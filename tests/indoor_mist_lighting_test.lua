-- A real GPU comparison: lighting may change RGB, but never fog opacity.
local root=assert(arg[1]);local active=false;local frame={}
local lights={active=function()return active end,current=function()return frame end,
 send=function()end,glsl=function()return [[
 const vec4 localSkyState=vec4(0.0);
 vec3 localIrradiance(vec3 p,vec3 n){return vec3(20.0,10.0,5.0);}
 float localSurfaceShade(float a,vec3 n,vec3 p){return 1.0;}
 ]]end}
local modules={LocalLights=lights,Sky={clock=0},
 Weather={isLavender=function(map)return map.id=='LAVENDER_TOWN'end},
 TowerAtmosphere={active=function(map)return map.id:match('^POKEMON_TOWER_')end},
 LedgeElevation={basisAtCell=function()return 0 end}}
local M=assert(loadfile(root..'/lib/IndoorMist.lua'))({require=function(n)return assert(modules[n],n)end})
local g=love.graphics
local target=g.newCanvas(64,64,{format='rgba16f',dpiscale=1})
local depthData=love.image.newImageData(64,64)
for y=0,63 do for x=0,63 do
 local d=.25+.7*x/63;depthData:setPixel(x,y,d,d,d,1)
end end
local depth=g.newImage(depthData);depthData:release()
-- Orthographic view through the entire floor-to-ceiling mist volume.
local vp={1/32,0,0,0, 0,1/32,0,-1, 0,0,1/192,-5/6, 0,0,0,1}
local changed=0
for _,case in ipairs({{'POKEMON_TOWER_3F',.018,42},{'VIRIDIAN_FOREST',.009,44}})do
 local map={id=case[1],def={generation=1,width=10,height=10}}
 -- A generic light shell must not replace either location's atmosphere.
 frame={map=map,interior={profile={shellHeight=8}}}
 active=false;local off=M.profile(map,false)
 active=true;local on=M.profile(map,false)
 assert(off==on and on.density==case[2] and on.height==case[3],'light setting changes fog profile')
 local images={}
 for i=1,2 do
  active=i==2
  g.push('all');g.setCanvas(target);g.clear(0,0,0,0);g.setCanvas();g.pop()
  assert(M.draw(map,false,target,depth,vp));images[i]=target:newImageData()
  assert(M.last.width==32 and M.last.height==32 and M.last.samples==12,'light setting changes integration grid')
 end
 local visible=0
 for y=0,63 do for x=0,63 do
  local r1,_,_,a1=images[1]:getPixel(x,y)
  local r2,_,_,a2=images[2]:getPixel(x,y)
  assert(math.abs(a1-a2)<.001,'lighting thins fog on GPU')
  assert(r2-r1<=.251*a2+.005,('scattering washes out the mist: %.6f %.6f %.6f'):format(r1,r2,a2))
  if a1>.01 then visible=visible+1 end
  if r2>r1+.001 then changed=changed+1 end
 end end
 assert(visible>100,'test volume is not visible')
 for _,im in ipairs(images)do im:release()end
 print('PASS_FOG_OPACITY',case[1],visible)
end
assert(changed>100,'test never exercised illuminated fog')
assert(not M.profile({def={generation=2}},false),'Gen2 unexpectedly enabled')
assert(not M.profile({id='POKEMON_TOWER_3F',def={generation=1}},true),'FLASH darkness lifted')
M.invalidate();depth:release();target:release()
print('PASS_INDOOR_MIST_LIGHTING: unchanged tower/forest density, height, grid and GPU alpha; bounded scattering')
