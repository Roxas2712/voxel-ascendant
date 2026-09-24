local V=...
local L=V.require('SetupLocale').text
-- Deliberately tiny, source-backed compatibility database. No GPU model is
-- declared safe merely because its name resembles one we have tested.
local M={REVISION=1}
M.effects={
 {id='world_light',label=L("World lighting",'Weltlicht'),key='localLights',on=true,off=false,scene='world'},
 {id='battle_light',label=L("Battle lighting",'Kampflicht'),key='battleLights',on=true,off=false,scene='battle'},
 {id='terrarium_light',label=L("Terrarium lighting",'Terrarium-Licht'),key='terarriumLighting',on=true,off=false,scene='terrarium'},
 {id='shadows',label=L("Shadows",'Schatten'),key='shadows',on=true,off=false,scene='world'},
 {id='reflections',label=L("Full water reflections",'Volle Wasserreflexionen'),key='water',on='full',off='sky',scene='world'},
 {id='aa',label=L("Anti-aliasing",'Kantenglättung'),key='aa',on=2,off=0,scene='world'},
}
M.rules={
 {id='render-path',source='Voxel3D.available / SetupEffects.probe',reason=L("The basic 3D / depth buffer check failed.",'Die 3D-/Tiefenpuffer-Grundprüfung ist fehlgeschlagen.'),test=function(c)return not c.gpu end,ids='all',state='blocked'},
 {id='light-owner',source='LocalLights.available',reason=L("The active lighting renderer reports an error or is unavailable.",'Der aktive Licht-Renderer meldet einen Fehler oder ist nicht verfügbar.'),test=function(c)return not c.lights end,ids={'world_light','battle_light','terrarium_light'},state='blocked'},
 {id='battle-stage',source='BattleLights.enabled / neutralStage',reason=L("Battle lighting only applies to MAP or Arena. This setting does not use this lighting control.",'Kampflicht wirkt nur in MAP oder Arena. Diese Kulisse verwendet diesen Lichtregler nicht.'),test=function(c)return c.battle~=true and c.battle~='arena' end,ids={'battle_light'},state='not-applicable'},
 {id='terrarium-owner',source='TerarriumHost.available',reason=L("Terrarium lighting applies only to the Terrarium setting.",'Terrarium-Licht gehört ausschließlich zur Terrarium-Kulisse.'),test=function(c)return c.battle~='terarrium' or not c.terrarium end,ids={'terrarium_light'},state='not-applicable'},
 {id='mobile-aa',source='AntiAlias.MOBILE_RUNTIME / samples',reason=L("VASC disables supersampling on Android and iOS. Higher values would have no effect there.",'VASC deaktiviert Supersampling auf Android und iOS. Eine höhere Auswahl würde dort nicht wirken.'),test=function(c)return c.mobile end,ids={'aa'},state='blocked'},
 {id='texture-budget',source='AntiAlias.expand / love.graphics.getSystemLimits',reason=L("The additional rendering resolution exceeds the reported texture limit.",'Die zusätzliche Renderauflösung überschreitet das gemeldete Texturlimit.'),test=function(c)return c.maxTexture and math.max(c.width,c.height)*1.5>c.maxTexture end,ids={'aa'},state='blocked'},
 {id='conservative-device',source='DeviceProfile / user-selected startup budget',reason=L("Leave off initially for this economy profile. Test the scene before enabling additional effects.",'Für dieses sparsame Startprofil zunächst aus lassen. Erst ein Test dieser Szene kann zusätzliche Effekte begründen.'),test=function(c)return c.mobile or c.profile=='mobile' or c.profile=='safe' end,ids={'world_light','battle_light','terrarium_light','reflections','aa'},state='caution'},
 {id='lazy-driver',source='Voxel3D.mobileCoreShaderSource (first-draw driver evidence)',reason=L("Successful shader compilation does not prove correct output. Actual rendering and visual checks are still needed.",'Ein erfolgreich kompilierter Shader beweist noch keine fehlerfreie Ausgabe. Der echte Zeichentest und die Sichtprüfung fehlen noch.'),test=function(c)return c.gpu end,ids='all',state='needs-test'},
}
function M.evaluate(c)
 local out={};for _,e in ipairs(M.effects)do out[e.id]={id=e.id,label=e.label,state='needs-test',reason=L("No test in a matching scene yet.",'Noch kein Test in einer passenden Szene.'),rules={}}end
 local rank={['needs-test']=0,caution=1,['not-applicable']=2,blocked=3}
 for _,rule in ipairs(M.rules)do if rule.test(c)then
  local ids=rule.ids;if ids=='all'then ids={};for _,e in ipairs(M.effects)do ids[#ids+1]=e.id end end
  for _,id in ipairs(ids)do local r=out[id];r.rules[#r.rules+1]=rule.id;if rank[rule.state]>=rank[r.state]then r.state=rule.state;r.reason=rule.reason end end
 end end
 return out
end
return M
