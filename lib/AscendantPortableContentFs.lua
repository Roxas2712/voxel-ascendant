-- Complete the older engine's portable backend for content imports only.
-- All persistent paths stay below the engine's actual portable directory.
-- HostShell is an engine-owned desktop API; no global filesystem is replaced.
local M={}
local function utf16(s)
  local out,i={},1
  local function word(n)out[#out+1]=string.char(n%256,math.floor(n/256))end
  while i<=#s do
    local a=s:byte(i);local n,count
    if a<128 then n,count=a,1
    elseif a>=194 and a<224 then n,count=a-192,2
    elseif a<240 and a>=224 then n,count=a-224,3
    elseif a>=240 and a<245 then n,count=a-240,4
    else error('invalid UTF-8 path')end
    for j=1,count-1 do local b=s:byte(i+j);assert(b and b>=128 and b<192,'invalid UTF-8 path');n=n*64+b-128 end
    assert(n<=1114111 and not(n>=55296 and n<=57343),'invalid Unicode path')
    if n<65536 then word(n)else n=n-65536;word(55296+math.floor(n/1024));word(56320+n%1024)end
    i=i+count
  end
  return table.concat(out)
end
function M.new(d)
  local fs,base,shell=assert(d.fs),assert(d.base),assert(d.shell)
  assert(type(base)=='string' and base~='' and not base:find('[%z\r\n]'))
  local win=d.osName=='Windows'
  assert(win or d.osName=='OS X' or d.osName=='Linux','unsupported portable platform')
  local copy={};for k,v in pairs(fs)do copy[k]=v end
  local roots={['cache/stadium']=true,['cache/stadium2-gen1']=true}
  for _,id in ipairs({d.modId,d.cacheId or d.modId})do
    assert(type(id)=='string' and id:match('^[%w_-]+$'),'invalid content owner')
    roots['mod_cache/'..id..'/sprite-content']=true
    roots['mod_cache/'..id..'/hd-content']=true
  end
  local function path(key)
    assert(type(key)=='string' and #key<=1024 and not key:find('..',1,true)
      and not key:find('//',1,true) and not key:find('[\\:%z\1-\31]'),'invalid portable content path')
    key=key:gsub('/$','')
    local allowed=key=='sprite-import.spritepack'
    for root in pairs(roots)do if key==root or key:sub(1,#root+1)==root..'/'then allowed=true end end
    assert(allowed,'path outside portable content roots')
    return base..'/'..key
  end
  local function q(s)return "'"..s:gsub("'","'\\''").."'"end
  local function psq(s)return "'"..s:gsub("'","''").."'"end
  local function powershell(script)
    return 'powershell -NoProfile -NonInteractive -EncodedCommand '..d.base64(utf16(script))
  end
  local function run(command,limit)
    local pipe=shell.popen(command,'r');if not pipe then error('content host operation unavailable')end
    local ok,raw=pcall(pipe.read,pipe,(limit or 1048576)+1)
    shell.pclose(pipe)
    if not ok or type(raw)~='string' or #raw>(limit or 1048576)then error('content host operation failed')end
    return raw
  end
  function copy.getSaveDirectory()return base end
  function copy.read(key)path(key);return fs.read(key)end
  function copy.write(key,bytes)
    path(key)
    if type(bytes)~='string' or #bytes>67108864 then return false,'invalid content bytes'end
    return fs.write(key,bytes)==true and fs.read(key)==bytes
  end
  function copy.createDirectory(key)
    path(key)
    return fs.createDirectory(key)==true and copy.getInfo(key,'directory')~=nil
  end
  function copy.getInfo(key,filter)
    local full=path(key);local command
    if win then
      command=powershell("$ErrorActionPreference='Stop';try{$i=Get-Item -Force -LiteralPath "..psq(full)..";if($i.PSIsContainer){[Console]::Write('directory')}else{[Console]::Write('file '+$i.Length)}}catch{if($_.CategoryInfo.Category -eq 'ObjectNotFound'){[Console]::Write('missing')}else{[Console]::Write('error')}}")
    else
      local format=d.osName=='OS X' and "stat -f '%HT:%z' " or "stat -c '%F:%s' -- "
      command='LC_ALL=C '..format..q(full)..' 2>&1'
    end
    local raw=run(command,8192):gsub('%s+$','')
    if raw=='missing' or (not win and raw:match(': No such file or directory$'))then return nil end
    local kind,n
    if raw=='directory' or raw:match('^[Dd]irectory:')then kind='directory'
    else n=raw:match('^file (%d+)$') or raw:match('^[Rr]egular [Ff]ile:(%d+)$') or raw:match('^regular empty file:(%d+)$');if n then kind='file' end end
    if not kind then error('could not inspect portable content file')end
    if filter and filter~=kind then return nil end
    return {type=kind,size=n and tonumber(n)or nil}
  end
  function copy.getDirectoryItems(key)
    local full=path(key);local info=copy.getInfo(key)
    if not info then return {}end
    assert(info.type=='directory','content inventory path is not a directory')
    local command
    if win then
      command=powershell("$ErrorActionPreference='Stop';try{Get-ChildItem -Force -LiteralPath "..psq(full).."|ForEach-Object{[Console]::Write($_.Name+[char]0)};[Console]::Write([char]1+'OK')}catch{[Console]::Write('error')}")
    else command='find '..q(full).." -mindepth 1 -maxdepth 1 -print0 2>&1 && printf '\001OK'"end
    local raw=run(command)
    assert(raw:sub(-3)=='\1OK','incomplete portable content inventory')
    raw=raw:sub(1,-4);local out={}
    for item in raw:gmatch('([^%z]+)%z')do
      local name=win and item or item:sub(#full+2)
      assert((win or item:sub(1,#full+1)==full..'/')and name:match('^[%w_.-]+$')and name~='.'and name~='..','invalid content inventory entry')
      out[#out+1]=name
    end
    assert(raw=='' or raw:sub(-1)=='\0','truncated content inventory')
    table.sort(out);return out
  end
  function copy.newFile(key)
    local full=path(key);local file={}
    function file:open(mode)
      if mode~='r' or self.pipe then return false,'content reader is read-only'end
      local info=copy.getInfo(key,'file');if not info or info.size>1073741824 then return false,'invalid content file size'end
      local command
      if win then
        command=powershell("$ErrorActionPreference='Stop';$f=[IO.File]::OpenRead("..psq(full)..");try{$f.CopyTo([Console]::OpenStandardOutput(),65536)}finally{$f.Dispose()}")
      else command='cat -- '..q(full)..' 2>/dev/null'end
      -- Windows text-mode pipes translate CRLF and can treat 0x1A as EOF.
      -- Sprite packages are binary, including their manifest and PNG chunks.
      self.pipe=shell.popen(command,win and 'rb' or 'r');return self.pipe~=nil
    end
    function file:read(n)
      assert(self.pipe and type(n)=='number' and n>=0 and n<=4194304 and n%1==0,'invalid content read')
      return self.pipe:read(n)
    end
    function file:close()if self.pipe then shell.pclose(self.pipe);self.pipe=nil end;return true end
    return file
  end
  function copy.stageExternal(selected,key)
    assert(type(selected)=='string' and not selected:find('[%z\r\n]'),'invalid selected path')
    local dest=path(key);local command
    if win then command=powershell("$ErrorActionPreference='Stop';try{Copy-Item -LiteralPath "..psq(selected).." -Destination "..psq(dest).." -Force;[Console]::Write('OK')}catch{[Console]::Write('error')}")
    else command='cp -f -- '..q(selected)..' '..q(dest).." 2>/dev/null && printf OK"end
    local raw=run(command,8192)
    return raw=='OK' and copy.getInfo(key,'file')~=nil
  end
  function copy.remove(key)
    path(key)
    if not copy.getInfo(key)then return true end
    local ok=fs.remove(key)
    return ok==true and copy.getInfo(key)==nil
  end
  return copy
end
M._utf16=utf16
return M
