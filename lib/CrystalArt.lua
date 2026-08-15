-- Voxel Ascendant's self-contained Gen-I Crystal battle-art provider.
--
-- The files live in this package.  Kanto Ascendant does not lend assets at
-- runtime and is never modified: when it is loaded, this provider yields so
-- KASC remains the sole owner of forms, shinies and its extended catalogue.
-- Other sprite hooks also keep priority because we call `next` first and
-- replace only an unchanged native answer.

local V = ...

local ModSetting = V.require("ModSetting")
local timing = V.data("crystal_gen1_timing")
local mod = V.mod
local unpackValues = table.unpack or unpack

local function packValues(...)
  return { n = select("#", ...), ... }
end

local CrystalArt = {
  selected = setmetatable({}, { __mode = "k" }),
  imageCache = {},
}

CrystalArt.setting = ModSetting.new(
  "battle_art", "BATTLE ART",
  { "crystal", "native" },
  { "CRYSTAL", "GEN I" })

CrystalArt.motionSetting = ModSetting.new(
  "crystal_motion", "CRYSTAL MOTION",
  { true, false },
  { "ON", "OFF" })

local function loaded(id)
  if not (mod and type(mod.find) == "function") then return false end
  local ok, handle = pcall(mod.find, id)
  return ok and type(handle) == "table"
    and type(handle.exports) == "table"
end

function CrystalArt.mustYield()
  return loaded("kanto_ascendant")
    or loaded("crystal_animated_sprites_with_shiny_visuals")
end

local function dexFor(ctx)
  local def = ctx and ctx.data and ctx.data.pokemon
    and ctx.data.pokemon[ctx.species]
  local dex = def and tonumber(def.dex)
  if dex and dex >= 1 and dex <= 151 then return dex end
  return nil
end

local function isShiny(mon)
  if not mon then return false end
  if mon.shiny ~= nil then return mon.shiny and true or false end
  local ok, Stats = pcall(require, "src.pokemon.Stats")
  return ok and type(Stats.isShiny) == "function"
    and Stats.isShiny(mon.dvs) or false
end

local function relative(side, variant, dex, frame)
  return ("assets/crystal_gen1/%s/%s/%d/%03d.png")
    :format(side, variant, dex, frame or 1)
end

local function exists(path)
  return type(path) == "string" and mod:read(path) ~= nil
end

local function readPixels(image)
  if not (image and love and love.graphics) then return nil end
  local okData, data = pcall(image.getData, image)
  if okData and data and data.clone then
    local okClone, clone = pcall(data.clone, data)
    if okClone then return clone end
  end
  local ok, out = pcall(function()
    local g = love.graphics
    local w, h = image:getDimensions()
    local previous = g.getCanvas and g.getCanvas() or nil
    local canvas = g.newCanvas(w, h, { dpiscale = 1 })
    g.setCanvas(canvas)
    g.clear(0, 0, 0, 0)
    g.setColor(1, 1, 1, 1)
    g.draw(image, 0, 0)
    if previous then g.setCanvas(previous) else g.setCanvas() end
    return canvas:newImageData()
  end)
  return ok and out or nil
end

-- Crystal sheets carry transparent ground padding.  The engine measures
-- frame one, but later animation frames enter as Images; crop their bottom
-- (and the rear card's empty left edge) so every frame keeps the same feet.
local function preparedImage(path, side)
  local key = path .. "#" .. side
  if CrystalArt.imageCache[key] then return CrystalArt.imageCache[key] end
  if not (love and love.graphics and love.graphics.newImage) then return nil end
  local ok, image = pcall(love.graphics.newImage, mod.path .. "/" .. path)
  if not (ok and image) then return nil end
  local data = readPixels(image)
  if data and love.image and love.image.newImageData then
    local w, h = data:getDimensions()
    local bottom = h - 1
    while bottom >= 0 do
      local opaque = false
      for x = 0, w - 1 do
        local _, _, _, a = data:getPixel(x, bottom)
        if a > 0 then opaque = true; break end
      end
      if opaque then break end
      bottom = bottom - 1
    end
    local left = 0
    if side == "back" and bottom >= 0 then
      while left < w do
        local opaque = false
        for y = 0, bottom do
          local _, _, _, a = data:getPixel(left, y)
          if a > 0 then opaque = true; break end
        end
        if opaque then break end
        left = left + 1
      end
    end
    if bottom >= 0 and (bottom < h - 1 or left > 0) then
      local okCrop, cropped = pcall(love.image.newImageData,
        w - left, bottom + 1)
      if okCrop and cropped then
        local copied = pcall(function()
          for y = 0, bottom do
            for x = left, w - 1 do
              cropped:setPixel(x - left, y, data:getPixel(x, y))
            end
          end
        end)
        if copied then
          local okImage, ready = pcall(love.graphics.newImage, cropped)
          if okImage and ready then image = ready end
        end
      end
    end
  end
  if image.setFilter then image:setFilter("nearest", "nearest") end
  CrystalArt.imageCache[key] = image
  return image
end

function CrystalArt.resolve(nextFn, path, ctx)
  local selected = nextFn(path, ctx)
  if CrystalArt.setting:get() ~= "crystal" or CrystalArt.mustYield()
      or not (ctx and ctx.kind == "battle") then
    if ctx and ctx.mon then CrystalArt.selected[ctx.mon] = nil end
    return selected
  end
  -- A different art provider changed the path downstream.  Its answer wins.
  if selected ~= path then return selected end
  local dex = dexFor(ctx)
  local mon = ctx.mon
  if not (dex and mon) or mon._ascMegaForm or mon.ascMegaForm then return selected end
  local side = ctx.side == "back" and "back" or "front"
  local variant = isShiny(mon) and "shiny" or "normal"
  local first = relative(side, variant, dex, 1)
  if not exists(first) then return selected end

  local durations = timing and timing[variant]
    and timing[variant][tostring(dex)] or nil
  local animated = side == "front"
    and CrystalArt.motionSetting:get() ~= false
    and type(durations) == "table" and #durations > 1
    and exists(relative(side, variant, dex, 2))
  CrystalArt.selected[mon] = animated and {
    species = ctx.species, dex = dex, side = side, variant = variant,
    durations = durations, frame = 1, elapsed = 0,
  } or nil
  ctx.trueColor = true
  return mod.path .. "/" .. first
end

local function updateBattler(battler, dt)
  local mon = battler and battler.mon
  local state = mon and CrystalArt.selected[mon] or nil
  if not state or state.species ~= mon.species
      or CrystalArt.setting:get() ~= "crystal" or CrystalArt.mustYield() then
    if mon then CrystalArt.selected[mon] = nil end
    return
  end
  state.elapsed = state.elapsed + (tonumber(dt) or 1 / 60) * 1000
  local changed, guard = false, 0
  while state.elapsed >= (state.durations[state.frame] or 100)
      and guard < 64 do
    state.elapsed = state.elapsed - (state.durations[state.frame] or 100)
    state.frame = state.frame % #state.durations + 1
    changed, guard = true, guard + 1
  end
  if not changed then return end
  local path = relative(state.side, state.variant, state.dex, state.frame)
  if not exists(path) then state.frame = 1; path = relative(
    state.side, state.variant, state.dex, 1) end
  local image = preparedImage(path, state.side)
  if image then battler.sprite = image end
end

function CrystalArt.updateBattle(battle, dt)
  if not battle then return end
  if battle.enemy and not battle.showEnemyTrainer and not battle.enemySendingOut then
    updateBattler(battle.enemy, dt)
  end
  if battle.player and not battle.showPlayerBack and not battle.sendingOut then
    updateBattler(battle.player, dt)
  end
end

local function trainerName(path)
  if type(path) ~= "string" then return nil end
  local name = path:match("([^/\\]+)%.png$") or path:match("([^/\\]+)$")
  return name and name:lower() or nil
end

local function trainerImage(name)
  if not name then return nil end
  local rel = "assets/crystal_gen1/trainers/normal/" .. name .. ".png"
  if not exists(rel) then return nil end
  local key = "trainer#" .. rel
  if CrystalArt.imageCache[key] then return CrystalArt.imageCache[key] end
  if not (love and love.graphics and love.graphics.newImage) then return nil end
  local ok, image = pcall(love.graphics.newImage, mod.path .. "/" .. rel)
  if not (ok and image) then return nil end
  if image.setFilter then image:setFilter("nearest", "nearest") end
  CrystalArt.imageCache[key] = image
  return image
end

function CrystalArt.install()
  mod.hooks:wrap("pokemon.sprite", CrystalArt.resolve, -100)

  local ok, BattleState = pcall(require, "src.battle.BattleState")
  if not ok or type(BattleState) ~= "table" then return false end
  BattleState._voxelAscendantCrystalArt = CrystalArt

  if type(BattleState.update) == "function"
      and not BattleState._voxelAscendantCrystalUpdateWrapped then
    local inner = BattleState.update
    BattleState.update = function(battle, dt, ...)
      local results = packValues(inner(battle, dt, ...))
      local controller = BattleState._voxelAscendantCrystalArt
      if controller then controller.updateBattle(battle, dt) end
      return unpackValues(results, 1, results.n)
    end
    BattleState._voxelAscendantCrystalUpdateWrapped = true
  end

  if type(BattleState.resolveBattleScale) == "function"
      and not BattleState._voxelAscendantCrystalScaleWrapped then
    local inner = BattleState.resolveBattleScale
    BattleState.resolveBattleScale = function(data, side, path, species, ...)
      if type(path) == "string"
          and path:find("/assets/crystal_gen1/back/", 1, true) then
        return 1
      end
      return inner(data, side, path, species, ...)
    end
    BattleState._voxelAscendantCrystalScaleWrapped = true
  end

  if type(BattleState.trainerSprite) == "function"
      and type(BattleState.trainerPicPath) == "function"
      and not BattleState._voxelAscendantCrystalTrainerWrapped then
    local inner = BattleState.trainerSprite
    BattleState.trainerSprite = function(data, trainer, oppClass, partyIndex, ...)
      local native = inner(data, trainer, oppClass, partyIndex, ...)
      local controller = BattleState._voxelAscendantCrystalArt
      if not controller or controller.setting:get() ~= "crystal"
          or controller.mustYield() or (trainer and trainer.trueColor) then
        return native
      end
      local path = BattleState.trainerPicPath(data, trainer, oppClass, partyIndex)
      return trainerImage(trainerName(path)) or native
    end
    BattleState._voxelAscendantCrystalTrainerWrapped = true
  end
  return true
end

return CrystalArt
