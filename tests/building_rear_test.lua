local V = {}

function V.require(name)
  if name == "BuildBudget" then
    return { tick = function() end, check = function() end }
  end
  error("unexpected dependency: " .. tostring(name))
end

local Buildings = assert(loadfile("lib/Buildings.lua"))(V)

local function expect(ok, message)
  if not ok then error(message, 2) end
end

-- Two deliberately misaligned facade bands (roofRows=17) containing the
-- source-tile sequence edge, wall, door, wall. One recessed pixel is enough
-- to reject the WHOLE door source tile. The repeated wall tile must supply a
-- real eight-pixel pattern, rather than one colour stretched over the back.
local W, H = 32, 32
local sp = { W = W, H = H, col = {}, ax = {}, ay = {}, inside = {} }
local recess = {}
for sy = 0, H - 1 do
  local sourceBand = math.floor(sy / 8)
  for sx = 0, W - 1 do
    local i = sy * W + sx
    local bx, lx = math.floor(sx / 8), sx % 8
    local sourceX = ({ 0, 1, 2, 1 })[bx + 1]
    sp.ax[i], sp.ay[i] = sourceX * 8 + lx, sourceBand * 8 + sy % 8
    sp.inside[i] = true
    if sourceX == 1 then
      sp.col[i] = (lx == 0 or lx == 7) and 2 or 1
    elseif sourceX == 2 then
      sp.col[i] = (lx >= 2 and lx <= 5) and 0 or 3
    else
      sp.col[i] = lx % 2
    end
  end
end
for sy = 17, H - 1 do recess[sy * W + 2 * 8 + 3] = true end

local rear = Buildings.rearMaterial(sp, recess, 17, H)
for sy = 17, H - 1 do
  for sx = 0, W - 1 do
    local donor = rear[sy * W + sx]
    expect(donor ~= nil, "visible rear texel has no material donor")
    expect(math.floor(sp.ax[donor] / 8) == 1,
           "door/edge source tile leaked onto the rear wall")
    expect(sp.ax[donor] % 8 == sx % 8,
           "rear wall lost the source tile's eight-pixel pattern")
    expect(math.floor(sp.ay[donor] / 8) == math.floor(sy / 8),
           "rear wall crossed facade bands")
  end
end

-- The same safe source course must turn ninety degrees across a flank at
-- exactly one source texel per world voxel.  It repeats at the 8px lattice,
-- never samples the dirty door tile, and keeps each vertical facade band.
local depth = 24
for sy = 17, H - 1 do
  for z = 0, depth - 1 do
    local donor = Buildings.sideMaterialAt(sp, rear, sy, z)
    expect(donor ~= nil, "visible side texel has no material donor")
    expect(math.floor(sp.ax[donor] / 8) == 1,
           "door/edge source tile leaked onto the side wall")
    expect(sp.ax[donor] % 8 == z % 8,
           "side wall stretched one texel instead of its eight-pixel course")
    expect(math.floor(sp.ay[donor] / 8) == math.floor(sy / 8),
           "side wall crossed facade bands")
  end
end

-- If every candidate tile is dirty, even an all-black course still receives
-- a deterministic non-recessed fallback and can never fall back to the door.
local black = { W = 8, H = 8, col = {}, ax = {}, ay = {}, inside = {} }
local dirty = { [0] = true }
for i = 0, 63 do
  black.col[i], black.ax[i], black.ay[i], black.inside[i] = 3, i % 8,
    math.floor(i / 8), true
end
local blackRear = Buildings.rearMaterial(black, dirty, 0, 8)
for i = 0, 63 do
  expect(blackRear[i] ~= nil, "black fallback course became empty")
end

-- A placement keeps the generated model local and shared. The old deep copy
-- produced thousands of corner tables per building and later GC spikes; the
-- mesher owns exact expansion/capability fallback now.
local localModel = {
  {
    { -1, 0, 0 }, { 1, 0, 0 }, { 1, 2, 1 }, { -1, 2, 1 },
    uv = { { 0, 0 }, { 1, 0 }, { 1, 1 }, { 0, 1 } }, shade = 0.8,
  },
}

-- The profile-owned compact-house correction changes Y only and records the
-- exact factor for the separately emitted rear door. It is atomic: malformed
-- input cannot leave a partially stretched shared model behind.
local scaledModel = {
  {
    { -1, 0, 0 }, { 1, 0, 0 }, { 1, 2, 1 }, { -1, 2, 1 },
    uv = { { 0, 0 }, { 1, 0 }, { 1, 1 }, { 0, 1 } }, shade = 0.8,
  },
}
local scaled, scaleOk = Buildings.applyHeightScale(scaledModel, 1.4)
expect(scaleOk and scaled == scaledModel and scaled.heightScale == 1.4,
       "valid compact-house height scale was rejected")
expect(scaled[1][1][1] == -1 and scaled[1][1][3] == 0
       and math.abs(scaled[1][3][2] - 2.8) < 1e-9,
       "compact-house correction changed X/Z or the wrong Y scale")
expect(scaled[1].uv[3][1] == 1 and scaled[1].shade == 0.8,
       "compact-house correction changed UV or shade")
local malformedModel = {
  {
    { 0, 0, 0 }, { 1, 0, 0 }, { 1, "bad", 1 }, { 0, 2, 1 },
    uv = {}, shade = 1,
  },
}
local _, malformedOk = Buildings.applyHeightScale(malformedModel, 1.4)
expect(not malformedOk and malformedModel[1][4][2] == 2
       and malformedModel.heightScale == nil,
       "malformed height scale did not fail closed atomically")
local S = {
  shapeAt = {}, tileAt = {}, skip = {}, ground = {}, objectQuads = {},
  buildingStamps = {},
}
local front = (4 + 64) * 4096 + (2 + 64)
S.shapeAt[front] = { flat = true, class = "ground" }
S.tileAt[front] = 9
local placementMap = {
  doorTiles = { [27] = true },
  cellTile = function(_, cx, cy)
    return cx == 1 and cy == 1 and 27 or 0
  end,
}
Buildings.stamp(S, placementMap, localModel, 2, 3, 1, 1, {})
expect(#S.objectQuads == 0, "building placement deep-copied object quads")
expect(#S.buildingStamps == 1 and S.buildingStamps[1].quads == localModel,
       "building placement did not retain its shared local model")
expect(S.buildingStamps[1].mx == 16 and S.buildingStamps[1].mz == 24,
       "building placement translation changed")
expect(S.buildingStamps[1].tx == 2 and S.buildingStamps[1].ty == 3
       and S.buildingStamps[1].bw == 1 and S.buildingStamps[1].bh == 1,
       "building placement lost its logical claimed footprint")
expect(#S.buildingStamps[1].doorGroundSamples == 2
       and S.buildingStamps[1].doorGroundSamples[1] == 2
       and S.buildingStamps[1].doorGroundSamples[2] == 3,
       "building stamp did not retain its gameplay door-cell anchor")
local claimed = (3 + 64) * 4096 + (2 + 64)
expect(S.skip[claimed] and S.shapeAt[claimed].class == "building",
       "shared building stamp no longer claimed its footprint")
local scaledStampState = {
  shapeAt = {}, tileAt = {}, skip = {}, ground = {}, objectQuads = {},
  buildingStamps = {},
}
Buildings.stamp(scaledStampState, placementMap, scaledModel,
                2, 3, 1, 1, {})
expect(scaledStampState.buildingStamps[1].heightScale == 1.4,
       "building stamp lost its model-owned height scale")

-- Route 2's northern forest entrance proves the functional case. The matcher
-- retains the native B03 door course and separately records its real warp.
local route2Def = {
  id = "ROUTE_2", source = "ROM:15:4000", index = 13,
  width = 10, height = 36, tileset = "OVERWORLD",
  connections = {
    north = { map = "PEWTER_CITY", offset = -5 },
    south = { map = "VIRIDIAN_CITY", offset = -5 },
  },
  warps = {
    { x = 12, y = 9, destMap = "DIGLETTS_CAVE_ROUTE_2", destWarp = 1 },
    { x = 3, y = 11, destMap = "VIRIDIAN_FOREST_NORTH_GATE", destWarp = 2 },
    { x = 15, y = 19, destMap = "ROUTE_2_TRADE_HOUSE", destWarp = 1 },
    { x = 16, y = 35, destMap = "ROUTE_2_GATE", destWarp = 2 },
    { x = 15, y = 39, destMap = "ROUTE_2_GATE", destWarp = 3 },
    { x = 3, y = 43, destMap = "VIRIDIAN_FOREST_SOUTH_GATE", destWarp = 3 },
  },
}
local route2Map = { id = "ROUTE_2", def = route2Def,
                    tileset = { id = "OVERWORLD" } }
local flatCommercial = {
  id = "flat_commercial",
  tiles = {
    { 76, 83, 83, 83, 83, 83, 83, 77 },
    { 90, 18, 18, 18, 18, 18, 18, 90 },
    { 90, 18, 18, 18, 18, 18, 18, 90 },
    { 92, 23, 23, 23, 23, 23, 23, 93 },
    { 15, 10, 10, 10, 10, 10, 10, 31 },
    { 15, 75, 75, 75, 75, 75, 75, 31 },
    { 15, 75, 11, 12, 75, 75, 75, 31 },
    { 78, 26, 27, 28, 26, 26, 26, 79 },
  },
}
local gateDoor = Buildings.rearWarpDoor(
  route2Map, 4, 24, 8, 8, flatCommercial)
expect(gateDoor and gateDoor.x == 16 and gateDoor.z < 0,
       "canonical north forest door receipt was rejected")
expect(table.concat(gateDoor.tiles, ",") == "11,12,27,28",
       "north forest door no longer reuses the native B03 tile courses")
expect(gateDoor.warp.map == "VIRIDIAN_FOREST_NORTH_GATE"
       and gateDoor.warp.x == 3 and gateDoor.warp.y == 11,
       "rear-door receipt lost its uniquely aligned gameplay warp")
local savedDest = route2Def.warps[2].destMap
route2Def.warps[2].destMap = "VIRIDIAN_FOREST_SOUTH_GATE"
local retargeted = Buildings.rearWarpDoor(
  route2Map, 4, 24, 8, 8, flatCommercial)
expect(retargeted and retargeted.warp.map == "VIRIDIAN_FOREST_SOUTH_GATE",
       "valid retargeted north entrance was not discovered semantically")
route2Def.warps[2].destMap = savedDest
local cosmetic = Buildings.rearFacadeDoor(
  route2Map, 4, 80, 8, 8, flatCommercial)
expect(cosmetic and not cosmetic.functional and cosmetic.warp == nil,
       "door-bearing building did not retain a cosmetic north facade")

-- A matching native SOUTH door is not a licence to paste a decorative door
-- onto every rear wall. Vermilion's ordinary houses were the visible failure:
-- same exact template, no aligned north warp, therefore a closed rear.
local vermilion = {
  id = "VERMILION_CITY",
  def = { id = "VERMILION_CITY", tileset = "OVERWORLD", warps = {} },
  tileset = { id = "OVERWORLD" },
}
expect(Buildings.rearFacadeDoor(
         vermilion, 12, 0, 8, 8, flatCommercial) == nil,
       "ordinary Vermilion house gained an invented rear door")

-- Exact gameplay evidence still wins outside the cosmetic allow-list. This
-- keeps a real north-facing warp functional without broadening its neighbours.
local cerulean = {
  id = "CERULEAN_CITY",
  def = { id = "CERULEAN_CITY", tileset = "OVERWORLD", warps = {
    { x = 9, y = 9, destMap = "CERULEAN_BADGE_HOUSE", destWarp = 1 },
  } },
  tileset = { id = "OVERWORLD" },
}
flatCommercial.rearDoorWidth = 12
local realNorth = Buildings.rearFacadeDoor(
  cerulean, 16, 20, 8, 8, flatCommercial)
expect(realNorth and realNorth.functional
       and realNorth.displayWidth == 12
       and realNorth.warp.map == "CERULEAN_BADGE_HOUSE",
       "aligned Cerulean north warp lost its centred single rear entrance")
flatCommercial.rearDoorWidth = nil
local savedY = route2Def.warps[2].y
route2Def.warps[2].y = 12
local unaligned = Buildings.rearFacadeDoor(
  route2Map, 4, 24, 8, 8, flatCommercial)
expect(unaligned and not unaligned.functional and unaligned.warp == nil,
       "unaligned warp incorrectly made the cosmetic door functional")
route2Def.warps[2].y = savedY

-- Safari's native rest-house course is different, but equally exact. It is
-- visual-only on the north wall because its gameplay warp remains south.
local safari = {
  id = "SAFARI_ZONE_CENTER",
  def = { id = "SAFARI_ZONE_CENTER", tileset = "FOREST", warps = {
    { x = 17, y = 19, destMap = "SAFARI_ZONE_CENTER_REST_HOUSE",
      destWarp = 1 },
  } },
  tileset = { id = "FOREST" },
}
local safariHouse = { tiles = {
  { 8, 9, 9, 9, 9, 9, 9, 12 },
  { 24, 25, 25, 25, 25, 25, 25, 28 },
  { 40, 41, 42, 43, 1, 1, 41, 44 },
  { 56, 41, 58, 59, 41, 41, 41, 60 },
} }
local safariDoor = Buildings.rearFacadeDoor(
  safari, 32, 36, 8, 4, safariHouse)
expect(safariDoor and safariDoor.tileset == "FOREST"
       and table.concat(safariDoor.tiles, ",") == "42,43,58,59"
       and not safariDoor.functional and safariDoor.warp == nil,
       "Safari rest house did not reuse its native rear door course")
local brokenSafari = { tiles = {
  safariHouse.tiles[1], safariHouse.tiles[2], safariHouse.tiles[3],
  { 56, 41, 58, 41, 41, 41, 41, 60 },
} }
expect(Buildings.rearFacadeDoor(
         safari, 32, 36, 8, 4, brokenSafari) == nil,
       "mutated Safari door course did not fail closed")

print("building exterior material/shared stamp: rear+side ok")
