local M={roles={red=true,blue=true,green=true,gold=true,silver=true,kris=true}}
function M.identity(battle, override)
  if M.roles[override] then return override end
  local game=battle and battle.game
  local player=game and game.overworld and game.overworld.player
  local def=player and player.sprite and player.sprite.def or {}
  for _,key in ipairs({'ascendantRole','ascendantCharacter'})do
   local role=tostring(def[key] or ''):lower()
   if M.roles[role]then return role end
  end
  local s=table.concat({tostring(def.id or ''),tostring(def.name or ''),
    tostring(def.ascendantRole or ''),tostring(def.ascendantCharacter or ''),
    tostring(battle and battle.playerBackPic and battle.playerBackPic.path or '')},'|'):upper()
  if s:find('KRIS',1,true) then return 'kris' end
  if s:find('SILVER',1,true) then return 'silver' end
  if s:find('GOLD',1,true) or s:find('CHRIS',1,true) then return 'gold' end
  if s:find('GREEN',1,true) then return 'green' end
  if s:find('BLUE',1,true) then return 'blue' end
  return 'red'
end
function M.wobbles(caught, shakes)
  local count=0
  shakes=math.max(0,math.min(3,math.floor(tonumber(shakes) or 0)))
  return function()
    count=count+1
    if caught then return count>=4 and 1 or 0 end
    return count>shakes and 2 or 0
  end
end
-- Affine endpoint transfer: retain every native Johto bounce/arc offset,
-- relocate the hand and the final ground contact to the live combat actors.
function M.transfer(state,x,y,frame)
 local t=math.max(0,math.min(1,(frame-1)/35))
 local lx,ly=state.launchX or 22,state.launchY or 60
 local tx,ty=state.targetX or 124,state.targetY or 56
 return x+(lx-60)*(1-t)+(tx-128)*t,
        y+(ly-76)*(1-t)+(ty-56)*t
end
return M
