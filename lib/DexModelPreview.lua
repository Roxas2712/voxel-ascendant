-- One independent animated Cobblemon preview per Dex screen. No battle options
-- or seen/caught flags are changed. Failure remains local to the artwork slot.
local V=...
local M={}
local Content=V.require("CobblemonContent")
local shaderSource=[[
#ifdef VERTEX
attribute float VertexShade;
varying float shade;
uniform float turn;
uniform float fit;
uniform vec3 centre;
vec4 position(mat4 transform_projection, vec4 vertex_position) {
 vec3 p=(vertex_position.xyz-centre)*fit;
 float x=p.x*cos(turn)+p.z*sin(turn);
 float z=-p.x*sin(turn)+p.z*cos(turn);
 shade=VertexShade;
 return vec4(x/180.0, -(p.y*0.94-z*0.34)/135.0, (z*0.94+p.y*0.34)/600.0,1.0);
}
#endif
#ifdef PIXEL
varying float shade;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 px) {
 vec4 c=Texel(tex,uv)*color;
 if(c.a<0.05) discard;
 return vec4(c.rgb*max(0.72,shade),c.a);
}
#endif
]]

local function release(value)if value and value.release then pcall(value.release,value)end end
local function dispose(state)
 if not state then return end
 release(state.actor);release(state.canvas);release(state.shader)
 state.actor,state.canvas,state.shader=nil,nil,nil
end
function M.release(screen)
 dispose(screen._vascDexModel);screen._vascDexModel=nil
end
function M.draw(screen,species,x,y,w,h)
 local game=screen.game
 local def=game and game.data and game.data.pokemon and game.data.pokemon[species]
 local dex=def and tonumber(def.dex)
 if not dex then M.release(screen);return false end
 local epoch=Content.epoch or 0
 local state=screen._vascDexModel
 if not state or state.species~=species or state.epoch~=epoch then
  M.release(screen);state={species=species,epoch=epoch,turn=math.pi};screen._vascDexModel=state
  local ok,err=pcall(function()
   state.actor=V.require('StadiumMon').new('dex-preview',V.require('CobblemonPack'))
   assert(state.actor:setSpecies(dex,true,{species=species}),'model_unavailable')
   state.actor:update(0);state.actor:pose();state.actor:upload()
   state.shader=love.graphics.newShader(shaderSource)
   state.canvas=love.graphics.newCanvas(360,270)
  end)
  if not ok then dispose(state);state.error=tostring(err);return false end
 end
 if state.error then return false end
 local G=love.graphics;local previous=G.getCanvas();G.push('all')
 local ok,err=pcall(function()
  local now=love.timer.getTime();local dt=math.max(0,math.min(.1,now-(state.clock or now)));state.clock=now;state.turn=state.turn+dt*.2
  local actor=state.actor;actor:update(dt);actor:pose();actor:upload()
  G.setCanvas({state.canvas,depth=true});G.origin();G.setScissor();G.setStencilTest();G.setColorMask(true,true,true,true)
  G.clear(0,0,0,0,true,true);G.setShader(state.shader);G.setDepthMode('less',true);G.setMeshCullMode('none');G.setColor(1,1,1,1)
  local a,b,c,d,e,f=actor.rig:posedBounds()
  local cs,sn=math.abs(math.cos(state.turn)),math.abs(math.sin(state.turn))
  local spanX=cs*(d-a)+sn*(f-c);local spanY=.94*(e-b)+.34*(sn*(d-a)+cs*(f-c))
  local fit=math.min(320/math.max(spanX,.0001),230/math.max(spanY,.0001))
  state.shader:send('centre',{(a+d)/2,(b+e)/2,(c+f)/2});state.shader:send('fit',fit);state.shader:send('turn',state.turn)
  for _,part in ipairs(actor.rig.parts)do if part.texture then part.mesh:setTexture(part.texture);G.draw(part.mesh)end end
 end)
 G.setCanvas(previous);G.pop()
 if not ok then dispose(state);state.error=tostring(err);return false end
 G.push('all');G.setShader();G.setDepthMode();G.setColor(1,1,1,1)
 local scale=math.min(w/360,h/270);G.draw(state.canvas,x+(w-360*scale)/2,y+(h-270*scale)/2,0,scale,scale);G.pop()
 return true
end
return M
