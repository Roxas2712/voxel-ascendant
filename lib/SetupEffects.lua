local V=...
local L=V.require('SetupLocale').text
local Measure=V.require('SetupMeasurement')
local M={};local Rules=V.require('SetupEffectRules');M.rules=Rules
local function stable(t)
 local keys={};for k in pairs(t)do keys[#keys+1]=k end;table.sort(keys)
 local out={};for _,k in ipairs(keys)do out[#out+1]=k..'='..tostring(t[k])end;return table.concat(out,'|')
end
function M.fingerprint(draft)
 local G=love.graphics;local renderer,version,vendor,device=G.getRendererInfo();local w,h=G.getPixelDimensions()
 local t={os=love.system.getOS(),renderer=renderer,driver=version,vendor=vendor,device=device,width=w,height=h,db=Rules.REVISION,measurement=Measure.REVISION,scenarios=2,frameCap=require('src.core.FrameCap').current,vsync=love.window.getVSync and love.window.getVSync()or 0,vasc=V.mod.version or '3.0.38',generation=V.mod._vascHostGeneration or 1}
 for _,k in ipairs({'sceneResolution','battles','arenaCamera','pokemonModelSkin','battleSpriteStyle','apo_pokemon_model_source','outdoorHorizon','outdoorTrees','outdoorGround','palletBuildings','deviceProfile','_device'})do t[k]=draft[k]end
 return stable(t),t
end
function M.probe()
 local G=love.graphics;local out={};local canvas,shader
 G.push('all')
 local ok,err=pcall(function()
  canvas=G.newCanvas(8,8);shader=G.newShader('vec4 effect(vec4 c, Image t, vec2 uv, vec2 px){return vec4(0.25,0.5,0.75,1.0);}')
  G.setCanvas({canvas,depth=true});G.origin();G.setScissor();G.setShader(shader);G.setDepthMode('always',true);G.clear(0,0,0,1,true,true);G.setColor(1,1,1,1);G.rectangle('fill',0,0,8,8)
  G.setShader();G.setDepthMode();G.setCanvas()
  local data=canvas:newImageData();local r,g,b,a=data:getPixel(4,4);data:release()
  assert(math.abs(r-.25)<.08 and math.abs(g-.5)<.08 and math.abs(b-.75)<.08 and a>.9,L("Graphics readback differs from the test image",'Grafik-Readback weicht vom Testbild ab'))
  assert(V.require('Voxel3D').available('DeinLook.preflight'),L("VASC scene shader unavailable",'VASC-Szenenshader nicht verfügbar'))
 end)
 G.pop();if canvas then canvas:release()end;if shader then shader:release()end
 out.ok=ok;out.error=not ok and tostring(err) or nil
 return out
end
function M.new(game,draft)
 local key,device=M.fingerprint(draft);local probe=M.probe()
 local self={game=game,fingerprint=key,device=device,probe=probe,results={}}
 local saved=V.mod.storage:read(game,'dein-look/effects-v1')
 if type(saved)=='table'and saved.fingerprint==key and type(saved.results)=='table'then self.results=saved.results;self.performance=saved.performance;self.combination=saved.combination end
 return self
end
function M.context(a,draft)
 local limits=love.graphics.getSystemLimits();local os=a.device.os
 return {gpu=a.probe.ok,lights=V.require('LocalLights').available(),battle=draft.battles,terrarium=V.require('TerarriumHost').available(),mobile=os=='iOS'or os=='Android',width=a.device.width,height=a.device.height,maxTexture=limits.texturesize,profile=draft._device}
end
function M.refresh(a,draft)
 local key,device=M.fingerprint(draft)
 if key~=a.fingerprint then a.fingerprint=key;a.device=device;a.results={};a.performance=nil;a.combination=nil;a.invalidated=true end
 a.compatibility=Rules.evaluate(M.context(a,draft));return a.compatibility
end
function M.save(a)
 -- At most six effect records, each summarised; no frame histories or images.
 return V.mod.storage:write(a.game,'dein-look/effects-v1',{revision=Rules.REVISION,fingerprint=a.fingerprint,results=a.results,performance=a.performance,combination=a.combination})
end
function M.status(a,id,draft)
 M.refresh(a,draft);local rule=a.compatibility[id];local r=a.results[id]
 if rule.state=='blocked'or rule.state=='not-applicable'then return rule.state,rule.reason end
 if not r then return rule.state,rule.reason end
 if r.error then return 'off',L('Rendering or image analysis reported a fault. This effect stays off; test again.','Zeichentest oder Bildanalyse meldeten einen Fehler. Dieser Effekt bleibt aus; bitte erneut testen.')end
 if r.visual=='bad' then return 'off', L("Visual faults were reported during the visual check.",'Bei der Sichtprüfung wurden Bildfehler gemeldet.')end
 if r.method~=Measure.REVISION or not r.valid or not r.exercised or type(r.off)~='number'or type(r.on)~='number'or r.off~=r.off or r.on~=r.on or r.off<=0 or r.on<=0 or r.off==math.huge or r.on==math.huge then return 'untested',L('Not enough matching, repeated measurements. Your choice is kept; test again.','Zu wenige passende Wiederholungsmessungen. Deine Auswahl bleibt erhalten; bitte erneut testen.')end
 if r.verdict=='uncertain' then return 'uncertain',L('Measurements vary or the difference is borderline. Your choice is kept. Close other demanding apps and test again.','Die Messung schwankt oder der Unterschied ist knapp. Deine Auswahl bleibt erhalten. Andere rechenintensive Apps schließen und erneut testen.')end
 if r.verdict=='costly' then return 'off',L('Repeated comparisons show a clear extra cost and missed frame-time target. Turning this effect off is recommended.','Wiederholte Vergleiche zeigen deutliche Mehrkosten und überschreiten das Bildzeitziel. Diesen Effekt auszuschalten wird empfohlen.')end
 if r.verdict~='pass' then return 'untested',L('No reliable paired result yet. Your choice is kept.','Noch kein belastbares Vergleichsergebnis. Deine Auswahl bleibt erhalten.')end
 local combined=a.combination
 if combined and (id=='world_light'or id=='shadows'or id=='reflections'or id=='aa')and (combined.verdict~='pass' or combined.imageSuspect and combined.visual~='ok' or combined.visual=='bad' or combined.candidates and not combined.candidates[id])then
  return 'uncertain',L('The effect passed alone, but the combined result needs another check. Your choice is kept.','Der Effekt bestand einzeln, aber die Kombination muss erneut geprüft werden. Deine Auswahl bleibt erhalten.')
 end
 if r.imageSuspect and r.visual~='ok'then return 'review',L('Image analysis flagged a possible visual issue. Compare the image yourself before enabling this effect.','Die Bildanalyse meldet einen möglichen Bildfehler. Prüfe die Darstellung selbst, bevor du diesen Effekt einschaltest.')end
 if r.visual~='ok' then return 'review',L('Repeated comparisons show no clear performance problem. Please review the image.','Wiederholte Vergleiche zeigen kein klares Leistungsproblem. Bitte die Darstellung prüfen.')end
 return 'recommended',L("Fast enough in the scene test, with no reported visual faults. Recommended in the draft; not a guarantee for every situation.",'Im Szenentest schnell genug und ohne gemeldete Bildfehler. Im Entwurf empfohlen; keine Garantie für jede Spielsituation.')
end
function M.record(a,id,result)
 a.results[id]=result;M.save(a)
end
function M.visual(a,id,value)
 if value~='ok'and value~='bad'and value~='unknown'then return false end
 local r=id=='combined'and a.combination or a.results[id]
 if not r then return false end
 r.visual=value;M.save(a);return true
end
-- A pending human image review does not need another timed measurement.
local function unclear(r)
 return not r or r.method~=Measure.REVISION or not r.valid or r.error~=nil
  or type(r.off)~='number'or type(r.on)~='number'or r.off<=0 or r.on<=0 or r.off~=r.off or r.on~=r.on or r.off==math.huge or r.on==math.huge
  or r.verdict~='pass'and r.verdict~='costly'
end
function M.retest(a,draft,id)
 M.refresh(a,draft)
 local request={ids={},combo=id=='combined',targeted=true};local n=0
 for _,e in ipairs(Rules.effects)do
  local rule=a.compatibility[e.id]
  local eligible=rule.state~='blocked'and rule.state~='not-applicable'
  if eligible and (id==e.id or not id and (unclear(a.results[e.id])or not a.results[e.id].exercised))then
   request.ids[e.id]=true;n=n+1;if e.scene=='world'then request.combo=true end
  end
 end
 if not id then
  if unclear(a.combination)then request.combo=true end
  for _,e in ipairs(Rules.effects)do local r=a.results[e.id];local c=a.combination
   if e.scene=='world'and not unclear(r)and r.exercised and r.verdict=='pass'and r.visual~='bad'and (not r.imageSuspect or r.visual=='ok')and c and c.candidates and not c.candidates[e.id]then request.combo=true end
  end
 end
 request.duration=(n>0 or request.combo)and 8+16*n+(request.combo and 16 or 0)or 0
 return request
end
function M.details(a,id,draft)
 M.refresh(a,draft)
 local r=id=='combined'and a.combination or a.results[id]
 local perf=not r and L('Not measured','Nicht gemessen')or unclear(r)and L('Unclear — retest','Unklar – erneut testen')
  or r.exercised==false and id~='combined'and L('Effect not observed','Effekt nicht nachgewiesen')
  or r.verdict=='costly'and L('Too costly at this target','Zu teuer für dieses Bildzeitziel')or L('Passed comparison','Vergleich bestanden')
 local reasons={drift=L('Changing load','Schwankende Last'),stalls=L('Uneven frame times','Unregelmäßige Bildzeiten'),samples=L('Insufficient samples','Zu wenige Messwerte'),scenario=L('Scene coverage missing','Szenen-Nachweis fehlt'),['no-candidates']=L('No eligible combination yet','Noch keine geeignete Kombination'),pairs=L('Repeats disagree','Wiederholungen widersprechen sich'),speedup=L('Unexpected timing change','Unerklärliche Zeitänderung'),['tail-cost']=L('Uneven frame times','Unregelmäßige Bildzeiten'),borderline=L('Borderline difference','Unterschied zu knapp')}
 if r and unclear(r)and reasons[r.reason]then perf=L('Unclear: ','Unklar: ')..reasons[r.reason]end
 local visual=not r and L('Not reviewed','Nicht beurteilt')or r.visual=='bad'and L('Fault reported here','Hier Bildfehler gemeldet')
  or r.visual=='ok'and L('No fault reported','Kein Bildfehler gemeldet')or r.imageSuspect and L('Possible fault — review','Verdacht – Bild prüfen')or L('Review pending','Sichtprüfung offen')
 local world=id=='combined';for _,e in ipairs(Rules.effects)do if e.id==id then world=e.scene=='world'end end
 local c=a.combination
 local combined=not world and L('Separate battle test','Eigener Kampftest')or not c and L('Not tested','Nicht geprüft')
  or c.candidates and id~='combined'and not c.candidates[id]and L('Not included','Nicht mitgeprüft')
  or c.visual=='bad'and L('Visual fault in combination','Bildfehler in Kombination')
  or unclear(c)and L('Unclear — retest together','Unklar – gemeinsam nachtesten')
  or c.verdict=='costly'and L('Combined cost too high','Gemeinsam zu aufwendig')
  or c.imageSuspect and c.visual~='ok'and L('Combined image needs review','Gemeinsames Bild prüfen')or L('Performance passed','Leistung bestanden')
 return {performance=perf,visual=visual,combined=combined,record=r}
end
function M.imageStats()
 if not M.sceneObserved then return nil,L("No successful 3D rendering pass in this frame.",'Kein erfolgreicher 3D-Zeichendurchlauf in diesem Bild.')end
 local source=V.require('Voxel3D').canvas();if not source then return nil,L("No 3D scene image",'Kein 3D-Szenenbild') end
 local G=love.graphics;local small=G.newCanvas(16,16);G.push('all')
 local ok,result=pcall(function()
  G.setCanvas(small);G.origin();G.setShader();G.setScissor();G.setDepthMode();G.setColor(1,1,1,1);G.clear(0,0,0,0)
  G.draw(source,0,0,0,16/source:getWidth(),16/source:getHeight());G.setCanvas()
  local d=small:newImageData();local sum,black,opaque,groundBlack,groundOpaque=0,0,0,0,0
  for y=0,15 do for x=0,15 do local r,g,b,a=d:getPixel(x,y);local l=(r+g+b)/3;assert(l==l,L("Non-finite colour values",'Nicht endliche Farbwerte'));sum=sum+l;if l<.015 then black=black+1 end;if a>.5 then opaque=opaque+1 end;if y>=8 then if l<.015 then groundBlack=groundBlack+1 end;if a>.5 then groundOpaque=groundOpaque+1 end end end end
  d:release();return {mean=sum/256,black=black/256,opaque=opaque/256,groundBlack=groundBlack/128,groundOpaque=groundOpaque/128}
 end)
 G.pop();small:release();return ok and result or nil,not ok and tostring(result)or nil
end
function M.active(id)
 if id=='world_light'or id=='battle_light'or id=='terrarium_light'then return M.lightObserved==true end
 if id=='shadows'then return M.shadowObserved==true end
 if id=='aa'then return M.aaObserved==true end
 if id=='reflections'then return M.waterObserved==true end
 return false
end
function M.resetFrame()
 M.sceneObserved=false;M.cameraSignature=nil;M.lightCount=0;M.waterObserved=false;M.lightObserved=false;M.shadowObserved=false;M.aaObserved=false
end
-- Observe successful passes while their renderer state is still live.
function M.install()
 if M.installed then return end;M.installed=true
 local G=V.require('Voxel3D');local begin=G.beginScene
 local projection=G.viewProjection
 function G.viewProjection(...)
  if M.tracking and G.camera and G.camera.eye then local c=G.camera;M.cameraSignature=table.concat(c.eye,',')..'/'..table.concat(c.focus or {},',')end
  return projection(...)
 end
 function G.beginScene(...)
  local result=begin(...)
  if result then
   M.sceneObserved=true
   if M.tracking and G.camera and G.camera.eye then local c=G.camera;M.cameraSignature=table.concat(c.eye,',')..'/'..table.concat(c.focus or {},',')end
   M.shadowObserved=M.shadowObserved or (V.require('Shadows').enabled() and V.require('ShadowMap').active())
   local l=V.require('LocalLights');local f=l.current();M.lightCount=math.max(M.lightCount or 0,#(f.lights or {}))
   M.lightObserved=M.lightObserved or (G.localLightsActive==true and l.active() and (f.sky~=nil or #(f.lights or {})>0))
  end
  return result
 end
 local water=G.beginWater
 function G.beginWater(...)local result=water(...);if result then M.waterObserved=true end;return result end
 local shadow=V.require('ShadowMap');local cast=shadow.begin
 function shadow.begin(...)local result,reused=cast(...);if result then M.shadowObserved=true end;return result,reused end
 local aa=V.require('AntiAlias');local expand=aa.expand
 function aa.expand(w,h,...)local ew,eh=expand(w,h,...);if aa.samples()>1 and ew>w*1.01 then M.aaObserved=true end;return ew,eh end
end
return M
