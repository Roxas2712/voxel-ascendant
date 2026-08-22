local cache = {}
local pairById, fullPairById, auxById = {}, {}, {}
local requests, horizonCalls = {}, {}
local failHorizon = false

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

cache.VoxelState = { ready = false, angle = 0 }
cache.TerrainAtlas = {
  prepared = function() return true end,
  prepare = function() error("prepared atlas was rebuilt", 0) end,
  setLive = function() end,
}
cache.ChunkMesher = {
  setLive = function() end,
  request = function(map, bodyOnly, masks, urgent, priority)
    requests[#requests + 1] = {
      id = map.id, bodyOnly = bodyOnly, masks = masks, urgent = urgent,
      priority = priority and true or false,
      priorityRank = tonumber(priority) or (priority and 2 or 0),
    }
  end,
  pair = function(map, bodyOnly)
    local pair
    if bodyOnly == false then pair = fullPairById[map.id]
    else pair = pairById[map.id] end
    return pair and pair[1], pair and pair[2]
  end,
  auxReady = function(map) return auxById[map.id] == true end,
}
cache.HorizonWall = {
  preferBody = function() return true end,
  hasSky = function() return true end,
  meshes = function(state)
    local call = { root = state.map.id, ids = {} }
    for _, nb in ipairs(state.neighbors or {}) do
      call.ids[#call.ids + 1] = nb.map.id
    end
    horizonCalls[#horizonCalls + 1] = call
    if failHorizon then return {}, false, true end
    return { "ready-horizon" }, true
  end,
}

local Scene = assert(loadfile("lib/VoxelScene.lua"))(V)

local function map(id, width, height, connections)
  return {
    id = id,
    def = { id = id, width = width, height = height,
            tileset = "OVERWORLD", outdoor = true,
            connections = connections or {} },
  }
end

local r4 = map("ROUTE_4", 45, 9, {
  south = { map = "ROUTE_3", offset = -25 },
  east = { map = "CERULEAN_CITY", offset = -4 },
})
local r3 = map("ROUTE_3", 35, 9, {
  north = { map = "ROUTE_4", offset = 25 },
  west = { map = "PEWTER_CITY", offset = -4 },
})
local cerulean = map("CERULEAN_CITY", 20, 18, {
  west = { map = "ROUTE_4", offset = 4 },
})
local route5 = map("ROUTE_5", 10, 18)
local pewter = map("PEWTER_CITY", 20, 18)

for _, m in ipairs({ r4, r3, cerulean, route5, pewter }) do
  pairById[m.id] = { m.id .. "-body", m.id .. "-water" }
  auxById[m.id] = true
end

local route4State = {
  map = r4,
  player = { cellX = 12, cellY = 16, facing = "down" },
  neighbors = {
    { map = r3, ox = -800, oy = 288 },
    { map = cerulean, ox = 1440, oy = -128 },
    { map = route5, ox = 1600, oy = 448 },
  },
}

local seamIndex, seamDirection = Scene._seamCandidate(route4State)
eq(seamIndex, 1, "Route 4 ledge did not select Route 3")
eq(seamDirection, "south", "Route 4 selected the wrong edge")
route4State.player.cellX = 70
eq(Scene._seamCandidate(route4State), nil,
   "non-overlapping Route 4 south cells stole Route 3 priority")
route4State.player.cellX = 12

local _, _, _, _, plan = Scene.prefetch(route4State)
eq(cache.VoxelState.ready, true, "Route 4 complete scene fell back to 2D")
eq(plan.maps.ROUTE_3, true, "approached Route 3 was not first promotion")
eq(plan.maps.CERULEAN_CITY, nil,
   "more than one neighbour was promoted in the first stage")
eq(requests[2].id, "ROUTE_3", "Route 3 request order changed")
eq(requests[2].priority, true,
   "approached Route 3 did not receive queue priority")
eq(requests[2].priorityRank, 2,
   "approached Route 3 did not receive the highest background rank")
eq(requests[2].urgent, false,
   "seam priority incorrectly received the larger urgent budget")
eq(requests[3].id, "CERULEAN_CITY",
   "direct Route 4 neighbour request order changed")
eq(requests[3].priorityRank, 1,
   "unapproached direct connection lost background priority")
eq(requests[4].priorityRank, 0,
   "two-hop survey map incorrectly outranked a direct connection")

-- Grow the richer survey union one complete neighbour per call. The retained
-- handoff remains only Route4 + all of its direct neighbours.
Scene.prefetch(route4State)
_, _, _, _, plan = Scene.prefetch(route4State)
truthy(plan.maps.ROUTE_3 and plan.maps.CERULEAN_CITY and plan.maps.ROUTE_5,
       "complete Route 4 survey union did not finish staging")

-- Route 5 is three hops from a Route 3 root and deliberately absent. The rich
-- active union therefore cannot be projected, but the cached Route4 direct
-- handoff (Route4+Route3+Cerulean) can. It must be the FIRST horizon request
-- after re-root: a zero-neighbour request is the visible brown/2D fallback.
auxById.PEWTER_CITY = false
local route3State = {
  map = r3,
  player = { cellX = 40, cellY = 8, facing = "right" },
  neighbors = {
    { map = r4, ox = 800, oy = -288 },
    { map = pewter, ox = -640, oy = -128 },
    { map = cerulean, ox = 2240, oy = -416 },
  },
}
local before = #horizonCalls
_, _, _, _, plan = Scene.prefetch(route3State)
eq(cache.VoxelState.ready, true,
   "Route 4->3 re-root exposed the engine's flat/brown fallback")
eq(horizonCalls[before + 1].root, "ROUTE_3",
   "re-root horizon used the old root frame")
eq(#horizonCalls[before + 1].ids, 2,
   "re-root did not reuse the complete direct handoff union")
truthy(plan.maps.ROUTE_3 and plan.maps.ROUTE_4
       and plan.maps.CERULEAN_CITY,
       "re-root lost physical maps from the handoff")
eq(plan.maps.ROUTE_5, nil, "unavailable three-hop map leaked across re-root")
eq(plan.maps.PEWTER_CITY, nil,
   "aux-cold destination neighbour appeared before completion")
eq(plan.state.neighbors[1].ox, 800,
   "Route 4 body was not rebased into Route 3 coordinates")

-- Pallet -> Route 1 is the measured return-loop regression. Put Route 1
-- second in source order: proximity must still select and prioritize it.
local pallet = map("PALLET_TOWN", 10, 9, {
  north = { map = "ROUTE_1", offset = 0 },
  south = { map = "ROUTE_21", offset = 0 },
})
local route1 = map("ROUTE_1", 10, 18, {
  south = { map = "PALLET_TOWN", offset = 0 },
  north = { map = "VIRIDIAN_CITY", offset = -5 },
})
local route21 = map("ROUTE_21", 10, 36)
local viridian = map("VIRIDIAN_CITY", 20, 18)
for _, m in ipairs({ pallet, route1, route21, viridian }) do
  pairById[m.id] = { m.id .. "-body", m.id .. "-water" }
  auxById[m.id] = true
end
local palletState = {
  map = pallet,
  player = { cellX = 5, cellY = 1, facing = "up" },
  neighbors = {
    { map = route21, ox = 0, oy = 288 },
    { map = route1, ox = 0, oy = -576 },
  },
}
requests = {}
_, _, _, _, plan = Scene.prefetch(palletState)
eq(plan.maps.ROUTE_1, true, "Pallet approach did not stage Route 1 first")
eq(plan.maps.ROUTE_21, nil,
   "Pallet promoted two connection neighbours in one stage")
eq(requests[3].id, "ROUTE_1", "Route 1 source index changed")
eq(requests[3].priority, true, "Route 1 did not receive seam priority")
eq(requests[3].priorityRank, 2,
   "approached Route 1 did not outrank the other direct connection")
eq(requests[2].priorityRank, 1,
   "unapproached Route 21 direct connection lost its warmup rank")
Scene.prefetch(palletState) -- finish the direct handoff

local route1State = {
  map = route1,
  player = { cellX = 5, cellY = 35, facing = "down" },
  neighbors = {
    { map = pallet, ox = 0, oy = 576 },
    { map = viridian, ox = -160, oy = -576 },
    { map = route21, ox = 0, oy = 864 },
  },
}
before = #horizonCalls
_, _, _, _, plan = Scene.prefetch(route1State)
eq(cache.VoxelState.ready, true,
   "Pallet/Route 1 re-root returned to the flat fallback")
truthy(plan.maps.PALLET_TOWN and plan.maps.ROUTE_1 and plan.maps.ROUTE_21,
       "Pallet direct handoff was not retained on Route 1")
truthy(#horizonCalls[before + 1].ids > 0,
       "Pallet/Route 1 re-root built a current-only brown closure")

-- Route 8 -> Lavender is the wide three-map handoff used by the real seam
-- audit.  Both destination bodies can be complete before the crossing; the
-- first Lavender-rooted prefetch must therefore reuse Route8+Saffron+Lavender
-- at once, without a current-only/birdseye frame.
local route8 = map("ROUTE_8", 30, 9, {
  west = { map = "SAFFRON_CITY", offset = -4 },
  east = { map = "LAVENDER_TOWN", offset = 0 },
})
local saffron = map("SAFFRON_CITY", 20, 18, {
  east = { map = "ROUTE_8", offset = 4 },
})
local lavender = map("LAVENDER_TOWN", 10, 9, {
  west = { map = "ROUTE_8", offset = 0 },
})
for _, m in ipairs({ route8, saffron, lavender }) do
  pairById[m.id] = { m.id .. "-body", m.id .. "-water" }
  auxById[m.id] = true
end
local route8State = {
  map = route8,
  player = { cellX = 59, cellY = 8, facing = "right" },
  neighbors = {
    { map = saffron, ox = -640, oy = -128 },
    { map = lavender, ox = 960, oy = 0 },
  },
}
route8State.player.facing = "left"
local route8Index, route8Direction = Scene._seamCandidate(route8State)
eq(route8Index, 1,
   "Route 8 did not prioritize far Saffron in the walking direction")
eq(route8Direction, "west",
   "Route 8 selected the nearby connection behind the player")
route8State.player.facing = "right"
route8Index, route8Direction = Scene._seamCandidate(route8State)
eq(route8Index, 2, "Route 8 east approach did not select Lavender")
eq(route8Direction, "east", "Route 8 east approach chose the wrong edge")
Scene.prefetch(route8State)
Scene.prefetch(route8State)
_, _, _, _, plan = Scene.prefetch(route8State)
truthy(plan.maps.ROUTE_8 and plan.maps.SAFFRON_CITY
       and plan.maps.LAVENDER_TOWN,
       "Route 8 did not finish its three-map handoff")

local lavenderState = {
  map = lavender,
  player = { cellX = 0, cellY = 8, facing = "left" },
  neighbors = {
    { map = route8, ox = -960, oy = 0 },
    { map = saffron, ox = -1600, oy = -128 },
  },
}
before = #horizonCalls
_, _, _, _, plan = Scene.prefetch(lavenderState)
eq(cache.VoxelState.ready, true,
   "Route 8/Lavender re-root exposed the flat fallback")
eq(#horizonCalls[before + 1].ids, 2,
   "Lavender re-root failed to request the retained three-map horizon first")
truthy(plan.maps.ROUTE_8 and plan.maps.SAFFRON_CITY
       and plan.maps.LAVENDER_TOWN,
       "Lavender re-root lost a complete handoff body")
local status = Scene.planStatus()
eq(status.active.rootId, "LAVENDER_TOWN",
   "semantic status kept the pre-crossing root")
eq(table.concat(status.active.ids, ","),
   "LAVENDER_TOWN,ROUTE_8,SAFFRON_CITY",
   "semantic status did not expose the exact active union")
eq(status.handoff.rootId, "LAVENDER_TOWN",
   "handoff status did not re-root with Lavender")
truthy(type(status.liveKey) == "string"
       and status.liveKey:find("LAVENDER_TOWN", 1, true),
       "semantic status omitted the current live-set key")

-- A direct connection on the OPPOSITE edge must never become a hidden
-- requirement for the seam being crossed. The broad all-direct horizon may
-- already be cached, but if Lavender's visual bundle is cold while Saffron is
-- ready, semanticPlan must retain/promote the smaller Route8+Saffron answer
-- and re-root it without a current-only/2D frame. This adversarial case keeps
-- the performance diagnosis honest: a cold opposite flank is not, by itself,
-- proof that the three-map handoff caused a timeout.
local route8Pair = map("ROUTE_8_PAIR", 30, 9, {
  west = { map = "SAFFRON_PAIR", offset = -4 },
  east = { map = "LAVENDER_PAIR", offset = 0 },
})
local saffronPair = map("SAFFRON_PAIR", 20, 18, {
  east = { map = "ROUTE_8_PAIR", offset = 4 },
})
local lavenderPair = map("LAVENDER_PAIR", 10, 9, {
  west = { map = "ROUTE_8_PAIR", offset = 0 },
})
for _, m in ipairs({ route8Pair, saffronPair, lavenderPair }) do
  pairById[m.id] = { m.id .. "-body", m.id .. "-water" }
  auxById[m.id] = true
end
auxById.LAVENDER_PAIR = false
local route8PairState = {
  map = route8Pair,
  player = { cellX = 0, cellY = 9, facing = "left" },
  neighbors = {
    { map = saffronPair, ox = -640, oy = -128 },
    { map = lavenderPair, ox = 960, oy = 0 },
  },
}
_, _, _, _, plan = Scene.prefetch(route8PairState)
truthy(plan.maps.ROUTE_8_PAIR and plan.maps.SAFFRON_PAIR,
       "ready approached pair was not promoted while opposite edge was cold")
eq(plan.maps.LAVENDER_PAIR, nil,
   "cold opposite edge leaked into the active seam answer")

local saffronPairState = {
  map = saffronPair,
  player = { cellX = 39, cellY = 17, facing = "right" },
  neighbors = {
    { map = route8Pair, ox = 640, oy = 128 },
    { map = lavenderPair, ox = 1600, oy = 128 },
  },
}
before = #horizonCalls
_, _, _, _, plan = Scene.prefetch(saffronPairState)
eq(cache.VoxelState.ready, true,
   "cold opposite Route 8 flank blocked the ready Saffron pair re-root")
eq(#horizonCalls[before + 1].ids, 1,
   "Saffron pair re-root incorrectly required cold Lavender")
truthy(plan.maps.ROUTE_8_PAIR and plan.maps.SAFFRON_PAIR,
       "Saffron pair re-root lost the ready Route 8 body")
eq(plan.maps.LAVENDER_PAIR, nil,
   "Saffron pair re-root exposed the cold opposite connection")

-- Exercise the real Route-8 survey topology, not only its direct three-map
-- handoff.  A fully promoted Route-8 answer contains seven neighbours: the
-- Saffron/Lavender flanks and their five direct continuations.  Re-rooting at
-- either flank necessarily drops some of those old two-hop maps.  The first
-- destination prefetch must therefore reject the oversized active union and
-- immediately reuse Route8+Saffron+Lavender; it must not build a current-only
-- horizon just because a discarded old survey member has gone cold.
local route5Wide = map("ROUTE_5", 10, 18, {
  north = { map = "CERULEAN_CITY", offset = -5 },
  south = { map = "SAFFRON_CITY", offset = -5 },
})
local route6Wide = map("ROUTE_6", 10, 18, {
  north = { map = "SAFFRON_CITY", offset = -5 },
  south = { map = "VERMILION_CITY", offset = -5 },
})
local route7Wide = map("ROUTE_7", 10, 9, {
  east = { map = "SAFFRON_CITY", offset = -4 },
  west = { map = "CELADON_CITY", offset = -4 },
})
local route10Wide = map("ROUTE_10", 10, 36, {
  south = { map = "LAVENDER_TOWN", offset = 0 },
  west = { map = "ROUTE_9", offset = 0 },
})
local route12Wide = map("ROUTE_12", 10, 54, {
  north = { map = "LAVENDER_TOWN", offset = 0 },
  south = { map = "ROUTE_13", offset = -20 },
})
local route8Wide = map("ROUTE_8", 30, 9, {
  west = { map = "SAFFRON_CITY", offset = -4 },
  east = { map = "LAVENDER_TOWN", offset = 0 },
})
local saffronWide = map("SAFFRON_CITY", 20, 18, {
  east = { map = "ROUTE_8", offset = 4 },
  north = { map = "ROUTE_5", offset = 5 },
  south = { map = "ROUTE_6", offset = 5 },
  west = { map = "ROUTE_7", offset = 4 },
})
local lavenderWide = map("LAVENDER_TOWN", 10, 9, {
  north = { map = "ROUTE_10", offset = 0 },
  south = { map = "ROUTE_12", offset = 0 },
  west = { map = "ROUTE_8", offset = 0 },
})
local ceruleanWide = map("CERULEAN_CITY", 20, 18)
local vermilionWide = map("VERMILION_CITY", 20, 18)
local celadonWide = map("CELADON_CITY", 25, 18)
local route9Wide = map("ROUTE_9", 30, 9)
local route13Wide = map("ROUTE_13", 30, 9)
local wideMaps = {
  route8Wide, saffronWide, lavenderWide,
  route5Wide, route6Wide, route7Wide, route10Wide, route12Wide,
  ceruleanWide, vermilionWide, celadonWide, route9Wide, route13Wide,
}
for _, m in ipairs(wideMaps) do
  pairById[m.id] = { m.id .. "-body", m.id .. "-water" }
  auxById[m.id] = true
end

local function hasId(call, id)
  for _, value in ipairs(call and call.ids or {}) do
    if value == id then return true end
  end
  return false
end

local function wideRoute8State(facing)
  return {
    map = route8Wide,
    player = { cellX = facing == "left" and 0 or 59,
               cellY = facing == "left" and 9 or 8,
               facing = facing },
    neighbors = {
      { map = saffronWide, ox = -640, oy = -128 },
      { map = lavenderWide, ox = 960, oy = 0 },
      { map = route5Wide, ox = -480, oy = -704 },
      { map = route6Wide, ox = -480, oy = 448 },
      { map = route7Wide, ox = -960, oy = 0 },
      { map = route10Wide, ox = 960, oy = -1152 },
      { map = route12Wide, ox = 960, oy = 288 },
    },
  }
end

local function promoteWholeRoute8(scene, facing)
  local state = wideRoute8State(facing)
  local promoted
  for _ = 1, #state.neighbors do
    _, _, _, _, promoted = scene.prefetch(state)
  end
  for _, m in ipairs(wideMaps) do
    if m == route8Wide or m == saffronWide or m == lavenderWide
       or m == route5Wide or m == route6Wide or m == route7Wide
       or m == route10Wide or m == route12Wide then
      truthy(promoted.maps[m.id],
             "seven-neighbour Route 8 union did not promote " .. m.id)
    end
  end
  eq(#promoted.state.neighbors, 7,
     "Route 8 source plan was not the exact seven-neighbour union")
  local active = scene.planStatus().active
  eq(active.rootId, "ROUTE_8",
     "seven-neighbour source union lost its Route 8 root")
  eq(table.concat(active.ids, ","),
     "LAVENDER_TOWN,ROUTE_10,ROUTE_12,ROUTE_5,ROUTE_6,ROUTE_7,ROUTE_8,SAFFRON_CITY",
     "Route 8 active union did not contain its exact seven neighbours")
end

-- West: Route 10 belonged to Route 8's old eastern two-hop survey, but is not
-- in Saffron's two-hop state.  Make it cold after promotion to prove neither
-- its missing topology nor its stale readiness can poison the direct handoff.
local SaffronScene = assert(loadfile("lib/VoxelScene.lua"))(V)
promoteWholeRoute8(SaffronScene, "left")
auxById.ROUTE_10 = false
local saffronWideState = {
  map = saffronWide,
  player = { cellX = 39, cellY = 17, facing = "left" },
  neighbors = {
    { map = route8Wide, ox = 640, oy = 128 },
    { map = route5Wide, ox = 160, oy = -576 },
    { map = route6Wide, ox = 160, oy = 576 },
    { map = route7Wide, ox = -320, oy = 128 },
    { map = lavenderWide, ox = 1600, oy = 128 },
    { map = ceruleanWide, ox = 0, oy = -1152 },
    { map = vermilionWide, ox = 0, oy = 1152 },
    { map = celadonWide, ox = -1120, oy = 0 },
  },
}
before = #horizonCalls
cache.VoxelState.ready = false
_, _, _, _, plan = SaffronScene.prefetch(saffronWideState)
eq(cache.VoxelState.ready, true,
   "seven-neighbour Route 8/Saffron re-root exposed the flat fallback")
eq(horizonCalls[before + 1].root, "SAFFRON_CITY",
   "Saffron re-root's first horizon request kept the Route 8 root")
eq(#horizonCalls[before + 1].ids, 2,
   "Saffron re-root did not select the guaranteed direct handoff first")
truthy(hasId(horizonCalls[before + 1], "ROUTE_8")
       and hasId(horizonCalls[before + 1], "LAVENDER_TOWN"),
       "Saffron re-root's first horizon request lost a handoff member")
truthy(plan.maps.SAFFRON_CITY and plan.maps.ROUTE_8,
       "Saffron re-root did not keep destination and Route 8 visible")
truthy(plan.maps.LAVENDER_TOWN,
       "Saffron re-root did not retain the complete guaranteed handoff")
eq(plan.maps.ROUTE_10, nil,
   "discarded cold Route 10 leaked into the Saffron plan")
auxById.ROUTE_10 = true

-- East is an independent cold module state.  Here Route 5 is the discarded
-- western two-hop member; Lavender must still reveal its first 3D frame from
-- the same guaranteed three-map handoff.
local LavenderScene = assert(loadfile("lib/VoxelScene.lua"))(V)
promoteWholeRoute8(LavenderScene, "right")
auxById.ROUTE_5 = false
local lavenderWideState = {
  map = lavenderWide,
  player = { cellX = 0, cellY = 8, facing = "right" },
  neighbors = {
    { map = route8Wide, ox = -960, oy = 0 },
    { map = route10Wide, ox = 0, oy = -1152 },
    { map = route12Wide, ox = 0, oy = 288 },
    { map = saffronWide, ox = -1600, oy = -128 },
    { map = route9Wide, ox = -960, oy = -1152 },
    { map = route13Wide, ox = -640, oy = 2016 },
  },
}
before = #horizonCalls
cache.VoxelState.ready = false
_, _, _, _, plan = LavenderScene.prefetch(lavenderWideState)
eq(cache.VoxelState.ready, true,
   "seven-neighbour Route 8/Lavender re-root exposed the flat fallback")
eq(horizonCalls[before + 1].root, "LAVENDER_TOWN",
   "Lavender re-root's first horizon request kept the Route 8 root")
eq(#horizonCalls[before + 1].ids, 2,
   "Lavender re-root did not select the guaranteed direct handoff first")
truthy(hasId(horizonCalls[before + 1], "ROUTE_8")
       and hasId(horizonCalls[before + 1], "SAFFRON_CITY"),
       "Lavender re-root's first horizon request lost a handoff member")
truthy(plan.maps.LAVENDER_TOWN and plan.maps.ROUTE_8,
       "Lavender re-root did not keep destination and Route 8 visible")
truthy(plan.maps.SAFFRON_CITY,
       "Lavender re-root did not retain the complete guaranteed handoff")
eq(plan.maps.ROUTE_5, nil,
   "discarded cold Route 5 leaked into the Lavender plan")
auxById.ROUTE_5 = true

-- A terminal failure of the minimum current-only curtain must not expose its
-- body or any partial horizon. VoxelScene switches to the established masked
-- FULL-ring contract: while that slot is cold the complete 2D renderer stays
-- active; once the FULL current and every connected visual bundle are warm,
-- the fallback releases atomically and carries no semantic horizon.
local fallbackCurrent = map("FALLBACK_CURRENT", 10, 9, {
  east = { map = "FALLBACK_NEIGHBOR", offset = 0 },
})
local fallbackNeighbor = map("FALLBACK_NEIGHBOR", 10, 9, {
  west = { map = "FALLBACK_CURRENT", offset = 0 },
})
pairById.FALLBACK_CURRENT = { "fallback-body", "fallback-body-water" }
pairById.FALLBACK_NEIGHBOR = {
  "fallback-neighbor-body", "fallback-neighbor-water",
}
auxById.FALLBACK_CURRENT = true
auxById.FALLBACK_NEIGHBOR = true
local fallbackState = {
  map = fallbackCurrent,
  player = { cellX = 19, cellY = 8, facing = "right" },
  neighbors = {
    { map = fallbackNeighbor, ox = 320, oy = 0 },
  },
}

failHorizon = true
requests = {}
cache.VoxelState.ready = true
local FallbackScene = assert(loadfile("lib/VoxelScene.lua"))(V)
local fallbackTerrain, _, _, _, fallbackPlan =
  FallbackScene.prefetch(fallbackState)
eq(fallbackTerrain, nil,
   "failed semantic horizon exposed the body while FULL was cold")
eq(cache.VoxelState.ready, false,
   "failed semantic horizon did not retain the complete 2D renderer")
eq(fallbackPlan.horizonFallback, true,
   "terminal horizon failure missed the FULL-ring plan")

local sawFullCurrent, sawUrgentNeighbor = false, false
for _, request in ipairs(requests) do
  if request.id == "FALLBACK_CURRENT" and request.bodyOnly == false
     and request.urgent and request.masks and #request.masks == 1 then
    sawFullCurrent = true
  elseif request.id == "FALLBACK_NEIGHBOR" and request.bodyOnly == true
         and request.urgent then
    sawUrgentNeighbor = true
  end
end
truthy(sawFullCurrent,
       "horizon failure did not request the masked FULL current map")
truthy(sawUrgentNeighbor,
       "horizon failure lost the atomic neighbour promotion")

fullPairById.FALLBACK_CURRENT = {
  "fallback-full", "fallback-full-water",
}
fallbackTerrain, _, _, _, fallbackPlan =
  FallbackScene.prefetch(fallbackState)
eq(fallbackTerrain, "fallback-full",
   "warm horizon fallback did not use the FULL terrain slot")
eq(cache.VoxelState.ready, true,
   "complete FULL-ring fallback remained stuck in 2D")
eq(fallbackPlan.horizonFallback, true,
   "warm FULL-ring fallback lost its render marker")
eq(#fallbackPlan.state.neighbors, 1,
   "FULL-ring fallback released without every connected body")
eq(fallbackPlan.meshes[1], "fallback-neighbor-body",
   "FULL-ring fallback mismatched neighbour body and plan")
failHorizon = false

print("voxel scene seam handoff: ok")
