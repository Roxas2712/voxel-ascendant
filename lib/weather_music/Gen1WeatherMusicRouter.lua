-- Pure Gen-1 Weather Music selection.  This module never starts audio and
-- never reads mutable game state: callers hand it one already-stable map /
-- weather / time receipt and it returns either an immutable weather cue plan
-- or the exact native cue it was given.

local Router = {}
Router.__index = Router

Router.API_VERSION = 1
Router.SCHEMA = "voxel-ascendant/weather-music-route/v1"

local WEATHER_VARIANT = {
  storm = "Storm",
  snow = "Winter",
  winter = "Winter",
  rain = "Rain",
  heat = "Heat",
}

local function text(value)
  if type(value) ~= "string" or value == "" then return nil end
  return value
end

local function normalized(value)
  value = text(value)
  return value and value:lower() or nil
end

local function matchesNativeReference(family, songId)
  if type(family) ~= "table" or text(songId) == nil
      or type(family.nativeSongIds) ~= "table" then return false end
  for _, edition in ipairs({ "red", "blue", "yellow" }) do
    if family.nativeSongIds[edition] == songId then return true end
  end
  return false
end

local function native(input, reason)
  return {
    schema=Router.SCHEMA,
    apiVersion=Router.API_VERSION,
    action="native",
    reason=reason,
    mapId=text(input and input.mapId),
    weatherCode=normalized(input and input.weatherCode) or "unknown",
    timeOfDay=text(input and input.timeOfDay) or "UNKNOWN",
    songId=input and input.nativeSongId or nil,
    requestToken=input and input.requestToken or nil,
  }
end

function Router.new(catalog)
  if type(catalog) ~= "table"
      or type(catalog.map) ~= "function"
      or type(catalog.variant) ~= "function" then
    return nil, "weather music catalog capability is unavailable"
  end
  return setmetatable({ catalog=catalog }, Router)
end

-- Priority is deliberately encoded once here:
-- storm > snow/winter > rain > heat > night > native.
function Router:select(input)
  input = type(input) == "table" and input or {}
  if tonumber(input.generation) ~= 1 then return native(input, "not-gen1") end
  if input.reason ~= "map" then return native(input, "priority-owner") end
  if input.mapReady ~= true then return native(input, "map-not-ready") end
  if input.stable ~= true then return native(input, "state-not-stable") end
  if input.optionEnabled ~= true then return native(input, "option-off") end
  if input.surfing == true then return native(input, "surf-owner") end
  if input.higherPriority == true then
    return native(input, "priority-owner")
  end

  local mapId = text(input.mapId)
  -- Cycling is a map-owned outdoor state in the engine, but its own native
  -- composition supersedes every route/city theme. Use the dedicated family
  -- before map/theme lookup so Rain/Night/etc. stay Bicycle arrangements and
  -- dismounting returns to the underlying map family through the same hook.
  local themeMapId = input.onBike == true and "BICYCLE" or mapId
  local family = themeMapId and self.catalog.map(themeMapId) or nil
  if not family and type(self.catalog.themeMap) == "function" then
    themeMapId = self.catalog.themeMap(input.nativeSongId)
    family = themeMapId and self.catalog.map(themeMapId) or nil
  end
  if not family then return native(input, "unregistered-map") end

  local code = normalized(input.weatherCode) or "clear"
  local variant = WEATHER_VARIANT[code]
  if not variant and tostring(input.timeOfDay):upper() == "NIGHT" then
    variant = "Night"
  end
  if not variant then return native(input, "clear-day") end

  local cue = self.catalog.variant(themeMapId, variant)
  if not cue then return native(input, "missing-variant") end
  if cue.runtimeReady == false then return native(input, "asset-unavailable") end

  local phaseMode = cue.synchronous == false and "phrase" or "phase"
  if phaseMode == "phrase" and not cue.safePhraseFallback then
    return native(input, "unsynchronised-pair")
  end
  local transitionBars = tonumber(cue.transitionBars)
    or (variant == "Storm" and 1 or 2)
  if variant == "Storm" then
    transitionBars = math.max(1, math.min(2, transitionBars))
  else
    transitionBars = math.max(2, math.min(4, transitionBars))
  end

  return {
    schema=Router.SCHEMA,
    apiVersion=Router.API_VERSION,
    action="weather",
    reason="weather-" .. variant:lower(),
    mapId=mapId,
    themeMapId=themeMapId,
    weatherCode=code,
    timeOfDay=text(input.timeOfDay) or "UNKNOWN",
    nativeSongId=input.nativeSongId,
    -- A LocalMusic/KASC/user replacement remains the exact fallback, but it
    -- must never be declared phase-compatible merely because it replaced the
    -- native cue.  The adapter uses this receipt to select ordinary crossfade
    -- for unknown arrangements and synchronous transfer for actual R/B/Y.
    nativeSongMatched=matchesNativeReference(family, input.nativeSongId),
    songId=cue.songId,
    family=family.family,
    compositionId=family.compositionId,
    variant=variant,
    phaseMode=phaseMode,
    equalPower=true,
    transitionBars=transitionBars,
    beatsPerBar=family.beatsPerBar,
    bpm=family.bpm,
    introEndSeconds=family.introEndSeconds,
    loopStartSeconds=family.loopStartSeconds,
    loopEndSeconds=family.loopEndSeconds,
    loopSeconds=family.loopSeconds,
    downbeatOriginSeconds=family.safeDownbeats
      and family.safeDownbeats.originSamples
      and family.safeDownbeats.originSamples
        / (tonumber(family.sampleRate) or 48000)
      or family.introEndSeconds,
    downbeatStepSeconds=family.safeDownbeats
      and family.safeDownbeats.stepSamples
      and family.safeDownbeats.stepSamples
        / (tonumber(family.sampleRate) or 48000)
      or (60 / family.bpm * family.beatsPerBar),
    phraseSeconds=family.phraseFrames
      and family.phraseFrames / (tonumber(family.sampleRate) or 48000)
      or family.loopSeconds,
    safeDownbeatEveryBars=family.safeDownbeatEveryBars,
    phraseBars=family.phraseBars,
    requestToken=input.requestToken,
  }
end

return Router
