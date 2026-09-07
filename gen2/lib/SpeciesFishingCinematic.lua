-- VASC integrated Species Fishing Cinematic (Generation 2).
--
-- Gold/Silver/Crystal retain exclusive ownership of rod validation, encounter
-- and shiny generation, timers, text, input and battle startup. This module
-- observes World:beginFishing after the native call and draws the exact stored
-- result into GoldVoxelBridge's already successful field-FX canvas.

local V = ...

local M = {
  VERSION = "0.1.0",
  installed = false,
  lastError = nil,
}

local mod = V and V.mod
local activeByWorld = setmetatable({}, { __mode = "k" })
local pendingRodByWorld = setmetatable({}, { __mode = "k" })
local imageCache = {}
local quadCache = setmetatable({}, { __mode = "k" })
local unpackValues = table.unpack or unpack

local ASSET_DIR = "assets/species_cinematics/directional"
local NATIONAL_DEX_MAX = 386
local GOROCHU_DEX = 1026
local FISH_CAST_FRAMES = 40
local FISH_BITE_FRAMES = 40
local OPTION_KEY = "fishingPresentation"
local OPTION_DEFAULT = "vasc"

local RODS = {
  OLD_ROD = {
    line = { 0.55, 0.43, 0.27, 1 },
    float = { 0.82, 0.22, 0.16, 1 },
    rings = 2, splash = 0.72,
  },
  GOOD_ROD = {
    line = { 0.80, 0.84, 0.82, 1 },
    float = { 0.94, 0.32, 0.16, 1 },
    rings = 3, splash = 0.90,
  },
  SUPER_ROD = {
    line = { 0.96, 0.82, 0.26, 1 },
    float = { 0.90, 0.12, 0.15, 1 },
    rings = 4, splash = 1.12,
  },
}

local function pack(...)
  return { n = select("#", ...), ... }
end

local function clamp(v, lo, hi)
  return math.max(lo, math.min(hi, tonumber(v) or 0))
end

local function smooth(v)
  v = clamp(v, 0, 1)
  return v * v * (3 - 2 * v)
end

local function lerp(a, b, t)
  return a + (b - a) * t
end

local function safeWarn(fmt, ...)
  local log = mod and mod.log
  if log and type(log.warn) == "function" then
    pcall(log.warn, log, fmt, ...)
  end
end

-- Fishing keeps the established VASC replacement when an older launcher does
-- not know this option. An explicit OFF still bypasses every presentation
-- record and delegates directly to the engine method.
local function optionEnabled()
  local options = mod and mod.options
  if not (options and type(options.get) == "function") then return OPTION_DEFAULT end
  local ok, value = pcall(options.get, options, OPTION_KEY)
  if not ok or value == nil then return OPTION_DEFAULT end
  if value == "vanilla" or value == "off" or value == false or value == 0
      or value == "0" or value == "false" then return false end
  return value == "vasc" or value == true or value == 1 or value == "1"
    or value == "true" or value == "on"
end

local function clearWorldState(world)
  if world == nil then return end
  activeByWorld[world] = nil
  pendingRodByWorld[world] = nil
end

local function shiny(mon)
  if type(mon) ~= "table" then return false end
  if mon.shiny == true or mon.isShiny == true then return true end
  local okStats, Stats = pcall(require, "src.pokemon.Stats")
  if okStats and Stats and type(Stats.isShiny) == "function" then
    local ok, value = pcall(Stats.isShiny, mon.dvs)
    if ok then return value == true end
  end
  return false
end

local function pokemonDef(world, mon)
  local species = type(mon) == "table" and mon.species or nil
  local data = world and world.game and world.game.data
  return species and data and data.pokemon and data.pokemon[species] or nil
end

local function dexFor(world, mon)
  local def = pokemonDef(world, mon)
  if type(def) ~= "table" then return nil end
  local raw = def.sourceDex or def.nationalDex or def.dexNumber
    or def.dex or def.number or def.index
  local dex = tonumber(raw)
  if not dex or dex ~= math.floor(dex) then return nil end
  if mon.species == "GOROCHU" and dex == GOROCHU_DEX then return dex end
  if dex < 1 or dex > NATIONAL_DEX_MAX then return nil end
  return dex
end

local function dimensions(def)
  local entry = type(def) == "table" and (def.dexEntry or def.pokedex) or {}
  local metres = tonumber(entry.heightM or entry.height)
  if not metres then
    local feet = tonumber(entry.heightFt) or 0
    local inches = tonumber(entry.heightIn) or 0
    if feet > 0 or inches > 0 then
      metres = (feet * 12 + inches) * 0.0254
    end
  end
  return metres or 1, tonumber(entry.weightKg or entry.weight) or 10
end

local function profileFor(world, mon)
  local def = pokemonDef(world, mon) or {}
  local metres, kilos = dimensions(def)
  local rate = tonumber(def.catchRate or def.catch_rate or def.captureRate)
  local large = metres >= 1.8 or kilos >= 90
  local rare = rate ~= nil and rate <= 60
  return {
    large = large,
    rare = rare,
    burst = 1 + (large and 0.65 or 0) + (rare and 0.35 or 0),
    size = clamp(18 + metres * 5.2, 20, large and 42 or 32),
  }
end

local function imagePath(rel)
  local assets = mod and mod.assets
  if assets and type(assets.path) == "function" then
    local ok, path = pcall(assets.path, assets, rel)
    if ok and type(path) == "string" then return path end
  end
  return nil
end

local function spriteFor(world, mon)
  local dex = dexFor(world, mon)
  if not dex then return nil end
  local key = string.format("%03d-%s", dex, shiny(mon) and "shiny" or "normal")
  if imageCache[key] == false then return nil end
  local image = imageCache[key]
  if image then return image end
  local g = love and love.graphics
  local path = imagePath(ASSET_DIR .. "/" .. key .. ".png")
  if not (g and type(g.newImage) == "function" and path) then return nil end
  local ok
  ok, image = pcall(g.newImage, path)
  if not ok or not image then
    imageCache[key] = false
    return nil
  end
  if type(image.setFilter) == "function" then
    pcall(image.setFilter, image, "nearest", "nearest")
  end
  imageCache[key] = image
  return image
end

local ROW = { down = 0, left = 1, right = 2, up = 3 }
local OPPOSITE = { down = "up", up = "down", left = "right", right = "left" }

local function spriteQuad(image, facing, frame)
  local byImage = quadCache[image]
  if not byImage then
    byImage = {}
    quadCache[image] = byImage
  end
  local row = ROW[OPPOSITE[facing] or "down"] or 0
  local column = math.floor(tonumber(frame) or 0) % 4
  local key = row * 4 + column
  if byImage[key] then
    return byImage[key], byImage.cell,
      byImage.mirrorRows and byImage.mirrorRows[row] == true
  end
  if type(image.getDimensions) ~= "function" then return nil end
  local iw, ih = image:getDimensions()
  local cell, qx, qy
  if iw == 16 and ih == 96 then
    local frames = {
      [0] = { 0, 3, 0, 3 },
      [1] = { 2, 5, 2, 5 },
      [2] = { 2, 5, 2, 5 },
      [3] = { 1, 4, 1, 4 },
    }
    cell, qx, qy = 16, 0, frames[row][column + 1] * 16
    byImage.mirrorRows = { [2] = true }
  elseif iw == ih and iw % 4 == 0 then
    cell, qx, qy = iw / 4, column * (iw / 4), row * (iw / 4)
  else
    return nil
  end
  local g = love and love.graphics
  if not (g and type(g.newQuad) == "function") then return nil end
  local ok, quad = pcall(g.newQuad, qx, qy, cell, cell, iw, ih)
  if not ok or not quad then return nil end
  byImage[key], byImage.cell = quad, cell
  return quad, cell, byImage.mirrorRows and byImage.mirrorRows[row] == true
end

local function playerPoint(world)
  local p = world and world.player
  if not p then return nil end
  return (tonumber(p.px) or ((tonumber(p.cellX) or 0) * 16)) + 8,
    (tonumber(p.py) or ((tonumber(p.cellY) or 0) * 16)) + 15,
    p.facing or "down"
end

local DELTA = {
  up = { 0, -16 }, down = { 0, 16 },
  left = { -16, 0 }, right = { 16, 0 },
}

local function bobberPoint(world, state)
  local fishing = world and world.fishing
  local bobber = fishing and fishing.bobber
  if bobber then
    return (tonumber(bobber.px) or ((tonumber(bobber.cellX) or 0) * 16)) + 8,
      (tonumber(bobber.py) or ((tonumber(bobber.cellY) or 0) * 16)) + 8
  end
  local px, py, facing = playerPoint(world)
  if not px then return nil end
  local d = DELTA[state.facing or facing] or DELTA.down
  return px + d[1], py + d[2] - 7
end

local function startState(world, rod, outcome, wild)
  if not optionEnabled() then
    clearWorldState(world)
    return nil
  end
  if not (world and world.player and world.fishing) then return nil end
  M.lastError = nil
  local _, _, facing = playerPoint(world)
  local state = {
    world = world,
    generation = 2,
    rod = RODS[rod] and rod or "OLD_ROD",
    outcome = outcome,
    wild = wild,
    native = world.fishing,
    facing = facing or "down",
    elapsed = 0,
    lastClock = nil,
    drawFrames = 0,
    biteFrames = 0,
    pulloutFrames = 0,
  }
  state.profile = wild and profileFor(world, wild) or nil
  activeByWorld[world] = state
  return state
end

local function tickClock(state)
  local now
  if love and love.timer and type(love.timer.getTime) == "function" then
    local ok, value = pcall(love.timer.getTime)
    if ok then now = tonumber(value) end
  end
  local dt = 1 / 60
  if now and state.lastClock then dt = clamp(now - state.lastClock, 0, 0.1) end
  state.lastClock = now
  state.elapsed = state.elapsed + dt
end

local function phaseValues(state)
  local st = state.native
  if type(st) ~= "table" then return 1, 0, 0 end
  if st.phase == "cast" then
    return smooth(1 - clamp((tonumber(st.timer) or 0) / FISH_CAST_FRAMES, 0, 1)), 0, 0
  end
  if st.phase == "bite" then
    local bite = smooth(1 - clamp((tonumber(st.timer) or 0) / FISH_BITE_FRAMES, 0, 1))
    return 1, bite, smooth(clamp((bite - 0.18) / 0.82, 0, 1))
  end
  if st.phase == "done" and st.outcome == "battle" then return 1, 1, 1 end
  return 1, 0, 0
end

local function displayPhase(state)
  local st = state.native or {}
  if st.phase == "done" and st.outcome ~= "battle" then return "nothing" end
  -- Gold keeps the successful catch result in DONE while the battle hand-off
  -- is pending.  phaseValues deliberately holds the pulled Pokemon at 1 here;
  -- report that same presentation state instead of falling through to SETTLE.
  if st.phase == "done" and st.outcome == "battle" then return "pullout" end
  local cast, _, pulled = phaseValues(state)
  if st.phase == "bite" then
    if pulled > 0.02 then return "pullout" end
    -- The engine latches BITE before decrementing its 40-frame timer. Report
    -- that real phase immediately even though the first visual amplitude is
    -- still zero; the pull-out threshold remains unchanged.
    return "bite"
  end
  return cast < 0.96 and "cast" or "settle"
end

-- Gold's render.compose scale is expressed in LOVE window units, while the
-- legacy whole-window voxel canvas is allocated in framebuffer pixels and is
-- later drawn back from pw/ph to ww/wh.  Size the overlay in the canvas' actual
-- coordinate space so a 2x Retina canvas presents at the same logical size as
-- the modern 1x path.  The geometric mean is the least-distorting single scale
-- for the rare host that reports different horizontal/vertical pixel ratios.
local function effectivePresentationScale(canvas, ctx)
  local scale = tonumber(ctx and ctx.scale) or 1
  if not (canvas and type(canvas.getDimensions) == "function") then
    return scale
  end
  local ok, cw, ch = pcall(canvas.getDimensions, canvas)
  local ww, wh = tonumber(ctx and ctx.ww), tonumber(ctx and ctx.wh)
  cw, ch = tonumber(cw), tonumber(ch)
  if not (ok and cw and ch and ww and wh
      and cw > 0 and ch > 0 and ww > 0 and wh > 0) then
    return scale
  end
  local pixelRatio = math.sqrt((cw / ww) * (ch / wh))
  if pixelRatio ~= pixelRatio or pixelRatio <= 0 then return scale end
  return scale * pixelRatio
end

local function color(g, value, alpha)
  g.setColor(value[1], value[2], value[3],
    (value[4] or 1) * (alpha == nil and 1 or alpha))
end

local WATER_LIGHT = { 0.76, 0.95, 1, 1 }
local WATER_MID = { 0.22, 0.68, 0.91, 1 }
local WATER_DARK = { 0.05, 0.28, 0.48, 1 }

local function ringCount(state)
  local rod = RODS[state.rod] or RODS.OLD_ROD
  return rod.rings + ((state.profile and state.profile.large) and 1 or 0)
end

local function drawPixelDrop(g, x, y, size, alpha)
  color(g, WATER_LIGHT, alpha)
  g.rectangle("fill", math.floor(x), math.floor(y), size, size * 1.8)
  color(g, WATER_MID, alpha)
  g.rectangle("fill", math.floor(x + size * 0.35),
    math.floor(y + size * 0.8), size * 0.65, size)
end

local function drawRipples(g, x, y, state, scale, intensity)
  local rings = ringCount(state)
  local clock = state.elapsed * 1.8
  if type(g.setLineWidth) == "function" then
    g.setLineWidth(math.max(1, scale * 0.55))
  end
  for i = 1, rings do
    local p = (clock + i / rings) % 1
    local radius = (3 + p * (9 + i * 1.2)) * scale * intensity
    color(g, i % 2 == 0 and WATER_MID or WATER_LIGHT, (1 - p) * 0.72)
    g.ellipse("line", x, y, radius, math.max(scale, radius * 0.28))
  end
end

local function drawSplash(g, x, y, state, scale, bite)
  if bite <= 0 then return end
  local rod = RODS[state.rod] or RODS.OLD_ROD
  local burst = rod.splash * ((state.profile and state.profile.burst) or 1)
  local alpha = clamp(1 - math.abs(bite - 0.48) * 1.8, 0, 1)
  local count = math.floor(4 + burst * 4)
  for i = 1, count do
    local side = i % 2 == 0 and 1 or -1
    local lane = math.floor((i - 1) / 2) + 1
    local reach = (4 + lane * 2.2) * scale * burst
    local arc = math.sin(clamp(bite * 1.35, 0, 1) * math.pi)
    drawPixelDrop(g, x + side * reach * bite,
      y - arc * (5 + lane * 2.5) * scale * burst,
      math.max(1, scale * 0.65), alpha)
  end
  color(g, WATER_LIGHT, 0.78 * alpha)
  g.rectangle("fill", x - 11 * scale * burst, y - scale,
    22 * scale * burst, math.max(1, scale))
end

local function drawFloat(g, x, y, rod, scale, bite)
  local bob = math.sin(bite * math.pi * 8) * scale * (bite > 0 and 1.5 or 0)
  y = y + bob
  color(g, WATER_DARK, 0.85)
  g.rectangle("fill", x - scale, y - 4 * scale, 2 * scale, 5 * scale)
  color(g, rod.float, 1)
  g.rectangle("fill", x - 1.5 * scale, y - 3 * scale, 3 * scale, 2 * scale)
  g.setColor(0.97, 0.97, 0.88, 1)
  g.rectangle("fill", x - 1.5 * scale, y - scale, 3 * scale, 2 * scale)
end

local function drawPokemon(g, state, x, y, pulled, scale)
  if not (state.wild and pulled > 0.02) then return false end
  local image = spriteFor(state.world, state.wild)
  if not image then return false end
  local quad, cell, mirror = spriteQuad(image, state.facing,
    math.floor(state.elapsed * 10) % 4)
  if not quad then return false end
  local profile = state.profile or profileFor(state.world, state.wild)
  local target = profile.size * scale
  local appear = smooth(clamp(pulled / 0.72, 0, 1))
  local drawScale = target / cell * appear
  local rise = (7 + target * 0.78) * pulled
  local bob = math.sin(state.elapsed * 8) * scale * 0.75 * pulled
  g.setColor(1, 1, 1, appear)
  local drawX = x + (mirror and 1 or -1) * cell * drawScale * 0.5
  g.draw(image, quad, drawX,
    y - rise - cell * drawScale * 0.65 + bob,
    0, mirror and -drawScale or drawScale, drawScale)
  return true
end

local function drawFishingFx(state, project, displayScale)
  local world = state.world
  local px, py = playerPoint(world)
  local bx, by = bobberPoint(world, state)
  if not (px and bx and type(project) == "function") then return false end
  local okP, psx, psy = pcall(project, px, py)
  local okB, bsx, bsy = pcall(project, bx, by)
  if not (okP and okB and type(psx) == "number" and type(psy) == "number"
      and type(bsx) == "number" and type(bsy) == "number") then return false end

  local g = love and love.graphics
  if not (g and type(g.push) == "function" and type(g.pop) == "function"
      and type(g.rectangle) == "function" and type(g.ellipse) == "function"
      and type(g.line) == "function" and type(g.setColor) == "function") then
    return false
  end
  tickClock(state)
  local rod = RODS[state.rod] or RODS.OLD_ROD
  local scale = math.max(0.55, tonumber(displayScale) or 1)
  local cast, bite, pulled = phaseValues(state)
  local handX, handY = psx, psy - 13 * scale
  if state.facing == "left" then handX = handX - 4 * scale
  elseif state.facing == "right" then handX = handX + 4 * scale end
  local tipX, tipY
  if cast < 1 then
    tipX = lerp(handX, bsx, cast)
    tipY = lerp(handY, bsy, cast) - math.sin(cast * math.pi) * 18 * scale
  else
    tipX, tipY = bsx, bsy
  end
  if bite > 0 then tipY = tipY + math.sin(bite * math.pi * 8) * 1.5 * scale end

  local pushed = false
  local ok, err = pcall(function()
    g.push("all")
    pushed = true
    if type(g.setBlendMode) == "function" then g.setBlendMode("alpha") end
    if type(g.setShader) == "function" then g.setShader() end
    if type(g.setLineWidth) == "function" then
      g.setLineWidth(math.max(1, scale * 0.65))
    end
    local lean = cast < 1 and math.sin(cast * math.pi) * 5 * scale or 0
    color(g, rod.line, 1)
    g.line(handX, handY, handX + (bsx - handX) * 0.25,
      handY - 8 * scale - lean)
    g.setColor(0.86, 0.90, 0.94, 0.92)
    g.line(handX + (bsx - handX) * 0.25, handY - 8 * scale - lean,
      tipX, tipY - 3 * scale)
    if cast >= 0.96 then
      drawRipples(g, bsx, bsy, state, scale,
        displayPhase(state) == "nothing" and 0.65 or 1)
    end
    drawSplash(g, bsx, bsy, state, scale, bite)
    if pulled < 0.82 then drawFloat(g, tipX, tipY, rod, scale, bite) end
    if drawPokemon(g, state, bsx, bsy, pulled, scale) then
      state.pulloutFrames = state.pulloutFrames + 1
    end
    if bite > 0 then state.biteFrames = state.biteFrames + 1 end
  end)
  if pushed then pcall(g.pop) end
  if not ok then error(err, 0) end
  state.drawFrames = state.drawFrames + 1
  state.lastDraw = {
    rod = true,
    line = true,
    bobber = pulled < 0.82,
    rings = cast >= 0.96 and ringCount(state) or 0,
  }
  return true
end

local function status(world)
  local state = world and activeByWorld[world]
  local enabled = optionEnabled()
  local draw = state and state.lastDraw or {}
  return {
    active = enabled and state ~= nil and state.disabled ~= true,
    configured = enabled,
    generation = 2,
    phase = state and displayPhase(state) or nil,
    rod = state and state.rod or nil,
    rolledSpecies = state and state.wild and state.wild.species or nil,
    shiny = state and state.wild and shiny(state.wild) or false,
    noBite = state and state.wild == nil or false,
    rodVisible = draw.rod == true,
    lineVisible = draw.line == true,
    bobberVisible = draw.bobber == true,
    ringCount = tonumber(draw.rings) or (state and ringCount(state) or 0),
    drawFrames = state and state.drawFrames or 0,
    biteFrames = state and state.biteFrames or 0,
    pulloutFrames = state and state.pulloutFrames or 0,
    nativeFailOpen = true,
    lastError = M.lastError,
  }
end

function M.decorateState(world, state)
  if not (world and type(state) == "table") then return state end
  if not optionEnabled() then
    clearWorldState(world)
    return state
  end
  local record = activeByWorld[world]
  if not world.fishing then
    activeByWorld[world] = nil
    return state
  end
  if record then
    record.native = world.fishing
    record.outcome = world.fishing.outcome or record.outcome
    record.wild = world.fishing.wild or record.wild
    record.profile = record.wild and profileFor(world, record.wild) or nil
    state._vascGen2Fishing = record
  end
  return state
end

function M.drawEngineFx(canvas, state, ctx, VoxelScene, Voxel3D)
  if not optionEnabled() then return true end
  local record = state and state._vascGen2Fishing
  if not (canvas and record and record.disabled ~= true) then return true end
  local g = love and love.graphics
  if not (g and type(g.setCanvas) == "function" and type(g.push) == "function"
      and type(g.pop) == "function" and Voxel3D
      and type(Voxel3D.project) == "function") then
    return true
  end
  local previous = type(g.getCanvas) == "function" and g.getCanvas() or nil
  local pushed = false
  local ok, err = pcall(function()
    g.push("all")
    pushed = true
    g.setCanvas(canvas)
    if type(g.origin) == "function" then g.origin() end
    if type(g.setShader) == "function" then g.setShader() end
    if type(g.setDepthMode) == "function" then g.setDepthMode() end
    if type(g.setBlendMode) == "function" then g.setBlendMode("alpha") end
    local function project(wx, wz)
      wx, wz = tonumber(wx), tonumber(wz)
      if not (wx and wz) then return nil end
      local ground = 0
      if VoxelScene and type(VoxelScene.groundAt) == "function"
          and state.map then
        local okGround, value = pcall(VoxelScene.groundAt, state.map,
          math.floor(wx / 16), math.floor(wz / 16))
        if okGround then ground = tonumber(value) or 0 end
      end
      return Voxel3D.project(wx, ground, wz)
    end
    drawFishingFx(record, project, effectivePresentationScale(canvas, ctx))
  end)
  if pushed then pcall(g.pop) end
  if previous then pcall(g.setCanvas, previous) else pcall(g.setCanvas) end
  if not ok then
    record.disabled = true
    M.lastError = tostring(err)
    safeWarn("Gen-2 fishing cinematic failed open to native: %s", M.lastError)
    return false
  end
  return true
end

function M.install()
  if M.installed then return true end
  local okWorld, World = pcall(require, "src.world.gen2.World")
  if not (okWorld and type(World) == "table"
      and type(World.useRod) == "function"
      and type(World.beginFishing) == "function") then
    return false, "Gen-2 fishing controller unavailable"
  end

  local bridge = World.__vascSpeciesFishingBridge
  if type(bridge) ~= "table" then
    bridge = {
      originalUseRod = World.useRod,
      originalBeginFishing = World.beginFishing,
    }
    World.__vascSpeciesFishingBridge = bridge
    World.useRod = function(world, rodId, ...)
      if not optionEnabled() then
        clearWorldState(world)
        return bridge.originalUseRod(world, rodId, ...)
      end
      local previous = pendingRodByWorld[world]
      local pending = { rod = rodId, previous = previous }
      pendingRodByWorld[world] = pending
      local results = pack(pcall(bridge.originalUseRod, world, rodId, ...))
      if not results[1] then
        if pendingRodByWorld[world] == pending then
          pendingRodByWorld[world] = previous
        end
        error(results[2], 0)
      end
      -- The current engine calls beginFishing synchronously and that wrapper
      -- consumes this record. Keep it for a deferred native implementation,
      -- but never retain a refused cast that returned "nowhere".
      if results[2] == "nowhere" and pendingRodByWorld[world] == pending then
        pendingRodByWorld[world] = previous
      end
      return unpackValues(results, 2, results.n)
    end
    World.beginFishing = function(world, outcome, wild, ...)
      if not optionEnabled() then
        clearWorldState(world)
        return bridge.originalBeginFishing(world, outcome, wild, ...)
      end
      local pending = pendingRodByWorld[world]
      local rod = type(pending) == "table" and pending.rod or pending
      local results = pack(pcall(bridge.originalBeginFishing,
        world, outcome, wild, ...))
      if not results[1] then
        if pendingRodByWorld[world] == pending then
          pendingRodByWorld[world] = type(pending) == "table"
            and pending.previous or nil
        end
        error(results[2], 0)
      end
      local provider = bridge.provider
      if provider and world.fishing then
        local okBegin, beginErr = pcall(provider.begin, world,
          rod, outcome, wild)
        if not okBegin then
          M.lastError = tostring(beginErr)
          activeByWorld[world] = nil
        end
      end
      if pendingRodByWorld[world] == pending then
        pendingRodByWorld[world] = type(pending) == "table"
          and pending.previous or nil
      end
      return unpackValues(results, 2, results.n)
    end
  end
  bridge.provider = {
    owner = M,
    begin = function(world, rod, outcome, wild)
      if optionEnabled() then
        startState(world, rod or world.fishingRod or "OLD_ROD", outcome, wild)
      else
        clearWorldState(world)
      end
    end,
  }

  mod.exports.speciesCinematics = mod.exports.speciesCinematics or { apiVersion = 1 }
  local contractQa = {
    mode = "CONTRACT_ONLY",
    receipt = function(world)
      local receipt = status(world)
      receipt.schema = "vasc/rc10-fishing-visual/v1"
      receipt.mode = "CONTRACT_ONLY"
      receipt.sourceVersion = M.VERSION
      receipt.owner = "mod.exports.speciesCinematics.fishing"
      receipt.configured = optionEnabled()
      receipt.gpuEvidence = false
      receipt.presentationOnly = true
      receipt.encounterMutations = 0
      receipt.captures = {}
      receipt.contracts = {
        rod = true,
        line = true,
        bobber = true,
        rings = true,
        rolled_species = true,
        no_bite = true,
        native_fail_open = true,
      }
      return receipt
    end,
  }
  mod.exports.speciesCinematics.fishing = {
    active = true,
    configured = optionEnabled(),
    isConfigured = optionEnabled,
    version = M.VERSION,
    sourceVersion = M.VERSION,
    generation = 2,
    assetRoot = ASSET_DIR,
    nativeFallback = true,
    status = status,
    visualQa = contractQa,
  }
  M.installed = true
  return true
end

-- GoldVoxelBridge calls this only when its renderer-level installation cannot
-- retain Fishing.  The engine wrappers remain safe delegates, but their VASC
-- provider and public capability are removed so no half-installed observer is
-- left active without the draw/decorate path that consumes it.
function M.deactivate(reason)
  local okWorld, World = pcall(require, "src.world.gen2.World")
  local bridge = okWorld and type(World) == "table"
    and World.__vascSpeciesFishingBridge or nil
  if type(bridge) == "table" and type(bridge.provider) == "table"
      and bridge.provider.owner == M then
    bridge.provider = nil
  end
  for world in pairs(activeByWorld) do clearWorldState(world) end
  for world in pairs(pendingRodByWorld) do clearWorldState(world) end
  local family = mod and mod.exports and mod.exports.speciesCinematics
  if type(family) == "table" and type(family.fishing) == "table"
      and family.fishing.sourceVersion == M.VERSION then
    family.fishing.active = false
    family.fishing = nil
  end
  M.installed = false
  M.lastError = reason and tostring(reason) or M.lastError
  return true
end

function M.status(world)
  return status(world)
end

M.configured = optionEnabled

return M
