local root=assert(arg[1]);local settings={};local modules={}
local V={require=function(n)return assert(modules[n],n)end}
modules.CanvasPresentation={OS='OS X'}
modules.ModSetting={new=function(key,_,_,_,default)
 settings[key]=default
 return {get=function()return settings[key]end,setGate=function()end}
end}
local G={tint={.4,.5,.6}};modules.Voxel3D=G
local t=0
modules.DayNight={isCanopy=function(m)return m.id=='FOREST'end,
 rigTime=function()return t end,time=function()return t end,strengthAt=function()return 1 end,
 shearAt=function()return -.5,.5,false end,windowLight=function()return .5 end,
 applyRig=function(outdoor,dynamic)assert(outdoor and dynamic)end}
modules.Sky={clock=0};modules.TowerAtmosphere={active=function()return false end}
modules.VoxelBattleStage={presentationWindowScene=function()return nil end}
modules.CaveTorches={eligible=function()return false end}
modules.InteriorLights={prepare=function()end}
modules.VoxelItems={models={glass={boxes={{0,4,10,10,12,1}}}}}
modules.VoxelFurniture={eachWorld=function()error('MAP must use retained battle props')end}
modules.LightVisibility=assert(loadfile(root..'/lib/LightVisibility.lua'))(V)
local L=assert(loadfile(root..'/lib/LocalLights.lua'))(V);modules.LocalLights=L
local B=assert(loadfile(root..'/lib/BattleLights.lua'))(V)
local map={id='FIELD',def={generation=1,tileset='OVERWORLD'}}
local state={map=map};local a={mid={16,16},player={0,16},enemy={32,16},discs=true,arenaStyle={}}
for _,world in ipairs({false,true})do for _,battle in ipairs({false,true})do
 settings.localLights=world;settings.battleLights=battle
 for _,mode in ipairs({'MAP','ARENA','DISCS','TERARRIUM','2D'})do
  local on=B.enabled(mode,map)
  assert(on==(battle and (mode=='MAP' or mode=='ARENA')),'switch scope '..mode)
  B.prepare(state,map,a,true,0,nil,on,'clear')
  assert((L.current().battle==true)==on)
  assert((L.current().sky~=nil)==on)
  assert(L.active()==on,'world setting leaks into battle')
 end
end end
settings.battleLights=true;settings.localLights=false
assert(not B.enabled('ARENA',map,{terarrium={}}),'Terrarium accepted a misleading ARENA label')
assert(not B.enabled('MAP',map,{discs=true}),'DISCS accepted a misleading MAP label')
local gen2={def={generation=2}}
assert(not B.enabled('MAP',gen2) and not B.enabled('ARENA',gen2))
map.def.tileset='CAVERN'
local f=B.prepare(state,map,a,false,10,nil,true,'clear')
assert(not f.sky and #f.lights==2 and f.lights[1].y==54,'portable cave placement')
local first=f.lights[1].power;modules.Sky.clock=1
assert(B.prepare(state,map,a,false,10,nil,true,'clear').lights[1].power~=first,'torch rig does not flicker')
map.id='FOREST';assert(B.prepare(state,map,a,false,0,nil,true,'clear').sky.canopy==1)
map.id='FIELD';map.def.tileset='OVERWORLD';a.discs=false
local props={furniture={{mat={1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1},extra={glow=1,
 lightModel={terrain=true,glassKind='glass',boxes={{0,0,0,10,20,10}}}}}}}
f=B.prepare(state,map,a,true,0,props,true,'clear')
assert(f.battle and #f.lights==1,'retained MAP source missing with world OFF')
f=B.prepare(state,map,a,true,0,{furniture={}},true,'clear')
assert(#f.lights==0,'removed MAP building left phantom emitter')
settings.localLights=true
L.prepare({map=map},true,{0,0,0},false,'clear',false,{furniture={}})
assert(not L.current().battle and L.active(),'battle state leaked into world')
modules.CanvasPresentation.OS='iOS'
modules.LocalLights=assert(loadfile(root..'/lib/LocalLights.lua'))(V)
local mobile=assert(loadfile(root..'/lib/BattleLights.lua'))(V)
assert(mobile.enabled('MAP',map) and modules.LocalLights.MAX_BATTLE_LIGHTS==2,'mobile battle lighting missing')
-- The world switch cannot change the released rig in excluded battles.
local file=assert(io.open(root..'/lib/DayNight.lua','rb'));local source=file:read('*a');file:close()
local body=assert(source:match('(function DayNight.applyRig%b()%s.-)\nend'))..'\nend'
local D={T={day=300},rigTime=function()return 800 end,
 shearAt=function()return .11,.22,false end,strengthAt=function()return 1 end,ALPHA_SUN=.4,ALPHA_MOON=.2}
local SM={};modules.ShadowMap=SM;modules.Voxel3D=G;modules.LocalLights=L;settings.localLights=true
assert(loadstring('local V,DayNight=...; '..body))(V,D)
D.applyRig(true,false);assert(SM.KX==.11 and G.SHADOW_KZ==.22,'excluded battle inherited world sun rig')
D.applyRig(true,true);assert(SM.KX~=.11,'active battle lost dynamic sun rig')
print('PASS_BATTLE_LIGHTS: independent switches, MAP/ARENA scope, portable placement, canopy, retained props, no stale emitters, world restore, Gen2/mobile')
