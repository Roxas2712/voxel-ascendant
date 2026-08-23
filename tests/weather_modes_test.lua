local stored = { weather = "clear" }
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
  elseif name == "CanvasPresentation" then
    cache[name] = assert(loadfile("lib/CanvasPresentation.lua"))(V)
  else
    error("unexpected dependency " .. tostring(name))
  end
  return cache[name]
end

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected "
          .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function truthy(value, message)
  if not value then error(message or "expected a truthy value", 2) end
end

local Weather = assert(loadfile("lib/Weather.lua"))(V)

eq(#Weather.setting.values, 6, "weather row exposes all six modes")
eq(Weather.setting.values[5], "fog", "fog has a persisted setting rung")
eq(Weather.setting.values[6], "storm", "storm has a persisted setting rung")
eq(Weather.setting.labels[5], "FOG", "fog setting has a visible label")
eq(Weather.setting.labels[6], "STORM", "storm setting has a visible label")

local outside = {
  id = "PALLET_TOWN",
  def = { id = "PALLET_TOWN", tileset = "OVERWORLD", outdoor = true },
}
local inside = {
  id = "REDS_HOUSE_1F",
  def = { id = "REDS_HOUSE_1F", tileset = "HOUSE", outdoor = false },
}
local canopy = {
  id = "VIRIDIAN_FOREST",
  def = { id = "VIRIDIAN_FOREST", tileset = "FOREST", outdoor = false },
}

eq(Weather.isOutdoor(outside), true,
   "ordinary engine outdoors use the shared scenic predicate")
eq(Weather.isOutdoor(inside), false,
   "ordinary rooms remain outside the scenic exception contract")
for _, id in ipairs({
  "SAFARI_ZONE_CENTER", "SAFARI_ZONE_EAST",
  "SAFARI_ZONE_NORTH", "SAFARI_ZONE_WEST",
  "VERMILION_DOCK", "SS_ANNE_BOW",
}) do
  local scenic = {
    id = id,
    def = { id = id, tileset = "SPECIAL", outdoor = false },
  }
  eq(Weather.isOutdoor(scenic), true,
     id .. " overrides only its incorrect source interior metadata")
  eq(Weather.modeAt(scenic, "fog", 0), "fog",
     id .. " accepts outdoor fog through the shared predicate")
  eq(Weather.modeAt(scenic, "storm", 0), "storm",
     id .. " accepts outdoor storms through the shared predicate")
end

Weather.setting:sync("fog")
eq(Weather.mode(outside), "fog", "fog can be forced outdoors")
eq(Weather.mode(canopy), "fog", "fog reaches a sheltered outdoor forest")
eq(Weather.mode(inside), "clear", "fog never leaks indoors")
Weather.setting:sync("storm")
eq(Weather.mode(outside), "storm", "storm can be forced outdoors")
eq(Weather.mode(canopy), "storm",
   "thunderstorms reach a sheltered outdoor forest")
eq(Weather.mode(inside), "clear", "storm never leaks indoors")
eq(Weather.modeAt(outside, "off", 0), "clear", "OFF aliases the zero-cost mode")
eq(Weather.modeAt(outside, "garbage", 0), "clear",
   "unknown modes fail closed instead of drawing snow")

-- AUTO is a pure map/clock function.  Since 17 is coprime with 32, these
-- consecutive spells visit every bucket precisely once, including exactly
-- one storm and two fog spells.
local counts = { clear = 0, rain = 0, snow = 0, fog = 0, storm = 0 }
for period = 0, Weather.AUTO_BUCKETS - 1 do
  local t = period * Weather.AUTO_SECONDS + 0.25
  local mode = Weather.modeAt(outside, "auto", t)
  counts[mode] = (counts[mode] or 0) + 1
end
eq(counts.storm, 1, "AUTO makes thunderstorm spells rare")
eq(counts.fog, 2, "AUTO makes fog spells uncommon")
truthy(counts.rain > counts.storm, "AUTO keeps rain commoner than storms")
truthy(counts.clear > counts.fog, "AUTO remains dry most of the time")

for period = 0, 7 do
  local start = period * Weather.AUTO_SECONDS
  eq(Weather.modeAt(outside, "auto", start + 0.01),
     Weather.modeAt(outside, "auto", start + Weather.AUTO_SECONDS - 0.01),
     "AUTO mode is stable for the complete spell")
end

-- Clock mutation has a deterministic seam and refuses broken deltas.
Weather.setClock(12.5)
eq(Weather.clock, 12.5, "QA can pin the weather clock")
Weather.update(0.5)
eq(Weather.clock, 13, "runtime update advances the same clock")
Weather.update(0 / 0)
eq(Weather.clock, 13, "NaN cannot poison weather animation")

local stats
local oldLove = love
local function resetGraphics()
  stats = { rectangles = 0, lines = 0, circles = 0, ellipses = 0,
            pushes = 0, pops = 0, colors = {}, canvases = 0 }
  local g = {}
  function g.push() stats.pushes = stats.pushes + 1 end
  function g.pop() stats.pops = stats.pops + 1 end
  function g.origin() end
  function g.setCanvas() stats.canvases = stats.canvases + 1 end
  function g.setShader() end
  function g.setDepthMode() end
  function g.setBlendMode() end
  function g.translate() end
  function g.scale() end
  function g.setLineStyle() end
  function g.setLineWidth() end
  function g.setColor(r, green, b, a)
    stats.colors[#stats.colors + 1] = { r, green, b, a }
  end
  function g.rectangle(mode, x, y, w, h)
    eq(mode, "fill", "weather uses filled pixel primitives")
    truthy(type(x) == "number" and type(y) == "number"
           and type(w) == "number" and type(h) == "number",
           "weather rectangle is numeric")
    stats.rectangles = stats.rectangles + 1
  end
  function g.line(x1, y1, x2, y2)
    truthy(type(x1) == "number" and type(y1) == "number"
           and type(x2) == "number" and type(y2) == "number",
           "battle rain line is numeric")
    stats.lines = stats.lines + 1
  end
  function g.circle(mode, x, y, radius)
    eq(mode, "fill", "battle snow uses filled circles")
    truthy(type(x) == "number" and type(y) == "number"
           and type(radius) == "number", "battle snow circle is numeric")
    stats.circles = stats.circles + 1
  end
  function g.ellipse(mode, x, y, rx, ry)
    eq(mode, "fill", "battle fog uses filled ellipses")
    truthy(type(x) == "number" and type(y) == "number"
           and type(rx) == "number" and type(ry) == "number",
           "battle fog ellipse is numeric")
    stats.ellipses = stats.ellipses + 1
  end
  love = { graphics = g }
end

local canvas = {}
resetGraphics()
eq(Weather.apply(canvas, 320, 180, outside, 2, "clear"), canvas,
   "CLEAR preserves the completed canvas")
eq(stats.pushes, 0, "CLEAR does no graphics setup")
eq(stats.rectangles, 0, "CLEAR has no draw cost")
eq(Weather.apply(canvas, 320, 180, outside, 2, "off"), canvas,
   "OFF preserves the completed canvas")
eq(stats.pushes, 0, "OFF does no graphics setup")
eq(Weather.apply(canvas, 320, 180, outside, 2, "unknown"), canvas,
   "unknown resolved weather is a no-op")
eq(stats.pushes, 0, "unknown weather does no graphics setup")

resetGraphics()
Weather.setClock(7)
eq(Weather.apply(canvas, 320, 180, outside, 2, "fog"), canvas,
   "fog paints in-place")
eq(stats.pushes, 1, "fog owns one contained graphics pass")
eq(stats.pops, 1, "fog restores graphics state")
eq(stats.rectangles, 15, "fog stays a fixed fifteen-draw haze")

resetGraphics()
Weather.apply(canvas, 320, 180, outside, 2, "rain")
local rainDraws = stats.rectangles
truthy(rainDraws > 100, "rain remains visibly populated")
truthy(15 < rainDraws, "fog costs much less than rain")

resetGraphics()
Weather.applyBattle(canvas, 320, 180, outside, 2, "rain")
eq(stats.rectangles, 1,
   "battle rain uses one restrained atmospheric grade")
eq(stats.lines, 88,
   "battle rain uses three bounded perspective depth bands")
truthy(stats.lines < rainDraws,
       "battle rain is calmer than the overworld voxel staircase")

resetGraphics()
Weather.applyBattle(canvas, 320, 180, outside, 2, "snow")
eq(stats.rectangles, 1, "battle snow uses one atmospheric grade")
eq(stats.circles, 42, "battle snow uses bounded soft flakes")

resetGraphics()
Weather.applyBattle(canvas, 320, 180, outside, 2, "fog")
eq(stats.rectangles, 1, "battle fog uses one subtle veil")
eq(stats.ellipses, 6, "battle fog uses six soft depth wisps")

-- Find one deterministic flash frame without waiting in real time.  Replaying
-- it gives the same strength/key and the storm adds both rain and illumination.
local flashClock, flashStrength, flashKey
for ms = 0, Weather.LIGHTNING_SECONDS * 1000 do
  local t = ms / 1000
  local strength, key = Weather.lightningAt(t, outside)
  if strength > 0.90 then
    flashClock, flashStrength, flashKey = t, strength, key
    break
  end
end
truthy(flashClock ~= nil, "deterministic lightning window is reachable")
local replayStrength, replayKey = Weather.lightningAt(flashClock, outside)
eq(replayStrength, flashStrength, "lightning strength replays exactly")
eq(replayKey, flashKey, "lightning occurrence replays exactly")

local thunder = 0
Weather.setThunderHook(function(map, strength, key)
  eq(map, outside, "thunder receives the active map")
  truthy(strength > 0, "thunder only fires during a flash")
  eq(key, flashKey, "thunder and lightning share an occurrence")
  thunder = thunder + 1
end)
resetGraphics()
Weather.setClock(flashClock)
Weather.apply(canvas, 320, 180, outside, 2, "storm")
local stormDraws = stats.rectangles
truthy(stormDraws > rainDraws, "storm rain is visibly denser than rain")
eq(thunder, 1, "first flash may trigger one optional thunder hook")
Weather.apply(canvas, 320, 180, outside, 2, "storm")
eq(thunder, 1, "the same flash frame never repeats thunder")

-- A faulty optional audio integration is fully isolated from rendering.
Weather.setThunderHook(function() error("missing sample") end)
local ok, result = pcall(Weather.apply, canvas, 320, 180, outside, 2, "storm")
eq(ok, true, "broken thunder callback cannot break the weather pass")
eq(result, canvas, "broken thunder callback still returns the world canvas")
Weather.setThunderHook(nil)
love = oldLove

print("weather modes: ok")
