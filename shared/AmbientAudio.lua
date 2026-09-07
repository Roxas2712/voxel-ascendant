-- Small shared audio focus owner for weather details. It never owns music or
-- changes the saved volume: the engine's music.volume seam receives a brief
-- multiplier and returns smoothly to the user's configured level.

local V = ...
local AmbientAudio = {
  remaining = 0, duration = 0, target = 1,
  installed = false, lastWeatherKey = nil, windSource = nil,
}

local RATE, WIND_SECONDS = 11025, 1.8

local function finite(value, fallback)
  if type(value) ~= "number" or value ~= value
      or value == math.huge or value == -math.huge then return fallback end
  return value
end

function AmbientAudio.factor()
  if AmbientAudio.remaining <= 0 or AmbientAudio.duration <= 0 then return 1 end
  local left = math.max(0, math.min(1,
    AmbientAudio.remaining / AmbientAudio.duration))
  -- Hold the dip briefly, then use a smooth return with no volume step.
  local recovery = 1 - left
  recovery = recovery * recovery * (3 - 2 * recovery)
  return AmbientAudio.target + (1 - AmbientAudio.target) * recovery
end

function AmbientAudio.duck(target, seconds)
  target = math.max(.35, math.min(1, finite(target, 1)))
  seconds = math.max(0, finite(seconds, 0))
  if seconds <= 0 then return false end
  AmbientAudio.target = math.min(AmbientAudio.target, target)
  AmbientAudio.remaining = math.max(AmbientAudio.remaining, seconds)
  AmbientAudio.duration = math.max(AmbientAudio.duration, seconds)
  return true
end

function AmbientAudio.update(dt)
  dt = math.max(0, finite(dt, 0))
  AmbientAudio.remaining = math.max(0, AmbientAudio.remaining - dt)
  if AmbientAudio.remaining == 0 then
    AmbientAudio.duration, AmbientAudio.target = 0, 1
  end
end

function AmbientAudio.install(mod)
  if AmbientAudio.installed then return true end
  if not (mod and mod.hooks and type(mod.hooks.wrap) == "function") then
    return false
  end
  mod.hooks:wrap("music.volume", function(next, volume, ctx)
    return next((tonumber(volume) or 0) * AmbientAudio.factor(), ctx)
  end)
  AmbientAudio.installed = true
  return true
end

local function buildWind()
  if AmbientAudio.windSource then return AmbientAudio.windSource end
  if not (love and love.sound and love.sound.newSoundData
      and love.audio and love.audio.newSource) then return nil end
  local count = math.floor(RATE * WIND_SECONDS)
  local ok, data = pcall(love.sound.newSoundData, count, RATE, 16, 1)
  if not ok or not data then return nil end
  local seed, filtered = 24191, 0
  for i = 0, count - 1 do
    seed = (seed * 1103515245 + 12345) % 2147483647
    local noise = seed / 1073741823.5 - 1
    filtered = filtered * .94 + noise * .06
    local t = i / RATE
    local edge = math.min(1, t * 4, (WIND_SECONDS - t) * 3)
    local swell = .48 + .28 * math.sin(t * math.pi * 1.7)
    local voice = math.sin(t * math.pi * 2 * (178 + 24 * math.sin(t * 1.9)))
    local sample = (filtered * .82 + voice * .11) * swell * math.max(0, edge)
    pcall(data.setSample, data, i, math.max(-1, math.min(1, sample)))
  end
  local made, source = pcall(love.audio.newSource, data, "static")
  if not made then return nil end
  AmbientAudio.windSource = source
  return source
end

local function sfxScale(game)
  if not game then
    local worldApi = V and V.mod and V.mod.world
    if worldApi and type(worldApi.game) == "function" then
      local ok, value = pcall(worldApi.game, worldApi)
      if ok then game = value end
    end
  end
  if not game then
    local ok, value = pcall(require, "src.core.Game")
    if ok then game = value end
  end
  if not game then
    local ok, value = pcall(require, "src.core.Game2")
    if ok then game = value end
  end
  local options = game and game.save and game.save.options
  options = options or (game and game.options)
  local value = options and tonumber(options.sfxVol)
  if value == nil then return 1 end
  return math.max(0, math.min(7, value)) / 7
end

-- Called only after the visual scheduler has selected an audible wind event.
-- The occurrence key debounces stereo/VR redraws and battles.
function AmbientAudio.weatherEvent(event, game)
  if not event or (event.kind ~= "wind" and event.kind ~= "stormLeaves")
      or event.strength < .42 or event.key == AmbientAudio.lastWeatherKey then
    return false
  end
  AmbientAudio.lastWeatherKey = event.key
  local scale = sfxScale(game)
  if scale <= 0 then return false end
  local source = buildWind()
  if not source then return false end
  if source.stop then pcall(source.stop, source) end
  if source.setVolume then
    pcall(source.setVolume, source, .15 * scale * math.min(1, event.strength))
  end
  if source.setPitch then
    pcall(source.setPitch, source, event.kind == "stormLeaves" and .86 or 1)
  end
  local ok = source.play and pcall(source.play, source)
  if ok then AmbientAudio.duck(.58, WIND_SECONDS) end
  return ok and true or false
end

return AmbientAudio
