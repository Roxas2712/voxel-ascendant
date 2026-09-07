-- Data-only, installation-wide content cache. No network or save-game writes.
-- Caller supplies scoped mod.cache, a SHA256 implementation and strict JSON.
-- Two journal slots per package retain the previous activation on torn writes.
local M = {}
local CHUNK, FILE, MANIFEST = 4*1024*1024, 32*1024*1024, 4*1024*1024
local PREFIX = "assets/pokemon-animation-cards/"
local function hashOK(s) return type(s)=="string" and #s==64 and not s:find("[^0-9a-f]") end
local function integer(n,lo,hi) return type(n)=="number" and n==math.floor(n) and n>=lo and n<=hi end
local function pathOK(s)
  return type(s)=="string" and s:sub(1,#PREFIX)==PREFIX and s:sub(-4)==".png"
    and not s:find("..",1,true) and not s:find("//",1,true)
    and not s:find("[\\:%z\1-\31]") and #s<=512
end
local function idOK(id)
  return type(id)=="string" and id:match("^apo%.pokemon%-hd%.g%d%d%.dex%d%d%d%d%-%d%d%d%d$")~=nil
end
local function u32(s,i)
  local a,b,c,d=s:byte(i,i+3); if not d then return nil end
  return ((a*256+b)*256+c)*256+d
end
local function finite(n,lo,hi)
  return type(n)=="number" and n==n and n>=lo and n<=hi
end
local function array(t,lo,hi)
  if type(t)~="table" or #t<lo or #t>hi then return false end
  local count=0
  for k in pairs(t)do if not integer(k,1,#t)then return false end;count=count+1 end
  return count==#t
end
-- Same version-1 roster partition as the offline builder, not a gameplay
-- generation rule. Expanding beyond 1025 requires an explicit content revision.
local GEN_ENDS={151,251,386,493,649,721,809,905,1025}
local function metadata(m,paths)
  local gen,first,last=m.id:match("^apo%.pokemon%-hd%.g(%d%d)%.dex(%d%d%d%d)%-(%d%d%d%d)$")
  gen,first,last=tonumber(gen),tonumber(first),tonumber(last)
  if not integer(gen,1,#GEN_ENDS) or m.rosterGeneration~=gen
      or not array(m.dexRange,2,2) or m.dexRange[1]~=first or m.dexRange[2]~=last then return false end
  local start=gen==1 and 1 or GEN_ENDS[gen-1]+1
  if first<start or first>GEN_ENDS[gen] or (first-start)%20~=0
      or last~=math.min(first+19,GEN_ENDS[gen]) then return false end
  local identities,used={},{ }
  for _,e in ipairs(m.entries)do
    if type(e)~="table" or not integer(e.dex,first,last)
      or type(e.form)~="string" or #e.form<1 or #e.form>64 or e.form:find("[^%w_-]")
      or (e.gender~="none" and e.gender~="male" and e.gender~="female")
      or (e.palette~="normal" and e.palette~="shiny") or type(e.clips)~="table" then return false end
    local form=e.form:lower();if form:match("^0+$")then form="base"end
    local key=table.concat({e.dex,form,e.gender,e.palette},":")
    if identities[key]then return false end;identities[key]=true
    local l=e.layout
    if type(l)~="table" or not integer(l.cell_width,1,4096) or not integer(l.cell_height,1,4096)
      or not integer(l.left,0,l.cell_width-1) or not integer(l.right,l.left+1,l.cell_width)
      or not integer(l.top,0,l.cell_height-1) or not integer(l.bottom,l.top+1,l.cell_height)
      or not finite(l.anchor_x,0,l.cell_width) or not finite(l.anchor_y,0,l.cell_height*2)
      or not finite(l.reference_height,0.001,8192) then return false end
    for _,name in ipairs({"runtime_content_width","runtime_content_height"})do
      if e[name]~=nil and not integer(e[name],1,16)then return false end
    end
    local decoded=0
    for _,kind in ipairs({"idle","walk","runtime"})do
      local clip=e.clips[kind]
      local file=type(clip)=="table" and paths[clip.logicalPath]
      if not file then return false end
      used[clip.logicalPath]=true
      if kind=="runtime"then
        if file.width~=16 or file.height~=96 then return false end
      else
        if not integer(clip.columns,1,64) or not finite(clip.duration,0.001,120)
          or clip.directions~=4 or file.width~=l.cell_width*clip.columns
          or file.height~=l.cell_height*4 then return false end
        decoded=decoded+file.width*file.height*4
      end
    end
    if decoded>64*1024*1024 or e.clips.idle.logicalPath==e.clips.walk.logicalPath then return false end
  end
  for path in pairs(paths)do if not used[path]then return false end end
  return true
end
function M.new(deps)
  local self={epoch=0,packages={},index={},cache=assert(deps.cache)}
  local hash,decode=assert(deps.sha256),assert(deps.decode)
  local function read(key,limit)
    local ok,info=pcall(self.cache.info,self.cache,key)
    if not ok or not info or info.type~="file" or not integer(info.size,1,limit) then return nil end
    local good,bytes=pcall(self.cache.read,self.cache,key)
    return good and type(bytes)=="string" and #bytes==info.size and bytes or nil
  end
  local function write(key,bytes)
    local ok,result=pcall(self.cache.write,self.cache,key,bytes)
    return ok and result and read(key,#bytes)==bytes or false
  end
  function self:putChunk(digest,bytes)
    if not hashOK(digest) or type(bytes)~="string" or #bytes<1 or #bytes>CHUNK or hash(bytes)~=digest then
      return nil,"chunk_verification_failed"
    end
    local key="hd-content/blobs/"..digest
    if read(key,CHUNK)==bytes or write(key,bytes) then return true end
    return nil,"cache_write_failed"
  end
  local function fileBytes(file)
    local parts={}
    for i,c in ipairs(file.chunks) do
      local bytes=read("hd-content/blobs/"..c.sha256,CHUNK)
      if not bytes or #bytes~=c.bytes or hash(bytes)~=c.sha256 then return nil end
      parts[i]=bytes
    end
    local bytes=table.concat(parts)
    if #bytes~=file.bytes or hash(bytes)~=file.sha256 or bytes:sub(1,8)~="\137PNG\r\n\26\n"
      or bytes:sub(13,16)~="IHDR" or u32(bytes,17)~=file.width or u32(bytes,21)~=file.height then return nil end
    return bytes
  end
  local function parse(raw,digest)
    if type(raw)~="string" or #raw>MANIFEST or not hashOK(digest) or hash(raw)~=digest then return nil end
    local ok,m=pcall(decode,raw)
    if not ok or type(m)~="table" or m.schema~="apo.content-package/v1" or m.requiresContentApi~=1
      or not idOK(m.id) or not integer(m.revision,1,2147483647)
      or not array(m.files,1,2048) or not array(m.entries,1,1024)
      or not array(m.dependencies,0,0) then return nil end
    local paths={}
    for _,f in ipairs(m.files) do
      if type(f)~="table" or not pathOK(f.logicalPath) or paths[f.logicalPath] or not hashOK(f.sha256)
        or not integer(f.bytes,1,FILE) or not integer(f.width,1,16384) or not integer(f.height,1,16384)
        or f.width*f.height>32*1024*1024 or not array(f.chunks,1,8) then return nil end
      local total=0
      for _,c in ipairs(f.chunks) do
        if type(c)~="table" or not hashOK(c.sha256) or not integer(c.bytes,1,CHUNK) then return nil end
        total=total+c.bytes
      end
      if total~=f.bytes then return nil end
      paths[f.logicalPath]=f
    end
    if not metadata(m,paths)then return nil end
    return m,paths
  end
  local function loadSlot(id,slot)
    local record=read("hd-content/active/"..id.."."..slot,256)
    if not record then return nil end
    local seq,digest,checksum=record:match("^VASC%-HD%-1\n(%d+)\n([0-9a-f]+)\n([0-9a-f]+)$")
    seq=tonumber(seq)
    if not integer(seq,1,2147483647) or not hashOK(digest) or not hashOK(checksum) then return nil end
    local prefix="VASC-HD-1\n"..seq.."\n"..digest.."\n"
    if hash(prefix)~=checksum then return nil end
    local raw=read("hd-content/manifests/"..digest,MANIFEST)
    local m,paths=parse(raw,digest)
    if not m or m.id~=id then return nil end
    for _,f in ipairs(m.files) do if not fileBytes(f) then return nil end end
    return {sequence=seq,digest=digest,manifest=m,paths=paths,slot=slot}
  end
  function self:inspect(raw,digest) return parse(raw,digest) end
  function self:hasChunk(digest,size)
    if not hashOK(digest) or not integer(size,1,CHUNK) then return false end
    local bytes=read("hd-content/blobs/"..digest,CHUNK)
    return bytes~=nil and #bytes==size and hash(bytes)==digest
  end
  local function mount(row)
    local id=row.manifest.id
    for path,f in pairs(row.paths) do
      local old=self.index[path]
      if old and old.owner~=id then return nil,"path_conflict" end
    end
    for path,old in pairs(self.index) do if old.owner==id then self.index[path]=nil end end
    self.packages[id]=row
    for path,f in pairs(row.paths) do self.index[path]={owner=id,file=f} end
    self.epoch=self.epoch+1
    return true
  end
  function self:restore(id)
    if not idOK(id) then return nil,"invalid_package_id" end
    local a,b=loadSlot(id,0),loadSlot(id,1)
    local row=a and b and (a.sequence>b.sequence and a or b) or a or b
    if not row then return nil,"no_verified_activation" end
    return mount(row)
  end
  -- Split a freshly verified boot mount from its writable download view
  -- without reading every PNG a second time. Copy metadata only; each view
  -- owns its tables and every later read still verifies the underlying bytes.
  function self:forkVerified()
    local seen={}
    local function clone(value)
      if type(value)~="table" then return value end
      if seen[value] then return seen[value] end
      local result={};seen[value]=result
      for k,v in pairs(value)do result[k]=clone(v)end
      return result
    end
    local fork=M.new(deps)
    fork.packages=clone(self.packages)
    fork.index=clone(self.index)
    fork.epoch=self.epoch
    return fork
  end
  function self:activate(raw,digest,consent,safeToActivate)
    if consent~=true then return nil,"consent_required" end
    if safeToActivate~=true then return nil,"activation_deferred" end
    local m,paths=parse(raw,digest)
    if not m then return nil,"manifest_verification_failed" end
    for _,f in ipairs(m.files) do if not fileBytes(f) then return nil,"incomplete_package" end end
    local prior=self.packages[m.id]
    -- Recover prior journal before selecting an overwrite slot, including after restart.
    if not prior then self:restore(m.id); prior=self.packages[m.id] end
    if prior and prior.digest==digest then return true end
    if prior and m.revision<=prior.manifest.revision then return nil,"revision_not_newer" end
    for path,f in pairs(paths) do
      local old=self.index[path]
      if old and old.owner~=m.id then return nil,"path_conflict" end
    end
    if not write("hd-content/manifests/"..digest,raw) then return nil,"manifest_write_failed" end
    local seq=prior and prior.sequence+1 or 1
    if seq>2147483647 then return nil,"journal_limit" end
    local slot=prior and 1-prior.slot or 0
    local prefix="VASC-HD-1\n"..seq.."\n"..digest.."\n"
    if not write("hd-content/active/"..m.id.."."..slot,prefix..hash(prefix)) then return nil,"activation_write_failed" end
    return mount({sequence=seq,digest=digest,manifest=m,paths=paths,slot=slot})
  end
  function self:read(path)
    local row=self.index[path]
    return row and fileBytes(row.file) or nil
  end
  function self:info(path)
    local row=self.index[path]
    if not row then return nil end
    local f=row.file
    return {type="file",size=f.bytes,width=f.width,height=f.height,
      sha256=f.sha256,epoch=self.epoch,packageId=row.owner}
  end
  function self:health()
    local count=0; for _ in pairs(self.packages) do count=count+1 end
    return {schema="vasc.hd-content-cache/v1",packages=count,epoch=self.epoch,
      networkConfigured=false,rendererConnected=false,charactersBundled=true}
  end
  return self
end
return M
