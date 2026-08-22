local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected " .. tostring(expected)
          .. ", got " .. tostring(actual), 2)
  end
end

local shipped = assert(loadfile("data/battle_arenas.lua"))()
eq(#shipped.ROUTE_3.spots, 4, "Route 3 did not gain multiple reviewed anchors")
eq(#shipped.MT_MOON_1F.spots, 6,
   "Mt Moon 1F did not gain upper/lower-map anchors")
eq(#shipped.CERULEAN_CITY.spots, 4,
   "Cerulean did not replace the house-alley singleton")

local authored = {
  MULTI = { adaptive = false, spots = {
    { x = 2, y = 5, shape = "wide" },
    { x = 20, y = 5, shape = "wide" },
  } },
  LOCAL = { x = 25, y = 5, shape = "wide" },
  TEST_CITY = { x = 2, y = 3, shape = "wide" },
  HOUSE_TEST = { x = 12, y = 2, shape = "narrow" },
}

local V = {}
function V.data(name)
  if name == "battle_arenas" then return authored end
  error("unexpected data " .. tostring(name))
end
function V.require(name)
  if name == "VoxelScene" then
    return { groundAt = function(map, x, y) return map:heightAt(x, y) end }
  end
  if name == "BattleCam" then
    -- A missing canonical eye makes clearance conservatively accept the
    -- fixture; selection/height/apron logic is what this test owns.
    return { rig = function() return nil end }
  end
  error("unexpected module " .. tostring(name))
end

local Arena = assert(loadfile("lib/BattleArena.lua"))(V)

local function map(id, walk, height, tileset)
  local m = { id = id, widthCells = 32, heightCells = 20,
              def = { tileset = tileset or "OVERWORLD" } }
  function m:inBounds(x, y)
    return x >= 0 and y >= 0 and x < self.widthCells and y < self.heightCells
  end
  function m:isWalkableCell(x, y)
    return self:inBounds(x, y) and (not walk or walk(x, y))
  end
  function m:warpAtCell() return nil end
  function m:isWarpTileCell() return false end
  function m:isGrassCell() return false end
  function m:isWaterCell() return false end
  function m:heightAt(x, y) return height and height(x, y) or 0 end
  return m
end

local terraces = map("MULTI", nil, function(x) return x >= 15 and 6 or 0 end)
local high = assert(Arena.find(terraces, 22, 8, false))
eq(high.x, 20, "high player did not select the high/east reviewed anchor")
eq(high.anchorIndex, 2, "high reviewed anchor index")
eq(high.anchorHeight, 6, "high reviewed anchor height")
local low = assert(Arena.find(terraces, 3, 8, false))
eq(low.x, 2, "low player did not select the low/west reviewed anchor")
eq(low.anchorIndex, 1, "low reviewed anchor index")

local open = map("LOCAL")
local nearby = assert(Arena.find(open, 6, 10, false))
eq(nearby.anchorSource, "local-height",
   "nearby same-height clearing did not precede far fallback")
eq(nearby.anchorHeight, 0, "local anchor height")
if math.abs(nearby.mid[1] / 16 - 6) > 18 then
  error("local anchor escaped the bounded encounter neighbourhood")
end

-- A three-cell city alley fits the wide battle footprint exactly but has no
-- one-cell apron. The adaptive urban search must refuse it and retain the
-- reviewed fallback instead of manufacturing a house-corridor battle.
local alley = map("TEST_CITY", function(x, y)
  return x >= 2 and x <= 4 and y >= 1 and y <= 12
end)
local city = assert(Arena.find(alley, 3, 9, false))
eq(city.anchorSource, "authored", "urban alley passed the open-apron gate")
eq(city.x, 2, "urban fallback moved")

-- Interior maps retain their reviewed spot instead of moving an authored
-- encounter to another room/corridor through the outdoor local search.
local interior = map("HOUSE_TEST", nil, nil, "HOUSE")
local inside = assert(Arena.find(interior, 1, 2, false))
eq(inside.anchorSource, "authored",
   "interior unexpectedly used an adaptive local anchor")
eq(inside.x, 12, "interior reviewed fallback moved")

print("battle anchors: multi-height/local/apron selection ok")
