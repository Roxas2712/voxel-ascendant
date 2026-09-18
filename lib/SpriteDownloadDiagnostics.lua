-- Bounded local diagnostics + durable retry queue. No device/user identity or raw URLs.
-- post/poll/release are supplied by the native transport adapter. A report is removed
-- only after a matching server acknowledgement, so the receiver must deduplicate IDs.
local M={KEY="sprite-content/diagnostics-v1.json"}
local EVENTS={started=true,package_started=true,request_started=true,request_verified=true,
  request_failed=true,chunk_cached=true,chunk_stored=true,package_verified=true,success=true,error=true,cancelled=true}
local CODES={tls_error=true,dns_error=true,rate_limited=true,timeout=true,http_error=true,poll_failed=true,request_start_failed=true,
  size_mismatch=true,checksum_mismatch=true,chunk_verification_failed=true,cache_write_failed=true,
  manifest_hash_mismatch=true,invalid_manifest=true,package_size_mismatch=true,missing_or_corrupt_chunk=true,
  file_hash_mismatch=true,receipt_write_failed=true,legacy_manifest_mismatch=true,legacy_package_size_mismatch=true,
  no_published_mirrors=true,manifest_verification_failed=true,incomplete_package=true,activation_write_failed=true,
  manifest_write_failed=true,package_not_published=true,interrupted=true,unknown_error=true}
local function token(s,max)return type(s)=="string" and #s<=(max or 160) and s:match("^[a-zA-Z0-9_.-]+$") and s or nil end
function M.new(d)
  assert(d.cache and d.encode and d.decode and d.now and d.newId,"missing diagnostic dependency")
  local self={state={history={},outbox={}},warning=nil,nextTry=0}
  local ok,raw=pcall(d.cache.read,d.cache,M.KEY)
  if ok and type(raw)=="string" and #raw<=4194304 then
    local decoded,s=pcall(d.decode,raw)
    if decoded and type(s)=="table" and type(s.history)=="table" and type(s.outbox)=="table" then self.state=s end
  end
  local function save()
    local raw=d.encode(self.state)
    if #raw>4194304 then self.warning="diagnostic_limit";return false end
    local ok,yes=pcall(d.cache.write,d.cache,M.KEY,raw)
    if not ok or yes~=true then self.warning="diagnostic_write_failed";return false end
    local read,back=pcall(d.cache.read,d.cache,M.KEY)
    if not read or back~=raw then self.warning="diagnostic_write_failed";return false end
    return true
  end
  function self:begin()
    local id=assert(token(d.newId(),80),"invalid diagnostic ID")
    self.current={id=id,startedAt=d.now(),events={},counts={},version=token(d.version,80),platform=token(d.platform,40)}
    self:event("started",{});self.state.active=self.current;save();return id
  end
  function self:event(name,fields)
    if not self.current or not EVENTS[name] then return end
    fields=fields or {};local event={name=name,at=d.now()}
    for _,k in ipairs({"packageId","mirror"}) do event[k]=token(fields[k]) end
    for _,k in ipairs({"attempt","bytes","doneBytes","httpStatus"}) do
      local n=fields[k];if type(n)=="number" and n>=0 and n<9007199254740991 then event[k]=math.floor(n) end
    end
    if fields.code then event.code=CODES[fields.code] and fields.code or "unknown_error" end
    self.current.counts[name]=(self.current.counts[name] or 0)+1
    local events=self.current.events;events[#events+1]=event
    if #events>512 then table.remove(events,1);self.current.earlierEventsOmitted=true end
    -- Persist useful checkpoints; request bodies, URLs, transport text, paths and ROMs are never accepted.
    if name=="package_verified" or name=="request_failed" then self.state.active=self.current;save() end
  end
  function self:finish(outcome,fields)
    if not self.current then return false,"no_active_diagnostic" end
    assert(outcome=="success" or outcome=="error" or outcome=="cancelled")
    self:event(outcome,fields);local report=self.current
    report.outcome=outcome;report.finishedAt=d.now();self.current=nil;self.state.active=nil
    self.state.history[#self.state.history+1]=report
    if #self.state.history>10 then table.remove(self.state.history,1) end
    if outcome~="cancelled" then
      if #self.state.outbox>=32 then self.warning="report_queue_full"
      else self.state.outbox[#self.state.outbox+1]=report end
    end
    return save()
  end
  function self:update()
    -- Reporting failure must never fail or undo a verified sprite download.
    if not d.transport or not d.endpoint then self.warning="report_endpoint_not_configured";return end
    if not d.endpoint:match("^https://[%w.-]+/[%w/_-]+$") then self.warning="invalid_report_endpoint";return end
    local report=self.state.outbox[1];if not report or d.now()<self.nextTry then return end
    local function retry()
      if self.job then
        if d.transport.cancel then pcall(d.transport.cancel,d.transport,self.job) end
        pcall(d.transport.release,d.transport,self.job);self.job=nil end
      report.attempts=(report.attempts or 0)+1;self.nextTry=d.now()+math.min(30*2^math.min(report.attempts,7),3600)
      self.warning="report_pending_retry";save()
    end
    if not self.job then
      local payload={schema="vasc.download-report/v1",reportId=report.id,outcome=report.outcome,
        startedAt=report.startedAt,finishedAt=report.finishedAt,version=report.version,platform=report.platform,events=report.events,counts=report.counts,earlierEventsOmitted=report.earlierEventsOmitted}
      local body=d.encode(payload)
      if #body>262144 then self.warning="report_too_large";return end
      local ok,job=pcall(d.transport.post,d.transport,d.endpoint,body,{contentType="application/json",maxBytes=4096,maxSeconds=15})
      if not ok or not job then return retry() end
      self.job=job;self.deadline=d.now()+15
    end
    local ok,response=pcall(d.transport.poll,d.transport,self.job)
    if not ok or type(response)~="table" then return retry() end
    if response.status=="pending" and d.now()<self.deadline then return end
    if response.status~="ok" or type(response.body)~="string" or #response.body>4096 then return retry() end
    local parsed,ack=pcall(d.decode,response.body)
    if not parsed or type(ack)~="table" or ack.accepted~=true or ack.reportId~=report.id then return retry() end
    pcall(d.transport.release,d.transport,self.job);self.job=nil
    table.remove(self.state.outbox,1);self.warning=nil;save()
  end
  -- A process that stopped during a transfer left no terminal report. Preserve
  -- its operation ID and failed-request checkpoints when reporting interruption.
  local active=self.state.active
  if type(active)=='table' and token(active.id,80) and type(active.events)=='table'
    and #active.events<=512 and type(active.counts)=='table' and type(active.startedAt)=='number' then
    self.current=active;self:finish('error',{code='interrupted'})
  elseif active~=nil then self.state.active=nil;save()end
  return self
end
return M
