-- Stable Voxel Ascendant public API for the integrated Gen-2 runtime.
local C = ...
local BaseV = assert(C and C.BaseV, "Voxel Ascendant Gen2: renderer namespace missing")
local VERSION = tostring(C.version or "0.0.0")
local UPSTREAM_VERSION = tostring(C.upstreamVersion or "unknown")

local function resolve(name)
  if type(BaseV.require) ~= "function" then return nil end
  local ok, value = pcall(BaseV.require, name)
  if ok and type(value) == "table" then return value end
  return nil
end

local PublicFacade = resolve("PublicFacade")
if not PublicFacade then
  local source, err = C.mod:read("lib/PublicFacade.lua")
  assert(source, "Voxel Ascendant Gen2: PublicFacade missing: " .. tostring(err))
  local chunk, compileErr = (loadstring or load)(source,
    "@" .. C.mod.path .. "/lib/PublicFacade.lua")
  assert(chunk, "Voxel Ascendant Gen2: PublicFacade did not compile: " .. tostring(compileErr))
  PublicFacade = chunk()
end

local Gen2PublicExports = {}

local function readOnlyModule(fields, label)
  local allowed = {}
  for name, value in pairs(fields or {}) do
    if type(name) == "string" and value ~= nil then allowed[name] = value end
  end
  return setmetatable({}, {
    __index=function(_, key) return allowed[key] end,
    __newindex=function()
      error("Voxel Ascendant Gen 2: "
        .. tostring(label or "public module") .. " is read-only", 2)
    end,
    __metatable="Voxel Ascendant Gen 2 read-only module",
  })
end

local function detachedSnapshot(value, label, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] ~= nil then return seen[value] end
  local snapshot = {}
  seen[value] = snapshot
  for key, item in pairs(value) do
    if type(key) == "string" or type(key) == "number" then
      snapshot[key] = detachedSnapshot(item, label, seen)
    end
  end
  return setmetatable(snapshot, {
    __newindex=function()
      error("Voxel Ascendant Gen 2: "
        .. tostring(label or "diagnostic receipt")
        .. " cannot be extended", 2)
    end,
    __metatable="Voxel Ascendant Gen 2 detached diagnostic receipt",
  })
end

local function detachedDiagnosticList(values, label)
  if type(values) ~= "table" then return nil end
  local out, seen = {}, {}
  for index, value in ipairs(values) do
    local card = type(value) == "table" and {
      texturePresent=value.tex ~= nil,
      modelPresent=value.model ~= nil,
      noDayTint=value.noDayTint,
    } or value
    out[index] = detachedSnapshot(card, label, seen)
  end
  return setmetatable(out, {
    __newindex=function()
      error("Voxel Ascendant Gen 2: "
        .. tostring(label or "diagnostic list") .. " is read-only", 2)
    end,
    __metatable="Voxel Ascendant Gen 2 detached diagnostic list",
  })
end

local function battleDiagnostics(privateBattle)
  if type(privateBattle) ~= "table" then return nil end
  local planReceipts = setmetatable({}, { __mode="k" })

  local function presentationPlan(expectedScreen)
    if type(privateBattle.presentationPlan) ~= "function" then return nil end
    local value = privateBattle.presentationPlan(expectedScreen)
    if type(value) ~= "table" then return value end
    local receipt = planReceipts[value]
    if receipt == nil then
      receipt = detachedSnapshot(value, "battle presentation plan")
      planReceipts[value] = receipt
    else
      for key in pairs(receipt) do rawset(receipt, key, nil) end
      local refreshed = detachedSnapshot(value, "battle presentation plan")
      for key, item in pairs(refreshed) do rawset(receipt, key, item) end
    end
    return receipt
  end

  local function shot()
    if type(privateBattle.shot) ~= "function" then return nil end
    local value = privateBattle.shot()
    if type(value) ~= "table" then return value end
    local diagnostic = {}
    for _, key in ipairs({
      "ready", "liveWorld", "goldStaged", "presentationMode",
      "nativeHud", "pendingActors", "pw", "ph", "lx", "ly", "scale",
      "player", "enemy", "playerSpan", "enemySpan", "tint",
    }) do
      diagnostic[key] = value[key]
    end
    diagnostic.canvas = value.canvas ~= nil
    return detachedSnapshot(diagnostic, "battle shot")
  end

  local function worldCards()
    if type(privateBattle.worldCards) ~= "function" then return nil end
    local cards = privateBattle.worldCards()
    return detachedDiagnosticList(cards, "battle world-card diagnostics")
  end

  return readOnlyModule({
    presentationPlan=type(privateBattle.presentationPlan) == "function"
      and presentationPlan or nil,
    shot=type(privateBattle.shot) == "function" and shot or nil,
    worldCards=type(privateBattle.worldCards) == "function"
      and worldCards or nil,
  }, "OverworldBattle diagnostics")
end

function Gen2PublicExports.apply(exports)
  exports = exports or {}

  local privateWeatherTweak = resolve("WeatherTweak")
  local publicWeatherTweak = type(privateWeatherTweak) == "table"
    and readOnlyModule({
      status=privateWeatherTweak.status,
      eventAt=privateWeatherTweak.eventAt,
    }, "WeatherTweak diagnostics") or nil

  -- The bridge installs Fishing before this facade is published.  Advertise
  -- the capability only when that exact public provider survived require and
  -- install; a fail-open native runtime must not claim an unavailable VASC
  -- presentation feature.
  local fishingExport = type(exports.speciesCinematics) == "table"
    and exports.speciesCinematics.fishing or nil
  local fishingInstalled = type(fishingExport) == "table"
    and fishingExport.active == true
    and type(fishingExport.status) == "function"
  local speciesCinematicCapabilities = nil
  if fishingInstalled then
    speciesCinematicCapabilities = {
      apiVersion = 1,
      generation = 2,
      fishing = tostring(fishingExport.version or "0.1.0"),
      nativeFallback = fishingExport.nativeFallback ~= false,
    }
  end

  local publicModules = {
    AntiAlias = resolve("AntiAlias"),
    BattleCam = resolve("BattleCam"),
    OverworldBattle = battleDiagnostics(resolve("OverworldBattle")),
    ShadowMap = resolve("ShadowMap"),
    Shadows = resolve("Shadows"),
    Sky = resolve("Sky"),
    SkyEvents = resolve("SkyEvents"),
    HorizonWall = resolve("HorizonWall"),
    PanoramaBackdrop = resolve("PanoramaBackdrop"),
    WallDecals = resolve("WallDecals"),
    DayNight = resolve("DayNight"),
    LocalMusic = resolve("LocalMusic"),
    LocalSprites = resolve("LocalSprites"),
    LocalContent = resolve("LocalContent"),
    SpritePacks = resolve("SpritePacks"),
    Voxel3D = resolve("Voxel3D"),
    VoxelGrid = resolve("VoxelGrid"),
    VoxelScene = resolve("VoxelScene"),
    VoxelState = resolve("VoxelState"),
    HdResidencyPlan = resolve("HdResidencyPlan"),
    Water = resolve("Water"),
    Weather = resolve("Weather"),
    WeatherTweak = publicWeatherTweak,
    WorldCurve = resolve("WorldCurve"),
    AscendantHudTheme = C.HudTheme or resolve("AscendantHudTheme"),
  }

  exports.version = VERSION
  exports.apiVersion = 1
  exports.renderer = {
    id = (C.mod and C.mod.id) or "VOXEL_ASCENDANT",
    version = VERSION,
    pipeline = "voxel",
    generation = 2,
    cameraProfile = "diorama-first-third",
  }
  exports.capabilities = {
    voxelWorld = true,
    openWorld = true,
    generation = 2,
    cameraModes = {
      "FULL", "ANGLE_15", "ANGLE_35", "ANGLE_50", "ANGLE_75",
      "FIRST_PERSON", "THIRD_PERSON",
    },
    battleCards = { "MAP", "ARENA", "DISCS", "GAME_DEFAULT" },
    -- The supplied A21 runtime owns all four presentation modes through one
    -- non-overlapping Gen-2 Card. Do not resurrect the removed pre-A21
    -- provider graph here: consumers need a truthful owner/terminal receipt,
    -- while the complete boundary is exported as `gen2SegmentCards` by the
    -- generation dispatcher.
    battleLifecycle = {
      apiVersion = 1,
      segmented = true,
      segmentOwner = "vasc.gen2.battle-presentation",
      providers = { "MAP", "ARENA", "DISCS", "GAME_DEFAULT" },
      terminalOwner = "a21-battle-state-pop",
      movePresentationOwner = "a21-battle-animation-compat",
    },
    battleWorldOption = "battle3dWorld",
    battleCameraOption = "battleSmartCamera",
    gridControls = { overworld = "grid", battle = "battleGrid" },
    renderControls = {
      "curve", "water", "aa", "renderScale", "shadowQuality",
    },
    stadium2Models = true,
    visibleWildPokemon = true,
    partyFollowers = true,
    customMenus = true,
    optionalAscendantHud = {
      enabled = true,
      option = "battleHudStyle",
      themeApiVersion = 1,
      editions = { "red", "blue", "yellow", "gold", "silver", "crystal" },
    },
    fieldPresentations = {
      surf = "speciesSurfPresentation",
      fieldKit = "fieldKitPresentation",
      fly = "speciesFlyPresentation",
      fishing = "fishingPresentation",
      nativeRules = true,
    },
    comfortOptions = {
      expBar = "qolExpBar",
      caughtIndicator = "qolCaughtIndicator",
      battleGender = "battleGender",
      statusValues = "statusValues",
      locationBanners = "qolLocationBanners",
      easyInteractions = "qolEasyInteractions",
      registeredItem = "qolRegisteredItem",
      catchBoxNotice = "qolCatchBoxNotice",
      fastBoxSwitch = "qolFastBoxSwitch",
      modernBallSkins = "qolModernBallSkins",
    },
    panorama = true,
    scenery = true,
    interiorCutaway = true,
    fullWeather = { "clear", "auto", "rain", "snow", "fog", "storm", "heat", "rainbow" },
    skyEvents = { "rainbow", "flyers", "legendary" },
    dayNight = true,
    localSpriteFolders = true,
    localMusicFolders = true,
    contentProfiles = {
      apiVersion=2, contract="vasc-active-preset/v2",
      profiles={"KASC", "VASC_DEFAULT", "RETRO", "CUSTOM"},
      autonomous=true, publicReceiptsOnly=true,
    },
    speciesCinematics = speciesCinematicCapabilities,
    wallDecals = true,
    diskCache = true,
    diskCacheOption = "voxelDiskCache",
    vr = false,
  }
  exports.upstreams = {
    gen2Sprites = { version = UPSTREAM_VERSION, repository = "randyadr/Gen2-3D-Sprites" },
    voxelAscendant = { apiVersion = 1, repository = "Roxas2712/voxel-ascendant" },
  }
  exports.Voxel3D = publicModules.Voxel3D
  local weather = publicModules.Weather
  exports.weather = {
    apiVersion = 1,
    mode = weather and weather.mode or nil,
    modeAt = weather and weather.modeAt or nil,
    skyState = weather and weather.skyState or nil,
    lightningAt = weather and weather.lightningAt or nil,
  }
  exports.shadows = {
    apiVersion = 1,
    qualityOption = "shadowQuality",
    enabled = publicModules.Shadows and publicModules.Shadows.enabled or nil,
  }
  exports.WallDecals = publicModules.WallDecals
  exports.ascendantHudTheme = publicModules.AscendantHudTheme
  exports.spritePacks = publicModules.SpritePacks
    and publicModules.SpritePacks.public and publicModules.SpritePacks.public() or nil
  exports.localContent = publicModules.LocalContent
    and publicModules.LocalContent.public and publicModules.LocalContent.public() or nil
  exports.localMusic = publicModules.LocalMusic and {
    root = publicModules.LocalMusic.ROOT,
    list = publicModules.LocalMusic.list,
    scan = publicModules.LocalMusic.scan,
  } or nil
  exports.localSprites = publicModules.LocalSprites and {
    apiVersion=publicModules.LocalSprites.API_VERSION,
    root = publicModules.LocalSprites.ROOT,
    rescan = publicModules.LocalSprites.rescan,
    inventory = publicModules.LocalSprites.inventory,
    enabled = publicModules.LocalSprites.enabled,
    status = publicModules.LocalSprites.status,
  } or nil
  -- A21 uses this module internally, but callers receive only the stable
  -- status function published by main.lua. Exposing the module would hand
  -- lifecycle mutation ownership across the segment boundary.
  exports.vascEnvironment = nil
  exports.lib = PublicFacade.new(publicModules)
  return exports
end

return Gen2PublicExports
