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

SkyEvents.DEFAULT_CLOCK = 1800
SkyEvents.clock = SkyEvents.DEFAULT_CLOCK

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

local EVENT_SALT = {
  rainbow = 193, pidgeot = 431, hooh = 887,
  articuno = 241, zapdos = 593, moltres = 761,
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
  local individual = SkyEvents.apparentHeightCells(species, occurrence)
  if not individual then return nil end
  count = math.max(1, math.min(4, math.floor(tonumber(count) or 1)))
  local formationSpacing = 1.25 + 0.25 * count
  local maximum = SkyEvents.LEGEND_ART[species] and 36 or 26
  local height = math.min(maximum, individual * formationSpacing)
  return height * 2, height
end

function SkyEvents.ordinaryPlan(clock)
  local _, occurrence = SkyEvents.anchor("pidgeot", clock)
  if not occurrence then return nil end
  local species = ORDINARY_ROTATION[(occurrence % #ORDINARY_ROTATION) + 1]
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

-- Asset contract. Artwork can be replaced without touching scheduler or
-- renderer code as long as these transparent dimensions and frame grids stay
-- stable. Ho-Oh's single composition includes its subtle rainbow wake; flight
-- path, bob, scale and direction mirroring provide animation without an atlas.
SkyEvents.ASSET_SPECS = {
  rainbow = {
    path = "assets/sky/rainbow.png", width = 512, height = 256,
    frameWidth = 512, frameHeight = 256, columns = 1, rows = 1,
    -- The previous 96-cell arc was 768 px wide at the normal 8x Metal
    -- canvas scale.  In the default 3RD reading pitch its crown sat above the
    -- canvas while both legs were occluded by the horizon wall, so a forced
    -- event produced no visible rainbow at all.  Fifty-six cells leaves the
    -- authored 2:1 arc large, but keeps its crown inside the actual sky wedge.
    displayCells = { 56, 28 },
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
}

local ASSET_ORDER = {
  "rainbow", "flock", "spearowFlock", "murkrowFlock", "farfetchd",
  "hooh", "articuno", "zapdos", "moltres",
}
local FLYER_ASSET_ORDER = {
  "flock", "spearowFlock", "murkrowFlock", "farfetchd",
  "hooh", "articuno", "zapdos", "moltres",
}
local assetCache = {}

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
  if asset and asset.image and asset.image.release then
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

local function fileSource(spec)
  -- V.path is supplied by the host for both directory mods and mounted .love
  -- archives. Passing that virtual path straight to newImage avoids a second
  -- binary copy and keeps the runtime clear of the restricted filesystem API.
  if type(V.path) == "string" then return V.path .. "/" .. spec.path end
  return nil, "missing"
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
  local source, sourceError = fileSource(spec)
  if not source then
    entry.state, entry.error = "missing", sourceError
    return false
  end
  entry.state = "loading"
  local ok, image = pcall(graphics.newImage, source,
                          { mipmaps = false, linear = false })
  if not ok or not image then
    -- LÖVE versions without ImageSettings default to no mipmaps. This fallback
    -- retains compatibility while setFilter below still enforces nearest.
    ok, image = pcall(graphics.newImage, source)
  end
  if not ok or not image then
    entry.state, entry.error = "missing", "decode"
    return false
  end
  if image.setFilter then pcall(image.setFilter, image, "nearest", "nearest", 1) end
  if image.setMipmapFilter then pcall(image.setMipmapFilter, image, nil) end
  local dimOk, width, height = pcall(image.getDimensions, image)
  if not dimOk or width ~= spec.width or height ~= spec.height then
    releaseAsset({ image = image })
    entry.state, entry.error = "invalid", "dimensions"
    return false
  end
  local quads = {}
  for row = 0, spec.rows - 1 do
    for column = 0, spec.columns - 1 do
      local quadOk, quad = pcall(graphics.newQuad,
        column * spec.frameWidth, row * spec.frameHeight,
        spec.frameWidth, spec.frameHeight, spec.width, spec.height)
      if not quadOk or not quad then
        releaseAsset({ image = image })
        entry.state, entry.error = "invalid", "quad"
        return false
      end
      quads[#quads + 1] = quad
    end
  end
  entry.state, entry.error = "ready", nil
  entry.image, entry.quads = image, quads
  return true
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
  end
  SkyEvents.prewarm(1)
end

local function lightAllows(art, light)
  return light >= art.minLight and light <= art.maxLight
end

local function readyAsset(name)
  local entry = assetCache[name]
  return entry and entry.state == "ready" and entry or nil
end

local function drawBillboard(ctx, name, frame, x, y, width, height, alpha, mirror)
  local asset = readyAsset(name)
  local spec = SkyEvents.ASSET_SPECS[name]
  local graphics = ctx.g
  if not (asset and spec and graphics and type(graphics.draw) == "function") then
    return 0
  end
  local quad = asset.quads[(frame % #asset.quads) + 1]
  local scaleX = width / spec.frameWidth
  if mirror then scaleX = -scaleX end
  local scaleY = height / spec.frameHeight
  graphics.setColor(1, 1, 1, alpha)
  graphics.draw(asset.image, quad, x, y, 0, scaleX, scaleY,
                spec.frameWidth * 0.5, spec.frameHeight * 0.5)
  return 1
end

local function paintRainbow(ctx, progress)
  if obscuresRainbow(ctx.weather) or not readyAsset("rainbow") then return 0 end
  local spec = SkyEvents.ASSET_SPECS.rainbow
  local width = math.min(ctx.w * 0.78, spec.displayCells[1] * ctx.cell)
  local height = width * spec.frameHeight / spec.frameWidth
  local centre = SkyEvents.anchor("rainbow", ctx.clock)
  local x, y = projected(ctx, centre, 0.20, width * 0.5, height * 0.5)
  if not x then return 0 end
  local alpha = (ctx.alpha or 1) * fade(progress, 0.20) * 0.68
  if alpha <= 0 then return 0 end
  return drawBillboard(ctx, "rainbow", 0, x, y, width, height, alpha, false)
end

local function paintOrdinary(ctx, progress, light)
  if obscuresFlyers(ctx.weather) then return 0 end
  local centre, occurrence = SkyEvents.anchor("pidgeot", ctx.clock)
  local plan = SkyEvents.ordinaryPlan(ctx.clock)
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
                       alpha, direction < 0)
end

local function paintLegendary(ctx, kind, progress, light)
  if obscuresFlyers(ctx.weather) or not readyAsset(kind) then return 0 end
  local art = SkyEvents.LEGEND_ART[kind]
  if not (art and lightAllows(art, light)) then return 0 end
  local centre, occurrence = SkyEvents.anchor(kind, ctx.clock)
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
  return drawBillboard(ctx, kind, 0, x, y, width, height,
                       alpha, direction < 0)
end

SkyEvents.MAX_DRAWS = { rainbow = 1, ordinary = 1, legendary = 1,
                        back = 1, front = 1, combined = 2 }

-- Returns actual textured draw calls. paint() never decodes an image or builds
-- a Quad; missing/invalid assets simply produce zero draws until invalidated.
function SkyEvents.paint(ctx, layer)
  if not (ctx and ctx.skyEnabled == true and SkyEvents.enabled()) then return 0 end
  if not (ctx.g and type(ctx.g.setColor) == "function"
          and type(ctx.g.draw) == "function"
          and type(ctx.project) == "function") then return 0 end
  if not (type(ctx.w) == "number" and ctx.w > 0
          and type(ctx.h) == "number" and ctx.h > 0) then return 0 end
  ctx.cell = math.max(1, math.floor((ctx.cell or 1) + 0.5))
  ctx.clock = ctx.clock or SkyEvents.clock

  local drawRainbow = layer ~= "front" and SkyEvents.enabled("rainbow")
  local drawFlyers = layer ~= "back" and SkyEvents.enabled("pidgeot")
  local rainbow = drawRainbow and SkyEvents.progress("rainbow", ctx.clock) or nil
  local legendary, legendProgress
  if drawFlyers then legendary, legendProgress = SkyEvents.activeLegendary(ctx.clock) end
  local ordinary = drawFlyers and not legendary
                   and SkyEvents.progress("pidgeot", ctx.clock) or nil
  if not (rainbow or ordinary or legendProgress) then return 0 end

  local light = SkyEvents.daylight(ctx)
  local drawn = 0
  if light >= 0.42 and rainbow then drawn = drawn + paintRainbow(ctx, rainbow) end
  if ordinary then drawn = drawn + paintOrdinary(ctx, ordinary, light) end
  if legendProgress then
    drawn = drawn + paintLegendary(ctx, legendary, legendProgress, light)
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
end

return SkyEvents
