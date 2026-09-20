-- Actual shader probes, with desktop and mobile budgets on the available GPU.
local root=assert(arg[1])
for _,os in ipairs({'OS X','Android'})do
 local modules={CanvasPresentation={OS=os},Sky={clock=0}}
 modules.ModSetting={new=function()return{setGate=function()end,get=function()return false end}end}
 modules.LightVisibility={prepare=function()error('Terrarium must not render a visibility volume')end}
 local V={require=function(n)return assert(modules[n],n)end}
 local L=assert(loadfile(root..'/lib/LocalLights.lua'))(V)
 local flag=true;local G={}
 local rig=assert(loadfile(root..'/integrated/terarrium/Lighting.lua'))()({lights=L,graphics=G,enabled=function()return flag end,clock=function()return 2 end})
 local ao=rig.bake({{0,0,0,12,18,12}})
 local a={terarrium={id='CINNABAR_GYM'},mid={0,0}}
 assert(rig.prepare(a,0,ao));assert(#L.current().lights==(os=='Android'and 2 or 3))
 local shader=love.graphics.newShader(L.glsl()..[[
 uniform vec3 probe;uniform float mode;
 vec4 effect(vec4 c,Image tex,vec2 uv,vec2 screen){
  vec3 n=vec3(0,1,0);
  if(mode>1.5)return vec4(vec3(localSurfaceShade(1.0,n,probe)),1);
  if(mode>.5)return vec4(localActorIrradiance(probe,n),1);
  return vec4(localIrradiance(probe,n),1);
 }
 ]])
 local canvas=love.graphics.newCanvas(1,1,{dpiscale=1})
 local function sample(x,y,z,mode)
  L.send(shader,true);shader:send('probe',{x,y,z});shader:send('mode',mode)
  love.graphics.push('all');love.graphics.setCanvas(canvas);love.graphics.origin();love.graphics.setShader(shader);love.graphics.clear();love.graphics.setColor(1,1,1,1);love.graphics.rectangle('fill',0,0,1,1);love.graphics.pop()
  local data=canvas:newImageData();local r,g,b=data:getPixel(0,0);data:release();return r,g,b
 end
 local r,g,b=sample(0,12,0,1);assert(r>.07 and r>g and g>b,'warm light missing on actors')
 assert(sample(1000,0,0,0)==0,'light range unbounded')
 local contact=sample(0,0,0,2);assert(contact<.91 and contact>.65,'contact lightmap missing')
 assert(sample(60,0,60,2)>.99,'empty floor darkened')
 assert(sample(0,-20,0,2)>.99,'bowl/signature received floor occlusion')
 assert(sample(0,30,0,2)>.99,'occlusion projected through entire height')
 flag=false;assert(not rig.prepare(a,0,ao));assert(sample(0,12,0,1)==0 and sample(0,0,0,2)>.99,'OFF retained lightmap or local light')
 flag=true;rig.prepare(a,0,ao);assert(sample(0,12,0,1)>.07)
 rig.release();assert(not L.active());ao:release();shader:release();canvas:release()
 print('PASS_TERRARIUM_GPU',os,'real actor light, cached soft contact shade, floor/shell bounds, OFF, release')
end
