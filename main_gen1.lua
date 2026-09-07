-- Voxel Ascendant: a standalone Gen1Recomp voxel-world renderer.
--
-- This fork starts at the MIT-licensed DramaticShapeVoxelMod v1.6.1 tag.
-- VR, Stadium ROM/model support and Horde mode are intentionally absent.
--
-- The engine's render_pipelines registry (src/mods/Schemas.lua) lets a mod
-- own part of the frame.  This mod registers two:
--
--   voxel      a drawWorld pipeline.  Instead of the flat tile blit, the
--              overworld's terrain is extruded into real geometry, walked
--              by a depth-buffered 3D camera, with characters as leaning
--              sprite slabs and a shadow map throwing real cast shadows
--              across whatever they land on.  Occlusion is the depth
--              buffer, not a y-sort: walk behind a building and the
--              building is simply in front.
--
--   tiltshift  a worldPresent pipeline -- the stage that post-processes
--              the finished world BEFORE the UI composites over it.  A
--              tilt-shift blur that sells the miniature-model look, on the
--              diorama only, leaving text boxes and menus crisp.
--
-- Everything a display mode needs beyond the two draw functions -- the
-- OFF/15/35/50 ladder, the options rows, the hotkeys, persistence in
-- save.options.pipelines, the free-roam gate, the mutual exclusion with
-- the engine's TILT mode -- is engine plumbing driven by the records
-- below.  This file declares; lib/ draws.
--
-- Orbit rungs remain purely presentational. 1ST and 3RD attach the camera to
-- the player and use camera-relative free movement while reusing the engine's
-- own collision, cell-arrival, encounter, warp and scripted-move paths.

local mod = ...
local PACKAGE_VERSION = mod._vascPackageVersion or mod.version
  or (mod.exports and mod.exports.packageVersion)
assert(type(PACKAGE_VERSION) == "string" and PACKAGE_VERSION ~= "",
  "VOXEL_ASCENDANT: package version was not supplied by the dispatcher")

local MobileDiagnostic = mod._vascMobileDiagnostic
do
  local active = false
  if type(MobileDiagnostic) == "table"
      and type(MobileDiagnostic.active) == "function" then
    local ok, value = pcall(MobileDiagnostic.active)
    active = ok and value == true
  end
  if not active then MobileDiagnostic = nil end
end

local function mobileDiagnostic(name, ...)
  local fn = MobileDiagnostic and MobileDiagnostic[name]
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c = pcall(fn, ...)
  if ok then return a, b, c end
  return nil
end

local unpackValues = table.unpack or unpack
local function packValues(...)
  return { n = select("#", ...), ... }
end

-- ------- the mod namespace
--
-- lib/ modules require each other through V rather than package.path: a
-- mod directory is not on it, and may live inside a mounted .love archive
-- that plain require cannot reach.  Each module is loaded once, with V
-- passed in as its vararg (`local V = ...`).

local V = {
  mod = mod,
  path = mod.path,
  -- Gen 1 deliberately reuses only the audited, generation-neutral Stadium-2
  -- import/model modules. Ordinary Gen-2 gameplay stays behind gen2/main.lua.
  stadium2ForGen1 = true,
}

local GEN1_STADIUM2_MODULES = {
  -- Shared by every Stadium-2 import/cache module below.  It intentionally
  -- lives with the audited Gen-2 importer sources; without this entry the
  -- Gen-1 loader falls through to the nonexistent lib/EngineCompat.lua and
  -- the whole package is rejected by the mod manager during startup.
  EngineCompat=true,
  BattleEffectAnchors=true,
  PokemonModelProvider=true,
  Stadium=true,
  StadiumBuild=true,
  StadiumFragment=true,
  StadiumFx=true,
  StadiumInstall=true,
  StadiumMon=true,
  StadiumPack=true,
  StadiumRig=true,
  StadiumRom=true,
  StadiumRom2=true,
  StadiumRomMenu=true,
  StadiumRomPick=true,
  StadiumScreen=true,
  StadiumStage=true,
  LugiaGeoDump=true,
  LugiaRescue=true,
}

-- ASC BOX uses German labels even without a translation package. Register
-- only still-missing glyphs from VASC's original, ROM-independent 8x8 page;
-- an installed translation keeps precedence for every row it already owns.
do
  local font = mod.content and mod.content.font
  if font and type(font.get) == "function" and type(font.register) == "function" then
    local base = 0x5600
    local glyphs = { "Ä", "Ö", "Ü", "ä", "ö", "ü", "ß" }
    local charmap = {}
    for index, seq in ipairs(glyphs) do
      if font:get("charmap:" .. seq) == nil then
        charmap[#charmap + 1] = { seq=seq, code=base + index - 1 }
      end
    end
    if #charmap > 0 then
      font:register("vasc_asc_box_de_umlauts", {
        image=mod.assets:path("assets/ui/font_de_umlauts.png"),
        base=base, glyphsPerRow=#glyphs, advance=8, charmap=charmap,
      })
    end
  end
end

local function chunkFor(rel)
  local source = mod:read(rel)
  if not source then
    error(("VOXEL_ASCENDANT: %s is missing -- reinstall the mod"):format(rel), 0)
  end
  local chunk, err = load(source, "@" .. mod.path .. "/" .. rel)
  if not chunk then
    error(("VOXEL_ASCENDANT: %s did not compile: %s"):format(rel, tostring(err)), 0)
  end
  return chunk
end

local modules = {}
function V.require(name)
  local hit = modules[name]
  if hit ~= nil then return hit end
  local rel = GEN1_STADIUM2_MODULES[name]
    and ("gen2/lib/" .. name .. ".lua")
    or ("lib/" .. name .. ".lua")
  local value = chunkFor(rel)(V)
  modules[name] = value
  return value
end

local dataFiles = {}
function V.data(name)
  local hit = dataFiles[name]
  if hit ~= nil then return hit end
  local value = chunkFor("data/" .. name .. ".lua")(V)
  dataFiles[name] = value
  return value
end

-- Generated editor data is normally immutable for the lifetime of a mod
-- loader, but the native scenery editor can deliberately replace its one
-- generated module in an unpacked development install.  Keep cache eviction
-- narrow and explicit; ordinary data files retain the load-once contract.
function V.invalidateData(name)
  if type(name) ~= "string" or name == "" then return false end
  local present = dataFiles[name] ~= nil
  dataFiles[name] = nil
  return present
end

-- Read a prospective generated revision without disturbing the committed
-- load-once cache.  The scenery runtime validates this value first and calls
-- commitData only after the complete overlay is ready, so a half-written Lua
-- file cannot evict the last known-good document.
function V.readDataFresh(name)
  if type(name) ~= "string" or name == "" then
    error("VOXEL_ASCENDANT: a data name is required", 0)
  end
  return chunkFor("data/" .. name .. ".lua")(V)
end

function V.commitData(name, value)
  if type(name) ~= "string" or name == "" or value == nil then return false end
  dataFiles[name] = value
  return true
end

-- Arm the persistent trace before any renderer sibling is evaluated. If a
-- mobile driver hangs during an eager capability check, its preceding START
-- marker must already be on disk rather than buffered in RAM.
local Diagnostics = V.require("Diagnostics")
Diagnostics.boot()
local PerformanceDiagnostics = V.require("PerformanceDiagnostics")
if PerformanceDiagnostics and type(PerformanceDiagnostics.install) == "function" then
  local okPerformance, performanceErr = PerformanceDiagnostics.install({
    diagnostics=Diagnostics,
  })
  if not okPerformance and mod.log and type(mod.log.warn) == "function" then
    mod.log:warn("VASC performance monitor failed open: %s",
      tostring(performanceErr or "unavailable"))
  end
end
if MobileDiagnostic and type(MobileDiagnostic.setLogger) == "function" then
  pcall(MobileDiagnostic.setLogger, Diagnostics)
end

-- ------- pipelines

local Voxel = V.require("VoxelState")
local Voxel3D = V.require("Voxel3D")
local VoxelScene = V.require("VoxelScene")
local ExternalKascWalker = V.require("ExternalKascWalker")
local TiltShift = V.require("TiltShift")
local ChunkMesher = V.require("ChunkMesher")
local LedgeElevation = V.require("LedgeElevation")
local WarpPrefetch = V.require("WarpPrefetch")
local VoxelGrid = V.require("VoxelGrid")
local Shadows = V.require("Shadows")
local ShadowPolicy = V.require("ShadowPolicy")
local WorldCurve = V.require("WorldCurve")
local AscendantContracts = V.require("core/AscendantContracts")
local AscendantCardRegistry = V.require("core/AscendantCardRegistry")
local AscendantCardHost = V.require("core/AscendantCardHost")
local Gen1BattleLifecycle =
  V.require("adapters/gen1/Gen1BattleLifecycle")
local Gen1BattleLifecycleCard =
  V.require("cards/battle_router/Gen1BattleLifecycleCard")
local Gen1BattleLatchDiagnosticsCard =
  V.require("cards/battle_router/Gen1BattleLatchDiagnosticsCard")
local Gen1DefaultBattleProviderCard =
  V.require("cards/battle_router/Gen1DefaultBattleProviderCard")
local Gen1DiscsBattleProviderCard =
  V.require("cards/battle_router/Gen1DiscsBattleProviderCard")
local Gen1BattleRouterCard =
  V.require("cards/battle_router/Gen1BattleRouterCard")
local Gen1BattleOverlayCard =
  V.require("cards/battle_overlay/Gen1BattleOverlayCard")
local Gen1DragoniteFlyCard =
  V.require("cards/compat/Gen1DragoniteFlyCard")
local Gen1WeatherMusicPackageAssetsCard =
  V.require("cards/weather_music/Gen1WeatherMusicPackageAssetsCard")
local Gen1WeatherMusicCatalogCard =
  V.require("cards/weather_music/Gen1WeatherMusicCatalogCard")
local Gen1WeatherMusicRouterCard =
  V.require("cards/weather_music/Gen1WeatherMusicRouterCard")
local Gen1WeatherMusicOptionUiCard =
  V.require("cards/weather_music/Gen1WeatherMusicOptionUiCard")
local Gen1WeatherMusicPlaybackAdapterCard =
  V.require("cards/weather_music/Gen1WeatherMusicPlaybackAdapterCard")
local Gen1NativeBattleCleanup =
  V.require("adapters/gen1/NativeBattleCleanup")
local OverworldBattlePublic =
  V.require("adapters/gen1/OverworldBattlePublic")
local OverworldBattle = V.require("OverworldBattle")
V.PokemonModelProvider = V.require("PokemonModelProvider")
V.StadiumRomMenu = V.require("StadiumRomMenu")
function V.modelsEnabled()
  local predicate = V.PokemonModelProvider.builtInModelsEnabled
    or V.PokemonModelProvider.modelsEnabled
  local ok, enabled = pcall(predicate)
  return ok and enabled == true
end
local BattleLayout = V.require("BattleLayout")
local BattleHud = V.require("BattleHud")
local OrasBattleHudSettings = V.require("OrasBattleHudSettings")
local OrasUiSkin = V.require("OrasUiSkin")
-- A21's START presenter and the global ORAS skin deliberately share this
-- singleton so they cannot decorate the same native menu in opposite orders.
V.OrasUiSkin = OrasUiSkin
local StartMenuMode = V.require("StartMenuMode")
V.Gen1GermanUiCompat = V.require("Gen1GermanUiCompat")
local StartMenuSurfacePolicy = V.require("StartMenuSurfacePolicy")
local OrasBagSkin = V.require("OrasBagSkin")
local OrasFrlgBagSkin = V.require("OrasFrlgBagSkin")
local ManualBagSort = V.require("ManualBagSort")
local EvolutionPresentation = V.require("EvolutionPresentation")
local MoveLearnPresentation = V.require("MoveLearnPresentation")
V.TitleMenuHub = V.require("TitleMenuHub")
local MobileMenuPresentation = V.require("MobileMenuPresentation")
local Gen1MobileMenuBridge = V.require("Gen1MobileMenuBridge")
local PartyMenuSkins = V.require("PartyMenuSkins")
local PokemonUi = V.require("PokemonUi")
local AscBoxProvider = V.require("AscBoxProvider")
local PokemonUiGen1Hosts = V.require("PokemonUiGen1Hosts")
local BattlePartyBalls = V.require("BattlePartyBalls")
local BattleHudExtras = V.require("BattleHudExtras")
local BattleAnimationCompat = V.require("BattleAnimationCompat")
local BattleMusic = V.require("BattleMusic")
local LocalMusic = V.require("LocalMusic")
local SpritePacks = V.require("SpritePacks")
local LocalSprites = V.require("LocalSprites")
local LocalContent = V.require("LocalContent")
local SpriteHooks = V.require("SpriteHooks")
local BattleCam = V.require("BattleCam")
local BattleExit = V.require("BattleExit")
local DayNight = V.require("DayNight")
local DayTint = V.require("DayTint")
local Sky = V.require("Sky")
local SkyEvents = V.require("SkyEvents")
if type(SkyEvents.setCryPlayer) == "function" then
  SkyEvents.setCryPlayer(function(species)
    local Game = require("src.core.Game")
    if not (Game and Game.data) then return end
    local Sound = require("src.core.Sound")
    if Sound and type(Sound.playCry) == "function" then
      return Sound.playCry(Game.data, species)
    end
  end)
end
local Weather = V.require("Weather")
local WeatherTweak = V.require("WeatherTweak")
local AmbientAudio = V.require("AmbientAudio")
local WeatherFootsteps = V.require("WeatherFootsteps")
local WeatherMusicPlayback = nil
local Water = V.require("Water")
local AntiAlias = V.require("AntiAlias")
local CanvasPresentation = V.require("CanvasPresentation")
local DeviceProfile = V.require("DeviceProfile")
local WallDecals = V.require("WallDecals")
local PublicFacade = V.require("PublicFacade")
local KantoAscendantCompat = V.require("KantoAscendantCompat")
local KantoFlyMap = V.require("KantoFlyMap")
local ModernDexHost = V.require("ModernDexHost")
local VascMenu = V.require("VascMenu")
local FirstPerson = V.require("FirstPerson")
local FreeMove = V.require("FreeMove")
local CamControl = V.require("CamControl")
local VoxelShortcut = V.require("VoxelShortcut")
local ShortcutToast = V.require("ShortcutToast")
local ShortcutToastSetting = V.require("ModSetting").new(
  "shortcutToast", "SHORTCUT NOTICE", { true, false }, { "ON", "OFF" }, true)
local VascMenuSkinSetting = V.require("ModSetting").new(
  "vascMenuSkin", "VASC MENU",
  { "oras_fullscreen" },
  { "ORAS FULLSCREEN" }, "oras_fullscreen")
VascMenuSkinSetting:aliasLegacy("firered", "oras_fullscreen")
VascMenuSkinSetting:aliasLegacy("firered_compact", "oras_fullscreen")
local HorizonWall = V.require("HorizonWall")
local PanoramaBackdrop = V.require("PanoramaBackdrop")
local TransitionReveal = V.require("TransitionReveal")
local EngineFxCompat = V.require("EngineFxCompat")
local SpeciesFlyCinematic = V.require("SpeciesFlyCinematic")
local SpeciesSurfCinematic = V.require("SpeciesSurfCinematic")
local SpeciesFishingCinematic = V.require("SpeciesFishingCinematic")

local ascBoxInstalled, ascBoxInstallReason = AscBoxProvider.install(PokemonUi)
if not ascBoxInstalled and mod.log and type(mod.log.warn) == "function" then
  mod.log:warn("ASC BOX provider failed open: %s", tostring(ascBoxInstallReason))
end

-- Forward declaration: the voxel pipeline's update hook (registered below)
-- calls this, and it is defined further down with the settings it drives.
-- Declared rather than left global -- a mod writing to _G would leak into
-- every other mod's namespace.
local applyFull

local MOBILE_RUNTIME = CanvasPresentation.OS == "iOS"
  or CanvasPresentation.OS == "Android"

-- Keep cold-start boundary receipts sparse so the diagnostic itself cannot
-- become phone I/O load.
local updateTrace = { map = nil, prefetch = 0, pump = 0, armed = {} }
local function updateBoundary(kind, phase, fields)
  local Game = require("src.core.Game")
  local map = Game and Game.overworld and Game.overworld.map
  local mapId = map and map.id or "none"
  if updateTrace.map ~= mapId then
    updateTrace = { map=mapId, prefetch=0, pump=0, armed={} }
  end
  if phase == "start" then
    updateTrace[kind] = (updateTrace[kind] or 0) + 1
    local n = updateTrace[kind]
    updateTrace.armed[kind] = n <= 3 or n % 30 == 0
  end
  if not updateTrace.armed[kind] and phase ~= "failed" then return end
  fields = type(fields) == "table" and fields or {}
  fields.caller = fields.caller or (kind == "prefetch"
    and "VoxelScene.prefetch" or "ChunkMesher.pump")
  fields.context = "world"
  fields.map = mapId
  fields.attempt = updateTrace[kind]
  mobileDiagnostic(phase == "failed" and "fail" or "checkpoint",
    phase == "failed" and (kind == "prefetch" and "D11" or "D12")
      or "gen1-update-" .. kind .. "-" .. phase,
    phase == "failed" and "gen1-update-" .. kind or fields,
    phase == "failed" and tostring(fields.error or "unknown-error") or nil,
    phase == "failed" and fields or nil)
  if phase ~= "start" then updateTrace.armed[kind] = false end
end

-- The last VOID FILL the terrain was meshed under; see the update hook.
-- The scene canvas's size, in FRAMEBUFFER PIXELS.
--
-- `ctx.width/height` are the window measured in LOVE UNITS
-- (love.graphics.getDimensions), but the engine composites a pipeline's
-- returned canvas with `draw(canvas, 0, 0, 0, 1/dpiX, 1/dpiY)` -- a scale
-- that only covers the window when the canvas is at PIXEL resolution.
-- Sizing it in units costs the DPI scale TWICE: the canvas is that much
-- smaller, then it is drawn that much smaller again, so the diorama lands
-- in the top-left corner at 1/dpi of the screen.  Desktop never sees it --
-- units and pixels are the same thing there -- but on Android the DPI scale
-- is the display density (2.625 on a 420dpi panel), and the world came out
-- a third of the size in each direction.
--
-- So ask for the pixel dimensions rather than trusting the ctx.  That is
-- the number a fixed engine would hand over, so this keeps working either
-- way instead of double-correcting.  It also squares the FX pass: ctx.scale
-- is ALREADY in pixels per world pixel (Zoom.scale over Renderer:fitScale,
-- which measures the drawable), so the closures ctx.drawFx runs were being
-- scaled for a canvas 2.6x bigger than the one they drew into.
local function sceneSize(ctx)
  if love.graphics and love.graphics.getPixelDimensions then
    local pw, ph = love.graphics.getPixelDimensions()
    if pw and ph and pw > 0 and ph > 0 then return pw, ph end
  end
  return ctx.width, ctx.height
end

local voidFill = { last = nil }
function voidFill.check()
  local TileRenderer = require("src.render.TileRenderer")
  local now = TileRenderer.voidFill
  if voidFill.last ~= nil and now ~= voidFill.last then
    ChunkMesher.invalidate()   -- no map id: every ring on every map is stale
    HorizonWall.invalidate()
    PanoramaBackdrop.invalidate()
  end
  voidFill.last = now
end

local voxelPipeline = {
  label = "VOXEL",
  levels = Voxel.ANGLE_LABELS,
  -- 3 is the engine's TILT key, which this mode supersedes -- see the
  -- hotkey block near the bottom of this file for how it is claimed
  hotkey = "3",
  -- above tiltshift, so the two sort together in the options list with the
  -- mode first and its post-process under it
  priority = 20,

  -- Headless runs and drivers without a depth canvas or shader support
  -- answer false here, and the engine keeps the vanilla 2D path -- which
  -- is why no caller ever has to guard for a missing 3D pass.
  available = function()
    if mobileDiagnostic("recoveryMode") == true then return false end
    local ok = Voxel3D.available("voxelPipeline.available")
    mobileDiagnostic("capability", "D06", "gen1-pipeline-available",
      ok, ok and "graphics-api-and-shader-ready"
        or "graphics-api-or-shader-unavailable", {
        caller="voxelPipeline.available",
      })
    return ok
  end,

  -- the engine hands over the live level; we ease the camera toward it.
  -- pump() advances queued mesh builds inside a few-millisecond budget,
  -- so entering voxel mode (and streaming neighbours while walking)
  -- costs frames nothing visible -- the old synchronous build froze the
  -- first frame for seconds. prefetch() runs here as well as in the
  -- draw, because update ticks even while a warp's Transition covers
  -- the screen: the destination's meshes start building the moment the
  -- map swaps behind the fade, and the fade-covered frames get a wider
  -- pump slice -- so stepping out of a door lands on terrain that is
  -- already there instead of a flat flash.
  update = function(dt, level)
    if mobileDiagnostic("recoveryMode") == true then return end
    mobileDiagnostic("observeOption", (tonumber(level) or 0) > 0,
      "gen1-pipeline-update", { level=level })
    -- FULL is a preset, so it is applied ON THE PRESS rather than held every
    -- frame: it SETS the other rows and then leaves them alone. Holding them
    -- would make the zoom keys and the wheel dead while the mode was on, and
    -- would fight anyone who changed one deliberately.
    applyFull(level)
    Voxel.update(dt, level)
    -- The player-attached rig must keep easing both into and out of its
    -- rungs, so it ticks even after 1ST/3RD has just been left.
    FirstPerson.update(dt)
    -- the day/night clock, on the same always-running tick: Pipelines.update
    -- runs whatever the level, so time passes with the mode off, through
    -- battles and menus, and a CYCLE evening falls mid-fight exactly as it
    -- would mid-walk
    DayNight.update(dt)
    Sky.update(dt)
    SkyEvents.update(dt)
    local sceneryReloaded, sceneryReloadError = false, nil
    if type(HorizonWall.pollEditorReload) == "function" then
      sceneryReloaded, sceneryReloadError = HorizonWall.pollEditorReload(dt)
    end
    if sceneryReloaded then
      -- This image is independent of the authored edge assets, but dropping
      -- it here makes the scene-wide backdrop gate and all scenery GPU state
      -- cross the same atomic editor revision boundary.
      PanoramaBackdrop.invalidate()
    elseif sceneryReloadError and mod.log
           and type(mod.log.warn) == "function" then
      mod.log:warn("scenery editor reload deferred: %s",
                   tostring(sceneryReloadError))
    end
    local weatherGame = require("src.core.Game")
    local weatherMode = Weather.update(dt,
      weatherGame and weatherGame.overworld
        and weatherGame.overworld.map or nil)
    if WeatherMusicPlayback
        and type(WeatherMusicPlayback.observe) == "function" then
      WeatherMusicPlayback.observe(weatherGame, weatherMode, DayNight.tod())
    end
    AmbientAudio.update(dt)
    -- The overworld battle rides this hook rather than owning a pipeline of
    -- its own, because it owns no pass of the FRAME: it draws under a battle
    -- screen the engine composites, which is not a stage the registry has.
    -- What it needs is a tick that keeps running once the overworld stops
    -- being the top state, and this is one -- Game:update calls
    -- Pipelines.update unconditionally, so it survives the transition wipe
    -- and the whole battle. Ahead of the active() gate below, because a 3D
    -- battle does not require the free-roam mode to be switched on.
    OverworldBattle.update(dt)
    -- VOID FILL picks the block the border ring is made of, and in this
    -- mode that ring is BAKED INTO THE MESH rather than drawn each frame.
    -- So the option has to reach the cache or nothing happens on screen
    -- until the meshes are dropped for some other reason -- which reads
    -- exactly like the option doing nothing at all. Polled rather than
    -- hooked because the engine changes it from three places (the options
    -- row, applyOptions on load, TileRenderer.setVoidFill) and none of
    -- them announces it. Ahead of the active() gate, so switching it
    -- while voxel mode is OFF still invalidates what is cached.
    voidFill.check()
    local Game = require("src.core.Game")
    local ow = Game and Game.overworld
    local covered = Game and Game.stack and Game.stack:top() ~= ow
    local warpWarm = WarpPrefetch.update(Game, covered)
    local warm = ChunkMesher.preloadSetting:get()
    local configuredVoxel = (tonumber(level) or 0) > 0
    -- A phone map transaction that started while VOXEL was active remains
    -- map-owned while the engine swaps overworld objects.  Continue only its
    -- finite structural lane even if the general active/warm gate is briefly
    -- down; cold VOXEL OFF never arms this predicate.
    local mobileSceneryDrive = false
    if configuredVoxel and ow and ow.map and ow.camera
        and type(VoxelScene.mobileSceneryLifecyclePending) == "function" then
      local okDrive, pending = pcall(
        VoxelScene.mobileSceneryLifecyclePending, ow)
      mobileSceneryDrive = okDrive and pending == true
      if not okDrive then
        updateBoundary("mobile-scenery-drive", "failed", {
          error=tostring(pending),
        })
      end
    end
    if ow and ow.map and ow.camera
        and (Voxel.active() or warm or mobileSceneryDrive) then
      updateBoundary("prefetch", "start")
      local okPrefetch, prefetchError = pcall(VoxelScene.prefetch, ow)
      if okPrefetch then
        -- M11 is a separate bounded update lane after M10's core/direct-union
        -- receipt. It never decodes panorama/sky resources from draw().
        if type(VoxelScene.stageMobileScenery) == "function" then
          local okScenery, sceneryError = pcall(
            VoxelScene.stageMobileScenery, ow)
          if not okScenery then
            updateBoundary("mobile-scenery", "failed", {
              error=tostring(sceneryError),
            })
          end
        end
        updateBoundary("prefetch", "ready", {
          sceneReady=Voxel.ready == true,
        })
      else
        Voxel.ready = false
        updateBoundary("prefetch", "failed", {
          error=tostring(prefetchError),
        })
      end
    end
    if not Voxel.active() then
      if warm then
        local warmCovered = Game and Game.stack and Game.stack:top() ~= ow
        updateBoundary("pump", "start", {
          loading=false, covered=warmCovered, background=true,
        })
        local okPump, pumpError = pcall(
          ChunkMesher.pump, warmCovered, true)
        if okPump then
          updateBoundary("pump", "ready", {
            loading=false, covered=warmCovered, background=true,
            pending=type(ChunkMesher.pending) == "function"
              and ChunkMesher.pending() or "unknown",
          })
        else
          updateBoundary("pump", "failed", {
            loading=false, covered=warmCovered, background=true,
            error=tostring(pumpError),
          })
        end
      end
      return
    end
    -- A fade/menu still runs the engine's own animation and input work. Keep
    -- its covered build slice to 6ms; while the complete 2D fallback is
    -- visible, the bounded 8ms loading slice likewise keeps iPhone responsive
    -- until the atomic swap.
    local loading = not Voxel.ready
    -- Once the current scene and every relevant seam are complete, two-hop
    -- survey maps receive only a 1ms trickle. They are promoted automatically
    -- when approached. This still drains the bounded cache over long walks,
    -- but removes distant speculative work from the normal 4ms visible slice.
    local priorityWork = ChunkMesher.hasPriorityWork()
    updateBoundary("pump", "start", {
      loading=loading, covered=covered,
    })
    local okPump, pumpError = pcall(
      ChunkMesher.pump, covered, false, loading, warpWarm,
      not covered and not loading and not priorityWork)
    if okPump then
      updateBoundary("pump", "ready", {
        loading=loading, covered=covered,
        pending=type(ChunkMesher.pending) == "function"
          and ChunkMesher.pending() or "unknown",
      })
    else
      Voxel.ready = false
      updateBoundary("pump", "failed", {
        loading=loading, covered=covered, error=tostring(pumpError),
      })
    end
  end,

  drawWorld = function(ctx)
    if mobileDiagnostic("recoveryMode") == true then return nil end
    -- Terrain and characters are geometry; the field FX stay ordinary 2D
    -- draws composited on top, anchored through the same camera the 3D
    -- pass used (ctx.drawFx below).  The scene renders at the window's
    -- PIXEL resolution (see sceneSize) so the 3D pass is crisp rather than
    -- a magnified low-res image, while the FX closures keep drawing in
    -- world-pixel units.
    mobileDiagnostic("callback", "gen1-voxelPipeline.drawWorld", "world", {
      level=ctx and ctx.level,
    })
    local sw, sh = sceneSize(ctx)
    -- With AA on, the whole pass runs into a canvas BIGGER than the window
    -- and is folded back down at the end (see AntiAlias).  Nothing between
    -- these two lines knows: every pass in the frame measures itself in the
    -- canvas it was handed, so the sky's dither, the water's march and the
    -- camera itself all come out the same picture at a higher sample rate.
    local rw, rh = AntiAlias.expand(sw, sh)
    mobileDiagnostic("checkpoint", "gen1-voxel-scene-start", {
      caller="VoxelScene.render", context="world",
      width=rw, height=rh,
    })
    local canvas = VoxelScene.render(ctx.state, rw, rh,
                                     ctx.vw, ctx.vh, ctx.paletteFor)
    if not canvas then
      return nil
    end   -- fall back to the 2D path
    if Voxel3D.beginOverlay() then
      -- the FX closures are ordinary 2D draws sized in DISPLAY pixels, and
      -- they are drawing into the supersampled canvas alongside everything
      -- else -- so the scale goes up with it, or the "!" bubble lands the
      -- right place at half the size.  project() already answers in canvas
      -- pixels, so only the scale needs saying.
      ctx.drawFx(function(wx, wy) return Voxel3D.project(wx, 0, wy) end,
                 ctx.scale * AntiAlias.factor())
      Voxel3D.endOverlay()
    end
    -- and back to the window's own size, which is what the engine composites
    -- one canvas pixel to one display pixel.  A pass-through when AA is off.
    mobileDiagnostic("checkpoint", "gen1-aa-resolve-start", {
      caller="AntiAlias.resolve", context="world",
      width=sw, height=sh,
    })
    local resolved = AntiAlias.resolve(canvas, sw, sh, "world")
    if not resolved then
      mobileDiagnostic("fail", "D15", "gen1-present-resolve",
        "anti-alias-resolve-returned-nil", {
          caller="AntiAlias.resolve", context="world",
        })
      return nil
    end
    mobileDiagnostic("produced", "gen1-voxelPipeline.drawWorld", "world", {
      width=sw, height=sh, renderWidth=rw, renderHeight=rh,
    })
    return resolved
  end,

  invalidate = function()
    -- Drop P1 receipts before their ping-pong canvases are released.
    if type(VoxelScene.invalidateMobileScenery) == "function" then
      VoxelScene.invalidateMobileScenery("voxel-pipeline-invalidate")
    end
    Voxel3D.invalidate()
    ExternalKascWalker.invalidate()
    OverworldBattle.invalidate()
    AntiAlias.invalidate()
    ChunkMesher.invalidate()   -- no map id = every cached mesh
    HorizonWall.invalidate()
    PanoramaBackdrop.invalidate()
  end,
}

-- Gen1Recomp 0.1.90 does not know the optional revealReady schema field, so
-- include it only after feature-detecting the complete new engine seam.  On
-- 0.1.90 configure() installs an idempotent engine_internals compatibility
-- wrapper with the exact same predicate instead; the registered record stays
-- byte-for-byte valid against that baseline schema.
local revealReady = TransitionReveal.configure()
if revealReady then voxelPipeline.revealReady = revealReady end
mod.content.render_pipelines:register("voxel", voxelPipeline)
mobileDiagnostic("provider", true, false,
  "gen1-main.render-pipelines", "voxel-provider-registered")

mod.content.render_pipelines:register("tiltshift", {
  label = "T-SHIFT",
  levels = TiltShift.LABELS,
  -- 6 is free: no engine branch claims it, so this one alone reaches the
  -- registry by the documented route
  hotkey = "6",
  priority = 10,

  update = function(dt, level)
    TiltShift.update(dt, level)
  end,

  -- worldPresent, not present: the blur belongs on the diorama, not on the
  -- dialog box in front of it.  A pass-through when the level is 0 or the
  -- shader is unavailable, so the frame is untouched in every other case.
  worldPresent = function(canvas)
    return TiltShift.apply(canvas)
  end,

  invalidate = function()
    TiltShift.invalidate()
  end,
})

-- ------- this mod's own settings
--
-- Neither of these is a pipeline: they own no pass of the frame, they
-- PARAMETERISE the voxel one, so they have nothing to put in drawWorld or
-- present and the registry would rightly reject them.  Plain mod settings
-- instead -- see ModSetting for where they persist and how the two rows
-- each ends up on stay in step.

-- ------- the FULL preset
--
-- Everything the mode wants switched to at once. Applied when the VOXEL row
-- ARRIVES at FULL and not again, so the player can still move the camera or
-- the zoom afterwards -- it is a starting point, not a lock.
--
-- Leaving FULL deliberately does NOT undo any of it. A preset that reverted
-- would throw away whatever the player had changed since, and "put it back
-- how it was" is not a thing this can know.
local fullWas = nil

applyFull = function(level)
  local isFull = Voxel.isFull(level)
  local was = fullWas
  fullWas = isFull
  if not isFull or was == true or was == nil then return end

  local Game = require("src.core.Game")
  local Pipelines = require("src.render.Pipelines")
  local Zoom = require("src.render.Zoom")
  local opts = Game.save and Game.save.options
  if not opts then return end

  -- the miniature blur at its strongest: FULL is the diorama look, and the
  -- tilt-shift is most of what makes it read as a model
  Pipelines.setLevel("tiltshift", Pipelines.maxLevel("tiltshift"))
  Pipelines.syncOptions(opts)
  -- the horizon flat. The curve bends the world away from a walking player,
  -- which fights a fixed diorama framing
  WorldCurve.setting:setIndex(1, Game)
  -- and the water reflecting everything it can: FULL is the diorama at its
  -- most photographed, and a lake with the sky and the shoreline in it is
  -- most of what makes the model read as being outdoors
  Water.setting:setIndex(1, Game)
  Sky.setting:setValue("full", Game)
  Sky.cloudSetting:setValue("on", Game)
  SkyEvents.setting:setValue("full", Game)
  HorizonWall.setting:setValue("full", Game)
  -- and the view fitted to the window
  opts.zoom = 0
  Zoom.applyOptions(opts)
  -- Battle mode, backsprite policy and camera are persisted presentation
  -- choices, not part of the overworld diorama preset. In particular, FULL
  -- must not turn a deliberate OFF/ARENA/DISCS selection back into MAP or
  -- re-enable player/trainer backs. Those rows remain independently owned by
  -- the player and are merely shown alongside FULL in the menu.
  -- and the battle screen the staged fight is composed for. WIDE re-lays that
  -- screen out on a 304x144 surface, which moves every anchor the arena camera
  -- is solved against (OverworldBattle.forceOG). Only apply that battle-owned
  -- layout policy when the player's already selected mode is staged; OFF keeps
  -- the cartridge layout it owns.
  if OverworldBattle.enabled() then OverworldBattle.forceOG(Game) end
  -- FULL showcases the complete outdoor system, including the colour-graded
  -- day/night clock. DAYTIME remains selectable afterwards, so this is a
  -- starting value rather than a lock.
  DayNight.setting:setValue("cycle", Game)
  if Game.writeOptions then pcall(Game.writeOptions, Game) end
end

-- Whether a fight can be staged on the map, as far as the OPTIONS menu is
-- concerned: the 3D-BTL row, and nothing else.
--
-- It used to answer yes under FULL as well, on the grounds that FULL owned
-- that row and switched it on. FULL no longer owns it -- the row stays on the
-- menu under FULL and can be switched off there (see the rows hook) -- so that
-- clause would now claim staged battles for a preset the player had just
-- turned them off inside, pinning BATTLE LAYOUT to OG for a fight that is
-- never staged. The row is the only thing that decides, which is what every
-- other reader of this setting already believed: OverworldBattle.begin and
-- wantsFront both gate on enabled() alone.
--
-- Deliberately NOT gated on Voxel3D.available(): the engine offers a
-- pipeline's row whether or not the hardware can run it (Pipelines.rows), so
-- this mode's rows say ON on a machine without a depth buffer too, and a menu
-- that claims 3D battles are on must not also offer the layout they cannot be
-- drawn in.
local function stagedBattles()
  return OverworldBattle.enabled()
end

-- VASC owns both its bundled ORAS HUD and its legacy readable HUD even when
-- KASC is installed. Rows disappear only for an explicit public KASC HUD
-- claimant; optional Mega/QoL services alone never displace presentation.
local function vascHudControls()
  return stagedBattles() and OrasBattleHudSettings.vascOwnsHud(mod)
end

local function vascOrasHudControls()
  return vascHudControls() and OrasBattleHudSettings.orasSelected(mod)
end

local function vascStandardHudControls()
  return vascHudControls() and OrasBattleHudSettings.standardSelected(mod)
end

local function adjustableBattleCamera()
  return stagedBattles() and not OverworldBattle.arenaMode()
end

local function authoredBattleCamera()
  return stagedBattles() and OverworldBattle.arenaMode()
end

-- The Stadium director belongs to real voxel terrain, not only to the ARENA
-- stage selector. MAP is its primary use case; authored ARENA remains the
-- portable fallback. Procedural DISCS have no surrounding world to orbit.
local function stadiumBattleCamera()
  return stagedBattles() and not OverworldBattle.discs()
end

local function battleDiscs()
  return stagedBattles() and OverworldBattle.discs()
end

local SETTINGS = {
  { DeviceProfile.setting,
    "Choose a persistent hardware profile. AUTO selects PC/MAX on desktop, "
    .. "HANDHELD on iOS/Android and ECO on Web. Changing any managed row "
    .. "switches to CUSTOM and preserves those individual values.",
    row = DeviceProfile.row },
  { ShortcutToastSetting,
    "Show a short ORAS-style receipt in the upper-left after a successful "
    .. "Voxel Ascendant display shortcut. This is screen-space presentation "
    .. "only and may be disabled without changing any shortcut or setting.",
    full = true },
  { Sky.setting,
    "Outdoor sky over Kanto. FULL draws the time-aware banded sky with sun "
    .. "or moon, FLAT keeps only the cheaper horizon colour, and OFF leaves "
    .. "the outdoor backdrop unpainted." },
  { Sky.cloudSetting,
    "Pixel-art clouds crossing the outdoor sky. They follow the current "
    .. "day/night colour and can be disabled independently for performance." },
  { SkyEvents.setting,
    "Rare world-anchored sky events. FULL permits rainbows plus distant "
    .. "Pidgeot and Ho-Oh flights; RAINBOW or FLYERS keeps only that class, "
    .. "and OFF skips all event drawing for slower devices.",
    full = true },
  { Weather.setting,
    "Outdoor weather. AUTO keeps one regional four-minute front across map "
    .. "and interior transitions, keeps STORM rare, and separates HEAT/SNOW seasons "
    .. "with normal weather. RAIN, SNOW, FOG, STORM, daytime-only HEAT and "
    .. "RAINBOW remain direct tests. Rain endings guarantee a rainbow. "
    .. "The same weather remains visible in staged outdoor battles." },
  { Gen1WeatherMusicOptionUiCard.setting,
    "Play the supplied map-specific Night, Rain, Storm, Winter and Heat "
    .. "arrangements in the nine registered Gen-I areas. Clear daytime, "
    .. "unsupported maps, Battle, victory, jingles, story, Bike and SURF "
    .. "always keep the already resolved game/KASC music.",
    full = true },
  { WeatherTweak.setting,
    "Optional additive weather detail. OFF keeps only canonical VASC weather. "
    .. "Normal RAIN is never overdrawn or changed by this layer. SUBTLE "
    .. "(default) and FULL add bounded storm leaves, cold-route hail, forest "
    .. "fireflies, regional wind, fog spray, dust, ash, rare meteors, gradual "
    .. "surface aftermath and safe ambient sound focus. Battle rules never change.",
    full = true },
  { HorizonWall.setting,
    "Close the streamed world edge with a map-aware near layer and original "
    .. "distant Kanto panorama outdoors, plus rock walls in caves. Water, "
    .. "coastal openings and connected maps stay real. OFF draws neither "
    .. "the scenery curtain nor the outdoor panorama." },
  { ChunkMesher.preloadSetting,
    "Build the current map and connected neighbours into a safe in-memory "
    .. "mesh cache while voxel mode is off. ON makes the first switch and "
    .. "most map changes appear immediately; OFF saves background CPU.",
    full = true },
  { VoxelGrid.setting, "One-pixel wireframe along every voxel edge." },
  { LedgeElevation.setting,
    "Interpret authored ledges as visual terrain height. WORLD carries a "
    .. "bounded terrace through direct outdoor map connections and lets its "
    .. "nearest enclosing rocks or bollards share the correct level; unrelated "
    .. "roads stay flat and warp interiors may reset the datum. LOCAL keeps "
    .. "the original per-map bounded treatment. FLAT retains native "
    .. "ledge/stair art and gameplay "
    .. "without lifting the land behind it.",
    full = true },
  -- The staged fight used to force this on even when V-GRID said OFF. It is
  -- deliberately independent: battle framing should not rewrite the look the
  -- player chose for free-roam.
  { VoxelGrid.battleSetting,
    "Draw voxel seams in 3D battles. Independent of V-GRID, which controls "
    .. "the overworld.",
    full = true },
  -- A quality/performance switch rather than a FULL-preset knob. Keep it on
  -- the menu under FULL so mobile players can disable the shadow-map pass
  -- without leaving the curated camera preset.
  { Shadows.setting,
    "Turn object-anchored world and character shadows ON or OFF in voxel "
    .. "scenes and 3D battles. Turn "
    .. "this off on mobile devices where the shadow pass is slow or renders "
    .. "poorly.",
    full = true },
  { WorldCurve.setting,
    "Bend the world down over the horizon, Animal Crossing style." },
  { Water.setting,
    "Reflections on water. FULL adds screen-space reflections of the "
    .. "shoreline, the trees and the buildings behind it; SKY is the sky, "
    .. "the sun and the moon alone, which is most of the look for a "
    .. "fraction of the cost." },
  -- `full` marks a row FULL does not take away. FULL owns the diorama's own
  -- knobs; what a battle is drawn over, and how it is framed, are not that.
  { OverworldBattle.setting,
    "Fight in three dimensions using the game's native Gen 1 pictures as "
    .. "camera-facing cards. MAP uses nearby voxel terrain; ARENA builds a "
    .. "location- and anchor-aware field; DISCS uses two neutral platforms.",
    full = true },
  { V.PokemonModelProvider.setting,
    "Choose the Pokemon actor used only in staged MAP, ARENA or DISCS "
    .. "battles. CARTRIDGE keeps the game sprite. STADIUM 2 builds a local "
    .. "model cache from the player's own ROM: standalone Gen 1 is strictly "
    .. "limited to 001-151; active KASC may extend it to 001-251. Missing "
    .. "packs or providers fail closed to CARTRIDGE.",
    full = true },
  { OverworldBattle.arenaArtSetting,
    "Choose ARENA paintings. VASC + FRLG makes one stable shuffled choice "
    .. "per fight, but only between a VASC master and its geographically "
    .. "reviewed FRLG-like counterpart. VASC ONLY keeps the existing art; "
    .. "FRLG-LIKE ONLY uses new art where available and the appropriate "
    .. "VASC master everywhere else.",
    when = authoredBattleCamera,
    full = true },
  { OverworldBattle.diskArtSetting,
    "Choose the carried DISCS texture family. VASC + FRLG makes one stable "
    .. "shuffled choice per fight between the neutral VASC disk and the "
    .. "FRLG-like disk assigned to that map terrain. VASC ONLY keeps the "
    .. "original neutral platforms; FRLG-LIKE ONLY uses a matching generated "
    .. "terrain disk plus a pale procedural material tint behind it, and "
    .. "safely falls back to VASC on unsupported maps. No large backdrop "
    .. "image is loaded.",
    when = battleDiscs,
    full = true },
  -- Keep the two user-facing team selectors first on SKINS & OVERLAYS. The
  -- page preserves SETTINGS order, so placing them here keeps both choices
  -- visible before the first six-row scroll boundary.
  { PartyMenuSkins.setting,
    "Choose the normal Start-menu team view independently: ASC BOX uses the "
    .. "new wide ORAS party, summary and modal presentation; ORAS GLASS "
    .. "repaints only the already-created native PartyMenu; GAME DEFAULT "
    .. "leaves its exact game/KASC renderer untouched. The canonical POKéMON "
    .. "row and all native actions, field moves and callbacks stay authoritative.",
    full = true },
  { PokemonUi.surfaceSettings.battle_party,
    "Choose ASC BOX, ORAS GLASS or GAME DEFAULT only for the in-battle "
    .. "party/team and forced-switch picker. HP/status cards and battle commands still follow the "
    .. "independent BATTLE HUD option, so ORAS HUD plus ASC BOX is valid.",
    full = true },
  { VascMenuSkinSetting,
    "The VASC/KASC settings hub always opens as responsive ORAS FULLSCREEN "
    .. "glass with permanent focused-row help and remembered navigation. "
    .. "The compact renderer is retained internally only as a fail-safe when "
    .. "the fullscreen presentation cannot be created. Bag, PC, Box and "
    .. "ordinary game menus are never affected.",
    full = true },
  { KantoFlyMap.setting,
    "Choose the regular Gen 1 Town Map and Fly picker. CARTRIDGE MAP keeps "
    .. "the exact engine screen. VASC WIDESCREEN uses the integrated 576x324 "
    .. "Kanto map for Town Map, Fly and its public Dex-area provider. The "
    .. "retired compact custom map is not selectable and appears only as an "
    .. "automatic fail-open rescue if the widescreen assets or renderer fail.",
    full = true },
  { ModernDexHost.styleSetting,
    "Choose VASC WIDESCREEN for the integrated 512x288 Modern Pokedex or "
    .. "GAME DEFAULT for the exact native Gen 1 Pokedex and entry screen. "
    .. "Seen/owned flags, species records, cries, scripted forceOwned previews, "
    .. "Start-menu callbacks and stack ownership always remain engine-owned. "
    .. "Any Modern Pokedex install, construction or rendering failure returns "
    .. "to that same native screen without changing save data.",
    full = true },
  { ModernDexHost.spriteSetting,
    "Choose only the Modern Pokedex portrait source. KASC CRYSTAL (AUTO) "
    .. "uses KASC's public Crystal provider when available and otherwise the "
    .. "active game provider; ACTIVE SPRITE STYLE follows the current provider; "
    .. "GAME ORIGINAL reads the cartridge species front picture. This setting "
    .. "does not change battle, Box, Party or overworld sprites.",
    full = true },
  { OrasBattleHudSettings.uiSkinSetting,
    "Choose ORAS glass for the engine's native dialogue, choice, title/START "
    .. "and ordinary list surfaces, or restore the exact Game default. "
    .. "PC, authored menus and battle HUDs retain their own renderer; Bag "
    .. "presentation is selected independently in the next row.",
    full = true },
  { OrasBattleHudSettings.bagSkinSetting,
    "Keep the exact GAME/KASC/Useful Bag renderer, or deliberately repaint an "
    .. "already constructed Bag with VASC's 512x288 D/P ORAS WIDE or FRLG "
    .. "ORAS WIDE drawing. Historical compact choices migrate here and stay "
    .. "internal fail-safe renderers only. "
    .. "The safe default never wraps provider draw ownership; VASC styles "
    .. "replace drawing only and preserve items, pockets, input, USE/TOSS, "
    .. "quantity, TM, battle and sorting callbacks.",
    full = true },
  { OrasBattleHudSettings.bagColorSetting,
    "Choose the red, blue or green pocket accent on a selected VASC ORAS Bag. "
    .. "AUTO follows KASC's public RED/BLUE/GREEN character when available "
    .. "and otherwise uses red. Gold material and outlines are never recoloured.",
    full = true },
  { OrasBattleHudSettings.bagBodySetting,
    "Choose an independent body colour for a selected VASC ORAS Bag. AUTO "
    .. "follows the active Red/Blue/Yellow/Gold/Silver/Crystal edition; ORAS "
    .. "preserves the authored atlas colours. GAME/KASC is never recoloured.",
    full = true },
  { OrasBattleHudSettings.bagFormSetting,
    "Choose the normal or handled silhouette for a selected VASC ORAS Bag. "
    .. "AUTO follows the active KASC character independently from the accent: "
    .. "GREEN uses the handled Bag; RED and BLUE use the round Bag.",
    full = true },
  { PokemonUi.globalSetting,
    "Choose the preferred skin for box-like Pokemon screens. ASC BOX becomes "
    .. "the new default only on surfaces where its complete provider is "
    .. "installed; unavailable choices fail open to GAME DEFAULT without "
    .. "erasing the saved preference. This never changes the battle HUD.",
    full = true },
  { PokemonUi.surfaceSettings.pc_box,
    "Override the shared Pokemon UI choice for the standard PC storage box, "
    .. "or FOLLOW GLOBAL. Providers only present the screen; native withdraw, "
    .. "deposit, release, box switching and printer rules remain authoritative.",
    full = true },
  { PokemonUi.surfaceSettings.legacy_bank,
    "Override the shared Pokemon UI choice for KASC's Legacy Bank, or FOLLOW "
    .. "GLOBAL. KASC may register KASC FRLG publicly; its transfer, Dex, "
    .. "capacity and cross-box multi-selection backend remains authoritative.",
    full = true },
  { AscBoxProvider.densitySetting,
    "ASC BOX uses the genuine Gen-I 5x4 capacity by default with larger "
    .. "Pokemon art. 6x5 DENSE keeps the ORAS-like compact grid and visibly "
    .. "locks cells beyond the host-reported capacity. This changes only "
    .. "presentation; every transfer and capacity rule stays host-owned.",
    full = true },
  { OrasBattleHudSettings.styleSetting,
    "Choose VASC's complete responsive ORAS battle controls or its existing "
    .. "readable standard HUD. KASC may supply optional Mega/QoL data without "
    .. "taking over; only an explicit public HUD claim hides this choice.",
    when = vascHudControls,
    full = true },
  { OrasBattleHudSettings.languageSetting,
    "Select the VASC ORAS HUD language. AUTO follows Universal German when "
    .. "available and otherwise uses the active game language.",
    when = vascOrasHudControls,
    full = true },
  { OrasBattleHudSettings.scaleSetting,
    "Scale the complete ORAS battle furniture as one responsive group without "
    .. "stretching its individual button art.",
    when = vascOrasHudControls,
    full = true },
  { OrasBattleHudSettings.statusGlassSetting,
    "Set only the background-glass strength of ORAS HP/status cards. Text, "
    .. "HP/EXP bars, symbols and edition borders stay fully legible.",
    when = vascOrasHudControls,
    full = true },
  { OrasBattleHudSettings.textGlassSetting,
    "Set only the background-glass strength of the ORAS battle message box. "
    .. "Message ink, prompt cursor and edition border keep their authored "
    .. "opacity so a transparent pane remains readable.",
    when = vascOrasHudControls,
    full = true },
  { OrasBattleHudSettings.anchorSetting,
    "Anchor status cards outside or above their projected Pokemon, or use "
    .. "screen corners. Collision avoidance always keeps the sprite clear.",
    when = vascOrasHudControls,
    full = true },
  { OrasBattleHudSettings.playerXSetting,
    "Fine-tune the player ORAS status card horizontally.",
    when = vascOrasHudControls, full = true },
  { OrasBattleHudSettings.playerYSetting,
    "Fine-tune the player ORAS status card vertically.",
    when = vascOrasHudControls, full = true },
  { OrasBattleHudSettings.enemyXSetting,
    "Fine-tune the enemy ORAS status card horizontally.",
    when = vascOrasHudControls, full = true },
  { OrasBattleHudSettings.enemyYSetting,
    "Fine-tune the enemy ORAS status card vertically.",
    when = vascOrasHudControls, full = true },
  { OrasBattleHudSettings.wildDvsSetting,
    "Show the five deterministic Gen-I DVs on wild-enemy ORAS status cards.",
    when = vascOrasHudControls, full = true },
  { BattleHud.positionSetting,
    "Place battle status panels using the shared KASC/VASC HUD geometry. "
    .. "AUTO uses wide edges in landscape and a top/bottom stack on portrait "
    .. "phones; FRAME restores the original Game Boy positions.",
    when = vascStandardHudControls,
    full = true },
  { BattleHud.scaleSetting,
    "Scale battle status panels independently of the arena. AUTO uses a "
    .. "crisp native size on portrait phones, a compact size in mobile "
    .. "landscape, and the original KASC size on desktop.",
    when = vascStandardHudControls,
    full = true },
  { BattleHud.alphaSetting,
    "Set the transparency of the readable frosted backing behind status, "
    .. "move-selection and battle-text furniture.",
    when = vascStandardHudControls,
    full = true },
  { BattleHudExtras.genderSetting,
    "Show the Gen-II gender symbol in the dedicated enemy/player status "
    .. "cell. VASC derives it from the existing Attack DV and never writes "
    .. "another Pokemon identity field.",
    when = vascStandardHudControls,
    full = true },
  { BattleHudExtras.expSetting,
    "Show battle EXP progress in black or blue on the same player HUD. When "
    .. "KASC is active this row proxies its matching QoL value; VASC remains "
    .. "the owner of the final HUD position.",
    row = BattleHudExtras.expRow,
    when = vascStandardHudControls,
    full = true },
  { BattleHudExtras.caughtSetting,
    "Show a red or grey Pokeball beside an already-caught wild opponent. "
    .. "The marker is baked into the enemy HUD band and cannot remain floating "
    .. "in the old centre position.",
    row = BattleHudExtras.caughtRow,
    when = vascStandardHudControls,
    full = true },
  { BattleCam.distanceSetting,
    "Set the saved starting distance of MAP and DISCS battles. 1X is the "
    .. "closest, tightest view; 2X is the balanced middle ground; 3X is the "
    .. "default and widest view. Q/E, wheel and pinch "
    .. "can still fine-tune it during a fight.",
    when = adjustableBattleCamera,
    full = true },
  { BattleCam.arenaCameraSetting,
    "STADIUM directs battles in real Voxel terrain: trainer/"
    .. "wild intros, Pokemon portraits, shoulder views, attacks and a slow "
    .. "360-degree orbit with regular still holds. Travel is speed-limited and "
    .. "checks the complete route around trees, walls and houses; the camera "
    .. "may lift or zoom, and uses a safe cut rather than crossing geometry. "
    .. "In a narrow or constrained room VASC chooses the best clear view of "
    .. "both Pokemon once and holds that seat static for the whole fight. "
    .. "A painted ARENA fallback stays optically fixed so its Pokemon cannot "
    .. "grow or shrink against the unmoving painting. 3X keeps the prior "
    .. "static camera. Q/E, wheel "
    .. "or pinch temporarily take camera control.",
    when = stadiumBattleCamera,
    full = true },
  -- Only offered while a fight can actually be staged on the map: with 3D-BTL
  -- off the engine draws the classic screen, which is this row's ON already,
  -- and a row that no longer decides anything is worse than no row.
  { OverworldBattle.trainerBackSetting,
    "Use the trainer's native 2D rear only with BATTLE HUD = STANDARD in "
    .. "MAP or DISCS. Its feet remain on the original textbox. ARENA and "
    .. "every other HUD use a full standing front instead.",
    when = function()
      return stagedBattles()
        and OverworldBattle.trainerBackOptionAvailable()
    end,
    full = true },
  { OverworldBattle.pokemonBackSetting,
    "MAP plus BATTLE HUD = STANDARD may keep the native 2D rear on the "
    .. "textbox. DISCS, ARENA and other HUDs accept only a provider-certified "
    .. "full-body rear; otherwise they safely use the full front sprite.",
    when = stagedBattles,
    full = true },
  { BattleMusic.setting,
    "Optional companion-pack music. ORIGINAL keeps the game/KASC cue; "
    .. "SHUFFLE chooses once per fight from installed packs, while GEN 2-6 "
    .. "pins one available generation. USER MUSIC below is the simpler "
    .. "choice for loose files you own. VASC includes no audio.",
    full = true },
  { DayNight.setting,
    "What time it is outdoors: pin the sky to DAY, NIGHT, DUSK or DAWN, "
    .. "or leave AUTO to run it -- long DAY and NIGHT plateaus with short "
    .. "graded dawn and dusk transitions. The "
    .. "colour-graded world, clouds, stars, windows, shadows and sky "
    .. "following the same clock.",
    full = true },
  -- Marked `full` for the opposite reason the battle rows are: this is not a
  -- knob on the look at all, it is what the look COSTS. FULL is a preset for
  -- the diorama, not a licence to spend four times the fill rate on the
  -- machine it happens to be running on, so it neither sets this nor takes
  -- the row away -- the player decides what their hardware can carry, from
  -- inside FULL like anywhere else.
  { AntiAlias.setting,
    "Smooth the stair-stepped edges of the 3D world -- roof ridges, ledge "
    .. "lips, a tree against the sky -- by rendering the diorama larger than "
    .. "the window and folding it back down. Every edge in the picture "
    .. "softens with them, the tileset's own texels included, so the diorama "
    .. "reads smoother rather than sharper. 2X costs half again as many "
    .. "pixels in each direction and 4X twice, which makes this the most "
    .. "expensive row in the mod.",
    full = true },
}

-- Height mode changes every terrain basis, entity footing and horizon seam.
-- Drop all derived geometry in one operation; the ordinary asynchronous mesh
-- path keeps the 2D world visible until the replacement is ready.
LedgeElevation.setting:onChange(function()
  ChunkMesher.invalidate()
  HorizonWall.invalidate()
end)

-- Profiles own only cost/automation choices, never camera composition,
-- world curve or the player's sprite/back-picture preferences.
DeviceProfile.configure({
  { setting = Sky.setting,
    max = "full", handheld = "full", eco = "flat" },
  { setting = Sky.cloudSetting,
    max = "on", handheld = "on", eco = "off" },
  { setting = SkyEvents.setting,
    max = "full", handheld = "flyers", eco = "off" },
  { setting = Weather.setting,
    max = "auto", handheld = "auto", eco = "auto" },
  { setting = HorizonWall.setting,
    max = "full", handheld = "full", eco = "full" },
  { setting = ChunkMesher.preloadSetting,
    max = true, handheld = true, eco = false },
  { setting = Shadows.setting,
    max = true, handheld = true, eco = false },
  { setting = Water.setting,
    max = "full", handheld = "sky", eco = "sky" },
  { setting = DayNight.setting,
    max = "cycle", handheld = "cycle", eco = "cycle" },
  { setting = AntiAlias.setting,
    max = 2, handheld = 0, eco = 0 },
})

local vascHudSchemaKeys = {
  battleHudStyle=true,
  hud_language=true, hud_scale=true,
  oras_status_glass=true, oras_text_glass=true, status_anchor=true,
  player_hud_x=true, player_hud_y=true,
  enemy_hud_x=true, enemy_hud_y=true, wild_dvs=true,
  battleHudPosition=true, battleHudScale=true, battleHudAlpha=true,
  battleHudGender=true, battleHudExp=true, battleHudCaught=true,
}
local kascOwnsHudAtBoot = not OrasBattleHudSettings.vascOwnsHud(mod)
if mod._vascOverworldCard then
  local apo = mod._vascOverworldCard.options
  for _, entry in ipairs(apo.entries(mod, V.require("ModSetting"))) do
    SETTINGS[#SETTINGS+1] = entry
  end
  apo.addKeys(VascMenu.sections)
end
local function defineOptionSchema()
  local schema = {}
  for _, entry in ipairs(SETTINGS) do
    local setting = entry[1]
    if not (kascOwnsHudAtBoot and vascHudSchemaKeys[setting.key]) then
      schema[#schema + 1] = setting:schema(entry[2])
    end
  end
  if mod._vascOverworldCard then
    for _, spec in ipairs(mod._vascOverworldCard.options.managerExtras(mod)) do
      schema[#schema+1]=spec
    end
  end
  mod.options:define(schema)
  return schema
end
defineOptionSchema()
-- Providers may register after VASC (for example KASC on mods.loaded). Rebuild
-- only the declarative option choices; saved intent and live controllers are
-- untouched, while unavailable provider rungs stay hidden.
PokemonUi.onRegistryChanged(defineOptionSchema)

-- Title choices and the CONTINUE receipt use one six-edition shared hub. It is
-- registered before the generic UI skin so the exact title states cannot be
-- claimed by the ordinary menu decorator.
V.titleHubInstalled, V.titleHubReason = V.TitleMenuHub.install()
if not V.titleHubInstalled and mod.log and type(mod.log.warn) == "function" then
  mod.log:warn("VASC Gen-1 title hub failed open: %s",
    tostring(V.titleHubReason))
end

-- This decorates engine-owned native UI states and supplies the two optional
-- draw-only Bag adapters. GAME/KASC is the Bag default; all unsupported values,
-- missing assets and draw failures return to the exact captured owner renderer.
-- KASC remains an optional public claimant; no private module is imported.
local uiSkinInstalled, uiSkinReason = OrasUiSkin.install({
  mod=mod,
  bagSkin=OrasBagSkin,
  frlgBagSkin=OrasFrlgBagSkin,
  manualBagSort=ManualBagSort,
  mobileMenuPresentation=MobileMenuPresentation,
})
if not uiSkinInstalled and mod.log and type(mod.log.warn) == "function" then
  mod.log:warn("VASC native ORAS UI skin failed open: %s", tostring(uiSkinReason))
end

-- Restore the reviewed A21 Gen-1 START contract: SELECT switches between the
-- field-edge view and the complete Ascendant menu without changing any native
-- row, callback or navigation behavior. The selected mode persists per save.
local startModeInstalled, startModeReason = StartMenuMode.install()
V.require("FieldKitPresentation").install()
V.germanUiInstalled, V.germanUiReason = V.Gen1GermanUiCompat.install()
if not startModeInstalled and mod.log and type(mod.log.warn) == "function" then
  mod.log:warn("VASC persistent Gen-1 START presentation failed open: %s",
    tostring(startModeReason))
end
if not V.germanUiInstalled and mod.log and type(mod.log.warn) == "function" then
  mod.log:warn("VASC Gen-1 German UI compatibility failed open: %s",
    tostring(V.germanUiReason))
end

local bagSortInstalled, bagSortReason = ManualBagSort.installPointer(mod, {
  pointerToLogical=MobileMenuPresentation.pointerToLogical,
})
if not bagSortInstalled and mod.log and type(mod.log.warn) == "function" then
  mod.log:warn("VASC manual Bag sort pointer failed open: %s",
    tostring(bagSortReason))
end
local evolutionPresentationInstalled, evolutionPresentationReason =
  EvolutionPresentation.install(mod)
if not evolutionPresentationInstalled and mod.log
    and type(mod.log.warn) == "function" then
  mod.log:warn("VASC Evolution presentation failed open: %s",
    tostring(evolutionPresentationReason))
end
local moveLearnPresentationInstalled, moveLearnPresentationReason =
  MoveLearnPresentation.install(mod)
if not moveLearnPresentationInstalled and mod.log
    and type(mod.log.warn) == "function" then
  mod.log:warn("VASC Move Learn presentation failed open: %s",
    tostring(moveLearnPresentationReason))
end

-- Install while the content registries are still writable. The hook replaces
-- no Start-menu descriptor: it wraps the canonical POKéMON callback and skins
-- only the PartyMenu instance that callback actually pushed.
local partySkinInstalled, partySkinReason = PartyMenuSkins.install()
if not partySkinInstalled and mod.log and type(mod.log.warn) == "function" then
  mod.log:warn("VASC Start PartyMenu skins failed open: %s",
    tostring(partySkinReason))
end

-- ORAS Storage UI 0.5.3 is integrated below as draw-only providers on the
-- engine/KASC-owned PC, Legacy Bank and Party hosts.  Its retired standalone
-- prototype also added a direct ORAS STORAGE row to the field Start menu.
-- The manifest replaces that package, but filter its stable public marker as
-- a fail-safe when an older launcher nevertheless activates both mods.  PC
-- access remains at an actual terminal; this never removes native/KASC rows.
if mod.hooks and type(mod.hooks.wrap) == "function" then
  mod.hooks:wrap("ui.start_menu.items", function(nextItems, game, items)
    local out = nextItems(game, items)
    if type(out) ~= "table" then return out end
    local filtered, changed = {}, false
    for _, row in ipairs(out) do
      local retired = type(row) == "table"
        and (row.ascendantKey == "vasc_oras_storage_ui"
          or row.label == "ORAS STORAGE")
      if retired then changed = true else filtered[#filtered + 1] = row end
    end
    return changed and filtered or out
  end, 2000)
end

-- ------- this mod's hotkeys
--
-- 3/V  VOXEL    cycle the camera ladder      (was 6; skips FULL)
--   5  V-GRID   toggle the wireframe         (new)
--   6  T-SHIFT  cycle the blur ladder        (was 9)
--   7  V-CURVE  cycle the horizon bend       (new)
--   8  3D-BTL   cycle overworld battles      (new)
--   9  WATER    cycle the water reflections  (new; 9 was T-SHIFT's old key)
--
-- Only 6 arrives by the documented route. Game:keypressed answers the
-- engine's own display keys FIRST and returns -- 2 COLORS, 3 TILT, 4 ZOOM,
-- 5 GBC FX -- and only then offers the key to Pipelines.hotkey, expressly
-- so "a pipeline can never shadow one" (Schemas, render_pipelines.hotkey).
-- 3 and 5 are two of those, and 7 and 8 belong to plain mod settings that
-- own no pass and so have no registry to claim a key from at all.
--
-- So this wraps Game:keypressed. It is the invasive option and it is the
-- only one: polling the keyboard in update() would fire alongside the
-- engine's handler rather than instead of it, so 3 would cycle this mode
-- AND the engine's TILT on the same press.
--
-- Consequences worth being explicit about: while this mod is enabled, TILT
-- (3) and GBC FX (5) are unreachable by key -- and unreachable on the OPTIONS
-- menu too, where both rows are taken away and both values held at zero (see
-- pinEngineFx). Nothing is being hidden that still does something: TILT is the
-- flat fake of what this mode does for real, the registry already forces it
-- off whenever a world pipeline takes the pass, and GBC FX is a full-screen
-- present pass over the top of the diorama. Uninstalling puts both back.
--
-- Everything the engine does around a pipeline hotkey has to happen here
-- too, so the work is DELEGATED rather than reimplemented: Pipelines.hotkey
-- applies its own gate and ladder, and the three lines after it are the
-- engine's own (syncOptions, the tilt exclusion, writeOptions).

local HOTKEYS = {
  ["3"] = "pipeline",           -- voxel, by its declared hotkey
  ["6"] = "pipeline",           -- tiltshift, likewise
  ["5"] = VoxelGrid.setting,
  ["7"] = WorldCurve.setting,
  ["8"] = OverworldBattle.setting,
  ["9"] = Water.setting,
}

-- One step of the VOXEL angle ladder: everything a "3", dedicated V-key or
-- right-trigger press does. The gate is the registry's own; the tilt/GBC FX
-- clearing is the engine work the key has always delegated (see the wrap
-- below for why). SELECT deliberately remains entirely game/KASC-owned.
local function cycleVoxel(game)
  local Pipelines = require("src.render.Pipelines")
  local top = game.stack and game.stack:top()
  if not Pipelines.canToggle("voxel", top, game.overworld) then return false end
  local nextLevel = Voxel.nextHotkeyLevel(Pipelines.level("voxel"))
  Pipelines.setLevel("voxel", nextLevel)
  Pipelines.syncOptions(game.save.options)
  -- 3 is the key that used to turn TILT on and sits next to the one that
  -- used to turn GBC FX on, and this mod has taken both away. A player who
  -- left either running before enabling the mod would otherwise have no
  -- way back to off, and both fight the diorama -- so the VOXEL step
  -- clears them on EVERY press, not just the press that switches on.
  game.save.options.tilt = 0
  EngineFxCompat.disable(game.save.options)
  require("src.render.Tilt").setLevel(game.save.options.tilt or 0)
  game:writeOptions()
  ShortcutToast.notify("VOXEL VIEW",
    Voxel.ANGLE_LABELS[nextLevel + 1] or tostring(nextLevel))
  return true
end

do
  local Game = require("src.core.Game")
  local Pipelines = require("src.render.Pipelines")
  local Tilt = require("src.render.Tilt")
  local inner = Game.keypressed
  local pipelineShape = type(Pipelines.canToggle) == "function"
                        and type(Pipelines.hotkey) == "function"
                        and type(Pipelines.syncOptions) == "function"
                        and type(Pipelines.setLevel) == "function"
                        and type(Pipelines.level) == "function"
                        and type(Tilt.setLevel) == "function"

  if pipelineShape and type(inner) == "function"
     and not Game.voxelAscendantKeyHook then
    function Game:keypressed(key, ...)
      local claim = HOTKEYS[key]
      local top = self.stack and self.stack:top()
      -- Q/E control whichever camera is currently in front: the staged
      -- battle lens, the third-person boom, or the regular survey zoom.
      if (key == "q" or key == "e")
         and not (top and top.onKeyPressed) then
        if CamControl.zoomBy(key == "q" and 1 or -1) then
          ShortcutToast.notify("VOXEL CAMERA", key == "q" and "ZOOM IN" or "ZOOM OUT")
          return
        end
      end
      -- A screen with its own key handler gets the key first, exactly as the
      -- engine's first branch does: typing a nickname must not toggle a
      -- render mode. Only free-roam presses are ours to take.
      if claim and not (top and top.onKeyPressed) then
        if claim == "pipeline" then
          -- 3 walks the ANGLE rungs and steps over FULL (Voxel.HOTKEY_ORDER),
          -- so the registry's plain "advance one and wrap" is not what it
          -- wants; 6 still is. The gate is the registry's own either way.
          if key == "3" then
            if cycleVoxel(self) then return end
          elseif Pipelines.hotkey(key, top, self.overworld) then
            Pipelines.syncOptions(self.save.options)
            require("src.render.Tilt").setLevel(self.save.options.tilt or 0)
            self:writeOptions()
            return
          end
        elseif Pipelines.canToggle("voxel", top, self.overworld) then
          claim:cycle(self)
          local at = claim.read and claim:read() or nil
          ShortcutToast.notify(claim.label or "VOXEL ASCENDANT",
            at and claim.labels and claim.labels[at] or tostring(claim.get and claim:get()))
          if stagedBattles() then OverworldBattle.forceOG(self) end
          return
        end
      end
      return inner(self, key, ...)
    end
    Game.voxelAscendantKeyHook = true
  end
end

-- ------- the mode's rows, kept together
--
-- The engine splices a pipeline's row in beside TILT, because a display mode
-- belongs with the other display modes; a mod's own ui.options.rows
-- additions land at the END of the list. That left this mod's four rows in
-- two places with unrelated engine rows between them, which reads as two
-- unrelated features rather than one mode with settings.
--
-- So the plain settings are inserted directly after the last of this mod's
-- PIPELINE rows instead of appended. Nothing else moves: the block lands
-- where the engine already decided display modes go.
local function insertGrouped(out, extra)
  local anchor = nil
  for i, row in ipairs(out) do
    local id = type(row) == "table" and row.id
    if id == "pipeline:voxel" or id == "pipeline:tiltshift" then anchor = i end
  end
  if not anchor then
    for _, row in ipairs(extra) do out[#out + 1] = row end
    return out
  end
  for i, row in ipairs(extra) do table.insert(out, anchor + i, row) end
  return out
end

-- FULL owns the settings that describe the LOOK, so while it is selected those
-- are taken off the menu rather than left to be changed under it -- including
-- T-SHIFT, which is a pipeline row the engine put there. A row that no longer
-- decides anything is worse than no row.
--
-- The battle rows are the exception and they stay; see the rows hook.
local function dropRow(out, id)
  for i = #out, 1, -1 do
    if type(out[i]) == "table" and out[i].id == id then table.remove(out, i) end
  end
  return out
end

-- ------- TILT and GBC FX are gone while this mod is installed
--
-- Both fight the diorama, and both were already half-taken: the mode's own key
-- (3) forces them off on every press, and the registry switches TILT off
-- whenever a world pipeline takes the pass. What was left was two rows the
-- player could set and watch get reverted -- TILT is the flat fake of what
-- this mode does for real, and GBC FX is a full-screen present pass over the
-- top of the whole thing.
--
-- So they come OFF the menu, and are HELD at zero rather than merely dropped.
-- Hiding a live setting is a trap: a save written before the mod was installed
-- can carry TILT 3, and a row that is not there is a row that cannot turn it
-- back off. Pinned wherever the value could have arrived from -- the menu
-- opening, a save being loaded or begun -- so there is no route by which one
-- of them is on and unreachable.
--
-- Everything they did is still reachable: uninstall the mod and both rows are
-- back, at whatever they were last set to.
-- BATTLE BG rides the same reasoning, and comes off for a reason of its own.
-- The row picks what fills the screen AROUND the battle's 160x144 field --
-- WHITE paper, BLACK bars, or the frozen overworld dimmed behind it -- and
-- all three were answers to the same question: what to do with the voids,
-- given the battle is a small picture in the middle of a big window.
--
-- This mod answers that question differently and permanently. A staged fight
-- fills the whole window with the map the fight is standing on, and the
-- flat battle screen it composites over it is drawn on the mode's own
-- surface; there are no voids left for the row to fill. WORLD is the worst
-- of the three under it -- it makes the battle non-opaque so the engine
-- draws the overworld underneath, which is a SECOND copy of the world drawn
-- under the one the arena pass already put there, dimmed and at a different
-- camera. BLACK bars over a diorama read as a letterboxed screenshot.
--
-- So the value is pinned at WHITE, which is the one the mode was composed
-- against, and the row comes off the menu on the same reasoning as TILT and
-- GBC FX: a row that no longer decides anything is worse than no row.
-- Uninstall the mod and it is back, at whatever it was last set to.
local function pinEngineFx(game)
  game = game or require("src.core.Game")
  local opts = game and game.save and game.save.options
  local Tilt = require("src.render.Tilt")
  local changed = false
  if opts then
    changed = (opts.tilt or 0) ~= 0 or (opts.gbcfx or 0) ~= 0
                or (opts.battleBg or "white") ~= "white"
    opts.tilt, opts.gbcfx = 0, 0
    opts.battleBg = "white"
  end
  pcall(Tilt.setLevel, 0)
  if EngineFxCompat.disable(opts) then changed = true end
  if changed and game.writeOptions then pcall(game.writeOptions, game) end
end

-- call next() first and decorate what comes back, so every other mod's
-- rows survive this one
mod.hooks:wrap("ui.options.rows", function(next, game, rows)
  local out = next(game, rows)
  if type(out) ~= "table" then return out end
  local Pipelines = require("src.render.Pipelines")
  -- ahead of every branch below, including FULL's early return: these two are
  -- off the menu whatever else this mod is or is not doing
  pinEngineFx(game)
  dropRow(out, "tilt")
  for _, id in ipairs(EngineFxCompat.ROW_IDS) do dropRow(out, id) end
  -- and BATTLE BG with them: this mode fills the window with the map, so
  -- the row's whole question -- what to put in the voids around the battle
  -- -- no longer has voids to be about (see pinEngineFx)
  dropRow(out, "battleBg")
  -- BATTLE LAYOUT is the ENGINE's row, and this is the one place the mod takes
  -- one away. While a fight can be staged on the map, OG is the only layout it
  -- can be composed in (OverworldBattle.forceOG), so the value is pinned there
  -- and the row comes off the list on the same reasoning as the rows FULL owns:
  -- a row that no longer decides anything is worse than no row. Nothing is
  -- lost by switching 3D-BTL off -- the row is back, WIDE and all, on the same
  -- keypress.
  if stagedBattles() then
    OverworldBattle.forceOG(game)
    dropRow(out, "battleLayout")
  end
  local full = Voxel.isFull(Pipelines.level("voxel"))
  if full then
    -- FULL owns the rows that PARAMETERISE the diorama -- the wireframe, the
    -- horizon bend and blur -- so those come off the menu. DAYTIME remains
    -- available because the complete preset now includes the running clock.
    dropRow(out, "pipeline:tiltshift")
  end
  local extra = {}
  for _, entry in ipairs(SETTINGS) do
    -- Two things decide whether a row is offered.
    --
    -- FULL: a preset that owns the look, so the rows that describe the look go
    -- with it. The BATTLE rows are not that -- 3D-BTL decides what a fight is
    -- drawn over and TRAINER/PKMN BACK how it is framed; neither is a knob on
    -- the diorama FULL is a preset for. FULL still SETS them on arrival (see
    -- applyFull); it does not hold them, so leaving them on the menu is the
    -- difference between a preset and a lock.
    --
    -- And a row whose own switch is off the table this frame (the two BACK
    -- rows need a staged fight to be about) is left off with it. The mod
    -- manager's page carries every one of them either way.
    local offered = (entry.full or not full)
                    and (not entry.when or entry.when())
    if offered then
      extra[#extra + 1] = entry.row and entry.row() or entry[1]:row()
    end
  end
  -- One source owner replaces the former three independent pack/music/sprite
  -- switches. Optional KASC/RETRO sources register public receipts; CUSTOM
  -- consumes the documented user folders materialised by the selector app.
  extra[#extra + 1] = LocalContent.row(mod)
  return insertGrouped(out, extra)
end)

-- The mod manager writes and persists on its own, so the only thing left
-- to do is move our cached index and pick the new value up.
mod.events:on("mod.options_changed", function(payload)
  if not (payload and payload.mod == mod.id) then return end
  for _, entry in ipairs(SETTINGS) do
    if payload.key == entry[1].key then entry[1]:sync(payload.value) end
  end
  BattleLayout.syncOption(payload.key, payload.value)
  if payload.key == LedgeElevation.setting.key then
    ChunkMesher.invalidate()
    HorizonWall.invalidate()
  end
  DeviceProfile.externalChanged(require("src.core.Game"),
                                payload.key, payload.value)
  -- 3D-BTL switched on from the manager's page pins BATTLE LAYOUT exactly as
  -- the OPTIONS row does. The manager persists its own value; this is the one
  -- that has to follow it.
  if stagedBattles() then OverworldBattle.forceOG() end
end)

-- ------- keeping the geometry in step with the world
--
-- Terrain meshes are derived from a map's block layer, so anything that
-- rewrites a block (a cut tree, a smashed rock, a script's replaceBlock)
-- has to drop that map's cached mesh or the 3D world keeps showing the
-- tree that is no longer there.  The 2D tile renderer invalidates its own
-- caches off the same edit.

-- refresh, not invalidate: the stale mesh keeps drawing while the
-- replacement builds in the background, so a one-block edit (Cut, a
-- door stamp, the tree regrowing on re-entry) repopulates in place
-- instead of blinking the whole scene down to the flat 2D path
mod.events:on("world.block_replaced", function(payload)
  local mapId = payload and (payload.mapId or (payload.map and payload.map.id))
  if mapId then
    ChunkMesher.refresh(mapId)
    local map = payload and payload.map
    if not map then
      local Game = require("src.core.Game")
      local active = Game and Game.overworld and Game.overworld.map
      if active and active.id == mapId then map = active end
    end
    if HorizonWall.blockAffectsGeometry(
         map, payload and payload.bx, payload and payload.by) then
      HorizonWall.invalidateMap(mapId)
    end
  end
end)

-- The event above is the ANNOUNCED edit -- OverworldState:replaceBlock
-- emits it, which is the path Victory Road's barriers and a script's
-- replaceBlock take. Several edits do not go through it:
--
--   Cut          swaps the tree block and rebuilds the 2D renderer
--   the regrowth restores those blocks when the map is re-entered
--   card-key doors are stamped closed on floor load
--
-- all of them writing the block layer directly. Meshes derived from that
-- layer went stale with no announcement -- the cut tree stayed standing,
-- and after a round trip through a door the stump stayed cut because this
-- map's mesh survives in the cache (that is what prevLive is for).
--
-- The engine could announce each of those, and an earlier cut of this
-- work changed it to. That is the wrong place: it edits the game for one
-- mod's benefit, and every future path that writes a block has to
-- remember to do the same. They all funnel through ONE choke point --
-- Map:setBlock -- so wrap that from here instead. Map is a plain
-- metatable shared by every map instance, so this covers all of them,
-- including paths written after this mod.
--
-- Read back rather than trust the argument: setBlock silently ignores an
-- out-of-bounds write, and a stamp that rewrites a block with the value
-- it already held (the door code guards for this, the regrowth does not)
-- is not a change and must not throw the mesh away.
do
  local Map = require("src.world.Map")
  if not Map.voxelAscendantBlockHook
     and type(Map.setBlock) == "function"
     and type(Map.blockAt) == "function" then
    local setBlock = Map.setBlock
    Map.setBlock = function(self, bx, by, block, ...)
      local before = self:blockAt(bx, by)
      local results = packValues(setBlock(self, bx, by, block, ...))
      if self.id and self:blockAt(bx, by) ~= before then
        ChunkMesher.refresh(self.id)
        if HorizonWall.blockAffectsGeometry(self, bx, by) then
          HorizonWall.invalidateMap(self.id)
        end
      end
      return unpackValues(results, 1, results.n)
    end
    Map.voxelAscendantBlockHook = true
  end
end

-- A reloaded map is rebuilt from scratch (warps that re-enter the same map,
-- hot reload), so its mesh is stale for the same reason -- with one
-- exception, and it is the common one.
--
-- A palette switch reloads the map ONLY to rebuild its atlas
-- (PaletteFX.setMode -> reloadMap(id, "colors")). The geometry that comes
-- back is identical: this mesher reads block layout and tile ids and never
-- reads colour, and the palette lives entirely in the texture TerrainAtlas
-- hands back per frame -- which is keyed BY palette, so the new colours are
-- already built by the time the next frame draws.
--
-- Dropping the mesh anyway cost a visible flash of the flat 2D world on
-- every palette toggle. Mesh builds are asynchronous, so the frames between
-- the drop and the first finished mesh have no terrain to draw, and
-- drawWorld returning nil IS the 2D fallback. Keeping the geometry lets the
-- new colours land on the diorama already on screen, in one frame, which is
-- what a palette toggle should look like from inside voxel mode.
mod.events:on("map.reloaded", function(payload)
  if payload and payload.reason == "colors" then return end
  local mapId = payload and (payload.mapId or (payload.map and payload.map.id))
  if mapId then
    ChunkMesher.invalidate(mapId)
    HorizonWall.invalidateMap(mapId)
  end
end)

-- ------- rows come and go, so the menu has to notice
--
-- OptionsMenu builds its row list ONCE, when it is opened, and then reads
-- that list every frame. So stepping the VOXEL row onto or off FULL changed
-- which rows the hook would return but not which rows were on screen -- the
-- settings FULL owns stayed visible until the menu was closed and reopened,
-- and a player who stepped off FULL could not see the rows come back.
--
-- Rebuilt in place, and only on a step that changes the LIST: crossing FULL,
-- or toggling 3D-BTL, which is the other row that owns one (BATTLE LAYOUT).
-- Every other rung returns the same list, and rebuilding on all of them would
-- rerun every mod's ui.options.rows hook once per keypress. The cursor is
-- clamped rather than reset, so it stays on the row it was just used on
-- instead of jumping to the top when the list below it shortens.
do
  local OptionsMenu = require("src.ui.OptionsMenu")
  local Pipelines = require("src.render.Pipelines")
  if not OptionsMenu.voxelAscendantFullHook
     and type(OptionsMenu.update) == "function"
     and type(OptionsMenu.new) == "function"
     and type(Pipelines.level) == "function" then
    local inner = OptionsMenu.update

    local function idAt(menu, index)
      local row = menu.rows and menu.rows[index or 1]
      return type(row) == "table" and row.id or nil
    end

    function OptionsMenu:update(dt, ...)
      local before = Pipelines.level("voxel")
      local hadBattles = OverworldBattle.enabled()
      local hadArena = OverworldBattle.arenaMode()
      local wasOn = idAt(self, self.index)
      local results = packValues(inner(self, dt, ...))
      local after = Pipelines.level("voxel")
      local crossedFull = after ~= before
                          and (Voxel.isFull(before) or Voxel.isFull(after))
      if crossedFull or OverworldBattle.enabled() ~= hadBattles
         or OverworldBattle.arenaMode() ~= hadArena then
        local rebuilt = OptionsMenu.new(self.game)
        self.rows = rebuilt.rows
        -- Follow the row the cursor was ON rather than the slot it was in:
        -- 3D-BTL takes BATTLE LAYOUT off the list ABOVE itself, which would
        -- otherwise slide the cursor onto the row under the one just used.
        for i = 1, #self.rows do
          if wasOn and idAt(self, i) == wasOn then self.index = i; break end
        end
        local cancel = #self.rows + 1
        if (self.index or 1) > cancel then self.index = cancel end
      end
      return unpackValues(results, 1, results.n)
    end

    OptionsMenu.voxelAscendantFullHook = true
  end
end

-- ------- battles on the map
--
-- The wraps this needs -- OverworldState:pushBattle, BattleState:draw and
-- BattleState:drawHUDs -- all live in lib/OverworldBattle.lua, which is
-- where the reasoning for each one is written down. Installed once, here,
-- so this file keeps naming every engine seam the mod touches.
local AscendantCards = nil
local battleLifecycleRegistered, battleLifecycleRegisterReason = false, nil
local battleLatchDiagnosticsRegistered,
  battleLatchDiagnosticsRegisterReason = false, nil
local battleOverlayRegistered, battleOverlayRegisterReason = false, nil
local NativeBattleCleanup, nativeBattleCleanupReason = nil, nil
local battleRuntimeInstalled, battleRuntimeInstallReason =
  OverworldBattle.install()
V.stadiumRomOptionsInstalled = V.StadiumRomMenu.installOptionsHook(mod)
-- The regular OPTIONS hook above is only a compatibility surface. Current
-- builds expose each mod's own option rows through ManagerState, so Gen 1 must
-- install the same action-row bridge as Gen 2 or the bundled Stadium-2
-- importer remains present but unreachable from VASC's menu.
V.stadiumRomManagerOptionsInstalled =
  V.StadiumRomMenu.installModManagerOptions(mod)
if mod.events and type(mod.events.on) == "function" then
  mod.events:on("game.ready", function(game)
    -- Stadium's shared actor path needs the live Gen1 species catalogue.
    -- The safe Stadium-2 bind-pose policy comes from stadium2ForGen1 above,
    -- not Gold's game.world field (Gen1 owns game.overworld).
    V.game = game
    pcall(V.StadiumRomMenu.poll, game)
  end)
end
local battleRuntimeInstallStatus = OverworldBattle.battleLifecycleHealth()
local nativeCleanupPermitted = battleRuntimeInstalled
  or battleRuntimeInstallStatus.runtimeState == "unsupported"
if not battleRuntimeInstalled and mod.log
    and type(mod.log.error) == "function" then
  mod.log:error("Gen-1 battle runtime unavailable; native DEFAULT only until "
    .. "process restart: %s", tostring(
      battleRuntimeInstallReason or "required engine seam unavailable"))
end

-- Bind the process lease's teardown immediately after the irreversible class
-- wrappers are installed. The captured owner variables are populated below;
-- if any later top-level installer throws, a re-entry can still deactivate
-- every Card/native listener which had already been created before the throw.
if battleRuntimeInstalled then
  local retireBound, retireBindReason =
    OverworldBattle.setRuntimeRetireCallback(function(reason)
      local cardStopped, cardStopReason = true, nil
      if AscendantCards and battleLifecycleRegistered then
        local report = AscendantCards:deactivateAll(
          { generation=1, host="VOXEL_ASCENDANT", reentry=true },
          reason or "battle-runtime-retired")
        cardStopped = type(report) == "table"
          and type(report.errors) == "table" and #report.errors == 0
        if not cardStopped then
          local errors = {}
          for _, failure in ipairs(report and report.errors or {}) do
            errors[#errors + 1] = tostring(failure.id) .. ": "
              .. tostring(failure.error)
          end
          cardStopReason = table.concat(errors, "; ")
        end
      end
      local cleanupStopped = true
      local nativeOwner = nil
      if NativeBattleCleanup
          and type(NativeBattleCleanup.deactivate) == "function" then
        local called, value, retiredOwner = pcall(
          NativeBattleCleanup.deactivate)
        -- `false` means the adapter was already inactive; that is still a
        -- fully retired owner. Only an exception leaves its state uncertain.
        cleanupStopped = called and (value == true or value == false)
        if called and type(retiredOwner) == "table" then
          nativeOwner = retiredOwner
        end
      end
      if not cardStopped and mod.log and type(mod.log.warn) == "function" then
        mod.log:warn("battle lifecycle Card retirement failed: %s",
          tostring(cardStopReason))
      end
      return cardStopped == true and cleanupStopped, nativeOwner
    end)
  if not retireBound and mod.log and type(mod.log.error) == "function" then
    mod.log:error("battle runtime owner retirement hook unavailable: %s",
      tostring(retireBindReason))
  end
end
BattlePartyBalls.setHudOwnerPredicate(function()
  return OrasBattleHudSettings.vascOwnsHud(mod)
end)
BattleHudExtras.setHudOwnerPredicate(function()
  return OrasBattleHudSettings.vascOwnsHud(mod)
end)
BattlePartyBalls.install()
BattleHudExtras.install(mod, OverworldBattle)
BattleMusic.install(mod)
LocalContent.install(mod)
LocalMusic.install(mod)
AmbientAudio.install(mod)
LocalSprites.install(mod)
local function finishBattleContent()
  BattleMusic.finish()
  LocalContent.finish()
end
if nativeCleanupPermitted then
  NativeBattleCleanup, nativeBattleCleanupReason =
    Gen1NativeBattleCleanup.install(mod, {
      renderer=OverworldBattle,
      lifecycle=Gen1BattleLifecycle,
      finishContent=finishBattleContent,
    })
else
  -- A rejected re-entry has no lease of its own and could never retire a new
  -- listener set on a third load. Keep that instance entirely listener-free;
  -- the process-level diagnostic above makes the required restart explicit.
  nativeBattleCleanupReason = battleRuntimeInstallReason
    or "battle wrapper runtime unavailable"
end
if not NativeBattleCleanup and mod.log
    and type(mod.log.error) == "function" then
  mod.log:error("native battle cleanup adapter unavailable: %s",
    tostring(nativeBattleCleanupReason))
end
-- Renderer, Card and native fallback all converge on one exact BattleState
-- tombstone.  Keep the historical raw callback only as the fail-open seam
-- when the coordinator itself could not be installed.
OverworldBattle.setReplacementCleanup(
  NativeBattleCleanup and NativeBattleCleanup.finishExact
    or finishBattleContent)
OverworldBattle.setNativeBattlePreflight(
  battleRuntimeInstalled and NativeBattleCleanup
    and NativeBattleCleanup.beforeBattle)

-- RC11's first real card owns the complete Gen-1 battle event boundary.
-- Renderer code remains unchanged behind the injected adapter, while the
-- registry now has enough lifecycle information to deactivate/abort it and
-- remove every event/hook token deterministically.
AscendantCards = AscendantCardRegistry.new({
  onHookError=function(event, failure)
    if mod.log and type(mod.log.warn) == "function" then
      mod.log:warn("Ascendant hook %s owner %s failed open: %s",
        tostring(event), tostring(failure and failure.owner),
        tostring(failure and failure.error))
    end
  end,
})
local defaultProviderRegistered, defaultProviderRegisterReason =
  AscendantCards:register(Gen1DefaultBattleProviderCard.descriptor())
local discsProviderRegistered, discsProviderRegisterReason =
  AscendantCards:register(Gen1DiscsBattleProviderCard.descriptor({
    renderer=OverworldBattle,
  }))
local battleRouterRegistered, battleRouterRegisterReason =
  AscendantCards:register(Gen1BattleRouterCard.descriptor())
battleLifecycleRegistered, battleLifecycleRegisterReason =
  AscendantCards:register(Gen1BattleLifecycleCard.descriptor({
    mod=mod,
    renderer=OverworldBattle,
    lifecycle=Gen1BattleLifecycle,
    finishContent=finishBattleContent,
    contentCoordinator=NativeBattleCleanup,
  }))
battleLatchDiagnosticsRegistered, battleLatchDiagnosticsRegisterReason =
  AscendantCards:register(Gen1BattleLatchDiagnosticsCard.descriptor({
    renderer=OverworldBattle,
    diagnostics=Diagnostics,
  }))
battleOverlayRegistered, battleOverlayRegisterReason =
  AscendantCards:register(Gen1BattleOverlayCard.descriptor({
    renderer=OverworldBattle,
  }))
local dragoniteFlyRegistered, dragoniteFlyRegisterReason =
  AscendantCards:register(Gen1DragoniteFlyCard.descriptor({
    pokemon=mod.content and mod.content.pokemon,
  }))
if not defaultProviderRegistered then
  battleLifecycleRegisterReason = "DEFAULT provider registration failed: "
    .. tostring(defaultProviderRegisterReason)
elseif not discsProviderRegistered then
  battleLifecycleRegisterReason = "DISCS provider registration failed: "
    .. tostring(discsProviderRegisterReason)
elseif not battleRouterRegistered then
  battleLifecycleRegisterReason = "battle router registration failed: "
    .. tostring(battleRouterRegisterReason)
end
if not defaultProviderRegistered or not discsProviderRegistered
    or not battleRouterRegistered then
  battleLifecycleRegistered = false
end
if not battleLifecycleRegistered then
  OverworldBattle.setBattleLifecycleReady(false,
    battleLifecycleRegisterReason or "battle lifecycle registration failed")
  if mod.log and type(mod.log.error) == "function" then
    mod.log:error("battle lifecycle card registration failed closed: %s",
      tostring(battleLifecycleRegisterReason))
  end
end
if not battleOverlayRegistered and mod.log
    and type(mod.log.warn) == "function" then
  mod.log:warn("read-only battle overlay capability unavailable; companions "
    .. "remain native: %s", tostring(battleOverlayRegisterReason))
end
if not battleLatchDiagnosticsRegistered and mod.log
    and type(mod.log.warn) == "function" then
  mod.log:warn("battle latch diagnostics Card registration failed open: %s",
    tostring(battleLatchDiagnosticsRegisterReason))
end

-- Weather Music is an independent five-Card graph.  It deliberately does not
-- share the battle registry: a battle-owner rollback must never retire the
-- weather catalog/option, and a missing audio capability must never touch the
-- already proven battle lifecycle.  The only engine hook is installed by the
-- terminal playback adapter after all four data/UI providers are active.
local WeatherMusicCards = AscendantCardRegistry.new({
  onHookError=function(event, failure)
    if mod.log and type(mod.log.warn) == "function" then
      mod.log:warn("Weather Music Card hook %s owner %s failed open: %s",
        tostring(event), tostring(failure and failure.owner),
        tostring(failure and failure.error))
    end
  end,
})
local weatherMusicDocument, weatherMusicDocumentReason
do
  local ok, value = pcall(V.data, "gen1_weather_music")
  if ok and type(value) == "table" then weatherMusicDocument = value
  else weatherMusicDocumentReason = ok and "catalog did not return a table"
    or tostring(value) end
end
local weatherMusicDescriptors = {
  Gen1WeatherMusicPackageAssetsCard.descriptor({
    document=weatherMusicDocument, mod=mod,
  }),
  Gen1WeatherMusicCatalogCard.descriptor(),
  Gen1WeatherMusicRouterCard.descriptor(),
  Gen1WeatherMusicOptionUiCard.descriptor(),
  Gen1WeatherMusicPlaybackAdapterCard.descriptor({
    mod=mod, music=require("src.core.Music"), diagnostics=Diagnostics,
  }),
}
local weatherMusicRegistered, weatherMusicRegisterReason =
  weatherMusicDocument ~= nil, weatherMusicDocumentReason
for _, descriptor in ipairs(weatherMusicDescriptors) do
  if weatherMusicRegistered then
    local registered, reason = WeatherMusicCards:register(descriptor)
    if not registered then
      weatherMusicRegistered = false
      weatherMusicRegisterReason = descriptor.id .. ": " .. tostring(reason)
    end
  end
end
local weatherMusicActive, weatherMusicActivateReason = false, nil
if weatherMusicRegistered then
  weatherMusicActive, weatherMusicActivateReason = WeatherMusicCards:activate(
    Gen1WeatherMusicPlaybackAdapterCard.ID,
    { generation=1, host="VOXEL_ASCENDANT" })
end
if weatherMusicActive then
  local capability = WeatherMusicCards:capability(
    Gen1WeatherMusicPlaybackAdapterCard.CAPABILITY)
  WeatherMusicPlayback = capability and capability.value or nil
  weatherMusicActive = WeatherMusicPlayback ~= nil
  if not weatherMusicActive then
    weatherMusicActivateReason = "playback capability was not published"
  end
end
if not weatherMusicActive then
  local rollback = WeatherMusicCards:deactivateAll(
    { generation=1, host="VOXEL_ASCENDANT" }, "graph-activation-failed")
  if rollback and #rollback.errors > 0 and mod.log
      and type(mod.log.warn) == "function" then
    mod.log:warn("Gen-1 Weather Music provider rollback incomplete: %s",
      tostring(rollback.errors[1] and rollback.errors[1].error
        or "unknown rollback error"))
  end
end
if not weatherMusicActive and mod.log and type(mod.log.warn) == "function" then
  mod.log:warn("Gen-1 Weather Music failed open to native map music: %s",
    tostring(weatherMusicActivateReason or weatherMusicRegisterReason
      or "unavailable"))
end
-- Register the diagnostic inventory only after the terminal activation has
-- either activated all five dependencies or rolled them back.  Reporting a
-- merely registered provider as active would make a failed-open audio host
-- look healthy in the support receipt.
for _, descriptor in ipairs(weatherMusicDescriptors) do
  local cardState = WeatherMusicCards:state(descriptor.id)
  local cardActive = cardState == "active"
  Diagnostics.registerSegment({
    segmentId=descriptor.id, cardId=descriptor.id,
    version=descriptor.version, schema=descriptor.schema,
    owner=descriptor.owner, active=cardActive,
    dependencyStatus=cardState or "not-registered",
    providerStatus=cardActive and "VASC-only-active"
      or "VASC-only-failed-open",
    buildReceiptId="WEATHER-MUSIC-GEN1-20260903",
    rollbackReceiptId="WEATHER-MUSIC-GEN1-ROLLBACK-20260903",
  })
end
mod.exports.weatherMusic = {
  schema="voxel-ascendant/weather-music-host/v1",
  apiVersion=1,
  active=weatherMusicActive,
  status=function()
    if WeatherMusicPlayback and type(WeatherMusicPlayback.status) == "function" then
      return WeatherMusicPlayback.status()
    end
    return { schema="voxel-ascendant/weather-music-playback/v1",
      apiVersion=1, ok=false, state="unavailable",
      error=tostring(weatherMusicActivateReason or weatherMusicRegisterReason
        or "unavailable") }
  end,
}
VascMenu.install(mod, {
  settings=SETTINGS,
  menuSkinSetting=VascMenuSkinSetting,
  battleLayout=BattleLayout,
  diagnostics=Diagnostics,
  performanceDiagnostics=PerformanceDiagnostics,
  mobileDiagnostic=MobileDiagnostic,
  -- MOBILE TRACE and REARM remain behind ADVANCED -> RC DIAGNOSTICS.
  prominentMobileTrace=false,
  resumeLastSection=false,
  version=PACKAGE_VERSION,
  contentProfileRow=function() return LocalContent.row(mod) end,
  stadiumRomMenu=V.StadiumRomMenu,
  pipelineHelp={
    ["pipeline:voxel"] = "Choose the Voxel Ascendant camera ladder: OFF, "
      .. "orbit views, first person, third person or the complete FULL preset.",
    ["pipeline:tiltshift"] = "Apply the saved miniature-depth post-process "
      .. "to the voxel world while keeping menus and battle text crisp.",
  },
  pipelineHelpDe={
    ["pipeline:voxel"] = "Wähle die Voxel-Kameraleiter: OFF, Orbitansichten, "
      .. "Ego-, Verfolgeransicht oder das vollständige FULL-Preset.",
    ["pipeline:tiltshift"] = "Miniatur-Tiefenunschärfe nur auf der Voxelwelt; "
      .. "Menüs, Kampftext und HUD bleiben scharf.",
  },
  animationStatus=function()
    local receipt = BattleAnimationCompat.status()
    if not receipt.installed then
      return {
        right="PENDING",
        help={
          en="The VASC move-animation catalog has not installed yet ("
            .. tostring(receipt.reason or "waiting for game data") .. ").",
          de="Der VASC-Attackenanimationskatalog ist noch nicht installiert ("
            .. tostring(receipt.reason or "warte auf Spieldaten") .. ").",
        },
      }
    end
    local total = (tonumber(receipt.gen1) or 0)
      + (tonumber(receipt.postGen) or 0)
    local generation = receipt.kasc and "KASC is active, so matching "
      .. "post-Gen-I programs are enabled." or "KASC is not active, so only "
      .. "Gen-I move programs are enabled."
    return {
      right=tostring(total) .. " MOVES",
      help={
        en=("VASC move animations are installed: %d Gen-I and %d post-Gen-I "
          .. "programs (%d program aliases). %s Every animation is mapped from "
          .. "the actual user/attacker toward the target, including reversed "
          .. "opponent attacks."):format(tonumber(receipt.gen1) or 0,
            tonumber(receipt.postGen) or 0,
            tonumber(receipt.programAliases) or 0, generation),
        de=("VASC-Attackenanimationen sind installiert: %d Gen-I- und %d "
          .. "Post-Gen-I-Programme (%d Programm-Aliasse). %s Jede Animation "
          .. "läuft vom tatsächlichen Anwender/Angreifer zum Ziel, auch bei "
          .. "umgekehrten Gegnerangriffen."):format(tonumber(receipt.gen1) or 0,
            tonumber(receipt.postGen) or 0,
            tonumber(receipt.programAliases) or 0,
            receipt.kasc and "KASC ist aktiv; passende spätere Attacken sind freigeschaltet."
              or "KASC ist nicht aktiv; nur Gen-I-Attacken sind freigeschaltet."),
      },
    }
  end,
})
SpriteHooks.install(mod)

-- Contribute one VASC-owned descriptor through the public Start-menu hook.
-- Standalone it remains a normal Start-menu row and opens VASC's complete
-- local hub. When Kanto Ascendant is active, its higher-priority collector
-- moves that same descriptor into ASCENDANT; no KASC code or dependency is
-- needed for the standalone path.
local ascendantMenuSkinBridge = VascMenu.menuSkinBridge(mod)
mod.exports.ascendantMenuSkin = ascendantMenuSkinBridge
KantoAscendantCompat.install(mod, {
  menuSkinBridge=ascendantMenuSkinBridge,
})

mod.exports.speciesCinematics = {
  apiVersion = 1,
  integrated = true,
  flySourceVersion = SpeciesFlyCinematic.VERSION,
  surfSourceVersion = SpeciesSurfCinematic.VERSION,
  fishingSourceVersion = SpeciesFishingCinematic.VERSION,
}

local function enabledLegacyCompanion(id)
  if type(mod.find) ~= "function" then return nil end
  local ok, handle = pcall(mod.find, id)
  if ok and type(handle) == "table" then return handle end
  ok, handle = pcall(mod.find, mod, id)
  return ok and type(handle) == "table" and handle or nil
end

local function installSpeciesCinematic(key, legacyId, module)
  if enabledLegacyCompanion(legacyId) then
    -- Modern launchers apply manifest policy=replace before loading. This is
    -- the fail-open guard for an older host: never compose the same controller
    -- and voxel callbacks twice if a retired standalone companion survived.
    mod.exports.speciesCinematics[key] = {
      active = false,
      legacyCompanion = legacyId,
      reason = "legacy-companion-active",
    }
    mod.log:warn("Integrated %s cinematic skipped: retired companion %s is active",
      key, legacyId)
    return false
  end
  local called, active, receipt = pcall(module.install)
  if not called or active ~= true then
    mod.exports.speciesCinematics[key] = {
      active = false,
      reason = called and tostring(receipt) or tostring(active),
    }
    mod.log:warn("Integrated %s cinematic failed open: %s", key,
      tostring(called and receipt or active))
    return false
  end
  return true
end

-- Content registries freeze before `mods.loaded` is emitted. All cinematic
-- installers patch VASC's owned render pipeline, so they must finish while the
-- loader is still accepting content.  Optional companions have already been
-- ordered ahead of VASC by the manifest, which keeps the public KASC/field-kit
-- lookup available here without a late, half-installed controller.
--
-- Fly installs first and Surf composes over that exact receipt.  Surf yields
-- immediately whenever Fly/warp presentation owns the frame.
installSpeciesCinematic("fly", "vasc_species_fly_cinematic",
  SpeciesFlyCinematic)
installSpeciesCinematic("surf", "vasc_species_surf_cinematic",
  SpeciesSurfCinematic)
installSpeciesCinematic("fishing", "vasc_species_fishing_cinematic",
  SpeciesFishingCinematic)

-- Keep VASC's ORAS provider installed as the autonomous default in a combined
-- stack. Optional KASC gameplay/QoL exports do not disable it; only a versioned
-- external provider claim can become authoritative, and removing that claim
-- restores VASC immediately without a reload.
mod.events:once("mods.loaded", function()
  if not mod.exports.orasBattleHud then
    local okHud, hudOrError = pcall(function()
      local factory = chunkFor("battle_hud_oras.lua")()
      return factory(mod, {
        MessageLayout=V.require("OrasBattleMessageLayout"),
        -- Keep the public OverworldBattle facade read-only.  The bundled HUD
        -- receives only the exact default-provider registration capability it
        -- needs; neither the raw renderer nor its external provider slot
        -- crosses this internal factory boundary.
        RegisterDefaultBattleHudProvider=function(provider)
          return OverworldBattle.setDefaultBattleHudProvider(provider)
        end,
      })
    end)
    if not okHud then
      mod.log:error("VASC ORAS Battle HUD failed open: %s", tostring(hudOrError))
    end
  end
  mod.exports.battleHudOwnership = OrasBattleHudSettings.receipt(mod)
end)

-- Events dispatch higher priorities first. Install the native PokemonUi host
-- at a deliberately lower priority than optional UI companions, making VASC
-- the deterministic outer BoxMenu/PartyMenu wrapper while retaining their
-- complete screens as the whole-surface GAME DEFAULT/failure fallback.
local POKEMON_UI_OUTER_HOST_PRIORITY = -10000
mod.events:once("mods.loaded", function()
  local okHosts, hostReason = PokemonUiGen1Hosts.install(PokemonUi)
  if not okHosts then
    mod.log:warn("VASC Pokemon UI native hosts failed open: %s",
      tostring(hostReason))
  end
end, POKEMON_UI_OUTER_HOST_PRIORITY)

-- 1ST and 3RD share one player-attached camera and one camera-relative
-- movement path. These installers only claim input while either rung is
-- active and the overworld is actually on top of the state stack.
FirstPerson.install()
FreeMove.install()
CamControl.install()
ShortcutToast.install(require("src.core.Game"), {
  enabled = function() return ShortcutToastSetting:get() ~= false end,
})
VoxelShortcut.install(cycleVoxel)

-- The BattleLifecycle card above is now the sole state-changing router for
-- battle.started, battle.battler_switched, battle.move_used and battle.ended.
-- Independent read-only observers (for example BattleAnimationCompat below)
-- may still refresh their own data without taking lifecycle ownership.

-- The live BattleState deliberately keeps its native player rear. VASC asks
-- for a front only inside OverworldBattle's private billboard texture pass;
-- that preserves an exact DEFAULT/2D image if a staged renderer must fail
-- atomically, and prevents front art ever landing in the classic back slot.

-- Trainer presentation is independent of the Pokemon card. Gen1 loads the
-- trainer through the battle-back slot until the throw completes; in a staged
-- fight TRAINER BACK = OFF replaces that slot with standing front art.
--
-- The high hook priority also lets the ON path ask character companions for
-- their actual battle-back visual. Older Kanto Ascendant builds selected a
-- voxel front solely from ctx.kind == "battle"; the compatibility kind below
-- preserves every other context field while routing that one request to the
-- companion's normal back-art branch.
mod.hooks:wrap("player.sprite", function(next, path, ctx)
  local wantsFront = OverworldBattle.wantsTrainerFront()
  if wantsFront then
    -- Standing trainer art is resolved at the public sideTexture seam (KASC
    -- provider first, VASC's embedded fallback otherwise). Keep this engine
    -- field native for the same atomic 2D fallback contract as Pokemon backs.
    return next(path, ctx)
  end
  return OverworldBattle.routeTrainerSprite(
    next, path, ctx,
    OverworldBattle.wantsTrainerBack(),
    false)
end, 100)

-- ------- and the way back out
--
-- The engine wipes INTO a battle with one of the original's eight transitions
-- and cuts straight OUT of it. That cut is between two very different cameras
-- in this mode, so while voxel mode is on the battle fades out, closes behind
-- the black, and the map fades up. The two seams it needs -- BattleState:finish
-- and Renderer:endFrame -- and the reasoning for each live in lib/BattleExit.lua.
--
-- Declared as a transitions record rather than a constant in that file, so the
-- fade is retunable in data exactly like the eight wipes it answers, and a total
-- conversion can make it as long or as short as its own pacing wants.
mod.content.transitions:register(BattleExit.ID, {
  frames = BattleExit.FRAMES,
})

BattleExit.install()

-- ------- and the hour on the flat world
--
-- The clock reaches the diorama through the voxel shader's own tint uniform,
-- which the 2D tile path never runs -- so with the mode off, the same evening
-- that fell on the diorama left the flat world at permanent noon. One clock,
-- two worlds, one of them ignoring it. DayTint paints the same multiply over
-- the composited flat world, between the world blit and the UI blit; the
-- reasoning for that exact instant is in the file.
DayTint.install()

-- ------- what time it is
--
-- The cycle's clock rides the SAVE SLOT (save.modData, via mod.save): what
-- time it is in Kanto is a fact about that journey, like where the player is
-- standing. Written on the engine's save.writing event -- the moment before
-- the bytes hit disk -- and read back whenever a save is opened or begun. A
-- A save with no clock in it starts at noon on the default AUTO dial;
-- explicit DAY/NIGHT/DUSK/DAWN pins remain stored options.
mod.events:on("save.writing", function()
  DayNight.store()
  SkyEvents.store()
  Weather.store()
end)

mod.events:on("save.loaded", function(payload)
  Voxel.seedLiveOptions(payload)
  OrasBattleHudSettings.migrateLegacyFrame(
    mod, require("src.core.Game"), BattleHud.positionSetting)
  DayNight.restore()
  SkyEvents.restore()
  Weather.restore()
  DeviceProfile.restore(require("src.core.Game"), false)
  SpritePacks.restore(require("src.core.Game"))
  LocalMusic.restore(require("src.core.Game"))
  LocalSprites.restore(require("src.core.Game"))
  LocalContent.restore(require("src.core.Game"))
  -- a save written before this mod was installed can carry TILT or GBC FX
  -- switched on, and their rows are not there to switch them back off (see
  -- pinEngineFx). Answered here rather than only when the menu opens, so a
  -- player who never opens it is not left playing under one.
  pinEngineFx()
end)

mod.events:on("save.created", function(payload)
  Voxel.seedLiveOptions(payload)
  OrasBattleHudSettings.migrateLegacyFrame(
    mod, require("src.core.Game"), BattleHud.positionSetting)
  DayNight.restore()
  SkyEvents.restore()
  Weather.restore()
  DeviceProfile.restore(require("src.core.Game"), true)
  SpritePacks.restore(require("src.core.Game"))
  LocalMusic.restore(require("src.core.Game"))
  LocalSprites.restore(require("src.core.Game"))
  LocalContent.restore(require("src.core.Game"))
  pinEngineFx()
end)

-- Hot reload constructs a new mod loader around an already loaded save, so
-- no save.loaded event is guaranteed. Restore the selected pack here too;
-- providers may register before or after this without losing the stored id.
mod.events:on("game.ready", function()
  local Game = require("src.core.Game")
  OrasBattleHudSettings.migrateLegacyFrame(
    mod, Game, BattleHud.positionSetting)
  pinEngineFx(Game)
  BattleAnimationCompat.install(Game, mod)
  WarpPrefetch.install(Game)
  SpritePacks.restore(Game)
  LocalMusic.restore(Game)
  LocalSprites.restore(Game)
  LocalContent.restore(Game)
  LocalSprites.writeInventory(Game.data)
end)

-- The engine emits one receipt per completed logical cell, including VASC's
-- free movement path. Weather sound therefore follows actual footsteps and
-- never a frame timer; bikes and Surf are rejected by WeatherFootsteps.
mod.events:on("world.stepped", function()
  local Game = require("src.core.Game")
  local map = Game and Game.overworld and Game.overworld.map
  local mode = Weather.mode(map)
  WeatherFootsteps.onStep(
    Game, mode, WeatherTweak.groundAmount(map, mode, true))
end)

-- KASC merges its post-Gen-I move registry on game.ready as well. Refresh at
-- the battle boundary so load-order or hot-reload cannot leave those programs
-- gated off after KASC has become active; the AnimPlayer constructor itself
-- is identity-held and is never stacked by this refresh.
mod.events:on("battle.started", function()
  BattleAnimationCompat.install(require("src.core.Game"), mod)
end)

-- The engine's own time-of-day seam. OverworldState:timeOfDay() is an
-- eternal "DAY" until a mod answers here; answering it hands the period to
-- the map.palette hook (ctx.tod) and music.select, so a palette or music
-- pack keyed to night works with this mod's clock for free. next() first: a
-- mod loaded before this one that already moved the time keeps its answer.
mod.hooks:wrap("world.tod", function(next, tod, ctx)
  local out = next(tod, ctx)
  if out ~= tod then return out end
  return DayNight.tod()
end)

mod.exports.packageVersion = PACKAGE_VERSION
mod.exports.version = PACKAGE_VERSION
mod.exports.apiVersion = 1
mod.exports.orasUiSkin = uiSkinInstalled and OrasUiSkin or nil
mod.exports.shortcutToast = ShortcutToast
mod.exports.shortcutToastStatus = function() return ShortcutToast.status() end
mod.exports.renderer = {
  id = "VOXEL_ASCENDANT",
  version = PACKAGE_VERSION,
  pipeline = "voxel",
  -- Stable staged-battle discriminator consumed by Kanto Ascendant's
  -- reviewed renderer facade. The staged battle camera is still orbit-only;
  -- overworld 1ST/3RD are advertised on their own field and capability.
  cameraProfile = "orbit-only",
  overworldCameraProfile = "orbit-first-third",
}

local function installedSpeciesCinematicVersion(key)
  local family = mod.exports.speciesCinematics
  local public = type(family) == "table" and family[key] or nil
  if type(public) ~= "table" or public.active ~= true
      or type(public.status) ~= "function" then
    return nil
  end
  local version = public.version or public.sourceVersion
  if type(version) ~= "string" or version == "" then return nil end
  return version
end

mod.exports.capabilities = {
  voxelWorld = true,
  -- KASC's public compatibility receipt pins the historical first two
  -- entries as MAP/DISCS. New capabilities append; the OPTIONS ladder may
  -- still present MAP/ARENA/DISCS in its more useful player-facing order.
  battleCards = { "MAP", "DISCS" },
  battleLifecycle = {
    apiVersion=Gen1BattleLifecycle.API_VERSION,
    contextSchema=Gen1BattleLifecycle.CONTEXT_SCHEMA,
    providerSchema=Gen1BattleLifecycle.PROVIDER_SCHEMA,
    exactBattleOwner=true,
    switchEvent="battle.battler_switched",
    routerSchema="ascendant.battle-router/v1",
    segmentedProviders={ "DEFAULT", "DISCS" },
    transitionalProviders={ "MAP", "ARENA" },
  },
  battleOverlay = {
    apiVersion=1,
    schema="ascendant.battle-overlay/v1",
    receiptSchema="ascendant.battle-overlay-receipt/v1",
    generation=1,
    surfaces={ "status_hud" },
    rawRendererAuthority=false,
  },
  ascendantCards = {
    apiVersion=1,
    schema=AscendantCardHost.SCHEMA,
    cardSchema=AscendantContracts.CARD_SCHEMA,
    builtIn={
      Gen1DefaultBattleProviderCard.ID,
      Gen1DiscsBattleProviderCard.ID,
      Gen1BattleRouterCard.ID,
      Gen1BattleLifecycleCard.ID,
      Gen1BattleLatchDiagnosticsCard.ID,
      Gen1BattleOverlayCard.ID,
    },
    registry="internal-owner-scoped",
    externalRegistration=false,
    publicEvents={ Gen1BattleLifecycleCard.PUBLIC_EVENT },
  },
  battleHudProvider = 1,
  wallDecals = WallDecals.API_VERSION,
  cameraModes = { "ORBIT", "FIRST_PERSON", "THIRD_PERSON" },
  speciesCinematics = {
    apiVersion = 1,
    generation = 1,
    fly = installedSpeciesCinematicVersion("fly"),
    surf = installedSpeciesCinematicVersion("surf"),
    fishing = installedSpeciesCinematicVersion("fishing"),
    nativeFallback = true,
  },
  spriteOverrideHooks = {
    "vasc.sprite.pokemon", "vasc.sprite.battle", "vasc.sprite.dex",
    "vasc.sprite.overworld_pokemon", "vasc.sprite.player",
    "vasc.sprite.trainer", "vasc.sprite.icon", "vasc.sprite.overworld",
  },
  spritePacks = { apiVersion=SpritePacks.API_VERSION, bundledAssets=false,
                  liveActivation=true, licenseReceipt=true, sha256=true },
  battleMusicPacks = {
    apiVersion=BattleMusic.API_VERSION, bundledAudio=false,
    networkDownloads=false, liveActivation=true,
  },
  weatherMusic = {
    apiVersion=1,
    schema="voxel-ascendant/weather-music-host/v1",
    generation=1,
    owner="VOXEL_ASCENDANT",
    cards={
      Gen1WeatherMusicPackageAssetsCard.ID,
      Gen1WeatherMusicCatalogCard.ID,
      Gen1WeatherMusicRouterCard.ID,
      Gen1WeatherMusicOptionUiCard.ID,
      Gen1WeatherMusicPlaybackAdapterCard.ID,
    },
    registeredMaps=9,
    variantsPerMap=5,
    nativeFallback=true,
    directLoveAudio=false,
    active=weatherMusicActive,
    hearingStatus="USER_TEST_REQUIRED",
  },
  looseUserMusic = {
    root=LocalMusic.ROOT, categories={
      "wild", "trainer", "rival", "gym", "elite4", "champion", "field",
      "bike", "surf", "victory", "evolution", "title", "halloffame",
      "credits", "jingle", "scene",
    }, exactSongReplacement="replace/<SONG_ID>.<ext>",
       shuffle=true, bundledAudio=false, liveRescan=true,
       default="GAME/KASC", explicitOptIn=true,
  },
  looseUserSprites = {
    root=LocalSprites.ROOT, live=true, bundledAssets=false,
    default="GAME/KASC", explicitOptIn=true,
    roles={"pokemon", "player", "trainer", "dex", "icon", "overworld"},
  },
  contentProfiles = {
    apiVersion=LocalContent.API_VERSION,
    contract=LocalContent.CONTRACT,
    profiles={"KASC", "VASC_DEFAULT", "RETRO", "CUSTOM"},
    autonomous=true, publicReceiptsOnly=true,
  },
  battleLayoutProfiles = {
    apiVersion=BattleLayout.API_VERSION,
    contract=BattleLayout.PROFILE_CONTRACT,
    normalizedViewport=true,
    mergeOrder={"VASC_DEFAULT", "IMPORTED_PROFILE", "USER_OFFSETS"},
  },
  pokemonUiProviders = {
    apiVersion=PokemonUi.API_VERSION,
    schema=PokemonUi.PROVIDER_SCHEMA,
    hostSchema=PokemonUi.HOST_SCHEMA,
    sessionSchema=PokemonUi.SESSION_SCHEMA,
    modelSchema=PokemonUi.MODEL_SCHEMA,
    actionSchema=PokemonUi.ACTION_SCHEMA,
    actionResultSchema=PokemonUi.ACTION_RESULT_SCHEMA,
    eventSchema=PokemonUi.EVENT_SCHEMA,
    controllerGeneration=PokemonUi.CONTROLLER_GENERATION,
    hostGeneration=PokemonUi.HOST_GENERATION,
    capabilityDigestSchema=PokemonUi.CAPABILITY_DIGEST_SCHEMA,
    surfaces={"pc_box", "legacy_bank", "battle_party"},
    transactionalDraw=PokemonUi.TRANSACTIONAL_DRAW,
    inputOwnership="exclusive_after_accept",
  },
  freeMovement = true,
  shadowPolicy = 1,
  backgroundMeshCache = "memory",
  skyEvents = {
    "RAINBOW", "PIDGEY", "PIDGEOTTO", "PIDGEOT",
    "SPEAROW", "FEAROW", "MURKROW",
    "ARTICUNO", "ZAPDOS", "MOLTRES", "HO_OH", "LUGIA",
  },
  diskCache = false,
  -- Historical KASC capability: this means the old model-backed Stadium
  -- renderer, not ARENA CAM's internal presentation director and not the
  -- separately exported player-ROM importer below.  Changing this legacy bit
  -- made KASC reject the complete VASC renderer facade, so its Green/Blue/Red
  -- standing-trainer relay never installed and the native battle back leaked
  -- into staged fights.  The importer remains advertised by
  -- exports.stadium2Importer / stadium2Catalog.
  stadium = false,
  vr = false,
}
mod.exports.integrations = {
  kantoAscendantMenu = KantoAscendantCompat.receipt(),
}
mod.exports.Voxel3D = Voxel3D
mod.exports.WallDecals = WallDecals
mod.exports.spritePacks = SpritePacks.public()
mod.exports.battleMusic = BattleMusic.public()
mod.exports.localContent = LocalContent.public()
mod.exports.pokemonModelProvider = V.PokemonModelProvider.public()
mod.exports.stadium2Importer = true
mod.exports.stadium2Catalog = {
  source="player-owned-rom",
  standaloneGen1=151,
  kascGen1=251,
  gen2=251,
  cache="cache/stadium2-gen1",
}
mod.exports.romMenu = V.StadiumRomMenu
mod.exports.stadiumRomOptionsInstalled = V.stadiumRomOptionsInstalled == true
mod.exports.stadiumRomManagerOptionsInstalled =
  V.stadiumRomManagerOptionsInstalled == true
mod.exports.chooseStadiumRom = function(game)
  if game then return V.StadiumRomMenu.choose(game) end
  local okGame, Game = pcall(require, "src.core.Game")
  return V.StadiumRomMenu.choose(okGame and Game or nil)
end
mod.exports.battleLayout = BattleLayout.public()
mod.exports.battleLifecycle = Gen1BattleLifecycle.public()
mod.exports.ascendantCards = AscendantCardHost.new({
  cardSchema=AscendantContracts.CARD_SCHEMA,
  lifecycle={
    event=Gen1BattleLifecycleCard.PUBLIC_EVENT,
    schema="ascendant.battle-lifecycle-public-event/v1",
    apiVersion=Gen1BattleLifecycle.API_VERSION,
  },
  health=function()
    local status, reason = AscendantCards:health(
      Gen1BattleLifecycleCard.ID,
      { generation=1, host="VOXEL_ASCENDANT", public=true })
    if not status then
      return { ok=false, state="unavailable", error=tostring(reason) }
    end
    local fallback = NativeBattleCleanup
      and NativeBattleCleanup.health() or {
        ok=false,
        state="unavailable",
        lastError=tostring(nativeBattleCleanupReason),
      }
    local runtime = OverworldBattle.battleLifecycleHealth()
    local router = AscendantCards:health(
      Gen1BattleRouterCard.ID,
      { generation=1, host="VOXEL_ASCENDANT", public=true })
    local defaultProvider = AscendantCards:health(
      Gen1DefaultBattleProviderCard.ID,
      { generation=1, host="VOXEL_ASCENDANT", public=true })
    local discsProvider = AscendantCards:health(
      Gen1DiscsBattleProviderCard.ID,
      { generation=1, host="VOXEL_ASCENDANT", public=true })
    local overlay = battleOverlayRegistered and AscendantCards:health(
      Gen1BattleOverlayCard.ID,
      { generation=1, host="VOXEL_ASCENDANT", public=true }) or nil
    local latchDiagnostics = battleLatchDiagnosticsRegistered
      and AscendantCards:health(Gen1BattleLatchDiagnosticsCard.ID,
        { generation=1, host="VOXEL_ASCENDANT", public=true }) or nil
    local dragoniteFly = dragoniteFlyRegistered and AscendantCards:health(
      Gen1DragoniteFlyCard.ID,
      { generation=1, host="VOXEL_ASCENDANT", public=true }) or nil
    return {
      ok=status.ok == true and runtime.ready == true
        and runtime.runtimeState == "installed"
        and runtime.leaseState == "active"
        and router and router.ok == true
        and defaultProvider and defaultProvider.ok == true
        and discsProvider and discsProvider.ok == true
        and overlay and overlay.ok == true,
      state=status.state,
      error=status.error,
      lastError=status.lastError,
      runtime=runtime,
      nativeFallback=fallback,
      providerRouter=router,
      defaultProvider=defaultProvider,
      discsProvider=discsProvider,
      battleOverlay=overlay,
      battleLatchDiagnostics=latchDiagnostics,
      dragoniteFlyCompat=dragoniteFly,
    }
  end,
})
mod.exports.pokemonUi = PokemonUi.public()
mod.exports.localMusic = {
  apiVersion=LocalMusic.API_VERSION,
  root=LocalMusic.ROOT,
  list=LocalMusic.list,
  scan=LocalMusic.scan,
  status=LocalMusic.status,
  enabled=LocalMusic.enabled,
  previewOriginal=LocalMusic.previewOriginal,
  previewTrack=LocalMusic.previewTrack,
  stopPreview=LocalMusic.stopPreview,
}
mod.exports.localSprites = { apiVersion=LocalSprites.API_VERSION,
                             root=LocalSprites.ROOT,
                             rescan=LocalSprites.rescan,
                             inventory=LocalSprites.inventory,
                             refreshInventory=LocalSprites.writeInventory,
                             enabled=LocalSprites.enabled,
                             status=LocalSprites.status }
mod.exports.weather = {
  apiVersion = 1,
  nativeGround = true,
  heatAllowed = Weather.heatAllowed,
  mode = Weather.mode,
  seasonAt = Weather.seasonAt,
  setSkyProvider = Weather.setSkyProvider,
}
mod.exports.shadows = {
  apiVersion = 1,
  setPolicyProvider = ShadowPolicy.setProvider,
}

local kantoMapInstalled, kantoMapInstallReason = KantoFlyMap.install()
if not kantoMapInstalled and mod.log and type(mod.log.warn) == "function" then
  mod.log:warn("Kanto Fly Map failed open: %s",
    tostring(kantoMapInstallReason or "unavailable"))
end

-- The map provider must contribute its descriptor before this final filter so
-- KASC's priority-1000 ASCENDANT collector can retain it. Standalone VASC then
-- removes only the redundant top-level shortcut; Town Map item, Dex AREA and
-- every FLY path continue to use the registered TownMap owner.
local startSurfaceInstalled, startSurfaceReason =
  StartMenuSurfacePolicy.install(mod)
if not startSurfaceInstalled and mod.log
    and type(mod.log.warn) == "function" then
  mod.log:warn("Gen-1 START surface policy failed open: %s",
    tostring(startSurfaceReason or "unavailable"))
end

-- The Dex is installed after the Kanto map receipt is published. Its AREA
-- shell may consume that one provider, but never registers or discovers a
-- second map owner. A missing provider remains the engine TownMap renderer.
local modernDexInstalled, modernDexInstallReason = ModernDexHost.install()
if not modernDexInstalled and mod.log and type(mod.log.warn) == "function" then
  mod.log:warn("Modern Pokedex failed open: %s",
    tostring(modernDexInstallReason or "unavailable"))
end

-- This must be last among Gen-1 menu installers. It scales the final A21/
-- Ascendant draw surface into the full notch-safe phone viewport while every
-- screen keeps its native behavior and provider ownership.
local gen1MobileMenusInstalled, gen1MobileMenusReason =
  Gen1MobileMenuBridge.install()
if not gen1MobileMenusInstalled and mod.log
    and type(mod.log.warn) == "function" then
  mod.log:warn("Gen-1 mobile menu presentation failed open: %s",
    tostring(gen1MobileMenusReason or "unavailable"))
end
mod.exports.gen1MobileMenus = gen1MobileMenusInstalled
  and Gen1MobileMenuBridge or nil

-- Compatibility modules are selected eagerly into a closed table. Unknown
-- names never reach the private owner-scoped loader, and the facade exposes
-- neither the mod handle nor its path/data/module caches.
local publicModules = {
  AntiAlias = AntiAlias,
  BattleArena = V.require("BattleArena"),
  BattleCam = BattleCam,
  OverworldBattle = OverworldBattlePublic.new(OverworldBattle),
  SkyEvents = SkyEvents,
  Voxel3D = Voxel3D,
  VoxelScene = VoxelScene,
  VoxelState = Voxel,
  -- Pure planner only: the integrated renderer cannot access our private loader.
  HdResidencyPlan = V.require("HdResidencyPlan"),
  WallDecals = WallDecals,
}
mod.exports.lib = PublicFacade.new(publicModules)

-- Activate the mandatory lifecycle owner only after every installer/export
-- above completed. The loader cannot undo direct class wrappers, so a failure
-- must not pretend an entry throw is atomic: the wrapper gate stays closed and
-- the successfully loaded mod delegates battles to native DEFAULT instead.
local battleLifecycleActive, battleLifecycleActivateReason = false,
  battleLifecycleRegisterReason
local dragoniteFlyActive, dragoniteFlyActivateReason = false,
  dragoniteFlyRegisterReason
if dragoniteFlyRegistered then
  dragoniteFlyActive, dragoniteFlyActivateReason =
    AscendantCards:activate(Gen1DragoniteFlyCard.ID, {
      generation=1,
      host="VOXEL_ASCENDANT",
    })
end
if not dragoniteFlyActive and mod.log
    and type(mod.log.warn) == "function" then
  mod.log:warn("Dragonite FLY compatibility Card failed open: %s",
    tostring(dragoniteFlyActivateReason))
end
if battleLifecycleRegistered then
  battleLifecycleActive, battleLifecycleActivateReason =
    AscendantCards:activate(Gen1BattleLifecycleCard.ID, {
      generation=1,
      host="VOXEL_ASCENDANT",
    })
end
if not battleLifecycleActive then
  OverworldBattle.setBattleLifecycleReady(false,
    battleLifecycleActivateReason or "battle lifecycle activation failed")
  -- Dependencies may already be active when the mandatory consumer fails.
  -- Retire the whole provider graph immediately; leaving an unreachable
  -- DEFAULT/router capability alive would make Health claim owners which can
  -- no longer receive an engine lifecycle event.
  local activationTeardown = AscendantCards:deactivateAll(
    { generation=1, host="VOXEL_ASCENDANT", activationFailed=true },
    "mandatory battle lifecycle activation failed")
  if type(activationTeardown) ~= "table"
      or type(activationTeardown.errors) ~= "table"
      or #activationTeardown.errors > 0 then
    local teardownErrors = {}
    for _, failure in ipairs(activationTeardown
        and activationTeardown.errors or {}) do
      teardownErrors[#teardownErrors + 1] = tostring(failure.id) .. ": "
        .. tostring(failure.error)
    end
    if #teardownErrors == 0 then
      teardownErrors[1] = "no structured teardown receipt"
    end
    if mod.log and type(mod.log.error) == "function" then
      mod.log:error("mandatory battle provider graph teardown incomplete: %s",
        table.concat(teardownErrors, "; "))
    end
  end
  if mod.log and type(mod.log.error) == "function" then
    mod.log:error("mandatory battle lifecycle card failed closed; native "
      .. "DEFAULT remains active: %s",
      tostring(battleLifecycleActivateReason))
  end
end

-- Terminal renderer telemetry is optional and write-only. Its failure must
-- never alter provider selection or the native fallback behavior it observes.
local battleLatchDiagnosticsActive, battleLatchDiagnosticsActivateReason =
  false, battleLatchDiagnosticsRegisterReason
if battleLifecycleActive and battleLatchDiagnosticsRegistered then
  battleLatchDiagnosticsActive, battleLatchDiagnosticsActivateReason =
    AscendantCards:activate(Gen1BattleLatchDiagnosticsCard.ID, {
      generation=1,
      host="VOXEL_ASCENDANT",
    })
end
if battleLifecycleActive and not battleLatchDiagnosticsActive and mod.log
    and type(mod.log.warn) == "function" then
  mod.log:warn("battle latch diagnostics Card failed open: %s",
    tostring(battleLatchDiagnosticsActivateReason))
end

-- The public overlay receipt is an optional, read-only companion boundary.
-- Its activation depends on the mandatory lifecycle owner, but its failure
-- never changes battle rendering; KASC simply keeps its native overlays.
local battleOverlayActive, battleOverlayActivateReason = false,
  battleOverlayRegisterReason
if battleLifecycleActive and battleOverlayRegistered then
  battleOverlayActive, battleOverlayActivateReason =
    AscendantCards:activate(Gen1BattleOverlayCard.ID, {
      generation=1,
      host="VOXEL_ASCENDANT",
    })
end
if battleOverlayActive then
  local capability = AscendantCards:capability(
    Gen1BattleOverlayCard.CAPABILITY)
  mod.exports.battleOverlay = capability and capability.value or nil
else
  mod.exports.battleOverlay = nil
  if battleLifecycleActive and mod.log
      and type(mod.log.warn) == "function" then
    mod.log:warn("read-only battle overlay capability failed open: %s",
      tostring(battleOverlayActivateReason))
  end
end
