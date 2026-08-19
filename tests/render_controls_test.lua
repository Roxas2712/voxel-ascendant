local cache = {}
local stored = {}

local V = {
  mod = {
    id = "VOXEL_ASCENDANT",
    options = {
      get = function(_, key) return stored[key] end,
    },
  },
}

function V.require(name)
  if cache[name] then return cache[name] end
  local value = assert(loadfile("lib/" .. name .. ".lua"))(V)
  cache[name] = value
  return value
end

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected "
          .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local grid = V.require("VoxelGrid")
local shadows = V.require("Shadows")

eq(grid.enabled(), false, "free-roam grid keeps its historical default")
eq(grid.battleEnabled(), true, "battle grid defaults on for upgrades")
eq(shadows.enabled(), true, "shadows default on for upgrades")

grid.battleSetting:sync(false)
eq(grid.battleEnabled(), false, "battle grid can be disabled independently")
eq(grid.enabled(), false, "battle grid does not rewrite free-roam grid")

grid.setting:sync(true)
eq(grid.enabled(), true, "free-roam grid can remain enabled")
eq(grid.battleEnabled(), false, "battle grid remains disabled")

shadows.setting:sync(false)
eq(shadows.enabled(), false, "shadows can be disabled")
shadows.setting:sync(true)
eq(shadows.enabled(), true, "shadows can be restored")

print("render controls: ok")
