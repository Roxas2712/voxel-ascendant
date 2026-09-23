-- One reusable rumble, scheduled after the weather renderer's actual flash.
-- Build in small slices when a storm starts, never in the drawing callback.
local V = ...
local Thunder = {}
local RATE, SECONDS = 11025, 2.4
local source, building, mapId, pending, lastOccurrence, failed

local function volume(game)
  local value = game and game.save and game.save.options
  value = value and tonumber(value.sfxVol)
  return math.max(0, math.min(7, value or 7)) / 7
end

local function prepare()
  if not (love and love.sound and love.audio) then return end
  building = coroutine.create(function()
    local count = math.floor(RATE * SECONDS)
    -- Stereo stays non-positional with the engine's moving audio listener.
    local data = love.sound.newSoundData(count, RATE, 16, 2)
    local seed, low, slower = 7523, 0, 0
    for i=0,count-1 do
      seed = seed * 16807 % 2147483647
      local noise = seed / 1073741823.5 - 1
      low = low * .92 + noise * .08
      slower = slower * .985 + noise * .015
      local t = i / RATE
      local attack = math.min(1, t / .012)
      local tail = math.min(1, (SECONDS-t) / .35)
      local roll = .65 + .35 * math.sin(t * 13)^2
      local rumble = (low * 2.8 + slower * 4) * math.exp(-t * 1.2) * roll
      local crack = noise * .4 * math.exp(-t * 24)
      local sample=math.max(-1, math.min(1, (rumble+crack)*attack*tail))
      data:setSample(i,1,sample);data:setSample(i,2,sample)
      if i % 768 == 767 then coroutine.yield() end
    end
    source = love.audio.newSource(data, 'static')
  end)
end

function Thunder.onLightning(map, flash, occurrence)
  if not map or map.id ~= mapId or occurrence == lastOccurrence then return end
  lastOccurrence = occurrence
  -- A short delay keeps the flash and its sound recognisably connected.
  pending = { delay=.25 + (tonumber(occurrence) or 0)%3 * .16 }
end

function Thunder.update(dt, game, mode)
  local map = game and game.overworld and game.overworld.map
  local id = mode == 'storm' and map and map.id or nil
  if id ~= mapId then
    mapId, pending, lastOccurrence = id, nil, nil
    if source then source:stop() end
  end
  if not id then return end
  local gain = volume(game)
  if source then source:setVolume(.85 * gain) end
  if gain <= 0 then pending=nil; return end
  if not source and not building and not failed then prepare() end
  if building then
    local ok = coroutine.resume(building)
    if not ok or coroutine.status(building)=='dead' then
      -- Do not retry a failed audio backend on every frame.
      building = nil
      if not ok then failed=true; pending=nil; return end
    end
  end
  if pending then
    pending.delay = pending.delay - math.max(0, tonumber(dt) or 0)
    if pending.delay <= 0 and source then
      source:stop(); source:setVolume(.85 * gain); source:play()
      pending=nil
    end
  end
end

return Thunder
