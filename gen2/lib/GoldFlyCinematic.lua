-- Full Gold/Silver/Crystal Fly presentation for VASC's voxel renderer.
--
-- Crystal remains the sole owner of Fly eligibility, destination selection,
-- timing, callbacks and warps.  This module only draws the accepted native
-- World.flyAnim phases.  It intentionally lives in the Gen-2 tree: Kanto and
-- Johto have equivalent choreography, but never share mutable runtime state.
local V = ...

local M = {
  VERSION = "1.0.0",
  drawFrames = 0,
  lastError = nil,
  lastBeat = nil,
}

local imageCache = {}
local resourceCache = setmetatable({}, { __mode = "k" })

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

local function cubic(a, b, c, d, t)
  local u = 1 - t
  return u * u * u * a + 3 * u * u * t * b
    + 3 * u * t * t * c + t * t * t * d
end

local function arc(t)
  if t <= 0 or t >= 1 then return 0 end
  return math.sin(t * math.pi)
end

local function setColor(g, r, gg, b, a)
  g.setColor(r, gg, b, a == nil and 1 or a)
end

local function imagePath(rel)
  local assets = V and V.mod and V.mod.assets
  if assets and type(assets.path) == "function" then
    local ok, path = pcall(assets.path, assets, rel)
    if ok and type(path) == "string" then return path end
  end
  return rel
end

local function loadExactImage(g, rel)
  local cached = imageCache[rel]
  if cached then return cached.image, cached.path end
  local path = imagePath(rel)
  local file = io and io.open and io.open(path, "rb") or nil
  local image
  if file and love and love.filesystem
      and type(love.filesystem.newFileData) == "function" then
    local bytes = file:read("*a")
    file:close()
    local safeName = ("vasc-gen2-fly-" .. rel):gsub("[^%w%._%-]", "_")
    local okData, data = pcall(love.filesystem.newFileData, bytes, safeName)
    if okData and data then
      local okImage, loaded = pcall(g.newImage, data)
      if okImage then image = loaded end
    end
  elseif file then
    file:close()
  end
  if not image then
    local okImage, loaded = pcall(g.newImage, path)
    if okImage then image = loaded end
  end
  if image and type(image.setFilter) == "function" then
    image:setFilter("nearest", "nearest")
  end
  if image then imageCache[rel] = { image = image, path = path } end
  return image, path
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
  local value = def.sourceDex or def.nationalDex or def.dexNumber
    or def.dex or def.number or def.index
  local dex = tonumber(value)
  if not dex or dex ~= math.floor(dex) or dex < 1 or dex > 386 then return nil end
  return dex
end

local function monHeight(world, mon)
  local def = pokemonDef(world, mon) or {}
  local entry = def.dexEntry or {}
  local metres = tonumber(entry.heightM)
  if not metres then
    local inches = (tonumber(entry.heightFt) or 0) * 12
      + (tonumber(entry.heightIn) or 0)
    if inches > 0 then metres = inches * 0.0254 end
  end
  return metres or 1
end

local FORCE_MOUNT = {
  [6] = true, [18] = true, [130] = true, [142] = true, [149] = true,
  [249] = true, [250] = true,
}

local function profileFor(world, mon, fieldKit)
  if fieldKit then return { mode = "jetpack", dex = nil } end
  local dex = dexFor(world, mon)
  local mount = FORCE_MOUNT[dex] == true or monHeight(world, mon) >= 1.4
  return {
    mode = mount and "mount" or "carry",
    dex = dex,
    monScale = (dex == 249 or dex == 250) and 1.12 or 1,
  }
end

local function normalTrainer(world)
  if not (world and world.player and world.sprites) then return nil end
  local okMoves, FieldMoves = pcall(require, "src.world.gen2.FieldMoves")
  local okRenderer, SpriteRenderer = pcall(require, "src.render.SpriteRenderer")
  if not (okMoves and okRenderer and SpriteRenderer
      and type(SpriteRenderer.new) == "function") then return nil end
  local gender
  if type(world.playerGender) == "function" then
    local ok, value = pcall(world.playerGender, world)
    if ok then gender = value end
  end
  local name = type(FieldMoves.playerSprite) == "function"
    and FieldMoves.playerSprite(gender) or nil
  local def = name and world.sprites[name] or nil
  if not (def and type(def.image) == "string") then return nil end
  local okNew, renderer = pcall(SpriteRenderer.new, def, "vasc-gen2-fly-cinematic")
  if not (okNew and renderer) then return nil end
  if type(world.applySpritePalette) == "function" then
    pcall(world.applySpritePalette, world, { sprite = renderer, spriteDef = def })
  end
  return renderer
end

local function resources(world, mon, fieldKit)
  local key = fieldKit and "JETPACK"
    or (tostring(mon and mon.species) .. ":" .. tostring(shiny(mon)))
  local held = resourceCache[world]
  if held and held.key == key then return held end
  local trainer = normalTrainer(world)
  if not (trainer and trainer.frames and type(trainer.resolveImage) == "function") then
    return nil, "trainer renderer unavailable"
  end
  local okTrainer, trainerImage = pcall(trainer.resolveImage, trainer)
  if not (okTrainer and trainerImage) then return nil, "trainer image unavailable" end
  local out = { key = key, trainer = trainer, trainerImage = trainerImage }
  if not fieldKit then
    local dex = dexFor(world, mon)
    if not dex then return nil, "Fly user has no artwork dex" end
    local rel = string.format("assets/species_cinematics/directional/%03d-%s.png",
      dex, shiny(mon) and "shiny" or "normal")
    local image, path = loadExactImage(love.graphics, rel)
    if not (image and type(image.getDimensions) == "function") then
      return nil, "directional Fly atlas unavailable"
    end
    local w, h = image:getDimensions()
    if w ~= h or w % 4 ~= 0 then return nil, "invalid directional Fly atlas" end
    out.monImage, out.monCell, out.monW, out.monH = image, w / 4, w, h
    out.sourceAtlas = path
  end
  resourceCache[world] = out
  return out
end

local TRAINER_FRAME = { down = 0, up = 1, left = 2, right = 2 }

local function drawTrainer(g, res, footX, footY, scale, facing, alpha)
  local frame = res.trainer.frames[TRAINER_FRAME[facing] or 0]
    or res.trainer.frames[0]
  if not frame then return end
  local sx = scale
  local x = footX - 8 * scale
  if facing == "right" then x, sx = footX + 8 * scale, -scale end
  setColor(g, 1, 1, 1, alpha or 1)
  g.draw(res.trainerImage, frame, math.floor(x + 0.5),
    math.floor(footY - 20 * scale + 0.5), 0, sx, scale)
end

local ROW = { down = 0, left = 1, right = 2, up = 3 }

local function drawMon(g, res, centerX, footY, target, direction, col, alpha)
  if not res.monImage then return end
  local row = ROW[direction] or ROW.left
  col = math.floor(tonumber(col) or 0) % 4
  local q = g.newQuad(col * res.monCell, row * res.monCell,
    res.monCell, res.monCell, res.monW, res.monH)
  local s = target / res.monCell
  setColor(g, 1, 1, 1, alpha or 1)
  g.draw(res.monImage, q, math.floor(centerX - target / 2 + 0.5),
    math.floor(footY - target - target * 0.10 + 0.5), 0, s, s)
end

local BALL = {
  "..KKK..", ".KRRRK.", "KRRRRRK", "KKKWKKK",
  "KWWWWWK", ".KWWWK.", "..KKK..",
}

local function drawBall(g, x, y, scale, alpha)
  local unit = math.max(1, math.floor(scale * 0.42 + 0.5))
  local colors = { K = { .04, .05, .06 }, R = { .92, .10, .08 }, W = { 1, 1, 1 } }
  local ox, oy = math.floor(x - 3.5 * unit), math.floor(y - 3.5 * unit)
  for row, line in ipairs(BALL) do
    for col = 1, #line do
      local c = colors[line:sub(col, col)]
      if c then
        setColor(g, c[1], c[2], c[3], alpha or 1)
        g.rectangle("fill", ox + (col - 1) * unit,
          oy + (row - 1) * unit, unit, unit)
      end
    end
  end
end

local function drawShadow(g, x, y, radius, scale, alpha)
  setColor(g, .02, .04, .06, .30 * (alpha or 1))
  g.ellipse("fill", x, y, radius * scale, 3.2 * scale)
end

local function drawSummon(g, x, y, scale, progress, alpha)
  setColor(g, 1, .77, .22, .8 * (alpha or 1))
  for i = 0, 7 do
    local a = i * math.pi / 4 + progress * math.pi
    local r = (5 + 10 * progress) * scale
    g.rectangle("fill", math.floor(x + math.cos(a) * r),
      math.floor(y + math.sin(a) * r), math.max(1, scale), math.max(1, scale))
  end
end

local function jetpackRect(g, x, y, w, h, scale, color, alpha)
  setColor(g, color[1], color[2], color[3], alpha or 1)
  g.rectangle("fill", math.floor(x), math.floor(y),
    math.max(1, math.floor(w * scale)), math.max(1, math.floor(h * scale)))
end

local JET_DARK = { .12, .16, .20 }
local JET_STEEL = { .64, .72, .78 }
local JET_LIGHT = { .86, .92, .92 }
local JET_BLUE = { .18, .42, .62 }
local JET_ORANGE = { .96, .35, .05 }
local JET_YELLOW = { 1, .88, .18 }

local function drawPixelLine(g, x1, y1, x2, y2, scale, color, alpha)
  local unit = math.max(1, math.floor(scale + .5))
  local distance = math.max(math.abs(x2 - x1), math.abs(y2 - y1))
  local steps = math.max(1, math.ceil(distance / unit))
  setColor(g, color[1], color[2], color[3], alpha or 1)
  for step = 0, steps do
    local p = step / steps
    g.rectangle("fill", math.floor(lerp(x1, x2, p) + .5),
      math.floor(lerp(y1, y2, p) + .5), unit, unit)
  end
end

local function drawJetpackBody(g, x, footY, scale, deploy, alpha)
  deploy = clamp(deploy, 0, 1)
  if deploy <= .05 then return end
  local extension = smooth(deploy)
  local top = footY - (8 + 9 * extension) * scale
  local tankHeight = 5 + 7 * extension
  jetpackRect(g, x - 6 * scale, top + 2 * scale, 12, tankHeight,
    scale, JET_DARK, alpha)
  jetpackRect(g, x - 4 * scale, top + 3 * scale, 8,
    math.max(2, tankHeight - 2), scale, JET_ORANGE, alpha)
  jetpackRect(g, x - scale, top + 4 * scale, 2,
    math.max(1, tankHeight - 4), scale, JET_YELLOW, alpha)
  for _, side in ipairs({ -1, 1 }) do
    local tankX = x + side * 7 * scale
    jetpackRect(g, tankX - 3 * scale, top, 6, tankHeight,
      scale, JET_DARK, alpha)
    jetpackRect(g, tankX - 2 * scale, top + scale, 4,
      math.max(2, tankHeight - 2), scale, JET_STEEL, alpha)
    jetpackRect(g, tankX - scale, top + 2 * scale, 1,
      math.max(1, tankHeight - 4), scale, JET_LIGHT, alpha)
    jetpackRect(g, tankX + scale, top + 2 * scale, 1,
      math.max(1, tankHeight - 4), scale, JET_BLUE, alpha)
    jetpackRect(g, tankX - 2 * scale, top - 2 * scale, 4, 2,
      scale, JET_DARK, alpha)
    jetpackRect(g, tankX - 2 * scale, top + tankHeight * scale, 4, 3,
      scale, JET_DARK, alpha)
  end
end

local function drawJetpackExhaust(g, x, footY, scale, thrust, pulse, alpha)
  thrust = clamp(thrust, 0, 1)
  if thrust <= .03 then return end
  local flicker = math.floor((math.sin(pulse or 0) + 1) * 1.5 + .5)
  local flame = 4 + math.floor(thrust * 7 + .5) + flicker
  local nozzleY = footY - 3 * scale
  for _, side in ipairs({ -1, 1 }) do
    local nozzleX = x + side * 7 * scale
    jetpackRect(g, nozzleX - 2 * scale, nozzleY, 4, 3,
      scale, JET_DARK, alpha)
    jetpackRect(g, nozzleX - 1.5 * scale, footY - scale, 3, flame,
      scale, JET_ORANGE, alpha)
    jetpackRect(g, nozzleX - .5 * scale, footY, 1,
      math.max(2, flame - 3), scale, JET_YELLOW, alpha)
    jetpackRect(g, nozzleX - .5 * scale, footY, 1,
      math.max(1, math.floor((flame - 4) * .45)), scale, JET_LIGHT, alpha)
  end
end

local function drawJetpackStraps(g, x, footY, scale, deploy, alpha)
  deploy = clamp(deploy, 0, 1)
  alpha = (alpha or 1) * deploy
  if alpha <= .05 then return end
  drawPixelLine(g, x - 5 * scale, footY - 16 * scale,
    x - 6 * scale, footY - 8 * scale, scale, JET_DARK, alpha)
  drawPixelLine(g, x + 5 * scale, footY - 16 * scale,
    x + 6 * scale, footY - 8 * scale, scale, JET_DARK, alpha)
  drawPixelLine(g, x - 4 * scale, footY - 15 * scale,
    x - 5 * scale, footY - 9 * scale, scale, JET_ORANGE, alpha)
  drawPixelLine(g, x + 4 * scale, footY - 15 * scale,
    x + 5 * scale, footY - 9 * scale, scale, JET_ORANGE, alpha)
  jetpackRect(g, x - 7 * scale, footY - 8 * scale, 14, 3,
    scale, JET_DARK, alpha)
  jetpackRect(g, x - 6 * scale, footY - 7 * scale, 12, 1,
    scale, JET_ORANGE, alpha)
end

local function drawDust(g, x, y, scale, amount, pulse)
  if amount <= 0 then return end
  for i = -2, 2 do
    local drift = (i * 7 + math.sin(pulse + i) * 3) * scale
    local r = (2.5 + math.abs(i) * .5) * scale
    setColor(g, .82, .86, .89, .30 * amount)
    g.circle("fill", x + drift, y - math.abs(i) * scale, r)
  end
end

-- Test-visible beat classification.  The live draw uses the same function,
-- so a receipt cannot claim a choreography phase the renderer did not enter.
local function beatFor(phase, t, fieldKit, mode)
  t = tonumber(t) or 0
  if fieldKit then
    if phase == "to" then
      if t < 42 then return "jetpack-land" end
      if t < 56 then return "jetpack-shutdown" end
      return "jetpack-stowed"
    end
    if t < 24 then return "jetpack-deploy" end
    if t < 64 then return "jetpack-ignite" end
    return "jetpack-ascent"
  end
  if phase == "to" then
    if t < 42 then return "arrival" end
    if t < 56 then return mode == "mount" and "dismount" or "release" end
    return "recall"
  end
  if t < 14 then return "ball-throw" end
  if t < 30 then return "summon" end
  if t < 64 then return mode == "mount" and "mount-jump" or "carry-grab" end
  return "ascent"
end

function M._beatForTests(phase, t, fieldKit, mode)
  return beatFor(phase, t, fieldKit == true, mode or "mount")
end

local function drawPokemonFlight(g, world, fa, record, res, profile,
                                 footX, footY, scale)
  local t = tonumber(fa.t) or 0
  local phase = fa.phase == "to" and "to" or "from"
  local target = 34 * scale * (profile.monScale or 1)
  local baseX, baseY = footX + 29 * scale, footY
  local col = math.floor(t / 6) % 4
  local riderX, riderY, riderFacing = footX, footY, "right"
  local monX, monY = baseX, baseY
  local playerBehind = false

  if phase == "from" then
    local summon = smooth((t - 11) / 12)
    local rising = smooth((t - 64) / 56)
    if profile.mode == "mount" then
      local jumpRaw = clamp((t - 30) / 30, 0, 1)
      local jump = smooth(jumpRaw)
      local seatX, seatY = baseX - 2 * scale, baseY - 22 * scale
      riderX = lerp(footX, seatX, jump)
      riderY = lerp(footY, seatY, jump) - arc(jumpRaw) * 15 * scale
      riderFacing = t < 51 and "right" or "left"
      playerBehind = t >= 48
      if t >= 64 then
        monX = baseX + (tonumber(fa.xoff) or 0) * scale * .35
        monY = baseY + (tonumber(fa.y) or 0) * scale
          - 8 * scale * rising
        riderX, riderY = monX - 2 * scale, monY - 22 * scale
      end
    else
      local approach = smooth((t - 28) / 22)
      monX = lerp(baseX, footX + 5 * scale, approach)
      monY = lerp(baseY, footY - 30 * scale, approach)
      if t >= 48 then
        riderX, riderY = monX - 2 * scale, monY + 28 * scale
        riderFacing, playerBehind = "down", true
      end
      if t >= 64 then
        monX = footX + 5 * scale + (tonumber(fa.xoff) or 0) * scale * .35
        monY = footY - 30 * scale + (tonumber(fa.y) or 0) * scale
        riderX, riderY = monX - 2 * scale, monY + 28 * scale
      end
    end

    drawShadow(g, baseX, baseY + scale, 14, scale,
      summon * (1 - rising * .8))
    if playerBehind then drawTrainer(g, res, riderX, riderY, scale, riderFacing, 1) end
    drawMon(g, res, monX, monY, target, t < 26 and "down" or "left",
      col, summon)
    if not playerBehind then drawTrainer(g, res, riderX, riderY, scale, riderFacing, 1) end

    local throw = smooth(t / 11)
    local handX, handY = footX + 3 * scale, footY - 14 * scale
    local impactX, impactY = baseX - 9 * scale, baseY - 20 * scale
    if t < 15 then
      drawBall(g, lerp(handX, impactX, throw),
        lerp(handY, impactY, throw) - arc(throw) * 10 * scale,
        scale, 1 - smooth((t - 12) / 3))
    end
    if t >= 8 and t < 29 then
      drawSummon(g, impactX, impactY, scale, smooth((t - 8) / 20),
        1 - smooth((t - 20) / 9))
    end
  else
    local descend = smooth(t / 42)
    monX = baseX + (tonumber(fa.xoff) or 0) * scale * .28
    monY = baseY + (tonumber(fa.y) or 0) * scale
    local dismountRaw = clamp((t - 42) / 14, 0, 1)
    local dismount = smooth(dismountRaw)
    if profile.mode == "mount" then
      riderX = lerp(monX - 2 * scale, footX, dismount)
      riderY = lerp(monY - 22 * scale, footY, dismount)
        - arc(dismountRaw) * 13 * scale
      riderFacing = dismount < .8 and "left" or "down"
    else
      riderX = lerp(monX - 2 * scale, footX, dismount)
      riderY = lerp(monY + 28 * scale, footY, dismount)
      riderFacing = "down"
    end
    local recall = smooth((t - 56) / 7)
    drawShadow(g, baseX, baseY + scale, 14, scale, descend * (1 - recall))
    drawTrainer(g, res, riderX, riderY, scale, riderFacing, 1)
    drawMon(g, res, monX, monY, target, t < 42 and "left" or "down",
      col, 1 - recall)
    if t >= 53 then
      local handX, handY = footX + 3 * scale, footY - 14 * scale
      local impactX, impactY = baseX - 9 * scale, baseY - 20 * scale
      local throw = smooth((t - 53) / 7)
      drawBall(g, lerp(handX, impactX, throw),
        lerp(handY, impactY, throw) - arc(throw) * 8 * scale, scale, 1)
      if recall > 0 then drawSummon(g, impactX, impactY, scale, recall, 1 - recall) end
    end
  end
end

local function drawJetpackFlight(g, fa, res, footX, footY, scale)
  local t = tonumber(fa.t) or 0
  local phase = fa.phase == "to" and "to" or "from"
  local riderX, riderY = footX, footY
  local deploy, thrust, dust = 0, 0, 0
  if phase == "from" then
    deploy = smooth(t / 24)
    thrust = smooth((t - 24) / 22)
    dust = thrust * (1 - smooth((t - 64) / 18))
    if t >= 64 then
      riderX = footX + (tonumber(fa.xoff) or 0) * scale * .18
      riderY = footY + (tonumber(fa.y) or 0) * scale
    end
  else
    deploy = 1 - smooth((t - 42) / 14)
    thrust = 1 - smooth((t - 38) / 18)
    dust = smooth((t - 22) / 15) * (1 - smooth((t - 52) / 10))
    riderX = footX + (tonumber(fa.xoff) or 0) * scale * .18
    riderY = footY + (tonumber(fa.y) or 0) * scale
  end
  drawShadow(g, footX, footY + scale, 10, scale,
    1 - clamp(math.abs(riderY - footY) / (84 * scale), 0, .9))
  drawDust(g, footX, footY + scale, scale, dust, t / 3)
  drawJetpackExhaust(g, riderX, riderY, scale, thrust, t / 2, 1)
  drawJetpackBody(g, riderX, riderY, scale, deploy, 1)
  drawTrainer(g, res, riderX, riderY, scale,
    phase == "from" and t < 24 and "up" or "down", 1)
  drawJetpackStraps(g, riderX, riderY, scale, deploy, 1)
end

function M.draw(world, record, canvas, ctx, VoxelScene, Voxel3D)
  local fa = world and world.flyAnim
  local g = love and love.graphics
  if not fa then M.lastError = "native world.flyAnim missing"; return false end
  if not record then M.lastError = "Fly presentation record missing"; return false end
  if not canvas then M.lastError = "voxel scene canvas missing"; return false end
  if not g then M.lastError = "LOVE graphics unavailable"; return false end
  if not (Voxel3D and type(Voxel3D.project) == "function") then
    M.lastError = "Voxel3D projector unavailable"; return false
  end
  local fieldKit = record.fieldKit == true
  local res, err = resources(world, record.mon, fieldKit)
  if not res then M.lastError = tostring(err); return false end
  local profile = profileFor(world, record.mon, fieldKit)
  local ground = 0
  if VoxelScene and type(VoxelScene.groundAt) == "function"
      and world.map and world.player then
    local ok, value = pcall(VoxelScene.groundAt, world.map,
      world.player.cellX, world.player.cellY)
    if ok then ground = tonumber(value) or 0 end
  end
  local footX, footY = Voxel3D.project((tonumber(fa.px) or 0) + 8,
    ground, (tonumber(fa.py) or 0) + 16)
  if not footX then M.lastError = "Fly ground point behind voxel camera"; return false end
  local scale = clamp(tonumber(ctx and ctx.scale) or 1, 1, 12)
  local previous = type(g.getCanvas) == "function" and g.getCanvas() or nil
  local pushed = false
  local ok, drawErr = pcall(function()
    g.push("all"); pushed = true
    g.setCanvas(canvas)
    if g.origin then g.origin() end
    if g.setShader then g.setShader() end
    if g.setDepthMode then g.setDepthMode() end
    if g.setBlendMode then g.setBlendMode("alpha") end
    if fieldKit then
      drawJetpackFlight(g, fa, res, footX, footY, scale)
    else
      drawPokemonFlight(g, world, fa, record, res, profile,
        footX, footY, scale)
    end
  end)
  if pushed then pcall(g.pop) end
  if previous then pcall(g.setCanvas, previous) else pcall(g.setCanvas) end
  if not ok then M.lastError = tostring(drawErr); return false end
  M.drawFrames = M.drawFrames + 1
  M.lastBeat = beatFor(fa.phase, fa.t, fieldKit, profile.mode)
  M.lastError = nil
  return true
end

function M.status()
  return {
    version = M.VERSION,
    drawFrames = M.drawFrames,
    lastBeat = M.lastBeat,
    lastError = M.lastError,
  }
end

return M
