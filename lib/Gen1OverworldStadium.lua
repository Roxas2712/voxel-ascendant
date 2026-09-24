-- Gen-1 scene adapter. APO owns species/source selection and gameplay owns
-- entities. Only a successfully built imported mesh replaces the captured card.
local V = ...
local Pack = V.require("StadiumPack")
local Mon = V.require("StadiumMon")
local Bounds = V.require("StadiumActorBounds")
local identity={1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}
local M = {}
local slots = {}
local baseKeep = tonumber(Pack.KEEP) or 4
local stats = {prepared=0, drawn=0, failed=0, active=0}
local function dexNumber(value)
  local n=tonumber(value)
  if n and n==math.floor(n) and n>=1 and n<=1026 then return n end
end
function M.available(dex)
  dex=dexNumber(dex)
  if not dex then return false end
  local ok,model=pcall(Pack.load,dex)
  return ok and type(model)=="table"
end
local function release(entity)
  local slot=slots[entity]
  if slot then pcall(slot.mon.release,slot.mon);slots[entity]=nil end
end
function M.releaseAll()
  for entity in pairs(slots) do release(entity) end
  stats.active=0
end
local function selected(p)
  local e=p.entity
  if p.isPlayer or not e or (e.ascendantPokemonModelSource~="stadium2" and e.ascendantPokemonModelSource~="cobblemon")
      or e.pokemonModel==false or e.stadiumModel==false then return nil end
  return dexNumber(e.ascendantPokemonModelDex)
end
local function prepareOne(p,dex,dt)
  local provider=p.entity.ascendantPokemonModelSource=="cobblemon" and V.require("CobblemonPack") or nil
  local slot=slots[p.entity]
  if slot and slot.mon.provider~=provider then release(p.entity);slot=nil end
  if not slot then slot={mon=Mon.new("overworld",provider)};slots[p.entity]=slot end
  local mon=slot.mon
  if not mon:setSpecies(dex,true,p.entity.ascendantPokemonModelAppearance) or not mon.rig then return false end
  if Pack.keep then Pack.keep(dex) end
  if provider then
    local scale,reference=V.require("CobblemonOverworldSize").scale(mon,dex)
    if not scale then return false end
    mon.scale=scale
    p.stadiumSizeReference=reference
  else
    local height=mon:worldHeight()
    mon.scale=height>0 and math.max(1,12/height) or 1
  end
  if mon.model and mon.model.actions then
    local moved=slot.x and (math.abs(p.px-slot.x)+math.abs(p.py-slot.y)>.01)
    local clip=moved and mon.model.actions.walk or mon.model.actions.idle
    if clip and mon.anim~=clip then mon:play("idle",clip) end
    slot.x,slot.y=p.px,p.py
  end
  mon:update(dt)
  local fx,fz=0,1
  if p.facing=="up" then fz=-1
  elseif p.facing=="left" then fx,fz=-1,0
  elseif p.facing=="right" then fx,fz=1,0 end
  local matrix=mon:matrix(p.px+8,p.gh+(p.lift or 0),p.py+8,fx,fz)
  if not matrix then return false end
  -- The existing safety fallback holds an immutable bind pose. Movement
  -- still changes the world matrix, but cannot require another CPU skin /
  -- GPU vertex upload until its rig or facing-dependent lighting changes.
  local static=mon.staticPose and not mon.anim
  local reuse=static and slot.builtRig==mon.rig and slot.builtYaw==mon.yaw
  if not reuse then
    if not mon:pose()then return false end
  end
  p.stadiumMon,p.stadiumMatrix,p.stadiumDex=mon,matrix,dex
  p.stadiumUploadPending=not reuse
  p.stadiumSlot=slot
  p.stadiumBounds=Bounds.world(mon.rig,matrix)
  if p.swimming and p.waterline and p.stadiumBounds then
    -- Imported rigs can carry a native hover offset (Tentacool, for example).
    -- Anchor the actually posed body to the water, not to its hovering root.
    -- Reuse its already calculated bounds; no extra skin/upload/readback.
    local b=p.stadiumBounds
    local height=math.max(.1,b[5]-b[2])
    local offset=p.waterline-height*.45+(p.swimBob or 0)-b[2]
    matrix[8]=matrix[8]+offset
    b[2],b[5]=b[2]+offset,b[5]+offset
  end
  p.stadiumShadowTick=math.floor((mon.time or 0)*12)
  return true
end
function M.prepare(posed)
  local live,demand={},{}
  local count=0
  for _,p in ipairs(posed or {}) do
    p.stadiumMon,p.stadiumMatrix,p.stadiumDex,p.stadiumShadowTick=nil,nil,nil,nil
    p.stadiumBounds=nil
    p.stadiumSizeReference=nil
    p.stadiumUploadPending,p.stadiumSlot=nil,nil
    local dex=selected(p)
    if dex then
      live[p.entity]=true
      if not demand[dex] then demand[dex]=true;count=count+1 end
    end
  end
  for entity in pairs(slots) do if not live[entity] then release(entity) end end
  -- A later species must not evict textures retained by an earlier live rig.
  Pack.KEEP=math.max(tonumber(Pack.KEEP) or baseKeep,baseKeep+count)
  for dex in pairs(demand) do if Pack.keep then Pack.keep(dex) end end
  local dt=love.timer and love.timer.getDelta and love.timer.getDelta() or 1/60
  dt=math.max(0,math.min(tonumber(dt) or 0,0.1))
  stats.active=0
  for _,p in ipairs(posed or {}) do
    local dex=selected(p)
    if dex then
      local ok,ready=pcall(prepareOne,p,dex,dt)
      if ok and ready then stats.prepared=stats.prepared+1;stats.active=stats.active+1
      else
        stats.failed=stats.failed+1
        stats.lastError=tostring(ok and "model-unavailable" or ready)
        release(p.entity)
      end
    end
  end
end
local function upload(p)
  if not p.stadiumUploadPending then return true end
  local ok,ready=pcall(p.stadiumMon.upload,p.stadiumMon)
  if not ok or ready==false then
    stats.lastError=tostring(ready);stats.failed=stats.failed+1
    return false
  end
  p.stadiumUploadPending=false
  local slot=p.stadiumSlot
  slot.builtRig,slot.builtYaw=p.stadiumMon.rig,p.stadiumMon.yaw
  return true
end
function M.draw(p,visible,pull)
  if not (p.stadiumMon and p.stadiumMatrix) then return false end
  -- A culled imported model is still the owner: never draw its sprite
  -- fallback, release its rig, or interrupt its animation clock here.
  if visible and not visible(p.stadiumBounds,identity)then return true end
  if not upload(p)then return false end
  -- Grass and sprite actors share this camera-depth correction. Imported
  -- bodies need it too, or even grass behind them wins the depth test.
  -- Shadows keep the physical matrix with no camera pull.
  local ok,result=pcall(p.stadiumMon.rig.draw,p.stadiumMon.rig,p.stadiumMatrix,pull)
  -- StadiumRig restores atlas state. The following actors still need the
  -- billboard state until VoxelScene finishes the complete actor pass.
  local renderer=V.require("Voxel3D")
  renderer.seams(false);renderer.glass(false);renderer.blend(nil)
  if love.graphics and love.graphics.setColor then love.graphics.setColor(1,1,1,1) end
  if not ok or result==false then
    stats.lastError=tostring(result);stats.failed=stats.failed+1;return false
  end
  stats.drawn=stats.drawn+1
  return true
end
function M.cast(p,shadow,visible)
  if not (p.stadiumMon and p.stadiumMatrix) then return false end
  if visible and not visible(p.stadiumBounds,identity)then return true end
  if not upload(p)then return false end
  local ok,result=pcall(p.stadiumMon.rig.caster,p.stadiumMon.rig,shadow,p.stadiumMatrix)
  return ok and result~=false
end
function M.status()
  local out={};for k,v in pairs(stats) do out[k]=v end;return out
end
return M
