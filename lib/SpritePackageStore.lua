-- Verified data cache for generic sprite packages. Game saves are never touched.
-- Restore/activation may be scheduled outside gameplay; resolving uses only mounted receipts.
local M={CHUNK=4194304,MANIFEST=4194304,FILE=67108864}
local function hashOK(s) return type(s)=="string" and #s==64 and not s:find("[^a-f0-9]") end
local function size(n,max) return type(n)=="number" and n%1==0 and n>0 and n<=max end
local function pathOK(s)
  return type(s)=="string" and #s<=512 and s:match("^[%w_./-]+$")
    and not s:find("..",1,true) and s:sub(1,1)~="/" and not s:find("//",1,true)
    and (s:match("%.png$") or s:match("%.gif$") or s:match("%.webp$") or s:match("%.jpg$") or s:match("%.jpeg$") or s:match("%.bmp$") or s:match("%.tga$"))
end
function M.new(d)
  local self={receipts={},mounted={},files={},filePackages={}}
  local bootVerified
  local function read(key,max)
    local ok,info=pcall(d.cache.info,d.cache,key)
    -- Older portable engines omit size. Never infer verified content from
    -- metadata: enforce the byte limit and supplied size on the actual read.
    if not ok or type(info)~="table" or (info.size~=nil and not size(info.size,max)) then return nil end
    local yes,raw=pcall(d.cache.read,d.cache,key)
    if yes and type(raw)=="string" and size(#raw,max) and (info.size==nil or #raw==info.size) then return raw end
  end
  local function write(key,raw)
    if read(key,#raw)==raw then return true end
    local ok,yes=pcall(d.cache.write,d.cache,key,raw)
    return ok and yes==true and read(key,#raw)==raw
  end
  function self:hasChunk(h,n)
    if not hashOK(h) or not size(n,M.CHUNK) then return false end
    local raw=read("sprite-content/blobs/"..h,M.CHUNK)
    if raw and #raw==n and d.sha256(raw)==h then return true end
    -- Old verified HD bytes are shared without copying or marking unverified data installed.
    if d.legacy and type(d.legacy.hasChunk)=="function" then
      local ok,yes=pcall(d.legacy.hasChunk,d.legacy,h,n);return ok and yes==true
    end
    return false
  end
  function self:putChunk(h,raw)
    if not hashOK(h) or type(raw)~="string" or not size(#raw,M.CHUNK) or d.sha256(raw)~=h then return false,"chunk_verification_failed" end
    if self:hasChunk(h,#raw) then return true end
    return write("sprite-content/blobs/"..h,raw),"cache_write_failed"
  end
  local function chunk(h,n)
    local raw=read("sprite-content/blobs/"..h,M.CHUNK)
    if type(raw)=="string" and #raw==n and d.sha256(raw)==h then return raw end
    if d.legacyReadChunk then
      raw=d.legacyReadChunk(h,n)
      if type(raw)=="string" and #raw==n and d.sha256(raw)==h then return raw end
    end
  end
  local function fileKey(f)
    local key={f.sha256,tostring(f.bytes)}
    for _,c in ipairs(f.chunks)do key[#key+1]=c.sha256;key[#key+1]=tostring(c.bytes)end
    return table.concat(key,':')
  end
  local function fileHashMatches(f,raw)
    local c=f.chunks[1]
    return #raw==f.bytes and ((#f.chunks==1 and c.sha256==f.sha256 and c.bytes==f.bytes)
      or d.sha256(raw)==f.sha256)
  end
  function self:inspect(raw,p)
    if type(raw)~="string" or #raw>M.MANIFEST or #raw~=p.manifestBytes or d.sha256(raw)~=p.manifestSha256 then return nil,"manifest_hash_mismatch" end
    local ok,m=pcall(d.decode,raw)
    if not ok or type(m)~="table" or m.schema~="vasc.sprite-package/v1" or m.requiresContentApi~=2
      or m.id~=p.id or m.revision~=p.revision or type(m.files)~="table" or #m.files<1 or #m.files>10000
      or type(m.dependencies)~="table" or #m.dependencies~=#p.dependencies then return nil,"invalid_manifest" end
    for i,dep in ipairs(m.dependencies) do if dep~=p.dependencies[i] then return nil,"dependency_mismatch" end end
    local paths,total={},0
    for _,f in ipairs(m.files) do
      if type(f)~="table" or (f.owner~="vasc" and f.owner~="kasc") or not pathOK(f.logicalPath)
        or not size(f.bytes,M.FILE) or not hashOK(f.sha256) or type(f.chunks)~="table" or #f.chunks<1 or #f.chunks>16 then return nil,"invalid_file" end
      local key=f.owner..":"..f.logicalPath
      if paths[key] then return nil,"duplicate_file" end
      paths[key]=true;local n=0
      for _,c in ipairs(f.chunks) do
        if type(c)~="table" or not hashOK(c.sha256) or not size(c.bytes,M.CHUNK) then return nil,"invalid_chunk" end
        n=n+c.bytes
      end
      if n~=f.bytes then return nil,"file_size_mismatch" end
      total=total+n
    end
    if total~=p.fileBytes then return nil,"package_size_mismatch" end
    return m
  end
  function self:activate(raw,p,mount)
    local m,err=self:inspect(raw,p);if not m then return false,err end
    for _,dep in ipairs(p.dependencies) do if not self:receipt(dep) then return false,"missing_dependency" end end
    -- Verify complete files as well as each chunk. Activation record is written last.
    for _,f in ipairs(m.files) do
      local key=bootVerified and fileKey(f)
      if not (key and bootVerified[key]) then
        local parts={}
        for i,c in ipairs(f.chunks) do parts[i]=chunk(c.sha256,c.bytes);if not parts[i] then return false,"missing_or_corrupt_chunk" end end
        if not fileHashMatches(f,table.concat(parts)) then return false,"file_hash_mismatch" end
        if key then bootVerified[key]=true end
      end
      local held=self.files[f.owner..":"..f.logicalPath]
      if mount and held and held.sha256~=f.sha256 then return false,"mounted_path_conflict" end
    end
    if not write("sprite-content/manifests/"..p.manifestSha256..".json",raw) then return false,"cache_write_failed" end
    if not write("sprite-content/installed/"..p.id,p.manifestSha256) then return false,"receipt_write_failed" end
    self.receipts[p.id]={verified=true,manifestSha256=p.manifestSha256,revision=p.revision}
    if mount then
      self.mounted[p.id]=true
      for _,f in ipairs(m.files) do
        local key=f.owner..":"..f.logicalPath;self.files[key]=f;self.filePackages[key]=p.id
      end
    end
    return true
  end
  function self:restore(p)
    self.receipts[p.id]=nil;self.mounted[p.id]=nil
    if read("sprite-content/installed/"..p.id,64)~=p.manifestSha256 then return false,"not_installed" end
    local raw=read("sprite-content/manifests/"..p.manifestSha256..".json",M.MANIFEST)
    return self:activate(raw,p,true)
  end
  -- A committed installation receipt may restore its catalog-pinned index
  -- without rescanning every image. This does not accept any image bytes:
  -- readVerified checks the actual payload each time it reaches the renderer.
  -- Fresh activation and the explicit full restore above remain exhaustive.
  function self:restoreIndex(p)
    self.receipts[p.id]=nil;self.mounted[p.id]=nil
    if read('sprite-content/installed/'..p.id,64)~=p.manifestSha256 then return false,'not_installed' end
    local raw=read('sprite-content/manifests/'..p.manifestSha256..'.json',M.MANIFEST)
    local m,err=self:inspect(raw,p);if not m then return false,err end
    for _,dep in ipairs(p.dependencies)do if not self:receipt(dep)then return false,'missing_dependency'end end
    for _,f in ipairs(m.files)do
      local held=self.files[f.owner..':'..f.logicalPath]
      if held and held.sha256~=f.sha256 then return false,'mounted_path_conflict'end
    end
    self.receipts[p.id]={verified=true,manifestSha256=p.manifestSha256,revision=p.revision,payloadValidation='on-read'}
    self.mounted[p.id]=true
    for _,f in ipairs(m.files)do
      local key=f.owner..':'..f.logicalPath;self.files[key]=f;self.filePackages[key]=p.id
    end
    return true
  end
  -- Only this synchronous boot batch shares verification of identical files.
  -- Do not retain the memo across boots, downloads, activation or rendering:
  -- readVerified must still reject bytes changed after mounting.
  function self:restoreAll(packages)
    assert(not bootVerified,'nested sprite restore')
    bootVerified={}
    local ok,err=pcall(function()
      for _,p in ipairs(packages)do self:restore(p)end
    end)
    bootVerified=nil
    if not ok then error(err)end
  end
  function self:receipt(id) return self.receipts[id] end
  function self:packageMounted(id)return self.mounted[id]==true end
  function self:styleMounted(id)
    local style=d.catalog.styles[id];if not style then return false end
    if style.kind=="native" then return true end
    if style.activationPolicy=="any-package" then
      for _,key in ipairs(style.packages) do if self.mounted[key] then return true end end
      return false
    end
    for _,key in ipairs(style.packages) do if not self.mounted[key] then return false end end
    return style.kind=="download"
  end
  -- Rendering consumes verified bytes directly. A second on-disk copy is
  -- optional: full/read-only storage must not make installed sprites unusable.
  function self:readVerified(owner,path)
    local key=owner..":"..path
    local f=self.files[key];if not f or not self.mounted[self.filePackages[key]] then return nil,"not_mounted" end
    local target="sprite-content/files/"..f.sha256.."."..path:match("%.(%w+)$")
    local existing=read(target,M.FILE)
    if existing and d.sha256(existing)==f.sha256 then return existing end
    local parts={};for i,c in ipairs(f.chunks) do parts[i]=chunk(c.sha256,c.bytes);if not parts[i] then return nil,"missing_or_corrupt_chunk" end end
    local raw=table.concat(parts)
    if not fileHashMatches(f,raw) then return nil,"file_hash_mismatch" end
    return raw
  end
  function self:materialize(owner,path)
    local raw,err=self:readVerified(owner,path)
    if not raw then return nil,err end
    local f=self.files[owner..":"..path]
    local target="sprite-content/files/"..f.sha256.."."..path:match("%.(%w+)$")
    if read(target,M.FILE)~=raw and not write(target,raw) then return nil,"materialize_failed" end
    return target -- adapter resolves this scoped cache key; never love.filesystem on user input
  end
  return self
end
return M
