-- Overworld battles: fights that happen on the map you were standing on.
--
-- The engine's battle is a screen: a white field with two pics on it, pushed
-- over a frozen overworld that stops drawing. This turns that white field
-- into the world -- the same terrain the free-roam mode extrudes, shot from
-- a placed over-the-shoulder camera at a clear patch of ground nearby --
-- while leaving the battle ITSELF alone. Every pic, HUD, HP bar, move
-- animation, faint slide and text box is the engine's own, drawn in the
-- engine's own order. What changes is what is behind them, and where the two
-- pics stand.
--
-- The sequence, from the moment something picks a fight:
--
--   1. the overworld cast is culled -- every NPC vanishes, so the wipe
--      plays over an empty map and no bystander is left standing in the
--      arena shot
--   2. the engine's own transition wipes the screen (untouched: it is the
--      right wipe, picked by the right three bits)
--   3. the battle draws over a live, window-resolution render of the arena,
--      with each mon PINNED to the cell it is standing on, the camera
--      drifting slowly enough to read as parallax, and a depth-of-field pass
--      holding the slab of world the two of them occupy sharp
--   4. the battle ends, the cast comes back, and the player is exactly
--      where they were standing
--
-- WHAT DOES NOT MOVE. The arena is where the CAMERA goes, not where the
-- player goes: nothing here writes a cell, a facing, a flag or a warp. A
-- real warp would have to survive trainer sight-lines, post-battle
-- dialogue, the blackout path and every script that assumes the player is
-- where it left them -- and it would have to put them back afterwards.
-- Moving the camera buys the whole shot and owes nothing back.
--
-- The feature declines cleanly rather than half-working: no depth support,
-- no open ground on the map, the row switched off, or a mesh still building
-- all end at the same place, which is the battle screen the engine has
-- always drawn.

-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local ModSetting = V.require("ModSetting")
local BattleArena = V.require("BattleArena")
local BattleCam = V.require("BattleCam")
local BattleScene = V.require("BattleScene")
local BattleDOF = V.require("BattleDOF")
local BattleHud = V.require("BattleHud")
local BattlePartyBalls = V.require("BattlePartyBalls")
local BattlePics = V.require("BattlePics")
local CanvasPresentation = V.require("CanvasPresentation")
local Voxel3D = V.require("Voxel3D")
local ChunkMesher = V.require("ChunkMesher")
local okDiagnostics, Diagnostics = pcall(V.require, "Diagnostics")
if not okDiagnostics or type(Diagnostics) ~= "table" then Diagnostics = {} end
if type(Diagnostics.write) ~= "function" then
  Diagnostics.write = function() return false end
end
-- Loaded eagerly by main_gen1 in production.  Isolated legacy fixtures often
-- provide a closed V.require table, so keep this one collaboration seam
-- optional there; the release/runtime path still fails installation if the
-- adapter itself is absent or invalid.
local lifecycleLoaded, BattleLifecycle =
  pcall(V.require, "adapters/gen1/Gen1BattleLifecycle")
if not lifecycleLoaded or type(BattleLifecycle) ~= "table" then
  BattleLifecycle = nil
end

local OverworldBattle = {}
local supported = false
-- The engine classes outlive a module instance.  Their wrappers therefore
-- need one process-local owner. A reload retires the old owner before replacing it.
-- Keeping the lease on OverworldController makes the first wrapper's kill
-- switch reachable without exposing its renderer/session table.
local RUNTIME_LEASE_SLOT = "voxelAscendantBattleRuntimeLeaseV1"
local RUNTIME_LEASE_SCHEMA = "ascendant.gen1-battle-wrapper-lease/v1"
local runtimeState = "new"
local runtimeLease = nil
local function runtimeLeaseActive()
  return runtimeState == "installed"
    and type(runtimeLease) == "table"
    and runtimeLease.schema == RUNTIME_LEASE_SCHEMA
    and runtimeLease.apiVersion == 1
    and runtimeLease.state == "active"
    and type(runtimeLease.retire) == "function"
end
-- Direct BattleState/OverworldController wrappers cannot currently be rolled
-- back by the engine loader.  They therefore stay behaviorally inert until
-- the owner-scoped lifecycle Card has installed every event subscription.
-- A Card abort closes this gate again, so wrappers left by a failed/hot load
-- can only delegate to the native renderer.
local battleLifecycleReady = false
local battleLifecycleReason = "battle lifecycle card not activated"
-- Forward-declared because presentation policy is queried both while the
-- engine creates battlers and later from the installed draw hooks. Once a
-- battle starts, `session.plan` freezes every saved presentation choice for
-- that exact battle; menu/hot-reload changes apply only to the next one.
local session = nil
-- Owner-scoped, write-only terminal telemetry installed by the dedicated
-- diagnostics Card. It observes decisions already made by this renderer and
-- can never request a fallback, change a provider or reach engine/save state.
local BATTLE_LATCH_DIAGNOSTICS_SCHEMA =
  "ascendant.gen1-battle-latch-diagnostics/v1"
local battleLatchDiagnosticsOwner = nil
local battleLatchDiagnosticSerial = 0
-- RC11 renderer-only ownership seam.  `rendererPreparation` is deliberately
-- separate from `session`: stage selection may happen before the lifecycle
-- Router calls a provider, while world/camera mutation starts only when that
-- exact provider adopts the prepared BattleState.  The control facade is
-- private to VASC (OverworldBattlePublic does not expose it) and none of its
-- methods emit lifecycle events or finish external battle content.
local rendererPreparation = nil
local rendererLastOwner = setmetatable({}, { __mode="v" })
local rendererTerminalOwners = setmetatable({}, { __mode="k" })
local rendererSessionSerial = 0
local rendererSessionMutation = nil
local rendererSessionStats = {
  prepares=0,
  adopts=0,
  switches=0,
  finishes=0,
  aborts=0,
  fallbacks=0,
  failures=0,
}
local rendererSessionAbort
local rendererSessionFallback
-- Content/music live outside this renderer module, but a replacement battle
-- can arrive before the old battle.ended event.  The owner registers one
-- narrow cleanup callback so begin() can retire those battle-scoped caches at
-- the same instant it retires the old renderer session.
local replacementCleanup = nil
-- Exact native cleanup needs one earlier seam than battle.started: the engine
-- asks for battle music inside its original pushBattle.  This injected
-- callback is owned by adapters/gen1/NativeBattleCleanup and runs before that
-- original method; it never owns staged renderer state.
local nativeBattlePreflight = nil
-- The host owns event subscriptions which this renderer cannot see. Once the
-- lifecycle Card is active, it binds one owner-retirement callback here so a
-- later module instance can unsubscribe the old Card/native-cleanup adapters
-- before it tears down renderer state.
local runtimeRetireCallback = nil
local worldPlayerSpriteCache = setmetatable({}, { __mode="k" })
local arenaArtSerial = 0
local diskArtSerial = 0
local unpackValues = table.unpack or unpack
local function packValues(...)
  return { n = select("#", ...), ... }
end
local function sameBattle(left, right)
  return rawequal(left, right)
end

-- Released KASC builds extend the historical public OverworldBattle name by
-- replacing a handful of presentation functions and by wrapping begin/ensure
-- as native-2D vetoes.  RC11 keeps those callbacks in its public proxy.  The
-- raw renderer owns only this VASC-created dispatcher object and opens it at
-- explicit render/entry boundaries; no foreign write can replace a renderer
-- function or call finish outside an exact owner-mediated battle invocation.
local LEGACY_COMPATIBILITY_BRIDGE_SCHEMA =
  "ascendant.gen1-overworld-battle-legacy-bridge/v1"
local legacyCompatibilityBridge = nil
local legacyFinishRequestedBattle = nil

local function validLegacyCompatibilityBridge(value)
  return type(value) == "table"
    and value.schema == LEGACY_COMPATIBILITY_BRIDGE_SCHEMA
    and value.apiVersion == 1
    and type(value.invoke) == "function"
    and type(value.guard) == "function"
    and type(value.overridden) == "function"
    and type(value.retire) == "function"
end

local function legacyPresentation(key, ...)
  local bridge = legacyCompatibilityBridge
  if not validLegacyCompatibilityBridge(bridge) then
    local fallback = OverworldBattle[key]
    if type(fallback) ~= "function" then return nil end
    return fallback(...)
  end
  local called, receipt = pcall(bridge.invoke, key, ...)
  if not called or type(receipt) ~= "table"
      or receipt.schema ~= LEGACY_COMPATIBILITY_BRIDGE_SCHEMA
      or type(receipt.values) ~= "table"
      or type(receipt.values.n) ~= "number" then
    error(called and "invalid legacy presentation receipt"
      or tostring(receipt), 0)
  end
  -- A legacy texture resolver may discover that its approved staged asset is
  -- unreadable.  Record only a request for the exact active owner.  The frame
  -- driver consumes it immediately after texture resolution, before touching
  -- `session` again, then retires only that renderer session to native 2D.
  -- The real engine end event keeps sole ownership of lifecycle/content/music
  -- cleanup.
  if receipt.finishRequested == true and receipt.battle ~= nil then
    if session ~= nil and sameBattle(session.battle, receipt.battle) then
      legacyFinishRequestedBattle = receipt.battle
    end
  end
  if receipt.ok ~= true then error(tostring(receipt.error), 0) end
  return unpackValues(receipt.values, 1, receipt.values.n)
end

local function legacyPresentationOverridden(key)
  local bridge = legacyCompatibilityBridge
  if not validLegacyCompatibilityBridge(bridge) then return false end
  local ok, value = pcall(bridge.overridden, key)
  return ok and value == true
end

local function legacyBattleGuard(entry, ...)
  local bridge = legacyCompatibilityBridge
  if not validLegacyCompatibilityBridge(bridge) then return true, nil, false end
  local called, receipt = pcall(bridge.guard, entry, ...)
  if not called or type(receipt) ~= "table"
      or receipt.schema ~= LEGACY_COMPATIBILITY_BRIDGE_SCHEMA then
    return false, called and "invalid legacy battle-guard receipt"
      or tostring(receipt), false
  end
  return receipt.allowed == true, receipt.error,
    receipt.finishRequested == true
end

local function lifecycle(method, ...)
  local callback = BattleLifecycle and BattleLifecycle[method]
  if type(callback) ~= "function" then return nil end
  local ok, value, reason = pcall(callback, ...)
  if ok then return value, reason end
  if V.mod and V.mod.log and type(V.mod.log.warn) == "function" then
    pcall(V.mod.log.warn, V.mod.log,
      "battle lifecycle adapter %s failed open: %s",
      tostring(method), tostring(value))
  end
  return nil, tostring(value)
end

local function claimLifecycle(battle, plan, provider, reason, entry)
  if battle == nil then return nil end
  return lifecycle("claim", battle, {
    provider=provider,
    requestedMode=plan and plan.mode,
    standardHud=plan and plan.standardHud,
    pokemonBack=plan and plan.pokemonBack,
    trainerBack=plan and plan.trainerBack,
    fallbackReason=reason,
    entry=entry,
  })
end

-- Release builds keep the optional HUD probe disabled. In particular, this
-- module never reaches through the mod sandbox for process environment data.
local DEBUG = false

-- Gen1Recomp presents the world canvas through one stable negative-Y contract
-- on iOS in every physical device orientation. A battle HUD rendered upright
-- into that canvas must cancel that exact Y presentation once; switching only
-- the HUD to X in a flipped orientation rotates its pixels by 180 degrees.
-- Voxel Ascendant no longer calls the
-- legacy edge-HUD compositor itself.  It must be absent from the public module
-- on iOS, because advertising it is enough for a companion to install
-- cross-canvas panel wrappers before the function ever runs.  An unavailable
-- platform receipt also fails closed: losing the optional edge layout is safer
-- than exposing it before iOS has been ruled out.
local function detectedOS()
  -- Prefer the native mobile renderer over an OS X compatibility receipt.
  -- The battle HUD transform is a renderer contract, not a host-UI contract.
  local runtime = love
  local function runtimeMember(owner, key)
    if type(owner) ~= "table" then return nil end
    local okValue, value = pcall(function() return owner[key] end)
    if okValue then return value end
    return nil
  end
  local system = runtimeMember(runtime, "system")
  local getOS = runtimeMember(system, "getOS")
  local nativeOS = nil
  if type(getOS) == "function" then
    local okNative, value = pcall(getOS)
    if okNative and type(value) == "string" and value ~= "" then
      nativeOS = value
      if value == "iOS" or value == "Android" then return value end
    end
  end
  local ok, Platform = pcall(require, "src.core.Platform")
  if ok and type(Platform) == "table"
      and type(Platform.detect) == "function" then
    local detected, info = pcall(Platform.detect)
    if detected and type(info) == "table" and type(info.os) == "string" then
      return info.os
    end
  end
  -- Current public Gen1Recomp builds do not ship src.core.Platform. LÖVE's
  -- bootstrap receipt is the sandbox-safe fallback and is present before
  -- love.conf on desktop, Android and iOS. Reading the receipt avoids direct
  -- system API access from mod code while still recovering the desktop edge
  -- compositor and the iOS pre-flip on those builds.
  local value = runtimeMember(runtime, "_os")
  if type(value) == "string" and value ~= "" then return value end
  return nativeOS
end

local PLATFORM_OS = detectedOS()
local BATTLE_CANVAS_PRESENTATION_SCHEMA =
  CanvasPresentation.BATTLE_PRESENTATION_SCHEMA
  or "voxel-ascendant/battle-canvas-presentation/v1"

-- Resolve orientation at the draw boundary for telemetry, never at module
-- initialization. The axis itself remains the stable Gen-1 iOS Y contract;
-- current builds return a primitive receipt passed unchanged through provider
-- pixels, frost sampling and frame ownership.
local function battleHudPresentation()
  if type(CanvasPresentation.battlePresentation) == "function" then
    local ok, receipt = pcall(
      CanvasPresentation.battlePresentation, PLATFORM_OS)
    if ok and type(receipt) == "table"
        and receipt.schema == BATTLE_CANVAS_PRESENTATION_SCHEMA
        and (receipt.axis == nil or receipt.axis == "x"
          or receipt.axis == "y") then
      return receipt
    end
  end
  local preflipped = type(CanvasPresentation.preflips) == "function"
    and CanvasPresentation.preflips(PLATFORM_OS) or false
  return {
    schema=BATTLE_CANVAS_PRESENTATION_SCHEMA,
    platform=PLATFORM_OS,
    orientation="unavailable",
    axis=preflipped and "y" or nil,
    source="legacy-preflips",
  }
end

local function beginBattleHud2D(g, shot, receipt)
  if not receipt or receipt.axis == nil then return true end
  if type(CanvasPresentation.beginBattle2D) == "function" then
    return CanvasPresentation.beginBattle2D(
      g, shot and shot.pw, shot and shot.ph, receipt)
  end
  if receipt.axis == "y" and type(CanvasPresentation.begin2D) == "function" then
    return CanvasPresentation.begin2D(g, shot and shot.ph, PLATFORM_OS)
  end
  return false
end

local LEGACY_SNAP_OS = {
  ["OS X"] = true,
  macOS = true,
  Windows = true,
  Linux = true,
  Android = true,
  NX = true,
  UWP = true,
}
local function legacySnapIsSafe()
  return LEGACY_SNAP_OS[PLATFORM_OS] == true
end

-- Kanto Ascendant and other companions feature-detect the historical
-- window-edge HUD compositor through the public OverworldBattle module.  On
-- iOS that compositor cannot be offered safely: even a clean false return
-- makes KASC restore the compact panels while the engine's grayscale battle
-- canvas is bound, so the later zone pass recolors the frost as an HP bar.
--
-- The function is therefore attached to the real owner module only off iOS
-- (below its implementation).  Keeping the original table matters: companion
-- hooks for side textures and overlays must still reach Voxel Ascendant rather
-- than mutate a detached proxy.

OverworldBattle.KEY = "battles"
OverworldBattle.LABEL = "3D-BTL"

-- Three rungs: native Gen 1 cards on the current map, those same cards on a
-- procedural pair of discs, or the original flat battle screen. MAP prefers
-- the physical encounter ground, but falls back to a portable Voxel arena
-- when that exact patch is unsafe. Only OFF deliberately selects the classic
-- screen; a transient arena miss must not switch a later encounter back to 2D.
OverworldBattle.ARENA = "arena"
OverworldBattle.FLAT_B = "flatB"

-- Gen1Recomp 0.1.90 moved compact enemy Pokemon from the long-standing
-- cartridge card fit (right edge 152, baseline 48) into the complete 7x7 ROM
-- tile buffer (hlcoord 12,0).  The latter is useful source fidelity, but its
-- extra bottom padding crowds the native status card and no longer matches the
-- reviewed VASC/KASC DEFAULT presentation.  Keep the compatibility fit narrow:
-- it is latched only for an explicitly selected DEFAULT + STANDARD battle,
-- never for ORAS, MAP, ARENA, DISCS, trainer art or oversized custom sheets.
OverworldBattle.NATIVE_FRONT_RIGHT = 152
OverworldBattle.NATIVE_FRONT_BASELINE = 48
OverworldBattle.NATIVE_FRONT_MAX = 56

function OverworldBattle.nativeCartridgeFrontPlacement(x, y, w, h, scale)
  w, h = tonumber(w), tonumber(h)
  if not (type(x) == "number" and type(y) == "number"
      and w and h and w > 0 and h > 0
      and w <= OverworldBattle.NATIVE_FRONT_MAX
      and h <= OverworldBattle.NATIVE_FRONT_MAX) then
    return x, y, scale
  end

  -- `x`/`y` already include the engine's scale, grow, slide and shake
  -- compensation.  Translate only the source-space slot origin from the new
  -- 7x7 layout back to the reviewed compact card.  This preserves every
  -- animation offset and works at any explicit integer sprite scale.
  local tw, th = math.floor(w / 8), math.floor(h / 8)
  if tw < 1 then tw = 1 elseif tw > 7 then tw = 7 end
  if th < 1 then th = 1 elseif th > 7 then th = 7 end
  local engineX = 96 + 8 * math.floor((8 - tw) / 2)
  local engineY = 8 * (7 - th)
  local reviewedX = OverworldBattle.NATIVE_FRONT_RIGHT - w
  -- A complete 7x7 (56 px) front begins at -8 to retain the reviewed y=48
  -- baseline. Clamping to zero moved precisely the largest opponent sprites
  -- eight pixels below the other cartridge fronts.
  local reviewedY = OverworldBattle.NATIVE_FRONT_BASELINE - h
  return x + reviewedX - engineX, y + reviewedY - engineY, scale
end

OverworldBattle.setting =
  ModSetting.new(OverworldBattle.KEY, OverworldBattle.LABEL,
                 { true, OverworldBattle.ARENA,
                   OverworldBattle.FLAT_B, false },
                 { "MAP", "ARENA", "DISCS", "OFF" })
-- Retired save values were previously treated as unknown and silently
-- collapsed to the default MAP rung. Preserve their historical meaning:
-- `stadium` was the physical-map stage and `stadiumB` the portable discs.
if type(OverworldBattle.setting.aliasLegacy) == "function" then
  OverworldBattle.setting:aliasLegacy("stadium", true)
  OverworldBattle.setting:aliasLegacy("stadiumB", OverworldBattle.FLAT_B)
end

local function selectedBattleMode()
  local plan = session and session.plan
  if plan and plan.mode ~= nil then return plan.mode end
  return OverworldBattle.setting:get()
end

-- ARENA paintings have their own saved ladder. MIX is intentionally the
-- default: it makes one stable per-battle choice only where a reviewed
-- FR/LG-like counterpart exists. Every other map keeps its VASC master.
OverworldBattle.ARENA_ART_KEY = "arenaArt"
OverworldBattle.ARENA_ART_LABEL = "ARENA BG"
OverworldBattle.ART_MIX = "mix"
OverworldBattle.ART_VASC = "vasc"
OverworldBattle.ART_FRLG = "frlg"
OverworldBattle.arenaArtSetting =
  ModSetting.new(OverworldBattle.ARENA_ART_KEY,
                 OverworldBattle.ARENA_ART_LABEL,
                 { OverworldBattle.ART_MIX, OverworldBattle.ART_VASC,
                   OverworldBattle.ART_FRLG },
                 { "V+FRLG", "VASC", "FRLG" },
                 OverworldBattle.ART_MIX)

function OverworldBattle.arenaArtMode()
  return OverworldBattle.arenaArtSetting:get()
end

local function latchArenaArt(style)
  arenaArtSerial = (arenaArtSerial + 1) % 2147483647
  style.arenaArtMode = OverworldBattle.arenaArtMode()
  -- A cheap deterministic shuffle over battle order and location seed. The
  -- result lives on this style record, so all frames and render passes agree.
  local seed = tonumber(style.seed) or 0
  local pick = ((seed % 65521) + (arenaArtSerial % 65521) * 25173
                + 13849) % 65521
  style.arenaArtPick = (pick % 2 == 0)
                       and OverworldBattle.ART_FRLG
                       or OverworldBattle.ART_VASC
  return style
end

OverworldBattle.latchArenaArt = latchArenaArt

-- DISCS keep their historical neutral VASC texture and add a separate saved
-- art ladder.  The FRLG-like side is resolved from the current map/profile;
-- MIX only chooses which family is used, never which terrain family fits.
OverworldBattle.DISK_ART_KEY = "diskArt"
OverworldBattle.DISK_ART_LABEL = "DISK ART"
OverworldBattle.diskArtSetting =
  ModSetting.new(OverworldBattle.DISK_ART_KEY,
                 OverworldBattle.DISK_ART_LABEL,
                 { OverworldBattle.ART_MIX, OverworldBattle.ART_VASC,
                   OverworldBattle.ART_FRLG },
                 { "V+FRLG", "VASC", "FRLG" },
                 OverworldBattle.ART_MIX)

function OverworldBattle.diskArtMode()
  return OverworldBattle.diskArtSetting:get()
end

local function latchDiskArt(style)
  diskArtSerial = (diskArtSerial + 1) % 2147483647
  style.diskArtMode = OverworldBattle.diskArtMode()
  local seed = tonumber(style.seed) or 0
  local pick = ((seed % 65521) + (diskArtSerial % 65521) * 31337
                + 19753) % 65521
  style.diskArtPick = (pick % 2 == 0)
                      and OverworldBattle.ART_FRLG
                      or OverworldBattle.ART_VASC
  return style
end

OverworldBattle.latchDiskArt = latchDiskArt

-- Whether the fight stands on the two carried DISCS rather than on the map
-- -- the B column above, whichever row of it. Asked by stageFor (what to
-- stage on), wantsFront (whether this map needs an arena at all) and, once
-- the arena carries the answer as `arena.discs`, by BattleScene and
-- VoxelScene for what to draw.
--
-- Read straight off the row rather than through Stadium, because it is a
-- question about the STAGE and half the rungs that answer yes have no
-- Stadium models on them at all.
function OverworldBattle.discs()
  return selectedBattleMode() == OverworldBattle.FLAT_B
end

function OverworldBattle.arenaMode()
  return selectedBattleMode() == OverworldBattle.ARENA
end

function OverworldBattle.portable()
  return OverworldBattle.discs() or OverworldBattle.arenaMode()
end

function OverworldBattle.enabled()
  return supported and selectedBattleMode() and true or false
end

local function stadiumModelsEnabled()
  local ok, provider = pcall(V.require, "PokemonModelProvider")
  if not (ok and type(provider) == "table") then return false end
  local predicate = provider.builtInModelsEnabled or provider.modelsEnabled
  if type(predicate) ~= "function" then return false end
  local called, enabled = pcall(predicate)
  return called and enabled == true
end

function OverworldBattle.stadium()
  return OverworldBattle.arenaMode()
         and BattleCam.arenaDirectorSelected()
end

-- ------- independent player-side sprite views
--
-- The two historical booleans remain the save-compatible expression of user
-- intent; effective presentation is resolved below from stage, active HUD and
-- an explicit full-body capability receipt.  MAP/standard may retain classic
-- 2D backs on the engine textbox.  ARENA never does.  DISCS permits the same
-- trainer/textbox exception, while Pokemon backs there must be certified
-- full-body world cards.  Unknown or cropped sources fail closed to Front.
OverworldBattle.POKEMON_BACK_KEY = "battleBack"
OverworldBattle.POKEMON_BACK_LABEL = "PKMN BACK"
OverworldBattle.TRAINER_BACK_KEY = "trainerBack"
OverworldBattle.TRAINER_BACK_LABEL = "TRAINER BACK"

OverworldBattle.pokemonBackSetting =
  ModSetting.new(OverworldBattle.POKEMON_BACK_KEY,
                 OverworldBattle.POKEMON_BACK_LABEL,
                 { false, true }, { "FRONT", "BACK" })
OverworldBattle.trainerBackSetting =
  ModSetting.new(OverworldBattle.TRAINER_BACK_KEY,
                 OverworldBattle.TRAINER_BACK_LABEL,
                 { false, true }, { "FRONT", "2D BACK" })

-- Compatibility for companions that still feature-detect the old field.
OverworldBattle.BACK_KEY = OverworldBattle.POKEMON_BACK_KEY
OverworldBattle.BACK_LABEL = OverworldBattle.POKEMON_BACK_LABEL
OverworldBattle.backSetting = OverworldBattle.pokemonBackSetting

-- The old player slot was authored for a 7x7/56px Gen-I card.  Keep its
-- 64-pixel envelope as diagnostics for the one legal classic/textbox path;
-- dimensions never grant full-body world compatibility.
OverworldBattle.CLASSIC_BACK_CARD_MAX = 64

local function spriteDimensions(sprite)
  if sprite == nil then return nil end
  local ok, width, height = pcall(function()
    if type(sprite.getDimensions) == "function" then
      return sprite:getDimensions()
    end
    if type(sprite.getWidth) == "function"
        and type(sprite.getHeight) == "function" then
      return sprite:getWidth(), sprite:getHeight()
    end
    return sprite.width, sprite.height
  end)
  width, height = tonumber(width), tonumber(height)
  if not (ok and width and height and width == width and height == height
          and width > 0 and height > 0
          and width < math.huge and height < math.huge) then
    return nil
  end
  return width, height
end

function OverworldBattle.backCardExceedsClassicSlot(sprite)
  local width, height = spriteDimensions(sprite)
  if not width then return false end
  return math.max(width, height) > OverworldBattle.CLASSIC_BACK_CARD_MAX
end

-- The engine's historical player slot assumes a 32px trainer card and gives
-- every non-species back pic its default 2x scale.  Modern full-body trainer
-- backs are commonly already 64px, so applying that default again makes them
-- twice as tall as the opposing trainer and crops them into the battlefield.
-- Fit only the one legal classic/textbox presentation into the reviewed
-- 64-logical-pixel envelope.  Smaller legacy cards retain their authored
-- scale, while oversized custom cards are reduced with nearest sampling.
function OverworldBattle.classicBackCardScale(sprite, requested)
  local scale = tonumber(requested)
  if not (scale and scale == scale and scale > 0 and scale < math.huge) then
    scale = 1
  end
  local width, height = spriteDimensions(sprite)
  if not width then return scale end
  local fit = OverworldBattle.CLASSIC_BACK_CARD_MAX
              / math.max(width, height)
  return math.min(scale, fit)
end

-- Selection remains independent of effective placement so old saves retain
-- their preference when the player later switches to a compatible mode.
function OverworldBattle.pokemonBackSelected()
  local plan = session and session.plan
  if plan and plan.pokemonBack ~= nil then
    return plan.pokemonBack == true
  end
  return OverworldBattle.pokemonBackSetting:get() and true or false
end

-- Classic Gen-I rear cards only make visual sense in the native lower slot,
-- and that slot only exists while VASC's STANDARD battle HUD is selected.
-- ARENA has no such slot. DISCS deliberately keeps Pokemon on its physical
-- platforms, so a rear there must carry an explicit full-body provider
-- receipt; image dimensions are never treated as proof.
local function standardBattleHudNow()
  local ok, settings = pcall(V.require, "OrasBattleHudSettings")
  if not (ok and type(settings) == "table"
      and type(settings.standardSelected) == "function") then
    return false
  end
  local called, selected = pcall(settings.standardSelected, V.mod)
  return called and selected == true
end

local function standardBattleHud()
  local plan = session and session.plan
  if plan and plan.standardHud ~= nil then return plan.standardHud == true end
  return standardBattleHudNow()
end

function OverworldBattle.capturePresentationPlan()
  return {
    schema="voxel-ascendant/battle-presentation-plan/v1",
    mode=OverworldBattle.setting:get(),
    standardHud=standardBattleHudNow(),
    pokemonBack=OverworldBattle.pokemonBackSetting:get() and true or false,
    trainerBack=OverworldBattle.trainerBackSetting:get() and true or false,
  }
end

function OverworldBattle.presentationPlan(expectedBattle)
  -- Callers that own a concrete BattleState must never observe another
  -- encounter's plan.  Nil remains the deliberate active-session query used
  -- by battle submenus that do not carry the BattleState themselves.
  if expectedBattle ~= nil
      and (not session or not sameBattle(session.battle, expectedBattle)) then
    return nil
  end
  return session and session.plan or nil
end

local function hasFullBodyBackReceipt(value)
  if type(value) ~= "table" then return false end
  if value.vascFullBodyBack == true
      or value.ascendantFullBodyBack == true then
    return true
  end
  local receipt = value.vascSpriteReceipt
    or value.ascendantSpriteReceipt
    or value.spriteReceipt
  return type(receipt) == "table"
    and receipt.apiVersion == 1
    and receipt.view == "back"
    and receipt.body == "full"
end

function OverworldBattle.fullBodyBackApproved(context, resolved)
  return hasFullBodyBackReceipt(context)
    or hasFullBodyBackReceipt(resolved)
end

function OverworldBattle.pokemonPresentation(context, resolved)
  if not OverworldBattle.pokemonBackSelected() then return "front" end
  local mode = selectedBattleMode()
  if mode == true and standardBattleHud() then return "classic_back" end
  if OverworldBattle.fullBodyBackApproved(context, resolved) then
    return "full_back"
  end
  return "front"
end

function OverworldBattle.trainerBackOptionAvailable()
  local mode = selectedBattleMode()
  return standardBattleHud()
    and (mode == true or mode == OverworldBattle.FLAT_B)
end

function OverworldBattle.trainerPresentation()
  local plan = session and session.plan
  local selected = plan and plan.trainerBack
  if selected == nil then
    selected = OverworldBattle.trainerBackSetting:get() and true or false
  end
  if selected
      and OverworldBattle.trainerBackOptionAvailable() then
    return "classic_back"
  end
  return "front"
end

-- Public historical seam. True means the engine must retain the native
-- player-side picture rather than also turning it into world geometry.
function OverworldBattle.pokemonBackPinned()
  return OverworldBattle.pokemonPresentation() == "classic_back"
end

function OverworldBattle.trainerBackPinned()
  return OverworldBattle.trainerPresentation() == "classic_back"
end

-- Historical API retained for companions. False means they must not restore
-- their own classic-slot overlay on top of VASC's staged rear.
function OverworldBattle.backPinned(expectedBattle)
  if expectedBattle ~= nil
      and (not session or not sameBattle(session.battle, expectedBattle)) then
    return false
  end
  return OverworldBattle.pokemonBackPinned()
end

function OverworldBattle.playerBackPinned(battle)
  if not battle then return false end
  if battle.showPlayerBack and battle.playerBackPic then
    return OverworldBattle.trainerBackPinned()
  end
  if battle.player and battle.player.sprite then
    return OverworldBattle.pokemonBackPinned()
  end
  return false
end

function OverworldBattle.trainerBackStaged(battle)
  -- Cropped trainer backs are never world geometry. In MAP/DISCS they are
  -- either pinned to the native textbox or replaced by a standing front; in
  -- ARENA only the standing front is legal.
  return false
end

function OverworldBattle.pinnedPic(battle, img)
  if not (battle and img and OverworldBattle.playerBackPinned(battle)) then
    return false
  end
  if battle.showPlayerBack and battle.playerBackPic then
    return img == battle.playerBackPic
  end
  if battle.player and battle.player.sprite then
    return img == battle.player.sprite
  end
  return false
end

-- ------- both mons face you
--
-- Standing on a map, seen from in front, a Pokemon showing you its BACK is
-- wrong twice over: it is turned away from the camera that is looking at it,
-- and the back pics are a different, smaller drawing made for a slot the
-- player never really sees. So the player's side asks for the FRONT pic too,
-- through the engine's own pokemon.sprite hook -- the seam that exists for
-- exactly this, so no battle code has to be touched to get it.
--
-- PKMN BACK asks for the rear source instead, but keeps exactly the same
-- grounded billboard placement and physical-size policy.
--
-- Answered BEFORE a battle exists, because the battler is built before the
-- battle is pushed. So it cannot ask whether this fight is staged; it asks
-- whether one on this map WOULD be -- the row is on, the 3D pass is
-- available, and the map has an arena -- which is the same question with the
-- same answer a moment later. Cached for the exact map object, encounter cell
-- and water state because the arena search walks the whole grid and this runs
-- once per battler. A map ID alone is stale after a same-ID reload and moving
-- between the two ends of a long route must ask for a new nearby clearing.
local staged = { key = nil, ready = false, arena = nil }

local function stageRequestKey(state, mode)
  if not (state and state.map and state.player) then return nil end
  local ok, key = pcall(BattleArena.requestKey, state.map,
    state.player.cellX, state.player.cellY, state.player.surfing)
  if not ok or key == nil then
    key = table.concat({ tostring(state.map), tostring(state.player.cellX),
      tostring(state.player.cellY), tostring(state.player.surfing) }, ":")
  end
  return tostring(mode) .. "\0" .. tostring(key)
end

local function canStageFront()
  if not OverworldBattle.enabled() then return false end
  if not Voxel3D.available() then return false end
  -- required here rather than through the file's own helper: this runs
  -- while a battler is being built, which is before that helper is defined
  local g = require("src.core.Game")
  local ow = g and g.overworld
  if not (ow and ow.map and ow.player) then return false end
  -- Use the exact same stage resolver as begin(), including MAP's neutral
  -- Voxel fallback and portable ARENA/DISCS failures. The engine asks for the
  -- sprite view before pushBattle; caching the concrete preflight result keeps
  -- that choice and the later session atomic instead of building BACK art and
  -- subsequently discovering a valid MAP fallback (or the reverse).
  local plan = OverworldBattle.capturePresentationPlan()
  local key = stageRequestKey(ow, plan.mode)
  if staged.key ~= key or not staged.ready then
    local ok, arena = pcall(OverworldBattle.stageFor, ow, plan, true)
    staged = { key=key, ready=true, arena=ok and arena or false }
  end
  return staged.arena ~= nil and staged.arena ~= false
end

function OverworldBattle.wantsFront(context, resolved)
  return OverworldBattle.pokemonPresentation(context, resolved) == "front"
    and canStageFront()
end

function OverworldBattle.wantsTrainerFront()
  return OverworldBattle.trainerPresentation() == "front" and canStageFront()
end

function OverworldBattle.wantsTrainerBack()
  return OverworldBattle.trainerBackPinned() and canStageFront()
end

-- Route the engine's player.sprite request for the trainer intro. Kept as a
-- named, pure seam so companion ordering can be regression-tested without
-- constructing a live BattleState.
function OverworldBattle.routeTrainerSprite(next, path, ctx,
                                             wantsBack, wantsFront)
  if not (ctx and ctx.kind == "battle" and ctx.side == "back") then
    return next(path, ctx)
  end

  if wantsBack then
    local routed = {}
    for key, value in pairs(ctx) do routed[key] = value end
    routed.kind = "battle_back"
    routed.voxelTrainerBack = true
    local out = next(path, routed)
    if routed.trueColor ~= nil then ctx.trueColor = routed.trueColor end
    return out
  end

  if not wantsFront then return next(path, ctx) end

  -- This must be a real FRONT request all the way down the chain, rather
  -- than a back request whose result is replaced afterwards. Kanto Ascendant
  -- 6.7 resolves character art in two player.sprite hooks: its inner hook
  -- sees ctx.side and its outer hook preserves any already-selected result.
  -- Sending the original back context therefore made TRAINER BACK = OFF
  -- impossible to honour -- the inner hook selected battleBack and the outer
  -- hook quite correctly kept it. Route a copy as side=front so every
  -- character/art provider gets to select its own matching standing portrait.
  local ok, FieldDefaults = pcall(require, "src.world.FieldDefaults")
  local front = ok and FieldDefaults and FieldDefaults.fieldValue
                and FieldDefaults.fieldValue(ctx.data, "playerPics", "front")
  if not front then return next(path, ctx) end

  local routed = {}
  for key, value in pairs(ctx) do routed[key] = value end
  routed.side = "front"
  routed.voxelTrainerFront = true
  local out = next(front, routed)
  if routed.trueColor ~= nil then ctx.trueColor = routed.trueColor end
  return out or front
end

-- ------- where the engine's own pics stand
--
-- The GB draws the player's back pic with its feet on the text box at row 96
-- and its 7x7-tile slot centred on x=40, and the enemy's front pic
-- bottom-aligned in a 7x7 slot centred on x=124 ending at row 56. Those two
-- points are the pics' FEET, they hold for every species at every scale (the
-- engine's placement helpers pin the bottom edge and the centre), and they
-- are what BattleCam is solved to put the two arena cells under.
--
-- Which makes the pin a subtraction: whatever the drift has done to the
-- camera this frame, each pic moves by its own cell's projected position
-- minus its anchor. At the middle of the drift that is zero.
OverworldBattle.ANCHOR = {
  player = { 26, 96 },
  enemy = { 124, 56 },
}

-- ------- how big a mon is
--
-- Not a decision made here. A pic is drawn at its own integer scale -- 1x for
-- a 56px front pic, 2x for a 32px back one -- because that is the only way it
-- keeps every pixel the artist drew, and the CAMERA is solved so that one
-- overworld square is that big on screen (see BattleCam). The mon fits its
-- tile because the tile was sized to the mon, not the other way round.
OverworldBattle.SLOT_W = { front = 56, back = 32 }

-- The two HUD blocks, as the pixel spans DrawEnemyHUDAndHPBar and
-- DrawPlayerHUDAndHPBar actually reach. Neither overlaps its side's pic at
-- the anchors above.
OverworldBattle.HUD_RECT = {
  enemy = { 8, 0, 80, 32 },
  player = { 72, 56, 88, 40 },
}

-- ------- the box at the bottom, on the same glass
--
-- The HUDs got frosted panels because black glyphs on grass are not readable.
-- The battle's text box and its menu had the opposite problem and the same
-- cause: they are drawn as an OPAQUE WHITE slab with a black border, which was
-- the field's own colour when the field was white and is a sheet of paper laid
-- over the bottom third of the diorama now that it is not.
--
-- So the box gets exactly what the HUDs get: the world behind it, blurred to
-- frosted glass and laid back down translucent, with the border and the text
-- drawn over it unchanged, and the same brightness verdict flipping the ink
-- when the ground under it is dark. Only the FILL is taken away -- every glyph
-- the engine draws inside the box is still the engine's own, in its own place.
--
-- These are the boxes BattleState:drawTextArea lays down, as GB-frame rects.
-- READ-ONLY duplicates of that function's own branches, the same kind of
-- mirror hudLive is and for the same reason: there is no seam that reports "a
-- move menu is up", and glass has to go down BEFORE the box that sits on it.
-- The worst a future engine change can do is frost a rectangle nothing lands
-- on, or leave a box unfrosted -- never break a battle.
--
-- Each rect stops where the next one starts rather than overlapping it: two
-- panels over the same pixels would frost it twice and leave a visible step
-- along the seam.
OverworldBattle.TEXT_RECT = {
  box = { 0, 96, 160, 48 },       -- Font.drawBox(0, 12, 20, 6), always
  -- moveSelect's TYPE/PP box, Font.drawBox(0, 8, 11, 5), trimmed to the rows
  -- above the box above -- its last tile row sits inside that one
  moves = { 0, 64, 88, 32 },
  -- mimicSelect's copy menu, Font.drawBox(0, 7, 16, 6), trimmed the same way
  mimic = { 0, 56, 128, 40 },
}

-- How far apart the two anchors are: the spacing every move animation was
-- authored against, and so the yardstick the live pair is measured with.
OverworldBattle.ANCHOR_SPAN = math.sqrt(
  (OverworldBattle.ANCHOR.enemy[1] - OverworldBattle.ANCHOR.player[1]) ^ 2
  + (OverworldBattle.ANCHOR.enemy[2] - OverworldBattle.ANCHOR.player[2]) ^ 2)

-- The effects layer's scale for this shot: how far apart the two mons
-- actually are on screen, over how far apart the slots they were authored
-- for were. Clamped hard at both ends -- an effect is pixel art and a wild
-- factor is worse than a slightly wrong one -- and held at exactly 1 when
-- the marks coincide, which is a projection about to degenerate rather
-- than a pair that has genuinely closed up.
OverworldBattle.ANIM_SCALE_MIN = 0.5
OverworldBattle.ANIM_SCALE_MAX = 2.0

function OverworldBattle.animScale(shot, px, py)
  if not (shot and shot.enemy and px and py) then return 1 end
  local dx, dy = shot.enemy[1] - px, shot.enemy[2] - py
  local span = math.sqrt(dx * dx + dy * dy)
  if not (span > 1) then return 1 end
  local k = span / OverworldBattle.ANCHOR_SPAN
  return math.max(OverworldBattle.ANIM_SCALE_MIN,
                  math.min(OverworldBattle.ANIM_SCALE_MAX, k))
end

function OverworldBattle.textRects(battle)
  if not battle or battle.blankForAskName then return {} end
  local r = OverworldBattle.TEXT_RECT
  local out = { box = r.box }
  if battle.phase == "moveSelect" then
    out.moves = r.moves
  elseif battle.phase == "mimicSelect" then
    out.mimic = r.mimic
  end
  return out
end

-- Glass footprints for both the original transient party rows and VASC's
-- persistent remaining-team receipts. Kept separate from the status blocks:
-- widening those panels across the whole band would recreate the opaque slab
-- the mobile transparency fix is removing.
function OverworldBattle.partyRects(battle, slide)
  if not battle then return {} end
  local out = {}
  if battle.introBalls then
    -- Gen I does not draw the OAM ball rows until the horizontal intro slide
    -- has landed.  The old panel mirror ignored that same guard, leaving two
    -- empty glass slabs over the trainers while the rows themselves were
    -- still suppressed by drawHUDs.
    if (tonumber(slide) or 0) ~= 0 then return out end
    if battle.enemyParty
        and (battle.kind == "trainer" or battle.kind == "link") then
      out.enemy = { 8, 14, 80, 20 }
    end
    out.player = { 72, 78, 80, 18 }
    return out
  end
  if battle.showEnemyBalls and battle.enemyParty
      and (tonumber(slide) or 0) == 0 then
    out.enemy = { 8, 14, 80, 20 }
  elseif BattlePartyBalls.persistentLive(battle, "enemy") then
    out.enemy = BattlePartyBalls.PERSISTENT_RECT.enemy
  end
  if BattlePartyBalls.persistentLive(battle, "player") then
    out.player = BattlePartyBalls.PERSISTENT_RECT.player
  end
  return out
end

-- ------- the HUDs, out at the window's own edges
--
-- The battle screen is 160x144 in the MIDDLE of the window and the world is the
-- whole of it. That left both HUD blocks huddled together in the middle of the
-- frame with map showing on either side of them, which reads as a Game Boy
-- screenshot pasted over a diorama rather than as the diorama's own furniture.
--
-- So each block is snapped to its own side: the foe's to the left edge of the
-- window, the player's to the right. Nothing about either block changes -- same
-- tiles, same size, same rows, drawn by the engine's own DrawEnemyHUDAndHPBar
-- and DrawPlayerHUDAndHPBar -- only where the pair sits. On a window the shape
-- of the GB screen there is nowhere to go and the snap is a no-op.
--
-- They cannot simply be MOVED there: the engine draws them into the 160x144 UI
-- canvas and everything outside it is clipped away. So the layer is rendered to
-- a texture and composited into the WORLD image instead, which is the one
-- surface in this mode that covers the whole window.

-- The rows each block is cut out of, full width. Generous on purpose:
-- AnimationShakeEnemyHUD nudges the foe's block sideways, a long name reaches
-- further than the panel does, and the pokeball rows and the safari ball count
-- belong to the block whose rows they sit in. Nothing drawHUDs draws lies
-- outside rows 0-96, and the two bands split that between them.
OverworldBattle.HUD_BAND = {
  enemy = { 0, 0, 160, 48 },
  player = { 0, 48, 160, 48 },
}

local battleLayoutModule, battleLayoutChecked
local function battleLayout()
  if battleLayoutChecked then return battleLayoutModule end
  battleLayoutChecked = true
  local ok, value = pcall(V.require, "BattleLayout")
  if ok and type(value) == "table" then battleLayoutModule = value end
  return battleLayoutModule
end

local function layoutAdjustment(id, context)
  local controller = battleLayout()
  if controller and type(controller.adjustment) == "function" then
    local ok, value = pcall(controller.adjustment, id, context)
    if ok and type(value) == "table" then return value end
  end
  return { x=0, y=0, scale=1 }
end

local function clamp(value, low, high)
  if high < low then return low end
  return math.max(low, math.min(high, value))
end

-- Transform a related group (for example the three command-pane slices) as
-- one zone.  Scaling every slice around itself would introduce seams; scaling
-- their common bounding box preserves the original Gen-I/KASC silhouette.
local function adjustTargetGroup(items, id, shot)
  if not (items and items[1] and shot) then return items end
  local adjustment = layoutAdjustment(id, shot.layoutContext)
  if adjustment.visible == false then return {} end
  local factor = tonumber(adjustment.scale) or 1
  local dx = (tonumber(adjustment.x) or 0) * (tonumber(shot.scale) or 1)
  local dy = (tonumber(adjustment.y) or 0) * (tonumber(shot.scale) or 1)
  local normalizedX = tonumber(adjustment.normalizedX)
  local normalizedY = tonumber(adjustment.normalizedY)
  local normalizedWidth = tonumber(adjustment.normalizedWidth)
  local normalizedHeight = tonumber(adjustment.normalizedHeight)
  if math.abs(factor - 1) < 1e-9 and dx == 0 and dy == 0
      and normalizedX == nil and normalizedY == nil
      and normalizedWidth == nil and normalizedHeight == nil then
    return items
  end
  local left, top, right, bottom
  for _, item in ipairs(items) do
    local target = item and item.target
    if target then
      left = left and math.min(left, target[1]) or target[1]
      top = top and math.min(top, target[2]) or target[2]
      right = right and math.max(right, target[1] + target[3])
        or (target[1] + target[3])
      bottom = bottom and math.max(bottom, target[2] + target[4])
        or (target[2] + target[4])
    end
  end
  if not left then return items end
  local width, height = right - left, bottom - top
  factor = math.max(.5, math.min(2, factor))
  factor = math.min(factor,
    (tonumber(shot.pw) or width) / math.max(width, 1),
    (tonumber(shot.ph) or height) / math.max(height, 1))
  local outWidth = normalizedWidth and normalizedWidth * shot.pw
    or width * factor
  local outHeight = normalizedHeight and normalizedHeight * shot.ph
    or height * factor
  local factorX, factorY = outWidth / math.max(width, 1),
                           outHeight / math.max(height, 1)
  local originX = normalizedX and normalizedX * shot.pw - outWidth / 2
    or left
  local originY = normalizedY and normalizedY * shot.ph - outHeight / 2
    or top
  originX = clamp(originX + dx, 0, (shot.pw or outWidth) - outWidth)
  originY = clamp(originY + dy, 0, (shot.ph or outHeight) - outHeight)
  for _, item in ipairs(items) do
    local target = item and item.target
    if target then
      target[1] = originX + (target[1] - left) * factorX
      target[2] = originY + (target[2] - top) * factorY
      target[3] = target[3] * factorX
      target[4] = target[4] * factorY
    end
  end
  return items
end

-- Where each block lands, in WORLD-canvas pixels: the panel rect the frosted
-- glass is cut to, plus the x its band is blitted at.
--
-- The foe's panel starts at the window's left edge and the player's ends at the
-- right one. The vertical is untouched, so both stay on the rows the GB put
-- them on. A band's own origin sits outside the window by the panel's inset --
-- the couple of pixels a HUD shake can push past the edge are clipped there,
-- which is the whole cost of the snap and is invisible.
function OverworldBattle.snapRects(shot, textPlacement)
  local position = BattleHud.position(PLATFORM_OS, shot.pw, shot.ph)
  local s = shot.scale * BattleHud.scale(PLATFORM_OS, shot.pw, shot.ph)
  local inset = BattleHud.edgeInset(position, shot.pw)
  local e, p = OverworldBattle.HUD_RECT.enemy, OverworldBattle.HUD_RECT.player
  if position == "stacked" then
    inset = math.floor(math.max(8, shot.pw * .035) + .5)
  end
  -- Keep the complete enemy source band inside the framebuffer. The status
  -- panel itself begins eight GB pixels into that band, but long names and
  -- the first party-ball rail legitimately use those leading pixels. Moving
  -- the band left by the panel inset clipped the first glyph (DIGLETT became
  -- `IGLETT`) on every wide desktop and phone shot.
  local ex = inset
  local px = shot.pw - inset - (p[1] + p[3]) * s
  -- Keep the panel tops on the battle rows KASC/Gen I authored even when the
  -- optional HUD scale changes.  The source bands begin above those panels,
  -- so their draw origins move by the scaled band-to-panel gap.
  local eb = OverworldBattle.HUD_BAND.enemy
  local pb = OverworldBattle.HUD_BAND.player
  local ey = shot.ly + e[2] * shot.scale - (e[2] - eb[2]) * s
  local py = shot.ly + p[2] * shot.scale - (p[2] - pb[2]) * s
  local enemyPanelY = ey + (e[2] - eb[2]) * s
  local playerPanelY = py + (p[2] - pb[2]) * s
  if position == "stacked" then
    local verticalInset = math.floor(math.max(10, shot.ph * .04) + .5)
    enemyPanelY = verticalInset
    -- The command/message frame owns the bottom edge.  Dock the player HUD
    -- immediately above the highest piece of that lower furniture instead
    -- of putting both into the same pixels (the old portrait overlap).
    local furnitureTop = nil
    for _, item in ipairs(textPlacement or {}) do
      local target = item and item.target
      if target and type(target[2]) == "number" then
        furnitureTop = furnitureTop and math.min(furnitureTop, target[2])
                       or target[2]
      end
    end
    furnitureTop = furnitureTop or (shot.ph - verticalInset - 48 * s)
    local gap = math.floor(math.max(6, shot.ph * .012) + .5)
    playerPanelY = math.max(verticalInset + e[4] * s + gap,
                            furnitureTop - gap - p[4] * s)
    ey = enemyPanelY - (e[2] - eb[2]) * s
    py = playerPanelY - (p[2] - pb[2]) * s
  end
  local placements = {
    enemy = { x = ex, y = ey, scale = s },
    player = { x = px, y = py, scale = s },
  }
  local rects = {
    enemy = { inset, enemyPanelY, (e[1] + e[3]) * s, e[4] * s },
    player = { shot.pw - inset - p[3] * s,
               playerPanelY, p[3] * s, p[4] * s },
  }
  -- Status cards retain their independently authored source bands.  Scale and
  -- move the band around the panel's current top-left so names, gender/EXP
  -- additions and HP bars cannot split into a second overlapping HUD.
  for _, side in ipairs({ "enemy", "player" }) do
    local adjustment = layoutAdjustment("hud_" .. side .. "_status",
                                        shot.layoutContext)
    local factor = tonumber(adjustment.scale) or 1
    local dx = (tonumber(adjustment.x) or 0) * (tonumber(shot.scale) or 1)
    local dy = (tonumber(adjustment.y) or 0) * (tonumber(shot.scale) or 1)
    local normalizedX = tonumber(adjustment.normalizedX)
    local normalizedY = tonumber(adjustment.normalizedY)
    if adjustment.visible ~= false
        and (math.abs(factor - 1) >= 1e-9 or dx ~= 0 or dy ~= 0
        or normalizedX ~= nil or normalizedY ~= nil) then
      local rect, place = rects[side], placements[side]
      factor = math.max(.5, math.min(2, factor))
      factor = math.min(factor,
        shot.pw / math.max(rect[3], 1), shot.ph / math.max(rect[4], 1))
      local width, height = rect[3] * factor, rect[4] * factor
      local x = normalizedX and normalizedX * shot.pw - width / 2
        or rect[1]
      local y = normalizedY and normalizedY * shot.ph - height / 2
        or rect[2]
      x = clamp(x + dx, 0, shot.pw - width)
      y = clamp(y + dy, 0, shot.ph - height)
      place.x = x + (place.x - rect[1]) * factor
      place.y = y + (place.y - rect[2]) * factor
      place.scale = place.scale * factor
      rects[side] = { x, y, width, height }
    end
  end
  return rects, placements
end

-- A rect measured in the GB frame, in WORLD-canvas pixels: where the letterbox
-- blit will actually put it. The text box has not moved anywhere -- it is drawn
-- where it always was -- but its glass is laid into the world image alongside
-- the HUDs' (see snapHUDs), which is the surface that reaches the screen a
-- pixel to a pixel rather than magnified out of a 160x144 canvas.
local function toWorld(rect, shot)
  local s = shot.scale
  return { shot.lx + rect[1] * s, shot.ly + rect[2] * s,
           rect[3] * s, rect[4] * s }
end

local function placement(source, target)
  return { source=source, target=target }
end

-- Source/target pairs for the battle's lower furniture. Message boxes keep
-- their familiar full-width Gen-I composition.  The command screen keeps the
-- exact KASC/Gen-I two-part silhouette as well, but its empty message half is
-- extended across the spare widescreen columns so the two halves still meet.
-- Only one empty source column is widened; borders, glyphs and the complete
-- four-command pane remain at native pixel scale.  This avoids both a Game-Boy
-- rectangle hovering in the centre and the artificial third/middle segment a
-- large gap between two independently edge-docked panes created.
function OverworldBattle.textPlacements(battle, shot)
  if not (battle and shot and (shot.scale or 0) > 0) then return {} end
  local hudPosition = BattleHud.position(PLATFORM_OS, shot.pw, shot.ph)
  local furnitureScale = BattleHud.scale(
    PLATFORM_OS, shot.pw, shot.ph)
  local phase = battle.phase
  local furnitureTarget = (phase == "menu" or phase == "moveSelect"
    or phase == "mimicSelect") and "hud_command" or "hud_message"
  local full = function(source)
    if hudPosition == "stacked" then
      local s = shot.scale * furnitureScale
      local bottom = math.floor(math.max(8, shot.ph * .02) + .5)
      local w, h = source[3] * s, source[4] * s
      return adjustTargetGroup({ placement(source, {
        math.floor((shot.pw - w) / 2 + .5), shot.ph - bottom - h, w, h,
      }) }, furnitureTarget, shot)
    end
    return adjustTargetGroup(
      { placement(source, toWorld(source, shot)) }, furnitureTarget, shot)
  end
  if battle.blankForAskName then return {} end
  if phase == "menu" and not battle.safari then
    local s = shot.scale * furnitureScale
    local inset = math.floor(math.max(8, shot.pw * .025) + .5)
    local bottom = math.floor(math.max(8, shot.ph * .02) + .5)
    local leftCap = { 0, 96, 8, 48 }
    local leftRail = { 8, 96, 1, 48 }
    local right = { 64, 96, 96, 48 }
    local rightX = shot.pw - inset - right[3] * s
    local railX = inset + leftCap[3] * s
    if rightX > railX then
      local y = shot.ph - bottom - 48 * s
      return adjustTargetGroup({
        placement(leftCap, { inset, y,
                             leftCap[3] * s, leftCap[4] * s }),
        placement(leftRail, { railX, y, rightX - railX,
                              leftRail[4] * s }),
        placement(right, { rightX, y,
                           right[3] * s, right[4] * s }),
      }, furnitureTarget, shot)
    end
    return full(OverworldBattle.TEXT_RECT.box)
  end
  if phase == "moveSelect" then
    local s = shot.scale * furnitureScale
    local inset = math.floor(math.max(8, shot.pw * .025) + .5)
    local bottom = math.floor(math.max(8, shot.ph * .02) + .5)
    local info = { 0, 64, 88, 40 }
    local moves = { 32, 96, 128, 48 }
    local gap = math.floor(math.max(16, shot.pw * .035) + .5)
    if (info[3] + moves[3]) * s + inset * 2 + gap <= shot.pw then
      return adjustTargetGroup({
        placement(info, { inset, shot.ph - bottom - info[4] * s,
                          info[3] * s, info[4] * s }),
        placement(moves, { shot.pw - inset - moves[3] * s,
                           shot.ph - bottom - moves[4] * s,
                           moves[3] * s, moves[4] * s }),
      }, furnitureTarget, shot)
    end
    return full({ 0, 64, 160, 80 })
  end
  if phase == "mimicSelect" then return full({ 0, 56, 160, 88 }) end
  return full(OverworldBattle.TEXT_RECT.box)
end

-- Persistent remaining-team receipts are their own piece of battle furniture.
-- They used to be baked into the two 48px status bands, which meant the player
-- row travelled with the HP card and was frequently covered by that card, a
-- battler or KASC's zone pass.  Give each row an explicit screen-space target:
-- the player's row occupies the otherwise unused rail between the HP card and
-- the command/message frame, while the opponent's row stays attached just
-- below its status card.  The native intro/faint rows remain in the original
-- status bands and are not handled here.
function OverworldBattle.persistentPartyPlacements(
    battle, shot, slide, statusRects, statusPlacement, textPlacement)
  if not (battle and shot and statusRects and statusPlacement) then return {} end
  local out = {}
  local naturalScale = math.max(1,
    math.floor((tonumber(shot.scale) or 1) * .45 + .5))
  local furnitureTop = nil
  for _, item in ipairs(textPlacement or {}) do
    local target = item and item.target
    if target and type(target[2]) == "number" then
      furnitureTop = furnitureTop and math.min(furnitureTop, target[2])
                     or target[2]
    end
  end

  local function add(side)
    if not BattlePartyBalls.persistentLive(battle, side) then return end
    local source = BattlePartyBalls.PERSISTENT_RECT[side]
    local status = statusRects[side]
    local place = statusPlacement[side]
    if not (source and status and place) then return end
    local scale = math.min(naturalScale, math.max(1,
      math.floor((tonumber(place.scale) or 1) + .5)))
    local margin = math.max(2, math.floor(scale * .5 + .5))
    local x, y
    if side == "player" then
      local statusBottom = status[2] + status[4]
      if furnitureTop and furnitureTop > statusBottom then
        local available = furnitureTop - statusBottom
        local fit = math.floor((available - margin * 2) / source[4])
        if fit >= 1 then scale = math.min(scale, fit) end
        local height = source[4] * scale
        y = statusBottom + math.max(1,
          math.floor((available - height) / 2 + .5))
      else
        y = statusBottom + margin
      end
      x = status[1] + status[3] - source[3] * scale
    else
      x = place.x + source[1] * scale
      y = status[2] + status[4] + margin
    end
    local target = { math.floor(x + .5), math.floor(y + .5),
                     source[3] * scale, source[4] * scale }
    local item = {
      side = side, source = source, target = target,
      panel = { target[1], target[2], target[3], target[4] },
    }
    adjustTargetGroup({ item }, "hud_" .. side .. "_party", shot)
    item.panel = { item.target[1], item.target[2],
                   item.target[3], item.target[4] }
    out[#out + 1] = item
  end

  add("enemy")
  add("player")
  return out
end

-- A rect inside one source HUD band, mapped to the band's snapped placement.
local function bandRectWorld(rect, band, place)
  local s = place.scale
  return { place.x + rect[1] * s,
           place.y + (rect[2] - band[2]) * s,
           rect[3] * s, rect[4] * s }
end

-- ------- the live battle
--
-- nil when no overworld battle is running. Never more than one: battles do
-- not nest. The forward declaration lives beside the module state above so
-- pre-battle sprite policy and active draw hooks consult the same owner.
local snapHUDs = nil
local hudExtrasDrawer = nil
local battleHudProvider = nil
local defaultBattleHudProvider = nil
local drawBattleHudProvider = nil
local warnBattleHudProvider = nil
local battleHudProviderWarnings = {}
local battleHudProviderLayer = nil
local battleHudProviderLayerW, battleHudProviderLayerH = 0, 0
local HUD_SNAP_RECEIPT_KEY = "__voxelAscendantWideHudReceipt"
local HUD_SNAP_RECEIPT_SCHEMA = "voxel-ascendant/hud-snap/v1"
local HUD_CAMERA_BOUNDS_SCHEMA = "voxel-ascendant/hud-camera-bounds/v1"
local HUD_DAMAGE_BOUNDS_SCHEMA = "voxel-ascendant/hud-damage-bounds/v1"

local function game()
  return require("src.core.Game")
end

local function copyBattleHudPresentation(shot)
  local value = type(shot) == "table"
    and rawget(shot, "battleHudPresentation") or nil
  if type(value) ~= "table"
      or value.schema ~= BATTLE_CANVAS_PRESENTATION_SCHEMA
      or (value.axis ~= nil and value.axis ~= "x" and value.axis ~= "y") then
    return nil
  end
  return {
    schema=value.schema,
    platform=value.platform,
    orientation=value.orientation,
    axis=value.axis,
    source=value.source,
  }
end

-- Whether this frame's HUDs went out to the window's edges instead of being
-- drawn in the GB frame. False whenever the composite could not be made, which
-- is what leaves the in-frame HUD as the fallback rather than no HUD at all.
local function markSnapped(battle, shot, value, reason, owner)
  if type(battle) ~= "table" then return end
  battle[HUD_SNAP_RECEIPT_KEY] = {
    schema = HUD_SNAP_RECEIPT_SCHEMA,
    shot = shot,
    snapped = value == true,
    reason = reason,
    owner = owner,
    presentation = copyBattleHudPresentation(shot),
  }
  -- Retain the historical boolean for the party-ball overlay and compatible
  -- companions, but derive it from the exact same frame-local receipt.
  battle.voxelAscendantHudSnapped = value == true
end

local function snapped(battle, shot)
  if type(battle) == "table" then
    shot = shot or rawget(battle, "voxelAscendantShot")
    local receipt = rawget(battle, HUD_SNAP_RECEIPT_KEY)
    if type(receipt) == "table"
        and receipt.schema == HUD_SNAP_RECEIPT_SCHEMA
        and receipt.shot == shot then
      return receipt.snapped == true
    end
    return false
  end
  return (session and session.snapped) and true or false
end

-- A replacement provider has already committed the complete visible HUD, but
-- cooperative companions may observe the long-standing public snapHUDs seam
-- to decide whether their captured native draw chain still needs to run.  Let
-- wrappers observe one successful call without asking the renderer's own
-- implementation to composite the legacy bands a second time.  Function
-- identity is the whole contract here: VASC knows nothing about the observer,
-- its receipt keys or its package internals.
local function acknowledgeHudSnapshot(battle, shot)
  if type(OverworldBattle.snapHUDs) ~= "function" then
    return true
  end
  local ok, acknowledged
  if validLegacyCompatibilityBridge(legacyCompatibilityBridge) then
    if not legacyPresentationOverridden("snapHUDs") then return true end
    ok, acknowledged = pcall(
      legacyPresentation, "snapHUDs", battle, shot)
  else
    -- Isolated legacy hosts and pre-Card companions may still wrap the
    -- documented function directly. Production KASC uses the owner-scoped
    -- bridge above; this fallback preserves the old read-only observation
    -- seam without exposing any renderer lifecycle mutation.
    local publicSnap = OverworldBattle.snapHUDs
    if rawequal(publicSnap, snapHUDs) then return true end
    ok, acknowledged = pcall(publicSnap, battle, shot)
  end
  return ok and acknowledged == true
end

function OverworldBattle.hudSnapReceipt(battle)
  local receipt = type(battle) == "table"
                  and rawget(battle, HUD_SNAP_RECEIPT_KEY) or nil
  if type(receipt) ~= "table" or receipt.schema ~= HUD_SNAP_RECEIPT_SCHEMA then
    return nil
  end
  return receipt
end

-- One optional, public replacement-HUD owner. The renderer retains canvas,
-- pre-flip and exact-shot receipt ownership; a provider supplies only policy
-- and pixels. Returning false (or throwing) is deliberately fail-open to the
-- existing VASC/engine HUD for that frame.
local function validBattleHudProvider(provider)
  return type(provider) == "table" and provider.apiVersion == 1
      and type(provider.id) == "string" and provider.id ~= ""
      and type(provider.claim) == "function"
      and type(provider.draw) == "function"
end

function OverworldBattle.setBattleHudProvider(provider)
  if provider == nil then
    battleHudProvider = nil
    return true
  end
  if not validBattleHudProvider(provider) then
    return false, "invalid-provider"
  end
  battleHudProvider = provider
  return true
end

-- VASC's bundled ORAS renderer is a permanent fallback, not a competitor for
-- the public companion slot. KASC occupies the external slot and is always
-- attempted first; clearing or failing that provider immediately reveals this
-- default again without relying on mod load order.
function OverworldBattle.setDefaultBattleHudProvider(provider)
  if provider == nil then
    defaultBattleHudProvider = nil
    return true
  end
  if not validBattleHudProvider(provider) then
    return false, "invalid-provider"
  end
  defaultBattleHudProvider = provider
  return true
end

function OverworldBattle.battleHudProviderReceipt()
  if not battleHudProvider and not defaultBattleHudProvider then return nil end
  return {
    apiVersion = 1,
    id = battleHudProvider and battleHudProvider.id
      or defaultBattleHudProvider.id,
    externalId = battleHudProvider and battleHudProvider.id or nil,
    defaultId = defaultBattleHudProvider and defaultBattleHudProvider.id or nil,
    cameraBoundsSchema = HUD_CAMERA_BOUNDS_SCHEMA,
    damageBoundsSchema = HUD_DAMAGE_BOUNDS_SCHEMA,
  }
end

local function providerClaimsHud(provider, battle, shot)
  if not provider then return false end
  local ok, claimed = pcall(provider.claim, battle, shot)
  if not ok then return nil, "claim-error" end
  return claimed == true
end

local function providerCameraBounds(provider, battle, shot)
  if type(provider.cameraBounds) ~= "function"
      or provider.cameraBoundsSchema ~= HUD_CAMERA_BOUNDS_SCHEMA then
    return nil, "provider-bounds-unavailable"
  end
  local ok, bounds, boundsReason = pcall(provider.cameraBounds, battle, shot)
  if not ok then return nil, "provider-bounds-error" end
  if bounds == nil and type(boundsReason) == "string" then
    return nil, boundsReason
  end
  if type(bounds) ~= "table" or bounds.schema ~= HUD_CAMERA_BOUNDS_SCHEMA
      or tonumber(bounds.width) ~= tonumber(shot.pw)
      or tonumber(bounds.height) ~= tonumber(shot.ph)
      or type(bounds.safeInsets) ~= "table"
      or type(bounds.reserved) ~= "table" then
    return nil, "provider-bounds-malformed"
  end
  return bounds
end

local function nativeCameraBounds(battle, shot)
  if not (battle and shot and tonumber(shot.pw) and tonumber(shot.ph)
          and tonumber(shot.scale) and shot.scale > 0) then return nil end
  local reserved = {}
  local function add(id, rect)
    if type(rect) == "table" and tonumber(rect[1]) and tonumber(rect[2])
        and tonumber(rect[3]) and tonumber(rect[4])
        and rect[3] > 0 and rect[4] > 0 then
      reserved[#reserved + 1] = {
        id=id, x=rect[1], y=rect[2], w=rect[3], h=rect[4],
      }
    end
  end
  local position = BattleHud.position(PLATFORM_OS, shot.pw, shot.ph)
  if position == "frame" then
    for side, rect in pairs(OverworldBattle.HUD_RECT) do
      add(side .. "-status", {
        shot.lx + rect[1] * shot.scale,
        shot.ly + rect[2] * shot.scale,
        rect[3] * shot.scale, rect[4] * shot.scale,
      })
    end
  else
    local text = OverworldBattle.textPlacements(battle, shot)
    local rects = OverworldBattle.snapRects(shot, text)
    add("enemy-status", rects and rects.enemy)
    add("player-status", rects and rects.player)
    for index, item in ipairs(text) do
      add("text-" .. tostring(index), item and item.target)
    end
  end
  return {
    schema=HUD_CAMERA_BOUNDS_SCHEMA, width=shot.pw, height=shot.ph,
    safeInsets={ 0, 0, 0, 0 }, reserved=reserved,
  }
end

-- Resolve the owner exactly as the transactional draw path does. An external
-- provider that actually claims this frame owns its camera bounds as well;
-- VASC never reaches into KASC/private state or falls through to a different
-- skin's geometry. Missing/malformed public bounds deliberately return nil so
-- BattleCam selects a static composition.
function OverworldBattle.battleHudCameraBounds(battle, shot)
  local externalClaim, externalReason = providerClaimsHud(
    battleHudProvider, battle, shot)
  if externalClaim == nil then return nil, externalReason end
  if externalClaim then
    return providerCameraBounds(battleHudProvider, battle, shot)
  end
  if battleHudProvider and battleHudProvider.exclusive == true then
    return nil, "exclusive-provider-native-bounds-unavailable"
  end
  local defaultClaim, defaultReason = providerClaimsHud(
    defaultBattleHudProvider, battle, shot)
  if defaultClaim == nil then return nil, defaultReason end
  if defaultClaim then
    return providerCameraBounds(defaultBattleHudProvider, battle, shot)
  end
  return nativeCameraBounds(battle, shot)
end

local function rectHits(a, b, padding)
  padding = tonumber(padding) or 0
  return a[1] < b.x + b.w + padding
     and a[1] + a[3] > b.x - padding
     and a[2] < b.y + b.h + padding
     and a[2] + a[4] > b.y - padding
end

-- Provider-neutral projected safe-frame verdict. Both feet and the complete
-- conservative actor prisms must remain inside the physical display safe area
-- and outside every rectangle the claiming HUD says it will paint.
function OverworldBattle.battleHudCameraSafe(battle, arena, groundY, camera)
  -- Two individually in-frame silhouettes can still project into one
  -- unreadable centre blob when SMART looks almost straight down the arena
  -- axis. Measure the empty screen-space distance between their exact alpha
  -- hulls and require a small viewport- and sprite-aware gutter. This rejects
  -- only the camera seat; it never moves a battler, changes a texture or
  -- weakens the HUD collision gate.
  local function actorPairSeparated(candidateShot, playerHull, enemyHull)
    if not (candidateShot and type(playerHull) == "table"
        and type(enemyHull) == "table") then return true end
    local px, py, pw, ph = tonumber(playerHull[1]), tonumber(playerHull[2]),
      tonumber(playerHull[3]), tonumber(playerHull[4])
    local ex, ey, ew, eh = tonumber(enemyHull[1]), tonumber(enemyHull[2]),
      tonumber(enemyHull[3]), tonumber(enemyHull[4])
    if not (px and py and pw and ph and ex and ey and ew and eh
        and pw > 0 and ph > 0 and ew > 0 and eh > 0) then return true end
    local dx = math.max(0, math.max(px, ex) - math.min(px + pw, ex + ew))
    local dy = math.max(0, math.max(py, ey) - math.min(py + ph, ey + eh))
    local smallerActor = math.min(math.max(pw, ph), math.max(ew, eh))
    local viewport = math.min(tonumber(candidateShot.pw) or 0,
                              tonumber(candidateShot.ph) or 0)
    local minimum = math.min(48, math.max(12, viewport * .035,
                                          smallerActor * .18))
    return dx * dx + dy * dy >= minimum * minimum
  end
  local live = session and sameBattle(session.battle, battle) and session or nil
  local shot = BattleScene.cameraSafetyShot(
    arena, groundY, camera,
    live and live.textures or nil,
    live and live.arena and live.arena.map
      or live and live.state and live.state.map
      or arena and arena.map,
    live and live.token or nil)
  if not shot then return nil, "camera-projection-unavailable" end
  if shot.groundRegions then
    local Ground = V.require("ArenaGround")
    for _, actor in pairs(shot.actorVisuals or {}) do
      local f = actor.groundFootprint
      if f and not Ground.supports(shot.groundRegions,
          f[1]+f[3]*.5,f[2]+f[4]*.5,f[3]*.5+.002,f[4]*.5+.002) then
        return false, "actor-contact-outside-ground"
      end
    end
  end
  local bounds, reason = OverworldBattle.battleHudCameraBounds(battle, shot)
  if not bounds then
    -- The bundled ORAS provider uses this one reason only after it has exact
    -- actor receipts and a ready status pair, but proves that pair collides
    -- with the current safe frame or bottom HUD.  That is a definitive seat
    -- rejection, not unknown provider geometry.  Keep pending, unavailable,
    -- malformed and error cases tri-state nil so their conservative fallback
    -- behaviour remains unchanged.
    if reason == "owner-render-unsafe" then return false, reason end
    return nil, reason
  end
  local insets = bounds.safeInsets
  local margin = math.max(10, math.floor(math.min(shot.pw, shot.ph) * .018))
  local hudLeft = tonumber(insets[1]) or 0
  local hudTop = tonumber(insets[2]) or 0
  local hudRight = shot.pw - (tonumber(insets[3]) or 0)
  local hudBottom = shot.ph - (tonumber(insets[4]) or 0)
  local left, top = hudLeft + margin, hudTop + margin
  local right, bottom = hudRight - margin, hudBottom - margin
  local padding = math.max(8, math.floor(math.min(shot.pw, shot.ph) * .012))
  local statusCards = {}
  local visibleActorHulls = {}
  for _, rect in ipairs(bounds.reserved) do
    if type(rect) ~= "table" or not (tonumber(rect.x) and tonumber(rect.y)
        and tonumber(rect.w) and tonumber(rect.h)
        and rect.w > 0 and rect.h > 0) then
      return nil, "provider-bounds-malformed"
    end
    if rect.allowOwnActorOverlap ~= nil then
      local ownerSide = rect.ownerSide
      if rect.allowOwnActorOverlap ~= true
          or (ownerSide ~= "player" and ownerSide ~= "enemy")
          or tostring(rect.id or "") ~= ownerSide .. "-status" then
        return nil, "provider-bounds-malformed"
      end
    elseif rect.ownerSide ~= nil then
      return nil, "provider-bounds-malformed"
    end
    if rect.ownerVisualGap ~= nil
        and (rect.ownerVisualGap ~= true
          or rect.allowOwnActorOverlap ~= true) then
      return nil, "provider-bounds-malformed"
    end
    local id = tostring(rect.id or "")
    local physicalBottomDock = rect.safeAreaPolicy == "physical-bottom-dock"
    if rect.safeAreaPolicy ~= nil
        and (not physicalBottomDock
          or (id ~= "command" and id ~= "fight" and id ~= "message")
          or math.abs(rect.y + rect.h - shot.ph) > 1e-6) then
      return nil, "provider-bounds-malformed"
    end
    -- The bundled ORAS command/message dock intentionally paints through the
    -- iOS home-indicator inset to the physical bottom edge.  Only a provider's
    -- explicit, validated bottom-dock receipt receives that one-axis exception;
    -- status cards and every other rectangle remain inside all safe insets.
    local rectBottom = physicalBottomDock and shot.ph or hudBottom
    if rect.x < hudLeft or rect.y < hudTop
        or rect.x + rect.w > hudRight
        or rect.y + rect.h > rectBottom then
      return false, tostring(rect.id or "hud") .. "-outside-safe-frame"
    end
    if tostring(rect.id or ""):find("-status", 1, true) then
      statusCards[#statusCards + 1] = rect
    end
  end
  for index = 1, #statusCards do
    for other = index + 1, #statusCards do
      local a, b = statusCards[index], statusCards[other]
      if a.x < b.x + b.w + padding
          and a.x + a.w + padding > b.x
          and a.y < b.y + b.h + padding
          and a.y + a.h + padding > b.y then
        return false, "status-card-overlap"
      end
    end
  end
  for _, side in ipairs({ "player", "enemy" }) do
    local visual = shot.actorVisuals and shot.actorVisuals[side]
    local hiddenCurrentActor = false
    if type(shot.actorVisuals) == "table" and visual == nil then
      -- During an exact send-out or completed faint the engine has no body.
      -- A fainted side has no status owner left to publish an owner-gap
      -- receipt. Its absent nominal prism must not reject the next message.
      -- A nominal full-size prism for that absent actor can intersect the
      -- other side's HP card and reject every replacement camera. Require an
      -- explicit engine hide flag, no trainer occupying the slot, and no
      -- rendered visual: a growing Stadium model already has a receipt and
      -- must still pass the ordinary complete-hull checks below.
      if live and battle then
        local battler = battle[side]
        local zeroScale = false
        if battler and type(battle.growInScale) == "function" then
          local ok, scale = pcall(battle.growInScale, battle, battler)
          zeroScale = ok and scale == 0
        end
        hiddenCurrentActor = (side == "enemy"
          and not battle.showEnemyTrainer
          and (battle.enemySendingOut == true or battle.enemyHidden == true
            or zeroScale or (battler and battler.fainted == true)))
          or (side == "player" and not battle.showPlayerBack
            and (battle.sendingOut == true or zeroScale
              or (battler and battler.fainted == true)))
      end
      for _, rect in ipairs(bounds.reserved) do
        if rect.ownerSide == side and rect.ownerVisualGap == true
            and rect.allowOwnActorOverlap == true then
          hiddenCurrentActor = true; break
        end
      end
    end
    if not hiddenCurrentActor and type(shot.actorVisuals) == "table"
        and visual == nil and live and live.presentationCommitted == true
        and live.pendingSwitch == nil then
      -- STANDARD's native HUD has no floating owner-gap receipt. Its pinned
      -- player picture and the engine's explicit hide programs still do not
      -- produce world geometry. Restrict this to an established deployment;
      -- missing assets during initial send-out/switch remain a pending error.
      local battler = battle and battle[side]
      local pic = battler and battle.picFx and battle.picFx[battler]
      local blink = false
      if battler and type(battle.fxHidden) == "function" then
        local ok, hidden = pcall(battle.fxHidden, battle, battler)
        blink = ok and hidden == true
      end
      hiddenCurrentActor = (side == "player"
        and OverworldBattle.playerBackPinned(battle))
        or (battler ~= nil and (blink or (pic and pic.hidden == true)))
    end
    -- Fly/Dig and simultaneous damage blinks have no body pixels. The HUD's
    -- exact same-battler owner receipt authorizes that absence; a nominal
    -- prism must not collide with command buttons during the hidden frame.
    if not hiddenCurrentActor then
    local hull = visual and visual.hull or shot.actorHulls[side]
    local visualFoot = visual and visual.foot
    local foot = visualFoot and { visualFoot.x, visualFoot.y }
                 or shot.actorFeet[side]
    if not (hull and foot and hull[1] >= left and hull[2] >= top
            and hull[1] + hull[3] <= right
            and hull[2] + hull[4] <= bottom
            and foot[1] >= left and foot[1] <= right
            and foot[2] >= top and foot[2] <= bottom) then
      return false, side .. "-outside-safe-frame"
    end
    -- Only exact visible alpha receipts participate in the pair-readability
    -- gate. Attack/damage frames may intentionally omit one visual and retain
    -- a conservative nominal prism; that hidden side must not invent a pair
    -- collision while the ordinary owner-gap rules remain active below.
    if visual and type(visual.hull) == "table" then
      visibleActorHulls[side] = visual.hull
    end
    for _, rect in ipairs(bounds.reserved) do
      if rectHits(hull, rect, padding)
          or (foot[1] >= rect.x - padding
              and foot[1] <= rect.x + rect.w + padding
              and foot[2] >= rect.y - padding
              and foot[2] <= rect.y + rect.h + padding) then
        local battler = battle and battle[side] or nil
        local hiddenOwnActor = rect.allowOwnActorOverlap == true
          and rect.ownerVisualGap == true and rect.ownerSide == side
          and type(shot.actorVisuals) == "table" and visual == nil
          and battler ~= nil and battler.mon ~= nil
        if not hiddenOwnActor then
          return false, side .. "-under-" .. tostring(rect.id or "hud")
        end
      end
    end
    end
  end
  if visibleActorHulls.player and visibleActorHulls.enemy
      and not actorPairSeparated(shot, visibleActorHulls.player,
                                visibleActorHulls.enemy) then
    return false, "actor-pair-too-close"
  end
  return true, "actor-hulls-clear"
end

if type(BattleCam.setScreenSafetyEvaluator) == "function" then
  BattleCam.setScreenSafetyEvaluator(OverworldBattle.battleHudCameraSafe)
end

-- Optional VASC-owned HUD details are injected through one narrow painter.
-- Keeping the dependency in main.lua avoids making older compatibility
-- fixtures manufacture a second module merely to exercise battle geometry.
function OverworldBattle.setHudExtrasDrawer(drawer)
  hudExtrasDrawer = type(drawer) == "function" and drawer or nil
  return hudExtrasDrawer ~= nil
end

-- Put the map's cast back. Both lists are handed back by identity, so
-- anything that captured one before the battle still sees the same table.
local function restoreCast(expected)
  local active = expected or session
  if not (active and active.state) then return end
  if active.entities then active.state.entities = active.entities end
  if active.ghosts then active.state.ghosts = active.ghosts end
  active.entities, active.ghosts = nil, nil
end

local function finishBattleHudProviders(battle)
  local finishedProviders = {}
  for index = 1, 2 do
    local provider = index == 1 and battleHudProvider
      or defaultBattleHudProvider
    if provider and not finishedProviders[provider]
        and type(provider.finishBattle) == "function" then
      finishedProviders[provider] = true
      local ok, reason = pcall(provider.finishBattle, battle)
      if not ok then warnBattleHudProvider(provider, "finish", reason) end
    end
  end
end

local function clearRendererBattleReceipts(battle)
  if type(battle) ~= "table" then return end
  battle.voxelAscendantShot = nil
  battle.voxelAscendantHudSnapped = nil
  battle[HUD_SNAP_RECEIPT_KEY] = nil
  battle.dramaticShapeShot = nil
  battle.letterboxWhite = nil
  battle._vascNativeCartridgeFrontAnchor = nil
  battle._vascWorldVisualBattler = nil
  battle._vascWorldVisualSpecies = nil
end

-- Optional preset art is renderer content owned by the exact BattleState,
-- not by a deployment. Raw provider finish/abort/fallback paths can bypass
-- OverworldBattle.finish(), so retire the resolver latch at their common
-- exact-owner terminal seam as well.
local function finishPresetArenaBackdrop(active, battle)
  if active and type(active.arena) == "table" then
    active.arena._vascPresetArenaBackdrop = nil
  end
  if battle == nil then return end
  pcall(function()
    local PresetRuntime = V.require("PresetRuntime")
    if type(PresetRuntime.finishArenaBackdrop) == "function" then
      PresetRuntime.finishArenaBackdrop(battle)
    end
  end)
end

-- A legacy staged-asset failure means only "continue this exact encounter in
-- native 2D".  It is not battle.ended: keep the lifecycle/content owner alive
-- so the real engine end event remains the sole music/content cleanup edge.
local function retireRendererSessionToNative(expectedBattle, reason)
  local active = session
  if expectedBattle == nil or active == nil
      or not sameBattle(active.battle, expectedBattle) then
    return false
  end
  legacyFinishRequestedBattle = nil
  if active.rendererOwnerKind == "provider" then
    -- The Lifecycle Router is the sole provider owner. Let its native-latch
    -- transaction abort DISCS and acquire DEFAULT; the DISCS Card performs the
    -- raw cleanup within that exact transaction.
    local latched, latchReason = lifecycle("nativeLatched", expectedBattle,
      reason or "provider-renderer-native-fallback")
    if not latched then return false, latchReason end
    if session ~= nil and sameBattle(session.battle, expectedBattle) then
      return false, "provider fallback retained renderer session"
    end
    return true
  end
  local retired, retireReason = rendererSessionFallback(
    expectedBattle, reason or "legacy-stage-native-fallback")
  if retired == nil then return false, retireReason end
  lifecycle("nativeLatched", expectedBattle,
    reason or "legacy-stage-native-fallback")
  return true
end

-- Cull them. The player stays -- they are not an NPC, they are who the
-- battle belongs to, and Fly/surf animations and the save's own capture read
-- state.player through this list.
--
-- Only the DRAW lists are touched, and only while the overworld is frozen
-- underneath a battle: StateStack updates the top state alone, so nothing
-- walks, wanders, triggers or collides against a list that is short for
-- these frames. The originals go back at battle.ended.
local function cullCast(state)
  session.entities = state.entities
  session.ghosts = state.ghosts
  state.entities = { state.player }
  state.ghosts = {}
end

-- ------- one right battle layout
--
-- Everything this file composes is measured in the GB's own 160x144 frame: the
-- two ANCHORs the arena camera is solved to put a cell under, the HUD_RECTs
-- the frosted panels are cut to, and the full-frame white intercepted to let
-- the world through. BATTLE LAYOUT's WIDE lays the same battle out on a
-- 304x144 surface (src/battle/WideBattle.lua), which moves every one of those
-- -- the mons would stand where no camera was solved for them, and the panels
-- would land beside the HUDs they are supposed to be under.
--
-- So while a fight can be staged on the map there is one right answer, and it
-- is SET rather than worked around. The engine reads the option live
-- (BattleState:isWideBattleLayout is asked per frame, and Renderer asks the
-- top state for its surface the same way), so writing it here lands on the
-- battle being pushed as well as every one after it.
--
-- This is the last line rather than the first: the OPTIONS menu takes the row
-- off the list and pins the value while 3D-BTL is on (see main.lua), so a
-- player is never offered a switch that gets reverted under them. What reaches
-- here is a value that arrived some other way -- a save written before the mod
-- was installed, the mod manager's own page, another mod.
function OverworldBattle.forceOG(g)
  g = g or game()
  local opts = g and g.save and g.save.options
  if not opts or opts.battleLayout ~= "wide" then return false end
  opts.battleLayout = "og"
  if g.writeOptions then pcall(g.writeOptions, g) end
  return true
end

-- Where THIS fight stands, on whichever rung is running: the map's own
-- ground, or the pair of discs a B rung carries with it.
--
-- The one place the two columns actually diverge, and it is worth stating
-- plainly. On an A rung the physical answer can be NO -- a corridor, a shop
-- floor, a map whose authored entry is a refusal -- and the battle then uses
-- a portable Voxel arena. A B rung cannot fail: its stage is not something the
-- map has to have room for, so a fight in the tightest cave in Kanto is staged
-- as readily as one on Route 1.
function OverworldBattle.stageFor(state, plan, bypassPreflight)
  local mode = plan and plan.mode or selectedBattleMode()
  local key = stageRequestKey(state, mode)
  if not bypassPreflight and staged.ready and staged.key == key then
    local arena = staged.arena
    staged = { key=nil, ready=false, arena=nil }
    return arena ~= false and arena or nil
  end
  local arenaSelected = mode == OverworldBattle.ARENA
  local discsSelected = mode == OverworldBattle.FLAT_B
  local portableSelected = arenaSelected or discsSelected
  -- MAP, ARENA and DISCS are user-visible architectures, not suggestions.
  -- Camera style must never exchange one stage for another: SMART/STADIUM
  -- directs the selected stage only. In particular, ARENA always keeps its
  -- reviewed portable scenery instead of silently turning into MAP whenever a
  -- physical patch happens to be available.
  if portableSelected and Voxel3D.available() then
    local okStage, arena = pcall(function()
      local arenaStyle, diskStyle
      if arenaSelected then
        local found = BattleArena.find(state.map, state.player.cellX,
                                       state.player.cellY,
                                       state.player.surfing)
        arenaStyle = latchArenaArt(
          V.require("BattleArenaStyle").resolve(state.map, found))
      else
        -- DISCS are portable and do not need a map-ground search, but their
        -- art still receives the same location family used by ARENA.
        diskStyle = latchDiskArt(
          V.require("BattleArenaStyle").resolve(state.map, nil))
      end
      return V.require("VoxelBattleStage").arena(
        state.map, arenaStyle, diskStyle)
    end)
    if okStage and arena then
      arena.presentationMode = arenaSelected and "ARENA" or "DISCS"
      return arena
    end
    -- A selected architecture is immutable for this battle. If its portable
    -- stage cannot be built, fail closed to the native presentation once;
    -- never disguise a physical MAP stage as ARENA/DISCS or silently change
    -- layouts, sprite policy and camera ownership underneath the player.
    return nil
  end
  local okFind, arena = pcall(BattleArena.find, state.map,
                              state.player.cellX, state.player.cellY,
                              state.player.surfing)
  if okFind and arena then
    arena.presentationMode = "MAP"
    return arena
  end

  -- MAP is still a Voxel mode. Fishing, scripted encounters and narrow edge
  -- tiles can legitimately have no safe physical patch; handing those cases
  -- to the native renderer made the next fight appear to change the user's
  -- saved battle setting. Carry a neutral arena instead, while preserving the
  -- real map as the art/location source. OFF remains the only 2D opt-out.
  if Voxel3D.available() then
    local okFallback, fallback = pcall(function()
      local style = latchArenaArt(
        V.require("BattleArenaStyle").resolve(state.map, nil))
      local staged = V.require("VoxelBattleStage").arena(
        state.map, style, nil)
      if staged then
        staged.mapFallback = true
        staged.presentationMode = "MAP"
      end
      return staged
    end)
    if okFallback and fallback then return fallback end
  end
  return nil
end

local RENDERER_SESSION_SCHEMA =
  "ascendant.gen1-battle-renderer-session/v1"
local RENDERER_OWNER_SCHEMA =
  "ascendant.gen1-battle-renderer-owner/v1"
local RENDERER_PROVIDERS = { MAP=true, ARENA=true, DISCS=true }

local function rendererReason(value, fallback)
  if type(value) == "string" then return value end
  if value == nil then return fallback end
  local ok, text = pcall(tostring, value)
  if ok and type(text) == "string" then return text end
  return fallback or ("<unprintable-%s>"):format(type(value))
end

local function nativeLatchBattleId(active)
  local existing = type(active) == "table"
    and rawget(active, "nativeLatchBattleId") or nil
  if type(existing) == "string" and existing:match("^G1L%-%d+$") then
    return existing
  end
  battleLatchDiagnosticSerial = battleLatchDiagnosticSerial + 1
  local battleId = "G1L-" .. tostring(battleLatchDiagnosticSerial)
  if type(active) == "table" then active.nativeLatchBattleId = battleId end
  return battleId
end

-- Central terminal transition for the five pre-existing per-frame failure
-- decisions below. The first three assignments deliberately retain their old
-- values and meaning; the remaining code still owns Lifecycle fallback. The
-- reporter is best-effort and marked before invocation so a reentrant or
-- failing logger cannot emit twice or perturb battle behavior.
local function markSessionNative(active, phase, reason)
  if type(active) ~= "table" then return nil end
  local reasonText = rendererReason(reason, phase or "battle-renderer-failed")
  active.broken = true
  active.nativeOnly = true
  active.failureReason = reasonText
  if active.nativeLatchReported == true then return reasonText end
  active.nativeLatchReported = true

  local owner = battleLatchDiagnosticsOwner
  if type(owner) == "table" and owner.state == "active"
      and type(owner.report) == "function" then
    local provider = rawget(active, "rendererProvider")
      or (type(rawget(active, "arena")) == "table"
        and rawget(active.arena, "presentationMode")) or "MAP"
    local called, reported = pcall(owner.report, {
      generation=1,
      provider=provider,
      phase=phase,
      status="native_latched",
      reason=reasonText,
      battleId=nativeLatchBattleId(active),
    })
    if called and reported ~= false then
      owner.reports = owner.reports + 1
    else
      owner.failures = owner.failures + 1
    end
  end
  return reasonText
end

-- Private raw-renderer bind point. OverworldBattlePublic never exports this
-- method. A stale Card control may retire only its own lease, never a newer
-- reporter installed by a later module/Card activation.
function OverworldBattle.installBattleLatchDiagnosticsV1(report)
  if type(report) ~= "function" then
    return nil, "battle latch reporter must be a function"
  end
  local current = battleLatchDiagnosticsOwner
  if type(current) == "table" and current.state == "active" then
    return nil, "battle latch diagnostics owner is already active"
  end
  local owner = { state="active", report=report, reports=0, failures=0 }
  battleLatchDiagnosticsOwner = owner
  local control = {}
  function control.retire()
    if owner.state == "retired" then return true end
    owner.state = "retired"
    owner.report = nil
    if rawequal(battleLatchDiagnosticsOwner, owner) then
      battleLatchDiagnosticsOwner = nil
    end
    return true
  end
  function control.health()
    local active = owner.state == "active"
      and rawequal(battleLatchDiagnosticsOwner, owner)
    return {
      schema=BATTLE_LATCH_DIAGNOSTICS_SCHEMA,
      apiVersion=1,
      ok=active,
      state=active and "active" or "retired",
      reports=owner.reports,
      failures=owner.failures,
    }
  end
  return control
end

local function rendererPositiveInteger(value)
  return type(value) == "number" and value >= 1 and value % 1 == 0
end

local function rendererNonNegativeInteger(value)
  return type(value) == "number" and value >= 0 and value % 1 == 0
end

local function normalizeRendererOwner(raw, expectedProvider)
  if type(raw) ~= "table"
      or raw.schema ~= RENDERER_OWNER_SCHEMA
      or raw.apiVersion ~= 1
      or (raw.ownerKind ~= "legacy" and raw.ownerKind ~= "provider")
      or not RENDERER_PROVIDERS[raw.provider]
      or not rendererPositiveInteger(raw.battleToken)
      or not rendererNonNegativeInteger(raw.deploymentToken) then
    return nil, "invalid renderer owner receipt"
  end
  if expectedProvider ~= nil and raw.provider ~= expectedProvider then
    return nil, ("renderer provider mismatch: expected %s, got %s")
      :format(tostring(expectedProvider), tostring(raw.provider))
  end
  if raw.ownerKind == "provider" and raw.provider ~= "DISCS" then
    return nil, "only DISCS may use provider-owned renderer sessions"
  end
  return {
    schema=RENDERER_OWNER_SCHEMA,
    apiVersion=1,
    ownerKind=raw.ownerKind,
    provider=raw.provider,
    battleToken=raw.battleToken,
    deploymentToken=raw.deploymentToken,
  }
end

local function copyRendererOwner(owner, state, sessionToken)
  if type(owner) ~= "table" then return nil end
  return {
    schema=RENDERER_OWNER_SCHEMA,
    apiVersion=1,
    ownerKind=owner.ownerKind,
    provider=owner.provider,
    battleToken=owner.battleToken,
    deploymentToken=owner.deploymentToken,
    state=state,
    sessionToken=sessionToken,
  }
end

local function activeRendererOwner(active)
  if type(active) ~= "table" then return nil end
  return {
    schema=RENDERER_OWNER_SCHEMA,
    apiVersion=1,
    ownerKind=active.rendererOwnerKind,
    provider=active.rendererProvider,
    battleToken=active.rendererBattleToken,
    deploymentToken=active.rendererDeploymentToken,
  }
end

local function equalRendererOwner(left, right)
  return type(left) == "table" and type(right) == "table"
    and left.ownerKind == right.ownerKind
    and left.provider == right.provider
    and left.battleToken == right.battleToken
    and left.deploymentToken == right.deploymentToken
end

local function sameRendererOwner(active, owner)
  return equalRendererOwner(activeRendererOwner(active), owner)
end

local function rendererOwnerForBattle(battle)
  local active = session
  if battle ~= nil and active ~= nil and sameBattle(active.battle, battle) then
    return copyRendererOwner(activeRendererOwner(active), "active",
      active.rendererSessionToken)
  end
  local prepared = rendererPreparation
  if battle ~= nil and prepared ~= nil
      and sameBattle(prepared.battle, battle) then
    return {
      schema=RENDERER_OWNER_SCHEMA,
      apiVersion=1,
      provider=prepared.provider,
      state="prepared",
      sessionToken=prepared.token,
    }
  end
  local terminal = type(battle) == "table"
    and rendererTerminalOwners[battle] or nil
  if terminal ~= nil then
    return copyRendererOwner(terminal, terminal.state, terminal.sessionToken)
  end
  return nil
end

local function recordRendererTerminal(battle, active, state)
  if type(battle) ~= "table" then return end
  local owner = activeRendererOwner(active)
  if not owner then return end
  owner.state = state
  owner.sessionToken = active.rendererSessionToken
  rendererTerminalOwners[battle] = owner
  rendererLastOwner.value = battle
end

-- Once adopt has validated a provider owner, a later preparation failure is
-- still that provider's rollback responsibility. Preserve an already-clean
-- terminal owner so Router._abortActive can compensate instead of stranding
-- the provider graph in rollback_pending.
local function recordFailedRendererAdoption(battle, prepared, owner)
  recordRendererTerminal(battle, {
    rendererOwnerKind=owner.ownerKind,
    rendererProvider=owner.provider,
    rendererBattleToken=owner.battleToken,
    rendererDeploymentToken=owner.deploymentToken,
    rendererSessionToken=prepared.token,
  }, "aborted")
end

local function runRendererSessionMutation(operation, callback)
  if rendererSessionMutation ~= nil then
    return nil, ("renderer session mutation is already in progress: %s; rejected %s")
      :format(rendererSessionMutation, operation)
  end
  rendererSessionMutation = operation
  local values = packValues(pcall(callback))
  rendererSessionMutation = nil
  if values[1] ~= true then
    rendererSessionStats.failures = rendererSessionStats.failures + 1
    return nil, ("renderer session %s threw: %s"):format(
      operation, rendererReason(values[2], "unprintable renderer error"))
  end
  return unpackValues(values, 2, values.n)
end

local function rendererSessionReceipt(state, reason)
  local active = session
  local prepared = rendererPreparation
  local owner = activeRendererOwner(active)
  return {
    schema=RENDERER_SESSION_SCHEMA,
    apiVersion=1,
    generation=1,
    state=state or (active and "active"
      or (prepared and "prepared" or "idle")),
    provider=owner and owner.provider
      or prepared and prepared.provider
      or nil,
    ownerKind=owner and owner.ownerKind or nil,
    battleToken=owner and owner.battleToken or nil,
    deploymentToken=owner and owner.deploymentToken or nil,
    preparationToken=prepared and prepared.token or nil,
    sessionToken=active and active.rendererSessionToken or nil,
    active=active ~= nil,
    prepared=prepared ~= nil,
    reason=rendererReason(reason, nil),
    prepares=rendererSessionStats.prepares,
    adopts=rendererSessionStats.adopts,
    switches=rendererSessionStats.switches,
    finishes=rendererSessionStats.finishes,
    aborts=rendererSessionStats.aborts,
    fallbacks=rendererSessionStats.fallbacks,
    failures=rendererSessionStats.failures,
  }
end

local function rendererSessionPrepareImpl(state, battle, plan, arena)
  if session ~= nil then
    return nil, "renderer session is already active"
  end
  if rendererPreparation ~= nil then
    if sameBattle(rendererPreparation.battle, battle)
        and rendererPreparation.state == state
        and rendererPreparation.plan == plan
        and rendererPreparation.arena == arena then
      return rendererSessionReceipt("prepared")
    end
    return nil, "renderer preparation is already owned"
  end
  if battle == nil then return nil, "battle owner is required" end
  if not (state and state.map and state.player) then
    return nil, "overworld context is required"
  end
  if type(plan) ~= "table" then
    return nil, "presentation plan is required"
  end
  if type(arena) ~= "table" then return nil, "battle stage is required" end
  local provider = arena.presentationMode or "MAP"
  if not RENDERER_PROVIDERS[provider] then
    return nil, "unknown renderer provider " .. tostring(provider)
  end
  rendererSessionSerial = rendererSessionSerial + 1
  if type(battle) == "table" then rendererTerminalOwners[battle] = nil end
  rendererPreparation = {
    token=rendererSessionSerial,
    state=state,
    battle=battle,
    plan=plan,
    arena=arena,
    provider=provider,
  }
  rendererSessionStats.prepares = rendererSessionStats.prepares + 1
  return rendererSessionReceipt("prepared")
end

local function rendererSessionAdoptImpl(battle, rawOwner)
  if session ~= nil then
    local owner = normalizeRendererOwner(rawOwner, session.rendererProvider)
    if battle ~= nil and sameBattle(session.battle, battle)
        and owner ~= nil and sameRendererOwner(session, owner) then
      return rendererSessionReceipt("active")
    end
    return nil, "renderer session is already active"
  end
  local prepared = rendererPreparation
  if prepared == nil then return nil, "renderer preparation is unavailable" end
  if battle == nil or not sameBattle(prepared.battle, battle) then
    return nil, "renderer preparation owner mismatch"
  end
  local owner, ownerReason = normalizeRendererOwner(
    rawOwner, prepared.provider)
  if not owner then return nil, ownerReason end

  local forced, forceReason = pcall(OverworldBattle.forceOG)
  if not forced then
    rendererPreparation = nil
    recordFailedRendererAdoption(battle, prepared, owner)
    rendererSessionStats.failures = rendererSessionStats.failures + 1
    return nil, "battle layout preparation failed: " .. tostring(forceReason)
  end

  session = {
    state=prepared.state,
    arena=prepared.arena,
    battle=prepared.battle,
    shot=nil,
    plan=prepared.plan,
    armed=false,
    token=0,
    presentationCommitted=false,
    rendererSessionToken=prepared.token,
    rendererOwnerKind=owner.ownerKind,
    rendererProvider=owner.provider,
    rendererBattleToken=owner.battleToken,
    rendererDeploymentToken=owner.deploymentToken,
  }
  rendererPreparation = nil
  local active = session
  local adopted, adoptReason = pcall(function()
    cullCast(active.state)
    BattleCam.reset()
  end)
  if not adopted then
    pcall(restoreCast, active)
    if sameBattle(session, active) then session = nil end
    Voxel3D.camera = nil
    recordRendererTerminal(battle, active, "aborted")
    rendererSessionStats.failures = rendererSessionStats.failures + 1
    return nil, "battle session preparation failed: " .. tostring(adoptReason)
  end
  rendererSessionStats.adopts = rendererSessionStats.adopts + 1
  -- Queue the cold arena before the wipe is pushed. The update hook can now
  -- spend its first covered-frame budget on terrain instead of discovering
  -- the work only after that slice has passed.
  pcall(BattleScene.prepare, active.state, active.arena)
  if stadiumModelsEnabled() then
    pcall(function() V.require("Stadium").begin(active.arena) end)
  else
    pcall(function() V.require("Stadium").finish() end)
  end
  return rendererSessionReceipt("active")
end

local function rendererSwitchSide(battle, payload)
  payload = type(payload) == "table" and payload or {}
  if payload.battler ~= nil and type(battle) == "table" then
    if payload.battler == battle.player then return "player" end
    if payload.battler == battle.enemy then return "enemy" end
  end
  local side = payload.side
  if type(side) == "table" then
    local key = rawget(side, "key")
    if key == "player" or key == "enemy" then return key end
    side = rawget(side, "index")
  end
  if side == "player" or side == 1 then return "player" end
  if side == "enemy" or side == 2 then return "enemy" end
end

local function rendererSessionSwitchImpl(battle, payload, rawOwner)
  local active = session
  if active == nil or battle == nil
      or not sameBattle(active.battle, battle) then
    return nil, "renderer session owner mismatch"
  end
  local owner, ownerReason = normalizeRendererOwner(
    rawOwner, active.rendererProvider)
  if not owner then return nil, ownerReason end
  if owner.ownerKind ~= active.rendererOwnerKind
      or owner.battleToken ~= active.rendererBattleToken then
    return nil, "renderer switch owner mismatch"
  end
  if owner.deploymentToken == active.rendererDeploymentToken then
    return rendererSessionReceipt(
      (active.broken or active.nativeOnly) and "native" or "active",
      active.failureReason)
  end
  if owner.deploymentToken ~= active.rendererDeploymentToken + 1 then
    return nil, ("renderer deployment token must advance beyond %d")
      :format(active.rendererDeploymentToken)
  end
  -- A terminally native encounter can still emit the engine's later KO/switch
  -- edge. Validate its exact owner/token shape, then remain an inert native
  -- receipt: reopening pendingSwitch or resetting failure counters cannot make
  -- the dead renderer useful and would leave its private token graph diverged
  -- from the one-way Lifecycle fallback.
  if active.broken or active.nativeOnly then
    return rendererSessionReceipt("native", active.failureReason)
  end
  payload = type(payload) == "table" and payload or {}
  local side = rendererSwitchSide(battle, payload)
  if side == nil then return nil, "renderer switch side is unavailable" end
  active.pendingSwitch = {
    side=side,
    battler=payload.battler,
    previous=payload.previous,
  }
  active.textureFailures = 0
  active.textureFailureReason = nil
  active.textureFailureWarned = false
  active.renderFailures = 0
  active.renderFailureWarned = false
  active.cameraSeatRecoverySeconds = nil
  active.cameraSeatRecoveryUpdates = nil
  active.cameraSeatRecoveryReason = nil
  active.cameraSeatRecoveryReported = nil
  active.actorFreeCover = nil
  active.actorFreeCoverOwner = nil
  active.rendererDeploymentToken = owner.deploymentToken
  rendererSessionStats.switches = rendererSessionStats.switches + 1
  return rendererSessionReceipt("active")
end

local function rendererSessionFinishImpl(expectedBattle, rawOwner,
                                          enforceOwner)
  local active = session
  if active == nil then
    if enforceOwner ~= true then
      return nil, "renderer session is unavailable"
    end
    local terminal = rendererOwnerForBattle(expectedBattle)
    local owner = normalizeRendererOwner(rawOwner,
      terminal and terminal.provider)
    if terminal and terminal.state == "ended"
        and owner and equalRendererOwner(terminal, owner) then
      return terminal, expectedBattle
    end
    return nil, "renderer session is unavailable"
  end
  if expectedBattle ~= nil and active.battle ~= nil
      and not sameBattle(active.battle, expectedBattle) then
    return nil, "renderer session owner mismatch"
  end
  if enforceOwner == true then
    local owner, ownerReason = normalizeRendererOwner(
      rawOwner, active.rendererProvider)
    if not owner or not sameRendererOwner(active, owner) then
      return nil, ownerReason or "renderer finish owner mismatch"
    end
  end
  local battle = active.battle
  finishBattleHudProviders(battle)
  if not sameBattle(session, active) then
    rendererSessionStats.failures = rendererSessionStats.failures + 1
    return nil, "renderer session owner changed during HUD cleanup"
  end
  restoreCast(active)
  finishPresetArenaBackdrop(active, battle)
  pcall(function() V.require("Stadium").finish() end)
  if sameBattle(session, active) then session = nil end
  Voxel3D.camera = nil
  clearRendererBattleReceipts(battle)
  recordRendererTerminal(battle, active, "ended")
  rendererSessionStats.finishes = rendererSessionStats.finishes + 1
  return rendererSessionReceipt("ended"), battle
end

local function rendererSessionAbortImpl(expectedBattle, reason, fallback,
                                         rawOwner, enforceOwner)
  local prepared = rendererPreparation
  local active = session
  local terminal = rendererOwnerForBattle(expectedBattle)
  local owner
  if enforceOwner == true then
    local expectedProvider = active and active.rendererProvider
      or prepared and prepared.provider
      or terminal and terminal.provider
    local ownerReason
    owner, ownerReason = normalizeRendererOwner(rawOwner, expectedProvider)
    if not owner then return nil, ownerReason end
    if active ~= nil and not sameRendererOwner(active, owner) then
      return nil, "renderer abort owner mismatch"
    end
    if active == nil and prepared ~= nil then
      return nil, "prepared renderer has not adopted an owner"
    end
    if active == nil and prepared == nil then
      if terminal and equalRendererOwner(terminal, owner) then
        if fallback == true and terminal.state == "native" then
          return terminal
        end
        if fallback ~= true and (terminal.state == "ended"
            or terminal.state == "aborted"
            or terminal.state == "native") then
          return terminal
        end
      end
      return nil, "renderer session is unavailable"
    end
  elseif active == nil and prepared == nil and terminal ~= nil then
    return terminal
  end
  if expectedBattle ~= nil then
    if active ~= nil and not sameBattle(active.battle, expectedBattle) then
      return nil, "renderer session owner mismatch"
    end
    if active == nil and prepared ~= nil
        and not sameBattle(prepared.battle, expectedBattle) then
      return nil, "renderer preparation owner mismatch"
    end
    if active == nil and prepared == nil
        and not sameBattle(rendererLastOwner.value, expectedBattle) then
      return nil, "renderer session owner mismatch"
    end
  end
  local battle = active and active.battle
    or prepared and prepared.battle
    or expectedBattle
  if active ~= nil then
    restoreCast(active)
    finishPresetArenaBackdrop(active, battle)
    pcall(function() V.require("Stadium").finish() end)
    if sameBattle(session, active) then session = nil end
    Voxel3D.camera = nil
    clearRendererBattleReceipts(battle)
    finishBattleHudProviders(battle)
  end
  if prepared ~= nil
      and (expectedBattle == nil or sameBattle(prepared.battle, expectedBattle)) then
    rendererPreparation = nil
  end
  if active ~= nil then
    recordRendererTerminal(battle, active, fallback and "native" or "aborted")
  elseif type(battle) == "table" then
    rendererLastOwner.value = battle
  end
  if fallback == true then
    rendererSessionStats.fallbacks = rendererSessionStats.fallbacks + 1
  else
    rendererSessionStats.aborts = rendererSessionStats.aborts + 1
  end
  return rendererSessionReceipt(fallback and "native" or "aborted", reason)
end

local function rendererSessionPrepare(state, battle, plan, arena)
  return runRendererSessionMutation("prepare", function()
    return rendererSessionPrepareImpl(state, battle, plan, arena)
  end)
end

local function rendererSessionAdopt(battle, owner)
  return runRendererSessionMutation("adopt", function()
    return rendererSessionAdoptImpl(battle, owner)
  end)
end

local function rendererSessionSwitch(battle, payload, owner)
  return runRendererSessionMutation("switch", function()
    return rendererSessionSwitchImpl(battle, payload, owner)
  end)
end

local function rendererSessionFinish(expectedBattle)
  return runRendererSessionMutation("finish", function()
    return rendererSessionFinishImpl(expectedBattle, nil, false)
  end)
end

rendererSessionAbort = function(expectedBattle, reason, fallback)
  return runRendererSessionMutation(fallback and "fallback" or "abort",
    function()
      return rendererSessionAbortImpl(expectedBattle, reason, fallback)
    end)
end

rendererSessionFallback = function(expectedBattle, reason)
  return rendererSessionAbort(expectedBattle, reason, true)
end

local rendererSessionControl = {
  schema=RENDERER_SESSION_SCHEMA,
  apiVersion=1,
  generation=1,
  prepare=rendererSessionPrepare,
  adopt=rendererSessionAdopt,
  switch=rendererSessionSwitch,
  finish=function(battle, owner)
    return runRendererSessionMutation("finish", function()
      return rendererSessionFinishImpl(battle, owner, true)
    end)
  end,
  abort=function(battle, reason, owner)
    return runRendererSessionMutation("abort", function()
      return rendererSessionAbortImpl(
        battle, reason, false, owner, true)
    end)
  end,
  fallback=function(battle, reason, owner)
    return runRendererSessionMutation("fallback", function()
      return rendererSessionAbortImpl(
        battle, reason, true, owner, true)
    end)
  end,
  owns=function(battle)
    return battle ~= nil and session ~= nil
      and sameBattle(session.battle, battle)
  end,
  health=function()
    return rendererSessionReceipt()
  end,
  owner=rendererOwnerForBattle,
}

-- Private bind point for the owner-scoped renderer Session Card.  The public
-- compatibility facade intentionally omits this name.
function OverworldBattle.rendererSessionControlV1()
  -- Return a disposable facade, never the owner table itself. A consumer may
  -- replace fields on its copy without changing another Card or the renderer.
  local facade = {}
  for key, value in pairs(rendererSessionControl) do facade[key] = value end
  return facade
end

local function legacyRendererOwner(provider, lifecycleReceipt,
                                   preparationReceipt)
  local battleToken = type(lifecycleReceipt) == "table"
    and lifecycleReceipt.battleToken or nil
  if not rendererPositiveInteger(battleToken) then
    battleToken = type(preparationReceipt) == "table"
      and preparationReceipt.preparationToken or nil
  end
  if not rendererPositiveInteger(battleToken) then battleToken = 1 end
  local deploymentToken = type(lifecycleReceipt) == "table"
    and lifecycleReceipt.deploymentToken or 0
  if not rendererNonNegativeInteger(deploymentToken) then
    deploymentToken = 0
  end
  return {
    schema=RENDERER_OWNER_SCHEMA,
    apiVersion=1,
    ownerKind="legacy",
    provider=provider,
    battleToken=battleToken,
    deploymentToken=deploymentToken,
  }
end

local PRESET_BACKGROUND_KINDS = {
  wild=true, trainer=true, rival=true, gym=true, elite4=true,
  champion=true, special=true,
}

local function presetBackgroundContext(state, battle, arena, ownerReceipt)
  if not (type(state) == "table" and type(state.map) == "table"
      and state.map.id ~= nil and type(battle) == "table"
      and type(arena) == "table" and arena.presentationMode == "ARENA"
      and type(ownerReceipt) == "table") then
    return nil
  end
  local okRuntime, PresetRuntime = pcall(V.require, "PresetRuntime")
  local okStage, BattleStage = pcall(V.require, "VoxelBattleStage")
  if not okRuntime or type(PresetRuntime.status) ~= "function"
      or type(PresetRuntime.resolveArenaBackdrop) ~= "function"
      or not okStage or type(BattleStage.hasAuthoredBackdrop) ~= "function" then
    return nil
  end
  local status = PresetRuntime.status()
  if type(status) ~= "table" or status.valid ~= true
      or type(status.generation) ~= "string"
      or type(status.game) ~= "string" then
    return nil
  end
  local ctx = {
    presentationMode="ARENA",
    battleToken=ownerReceipt.battleToken,
    generation=status.generation,
    game=status.game,
    route_or_map=tostring(state.map.id),
    authoredBackdropExists=BattleStage.hasAuthoredBackdrop(arena) == true,
  }
  local kind = type(battle.kind) == "string" and battle.kind:lower() or nil
  if PRESET_BACKGROUND_KINDS[kind] then ctx.battle_kind = kind end
  local trainerId = battle.trainerId
    or (type(battle.trainer) == "table" and battle.trainer.id or nil)
  if type(trainerId) == "string" and trainerId ~= "" then
    ctx.trainer_id = trainerId
  end
  local battleId = battle.battleId or battle.encounterId
  if type(battleId) == "string" and battleId ~= "" then
    ctx.battle_id = battleId
  end
  return PresetRuntime, ctx
end

local function bindPresetArenaBackdrop(state, battle, arena, ownerReceipt)
  local PresetRuntime, ctx = presetBackgroundContext(
    state, battle, arena, ownerReceipt)
  if not PresetRuntime then return end
  local ok, choice = pcall(PresetRuntime.resolveArenaBackdrop, battle, ctx)
  if ok and type(choice) == "table" then
    -- The private field is battle/session-local presentation data.  It never
    -- enters the ARENA registry, the save, or another provider.
    arena._vascPresetArenaBackdrop = choice
  end
end

-- Stage a battle triggered from `state`, if this mode can. Returns true when
-- a session started -- which is also the only case where anything visible
-- changes. MAP first uses the physical encounter patch and then its portable
-- Voxel fallback; only an unavailable renderer or explicit OFF stays native.
function OverworldBattle.begin(state, battle)
  if not runtimeLeaseActive() then return false end
  legacyFinishRequestedBattle = nil
  local legacyAllowed, legacyReason = legacyBattleGuard(
    "begin", state, battle)
  if not legacyAllowed then
    -- The public guard owns no replacement authority.  It may retire only an
    -- already-staged session for this exact BattleState; a different live owner
    -- is left to the engine/Card's normal replacement boundary.
    local reason = "legacy-stage-guard: "
      .. tostring(legacyReason or "declined")
    local exactRetired = retireRendererSessionToNative(battle, reason)
    if not exactRetired and not session then
      local plan = OverworldBattle.capturePresentationPlan()
      claimLifecycle(battle, plan, "DEFAULT", reason,
        "overworld.pushBattle")
    end
    return false
  end
  -- Only a successfully delegated owner entry may exercise the renderer's
  -- ordinary replacement invariant.
  OverworldBattle.finish()
  local plan = OverworldBattle.capturePresentationPlan()
  if type(battle) == "table" then
    -- A per-BattleState latch prevents a settings reload, failed MAP stage or
    -- later fight from adopting this compatibility placement.  STANDARD is
    -- part of the condition: DEFAULT with the ORAS HUD is intentionally not a
    -- native cartridge composition and therefore remains byte-for-byte on the
    -- engine placement.
    battle._vascNativeCartridgeFrontAnchor =
      plan.mode == false and plan.standardHud == true or nil
  end
  if not battleLifecycleReady then return false end
  if not plan.mode then
    claimLifecycle(battle, plan, "DEFAULT", "selected-default",
      "overworld.pushBattle")
    return false
  end
  if not supported then
    claimLifecycle(battle, plan, "DEFAULT", "engine-seam-unavailable",
      "overworld.pushBattle")
    return false
  end
  if not (state and state.map and state.player) then
    claimLifecycle(battle, plan, "DEFAULT", "overworld-context-unavailable",
      "overworld.pushBattle")
    return false
  end
  if not Voxel3D.available() then
    claimLifecycle(battle, plan, "DEFAULT", "voxel-renderer-unavailable",
      "overworld.pushBattle")
    return false
  end

  -- Keep successful stage art hot, but let a later battle retry an upload
  -- that exhausted its bounded first-frame recovery in the previous fight.
  -- Without this per-battle negative-cache boundary only a process restart
  -- could make that ARENA image eligible again.
  local okStage, BattleStage = pcall(V.require, "VoxelBattleStage")
  if okStage and type(BattleStage.retryFailedImages) == "function" then
    BattleStage.retryFailedImages()
  end

  local arena = OverworldBattle.stageFor(state, plan)
  if not arena then
    claimLifecycle(battle, plan, "DEFAULT", "selected-stage-unavailable",
      "overworld.pushBattle")
    return false
  end

  local provider = arena.presentationMode or "MAP"
  local prepared, prepareReason = rendererSessionPrepare(
    state, battle, plan, arena)
  if not prepared then
    claimLifecycle(battle, plan, "DEFAULT",
      "renderer-session-prepare-failed: " .. tostring(prepareReason),
      "overworld.pushBattle")
    return false, prepareReason
  end
  local claimed, claimReason = claimLifecycle(
    battle, plan, provider, nil, "overworld.pushBattle")
  if BattleLifecycle ~= nil and (claimed == nil
      or claimed.provider ~= provider) then
    rendererSessionAbort(battle,
      claimReason or "lifecycle ownership failed", false)
    if V.mod and V.mod.log and type(V.mod.log.warn) == "function" then
      pcall(V.mod.log.warn, V.mod.log,
        "selected %s battle declined: lifecycle ownership failed: %s",
        tostring(provider), tostring(claimReason
          or (claimed and ("provider receipt is "
            .. tostring(claimed.provider))) or "unknown failure"))
    end
    return false
  end

  local activeOwner = rendererOwnerForBattle(battle)
  local adopted, adoptReason
  if activeOwner and activeOwner.state == "active" then
    if activeOwner.provider == provider
        and (type(claimed) ~= "table"
          or (activeOwner.battleToken == claimed.battleToken
            and activeOwner.deploymentToken == claimed.deploymentToken)) then
      adopted = activeOwner
    else
      adoptReason = "renderer provider owner does not match lifecycle claim"
    end
  else
    adopted, adoptReason = rendererSessionAdopt(battle,
      legacyRendererOwner(provider, claimed, prepared))
  end
  if not adopted then
    rendererSessionFallback(battle, adoptReason)
    lifecycle("nativeLatched", battle, adoptReason)
    return false, adoptReason
  end
  bindPresetArenaBackdrop(state, battle, arena, adopted)
  return true
end

function OverworldBattle.setReplacementCleanup(callback)
  replacementCleanup = type(callback) == "function" and callback or nil
end

-- Private bind point used only by adapters/gen1/OverworldBattlePublic.  The
-- public facade does not expose this function.  Rebinding retires the previous
-- proxy first so its KASC callback chain cannot survive a host replacement.
function OverworldBattle.setLegacyCompatibilityBridge(bridge)
  if runtimeState == "retired" or runtimeState == "rejected" then
    return false, "battle wrapper runtime is " .. runtimeState
  end
  if not validLegacyCompatibilityBridge(bridge) then
    return false, "invalid legacy compatibility bridge"
  end
  local previous = legacyCompatibilityBridge
  if previous == bridge then return true end
  legacyCompatibilityBridge = nil
  if validLegacyCompatibilityBridge(previous) then
    pcall(previous.retire, "legacy compatibility bridge replaced")
  end
  legacyCompatibilityBridge = bridge
  return true
end

function OverworldBattle.setNativeBattlePreflight(callback)
  if runtimeState == "retired" or runtimeState == "rejected" then
    nativeBattlePreflight = nil
    return false, "battle wrapper runtime is " .. runtimeState
  end
  nativeBattlePreflight = type(callback) == "function" and callback or nil
  return nativeBattlePreflight ~= nil
end

function OverworldBattle.setRuntimeRetireCallback(callback)
  if runtimeState == "retired" or runtimeState == "rejected" then
    runtimeRetireCallback = nil
    return false, "battle wrapper runtime is " .. runtimeState
  end
  runtimeRetireCallback = type(callback) == "function" and callback or nil
  return runtimeRetireCallback ~= nil
end

function OverworldBattle.setBattleLifecycleReady(ready, reason)
  if ready == true then
    if not runtimeLeaseActive() then
      battleLifecycleReady = false
      battleLifecycleReason = "battle wrapper runtime is " .. runtimeState
      return false, battleLifecycleReason
    end
  end
  battleLifecycleReady = ready == true
  battleLifecycleReason = battleLifecycleReady and nil
    or tostring(reason or "battle lifecycle card unavailable")
  if not battleLifecycleReady and (session or rendererPreparation) then
    -- Normal retirement is preferred because it notifies HUD/content owners.
    -- If that seam itself is the callback which failed, forcibly discard the
    -- private renderer state so the still-installed class wrappers cannot
    -- publish another Voxel frame after the Card has self-aborted.
    if session then pcall(OverworldBattle.finish) end
    if session or rendererPreparation then
      local activeSession = session
      local battle = activeSession and activeSession.battle
        or rendererPreparation and rendererPreparation.battle
      pcall(rendererSessionAbort, battle,
        reason or "battle lifecycle card unavailable", false)
      if activeSession ~= nil and type(replacementCleanup) == "function" then
        pcall(replacementCleanup, battle)
      end
    end
  end
  return battleLifecycleReady
end

function OverworldBattle.battleLifecycleHealth()
  return {
    ready=battleLifecycleReady,
    reason=battleLifecycleReason,
    runtimeState=runtimeState,
    leaseState=runtimeLease and runtimeLease.state or nil,
    runtimeRetireBound=type(runtimeRetireCallback) == "function",
  }
end

function OverworldBattle.ownsBattle(battle)
  return rendererSessionControl.owns(battle)
end

-- The fallback entry point: a battle that arrived without going through the
-- overworld's own pushBattle (a link battle, a script pushing a BattleState
-- directly). Nothing visible depends on the cull for those -- the wipe has
-- already been and gone -- but the arena still has to be picked.
function OverworldBattle.ensure(battle)
  if not battleLifecycleReady then return false, battleLifecycleReason end
  local legacyAllowed, legacyReason =
    legacyBattleGuard("ensure", battle)
  if not legacyAllowed then
    local reason = "legacy-stage-guard: "
      .. tostring(legacyReason or "declined")
    local exactRetired = retireRendererSessionToNative(battle, reason)
    if not exactRetired and not session then
      -- Direct/scripted states can reach ensure without pushBattle/begin.
      -- A deliberate native guard still needs an exact lifecycle owner;
      -- otherwise the missing receipt aborts the router for later battles.
      local current = lifecycle("current")
      if current == nil then
        claimLifecycle(battle, OverworldBattle.capturePresentationPlan(),
          "DEFAULT", reason, "battle.started.ensure")
      end
      lifecycle("nativeLatched", battle, reason)
    end
    return false, legacyReason
  end
  -- A mismatched predecessor is an owner-approved replacement only after the
  -- virtual guard delegates.  A veto can therefore never end that predecessor.
  if session and battle and session.battle
      and not sameBattle(session.battle, battle) then
    OverworldBattle.finish()
  end
  if session then
    -- A direct/scripted battle can arrive without the matching pushBattle
    -- seam. Never attach it to an arbitrary previous session: retire that
    -- owner first and build a fresh stage from the current overworld.
    if battle and session.battle
        and not sameBattle(session.battle, battle) then
      OverworldBattle.finish()
    else
    -- a battle pushed through the overworld reaches begin() before it is
    -- built far enough to draw; battle.started is where it is finished
      if battle and not session.battle then
        session.battle = battle
        claimLifecycle(battle, session.plan,
          session.arena and session.arena.presentationMode or "MAP", nil,
          "battle.started.ensure")
      end
      return
    end
  end
  local g = game()
  local ow = g and g.overworld
  if ow and ow.map then OverworldBattle.begin(ow, battle) end
end

-- The engine owns switch semantics.  This adapter consumes its public event
-- instead of guessing from mutable canvases alone, and resets only the
-- deployment-local retry counters.  Scene, camera, HUD and the selected stage
-- remain owned by the exact same battle session.
function OverworldBattle.battlerSwitched(payload)
  local lifecycleReceipt, lifecycleReason = lifecycle("replacing", payload)
  local battle = type(payload) == "table" and payload.battle or nil
  if not session or battle == nil or not sameBattle(session.battle, battle) then
    if lifecycleReceipt and lifecycleReceipt.provider == "DEFAULT"
        and battle ~= nil then
      local committed, commitReason = lifecycle("committed", battle, {
        provider="DEFAULT",
        entry="native-battler-switched",
      })
      return committed ~= nil, committed or commitReason
    end
    if lifecycleReceipt and battle ~= nil then
      lifecycle("nativeLatched", battle,
        "renderer-session-unavailable-on-switch")
      return false, "renderer session unavailable on switch"
    end
    return false, lifecycleReason or "battle owner mismatch"
  end
  local currentOwner = rendererOwnerForBattle(battle)
  if type(currentOwner) ~= "table" then
    return false, "renderer session owner receipt is unavailable"
  end
  if currentOwner.ownerKind == "provider" then
    -- The critical Lifecycle -> Router -> Provider transaction already owns
    -- and performs the raw DISCS renderer switch.  Never replay it through
    -- this legacy wrapper: a rejected transition could otherwise mutate the
    -- renderer after the Router had failed closed.  Success is accepted only
    -- when the post-transaction renderer owner and lifecycle receipt agree on
    -- the exact provider and authoritative tokens.
    if type(lifecycleReceipt) ~= "table" then
      return false, lifecycleReason
        or "provider lifecycle switch was declined"
    end
    if lifecycleReceipt.provider ~= currentOwner.provider
        or lifecycleReceipt.battleToken ~= currentOwner.battleToken
        or lifecycleReceipt.deploymentToken
          ~= currentOwner.deploymentToken then
      return false, "provider lifecycle switch owner mismatch"
    end
    return true, lifecycleReceipt
  end
  local nextOwner = {
    schema=RENDERER_OWNER_SCHEMA,
    apiVersion=1,
    ownerKind=currentOwner.ownerKind,
    provider=currentOwner.provider,
    battleToken=currentOwner.battleToken,
    deploymentToken=type(lifecycleReceipt) == "table"
      and lifecycleReceipt.deploymentToken
      or currentOwner.deploymentToken + 1,
  }
  local switched, switchReason = rendererSessionSwitch(
    battle, payload, nextOwner)
  return switched ~= nil, switched and lifecycleReceipt or switchReason
end

-- The arena this battle is staged on, or nil. Read by the shot driver so a
-- screenshot can be labelled with the ground it was taken on.
function OverworldBattle.arena()
  return session and session.arena or nil
end

function OverworldBattle.finish(expectedBattle)
  if not session then
    if expectedBattle == nil
        or sameBattle(legacyFinishRequestedBattle, expectedBattle) then
      legacyFinishRequestedBattle = nil
    end
    return
  end
  -- battle.ended carries the exact state that emitted it. A delayed end event
  -- from a fishing/script battle must never tear down a newer staged fight.
  -- Internal watchdog/reset callers deliberately omit the argument and retain
  -- their unconditional cleanup semantics.
  if expectedBattle ~= nil and session.battle ~= nil
      and not sameBattle(session.battle, expectedBattle) then
    return false
  end
  local battle = session.battle
  if sameBattle(legacyFinishRequestedBattle, battle) then
    legacyFinishRequestedBattle = nil
  end
  if session.rendererOwnerKind == "provider" then
    -- Provider-owned sessions are retired by the Router's exact finish edge.
    -- Running raw cleanup first would leave DISCS nominally segmented while
    -- the legacy wrapper still owned its real lifecycle.
    local ended, endReason = lifecycle("finished", battle,
      "provider-renderer-session-finished")
    if not ended then return false, endReason end
    if session ~= nil and sameBattle(session.battle, battle) then
      return false, "provider finish retained renderer session"
    end
  else
    local finished, finishReason = rendererSessionFinish(expectedBattle)
    if not finished then return false, finishReason end
    if battle ~= nil then
      lifecycle("finished", battle, "renderer-session-finished")
    end
  end
  if type(replacementCleanup) == "function" then
    local okCleanup, cleanupReason = pcall(replacementCleanup, battle)
    if not okCleanup and V.mod and V.mod.log
        and type(V.mod.log.warn) == "function" then
      V.mod.log:warn("battle content cleanup failed open: %s",
                     tostring(cleanupReason))
    end
  end
  return true
end

-- The actor receipts belong to the exact completed scene. A side canvas is
-- reused on a switch, so holding that scene through a one-frame render miss
-- is safe only while every published deployment identity still matches.
local function actorMatchesTexture(actor, texture)
  if not (type(actor) == "table"
      and actor.schema == "voxel-ascendant/actor-render/v1") then return false end
  if actor.view == "stadium-model" then
    -- A covered 3D side deliberately has no sprite canvas. Its rig and exact
    -- battler/mon owner are the deployment identity instead.
    return V.require("Stadium").matchesVisualReceipt(actor)
      and (texture == nil or (type(texture) == "table"
        and actor.battler == texture.vascRenderBattler
        and actor.mon == texture.vascRenderMon))
  end
  return type(texture) == "table"
    and actor.battler == texture.vascRenderBattler
    and actor.mon == texture.vascRenderMon
    and actor.modelKey == texture.vascRenderModelKey
    and actor.textureToken == texture.vascRenderTextureToken
    and actor.view == texture.vascSpriteView
end

local function shotMatchesTextures(shot, textures)
  local visuals = shot and shot.actorVisuals
  if type(visuals) ~= "table" or type(textures) ~= "table" then return false end
  local matched = false
  for _, side in ipairs({ "player", "enemy" }) do
    local actor, texture = visuals[side], textures[side]
    if actor == nil and texture ~= nil then return false end
    if actor then
      if not actorMatchesTexture(actor, texture) then return false end
      matched = true
    end
  end
  return matched
end

-- A switch edge is emitted before the replacement card is necessarily
-- visible. During the send-out page the unchanged opponent can therefore be
-- a complete actor while the switched side is intentionally absent. That is
-- a safe deployment cover, not a completed deployment. Validate the complete
-- receipt tuple here so an unrelated stale actor can never earn that status.
-- Returns true for a pending cover, false for a complete/no-switch frame, and
-- nil plus a diagnostic for an unsafe replacement frame.
local function replacementFramePending(active, shot, textures)
  local pending = active and active.pendingSwitch
  if pending == nil then return false end
  local side = pending.side
  if side ~= "player" and side ~= "enemy" then
    return nil, "replacement side is invalid"
  end
  local battle = active.battle
  local battler = type(battle) == "table" and battle[side] or nil
  if type(battler) ~= "table" or pending.battler ~= battler then
    return nil, "replacement battler owner changed"
  end
  if not shotMatchesTextures(shot, textures) then
    return nil, "replacement actor receipt does not match live textures"
  end
  local actor = shot.actorVisuals[side]
  local texture = textures[side]
  if actor == nil then
    if texture ~= nil then
      return nil, "replacement actor receipt is missing"
    end
    -- STANDARD may deliberately leave the player's native rear in its fixed
    -- cartridge slot. In that presentation there will never be a Voxel-side
    -- player receipt, so the exact enemy-only shot is the completed frame.
    if side == "player" and OverworldBattle.playerBackPinned(battle) then
      return false
    end
    return true
  end
  if actor.battler ~= pending.battler
      or actor.mon ~= pending.battler.mon then
    return nil, "replacement actor receipt has the wrong owner"
  end
  return false
end

local function shouldRetainCommittedShot(active, textures)
  if not (active and active.shot) then return false end
  -- Presentation ownership is battle-scoped, but the pixels in a completed
  -- shot are deployment-scoped.  A switch commonly reuses the same side
  -- canvas for the next monster; retaining the old shot merely because this
  -- battle already committed would then present the previous monster under
  -- the new battler/HUD identity.  Hold a transient miss only while the exact
  -- actor receipts still match.  The session remains active and can commit
  -- the replacement on the next successful render without mutating the
  -- player's selected battle mode.
  return shotMatchesTextures(active.shot, textures)
end

-- Camera/HUD ownership has one circular boundary: the camera asks the HUD for
-- its current rectangles, while the HUD can publish those rectangles only on
-- a rendered scene.  If that owner remains pending for more than its single
-- provisional probe, BattleScene declines before touching the scene Canvas.
-- A fully committed shot for the unchanged semantic battlers is therefore a
-- safe continuity frame even when the current animation temporarily omits a
-- texture receipt.  A real switch is rejected explicitly by pendingSwitch and
-- by the battler/Mon tuple below, so old Pokemon pixels cannot cross a
-- deployment boundary.
local function committedShotMatchesBattle(active)
  if not (active and active.presentationCommitted == true
      and active.pendingSwitch == nil and type(active.shot) == "table"
      and type(active.shot.actorVisuals) == "table"
      and type(active.battle) == "table") then return false end
  local matched = false
  for _, side in ipairs({ "player", "enemy" }) do
    local actor = active.shot.actorVisuals[side]
    if actor then
      local battler = active.battle[side]
      if type(battler) ~= "table" or actor.battler ~= battler
          or actor.mon ~= battler.mon then return false end
      matched = true
    end
  end
  return matched
end

local MAX_TRANSIENT_SCENE_FAILURES = 3
local MAX_COLD_SCENE_MISSES = 12
-- Camera/HUD ownership recovery is governed by real presentation time, not by
-- the number of engine updates which happen to fit in it.  Fast-forward and a
-- stalled renderer can run three logical updates before BattleCam's 120 ms
-- safety probe has found and published its replacement seat.  Retaining the
-- already committed same-battler transaction is safe for this bounded window:
-- committedShotMatchesBattle rejects every deployment/switch boundary first.
local MOBILE_ARENA_PREFETCH_PENDING = "arena-prefetch-pending"
local MAX_MOBILE_ARENA_PREFETCH_WAIT_SECONDS = 3
local MAX_MOBILE_ARENA_PREFETCH_WAIT_UPDATES = 360

-- A newly sent-out Pokemon can become logically visible one fixed step before
-- its provider/front-art path is ready.  Texture capture used to let that
-- single deployment-boundary error escape through update(), which retired the
-- complete MAP/ARENA/DISCS session and exposed native 2D for the rest of the
-- encounter.  Give the exact selected architecture the same bounded cold
-- build window as a nil scene: it publishes an actor-free world cover while
-- the private sprite resolver retries, then fails closed only if the resolver
-- remains broken.  This is deliberately narrower than general update errors;
-- camera, mesh, scene and HUD failures retain their existing classifications.
local function retryAfterTextureFailure(active, reason)
  active.textureFailures = (tonumber(active.textureFailures) or 0) + 1
  active.textureFailureReason = tostring(reason)
  return active.textureFailures < MAX_COLD_SCENE_MISSES
end

local function retryablePlayerFrontFailure(reason)
  reason = tostring(reason or "")
  -- Everything below this private resolver prefix is deployment readiness.
  -- The first send-out may expose player.sprite one fixed step before mon,
  -- data or an optional provider front is available. The bounded retry below
  -- still prevents an unrelated permanent resolver fault from being hidden.
  return reason:find("Gen-1 ORAS/MAP player-front ", 1, true) == 1
end

-- Retained as the small exact-actor budget primitive used by focused
-- ownership contracts. The frame driver grants a budget only to cooperative
-- nil declines below; thrown scene failures fail this battle closed.
local function retainAfterRenderFailure(active, textures)
  if not shouldRetainCommittedShot(active, textures) then return false end
  active.renderFailures = (tonumber(active.renderFailures) or 0) + 1
  return active.renderFailures < MAX_TRANSIENT_SCENE_FAILURES
end

-- `render() -> nil` is a deliberate cooperative decline, but it is not a
-- licence to keep an old frame (or a half-entered battle mode) forever.  An
-- exact deployment gets the short last-good budget; a cold/replacement scene
-- gets a slightly wider mesh-build budget.  Once exhausted this battle stays
-- native instead of oscillating back into Voxel later.
local function retryAfterNilFrame(active, textures, declineReason, dt)
  -- These are the complete definitive-false outcomes produced by
  -- battleHudCameraSafe. Every other camera reason is pending, unavailable,
  -- malformed or an owner mismatch and retains the ordinary fail-closed path.
  -- Keeping the classification exact avoids treating an arbitrary
  -- `camera-unavailable:*` renderer fault as a recoverable seat collision.
  local cameraReason = type(declineReason) == "string"
    and declineReason:match("^camera%-unavailable:(.+)$") or nil
  local cameraSeatHold = cameraReason ~= nil
    and (cameraReason == "owner-render-unsafe"
      or cameraReason == "status-card-overlap"
      or cameraReason == "actor-pair-too-close"
      or cameraReason:match("^.+%-outside%-safe%-frame$") ~= nil
      or cameraReason:match("^player%-under%-.+$") ~= nil
      or cameraReason:match("^enemy%-under%-.+$") ~= nil)
    and committedShotMatchesBattle(active)
  local retain = shouldRetainCommittedShot(active, textures)
    or cameraSeatHold
  local ownerPendingHold = declineReason
      == "camera-unavailable:pending-exhausted:owner-render-pending"
    and committedShotMatchesBattle(active)
  -- A definitive actor/HUD collision invalidates the current moving camera,
  -- and BattleCam drops that path so the following update can solve a static
  -- seat.  The scene has not touched its shared Canvas at this point.  Keep
  -- the exact same-battler committed transaction for only the ordinary short
  -- retry budget, even if this animation step omits one texture receipt.
  -- `committedShotMatchesBattle` rejects every switch/deployment boundary, so
  -- this can freeze a safe prior picture briefly but can never show an old
  -- Pokemon under a new battle owner.
  active.renderFailures = (tonumber(active.renderFailures) or 0) + 1
  if cameraSeatHold or ownerPendingHold then
    -- BattleCam invalidates the unsafe route and solves its replacement on
    -- subsequent real-time updates. Do not make that public 120 ms probe race
    -- a three-update fallback budget: hold only the exact committed battlers,
    -- then still fail this encounter closed at the hard bound.
    local delta = tonumber(dt)
    if delta == nil or delta ~= delta or delta <= 0 then
      delta = 1 / 60
    else
      -- One debugger/host stall must not spend the complete continuity window.
      delta = math.min(delta, 0.25)
    end
    active.cameraSeatRecoverySeconds =
      (tonumber(active.cameraSeatRecoverySeconds) or 0) + delta
    active.cameraSeatRecoveryUpdates =
      (tonumber(active.cameraSeatRecoveryUpdates) or 0) + 1
    active.cameraSeatRecoveryReason = cameraReason
      or active.cameraSeatRecoveryReason or "camera-seat-unsafe"
    if not active.cameraSeatRecoveryReported then
      active.cameraSeatRecoveryReported = true
      Diagnostics.write("battle-camera-seat-wait", {
        mode=active.arena and active.arena.presentationMode,
        timeoutMs=2000,
        reason=active.cameraSeatRecoveryReason,
      })
    end
    local waiting = active.cameraSeatRecoverySeconds < 2
      and active.cameraSeatRecoveryUpdates < 240
    if not waiting then
      Diagnostics.write("battle-camera-seat-timeout", {
        mode=active.arena and active.arena.presentationMode,
        elapsedMs=math.floor(active.cameraSeatRecoverySeconds * 1000 + 0.5),
        updates=active.cameraSeatRecoveryUpdates,
        reason=active.cameraSeatRecoveryReason,
      })
      active.cameraSeatRecoverySeconds = nil
      active.cameraSeatRecoveryUpdates = nil
      active.cameraSeatRecoveryReason = nil
      active.cameraSeatRecoveryReported = nil
    end
    return waiting, waiting, waiting and ownerPendingHold, waiting and cameraSeatHold
  end
  active.cameraSeatRecoverySeconds = nil
  active.cameraSeatRecoveryUpdates = nil
  active.cameraSeatRecoveryReason = nil
  active.cameraSeatRecoveryReported = nil
  local limit = retain and MAX_TRANSIENT_SCENE_FAILURES
    or MAX_COLD_SCENE_MISSES
  return active.renderFailures < limit, retain
end

-- A mobile MAP battle can reach its first visible BattleState one update
-- before the asynchronously staged arena has published a complete scene.
-- `arena-prefetch-pending` is an explicit cooperative readiness receipt, not
-- a renderer failure.  Keep advancing the exact selected arena for a bounded
-- amount of real update time instead of immediately trying the actor-free
-- render (which necessarily has the same pending arena and used to latch the
-- whole encounter to native 2D in that very update).
--
-- Desktop keeps the existing atomic fallback contract.  The update cap is a
-- second hard bound for malformed hosts which repeatedly report zero/tiny dt;
-- ordinary 30/60/120 Hz devices are governed by the time limit.
local function finishMobileArenaPrefetchWait(active, outcome)
  if not active or active.mobileArenaPrefetchWaitUpdates == nil then
    return false
  end
  local elapsed = tonumber(active.mobileArenaPrefetchWaitSeconds) or 0
  local updates = tonumber(active.mobileArenaPrefetchWaitUpdates) or 0
  if outcome == "recovered" then
    Diagnostics.write("battle-arena-prefetch-recovered", {
      mode=active.arena and active.arena.presentationMode,
      elapsedMs=math.floor(elapsed * 1000 + 0.5),
      updates=updates,
    })
  end
  active.mobileArenaPrefetchWaitSeconds = nil
  active.mobileArenaPrefetchWaitUpdates = nil
  active.mobileArenaPrefetchWaitReported = nil
  return true
end

local function waitForMobileArenaPrefetch(active, dt, declineReason)
  local mobile = PLATFORM_OS == "iOS" or PLATFORM_OS == "Android"
  if not mobile or declineReason ~= MOBILE_ARENA_PREFETCH_PENDING
      or not active or active.presentationCommitted == true then
    -- A different explicit decline owns the next fallback decision. Do not
    -- let elapsed time from an earlier prefetch episode leak into it.
    finishMobileArenaPrefetchWait(active, "superseded")
    return false
  end

  local delta = tonumber(dt)
  if delta == nil or delta ~= delta or delta <= 0 then
    delta = 1 / 60
  else
    -- One host/suspend spike must not consume the complete recovery window.
    delta = math.min(delta, 0.25)
  end
  active.mobileArenaPrefetchWaitSeconds =
    (tonumber(active.mobileArenaPrefetchWaitSeconds) or 0) + delta
  active.mobileArenaPrefetchWaitUpdates =
    (tonumber(active.mobileArenaPrefetchWaitUpdates) or 0) + 1
  active.renderFailures = 0

  if not active.mobileArenaPrefetchWaitReported then
    active.mobileArenaPrefetchWaitReported = true
    Diagnostics.write("battle-arena-prefetch-wait", {
      mode=active.arena and active.arena.presentationMode,
      timeoutMs=MAX_MOBILE_ARENA_PREFETCH_WAIT_SECONDS * 1000,
      reason=MOBILE_ARENA_PREFETCH_PENDING,
    })
  end

  if active.mobileArenaPrefetchWaitSeconds
        >= MAX_MOBILE_ARENA_PREFETCH_WAIT_SECONDS
      or active.mobileArenaPrefetchWaitUpdates
        >= MAX_MOBILE_ARENA_PREFETCH_WAIT_UPDATES then
    Diagnostics.write("battle-arena-prefetch-timeout", {
      mode=active.arena and active.arena.presentationMode,
      elapsedMs=math.floor(active.mobileArenaPrefetchWaitSeconds * 1000
        + 0.5),
      updates=active.mobileArenaPrefetchWaitUpdates,
      reason=MOBILE_ARENA_PREFETCH_PENDING,
    })
    finishMobileArenaPrefetchWait(active, "timeout")
    return false
  end

  -- The frame driver already pumped the mesher immediately before render().
  -- Keep prepare() queuing the exact missing stage for the following update;
  -- a second covered pump here would spend two 6 ms slices in one visible
  -- mobile frame and turn recovery itself into a hitch.
  pcall(BattleScene.prepare, active.state, active.arena)
  return true
end

-- A deployment may retain only a cover that was committed for that exact
-- pending actor boundary. The cover is normally actor-free, but a successful
-- send-out frame may already contain the unchanged opponent. Preserve that
-- useful actor only while its exact battler/mon/texture receipt is current and
-- the replacement side remains absent from the cached pixels.
local function pendingCoverActorsMatch(active, cover, textures)
  local visuals = cover and cover.actorVisuals
  if type(visuals) ~= "table" then return false end
  if next(visuals) == nil then return true end
  local pending = active and active.pendingSwitch
  local side = pending and pending.side
  if side ~= "player" and side ~= "enemy" then return false end
  if visuals[side] ~= nil then return false end
  local battle = active.battle
  for _, other in ipairs({ "player", "enemy" }) do
    local actor = visuals[other]
    if actor then
      if other == side then return false end
      local battler = type(battle) == "table" and battle[other] or nil
      if type(battler) ~= "table"
          or actor.schema ~= "voxel-ascendant/actor-render/v1"
          or actor.battler ~= battler
          or actor.mon ~= battler.mon then
        return false
      end
      if type(textures) == "table"
          and not actorMatchesTexture(actor, textures[other]) then
        return false
      end
    end
  end
  return true
end

local function holdCommittedPresentation(active, reason, textures)
  local cover = active and active.actorFreeCover
  local owner = active and active.actorFreeCoverOwner
  local battle = active and active.battle
  if not (cover and cover.canvas and cover.pendingActors == true
      and type(cover.actorVisuals) == "table"
      and pendingCoverActorsMatch(active, cover, textures)
      and type(battle) == "table"
      and owner and owner.battle == battle
      and owner.player == battle.player
      and owner.playerMon == (battle.player and battle.player.mon)
      and owner.enemy == battle.enemy
      and owner.enemyMon == (battle.enemy and battle.enemy.mon)
      and owner.deploymentToken == active.rendererDeploymentToken
      and owner.pendingSwitch == active.pendingSwitch) then
    return false
  end
  active.shot = cover
  if not active.diagnosticPresentationHold then
    active.diagnosticPresentationHold = true
    Diagnostics.write("battle-frame-held", {
      mode=active.arena and active.arena.presentationMode,
      reason=reason or "replacement-pending",
      failures=active.renderFailures,
      grow=active.battle and active.battle.growIn ~= nil,
    })
  end
  return true
end

-- Publish either a complete actor shot or a pending replacement cover through
-- the exact same world/HUD transaction. A cover is a real render of the chosen
-- MAP/ARENA/DISCS architecture (terrain, camera, weather, shadows, AA). It may
-- contain exact unchanged-side actors, but never the old switched-side actor,
-- so it cannot expose stale deployment pixels or native 2D pics.
local function commitShot(active, shot, pendingActors)
  if not (active and shot and shot.canvas) then return false end
  -- A renderer may recycle its shot table across frames. Never let the prior
  -- orientation survive into a newly pending/failed HUD transaction.
  shot.battleHudPresentation = nil
  -- A lifecycle commit belongs to a deployment, not to every rendered frame.
  -- The initial complete presentation and the first complete frame after an
  -- exact battler switch each close one boundary.  Ordinary subsequent frames
  -- only replace pixels inside that already-committed owner.
  local deploymentCommitNeeded = active.presentationCommitted ~= true
    or active.pendingSwitch ~= nil
  shot.pendingActors = pendingActors and true or nil
  if pendingActors then
    shot.actorVisuals = type(shot.actorVisuals) == "table"
      and shot.actorVisuals or {}
  else
    if active.cameraSeatRecoveryUpdates ~= nil then
      Diagnostics.write("battle-camera-seat-recovered", {
        elapsedMs=math.floor(
          (tonumber(active.cameraSeatRecoverySeconds) or 0) * 1000 + 0.5),
        updates=active.cameraSeatRecoveryUpdates,
        reason=active.cameraSeatRecoveryReason,
      })
    end
    active.cameraSeatRecoverySeconds = nil
    active.cameraSeatRecoveryUpdates = nil
    active.cameraSeatRecoveryReason = nil
    active.cameraSeatRecoveryReported = nil
    active.renderFailures = 0
    active.renderFailureWarned = false
    active.diagnosticPresentationHold = false
    -- A fully committed frame closes a temporary owner/camera hold. Allow a
    -- later, distinct hold episode to emit its own single diagnostic.
    active.diagnosticOwnerPendingHold = false
    active.presentationCommitted = true
    active.pendingSwitch = nil
  end
  active.snapped = false
  local providerNative = false
  -- The depth of field is measured off the two arena marks. Pending covers
  -- retain those same projected marks, so the background cannot jump while a
  -- replacement card is pending.
  local y1 = shot.ly + shot.player[2] * shot.scale
  local y2 = shot.ly + shot.enemy[2] * shot.scale
  local focusY, band, range = BattleDOF.bandFor(y1, y2, shot.ph)
  local okDof, blurred = pcall(BattleDOF.apply, shot.canvas,
                               focusY, band, range)
  if okDof and blurred then shot.canvas = blurred end
  pcall(BattleHud.build, shot.canvas)
  active.shot = shot
  markSnapped(active.battle, shot, false,
              pendingActors and "actor-replacement-pending" or "frame-pending")
  local providerDrew, providerOwner = false, nil
  if type(drawBattleHudProvider) == "function" then
    providerDrew, providerOwner, providerNative =
      drawBattleHudProvider(active.battle, shot)
  end
  if providerDrew then
    active.snapped = true
    markSnapped(active.battle, shot, true, nil, providerOwner)
    acknowledgeHudSnapshot(active.battle, shot)
  elseif providerNative then
    markSnapped(active.battle, shot, false,
                "exclusive-provider-native", providerOwner)
  else
    local snapAvailable = PLATFORM_OS == "iOS"
      and type(snapHUDs) == "function"
      or type(OverworldBattle.snapHUDs) == "function"
    if BattleHud.position(PLATFORM_OS, shot.pw, shot.ph) ~= "frame"
        and snapAvailable then
      local snappedOK, didSnap
      if PLATFORM_OS == "iOS" then
        snappedOK, didSnap = pcall(snapHUDs, active.battle, shot)
      else
        snappedOK, didSnap = pcall(
          legacyPresentation, "snapHUDs", active.battle, shot)
      end
      active.snapped = snappedOK and didSnap == true
      markSnapped(active.battle, shot, active.snapped,
        snappedOK and (active.snapped and nil or "snap-declined")
          or tostring(didSnap),
        active.snapped and "voxel_ascendant.legacy" or nil)
    end
  end
  if not active.snapped and not providerNative then
    markSnapped(active.battle, shot, false,
      pendingActors and "actor-replacement-layout-fallback"
        or "frame-layout-fallback")
  end
  active.shot = shot
  local cameraState = type(BattleCam.directorState) == "function"
    and BattleCam.directorState() or nil
  if cameraState and not cameraState.screenFallback then
    if active.diagnosticCameraStartYaw == nil then
      active.diagnosticCameraStartYaw = tonumber(cameraState.yaw) or 0
      active.diagnosticCameraStartLift = tonumber(cameraState.lift) or 0
      active.diagnosticCameraStartShot = cameraState.shot
    elseif not active.diagnosticCameraMoved then
      local yawDelta = math.abs((tonumber(cameraState.yaw) or 0)
        - active.diagnosticCameraStartYaw)
      local liftDelta = math.abs((tonumber(cameraState.lift) or 0)
        - active.diagnosticCameraStartLift)
      local shotChanged = cameraState.shot ~= active.diagnosticCameraStartShot
      if yawDelta >= math.rad(2) or liftDelta >= math.rad(1)
          or shotChanged then
        active.diagnosticCameraMoved = true
        Diagnostics.write("battle-camera-smart-motion", {
          mode=active.arena and active.arena.presentationMode,
          shot=cameraState.shot,
          yawDelta=math.deg(yawDelta), liftDelta=math.deg(liftDelta),
          path=cameraState.pathLatched,
        })
      end
    end
  end
  if cameraState and cameraState.screenFallback then
    if not active.diagnosticCameraFallback then
      active.diagnosticCameraFallback = true
      Diagnostics.write("battle-camera-static-fallback", {
        mode=active.arena and active.arena.presentationMode,
        reason=cameraState.screenReason,
        grow=active.battle and active.battle.growIn ~= nil,
      })
    end
  else
    if active.diagnosticCameraFallback then
      Diagnostics.write("battle-camera-smart-resumed", {
        mode=active.arena and active.arena.presentationMode,
        reason=cameraState and cameraState.screenReason,
        shot=cameraState and cameraState.shot,
      })
    end
    active.diagnosticCameraFallback = false
  end
  if shot.smartArenaComposition and not active.diagnosticArenaComposition then
    active.diagnosticArenaComposition = true
    Diagnostics.write("battle-arena-smart-composition", {
      mode=active.arena and active.arena.presentationMode,
      source=shot.smartArenaComposition,
      map=active.arena and active.arena.map and active.arena.map.id,
    })
  end
  if not pendingActors and not active.diagnosticCommitted then
    active.diagnosticCommitted = true
    Diagnostics.write("battle-frame-committed", {
      mode=active.arena and active.arena.presentationMode,
      player=active.battle and active.battle.player
        and active.battle.player.mon and active.battle.player.mon.species,
      grow=active.battle and active.battle.growIn ~= nil,
      discs=active.arena and active.arena.discs == true,
    })
  elseif pendingActors and not active.diagnosticPendingActors then
    active.diagnosticPendingActors = true
    Diagnostics.write("battle-frame-cover", {
      mode=active.arena and active.arena.presentationMode,
      reason="actors-pending",
    })
  end
  -- Cache only after the complete world/HUD transaction succeeded. A later
  -- miss in this same deployment may hold these safe pending pixels, while a
  -- complete actor commit or the next lifecycle switch invalidates them.
  if pendingActors then
    active.actorFreeCover = shot
    local battle = active.battle
    active.actorFreeCoverOwner = battle and {
      battle=battle,
      player=battle.player,
      playerMon=battle.player and battle.player.mon,
      enemy=battle.enemy,
      enemyMon=battle.enemy and battle.enemy.mon,
      deploymentToken=active.rendererDeploymentToken,
      pendingSwitch=active.pendingSwitch,
    } or nil
  else
    active.actorFreeCover = nil
    active.actorFreeCoverOwner = nil
  end
  if not pendingActors and deploymentCommitNeeded
      and active.battle ~= nil then
    lifecycle("committed", active.battle, {
      provider=active.arena and active.arena.presentationMode or "MAP",
      presentationCommitted=true,
      entry="battle-scene-frame",
    })
  end
  finishMobileArenaPrefetchWait(active, "recovered")
  return true
end

local BACKDROP_SELECTION_CHANGED = "backdrop-selection-changed"

-- Voxel3D's battle slot is intentionally reused. A late custom-backdrop draw
-- decline has therefore already touched the canvas behind the last published
-- shot even though BattleScene correctly returned nil. Drop every alias to
-- that canvas and rerun the complete scene after Stage selected its fallback;
-- no draw can observe the discarded A frame between these synchronous calls.
local function retryChangedBackdrop(active, textures)
  if BattleScene.lastDeclineReason ~= BACKDROP_SELECTION_CHANGED then
    return nil, false
  end
  active.shot = nil
  active.actorFreeCover = nil
  active.actorFreeCoverOwner = nil
  active.snapped = false
  markSnapped(active.battle, nil, false, BACKDROP_SELECTION_CHANGED)
  active.token = (active.token or 0) + 1
  Diagnostics.write("battle-backdrop-frame-retry", {
    mode=active.arena and active.arena.presentationMode,
    token=active.token,
  })
  local ok, shot = pcall(BattleScene.render,
    active.state, active.arena, textures, active.token)
  if not ok then error(shot, 0) end
  return shot, true
end

-- Every successful scene render, including the synchronous backdrop retry,
-- crosses the same deployment boundary. Keeping this decision in one place
-- prevents an alternate render path from treating a send-out cover as the
-- first complete frame of the replacement.
local function publishRenderedShot(active, shot, textures)
  local pendingActors, pendingReason = replacementFramePending(
    active, shot, textures)
  if pendingActors == nil then
    Diagnostics.write("battle-replacement-frame-rejected", {
      mode=active.arena and active.arena.presentationMode,
      reason=pendingReason,
      side=active.pendingSwitch and active.pendingSwitch.side,
    })
    local retry = retryAfterNilFrame(active, textures)
    if not retry then
      error("unsafe replacement battle frame: " .. tostring(pendingReason), 0)
    end
    local okCover, cover = pcall(BattleScene.render,
      active.state, active.arena, nil, active.token)
    if not okCover then error(cover, 0) end
    if commitShot(active, cover, true) then return true end
    if holdCommittedPresentation(active,
        "replacement-frame-rejected", textures) then
      return true
    end
    error("safe replacement battle cover unavailable: "
      .. tostring(pendingReason), 0)
  end
  return commitShot(active, shot, pendingActors)
end

-- ------- per-frame
--
-- Driven from the voxel pipeline's update hook, which the engine ticks every
-- frame regardless of which state is on top -- including the frames the
-- transition wipe covers, which is what gets the arena's meshes built before
-- the first battle frame needs them.
--
-- The scene is rendered HERE rather than inside the battle's draw, because
-- update runs with no canvas bound: a 3D pass that binds a depth target and
-- unbinds to the screen when it is done cannot do that in the middle of
-- someone else's frame without putting the frame back itself.
local function retireMissingBattleState()
  if not session then return false end
  local g = game()
  local top = g and g.stack and g.stack:top()
  local ow = g and g.overworld
  -- A battle that ended without saying so (a script tearing the state down,
  -- a path that never emits battle.ended) would otherwise leave the cast
  -- culled for good. Armed only once something has actually covered the
  -- overworld, because begin() runs while the overworld is still on top.
  if top ~= nil and top ~= ow then
    session.armed = true
  elseif session.armed then
    OverworldBattle.finish()
    return true, top, ow
  end
  return false, top, ow
end

local function updateBattleFrame(dt)
  if not session then return end
  local retired, top, ow = retireMissingBattleState()
  if retired then return end

  -- The battle only exists once it has been pushed; a session opened at
  -- pushBattle time has it, one opened from battle.started was handed it
  session.battle = session.battle or (top ~= ow and top or nil)
  -- `begin()` runs before the engine pushes its transition.  A cold MAP can
  -- therefore need a few covered frames before its atomic terrain/horizon
  -- plan exists.  Rendering on the very first pre-transition update used to
  -- see that legitimate cold miss, conclude that even an actor-free cover was
  -- unavailable, and latch the whole encounter to native 2D before the wipe
  -- had even started.  Use the engine transition as the build curtain it is:
  -- keep pumping the exact selected arena until the real BattleState owns the
  -- stack.  No Voxel frame has been published here, so this cannot retain
  -- stale actors or create a visible native-to-Voxel mode switch.  Once the
  -- BattleState is visible, the existing bounded/atomic fallback rules remain
  -- unchanged and still fail closed if the scene genuinely is unavailable.
  if session.battle ~= nil and not sameBattle(top, session.battle)
      and session.presentationCommitted ~= true then
    pcall(BattleScene.prepare, session.state, session.arena)
    ChunkMesher.pump(true)
    return
  end
  BattleCam.steerable = not OverworldBattle.playerBackPinned(session.battle)
  pcall(V.require("CamControl").tick, dt)
  local host = session.arena.map or session.state.map
  local groundY = BattleScene.groundY(host, session.arena)
  local wantsStadium = stadiumModelsEnabled()
  local okActors, actorErr = pcall(function()
    if wantsStadium then
      local stadium = V.require("Stadium")
      if not stadium.active() then stadium.begin(session.arena) end
      stadium.update(dt, session.battle, groundY)
    else
      local okStadium, stadium = pcall(V.require, "Stadium")
      if okStadium and type(stadium) == "table"
          and type(stadium.finish) == "function" then
        stadium.finish()
      end
    end
  end)
  if wantsStadium and not okActors then error(actorErr, 0) end
  -- Resolve the exact current battler/model textures before camera safety.
  -- Switches reuse side canvases, so inspecting yesterday's texture could
  -- approve a shot for Pikachu while Charizard is already the live battler.
  -- The same immutable table is then used by both candidate projection and
  -- the real scene render below.
  OverworldBattle.advanceWorldPlayerSprite(session.battle, dt)
  local okTex, textures = pcall(OverworldBattle.textures, session.battle)
  local legacyFinish = legacyFinishRequestedBattle
  legacyFinishRequestedBattle = nil
  if legacyFinish ~= nil then
    -- This is a renderer fallback, not battle.ended.  Retire only the exact
    -- staged session; lifecycle/content/music remain live until the real engine
    -- end event arrives.  An unrelated request is inert.
    pcall(retireRendererSessionToNative, legacyFinish,
      "legacy-side-texture-native-fallback")
    return
  end
  if not okTex then
    local reason = tostring(textures)
    Diagnostics.write("battle-texture-error", {
      mode=session.arena and session.arena.presentationMode,
      reason=reason,
      grow=session.battle and session.battle.growIn ~= nil,
      sending=session.battle and session.battle.sendingOut,
    })
    -- Only the render-only player-front provider has the known one-step
    -- deployment seam. Enemy capture, Canvas/graphics restoration and every
    -- other texture error remain fatal to this exact encounter as before;
    -- masking those as an empty actor cover would hide a real renderer fault.
    if not retryablePlayerFrontFailure(reason) then
      error(reason, 0)
    end
    if not retryAfterTextureFailure(session, reason) then
      session.shot = nil
      session.actorFreeCover = nil
      session.actorFreeCoverOwner = nil
      session.textures = nil
      session.snapped = false
      session.presentationCommitted = false
      markSnapped(session.battle, nil, false, "texture-resolution-timeout")
      markSessionNative(session, "texture-resolution-timeout", reason)
      lifecycle("nativeLatched", session.battle,
        "texture-resolution-timeout: " .. reason)
      V.mod.log:warn("overworld battle textures remained unavailable: %s "
        .. "-- this exact battle stays native", reason)
      return
    end
    if not session.textureFailureWarned then
      session.textureFailureWarned = true
      V.mod.log:warn("overworld battle texture deployment is not ready: %s "
        .. "-- holding the selected battle architecture while it retries",
        reason)
    end
    -- Never retain the preceding Pokemon's pixels across this error.  The nil
    -- texture path below renders the same arena without actors until the exact
    -- replacement/front source has completed successfully.
    textures = nil
  else
    session.textureFailures = 0
    session.textureFailureReason = nil
    session.textureFailureWarned = false
  end
  session.textures = textures
  if type(BattleCam.setPresentationFit) == "function" then
    BattleCam.setPresentationFit(
      BattleScene.presentationFitDistance(session.arena, textures, host))
  end
  BattleCam.update(dt, session.arena, session.battle, groundY)
  -- the world pass is hidden behind the battle, so mesh builds get the wide
  -- slice: nothing visible can hitch on them
  ChunkMesher.pump(true)

  -- The mons' textures are rendered HERE, with no canvas bound, for the same
  -- reason the scene is: the pics layer binds its own targets, and doing that
  -- inside somebody else's frame means putting the frame back afterwards.
  session.token = (session.token or 0) + 1
  if textures == nil then
    local okCover, cover = pcall(BattleScene.render,
      session.state, session.arena, nil, session.token)
    if not okCover then error(cover, 0) end
    if not cover then
      cover = retryChangedBackdrop(session, nil)
    end
    if commitShot(session, cover, true) then return end
    if holdCommittedPresentation(session,
        "texture-cover-pending") then return end
    error("actor-free battle cover unavailable", 0)
  end
  local ok, shot = pcall(BattleScene.render, session.state, session.arena,
                         textures, session.token)
  if not ok then
    Diagnostics.write("battle-scene-error", {
      mode=session.arena and session.arena.presentationMode,
      reason=tostring(shot),
      grow=session.battle and session.battle.growIn ~= nil,
    })
    -- A thrown scene is a renderer/Canvas/programming failure, not cooperative
    -- readiness.  Only an explicit `render() -> nil` below receives the
    -- bounded cover transaction; deployment flags must never mask this error
    -- or keep a stale/partial frame alive.
    -- One failure retires the arena for THIS battle and nothing else: the
    -- battle screen carries on as the engine's own, the free-roam pipeline
    -- this runs inside keeps rendering the overworld, and the next battle
    -- tries again. Rethrowing would hand the whole voxel mode to Pipelines'
    -- guard, which retires a pipeline for the session.
    session.shot = nil
    session.actorFreeCover = nil
    session.actorFreeCoverOwner = nil
    session.snapped = false
    markSnapped(session.battle, nil, false, "scene-render-failed")
    markSessionNative(session, "scene-render-failed", shot)
    lifecycle("nativeLatched", session.battle,
      "scene-render-failed: " .. tostring(shot))
    V.mod.log:warn("overworld battle scene failed: %s -- this battle draws "
                   .. "on the plain battle background", tostring(shot))
    return
  end
  if not shot then
    shot = retryChangedBackdrop(session, textures)
    if shot then
      publishRenderedShot(session, shot, textures)
      return
    end
    Diagnostics.write("battle-scene-nil", {
      mode=session.arena and session.arena.presentationMode,
      grow=session.battle and session.battle.growIn ~= nil,
      failures=session.renderFailures,
      reason=BattleScene.lastDeclineReason,
      camera=type(BattleCam.directorState) == "function"
        and BattleCam.directorState().screenReason or nil,
    })
    if waitForMobileArenaPrefetch(
        session, dt, BattleScene.lastDeclineReason) then
      return
    end
    local retry, retain, ownerPendingHold = retryAfterNilFrame(
      session, textures, BattleScene.lastDeclineReason, dt)
    if retry then
      if retain then
        if ownerPendingHold and not session.diagnosticOwnerPendingHold then
          session.diagnosticOwnerPendingHold = true
          Diagnostics.write("battle-frame-held", {
            mode=session.arena and session.arena.presentationMode,
            reason="camera-owner-render-pending",
            camera=type(BattleCam.directorState) == "function"
              and BattleCam.directorState().screenReason or nil,
          })
        end
        return
      end
      -- A switch can reuse a canvas while replacing its pixels. Render
      -- the exact same arena without actor textures and publish that complete
      -- cover through the normal HUD transaction. The old monster and native
      -- 2D pics are both absent while the replacement receives its bounded
      -- build window.
      local okCover, cover = pcall(BattleScene.render,
        session.state, session.arena, nil, session.token)
      if okCover and commitShot(session, cover, true) then return end
      if holdCommittedPresentation(session,
          "scene-nil-cover-pending") then
        return
      end
      -- If the chosen architecture cannot even render an actor-free world,
      -- fail once and stay native. Retrying from a visible native frame and
      -- entering Voxel later would itself be a mode switch; this applies to a
      -- cold battle just as strictly as to a mid-battle replacement.
      session.shot = nil
      session.actorFreeCover = nil
      session.actorFreeCoverOwner = nil
      session.snapped = false
      markSnapped(session.battle, nil, false,
                  "scene-cover-unavailable")
      markSessionNative(session, "scene-cover-unavailable",
        "scene-cover-unavailable")
      lifecycle("nativeLatched", session.battle,
        "scene-cover-unavailable")
      V.mod.log:warn("overworld battle cover unavailable -- this battle "
        .. "atomically stays native")
      return
    end
    session.shot = nil
    session.actorFreeCover = nil
    session.actorFreeCoverOwner = nil
    session.snapped = false
    markSnapped(session.battle, nil, false, "scene-render-timeout")
    markSessionNative(session, "scene-render-timeout",
      "scene-render-timeout")
    lifecycle("nativeLatched", session.battle,
      "scene-render-timeout")
    V.mod.log:warn("overworld battle scene produced no complete frame within "
      .. "its bounded retry budget -- this battle stays native")
    return
  end
  publishRenderedShot(session, shot, textures)
end

-- Keep every battle-only dependency behind one module-local error boundary.
-- Pipelines.guard protects the application, but an exception reaching it marks
-- the complete Voxel pipeline broken for the process. A bad battle frame is a
-- much narrower ownership failure: retain the exact BattleState, clear every
-- published world/HUD receipt and make only that encounter native. The session
-- stays alive so its normal exact-owner finish path can restore the culled cast
-- and let the following encounter stage from a clean slate.
function OverworldBattle.update(dt)
  local active = session
  if not active then return true end
  if active.broken then
    -- The exact battle may be script-popped after a renderer exception and
    -- without battle.ended. Keep the minimal stack retirement watchdog alive
    -- even though no Voxel work may run again for this encounter.
    pcall(retireMissingBattleState)
    return true
  end

  local ok, reason = pcall(updateBattleFrame, dt)
  if ok then
    return true
  end

  -- A callback is allowed to end/replace a battle. Never apply the failed
  -- frame's fallback to a different session that appeared before it returned.
  if rawequal(session, active) then
    active.shot = nil
    active.actorFreeCover = nil
    active.actorFreeCoverOwner = nil
    active.textures = nil
    active.snapped = false
    active.presentationCommitted = false
    active.renderFailures = 0
    active.renderFailureWarned = false
    active.cameraSeatRecoverySeconds = nil
    active.cameraSeatRecoveryUpdates = nil
    active.cameraSeatRecoveryReason = nil
    active.cameraSeatRecoveryReported = nil
    markSessionNative(active, "battle-update-failed", reason)
    lifecycle("nativeLatched", active.battle,
      "battle-update-failed: " .. tostring(reason))
    local battle = active.battle
    if type(battle) == "table" then
      battle.voxelAscendantShot = nil
      battle.voxelAscendantHudSnapped = nil
      battle[HUD_SNAP_RECEIPT_KEY] = nil
    end
  end

  if V.mod and V.mod.log and type(V.mod.log.warn) == "function" then
    pcall(V.mod.log.warn, V.mod.log,
      "overworld battle update failed: %s -- this exact battle stays native",
      tostring(reason))
  end
  return false, tostring(reason)
end

-- The finished shot for this frame, or nil when there is none and the battle
-- should draw the way it always did.
function OverworldBattle.shot()
  if not session or session.broken then return nil end
  local s = session.shot
  if s and s.canvas then return s end
  return nil
end

function OverworldBattle.invalidate()
  BattleDOF.invalidate()
  BattleHud.invalidate()
  BattlePics.invalidate()
end

-- ------- the battle screen's background
--
-- BattleState opens by filling 160x144 white -- that fill IS the battle's
-- background, and in the colorized pipeline it is also the BG canvas's clear
-- (nothing else clears it, so skipping it outright would ghost last frame).
-- So for the length of one draw, that one call is intercepted: on the two
-- offscreen canvases it becomes a transparent clear, so the shade-remap pass
-- composites the HUD and the text box over the arena and leaves the empty
-- field showing it; on the screen it is simply dropped, because the UI canvas
-- has already been cleared transparent for the world to show through.
--
-- Matched exactly -- fill, the full frame, at the origin, in opaque white --
-- so the text box (a 20x6 box lower down), a mon pic, an HP bar and the
-- move-animation flash (which is white at 0.85) all pass through untouched.
--
-- This is a shim over love.graphics and it is the one invasive thing here,
-- so it is scoped as tightly as it can be: installed around a single call,
-- removed on the way out including on error, and never live outside a battle
-- frame this mode is drawing.
local function withoutBackgroundFill(battle, fn, ...)
  local g = love.graphics
  local rectangle = g.rectangle
  g.rectangle = function(mode, x, y, w, h, ...)
    if mode == "fill" and x == 0 and y == 0
       and w == BattleScene.GB_W and h == BattleScene.GB_H then
      local r, gr, b, a = g.getColor()
      if r > 0.99 and gr > 0.99 and b > 0.99 then
        -- Two different full-frame whites, both replaced rather than drawn.
        --
        -- OPAQUE is the battle's background, and on the offscreen canvases it
        -- doubles as their clear, so there it becomes a transparent one.
        --
        -- TRANSLUCENT is the hit flash. Over a white field that reads as a
        -- flash; over a world it whites out the map, the HUD and the text box
        -- together. BattleScene puts it back on the mons alone.
        if a > 0.99 then
          local target = g.getCanvas()
          if target ~= nil
             and (target == battle.bgCanvas or target == battle.waveCanvas) then
            g.clear(0, 0, 0, 0)
          end
        end
        return
      end
    end
    return rectangle(mode, x, y, w, h, ...)
  end
  local results = packValues(pcall(fn, battle, ...))
  g.rectangle = rectangle
  if not results[1] then error(results[2], 0) end
  return unpackValues(results, 2, results.n)
end

-- ------- the box, without its paper
--
-- Font.drawBox is a white fill and then six border glyphs, and the fill is the
-- opaque slab the frosted panel underneath is there to replace. So for the
-- length of one drawTextArea the white fills are dropped and everything else
-- -- the border, the text, the cursor, the down arrow -- draws exactly as it
-- always did, over the glass instead of over paper.
--
-- Every fill drawTextArea issues is one of those: the box's own, and the two
-- eight-pixel cells MoveSelectionMenu wipes back to box white before it writes
-- the border glyphs that hardware would have overwritten. Both are opaque
-- white, both are paper, and both go.
--
-- The same shim shape as withoutBackgroundFill above, and scoped as tightly:
-- installed around a single call, removed on the way out including on error,
-- never live outside a battle frame this mode is drawing.
local function withoutBoxFill(battle, fn, ...)
  local g = love.graphics
  local rectangle = g.rectangle
  g.rectangle = function(mode, ...)
    if mode == "fill" then
      local r, gr, b, a = g.getColor()
      if r > 0.99 and gr > 0.99 and b > 0.99 and a > 0.99 then return end
    end
    return rectangle(mode, ...)
  end
  local results = packValues(pcall(fn, battle, ...))
  g.rectangle = rectangle
  if not results[1] then error(results[2], 0) end
  return unpackValues(results, 2, results.n)
end

-- ------- the mons, as textures for the 3D pass
--
-- The two Pokemon are not composited over the world any more: they are quads
-- standing in it (see BattleBillboard). What that needs from the battle
-- screen is a TEXTURE per side -- and the honest way to get one is to let the
-- engine draw its own pics layer, unchanged, into a canvas.
--
-- So the layer is rendered twice, once per side, with the other side
-- falsified out of existence by nulling exactly the fields its branches
-- test. Everything the engine does to a pic comes along for free that way:
-- the trainer pic before the send-out, the grow-out-of-the-ball scale, the
-- faint slide, the damage blink, the squish, every SE displacement. None of
-- it is reimplemented and none of it can drift.
--
-- Two things are forced during that render. The scale, to 1, so the texture
-- carries the artwork's own pixels and the BILLBOARD does the sizing; and the
-- placement, so the pic lands centred on a known column with its feet on a
-- known row. That known point is what the quad is then hung from.
local TEX_AX, TEX_AY = 80, 96          -- forced pic centre and baseline
local TRAINER_AX, TRAINER_AY = 124, 56 -- the intro trainer pic's own slot

OverworldBattle.TEX_AX, OverworldBattle.TEX_AY = TEX_AX, TEX_AY

-- Which side is being rendered, or nil. The placement wrappers read it.
local texturing = nil

-- Non-nil only while the exact DEFAULT + STANDARD battle draws its native
-- pics layer.  Unlike `texturing`, this never participates in Voxel captures.
local nativeCartridgeBattle = nil

-- Non-nil only around the native pics-layer draw of an explicitly selected
-- trainer back.  Keeping the scope this tight is what prevents the classic
-- card fit from changing Pokemon backs, world billboards or companion art.
local pinnedTrainerBackSprite = nil

local texCanvas = {}
local innerPics = nil                   -- captured by install()
local innerHUDs = nil                   -- likewise, for the snapped HUD layer
local innerText = nil                   -- and the edge-docked command panes
local innerAnim = nil                   -- move-animation layer

local function texCanvasFor(side)
  local c = texCanvas[side]
  if c then return c end
  local ok, made = pcall(love.graphics.newCanvas, BattleScene.GB_W,
                         BattleScene.GB_H, { dpiscale = 1 })
  if not ok or not made then
    error(("Gen-1 %s battle-pic Canvas allocation failed: %s")
      :format(tostring(side), tostring(made)), 0)
  end
  made:setFilter("nearest", "nearest")
  texCanvas[side] = made
  return made
end

-- Standalone VASC must never depend on a companion being installed merely to
-- render a legal trainer in MAP/DISCS/ARENA.  This reviewed Red standee is a
-- packaged fallback only; KASC may still replace `sideTexture` through the
-- public wrapper and therefore remains authoritative for Red/Blue/Green and
-- opponent identity when present.
local embeddedTrainerChecked = false
local embeddedTrainerTexture = nil
local embeddedTrainerCompanionNotice = false

-- The packaged Red standee is a standalone default, never an identity
-- decision for a companion-owned save.  KASC can load before this renderer
-- publishes its public sideTexture seam; during that short late-provider gap
-- its wrapper is not installed yet.  Treating the gap as "standalone" made a
-- valid GREEN/BLUE selection visibly become Red.  A present companion keeps
-- its identity authority even while its presentation relay is being rebound,
-- so fail closed to the engine's native card instead of inventing a trainer.
local function companionOwnsTrainerIdentity()
  local mod = V.mod
  if not (mod and type(mod.find) == "function") then return false end
  for _, id in ipairs({ "kanto_ascendant", "trainer_rematch" }) do
    local ok, handle = pcall(mod.find, id)
    if not ok then ok, handle = pcall(mod.find, mod, id) end
    if ok and handle ~= nil then return true end
  end
  return false
end

local function embeddedPlayerTrainerTexture()
  if embeddedTrainerChecked then return embeddedTrainerTexture end
  embeddedTrainerChecked = true
  local g = love and love.graphics
  local root = V.mod and V.mod.path
  if not g then return nil end
  local relative = "assets/fallback/red_voxel_front_hd.png"
  local source, image
  local okFiles, UserFiles = pcall(V.require, "UserFiles")
  if okFiles and type(UserFiles) == "table" then
    if type(UserFiles.image) == "function" then
      local okAsset, assetImage = pcall(UserFiles.image, relative)
      if okAsset and assetImage then image = assetImage end
    end
    if not image and type(UserFiles.path) == "function" then
      local okPath, assetPath = pcall(UserFiles.path, relative)
      if okPath and type(assetPath) == "string" and assetPath ~= "" then
        source = assetPath
      end
    end
  end
  source = source or (type(root) == "string" and root ~= ""
    and (root .. "/" .. relative) or nil)
  if not image and source then
    local okImage, loaded = pcall(g.newImage, source)
    if okImage then image = loaded end
  end
  if not (image and type(image.getDimensions) == "function") then
    return nil
  end
  local width, height = image:getDimensions()
  if width ~= 128 or height ~= 128 then return nil end
  pcall(image.setFilter, image, "nearest", "nearest")
  local okCanvas, canvas = pcall(g.newCanvas, 320, 288, { dpiscale=1 })
  if not (okCanvas and canvas) then return nil end
  pcall(canvas.setFilter, canvas, "nearest", "nearest")

  local previousCanvas = g.getCanvas()
  local previousBlend, previousAlpha = g.getBlendMode()
  local cr, cg, cb, ca = g.getColor()
  local okDraw, why = pcall(function()
    g.setCanvas(canvas)
    g.clear(0, 0, 0, 0)
    g.setBlendMode("alpha")
    g.setColor(1, 1, 1, 1)
    -- Logical player anchor (80,96) in a 2x source canvas.
    g.draw(image, 80 * 2 - width / 2, 96 * 2 - height)
  end)
  if previousCanvas then g.setCanvas(previousCanvas) else g.setCanvas() end
  g.setBlendMode(previousBlend or "alpha", previousAlpha)
  g.setColor(cr, cg, cb, ca)
  if not okDraw then
    if V.mod and V.mod.log and type(V.mod.log.warn) == "function" then
      V.mod.log:warn("embedded trainer fallback unavailable: %s", tostring(why))
    end
    return nil
  end

  embeddedTrainerTexture = {
    canvas = canvas, ax = 80, ay = 96,
    trainer = false, trainerArt = true,
    ascendantStandingTrainer = "VASC_RED_FALLBACK",
    ascendantHighResTrainer = true,
    ascendantHighResSource = relative,
    ascendantTrainerSourceScale = 2,
    vascEmbeddedTrainer = {
      apiVersion = 1, identity = "RED", view = "front", body = "full",
    },
  }
  return embeddedTrainerTexture
end

-- Whether this side has anything to draw at all. Mirrors drawPicsLayer's own
-- guards, so an empty canvas is never hung on a quad: a fainted, hidden or
-- not-yet-sent-out mon simply has no billboard this frame.
local function sideVisible(battle, side)
  local function effectHidden(battler)
    if not battler then return false end
    -- Native send-out starts with three deliberately empty frames; recall
    -- similarly ends at zero scale. These are absence, not broken textures.
    if type(battle.growInScale) == "function"
        and battle:growInScale(battler) == 0 then return true end
    if type(battle.shrinkOutScale) == "function"
        and battle:shrinkOutScale(battler) == 0 then return true end
    if type(battle.fxHidden) == "function" and battle:fxHidden(battler) then
      return true
    end
    -- Dig/Fly uses the persistent picture-effect hide, not fxHidden (which is
    -- also used for short damage blinks). Mirror drawBattlerPic so a Voxel
    -- billboard cannot remain visible after the native layer hides its owner.
    local pic = battle.picFx and battle.picFx[battler]
    return pic and pic.hidden == true or false
  end
  if side == "enemy" then
    if battle.showEnemyTrainer and battle.trainerPic then return true end
    return (battle.enemy and battle.enemy.sprite and not battle.enemyHidden
            and not battle.enemySendingOut
            and not effectHidden(battle.enemy)) and true or false
  end
  if battle.showPlayerBack and battle.playerBackPic then return true end
  local hide = battle.safari or battle.demo
  return (battle.player and battle.player.sprite and not hide
          and not battle.sendingOut
          and not effectHidden(battle.player)) and true or false
end

local OFF = {
  enemy = { player = false, showPlayerBack = false },
  player = { enemy = false, showEnemyTrainer = false },
}

-- Canonical physical height for staged presentation. Keep this pure and
-- exported so the cross-engine fixtures can prove corrupt or partial data
-- always falls back to neutral sizing rather than breaking a battle.
function OverworldBattle.battlerHeightIn(battle, side)
  local battler = battle and battle[side]
  local entry = battler and battler.def and battler.def.dexEntry
  -- Form providers may replace `battler.def` with a combat-only profile that
  -- deliberately carries no Pokédex prose/measurements.  The underlying mon
  -- still names its canonical species, and the battle's immutable registry
  -- remains the authority for physical presentation.  This is particularly
  -- important for Kanto Ascendant Megas: falling through to nil made every
  -- form use neutral scale while the ordinary opponent used its real height.
  if not entry and battler and battler.mon and battler.mon.species then
    local data = battle and (battle.data or (battle.game and battle.game.data))
    local def = data and data.pokemon and data.pokemon[battler.mon.species]
    entry = def and def.dexEntry
  end
  local feet = tonumber(entry and entry.heightFt)
  local inches = tonumber(entry and entry.heightIn) or 0
  if not (feet and feet == math.floor(feet) and feet >= 0
          and inches == math.floor(inches) and inches >= 0
          and inches < 12) then
    return nil
  end
  local total = feet * 12 + inches
  return total > 0 and total or nil
end

-- Companion renderers wrap `sideTexture` after VASC has installed. Some of
-- those wrappers replace the captured card with a high-resolution monster
-- canvas while an engine trainer flag is still transitioning, or omit fields
-- that were present on the inner card. Finalise the result only after the
-- complete wrapper chain has returned. This is the authoritative production
-- seam used by `textures`; it keeps ordinary cards unchanged and makes KASC's
-- Mega/Gorochu cards unambiguously monster art with canonical physical size.
function OverworldBattle.finalizeSideTexture(battle, side, texture)
  if type(texture) ~= "table" then return texture end
  local battler = battle and battle[side] or nil
  local mon = battler and battler.mon or nil
  local grow = battle and battle.growIn
  local shrink = battle and battle.shrinkOut
  texture.inkTransient = (grow and grow.battler == battler)
    or (shrink and shrink.battler == battler) or nil
  local companionMon = texture.kantoAscendantMegaSupersampled == true
    or texture.kantoAscendantGorochuSupersampled == true
  if companionMon then
    texture.trainer = false
    texture.trainerArt = false
  elseif texture.ascendantHighResTrainer == true then
    -- KASC's 320x288 standee deliberately keeps its anchor in logical
    -- 160x144 battle coordinates.  Preserve that public receipt so
    -- BattleScene can convert both its density and anchor exactly once.
    texture.trainerArt = true
    texture.inkIdentity = texture.ascendantHighResSource
      or texture.inkIdentity
    -- The provider already authors this canvas with nearest sampling.  Set it
    -- again at the public boundary so hot reloads or an intermediate wrapper
    -- cannot silently turn reviewed pixel art into a blurred billboard.
    local canvas = texture.canvas
    if canvas and type(canvas.setFilter) == "function" then
      pcall(canvas.setFilter, canvas, "nearest", "nearest")
    end
  end
  local trainerArt = texture.trainer == true or texture.trainerArt == true
  -- VASC-owned role receipts let the saved BATTLE LAYOUT controller classify
  -- the final card without querying whichever optional package supplied its
  -- pixels.  They describe presentation only and never write provider state.
  texture.vascBattleSide = side
  texture.vascMegaPresentation = companionMon and true or nil
  local presentation = trainerArt and "front"
    or OverworldBattle.pokemonPresentation(texture)
  if presentation == "full_back" then presentation = "back" end
  texture.vascSpriteView = presentation == "back" and "back" or "front"
  texture.vascBackSelected = side == "player" and not trainerArt
    and presentation == "back" or nil
  if not trainerArt then
    texture.heightIn = OverworldBattle.battlerHeightIn(battle, side)
      or texture.heightIn
    texture.inkIdentity = texture.kantoAscendantMegaSource
      or texture.kantoAscendantGorochuSource
      or texture.inkIdentity
      or (battler and battler.sprite)
  end
  -- Exact public render identity for the shot produced from this card.  The
  -- reused side canvas is deliberately not sufficient on its own: a switch
  -- paints a different Pokemon into the same canvas.  The tuple below lets the
  -- HUD reject a stale head receipt until the real replacement texture has
  -- completed the same render path as the billboard now on screen.
  texture.vascRenderBattler = battler
  texture.vascRenderMon = mon
  texture.vascRenderModelKey = table.concat({
    tostring(texture.vascVisualSpecies
      or mon and mon.species or trainerArt and "TRAINER" or ""),
    tostring(mon and mon._ascMegaForm or battler and battler._ascMegaForm or ""),
    tostring(mon and mon.form or battler and battler.form or ""),
    tostring(texture.vascSpriteView or "front"),
    trainerArt and "trainer" or "pokemon",
  }, "|")
  -- `inkIdentity` may be an animation-frame sprite object. Treating that
  -- ephemeral frame as deployment identity made an unchanged battler acquire
  -- a new frozen HUD slot every few frames.  A deployment is instead the
  -- exact mon object plus its modelKey. Companion Pokemon sources are not
  -- deployment tokens: Mega/Gorochu animation providers may publish a
  -- different source path on every authored frame. `inkIdentity` remains the
  -- content key, while modelKey already carries species/form/view changes.
  -- Trainer sources are static presentation identities and keep their token.
  if trainerArt then
    texture.vascRenderTextureToken = texture.ascendantHighResSource
      or texture.inkIdentity or texture.canvas
  else
    texture.vascRenderTextureToken = mon or battler or texture.canvas
  end
  return texture
end

-- Optional companion animation discovery stays behind the same two reviewed
-- package identities already used for trainer ownership. The seam is
-- presentation-only: it returns an independent state/image and never asks the
-- companion to select a side on the live BattleState mon.
function OverworldBattle.companionVoxelFrontAnimation(
    battle, visualMon, presentationMode)
  local owner = V.mod
  if not (owner and type(owner.find) == "function"
      and type(visualMon) == "table"
      and type(visualMon.species) == "string"
      and not visualMon._ascMegaForm
      and not visualMon.ascMegaForm) then return nil end
  local mode = presentationMode == "DISCS" and "DISK"
    or presentationMode == "ARENA" and "ARENA" or "MAP"
  for _, id in ipairs({ "kanto_ascendant", "trainer_rematch" }) do
    local okHandle, handle = pcall(owner.find, id)
    if not okHandle then okHandle, handle = pcall(owner.find, owner, id) end
    local exports = okHandle and type(handle) == "table"
      and handle.exports or nil
    local animation = type(exports) == "table"
      and exports.crystalAnimation or nil
    if type(animation) == "table"
        and type(animation.voxelPresentationAnimation) == "function"
        and type(animation.advancePresentation) == "function" then
      local okState, state = pcall(animation.voxelPresentationAnimation,
        visualMon.species, visualMon, mode, {
          data=battle and battle.data,
          kind="battle", source="vasc_overworld_battle",
        })
      if okState and type(state) == "table" and state.side == "front"
          and state.image ~= nil then
        return animation, state, id, mode
      end
    end
  end
  return nil
end

-- Companion presentation states are advanced from VASC's real-time update,
-- independently of the engine's native rear battler. Fast-forward therefore
-- cannot spin the world front, and a provider error freezes the last complete
-- front instead of mutating or borrowing the classic 2D fallback.
function OverworldBattle.advanceWorldPlayerSprite(battle, dt)
  local battler = battle and battle.player
  local cached = battler and worldPlayerSpriteCache[battler] or nil
  if not (cached and cached.mon == battler.mon
      and type(cached.presentationAnimation) == "table"
      and type(cached.presentationAnimation.advancePresentation)
        == "function"
      and type(cached.presentationState) == "table") then return false end
  local okImage, image = pcall(
    cached.presentationAnimation.advancePresentation,
    cached.presentationState, dt, game())
  if okImage and image ~= nil then
    cached.sprite = image
    return true
  end
  cached.presentationAnimation = nil
  cached.presentationState = nil
  cached.presentationFailed = true
  return false
end

-- The engine must retain its real rear image for a possible atomic return to
-- DEFAULT/2D.  World presentation therefore resolves the player's front art
-- into a private render-only battler and swaps it in only while the isolated
-- side canvas is painted.  No live mon/battler field survives that draw.
function OverworldBattle.worldPlayerSprite(battle)
  local battler = battle and battle.player
  local mon = battler and battler.mon
  if not (battler and mon and type(mon.species) == "string"
      and type(battle.data) == "table") then
    error("Gen-1 ORAS/MAP player-front resolver not ready: missing live "
      .. "battler, species or battle registry", 0)
  end
  local species = battle._vascWorldVisualBattler == battler
    and battle._vascWorldVisualSpecies or mon.species
  if type(species) ~= "string" or species == "" then species = mon.species end

  local form = tostring(mon._ascMegaForm or mon.form or "")
  local selectedMode = session and session.battle == battle
    and session.arena and session.arena.presentationMode or nil
  if selectedMode == nil then
    local configured = OverworldBattle.setting:get()
    selectedMode = configured == OverworldBattle.FLAT_B and "DISCS"
      or configured == OverworldBattle.ARENA and "ARENA" or "MAP"
  end
  local cached = worldPlayerSpriteCache[battler]
  if cached and cached.mon == mon and cached.species == species
      and cached.form == form and cached.mode == selectedMode then
    if cached.presentationState ~= nil or cached.presentationFailed == true
        or cached.native == battler.sprite then
      return cached.sprite
    end
  end
  -- Render-only selection must never share the engine mon identity. KASC's
  -- native Crystal selector keys side choice by mon; resolving a VASC front
  -- on the live object overwrote the player's native BACK selection, which a
  -- later fail-closed 2D frame then exposed as a forbidden front. The shallow
  -- presentation copy preserves shiny/form data without acquiring save or
  -- BattleState ownership.
  local visualMon = {}
  for key, value in pairs(mon) do visualMon[key] = value end
  visualMon.species = species

  local animation, presentation, provider, providerMode =
    OverworldBattle.companionVoxelFrontAnimation(
      battle, visualMon, selectedMode)
  if presentation then
    worldPlayerSpriteCache[battler] = {
      mon=mon, species=species, form=form, mode=selectedMode,
      sprite=presentation.image,
      presentationAnimation=animation,
      presentationState=presentation,
      presentationProvider=provider,
      presentationMode=providerMode,
    }
    return presentation.image
  end
  local okState, BattleState = pcall(require, "src.battle.BattleState")
  local okFront, front = false, nil
  if okState and type(BattleState) == "table"
      and type(BattleState.makeBattler) == "function" then
    okFront, front = pcall(
      BattleState.makeBattler, battle.data, visualMon, false, nil)
  end
  if not okFront then
    error("Gen-1 ORAS/MAP player-front resolution failed: "
      .. tostring(front), 0)
  end
  local sprite = type(front) == "table" and front.sprite or nil
  if not sprite then
    error("Gen-1 ORAS/MAP player-front resolver returned no sprite", 0)
  end
  worldPlayerSpriteCache[battler] = {
    native=battler.sprite, mon=mon, species=species, form=form,
    mode=selectedMode, sprite=sprite,
  }
  return sprite
end

-- Render one side's pics layer into its canvas and report where the pic's
-- feet ended up, in canvas coordinates.
local function baseSideTexture(battle, side)
  if not (innerPics and battle) then return nil end
  if not sideVisible(battle, side) then return nil end
  local canvas = texCanvasFor(side)

  -- Resolve the private player-front before mutating any BattleState or LÖVE
  -- graphics state. The live battler intentionally retains its native rear as
  -- the atomic DEFAULT fallback; it must never be reused as a world/front card
  -- when the private resolver fails.
  local requestedPlayerFront = nil
  if side == "player" and battle.player and battle.player.sprite
      and not battle.showPlayerBack
      and OverworldBattle.pokemonPresentation() == "front" then
    requestedPlayerFront = OverworldBattle.worldPlayerSprite(battle)
  end

  local g = love.graphics
  local prevCanvas = g.getCanvas()
  local prevBlend, prevAlpha = g.getBlendMode()
  -- The pic-window scissors are in the battle screen's fixed coordinates and
  -- would clip a pic that has been moved to the middle of its own canvas.
  -- There is nothing here for them to protect -- no HUD, no text box, just
  -- the one pic -- so they are switched off for the render.
  local setScissor, intersectScissor = g.setScissor, g.intersectScissor
  local getScissor = g.getScissor
  g.setScissor = function() end
  g.intersectScissor = function() end
  g.getScissor = function() return nil end

  local saved = {}
  for k, v in pairs(OFF[side]) do saved[k] = battle[k]; battle[k] = v end
  local originalPlayerSprite, renderedPlayerSprite
  if requestedPlayerFront ~= nil then
    originalPlayerSprite = battle.player.sprite
    renderedPlayerSprite = requestedPlayerFront
    battle.player.sprite = renderedPlayerSprite
  end
  texturing = side

  local ok, err = pcall(function()
    g.setCanvas(canvas)
    g.clear(0, 0, 0, 0)
    g.setBlendMode("alpha")
    g.setColor(1, 1, 1, 1)
    innerPics(battle, 0, 0, 0)
  end)

  texturing = nil
  if originalPlayerSprite then battle.player.sprite = originalPlayerSprite end
  for k in pairs(OFF[side]) do battle[k] = saved[k] end
  g.setScissor, g.intersectScissor, g.getScissor =
    setScissor, intersectScissor, getScissor
  if prevCanvas then g.setCanvas(prevCanvas) else g.setCanvas() end
  g.setBlendMode(prevBlend or "alpha", prevAlpha)
  if not ok then error(err, 0) end

  local ax, ay = TEX_AX, TEX_AY
  local trainer = false
  local trainerArt = false
  -- The intro trainer pic draws itself straight into its own 7x7 slot rather
  -- than through the placement helpers, so it is hung from that slot instead.
  if side == "enemy" and battle.showEnemyTrainer and battle.trainerPic then
    ax, ay, trainer, trainerArt = TRAINER_AX, TRAINER_AY, true, true
  elseif side == "player" and battle.showPlayerBack and battle.playerBackPic then
    -- TRAINER BACK = OFF means the back-slot image is deliberately front art
    -- standing in the scene, so it follows the regular player-card mirror.
    trainer = OverworldBattle.trainerBackPinned()
    trainerArt = true
  end
  local heightIn = not trainerArt
                   and OverworldBattle.battlerHeightIn(battle, side) or nil
  local inkIdentity
  if trainerArt then
    inkIdentity = side == "enemy" and battle.trainerPic
      or battle.playerBackPic
  else
    inkIdentity = renderedPlayerSprite
      or battle[side] and battle[side].sprite or nil
  end
  return { canvas = canvas, ax = ax, ay = ay, trainer = trainer,
           trainerArt = trainerArt, heightIn = heightIn,
           vascVisualSpecies = side == "player" and battle.player
             and (battle._vascWorldVisualBattler == battle.player
               and battle._vascWorldVisualSpecies
               or battle.player.mon and battle.player.mon.species) or nil,
           -- The two side canvases are reused every frame.  Cache alpha
           -- bounds by the actual art identity, never merely by the canvas,
           -- or changing species/forms would inherit the previous feet.
           inkIdentity = inkIdentity }
end

-- Public compatibility seam. Companion renderers may wrap this function for
-- their own standing/front art. The selected trainer BACK is intentionally
-- captured through `baseSideTexture` below: the engine's player.sprite chain
-- has already resolved the correct Red/Blue/Green/native rear image, while a
-- standing-trainer wrapper would otherwise replace that back with front art.
function OverworldBattle.sideTexture(battle, side)
  if stadiumModelsEnabled() then
    local okCovered, covered = pcall(function()
      return V.require("Stadium").covers(battle, side)
    end)
    if okCovered and covered == true then return nil end
  end
  if side == "player" and battle and battle.showPlayerBack
      and battle.playerBackPic and not battle.demo and not battle.oakDemo
      and OverworldBattle.trainerPresentation() == "front" then
    if companionOwnsTrainerIdentity() then
      if not embeddedTrainerCompanionNotice and V.mod and V.mod.log
          and type(V.mod.log.info) == "function" then
        embeddedTrainerCompanionNotice = true
        V.mod.log:info("embedded Red trainer fallback suppressed: "
          .. "companion owns player identity")
      end
      return baseSideTexture(battle, side)
    end
    return embeddedPlayerTrainerTexture() or baseSideTexture(battle, side)
  end
  return baseSideTexture(battle, side)
end

-- Whether the hit flash is showing this frame.
--
-- Mirrors BattleState:draw's own test, because the flash is a DRAW-time
-- decision there (a counter plus the frame parity that makes it flicker) and
-- there is no seam that reports it. Read-only, so the worst a future engine
-- change can do is flash on a frame the engine would not have.
function OverworldBattle.flashing(battle)
  local fx = battle and battle.fx
  if not (fx and fx.flash and fx.flash > 0) then return false end
  return (battle.frame or 0) % 4 < 2
end

-- Both sides, or nil when neither has anything to show. Front and rear source
-- choices follow the same path so every visible battler receives one grounded
-- billboard and one shadow policy.
function OverworldBattle.textures(battle)
  if not battle then return nil end
  local out = {}
  local okE, enemy = pcall(
    legacyPresentation, "sideTexture", battle, "enemy")
  local okP, player = true, nil
  if not OverworldBattle.playerBackPinned(battle) then
    if OverworldBattle.trainerBackStaged(battle) then
      okP, player = pcall(baseSideTexture, battle, "player")
    else
      okP, player = pcall(
        legacyPresentation, "sideTexture", battle, "player")
    end
  end
  if not okE then error(enemy, 0) end
  if not okP then error(player, 0) end
  out.enemy = okE and OverworldBattle.finalizeSideTexture(
    battle, "enemy", enemy) or nil
  out.player = okP and OverworldBattle.finalizeSideTexture(
    battle, "player", player) or nil
  -- A legacy art wrapper may turn an intentional nil into an empty Canvas.
  -- Reapply native visibility after the complete wrapper chain so send-out
  -- covers remain pending, rather than claiming an actor with no receipt.
  if not sideVisible(battle, "enemy") then out.enemy = nil end
  if not sideVisible(battle, "player") then out.player = nil end
  local standing = false
  if stadiumModelsEnabled() then
    local okStanding, value = pcall(function()
      return V.require("Stadium").standing()
    end)
    if not okStanding then error(value, 0) end
    standing = value == true
  end
  if not (out.enemy or out.player or standing) then return nil end
  out.flash = OverworldBattle.flashing(battle)
  return out
end

-- ------- engine seams
--
-- Four wraps, each idempotent so a hot reload cannot stack them.

local function validRuntimeLease(value)
  return type(value) == "table"
    and value.schema == RUNTIME_LEASE_SCHEMA
    and value.apiVersion == 1
    and (value.state == "active" or value.state == "retired")
    and type(value.retire) == "function"
end

local function retireRuntime(reason)
  if runtimeState == "retired" then return false end

  reason = tostring(reason or "battle wrapper runtime retired")
  -- This is the irreversible part of the operation.  It happens before any
  -- callback-bearing cleanup, so even an exceptional provider cannot reopen
  -- the old instance or let its installed wrapper publish another frame.
  runtimeState = "retired"
  local retiredLegacyBridge = legacyCompatibilityBridge
  legacyCompatibilityBridge = nil
  legacyFinishRequestedBattle = nil
  if validLegacyCompatibilityBridge(retiredLegacyBridge) then
    pcall(retiredLegacyBridge.retire, reason)
  end
  if runtimeLease then
    runtimeLease.state = "retired"
    runtimeLease.reason = reason
  end
  supported = false
  nativeBattlePreflight = nil

  local hadSession = session ~= nil
  local retiredBattle = session and session.battle
    or rendererPreparation and rendererPreparation.battle
    or nil
  if retiredBattle == nil then
    local current = lifecycle("current")
    retiredBattle = type(current) == "table" and current.battle or nil
  end
  local retireOwners = runtimeRetireCallback
  runtimeRetireCallback = nil
  local ownersRetired = false
  if type(retireOwners) == "function" then
    local ok, value, nativeOwner = pcall(retireOwners, reason)
    ownersRetired = ok and value ~= false
    -- A failed/aborted Card no longer has a lifecycle.current receipt, while
    -- the outer native cleanup adapter still owns the exact live BattleState.
    -- Accept only that explicit owner handoff; never search global state.
    if retiredBattle == nil and type(nativeOwner) == "table" then
      retiredBattle = nativeOwner
    end
  end
  pcall(OverworldBattle.setBattleLifecycleReady, false, reason)
  -- setBattleLifecycleReady already has the normal and forced cleanup paths.
  -- Keep this last-resort branch local to the first owner in case that seam was
  -- itself what failed during a hot-reload retirement.
  if session or rendererPreparation then
    local hadRendererSession = session ~= nil
    retiredBattle = retiredBattle
      or (session and session.battle)
      or (rendererPreparation and rendererPreparation.battle)
    pcall(rendererSessionAbort, retiredBattle, reason, false)
    if hadRendererSession and type(replacementCleanup) == "function" then
      pcall(replacementCleanup, retiredBattle)
    end
  elseif not ownersRetired and not hadSession and retiredBattle ~= nil
      and type(replacementCleanup) == "function" then
    pcall(replacementCleanup, retiredBattle)
  end
  staged = { key=nil, ready=false, arena=nil }
  texturing = nil
  nativeCartridgeBattle = nil
  pinnedTrainerBackSprite = nil
  pcall(BattleCam.reset)
  Voxel3D.camera = nil
  if type(retiredBattle) == "table" then
    retiredBattle.voxelAscendantShot = nil
    retiredBattle.voxelAscendantHudSnapped = nil
    retiredBattle[HUD_SNAP_RECEIPT_KEY] = nil
    retiredBattle.dramaticShapeShot = nil
    retiredBattle.letterboxWhite = nil
    retiredBattle._vascNativeCartridgeFrontAnchor = nil
    retiredBattle._vascWorldVisualBattler = nil
    retiredBattle._vascWorldVisualSpecies = nil
    if retiredBattle.player ~= nil then
      worldPlayerSpriteCache[retiredBattle.player] = nil
    end
  end
  return true
end

function OverworldBattle.install()
  supported = false
  local OverworldState = require("src.world.OverworldController")
  local BattleState = require("src.battle.BattleState")

  local incumbent = rawget(OverworldState, RUNTIME_LEASE_SLOT)
  if incumbent ~= nil
      and incumbent == runtimeLease
      and runtimeState == "installed"
      and incumbent.state == "active" then
    supported = true
    return true
  end
  if incumbent ~= nil then
    local valid = validRuntimeLease(incumbent)
    local retired, retireReason = false, nil
    if valid then
      local called, value = pcall(
        incumbent.retire, "overworld-battle-module-reentry")
      retired = called and (value == true or incumbent.state == "retired")
      if not called then retireReason = tostring(value) end
    end
    if retired and incumbent.replaceable == true then
      -- Every wrapper of this lease delegates unchanged after retirement.
      -- Remove owned outer wrappers where possible; foreign outer wrappers
      -- retain an inert inner link and are never overwritten.
      if type(incumbent.detach) == "function" then incumbent.detach() end
      OverworldState.voxelAscendantBattleHook = nil
      BattleState.voxelAscendantBattleHook = nil
      rawset(OverworldState, RUNTIME_LEASE_SLOT, nil)
    else
    runtimeState = "rejected"
    battleLifecycleReady = false
    battleLifecycleReason = valid
      and (retired and "battle wrapper runtime already installed; restart required"
        or "incumbent battle wrapper retirement failed: "
          .. tostring(retireReason or "unknown failure"))
      or "invalid battle wrapper runtime lease; restart required"
    nativeBattlePreflight = nil
    return false, battleLifecycleReason
    end
  end

  -- A marker without the versioned kill switch belongs to a pre-lease or
  -- partially installed runtime.  Its captured inner/upvalues are unreachable;
  -- claiming a safe hot upgrade would be dishonest, so reject this instance.
  if OverworldState.voxelAscendantBattleHook
      or BattleState.voxelAscendantBattleHook then
    runtimeState = "rejected"
    battleLifecycleReady = false
    battleLifecycleReason =
      "legacy battle wrapper has no retirement lease; restart required"
    nativeBattlePreflight = nil
    return false, battleLifecycleReason
  end

  local required = {
    { OverworldState, "pushBattle" },
    { BattleState, "resolveBattleScale" },
    { BattleState, "picImage" },
    { BattleState, "backPlacement" },
    { BattleState, "frontPlacement" },
    { BattleState, "draw" },
    { BattleState, "drawPicsLayer" },
    { BattleState, "drawTextArea" },
    { BattleState, "drawAnimLayer" },
    { BattleState, "drawZonePass" },
    { BattleState, "drawHUDs" },
    { BattleState, "fxHidden" },
    { BattleState, "growInScale" },
  }
  for _, seam in ipairs(required) do
    if type(seam[1] and seam[1][seam[2]]) ~= "function" then
      runtimeState = "unsupported"
      battleLifecycleReady = false
      battleLifecycleReason =
        "required engine seam unavailable: " .. tostring(seam[2])
      nativeBattlePreflight = nil
      if V.mod and V.mod.log and type(V.mod.log.warn) == "function" then
        V.mod.log:warn("3D battle disabled: engine seam %s is unavailable",
                       seam[2])
      end
      return false, battleLifecycleReason
    end
  end

  runtimeLease = {
    schema=RUNTIME_LEASE_SCHEMA,
    apiVersion=1,
    state="installing",
    replaceable=true,
  }
  runtimeLease.retire = retireRuntime
  -- Stadium owns its independent wrappers/marker. Capture our inner methods
  -- after its installation so detaching this runtime retains that owner.
  pcall(function() V.require("Stadium").install() end)
  local originalMethods = {}
  for _, class in ipairs({OverworldState, BattleState}) do
    originalMethods[class] = {}
    for key, fn in pairs(class) do originalMethods[class][key] = fn end
  end

  if not OverworldState.voxelAscendantBattleHook then
    local inner = OverworldState.pushBattle
    -- The one place the overworld starts a battle, and it runs BEFORE the
    -- transition is pushed -- which is what lets the cull happen off-screen
    -- and the wipe play over a map with nobody on it.
    function OverworldState:pushBattle(battle, ...)
      local leaseActive = runtimeLeaseActive()
        and rawget(OverworldState, RUNTIME_LEASE_SLOT) == runtimeLease
      if leaseActive then
        if type(nativeBattlePreflight) == "function" then
          local okPreflight, preflightReason = pcall(
            nativeBattlePreflight, battle)
          if not okPreflight and V.mod and V.mod.log
              and type(V.mod.log.warn) == "function" then
            V.mod.log:warn("native battle preflight failed open: %s",
                           tostring(preflightReason))
          end
        end
        pcall(OverworldBattle.begin, self, battle)
      end
      return inner(self, battle, ...)
    end
    OverworldState.voxelAscendantBattleHook = true
  end

  if BattleState.voxelAscendantBattleHook then
    supported = true
    return true
  end

  -- Transform reloads the player's picture for the copied species. Keep that
  -- native rear on the real battler, while recording which species the
  -- render-only world front must resolve on the next scene update.
  if type(BattleState.speciesSprite) == "function" then
    local innerSpeciesSprite = BattleState.speciesSprite
    function BattleState:speciesSprite(species, isPlayerSide, ...)
      if runtimeLeaseActive() and isPlayerSide then
        self._vascWorldVisualBattler = self.player
        self._vascWorldVisualSpecies = species
      end
      return innerSpeciesSprite(self, species, isPlayerSide, ...)
    end
  end

  -- Integer scales only. The camera is solved to make one overworld square
  -- exactly big enough for a pic at its own integer scale (see BattleCam), so
  -- the fit never has to come out of the pixels -- and a species override or
  -- a battle_sprite_scales entry that asks for 1.7x would undo that and
  -- resample the sprite into mush. Rounded rather than refused, so such a mod
  -- still gets the bigger or smaller mon it asked for, on the pixel grid.
  local innerScale = BattleState.resolveBattleScale
  function BattleState.resolveBattleScale(data, side, path, species, ...)
    local results = packValues(innerScale(data, side, path, species, ...))
    local base = results[1]
    -- 1:1 into the billboard texture: the artwork's own pixels, with the
    -- quad's world size doing every bit of the scaling. Anything else would
    -- resample the sprite twice -- once into the texture and again on the way
    -- to the screen -- and a twice-resampled Gen 1 pic is mush.
    if texturing then
      results[1] = 1
    elseif pinnedTrainerBackSprite and side == "back" and species == nil then
      results[1] = OverworldBattle.classicBackCardScale(
        pinnedTrainerBackSprite, base)
    elseif OverworldBattle.shot() then
      results[1] = math.max(1, math.floor((tonumber(base) or 1) + 0.5))
    end
    return unpackValues(results, 1, results.n)
  end

  -- Keyed-out whites inside a pic used to be filled by the white field
  -- behind it. There is a world back there now, so they are filled here
  -- instead -- see BattlePics, which puts the paper back without touching
  -- the silhouette.
  --
  -- The pinned pic is told that its feet are on the box, which is what lets
  -- the pale-bodied back sprites be filled at all: their bellies leak out
  -- through an opening too wide to read as a drain, and only the box under
  -- them settles that it is not a hole. Passed the pre-bake image, because
  -- that is the one the battle holds a reference to.
  local innerPic = BattleState.picImage
  function BattleState:picImage(img, ...)
    local results = packValues(innerPic(self, img, ...))
    if OverworldBattle.shot() then
      results[1] = BattlePics.filled(results[1],
                                     OverworldBattle.pinnedPic(self, img))
    end
    return unpackValues(results, 1, results.n)
  end

  -- While a billboard texture is being rendered both pics are put in the same
  -- known place -- centred on TEX_AX with their feet on TEX_AY -- so the quad
  -- has one anchor to hang from whichever side and whichever species it is
  -- carrying. Outside that render both helpers answer exactly as they always
  -- did.
  local innerBack = BattleState.backPlacement
  function BattleState.backPlacement(w, h, pad, padL, scale, ...)
    local results = packValues(innerBack(w, h, pad, padL, scale, ...))
    if texturing then
      results[1] = TEX_AX - w * scale / 2
      results[2] = TEX_AY - (h - pad) * scale
    end
    return unpackValues(results, 1, results.n)
  end

  local innerFront = BattleState.frontPlacement
  function BattleState.frontPlacement(ex, ey, w, h, scale, ...)
    local results = packValues(innerFront(ex, ey, w, h, scale, ...))
    if texturing then
      results[1] = TEX_AX - w * scale / 2
      results[2] = TEX_AY - h * scale
    elseif nativeCartridgeBattle then
      results[1], results[2], results[3] =
        OverworldBattle.nativeCartridgeFrontPlacement(
          results[1], results[2], w, h, results[3] or scale)
    end
    return unpackValues(results, 1, results.n)
  end

  local innerDraw = BattleState.draw
  function BattleState:draw(...)
    if not runtimeLeaseActive() then return innerDraw(self, ...) end
    local shot = OverworldBattle.shot()
    -- AskName blanks the field on purpose (the nickname prompt is meant to
    -- sit on nothing); leave that one alone.
    if not shot or self.blankForAskName then
      -- nil, not false: the class default is inherited again, so a battle
      -- that loses its arena mid-fight goes back to white voids
      self.letterboxWhite = nil
      self.voxelAscendantShot = nil
      self.voxelAscendantHudSnapped = nil
      -- Kanto Ascendant's Mega overlay still feature-detects the historical
      -- staged-renderer marker.  Clear it together with the real VASC field;
      -- a stale truthy marker would incorrectly suppress the ordinary 2D
      -- Mega rear after a staged shot has genuinely gone away.
      self.dramaticShapeShot = nil
      return innerDraw(self, ...)
    end
    self.voxelAscendantShot = shot
    -- The final battle.overlay hook uses this exact receipt to decide whether
    -- the true-colour party row belongs in the classic UI canvas or was
    -- already composited into the edge HUD texture during update().
    self.voxelAscendantHudSnapped = snapped(self, shot)
    -- Compatibility marker only: the owner and every VASC/KASC wide-HUD seam
    -- continue to use voxelAscendantShot.  KASC's shared Mega renderer checks
    -- this historical field before deciding whether to paint its classic
    -- white-paper rear overlay.  Pointing it at the exact same live shot keeps
    -- all Mega forms on VASC's camera-facing billboards instead of laying a
    -- second, misplaced 2D sprite and opaque paper over the arena.
    self.dramaticShapeShot = shot
    -- The world reaches the screen through the seam a render pipeline's
    -- finished world image already uses: one window-resolution canvas,
    -- blitted a pixel to a pixel, with the 160x144 UI canvas composited over
    -- it in the classic letterbox afterwards. That is what makes the backdrop
    -- as crisp as the free-roam diorama while the pics and text stay GB art.
    local renderer = game().renderer
    if renderer and renderer.setWorldOverride then
      renderer:setWorldOverride(shot.canvas)
    end
    -- beginFrame clears the UI canvas white for an opaque state; the world is
    -- under it now, so clear it back to nothing and let it through. Safe to
    -- do here: an opaque battle is the lowest state drawn, so nothing has
    -- drawn into this canvas yet.
    love.graphics.clear(0, 0, 0, 0)
    -- the white letterbox exists so the window matches the white battle
    -- canvas; there is a world out to the window edges now
    self.letterboxWhite = false
    legacyPresentation("drawHudPanels", self)
    return withoutBackgroundFill(self, innerDraw, ...)
  end

  -- World-compatible fronts and certified full-body backs are geometry and
  -- therefore disappear from the flat pics layer. The one deliberate
  -- exception is a classic player-side 2D rear used together with STANDARD:
  -- draw that side alone in the engine's authored slot, with its feet on the
  -- textbox, while the opponent remains a world billboard.
  innerPics = BattleState.drawPicsLayer
  function BattleState:drawPicsLayer(slide, sx, sy, onlySide, skipMenuClip, ...)
    local shot = runtimeLeaseActive() and self.voxelAscendantShot
    if not shot then
      if runtimeLeaseActive()
          and self._vascNativeCartridgeFrontAnchor == true then
        local previous = nativeCartridgeBattle
        nativeCartridgeBattle = self
        local results = packValues(pcall(innerPics, self, slide, sx, sy,
                                         onlySide, skipMenuClip, ...))
        nativeCartridgeBattle = previous
        if not results[1] then error(results[2], 0) end
        return unpackValues(results, 2, results.n)
      end
      return innerPics(self, slide, sx, sy, onlySide, skipMenuClip, ...)
    end
    if OverworldBattle.playerBackPinned(self) and onlySide ~= "enemy" then
      local previous = pinnedTrainerBackSprite
      pinnedTrainerBackSprite = self.playerBackPic
      local results = packValues(pcall(innerPics, self, slide, sx, sy,
                                       "player", skipMenuClip, ...))
      pinnedTrainerBackSprite = previous
      if not results[1] then error(results[2], 0) end
      return unpackValues(results, 2, results.n)
    end
  end

  -- The battle's text box and its menus, over the frosted glass laid down for
  -- them rather than over their own white paper. The INK is Gen 1's own black
  -- and stays that way whatever is behind the glass -- the panel's tint is
  -- what earns it its contrast (see BattleHud).
  innerText = BattleState.drawTextArea
  function BattleState:drawTextArea(...)
    if not runtimeLeaseActive() or not self.voxelAscendantShot then return innerText(self, ...) end
    if snapped(self, self.voxelAscendantShot) then return end
    return withoutBoxFill(self, innerText, ...)
  end

  -- Move animations are authored against the pics' fixed slots, and a single
  -- animation reaches across both sides, so there is no per-side offset to
  -- give them. They ride the average, which is where the pair's centre went
  -- -- a few pixels at most, and it keeps a hit landing on the mon it is
  -- aimed at instead of drifting off it.
  innerAnim = BattleState.drawAnimLayer
  function BattleState:drawAnimLayer(colorized, ...)
    local shot = runtimeLeaseActive() and self.voxelAscendantShot
    if not shot then return innerAnim(self, colorized, ...) end
    if shot.pendingActors then
      -- An authored attack is positioned between two concrete deployment
      -- cards. During the actor-free replacement cover neither endpoint is
      -- committed, so drawing it would leave a projectile floating in space.
      return
    end
    -- Move animations are authored against the pics' old fixed slots, and one
    -- animation reaches across both sides, so there is no per-side offset to
    -- give them. They ride to where the PAIR went: the midpoint of the two
    -- mons' projected positions, less the midpoint of the slots they used to
    -- sit in. A hit still lands on the mon it is aimed at.
    --
    -- And they ride the pair's SEPARATION as well, because the mons
    -- themselves do. Both are geometry standing on the map, so the camera
    -- sizes them: zoom in and they grow, swing round to side-on and the two
    -- marks close up as the axis foreshortens. A layer that only slid would
    -- have held the authored 106-pixel spacing through all of it -- a beam
    -- fired between two mons that are no longer that far apart, ending in
    -- the air beside the one it was aimed at. Scaling about the same
    -- midpoint keeps every authored offset the same fraction of the gap it
    -- was authored as.
    local a = OverworldBattle.ANCHOR
    -- A pinned player-side picture stays exactly where the GB put it, so that side
    -- contributes no movement at all and the pair's centre has gone half as
    -- far as the foe's mark did.
    local px, py = shot.player[1], shot.player[2]
    if OverworldBattle.playerBackPinned(self) then
      px, py = a.player[1], a.player[2]
    end
    local cx, cy = (shot.enemy[1] + px) / 2, (shot.enemy[2] + py) / 2
    local ax = (a.enemy[1] + a.player[1]) / 2
    local ay = (a.enemy[2] + a.player[2]) / 2
    love.graphics.push()
    love.graphics.translate(cx - ax, cy - ay)
    -- Clamped, and skipped outright if the marks ever coincide: a
    -- degenerate projection must leave the effects the size they were
    -- rather than collapse them to nothing or blow them across the screen.
    local k = OverworldBattle.animScale(shot, px, py)
    if k ~= 1 then
      love.graphics.translate(ax, ay)
      love.graphics.scale(k, k)
      love.graphics.translate(-ax, -ay)
    end
    local results = packValues(pcall(innerAnim, self, colorized, ...))
    love.graphics.pop()
    if not results[1] then error(results[2], 0) end
    return unpackValues(results, 2, results.n)
  end

  -- The engine's flash has a SECOND half, and it is the one that reaches the
  -- menu. Beside the white rectangle (dropped above) the flash moves are
  -- driven by a BGP palette fade -- BGP_LIGHT and friends -- which the
  -- colorized pipeline applies in drawZonePass to the WHOLE background
  -- canvas. That canvas carries the HUD glyphs and the text box, so a fade
  -- meant for the two mons washed the menu out with them.
  --
  -- The fade is left switched on for the pics, which read it through
  -- picImage, and switched off for the zone pass alone. So the mons flash
  -- and the furniture around them does not.
  --
  -- The zone pass has a SECOND thing it paints, and this is the one that
  -- reads as the menu box flashing. A screen shake makes it fill every zone
  -- with the zone's own color 0 before it draws the offset copy -- the
  -- hardware showing empty BG in the strip the shake vacated. On a white
  -- battle field that fill is invisible; over a world it is an opaque white
  -- sheet across the whole frame, and since a shake program alternates
  -- offset and no-offset frames (SE_SHAKE_SCREEN steps dx 1, 0, 1, 0...) it
  -- switches on and off a few times a second. It is dropped: the background
  -- here is the map, so what the shake vacates should show the map.
  local innerZone = BattleState.drawZonePass
  function BattleState:drawZonePass(src, sx, sy, ...)
    if not runtimeLeaseActive() or not self.voxelAscendantShot then
      return innerZone(self, src, sx, sy, ...)
    end
    -- shadow the method on the instance for this call only; putting the
    -- field back to whatever it was (normally nil) lets the class method be
    -- found again
    local had = rawget(self, "activeBgp")
    self.activeBgp = function() return nil end
    local g = love.graphics
    local rectangle = g.rectangle
    g.rectangle = function(mode, ...)
      -- the pass draws no other rectangle; the shake still shifts the copy
      if mode == "fill" then return end
      return rectangle(mode, ...)
    end
    local results = packValues(pcall(innerZone, self, src, sx, sy, ...))
    g.rectangle = rectangle
    self.activeBgp = had
    if not results[1] then error(results[2], 0) end
    return unpackValues(results, 2, results.n)
  end

  innerHUDs = BattleState.drawHUDs
  function BattleState:drawHUDs(slide, ...)
    if not runtimeLeaseActive() or not self.voxelAscendantShot then
      return innerHUDs(self, slide, ...)
    end
    -- Normally the HUDs have already been drawn this frame, snapped out to the
    -- window's edges and composited into the world image (snapHUDs). Drawing
    -- them here as well would show each block twice, once in each place.
    if snapped(self, self.voxelAscendantShot) then return end
    -- Persistent party receipts are drawn by the final battle.overlay hook.
    -- That is after the SGB/KASC zone recolour, so red and grey remain literal.
    return innerHUDs(self, slide, ...)
  end

  local replacements = {}
  for class, before in pairs(originalMethods) do
    for key, fn in pairs(class) do
      if type(fn) == "function" and fn ~= before[key] then
        replacements[#replacements + 1] = {class=class, key=key, wrapper=fn, original=before[key]}
      end
    end
  end
  runtimeLease.detach = function()
    if runtimeLease.state ~= "retired" then return false end
    for _, row in ipairs(replacements) do
      if rawget(row.class, row.key) == row.wrapper then
        row.class[row.key] = row.original
      end
    end
    return true
  end
  BattleState.voxelAscendantBattleHook = true
  runtimeState = "installed"
  runtimeLease.state = "active"
  rawset(OverworldState, RUNTIME_LEASE_SLOT, runtimeLease)
  supported = true
  return true
end

-- Whether each HUD block is on screen this frame.
--
-- READ-ONLY duplicates of drawHUDs' own two guards, because there is no seam
-- that reports "the enemy HUD is up". A panel under a HUD that is not there
-- would be a frosted slab floating in the arena, so it is worth mirroring;
-- the worst a future engine change can do is show an empty one for a frame,
-- never break a battle.
function OverworldBattle.hudLive(battle, slide)
  local showStatus = type(battle.statusHUDVisible) ~= "function"
                     or battle:statusHUDVisible()
  local enemy = showStatus and battle.enemy and not battle.showEnemyTrainer
                and not battle.enemySendingOut
                and not battle:growInScale(battle.enemy) and slide == 0
                and not battle.introBalls and not battle.enemy.fainted
  local player = showStatus and battle.player
                 and not (battle.safari or battle.demo)
                 and not battle.showPlayerBack and slide == 0
  return enemy and true or false, player and true or false
end

-- ------- the snapped composite
--
-- The engine's own HUD layer, rendered into a texture.
--
-- One thing is falsified for the render, and it is falsified because this layer
-- never reaches the battle's zone pass -- it is composited into the world image,
-- outside the frame that pass covers. In the colorized pipeline drawHUDs leaves
-- the HP bar's fill as DMG gray for the zone pass to colour by region (#229);
-- answered false, it tints its own greens and reds instead, exactly as it does
-- on the flat path.
--
-- Shadowed on the instance for this call only, the way drawZonePass shadows
-- activeBgp: putting the field back to whatever it was (normally nil) lets the
-- class method be found again.
function OverworldBattle.hudTexture(battle, slide)
  if not (innerHUDs and battle) then return nil end
  local had = rawget(battle, "colorMode")
  battle.colorMode = function() return false end
  local ok, layer = pcall(BattleHud.layerTexture,
                          BattleScene.GB_W, BattleScene.GB_H,
                          function()
                            innerHUDs(battle, slide)
                            if hudExtrasDrawer then
                              hudExtrasDrawer(battle, slide)
                            end
                          end, "status")
  battle.colorMode = had
  return ok and layer or nil
end

function OverworldBattle.partyTexture(battle)
  if not battle then return nil end
  local ok, layer = pcall(BattleHud.layerTexture,
                          BattleScene.GB_W, BattleScene.GB_H,
                          function()
                            BattlePartyBalls.drawPersistent(battle)
                          end, "party")
  return ok and layer or nil
end

-- Keep lower battle furniture on its own transparent source. Move-select and
-- Mimic boxes begin inside the lower 48px HUD band; baking text and status
-- into one canvas duplicated TYPE/PP or move rows when that complete band was
-- snapped to the player edge. Separate canvases make the composition exact:
-- status bands contain only status/party art and each text pane is blitted
-- once at its own reviewed left/right target.
function OverworldBattle.textTexture(battle)
  if not (innerText and battle) then return nil end
  local ok, layer = pcall(BattleHud.layerTexture,
                          BattleScene.GB_W, BattleScene.GB_H,
                          function()
                            withoutBoxFill(battle, innerText)
                          end, "text")
  return ok and layer or nil
end

warnBattleHudProvider = function(provider, stage, reason)
  local id = type(provider) == "table" and provider.id or "unknown"
  local key = tostring(id) .. ":" .. tostring(stage)
  if battleHudProviderWarnings[key] then return end
  battleHudProviderWarnings[key] = true
  V.mod.log:warn("battle HUD provider %s %s failed open: %s",
                 tostring(id), tostring(stage), tostring(reason))
end

local function runHiddenBattleHudLifecycles(battle)
  if not battle then return end
  if innerHUDs then
    local slide = (battle.introSlide or 0) * 4
    local okStatus, statusReason = pcall(
      BattleHud.layerTexture, BattleScene.GB_W, BattleScene.GB_H,
      function() innerHUDs(battle, slide) end, "provider-status-lifecycle")
    if not okStatus then
      warnBattleHudProvider(battleHudProvider, "status-lifecycle", statusReason)
    end
  end
  if innerText then
    local okText, textReason = pcall(
      BattleHud.layerTexture, BattleScene.GB_W, BattleScene.GB_H,
      function() withoutBoxFill(battle, innerText) end,
      "provider-text-lifecycle")
    if not okText then
      warnBattleHudProvider(battleHudProvider, "text-lifecycle", textReason)
    end
  end
end

local function providerLayer(shot)
  local width = shot and shot.canvas and shot.canvas:getWidth() or 0
  local height = shot and shot.canvas and shot.canvas:getHeight() or 0
  if width <= 0 or height <= 0 then return nil end
  if battleHudProviderLayer and battleHudProviderLayerW == width
      and battleHudProviderLayerH == height then
    return battleHudProviderLayer
  end
  local ok, layer = pcall(love.graphics.newCanvas, width, height,
                          { dpiscale = 1 })
  if not (ok and layer) then return nil end
  pcall(layer.setFilter, layer, "nearest", "nearest")
  battleHudProviderLayer = layer
  battleHudProviderLayerW, battleHudProviderLayerH = width, height
  return layer
end

-- A full-window transparent transaction canvas is still required for strict
-- fail-open provider ownership, but clearing and blitting every pixel of that
-- canvas is not.  At 3420x2214 those two otherwise-empty passes were more
-- expensive than Oak's entire indoor voxel stage.  Providers may publish an
-- exact list of rectangles they can paint; the compositor then clears and
-- commits only those regions while retaining the same disposable-layer
-- transaction. Missing/malformed capability data deliberately falls back to
-- the historical full-canvas path.
local function providerDamageRects(provider, battle, shot)
  if type(provider) ~= "table"
      or provider.damageBoundsSchema ~= HUD_DAMAGE_BOUNDS_SCHEMA
      or type(provider.damageBounds) ~= "function"
      or not (shot and tonumber(shot.pw) and tonumber(shot.ph)) then
    return nil
  end
  local ok, bounds = pcall(provider.damageBounds, battle, shot)
  if not ok or type(bounds) ~= "table"
      or bounds.schema ~= HUD_DAMAGE_BOUNDS_SCHEMA
      or tonumber(bounds.width) ~= tonumber(shot.pw)
      or tonumber(bounds.height) ~= tonumber(shot.ph)
      or type(bounds.rects) ~= "table" then
    return nil
  end
  local width, height = math.max(1, shot.pw), math.max(1, shot.ph)
  local out = {}
  for _, rect in ipairs(bounds.rects) do
    local x = type(rect) == "table" and tonumber(rect.x or rect[1]) or nil
    local y = type(rect) == "table" and tonumber(rect.y or rect[2]) or nil
    local w = type(rect) == "table" and tonumber(rect.w or rect[3]) or nil
    local h = type(rect) == "table" and tonumber(rect.h or rect[4]) or nil
    if x and y and w and h and w > 0 and h > 0 then
      local x1 = math.max(0, math.floor(x))
      local y1 = math.max(0, math.floor(y))
      local x2 = math.min(width, math.ceil(x + w))
      local y2 = math.min(height, math.ceil(y + h))
      if x2 > x1 and y2 > y1 then
        out[#out + 1] = { x1, y1, x2 - x1, y2 - y1 }
      end
    end
  end
  if #out == 0 then return nil end
  return out
end

local function clearProviderLayer(g, layer, damage)
  g.setCanvas(layer)
  g.setBlendMode("replace", "premultiplied")
  if damage and type(g.setScissor) == "function" then
    g.setColor(0, 0, 0, 0)
    for _, rect in ipairs(damage) do
      g.setScissor(rect[1], rect[2], rect[3], rect[4])
      g.rectangle("fill", rect[1], rect[2], rect[3], rect[4])
    end
    g.setScissor()
  else
    g.clear(0, 0, 0, 0)
  end
  g.setColor(1, 1, 1, 1)
end

local function tryBattleHudProvider(provider, battle, shot)
  if not provider then return false end
  local okClaim, claimed = pcall(provider.claim, battle, shot)
  if not okClaim then
    warnBattleHudProvider(provider, "claim", claimed)
    return false
  end
  if claimed ~= true then return false end

  local layer = providerLayer(shot)
  if not layer then
    warnBattleHudProvider(provider, "canvas", "replacement layer unavailable")
    return false
  end

  -- Providers draw transactionally. A provider that paints a few pixels and
  -- then returns false/throws must leave the authoritative staged scene
  -- untouched so the standard HUD can fail open without ORAS fragments.
  local providerShot = {}
  for key, value in pairs(shot) do providerShot[key] = value end
  providerShot.canvas = layer

  local g = love.graphics
  local previousCanvas = g.getCanvas()
  local previousBlend, previousAlpha = g.getBlendMode()
  local previousScissor = type(g.getScissor) == "function"
    and { g.getScissor() } or nil
  local function restoreScissor()
    if type(g.setScissor) ~= "function" then return end
    if previousScissor and previousScissor[1] ~= nil then
      g.setScissor(previousScissor[1], previousScissor[2],
                   previousScissor[3], previousScissor[4])
    else
      g.setScissor()
    end
  end
  local pushed = false
  local presentation = battleHudPresentation()
  local preflipped = presentation.axis ~= nil
  providerShot.battleHudPresentation = presentation
  -- Gen-1 iOS presents the complete staged world canvas through a Y reflection.
  -- The ORAS provider therefore authors its final pixels in the reflected
  -- transaction layer even when the public battle receipt correctly requests
  -- no *additional* HUD reflection (axis=nil).  Its camera/damage rectangles
  -- remain in upright screen coordinates.  Applying those upright rectangles
  -- as scissors to the reflected layer commits only their narrow intersection
  -- (typically the status-card top border) and drops the rest of the HUD.
  -- Keep the proven full transparent transaction on every iOS frame until a
  -- reflected damage-rectangle schema exists. Other platforms retain the
  -- bounded damage optimization.
  local reflectedWorldCanvas = PLATFORM_OS == "iOS"
  local damage = not reflectedWorldCanvas
    and providerDamageRects(provider, battle, shot) or nil
  local afterCommit = nil
  local okDraw, didDraw = pcall(function()
    clearProviderLayer(g, layer, damage)
    g.setBlendMode("alpha")
    g.push("all")
    pushed = true
    g.origin()
    if preflipped then
      if not beginBattleHud2D(g, shot, presentation) then
        error("battle HUD presentation transform unavailable", 0)
      end
    end
    return provider.draw(battle, providerShot, {
      apiVersion = 1,
      platform = PLATFORM_OS,
      preflipped = preflipped,
      presentationAxis = presentation.axis,
      presentationReceipt = presentation,
      width = shot.pw,
      height = shot.ph,
      -- State belonging to provider pixels must not become observable while
      -- those pixels still live only on the disposable layer. A provider may
      -- register one tiny post-blit transaction; it runs only after the
      -- authoritative shot accepted the complete layer.
      afterCommit = function(callback)
        if type(callback) ~= "function" or afterCommit ~= nil then
          return false
        end
        afterCommit = callback
        return true
      end,
    })
  end)
  if pushed then pcall(g.pop) end
  if previousCanvas then g.setCanvas(previousCanvas) else g.setCanvas() end
  g.setBlendMode(previousBlend or "alpha", previousAlpha)
  g.setColor(1, 1, 1, 1)
  restoreScissor()

  if not okDraw then
    warnBattleHudProvider(provider, "draw", didDraw)
    return false
  end
  if didDraw ~= true then return false end

  local commitPushed = false
  local okCommit, commitReason = pcall(function()
    g.setCanvas(shot.canvas)
    g.push("all")
    commitPushed = true
    g.origin()
    g.setShader()
    g.setBlendMode("alpha")
    g.setColor(1, 1, 1, 1)
    if type(g.setScissor) == "function" then g.setScissor() end
    if damage and type(g.setScissor) == "function" then
      for _, rect in ipairs(damage) do
        g.setScissor(rect[1], rect[2], rect[3], rect[4])
        g.draw(layer, 0, 0)
      end
      g.setScissor()
    else
      g.draw(layer, 0, 0)
    end
  end)
  if commitPushed then pcall(g.pop) end
  if previousCanvas then g.setCanvas(previousCanvas) else g.setCanvas() end
  g.setBlendMode(previousBlend or "alpha", previousAlpha)
  g.setColor(1, 1, 1, 1)
  restoreScissor()
  if not okCommit then
    warnBattleHudProvider(provider, "commit", commitReason)
    return false
  end

  -- Publish only after the complete private layer reached the authoritative
  -- staged shot. A failed/declined provider cannot leave a false frame receipt.
  shot.battleHudPresentation = presentation

  if afterCommit then
    local okAfter, accepted = pcall(afterCommit)
    if not okAfter or accepted ~= true then
      warnBattleHudProvider(provider, "after-commit",
        okAfter and "transaction-declined" or accepted)
      -- The complete provider layer already owns the authoritative pixels.
      -- Failing open now would paint native/legacy UI over those pixels and
      -- create exactly the doubled HUD this transaction prevents. Keep pixel
      -- ownership true; the provider's internal state can reacquire on the
      -- next frame and the renderer still publishes the exact snapped owner.
    end
  end

  return true, provider.id
end

drawBattleHudProvider = function(battle, shot)
  if not (battle and shot and shot.canvas) then return false end
  local didDraw, owner = tryBattleHudProvider(battleHudProvider, battle, shot)
  if not didDraw and battleHudProvider
      and battleHudProvider.exclusive == true then
    -- The external owner deliberately chose native/standard or failed open.
    -- Do not allow VASC's default ORAS or legacy edge compositor to turn that
    -- into a different visual choice.
    return false, battleHudProvider.id, true
  end
  if not didDraw then
    didDraw, owner = tryBattleHudProvider(
      defaultBattleHudProvider, battle, shot)
  end
  if not didDraw then return false end

  -- Preserve BattleState's presentation lifecycle exactly once, but keep its
  -- pixels in private transparent layers. The provider already painted the
  -- visible replacement into the staged world canvas.
  runHiddenBattleHudLifecycles(battle)
  return true, owner
end

-- Draw both HUD blocks into the world image at the window's edges, each on its
-- own frosted panel. Returns true when the frame's HUDs are up there and the
-- in-frame draw must be skipped; false leaves the battle screen's own HUD
-- exactly as it was before any of this existed.
--
-- Both bands are blitted whether or not that side's HUD is LIVE, because a band
-- carries more than the HUD: the pokeball rows of the intro and of an enemy
-- faint, and the safari ball count, all draw in these rows and belong at the
-- same edge as the block they share it with. The panels are the ones that
-- follow hudLive -- frosted glass under nothing is a slab floating in the arena.
snapHUDs = function(battle, shot)
  -- Replacement providers commit directly to shot.canvas before notifying
  -- this public seam.  Returning true is an acknowledgement only; repainting
  -- the old bands here would create the doubled translucent/opaque HUD seen in
  -- combined VASC + KASC battles.
  if snapped(battle, shot) then return true end
  if not legacySnapIsSafe() and PLATFORM_OS ~= "iOS" then return false end
  if BattleHud.position(PLATFORM_OS, shot and shot.pw, shot and shot.ph)
      == "frame" then return false end
  if not (battle and shot and shot.canvas and (shot.scale or 0) > 0) then
    return false
  end
  local slide = (battle.introSlide or 0) * 4
  local textPlacement = OverworldBattle.textPlacements(battle, shot)
  local rects, placement = OverworldBattle.snapRects(shot, textPlacement)
  local enemy, player = legacyPresentation("hudLive", battle, slide)
  local live = {}
  if enemy then live.enemy = rects.enemy end
  if player then live.player = rects.player end
  for side, rect in pairs(OverworldBattle.partyRects(battle, slide)) do
    if rect ~= BattlePartyBalls.PERSISTENT_RECT[side] then
      live[side .. "Party"] = bandRectWorld(
        rect, OverworldBattle.HUD_BAND[side], placement[side])
    end
  end
  local partyPlacement = OverworldBattle.persistentPartyPlacements(
    battle, shot, slide, rects, placement, textPlacement)
  for _, item in ipairs(partyPlacement) do
    live[item.side .. "PersistentParty"] = item.panel
  end
  if battle.phase == "menu" and not battle.safari
      and #textPlacement == 3 then
    local first, last = textPlacement[1].target, textPlacement[3].target
    live.text = { first[1], first[2],
                  last[1] + last[3] - first[1], first[4] }
  else
    for index, item in ipairs(textPlacement) do
      live["text" .. index] = item.target
    end
  end
  local layer = legacyPresentation("hudTexture", battle, slide)
  local textLayer = #textPlacement > 0
    and OverworldBattle.textTexture(battle) or nil
  local partyLayer = #partyPlacement > 0
    and OverworldBattle.partyTexture(battle) or nil
  if not layer or (#textPlacement > 0 and not textLayer) then return false end
  if #partyPlacement > 0 and not partyLayer then return false end

  local g = love.graphics
  local prevCanvas = g.getCanvas()
  local prevBlend, prevAlpha = g.getBlendMode()
  local presentation = battleHudPresentation()
  local preflip = presentation.axis ~= nil
  local pushedTransform = false
  local ok, err = pcall(function()
    g.setCanvas(shot.canvas)
    g.setBlendMode("alpha")
    if preflip then
      g.push("transform")
      pushedTransform = true
      if not beginBattleHud2D(g, shot, presentation) then
        error("battle HUD presentation transform unavailable", 0)
      end
    end
    for _, rect in pairs(live) do
      BattleHud.panel(rect, shot, true, presentation.axis)
    end
    g.setColor(1, 1, 1, 1)
    for side, band in pairs(OverworldBattle.HUD_BAND) do
      local place = placement[side]
      local quad = g.newQuad(band[1], band[2], band[3], band[4],
                             BattleScene.GB_W, BattleScene.GB_H)
      g.draw(layer, quad, place.x + band[1] * place.scale,
             place.y, 0, place.scale, place.scale)
    end
    for _, item in ipairs(partyPlacement) do
      local source, target = item.source, item.target
      local quad = g.newQuad(source[1], source[2], source[3], source[4],
                             BattleScene.GB_W, BattleScene.GB_H)
      g.draw(partyLayer, quad, target[1], target[2], 0,
             target[3] / source[3], target[4] / source[4])
    end
    for _, item in ipairs(textPlacement) do
      local source, target = item.source, item.target
      local quad = g.newQuad(source[1], source[2], source[3], source[4],
                             BattleScene.GB_W, BattleScene.GB_H)
      g.draw(textLayer, quad, target[1], target[2], 0,
             target[3] / source[3], target[4] / source[4])
    end
    if pushedTransform then
      g.pop()
      pushedTransform = false
    end
  end)
  if pushedTransform then pcall(g.pop) end
  if prevCanvas then g.setCanvas(prevCanvas) else g.setCanvas() end
  g.setBlendMode(prevBlend or "alpha", prevAlpha)
  g.setColor(1, 1, 1, 1)
  if not ok then error(err, 0) end
  -- This compositor is itself a complete visible HUD owner. Publishing an
  -- owner is essential for cooperative KASC observers: a successful legacy
  -- fallback must not be mistaken for an unowned frame and receive a second
  -- layer of native Gender/Caught/QoL furniture.
  shot.battleHudPresentation = presentation
  markSnapped(battle, shot, true, nil, "voxel_ascendant.legacy")
  return true
end

if legacySnapIsSafe() then OverworldBattle.snapHUDs = snapHUDs end

-- Lay the frosted glass down under whichever HUD and box are about to draw,
-- and record which way the glyphs have to flip.
--
-- The panels are the fallback path only: normally the HUDs are snapped out to
-- the window's edges and their glass, and the box's, went into the world image
-- with them (snapHUDs). The VERDICT is needed either way -- the box's ink is
-- drawn here, in the GB frame, whichever path laid the glass under it.
function OverworldBattle.drawHudPanels(battle)
  local shot = battle.voxelAscendantShot
  if not shot then return end
  if snapped(battle, shot) then
    return
  end
  local slide = (battle.introSlide or 0) * 4
  local enemy, player = legacyPresentation("hudLive", battle, slide)
  local rect = OverworldBattle.HUD_RECT
  local live = {}
  if enemy then live.enemy = rect.enemy end
  if player then live.player = rect.player end
  for side, r in pairs(OverworldBattle.partyRects(battle, slide)) do
    live[side .. "Party"] = r
  end
  for key, r in pairs(legacyPresentation("textRects", battle)) do
    live[key] = r
  end
  if not next(live) then return end
  for _, r in pairs(live) do BattleHud.panel(r, shot) end
end

return OverworldBattle
