-- Final sprite relay. The engine/KASC chain runs first; an active optional
-- pack and public VASC hook names then see that final choice, so load priority
-- cannot accidentally put old art back on top of a selected pack.

local V = ...
local Runtime = require("src.mods.Runtime")
local SpritePacks = V.require("SpritePacks")
local LocalSprites = V.require("LocalSprites")
local SpriteHooks = {}

local function overridesEnabled()
  if LocalSprites.enabled and LocalSprites.enabled() then return true end
  local _, selected = SpritePacks.active()
  return selected ~= "base"
end

local function identity(value) return value end

local function publicPath(name, current, ctx)
  if not (Runtime.wantsHook and Runtime.wantsHook(name)) then return current end
  local ok, value = pcall(Runtime.call, name, identity, current, ctx)
  return ok and type(value) == "string" and value ~= "" and value or current
end

local function path(kind, current, ctx, specific)
  if not overridesEnabled() then return current end
  current = SpritePacks.resolve(kind, current, ctx)
  current = LocalSprites.resolve(kind, current, ctx)
  current = publicPath("vasc.sprite." .. kind, current, ctx)
  if specific then current = publicPath("vasc.sprite." .. specific, current, ctx) end
  return current
end

local function validDef(def)
  return type(def) == "table" and type(def.image) == "string"
         and def.image ~= "" and type(def.frames) == "number"
         and def.frames == math.floor(def.frames)
         and def.frames >= 1 and def.frames <= 256
end

local function overworldContext(def, seed)
  local spriteId = type(def) == "table" and def.id or nil
  local upper = type(spriteId) == "string" and string.upper(spriteId) or ""
  local state
  if upper:find("BIKE", 1, true) then state = "bike"
  elseif upper:find("FISH", 1, true) then state = "fishing"
  elseif upper:find("SURF", 1, true) then state = "surf"
  elseif upper:find("WALK", 1, true) then state = "walk" end
  local character = upper:match("_CRYSTAL_([A-Z0-9]+)_[A-Z0-9]+$")
  return {
    kind="overworld", seed=seed, spriteDef=def, spriteId=spriteId,
    player=seed == "player", playerState=state, playerCharacter=character,
  }
end

local function publicDef(current, ctx)
  if not (Runtime.wantsHook and Runtime.wantsHook("vasc.sprite.overworld")) then
    return current
  end
  local ok, value = pcall(Runtime.call, "vasc.sprite.overworld",
                          identity, current, ctx)
  if not ok then return current end
  if type(value) == "string" and value ~= "" then
    local out = {}
    for k, v in pairs(current) do out[k] = v end
    out.image = value
    return out
  end
  return validDef(value) and value or current
end

local function installRenderer()
  local Renderer = require("src.render.SpriteRenderer")
  local current = Renderer and Renderer.new
  if type(current) ~= "function" then return false end
  local held = rawget(Renderer, "voxelAscendantSpriteRelay")
  if held then
    if current ~= held.wrapper then return false end
    held.resolve = function(def, seed)
      if not overridesEnabled() then return def end
      local ctx = overworldContext(def, seed)
      local chosen = SpritePacks.resolve("overworld", def, ctx)
      chosen = LocalSprites.resolve("overworld", chosen, ctx)
      return publicDef(chosen, ctx)
    end
    return true
  end
  held = {}
  held.resolve = function(def, seed)
    if not overridesEnabled() then return def end
    local ctx = overworldContext(def, seed)
    local chosen = SpritePacks.resolve("overworld", def, ctx)
    chosen = LocalSprites.resolve("overworld", chosen, ctx)
    return publicDef(chosen, ctx)
  end
  held.wrapper = function(def, seed)
    local ok, chosen = pcall(held.resolve, def, seed)
    return current(ok and validDef(chosen) and chosen or def, seed)
  end
  Renderer.new = held.wrapper
  Renderer.voxelAscendantSpriteRelay = held
  return true
end

-- Enemy trainer portraits do not pass through player.sprite: exact engine
-- builds resolve them through BattleState.trainerPicPath before decoding the
-- image.  Relay that final path through the same live local/pack/public chain.
-- The wrapper is identity-held so hot reload updates the resolver without
-- stacking, and an unexpected foreign replacement is left untouched.
local function installTrainerPictures()
  local ok, BattleState = pcall(require, "src.battle.BattleState")
  if not ok or type(BattleState) ~= "table"
     or type(BattleState.trainerPicPath) ~= "function" then return false end
  local current = BattleState.trainerPicPath
  local held = rawget(BattleState, "voxelAscendantTrainerSpriteRelay")
  if held then
    if current ~= held.wrapper then return false end
    held.resolve = function(value, ctx)
      return path("trainer", value, ctx, nil)
    end
    return true
  end
  held = {}
  held.resolve = function(value, ctx)
    return path("trainer", value, ctx, nil)
  end
  held.wrapper = function(data, trainer, oppClass, partyIndex)
    local value = current(data, trainer, oppClass, partyIndex)
    local okResolve, chosen = pcall(held.resolve, value, {
      kind="battle", trainer=trainer, trainerId=oppClass,
      oppClass=oppClass, partyIndex=partyIndex, data=data,
    })
    return okResolve and type(chosen) == "string" and chosen ~= ""
           and chosen or value
  end
  BattleState.trainerPicPath = held.wrapper
  BattleState.voxelAscendantTrainerSpriteRelay = held
  return true
end

function SpriteHooks.install(mod)
  if not (mod and mod.hooks and type(mod.hooks.wrap) == "function") then
    return false
  end
  mod.hooks:wrap("pokemon.sprite", function(next, current, ctx)
    local out = next(current, ctx)
    local specific = ctx and ctx.kind == "battle" and "battle"
                     or ctx and ctx.kind == "dex" and "dex"
                     or ctx and ctx.kind == "overworld" and "overworld_pokemon"
    return path("pokemon", out, ctx, specific)
  end, 1000000)
  mod.hooks:wrap("player.sprite", function(next, current, ctx)
    local out = next(current, ctx)
    return path("player", out, ctx,
                ctx and ctx.kind == "battle" and "trainer" or nil)
  end, 1000000)
  mod.hooks:wrap("pokemon.icon", function(next, current, ctx)
    return path("icon", next(current, ctx), ctx, nil)
  end, 1000000)
  return installRenderer() and installTrainerPictures()
end

return SpriteHooks
