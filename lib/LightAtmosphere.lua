-- Bounded decorative light motes. No new light sources, shadow passes or
-- gameplay RNG; one depth-tested batch shares the existing scene target.
local V=...
local M={MAX_PARTICLES=V.require('LocalLights').mobile and 24 or 48,FADE_SECONDS=.45}
local particles,vertices={},{}
local mesh,shader
local previous
local function clamp(x,a,b)return math.max(a,math.min(b,x))end
local function smooth(t)t=clamp(t,0,1);return t*t*(3-2*t)end
local function copy(t)return {t[1],t[2],t[3]}end
-- Only ambient colour crosses the doorway. Source positions, wall masks,
-- native darkness and the lighting OFF switch always change immediately.
function M.transition(frame,state,enabled,now)
 local map=state and state.map
 if not enabled or not map or map.def.generation==2 or state.dark or frame.battle then
  previous=nil;return
 end
 local target=frame.tint
 if not target then previous=nil;return end
 local old=previous
 if not old or now<old.seen or now-old.seen>1 then
  previous={map=map,seen=now,color=copy(target)};return
 end
 if old.map~=map then
  previous={map=map,seen=now,start=now,from=copy(old.color),color=copy(old.color)}
  old=previous
 end
 local color=copy(target)
 if old.from then
  local f=smooth((now-old.start)/M.FADE_SECONDS)
  for i=1,3 do color[i]=old.from[i]+(target[i]-old.from[i])*f end
  if f>=1 then old.from=nil end
 end
 old.seen=now;old.color=color
 frame.tint=color;V.require('Voxel3D').tint=color
end
local function hash(x,z)return ((x*127.1+z*311.7)%97)/97 end
function M.sample(frame,focus,now,night,elevation)
 local count=0
 local function add(x,y,z,size,r,g,b,alpha,kind)
  if count>=M.MAX_PARTICLES or alpha<.015 then return end
  count=count+1;local p=particles[count]or {};particles[count]=p
  p.x,p.y,p.z,p.size,p.r,p.g,p.b,p.alpha,p.kind=x,y,z,size,r,g,b,alpha,kind
 end
 local map=frame.map
 if not map or not map.def or map.def.generation==2 then return particles,0 end
 -- A fixed world grid prevents the swarm from following the camera. Fade
 -- at its outer edge before a grid row enters/leaves the small search area.
 if map.id=='VIRIDIAN_FOREST' and not frame.battle and night>.05 then
  local gx,gz=math.floor(focus[1]/48),math.floor(focus[3]/48)
  for dz=-2,2 do for dx=-2,2 do
   local ix,iz=gx+dx,gz+dz;local seed=hash(ix,iz)
   local x=ix*48+12+seed*24;local z=iz*48+12+hash(iz,ix)*24
   local cx,cz=math.floor(x/16),math.floor(z/16)
   if cx>=0 and cz>=0 and cx<map.def.width*2 and cz<map.def.height*2
      and map.isWalkableCell and map:isWalkableCell(cx,cz)then
    local dist=math.sqrt((x-focus[1])^2+(z-focus[3])^2)
    local edge=1-smooth((dist-65)/30)
    local pulse=(.5+.5*math.sin(now*1.7+seed*31))^3
    local base=elevation and elevation:at(cx,cz)or 0
    add(x+math.sin(now*.65+seed*20)*3,base+9+math.sin(now*.9+seed*11)*3,
      z+math.cos(now*.51+seed*18)*3,1.7,.78,1,.30,edge*night*(.12+.65*pulse),'firefly')
   end
  end end
 end
 for _,l in ipairs(frame.lights or {})do
  if (l.kind=='torch' or l.kind=='candle') and (l.weight or 1)>.01 and l.power>0 then
   local candle=l.radius<=30;local seed=hash(l.x,l.z)
   local amount=candle and 1 or 3
   for i=1,amount do
    local phase=(now*(candle and .55 or .72)+seed+i/amount)%1
    local alpha=math.sin(math.pi*phase)^2*(candle and .45 or .7)*(l.weight or 1)
    add(l.x+math.sin(phase*5+seed*19)*phase*2,l.y+phase*(candle and 7 or 15),
      l.z+math.cos(phase*4+seed*17)*phase*1.4,candle and .55 or .8,1,.47,.10,alpha,'spark')
   end
  end
 end
 return particles,count
end
M.GLSL=[[
varying vec4 moteColor;
#ifdef VERTEX
uniform mat4 vp;
uniform vec3 curve;
attribute vec4 MoteColor;
vec4 position(mat4 transform_projection,vec4 vertex_position) {
 vec4 p=vertex_position;
 vec2 delta=p.xz-curve.xy;p.y-=dot(delta,delta)*curve.z;
 moteColor=MoteColor;return vp*p;
}
#endif
#ifdef PIXEL
vec4 effect(vec4 color,Image tex,vec2 tc,vec2 sc) {
 float d=length(tc*2.0-1.0);
 float alpha=max(0.0,1.0-d);alpha*=alpha;
 return vec4(mix(moteColor.rgb,vec3(1,.97,.72),1.0-smoothstep(.0,.25,d)),alpha*moteColor.a)*color;
}
#endif
]]
local corners={{-1,-1,0,0},{1,-1,1,0},{1,1,1,1},{-1,-1,0,0},{1,1,1,1},{-1,1,0,1}}
function M.draw(state)
 local lights=V.require('LocalLights');local frame=lights.current()
 M.last={count=0,draws=0}
 if not lights.active() or not frame.map or (state and state.dark) then return false end
 local G=V.require('Voxel3D');local vp=G.vp
 if not vp then return false end
 local forest=frame.map.id=='VIRIDIAN_FOREST'
 local height=forest and V.require('LedgeElevation').map(frame.map)or nil
 local list,count=M.sample(frame,G.focus or {0,0,0},V.require('Sky').clock or 0,
   forest and V.require('DayNight').windowLight()or 0,height)
 if count==0 then return false end
 local g=love.graphics
 if not shader then shader=g.newShader(M.GLSL)end
 if not mesh then mesh=g.newMesh({{'VertexPosition','float',3},{'VertexTexCoord','float',2},
   {'MoteColor','float',4}},M.MAX_PARTICLES*6,'triangles','stream')end
 local rx,ry,rz=vp[1],vp[2],vp[3];local rl=math.sqrt(rx*rx+ry*ry+rz*rz)
 local ux,uy,uz=vp[5],vp[6],vp[7];local ul=math.sqrt(ux*ux+uy*uy+uz*uz)
 if rl<1e-8 or ul<1e-8 then return false end
 rx,ry,rz=rx/rl,ry/rl,rz/rl;ux,uy,uz=ux/ul,uy/ul,uz/ul
 local n=0
 for i=1,count do local p=list[i]
  for _,c in ipairs(corners)do
   n=n+1;local v=vertices[n]or {};vertices[n]=v
   local x,y=c[1]*p.size,c[2]*p.size
   v[1],v[2],v[3]=p.x+rx*x+ux*y,p.y+ry*x+uy*y,p.z+rz*x+uz*y
   v[4],v[5],v[6],v[7],v[8],v[9]=c[3],c[4],p.r,p.g,p.b,p.alpha
  end
 end
 mesh:setVertices(vertices,1,n);mesh:setDrawRange(1,n)
 shader:send('vp','row',vp);shader:send('curve',{G.curveX or 0,G.curveZ or 0,G.curveK or 0})
 g.push('all');g.setShader(shader);g.setDepthMode('lequal',false);g.setMeshCullMode('none')
 g.setBlendMode('add','alphamultiply');g.setColor(1,1,1,1);g.draw(mesh);g.pop()
 M.last={count=count,draws=1};return true
end
function M.invalidate()
 if mesh then mesh:release()end;if shader then shader:release()end
 mesh,shader,previous=nil,nil,nil
 particles,vertices={},{}
end
return M
