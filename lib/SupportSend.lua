-- Manual-only support transport, including the iOS 0.2.61 request bridge.
-- No URL is accepted from a menu/save: the reviewed manifest owns the target.
local M = {}
-- Correlation only, never an authentication credential or a player identity.
function M.newReportId()
  local random=love and love.math and love.math.random or math.random
  local parts={}
  for i=1,4 do parts[i]=string.format("%04x",random(0,65535)) end
  return table.concat(parts)
end
function M.new(mod, getLog)
  local S={state="idle",reportId=nil}
  local job, sentAt, lastSend
  local function clock() return love and love.timer and love.timer.getTime and love.timer.getTime() or os.time() end
  local function clean(s)
    s=tostring(s or "")
    return s:gsub("https?://%S+","[url]")
      :gsub("/Users/[^/%s]+","/Users/[redacted]")
      :gsub("/home/[^/%s]+","/home/[redacted]")
      :gsub("([A-Za-z]:[\\/]Users[\\/])[^\\/%s]+","%1[redacted]")
      :gsub("[Tt]oken[=:]%s*%S+","token=[redacted]")
      :gsub("[Aa]uthorization[=:]%s*[^\r\n]+","authorization=[redacted]")
      :gsub("[%z\1-\8\11\12\14-\31]", "?")
  end
  local function tail(s,n)
    local at=math.max(1,#s-n+1)
    while at<=#s and s:byte(at)>=128 and s:byte(at)<=191 do at=at+1 end
    return s:sub(at)
  end
  local function head(s,n)
    if #s<=n then return s end
    local last=n
    while last>0 and s:byte(last)>=128 and s:byte(last)<=191 do last=last-1 end
    if s:byte(last) and s:byte(last)>=192 then last=last-1 else last=n end
    return s:sub(1,last)
  end
  local function downloadLines()
    local owner=mod
    if not (owner.exports and owner.exports.pokemonHdContent) and type(mod.find)=="function" then
      local ok,other=pcall(mod.find,mod,"VOXEL_ASCENDANT")
      if ok and type(other)=="table" then owner=other end
    end
    local api=owner.exports and owner.exports.pokemonHdContent
    local ok,d=pcall(function()return api and api.downloader()end)
    if not ok or type(d)~="table" then return "downloads=unavailable\n" end
    local lines={"downloads="..clean(d.status),"download-message="..head(clean(d.message),800),
      "download-bytes="..tostring(tonumber(d.doneBytes) or 0).."/"..tostring(tonumber(d.totalBytes) or 0)}
    if d.current and type(d.current.id)=="string" then lines[#lines+1]="download-package="..head(clean(d.current.id),120) end
    for _,e in ipairs(d.supportFailures or {}) do
      lines[#lines+1]="download-error="..head(clean(e),800)
    end
    return table.concat(lines,"\n").."\n"
  end
  local function downloadLog()
    local owner=mod
    if mod.id~="kanto_ascendant" and type(mod.find)=="function" then
      local ok,other=pcall(mod.find,mod,"kanto_ascendant")
      if ok then owner=other end
    end
    local cache=owner and owner.cache
    if cache and type(cache.read)=="function" then
      local ok,body=pcall(cache.read,cache,"KASC-HD-DOWNLOAD-LOG.txt")
      if ok and type(body)=="string" and body:find("KASC HD download log v1",1,true)==1 then
        return "\n--- HD DOWNLOAD DIAGNOSTICS ---\n"..tail(clean(body),4000)
      end
    end
    return ""
  end
  function S.payload(limit)
    limit=limit or 500*1024
    local ok,log,reason=pcall(getLog)
    if not ok or type(log)~="string" or #log==0 then
      log="Session log unavailable: "..clean(reason or "no recorded session").."\nCurrent diagnostics are attached below."
    end
    log=clean(log)
    -- Keep the last failure summaries even when verbose retries fill the tail.
    local failures={}
    for line in log:gmatch("[^\n]+") do
      if line:find("event=vasc.battle.battle-hud-camera-failure",1,true)
          or line:find("event=vasc.battle.battle-native-latch",1,true) then
        failures[#failures+1]=line
        if #failures>4 then table.remove(failures,1) end
      end
    end
    local failureSummary=head(table.concat(failures,"\n"),4000)
    local sys=love and love.system
    local osOK,platform=pcall(function()return sys and sys.getOS and sys.getOS()end)
    local prefix="ASCENDANT-SUPPORT/2\nmod="..mod.id.."\nversion="..head(clean(mod.version or "unknown"),120)
      .."\ntime="..tostring(os.time()).."\nplatform="..clean(osOK and platform or "unknown").."\n"
    local evidence="runtime-evidence=unavailable"
    local recorder=mod._vascRuntimeDiagnostics
    if recorder and type(recorder.evidence)=="function" then
      local good,value=pcall(recorder.evidence)
      if good and type(value)=="string" then evidence=value end
    end
    local errors=mod.exports and mod.exports.errors
    local incidents={}
    if errors and errors.inbox then
      incidents[1]="recorded-incidents="..#errors.inbox.items
      local context=errors.inbox.context or {}
      for _,key in ipairs{"engine","platform","renderer","gpu","resolution","map","x","y","settings","performance"}do
        local value=context[key]
        if type(value)=="string" or type(value)=="number" then incidents[#incidents+1]=key.."="..tostring(value) end
      end
      for i=math.max(1,#errors.inbox.items-2),#errors.inbox.items do
        local good,value=pcall(errors.reportText,errors.inbox.items[i])
        if good and type(value)=="string" then incidents[#incidents+1]=value end
      end
    end
    local report=prefix.."report-id="..(S.reportId or "").."\nsend-ticket="..(S.ticket or "").."\n"..head(downloadLines(),4000)
      .."\n--- RUNTIME EVIDENCE ---\n"..head(clean(evidence),16000)
      .."\n--- FAILURE SUMMARY ---\n"..failureSummary..downloadLog()
      .."\n--- ERRORS ---\n"..head(clean(table.concat(incidents,"\n")),8000)
      .."\n--- SESSION LOG ---\n"
    local budget=limit-#report
    if #log>budget then
      local marker="\n[older middle records omitted]\n"
      log=head(log,math.min(3000,budget))..marker..tail(log,math.max(0,budget-3000-#marker))
    end
    report=report..log
    if #report>limit then return nil,"too-large" end
    return report
  end
  function S.ticketEndpoint()
    return mod.manifest.log_url:gsub("/[^/]+$","/ticket")
  end
  function S.available()
    return type(mod.postLog)=="function" and type(mod.manifest)=="table"
      and type(mod.manifest.log_url)=="string" and mod.manifest.log_url:match("^https://")~=nil
      and mod.fetch and type(mod.fetch.poll)=="function" and type(mod.fetch.release)=="function"
  end
  -- iOS 0.2.61 exposes httpRequest but not the dedicated httpPost bridge.
  -- Submit through the existing engine worker pool; never block the UI, retry
  -- a possibly delivered report, or accept an endpoint from a save/menu.
  local transport
  local function getTransport()
    if transport then return transport end
    local sys=love and love.system
    -- The mod-facing system facade hides native HTTP functions. Select by
    -- platform and let the engine worker resolve the available bridge.
    if sys and type(sys.getOS)=="function" and sys.getOS()=="iOS" then
      local ok,F=pcall(require,"src.net.Fetch")
      if ok and type(F)=="table" and type(F.request)=="function"
          and type(F.poll)=="function" and type(F.release)=="function" then
        transport={
          send=function(body)
            local url=mod.manifest.log_url
            if not url:match("^https://[^/%s]+") or #body>500*1024 then return nil end
            return F.request(url,{method="POST",body=body,
              headers={["Content-Type"]="text/plain"},
              userAgent="gen1recomp-mod/"..tostring(mod.id),maxSeconds=30})
          end,
          poll=function(id)
            local st=F.poll(id)
            if type(st)~="table" then return {status="error"} end
            if st.status=="pending" then return {status="pending"} end
            local code=tonumber(st.code)
            -- The request API considers any HTTP reply completed, including
            -- rejection. Only a 2xx means the receiver saved this report.
            return {status=st.status=="ok" and code and code>=200 and code<300 and "ok" or "error",code=code}
          end,
          release=function(id)return F.release(id)end,
          cancel=function(id)if F.cancel then return F.cancel(id)end end,
        }
      end
    end
    transport=transport or {
      send=function(body)return mod:postLog(body,{format="text"})end,
      poll=function(id)return mod.fetch:poll(id)end,
      release=function(id)return mod.fetch:release(id)end,
      cancel=function(id)if mod.fetch.cancel then return mod.fetch:cancel(id)end end,
    }
    return transport
  end
  local function release(cancel)
    if not job then return end
    if cancel then pcall(getTransport().cancel,job) end
    pcall(getTransport().release,job);job=nil
  end
  function S.send(reportId,ticket)
    if not S.available() then S.state="not-configured";return false,S.state end
    if job then return false,"pending" end
    if lastSend and clock()-lastSend<60 then S.state="cooldown";return false,S.state end
    if reportId~=nil and (type(reportId)~="string" or #reportId~=16 or reportId:find("[^0-9a-f]")) then
      return false,"invalid-report-id"
    end
    if type(ticket)~="string" or #ticket>120 or not ticket:match("^[0-9a-f:]+$") then return false,"ticket-required" end
    S.ticket=ticket
    S.reportId=reportId or M.newReportId()
    local body,why=S.payload()
    if not body then S.state=why or "no-log";return false,S.state end
    local ok,handle,reason=pcall(getTransport().send,body)
    if ok and not handle and tostring(reason or ""):find("too large",1,true) then
      -- Retry only a local engine rejection; never repeat an uncertain upload.
      body=S.payload(48*1024)
      if body then ok,handle=pcall(getTransport().send,body) end
    end
    if not ok or not handle then S.state="failed";return false,S.state end
    job,sentAt,lastSend=handle,clock(),clock();S.state="pending"
    return true,S.state
  end
  function S.poll()
    if not job then return S.state end
    local ok,status=pcall(getTransport().poll,job)
    if not ok or type(status)~="table" then release(true);S.state="failed"
    elseif status.status~="pending" then
      -- postLog discards the response body; the engine confirms HTTP success.
      -- Our receiver returns success only after the report has been written.
      S.state=status.status=="ok" and "saved" or ((status.code==429 or tostring(status.err or ""):find("429",1,true)) and "cooldown" or "failed")
      release(false)
    elseif clock()-sentAt>40 then release(true);S.state="timeout" end
    return S.state
  end
  function S.cancel() if job then release(true);S.state="cancelled" end end
  function S.open(game,de)
    local errors=mod.exports and mod.exports.errors
    if not (errors and errors.openSupport) then
      local function module(name)
        return assert((loadstring or load)(assert(mod:read("lib/"..name..".lua")),"@"..name))()
      end
      errors=module("ErrorsMenu").install(mod,module("ErrorInbox").new(),{language=function()return de and "de" or "en" end})
    end
    return errors.openSupport(game)
  end
  return S
end
return M
