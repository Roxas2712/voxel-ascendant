-- Shared KASC/VASC status screen. Measures actual received/verified bytes only.
local M={}
function M.new(game,session,Text)
 local F=require('src.render.Font')
 local G=love.graphics
 local ok,inkShader=pcall(G.newShader,[[
 extern vec4 ink;
 vec4 effect(vec4 color, Image tex, vec2 uv, vec2 xy) {
  return vec4(ink.rgb, ink.a * color.a * Texel(tex,uv).a);
 }
 ]])
 if not ok then inkShader=nil end
 local self={opaque=true,isOpaque=true,ascendantContentInventory=true,key='vasc_content_status',index=1,items={}}
 local function tr(en,de)return session.de and de or en end
 local function clean(s)
  s=tostring(s or '')
  for a,b in pairs({['ä']='ae',['ö']='oe',['ü']='ue',['ß']='ss',['é']='e',['–']='-',['—']='-'})do s=s:gsub(a,b)end
  return s:gsub('[^\32-\126]','')
 end
 local function fit(s,w)
  s=clean(s);if F.width(s)<=w then return s end
  while #s>0 and F.width(s..'..')>w do s=s:sub(1,-2)end
  return s..'..'
 end
 local function text(s,x,y,color)
  local previous=G.getShader()
  if inkShader then inkShader:send('ink',color or {1,1,1,1});G.setShader(inkShader)end
  G.setColor(1,1,1,1);F.draw(fit(s,296),x,y);G.setShader(previous)
 end
 local function snapshot()
  local m=session.maintenance
  if m and(m.state=='checking'or m.state=='paused'or m.state=='error'or m.state=='restart_required'or m.state=='ready'and session.activeOperation=='maintenance')then
   return {state=m.state=='ready'and'ready'or m.state=='error'and'error'or m.state=='paused'and'cancelled'or'downloading',stage='checking',checkingInventory=true,maintenance=true,
    healthy=m.state=='ready'and m.result=='healthy',restartRequired=m.state=='restart_required',
    totalBytes=m.job and #m.job.ids or 0,doneBytes=m.checked,total=m.job and #m.job.ids or 0,completed=m.checked,speed=0,elapsed=0,attempt=0,error=m.error}
  end
  if session.pendingDownloadIds then
   local checked,total=session:inventoryProgress(session.pendingDownloadIds)
   return {state='downloading',stage='checking',checkingInventory=true,totalBytes=total,doneBytes=checked,
    speed=0,completed=checked,total=total,attempt=0,elapsed=0}
  end
  local p=session.installer:progress()
  local imp=session.importer
  if imp and session.activeOperation=='import'then
   p.state=imp.state=='error'and'error'or imp.state=='ready'and'ready'or imp.state=='cancelled'and'cancelled'or'downloading'
   p.stage='installing';p.error=imp.error;p.total=1;p.completed=imp.state=='ready'and 1 or 0
   p.totalBytes=#(imp.chunks or {});p.doneBytes=math.min(p.totalBytes,(imp.index or 1)-1);p.speed=0;p.isImport=true;p.current=imp.current
  end
  return p
 end
 function self:uiSize()return 320,288 end
 function self:sgbPalettes()return {require('src.render.PaletteFX').trueColorZone(0,0,39,35)}end
 function self:refresh()
  local selected=self.items[self.index];local selectedAction=selected and selected.action
  self.progress=snapshot();local p=self.progress
  if self.ascendantContentRestart then
   local phase=session.restart.phase
   self.items=(phase=='save_error'or phase=='restart_error')and{{label=tr('RETRY SAVE / RESTART','SPEICHERN / NEUSTART WIEDERHOLEN'),action='restart'}}or{}
   self.index=1;return
  end
  if p.current then session.lastPackage=p.current.id end
  local items={}
  if session.maintenance and session.maintenance.state=='restart_required'then
   items={{label=tr('BACK - RESTART REQUIRED','ZURUECK - NEUSTART ERFORDERLICH'),action='back'}}
  elseif p.state=='downloading'then
   items={{label=p.checkingInventory and tr('CANCEL','ABBRECHEN')or tr('PAUSE DOWNLOAD','DOWNLOAD PAUSIEREN'),action='cancel'},
    {label=tr('BACK - DOWNLOAD CONTINUES','ZURUECK - DOWNLOAD LAEUFT WEITER'),action='back'}}
  else
   if p.state~='ready'and(session.downloadIds or session.maintenance and session.maintenance:pending())then items[#items+1]={label=tr('RESUME MISSING DOWNLOADS','FEHLENDE DOWNLOADS FORTSETZEN'),action='retry'}end
   if p.state~='ready' and p.state~='idle'then
    items[#items+1]={label=tr('IMPORT DOWNLOADED FILE','GELADENE DATEI IMPORTIEREN'),action='import'}
    if session.lastPackage then items[#items+1]={label=tr('OPEN ALTERNATIVE DOWNLOAD LINKS','ALTERNATIVE DOWNLOAD-LINKS'),action='manual'}end
   end
   items[#items+1]={label=tr('BACK','ZURUECK'),action='back'}
  end
  self.items=items;self.index=math.max(1,math.min(self.index,#items))
  if selectedAction then
   local found,back
   for i,row in ipairs(items)do if row.action==selectedAction then found=i end;if row.action=='back'then back=i end end
   self.index=found or back or 1
  end
 end
 function self:update()
  self:refresh();local input=game.input
  if self.ascendantContentRestart then
   if self.items[1]and input:wasPressed('a')then session.restart:retry()end
   return
  end
  if input:wasPressed('up')then self.index=(self.index-2)%#self.items+1
  elseif input:wasPressed('down')then self.index=self.index%#self.items+1
  elseif input:wasPressed('b')then game.stack:pop()
  elseif input:wasPressed('a')then
   local a=self.items[self.index].action
   if a=='back'then game.stack:pop()
   elseif a=='cancel'then if session.maintenance and session.maintenance:pending()then session.maintenance:pause()end;session.pendingDownloadIds=nil;session.installer:cancel();if session.importer then session.importer:cancel()end;self.index=1;self:refresh()
   elseif a=='retry'then if session.maintenance and session.maintenance:pending()then session.maintenance:resume()else session:confirmDownload(session.downloadIds,session.downloadIncludesCobblemon)end
   elseif a=='import'then session:openPackageImport(session.lastPackage)
   elseif a=='manual'and session.lastPackage then session:openManual(session.lastPackage,session.de)end
  end
 end
 function self:draw()
  if self.ascendantContentRestart then
   local r=session.restart
   G.push('all');G.setShader();G.setColor(.035,.08,.15,1);G.rectangle('fill',0,0,320,288)
   G.setColor(.16,.5,.7,1);G.rectangle('line',4,4,312,280)
   text(session.maintenance and session.maintenance:pending()and tr('SPRITE MAINTENANCE','SPRITE-WARTUNG')or tr('SPRITES INSTALLED','SPRITES INSTALLIERT'),12,18,{1,.76,.24,1})
   text(tr('RESTART REQUIRED','NEUSTART ERFORDERLICH'),12,45)
   local phase=r.phase
   local message=phase=='save_error'and tr('SAVE FAILED - GAME STAYS OPEN','SPEICHERN FEHLGESCHLAGEN')
    or phase=='restart_error'and tr('RESTART FAILED','NEUSTART FEHLGESCHLAGEN')
    or phase=='saving'and tr('SAVING YOUR GAME...','SPIEL WIRD GESPEICHERT...')
    or (phase=='restarting'or phase=='restarted')and tr('RESTARTING...','NEUSTART...')
    or tr('RESTART IN ','NEUSTART IN ')..math.ceil(r.remaining)..' s'
   text(message,12,83,{1,.76,.24,1})
   text(r.inGame and tr('Your progress is saved first.','Dein Fortschritt wird gespeichert.')or tr('No active game to save.','Kein laufendes Spiel zu speichern.'),12,113)
   text(session.maintenance and session.maintenance:pending()and tr('Cleanup runs after restarting.','Bereinigung startet nach Neustart.')or tr('New sprites load after restarting.','Neue Sprites laden nach Neustart.'),12,141)
   if phase=='restarted'then
    text(tr('If the app closes, reopen it.','Falls die App schliesst: neu oeffnen.'),12,175)
   elseif self.items[1]then
    text(tr('A: RETRY SAVE / RESTART','A: SPEICHERN / NEUSTART ERNEUT'),12,202)
   end
   G.pop();return
  end
  local p=self.progress or snapshot();local done=p.state=='ready';local failed=p.state=='error';local paused=p.state=='cancelled'
  G.push('all');G.setShader();if inkShader then G.setColor(.035,.08,.15,1)else G.setColor(.85,.9,.95,1)end;G.rectangle('fill',0,0,320,288)
  G.setColor(.16,.5,.7,1);G.rectangle('line',4,4,312,280)
  text(tr('ASCENDANT DOWNLOADS','ASCENDANT DOWNLOADS'),12,12)
  local stage=p.healthy and tr('SPRITES VERIFIED','SPRITES GEPRUEFT')or p.restartRequired and tr('RESTART REQUIRED','NEUSTART ERFORDERLICH')or p.state=='idle'and tr('NO ACTIVE DOWNLOAD','KEIN LAUFENDER DOWNLOAD')or done and tr('INSTALLED - RESTART THE GAME','INSTALLIERT - SPIEL NEU STARTEN')
    or failed and tr('DOWNLOAD STOPPED','DOWNLOAD ANGEHALTEN')
    or paused and tr('PAUSED - PROGRESS SAVED','PAUSIERT - FORTSCHRITT GESPEICHERT')
    or p.stage=='installing'and tr('CHECKING AND INSTALLING','PRUEFEN UND INSTALLIEREN')
    or p.stage=='retrying'and tr('TRYING ANOTHER SERVER','ANDERER SERVER WIRD VERSUCHT')
    or p.stage=='checking'and tr('CHECKING EXISTING SPRITES','VORHANDENE SPRITES PRUEFEN')
    or tr('DOWNLOADING','WIRD HERUNTERGELADEN')
  text(stage,12,32,{1,.76,.24,1})
  local current=p.current or session.catalog.packages[session.lastPackage]
  local name=current and (session.downloadFamilyLabels[current.family]or current.family)or''
  if current and current.adapter=='existing-HdContentStore'then
   local gen=tonumber(current.id:match('%.g(%d+)%.'))
   name=tr('HD walking sprites','HD-Laufsprites')..' - '..(({[1]='Kanto',[2]='Johto',[3]='Hoenn'})[gen]or'Pokemon')
  end
  text(name,12,52)
  local first,last
  if current then first,last=current.id:match('dex(%d+)%-(%d+)')end
  text((first and ('Pokemon '..tonumber(first)..'-'..tonumber(last)..'  ')or'')..tr('Package ','Paket ')..math.min(p.total,p.completed+1)..' / '..p.total,12,67)
  local ratio=p.totalBytes>0 and math.min(1,p.doneBytes/p.totalBytes)or 0
  if done then ratio=1 end
  G.setColor(.12,.21,.31,1);G.rectangle('fill',12,86,296,15)
  G.setColor(.25,.8,.58,1);G.rectangle('fill',13,87,294*ratio,13)
  local percent=tostring(math.floor(ratio*100));local px=144+F.width(percent)
  text(percent,144,90,{1,1,1,1});G.setColor(1,1,1,1)
  G.rectangle('fill',px+1,91,2,2);G.rectangle('fill',px+5,95,2,2)
  for i=0,4 do G.rectangle('fill',px+5-i,91+i,1,1)end
  text(p.checkingInventory and (tr('Checked packages: ','Gepruefte Pakete: ')..p.doneBytes..' / '..p.totalBytes)or p.isImport and (tr('Verified parts: ','Gepruefte Teile: ')..p.doneBytes..' / '..p.totalBytes)or string.format('%.1f / %.1f MiB',p.doneBytes/1048576,p.totalBytes/1048576),12,110)
  text(p.healthy and tr('No repair or restart needed.','Keine Reparatur, kein Neustart noetig.')or p.restartRequired and tr('Cleanup runs after restarting.','Bereinigung startet nach Neustart.')or p.checkingInventory and (paused and tr('Check paused. Resume when ready.','Pruefung pausiert. Bei Bedarf fortsetzen.')or failed and tr('Check stopped. See error below.','Pruefung gestoppt. Fehler siehe unten.')or tr('Download starts automatically.','Download startet automatisch.'))or p.isImport and tr('Importing your local file','Lokale Datei wird importiert')or tr('Average: ','Durchschnitt: ')..(p.speed>0 and string.format('%.0f KiB/s',p.speed/1024)or (done and '0 KiB/s' or tr('waiting for data','warte auf Daten'))),12,126)
  local detail=p.state=='idle'and tr('Choose a collection to download.','Eine Sammlung zum Laden auswaehlen.')or done and tr('All selected packages are installed.','Alle gewaehlten Pakete installiert.')
    or failed and Text.message(p.error,session.de)
    or paused and tr('Resume skips completed packages.','Fortsetzen behaelt fertige Pakete.')
    or p.stage=='retrying'and (tr('Automatic retry in ','Neuer Versuch in ')..p.retrySeconds..' s')
    or p.checkingInventory and tr('Existing sprites are kept.','Vorhandene Sprites bleiben erhalten.')
    or p.stage=='installing'and tr('Verifying files. Please wait.','Dateien werden geprueft. Bitte warten.')
    or ((p.server or tr('Connecting','Verbinden'))..'  '..math.floor(p.elapsed or 0)..' s'..string.rep('.',math.floor(p.elapsed or 0)%3+1)..(p.attempt>1 and (' - '..tr('attempt ','Versuch ')..p.attempt)or''))
  text(detail,12,145)
  text((p.checkingInventory and tr('Checked: ','Geprueft: ')or tr('Installed: ','Installiert: '))..p.completed..' / '..p.total,12,162)
  for i,row in ipairs(self.items)do
   local y=182+(i-1)*19
   G.setColor(i==self.index and .28 or .09,i==self.index and .36 or .16,.25,1);G.rectangle('fill',10,y,300,17)
   if i==self.index then G.setColor(1,.76,.24,1);G.rectangle('fill',12,y+4,3,9)end
   text(row.label,20,y+5)
  end
  text(tr('A: SELECT   B: BACK','A: WAHL   B: ZURUECK'),12,270)
  G.pop()
 end
 self:refresh();return self
end
return M
