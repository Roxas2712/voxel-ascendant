local stored = { scenery = "full" }
local cache = {}
local V = {
  path = ".",
  mod = { id = "VOXEL_ASCENDANT", options = {
    get = function(_, key) return stored[key] end,
  } },
}

function V.require(name)
  if cache[name] then return cache[name] end
  if name == "ModSetting" then
    cache[name] = assert(loadfile("lib/ModSetting.lua"))(V)
  elseif name == "Voxel3D" then
    cache[name] = {
      FACE_SHADE = { 0.84, 0.72, 1, 0.55, 0.90, 0.68 },
    }
  else
    cache[name] = {}
  end
  return cache[name]
end

package.preload["src.render.TileRenderer"] = function()
  return { voidFill = "trees" }
end

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected "
          .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function near(actual, expected, epsilon, message)
  if math.abs(actual - expected) > epsilon then
    error((message or "values differ") .. ": expected "
          .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function fakeMap(id, width, height, tileset)
  local block = {}
  for i = 1, 16 do block[i] = (i - 1) % 8 end
  return {
    id = id,
    def = { id = id, width = width or 30, height = height or 18,
            outdoor = true, tileset = tileset or "OVERWORLD" },
    tileset = { blocks = { block }, tilesPerRow = 16,
                imageWidth = 128, imageHeight = 48 },
  }
end

local Horizon = assert(loadfile("lib/HorizonWall.lua"))(V)
eq(Horizon.REGIONAL_VRAM, 2432 * 128 * 4,
   "regional atlas retained VRAM is exact")
eq(Horizon.ROUTE8_VRAM, 960 * 96 * 4,
   "Route 8 retains one dedicated high-detail compact")
eq(Horizon.ROUTE8_MIDGROUND_VRAM, 256 * 64 * 4,
   "Route 8 midground retains exactly one 64 KiB atlas")
eq(Horizon.IMAGE_EXTRA_VRAM, 1992704,
   "optional horizon atlases plus the 10 KiB Forest gate facade retain an exact byte budget")
local completeAuthoredVRAM = Horizon.REGIONAL_VRAM + Horizon.MOUNTAIN_VRAM
  + Horizon.COASTAL_LANDMARK_VRAM + Horizon.MINI_TREE_VRAM
  + Horizon.FUJI_VRAM
eq(completeAuthoredVRAM + Horizon.ROUTE8_VRAM
   + Horizon.ROUTE8_MIDGROUND_VRAM, 3053056,
   "complete authored horizon retained VRAM is exact")
if completeAuthoredVRAM + Horizon.ROUTE8_VRAM
   + Horizon.ROUTE8_MIDGROUND_VRAM > 3 * 1024 * 1024 then
  error("complete authored horizon texture budget exceeds 3 MiB")
end

local requiredMaps = {
  "PALLET_TOWN", "ROUTE_1", "VIRIDIAN_CITY", "ROUTE_2",
  "VIRIDIAN_FOREST", "PEWTER_CITY", "ROUTE_3", "ROUTE_4",
  "CERULEAN_CITY", "ROUTE_5", "ROUTE_9", "ROUTE_24", "ROUTE_25",
  "SAFFRON_CITY", "ROUTE_6", "ROUTE_7", "ROUTE_8",
  "CELADON_CITY", "ROUTE_16", "LAVENDER_TOWN", "ROUTE_10",
  "ROUTE_12", "VERMILION_CITY", "ROUTE_11", "VERMILION_DOCK",
  "SS_ANNE_BOW", "FUCHSIA_CITY", "ROUTE_13", "ROUTE_14",
  "ROUTE_15", "ROUTE_17", "ROUTE_18", "SAFARI_ZONE_CENTER",
  "SAFARI_ZONE_EAST", "SAFARI_ZONE_NORTH", "SAFARI_ZONE_WEST",
  "ROUTE_19", "ROUTE_20", "ROUTE_21", "CINNABAR_ISLAND",
  "ROUTE_22", "ROUTE_23", "INDIGO_PLATEAU",
}
for _, id in ipairs(requiredMaps) do
  local rules = Horizon.EDGE_PROFILES[id]
  if not rules then error(id .. " is missing a regional edge profile") end
  for _, edge in ipairs({ "north", "south", "west", "east" }) do
    if not rules[edge] then error(id .. " is missing its " .. edge .. " rule") end
  end
end

local function kind(id, edge, t, width, height)
  local map = fakeMap(id, width or 30, height or 18)
  local length = (edge == "north" or edge == "south")
                 and map.def.width * Horizon.CELL
                 or map.def.height * Horizon.CELL
  return Horizon.panelProfile(map, edge, t * length)
end

-- Mixed approach routes carry the adjacent city's semantic into the matching
-- 90-degree corners while keeping the middle countryside plausible.
eq(kind("ROUTE_5", "west", 0.05), "rural", "Route 5 north approach")
eq(kind("ROUTE_5", "west", 0.50), "town", "Route 5 middle approach")
eq(kind("ROUTE_5", "west", 0.95), "metropolis", "Route 5 Saffron approach")
eq(kind("ROUTE_6", "east", 0.05), "metropolis", "Route 6 Saffron corner")
eq(kind("ROUTE_6", "east", 0.50), "rural", "Route 6 middle")
eq(kind("ROUTE_6", "east", 0.95), "harbor", "Route 6 Vermilion corner")
eq(kind("ROUTE_5", "west", 0.34), "town",
   "Route 5 west side leaves countryside before its east side")
eq(kind("ROUTE_5", "east", 0.34), "rural",
   "Route 5 opposite transitions are not one straight cross-map line")
eq(kind("ROUTE_6", "west", 0.33), "rural",
   "Route 6 west side reaches its rural buffer first")
eq(kind("ROUTE_6", "east", 0.33), "metropolis",
   "Route 6 opposite transition remains location-staggered")
eq(kind("FUCHSIA_CITY", "west", 0.27, 20, 18), "rural",
   "Fuchsia inserts countryside between forest and houses")
eq(kind("FUCHSIA_CITY", "east", 0.27, 20, 18), "forest",
   "Fuchsia forest edge does not end on one shared line")
eq(kind("FUCHSIA_CITY", "west", 0.42, 20, 18), "town",
   "Fuchsia west countryside eases into town")
eq(kind("FUCHSIA_CITY", "east", 0.42, 20, 18), "rural",
   "Fuchsia east countryside buffer remains visible")
eq(kind("ROUTE_11", "north", 0.50), "rural",
   "Route 11 north transition is already countryside at mid-map")
eq(kind("ROUTE_11", "south", 0.50), "town",
   "Route 11 south transition is deliberately offset")
eq(kind("LAVENDER_TOWN", "north", 0.95, 10, 9), "rural",
   "Lavender north-east corner tapers below the town facade")
eq(kind("LAVENDER_TOWN", "east", 0.05, 10, 9), "rural",
   "Lavender east mountain edge joins the north rural buffer")
eq(kind("LAVENDER_TOWN", "south", 0.95, 10, 9), "rural",
   "Lavender south-east corner tapers below the town facade")
eq(kind("LAVENDER_TOWN", "east", 0.95, 10, 9), "rural",
   "Lavender east mountain edge joins the south rural buffer")
eq(kind("ROUTE_22", "north", 0.50), "mountain",
   "Route 22 retains its north-facing mountain landmark")
eq(kind("ROUTE_22", "south", 0.50), "rural",
   "Route 22 south remains open countryside")
for _, edge in ipairs({ "west", "east" }) do
  for _, t in ipairs({ 0.05, 0.35, 0.65, 0.95 }) do
    eq(kind("ROUTE_22", edge, t), "rural",
       "Route 22 side face must not contain a pasted mountain-card seam")
  end
end
eq(kind("ROUTE_8", "north", 0.05), "route8", "Route 8 west strip")
eq(kind("ROUTE_8", "north", 0.50), "route8", "Route 8 middle strip")
eq(kind("ROUTE_8", "north", 0.95), "route8", "Route 8 east strip")
for _, edge in ipairs({ "north", "south", "west", "east" }) do
  eq(kind("ROUTE_8", edge, 0.5), "route8",
     "Route 8 keeps one connector-safe family on " .. edge)
end
for _, id in ipairs({ "ROUTE_13", "ROUTE_14", "ROUTE_17" }) do
  for _, edge in ipairs({ "north", "south", "west", "east" }) do
    eq(kind(id, edge, 0.5), "rural", id .. " stays rural on " .. edge)
  end
end
eq(kind("ROUTE_5", "north", 0.5), kind("ROUTE_5", "west", 0),
   "Route 5 NW corner joins")
eq(kind("ROUTE_5", "south", 0.5), kind("ROUTE_5", "east", 0.999),
   "Route 5 SE corner joins")
eq(kind("ROUTE_6", "north", 0.5), kind("ROUTE_6", "west", 0),
   "Route 6 NW corner joins")
eq(kind("ROUTE_6", "south", 0.5), kind("ROUTE_6", "east", 0.999),
   "Route 6 SE corner joins")

-- No union/map normalisation: every 32-world-pixel panel consumes ~32 native
-- texels regardless of route length, and identical canonical coordinates are
-- identical across map owners.
local r0 = Horizon.panelUV("rural", 0, 320, false)
local r1 = Horizon.panelUV("rural", 0, 352, true)
local ruralSpan = (r1 - r0) * Horizon.REGIONAL_STRIP_W
if ruralSpan < 31 or ruralSpan > 32 then
  error("rural phase is stretched: " .. tostring(ruralSpan))
end
local sameR0 = Horizon.panelUV("rural", 0, 320, false)
near(sameR0, r0, 1e-12, "canonical rural phase is owner-independent")
local m0 = Horizon.panelUV("mountain", 0, -320, false)
local m1 = Horizon.panelUV("mountain", 0, -288, true)
local mountainSpan = (m1 - m0) * Horizon.MOUNTAIN_STRIP_W
if mountainSpan < 31 or mountainSpan > 32 then
  error("mountain phase is stretched: " .. tostring(mountainSpan))
end

-- Coastal cadence aliases the reviewed harbour tail already present at atlas
-- x=2400.  One 32px panel consumes the complete crop at exact 1:1 scale;
-- neither the atlas dimensions nor retained image set changes.
local lowKind, lowSource = Horizon.COASTAL_CADENCE_LOW_KIND,
                           Horizon.COASTAL_CADENCE_LOW_SOURCE
eq(lowKind, "coastal_quay", "coastal cadence low kind changed")
eq(lowSource.asset, "harbor", "coastal cadence added another source image")
eq(lowSource.x, 480, "coastal cadence source crop moved")
eq(lowSource.y, 0, "coastal cadence source crop moved vertically")
eq(lowSource.w, 32, "coastal cadence source is not one native panel")
eq(lowSource.h, 128, "coastal cadence source lost native wall height")
eq(lowSource.atlasX, 2400, "coastal cadence atlas alias moved")
eq(Horizon.REGIONAL_SLICES[lowKind].nativeWorld, true,
   "coastal cadence lost exact native-world addressing")
eq(Horizon.IMAGE_ASSETS[lowSource.asset], Horizon.IMAGE_ASSETS.harbor,
   "coastal cadence retained a second image family")
local lowU0, lowV0, lowV1 = Horizon.panelUV(lowKind, 0, 0, false)
local lowU1 = Horizon.panelUV(lowKind, 0, Horizon.CELL, true)
near(lowU0 * Horizon.REGIONAL_STRIP_W, lowSource.atlasX, 1e-12,
     "coastal cadence did not begin on its native atlas texel")
near(lowU1 * Horizon.REGIONAL_STRIP_W,
     lowSource.atlasX + lowSource.w, 1e-12,
     "coastal cadence did not consume its complete native crop")
near((lowU1 - lowU0) * Horizon.REGIONAL_STRIP_W, Horizon.CELL, 1e-12,
     "coastal cadence source texels are not 1:1 world pixels")
near((lowV1 - lowV0) * Horizon.REGIONAL_TEXTURE_H, lowSource.h, 1e-12,
     "coastal cadence vertical texels are not 1:1 world pixels")

local function exactTaper(mode, edge, inner, low, tip, length, label)
  eq(Horizon.coastalCadenceStage(mode, edge, inner, length), nil,
     label .. " did not keep the inner canonical panel")
  eq(Horizon.coastalCadenceStage(mode, edge, low, length), "low",
     label .. " lost its single low native module")
  eq(Horizon.coastalCadenceStage(mode, edge, tip, length), "open_water",
     label .. " lost its transparent/open tip")
end
local fuchsiaW, fuchsiaH = 20 * Horizon.CELL, 18 * Horizon.CELL
exactTaper("south_free", "south", 2 * Horizon.CELL, Horizon.CELL, 0,
           fuchsiaW, "Fuchsia southwest shoreline arm")
exactTaper("south_free", "south", fuchsiaW - 3 * Horizon.CELL,
           fuchsiaW - 2 * Horizon.CELL, fuchsiaW - Horizon.CELL,
           fuchsiaW, "Fuchsia southeast shoreline arm")
for _, edge in ipairs({ "west", "east" }) do
  exactTaper("south_free", edge, fuchsiaH - 3 * Horizon.CELL,
             fuchsiaH - 2 * Horizon.CELL, fuchsiaH - Horizon.CELL,
             fuchsiaH, "Fuchsia " .. edge .. " inland-facing arm")
end
local palletH = 9 * Horizon.CELL
for _, edge in ipairs({ "west", "east" }) do
  exactTaper("south_corners", edge, palletH - 3 * Horizon.CELL,
             palletH - 2 * Horizon.CELL, palletH - Horizon.CELL,
             palletH, "Pallet " .. edge .. " Route 21 arm")
end
local dockW = 14 * Horizon.CELL
for _, edge in ipairs({ "north", "south" }) do
  exactTaper("dock", edge, 2 * Horizon.CELL, Horizon.CELL, 0,
             dockW, "Dock northwest/west arm on " .. edge)
  exactTaper("dock", edge, dockW - 3 * Horizon.CELL,
             dockW - 2 * Horizon.CELL, dockW - Horizon.CELL,
             dockW, "Dock northeast/east arm on " .. edge)
end
eq(Horizon.coastalCadenceStage("south_free", "north", 0, fuchsiaW), nil,
   "Fuchsia cadence escaped its verified coastal turns")
eq(Horizon.coastalCadenceStage("dock", "north", 0.5, dockW), nil,
   "coastal cadence accepted a non-native panel boundary")

local route5 = fakeMap("ROUTE_5", 20, 18)
local route5Built = Horizon.geometry({ map = route5, neighbors = {} })[1]
eq(route5Built.wallDraws, 1,
   "all Route 5 semantic transitions share one regional wall draw")
eq(route5Built.wallGroups[1].family, "regional", "Route 5 regional family")
local route8 = fakeMap("ROUTE_8", 30, 9)
local route8Parts = Horizon.geometry({ map = route8, neighbors = {} })
local route8Built = route8Parts[1]
eq(route8Built.wallDraws, 1,
   "isolated Route 8 continuous strip stays one wall draw")
eq(route8Built.wallGroups[1].family, "route8",
   "Route 8 uses its dedicated native-height texture family")

-- Production Route 8 is exactly 960x288 world pixels.  North/south consume
-- the complete strip once; west/east select the authored city/Lavender
-- thirds.  The four 96px outer-corner endpoints must agree pairwise, while
-- inner joins land on the compact asset's equal connector columns.
local r8w, r8h = route8.def.width * Horizon.CELL,
                 route8.def.height * Horizon.CELL
eq(Horizon.route8Phase(0, 0, r8w, false), 0,
   "Route 8 north begins at Saffron")
eq(Horizon.route8Phase(0, r8w, r8w, true), Horizon.ROUTE8_STRIP_W,
   "Route 8 north reaches Lavender without a repeated strip")
eq(Horizon.route8Phase(2, 0, r8h, false), 0,
   "Route 8 west face begins on its city connector")
eq(Horizon.route8Phase(2, r8h, r8h, true), Horizon.ROUTE8_CITY_SPAN,
   "Route 8 west face consumes the city third exactly once")
eq(Horizon.route8Phase(3, 0, r8h, false), Horizon.ROUTE8_LAVENDER_X,
   "Route 8 east face begins on its Lavender connector")
eq(Horizon.route8Phase(3, r8h, r8h, true), Horizon.ROUTE8_STRIP_W,
   "Route 8 east face consumes the Lavender third exactly once")
eq(Horizon.route8Phase(0, -Horizon.OUTDOOR_WALL_DISTANCE, r8w, false),
   Horizon.route8Phase(2, -Horizon.OUTDOOR_WALL_DISTANCE, r8h, false),
   "Route 8 northwest outer corner uses one connector column")
eq(Horizon.route8Phase(1, -Horizon.OUTDOOR_WALL_DISTANCE, r8w, false),
   Horizon.route8Phase(2, r8h + Horizon.OUTDOOR_WALL_DISTANCE,
                       r8h, true),
   "Route 8 southwest outer corner uses one connector column")
eq(Horizon.route8Phase(0, r8w + Horizon.OUTDOOR_WALL_DISTANCE,
                       r8w, true),
   Horizon.route8Phase(3, -Horizon.OUTDOOR_WALL_DISTANCE, r8h, false),
   "Route 8 northeast outer corner uses one connector column")
eq(Horizon.route8Phase(1, r8w + Horizon.OUTDOOR_WALL_DISTANCE,
                       r8w, true),
   Horizon.route8Phase(3, r8h + Horizon.OUTDOOR_WALL_DISTANCE,
                       r8h, true),
   "Route 8 southeast outer corner uses one connector column")

-- Landmarks have one physical bearing owner.  North/south substitute native
-- 32px background panels, while the west/east exact connector faces retain
-- exactly the two source panels that form their respective tower.
local landmarkPanels = { saffron = {}, lavender = {} }
for name in pairs(landmarkPanels) do
  for edge = 0, 3 do landmarkPanels[name][edge] = 0 end
end
local edgeLengths = { r8w, r8w, r8h, r8h }
for edge = 0, 3 do
  local length = edgeLengths[edge + 1]
  for along = 0, length - Horizon.CELL, Horizon.CELL do
    local phase0, phase1 = Horizon.route8PanelPhases(
      edge, along, along + Horizon.CELL, length)
    for _, name in ipairs(Horizon.ROUTE8_LANDMARK_ORDER) do
      local landmark = Horizon.ROUTE8_LANDMARKS[name]
      if phase0 < landmark.x1 and phase1 > landmark.x0 then
        landmarkPanels[name][edge] = landmarkPanels[name][edge] + 1
      end
    end
  end
end
for _, name in ipairs(Horizon.ROUTE8_LANDMARK_ORDER) do
  local landmark = Horizon.ROUTE8_LANDMARKS[name]
  for edge = 0, 3 do
    local expected = edge == landmark.owner and 2 or 0
    eq(landmarkPanels[name][edge], expected,
       "Route 8 " .. name .. " landmark escaped its single bearing owner")
  end
end
for _, edge in ipairs({ 0, 1 }) do
  local saffron0, saffron1 = Horizon.route8PanelPhases(
    edge, 128, 192, r8w)
  eq(saffron1 - saffron0, 64,
     "Route 8 Saffron substitution lost native scale")
  eq(saffron0, Horizon.ROUTE8_LANDMARKS.saffron.replacementX,
     "Route 8 Saffron substitution changed source window")
  local lavender0, lavender1 = Horizon.route8PanelPhases(
    edge, 768, 832, r8w)
  eq(lavender1 - lavender0, 64,
     "Route 8 Lavender substitution lost native scale")
  eq(lavender0, Horizon.ROUTE8_LANDMARKS.lavender.replacementX,
     "Route 8 Lavender substitution changed source window")
end
local corner0, corner1 = Horizon.route8PanelPhases(
  0, -Horizon.OUTDOOR_WALL_DISTANCE,
  -Horizon.OUTDOOR_WALL_DISTANCE + Horizon.CELL, r8w)
eq(corner0, Horizon.route8Phase(0, -Horizon.OUTDOOR_WALL_DISTANCE,
                               r8w, false),
   "Route 8 landmark ownership changed a connector-arm start")
eq(corner1, Horizon.route8Phase(
     0, -Horizon.OUTDOOR_WALL_DISTANCE + Horizon.CELL, r8w, true),
   "Route 8 landmark ownership changed a connector-arm end")

-- Midground phases fold the distant strip's equal connector columns onto the
-- matching four-module city sets. Both depth rows stay deterministic and use
-- different motifs, while the short faces reserve the real Gen-1 lanes.
for row = 0, Horizon.ROUTE8_MIDGROUND_ROWS - 1 do
  eq(Horizon.route8MidgroundModule(0, 0, r8w, row),
     Horizon.route8MidgroundModule(2, 0, r8h, row),
     "Route 8 northwest midground connector phase drifted")
  eq(Horizon.route8MidgroundModule(0, r8w, r8w, row),
     Horizon.route8MidgroundModule(3, 0, r8h, row),
     "Route 8 northeast midground connector phase drifted")
  eq(Horizon.route8MidgroundModule(0, -64, r8w, row),
     Horizon.route8MidgroundModule(2, -64, r8h, row),
     "Route 8 northwest outer midground phase drifted")
end
local westModule = Horizon.route8MidgroundModule(2, 32, r8h, 0)
local eastModule = Horizon.route8MidgroundModule(3, 32, r8h, 0)
if westModule < 0 or westModule > 3 then
  error("Route 8 west midground escaped Saffron modules 0..3")
end
if eastModule < 4 or eastModule > 7 then
  error("Route 8 east midground escaped Lavender modules 4..7")
end
local generic0, generic1 = Horizon.route8MidgroundOpening(r8h)
eq(generic0, 96, "Route 8 generic fallback opening moved off lattice")
eq(generic1, 160, "Route 8 generic fallback opening lost its 64px width")
local westSeam = Horizon.route8SeamSpec(2)
eq(westSeam.target, "SAFFRON_CITY",
   "Route 8 west seam lost its real target")
eq(westSeam.offsetBlocks, -4,
   "Route 8 west seam lost Saffron's four-block offset")
eq(westSeam.firstCell, 8,
   "Route 8 west seam moved its first traversable cell")
eq(westSeam.lastCell, 10,
   "Route 8 west seam moved its last traversable cell")
local eastSeam = Horizon.route8SeamSpec(3)
eq(eastSeam.target, "LAVENDER_TOWN",
   "Route 8 east seam lost its real target")
eq(eastSeam.offsetBlocks, 0,
   "Route 8 east seam ceased to be flush with Lavender")
eq(eastSeam.firstCell, 8,
   "Route 8 east seam moved its traversable cell")
eq(eastSeam.lastCell, 8,
   "Route 8 east seam widened beyond its traversable cell")
local westOpen0, westOpen1 = Horizon.route8MidgroundOpening(r8h, 2)
eq(westOpen0, 128,
   "Route 8 west scenery opening starts before its real lanes")
eq(westOpen1, 192,
   "Route 8 west scenery opening blocks authored lane y=10")
local eastOpen0, eastOpen1 = Horizon.route8MidgroundOpening(r8h, 3)
eq(eastOpen0, 128,
   "Route 8 east scenery opening starts before its real lane")
eq(eastOpen1, 160,
   "Route 8 east scenery opening did not stay on the 32px mesh lattice")
eq(Horizon.route8MidgroundFlankModule(2, 96, r8h, 0), 3,
   "Route 8 west lane lost its left low shrub")
eq(Horizon.route8MidgroundFlankModule(2, 192, r8h, 0), 3,
   "Route 8 west lane lost its right low shrub")
eq(Horizon.route8MidgroundFlankModule(3, 96, r8h, 0), 7,
   "Route 8 east lane lost its left small trees")
eq(Horizon.route8MidgroundFlankModule(3, 160, r8h, 0), 7,
   "Route 8 east lane lost its right small trees")
eq(Horizon.route8MidgroundFlankModule(2, 96, r8h, 1), nil,
   "Route 8 duplicated its seam shrub into both depth rows")

-- A cold target leaves Horizon's generic green apron visible at the exact
-- connection.  The canonical current-only Route 8 state therefore owns one
-- atlas-backed batch containing the real $23/$39 source phases across both
-- complete 96px aprons.  Its low voxel course, not a second near billboard,
-- frames the lanes; only the farther first depth row uses a native 16x12 crop.
local flankedRoute8 = fakeMap("ROUTE_8", 30, 9)
flankedRoute8.def.connections = {
  west = { map = "SAFFRON_CITY", offset = -4 },
  east = { map = "LAVENDER_TOWN", offset = 0 },
}
flankedRoute8._collision = {}
for cy = 8, 10 do flankedRoute8._collision[cy * 128] = true end
flankedRoute8._collision[8 * 128 + 59] = true
flankedRoute8._tiles = {}
function flankedRoute8:tileAt(tx, ty)
  return self._tiles[ty * 256 + tx] or 0
end
local function sourceCell(cx, cy, values)
  for dy = 0, 1 do
    for dx = 0, 1 do
      flankedRoute8._tiles[(cy * 2 + dy) * 256 + cx * 2 + dx] =
        values[dy * 2 + dx + 1]
    end
  end
end
sourceCell(0, 8, { 0x23, 0x23, 0x39, 0x23 })
sourceCell(0, 9, { 0x23, 0x23, 0x23, 0x23 })
sourceCell(0, 10, { 0x39, 0x39, 0x39, 0x39 })
sourceCell(59, 8, { 0x39, 0x39, 0x39, 0x39 })
function flankedRoute8:isWalkableCell(cx, cy)
  return self._collision[cy * 128 + cx] == true
end
eq(Horizon.route8SeamVerified(flankedRoute8, 2), true,
   "canonical Route 8 west flank cells were not verified")
eq(Horizon.route8SeamVerified(flankedRoute8, 3), true,
   "canonical Route 8 east flank cells were not verified")
local collisionBefore = {}
for key, value in pairs(flankedRoute8._collision) do
  collisionBefore[key] = value
end
local flankedBuilt = Horizon.geometry({ map = flankedRoute8, neighbors = {} })[1]
eq(flankedBuilt.route8SeamFlankQuads, 0,
   "Route 8 restored a near-camera seam shrub billboard")
eq(flankedBuilt.route8MidgroundQuads, 86,
   "Route 8 low seam framing changed the sparse midground quad budget")
eq(flankedBuilt.route8SeamPathQuads, 96,
   "cold Route 8 did not tile both full 96px aprons at native 8px scale")
eq(flankedBuilt.route8SeamPathQuadsByEdge[2], 72,
   "cold Route 8 west proxy did not cover all three 96px lanes")
eq(flankedBuilt.route8SeamPathQuadsByEdge[3], 24,
   "cold Route 8 east proxy did not reach the 96px wall baseline")
eq(#flankedBuilt.route8SeamPathVertices, 96 * 4,
   "cold Route 8 path escaped its one indexed vertex batch")
eq(#flankedBuilt.route8SeamPathIndices, 96 * 6,
   "cold Route 8 path escaped its one indexed triangle batch")
local pathBounds = {
  [2] = { math.huge, -math.huge, math.huge, -math.huge },
  [3] = { math.huge, -math.huge, math.huge, -math.huge },
}
local pathMaterials = { [0x23] = 0, [0x39] = 0 }
for i = 1, #flankedBuilt.route8SeamPathVertices, 4 do
  local a, b, c = flankedBuilt.route8SeamPathVertices[i],
                  flankedBuilt.route8SeamPathVertices[i + 1],
                  flankedBuilt.route8SeamPathVertices[i + 2]
  local edge = a[1] < 0 and 2 or 3
  local sourceBaseTx = edge == 2 and 0 or 118
  local sourceDx = math.floor(a[1] / 8) % 2
  local tile = flankedRoute8:tileAt(sourceBaseTx + sourceDx,
                                    math.floor(a[3] / 8))
  local expectedPathU = ((tile % 16) * 8
                         + Horizon.ROUTE8_COLD_PATH_UV_INSET) / 128
  local expectedPathV = (math.floor(tile / 16) * 8
                         + Horizon.ROUTE8_COLD_PATH_UV_INSET) / 48
  pathMaterials[tile] = (pathMaterials[tile] or 0) + 1
  eq(a[2], Horizon.ROUTE8_COLD_PATH_RISE,
     "cold Route 8 path lost its z-fight-safe visual rise")
  eq(b[1] - a[1], Horizon.ROUTE8_COLD_PATH_TILE_SIZE,
     "cold Route 8 path stretched one source tile horizontally")
  eq(c[3] - b[3], Horizon.ROUTE8_COLD_PATH_TILE_SIZE,
     "cold Route 8 path stretched one source tile vertically")
  near(a[4], expectedPathU, 1e-12,
       "cold Route 8 path did not select its source-authored atlas U")
  near(a[5], expectedPathV, 1e-12,
       "cold Route 8 path did not select its source-authored atlas V")
  for j = 0, 3 do
    local v = flankedBuilt.route8SeamPathVertices[i + j]
    local bounds = pathBounds[edge]
    bounds[1], bounds[2] = math.min(bounds[1], v[1]),
                           math.max(bounds[2], v[1])
    bounds[3], bounds[4] = math.min(bounds[3], v[3]),
                           math.max(bounds[4], v[3])
  end
end
for edge, expected in pairs({
  [2] = { -96, 0, 128, 176 }, [3] = { 960, 1056, 128, 144 },
}) do
  for index = 1, 4 do
    eq(pathBounds[edge][index], expected[index],
       "cold Route 8 proxy escaped its exact edge/apron coverage")
  end
end
eq(pathMaterials[0x23], 42,
   "cold west proxy lost its canonical plain-path tile cadence")
eq(pathMaterials[0x39], 54,
   "cold proxies lost their canonical dashed-path tile cadence")
local flankPositions, flankQuads = {}, 0
for i = 1, #flankedBuilt.route8MidgroundVertices, 4 do
  local minX, maxX, minZ, maxZ = math.huge, -math.huge,
                                   math.huge, -math.huge
  local minY, maxY = math.huge, -math.huge
  local minU, maxU, minV, maxV = math.huge, -math.huge,
                                  math.huge, -math.huge
  for j = 0, 3 do
    local v = flankedBuilt.route8MidgroundVertices[i + j]
    minX, maxX = math.min(minX, v[1]), math.max(maxX, v[1])
    minY, maxY = math.min(minY, v[2]), math.max(maxY, v[2])
    minZ, maxZ = math.min(minZ, v[3]), math.max(maxZ, v[3])
    minU, maxU = math.min(minU, v[4]), math.max(maxU, v[4])
    minV, maxV = math.min(minV, v[5]), math.max(maxV, v[5])
  end
  if maxX == minX and maxZ - minZ == Horizon.ROUTE8_SEAM_CELL
     and minZ >= 0 and maxZ <= r8h then
    flankQuads = flankQuads + 1
    eq(maxY - minY, Horizon.ROUTE8_SEAM_SHRUB.h,
       "Route 8 seam shrub regained a full-height tree board")
    eq((maxU - minU) * Horizon.ROUTE8_MIDGROUND_W,
       Horizon.ROUTE8_SEAM_SHRUB.w,
       "Route 8 seam shrub lost native horizontal scale")
    eq((maxV - minV) * Horizon.ROUTE8_MIDGROUND_H,
       Horizon.ROUTE8_SEAM_SHRUB.h,
       "Route 8 seam shrub lost native vertical scale")
    eq(minU * Horizon.ROUTE8_MIDGROUND_W, Horizon.ROUTE8_SEAM_SHRUB.x,
       "Route 8 seam shrub sampled a tree-bearing atlas column")
    eq(minV * Horizon.ROUTE8_MIDGROUND_H, Horizon.ROUTE8_SEAM_SHRUB.y,
       "Route 8 seam shrub sampled above its low cut-out")
    flankPositions[minX .. ":" .. minZ] = true
  end
end
eq(flankQuads, 4,
   "Route 8 cold seam framing did not keep four outward shrub cut-outs")
for _, position in ipairs({
  "-32:104", "-32:200", "992:104", "992:168",
}) do
  eq(flankPositions[position], true,
     "Route 8 seam flank moved onto a lane: " .. position)
end
for key, value in pairs(collisionBefore) do
  eq(flankedRoute8._collision[key], value,
     "Route 8 seam framing mutated collision")
end
flankedRoute8._collision[7 * 128 + 59] = true
eq(Horizon.route8SeamVerified(flankedRoute8, 3), false,
   "walkable Route 8 flank cell accepted decorative obstruction")
local editedEast = Horizon.geometry({ map = flankedRoute8, neighbors = {} })[1]
eq(editedEast.route8SeamPathQuadsByEdge[3], 0,
   "edited Route 8 collision inherited the east cold proxy")
eq(editedEast.route8SeamPathQuadsByEdge[2], 72,
   "edited east collision suppressed the independent west cold proxy")
flankedRoute8._collision[7 * 128 + 59] = nil
flankedRoute8.def.connections.east.offset = 1
eq(Horizon.route8SeamVerified(flankedRoute8, 3), false,
   "edited Route 8/Lavender offset inherited seam framing")
local editedOffset = Horizon.geometry({ map = flankedRoute8, neighbors = {} })[1]
eq(editedOffset.route8SeamPathQuadsByEdge[3], 0,
   "edited Route 8/Lavender offset inherited the east cold proxy")
eq(editedOffset.route8SeamPathQuadsByEdge[2], 72,
   "edited east offset suppressed the independent west cold proxy")
flankedRoute8.def.connections.east.offset = 0
local eastTileKey = 16 * 256 + 118
flankedRoute8._tiles[eastTileKey] = 0x23
eq(Horizon.route8SeamVerified(flankedRoute8, 3), false,
   "edited Route 8 east source material passed canonical verification")
local editedEastTile = Horizon.geometry({ map = flankedRoute8,
                                          neighbors = {} })[1]
eq(editedEastTile.route8SeamPathQuadsByEdge[3], 0,
   "edited Route 8 east material inherited the cold proxy")
eq(editedEastTile.route8SeamPathQuadsByEdge[2], 72,
   "edited east material suppressed the independent west proxy")
flankedRoute8._tiles[eastTileKey] = 0x39
local westTileKey = 16 * 256
flankedRoute8._tiles[westTileKey] = 0x39
eq(Horizon.route8SeamVerified(flankedRoute8, 2), false,
   "edited Route 8 west source material passed canonical verification")
local editedWestTile = Horizon.geometry({ map = flankedRoute8,
                                          neighbors = {} })[1]
eq(editedWestTile.route8SeamPathQuadsByEdge[2], 0,
   "edited Route 8 west material inherited the cold proxy")
eq(editedWestTile.route8SeamPathQuadsByEdge[3], 24,
   "edited west material suppressed the independent east proxy")
flankedRoute8._tiles[westTileKey] = 0x23

-- Long faces retain only sparse, coprime module cadences. The exact west/east
-- connector faces stay occupied, while synthetic corner arms remain present
-- only as the atlas' low shrub crop instead of pasted landmark cards.
local longCadence = { 0, 0 }
for along = 0, r8w - Horizon.CELL, Horizon.CELL do
  for row = 0, Horizon.ROUTE8_MIDGROUND_ROWS - 1 do
    if Horizon.route8MidgroundOccupied(0, along, r8w, row) then
      longCadence[row + 1] = longCadence[row + 1] + 1
    end
  end
end
eq(longCadence[1], 10,
   "Route 8 inner midground row lost its sparse three-cell cadence")
eq(longCadence[2], 6,
   "Route 8 outer midground row lost its sparse five-cell cadence")
for _, edge in ipairs({ 2, 3 }) do
  for along = 0, r8h - Horizon.CELL, Horizon.CELL do
    for row = 0, Horizon.ROUTE8_MIDGROUND_ROWS - 1 do
      eq(Horizon.route8MidgroundOccupied(edge, along, r8h, row), true,
         "Route 8 exact connector-face module was sparsified")
    end
  end
end
for _, along in ipairs({ -Horizon.CELL, r8w }) do
  for row = 0, Horizon.ROUTE8_MIDGROUND_ROWS - 1 do
    eq(Horizon.route8MidgroundOccupied(0, along, r8w, row), true,
       "Route 8 corner-arm midground acquired a gap")
  end
end

-- Verify ownership again on emitted geometry, not only through the pure
-- address helper: no z-facing wall quad may sample a tower window, and each
-- x-facing endpoint owns exactly two native panels.
local emittedLandmarkPanels = { saffron = 0, lavender = 0 }
local function route8PhaseFromU(u)
  return (u * Horizon.ROUTE8_STRIP_W - 0.5)
         * Horizon.ROUTE8_STRIP_W / (Horizon.ROUTE8_STRIP_W - 1)
end
for _, group in ipairs(route8Built.wallGroups) do
  if group.family == "route8" then
    for i = 1, #group.vertices, 4 do
      local a, b = group.vertices[i], group.vertices[i + 1]
      local xFacing = a[1] == b[1]
      local phase0 = math.min(route8PhaseFromU(a[4]),
                              route8PhaseFromU(b[4]))
      local phase1 = math.max(route8PhaseFromU(a[4]),
                              route8PhaseFromU(b[4]))
      for _, name in ipairs(Horizon.ROUTE8_LANDMARK_ORDER) do
        local landmark = Horizon.ROUTE8_LANDMARKS[name]
        if phase0 < landmark.x1 - 1e-4
           and phase1 > landmark.x0 + 1e-4 then
          if not xFacing then
            error("Route 8 " .. name
                  .. " landmark duplicated onto a long visible face")
          end
          local expectedX = landmark.owner == 2
            and -Horizon.OUTDOOR_WALL_DISTANCE
            or r8w + Horizon.OUTDOOR_WALL_DISTANCE
          if math.abs(a[1] - expectedX) > 1e-6 then
            error("Route 8 " .. name
                  .. " landmark escaped its world-bearing wall")
          end
          emittedLandmarkPanels[name] = emittedLandmarkPanels[name] + 1
        end
      end
    end
  end
end
eq(emittedLandmarkPanels.saffron, 2,
   "Route 8 emitted Saffron landmark more than once around the ring")
eq(emittedLandmarkPanels.lavender, 2,
   "Route 8 emitted Lavender landmark more than once around the ring")

-- Outdoor walls form one closed graph around the complete streamed union,
-- and every horizontal filler cell is unique on the same 32px lattice as the
-- terrain. This catches both the old seam fins (degree-one wall endpoints)
-- and the coplanar apron/cap overlaps that only appeared after moving the wall
-- from 32px to 96px.
local function auditOutdoorUnion(parts, message)
  local degree, groundCells = {}, {}
  local function key(x, z) return tostring(x) .. ":" .. tostring(z) end
  local k = 0.18 / 144
  for _, part in ipairs(parts) do
    for i = 1, #part.wallVertices, 4 do
      local a, b = part.wallVertices[i], part.wallVertices[i + 1]
      local ak = key(part.ox + a[1], part.oy + a[3])
      local bk = key(part.ox + b[1], part.oy + b[3])
      degree[ak], degree[bk] = (degree[ak] or 0) + 1,
                               (degree[bk] or 0) + 1
    end
    for i = 1, #part.groundVertices, 4 do
      local minX, maxX, minZ, maxZ = math.huge, -math.huge,
                                       math.huge, -math.huge
      for j = 0, 3 do
        local v = part.groundVertices[i + j]
        minX, maxX = math.min(minX, part.ox + v[1]),
                     math.max(maxX, part.ox + v[1])
        minZ, maxZ = math.min(minZ, part.oy + v[3]),
                     math.max(maxZ, part.oy + v[3])
      end
      local spanX, spanZ = maxX - minX, maxZ - minZ
      if spanX > Horizon.CELL or spanZ > Horizon.CELL then
        error(message .. " ground escaped the 32px curve lattice: "
              .. spanX .. "x" .. spanZ)
      end
      local curveError = k * (spanX * spanX + spanZ * spanZ) / 4
      if curveError > 0.65 then
        error(message .. " ground exceeded the WorldCurve error bound: "
              .. tostring(curveError))
      end
      local cell = key(minX, minZ)
      if groundCells[cell] then
        error(message .. " duplicated outdoor ground cell " .. cell)
      end
      groundCells[cell] = true
    end
  end
  for point, count in pairs(degree) do
    if count ~= 2 then
      error(message .. " left a degree-" .. count
            .. " wall endpoint at " .. point)
    end
  end
end

auditOutdoorUnion(route8Parts,
                  "isolated mixed regional/mountain Route 8")

-- The production component is not a flush three-map row: Saffron is four
-- blocks north of Route 8, while Lavender is flush on the east.  Exercise
-- that exact union so a connector fix cannot regress to an isolated-map-only
-- panorama.  Saffron's 96px dilation legitimately masks the first city
-- panels, but the remaining Route 8 north/south contour must still sample the
-- compact strip from the Silph landmark through the Lavender tower.
local saffron = fakeMap("SAFFRON_CITY", 20, 18)
local lavender = fakeMap("LAVENDER_TOWN", 10, 9)
local connectedRoute8 = Horizon.geometry({ map = route8, neighbors = {
  { map = saffron, ox = -saffron.def.width * Horizon.CELL,
    oy = -4 * Horizon.CELL },
  { map = lavender, ox = route8.def.width * Horizon.CELL, oy = 0 },
} })
auditOutdoorUnion(connectedRoute8,
                  "real Route 8/Saffron/Lavender union")
eq(connectedRoute8[1].wallDraws, 1,
   "connected Route 8 owner keeps one dedicated strip draw")
if connectedRoute8[1].route8MidgroundQuads <= 0 then
  error("connected Route 8 lost its bounded north/south midground framing")
end
for owner = 2, #connectedRoute8 do
  eq(connectedRoute8[owner].route8MidgroundQuads, 0,
     "Route 8 midground duplicated onto a target city owner")
  eq(#connectedRoute8[owner].route8MidgroundVertices, 0,
     "target city received hidden Route 8 landmark geometry")
end
for _, vertex in ipairs(connectedRoute8[1].route8MidgroundVertices) do
  if vertex[2] ~= 0 and vertex[2] ~= Horizon.ROUTE8_MIDGROUND_H then
    error("Route 8 midground inherited a target-ground height proxy")
  end
end

local connectedFlanks = Horizon.geometry({ map = flankedRoute8, neighbors = {
  { map = saffron, ox = -saffron.def.width * Horizon.CELL,
    oy = -4 * Horizon.CELL },
  { map = lavender, ox = flankedRoute8.def.width * Horizon.CELL, oy = 0 },
} })
eq(connectedFlanks[1].route8SeamFlankQuads, 0,
   "resident target restored a near-camera seam shrub")
eq(connectedFlanks[1].route8SeamPathQuads, 0,
   "resident city bodies retained a cold Route 8 path proxy")
eq(connectedFlanks[1].route8SeamPathQuadsByEdge[2], 0,
   "resident Saffron body retained the west cold proxy")
eq(connectedFlanks[1].route8SeamPathQuadsByEdge[3], 0,
   "resident Lavender body retained the east cold proxy")
eq(#connectedFlanks[1].route8SeamPathVertices, 0,
   "resident Lavender body can z-fight a cold Route 8 path proxy")
local warmShrubs = 0
for i = 1, #connectedFlanks[1].route8MidgroundVertices, 4 do
  local minX, maxX, minY, maxY, minZ, maxZ = math.huge, -math.huge,
    math.huge, -math.huge, math.huge, -math.huge
  for j = 0, 3 do
    local v = connectedFlanks[1].route8MidgroundVertices[i + j]
    minX, maxX = math.min(minX, v[1]), math.max(maxX, v[1])
    minY, maxY = math.min(minY, v[2]), math.max(maxY, v[2])
    minZ, maxZ = math.min(minZ, v[3]), math.max(maxZ, v[3])
  end
  if maxY - minY == Horizon.ROUTE8_SEAM_SHRUB.h
     and math.max(maxX - minX, maxZ - minZ)
         == Horizon.ROUTE8_SEAM_SHRUB.w then
    warmShrubs = warmShrubs + 1
  end
end
eq(warmShrubs, 0,
   "resident target retained cold-apron shrubs on walkable city cells")
for owner = 2, #connectedFlanks do
  eq(connectedFlanks[owner].route8MidgroundQuads, 0,
     "resident target city acquired Route 8-owned seam geometry")
  eq(connectedFlanks[owner].route8SeamPathQuads, 0,
     "resident target city acquired Route 8's cold path geometry")
end

local eastWarm = Horizon.geometry({ map = flankedRoute8, neighbors = {
  { map = lavender, ox = flankedRoute8.def.width * Horizon.CELL, oy = 0 },
} })[1]
eq(eastWarm.route8SeamPathQuadsByEdge[3], 0,
   "east-resident union retained the Lavender cold proxy")
eq(eastWarm.route8SeamPathQuadsByEdge[2], 72,
   "east-resident union suppressed the independent Saffron cold proxy")
local westWarm = Horizon.geometry({ map = flankedRoute8, neighbors = {
  { map = saffron, ox = -saffron.def.width * Horizon.CELL,
    oy = -4 * Horizon.CELL },
} })[1]
eq(westWarm.route8SeamPathQuadsByEdge[2], 0,
   "west-resident union retained the Saffron cold proxy")
eq(westWarm.route8SeamPathQuadsByEdge[3], 24,
   "west-resident union suppressed the independent Lavender cold proxy")

local connectedRoute8Group
for _, group in ipairs(connectedRoute8[1].wallGroups) do
  if group.family == "route8" then connectedRoute8Group = group end
end
if not connectedRoute8Group then error("connected Route 8 lost its strip") end
local minConnectedPhase, maxConnectedPhase = math.huge, -math.huge
for i = 1, #connectedRoute8Group.vertices, 4 do
  local a, b = connectedRoute8Group.vertices[i],
               connectedRoute8Group.vertices[i + 1]
  -- Only Route 8's horizontal far faces represent the authored west-to-east
  -- world progression; its short faces deliberately reuse end thirds.
  if a[3] == b[3] then
    for _, vertex in ipairs({ a, b }) do
      local phase = ((vertex[4] * Horizon.ROUTE8_STRIP_W - 0.5)
                     * Horizon.ROUTE8_STRIP_W
                     / (Horizon.ROUTE8_STRIP_W - 1))
      minConnectedPhase = math.min(minConnectedPhase, phase)
      maxConnectedPhase = math.max(maxConnectedPhase, phase)
    end
  end
end
if minConnectedPhase > 112 or maxConnectedPhase < 958 then
  error("connected Route 8 clips a landmark end of its compact strip: "
        .. tostring(minConnectedPhase) .. ".." .. tostring(maxConnectedPhase))
end

-- Real neighbours always win before an edge profile can emit a panel/filler.
local route13 = fakeMap("ROUTE_13", 12, 8)
local east = fakeMap("ROUTE_14", 12, 8)
;(function()
local isolatedRoute13 = Horizon.geometry({ map=route13, neighbors={} })[1]
eq(Horizon.NEAR_FILL_FIRST, 16,
   "ordinary edge fill no longer starts on the first half-cell")
eq(Horizon.NEAR_FILL_STEP, 32,
   "ordinary edge fill no longer follows the native cell cadence")
eq(Horizon.NEAR_FILL_CARD_W, 26,
   "ordinary edge cards no longer leave visible gaps")
eq(Horizon.RURAL_TERMINAL_TREE_H, 76,
   "rural terminal tree no longer clears the panorama silhouette")
eq(Horizon.RURAL_TERMINAL_INSET, 2,
   "rural terminal tree lost its non-coplanar inset")
eq(Horizon.RURAL_TERMINAL_TREE_VARIANT, 1,
   "rural terminal tree lost its continuous centre column")
eq(Horizon.RURAL_TERMINAL_QUADS, 2,
   "rural terminal is no longer one crossed cut-out")
eq(isolatedRoute13.ruralTerminalQuads, 8,
   "isolated rural rectangle does not own four deduplicated turns")
eq(isolatedRoute13.foregroundQuads,
   isolatedRoute13.canopyFillerQuads
     + isolatedRoute13.ruralTerminalQuads,
   "rural terminal escaped the existing foreground batch")
eq(isolatedRoute13.wallDraws, 1,
   "rural terminal added a wall draw family")
local route13W, route13H = route13.def.width * Horizon.CELL,
                           route13.def.height * Horizon.CELL
local ordinaryCards, terminalCards = 0, 0
for i = 1, #isolatedRoute13.foregroundVertices, 4 do
  local minX, maxX, minZ, maxZ = math.huge, -math.huge,
                                  math.huge, -math.huge
  local minY, maxY, minU, maxU = math.huge, -math.huge,
                                  math.huge, -math.huge
  for j = 0, 3 do
    local v = isolatedRoute13.foregroundVertices[i + j]
    minX, maxX = math.min(minX, v[1]), math.max(maxX, v[1])
    minY, maxY = math.min(minY, v[2]), math.max(maxY, v[2])
    minZ, maxZ = math.min(minZ, v[3]), math.max(maxZ, v[3])
    minU, maxU = math.min(minU, v[4]), math.max(maxU, v[4])
  end
  local width = (maxX - minX) + (maxZ - minZ)
  eq(width, Horizon.NEAR_FILL_CARD_W,
     "ordinary edge bitmap was stretched into a continuous wall")
  local planeX = minX == maxX and minX or nil
  local planeZ = minZ == maxZ and minZ or nil
  if maxY - minY == Horizon.RURAL_TERMINAL_TREE_H then
    terminalCards = terminalCards + 1
    near(minU, (32 + Horizon.RURAL_TERMINAL_TREE_VARIANT * 32)
               / Horizon.FOREGROUND_ATLAS_W, 1e-9,
         "rural terminal sampled a different tree module")
    near(maxU, (32 + (Horizon.RURAL_TERMINAL_TREE_VARIANT + 1) * 32)
               / Horizon.FOREGROUND_ATLAS_W, 1e-9,
         "rural terminal stretched its tree module")
  elseif planeX == -Horizon.NEAR_FILL_FIRST
         or planeX == route13W + Horizon.NEAR_FILL_FIRST
         or planeZ == -Horizon.NEAR_FILL_FIRST
         or planeZ == route13H + Horizon.NEAR_FILL_FIRST then
    ordinaryCards = ordinaryCards + 1
  else
    error("ordinary edge fill did not occupy the first outside cell")
  end
end
eq(ordinaryCards, isolatedRoute13.canopyFillerQuads,
   "rural terminal moved or replaced an ordinary near-edge card")
eq(terminalCards, isolatedRoute13.ruralTerminalQuads,
   "rural terminal diagnostic disagrees with foreground geometry")

-- The user-approved Forest composition owns deliberate crossed/overlapping
-- canopy cards.  The generic near-edge rule must not silently re-layout it.
local legacyForest = Horizon.geometry({
  map=fakeMap("VIRIDIAN_FOREST", 17, 47, "FOREST"), neighbors={}
})[1]
local foundLegacyWidth = false
for i = 1, #legacyForest.foregroundVertices, 4 do
  local minX, maxX, minZ, maxZ = math.huge, -math.huge,
                                  math.huge, -math.huge
  for j = 0, 3 do
    local v = legacyForest.foregroundVertices[i + j]
    minX, maxX = math.min(minX, v[1]), math.max(maxX, v[1])
    minZ, maxZ = math.min(minZ, v[3]), math.max(maxZ, v[3])
  end
  if (maxX - minX) + (maxZ - minZ) == Horizon.CELL + 8 then
    foundLegacyWidth = true
    break
  end
end
eq(foundLegacyWidth, true,
   "Viridian Forest lost its retained overlapping canopy layout")
eq(legacyForest.ruralTerminalQuads, 0,
   "rural terminal treatment leaked into Viridian Forest")
end)()

local joinedParts = Horizon.geometry({ map = route13, neighbors = {
  { map = east, ox = route13.def.width * Horizon.CELL, oy = 0 },
} })
local joined = joinedParts[1]
local seamX = route13.def.width * Horizon.CELL
              + Horizon.OUTDOOR_WALL_DISTANCE
for i = 1, #joined.wallVertices, 4 do
  local a, b = joined.wallVertices[i], joined.wallVertices[i + 1]
  if a[1] == seamX and b[1] == seamX then
    local z = (a[3] + b[3]) / 2
    if z >= 0 and z < route13.def.height * Horizon.CELL then
      error("covered east seam still contains a regional wall")
    end
  end
end
auditOutdoorUnion(joinedParts, "east/west Route 13/14 union")
;(function()
  local count = 0
  for _, built in ipairs(joinedParts) do
    count = count + (built.ruralTerminalQuads or 0)
  end
  eq(count, 8,
     "flush rural owners duplicated or lost the four outer turn covers")
end)()

local northJoined = Horizon.geometry({ map = route13, neighbors = {
  { map = east, ox = 0,
    oy = -east.def.height * Horizon.CELL },
} })
auditOutdoorUnion(northJoined, "north/south Route 13/14 union")
;(function()
  local count = 0
  for _, built in ipairs(northJoined) do
    count = count + (built.ruralTerminalQuads or 0)
  end
  eq(count, 8,
     "north/south rural owners duplicated or lost turn covers")
end)()

-- The production Route 12/13/14 footprint is an offset three-rectangle union:
-- its contour has six convex corners and two concave turns.  Both orthogonal
-- owners can discover a turn, but the shared world key must publish exactly
-- one crossed tree there (two quads), never one per owner.
;(function()
  local route13 = fakeMap("ROUTE_13", 30, 9)
  local route12 = fakeMap("ROUTE_12", 10, 54)
  local route14 = fakeMap("ROUTE_14", 10, 27)
  local parts = Horizon.geometry({
    map = route13,
    neighbors = {
      { map=route12, ox=20 * Horizon.CELL, oy=-54 * Horizon.CELL },
      { map=route14, ox=-10 * Horizon.CELL, oy=0 },
    },
  })
  local count = 0
  for _, built in ipairs(parts) do
    count = count + (built.ruralTerminalQuads or 0)
  end
  eq(count, 16,
     "production Route 12/13/14 contour does not own exactly eight covers")
  auditOutdoorUnion(parts, "production Route 12/13/14 rural union")
end)()

-- Non-rural and open-water families fail closed.  These exact zeros protect
-- the approved Forest composition, coastal cadence and Route 8 landmarks.
;(function()
  for _, id in ipairs({ "VIRIDIAN_CITY", "VIRIDIAN_FOREST",
                        "FUCHSIA_CITY", "ROUTE_19", "ROUTE_8" }) do
    local built = Horizon.geometry({ map=fakeMap(id, 12, 8), neighbors={} })[1]
    if built then
      eq(built.ruralTerminalQuads, 0,
         id .. " inherited rural terminal covers")
    end
  end
end)()

-- Production Kanto connections are often offset rather than flush. Route 3
-- meets Route 4 across a 25-block horizontal offset, creating two concave
-- corners in the union; Route 4 then meets Cerulean four blocks above its own
-- origin. The far contour must clip at the dilated-union intersection instead
-- of crossing and continuing as two 96px spurs.
local route4 = fakeMap("ROUTE_4", 45, 9)
local route3 = fakeMap("ROUTE_3", 35, 9)
local realRoute34 = Horizon.geometry({ map = route4, neighbors = {
  { map = route3, ox = -25 * Horizon.CELL,
    oy = route4.def.height * Horizon.CELL },
} })
auditOutdoorUnion(realRoute34, "real offset Route 4/3 union")

local cerulean = fakeMap("CERULEAN_CITY", 20, 18)
local realRoute4Cerulean = Horizon.geometry({ map = route4, neighbors = {
  { map = cerulean, ox = route4.def.width * Horizon.CELL,
    oy = -4 * Horizon.CELL },
} })
auditOutdoorUnion(realRoute4Cerulean,
                  "real offset Route 4/Cerulean union")

-- Open sea has no wall.  Landmarks remain rare, module-varied billboards and
-- disappear entirely from a covered edge rather than painting over the seam.
eq(Horizon.COASTAL_LANDMARKS_PER_MAP, 1,
   "each maritime map owns at most one distant landmark")

local function landmarkInfo(map, built)
  local spec = Horizon.COASTAL_LANDMARKS[map.id]
  local module = Horizon.COASTAL_MODULES[spec.variant]
  eq(spec.w, module.w, map.id .. " world width diverged from V3 BBox")
  eq(spec.h, module.h, map.id .. " world height diverged from V3 BBox")
  eq(built.coastalQuads, math.ceil(spec.w / Horizon.CELL),
     map.id .. " tessellates one coastal landmark on the curve lattice")
  eq(#built.coastalVertices, built.coastalQuads * 4,
     map.id .. " coastal quad metadata matches its shared mesh vertices")
  local vertex = built.coastalVertices[1]
  local distance = Horizon.BELT + math.floor(Horizon.SEA_DEPTH * 0.55)
  local mapW, mapH = map.def.width * Horizon.CELL,
                     map.def.height * Horizon.CELL
  local edge = vertex[3] == -distance and "north"
               or vertex[3] == mapH + distance and "south"
               or vertex[1] == -distance and "west"
               or vertex[1] == mapW + distance and "east"
  if not edge then error(map.id .. " emitted a landmark off its edge") end
  local horizontal = edge == "north" or edge == "south"
  local function along(v) return horizontal and v[1] or v[3] end
  local startAlong, endAlong = along(vertex), nil
  local previousAlong, previousU = nil, nil
  local strongestCurve = 0.18 / 144
  for i = 1, #built.coastalVertices, 4 do
    local a, b, c, d = built.coastalVertices[i],
                        built.coastalVertices[i + 1],
                        built.coastalVertices[i + 2],
                        built.coastalVertices[i + 3]
    local span = math.abs(along(b) - along(a))
    if span > Horizon.CELL then
      error(map.id .. " coastal segment escaped the 32px curve lattice: "
            .. tostring(span))
    end
    local curveError = strongestCurve * span * span / 4
    if curveError > 0.65 then
      error(map.id .. " coastal segment exceeded the WorldCurve error bound: "
            .. tostring(curveError))
    end
    if previousAlong ~= nil then
      near(along(a), previousAlong, 1e-12,
           map.id .. " coastal segment geometry is discontinuous")
      near(a[4], previousU, 1e-12,
           map.id .. " coastal segment UV is discontinuous")
    end
    eq(a[5], (module.y + module.h) / 128,
       map.id .. " coastal segment starts on the shared waterline")
    eq(b[5], (module.y + module.h) / 128,
       map.id .. " coastal segment ends on the shared waterline")
    eq(c[5], module.y / 128,
       map.id .. " coastal segment top escaped its V3 alpha BBox")
    eq(d[5], module.y / 128,
       map.id .. " coastal segment top escaped its V3 alpha BBox")
    near(span, math.abs(b[4] - a[4]) * 512, 1e-9,
         map.id .. " coastal horizontal texels are not 1:1 world pixels")
    previousAlong, previousU = along(b), b[4]
    endAlong = along(b)
  end
  local width = math.abs(endAlong - startAlong)
  local height = math.abs(built.coastalVertices[3][2]
                          - built.coastalVertices[2][2])
  local sourceHeight = math.abs(built.coastalVertices[3][5]
                                - built.coastalVertices[2][5]) * 128
  near(height, sourceHeight, 1e-9,
       map.id .. " coastal vertical texels are not 1:1 world pixels")
  return edge, math.floor(vertex[4] * 4 + 1e-6), width, height,
         vertex[5]
end

local southMaps = {
  ROUTE_19 = fakeMap("ROUTE_19", 10, 27),
  ROUTE_20 = fakeMap("ROUTE_20", 50, 9),
  ROUTE_21 = fakeMap("ROUTE_21", 10, 45),
  CINNABAR_ISLAND = fakeMap("CINNABAR_ISLAND", 10, 9),
}
local southVariants = {}
for id, map in pairs(southMaps) do
  local built = Horizon.geometry({ map = map, neighbors = {} })[1]
  eq(#built.wallVertices, 0, id .. " keeps the ocean horizon wall-free")
  local edge, variant, width, height, bottomV = landmarkInfo(map, built)
  local spec = Horizon.COASTAL_LANDMARKS[id]
  eq(edge, spec.edge, id .. " uses its fixed free edge")
  eq(variant, spec.variant, id .. " uses its fixed atlas module")
  eq(width, spec.w, id .. " keeps its authored distant width")
  eq(height, spec.h, id .. " keeps its authored distant height")
  eq(bottomV, Horizon.COASTAL_LANDMARK_V_BOTTOM,
     id .. " crops the transparent foot pad onto sea level")
  if southVariants[variant] then
    error(id .. " duplicates another South Sea atlas module")
  end
  southVariants[variant] = true
end
local bowNoop = fakeMap("SS_ANNE_BOW", 10, 7, "SHIP_PORT")
local bowNoopBuilt = Horizon.geometry({ map=bowNoop, neighbors={} })[1]
eq(Horizon.geometry({
  map=southMaps.ROUTE_20, neighbors={},
})[1].quads, 2213, "Route 20 changed under the coastal cadence")
eq(Horizon.geometry({
  map=southMaps.CINNABAR_ISLAND, neighbors={},
})[1].quads, 1173, "Cinnabar changed under the coastal cadence")
eq(bowNoopBuilt.quads, 1121,
   "SS Anne Bow changed under the coastal cadence")
eq(bowNoopBuilt.seaQuads, 1118,
   "SS Anne Bow sea budget changed under the coastal cadence")
local variantCount = 0
for _ in pairs(southVariants) do variantCount = variantCount + 1 end
eq(variantCount, 4,
   "the complete South Sea uses all four modules exactly once")

-- The real South-Sea connection layout can coexist in one two-hop survey:
-- Cinnabar -> Route 20 -> Route 19 and Cinnabar -> Route 21. The four owners
-- remain sparse and module-unique in that shared geometry.
local c = southMaps.CINNABAR_ISLAND
local r20, r19, r21 = southMaps.ROUTE_20, southMaps.ROUTE_19,
                       southMaps.ROUTE_21
local fullSouthState = { map = c, neighbors = {
  { map=r20, ox=c.def.width * Horizon.CELL, oy=0 },
  { map=r19, ox=(c.def.width + r20.def.width) * Horizon.CELL,
               oy=-18 * Horizon.CELL },
  { map=r21, ox=0, oy=-r21.def.height * Horizon.CELL },
} }
local fullSouth = Horizon.geometry(fullSouthState)
local unionVariants, unionLandmarks, unionQuads = {}, 0, 0
for _, part in ipairs(fullSouth) do
  if #part.coastalVertices > 0 then
    local variant = math.floor(part.coastalVertices[1][4] * 4 + 1e-6)
    if unionVariants[variant] then
      error("full South Sea union repeats coastal module " .. variant)
    end
    unionVariants[variant] = true
    unionLandmarks = unionLandmarks + 1
    unionQuads = unionQuads + part.coastalQuads
  end
end
eq(unionLandmarks, 4, "full South Sea union remains capped at four motifs")
eq(unionQuads, 12,
   "four South Sea motifs stay in one bounded three-segment mesh each")

-- The exact generated land/sea pairs and Dock get a crisp high->low->open
-- cadence. It only reclassifies synthetic Horizon panels; the maps' blocks,
-- collision, warps and real Structure references must remain byte-identical.
local function stableSnapshot(value, seen)
  local kind = type(value)
  if kind ~= "table" then return kind .. ":" .. tostring(value) end
  seen = seen or {}
  if seen[value] then error("snapshot contract encountered a cycle") end
  seen[value] = true
  local keys = {}
  for key in pairs(value) do keys[#keys + 1] = key end
  table.sort(keys, function(a, b)
    return type(a) .. ":" .. tostring(a) < type(b) .. ":" .. tostring(b)
  end)
  local parts = { "{" }
  for _, key in ipairs(keys) do
    parts[#parts + 1] = stableSnapshot(key, seen)
    parts[#parts + 1] = "="
    parts[#parts + 1] = stableSnapshot(value[key], seen)
    parts[#parts + 1] = ";"
  end
  parts[#parts + 1] = "}"
  seen[value] = nil
  return table.concat(parts)
end

local function mutationGuard(map, ordinal)
  map.def.blocks = { ordinal, ordinal + 1, ordinal + 2 }
  map.def.warps = {
    { x=ordinal, y=ordinal + 1, destMap="UNCHANGED", destWarp=ordinal },
  }
  map.def.collision = { ordinal + 3, ordinal + 4 }
  map.collision = { [ordinal] = true, [ordinal + 1] = false }
  map.structures = { { id="REAL_STRUCTURE_" .. ordinal, solid=true } }
  return stableSnapshot({
    def=map.def, collision=map.collision, structures=map.structures,
    tilesetBlocks=map.tileset.blocks,
  })
end

local function assertMutationGuard(map, expected, label)
  eq(stableSnapshot({
    def=map.def, collision=map.collision, structures=map.structures,
    tilesetBlocks=map.tileset.blocks,
  }), expected, label .. " changed gameplay/map data")
end

local function geometryBudget(built)
  return {
    wall=#built.wallVertices / 4,
    ground=#built.groundVertices / 4,
    sea=built.seaQuads,
    foreground=#built.foregroundVertices / 4,
    coastal=built.coastalQuads,
    total=built.quads,
  }
end

local function unionBudget(parts)
  local out = { wall=0, ground=0, sea=0, foreground=0, coastal=0, total=0 }
  for _, built in ipairs(parts) do
    local one = geometryBudget(built)
    for key, value in pairs(one) do out[key] = out[key] + value end
  end
  return out
end

local function assertBudget(actual, expected, label)
  for _, key in ipairs({ "wall", "ground", "sea", "foreground",
                         "coastal", "total" }) do
    if actual[key] ~= expected[key] then
      error(string.format(
        "%s budget: expected %d/%d/%d/%d/%d/%d, got %d/%d/%d/%d/%d/%d",
        label,
        expected.wall, expected.ground, expected.sea, expected.foreground,
        expected.coastal, expected.total,
        actual.wall, actual.ground, actual.sea, actual.foreground,
        actual.coastal, actual.total))
    end
  end
end

local function nativeLowPanelCount(built, label)
  local count = 0
  for i = 1, #built.wallVertices, 4 do
    local minU, maxU, minV, maxV = math.huge, -math.huge,
                                      math.huge, -math.huge
    local minX, maxX, minY, maxY, minZ, maxZ =
      math.huge, -math.huge, math.huge, -math.huge, math.huge, -math.huge
    for j = 0, 3 do
      local vertex = built.wallVertices[i + j]
      minX, maxX = math.min(minX, vertex[1]), math.max(maxX, vertex[1])
      minY, maxY = math.min(minY, vertex[2]), math.max(maxY, vertex[2])
      minZ, maxZ = math.min(minZ, vertex[3]), math.max(maxZ, vertex[3])
      minU, maxU = math.min(minU, vertex[4]), math.max(maxU, vertex[4])
      minV, maxV = math.min(minV, vertex[5]), math.max(maxV, vertex[5])
    end
    if math.abs(minU * Horizon.REGIONAL_STRIP_W - lowSource.atlasX) < 1e-9
       and math.abs(maxU * Horizon.REGIONAL_STRIP_W
                    - lowSource.atlasX - lowSource.w) < 1e-9 then
      count = count + 1
      near((maxU - minU) * Horizon.REGIONAL_STRIP_W, Horizon.CELL, 1e-9,
           label .. " low panel stretched horizontally")
      near((maxV - minV) * Horizon.REGIONAL_TEXTURE_H, lowSource.h, 1e-9,
           label .. " low panel stretched vertically")
      eq(maxY - minY, lowSource.h,
         label .. " low panel world height is not native")
      eq((maxX - minX) + (maxZ - minZ), Horizon.CELL,
         label .. " low panel world width is not native")
    end
  end
  return count
end

local fuchsiaFoot = fakeMap("FUCHSIA_CITY", 20, 18)
local route19Foot = fakeMap("ROUTE_19", 10, 27)
fuchsiaFoot.def.connections = {
  east = { map="ROUTE_15", offset=4 },
  south = { map="ROUTE_19", offset=5 },
  west = { map="ROUTE_18", offset=4 },
}
route19Foot.def.connections = {
  north = { map="FUCHSIA_CITY", offset=-5 },
  west = { map="ROUTE_20", offset=18 },
}
local fuchsiaMapSnapshot = mutationGuard(fuchsiaFoot, 11)
local route19MapSnapshot = mutationGuard(route19Foot, 21)
local fuchsiaFootState = { map=fuchsiaFoot, neighbors={
  { map=route19Foot, ox=5 * Horizon.CELL,
    oy=18 * Horizon.CELL },
} }
local fuchsiaFootParts = Horizon.geometry(fuchsiaFootState)
local fuchsiaFootBuilt = fuchsiaFootParts[1]
assertBudget(geometryBudget(fuchsiaFootBuilt),
  { wall=68, ground=658, sea=398, foreground=57, coastal=0, total=1181 },
  "Fuchsia cadence owner")
assertBudget(geometryBudget(fuchsiaFootParts[2]),
  { wall=0, ground=0, sea=928, foreground=0, coastal=3, total=931 },
  "Route 19 cadence owner")
assertBudget(unionBudget(fuchsiaFootParts),
  { wall=68, ground=658, sea=1326, foreground=57, coastal=3, total=2112 },
  "Fuchsia/Route 19 cadence union")
eq(nativeLowPanelCount(fuchsiaFootBuilt, "Fuchsia"), 4,
   "Fuchsia did not use exactly one low panel on each turn arm")
eq(fuchsiaFootBuilt.wallDraws, 1,
   "Fuchsia cadence added a second wall draw family")
eq(fuchsiaFootBuilt.coastalWaterFootQuads, 8,
   "Fuchsia exact free-corner water-foot budget")
eq(fuchsiaFootBuilt.seaQuads, 398,
   "Fuchsia water feet escaped the existing sea batch")

local fuchsiaFallback = fakeMap("FUCHSIA_CITY", 20, 18)
local route19Fallback = fakeMap("ROUTE_19", 10, 27)
fuchsiaFallback.def.connections = {
  east = { map="ROUTE_15", offset=4 },
  south = { map="ROUTE_19", offset=5 },
  west = { map="ROUTE_18", offset=4 },
}
route19Fallback.def.connections = {
  north = { map="FUCHSIA_CITY", offset=-4 },
  west = { map="ROUTE_20", offset=18 },
}
local fuchsiaFallbackState = { map=fuchsiaFallback, neighbors={
  { map=route19Fallback, ox=5 * Horizon.CELL,
    oy=18 * Horizon.CELL },
} }
local fuchsiaFallbackParts = Horizon.geometry(fuchsiaFallbackState)
local fuchsiaFallbackBuilt = fuchsiaFallbackParts[1]
assertBudget(geometryBudget(fuchsiaFallbackBuilt),
  { wall=84, ground=864, sea=0, foreground=57, coastal=0, total=1005 },
  "Fuchsia fail-closed owner")
assertBudget(geometryBudget(fuchsiaFallbackParts[2]),
  { wall=0, ground=0, sea=1170, foreground=0, coastal=3, total=1173 },
  "Route 19 fail-closed owner")
assertBudget(unionBudget(fuchsiaFallbackParts),
  { wall=84, ground=864, sea=1170, foreground=57, coastal=3, total=2178 },
  "Fuchsia/Route 19 fail-closed union")
eq(fuchsiaFallbackBuilt.coastalWaterFootQuads, 0,
   "edited reciprocal Route 19 seam inherited water feet")
eq(fuchsiaFallbackBuilt.seaQuads, 0,
   "edited Fuchsia seam moved ground into the sea batch")
eq(unionBudget(fuchsiaFootParts).total
   - unionBudget(fuchsiaFallbackParts).total, -66,
   "Fuchsia cadence union quad delta")
assertMutationGuard(fuchsiaFoot, fuchsiaMapSnapshot, "Fuchsia cadence")
assertMutationGuard(route19Foot, route19MapSnapshot, "Route 19 cadence")

local fuchsiaExtra = fakeMap("FUCHSIA_CITY", 20, 18)
local route19Extra = fakeMap("ROUTE_19", 10, 27)
fuchsiaExtra.def.connections = {
  east = { map="ROUTE_15", offset=4 },
  south = { map="ROUTE_19", offset=5 },
  west = { map="ROUTE_18", offset=4 },
  north = { map="UNEXPECTED_CONNECTION", offset=0 },
}
route19Extra.def.connections = {
  north = { map="FUCHSIA_CITY", offset=-5 },
  west = { map="ROUTE_20", offset=18 },
}
local fuchsiaExtraBuilt = Horizon.geometry({ map=fuchsiaExtra, neighbors={
  { map=route19Extra, ox=5 * Horizon.CELL, oy=18 * Horizon.CELL },
} })[1]
eq(fuchsiaExtraBuilt.coastalWaterFootQuads, 0,
   "unexpected Fuchsia topology enabled a partial cadence")
eq(fuchsiaExtraBuilt.quads, 1005,
   "unexpected Fuchsia topology did not fail closed")

local palletFoot = fakeMap("PALLET_TOWN", 10, 9)
local route21Foot = fakeMap("ROUTE_21", 10, 45)
palletFoot.def.connections = {
  north = { map="ROUTE_1", offset=0 },
  south = { map="ROUTE_21", offset=0 },
}
route21Foot.def.connections = {
  north = { map="PALLET_TOWN", offset=0 },
  south = { map="CINNABAR_ISLAND", offset=0 },
}
local palletMapSnapshot = mutationGuard(palletFoot, 31)
local route21MapSnapshot = mutationGuard(route21Foot, 41)
local palletFootState = { map=palletFoot, neighbors={
  { map=route21Foot, ox=0, oy=9 * Horizon.CELL },
} }
local palletFootParts = Horizon.geometry(palletFootState)
local palletFootBuilt = palletFootParts[1]
assertBudget(geometryBudget(palletFootBuilt),
  { wall=26, ground=212, sea=42, foreground=0, coastal=0, total=280 },
  "Pallet cadence owner")
assertBudget(geometryBudget(palletFootParts[2]),
  { wall=0, ground=0, sea=1638, foreground=0, coastal=3, total=1641 },
  "Route 21 cadence owner")
assertBudget(unionBudget(palletFootParts),
  { wall=26, ground=212, sea=1680, foreground=0, coastal=3, total=1921 },
  "Pallet/Route 21 cadence union")
eq(nativeLowPanelCount(palletFootBuilt, "Pallet"), 2,
   "Pallet did not use one low panel on each Route 21 turn")
eq(palletFootBuilt.wallDraws, 1,
   "Pallet cadence added a second wall draw family")
eq(palletFootBuilt.coastalWaterFootQuads, 16,
   "Pallet exact side-corner water-foot budget")
eq(palletFootBuilt.seaQuads, 42,
   "Pallet water feet escaped the existing sea batch")

local palletFallback = fakeMap("PALLET_TOWN", 10, 9)
local route21Fallback = fakeMap("ROUTE_21", 10, 45)
palletFallback.def.connections = {
  north = { map="ROUTE_1", offset=0 },
  south = { map="ROUTE_21", offset=0 },
}
route21Fallback.def.connections = {
  north = { map="PALLET_TOWN", offset=1 },
  south = { map="CINNABAR_ISLAND", offset=0 },
}
local palletFallbackState = { map=palletFallback, neighbors={
  { map=route21Fallback, ox=0, oy=9 * Horizon.CELL },
} }
local palletFallbackParts = Horizon.geometry(palletFallbackState)
local palletFallbackBuilt = palletFallbackParts[1]
assertBudget(geometryBudget(palletFallbackBuilt),
  { wall=28, ground=240, sea=0, foreground=0, coastal=0, total=268 },
  "Pallet fail-closed owner")
assertBudget(unionBudget(palletFallbackParts),
  { wall=28, ground=240, sea=1638, foreground=0, coastal=3, total=1909 },
  "Pallet/Route 21 fail-closed union")
eq(palletFallbackBuilt.coastalWaterFootQuads, 0,
   "edited reciprocal Route 21 seam inherited Pallet water feet")
eq(unionBudget(palletFootParts).total
   - unionBudget(palletFallbackParts).total, 12,
   "Pallet cadence union quad delta")
eq(fuchsiaFootBuilt.coastalWaterFootQuads
   + palletFootBuilt.coastalWaterFootQuads, 24,
   "South Sea land-foot global quad budget")
for _, built in ipairs({ fuchsiaFootBuilt, palletFootBuilt }) do
  for _, vertex in ipairs(built.seaVertices) do
    eq(vertex[1] % Horizon.CELL, 0,
       "water foot escaped the native world-x lattice")
    eq(vertex[3] % Horizon.CELL, 0,
       "water foot escaped the native world-z lattice")
  end
end
assertMutationGuard(palletFoot, palletMapSnapshot, "Pallet cadence")
assertMutationGuard(route21Foot, route21MapSnapshot, "Route 21 cadence")

local dockCadence = fakeMap("VERMILION_DOCK", 14, 6, "SHIP_PORT")
dockCadence.def.outdoor = nil
dockCadence.def.connections = {}
local dockMapSnapshot = mutationGuard(dockCadence, 51)
local dockCadenceState = { map=dockCadence, neighbors={} }
local dockCadenceBuilt = Horizon.geometry(dockCadenceState)[1]
assertBudget(geometryBudget(dockCadenceBuilt),
  { wall=24, ground=216, sea=884, foreground=0, coastal=3, total=1127 },
  "Dock cadence owner")
eq(nativeLowPanelCount(dockCadenceBuilt, "Dock"), 4,
   "Dock did not use one low panel at each band end")
eq(dockCadenceBuilt.wallDraws, 1,
   "Dock cadence added a second wall draw family")
assertMutationGuard(dockCadence, dockMapSnapshot, "Dock cadence")

local dockFallback = fakeMap("VERMILION_DOCK", 14, 6, "SHIP_PORT")
dockFallback.def.outdoor = nil
dockFallback.def.connections = {
  north = { map="UNEXPECTED_CONNECTION", offset=0 },
}
local dockFallbackState = { map=dockFallback, neighbors={} }
local dockFallbackBuilt = Horizon.geometry(dockFallbackState)[1]
assertBudget(geometryBudget(dockFallbackBuilt),
  { wall=40, ground=324, sea=832, foreground=0, coastal=3, total=1199 },
  "Dock fail-closed owner")
eq(dockCadenceBuilt.quads - dockFallbackBuilt.quads, -72,
   "Dock cadence quad delta")

-- Short Dock/Bow edges bypass the old hash lottery and keep one centred
-- three-panel placement each.
for _, id in ipairs({ "VERMILION_DOCK", "SS_ANNE_BOW" }) do
  local map = fakeMap(id, 4, 3, "SHIP_PORT")
  local built = Horizon.geometry({ map=map, neighbors={} })[1]
  local edge, variant, width, height, bottomV = landmarkInfo(map, built)
  eq(edge, Horizon.COASTAL_LANDMARKS[id].edge,
     id .. " short-edge fallback uses its fixed edge")
  eq(variant, Horizon.COASTAL_LANDMARKS[id].variant,
     id .. " short-edge fallback uses its fixed module")
  eq(width, Horizon.COASTAL_LANDMARKS[id].w,
     id .. " short-edge fallback keeps its bounded width")
  eq(height, Horizon.COASTAL_LANDMARKS[id].h,
     id .. " short-edge fallback keeps its bounded height")
  eq(bottomV, Horizon.COASTAL_LANDMARK_V_BOTTOM,
     id .. " short-edge landmark is water-grounded")
end

-- Covering Route 20's selected south edge hides the motif rather than moving
-- it to another edge or changing its atlas module.
local southCover = fakeMap("SOUTH_COVER", 50, 9)
local route20Covered = Horizon.geometry({ map=r20, neighbors={
  { map=southCover, ox=0, oy=r20.def.height * Horizon.CELL },
} })[1]
eq(route20Covered.coastalQuads, 0,
   "covered Route 20 landmark is hidden without reassignment")
eq(#route20Covered.coastalVertices, 0,
   "covered Route 20 landmark left no hidden mesh segments")

-- Runtime image contract: native atlas dimensions, no scaling/mips, one-time
-- decode, and all-or-nothing rejection of a malformed regional source.
local canvases, sources, activeCanvas = {}, {}, nil
local dimensions = {
  ["forest_edge_a.compact.png"] = { 128, 96 },
  ["forest_edge_b.compact.png"] = { 128, 96 },
  ["forest_edge_c.compact.png"] = { 128, 96 },
  ["viridian_town.compact.png"] = { 512, 96 },
  ["metropolis.compact.png"] = { 512, 96 },
  ["route8_horizon.compact.png"] = { 960, 96 },
  ["route8_midground.compact.png"] = { 256, 64 },
  ["viridian_forest_gate.compact.png"] = { 64, 40 },
  ["rural_edge.compact.png"] = { 512, 128 },
  ["harbor_edge.compact.png"] = { 512, 128 },
  ["mini_trees.compact.png"] = { 128, 64 },
  ["coastal_landmarks_v3.compact.png"] = { 512, 128 },
  ["mountain_panorama.compact.png"] = { 2048, 128 },
  ["fuji_panorama.compact.png"] = { 128, 43 },
}
local graphics = {}
function graphics.newCanvas(w, h, settings)
  local canvas = { w=w, h=h, settings=settings, draws={} }
  function canvas:setFilter(min, mag) self.filter = { min, mag } end
  function canvas:setMipmapFilter(mode) self.mipmap = mode or false end
  function canvas:setWrap(x, y) self.wrap = { x, y } end
  function canvas:release() self.released = true end
  canvases[#canvases + 1] = canvas
  return canvas
end
function graphics.newImage(path, settings)
  local filename = path:match("([^/]+)$")
  local d = dimensions[filename]
  if not d then error("unknown image " .. path) end
  local image = { path=path, w=d[1], h=d[2], settings=settings }
  function image:getDimensions() return self.w, self.h end
  function image:setFilter(min, mag) self.filter = { min, mag } end
  function image:setMipmapFilter(mode) self.mipmap = mode or false end
  function image:release() self.released = true end
  sources[#sources + 1] = image
  return image
end
function graphics.push() end
function graphics.pop() end
function graphics.origin() end
function graphics.clear() end
function graphics.setColor() end
function graphics.setBlendMode() end
function graphics.setCanvas(canvas) activeCanvas = canvas end
function graphics.rectangle() end
function graphics.draw(image, x, y, rotation, sx, sy)
  activeCanvas.draws[#activeCanvas.draws + 1] = {
    image=image, x=x or 0, y=y or 0, sx=sx or 1, sy=sy or 1,
  }
end
love = { graphics = graphics }

Horizon.invalidate()
eq(Horizon.prewarm(route13), true, "valid regional atlas prewarms")
eq(canvases[1].w, Horizon.REGIONAL_STRIP_W, "regional atlas native width")
eq(canvases[1].h, Horizon.REGIONAL_TEXTURE_H, "regional atlas native height")
eq(canvases[1].settings.mipmaps, "none", "regional atlas has no mipmaps")
eq(canvases[1].filter[1], "nearest", "regional atlas stays nearest")
for _, source in ipairs(sources) do
  if source.path:find("scenery", 1, true)
     and not source.path:find("coastal_landmarks", 1, true)
     and not source.released then
    error(source.path .. " was retained after its one-time bake")
  end
end
local sourceCount = #sources
eq(Horizon.prewarm(route13), true, "regional prewarm cache is reusable")
eq(#sources, sourceCount, "prewarm cache performs no second decode")

-- Three curve-safe pieces are still one runtime mesh/draw. Drive the real
-- cooperative builder far enough to finish a short Dock scene and count its
-- draw parts; a refactor that calls addPart per segment would fail here even
-- though the headless geometry remains visually identical.
local createdMeshes = {}
cache.Voxel3D.newMesh = function(vertices, indices)
  local mesh = { vertices=vertices, indices=indices }
  function mesh:release() self.released = true end
  createdMeshes[#createdMeshes + 1] = mesh
  return mesh
end
local runtimeDock = fakeMap("VERMILION_DOCK", 4, 3, "SHIP_PORT")
local runtimeState = { map=runtimeDock, neighbors={} }
local rims, runtimeReady
for _ = 1, 10000 do
  rims, runtimeReady = Horizon.meshes(runtimeState)
  if runtimeReady then break end
end
eq(runtimeReady, true, "coastal runtime mesh build did not complete")
local coastalDraws, coastalMesh = 0, nil
for _, rim in ipairs(rims) do
  if rim.kind == "coastal" then
    coastalDraws, coastalMesh = coastalDraws + 1, rim.mesh
  end
end
eq(coastalDraws, 1, "segmented coastal landmark added more than one draw")
local runtimeBuilt = Horizon.geometry(runtimeState)[1]
eq(#coastalMesh.vertices, runtimeBuilt.coastalQuads * 4,
   "one coastal runtime mesh did not contain every curve-safe segment")

-- The cadence changes only quad allocation between the existing regional,
-- ground and sea batches.  It adds no runtime part/draw and no image; exact
-- geometry deltas are pinned above instead of pretending buffer sizes match.
local function finishRims(state, message)
  local built, ready
  for _ = 1, 10000 do
    built, ready = Horizon.meshes(state)
    if ready then break end
  end
  eq(ready, true, message .. " did not complete")
  return built
end
local function rimBudget(rims)
  local draws, vertices, indices, water = 0, 0, 0, 0
  for _, rim in ipairs(rims) do
    if rim.mesh then
      draws = draws + 1
      vertices = vertices + #rim.mesh.vertices
      indices = indices + #rim.mesh.indices
    end
    if rim.kind == "water" then water = water + 1 end
  end
  return draws, vertices, indices, water
end
Horizon.invalidate()
local exactFootRims = finishRims(fuchsiaFootState, "Fuchsia cadence runtime")
Horizon.invalidate()
local fallbackFootRims = finishRims(fuchsiaFallbackState,
                                    "Fuchsia fallback runtime")
local exactDraws, _, _, exactWater = rimBudget(exactFootRims)
local fallbackDraws, _, _, fallbackWater = rimBudget(fallbackFootRims)
eq(exactDraws - fallbackDraws, 0,
   "Fuchsia cadence changed runtime draw count")
eq(exactWater, 1, "Fuchsia/Route 19 water did not aggregate to one draw")
eq(fallbackWater, 1,
   "fallback Fuchsia/Route 19 water did not aggregate to one draw")

Horizon.invalidate()
local exactDockRims = finishRims(dockCadenceState, "Dock cadence runtime")
Horizon.invalidate()
local fallbackDockRims = finishRims(dockFallbackState,
                                    "Dock fallback runtime")
local exactDockDraws = rimBudget(exactDockRims)
local fallbackDockDraws = rimBudget(fallbackDockRims)
eq(exactDockDraws - fallbackDockDraws, 0,
   "Dock cadence changed runtime draw count")

-- The complete southern union previously published one reflective cap mesh
-- per map.  Preserve the exact translated quad/UV/index stream while merging
-- all four owners into one water draw and one mesh allocation.
local expectedSeaVertices, expectedSeaIndices = {}, {}
local seaOwners = 0
for _, part in ipairs(fullSouth) do
  if #part.seaVertices > 0 then seaOwners = seaOwners + 1 end
  local base = #expectedSeaVertices
  for _, vertex in ipairs(part.seaVertices) do
    expectedSeaVertices[#expectedSeaVertices + 1] = {
      vertex[1] + part.ox, vertex[2], vertex[3] + part.oy,
      vertex[4], vertex[5], vertex[6],
    }
  end
  for _, index in ipairs(part.seaIndices) do
    expectedSeaIndices[#expectedSeaIndices + 1] = base + index
  end
end
eq(seaOwners, 4, "South Sea geometry no longer has four water owners")
local southRims, southReady
for _ = 1, 10000 do
  southRims, southReady = Horizon.meshes(fullSouthState)
  if southReady then break end
end
eq(southReady, true, "South Sea runtime mesh build did not complete")
local seaDraws, seaMesh = 0, nil
for _, rim in ipairs(southRims) do
  if rim.kind == "water" then
    seaDraws, seaMesh = seaDraws + 1, rim.mesh
    eq(rim.ox, 0, "aggregated sea mesh retained a map-local x offset")
    eq(rim.oy, 0, "aggregated sea mesh retained a map-local y offset")
  end
end
eq(seaDraws, 1, "four-map South Sea did not aggregate 4 water draws to 1")
eq(#seaMesh.vertices, #expectedSeaVertices,
   "aggregated sea mesh changed vertex budget")
eq(#seaMesh.indices, #expectedSeaIndices,
   "aggregated sea mesh changed index budget")
for i, expectedVertex in ipairs(expectedSeaVertices) do
  local actual = seaMesh.vertices[i]
  for field = 1, 6 do
    eq(actual[field], expectedVertex[field],
       "aggregated sea vertex/UV/shade changed")
  end
end
for i, expectedIndex in ipairs(expectedSeaIndices) do
  eq(seaMesh.indices[i], expectedIndex, "aggregated sea index changed")
end

-- Both cold endpoint proxies aggregate into exactly one atlas-backed runtime
-- draw and retain no duplicate texture.  The warm three-map key contains no
-- such part at all, so promotion cannot leave a hidden z-fighting mesh.
local coldRims, coldReady
for _ = 1, 10000 do
  coldRims, coldReady = Horizon.meshes({ map=flankedRoute8, neighbors={} })
  if coldReady then break end
end
eq(coldReady, true, "cold Route 8 runtime mesh build did not complete")
local coldPathDraws, coldPathMesh = 0, nil
for _, rim in ipairs(coldRims) do
  if rim.kind == "route8-seam-path" then
    coldPathDraws, coldPathMesh = coldPathDraws + 1, rim
  end
end
eq(coldPathDraws, 1,
   "east/west cold proxies escaped their one terrain-atlas draw")
eq(coldPathMesh.textureMap, flankedRoute8,
   "cold path draw lost its live Route 8 terrain atlas owner")
eq(coldPathMesh.texture, nil,
   "cold path draw retained a duplicate texture")
eq(#coldPathMesh.mesh.vertices, 96 * 4,
   "cold runtime path mesh lost its exact east+west quad budget")

local warmState = { map=flankedRoute8, neighbors={
  { map=saffron, ox=-saffron.def.width * Horizon.CELL,
    oy=-4 * Horizon.CELL },
  { map=lavender, ox=flankedRoute8.def.width * Horizon.CELL, oy=0 },
} }
local warmRims, warmReady
for _ = 1, 10000 do
  warmRims, warmReady = Horizon.meshes(warmState)
  if warmReady then break end
end
eq(warmReady, true, "warm Route 8 runtime mesh build did not complete")
local warmPathDraws = 0
for _, rim in ipairs(warmRims) do
  if rim.kind == "route8-seam-path" then
    warmPathDraws = warmPathDraws + 1
  end
end
eq(warmPathDraws, 0,
   "warm Route 8 runtime key retained a cold path draw")

Horizon.invalidate()
canvases, sources, activeCanvas = {}, {}, nil
dimensions["rural_edge.compact.png"] = { 511, 128 }
eq(Horizon.prewarm(route13), false, "wrong rural dimensions fail closed")
eq(Horizon.assetStats().rejected, 1, "dimension rejection is counted")
local rejectedSourceCount = #sources
eq(Horizon.prewarm(route13), false,
   "cached malformed regional atlas remains failed closed")
eq(#sources, rejectedSourceCount,
   "malformed regional source is not decoded again per frame")
local rejectedReleased = false
for _, source in ipairs(sources) do
  if source.path:find("rural_edge", 1, true) and source.released then
    rejectedReleased = true
  end
end
eq(rejectedReleased, true, "rejected regional source is released")

-- Coastal V3 has no implicit V2/procedural substitution. A malformed package
-- must block publication of the landmark-bearing horizon, release the source
-- immediately and cache the rejection instead of retrying every frame.
Horizon.invalidate()
Horizon._resetAssetStats()
canvases, sources, activeCanvas = {}, {}, nil
dimensions["rural_edge.compact.png"] = { 512, 128 }
dimensions["coastal_landmarks_v3.compact.png"] = { 511, 128 }
eq(Horizon.prewarm(runtimeDock), false,
   "wrong coastal V3 dimensions fail closed")
eq(Horizon.assetStats().rejected, 1,
   "malformed coastal V3 rejection is counted")
local coastalRejectedSourceCount = #sources
eq(Horizon.prewarm(runtimeDock), false,
   "cached malformed coastal V3 remains failed closed")
eq(#sources, coastalRejectedSourceCount,
   "malformed coastal V3 is not decoded again per frame")
local coastalRejectedReleased = false
for _, source in ipairs(sources) do
  if source.path:find("coastal_landmarks_v3", 1, true)
     and source.released then
    coastalRejectedReleased = true
  end
end
eq(coastalRejectedReleased, true,
   "rejected coastal V3 source is released")

print("regional horizon profiles: ok")
