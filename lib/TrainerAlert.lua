-- Draw-only replacement for a trainer's exclamation. The native emote still
-- owns its sixty-frame hold, sound, walk-up and battle callback.
local V=...
local M={}
function M.draw(ctx,project,scale)
  local world=ctx.state
  local emote=world and world.emote
  local npc=emote and emote.npc
  if not (npc and npc~=world.player and npc.def and npc.def.trainerClass
      and not emote.pikaPic and (emote.bubble==nil or emote.bubble==1)) then
    return ctx.drawFx(project,scale)
  end
  local G=V.require('Voxel3D')
  local ground=V.require('VoxelScene').fieldEffectGround(world,npc.px+8,npc.py+16)
  local x,y=G.project(npc.px+8,ground+29,npc.py+16)
  if not x then return ctx.drawFx(project,scale) end
  local bubble=emote.bubble
  emote.bubble=false
  local ok,err=pcall(ctx.drawFx,project,scale)
  emote.bubble=bubble
  if not ok then error(err,0) end
  local g=love.graphics
  local s=math.max(1,math.min(3,(scale or 1)*.6))
  local w,h=16*s,19*s
  x,y=x-w/2,y-h-3*s
  g.push('all');g.setShader();g.setColor(.04,.07,.09,.9)
  g.rectangle('fill',x+2*s,y+2*s,w,h,5*s,5*s)
  g.setColor(1,.98,.87,1);g.rectangle('fill',x,y,w,h,5*s,5*s)
  g.polygon('fill',x+6*s,y+h-1,x+8*s,y+h+4*s,x+11*s,y+h-1)
  g.setLineWidth(s);g.setColor(.75,.15,.16,1)
  g.rectangle('line',x+.5*s,y+.5*s,w-s,h-s,4.5*s,4.5*s)
  g.rectangle('fill',x+6.5*s,y+3*s,3*s,8*s,1*s,1*s)
  g.circle('fill',x+8*s,y+14*s,1.7*s)
  g.pop()
end
return M
