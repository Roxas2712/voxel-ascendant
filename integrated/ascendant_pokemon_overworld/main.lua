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
  local HumanBlink = loadSibling(mod, "src/human_blink.lua")
  local HumanBlinkProfiles = loadSibling(mod, "src/human_blink_profiles.lua")
  local HumanSeatProfiles = loadSibling(mod, "src/human_seat_profiles.lua")
  local positionOk, HumanPosition = pcall(loadSibling, mod, "src/human_position.lua")
  if not positionOk or type(HumanPosition) ~= "table" or type(HumanPosition.apply) ~= "function"
      or type(HumanPosition.fraction) ~= "function" then HumanPosition = nil end
  local HumanIdle = loadSibling(mod, "src/human_idle.lua")
  local HumanDialogueIdle = loadSibling(mod, "src/human_dialogue_idle.lua")
  local HumanDialogue = loadSibling(mod, "src/human_dialogue.lua")
  local HumanTurn = loadSibling(mod, "src/human_turn.lua")
  local HumanActing = loadSibling(mod, "src/human_acting.lua")
  local HumanActingProfiles = loadSibling(mod, "src/human_acting_profiles.lua")
  local HumanConversation = loadSibling(mod, "src/human_conversation.lua")
  local HumanSeatedBreath = loadSibling(mod, "src/human_seated_breath.lua")
  local HumanJohtoSeat = loadSibling(mod, "src/human_johto_seat.lua")
  local HumanSeatedMother = loadSibling(mod, "src/human_seated_mother.lua")
  local motherModules = {
    mod=mod, idle=HumanIdle, frames=loadSibling(mod, "src/human_mother_frames.lua"),
    headLayers=loadSibling(mod, "src/human_head_layers.lua"),
    headMorph=loadSibling(mod, "src/human_head_morph.lua"),
    seatLayers=loadSibling(mod, "src/human_seat_layers.lua"),
  }
  local HumanRig = loadSibling(mod, "src/human_rig.lua")
  local HumanRigProfiles = loadSibling(mod, "src/human_rig_profiles.lua")
  local rimOk, HumanRim = pcall(loadSibling, mod, "src/human_rim.lua")
  if rimOk and type(HumanRim)=="table" and type(HumanRim.shader)=="string"
      and type(HumanRim.send)=="function" then
    HumanRig.rim, HumanBlink.rim = HumanRim, HumanRim
  end
  local gridOk, HumanGrid = pcall(function()
    return loadSibling(mod, "src/human_grid.lua")(
      loadSibling(mod, "src/human_grid_cache.lua"),
      loadSibling(mod, "src/human_grid_stencil.lua"),
      loadSibling(mod, "src/human_grid_builder.lua"),
      loadSibling(mod, "src/human_grid_preparation.lua"))
  end)
  if not gridOk then
    mod.log:warn("Human grid animation unavailable; retaining existing character cards: %s", tostring(HumanGrid))
    HumanGrid = nil
  end
  local VoxelCharacters = loadSibling(mod, "src/voxel_characters.lua")
  local CardBounds = loadSibling(mod, "src/card_bounds.lua")
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
  local humanDialogueIdle = own(HumanDialogueIdle.new({mod=mod,generation=generation,
    seatProfiles=HumanSeatProfiles}))
  local humanActing = own(HumanActing.new({mod=mod,generation=generation,dialogue=HumanDialogue,profiles=HumanActingProfiles,turn=HumanTurn,idle=HumanIdle,
    conversation=HumanConversation,dialogueIdle=humanDialogueIdle,seatedMother=HumanSeatedMother.new(motherModules)}))
  humanActing:install()

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
    cardBounds = CardBounds.new(mod),
    mod = mod,
    generation = generation,
    scaleProfiles = ScaleProfiles,
    followerSpacing = followerSpacing,
    presentationPolicy = presentationPolicy,
    debugLog = debugLog,
    cardStyleModule = PokemonCardStyle,
    humanBlinkModule = HumanBlink,
    humanBlinkProfiles = HumanBlinkProfiles,
    humanIdleModule = HumanIdle,
    humanPositionModule = HumanPosition,
    humanActing = humanActing,
    humanDialogueIdle = humanDialogueIdle,
    humanSeatedBreathModule = HumanSeatedBreath,
    humanJohtoSeatModule = HumanJohtoSeat,
    humanSeatProfiles = HumanSeatProfiles,
    humanRigModule = HumanRig,
    humanGridModule = HumanGrid,
    humanRigProfiles = HumanRigProfiles,
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
