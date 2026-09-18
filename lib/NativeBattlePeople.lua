-- The HD-people switch also governs the full standing battle cards.
-- Reuse the restored native renderer; never substitute another trainer identity.
local V=...
local M={}
local cache=setmetatable({},{__mode="k"})
function M.enabled()
  local api=V.mod.exports and V.mod.exports.overworldPokemon
  return api and api.walkingSprites and api.walkingSprites.enabled()==false
end
local function renderer(b,side)
  local w=b.game and b.game.overworld
  if not w then return end
  if side=="player"then return w.player and w.player.sprite end
  for _,npc in pairs(w.npcs or {})do
    local d=npc.def
    if d and d.trainerClass==b.oppClass and d.trainerParty==b.partyIndex then return npc.sprite end
  end
end
function M.adapt(b,side,original)
  if not original or not M.enabled()then return original end
  cache[b]=cache[b]or{};local slots=cache[b]
  local p=slots[side]
  if not p then p={};slots[side]=p end
  p.width,p.height,p.intro,p.action=original.width,original.height,original.intro,original.action
  p.role="native:"..tostring(original.role)
  p.releaseHand=original.releaseHand
  function p.setView(view,facing)
    local sprite=renderer(b,side)
    local image,quad,mirror,w,h
    if sprite and sprite.getPoseGeometry and sprite.resolveImage then
      local dir=(view=="back"or view=="terarrium-back")and"up"
        or(view=="front"or view=="terarrium-front")and"down"
        or side=="player"and"right"or"left"
      local pose=sprite:getPoseGeometry(dir,0,false)
      image,quad,mirror,w,h=sprite:resolveImage(),pose.quad,pose.mirror,pose.width,pose.height
    elseif side=="enemy"and b.trainer then
      local B=require("src.battle.BattleState")
      image=B.trainerSprite(b.data,b.trainer,b.oppClass,b.partyIndex)
      if image then w,h=image:getDimensions()end
    end
    if not image then return original end
    if p.image~=image or p.view~=view or p.facing~=facing then
      local g=love.graphics;p.canvas=p.canvas or g.newCanvas(192,256,{dpiscale=1})
      p.canvas:setFilter("nearest","nearest")
      g.push("all")
      local ok,err=pcall(function()
        g.setCanvas(p.canvas);g.origin();g.setShader();g.setScissor();g.setDepthMode();g.clear(0,0,0,0)
        g.setBlendMode("alpha");g.setColor(1,1,1,1)
        local scale=220/h;local x=96-(mirror and -1 or 1)*w*scale/2
        if quad then g.draw(image,quad,x,26,0,mirror and -scale or scale,scale)
        else g.draw(image,x,26,0,scale,scale)end
      end)
      g.pop();if not ok then error(err,0)end
      p.image,p.view,p.facing=image,view,facing
    end
    return p
  end
  return p.setView(original.view or(side=="player"and"back"or"front"),side)
end
return M
