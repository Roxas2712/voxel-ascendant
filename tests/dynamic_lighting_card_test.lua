local root=assert(arg[1]);local loaded={};local active=false;local resets=0
local L={mobile=false,MAX_LIGHTS=8,MAX_BATTLE_LIGHTS=4,MAX_PORTALS=4,
 available=function()return active end,enabled=function()return active end,
 setOwnerActive=function(v)active=v end}
loaded.LocalLights=L;loaded.BattleLights={setting={get=function()return true end}}
loaded.LightAtmosphere={invalidate=function()resets=resets+1 end}
local V={};V.require=function(n)
 if loaded[n]then return loaded[n]end
 local m=assert(loadfile(root..'/lib/'..n..'.lua'))(V);loaded[n]=m;return m
end
local C=V.require('cards/lighting/Gen1DynamicLightingCard');local registry=V.require('core/AscendantCardRegistry').new()
assert(registry:register(C.descriptor()))
assert(not registry:activate(C.ID,{generation=2}));assert(not active)
registry=V.require('core/AscendantCardRegistry').new();assert(registry:register(C.descriptor()))
assert(registry:activate(C.ID,{generation=1}));assert(active)
local cap=assert(registry:capability(C.CAPABILITY));assert(cap.value.status().world)
local hostInstaller=C.installHost;assert(registry:health(C.ID,{generation=1}).ok);assert(C.installHost==hostInstaller,'health mutated the host installer')
local report=registry:deactivateAll({generation=1},'QA');assert(#report.errors==0 and not active and resets>0)
assert(registry:activate(C.ID,{generation=1}));assert(active)
assert(C.descriptor().saveNamespace==false and #C.descriptor().impact.publicHooks==0)
local mod={exports={}};local receipt
C.installHost(mod,{registerSegment=function(value)receipt=value end})
assert(receipt.active and mod.exports.dynamicLighting.status().active)
assert(mod.exports.dynamicLighting.setActive(false));assert(not active)
assert(mod.exports.dynamicLighting.setActive(true));assert(active)
-- The shared dispatcher must never enable this renderer in Gen2.
loaded.CanvasPresentation={OS='Android'};loaded.ModSetting={new=function()return {setGate=function()end}end}
local isolated=assert(loadfile(root..'/lib/LocalLights.lua'))({mod={_vascHostGeneration=2},require=V.require})
assert(not isolated.supported and isolated.glsl()=='')
print('PASS_DYNAMIC_LIGHTING_CARD: actual registry lifecycle, Gen2 rejection, capability, cleanup and reactivation')
