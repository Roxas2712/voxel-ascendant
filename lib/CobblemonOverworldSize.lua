-- Match the Wilds/overworld walking-sprite scale policy, independently of
-- Crystal battle sprites. Measure the actual idle/walk silhouette once: a
-- bind pose with raised wings or a different tail pose is not a size reference.
local V=...
local M={}
local measured=setmetatable({},{__mode='k'})
local profiles
local function policy()
  local api=V.mod and V.mod.exports and V.mod.exports.overworldPokemon
  if api and api.scaleProfiles then return api.scaleProfiles end
  if not profiles then
    local source=assert(V.mod:read('integrated/ascendant_pokemon_overworld/src/scale_profiles.lua'))
    profiles=assert((loadstring or load)(source))()
  end
  return profiles
end
local function positive(x)return type(x)=='number' and x==x and x>0 and x<1e6 end
local function envelope(mon)
  local model,rig=mon.model,mon.rig
  local cached=measured[model];if cached then return cached end
  local h,span=0,0
  local function sample(clip,frame)
    rig:pose(clip,frame,true)
    local x,y,z,X,Y,Z=rig:posedBounds()
    if x then h=math.max(h,Y-y);span=math.max(span,X-x,Z-z) end
  end
  local seen={}
  for _,action in ipairs({'idle','walk'})do
    local clip=model.actions and model.actions[action]
    if clip and not seen[clip] then
      seen[clip]=true
      local seconds=model.anims and model.anims[clip] and model.anims[clip].seconds or 1
      for i=0,15 do sample(clip,seconds*30*i/16)end
    end
  end
  if not next(seen)then sample(nil,0)end
  -- prepareOne poses the current animation again before any draw/upload.
  local root=math.abs(tonumber(model.rootScale)or 1);if root==0 then root=1 end
  cached={height=h*root,span=span*root}
  if not positive(cached.height)or not positive(cached.span)then return nil end
  measured[model]=cached
  return cached
end
function M.scale(mon,dex)
  local reference=policy().worldHeight(nil,dex)
  local size=envelope(mon)
  local base=mon:worldHeight()
  local height=mon.model and mon.model.height
  if not(size and positive(reference)and positive(base)and positive(height))then return nil end
  -- Cancel StadiumMon's battle-derived baseline. Uniform scaling preserves
  -- anatomy; the shared Wilds height tier is the sole overworld reference.
  -- The same-camera Wilds comparison also bounds depth/wing span: allow
  -- 20% over the sprite tier for a 3-D silhouette, not a two-times-long body.
  local fit=math.min(reference/size.height,reference*1.2/size.span)
  return fit*height/base,{reference=reference,height=size.height*fit,span=size.span*fit}
end
return M
