-- Air, not a dark floor decal: integrate drifting density between the camera
-- and the actual scene depth. One half-resolution pass, twelve bounded samples.
local V=...
local M={}
local shader,noise,buffer,bw,bh
local slices,sliceShader,sliceMap,sliceBase
local tower={color={.48,.46,.54},density=.018,height=42}
local cave={color={.43,.47,.50},density=.015,height=38}
local town={color={.43,.44,.49},density=.009,height=48}
local forest={color={.43,.49,.44},density=.009,height=44}
local outdoorTint={}
local function isForest(map)
 local d=map and map.def
 return d and d.generation~=2 and (map.id or d.id)=='VIRIDIAN_FOREST'
end
function M.tint(map,normal)
 local forestMap=isForest(map)
 if not forestMap and not V.require("Weather").isLavender(map)then return normal end
 outdoorTint[1]=normal[1]*(forestMap and .72 or .68)
 outdoorTint[2]=normal[2]*(forestMap and .80 or .70)
 outdoorTint[3]=normal[3]*(forestMap and .73 or .80)
 return outdoorTint
end
function M.base(map)
 if not isForest(map)and not V.require("Weather").isLavender(map)then return 0 end
 return V.require("LedgeElevation").basisAtCell(map,map.def.width,map.def.height)
end
function M.profile(map,dark)
 local d=map and map.def
 if not d or d.generation==2 or dark then return nil end
 if V.require('Weather').isLavender(map)then return town end
 if isForest(map)then return forest end
 if V.require('TowerAtmosphere').active(map)then
  return tower
 elseif d.tileset=='CAVERN'then
  return cave
 end
end
-- Pivoted inverse handles both perspective and orthographic camera modes.
function M.inverse(m)
 local a={}
 for r=1,4 do a[r]={};for c=1,8 do a[r][c]=c<=4 and m[(r-1)*4+c]or(c-4==r and 1 or 0)end end
 for c=1,4 do
  local p=c;for r=c+1,4 do if math.abs(a[r][c])>math.abs(a[p][c])then p=r end end
  if math.abs(a[p][c])<1e-12 then return nil end
  a[c],a[p]=a[p],a[c];local scale=a[c][c]
  for j=1,8 do a[c][j]=a[c][j]/scale end
  for r=1,4 do if r~=c then local k=a[r][c];for j=1,8 do a[r][j]=a[r][j]-k*a[c][j]end end end
 end
 local out={};for r=1,4 do for c=5,8 do out[#out+1]=a[r][c]end end;return out
end
M.GLSL=[[
uniform Image sceneDepth;
uniform Image mistNoise;
uniform mat4 inverseVP;
uniform vec2 mistResolution;
uniform vec3 mistMin;
uniform vec3 mistMax;
uniform vec3 mistColor;
uniform float mistDensity;
uniform float mistTime;
vec3 unproject(vec2 uv,float depth) {
 vec4 p=inverseVP*vec4(uv*2.0-1.0,depth*2.0-1.0,1.0);
 return p.xyz/p.w;
}
vec4 effect(vec4 color,Image tex,vec2 tc,vec2 sc) {
 vec2 uv=sc/mistResolution;
 vec3 start=unproject(uv,0.0);
 vec3 stop=unproject(uv,min(Texel(sceneDepth,uv).r,0.99999));
 vec3 delta=stop-start;
 float lengthRay=length(delta);
 vec3 ray=delta/max(lengthRay,0.0001);
 // Clip the ray to the air above this floor, not the whole camera distance.
 vec3 safeRay=mix(vec3(0.00001),ray,step(vec3(0.00001),abs(ray)));
 vec3 a=(mistMin-start)/safeRay,b=(mistMax-start)/safeRay;
 vec3 lo=min(a,b),hi=max(a,b);
 float entry=max(0.0,max(lo.x,max(lo.y,lo.z)));
 float exitAt=min(lengthRay,min(hi.x,min(hi.y,hi.z)));
 float stepSize=max(0.0,exitAt-entry)/12.0;
 float optical=0.0;
 for(int i=0;i<12;i++) {
  vec3 p=start+ray*(entry+(float(i)+0.5)*stepSize);
  vec2 drift=vec2(mistTime*0.55,mistTime*0.23);
  float broad=Texel(mistNoise,(p.xz+drift+p.y*vec2(0.8,-0.6))/210.0).r;
  float fine=Texel(mistNoise,(p.xz-drift*0.6)/76.0).r;
  float cloud=smoothstep(0.27,0.73,broad*0.72+fine*0.28);
  float height=(p.y-mistMin.y)/(mistMax.y-mistMin.y);
  float layer=smoothstep(0.0,0.12,height)*(1.0-smoothstep(0.30,1.0,height));
  optical+=stepSize*mistDensity*(0.12+cloud*1.35)*layer;
 }
 return vec4(mistColor,1.0-exp(-optical));
}
]]
local function prepareNoise()
 local g=love.graphics
 if not noise then
  local data=love.image.newImageData(8,8);local seed=71237
  for y=0,7 do for x=0,7 do
   seed=(seed*16807)%2147483647;local n=seed/2147483647;data:setPixel(x,y,n,n,n,1)
  end end
  noise=g.newImage(data);data:release();noise:setFilter('linear','linear');noise:setWrap('repeat','repeat')
 end
end
local function prepare(w,h)
 local g=love.graphics
 if not shader then shader=g.newShader(M.GLSL)end
 prepareNoise()
 if bw~=w or bh~=h then
  if buffer then buffer:release()end
  buffer=g.newCanvas(w,h);buffer:setFilter('linear','linear');bw,bh=w,h
 end
end
-- Phones keep their inexpensive internal depth attachment. They get real
-- translucent air layers tested against it, not a black screen-space mask.
M.SLICE_GLSL=[[
varying vec3 mistWorld;
#ifdef VERTEX
uniform mat4 mistVP;
vec4 position(mat4 transform_projection,vec4 vertex_position) {
 mistWorld=vertex_position.xyz;return mistVP*vertex_position;
}
#endif
#ifdef PIXEL
uniform Image mistNoise;
uniform vec3 mistColor;
uniform float mistTime;
uniform float mistHeight;
uniform float mistBase;
vec4 effect(vec4 color,Image tex,vec2 tc,vec2 sc) {
 vec2 drift=vec2(mistTime*0.55,mistTime*0.23);
 float broad=Texel(mistNoise,(mistWorld.xz+drift+mistWorld.y*vec2(0.8,-0.6))/210.0).r;
 float fine=Texel(mistNoise,(mistWorld.xz-drift*0.6)/76.0).r;
 float cloud=smoothstep(0.27,0.73,broad*0.72+fine*0.28);
 float height=(mistWorld.y-mistBase)/mistHeight;
 float layer=smoothstep(0.0,0.12,height)*(1.0-smoothstep(0.30,1.0,height));
 return vec4(mistColor,(0.015+cloud*0.09)*layer);
}
#endif
]]
function M.drawLayers(map,p,vp)
 local g=love.graphics
 prepareNoise()
 if not sliceShader then sliceShader=g.newShader(M.SLICE_GLSL)end
 local base=M.base(map)
 if sliceMap~=map or sliceBase~=base then
  if slices then slices:release()end
  local vertices={};local w,h=map.def.width*32+32,map.def.height*32+32
  for i=1,12 do
   local y=base+p.height*i/13
   for _,q in ipairs({{-32,-32},{w,-32},{w,h},{-32,-32},{w,h},{-32,h}})do
    vertices[#vertices+1]={q[1],y,q[2]}
   end
  end
  slices=g.newMesh({{'VertexPosition','float',3}},vertices,'triangles','static');sliceMap,sliceBase=map,base
 end
 g.push('all');g.setShader(sliceShader);g.setColor(1,1,1,1)
 g.setDepthMode('lequal',false);g.setBlendMode('alpha','alphamultiply');g.setMeshCullMode('none')
 sliceShader:send('mistVP','row',vp);sliceShader:send('mistNoise',noise)
 sliceShader:send('mistColor',p.color);sliceShader:send('mistHeight',p.height);sliceShader:send('mistBase',base)
 sliceShader:send('mistTime',V.require('Sky').clock or 0)
 g.draw(slices);g.pop()
 M.last={map=map.id,layers=12,draws=1,mode='layers'}
 return true
end
function M.draw(map,dark,canvas,depth,vp)
 local p=M.profile(map,dark)
 if not p then return false end
 if not depth then return M.drawLayers(map,p,vp)end
 local inv=M.inverse(vp);if not inv then return false end
 local w,h=canvas:getDimensions();local fw,fh=math.ceil(w/2),math.ceil(h/2)
 prepare(fw,fh)
 local g=love.graphics
 g.push('all');g.origin();g.setScissor();g.setDepthMode();g.setMeshCullMode('none')
 -- The readable depth must be detached before it becomes a sampler.
 g.setCanvas(buffer);g.clear(0,0,0,0);g.setShader(shader);g.setColor(1,1,1,1)
 shader:send('sceneDepth',depth);shader:send('mistNoise',noise)
 shader:send('inverseVP','row',inv);shader:send('mistResolution',{fw,fh})
 local base=M.base(map)
 shader:send('mistMin',{-32,base,-32})
 shader:send('mistMax',{map.def.width*32+32,base+p.height,map.def.height*32+32})
 shader:send('mistColor',p.color);shader:send('mistDensity',p.density)
 shader:send('mistTime',V.require('Sky').clock or 0)
 g.setBlendMode('replace');g.rectangle('fill',0,0,fw,fh)
 g.setCanvas(canvas);g.setShader();g.setBlendMode('alpha','alphamultiply')
 g.draw(buffer,0,0,0,w/fw,h/fh);g.pop()
 M.last={map=map.id,width=fw,height=fh,samples=12,draws=2,mode='volume'}
 return true
end
function M.invalidate()
 for _,resource in pairs({shader,noise,buffer,slices,sliceShader})do if resource then resource:release()end end
 shader,noise,buffer,bw,bh=nil,nil,nil,nil,nil
 slices,sliceShader,sliceMap,sliceBase=nil,nil,nil,nil
end
return M
