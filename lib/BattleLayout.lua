-- Player-owned battle composition adjustments.
--
-- Authored MAP/ARENA/DISCS anchors remain the neutral baseline.  This module
-- adds one small, saved delta per presentation role so a player can correct a
-- particular sprite family without moving every other actor.  It deliberately
-- stores ordinary VASC mod options and knows nothing about KASC internals:
-- optional sprite providers may change the selected art, while VASC retains
-- ownership of the final stage and fallback-HUD placement.

local V = ...

local ModSetting = V.require("ModSetting")

local BattleLayout = {}

BattleLayout.API_VERSION = 1
BattleLayout.PROFILE_CONTRACT = "vasc-battle-layout-profile/v1"

-- Profiles are deliberately registered as validated data, never discovered
-- by walking arbitrary host paths. The native editor (or a future bounded
-- content importer) hands VASC JSON/table data plus explicit resolver
-- capabilities; VASC remains the sole owner of the final battle geometry.
local importedProfiles = {}
local activePreset
local profileModule

local function profileImporter()
  if profileModule ~= nil then return profileModule or nil end
  local ok, value = pcall(V.require, "BattleLayoutProfile")
  profileModule = ok and type(value) == "table" and value or false
  return profileModule or nil
end

local TARGETS = {
  { id="player_front",         label="P FRONT",  actor=true },
  { id="player_back",          label="P BACK",   actor=true },
  { id="player_retro_back",    label="P RETRO",  actor=true },
  { id="mega",                 label="MEGA",     actor=true },
  { id="enemy_pokemon",        label="E PKMN",   actor=true },
  { id="player_trainer_front", label="P TR F",   actor=true },
  { id="player_trainer_back",  label="P TR B",   actor=true },
  { id="enemy_trainer",        label="E TRAIN",  actor=true },
  { id="hud_enemy_status",     label="E STATUS", hud=true },
  { id="hud_player_status",    label="P STATUS", hud=true },
  { id="hud_enemy_party",      label="E TEAM",   hud=true },
  { id="hud_player_party",     label="P TEAM",   hud=true },
  { id="hud_command",          label="COMMAND",  hud=true },
  { id="hud_message",          label="MESSAGE",  hud=true },
}

local TARGET_BY_ID, TARGET_VALUES, TARGET_LABELS = {}, {}, {}
for _, target in ipairs(TARGETS) do
  TARGET_BY_ID[target.id] = target
  TARGET_VALUES[#TARGET_VALUES + 1] = target.id
  TARGET_LABELS[#TARGET_LABELS + 1] = target.label
end

local AXIS_VALUES = {
  -32, -24, -16, -12, -8, -4, 0, 4, 8, 12, 16, 24, 32,
}
local AXIS_LABELS = {}
for i, value in ipairs(AXIS_VALUES) do AXIS_LABELS[i] = tostring(value) end

local SCALE_VALUES = { .50, .65, .75, .85, .90, 1, 1.10, 1.25, 1.50, 1.75, 2 }
local SCALE_LABELS = {
  "50%", "65%", "75%", "85%", "90%", "100%",
  "110%", "125%", "150%", "175%", "200%",
}

BattleLayout.targets = TARGETS
BattleLayout.targetSetting = ModSetting.new(
  "battleLayoutTarget", "TARGET", TARGET_VALUES, TARGET_LABELS, "player_front")

local SETTINGS = {}
for _, target in ipairs(TARGETS) do
  SETTINGS[target.id] = {
    x = ModSetting.new("battleLayout_" .. target.id .. "_x", "X",
                       AXIS_VALUES, AXIS_LABELS, 0),
    y = ModSetting.new("battleLayout_" .. target.id .. "_y", "Y",
                       AXIS_VALUES, AXIS_LABELS, 0),
    scale = ModSetting.new("battleLayout_" .. target.id .. "_scale", "SIZE",
                           SCALE_VALUES, SCALE_LABELS, 1),
  }
end

local function finite(value, fallback)
  value = tonumber(value)
  if not (value and value == value and value > -math.huge
          and value < math.huge) then return fallback end
  return value
end

local function selectedId()
  local id = BattleLayout.targetSetting:get()
  return TARGET_BY_ID[id] and id or TARGETS[1].id
end

local function selectedSetting(field)
  return SETTINGS[selectedId()][field]
end

local function dynamicRow(field, label)
  return {
    id = "VOXEL_ASCENDANT:battleLayout:" .. field,
    label = label,
    value = function()
      local setting = selectedSetting(field)
      return setting.labels[setting:read()]
    end,
    step = function(game, direction)
      selectedSetting(field):cycle(game, direction)
      return true
    end,
  }
end

local function localized(language, en, de)
  return language == "de" and de or en
end

function BattleLayout.menuRows(language)
  local rows = {
    {
      label="TARGET", descriptor=BattleLayout.targetSetting:row(),
      settingKey="battleLayoutTarget",
      help=localized(language,
        "Choose the sprite or VASC fallback-HUD zone to adjust. Other roles keep their own saved values.",
        "Wähle den Sprite- oder VASC-Fallback-HUD-Bereich. Alle anderen Rollen behalten ihre eigenen gespeicherten Werte."),
    },
    {
      label="X", descriptor=dynamicRow("x", "X"),
      help=localized(language,
        "Move the selected role left (-) or right (+). Actor values are battlefield units; HUD values follow the screen scale.",
        "Verschiebt die gewählte Rolle nach links (-) oder rechts (+). Figuren nutzen Feld-, HUD-Bereiche bildschirmskalierte Einheiten."),
    },
    {
      label="Y", descriptor=dynamicRow("y", "Y"),
      help=localized(language,
        "Move the selected role up (-) or down (+) while retaining its baseline and shadow contract.",
        "Verschiebt die gewählte Rolle nach oben (-) oder unten (+); Fußlinie und Schattenvertrag bleiben gekoppelt."),
    },
    {
      label="SIZE", descriptor=dynamicRow("scale", "SIZE"),
      help=localized(language,
        "Scale only the selected role from 50 to 200 percent. Species height and high-resolution source density are still normalized first.",
        "Skaliert nur die gewählte Rolle von 50 bis 200 Prozent. Artgröße und hochauflösende Quelldichte werden vorher weiter normalisiert."),
    },
    {
      label="RESET ONE", action="layoutResetTarget", right="RESET",
      help=localized(language,
        "Reset X, Y and size for the selected role only.",
        "Setzt X, Y und Größe nur für die gewählte Rolle zurück."),
    },
    {
      label="RESET ALL", action="layoutResetAll", right="RESET",
      help=localized(language,
        "Reset every actor and VASC fallback-HUD role to its reviewed automatic placement.",
        "Setzt alle Figuren und VASC-Fallback-HUD-Bereiche auf die geprüfte automatische Platzierung zurück."),
    },
  }
  for _, row in ipairs(rows) do
    if row.descriptor then
      local ok, value = pcall(row.descriptor.value)
      row.right = ok and tostring(value) or "--"
    end
  end
  return rows
end

function BattleLayout.menuHelp(language)
  return localized(language,
    "Saved fine placement for each front, back, retro-back, Mega, trainer and VASC fallback-HUD role. Defaults always preserve the reviewed automatic layout. KASC may provide artwork, but VASC changes no KASC option or file.",
    "Gespeicherte Feinplatzierung für Front-, Rück-, Retro-Rück-, Mega-, Trainer- und VASC-Fallback-HUD-Rollen. Die Standardwerte bewahren stets die geprüfte Automatik. KASC darf Grafiken liefern; VASC ändert keine KASC-Option oder -Datei.")
end

function BattleLayout.refreshRows(rows)
  for _, row in ipairs(rows or {}) do
    local descriptor = row and row.descriptor
    if descriptor and type(descriptor.value) == "function" then
      local ok, value = pcall(descriptor.value)
      row.right = ok and tostring(value) or "--"
    end
  end
  return rows
end

local function writeStored(game, setting, value)
  setting:setValue(value, nil, true)
  local id = (V.mod and V.mod.id) or "VOXEL_ASCENDANT"
  local opts = game and game.save and game.save.options
  if opts then
    opts.modOptions = opts.modOptions or {}
    opts.modOptions[id] = opts.modOptions[id] or {}
    opts.modOptions[id][setting.key] = value
  end
  local loader = game and game.mods
  if loader then
    loader.modOptions = loader.modOptions or {}
    loader.modOptions[id] = loader.modOptions[id] or {}
    loader.modOptions[id][setting.key] = value
  end
end

local function resetId(game, id)
  local settings = SETTINGS[id]
  if not settings then return false end
  writeStored(game, settings.x, 0)
  writeStored(game, settings.y, 0)
  writeStored(game, settings.scale, 1)
  return true
end

function BattleLayout.resetTarget(game)
  local done = resetId(game, selectedId())
  if done and game and type(game.writeOptions) == "function" then
    pcall(game.writeOptions, game)
  end
  return done
end

function BattleLayout.resetAll(game)
  for _, target in ipairs(TARGETS) do resetId(game, target.id) end
  if game and type(game.writeOptions) == "function" then
    pcall(game.writeOptions, game)
  end
  return true
end

function BattleLayout.syncOption(key, value)
  if key == BattleLayout.targetSetting.key then
    BattleLayout.targetSetting:sync(value)
    return true
  end
  for _, fields in pairs(SETTINGS) do
    for _, setting in pairs(fields) do
      if setting.key == key then setting:sync(value); return true end
    end
  end
  return false
end

local function savedAdjustment(id)
  local fields = SETTINGS[id]
  if not fields then return { x=0, y=0, scale=1, target=id } end
  return {
    x = math.max(-32, math.min(32, finite(fields.x:get(), 0))),
    y = math.max(-32, math.min(32, finite(fields.y:get(), 0))),
    scale = math.max(.5, math.min(2, finite(fields.scale:get(), 1))),
    target = id,
  }
end

local HUD_PROFILE_ROLE = {
  hud_enemy_status="enemy-status",
  hud_player_status="player-status",
  hud_enemy_party="enemy-party-balls",
  hud_player_party="player-party-balls",
  hud_command="command",
  hud_message="message",
}

local function stringId(value)
  if value == nil then return nil end
  value = tostring(value)
  return value ~= "" and value or nil
end

-- One normalized identity for MAP, DISCS and painted ARENA. Stage aliases let
-- old per-map editor exports keep working while newer profiles may distinguish
-- `DISCS:MAP_ID`/`ARENA:MAP_ID` or a reviewed scenery style ID.
function BattleLayout.stageContext(arena, map)
  arena = type(arena) == "table" and arena or {}
  map = map or arena.map
  local mapID = stringId(type(map) == "table" and map.id or map)
  local declaredMode = stringId(arena.presentationMode)
  local mode = (declaredMode == "MAP" or declaredMode == "ARENA"
      or declaredMode == "DISCS") and declaredMode
    or arena.arenaStyle and "ARENA"
    or arena.discs and "DISCS" or "MAP"
  local style = arena.arenaStyle or arena.diskStyle
  local styleID = stringId(type(style) == "table"
    and (style.mapId or style.stageID or style.id) or nil)
  return {
    mapID=mapID,
    stageID=styleID or mapID,
    mode=mode,
    modeStageID=mapID and (mode .. ":" .. mapID) or nil,
  }
end

local function contextMatch(profile, context)
  if type(profile) ~= "table" or type(context) ~= "table" then return nil end
  local mapID = stringId(context.mapID)
  if not mapID or profile.mapID ~= mapID then return nil end
  if activePreset and profile.presetID ~= activePreset then return nil end
  local stageID = stringId(context.stageID)
  local modeStageID = stringId(context.modeStageID)
  if stageID and profile.stageID == stageID then return 3 end
  if modeStageID and profile.stageID == modeStageID then return 2 end
  if profile.stageID == mapID then return 1 end
  return nil
end

function BattleLayout.profileFor(context)
  local best, bestScore, bestKey
  for key, profile in pairs(importedProfiles) do
    local score = contextMatch(profile, context)
    if score and (not best or score > bestScore
        or score == bestScore
           and (tonumber(profile.profileVersion) or 0)
             > (tonumber(best.profileVersion) or 0)
        or score == bestScore
           and (tonumber(profile.profileVersion) or 0)
             == (tonumber(best.profileVersion) or 0)
           and key < bestKey) then
      best, bestScore, bestKey = profile, score, key
    end
  end
  return best, bestKey
end

function BattleLayout.importProfile(input, options)
  local importer = profileImporter()
  if not importer or type(importer.import) ~= "function" then
    return nil, "battle layout profile importer unavailable"
  end
  local profile, err = importer.import(input, options or {})
  if not profile then
    return nil, type(importer.errorMessage) == "function"
      and importer.errorMessage(err) or tostring(err or "invalid profile")
  end
  local key = importer.identityKey(profile)
  if not key then return nil, "profile identity missing" end
  local previous = importedProfiles[key]
  if previous and (tonumber(previous.profileVersion) or 0)
      > (tonumber(profile.profileVersion) or 0) then
    return previous, key
  end
  importedProfiles[key] = profile
  return profile, key
end

function BattleLayout.removeProfile(key)
  if type(key) ~= "string" or importedProfiles[key] == nil then return false end
  importedProfiles[key] = nil
  return true
end

function BattleLayout.clearProfiles()
  importedProfiles = {}
  return true
end

function BattleLayout.setActivePreset(presetID)
  if presetID ~= nil and (type(presetID) ~= "string" or presetID == "") then
    return false
  end
  activePreset = presetID
  return true
end

function BattleLayout.profileStatus()
  local keys = {}
  for key in pairs(importedProfiles) do keys[#keys + 1] = key end
  table.sort(keys)
  return {apiVersion=BattleLayout.API_VERSION,
          contract=BattleLayout.PROFILE_CONTRACT,
          count=#keys, keys=keys, activePreset=activePreset}
end

local function hudProfileItem(profile, id)
  local role = HUD_PROFILE_ROLE[id]
  if not role then return nil end
  for _, item in ipairs(profile and profile.layout
                        and profile.layout.hud or {}) do
    if item.role == role then return item end
  end
end

local function mergeProfile(base, item)
  if type(item) ~= "table" then return base end
  local out = {}
  for key, value in pairs(base) do out[key] = value end
  for _, key in ipairs({
    "normalizedX", "normalizedY", "normalizedWidth", "normalizedHeight",
    "visible", "flipX", "flipY", "baseline", "footAnchor", "opacity",
    "layer", "animation", "respectsSafeArea",
  }) do
    if item[key] ~= nil then out[key] = item[key] end
  end
  local profileScale = tonumber(item.scale) or 1
  if not (profileScale == profileScale and profileScale > 0
          and profileScale < math.huge) then profileScale = 1 end
  out.scale = profileScale * (tonumber(base.scale) or 1)
  out.profileObject = item
  return out
end

function BattleLayout.adjustment(id, context)
  local base = savedAdjustment(id)
  if type(context) ~= "table" or not HUD_PROFILE_ROLE[id] then return base end
  local profile = BattleLayout.profileFor(context)
  return mergeProfile(base, hudProfileItem(profile, id))
end

-- Texture classification is receipt based. Optional packages do not need to
-- be present and no package id or private setting is consulted. In
-- particular, image dimensions are not a body/view capability: 64x64 may be
-- either a reviewed full-body trainer back or a cropped legacy battle card.
function BattleLayout.actorTarget(side, texture, metrics)
  if type(texture) ~= "table" then
    return side == "enemy" and "enemy_pokemon" or "player_front"
  end
  if texture.vascLayoutTarget and TARGET_BY_ID[texture.vascLayoutTarget] then
    return texture.vascLayoutTarget
  end
  local trainer = texture.trainer == true or texture.trainerArt == true
    or texture.ascendantHighResTrainer == true
  if trainer then
    if side == "enemy" then return "enemy_trainer" end
    local view = texture.vascSpriteView or texture.ascendantSpriteView
      or texture.battleSpriteView
    return (view == "back" or view == "full_back"
            or texture.trainer == true) and "player_trainer_back"
      or "player_trainer_front"
  end
  if texture.kantoAscendantMegaSupersampled == true
      or texture.kantoAscendantGorochuSupersampled == true
      or texture.vascMegaPresentation == true then
    return "mega"
  end
  if side == "enemy" then return "enemy_pokemon" end
  if texture.vascRetroBack == true then return "player_retro_back" end
  local view = texture.vascSpriteView or texture.ascendantSpriteView
    or texture.battleSpriteView
  if texture.vascBackSelected == true or view == "back"
      or view == "full_back" then
    return "player_back"
  end
  return "player_front"
end

local function actorProfileRole(side, texture, id)
  if id == "player_trainer_front" or id == "player_trainer_back" then
    return "player-trainer"
  end
  if id == "enemy_trainer" then return "enemy-trainer" end
  if id == "mega" then
    return side == "enemy" and "enemy-pokemon-mega"
      or "player-pokemon-mega"
  end
  local view = type(texture) == "table" and
    (texture.vascSpriteView or texture.ascendantSpriteView
     or texture.battleSpriteView) or nil
  local back = view == "back" or view == "full_back"
    or type(texture) == "table" and texture.vascFullBodyBack == true
  if side == "enemy" then
    return back and "enemy-pokemon-back" or "enemy-pokemon-front"
  end
  if id == "player_back" then return "player-pokemon-back" end
  return "player-pokemon-front"
end

local function actorProfileItem(profile, role, texture)
  local requestedInstance = type(texture) == "table"
    and texture.vascLayoutInstanceID or nil
  local fallback
  for _, item in ipairs(profile and profile.layout
                        and profile.layout.objects or {}) do
    if item.role == role then
      if requestedInstance and item.instanceID == requestedInstance then
        return item
      end
      if item.instanceID == nil then fallback = item end
    end
  end
  return fallback
end

function BattleLayout.actorAdjustment(side, texture, metrics, context)
  local id = BattleLayout.actorTarget(side, texture, metrics)
  local base = savedAdjustment(id)
  local profile = BattleLayout.profileFor(context)
  local role = actorProfileRole(side, texture, id)
  return mergeProfile(base, actorProfileItem(profile, role, texture)), id
end

function BattleLayout.isHudTarget(id)
  local target = TARGET_BY_ID[id]
  return target and target.hud == true or false
end

function BattleLayout.backdropFor(context)
  local profile = BattleLayout.profileFor(context)
  return profile and profile.layout and profile.layout.backdrop or nil
end

function BattleLayout.public()
  return {
    apiVersion=BattleLayout.API_VERSION,
    contract=BattleLayout.PROFILE_CONTRACT,
    importProfile=BattleLayout.importProfile,
    removeProfile=BattleLayout.removeProfile,
    clearProfiles=BattleLayout.clearProfiles,
    setActivePreset=BattleLayout.setActivePreset,
    status=BattleLayout.profileStatus,
  }
end

return BattleLayout
