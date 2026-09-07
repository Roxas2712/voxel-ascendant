-- Data-only sequential HD stage import. The selected file is never executed,
-- mounted or extracted. Only catalog-pinned manifests and verified chunks
-- reach the same installation-wide store used by the network downloader.
local M={MAGIC="VASC-HD-PACK-1\n"}
local HEADER=#M.MAGIC+65+9
local LIMIT=4*1024*1024
function M.new(deps)
  local self={status="idle",message="",doneBytes=0,totalBytes=0,changed=false}
  local store=assert(deps.store)
  local file,raw,digest,chunks,index
  local function close()
    if file then pcall(file.close,file);file=nil end
    raw,digest,chunks,index=nil,nil,nil,nil
  end
  local function fail(reason)
    close();self.status="error";self.message=reason;return false,reason
  end
  local function read(n)
    local ok,s=pcall(file.read,file,n)
    if ok and type(s)=="string" and #s==n then return s end
  end
  function self:busy()return self.status=="importing"end
  function self:cancel()
    close();self.status="cancelled";self.message="Import cancelled; verified chunks retained"
  end
  -- reader must be an already opened, user-selected, seek-free binary file.
  -- Ownership transfers here, including on rejection; never read whole packs.
  function self:start(reader,size,catalog,consent)
    if self:busy()then return false,"Import already running"end
    file=reader
    if consent~=true then return fail("Import confirmation required")end
    if type(size)~="number" or size~=math.floor(size) or size<HEADER+1
      or size>1024*1024*1024+LIMIT+HEADER then return fail("Invalid HD package size")end
    local header=read(HEADER)
    if not header or header:sub(1,#M.MAGIC)~=M.MAGIC then return fail("Not a VASC HD package")end
    digest=header:sub(#M.MAGIC+1,#M.MAGIC+64)
    local lengthHex=header:sub(-9,-2)
    if digest:find("[^0-9a-f]") or header:sub(#M.MAGIC+65,#M.MAGIC+65)~="\n"
      or lengthHex:find("[^0-9a-f]") or header:sub(-1)~="\n"then
      return fail("Invalid HD package header")
    end
    local length=tonumber(lengthHex,16)
    local package
    for _,p in ipairs(catalog and catalog.packages or {})do
      if p.manifestSha256==digest then package=p;break end
    end
    if not package then return fail("HD package not in catalog; update VASC or catalog")end
    if length~=package.manifestBytes or length<1 or length>LIMIT then return fail("Manifest does not match catalog")end
    raw=read(length)
    local manifest=raw and store:inspect(raw,digest)
    if not manifest or manifest.id~=package.id or manifest.revision~=package.revision
      or manifest.rosterGeneration~=package.rosterGeneration then return fail("Manifest does not match catalog")end
    local prior=store.packages[manifest.id]
    if prior and prior.manifest.revision>manifest.revision then return fail("revision_not_newer")end
    chunks={};local seen,total,allBytes={},HEADER+length,0
    for _,entry in ipairs(manifest.files)do
      allBytes=allBytes+entry.bytes
      for _,c in ipairs(entry.chunks)do
        if seen[c.sha256] and seen[c.sha256]~=c.bytes then return fail("Invalid HD package chunks")end
        if not seen[c.sha256]then
          seen[c.sha256]=c.bytes;chunks[#chunks+1]=c;total=total+c.bytes
        end
      end
    end
    if allBytes~=package.fileBytes or total~=size then return fail("Package size mismatch")end
    self.doneBytes=HEADER+length;self.totalBytes=total;index=1
    self.status="importing";self.message="Importing verified HD package"
    return true
  end
  function self:update()
    if not self:busy()then return end
    local c=chunks[index]
    if c then
      local bytes=read(c.bytes)
      if not bytes then return fail("Truncated chunk")end
      local ok,why=store:putChunk(c.sha256,bytes)
      if not ok then return fail(why)end
      self.doneBytes=self.doneBytes+#bytes;index=index+1
      return -- at most one <=4 MiB read/hash/write per UI tick
    end
    local ok,extra=pcall(file.read,file,1)
    if not ok or (type(extra)=="string" and #extra>0)then return fail("Package size mismatch")end
    local activated,why=store:activate(raw,digest,true,true)
    if not activated then return fail(why)end
    close();self.changed=true;self.status="ready"
    self.message="Import verified. Restart the game to enable HD."
    return true
  end
  return self
end
return M
