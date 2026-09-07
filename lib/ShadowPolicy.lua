-- Optional policy seam for companion mods that want to narrow VASC's
-- overworld shadows without replacing the renderer. With no provider the
-- historical full-world shadow pass remains unchanged.

local ShadowPolicy = {}

local provider

local function clamp(value, lo, hi, fallback)
  value = tonumber(value)
  if not value or value ~= value or value == math.huge or value == -math.huge then
    return fallback
  end
  return math.max(lo, math.min(hi, value))
end

function ShadowPolicy.setProvider(value)
  provider = type(value) == "function" and value or nil
end

function ShadowPolicy.resolve(context)
  context = context or {}
  local supplied
  if provider then
    local ok, value = pcall(provider, context)
    if ok and type(value) == "table" then supplied = value end
  end

  -- VASC owns its weather even with no companion installed. Rain, storm,
  -- fog and snow are overcast presentations, so the hard sun/world pass must
  -- not remain visible beneath them. Keeping that pass was the source of the
  -- large dark bands reported in 3.0 RC2. Clear and heat retain the historical
  -- full-world fallback; an external provider may still narrow it further.
  if not supplied then
    local weather = tostring(context.weather or "clear"):lower()
    local overcast = weather == "rain" or weather == "storm"
      or weather == "fog" or weather == "snow"
    return {
      enabled = not overcast,
      casters = overcast and "none" or "world",
      cloudOpacity = 0,
      cloudProgress = 0,
      cloudSeed = 0,
      birdOpacity = 0,
      birdEnabled = false,
      birdProgress = 0,
      birdSeed = 0,
      key = overcast and ("vasc-weather-cutoff:" .. weather)
        or "legacy-world",
    }
  end

  local casters = supplied.casters
  if casters ~= "objects" and casters ~= "world" then casters = "none" end
  -- Ambient-only weather events deliberately carry no map casters: rain and
  -- storm may show Lugia's synchronized silhouette, and HEAT may do the same
  -- for Ho-Oh, while the ordinary sun/world pass stays completely inactive.
  local enabled = supplied.enabled ~= false
                  and (casters ~= "none" or supplied.birdEnabled == true)
  local cloudOpacity = enabled
    and clamp(supplied.cloudOpacity, 0, 0.24, 0) or 0
  local cloudProgress = cloudOpacity > 0
    and clamp(supplied.cloudProgress, 0, 1, 0) or 0
  local cloudSeed = cloudOpacity > 0
    and clamp(supplied.cloudSeed, 0, 65521, 0) or 0
  local birdOpacity = enabled
    and clamp(supplied.birdOpacity, 0, 0.35, 0) or 0
  local birdEnabled = enabled and supplied.birdEnabled == true
  local birdProgress = birdOpacity > 0
    and clamp(supplied.birdProgress, 0, 1, 0) or 0
  local birdSeed = birdOpacity > 0
    and clamp(supplied.birdSeed, 0, 65521, 0) or 0
  return {
    enabled = enabled,
    casters = enabled and casters or "none",
    cloudOpacity = cloudOpacity,
    cloudProgress = cloudProgress,
    cloudSeed = cloudSeed,
    birdOpacity = birdOpacity,
    birdEnabled = birdEnabled,
    birdProgress = birdProgress,
    birdSeed = birdSeed,
    key = table.concat({
      enabled and "on" or "off",
      enabled and casters or "none",
      tostring(supplied.key or "external"),
    }, ":"),
  }
end

return ShadowPolicy
