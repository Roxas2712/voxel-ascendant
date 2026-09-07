-- Gold/Silver visible-Wilds bridge for render.compose.
--
-- This module never monkey-patches Gold's World class.  It exposes the visible
-- roaming Pokemon list to both the voxel scene and a guaranteed 2D fallback
-- pass that GoldComposeBridge draws after the vanilla scene when voxel is not
-- ready.  Wilds entities remain outside Gold's persistent script-NPC list.
local mod, wilds = ...

local Bridge = {
  installed = false,
  frames = 0,
  visible = 0,
  drawn = 0,
  drawErrors = 0,
  lastError = nil,
  initAttempts = 0,
  initSuccesses = 0,
  lastInitError = nil,
  _nextInitProbe = 0,
}

local SpawnFx
local spawnFxResolved = false

local function spawnFx()
  if spawnFxResolved then return SpawnFx end
  spawnFxResolved = true
  local V = wilds and wilds.lib
  if V and type(V.require) == "function" then
    local ok, value = pcall(V.require, "spawn_fx")
    if ok and type(value) == "table" then SpawnFx = value end
  end
  return SpawnFx
end

local function ensureMapInitialized(world)
  local logic = wilds and wilds.logic
  local mapId = world and world.map and world.map.id
  if not (logic and mapId and type(logic.onMapEntered) == "function") then
    return false, "Wilds logic/map unavailable"
  end

  local initialized = logic.state and logic.state.initialized == true
  if logic.activeMapId == mapId and initialized then
    Bridge.lastInitError = nil
    return true
  end

  -- map.entered normally performs this bootstrap.  render.compose is a second,
  -- authoritative free-roam seam, so probe here as well in case a Gold build
  -- emitted the map event before the embedded Wilds listener was ready.  Rate
  -- limit failures so a bad map cannot spam a full initialization every frame.
  local now = (love and love.timer and love.timer.getTime and love.timer.getTime())
    or os.clock()
  if now < (Bridge._nextInitProbe or 0) then
    return false, Bridge.lastInitError or "Wilds initialization pending"
  end
  Bridge._nextInitProbe = now + 1.0
  Bridge.initAttempts = Bridge.initAttempts + 1

  local ok, err = pcall(logic.onMapEntered, logic, {
    mapId = mapId,
    map = world.map,
    via = "gold_render_compose_self_heal",
  })
  initialized = logic.state and logic.state.initialized == true
  if ok and logic.activeMapId == mapId and initialized then
    Bridge.initSuccesses = Bridge.initSuccesses + 1
    Bridge.lastInitError = nil
    return true
  end

  Bridge.lastInitError = ok
    and ((logic.state and (logic.state.error or logic.state.reason))
      or "Wilds map initialization did not reach READY")
    or tostring(err)
  return false, Bridge.lastInitError
end

local function visibleWilds(world)
  local out = {}
  ensureMapInitialized(world)
  local logic = wilds and wilds.logic
  if not (logic and type(logic.entities) == "table") then return out end
  local mapId = world and world.map and world.map.id
  local Fx = spawnFx()

  for _, e in pairs(logic.entities) do
    if e and e.overworldWildSpawn == true
       and (e.mapId == nil or e.mapId == mapId)
       and e.visibleSprite ~= false
       and e.hiddenEncounter ~= true then
      local bodyVisible = true
      if Fx and type(Fx.bodyVisible) == "function" then
        local okBody, shown = pcall(Fx.bodyVisible, e)
        bodyVisible = not okBody or shown ~= false
      end
      if bodyVisible then
        -- Self-heal Wilds' collision/entity registration if its old present
        -- update did not run on Gold.  This does NOT add it to world.npcs.
        if e.registeredInWorld ~= true and type(logic._attach) == "function" then
          pcall(logic._attach, logic, e)
        end
        out[#out + 1] = e
      end
    end
  end

  table.sort(out, function(a, b)
    return tonumber(a and a.py or 0) < tonumber(b and b.py or 0)
  end)
  Bridge.visible = #out
  return out
end

function Bridge.visibleEntities(world)
  return visibleWilds(world)
end

local function worldScale(world)
  if world and type(world.zoomScale) == "function" then
    local ok, s = pcall(world.zoomScale, world)
    if ok and tonumber(s) and tonumber(s) > 0 then return tonumber(s) end
  end
  return 1
end

local function drawOne(e, ox, oy, scale)
  if type(e.draw) ~= "function" then return false, "entity has no draw()" end

  -- The voxel/Stadium compatibility layer can intentionally suppress the 2D
  -- body when it believes a 3D card owns it.  During the fallback pass we are
  -- explicitly proving that no voxel frame owns this entity, so clear only the
  -- renderer-ownership flags for the duration of this draw and restore them
  -- even on error.
  local oldWorldRenderer = e.worldRenderer
  local oldPokemonRenderer = e.pokemonRenderer
  local oldWaterVoxelActive = e.waterVoxelActive
  local oldClaimed = e._stadiumWorldClaimed

  e.worldRenderer = nil
  e.pokemonRenderer = nil
  e.waterVoxelActive = false
  e._stadiumWorldClaimed = false

  local ok, err = pcall(e.draw, e, ox, oy, scale)

  e.worldRenderer = oldWorldRenderer
  e.pokemonRenderer = oldPokemonRenderer
  e.waterVoxelActive = oldWaterVoxelActive
  e._stadiumWorldClaimed = oldClaimed

  if not ok then return false, tostring(err) end
  return true
end

function Bridge.drawFallback(world)
  Bridge.frames = Bridge.frames + 1
  if not (world and world.camera) then
    Bridge.drawn = 0
    return 0, "Gold world/camera not ready"
  end

  local list = visibleWilds(world)
  if #list == 0 then
    Bridge.drawn = 0
    Bridge.lastError = nil
    return 0
  end

  local scale = worldScale(world)
  local cam = world.camera
  local ox = math.floor(-(tonumber(cam.x) or 0) * scale)
  local oy = math.floor(-(tonumber(cam.y) or 0) * scale)
  local drawn, firstErr = 0, nil

  local G = love and love.graphics
  if G then
    G.push("all")
    G.origin()
    G.setColor(1, 1, 1, 1)
  end
  for _, e in ipairs(list) do
    local ok, err = drawOne(e, ox, oy, scale)
    if ok then
      drawn = drawn + 1
    else
      Bridge.drawErrors = Bridge.drawErrors + 1
      firstErr = firstErr or err
    end
  end
  if G then G.pop() end

  Bridge.drawn = drawn
  Bridge.lastError = firstErr
  return drawn, firstErr
end

function Bridge.install()
  Bridge.installed = true
  return true
end

function Bridge.ensure()
  if not Bridge.installed then return Bridge.install() end
  return true
end

function Bridge.status()
  return {
    installed = Bridge.installed,
    frames = Bridge.frames,
    visible = Bridge.visible,
    drawn = Bridge.drawn,
    drawErrors = Bridge.drawErrors,
    initAttempts = Bridge.initAttempts,
    initSuccesses = Bridge.initSuccesses,
    lastInitError = Bridge.lastInitError,
    lastError = Bridge.lastError,
  }
end

return Bridge
