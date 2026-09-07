-- Pure Gen-1 panorama grade for a settled snow surface.
--
-- Weather and its accumulation remain owned by Weather/WeatherTweak, while
-- DayNight remains the scene-light owner. This adapter only supplies a
-- per-draw colour multiplier for the distant authored panorama. The scene
-- shader applies its existing dayTint afterwards, so the same grade stays
-- warm at dusk and moonlit at night without owning another clock or shader.

local _ = ...
local PanoramaSnowGrade = {}

PanoramaSnowGrade.FULL = { 0.82, 0.90, 1.00, 1.00 }

local function clamp01(value, fallback)
  value = tonumber(value)
  if value == nil or value ~= value then return fallback end
  return math.max(0, math.min(1, value))
end

function PanoramaSnowGrade.color(weather, amount, outdoor, surfaces)
  if outdoor ~= true or surfaces == false or weather ~= "snow" then return nil end
  -- A missing/invalid coat is not permission to manufacture full snow. The
  -- Weather owner must hand over a finite, positive accumulation receipt.
  amount = clamp01(amount, 0)
  if amount <= 0 then return nil end
  local target = PanoramaSnowGrade.FULL
  return {
    1 + (target[1] - 1) * amount,
    1 + (target[2] - 1) * amount,
    1 + (target[3] - 1) * amount,
    1,
  }
end

return PanoramaSnowGrade
