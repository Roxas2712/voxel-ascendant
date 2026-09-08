-- One portable follower runtime for the public Gen1Recomp Gen-1/Gen-2 seam.

local Runtime = {}
Runtime.__index = Runtime
local STATE_KEY = "__ascendantPokemonOverworld"

local OPPOSITE = {
  up="down", down="up", left="right", right="left",
}

local function clone(source)
  local result = {}
  for key, value in pairs(source or {}) do result[key] = value end
  return result
end

local function animationMotionColumns(record)
  if not record.animationCards then return { "idle", "step-a", "step-b" } end
  local cards = record.animationCards
  local count = type(cards) == "table" and type(cards.idle) == "table"
    and cards.idle.columns == 16 and 16 or 8
  local result = {}
  for column = 0, count - 1 do result[#result+1] = tostring(column) end
  return result
end

local function option(mod, key, fallback)
  local options = mod and mod.options
  if not (options and type(options.get) == "function") then return fallback end
  local ok, value = pcall(options.get, options, key)
  if not ok or value == nil then return fallback end
  return value == true
end

local function healthy(mon)
  return type(mon) == "table" and type(mon.species) == "string"
    and mon.species ~= "" and mon.egg ~= true and mon.isEgg ~= true
    and (tonumber(mon.hp) or 0) > 0
end

local function followerSpritesEnabled(mod)
  return option(mod, "hd_pokemon_followers",
    option(mod, "hd_walking_sprites", true))
end

local function worldFor(game)
  return game and (game.overworld or game.world) or nil
end

local function fingerprint(mon)
  if type(mon) ~= "table" then return nil end
  for _, key in ipairs({ "uid", "monUid", "pokemonUid", "personality" }) do
    if mon[key] ~= nil then return key .. ":" .. tostring(mon[key]) end
  end
  local dvs = type(mon.dvs) == "table" and mon.dvs
    or type(mon.dv) == "table" and mon.dv or {}
  return table.concat({
    "legacy", tostring(mon.otId or mon.trainerId or -1),
    tostring(dvs.attack or dvs.atk or -1),
    tostring(dvs.defense or dvs.def or -1),
    tostring(dvs.speed or dvs.spd or -1),
    tostring(dvs.special or dvs.spc or -1),
    tostring(mon.catchRate or mon.metLocation or -1),
  }, ":")
end

local function replaceUpvalue(fn, wanted, replacement)
  if type(fn) ~= "function" or not (debug and debug.getupvalue
      and debug.setupvalue) then return nil, "debug_upvalue_api_unavailable" end
  local index = 1
  while true do
    local name, previous = debug.getupvalue(fn, index)
    if not name then return nil, "shouldSpawn_upvalue_unavailable" end
    if name == wanted then
      debug.setupvalue(fn, index, replacement)
      return { fn=fn, index=index, previous=previous }
    end
    index = index + 1
  end
end

function Runtime.new(options)
  return setmetatable({
    mod = assert(options.mod),
    generation = assert(options.generation),
    catalog = assert(options.catalog),
    compat = assert(options.compat),
    characters = assert(options.characters),
    pokemonWalksheets = options.pokemonWalksheets,
    scaleProfiles = options.scaleProfiles,
    gen1Follower = options.gen1Follower,
    mode = "pending",
    installed = false,
    ownerId = nil,
    lastError = nil,
    activeGame = nil,
    flamePhases = setmetatable({}, { __mode="k" }),
    flamePhaseSerial = 0,
  }, Runtime)
end

function Runtime:_bindFlameCards(def, record, mon)
  -- KASC's shared follower definition does not promise pokemonDex, notably
  -- when it switches to a Shiny image. Publish the resolved identity on our
  -- own metadata instead of inferring it from a filename or changing KASC.
  def.ascendantPokemonDex = record and tonumber(record.dex) or nil
  local cards = record and record.source ~= "pokemmo" and record.flameCards
  local animation = record and record.source ~= "pokemmo" and record.animationCards
  def.ascendantPokemonFlameCards = type(cards) == "table" and cards or nil
  def.ascendantPokemonAnimationCards = type(animation) == "table" and animation or nil
  def.ascendantPokemonAnimationClips = type(animation) == "table" and {"idle", "walk"} or nil
  def.ascendantPokemonFlamePhase = nil
  def.ascendantPokemonAnimationPhase = nil
  if (type(cards) == "table" or type(animation) == "table") and type(mon) == "table" then
    local phase = self.flamePhases[mon]
    if phase == nil then
      self.flamePhaseSerial = self.flamePhaseSerial + 1
      phase = (self.flamePhaseSerial * .61803398875) % 1
      self.flamePhases[mon] = phase
    end
    if cards then def.ascendantPokemonFlamePhase = phase end
    if animation then def.ascendantPokemonAnimationPhase = phase end
  end
end

function Runtime:activeMon(game, needHealthy)
  local party = game and game.save and game.save.party or {}
  local selected = self.mod.save:get("selected_mon")
  local selectedSlot = tonumber(self.mod.save:get("selected_slot"))
  if selected then
    local atSlot = selectedSlot and party[selectedSlot] or nil
    if atSlot and fingerprint(atSlot) == selected
        and (not needHealthy or healthy(atSlot)) then
      return atSlot, selectedSlot, "selected"
    end
    for index, mon in ipairs(party) do
      if fingerprint(mon) == selected and (not needHealthy or healthy(mon)) then
        return mon, index, "selected"
      end
    end
  end
  for index, mon in ipairs(party) do
    if not needHealthy or healthy(mon) then return mon, index, "party" end
  end
  return nil
end

function Runtime:select(mon, game)
  if not healthy(mon) then return false, "pokemon_not_eligible" end
  local party = game and game.save and game.save.party or {}
  local slot
  for index, candidate in ipairs(party) do
    if candidate == mon then slot = index break end
  end
  if not slot then return false, "pokemon_not_in_party" end
  self.mod.save:set("selected_mon", fingerprint(mon))
  self.mod.save:set("selected_slot", slot)
  self:sync(game, worldFor(game))
  return true
end

function Runtime:shouldSpawn(game, world)
  local save = game and game.save
  if not (save and world and world.player) then return false end
  if save.onBike or world.player.surfing then return false end
  if self.generation == 1 then
    local ok, GameVersion = pcall(require, "src.core.GameVersion")
    if ok and GameVersion.isYellow and GameVersion.isYellow() then
      local flags = save.flags or {}
      if not flags.EVENT_GOT_STARTER then return false end
      if save.pikachuInBall == true then return false end
      if save.pikachuInBall == nil
          and not flags.EVENT_BATTLED_RIVAL_IN_OAKS_LAB then return false end
    end
  end
  local mon = self:activeMon(game, true)
  return mon ~= nil
end

function Runtime:_spriteDef(game, world)
  local id = "SPRITE_PIKACHU"
  local sprites = game and game.data and game.data.sprites
  local def = sprites and sprites[id] or nil
  if not def and world and type(world.sprites) == "table" then
    def = world.sprites[id]
  end
  return def
end

function Runtime:configure(game, world, mon)
  mon = mon or self:activeMon(game, true)
  if not mon then return nil, "no_healthy_party_pokemon" end
  local path, dex, relative = self.catalog.asset(self.mod, game, mon, false)
  if not path then return nil, "species_outside_national_dex_001_251" end
  local walksheet, variant
  if followerSpritesEnabled(self.mod)
      and self.pokemonWalksheets then
    local resolver = self.pokemonWalksheets.resolveFollower
      or self.pokemonWalksheets.resolve
    walksheet, _, variant = resolver(self.pokemonWalksheets, game, mon)
    if walksheet then path = self.mod.path .. "/" .. walksheet.runtime end
  end
  if self.mod._vascIntegrated and not walksheet then
    self.assetPresence = self.assetPresence or {}
    if self.assetPresence[relative] == nil then
      local info = self.mod:info(relative)
      self.assetPresence[relative] = type(info) == "table"
        and info.type == "file" and (info.size == nil or info.size > 0)
    end
    if not self.assetPresence[relative] then
      return nil, "no_usable_follower_sheet_owner_retained"
    end
  end
  local def = self:_spriteDef(game, world)
  if not def then return nil, "follower_sprite_record_unavailable" end
  local localDef = clone(def)
  localDef.image = path
  localDef.frames = self.catalog.FRAMES
  localDef.walker = true
  localDef.trueColor = true
  localDef.pokemonSpecies = mon.species
  localDef.pokemonDex = dex
  self:_bindFlameCards(localDef, walksheet, mon)
  if walksheet then
    localDef.ascendantAtlasImage = self.mod.path .. "/" .. walksheet.atlas
    localDef.ascendantAtlasRelative = walksheet.atlas
    localDef.ascendantRole = ("pokemon_%03d"):format(dex)
    localDef.ascendantScaleClass = walksheet.scaleClass
    localDef.ascendantWorldHeight = self.scaleProfiles
      and (self.scaleProfiles.worldHeightForRecord
        and self.scaleProfiles.worldHeightForRecord(walksheet)
        or self.scaleProfiles.worldHeightForClass(walksheet.scaleClass)) or nil
    localDef.ascendantRuntimeContentWidth = walksheet.runtimeContentWidth
    localDef.ascendantRuntimeContentHeight = walksheet.runtimeContentHeight
    localDef.ascendantPokemonGender = walksheet.gender
    localDef.ascendantPokemonPalette = walksheet.palette
    localDef.ascendantPokemonExactPalette = variant and variant.exactPalette
    localDef.ascendantPokemonContext = "follower"
    localDef.ascendantPokemonWalksheet = true
    localDef.ascendantPokemonMotionProfile = walksheet.motionProfile
    localDef.ascendantPokemonSpriteSource = walksheet.source
      or "ascendant_hd"
    localDef.ascendantPokemonMotionColumns = animationMotionColumns(walksheet)
    localDef.ascendantPokemonAnimationClips = walksheet.animationCards and {"idle","walk"} or nil
    localDef.ascendantPokemonDirectionRows = {
      "front", "left", "back", "right",
    }
    localDef.ascendantPokemonIdleEventManifest =
      self.pokemonWalksheets.idleEventManifest
    localDef.ascendantPokemonIdleEventRoot =
      self.pokemonWalksheets.idleEventRoot
    local idle = self.pokemonWalksheets.idleEvents
      and self.pokemonWalksheets.idleEvents[walksheet.dex]
      and self.pokemonWalksheets.idleEvents[walksheet.dex][walksheet.palette]
      or nil
    localDef.ascendantPokemonBlinkSheet = idle and idle.sheet or nil
    localDef.ascendantPokemonBlinkSourceExact = idle and idle.sourceExact or nil
    localDef.ascendantPokemonBlinkSha256 = idle and idle.sha256 or nil
  else
    localDef.ascendantAtlasImage = nil
    localDef.ascendantAtlasRelative = nil
    localDef.ascendantRole = nil
    localDef.ascendantScaleClass = nil
    localDef.ascendantWorldHeight = nil
    localDef.ascendantRuntimeContentWidth = nil
    localDef.ascendantRuntimeContentHeight = nil
    localDef.ascendantPokemonGender = nil
    localDef.ascendantPokemonPalette = nil
    localDef.ascendantPokemonExactPalette = nil
    localDef.ascendantPokemonContext = nil
    localDef.ascendantPokemonWalksheet = nil
    localDef.ascendantPokemonMotionProfile = nil
    localDef.ascendantPokemonSpriteSource = nil
    localDef.ascendantPokemonMotionColumns = nil
    localDef.ascendantPokemonDirectionRows = nil
    localDef.ascendantPokemonIdleEventManifest = nil
    localDef.ascendantPokemonIdleEventRoot = nil
    localDef.ascendantPokemonBlinkSheet = nil
    localDef.ascendantPokemonBlinkSourceExact = nil
    localDef.ascendantPokemonBlinkSha256 = nil
  end
  return localDef, path, dex
end

function Runtime:sync(game, world)
  game = game or self.activeGame
  world = world or worldFor(game)
  if not (game and world) then return nil, "world_unavailable" end
  self.activeGame = game
  local mon = self:activeMon(game, true)
  local def, path, dex = self:configure(game, world, mon)
  if not def then return nil, path end

  local follower = self.follower and self.follower.current
    and self.follower.current(world) or nil
  if not follower then return nil, "follower_pending" end
  if follower.followerSprite ~= path or not follower.sprite
      or not follower.sprite.def or follower.sprite.def.image ~= path
      or follower.sprite.def.ascendantAtlasImage
        ~= def.ascendantAtlasImage then
    local SpriteRenderer = require("src.render.SpriteRenderer")
    local localDef = clone(def)
    follower.sprite = SpriteRenderer.new(localDef, follower.id)
    follower.spriteDef = localDef
  end
  follower.followerSprite = path
  follower.ascendantPokemonSpriteContext = def.ascendantPokemonContext
  follower._ascendantPokemonOverworld = true
  self.compat.tagFollower(follower, mon, dex)
  return follower, nil, dex
end

function Runtime:_registerSprite()
  local content = self.mod.content and self.mod.content.sprites
  if not content then return false, "sprite_content_registry_unavailable" end
  local existing
  if type(content.get) == "function" then
    local ok, value = pcall(content.get, content, "SPRITE_PIKACHU")
    if ok then existing = value end
  end
  local relative = self.catalog.relative(25, false, false)
  if self.mod._vascIntegrated and not self.mod:info(relative) then
    -- The bootstrap record can be constructed before a party is adopted.
    -- Optional HD is not bundled; never publish a missing image to Gen2's
    -- eager SpriteRenderer. configure() selects the actual party art later.
    if existing then return true, "original_sprite_owner_retained" end
    relative = "assets/pokemmo-runtime/follower_025_male_normal_base.png"
    if not self.mod:info(relative) then
      return false, "follower_bootstrap_sheet_unavailable"
    end
  end
  local fallback = {
    id="SPRITE_PIKACHU",
    image=self.mod.path .. "/" .. relative,
    frames=self.catalog.FRAMES,
    walker=true,
    trueColor=true,
    pokemonSpecies="PIKACHU",
    pokemonDex=25,
  }
  if existing and type(content.patch) == "function" then
    content:patch("SPRITE_PIKACHU", fallback)
  else
    content:register("SPRITE_PIKACHU", fallback)
  end
  return true
end

function Runtime:_installSelectionMenu()
  if not (self.mod.hooks and type(self.mod.hooks.wrap) == "function") then
    return false, "party_submenu_hook_unavailable"
  end
  local runtime = self
  self.mod.hooks:wrap("ui.party.submenu",
    function(nextHandler, game, items, mon, context)
      local result = nextHandler(game, items, mon, context)
      if type(result) ~= "table" or (context and context.battle)
          or not healthy(mon) then return result end
      local active = runtime:activeMon(game, true)
      local german = game and game.data and game.data.strings
        and game.data.strings.CANCEL == "ZURÜCK"
      result[#result + 1] = {
        id="ascendant_pokemon_overworld_follower",
        label=german and (active == mon and "FOLGT" or "FOLGEN")
          or (active == mon and "FOLLOWING" or "FOLLOWER"),
        onSelect=function(selected, selectedGame)
          runtime:select(selected or mon, selectedGame or game)
        end,
      }
      return result
    end, -50)
  return true
end

function Runtime:_installDelegated(ownerId, ownerApi)
  local sprites = type(ownerApi) == "table" and ownerApi.followerSprites
  if type(sprites) ~= "table" or type(sprites.resolve) ~= "function"
      or type(sprites.configure) ~= "function" then
    return false, "delegated_follower_sprite_seam_unavailable"
  end
  local bridgeKey = STATE_KEY .. "Delegated"
  local previous = rawget(sprites, bridgeKey)
  if previous and type(previous.restore) == "function" then pcall(previous.restore) end
  local originalResolve, originalConfigure = sprites.resolve, sprites.configure
  local runtime = self

  local function selected(game, mon)
    if not followerSpritesEnabled(runtime.mod)
        or not runtime.pokemonWalksheets then return nil end
    local resolver = runtime.pokemonWalksheets.resolveFollower
      or runtime.pokemonWalksheets.resolve
    return resolver(runtime.pokemonWalksheets, game, mon)
  end

  local function resolve(game, mon)
    local record = selected(game, mon)
    if record then return runtime.mod.path .. "/" .. record.runtime end
    return originalResolve(game, mon)
  end

  local function configure(game, mon)
    local def, path = originalConfigure(game, mon)
    if type(def) ~= "table" then return def, path end
    local record, _, variant = selected(game, mon)
    if runtime.mod._vascIntegrated then
      if not record then return def, path end
      def = clone(def)
    end
    runtime:_bindFlameCards(def, record, mon)
    if record then
      def.ascendantAtlasImage = runtime.mod.path .. "/" .. record.atlas
      def.ascendantAtlasRelative = record.atlas
      def.ascendantRole = ("pokemon_%03d"):format(record.dex)
      def.ascendantScaleClass = record.scaleClass
      def.ascendantWorldHeight = runtime.scaleProfiles
        and (runtime.scaleProfiles.worldHeightForRecord
          and runtime.scaleProfiles.worldHeightForRecord(record)
          or runtime.scaleProfiles.worldHeightForClass(record.scaleClass)) or nil
      def.ascendantRuntimeContentWidth = record.runtimeContentWidth
      def.ascendantRuntimeContentHeight = record.runtimeContentHeight
      def.ascendantPokemonGender = record.gender
      def.ascendantPokemonPalette = record.palette
      def.ascendantPokemonExactPalette = variant and variant.exactPalette
      def.ascendantPokemonContext = "follower"
      def.ascendantPokemonWalksheet = true
      def.ascendantPokemonMotionProfile = record.motionProfile
      def.ascendantPokemonSpriteSource = record.source or "ascendant_hd"
      def.ascendantPokemonMotionColumns = animationMotionColumns(record)
      def.ascendantPokemonAnimationClips = record.animationCards and {"idle","walk"} or nil
      def.ascendantPokemonDirectionRows = {
        "front", "left", "back", "right",
      }
      def.ascendantPokemonIdleEventManifest =
        runtime.pokemonWalksheets.idleEventManifest
      def.ascendantPokemonIdleEventRoot =
        runtime.pokemonWalksheets.idleEventRoot
      local idle = runtime.pokemonWalksheets.idleEvents
        and runtime.pokemonWalksheets.idleEvents[record.dex]
        and runtime.pokemonWalksheets.idleEvents[record.dex][record.palette]
        or nil
      def.ascendantPokemonBlinkSheet = idle and idle.sheet or nil
      def.ascendantPokemonBlinkSourceExact = idle and idle.sourceExact or nil
      def.ascendantPokemonBlinkSha256 = idle and idle.sha256 or nil
    else
      def.ascendantAtlasImage = nil
      def.ascendantAtlasRelative = nil
      def.ascendantRole = nil
      def.ascendantScaleClass = nil
      def.ascendantWorldHeight = nil
      def.ascendantRuntimeContentWidth = nil
      def.ascendantRuntimeContentHeight = nil
      def.ascendantPokemonGender = nil
      def.ascendantPokemonPalette = nil
      def.ascendantPokemonExactPalette = nil
      def.ascendantPokemonContext = nil
      def.ascendantPokemonWalksheet = nil
      def.ascendantPokemonMotionProfile = nil
      def.ascendantPokemonSpriteSource = nil
      def.ascendantPokemonMotionColumns = nil
      def.ascendantPokemonDirectionRows = nil
      def.ascendantPokemonIdleEventManifest = nil
      def.ascendantPokemonIdleEventRoot = nil
      def.ascendantPokemonBlinkSheet = nil
      def.ascendantPokemonBlinkSourceExact = nil
      def.ascendantPokemonBlinkSha256 = nil
    end
    return def, path
  end

  sprites.resolve, sprites.configure = resolve, configure
  local state = {}
  function state.restore()
    if sprites.resolve == resolve then sprites.resolve = originalResolve end
    if sprites.configure == configure then sprites.configure = originalConfigure end
    if rawget(sprites, bridgeKey) == state then sprites[bridgeKey] = nil end
  end
  sprites[bridgeKey] = state
  self.restore = state.restore
  self.delegatedBridge = true
  return true
end

function Runtime:_installFollower()
  local follower = require("src.world.PikachuFollower")
  self.follower = follower
  local previous = rawget(follower, STATE_KEY)
  if previous and type(previous.restore) == "function" then
    pcall(previous.restore)
  end
  local originalUpdate = follower.update
  local originalMap = follower.onMapEntered
  local runtime = self
  local predicate = function(game, world)
    return runtime:shouldSpawn(game, world)
  end

  local predicateRestore
  local baseUpdate, baseMap = originalUpdate, originalMap
  if self.generation == 1 then
    if not self.gen1Follower then return false, "gen1_follower_controller_missing" end
    local controller = self.gen1Follower.new(predicate)
    baseUpdate, baseMap = controller.update, controller.onMapEntered
  elseif type(follower.setShouldSpawn) == "function" then
    local previous = follower.setShouldSpawn(predicate)
    predicateRestore = function() follower.setShouldSpawn(previous) end
  else
    local patch, reason = replaceUpvalue(originalUpdate, "shouldSpawn", predicate)
    if not patch then return false, reason end
    predicateRestore = function()
      if patch.fn then debug.setupvalue(patch.fn, patch.index, patch.previous) end
    end
  end

  local wrappedMap = function(game, world, options, viaMapLoad)
    runtime.activeGame = game
    runtime:configure(game, world)
    local value = baseMap(game, world, options, viaMapLoad)
    runtime:sync(game, world)
    return value
  end
  local wrappedUpdate = function(game, world)
    runtime.activeGame = game
    runtime:configure(game, world)
    local value = baseUpdate(game, world)
    runtime:sync(game, world)
    return value
  end
  follower.onMapEntered = wrappedMap
  follower.update = wrappedUpdate

  self.restore = function()
    if predicateRestore then predicateRestore() end
    if follower.onMapEntered == wrappedMap then
      follower.onMapEntered = originalMap
    end
    if follower.update == wrappedUpdate then follower.update = originalUpdate end
    if rawget(follower, STATE_KEY)
        and follower[STATE_KEY].runtime == self then follower[STATE_KEY] = nil end
  end
  follower[STATE_KEY] = { runtime=self, restore=self.restore }
  return true
end

function Runtime:install()
  local ownerId, ownerApi = self.compat.followerOwner()
  if ownerId then
    self.mode = "delegated"
    self.ownerId = ownerId
    local bridged, bridgeReason = self:_installDelegated(ownerId, ownerApi)
    self.installed = bridged
    self.lastError = bridged and nil or bridgeReason
    return false, bridged and ("follower_owned_by_" .. ownerId) or bridgeReason
  end
  local ok, reason = self:_registerSprite()
  if not ok then self.mode, self.lastError = "failed", reason return false, reason end
  ok, reason = self:_installFollower()
  if not ok then self.mode, self.lastError = "failed", reason return false, reason end
  ok, reason = self:_installSelectionMenu()
  if not ok then
    if self.restore then self.restore() end
    self.mode, self.lastError = "failed", reason
    return false, reason
  end
  self.mode = "standalone"
  self.installed = true
  return true
end

function Runtime:health()
  return {
    schema="ascendant.compat-status/v1",
    ok=self.installed or self.mode == "delegated",
    state=self.mode,
    generation=self.generation,
    owner=self.ownerId or self.mod.id,
    delegatedBridge=self.delegatedBridge == true,
    lastError=self.lastError,
    vasc=self.compat.vascStatus(),
    characters=self.characters:health(),
    pokemonWalksheets=self.pokemonWalksheets
      and self.pokemonWalksheets:public() or nil,
  }
end

function Runtime:public()
  local runtime = self
  return {
    schema="ascendant.pokemon-overworld.runtime/v1",
    generation=self.generation,
    mode=function() return runtime.mode end,
    owner=function() return runtime.ownerId or runtime.mod.id end,
    activeMon=function(game, needHealthy)
      return runtime:activeMon(game, needHealthy ~= false)
    end,
    select=function(mon, game) return runtime:select(mon, game) end,
    sync=function(game) return runtime:sync(game, worldFor(game)) end,
    restore=function()
      if runtime.restore then runtime.restore() end
      runtime.installed, runtime.mode = false, "stopped"
      return true
    end,
    health=function() return runtime:health() end,
  }
end

Runtime.fingerprint = fingerprint
Runtime.healthy = healthy
Runtime.OPPOSITE = OPPOSITE
return Runtime
