-- Voxel Ascendant for Johto (Generation 2)
--
-- Standalone Gen1Recomp Gold/Gen-2 graphics/gameplay mod. It embeds the Gen2 Dramatic Shapes
-- voxel renderer and the Wilds of Kanto roaming-Pokemon runtime, but contains no
-- Pokemon Stadium 2 ROM or ROM-derived model data. Models are built locally
-- from the player's own compatible Stadium 2 ROM.
local mod = ...
local MOD_ID = mod.id or "VOXEL_ASCENDANT"
local VERSION = mod._vascPackageVersion or mod.version
  or (mod.exports and mod.exports.packageVersion)
assert(type(VERSION) == "string" and VERSION ~= "",
  "VOXEL_ASCENDANT: package version was not supplied by the dispatcher")

local MobileDiagnostic = mod._vascMobileDiagnostic

-- This package has its own Gen2-only mod id. Keep a runtime generation guard
-- anyway so accidentally enabling it on Red/Blue/Yellow fails closed.
local function gameGeneration()
  local ok, GameVersion = pcall(require, "src.core.GameVersion")
  if ok and type(GameVersion) == "table" then
    if type(GameVersion.generation) == "function" then
      local okGen, generation = pcall(GameVersion.generation)
      if okGen and tonumber(generation) then return tonumber(generation) end
    end
    if type(GameVersion.isGen2) == "function" then
      local okGen2, yes = pcall(GameVersion.isGen2)
      if okGen2 and yes then return 2 end
    end
  end
  return nil
end

local function isGen2()
  return gameGeneration() == 2
end

local detectedGeneration = tonumber(mod._vascHostGeneration) or gameGeneration()
if detectedGeneration == 2 then
  mod.log:info("Gold/Silver/Crystal runtime: Pokemon Generation 2 detected; Stadium 2 importer targets National Dex 1-251")
else
  mod.log:warn("%s requires Pokemon Gold, Silver or Crystal. Active game reports Pokemon Generation %s; this Gen 2 runtime will stay inactive.", MOD_ID, tostring(detectedGeneration))
  mod.exports.version = VERSION
  mod.exports.targetGeneration = 2
  mod.exports.generation = detectedGeneration
  mod.exports.gen2Compatible = true
  mod.exports.stadium2Importer = true
  mod.exports.standaloneRenderer = true
  mod.exports.maxDex = 251
  mod.exports.active = false
  mod.exports.rendererInstalled = false
  mod.exports.rendererError = "Pokemon Gold/Silver/Crystal (Generation 2) must be the active game"
  return
end

-- Import the retired standalone VASC4J option bucket exactly once. The new
-- package id owns all future writes; the old bucket remains untouched so a
-- rollback to the standalone development mod is still possible.
local function migrateLegacyOptions(payload)
  local game = type(payload) == "table" and (payload.game or payload) or nil
  if type(game) ~= "table" then return false end
  -- These stores can temporarily disagree during startup.  Resolve them in a
  -- fixed order instead of letting the last table visited win: the loaded
  -- save is authoritative, followed by the live mod manager and finally its
  -- persisted loader cache.
  local buckets = {}
  local seenBuckets = {}
  local function addBucket(bucket)
    if type(bucket) == "table" and not seenBuckets[bucket] then
      seenBuckets[bucket] = true
      buckets[#buckets + 1] = bucket
    end
  end
  addBucket(game.save and game.save.options and game.save.options.modOptions)
  addBucket(game.mods and game.mods.modOptions)
  addBucket(game.mods and game.mods.loader and game.mods.loader.modOptions)
  local schema = type(mod._vascGen2Schema) == "table" and mod._vascGen2Schema or {}
  local hasLegacy, hadTarget = false, false
  for _, bucket in ipairs(buckets) do
    hasLegacy = hasLegacy or type(bucket.VASC4J) == "table"
    hadTarget = hadTarget or type(bucket[MOD_ID]) == "table"
    if type(bucket[MOD_ID]) == "table"
        and bucket[MOD_ID].__vascGen2Migration == 1 then
      return false
    end
  end
  if not hasLegacy then return false end

  local function modernValue(key)
    for _, bucket in ipairs(buckets) do
      local target = type(bucket[MOD_ID]) == "table" and bucket[MOD_ID] or nil
      if target and target[key] ~= nil then return target[key] end
    end
    return nil
  end

  local function legacyValue(key)
    for _, bucket in ipairs(buckets) do
      local legacy = type(bucket.VASC4J) == "table" and bucket.VASC4J or nil
      if legacy and legacy[key] ~= nil then return legacy[key] end
    end
    return nil
  end

  local imported = false
  local function importMissing(key, value)
    if value == nil or modernValue(key) ~= nil then return false end
    local wrote = false
    for _, bucket in ipairs(buckets) do
      bucket[MOD_ID] = type(bucket[MOD_ID]) == "table" and bucket[MOD_ID] or {}
      local target = bucket[MOD_ID]
      if target[key] == nil then
        target[key] = value
        wrote = true
      end
    end
    if wrote and mod.options and type(mod.options.set) == "function" then
      pcall(mod.options.set, mod.options, key, value)
    end
    return wrote
  end

  for _, spec in ipairs(schema) do
    local key = type(spec) == "table" and spec.key or nil
    if key and importMissing(key, legacyValue(key)) then imported = true end
  end

  -- Retired VASC4J builds predated DEVICE profiles. A genuinely new unified
  -- VASC bucket starts on AUTO unless the legacy source explicitly supplied a
  -- profile. Existing unified buckets -- even sparse ones -- stay untouched.
  if not hadTarget and modernValue("deviceProfile") == nil then
    local profile = legacyValue("deviceProfile")
    if profile == nil then profile = "auto" end
    if importMissing("deviceProfile", profile) then imported = true end
  end

  -- Record the one-shot decision in every active store. The marker is metadata
  -- only; no modern option value is rewritten to create it.
  for _, bucket in ipairs(buckets) do
    bucket[MOD_ID] = type(bucket[MOD_ID]) == "table" and bucket[MOD_ID] or {}
    bucket[MOD_ID].__vascGen2Migration = 1
  end
  if type(game.persistOptions) == "function" then
    pcall(game.persistOptions, game)
  elseif type(game.writeOptions) == "function" then
    pcall(game.writeOptions, game)
  end
  if imported then
    mod.log:info("Imported missing standalone VASC4J settings into %s", MOD_ID)
  else
    mod.log:info("Retired standalone VASC4J settings without replacing existing %s values", MOD_ID)
  end
  return true
end

if mod.events and type(mod.events.on) == "function" then
  mod.events:on("game.ready", migrateLegacyOptions)
end

-- A few development packages registered the Gen-2 options before the ORAS
-- defaults were final and therefore persisted GAME DEFAULT into otherwise
-- untouched saves.  Repair only those stale native values once.  The marker
-- is separate from the VASC4J import above so a player can deliberately choose
-- GAME DEFAULT again after this migration and keep that choice permanently.
local function migrateGen2UiParity(payload)
  local game = type(payload) == "table" and (payload.game or payload) or nil
  if type(game) ~= "table" then return false end
  local buckets, seen = {}, {}
  local function add(bucket)
    if type(bucket) == "table" and not seen[bucket] then
      seen[bucket] = true
      buckets[#buckets + 1] = bucket
    end
  end
  add(game.save and game.save.options and game.save.options.modOptions)
  add(game.mods and game.mods.modOptions)
  add(game.mods and game.mods.loader and game.mods.loader.modOptions)
  for _, all in ipairs(buckets) do
    local owner = type(all[MOD_ID]) == "table" and all[MOD_ID] or nil
    if owner and owner.__vascGen2UiParity == 1 then return false end
  end

  local replacements = {
    qol_ui_skin = { value="oras", stale={ standard=true, native=true,
      game_default=true, off=true } },
    qol_bag_skin = { value="oras_wide", stale={ external=true, standard=true,
      native=true, game_default=true, off=true } },
    pokedexStyle = { value="modern", stale={ game=true, standard=true,
      native=true, game_default=true, off=true } },
    pokemonUiPartyMenu = { value="oras", stale={ standard=true, native=true,
      game_default=true, off=true } },
    pokemonUiBattleParty = { value="oras", stale={ standard=true, native=true,
      game_default=true, off=true } },
    battleHudStyle = { value="oras", stale={ standard=true, native=true,
      game_default=true, off=true } },
  }
  local changed = false
  for key, spec in pairs(replacements) do
    local current
    for _, all in ipairs(buckets) do
      local owner = type(all[MOD_ID]) == "table" and all[MOD_ID] or nil
      if owner and owner[key] ~= nil then current = owner[key]; break end
    end
    if current ~= nil and spec.stale[tostring(current):lower()] then
      for _, all in ipairs(buckets) do
        all[MOD_ID] = type(all[MOD_ID]) == "table" and all[MOD_ID] or {}
        all[MOD_ID][key] = spec.value
      end
      if mod.options and type(mod.options.set) == "function" then
        pcall(mod.options.set, mod.options, key, spec.value)
      end
      changed = true
    end
  end
  for _, all in ipairs(buckets) do
    all[MOD_ID] = type(all[MOD_ID]) == "table" and all[MOD_ID] or {}
    all[MOD_ID].__vascGen2UiParity = 1
  end
  if type(game.persistOptions) == "function" then
    pcall(game.persistOptions, game)
  elseif type(game.writeOptions) == "function" then
    pcall(game.writeOptions, game)
  end
  if changed then
    mod.log:info("Recovered the reviewed Gen-2 ORAS menu defaults from stale development values")
  end
  return changed
end

if mod.events and type(mod.events.on) == "function" then
  mod.events:on("game.ready", migrateGen2UiParity)
end

-- v0.3.x exposed `customUI=true`. Its global class wrappers consult that
-- value dynamically, so forcing the retired key false also makes an upgraded
-- hot-reload session fall through to the native methods captured by the old
-- wrappers. A full process restart remains the release/QA requirement because
-- old compose/input closures cannot all be unwound safely.
local function retireLegacyUiSwitch(payload)
  local game = type(payload) == "table" and (payload.game or payload) or nil
  if mod.options and type(mod.options.set) == "function" then
    pcall(mod.options.set, mod.options, "customUI", false)
  end
  local function retireBucket(bucket)
    if type(bucket) == "table" then
      bucket[MOD_ID] = bucket[MOD_ID] or {}
      bucket[MOD_ID].customUI = false
    end
  end
  retireBucket(game and game.save and game.save.options
    and game.save.options.modOptions)
  retireBucket(game and game.mods and game.mods.modOptions)
  retireBucket(game and game.mods and game.mods.loader
    and game.mods.loader.modOptions)
  if game and type(game.persistOptions) == "function" then
    pcall(game.persistOptions, game)
  elseif game and type(game.writeOptions) == "function" then
    pcall(game.writeOptions, game)
  end
end

retireLegacyUiSwitch(nil)
if mod.events and type(mod.events.on) == "function" then
  mod.events:on("game.ready", retireLegacyUiSwitch)
end

-- Wilds of Kanto's embedded entry returns an installer factory instead of
-- executing directly.  Run it against THIS mod object, capture the child's
-- public surface, then restore this package's Stadium exports.  v0.1.74 keeps
-- this definition in the top-level entry: an earlier direct-world refactor
-- accidentally deleted it while leaving the call site behind, which made the
-- mod abort late in main.lua after its Options UI had already been registered.
local function bootEmbeddedWilds()
  local source, readErr = mod:read("lib/EmbeddedWildsMain.lua")
  if not source then return nil, tostring(readErr or "embedded Wilds runtime is missing") end
  local loadcode = loadstring or load
  local chunk, compileErr = loadcode(source, "@" .. mod.path .. "/lib/EmbeddedWildsMain.lua")
  if not chunk then return nil, tostring(compileErr) end

  local okFactory, factory = pcall(chunk)
  if not okFactory then return nil, tostring(factory) end
  if type(factory) ~= "function" then
    return nil, "embedded Wilds entry did not return its installer function"
  end

  mod.exports = mod.exports or {}
  local before = {}
  for k, v in pairs(mod.exports) do before[k] = v end

  local okRun, runErr = pcall(factory, mod)
  if not okRun then
    for k in pairs(mod.exports) do mod.exports[k] = nil end
    for k, v in pairs(before) do mod.exports[k] = v end
    return nil, tostring(runErr)
  end

  local wilds = {}
  for k, v in pairs(mod.exports) do
    if before[k] ~= v then wilds[k] = v end
  end

  for k in pairs(mod.exports) do mod.exports[k] = nil end
  for k, v in pairs(before) do mod.exports[k] = v end

  if type(wilds.logic) ~= "table" or type(wilds.render) ~= "table" then
    return nil, "embedded Wilds runtime did not expose spawn logic/render services"
  end
  return wilds
end

-- Gold/Silver/Crystal renderer bootstrap (v0.2.70: current drawWorld + compose coexistence)
--
-- GoldVoxelBridge is the renderer provider only: it prepares the embedded voxel
-- scene and exposes renderFrame(world, ctx). GoldPipelineBridge connects it to
-- current Gen1Recomp's engine-owned drawWorld seam, while GoldComposeBridge
-- remains the older-host and Character Selector coexistence path.
local function bootGoldVoxelBridge()
  local source, readErr = mod:read("lib/GoldVoxelBridge.lua")
  if not source then return nil, nil, tostring(readErr or "Gold voxel bridge is missing") end
  local chunk, compileErr = load(source, "@" .. mod.path .. "/lib/GoldVoxelBridge.lua")
  if not chunk then return nil, nil, tostring(compileErr) end
  local okLoad, Bridge = pcall(chunk, mod)
  if not okLoad then return nil, nil, tostring(Bridge) end
  if type(Bridge) ~= "table" or type(Bridge.install) ~= "function" then
    return nil, nil, "Gold voxel bridge did not expose install()"
  end
  local okInstall, installed, libOrErr = pcall(Bridge.install)
  if not okInstall then return nil, nil, tostring(installed) end
  if not installed then return nil, nil, tostring(libOrErr or "Gold voxel bridge install failed") end
  local lib = libOrErr or Bridge.lib
  if type(lib) ~= "table" or type(lib.require) ~= "function" then
    return nil, nil, "Gold voxel bridge did not expose its renderer module loader"
  end
  return Bridge, lib
end

local GoldVoxelBridge, BaseV, bridgeErr = bootGoldVoxelBridge()
local ds, dramaticShapeId
if GoldVoxelBridge and BaseV then
  if mod._vascRuntimeDiagnostics then
    local baseRequire = BaseV.require
    BaseV.require = function(name)
      return mod._vascRuntimeDiagnostics.wrap(name, baseRequire(name))
    end
  end
  ds = mod
  dramaticShapeId = "STADIUM2_GOLD_COMPOSE"
  mod.log:info("Gold/Silver/Crystal voxel renderer provider loaded; the current Gen-2 drawWorld pipeline owns world frames when available, with render.compose retained as fallback")
else
  mod.log:error("Gold/Silver/Crystal voxel renderer provider failed: %s", tostring(bridgeErr))
  mod.exports.version = VERSION
  mod.exports.rendererInstalled = false
  mod.exports.rendererError = "Gold/Silver/Crystal voxel renderer provider failed: " .. tostring(bridgeErr)
  mod.exports.hostDetected = false
  mod.exports.generation = gameGeneration()
  mod.exports.gen2Compatible = true
  mod.exports.targetGeneration = 2
  mod.exports.stadium2Importer = true
  mod.exports.standaloneRenderer = true
  mod.exports.maxDex = 251
  return
end

-- v0.1.89 is a Gen-2-only runtime. Legacy Yellow/Followers-EX glue was
-- intentionally removed. The embedded Wilds trailer mover owns the visible
-- Gold follower; the native Gen-2 follower bridge below is cleanup/fallback only.

local function loadLocal(rel, arg)
  local source, readErr = mod:read(rel)
  assert(source, ("VOXEL_ASCENDANT Gen2: missing %s: %s")
    :format(rel, tostring(readErr)))
  local chunk, err = load(source, "@" .. mod.path .. "/" .. rel)
  assert(chunk, ("VOXEL_ASCENDANT Gen2: %s did not compile: %s")
    :format(rel, tostring(err)))
  return chunk(arg)
end

-- v0.2.64 recovery guard: optional post-v0.2.45 helpers must never be able to
-- abort Gold's boot. Their installers patch presentation/settings seams only;
-- if one is incompatible with a particular Gen1Recomp build, log it and keep
-- the proven core voxel/world renderer alive.
local function safeInstall(label, module, options)
  if not (module and type(module.install) == "function") then
    return false, label .. " has no install()"
  end
  local ok, installed, err = pcall(module.install, options)
  if not ok then
    local message = tostring(installed)
    mod.log:warn("%s disabled after install error: %s", label, message)
    return false, message
  end
  if installed == false then
    local message = tostring(err or "installer returned false")
    mod.log:warn("%s not installed: %s", label, message)
    return false, message
  end
  return true, err
end

local function safeLoadLocal(label, rel, arg)
  local ok, module = pcall(loadLocal, rel, arg)
  if ok and type(module) == "table" then return module end
  local message = tostring(ok and "module did not return a table" or module)
  mod.log:warn("%s disabled after load error: %s", label, message)
  return {
    install = function() return false, message end,
    status = function() return { installed = false, lastError = message } end,
  }
end

local function inactiveSourceModule(source, reason)
  return {
    source = source,
    install = function() return false, reason end,
    status = function()
      return { installed = false, active = false, source = source, lastError = reason }
    end,
  }
end

-- Gold/Silver/Crystal share the same generation-neutral ORAS drawing wrapper
-- as the Gen-1 runtime.  It decorates pushed engine UI instances only; native
-- update/input/callback ownership stays untouched and GAME DEFAULT fails open
-- to the original draw methods.  The source is shared by the dispatcher so
-- fixes cannot drift between two copies.
local EditionAccent = safeLoadLocal(
  "Shared Red/Blue/Yellow/Gold/Silver/Crystal accent",
  "lib/EditionAccent.lua")
-- battle_hud_oras.lua is shared byte-for-byte with Gen 1 and resolves its
-- one-pixel cartridge signal through the host's public export.  Publish the
-- already-reviewed resolver before the shared HUD factory is installed;
-- otherwise Gold/Silver/Crystal silently fall back to the old cyan proof
-- colour even though every native Gen-2 menu has the correct edition accent.
mod.exports.editionAccent = EditionAccent
local OrasUiSkin = safeLoadLocal(
  "Gen-2 native ORAS UI skin", "lib/OrasUiSkin.lua", BaseV)
local OrasUiSkinInstaller = {
  install = function()
    return OrasUiSkin.install({
      mod=mod,
      companionOptionBuckets={},
      editionAccent=EditionAccent,
    })
  end,
}
local orasUiSkinInstalled, orasUiSkinErr =
  safeInstall("Gen-2 native ORAS UI skin", OrasUiSkinInstaller)

-- VASC4J exposes several renderer settings that the imported Gen-2 modules
-- already implement. Keep their cached ModSetting objects synchronized with
-- ManagerState's live options_changed events.
local VascRendererOptions = safeLoadLocal(
  "VASC renderer option bridge", "lib/VascRendererOptions.lua",
  { mod = mod, BaseV = BaseV })
local rendererOptionsInstalled, rendererOptionsErr =
  safeInstall("VASC renderer option bridge", VascRendererOptions)

-- Current VASC lifecycle/services: saved environment clocks, full weather,
-- sky events, panorama/scenery resources, local sprite/music folders and the
-- shared world.tod/footstep hooks. Build the battle Card graph first so the
-- environment can keep its legacy listeners strictly as a startup fallback.
local Gen2BattleCardHost = safeLoadLocal(
  "Gen-2 Ascendant battle Card host", "lib/Gen2BattleCardHost.lua", BaseV)
local gen2BattleCardsInstalled, gen2BattleCardsErr =
  safeInstall("Gen-2 Ascendant battle Card host", Gen2BattleCardHost, {
    mod=mod,
  })
local gen2BattleCardStatus = Gen2BattleCardHost
  and type(Gen2BattleCardHost.status) == "function"
  and Gen2BattleCardHost.status() or nil
local gen2BattleCardOwnsLifecycle = gen2BattleCardsInstalled == true
  and type(gen2BattleCardStatus) == "table"
  and gen2BattleCardStatus.ok == true
local gen2BattleLifecycleOwner
if gen2BattleCardOwnsLifecycle then
  gen2BattleLifecycleOwner = "ascendant-card"
elseif type(gen2BattleCardStatus) == "table"
    and gen2BattleCardStatus.fallbackSafe == false then
  gen2BattleLifecycleOwner = "quarantined-card"
else
  gen2BattleLifecycleOwner = "legacy-fallback"
end

local VascEnvironment = safeLoadLocal(
  "VASC environment services", "lib/VascEnvironment.lua",
  { mod = mod, BaseV = BaseV, Camera = GoldVoxelBridge })
local vascEnvironmentInstalled, vascEnvironmentErr =
  safeInstall("VASC environment services", VascEnvironment, {
    battleLifecycleOwner=gen2BattleLifecycleOwner,
  })
if vascEnvironmentInstalled == true
    and Gen2BattleCardHost
    and type(Gen2BattleCardHost.bindPostFailureRecovery) == "function"
    and VascEnvironment
    and type(VascEnvironment.armLegacyBattleRecovery) == "function" then
  local bound, bindReason = Gen2BattleCardHost.bindPostFailureRecovery(
    function(failedEncounter)
      return VascEnvironment.armLegacyBattleRecovery(failedEncounter)
    end)
  if bound ~= true then
    mod.log:warn("Gen-2 post-failure battle recovery binding failed: %s",
      tostring(bindReason))
  end
end

-- Load our configuration first, then make a tiny namespace that delegates all
-- Dramatic Shape modules to Dramatic Shape while intercepting our own config.
local Config = loadLocal("lib/OverworldStadiumConfig.lua", BaseV)
local PokemonHeights = loadLocal("lib/PokemonHeights.lua", BaseV)
local PokemonLocomotion = loadLocal("lib/PokemonLocomotion.lua", BaseV)

-- Gold exposes an engine-owned party-follower surface, but embedded Wilds
-- already owns a map-safe trailer mover and follower selection. v0.2.73 keeps
-- Wilds as the single visible follower owner (including slot #1); this bridge
-- disables/cleans native Gold copies and retains the engine follower only as a
-- fallback if the embedded Wilds follower runtime ever fails to boot.
local GoldPartyFollower = safeLoadLocal("Gold party follower bridge", "lib/GoldPartyFollower.lua", { mod = mod })
local goldPartyFollowerInstalled, goldPartyFollowerErr =
  safeInstall("Gold party follower bridge", GoldPartyFollower)
if goldPartyFollowerInstalled then
  mod.log:info("Gold follower ownership bridge installed; embedded Wilds owns slot #1 with native Gen-2 fallback only")
end

-- Put Stadium ROM selection inside THIS MOD'S Mod Manager -> Options screen.
-- The manifest also ships options.lua so the recomp mod manager exposes an OPTIONS button
-- for this mod.  StadiumRomMenu converts the STADIUM ROM FILE row into a real
-- Android file-picker action (A/Confirm, Left, or Right all open the system Files picker).
local RomMenuV = { require = BaseV.require }
local StadiumRomMenu = loadLocal("lib/StadiumRomMenu.lua", RomMenuV)
local managerOptionsInstalled = StadiumRomMenu.installModManagerOptions(mod)

-- The earlier standalone prototype replaced Gold's START screen and most of
-- its submenus with edition-specific palettes. Keep the broad submenu
-- replacement inactive. The START screen itself receives one responsive
-- ORAS-glass draw adapter; the engine keeps every callback, update path, field
-- move and switch operation, and GAME DEFAULT delegates to native drawing.
local nativeJohtoUiReason =
  "inactive handoff: shared ORAS skin owns presentation; native Gen-2 owns semantics"
local okDiagnostics, Diagnostics = pcall(BaseV.require, "Diagnostics")
if not okDiagnostics or type(Diagnostics) ~= "table" then Diagnostics = nil end
if Diagnostics and type(Diagnostics.boot) == "function" then
  local okBoot, bootErr = pcall(Diagnostics.boot)
  if not okBoot then
    mod.log:warn("Gen-2 RC diagnostics boot failed open: %s", tostring(bootErr))
  end
end
local okPerformanceDiagnostics, PerformanceDiagnostics =
  pcall(BaseV.require, "PerformanceDiagnostics")
if not okPerformanceDiagnostics or type(PerformanceDiagnostics) ~= "table" then
  PerformanceDiagnostics = nil
end
if PerformanceDiagnostics and type(PerformanceDiagnostics.install) == "function" then
  local okPerformance, performanceErr = PerformanceDiagnostics.install({
    diagnostics=Diagnostics,
  })
  if not okPerformance then
    mod.log:warn("Gen-2 performance monitor failed open: %s",
      tostring(performanceErr or "unavailable"))
  end
end
if MobileDiagnostic and Diagnostics
    and type(MobileDiagnostic.setLogger) == "function" then
  pcall(MobileDiagnostic.setLogger, Diagnostics)
end
if GoldVoxelBridge and type(GoldVoxelBridge.setDiagnostics) == "function" then
  pcall(GoldVoxelBridge.setDiagnostics, Diagnostics)
end
local okSharedMenuStyle, SharedMenuStyle = pcall(BaseV.require, "VascMenuStyle")
if not okSharedMenuStyle then SharedMenuStyle = nil end
local okCanvasPresentation, CanvasPresentation =
  pcall(BaseV.require, "CanvasPresentation")
if not okCanvasPresentation then CanvasPresentation = nil end
local okTitleHubPresentation, TitleHubPresentation =
  pcall(BaseV.require, "TitleHubPresentation")
if not okTitleHubPresentation then TitleHubPresentation = nil end
local SharedVascMenuPresentation = safeLoadLocal(
  "shared Gen-1 VASC menu presentation",
  "lib/SharedVascMenuPresentation.lua", {
    mod=mod,
    Style=SharedMenuStyle,
    Diagnostics=Diagnostics,
    CanvasPresentation=CanvasPresentation,
  })
local sharedMenuInstalled, sharedMenuErr = safeInstall(
  "shared Gen-1 VASC menu presentation", SharedVascMenuPresentation)
local PauseMenuBattleStyle = safeLoadLocal(
  "Gen-2 ORAS START presentation", "lib/PauseMenuBattleStyle.lua", {
    mod=mod,
    OrasUiSkin=OrasUiSkin,
    SharedMenuPresentation=SharedVascMenuPresentation,
    Diagnostics=Diagnostics,
    CanvasPresentation=CanvasPresentation,
  })
local pauseStyleInstalled, pauseStyleErr =
  safeInstall("Gen-2 ORAS START presentation", PauseMenuBattleStyle)
local TitleMenuVascStyle = safeLoadLocal(
  "Gen-2 VASC title menu presentation", "lib/TitleMenuVascStyle.lua", {
    mod=mod,
    SharedMenuPresentation=SharedVascMenuPresentation,
    TitleHubPresentation=TitleHubPresentation,
    Diagnostics=Diagnostics,
    CanvasPresentation=CanvasPresentation,
  })
local titleMenuStyleInstalled, titleMenuStyleErr = safeInstall(
  "Gen-2 VASC title menu presentation", TitleMenuVascStyle)

-- v0.2.39: the pause menu now grows tall enough to expose its normal complete
-- row set, and every built-in Gold screen launched from it receives the same
-- custom battle-selector presentation.  The constructors are tagged only when
-- StartMenu is the caller, so Party/Pack/Pokedex/Pokegear screens used by
-- battles, scripts and other engine flows keep their native presentation.
-- v0.2.41 introduced PartyModelPreview. v0.2.42 makes Party/Summary skinning
-- deterministic on Gen1Recomp v0.1.83 (not dependent on StartMenu constructor
-- timing) and BattleControllerUI now uses the same preview in its live 3D PKMN
-- selector. Pass the renderer namespace so both paths share StadiumMon/Voxel3D.
local OrasPartyPresentationV = setmetatable({ mod=mod }, { __index=BaseV })
local OrasPartyPresentation = safeLoadLocal(
  "shared ORAS Team presentation",
  "lib/OrasPartyPresentation.lua", OrasPartyPresentationV)
local OrasPartySummaryPresentationV = setmetatable({
  mod=mod,
  PartyPresentation=OrasPartyPresentation,
}, { __index=BaseV })
local OrasPartySummaryPresentation = safeLoadLocal(
  "shared ORAS Summary presentation",
  "lib/OrasPartySummaryPresentation.lua", OrasPartySummaryPresentationV)
local okOrasBag, OrasBagSkin = pcall(BaseV.require, "OrasBagSkin")
if not okOrasBag then OrasBagSkin = nil end
local okOrasFrlgBag, OrasFrlgBagSkin = pcall(BaseV.require, "OrasFrlgBagSkin")
if not okOrasFrlgBag then OrasFrlgBagSkin = nil end
local okManualBagSort, ManualBagSort = pcall(BaseV.require, "ManualBagSort")
if not okManualBagSort then ManualBagSort = nil end
local GoldSubmenuV = setmetatable({
  mod=mod,
  OrasPartyPresentation=OrasPartyPresentation,
  OrasPartySummaryPresentation=OrasPartySummaryPresentation,
  OrasBagSkin=OrasBagSkin,
  OrasFrlgBagSkin=OrasFrlgBagSkin,
  ManualBagSort=ManualBagSort,
  SharedMenuPresentation=SharedVascMenuPresentation,
  Diagnostics=Diagnostics,
  CanvasPresentation=CanvasPresentation,
}, { __index=BaseV })
local GoldSubmenuBattleStyle = safeLoadLocal(
  "Gen-2 ORAS party/summary presentation",
  "lib/GoldSubmenuBattleStyle.lua", GoldSubmenuV)
local submenuStyleInstalled, submenuStyleErr =
  safeInstall("Gen-2 ORAS party/summary presentation", GoldSubmenuBattleStyle)
if ManualBagSort and type(ManualBagSort.installPointer) == "function" then
  local bagSortInstalled, bagSortReason = ManualBagSort.installPointer(mod, {
    pointerToLogical=GoldSubmenuBattleStyle
      and GoldSubmenuBattleStyle.pointerToBagLogical,
  })
  if not bagSortInstalled and mod.log and type(mod.log.warn) == "function" then
    mod.log:warn("Gen-2 manual Bag sort pointer failed open: %s",
      tostring(bagSortReason))
  end
end

-- v0.2.79: Gold/Silver/Crystal still own the complete Fly contract.  VASC's
-- widescreen atlas may show both regions at once and, only after the Hall of
-- Fame receipt, offer all visited Johto + postgame spawn rows together.
local Gen2WorldMap = safeLoadLocal(
  "Gen-2 Johto/Kanto world map", "lib/Gen2WorldMap.lua", { mod=mod })
local gen2WorldMapInstalled, gen2WorldMapErr =
  safeInstall("Gen-2 Johto/Kanto world map", Gen2WorldMap)

-- Field/QoL presentation remains opt-in per feature at runtime. Fly, Surf,
-- fishing and the read-only comfort displays may ship enabled; Field Kit is
-- deliberately disabled by default. None of these hooks replaces Crystal's
-- item, badge, warp, encounter or battle-rule authority.
local Gen2Comfort = safeLoadLocal(
  "Gen-2 field/comfort presentation", "lib/Gen2Comfort.lua", { mod=mod })
local gen2ComfortInstalled, gen2ComfortErr =
  safeInstall("Gen-2 field/comfort presentation", Gen2Comfort)
mod.exports.gen2Comfort = Gen2Comfort

-- KASC comfort parity uses only concrete Gen-2 host seams: the native
-- registered-item/SELECT path, capture storage queue, BoxMenu box step and
-- thrown-ball palette resolver. Every adapter is independently switchable.
local Gen2KascQol = safeLoadLocal(
  "Gen-2 KASC comfort parity", "lib/Gen2KascQol.lua", { mod=mod })
local gen2KascQolInstalled, gen2KascQolErr =
  safeInstall("Gen-2 KASC comfort parity", Gen2KascQol)
mod.exports.gen2KascQol = Gen2KascQol
mod.exports.gen2KascQolInstalled = gen2KascQolInstalled == true
mod.exports.gen2KascQolError = gen2KascQolErr
mod.exports.gen2KascQolStatus = function()
  return Gen2KascQol and Gen2KascQol.status and Gen2KascQol.status() or {
    installed = false, lastError = gen2KascQolErr,
  }
end

-- Capture-ball visuals are a separate presentation card. The recovered QoL
-- owner supplies only the native palette marker; this segment may be changed
-- or rolled back without touching registered items, boxes or catch storage.
local Gen2CaptureBallPresentation = safeLoadLocal(
  "Gen-2 capture-ball presentation",
  "lib/Gen2CaptureBallPresentation.lua", { mod=mod })
local gen2CaptureBallPresentationInstalled, gen2CaptureBallPresentationErr =
  safeInstall("Gen-2 capture-ball presentation", Gen2CaptureBallPresentation)
mod.exports.gen2CaptureBallPresentation = Gen2CaptureBallPresentation
mod.exports.gen2CaptureBallPresentationInstalled =
  gen2CaptureBallPresentationInstalled == true
mod.exports.gen2CaptureBallPresentationError = gen2CaptureBallPresentationErr
mod.exports.gen2CaptureBallPresentationStatus = function()
  return Gen2CaptureBallPresentation and Gen2CaptureBallPresentation.status
    and Gen2CaptureBallPresentation.status() or {
      installed=false, lastError=gen2CaptureBallPresentationErr,
    }
end

-- v0.2.77: split character presentation into independent Pokemon-model and
-- human-player-model switches. Stadium Pokemon geometry remains controlled by
-- stadium3dSprites; red_3d_player's selected Gold skin is controlled separately
-- by player3dModel so either layer can fall back to its 2D Gold card alone.
-- Ordinary Gold dialogue and YES/NO prompts use a dedicated opaque Johto
-- paper/silver frame. It intentionally shares no background or palette with
-- the retained battle HUD; TextBox/ChoiceBox keep all engine behaviour.
local TextBoxBattleStyle = inactiveSourceModule(
  "lib/TextBoxBattleStyle.lua", nativeJohtoUiReason)
local textBoxStyleInstalled, textBoxStyleErr = false, nativeJohtoUiReason

-- v0.2.76: widen both this renderer's continuous diorama range and the
-- engine-native survey ladder used by Character Selector/native ZOOM. The
-- official zoom.range hook adds one 0.25-scale whole-region rung in OPEN WORLD.
local OpenWorldZoom = safeLoadLocal(
  "OPEN WORLD extended zoom", "lib/OpenWorldZoom.lua", { mod = mod })
local openWorldZoomInstalled, openWorldZoomErr =
  safeInstall("OPEN WORLD extended zoom", OpenWorldZoom)

-- v0.2.40: MODS now opens a fully matching glass submenu.  The Mod Manager's
-- installed-mod list, per-mod detail menu, OPTIONS submenu, permissions,
-- errors, profiles, apply/restart prompts and confirmation overlays all use
-- the same battle-selector visual language.  Any mod using options_schema is
-- covered automatically.  A screen.pushed watcher also skins conventional
-- list-like menus opened by hook-injected START-menu rows while leaving custom
-- renderers it cannot safely understand untouched.
local ModMenuBattleStyle = inactiveSourceModule(
  "lib/ModMenuBattleStyle.lua", nativeJohtoUiReason)
local modMenuStyleInstalled, modMenuStyleErr = false, nativeJohtoUiReason

-- v0.2.55: Gen-2 ManagerState writes live option values correctly but the
-- v0.1.83 Gold path persists through Game2:persistOptions rather than the
-- writeOptions name ManagerState probes. Bridge that seam so every toggle and
-- choice on this mod's MOD SETTINGS page survives a restart.
local ModSettingsPersistence = safeLoadLocal("Gold mod-settings persistence bridge", "lib/ModSettingsPersistence.lua", { mod = mod })
local persistenceInstalled, persistenceErr =
  safeInstall("Gold mod-settings persistence bridge", ModSettingsPersistence)

-- v0.2.56: this mod now has enough controls that one flat ManagerState list is
-- awkward on phones. Keep ManagerState as the value/persistence owner, but
-- present this mod through category submenus (world/performance, camera/display,
-- battle, 3D models, wild Pokemon, followers/behavior, developer).
local CategorizedModSettings = inactiveSourceModule(
  "lib/CategorizedModSettings.lua", nativeJohtoUiReason)
local categorizedInstalled, categorizedErr = false,
  "inactive fallback: native Mod Manager remains unchanged; VascMenu owns the hub"

-- v0.2.56: screenFlip is no longer a render.compose-only transform. Gold draws
-- HUD/touch controls after compose, so the compatibility flip now wraps the
-- entire Game2:draw frame and inversely remaps Android touch coordinates.
local AndroidFullFrameFlip = safeLoadLocal("Android whole-frame flip", "lib/AndroidFullFrameFlip.lua", { mod = mod })
local fullFrameFlipInstalled, fullFrameFlipErr =
  safeInstall("Android whole-frame flip", AndroidFullFrameFlip)

-- Screen-space feedback for successful keyboard/controller display shortcuts.
-- It is installed after the whole-frame Android wrapper so the card itself is
-- part of the final orientation, while GoldVoxelBridge remains the input owner.
local ShortcutToast = safeLoadLocal("ORAS shortcut notice", "lib/ShortcutToast.lua", { mod = mod })
local shortcutToastInstalled, shortcutToastErr = false, nil
do
  local okGame, Game2 = pcall(require, "src.core.Game2")
  if okGame and ShortcutToast and type(ShortcutToast.install) == "function" then
    local okInstall, installed, installErr = pcall(ShortcutToast.install, Game2, {
      enabled = function()
        if not (mod.options and type(mod.options.get) == "function") then return true end
        local ok, value = pcall(mod.options.get, mod.options, "shortcutToast")
        return not ok or value ~= false
      end,
    })
    shortcutToastInstalled = okInstall and installed ~= false
    shortcutToastErr = shortcutToastInstalled and nil
      or tostring(okInstall and installErr or installed)
  else
    shortcutToastErr = tostring(okGame and "shortcut presenter unavailable" or Game2)
  end
  if GoldVoxelBridge and type(GoldVoxelBridge.setShortcutToast) == "function" then
    pcall(GoldVoxelBridge.setShortcutToast, ShortcutToast)
  end
end

-- Historical fallback: v0.2.x put the flat Mod Manager settings page directly
-- below OPTION. Keep the module for source/handoff compatibility, but leave its
-- hook inactive; VascMenuGen2 installs the one ASCENDANT row after the
-- embedded Wilds runtime is ready.
local DirectModSettingsMenu = inactiveSourceModule(
  "lib/DirectModSettingsMenu.lua", nativeJohtoUiReason)
local directSettingsInstalled, directSettingsErr = false,
  "inactive fallback: VascMenuGen2 owns the single ASCENDANT start row"

-- Older releases fell back to a native OPTIONS hook when the Mod Manager could
-- not decorate this mod's action row. Do not do that in the owner-isolated
-- build: the Stadium ROM action is always available inside ASCENDANT,
-- and Gold/Silver's standard OPTIONS screen remains exact on every host.
if not managerOptionsInstalled then
  mod.log:info("Mod Manager Stadium action unavailable; using the Voxel Ascendant hub only")
end

-- Gold voxel renderer status. v0.2.73 targets current Gen1Recomp's official
-- render_pipelines.drawWorld seam again, while preserving render.compose as a
-- real compatibility/coexistence fallback. In particular, red_3d_player owns
-- the engine's public `voxel` pipeline ladder; when that selector is installed
-- GoldPipelineBridge intentionally stays OFF so the selector is not disabled by
-- Gen1Recomp's one-world-pipeline rule. GoldComposeBridge then owns the window
-- and OverworldStadium draws the selector's chosen skin into the voxel scene.
local GoldPipelineBridge = safeLoadLocal(
  "Gold drawWorld voxel pipeline", "lib/GoldPipelineBridge.lua",
  { mod = mod, VoxelBridge = GoldVoxelBridge })
local goldPipelineInstalled, goldPipelineErr =
  safeInstall("Gold drawWorld voxel pipeline", GoldPipelineBridge)
local voxelPipelineState = goldPipelineInstalled and GoldPipelineBridge or GoldVoxelBridge
if goldPipelineInstalled then
  mod.log:info("Gold drawWorld voxel pipeline registered; render.compose remains fallback/Character Selector coexistence path")
else
  mod.log:warn("Gold drawWorld voxel pipeline unavailable; using render.compose: %s",
    tostring(goldPipelineErr))
end

-- Android may recreate the app while the native document picker is open.
-- Finish a pending Stadium selection as soon as the live Gold service owner is
-- ready.  Rendering itself is installed later through mod.hooks:wrap.
mod.events:on("game.ready", function(game)
  pcall(StadiumRomMenu.poll, game)
end)

-- GoldPipelineBridge registers its engine listener during install, before the
-- generation-specific map lifecycle below.  Crystal rebuilds the public
-- render-pipeline registry while replacing a map, so that early listener can
-- legitimately observe the temporary OFF rung.  Always perform one final
-- synchronization *after* GoldVoxelBridge has armed its bounded recovery
-- latch.  This keeps the official drawWorld provider and the compose fallback
-- in the same state instead of leaving third-person controls active over a
-- native 2D world.
local function rehydrateGoldVoxelPipeline(payload, trigger)
  if not (GoldPipelineBridge
      and type(GoldPipelineBridge.sync) == "function") then
    return false, "pipeline-bridge-unavailable"
  end
  local ok, synced, activeOrError = pcall(GoldPipelineBridge.sync, payload)
  local status = type(GoldPipelineBridge.status) == "function"
    and GoldPipelineBridge.status() or {}
  if Diagnostics and type(Diagnostics.write) == "function" then
    pcall(Diagnostics.write, "gen2-voxel-pipeline-rehydrate", {
      trigger=trigger or "unspecified",
      callOk=ok,
      synced=ok and synced == true,
      result=ok and activeOrError or tostring(synced),
      runtimeInstalled=status.runtimeInstalled,
      runtimeActive=status.runtimeActive,
      selectorDetected=status.selectorDetected,
      selectorComposeFallback=status.selectorComposeFallback,
      pipelineError=status.lastError,
    })
  end
  if not ok or synced ~= true then
    local reason = ok and activeOrError or synced
    mod.log:warn("Gen-2 voxel pipeline rehydrate (%s) failed open: %s",
      tostring(trigger or "unspecified"), tostring(reason))
    return false, reason
  end
  return true, activeOrError
end

mod.events:on("map.entered", function(payload)
  if GoldVoxelBridge and type(GoldVoxelBridge.onMapEntered) == "function" then
    local ok, resetOrErr, _, lifecycleErr = pcall(
      GoldVoxelBridge.onMapEntered, payload)
    if not ok then
      mod.log:warn("Gen-2 voxel map lifecycle reset failed; native map remains authoritative: %s",
        tostring(resetOrErr))
    elseif lifecycleErr ~= nil then
      mod.log:warn("Gen-2 voxel map cache reconciliation declined; native map remains authoritative: %s",
        tostring(lifecycleErr))
    end
  elseif GoldVoxelBridge then
    GoldVoxelBridge.mapId = nil
  end
  -- This call must remain after onMapEntered: optionOn() can now see the
  -- pending recovery latch even if Crystal temporarily reset the public
  -- option/pipeline during setMap.
  rehydrateGoldVoxelPipeline(payload, "map.entered-after-lifecycle")
end)

-- First boot/save resume has no preceding player.warped event.  Register these
-- receipts after GoldPipelineBridge's own handlers as a final, idempotent
-- synchronization against the fully restored option bucket.
mod.events:on("game.ready", function(game)
  rehydrateGoldVoxelPipeline(game, "game.ready-final")
end)
mod.events:on("save.loaded", function(payload)
  rehydrateGoldVoxelPipeline(payload, "save.loaded-final")
end)

-- Legacy Pokemon Yellow follower and Dramatic Sky Ride compatibility code
-- used Gen-1 `src.world.*` controllers and is not loaded in this Gold/Silver
-- package. Keeping it here only increased startup work and made the package
-- look less generation-specific, so v0.1.89 removes it.

local V = {
  mod = mod,
  path = mod.path,
  voxelHostId = dramaticShapeId,
}
setmetatable(V, { __index = BaseV })
function V.require(name)
  if name == "OverworldStadiumConfig" then return Config end
  if name == "PokemonHeights" then return PokemonHeights end
  if name == "PokemonLocomotion" then return PokemonLocomotion end
  -- EditionAccent lives at the shared package root, outside the embedded
  -- Gen-2 renderer namespace.  Return the exact already-loaded resolver here
  -- so AscendantHudTheme paints Gold/Silver/Crystal borders instead of keeping
  -- its cyan fail-open colour while merely reporting the right edition id.
  if name == "EditionAccent" then return EditionAccent end
  if name == "AscendantHudTheme" and V.AscendantHudTheme then return V.AscendantHudTheme end
  return BaseV.require(name)
end

-- Publish the generation-neutral PokemonUi v1 exchange in Gen 2 as well.
-- The ASC BOX provider is dormant until an authoritative host (for example a
-- future JASC Legacy Bank) registers. We deliberately do not install the
-- Gen-1 BoxMenu host adapter here, so Johto's reviewed native wide PC/Box
-- presentation and all storage rules remain untouched in a standalone run.
local PokemonUi, AscBoxProvider
local pokemonUiProviderInstalled = false
local pokemonUiProviderError
do
  local okUi, uiOrError = pcall(V.require, "PokemonUi")
  if okUi and type(uiOrError) == "table"
      and type(uiOrError.public) == "function" then
    PokemonUi = uiOrError
    local okProvider, providerOrError = pcall(V.require, "AscBoxProvider")
    if okProvider and type(providerOrError) == "table"
        and type(providerOrError.install) == "function" then
      AscBoxProvider = providerOrError
      local okInstall, installed, why = pcall(
        AscBoxProvider.install, PokemonUi)
      pokemonUiProviderInstalled = okInstall and installed == true
      if not pokemonUiProviderInstalled then
        pokemonUiProviderError = tostring(okInstall and why or installed)
      end
    else
      pokemonUiProviderError = tostring(providerOrError)
    end
  else
    pokemonUiProviderError = tostring(uiOrError)
  end
  if pokemonUiProviderError and mod.log
      and type(mod.log.warn) == "function" then
    mod.log:warn("Gen-2 Pokemon UI exchange failed open: %s",
      pokemonUiProviderError)
  end
end

local Stadium = loadLocal("lib/OverworldStadium.lua", V)
V.OverworldStadium = Stadium

-- Retained presentation-control prototype. Native Gen-2 battle menus and input
-- must receive the left stick/WASD without a second consumer moving an actor in
-- the same frame, so VASC4J does not attach this module to Stadium.updateGen2.
local BattlePokemonControl = inactiveSourceModule(
  "lib/BattlePokemonControl.lua",
  "inactive handoff: native Gen-2 battle input has exclusive ownership")
local battlePokemonControlInstalled = false
local battlePokemonControlErr =
  "inactive handoff: native Gen-2 battle input has exclusive ownership"
-- Portable palette contract for the retained HUD prototype. The active Johto
-- build does not draw that HUD, but VASC can consume the controller and theme
-- independently and select Red/Blue/Yellow/Gold/Silver/Crystal colours.
-- Pass the live Gen-2 facade: AscendantHudTheme resolves EditionAccent through
-- V.require().  Calling the chunk without this argument leaves it on the cyan
-- fail-open palette even though save.version and the public resolver are both
-- correct.
local AscendantHudTheme = loadLocal("lib/AscendantHudTheme.lua", V)
V.AscendantHudTheme = AscendantHudTheme
-- Draw-only controller HUD. It never installs its historical input wrappers:
-- Gold/Silver/Crystal continue to own the battle cursor, A/B dispatch, PACK,
-- PKMN, switching and all special battle flows. VoxelScene/GoldComposeBridge
-- call only owns()/drawFull() and fail open to the complete native canvas.
local BattleControllerUI = safeLoadLocal(
  "Gen-2 ORAS battle HUD presentation", "lib/BattleControllerUI.lua", V)
V.BattleControllerUI = BattleControllerUI
BaseV.BattleControllerUI = BattleControllerUI
mod.exports.battleControllerUI = BattleControllerUI
mod.exports.gen2BattleProjectionStatus = function()
  local scene = V.require("VoxelScene")
  local battle = V.require("OverworldBattle")
  return (scene and scene.lastBattleProjectionDiagnostic)
    or (battle and battle.lastActorProjectionDiagnostic) or nil
end
mod.exports.gen2BattleProjection = function()
  local battle = V.require("OverworldBattle")
  local shot = battle and type(battle.shot) == "function" and battle.shot() or nil
  return shot and type(shot.actorVisuals) == "table" and shot or nil
end
-- Publish the exact stateful camera instance used by VoxelScene.  QA and the
-- built-in debugger must not resolve a second loader facade and accidentally
-- inspect a fresh module while the renderer is moving the real camera.
local BattleCinematic = V.require("BattleCinematic")
V.BattleCinematic = BattleCinematic
BaseV.BattleCinematic = BattleCinematic
mod.exports.battleCinematic = BattleCinematic
-- Public, generation-neutral Injector contract.  The mutable controller stays
-- private; consumers receive only validated import/status/sky-policy methods.
local BattleLayout = V.require("BattleLayout")
mod.exports.battleLayout = type(BattleLayout.public) == "function"
  and BattleLayout.public() or nil
local Gen2MeshCache = V.require("Gen2MeshCache")
mod.exports.gen2MeshCache = Gen2MeshCache
-- Expose the same resolver used by the live battle renderer.  This lets the
-- built-in diagnostics report honest HD/native trainer coverage instead of
-- accidentally loading a second facade with a different asset context.
local Gen2TrainerArt = V.require("Gen2TrainerArt")
mod.exports.gen2TrainerArt = Gen2TrainerArt
mod.exports.ascendantHudPrototype = {
  apiVersion = 1,
  enabled = true,
  controller = BattleControllerUI,
  theme = AscendantHudTheme,
  handoff = "docs/VASC_HUD_HANDOFF.md",
}
-- Deliberately no BattleControllerUI.install() call: this activation is
-- presentation-only and cannot consume or synthesize controller input.

-- The ORAS move surface is visibly arranged as a 2x2 grid. Gold remains the
-- sole input owner and already contains the complete left/right/up/down grid
-- implementation; this read-only capability hook merely tells that native
-- owner when the active VASC presentation is actually showing the grid.
local battleMoveGridNavigationInstalled = false
local battleMoveGridNavigationError = nil
if mod.hooks and type(mod.hooks.wrap) == "function" then
  local okGridHook, gridHookOrError = pcall(function()
    return mod.hooks:wrap("battle.move_grid_navigation", function(next, screen)
      if type(BattleControllerUI) == "table"
          and type(BattleControllerUI.owns) == "function"
          and BattleControllerUI.owns(screen) then
        return true
      end
      return next(screen)
    end)
  end)
  battleMoveGridNavigationInstalled = okGridHook == true
  if not okGridHook then
    battleMoveGridNavigationError = tostring(gridHookOrError)
  end
else
  battleMoveGridNavigationError = "mod.hooks.wrap unavailable (hooks="
    .. tostring(type(mod.hooks)) .. ", wrap="
    .. tostring(type(mod.hooks and mod.hooks.wrap)) .. ")"
end
mod.exports.ascendantHudPrototype.moveGridNavigation =
  battleMoveGridNavigationInstalled
mod.exports.battleMoveGridNavigationInstalled =
  battleMoveGridNavigationInstalled
mod.exports.battleMoveGridNavigationError = battleMoveGridNavigationError
if battleMoveGridNavigationError and mod.log
    and type(mod.log.warn) == "function" then
  mod.log:warn("Gen-2 ORAS move-grid hook unavailable: %s",
    battleMoveGridNavigationError)
end

local BattleStadiumAnimations = safeLoadLocal("Pokemon Stadium Stage 1 battle performances", "lib/BattleStadiumAnimations.lua", V)
local battleAnimationsInstalled, battleAnimationsErr =
  safeInstall("Pokemon Stadium Stage 1 battle performances", BattleStadiumAnimations)
if battleAnimationsInstalled then
  mod.log:info("Pokemon Stadium Stage 1 battle performances enabled")
end

-- Use the same authored VASC animation catalog/player and structural checker
-- as Kanto.  Johto enables every move present in its native 1-251 registry;
-- the 3D choreography layer below remains the complete smart-anchor fallback
-- for all 251 moves and for any individual sheet/frame that cannot be drawn.
local BattleAnimationCompat = V.require("BattleAnimationCompat")
local battleAnimationInstallLogged = false
local function refreshVascBattleAnimations(payload, trigger)
  local game = type(payload) == "table" and (payload.game or payload) or nil
  -- Gen 2's battle.started payload owns the logic Battle directly.  Unlike
  -- Gen 1 it is not a Game service owner, but its `.data` is exactly the
  -- merged registry BattleAnimationCompat needs.  Adapt that native contract
  -- locally instead of reaching into the Kanto singleton/facade.
  if not (type(game) == "table" and type(game.data) == "table")
      and type(payload) == "table" and type(payload.battle) == "table"
      and type(payload.battle.data) == "table" then
    game = { data=payload.battle.data }
  end
  if not (type(game) == "table" and type(game.data) == "table") then
    local okGame, Game = pcall(require, "src.core.Game")
    if okGame and type(Game) == "table" and type(Game.data) == "table" then
      game = Game
    end
  end
  if not game then return false, "game-data-unavailable" end
  local ok, aliasesInstalled, aliasesMissing, receipt = pcall(
    BattleAnimationCompat.install, game, mod, {
      enablePostGen=true, nativeMoveMax=251,
    })
  if not ok then
    mod.log:warn("Johto VASC move-animation catalog failed open: %s",
      tostring(aliasesInstalled))
    return false, tostring(aliasesInstalled)
  end
  receipt = type(receipt) == "table" and receipt
    or BattleAnimationCompat.status()
  if Diagnostics and type(Diagnostics.write) == "function" then
    pcall(Diagnostics.write, "gen2-move-animation-audit", {
      trigger=trigger or "unspecified",
      installed=receipt.installed,
      catalogValid=receipt.catalogValid,
      catalogPerfect=receipt.catalogPerfect,
      programs=receipt.programs,
      frames=receipt.frames,
      invalidSheets=receipt.invalidSheets,
      invalidPrograms=receipt.invalidPrograms,
      invalidFrames=receipt.invalidFrames,
      gen1=receipt.gen1,
      postGen=receipt.postGen,
      coveredNativePrograms=receipt.coveredNativePrograms,
      missingNativeProgramCount=receipt.missingNativeProgramCount,
      missingNativePrograms=receipt.missingNativePrograms,
    })
  end
  if receipt.installed == true then
    if not battleAnimationInstallLogged then
      battleAnimationInstallLogged = true
      mod.log:info("Johto VASC move-animation player ready (%s/%s programs, trigger=%s)",
        tostring(receipt.coveredNativePrograms),
        tostring(receipt.nativeMoveCount), tostring(trigger or "unspecified"))
    end
  else
    mod.log:warn("Johto VASC move-animation player unavailable at %s: %s",
      tostring(trigger or "unspecified"), tostring(receipt.reason))
  end
  return receipt.installed == true, receipt.reason
end
mod.events:on("game.ready", function(payload)
  return refreshVascBattleAnimations(payload, "game.ready")
end)
mod.events:on("save.loaded", function(payload)
  return refreshVascBattleAnimations(payload, "save.loaded")
end)
mod.events:on("battle.started", function(payload)
  return refreshVascBattleAnimations(payload, "battle.started")
end)
mod.events:on("map.entered", function(payload)
  return refreshVascBattleAnimations(payload, "map.entered")
end)

-- ARENA is the only mode whose feet depend on a replaceable 1280x800
-- painting.  Analyse that painting at map entry and cache its normalized
-- player/enemy/trainer ground marks.  MAP keeps its walkable map cells and
-- DISCS keep their authored platform positions; neither is routed through
-- this bitmap resolver.  BattleScene converts the cached marks to immutable
-- world points exactly once when the battle camera is first available.
local lastArenaAnchorPreparation = {
  prepared=false, reason="not-run", mode=nil, mapId=nil,
}
local function arenaModeSelected()
  if not (mod.options and type(mod.options.get) == "function") then
    return false, nil
  end
  local ok, value = pcall(mod.options.get, mod.options, "battle3dWorld")
  if not ok then return false, nil end
  local key = type(value) == "string"
    and value:lower():gsub("[%s_-]+", "") or value
  return key == "arena" or key == "stadium", value
end
local function prepareArenaAnchorsOnMapEntry(payload)
  local selected, selectedValue = arenaModeSelected()
  if not selected then
    lastArenaAnchorPreparation = {
      prepared=false, reason="mode-is-not-arena", mode=selectedValue,
      mapId=type(payload) == "table" and payload.mapId or nil,
    }
    return
  end
  local map = type(payload) == "table" and payload.map or nil
  if not map then
    local ow = mod.world and mod.world.overworld and mod.world:overworld()
    map = ow and ow.map or nil
  end
  if not map then
    lastArenaAnchorPreparation = {
      prepared=false, reason="map-unavailable", mode=selectedValue,
      mapId=type(payload) == "table" and payload.mapId or nil,
    }
    return
  end
  local ok, receipt = pcall(function()
    local backdrop = V.require("BattleBackdrop")
    local arena = assert(backdrop.arena(map), "arena-backdrop-unresolved")
    local spec = assert(arena.backdropSpec, "arena-backdrop-spec-missing")
    assert(backdrop.prepare(arena,
      spec.outdoor == true or spec.voxelSky == true),
      "arena-backdrop-decode-failed")
    local stage = V.require("VoxelBattleStage")
    local mon = assert(stage.presentationComposition(arena, false),
      "arena-ground-composition-missing")
    local trainer = assert(stage.presentationComposition(arena, true),
      "arena-trainer-composition-missing")
    assert(mon.player and mon.enemy and trainer.player and trainer.enemy,
      "arena-ground-pair-incomplete")
    return {
      prepared=true, reason=nil, mode="arena",
      mapId=tostring(map.id or (map.def and map.def.id) or ""),
      backdropKey=arena.backdropKey,
      source=mon.source,
      player={ x=mon.player.x, y=mon.player.y },
      enemy={ x=mon.enemy.x, y=mon.enemy.y },
      trainerPlayer={ x=trainer.player.x, y=trainer.player.y },
      trainerEnemy={ x=trainer.enemy.x, y=trainer.enemy.y },
    }
  end)
  if ok then
    lastArenaAnchorPreparation = receipt
  else
    lastArenaAnchorPreparation = {
      prepared=false, reason=tostring(receipt), mode="arena",
      mapId=tostring(map.id or (map.def and map.def.id) or ""),
    }
    mod.log:warn("Johto ARENA ground preflight failed open: %s",
      tostring(receipt))
  end
end
mod.events:on("map.entered", prepareArenaAnchorsOnMapEntry)
mod.exports.gen2ArenaAnchorPreparationStatus = function()
  local copy = {}
  for key, value in pairs(lastArenaAnchorPreparation) do
    if type(value) == "table" then
      copy[key] = { x=value.x, y=value.y }
    else
      copy[key] = value
    end
  end
  return copy
end

-- Crystal has a separate BattleState/AnimRunner stack.  Register a Johto-only
-- visual bridge once; refreshVascBattleAnimations continues to update the
-- private catalog holder at game/save/map/battle boundaries.
local Gen2VascBattleAnimations = safeLoadLocal(
  "Johto VASC move-animation presentation",
  "lib/Gen2VascBattleAnimations.lua", V)
local gen2VascAnimationsInstalled, gen2VascAnimationsErr = safeInstall(
  "Johto VASC move-animation presentation", Gen2VascBattleAnimations)
mod.exports.gen2VascBattleAnimations = Gen2VascBattleAnimations
if gen2VascAnimationsInstalled then
  mod.log:info("Johto VASC move-animation presentation connected to Crystal BattleState")
end

-- Crystal's native 2x2 command cursor does not match the shared ORAS command
-- shape painted by BattleControllerUI (FIGHT above BAG / POKEMON / RUN). Keep
-- this as a separate, generation-local card: it adapts directional neighbours
-- only while that exact presentation owns the battle and leaves A-confirm,
-- command callbacks and all native battle logic untouched.
local Gen2BattleCommandNavigation = safeLoadLocal(
  "Johto ORAS battle command navigation",
  "lib/Gen2BattleCommandNavigation.lua", V)
local gen2BattleCommandNavigationInstalled,
  gen2BattleCommandNavigationError = safeInstall(
    "Johto ORAS battle command navigation", Gen2BattleCommandNavigation)
mod.exports.gen2BattleCommandNavigation = Gen2BattleCommandNavigation
mod.exports.gen2BattleCommandNavigationInstalled =
  gen2BattleCommandNavigationInstalled
mod.exports.gen2BattleCommandNavigationError =
  gen2BattleCommandNavigationError
if gen2BattleCommandNavigationInstalled then
  mod.log:info("Johto ORAS battle command navigation connected to Crystal BattleState")
end

-- Optional native Gen-2 KASC capability. Install outside the spatial cursor
-- adapter; the extra chip never becomes an invented native menu index.
local Gen2MegaBridge = safeLoadLocal(
  "Johto conditional KASC Mega command", "lib/Gen2MegaBridge.lua", V)
mod.exports.gen2MegaBridgeInstalled, mod.exports.gen2MegaBridgeError =
  safeInstall("Johto conditional KASC Mega command", Gen2MegaBridge,
    { flip=AndroidFullFrameFlip })
if mod.exports.gen2MegaBridgeInstalled then V.Gen2MegaBridge = Gen2MegaBridge end

-- The native 48px Crystal HP chase looks stepped on the much wider ORAS HUD.
-- Retain BattleState's single hpAnim/queue owner and adapt only its visual
-- increment while the VASC battle controller owns an ordinary encounter.
local Gen2BattleHpPresentation = safeLoadLocal(
  "Johto ORAS battle HP presentation",
  "lib/Gen2BattleHpPresentation.lua", V)
local gen2BattleHpPresentationInstalled,
  gen2BattleHpPresentationError = safeInstall(
    "Johto ORAS battle HP presentation", Gen2BattleHpPresentation)
mod.exports.gen2BattleHpPresentation = Gen2BattleHpPresentation
mod.exports.gen2BattleHpPresentationInstalled =
  gen2BattleHpPresentationInstalled
mod.exports.gen2BattleHpPresentationError = gen2BattleHpPresentationError
if gen2BattleHpPresentationInstalled then
  mod.log:info("Johto ORAS battle HP chase connected to Crystal BattleState")
end

-- Phase 2 + Phase 3 + Phase 4 battle effects: common elemental families, dedicated
-- signature-move renderers, and safe visual hit-stop/shake/impact polish
-- drawn on the recomp engine's own move-animation layer. Dramatic Shape already maps
-- that layer onto the 3D arena, so this does not touch battle model lifecycle.
local BattleStadiumEffects = safeLoadLocal("Pokemon Stadium Phase 2 + Phase 3 + Phase 4 battle presentation", "lib/BattleStadiumEffects.lua", V)
local battleEffectsInstalled, battleEffectsErr =
  safeInstall("Pokemon Stadium Phase 2 + Phase 3 + Phase 4 battle presentation",
    BattleStadiumEffects)
if battleEffectsInstalled then
  mod.log:info("Pokemon Stadium Phase 2 + Phase 3 + Phase 4 battle presentation enabled")
end

-- Phase 5: real world-space procedural effects. This wraps Dramatic Shape's
-- exported Stadium begin/update/draw functions, so the particles are drawn
-- inside the active Voxel3D scene and follow camera orbit/depth naturally.
local BattleStadium3DFx = safeLoadLocal("Pokemon Stadium Phase 5 world-space effects", "lib/BattleStadium3DFx.lua", V)
local battle3DInstalled, battle3DErr =
  safeInstall("Pokemon Stadium Phase 5 world-space effects", BattleStadium3DFx)
if battle3DInstalled then
  mod.log:info("Pokemon Stadium Phase 5 world-space battle effects enabled")
end

local function gen2AnimationStatus()
  local receipt = BattleAnimationCompat.status()
  local coverage = type(BattleStadium3DFx.coverage) == "function"
    and BattleStadium3DFx.coverage() or {}
  if not receipt.installed then
    return {
      right="PENDING",
      help={
        en="The shared VASC animation catalog is waiting for Crystal battle data ("
          .. tostring(receipt.reason or "game data") .. ").",
        de="Der gemeinsame VASC-Animationskatalog wartet auf die geladenen Crystal-Kampfdaten ("
          .. tostring(receipt.reason or "game data") .. ").",
      },
    }
  end
  local authored = (tonumber(receipt.gen1) or 0)
    + (tonumber(receipt.postGen) or 0)
  local valid = receipt.catalogValid == true
    and tonumber(receipt.invalidSheets or 0) == 0
    and tonumber(receipt.invalidPrograms or 0) == 0
  return {
    right=(coverage.complete and "251/251" or tostring(
      coverage.reviewedMoves or 0) .. "/251"),
    help={
      en=("Johto: %d reviewed move routes with smart user/target anchors; "
        .. "%d VASC HD programs from the shared Kanto catalog. "
        .. "Catalog check: %s (%d sheets, %d frames, %d invalid). "
        .. "An individual missing frame falls back to the native Crystal animation.")
        :format(tonumber(coverage.reviewedMoves) or 0, authored,
          valid and ((tonumber(receipt.invalidFrames) or 0) == 0
            and "OK" or "OK / QUARANTINED") or "ERROR",
          tonumber(receipt.sheets) or 0,
          tonumber(receipt.frames) or 0,
          (tonumber(receipt.invalidSheets) or 0)
            + (tonumber(receipt.invalidPrograms) or 0)
            + (tonumber(receipt.invalidFrames) or 0)),
      de=("Johto: %d geprüfte Attackenrouten mit smarten Anwender-/Zielankern; "
      .. "%d VASC-HD-Programme aus dem gemeinsamen Kanto-Katalog. "
      .. "Katalogprüfung: %s (%d Sheets, %d Frames, %d ungültig). "
      .. "Ein einzelner fehlender Frame fällt auf die native Crystal-Animation zurück.")
      :format(tonumber(coverage.reviewedMoves) or 0, authored,
        valid and ((tonumber(receipt.invalidFrames) or 0) == 0
          and "OK" or "OK / QUARANTÄNE") or "FEHLER",
        tonumber(receipt.sheets) or 0,
        tonumber(receipt.frames) or 0,
        (tonumber(receipt.invalidSheets) or 0)
          + (tonumber(receipt.invalidPrograms) or 0)
          + (tonumber(receipt.invalidFrames) or 0)),
    },
  }
end

-- Patch only structural seams in the exact VoxelScene source from the installed
-- Dramatic Shape build. Stadium operations are isolated per Pokemon, so one
-- bad model falls back to its own sprite without disabling the full overlay.
local VoxelScenePatch = loadLocal("lib/VoxelScenePatch.lua", V)
local rendererInstalled, rendererErr = VoxelScenePatch.install(ds, BaseV, V, Stadium)
if rendererInstalled then
  mod.log:info("Pokemon Stadium overworld renderer installed on current Dramatic Shape VoxelScene")
else
  mod.log:warn("Stadium overworld renderer not installed; Dramatic Shape voxel renderer preserved: %s",
               tostring(rendererErr))
end

-- Standalone roaming Pokemon.  Always boot the embedded, Gen-2-patched Wilds
-- runtime.  Do not let a separately installed Gen-1 Wilds build hijack this
-- package: independence means Gold uses the copy that was actually ported for
-- morning/day/night encounters and the Gen-2 world facade.
local wildsExports, wildsSource, wildsErr
wildsExports, wildsErr = bootEmbeddedWilds()
if wildsExports then
  wildsSource = "embedded"
  mod.log:info("Embedded Wilds of Kanto 1.12.2 Gen-2 roaming spawn runtime enabled")
else
  wildsSource = "failed"
  mod.log:warn("Embedded Wilds roaming spawn runtime failed; Stadium renderer remains available: %s",
               tostring(wildsErr))
end

-- One self-contained FireRed/LeafGreen Voxel Ascendant control centre. Gen 2's
-- START menu remains native and receives exactly one extra row after OPTION;
-- all VASC controls live below it in eight clean sections. Load VascMenu and
-- its style through BaseV so user-content screens resolve the same controller
-- instance when they ask V.require("VascMenu") for decoration.
local function menuModule(name)
  local ok, value = pcall(BaseV.require, name)
  if ok and type(value) == "table" then return value end
  mod.log:warn("Voxel Ascendant menu dependency %s unavailable: %s",
    tostring(name), tostring(value))
  return nil
end

local VascMenu = menuModule("VascMenu")
local VascMenuStyle = menuModule("VascMenuStyle")
local FieldKitPresentation = menuModule("FieldKitPresentation")
safeInstall("Gen-2 fullscreen Field Kit", FieldKitPresentation)
local VascModSetting = menuModule("ModSetting")
local environmentModules = (VascEnvironment and VascEnvironment.modules) or {}
local VascMenuGen2 = safeLoadLocal(
  "Gen-2 Voxel Ascendant menu", "lib/VascMenuGen2.lua", {
    mod = mod,
    V = BaseV,
    Menu = VascMenu,
    Style = VascMenuStyle,
    ModSetting = VascModSetting,
    RomMenu = StadiumRomMenu,
    RendererOptions = VascRendererOptions,
    PipelineBridge = GoldPipelineBridge,
    VoxelBridge = GoldVoxelBridge,
    SpritePacks = environmentModules.SpritePacks,
    LocalMusic = environmentModules.LocalMusic,
    LocalSprites = environmentModules.LocalSprites,
    LocalContent = environmentModules.LocalContent,
    Diagnostics = Diagnostics,
    PerformanceDiagnostics = PerformanceDiagnostics,
    MobileDiagnostic = MobileDiagnostic,
    version = VERSION,
    schema = mod._vascGen2Schema,
    onChanged = wildsExports and wildsExports.handleOptionsChanged,
  })
local vascMenuInstalled, vascMenuErr =
  safeInstall("Gen-2 Voxel Ascendant menu", VascMenuGen2, {
    version = VERSION,
    Diagnostics = Diagnostics,
    PerformanceDiagnostics = PerformanceDiagnostics,
    mobileDiagnostic = MobileDiagnostic,
    prominentMobileTrace = false,
    animationStatus = gen2AnimationStatus,
  })
if vascMenuInstalled then
  mod.log:info("Native Gen-2 START semantics + shared FireRed Voxel Ascendant hub enabled")
end
if Diagnostics and type(Diagnostics.boot) == "function" then
  if mod.events and type(mod.events.on) == "function" then
    local function bootSavedDiagnostics(payload)
      local game = type(payload) == "table" and (payload.game or payload) or nil
      pcall(Diagnostics.boot, game)
    end
    mod.events:on("save.loaded", bootSavedDiagnostics)
    mod.events:on("game.ready", bootSavedDiagnostics)
  end
end

-- v0.2.12: hold-to-aim overworld Poké Ball throw. Normal roaming-Pokemon
-- contact keeps Wilds' ordinary Gold battle path. While free-roaming the
-- capture module polls Gold's fixed-step input seam, so L2 / right mouse can
-- target a visible Pokemon in the camera cone and immediately throw before
-- contact. Any supported Gold Ball can be used; if prerequisites are missing,
-- the original Gold battle path remains unchanged.
local OverworldCapture, overworldCaptureInstalled, overworldCaptureErr
local ENABLE_OVERWORLD_CAPTURE_RC = false
if ENABLE_OVERWORLD_CAPTURE_RC then
  local okCapture, captureOrErr = pcall(BaseV.require, "OverworldCapture")
  if okCapture and type(captureOrErr) == "table" then
    OverworldCapture = captureOrErr
    if wildsExports and type(wildsExports.logic) == "table"
       and type(OverworldCapture.install) == "function" then
      local okInstall, installed, err = pcall(OverworldCapture.install, wildsExports.logic)
      overworldCaptureInstalled = okInstall and installed ~= false
      if not overworldCaptureInstalled then
        overworldCaptureErr = tostring(okInstall and err or installed)
      end
    else
      overworldCaptureInstalled = false
      overworldCaptureErr = "visible Wilds runtime unavailable"
    end
  else
    overworldCaptureInstalled = false
    overworldCaptureErr = tostring(captureOrErr)
  end
else
  overworldCaptureInstalled = false
  overworldCaptureErr = "disabled in 3.0 RC pending Gold/Silver/Crystal ROM QA"
end
if overworldCaptureInstalled then
  do
  local st = OverworldCapture and OverworldCapture.status and OverworldCapture.status() or {}
  mod.log:info("Overworld capture enabled (direct=%s manual=%s)",
               tostring(st.directHookInstalled), tostring(st.manualHookInstalled))
end
else
  mod.log:warn("Overworld capture minigame unavailable; normal battles preserved: %s",
               tostring(overworldCaptureErr))
end

-- Visible roaming Pokemon provider/fallback drawer.  This no longer patches
-- World:drawPeople; it stays independent from voxel and is consumed by the
-- supported Gold render.compose bridge below.
local GoldWildsBridge, goldWildsBridgeErr
if wildsExports then
  local source, readErr = mod:read("lib/GoldWildsBridge.lua")
  if source then
    local loadcode = loadstring or load
    local chunk, compileErr = loadcode(source,
      "@" .. mod.path .. "/lib/GoldWildsBridge.lua")
    if chunk then
      local okLoad, bridgeOrErr = pcall(chunk, mod, wildsExports)
      if okLoad and type(bridgeOrErr) == "table" then
        GoldWildsBridge = bridgeOrErr
        local okInstall, installErr = GoldWildsBridge.install()
        if not okInstall then
          goldWildsBridgeErr = tostring(installErr)
          GoldWildsBridge = nil
        end
      else
        goldWildsBridgeErr = tostring(bridgeOrErr)
      end
    else
      goldWildsBridgeErr = tostring(compileErr)
    end
  else
    goldWildsBridgeErr = tostring(readErr)
  end
  if GoldWildsBridge then
    mod.log:info("Gold visible-Wilds provider/fallback renderer ready")
  else
    mod.log:warn("Gold visible-Wilds provider failed: %s",
                 tostring(goldWildsBridgeErr))
  end
end

-- Feed the same visible roaming-Pokemon set into the voxel scene.  The Stadium
-- VoxelScene overlay can then replace those entities with their imported
-- Stadium 2 models; if voxel fails, GoldComposeBridge still draws their sprites.
if GoldVoxelBridge and GoldWildsBridge
   and type(GoldVoxelBridge.setExtraEntitiesProvider) == "function"
   and type(GoldWildsBridge.visibleEntities) == "function" then
  local okProvider, providerErr = GoldVoxelBridge.setExtraEntitiesProvider(function(world)
    return GoldWildsBridge.visibleEntities(world)
  end)
  if okProvider then
    mod.log:info("Gold visible-Wilds entities bridged into voxel/Stadium scene")
  else
    mod.log:warn("Gold Wilds voxel entity bridge failed: %s", tostring(providerErr))
  end
end

-- Gold compose fallback/coexistence path. Current Gold normally reaches voxels
-- earlier through GoldPipelineBridge/render_pipelines.drawWorld. Older hosts,
-- and installations with red_3d_player (whose own public `voxel` pipeline must
-- remain untouched), deliberately render here instead. When voxel is unavailable,
-- the already-drawn Gold scene is preserved.
local GoldComposeBridge, goldComposeBridgeErr
do
  local source, readErr = mod:read("lib/GoldComposeBridge.lua")
  if source then
    local loadcode = loadstring or load
    local chunk, compileErr = loadcode(source,
      "@" .. mod.path .. "/lib/GoldComposeBridge.lua")
    if chunk then
      local okLoad, bridgeOrErr = pcall(chunk, mod, GoldVoxelBridge, GoldWildsBridge, GoldPipelineBridge)
      if okLoad and type(bridgeOrErr) == "table" then
        GoldComposeBridge = bridgeOrErr
        local okInstall, installErr = GoldComposeBridge.install()
        if not okInstall then
          goldComposeBridgeErr = tostring(installErr)
          GoldComposeBridge = nil
        end
      else
        goldComposeBridgeErr = tostring(bridgeOrErr)
      end
    else
      goldComposeBridgeErr = tostring(compileErr)
    end
  else
    goldComposeBridgeErr = tostring(readErr)
  end
end
if GoldComposeBridge then
  if GoldVoxelBridge and type(GoldVoxelBridge.setBattleCompositorReady) == "function" then
    pcall(GoldVoxelBridge.setBattleCompositorReady, false)
  end
  mod.log:info("Gold render.compose integration installed; battle mode waits for a live compose heartbeat")
else
  if GoldVoxelBridge and type(GoldVoxelBridge.setBattleCompositorReady) == "function" then
    pcall(GoldVoxelBridge.setBattleCompositorReady, false)
  end
  mod.log:error("Gold render.compose integration failed: %s",
                tostring(goldComposeBridgeErr))
end

-- `game.ready` happens before a new Gold World necessarily exists, while
-- `map.entered` happens after the live map/people are built.  The embedded
-- Wilds event listener normally initializes there, but this idempotent repair
-- makes a current map visible even if event ordering differs across builds or
-- after a save reload.
local function ensureWildsCurrentMap(ev)
  if not (wildsExports and type(wildsExports.logic) == "table") then return end
  local worldApi = mod.world
  local ow = worldApi and worldApi.overworld and worldApi:overworld()
  local map = ow and ow.map
  local mapId = (ev and ev.mapId) or (map and map.id)
  if not mapId then return end

  local logic = wildsExports.logic
  local initialized = logic.state and logic.state.initialized == true
  if logic.activeMapId == mapId and initialized then return end
  if type(logic.onMapEntered) ~= "function" then return end

  local ok, err = pcall(logic.onMapEntered, logic, {
    mapId = mapId, map = map, via = "stadium2_gen2_bootstrap",
  })
  if not ok then
    mod.log:warn("Gold visible-Wilds map bootstrap failed: %s", tostring(err))
  end
end

mod.events:on("map.entered", ensureWildsCurrentMap)
mod.events:on("save.loaded", ensureWildsCurrentMap)
mod.events:on("game.ready", ensureWildsCurrentMap)
pcall(ensureWildsCurrentMap)

-- Gold/Silver can change land encounter slots with time of day. Rebuild the
-- embedded Wilds population when the engine announces a TOD transition so the
-- visible roster stays in lockstep with vanilla encounters.
if wildsExports and type(wildsExports.logic) == "table" then
  mod.events:on("world.tod_changed", function(ev)
    local logic = wildsExports.logic
    local world = mod.world
    local ow = world and world.overworld and world:overworld()
    local mapId = (ev and ev.mapId) or (ow and ow.map and ow.map.id)
    if mapId and logic.activeMapId == mapId
       and type(logic.onMapReloaded) == "function" then
      local okReload, reloadErr = pcall(logic.onMapReloaded, logic, { mapId = mapId })
      if not okReload then
        mod.log:warn("Wilds time-of-day refresh failed: %s", tostring(reloadErr))
      end
    end
  end)
end

-- Companion mods can tag a Pokemon entity explicitly through this mod.
mod.exports.version = VERSION
mod.exports.diagnostics = Diagnostics
mod.exports.performanceDiagnostics = PerformanceDiagnostics
mod.exports.diagnosticsCode = Diagnostics and Diagnostics.CODE
mod.exports.diagnosticsFile = Diagnostics and Diagnostics.FILE
mod.exports.diagnosticsReady = Diagnostics ~= nil
  and type(Diagnostics.setEnabled) == "function"
  and type(Diagnostics.write) == "function"
mod.exports.pokemonUi = PokemonUi and PokemonUi.public() or nil
mod.exports.pokemonUiProviderInstalled = pokemonUiProviderInstalled
mod.exports.pokemonUiProviderError = pokemonUiProviderError
mod.exports.pauseMenuBattleStyle = PauseMenuBattleStyle
mod.exports.titleMenuVascStyle = TitleMenuVascStyle
mod.exports.titleMenuVascStyleStatus = function()
  return TitleMenuVascStyle and TitleMenuVascStyle.status
    and TitleMenuVascStyle.status() or {
      installed=false, error=titleMenuStyleErr,
    }
end
mod.exports.goldSubmenuBattleStyle = GoldSubmenuBattleStyle
mod.exports.sharedMenuPresentation = SharedVascMenuPresentation
mod.exports.sharedMenuPresentationInstalled = sharedMenuInstalled == true
mod.exports.sharedMenuPresentationError = sharedMenuErr
mod.exports.sharedMenuPresentationStatus = function()
  return SharedVascMenuPresentation and SharedVascMenuPresentation.status
    and SharedVascMenuPresentation.status() or {
      installed=false, error=sharedMenuErr,
    }
end
mod.exports.textBoxBattleStyle = TextBoxBattleStyle
mod.exports.textBoxBattleStyleStatus = function()
  return TextBoxBattleStyle and TextBoxBattleStyle.status and TextBoxBattleStyle.status() or {
    installed = false, error = textBoxStyleErr,
  }
end
mod.exports.openWorldZoom = OpenWorldZoom
mod.exports.openWorldZoomStatus = function()
  return OpenWorldZoom and OpenWorldZoom.status and OpenWorldZoom.status() or {
    installed = false, error = openWorldZoomErr,
  }
end
mod.exports.overworld = Stadium
mod.exports.modelsEnabled = BaseV.modelsEnabled
-- Read-only, per-species readiness for the integrated visual-source policy.
-- A generic "supports Stadium" flag cannot prove a ROM/model is installed.
mod.exports.overworldPokemonModelAvailable = function(dex)
  dex = tonumber(dex)
  if not dex or dex ~= math.floor(dex) or dex < 1 or dex > 251
      or not Config.enabled or not BaseV.modelsEnabled() then return false end
  return BaseV.require("StadiumPack").load(dex) ~= nil
end
local PokemonModelProvider = BaseV.require("PokemonModelProvider")
mod.exports.pokemonModelProvider = PokemonModelProvider.public()
mod.exports.red3dPlayerCompat = true
mod.exports.red3dPlayerCompatStatus = function()
  local selector = mod.find and mod.find("red_3d_player") or nil
  local okPlayer, Player = pcall(require, "src.world.gen2.Player")
  local renderer = okPlayer and type(Player) == "table" and Player.red3dPlayerRenderer or nil
  local camera = GoldVoxelBridge and GoldVoxelBridge.status and GoldVoxelBridge.status() or nil
  return {
    selectorDetected = selector ~= nil,
    rendererReady = type(renderer) == "table" and type(renderer.drawVoxel) == "function",
    activeId = type(renderer) == "table" and renderer.activeId or nil,
    cameraProvider = camera and camera.cameraProvider or nil,
    externalCameraLabel = camera and camera.externalCameraLabel or nil,
    externalCameraLevel = camera and camera.externalCameraLevel or nil,
  }
end
mod.exports.romMenu = StadiumRomMenu
mod.exports.modOptionsBattleStyle = ModMenuBattleStyle
mod.exports.modMenuBattleStyle = ModMenuBattleStyle
mod.exports.directModSettingsMenu = DirectModSettingsMenu
mod.exports.modSettingsPersistence = ModSettingsPersistence
mod.exports.categorizedModSettings = CategorizedModSettings
mod.exports.vascMenu = VascMenu
mod.exports.vascMenuStyle = VascMenuStyle
mod.exports.vascMenuGen2 = VascMenuGen2
mod.exports.vascMenuInstalled = vascMenuInstalled == true
mod.exports.vascMenuError = vascMenuErr
mod.exports.vascMenuStatus = function()
  return VascMenuGen2 and VascMenuGen2.status and VascMenuGen2.status() or {
    installed = false, lastError = vascMenuErr,
  }
end
mod.exports.johtoUi = {
  apiVersion = 1,
  standardOwner = "ascendant-oras",
  nativeFallbackOwner = "engine-native",
  startMenuContribution = "ASCENDANT",
  hubTitle = "ASCENDANT",
  hubOwner = "VascMenuGen2",
  hubStyle = "firered-ascendant",
  nativeSkin = "oras-glass",
  nativeSkinOption = "qol_ui_skin",
  partySkinOption = "pokemonUiPartyMenu",
  battlePartySkinOption = "pokemonUiBattleParty",
  battleHudOwner = "voxel-ascendant",
  battleHudFallbackOwner = "engine-native",
  battleHudStyle = "oras-glass",
  battleHudOption = "battleHudStyle",
  orasHudEnabled = true,
  legacyHudEnabled = false,
}
mod.exports.orasUiSkin = orasUiSkinInstalled and OrasUiSkin or nil
mod.exports.orasUiSkinInstalled = orasUiSkinInstalled == true
mod.exports.orasUiSkinError = orasUiSkinErr
mod.exports.androidFullFrameFlip = AndroidFullFrameFlip
mod.exports.vascRendererOptions = VascRendererOptions
mod.exports.vascRendererOptionsStatus = function()
  return VascRendererOptions and VascRendererOptions.status
    and VascRendererOptions.status() or {
      installed = false, error = rendererOptionsErr,
    }
end
mod.exports.vascEnvironment = VascEnvironment
mod.exports.vascEnvironmentInstalled = vascEnvironmentInstalled == true
mod.exports.vascEnvironmentError = vascEnvironmentErr
mod.exports.vascEnvironmentStatus = function()
  return VascEnvironment and VascEnvironment.status
    and VascEnvironment.status() or nil
end
mod.exports.gen2BattleCardsInstalled = gen2BattleCardsInstalled == true
mod.exports.gen2BattleCardsError = gen2BattleCardsErr
mod.exports.gen2BattleCardsStatus = function()
  return Gen2BattleCardHost and type(Gen2BattleCardHost.status) == "function"
    and Gen2BattleCardHost.status() or {
      ok=false, fallbackSafe=true, error=gen2BattleCardsErr,
    }
end
mod.exports.categorizedModSettingsStatus = function()
  return CategorizedModSettings and CategorizedModSettings.status and CategorizedModSettings.status() or nil
end
mod.exports.androidFullFrameFlipStatus = function()
  return AndroidFullFrameFlip and AndroidFullFrameFlip.status and AndroidFullFrameFlip.status() or nil
end
mod.exports.shortcutToastInstalled = shortcutToastInstalled == true
mod.exports.shortcutToastError = shortcutToastErr
mod.exports.shortcutToastStatus = function()
  return ShortcutToast and ShortcutToast.status and ShortcutToast.status() or nil
end
mod.exports.chooseStadiumRom = function(game)
  if game then return StadiumRomMenu.choose(game) end
  local okGame2, Game2 = pcall(require, "src.core.Game2")
  return StadiumRomMenu.choose(okGame2 and Game2 or nil)
end
mod.exports.tag = function(entity, speciesOrDex)
  return Stadium.tag(entity, speciesOrDex)
end
mod.exports.untag = function(entity)
  return Stadium.untag(entity)
end

mod.exports.active = true
mod.exports.hostDetected = true
mod.exports.hostId = dramaticShapeId
mod.exports.generation = gameGeneration()
mod.exports.gen2Compatible = true
mod.exports.targetGeneration = 2
mod.exports.stadium2Importer = true
mod.exports.standaloneRenderer = true
mod.exports.maxDex = 251
mod.exports.rendererInstalled = rendererInstalled
mod.exports.rendererError = rendererErr
mod.exports.voxelHostId = dramaticShapeId
mod.exports.voxelHostGeneration = 2
mod.exports.voxelPipelineState = voxelPipelineState
mod.exports.voxelDirectWorldHook = goldPipelineInstalled == true
mod.exports.voxelComposeHook = GoldComposeBridge ~= nil
-- Legacy default target remains FULL/diorama level 1. v0.1.89 can select the
-- live first/third-person levels through GoldVoxelBridge without changing this
-- compatibility value expected by older diagnostics.
mod.exports.voxelTargetLevel = 1
mod.exports.voxelStatus = function()
  return GoldVoxelBridge and GoldVoxelBridge.status and GoldVoxelBridge.status() or nil
end
mod.exports.voxelCameraMode = function()
  local status = GoldVoxelBridge and GoldVoxelBridge.status and GoldVoxelBridge.status() or nil
  return status and status.cameraMode or "full"
end
mod.exports.voxelCameraLevel = function()
  local status = GoldVoxelBridge and GoldVoxelBridge.status and GoldVoxelBridge.status() or nil
  return status and status.cameraLevel or 1
end
mod.exports.cycleVoxelCamera = function()
  if GoldVoxelBridge and type(GoldVoxelBridge.cycleCameraMode) == "function" then
    return GoldVoxelBridge.cycleCameraMode(true)
  end
  return nil
end
mod.exports.partyFollower = GoldPartyFollower
mod.exports.partyFollowerStatus = function()
  return GoldPartyFollower and GoldPartyFollower.status and GoldPartyFollower.status() or {
    installed = false,
    error = goldPartyFollowerErr,
  }
end
mod.exports.inWorld3DBattles = true
mod.exports.inWorld3DBattleStatus = function()
  local voxel = GoldVoxelBridge and GoldVoxelBridge.status and GoldVoxelBridge.status() or nil
  local compose = GoldComposeBridge and GoldComposeBridge.status and GoldComposeBridge.status() or nil
  return {
    installed = voxel and voxel.battleInstalled or false,
    active = voxel and voxel.battleActive or false,
    error = (voxel and voxel.battleError) or (compose and compose.lastBattleError) or nil,
    frames = compose and compose.battleFrames or 0,
    fallbacks = compose and compose.battleFallbackFrames or 0,
  }
end
mod.exports.battlePokemonControl = BattlePokemonControl
mod.exports.battlePokemonControlStatus = function()
  local status = BattlePokemonControl and BattlePokemonControl.status
    and BattlePokemonControl.status() or {}
  status.installed = battlePokemonControlInstalled
  status.error = battlePokemonControlErr
  return status
end
mod.exports.battleControllerUI = BattleControllerUI
mod.exports.battleControllerUIStatus = function()
  return BattleControllerUI and BattleControllerUI.status and BattleControllerUI.status() or nil
end
-- Re-publish after the embedded Wilds export transaction so live QA reads the
-- exact hook instance that survived the complete Gen-2 boot.
mod.exports.battleMoveGridNavigationInstalled =
  battleMoveGridNavigationInstalled
mod.exports.battleMoveGridNavigationError = battleMoveGridNavigationError
mod.exports.battleAnimationsInstalled = battleAnimationsInstalled
mod.exports.battleAnimationsError = battleAnimationsErr
-- Exact private-instance receipt for the logger and live QA.  Going through a
-- generic module loader here can observe a hot-reload cache generation rather
-- than the instance that patched AnimPlayer.new.
mod.exports.gen2BattleAnimationStatus = function()
  return BattleAnimationCompat.status()
end
mod.exports.battleEffectsInstalled = battleEffectsInstalled
mod.exports.battleEffectsError = battleEffectsErr

mod.exports.battle3DInstalled = battle3DInstalled
mod.exports.battle3DError = battle3DErr
mod.exports.lib = BaseV
mod.exports.wilds = wildsExports
mod.exports.overworldCaptureInstalled = overworldCaptureInstalled
mod.exports.overworldCaptureError = overworldCaptureErr
mod.exports.overworldCaptureStatus = function()
  return OverworldCapture and OverworldCapture.status and OverworldCapture.status() or {
    installed = false, error = overworldCaptureErr,
  }
end
mod.exports.wildSpawnsInstalled = wildsExports ~= nil
mod.exports.wildSpawnsSource = wildsSource
mod.exports.wildSpawnsError = wildsErr
mod.exports.goldWildsDrawBridgeInstalled = GoldWildsBridge ~= nil
mod.exports.goldWildsDrawBridgeError = goldWildsBridgeErr
mod.exports.goldWildsDrawBridgeStatus = function()
  return GoldWildsBridge and GoldWildsBridge.status and GoldWildsBridge.status() or nil
end
mod.exports.goldPipelineBridge = GoldPipelineBridge
mod.exports.goldPipelineBridgeInstalled = goldPipelineInstalled == true
mod.exports.goldPipelineBridgeError = goldPipelineErr
mod.exports.goldPipelineBridgeStatus = function()
  return GoldPipelineBridge and GoldPipelineBridge.status and GoldPipelineBridge.status() or nil
end
mod.exports.goldComposeBridgeInstalled = GoldComposeBridge ~= nil
mod.exports.goldComposeBridgeError = goldComposeBridgeErr
mod.exports.goldComposeBridgeStatus = function()
  return GoldComposeBridge and GoldComposeBridge.status and GoldComposeBridge.status() or nil
end
mod.exports.visibleWildsForced = true
mod.exports.entryCompleted = true

-- Finish with the owner-isolated VASC public surface. All historical
-- Gen2-3D-Sprites exports above remain available, while `lib` becomes a
-- read-only allowlist instead of exposing this mod's private loader.
local Gen2PublicExports = loadLocal("lib/Gen2PublicExports.lua", {
  mod = mod,
  BaseV = BaseV,
  version = VERSION,
  upstreamVersion = "0.2.81",
  HudTheme = AscendantHudTheme,
})
Gen2PublicExports.apply(mod.exports)
