local stored = { scenery = "full" }
local cache = {}

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
  elseif name == "Voxel3D" then
    cache[name] = {
      FACE_SHADE = { 0.84, 0.72, 1, 0.55, 0.90, 0.68 },
      pushQuad = function(indices, n)
        local base = n * 4
        for _, i in ipairs({ 1, 2, 3, 1, 3, 4 }) do
          indices[#indices + 1] = base + i
        end
      end,
    }
  else
    cache[name] = {}
  end
  return cache[name]
end

local TileRenderer = { voidFill = "trees" }
package.preload["src.render.TileRenderer"] = function() return TileRenderer end

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected "
          .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function fakeMap(id, width, height, outdoor, tileset)
  local block = {}
  for i = 1, 16 do block[i] = (i - 1) % 8 end
  return {
    id = id,
    def = {
      id = id, width = width or 4, height = height or 3,
      outdoor = outdoor, tileset = tileset or "OVERWORLD",
    },
    tileset = {
      blocks = { block }, tilesPerRow = 16,
      imageWidth = 128, imageHeight = 48,
    },
  }
end

local Horizon = assert(loadfile("lib/HorizonWall.lua"))(V)

-- Safari maps carry closed-map metadata in the source game, but visually they
-- are open-air reserves.  All four must reuse the existing one-pixel/world
-- forest strip and the bounded three-row mini-tree belt.
local safariIds = {
  "SAFARI_ZONE_CENTER", "SAFARI_ZONE_EAST",
  "SAFARI_ZONE_NORTH", "SAFARI_ZONE_WEST",
}
for _, id in ipairs(safariIds) do
  local map = fakeMap(id, 4, 3, false, "FOREST")
  local profile = Horizon.profileFor(map)
  eq(Horizon.classFor(map), "trees", id .. " is an outdoor forest")
  eq(Horizon.hasSky(map), true, id .. " exposes the outdoor sky")
  eq(Horizon.preferBody(map), true,
     id .. " replaces the black carved border with semantic scenery")
  eq(profile.wall, "forest", id .. " reuses the sharp forest atlas")
  eq(profile.filler, "miniTrees", id .. " reuses the mini-tree atlas")
  eq(profile.fillerRows, 3, id .. " has exactly three depth rows")

  local built = Horizon.geometry({ map = map, neighbors = {} })[1]
  local wallQuads = #built.wallVertices / 4
  eq(built.fillerQuads, wallQuads * 3,
     id .. " keeps a fixed three-quads-per-panel filler budget")
  eq(built.foregroundTrees, 0,
     id .. " adds no unbounded per-panel voxel objects")
  if built.quads > 650 then
    error(id .. " exceeded the bounded 4x3 reserve edge budget: "
          .. tostring(built.quads))
  end
end

-- Production-size Safari maps keep the existing mesh/draw budget. The corner
-- repair is an address/placement change only: no connector texture, quad or
-- retained Canvas is allowed to appear behind the visual improvement.
local safariProduction = {
  { id="SAFARI_ZONE_CENTER", width=15, height=13,
    wall=80, ground=828, filler=240, total=1148 },
  { id="SAFARI_ZONE_EAST", width=15, height=13,
    wall=80, ground=828, filler=240, total=1148 },
  { id="SAFARI_ZONE_NORTH", width=20, height=18,
    wall=100, ground=1008, filler=300, total=1408 },
  { id="SAFARI_ZONE_WEST", width=15, height=13,
    wall=80, ground=828, filler=240, total=1148 },
}
local safariBuilt = {}
for _, spec in ipairs(safariProduction) do
  local map = fakeMap(spec.id, spec.width, spec.height, false, "FOREST")
  local built = Horizon.geometry({ map=map, neighbors={} })[1]
  safariBuilt[spec.id] = { map=map, geometry=built }
  eq(#built.wallVertices / 4, spec.wall, spec.id .. " wall budget")
  eq(#built.groundVertices / 4, spec.ground, spec.id .. " ground budget")
  eq(built.fillerQuads, spec.filler, spec.id .. " filler budget")
  eq(built.quads, spec.total, spec.id .. " total quad budget")
  eq(built.wallDraws, 1, spec.id .. " keeps one regional wall family")
  eq(#built.foregroundVertices / 4, spec.filler,
     spec.id .. " keeps one batched filler quad per recorded placement")
  for i = 1, #built.wallVertices, 4 do
    local span = math.abs(built.wallVertices[i + 1][4]
                          - built.wallVertices[i][4])
                 * Horizon.REGIONAL_STRIP_W
    if span < 31 or span > 32 then
      error(spec.id .. " corner panel left native 1:1 scale: "
            .. tostring(span))
    end
  end
end

-- A/B/C/A-offset are three native panels each. The two possible arm
-- orientations must reach the same outer texel exactly, with no in-panel wrap
-- or stretch. This is the headless contract behind the paper-edge repair.
local cornerNames = { "nw", "ne", "se", "sw" }
local sharedPhases = {}
for _, corner in ipairs(cornerNames) do
  local previousEnd
  for i = 0, 2 do
    local p0, p1 = Horizon.safariCornerPanelPhases(corner, i, true)
    eq(math.abs(p1 - p0), Horizon.CELL,
       corner .. " outward-start arm keeps a native panel")
    if previousEnd ~= nil then
      eq(p0, previousEnd, corner .. " outward-start arm is continuous")
    end
    previousEnd = p1
  end
  local sharedAtStart = Horizon.safariCornerPanelPhases(corner, 0, true)
  local _, sharedAtEnd = Horizon.safariCornerPanelPhases(corner, 2, false)
  eq(sharedAtStart, sharedAtEnd,
     corner .. " orthogonal arms share one exact outer phase")
  sharedPhases[sharedAtStart] = true

  previousEnd = nil
  for i = 0, 2 do
    local p0, p1 = Horizon.safariCornerPanelPhases(corner, i, false)
    eq(math.abs(p1 - p0), Horizon.CELL,
       corner .. " outward-end arm keeps a native panel")
    if previousEnd ~= nil then
      eq(p0, previousEnd, corner .. " outward-end arm is continuous")
    end
    previousEnd = p1
  end
end
local sharedPhaseCount = 0
for _ in pairs(sharedPhases) do sharedPhaseCount = sharedPhaseCount + 1 end
eq(sharedPhaseCount, 4, "Safari's four turns use four distinct motif phases")

-- Verify the actual wall vertices, not only the helper. Every exposed corner
-- has exactly one UV at its spatial join. Row 0/1/2 then pair the outer,
-- middle and inner orthogonal mini-tree planes at one centre with identical
-- source variant and height, making three volumetric cross-billboards.
local function countKeys(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end
for _, spec in ipairs(safariProduction) do
  local built = safariBuilt[spec.id].geometry
  local w, h = spec.width * Horizon.CELL, spec.height * Horizon.CELL
  local d = Horizon.OUTDOOR_WALL_DISTANCE
  local corners = {
    { name="nw", x=-d,  z=-d,  tx=1,  tz=1 },
    { name="ne", x=w+d, z=-d,  tx=-1, tz=1 },
    { name="sw", x=-d,  z=h+d, tx=1,  tz=-1 },
    { name="se", x=w+d, z=h+d, tx=-1, tz=-1 },
  }
  for _, corner in ipairs(corners) do
    local joinUV = {}
    for _, v in ipairs(built.wallVertices) do
      if v[1] == corner.x and v[3] == corner.z then
        joinUV[string.format("%.12f", v[4])] = true
      end
    end
    eq(countKeys(joinUV), 1,
       spec.id .. " " .. corner.name .. " has one wall-join texel")

    for row = 0, 2 do
      local toward = d * (row + 1) / 4
      local expectedX = corner.x + corner.tx * toward
      local expectedZ = corner.z + corner.tz * toward
      local hits, fixedX, fixedZ = {}, false, false
      for i = 1, #built.foregroundVertices, 4 do
        local sx, sz, height = 0, 0, 0
        local sameX, sameZ = true, true
        local first = built.foregroundVertices[i]
        for j = 0, 3 do
          local v = built.foregroundVertices[i + j]
          sx, sz = sx + v[1], sz + v[3]
          height = math.max(height, v[2])
          sameX = sameX and v[1] == first[1]
          sameZ = sameZ and v[3] == first[3]
        end
        sx, sz = sx / 4, sz / 4
        if sx == expectedX and sz == expectedZ then
          hits[#hits + 1] = { u=first[4], height=height }
          fixedX, fixedZ = fixedX or sameX, fixedZ or sameZ
        end
      end
      eq(#hits, 2, spec.id .. " " .. corner.name .. " row " .. row
         .. " owns exactly two crossed planes")
      eq(hits[1].u, hits[2].u,
         spec.id .. " " .. corner.name .. " cross shares one tree variant")
      eq(hits[1].height, hits[2].height,
         spec.id .. " " .. corner.name .. " cross shares one height")
      eq(fixedX and fixedZ, true,
         spec.id .. " " .. corner.name .. " cross keeps both orientations")
    end
  end
end

-- The straight belt uses the same four cut-outs but no longer repeats one
-- four-panel signature. It remains deterministic and tightly bounded.
for _, id in ipairs(safariIds) do
  local map = safariBuilt[id] and safariBuilt[id].map
              or fakeMap(id, 15, 13, false, "FOREST")
  local styles = {}
  local breaksFourPanelCadence = false
  for ordinal = 0, 11 do
    local variant, stagger, height = Horizon.safariFillerStyle(
      map, 0, ordinal, 1)
    local againV, againS, againH = Horizon.safariFillerStyle(
      map, 0, ordinal, 1)
    eq(variant, againV, id .. " filler variant is deterministic")
    eq(stagger, againS, id .. " filler stagger is deterministic")
    eq(height, againH, id .. " filler height is deterministic")
    if variant < 0 or variant > 3 or stagger < -4 or stagger > 4
       or height < 39 or height > 56 then
      error(id .. " filler style escaped its existing atlas/size bounds")
    end
    styles[ordinal] = table.concat({ variant, stagger, height }, ":")
    if ordinal >= 4 and styles[ordinal] ~= styles[ordinal - 4] then
      breaksFourPanelCadence = true
    end
  end
  eq(breaksFourPanelCadence, true,
     id .. " straight belt no longer repeats every four panels")
end
eq(Horizon.safariFillerStyle(fakeMap("ROUTE_1"), 0, 0, 0), nil,
   "ordinary forest profiles never inherit Safari filler addressing")

-- A real streamed neighbour owns the shared edge.  It must remove both the
-- panorama and every filler plane there instead of drawing scenery through the
-- connection corridor.
local safari = fakeMap("SAFARI_ZONE_CENTER", 4, 3, false, "FOREST")
local safariEast = fakeMap("SAFARI_ZONE_EAST", 4, 3, false, "FOREST")
local safariSolo = Horizon.geometry({ map = safari, neighbors = {} })[1]
local safariJoined = Horizon.geometry({
  map = safari,
  neighbors = { { map = safariEast, ox = 4 * 32, oy = 0 } },
})[1]
if #safariJoined.wallVertices >= #safariSolo.wallVertices then
  error("Safari connection did not remove its covered panorama panels")
end
if safariJoined.fillerQuads >= safariSolo.fillerQuads then
  error("Safari connection did not remove its covered mini-tree planes")
end
local eastWallX = 4 * 32 + Horizon.BELT
for i = 1, #safariJoined.wallVertices, 4 do
  local a, b = safariJoined.wallVertices[i], safariJoined.wallVertices[i + 1]
  if a[1] == eastWallX and b[1] == eastWallX then
    local midZ = (a[3] + b[3]) / 2
    if midZ >= 0 and midZ < 3 * 32 then
      error("Safari east connection still contains a vertical curtain")
    end
  end
end

-- The dock and exposed bow are outdoor water spaces despite their source
-- tilesets. Dock's land-facing ends use the authored harbour strip while its
-- sides remain open water; the exposed bow remains open water all around.
for _, id in ipairs({ "VERMILION_DOCK", "SS_ANNE_BOW" }) do
  local map = fakeMap(id, 4, 3, false, "SHIP_PORT")
  eq(Horizon.classFor(map), "water", id .. " is an outdoor water space")
  eq(Horizon.hasSky(map), true, id .. " exposes the outdoor sky")
  eq(Horizon.preferBody(map), true,
     id .. " suppresses the black interior border extrusion")
  local expectedEdges = id == "VERMILION_DOCK"
    and { north="harbor", south="harbor",
          west="open_water", east="open_water" }
    or { north="open_water", south="open_water",
         west="open_water", east="open_water" }
  for edge, expectedClass in pairs(expectedEdges) do
    eq(Horizon.edgeClass(map, edge), expectedClass,
       id .. " free " .. edge .. " rim keeps its regional semantic")
  end

  local built = Horizon.geometry({ map = map, neighbors = {} })[1]
  local dock = id == "VERMILION_DOCK"
  if dock and #built.wallVertices == 0 then
    error("Vermilion Dock lost its north/south harbour context")
  end
  if not dock then
    eq(#built.wallVertices, 0, id .. " has no sea barricade")
    eq(#built.groundVertices, 0, id .. " adds no opaque land cap")
  end
  eq(#built.foregroundVertices, 0, id .. " adds no filler draw")
  local ray = (Horizon.BELT + Horizon.SEA_DEPTH) / Horizon.CELL
  local expected = dock and 2 * map.def.height * ray + 4 * ray * ray
                   or 2 * (map.def.width + map.def.height) * ray
                      + 4 * ray * ray
  eq(built.seaQuads, expected,
     id .. " sea tessellation remains bounded")
  if dock then
    eq(built.quads, expected + #built.wallVertices / 4
                      + #built.groundVertices / 4 + built.coastalQuads,
       id .. " adds only tiled harbour closure and one distant motif")
  else
    eq(built.quads, expected + built.coastalQuads,
       id .. " contains batched water plus one distant motif")
  end
end

-- A connected map suppresses the entire east water arm and its two outer
-- quadrants.  The west/north/south free sides continue all the way out.
local dock = fakeMap("VERMILION_DOCK", 4, 3, false, "SHIP_PORT")
local vermilion = fakeMap("VERMILION_CITY", 4, 3, true, "OVERWORLD")
local dockSolo = Horizon.geometry({ map = dock, neighbors = {} })[1]

-- Harbour north/south walls turn back to the real shoreline at all four
-- mixed wall/water corners. Their only degree-one endpoints are therefore the
-- four deliberate contacts with the sea, never a floating point out in the
-- 96px belt. Both ground and sea stay on unique 32px cells; where the water
-- continues below the two-pixel-high coast it is not coplanar with the cap.
local function cellKey(x, z) return tostring(x) .. ":" .. tostring(z) end
local wallDegree, groundCells, seaCells = {}, {}, {}
for i = 1, #dockSolo.wallVertices, 4 do
  local a, b = dockSolo.wallVertices[i], dockSolo.wallVertices[i + 1]
  local ak, bk = cellKey(a[1], a[3]), cellKey(b[1], b[3])
  wallDegree[ak], wallDegree[bk] = (wallDegree[ak] or 0) + 1,
                                   (wallDegree[bk] or 0) + 1
end
local w, h = dock.def.width * Horizon.CELL,
             dock.def.height * Horizon.CELL
local shoreline = {
  [cellKey(0, 0)] = true, [cellKey(w, 0)] = true,
  [cellKey(0, h)] = true, [cellKey(w, h)] = true,
}
for point, degree in pairs(wallDegree) do
  local expected = shoreline[point] and 1 or 2
  eq(degree, expected,
     "Dock mixed corner wall endpoint changed at " .. point)
end

local function collectCells(vertices, cells, message)
  for i = 1, #vertices, 4 do
    local minX, maxX, minZ, maxZ = math.huge, -math.huge,
                                     math.huge, -math.huge
    for j = 0, 3 do
      local v = vertices[i + j]
      minX, maxX = math.min(minX, v[1]), math.max(maxX, v[1])
      minZ, maxZ = math.min(minZ, v[3]), math.max(maxZ, v[3])
    end
    if maxX - minX > Horizon.CELL or maxZ - minZ > Horizon.CELL then
      error(message .. " escaped the 32px lattice")
    end
    local key = cellKey(minX, minZ)
    if cells[key] then error(message .. " duplicated cell " .. key) end
    cells[key] = vertices[i][2]
  end
end
collectCells(dockSolo.groundVertices, groundCells, "Dock ground")
collectCells(dockSolo.seaVertices, seaCells, "Dock sea")
for _, key in ipairs({ cellKey(-Horizon.CELL, -Horizon.CELL),
                       cellKey(w, -Horizon.CELL),
                       cellKey(-Horizon.CELL, h), cellKey(w, h) }) do
  if seaCells[key] == nil then
    error("Dock mixed corner left an empty sea cell at " .. key)
  end
end
for key, groundY in pairs(groundCells) do
  local seaY = seaCells[key]
  if seaY ~= nil and seaY == groundY then
    error("Dock mixed corner emitted coplanar ground/sea at " .. key)
  end
end

local dockJoined = Horizon.geometry({
  map = dock,
  neighbors = { { map = vermilion, ox = 4 * 32, oy = 0 } },
})[1]
if dockJoined.seaQuads >= dockSolo.seaQuads then
  error("Dock connection did not remove its covered water arm")
end
for _, v in ipairs(dockJoined.seaVertices) do
  if v[1] > 4 * 32 then
    error("Dock east connection is covered by synthesized sea")
  end
end

-- Every genuinely free edge of the southern Kanto sea belt is water.  The
-- map's inland semantic class is irrelevant, and no rock/tree wall survives.
for _, id in ipairs({
  "ROUTE_19", "ROUTE_20", "ROUTE_21", "CINNABAR_ISLAND",
}) do
  local map = fakeMap(id, 4, 3, true, "OVERWORLD")
  for _, edge in ipairs({ "north", "south", "west", "east" }) do
    eq(Horizon.edgeClass(map, edge), "open_water",
       id .. " free " .. edge .. " edge is continuous sea")
  end
  local built = Horizon.geometry({ map = map, neighbors = {} })[1]
  eq(#built.wallVertices, 0, id .. " has no free-edge barricade")
  if built.seaQuads <= 0 then error(id .. " lost its sea extension") end
end

-- Safari still reuses the regional forest slice. Harbour and coast are strict
-- compact inputs with explicit retained budgets rather than procedural walls.
eq(Horizon.IMAGE_ASSETS.safari, nil, "Safari adds no image allocation")
eq(Horizon.IMAGE_ASSETS.harbor.sourceW, 512, "harbour source width is fixed")
eq(Horizon.IMAGE_ASSETS.harbor.sourceH, 128, "harbour source height is fixed")
eq(Horizon.IMAGE_ASSETS.coastalLandmarks.sourceW, 512,
   "coastal landmark source width is fixed")
eq(Horizon.IMAGE_ASSETS.coastalLandmarks.path,
   "assets/scenery/coastal_landmarks_v3.compact.png",
   "South Sea runtime is fail-closed on the reviewed V3 atlas")
eq(Horizon.COASTAL_LANDMARK_VRAM, 512 * 128 * 4,
   "coastal landmark draw has a 256 KiB retained texture cap")

Horizon.setting:sync("off")
eq(Horizon.preferBody(safari), false, "SCENERY OFF restores normal borders")
eq(#Horizon.geometry({ map = safari, neighbors = {} }), 0,
   "SCENERY OFF emits no Safari geometry")
eq(#Horizon.geometry({ map = dock, neighbors = {} }), 0,
   "SCENERY OFF emits no dock water geometry")

print("outdoor specials and south sea: ok")
