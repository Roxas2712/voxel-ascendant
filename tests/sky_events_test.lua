local stored = { skyEvents = "full" }
local cache = {}

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected "
          .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function check(value, message)
  if not value then error(message or "check failed", 2) end
end

local assetDimensions = {
  ["rainbow.png"] = { 512, 256 },
  ["bird_flock.png"] = { 512, 256 },
  ["spearow_flock.png"] = { 512, 256 },
  ["murkrow_flock.png"] = { 512, 256 },
  ["farfetchd.png"] = { 512, 256 },
  ["hooh.png"] = { 512, 256 },
  ["articuno.png"] = { 512, 256 },
  ["zapdos.png"] = { 512, 256 },
  ["moltres.png"] = { 512, 256 },
}
local missing, wrongDimensions = {}, {}
local calls = {
  read = {}, newImage = {}, newQuad = {}, images = {},
  draw = {}, color = {}, project = {}, rectangle = 0,
}

local graphics = {}

function graphics.newImage(source, settings)
  local name = type(source) == "string" and source:match("([^/]+)$") or nil
  calls.newImage[#calls.newImage + 1] = { name = name, settings = settings }
  if missing[name] then error("missing test image " .. tostring(name)) end
  local dimensions = assetDimensions[name]
  if not dimensions then error("unknown test image " .. tostring(name)) end
  local image = {
    name = name,
    width = wrongDimensions[name] and dimensions[1] + 1 or dimensions[1],
    height = dimensions[2],
    filter = nil, mipmapFilterCalled = false, released = false,
  }
  function image:setFilter(min, mag, anisotropy)
    self.filter = { min, mag, anisotropy }
  end
  function image:setMipmapFilter(value)
    self.mipmapFilterCalled = true
    self.mipmapFilter = value
  end
  function image:getDimensions() return self.width, self.height end
  function image:release() self.released = true end
  calls.images[#calls.images + 1] = image
  return image
end

function graphics.newQuad(x, y, width, height, textureWidth, textureHeight)
  local quad = {
    x = x, y = y, width = width, height = height,
    textureWidth = textureWidth, textureHeight = textureHeight,
  }
  calls.newQuad[#calls.newQuad + 1] = quad
  return quad
end

function graphics.setColor(r, g, b, a)
  calls.color[#calls.color + 1] = { r, g, b, a }
end

function graphics.draw(image, quad, x, y, rotation, sx, sy, ox, oy)
  calls.draw[#calls.draw + 1] = {
    image = image, quad = quad, x = x, y = y, rotation = rotation,
    sx = sx, sy = sy, ox = ox, oy = oy,
  }
end

function graphics.rectangle()
  calls.rectangle = calls.rectangle + 1
  error("SkyEvents must not build procedural rectangle art")
end

love = { graphics = graphics }

local V = {
  path = "mounted/VOXEL_ASCENDANT",
  mod = {
    id = "VOXEL_ASCENDANT",
    options = { get = function(_, key) return stored[key] end },
    read = function(_, path)
      calls.read[path] = (calls.read[path] or 0) + 1
      if missing[path] then return nil end
      return "test-png:" .. path
    end,
  },
}

function V.require(name)
  if cache[name] then return cache[name] end
  if name == "ModSetting" then
    cache[name] = assert(loadfile("lib/ModSetting.lua"))(V)
  elseif name == "DayNight" then
    cache[name] = {
      time = function() return 300 end,
      mix = function() return { day = 1 } end,
    }
  else
    error("unexpected dependency " .. tostring(name))
  end
  return cache[name]
end

local Events = assert(loadfile("lib/SkyEvents.lua"))(V)

local function resetRender()
  calls.draw, calls.color, calls.project = {}, {}, {}
  calls.rectangle = 0
end

local function totalReads()
  local count = 0
  for _, reads in pairs(calls.read) do count = count + reads end
  return count
end

local function context(clock, daylight)
  return {
    skyEnabled = true,
    g = graphics, w = 320, h = 180, edge = 100, cell = 2, alpha = 1,
    daylight = daylight == nil and 1 or daylight,
    weather = "clear", clock = clock,
    project = function(azimuth, elevation)
      calls.project[#calls.project + 1] = { azimuth, elevation }
      local relative = (azimuth - math.pi + math.pi) % (math.pi * 2) - math.pi
      return 160 + relative * 80, 90 - elevation * 80, true
    end,
  }
end

local function centredContext(clock, daylight)
  local ctx = context(clock, daylight)
  ctx.project = function(azimuth, elevation)
    calls.project[#calls.project + 1] = { azimuth, elevation }
    return 160, 80, true
  end
  return ctx
end

local function startOf(kind)
  local timing = Events.TIMING[kind]
  return timing.period - timing.offset
end

local function ordinaryClock(species, wantedCount)
  for occurrence = 1, 4096 do
    local clock = Events.eventClock("pidgeot", 0.5, occurrence)
    local plan = Events.ordinaryPlan(clock)
    if plan.species == species
        and (not wantedCount or plan.count == wantedCount)
        and not Events.activeLegendary(clock) then
      return clock, plan
    end
  end
  return nil
end

-- Settings, cadence and world anchors are unchanged by the art backend.
eq(Events.setting.key, "skyEvents", "sky event quality is persisted")
eq(Events.mode(), "full", "complete rare-event set is the default")
for _, kind in ipairs({
    "rainbow", "pidgeot", "hooh", "articuno", "zapdos", "moltres",
}) do
  eq(Events.enabled(kind), true, "FULL permits " .. kind)
  local timing, start = Events.TIMING[kind], startOf(kind)
  eq(Events.progress(kind, start), 0, kind .. " opens deterministically")
  check(math.abs(Events.progress(kind, start + timing.duration * 0.5) - 0.5)
        < 1e-8, kind .. " has normalised progress")
  eq(Events.progress(kind, start + timing.duration), nil,
     kind .. " closes at its exact duration")
  local az1, occurrence1 = Events.anchor(kind, start + 1)
  local az2, occurrence2 = Events.anchor(kind, start + 2)
  eq(az1, az2, kind .. " retains one world bearing")
  eq(occurrence1, occurrence2, kind .. " occurrence remains stable")
end
eq(Events.enabled("missing"), false, "unknown event fails closed")

Events.setting:sync("rainbow")
eq(Events.enabled("rainbow"), true, "RAINBOW keeps the arc")
eq(Events.enabled("pidgeot"), false, "RAINBOW drops flyers")
Events.setting:sync("flyers")
eq(Events.enabled("rainbow"), false, "FLYERS drops the arc")
eq(Events.enabled("hooh"), true, "FLYERS keeps legends")
Events.setting:sync("off")
eq(Events.enabled(), false, "OFF is a complete kill switch")
Events.setting:sync("full")

local seenSpecies, seenCounts, murkrowClock = {}, {}, nil
for occurrence = 1, 512 do
  local clock = Events.eventClock("pidgeot", 0.5, occurrence)
  local first, replay = Events.ordinaryPlan(clock), Events.ordinaryPlan(clock)
  eq(first.species, replay.species, "species selection is deterministic")
  eq(first.formation, replay.formation, "formation selection is deterministic")
  eq(first.count, replay.count, "formation size is deterministic")
  local art = Events.ORDINARY_ART[first.species]
  check(art ~= nil, "scheduled species has explicit art metadata")
  check(art.asset and Events.ASSET_SPECS[art.asset],
        "scheduled species always has an approved PNG contract")
  check(first.count >= art.minCount and first.count <= art.maxCount,
        "formation obeys the species size class")
  eq(first.heightMeters, art.heightMeters,
     "plan exposes canonical height metadata")
  check(first.distanceMeters >= art.distanceMin
        and first.distanceMeters <= art.distanceMax,
        "plan derives a bounded observation distance")
  eq(first.apparentHeightCells,
     Events.apparentHeightCells(first.species, first.occurrence),
     "plan reuses the proportional scale calculation")
  seenSpecies[first.species] = (seenSpecies[first.species] or 0) + 1
  seenCounts[first.count] = true
  if first.species == "murkrow" and not Events.activeLegendary(clock) then
    murkrowClock = murkrowClock or clock
  end
end
for _, species in ipairs(Events.ORDINARY_ROSTER) do
  check(seenSpecies[species], species .. " remains reachable")
end
local rosterCount, registryCount = 0, 0
for _ in ipairs(Events.ORDINARY_ROSTER) do rosterCount = rosterCount + 1 end
for _ in pairs(Events.ORDINARY_ART) do registryCount = registryCount + 1 end
eq(rosterCount, 7, "frozen ordinary roster has exactly seven species")
eq(registryCount, rosterCount,
   "ordinary art registry cannot hide unapproved extra species")
for count = 1, 4 do check(seenCounts[count], "formation " .. count .. " is reachable") end
check(seenSpecies.murkrow < seenSpecies.pidgey, "Murkrow remains occasional")
check(seenSpecies.pidgeot < seenSpecies.pidgey, "Pidgeot remains rare")

-- Official species heights feed one perspective formula. Test the complete
-- deterministic distance range, not just a convenient production occurrence.
local canonicalHeights = {
  pidgey = 0.3, pidgeotto = 1.1, pidgeot = 1.5,
  spearow = 0.3, fearow = 1.2, farfetchd = 0.8,
  murkrow = 0.5,
  articuno = 1.7, zapdos = 1.6, moltres = 2.0, hooh = 3.8,
}
for species, height in pairs(canonicalHeights) do
  local art = Events.ORDINARY_ART[species] or Events.LEGEND_ART[species]
  eq(art.heightMeters, height, species .. " retains canonical height in metres")
end
local maxPidgey, minPidgeot, minHooh = 0, math.huge, math.huge
for occurrence = 1, 997 do
  maxPidgey = math.max(maxPidgey,
    Events.apparentHeightCells("pidgey", occurrence))
  minPidgeot = math.min(minPidgeot,
    Events.apparentHeightCells("pidgeot", occurrence))
  minHooh = math.min(minHooh,
    Events.apparentHeightCells("hooh", occurrence))
end
check(maxPidgey < minPidgeot, "Pidgey can never appear taller than Pidgeot")
check(maxPidgey < minHooh, "Pidgey can never appear taller than Ho-Oh")
eq(Events.apparentHeightCells("missing", 1), nil,
   "unknown species has no accidental display scale")
for _, species in ipairs({ "pidgey", "spearow", "murkrow" }) do
  local art = Events.ORDINARY_ART[species]
  check(art.minCount >= 2 and art.maxCount <= 4,
        species .. " appears only in a small flock")
end
for _, species in ipairs({ "pidgeotto", "fearow", "farfetchd" }) do
  local art = Events.ORDINARY_ART[species]
  check(art.minCount == 1 and art.maxCount == 2,
        species .. " stays single or paired")
end
for _, species in ipairs({ "pidgeot" }) do
  local art = Events.ORDINARY_ART[species]
  eq(art.minCount, 1, species .. " is solitary")
  eq(art.maxCount, 1, species .. " cannot overcrowd the sky")
end
for _, species in ipairs({ "hoothoot", "noctowl", "skarmory" }) do
  eq(Events.ORDINARY_ART[species], nil,
     species .. " has no generic placeholder registry entry")
end

local overlapClock
for second = 0, 1000003 do
  local raw = 0
  for _, kind in ipairs(Events.LEGENDARY_ROSTER) do
    if Events.progress(kind, second) then raw = raw + 1 end
  end
  local selected = Events.activeLegendary(second)
  if raw == 0 then eq(selected, nil, "no legend outside every window") end
  if raw > 1 then overlapClock = second; break end
end
check(overlapClock ~= nil, "long-range QA reaches a legendary overlap")

for _, kind in ipairs({
    "rainbow", "pidgeot", "hooh", "articuno", "zapdos", "moltres",
}) do
  local clock = Events.qaClock(kind, 0.5)
  check(type(clock) == "number", kind .. " has a QA clock")
  check(math.abs(Events.progress(kind, clock) - 0.5) < 1e-8,
        kind .. " QA clock uses a real production phase")
  local azimuth = Events.anchor(kind, clock)
  local northDelta = math.abs((azimuth - math.pi + math.pi)
                              % (math.pi * 2) - math.pi)
  check(northDelta < 0.03, kind .. " QA clock stays near north")
end
eq(Events.qaClock("missing", 0.5), nil, "unknown QA event fails closed")
for _, species in ipairs(Events.ORDINARY_ROSTER) do
  local clock = Events.qaClockForSpecies(species, 0.5)
  check(type(clock) == "number", species .. " has an exact QA clock")
  check(math.abs(Events.progress("pidgeot", clock) - 0.5) < 1e-8,
        species .. " QA clock uses the real ordinary flight window")
  eq(Events.ordinaryPlan(clock).species, species,
     species .. " QA clock selects the requested production species")
  eq(Events.activeLegendary(clock), nil,
     species .. " QA clock never loses to a legendary overlap")
end
eq(Events.qaClockForSpecies("missing", 0.5), nil,
   "unknown QA species fails closed")

-- The public art contract fixes every required filename and exact atlas grid.
local expectedAssets = {
  rainbow = { "assets/sky/rainbow.png", 512, 256, 1, 1 },
  flock = { "assets/sky/bird_flock.png", 512, 256, 1, 1 },
  spearowFlock = { "assets/sky/spearow_flock.png", 512, 256, 1, 1 },
  murkrowFlock = { "assets/sky/murkrow_flock.png", 512, 256, 1, 1 },
  farfetchd = { "assets/sky/farfetchd.png", 512, 256, 1, 1 },
  hooh = { "assets/sky/hooh.png", 512, 256, 1, 1 },
  articuno = { "assets/sky/articuno.png", 512, 256, 1, 1 },
  zapdos = { "assets/sky/zapdos.png", 512, 256, 1, 1 },
  moltres = { "assets/sky/moltres.png", 512, 256, 1, 1 },
}
for name, expected in pairs(expectedAssets) do
  local spec = Events.ASSET_SPECS[name]
  eq(spec.path, expected[1], name .. " asset path is stable")
  eq(spec.width, expected[2], name .. " atlas width is exact")
  eq(spec.height, expected[3], name .. " atlas height is exact")
  eq(spec.columns, expected[4], name .. " column count is exact")
  eq(spec.rows, expected[5], name .. " row count is exact")
  eq(Events.assetStatus(name), "cold", name .. " starts unloaded")
end
eq(Events.ASSET_SPECS.hooh.includesRainbowWake, true,
   "Ho-Oh's wake is authored into its one-draw image")
eq(Events.assetStatus("missing"), "unknown", "unknown asset status fails closed")

-- Device-quality modes also gate staging/memory, not only draw calls.  A cold
-- OFF session must not decode 4.5 MiB of flyer/rainbow textures in the
-- background; the two partial modes touch only their own allowlist.
Events.setting:sync("off")
local modeReady, modeAttempted = Events.prewarm()
eq(modeReady, 0, "OFF exposes no active ready atlas")
eq(modeAttempted, 0, "OFF performs no atlas decode")
eq(#calls.newImage, 0, "OFF stays zero-allocation while cold")
Events.setting:sync("rainbow")
modeReady, modeAttempted = Events.prewarm()
eq(modeReady, 1, "RAINBOW prewarms its one authored arc")
eq(modeAttempted, 1, "RAINBOW attempts exactly one atlas")
eq(Events.assetStatus("flock"), "cold",
   "RAINBOW does not stage flyer art")
Events.invalidateAssets()
Events.setting:sync("flyers")
modeReady, modeAttempted = Events.prewarm(1)
eq(modeReady, 1, "FLYERS stages its first flyer atlas")
eq(modeAttempted, 1, "FLYERS attempts one atlas per requested slice")
eq(Events.assetStatus("rainbow"), "cold",
   "FLYERS does not stage rainbow art")
Events.invalidateAssets()
calls.newImage, calls.newQuad, calls.images = {}, {}, {}
Events.setting:sync("full")

-- paint() never loads on first use: an early rare window skips cleanly instead
-- of hitching the render thread.
local rainbowClock = Events.qaClock("rainbow", 0.5)
resetRender()
eq(Events.paint(centredContext(rainbowClock), "back"), 0,
   "cold rainbow skips without a procedural fallback")
eq(totalReads(), 0, "cold paint performs no file IO")
eq(#calls.newImage, 0, "cold paint performs no image decode")
eq(#calls.project, 0, "cold asset is rejected before projection")
eq(#calls.draw, 0, "cold asset costs no draw")

-- update() stages one atlas per frame; loading screens can prewarm the rest.
local ready, attempted = Events.prewarm(1)
eq(ready, 1, "first staged prewarm makes one atlas ready")
eq(attempted, 1, "first staged prewarm attempts one atlas")
eq(Events.assetStatus("rainbow"), "ready", "rainbow is first in prewarm order")
Events.update(0)
eq(Events.assetStatus("flock"), "ready", "update stages the next atlas")
ready, attempted = Events.prewarm()
eq(ready, 9, "explicit prewarm completes the approved sky roster")
eq(attempted, 7, "explicit prewarm only touches remaining atlases")
eq(totalReads(), 0, "atlas loader never copies bytes through the mod API")
eq(#calls.newImage, 9, "each atlas is decoded exactly once")
eq(#calls.newQuad, 9, "single-frame Quads are prebuilt outside paint")
for _, imageCall in ipairs(calls.newImage) do
  eq(imageCall.settings.mipmaps, false, "image decode disables mipmaps")
  eq(imageCall.settings.linear, false, "image decode disables linear sampling")
end
for _, image in ipairs(calls.images) do
  eq(image.filter[1], "nearest", image.name .. " min filter is nearest")
  eq(image.filter[2], "nearest", image.name .. " mag filter is nearest")
  eq(image.mipmapFilterCalled, true, image.name .. " explicitly disables mipmap filtering")
end
local readsAfterWarm = totalReads()
ready, attempted = Events.prewarm()
eq(ready, 9, "repeated prewarm retains all atlases")
eq(attempted, 0, "repeated prewarm does no work")
eq(totalReads(), readsAfterWarm, "ready atlases are never reread")

-- Each visible object/formation is exactly one textured draw.
resetRender()
eq(Events.paint(centredContext(rainbowClock), "back"), 1,
   "rainbow is one billboard draw")
eq(#calls.draw, 1, "rainbow issues exactly one draw call")
eq(calls.draw[1].image.name, "rainbow.png", "rainbow uses its authored PNG")
eq(calls.rectangle, 0, "rainbow has no procedural rectangles")
eq(Events.MAX_DRAWS.rainbow, 1, "rainbow budget is one draw")
eq(math.abs(calls.draw[1].sx), 112 / 512,
   "rainbow is 56 world cells wide at the 2x QA canvas scale")
eq(math.abs(calls.draw[1].sy), 56 / 256,
   "rainbow retains its authored 2:1 aspect ratio")

local flockClock, flockPlan = ordinaryClock("pidgey", 4)
check(flockClock ~= nil, "production schedule reaches a four-Pidgey flock")
resetRender()
eq(Events.paint(centredContext(flockClock, 0.5), "front"), 1,
   "four-bird formation is one atlas draw")
eq(#calls.draw, 1, "formation never becomes four object draws")
eq(calls.draw[1].image.name, "bird_flock.png", "formation uses flock atlas")
eq(calls.draw[1].quad.width, 512, "flock uses its complete single frame")
eq(calls.draw[1].quad.x, 0, "flock has no hidden atlas column")
eq(calls.draw[1].quad.y, 0, "flock has no hidden atlas row")
eq(calls.rectangle, 0, "flock has no procedural rectangles")
eq(Events.MAX_DRAWS.ordinary, 1, "ordinary budget is one draw")

local expectedOrdinaryAsset = {
  pidgey = "bird_flock.png", pidgeotto = "bird_flock.png",
  pidgeot = "bird_flock.png", spearow = "spearow_flock.png",
  fearow = "spearow_flock.png", farfetchd = "farfetchd.png",
  murkrow = "murkrow_flock.png",
}
for _, species in ipairs(Events.ORDINARY_ROSTER) do
  local clock, plan = ordinaryClock(species)
  check(clock ~= nil, species .. " has a non-overlapped production window")
  local art = Events.ORDINARY_ART[species]
  local light = art.maxLight < 0.7 and math.min(0.4, art.maxLight) or 0.5
  resetRender()
  eq(Events.paint(centredContext(clock, light), "front"), 1,
     species .. " renders as one complete formation")
  eq(#calls.draw, 1, species .. " never expands into per-bird draws")
  eq(calls.draw[1].image.name, expectedOrdinaryAsset[species],
     species .. " selects its authored PNG")
  local expectedWidth, expectedHeight = Events.displaySizeCells(
    species, plan.count, plan.occurrence)
  check(math.abs(calls.draw[1].sx) == expectedWidth * 2 / 512
        and math.abs(calls.draw[1].sy) == expectedHeight * 2 / 256,
        species .. " draw scale is derived from height and distance")
end

resetRender()
Events.paint(centredContext(flockClock, 0.5), "front")
local firstFlockPoints = calls.project
resetRender()
Events.paint(centredContext(flockClock, 0.5), "front")
eq(#calls.project, 1, "whole flock has one world anchor")
eq(calls.project[1][1], firstFlockPoints[1][1], "flock azimuth replays exactly")
eq(calls.project[1][2], firstFlockPoints[1][2], "flock elevation replays exactly")

local directionScale = {}
for occurrence = 1, 96 do
  local clock = Events.eventClock("pidgeot", 0.5, occurrence)
  local plan = Events.ordinaryPlan(clock)
  if not Events.activeLegendary(clock) and plan.species ~= "murkrow" then
    resetRender()
    Events.paint(centredContext(clock, 0.5), "front")
    if #calls.draw == 1 then
      directionScale[occurrence % 2] = calls.draw[1].sx
    end
  end
  if directionScale[0] and directionScale[1] then break end
end
check(directionScale[0] * directionScale[1] < 0,
      "billboard mirrors once when world-space flight direction reverses")

local legendClock = {}
for _, kind in ipairs(Events.LEGENDARY_ROSTER) do
  legendClock[kind] = Events.qaClock(kind, 0.10)
  resetRender()
  eq(Events.paint(centredContext(legendClock[kind], 0.5), "front"), 1,
     kind .. " is one billboard draw")
  eq(#calls.draw, 1, kind .. " issues one draw call")
  eq(calls.draw[1].image.name, kind .. ".png", kind .. " uses its own atlas")
  eq(calls.draw[1].quad.x, 0, kind .. " uses its complete single frame")
end
eq(Events.MAX_DRAWS.legendary, 1, "legendary budget is one draw")

for _, progress in ipairs({ 0.10, 0.20, 0.30 }) do
  local clock = Events.qaClock("hooh", progress)
  resetRender()
  Events.paint(centredContext(clock, 0.5), "front")
  eq(calls.draw[1].quad.x, 0,
     "Ho-Oh animation keeps one authored frame at every flight phase")
end

resetRender()
eq(Events.paint(centredContext(overlapClock, 0.5), "front"), 1,
   "overlapping legendary schedules still draw one stable winner")
eq(#calls.draw, 1, "legendary overlap cannot stack billboard draws")

-- Layer, weather, daylight and ecology gates happen before a draw.
resetRender()
eq(Events.paint(centredContext(rainbowClock), "front"), 0,
   "front layer excludes distant rainbow")
eq(#calls.draw, 0, "excluded layer has no draw")
resetRender()
eq(Events.paint(centredContext(legendClock.hooh, 0.5), "back"), 0,
   "back layer excludes every flyer")

for _, weather in ipairs({ "rain", "snow", "fog", "storm" }) do
  local obscured = centredContext(legendClock.hooh, 0.5)
  obscured.weather = weather
  resetRender()
  eq(Events.paint(obscured, "front"), 0, weather .. " suppresses flyers")
  eq(#calls.draw, 0, weather .. " suppression costs no draw")
end
for _, weather in ipairs({ "rain", "snow", "fog", "storm" }) do
  local obscured = centredContext(flockClock, 0.5)
  obscured.weather = weather
  resetRender()
  eq(Events.paint(obscured, "front"), 0,
     weather .. " suppresses ordinary formations")
  eq(#calls.draw, 0, weather .. " ordinary suppression costs no draw")
end
for _, weather in ipairs({ "snow", "fog", "storm" }) do
  local obscured = centredContext(rainbowClock)
  obscured.weather = weather
  resetRender()
  eq(Events.paint(obscured, "back"), 0, weather .. " suppresses rainbow")
end
resetRender()
eq(Events.paint(centredContext(legendClock.hooh, 0), "front"), 0,
   "Ho-Oh does not cross a fully dark sky")
resetRender()
eq(Events.paint(centredContext(murkrowClock, 1), "front"), 0,
   "Murkrow does not cross full daylight")
resetRender()
eq(Events.paint(centredContext(murkrowClock, 0.2), "front"), 1,
   "Murkrow can cross dusk/night in one draw")

Events.setting:sync("off")
resetRender()
local readsBeforeOff = totalReads()
eq(Events.paint(centredContext(legendClock.hooh, 0.5), "front"), 0,
   "OFF removes every billboard")
eq(#calls.project, 0, "OFF is a zero-projection path")
eq(#calls.draw, 0, "OFF is a zero-draw path")
eq(totalReads(), readsBeforeOff, "OFF paint performs no IO")
resetRender()
eq(Events.paint(centredContext(flockClock, 0.5), "front"), 0,
   "OFF removes ordinary formations too")
eq(#calls.draw, 0, "OFF ordinary path remains zero-draw")
Events.setting:sync("full")
resetRender()
eq(Events.paint(centredContext(30), "front"), 0, "idle frame has no event")
eq(#calls.draw, 0, "idle frame remains zero draw")

-- Missing and malformed assets fail closed and remain cached, so an event can
-- never retry disk IO in paint or every subsequent frame.
local releasedBefore = 0
for _, image in ipairs(calls.images) do if image.released then releasedBefore = releasedBefore + 1 end end
Events.invalidateAssets()
local releasedAfter = 0
for _, image in ipairs(calls.images) do if image.released then releasedAfter = releasedAfter + 1 end end
eq(releasedAfter - releasedBefore, 9, "invalidating releases every GPU image")
missing["hooh.png"] = true
Events.prewarm()
local state, reason = Events.assetStatus("hooh")
eq(state, "missing", "missing Ho-Oh is remembered")
eq(reason, "decode", "missing asset reports a stable decode reason")
local hoohDecodes = #calls.newImage
resetRender()
eq(Events.paint(centredContext(legendClock.hooh, 0.5), "front"), 0,
   "missing Ho-Oh skips without placeholder geometry")
eq(#calls.project, 0, "missing asset is rejected before projection")
eq(#calls.draw, 0, "missing asset costs no draw")
Events.prewarm()
eq(#calls.newImage, hoohDecodes, "missing asset is not retried every frame")
resetRender()
eq(Events.paint(centredContext(legendClock.articuno, 0.5), "front"), 1,
   "one missing atlas does not poison other legends")

missing["hooh.png"] = nil
Events.invalidateAssets()
missing["spearow_flock.png"] = true
Events.prewarm()
state, reason = Events.assetStatus("spearowFlock")
eq(state, "missing", "missing ordinary-family art is remembered")
eq(reason, "decode", "missing ordinary art reports a stable decode reason")
local spearowClock = ordinaryClock("spearow")
resetRender()
eq(Events.paint(centredContext(spearowClock, 0.5), "front"), 0,
   "missing Spearow family art fails closed")
eq(#calls.project, 0, "missing ordinary art is rejected before projection")
eq(#calls.draw, 0, "missing ordinary art has no rectangle fallback")
resetRender()
eq(Events.paint(centredContext(flockClock, 0.5), "front"), 1,
   "one missing ordinary family does not poison Pidgey")

missing["spearow_flock.png"] = nil
Events.invalidateAssets()
wrongDimensions["moltres.png"] = true
Events.prewarm()
state, reason = Events.assetStatus("moltres")
eq(state, "invalid", "wrong atlas dimensions fail closed")
eq(reason, "dimensions", "dimension mismatch has a diagnostic reason")
resetRender()
eq(Events.paint(centredContext(legendClock.moltres, 0.5), "front"), 0,
   "malformed Moltres atlas never reaches draw")
eq(#calls.draw, 0, "malformed atlas has no draw fallback")

wrongDimensions["moltres.png"] = nil
Events.invalidateAssets()
Events.prewarm()
eq(Events.assetStatus("moltres"), "ready", "fixed atlas reloads after invalidation")

-- Scheduler persistence and staged prewarming coexist without changing time.
local clockBefore = Events.clock
Events.update(-10)
eq(Events.clock, clockBefore, "negative dt cannot rewind rare windows")
Events.update(2.5)
eq(Events.clock, clockBefore + 2.5, "scheduler advances deterministically")

local saved = {}
V.mod.save = {
  set = function(_, key, value) saved[key] = value end,
  get = function(_, key) return saved[key] end,
}
Events.clock = 54321.25
Events.store()
Events.clock = 0
Events.restore()
eq(Events.clock, 54321.25, "rare cadence survives save reloads")
saved[Events.SAVE_KEY] = nil
Events.restore()
eq(Events.clock, Events.DEFAULT_CLOCK, "old saves start at quiet phase")

print("sky events image backend: ok")
