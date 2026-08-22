local calls = { requests = {}, horizons = {} }
local preferBody = true
local horizonReady = true
local fullPair = nil

local current = { id = "CURRENT", def = { width = 10, height = 10 } }
local cold = { id = "COLD", def = { width = 8, height = 8 } }
local warm = { id = "WARM", def = { width = 7, height = 7 } }
local foreign = { id = "FOREIGN", def = { width = 6, height = 6 } }

local compactPlan = {
  state = {
    map = current,
    neighbors = { { map = warm, ox = 320, oy = 0 } },
  },
  meshes = { "warm-body" },
  waters = { "warm-water" },
  maps = { CURRENT = true, WARM = true },
}

local VoxelScene = {
  prefetch = function()
    -- The public tuple remains sparse/source-indexed for old callers. The
    -- battle must consume the compact fifth plan instead.
    return "current-body", { [2] = "warm-body" }, "current-water",
           { [2] = "warm-water" }, compactPlan
  end,
}

local HorizonWall = {
  preferBody = function() return preferBody end,
  meshes = function(state)
    calls.horizons[#calls.horizons + 1] = state
    return { { mesh = "rim", texture = "trees", kind = "wall",
               ox = 0, oy = 0 } }, horizonReady
  end,
}

local ChunkMesher = {
  setLive = function() end,
  request = function(map, bodyOnly, masks, urgent)
    calls.requests[#calls.requests + 1] = {
      map = map, bodyOnly = bodyOnly, masks = masks, urgent = urgent,
    }
  end,
  pair = function(map, bodyOnly)
    if map == foreign and not bodyOnly and fullPair then
      return fullPair[1], fullPair[2]
    end
    return nil, nil
  end,
}

local modules = {
  VoxelScene = VoxelScene,
  HorizonWall = HorizonWall,
  ChunkMesher = ChunkMesher,
  TerrainAtlas = { setLive = function() end },
}

local V = {}
function V.require(name)
  modules[name] = modules[name] or {}
  return modules[name]
end

package.preload["src.render.PaletteFX"] = function() return {} end
package.preload["src.world.Map"] = function()
  return { isOutdoor = function() return false end }
end

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected "
          .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local BattleScene = assert(loadfile("lib/BattleScene.lua"))(V)
local state = {
  map = current,
  neighbors = {
    { map = cold, ox = -256, oy = 0 },
    { map = warm, ox = 320, oy = 0 },
  },
}

local stage = BattleScene._prefetchArena(state, current)
eq(stage.terrain, "current-body", "home battle keeps current terrain")
eq(#stage.neighbors, 1, "cold neighbour is absent from the battle union")
eq(stage.neighbors[1].map, warm, "ready neighbour keeps its compact map")
eq(stage.meshes[1], "warm-body", "compact mesh stays paired with its map")
eq(stage.waters[1], "warm-water", "compact water stays paired with its map")
eq(stage.horizon[1].mesh, "rim", "closed horizon reaches the MAP battle")
eq(calls.horizons[#calls.horizons], compactPlan.state,
   "horizon is built around exactly the drawable union")

-- A VoxelScene FULL-ring fallback already has no semantic curtain. Battles
-- must consume that exact atomic plan without probing the terminal Horizon
-- key again, while still requiring every source neighbour.
compactPlan.horizonFallback = true
compactPlan.state.neighbors = {
  { map = cold, ox = -256, oy = 0 },
  { map = warm, ox = 320, oy = 0 },
}
compactPlan.meshes = { "cold-body", "warm-body" }
compactPlan.waters = { "cold-water", "warm-water" }
compactPlan.maps.COLD = true
local beforeFallbackHorizons = #calls.horizons
horizonReady = false
stage = BattleScene._prefetchArena(state, current)
eq(#calls.horizons, beforeFallbackHorizons,
   "FULL-ring battle retried the failed semantic horizon")
eq(#stage.neighbors, 2,
   "FULL-ring battle dropped an atomically required neighbour")
eq(#stage.horizon, 0,
   "FULL-ring battle invented a semantic horizon")
compactPlan.horizonFallback = nil
compactPlan.state.neighbors = { { map = warm, ox = 320, oy = 0 } }
compactPlan.meshes = { "warm-body" }
compactPlan.waters = { "warm-water" }
compactPlan.maps.COLD = nil

horizonReady = false
eq(BattleScene._prefetchArena(state, current), nil,
   "battle waits rather than drawing a failed horizon")
horizonReady = true

-- The non-semantic/full-ring path may only release atomically. Its current
-- mesh is masked under both connections, so one compact neighbour is a hole.
preferBody = false
eq(BattleScene._prefetchArena(state, current), nil,
   "full-ring battle waits for every connected body")
preferBody = true

-- A foreign authored arena cannot use the overworld's connection plan. It
-- waits for its closed FULL ring and never falls back to a naked body mesh.
calls.requests = {}
eq(BattleScene._prefetchArena(state, foreign), nil,
   "foreign arena waits while its full mesh is cold")
eq(calls.requests[1].map, foreign, "foreign host itself is requested")
eq(calls.requests[1].bodyOnly, false,
   "foreign arena requests only the closed full variant")
eq(calls.requests[1].urgent, true, "foreign arena stays transition-urgent")

fullPair = { "foreign-full", "foreign-water" }
stage = BattleScene._prefetchArena(state, foreign)
eq(stage.terrain, "foreign-full", "foreign arena releases its full ring")
eq(#stage.neighbors, 0, "foreign arena invents no map connections")
eq(#stage.horizon, 0, "foreign full ring needs no semantic curtain")

print("battle scene horizon: ok")
