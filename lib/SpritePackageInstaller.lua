-- One network request and at most one chunk write per update. No automatic consent.
local M={}
function M.new(d)
  local self={state="idle",queue={},doneBytes=0}
  local function log(name,fields)if d.diagnostics then pcall(d.diagnostics.event,d.diagnostics,name,fields) end end
  local function finish(name,fields)if d.diagnostics then pcall(d.diagnostics.finish,d.diagnostics,name,fields) end end
  local function fail(reason) self.state="error";self.error=reason;finish("error",{code=reason,packageId=self.current and self.current.id,doneBytes=self.doneBytes});return false,reason end
  local function request(path,bytes,hash,kind)
    local ok,err=d.fetch:start(path,bytes,hash)
    if not ok then return fail(err) end
    self.pending=kind;return true
  end
  function self:start(plan,consent)
    if consent~=true then return false,"confirmation_required" end
    if self.state=="downloading" then return false,"busy" end
    if d.diagnostics then pcall(d.diagnostics.begin,d.diagnostics) end
    self.queue={};self.index=1;self.doneBytes=0;self.error=nil;self.pending=nil
    self.current=nil;self.raw=nil;self.manifest=nil;self.chunks=nil
    for _,key in ipairs(plan.missing) do
      local p=d.catalog.packages[key]
      if not p or p.published~=true then return fail("package_not_published") end
      self.queue[#self.queue+1]=p
    end
    self.state="downloading";return true
  end
  function self:update()
    if self.state~="downloading" then return end
    if self.pending then
      d.fetch:update()
      if d.fetch.state=="error" then return fail(d.fetch.error) end
      if d.fetch.state~="ready" then return end
      local body=d.fetch.body;d.fetch.body=nil;local kind=self.pending;self.pending=nil
      if kind=="manifest" then
        local m,err=d.store:inspect(body,self.current)
        if not m then return fail(err) end
        self.raw=body;self.manifest=m;self.chunks={};self.chunkIndex=1
        local seen={}
        for _,f in ipairs(m.files) do for _,c in ipairs(f.chunks) do
          if not seen[c.sha256] then self.chunks[#self.chunks+1]=c;seen[c.sha256]=true end
        end end
      else
        local c=self.chunks[self.chunkIndex];local ok,err=d.store:putChunk(c.sha256,body)
        if not ok then return fail(err) end
        log("chunk_stored",{packageId=self.current.id,bytes=c.bytes})
        self.doneBytes=self.doneBytes+c.bytes;self.chunkIndex=self.chunkIndex+1
      end
      return
    end
    if not self.current then
      self.current=self.queue[self.index]
      if not self.current then self.state="ready";finish("success",{doneBytes=self.doneBytes});return end
      log("package_started",{packageId=self.current.id,bytes=self.current.fileBytes})
      return request("/manifests/"..self.current.manifestSha256..".json",self.current.manifestBytes,self.current.manifestSha256,"manifest")
    end
    local c=self.chunks and self.chunks[self.chunkIndex]
    if c then
      if d.store:hasChunk(c.sha256,c.bytes) then log("chunk_cached",{packageId=self.current.id,bytes=c.bytes});self.chunkIndex=self.chunkIndex+1;return end
      return request("/blobs/sha256/"..c.sha256,c.bytes,c.sha256,"chunk")
    end
    local ok,err=d.store:activate(self.raw,self.current,false)
    if not ok then return fail(err) end
    log("package_verified",{packageId=self.current.id,doneBytes=self.doneBytes})
    self.index=self.index+1;self.current=nil;self.raw=nil;self.manifest=nil;self.chunks=nil
  end
  function self:cancel()
    finish("cancelled",{doneBytes=self.doneBytes})
    d.fetch:cancel();self.state="cancelled";self.current=nil;self.raw=nil;self.pending=nil;self.chunks=nil
  end
  return self
end
return M
