local M={}
function M.progressRows(s,de)
 local function tr(a,b)return de and b or a end
 local total=tonumber(s.totalBytes) or 0
 local bytes=math.min(total,tonumber(s.bytes) or 0)
 local percent=total>0 and math.floor(bytes/total*100) or 0
 local rate=math.max(0,tonumber(s.bytesPerSecond) or 0)
 local speed=rate>=1048576 and string.format('%.1fMiB/s',rate/1048576) or string.format('%.0fKiB/s',rate/1024)
 local label=s.phase=='prepare' and tr('MODELS','MODELLE')
  or s.stage=='download' and tr('SPEED','TEMPO')
  or s.phase=='download' and tr('LOCAL FILES','LOKAL')
  or tr('NETWORK','NETZ')
 local right=s.phase=='prepare' and string.format('%d/%d',s.prepared or 0,s.prepareTotal or 0)
  or s.stage=='download' and speed
  or s.phase=='download' and string.format('%d/%d',s.done or 0,s.total or 0)
  or string.format('%.1f MiB',(s.receivedBytes or 0)/1048576)
 return {
  {label=tr('VERIFIED','GEPRUEFT'),right=string.format('%d%%',percent),help=string.format('%.1f / %.1f MiB. ',bytes/1048576,total/1048576)..tr('Local files count toward progress, not network speed.','Lokale Dateien zaehlen zum Fortschritt, nicht zum Netztempo.')},
  {label=label,right=right,help=tr('Network bytes per second (5 s). Local verification and model preparation do not count.','Echte Netzwerkdaten pro Sekunde (5 s). Lokale Pruefung und Modellaufbereitung zaehlen nicht mit.')},
 }
end
function M.new(mod,game,guided,de,content)
 local function tr(a,b)return de and b or a end
 local function rows()
  local s=content.status()
  if s.phase=='idle' and content.complete()then s={phase='ready',message='',bytes=content.size(),totalBytes=content.size()}end
  local p=M.progressRows(s,de);return {
   {label='COBBLEMON',right=content.version,help=tr('3D models and animations for regular species including Hoenn and Gorochu. Included in the base pack.','3D-Modelle und Animationen fuer regulaere Arten inkl. Hoenn und Gorochu. Im Basispaket enthalten.')},
   {label='STATUS',right=s.phase=='ready' and tr('READY','BEREIT') or s.phase=='prepare' and tr('PREPARING','AUFBAU') or s.phase=='download' and (s.stage=='download' and 'DOWNLOAD' or tr('VERIFY','PRUEFUNG')) or s.phase=='error' and tr('ERROR','FEHLER') or s.phase=='cancelled' and tr('STOPPED','GESTOPPT') or content.complete() and tr('READY','BEREIT') or tr('PENDING','OFFEN'),help=s.message~='' and s.message or content.source},
   p[1],p[2],
   {label=tr('INSTALL','EINRICHTEN'),action='download',right=string.format('%.1f MiB',content.size()/1048576),help=tr('Verify and prepare included models. Only unbundled missing files require a download. Existing graphics choices stay unchanged.','Enthaltene Modelle pruefen und aufbereiten. Nur fehlende, nicht mitgelieferte Dateien werden geladen. Bisherige Grafikauswahl bleibt bestehen.')},
   {label=tr('STOP DOWNLOAD','DOWNLOAD STOPPEN'),action='cancel'},
   {label=tr('BACK','ZURUECK'),action='back'},
  }
 end
 local menu=guided(mod,game,{key='vasc_cobblemon',title='COBBLEMON',rows=rows(),help=tr('After installation select COBBLEMON under Pokemon Model (battle) or follower sprite source. Missing species use existing sprites.','Nach Installation COBBLEMON unter Pokemon-Modell (Kampf) oder Begleiter-Spritequelle waehlen. Fehlende Arten nutzen vorhandene Sprites.'),onChoose=function(row)
  if row.action=='back'then game.stack:pop()
  elseif row.action=='cancel'then content.cancel()
  elseif row.action=='download'then content.start()end
 end})
 menu.showFirstGuide=function()return false end
 local update=menu.update;local last
 function menu:update(...)
  local s=content.status();local key=s.phase..s.message..':'..math.floor((s.elapsed or 0)*4)
  if key~=last then last=key;self.items=rows();self.index=math.min(self.index or 1,#self.items)end
  if update then return update(self,...)end
 end
 return menu
end
return M
