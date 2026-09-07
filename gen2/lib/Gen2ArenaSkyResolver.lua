-- Johto-private Arena sky/weather policy. It never changes the overworld map
-- and never participates in MAP/DISCS positioning. Authored PNG alpha decides
-- where celestial sky may be visible; only a genuinely outdoor Arena receives
-- precipitation, ground weather and weather grading.

local Resolver = { last=nil }

local function normalizeWeather(value)
  value = tostring(value or "clear"):lower()
  if value == "rainbow" then return "clear", "rainbow" end
  if value == "rain" or value == "snow" or value == "fog"
      or value == "storm" or value == "heat" then
    return value, value
  end
  return "clear", value
end

function Resolver.resolve(arena, mapOutdoor, resolvedWeather, skyPolicy)
  arena = type(arena) == "table" and arena or {}
  skyPolicy = type(skyPolicy) == "table" and skyPolicy or {}
  local isArena = arena.painting == true and arena.arenaStyle ~= nil
  local outdoor = isArena and mapOutdoor == true
  local apertureSky = isArena and skyPolicy.voxelSky == true
  local celestial = outdoor or apertureSky
  local normalized, requested = normalizeWeather(resolvedWeather)
  local receipt = {
    schema="voxel-ascendant/gen2-arena-sky/v1",
    isArena=isArena,
    outdoor=outdoor,
    celestial=celestial,
    voxelSky=apertureSky,
    skyAperture=apertureSky and skyPolicy.skyAperture or nil,
    -- Indoor windows show the clock sky (sun/moon/clouds/rainbow) but never
    -- rain, snow, fog or storm particles inside the room.
    skyWeather=outdoor and normalized or "clear",
    particleWeather=outdoor and normalized or nil,
    groundWeather=outdoor and normalized or nil,
    backdropWeather=outdoor and normalized or nil,
    requestedWeather=requested,
    source=outdoor and "johto-arena-outdoor"
      or apertureSky and "johto-arena-alpha-window"
      or "johto-arena-closed-indoor",
  }
  Resolver.last = receipt
  return receipt
end

function Resolver.status()
  local src = Resolver.last
  if type(src) ~= "table" then
    return { schema="voxel-ascendant/gen2-arena-sky/v1" }
  end
  local out = {}
  for key, value in pairs(src) do out[key] = value end
  return out
end

return Resolver
