local stored = { sky = "full", clouds = "on", skyEvents = "full", scenery = "full",
                 weather = "clear" }
local cache = {}
local meshBuilds = 0

local V = {
  path = ".",
  mod = {
    id = "VOXEL_ASCENDANT",
    options = { get = function(_, key) return stored[key] end },
  },
}

function V.require(name)
  if cache[name] then return cache[name] end
  if name == "ModSetting" then
    cache[name] = assert(loadfile("lib/ModSetting.lua"))(V)
  elseif name == "DayNight" then
    cache[name] = {
      palette = function()
        return { { 240, 248, 255 }, { 144, 200, 240 },
                 { 64, 120, 192 }, { 16, 40, 80 } }
      end,
      time = function() return 900 end,
      mix = function() return { night = 1 } end,
    }
  elseif name == "Voxel3D" then
    cache[name] = {
      FACE_SHADE = { 0.84, 0.72, 1, 0.55, 0.90, 0.68 },
      newMesh = function()
        meshBuilds = meshBuilds + 1
        return { release = function(self) self.released = true end }
      end,
      pushQuad = function(indices, n)
        local b = n * 4
        for _, i in ipairs({ 1, 2, 3, 1, 3, 4 }) do
          indices[#indices + 1] = b + i
        end
      end,
    }
  elseif name == "SkyEvents" then
    cache[name] = assert(loadfile("lib/SkyEvents.lua"))(V)
  else
    cache[name] = {}
  end
  return cache[name]
end

package.preload["src.render.PaletteFX"] = function()
  return { effectiveColors = function(p) return p end }
end

local TileRenderer = {
  voidFill = "trees",
  borderBlockFor = function() return 0 end,
}
package.preload["src.render.TileRenderer"] = function() return TileRenderer end

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected "
          .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local Sky = assert(loadfile("lib/Sky.lua"))(V)
eq(Sky.setting.key, "sky", "sky control has a persisted option")
eq(Sky.cloudSetting.key, "clouds", "clouds have an independent option")
eq(Sky.mode(), "full", "full banded sky is the default")
local dressed = Sky.dress({ 0, 0, 0, 1 })
eq(type(dressed.bands), "table", "FULL attaches the band palette")
eq(#dressed.bands, Sky.GRADIENT_BANDS,
   "FULL uses the fine fixed-cost gradient instead of broad key stripes")
eq(Sky.GRADIENT_RGBA_BYTES, 384,
   "FULL gradient remains a negligible 96x1 RGBA8 allocation")

Sky.setting:sync("flat")
local flat = Sky.dress({ 0.1, 0.2, 0.3, 1 })
eq(flat.bands, nil, "FLAT avoids the banded pass")
eq(Sky.ramp(), nil, "FLAT avoids the reflected band texture")

Sky.setting:sync("off")
eq(Sky.dress({ 0, 0, 0, 1 }), nil, "OFF suppresses the outdoor sky")

local block = {}
for i = 1, 16 do block[i] = (i - 1) % 8 end
local function fakeMap(id)
  return {
    id = id,
    def = { width = 2, height = 2, tileset = "OVERWORLD" },
    tileset = {
      blocks = { block }, tilesPerRow = 16,
      imageWidth = 128, imageHeight = 48,
    },
  }
end

local Horizon = assert(loadfile("lib/HorizonWall.lua"))(V)
local map = fakeMap("ROUTE_2")
eq(Horizon.classFor(map), "trees", "ordinary outdoor maps extend as trees")
eq(Horizon.preferBody(map), true,
   "outdoor panorama replaces the expensive carved border ring")
local geometry = Horizon.geometry({ map = map, neighbors = {} })
eq(#geometry, 1, "one isolated map gets one horizon mesh")
if geometry[1].quads < 24 then
  error("horizon mesh is unexpectedly sparse")
end
if geometry[1].quads > 520 then
  error("horizon mesh exceeded the bounded far-belt rural budget")
end
local maxY, minX = -math.huge, math.huge
for _, v in ipairs(geometry[1].wallVertices) do
  maxY = math.max(maxY, v[2])
  minX = math.min(minX, v[1])
end
if maxY < Horizon.HEIGHT then
  error("varied curtain did not reach its minimum opaque height")
end
eq(minX, -Horizon.OUTDOOR_WALL_DISTANCE,
   "far belt closes the west world edge")
local groundMinX = math.huge
local ruralCapMaxY = -math.huge
for _, v in ipairs(geometry[1].groundVertices) do
  groundMinX = math.min(groundMinX, v[1])
  ruralCapMaxY = math.max(ruralCapMaxY, v[2])
end
eq(groundMinX, -Horizon.OUTDOOR_WALL_DISTANCE - Horizon.CAP_DEPTH,
   "high-view cap closes the outer corner instead of leaving a sky hole")
eq(ruralCapMaxY, 0, "generic rural scenery has no raised muddy cap")
eq(geometry[1].class, "trees", "mesh records its semantic scenery class")
eq(geometry[1].fillerQuads,
   #geometry[1].wallVertices / 4 * Horizon.GENERIC_TREE_FILLER_ROWS,
   "generic rural walls receive exactly two bounded underbrush rows")
eq(geometry[1].foregroundTrees, 0,
   "generic rural filler adds no per-panel voxel objects")

-- Explicit profiles prevent one universal town wallpaper from leaking onto
-- every OVERWORLD map. Route 1 shares Pallet's rural forest treatment;
-- Viridian/Cerulean retain towns, while Saffron/Celadon use the metropolis.
local pallet = fakeMap("PALLET_TOWN")
eq(Horizon.classFor(pallet), "pallet", "Pallet gets its forest-only profile")
eq(Horizon.profileFor(pallet).wall, "forest", "Pallet never inherits city art")
eq(Horizon.profileFor(pallet).fillerRows, 0,
   "Pallet adds no synthetic tree-card corridor before its forest")
eq(Horizon.PALLET_WALL_DISTANCE, 0,
   "Pallet forest meets the authored map boundary without a checker apron")
eq(Horizon.VEGETATION_GROUND_PERIOD, 128,
   "every vegetated horizon uses one broad non-checker grass period")
eq(Horizon.groundPeriodFor(pallet), Horizon.VEGETATION_GROUND_PERIOD,
   "Pallet's transition ground addresses the broad grass source")
local palletGeometry = Horizon.geometry({ map = pallet, neighbors = {} })[1]
eq(palletGeometry.groundPeriod, Horizon.VEGETATION_GROUND_PERIOD,
   "Pallet geometry carries the same broad grass UV period")
local palletWallMinX, palletWallMaxX = math.huge, -math.huge
for _, v in ipairs(palletGeometry.wallVertices) do
  palletWallMinX = math.min(palletWallMinX, v[1])
  palletWallMaxX = math.max(palletWallMaxX, v[1])
end
eq(palletWallMinX, 0,
   "Pallet west forest plane meets the authored map boundary")
eq(palletWallMaxX, pallet.def.width * 32 + Horizon.PALLET_WALL_DISTANCE,
   "Pallet east forest plane meets the authored map boundary")
eq(palletGeometry.fillerQuads, 0,
   "Pallet emits no pasted cards between its map and forest")

-- Route 1 is a rural Pallet/Viridian approach rather than a ring of houses.
-- Its closing plane remains at ground level and the same three mini-tree rows
-- used around Pallet close the otherwise empty apron.
local route1Edge = fakeMap("ROUTE_1")
local viridian = fakeMap("VIRIDIAN_CITY")
local cerulean = fakeMap("CERULEAN_CITY")
eq(Horizon.classFor(route1Edge), "pallet",
   "Route 1 uses Pallet's rural forest skyline")
eq(Horizon.profileFor(route1Edge).wall, "forest",
   "Route 1 never decodes or displays the town facade")
eq(Horizon.profileFor(route1Edge).fillerRows, 0,
   "Route 1 adds no synthetic tree-card corridor")
local route1Geometry = Horizon.geometry({ map = route1Edge, neighbors = {} })[1]
local route1WallMinX = math.huge
for _, v in ipairs(route1Geometry.wallVertices) do
  route1WallMinX = math.min(route1WallMinX, v[1])
end
eq(route1WallMinX, -Horizon.PALLET_WALL_DISTANCE,
   "Route 1 shares Pallet's flush transition distance")
eq(Horizon.classFor(viridian), "smalltown",
   "Viridian City uses its authored outskirts skyline")
eq(Horizon.classFor(cerulean), "smalltown",
   "Cerulean City shares only the explicit small-town profile")
eq(Horizon.classFor(fakeMap("SAFFRON_CITY")), "metropolis",
   "Saffron receives the high-rise profile")
eq(Horizon.classFor(fakeMap("CELADON_CITY")), "metropolis",
   "Celadon receives the high-rise profile")
eq(Horizon.profileFor(map), nil,
   "generic outdoor maps never inherit a settlement image profile")
local viridianGeometry = Horizon.geometry({ map = viridian, neighbors = {} })[1]
eq(viridianGeometry.class, "smalltown",
   "Viridian geometry retains the distinct texture class")
eq(viridianGeometry.foregroundTrees, Horizon.FOREGROUND_TREE_CAP,
   "an isolated Viridian edge reaches but never exceeds the tree cap")
eq(viridianGeometry.foregroundQuads,
   Horizon.FOREGROUND_TREE_CAP * Horizon.FOREGROUND_TREE_QUADS
   + viridianGeometry.fillerQuads,
   "voxel trees and the one image row share an exact geometry budget")
if viridianGeometry.fillerQuads <= 0 then
  error("small-town belt lost its mini-tree foreground layer")
end
eq(#viridianGeometry.foregroundVertices,
   viridianGeometry.foregroundQuads * 4,
   "foreground trees are real batched quad geometry")
eq(#viridianGeometry.foregroundIndices,
   viridianGeometry.foregroundQuads * 6,
   "foreground trees share one indexed mesh")
local capMaxY, treeMaxY = -math.huge, -math.huge
for _, v in ipairs(viridianGeometry.groundVertices) do
  capMaxY = math.max(capMaxY, v[2])
end
for _, v in ipairs(viridianGeometry.foregroundVertices) do
  treeMaxY = math.max(treeMaxY, v[2])
end
eq(capMaxY, 0, "Viridian has no elevated rectangular green mass")
if treeMaxY < 50 then error("foreground trees lost their voxel silhouette") end

local cinnabar = fakeMap("CINNABAR_ISLAND")
cinnabar.def.width, cinnabar.def.height = 10, 9
eq(Horizon.classFor(cinnabar), "mountain",
   "Cinnabar keeps volcanic scenery on its non-ocean edges")
eq(Horizon.edgeClass(cinnabar, "south"), "open_water",
   "Cinnabar's free southern edge is classified as open ocean")
eq(Horizon.edgeClass(cinnabar, "west"), "open_water",
   "Cinnabar's free western edge is ocean too")
eq(Horizon.edgeClass(fakeMap("ROUTE_20"), "south"), "open_water",
   "Route 20 continues the same southern ocean")
eq(Horizon.edgeClass(map, "south"), "forest",
   "ordinary inland maps retain their semantic edge scenery")
local islandGeometry = Horizon.geometry({ map = cinnabar, neighbors = {} })[1]
if not islandGeometry or islandGeometry.seaQuads <= 0 then
  error("Cinnabar did not build its southern sea extension")
end
local seaMinX, seaMaxZ = math.huge, -math.huge
for _, v in ipairs(islandGeometry.seaVertices) do
  seaMinX = math.min(seaMinX, v[1])
  seaMaxZ = math.max(seaMaxZ, v[3])
  eq(v[2], Horizon.SEA_LEVEL, "open sea matches native recessed water")
end
eq(seaMinX, -Horizon.BELT - Horizon.SEA_DEPTH,
   "open sea fans out beyond the southwest corner")
eq(seaMaxZ, cinnabar.def.height * 32 + Horizon.BELT + Horizon.SEA_DEPTH,
   "open sea reaches beyond the curved visible horizon")
local forbiddenSouthWall = cinnabar.def.height * 32 + Horizon.BELT
for _, v in ipairs(islandGeometry.wallVertices) do
  if v[3] == forbiddenSouthWall then
    error("Cinnabar still has a vertical barricade across its southern sea")
  end
end

-- Use the real Cinnabar dimensions and its two real connection directions.
-- Those seams must remain empty while the unconnected south/west edges keep
-- their sea. This guards directional water against covering streamed map
-- bodies as the player approaches Route 20 or Route 21.
local route21 = fakeMap("ROUTE_21")
route21.def.width, route21.def.height = 10, 45
local route20 = fakeMap("ROUTE_20")
route20.def.width, route20.def.height = 50, 9
local islandJoined = Horizon.geometry({
  map = cinnabar,
  neighbors = {
    { map = route21, ox = 0, oy = -route21.def.height * 32 },
    { map = route20, ox = cinnabar.def.width * 32, oy = 0 },
  },
})[1]
eq(#islandJoined.wallVertices, 0,
   "real north/east connections add no Cinnabar panorama panels")
if islandJoined.seaQuads <= 0 then
  error("connected Cinnabar lost its unconnected south/west ocean")
end

local mountain = fakeMap("ROUTE_23")
mountain.def.borderBlock = 0
eq(Horizon.classFor(mountain), "mountain", "rocky routes extend as mountains")
eq(Horizon.hasSky(mountain), true, "open mountain routes retain the sky")
eq(Horizon.preferBody(mountain), true,
   "mountain routes suppress decorative border-block extrusion")
local mountainGeometry = Horizon.geometry({ map = mountain, neighbors = {} })[1]
eq(#mountainGeometry.foregroundVertices,
   0, "mountain horizons do not inherit Viridian foreground trees")
local mountainCapMaxY = -math.huge
for _, v in ipairs(mountainGeometry.groundVertices) do
  mountainCapMaxY = math.max(mountainCapMaxY, v[2])
end
eq(mountainCapMaxY, 0,
   "mountain horizon has no elevated shelf cutting a stripe across the sky")

-- Real Route 4 is 45x9 blocks. Its panorama advances at native world scale;
-- adding Route 3 may remove covered panels but cannot move a surviving UV.
local route4 = fakeMap("ROUTE_4")
route4.def.width, route4.def.height = 45, 9
local route3 = fakeMap("ROUTE_3")
route3.def.width, route3.def.height = 35, 9
local route4Solo = Horizon.geometry({ map = route4, neighbors = {} })[1]
local route4Geometry = Horizon.geometry({
  map = route4,
  neighbors = { { map = route3, ox = -25 * 32, oy = 9 * 32 } },
})[1]
local function northPanels(built)
  local out = {}
  for i = 1, #built.wallVertices, 4 do
    local a, b = built.wallVertices[i], built.wallVertices[i + 1]
    if a[3] == -Horizon.BELT and b[3] == -Horizon.BELT then
      local span = math.abs(b[4] - a[4]) * Horizon.MOUNTAIN_STRIP_W
      if span < 31 or span > 32 then
        error("Route 4 panel is stretched across " .. tostring(span)
              .. " mountain texels")
      end
      out[a[1]] = a[4]
    end
  end
  return out
end
local soloNorth, joinedNorth = northPanels(route4Solo), northPanels(route4Geometry)
for x, u in pairs(joinedNorth) do
  if soloNorth[x] and math.abs(soloNorth[x] - u) > 1e-12 then
    error("Route 4 canonical UV phase moved after Route 3 joined at x=" .. x)
  end
end
local m0 = Horizon.panelUV("mountain", 0, 320, false)
local m1 = Horizon.panelUV("mountain", 0, 352, true)
local nativeSpan = math.abs(m1 - m0) * Horizon.MOUNTAIN_STRIP_W
if nativeSpan < 31 or nativeSpan > 32 then
  error("mountain panelUV lost native world scale")
end
local mountainWallMaxY = -math.huge
for _, v in ipairs(mountainGeometry.wallVertices) do
  eq(v[6], Horizon.MOUNTAIN_SHADE,
     "mountain faces share one shade across geometry corners")
  mountainWallMaxY = math.max(mountainWallMaxY, v[2])
end
eq(mountainWallMaxY, Horizon.MOUNTAIN_TEXTURE_H,
   "mountain art keeps one vertical world pixel per source texel")
local cave = fakeMap("ROCK_TUNNEL_1F")
cave.def.tileset = "CAVERN"
eq(Horizon.classFor(cave), "cave", "cavern maps extend as rock walls")
eq(Horizon.preferBody(cave), true,
   "caves suppress decorative border-block extrusion")
local caveGeometry = Horizon.geometry({ map = cave, neighbors = {} })[1]
eq(#caveGeometry.foregroundVertices,
   0, "cave horizons do not inherit Viridian foreground trees")
eq(caveGeometry.ceilingQuads,
   (cave.def.width + 2) * (cave.def.height + 2),
   "cave ceiling covers every body/apron cell exactly once")
local caveWallMaxY = -math.huge
for _, v in ipairs(caveGeometry.wallVertices) do
  caveWallMaxY = math.max(caveWallMaxY, v[2])
end
eq(caveWallMaxY, Horizon.ENCLOSURE_HEIGHT,
   "cave perimeter reaches the dedicated enclosure height")
eq(Horizon.materialFor(cave), "cave",
   "Rock Tunnel keeps the existing procedural cave material")
eq(Horizon.groundPeriodFor(cave), Horizon.CELL,
   "ordinary caves retain the existing 32px ground period")
eq(Horizon.wallFamily("cave", cave), "cave",
   "ordinary caves retain the existing wall family")

local mtMoonMaps = {}
for _, id in ipairs({ "MT_MOON_1F", "MT_MOON_B1F", "MT_MOON_B2F" }) do
  local mtMoon = fakeMap(id)
  mtMoon.def.tileset = "CAVERN"
  mtMoonMaps[#mtMoonMaps + 1] = mtMoon
  eq(Horizon.classFor(mtMoon), "cave",
     id .. " keeps shared cave geometry/camera semantics")
  eq(Horizon.materialFor(mtMoon), "mt_moon",
     id .. " selects the authored Mt Moon material")
  eq(Horizon.groundPeriodFor(mtMoon), 256,
     id .. " selects the native 256px ceiling period")
  eq(Horizon.wallFamily("cave", mtMoon), "mt_moon",
     id .. " routes its cave wall to the Mt Moon texture")
end
local mtU0 = Horizon.panelUV("mt_moon", 0, -64, false)
local mtU1 = Horizon.panelUV("mt_moon", 0, -32, true)
local mtURepeat = Horizon.panelUV("mt_moon", 0, 448, false)
eq((mtU1 - mtU0) * Horizon.MT_MOON_WALL_W, Horizon.CELL,
   "Mt Moon wall keeps one texel per world pixel")
eq(mtURepeat - mtU0, 1,
   "Mt Moon wall phase repeats only after 512 world pixels")

local mtMoonGeometry = Horizon.geometry({
  map = mtMoonMaps[1], neighbors = {},
})[1]
eq(mtMoonGeometry.class, "cave",
   "Mt Moon geometry does not fork the enclosure class")
eq(mtMoonGeometry.material, "mt_moon",
   "Mt Moon geometry records its map-specific material key")
eq(mtMoonGeometry.groundPeriod, Horizon.MT_MOON_GROUND_PERIOD,
   "Mt Moon geometry records its map-specific ground period")
eq(mtMoonGeometry.wallDraws, 1,
   "Mt Moon authored wall remains one existing batched draw")
eq(mtMoonGeometry.wallGroups[1].family, "mt_moon",
   "Mt Moon wall group owns only its authored material")
for i = 1, #mtMoonGeometry.wallGroups[1].vertices, 4 do
  local a, b = mtMoonGeometry.wallGroups[1].vertices[i],
               mtMoonGeometry.wallGroups[1].vertices[i + 1]
  eq(math.abs(b[4] - a[4]) * Horizon.MT_MOON_WALL_W, Horizon.CELL,
     "Mt Moon wall panel escaped native 32px tessellation")
end

local function verifyCeilingGrid(map, built, message)
  local expected = (map.def.width + 2) * (map.def.height + 2)
  eq(built.ceilingQuads, expected, message .. " quad budget")
  local first = #built.groundVertices - built.ceilingQuads * 4 + 1
  local seen, minX, minZ = {}, math.huge, math.huge
  local maxX, maxZ, curveError = -math.huge, -math.huge, 0
  local k = 0.18 / 144 -- strongest shipped curve at the native-height bound
  local focusX = map.def.width * Horizon.CELL * 0.37
  local focusZ = map.def.height * Horizon.CELL * 0.61
  local function drop(x, z)
    local dx, dz = x - focusX, z - focusZ
    return (dx * dx + dz * dz) * k
  end
  for i = first, #built.groundVertices, 4 do
    local a, b, c, d = built.groundVertices[i],
                        built.groundVertices[i + 1],
                        built.groundVertices[i + 2],
                        built.groundVertices[i + 3]
    eq(b[1] - a[1], Horizon.CELL, message .. " cell width")
    eq(c[3] - b[3], Horizon.CELL, message .. " cell depth")
    eq(a[3], b[3], message .. " north edge is level")
    eq(b[1], c[1], message .. " east edge is closed")
    eq(c[3], d[3], message .. " south edge is level")
    eq(d[1], a[1], message .. " west edge is closed")
    for _, v in ipairs({ a, b, c, d }) do
      eq(v[2], Horizon.ENCLOSURE_HEIGHT,
         message .. " meets the tall wall without a black seam")
    end
    local key = tostring(a[1]) .. ":" .. tostring(a[3])
    if seen[key] then error(message .. " duplicated ceiling cell " .. key) end
    seen[key] = true
    minX, minZ = math.min(minX, a[1]), math.min(minZ, a[3])
    maxX, maxZ = math.max(maxX, c[1]), math.max(maxZ, c[3])

    -- The shader displaces vertices quadratically and the rasterizer linearly
    -- interpolates between them. Measure the worst centre error of every real
    -- tile: one old map-sized quad would be tens of pixels wrong here.
    local midX, midZ = (a[1] + c[1]) / 2, (a[3] + c[3]) / 2
    local interpolated = (drop(a[1], a[3]) + drop(b[1], b[3])
                        + drop(c[1], c[3]) + drop(d[1], d[3])) / 4
    curveError = math.max(curveError,
                          math.abs(interpolated - drop(midX, midZ)))
  end
  eq(minX, -Horizon.BELT, message .. " starts at west wall")
  eq(minZ, -Horizon.BELT, message .. " starts at north wall")
  eq(maxX, map.def.width * Horizon.CELL + Horizon.BELT,
     message .. " reaches east wall")
  eq(maxZ, map.def.height * Horizon.CELL + Horizon.BELT,
     message .. " reaches south wall")
  for z = -Horizon.BELT,
          map.def.height * Horizon.CELL + Horizon.BELT - Horizon.CELL,
          Horizon.CELL do
    for x = -Horizon.BELT,
            map.def.width * Horizon.CELL + Horizon.BELT - Horizon.CELL,
            Horizon.CELL do
      if not seen[tostring(x) .. ":" .. tostring(z)] then
        error(message .. " left a ceiling hole at " .. x .. "," .. z)
      end
    end
  end
  if curveError > 0.65 then
    error(message .. " exceeded the 32px WorldCurve error bound: "
          .. tostring(curveError))
  end
  return curveError
end

verifyCeilingGrid(cave, caveGeometry, "small cave ceiling")
verifyCeilingGrid(mtMoonMaps[1], mtMoonGeometry, "Mt Moon ceiling")
local mtCeilingStart = #mtMoonGeometry.groundVertices
                       - mtMoonGeometry.ceilingQuads * 4 + 1
local mtCeilingA = mtMoonGeometry.groundVertices[mtCeilingStart]
local mtCeilingB = mtMoonGeometry.groundVertices[mtCeilingStart + 1]
local mtCeilingD = mtMoonGeometry.groundVertices[mtCeilingStart + 3]
eq(mtCeilingB[4] - mtCeilingA[4],
   Horizon.CELL / Horizon.MT_MOON_GROUND_PERIOD,
   "Mt Moon ceiling U uses the native 256px world period")
eq(mtCeilingD[5] - mtCeilingA[5],
   Horizon.CELL / Horizon.MT_MOON_GROUND_PERIOD,
   "Mt Moon ceiling V uses the native 256px world period")

-- Rock Tunnel's large production-scale footprint is the adversarial case:
-- complete coverage stays on the 32px curve grid and below a one-pixel chord
-- error while retaining one ground batch.
local largeCave = fakeMap("ROCK_TUNNEL_1F")
largeCave.def.tileset = "CAVERN"
largeCave.def.width, largeCave.def.height = 20, 18
local largeCaveGeometry = Horizon.geometry({
  map = largeCave, neighbors = {},
})[1]
eq(largeCaveGeometry.ceilingQuads, 440,
   "20x18 Rock Tunnel has one bounded ceiling quad per covered cell")
verifyCeilingGrid(largeCave, largeCaveGeometry,
                  "production Rock Tunnel ceiling")

-- Connected cave floors intentionally overlap only on their two-cell aprons.
-- Because both owners use the same 32px world grid and repeating material
-- phase, those coplanar tiles are byte-equivalent after the neighbour model
-- translation instead of forming a curved crack or mismatched texture strip.
local caveEast = fakeMap("ROCK_TUNNEL_B1F")
caveEast.def.tileset = "CAVERN"
caveEast.def.width, caveEast.def.height = 8, largeCave.def.height
local caveUnion = Horizon.geometry({
  map = largeCave,
  neighbors = {
    { map = caveEast, ox = largeCave.def.width * Horizon.CELL, oy = 0 },
  },
})
eq(#caveUnion, 2, "connected Rock Tunnel keeps two enclosure owners")
local function worldCeilingCells(part)
  local cells = {}
  local first = #part.groundVertices - part.ceilingQuads * 4 + 1
  for i = first, #part.groundVertices, 4 do
    local v = part.groundVertices[i]
    local key = tostring(part.ox + v[1]) .. ":"
                .. tostring(part.oy + v[3])
    cells[key] = { y = v[2], u = v[4] % 1, vv = v[5] % 1 }
  end
  return cells
end
local westCells, eastCells = worldCeilingCells(caveUnion[1]),
                              worldCeilingCells(caveUnion[2])
local overlap = 0
for key, westCell in pairs(westCells) do
  local eastCell = eastCells[key]
  if eastCell then
    overlap = overlap + 1
    eq(eastCell.y, westCell.y, "cave overlap has identical height")
    eq(eastCell.u, westCell.u, "cave overlap has identical U phase")
    eq(eastCell.vv, westCell.vv, "cave overlap has identical V phase")
  end
end
eq(overlap, 2 * (largeCave.def.height + 2),
   "connected cave overlap is exactly the two-cell shared apron")

local tower = fakeMap("POKEMON_TOWER_2F")
tower.def.tileset = "CEMETERY"
eq(Horizon.classFor(tower), "tower",
   "Pokemon Tower gets a dedicated closed architectural enclosure")
eq(Horizon.preferBody(tower), true,
   "tower enclosure replaces the low carved border ring")
eq(Horizon.materialFor(tower), "tower",
   "Pokemon Tower keeps its dedicated authored material key")
eq(Horizon.groundPeriodFor(tower), Horizon.TOWER_SURFACE_PERIOD,
   "Pokemon Tower selects the broad native ceiling period")
local towerU0 = Horizon.panelUV("tower", 0, 0, false)
local towerU1 = Horizon.panelUV("tower", 0, Horizon.CELL, true)
local towerURepeat = Horizon.panelUV(
  "tower", 0, Horizon.TOWER_WALL_W, false)
eq((towerU1 - towerU0) * Horizon.TOWER_WALL_W, Horizon.CELL,
   "Pokemon Tower wall keeps one texel per world pixel")
eq(towerURepeat - towerU0, 1,
   "Pokemon Tower wall repeats only after both authored bays")
local towerGeometry = Horizon.geometry({ map = tower, neighbors = {} })[1]
eq(towerGeometry.ceilingQuads,
   (tower.def.width + 2) * (tower.def.height + 2),
   "Pokemon Tower receives the same cell-bounded overhead closure")
eq(towerGeometry.class, "tower",
   "tower geometry retains its distinct material class")
eq(towerGeometry.groundPeriod, Horizon.TOWER_SURFACE_PERIOD,
   "tower geometry records its 256px ceiling period")
eq(towerGeometry.wallGroups[1].family, "tower",
   "tower wall stays in one dedicated authored draw family")
verifyCeilingGrid(tower, towerGeometry, "Pokemon Tower ceiling")

local roomCenters = {}
for _, id in ipairs({ "MT_MOON_POKECENTER",
                       "ROCK_TUNNEL_POKECENTER" }) do
  local center = fakeMap(id)
  center.def.tileset = "POKECENTER"
  center.def.width, center.def.height = 7, 4
  center.def.connections = {}
  roomCenters[#roomCenters + 1] = center
  eq(Horizon.classFor(center), "room",
     id .. " receives a room shell, never a cave shell")
  eq(Horizon.materialFor(center), "pokecenter_room",
     id .. " selects only the shared Pokecenter material")
  eq(Horizon.groundPeriodFor(center), 128,
     id .. " keeps the quiet 128px room-surface period")
  eq(Horizon.preferBody(center), true,
     id .. " replaces the low synthetic border ring with the room shell")
  eq(Horizon.hasSky(center), false,
     id .. " remains a sealed interior with no outdoor atmosphere")
  local roomGeometry = Horizon.geometry({ map = center, neighbors = {} })[1]
  eq(roomGeometry.class, "room", id .. " records room geometry semantics")
  eq(roomGeometry.material, "pokecenter_room",
     id .. " records the Pokecenter material key")
  eq(roomGeometry.wallDraws, 1, id .. " has one batched wall family")
  eq(roomGeometry.wallGroups[1].family, "pokecenter_room",
     id .. " wall batch cannot inherit cave/tower art")
  eq(Horizon.wallFamily("room", center), "pokecenter_room",
     id .. " room panels resolve only to the Pokecenter family")
  eq(roomGeometry.ceilingQuads, 54,
     id .. " 7x4 body plus apron has exactly 54 ceiling cells")
  eq(#roomGeometry.wallVertices / 4, 30,
     id .. " perimeter has exactly 30 native-width wall panels")
  eq(#roomGeometry.groundVertices / 4, 118,
     id .. " apron/cap/ceiling stays one bounded ground batch")
  eq(roomGeometry.quads, 148,
     id .. " shell stays within the exact 148-quad budget")
  eq(#roomGeometry.wallVertices + #roomGeometry.groundVertices, 592,
     id .. " shell retains exactly 592 table vertices")
  eq(#roomGeometry.wallIndices + #roomGeometry.groundIndices, 888,
     id .. " shell retains exactly 888 triangle indices")
  local roomWallMaxY = -math.huge
  for i = 1, #roomGeometry.wallGroups[1].vertices, 4 do
    local a, b = roomGeometry.wallGroups[1].vertices[i],
                 roomGeometry.wallGroups[1].vertices[i + 1]
    roomWallMaxY = math.max(roomWallMaxY,
      a[2], b[2], roomGeometry.wallGroups[1].vertices[i + 2][2],
      roomGeometry.wallGroups[1].vertices[i + 3][2])
    eq(math.abs(b[4] - a[4]) * Horizon.POKECENTER_ROOM_WALL_W,
       Horizon.CELL, id .. " wall panel keeps one source texel per world pixel")
  end
  eq(roomWallMaxY, Horizon.ENCLOSURE_HEIGHT,
     id .. " wall meets the ceiling at the shared enclosure height")
  verifyCeilingGrid(center, roomGeometry, id .. " room ceiling")
end

-- Every eligibility axis fails closed. Exact location names cannot override a
-- real cave/outdoor conversion; a streamed opening and every unlisted Center
-- keep the legacy interior border path.
for _, id in ipairs({ "MT_MOON_POKECENTER",
                       "ROCK_TUNNEL_POKECENTER" }) do
  local realCaveCenter = fakeMap(id)
  realCaveCenter.def.tileset, realCaveCenter.def.connections = "CAVERN", {}
  eq(Horizon.classFor(realCaveCenter), "cave",
     id .. " CAVERN conversion is never forced into a Pokecenter room")
  eq(Horizon.materialFor(realCaveCenter), "cave",
     id .. " real cave conversion receives no Pokecenter material")
  eq(Horizon.preferBody(realCaveCenter), true,
     id .. " real CAVERN conversion receives the automatic closed cave body")
  local realCaveCenterGeometry = Horizon.geometry({
    map = realCaveCenter, neighbors = {},
  })[1]
  eq(realCaveCenterGeometry.class, "cave",
     id .. " room-profile ID cannot leak into cave geometry")
  eq(realCaveCenterGeometry.wallGroups[1].family, "cave",
     id .. " room-profile ID cannot leak Pokecenter wall art into a cave")
  verifyCeilingGrid(realCaveCenter, realCaveCenterGeometry,
                    id .. " CAVERN room-profile collision ceiling")
end

-- Cave tilesets, rather than today's map-name list, own the enclosure. These
-- synthetic IDs model unknown fan-region maps and an explicit outdoor profile
-- collision so future CAVERN maps automatically remain sealed.
for _, tileset in ipairs({ "CAVERN", "ORANGE_GEN2_CAVE" }) do
  local extensionCave = fakeMap("FAN_REGION_CRYSTAL_DEPTHS")
  extensionCave.def.tileset, extensionCave.def.connections = tileset, {}
  eq(Horizon.classFor(extensionCave), "cave",
     tileset .. " classifies an unknown extension ID as a cave")
  eq(Horizon.materialFor(extensionCave), "cave",
     tileset .. " selects the generic cave material for an unknown ID")
  eq(Horizon.preferBody(extensionCave), true,
     tileset .. " automatically selects the closed cave body")
  local extensionGeometry = Horizon.geometry({
    map = extensionCave, neighbors = {},
  })[1]
  eq(extensionGeometry.class, "cave",
     tileset .. " records cave geometry for an unknown extension ID")
  eq(extensionGeometry.wallGroups[1].family, "cave",
     tileset .. " retains the cave wall family for an unknown extension ID")
  verifyCeilingGrid(extensionCave, extensionGeometry,
                    tileset .. " future extension ceiling")
end

local profiledCave = fakeMap("VIRIDIAN_CITY")
profiledCave.def.tileset, profiledCave.def.connections = "CAVERN", {}
eq(Horizon.classFor(profiledCave), "cave",
   "a CAVERN tileset overrides even an existing outdoor location profile")
eq(Horizon.materialFor(profiledCave), "cave",
   "an outdoor profile collision cannot replace the cave material")
local profiledCaveGeometry = Horizon.geometry({
  map = profiledCave, neighbors = {},
})[1]
eq(profiledCaveGeometry.class, "cave",
   "an outdoor profile collision still builds cave enclosure geometry")
verifyCeilingGrid(profiledCave, profiledCaveGeometry,
                  "CAVERN outdoor-profile collision ceiling")
local outdoorCenter = fakeMap("ROCK_TUNNEL_POKECENTER")
outdoorCenter.def.tileset, outdoorCenter.def.connections = "OVERWORLD", {}
eq(Horizon.classFor(outdoorCenter), "trees",
   "an outdoor conversion retains outdoor scenery semantics")
local connectedCenter = fakeMap("MT_MOON_POKECENTER")
connectedCenter.def.tileset = "POKECENTER"
connectedCenter.def.connections = { east = { map = "ROUTE_4" } }
eq(Horizon.classFor(connectedCenter), "interior",
   "an authored physical opening disables the closed room shell")
eq(Horizon.preferBody(connectedCenter), false,
   "a connected Center fails back to the legacy atomic border path")
eq(#Horizon.geometry({ map = connectedCenter, neighbors = {} }), 0,
   "a connected Center cannot be cut by a room wall or ceiling")
local unlistedCenter = fakeMap("VIRIDIAN_POKECENTER")
unlistedCenter.def.tileset, unlistedCenter.def.connections = "POKECENTER", {}
eq(Horizon.classFor(unlistedCenter), "interior",
   "the room pilot does not generalize by a POKECENTER substring")
eq(Horizon.preferBody(unlistedCenter), false,
   "unlisted Centers remain byte-for-byte on the legacy border path")
local interior = fakeMap("REDS_HOUSE_1F")
interior.def.tileset = "HOUSE"
eq(Horizon.classFor(interior), "interior", "rooms have no outdoor curtain")
eq(Horizon.preferBody(interior), false,
   "rooms keep their existing enclosed geometry")
eq(#Horizon.geometry({ map = interior, neighbors = {} }), 0,
   "rooms never receive an outdoor panorama")
local forest = fakeMap("VIRIDIAN_FOREST")
forest.def.tileset = "FOREST"
eq(Horizon.classFor(forest), "canopy",
   "Viridian Forest keeps a closed panorama-free canopy edge")
eq(Horizon.preferBody(forest), true,
   "Viridian Forest skips its expensive carved border ring")
eq(Horizon.hasSky(forest), false,
   "forest edge scenery does not expose an open sky through the canopy")
local forestGeometry = Horizon.geometry({ map = forest, neighbors = {} })[1]
eq(forestGeometry.foregroundTrees, 0,
   "the closed forest class never inherits small-town voxel trees")
eq(forestGeometry.canopyCrownQuads,
   #forestGeometry.wallVertices / 4,
   "every forest wall panel receives one native rear-vault panel")
eq(#forestGeometry.wallGroups, 1,
   "canopy crown shares the existing regional wall family")
eq(#forestGeometry.wallGroups[1].vertices,
   #forestGeometry.wallVertices + forestGeometry.canopyCrownQuads * 4,
   "canopy crown adds geometry without another draw family")
eq(Horizon.CANOPY_VAULT_RISE, 48,
   "rear forest crown lost its front-hidden native crop baseline")
eq(Horizon.CANOPY_VAULT_HEIGHT, 64,
   "rear forest crown stopped using exactly 64 native source rows")
local crownVertices = 0
local crownMinY = math.huge
local crownMaxY = -math.huge
local mapW, mapH = forest.def.width * 32, forest.def.height * 32
local canopyGroup = forestGeometry.wallGroups[1].vertices
for panel = 1, #canopyGroup, 8 do
  local base = { canopyGroup[panel], canopyGroup[panel + 1],
                 canopyGroup[panel + 2], canopyGroup[panel + 3] }
  local crown = { canopyGroup[panel + 4], canopyGroup[panel + 5],
                  canopyGroup[panel + 6], canopyGroup[panel + 7] }
  eq(crown[3][2] - crown[1][2], Horizon.CANOPY_VAULT_HEIGHT,
     "rear forest crown stopped using a native-height vertical course")
  eq((crown[1][5] - crown[3][5]) * Horizon.REGIONAL_TEXTURE_H,
     Horizon.CANOPY_VAULT_HEIGHT,
     "rear forest crown vertically stretched its cropped source")
  for i = panel + 4, panel + 7 do
    local v = canopyGroup[i]
    crownVertices = crownVertices + 1
    crownMinY = math.min(crownMinY, v[2])
    crownMaxY = math.max(crownMaxY, v[2])
    local baseV = base[i - panel - 3]
    local bottom = i - panel <= 5
    local expectedY = Horizon.CANOPY_VAULT_RISE
                      + (bottom and 0 or Horizon.CANOPY_VAULT_HEIGHT)
    if v[2] ~= expectedY then
      error("canopy crown escaped its cropped native vertical bounds")
    end
    local expectedV = bottom
      and baseV[5] - (96 - Horizon.CANOPY_VAULT_HEIGHT)
                       / Horizon.REGIONAL_TEXTURE_H
      or baseV[5]
    if v[4] ~= baseV[4] or v[5] ~= expectedV then
      error("canopy rear vault escaped the exact native upper-panel crop")
    end
    local onRearWall = v[1] == -Horizon.OUTDOOR_WALL_DISTANCE
                               - Horizon.CANOPY_VAULT_OUTSET
                       or v[1] == mapW + Horizon.OUTDOOR_WALL_DISTANCE
                                  + Horizon.CANOPY_VAULT_OUTSET
                       or v[3] == -Horizon.OUTDOOR_WALL_DISTANCE
                                  - Horizon.CANOPY_VAULT_OUTSET
                       or v[3] == mapH + Horizon.OUTDOOR_WALL_DISTANCE
                                  + Horizon.CANOPY_VAULT_OUTSET
    if not onRearWall then
      error("canopy crown crossed over the playable forest footprint")
    end
  end
end
eq(crownVertices, forestGeometry.canopyCrownQuads * 4,
   "only the perimeter wall owns high canopy-crown vertices")
eq(crownMinY, Horizon.CANOPY_VAULT_RISE,
   "rear forest crown cut is no longer hidden at y=48")
eq(crownMaxY,
   Horizon.CANOPY_VAULT_RISE + Horizon.CANOPY_VAULT_HEIGHT,
   "rear forest vault lost its naturally transparent cropped top")
eq(forestGeometry.fillerQuads,
   #forestGeometry.wallVertices / 4 * 3,
   "an isolated forest closes wall and turn panels with exactly three rows")
eq(#forestGeometry.foregroundVertices, forestGeometry.fillerQuads * 4,
   "forest image rows share one indexed foreground mesh")
local forestCapY = -math.huge
for _, v in ipairs(forestGeometry.groundVertices) do
  forestCapY = math.max(forestCapY, v[2])
end
eq(forestCapY, 0, "Viridian Forest removed the raised muddy canopy cap")

local productionForest = fakeMap("VIRIDIAN_FOREST")
productionForest.def.tileset = "FOREST"
productionForest.def.width, productionForest.def.height = 17, 24
local productionForestGeometry = Horizon.geometry({
  map = productionForest, neighbors = {},
})[1]
eq(#productionForestGeometry.wallVertices / 4, 106,
   "the real 17x24 forest has 82 edge and 24 corner wall panels")
eq(productionForestGeometry.canopyCrownQuads, 106,
   "the real forest crown stays at one rear panel per perimeter panel")
eq(productionForestGeometry.wallDraws, 1,
   "the real forest crown adds no wall draw or texture family")
if productionForestGeometry.canopyCrownQuads >= 690 then
  error("canopy crown regressed into a map-covering horizontal roof")
end

local palletGeometry = Horizon.geometry({ map = pallet, neighbors = {} })[1]
eq(palletGeometry.foregroundTrees, 0,
   "Pallet's complete hedge ring contains no city voxel objects")
eq(palletGeometry.fillerQuads,
   0,
   "Pallet uses the continuous forest wall rather than pasted depth rows")
local palletVariants = {}
local palletMinTexelSpan, palletMaxTexelSpan = math.huge, -math.huge
for _, v in ipairs(palletGeometry.wallVertices) do
  palletVariants[math.min(Horizon.FOREST_VARIANTS - 1,
    math.floor((v[4] * Horizon.REGIONAL_STRIP_W
                - Horizon.REGIONAL_SLICES.forest.x) / Horizon.DIRECTION_W))] = true
end
for i = 1, #palletGeometry.wallVertices, 4 do
  local span = math.abs(palletGeometry.wallVertices[i + 1][4]
                        - palletGeometry.wallVertices[i][4])
               * Horizon.REGIONAL_STRIP_W
  palletMinTexelSpan = math.min(palletMinTexelSpan, span)
  palletMaxTexelSpan = math.max(palletMaxTexelSpan, span)
end
local palletVariantCount = 0
for _ in pairs(palletVariants) do palletVariantCount = palletVariantCount + 1 end
if palletVariantCount < 2 then
  error("Pallet forest stretched one image across its complete perimeter")
end
if palletMinTexelSpan < 31 or palletMaxTexelSpan > 32 then
  error("Pallet forest lost its one-texel-per-world-pixel scale")
end

local route1Geometry = Horizon.geometry({
  map = route1Edge, neighbors = {},
})[1]
eq(route1Geometry.class, "pallet",
   "Route 1 geometry shares the rural forest texture class")
eq(route1Geometry.fillerQuads,
   0,
   "Route 1 joins directly to its continuous forest wall")
local route1CapMaxY = -math.huge
for _, v in ipairs(route1Geometry.groundVertices) do
  route1CapMaxY = math.max(route1CapMaxY, v[2])
end
eq(route1CapMaxY, 0, "Route 1 keeps its entire outer cap on ground level")

-- Route 8 owns one compact Saffron -> suburb -> Lavender strip.  Native QA
-- rejected the 32px draft, so it now keeps one dedicated 960x96 Canvas while
-- preserving one draw and exact 1:1 panel addressing on the isolated route.
local route8 = fakeMap("ROUTE_8")
route8.def.width, route8.def.height = 30, 9
local route8Geometry = Horizon.geometry({ map = route8, neighbors = {} })[1]
local route8WallQuads = #route8Geometry.wallVertices / 4
eq(route8Geometry.wallDraws, 1,
   "Route 8 continuous panorama adds no second wall draw")
for _, group in ipairs(route8Geometry.wallGroups) do
  local textureW = group.family == "route8" and Horizon.ROUTE8_STRIP_W
                   or Horizon.REGIONAL_STRIP_W
  for i = 1, #group.vertices, 4 do
    local span = math.abs(group.vertices[i + 1][4]
                          - group.vertices[i][4]) * textureW
    if span < 31 or span > 32 then
      error("Route 8 " .. group.family .. " scale drifted outside 1:1: "
            .. tostring(span))
    end
  end
end
eq(route8Geometry.fillerQuads, 0,
   "Route 8 distant strip adds no near-field filler/pop-in family")
eq(route8Geometry.route8MidgroundQuads, 86,
   "Route 8 keeps sparse long faces plus exact short-face openings")
eq(#route8Geometry.route8MidgroundVertices,
   route8Geometry.route8MidgroundQuads * 4,
   "Route 8 midground planes share one exact vertex batch")
eq(#route8Geometry.route8MidgroundIndices,
   route8Geometry.route8MidgroundQuads * 6,
   "Route 8 midground planes share one exact indexed batch")
local westOpening, eastOpening = {}, {}
local route8Width = route8.def.width * Horizon.CELL
local route8Height = route8.def.height * Horizon.CELL
local longFaceMidground, shortFaceMidground, cornerMidground = 0, 0, 0
local lowCropMidground = 0
for i = 1, #route8Geometry.route8MidgroundVertices, 4 do
  local minX, maxX, minY, maxY, minZ, maxZ = math.huge, -math.huge,
    math.huge, -math.huge, math.huge, -math.huge
  for j = 0, 3 do
    local v = route8Geometry.route8MidgroundVertices[i + j]
    minX, maxX = math.min(minX, v[1]), math.max(maxX, v[1])
    minY, maxY = math.min(minY, v[2]), math.max(maxY, v[2])
    minZ, maxZ = math.min(minZ, v[3]), math.max(maxZ, v[3])
  end
  local span = math.max(maxX - minX, maxZ - minZ)
  local uSpan = math.abs(route8Geometry.route8MidgroundVertices[i + 1][4]
                         - route8Geometry.route8MidgroundVertices[i][4])
                * Horizon.ROUTE8_MIDGROUND_W
  local lowSeam = span == Horizon.ROUTE8_SEAM_SHRUB.w
                  and maxY - minY == Horizon.ROUTE8_SEAM_SHRUB.h
  if lowSeam then
    lowCropMidground = lowCropMidground + 1
    eq(uSpan, Horizon.ROUTE8_SEAM_SHRUB.w,
       "Route 8 seam shrub lost native 1:1 scale")
    eq(math.min(route8Geometry.route8MidgroundVertices[i][4],
                route8Geometry.route8MidgroundVertices[i + 1][4])
       * Horizon.ROUTE8_MIDGROUND_W,
       Horizon.ROUTE8_SEAM_SHRUB.x,
       "Route 8 seam shrub sampled outside its proven low crop")
  else
    eq(span, Horizon.ROUTE8_MIDGROUND_MODULE_W,
       "Route 8 midground module lost its native 32px width")
    eq(maxY - minY, Horizon.ROUTE8_MIDGROUND_H,
       "Route 8 midground module lost its native 64px height")
    eq(uSpan, Horizon.ROUTE8_MIDGROUND_MODULE_W,
       "Route 8 midground texture drifted outside exact 1:1 scale")
  end
  if minZ == maxZ and minX >= 0 and maxX <= route8Width then
    longFaceMidground = longFaceMidground + 1
  elseif minX == maxX and minZ >= 0 and maxZ <= route8Height then
    shortFaceMidground = shortFaceMidground + 1
  else
    cornerMidground = cornerMidground + 1
  end
  if not lowSeam and minX == maxX and (minX == -Horizon.CELL
                        or minX == -2 * Horizon.CELL) then
    westOpening[minZ] = true
    local module = math.floor(route8Geometry.route8MidgroundVertices[i][4]
                              * Horizon.ROUTE8_MIDGROUND_MODULES + 0.5)
    if module < 0 or module > 3 then
      error("Route 8 west face used a non-Saffron module: " .. module)
    end
  elseif not lowSeam and minX == maxX
                            and (minX == route8Width + Horizon.CELL
                            or minX == route8Width + 2 * Horizon.CELL) then
    eastOpening[minZ] = true
    local module = math.floor(route8Geometry.route8MidgroundVertices[i][4]
                              * Horizon.ROUTE8_MIDGROUND_MODULES + 0.5)
    if module < 4 or module > 7 then
      error("Route 8 east face used a non-Lavender module: " .. module)
    end
  end
end
eq(longFaceMidground, 32,
   "Route 8 long faces did not use the sparse 10+6 cadence twice")
eq(shortFaceMidground, 30,
   "Route 8 exact west/east connector-face population changed")
eq(cornerMidground, 24,
   "Route 8 connector-corner midground continuity changed")
eq(lowCropMidground, 28,
   "Route 8 did not keep all 24 corner arms and four seam flanks low")
for _, z in ipairs({ 128, 160 }) do
  eq(westOpening[z], nil,
     "Route 8 west face closed its exact three-cell sight opening")
end
eq(westOpening[96], true,
   "Route 8 west framing opened before Saffron's real lanes")
eq(eastOpening[128], nil,
   "Route 8 east face closed its exact one-cell sight opening")
eq(eastOpening[96], true,
   "Route 8 east framing opened north of Lavender's real lane")
eq(eastOpening[160], true,
   "Route 8 east framing opened south of Lavender's real lane")
local mainPanels = 2 * (route8.def.width + route8.def.height)
local turnPanels = 8 * (Horizon.OUTDOOR_WALL_DISTANCE / Horizon.CELL)
local expectedGround = mainPanels
  * ((Horizon.OUTDOOR_WALL_DISTANCE + Horizon.CAP_DEPTH) / Horizon.CELL)
  + turnPanels * (Horizon.CAP_DEPTH / Horizon.CELL)
  + 4 * (Horizon.OUTDOOR_WALL_DISTANCE / Horizon.CELL) ^ 2
  + 4 * (Horizon.CAP_DEPTH / Horizon.CELL) ^ 2
eq(#route8Geometry.groundVertices / 4, expectedGround,
   "Route 8 curve-lattice ground budget changed")
eq(route8Geometry.quads,
   route8WallQuads + expectedGround + route8Geometry.foregroundQuads
     + route8Geometry.route8MidgroundQuads,
   "Route 8 emitted geometry outside wall/ground/foreground batches")

Horizon.setting:sync("off")
eq(#Horizon.geometry({ map = map, neighbors = {} }), 0,
   "SCENERY OFF removes the extra horizon mesh")
Horizon.setting:sync("full")

-- A connected map directly east suppresses both internal curtains. The two
-- texture classes still agree on the same deterministic world forest phase.
local east = fakeMap("ROUTE_1")
local joined = Horizon.geometry({
  map = map,
  neighbors = { { map = east, ox = map.def.width * 32, oy = 0 } },
})
eq(#joined, 2, "connected map union keeps both texture owners")
if joined[1].quads >= geometry[1].quads then
  error("connected-map overlap did not remove the internal horizon wall")
end
local sharedWorldX = map.def.width * Horizon.CELL
local sharedA = Horizon.panelUV("forest", 0, sharedWorldX, false)
local sharedB = Horizon.panelUV("forest", 0, sharedWorldX, false)
eq(sharedA, sharedB,
   "connected north walls address the same canonical forest phase")
for _, part in ipairs(joined) do
  for i = 1, #part.wallVertices, 4 do
    local a, b = part.wallVertices[i], part.wallVertices[i + 1]
    if a[3] == -Horizon.BELT and b[3] == -Horizon.BELT then
      local span = math.abs(a[4] - b[4]) * Horizon.REGIONAL_STRIP_W
      if span < 31 or span > 32 then
        error("connected forest panel collapsed its native span")
      end
    end
  end
end

-- Repeating forest profiles address A/B/C from global world segments, not
-- from each map's local origin. Connected union pieces therefore agree at
-- their shared north span, while multiple variants appear deterministically.
local forestEast = fakeMap("VIRIDIAN_FOREST")
forestEast.def.tileset = "FOREST"
local forestUnionState = {
  map = forest,
  neighbors = { { map = forestEast, ox = forest.def.width * 32, oy = 0 } },
}
local forestUnionA = Horizon.geometry(forestUnionState)
local forestUnionB = Horizon.geometry(forestUnionState)
eq(#forestUnionA, 2, "connected forest retains two texture owners")
local variants, phaseByWorld = {}, {}
for partIndex, part in ipairs(forestUnionA) do
  for vertexIndex, v in ipairs(part.wallVertices) do
    eq(v[4], forestUnionB[partIndex].wallVertices[vertexIndex][4],
       "forest world UV selection is deterministic")
    local variant = math.min(2, math.floor(
      (v[4] * Horizon.REGIONAL_STRIP_W
       - Horizon.REGIONAL_SLICES.forest.x) / Horizon.DIRECTION_W))
    variants[variant] = true
    if v[3] == -Horizon.OUTDOOR_WALL_DISTANCE then
      local worldX = part.ox + v[1]
      phaseByWorld[worldX] = phaseByWorld[worldX] or {}
      phaseByWorld[worldX][string.format("%.9f", v[4])] = true
    end
  end
end
local variantCount = 0
for _ in pairs(variants) do variantCount = variantCount + 1 end
if variantCount < 2 then error("forest belt collapsed to one repeated image") end
local sharedPhase = false
for worldX, phases in pairs(phaseByWorld) do
  if worldX >= forest.def.width * 32 - Horizon.BELT
     and worldX <= forest.def.width * 32 + Horizon.BELT then
    local n = 0
    for _ in pairs(phases) do n = n + 1 end
    if n >= 1 then sharedPhase = true break end
  end
end
eq(sharedPhase, true, "connected forest union keeps a stable world UV join")

-- GPU/cache contract: only compact sources are accepted, every bake is
-- nearest/no-mipmap, transient inputs are released immediately, and the
-- union rebuild advances cooperatively while the last closed horizon stays
-- drawable.
local oldLove = love
local canvases, sources, activeCanvas, activeColor = {}, {}, nil, nil
local graphics = {}
function graphics.newCanvas(w, h, settings)
  local c = { w = w, h = h, settings = settings, rects = {}, draws = {} }
  function c:setFilter(min, mag, anisotropy)
    self.filter = { min, mag, anisotropy }
  end
  function c:setMipmapFilter(mode) self.mipmap = mode or false end
  function c:setWrap(x, y) self.wrap = { x, y } end
  function c:release() self.released = true end
  canvases[#canvases + 1] = c
  return c
end
local dimensions = {
  ["fuji_panorama.compact.png"] = { 128, 43 },
  ["mountain_panorama.compact.png"] = { 2048, 128 },
  ["viridian_town.compact.png"] = { 512, 96 },
  ["metropolis.compact.png"] = { 512, 96 },
  ["route8_horizon.compact.png"] = { 960, 96 },
  ["route8_midground.compact.png"] = { 256, 64 },
  ["rural_edge.compact.png"] = { 512, 128 },
  ["harbor_edge.compact.png"] = { 512, 128 },
  ["mt_moon_wall.compact.png"] = { 512, 160 },
  ["mt_moon_ceiling.compact.png"] = { 256, 256 },
  ["pokemon_tower_wall.compact.png"] = { 512, 160 },
  ["pokemon_tower_ceiling.compact.png"] = { 256, 256 },
  ["pokecenter_room_wall.compact.png"] = { 128, 160 },
  ["pokecenter_room_ceiling.compact.png"] = { 128, 128 },
  ["coastal_landmarks_v3.compact.png"] = { 512, 128 },
  ["forest_edge_a.compact.png"] = { 128, 96 },
  ["forest_edge_b.compact.png"] = { 128, 96 },
  ["forest_edge_c.compact.png"] = { 128, 96 },
  ["mini_trees.compact.png"] = { 128, 64 },
}
function graphics.newImage(path, settings)
  local filename = path:match("([^/]+)$")
  local d = dimensions[filename]
  if not d then error("raw or unknown horizon image requested: " .. path) end
  local image = { path = path, w = d[1], h = d[2], settings = settings }
  function image:getDimensions() return self.w, self.h end
  function image:setFilter(min, mag, anisotropy)
    self.filter = { min, mag, anisotropy }
  end
  function image:setMipmapFilter(mode) self.mipmap = mode or false end
  function image:release() self.released = true end
  sources[#sources + 1] = image
  return image
end
function graphics.push() end
function graphics.pop() end
function graphics.origin() end
function graphics.clear() end
function graphics.setColor(r, g, b, a) activeColor = { r, g, b, a } end
function graphics.setBlendMode() end
function graphics.setCanvas(canvas) activeCanvas = canvas end
function graphics.rectangle(_, x, y, w, h)
  activeCanvas.rects[#activeCanvas.rects + 1] = {
    x, y, w, h, color = activeColor,
  }
end
function graphics.draw(image, x, y, rotation, sx, sy)
  activeCanvas.draws[#activeCanvas.draws + 1] = {
    image = image, x = x or 0, y = y or 0,
    sx = sx or 1, sy = sy or sx or 1,
  }
end
love = { graphics = graphics }

local function awaitMeshes(state, limit)
  for calls = 1, limit or 512 do
    local meshes, ready = Horizon.meshes(state)
    if ready then return meshes, calls end
  end
  error("cooperative horizon did not finish within its bounded QA window")
end

local function resetSpy()
  canvases, sources, activeCanvas, activeColor = {}, {}, nil, nil
  Horizon._resetAssetStats()
end

local function drawWith(canvas, fragment)
  for _, draw in ipairs(canvas.draws or {}) do
    if draw.image.path and draw.image.path:find(fragment, 1, true) then
      return draw
    end
  end
end

local function sourceWith(fragment)
  for _, image in ipairs(sources) do
    if image.path:find(fragment, 1, true) then return image end
  end
end

Horizon.invalidate()
resetSpy()
local baseState = { map = map, neighbors = {} }
local crispMeshes, coldCalls = awaitMeshes(baseState)
if coldCalls <= 1 then error("cold horizon unexpectedly rebuilt synchronously") end
eq(#crispMeshes, 3,
   "rural forest remains wall, ground and one batched filler draw")
eq(#canvases, 3,
   "rural forest retains skyline, ground and the shared mini-tree atlas")
local skyline = canvases[1]
eq(skyline.w, Horizon.REGIONAL_STRIP_W,
   "regional skyline packs every non-alpine family into one Canvas")
eq(skyline.h, Horizon.REGIONAL_TEXTURE_H,
   "regional skyline preserves the 128px rural/harbour source height")
eq(skyline.settings.dpiscale, 1, "skyline uses one device pixel per texel")
eq(skyline.settings.msaa, 0, "skyline source never multisamples")
eq(skyline.settings.mipmaps, "none", "skyline creates no mip chain")
eq(skyline.filter[1], "nearest", "skyline minification stays nearest")
eq(skyline.mipmap, false, "mipmap sampling is explicitly disabled")
eq(sourceWith("fuji_panorama"), nil,
   "generic forest does not decode an unrelated directional landmark")
local expectedForestX = {
  forest_edge_a = 0,
  forest_edge_b = Horizon.DIRECTION_W,
  forest_edge_c = Horizon.DIRECTION_W * 2,
}
for _, suffix in ipairs({ "forest_edge_a", "forest_edge_b", "forest_edge_c" }) do
  local source = sourceWith(suffix)
  if not source or not source.released then
    error(suffix .. " was not decoded once and released after the bake")
  end
  eq(source.filter[1], "nearest", suffix .. " source minifies nearest")
  eq(source.mipmap, false, suffix .. " source has no mipmaps")
  local draw = drawWith(skyline, suffix .. ".compact.png")
  if not draw then error(suffix .. " was not baked into the forest strip") end
  eq(draw.x, expectedForestX[suffix],
     suffix .. " starts on its exact 128px segment boundary")
  eq(draw.sx, 1, suffix .. " is baked without horizontal scaling")
  eq(draw.sy, 1, suffix .. " is baked without vertical scaling")
end
local expectedRegional = {
  viridian_town = Horizon.REGIONAL_SLICES.town.x,
  metropolis = Horizon.REGIONAL_SLICES.metropolis.x,
  rural_edge = Horizon.REGIONAL_SLICES.rural.x,
  harbor_edge = Horizon.REGIONAL_SLICES.harbor.x,
}
for suffix, expectedX in pairs(expectedRegional) do
  local source = sourceWith(suffix)
  if not source or not source.released then
    error(suffix .. " was not decoded once and released after the bake")
  end
  local draw = drawWith(skyline, suffix .. ".compact.png")
  if not draw then error(suffix .. " is missing from the regional atlas") end
  eq(draw.x, expectedX, suffix .. " starts at its fixed atlas offset")
  eq(draw.sx, 1, suffix .. " is baked without horizontal scaling")
  eq(draw.sy, 1, suffix .. " is baked without vertical scaling")
end
eq(Horizon.REGIONAL_VRAM, 2432 * 128 * 4,
   "ordinary regional maps retain their fixed atlas budget")
eq(sourceWith("mini_trees").released, true,
   "rural filler source is released after its one-time atlas bake")
eq(skyline.w * skyline.h * 4 + Horizon.CELL * Horizon.CELL * 4
   + Horizon.FOREGROUND_ATLAS_W * Horizon.FOREGROUND_ATLAS_H * 4,
   1290240, "regional rural horizon stays within its fixed 1260 KiB budget")
local previousSources, previousCanvases = #sources, #canvases
local again, againReady = Horizon.meshes(baseState)
eq(againReady, true, "ready horizon is a pure cache read")
eq(again, crispMeshes, "ready cache returns the identical mesh list")
eq(#sources, previousSources, "ready cache never decodes an image per frame")
eq(#canvases, previousCanvases, "ready cache never allocates per frame")

-- A neighbour landing starts only one eight-unit geometry slice. A cold,
-- different union must not borrow the previous map's skyline while it builds:
-- that one-frame wrong bitmap is more visible than the empty exact fallback.
local eastRural = fakeMap("ROUTE_3")
local expandedState = {
  map = map,
  neighbors = { { map = eastRural, ox = map.def.width * 32, oy = 0 } },
}
local buildsBefore = meshBuilds
local pending, expandedReady = Horizon.meshes(expandedState)
eq(expandedReady, false, "expanded union is staged instead of blocking")
eq(type(pending), "table", "pending union returns a drawable list")
eq(#pending, 0, "pending union never borrows another union's bitmap")
eq(meshBuilds, buildsBefore, "first expansion slice performs no full GPU upload")
eq(crispMeshes[1].mesh.released, nil,
   "old horizon is not released before the replacement is complete")
local fallback, fallbackReady = Horizon.meshes(baseState)
eq(fallbackReady, true, "current-only fallback remains instantly ready")
eq(fallback, crispMeshes, "fallback keeps geometry and horizon matched")
local expanded, expansionCalls = awaitMeshes(expandedState)
if expansionCalls <= 1 then error("expanded union skipped cooperative staging") end
if expanded == crispMeshes then error("expanded union never swapped atomically") end
eq(crispMeshes[1].mesh.released, nil,
   "two-entry ready cache retains the rollback horizon after swap")

Horizon.invalidate()
resetSpy()
local mountainMeshes = awaitMeshes({ map = mountain, neighbors = {} })
eq(#mountainMeshes, 2, "mountain range remains wall plus ground")
eq(canvases[1].w, Horizon.MOUNTAIN_STRIP_W,
   "mountain range retains four high-resolution fixed world bearings")
eq(canvases[1].h, Horizon.MOUNTAIN_TEXTURE_H,
   "mountain texture keeps enough vertical samples for a Retina viewport")
local mountainPanorama = drawWith(canvases[1],
                                   "mountain_panorama.compact.png")
if not mountainPanorama then
  error("mountain class lost its authored panorama atlas")
end
eq(mountainPanorama.x, 0, "mountain atlas starts at the north bearing")
eq(mountainPanorama.y, 0, "mountain atlas is grounded in its final Canvas")
eq(#canvases[1].rects, 0,
   "valid mountain art never mixes in procedural stripe layers")
eq(sourceWith("mountain_panorama").released, true,
   "mountain source is released immediately after its one-time bake")
eq(Horizon.MOUNTAIN_VRAM + Horizon.CELL * Horizon.CELL * 4, 1052672,
   "mountain panorama retains only 1028 KiB including its ground tile")

Horizon.invalidate()
resetSpy()
local palletMeshes = awaitMeshes({ map = pallet, neighbors = {} })
eq(#palletMeshes, 2, "Pallet keeps only its forest wall and closed outer ground")
eq(canvases[1].w, Horizon.REGIONAL_STRIP_W,
   "Pallet shares the one regional atlas without another draw")
eq(canvases[2].w, Horizon.VEGETATION_GROUND_PERIOD,
   "Pallet grass bakes into one broad retained Canvas")
eq(canvases[2].h, Horizon.VEGETATION_GROUND_PERIOD,
   "Pallet grass Canvas is square and world-addressable")
do
  if #canvases[2].rects < 330 then
    error("Pallet grass lost its overlapping organic undergrowth")
  end
  local sodPatches = 0
  for i, rect in ipairs(canvases[2].rects) do
    if i > 1 and (rect[3] > 13 or rect[4] > 6) then
      error("Pallet grass escaped its bounded sod/blade vocabulary")
    end
    if i > 1 and rect[3] >= 5 and rect[4] >= 2 then
      sodPatches = sodPatches + 1
    end
  end
  if sodPatches < 140 then
    error("Pallet grass lost its irregular overlapping sod islands")
  end
end
eq(sourceWith("fuji_panorama"), nil,
   "Pallet's all-forest ring does not decode an unrelated landmark")
for _, suffix in ipairs({ "forest_edge_a", "forest_edge_b", "forest_edge_c",
                           "viridian_town", "metropolis", "rural_edge",
                           "harbor_edge" }) do
  if not sourceWith(suffix) then error("Pallet lost " .. suffix) end
end
eq(sourceWith("mini_trees"), nil,
   "flush Pallet edge does not retain an unused foreground atlas")

Horizon.invalidate()
resetSpy()
local route8Meshes, route8BuildCalls = awaitMeshes({
  map = route8, neighbors = {},
})
eq(#route8Meshes, 3,
   "Route 8 remains skyline, ground and one batched midground draw")
if route8BuildCalls <= 1 or route8BuildCalls > 96 then
  error("Route 8 midground escaped its cooperative build window: "
        .. tostring(route8BuildCalls))
end
eq(canvases[1].w, Horizon.ROUTE8_STRIP_W,
   "Route 8 keeps its exact one-world-pixel strip width")
eq(canvases[1].h, Horizon.ROUTE8_TEXTURE_H,
   "Route 8 retains enough vertical source detail for Kanto silhouettes")
eq(sourceWith("route8_horizon").released, true,
   "Route 8 source is released after its dedicated one-time bake")
if drawWith(canvases[1], "route8_horizon.compact.png") == nil then
  error("Route 8 dedicated compact was not drawn into its Canvas")
end
eq(drawWith(canvases[1], "route8_midground.compact.png"), nil,
   "Route 8 midground did not duplicate into the landmark skyline")
eq(canvases[3].w, Horizon.ROUTE8_MIDGROUND_W,
   "Route 8 retains one exact-width eight-module foreground atlas")
eq(canvases[3].h, Horizon.ROUTE8_MIDGROUND_H,
   "Route 8 foreground atlas keeps native 64px vertical resolution")
eq(canvases[3].filter[1], "nearest",
   "Route 8 foreground atlas lost nearest filtering")
eq(canvases[3].mipmap, false,
   "Route 8 foreground atlas unexpectedly gained mipmaps")
if drawWith(canvases[3], "route8_midground.compact.png") == nil then
  error("Route 8 midground compact was not drawn into its retained Canvas")
end
eq(sourceWith("route8_midground").released, true,
   "Route 8 midground source is transient after its one-time bake")
eq(Horizon.ROUTE8_VRAM, 960 * 96 * 4,
   "Route 8 dedicated retained texture budget is exact")
eq(Horizon.ROUTE8_MIDGROUND_VRAM, 256 * 64 * 4,
   "Route 8 adds exactly 64 KiB of retained midground texture")
local route8MidgroundDraws = 0
for _, mesh in ipairs(route8Meshes) do
  if mesh.class == "route8-midground" then
    route8MidgroundDraws = route8MidgroundDraws + 1
    eq(mesh.kind, "foreground",
       "Route 8 midground escaped the existing foreground render path")
  end
end
eq(route8MidgroundDraws, 1,
   "Route 8 midground must remain one union-wide batched draw")

Horizon.invalidate()
resetSpy()
local viridianMeshes = awaitMeshes({ map = viridian, neighbors = {} })
eq(#viridianMeshes, 3,
   "small-town wall, ground, voxel/mini layers stay three batched draws")
eq(#canvases, 3, "small-town retains exactly skyline, ground, foreground")
eq(canvases[3].w, Horizon.FOREGROUND_ATLAS_W,
   "voxel material and four mini trees share one compact atlas")
if not drawWith(canvases[1], "viridian_town.compact.png") then
  error("small-town profile did not bake its location-specific strip")
end
eq(sourceWith("viridian_town").released, true,
   "small-town input is released after skyline bake")
eq(sourceWith("mini_trees").released, true,
   "mini-tree input is released after shared foreground bake")
eq(Horizon.REGIONAL_VRAM + 32 * 32 * 4
   + Horizon.FOREGROUND_ATLAS_W * Horizon.FOREGROUND_ATLAS_H * 4
   , 1290240,
   "small-town retained horizon stays within the fixed regional budget")

Horizon.invalidate()
resetSpy()
local metroMap = fakeMap("SAFFRON_CITY")
local metroMeshes = awaitMeshes({ map = metroMap, neighbors = {} })
eq(#metroMeshes, 2, "metropolis and lower town bake into wall plus ground")
eq(#canvases, 2, "metropolis adds no layer Canvas or draw")
if not drawWith(canvases[1], "metropolis.compact.png")
   or not drawWith(canvases[1], "viridian_town.compact.png") then
  error("metropolis profile lost its high-rise or lower-town layer")
end
eq(sourceWith("metropolis").released, true,
   "metropolis compact is released after bake")
eq(sourceWith("viridian_town").released, true,
   "lower-town compact is released after metropolis bake")
eq(Horizon.REGIONAL_VRAM + 32 * 32 * 4, 1249280,
   "metropolis retained horizon stays within the fixed regional budget")

Horizon.invalidate()
resetSpy()
local canopyMeshes, canopyBuildCalls = awaitMeshes({ map = forest, neighbors = {} })
eq(#canopyMeshes, 3, "forest wall, ground and three rows stay three draws")
if canopyBuildCalls <= 1 or canopyBuildCalls > 96 then
  error("tessellated forest canopy escaped its cooperative build budget: "
        .. tostring(canopyBuildCalls))
end
eq(#canvases, 3, "forest retains skyline, green ground and shared tree atlas")
eq(canvases[1].w, Horizon.REGIONAL_STRIP_W,
   "three forest variants share the single regional atlas")
eq(canvases[3].w, Horizon.FOREGROUND_ATLAS_W,
   "all forest belt rows share the four-tree atlas")
for _, suffix in ipairs({ "forest_edge_a", "forest_edge_b", "forest_edge_c",
                           "mini_trees" }) do
  eq(sourceWith(suffix).released, true,
     suffix .. " is transient after the forest prewarm")
end
local normalForestCopies = 0
for _, draw in ipairs(canvases[1].draws) do
  if draw.image.path and draw.image.path:find("forest_edge_", 1, true) then
    if draw.y == Horizon.REGIONAL_SLICES.forest.y then
      normalForestCopies = normalForestCopies + 1
    end
  end
end
eq(normalForestCopies, 3,
   "the rear vault reuses the ordinary vertical forest strip without a bake")
eq(Horizon.REGIONAL_VRAM + 32 * 32 * 4
   + Horizon.FOREGROUND_ATLAS_W * Horizon.FOREGROUND_ATLAS_H * 4,
   1290240, "forest retained horizon stays within 1260 KiB")

Horizon.invalidate()
resetSpy()
local caveMeshes, caveBuildCalls = awaitMeshes({
  map = largeCave, neighbors = {},
})
eq(#caveMeshes, 2,
   "large cave wall and tessellated ceiling remain exactly two batched draws")
if caveBuildCalls <= 1 or caveBuildCalls > 96 then
  error("large cave build escaped its cooperative frame budget: "
        .. tostring(caveBuildCalls))
end
eq(#canvases, 2, "cave retains only its wall and shared material Canvas")
eq(canvases[1].w, Horizon.DIRECTION_W,
   "cave wall keeps a compact repeating horizontal material")
eq(canvases[1].h, Horizon.ENCLOSURE_TEXTURE_H,
   "cave wall texture matches its tall geometry without vertical stretch")
for _, rect in ipairs(canvases[1].rects) do
  eq(rect.color[4], 1,
     "cave wall art is fully opaque and cannot reveal black pockets")
end
eq(Horizon.DIRECTION_W * Horizon.ENCLOSURE_TEXTURE_H * 4
   + Horizon.CELL * Horizon.CELL * 4,
   86016, "closed cave costs exactly 84 KiB of retained texture memory")

Horizon.invalidate()
resetSpy()
local mtMoonRuntime = fakeMap("MT_MOON_1F")
mtMoonRuntime.def.tileset = "CAVERN"
mtMoonRuntime.def.width, mtMoonRuntime.def.height =
  largeCave.def.width, largeCave.def.height
local mtMoonMeshes, mtMoonBuildCalls = awaitMeshes({
  map = mtMoonRuntime, neighbors = {},
})
eq(#mtMoonMeshes, 2,
   "Mt Moon authored wall and ceiling stay exactly two batched draws")
eq(mtMoonBuildCalls, caveBuildCalls,
   "Mt Moon assets do not change the existing geometry build budget")
eq(#canvases, 2,
   "Mt Moon retains only its existing wall and ground texture slots")
eq(canvases[1].w, Horizon.MT_MOON_WALL_W,
   "Mt Moon wall Canvas preserves the source width")
eq(canvases[1].h, Horizon.ENCLOSURE_TEXTURE_H,
   "Mt Moon wall Canvas preserves the source height")
eq(canvases[2].w, Horizon.MT_MOON_GROUND_PERIOD,
   "Mt Moon ceiling Canvas preserves its native period")
eq(canvases[2].h, Horizon.MT_MOON_GROUND_PERIOD,
   "Mt Moon ceiling Canvas preserves its native height")
eq(#canvases[1].rects, 0,
   "valid Mt Moon wall art does not mix procedural cave marks")
eq(#canvases[2].rects, 0,
   "valid Mt Moon ceiling art does not mix procedural cave marks")
for _, suffix in ipairs({ "mt_moon_wall", "mt_moon_ceiling" }) do
  local source = sourceWith(suffix)
  if not source then error(suffix .. " was not decoded") end
  eq(source.released, true, suffix .. " source is released after baking")
  eq(source.settings.mipmaps, false, suffix .. " source requests no mipmaps")
  eq(source.settings.linear, false, suffix .. " source requests nearest load")
  eq(source.filter[1], "nearest", suffix .. " minifies nearest")
  eq(source.mipmap, false, suffix .. " explicitly disables mip sampling")
end
if not drawWith(canvases[1], "mt_moon_wall.compact.png") then
  error("Mt Moon wall source was not baked into the wall Canvas")
end
if not drawWith(canvases[2], "mt_moon_ceiling.compact.png") then
  error("Mt Moon ceiling source was not baked into the ground Canvas")
end
eq(Horizon.MT_MOON_VRAM, 589824,
   "Mt Moon authored enclosure retains exactly 576 KiB")
local mtMoonSourceCount = #sources
local mtMoonAgain = awaitMeshes({ map = mtMoonRuntime, neighbors = {} })
eq(#mtMoonAgain, 2, "cached Mt Moon enclosure remains complete")
eq(#sources, mtMoonSourceCount,
   "cached Mt Moon enclosure performs no second source decode")

-- Both compact inputs fail independently to the old procedural cave material.
-- Rejected source objects are still released and the fallback is cached as a
-- successful two-draw enclosure rather than retried on every frame.
Horizon.invalidate()
resetSpy()
dimensions["mt_moon_wall.compact.png"] = { 511, 160 }
dimensions["mt_moon_ceiling.compact.png"] = { 256, 255 }
local mtMoonFallback = awaitMeshes({ map = mtMoonRuntime, neighbors = {} })
eq(#mtMoonFallback, 2,
   "malformed Mt Moon assets fail closed to a complete cave enclosure")
eq(Horizon.assetStats().rejected, 2,
   "both malformed Mt Moon inputs are dimension-rejected")
eq(#canvases[1].draws, 0,
   "rejected Mt Moon wall never reaches its retained Canvas")
eq(#canvases[2].draws, 0,
   "rejected Mt Moon ceiling never reaches its retained Canvas")
if #canvases[1].rects == 0 or #canvases[2].rects == 0 then
  error("malformed Mt Moon package did not restore procedural cave material")
end
for _, suffix in ipairs({ "mt_moon_wall", "mt_moon_ceiling" }) do
  eq(sourceWith(suffix).released, true,
     suffix .. " rejected source is released immediately")
end
local fallbackSourceCount = #sources
local mtMoonFallbackAgain = awaitMeshes({
  map = mtMoonRuntime, neighbors = {},
})
eq(#mtMoonFallbackAgain, 2, "cached Mt Moon fallback remains complete")
eq(#sources, fallbackSourceCount,
   "cached Mt Moon fallback never retries malformed sources per frame")
dimensions["mt_moon_wall.compact.png"] = { 512, 160 }
dimensions["mt_moon_ceiling.compact.png"] = { 256, 256 }

Horizon.invalidate()
resetSpy()
local towerMeshes, towerBuildCalls = awaitMeshes({ map = tower, neighbors = {} })
eq(#towerMeshes, 2,
   "tower wall and ceiling/apron remain exactly two batched draws")
if towerBuildCalls <= 1 or towerBuildCalls > 64 then
  error("Pokemon Tower escaped its cooperative build window: "
        .. tostring(towerBuildCalls))
end
eq(#canvases, 2,
   "tower authored enclosure reuses only wall and ground texture slots")
eq(canvases[1].w, Horizon.TOWER_WALL_W,
   "tower wall Canvas preserves both authored bays")
eq(canvases[1].h, Horizon.ENCLOSURE_TEXTURE_H,
   "tower wall uses the same unstretched tall texture budget")
eq(canvases[2].w, Horizon.TOWER_SURFACE_PERIOD,
   "tower ceiling Canvas preserves its broad native period")
eq(canvases[2].h, Horizon.TOWER_SURFACE_PERIOD,
   "tower ceiling Canvas remains square and world-tileable")
eq(#canvases[1].rects, 0,
   "valid tower wall art does not mix procedural brick stamps")
eq(#canvases[2].rects, 0,
   "valid tower ceiling art does not mix procedural floor stamps")
if not drawWith(canvases[1], "pokemon_tower_wall.compact.png") then
  error("Pokemon Tower wall source was not baked into the wall Canvas")
end
if not drawWith(canvases[2], "pokemon_tower_ceiling.compact.png") then
  error("Pokemon Tower ceiling source was not baked into the ground Canvas")
end
for _, suffix in ipairs({ "pokemon_tower_wall",
                           "pokemon_tower_ceiling" }) do
  local source = sourceWith(suffix)
  if not source then error(suffix .. " was not decoded") end
  eq(source.released, true, suffix .. " source is transient after baking")
  eq(source.settings.mipmaps, false, suffix .. " requests no mipmaps")
  eq(source.settings.linear, false, suffix .. " requests nearest loading")
  eq(source.filter[1], "nearest", suffix .. " minifies nearest")
  eq(source.mipmap, false, suffix .. " disables mip sampling")
end
eq(Horizon.TOWER_VRAM, 589824,
   "shared Pokemon Tower enclosure retains exactly 576 KiB")
local towerSourceCount = #sources
local towerAgain = awaitMeshes({ map = tower, neighbors = {} })
eq(#towerAgain, 2, "cached Pokemon Tower enclosure remains complete")
eq(#sources, towerSourceCount,
   "cached Pokemon Tower enclosure performs no second source decode")

-- A stale package falls back to the old opaque procedural tower rather than
-- opening a black void, and the rejected sources cannot leak or retry.
Horizon.invalidate()
resetSpy()
dimensions["pokemon_tower_wall.compact.png"] = { 511, 160 }
dimensions["pokemon_tower_ceiling.compact.png"] = { 256, 255 }
local towerFallback = awaitMeshes({ map = tower, neighbors = {} })
eq(#towerFallback, 2,
   "malformed tower art retains a complete two-draw enclosure")
eq(Horizon.assetStats().rejected, 2,
   "both malformed Pokemon Tower inputs are dimension-rejected")
eq(#canvases[1].draws, 0,
   "rejected tower wall never reaches its retained Canvas")
eq(#canvases[2].draws, 0,
   "rejected tower ceiling never reaches its retained Canvas")
if #canvases[1].rects == 0 or #canvases[2].rects == 0 then
  error("malformed tower package did not restore opaque procedural material")
end
for _, suffix in ipairs({ "pokemon_tower_wall",
                           "pokemon_tower_ceiling" }) do
  eq(sourceWith(suffix).released, true,
     suffix .. " rejected source is released immediately")
end
local towerFallbackSourceCount = #sources
local towerFallbackAgain = awaitMeshes({ map = tower, neighbors = {} })
eq(#towerFallbackAgain, 2, "cached malformed tower fallback remains complete")
eq(#sources, towerFallbackSourceCount,
   "cached malformed tower fallback never retries sources per frame")
dimensions["pokemon_tower_wall.compact.png"] = { 512, 160 }
dimensions["pokemon_tower_ceiling.compact.png"] = { 256, 256 }

Horizon.invalidate()
resetSpy()
local roomMeshes, roomBuildCalls = awaitMeshes({
  map = roomCenters[1], neighbors = {},
})
eq(#roomMeshes, 2,
   "Pokecenter room wall and ceiling/apron stay exactly two batched draws")
if roomBuildCalls <= 1 or roomBuildCalls > 64 then
  error("Pokecenter room escaped its cooperative build window: "
        .. tostring(roomBuildCalls))
end
eq(roomMeshes[1].class, "pokecenter_room",
   "room wall mesh cannot inherit a cave/tower material class")
eq(roomMeshes[2].class, "room",
   "room ground mesh retains structural room semantics")
eq(#canvases, 2,
   "both Centers share only one wall and one ceiling/apron texture slot")
eq(canvases[1].w, Horizon.POKECENTER_ROOM_WALL_W,
   "Pokecenter wall preserves its native horizontal period")
eq(canvases[1].h, Horizon.ENCLOSURE_TEXTURE_H,
   "Pokecenter wall preserves its native enclosure height")
eq(canvases[2].w, Horizon.POKECENTER_ROOM_SURFACE_PERIOD,
   "Pokecenter ceiling preserves its quiet 128px period")
eq(canvases[2].h, Horizon.POKECENTER_ROOM_SURFACE_PERIOD,
   "Pokecenter ceiling remains square and world-tileable")
eq(#canvases[1].rects, 0,
   "valid Pokecenter wall art does not mix procedural fallback marks")
eq(#canvases[2].rects, 0,
   "valid Pokecenter ceiling art does not mix procedural fallback marks")
if not drawWith(canvases[1], "pokecenter_room_wall.compact.png") then
  error("Pokecenter wall source was not baked into the wall Canvas")
end
if not drawWith(canvases[2], "pokecenter_room_ceiling.compact.png") then
  error("Pokecenter ceiling source was not baked into the ground Canvas")
end
for _, suffix in ipairs({ "pokecenter_room_wall",
                           "pokecenter_room_ceiling" }) do
  local source = sourceWith(suffix)
  if not source then error(suffix .. " was not decoded") end
  eq(source.released, true, suffix .. " source is transient after baking")
  eq(source.settings.mipmaps, false, suffix .. " requests no mipmaps")
  eq(source.settings.linear, false, suffix .. " requests nearest loading")
  eq(source.filter[1], "nearest", suffix .. " minifies nearest")
  eq(source.mipmap, false, suffix .. " disables mip sampling")
end
eq(Horizon.POKECENTER_ROOM_VRAM, 147456,
   "shared Pokecenter enclosure retains exactly 144 KiB")
eq(sourceWith("mt_moon"), nil,
   "Pokecenter room never decodes a cave-family material")

-- Missing and malformed package art fail closed to a small opaque room
-- material. They never expose black, borrow cave stone or retry every frame.
Horizon.invalidate()
resetSpy()
dimensions["pokecenter_room_wall.compact.png"] = { 127, 160 }
dimensions["pokecenter_room_ceiling.compact.png"] = { 128, 127 }
local malformedRoom = awaitMeshes({ map = roomCenters[1], neighbors = {} })
eq(#malformedRoom, 2,
   "malformed Pokecenter art retains a complete two-draw room shell")
eq(Horizon.assetStats().rejected, 2,
   "both malformed Pokecenter inputs are dimension-rejected")
eq(#canvases[1].draws, 0,
   "rejected Pokecenter wall never reaches its retained Canvas")
eq(#canvases[2].draws, 0,
   "rejected Pokecenter ceiling never reaches its retained Canvas")
if #canvases[1].rects == 0 or #canvases[2].rects == 0 then
  error("malformed Pokecenter package did not restore the opaque room fallback")
end
for _, suffix in ipairs({ "pokecenter_room_wall",
                           "pokecenter_room_ceiling" }) do
  eq(sourceWith(suffix).released, true,
     suffix .. " rejected source is released immediately")
end
local malformedSourceCount = #sources
local malformedAgain = awaitMeshes({ map = roomCenters[1], neighbors = {} })
eq(#malformedAgain, 2, "cached malformed room fallback remains complete")
eq(#sources, malformedSourceCount,
   "cached malformed room fallback never retries sources per frame")

Horizon.invalidate()
resetSpy()
dimensions["pokecenter_room_wall.compact.png"] = nil
dimensions["pokecenter_room_ceiling.compact.png"] = nil
local missingRoom = awaitMeshes({ map = roomCenters[2], neighbors = {} })
eq(#missingRoom, 2,
   "missing Pokecenter package art still returns a complete room shell")
eq(#sources, 0, "missing Pokecenter inputs retain no failed source objects")
if #canvases[1].rects == 0 or #canvases[2].rects == 0 then
  error("missing Pokecenter package exposed a transparent room surface")
end
eq(missingRoom[1].class, "pokecenter_room",
   "missing art cannot reroute the room through cave material")
dimensions["pokecenter_room_wall.compact.png"] = { 128, 160 }
dimensions["pokecenter_room_ceiling.compact.png"] = { 128, 128 }

-- SCENERY OFF exits before profile lookup, image decode, Canvas allocation or
-- a cooperative job is created.
Horizon.invalidate()
resetSpy()
Horizon.setting:sync("off")
local offMeshes, offReady = Horizon.meshes({ map = viridian, neighbors = {} })
eq(offReady, true, "SCENERY OFF needs no asynchronous work")
eq(#offMeshes, 0, "SCENERY OFF returns no horizon draw")
eq(Horizon.prewarm(viridian), true, "SCENERY OFF prewarm is a no-op")
eq(#sources, 0, "SCENERY OFF decodes zero images")
eq(#canvases, 0, "SCENERY OFF allocates zero Canvases")
eq(Horizon.buildStatus().pending, 0, "SCENERY OFF schedules zero build jobs")
Horizon.setting:sync("full")
Horizon.invalidate()
love = oldLove

local Weather = assert(loadfile("lib/Weather.lua"))(V)
eq(Weather.mode(map), "clear", "weather preserves the dry default")
Weather.setting:sync("rain")
eq(Weather.mode(map), "rain", "rain can be forced outdoors")
local room = fakeMap("REDS_HOUSE_1F")
room.def.tileset = "HOUSE"
eq(Weather.mode(room), "clear", "weather never enters interiors")
Weather.setting:sync("snow")
eq(Weather.mode(map), "snow", "snow can be forced outdoors")
Weather.setting:sync("auto")
local automatic = Weather.mode(map)
if automatic ~= "clear" and automatic ~= "rain" and automatic ~= "snow" then
  error("AUTO returned an unknown weather mode: " .. tostring(automatic))
end

print("environment controls: ok")
