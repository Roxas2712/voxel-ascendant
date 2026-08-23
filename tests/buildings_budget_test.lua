-- Cold profiled buildings must cooperate with ChunkMesher's frame budget and
-- retain shared local models instead of translated quad copies.

local runnerLove = rawget(_G, "love")
local now = 0
love = {
  timer = {
    -- Deterministic virtual clock: every budget consultation consumes 10us.
    -- Large inner loops with no consultation therefore fail the yield-count
    -- floor below, without relying on host timing.
    getTime = function()
      now = now + 0.00001
      return now
    end,
  },
  event = runnerLove and runnerLove.event or nil,
}

local tileRows = {}
for y = 1, 8 do
  tileRows[y] = {}
  for x = 1, 8 do tileRows[y][x] = 0 end
end

local profile = {
  buildings = {
    OVERWORLD = {
      {
        tiles = tileRows,
        roofRows = 16,
        slab = 4,
        depth = 8,
        roofBack = 1,
        roofFront = 1,
        roofCycle = { 0, 15 },
      },
    },
  },
}

local loaded = {}
local V = {}
function V.require(name)
  if loaded[name] then return loaded[name] end
  if name == "BuildBudget" then
    loaded[name] = assert(loadfile("lib/BuildBudget.lua"))()
    return loaded[name]
  end
  error("unexpected dependency: " .. tostring(name))
end
function V.data(name)
  if name == "voxel_heights" then return profile end
  error("unexpected data: " .. tostring(name))
end

local Budget = V.require("BuildBudget")
local Buildings = assert(loadfile("lib/Buildings.lua"))(V)
Buildings.diagnostics(true)
local function keyOf(tx, ty) return (ty + 64) * 4096 + (tx + 64) end
local S = {
  outdoor = true,
  shapeAt = {}, tileAt = {}, skip = {}, ground = {},
  objectQuads = {}, buildingStamps = {},
}
for ty = 0, 7 do
  for tx = 0, 7 do
    local key = keyOf(tx, ty)
    S.tileAt[key] = 0
    S.shapeAt[key] = { flat = true, class = "ground" }
  end
end
local map = {
  def = { width = 2, height = 2 },
  tileset = { id = "OVERWORLD", imageWidth = 128, imageHeight = 64 },
}
-- An all-inside, source-tile-scale wall course: BLACK/DARK never lets the
-- silhouette flood in, while its x variation proves flank UVs preserve eight
-- real texels instead of stretching one texel over an eight-voxel quad.
local pixels = { getPixel = function(_, x)
  local v = (x % 8 == 0 or x % 8 == 7) and 0 or 0.4
  return v, v, v, 1
end }

local co = coroutine.create(function()
  Buildings.build(S, map, pixels, 16)
end)
local yields, guard = 0, 0
while coroutine.status(co) ~= "dead" do
  guard = guard + 1
  if guard > 2000 then error("budgeted building build did not finish") end
  Budget.begin(co, 0.001)
  local ok, reason = coroutine.resume(co)
  Budget.finish()
  if not ok then error(reason) end
  if coroutine.status(co) ~= "dead" then
    if reason ~= "budget" then error("building yielded outside BuildBudget") end
    yields = yields + 1
  end
end

-- Ordinary profiled buildings now derive their exact occupied depth intervals
-- instead of materialising the invisible interior volume.  Active face rows
-- and interval differences still check the budget.  Sorted active-row
-- emission removes the remaining empty scans as well; eight deterministic
-- slices continue to prove the optimized path is cooperative rather than one
-- coarse uninterruptible loop.
if yields < 8 then
  error("large building sparse shell was not sliced finely: " .. yields)
end
if #S.objectQuads ~= 0 then error("building build retained translated quads") end
if #S.buildingStamps ~= 1 or #S.buildingStamps[1].quads == 0 then
  error("large building did not retain one shared local stamp")
end


local sideCourse = false
for _, q in ipairs(S.buildingStamps[1].quads) do
  local x = q[1][1]
  local constantX = q[2][1] == x and q[3][1] == x and q[4][1] == x
  if constantX then
    local z0, z1 = q[1][3], q[1][3]
    local u0, u1 = q.uv[1][1], q.uv[1][1]
    for i = 2, 4 do
      z0, z1 = math.min(z0, q[i][3]), math.max(z1, q[i][3])
      u0, u1 = math.min(u0, q.uv[i][1]), math.max(u1, q.uv[i][1])
    end
    local worldSpan, sourceSpan = z1 - z0, (u1 - u0) * 128
    if worldSpan == 8 and sourceSpan >= 7.8 then
      sideCourse = true
      break
    end
  end
end
if not sideCourse then
  error("outdoor flank did not retain a 1:1 eight-texel source course")
end

-- Pin the complete local model, not just its quad count.  The production
-- emitter is allowed to skip volume rows proven to contain no exposed face,
-- but the optimisation must preserve every corner, UV, shade and their
-- deterministic order byte-for-byte at the Lua-number level represented by
-- this fixture.  A small-prime rolling digest stays exactly representable in
-- IEEE doubles while still covering every scalar in every quad.
local function quadDigest(quads)
  local h, prime = 2166136261, 4294967291
  local function add(value)
    h = (h * 257 + value) % prime
  end
  for _, q in ipairs(quads) do
    for corner = 1, 4 do
      for axis = 1, 3 do add(q[corner][axis] + 4096) end
      for axis = 1, 2 do
        add(math.floor(q.uv[corner][axis] * 100000000 + 0.5))
      end
    end
    add(math.floor(q.shade * 1000000 + 0.5))
  end
  return h
end
local referenceDigest = quadDigest(S.buildingStamps[1].quads)
if S.buildingStamps[1].quads.voxels ~= 212992
   or S.buildingStamps[1].quads.shell ~= 20792
   or #S.buildingStamps[1].quads ~= 2293
   or referenceDigest ~= 1455267591 then
  error(("building active-row output changed: %d/%d/%d/%.0f")
    :format(S.buildingStamps[1].quads.voxels,
            S.buildingStamps[1].quads.shell,
            #S.buildingStamps[1].quads, referenceDigest))
end

-- Placement candidates are indexed once by their first tile. Exercise that
-- contract with many templates whose first tile is absent, one false sparse
-- candidate, and one real 2x2 match. A proxy counts every tileAt probe; the
-- old per-template full-map sweeps exceed this bound by tens of thousands.
local function placementFixture(defWidth, defHeight, templates, edit)
  profile.buildings.OVERWORLD = templates
  Buildings.invalidate()

  local tw, th = defWidth * 4, defHeight * 4
  local backing = {}
  for ty = 0, th - 1 do
    for tx = 0, tw - 1 do backing[keyOf(tx, ty)] = 0 end
  end
  if edit then
    edit(function(tx, ty, tile) backing[keyOf(tx, ty)] = tile end)
  end

  local reads = 0
  local tileAt = setmetatable({}, {
    __index = function(_, key)
      reads = reads + 1
      return backing[key]
    end,
  })
  local state = {
    outdoor = true,
    shapeAt = {}, tileAt = tileAt, skip = {}, ground = {},
    objectQuads = {}, buildingStamps = {},
  }
  local fixtureMap = {
    def = { width = defWidth, height = defHeight },
    tileset = { id = "OVERWORLD", imageWidth = 128, imageHeight = 64 },
  }
  Buildings.build(state, fixtureMap, pixels, 16)
  return state, reads, tw * th
end

local sparseTemplates = {}
for i = 1, 24 do
  sparseTemplates[#sparseTemplates + 1] = {
    tiles = { { 100 + i } }, claimOnly = true,
  }
end
sparseTemplates[#sparseTemplates + 1] = {
  tiles = { { 9, 10 }, { 11, 12 } }, claimOnly = true, support = 7,
}
local sparse, sparseReads, sparseCells = placementFixture(
  8, 8, sparseTemplates,
  function(set)
    set(2, 3, 9) -- same first tile, but the second tile rejects the match
    set(23, 18, 9)
    set(24, 18, 10)
    set(23, 19, 11)
    set(24, 19, 12)
  end)
for ty = 18, 19 do
  for tx = 23, 24 do
    local shape = sparse.shapeAt[keyOf(tx, ty)]
    if not sparse.skip[keyOf(tx, ty)] or not shape or shape.h ~= 7 then
      error("sparse first-tile candidate did not claim the real match")
    end
  end
end
if sparse.skip[keyOf(2, 3)] then
  error("sparse false first-tile candidate was claimed")
end
if sparseReads < sparseCells or sparseReads > sparseCells + 12 then
  error(("first-tile candidate probes were not bounded: %d for %d cells")
    :format(sparseReads, sparseCells))
end

-- Template order is semantic: the first matching drawing owns an overlap.
-- Different support heights make the winning template observable even though
-- both claim-only fixtures intentionally emit no geometry.
local priority = placementFixture(1, 1, {
  { tiles = { { 31, 32 } }, claimOnly = true, support = 11 },
  { tiles = { { 32 } }, claimOnly = true, support = 22 },
}, function(set)
  set(0, 0, 31)
  set(1, 0, 32)
end)
local priorityShape = priority.shapeAt[keyOf(1, 0)]
if not priorityShape or priorityShape.h ~= 11 then
  error("later template displaced the first template's overlap claim")
end

-- Candidate positions themselves remain row-major. With three identical
-- first tiles, the left 2-cell placement must claim before the overlapping
-- middle placement; reversing the index would leave x=0 unclaimed instead.
local rowMajor = placementFixture(1, 1, {
  { tiles = { { 41, 41 } }, claimOnly = true, support = 33 },
}, function(set)
  set(0, 0, 41)
  set(1, 0, 41)
  set(2, 0, 41)
end)
if not rowMajor.skip[keyOf(0, 0)] or not rowMajor.skip[keyOf(1, 0)]
   or rowMajor.skip[keyOf(2, 0)] then
  error("first-tile candidates lost row-major first-claim order")
end

love = runnerLove
print(("buildings budget/shared stamp: %d yields, %d template quads; "
       .. "sparse probes %d/%d")
  :format(yields, #S.buildingStamps[1].quads, sparseReads, sparseCells))
