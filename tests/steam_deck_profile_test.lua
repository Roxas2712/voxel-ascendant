local root=assert(arg[1])
local H=assert(loadfile(root..'/lib/DeviceHardware.lua'))()
for _,device in ipairs({'AMD Vangogh','AMD Radeon Graphics (RADV VANGOGH)','AMD Custom GPU 0405','AMD Custom GPU 0932 (RADV)'})do
 for _,osName in ipairs({'Linux','Windows'})do assert(H.classify(osName,device).steamDeck,device)end
end
for _,device in ipairs({'AMD Radeon RX 7900 XTX','AMD Radeon Graphics','Intel UHD','AMD Custom GPU 04050','unknown'})do assert(not H.classify('Linux',device).steamDeck,device)end
assert(not H.classify('Android','AMD Vangogh').steamDeck)
assert(not H.detect(nil).steamDeck)
assert(not H.detect({system={getOS=function()error('unavailable')end},graphics={getRendererInfo=function()error('unavailable')end}}).steamDeck)
local hardware=H.detect({system={getOS=function()return 'Linux'end},graphics={getRendererInfo=function()return 'OpenGL','4.6','AMD','AMD Vangogh'end}})
assert(hardware.steamDeck)
local tier='high'
package.loaded['src.core.Performance']={detect=function()return tier end}
for _,gen in ipairs({1,2})do
 local modules={CanvasPresentation={OS='Linux'}}
 local parent={_vascDeviceHardware=hardware}
 local V={mod=setmetatable({id='VOXEL_ASCENDANT'}, {__index=parent})}
 V.require=function(n)return assert(modules[n],n)end
 modules.ModSetting=assert(loadfile(root..'/lib/ModSetting.lua'))(V)
 modules.Gen2PerformancePolicy=assert(loadfile(root..'/gen2/lib/Gen2PerformancePolicy.lua'))()
 local prefix=gen==1 and '/lib/'or '/gen2/lib/'
 local P=assert(loadfile(root..prefix..'DeviceProfile.lua'))(V)
 assert(P.resolve('auto')==(gen==1 and 'balanced'or'handheld'))
 for _,mode in ipairs(gen==1 and {'high','ultra','light','balanced','custom'}or{'max','handheld','eco','custom'})do assert(P.resolve(mode)==mode,'manual setting overwritten')end
 local child=modules.ModSetting.new('testCost','TEST',{0,1},{'OFF','ON'},1)
 P.configure({{setting=child,max=1,handheld=0,eco=0}})
 P.setting:sync('auto');P.apply(nil,false);assert(child:get()==0)
 child:sync(1);P.setting:sync('custom');P.apply(nil,false);assert(child:get()==1,'CUSTOM overwritten')
 local L=assert(loadfile(root..'/lib/LocalLights.lua'))(V)
 assert(not L.mobile and L.handheld,'Deck must keep desktop graphics APIs')
 assert(L.MAX_LIGHTS==4 and L.MAX_BATTLE_LIGHTS==2 and L.MAX_BLOCKERS==4 and L.MAX_PORTALS==2)
 parent._vascDeviceHardware={steamDeck=false}
 assert(P.resolve('auto')==(gen==1 and 'high'or'handheld'))
 L=assert(loadfile(root..'/lib/LocalLights.lua'))(V)
 assert(not L.handheld and L.MAX_LIGHTS==8 and L.MAX_BATTLE_LIGHTS==4)
end
local host={detect=function()return 'high'end}
function host.resolve(value)return value=='auto' and host.detect()or value end
assert(not H.installAutoProfile(host,{steamDeck=false}) and host.resolve('auto')=='high')
assert(H.installAutoProfile(host,hardware) and host.resolve('auto')=='balanced')
for _,value in ipairs({'high','balanced','low'})do assert(host.resolve(value)==value)end
assert(H.installAutoProfile(host,hardware) and host.resolve('auto')=='balanced')
print('PASS Steam Deck detection, negative controls, missing APIs, facade inheritance, AUTO/manual/CUSTOM, shared lighting budgets')
