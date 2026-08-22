local now = 0

love = love or {}
love.timer = love.timer or {}
-- Make every sampled budget clock advance. A slice shorter than this forces
-- the exercised scan/flood loops to hand control back. Preserve the runner's
-- other timer functions so LÖVE can finish the headless test cleanly.
love.timer.getTime = function()
  now = now + 0.00001
  return now
end

local assetLoads = 0
local invalidator
local pixelsRead = 0
local atlas = {}

function atlas:getDimensions()
  return 128, 48
end

function atlas:getPixel()
  pixelsRead = pixelsRead + 1
  return 0, 0, 0, 1
end

package.preload["src.render.Assets"] = function()
  return {
    imageData = function(path)
      assert(path == "budget-atlas.png")
      assetLoads = assetLoads + 1
      return atlas
    end,
    register = function(fn) invalidator = fn end,
  }
end

package.preload["src.world.Map"] = function()
  return { isOutdoor = function() return true end }
end

local Budget = assert(loadfile("lib/BuildBudget.lua"))()
local buildingInvalidations = 0
local V = {}

function V.require(name)
  if name == "BuildBudget" then return Budget end
  if name == "Buildings" then
    return {
      invalidate = function() buildingInvalidations = buildingInvalidations + 1 end,
    }
  end
  if name == "TileShape" then return {} end
  error("unexpected dependency: " .. tostring(name))
end

local Structures = assert(loadfile("lib/Structures.lua"))(V)

local function expect(ok, message)
  if not ok then error(message, 2) end
end

local function upvalue(fn, wanted)
  for i = 1, 100 do
    local name, value = debug.getupvalue(fn, i)
    if not name then break end
    if name == wanted then return value end
  end
end

local voidTiles = upvalue(Structures.forMap, "voidTiles")
local roundTemplate = upvalue(Structures.buildCylinders, "roundTemplate")
expect(type(voidTiles) == "function", "void tile scan is not reachable")
expect(type(roundTemplate) == "function", "round template is not reachable")
expect(type(invalidator) == "function", "Structures did not register invalidation")

local function budgeted(fn)
  local result
  local co = coroutine.create(function() result = fn() end)
  local yields = 0
  repeat
    Budget.begin(co, 0.000005)
    local ok, why = coroutine.resume(co)
    Budget.finish()
    expect(ok, why)
    if coroutine.status(co) ~= "dead" then
      expect(why == "budget", "Structures yielded for a non-budget reason")
      yields = yields + 1
    end
  until coroutine.status(co) == "dead"
  return result, yields
end

local tileset = { image = "budget-atlas.png", tilesPerRow = 16 }
local first, voidYields = budgeted(function() return voidTiles(tileset) end)
expect(voidYields > 0, "void tile pixel scan did not honor the build budget")
expect(first[0] == true and first[95] == true,
       "all-black atlas was not classified as void")
local readsAfterFirst = pixelsRead

local second = voidTiles(tileset)
expect(second == first, "void tiles were not cached per tileset")
expect(pixelsRead == readsAfterFirst, "cached void tiles rescanned atlas pixels")
expect(assetLoads == 1, "cached void tiles reloaded the atlas")

Structures.invalidate("MAP_ONLY")
expect(voidTiles(tileset) == first,
       "map-only invalidation discarded the shared tileset scan")

-- Layout is part of the cache key even when two tilesets share one image.
local otherLayout = { image = "budget-atlas.png", tilesPerRow = 8 }
local third = voidTiles(otherLayout)
expect(third ~= first, "different tile layouts shared one void result table")
expect(assetLoads == 1, "layout-specific scan reloaded shared image data")

-- An asset reload clears both the pixels and the derived classification.
invalidator()
local fourth = voidTiles(tileset)
expect(fourth ~= first, "asset invalidation retained stale void tiles")
expect(assetLoads == 2, "asset invalidation did not reload atlas pixels")
expect(buildingInvalidations == 1,
       "full Structures invalidation did not reach Buildings")

-- A 32x32 all-white canopy is entirely outside/background and therefore
-- emits no hull. More importantly, both its pixel rows and its two outside
-- floods must cooperatively yield instead of running as one cold-map spike.
local white = {
  getPixel = function() return 1, 1, 1, 1 end,
}
local S = { tileAt = {} }
local function keyOf(tx, ty)
  return (ty + 64) * 4096 + (tx + 64)
end
for ty = 0, 3 do
  for tx = 0, 3 do
    S.tileAt[keyOf(tx, ty)] = ty * 4 + tx
  end
end
local map = {
  tileset = {
    tilesPerRow = 16,
    imageWidth = 128,
    imageHeight = 48,
  },
}
local quads, roundYields = budgeted(function()
  return roundTemplate(S, map, white, 0, 0, {}, 32)
end)
expect(#quads == 0, "all-background canopy unexpectedly emitted geometry")
expect(roundYields > 64,
       "round template pixel/flood work did not yield across phases")

-- Exercise the later chord/quad phases too. Cooperative suspension must not
-- change the deterministic template that a synchronous caller receives.
local black = {
  getPixel = function() return 0, 0, 0, 1 end,
}
local directQuads, directGround = roundTemplate(S, map, black, 0, 0, {}, 32)
local async, geometryYields = budgeted(function()
  local built, ground = roundTemplate(S, map, black, 0, 0, {}, 32)
  return { quads = built, ground = ground }
end)
expect(geometryYields > 0, "round template geometry never yielded")
expect(#async.quads == #directQuads,
       "budgeted round template changed the geometry size")
expect(async.ground == directGround,
       "budgeted round template changed the selected ground")
for i, q in ipairs(directQuads) do
  local aq = async.quads[i]
  expect(aq.shade == q.shade, "budgeted round template changed a face shade")
  for c = 1, 4 do
    for axis = 1, 3 do
      expect(aq[c][axis] == q[c][axis],
             "budgeted round template changed a face coordinate")
    end
  end
end

print("structures budget/cache: ok")
