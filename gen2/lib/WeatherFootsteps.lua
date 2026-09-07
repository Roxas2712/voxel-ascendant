-- Short procedural surface steps for VASC weather. No audio asset is bundled:
-- the tiny mono buffers are synthesized lazily on the first relevant step,
-- respect the engine SFX volume, and are reused thereafter.

local V = ...
local WeatherFootsteps = {}
local AmbientAudio = V.require("AmbientAudio")

local RATE, VARIANTS = 22050, 3
local DURATION = { snow=.18, splash=.15 }
local banks = { snow = {}, splash = {} }
local cursor = { snow = 0, splash = 0 }

local function clamp(n)
  return math.max(-1, math.min(1, n))
end

local function build(kind, variant)
  if not (love and love.sound and love.sound.newSoundData
          and love.audio and love.audio.newSource) then return nil end
  local count = math.floor(RATE * DURATION[kind])
  local ok, data = pcall(love.sound.newSoundData, count, RATE, 16, 1)
  if not ok or not data then return nil end
  local seed = 9137 + variant * 7919 + (kind == "snow" and 337 or 977)
  local previous, filtered = 0, 0
  for i = 0, count - 1 do
    seed = (seed * 1103515245 + 12345) % 2147483647
    local noise = seed / 1073741823.5 - 1
    local t = i / RATE
    local envelope = math.exp(-t * (kind == "snow" and 24 or 30))
    local sample
    if kind == "snow" then
      -- Three close granular compressions make a dry, soft crunch rather
      -- than a generic white-noise hiss.
      local grains = math.max(0, math.sin(t * math.pi * (34 + variant * 2)))
      sample = (noise - previous * .55) * envelope * (.24 + grains * .34)
    else
      -- Filtered noise is the wet sole; the low decaying chirp is the small
      -- displaced-water "plop". The source stays short, while the volume duck
      -- gives it a clear foreground instant without masking the whole track.
      filtered = filtered * .72 + noise * .28
      local plop = math.sin(t * math.pi * 2 * (145 + variant * 17))
                   * math.exp(-t * 38)
      sample = filtered * envelope * .34 + plop * .30
    end
    previous = noise
    pcall(data.setSample, data, i, clamp(sample))
  end
  local sourceOK, source = pcall(love.audio.newSource, data, "static")
  if not sourceOK then return nil end
  return source
end

local function sfxScale(game)
  local options = game and game.save and game.save.options
  local value = options and tonumber(options.sfxVol)
  if value == nil then return 1 end
  return math.max(0, math.min(7, value)) / 7
end

function WeatherFootsteps.onStep(game, mode, surfaceAmount)
  local world = game and (game.overworld or game.world)
  if not (world and world.player) then return false end
  local player = world.player
  if (game.save and game.save.onBike) or player.surfing then return false end
  surfaceAmount = tonumber(surfaceAmount)
  local kind = mode == "snow" and (surfaceAmount == nil or surfaceAmount > .08)
               and "snow"
               or ((mode == "rain" or mode == "storm") and "splash" or nil)
  if not kind then return false end
  cursor[kind] = cursor[kind] % VARIANTS + 1
  local source = banks[kind][cursor[kind]]
  if not source then
    source = build(kind, cursor[kind])
    banks[kind][cursor[kind]] = source or false
  end
  if not source then return false end
  local scale = sfxScale(game)
  if scale <= 0 then return false end
  local coat = kind == "snow"
               and (.65 + .35 * math.max(0, math.min(1, surfaceAmount or 1)))
               or 1
  local volume = (kind == "snow" and .34 or .24) * scale * coat
  if source.stop then pcall(source.stop, source) end
  if source.setVolume then pcall(source.setVolume, source, volume) end
  if source.setPitch then
    pcall(source.setPitch, source, .96 + cursor[kind] * .025)
  end
  if source.play then
    local ok = pcall(source.play, source)
    if ok and AmbientAudio and type(AmbientAudio.duck) == "function" then
      AmbientAudio.duck(kind == "snow" and .52 or .60,
                        kind == "snow" and .30 or .24)
    end
    return ok
  end
  return false
end

return WeatherFootsteps
