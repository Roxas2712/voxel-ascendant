-- Viridian Forest's two warp exits receive visual-only path/gate continuations.
-- This pins the exact generated Red/Blue data, independent fail-closed gates,
-- quad/draw/VRAM budgets and byte-for-byte gameplay immutability headlessly.

local engineRoot = os.getenv("GEN1RECOMP_0190_ROOT") or "../gen1recomp"
local realMaps = assert(loadfile(engineRoot .. "/data/generated/maps.lua"))()
local realTilesets =
  assert(loadfile(engineRoot .. "/data/generated/tilesets.lua"))()
local RealMap = assert(loadfile(engineRoot .. "/src/world/Map.lua"))()

local stored = { scenery = "full" }
local cache = {}
local V = {
  path = ".",
  mod = {
    id = "VOXEL_ASCENDANT",
    options = { get = function(_, key) return stored[key] end },
  },
}

local createdMeshes = {}
function V.require(name)
  if cache[name] then return cache[name] end
  if name == "ModSetting" then
    cache[name] = assert(loadfile("lib/ModSetting.lua"))(V)
  elseif name == "Voxel3D" then
    cache[name] = {
      FACE_SHADE = { 0.84, 0.72, 1, 0.55, 0.90, 0.68 },
      newMesh = function(vertices, indices)
        local mesh = { vertices = vertices, indices = indices }
        function mesh:release() self.released = true end
        createdMeshes[#createdMeshes + 1] = mesh
        return mesh
      end,
    }
  elseif name == "WorldPlacement" then
    cache[name] = {}
  else
    cache[name] = {}
  end
  return cache[name]
end

package.preload["src.render.TileRenderer"] = function()
  return { voidFill = "trees", borderBlockFor = function() return 0 end }
end

local function expect(ok, message)
  if not ok then error(message, 2) end
end

local function eq(actual, expected, message)
  if actual ~= expected then
    error(("%s (expected %s, got %s)")
      :format(message, tostring(expected), tostring(actual)), 2)
  end
end

local function near(actual, expected, epsilon, message)
  if math.abs(actual - expected) > epsilon then
    error(("%s (expected %.12f, got %.12f)")
      :format(message, expected, actual), 2)
  end
end

local function deepCopy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local copy = {}
  seen[value] = copy
  for key, item in pairs(value) do
    copy[deepCopy(key, seen)] = deepCopy(item, seen)
  end
  return copy
end

local function shallowCopy(value)
  local copy = {}
  for key, item in pairs(value) do copy[key] = item end
  return copy
end

local function canonicalMap(defMutator, mapMutator, tilesetMutator)
  local def = deepCopy(assert(realMaps.VIRIDIAN_FOREST))
  local tileset = shallowCopy(assert(realTilesets.FOREST))
  if defMutator then defMutator(def) end
  if tilesetMutator then tilesetMutator(tileset) end
  local map = RealMap.new(def, tileset)
  if mapMutator then mapMutator(map) end
  return map
end

local function serialize(value, seen)
  local kind = type(value)
  if kind ~= "table" then return kind .. ":" .. tostring(value) end
  seen = seen or {}
  expect(not seen[value], "cyclic gameplay fixture cannot be serialized")
  seen[value] = true
  local keys = {}
  for key in pairs(value) do keys[#keys + 1] = key end
  table.sort(keys, function(a, b)
    local ak, bk = type(a), type(b)
    if ak ~= bk then return ak < bk end
    if ak == "number" or ak == "string" then return a < b end
    return tostring(a) < tostring(b)
  end)
  local out = { "{" }
  for _, key in ipairs(keys) do
    out[#out + 1] = serialize(key, seen)
    out[#out + 1] = "="
    out[#out + 1] = serialize(value[key], seen)
    out[#out + 1] = ";"
  end
  out[#out + 1] = "}"
  seen[value] = nil
  return table.concat(out)
end

local function gameplaySnapshot(map)
  local cells = {}
  for cy = 0, map.heightCells - 1 do
    for cx = 0, map.widthCells - 1 do
      local warp = map:warpAtCell(cx, cy)
      cells[#cells + 1] = table.concat({
        map:cellTile(cx, cy),
        map:isWalkableCell(cx, cy) and 1 or 0,
        warp and warp.index or 0,
      }, ":")
    end
  end
  return table.concat({
    serialize(map.def.blocks), serialize(map.def.warps),
    serialize(map.def.connections), table.concat(cells, ","),
  }, "|")
end

local Horizon = assert(loadfile("lib/HorizonWall.lua"))(V)
local gates = Horizon.VIRIDIAN_FOREST_GATES

-- Exported review spec: exact warp cells, 48px approaches and one shared
-- native-width Route 2 gate facade, mirrored only at the opposite-facing end.
local facadeSource = Horizon.FOREST_GATE_FACADE_SOURCE
eq(facadeSource.asset, "forestGateFacade",
   "Forest gatehouse stopped using the canonical Route 2 facade")
eq(facadeSource.x, 0, "Forest gatehouse compact acquired a source offset")
eq(facadeSource.y, 0, "Forest gatehouse compact acquired a source offset")
eq(facadeSource.w, 64, "Forest gatehouse stopped being native 64px wide")
eq(facadeSource.h, 40, "Forest gatehouse lost its reviewed 40px facade crop")
eq(facadeSource.alphaBBox.x0, 3,
   "Forest gatehouse alpha silhouette moved at the left edge")
eq(facadeSource.alphaBBox.x1, 61,
   "Forest gatehouse alpha silhouette moved at the right edge")
eq(facadeSource.opaquePixels, 2140,
   "Forest gatehouse alpha occupancy drifted from the canonical cut")
eq(facadeSource.doorCenterX, 24,
   "Forest gatehouse door moved within the canonical facade")
eq(Horizon.FOREST_GATE_FACADE_VRAM, 10240,
   "Forest gatehouse retained more than its exact 64x40 RGBA8 bitmap")
eq(gates.north.target, "VIRIDIAN_FOREST_NORTH_GATE",
   "north gate target drifted")
eq(#gates.north.warps, 2, "north gate lost its two canonical warp cells")
eq(gates.north.path.x0, 16, "north path moved off warp cell x=1")
eq(gates.north.path.x1, 48, "north path no longer spans two cells")
eq(gates.north.path.z0, -48, "north path lost its shallow apron")
eq(gates.north.facade.x0, 8,
   "north gatehouse lost its native-width door alignment")
eq(gates.north.facade.x1, 72,
   "north gatehouse stopped rendering at native width")
eq(gates.north.facade.x0 + facadeSource.doorCenterX, 32,
   "north gatehouse door moved off the approach centre")
eq(gates.north.facade.z, gates.north.path.z0,
   "north gatehouse detached from the path end")
eq(gates.north.facade.mirror, false,
   "north gatehouse unexpectedly mirrored")
eq(gates.south.target, "VIRIDIAN_FOREST_SOUTH_GATE",
   "south gate target drifted")
eq(#gates.south.warps, 4, "south gate lost its four canonical warp cells")
eq(gates.south.path.x0, 240, "south path moved off warp cell x=15")
eq(gates.south.path.x1, 304, "south path no longer spans four cells")
eq(gates.south.path.z1, 816, "south path lost its shallow apron")
eq(gates.south.facade.x0, 232,
   "south gatehouse lost its native-width mirrored alignment")
eq(gates.south.facade.x1, 296,
   "south gatehouse stopped rendering at native width")
eq(gates.south.facade.x0
   + facadeSource.w - facadeSource.doorCenterX, 272,
   "south mirrored gatehouse door moved off the approach centre")
eq(gates.south.facade.z, gates.south.path.z1,
   "south gatehouse detached from the path end")
eq(gates.south.facade.mirror, true,
   "south gatehouse lost its opposite-entrance mirror")
eq(Horizon.viridianForestGateSpec(0), gates.north,
   "north numeric edge resolver drifted from the exported spec")
eq(Horizon.viridianForestGateSpec(1), gates.south,
   "south numeric edge resolver drifted from the exported spec")

local forest = canonicalMap()
eq(Horizon.viridianForestGateVerified(forest, "north"), true,
   "canonical north Forest gate did not verify")
eq(Horizon.viridianForestGateVerified(forest, "south"), true,
   "canonical south Forest gate did not verify")

local before = gameplaySnapshot(forest)
local built = Horizon.geometry({ map = forest, neighbors = {} })[1]
eq(gameplaySnapshot(forest), before,
   "Forest gate visual geometry mutated map bytes, warps or collision")

-- Reconstruct the rejected 64px-tall presentation in-memory and prove that
-- reducing only the facade source height cannot perturb any other returned
-- Forest geometry, budget or metadata. Map-owner fields are references rather
-- than geometry and are already covered by gameplaySnapshot above.
local function outsideFacadeGeometry(geometry)
  local copy = {}
  for key, value in pairs(geometry) do
    if key ~= "map" and not tostring(key):match("Map$")
       and not tostring(key):match("^forestGateFacade") then
      copy[key] = value
    end
  end
  return serialize(copy)
end
local croppedOutside = outsideFacadeGeometry(built)
facadeSource.h = 64
local rejectedFullHeight = Horizon.geometry({ map = forest, neighbors = {} })[1]
facadeSource.h = 40
eq(outsideFacadeGeometry(rejectedFullHeight), croppedOutside,
   "40px gate crop changed geometry outside the two facade quads")
eq(gameplaySnapshot(forest), before,
   "legacy-height comparison mutated map bytes, warps or collision")

-- The landed perimeter vault remains byte-for-byte in budget and draw family.
eq(#built.wallVertices / 4, 106,
   "real Forest lost one of its 106 authored wall panels")
eq(built.canopyCrownQuads, 106,
   "Forest gate work changed the landed 106-quad canopy vault")
eq(built.wallDraws, 1, "Forest gate work added a wall texture/draw")
eq(#built.wallGroups[1].vertices / 4, 212,
   "gatehouse mutated the base-wall/rear-vault regional mesh")

-- Six canonical cells continue 48px at native 8px scale: 24 north + 48 south.
eq(built.forestGateEdges.north, true, "north overlay did not activate")
eq(built.forestGateEdges.south, true, "south overlay did not activate")
eq(built.forestGatePathQuads, 72,
   "Forest approaches lost their exact native-tile quad budget")
eq(built.forestGatePathQuadsByEdge.north, 24,
   "north Forest path is not 4x6 native tiles")
eq(built.forestGatePathQuadsByEdge.south, 48,
   "south Forest path is not 8x6 native tiles")
eq(#built.forestGatePathVertices, 72 * 4,
   "both Forest paths escaped their one vertex batch")
eq(#built.forestGatePathIndices, 72 * 6,
   "both Forest paths escaped their one index batch")

local pathBounds = {
  north = { math.huge, -math.huge, math.huge, -math.huge },
  south = { math.huge, -math.huge, math.huge, -math.huge },
}
local tileSize = Horizon.FOREST_GATE_PATH_TILE_SIZE
local inset = Horizon.FOREST_GATE_PATH_UV_INSET
local expectedU0, expectedV0 = inset / 128, (24 + inset) / 48
local expectedU1, expectedV1 = (8 - inset) / 128, (32 - inset) / 48
for i = 1, #built.forestGatePathVertices, 4 do
  local a, b, c = built.forestGatePathVertices[i],
                  built.forestGatePathVertices[i + 1],
                  built.forestGatePathVertices[i + 2]
  local name = a[3] < 0 and "north" or "south"
  eq(b[1] - a[1], tileSize, name .. " path stretched its atlas tile in X")
  eq(c[3] - b[3], tileSize, name .. " path stretched its atlas tile in Z")
  near(a[2], Horizon.FOREST_GATE_PATH_RISE, 1e-12,
       name .. " path lost its z-fight-safe rise")
  near(a[4], expectedU0, 1e-12, name .. " path lost $30 atlas U0")
  near(a[5], expectedV0, 1e-12, name .. " path lost $30 atlas V0")
  near(c[4], expectedU1, 1e-12, name .. " path lost $30 atlas U1")
  near(c[5], expectedV1, 1e-12, name .. " path lost $30 atlas V1")
  local bounds = pathBounds[name]
  for j = 0, 3 do
    local v = built.forestGatePathVertices[i + j]
    bounds[1], bounds[2] = math.min(bounds[1], v[1]),
                           math.max(bounds[2], v[1])
    bounds[3], bounds[4] = math.min(bounds[3], v[3]),
                           math.max(bounds[4], v[3])
  end
end
for name, expected in pairs({
  north = { 16, 48, -48, 0 }, south = { 240, 304, 768, 816 },
}) do
  for index = 1, 4 do
    eq(pathBounds[name][index], expected[index],
       name .. " Forest path escaped its exact review bounds")
  end
end

-- The two openings replace only their obscuring filler panels. The ugly
-- procedural bush/frame boxes are gone; one 1:1 PNG quad per end is returned
-- separately for the single shared gatehouse draw.
eq(built.forestGateFillerSuppressed, 15,
   "Forest openings did not suppress exactly 6 north + 9 south fillers")
eq(built.canopyFillerQuads, 303,
   "Forest retained filler count drifted from 318 - 15")
eq(built.foregroundQuads, 303,
   "Forest gatehouse changed the retained tree/filler foreground")
eq(#built.foregroundVertices, 303 * 4,
   "Forest gatehouse escaped the unchanged foreground vertex batch")
eq(#built.foregroundIndices, 303 * 6,
   "Forest gatehouse escaped the unchanged foreground index batch")
eq(built.forestGateFacadeQuads, 2,
   "north/south gatehouses are not exactly two PNG quads")
eq(#built.forestGateFacadeVertices, 2 * 4,
   "Forest gatehouses escaped their one two-quad vertex batch")
eq(#built.forestGateFacadeIndices, 2 * 6,
   "Forest gatehouses escaped their one two-quad index batch")

local gateU0, gateU1 = 0.5 / 64, 63.5 / 64
local gateV0, gateV1 = 0.5 / 40, 39.5 / 40
local northFacade = built.forestGateFacadeVertices
eq(northFacade[1][1], 8, "north gatehouse x0 drifted")
eq(northFacade[2][1], 72, "north gatehouse x1 drifted")
eq(northFacade[1][2], 0, "north gatehouse lifted off its path")
eq(northFacade[3][2], 40, "north gatehouse lost its reviewed 40px height")
eq(northFacade[1][3], -48, "north gatehouse moved off its path end")
near(northFacade[1][4], gateU0, 1e-12,
     "north gatehouse lost crop U0")
near(northFacade[2][4], gateU1, 1e-12,
     "north gatehouse lost crop U1")
near(northFacade[1][5], gateV1, 1e-12,
     "north gatehouse lost crop V1")
near(northFacade[3][5], gateV0, 1e-12,
     "north gatehouse lost crop V0")

local southFacade = built.forestGateFacadeVertices
eq(southFacade[5][1], 296,
   "south gatehouse did not reverse its facing winding")
eq(southFacade[6][1], 232,
   "south gatehouse did not reverse its facing winding")
eq(southFacade[5][2], 0, "south gatehouse lifted off its path")
eq(southFacade[7][2], 40, "south gatehouse lost its reviewed 40px height")
eq(southFacade[5][3], 816, "south gatehouse moved off its path end")
near(southFacade[5][4], gateU1, 1e-12,
     "south gatehouse left edge did not mirror the source U")
near(southFacade[6][4], gateU0, 1e-12,
     "south gatehouse right edge did not mirror the source U")
near(southFacade[5][5], gateV1, 1e-12,
     "south gatehouse lost crop V1")
near(southFacade[7][5], gateV0, 1e-12,
     "south gatehouse lost crop V0")

local plain = canonicalMap(function(def)
  def.warps[1].destMap = "EDITED_NORTH_GATE"
  def.warps[3].destMap = "EDITED_SOUTH_GATE"
end)
local plainBuilt = Horizon.geometry({ map = plain, neighbors = {} })[1]
eq(plainBuilt.canopyCrownQuads, 106,
   "failed gates changed the independent canopy vault")
eq(plainBuilt.canopyFillerQuads, 318,
   "failed gates suppressed ordinary Forest filler")
eq(plainBuilt.forestGatePathQuads, 0,
   "failed gates retained an atlas-backed path")
eq(plainBuilt.foregroundQuads, 318,
   "failed gates changed ordinary Forest foreground")
eq(plainBuilt.forestGateFacadeQuads, 0,
   "failed gates retained a PNG gatehouse")
eq(built.quads - plainBuilt.quads, 59,
   "canonical gate treatment is not net -15 fillers +72 paths +2 facades")

-- Adversarial per-edge matrix. Every failure leaves the opposite gate intact.
local edgeCases = {
  {
    name = "north target", edge = "north",
    def = function(def) def.warps[1].destMap = "EDITED" end,
  },
  {
    name = "north destination index", edge = "north",
    def = function(def) def.warps[2].destWarp = 5 end,
  },
  {
    name = "north extra boundary warp", edge = "north",
    def = function(def)
      def.warps[#def.warps + 1] = {
        x = 4, y = 0, destMap = gates.north.target, destWarp = 3,
      }
    end,
  },
  {
    name = "north source material", edge = "north",
    map = function(map)
      local base = map.tileAt
      function map:tileAt(tx, ty)
        if tx == 2 and ty == 0 then return 0x31 end
        return base(self, tx, ty)
      end
    end,
  },
  {
    name = "north walkability", edge = "north",
    map = function(map)
      local base = map.isWalkableCell
      function map:isWalkableCell(cx, cy)
        if cx == 1 and cy == 0 then return false end
        return base(self, cx, cy)
      end
    end,
  },
  {
    name = "north blocked flank", edge = "north",
    map = function(map)
      local base = map.isWalkableCell
      function map:isWalkableCell(cx, cy)
        if cx == 0 and cy == 0 then return true end
        return base(self, cx, cy)
      end
    end,
  },
  {
    name = "south target", edge = "south",
    def = function(def) def.warps[3].destMap = "EDITED" end,
  },
  {
    name = "south destination index", edge = "south",
    def = function(def) def.warps[6].destWarp = 3 end,
  },
  {
    name = "south extra boundary warp", edge = "south",
    def = function(def)
      def.warps[#def.warps + 1] = {
        x = 20, y = 47, destMap = gates.south.target, destWarp = 2,
      }
    end,
  },
  {
    name = "south source material", edge = "south",
    map = function(map)
      local base = map.tileAt
      function map:tileAt(tx, ty)
        if tx == 30 and ty == 94 then return 0x31 end
        return base(self, tx, ty)
      end
    end,
  },
  {
    name = "south walkability", edge = "south",
    map = function(map)
      local base = map.isWalkableCell
      function map:isWalkableCell(cx, cy)
        if cx == 15 and cy == 47 then return false end
        return base(self, cx, cy)
      end
    end,
  },
  {
    name = "south blocked flank", edge = "south",
    map = function(map)
      local base = map.isWalkableCell
      function map:isWalkableCell(cx, cy)
        if cx == 19 and cy == 47 then return true end
        return base(self, cx, cy)
      end
    end,
  },
}

for _, case in ipairs(edgeCases) do
  local edited = canonicalMap(case.def, case.map)
  local other = case.edge == "north" and "south" or "north"
  eq(Horizon.viridianForestGateVerified(edited, case.edge), false,
     case.name .. " did not fail closed")
  eq(Horizon.viridianForestGateVerified(edited, other), true,
     case.name .. " suppressed the independent " .. other .. " gate")
  local geometry = Horizon.geometry({ map = edited, neighbors = {} })[1]
  local expectedPath = other == "north" and 24 or 48
  local expectedSuppressed = other == "north" and 6 or 9
  eq(geometry.forestGatePathQuadsByEdge[case.edge], 0,
     case.name .. " retained its rejected path")
  eq(geometry.forestGatePathQuadsByEdge[other], expectedPath,
     case.name .. " removed the independent path")
  eq(geometry.forestGateFillerSuppressed, expectedSuppressed,
     case.name .. " changed filler outside the surviving gate")
  eq(geometry.forestGateFacadeQuads, 1,
     case.name .. " did not retain exactly one opposite-end gatehouse")
  eq(geometry.foregroundQuads, 318 - expectedSuppressed,
     case.name .. " changed ordinary foreground outside suppression")
end

-- Shared canonical guards fail both gates; none may accept an edited map shape.
local globalCases = {
  { "map id", nil, function(map) map.id = "VIRIDIAN_FOREST_EDITED" end },
  { "definition id", function(def) def.id = "VIRIDIAN_FOREST_EDITED" end },
  { "tileset", function(def) def.tileset = "OVERWORLD" end },
  { "width", function(def) def.width = 18 end },
  { "height", function(def) def.height = 25 end },
  { "connection", function(def) def.connections.north = { map = "ROUTE_2" } end },
  { "warp table", function(def) def.warps = nil end },
  { "atlas cadence", nil, nil, function(ts) ts.tilesPerRow = 8 end },
  { "atlas width", nil, nil, function(ts) ts.imageWidth = 64 end },
  { "atlas height", nil, nil, function(ts) ts.imageHeight = 96 end },
  { "tile query", nil, function(map) map.tileAt = false end },
  { "collision query", nil, function(map) map.isWalkableCell = false end },
}
for _, case in ipairs(globalCases) do
  local edited = canonicalMap(case[2], case[3], case[4])
  eq(Horizon.viridianForestGateVerified(edited, "north"), false,
     case[1] .. " edit was accepted by the north gate")
  eq(Horizon.viridianForestGateVerified(edited, "south"), false,
     case[1] .. " edit was accepted by the south gate")
end

-- Minimal LOVE graphics spy: the complete canonical runtime keeps the same
-- regional/ground/foreground textures as the no-gate forest, adds exactly one
-- 64x40 facade Canvas/two-quad draw, and retains one texture-less path mesh.
local canvases, sources, drawCalls, activeCanvas = {}, {}, {}, nil
local graphics = {}
function graphics.newCanvas(w, h, settings)
  local canvas = { w = w, h = h, settings = settings }
  function canvas:setFilter(min, mag) self.filter = { min, mag } end
  function canvas:setMipmapFilter(mode) self.mipmap = mode or false end
  function canvas:setWrap(x, y) self.wrap = { x, y } end
  function canvas:release() self.released = true end
  canvases[#canvases + 1] = canvas
  return canvas
end
local dimensions = {
  ["forest_edge_a.compact.png"] = { 128, 96 },
  ["forest_edge_b.compact.png"] = { 128, 96 },
  ["forest_edge_c.compact.png"] = { 128, 96 },
  ["viridian_town.compact.png"] = { 512, 96 },
  ["metropolis.compact.png"] = { 512, 96 },
  ["rural_edge.compact.png"] = { 512, 128 },
  ["harbor_edge.compact.png"] = { 512, 128 },
  ["mini_trees.compact.png"] = { 128, 64 },
  ["route8_midground.compact.png"] = { 256, 64 },
  ["viridian_forest_gate.compact.png"] = { 64, 40 },
}
function graphics.newImage(path, settings)
  local filename = path:match("([^/]+)$")
  local size = dimensions[filename]
  if not size then error("unexpected Forest gate asset " .. tostring(path)) end
  local image = { path = path, w = size[1], h = size[2], settings = settings }
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
function graphics.rectangle()
  expect(activeCanvas ~= nil, "Forest texture painter lost its bound Canvas")
end
function graphics.draw(image, x, y)
  expect(activeCanvas ~= nil, "Forest asset bake lost its bound Canvas")
  drawCalls[#drawCalls + 1] = {
    image = image, x = x or 0, y = y or 0, canvas = activeCanvas,
  }
end
love = { graphics = graphics }

Horizon.invalidate()
createdMeshes = {}
local rims, ready
for _ = 1, 10000 do
  rims, ready = Horizon.meshes({ map = forest, neighbors = {} })
  if ready then break end
end
eq(ready, true, "canonical Forest gate runtime build did not complete")
local pathDraws, pathRim, foregroundDraws, wallDraws = 0, nil, 0, 0
local facadeDraws, facadeRim = 0, nil
for _, rim in ipairs(rims) do
  if rim.kind == "forest-gate-path" then
    pathDraws, pathRim = pathDraws + 1, rim
  elseif rim.kind == "forest-gate-facade" then
    facadeDraws, facadeRim = facadeDraws + 1, rim
  elseif rim.kind == "foreground" and rim.class == "canopy" then
    foregroundDraws = foregroundDraws + 1
    eq(#rim.mesh.vertices, 303 * 4,
       "gatehouse changed the one canopy foreground runtime mesh")
  elseif rim.kind == "wall" then
    wallDraws = wallDraws + 1
  end
end
eq(pathDraws, 1, "north/south Forest paths added more than one draw")
eq(pathRim.textureMap, forest,
   "Forest path draw lost its live FOREST terrain-atlas owner")
eq(pathRim.texture, nil, "Forest path draw retained a duplicate bitmap")
eq(#pathRim.mesh.vertices, 72 * 4,
   "Forest runtime path mesh lost its exact 72-quad batch")
eq(#pathRim.mesh.indices, 72 * 6,
   "Forest runtime path mesh lost its exact index batch")
eq(foregroundDraws, 1,
   "Forest gatehouse changed the existing foreground texture draw")
eq(wallDraws, 1, "Forest gate runtime changed the one-draw canopy vault")
eq(facadeDraws, 1,
   "north/south gatehouses did not aggregate into exactly one draw")
eq(#facadeRim.mesh.vertices, 2 * 4,
   "runtime gatehouse mesh is not exactly two quads")
eq(#facadeRim.mesh.indices, 2 * 6,
   "runtime gatehouse mesh lost its exact index budget")
eq(facadeRim.texture.w, 64,
   "runtime gatehouse stopped retaining the native-width facade")
eq(facadeRim.texture.h, 40,
   "runtime gatehouse stopped retaining the reviewed-height facade")
eq(#canvases, 4,
   "Forest gatehouse allocation is not exactly +1 tiny Canvas")
local tinyCanvases = 0
for _, canvas in ipairs(canvases) do
  if canvas.w == 64 and canvas.h == 40 then
    tinyCanvases = tinyCanvases + 1
    eq(canvas.filter[1], "nearest",
       "Forest gatehouse crop lost nearest filtering")
    eq(canvas.wrap[1], "clamp", "Forest gatehouse crop lost clamp wrapping")
  end
end
eq(tinyCanvases, 1, "Forest retained more than one 64x40 gatehouse Canvas")
local cropDraws = 0
for _, draw in ipairs(drawCalls) do
  if draw.image.path:match("viridian_forest_gate%.compact%.png$") then
    cropDraws = cropDraws + 1
    eq(draw.x, 0, "Forest gatehouse copied the wrong source X")
    eq(draw.y, 0, "Forest gatehouse copied the wrong source Y")
    eq(draw.canvas.w, 64, "Forest gatehouse escaped its exact Canvas")
    eq(draw.canvas.h, 40, "Forest gatehouse escaped its exact Canvas")
  end
end
eq(cropDraws, 1, "Forest gatehouse decoded/copied its source more than once")
eq(Horizon.IMAGE_EXTRA_VRAM, 2254848,
   "Forest gatehouse VRAM is not the fixed budget plus exactly 10240 bytes")

-- A missing/malformed shared PNG must fail the exact horizon key rather than
-- publish paths with an absent building or retry the decode every frame.
dimensions["viridian_forest_gate.compact.png"] = { 64, 64 }
Horizon.invalidate()
createdMeshes = {}
local badReady, badFailed = false, false
for _ = 1, 10000 do
  _, badReady, badFailed = Horizon.meshes({ map = forest, neighbors = {} })
  if badReady or badFailed then break end
end
eq(badReady, false, "malformed Forest gatehouse source published a scene")
eq(badFailed, true, "malformed Forest gatehouse source did not fail closed")
eq(Horizon.buildStatus().failed, 1,
   "malformed Forest gatehouse source was not terminally cached")
dimensions["viridian_forest_gate.compact.png"] = { 64, 40 }
Horizon.invalidate()

print("forest gate overlays: ok")
