-- Runs in the existing lua_via_love harness: real GPU probes, no screenshot
-- filters. Check received light, occlusion, water direction and scene resets.
local root=assert(arg[1])
local enabled=true
local time=300
local calls={}
local models={}
local currentOS='OS X'
local skyClock=0
local function matrix(x,y,z)
  return {1,0,0,x,0,1,0,y,0,0,1,z,0,0,0,1}
end
local modules={
  InteriorLights={prepare=function()return nil end},
  CanvasPresentation={OS=currentOS},
  ModSetting={new=function(_,_,_,_,default)
    return {get=function()return enabled end,
      setGate=function(self,fn)self.gate=fn end}
  end},
  VoxelItems={models=models},
  VoxelFurniture={eachWorld=function(_,fn)
    for _,c in ipairs(calls)do fn(nil,nil,c.mat,1,c.extra)end
  end},
  Voxel3D={tint={.4,.45,.65}},
  CaveTorches={eligible=function(map)return map.id=='CAVE'end,
    wallCell=function(_,x)return x==2 end},
  TowerAtmosphere={active=function()return false end},
  Sky={clock=skyClock},
  DayNight={isCanopy=function(map)return map.id=='VIRIDIAN_FOREST'end,
    time=function()return time end,rigTime=function()return time end,
    strengthAt=function()return 1 end,
    shearAt=function(t)return t<600 and -.5 or .5,t<600 and -.5 or .5,t>=600 end},
}
local V={require=function(n)return assert(modules[n],n)end}
modules.LightVisibility=assert(loadfile(root..'/lib/LightVisibility.lua'))(V)
local M=assert(loadfile(root..'/lib/LocalLights.lua'))(V)
local building={terrain=true,boxes={{0,0,0,40,30,40}},glassKind='glass'}
local glass={boxes={{10,8,40,20,12,1},{0,8,10,1,12,10},{10,30,10,20,1,20}}}
local shape=M.shape(building,glass)
assert(shape.panes[1].normal[3]==1,'front window direction')
assert(shape.panes[2].normal[1]==-1,'side window direction')
assert(shape.panes[3].normal[2]==1,'skylight direction')
assert(shape==M.shape(building,glass),'model geometry not cached')
assert(glass.boxes[1][3]==40,'authored model mutated')
models.glass={boxes={glass.boxes[1]}}
calls={{mat=matrix(0,0,0),extra={lightModel=building,glow=1}}}
local map={id='ROUTE_18',def={generation=1,width=10,height=10}}
local state={map=map}
M.prepare(state,true,{20,0,50})
local lamp=M.current().lights[1]
assert(lamp and lamp.z>40 and lamp.normal[3]==1)
local initialY=lamp.y
calls[1].mat=matrix(160,12,-80)
M.prepare(state,true,{180,0,-30})
lamp=M.current().lights[1]
assert(lamp.x==180 and lamp.y==initialY+12 and lamp.z<0,'neighbor transform/elevation')
calls[1].mat=matrix(0,0,0)

local shader=love.graphics.newShader(M.glsl()..[[
uniform vec3 probe;
uniform vec3 normal;
uniform vec3 reflected;
uniform float mode;
vec4 effect(vec4 c,Image tex,vec2 tc,vec2 sc) {
 vec3 light=localIrradiance(probe,normal);
 if(mode>2.5) light=localActorIrradiance(probe,normal);
 else if(mode>1.5) light=localWaterLight(probe,reflected);
 else if(mode>.5) light=vec3(localSurfaceShade(.7,normal,probe));
 return vec4(light,1.0);
}
]])
local canvas=love.graphics.newCanvas(1,1,{dpiscale=1})
local function probe(x,y,z,normal,mode,reflected)
  M.send(shader,true)
  shader:send('probe',{x,y,z});shader:send('normal',normal or {0,1,0})
  shader:send('mode',mode or 0);shader:send('reflected',reflected or {0,1,0})
  love.graphics.push('all');love.graphics.setCanvas(canvas);love.graphics.origin()
  love.graphics.setShader(shader);love.graphics.clear();love.graphics.setColor(1,1,1,1)
  love.graphics.rectangle('fill',0,0,1,1);love.graphics.setCanvas();love.graphics.pop()
  local data=canvas:newImageData();local r,g,b=data:getPixel(0,0);data:release()
  return r,g,b
end
M.prepare(state,true,{20,0,50})
local front=probe(20,0,50)
assert(front>.05,'floor receives no light')
assert(probe(20,0,36)==0,'window leaks through its own rear wall')
assert(probe(20,0,150)==0,'light has no finite range')
assert(probe(20,12,50,{0,0,-1})>.05,'vertical actor/facade does not receive light')
-- Head/torso at and above the window: the old up-normal gave only 12%
-- light here. Wrapped actor diffuse must illuminate both, not just feet.
local shoulder=probe(20,initialY,50,{0,1,0},3)
local oldShoulder=probe(20,initialY,50,{0,1,0},0)
assert(shoulder>oldShoulder*3 and shoulder>.16,'side light still misses actor shoulders')
assert(probe(20,initialY+8,50,{0,1,0},3)>.12,'light below actor misses face')
assert(probe(20,initialY,150,{0,1,0},3)==0,'actor wraps beyond finite range')
-- A second building lies between the emitter and receiver.
local blocker={terrain=true,boxes={{0,0,0,40,30,5}},glassKind='empty'}
models.empty={boxes={}}
calls[2]={mat=matrix(0,0,48),extra={lightModel=blocker,glow=0}}
M.prepare(state,true,{20,0,60})
assert(probe(20,0,60)==0,'light passes through an intervening building')
assert(probe(20,12,60,nil,3)==0,'actor wrap leaks through intervening building')
assert(probe(20,12,48,{0,0,-1})>0,'receiving facade shadows itself')
calls[2]=nil;M.prepare(state,true,{20,0,50})
probe(20,0,50)
local count=modules.LightVisibility.rebuilds
M.prepare(state,true,{20,0,50});probe(20,0,50)
assert(modules.LightVisibility.rebuilds==count,'static visibility rebaked each frame')
calls[1].extra.glow=.7;M.prepare(state,true,{20,0,50});probe(20,0,50)
assert(modules.LightVisibility.rebuilds==count,'brightness/flicker invalidates geometric visibility')
calls[1].extra.glow=1;M.prepare(state,true,{20,0,50})
local visibility=modules.LightVisibility
local blankData=love.image.newImageData(1,1)
local blank=love.graphics.newImage(blankData);blankData:release()
local cached=visibility.prepare(M.current(),M,blank)
assert(visibility.prepare(M.current(),M,blank)==cached,'same frame lost cached atlas')
M.invalidate();assert(not M.active(),'renderer reset retained active scene')
M.prepare(state,true,{20,0,50})
local rebuilt=visibility.prepare(M.current(),M,blank)
assert(rebuilt~=cached and visibility.rebuilds==count+1,'renderer reset reused retired visibility atlas')
blank:release()
assert(probe(20,0,50)>0,'surviving shader kept retired light texture')

local l=M.current().lights[1]
local d={l.x-20,l.y,l.z-50};local len=math.sqrt(d[1]^2+d[2]^2+d[3]^2)
for i=1,3 do d[i]=d[i]/len end
local reflected=probe(20,0,50,nil,2,d)
local reversed=probe(20,0,50,nil,2,{-d[1],-d[2],-d[3]})
assert(reflected>reversed+.1,'water reflection ignores viewing/wave direction')
-- Day and moon directions, including canopy ownership.
local sun=probe(20,0,50,{1,0,0},1)
time=900;M.prepare(state,true,{20,0,50})
assert(probe(20,0,50,{1,0,0},1)<sun-.1,'moon failed to change surface lighting')
M.prepare({map={id='VIRIDIAN_FOREST',def=map.def}},false,{20,0,50})
assert(M.current().sky and M.current().sky.canopy==1,'forest lost celestial light')
-- Torch field blocks rock columns; darkness only shortens its local range.
local torch={lightSource={position={8,21,8},normal={1,0,0},radius=62,power=2.1,color={1,.47,.13}}}
calls={{mat=matrix(0,0,0),extra={lightModel=torch,glow=.7}}}
local cave={id='CAVE',def={generation=1,width=5,height=5}}
M.prepare({map=cave},false,{20,0,8})
assert(probe(20,0,8)>0,'torch does not light cave floor')
assert(probe(55,0,8)==0,'torch reveals floor behind cave wall')
assert(not M.current().sky and M.current().wall,'sunlight in sealed cave')
M.prepare({map=cave},false,{20,0,8},true)
assert(M.current().lights[1].radius==26,'unlit cave gets full room illumination')
M.prepare({map={id='HOUSE',def=map.def}},false,{20,0,50})
assert(#M.current().lights==0 and not M.current().wall and not M.current().sky,'warp state leaked')
M.prepare({map={id='ROUTE_18',def={generation=2}}},true,{0,0,0})
assert(#M.current().lights==0,'Gen2 changed')
enabled=false;M.prepare(state,true,{0,0,0});assert(probe(20,0,50)==0,'OFF does not restore local light')

-- The real HD-card hook must preserve its old colors/alpha with OFF, and
-- must change its pixels when a light moves while leaving silhouette intact.
local function read(path)local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end
local source=read(root..'/lib/Voxel3D.lua')
local a=assert(source:find('function Voxel3D.lightCardSource',1,true))
local b=assert(source:find('function Voxel3D.shaderVariant',a,true))
local identity=matrix(0,0,0)
local blankData=love.image.newImageData(1,1);local blank=love.graphics.newImage(blankData);blankData:release()
local G={localLightsActive=true}
local hook=assert(loadstring('local V,Voxel3D,ShadowMap,Shadows,IDENTITY,GlassMask=...; '..source:sub(a,b-1)))
local deps={require=function(n)if n=='LocalLights'then return M end;return V.require(n)end}
hook(deps,G,{texture=function()return blank end,bias=.001,res=1024},
  {enabled=function()return false end},identity,{blank=function()return blank end})
local neutral=assert(read(root..'/integrated/ascendant_pokemon_overworld/src/voxel_characters.lua'):match('local NEUTRAL_CARD_SHADER = %[%[(.-)%]%]'))
local original=love.graphics.newShader(neutral)
local lit=love.graphics.newShader(G.lightCardSource(neutral))
local pixels=love.image.newImageData(4,4)
for y=1,2 do for x=1,2 do pixels:setPixel(x,y,1,.5,.25,1)end end
local texture=love.graphics.newImage(pixels);pixels:release();texture:setFilter('nearest','nearest')
local fmt={{'VertexPosition','float',3},{'VertexTexCoord','float',2},{'VertexShade','float',1}}
local mesh=love.graphics.newMesh(fmt,{{12,0,50,0,1,1},{28,0,50,1,1,1},
  {28,16,50,1,0,1},{12,16,50,0,0,1}},'fan','static');mesh:setTexture(texture)
local target=love.graphics.newCanvas(32,32,{dpiscale=1})
local function card(sh)
 sh:send('vp','row',{.125,0,0,-2.5,0,-.125,0,1,0,0,.001,0,0,0,0,1})
 sh:send('model','row',identity);sh:send('eye',{20,8,100});sh:send('curve',{0,0,0})
 sh:send('pull',0);sh:send('cardAlphaPass',0);sh:send('actorWaterline',-30000)
 if sh==lit then G.sendCardLighting(sh,identity)end
 love.graphics.push('all');love.graphics.setCanvas(target);love.graphics.origin();love.graphics.clear(0,0,0,0)
 love.graphics.setShader(sh);love.graphics.setColor(1,1,1,1);love.graphics.draw(mesh)
 love.graphics.setCanvas();love.graphics.pop();return target:newImageData()
end
local expected=card(original);local off=card(lit)
assert(expected:getString()==off:getString(),'OFF changes HD card pixels/alpha')
enabled=true;time=900;calls={{mat=matrix(0,0,0),extra={lightModel=building,glow=1}}}
modules.Voxel3D.tint={.4,.45,.65};M.prepare(state,true,{20,0,50})
local close=card(lit)
calls[1].mat=matrix(300,0,0);M.prepare(state,true,{20,0,50})
local far=card(lit)
local rClose=close:getPixel(16,16);local rFar=far:getPixel(16,16)
assert(rClose>rFar+.08,'HD card fails to respond to moving light')
for y=0,31 do for x=0,31 do
 local _,_,_,aa=expected:getPixel(x,y);local _,_,_,bb=close:getPixel(x,y)
 assert(aa==bb,'lighting changed HD alpha silhouette')
end end
for _,object in ipairs({expected,off,close,far,original,lit,texture,mesh,target,blank})do object:release()end
-- Haunted tint is confined to the active Tower pass; candle phases differ
-- by world position and never need extra shadow-volume updates.
modules.TowerAtmosphere.active=function(map)return map.id=='POKEMON_TOWER_3F'end
local candle={lightSource={position={8,10,8},normal={0,0,0},radius=24,power=1.45,color={1,.4,.12},kind='candle'}}
calls={{mat=matrix(0,0,0),extra={lightModel=candle,glow=.7}},
 {mat=matrix(32,0,0),extra={lightModel=candle,glow=.7}}}
local tower={map={id='POKEMON_TOWER_3F',def={generation=1,width=10,height=10,tileset='CEMETERY'}}}
M.prepare(tower,false,{20,0,8});local haunted=M.current()
assert(haunted.tint[3]>haunted.tint[1] and haunted.tint[1]==.34 and not haunted.sky)
assert(haunted.lights[1].power~=haunted.lights[2].power,'Tower candles flicker in unison')
assert(haunted.lights[1].kind=='candle','candle identity lost')
enabled=false;M.prepare(tower,false,{20,0,8});assert(#M.current().lights==0,'Tower remains lit with OFF')
modules.CanvasPresentation.OS='iOS'
local mobile=assert(loadfile(root..'/lib/LocalLights.lua'))(V)
assert(mobile.supported and mobile.mobile and mobile.MAX_LIGHTS==4 and mobile.MAX_PORTALS==2 and mobile.setting.gate(true),'mobile budget unavailable')
assert(mobile.glsl():find('/192.0',1,true) and not mobile.glsl():find('localPos4',1,true),'mobile atlas/slot mismatch')
local candidates={}
for i=1,100 do candidates[i]={x=i,y=0,z=0,radius=50,power=1}end
local selected=M.select(candidates,{0,0,0},8)
assert(#selected==8 and selected[1].x==1 and selected[8].weight<1,'light budget/edge fade')
-- A failed visibility pass must unwind graphics state and disable only light.
enabled=true;calls={{mat=matrix(0,0,0),extra={lightModel=building,glow=1}}}
M.invalidate();M.prepare(state,true,{20,0,50})
local rectangle=love.graphics.rectangle;local previousCanvas=love.graphics.getCanvas()
love.graphics.rectangle=function()error('injected visibility draw failure')end
M.send(shader,true)
love.graphics.rectangle=rectangle
assert(M.failure and not M.active(),'failed optional light pass remained active')
assert(love.graphics.getCanvas()==previousCanvas,'failed visibility pass leaked its canvas')
M.invalidate();assert(not M.failure,'renderer reset failed to recover lighting')
shader:release();canvas:release()
print('PASS_LOCAL_LIGHTS: real GPU falloff, facade/actor response, wall occlusion, water reflection, sun/moon, canopy, torch, dark cave, warps, OFF and mobile fallback')
