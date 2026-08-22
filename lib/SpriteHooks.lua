-- Final sprite relay. The engine/KASC chain runs first; an active optional
-- pack and public VASC hook names then see that final choice, so load priority
-- cannot accidentally put old art back on top of a selected pack.

local V = ...
local Runtime = require("src.mods.Runtime")
local SpritePacks = V.require("SpritePacks")
local SpriteHooks = {}

local function identity(value) return value end

local function publicPath(name, current, ctx)
  if not (Runtime.wantsHook and Runtime.wantsHook(name)) then return current end
  local ok, value = pcall(Runtime.call, name, identity, current, ctx)
  return ok and type(value) == "string" and value ~= "" and value or current
end

local function path(kind, current, ctx, specific)
  current = SpritePacks.resolve(kind, current, ctx)
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
      local ctx = { kind="overworld", seed=seed, spriteDef=def }
      local chosen = SpritePacks.resolve("overworld", def, ctx)
      return publicDef(chosen, ctx)
    end
    return true
  end
  held = {}
  held.resolve = function(def, seed)
    local ctx = { kind="overworld", seed=seed, spriteDef=def }
    local chosen = SpritePacks.resolve("overworld", def, ctx)
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
  return installRenderer()
end

return SpriteHooks
