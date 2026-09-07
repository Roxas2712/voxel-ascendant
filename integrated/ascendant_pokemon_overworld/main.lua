-- Ascendant Pokemon Overworld
--
-- A small generation dispatcher and nothing else.  The actual follower,
-- compatibility and future Card concerns live behind separate modules so the
-- standalone package can later move into a VASC Card without changing its
-- public contract.

local function loadSibling(mod, filename)
  local body, readErr = mod:read(filename)
  assert(type(body) == "string", readErr or ("unable to read " .. filename))
  local chunk, compileErr = loadstring(body, "@" .. mod.path .. "/" .. filename)
  assert(chunk, compileErr)
  return chunk()
end

return function(mod)
  -- VASC's internal Card owns rollback, including partial entry failure.
  local function own(service)
    if mod._apoOwn then mod._apoOwn(service) end
    return service
  end
  local GameVersion = require("src.core.GameVersion")
  local generation = tonumber(GameVersion.generation()) or 1
  if generation ~= 1 and generation ~= 2 then
    mod.exports.supported = false
    mod.exports.reason = "unsupported_generation"
    mod.log:warn("Ascendant Pokemon Overworld: unsupported generation %s",
      tostring(generation))
    return
  end

  local Catalog = loadSibling(mod, "src/catalog.lua")
  local PokemonWalksheets = loadSibling(mod, "src/pokemon_walksheets.lua")
  local Compat = loadSibling(mod, "src/compat.lua")(mod, generation)
  local Characters = loadSibling(mod, "src/characters.lua")
  local CharacterActions = loadSibling(mod, "src/character_actions.lua")
  local NpcCatalog = loadSibling(mod, "src/npc_catalog.lua")
  local WalkingSprites = loadSibling(mod, "src/walking_sprites.lua")
  local DebugLog = loadSibling(mod, "src/debug_log.lua")
  local ScaleProfiles = loadSibling(mod, "src/scale_profiles.lua")
  local PresentationPolicy = loadSibling(mod, "src/presentation_policy.lua")
  local VoxelCharacters = loadSibling(mod, "src/voxel_characters.lua")
  local PokemonCardStyle = loadSibling(mod, "src/pokemon_card_style.lua")
  local PikachuRide = loadSibling(mod, "src/pikachu_ride.lua")
  local PokemonWorldSprites = loadSibling(mod, "src/pokemon_world_sprites.lua")
  local FollowerSpacing = loadSibling(mod, "src/follower_spacing.lua")
  local PokemonCollision = loadSibling(mod, "src/pokemon_collision.lua")
  local Gen1Follower = loadSibling(mod, "src/follower_gen1.lua")
  local Runtime = loadSibling(mod, "src/runtime.lua")
  local Card = loadSibling(mod, "cards/overworld_pokemon_card.lua")

  local characters = Characters.new({
    mod = mod,
    generation = generation,
    compat = Compat,
  })
  own(characters):install()

  local npcCatalog = NpcCatalog.public(mod)
  local pokemonWalksheets = PokemonWalksheets.new({
    mod = mod,
    catalog = Catalog,
    scaleProfiles = ScaleProfiles,
  })
  local debugLog = DebugLog.new(mod, generation)
  local walkingSprites = WalkingSprites.new({
    mod = mod,
    generation = generation,
    compat = Compat,
    npcCatalog = npcCatalog,
    characterActions = CharacterActions,
    debugLog = debugLog,
  })
  own(walkingSprites):install()

  local followerSpacing = FollowerSpacing.new({ mod=mod, compat=Compat })
  local presentationPolicy = PresentationPolicy.new({ mod=mod, compat=Compat })
  local goProvider = pokemonWalksheets:goRenderCardProvider()
  local goRegistered, goReason = presentationPolicy:register(
    "pokemon_go", goProvider)
  if not goRegistered and mod.log and type(mod.log.warn) == "function" then
    mod.log:warn("GO-HD render-card provider unavailable: %s",
      tostring(goReason or "registration_failed"))
  end
  local voxelCharacters = VoxelCharacters.new({
    mod = mod,
    generation = generation,
    scaleProfiles = ScaleProfiles,
    followerSpacing = followerSpacing,
    presentationPolicy = presentationPolicy,
    debugLog = debugLog,
    cardStyleModule = PokemonCardStyle,
    pikachuRide = PikachuRide.new(),
  })
  own(voxelCharacters):install()
  local voxelHealth = voxelCharacters:health()
  if voxelHealth.vasc then
    mod.log:info("Ascendant character renderer: VASC visual hull active")
  else
    mod.log:info("Ascendant character renderer: native 2D fallback (%s)",
      tostring(voxelHealth.vascError or voxelHealth.standaloneError))
  end

  local runtime = Runtime.new({
    mod = mod,
    generation = generation,
    catalog = Catalog,
    compat = Compat,
    characters = characters,
    pokemonWalksheets = pokemonWalksheets,
    scaleProfiles = ScaleProfiles,
    gen1Follower = Gen1Follower,
  })
  local installed, reason = own(runtime):install()

  local pokemonWorldSprites = PokemonWorldSprites.new({
    mod = mod,
    catalog = Catalog,
    compat = Compat,
    pokemonWalksheets = pokemonWalksheets,
    scaleProfiles = ScaleProfiles,
    presentationPolicy = presentationPolicy,
    debugLog = debugLog,
  })
  own(pokemonWorldSprites):install()

  own(followerSpacing):install()
  local pokemonCollision = PokemonCollision.new({
    mod=mod, debugLog=debugLog, generation=generation,
  })
  own(pokemonCollision):install()

  mod.exports.supported = true
  mod.exports.generation = generation
  mod.exports.catalog = Catalog.public(mod)
  mod.exports.pokemonWalksheets = pokemonWalksheets:public()
  mod.exports.compatibility = Compat.public
  mod.exports.characters = characters:public()
  mod.exports.characterActions = CharacterActions.public(mod)
  mod.exports.npcCatalog = npcCatalog
  mod.exports.walkingSprites = walkingSprites:public()
  mod.exports.diagnostics = debugLog:public()
  mod.exports.voxelCharacters = voxelCharacters:public()
  mod.exports.pokemonWorldSprites = pokemonWorldSprites:public()
  mod.exports.followerSpacing = followerSpacing:public()
  mod.exports.pokemonCollision = pokemonCollision:public()
  mod.exports.scaleProfiles = ScaleProfiles.public()
  mod.exports.presentationPolicy = presentationPolicy:public()
  mod.exports.runtime = runtime:public()
  mod.exports.ascendantCard = Card.public(
    runtime, characters, mod.exports.characterActions, mod.exports.npcCatalog)
  mod.exports.mode = runtime.mode
  mod.exports.active = installed == true or runtime.mode == "delegated"
  mod.exports.reason = reason

  if installed then
    mod.log:info("Ascendant Pokemon Overworld: Gen %d standalone active",
      generation)
  elseif runtime.mode == "delegated" then
    mod.log:info("Ascendant Pokemon Overworld: follower ownership delegated to %s",
      tostring(runtime.ownerId))
  else
    mod.log:error("Ascendant Pokemon Overworld inactive: %s",
      tostring(reason or "unknown error"))
  end
end
