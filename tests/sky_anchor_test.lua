local stored = { sky = "full", clouds = "on" }
local cache = {}
local sourcePalette = {
  { 240, 248, 255 }, { 144, 200, 240 },
  { 64, 120, 192 }, { 16, 40, 80 },
}

local V = {
  path = "/virtual/VOXEL_ASCENDANT",
  mod = {
    id = "VOXEL_ASCENDANT",
    options = { get = function(_, key) return stored[key] end },
  },
}

function V.require(name)
  if cache[name] then return cache[name] end
  if name == "ModSetting" then
    cache[name] = assert(loadfile("lib/ModSetting.lua"))(V)
  elseif name == "DayNight" then
    cache[name] = {
      palette = function() return sourcePalette end,
      time = function() return 900 end,
      mix = function() return { night = 1 } end,
    }
  elseif name == "SkyEvents" then
    cache[name] = assert(loadfile("lib/SkyEvents.lua"))(V)
  else
    error("unexpected dependency: " .. tostring(name))
  end
  return cache[name]
end

package.preload["src.render.PaletteFX"] = function()
  return { effectiveColors = function(p) return p end }
end

local function near(actual, expected, tolerance, message)
  if math.abs(actual - expected) > tolerance then
    error((message or "values differ") .. ": expected "
          .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function vecNear(a, b, tolerance, message)
  for i = 1, 3 do near(a[i], b[i], tolerance, message) end
end

local Sky = assert(loadfile("lib/Sky.lua"))(V)

-- FULL expands the short time-of-day palette into one tiny nearest-sampled
-- texture. This is the visual correction for the few huge curved bands in a
-- low 1ST/3RD camera: finer steps, without a filtered bitmap or a second pass.
local denseA = Sky.bands()
if #denseA ~= Sky.GRADIENT_BANDS or Sky.GRADIENT_BANDS ~= 96 then
  error("FULL sky did not build its exact 96-step gradient")
end
if Sky.GRADIENT_RGBA_BYTES ~= 384 then
  error("sky gradient escaped its 384-byte RGBA8 allocation")
end
near(denseA[1][1], sourcePalette[#sourcePalette][1] / 255, 1e-12,
     "gradient zenith does not retain the deepest key colour")
near(denseA[#denseA][3], sourcePalette[1][3] / 255, 1e-12,
     "gradient horizon does not retain the haze key colour")
local maxStep = 0
for i = 2, #denseA do
  for channel = 1, 3 do
    maxStep = math.max(maxStep,
      math.abs(denseA[i][channel] - denseA[i - 1][channel]))
  end
end
if maxStep >= 0.02 then
  error("densified sky retained a broad source-palette jump: "
        .. tostring(maxStep))
end

-- The native pilot is 1069 px tall and both free cameras use a 65-degree
-- vertical lens. At the horizon the angular ramp pitch must stay below nine
-- canvas pixels; perspective expands the upper visible rows to the measured
-- 10-12 px range. The old 24-step ramp was 33.6 px at the horizon and 40-49 px
-- in the capture, which is why only 8-9 of its steps read as huge rings.
local nativeH, freeFov = 1069, math.rad(65)
local focalPixels = nativeH / (2 * math.tan(freeFov / 2))
local horizonStepPixels = focalPixels * Sky.ELEV_SPAN / Sky.GRADIENT_BANDS
if horizonStepPixels >= 9 then
  error("free-camera sky steps are still too coarse at native resolution: "
        .. tostring(horizonStepPixels) .. " px")
end
local visibleTwentyDegrees = Sky.GRADIENT_BANDS * 20 / math.deg(Sky.ELEV_SPAN)
if visibleTwentyDegrees < 34 then
  error("low free-camera slice still exposes too few sky colours: "
        .. tostring(visibleTwentyDegrees))
end
if Sky.bands() ~= denseA then
  error("unchanged sky keys rebuilt the fine ramp table")
end

-- Exercise the actual Android-safe palette texture seam: exact 96x1 storage,
-- all texels populated, nearest/clamp, and no mip chain. Water receives this
-- same image/count/table rather than rebuilding a mismatched reflection ramp.
local priorLove = love
local rampWidth, rampHeight, rampPixels = nil, nil, 0
local rampFilter, rampWrap, rampMipmaps, rampReleased
love = {
  image = {
    newImageData = function(width, height)
      rampWidth, rampHeight = width, height
      local data = {}
      function data:setPixel(x, y, r, g, b, a)
        if x ~= rampPixels or y ~= 0 or a ~= 1
            or not (r and g and b) then
          error("sky ramp texel write escaped its exact row")
        end
        rampPixels = rampPixels + 1
      end
      return data
    end,
  },
  graphics = {
    newImage = function()
      local image = {}
      function image:setFilter(min, mag) rampFilter = { min, mag } end
      function image:setMipmapFilter(mode) rampMipmaps = mode or false end
      function image:setWrap(horizontal, vertical)
        rampWrap = { horizontal, vertical }
      end
      function image:release() rampReleased = true end
      return image
    end,
  },
}
local rampImage = Sky._rampFor(denseA)
if not rampImage or rampWidth ~= 96 or rampHeight ~= 1 or rampPixels ~= 96 then
  error("sky ramp was not one exact 96x1 palette texture")
end
if not rampFilter or rampFilter[1] ~= "nearest"
    or rampFilter[2] ~= "nearest" then
  error("sky ramp enabled filtered sampling")
end
if not rampWrap or rampWrap[1] ~= "clamp" or rampWrap[2] ~= "clamp" then
  error("sky ramp sampler is not clamped on both axes")
end
if rampMipmaps ~= false then error("sky ramp enabled mipmaps") end
local waterRamp, waterCount, waterBands = Sky.ramp()
if waterRamp ~= rampImage or waterCount ~= 96 or waterBands ~= denseA then
  error("water reflection did not share the painted sky ramp exactly")
end

-- Context invalidation releases this tiny GPU object and the next FULL query
-- recreates the exact same 96-step contract. No stale 24-step image can survive
-- a resize/hot reload, and water immediately receives the replacement.
rampReleased = false
Sky.invalidate()
if not rampReleased then error("sky invalidation retained the old ramp image") end
rampWidth, rampHeight, rampPixels = nil, nil, 0
local rebuiltRamp, rebuiltCount, rebuiltBands = Sky.ramp()
if not rebuiltRamp or rebuiltRamp == rampImage or rebuiltCount ~= 96
    or rebuiltBands ~= denseA or rampWidth ~= 96 or rampHeight ~= 1
    or rampPixels ~= 96 then
  error("FULL sky did not rebuild its exact shared ramp after invalidation")
end
rampImage = rebuiltRamp

-- The density change belongs only to FULL. FLAT keeps the caller's descriptor
-- without bands or a ramp; OFF still declines the sky completely.
stored.sky = "flat"
Sky.setting:sync("flat")
local flat = { 0.2, 0.3, 0.4, 1, bands = denseA }
if Sky.dress(flat) ~= flat or flat.bands ~= nil or Sky.ramp() ~= nil then
  error("FLAT sky semantics changed with the FULL ramp density")
end
stored.sky = "off"
Sky.setting:sync("off")
if Sky.dress({ 0.2, 0.3, 0.4, 1 }) ~= nil or Sky.ramp() ~= nil then
  error("OFF sky semantics changed with the FULL ramp density")
end
stored.sky = "full"
Sky.setting:sync("full")

-- A clock/display-palette change invalidates the memoised ramp, while keeping
-- the same fixed storage/draw budget. Restore the source before atmosphere QA.
rampReleased = false
sourcePalette[1][1] = 232
local denseB = Sky.bands()
if denseB == denseA or not rampReleased
    or #denseB ~= Sky.GRADIENT_BANDS then
  error("time-of-day key change did not replace/release the sky ramp")
end
sourcePalette[1][1] = 240
Sky.bands()
love = priorLove

-- The same construction Voxel3D.viewProjection uses: a symmetric camera ray
-- fan in WORLD axes. At (u,v)=(.5,.5) it points along the supplied bearing and
-- elevation.
local function cameraRay(azimuth, elevation)
  local f = Sky.direction(azimuth, elevation)
  local right = { -f[3], 0, f[1] }
  local rl = math.sqrt(right[1] * right[1] + right[3] * right[3])
  right[1], right[3] = right[1] / rl, right[3] / rl
  local up = {
    right[2] * f[3] - right[3] * f[2],
    right[3] * f[1] - right[1] * f[3],
    right[1] * f[2] - right[2] * f[1],
  }
  local tanX, tanY = math.tan(math.rad(38)), math.tan(math.rad(31))
  return {
    base = { f[1] - right[1] * tanX + up[1] * tanY,
             f[2] - right[2] * tanX + up[2] * tanY,
             f[3] - right[3] * tanX + up[3] * tanY },
    du = { right[1] * 2 * tanX, right[2] * 2 * tanX,
           right[3] * 2 * tanX },
    dv = { up[1] * -2 * tanY, up[2] * -2 * tanY,
           up[3] * -2 * tanY },
  }
end

local w, h = 800, 600
local az, el = 0.42, math.rad(24)
local direction = Sky.direction(az, el)
local x, y, visible = Sky.projectDirection(cameraRay(az, el), w, h,
                                            direction)
if not visible then error("the camera's own centre direction was not visible") end
near(x, w / 2, 1e-6, "world direction projects to the horizontal centre")
near(y, h / 2, 1e-6, "world direction projects to the vertical centre")

-- Turning the camera changes where the SAME world direction appears. The
-- direction itself is not recomputed from or parented to camera yaw.
local turnedX, turnedY = Sky.projectDirection(cameraRay(az + 0.35, el),
                                               w, h, direction)
if not turnedX or math.abs(turnedX - x) < 100 then
  error("turning did not move a world-fixed sky point across the canvas")
end
near(turnedY, y, 20, "pure yaw keeps a sky point near the same elevation")
local backX, _, backVisible = Sky.projectDirection(
  cameraRay(az + math.pi, el), w, h, direction)
if backX or backVisible then error("the opposite half of the sky wrapped forward") end

local freeProject = Sky.projector(cameraRay(az, el), w, h, h)
local freeX, freeY, freeVisible = freeProject(az, el)
if not freeVisible then error("free-camera event projector lost its centre") end
near(freeX, w / 2, 1e-6, "event projector shares the atmosphere anchor")
near(freeY, h / 2, 1e-6, "event projector shares the atmosphere elevation")
local orbitProject = Sky.projector(nil, w, h, h * 0.25)
local northX, horizonY, northVisible = orbitProject(math.pi, 0)
if not northVisible then error("north-facing orbit projection is not visible") end
near(northX, w / 2, 1e-6, "orbit keeps north at screen centre")
near(horizonY, h * 0.25, 1e-6, "orbit sky meets its actual horizon")

local cloudA = Sky.cloudDirection(7, 123.5)
local cloudB = Sky.cloudDirection(7, 123.5)
vecNear(cloudA, cloudB, 1e-12, "cloud world address is camera-independent")
local _, cloudAz, cloudEl = Sky.cloudDirection(7, 123.5)
local cloudX = Sky.projectDirection(cameraRay(cloudAz, cloudEl), w, h, cloudA)
local turnedCloudX = Sky.projectDirection(
  cameraRay(cloudAz + 0.30, cloudEl), w, h, cloudA)
near(cloudX, w / 2, 1e-6, "cloud bearing projects to its camera centre")
if not turnedCloudX or math.abs(turnedCloudX - cloudX) < 80 then
  error("turning the camera did not move the world-fixed cloud sprite")
end
if Sky.RAY_DITHER ~= false then
  error("free-camera sky must not turn angular dither into checker ribbons")
end
near(Sky.ditherStart(cameraRay(az, el)), 2, 0,
     "free-camera sky disables broad angular checker ribbons")
near(Sky.ditherStart(nil), Sky.DITHER_START, 0,
     "level screen sky preserves its compact pixel dither")
if Sky.CLOUD_MAX_DRAWS ~= Sky.CLOUD_COUNT then
  error("cloud image-draw budget is not an exact fixed bound")
end
if Sky.CLOUD_ASSET.rgbaBytes ~= 262144 then
  error("cloud atlas VRAM contract changed from the 256 KiB RGBA8 budget")
end
for i = 1, Sky.CLOUD_COUNT do
  local variantA, widthA, heightA = Sky.cloudVisual(i, 2)
  local variantB, widthB, heightB = Sky.cloudVisual(i, 2)
  if variantA ~= variantB or widthA ~= widthB or heightA ~= heightB
      or variantA < 1 or variantA > Sky.CLOUD_ASSET.frames then
    error("cloud art/scale assignment is not deterministic and bounded")
  end
end
local starA = Sky.starDirection(31)
Sky.clock = 999
local starB = Sky.starDirection(31)
vecNear(starA, starB, 1e-12, "twinkle clock must not move a star")
if Sky.STAR_COUNT ~= 224 or Sky.FALLBACK_STAR_COUNT ~= 72 then
  error("expanded star field escaped its bounded 224/72 candidate contract")
end
local starFamilies = {}
for i = 1, Sky.STAR_COUNT do
  local color, cells, speed = Sky.starVisual(i)
  starFamilies[table.concat(color, ",") .. ":" .. tostring(cells)] = true
  if (cells ~= 1 and cells ~= 2) or speed <= 0 then
    error("star family has an invalid size/twinkle rate")
  end
end
local familyCount = 0
for _ in pairs(starFamilies) do familyCount = familyCount + 1 end
if familyCount < 5 then error("night sky lost its five distinct star families") end
if #Sky.CONSTELLATIONS ~= 3 or Sky.CONSTELLATION_MAX_LINES ~= 32 then
  error("Pokemon constellation set/count changed unexpectedly")
end
local constellationNames = {}
for ci, constellation in ipairs(Sky.CONSTELLATIONS) do
  constellationNames[constellation.id] = true
  if #constellation.points < 9 or #constellation.segments < 9 then
    error(constellation.id .. " is too sparse to read as a constellation")
  end
  local pointA = Sky.constellationDirection(ci, 1)
  Sky.clock = Sky.clock + 10
  local pointB = Sky.constellationDirection(ci, 1)
  vecNear(pointA, pointB, 1e-12,
          constellation.id .. " moved when only twinkle time changed")
end
if not (constellationNames.PIKACHU and constellationNames.MAGIKARP
        and constellationNames.LAPRAS) then
  error("named Pokemon constellation identities are incomplete")
end

-- Exercise the real paint seam: a rayed 1ST/3RD frame must route every
-- atmospheric body through the world projector, including the orbit's
-- north-facing atmosphere ray.
local rectangles, imageDraws, constellationLines = 0, 0, 0
local imageLoads, quadBuilds = 0, 0
local cloudReleases, eventReleases = 0, 0
local loadedSource, loadedSettings
love = love or {}
local originalGraphics = love.graphics
love.graphics = {
  rectangle = function() rectangles = rectangles + 1 end,
  line = function() constellationLines = constellationLines + 1 end,
  getLineWidth = function() return 1 end,
  setLineWidth = function() end,
  getLineStyle = function() return "smooth" end,
  setLineStyle = function() end,
  newImage = function(source, settings)
    imageLoads = imageLoads + 1
    loadedSource, loadedSettings = source, settings
    local cloud = source:find("/clouds.png", 1, true) ~= nil
    local image = {}
    function image:getDimensions() return 512, cloud and 128 or 256 end
    function image:setFilter(min, mag, anisotropy)
      if min ~= "nearest" or mag ~= "nearest" or anisotropy ~= 1 then
        error("cloud atlas filter was not nearest/nearest with bounded anisotropy")
      end
    end
    function image:setMipmapFilter(mode)
      if mode ~= nil then error("cloud atlas enabled mipmaps") end
    end
    function image:release()
      if cloud then cloudReleases = cloudReleases + 1
               else eventReleases = eventReleases + 1 end
    end
    return image
  end,
  newQuad = function(x, y, qw, qh, iw, ih)
    quadBuilds = quadBuilds + 1
    local cloud = y == 0 and qw == 128 and qh == 128
                  and iw == 512 and ih == 128
    local event = x == 0 and y == 0 and qw == 512 and qh == 256
                  and iw == 512 and ih == 256
    if not (cloud or event) then
      error("sky-family atlas quad escaped its declared layout")
    end
    return { x = x, y = y }
  end,
  draw = function() imageDraws = imageDraws + 1 end,
  setColor = function() end,
  getShader = function() return nil end,
  setShader = function() end,
  getDepthMode = function() return "always", false end,
  setDepthMode = function() end,
  getBlendMode = function() return "alpha", "alphamultiply" end,
  setBlendMode = function() end,
  getScissor = function() return nil end,
  setScissor = function() end,
}

local ready, attempted = Sky.prewarmClouds()
if not ready or attempted ~= 1 or Sky.cloudAssetStatus() ~= "ready" then
  error("cloud atlas did not prewarm exactly once")
end
if imageLoads ~= 1 or quadBuilds ~= Sky.CLOUD_ASSET.frames then
  error("cloud atlas did not build one image and its exact four quads")
end
if loadedSource ~= V.path .. "/" .. Sky.CLOUD_ASSET.path
    or not loadedSettings or loadedSettings.mipmaps ~= false then
  error("cloud atlas used the wrong virtual path or mipmap settings")
end
ready, attempted = Sky.prewarmClouds()
if not ready or attempted ~= 0 or imageLoads ~= 1 then
  error("repeated cloud prewarm decoded the atlas again")
end

-- Context loss must release the complete sky family, not only the ramp and
-- disc. Exercise a real staged event image as well as the cloud atlas, call the
-- invalidator twice, then prove both public prewarm paths can reload cleanly.
local events = cache.SkyEvents
local eventReady, eventAttempted = events.prewarm(1)
if eventReady ~= 1 or eventAttempted ~= 1
    or events.assetStatus("rainbow") ~= "ready" then
  error("sky event fixture did not stage one real atlas before invalidation")
end
Sky.invalidate()
if cloudReleases ~= 1 or eventReleases ~= 1
    or Sky.cloudAssetStatus() ~= "cold"
    or events.assetStatus("rainbow") ~= "cold" then
  error("Sky.invalidate did not release/reset cloud and event GPU assets")
end
Sky.invalidate()
if cloudReleases ~= 1 or eventReleases ~= 1 then
  error("repeated Sky.invalidate released an already-cold sky asset")
end
ready, attempted = Sky.prewarmClouds()
eventReady, eventAttempted = events.prewarm(1)
if not ready or attempted ~= 1 or eventReady ~= 1 or eventAttempted ~= 1
    or Sky.cloudAssetStatus() ~= "ready"
    or events.assetStatus("rainbow") ~= "ready" then
  error("sky-family assets were not reloadable after context invalidation")
end

local originalProject = Sky.projectDirection
local originalProjectSky = Sky.projectSky
local projected, projectedAngles = 0, 0
Sky.projectDirection = function(...)
  projected = projected + 1
  return originalProject(...)
end
Sky.projectSky = function(...)
  projectedAngles = projectedAngles + 1
  return originalProjectSky(...)
end
local painted = Sky.paint(w, h, { 0.4, 0.6, 0.9, 1,
  bands = { { 0.1, 0.2, 0.4 }, { 0.4, 0.6, 0.9 } } }, nil, 2, nil,
  nil, nil, cameraRay(az, el))
if not painted or projected < Sky.STAR_COUNT
    or projectedAngles < Sky.CLOUD_COUNT then
  error("rayed sky did not world-project its atmosphere")
end
if constellationLines == 0 then
  error("deep-night painter emitted no visible constellation connections")
end

projected, projectedAngles = 0, 0
Sky.paint(w, h, { 0.4, 0.6, 0.9, 1,
  bands = { { 0.1, 0.2, 0.4 }, { 0.4, 0.6, 0.9 } } }, h * 0.25, 2,
  nil, nil, nil, nil, { ray = cameraRay(math.pi, el) })
if projected < Sky.STAR_COUNT or projectedAngles < Sky.CLOUD_COUNT then
  error("orbit atmosphere did not use its real north-facing projector")
end
if rectangles == 0 then error("headless sky painter produced no fallback output") end

-- Every candidate admitted at once is the artificial worst case. The painter
-- must still stay at its declared one-image-per-cloud budget, and CLOUDS OFF must
-- return before even constructing/projecting that list.
local originalProjector = Sky.projector
local projectedClouds, projectorBuilds = 0, 0
Sky.projector = function()
  projectorBuilds = projectorBuilds + 1
  return function()
    projectedClouds = projectedClouds + 1
    return w / 2, h / 4, true
  end
end
stored.clouds = "on"
Sky.cloudSetting:sync("on")
rectangles, imageDraws, projectedClouds, projectorBuilds = 0, 0, 0, 0
local loadsBeforePaint = imageLoads
Sky._paintClouds(w, h, h, 2, 1, cameraRay(az, el), 0)
if projectedClouds ~= Sky.CLOUD_COUNT then
  error("cloud painter did not project its exact bounded candidate count")
end
if imageDraws ~= Sky.CLOUD_MAX_DRAWS or rectangles ~= 0 then
  error("cloud painter exceeded or under-filled its declared sprite budget: "
        .. tostring(imageDraws) .. " versus " .. tostring(Sky.CLOUD_MAX_DRAWS))
end
if projectorBuilds ~= 1 then error("cloud painter built more than one projector") end
if imageLoads ~= loadsBeforePaint then error("cloud paint decoded or loaded an image") end

stored.clouds = "off"
Sky.cloudSetting:sync("off")
rectangles, imageDraws, projectedClouds, projectorBuilds = 0, 0, 0, 0
Sky._paintClouds(w, h, h, 2, 1, cameraRay(az, el), 0)
Sky.update(1 / 60)
if rectangles ~= 0 or imageDraws ~= 0 or projectedClouds ~= 0
    or projectorBuilds ~= 0 or imageLoads ~= loadsBeforePaint then
  error("CLOUDS OFF did work: draws=" .. tostring(imageDraws)
        .. ", projections=" .. tostring(projectedClouds)
        .. ", projector builds=" .. tostring(projectorBuilds))
end
stored.clouds = "on"
Sky.cloudSetting:sync("on")
Sky.projector = originalProjector

-- A corrupt replacement is rejected once and then remains a zero-draw state;
-- paint must never try to decode it again or fall back to blurry rectangles.
Sky.invalidateCloudAsset()
love.graphics.newImage = function()
  imageLoads = imageLoads + 1
  local image = {}
  function image:getDimensions() return 511, 128 end
  function image:setFilter() end
  function image:setMipmapFilter() end
  function image:release() end
  return image
end
local loadsBeforeInvalid = imageLoads
ready, attempted = Sky.prewarmClouds()
local invalidState, invalidReason = Sky.cloudAssetStatus()
if ready or attempted ~= 1 or invalidState ~= "invalid"
    or invalidReason ~= "dimensions" then
  error("invalid cloud atlas did not fail closed on exact dimensions")
end
imageDraws, projectedClouds, projectorBuilds = 0, 0, 0
Sky._paintClouds(w, h, h, 2, 1, cameraRay(az, el), 0)
Sky.prewarmClouds()
if imageDraws ~= 0 or projectedClouds ~= 0 or projectorBuilds ~= 0
    or imageLoads ~= loadsBeforeInvalid + 1 then
  error("invalid cloud atlas retried or painted after fail-closed validation")
end
love.graphics = originalGraphics

print("sky anchors: ok; gradient = 96x1 nearest RGBA8 / 384 B / one pass; "
      .. "clouds <= " .. tostring(Sky.CLOUD_MAX_DRAWS)
      .. " image draws, atlas = 256 KiB RGBA8, CLOUDS OFF = 0")
