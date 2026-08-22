local stored = { daytime = "day" }
local cache = {}

local V = {
  mod = {
    id = "VOXEL_ASCENDANT",
    options = { get = function(_, key) return stored[key] end },
  },
}

function V.require(name)
  if cache[name] then return cache[name] end
  if name == "ModSetting" then
    cache[name] = assert(loadfile("lib/ModSetting.lua"))(V)
  else
    cache[name] = {}
  end
  return cache[name]
end

package.preload["src.render.PaletteFX"] = function()
  return { effectiveColors = function(palette) return palette end }
end
package.preload["src.world.Map"] = function() return {} end

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected "
          .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function truthy(value, message)
  if not value then error(message or "expected a truthy value", 2) end
end

local function sum(color)
  return (color[1] or 0) + (color[2] or 0) + (color[3] or 0)
end

local DayNight = assert(loadfile("lib/DayNight.lua"))(V)
cache.DayNight = DayNight

local forest = { id = "VIRIDIAN_FOREST", def = { tileset = "FOREST" } }
local forestByDef = { def = { id = "VIRIDIAN_FOREST", tileset = "FOREST" } }
local room = { id = "REDS_HOUSE_1F", def = { tileset = "REDSHOUSE1" } }
local route = { id = "ROUTE_1", def = { outdoor = true,
                                        tileset = "OVERWORLD" } }

eq(DayNight.isCanopy(forest), true, "Viridian Forest is a canopy map")
eq(DayNight.isCanopy(forestByDef), true,
   "canopy lookup tolerates definitions that carry the id")
eq(DayNight.isCanopy(room), false, "ordinary rooms are not canopy maps")

local dayPalette = DayNight.canopyPalette(DayNight.T.day)
local nightPalette = DayNight.canopyPalette(DayNight.T.night)
eq(#dayPalette, 4, "canopy exposes a display-mode-shaped palette")
eq(#nightPalette, 4, "night canopy keeps all four shades")
truthy(sum(dayPalette[2]) > sum(nightPalette[2]),
       "the canopy darkens with the same day/night dial")
truthy(dayPalette[2][2] > dayPalette[2][1],
       "day canopy is pressed toward leaf green")
truthy(sum(nightPalette[2]) > 0, "night canopy never collapses to black")

local enabled, dressCalls = true, 0
cache.Sky = {
  enabled = function() return enabled end,
  haze = function() return { 0.7, 0.8, 0.9 } end,
  dress = function(sky)
    dressCalls = dressCalls + 1
    sky.bands = { { 0.1, 0.2, 0.3 }, { 0.7, 0.8, 0.9 } }
    return sky
  end,
}
cache.HorizonWall = {
  hasSky = function(map) return map and map.def and map.def.outdoor or false end,
}
cache.VoxelState = { angle = math.rad(30) }

local VoxelScene = assert(loadfile("lib/VoxelScene.lua"))(V)

DayNight.setting:sync("day")
local daySky = VoxelScene.skyColor(forest, 1)
truthy(daySky, "canopy map receives an opaque backdrop")
eq(daySky[4], 1, "canopy backdrop carries the requested strength")
eq(daySky.canopy, true, "canopy descriptor marks its closed-sky semantics")
truthy(sum(daySky) > 0, "canopy backdrop is not the black void")

DayNight.setting:sync("night")
local nightSky = VoxelScene.skyColor(forest, 1)
truthy(sum(daySky) > sum(nightSky),
       "rendered canopy fill follows the selected hour")

dressCalls = 0
local forestFrame = VoxelScene._skyFor(forest)
truthy(forestFrame, "free-roam forest frame keeps its backdrop")
eq(forestFrame.bands, nil,
   "canopy backdrop has no open-sky bands or celestial bodies")
eq(dressCalls, 0, "canopy bypasses open-sky dressing")

local routeFrame = VoxelScene._skyFor(route)
truthy(routeFrame and routeFrame.bands,
       "true outdoor maps retain their banded open sky")
eq(dressCalls, 1, "open outdoor sky still uses the normal dressing")
eq(VoxelScene.skyColor(room, 1), nil, "sealed rooms retain no sky")

enabled = false
eq(VoxelScene.skyColor(forest, 1), nil,
   "the explicit SKY OFF control still suppresses canopy fill")

print("canopy sky: ok")
