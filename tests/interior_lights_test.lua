-- Real pixel probes for projected room light and live room-layout ownership.
local root=assert(arg[1]);local enabled=true;local phase=0;local modules={}
local V={require=function(n)return assert(modules[n],n)end}
local profile={nativeRoomPanels=true,theme='home',shellHeight=40}
local map={id='REDS_HOUSE_1F',def={generation=1,width=4,height=4,blocks={1,2,3}}}
local layouts=0
modules.HorizonWall={interiorProfileFor=function(m)return m==map and profile end}
modules.Gen1InteriorLayout={panelsFor=function()
 layouts=layouts+1
 return {{edge='north',from=0,upto=128,at=16,openings={}},
  {edge='west',from=16,upto=128,at=0,openings={}},
  {edge='east',from=16,upto=128,at=128,openings={}},
  {edge='south',from=0,upto=128,at=128,openings={{from=48,upto=64,height=24,open=true}}}}
end}
modules.Gen1InteriorFinish=assert(loadfile(root..'/lib/Gen1InteriorFinish.lua'))()
modules.InteriorLights=assert(loadfile(root..'/lib/InteriorLights.lua'))(V)
local I=modules.InteriorLights
local layout=assert(I.layout(map));assert(#layout.portals==2 and #layout.lamps==4)
assert(I.layout(map)==layout and layouts==1,'room layout rebuilt every frame')
map.def.blocks[1]=9;assert(I.layout(map)~=layout and layouts==2,'native geometry mutation ignored')
assert(I.layout({def=map.def})==nil,'unsupported map invented lights')
modules.HorizonWall.enabled=function()return false end
assert(I.layout(map)==nil,'disabled room shell retains phantom window sources')
modules.HorizonWall.enabled=function()return true end
for _,p in ipairs(layout.portals)do
 assert(p.rect[1]<p.rect[2]and p.rect[3]<p.rect[4],'aperture reversed')
 assert(p.position[1]<1 or p.position[1]>127,'light disconnected from rendered window wall')
end
modules.CanvasPresentation={OS='OS X'}
modules.ModSetting={new=function()return {get=function()return enabled end,setGate=function()end}end}
modules.VoxelItems={models={}}
modules.VoxelFurniture={eachWorld=function()end}
modules.Voxel3D={tint={1,1,1}}
modules.CaveTorches={eligible=function()return false end}
modules.TowerAtmosphere={active=function()return false end}
modules.Sky={clock=1}
modules.Shadows={enabled=function()return false end}
modules.ShadowMap={bias=.002,res=1024}
modules.DayNight={isCanopy=function()return false end,windowLight=function()return phase==2 and 1 or 0 end,
 rigTime=function()return phase end,time=function()return phase end,strengthAt=function()return 1 end,
 shearAt=function()return phase==1 and .6 or -.6,0,phase==2 end}
modules.LightVisibility=assert(loadfile(root..'/lib/LightVisibility.lua'))(V)
local L=assert(loadfile(root..'/lib/LocalLights.lua'))(V);modules.LocalLights=L
local shader=love.graphics.newShader(L.glsl()..[[
uniform vec3 samplePosition;
vec4 effect(vec4 c,Image tex,vec2 tc,vec2 sc) { return vec4(localIrradiance(samplePosition,vec3(0,1,0)),1); }
]])
local target=love.graphics.newCanvas(1,1,{format='rgba16f',dpiscale=1})
local function prepare()
 local f=L.prepare({map=map},false,{100,0,72},false,'clear')
 assert(f.interior and #f.portals==2 and not f.sky,'interior got unbounded sky lighting')
 f.lights={};return f
end
local function probe(p)
 L.send(shader,true);shader:send('samplePosition',p)
 love.graphics.push('all');love.graphics.setCanvas(target);love.graphics.origin();love.graphics.setShader(shader)
 love.graphics.setColor(1,1,1,1);love.graphics.rectangle('fill',0,0,1,1)
 love.graphics.setCanvas();love.graphics.pop();local d=target:newImageData();local a,b,c=d:getPixel(0,0);d:release();return a,b,c
end
local f=prepare();local portal
for _,p in ipairs(f.portals)do if p.normal[1]<0 then portal=p end end
local y=portal.rect[3]+(portal.rect[4]-portal.rect[3])*.25
local z=portal.rect[1]+(portal.rect[2]-portal.rect[1])*.25
local spot={portal.position[1]-.6*y,0,z}
local lit=probe(spot);assert(lit>.3,'actual window failed to project onto floor')
local outside=probe({spot[1],0,portal.rect[2]+10});assert(outside<.001,'sun shines through opaque wall')
local mullion=probe({spot[1],0,(portal.rect[1]+portal.rect[2])*.5});assert(mullion<lit*.1,'mullion not projected')
local actor=probe({spot[1]+.6*8,8,z});assert(actor>.3,'raised actor does not receive same beam')
phase=1;prepare();assert(probe(spot)<.01,'sun angle does not move window projection')
phase=2;prepare();local nr,ng,nb=probe(spot);assert(nr>0 and nr<lit and nb>nr,'moon does not change color/intensity')
phase=0;f=prepare();f.blockers={{lo={spot[1]+2,0,z-5},hi={spot[1]+3,35,z+5}}}
assert(probe(spot)<.001,'closed partition leaks sun')
-- Depth-map reception: a foreground caster must interrupt the projection.
local depthData=love.image.newImageData(1,1);depthData:setPixel(0,0,0,0,0,1)
local depth=love.graphics.newImage(depthData);depthData:release()
modules.ShadowMap.active=function()return true end;modules.ShadowMap.texture=function()return depth end
modules.ShadowMap.uvVP={0,0,0,.5,0,0,0,.5,0,0,0,.5,0,0,0,1}
modules.Shadows.enabled=function()return true end
prepare();assert(probe(spot)<lit*.2,'actor/furniture shadow did not block window light')
enabled=false;L.prepare({map=map},false,{0,0,0});assert(probe(spot)==0,'OFF leaves window illumination')
enabled=true;L.prepare({map={id='OTHER',def={generation=1}}},false,{0,0,0})
assert(not L.current().portals and not L.current().interior,'room light leaks through warp')
shader:release();target:release();depth:release()
print('PASS_INTERIOR_LIGHTS: artwork-aligned apertures, cached native room mutations, floor/actor beams, mullions, sun direction, blue moonlight, closed-wall and caster occlusion, OFF and warp reset')
