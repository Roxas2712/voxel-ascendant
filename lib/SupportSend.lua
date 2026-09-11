-- Manual-only support transport through the existing mod.postLog API.
-- No URL is accepted from a menu/save: the reviewed manifest owns the target.
local M = {}
function M.new(mod, getLog)
  local S={state="idle",code=""}
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
  function S.payload()
    local ok,log,reason=pcall(getLog)
    if not ok or type(log)~="string" or #log==0 then return nil,reason or "no-log" end
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
    local prefix="ASCENDANT-SUPPORT/1\nmod="..mod.id.."\nversion="..head(clean(mod.version or "unknown"),120)
      .."\ntime="..tostring(os.time()).."\nplatform="..clean(osOK and platform or "unknown").."\n"
    local evidence="runtime-evidence=unavailable"
    local recorder=mod._vascRuntimeDiagnostics
    if recorder and type(recorder.evidence)=="function" then
      local good,value=pcall(recorder.evidence)
      if good and type(value)=="string" then evidence=value end
    end
    local report=prefix.."support-code="..S.code.."\n"..head(downloadLines(),4000)
      .."\n--- RUNTIME EVIDENCE ---\n"..head(clean(evidence),16000)
      .."\n--- FAILURE SUMMARY ---\n"..failureSummary..downloadLog()
      .."\n--- SESSION LOG ---\n"
    local budget=48*1024-#report
    if #log>budget then
      local marker="\n[older middle records omitted]\n"
      log=head(log,math.min(3000,budget))..marker..tail(log,math.max(0,budget-3000-#marker))
    end
    report=report..log
    if #report>48*1024 then return nil,"too-large" end
    return report
  end
  function S.available()
    return type(mod.postLog)=="function" and type(mod.manifest)=="table"
      and type(mod.manifest.log_url)=="string" and mod.manifest.log_url:match("^https://")~=nil
      and mod.fetch and type(mod.fetch.poll)=="function" and type(mod.fetch.release)=="function"
  end
  local function release(cancel)
    if not job then return end
    if cancel and mod.fetch.cancel then pcall(mod.fetch.cancel,mod.fetch,job) end
    pcall(mod.fetch.release,mod.fetch,job);job=nil
  end
  function S.send()
    if not S.available() then S.state="not-configured";return false,S.state end
    if job then return false,"pending" end
    if not S.code:match("^%d%d%d%d%d%d%d%d$") then S.state="code-required";return false,S.state end
    if lastSend and clock()-lastSend<30 then S.state="cooldown";return false,S.state end
    local body,why=S.payload()
    if not body then S.state=why or "no-log";return false,S.state end
    local ok,handle=pcall(mod.postLog,mod,body,{format="text"})
    if not ok or not handle then S.state="failed";return false,S.state end
    job,sentAt,lastSend=handle,clock(),clock();S.state="pending"
    return true,S.state
  end
  function S.poll()
    if not job then return S.state end
    local ok,status=pcall(mod.fetch.poll,mod.fetch,job)
    if not ok or type(status)~="table" then release(true);S.state="failed"
    elseif status.status~="pending" then
      -- postLog discards the response body; the engine confirms HTTP success.
      -- Our receiver returns success only after the report has been written.
      S.state=status.status=="ok" and "saved" or "failed"
      release(false)
    elseif clock()-sentAt>40 then release(true);S.state="timeout" end
    return S.state
  end
  function S.cancel() if job then release(true);S.state="cancelled" end end
  function S.open(game,de)
    local function tr(en,german)return de and german or en end
    local titles={idle=tr("READY","BEREIT"),pending=tr("SENDING","SENDET"),saved=tr("SENT","GESENDET"),
      failed=tr("FAILED","FEHLER"),cancelled=tr("CANCEL","ABBRUCH"),timeout=tr("TIMEOUT","TIMEOUT"),
      cooldown=tr("WAIT","WARTEN"),["not-configured"]=tr("OFFLINE","OFFLINE"),["code-required"]=tr("ENTER CODE","CODE EINGEBEN")}
    local armed=false
    local consent=tr("Send a bounded log excerpt, installed mod versions, renderer, scene timings and available HD download errors to the developer for troubleshooting? No save file is attached. Press A again to send. Nothing is sent automatically. Ask the developer for a support code (valid 24 hours, once per mod).",
      "Begrenzten Log-Ausschnitt, installierte Mod-Versionen, Renderer, Szenenmessungen und verfügbare HD-Download-Fehler zur Fehleranalyse an den Entwickler senden? Kein Spielstand wird angehängt. Zum Senden erneut A drücken. Kein automatischer Versand. Support-Code beim Entwickler anfordern (24 Stunden gültig, einmal je Mod).")
    local rows={{label=tr("SEND SUPPORT LOG","SUPPORT-LOG SENDEN"),action="send",help=consent},
      {label=tr("STATUS","STATUS"),action="status",right="",help=consent},
      {label=tr("CANCEL SEND","VERSAND ABBRECHEN"),action="cancel"}}
    local digits={}
    for i=1,8 do
      digits[i]=tonumber(S.code:sub(i,i))
      rows[#rows+1]={label=tr("CODE DIGIT ","CODE ZIFFER ")..i,action="digit",digit=i,right=digits[i] and tostring(digits[i]) or "?",help=tr("A: increase digit (0-9). Enter the eight-digit code, then select SEND SUPPORT LOG.","A: Ziffer erhöhen (0-9). Achtstelligen Code eingeben, dann SUPPORT-LOG SENDEN wählen.")}
    end
    local Factory=mod.ui.KantoListMenu or mod.ui.ListMenu
    local menu=Factory.new(game,mod.id=="kanto_ascendant" and "KASC SUPPORT" or "VASC SUPPORT",rows,{
      rows=5,pageJump=true,footer=tr("A:SELECT B:BACK","A:WAHL B:ZURÜCK"),
      onChoose=function(item)
        if item.action=="digit" then
          armed=false;rows[1].right=""
          digits[item.digit]=((digits[item.digit] or -1)+1)%10;item.right=tostring(digits[item.digit])
          local code=""
          for i=1,8 do code=code..(digits[i] and tostring(digits[i]) or "?") end
          S.code=code
        elseif item.action=="send" then
          if not S.available() then S.state="not-configured";return end
          if not armed then armed=true;item.right=tr("A:CONFIRM","A:BESTÄTIGEN")
            local ui=mod.exports and mod.exports.ascendantUi
            if ui and ui.showHelp then ui.showHelp(game,item.label,consent)
            elseif mod.ui.push then mod.ui.push(game,"VascHelp",{title=item.label,body=consent}) end
            return
          end
          armed=false;item.right="";S.send()
        elseif item.action=="cancel" then armed=false;S.cancel() end
      end,
      onCancel=function()S.cancel()end,
    })
    local base=menu.update
    function menu:update(...)
      local state=S.poll()
      if not S.available() then state="not-configured" end
      rows[2].right=titles[state] or tr("NO LOG","KEIN LOG")
      if base then return base(self,...) end
    end
    game.stack:push(menu);return true
  end
  return S
end
return M
