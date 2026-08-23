-- Lightweight outdoor weather drawn over the finished voxel canvas.
--
-- No particle objects are allocated and nothing is simulated off-screen:
-- every drop/flakes' position is a deterministic function of a small clock.
-- That keeps the option cheap on iPhone and makes a resize immediately fill
-- the new frame instead of waiting for a particle system to repopulate it.

local V = ...

local ModSetting = V.require("ModSetting")
local CanvasPresentation = V.require("CanvasPresentation")

local Weather = { clock = 0 }

Weather.setting = ModSetting.new("weather", "WEATHER",
  { "clear", "auto", "rain", "snow", "fog", "storm" },
  { "CLEAR", "AUTO", "RAIN", "SNOW", "FOG", "STORM" })

-- AUTO changes only at these boundaries.  The multiplier below is coprime
-- with AUTO_BUCKETS, so every map visits the complete weather distribution
-- before it repeats; it never depends on math.random, the wall clock or draw
-- frequency.  FOG and STORM deliberately occupy the two rarest buckets.
Weather.AUTO_SECONDS = 45
Weather.AUTO_BUCKETS = 32

-- A forced storm remains mostly dark rain.  Its two very short flashes recur
-- slowly enough to read as weather rather than a screen effect.  These values
-- are public so the deterministic QA seam can find a flash without waiting in
-- real time.
Weather.LIGHTNING_SECONDS = 23

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

function Weather.update(dt)
  dt = finite(dt, 0)
  if dt > 0 then Weather.clock = (Weather.clock + dt) % 65521 end
end

-- Pure selection seam used by mode() and tests.  An explicit forced mode is
-- still refused indoors, and unknown/legacy values fail to CLEAR rather than
-- accidentally falling into a costly effect.
function Weather.modeAt(map, selected, clock)
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
    return "clear"
  end

  local period = math.floor(finite(clock, Weather.clock)
                            / Weather.AUTO_SECONDS)
  local roll = (hashText(id) + period * 17) % Weather.AUTO_BUCKETS

  -- One thunderstorm and two fog spells per complete 32-spell sequence.
  -- Cold routes retain their stronger snow bias; ordinary rain remains much
  -- more common than either of the new atmospheric modes.
  if roll == 0 then return "storm" end
  if roll <= 2 then return "fog" end
  if COLD[id] and roll <= 10 then return "snow" end
  if (not COLD[id]) and roll <= 8 then return "rain" end
  if COLD[id] and roll <= 16 then return "rain" end
  return "clear"
end

function Weather.mode(map)
  return Weather.modeAt(map, Weather.setting:get(), Weather.clock)
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

local function paintRain(g, w, h, cell, storm)
  local step = math.max(1, cell)
  local tick = math.floor(Weather.clock * (storm and 250 or 180))
  local count = storm and 92 or 72
  local tail = storm and 5 or 3
  if storm then g.setColor(0.64, 0.76, 0.96, 0.82)
  else g.setColor(0.72, 0.84, 1.0, 0.72) end
  for i = 1, count do
    local x = (i * 97 + tick * (storm and 3 or 2)) % (w + 32) - 16
    local y = (i * 53 + tick * (storm and 7 or 5)) % (h + 64) - 32
    for p = 0, tail do
      g.rectangle("fill", x - p * step, y + p * step,
                  step, math.max(1, step))
    end
  end
end

-- Battles use a composed, painterly weather layer rather than the overworld's
-- deliberately chunky voxel staircase. Three restrained depth bands read like
-- a battle effect without hiding the authored scenery or either battler.
local function battleRainBand(g, w, h, step, count, phase,
                              speed, length, width, alpha)
  if not g.line then return false end
  if g.setLineStyle then g.setLineStyle("smooth") end
  if g.setLineWidth then g.setLineWidth(width) end
  g.setColor(0.76, 0.86, 1.0, alpha)
  local tick = Weather.clock * speed
  for i = 1, count do
    local x = (i * (73 + phase * 11) + tick * (1.6 + phase * .2))
              % (w + 80) - 40
    local y = (i * (41 + phase * 7) + tick * (3.6 + phase * .35))
              % (h + 100) - 50
    local len = length * (0.82 + (i % 5) * .045)
    g.line(x, y, x - step * (1.2 + phase * .35), y + len)
  end
  return true
end

local function paintBattleRain(g, w, h, cell, storm)
  local step = math.max(1, cell)
  -- A cool atmospheric grade replaces the old opaque storm blanket.
  g.setColor(0.10, 0.18, 0.30, storm and 0.16 or 0.045)
  g.rectangle("fill", 0, 0, w, h)
  if not battleRainBand(g, w, h, step, 30, 1, 38,
                        step * 2.0,
                        math.max(1, math.min(1.5, step * .22)), .16) then
    -- Old/minimal LOVE stubs fall back safely to the established primitives.
    paintRain(g, w, h, step, storm)
    return
  end
  battleRainBand(g, w, h, step, storm and 44 or 38, 2, 50,
                 step * 3.2,
                 math.max(1, math.min(2.1, step * .30)),
                 storm and .34 or .24)
  battleRainBand(g, w, h, step, storm and 26 or 20, 3, 64,
                 step * 4.6,
                 math.max(1, math.min(2.8, step * .40)),
                 storm and .46 or .33)
end

local function paintSnow(g, w, h, cell)
  local step = math.max(1, cell)
  local tick = Weather.clock
  g.setColor(1, 1, 1, 0.84)
  for i = 1, 58 do
    local drift = math.sin(tick * 1.7 + i * 2.1) * 18
    local x = (i * 83 + drift + tick * 11) % (w + 24) - 12
    local y = (i * 47 + tick * (18 + i % 5)) % (h + 24) - 12
    local s = step * (i % 7 == 0 and 2 or 1)
    g.rectangle("fill", math.floor(x / step) * step,
                math.floor(y / step) * step, s, s)
  end
end

local function paintBattleSnow(g, w, h, cell)
  local step, tick = math.max(1, cell), Weather.clock
  g.setColor(0.82, 0.90, 1.0, 0.055)
  g.rectangle("fill", 0, 0, w, h)
  g.setColor(1, 1, 1, 0.66)
  for i = 1, 42 do
    local drift = math.sin(tick * 1.25 + i * 1.73) * step * 6
    local x = (i * 79 + drift + tick * (7 + i % 4)) % (w + 30) - 15
    local y = (i * 43 + tick * (12 + i % 6)) % (h + 30) - 15
    local radius = step * (i % 9 == 0 and .9 or .48)
    if g.circle then g.circle("fill", x, y, math.max(1, radius))
    else g.rectangle("fill", x, y, math.max(1, radius), math.max(1, radius)) end
  end
end

-- A small fixed number of broad, pixel-snapped layers.  Unlike a particle
-- system this remains O(1) at every resolution and allocates no per-frame
-- objects; the foreground stays readable while the horizon visibly hazes.
local function paintFog(g, w, h, cell)
  local step = math.max(1, cell)
  local tick = Weather.clock
  g.setColor(0.76, 0.82, 0.84, 0.13)
  g.rectangle("fill", 0, 0, w, h)
  for i = 1, 7 do
    local bandH = math.max(step * 2,
      math.floor((h * (0.035 + (i % 3) * 0.012)) / step) * step)
    local span = math.max(step * 12,
      math.floor((w * (0.46 + (i % 3) * 0.09)) / step) * step)
    local travel = w + span + step * 10
    local x = (i * 109 + tick * (5 + i % 4)) % travel - span
    local y = h * (0.18 + i * 0.075)
              + math.sin(tick * 0.19 + i * 1.7) * step * 3
    x = math.floor(x / step) * step
    y = math.floor(y / step) * step
    local x2 = ((x + travel * 0.53 + span) % travel) - span
    x2 = math.floor(x2 / step) * step
    g.setColor(0.84, 0.88, 0.88, 0.075 + (i % 3) * 0.018)
    g.rectangle("fill", x, y, span, bandH)
    -- A differently phased wisp prevents a single obvious moving rectangle.
    g.rectangle("fill", x2, y + step * (i % 2), span, bandH)
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
  if mode == "clear" or mode == "off" or not canvas then return canvas end
  if mode ~= "rain" and mode ~= "snow"
      and mode ~= "fog" and mode ~= "storm" then return canvas end
  local g = love.graphics
  if not (g and g.setCanvas and g.rectangle) then return canvas end
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
    if mode == "rain" then
      if battle then paintBattleRain(g, w, h, cell, false)
      else paintRain(g, w, h, cell, false) end
    elseif mode == "snow" then
      if battle then paintBattleSnow(g, w, h, cell)
      else paintSnow(g, w, h, cell) end
    elseif mode == "fog" then
      if battle then paintBattleFog(g, w, h, cell)
      else paintFog(g, w, h, cell) end
    else
      if battle then
        paintBattleRain(g, w, h, cell, true)
        paintBattleLightning(g, w, h, map, cell, flash, occurrence)
      else
        g.setColor(0.04, 0.07, 0.13, 0.36)
        g.rectangle("fill", 0, 0, w, h)
        paintRain(g, w, h, cell, true)
        paintLightning(g, w, h, map, cell, flash, occurrence)
      end
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
  return canvas
end


function Weather.apply(canvas, w, h, map, cell, resolvedMode)
  return apply(canvas, w, h, map, cell, resolvedMode, false)
end

function Weather.applyBattle(canvas, w, h, map, cell, resolvedMode)
  return apply(canvas, w, h, map, cell, resolvedMode, true)
end

return Weather
