local function extract(path,first,last,env)
 local f=assert(io.open(path));local s=f:read('*a');f:close()
 local a=assert(s:find(first,1,true));local b=assert(s:find(last,a,true))
 local fn=assert(loadstring(s:sub(a,b-1)));setfenv(fn,setmetatable(env,{__index=_G}));fn()
end
for _,mobile in ipairs({false,true})do
 local mode='full'
 local VoxelScene={skyShade=function(_,t)return{.5,.5,.5,t}end}
 local env={VoxelScene=VoxelScene,MOBILE_RUNTIME=mobile,SKY_SHADE=1,CANOPY_SHADE=1,
  DayNight={isCanopy=function(m)return m.canopy end,canopyPalette=function()return{{20,50,20}}end},
  PaletteFX={effectiveColors=function(p)return p end},
  HorizonWall={hasSky=function(m)return m.outdoor end},
  Sky={enabled=function()return mode~='off'end,haze=function()return{.1,.2,.3}end}}
 extract('lib/VoxelScene.lua','local function sceneSkyColor','-- The free-roam sky:',env)
 local outside={outdoor=true}
 assert((VoxelScene.skyColor(outside,1)==nil)==mobile,'overworld policy changed')
 for _,choice in ipairs({'full','flat','off','full'})do
  mode=choice;local sky=VoxelScene.arenaSkyColor(outside,1)
  assert((sky==nil)==(choice=='off'),'arena lost sky after setting change')
  assert(VoxelScene.arenaSkyColor({},1)==nil,'interior gained outdoor sky')
  local canopy=VoxelScene.arenaSkyColor({canopy=true},1)
  assert(choice=='off' and canopy==nil or canopy and canopy.canopy,'canopy lost its closed background')
 end
end
print('Arena mobile sky: ok')
