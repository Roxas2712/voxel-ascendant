-- Technical owner for the packaged Weather Music derivatives.  It
-- validates the generated receipt and registers only file-backed song
-- definitions.  Playback remains entirely inside src.core.Music.

local V = ...
local Catalog = V.require("weather_music/Gen1WeatherMusicCatalog")

local Assets = {}
Assets.__index = Assets

Assets.API_VERSION = 1
Assets.CAPABILITY_SCHEMA = "ascendant.weather-music.package-assets/v1"

local function copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then error("weather asset receipt contains a cycle", 0) end
  seen[value] = true
  local out = {}
  for key, item in pairs(value) do out[copy(key, seen)] = copy(item, seen) end
  seen[value] = nil
  return out
end

function Assets.new(document, mod)
  local catalog, reason = Catalog.new(document)
  if not catalog then return nil, reason end
  if type(mod) ~= "table" or type(mod.content) ~= "table"
      or type(mod.content.music) ~= "table"
      or type(mod.content.music.register) ~= "function"
      or type(mod.content.music.get) ~= "function"
      or type(mod.content.music.remove) ~= "function"
      or type(mod.assets) ~= "table"
      or type(mod.assets.path) ~= "function" then
    return nil, "engine music/asset registry is unavailable"
  end
  local bytes = tonumber(document.totalAssetBytes) or 0
  if bytes > 40 * 1024 * 1024 then
    return nil, "weather music assets exceed the 40 MiB hard gate"
  end
  return setmetatable({ document=copy(document), catalog=catalog, mod=mod,
    registered=false, registeredIds={} }, Assets)
end

local function seconds(samples, rate)
  return tonumber(samples) and tonumber(rate) and tonumber(rate) > 0
    and tonumber(samples) / tonumber(rate) or nil
end

function Assets:register()
  if self.registered then return true end
  local rate = tonumber(self.document.sampleRate) or 48000
  local pending = {}
  for _, mapId in ipairs(Catalog.MAPS) do
    local family = assert(self.document.maps[mapId])
    for _, variant in ipairs(Catalog.VARIANTS) do
      local cue = assert(family.variants[variant])
      local def = {
        file=self.mod.assets:path(cue.path),
        seconds=seconds(cue.decodedFrames, rate),
        compositionId=family.compositionId,
        nativeSongId=family.nativeSongIds.red,
        bpm=family.bpm,
        beatsPerBar=family.beatsPerBar,
        introEndSeconds=family.introEndSeconds,
        loopStartSeconds=family.loopStartSeconds,
        loopEndSeconds=family.loopEndSeconds,
        loopCrossfadeSeconds=0.09,
        downbeatOriginSeconds=seconds(
          family.safeDownbeats and family.safeDownbeats.originSamples, rate),
        downbeatStepSeconds=seconds(
          family.safeDownbeats and family.safeDownbeats.stepSamples, rate),
        phraseSeconds=seconds(family.phraseFrames, rate),
        phaseSynchronous=cue.synchronous ~= false,
        -- The Engine schema permits bar-count transitions only for cues that
        -- claim one exact synchronous grid.  Lavender deliberately does not:
        -- its native channels have unequal nested loops, so the adapter asks
        -- for the Engine's phrase-boundary fallback instead.
        transitionBars=cue.synchronous ~= false and cue.transitionBars or nil,
        transitionSeconds=1.0,
      }
      local probed, existing = pcall(
        self.mod.content.music.get, self.mod.content.music, cue.songId)
      if not probed then
        return false, "song collision probe failed for " .. cue.songId
          .. ": " .. tostring(existing)
      end
      if existing ~= nil then
        return false, "song id is already registered: " .. cue.songId
      end
      pending[#pending + 1] = { id=cue.songId, definition=def }
    end
  end

  local committed = {}
  for _, entry in ipairs(pending) do
    local ok, result = pcall(self.mod.content.music.register,
      self.mod.content.music, entry.id, entry.definition)
    if not ok then
      local rollbackError
      for index = #committed, 1, -1 do
        local removed, detail = pcall(self.mod.content.music.remove,
          self.mod.content.music, committed[index])
        if not removed and not rollbackError then rollbackError = detail end
      end
      self.registeredIds = {}
      local suffix = rollbackError
        and "; rollback failed: " .. tostring(rollbackError) or ""
      return false, "song registration failed for " .. entry.id
        .. ": " .. tostring(result) .. suffix
    end
    committed[#committed + 1] = entry.id
    self.registeredIds[#self.registeredIds + 1] = entry.id
  end
  self.registered = #self.registeredIds
    == #Catalog.MAPS * #Catalog.VARIANTS
  return self.registered,
    self.registered and nil or "weather asset registration was incomplete"
end

function Assets:unregister()
  local failed
  for index = #self.registeredIds, 1, -1 do
    local id = self.registeredIds[index]
    local ok, reason = pcall(
      self.mod.content.music.remove, self.mod.content.music, id)
    if not ok and not failed then
      failed = "song removal failed for " .. id .. ": " .. tostring(reason)
    end
  end
  if failed then return false, failed end
  self.registeredIds = {}
  self.registered = false
  return true
end

function Assets:status()
  return {
    schema=Assets.CAPABILITY_SCHEMA,
    apiVersion=Assets.API_VERSION,
    ok=self.registered,
    state=self.registered and "active" or "installed",
    assetCount=self.document.assetCount,
    registered=#self.registeredIds,
    totalAssetBytes=self.document.totalAssetBytes,
    packageStatus=self.document.packageStatus,
    hearingStatus=self.document.package
      and self.document.package.hearingStatus or "USER_TEST_REQUIRED",
  }
end

function Assets:public()
  local owner = self
  return {
    schema=Assets.CAPABILITY_SCHEMA,
    apiVersion=Assets.API_VERSION,
    document=function() return copy(owner.document) end,
    status=function() return owner:status() end,
  }
end

return Assets
