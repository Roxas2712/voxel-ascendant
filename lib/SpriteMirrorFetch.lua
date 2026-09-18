-- Bounded, single-flight GET with independent mirrors and timed retries.
-- Routes/expected hashes come from a trusted bundled or authenticated catalog.
local M={MAX_BYTES=4194304}
local function validBase(s)
  if type(s)~="string" or #s>512 or s:find("[%s@?#\\]") or s:find("..",1,true) then return false end
  return s:match("^https://[%w.-]+[/ %w_.%-]*$")~=nil and not s:find("%%")
end
function M.new(d)
  assert(d.transport and d.now and d.sha256,"missing transport dependency")
  local mirrors,providers={},{}
  for _,m in ipairs(d.mirrors or {}) do
    if m.enabled==true then
      assert(validBase(m.baseUrl),"invalid HTTPS mirror base")
      assert(type(m.provider)=="string" and (not providers[m.provider] or m.sameProviderRoute==true),"mirrors must use independent providers")
      if m.shards then assert(#m.shards==4,"four shard origins required");for _,base in ipairs(m.shards)do assert(validBase(base),"invalid shard HTTPS base")end end
      providers[m.provider]=true;mirrors[#mirrors+1]={id=m.id,baseUrl=m.baseUrl:gsub("/$",""),provider=m.provider,shards=m.shards}
    end
  end
  assert(#mirrors<=3,"maximum three mirrors")
  local self={state="idle",events={},mirrors=mirrors}
  local function release()
    if self.job then pcall(d.transport.release,d.transport,self.job);self.job=nil end
  end
  local function diagnostic(name,fields)if d.diagnostics then pcall(d.diagnostics.event,d.diagnostics,name,fields) end end
  local function event(reason)
    self.events[#self.events+1]={mirror=self.mirror and self.mirror.id,reason=({timeout=true,http_error=true,poll_failed=true,request_start_failed=true,size_mismatch=true,checksum_mismatch=true,tls_error=true,dns_error=true,rate_limited=true})[reason] and reason or "transport_error",attempt=self.attempt}
    if #self.events>24 then table.remove(self.events,1) end
  end
  local function failed(reason,httpStatus)
    local known={timeout=true,http_error=true,poll_failed=true,request_start_failed=true,size_mismatch=true,checksum_mismatch=true}
    if not known[reason] then
      local raw=type(reason)=="string" and reason:lower() or ""
      if raw:find("certificate",1,true) or raw:find("tls",1,true) or raw:find("ssl",1,true) then reason="tls_error"
      elseif raw:find("resolve",1,true) or raw:find("dns",1,true) then reason="dns_error"
      elseif raw:find("timeout",1,true) or raw:find("timed out",1,true) then reason="timeout"
      elseif httpStatus==429 then reason="rate_limited"
      else reason="http_error" end
    end
    diagnostic("request_failed",{mirror=self.mirror and self.mirror.id,attempt=self.attempt,code=reason,httpStatus=httpStatus});event(reason);release()
    if self.attempt>=#mirrors*2 then self.state="error";self.error=reason;return end
    self.state="waiting";self.retryAt=d.now()+math.min(2^(self.attempt-1),8)
  end
  function self:start(path,bytes,hash)
    if self.state=="fetching" or self.state=="waiting" then return false,"busy" end
    if #mirrors==0 then return false,"no_published_mirrors" end
    if type(path)~="string" or not path:match("^/[%w/_%.%-]+$") or path:find("..",1,true) then return false,"invalid_route" end
    if type(bytes)~="number" or bytes%1~=0 or bytes<1 or bytes>M.MAX_BYTES then return false,"invalid_size" end
    if type(hash)~="string" or #hash~=64 or hash:find("[^a-f0-9]") then return false,"invalid_digest" end
    self.path=path;self.bytes=bytes;self.hash=hash;self.attempt=0;self.body=nil;self.error=nil
    self.startMirror=self.preferredMirror or 1
    self.receivedBytes=0;self.events={};self.state="waiting";self.retryAt=d.now();return true
  end
  function self:update()
    if self.state=="waiting" and d.now()>=self.retryAt then
      self.attempt=self.attempt+1;self.receivedBytes=0
      self.mirrorIndex=((self.startMirror or 1)+self.attempt-2)%#mirrors+1
      self.mirror=mirrors[self.mirrorIndex]
      diagnostic("request_started",{mirror=self.mirror.id,attempt=self.attempt,bytes=self.bytes})
      local origin=self.mirror.baseUrl
      if self.mirror.shards then origin=self.mirror.shards[tonumber(self.hash:sub(1,1),16)%4+1]end
      local ok,job,err=pcall(d.transport.get,d.transport,origin..self.path,
        {maxSeconds=30,boundedHttpsGet=1,maxBytes=self.bytes})
      if not ok or not job then failed(err or "request_start_failed");return end
      self.job=job;self.deadline=d.now()+30;self.state="fetching"
    end
    if self.state~="fetching" then return end
    if d.now()>=self.deadline then
      pcall(d.transport.cancel,d.transport,self.job);failed("timeout");return
    end
    local ok,r=pcall(d.transport.poll,d.transport,self.job)
    if not ok or type(r)~="table" then failed("poll_failed");return end
    if r.status=="pending" then
      self.receivedBytes=math.max(0,math.min(self.bytes,tonumber(r.receivedBytes) or 0));return end
    if r.status~="ok" then failed(r.err or "http_error",r.httpStatus or r.statusCode);return end
    if type(r.body)~="string" or #r.body~=self.bytes then failed("size_mismatch");return end
    local hashed,h=pcall(d.sha256,r.body)
    if not hashed or h~=self.hash then failed("checksum_mismatch");return end
    diagnostic("request_verified",{mirror=self.mirror.id,attempt=self.attempt,bytes=self.bytes})
    self.preferredMirror=self.mirrorIndex
    self.body=r.body;release();self.state="ready"
  end
  function self:cancel()
    if self.job then pcall(d.transport.cancel,d.transport,self.job) end
    release();self.body=nil;self.state="cancelled"
  end
  return self
end
return M
