-- One public owner for VASC's sprite and music source.  VASC never discovers
-- KASC (or a retro pack) by mod id or private tables: optional companions must
-- register an explicit API-v1 receipt.  CUSTOM deliberately reuses the loose
-- user folders materialised by the cross-platform Content Selector.

local V = ...
local LocalContent = {}

LocalContent.API_VERSION = 2
LocalContent.CONTRACT = "vasc-active-preset/v2"
LocalContent.ROOT = "user/content-selector/preset-runtime/v1"
LocalContent.KEY = "contentProfile.requested"
LocalContent.PROFILES = { "KASC", "VASC_DEFAULT", "RETRO", "CUSTOM" }

local LABELS = {
  KASC="KASC", VASC_DEFAULT="VASC DEFAULT", RETRO="RETRO", CUSTOM="CUSTOM",
}
local VALID_PROFILE = {}
for _, id in ipairs(LocalContent.PROFILES) do VALID_PROFILE[id] = true end

local LocalSprites = V.require("LocalSprites")
local LocalMusic = V.require("LocalMusic")
local SpritePacks = V.require("SpritePacks")
local PresetRuntime = V.require("PresetRuntime")
local okBattleMusic, BattleMusic = pcall(V.require, "BattleMusic")
if not okBattleMusic then BattleMusic = nil end

local requested = "VASC_DEFAULT"
local sources = {}
local modRef
local legacyPack
local partial = { KASC=false, RETRO=false }
local providerBattleSong

local function validId(value)
  return type(value) == "string" and value ~= ""
         and value:match("^[A-Za-z0-9_.%-]+$") ~= nil
end

local function copyScalars(value, allowed)
  local out = {}
  if type(value) ~= "table" then return out end
  for key in pairs(allowed) do
    local item = value[key]
    local kind = type(item)
    if kind == "string" or kind == "number" or kind == "boolean" then
      out[key] = item
    end
  end
  return out
end

local SPRITE_CONTEXT = {
  pokemon={kind=true, species=true, side=true, formId=true, shiny=true,
           letter=true, trueColor=true},
  icon={kind=true, species=true, formId=true, letter=true, name=true,
        shiny=true},
  player={kind=true, side=true, demo=true},
  trainer={kind=true, trainerId=true, partyIndex=true},
  overworld={kind=true, spriteId=true, player=true, playerState=true,
             playerCharacter=true},
}
local MUSIC_CONTEXT = {
  reason=true, category=true, mapId=true, mapSong=true, battleKind=true,
  kind=true, trainerId=true, onBike=true, surfing=true, selected=true,
}

local function safePath(path)
  if type(path) ~= "string" or path == "" or #path > 1024 then return false end
  if path:find("[%z\1-\31\127]") or path:find("\\", 1, true)
     or path:sub(1, 1) == "/" or path:match("^%a:")
     or path:sub(1, 2) == "//" or path:find("//", 1, true)
     or path:sub(-1) == "/" then return false end
  for part in path:gmatch("[^/]+") do
    if part == "." or part == ".." or part == "" then return false end
  end
  return true
end

local function imagePath(path)
  if not safePath(path) then return false end
  if love and love.image and type(love.image.newImageData) == "function" then
    local ok, image = pcall(love.image.newImageData, path)
    if not ok or not image then return false end
    local okDim, width, height = pcall(image.getDimensions, image)
    if type(image.release) == "function" then pcall(image.release, image) end
    return okDim and width >= 1 and height >= 1
           and width <= 4096 and height <= 4096
  end
  return true
end

local function clone(value)
  local out = {}
  for key, item in pairs(type(value) == "table" and value or {}) do
    out[key] = item
  end
  return out
end

local function validOverworld(current, result)
  if type(current) ~= "table" then return current end
  if type(result) == "string" then
    if not imagePath(result) then return current end
    local out = clone(current)
    out.image = result
    return out
  end
  if type(result) ~= "table" then return current end
  for key in pairs(result) do
    if key ~= "image" and key ~= "frames" and key ~= "walker"
       and key ~= "trueColor" and key ~= "paletteSource" then
      return current
    end
  end
  local out = clone(current)
  for _, key in ipairs({"image", "frames", "walker", "trueColor", "paletteSource"}) do
    if result[key] ~= nil then out[key] = result[key] end
  end
  if not imagePath(out.image) or type(out.frames) ~= "number"
     or out.frames ~= math.floor(out.frames)
     or out.frames < 1 or out.frames > 256
     or (out.walker ~= nil and type(out.walker) ~= "boolean")
     or (out.trueColor ~= nil and type(out.trueColor) ~= "boolean")
     or (out.paletteSource ~= nil and type(out.paletteSource) ~= "string") then
    return current
  end
  return out
end

local function gameBuckets(game)
  local modId = (V.mod and V.mod.id) or "VOXEL_ASCENDANT"
  local options = game and game.save and game.save.options
  if options then
    options.modOptions = options.modOptions or {}
    options.modOptions[modId] = options.modOptions[modId] or {}
  end
  local loader = game and game.mods
  if loader then
    loader.modOptions = loader.modOptions or {}
    loader.modOptions[modId] = loader.modOptions[modId] or {}
  end
  return options and options.modOptions[modId],
         loader and loader.modOptions[modId]
end

local function write(game)
  if game and type(game.writeOptions) == "function" then
    pcall(game.writeOptions, game)
  elseif game and type(game.persistOptions) == "function" then
    pcall(game.persistOptions, game)
  end
end

local function profileClaims(profile)
  local ids = {}
  for id, source in pairs(sources) do
    if source.profiles[profile] then ids[#ids + 1] = id end
  end
  table.sort(ids)
  return ids
end

local function providerFor(profile)
  local ids = profileClaims(profile)
  if #ids == 0 then return nil, profile:lower() .. "-provider-missing", ids end
  if #ids > 1 then return nil, "provider-collision", ids end
  local source = sources[ids[1]]
  local provider = source and source.profiles[profile]
  if provider and type(provider.ready) == "function" then
    local ok, ready, reason = pcall(provider.ready)
    if not ok or ready ~= true then
      return nil, type(reason) == "string" and reason ~= "" and reason
                  or profile:lower() .. "-provider-not-ready", ids
    end
  end
  return provider, nil, ids
end

local function currentState()
  local effective, reason = requested, nil
  local provider, ids
  if requested == "KASC" or requested == "RETRO" then
    provider, reason, ids = providerFor(requested)
    if not provider then effective = "VASC_DEFAULT" end
  elseif requested == "CUSTOM" then
    local preset = PresetRuntime.status()
    if preset.valid then
      effective = "CUSTOM"
      reason = preset.restartRequired and "restart-required" or nil
    elseif preset.reason == "pointer-missing" or preset.reason == "reader-unavailable" then
      -- RC8 and loose one-file installs remain a supported migration path.
      effective, reason = "CUSTOM", "custom-materialized-folders"
    elseif preset.baseProfile == "retro" then
      provider, reason, ids = providerFor("RETRO")
      effective = provider and "RETRO" or "VASC_DEFAULT"
      reason = "custom-generation-invalid:" .. tostring(preset.reason)
    else
      effective, reason = "VASC_DEFAULT",
        "custom-generation-invalid:" .. tostring(preset.reason)
    end
  else
    effective = "VASC_DEFAULT"
  end
  return effective, reason, provider, ids or {}
end

local function setLegacyState(game, profile)
  local _, packId = SpritePacks.active()
  if profile == "CUSTOM" then
    if legacyPack then SpritePacks.select(legacyPack, game) end
    LocalSprites.setEnabled(game, true)
    LocalMusic.setEnabled(game, true)
  else
    if packId and packId ~= "base" then legacyPack = packId end
    SpritePacks.select("base", game)
    LocalSprites.setEnabled(game, false)
    LocalMusic.setEnabled(game, false)
    if BattleMusic and BattleMusic.setting
       and type(BattleMusic.setting.setValue) == "function" then
      BattleMusic.setting:setValue("original", game)
    end
  end
end

function LocalContent.select(id, game)
  id = tostring(id or ""):upper():gsub("[ %-]+", "_")
  if not VALID_PROFILE[id] then return false, "unknown content profile" end
  requested = id
  local save, loader = gameBuckets(game)
  if save then save[LocalContent.KEY] = requested end
  if loader then loader[LocalContent.KEY] = requested end
  setLegacyState(game, requested)
  providerBattleSong = nil
  write(game)
  return true
end

function LocalContent.restore(game)
  local save, loader = gameBuckets(game)
  local stored = save and save[LocalContent.KEY]
                 or loader and loader[LocalContent.KEY]
  if VALID_PROFILE[stored] then
    requested = stored
  else
    local _, packId = SpritePacks.active()
    requested = (LocalSprites.enabled() or LocalMusic.enabled()
                 or (packId and packId ~= "base"))
                and "CUSTOM" or "VASC_DEFAULT"
  end
  setLegacyState(game, requested)
  providerBattleSong = nil
  return LocalContent.status()
end

local function validProfileProvider(value)
  return type(value) == "table" and value.sprites == true and value.music == true
         and type(value.resolveSprite) == "function"
         and type(value.resolveMusic) == "function"
         and (value.ready == nil or type(value.ready) == "function")
end

function LocalContent.registerSource(receipt)
  if type(receipt) ~= "table" or receipt.apiVersion ~= 1
     or not validId(receipt.id) or sources[receipt.id]
     or type(receipt.label) ~= "string" or receipt.label == ""
     or type(receipt.version) ~= "string" or receipt.version == ""
     or type(receipt.profiles) ~= "table" then
    return nil, "invalid or duplicate content-source receipt"
  end
  local profiles, count = {}, 0
  for profile, provider in pairs(receipt.profiles) do
    if (profile ~= "KASC" and profile ~= "RETRO")
       or not validProfileProvider(provider) then
      return nil, "content source may expose only complete KASC/RETRO profiles"
    end
    profiles[profile], count = provider, count + 1
  end
  if count == 0 then return nil, "content source has no profile" end
  local held = {
    id=receipt.id, label=receipt.label, version=receipt.version,
    profiles=profiles, identity=receipt,
  }
  sources[receipt.id] = held
  local function unregister()
    if sources[receipt.id] ~= held then return false end
    sources[receipt.id] = nil
    providerBattleSong = nil
    return true
  end
  return unregister
end

function LocalContent.unregisterSource(id, identity)
  local source = sources[id]
  if not source or source.identity ~= identity then return false end
  sources[id] = nil
  providerBattleSong = nil
  return true
end

function LocalContent.resolveSprite(kind, current, ctx)
  if not SPRITE_CONTEXT[kind] then return current end
  local effective, _, provider = currentState()
  if effective == "CUSTOM" then
    local preset = PresetRuntime.status()
    if preset.valid then
      local base = current
      if preset.baseProfile == "retro" then
        local retro = providerFor("RETRO")
        if retro then
          local safeCtx = copyScalars(ctx, SPRITE_CONTEXT[kind])
          local ok, result = pcall(retro.resolveSprite, kind, current, safeCtx)
          if ok and result ~= nil and result ~= false then
            if kind == "overworld" then base = validOverworld(current, result)
            elseif imagePath(result) then base = result end
          end
        end
      end
      return PresetRuntime.resolveSprite(kind, base, ctx)
    end
    local chosen = SpritePacks.resolve(kind, current, ctx)
    return LocalSprites.resolve(kind, chosen, ctx)
  end
  if not provider then return current end
  local safeCtx = copyScalars(ctx, SPRITE_CONTEXT[kind])
  local ok, result = pcall(provider.resolveSprite, kind, current, safeCtx)
  if not ok or result == nil or result == false then
    partial[effective] = true
    return current
  end
  if kind == "overworld" then
    local chosen = validOverworld(current, result)
    if chosen == current then partial[effective] = true end
    return chosen
  end
  if not imagePath(result) then partial[effective] = true return current end
  return result
end

local function songAvailable(id)
  if type(id) ~= "string" or id == "" then return false end
  local registry = modRef and modRef.content and modRef.content.music
  if not registry or type(registry.get) ~= "function" then return false end
  local ok, def = pcall(registry.get, registry, id)
  return ok and type(def) == "table"
         and (def.file ~= nil or def.chip ~= nil or def.program ~= nil
              or (def.address ~= nil and def.bank ~= nil))
end

function LocalContent.resolveMusic(current, ctx)
  if type(ctx) == "table" and ctx.selected == true then return current end
  local effective, _, provider = currentState()
  if effective == "CUSTOM" then
    local preset = PresetRuntime.status()
    if preset.valid then
      local base = current
      if preset.baseProfile == "retro" then
        local retro = providerFor("RETRO")
        if retro then
          local ok, result = pcall(retro.resolveMusic, current,
                                   copyScalars(ctx, MUSIC_CONTEXT))
          if ok and songAvailable(result) then base = result end
        end
      end
      return PresetRuntime.resolveMusic(base, ctx, LocalMusic.categoryFor(ctx))
    end
    return LocalMusic.resolve(current, ctx)
  end
  if not provider or type(current) ~= "string" or current == "" then return current end
  if type(ctx) == "table" and ctx.reason == "battle" and providerBattleSong then
    return providerBattleSong
  end
  local ok, result = pcall(provider.resolveMusic, current,
                           copyScalars(ctx, MUSIC_CONTEXT))
  if not ok or not songAvailable(result) then
    partial[effective] = true
    return current
  end
  if type(ctx) == "table" and ctx.reason == "battle" then
    providerBattleSong = result
  end
  return result
end

function LocalContent.finish()
  providerBattleSong = nil
  PresetRuntime.finish()
  if LocalMusic and type(LocalMusic.finish) == "function" then LocalMusic.finish() end
end

function LocalContent.rescan(game)
  PresetRuntime.rescan(modRef)
  LocalSprites.rescan()
  if LocalMusic and type(LocalMusic.scan) == "function" then LocalMusic.scan(modRef) end
  if requested == "CUSTOM" then setLegacyState(game, requested) end
  return LocalContent.status()
end

local function available(profile)
  if profile == "VASC_DEFAULT" or profile == "CUSTOM" then return true end
  return providerFor(profile) ~= nil
end

local function copyStatus()
  local effective, reason, _, ids = currentState()
  local out = {
    apiVersion=LocalContent.API_VERSION, contract=LocalContent.CONTRACT,
    requested=requested, effective=effective, reason=reason,
    baseProfile=PresetRuntime.status().baseProfile,
    presetReader=PresetRuntime.status().restartRequired and "restart-required"
      or PresetRuntime.status().valid and "verified" or "fail-closed",
    restartRequired=PresetRuntime.status().restartRequired == true,
    restartReason=PresetRuntime.status().restartReason,
    packageReceiptVerified=PresetRuntime.status().packageReceiptVerified == true,
    preset=PresetRuntime.status().preset,
    scope=PresetRuntime.status().scope,
    generation=PresetRuntime.status().generation,
    game=PresetRuntime.status().game,
    partial=partial[effective] == true,
    providers=ids,
    available={},
  }
  for _, profile in ipairs(LocalContent.PROFILES) do
    out.available[profile] = available(profile)
  end
  return out
end

function LocalContent.status() return copyStatus() end

function LocalContent.row()
  return {
    id=((V.mod and V.mod.id) or "VOXEL_ASCENDANT") .. ":contentProfile",
    label="CONTENT SOURCE",
    value=function() return LABELS[requested] end,
    step=function(game, direction)
      local at = 1
      for i, profile in ipairs(LocalContent.PROFILES) do
        if profile == requested then at = i break end
      end
      at = ((at - 1 + (tonumber(direction) or 1))
            % #LocalContent.PROFILES) + 1
      return LocalContent.select(LocalContent.PROFILES[at], game)
    end,
  }
end

local function installStatusScreen(mod)
  local screens = mod and mod.content and mod.content.screens
  if not screens or type(screens.register) ~= "function" then return false end
  screens:register("VascContentStatus", {
    new=function(game)
      local status = copyStatus()
      local preset = status.preset
      local presetId = preset and tostring(preset.id or "CUSTOM") or "NONE"
      local presetHash = preset and tostring(preset.digest or ""):sub(1, 8):upper()
        or "--------"
      local fallback = status.reason and tostring(status.reason):upper():sub(1, 18)
        or "NONE"
      local items = {
        {label="REQUESTED", right=LABELS[status.requested]},
        {label="EFFECTIVE", right=LABELS[status.effective]},
        {label="ACTIVE SCOPE", right=string.upper(tostring(status.scope or "DEFAULT"))},
        {label="PRESET", right=presetId:upper():sub(1, 18)},
        {label="PRESET BASE", right=string.upper(tostring(status.baseProfile or "VASC"))},
        {label="MANIFEST HASH", right=presetHash},
        {label="PRESET READER", right=status.presetReader == "verified" and "VERIFIED"
          or status.presetReader == "restart-required" and "RESTART" or "FALLBACK"},
        {label="FALLBACK", right=fallback},
        {label="KASC PROVIDER", right=status.available.KASC and "READY" or "MISSING"},
        {label="RETRO PROVIDER", right=status.available.RETRO and "READY" or "MISSING"},
        {label="RESTORE VASC DEFAULT", action="default"},
        {label="USE CUSTOM", action="custom"},
        {label="RESCAN CONTENT", action="rescan"},
        {label="SPRITE GUIDE", screen="VascUserSpritesHelp"},
        {label="MUSIC GUIDE", screen="VascUserMusicHelp"},
      }
      local menu = mod.ui.ListMenu.new(game, "PRESET & SCOPE", items, {
        onChoose=function(item, active)
          if item.action == "rescan" then
            LocalContent.rescan(game)
            if active and type(active.close) == "function" then active:close() end
          elseif item.action == "default" then
            LocalContent.select("VASC_DEFAULT", game)
            if active and type(active.close) == "function" then active:close() end
          elseif item.action == "custom" then
            LocalContent.select("CUSTOM", game)
            if active and type(active.close) == "function" then active:close() end
          elseif item.screen then
            mod.ui.push(game, item.screen)
          end
        end,
      })
      local ok, hub = pcall(V.require, "VascMenu")
      return ok and hub and type(hub.decorateActive) == "function"
             and hub.decorateActive(mod, menu) or menu
    end,
  })
  return true
end

function LocalContent.install(mod)
  modRef = mod or modRef
  PresetRuntime.install(modRef)
  return installStatusScreen(modRef)
end

function LocalContent.public()
  return {
    apiVersion=LocalContent.API_VERSION, contract=LocalContent.CONTRACT,
    profiles={"KASC", "VASC_DEFAULT", "RETRO", "CUSTOM"},
    registerSource=LocalContent.registerSource,
    unregisterSource=LocalContent.unregisterSource,
    resolveSprite=LocalContent.resolveSprite,
    resolveMusic=LocalContent.resolveMusic,
    select=LocalContent.select, restore=LocalContent.restore,
    rescan=LocalContent.rescan,
    status=LocalContent.status,
    requirements={autonomous=true, publicReceiptsOnly=true,
      privateKascDiscovery=false, presetReaderFailClosed=true,
      generationGameScopes=true, boundedReads=true, sha256=true},
  }
end

return LocalContent
