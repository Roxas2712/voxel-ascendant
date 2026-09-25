-- Screenshot-friendly incident view. Reads existing diagnostics; never retries hooks.
local M={}
-- Read-only, event-time snapshot. No module loading, settings writes, GPU
-- allocations or diagnostic emissions are allowed in this collector.
function M.captureContext(c,game,mod)
 local function call(fn,...)
  if type(fn)~='function' then return end
  local ok,a,b,d,e=pcall(fn,...);if ok then return a,b,d,e end
 end
 local ow=game and (game.overworld or game.world);local player=ow and ow.player
 c.map=ow and ow.map and ow.map.id;c.x=player and player.cellX;c.y=player and player.cellY
 c.gameVersion=game and game.save and game.save.version
 c.activity=game and game.save and game.save.meta and game.save.meta.playthroughId=='dein-look-benchmark-v3' and 'graphics-check' or 'gameplay'
 c.platform=call(love.system and love.system.getOS) or '?'
 c.package=mod.id=='kanto_ascendant' and 'KASC' or 'VASC'
 c.version=mod._vascPackageVersion or mod.version or (mod.manifest and mod.manifest.version) or '?'
 c.engine=mod._vascEngineVersion or c.engine or '?'
 local companion=call(mod.find,'kanto_ascendant')
 c.kascVersion=type(companion)=='table' and companion.version or nil
 local major,minor,revision=call(love.getVersion)
 if major then c.runtime=string.format('LOVE %s.%s.%s',major,minor,revision)end
 local g=love.graphics or {}
 local name,version,vendor,device=call(g.getRendererInfo)
 if name then c.renderer=tostring(name)..' '..tostring(version);c.gpu=tostring(vendor)..' / '..tostring(device)end
 local w,h=call(g.getDimensions);if w then c.resolution=tostring(w)..'x'..tostring(h)end
 local stats=call(g.getStats);local fps=call(love.timer and love.timer.getFPS)
 if type(stats)=='table' then c.performance=string.format('FPS %s; textures %.1f MiB; draw calls %s',tostring(fps or '?'),(tonumber(stats.texturememory) or 0)/1048576,tostring(stats.drawcalls or '?'))end
 local unavailable='not exposed by engine'
 local function mib(value,divisor)
  local n=tonumber(value);return n and string.format('%.1f MiB',n/(divisor or 1048576)) or unavailable
 end
 stats=type(stats)=='table' and stats or {}
 local cores=call(love.system and love.system.getProcessorCount)
 local model=call(love.system and love.system.getDeviceModel) or call(love.system and love.system.getModel)
 local luaKb=call(collectgarbage,'count') -- read only; never trigger collection
 local dt=call(love.timer and love.timer.getDelta)
 local average=call(love.timer and love.timer.getAverageDelta)
 c.hardware={
  {'Device',model or unavailable},
  {'CPU','model '..unavailable..'; logical processors '..tostring(cores or '?')..'; Lua architecture '..tostring(jit and jit.arch or '?')},
  {'GPU',c.gpu or unavailable},
  {'System RAM','total / used / free: '..unavailable},
  {'Process RAM','resident / peak: '..unavailable},
  {'Measured memory','Lua heap '..mib(luaKb,1024)..'; graphics textures '..mib(stats.texturememory)..' (not total RAM or VRAM)'},
  {'Frames',string.format('FPS %s; last %s ms; average %s ms',tostring(fps or '?'),dt and string.format('%.1f',dt*1000) or '?',average and string.format('%.1f',average*1000) or '?')},
 }
 c.performance=string.format('draw calls %s; canvases %s; images %s; shader switches %s',tostring(stats.drawcalls or '?'),tostring(stats.canvases or '?'),tostring(stats.images or '?'),tostring(stats.shaderswitches or '?'))
 local pw,ph=call(g.getPixelDimensions)
 if pw then c.resolution=tostring(w)..'x'..tostring(h)..' logical; '..tostring(pw)..'x'..tostring(ph)..' pixels'end
 local stack=game and game.stack;local top=stack and call(stack.top,stack)
 c.screen=top and (top.screenId or top.phase) or 'unknown'
 local options=game and game.save and game.save.options
 local saved=options and options.modOptions and options.modOptions[mod.id or 'VOXEL_ASCENDANT'] or {}
 local values={}
 for _,key in ipairs{'battles','battleSpriteStyle','pokemonModelSkin','sceneResolution','deviceProfile','aa','shadows','localLights','battleLights','terarriumDome','terarriumLighting'}do
  local value=saved[key]
  if value==nil and mod.options then value=call(mod.options.get,mod.options,key)end
  if type(value)=='string' or type(value)=='boolean' or type(value)=='number' then values[#values+1]=key..'='..tostring(value)end
 end
 c.settings=#values>0 and table.concat(values,'; ') or 'No explicit values available'
end
local explanations={
 D04={'Voxel provider unavailable','Voxel-Anbieter nicht verfügbar'},
 D06={'3D graphics unavailable','3D-Grafik nicht verfügbar'},
 D07={'Shader compilation failed','Shader konnte nicht erstellt werden'},
 D08={'Render target failed','Render-Ziel fehlgeschlagen'},
 D09={'Voxel mesh failed','Voxel-Geometrie fehlgeschlagen'},
 D10={'Voxel loading timed out','Voxel-Laden hat zu lange gedauert'},
 D11={'Voxel renderer fell back','Voxel-Renderer zurückgefallen'},
 D14={'Battle fell back to 2D','Kampf auf 2D zurückgefallen'},
 E_MAP={'MAP battle placement failed','MAP-Kampfplatz nicht verfügbar'},
 E_ART={'Selected Pokémon art unavailable','Gewählte Pokémon-Grafik nicht verfügbar'},
 E_HOOK={'A feature hook failed','Ein Funktions-Hook ist fehlgeschlagen'},
 E_ENGINE={'Engine reported a mod error','Engine meldet einen Mod-Fehler'},
 E_RENDER={'Rendering error recorded','Grafikfehler aufgezeichnet'},
}
function M.install(mod,inbox,options)
 if mod.exports and mod.exports.errors then return mod.exports.errors end
 options=options or {}
 mod.exports=mod.exports or {}
 if options.supportProvider then mod.exports.supportLogsProvider=options.supportProvider end
 local support
 local function supportService()
  if not support then
   local source=assert(mod:read('lib/SupportLogs.lua'))
   support=assert((loadstring or load)(source,'@SupportLogs'))().new(mod)
  end
  support.refresh();return support
 end
 local Screen={isOpaque=true};Screen.__index=Screen
 options.reportText=options.reportText or (inbox.report and function(r)return inbox:report(r)end)
 local latestGame
 if not options.session and not inbox.context.session then
  local ok,stamp=pcall(os.date,'!%Y%m%dT%H%M%SZ')
  inbox.context.session=(mod.id=='kanto_ascendant' and 'KASC' or 'VASC')..'-ERRORS-'..(ok and stamp or tostring(math.floor(love.timer.getTime()*1000)))
 end
 local ok,version=pcall(require,'src.core.Version')
 if ok and type(version)=='table' then inbox.context.engine=version.engine end
 inbox.captureContext=function()
  if latestGame then M.captureContext(inbox.context,latestGame,mod)end
  if options.session then local ok,v=pcall(options.session);if ok then inbox.context.session=v end end
 end
 local function de()return options.language and options.language()=='de'end
 local function tr(en,ger)return de() and ger or en end
 local function title(r)local v=explanations[r.code] or explanations.E_RENDER;return v[de() and 2 or 1]end
 local clock=love.timer.getTime
 local pendingNotice,lastNotice=nil,-math.huge
 inbox.onNew=function(r)if r.activity~='graphics-check' then pendingNotice=r.code end end
 local errorSource,errorCursor=nil,0
 local function poll(game)
  latestGame=game
  local c=inbox.context
  M.captureContext(c,game,mod)
  if options.session then local ok,v=pcall(options.session);if ok then c.session=v end end
  -- The loader already owns pipeline/hook failures, including quarantined renderers.
  -- Read it rather than wrapping Runtime.reportError or replaying failed callbacks.
  local status=game and game.modStatus
  if game and game.mods and type(game.mods.status)=='function' then
   local ok,v=pcall(game.mods.status,game.mods);if ok then status=v end
  end
  local errors=status and status.errors
  if type(errors)=='table' then
   if errors~=errorSource or #errors<errorCursor then errorSource=errors;errorCursor=0 end
   local last=math.min(#errors,errorCursor+32)
   for i=errorCursor+1,last do
    local raw=tostring(errors[i])
    if raw:find('VOXEL_ASCENDANT',1,true) or raw:find('kanto_ascendant',1,true) then
     inbox:observe('engine-error',{status='error',reason=raw,caller=raw:match('^([^:]+)')})
    end
   end
   errorCursor=last
  end
 end
 local function open(game,showSupport)
  poll(game)
  local screen=setmetatable({game=game,index=1,page=1,detail=false},Screen)
  if showSupport then screen.support=supportService() end
  game.stack:push(screen)
  return screen
 end
 function Screen:uiSize()return 640,400 end
 function Screen:wantsFillScale()return true end
 function Screen:drawsWidescreen()return true end
 function Screen:sgbPalettes()return {{colors=false,x=0,y=0,w=640,h=400}}end
 function Screen:draw()end
 function Screen:choose(action)
  if action=='diagnostics' then
   self.page=1
   if options.openDiagnostics then return options.openDiagnostics(self.game) end
   self.diagnostics=true;return
  end
  if self.diagnostics then
   if action=='back' then self.diagnostics=false;self.page=1
   elseif action=='sendLogs' or action=='open' then self.diagnostics=false;self.support=supportService();self.page=1
   elseif action=='previous' then self.page=math.max(1,(self.page or 1)-1)
   elseif action=='next' then self.page=math.min(self.pageCount or 1,(self.page or 1)+1)end
   return
  end
  if action=='sendLogs' then
   self.support=supportService();self.page=1;return
  end
  if self.support then
   if action=='back' then self.support.cancel();self.support=nil;self.page=1
   elseif action=='confirm' or action=='open' then self.support.send()
   elseif action=='previous' then self.page=math.max(1,(self.page or 1)-1)
   elseif action=='next' then self.page=math.min(self.pageCount or 1,(self.page or 1)+1) end
   return
  end
  if action=='back' then
   if self.detail then self.detail=false;self.page=1 else self.game.stack:pop()end
  elseif action=='previous' or action=='next' then
   local delta=action=='previous' and -1 or 1
   if self.detail then self.page=math.max(1,math.min(self.pageCount or 1,(self.page or 1)+delta))
   else self.index=math.max(1,math.min(math.max(1,#inbox.items),self.index+delta));self.page=1 end
  elseif not self.detail then
   if not inbox.items[self.index] then return self:choose('sendLogs') end
   self.detail=true;self.page=1
  elseif options.reportText and love.system and love.system.setClipboardText then
   local ok,body=pcall(options.reportText,inbox.items[self.index])
   if ok then
    local called,result=pcall(love.system.setClipboardText,body)
    local copied=called and result==true
    -- Modern hosts explicitly return false from the sandbox stub. Older
    -- native LOVE returns nil: only claim success after exact read-back.
    if called and result==nil and love.system.getClipboardText then
     local read,value=pcall(love.system.getClipboardText);copied=read and value==body
    end
    self.copyNotice=copied and tr('Report copied','Bericht kopiert') or tr('Clipboard unavailable in this engine; send report screenshots.','Zwischenablage in dieser Engine nicht verfügbar; Berichtsseiten als Screenshots schicken.')
    self.page=1
   end
  end
  if self.detail then inbox:read(inbox.items[self.index])end
 end
 function Screen:update()
  if self.support then self.support.poll() end
  local input=self.game.input;if not input then return end
  if input:wasPressed('b')then self:choose('back')
  elseif input:wasPressed('up') or input:wasPressed('left')then self:choose('previous')
  elseif input:wasPressed('down') or input:wasPressed('right')then self:choose('next')
  elseif not self.support and input:wasPressed('start') then self:choose('diagnostics')
  elseif input:wasPressed('select') then self:choose('sendLogs')
  elseif input:wasPressed('a')then self:choose('open')end
 end
 function Screen:pointer(p)
  if p.phase~='pressed' then return true end
  for _,b in ipairs(self.buttons or {})do if p.x>=b.x and p.y>=b.y and p.x<=b.x+b.w and p.y<=b.y+b.h then self:choose(b.action);return true end end
  return true
 end
 function Screen:drawPhysical()
  local g=love.graphics;g.push('all');g.setCanvas();g.origin();g.setShader();g.setScissor();g.setDepthMode();g.setBlendMode('alpha')
  local w,h=g.getDimensions();local left,top,right,bottom=18,22,w-18,h-18
  if love.window and love.window.getSafeArea then
   local x,y,sw,sh=love.window.getSafeArea();left=math.max(left,x+14);top=math.max(top,y+14);right=math.min(right,x+sw-14);bottom=math.min(bottom,y+sh-14)
  end
  local width=right-left;local fs=math.max(12,math.min(19,math.floor(math.min(width/30,(bottom-top)/27))))
  if self.fontSize~=fs then self.font=g.newFont(fs);self.bold=g.newFont(fs+5);self.fontSize=fs end
  g.setColor(.025,.045,.075,1);g.rectangle('fill',0,0,w,h)
  g.setFont(self.bold);g.setColor(.5,.9,1,1);g.print(tr('ERRORS / DIAGNOSTICS','FEHLER / DIAGNOSE'),left,top)
  local y=top+fs*2.3;g.setFont(self.font)
  local bh=math.max(38,fs*2.4);local by=bottom-bh;local bw=(width-18)/4
  -- Wrap first, then paginate complete lines above the controls. Keep the
  -- report ID and page count on every screenshot; never hide the last rows
  -- underneath navigation or shrink a diagnostic to unreadable type.
  local rows={}
  local function text(s,color)
   local _,lines=self.font:getWrap(s,width)
   for i,line in ipairs(lines)do
    rows[#rows+1]={text=line,color=color or {.93,.96,1,1},height=fs+2+(i==#lines and 6 or 0)}
   end
  end
  local r=inbox.items[self.index]
  if self.support then
   local stateNames={queued=tr('Queued','Wartet'),authorizing=tr('Preparing secure upload…','Sicherer Versand wird vorbereitet…'),idle=tr('Ready','Bereit'),pending=tr('Sending…','Sendet…'),saved=tr('Sent','Gesendet'),failed=tr('Failed','Fehlgeschlagen'),timeout=tr('Timed out — delivery unconfirmed','Zeitüberschreitung — Empfang unbestätigt'),cancelled=tr('Cancelled — delivery unconfirmed','Abgebrochen — Empfang unbestätigt'),cooldown=tr('Please wait 60 seconds','Bitte 60 Sekunden warten'),unavailable=tr('Unavailable — update this mod','Nicht verfügbar — Mod aktualisieren'),['not-configured']=tr('Sending unavailable','Versand nicht verfügbar')}
   text(tr('Send support logs','Support-Logs senden'))
   if not self.support.started then
    text(tr('Send the available KASC / VASC logs and diagnostics to the developer? No save file is attached. Nothing is sent automatically.','Vorhandene KASC-/VASC-Logs und Diagnosedaten an den Entwickler senden? Kein Spielstand wird angehängt. Kein automatischer Versand.'))
   end
   for _,target in ipairs(self.support.targets)do text(target.label..': '..(stateNames[target.state] or tr('Failed','Fehlgeschlagen')))end
   if #self.support.targets==0 then text(tr('No supported mod loaded.','Kein unterstützter Mod geladen.'))end
   if self.support.reportId then
    text(tr('Report ID: ','Bericht-ID: ')..self.support.reportId)
    text(tr('Include this ID when describing the problem. Only mods marked Sent have confirmed delivery.','Diese ID bei der Problembeschreibung angeben. Nur bei „Gesendet“ ist der Empfang bestätigt.'))
   end
  elseif self.diagnostics then
   M.captureContext(inbox.context,self.game,mod)
   local c=inbox.context
   text(tr('Current device diagnostics','Aktuelle Gerätediagnose'))
   text((c.platform or '?')..' · '..(c.package or '?')..' '..(c.version or '?')..' · Engine '..(c.engine or '?'))
   for _,row in ipairs(c.hardware or {})do text(row[1]..': '..row[2])end
   text(c.performance or '');text(c.settings or '')
  elseif not r then
   text(tr('No errors recorded this session.','In dieser Sitzung keine Fehler aufgezeichnet.'))
   text(tr('This does not rule out visual defects. If something looks wrong, send a gameplay screenshot and a log.','Das schließt sichtbare Grafikfehler nicht aus. Bei falscher Darstellung bitte Spielbild und Log schicken.'))
  elseif not self.detail then
   text(tr('Recorded incidents · current session','Aufgezeichnete Vorfälle · aktuelle Sitzung'))
   text(tostring(self.index)..' / '..#inbox.items..'     '..r.code..'     '..r.count..'×')
   text(title(r));text(r.map..'  ['..r.x..', '..r.y..']')
   text(tr('Requested: ','Gewählt: ')..r.requested..' -> '..r.actual)
   text(tr('Open the report to take a screenshot.','Bericht öffnen und einen Screenshot machen.'))
  else
   if self.copyNotice then text(self.copyNotice,{.6,.78,.84,1})end
   text(r.code..'  # '..r.id..'  · '..self.index..' / '..#inbox.items..'  · '..r.count..'×')
   text(title(r));text(r.platform..' · '..(r.package or 'VASC')..' '..r.version..' · Engine '..r.engine)
   for _,v in ipairs(r.hardware or {})do text(v[1]..': '..v[2])end
   text(tr('Map: ','Karte: ')..r.map..' ['..r.x..', '..r.y..']')
   text(tr('Requested -> actual: ','Gewählt -> tatsächlich: ')..r.requested..' -> '..r.actual)
   text(tr('Reason: ','Grund: ')..(r.fullReason or r.reason))
   text(tr('Source: ','Quelle: ')..r.caller)
   text(tr('Session: ','Sitzung: ')..r.session)
   text(tr('First / last: ','Erstmals / zuletzt: ')..math.floor(r.first)..'s / '..math.floor(r.last)..'s · '..r.activity)
   for _,v in ipairs(r.details or {})do text(v[1]..': '..v[2])end
   if #(r.related or {})>0 then
    text(tr('Immediately preceding incidents (not proven causes):','Unmittelbar vorherige Vorfälle (keine nachgewiesenen Ursachen):'),{.6,.78,.84,1})
    for _,v in ipairs(r.related)do text(v)end
   end
   text(tr('Send all report pages. Copy is available if the engine allows it. A log may still be needed for timing or visual-only faults.','Alle Berichtsseiten schicken. Kopieren ist möglich, wenn die Engine es erlaubt. Bei Ablauf- oder rein sichtbaren Fehlern kann weiterhin ein Log nötig sein.'),{.6,.78,.84,1})
  end
  local headerY=y;y=y+fs+10
  local pages={{}};local used=0;local controlsTop=by-(self.support and 1 or 2)*(bh+8)
  local capacity=math.max(fs+8,controlsTop-y-10)
  for _,row in ipairs(rows)do
   if used+row.height>capacity and #pages[#pages]>0 then pages[#pages+1]={};used=0 end
   pages[#pages][#pages[#pages]+1]=row;used=used+row.height
  end
  self.pageCount=#pages;self.page=math.max(1,math.min(self.page or 1,#pages))
  if (r and not self.support and not self.diagnostics) or #pages>1 then
   g.setColor(.6,.78,.84,1)
   g.print((r and not self.support and not self.diagnostics and (r.code..' #'..r.id..' · ') or '')..tr('Page ','Seite ')..self.page..' / '..#pages..(r and not self.support and not self.diagnostics and (' · '..r.session:sub(-12)) or ''), left,headerY)
  end
  for _,row in ipairs(pages[self.page])do
   g.setColor(unpack(row.color));g.print(row.text,left,y);y=y+row.height
  end
  self.buttons={}
  local sendY=by-bh-8
  local sendLabel=self.support and (self.support.pending() and tr('Sending…','Sendet…') or (self.support.started and tr('Send again','Erneut senden') or tr('Confirm & send','Bestätigen & senden'))) or tr('Send logs · SELECT','Logs senden · SELECT')
  g.setColor(.1,.32,.38,1);g.rectangle('fill',left,sendY,width,bh,5,5);g.setColor(1,1,1,1);g.printf(sendLabel,left,sendY+(bh-fs)/2,width,'center')
  self.buttons[#self.buttons+1]={x=left,y=sendY,w=width,h=bh,action=self.support and 'confirm' or 'sendLogs'}
  if not self.support then
   local dy=sendY-bh-8
   g.setColor(.09,.19,.25,1);g.rectangle('fill',left,dy,width,bh,5,5);g.setColor(1,1,1,1)
   g.printf(tr('Device diagnostics · START','Gerätediagnose · START'),left,dy+(bh-fs)/2,width,'center')
   self.buttons[#self.buttons+1]={x=left,y=dy,w=width,h=bh,action='diagnostics'}
  end
  for i,b in ipairs({{'back' ,tr('Back','Zurück')},{'previous','<'},{'next','>'},{'open',self.support and tr('Send','Senden') or (not r and tr('Logs','Logs') or (self.detail and options.reportText and tr('Copy','Kopieren') or tr('Report','Bericht')))}})do
   local x=left+(i-1)*(bw+6);g.setColor(.09,.19,.25,1);g.rectangle('fill',x,by,bw,bh,5,5);g.setColor(1,1,1,1);g.printf(b[2],x,by+(bh-fs)/2,bw,'center')
   self.buttons[#self.buttons+1]={x=x,y=by,w=bw,h=bh,action=b[1]}
  end
  self.contentBottom=y;self.buttonsTop=controlsTop;g.pop()
 end
 -- Gen2 passes its class owner: the Gen1 compatibility facade writes an
 -- instance method, which would hide later class-level menu wrappers.
 local Game=options.Game or require('src.core.Game');local draw,touch=Game.draw,Game.touchpressed
 function Game:draw(...)
  local result=draw(self,...);local s=self.stack:top();if getmetatable(s)==Screen then s:drawPhysical()end;return result
 end
 function Game:touchpressed(id,x,y,dx,dy,pressure)
  local s=self.stack:top();if getmetatable(s)==Screen then return s:pointer{phase='pressed',x=x,y=y}end
  if touch then return touch(self,id,x,y,dx,dy,pressure)end
 end
 mod.hooks:wrap('input.pointer',function(nextPointer,game,p)
  local s=game.stack:top();if getmetatable(s)==Screen then return s:pointer(p)end;return nextPointer(game,p)
 end,2000020)
 local elapsed=0
 mod.hooks:wrap('core.update',function(nextUpdate,game,dt)
  latestGame=game
  local result=nextUpdate(game,dt);elapsed=elapsed+(dt or 0)
  if elapsed>=2 then elapsed=0;pcall(poll,game)end
  if pendingNotice and options.notify and clock()-lastNotice>=15 then
   local code=pendingNotice;pendingNotice=nil
   if getmetatable(game.stack:top())~=Screen then lastNotice=clock();pcall(options.notify,code)end
  end
  return result
 end,2000020)
 mod.exports=mod.exports or {};mod.exports.errors={open=open,openSupport=function(game)return open(game,true)end,inbox=inbox,title=function()return tr('ERRORS / DIAGNOSTICS','FEHLER / DIAGNOSE')end,
  description=function()return tr('View errors and send KASC / VASC logs, even without a recorded error.','Fehler ansehen und KASC-/VASC-Logs senden, auch ohne aufgezeichneten Fehler.')end,
  count=function()return inbox.unread end,poll=poll,Screen=Screen,reportText=options.reportText}
 return mod.exports.errors
end
return M
