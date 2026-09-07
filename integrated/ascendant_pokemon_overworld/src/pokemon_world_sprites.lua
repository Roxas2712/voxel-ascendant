-- Context-selective visual bridge for the validated Pokemon #001-251 sheets.
--
-- The bridge never creates Pokemon. Existing follower, Wilds encounter and
-- town systems remain authoritative; this module only changes their resolved
-- SpriteRenderer definition. Every live mutation is identity-held and can be
-- restored without disturbing a later provider.

local PokemonWorldSprites = {}
PokemonWorldSprites.__index = PokemonWorldSprites
PokemonWorldSprites.SCHEMA = "ascendant.pokemon-world-sprites/v1"
local PATCH_KEY = "__ascendantPokemonWorldSprites"
local ABSENT = {}

local OPTION = {
  follower="hd_pokemon_followers",
  grass="hd_pokemon_grass",
  city="hd_pokemon_city",
  wilds_town="hd_pokemon_wilds_towns",
}

local function option(mod, key, fallback)
  local options = mod and mod.options
  if not (options and type(options.get) == "function") then return fallback end
  local ok, value = pcall(options.get, options, key)
  if not ok or value == nil then return fallback end
  return value == true
end

local function clone(source)
  local out = {}
  for key, value in pairs(source or {}) do out[key] = value end
  return out
end

local function worldFor(game)
  return game and (game.overworld or game.world) or nil
end

local function shinyFrom(value)
  if type(value) == "table" then
    if value.shiny ~= nil then return value.shiny == true end
    if value.isShiny ~= nil and type(value.isShiny) ~= "function" then
      return value.isShiny == true
    end
    value = value.variant or value.palette
  end
  value = tostring(value or ""):lower()
  return value == "shiny" or value == "rare"
end

local function monIdentity(entity, species, variant)
  entity = type(entity) == "table" and entity or {}
  local nested = type(entity.pokemon) == "table" and entity.pokemon
    or type(entity.mon) == "table" and entity.mon
    or type(entity.followerMon) == "table" and entity.followerMon
    -- VASC's Gen-2 native-follower bridge keeps the real party object here
    -- while the NPC itself deliberately retains the generic Wilds actor kind.
    or type(entity.pokepcMon) == "table" and entity.pokepcMon or nil
  local source = entity.sprite and entity.sprite.def or entity.spriteDef
    or type(entity.def) == "table" and entity.def or nil
  local sourceSpecies = type(source) == "table"
    and (source.pokemonSpecies or source.stadiumSpecies) or nil
  local sourceDex = type(source) == "table" and (source.pokemonDex
    or source.stadiumDex or source.dexId or source.nationalDex or source.dex)
    or nil
  local spriteId = type(source) == "table" and (source.id or source.sprite)
    or nil
  if type(spriteId) == "string" then
    spriteId = spriteId:upper():gsub("^SPRITE[_%-]", "")
      :gsub("^FOLLOWER[_%-]", "")
  end
  local nestedSpecies = nested and (nested.species or nested.pokemonSpecies)
  local nestedDex = nested and (nested.pokemonDex or nested.stadiumDex
    or nested.nationalDex or nested.speciesId or nested.dexId or nested.dex)
  local resolvedSpecies = species or nestedSpecies or entity.pokemonSpecies
    or entity.stadiumSpecies or entity._pokepcFollowerSpecies
    or entity.pokepcFollowerSpecies or entity._wildsFollowerSpecies
    or entity.followerSpecies or entity.wildSpecies or entity.spawnSpecies
    or entity.encounterSpecies
    or (nested and (nested.species or nested.pokemonSpecies))
    or sourceSpecies or entity.ambientSpecies or entity.species or spriteId
  if type(resolvedSpecies) == "string" then
    resolvedSpecies = resolvedSpecies:upper()
  end
  -- The owner's live party object carries palette/DVs; renderer metadata is
  -- only a fallback. Treating a follower without entity.shiny as normal made
  -- this bridge overwrite the just-configured Shiny animation on refresh.
  local paletteOwner = nested or entity
  local shiny
  if variant ~= nil then
    shiny = shinyFrom(variant)
  elseif paletteOwner.shiny ~= nil or (paletteOwner.isShiny ~= nil
      and type(paletteOwner.isShiny) ~= "function")
      or paletteOwner.variant ~= nil or paletteOwner.palette ~= nil then
    shiny = shinyFrom(paletteOwner)
  elseif not (paletteOwner.dvs or paletteOwner.dv) and type(source) == "table"
      and source.ascendantPokemonPalette ~= nil then
    shiny = source.ascendantPokemonPalette == "shiny"
  end
  local resolvedDex = nestedDex
  if not (nestedSpecies or nestedDex) then
    resolvedDex = entity.pokemonDex or entity.enhancedDexId
      or entity.stadiumDex or sourceDex or entity.speciesId or entity.dexId
      or entity.nationalDex or entity.dex
  end
  return {
    -- Published Pokemon metadata is authoritative.  Some follower owners use
    -- a generic entity species such as WILDS_FOLLOWER_MON while keeping the
    -- actual Pokemon identity on the SpriteRenderer definition; accepting the
    -- generic tag first made GO_ONLY look unavailable and misreported HD_2D.
    species=resolvedSpecies,
    nationalDex=resolvedDex,
    gender=paletteOwner.gender or paletteOwner.sex or entity.gender or entity.sex,
    shiny=shiny, dvs=paletteOwner.dvs or paletteOwner.dv,
  }
end

local function explicitPokemon(entity)
  if type(entity) ~= "table" then return false end
  local source = entity.sprite and entity.sprite.def or entity.spriteDef
    or type(entity.def) == "table" and entity.def or nil
  local spriteId = type(source) == "table" and (source.id or source.sprite)
    or nil
  return entity.pokemonDex ~= nil or entity.enhancedDexId ~= nil
    or entity.stadiumDex ~= nil or entity.dexId ~= nil
    or entity.nationalDex ~= nil or entity.stadiumSpecies ~= nil
    or entity.wildSpecies ~= nil or entity.spawnSpecies ~= nil
    or entity.encounterSpecies ~= nil
    or entity.speciesId ~= nil or entity.pokemonSpecies ~= nil
    or entity.followerSpecies ~= nil or entity.ambientSpecies ~= nil
    or entity._pokepcFollowerSpecies ~= nil
    or entity.pokepcFollowerSpecies ~= nil
    or entity._wildsFollowerSpecies ~= nil
    or entity.overworldWildSpawn == true or entity.isPokemonFollower == true
    or entity.pikachuFollower == true or entity.pokepcTrailer == true
    or entity.wildsFollower == true
    or type(spriteId) == "string" and (
      spriteId:upper():find("^SPRITE[_%-]") ~= nil
      or spriteId:upper():find("^FOLLOWER[_%-]") ~= nil)
end

local function entityContext(entity)
  if type(entity) ~= "table" then return nil end
  if entity.isPokemonFollower == true or entity.pikachuFollower == true
      or entity.pokepcTrailer == true or entity.wildsFollower == true then
    return "follower"
  end
  if entity.wildsAmbientPokemon == true or entity.ambientSpecies ~= nil then
    return "wilds_town"
  end
  if entity.overworldWildSpawn == true or entity._owwildEntity == true then
    return "grass"
  end
  if explicitPokemon(entity) then return "city" end
  return nil
end

function PokemonWorldSprites.new(options)
  return setmetatable({
    mod=assert(options.mod), catalog=assert(options.catalog),
    compat=assert(options.compat), sheets=assert(options.pokemonWalksheets),
    scaleProfiles=assert(options.scaleProfiles),
    presentationPolicy=options.presentationPolicy,
    debugLog=options.debugLog,
    installed=false, activeGame=nil, bridgeStates={}, applied=0,
    lastError=nil, originals=setmetatable({}, { __mode="k" }),
    flamePhases=setmetatable({}, { __mode="k" }), flamePhaseSerial=0,
  }, PokemonWorldSprites)
end

function PokemonWorldSprites:enabled(context)
  return option(self.mod, OPTION[context], true)
end

function PokemonWorldSprites:_def(game, entity, species, variant, context, id)
  local mon = monIdentity(entity, species, variant)
  local def, reason, record = self.sheets:def(game, mon, id, context)
  if not def then return nil, reason end
  def.providerId = "ascendant_walksheets"
  if (type(def.ascendantPokemonFlameCards) == "table"
      or type(def.ascendantPokemonAnimationCards) == "table")
      and def.ascendantPokemonSpriteSource ~= "pokemmo"
      and type(entity) == "table" then
    local phase = self.flamePhases[entity]
    if phase == nil then
      self.flamePhaseSerial = self.flamePhaseSerial + 1
      phase = (self.flamePhaseSerial * .61803398875) % 1
      self.flamePhases[entity] = phase
    end
    if def.ascendantPokemonFlameCards then def.ascendantPokemonFlamePhase = phase end
    if def.ascendantPokemonAnimationCards then def.ascendantPokemonAnimationPhase = phase end
  else
    def.ascendantPokemonFlameCards = nil
    def.ascendantPokemonFlamePhase = nil
    def.ascendantPokemonAnimationCards = nil
    def.ascendantPokemonAnimationPhase = nil
  end
  return def, nil, record
end

function PokemonWorldSprites:_result(game, entity, species, variant, context,
    fallback)
  local id = fallback and fallback.def and fallback.def.id
  local def, reason, record = self:_def(game, entity, species, variant,
    context, id)
  if not def then return nil, reason end
  return {
    def=def,
    meta={
      providerId="ascendant_walksheets", providerMod=self.mod.id,
      usedVariant=record.palette, relativePath=record.runtime,
      atlasRelativePath=record.atlas, loadPath=def.image,
      frames=6, walker=true, bodyRenderer="NATIVE_SPRITE_RENDERER",
      scaleClass=record.scaleClass, context=context,
    },
    providerId="ascendant_walksheets", fallbackStep=0,
    spriteState="land", spriteKind="ascendant_walksheets",
    waterOverride=false, steps={},
  }
end

function PokemonWorldSprites:_captureOriginal(entity, context)
  local original = self.originals[entity]
  if not original then
    original = {
      pokemonModel=entity.pokemonModel, stadiumModel=entity.stadiumModel,
      sprite=entity.sprite, spriteDef=entity.spriteDef,
      mode=entity.ascendantPokemonSpriteMode, context=context,
      scaleClass=entity.ascendantScaleClass,
      worldHeight=entity.ascendantWorldHeight,
      modelSource=entity.ascendantPokemonModelSource,
      actorGrid=entity.ascendantActorVoxelGrid,
    }
    self.originals[entity] = original
  end
  original.context = context
  return original
end

local function restoreLiveDef(entity, original)
  local mutation = original and original.liveDefMutation
  if not mutation then return false end
  for key, previous in pairs(mutation.previous) do
    if mutation.def[key] == mutation.applied[key] then
      if previous == ABSENT then
        mutation.def[key] = nil
      else
        mutation.def[key] = previous
      end
    end
  end
  if entity.spriteDef == mutation.def then
    if mutation.spriteDef == ABSENT then
      entity.spriteDef = nil
    else
      entity.spriteDef = mutation.spriteDef
    end
  end
  original.liveDefMutation = nil
  return true
end

function PokemonWorldSprites:_presentation(game, entity, context, species,
    variant)
  local mon = monIdentity(entity, species, variant)
  -- Gen-2 follower bridges commonly publish only a symbolic species on the
  -- live party object. Resolve that through the active game's catalogue before
  -- asking providers; passing nil made GO_ONLY incorrectly choose HD_2D even
  -- though the corresponding GO render card was installed.
  local presentationDex = self.catalog.presentationDexFor(game, mon)
  local requestedSpriteSource = self.sheets.sourceForContext
    and self.sheets:sourceForContext(context) or "hd"
  local selected = self.presentationPolicy
    and self.presentationPolicy:decorate(entity, presentationDex, {
      context=context, entity=entity, species=mon.species,
      game=game, mon=mon, spriteSource=requestedSpriteSource,
    }) or { id="sprite" }
  local sourceDef = entity.sprite and entity.sprite.def or entity.spriteDef
  local cardDef, cardReason, cardRecord = self:_def(game, entity, species,
    variant,
    context, type(sourceDef) == "table" and sourceDef.id or nil)
  return mon, selected, cardDef, cardRecord, cardReason, sourceDef
end

function PokemonWorldSprites:_bindLiveCard(game, entity, context, species,
    variant)
  if type(entity) ~= "table" then return nil, "entity_unavailable" end
  local original = self:_captureOriginal(entity, context)
  local _, selected, cardDef, cardRecord, reason, liveDef =
    self:_presentation(game, entity, context, species, variant)
  -- Stadium remains authoritative whenever the user/policy selects it.  A
  -- card existing somewhere in the provider catalogue is not permission to
  -- overwrite the live Stadium renderer.
  if selected.id == "stadium2" or type(cardRecord) ~= "table"
      or type(cardDef) ~= "table" or type(liveDef) ~= "table"
      or type(entity.sprite) ~= "table" then
    restoreLiveDef(entity, original)
    return nil, selected.id == "stadium2" and "stadium2_selected"
      or reason or "live_renderer_unavailable"
  end

  -- VASC rebuilds followers, wild encounters and ambient Pokemon from a
  -- deliberately reduced native definition.  Mutate the definition held by
  -- that exact renderer rather than replacing the renderer: animation state
  -- and ownership stay with VASC, while its draw hook can see our atlas/Dex/
  -- motion contract.  When VASC swaps the renderer, close the old mutation
  -- first so restore always leaves the newest owner renderer untouched.
  local mutation = original.liveDefMutation
  if mutation and mutation.def ~= liveDef then
    restoreLiveDef(entity, original)
    mutation = nil
  end
  if liveDef.ascendantPokemonWalksheet == true
      and liveDef.ascendantAtlasImage == cardDef.ascendantAtlasImage
      and (type(liveDef.ascendantPokemonFlameCards) == "table"
        and liveDef.ascendantPokemonFlameCards.id or nil)
        == (type(cardDef.ascendantPokemonFlameCards) == "table"
          and cardDef.ascendantPokemonFlameCards.id or nil)
      and liveDef.ascendantPokemonFlamePhase == cardDef.ascendantPokemonFlamePhase
      and (type(liveDef.ascendantPokemonAnimationCards) == "table"
        and liveDef.ascendantPokemonAnimationCards.id or nil)
        == (type(cardDef.ascendantPokemonAnimationCards) == "table"
          and cardDef.ascendantPokemonAnimationCards.id or nil)
      and liveDef.ascendantPokemonAnimationPhase == cardDef.ascendantPokemonAnimationPhase
      and tonumber(liveDef.pokemonDex) == tonumber(cardDef.pokemonDex) then
    return liveDef, nil, cardRecord
  end
  if not mutation then
    mutation = {
      def=liveDef, previous={}, applied={},
      spriteDef=entity.spriteDef == nil and ABSENT or entity.spriteDef,
    }
    original.liveDefMutation = mutation
  end
  for key, value in pairs(cardDef) do
    if mutation.previous[key] == nil then
      mutation.previous[key] = liveDef[key] == nil and ABSENT or liveDef[key]
    end
    liveDef[key] = value
    mutation.applied[key] = value
  end
  -- pairs() cannot remove a sidecar when a later source no longer has one.
  for _, key in ipairs({ "ascendantPokemonFlameCards",
      "ascendantPokemonFlamePhase", "ascendantPokemonAnimationCards",
      "ascendantPokemonAnimationPhase", "ascendantPokemonAnimationClips" }) do
    if cardDef[key] == nil then
      if mutation.previous[key] == nil then
        mutation.previous[key] = liveDef[key] == nil and ABSENT or liveDef[key]
      end
      liveDef[key], mutation.applied[key] = nil, nil
    end
  end
  entity.sprite.def = liveDef
  entity.spriteDef = liveDef
  return liveDef, nil, cardRecord
end

function PokemonWorldSprites:_rememberModel(entity, context, boundDef)
  local original = self:_captureOriginal(entity, context)
  local mon, selected, cardDef, cardRecord, _, sourceDef =
    self:_presentation(self.activeGame, entity, context)
  local cardAvailable = type(cardRecord) == "table"
  -- Stadium-2 is the only choice that may own a VASC model body. Both GO-HD
  -- and PokeMMO are animated cards; leaving pokemonModel/stadiumModel enabled
  -- lets VASC draw an unrelated Stadium mesh over the requested source. Never
  -- hide that body until the concrete entity has a resolvable card, though:
  -- provider availability for a Dex cannot prove that a late/generic follower
  -- already publishes enough identity for its actual card.
  sourceDef = type(boundDef) == "table" and boundDef or sourceDef
  local cardBound = cardAvailable and type(sourceDef) == "table"
    and sourceDef.ascendantPokemonWalksheet == true
    and sourceDef.ascendantAtlasImage == cardDef.ascendantAtlasImage
    and tonumber(sourceDef.pokemonDex) == tonumber(cardDef.pokemonDex)
  local suppressModels = selected.id ~= "stadium2" and cardBound
  if suppressModels then
    entity.pokemonModel = false
    entity.stadiumModel = false
  else
    entity.pokemonModel = original.pokemonModel
    entity.stadiumModel = original.stadiumModel
  end
  if selected.id ~= "stadium2" and not cardBound then
    entity.ascendantPokemonModelSource = original.modelSource
  end
  entity.ascendantPokemonSpriteMode = suppressModels and "walksheet_3x4"
    or selected.id == "stadium2" and (selected.id .. "_preferred")
    or original.mode
  entity.ascendantPokemonSpriteContext = context
  local effectiveSource = selected.id == "stadium2" and "stadium2"
    or cardBound and cardRecord.source or "owner_original"
  if effectiveSource == "pokemon_go_legacy"
      or effectiveSource == "pokemon_go_549" then
    effectiveSource = "go_hd_render_cards"
  elseif cardBound and effectiveSource ~= "pokemmo" then
    effectiveSource = "hd_2d"
  end
  if original.appliedPresentationSource ~= effectiveSource then
    original.appliedPresentationSource = effectiveSource
    if self.debugLog and type(self.debugLog.event) == "function" then
      pcall(self.debugLog.event, self.debugLog, "SOURCE", {
        entity=entity, species=mon.species, context=context,
        source=effectiveSource,
        provider=selected.id == "stadium2" and "VOXEL_ASCENDANT"
          or cardBound and "ascendant_walksheets" or "original_owner",
        decision=suppressModels and "card_owns_body"
          or selected.id == "stadium2" and "stadium2_owns_body"
          or "card_unavailable_owner_retained",
        reason=cardBound and (sourceDef.ascendantPokemonSourceFallbackReason
          or cardDef.ascendantPokemonSourceFallbackReason)
          or selected.reason,
        mode=self.presentationPolicy and self.presentationPolicy:mode() or nil,
        state=suppressModels and "renderer_bound" or "owner_renderer",
      }, self.activeGame)
    end
  end
  return original
end

function PokemonWorldSprites:_rememberScale(entity, original)
  if original.scaleCaptured then return end
  original.scaleCaptured = true
  original.visualScale = entity.visualScale
  original.final2DScale = entity.final2DScale
  original.scaleInfo = entity.scaleInfo
  original.grassOcclusionHeight = entity.grassOcclusionHeight
  original.voxelScale = entity.voxelScale
end

function PokemonWorldSprites:_wrapNativeDraw(entity, original)
  local sprite = entity.sprite
  if type(sprite) ~= "table" or type(sprite.draw) ~= "function" then
    return false
  end
  original.nativeDraws = original.nativeDraws or {}
  for index = #original.nativeDraws, 1, -1 do
    local entry = original.nativeDraws[index]
    if entry.sprite == sprite then return true end
    -- Owner refreshes can replace a follower renderer every step. Detached
    -- wrappers must not accumulate or retain old renderer graphs until map
    -- exit; release them as soon as a newer owner renderer becomes live.
    if entry.sprite.draw == entry.wrapped then entry.sprite.draw = entry.raw end
    table.remove(original.nativeDraws, index)
  end
  local inherited = sprite.draw
  local raw = rawget(sprite, "draw")
  local function wrapped(selfSprite, px, py, camX, camY, ...)
    local graphics = love and love.graphics
    local scale = tonumber(entity.final2DScale) or 1
    if scale == 1 or not (graphics and graphics.push and graphics.pop
        and graphics.translate and graphics.scale) then
      return inherited(selfSprite, px, py, camX, camY, ...)
    end
    -- Gen1 and Gen2 both ground a normal 16px actor at world anchor (+8,+12).
    -- Scale around that foot point so every size tier still touches the floor.
    local anchorX = math.floor((tonumber(px) or 0) - (tonumber(camX) or 0)) + 8
    local anchorY = math.floor((tonumber(py) or 0) - (tonumber(camY) or 0)) + 12
    graphics.push()
    graphics.translate(anchorX, anchorY)
    graphics.scale(scale, scale)
    graphics.translate(-anchorX, -anchorY)
    local ok, value = pcall(inherited, selfSprite, px, py, camX, camY, ...)
    graphics.pop()
    if not ok then error(value, 0) end
    return value
  end
  sprite.draw = wrapped
  original.nativeDraws[#original.nativeDraws + 1] = {
    sprite=sprite, raw=raw, wrapped=wrapped,
  }
  return true
end

function PokemonWorldSprites:_enforceScale(game, entity, context, def)
  if type(entity) ~= "table" then return false end
  local liveDef = (entity.sprite and entity.sprite.def) or entity.spriteDef
  def = def or (entity.sprite and entity.sprite.def) or entity.spriteDef
    or entity.pendingSpriteDef
  if not (type(def) == "table" and def.ascendantPokemonWalksheet) then
    def = self:_def(game, entity, nil, nil, context,
      type(def) == "table" and def.id or nil)
  end
  if type(def) ~= "table" then return false end
  local class = def.ascendantScaleClass
  local worldHeight = def.ascendantWorldHeight
    or self.scaleProfiles.worldHeightForClass(class)
  local contentW = tonumber(def.ascendantRuntimeContentWidth) or 16
  local contentH = tonumber(def.ascendantRuntimeContentHeight) or 16
  local scale = worldHeight / math.max(1, contentH)
  local original = self:_rememberModel(entity, context,
    liveDef == def and def or nil)
  self:_rememberScale(entity, original)
  local scaleInfo = clone(entity.scaleInfo)
  scaleInfo.scale = scale
  scaleInfo.final2DScale = scale
  scaleInfo.contentW = contentW
  scaleInfo.contentH = contentH
  scaleInfo.renderedW = contentW * scale
  scaleInfo.renderedH = worldHeight
  scaleInfo.originalW = 16
  scaleInfo.originalH = 96
  scaleInfo.logicalFootprintTiles = math.max(1, scaleInfo.renderedW / 16)
  scaleInfo.grassOcclusionHeight = math.max(2, worldHeight * 0.375)
  entity.scaleInfo = scaleInfo
  entity.visualScale = scale
  entity.final2DScale = scale
  entity.grassOcclusionHeight = scaleInfo.grassOcclusionHeight
  -- VASC reads ascendantWorldHeight and scales the authored atlas itself.
  -- Keep its generic model multiplier neutral to avoid applying the tier twice.
  entity.voxelScale = 1
  entity.ascendantScaleClass = class
  entity.ascendantWorldHeight = worldHeight
  self:_wrapNativeDraw(entity, original)
  return true
end

function PokemonWorldSprites:_restoreEntity(entity, original)
  restoreLiveDef(entity, original)
  for _, entry in ipairs(original.nativeDraws or {}) do
    if entry.sprite.draw == entry.wrapped then entry.sprite.draw = entry.raw end
  end
  if original.replacement == nil or entity.sprite == original.replacement then
    if original.replacement ~= nil then
      entity.sprite, entity.spriteDef = original.sprite, original.spriteDef
    end
  end
  entity.pokemonModel, entity.stadiumModel = original.pokemonModel,
    original.stadiumModel
  entity.ascendantPokemonSpriteMode = original.mode
  entity.ascendantPokemonSpriteContext = nil
  entity.ascendantScaleClass = original.scaleClass
  entity.ascendantWorldHeight = original.worldHeight
  entity.ascendantPokemonModelSource = original.modelSource
  entity.ascendantActorVoxelGrid = original.actorGrid
  if original.scaleCaptured then
    entity.visualScale = original.visualScale
    entity.final2DScale = original.final2DScale
    entity.scaleInfo = original.scaleInfo
    entity.grassOcclusionHeight = original.grassOcclusionHeight
    entity.voxelScale = original.voxelScale
  end
  if self.debugLog and type(self.debugLog.event) == "function" then
    pcall(self.debugLog.event, self.debugLog, "SOURCE", {
      entity=entity, context=original.context, source="owner_original",
      provider="original_owner", decision="restore",
      reason="ascendant_visual_disabled_or_context_changed",
    }, self.activeGame)
  end
  self.originals[entity] = nil
end

function PokemonWorldSprites:_bindCity(game, entity)
  local source = entity.sprite and entity.sprite.def or entity.spriteDef
  if type(source) ~= "table" then return false end
  local original = self:_captureOriginal(entity, "city")
  local _, selected, def, record = self:_presentation(game, entity, "city")
  if selected.id == "stadium2" or type(record) ~= "table"
      or type(def) ~= "table" then
    self:_rememberModel(entity, "city")
    return false
  end
  local SpriteRenderer = require("src.render.SpriteRenderer")
  local ok, renderer = pcall(SpriteRenderer.new, def, entity.id or "pokemon")
  if not ok or not renderer then
    self.lastError = tostring(renderer or "city_renderer_creation_failed")
    self:_rememberModel(entity, "city")
    return false
  end
  entity.sprite, entity.spriteDef = renderer, def
  original.replacement = renderer
  self:_rememberModel(entity, "city", def)
  self:_enforceScale(game, entity, "city", def)
  return true
end

function PokemonWorldSprites:apply(game)
  game = game or self.activeGame
  if game then self.activeGame = game end
  local world = worldFor(game)
  if type(world) ~= "table" then return 0 end
  local seen, count = {}, 0
  -- Iterate names, not a value array: `ipairs({nil, entities, ...})` stops at
  -- the first missing bucket and silently skips a perfectly valid live world.
  for _, bucketName in ipairs({ "npcs", "entities", "objects" }) do
    local bucket = world[bucketName]
    if type(bucket) == "table" then
      for _, entity in pairs(bucket) do
        if type(entity) == "table" and not seen[entity] then
          seen[entity] = true
          local context = entityContext(entity)
          local original = self.originals[entity]
          -- A fixed city/house Pokemon may be rebuilt by its authoritative
          -- owner after our first pass (map scripts and provider refreshes do
          -- this without replacing the entity itself).  The renderer held in
          -- `replacement` is then no longer live.  Close the old mutation
          -- before binding again so disabling this feature restores the
          -- newest owner renderer, never the stale one captured on map entry.
          if original and original.context == "city"
              and original.replacement ~= nil
              and entity.sprite ~= original.replacement then
            if type(entity.sprite) == "table"
                and type(entity.sprite.def) == "table" then
              entity.spriteDef = entity.sprite.def
            end
            self:_restoreEntity(entity, original)
            original = nil
          end
          -- A source switch from a concrete card back to Stadium must release
          -- our city renderer before policy is applied again.  Availability
          -- alone never grants a card ownership over an explicit Stadium
          -- choice.
          if original and original.context == "city"
              and original.replacement ~= nil then
            local _, selected, _, record = self:_presentation(game, entity,
              "city")
            if selected.id == "stadium2" or type(record) ~= "table" then
              self:_restoreEntity(entity, original)
              original = nil
            end
          end
          if original and (not context or not self:enabled(context)
              or original.context ~= context) then
            self:_restoreEntity(entity, original)
            original = nil
          end
          if context and self:enabled(context) then
            if context == "city" then
              if not original or original.replacement == nil then
                if self:_bindCity(game, entity) then count = count + 1 end
              else
                local liveDef = entity.sprite and entity.sprite.def
                  or entity.spriteDef
                self:_rememberModel(entity, context, liveDef)
                self:_enforceScale(game, entity, context, liveDef)
              end
            else
              local liveDef = self:_bindLiveCard(game, entity, context)
              self:_rememberModel(entity, context, liveDef)
              if liveDef then
                self:_enforceScale(game, entity, context, liveDef)
              end
            end
          end
        end
      end
    end
  end
  -- Entities removed from the active world can safely be forgotten. Weak keys
  -- make this bounded even if a provider discards an entity between maps.
  for entity, original in pairs(self.originals) do
    if seen[entity] and not self:enabled(original.context) then
      self:_restoreEntity(entity, original)
    end
  end
  self.applied = self.applied + count
  return count
end

function PokemonWorldSprites:_installWilds(source)
  local wilds = source and source.provider
  if type(wilds) ~= "table" then return false end
  local previous = rawget(wilds, PATCH_KEY)
  if previous and previous.owner == self then return false end
  if previous and type(previous.restore) == "function" then
    pcall(previous.restore)
  end
  local state = { source=source, restores={}, owner=self }
  local bridge = self
  local render = wilds.render
  local resolver = type(render) == "table" and render.spriteResolver or nil
  if type(resolver) == "table" and type(resolver.resolveForEntity) == "function" then
    local original = resolver.resolveForEntity
    local function wrapped(selfResolver, entity, context)
      local base = original(selfResolver, entity, context)
      local land = not entity or (entity.surface ~= "WATER"
        and entity.surface ~= "water" and entity.encounterKind ~= "water")
      if bridge:enabled("grass") and land and type(entity) == "table"
          and (entity.overworldWildSpawn == true or entity._owwildEntity == true) then
        local species = context and context.speciesId or entity.species
        local variant = context and context.variant or entity.spriteVariant
        local game = context and context.game
        local _, selected, _, record = bridge:_presentation(game, entity,
          "grass", species, variant)
        if selected.id ~= "stadium2" and type(record) == "table" then
          local result = bridge:_result(game, entity, species, variant,
            "grass", base)
          if result then return result end
        end
      end
      return base
    end
    resolver.resolveForEntity = wrapped
    state.restores[#state.restores + 1] = function()
      if resolver.resolveForEntity == wrapped then
        resolver.resolveForEntity = original
      end
    end
  end
  if type(render) == "table" and type(render.applyProviderSprite) == "function" then
    local original = render.applyProviderSprite
    local function wrapped(selfRender, entity, game)
      local applied, reason = original(selfRender, entity, game)
      local context = entityContext(entity)
      if applied and context and bridge:enabled(context) then
        local liveDef = bridge:_bindLiveCard(game, entity, context)
        bridge:_rememberModel(entity, context, liveDef)
        if liveDef then bridge:_enforceScale(game, entity, context, liveDef) end
      end
      return applied, reason
    end
    render.applyProviderSprite = wrapped
    state.restores[#state.restores + 1] = function()
      if render.applyProviderSprite == wrapped then
        render.applyProviderSprite = original
      end
    end
  end
  local ambient = wilds.ambient
  if type(ambient) == "table" and type(ambient._resolveSprite) == "function" then
    local original = ambient._resolveSprite
    local function wrapped(selfAmbient, species, game)
      if bridge:enabled("wilds_town") then
        local probe = { ambientSpecies=species, wildsAmbientPokemon=true }
        local _, selected, def, record = bridge:_presentation(game, probe,
          "wilds_town", species)
        if selected.id ~= "stadium2" and type(record) == "table" and def then
          def.id = "SPRITE_WILDS_AMBIENT"
          return def
        end
      end
      return original(selfAmbient, species, game)
    end
    ambient._resolveSprite = wrapped
    state.restores[#state.restores + 1] = function()
      if ambient._resolveSprite == wrapped then ambient._resolveSprite = original end
    end
  end
  if type(ambient) == "table" and type(ambient._bindSprite) == "function" then
    local original = ambient._bindSprite
    local function wrapped(selfAmbient, entity, species, game)
      local bound, reason = original(selfAmbient, entity, species, game)
      -- VASC's ambient binder deliberately copies only the five native
      -- SpriteRenderer fields from `_resolveSprite`.  That is sufficient for
      -- its 16x96 fallback strip, but drops our high-resolution atlas, Dex and
      -- motion contract even though source selection correctly reports GO.
      -- Enrich the renderer VASC actually created instead of replacing its
      -- ownership or touching VASC itself.
      if bound and bridge:enabled("wilds_town") and type(entity) == "table" then
        local liveDef = bridge:_bindLiveCard(game, entity, "wilds_town",
          species)
        bridge:_rememberModel(entity, "wilds_town", liveDef)
        if liveDef then
          bridge:_enforceScale(game, entity, "wilds_town", liveDef)
        end
      end
      return bound, reason
    end
    ambient._bindSprite = wrapped
    state.restores[#state.restores + 1] = function()
      if ambient._bindSprite == wrapped then ambient._bindSprite = original end
    end
  end
  if #state.restores == 0 then return false end
  function state.restore()
    for index = #state.restores, 1, -1 do pcall(state.restores[index]) end
    if rawget(wilds, PATCH_KEY) == state then wilds[PATCH_KEY] = nil end
  end
  wilds[PATCH_KEY] = state
  self.bridgeStates[#self.bridgeStates + 1] = state
  return true
end

function PokemonWorldSprites:_installWildsBridges()
  local count = 0
  for _, source in ipairs(self.compat.wildsSources() or {}) do
    if self:_installWilds(source) then count = count + 1 end
  end
  return count
end

function PokemonWorldSprites:_refreshProviders(game)
  for _, source in ipairs(self.compat.wildsSources() or {}) do
    local wilds = source.provider
    local render = wilds and wilds.render
    local resolver = render and render.spriteResolver
    if resolver and type(resolver.invalidateCache) == "function" then
      pcall(resolver.invalidateCache, resolver)
    end
    if wilds and type(wilds.refreshAllEntitySprites) == "function" then
      pcall(wilds.refreshAllEntitySprites, game)
    elseif render and type(render.refreshAllEntitySprites) == "function"
        and wilds.logic then
      pcall(render.refreshAllEntitySprites, render, wilds.logic, game)
    end
    local ambient = wilds and wilds.ambient
    if ambient and type(ambient.refreshSprites) == "function" then
      pcall(ambient.refreshSprites, ambient, game)
    end
  end
end

function PokemonWorldSprites:refresh(game)
  game = game or self.activeGame
  if game then self.activeGame = game end
  self:_installWildsBridges()
  self:_refreshProviders(game)
  return self:apply(game)
end

function PokemonWorldSprites:restore()
  for entity, original in pairs(self.originals) do
    self:_restoreEntity(entity, original)
  end
  for index = #self.bridgeStates, 1, -1 do
    pcall(self.bridgeStates[index].restore)
    self.bridgeStates[index] = nil
  end
  self.installed = false
  return true
end

function PokemonWorldSprites:install()
  if self.installed then return true end
  self.installed = true
  self:_installWildsBridges()
  if self.mod.hooks and type(self.mod.hooks.wrap) == "function" then
    local bridge = self
    -- VASC's final public relay sees definitions after GAME/KASC/Wilds. Keep
    -- our metadata intact there so its voxel scene renders the selected 3x4
    -- card rather than a Stadium model for that individual entity.
    self.mod.hooks:wrap("vasc.sprite.overworld", function(next, current, ctx)
      local out = next(current, ctx)
      if type(out) ~= "table" then return out end
      local context = out.ascendantPokemonContext
      if context and bridge:enabled(context) then return out end
      local record = bridge.sheets:fromPath(out.image)
      if record then
        local enriched = bridge.sheets:def(bridge.activeGame, {
          nationalDex=record.dex, gender=record.gender,
          shiny=record.palette == "shiny",
        }, out.id, context)
        if enriched then
          for key, value in pairs(out) do
            if enriched[key] == nil then enriched[key] = value end
          end
          return enriched
        end
      end
      return out
    end, 900000)
  end
  if self.mod.events and type(self.mod.events.on) == "function" then
    local bridge = self
    for _, event in ipairs({ "mods.loaded", "game.ready", "save.loaded",
        "map.entered", "map.reloaded", "world.stepped" }) do
      self.mod.events:on(event, function(ev)
        bridge:refresh(ev and ev.game or bridge.activeGame)
      end)
    end
    self.mod.events:on("mod.options_changed", function(ev)
      if not ev or not ev.mod or ev.mod == bridge.mod.id then
        bridge:refresh(bridge.activeGame)
      end
    end)
  end
  return true
end

function PokemonWorldSprites:health()
  return {
    schema=PokemonWorldSprites.SCHEMA, ok=self.installed,
    bridges=#self.bridgeStates, applied=self.applied,
    enabled={
      follower=self:enabled("follower"), grass=self:enabled("grass"),
      city=self:enabled("city"), wildsTown=self:enabled("wilds_town"),
    },
    modelSource=self.presentationPolicy and self.presentationPolicy:mode()
      or "sprite_only",
    actorVoxelGrid=self.presentationPolicy and self.presentationPolicy:gridMode()
      or "off",
    lastError=self.lastError,
  }
end

function PokemonWorldSprites:public()
  local bridge = self
  return {
    schema=PokemonWorldSprites.SCHEMA,
    refresh=function(game) return bridge:refresh(game) end,
    restore=function() return bridge:restore() end,
    health=function() return bridge:health() end,
  }
end

return PokemonWorldSprites
