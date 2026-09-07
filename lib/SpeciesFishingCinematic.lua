-- VASC integrated Species Fishing Cinematic (Generation 1).
--
-- The cartridge engine remains the sole owner of rod eligibility, encounter
-- rolls, text, input locks and battle creation. This module observes the
-- result returned by encounter.fishing exactly once and adds presentation to
-- VASC's existing field-FX pass. Any missing seam or drawing failure leaves
-- the native fishing sequence untouched.

local V = ...

local M = {
  VERSION = "0.1.0",
}

local installed = false
local activeByWorld = setmetatable({}, { __mode = "k" })
local pendingCastByWorld = setmetatable({}, { __mode = "k" })
local imageCache = {}
local quadCache = setmetatable({}, { __mode = "k" })
local lastError
local unpackValues = table.unpack or unpack

local PIPELINE_ID = "voxel"
local ASSET_DIR = "assets/species_cinematics/directional"
local NATIONAL_DEX_MAX = 386
local GOROCHU_DEX = 1026

local RODS = {
  OLD_ROD = {
    line = { 0.55, 0.43, 0.27, 1 },
    float = { 0.82, 0.22, 0.16, 1 },
    cast = 0.52, rings = 2, splash = 0.72,
  },
  GOOD_ROD = {
    line = { 0.80, 0.84, 0.82, 1 },
    float = { 0.94, 0.32, 0.16, 1 },
    cast = 0.46, rings = 3, splash = 0.90,
  },
  SUPER_ROD = {
    line = { 0.96, 0.82, 0.26, 1 },
    float = { 0.90, 0.12, 0.15, 1 },
    cast = 0.40, rings = 4, splash = 1.12,
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

local function safeLog(level, fmt, ...)
  local log = V and V.mod and V.mod.log
  local fn = log and log[level]
  if type(fn) == "function" then pcall(fn, log, fmt, ...) end
end

local function pokemonDef(world, mon)
  local species = type(mon) == "table" and mon.species or nil
  local game = world and world.game
  if not game then
    local ok, Game = pcall(require, "src.core.Game")
    if ok then game = Game end
  end
  return species and game and game.data and game.data.pokemon
    and game.data.pokemon[species] or nil
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

local function shiny(mon)
  if type(mon) ~= "table" then return false end
  if mon.shiny == true or mon.isShiny == true then return true end
  local okStats, Stats = pcall(require, "src.pokemon.Stats")
  if okStats and Stats and type(Stats.isShiny) == "function"
      and mon.dvs ~= nil then
    local ok, value = pcall(Stats.isShiny, mon.dvs)
    if ok then return value == true end
  end
  return false
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
  local kilos = tonumber(entry.weightKg or entry.weight)
  return metres or 1, kilos or 10
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
  local assets = V and V.mod and V.mod.assets
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
  local path = imagePath(ASSET_DIR .. "/" .. key .. ".png")
  local g = love and love.graphics
  if not (path and g and type(g.newImage) == "function") then return nil end
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

local function stackTop(world)
  local game = world and world.game
  if not game then
    local ok, Game = pcall(require, "src.core.Game")
    if ok then game = Game end
  end
  local stack = game and game.stack
  if not (stack and type(stack.top) == "function") then return nil end
  local ok, top = pcall(stack.top, stack)
  return ok and top or nil
end

local function playerPoint(world)
  local p = world and world.player
  if not p then return nil end
  return (tonumber(p.px) or ((tonumber(p.cellX) or 0) * 16)) + 8,
    (tonumber(p.py) or ((tonumber(p.cellY) or 0) * 16)) + 15,
    p.facing or (world.fishing and world.fishing.facing) or "down"
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
  facing = (fishing and fishing.facing) or state.facing or facing
  local d = DELTA[facing] or DELTA.down
  return px + d[1], py + d[2] - 7
end

local function startState(world, rod, roll, native, qa)
  if not (world and world.player) then return nil end
  lastError = nil
  local _, _, facing = playerPoint(world)
  local state = {
    generation = 1,
    rod = RODS[rod] and rod or "OLD_ROD",
    wild = roll,
    native = native,
    facing = facing or "down",
    elapsed = 0,
    phaseElapsed = 0,
    phase = "cast",
    firstTop = qa and nil or stackTop(world),
    qa = qa == true,
    drawFrames = 0,
    biteFrames = 0,
    pulloutFrames = 0,
  }
  state.profile = roll and profileFor(world, roll) or nil
  activeByWorld[world] = state
  return state
end

local function advanceState(world, state, dt)
  dt = clamp(dt, 0, 0.1)
  state.elapsed = state.elapsed + dt
  state.phaseElapsed = state.phaseElapsed + dt
  if state.qa then return end
  if not (world and world.fishing) then
    activeByWorld[world] = nil
    return
  end
  local top = stackTop(world)
  if state.phase == "cast" and state.firstTop and top ~= state.firstTop then
    state.phase = state.wild and "bite" or "nothing"
    state.phaseElapsed = 0
  end
end

local function phaseValues(state)
  if state.qa and state.forcedPhase then
    local p = smooth(state.forcedProgress or 0.5)
    if state.forcedPhase == "cast" then return p, 0, 0 end
    if state.forcedPhase == "settle" then return 1, 0, 0 end
    if state.forcedPhase == "bite" then return 1, p, 0 end
    if state.forcedPhase == "pullout" then return 1, 1, p end
    return 1, 0, 0
  end
  local rod = RODS[state.rod] or RODS.OLD_ROD
  local cast = smooth(state.elapsed / rod.cast)
  local bite, pulled = 0, 0
  if state.phase == "bite" then
    bite = smooth(state.phaseElapsed / 0.62)
    pulled = smooth(clamp((bite - 0.18) / 0.82, 0, 1))
  end
  return cast, bite, pulled
end

local function displayPhase(state)
  if state.qa and state.forcedPhase then return state.forcedPhase end
  local cast, _, pulled = phaseValues(state)
  if state.phase == "nothing" then return "nothing" end
  if state.phase == "bite" then
    if pulled > 0.02 then return "pullout" end
    -- The native TextBox edge is itself the bite latch. On that exact frame
    -- phaseElapsed is zero, so the visual amplitude has not advanced yet, but
    -- reporting SETTLE would lose the real engine transition the QA/export
    -- contract observes.
    return "bite"
  end
  return cast < 0.96 and "cast" or "settle"
end

local function color(g, value, alpha)
  g.setColor(value[1], value[2], value[3],
    (value[4] or 1) * (alpha == nil and 1 or alpha))
end

local WATER_LIGHT = { 0.76, 0.95, 1, 1 }
local WATER_MID = { 0.22, 0.68, 0.91, 1 }
local WATER_DARK = { 0.05, 0.28, 0.48, 1 }

local function drawPixelDrop(g, x, y, size, alpha)
  color(g, WATER_LIGHT, alpha)
  g.rectangle("fill", math.floor(x), math.floor(y), size, size * 1.8)
  color(g, WATER_MID, alpha)
  g.rectangle("fill", math.floor(x + size * 0.35),
    math.floor(y + size * 0.8), size * 0.65, size)
end

local function ringCount(state)
  local rod = RODS[state.rod] or RODS.OLD_ROD
  return rod.rings + ((state.profile and state.profile.large) and 1 or 0)
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

local function drawPokemon(g, world, state, x, y, pulled, scale)
  if not (state.wild and pulled > 0.02) then return false end
  local image = spriteFor(world, state.wild)
  if not image then return false end
  local quad, cell, mirror = spriteQuad(image, state.facing,
    math.floor(state.elapsed * 10) % 4)
  if not quad then return false end
  local profile = state.profile or profileFor(world, state.wild)
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

local function drawFishingFx(world, state, project, displayScale)
  if not (world and state and type(project) == "function") then return false end
  local px, py = playerPoint(world)
  local bx, by = bobberPoint(world, state)
  if not (px and bx) then return false end
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
  local pokemonDrawn = false
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
        state.phase == "nothing" and 0.65 or 1)
    end
    drawSplash(g, bsx, bsy, state, scale, bite)
    if pulled < 0.82 then drawFloat(g, tipX, tipY, rod, scale, bite) end
    pokemonDrawn = drawPokemon(g, world, state, bsx, bsy, pulled, scale)
  end)
  if pushed then pcall(g.pop) end
  if not ok then error(err, 0) end
  return true, {
    bite = bite > 0,
    pokemon = pokemonDrawn,
    draw = {
      rod = true,
      line = true,
      bobber = pulled < 0.82,
      rings = cast >= 0.96 and ringCount(state) or 0,
    },
  }
end

local function commitFishingDraw(state, receipt)
  if not (state and type(receipt) == "table") then return false end
  state.drawFrames = state.drawFrames + 1
  if receipt.bite == true then state.biteFrames = state.biteFrames + 1 end
  if receipt.pokemon == true then
    state.pulloutFrames = state.pulloutFrames + 1
  end
  state.lastDraw = receipt.draw
  return true
end

local function status(world)
  local state = world and activeByWorld[world]
  local draw = state and state.lastDraw or {}
  return {
    active = state ~= nil,
    generation = 1,
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
    lastError = lastError,
  }
end

local visualQa = {}

function visualQa.begin(world, spec)
  spec = type(spec) == "table" and spec or {}
  local roll = spec.noBite == true and nil or spec.rolled
  if roll ~= nil and type(roll) ~= "table" then
    return false, "rolled must be an existing encounter table or nil"
  end
  local state = startState(world, spec.rod or "OLD_ROD", roll, nil, true)
  if not state then return false, "world/player unavailable" end
  if type(spec.facing) == "string" then state.facing = spec.facing end
  state.forcedPhase = "cast"
  state.forcedProgress = 0.35
  return true
end

function visualQa.setPhase(world, phase, progress)
  local state = world and activeByWorld[world]
  if not (state and state.qa) then return false, "visual QA state unavailable" end
  local allowed = {
    cast = true, settle = true, bite = true, pullout = true, nothing = true,
  }
  if not allowed[phase] then return false, "unsupported presentation phase" end
  state.forcedPhase = phase
  state.forcedProgress = clamp(progress == nil and 0.62 or progress, 0, 1)
  state.phase = phase == "nothing" and "nothing" or phase
  state.phaseElapsed = 0
  return true
end

function visualQa.step(world, dt)
  local state = world and activeByWorld[world]
  if not (state and state.qa) then return false end
  advanceState(world, state, dt or 1 / 60)
  return true
end

function visualQa.clear(world)
  local state = world and activeByWorld[world]
  if not (state and state.qa) then return false end
  activeByWorld[world] = nil
  return true
end

function visualQa.receipt(world)
  local receipt = status(world)
  receipt.schema = "vasc/rc10-fishing-visual/v1"
  receipt.mode = "VISUAL"
  receipt.sourceVersion = M.VERSION
  receipt.presentationOnly = true
  receipt.encounterMutations = 0
  return receipt
end

function M.install()
  local mod = V and V.mod
  if installed then
    return true, mod and mod.exports and mod.exports.speciesCinematics
      and mod.exports.speciesCinematics.fishing
  end
  if not mod then return false, "mod handle unavailable" end

  local okVersion, GameVersion = pcall(require, "src.core.GameVersion")
  local edition = okVersion and GameVersion and type(GameVersion.get) == "function"
    and GameVersion.get() or nil
  if edition ~= "red" and edition ~= "blue" and edition ~= "yellow" then
    return false, "unsupported-edition"
  end

  local registry = mod.content and mod.content.render_pipelines
  local pipeline = registry and type(registry.get) == "function"
    and registry:get(PIPELINE_ID) or nil
  if type(pipeline) ~= "table" or type(pipeline.drawWorld) ~= "function"
      or not (registry and type(registry.patch) == "function") then
    return false, "voxel-pipeline-unavailable"
  end

  local okWorld, World = pcall(require, "src.world.OverworldController")
  if not (okWorld and type(World) == "table"
      and type(World.goFishing) == "function") then
    return false, "Gen-1 fishing controller unavailable"
  end

  -- rc.10 replaced World.goFishing to discover which instance owned a roll.
  -- That made a presentation feature part of the native fishing call chain.
  -- Stop any legacy provider but never replace (or restore over) the host
  -- method here: rod eligibility, fishing state and battle creation must stay
  -- under the engine's exact function identity.
  local legacyBridge = World.__vascSpeciesFishingBridge
  if type(legacyBridge) == "table" then legacyBridge.provider = nil end

  if mod.hooks and type(mod.hooks.wrap) == "function" then
    mod.hooks:wrap("encounter.fishing",
      function(next_, ...)
        -- Gen 1 0.1.90 exposes exactly three arguments while Gen 2's related
        -- hook later gained a fourth context value. Preserve the host chain's
        -- exact arity and every return rather than manufacturing a trailing
        -- nil or narrowing another provider's receipt.
        local args = pack(...)
        local results = pack(next_(unpackValues(args, 1, args.n)))
        -- Productive engine fishing always belongs to the active overworld.
        -- Record only presentation data here, then wait until the native
        -- controller itself exposes `world.fishing` before starting visuals.
        local okGame, Game = pcall(require, "src.core.Game")
        local world = okGame and Game and Game.overworld or nil
        if world then
          pendingCastByWorld[world] = { rod = args[1], roll = results[1] }
        end
        return unpackValues(results, 1, results.n)
      end, 1000)
  else
    return false, "encounter.fishing observer unavailable"
  end

  local baseUpdate = pipeline.update
  local baseDrawWorld = pipeline.drawWorld

  -- Gen1Recomp draws the native rod from `world.fishing` and selects the
  -- fishing player pose from `player.fishing`. The Voxel cinematic owns those
  -- pixels only while its canvas is eventually accepted; it never owns either
  -- gameplay flag. KASC and newer engines may publish the current character's
  -- live `fishingSprite`. Consume that renderer directly, without resolving or
  -- caching an identity: keeping `player.fishing` true makes VoxelScene retain
  -- the independent pose while a render-local sprite swap supports older
  -- engines whose pose() still reads only `player.sprite`. A missing or unsafe
  -- fishing renderer keeps the established standing/walking fallback. Every
  -- value is restored before the engine decides between Canvas and native 2D.
  local function liveFishingRenderer(player, playerFishing)
    if not (player and playerFishing) then return nil end
    local sprite = rawget(player, "fishingSprite")
    if type(sprite) ~= "table" or type(sprite.resolveImage) ~= "function"
        or type(sprite.frames) ~= "table" then return nil end
    local ok, image = pcall(sprite.resolveImage, sprite)
    if not ok or not image then return nil end
    if not (sprite.frames[0] or sprite.frames[1]) then return nil end
    return sprite
  end

  local function drawWithoutNativeFishing(world, draw, ctx)
    local player = world and world.player
    local nativeFishing = world and rawget(world, "fishing")
    local playerFishing = player and rawget(player, "fishing")
    local playerSprite = player and rawget(player, "sprite")
    local fishingSprite = liveFishingRenderer(player, playerFishing)
    if world then world.fishing = nil end
    if player then
      if fishingSprite then
        player.sprite = fishingSprite
      else
        player.fishing = nil
      end
    end
    local results = pack(pcall(draw, ctx))
    if player then
      player.sprite = playerSprite
      player.fishing = playerFishing
    end
    if world then world.fishing = nativeFishing end
    return results
  end

  local function noteUnclaimedFrame(state, reason)
    if not state then return end
    state.drawFailOpenFrames = (state.drawFailOpenFrames or 0) + 1
    if state.drawFailOpenFrames == 1 then
      safeLog("warn",
        "vasc.gen1.fishing.draw-claim-fail-open/v1 reason=%s action=native-2d-frame-retry",
        reason)
    end
  end
  local function fieldPresentationActive(world)
    if world and activeByWorld[world] then return true end
    local exports = mod.exports and mod.exports.speciesCinematics
    for _, id in ipairs({ "surf", "fly" }) do
      local api = type(exports) == "table" and exports[id] or nil
      if type(api) == "table" and type(api.status) == "function" then
        local ok, value = pcall(api.status, world)
        if ok and value ~= nil then return true end
      end
    end
    return false
  end

  local function abortFieldPresentations(world)
    activeByWorld[world] = nil
    pendingCastByWorld[world] = nil
    local exports = mod.exports and mod.exports.speciesCinematics
    for _, id in ipairs({ "surf", "fly" }) do
      local api = type(exports) == "table" and exports[id] or nil
      if type(api) == "table" and type(api.abort) == "function" then
        pcall(api.abort, world)
      end
    end
  end

  local okPatch, patchErr = pcall(registry.patch, registry, PIPELINE_ID, {
    update = function(dt, level)
      local okGame, Game = pcall(require, "src.core.Game")
      local world = okGame and Game and Game.overworld or nil
      if baseUpdate then
        local hadFieldPresentation = fieldPresentationActive(world)
        local okBase, baseErr = pcall(baseUpdate, dt, level)
        if not okBase then
          -- Fishing is installed last and therefore owns the outer field-FX
          -- boundary. A Surf/Fly/Fishing presentation must never let one bad
          -- transition callback retire the complete shared Voxel pipeline for
          -- the rest of the process. Drop only the active field visuals; an
          -- unrelated Voxel failure still keeps its original error policy.
          if hadFieldPresentation or fieldPresentationActive(world) then
            abortFieldPresentations(world)
            lastError = tostring(baseErr)
            safeLog("warn",
              "Field cinematic update failed open; Voxel retained: %s",
              lastError)
            return
          end
          error(baseErr, 0)
        end
      end
      local cast = world and pendingCastByWorld[world]
      if cast then
        pendingCastByWorld[world] = nil
        if world.fishing then
          local okBegin, beginErr = pcall(startState, world, cast.rod,
            cast.roll, world.fishing, false)
          if not okBegin then
            activeByWorld[world] = nil
            lastError = tostring(beginErr)
            safeLog("warn", "Fishing cinematic start failed open: %s", lastError)
          end
        end
      end
      local pending = {}
      for world, state in pairs(activeByWorld) do
        pending[#pending + 1] = { world, state }
      end
      for _, pair in ipairs(pending) do
        local ok, err = pcall(advanceState, pair[1], pair[2], dt)
        if not ok then
          activeByWorld[pair[1]] = nil
          lastError = tostring(err)
          safeLog("warn", "Fishing cinematic update failed open: %s", lastError)
        end
      end
    end,

    drawWorld = function(ctx)
      local world = ctx and ctx.state
      local state = world and activeByWorld[world]
      if not state then
        local hadFieldPresentation = fieldPresentationActive(world)
        local results = pack(pcall(baseDrawWorld, ctx))
        if not results[1] then
          if hadFieldPresentation or fieldPresentationActive(world) then
            abortFieldPresentations(world)
            lastError = tostring(results[2])
            safeLog("warn",
              "Field cinematic frame failed open; Voxel retained: %s",
              lastError)
            return nil
          end
          error(results[2], 0)
        end
        return unpackValues(results, 2, results.n)
      end
      if type(ctx.drawFx) ~= "function" then
        local results = pack(pcall(baseDrawWorld, ctx))
        if not results[1] then
          abortFieldPresentations(world)
          lastError = tostring(results[2])
          safeLog("warn",
            "Field cinematic frame failed open; Voxel retained: %s",
            lastError)
          return nil
        end
        if results[2] ~= nil then
          noteUnclaimedFrame(state, "host-overlay-callback-unavailable")
          return nil
        end
        return unpackValues(results, 2, results.n)
      end
      local originalDrawFx = ctx.drawFx
      local callbackInvoked = false
      local customDrawClaimed = false
      local customDrawReceipt
      local customDrawFailed = false
      ctx.drawFx = function(project, displayScale)
        callbackInvoked = true
        originalDrawFx(project, displayScale)
        local ok, claimed, receipt = pcall(drawFishingFx, world, state,
          project, displayScale)
        if not ok then
          customDrawFailed = true
          lastError = tostring(claimed)
          activeByWorld[world] = nil
          safeLog("warn", "Fishing cinematic frame failed open: %s", lastError)
        else
          customDrawClaimed = claimed == true
          customDrawReceipt = receipt
        end
      end
      local hadFieldPresentation = fieldPresentationActive(world)
      local results = drawWithoutNativeFishing(world, baseDrawWorld, ctx)
      ctx.drawFx = originalDrawFx
      if not results[1] then
        if hadFieldPresentation or fieldPresentationActive(world) then
          abortFieldPresentations(world)
          lastError = tostring(results[2])
          safeLog("warn",
            "Field cinematic frame failed open; Voxel retained: %s",
            lastError)
          return nil
        end
        error(results[2], 0)
      end
      if results[2] ~= nil and not customDrawClaimed then
        if not customDrawFailed then
          noteUnclaimedFrame(state, callbackInvoked
            and "projection-or-overlay-unavailable"
            or "overlay-callback-not-invoked")
        end
        return nil
      end
      if results[2] ~= nil and customDrawClaimed then
        state.drawFailOpenFrames = 0
        commitFishingDraw(state, customDrawReceipt)
      end
      return unpackValues(results, 2, results.n)
    end,
  })
  if not okPatch then
    return false, tostring(patchErr)
  end

  mod.exports.speciesCinematics = mod.exports.speciesCinematics or { apiVersion = 1 }
  local public = {
    active = true,
    version = M.VERSION,
    sourceVersion = M.VERSION,
    generation = 1,
    assetRoot = ASSET_DIR,
    nativeFallback = true,
    status = status,
    visualQa = visualQa,
  }
  mod.exports.speciesCinematics.fishing = public
  installed = true
  return true, public
end

return M
