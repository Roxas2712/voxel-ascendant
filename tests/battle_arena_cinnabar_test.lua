-- Cinnabar MAP battles must never fall back to the automatic land clearing
-- under the island's broad roof.  The authored arena is a fully-waterborne
-- 3x6 strip whose camera looks back toward the island from open sea.

local engineRoot = os.getenv("GEN1RECOMP_0190_ROOT") or "../gen1recomp"
local maps = assert(loadfile(engineRoot .. "/data/generated/maps.lua"))()
local tilesets = assert(loadfile(engineRoot .. "/data/generated/tilesets.lua"))()
local Map = assert(loadfile(engineRoot .. "/src/world/Map.lua"))()

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected " .. tostring(expected)
          .. ", got " .. tostring(actual), 2)
  end
end

local cache = {}
local V = {}
function V.data(name)
  return assert(loadfile("data/" .. name .. ".lua"))()
end
function V.require(name)
  if cache[name] then return cache[name] end
  if name == "VoxelScene" then
    cache[name] = { groundAt = function() return 0 end }
  elseif name == "ModSetting" then
    cache[name] = { new = function(_, _, _, _, default)
      return { get = function() return default end }
    end }
  else
    cache[name] = assert(loadfile("lib/" .. name .. ".lua"))(V)
  end
  return cache[name]
end

local def = assert(maps.CINNABAR_ISLAND, "missing canonical Cinnabar map")
local map = Map.new(def, assert(tilesets[def.tileset]))
local Arena = V.require("BattleArena")
local pick = assert(Arena.authoredFor("CINNABAR_ISLAND"),
                    "Cinnabar lost its authored water arena")
eq(pick.x, 1, "Cinnabar arena west coordinate")
eq(pick.y, 10, "Cinnabar arena north coordinate")
eq(pick.shape, "wide", "Cinnabar arena shape")

local arena = assert(Arena.find(map, 10, 4, false),
                     "Cinnabar authored arena no longer fits the real map")
eq(arena.x, 1, "land-triggered Cinnabar battle escaped the water arena")
eq(arena.y, 10, "land-triggered Cinnabar battle escaped the water arena")
eq(arena.playerCell[1], 2, "Cinnabar player mon x")
eq(arena.playerCell[2], 14, "Cinnabar player mon y")
eq(arena.enemyCell[1], 2, "Cinnabar enemy mon x")
eq(arena.enemyCell[2], 11, "Cinnabar enemy mon y")
for cy = pick.y, pick.y + 5 do
  for cx = pick.x, pick.x + 2 do
    if not map:isWaterCell(cx, cy) then
      error(("Cinnabar arena cell %d,%d is not canonical water"):format(cx, cy))
    end
    if map:warpAtCell(cx, cy) or map:isWarpTileCell(cx, cy) then
      error(("Cinnabar arena cell %d,%d overlaps a warp"):format(cx, cy))
    end
  end
end

local cam = V.require("BattleCam").rig(arena, 0, true)
if not (cam and cam.eye and cam.eye[3] > map.heightCells * 16) then
  error("Cinnabar canonical battle eye no longer stands beyond the south shore")
end
if not (cam.focus and cam.focus[3] < cam.eye[3]) then
  error("Cinnabar canonical battle eye no longer looks north toward the island")
end

print("Cinnabar battle arena: ok")
