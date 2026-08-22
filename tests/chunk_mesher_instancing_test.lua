-- Generic regression for repeated terrain/grass instancing and atomic current
-- scenery. The fake driver charges 4ms per paged vertex upload: no cold map,
-- promotion, or auxiliary overlay may hide one monolithic upload outside the
-- same BuildBudget contract as terrain.

local runnerLove = rawget(_G, "love")
local now, pumpNo = 0, 0
local uploads, allocations, attachments = {}, {}, {}
local releases, rejected, invalidations = 0, 0, 0
local capability, failAttach = true, false
local uploadedPageRefs = setmetatable({}, { __mode = "k" })

love = {
  timer = { getTime = function() return now end },
  graphics = {},
  data = {},
  event = runnerLove and runnerLove.event or nil,
}

function love.data.pack(_, format, ...)
  local count = select("#", ...)
  local fields = 0
  for _ in format:gmatch("I4") do fields = fields + 1 end
  if fields ~= count then error("packed index field mismatch") end
  return string.rep("\0", count * 4)
end

function love.data.newByteData(bytes)
  local data = { bytes = bytes }
  function data:release() self.released = true end
  return data
end

local function newDriverMesh(kind, payload)
  local mesh = { kind = kind, released = false }
  if kind == "buffer" then mesh.capacity = payload end
  if kind == "offsets" then mesh.rows = payload end
  allocations[#allocations + 1] = mesh

  function mesh:setVertices(page, first, count)
    collectgarbage("collect")
    for _ in pairs(uploadedPageRefs) do
      error("an uploaded page stayed retained across driver calls")
    end
    uploads[#uploads + 1] = {
      pump = pumpNo, count = count, first = first, source = #page,
    }
    if not self.firstVertex and page[1] then
      self.firstVertex = {}
      for i = 1, 6 do self.firstVertex[i] = page[1][i] end
    end
    if self.kind == "offsets" then
      for i = 1, count do
        local row = page[i]
        self.rows[first + i - 1] = { row[1], row[2], row[3] }
      end
    else
      self.vertices = self.vertices or {}
      for i = 1, count do
        local row = page[i]
        self.vertices[first + i - 1] = {
          row[1], row[2], row[3], row[4], row[5], row[6],
        }
      end
    end
    uploadedPageRefs[page] = true
    now = now + 0.004
  end

  function mesh:setVertexMap(data, indexType, count)
    if data.released then error("released index data reached driver") end
    if indexType ~= "uint32" or #data.bytes ~= count * 4 then
      error("bad packed index upload")
    end
    now = now + 0.004
  end

  function mesh:attachAttribute(name, source, rate)
    if failAttach then
      failAttach = false
      error("simulated per-instance attribute rejection")
    end
    if name ~= "InstanceOffset" or rate ~= "perinstance" then
      error("wrong instance attachment contract")
    end
    self.attached = source
    attachments[#attachments + 1] = { mesh = self, source = source }
  end

  function mesh:setTexture(texture) self.texture = texture end
  function mesh:release()
    if self.released then error("GPU object released twice") end
    self.released = true
    releases = releases + 1
  end
  return mesh
end

function love.graphics.newMesh(format, vertices)
  if format[1] and format[1][1] == "InstanceOffset" then
    return newDriverMesh("offsets", {})
  end
  if type(vertices) == "number" then
    return newDriverMesh("buffer", vertices)
  end
  error("unexpected non-paged mesh allocation")
end

package.preload["src.render.Assets"] = function()
  return { register = function() end }
end

local function quad(x0, z0, x1, z1, shade)
  return {
    { x0, 0, z0 }, { x1, 0, z0 }, { x1, 1, z1 }, { x0, 1, z1 },
    uv = { { 0, 0 }, { 1, 0 }, { 1, 1 }, { 0, 1 } },
    shade = shade or 1,
  }
end

local function keyOf(tx, ty)
  return (ty + 64) * 4096 + (tx + 64)
end

local S = {
  skip = {}, runs = {}, shapeAt = {}, tileAt = {}, ground = {},
  objectQuads = {}, flowerQuads = {}, figures = {},
  buildingStamps = {}, roundStamps = {}, grassGroups = {},
}
for ty = 0, 3 do
  for tx = 0, 3 do
    local key = keyOf(tx, ty)
    S.shapeAt[key] = { h = 0, art = "flat", class = "ground" }
    S.tileAt[key] = 0
  end
end

-- Two whole instances and one boundary instance. The latter keeps only q1:
-- q2 translated by x=0 stays wholly west of the body's open interval.
local stampTemplate = {
  quad(0, 0, 1, 1, 0.8),
  quad(-2, 0, -1, 1, 0.6),
}
S.roundStamps = {
  { quads = stampTemplate, mx = 8, mz = 8, r = 2 },
  { quads = stampTemplate, mx = 24, mz = 24, r = 2 },
  { quads = stampTemplate, mx = 0, mz = 8, r = 2 },
}

-- Buildings are body-owned: even an eave outside x=0 must survive intact.
-- Two placements share one model and must become one additional instance
-- group; the exact fallback expands all four historical quads.
local buildingTemplate = {
  quad(-2, 0, -1, 1, 0.7),
  quad(0, 0, 2, 2, 0.9),
}
S.buildingStamps = {
  { quads = buildingTemplate, mx = 0, mz = 8 },
  { quads = buildingTemplate, mx = 16, mz = 8 },
}

local grassTemplate = { quad(0, 1, 1, 2, 0.9) }
local placements = {}
for i = 1, 300 do
  placements[#placements + 1] = (i % 16) * 8
  placements[#placements + 1] = math.floor(i / 16) * 8
end
S.grassGroups[1] = { quads = grassTemplate, placements = placements }

-- Large unique aux geometry exercises the same page upload path even when
-- grass itself is reduced to one instanced template.
for i = 1, 300 do
  local x = i % 32
  local z = math.floor(i / 32)
  S.flowerQuads[i] = quad(x, z, x + 1, z + 1, 1)
end
local figureQuads = {}
for i = 1, 300 do
  local x = i % 16
  local y = math.floor(i / 16)
  figureQuads[i] = quad(x, y, x + 1, y + 1, 0.85)
end
S.figures[1] = { quads = figureQuads, wx = 8, wz = 8, y = 0 }

local Structures = {
  forMap = function(map) return map.analysis or S end,
  invalidate = function() invalidations = invalidations + 1 end,
}

local dependencyCache = {}
local V = {}
function V.require(name)
  if dependencyCache[name] then return dependencyCache[name] end
  if name == "Structures" then
    dependencyCache[name] = Structures
  elseif name == "TileShape" then
    dependencyCache[name] = {}
  elseif name == "LedgeElevation" then
    dependencyCache[name] = {
      map = function(map)
        return { at = function(_, x, y)
          if type(map.elevation) == "function" then
            return map.elevation(x, y)
          end
          return map.elevation or 0
        end }
      end,
      invalidate = function() return true end,
    }
  elseif name == "Voxel3D" then
    dependencyCache[name] = {
      FORMAT = {
        { "VertexPosition", "float", 3 },
        { "VertexTexCoord", "float", 2 },
        { "VertexShade", "float", 1 },
      },
      FACE_SHADE = { 0.84, 0.72, 1, 0.55, 0.90, 0.68 },
      pushQuad = function(indices, n)
        local base = n * 4
        for _, i in ipairs({ 1, 2, 3, 1, 3, 4 }) do
          indices[#indices + 1] = base + i
        end
      end,
      newMesh = function() error("sync mesh path reached async fixture") end,
      canInstance = function() return capability end,
      rejectInstancing = function()
        capability = false
        rejected = rejected + 1
      end,
    }
  elseif name == "BuildBudget" then
    dependencyCache[name] = assert(loadfile("lib/BuildBudget.lua"))()
  elseif name == "ModSetting" then
    dependencyCache[name] = {
      new = function() return { get = function() return true end } end,
    }
  else
    error("unexpected dependency " .. tostring(name))
  end
  return dependencyCache[name]
end

local Mesher = assert(loadfile("lib/ChunkMesher.lua"))(V)

local function map(id, elevation)
  return {
    id = id,
    elevation = elevation or 0,
    def = { width = 1, height = 1 },
    tileset = { tilesPerRow = 16, imageWidth = 128, imageHeight = 48 },
  }
end

local function expect(ok, message)
  if not ok then error(message, 2) end
end

local function pump()
  pumpNo = pumpNo + 1
  if pumpNo > 500 then error("global pump guard exceeded") end
  Mesher.pump(false, false, false)
end

local function finishCurrent(m)
  local guard = 0
  while Mesher.pending() > 0 and guard < 100 do
    pump()
    local terrain = Mesher.pair(m, true)
    if terrain then
      local figures = Mesher.figures(m)
      expect(Mesher.grass(m) ~= nil and Mesher.flowers(m) ~= nil
             and figures ~= nil and #figures > 0,
             "current terrain became visible before its aux overlays")
    end
    guard = guard + 1
  end
  expect(guard < 100, "budgeted current build never completed")
end

local first = map("INSTANCE_A", 6)
local syncVertices, _, syncQuads = Mesher.geometry(first, true)
expect(syncQuads == 16 + 5 + 4,
       "building fallback changed the historical expanded quad count")
expect(syncVertices[16 * 4 + 1][1] == -2,
       "body-owned building eave was clipped at the map boundary")
Mesher.setLive({ [first.id] = true })
Mesher.request(first, true, nil, true)
finishCurrent(first)

local terrain = Mesher.pair(first, true)
local grass = Mesher.grass(first)
expect(terrain and terrain.__voxelMeshBundle,
       "supported terrain did not use an instance bundle")
expect(#terrain.instances == 3,
       "terrain did not retain building + whole/boundary hull variants")
local instanceCounts, variantCaps = {}, {}
local cap8Count2 = 0
for _, group in ipairs(terrain.instances) do
  instanceCounts[group.count] = true
  variantCaps[group.mesh.capacity] = true
  expect(group.mesh.attached == group.source,
         "terrain variant lost its per-instance source")
  for _, row in pairs(group.source.rows) do
    expect(#row == 3 and row[2] == 6,
           "terrain instance source lost its semantic Y component")
  end
  local v = group.mesh.firstVertex
  expect(v and (v[1] == 0 or v[1] == -2)
         and v[3] == 0 and v[4] == 0 and v[5] == 0,
         "instanced template changed local position or UV")
  local authoredShade = v[1] == -2 and 0.7 or 0.8
  expect(math.abs(v[6] - authoredShade * (1 - 0.12 * 2.4)) < 1e-6,
         "instanced template changed its authored/AO shade")
  if group.mesh.capacity == 8 and group.count == 2 then
    cap8Count2 = cap8Count2 + 1
  end
end
expect(instanceCounts[2] and instanceCounts[1],
       "stamp placements were lost or duplicated")
expect(variantCaps[8] and variantCaps[4],
       "clipped variants changed their exact quad counts")
expect(cap8Count2 == 2,
       "shared building template was not uploaded once for two placements")
expect(terrain.base.capacity == 16 * 4,
       "repeated stamps leaked back into the base terrain upload")
expect(grass and grass.__voxelMeshBundle and #grass.instances == 1,
       "grass did not retain one shared template")
expect(grass.instances[1].mesh.capacity == 4
       and grass.instances[1].count == 300,
       "grass template/placement cardinality changed")
for _, row in pairs(grass.instances[1].source.rows) do
  expect(#row == 3 and row[2] == 6,
         "grass instance source lost its semantic Y component")
end

-- Every ordinary upload, including flowers and fallback grass below, stays
-- within the 256-quad page cap and releases consumed Lua pages immediately.
local perPump = {}
for _, upload in ipairs(uploads) do
  expect(upload.count == upload.source, "upload page count mismatch")
  expect(upload.count <= Mesher._UPLOAD_VERTICES,
         "an aux or terrain upload exceeded the page cap")
  perPump[upload.pump] = (perPump[upload.pump] or 0) + 1
end
for _, count in pairs(perPump) do
  expect(count <= 5, "one pump exceeded the simulated 12ms driver budget")
end

local releaseBefore = releases
Mesher.invalidate(first.id)
expect(releases == releaseBefore + 11,
       "terrain/grass bundles did not release base, variants and sources")

-- A rigid building whose footprint crosses two semantic bases cannot be one
-- GPU instance. It falls back to the exact expanded stream and keeps the
-- placement cell's Y, rather than bending vertices or silently choosing the
-- neighbouring terrace.
local unevenS = {
  skip = {}, runs = {}, shapeAt = {}, tileAt = {}, ground = {},
  objectQuads = {}, flowerQuads = {}, figures = {},
  buildingStamps = {}, roundStamps = {}, grassGroups = {},
}
for ty = 0, 3 do
  for tx = 0, 3 do
    local key = keyOf(tx, ty)
    unevenS.shapeAt[key] = { h = 0, art = "flat", class = "ground" }
    unevenS.tileAt[key] = 0
  end
end
unevenS.buildingStamps[1] = {
  quads = { quad(0, 0, 20, 0, 0.9) }, mx = 0, mz = 8,
}
local uneven = map("INSTANCE_UNEVEN")
uneven.analysis = unevenS
uneven.elevation = function(x) return x == 0 and 6 or 0 end
Mesher.setLive({ [uneven.id] = true })
Mesher.request(uneven, true, nil, true)
local unevenGuard = 0
while Mesher.pending() > 0 and unevenGuard < 100 do
  pump()
  unevenGuard = unevenGuard + 1
end
expect(unevenGuard < 100, "non-uniform building fallback never completed")
local unevenTerrain = Mesher.pair(uneven, true)
expect(unevenTerrain and not unevenTerrain.__voxelMeshBundle,
       "non-uniform building footprint was incorrectly instanced")
local shiftedBuilding = false
for _, v in ipairs(unevenTerrain.vertices or {}) do
  if v[1] == 0 and v[2] == 7 and v[3] == 8 then
    shiftedBuilding = true
    break
  end
end
expect(shiftedBuilding,
       "non-uniform building fallback lost the placement-cell base")

-- A driver can advertise instancing yet reject per-instance attributes. The
-- partial bundle must close and the same map must land through exact expanded
-- geometry, with the rejection sticky for later maps.
local fallback = map("INSTANCE_FALLBACK", 6)
Mesher.setLive({ [fallback.id] = true })
capability, failAttach = true, true
Mesher.request(fallback, true, nil, true)
finishCurrent(fallback)
local expanded = Mesher.pair(fallback, true)
expect(expanded and not expanded.__voxelMeshBundle,
       "attachAttribute rejection did not fall back to expansion")
expect(expanded.capacity == (16 + 5 + 4) * 4,
       "expanded fallback changed building/hull geometry or clipping")
expect(expanded.firstVertex and expanded.firstVertex[2] == 6,
       "expanded fallback did not match the instanced semantic Y")
expect(rejected == 1 and capability == false,
       "instancing rejection was not made sticky")
local fallbackGrass = Mesher.grass(fallback)
expect(fallbackGrass and not fallbackGrass.__voxelMeshBundle
       and fallbackGrass.capacity == 300 * 4,
       "unsupported driver did not receive exact budgeted grass expansion")

-- Promotion regression: neighbour terrain may warm before aux, but the moment
-- it becomes current pair()/ready() must hide it until the budgeted overlays
-- are complete. No one-frame Route-1 grass pop is possible.
local promoted = map("INSTANCE_PROMOTED")
Mesher.setLive({ [promoted.id] = true })
Mesher.request(promoted, true, nil, false)
local guard = 0
while not Mesher.pair(promoted, true) and guard < 100 do
  pump()
  guard = guard + 1
end
expect(guard < 100 and Mesher.grass(promoted) == nil,
       "neighbour fixture did not expose terrain before aux")
Mesher.request(promoted, true, nil, true)
expect(Mesher.pair(promoted, true) == nil,
       "promoted current exposed cached terrain without grass")
finishCurrent(promoted)
expect(Mesher.pair(promoted, true) and Mesher.grass(promoted)
       and Mesher.flowers(promoted) and Mesher.figures(promoted),
       "promoted current never landed its atomic visual answer")

-- Three generic transitions exercise bounded one-neighbourhood history. On
-- the third set the first cache must release; repeating the live set releases
-- the second, so periodic map traversal cannot retain an unbounded upload/GC
-- tail. No policy increase is hidden in this performance change.
local third = map("INSTANCE_THIRD")
local fourth = map("INSTANCE_FOURTH")
Mesher.setLive({ [third.id] = true })
Mesher.request(third, true, nil, true)
finishCurrent(third)
local beforeFourth = releases
Mesher.setLive({ [fourth.id] = true })
Mesher.request(fourth, true, nil, true)
finishCurrent(fourth)
expect(releases > beforeFourth,
       "third transition did not evict the oldest retained neighbourhood")
local beforeRepeat = releases
Mesher.setLive({ [fourth.id] = true })
expect(releases > beforeRepeat,
       "stable live set did not close the previous neighbourhood")
expect(invalidations > 0, "cache eviction did not drop Structures analyses")

collectgarbage("collect")
for _ in pairs(uploadedPageRefs) do
  error("uploaded page remained reachable after multi-map builds")
end

love = runnerLove
print(("chunk mesher instancing: %d attachments, %d paged uploads, %d releases")
  :format(#attachments, #uploads, releases))
