-- The Safari Zone's FOREST walls carry a two-row authored foot below a
-- repeated body course.  This is a pure visual-volume contract: exactly the
-- sixteen canonical body columns become 24px volumes, while generated map
-- bytes, collision and every fail-closed gate remain untouched.

local engineRoot = os.getenv("GEN1RECOMP_0190_ROOT") or "../gen1recomp"
local realMaps = assert(loadfile(engineRoot .. "/data/generated/maps.lua"))()
local realTilesets =
  assert(loadfile(engineRoot .. "/data/generated/tilesets.lua"))()
local RealMap = assert(loadfile(engineRoot .. "/src/world/Map.lua"))()

local logicalClock = 0
love = love or {}
love.timer = love.timer or {}
love.timer.getTime = function()
  logicalClock = logicalClock + 0.000001
  return logicalClock
end

package.preload["src.render.Assets"] = function()
  -- Volume classification is deliberately headless here.  The target is a
  -- structural run, not a pixel-extracted prop; nil is Structures' supported
  -- no-ImageData path and keeps this test GPU/decoder independent.
  return { imageData = function() return nil end,
           register = function() end }
end
package.preload["src.world.Map"] = function() return RealMap end
package.preload["src.render.TileRenderer"] = function()
  -- The rule is body-only; suppressing the ordinary render ring also makes a
  -- regression that escapes to negative/body-external coordinates obvious.
  return { borderBlockFor = function() return false end,
           voidFill = "trees" }
end

local loaded, V = {}, {}
function V.data(name)
  return assert(loadfile("data/" .. name .. ".lua"))()
end
function V.require(name)
  if loaded[name] then return loaded[name] end
  if name == "Buildings" then
    loaded[name] = {
      build = function() end,
      invalidate = function() end,
    }
  elseif name == "Voxel3D" then
    loaded[name] = {
      FACE_SHADE = { 0.84, 0.72, 1, 0.55, 0.90, 0.68 },
      canInstance = function() return false end,
      pushQuad = function(indices, quad)
        local base = quad * 4
        for _, index in ipairs({ 1, 2, 3, 1, 3, 4 }) do
          indices[#indices + 1] = base + index
        end
      end,
    }
  elseif name == "LedgeElevation" then
    loaded[name] = {
      map = function()
        return {
          at = function() return 0 end,
          atTile = function() return 0 end,
          atWorld = function() return 0 end,
        }
      end,
      invalidate = function() end,
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

local Budget = V.require("BuildBudget")
local Structures = V.require("Structures")
local Mesher = V.require("ChunkMesher")

local function expect(ok, message)
  if not ok then error(message, 2) end
end

local function eq(actual, expected, message)
  if actual ~= expected then
    error(("%s (expected %s, got %s)")
      :format(message, tostring(expected), tostring(actual)), 2)
  end
end

local function upvalue(fn, wanted)
  for i = 1, 100 do
    local name, value = debug.getupvalue(fn, i)
    if not name then break end
    if name == wanted then return value end
  end
end

local safariFootRepeat = upvalue(Structures.buildVolume, "safariFootRepeat")
expect(type(safariFootRepeat) == "function",
       "Safari foot gate is not wired into Structures.buildVolume")

local function keyOf(tx, ty)
  return (ty + 64) * 4096 + (tx + 64)
end

-- Synthetic adversarial probes pin every allow/deny branch independently of
-- canonical map drift.  The canonical-data section below is the authority for
-- the real sixteen columns.
local function synthetic(id, tileset, tx, north, sequence)
  local values = {}
  for i, tile in ipairs(sequence) do
    values[(north + i - 1) * 4096 + tx] = tile
  end
  local map = {
    id = id,
    def = { id = id, tileset = tileset, width = 2, height = 2 },
  }
  function map:tileAt(x, y) return values[y * 4096 + x] or 0x10 end
  return map, north + #sequence - 1
end

local canonicalSequence = { 0x2d, 0x2d, 0x2d, 0x2d, 0x3d, 0x3e }
for _, id in ipairs({
  "SAFARI_ZONE_CENTER", "SAFARI_ZONE_EAST",
  "SAFARI_ZONE_NORTH", "SAFARI_ZONE_WEST",
}) do
  local map, front = synthetic(id, "FOREST", 1, 0, canonicalSequence)
  expect(safariFootRepeat({ doorFold = {} }, map, 1, 0, front),
         id .. " is missing from the exact Safari allow-list")
end

do
  local minimum, front = synthetic(
    "SAFARI_ZONE_EAST", "FOREST", 1, 0,
    { 0x2d, 0x2d, 0x3d, 0x3e })
  expect(safariFootRepeat({ doorFold = {} }, minimum, 1, 0, front),
         "two repeated body rows did not satisfy the minimum gate")

  local prefixed, prefixedFront = synthetic(
    "SAFARI_ZONE_WEST", "FOREST", 1, 0,
    { 0x0f, 0x2f, 0x2f, 0x2f, 0x3f, 0x3e })
  expect(safariFootRepeat({ doorFold = {} }, prefixed, 1, 0,
                          prefixedFront),
         "canonical capped West spelling lost its terminal repeat")

  local one, oneFront = synthetic(
    "SAFARI_ZONE_EAST", "FOREST", 1, 0,
    { 0x0f, 0x2d, 0x3d, 0x3e })
  expect(not safariFootRepeat({ doorFold = {} }, one, 1, 0, oneFront),
         "a single body row was mistaken for a repeat")

  local edited, editedFront = synthetic(
    "SAFARI_ZONE_EAST", "FOREST", 1, 0,
    { 0x2d, 0x2d, 0x2d, 0x3f, 0x3e })
  expect(not safariFootRepeat({ doorFold = {} }, edited, 1, 0,
                              editedFront),
         "a mismatched first foot row passed the exact sequence gate")

  local other, otherFront = synthetic(
    "VIRIDIAN_FOREST", "FOREST", 1, 0, canonicalSequence)
  expect(not safariFootRepeat({ doorFold = {} }, other, 1, 0, otherFront),
         "Safari trim leaked into Viridian Forest")
  other.id = "SAFARI_ZONE_CENTER_REST_HOUSE"
  other.def.id = other.id
  expect(not safariFootRepeat({ doorFold = {} }, other, 1, 0, otherFront),
         "Safari trim leaked into a rest-house interior")

  local wrongTileset, wrongFront = synthetic(
    "SAFARI_ZONE_EAST", "OVERWORLD", 1, 0, canonicalSequence)
  expect(not safariFootRepeat({ doorFold = {} }, wrongTileset, 1, 0,
                              wrongFront),
         "Safari trim ignored the FOREST tileset gate")

  local ring, ringFront = synthetic(
    "SAFARI_ZONE_EAST", "FOREST", -1, 0, canonicalSequence)
  expect(not safariFootRepeat({ doorFold = {} }, ring, -1, 0, ringFront),
         "Safari trim escaped into the streamed ring")

  local door, doorFront = synthetic(
    "SAFARI_ZONE_EAST", "FOREST", 1, 0, canonicalSequence)
  local folded = { doorFold = { [keyOf(1, 2)] = true } }
  expect(not safariFootRepeat(folded, door, 1, 0, doorFront),
         "Safari trim overrode a folded doorway column")
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
  local collision = {}
  for cy = 0, map.heightCells - 1 do
    for cx = 0, map.widthCells - 1 do
      local warp = map:warpAtCell(cx, cy)
      collision[#collision + 1] = table.concat({
        map:cellTile(cx, cy),
        map:isWalkableCell(cx, cy) and 1 or 0,
        map:isWaterCell(cx, cy) and 1 or 0,
        map:isWarpTileCell(cx, cy) and 1 or 0,
        warp and warp.index or 0,
      }, ":")
    end
  end
  return {
    blocks = serialize(map.def.blocks),
    warps = serialize(map.def.warps or {}),
    collision = table.concat(collision, ","),
  }
end

local function sameGameplay(before, after, id)
  eq(after.blocks, before.blocks, id .. " generated block bytes changed")
  eq(after.warps, before.warps, id .. " generated warp bytes changed")
  eq(after.collision, before.collision, id .. " collision semantics changed")
end

local function realMap(id, overrideId)
  local def = assert(realMaps[id], "missing real map " .. id)
  local map = RealMap.new(def, assert(realTilesets[def.tileset]))
  if overrideId then map.id = overrideId end
  return map
end

local function terminalSequences(map)
  local hits = {}
  local tw, th = map.def.width * 4, map.def.height * 4
  for tx = 0, tw - 1 do
    for front = 3, th - 1 do
      local body = map:tileAt(tx, front - 2)
      local firstFoot = body == 0x2d and 0x3d
                        or body == 0x2f and 0x3f or nil
      if firstFoot and map:tileAt(tx, front - 1) == firstFoot
          and map:tileAt(tx, front) == 0x3e then
        local repeats = 0
        for ty = front - 2, 0, -1 do
          if map:tileAt(tx, ty) ~= body then break end
          repeats = repeats + 1
        end
        if repeats >= 2 then
          hits[#hits + 1] = { tx = tx, front = front, repeats = repeats }
        end
      end
    end
  end
  return hits
end

local function budgetedGeometry(map)
  Structures.invalidate(map.id)
  logicalClock = 0
  Budget.n = 0
  local result = {}
  local co = coroutine.create(function()
    result.vertices, result.indices, result.quads =
      Mesher.geometry(map, true)
  end)
  local resumes = 0
  repeat
    Budget.begin(co, 0.000004)
    local ok, why = coroutine.resume(co)
    Budget.finish()
    expect(ok, why)
    if coroutine.status(co) ~= "dead" then
      eq(why, "budget", "geometry yielded for a non-budget reason")
    end
    resumes = resumes + 1
  until coroutine.status(co) == "dead"
  result.resumes = resumes
  result.analysis = Structures.forMap(map)
  return result
end

local function arraysEqual(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do
    if type(a[i]) == "table" then
      if not arraysEqual(a[i], b[i]) then return false end
    elseif a[i] ~= b[i] then
      return false
    end
  end
  return true
end

local expectedHits = {
  SAFARI_ZONE_CENTER = 0,
  SAFARI_ZONE_EAST = 6,
  SAFARI_ZONE_NORTH = 6,
  SAFARI_ZONE_WEST = 4,
}
-- Full structural run bounds from the canonical atlas-backed classifier.
-- Three columns include a distinct northern cap before the repeated body;
-- the gate is intentionally terminal, so those caps stay part of the same
-- 24px volume rather than hiding the authored foot.
local expectedRuns = {
  SAFARI_ZONE_CENTER = {},
  SAFARI_ZONE_EAST = {
    { 21, 9, 15 }, { 21, 37, 43 }, { 37, 25, 31 },
    { 38, 9, 15 }, { 46, 30, 43 }, { 54, 25, 31 },
  },
  SAFARI_ZONE_NORTH = {
    { 29, 41, 55 }, { 38, 46, 55 }, { 50, 41, 47 },
    { 53, 49, 55 }, { 65, 25, 31 }, { 78, 25, 55 },
  },
  SAFARI_ZONE_WEST = {
    { 9, 33, 39 }, { 21, 13, 19 },
    { 34, 34, 39 }, { 46, 29, 35 },
  },
}
local totals = {
  hits = 0,
  beforeQuads = 0, afterQuads = 0,
  beforeVertices = 0, afterVertices = 0,
  beforeIndices = 0, afterIndices = 0,
  beforeResumes = 0, afterResumes = 0,
}

for _, id in ipairs({
  "SAFARI_ZONE_CENTER", "SAFARI_ZONE_EAST",
  "SAFARI_ZONE_NORTH", "SAFARI_ZONE_WEST",
}) do
  local map = realMap(id)
  eq(map.def.tileset, "FOREST", id .. " ceased to use FOREST")
  local beforeGameplay = gameplaySnapshot(map)
  local hits = terminalSequences(map)
  eq(#hits, expectedHits[id], id .. " canonical foot population changed")
  totals.hits = totals.hits + #hits

  local hitSet = {}
  for _, hit in ipairs(hits) do
    hitSet[hit.tx .. ":" .. hit.front] = true
  end
  for _, spec in ipairs(expectedRuns[id]) do
    local tx, north, front = spec[1], spec[2], spec[3]
    expect(hitSet[tx .. ":" .. front],
           id .. " canonical foot coordinate changed")
    local tiles = {}
    for ty = north, front do tiles[#tiles + 1] = { tx, ty } end

    local oldS = { doorFold = {}, runs = {}, outdoor = false }
    local newS = { doorFold = {}, runs = {}, outdoor = false }
    local baselineMap = realMap(id, id .. "_BASELINE_VOLUME")
    Structures.buildVolume(oldS, baselineMap, tiles)
    Structures.buildVolume(newS, map, tiles)
    local oldRun = oldS.runs[keyOf(tx, front)]
    local newRun = newS.runs[keyOf(tx, front)]
    expect(oldRun and newRun, id .. " canonical foot lost its volume run")
    eq(oldRun.peak, 48, id .. " baseline foot was not the 48px cap")
    eq(newRun.unit, 3, id .. " foot unit is not three rows")
    eq(newRun.peak, 24, id .. " foot did not trim to 24px")
    eq(newRun.fromRepeat, true, id .. " foot lost repeat provenance")
    eq(newRun.door, false, id .. " canonical foot became a folded door")
  end

  local baseline = realMap(id, id .. "_BASELINE")
  local before = budgetedGeometry(baseline)
  local after = budgetedGeometry(map)

  expect(after.quads <= before.quads, id .. " quad count increased")
  expect(#after.vertices <= #before.vertices, id .. " vertex count increased")
  expect(#after.indices <= #before.indices, id .. " index count increased")
  expect(after.resumes <= before.resumes, id .. " build resumes increased")

  if id == "SAFARI_ZONE_CENTER" then
    eq(after.quads, before.quads, "canonical Center geometry changed")
    eq(after.resumes, before.resumes, "canonical Center resume budget changed")
    expect(arraysEqual(after.vertices, before.vertices)
           and arraysEqual(after.indices, before.indices),
           "canonical Center vertex/index stream changed")
  end

  sameGameplay(beforeGameplay, gameplaySnapshot(map), id)
  totals.beforeQuads = totals.beforeQuads + before.quads
  totals.afterQuads = totals.afterQuads + after.quads
  totals.beforeVertices = totals.beforeVertices + #before.vertices
  totals.afterVertices = totals.afterVertices + #after.vertices
  totals.beforeIndices = totals.beforeIndices + #before.indices
  totals.afterIndices = totals.afterIndices + #after.indices
  totals.beforeResumes = totals.beforeResumes + before.resumes
  totals.afterResumes = totals.afterResumes + after.resumes

  Structures.invalidate(baseline.id)
  Structures.invalidate(map.id)
  before, after = nil, nil
  collectgarbage("collect")
end

eq(totals.hits, 16, "canonical Safari foot total changed")
expect(totals.afterQuads < totals.beforeQuads,
       "Safari trim did not reduce the aggregate quad count")
expect(totals.afterVertices < totals.beforeVertices,
       "Safari trim did not reduce the aggregate vertex count")
expect(totals.afterResumes <= totals.beforeResumes,
       "Safari trim increased aggregate build resumes")

print(("safari structure foot trim: hits=%d quads=%d->%d "
       .. "vertices=%d->%d indices=%d->%d resumes=%d->%d: ok")
  :format(totals.hits, totals.beforeQuads, totals.afterQuads,
          totals.beforeVertices, totals.afterVertices,
          totals.beforeIndices, totals.afterIndices,
          totals.beforeResumes, totals.afterResumes))
