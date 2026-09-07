-- Data-only HTTPS downloader. Rendering uses a separate, frozen boot mount:
-- downloading never replaces textures referenced by a running scene.
-- Neutral public origin: sealed RC32 payload verified end-to-end 2026-09-07.
-- Never fall back to a private NAS hostname or a share-link service.
-- Existing games may follow redirects internally: the approved service must
-- serve directly. A newer bounded transport is preferred, not required.
-- Legacy bodies are capped/verified after receipt, not during native receive.
local M={BASE="https://vasc-downloads.ascendant-content.workers.dev"}
local LIMIT=4*1024*1024
local GEN_ENDS={151,251,386,493,649,721,809,905,1025}
local function hash(s) return type(s)=="string" and #s==64 and not s:find("[^0-9a-f]") end
local function int(n,a,b) return type(n)=="number" and n==math.floor(n) and n>=a and n<=b end
function M.catalog(raw,decode)
  if type(raw)~="string" or #raw>LIMIT then return nil end
  local ok,c=pcall(decode,raw)
  if not ok or type(c)~="table" or c.schema~="apo.content-catalog/v1"
      or type(c.packages)~="table" or #c.packages>64 then return nil end
  local seen={}
  for k in pairs(c.packages)do
    if not int(k,1,#c.packages)then return nil end
  end
  for _,p in ipairs(c.packages)do
    if type(p)~="table" or type(p.id)~="string"
      or not p.id:match("^apo%.pokemon%-hd%.g%d%d%.dex%d%d%d%d%-%d%d%d%d$")
      or seen[p.id] or not hash(p.manifestSha256) or not int(p.revision,1,2147483647)
      or not int(p.manifestBytes,1,LIMIT) or not int(p.fileBytes,1,1024*1024*1024)
      or not int(p.rosterGeneration,1,9) then return nil end
    local gen,first,last=p.id:match("g(%d%d)%.dex(%d%d%d%d)%-(%d%d%d%d)$")
    gen,first,last=tonumber(gen),tonumber(first),tonumber(last)
    if gen~=p.rosterGeneration then return nil end
    local start=gen==1 and 1 or GEN_ENDS[gen-1]+1
    if first<start or first>GEN_ENDS[gen] or (first-start)%20~=0
      or last~=math.min(first+19,GEN_ENDS[gen])then return nil end
    seen[p.id]=true
  end
  return c
end
function M.new(d)
  local self={store=d.store,catalog=assert(d.catalog),status="idle",message="",
    queue={},doneBytes=0,totalBytes=0,changed=false,warnings={}}
  local fetch,decode=d.fetch,d.decode
  local receipts,replayed,replayRow=d.receipts,{},nil
  local function boundedAvailable()
    if not fetch or type(fetch.capabilities)~="function"then return false end
    local ok,caps=pcall(fetch.capabilities,fetch)
    return ok and type(caps)=="table" and caps.boundedHttpsGet==1
      and type(caps.maxResponseBytes)=="number" and caps.maxResponseBytes>=LIMIT
  end
  local function configured()
    -- Configuration is an origin, never a URL carrying credentials, query
    -- tokens or a path. Approval/redirect verification is a separate release
    -- gate; this syntax check is NOT proof of a neutral public host.
    if type(M.BASE)~="string"then return false end
    local authority=M.BASE:match("^https://([^/%?#@%s]+)$")
    return authority~=nil
  end
  local function receipt(kind)return kind=="start" or kind=="complete" or kind=="replay_complete"end
  local function warnReceipt()self.warnings.receipt_unconfirmed=true end
  local function release()
    if self.job then pcall(fetch.release,fetch,self.job);self.job=nil end
  end
  local function stopReplay()
    if self.pending=="replay_complete"then
      if self.job then pcall(fetch.cancel,fetch,self.job)end
      release();self.pending=nil;replayRow=nil
    end
  end
  local function rememberTicket(ttl)
    if not receipts then return end
    if receipts.origin~=M.BASE then return warnReceipt()end
    local ok,saved=pcall(receipts.put,receipts,self.current.id,self.current.manifestSha256,self.ticket,ttl)
    if not ok or saved~=true then warnReceipt()end
  end
  local function acknowledge(id,ticket)
    replayed[ticket]=true
    if receipts and receipts.origin==M.BASE then
      local ok,saved=pcall(receipts.remove,receipts,id,ticket)
      if not ok or saved~=true then warnReceipt()end
    end
  end
  local function fail(reason)
    release();self.status="error";self.message=tostring(reason or "Download failed")
    self.queue={};self.pending=nil
  end
  local function request(path,kind)
    local function rejected(reason)
      if receipt(kind)then warnReceipt() else fail(reason)end
      return false
    end
    if not configured()then return rejected("Public download source not configured")end
    if not self:available()then return rejected("Network unavailable in this engine")end
    local ceiling=LIMIT
    if receipt(kind)then ceiling=4096
    elseif kind=="manifest"then ceiling=self.current.manifestBytes
    elseif kind=="chunk"then ceiling=self.chunks[self.chunkIndex].bytes end
    local options={maxSeconds=30}
    if boundedAvailable()then options.boundedHttpsGet=1;options.maxBytes=ceiling end
    local ok,job,err=pcall(fetch.get,fetch,M.BASE..path,options)
    if not ok or not job then return rejected(err or "Network unavailable")end
    self.job,self.pending,self.responseLimit=job,kind,ceiling;return true
  end
  function self:available()
    if not fetch or type(fetch.available)~="function" then return false end
    local ok,yes=pcall(fetch.available,fetch);return ok and yes==true
  end
  function self:transportMode()return boundedAvailable() and "bounded" or "existing"end
  function self:configured()return configured()end
  function self:busy() return self.status=="checking" or self.status=="downloading" end
  function self:check()
    stopReplay()
    if self:busy() then return false end
    if not configured()then fail("Public download source not configured");return false end
    if not self:available()then fail("Network unavailable in this engine");return false end
    self.status="checking";self.message="Checking available packages"
    return request("/catalog.json","catalog")
  end
  function self:installed(p)
    local row=self.store.packages[p.id]
    return row and row.manifest.revision>=p.revision or false
  end
  local function nextPackage()
    self.current=table.remove(self.queue,1)
    if not self.current then
      self.status="ready";self.message="Download verified. Restart the game to enable HD."
      return
    end
    self.ticket=nil;self.chunks=nil;self.chunkIndex=1
    self.message=self.current.id
    request("/manifests/"..self.current.manifestSha256..".json","manifest")
  end
  function self:start(generation,packageId,consent)
    if consent~=true or self:busy()then return false end
    stopReplay()
    if not configured()then fail("Public download source not configured");return false end
    if not self:available()then fail("Network unavailable in this engine");return false end
    self.queue={};self.doneBytes=0;self.totalBytes=0
    for _,p in ipairs(self.catalog.packages)do
      if (not generation or p.rosterGeneration==generation) and (not packageId or p.id==packageId)
          and not self:installed(p)then
        self.queue[#self.queue+1]=p;self.totalBytes=self.totalBytes+p.fileBytes
      end
    end
    if #self.queue==0 then self.status="ready";self.message="All selected packages are installed";return true end
    self.status="downloading";nextPackage();return true
  end
  function self:cancel()
    if self.job then pcall(fetch.cancel,fetch,self.job)end
    release();self.queue={};self.pending=nil;replayRow=nil;self.status="cancelled"
    self.message="Stopped. Verified chunks are retained for resume."
  end
  local function nextChunk()
    local c=self.chunks[self.chunkIndex]
    if not c then
      local ok,reason=self.store:activate(self.manifestRaw,self.current.manifestSha256,true,true)
      if not ok then return fail(reason)end
      self.changed=true
      if self.ticket then replayed[self.ticket]=true end
      if self.ticket and request("/downloads/complete/"..self.ticket,"complete")then return end
      return nextPackage()
    end
    -- At most one cached chunk hash per frame; never scan the entire package
    -- in one UI tick. Failed/cancelled downloads resume these verified blobs.
    if self.store:hasChunk(c.sha256,c.bytes)then
      self.doneBytes=self.doneBytes+c.bytes;self.chunkIndex=self.chunkIndex+1
      self.pending="advance";return
    end
    request("/blobs/sha256/"..c.sha256,"chunk")
  end
  function self:update()
    if self.pending=="advance"then self.pending=nil;return nextChunk()end
    if not self.job then return end
    local ok,r=pcall(fetch.poll,fetch,self.job)
    -- A broken/unavailable transport must not throw from the menu update.
    -- Keep receipt failures non-fatal through the same error path below.
    if not ok or type(r)~="table" then r={status="error",err="Network polling failed"}end
    if r.status=="pending"then return end
    local kind=self.pending;release();self.pending=nil
    if r.status~="ok"then
      -- Metrics failure never discards already verified content.
      if kind=="start"then warnReceipt();return nextChunk()end
      if kind=="complete"then warnReceipt();return nextPackage()end
      if kind=="replay_complete"then warnReceipt();replayRow=nil;return end
      return fail(r.err or "Request failed; choose download to resume")
    end
    local body=r.body
    if type(body)~="string" or #body>(self.responseLimit or LIMIT) then
      if kind=="start"then warnReceipt();return nextChunk()end
      if kind=="complete"then warnReceipt();return nextPackage()end
      if kind=="replay_complete"then warnReceipt();replayRow=nil;return end
      return fail("Response exceeds content limit")
    end
    if kind=="catalog"then
      local c=M.catalog(body,decode)
      if not c then return fail("Invalid content catalog")end
      -- Retain installations from a previous catalog and reject advertised
      -- downgrades. Saved activations themselves remain checksum-protected.
      for _,p in ipairs(c.packages)do
        local row=self.store.packages[p.id]
        if not row then self.store:restore(p.id);row=self.store.packages[p.id]end
        if row and p.revision<row.manifest.revision then return fail("Catalog downgrade rejected")end
      end
      self.catalog=c;self.catalogChecks=(self.catalogChecks or 0)+1
      self.status="idle";self.message="Catalog checked; choose a generation or package"
      if d.cache then
        local saved,yes=pcall(d.cache.write,d.cache,"hd-content/catalog.json",body)
        if not saved or yes~=true then self.warnings.catalog_not_saved=true end
      end
    elseif kind=="manifest"then
      local m=self.store:inspect(body,self.current.manifestSha256)
      if not m or m.id~=self.current.id or m.revision~=self.current.revision
          or m.rosterGeneration~=self.current.rosterGeneration or #body~=self.current.manifestBytes then
        return fail("Manifest does not match catalog")
      end
      self.manifestRaw=body;self.chunks={};local bytes=0
      for _,f in ipairs(m.files)do
        for _,c in ipairs(f.chunks)do self.chunks[#self.chunks+1]=c;bytes=bytes+c.bytes end
      end
      if bytes~=self.current.fileBytes then return fail("Package size mismatch")end
      if not request("/downloads/start/"..self.current.manifestSha256,"start")then nextChunk()end
    elseif kind=="start"then
      local parsed,t=pcall(decode,body)
      if parsed and type(t)=="table" and type(t.ticket)=="string"
          and #t.ticket==48 and not t.ticket:find("[^0-9a-f]")then
        self.ticket=t.ticket;rememberTicket(t.expiresIn)
      else warnReceipt()end
      nextChunk()
    elseif kind=="chunk"then
      local c=self.chunks[self.chunkIndex]
      if #body~=c.bytes then return fail("Truncated chunk")end
      local stored,reason=self.store:putChunk(c.sha256,body)
      if not stored then return fail(reason)end
      self.doneBytes=self.doneBytes+c.bytes;self.chunkIndex=self.chunkIndex+1
      self.pending="advance"
    elseif kind=="complete"then
      local parsed,value=pcall(decode,body)
      if not parsed or type(value)~="table" or value.ok~=true then warnReceipt()end
      if parsed and type(value)=="table" and value.ok==true then acknowledge(self.current.id,self.ticket)end
      nextPackage()
    elseif kind=="replay_complete"then
      local parsed,value=pcall(decode,body)
      if parsed and type(value)=="table" and value.ok==true and replayRow then
        acknowledge(replayRow.id,replayRow.ticket)
      else warnReceipt()end
      replayRow=nil
    end
  end
  function self:background()
    -- Optional metrics never start/retry payloads and never interrupt a UI
    -- request. One attempt per ticket per process; expiry is journal-owned.
    if self.pending=="replay_complete"then return self:update()end
    if not receipts or receipts.origin~=M.BASE or self.job or self:busy()
        or not configured()or not self:available()then return end
    local ok,rows=pcall(receipts.list,receipts)
    if not ok or type(rows)~="table"then return warnReceipt()end
    for _,row in ipairs(rows)do
      local valid=type(row)=="table"and type(row.id)=="string"and hash(row.digest)
        and type(row.ticket)=="string"and #row.ticket==48 and not row.ticket:find("[^0-9a-f]")
      local installed=valid and self.store.packages[row.id]
      -- Store.restore/forkVerified already proved the activated file hashes.
      -- Never count an issued ticket with partial/corrupt/unactivated content,
      -- or a newer/different manifest under the same package id.
      if not replayed[row.ticket]and installed and installed.digest==row.digest then
        replayed[row.ticket]=true;replayRow=row
        if not request("/downloads/complete/"..row.ticket,"replay_complete")then replayRow=nil end
        return
      end
    end
  end
  return self
end
return M
