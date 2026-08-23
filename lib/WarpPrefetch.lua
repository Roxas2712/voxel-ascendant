-- Warm a semantic destination while the engine's existing warp fade covers
-- the overworld.  This module never changes the warp, map, transition or
-- renderer state: it only puts the already-known destination into
-- ChunkMesher's generation-checked in-memory queue.  Any failure therefore
-- falls back to the exact Game/KASC path that was going to run anyway.

local V = ...

local ChunkMesher = V.require("ChunkMesher")
local HorizonWall = V.require("HorizonWall")
local Voxel = V.require("VoxelState")

local WarpPrefetch = {}

local MARKER = "__voxelAscendantWarpPrefetchV1"
local OWNER = "VOXEL_ASCENDANT"

local function enabled()
  if type(Voxel.active) == "function" then
    local ok, value = pcall(Voxel.active)
    if ok and value then return true end
  end
  local setting = ChunkMesher.preloadSetting
  if setting and type(setting.get) == "function" then
    local ok, value = pcall(setting.get, setting)
    if ok and value then return true end
  end
  return false
end

local function arm(state, game, mapId)
  -- Loading Map objects may allocate renderer state.  Keep that work out of
  -- startWarpTo itself: the wrapper records only two references and returns
  -- immediately to the engine's unmodified transition implementation.
  state.pending = { game = game, mapId = mapId }
  state.warmingMap = nil
end

function WarpPrefetch.install(game)
  local ow = game and game.overworld
  if type(ow) ~= "table" or type(ow.startWarpTo) ~= "function" then
    return false
  end

  local existing = rawget(ow, MARKER)
  if existing ~= nil then
    -- Hot reload reuses the live OverworldState.  Adopt our existing wrapper
    -- instead of stacking another one; an inconsistent/foreign marker is
    -- deliberately left alone.
    if type(existing) ~= "table" or existing.owner ~= OWNER
       or ow.startWarpTo ~= existing.wrapper then
      return false
    end
    existing.arm = arm
    existing.game = game
    return true
  end

  local state = {
    owner = OWNER,
    game = game,
    original = ow.startWarpTo,
    arm = arm,
  }
  state.wrapper = function(self, mapId, ...)
    state.arm(state, state.game, mapId)
    -- Tail return preserves every original return value and every argument,
    -- including optional Fly/onDone/options records.
    return state.original(self, mapId, ...)
  end
  rawset(ow, MARKER, state)
  ow.startWarpTo = state.wrapper
  return true
end

function WarpPrefetch.update(game, covered)
  local ow = game and game.overworld
  if type(ow) ~= "table" then return false end
  local state = rawget(ow, MARKER)
  if type(state) ~= "table" or state.owner ~= OWNER
     or ow.startWarpTo ~= state.wrapper then
    return false
  end
  if not covered then
    state.warmingMap = nil
  elseif state.warmingMap and type(ChunkMesher.ready) == "function" then
    local readyOK, ready = pcall(ChunkMesher.ready, state.warmingMap, true)
    if readyOK and ready then state.warmingMap = nil end
  end
  local pending = state.pending
  if not pending or not covered then return state.warmingMap ~= nil end
  state.pending = nil
  if not enabled() or type(pending.mapId) ~= "string" then return false end

  local ok, map = pcall(function()
    local loader = require("src.world.MapLoader")
    return loader.load(pending.game and pending.game.data, pending.mapId)
  end)
  if not ok or not map then return false end

  local bodyOK, body = pcall(HorizonWall.preferBody, map)
  if not bodyOK or not body then return false end
  -- Urgent + body-only is the exact atomic current-map request VoxelScene
  -- would issue after the midpoint.  Starting it here lets the fade frames do
  -- useful bounded work and makes that later request an idempotent cache hit.
  local requestOK = pcall(ChunkMesher.request, map, true, nil, true)
  if requestOK then state.warmingMap = map end
  return requestOK
end

WarpPrefetch.MARKER = MARKER

return WarpPrefetch
