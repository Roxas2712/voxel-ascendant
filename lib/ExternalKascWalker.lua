-- Resolve Gen-1's ordinary 3-D player card from Kanto Ascendant's registered
-- walker without replacing the engine/KASC sprite used by the native 2-D
-- world. Bike, Surf, fishing, PokePC control and Fly keep their own
-- presentation paths; this module owns only normal WALK inside VASC's scene.
--
-- KASC registers three sprite definitions, not three player actors. VASC
-- selects exactly one of those definitions for the one local player's 3-D
-- pose. If KASC is absent or the loader rejected it, the live actor renderer
-- remains usable for that pose: optional artwork must never suppress the
-- already completed Voxel canvas.

local V = ...
local ExternalKascWalker = {}

local APPROVED = {
  RED = {
    id = "SPRITE_KA_CRYSTAL_RED_WALK",
    stem = "red",
    lanes = { "", "fallback_walk_v1/", "fallback_walk_v2/" },
  },
  BLUE = {
    id = "SPRITE_KA_CRYSTAL_BLUE_WALK",
    stem = "blue",
    lanes = { "", "fallback_walk_v1/", "fallback_walk_v2/" },
  },
  GREEN = {
    id = "SPRITE_KA_CRYSTAL_GREEN_WALK",
    stem = "green",
    lanes = {
      "", "fallback_walk_v1/", "fallback_walk_v2/", "fallback_walk_v3/",
    },
  },
}

local NATIVE_IDENTITY_BY_SPRITE = {
  SPRITE_RED = "RED",
  SPRITE_BLUE = "BLUE",
  SPRITE_KA_GREEN = "GREEN",
}

local APPROVED_IDENTITY_BY_SPRITE = {
  SPRITE_KA_CRYSTAL_RED_WALK = "RED",
  SPRITE_KA_CRYSTAL_BLUE_WALK = "BLUE",
  SPRITE_KA_CRYSTAL_GREEN_WALK = "GREEN",
}

local rendererCache = setmetatable({}, { __mode = "k" })

local function spriteDef(sprite)
  return type(sprite) == "table" and sprite.def or nil
end

local function independentState(player, sprite)
  local def = spriteDef(sprite)
  local id = def and def.id
  return type(player) == "table" and (
    player.onBike == true
    or player.surfing == true
    or player.fishing == true
    or player._pokepcAsPokemon == true
    or player._pokepcControlSpecies ~= nil
    or player.pokepcControlSpecies ~= nil
    or id == "SPRITE_PLAYER_POKEMON"
  )
end

local function findProvider(deps)
  if deps and deps.provider ~= nil then
    return deps.provider or nil
  end
  local mod = V and V.mod
  if not (mod and type(mod.find) == "function") then return nil end
  -- Legacy KASC releases used the trainer_rematch id but never registered the
  -- Crystal Red/Blue/Green walker contract. Treating that mod as a provider
  -- made target lookup deterministically fail on older smartphone installs.
  local ok, handle = pcall(mod.find, mod, "kanto_ascendant")
  if not ok or type(handle) ~= "table" then
    ok, handle = pcall(mod.find, "kanto_ascendant")
  end
  return ok and type(handle) == "table" and handle or nil
end

local function publicIdentity(provider, game)
  local exports = type(provider) == "table" and provider.exports or nil
  local journey = type(exports) == "table" and exports.legacyJourney or nil
  if type(journey) == "table" and type(journey.activeCharacter) == "function" then
    local ok, value = pcall(journey.activeCharacter, game and game.save)
    value = ok and type(value) == "string" and value:upper() or nil
    if APPROVED[value] then return value end
  end
  local characters = type(exports) == "table" and exports.extendedCharacters or nil
  if type(characters) == "table"
      and type(characters.getPlayerCharacter) == "function" then
    local ok, value = pcall(characters.getPlayerCharacter)
    value = ok and type(value) == "string" and value:upper() or nil
    if APPROVED[value] then return value end
  end
  return nil
end

local function identityOf(player, sprite, provider, game)
  local tagged = type(player) == "table" and player.ascendantCharacter or nil
  if type(tagged) == "string" then
    tagged = tagged:upper()
    if APPROVED[tagged] then return tagged end
  end
  local def = spriteDef(sprite)
  local approvedLive = def and APPROVED_IDENTITY_BY_SPRITE[def.id] or nil
  if approvedLive then return approvedLive end
  local public = publicIdentity(provider, game)
  if public then return public end
  return def and NATIVE_IDENTITY_BY_SPRITE[def.id] or "RED"
end

local function approvedDefinition(def, contract)
  if type(def) ~= "table" or def.id ~= contract.id then return false end
  local image = def.image
  local approvedPath = false
  if type(image) == "string" then
    for _, lane in ipairs(contract.lanes) do
      local expected = "/assets/characters/crystal_chars/" .. lane
        .. contract.stem .. "_walk.png"
      if #image >= #expected and image:sub(-#expected) == expected then
        approvedPath = true
        break
      end
    end
  end
  return approvedPath and tonumber(def.frames) == 6
    and def.walker == true and def.trueColor == true
end

local function fallback(reason, player, sprite, identity, target)
  local def = spriteDef(sprite)
  return sprite, (("live-actor-fallback: %s; "
    .. "identity=%s target=%s current=%s image=%s")
    :format(tostring(reason), tostring(identity), tostring(target),
      tostring(def and def.id), tostring(def and def.image)))
end

-- `deps` is a narrow deterministic test seam. Runtime callers omit it and
-- resolve the already merged engine registry plus the public SpriteRenderer.
function ExternalKascWalker.resolve(player, sprite, deps)
  if independentState(player, sprite) then
    return sprite, "independent-state"
  end

  local provider = findProvider(deps)
  local game = deps and deps.game or nil
  if not game then
    local ok, loaded = pcall(require, "src.core.Game")
    game = ok and loaded or nil
  end
  local identity = identityOf(player, sprite, provider, game)
  local contract = identity and APPROVED[identity] or nil
  if not contract then
    return fallback("normal 3-D WALK identity is unknown",
      player, sprite, identity, nil)
  end

  local current = spriteDef(sprite)
  if current and current.id == contract.id
      and approvedDefinition(current, contract) then
    return sprite, contract.id
  end

  if not provider then
    return fallback("Kanto Ascendant walker provider is not active",
      player, sprite, identity, contract.id)
  end

  local sprites = deps and deps.sprites or nil
  if not sprites then
    sprites = game and game.data and game.data.sprites or nil
  end
  local target = type(sprites) == "table" and sprites[contract.id] or nil
  if not approvedDefinition(target, contract) then
    return fallback("approved KASC walker is missing or invalid",
      player, sprite, identity, contract.id)
  end

  local cache = deps and deps.cache or rendererCache
  local cached = type(cache) == "table" and cache[player] or nil
  if cached and cached.def == target and cached.renderer then
    return cached.renderer, contract.id
  end

  local newRenderer = deps and deps.newRenderer or nil
  if not newRenderer then
    local SpriteRenderer = require("src.render.SpriteRenderer")
    newRenderer = SpriteRenderer and SpriteRenderer.new or nil
  end
  if type(newRenderer) ~= "function" then
    return fallback("SpriteRenderer.new is unavailable", player, sprite,
      identity, contract.id)
  end
  local ok, renderer = pcall(newRenderer, target,
    "vasc-gen1-3d-player-" .. identity:lower())
  if not ok or type(renderer) ~= "table"
      or renderer.def ~= target or type(renderer.resolveImage) ~= "function" then
    return fallback("approved KASC walker renderer could not be created",
      player, sprite, identity, contract.id)
  end

  if type(cache) == "table" then
    cache[player] = { def=target, renderer=renderer }
  end
  return renderer, contract.id
end

function ExternalKascWalker.invalidate()
  rendererCache = setmetatable({}, { __mode = "k" })
end

ExternalKascWalker.APPROVED = APPROVED
ExternalKascWalker.identityOf = identityOf
ExternalKascWalker.independentState = independentState
ExternalKascWalker.approvedDefinition = approvedDefinition
ExternalKascWalker.findProvider = findProvider
ExternalKascWalker.publicIdentity = publicIdentity

return ExternalKascWalker
