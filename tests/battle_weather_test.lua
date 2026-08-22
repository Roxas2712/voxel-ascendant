local calls = { modes = {}, applies = {} }

local Weather = {}

function Weather.isOutdoor(map)
  return map and map.def and map.def.outdoor and true or false
end

function Weather.mode(map)
  calls.modes[#calls.modes + 1] = map
  if not (map and map.def and map.def.outdoor) then return "clear" end
  return map.weather or "clear"
end

function Weather.apply(canvas, w, h, map, cell, resolved)
  calls.applies[#calls.applies + 1] = {
    canvas = canvas, w = w, h = h, map = map,
    cell = cell, resolved = resolved,
  }
  return { source = canvas, weather = resolved }
end

local V = {}
function V.require(name)
  if name == "Weather" then return Weather end
  return {}
end

package.preload["src.render.PaletteFX"] = function() return {} end
package.preload["src.world.Map"] = function()
  return { isOutdoor = function(def) return def and def.outdoor or false end }
end

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected "
          .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local BattleScene = assert(loadfile("lib/BattleScene.lua"))(V)

for _, kind in ipairs({ "rain", "snow", "fog", "storm" }) do
  local host = { id = "OUTDOOR_" .. kind, def = { outdoor = true },
                 weather = kind }
  eq(BattleScene.weatherMode(host), kind,
     kind .. " is resolved from the arena host map")
  local canvas = { kind = "battle" }
  local painted = BattleScene.applyWeather(canvas, 960, 720, host, 3, kind)
  local call = calls.applies[#calls.applies]
  eq(call.canvas, canvas, kind .. " paints the completed 3D battle canvas")
  eq(call.map, host, kind .. " uses the arena host for weather gates")
  eq(call.w, 960, kind .. " receives the expanded battle width")
  eq(call.h, 720, kind .. " receives the expanded battle height")
  eq(call.cell, 3, kind .. " keeps the voxel pixel scale")
  eq(call.resolved, kind, kind .. " is passed as one stable frame mode")
  eq(painted.weather, kind, kind .. " overlay remains on the battle shot")
end

local room = { id = "ROOM", def = { outdoor = false }, weather = "storm" }
eq(BattleScene.weatherMode(room), "clear",
   "indoor battles stay clear even when an outdoor mode was selected")
local modeCalls = #calls.modes
local dry = BattleScene.applyWeather({ kind = "room" }, 640, 480,
                                     room, 2, "clear")
eq(#calls.modes, modeCalls,
   "an already-resolved mode is not recomputed while painting")
eq(dry.weather, "clear", "the clear interior mode reaches Weather.apply")

print("battle weather: ok")
