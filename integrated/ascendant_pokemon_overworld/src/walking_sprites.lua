-- Runtime binding for the approved transparent 4x3 character atlases.
--
-- The native engine consumes a six-frame 16x96 strip. Each replacement def
-- therefore points at a generated native fallback and also carries the full
-- 4x3 atlas as metadata for VASC. No shared game definition is mutated: live
-- renderers are replaced locally and their exact originals are restorable.

local WalkingSprites = {}
WalkingSprites.__index = WalkingSprites

WalkingSprites.SCHEMA = "ascendant.walking-sprite-replacements/v1"

-- Explicitly rejected/not-yet-approved artwork never replaces the cartridge
-- sprite.  Keeping the files outside runtime selection makes rollback exact
-- while a corrected sheet is prepared.
local REJECTED_ATLASES = {
  ["assets/characters/npcs/youngster-kasc-hd-4x3-walk-sheet-v1.png"] = true,
}

-- These approved Gen-1 palettes have deliberate filename suffixes that do
-- not follow the generic KASC naming rule below. Preserve their semantic
-- youth roles for sizing without changing artwork or aliasing the ambiguous
-- cartridge SPRITE_YOUNGSTER constant to either trainer class.
local EXACT_YOUTH_ROLES = {
  ["assets/characters/npcs/youngster-gen1-bald-hd-4x3-walk-sheet-v1.png"] = "youngster",
  ["assets/characters/npcs/youngster-gen1-bald-hd-4x3-walk-sheet-v1-bald-green.png"] = "youngster",
  ["assets/characters/npcs/youngster-gen1-bald-hd-4x3-walk-sheet-v1-bald-red.png"] = "youngster",
  ["assets/characters/npcs/bug-catcher-gen1-kasc-hd-4x3-walk-sheet-v1-bug-teal.png"] = "bug-catcher",
  ["assets/characters/npcs/bug-catcher-gen1-kasc-hd-4x3-walk-sheet-v1-bug-navy.png"] = "bug-catcher",
}

local function split(line, separator)
  local result = {}
  for value in (line .. separator):gmatch("(.-)" .. separator) do
    result[#result + 1] = value
  end
  return result
end

local function normalize(value)
  return tostring(value or ""):upper():gsub("[^A-Z0-9]", "")
end

local function clone(source)
  local result = {}
  for key, value in pairs(source or {}) do result[key] = value end
  return result
end

local function invoke(owner, name, ...)
  local fn = type(owner) == "table" and owner[name]
  if type(fn) ~= "function" then return nil end
  local ok, value = pcall(fn, ...)
  if not ok or value == nil then ok, value = pcall(fn, owner, ...) end
  return ok and value or nil
end

local function option(mod, key, fallback)
  local options = mod and mod.options
  if not (options and type(options.get) == "function") then return fallback end
  local ok, value = pcall(options.get, options, key)
  if not ok or value == nil then return fallback end
  return value == true
end

local function roleFromPath(path)
  if EXACT_YOUTH_ROLES[path] then return EXACT_YOUTH_ROLES[path] end
  local stem = tostring(path or ""):match("([^/]+)%.png$") or "actor"
  stem = stem:gsub("[_%-]cards[_%-]4x3$", "")
    :gsub("%-variant%-.+$", "")
    :gsub("%-kasc%-hd%-4x3%-walk%-sheet%-v%d+$", "")
  if stem == "blue-johto-gym" then return "blue" end
  if stem == "red-mt-silver" then return "red" end
  return stem
end

local function scaleClass(role)
  local child = {
    red=true, green=true, blue=true, gold=true, kris=true, silver=true,
    ["little-boy"]=true, ["little-girl"]=true, youngster=true, lass=true,
    girl=true, ["brunette-girl"]=true,
    ["jr-trainer-female"]=true, ["jr-trainer-male"]=true,
    ["school-kid-male-gen2"]=true, ["school-kid-female-gen2"]=true,
    ["bug-catcher"]=true,
    ["camper-gen2"]=true, ["picnicker-gen2"]=true, ["twins-gen2"]=true,
    ["game-boy-kid"]=true,
  }
  return child[role] and "human_child" or "human_adult"
end

local function identityRole(id, generation, kascActive)
  local value = normalize(id)
  if generation == 1 and value == "SPRITERED" then return "red" end
  if value == "SPRITEBLUE" then return "blue" end
  if value == "SPRITERIVAL" then return generation == 2 and "silver" or "blue" end
  -- Gen 2's original male player constant is CHRIS.  KRIS is the Crystal
  -- heroine; treating both as Kris caused JASC Gold/Kris to inherit Red.
  if generation == 2 and value == "SPRITECHRIS" then return "gold" end
  if generation == 2 and value == "SPRITEKRIS" then return "kris" end
  if generation == 2 and (value == "SPRITEGOLD" or value == "SPRITEETHAN") then
    return "gold"
  end
  if kascActive and (value == "SPRITEKAGREEN"
      or value:find("SPRITEKACRYSTALGREENWALK", 1, true)) then
    return "green"
  end
  if kascActive and value:find("SPRITEKACRYSTALBLUEWALK", 1, true) then
    return "blue"
  end
  if kascActive and value:find("SPRITEKACRYSTALREDWALK", 1, true) then
    return "red"
  end
  return nil
end

local function worldFor(game)
  return game and (game.overworld or game.world) or nil
end

function WalkingSprites.new(options)
  local self = setmetatable({
    mod=assert(options.mod), generation=assert(options.generation),
    compat=assert(options.compat), npcCatalog=assert(options.npcCatalog),
    activeGame=nil, installed=false, applied=0, lastError=nil,
    originals=setmetatable({}, { __mode="k" }),
    runtimeByAtlas={}, rowsByMap={}, atlasByRole={}, atlasBySprite={},
    variantsByBase={}, variantSprites={},
    playerRole=nil,
    characterActions=options.characterActions,
    playerBridges=setmetatable({}, { __mode="k" }),
    debugLog=options.debugLog,
  }, WalkingSprites)
  self:_loadRuntimeManifest()
  self:_indexNpcRows()
  self:_indexRoles()
  return self
end

function WalkingSprites:_savedPlayerRole(game)
  local save = game and game.save
  local player = save and save.player
  if self.generation ~= 2 or type(player) ~= "table" then return nil end
  local key = tostring(player.characterKey or ""):lower()
  local route = tostring(player.routeKey or ""):lower()
  if key == "johto.kris" or route == "jasc.crystal_path" then return "kris" end
  if key == "johto.gold" or route == "jasc.gold_path" then return "gold" end
  if key == "johto.silver" or route == "jasc.silver_path" then return "silver" end
  local version = tostring(save.version or ""):lower()
  local gender = tostring(player.gender or ""):lower()
  if version == "crystal" and (gender == "female" or gender == "f") then
    return "kris"
  end
  return nil
end

function WalkingSprites:_loadRuntimeManifest()
  local body, err = self.mod:read("production/walking-sprite-runtime.tsv")
  if type(body) ~= "string" then self.lastError = err or "runtime_manifest_missing" return end
  local first = true
  for line in body:gmatch("[^\r\n]+") do
    if first then first = false else
      local field = split(line, "\t")
      local isPaletteVariant = field[1] and field[1]:find("%-variant%-") ~= nil
      local rejected = self.generation == 1
        and (REJECTED_ATLASES[field[1]] or isPaletteVariant)
      if field[1] and field[2] and not rejected then
        self.runtimeByAtlas[field[1]] = field[2]
      end
    end
  end
  local variantManifest = self.generation == 2
    and "production/npc-palette-variants.tsv"
    or "production/npc-palette-variants-gen1.tsv"
  local variants = self.mod:read(variantManifest)
  if type(variants) == "string" then
    local header = true
    for line in variants:gmatch("[^\r\n]+") do
      if header then header = false else
        local field = split(line, "\t")
        if self.runtimeByAtlas[field[2]] then
          self.variantsByBase[field[1]] = self.variantsByBase[field[1]] or {}
          self.variantsByBase[field[1]][#self.variantsByBase[field[1]]+1] = field[2]
        end
      end
    end
  end
end

function WalkingSprites:_indexNpcRows()
  local occurrences = {}
  for _, row in ipairs(self.npcCatalog.inventory(self.generation) or {}) do
    local map = normalize(row.map)
    local occurrenceKey = map .. ":" .. normalize(row.sprite)
    occurrences[occurrenceKey] = (occurrences[occurrenceKey] or 0) + 1
    row.ascendantVariantIndex = occurrences[occurrenceKey]
    self.rowsByMap[map] = self.rowsByMap[map] or {}
    local key = table.concat({ normalize(row.sprite), tostring(row.x), tostring(row.y) }, ":")
    self.rowsByMap[map][key] = self.rowsByMap[map][key] or {}
    self.rowsByMap[map][key][#self.rowsByMap[map][key] + 1] = row
    local sprite = normalize(row.sprite)
    self.atlasBySprite[sprite] = self.atlasBySprite[sprite] or {}
    local seen = {}
    for _, current in ipairs(self.atlasBySprite[sprite]) do seen[current] = true end
    for _, atlas in ipairs(row.assets or {}) do
      if self.runtimeByAtlas[atlas] and not seen[atlas] then
        self.atlasBySprite[sprite][#self.atlasBySprite[sprite] + 1] = atlas
        seen[atlas] = true
      end
      for _, variant in ipairs(self.variantsByBase[atlas] or {}) do
        if self.runtimeByAtlas[variant] and not seen[variant] then
          self.atlasBySprite[sprite][#self.atlasBySprite[sprite] + 1] = variant
          self.variantSprites[sprite] = true
          seen[variant] = true
        end
      end
    end
  end
  -- Both are approved lab-coated adults in the same visual language. This
  -- provides stable KASC researcher variety without inventing a new identity.
  local scientist = self.atlasBySprite.SPRITESCIENTIST
  local pharmacist = "assets/characters/npcs/pharmacist-gen2-kasc-hd-4x3-walk-sheet-v1.png"
  if scientist and self.runtimeByAtlas[pharmacist] then
    local exists = false
    for _, atlas in ipairs(scientist) do
      if atlas == pharmacist then exists = true break end
    end
    if not exists and #scientist < 4 then scientist[#scientist + 1] = pharmacist end
  end
end

function WalkingSprites:_indexRoles()
  local preferred = {
    red="assets/characters/red_cards_4x3.png",
    green="assets/characters/green_cards_4x3.png",
    blue="assets/characters/blue_cards_4x3.png",
    gold="assets/characters/gold_cards_4x3.png",
    kris="assets/characters/kris_cards_4x3.png",
    silver="assets/characters/npcs/silver-kasc-hd-4x3-walk-sheet-v1.png",
    oak="assets/characters/npcs/professor-oak-kasc-hd-4x3-walk-sheet-v1.png",
  }
  for role, atlas in pairs(preferred) do
    if self.runtimeByAtlas[atlas] then self.atlasByRole[role] = atlas end
  end
end

function WalkingSprites:enabled()
  return option(self.mod, "hd_walking_sprites", true)
end

function WalkingSprites:_kasc()
  for _, source in ipairs(self.compat.characterSources() or {}) do
    if source.kind == "kasc" then return source.provider end
  end
  return nil
end

-- The atlas replacement belongs to this mod, but the selected protagonist
-- does not.  Keep that distinction explicit so a renderer refresh can never
-- make APO look like the authority for KASC's Casey/Green (or JASC's Johto
-- choice).  Consumers that care about the image can inspect the separate
-- ascendantWalkingSpriteOwner field.
function WalkingSprites:_playerIdentityOwner()
  local wanted = self.generation == 2 and "jasc" or "kasc"
  for _, source in ipairs(self.compat.characterSources() or {}) do
    if source.kind == wanted then
      return source.id or (wanted == "jasc"
        and "johto_ascendant" or "kanto_ascendant")
    end
  end
  return nil
end

function WalkingSprites:_visiblePlayerRole(player)
  if type(player) ~= "table" then return nil end
  local def = player.sprite and player.sprite.def or player.spriteDef or {}
  local explicit = tostring(def.ascendantRole or ""):lower()
  if self.atlasByRole[explicit] then return explicit end
  local tagged = identityRole(player.ascendantCharacter,
    self.generation, self:_kasc() ~= nil)
  if self.atlasByRole[tagged] then return tagged end
  local visible = identityRole(def.id or self:_identity(player),
    self.generation, self:_kasc() ~= nil)
  -- The cartridge defaults (Red and Chris/Gold) may still be visible before
  -- KASC/JASC applies the user's selection.  Alternative hero identities are
  -- unambiguous and must outrank a provider's transient default value.
  if visible == "green" or visible == "blue" or visible == "kris" then
    return visible
  end
  return nil
end

function WalkingSprites:_playerRole(refreshAuthority, player)
  -- Movement ticks refresh the renderer, not the selected identity. JASC can
  -- briefly report nil/a default while advancing the world; retaining the
  -- role established by a load/map/selection event prevents Kris becoming
  -- Gold immediately after the first step.
  if refreshAuthority == false and self.generation == 1
      and self.playerRole == "red" then
    for _, source in ipairs(self.compat.characterSources() or {}) do
      if source.kind == "kasc" then
        local role = tostring(invoke(source.provider,
          "getPlayerCharacter") or ""):lower()
        if role ~= "red" and self.atlasByRole[role] then
          self.playerRole = role
          if self.debugLog then
            self.debugLog:role("kasc-save-recovery", role,
              self.activeGame, player)
          end
          return role
        end
      end
    end
  end
  if refreshAuthority == false and self.atlasByRole[self.playerRole] then
    return self.playerRole
  end
  -- KASC's character.selected event is authoritative and its getter reads a
  -- stable mod-save record.  It must outrank our currently visible renderer,
  -- which may still be the Red replacement from before Casey/Green was
  -- selected.  JASC is deliberately excluded: its transient default during
  -- rebuilds is the original Kris->Ethan failure this latch protects against.
  if self.generation == 1 and refreshAuthority == "kasc-event" then
    for _, source in ipairs(self.compat.characterSources() or {}) do
      if source.kind == "kasc" then
        local role = tostring(invoke(source.provider,
          "getPlayerCharacter") or ""):lower()
        if self.atlasByRole[role] then
          self.playerRole = role
          if self.debugLog then
            self.debugLog:role("kasc-event", role, self.activeGame, player)
          end
          return role
        end
      end
    end
  end
  local visible = self:_visiblePlayerRole(player)
  if visible then
    self.playerRole = visible
    if self.debugLog then self.debugLog:role("visible", visible, self.activeGame, player) end
    return visible
  end
  local saved = self:_savedPlayerRole(self.activeGame)
  if self.atlasByRole[saved] then
    self.playerRole = saved
    if self.debugLog then self.debugLog:role("save", saved, self.activeGame, player) end
    return saved
  end
  local sources = self.compat.characterSources() or {}
  local function from(kind)
    for _, source in ipairs(sources) do
      if source.kind == kind and kind == "kasc" then
      local role = tostring(invoke(source.provider, "getPlayerCharacter") or ""):lower()
      if self.atlasByRole[role] then return role end
      elseif source.kind == kind and kind == "jasc" then
      local role = tostring(invoke(source.provider, "current", self.activeGame) or ""):lower()
      if role == "ethan" then role = "gold" end
      if role == "crystal" then role = "kris" end
      if self.atlasByRole[role] then return role end
      end
    end
    return nil
  end
  -- KASC may also be loaded in a Gen 2 session, but it has no authority over
  -- the Johto player.  JASC is authoritative there; KASC remains authoritative
  -- in Gen 1.
  -- Never cross generations here. A loaded JASC instance must not turn Red
  -- into Kris in Gen 1, and a loaded KASC instance must not override the
  -- selected Johto hero in Gen 2.
  local role = self.generation == 2 and from("jasc") or from("kasc")
  if role then
    self.playerRole = role
    if self.debugLog then self.debugLog:role("provider", role, self.activeGame, player) end
    return role
  end
  if self.atlasByRole[self.playerRole] then return self.playerRole end
  self.playerRole = self.generation == 2 and "gold" or "red"
  return self.playerRole
end

function WalkingSprites:_identity(entity)
  local def = entity and entity.def or {}
  return def.sprite or entity and entity.spriteId
    or entity and entity.sprite and entity.sprite.def and entity.sprite.def.id
    or entity and entity.spriteDef and entity.spriteDef.id
end

function WalkingSprites:_rowFor(mapId, entity)
  local def = entity and entity.def or {}
  local sprite = self:_identity(entity)
  local x = def.x
  if x == nil then x = entity and (entity.cellX or entity.x) end
  local y = def.y
  if y == nil then y = entity and (entity.cellY or entity.y) end
  local key = table.concat({ normalize(sprite), tostring(x), tostring(y) }, ":")
  local candidates = self.rowsByMap[normalize(mapId)]
  candidates = candidates and candidates[key] or nil
  return candidates and candidates[1] or nil
end

local function stableIndex(value, count)
  if count <= 1 then return 1 end
  local hash = 0
  for index = 1, #value do hash = (hash * 33 + value:byte(index)) % 65521 end
  return (hash % count) + 1
end

function WalkingSprites:_atlasFor(mapId, entity, row)
  local identity = self:_identity(entity)
  local sprite = normalize(identity)
  local choices = self.atlasBySprite[sprite] or {}
  local atlas = row and row.assets and row.assets[1] or nil
  if atlas then
    -- A cartridge sprite constant can represent several trainer classes
    -- (notably Gen 1 SPRITE_YOUNGSTER). Once the inventory identified the
    -- concrete row, restrict selection to that class' base and variants.
    -- Mixing the sprite-wide bucket here made Youngsters become Bug Catchers.
    local rowChoices = {}
    if self.runtimeByAtlas[atlas] then rowChoices[#rowChoices+1] = atlas end
    for _, variant in ipairs(self.variantsByBase[atlas] or {}) do
      if self.runtimeByAtlas[variant] then rowChoices[#rowChoices+1] = variant end
    end
    choices = rowChoices
  elseif self.generation == 1 and sprite == "SPRITEYOUNGSTER" then
    -- Without map coordinates/trainer class the shared Gen-1 constant is
    -- ambiguous. Vanilla 2D is safer than assigning the wrong HD identity.
    return nil
  end
  if #choices > 1 and (self.variantSprites[sprite]
      or sprite == "SPRITESCIENTIST") then
    -- Stable per-object selection gives recurring generic classes some visual
    -- variety without flicker or more than the catalogued four candidates.
    local seed = table.concat({ normalize(mapId), normalize(identity),
      tostring(entity and entity.id or ""), tostring(entity and entity.cellX or ""),
      tostring(entity and entity.cellY or "") }, ":")
    local index = row and tonumber(row.ascendantVariantIndex)
      or stableIndex(seed, math.min(#choices, 4))
    atlas = choices[((index - 1) % math.min(#choices, 4)) + 1]
  end
  if atlas and self.runtimeByAtlas[atlas] then return atlas end
  for _, candidate in ipairs(choices) do
    if self.runtimeByAtlas[candidate] then return candidate end
  end
  return nil
end

function WalkingSprites:_bind(entity, atlas, role, identityOwner, action)
  if type(entity) ~= "table" or not atlas then return false end
  local runtime = self.runtimeByAtlas[atlas]
  if not runtime then return false end
  if entity.sprite and entity.sprite.def
      and entity.sprite.def.ascendantAtlasImage == self.mod.path .. "/" .. atlas then
    return false
  end
  local current = entity.sprite
  local source = current and current.def or entity.spriteDef
  if type(source) ~= "table" then return false end
  local SpriteRenderer = require("src.render.SpriteRenderer")
  local original = self.originals[entity]
  if not original or (original.replacement ~= entity.sprite
      and not (entity.sprite and entity.sprite.def
        and entity.sprite.def.ascendantAtlasImage)) then
    original = {
      sprite=entity.sprite, spriteDef=entity.spriteDef,
      ascendantCharacter=entity.ascendantCharacter,
      ascendantCharacterOwner=entity.ascendantCharacterOwner,
      ascendantWalkingAtlas=entity.ascendantWalkingAtlas,
      ascendantWalkingSpriteOwner=entity.ascendantWalkingSpriteOwner,
    }
    self.originals[entity] = original
  end
  local def = clone(source)
  def.image = self.mod.path .. "/" .. runtime
  def.frames, def.walker, def.trueColor = 6, true, true
  -- Every native fallback here is 16x96, including actions. Do not retain
  -- unrelated source-sheet frame dimensions when replacing its image.
  def.frameWidth, def.frameHeight = 16, 16
  def.anchorX, def.anchorY = 8, 16
  def.ascendantAtlasImage = self.mod.path .. "/" .. atlas
  def.ascendantAtlasRelative = atlas
  def.ascendantRole = role or roleFromPath(atlas)
  def.ascendantScaleClass = scaleClass(def.ascendantRole)
  def.ascendantCharacterAction = action
  local ok, renderer = pcall(SpriteRenderer.new, def, entity.id or "player")
  if not ok or not renderer then
    self.lastError = tostring(renderer or "renderer_creation_failed")
    return false
  end
  entity.sprite, entity.spriteDef = renderer, def
  -- The full fishing card already includes the lower-body pose and rod.
  -- Do not paste the native eight-pixel fishing tiles over that artwork.
  if action == "fishing" then renderer.drawTile = function() end end
  original.replacement = renderer
  entity.ascendantCharacter = def.ascendantRole
  entity.ascendantCharacterOwner = identityOwner
    or entity.ascendantCharacterOwner or self.mod.id
  entity.ascendantWalkingAtlas = atlas
  entity.ascendantWalkingSpriteOwner = self.mod.id
  return true
end

function WalkingSprites:restore()
  local count = 0
  for player, bridge in pairs(self.playerBridges) do
    if bridge.bike and player.bikeSprite == bridge.bike.sprite then
      player.bikeSprite = bridge.originalBike
    end
    for _, name in ipairs({"update", "pose"}) do
      if bridge[name] and player[name] == bridge[name].wrapper then
        player[name] = bridge[name].own
      end
    end
    self.playerBridges[player] = nil
  end
  for entity, original in pairs(self.originals) do
    entity.sprite, entity.spriteDef = original.sprite, original.spriteDef
    entity.ascendantCharacter = original.ascendantCharacter
    entity.ascendantCharacterOwner = original.ascendantCharacterOwner
    entity.ascendantWalkingAtlas = original.ascendantWalkingAtlas
    entity.ascendantWalkingSpriteOwner = original.ascendantWalkingSpriteOwner
    count = count + 1
    self.originals[entity] = nil
  end
  self.applied = 0
  return count
end

function WalkingSprites:apply(game, refreshAuthority)
  game = game or self.activeGame
  if game then self.activeGame = game end
  if not self:enabled() then return self:restore() end
  local world = worldFor(game)
  if type(world) ~= "table" then return 0 end
  local count = 0
  local player = world.player
  -- Provider `current()` values can briefly fall back to their default while
  -- maps, dialogs, or renderers are rebuilt. Establish authority once, then
  -- refresh it only for an explicit character-selection event.
  local authority = refreshAuthority
  if authority == nil then authority = self.playerRole == nil end
  local playerRole = self:_playerRole(authority, player)
  if player then count = count + self:_bindPlayer(game, player, playerRole) end
  local mapId = world.map and world.map.id
  local kascActive = self:_kasc() ~= nil
  local seen = {}
  for _, bucket in ipairs({ world.npcs, world.entities, world.objects }) do
    if type(bucket) == "table" then
      for _, entity in pairs(bucket) do
        if type(entity) == "table" and not seen[entity] then
          seen[entity] = true
          local row = self:_rowFor(mapId, entity)
          local atlas = self:_atlasFor(mapId, entity, row)
          local sourceDef = entity.sprite and entity.sprite.def or entity.spriteDef or {}
          local identity = self:_identity(entity) or sourceDef.id
          local role = atlas and roleFromPath(atlas)
            or identityRole(identity, self.generation, kascActive)
          atlas = atlas or self.atlasByRole[role]
          if self:_bind(entity, atlas, role) then count = count + 1 end
        end
      end
    end
  end
  self.applied = self.applied + count
  return count
end

-- KASC may replace only the live player renderer after changing its Kanto
-- character selection. Repairing that one seam each step is cheap and avoids
-- rescanning every NPC on every frame.
function WalkingSprites:refreshPlayer(game)
  game = game or self.activeGame
  if game then self.activeGame = game end
  if not self:enabled() then return 0 end
  local world = worldFor(game)
  local player = world and world.player
  if not player then return 0 end
  local role = self:_playerRole(false, player)
  return self:_bindPlayer(game, player, role)
end

-- The native Gen-1 pose selects bikeSprite, not sprite. Gen 2 rebuilds sprite
-- from playerState. Bind both actual seams without changing selection, physics
-- or the original Player classes; wrappers belong only to this live player.
function WalkingSprites:_bindPlayer(game, player, role)
  local bridge = self.playerBridges[player]
  if not bridge then
    bridge = {}
    self.playerBridges[player] = bridge
    for _, name in ipairs({"update", "pose"}) do
      local raw = player[name]
      if type(raw) == "function" then
        local entry = {own=rawget(player, name)}
        entry.wrapper = function(p, ...)
          self:refreshPlayer(game)
          return raw(p, ...)
        end
        bridge[name] = entry
        player[name] = entry.wrapper
      end
    end
  end
  local actions = self.characterActions
  local function atlasFor(action)
    return actions and actions.relative(role, action)
  end
  if player.bikeSprite then
    if not bridge.bike or player.bikeSprite ~= bridge.bike.sprite then
      bridge.originalBike = player.bikeSprite
      bridge.bike = {sprite=player.bikeSprite, id="player"}
    end
    self:_bind(bridge.bike, atlasFor("bicycle"), role,
      self:_playerIdentityOwner(), "bicycle")
    player.bikeSprite = bridge.bike.sprite
  end
  local world = worldFor(game)
  local state = world and world.playerState
  local action = player.fishing and "fishing"
    or (self.generation == 2 and state == "bike" and "bicycle") or nil
  -- No authored surfing card exists: retain the engine's actual surf pose.
  if self.generation == 2 and state and state ~= "normal" and state ~= "bike"
      and not action then return 0 end
  local atlas = action and atlasFor(action) or self.atlasByRole[role]
  return self:_bind(player, atlas, role, self:_playerIdentityOwner(), action) and 1 or 0
end

function WalkingSprites:install()
  if self.installed then return true end
  self.installed = true
  if self.mod.events and type(self.mod.events.on) == "function" then
    local binder = self
    for _, event in ipairs({ "game.ready", "save.loaded", "map.entered",
        "map.reloaded" }) do
      self.mod.events:on(event, function(ev)
        binder:apply(ev and ev.game or binder.activeGame, false)
      end)
    end
    self.mod.events:on("character.selected", function(ev)
      -- JASC currently also emits this seam while rebuilding the player on
      -- the first movement tick.  Its current() value can be Gold/Ethan for
      -- that one callback even in a Crystal/Kris save, so it is not a safe
      -- authority refresh signal.  The role established from the loaded save
      -- remains latched; a newly loaded/created runtime gets its own binder.
      binder:apply(ev and ev.game or binder.activeGame,
        binder.generation == 1 and "kasc-event" or false)
    end)
    self.mod.events:on("mod.johto_ascendant.character_selected", function(ev)
      if binder.generation ~= 2 then return end
      local selected = tostring(ev and ev.character or ""):lower()
      if selected == "crystal" then selected = "kris" end
      if selected == "ethan" then selected = "gold" end
      if binder.atlasByRole[selected] then
        binder.playerRole = selected
        if binder.debugLog then
          binder.debugLog:role("jasc-event", selected,
            ev and ev.game or binder.activeGame,
            worldFor(ev and ev.game or binder.activeGame)
              and worldFor(ev and ev.game or binder.activeGame).player)
        end
      end
      binder:apply(ev and ev.game or binder.activeGame, false)
    end)
    self.mod.events:on("world.stepped", function(ev)
      binder:refreshPlayer(ev and ev.game or binder.activeGame)
    end)
    self.mod.events:on("mod.options_changed", function(ev)
      if not ev or not ev.mod or ev.mod == binder.mod.id then
        binder:apply(binder.activeGame)
      end
    end)
  end
  return true
end

function WalkingSprites:health()
  local roleCount, runtimeCount = 0, 0
  for _ in pairs(self.atlasByRole) do roleCount = roleCount + 1 end
  for _ in pairs(self.runtimeByAtlas) do runtimeCount = runtimeCount + 1 end
  return {
    schema=WalkingSprites.SCHEMA, ok=self.installed and self.lastError == nil,
    enabled=self:enabled(), generation=self.generation,
    runtimeAssetCount=runtimeCount, heroRoleCount=roleCount,
    playerRole=self.playerRole, applied=self.applied, lastError=self.lastError,
  }
end

function WalkingSprites:public()
  local binder = self
  return {
    schema=WalkingSprites.SCHEMA,
    enabled=function() return binder:enabled() end,
    refresh=function(game) return binder:apply(game) end,
    restore=function() return binder:restore() end,
    health=function() return binder:health() end,
  }
end

return WalkingSprites
