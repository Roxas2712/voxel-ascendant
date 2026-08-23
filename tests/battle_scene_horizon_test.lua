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

local seenMegaSource
local BattlePics = {
  inkBounds = function(canvas, source)
    seenMegaSource = source
    if type(source) == "string" and source:find("steelix", 1, true) then
      return 0, 0, 95, 95
    end
    return 3, 7, 91, 88
  end,
}

local modules = {
  VoxelScene = VoxelScene,
  HorizonWall = HorizonWall,
  ChunkMesher = ChunkMesher,
  BattleBillboard = { FULL_W = 16, FULL_PIC = 56 },
  TerrainAtlas = { setLive = function() end },
  BattlePics = BattlePics,
  VoxelBattleStage = {
    presentationScale = function() return 1 end,
    presentationPosition = function(arena, side, groundY)
      local p = arena[side]
      return p[1], groundY or 0, p[2]
    end,
  },
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
eq(BattleScene.textureBaseline({ ay = 96, canvas = {} }), 96,
  "ordinary battle texture baseline changed")
eq(BattleScene.textureBaseline({
  ay = 96, canvas = {}, inkIdentity = "RATTATA",
}), 89, "ordinary compact alpha bottom did not reach the ground")
eq(BattleScene.textureBaseline({
  ay = 96, canvas = {}, kantoAscendantMegaSupersampled = true,
  kantoAscendantMegaSource = "assets/mega/mega_charizard_x_front.png",
}), 89, "Mega alpha bottom did not replace transparent-frame baseline")
eq(seenMegaSource, "assets/mega/mega_charizard_x_front.png",
  "Mega baseline cache did not receive content identity")
eq(BattleScene.speciesScale({ trainer = true, heightIn = 346 }), 1,
  "trainer art inherited Pokemon height scaling")
eq(BattleScene.speciesScale({ heightIn = 12 }),
   BattleScene.SPECIES_SCALE_MIN,
   "small Pokemon did not receive the readable minimum")
eq(BattleScene.speciesScale({ heightIn = 346 }),
   BattleScene.SPECIES_SCALE_MAX,
   "very large Pokemon exceeded the indoor-safe maximum")
local charizardScale = BattleScene.speciesScale({ heightIn = 67 })
local rattataScale = BattleScene.speciesScale({ heightIn = 12 })
if not (charizardScale > rattataScale * 1.7) then
  error("canonical species height does not visibly separate Charizard/Rattata")
end
eq(BattleScene.speciesScale({ heightIn = 0 }), 1,
  "malformed Pokemon height did not fail neutral")
local retinaMetrics = BattleScene.presentationMetrics({
  ay = 96, heightIn = 67,
  canvas = { getDimensions = function() return 320, 288 end },
  kantoAscendantMegaSupersampled = true,
  kantoAscendantMegaSource = "assets/mega/mega_charizard_x_front.png",
}, 1)
eq(retinaMetrics.canvasWidth, 320,
  "companion high-DPI canvas width was collapsed to the GB frame")
eq(retinaMetrics.canvasHeight, 288,
  "companion high-DPI canvas height was collapsed to the GB frame")
eq(retinaMetrics.baseline, 89,
  "companion high-DPI card lost its visible foot row")
if not (retinaMetrics.combinedScale > 1
        and retinaMetrics.worldInkHeight > 0) then
  error("Mega presentation metrics lost canonical physical scale")
end
eq(retinaMetrics.densityScale,
   (56 / retinaMetrics.inkHeight) * BattleScene.MEGA_SILHOUETTE_BONUS,
  "Mega silhouette did not replace nominal-card density")
eq(retinaMetrics.densityPolicy, "silhouette",
  "ordinary Mega silhouette used the wrong density policy")
if not (retinaMetrics.worldInkHeight > 23
        and retinaMetrics.worldInkHeight < 24) then
  error("Mega Charizard did not remain slightly larger than normal Charizard")
end
local steelixMetrics = BattleScene.presentationMetrics({
  ay = 96, heightIn = 362,
  canvas = { getDimensions = function() return 160, 144 end },
  kantoAscendantMegaSupersampled = true,
  kantoAscendantMegaSource = "assets/mega/mega_steelix_front.png",
}, 1)
eq(steelixMetrics.densityScale, 56 / 96,
  "already-large Mega Steelix was enlarged again")
eq(steelixMetrics.densityPolicy, "large-preserved",
  "Mega Steelix did not use the protected large-footprint path")
local spreadLayout = BattleScene.presentationLayout({
  player = { 0, 48 }, enemy = { 0, 0 },
}, 0, {
  player = {
    ay = 96, heightIn = 67, canvas = {},
    kantoAscendantMegaSupersampled = true,
    kantoAscendantMegaSource = "assets/mega/mega_charizard_x_front.png",
  },
  enemy = { ay = 96, heightIn = 346, canvas = {}, inkIdentity = "ONIX" },
})
if not (spreadLayout.spread and spreadLayout.spread > 0
        and spreadLayout.player[1] < 0
        and spreadLayout.enemy[1] == 0) then
  error("large battle pair did not separate on the HUD-safe player side")
end
local compactLayout = BattleScene.presentationLayout({
  player = { 0, 48 }, enemy = { 0, 0 },
}, 0, {
  player = { ay = 96, heightIn = 12, canvas = {}, inkIdentity = "RATTATA" },
  enemy = { ay = 96, heightIn = 12, canvas = {}, inkIdentity = "RATTATA" },
})
eq(compactLayout.spread, nil,
  "ordinary battle pair was moved by the large-pair guard")
local indoorOnix = BattleScene.presentationMetrics({
  heightIn = 346, canvas = {}, inkIdentity = "ONIX",
}, 2.1)
eq(indoorOnix.combinedScale, BattleScene.PRESENTATION_SCALE_MAX,
  "large indoor Pokemon exceeded the reviewed actor envelope")
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
