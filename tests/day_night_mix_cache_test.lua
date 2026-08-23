-- The sky, window lights, water reflection and world.tod hook all ask for
-- the same phase mix during a frame. That answer is immutable to its callers,
-- so an exact clock value must share one table without rounding the clock.

local cache = {}
local V = { mod = { id = "VOXEL_ASCENDANT" } }
local selected = "cycle"
local declared = nil

function V.require(name)
  if cache[name] then return cache[name] end
  if name == "ModSetting" then
    cache[name] = {
      new = function(key, label, values, labels, defaultValue)
        declared = { key = key, label = label, values = values,
                     labels = labels, defaultValue = defaultValue }
        return {
          get = function() return selected end,
          setIndex = function(_, index) selected = values[index] end,
        }
      end,
    }
  else
    cache[name] = {}
  end
  return cache[name]
end

package.preload["src.render.PaletteFX"] = function()
  return { effectiveColors = function(colors) return colors end }
end

local DayNight = assert(loadfile("lib/DayNight.lua"))(V)

local function expect(ok, message)
  if not ok then error(message, 2) end
end

local function near(actual, expected, message)
  if math.abs(actual - expected) > 1e-9 then
    error((message or "values differ") .. ": expected "
          .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

expect(declared and declared.defaultValue == "cycle",
       "an unset DAYTIME option did not default to the automatic clock")
expect(declared.labels[5] == "AUTO" and declared.values[5] == "cycle",
       "AUTO label broke stored CYCLE-value compatibility")
expect(DayNight.BLEND == 40,
       "dawn/dusk grew large enough to displace the day/night plateaus")
expect(DayNight.K_MAX <= 0.70 and DayNight.ALPHA_SUN <= 0.30
       and DayNight.ALPHA_MOON <= 0.18,
       "city shadows can again grow into opaque multi-building masses")
for t = 0, DayNight.CYCLE, 5 do
  local kx, kz = DayNight.shearAt(t)
  expect(math.sqrt(kx * kx + kz * kz) <= DayNight.K_MAX + 1e-9,
         "a time-of-day shadow exceeded the compact footprint clamp")
end
expect(DayNight.mix(100).day == 1,
       "the long daytime plateau is not a pure DAY phase")
expect(DayNight.mix(900).night == 1,
       "the long nighttime plateau is not a pure NIGHT phase")

DayNight.clock = DayNight.T.day
DayNight.update(1)
near(DayNight.clock, DayNight.T.day + 1,
     "AUTO did not advance without a manual FULL preset")
selected = "day"
DayNight.update(10)
near(DayNight.clock, DayNight.T.day + 1,
     "a manual DAY pin advanced the save-local clock")
selected = "cycle"
DayNight.update(1)
near(DayNight.clock, DayNight.T.day + 1,
     "returning from DAY to AUTO did not continue from the visible pin")

-- Halfway from golden hour to dusk gives a useful two-key answer rather than
-- a plateau, and exercises every read-only consumer below.
local t = 580
local first = DayNight.mix(t)
local again = DayNight.mix(t)
expect(rawequal(first, again), "an exact repeated time rebuilt its mix")
near(first.golden, 0.5, "golden weight")
near(first.dusk, 0.5, "dusk weight")

-- Existing consumers may iterate the shared answer but must not mutate it.
-- Run every DayNight-side consumer that reads mix, then verify the cached
-- weights and identity are untouched.
DayNight.palette(t)
DayNight.tint(true, t)
DayNight.glow(t)
DayNight.windowLight(t)
DayNight.tod(t)
expect(rawequal(first, DayNight.mix(t)),
       "a read-only consumer replaced the exact-time mix")
near(first.golden, 0.5, "consumer mutated golden weight")
near(first.dusk, 0.5, "consumer mutated dusk weight")

-- Modulo-equivalent clock positions have always produced the same answer;
-- normalising before the cache lookup preserves that contract and shares it.
expect(rawequal(first, DayNight.mix(t + DayNight.CYCLE)),
       "cycle-equivalent times did not share the phase answer")

local changed = DayNight.mix(t + 0.25)
expect(not rawequal(first, changed),
       "a genuinely changed clock reused a stale phase answer")
expect(changed.golden < first.golden and changed.dusk > first.dusk,
       "the exact sub-second blend stopped advancing")

local nightWindow = DayNight.windowScene(DayNight.T.night)
expect(nightWindow.alpha >= .85 and nightWindow.stars >= .9
       and nightWindow.moon == 1,
       "indoor windows still show a painted daytime exterior at night")
local dayWindow = DayNight.windowScene(DayNight.T.day)
expect(dayWindow.alpha == 0 and dayWindow.stars == 0
       and dayWindow.moon == 0,
       "daytime windows are needlessly painted over")

print("day/night exact-time phase mix cache: ok")
