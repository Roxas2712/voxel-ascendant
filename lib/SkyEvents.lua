-- Rare, world-anchored life in the outdoor sky.
--
-- Sky owns the atmosphere and supplies a projector. This module owns only the
-- deterministic schedule, ecology gates and transparent billboard atlases.
-- Assets are original mod art loaded through the mod API; there are no traced
-- game sprites and no procedural rectangle substitutes. Rendering therefore
-- costs one textured draw per visible rainbow, flock or legendary bird.

local V = ...

local DayNight = V.require("DayNight")
local ModSetting = V.require("ModSetting")

local SkyEvents = {}

local okPresentation, CanvasPresentation = pcall(V.require,
  "CanvasPresentation")
local MOBILE_RUNTIME = okPresentation and CanvasPresentation
  and (CanvasPresentation.OS == "iOS"
       or CanvasPresentation.OS == "Android") or false

SkyEvents.DEFAULT_CLOCK = 1800
SkyEvents.clock = SkyEvents.DEFAULT_CLOCK
local forcedRainbow
local previewRainbowMap
local cryPlayer
local pendingCry
local lastWeatherCryOccurrence = {}
local RAINBOW_ELEVATION = 0.18
local BATTLE_RAINBOW_ELEVATION = -0.18

SkyEvents.WEATHER_CRY_EVERY = 3
SkyEvents.WEATHER_APPEARANCE_CYCLE = 5

SkyEvents.setting = ModSetting.new("skyEvents", "SKY EVENTS",
  { "full", "rainbow", "flyers", "off" },
  { "FULL", "RAINBOW", "FLYERS", "OFF" })

-- `pidgeot` remains the backwards-compatible name of the ordinary-flight
-- schedule. ordinaryPlan() chooses its actual species and formation.
SkyEvents.TIMING = {
  rainbow  = { period = 607,  duration = 18, offset = 157  },
  pidgeot  = { period = 419,  duration = 8,  offset = 181  },
  hooh      = { period = 3607, duration = 12, offset = 3000 },
  articuno  = { period = 3259, duration = 10, offset = 2140 },
  zapdos    = { period = 3911, duration = 10, offset = 2670 },
  moltres   = { period = 4253, duration = 11, offset = 3340 },
}

SkyEvents.WEATHER_TIMING = {
  lugia = { period = 83, duration = 10, offset = 29 },
  hoohHeat = { period = 67, duration = 11, offset = 47 },
}

SkyEvents.LEGENDARY_ROSTER = { "hooh", "articuno", "zapdos", "moltres" }
SkyEvents.ORDINARY_ROSTER = {
  "pidgey", "pidgeotto", "pidgeot", "spearow", "fearow", "farfetchd",
  "murkrow",
}

-- Canon heights are deliberately kept as data rather than baked into hand-
-- tuned sprite scales. A deterministic observation distance then produces the
-- apparent height below. Formation bounds keep tiny birds social, medium birds
-- restrained and large silhouettes solitary, so one event never fills the sky.
SkyEvents.ORDINARY_ART = {
  pidgey = {
    asset = "flock", heightMeters = 0.3, distanceMin = 58, distanceMax = 64,
    minCount = 2, maxCount = 4, minLight = 0.28, maxLight = 1, salt = 31,
  },
  pidgeotto = {
    asset = "flock", heightMeters = 1.1, distanceMin = 74, distanceMax = 84,
    minCount = 1, maxCount = 2, minLight = 0.28, maxLight = 1, salt = 67,
  },
  pidgeot = {
    asset = "flock", heightMeters = 1.5, distanceMin = 82, distanceMax = 92,
    minCount = 1, maxCount = 1, minLight = 0.30, maxLight = 1, salt = 101,
  },
  spearow = {
    asset = "spearowFlock", heightMeters = 0.3,
    distanceMin = 58, distanceMax = 64,
    minCount = 2, maxCount = 4, minLight = 0.30, maxLight = 1, salt = 137,
  },
  fearow = {
    asset = "spearowFlock", heightMeters = 1.2,
    distanceMin = 76, distanceMax = 86,
    minCount = 1, maxCount = 2, minLight = 0.32, maxLight = 1, salt = 173,
  },
  farfetchd = {
    asset = "farfetchd", heightMeters = 0.8,
    distanceMin = 70, distanceMax = 80,
    minCount = 1, maxCount = 2, minLight = 0.30, maxLight = 1, salt = 211,
  },
  murkrow = {
    asset = "murkrowFlock", heightMeters = 0.5,
    distanceMin = 62, distanceMax = 70,
    minCount = 2, maxCount = 4, minLight = 0, maxLight = 0.58, salt = 337,
  },
}

SkyEvents.LEGEND_ART = {
  hooh = {
    heightMeters = 3.8, distanceMin = 115, distanceMax = 130,
    elevation = 0.19, minLight = 0.35, maxLight = 1, salt = 421,
  },
  articuno = {
    heightMeters = 1.7, distanceMin = 100, distanceMax = 110,
    elevation = 0.21, minLight = 0.24, maxLight = 1, salt = 463,
  },
  zapdos = {
    heightMeters = 1.6, distanceMin = 100, distanceMax = 112,
    elevation = 0.20, minLight = 0.28, maxLight = 1, salt = 503,
  },
  moltres = {
    heightMeters = 2.0, distanceMin = 100, distanceMax = 114,
    elevation = 0.18, minLight = 0.18, maxLight = 1, salt = 547,
  },
  lugia = {
    heightMeters = 5.2, distanceMin = 108, distanceMax = 122,
    elevation = 0.17, minLight = 0, maxLight = 1, salt = 601,
  },
}

local FLYER_KIND = { pidgeot = true }
for _, kind in ipairs(SkyEvents.LEGENDARY_ROSTER) do FLYER_KIND[kind] = true end

local function clamp01(n)
  if n < 0 then return 0 end
  return n > 1 and 1 or n
end

function SkyEvents.mode()
  return SkyEvents.setting:get()
end

function SkyEvents.enabled(kind)
  local mode = SkyEvents.mode()
  if mode == "off" then return false end
  if not kind then return true end
  if kind ~= "rainbow" and not FLYER_KIND[kind] then return false end
  if mode == "full" then return true end
  if kind == "rainbow" then return mode == "rainbow" end
  return FLYER_KIND[kind] and mode == "flyers" or false
end

function SkyEvents.progress(kind, clock)
  local timing = SkyEvents.TIMING[kind]
  if not timing then return nil end
  local phase = ((clock or SkyEvents.clock) + timing.offset) % timing.period
  if phase >= timing.duration then return nil end
  return phase / timing.duration
end

-- Weather uses this seam instead of manipulating the rare ambient schedule.
-- A post-rain rainbow is map-bound and guaranteed even when the optional sky
-- fauna row is OFF; RAINBOW in the WEATHER row uses the preview path so QA
-- can hold it on screen without waiting for a schedule boundary.
function SkyEvents.forceRainbow(mapId, duration)
  mapId = tostring(mapId or "")
  if mapId == "" then return false end
  if forcedRainbow and forcedRainbow.mapId == mapId
      and forcedRainbow.elapsed < forcedRainbow.duration then
    return true
  end
  forcedRainbow = {
    mapId = mapId, elapsed = 0,
    duration = math.max(6, tonumber(duration) or 24),
  }
  return true
end

function SkyEvents.setRainbowPreview(mapId)
  mapId = mapId ~= nil and tostring(mapId) or nil
  previewRainbowMap = mapId ~= "" and mapId or nil
end

function SkyEvents.rainbowProgress(mapId)
  mapId = tostring(mapId or "")
  if previewRainbowMap and previewRainbowMap == mapId then
    return 0.5
  end
  if forcedRainbow and forcedRainbow.mapId == mapId
      and forcedRainbow.elapsed < forcedRainbow.duration then
    return forcedRainbow.elapsed / forcedRainbow.duration
  end
  return nil
end

local EVENT_SALT = {
  rainbow = 193, pidgeot = 431, hooh = 887,
  articuno = 241, zapdos = 593, moltres = 761, lugia = 839,
}

function SkyEvents.anchor(kind, clock)
  local timing = SkyEvents.TIMING[kind]
  if not timing then return nil end
  local t = (clock or SkyEvents.clock) + timing.offset
  local occurrence = math.floor(t / timing.period)
  local salt = EVENT_SALT[kind] or 17
  local unit = ((occurrence * 977 + salt * 131) % 1009) / 1008
  local azimuth = math.pi + (unit * 2 - 1) * 0.72
  azimuth = (azimuth + math.pi) % (math.pi * 2) - math.pi
  return azimuth, occurrence
end

-- Unlike the drifting cloud layers and occurrence-based flyer routes, a
-- rainbow is a static landmark for the current map. Its bearing contains no
-- clock or event occurrence, so it cannot wander during a long preview or
-- jump when the ambient schedule crosses a period boundary.
function SkyEvents.rainbowAnchor(mapId)
  local text = tostring(mapId or "")
  local seed = 193
  for i = 1, #text do seed = (seed * 131 + text:byte(i)) % 1009 end
  local unit = seed / 1008
  local azimuth = math.pi + (unit * 2 - 1) * 0.58
  return (azimuth + math.pi) % (math.pi * 2) - math.pi
end

-- Weighted deterministic rotation: familiar small flocks recur, while a lone
-- Pidgeot or Farfetch'd remains a memorable sighting. Only species with an
-- approved exact PNG enter this production schedule. There
-- is still only one ordinary event window every 419 seconds.
local ORDINARY_ROTATION = {
  "pidgey", "spearow", "pidgeotto", "pidgey", "pidgey",
  "spearow", "murkrow", "fearow", "pidgey", "pidgeotto",
  "spearow", "farfetchd", "spearow", "pidgey", "fearow",
  "murkrow", "pidgeotto", "spearow", "pidgey", "spearow",
  "pidgeotto", "spearow", "pidgeot", "pidgey", "farfetchd",
}
local FORMATION_NAME = { [1] = "single", [2] = "pair", [3] = "vee",
                         [4] = "diamond" }
local SHADOW_ROTATION = {
  "pidgey", "spearow", "pidgeotto", "pidgey", "fearow", "farfetchd",
  "spearow", "pidgeot",
}

local APPARENT_FOCAL_CELLS = 800
local MIN_APPARENT_CELLS = 4.25

local function artFor(species)
  return SkyEvents.ORDINARY_ART[species] or SkyEvents.LEGEND_ART[species]
end

function SkyEvents.distanceMeters(species, occurrence)
  local art = artFor(species)
  if not art then return nil end
  occurrence = math.floor(tonumber(occurrence) or 0)
  local unit = ((occurrence * 421 + art.salt * 97) % 997) / 996
  return art.distanceMin + (art.distanceMax - art.distanceMin) * unit
end

-- Apparent individual height is the authoritative proportional scale. The
-- billboard can be larger because it contains formation spacing, but a Pidgey
-- inside it can never outgrow a Pidgeot, Noctowl or Ho-Oh.
function SkyEvents.apparentHeightCells(species, occurrence)
  local art = artFor(species)
  local distance = SkyEvents.distanceMeters(species, occurrence)
  if not (art and distance and distance > 0) then return nil end
  local ceiling = SkyEvents.LEGEND_ART[species] and 30 or 18
  return math.max(MIN_APPARENT_CELLS,
                  math.min(ceiling,
                           art.heightMeters / distance * APPARENT_FOCAL_CELLS))
end

function SkyEvents.displaySizeCells(species, count, occurrence)
  local art = artFor(species)
  local individual = SkyEvents.apparentHeightCells(species, occurrence)
  if not (art and individual) then return nil end
  count = math.max(1, math.min(4, math.floor(tonumber(count) or 1)))
  local formationSpacing = 1.25 + 0.25 * count
  local maximum = SkyEvents.LEGEND_ART[species] and 36 or 26
  local height = math.min(maximum, individual * formationSpacing)
  local assetName = SkyEvents.LEGEND_ART[species] and species or art.asset
  local spec = SkyEvents.ASSET_SPECS and SkyEvents.ASSET_SPECS[assetName]
  local aspect = spec and spec.frameWidth / spec.frameHeight or 2
  return height * aspect, height
end

local function ordinaryPlanFor(species, occurrence)
  local art = SkyEvents.ORDINARY_ART[species]
  if not (art and art.available ~= false and art.asset) then return nil end
  local count = art.minCount
                + ((occurrence * 7 + art.salt) %
                   (art.maxCount - art.minCount + 1))
  return {
    species = species, formation = FORMATION_NAME[count], count = count,
    occurrence = occurrence, asset = art.asset,
    heightMeters = art.heightMeters,
    distanceMeters = SkyEvents.distanceMeters(species, occurrence),
    apparentHeightCells = SkyEvents.apparentHeightCells(species, occurrence),
  }
end

function SkyEvents.ordinaryPlan(clock)
  local _, occurrence = SkyEvents.anchor("pidgeot", clock)
  if not occurrence then return nil end
  local species = ORDINARY_ROTATION[(occurrence % #ORDINARY_ROTATION) + 1]
  return ordinaryPlanFor(species, occurrence)
end

-- The paired ground/sky flyover uses the same approved VASC atlases and
-- formation rules as the ambient scheduler. Its seed chooses a daylight
-- species deterministically; both the sky painter and ground shader consume
-- this one plan, so count, scale and travel direction cannot disagree.
function SkyEvents.shadowPlan(seed)
  local occurrence = math.max(0, math.floor(tonumber(seed) or 0))
  local species = SHADOW_ROTATION[(occurrence % #SHADOW_ROTATION) + 1]
  return ordinaryPlanFor(species, occurrence)
end

function SkyEvents.activeLegendary(clock)
  -- Stable precedence guarantees a single sighting even when prime schedules
  -- eventually overlap in a very long save.
  for _, kind in ipairs(SkyEvents.LEGENDARY_ROSTER) do
    local progress = SkyEvents.progress(kind, clock)
    if progress then return kind, progress end
  end
  return nil
end

function SkyEvents.eventClock(kind, progress, occurrence)
  local timing = SkyEvents.TIMING[kind]
  if not timing then return nil end
  progress = clamp01(type(progress) == "number" and progress or 0.5)
  occurrence = math.max(1, math.floor(occurrence or 1))
  return occurrence * timing.period - timing.offset
         + progress * timing.duration
end

-- Screenshot seam: returns a real production occurrence close to the classic
-- north-facing QA camera, never a screen-space-only debug position.
function SkyEvents.qaClock(kind, progress)
  if not SkyEvents.TIMING[kind] then return nil end
  local bestClock, bestDelta, bestFormation, bestDaylight
  bestFormation, bestDaylight = -1, -1
  for occurrence = 1, 512 do
    local clock = SkyEvents.eventClock(kind, progress, occurrence)
    local active = SkyEvents.activeLegendary(clock)
    local wins = kind == "rainbow"
                 or (kind == "pidgeot" and not active)
                 or active == kind
    if wins then
      local azimuth = SkyEvents.anchor(kind, clock)
      local delta = math.abs((azimuth - math.pi + math.pi)
                             % (math.pi * 2) - math.pi)
      local plan = kind == "pidgeot" and SkyEvents.ordinaryPlan(clock) or nil
      local formation = plan and plan.count or 1
      local daylight = plan and plan.species == "murkrow" and 0 or 1
      if daylight > bestDaylight
          or (daylight == bestDaylight and formation > bestFormation)
          or (daylight == bestDaylight and formation == bestFormation
              and (not bestDelta or delta < bestDelta)) then
        bestClock, bestDelta = clock, delta
        bestFormation, bestDaylight = formation, daylight
      end
    end
  end
  return bestClock
end

-- QA-only selection seam: choose a genuine ordinary production occurrence
-- for one approved species without changing the production rotation, cadence
-- or save clock.  Keeping this in the scheduler (rather than faking a draw in
-- the manual driver) means screenshots still exercise the real ecology,
-- world anchor, formation and size calculations.
function SkyEvents.qaClockForSpecies(species, progress)
  local art = SkyEvents.ORDINARY_ART[species]
  if not (art and art.asset and art.available ~= false) then return nil end
  local bestClock, bestDelta, bestCount
  bestCount = -1
  for occurrence = 1, 512 do
    local clock = SkyEvents.eventClock("pidgeot", progress, occurrence)
    local plan = SkyEvents.ordinaryPlan(clock)
    if plan and plan.species == species
        and not SkyEvents.activeLegendary(clock) then
      local azimuth = SkyEvents.anchor("pidgeot", clock)
      local delta = math.abs((azimuth - math.pi + math.pi)
                             % (math.pi * 2) - math.pi)
      if plan.count > bestCount
          or (plan.count == bestCount
              and (not bestDelta or delta < bestDelta)) then
        bestClock, bestDelta, bestCount = clock, delta, plan.count
      end
    end
  end
  return bestClock
end

local DAY_WEIGHTS = {
  day = 1, golden = 1, dawn = 0.78, dusk = 0.68, violet = 0.20,
}

function SkyEvents.daylight(ctx)
  if ctx and type(ctx.daylight) == "number" then
    return clamp01(ctx.daylight)
  end
  local okTime, time = pcall(DayNight.time)
  local okMix, mix = pcall(DayNight.mix, okTime and time or nil)
  if not (okMix and type(mix) == "table") then return 1 end
  local light = 0
  for name, weight in pairs(mix) do
    light = light + (DAY_WEIGHTS[name] or 0) * weight
  end
  return clamp01(light)
end

local function fade(progress, edge)
  edge = edge or 0.14
  return math.min(1, progress / edge, (1 - progress) / edge)
end

local function projected(ctx, azimuth, elevation, marginX, marginY)
  local ok, x, y = pcall(ctx.project, azimuth, elevation)
  if not (ok and type(x) == "number" and type(y) == "number") then return nil end
  marginX, marginY = marginX or 0, marginY or marginX or 0
  if x < -marginX or x > ctx.w + marginX
      or y < -marginY or y > ctx.h + marginY then return nil end
  return x, y
end

local function obscuresRainbow(weather)
  return weather == "snow" or weather == "fog" or weather == "storm"
end

local function obscuresFlyers(weather)
  return weather == "rain" or weather == "snow"
      or weather == "fog" or weather == "storm"
end

local function weatherAllowsLegend(kind, weather)
  if kind == "lugia" then return weather == "rain" or weather == "storm" end
  return not obscuresFlyers(weather)
end

function SkyEvents.weatherLegend(weather, clock)
  local key, kind
  if weather == "rain" or weather == "storm" then
    key, kind = "lugia", "lugia"
  elseif weather == "heat" then
    key, kind = "hoohHeat", "hooh"
  else
    return nil
  end
  local timing = SkyEvents.WEATHER_TIMING[key]
  local eventClock = (clock or SkyEvents.clock) + timing.offset
  local phase = eventClock % timing.period
  if phase >= timing.duration then return nil end
  local occurrence = math.floor(eventClock / timing.period)
  -- Visible slots alternate at distances of two and three schedule windows:
  -- 0, 2, 5, 7, 10, 12... This keeps weather legends memorable without
  -- introducing mutable RNG state or changing the underlying weather itself.
  local cycle = occurrence % SkyEvents.WEATHER_APPEARANCE_CYCLE
  if cycle ~= 0 and cycle ~= 2 then return nil end
  return kind, phase / timing.duration, occurrence
end

local function weatherAppearanceIndex(occurrence)
  local cycle = occurrence % SkyEvents.WEATHER_APPEARANCE_CYCLE
  if cycle ~= 0 and cycle ~= 2 then return nil end
  return math.floor(occurrence / SkyEvents.WEATHER_APPEARANCE_CYCLE) * 2
         + (cycle == 2 and 1 or 0)
end

-- Asset contract. Artwork can be replaced without touching scheduler or
-- renderer code as long as these transparent dimensions and frame grids stay
-- stable. Ho-Oh's single composition includes its subtle rainbow wake; flight
-- path, bob, scale and direction mirroring provide animation without an atlas.
SkyEvents.ASSET_SPECS = {
  rainbow = {
    path = "assets/sky/rainbow_smooth.png", width = 1024, height = 512,
    frameWidth = 1024, frameHeight = 512, columns = 1, rows = 1,
    -- The soft authored gradient needs linear sampling; all pixel-art sky
    -- atlases retain nearest filtering. The bow itself keeps its natural 2:1
    -- proportions and stays at a fixed world bearing while its legs pass
    -- behind terrain.
    filter = "linear",
  },
  flock = {
    path = "assets/sky/bird_flock.png", width = 512, height = 256,
    frameWidth = 512, frameHeight = 256, columns = 1, rows = 1,
  },
  spearowFlock = {
    path = "assets/sky/spearow_flock.png", width = 512, height = 256,
    frameWidth = 512, frameHeight = 256, columns = 1, rows = 1,
  },
  murkrowFlock = {
    path = "assets/sky/murkrow_flock.png", width = 512, height = 256,
    frameWidth = 512, frameHeight = 256, columns = 1, rows = 1,
  },
  farfetchd = {
    path = "assets/sky/farfetchd.png", width = 512, height = 256,
    frameWidth = 512, frameHeight = 256, columns = 1, rows = 1,
  },
  hooh = {
    path = "assets/sky/hooh.png", width = 512, height = 256,
    frameWidth = 512, frameHeight = 256, columns = 1, rows = 1,
    displayCells = { 48, 24 }, includesRainbowWake = true,
  },
  articuno = {
    path = "assets/sky/articuno.png", width = 512, height = 256,
    frameWidth = 512, frameHeight = 256, columns = 1, rows = 1,
    displayCells = { 46, 23 },
  },
  zapdos = {
    path = "assets/sky/zapdos.png", width = 512, height = 256,
    frameWidth = 512, frameHeight = 256, columns = 1, rows = 1,
    displayCells = { 46, 23 },
  },
  moltres = {
    path = "assets/sky/moltres.png", width = 512, height = 256,
    frameWidth = 512, frameHeight = 256, columns = 1, rows = 1,
    displayCells = { 46, 23 },
  },
  lugia = {
    pathPattern = "assets/sky/lugia_crystal/%03d.png", fileFrames = 14,
    durationsMs = {
      380, 160, 160, 210, 210, 210, 160,
      350, 150, 150, 150, 300, 150, 1000,
    },
    width = 56, height = 56,
    frameWidth = 56, frameHeight = 56, columns = 1, rows = 1,
    displayCells = { 34, 34 },
  },
}

local ASSET_ORDER = {
  "rainbow", "flock", "spearowFlock", "murkrowFlock", "farfetchd",
  "hooh", "articuno", "zapdos", "moltres", "lugia",
}
local FLYER_ASSET_ORDER = {
  "flock", "spearowFlock", "murkrowFlock", "farfetchd",
  "hooh", "articuno", "zapdos", "moltres", "lugia",
}
local assetCache = {}
local requestedShadowAsset

function SkyEvents.requestShadowFlyer(seed, active)
  local plan = active and SkyEvents.shadowPlan(seed) or nil
  requestedShadowAsset = plan and plan.asset or nil
  return plan
end


function SkyEvents.requestShadowLegend(kind, active)
  requestedShadowAsset = active and SkyEvents.ASSET_SPECS[kind] and kind or nil
end

-- The host supplies the engine cry player so this rendering module remains
-- headless-safe and owns no audio files. Kanto Ascendant's registered LUGIA
-- and HO_OH definitions remain authoritative when present.
function SkyEvents.setCryPlayer(player)
  cryPlayer = type(player) == "function" and player or nil
  if not cryPlayer then pendingCry = nil end
end

local WEATHER_CRY_SPECIES = { lugia = "LUGIA", hooh = "HO_OH" }

local function queueWeatherCry(ctx, kind, progress)
  if not cryPlayer or progress < 0.34 then return end
  local weatherKind, _, occurrence =
    SkyEvents.weatherLegend(ctx.weather, ctx.clock)
  if weatherKind ~= kind or not occurrence then return end
  local art = SkyEvents.LEGEND_ART[kind]
  local appearance = weatherAppearanceIndex(occurrence)
  local chosen = appearance
    and ((appearance + (art and art.salt or 0))
         % SkyEvents.WEATHER_CRY_EVERY) == 0
  if not chosen or lastWeatherCryOccurrence[kind] == occurrence then return end
  local species = WEATHER_CRY_SPECIES[kind]
  if not species then return end
  lastWeatherCryOccurrence[kind] = occurrence
  pendingCry = species
end

local function activeAssetOrder()
  local mode = SkyEvents.mode()
  if mode == "rainbow" then return { "rainbow" } end
  if mode == "flyers" then return FLYER_ASSET_ORDER end
  if mode == "full" then return ASSET_ORDER end
  return nil
end

local function graphicsApi()
  return love and love.graphics or nil
end

local function releaseAsset(asset)
  if asset and asset.images then
    for _, image in ipairs(asset.images) do
      if image and image.release then pcall(image.release, image) end
    end
  elseif asset and asset.image and asset.image.release then
    pcall(asset.image.release, asset.image)
  end
end

function SkyEvents.invalidateAssets()
  for _, asset in pairs(assetCache) do releaseAsset(asset) end
  assetCache = {}
end

local function assetEntry(name)
  local entry = assetCache[name]
  if not entry then
    entry = { state = "cold" }
    assetCache[name] = entry
  end
  return entry
end

local function fileSource(relative)
  -- V.path is supplied by the host for both directory mods and mounted .love
  -- archives. Passing that virtual path straight to newImage avoids a second
  -- binary copy and keeps the runtime clear of the restricted filesystem API.
  if type(V.path) == "string" then return V.path .. "/" .. relative end
  return nil, "missing"
end

local function assetPaths(spec)
  if spec.pathPattern and spec.fileFrames then
    local paths = {}
    for frame = 1, spec.fileFrames do
      paths[frame] = spec.pathPattern:format(frame)
    end
    return paths
  end
  return spec.path and { spec.path } or {}
end

local function loadAsset(name)
  local spec = SkyEvents.ASSET_SPECS[name]
  local entry = assetEntry(name)
  if not spec or entry.state ~= "cold" then return entry.state == "ready" end
  local graphics = graphicsApi()
  if not (graphics and type(graphics.newImage) == "function"
          and type(graphics.newQuad) == "function") then
    return false -- graphics may become available after module initialisation
  end
  entry.state = "loading"
  local filter = spec.filter == "linear" and "linear" or "nearest"
  local images = {}
  for _, relative in ipairs(assetPaths(spec)) do
    local source, sourceError = fileSource(relative)
    if not source then
      releaseAsset({ images = images })
      entry.state, entry.error = "missing", sourceError
      return false
    end
    local ok, image = pcall(graphics.newImage, source,
                            { mipmaps = false, linear = false })
    if not ok or not image then
      -- LÖVE versions without ImageSettings default to no mipmaps. This
      -- fallback retains compatibility while filtering remains explicit.
      ok, image = pcall(graphics.newImage, source)
    end
    if not ok or not image then
      releaseAsset({ images = images })
      entry.state, entry.error = "missing", "decode"
      return false
    end
    if image.setFilter then pcall(image.setFilter, image, filter, filter, 1) end
    if image.setMipmapFilter then pcall(image.setMipmapFilter, image, nil) end
    local dimOk, width, height = pcall(image.getDimensions, image)
    if not dimOk or width ~= spec.width or height ~= spec.height then
      images[#images + 1] = image
      releaseAsset({ images = images })
      entry.state, entry.error = "invalid", "dimensions"
      return false
    end
    images[#images + 1] = image
  end
  local quads = {}
  for row = 0, spec.rows - 1 do
    for column = 0, spec.columns - 1 do
      local quadOk, quad = pcall(graphics.newQuad,
        column * spec.frameWidth, row * spec.frameHeight,
        spec.frameWidth, spec.frameHeight, spec.width, spec.height)
      if not quadOk or not quad then
        releaseAsset({ images = images })
        entry.state, entry.error = "invalid", "quad"
        return false
      end
      quads[#quads + 1] = quad
    end
  end
  entry.state, entry.error = "ready", nil
  entry.image, entry.images, entry.quads = images[1], images, quads
  return true
end

function SkyEvents.animationFrame(name, seconds)
  local spec = SkyEvents.ASSET_SPECS[name]
  local durations = spec and spec.durationsMs
  if not (durations and #durations > 0) then return 0 end
  local total = 0
  for _, duration in ipairs(durations) do total = total + duration end
  local elapsed = ((tonumber(seconds) or 0) * 1000) % total
  for frame, duration in ipairs(durations) do
    if elapsed < duration then return frame - 1 end
    elapsed = elapsed - duration
  end
  return 0
end

-- Loading never occurs in paint(). update() stages one atlas per frame, while
-- callers with a loading screen may prewarm the complete roster explicitly.
function SkyEvents.prewarm(limit)
  local order = activeAssetOrder()
  if not order then return 0, 0 end
  limit = math.max(0, math.floor(limit or #order))
  local attempted, ready = 0, 0
  for _, name in ipairs(order) do
    local entry = assetEntry(name)
    if entry.state == "cold" and attempted < limit then
      local graphics = graphicsApi()
      if graphics then
        loadAsset(name)
        attempted = attempted + 1
      end
    end
    if assetEntry(name).state == "ready" then ready = ready + 1 end
  end
  return ready, attempted
end

function SkyEvents.assetStatus(name)
  if not SkyEvents.ASSET_SPECS[name] then return "unknown" end
  local entry = assetEntry(name)
  return entry.state, entry.error
end

function SkyEvents.update(dt)
  if dt and dt > 0 then
    SkyEvents.clock = (SkyEvents.clock + dt) % 1000003
    if forcedRainbow then
      forcedRainbow.elapsed = forcedRainbow.elapsed + dt
      if forcedRainbow.elapsed >= forcedRainbow.duration then
        forcedRainbow = nil
      end
    end
  end
  -- The phone world-core never draws semantic sky events. Preserve clocks,
  -- expiry and queued cries, but do not synchronously decode/upload a series
  -- of 512/1024px atlases that cannot contribute to its frame.
  if not MOBILE_RUNTIME then
    if (forcedRainbow or previewRainbowMap)
        and assetEntry("rainbow").state == "cold" then
      loadAsset("rainbow")
    end
    if requestedShadowAsset
        and assetEntry(requestedShadowAsset).state == "cold" then
      loadAsset(requestedShadowAsset)
    end
    SkyEvents.prewarm(1)
  end
  if pendingCry and cryPlayer then
    local species = pendingCry
    pendingCry = nil
    pcall(cryPlayer, species)
  end
end

local function lightAllows(art, light)
  return light >= art.minLight and light <= art.maxLight
end

local function readyAsset(name)
  local entry = assetCache[name]
  return entry and entry.state == "ready" and entry or nil
end

-- Describe only a flyer that the ordinary sky painter can really draw NOW.
-- VoxelScene uses this to give visible ambient birds -- including legendary
-- sightings -- a synchronized ground shadow. A cold, disabled, obscured or
-- light-incompatible atlas returns nil, so an invisible bird never casts.
function SkyEvents.shadowState(ctx)
  ctx = type(ctx) == "table" and ctx or {}
  local weatherKind, weatherProgress, weatherOccurrence =
    SkyEvents.weatherLegend(ctx.weather, ctx.clock or SkyEvents.clock)
  if weatherKind then
    local apparent = SkyEvents.apparentHeightCells(
      weatherKind, weatherOccurrence) or 12
    local visible = readyAsset(weatherKind) ~= nil
    return {
      species = weatherKind, legendary = true, progress = weatherProgress,
      -- The first cold frame only requests the atlas. Its shadow begins with
      -- the first frame the real billboard can also be drawn.
      opacity = visible and 0.34 * fade(weatherProgress, 0.16) or 0,
      seed = weatherOccurrence, count = 1,
      scale = math.max(1.4, math.min(2.8, apparent / 7)),
      direction = weatherOccurrence % 2 == 0 and 1 or -1,
      weatherException = true,
    }
  end
  if obscuresFlyers(ctx.weather) or not SkyEvents.enabled("pidgeot") then
    return nil
  end
  local light = SkyEvents.daylight(ctx)
  local legendary, progress = SkyEvents.activeLegendary(SkyEvents.clock)
  if legendary and progress then
    local art = SkyEvents.LEGEND_ART[legendary]
    local _, occurrence = SkyEvents.anchor(legendary, SkyEvents.clock)
    if art and readyAsset(legendary) and lightAllows(art, light) then
      local apparent = SkyEvents.apparentHeightCells(legendary, occurrence) or 10
      return {
        species = legendary, legendary = true, progress = progress,
        opacity = 0.32 * fade(progress, 0.16), seed = occurrence,
        count = 1, scale = math.max(1.25, math.min(2.8, apparent / 7)),
        direction = occurrence % 2 == 0 and 1 or -1,
      }
    end
    return nil
  end

  progress = SkyEvents.progress("pidgeot", SkyEvents.clock)
  local plan = progress and SkyEvents.ordinaryPlan(SkyEvents.clock) or nil
  local art = plan and SkyEvents.ORDINARY_ART[plan.species]
  if not (plan and art and readyAsset(plan.asset) and lightAllows(art, light)) then
    return nil
  end
  return {
    species = plan.species, legendary = false, progress = progress,
    opacity = 0.30 * fade(progress, 0.16), seed = plan.occurrence,
    count = plan.count,
    scale = math.max(0.78, math.min(1.6,
      (plan.apparentHeightCells or 6) / 7)),
    direction = plan.occurrence % 2 == 0 and 1 or -1,
  }
end

local function drawBillboard(ctx, name, frame, x, y, width, height, alpha, mirror)
  local asset = readyAsset(name)
  local spec = SkyEvents.ASSET_SPECS[name]
  local graphics = ctx.g
  if not (asset and spec and graphics and type(graphics.draw) == "function") then
    return 0
  end
  local image = asset.images and asset.images[(frame % #asset.images) + 1]
                or asset.image
  local quad = asset.quads[(frame % #asset.quads) + 1]
  local scaleX = width / spec.frameWidth
  if mirror then scaleX = -scaleX end
  local scaleY = height / spec.frameHeight
  graphics.setColor(1, 1, 1, alpha)
  graphics.draw(image, quad, x, y, 0, scaleX, scaleY,
                spec.frameWidth * 0.5, spec.frameHeight * 0.5)
  return 1
end

-- Every authored flyer sheet faces screen-right.  World azimuth is not a
-- reliable proxy for screen direction: the real Voxel3D ray fan projects
-- increasing azimuth towards screen-left in the classic north-facing view,
-- while the compatibility projector uses the opposite sign.  Probe the
-- active projector along the flight path so birds always face their actual
-- on-screen movement, including after camera turns.
local function flightMirror(ctx, x, azimuth, elevation, direction)
  local ok, nextX = pcall(ctx.project,
                         azimuth + direction * 0.002, elevation)
  if ok and type(nextX) == "number" and math.abs(nextX - x) > 1e-4 then
    return nextX < x
  end
  -- Degenerate/headless projectors may collapse every bearing to one point.
  -- Their established convention maps increasing azimuth to screen-right.
  return direction < 0
end

local function paintRainbow(ctx, progress)
  if obscuresRainbow(ctx.weather) or not readyAsset("rainbow") then return 0 end
  local spec = SkyEvents.ASSET_SPECS.rainbow
  -- A rainbow is a fixed atmospheric landmark, not a HUD billboard. Feed its
  -- bearing AND elevation through exactly the same world-sky projector used
  -- by clouds; no screen/horizon coordinate may position it independently.
  local width = math.max(ctx.w * 1.10, ctx.h * 1.75)
  local height = width * spec.frameHeight / spec.frameWidth
  local azimuth = SkyEvents.rainbowAnchor(ctx.mapId)
  -- Battle cameras frame more ground than free roam, which makes the shared
  -- landmark sit too close to the top edge.  Every in-fight 3D architecture
  -- uses the battle projection; an untagged overworld frame keeps the
  -- historical world elevation exactly.
  local elevation = ctx.battleView == true
                    and BATTLE_RAINBOW_ELEVATION or RAINBOW_ELEVATION
  local x, y = projected(ctx, azimuth, elevation, width * .5, height * .5)
  if not x then return 0 end
  local alpha = (ctx.alpha or 1) * fade(progress, 0.20)
                * (ctx.guaranteedRainbow and 0.82 or 0.68)
  if alpha <= 0 then return 0 end
  return drawBillboard(ctx, "rainbow", 0, x, y, width, height, alpha, false)
end

local function paintOrdinary(ctx, progress, light, paired)
  if obscuresFlyers(ctx.weather) then return 0 end
  local plan = paired and SkyEvents.shadowPlan(ctx.shadowPolicy.birdSeed)
               or SkyEvents.ordinaryPlan(ctx.clock)
  local occurrence = plan and plan.occurrence
  local centre
  if paired and occurrence then
    local unit = ((occurrence * 977 + 431 * 131) % 1009) / 1008
    centre = math.pi + (unit * 2 - 1) * 0.36
  else
    centre = SkyEvents.anchor("pidgeot", ctx.clock)
  end
  local art = plan and SkyEvents.ORDINARY_ART[plan.species]
  if not (art and readyAsset(art.asset) and lightAllows(art, light)) then
    return 0
  end
  local alpha = (ctx.alpha or 1) * fade(progress, 0.16) * 0.88
  if alpha <= 0 then return 0 end
  local direction = occurrence % 2 == 0 and 1 or -1
  local azimuth = centre + direction * (-0.54 + progress * 1.08)
  local elevation = 0.22 + math.sin(progress * math.pi) * 0.040
                    + math.sin(progress * math.pi * 6) * 0.006
  local widthCells, heightCells = SkyEvents.displaySizeCells(
    plan.species, plan.count, occurrence)
  if not widthCells then return 0 end
  local width, height = widthCells * ctx.cell, heightCells * ctx.cell
  local x, y = projected(ctx, azimuth, elevation, width * 0.5, height * 0.5)
  if not x then return 0 end
  return drawBillboard(ctx, art.asset, 0, x, y, width, height,
                       alpha, flightMirror(ctx, x, azimuth, elevation,
                                           direction))
end

local function paintLegendary(ctx, kind, progress, light)
  if not weatherAllowsLegend(kind, ctx.weather) or not readyAsset(kind) then
    return 0
  end
  local art = SkyEvents.LEGEND_ART[kind]
  if not (art and lightAllows(art, light)) then return 0 end
  local centre, occurrence
  local weatherKind, _, weatherOccurrence =
    SkyEvents.weatherLegend(ctx.weather, ctx.clock)
  if weatherKind == kind then
    occurrence = weatherOccurrence
    local salt = EVENT_SALT[kind] or 17
    local unit = ((occurrence * 977 + salt * 131) % 1009) / 1008
    centre = math.pi + (unit * 2 - 1) * 0.72
    centre = (centre + math.pi) % (math.pi * 2) - math.pi
  else
    centre, occurrence = SkyEvents.anchor(kind, ctx.clock)
  end
  if not (centre and occurrence) then return 0 end
  local direction = occurrence % 2 == 0 and 1 or -1
  local azimuth = centre + direction * (-0.58 + progress * 1.16)
  local elevation = art.elevation + math.sin(progress * math.pi) * 0.050
                    + math.sin(progress * math.pi * 6) * 0.008
  local approach = 1 + math.sin(progress * math.pi) * 0.075
  local widthCells, heightCells = SkyEvents.displaySizeCells(kind, 1, occurrence)
  if not widthCells then return 0 end
  local width = widthCells * ctx.cell * approach
  local height = heightCells * ctx.cell * approach
  local x, y = projected(ctx, azimuth, elevation, width * 0.5, height * 0.5)
  if not x then return 0 end
  local alpha = (ctx.alpha or 1) * fade(progress, 0.16)
  if alpha <= 0 then return 0 end
  local frame = SkyEvents.animationFrame(kind,
    progress * ((SkyEvents.WEATHER_TIMING.lugia or {}).duration or 1))
  return drawBillboard(ctx, kind, frame, x, y, width, height,
                       alpha, flightMirror(ctx, x, azimuth, elevation,
                                           direction))
end

SkyEvents.MAX_DRAWS = { rainbow = 1, ordinary = 1, legendary = 1,
                        back = 1, front = 1, combined = 2 }

-- Returns actual textured draw calls. paint() never decodes an image or builds
-- a Quad; missing/invalid assets simply produce zero draws until invalidated.
function SkyEvents.paint(ctx, layer)
  if not (ctx and ctx.skyEnabled == true) then return 0 end
  if not (ctx.g and type(ctx.g.setColor) == "function"
          and type(ctx.g.draw) == "function"
          and type(ctx.project) == "function") then return 0 end
  if not (type(ctx.w) == "number" and ctx.w > 0
          and type(ctx.h) == "number" and ctx.h > 0) then return 0 end
  ctx.cell = math.max(1, math.floor((ctx.cell or 1) + 0.5))
  ctx.clock = ctx.clock or SkyEvents.clock

  local guaranteed = SkyEvents.rainbowProgress(ctx.mapId)
  local policy = ctx.shadowPolicy
  local weatherKind, weatherProgress = nil, nil
  if policy and policy.birdEnabled then
    weatherKind, weatherProgress = SkyEvents.weatherLegend(ctx.weather, ctx.clock)
  end
  local paired = policy and policy.birdPaired == true
                 and (policy.birdOpacity or 0) > 0
                 and type(policy.birdProgress) == "number"
  if not (guaranteed or paired or weatherProgress)
      and not SkyEvents.enabled() then return 0 end
  ctx.guaranteedRainbow = guaranteed ~= nil
  local drawRainbow = layer ~= "front"
                      and (guaranteed ~= nil or SkyEvents.enabled("rainbow"))
  local drawFlyers = layer ~= "back"
                     and (paired or weatherProgress
                          or SkyEvents.enabled("pidgeot"))
  local rainbow = drawRainbow and (guaranteed
                    or SkyEvents.progress("rainbow", ctx.clock)) or nil
  local legendary, legendProgress
  if drawFlyers and not paired then
    if weatherProgress then
      legendary, legendProgress = weatherKind, weatherProgress
    else
      legendary, legendProgress = SkyEvents.activeLegendary(ctx.clock)
    end
  end
  local ordinary = paired and policy.birdProgress
                   or (drawFlyers and not legendary
                       and SkyEvents.progress("pidgeot", ctx.clock) or nil)
  if not (rainbow or ordinary or legendProgress) then return 0 end

  local light = SkyEvents.daylight(ctx)
  local drawn = 0
  if rainbow and (guaranteed ~= nil or light >= 0.42) then
    drawn = drawn + paintRainbow(ctx, rainbow)
  end
  if ordinary then
    drawn = drawn + paintOrdinary(ctx, ordinary, light, paired)
  end
  if legendProgress then
    local legendDrawn = paintLegendary(ctx, legendary, legendProgress, light)
    drawn = drawn + legendDrawn
    if legendDrawn > 0 then
      queueWeatherCry(ctx, legendary, legendProgress)
    end
  end
  if drawn > 0 then ctx.g.setColor(1, 1, 1, 1) end
  return drawn
end

SkyEvents.SAVE_KEY = "skyEventsClock"

function SkyEvents.store()
  local saveApi = V.mod and V.mod.save
  if saveApi and saveApi.set then
    pcall(saveApi.set, saveApi, SkyEvents.SAVE_KEY, SkyEvents.clock)
  end
end

function SkyEvents.restore()
  local saveApi = V.mod and V.mod.save
  local stored
  if saveApi and saveApi.get then
    local ok, got = pcall(saveApi.get, saveApi, SkyEvents.SAVE_KEY)
    if ok then stored = got end
  end
  SkyEvents.clock = type(stored) == "number"
                    and stored % 1000003 or SkyEvents.DEFAULT_CLOCK
  forcedRainbow, previewRainbowMap, pendingCry = nil, nil, nil
  lastWeatherCryOccurrence = {}
end

return SkyEvents
