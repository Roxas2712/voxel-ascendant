-- Canonical OVERWORLD -> cave doors receive one fail-closed volumetric
-- portal stamp.  This test uses the real generated Red map/tileset/ledge data
-- and proves visual geometry never mutates gameplay authority.

local engineRoot = os.getenv("GEN1RECOMP_0190_ROOT") or "../gen1recomp"
local realMaps = assert(loadfile(engineRoot .. "/data/generated/maps.lua"))()
local realTilesets =
  assert(loadfile(engineRoot .. "/data/generated/tilesets.lua"))()
local realField =
  assert(loadfile(engineRoot .. "/data/generated/field.lua"))()
local RealMap = assert(loadfile(engineRoot .. "/src/world/Map.lua"))()

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
        map:isDoorTileCell(cx, cy) and 1 or 0,
        warp and warp.index or 0,
        warp and warp.def.destMap or "-",
        warp and warp.def.destWarp or 0,
      }, ":")
    end
  end
  return table.concat({
    serialize(map.def.blocks), serialize(map.def.warps),
    serialize(map.def.connections), table.concat(cells, ","),
  }, "|")
end

local assetRequests = {}
package.preload["src.render.Assets"] = function()
  return {
    imageData = function(path)
      assetRequests[#assetRequests + 1] = path
      error("pixel access intentionally unavailable in portal geometry test")
    end,
    register = function() end,
  }
end
package.preload["src.world.Map"] = function() return RealMap end
package.preload["src.render.TileRenderer"] = function()
  return {
    voidFill = "trees",
    borderBlockFor = function(map)
      if map.def.tileset == "OVERWORLD" then return 0x0f end
      return map.def.borderBlock
    end,
  }
end
package.preload["src.core.Game"] = function()
  return { data = { field = realField } }
end

local loaded, createdMeshes = {}, {}
local V = { path = "." }
function V.data(name)
  return assert(loadfile("data/" .. name .. ".lua"))()
end
function V.require(name)
  if loaded[name] then return loaded[name] end
  if name == "Voxel3D" then
    loaded[name] = {
      FORMAT = {},
      FACE_SHADE = { 0.84, 0.72, 1, 0.55, 0.90, 0.68 },
      pushQuad = function(indices, quad)
        local base = quad * 4
        for _, index in ipairs({ 1, 2, 3, 1, 3, 4 }) do
          indices[#indices + 1] = base + index
        end
      end,
      newMesh = function(vertices, indices)
        local mesh = { vertices = vertices, indices = indices }
        function mesh:release() self.released = true end
        createdMeshes[#createdMeshes + 1] = mesh
        return mesh
      end,
      canInstance = function() return false end,
    }
  elseif name == "ModSetting" then
    loaded[name] = { new = function()
      return { get = function() return true end }
    end }
  else
    loaded[name] = assert(loadfile("lib/" .. name .. ".lua"))(V)
  end
  return loaded[name]
end

local Structures = V.require("Structures")
local Mesher = V.require("ChunkMesher")
local LedgeElevation = V.require("LedgeElevation")
local PORTAL_QUADS = 20
local ROUTE4_PORTAL_QUADS = 22
local ROUTE4_STEP_QUADS = 16
local ROUTE4_CHEEK_QUADS = 0
eq(Mesher._CAVE_PORTAL_QUADS, PORTAL_QUADS,
   "portal geometry budget constant drifted")
eq(Mesher._CAVE_PORTAL_ROUTE4_QUADS, ROUTE4_PORTAL_QUADS,
   "Route 4 depth-course budget constant drifted")
eq(Mesher._CAVE_PORTAL_ROUTE4_STEP_QUADS, ROUTE4_STEP_QUADS,
   "Route 4 stepped-shoulder budget constant drifted")
eq(Mesher._CAVE_PORTAL_ROUTE4_CHEEK_QUADS, ROUTE4_CHEEK_QUADS,
   "Route 4 removed-cheek budget constant drifted")

local expected = {
  CERULEAN_CITY = {
    [7] = { 4, 11, "CERULEAN_CAVE_1F", 1, 0x37, 0x37, 0x39 },
  },
  ROUTE_10 = {
    [2] = { 8, 17, "ROCK_TUNNEL_1F", 1, 0x37, 0x37, 0x2c },
    [3] = { 8, 53, "ROCK_TUNNEL_1F", 3, 0x37, 0x37, 0x39 },
  },
  ROUTE_11 = {
    [5] = { 4, 5, "DIGLETTS_CAVE_ROUTE_11", 1, 0x37, 0x37, 0x39 },
  },
  ROUTE_2 = {
    [1] = { 12, 9, "DIGLETTS_CAVE_ROUTE_2", 1, 0x37, 0x37, 0x39 },
  },
  ROUTE_20 = {
    [1] = { 48, 5, "SEAFOAM_ISLANDS_1F", 1, 0x37, 0x37, 0x3c },
    [2] = { 58, 9, "SEAFOAM_ISLANDS_1F", 3, 0x37, 0x37, 0x3c },
  },
  ROUTE_4 = {
    [2] = { 18, 5, "MT_MOON_1F", 1, 0x37, 0x37, 0x39 },
    [3] = { 24, 5, "MT_MOON_B1F", 8, 0x24, 0x37, 0x39 },
  },
}

local function realMap(id, defMutator, mapMutator)
  local source = assert(realMaps[id], "missing real map " .. id)
  local def = deepCopy(source)
  if defMutator then defMutator(def) end
  local map = RealMap.new(def, assert(realTilesets[def.tileset] or
                                      realTilesets.OVERWORLD))
  if mapMutator then mapMutator(map) end
  return map
end

local function keyOf(tx, ty)
  return (ty + 64) * 4096 + (tx + 64)
end

local function expectedCount(rows)
  local n = 0
  for _ in pairs(rows) do n = n + 1 end
  return n
end

local function axisDistance(a, b)
  local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
  return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function uvDistance(a, b)
  local du, dv = (b[4] - a[4]) * 128, (b[5] - a[5]) * 48
  return math.sqrt(du * du + dv * dv)
end

local function hasMarker(value, markers)
  for _, marker in ipairs(markers) do
    if math.abs(value - marker) < 1e-9 then return true end
  end
  return false
end

local function portalGeometry(vertices, stamp, base, route4V2)
  local x0, z0 = stamp.cx * 16, stamp.cy * 16
  local backZ = z0 + 0.25
  local xMarkers = { x0 + 0.25, x0 + 15.75 }
  local zMarkers = { backZ, backZ + 8, backZ + 12 }
  local frontZ = backZ + 12
  if route4V2 then
    zMarkers[#zMarkers + 1] = backZ + 20
    frontZ = backZ + 20
  end
  zMarkers[#zMarkers + 1] = frontZ + 2
  local found = {}
  for at = 1, #vertices, 4 do
    local quad = { vertices[at], vertices[at + 1],
                   vertices[at + 2], vertices[at + 3] }
    local inside, marked = true, false
    local onOuterX0, onOuterX1 = true, true
    for _, vertex in ipairs(quad) do
      if vertex[1] < x0 - 1e-9 or vertex[1] > x0 + 16 + 1e-9
          or vertex[2] < base - 1e-9
          or vertex[2] > base + 16 + 1e-9
          -- Route 4's exterior backshield ends at the authored terminal
          -- plane. It is deliberately not part of the unchanged 20-quad
          -- front/reveal budget measured by this helper.
          or vertex[3] < backZ - 1e-9
          or vertex[3] > frontZ + 2 + 1e-9 then
        inside = false
      end
      marked = marked or hasMarker(vertex[1], xMarkers)
                      or hasMarker(vertex[3], zMarkers)
      onOuterX0 = onOuterX0 and math.abs(vertex[1] - x0) < 1e-9
      onOuterX1 = onOuterX1 and math.abs(vertex[1] - (x0 + 16)) < 1e-9
    end
    -- Warp #3's additive west shoulder has two east returns on x0. They are
    -- outside the tunnel union even though one endpoint shares backZ.
    if inside and marked and not onOuterX0 and not onOuterX1 then
      found[#found + 1] = quad
    end
  end
  return found
end

local function route4V2(mapId, index)
  return mapId == "ROUTE_4" and (index == 2 or index == 3)
end

local function portalQuadBudget(mapId, index)
  return route4V2(mapId, index) and ROUTE4_PORTAL_QUADS or PORTAL_QUADS
end

local function quadBounds(quad)
  local out = {
    math.huge, math.huge, math.huge,
    -math.huge, -math.huge, -math.huge,
  }
  for _, vertex in ipairs(quad) do
    for axis = 1, 3 do
      out[axis] = math.min(out[axis], vertex[axis])
      out[axis + 3] = math.max(out[axis + 3], vertex[axis])
    end
  end
  return out
end

local function quadSignature(quad)
  local parts = {}
  for _, vertex in ipairs(quad) do
    parts[#parts + 1] = ("%.6f,%.6f,%.6f")
      :format(vertex[1], vertex[2], vertex[3])
  end
  table.sort(parts)
  return table.concat(parts, "|")
end

local function allQuads(vertices)
  local out = {}
  for at = 1, #vertices, 4 do
    out[#out + 1] = { vertices[at], vertices[at + 1],
                      vertices[at + 2], vertices[at + 3] }
  end
  return out
end

local function constantAxis(quad, axis, value)
  for _, vertex in ipairs(quad) do
    if math.abs(vertex[axis] - value) > 1e-9 then return false end
  end
  return true
end

local function quadNormal(quad)
  local a, b, c = quad[1], quad[2], quad[3]
  local ux, uy, uz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
  local vx, vy, vz = c[1] - a[1], c[2] - a[2], c[3] - a[3]
  return uy * vz - uz * vy,
         uz * vx - ux * vz,
         ux * vy - uy * vx
end

local function tileForQuad(quad)
  local u, v = 0, 0
  for _, vertex in ipairs(quad) do
    u, v = u + vertex[4], v + vertex[5]
  end
  local column = math.floor((u / 4 * 128) / 8)
  local row = math.floor((v / 4 * 48) / 8)
  return row * 16 + column
end

local function route4ShieldGeometry(vertices, stamp, base, northTop)
  local x0, z0 = stamp.cx * 16, stamp.cy * 16
  local backZ, portalTop = z0 + 0.25, base + 16
  local found = { north = {}, sides = {}, tops = {}, all = {} }
  for _, quad in ipairs(allQuads(vertices)) do
    local b = quadBounds(quad)
    local inside = b[1] >= x0 - 1e-9 and b[4] <= x0 + 16 + 1e-9
      and b[2] >= northTop - 1e-9 and b[5] <= portalTop + 1e-9
      and b[3] >= z0 - 1e-9 and b[6] <= backZ + 1e-9
    local group
    if inside and constantAxis(quad, 3, z0)
        and b[5] > northTop + 1e-9 then
      group = found.north
    elseif inside and math.abs(b[3] - z0) < 1e-9
        and math.abs(b[6] - backZ) < 1e-9
        and (constantAxis(quad, 1, x0)
          or constantAxis(quad, 1, x0 + 16)) then
      group = found.sides
    elseif inside and constantAxis(quad, 2, portalTop)
        and math.abs(b[3] - z0) < 1e-9
        and math.abs(b[6] - backZ) < 1e-9 then
      group = found.tops
    end
    if group then
      group[#group + 1] = quad
      found.all[#found.all + 1] = quad
    end
  end
  return found
end

local function boundsMatch(bounds, expected)
  for axis = 1, 6 do
    if math.abs(bounds[axis] - expected[axis]) > 1e-9 then return false end
  end
  return true
end

local function route4StepGeometry(vertices, stamp, base)
  local x0, z0 = stamp.cx * 16, stamp.cy * 16
  local backZ = z0 + 0.25
  local sx0, lowerTop = x0 - 8, base + 8
  local portalTop, ridgeTop = base + 16, 16
  local lowerSouth, upperSouth = z0 + 8, backZ
  local notchX, notchTop = x0 - 4, portalTop - 4
  local specs = {
    lowerSouth = { sx0, 8, lowerSouth, x0, lowerTop, lowerSouth },
    lowerEastRearFoot = { x0, base, z0, x0, 8, backZ },
    lowerEastRear = { x0, 8, z0, x0, lowerTop, backZ },
    lowerEastFoot = { x0, base, backZ, x0, 8, lowerSouth },
    lowerEast = { x0, 8, backZ, x0, lowerTop, lowerSouth },
    lowerTopWest = { sx0, lowerTop, upperSouth,
                     notchX, lowerTop, lowerSouth },
    lowerTopEast = { notchX, lowerTop, upperSouth,
                     x0, lowerTop, lowerSouth },
    upperSouthWest = { sx0, lowerTop, upperSouth,
                       notchX, portalTop, upperSouth },
    upperSouthCrown = { notchX, notchTop, upperSouth,
                        x0, portalTop, upperSouth },
    upperWest = { sx0, ridgeTop, z0, sx0, portalTop, upperSouth },
    upperNorthWest = { sx0, ridgeTop, z0,
                       notchX, portalTop, z0 },
    upperNorthCrown = { notchX, notchTop, z0,
                        x0, portalTop, z0 },
    notchWall = { notchX, lowerTop, z0,
                  notchX, notchTop, backZ },
    notchCeiling = { notchX, notchTop, z0,
                     x0, notchTop, backZ },
    upperTopWest = { sx0, portalTop, z0,
                     notchX, portalTop, upperSouth },
    upperTopEast = { notchX, portalTop, z0,
                     x0, portalTop, upperSouth },
  }
  local found = { all = {} }
  for name in pairs(specs) do found[name] = {} end
  for _, quad in ipairs(allQuads(vertices)) do
    local bounds = quadBounds(quad)
    for name, expectedBounds in pairs(specs) do
      if boundsMatch(bounds, expectedBounds) then
        found[name][#found[name] + 1] = quad
        found.all[#found.all + 1] = quad
      end
    end
  end
  return found
end

local function containsPoint(quad, x, y, z)
  for _, vertex in ipairs(quad) do
    if math.abs(vertex[1] - x) < 1e-9
        and math.abs(vertex[2] - y) < 1e-9
        and math.abs(vertex[3] - z) < 1e-9 then
      return vertex
    end
  end
  return nil
end

local function curveY(x, y, z, focusX, focusZ, k)
  local dx, dz = x - focusX, z - focusZ
  return y - (dx * dx + dz * dz) * k
end

local function assertCurveSafeJoin(a, b, x, y, z, message)
  local av = containsPoint(a, x, y, z)
  local bv = containsPoint(b, x, y, z)
  expect(av, message .. " missing first endpoint")
  expect(bv, message .. " missing second endpoint")
  -- WorldCurve changes only Y as a deterministic function of X/Z. Sharing
  -- the exact source vertex therefore remains watertight for every camera
  -- focus; use an off-centre, nonzero fixture to pin that shader contract.
  near(curveY(av[1], av[2], av[3], 173.25, 91.75, 0.00031),
       curveY(bv[1], bv[2], bv[3], 173.25, 91.75, 0.00031), 0,
       message .. " split under WorldCurve")
end

local function assertCurveSafeTJoin(edge, surface, x0, y0, z0,
                                    x1, y1, z1, message)
  for at, point in ipairs({ { x0, y0, z0 }, { x1, y1, z1 } }) do
    expect(containsPoint(edge, point[1], point[2], point[3]),
           message .. " missing edge endpoint " .. at)
    local lo, hi = math.huge, -math.huge
    for _, vertex in ipairs(surface) do
      if math.abs(vertex[1] - point[1]) < 1e-9
          and math.abs(vertex[3] - point[3]) < 1e-9 then
        lo, hi = math.min(lo, vertex[2]), math.max(hi, vertex[2])
      end
    end
    expect(lo <= point[2] + 1e-9 and hi >= point[2] - 1e-9,
           message .. " escaped complementary face " .. at)
    -- WorldCurve's displacement depends only on X/Z.  A T-junction at an
    -- intermediate Y therefore receives exactly the same displacement as the
    -- two vertical face endpoints and cannot pull away under a nonzero bend.
    local focusX, focusZ, k = 173.25, 91.75, 0.00031
    near(curveY(point[1], point[2], point[3], focusX, focusZ, k)
           - point[2],
         curveY(point[1], lo, point[3], focusX, focusZ, k) - lo, 0,
         message .. " split under WorldCurve at endpoint " .. at)
  end
end

local function positiveOverlap(a0, a1, b0, b1)
  return math.min(a1, b1) - math.max(a0, b0) > 1e-9
end

local totalStamps, totalPortalQuads = 0, 0
for mapId, rows in pairs(expected) do
  local map = realMap(mapId)
  local before = gameplaySnapshot(map)
  Structures.invalidate(mapId)
  local structures = Structures.forMap(map)
  eq(#structures.portalStamps, expectedCount(rows),
     mapId .. " canonical portal count")
  local mapPortalBudget = 0
  for index in pairs(rows) do
    mapPortalBudget = mapPortalBudget + portalQuadBudget(mapId, index)
  end
  expect(mapPortalBudget <= 2 * ROUTE4_PORTAL_QUADS,
         mapId .. " portal stamps escaped the two-door quad budget")

  -- Pin the exact real source evidence rather than trusting the allow-list.
  for index, row in pairs(rows) do
    local cx, cy = row[1], row[2]
    local placed = assert(map:warpAtCell(cx, cy))
    eq(placed.index, index, mapId .. " real warp index")
    eq(placed.def.destMap, row[3], mapId .. " real destination")
    eq(placed.def.destWarp, row[4], mapId .. " real destination warp")
    eq(map:cellTile(cx, cy), 0x58, mapId .. " portal collision tile")
    expect(map:isDoorTileCell(cx, cy), mapId .. " portal ceased to be a door")
    expect(map:isWalkableCell(cx, cy), mapId .. " portal ceased to be walkable")
    local quadrants, at = { 0x48, 0x49, 0x58, 0x59 }, 1
    for dy = 0, 1 do
      for dx = 0, 1 do
        eq(map:tileAt(cx * 2 + dx, cy * 2 + dy), quadrants[at],
           mapId .. " authored 16x16 portal art")
        at = at + 1
      end
    end
    eq(map:cellTile(cx, cy - 1), 0x11, mapId .. " north cliff gate")
    expect(not map:isWalkableCell(cx, cy - 1), mapId .. " north flank opened")
    eq(map:cellTile(cx - 1, cy), row[5], mapId .. " west cliff gate")
    expect(not map:isWalkableCell(cx - 1, cy), mapId .. " west flank opened")
    eq(map:cellTile(cx + 1, cy), row[6], mapId .. " east cliff gate")
    expect(not map:isWalkableCell(cx + 1, cy), mapId .. " east flank opened")
    eq(map:cellTile(cx, cy + 1), row[7], mapId .. " south approach tile")
    expect(map:isWalkableCell(cx, cy + 1), mapId .. " south approach closed")
  end

  local stampsByIndex = {}
  for _, stamp in ipairs(structures.portalStamps) do
    stampsByIndex[stamp.warpIndex] = stamp
    local row = assert(rows[stamp.warpIndex], "unexpected canonical stamp")
    eq(stamp.cx, row[1], mapId .. " stamp x moved")
    eq(stamp.cy, row[2], mapId .. " stamp y moved")
    eq(stamp.target, row[3], mapId .. " stamp destination moved")
    for dy = 0, 1 do
      for dx = 0, 1 do
        local tx, ty = stamp.baseTx + dx, stamp.baseTy + dy
        expect(not structures.doorFold[keyOf(tx, ty)],
               mapId .. " cave portal leaked back into generic doorFold")
        eq(structures.topTileAt[keyOf(tx, ty)],
           map:tileAt(tx, ty + 2),
           mapId .. " tunnel floor is not the exact south continuation")
      end
    end
  end

  local vertices, indices, quads = Mesher.geometry(map, true)
  eq(#vertices, quads * 4, mapId .. " terrain vertex accounting")
  eq(#indices, quads * 6, mapId .. " terrain index accounting")
  local elevation = Mesher.elevation(map)
  for index, row in pairs(rows) do
    local stamp = assert(stampsByIndex[index])
    local base = elevation:atTile(stamp.baseTx, stamp.baseTy)
    for dy = 0, 1 do
      for dx = 0, 1 do
        eq(elevation:atTile(stamp.baseTx + dx, stamp.baseTy + dy), base,
           mapId .. " portal footprint crossed a ledge datum")
        eq(elevation:atTile(stamp.baseTx + dx, stamp.baseTy + 2 + dy), base,
           mapId .. " south continuation crossed the rigid portal datum")
      end
    end
    local portal = portalGeometry(vertices, stamp, base,
                                  route4V2(mapId, index))
    eq(#portal, portalQuadBudget(mapId, index),
       mapId .. " exact tunnel quad count")
    totalPortalQuads = totalPortalQuads + #portal

    local minY, maxY = math.huge, -math.huge
    local backTiles, signatures = {}, {}
    for _, quad in ipairs(portal) do
      for _, vertex in ipairs(quad) do
        minY, maxY = math.min(minY, vertex[2]), math.max(maxY, vertex[2])
      end
      -- Every axis-aligned portal edge retains one world pixel per source
      -- texel; the only difference is ChunkMesher's standard .02 inset at
      -- both ends to prevent atlas bleed.
      for edge = 1, 2 do
        local world = axisDistance(quad[edge], quad[edge + 1])
        local texels = uvDistance(quad[edge], quad[edge + 1])
        near(texels, world - 0.04, 1e-9,
             mapId .. " portal UV was stretched")
      end

      local parts = {}
      for _, vertex in ipairs(quad) do
        parts[#parts + 1] = ("%.3f,%.3f,%.3f")
          :format(vertex[1], vertex[2], vertex[3])
      end
      table.sort(parts)
      local signature = table.concat(parts, "|")
      expect(not signatures[signature], mapId .. " portal contains z-fight twins")
      signatures[signature] = true

      local backZ = stamp.cy * 16 + 0.25
      local rear = true
      for _, vertex in ipairs(quad) do
        rear = rear and math.abs(vertex[3] - backZ) < 1e-9
      end
      if rear then
        local u, v = 0, 0
        for _, vertex in ipairs(quad) do
          u, v = u + vertex[4], v + vertex[5]
        end
        local column = math.floor((u / 4 * 128) / 8)
        local atlasRow = math.floor((v / 4 * 48) / 8)
        backTiles[#backTiles + 1] = atlasRow * 16 + column
      end
    end
    eq(minY, base, mapId .. " portal did not use one rigid base")
    eq(maxY, base + 16, mapId .. " portal height changed")
    table.sort(backTiles)
    eq(table.concat(backTiles, ","), "72,73,88,89",
       mapId .. " rear terminal lost its authored four tiles")
    totalStamps = totalStamps + 1
  end
  eq(gameplaySnapshot(map), before,
     mapId .. " portal analysis/geometry mutated gameplay data")
end

eq(totalStamps, 9, "canonical outdoor cave portal population")
eq(totalPortalQuads, 7 * PORTAL_QUADS + 2 * ROUTE4_PORTAL_QUADS,
   "global canonical portal geometry budget")

-- The two Route 4 portals prove rigid placement on different ledge courses.
do
  local map = realMap("ROUTE_4")
  Structures.invalidate("ROUTE_4")
  local structures = Structures.forMap(map)
  local elevation = Mesher.elevation(map)
  local bases, stampsByIndex = {}, {}
  for _, stamp in ipairs(structures.portalStamps) do
    bases[stamp.warpIndex] = elevation:atTile(stamp.baseTx, stamp.baseTy)
    stampsByIndex[stamp.warpIndex] = stamp
  end
  eq(bases[2], 12, "Mt Moon 1F portal lost Route 4's upper datum")
  eq(bases[3], 6, "Mt Moon B1F portal lost Route 4's lower datum")

  -- Route 4 is the only canonical map where the north cliff ends below the
  -- portal terminal: absolute Y=16 leaves 12px exposed at warp #2 and 6px at
  -- warp #3. The exterior backshields remain intact; V2 appends one complete
  -- 8px low-jamb course after the canonical 8px+4px pair, then translates only
  -- the shallow threshold to the new front. Its upper half remains open from
  -- either three-quarter approach. Warp #3's separately gated west shoulder
  -- binds the retained backshield cap into its real neighbouring ridge.
  local vertices, indices, terrainQuads = Mesher.geometry(map, true)
  eq(#vertices, terrainQuads * 4, "Route 4 shield vertex accounting")
  eq(#indices, terrainQuads * 6, "Route 4 shield index accounting")
  local geometry = allQuads(vertices)
  local signatureCounts = {}
  for _, quad in ipairs(geometry) do
    local signature = quadSignature(quad)
    signatureCounts[signature] = (signatureCounts[signature] or 0) + 1
  end

  local shieldSpecs = {
    [2] = {
      total = 10, north = 4, sides = 4, tops = 2,
      intervals = "16-20,16-20,20-28,20-28",
    },
    [3] = {
      total = 6, north = 2, sides = 2, tops = 2,
      intervals = "16-22,16-22",
    },
  }

  local function intervalList(quads)
    local intervals = {}
    for _, quad in ipairs(quads) do
      local b = quadBounds(quad)
      intervals[#intervals + 1] = { b[2], b[5] }
    end
    table.sort(intervals, function(a, b)
      return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2])
    end)
    local out = {}
    for _, interval in ipairs(intervals) do
      out[#out + 1] = ("%g-%g"):format(interval[1], interval[2])
    end
    return table.concat(out, ",")
  end

  local function assertNoCoplanarOverlap(quads, planeAxis, firstAxis,
                                         secondAxis, label)
    for _, quad in ipairs(quads) do
      local b = quadBounds(quad)
      local plane = quad[1][planeAxis]
      local signature = quadSignature(quad)
      eq(signatureCounts[signature], 1, label .. " has a z-fight twin")
      for _, other in ipairs(geometry) do
        if quadSignature(other) ~= signature
            and constantAxis(other, planeAxis, plane) then
          local ob = quadBounds(other)
          local overlap = positiveOverlap(b[firstAxis], b[firstAxis + 3],
                                          ob[firstAxis], ob[firstAxis + 3])
            and positiveOverlap(b[secondAxis], b[secondAxis + 3],
                                ob[secondAxis], ob[secondAxis + 3])
          expect(not overlap, label .. " overlaps existing coplanar geometry")
        end
      end
    end
  end

  local shieldQuads, stepQuads = 0, 0
  local canonicalCores = {}
  local function coreDigest(quads, frontOfCore)
    local signatures = {}
    for _, quad in ipairs(quads) do
      local bounds = quadBounds(quad)
      if bounds[6] <= frontOfCore + 1e-9 then
        local fields = {}
        for _, vertex in ipairs(quad) do
          fields[#fields + 1] = ("%.6f,%.6f,%.6f,%.9f,%.9f,%.6f")
            :format(vertex[1], vertex[2], vertex[3], vertex[4], vertex[5],
                    vertex[6])
        end
        signatures[#signatures + 1] = table.concat(fields, "|")
      end
    end
    table.sort(signatures)
    eq(#signatures, 16, "Route 4 canonical rear/reveal core budget")
    return table.concat(signatures, "\n")
  end
  for index, spec in pairs(shieldSpecs) do
    local stamp = assert(stampsByIndex[index])
    local base = bases[index]
    local x0, z0 = stamp.cx * 16, stamp.cy * 16
    local backZ, portalTop = z0 + 0.25, base + 16
    local portal = portalGeometry(vertices, stamp, base, true)
    local shield = route4ShieldGeometry(vertices, stamp, base, 16)
    eq(#portal, ROUTE4_PORTAL_QUADS,
       "Route 4 warp #" .. index .. " front geometry changed")
    eq(#shield.all, spec.total,
       "Route 4 warp #" .. index .. " shield quad budget")
    eq(#shield.north, spec.north,
       "Route 4 warp #" .. index .. " north shield segmentation")
    eq(#shield.sides, spec.sides,
       "Route 4 warp #" .. index .. " diagonal side returns")
    eq(#shield.tops, spec.tops,
       "Route 4 warp #" .. index .. " top returns")
    eq(intervalList(shield.north), spec.intervals,
       "Route 4 warp #" .. index .. " north 8px vertical phase")
    eq(intervalList(shield.sides), spec.intervals,
       "Route 4 warp #" .. index .. " side 8px vertical phase")
    shieldQuads = shieldQuads + #shield.all

    -- Four authored terminal tiles + the two unchanged six-quad core courses,
    -- two lower outer-jamb faces and four sill quads account for the exact
    -- 22-quad V3 mouth. The canonical 8px/4px partitions stay byte-stable.
    local courseEnds = { { 0, 8 }, { 8, 12 } }
    for course, interval in ipairs(courseEnds) do
      local count = 0
      for _, quad in ipairs(portal) do
        local b = quadBounds(quad)
        if math.abs(b[3] - (backZ + interval[1])) < 1e-9
            and math.abs(b[6] - (backZ + interval[2])) < 1e-9 then
          count = count + 1
          eq(tileForQuad(quad), 0x11,
             "Route 4 depth course stopped using retained rock $11")
        end
      end
      eq(count, 6, "Route 4 warp #" .. index
        .. " depth course " .. course .. " quad budget")
    end
    local outerStart, outerEnd = backZ + 12, backZ + 20
    local outer = {}
    for _, quad in ipairs(portal) do
      local b = quadBounds(quad)
      if math.abs(b[3] - outerStart) < 1e-9
          and math.abs(b[6] - outerEnd) < 1e-9 then
        outer[#outer + 1] = quad
        near(b[2], base, 1e-9,
             "Route 4 outer shoulder lost its rigid base")
        near(b[5], base + 8, 1e-9,
             "Route 4 outer shoulder stopped at the wrong height")
        expect(constantAxis(quad, 1, x0 + 0.25)
            or constantAxis(quad, 1, x0 + 15.75),
          "Route 4 outer shoulder stopped being a side jamb")
        eq(tileForQuad(quad), 0x11,
           "Route 4 outer shoulder stopped using retained rock $11")
      end
    end
    eq(#outer, 2, "Route 4 warp #" .. index
      .. " low outer-jamb quad budget")

    -- Nothing in the additive depth may close the upper half or recreate the
    -- rejected full-height cuboid/roof. The unchanged inner course still owns
    -- the complete 16px frame behind this intentionally open sightline.
    for _, quad in ipairs(portal) do
      local b = quadBounds(quad)
      local spansOuter = positiveOverlap(b[3], b[6], outerStart, outerEnd)
      if spansOuter then
        expect(b[5] <= base + 8 + 1e-9,
          "Route 4 outer course blocked the upper three-quarter sightline")
        expect(not constantAxis(quad, 2, base + 16),
          "Route 4 outer course regrew a full-height roof")
      end
    end

    -- Both lower jambs continue the canonical lower side at the old front
    -- with identical source vertices, so WorldCurve cannot open that step.
    for _, outerQuad in ipairs(outer) do
      local ob = quadBounds(outerQuad)
      local x = ob[1]
      local inner
      for _, candidate in ipairs(portal) do
        local b = quadBounds(candidate)
        if constantAxis(candidate, 1, x)
            and math.abs(b[2] - base) < 1e-9
            and math.abs(b[5] - (base + 8)) < 1e-9
            and math.abs(b[3] - (backZ + 8)) < 1e-9
            and math.abs(b[6] - outerStart) < 1e-9 then
          inner = candidate
        end
      end
      expect(inner, "Route 4 outer shoulder lost its canonical neighbour")
      assertCurveSafeJoin(inner, outerQuad, x, base, outerStart,
        "Route 4 outer shoulder lower seam")
      assertCurveSafeJoin(inner, outerQuad, x, base + 8, outerStart,
        "Route 4 outer shoulder crown seam")
      assertNoCoplanarOverlap({ outerQuad }, 1, 2, 3,
        "Route 4 warp #" .. index .. " outer shoulder")
    end
    local threshold, maxZ = 0, -math.huge
    for _, quad in ipairs(portal) do
      local b = quadBounds(quad)
      maxZ = math.max(maxZ, b[6])
      if b[3] >= backZ + 20 - 1e-9 then threshold = threshold + 1 end
    end
    eq(threshold, 4,
       "Route 4 warp #" .. index .. " translated threshold budget")
    near(maxZ, backZ + 22, 1e-9,
         "Route 4 warp #" .. index .. " V2 front depth")
    canonicalCores[index] = coreDigest(portal, backZ + 12)

    for _, quad in ipairs(shield.all) do
      eq(tileForQuad(quad), 0x11,
         "Route 4 backshield stopped using retained rock $11")
      for edge = 1, 2 do
        local world = axisDistance(quad[edge], quad[edge + 1])
        local texels = uvDistance(quad[edge], quad[edge + 1])
        near(texels, world - 0.04, 1e-9,
             "Route 4 backshield UV was stretched")
      end
      local b = quadBounds(quad)
      expect(b[6] <= backZ + 1e-9,
             "Route 4 backshield entered the front-facing tunnel")
    end

    for _, quad in ipairs(shield.north) do
      local b = quadBounds(quad)
      near(b[4] - b[1], 8, 1e-9,
           "Route 4 north shield lost its 8px horizontal crop")
      expect(b[5] - b[2] <= 8 + 1e-9,
             "Route 4 north shield exceeded one vertical atlas course")
    end
    for _, quad in ipairs(shield.sides) do
      local b = quadBounds(quad)
      near(b[6] - b[3], 0.25, 1e-9,
           "Route 4 side return exceeded the terminal nudge")
      expect(b[5] - b[2] <= 8 + 1e-9,
             "Route 4 side return exceeded one vertical atlas course")
    end
    for _, quad in ipairs(shield.tops) do
      local b = quadBounds(quad)
      near(b[4] - b[1], 8, 1e-9,
           "Route 4 top return lost its 8px horizontal crop")
      near(b[6] - b[3], 0.25, 1e-9,
           "Route 4 top return exceeded the terminal nudge")
    end

    -- A positive-area intersection on any shield plane would flicker with
    -- culling disabled. Shared edges are intentional and have zero area.
    assertNoCoplanarOverlap(shield.north, 3, 1, 2,
      "Route 4 warp #" .. index .. " north shield")
    assertNoCoplanarOverlap(shield.sides, 1, 2, 3,
      "Route 4 warp #" .. index .. " side return")
    assertNoCoplanarOverlap(shield.tops, 2, 1, 3,
      "Route 4 warp #" .. index .. " top return")

    -- Each exposed band turns the north plane around the outer corner, and
    -- each 8px column turns across the roof to the unchanged rear terminal.
    -- The joins use identical X/Y/Z endpoints, so Voxel3D's quadratic
    -- WorldCurve displaces both sides by exactly the same amount.
    for _, north in ipairs(shield.north) do
      local nb = quadBounds(north)
      local outerX = nb[1] < x0 + 8 - 1e-9 and x0 or x0 + 16
      local side
      for _, candidate in ipairs(shield.sides) do
        local cb = quadBounds(candidate)
        if constantAxis(candidate, 1, outerX)
            and math.abs(cb[2] - nb[2]) < 1e-9
            and math.abs(cb[5] - nb[5]) < 1e-9 then
          side = candidate
        end
      end
      expect(side, "Route 4 north band lacks its diagonal return")
      assertCurveSafeJoin(north, side, outerX, nb[2], z0,
        "Route 4 shield lower diagonal seam")
      assertCurveSafeJoin(north, side, outerX, nb[5], z0,
        "Route 4 shield upper diagonal seam")
    end

    for column = 0, 1 do
      local xa, xb = x0 + column * 8, x0 + (column + 1) * 8
      local northCap, topReturn, rearTerminal
      for _, candidate in ipairs(shield.north) do
        local b = quadBounds(candidate)
        if math.abs(b[1] - xa) < 1e-9 and math.abs(b[4] - xb) < 1e-9
            and math.abs(b[5] - portalTop) < 1e-9 then
          northCap = candidate
        end
      end
      for _, candidate in ipairs(shield.tops) do
        local b = quadBounds(candidate)
        if math.abs(b[1] - xa) < 1e-9 and math.abs(b[4] - xb) < 1e-9 then
          topReturn = candidate
        end
      end
      for _, candidate in ipairs(portal) do
        local b = quadBounds(candidate)
        if constantAxis(candidate, 3, backZ)
            and math.abs(b[1] - xa) < 1e-9
            and math.abs(b[4] - xb) < 1e-9
            and math.abs(b[5] - portalTop) < 1e-9 then
          rearTerminal = candidate
        end
      end
      expect(northCap and topReturn and rearTerminal,
             "Route 4 top return lost a curve-safe neighbour")
      assertCurveSafeJoin(northCap, topReturn, xa, portalTop, z0,
        "Route 4 shield west roof seam")
      assertCurveSafeJoin(northCap, topReturn, xb, portalTop, z0,
        "Route 4 shield east roof seam")
      assertCurveSafeJoin(topReturn, rearTerminal, xa, portalTop, backZ,
        "Route 4 terminal west roof seam")
      assertCurveSafeJoin(topReturn, rearTerminal, xb, portalTop, backZ,
        "Route 4 terminal east roof seam")
    end

    if index == 3 then
      local step = route4StepGeometry(vertices, stamp, base)
      eq(#step.all, ROUTE4_STEP_QUADS,
         "Route 4 warp #3 stepped-shoulder budget")
      stepQuads = stepQuads + #step.all

      local function one(group, label)
        eq(#group, 1, "Route 4 step " .. label .. " face count")
        return group[1]
      end
      local lowerSouth = one(step.lowerSouth, "lower south")
      local lowerEastRearFoot =
        one(step.lowerEastRearFoot, "lower east rear foot")
      local lowerEastRear = one(step.lowerEastRear, "lower east rear")
      local lowerEastFoot = one(step.lowerEastFoot, "lower east foot")
      local lowerEast = one(step.lowerEast, "lower east")
      local lowerTopWest = one(step.lowerTopWest, "lower west top")
      local lowerTopEast = one(step.lowerTopEast, "lower east top")
      local upperSouthWest = one(step.upperSouthWest, "upper south west")
      local upperSouthCrown = one(step.upperSouthCrown,
                                  "upper south crown")
      local upperWest = one(step.upperWest, "upper west complement")
      local upperNorthWest = one(step.upperNorthWest, "upper north west")
      local upperNorthCrown = one(step.upperNorthCrown,
                                  "upper north crown")
      local notchWall = one(step.notchWall, "notch inner wall")
      local notchCeiling = one(step.notchCeiling, "notch ceiling")
      local upperTopWest = one(step.upperTopWest, "upper west cap")
      local upperTopEast = one(step.upperTopEast, "upper east cap")

      local stepNames = {}
      for _, name in ipairs({ "lowerSouth", "lowerEastRearFoot",
                              "lowerEastRear", "lowerEastFoot", "lowerEast",
                              "lowerTopWest", "lowerTopEast",
                              "upperSouthWest", "upperSouthCrown",
                              "upperWest", "upperNorthWest",
                              "upperNorthCrown", "notchWall",
                              "notchCeiling", "upperTopWest",
                              "upperTopEast" }) do
        stepNames[quadSignature(step[name][1])] = name
      end
      for _, quad in ipairs(step.all) do
        eq(tileForQuad(quad), 0x11,
           "Route 4 step stopped using retained rock $11")
        for edge = 1, 2 do
          local world = axisDistance(quad[edge], quad[edge + 1])
          local texels = uvDistance(quad[edge], quad[edge + 1])
          near(texels, world - 0.04, 1e-9,
               "Route 4 step UV was stretched")
        end

        local axis
        for candidate = 1, 3 do
          if constantAxis(quad, candidate, quad[1][candidate]) then
            expect(axis == nil, "Route 4 step emitted a degenerate face")
            axis = candidate
          end
        end
        expect(axis ~= nil, "Route 4 step emitted a non-axis-aligned face")
        local firstAxis = axis == 1 and 2 or 1
        local secondAxis = axis == 3 and 2 or 3
        assertNoCoplanarOverlap({ quad }, axis, firstAxis, secondAxis,
          "Route 4 warp #3 stepped shoulder "
            .. tostring(stepNames[quadSignature(quad)]))
      end

      local function matchingFaces(expectedBounds)
        local found = {}
        for _, candidate in ipairs(geometry) do
          if boundsMatch(quadBounds(candidate), expectedBounds) then
            found[#found + 1] = candidate
          end
        end
        return found
      end

      -- The failed V3.1 addition must be absent, not merely hidden behind the
      -- new cut.  These are its two exact real-map bounds.
      eq(#matchingFaces({ x0, 8, z0 + 8, x0, 14, z0 + 16 }), 0,
         "Route 4 warp #3 retained the V3.1 low-cheek east face")
      eq(#matchingFaces({ x0 - 8, 14, z0 + 8, x0, 14, z0 + 16 }), 0,
         "Route 4 warp #3 retained the V3.1 low-cheek top")

      -- The two main courses are native 8px voxels.  Cropped complements are
      -- allowed only where an existing ridge/backshield already owns the rest.
      local lowerSouthBounds = quadBounds(lowerSouth)
      near(lowerSouthBounds[4] - lowerSouthBounds[1], 8, 1e-9,
           "Route 4 lower shoulder lost native width")
      near(lowerSouthBounds[5] - lowerSouthBounds[2], 6, 1e-9,
           "Route 4 lower shoulder ignored south-ridge complement")
      local lowerEastBounds = quadBounds(lowerEast)
      local lowerEastRearBounds = quadBounds(lowerEastRear)
      near((lowerEastBounds[6] - lowerEastBounds[3])
             + (lowerEastRearBounds[6] - lowerEastRearBounds[3]),
           8, 1e-9, "Route 4 lower shoulder lost native depth")
      local lowerEastFootBounds = quadBounds(lowerEastFoot)
      local lowerEastRearFootBounds = quadBounds(lowerEastRearFoot)
      near((lowerEastFootBounds[6] - lowerEastFootBounds[3])
             + (lowerEastRearFootBounds[6] - lowerEastRearFootBounds[3]),
           8, 1e-9, "Route 4 lower shoulder foot lost native depth")
      local sx0, lowerTop = x0 - 8, base + 8
      local notchX, notchTop = x0 - 4, portalTop - 4
      local lowerSouthZ, upperSouthZ = z0 + 8, backZ
      for _, face in ipairs({ lowerTopWest, lowerTopEast,
                              upperSouthWest, upperSouthCrown,
                              upperNorthWest, upperNorthCrown,
                              notchWall, notchCeiling,
                              upperTopWest, upperTopEast }) do
        local b = quadBounds(face)
        expect(b[4] - b[1] <= 4 + 1e-9,
               "Route 4 notch escaped native 4px X phase")
      end
      local notchWallBounds, notchCeilingBounds =
        quadBounds(notchWall), quadBounds(notchCeiling)
      near(notchWallBounds[5] - notchWallBounds[2], 4, 1e-9,
           "Route 4 notch wall lost 4px height")
      near(notchWallBounds[6] - notchWallBounds[3], 0.25, 1e-9,
           "Route 4 notch wall left the recessed step")
      near(notchCeilingBounds[4] - notchCeilingBounds[1], 4, 1e-9,
           "Route 4 notch ceiling lost 4px width")
      near(notchCeilingBounds[6] - notchCeilingBounds[3], 0.25, 1e-9,
           "Route 4 notch ceiling left the recessed step")
      local wallNX = quadNormal(notchWall)
      local _, ceilingNY = quadNormal(notchCeiling)
      local _, capNY = quadNormal(upperTopEast)
      expect(wallNX > 0, "Route 4 notch wall faces into retained rock")
      expect(ceilingNY * capNY < 0,
             "Route 4 notch ceiling did not reverse the cap winding")

      -- No south-facing rock may refill the exact 4x4 aperture.  This pins
      -- negative space, not a copied black terminal.
      for _, candidate in ipairs(geometry) do
        if constantAxis(candidate, 3, backZ) then
          local b = quadBounds(candidate)
          local fillsNotch = positiveOverlap(b[1], b[4], notchX, x0)
            and positiveOverlap(b[2], b[5], lowerTop, notchTop)
          expect(not fillsNotch,
                 "Route 4 warp #3 4px air notch was refilled")
        end
      end

      -- Internal step edges, the west backshield return and the top cap all
      -- share exact source vertices. WorldCurve therefore cannot tear them
      -- apart at a nonzero camera-relative bend.
      assertCurveSafeJoin(lowerSouth, lowerEast, x0, 8, lowerSouthZ,
        "Route 4 lower shoulder south/east complement")
      assertCurveSafeJoin(lowerSouth, lowerEast, x0, lowerTop, lowerSouthZ,
        "Route 4 lower shoulder south/east crown")
      assertCurveSafeJoin(lowerEastRearFoot, lowerEastFoot,
        x0, base, backZ, "Route 4 lower shoulder east foot depth split")
      assertCurveSafeJoin(lowerEastRear, lowerEast, x0, lowerTop, backZ,
        "Route 4 lower shoulder east crown depth split")
      assertCurveSafeJoin(lowerEastRearFoot, lowerEastRear, x0, 8, z0,
        "Route 4 lower shoulder rear vertical split")
      assertCurveSafeJoin(lowerEastRearFoot, lowerEastRear, x0, 8, backZ,
        "Route 4 lower shoulder rear/sill split")
      assertCurveSafeJoin(lowerEastFoot, lowerEast, x0, 8, backZ,
        "Route 4 lower shoulder front/sill split")
      assertCurveSafeJoin(lowerEastFoot, lowerEast, x0, 8, lowerSouthZ,
        "Route 4 lower shoulder front vertical split")
      assertCurveSafeJoin(lowerTopWest, lowerTopEast,
        notchX, lowerTop, upperSouthZ,
        "Route 4 lower cap north split")
      assertCurveSafeJoin(lowerTopWest, lowerTopEast,
        notchX, lowerTop, lowerSouthZ,
        "Route 4 lower cap south split")
      assertCurveSafeJoin(lowerTopWest, upperSouthWest,
        sx0, lowerTop, upperSouthZ,
        "Route 4 west step ledge")
      assertCurveSafeJoin(lowerTopWest, upperSouthWest,
        notchX, lowerTop, upperSouthZ,
        "Route 4 notch west foot")
      assertCurveSafeJoin(lowerTopWest, notchWall,
        notchX, lowerTop, upperSouthZ,
        "Route 4 notch inner foot")
      assertCurveSafeTJoin(upperSouthCrown, upperSouthWest,
        notchX, notchTop, upperSouthZ,
        notchX, portalTop, upperSouthZ,
        "Route 4 notch south vertical split")
      assertCurveSafeJoin(notchWall, notchCeiling,
        notchX, notchTop, z0, "Route 4 notch northwest ceiling")
      assertCurveSafeJoin(notchWall, notchCeiling,
        notchX, notchTop, backZ, "Route 4 notch southwest ceiling")
      assertCurveSafeJoin(notchCeiling, upperSouthCrown,
        notchX, notchTop, upperSouthZ,
        "Route 4 notch south-west crown")
      assertCurveSafeJoin(notchCeiling, upperSouthCrown,
        x0, notchTop, upperSouthZ,
        "Route 4 notch south-east crown")
      assertCurveSafeJoin(notchCeiling, upperNorthCrown,
        notchX, notchTop, z0,
        "Route 4 notch north-west crown")
      assertCurveSafeJoin(notchCeiling, upperNorthCrown,
        x0, notchTop, z0,
        "Route 4 notch north-east crown")
      assertCurveSafeTJoin(upperNorthCrown, upperNorthWest,
        notchX, notchTop, z0,
        notchX, portalTop, z0,
        "Route 4 notch north vertical split")
      assertCurveSafeJoin(upperNorthWest, upperWest, sx0, 16, z0,
        "Route 4 ridge/step lower corner")
      assertCurveSafeJoin(upperNorthWest, upperWest, sx0, portalTop, z0,
        "Route 4 ridge/step upper corner")
      assertCurveSafeJoin(upperTopWest, upperTopEast,
        notchX, portalTop, z0, "Route 4 upper cap north split")
      assertCurveSafeJoin(upperTopWest, upperTopEast,
        notchX, portalTop, backZ, "Route 4 upper cap south split")
      assertCurveSafeJoin(upperTopWest, upperSouthWest,
        sx0, portalTop, backZ, "Route 4 upper west cap/south")
      assertCurveSafeJoin(upperTopWest, upperSouthWest,
        notchX, portalTop, backZ, "Route 4 upper split cap/south")
      assertCurveSafeJoin(upperTopEast, upperSouthCrown,
        notchX, portalTop, backZ, "Route 4 notch crown cap west")
      assertCurveSafeJoin(upperTopEast, upperSouthCrown,
        x0, portalTop, backZ, "Route 4 notch crown cap east")

      local westReturn, westCap
      for _, candidate in ipairs(shield.sides) do
        local b = quadBounds(candidate)
        if constantAxis(candidate, 1, x0)
            and math.abs(b[2] - 16) < 1e-9
            and math.abs(b[5] - portalTop) < 1e-9 then
          westReturn = candidate
        end
      end
      for _, candidate in ipairs(shield.tops) do
        local b = quadBounds(candidate)
        if math.abs(b[1] - x0) < 1e-9 then westCap = candidate end
      end
      expect(westReturn and westCap,
             "Route 4 step lost its retained backshield neighbours")
      assertCurveSafeTJoin(notchCeiling, westReturn,
        x0, notchTop, z0, x0, notchTop, backZ,
        "Route 4 notch ceiling/backshield return")
      assertCurveSafeJoin(upperTopEast, westCap, x0, portalTop, z0,
        "Route 4 shoulder/shield-cap north join")
      assertCurveSafeJoin(upperTopEast, westCap, x0, portalTop, backZ,
        "Route 4 shoulder/shield-cap south join")
    end
  end

  eq(shieldQuads, 16, "Route 4 aggregate backshield budget")
  eq(stepQuads, ROUTE4_STEP_QUADS,
     "Route 4 aggregate stepped-shoulder budget")
  eq(ROUTE4_CHEEK_QUADS, 0, "Route 4 V3.1 cheek was not removed")
  eq(2 * ROUTE4_PORTAL_QUADS + shieldQuads + stepQuads, 76,
     "Route 4 aggregate portal geometry budget")
  eq(totalPortalQuads + shieldQuads + stepQuads, 216,
     "global portal geometry including Route 4 V3.2 notch")

  -- Height gating is independent from Structures' canonical ROM/data gate.
  -- Perturb one analysed datum at a time without changing a map byte or the
  -- retained portal stamps: only that mouth must fall back to the established
  -- 12px/20-quad tunnel. The other Route 4 mouth and both backshields remain
  -- V2/stable; #3's notched step additionally requires every adjoining
  -- terrain height that supplies an intentionally omitted solid face.
  local rawElevationMap = LedgeElevation.map
  local heightFailures = {
    { label = "warp #2 west flank", index = 2,
      tx = stampsByIndex[2].baseTx - 1, ty = stampsByIndex[2].baseTy },
    { label = "warp #3 outer-west ridge", index = 3,
      tx = stampsByIndex[3].baseTx - 2, ty = stampsByIndex[3].baseTy },
    { label = "warp #3 north-west ridge", index = 3,
      tx = stampsByIndex[3].baseTx - 1, ty = stampsByIndex[3].baseTy - 1 },
    { label = "warp #3 south-west ridge", index = 3,
      tx = stampsByIndex[3].baseTx - 1, ty = stampsByIndex[3].baseTy + 1 },
  }
  for _, failure in ipairs(heightFailures) do
    LedgeElevation.map = function(candidate)
      local authority = rawElevationMap(candidate)
      if candidate ~= map then return authority end
      return {
        atTile = function(_, tx, ty)
          local value = authority:atTile(tx, ty)
          if tx == failure.tx and ty == failure.ty then return value + 1 end
          return value
        end,
      }
    end

    local failedVertices = Mesher.geometry(map, true)
    LedgeElevation.map = rawElevationMap
    for index = 2, 3 do
      local stamp = stampsByIndex[index]
      local enabled = index ~= failure.index
      local portal = portalGeometry(failedVertices, stamp, bases[index], enabled)
      eq(#portal, enabled and ROUTE4_PORTAL_QUADS or PORTAL_QUADS,
         failure.label .. " did not selectively fail closed")
      local backZ = stamp.cy * 16 + 0.25
      eq(coreDigest(portal, backZ + 12), canonicalCores[index],
         failure.label .. " changed the canonical rear/reveal core")
      local failedShield = route4ShieldGeometry(
        failedVertices, stamp, bases[index], 16)
      eq(#failedShield.all, shieldSpecs[index].total,
         failure.label .. " removed the retained backshield")
    end

    local failedStep = route4StepGeometry(
      failedVertices, stampsByIndex[3], bases[3])
    eq(#failedStep.all,
       failure.index == 3 and 0 or ROUTE4_STEP_QUADS,
       failure.label .. " applied the stepped shoulder outside its gate")
  end
  LedgeElevation.map = rawElevationMap

  -- The Pokecenter at warp #1 remains an ordinary building door and therefore
  -- cannot be counted as a cave portal or by its terrain stamp path.
  local center = assert(map:warpAtCell(11, 5))
  eq(center.index, 1, "Route 4 Center fixture moved")
  eq(center.def.destMap, "MT_MOON_POKECENTER",
     "Route 4 Center destination changed")
  for dy = 0, 1 do
    for dx = 0, 1 do
      expect(structures.doorFold[keyOf(22 + dx, 10 + dy)],
             "Route 4 Center door escaped generic building folding")
    end
  end

  -- A synchronous body build still allocates exactly the one existing terrain
  -- mesh. Portal stamps do not become building instances or another draw.
  createdMeshes = {}
  local mesh = Mesher.build(map, true, nil, false)
  expect(mesh ~= nil, "Route 4 terrain build returned no mesh")
  eq(#createdMeshes, 1, "portal introduced an extra terrain draw/mesh")
end

-- Scan every generated outdoor map: only the nine identities above may ever
-- enter this path. This includes every other Center and ordinary outdoor door.
do
  local identities, count = {}, 0
  for mapId, def in pairs(realMaps) do
    if def.tileset == "OVERWORLD" then
      local map = RealMap.new(def, assert(realTilesets.OVERWORLD))
      Structures.invalidate(mapId)
      local structures = Structures.forMap(map)
      for _, stamp in ipairs(structures.portalStamps) do
        count = count + 1
        identities[mapId .. "#" .. tostring(stamp.warpIndex)] = true
      end
      Structures.invalidate(mapId)
    end
  end
  eq(count, 9, "non-canonical outdoor door acquired a portal stamp")
  for mapId, rows in pairs(expected) do
    for index in pairs(rows) do
      expect(identities[mapId .. "#" .. tostring(index)],
             "full outdoor scan missed canonical portal")
    end
  end
end

-- Independent fail-closed gates. Each edit leaves the canonical map methods
-- otherwise usable, so Structures completes and proves it fell back instead
-- of throwing or half-applying a stamp.
local failures = {
  {
    "destination", function(def) def.warps[2].destMap = "EDITED_CAVE" end,
  },
  {
    "destination warp", function(def) def.warps[2].destWarp = 99 end,
  },
  {
    "map id", nil, function(map) map.id = "EDITED_ROUTE_4" end,
  },
  {
    "portal art", nil, function(map)
      local original = map.tileAt
      function map:tileAt(tx, ty)
        if tx == 36 and ty == 10 then return 0x30 end
        return original(self, tx, ty)
      end
    end,
  },
  {
    "collision", nil, function(map)
      local original = map.cellTile
      function map:cellTile(cx, cy)
        if cx == 18 and cy == 5 then return 0x39 end
        return original(self, cx, cy)
      end
    end,
  },
  {
    "door flag", nil, function(map)
      local original = map.isDoorTileCell
      function map:isDoorTileCell(cx, cy)
        if cx == 18 and cy == 5 then return false end
        return original(self, cx, cy)
      end
    end,
  },
  {
    "north cliff", nil, function(map)
      local original = map.cellTile
      function map:cellTile(cx, cy)
        if cx == 18 and cy == 4 then return 0x37 end
        return original(self, cx, cy)
      end
    end,
  },
  {
    "north blocked", nil, function(map)
      local original = map.isWalkableCell
      function map:isWalkableCell(cx, cy)
        if cx == 18 and cy == 4 then return true end
        return original(self, cx, cy)
      end
    end,
  },
  {
    "west cliff", nil, function(map)
      local original = map.cellTile
      function map:cellTile(cx, cy)
        if cx == 17 and cy == 5 then return 0x24 end
        return original(self, cx, cy)
      end
    end,
  },
  {
    "east blocked", nil, function(map)
      local original = map.isWalkableCell
      function map:isWalkableCell(cx, cy)
        if cx == 19 and cy == 5 then return true end
        return original(self, cx, cy)
      end
    end,
  },
  {
    "south tile", nil, function(map)
      local original = map.cellTile
      function map:cellTile(cx, cy)
        if cx == 18 and cy == 6 then return 0x2c end
        return original(self, cx, cy)
      end
    end,
  },
  {
    "south walk", nil, function(map)
      local original = map.isWalkableCell
      function map:isWalkableCell(cx, cy)
        if cx == 18 and cy == 6 then return false end
        return original(self, cx, cy)
      end
    end,
  },
}

for at, failure in ipairs(failures) do
  local map = realMap("ROUTE_4", failure[2], failure[3])
  Structures.invalidate()
  local structures = Structures.forMap(map)
  local found = false
  for _, stamp in ipairs(structures.portalStamps) do
    if stamp.warpIndex == 2 then found = true end
  end
  expect(not found, "portal gate failed closed: " .. failure[1])
end

-- Merely pointing an unlisted Center warp at a cave is never sufficient.
do
  local map = realMap("ROUTE_4", function(def)
    def.warps[1].destMap, def.warps[1].destWarp = "MT_MOON_1F", 1
  end)
  Structures.invalidate()
  local structures = Structures.forMap(map)
  eq(#structures.portalStamps, 2,
     "destination heuristic admitted an unlisted Center door")
  for _, stamp in ipairs(structures.portalStamps) do
    expect(stamp.warpIndex ~= 1, "unlisted Center became a cave portal")
  end
end

-- The visual path samples only the already-retained OVERWORLD atlas.
for _, path in ipairs(assetRequests) do
  expect(path == realTilesets.OVERWORLD.image,
         "portal requested a new texture asset: " .. tostring(path))
end

print(("outdoor cave portal tests: ok "
  .. "(%d stamps, %d tunnel + 16 shields + %d notched-step = %d quads)")
  :format(totalStamps, totalPortalQuads, ROUTE4_STEP_QUADS,
          totalPortalQuads + 16 + ROUTE4_STEP_QUADS))
