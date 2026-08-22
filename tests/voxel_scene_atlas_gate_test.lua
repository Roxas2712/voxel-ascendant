-- A connected body may finish before its RED++ animation atlas. It must stay
-- behind the closed semantic horizon until the next bounded preparation slot,
-- never perform that cold work from its first visible draw.

local cache, warm = {}, {}
local prepareCalls = {}
local V = { mod = { id = "VOXEL_ASCENDANT" } }
function V.require(name)
  if cache[name] == nil then cache[name] = {} end
  return cache[name]
end
package.preload["src.render.PaletteFX"] = function()
  return { effectiveColors = function(c) return c end,
           usesGbcPack = function() return true end }
end
package.preload["src.world.Map"] = function() return {} end

cache.VoxelState = { ready = false, angle = 0 }
cache.TerrainAtlas = {
  setLive = function() end,
  prepared = function(map) return warm[map.id] == true end,
  prepare = function(map)
    prepareCalls[#prepareCalls + 1] = map.id
    warm[map.id] = true
    return true
  end,
}
cache.GlassMask = {
  prepared = function() return true end,
  prepare = function() return true end,
}
cache.ChunkMesher = {
  setLive = function() end,
  request = function() end,
  pair = function(map) return map.id .. "-mesh", nil end,
  auxReady = function() return true end,
}
cache.HorizonWall = {
  preferBody = function() return true end,
  hasSky = function() return false end,
  meshes = function() return {}, true end,
}

local Scene = assert(loadfile("lib/VoxelScene.lua"))(V)
local current = { id = "CURRENT", def = { width = 2, height = 2 } }
local neighbour = { id = "NEIGHBOUR", def = { width = 2, height = 2 } }
local state = {
  map = current,
  neighbors = { { map = neighbour, ox = 64, oy = 0 } },
}

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected "
          .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local _, nbMesh, _, _, plan = Scene.prefetch(state)
eq(prepareCalls[1], "CURRENT", "current map was not prepared first")
eq(#prepareCalls, 1, "one prefetch prepared more than one cold atlas")
eq(nbMesh[1], "NEIGHBOUR-mesh", "public ready-mesh tuple was changed")
eq(#plan.state.neighbors, 0,
   "atlas-cold neighbour escaped the closed horizon")
eq(cache.VoxelState.ready, true,
   "prepared current map did not release its complete smaller scene")

_, nbMesh, _, _, plan = Scene.prefetch(state)
eq(prepareCalls[2], "NEIGHBOUR", "next slot did not prepare the neighbour")
eq(#prepareCalls, 2, "second prefetch prepared more than one cold atlas")
eq(#plan.state.neighbors, 1, "prepared neighbour did not join draw plan")
eq(plan.state.neighbors[1].map, neighbour,
   "wrong neighbour joined prepared plan")

print("voxel scene cold-atlas neighbour gate: ok")
