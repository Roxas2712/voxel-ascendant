-- Validated read-only facade over the generated Gen-1 Weather Music manifest.
-- The generated table owns paths/checksums; this module owns the runtime
-- boundary and never exposes the mutable source document itself.

local Catalog = {}
Catalog.__index = Catalog

Catalog.API_VERSION = 1
Catalog.SCHEMA = "voxel-ascendant/weather-music-catalog/v1"
Catalog.MAPS = {
  "PALLET_TOWN", "ROUTE_1", "VIRIDIAN_CITY", "ROUTE_3",
  "CERULEAN_CITY", "ROUTE_24", "VERMILION_CITY", "ROUTE_11",
  "CELADON_CITY", "CINNABAR_ISLAND", "BICYCLE", "LAVENDER_TOWN",
}
Catalog.VARIANTS = { "Heat", "Night", "Rain", "Storm", "Winter" }

local function finite(value)
  return type(value) == "number" and value == value
    and value ~= math.huge and value ~= -math.huge
end

local function integer(value)
  return finite(value) and value % 1 == 0
end

local function near(a, b, tolerance)
  return finite(a) and finite(b) and math.abs(a - b) <= tolerance
end

local function packagedOgg(path)
  return type(path) == "string"
    and path:match("^assets/audio/weather_music/gen1/[a-z0-9%-]+/[a-z]+%.ogg$")
    and not path:find("..", 1, true)
    and not path:find("\\", 1, true)
    and not path:find("%z")
end

local function copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then error("weather catalog contains a cycle", 0) end
  seen[value] = true
  local out = {}
  for key, item in pairs(value) do out[copy(key, seen)] = copy(item, seen) end
  seen[value] = nil
  return out
end

local function exactKeys(value, expected, label)
  if type(value) ~= "table" then return false, label .. " must be a table" end
  local wanted, count = {}, 0
  for _, key in ipairs(expected) do wanted[key] = true end
  for key in pairs(value) do
    if not wanted[key] then return false, label .. " has unexpected " .. tostring(key) end
    count = count + 1
  end
  if count ~= #expected then return false, label .. " has wrong cardinality" end
  for _, key in ipairs(expected) do
    if type(value[key]) ~= "table" then return false, label .. " misses " .. key end
  end
  return true
end

local function validateFamily(mapId, family)
  if family.mapId ~= nil and family.mapId ~= mapId then
    return false, mapId .. " map identity drift"
  end
  for _, field in ipairs({ "family", "compositionId" }) do
    if type(family[field]) ~= "string" or family[field] == "" then
      return false, mapId .. " misses " .. field
    end
  end
  local native = family.nativeSongIds
  if type(native) ~= "table" then return false, mapId .. " misses nativeSongIds" end
  for _, edition in ipairs({ "red", "blue", "yellow" }) do
    if type(native[edition]) ~= "string" or native[edition] == "" then
      return false, mapId .. " misses native " .. edition .. " song"
    end
  end
  for _, field in ipairs({ "bpm", "beatsPerBar", "introEndSeconds",
      "loopStartSeconds", "loopEndSeconds", "loopSeconds",
      "safeDownbeatEveryBars", "phraseBars", "sampleRate" }) do
    if not finite(family[field]) then return false, mapId .. " misses " .. field end
  end
  if family.sampleRate ~= 48000 or family.bpm <= 0
      or family.beatsPerBar ~= 4
      or type(family.meter) ~= "table"
      or family.meter.numerator ~= 4 or family.meter.denominator ~= 4
      or family.loopEndSeconds <= family.loopStartSeconds
      or family.loopSeconds <= 0 then
    return false, mapId .. " has invalid musical grid"
  end
  for _, field in ipairs({ "introEndSamples", "loopStartSamples",
      "loopEndSamples", "loopFrames", "barFrames", "phraseFrames",
      "barsPerLoop" }) do
    if not integer(family[field]) or family[field] < 0 then
      return false, mapId .. " has invalid " .. field
    end
  end
  if family.introEndSamples ~= family.loopStartSamples
      or family.loopEndSamples ~= family.loopStartSamples + family.loopFrames
      or family.loopFrames <= 0 or family.barFrames <= 0
      or family.barsPerLoop <= 0
      or family.loopFrames ~= family.barFrames * family.barsPerLoop
      or family.phraseFrames <= 0
      or family.phraseFrames > family.loopFrames
      or family.phraseFrames % family.barFrames ~= 0
      or family.phraseBars ~= family.phraseFrames / family.barFrames then
    return false, mapId .. " has inconsistent loop/phrase frames"
  end
  local sampleTolerance = 0.5 / family.sampleRate
  if not near(family.introEndSeconds,
      family.introEndSamples / family.sampleRate, sampleTolerance)
      or not near(family.loopStartSeconds,
        family.loopStartSamples / family.sampleRate, sampleTolerance)
      or not near(family.loopEndSeconds,
        family.loopEndSamples / family.sampleRate, sampleTolerance)
      or not near(family.loopSeconds,
        family.loopFrames / family.sampleRate, sampleTolerance) then
    return false, mapId .. " seconds drift from sample receipt"
  end
  local downbeats = family.safeDownbeats
  if type(downbeats) ~= "table"
      or downbeats.originSamples ~= family.loopStartSamples
      or downbeats.stepSamples ~= family.barFrames
      or not integer(downbeats.count) or downbeats.count <= 0
      or downbeats.count ~= family.barsPerLoop
      or family.safeDownbeatEveryBars ~= 1 then
    return false, mapId .. " has invalid safe-downbeat grid"
  end
  if type(family.safePhraseOffsetsSamples) ~= "table"
      or family.safePhraseOffsetsSamples[1] ~= 0 then
    return false, mapId .. " misses safe phrase origin"
  end
  local ok, reason = exactKeys(family.variants, Catalog.VARIANTS,
    mapId .. ".variants")
  if not ok then return false, reason end
  for _, name in ipairs(Catalog.VARIANTS) do
    local cue = family.variants[name]
    for _, field in ipairs({ "songId", "path", "sha256" }) do
      if type(cue[field]) ~= "string" or cue[field] == "" then
        return false, mapId .. "." .. name .. " misses " .. field
      end
    end
    if not cue.songId:match("^vasc%.weather%-music%.gen1%.[a-z0-9%-]+%.[a-z]+$")
        or not packagedOgg(cue.path) then
      return false, mapId .. "." .. name .. " has invalid package identity"
    end
    if not cue.sha256:match("^[0-9a-f]+$") or #cue.sha256 ~= 64 then
      return false, mapId .. "." .. name .. " has invalid sha256"
    end
    if not integer(cue.bytes) or cue.bytes <= 0
        or not integer(cue.decodedFrames)
        or cue.decodedFrames ~= family.loopEndSamples
        or not integer(cue.sampleDeviation)
        or type(cue.synchronous) ~= "boolean"
        or type(cue.runtimeReady) ~= "boolean"
        or type(cue.safePhraseFallback) ~= "boolean"
        or cue.hearingStatus ~= "USER_TEST_REQUIRED" then
      return false, mapId .. "." .. name .. " has invalid asset receipt"
    end
    if cue.synchronous and cue.sampleDeviation ~= 0 then
      return false, mapId .. "." .. name .. " claims a drifting sync grid"
    end
    local bars = tonumber(cue.transitionBars)
    local validBars = name == "Storm" and bars and bars >= 1 and bars <= 2
      or name ~= "Storm" and bars and bars >= 2 and bars <= 4
    if not validBars or bars % 1 ~= 0 then
      return false, mapId .. "." .. name .. " has invalid transition bars"
    end
  end
  return true
end

function Catalog.new(document)
  if type(document) ~= "table" then return nil, "catalog document is unavailable" end
  if document.schema ~= Catalog.SCHEMA then
    return nil, "catalog schema mismatch"
  end
  local expectedAssets = #Catalog.MAPS * #Catalog.VARIANTS
  if tonumber(document.assetCount) ~= expectedAssets then
    return nil, "catalog must contain exactly " .. expectedAssets .. " assets"
  end
  if integer(document.totalAssetBytes)
      and document.totalAssetBytes > 40 * 1024 * 1024 then
    return nil, "weather music assets exceed the 40 MiB hard gate"
  end
  if document.sampleRate ~= 48000
      or not integer(document.totalAssetBytes)
      or document.totalAssetBytes <= 0
      or document.packageStatus ~= "AUDITION_ONLY"
      or type(document.package) ~= "table"
      or document.package.hearingStatus ~= "USER_TEST_REQUIRED" then
    return nil, "catalog package receipt is invalid"
  end
  local ok, reason = exactKeys(document.maps, Catalog.MAPS, "maps")
  if not ok then return nil, reason end
  local maps, songs, paths, nativeThemes, totalBytes = {}, {}, {}, {}, 0
  for _, mapId in ipairs(Catalog.MAPS) do
    local family = copy(document.maps[mapId])
    family.sampleRate = document.sampleRate
    local valid, familyReason = validateFamily(mapId, family)
    if not valid then return nil, familyReason end
    maps[mapId] = family
    for _, edition in ipairs({ "red", "blue", "yellow" }) do
      local nativeSongId = family.nativeSongIds[edition]
      local existing = nativeThemes[nativeSongId]
      if existing ~= nil and existing ~= mapId then
        return nil, "native song maps to multiple weather families: "
          .. nativeSongId
      end
      nativeThemes[nativeSongId] = mapId
    end
    for _, variant in ipairs(Catalog.VARIANTS) do
      local cue = family.variants[variant]
      if songs[cue.songId] then return nil, "duplicate songId " .. cue.songId end
      if paths[cue.path] then return nil, "duplicate asset path " .. cue.path end
      paths[cue.path] = true
      totalBytes = totalBytes + cue.bytes
      songs[cue.songId] = { mapId=mapId, variant=variant, cue=copy(cue) }
    end
  end
  if totalBytes ~= document.totalAssetBytes then
    return nil, "catalog asset byte sum mismatch"
  end
  local self = setmetatable({
    version=document.version,
    assetCount=document.assetCount,
    totalAssetBytes=document.totalAssetBytes,
    packageStatus=document.packageStatus,
    maps=maps,
    songs=songs,
    nativeThemes=nativeThemes,
  }, Catalog)
  return self
end

function Catalog:map(mapId)
  local value = self.maps[mapId]
  return value and copy(value) or nil
end

function Catalog:variant(mapId, variant)
  local family = self.maps[mapId]
  local value = family and family.variants[variant]
  if not value then return nil end
  local result = copy(value)
  result.family = family.family
  result.compositionId = family.compositionId
  result.bpm = family.bpm
  result.beatsPerBar = family.beatsPerBar
  result.introEndSeconds = family.introEndSeconds
  result.loopStartSeconds = family.loopStartSeconds
  result.loopEndSeconds = family.loopEndSeconds
  result.loopSeconds = family.loopSeconds
  result.safeDownbeatEveryBars = family.safeDownbeatEveryBars
  result.phraseBars = family.phraseBars
  return result
end

function Catalog:song(songId)
  local row = self.songs[songId]
  return row and copy(row) or nil
end

-- The package stores one authored weather arrangement per native composition,
-- not one duplicate for every map that happens to use that composition.  This
-- lookup lets ROUTE_6 reuse the ROUTE_3 family when the engine reports
-- Music_Routes3, and applies the same rule to shared city themes.
function Catalog:themeMap(nativeSongId)
  if type(nativeSongId) ~= "string" or nativeSongId == "" then return nil end
  return self.nativeThemes[nativeSongId]
end

function Catalog:status()
  return {
    schema=Catalog.SCHEMA,
    apiVersion=Catalog.API_VERSION,
    ok=true,
    state="active",
    version=self.version,
    maps=#Catalog.MAPS,
    variants=#Catalog.VARIANTS,
    assets=self.assetCount,
    totalAssetBytes=self.totalAssetBytes,
    packageStatus=self.packageStatus,
  }
end

function Catalog:public()
  local owner = self
  return {
    schema=Catalog.SCHEMA,
    apiVersion=Catalog.API_VERSION,
    map=function(mapId) return owner:map(mapId) end,
    variant=function(mapId, variant) return owner:variant(mapId, variant) end,
    song=function(songId) return owner:song(songId) end,
    themeMap=function(nativeSongId) return owner:themeMap(nativeSongId) end,
    status=function() return owner:status() end,
  }
end

return Catalog
