-- Gen-1 scene adapter. APO owns species/source selection and gameplay owns
-- entities. Only a successfully built imported mesh replaces the captured card.
local V = ...
local Pack = V.require("StadiumPack")
local Mon = V.require("StadiumMon")
local M = {}
local slots = {}
local baseKeep = tonumber(Pack.KEEP) or 4
local stats = {prepared=0, drawn=0, failed=0, active=0}
local function dexNumber(value)
  local n=tonumber(value)
  if n and n==math.floor(n) and n>=1 and n<=251 then return n end
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
  if p.isPlayer or not e or e.ascendantPokemonModelSource~="stadium2"
      or e.pokemonModel==false or e.stadiumModel==false then return nil end
  return dexNumber(e.ascendantPokemonModelDex)
end
local function prepareOne(p,dex,dt)
  local slot=slots[p.entity]
  if not slot then slot={mon=Mon.new("overworld")};slots[p.entity]=slot end
  local mon=slot.mon
  if not mon:setSpecies(dex,true) or not mon.rig then return false end
  if Pack.keep then Pack.keep(dex) end
  -- Reuse the imported model's established sizing and bind-pose safety.
  -- Keep low-profile species readable above Gen-1 grass.
  local height=mon:worldHeight()
  mon.scale=height>0 and math.max(1,12/height) or 1
  mon:update(dt)
  local fx,fz=0,1
  if p.facing=="up" then fz=-1
  elseif p.facing=="left" then fx,fz=-1,0
  elseif p.facing=="right" then fx,fz=1,0 end
  local matrix=mon:matrix(p.px+8,p.gh+(p.lift or 0),p.py+8,fx,fz)
  if not matrix or not mon:build() then return false end
  p.stadiumMon,p.stadiumMatrix,p.stadiumDex=mon,matrix,dex
  p.stadiumShadowTick=math.floor((mon.time or 0)*12)
  return true
end
function M.prepare(posed)
  local live,demand={},{}
  local count=0
  for _,p in ipairs(posed or {}) do
    p.stadiumMon,p.stadiumMatrix,p.stadiumDex,p.stadiumShadowTick=nil,nil,nil,nil
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
function M.draw(p)
  if not (p.stadiumMon and p.stadiumMatrix) then return false end
  local ok,result=pcall(p.stadiumMon.rig.draw,p.stadiumMon.rig,p.stadiumMatrix,nil)
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
function M.cast(p,shadow)
  if not (p.stadiumMon and p.stadiumMatrix) then return false end
  local ok,result=pcall(p.stadiumMon.rig.caster,p.stadiumMon.rig,shadow,p.stadiumMatrix)
  return ok and result~=false
end
function M.status()
  local out={};for k,v in pairs(stats) do out[k]=v end;return out
end
return M
