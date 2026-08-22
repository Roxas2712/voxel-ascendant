local cache = {}
local preferBody = true
local pairByKey = {}
local auxById = { CURRENT = true }
local requests, horizonCalls, liveCalls = {}, {}, {}
local failExpanded = false

local V = { mod = { id = "VOXEL_ASCENDANT" } }

function V.require(name)
  if cache[name] == nil then cache[name] = {} end
  return cache[name]
end

package.preload["src.render.PaletteFX"] = function()
  return {
    effectiveColors = function(colors) return colors end,
    usesGbcPack = function() return false end,
  }
end
package.preload["src.world.Map"] = function() return {} end

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected "
          .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function truthy(value, message)
  if not value then error(message or "expected truthy value", 2) end
end

local function key(map, bodyOnly)
  return map.id .. (bodyOnly and ":body" or ":full")
end

cache.VoxelState = { ready = false, angle = 0 }
cache.TerrainAtlas = {
  setLive = function(live) liveCalls[#liveCalls + 1] = live end,
}
cache.ChunkMesher = {
  setLive = function(live) liveCalls[#liveCalls + 1] = live end,
  request = function(map, bodyOnly, masks, urgent)
    requests[#requests + 1] = {
      map = map, bodyOnly = bodyOnly, masks = masks, urgent = urgent,
    }
  end,
  pair = function(map, bodyOnly)
    local pair = pairByKey[key(map, bodyOnly)]
    if not pair then return nil, nil end
    return pair[1], pair[2]
  end,
  auxReady = function(map) return auxById[map.id] == true end,
}
cache.HorizonWall = {
  preferBody = function() return preferBody end,
  meshes = function(state)
    local ids = {}
    for _, nb in ipairs(state.neighbors or {}) do
      ids[#ids + 1] = nb.map.id
    end
    horizonCalls[#horizonCalls + 1] = ids
    if failExpanded and #ids > 0 then return {}, false end
    return { "closed-horizon" }, true
  end,
  hasSky = function() return true end,
}

local Scene = assert(loadfile("lib/VoxelScene.lua"))(V)

local current = { id = "CURRENT", def = { width = 10, height = 10 } }
local cold = { id = "COLD", def = { width = 8, height = 8 } }
local warm = { id = "WARM", def = { width = 7, height = 7 } }
local state = {
  map = current,
  neighbors = {
    { map = cold, ox = -256, oy = 0 },
    { map = warm, ox = 320, oy = 0 },
  },
}

pairByKey["CURRENT:body"] = { "current-body", "current-water" }
pairByKey["WARM:body"] = { "warm-body", "warm-water" }

-- A ready current map plus its closed horizon releases immediately. A
-- neighbour whose terrain has landed but whose grass/flowers/figures have not
-- stays behind that horizon, without losing its source index in the public
-- four-value BattleScene tuple.
local terrain, nbMesh, water, nbWater, plan = Scene.prefetch(state)
eq(terrain, "current-body", "semantic scene uses current body")
eq(water, "current-water", "current water stays paired with terrain")
eq(nbMesh[1], nil, "cold first neighbour remains absent")
eq(nbMesh[2], "warm-body", "ready second neighbour keeps source index")
eq(nbWater[2], "warm-water", "sparse battle water remains index-aligned")
eq(cache.VoxelState.ready, true,
   "current body plus filtered horizon is a complete first scene")
eq(Scene.readyForReveal(state), true,
   "a complete current scene releases the product warp fade")
eq(Scene.readyForReveal({ map = {
     id = current.id, def = current.def,
   } }), false,
   "a same-id destination cannot inherit stale source-map readiness")
eq(#plan.state.neighbors, 0,
   "terrain-ready neighbour escaped before its aux bundle")
eq(#horizonCalls[#horizonCalls], 0,
   "current-only horizon opened for an aux-cold neighbour")
eq(requests[1].urgent, true, "current map keeps urgent build priority")
eq(requests[2].urgent, false,
   "semantic neighbour continues on ordinary frame budget")
eq(requests[3].urgent, false,
   "every semantic neighbour is non-blocking")
truthy(liveCalls[1].CURRENT and liveCalls[1].COLD and liveCalls[1].WARM,
       "cold neighbours stay live while building")

-- Landing the complete aux bundle promotes the already cached body and the
-- expanded horizon together, without changing the public sparse tuple.
auxById.WARM = true
terrain, nbMesh, water, nbWater, plan = Scene.prefetch(state)
eq(#plan.state.neighbors, 1, "aux-complete neighbour did not enter union")
eq(plan.state.neighbors[1].map, warm, "filtered union keeps ready neighbour")
eq(plan.meshes[1], "warm-body", "draw plan compacts mesh with its map")
eq(plan.waters[1], "warm-water", "draw plan compacts paired water")
eq(plan.maps.CURRENT, true, "current map is drawable")
eq(plan.maps.COLD, nil, "cold ghost map is not drawable")
eq(plan.maps.WARM, true, "warm ghost map is drawable")
eq(#horizonCalls[#horizonCalls], 1, "horizon sees one ready neighbour")
eq(horizonCalls[#horizonCalls][1], "WARM",
   "horizon never opens the cold seam")

-- A newly landed body alone remains withheld; its expanded horizon only
-- becomes drawable when its aux bundle lands too.
pairByKey["COLD:body"] = { "cold-body", nil }
terrain, nbMesh, water, nbWater, plan = Scene.prefetch(state)
eq(#plan.state.neighbors, 1,
   "new terrain body entered union before aux completion")
auxById.COLD = true
terrain, nbMesh, water, nbWater, plan = Scene.prefetch(state)
eq(#plan.state.neighbors, 2, "landed neighbour expands drawable union")
eq(plan.state.neighbors[1].map, cold, "source order remains deterministic")
eq(plan.meshes[1], "cold-body", "new body lands with expanded union")
eq(#horizonCalls[#horizonCalls], 2,
   "expanded horizon closes around both drawable neighbours")

-- If expansion cannot be made, do not draw a body over the previous seam.
-- Rebuild and retain the smaller current-only closure instead; the sparse
-- BattleScene return still exposes every ready source-indexed body.
local beforeFailedExpansion = #horizonCalls
failExpanded = true
terrain, nbMesh, water, nbWater, plan = Scene.prefetch(state)
eq(nbMesh[1], "cold-body", "BattleScene tuple is unchanged by horizon failure")
eq(nbMesh[2], "warm-body", "all ready battle bodies remain available")
eq(#plan.state.neighbors, 0,
   "failed horizon expansion withholds connected bodies from overworld")
local sawClosedFallback = false
for i = beforeFailedExpansion + 1, #horizonCalls do
  if #horizonCalls[i] == 0 then sawClosedFallback = true end
end
truthy(sawClosedFallback,
       "failure did not retain a closed current-only horizon")
eq(cache.VoxelState.ready, true,
   "safe smaller voxel scene remains drawable after expansion failure")

-- No current terrain means the ordinary complete 2D world remains in charge.
failExpanded = false
pairByKey["CURRENT:body"] = nil
terrain, nbMesh, water, nbWater, plan = Scene.prefetch(state)
eq(terrain, nil, "missing current body is reported")
eq(cache.VoxelState.ready, false, "missing current body preserves 2D fallback")
eq(Scene.readyForReveal(state), false,
   "an incomplete current scene keeps the product midpoint closed")

-- Without a semantic closure, the full-ring/masked path must still wait for
-- every connection body. It also preserves the historical urgent requests.
preferBody = false
pairByKey["CURRENT:full"] = { "current-full", "full-water" }
pairByKey["COLD:body"] = nil
auxById.COLD = nil
requests = {}
terrain, nbMesh, water, nbWater, plan = Scene.prefetch(state)
eq(terrain, "current-full", "legacy path uses full current mesh")
eq(cache.VoxelState.ready, false,
   "masked full ring waits for every connected body")
eq(requests[2].urgent, true, "atomic neighbour remains urgent")
eq(requests[3].urgent, true, "all atomic neighbours remain urgent")

pairByKey["COLD:body"] = { "cold-body", nil }
auxById.COLD = true
terrain, nbMesh, water, nbWater, plan = Scene.prefetch(state)
eq(cache.VoxelState.ready, true,
   "legacy path releases when the complete neighbourhood exists")
eq(Scene.readyForReveal(state), true,
   "the complete legacy scene releases the product warp fade")
eq(#plan.state.neighbors, 2, "complete legacy draw plan includes both bodies")

print("voxel scene progressive release: ok")
