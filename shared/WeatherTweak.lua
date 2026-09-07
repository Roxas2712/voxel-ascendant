-- Optional micro-weather layered on top of Voxel Ascendant's canonical
-- Weather.lua. This module never selects or replaces the base weather, never
-- changes battle rules and owns no assets. OFF is a strict zero-draw path.
--
-- The implementation lives in shared/ so the Gen-1 and Gen-2 loader shims use
-- the exact same reviewed source. That also keeps the tweak easy to transplant
-- into a later RC without merging two drifting copies.

local V = ...

local CanvasPresentation = V.require("CanvasPresentation")
local DayNight = V.require("DayNight")
local ModSetting = V.require("ModSetting")
local AmbientAudio = V.require("AmbientAudio")

local WeatherTweak = {
  clock = 0,
  lastClock = nil,
  lastMapId = nil,
  lastMode = nil,
  aftermathRemaining = 0,
  snowAmount = 0,
  snowTarget = 0,
}

WeatherTweak.AFTERMATH_SECONDS = 45
WeatherTweak.SNOW_BUILD_SECONDS = 105
WeatherTweak.SNOW_MELT_SECONDS = 210
WeatherTweak.setting = ModSetting.new(
  "weatherTweak", "WX MICRO EVENTS",
  { "off", "subtle", "full" }, { "OFF", "SUBTLE", "FULL" }, "subtle")

local EVENT = {
  wind      = { period = 45,  duration = 24, salt = 173 },
  ash       = { period = 45,  duration = 32, salt = 317 },
  dust      = { period = 40,  duration = 28, salt = 431 },
  hail      = { period = 24,  duration = 24, salt = 557, reliable = .56 },
  spray     = { period = 32,  duration = 24, salt = 683 },
  fireflies = { period = 32,  duration = 32, salt = 811, reliable = .62 },
  meteor    = { period = 420, duration = 8,  salt = 947 },
  stormLeaves = { period = 14, duration = 14, salt = 1031, reliable = .58 },
}

local SCENIC_OUTDOORS = {
  SAFARI_ZONE_CENTER=true, SAFARI_ZONE_EAST=true,
  SAFARI_ZONE_NORTH=true, SAFARI_ZONE_WEST=true,
  VERMILION_DOCK=true, SS_ANNE_BOW=true,
}

local function finite(value, fallback)
  if type(value) ~= "number" or value ~= value
      or value == math.huge or value == -math.huge then
    return fallback
  end
  return value
end

local function mapId(map)
  return tostring(map and (map.id or (map.def and map.def.id)) or "")
end

local function normalizedMapId(map)
  return mapId(map):upper():gsub("[^A-Z0-9]+", "_")
end

local function hashText(text)
  local h = 19
  text = tostring(text or "")
  for i = 1, #text do h = (h * 33 + text:byte(i)) % 65521 end
  return h
end

local function isOutdoor(map)
  if not (map and map.def) then return false end
  local id, def = mapId(map), map.def
  if SCENIC_OUTDOORS[id] then return true end
  if def.outdoor ~= nil then return def.outdoor and true or false end
  if def.environment ~= nil then
    return def.environment == "TOWN" or def.environment == "ROUTE"
  end
  return def.tileset == "OVERWORLD"
end

local function contains(id, ...)
  for i = 1, select("#", ...) do
    if id:find(select(i, ...), 1, true) then return true end
  end
  return false
end

local function regionalTags(map)
  local id = normalizedMapId(map)
  return {
    ash = contains(id, "CINNABAR"),
    dust = id == "ROUTE_3" or id == "ROUTE_4"
           or contains(id, "MT_MOON_SQUARE"),
    cold = id == "ROUTE_23" or contains(id, "INDIGO_PLATEAU", "ICE_PATH",
                                         "MT_SILVER", "MAHOGANY"),
    coast = id == "ROUTE_19" or id == "ROUTE_20" or id == "ROUTE_21"
            or contains(id, "CINNABAR", "VERMILION", "SS_ANNE", "SEAFOAM",
                              "OLIVINE", "CIANWOOD", "WHIRL_ISLAND"),
    forest = contains(id, "VIRIDIAN_FOREST", "ILEX_FOREST", "NATIONAL_PARK"),
    meteor = id == "ROUTE_3" or id == "ROUTE_4"
             or contains(id, "MT_MOON_SQUARE"),
  }, id
end

local function window(kind, clock, id)
  local spec = EVENT[kind]
  if not spec then return nil end
  local shifted = finite(clock, 0) + (hashText(id) + spec.salt) % spec.period
  local occurrence = math.floor(shifted / spec.period)
  local phase = shifted % spec.period
  if phase >= spec.duration then return nil, occurrence end
  return phase / spec.duration, occurrence
end

local function envelope(progress)
  if progress == nil then return 0 end
  return math.min(1, progress / 0.18, (1 - progress) / 0.22)
end

local function allowedMode(mode, ...)
  for i = 1, select("#", ...) do
    if mode == select(i, ...) then return true end
  end
  return false
end

function WeatherTweak.enabled()
  return WeatherTweak.setting:get() ~= "off"
end

function WeatherTweak.reset(clock)
  WeatherTweak.clock = finite(clock, 0)
  WeatherTweak.lastClock = nil
  WeatherTweak.lastMapId = nil
  WeatherTweak.lastMode = nil
  WeatherTweak.aftermathRemaining = 0
  WeatherTweak.snowAmount = 0
  WeatherTweak.snowTarget = 0
end

-- Observe the already-resolved frame without installing into Weather.lua.
-- This keeps both canonical Gen-1/Gen-2 weather modules byte-identical to RC9.
function WeatherTweak.observe(map, baseMode, baseClock, outdoor)
  local clock = finite(baseClock, WeatherTweak.clock)
  local elapsed = WeatherTweak.lastClock and (clock - WeatherTweak.lastClock) or 0
  if elapsed < 0 then elapsed = elapsed + 65521 end
  -- A save restore/long suspension is not a weather transition. Reset the
  -- small observer instead of manufacturing an aftermath from stale state.
  if elapsed > 120 then
    WeatherTweak.lastMapId = nil
    WeatherTweak.lastMode = nil
    WeatherTweak.aftermathRemaining = 0
    elapsed = 0
  end
  WeatherTweak.clock = clock
  WeatherTweak.lastClock = clock
  local id = mapId(map)
  outdoor = outdoor ~= nil and outdoor or isOutdoor(map)

  if not WeatherTweak.enabled() then
    WeatherTweak.aftermathRemaining = 0
    WeatherTweak.snowAmount = 0
    WeatherTweak.snowTarget = 0
    WeatherTweak.lastMapId = id
    WeatherTweak.lastMode = baseMode
    return
  end

  -- Snow is a surface state, not a one-frame weather switch. A new spell
  -- gets a deterministic light-to-heavy target and builds over roughly two
  -- minutes; once the front passes, the coat thaws over three and a half.
  -- Map transitions keep the same regional accumulation.
  if outdoor and baseMode == "snow" then
    local spell = math.floor(clock / 240)
    local target = .62 + ((spell * 19 + 11) % 39) / 100
    WeatherTweak.snowTarget = math.min(1, target)
    WeatherTweak.snowAmount = math.min(
      WeatherTweak.snowTarget,
      WeatherTweak.snowAmount + elapsed / WeatherTweak.SNOW_BUILD_SECONDS)
  else
    WeatherTweak.snowAmount = math.max(
      0, WeatherTweak.snowAmount - elapsed / WeatherTweak.SNOW_MELT_SECONDS)
    if WeatherTweak.snowAmount == 0 then WeatherTweak.snowTarget = 0 end
  end

  if (WeatherTweak.lastMode == "rain" or WeatherTweak.lastMode == "storm")
      and (baseMode == "clear" or baseMode == "heat") then
    WeatherTweak.aftermathRemaining = WeatherTweak.AFTERMATH_SECONDS
  elseif baseMode == "rain" or baseMode == "storm" then
    WeatherTweak.aftermathRemaining = 0
  elseif WeatherTweak.aftermathRemaining > 0 then
    WeatherTweak.aftermathRemaining = math.max(
      0, WeatherTweak.aftermathRemaining - elapsed)
  end
  WeatherTweak.lastMapId = id
  WeatherTweak.lastMode = baseMode
end

-- Preserve VASC's surface owner. The tweak only asks the existing shader to
-- keep its already-reviewed wet-ground treatment briefly after rain clears.
function WeatherTweak.groundMode(map, baseMode, nativeGround)
  if nativeGround == false then return "clear" end
  if WeatherTweak.enabled() and isOutdoor(map)
      and WeatherTweak.snowAmount > 0
      and (baseMode == "clear" or baseMode == "heat") then
    return "snow"
  end
  if WeatherTweak.enabled() and isOutdoor(map)
      and WeatherTweak.aftermathRemaining > 0
      and (baseMode == "clear" or baseMode == "heat") then
    return "rain"
  end
  return baseMode
end

-- Scalar companion to groundMode. OFF returns one, preserving RC9's exact
-- immediate surface treatment. With the tweak enabled snow can accumulate
-- and aftermath wetness drains instead of snapping off.
function WeatherTweak.groundAmount(map, baseMode, nativeGround)
  if nativeGround == false or not isOutdoor(map) then return 0 end
  if not WeatherTweak.enabled() then return 1 end
  if baseMode == "snow" or WeatherTweak.snowAmount > 0 then
    return math.max(0, math.min(1, WeatherTweak.snowAmount))
  end
  if (baseMode == "clear" or baseMode == "heat")
      and WeatherTweak.aftermathRemaining > 0 then
    return WeatherTweak.aftermathRemaining / WeatherTweak.AFTERMATH_SECONDS
  end
  return 1
end

-- Pure scheduling seam for QA. Only one micro-event wins a frame, keeping the
-- overlay bounded and preventing combinations from obscuring the base weather.
function WeatherTweak.eventAt(map, baseMode, clock, tod, selected)
  selected = selected or WeatherTweak.setting:get()
  if selected == "off" or not isOutdoor(map) then return nil end
  baseMode = tostring(baseMode or "clear")
  -- Absolute contract: the tweak never draws on VASC's normal RAIN mode.
  if baseMode == "rain" then return nil end
  tod = tostring(tod or "DAY")
  local tags, id = regionalTags(map)
  local function candidate(kind)
    local progress, occurrence = window(kind, clock, id)
    if progress == nil then return nil end
    local density = selected == "full" and 1 or 0.58
    local reliable = EVENT[kind] and EVENT[kind].reliable
    local strength = reliable
      and (reliable + (1 - reliable)
        * (.5 + .5 * math.sin(progress * math.pi * 2))) * density
      or envelope(progress) * density
    return { kind=kind, progress=progress, occurrence=occurrence,
             key=kind .. ":" .. id .. ":" .. tostring(occurrence),
             strength=strength, mapId=id }
  end

  if baseMode == "storm" then
    return candidate("stormLeaves")
  end
  if tags.cold and baseMode == "snow" then
    local got = candidate("hail")
    if got then return got end
  end
  if tags.ash and allowedMode(baseMode, "clear", "heat") then
    local got = candidate("ash")
    if got then return got end
  end
  if tags.dust and allowedMode(baseMode, "clear", "heat") then
    local got = candidate("dust")
    if got then return got end
  end
  if tags.coast and baseMode == "fog" then
    local got = candidate("spray")
    if got then return got end
  end
  if tags.meteor and baseMode == "clear" and tod == "NIGHT" then
    local got = candidate("meteor")
    if got then return got end
  end
  if tags.forest and baseMode == "clear"
      and (tod == "NIGHT" or tod == "EVENING") then
    local got = candidate("fireflies")
    if got then return got end
  end
  if allowedMode(baseMode, "clear", "snow", "heat") then
    return candidate("wind")
  end
  return nil
end

local function paintWind(g, w, h, cell, event)
  if not g.line then return end
  local step = math.max(1, cell)
  if g.setLineWidth then g.setLineWidth(math.max(1, step * .35)) end
  g.setColor(0.88, 0.93, 0.91, 0.20 * event.strength)
  for i = 1, 18 do
    local x = (i * 83 + WeatherTweak.clock * (38 + i % 4) * step) % (w + 80) - 40
    local y = (i * 47 + (i % 3) * h * .13) % h
    local len = step * (3 + i % 5)
    g.line(x, y, x + len, y - step * .35)
  end
end

local function paintAsh(g, w, h, cell, event)
  local step = math.max(1, cell)
  g.setColor(0.20, 0.17, 0.16, 0.08 * event.strength)
  g.rectangle("fill", 0, 0, w, h)
  for i = 1, 30 do
    local x = (i * 71 + WeatherTweak.clock * (4 + i % 3)) % (w + 20) - 10
    local y = (i * 43 + WeatherTweak.clock * (9 + i % 4)) % (h + 20) - 10
    local a = (0.28 + (i % 4) * .07) * event.strength
    g.setColor(0.42, 0.38, 0.34, a)
    g.rectangle("fill", x, y, math.max(1, step * .35), math.max(1, step * .35))
  end
end

local function paintDust(g, w, h, cell, event)
  local step = math.max(1, cell)
  g.setColor(0.58, 0.42, 0.24, 0.065 * event.strength)
  g.rectangle("fill", 0, h * .42, w, h * .58)
  for i = 1, 22 do
    local x = (i * 61 + WeatherTweak.clock * (28 + i % 5)) % (w + 40) - 20
    local y = h * .50 + (i * 31 % math.max(1, math.floor(h * .47)))
    g.setColor(0.77, 0.62, 0.38, (0.18 + i % 3 * .05) * event.strength)
    g.rectangle("fill", x, y, step * (1 + i % 3), math.max(1, step * .3))
  end
end

local function paintHail(g, w, h, cell, event)
  local step = math.max(1, cell)
  for i = 1, 28 do
    local x = (i * 79 + WeatherTweak.clock * (33 + i % 6)) % (w + 30) - 15
    local y = (i * 37 + WeatherTweak.clock * (64 + i % 7)) % (h + 30) - 15
    local size = math.max(1, step * (.32 + (i % 3) * .10))
    g.setColor(0.90, 0.96, 1.0, (0.40 + i % 4 * .08) * event.strength)
    g.rectangle("fill", x, y, size, size)
  end
end

local function paintSpray(g, w, h, cell, event)
  if not g.line then return end
  local step = math.max(1, cell)
  if g.setLineWidth then g.setLineWidth(math.max(1, step * .42)) end
  g.setColor(0.80, 0.92, 1.0, 0.32 * event.strength)
  for i = 1, 16 do
    local x = (i * 97 + WeatherTweak.clock * (31 + i % 3)) % (w + 60) - 30
    local y = h * (.70 + (i % 5) * .055)
    g.line(x, y, x + step * (2 + i % 4), y - step * (2 + i % 3))
  end
end

local function paintFireflies(g, w, h, cell, event)
  local step = math.max(1, cell)
  local margin = step * 5
  for i = 1, 18 do
    local seed = i * 47 + 13
    -- Each insect follows a slow curved lane; alternating direction keeps the
    -- swarm from reading as wind or confetti.
    local travel = (WeatherTweak.clock * (.010 + (seed % 7) * .0017)
                    + i * .137) % 1
    if i % 2 == 0 then travel = 1 - travel end
    local x = -margin + travel * (w + margin * 2)
      + math.sin(WeatherTweak.clock * (.39 + i % 3 * .07) + seed)
        * step * (1.6 + i % 4 * .45)
    local lane = h * (.31 + (seed % 58) / 100)
    local y = lane
      + math.sin(WeatherTweak.clock * (.46 + i % 5 * .055) + seed * .31)
        * step * (2.4 + i % 3)
      + math.sin(WeatherTweak.clock * .19 + seed) * step * 1.4
    local pulse = .30 + .70 * math.max(
      0, math.sin(WeatherTweak.clock * (1.65 + i % 4 * .16) + i * 1.7))
    local glow = event.strength * pulse
    local core = math.max(1, step * (.34 + i % 3 * .07))
    if g.circle then
      g.setColor(.58, 1.0, .22, .14 * glow)
      g.circle("fill", x, y, core * 2.8)
      g.setColor(.82, 1.0, .34, .82 * glow)
      g.circle("fill", x, y, core)
    else
      g.setColor(.58, 1.0, .22, .13 * glow)
      g.rectangle("fill", x - core, y - core, core * 3, core * 3)
      g.setColor(.82, 1.0, .34, .82 * glow)
      g.rectangle("fill", x, y, core, core)
    end
  end
end

local function paintMeteor(g, w, h, cell, event)
  if not g.line then return end
  local step = math.max(1, cell)
  if g.setLineWidth then g.setLineWidth(math.max(1, step * .45)) end
  for i = 1, 3 do
    local travel = (event.progress * 1.45 + i * .29) % 1
    local x = w * (.12 + travel * .75)
    local y = h * (.08 + travel * .28 + i * .035)
    g.setColor(0.92, 0.96, 1.0, (.58 - i * .08) * event.strength)
    g.line(x, y, x - step * (8 + i * 3), y - step * (3 + i))
  end
end

-- An explicitly additive storm detail: tumbling leaf flecks only. It neither
-- draws rain nor changes VASC's existing rain rails, screen tears or tint.
local STORM_LEAF_COLORS = {
  { .48, .31, .12, .72 }, { .68, .46, .16, .68 },
  { .29, .43, .17, .66 }, { .55, .24, .10, .64 },
}

local function paintStormLeaves(g, w, h, cell, event)
  local step = math.max(1, cell)
  local count = 10 + math.floor(12 * event.strength + .5)
  for i = 1, count do
    local speed = 34 + (i % 6) * 7
    local x = (i * 83 + WeatherTweak.clock * speed) % (w + 56) - 28
    local y = (i * 47 + math.sin(WeatherTweak.clock * 2.2 + i) * step * 6)
              % (h + 32) - 16
    local leaf = STORM_LEAF_COLORS[(i - 1) % #STORM_LEAF_COLORS + 1]
    g.setColor(leaf[1], leaf[2], leaf[3], leaf[4] * event.strength)
    local wide = (i % 2 == 0) and step * 1.35 or step * .62
    local tall = (i % 2 == 0) and step * .55 or step * 1.18
    g.rectangle("fill", x, y, math.max(1, wide), math.max(1, tall))
  end
end

local PAINTER = {
  wind=paintWind, ash=paintAsh, dust=paintDust, hail=paintHail,
  spray=paintSpray, fireflies=paintFireflies, meteor=paintMeteor,
  stormLeaves=paintStormLeaves,
}

function WeatherTweak.apply(canvas, w, h, map, cell, baseMode, battle)
  if not canvas or not WeatherTweak.enabled() then return canvas end
  -- Normal VASC rain is sacrosanct: do not even inspect LOVE on this path.
  if baseMode == "rain" then return canvas end
  -- Celestial/forest discoveries stay in exploration. Weather-like events may
  -- enter a live overworld battle, but at half density for HUD readability.
  local tod = type(DayNight.tod) == "function" and DayNight.tod() or "DAY"
  local event = WeatherTweak.eventAt(
    map, baseMode, WeatherTweak.clock, tod, WeatherTweak.setting:get())
  if not event or (battle and (event.kind == "meteor"
      or event.kind == "fireflies")) then return canvas end
  if battle then event.strength = event.strength * .5 end
  if event.strength <= 0 then return canvas end
  if not battle and AmbientAudio
      and type(AmbientAudio.weatherEvent) == "function" then
    AmbientAudio.weatherEvent(event)
  end

  local g = love and love.graphics
  local painter = PAINTER[event.kind]
  if not (g and g.setCanvas and g.rectangle and painter) then return canvas end
  local pushed, previousCanvas = false, nil
  pcall(function() previousCanvas = g.getCanvas and g.getCanvas() or nil end)
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
    painter(g, w, h, cell, event)
    if previousCanvas then g.setCanvas(previousCanvas) else g.setCanvas() end
    g.pop()
    pushed = false
  end)
  if not ok then
    if previousCanvas then pcall(g.setCanvas, previousCanvas)
    else pcall(g.setCanvas) end
    if pushed then pcall(g.pop) end
  end
  return canvas
end

function WeatherTweak.status(map, baseMode)
  local tod = type(DayNight.tod) == "function" and DayNight.tod() or "DAY"
  local event = WeatherTweak.eventAt(
    map, baseMode, WeatherTweak.clock, tod, WeatherTweak.setting:get())
  return {
    enabled=WeatherTweak.enabled(),
    event=event and event.kind or nil,
    aftermath=WeatherTweak.aftermathRemaining,
    snowAmount=WeatherTweak.snowAmount,
    snowTarget=WeatherTweak.snowTarget,
  }
end

return WeatherTweak
