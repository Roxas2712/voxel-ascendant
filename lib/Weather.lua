-- Lightweight outdoor weather drawn over the finished voxel canvas.
--
-- No particle objects are allocated and nothing is simulated off-screen:
-- every drop/flakes' position is a deterministic function of a small clock.
-- That keeps the option cheap on iPhone and makes a resize immediately fill
-- the new frame instead of waiting for a particle system to repopulate it.

local V = ...

local ModSetting = V.require("ModSetting")
local CanvasPresentation = V.require("CanvasPresentation")
local DayNight = V.require("DayNight")
local SkyEvents = V.require("SkyEvents")
local PerformanceDiagnostics
pcall(function() PerformanceDiagnostics = V.require("PerformanceDiagnostics") end)

local Weather = { clock = 0 }

Weather.setting = ModSetting.new("weather", "WEATHER",
  { "clear", "auto", "rain", "snow", "fog", "storm", "heat", "rainbow" },
  { "CLEAR", "AUTO", "RAIN", "SNOW", "FOG", "STORM", "HEAT", "RAINBOW" })

-- AUTO advances one regional front every four minutes. The clock follows the
-- player across outdoor maps, so crossing a gate cannot reroll the weather.
-- The multiplier below remains coprime with AUTO_BUCKETS and therefore visits
-- the full deterministic distribution without math.random or an OS clock.
Weather.AUTO_SECONDS = 240
Weather.AUTO_BUCKETS = 64
-- Four fronts make a compressed 16-minute season. The resulting 64-minute
-- year does not phase-lock with the independent 20-minute day/night cycle.
Weather.SEASON_SECONDS = 960
Weather.SEASONS = { "normal", "heat", "normal", "snow" }

-- `visit` remains persisted for save/hot-reload compatibility, but AUTO no
-- longer consumes it. Map observation still owns outdoor transitions and the
-- existing post-rain rainbow handoff.
local director = {
  mapId = nil, outdoor = false, visit = 0,
  lastMode = nil, wetPending = false,
}

-- A forced storm remains mostly dark rain.  Its two very short flashes recur
-- slowly enough to read as weather rather than a screen effect.  These values
-- are public so the deterministic QA seam can find a flash without waiting in
-- real time.
Weather.LIGHTNING_SECONDS = 23
Weather.STORM_LEAF_SECONDS = 12
Weather.STORM_LEAF_FRACTION = .34
-- Sparse foreground drops are a separate, short lens/screen event rather
-- than a fourth permanent rain rail.  The pure window below makes the same
-- frame reproducible after resize, in battle and in headless QA.
Weather.SCREEN_DROP_SECONDS = 13
Weather.SCREEN_DROP_FRACTION = .18

local COLD = {
  INDIGO_PLATEAU = true, ROUTE_23 = true,
}

local SCENIC_OUTDOORS = {
  INDIGO_PLATEAU = true, ROUTE_23 = true, ROUTE_10 = true,
  ROUTE_9 = true, ROUTE_4 = true, ROUTE_3 = true,
  CINNABAR_ISLAND = true, VIRIDIAN_FOREST = true,
  SAFARI_ZONE_CENTER = true, SAFARI_ZONE_EAST = true,
  SAFARI_ZONE_NORTH = true, SAFARI_ZONE_WEST = true,
  VERMILION_DOCK = true, SS_ANNE_BOW = true,
}

local function defIsOutdoor(def)
  if def.outdoor ~= nil then return def.outdoor and true or false end
  return def.tileset == "OVERWORLD"
end

local function hashText(s)
  local h = 7
  for i = 1, #s do h = (h * 31 + s:byte(i)) % 65521 end
  return h
end

local function mapId(map)
  return tostring(map and (map.id or (map.def and map.def.id)) or "")
end

-- One small shared exception contract for source maps whose metadata says
-- "interior" even though the playable space is visibly outdoors. BattleScene
-- consumes this same predicate for the daylight rig; weather and battles can
-- therefore never disagree about Safari, the dock or the exposed ship bow.
-- Real rooms still require an ordinary outdoor definition or an explicit ID.
function Weather.isOutdoor(map)
  if not (map and map.def) then return false end
  return defIsOutdoor(map.def) or SCENIC_OUTDOORS[mapId(map)] == true
end

local function finite(value, fallback)
  if type(value) ~= "number" or value ~= value
      or value == math.huge or value == -math.huge then
    return fallback
  end
  return value
end

-- Deterministic clock control for save restoration and QA.  update() remains
-- the ordinary runtime path; neither entry point consults an OS clock.
function Weather.setClock(value)
  Weather.clock = finite(value, 0) % 65521
end

function Weather.update(dt, map)
  dt = finite(dt, 0)
  if dt > 0 then Weather.clock = (Weather.clock + dt) % 65521 end
  if map then return Weather.mode(map) end
  return "clear"
end

function Weather.heatAllowed()
  return not DayNight or type(DayNight.tod) ~= "function"
         or DayNight.tod() == "DAY"
end

-- Pure selection seam used by mode() and tests.  An explicit forced mode is
-- still refused indoors, and unknown/legacy values fail to CLEAR rather than
-- accidentally falling into a costly effect.
function Weather.seasonAt(clock)
  local slot = math.floor(finite(clock, Weather.clock)
                          / Weather.SEASON_SECONDS)
  return Weather.SEASONS[(slot % #Weather.SEASONS) + 1]
end

function Weather.modeAt(map, selected, clock, visit)
  local id = mapId(map)
  if not Weather.isOutdoor(map) then
    return "clear"
  end
  if selected == "off" then return "clear" end
  if selected ~= "auto" then
    if selected == "rain" or selected == "snow"
        or selected == "fog" or selected == "storm" then
      return selected
    end
    if selected == "heat" then
      return Weather.heatAllowed() and "heat" or "clear"
    end
    return "clear"
  end

  clock = finite(clock, Weather.clock)
  local period = math.floor(clock / Weather.AUTO_SECONDS)
  -- The active front belongs to the regional clock. Map identity may only
  -- tune how heavily a winter front settles below; it cannot reroll the base
  -- front while the player crosses between connected routes or towns.
  local roll = (23 + period * 17) % Weather.AUTO_BUCKETS
  local season = Weather.seasonAt(clock)

  -- Exactly one bucket in 64 is a storm. Snow and heat never interleave:
  -- the four-part season wheel always inserts a normal interval between
  -- them. Rain and calm remain the backbone in every part of the year.
  if roll == 0 then return "storm" end
  if roll <= 4 then return "fog" end
  if season == "snow" then
    if roll <= (COLD[id] and 38 or 30) then return "snow" end
    if roll <= (COLD[id] and 44 or 37) then return "rain" end
    return "clear"
  end
  if season == "heat" then
    if roll <= 14 then return "rain" end
    if roll <= 34 and Weather.heatAllowed() then return "heat" end
    return "clear"
  end
  if roll <= 22 then return "rain" end
  return "clear"
end

local function observeMap(map)
  local id, outdoor = mapId(map), Weather.isOutdoor(map)
  if id ~= director.mapId or outdoor ~= director.outdoor then
    if outdoor then
      director.visit = (director.visit * 37 + hashText(id) + 17)
                       % Weather.AUTO_BUCKETS
    end
    director.mapId, director.outdoor = id, outdoor
    director.lastMode = nil
  end
  return id, outdoor
end

local function noteResolved(id, mode)
  if not director.outdoor then return end
  if mode == "rain" or mode == "storm" then
    director.wetPending = true
  elseif mode == "clear" or mode == "heat" then
    if director.wetPending then
      SkyEvents.forceRainbow(id)
      director.wetPending = false
    end
  end
  director.lastMode = mode
end

function Weather.mode(map)
  local id, outdoor = observeMap(map)
  local selected = Weather.setting:get()
  if selected == "rainbow" then
    SkyEvents.setRainbowPreview(outdoor and id or nil)
    noteResolved(id, "clear")
    return "clear"
  end
  SkyEvents.setRainbowPreview(nil)
  local mode = Weather.modeAt(map, selected, Weather.clock, director.visit)
  noteResolved(id, mode)
  return mode
end

local skyProvider

-- Optional presentation-only bridge for a standalone weather owner. It can
-- recolour VASC's native sky without taking over VASC's particles or battle
-- rules. Returning nil leaves the ordinary VASC setting authoritative.
function Weather.setSkyProvider(provider)
  skyProvider = type(provider) == "function" and provider or nil
end

function Weather.skyState(map)
  if skyProvider and Weather.isOutdoor(map) then
    local ok, supplied = pcall(skyProvider, map)
    if ok then
      local config = type(supplied) == "table" and supplied or nil
      local mode = config and config.effect or supplied
      if mode == "off" or mode == "none" then return "clear" end
      if mode == "rainbow" then
        SkyEvents.setRainbowPreview(mapId(map))
        return "clear", false
      end
      if mode == "heat" and not Weather.heatAllowed() then
        return "clear", false
      end
      if mode == "rain" or mode == "snow" or mode == "fog"
          or mode == "storm" or mode == "heat" or mode == "clear" then
        return mode, not config or config.surfaces ~= false
      end
    end
  end
  return Weather.mode(map), true
end

function Weather.skyMode(map)
  return Weather.skyState(map)
end

-- Strength and occurrence key for a map's current lightning impulse.  This
-- is intentionally pure: visual QA can reproduce a frame exactly and the
-- optional thunder hook can be debounced without random state.
function Weather.lightningAt(clock, map)
  local id = mapId(map)
  local span = Weather.LIGHTNING_SECONDS
  local shifted = finite(clock, Weather.clock) + hashText(id) % span
  local occurrence = math.floor(shifted / span)
  local phase = shifted - occurrence * span
  local strength = 0
  if phase < 0.075 then
    strength = 1 - phase / 0.075
  elseif phase >= 0.135 and phase < 0.195 then
    strength = 0.58 * (1 - (phase - 0.135) / 0.060)
  end
  return strength, id .. ":" .. tostring(occurrence)
end

local thunderHook, lastThunder

-- Optional engine integration only.  A host that has an appropriate sample
-- may register a callback; without one storms remain completely visual.  A
-- broken callback is contained and cannot break the completed world canvas.
function Weather.setThunderHook(hook)
  thunderHook = type(hook) == "function" and hook or nil
  lastThunder = nil
end

-- A perspective band of independent drops. Earlier weather drew every drop
-- as the same block staircase, which made a handful of repeating pixel rails
-- slide across the screen. Varying speed, slant and length per drop produces
-- a rain field while three bounded bands retain the cheap deterministic path.
local function rainBand(g, w, h, step, count, phase,
                        speed, length, width, alpha, storm)
  if not g.line then return false end
  if g.setLineStyle then g.setLineStyle("smooth") end
  if g.setLineWidth then g.setLineWidth(width) end
  if storm then g.setColor(0.67, 0.78, 0.96, alpha)
  else g.setColor(0.78, 0.88, 1.0, alpha) end
  local tick = Weather.clock * speed
  for i = 1, count do
    local seed = (i * 37 + phase * 71) % 101
    local x = (i * (67 + phase * 13)
               + tick * (1.15 + (seed % 7) * .08)) % (w + 96) - 48
    local y = (i * (43 + phase * 9)
               + tick * (2.8 + (seed % 11) * .10)) % (h + 120) - 60
    local len = length * (.70 + (seed % 9) * .055)
    local slant = step * (.45 + phase * .22 + (seed % 5) * .11)
    g.line(x, y, x - slant, y + len)
  end
  return true
end

-- A few soft beads occasionally catch on the completed world canvas and run
-- down it for a moment.  They deliberately have no retained particles: the
-- active window, occurrence, position and trail length are pure functions of
-- the shared weather clock and map id.  Outside the window this is a strict
-- zero-draw path, so ordinary rain keeps its established 116/84 line budget.
function Weather.screenDropWindow(clock, map)
  local span = Weather.SCREEN_DROP_SECONDS
  local shifted = finite(clock, Weather.clock) + hashText(mapId(map)) % span
  local occurrence = math.floor(shifted / span)
  local phase = (shifted - occurrence * span) / span
  if phase >= Weather.SCREEN_DROP_FRACTION then return nil, occurrence end
  return phase / Weather.SCREEN_DROP_FRACTION, occurrence
end

local function paintScreenRain(g, w, h, cell, storm, battle, map)
  if not (g.line and g.ellipse) then return 0 end
  local progress, occurrence = Weather.screenDropWindow(Weather.clock, map)
  if progress == nil then return 0 end

  local step = math.max(1, cell)
  local count = battle and (storm and 3 or 2) or (storm and 7 or 5)
  local mapSeed = hashText(mapId(map)) + occurrence * 97
  local envelope = math.sin(math.pi * progress)
  envelope = math.sqrt(math.max(0, envelope))
  if g.setLineStyle then g.setLineStyle("smooth") end

  for i = 1, count do
    local seed = mapSeed + i * 43
    local lane = ((seed * 17) % 79) / 78
    local x = w * (.09 + lane * .82)
    local start = h * (.08 + ((seed * 29) % 47) / 100)
    local travel = h * (.055 + (seed % 5) * .012)
    local y = start + progress * travel
    local rx = step * (1.15 + (seed % 4) * .24)
    local ry = step * (1.90 + (seed % 5) * .31)
    local trail = step * (2.4 + progress * (3.2 + seed % 4))
    local alpha = envelope * (battle and .15 or .24)
                  * (storm and 1.18 or 1)

    -- A genuinely vertical, tapered run distinguishes these adhered drops
    -- from the slanted perspective rain behind them.
    if g.setLineWidth then g.setLineWidth(math.max(1, rx * .48)) end
    g.setColor(.70, .84, .96, alpha * .54)
    g.line(x, y - ry - trail, x, y - ry * .42)
    g.setColor(.82, .91, 1.0, alpha)
    g.ellipse("fill", x, y, rx, ry, 24)
    g.setColor(1, 1, 1, alpha * .55)
    g.ellipse("fill", x - rx * .28, y - ry * .30,
              math.max(.45, rx * .25), math.max(.45, ry * .18), 12)
  end
  return count
end

Weather._paintScreenRain = paintScreenRain -- deterministic focused QA seam

local function paintRain(g, w, h, cell, storm, battle, map)
  local step = math.max(1, cell)
  g.setColor(0.10, 0.18, 0.30,
             storm and (battle and .16 or .13) or (battle and .045 or .025))
  g.rectangle("fill", 0, 0, w, h)
  local near = battle and (storm and 28 or 22) or (storm and 40 or 32)
  local middle = battle and (storm and 40 or 34) or (storm and 56 or 46)
  local far = battle and 28 or 38
  if not rainBand(g, w, h, step, far, 1, 31, step * 2.0,
                  math.max(1, math.min(1.35, step * .20)), .14, storm) then
    g.setColor(.76, .86, 1, storm and .7 or .55)
    local tick = Weather.clock * (storm and 210 or 155)
    for i = 1, near + middle + far do
      local x = (i * 83 + tick * (1 + i % 3)) % (w + 24) - 12
      local y = (i * 47 + tick * (2 + i % 5)) % (h + 32) - 16
      g.rectangle("fill", x, y, math.max(1, step * .45),
                  step * (1.5 + i % 4 * .45))
    end
    paintScreenRain(g, w, h, step, storm, battle, map)
    return
  end
  rainBand(g, w, h, step, middle, 2, 45, step * 3.1,
           math.max(1, math.min(1.9, step * .28)),
           storm and .32 or .23, storm)
  rainBand(g, w, h, step, near, 3, 60, step * 4.5,
           math.max(1, math.min(2.6, step * .38)),
           storm and .44 or .31, storm)
  if g.ellipse then
    g.setColor(.80, .89, 1, storm and .22 or .14)
    local tick = Weather.clock * (storm and 7.5 or 5.5)
    for i = 1, (battle and 7 or 10) do
      local phase = (tick + i * .73) % 1
      if phase < .44 then
        local x = (i * 97 + math.floor(tick) * 31) % math.max(1, w)
        local y = h * (.70 + (i % 4) * .07)
        g.ellipse("line", x, y, step * (1 + phase * 5),
                  math.max(.5, step * (.25 + phase)), 18)
      end
    end
  end
  paintScreenRain(g, w, h, step, storm, battle, map)
end

-- Brief leaf gusts keep STORM from reading as merely denser rain. Positions
-- are deterministic functions of the weather clock, so resize/reload cannot
-- pop a particle system or allocate per-frame objects. For most of each
-- twelve-second cycle no leaves are drawn at all.
function Weather.stormLeafGust(clock)
  local phase = (finite(clock, Weather.clock) % Weather.STORM_LEAF_SECONDS)
                / Weather.STORM_LEAF_SECONDS
  if phase >= Weather.STORM_LEAF_FRACTION then return nil end
  return phase / Weather.STORM_LEAF_FRACTION
end

local STORM_LEAF_COLORS = {
  { .34, .48, .15, .80 }, { .48, .60, .19, .84 },
  { .58, .42, .12, .78 }, { .72, .50, .14, .74 },
}

local function paintStormLeaves(g, w, h, cell, battle)
  local gust = Weather.stormLeafGust(Weather.clock)
  if not gust then return 0 end
  local step = math.max(1, cell)
  local count = battle and 4 or 7
  local drawn = 0
  for i = 1, count do
    local seed = i * 43 + 17
    local p = (gust + i * .137) % 1
    local x = w + step * 8 - p * (w + step * 18)
    local y = h * (.12 + (seed % 67) / 100)
      + math.sin(Weather.clock * 4.2 + seed) * step * 5
    local angle = -.42 + math.sin(Weather.clock * 6.1 + seed * .31) * .82
    local length = step * (1.65 + (seed % 4) * .28)
    local width = step * (.55 + (seed % 3) * .14)
    local dx, dy = math.cos(angle) * length, math.sin(angle) * length
    local px, py = -math.sin(angle) * width, math.cos(angle) * width
    local leaf = STORM_LEAF_COLORS[(i - 1) % #STORM_LEAF_COLORS + 1]
    g.setColor(leaf[1], leaf[2], leaf[3], leaf[4])
    if g.polygon then
      g.polygon("fill",
        x - dx, y - dy, x + px, y + py,
        x + dx, y + dy, x - px, y - py)
    elseif g.ellipse then
      g.ellipse("fill", x, y, length, width, 8)
    else
      g.rectangle("fill", x - width, y - width, width * 2, width * 2)
    end
    drawn = drawn + 1
  end
  return drawn
end

local function paintSnow(g, w, h, cell)
  local step = math.max(1, cell)
  local tick = Weather.clock
  g.setColor(0.82, 0.90, 1.0, 0.055)
  g.rectangle("fill", 0, 0, w, h)
  for band = 1, 3 do
    local count = ({ 18, 16, 12 })[band]
    g.setColor(.96, .98, 1, ({ .34, .53, .72 })[band])
    for i = 1, count do
      local seed = i * 29 + band * 47
      local drift = math.sin(tick * (.48 + band * .27) + seed * .13)
                    * step * (2 + band * 2.2)
      local x = (seed * 3 + drift + tick * (2 + band * 2.4)) % (w + 36) - 18
      local y = (seed * 5 + tick * (5 + band * 4 + seed % 4))
                % (h + 36) - 18
      local radius = step * (.22 + band * .18 + (seed % 5) * .045)
      if g.circle then g.circle("fill", x, y, math.max(.65, radius))
      else g.rectangle("fill", x, y, math.max(1, radius),
                       math.max(1, radius)) end
    end
  end
end

local function paintBattleSnow(g, w, h, cell)
  paintSnow(g, w, h, cell)
  if not g.line then return end
  local step, tick = math.max(1, cell), Weather.clock
  g.setColor(1, 1, 1, .42)
  if g.setLineWidth then g.setLineWidth(1) end
  for i = 1, 5 do
    local x = (i * 71 + tick * (4 + i)) % (w + 20) - 10
    local y = (i * 53 + tick * (11 + i)) % (h + 20) - 10
    local radius = math.max(1.5, step * .8)
    g.line(x - radius, y, x + radius, y)
    g.line(x, y - radius, x, y + radius)
  end
end

local function fogRibbon(g, x, y, rx, ry, seed, tick)
  if not g.polygon then
    if g.ellipse then g.ellipse("fill", x, y, rx, ry, 40)
    else g.rectangle("fill", x - rx, y - ry, rx * 2, ry * 2) end
    return
  end
  local points, segments = {}, 14
  for j = 0, segments do
    local p = j / segments
    local edge = math.sin(p * math.pi)
    local wobble = math.sin(p * math.pi * 3 + seed * .41 + tick * .08)
      + math.sin(p * math.pi * 7 - seed * .19) * .30
    points[#points + 1] = x - rx + p * rx * 2
    points[#points + 1] = y - ry * (.25 + edge * (.58 + wobble * .12))
  end
  for j = segments, 0, -1 do
    local p = j / segments
    local edge = math.sin(p * math.pi)
    local wobble = math.sin(p * math.pi * 4 - seed * .27 - tick * .06)
      + math.sin(p * math.pi * 9 + seed * .13) * .24
    points[#points + 1] = x - rx + p * rx * 2
    points[#points + 1] = y + ry * (.22 + edge * (.50 + wobble * .10))
  end
  g.polygon("fill", points)
end

-- A small fixed number of broad, pixel-snapped layers.  Unlike a particle
-- system this remains O(1) at every resolution and allocates no per-frame
-- objects; the foreground stays readable while the horizon visibly hazes.
local function paintFog(g, w, h, cell)
  local step = math.max(1, cell)
  local tick = Weather.clock
  local surge = math.max(0, math.min(1,
    (math.sin(tick * .17 + 1.4) - .36) / .64))
  surge = surge * surge * (3 - 2 * surge)
  g.setColor(0.76, 0.82, 0.84, 0.095 + surge * .20)
  g.rectangle("fill", 0, 0, w, h)
  for i = 1, 8 do
    local rx = w * (.18 + (i % 4) * .055)
    local ry = h * (.035 + (i % 3) * .016)
    local travel = w + rx * 2
    local x = (i * 137 + tick * (2.2 + i % 3)) % travel - rx
    local y = h * (.24 + i * .065)
              + math.sin(tick * .13 + i * 1.6) * step * 2.5
    g.setColor(.86, .90, .91,
               .045 + (i % 3) * .014 + surge * .035)
    fogRibbon(g, x, y, rx, ry, i, tick)
  end
  -- At the crest a bank hides almost the complete scene. A compact stencil
  -- pocket keeps the centred player readable; drivers without stencil support
  -- retain the denser veil and never lose the weather pass.
  if surge > .08 and g.stencil and g.setStencilTest and g.ellipse then
    local ok = pcall(function()
      g.stencil(function()
        g.ellipse("fill", w * .5, h * .56,
                  w * (.055 + (1 - surge) * .035),
                  h * (.09 + (1 - surge) * .05), 32)
      end, "replace", 1)
      g.setStencilTest("less", 1)
      g.setColor(.79, .82, .82, surge * .37)
      g.rectangle("fill", 0, 0, w, h)
      g.setStencilTest()
    end)
    if not ok then pcall(g.setStencilTest) end
  end
end

local function paintBattleFog(g, w, h, cell)
  local step, tick = math.max(1, cell), Weather.clock
  g.setColor(0.77, 0.84, 0.86, 0.10)
  g.rectangle("fill", 0, 0, w, h)
  for i = 1, 6 do
    local rx = w * (.25 + (i % 3) * .08)
    local ry = h * (.055 + (i % 2) * .018)
    local x = ((i * 173 + tick * (5 + i)) % (w + rx * 2)) - rx
    local y = h * (.35 + i * .075)
              + math.sin(tick * .16 + i * 1.4) * step * 3
    g.setColor(0.88, 0.92, 0.92, .055 + (i % 3) * .012)
    if g.ellipse then g.ellipse("fill", x, y, rx, ry, 40)
    else g.rectangle("fill", x - rx, y - ry, rx * 2, ry * 2) end
  end
end

local function paintHeat(g, w, h, battle)
  -- Warm additive-looking veil: enough to bloom pale surfaces and push the
  -- whole daylight rig toward red without flattening sprite or terrain detail.
  g.setColor(1.0, 0.34, 0.18, battle and .075 or .095)
  g.rectangle("fill", 0, 0, w, h)
  g.setColor(1.0, 0.72, 0.52, battle and .028 or .038)
  g.rectangle("fill", 0, 0, w, h)
end

local PRISM_COLORS = {
  { 1.00, .18, .24 }, { 1.00, .48, .16 }, { 1.00, .84, .20 },
  { .32, 1.00, .48 }, { .20, .72, 1.00 }, { .38, .34, 1.00 },
  { .78, .28, 1.00 },
}

local PRISM_ANCHORS = {
  { .18, .20, .070 }, { .84, .18, .055 },
  { .76, .55, .082 }, { .28, .64, .060 },
}

local function paintRainbowReflections(g, w, h, progress, map)
  -- These are prismatic reflections rather than conventional round lens
  -- flares: mirrored translucent wedges split the rainbow colours around
  -- several slowly rotating centres. Their map-seeded placement makes each
  -- location throw the light elsewhere, while their gentle drift prevents a
  -- fixed UI-like stamp. The real HUD is composited after this world canvas.
  local pulse = .80 + math.sin(Weather.clock * .55) * .20
  local fade = math.min(1, math.max(0, progress or .5) * 5,
                        math.max(0, 1 - (progress or .5)) * 5)
  local alpha = pulse * fade
  if alpha <= 0 then return end
  local seed = hashText(mapId(map))
  if g.setBlendMode then pcall(g.setBlendMode, "add", "alphamultiply") end
  for index, anchor in ipairs(PRISM_ANCHORS) do
    local jitterX = (((seed + index * 43) % 17) - 8) * .004
    local jitterY = (((seed + index * 29) % 13) - 6) * .003
    local cx = w * (anchor[1] + jitterX
               + math.sin(Weather.clock * (.035 + index * .004) + index)
                 * .018)
    local cy = h * (anchor[2] + jitterY
               + math.cos(Weather.clock * (.027 + index * .003) + index * 2)
                 * .015)
    local radius = math.max(3, math.min(w, h) * anchor[3])
    local spin = Weather.clock * (.11 + index * .013) + seed * .017
    for spoke = 0, 6 do
      local color = PRISM_COLORS[((spoke + index * 2) % #PRISM_COLORS) + 1]
      local angle = spin + spoke * math.pi * 2 / 7
      local mirror = angle + math.pi
      local inner = radius * (.10 + (spoke % 2) * .06)
      local outer = radius * (.78 + (spoke % 3) * .13)
      local spread = .19 + (spoke % 2) * .055
      g.setColor(color[1], color[2], color[3],
                 alpha * (.075 + (spoke % 3) * .018))
      if g.polygon then
        -- Two opposed shards per colour make the recognisable mirrored
        -- kaleidoscope rather than a wheel of simple rays.
        g.polygon("fill",
          cx + math.cos(angle - spread) * inner,
          cy + math.sin(angle - spread) * inner,
          cx + math.cos(angle) * outer,
          cy + math.sin(angle) * outer,
          cx + math.cos(angle + spread) * inner,
          cy + math.sin(angle + spread) * inner)
        g.polygon("fill",
          cx + math.cos(mirror - spread) * inner,
          cy + math.sin(mirror - spread) * inner,
          cx + math.cos(mirror) * outer * .66,
          cy + math.sin(mirror) * outer * .66,
          cx + math.cos(mirror + spread) * inner,
          cy + math.sin(mirror + spread) * inner)
      else
        local sx, sy = cx + math.cos(angle) * outer,
                       cy + math.sin(angle) * outer
        g.rectangle("fill", sx, sy, math.max(1, radius * .22),
                    math.max(1, radius * .08))
      end
    end
    if g.line then
      g.setColor(1, 1, 1, alpha * .16)
      g.line(cx - radius * .22, cy, cx + radius * .22, cy)
      g.line(cx, cy - radius * .22, cx, cy + radius * .22)
    end
  end
  if g.setBlendMode then pcall(g.setBlendMode, "alpha") end
end

local function paintLightning(g, w, h, map, cell, strength, occurrence)
  if strength <= 0 then return end
  g.setColor(0.84, 0.90, 1.0, 0.16 + strength * 0.42)
  g.rectangle("fill", 0, 0, w, h)
  if strength < 0.30 then return end

  -- A short blocky bolt near the sky.  Its path is fixed for an occurrence,
  -- so the second pulse illuminates the same bolt instead of teleporting it.
  local step = math.max(1, cell)
  local seed = hashText(mapId(map) .. ":" .. tostring(occurrence))
  local x = math.floor((w * (0.20 + (seed % 57) / 100)) / step) * step
  local y = math.floor((h * 0.06) / step) * step
  g.setColor(0.92, 0.95, 1.0, 0.46 + strength * 0.50)
  for i = 1, 8 do
    local direction = ((seed + i * 13) % 3) - 1
    x = x + direction * step
    g.rectangle("fill", x, y, step, step * 3)
    y = y + step * 3
  end
end


local function paintBattleLightning(g, w, h, map, cell, strength, occurrence)
  if strength <= 0 then return end
  g.setColor(0.84, 0.90, 1.0, 0.10 + strength * 0.28)
  g.rectangle("fill", 0, 0, w, h)
  if strength < 0.38 or not g.line then return end
  local step = math.max(1, cell)
  local seed = hashText(mapId(map) .. ":" .. tostring(occurrence))
  local x = w * (0.22 + (seed % 47) / 100)
  local y = h * .04
  if g.setLineStyle then g.setLineStyle("smooth") end
  if g.setLineWidth then g.setLineWidth(math.max(1, step * .65)) end
  g.setColor(0.94, 0.97, 1.0, 0.40 + strength * .42)
  for i = 1, 6 do
    local nx = x + ((((seed + i * 13) % 5) - 2) * step * 1.4)
    local ny = y + h * .035
    g.line(x, y, nx, ny)
    x, y = nx, ny
  end
end

-- Paint into and return the canvas supplied by VoxelScene. Failure is a
-- visual fallback only: the already-finished world canvas remains valid.
local function apply(canvas, w, h, map, cell, resolvedMode, battle)
  local mode = resolvedMode or Weather.mode(map)
  local rainbow = not battle and SkyEvents.rainbowProgress(mapId(map)) or nil
  if not canvas then return canvas, false end
  if (mode == "clear" or mode == "off") and not rainbow then
    return canvas, true
  end
  if mode ~= "clear" and mode ~= "off" and mode ~= "rain"
      and mode ~= "snow" and mode ~= "fog"
      and mode ~= "storm" and mode ~= "heat" then return canvas, false end
  local g = love.graphics
  if not (g and g.setCanvas and g.rectangle) then return canvas, false end
  local flash, occurrence = 0, nil
  if mode == "storm" then
    flash, occurrence = Weather.lightningAt(Weather.clock, map)
  end
  local pushed = false
  local ok = pcall(function()
    g.push("all")
    pushed = true
    g.origin()
    g.setCanvas(canvas)
    if CanvasPresentation and CanvasPresentation.begin2D then
      CanvasPresentation.begin2D(g, h)
    end
    if g.setShader then g.setShader() end
    if g.setDepthMode then g.setDepthMode("always", false) end
    if g.setBlendMode then g.setBlendMode("alpha") end
    cell = math.max(1, math.floor((cell or 1) + 0.5))
    if mode == "clear" or mode == "off" then
      -- The world-space arc is painted by SkyEvents behind the clouds.
    elseif mode == "rain" then
      paintRain(g, w, h, cell, false, battle, map)
    elseif mode == "snow" then
      if battle then paintBattleSnow(g, w, h, cell)
      else paintSnow(g, w, h, cell) end
    elseif mode == "fog" then
      if battle then paintBattleFog(g, w, h, cell)
      else paintFog(g, w, h, cell) end
    elseif mode == "heat" then
      paintHeat(g, w, h, battle)
    else
      if battle then
        paintRain(g, w, h, cell, true, true, map)
        paintStormLeaves(g, w, h, cell, true)
        paintBattleLightning(g, w, h, map, cell, flash, occurrence)
      else
        g.setColor(0.04, 0.07, 0.13, 0.36)
        g.rectangle("fill", 0, 0, w, h)
        paintRain(g, w, h, cell, true, false, map)
        paintStormLeaves(g, w, h, cell, false)
        paintLightning(g, w, h, map, cell, flash, occurrence)
      end
    end
    if rainbow and mode ~= "fog" and mode ~= "storm" then
      paintRainbowReflections(g, w, h, rainbow, map)
    end
    g.setCanvas()
    g.pop()
    pushed = false
  end)
  if not ok then
    pcall(g.setCanvas)
    if pushed then pcall(g.pop) end
  end
  if ok and mode == "storm" and flash > 0 and thunderHook
      and occurrence ~= lastThunder then
    lastThunder = occurrence
    pcall(thunderHook, map, flash, occurrence)
  end
  return canvas, ok
end


function Weather.apply(canvas, w, h, map, cell, resolvedMode)
  local mode = resolvedMode or Weather.mode(map)
  local changed = Weather._performanceMode ~= mode
  if changed and PerformanceDiagnostics
      and type(PerformanceDiagnostics.beginLoad) == "function" then
    PerformanceDiagnostics.beginLoad("weather", {
      mapId=map and map.id, source="gen1-weather-pass",
    })
  end
  local out, painted = apply(canvas, w, h, map, cell, mode, false)
  Weather._performanceMode = mode
  if PerformanceDiagnostics then
    if changed and type(PerformanceDiagnostics.endLoad) == "function" then
      PerformanceDiagnostics.endLoad("weather", {
        mapId=map and map.id, status=painted and "ready" or "failed",
      })
    end
    if type(PerformanceDiagnostics.reportWeather) == "function" then
      PerformanceDiagnostics.reportWeather({
        weatherCode=mode, visualActive=mode == "clear" or painted == true,
        mapId=map and map.id, source="gen1-weather-pass",
        generation=1, musicExpected=true, musicPolicy="optional-variant",
      })
    end
  end
  return out
end

function Weather.applyBattle(canvas, w, h, map, cell, resolvedMode)
  local mode = resolvedMode or Weather.mode(map)
  local out, painted = apply(canvas, w, h, map, cell, mode, true)
  if PerformanceDiagnostics
      and type(PerformanceDiagnostics.reportWeather) == "function" then
    PerformanceDiagnostics.reportWeather({
      weatherCode=mode, visualActive=mode == "clear" or painted == true,
      mapId=map and map.id, source="gen1-battle-weather-pass",
      generation=1, musicExpected=true, musicPolicy="optional-variant",
    })
  end
  return out
end

Weather.SAVE_KEY = "weatherClock"

function Weather.store()
  local saveApi = V.mod and V.mod.save
  if saveApi and saveApi.set then
    pcall(saveApi.set, saveApi, Weather.SAVE_KEY, Weather.clock)
  end
end

function Weather.restore()
  local saveApi = V.mod and V.mod.save
  local stored
  if saveApi and saveApi.get then
    local ok, got = pcall(saveApi.get, saveApi, Weather.SAVE_KEY)
    if ok then stored = got end
  end
  Weather.setClock(type(stored) == "number" and stored or 0)
  director.mapId, director.outdoor = nil, false
  director.visit, director.lastMode = 0, nil
  director.wetPending = false
  SkyEvents.setRainbowPreview(nil)
end

return Weather
