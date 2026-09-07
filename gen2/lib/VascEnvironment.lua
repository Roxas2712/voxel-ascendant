-- Current VASC environment/services wired into the standalone Gen2 owner.
-- Rendering stays in GoldVoxelBridge; this module owns lifecycle, persistence,
-- local user content and the public time/weather seams.
local C = ...
local mod = assert(C and C.mod, "Voxel Ascendant Gen2 environment: mod missing")
local V = assert(C and C.BaseV, "Voxel Ascendant Gen2 environment: renderer namespace missing")
local Camera = C and C.Camera

local M = { installed = false, errors = {} }
local liveGame = nil
local battleLifecycleOwner = "legacy-fallback"
local legacyBattleListenersInstalled = false
local legacyBattleAccepting = false
local recoveryBlockedLogic = nil
local recoveryBlockedScreen = nil
local recoveryStaleLogic = nil
local recoveryStaleScreen = nil
local recoveryPostStartCleanup = false
local recoveryRendererFinished = false
local recoveryRendererAttempted = false
local recoveryContentFinished = false
local installLegacyBattleListeners = nil
local legacyBattleListenerGeneration = 0
local legacyBattleListenerUnsubscribers = {}

local CAMERA_ORDER = {
  "full", "angle15", "angle35", "angle50", "angle75", "first", "third",
}
local CAMERA_LABEL = {
  full = "FULL", angle15 = "15", angle35 = "35", angle50 = "50",
  angle75 = "75", first = "1ST PERSON", third = "3RD PERSON",
}

local function currentCameraMode()
  local options = mod and mod.options
  if options and type(options.get) == "function" then
    local ok, value = pcall(options.get, options, "cameraMode")
    value = ok and tostring(value or ""):lower() or ""
    if value == "diorama" then return "full" end
    if CAMERA_LABEL[value] then return value end
  end
  return "full"
end

local function cameraRow()
  return {
    id = tostring(mod.id or "VOXEL_ASCENDANT"):lower() .. ":voxel_view",
    label = "VOXEL VIEW",
    value = function() return CAMERA_LABEL[currentCameraMode()] end,
    step = function(_, direction)
      local current = currentCameraMode()
      local index = 1
      for i, mode in ipairs(CAMERA_ORDER) do
        if mode == current then index = i break end
      end
      local delta = tonumber(direction) or 1
      index = ((index - 1 + delta) % #CAMERA_ORDER) + 1
      local mode = CAMERA_ORDER[index]
      if Camera and type(Camera.selectCameraMode) == "function" then
        Camera.selectCameraMode(mode, true, true)
      elseif mod.options and type(mod.options.set) == "function" then
        pcall(mod.options.set, mod.options, "cameraMode", mode)
      end
      return true
    end,
  }
end

local function get(name)
  local ok, value = pcall(V.require, name)
  if ok and type(value) == "table" then return value end
  M.errors[name] = tostring(value)
  return nil
end

local DayNight = get("DayNight")
local SkyEvents = get("SkyEvents")
local Weather = get("Weather")
local WeatherTweak = get("WeatherTweak")
local AmbientAudio = get("AmbientAudio")
local DeviceProfile = get("DeviceProfile")
local SpritePacks = get("SpritePacks")
local LocalMusic = get("LocalMusic")
local LocalSprites = get("LocalSprites")
local LocalContent = get("LocalContent")
local OverworldBattle = get("OverworldBattle")
local SpriteHooks = get("SpriteHooks")
local WeatherFootsteps = get("WeatherFootsteps")
local DayTint = get("DayTint")
local WarpPrefetch = get("WarpPrefetch")
local activeBattleOwner = nil
local activeBattleScreen = nil
local pendingBattleEndOwner = nil
local pendingBattleEndWasLogic = false
local activeRendererFinished = false
local activeRendererAttempted = false
local activeContentFinished = false
local pendingReplacementOwner = nil
local pendingReplacementScreen = nil
local pendingReplacementEnded = false
local pendingReplacementEndWasLogic = false
local pendingReplacementKind = nil
local pendingReplacementRendererReplaced = false
local deferredReplacementOwner = nil
local deferredReplacementScreen = nil
local deferredReplacementEnded = false
local deferredReplacementEndWasLogic = false
local deferredReplacementKind = nil
local deferredReplacementRendererReplaced = false

local function game()
  if type(liveGame) == "table" then return liveGame end
  local worldApi = mod and mod.world
  if worldApi and type(worldApi.game) == "function" then
    local ok, value = pcall(worldApi.game, worldApi)
    if ok and type(value) == "table" then return value end
  end
  -- Compatibility fallback for older Gen-2 hosts that exposed Game2 as a
  -- singleton.  Never prefer src.core.Game here: that is the Gen-1 owner and
  -- made Gen-2 profile persistence target the wrong save.
  local ok, Game = pcall(require, "src.core.Game2")
  return ok and type(Game) == "table" and Game.world and Game or nil
end

local function call(target, method, ...)
  local fn = target and target[method]
  if type(fn) ~= "function" then return false end
  local ok, value = pcall(fn, ...)
  if not ok then M.errors[method] = tostring(value) end
  return ok, value
end

-- Sample only the owning Gen-2 world's save-relative RTC. `ctx.hour` is the
-- exact value passed through World:timeOfDay; minute() is read from that same
-- world when available. No host wall clock and no Gen-1 singleton enters the
-- Gen-2 sky owner.
local function syncNativeDaytime(ctx, period)
  if not (DayNight and type(DayNight.syncNativeClock) == "function") then
    return false
  end
  local hour = type(ctx) == "table" and rawget(ctx, "hour") or nil
  local Game = game()
  local world = Game and (Game.world or Game.overworld)
  if hour == nil and world and type(world.hour) == "function" then
    local ok, value = pcall(world.hour, world)
    if ok then hour = value end
  end
  local minute = nil
  if world and type(world.minute) == "function" then
    local ok, value = pcall(world.minute, world)
    if ok then minute = value end
  end
  local ok, synced = pcall(
    DayNight.syncNativeClock, hour, minute, period)
  if not ok then
    M.errors["daytime.native_sync"] = tostring(synced)
    return false
  end
  return synced == true
end

-- Gen 2 emits battle.ended from its logic object before the BattleState has
-- drained faint/victory/evolution/exit presentation. The concrete screen is
-- therefore the encounter instance boundary. Two screens may deliberately
-- reuse one logic table; never equate those screens merely because their
-- `.battle` fields point at the same object.
local function sameBattleOwner(a, b)
  if a == nil or b == nil then return false end
  if rawequal(a, b) then return true end
  if type(a) == "table" and rawequal(rawget(a, "battle"), b) then
    return true
  end
  if type(b) == "table" and rawequal(rawget(b, "battle"), a) then
    return true
  end
  return false
end

local function matchesRecoveryOwner(value, logic, screen)
  if value == nil then return false end
  if screen ~= nil and type(value) == "table"
      and rawget(value, "battle") ~= nil then
    return rawequal(value, screen)
  end
  if screen ~= nil and rawequal(value, screen) then return true end
  return logic ~= nil and sameBattleOwner(value, logic)
end

local function stackContains(stack, state)
  if type(stack) ~= "table" or type(state) ~= "table" then return false end
  for _, candidate in ipairs(stack.states or {}) do
    if rawequal(candidate, state) then return true end
  end
  return false
end

local function isConcreteBattleScreen(state)
  if not (OverworldBattle
      and type(OverworldBattle.isBattleScreen) == "function") then
    return false
  end
  local ok, yes = pcall(OverworldBattle.isBattleScreen, state)
  if not ok then
    M.errors["battle.screen_owner"] = tostring(yes)
    return false
  end
  return yes == true
end

local function retireActiveBattle(expected, errorKey, replacement)
  if activeBattleOwner == nil then return false end
  if expected ~= nil
      and not rawequal(expected, activeBattleScreen)
      and not sameBattleOwner(expected, activeBattleOwner) then
    return false
  end
  local exactOwner = activeBattleScreen or activeBattleOwner
  if not activeRendererFinished and OverworldBattle
      and type(OverworldBattle.finish) == "function" then
    local finish = replacement == true
        and type(OverworldBattle.finishForReplacement) == "function"
      and OverworldBattle.finishForReplacement or OverworldBattle.finish
    activeRendererAttempted = true
    local okFinish, finished = pcall(finish, exactOwner)
    if not okFinish then
      M.errors[errorKey or "battle.finish"] = tostring(finished)
      return false
    elseif finished == false then
      return false
    end
    activeRendererFinished = true
  elseif not activeRendererFinished then
    activeRendererFinished = true
  end
  if not activeContentFinished and LocalContent
      and type(LocalContent.finish) == "function" then
    local okContent, finished = pcall(LocalContent.finish)
    if not okContent or finished == false then
      M.errors[(errorKey or "battle.finish") .. ".content"] =
        tostring(finished)
      return false
    end
    activeContentFinished = true
  elseif not activeContentFinished then
    activeContentFinished = true
  end
  activeBattleOwner = nil
  activeBattleScreen = nil
  pendingBattleEndOwner = nil
  pendingBattleEndWasLogic = false
  activeRendererFinished = false
  activeRendererAttempted = false
  activeContentFinished = false
  return true
end

local function replacementIdentityMatches(slotOwner, slotScreen,
    owner, exactScreen)
  if slotOwner == nil or owner == nil then return false end
  if exactScreen ~= nil and slotScreen ~= nil then
    return rawequal(exactScreen, slotScreen)
  end
  if exactScreen ~= nil then
    return sameBattleOwner(exactScreen, slotOwner)
  end
  if slotScreen ~= nil and type(owner) == "table"
      and rawget(owner, "battle") ~= nil then
    return rawequal(owner, slotScreen)
  end
  return sameBattleOwner(owner, slotOwner)
end

-- Returns the exact queue slot selected for this encounter. Logic-only start
-- edges may identify an unbound slot, but once a concrete screen is known its
-- identity is immutable: another screen which reuses the same battle table is
-- a distinct encounter and must be deferred instead of overwriting it.
local function rememberReplacement(owner, kind, rendererReplaced, exactScreen)
  if owner == nil then return false end
  if pendingReplacementOwner ~= nil then
    if replacementIdentityMatches(pendingReplacementOwner,
        pendingReplacementScreen, owner, exactScreen) then
      if pendingReplacementScreen == nil and exactScreen ~= nil then
        pendingReplacementScreen = exactScreen
      end
      pendingReplacementRendererReplaced =
        pendingReplacementRendererReplaced or rendererReplaced == true
      return "pending"
    end
    if deferredReplacementOwner == nil then
      local inheritLogicEnd = pendingReplacementEndWasLogic
        and sameBattleOwner(pendingReplacementOwner, owner)
      deferredReplacementOwner = owner
      deferredReplacementScreen = exactScreen
      deferredReplacementEnded = inheritLogicEnd
      deferredReplacementEndWasLogic = inheritLogicEnd
      deferredReplacementKind = kind
      deferredReplacementRendererReplaced = rendererReplaced == true
      return "deferred"
    elseif replacementIdentityMatches(deferredReplacementOwner,
        deferredReplacementScreen, owner, exactScreen) then
      if deferredReplacementScreen == nil and exactScreen ~= nil then
        deferredReplacementScreen = exactScreen
      end
      deferredReplacementRendererReplaced =
        deferredReplacementRendererReplaced or rendererReplaced == true
      return "deferred"
    end
    return false
  end
  pendingReplacementOwner = owner
  pendingReplacementScreen = exactScreen
  pendingReplacementEnded = false
  pendingReplacementEndWasLogic = false
  pendingReplacementKind = kind
  pendingReplacementRendererReplaced = rendererReplaced == true
  return "pending"
end

local function promoteDeferredReplacement()
  if pendingReplacementOwner ~= nil or deferredReplacementOwner == nil then
    return false
  end
  pendingReplacementOwner = deferredReplacementOwner
  pendingReplacementScreen = deferredReplacementScreen
  pendingReplacementEnded = deferredReplacementEnded
  pendingReplacementEndWasLogic = deferredReplacementEndWasLogic
  pendingReplacementKind = deferredReplacementKind or "active"
  pendingReplacementRendererReplaced =
    deferredReplacementRendererReplaced
  deferredReplacementOwner = nil
  deferredReplacementScreen = nil
  deferredReplacementEnded = false
  deferredReplacementEndWasLogic = false
  deferredReplacementKind = nil
  deferredReplacementRendererReplaced = false
  return true
end

local function adoptPendingReplacement()
  if pendingReplacementOwner == nil then return false end
  activeBattleOwner = pendingReplacementOwner
  activeBattleScreen = pendingReplacementScreen
  pendingBattleEndOwner = pendingReplacementEnded
      and pendingReplacementOwner or nil
  pendingBattleEndWasLogic = pendingReplacementEnded
    and pendingReplacementEndWasLogic or false
  activeRendererFinished = false
  activeRendererAttempted = false
  activeContentFinished = false
  pendingReplacementOwner = nil
  pendingReplacementScreen = nil
  pendingReplacementEnded = false
  pendingReplacementEndWasLogic = false
  pendingReplacementKind = nil
  pendingReplacementRendererReplaced = false
  return true
end

-- Battle.new emits battle.started before Gold selects music and constructs the
-- world presentation. If the Card graph fails in that synchronous start edge,
-- its own rollback necessarily runs too early to see those later latches. The
-- legacy recovery owner performs exactly one compensating terminal cleanup at
-- the failed screen's exact pop (or immediately before adopting a distinct
-- next encounter). For same-logic screen replacement, Gold has already
-- replaced the renderer session itself; only the content/music latch remains.
local function finishFailedPostStart(expected, rendererMode)
  if not recoveryPostStartCleanup then return true end
  if not recoveryRendererFinished and rendererMode ~= "replaced"
      and OverworldBattle
      and type(OverworldBattle.finish) == "function" then
    local finish = rendererMode == "replacement"
        and type(OverworldBattle.finishForReplacement) == "function"
      and OverworldBattle.finishForReplacement or OverworldBattle.finish
    recoveryRendererAttempted = true
    local okFinish, finished = pcall(finish, expected)
    if not okFinish or finished == false then
      M.errors["battle.recovery_finish"] = tostring(finished)
      return false
    end
    recoveryRendererFinished = true
  elseif not recoveryRendererFinished then
    recoveryRendererFinished = true
  end
  if not recoveryContentFinished and LocalContent
      and type(LocalContent.finish) == "function" then
    local okContent, finished = pcall(LocalContent.finish)
    if not okContent or finished == false then
      M.errors["battle.recovery_content_finish"] = tostring(finished)
      return false
    end
    recoveryContentFinished = true
  elseif not recoveryContentFinished then
    recoveryContentFinished = true
  end
  recoveryPostStartCleanup = false
  recoveryRendererFinished = false
  recoveryRendererAttempted = false
  recoveryContentFinished = false
  return true
end

local function rotateRecoveryBlocker()
  recoveryStaleLogic = recoveryBlockedLogic
  recoveryStaleScreen = recoveryBlockedScreen
  recoveryBlockedLogic = nil
  recoveryBlockedScreen = nil
  legacyBattleAccepting = true
end

local function pendingReplacementMatches(value)
  if value == nil or pendingReplacementOwner == nil then return false end
  if pendingReplacementScreen ~= nil and type(value) == "table"
      and rawget(value, "battle") ~= nil then
    return rawequal(value, pendingReplacementScreen)
  end
  return sameBattleOwner(value, pendingReplacementOwner)
end

local function deferredReplacementMatches(value)
  if value == nil or deferredReplacementOwner == nil then return false end
  if deferredReplacementScreen ~= nil and type(value) == "table"
      and rawget(value, "battle") ~= nil then
    return rawequal(value, deferredReplacementScreen)
  end
  return sameBattleOwner(value, deferredReplacementOwner)
end

local function replacementEndMatches(owner, screen, value, exactScreen)
  if owner == nil or value == nil then return false end
  if exactScreen then
    return screen ~= nil and rawequal(value, screen)
  end
  return sameBattleOwner(value, owner)
end

local function tryPendingReplacement()
  if pendingReplacementOwner == nil then return false end
  if pendingReplacementScreen ~= nil then
    -- Gold begins/replaces the renderer before pushing the concrete B screen.
    -- Even if A's renderer cleanup threw in the earlier start callback, this
    -- exact screen proves the renderer has crossed the replacement boundary.
    if pendingReplacementKind == "active"
        and (activeRendererAttempted
          or pendingReplacementRendererReplaced) then
      activeRendererFinished = true
    elseif pendingReplacementKind == "recovery"
        and (recoveryRendererAttempted
          or pendingReplacementRendererReplaced) then
      recoveryRendererFinished = true
    end
  end
  local finished = false
  if pendingReplacementKind == "active" then
    finished = retireActiveBattle(activeBattleScreen or activeBattleOwner,
      "battle.replacement_finish", true)
  elseif pendingReplacementKind == "recovery" then
    finished = finishFailedPostStart(
      recoveryBlockedScreen or recoveryBlockedLogic, "replacement")
    if finished then rotateRecoveryBlocker() end
  end
  if not finished then return false end
  local adopted = adoptPendingReplacement()
  if adopted and promoteDeferredReplacement() then
    tryPendingReplacement()
  end
  return adopted
end

local function restore(created)
  local Game = game()
  call(DayNight, "restore")
  local world = Game and (Game.world or Game.overworld)
  syncNativeDaytime(nil, world and (world.tod or world.daytime))
  call(SkyEvents, "restore")
  call(Weather, "restore")
  call(DeviceProfile, "restore", Game, created == true)
  call(SpritePacks, "restore", Game)
  call(LocalMusic, "restore", Game)
  call(LocalSprites, "restore", Game)
  call(LocalContent, "restore", Game)
end

function M.install(options)
  if M.installed then return true end
  options = type(options) == "table" and options or {}
  local installCommitted = false
  local environmentUnsubscribers = {}
  local function rollbackBattleListeners()
    legacyBattleListenerGeneration = legacyBattleListenerGeneration + 1
    for index = #legacyBattleListenerUnsubscribers, 1, -1 do
      pcall(legacyBattleListenerUnsubscribers[index])
    end
    legacyBattleListenerUnsubscribers = {}
    legacyBattleListenersInstalled = false
    legacyBattleAccepting = false
  end
  local function rollbackInstall(reason)
    installCommitted = false
    rollbackBattleListeners()
    for index = #environmentUnsubscribers, 1, -1 do
      pcall(environmentUnsubscribers[index])
    end
    environmentUnsubscribers = {}
    M.errors["environment.install"] = tostring(reason)
    return false, reason
  end
  local function subscribeService(name, callback)
    local guarded = function(...)
      if installCommitted then return callback(...) end
    end
    local ok, unsubscribe = pcall(
      mod.events.on, mod.events, name, guarded)
    if not ok or type(unsubscribe) ~= "function" then
      return false, ok and (name .. " returned no unsubscribe")
        or (name .. " subscription failed: " .. tostring(unsubscribe))
    end
    environmentUnsubscribers[#environmentUnsubscribers + 1] = unsubscribe
    return true
  end
  local requestedOwner = rawget(options, "battleLifecycleOwner")
  local suppressLegacyBattle = requestedOwner == "ascendant-card"
    or requestedOwner == "quarantined-card"
  local legacyBattleOwned = not suppressLegacyBattle
  battleLifecycleOwner = suppressLegacyBattle
    and requestedOwner or "legacy-fallback"

  call(DayTint, "install")
  call(SpriteHooks, "install", mod)
  call(LocalContent, "install", mod)
  call(LocalMusic, "install", mod)
  call(AmbientAudio, "install", mod)
  call(LocalSprites, "install", mod)

  if mod.events and type(mod.events.on) == "function" then
    -- The RC11 Card graph is the sole battle mutation owner when its complete
    -- provider/router/lifecycle activation succeeded.  If it did not, retain
    -- this proven listener set verbatim as the startup fallback.  Environment,
    -- save, weather and world-step services remain installed in either case.
    installLegacyBattleListeners = function(acceptImmediately)
      if legacyBattleListenersInstalled then
        if acceptImmediately == true then
          legacyBattleAccepting = true
          recoveryBlockedLogic = nil
          recoveryBlockedScreen = nil
          recoveryStaleLogic = nil
          recoveryStaleScreen = nil
        end
        return true
      end
      local attempt = legacyBattleListenerGeneration + 1
      local subscriptions = {}
      local subscriptionError = nil
      local function subscribe(name, callback)
        if subscriptionError ~= nil then return end
        local guarded = function(...)
          if installCommitted and legacyBattleListenersInstalled
              and legacyBattleListenerGeneration == attempt then
            return callback(...)
          end
        end
        local ok, unsubscribe = pcall(
          mod.events.on, mod.events, name, guarded)
        if not ok or type(unsubscribe) ~= "function" then
          subscriptionError = ok
              and (name .. " returned no unsubscribe")
            or (name .. " subscription failed: " .. tostring(unsubscribe))
          return
        end
        subscriptions[#subscriptions + 1] = unsubscribe
      end
      subscribe("battle.started", function(payload)
      local incoming = type(payload) == "table"
        and (rawget(payload, "screen") or rawget(payload, "battle")) or nil
      if matchesRecoveryOwner(incoming,
          recoveryStaleLogic, recoveryStaleScreen) then
        return
      end
      if not legacyBattleAccepting then
        if incoming == nil then return end
        if matchesRecoveryOwner(incoming,
            recoveryBlockedLogic, recoveryBlockedScreen) then
          return
        end
        -- The first exact new encounter after a clean Card teardown becomes
        -- the legacy owner. Delayed end/pop edges from the failed encounter
        -- cannot match its different logic/screen identity.
        rememberReplacement(incoming, "recovery")
        tryPendingReplacement()
        return
      end
      -- Scripted/replacement encounters are allowed to start before the
      -- preceding battle.ended event is delivered. Retire the exact previous
      -- renderer and its music/content receipt before adopting the new owner;
      -- a later stale end event is then harmless by construction.
      if activeBattleOwner ~= nil and incoming ~= nil
          and not sameBattleOwner(activeBattleOwner, incoming) then
        rememberReplacement(incoming, "active")
        tryPendingReplacement()
      elseif activeBattleOwner == nil then
        activeBattleOwner = incoming
        activeBattleScreen = nil
        pendingBattleEndOwner = nil
        pendingBattleEndWasLogic = false
        activeRendererFinished = false
        activeRendererAttempted = false
        activeContentFinished = false
      end
    end)
      subscribe("battle.ended", function(payload)
      local expected = type(payload) == "table"
        and (rawget(payload, "screen") or rawget(payload, "battle")) or nil
      local exactScreen = type(expected) == "table"
        and isConcreteBattleScreen(expected)
      local pendingMatches = replacementEndMatches(
        pendingReplacementOwner, pendingReplacementScreen,
        expected, exactScreen)
      local deferredMatches = replacementEndMatches(
        deferredReplacementOwner, deferredReplacementScreen,
        expected, exactScreen)
      if pendingMatches or deferredMatches then
        -- A concrete screen end belongs to exactly one queue slot. A
        -- logic-only end cannot distinguish queued screens that deliberately
        -- reuse the same battle table, so latch every matching slot; these are
        -- nonterminal latches and still require each exact screen boundary.
        if pendingMatches then
          pendingReplacementEnded = true
          pendingReplacementEndWasLogic =
            pendingReplacementEndWasLogic or not exactScreen
        end
        if deferredMatches and not (exactScreen and pendingMatches) then
          deferredReplacementEnded = true
          deferredReplacementEndWasLogic =
            deferredReplacementEndWasLogic or not exactScreen
        end
        return
      end
      local belongsToActive = activeBattleOwner ~= nil
        and expected ~= nil and (exactScreen and activeBattleScreen ~= nil
          and rawequal(expected, activeBattleScreen)
          or not exactScreen and sameBattleOwner(activeBattleOwner, expected))
      if matchesRecoveryOwner(expected,
          recoveryStaleLogic, recoveryStaleScreen)
          and not belongsToActive then return end
      if not legacyBattleAccepting then return end
      -- A delayed end event from the preceding encounter must not clear the
      -- newly selected provider/PresetRuntime/LocalMusic song. Gen 2 may bind
      -- the concrete screen or the exact logic battle; accept either only when
      -- it agrees with the most recent battle.started owner.
      if activeBattleOwner ~= nil and expected ~= nil then
        if exactScreen then
          if activeBattleScreen == nil
              or not rawequal(expected, activeBattleScreen) then
            return
          end
        elseif not exactScreen
            and not sameBattleOwner(activeBattleOwner, expected) then
          return
        end
      end
      -- A terminal edge without a previously accepted start is stale or
      -- malformed. Never synthesize ownership from it: doing so made a late
      -- duplicate end re-arm cleanup after the exact screen had already left.
      if activeBattleOwner == nil then return end
      -- Logic completion is only a latch. The exact BattleState remains the
      -- visible owner until StateStack emits screen.popped after its queued
      -- faint/victory/evolution/exit frames have completed.
      pendingBattleEndOwner = expected or activeBattleOwner
      pendingBattleEndWasLogic = not exactScreen
    end)
      subscribe("screen.pushed", function(payload)
      local state = type(payload) == "table"
        and rawget(payload, "state") or nil
      if type(state) == "table" and isConcreteBattleScreen(state)
          and pendingReplacementMatches(state) then
        pendingReplacementScreen = state
        tryPendingReplacement()
        return
      elseif type(state) == "table" and isConcreteBattleScreen(state)
          and deferredReplacementMatches(state) then
        deferredReplacementScreen = state
        tryPendingReplacement()
        return
      end
      if matchesRecoveryOwner(state,
          recoveryStaleLogic, recoveryStaleScreen) then return end
      if not legacyBattleAccepting then
        if type(state) ~= "table" or not isConcreteBattleScreen(state)
            or recoveryBlockedLogic == nil
            or not sameBattleOwner(state, recoveryBlockedLogic) then
          return
        end
        if recoveryBlockedScreen == nil then
          -- A start failure may occur before its concrete screen was known.
          -- The first matching screen completes the failed tombstone only.
          recoveryBlockedScreen = state
          return
        end
        if rawequal(state, recoveryBlockedScreen) then return end
        -- Some recovery hosts reuse one logic table for a new BattleState.
        -- A different exact screen is therefore the next presentation owner,
        -- even though its logic identity matches the failed encounter.
        rememberReplacement(rawget(state, "battle") or state,
          "recovery", true, state)
        tryPendingReplacement()
        return
      end
      -- Once the failed exact screen has retired, a later BattleState may
      -- legitimately reuse its logic table. Its logic-only start is
      -- indistinguishable from a delayed failed edge, so keep that edge inert
      -- and adopt only this different concrete screen identity.
      if legacyBattleAccepting and activeBattleOwner == nil
          and type(state) == "table" and isConcreteBattleScreen(state)
          and recoveryStaleLogic ~= nil
          and sameBattleOwner(state, recoveryStaleLogic)
          and (recoveryStaleScreen == nil
            or not rawequal(state, recoveryStaleScreen)) then
        activeBattleOwner = rawget(state, "battle") or state
        activeBattleScreen = state
        pendingBattleEndOwner = nil
        pendingBattleEndWasLogic = false
        activeRendererFinished = false
        activeRendererAttempted = false
        activeContentFinished = false
        return
      end
      if type(state) ~= "table" or activeBattleOwner == nil
          or not isConcreteBattleScreen(state)
          or not sameBattleOwner(state, activeBattleOwner) then
        return
      end
      if activeBattleScreen ~= nil
          and not rawequal(activeBattleScreen, state) then
        -- A new concrete BattleState is a new presentation instance even if a
        -- recovery driver reuses the same Gen-2 logic table.
        local inheritEndPending = pendingBattleEndWasLogic
        local slot = rememberReplacement(
          rawget(state, "battle") or state, "active", true, state)
        if slot == "pending" then
          pendingReplacementEnded = pendingReplacementEnded
            or inheritEndPending
          pendingReplacementEndWasLogic =
            pendingReplacementEndWasLogic or inheritEndPending
        elseif slot == "deferred" then
          deferredReplacementEnded = deferredReplacementEnded
            or inheritEndPending
          deferredReplacementEndWasLogic =
            deferredReplacementEndWasLogic or inheritEndPending
        end
        tryPendingReplacement()
        return
      end
      activeBattleScreen = state
    end)
      subscribe("screen.popped", function(payload)
      local state = type(payload) == "table"
        and rawget(payload, "state") or nil
      if type(state) == "table" and isConcreteBattleScreen(state)
          and pendingReplacementMatches(state) then
        pendingReplacementScreen = state
        pendingReplacementEnded = true
        if tryPendingReplacement()
            and pendingReplacementOwner == nil
            and rawequal(activeBattleScreen, state) then
          if not retireActiveBattle(
              state, "battle.pending_replacement_pop") then
            pendingBattleEndOwner = activeBattleOwner
            pendingBattleEndWasLogic = false
          end
        end
        return
      elseif type(state) == "table" and isConcreteBattleScreen(state)
          and deferredReplacementMatches(state) then
        deferredReplacementScreen = state
        deferredReplacementEnded = true
        tryPendingReplacement()
        return
      end
      if matchesRecoveryOwner(state,
          recoveryStaleLogic, recoveryStaleScreen) then
        -- Keep the exact failed tombstone. A duplicate pop must not make a
        -- delayed logic-only start look new; a genuinely reused logic table is
        -- admitted above only by a different exact BattleState.
        return
      end
      if not legacyBattleAccepting then
        if type(state) == "table" and isConcreteBattleScreen(state)
            and recoveryBlockedScreen == nil
            and recoveryBlockedLogic ~= nil
            and sameBattleOwner(state, recoveryBlockedLogic) then
          recoveryBlockedScreen = state
        end
        if recoveryBlockedScreen ~= nil
            and rawequal(state, recoveryBlockedScreen) then
          if pendingReplacementKind == "recovery" then
            tryPendingReplacement()
          elseif finishFailedPostStart(state) then
              rotateRecoveryBlocker()
          end
          return
        end
        -- Keep an incomplete failed identity blocked until its exact screen
        -- boundary or a provably distinct start arrives.
        return
      end
      if type(state) ~= "table" or activeBattleOwner == nil then return end
      if activeBattleScreen ~= nil then
        if not rawequal(state, activeBattleScreen) then return end
      elseif not isConcreteBattleScreen(state)
          or not sameBattleOwner(state, activeBattleOwner) then
        return
      end
        if pendingReplacementKind == "active" then
          tryPendingReplacement()
        elseif not retireActiveBattle(state, "battle.screen_finish") then
          pendingBattleEndOwner = activeBattleOwner
          pendingBattleEndWasLogic = false
        end
      end)
      if subscriptionError ~= nil then
        -- Publish nothing until the complete listener set exists. Reverse all
        -- successful registrations; the generation guard also makes a hostile
        -- or failed unsubscriber inert immediately.
        legacyBattleListenerGeneration = attempt + 1
        for index = #subscriptions, 1, -1 do
          pcall(subscriptions[index])
        end
        legacyBattleListenerUnsubscribers = {}
        legacyBattleListenersInstalled = false
        legacyBattleAccepting = false
        M.errors["battle.listener_install"] = subscriptionError
        return false, subscriptionError
      end
      legacyBattleListenerUnsubscribers = subscriptions
      legacyBattleListenerGeneration = attempt
      legacyBattleListenersInstalled = true
      legacyBattleAccepting = acceptImmediately == true
      return true
    end
    local okService, serviceReason = subscribeService("save.writing", function()
      call(DayNight, "store")
      call(SkyEvents, "store")
      call(Weather, "store")
    end)
    if not okService then return rollbackInstall(serviceReason) end
    okService, serviceReason = subscribeService(
      "save.loaded", function() restore(false) end)
    if not okService then return rollbackInstall(serviceReason) end
    okService, serviceReason = subscribeService(
      "save.created", function() restore(true) end)
    if not okService then return rollbackInstall(serviceReason) end
    okService, serviceReason = subscribeService("game.ready", function(payload)
      local payloadGame = type(payload) == "table"
        and rawget(payload, "game") or nil
      if type(payloadGame) == "table" then
        liveGame = payloadGame
      end
      local Game = game()
      call(WarpPrefetch, "install", Game)
      restore(false)
      if Game and Game.data then call(LocalSprites, "writeInventory", Game.data) end
    end)
    if not okService then return rollbackInstall(serviceReason) end
    okService, serviceReason = subscribeService("world.stepped", function()
      local Game = game()
      local world = Game and (Game.world or Game.overworld)
      local map = world and world.map
      local mode = Weather and type(Weather.mode) == "function"
                   and Weather.mode(map) or "clear"
      local amount = WeatherTweak
                     and type(WeatherTweak.groundAmount) == "function"
                     and WeatherTweak.groundAmount(map, mode, true) or 1
      call(WeatherFootsteps, "onStep", Game, mode, amount)
      if legacyBattleListenersInstalled and pendingReplacementOwner ~= nil then
        tryPendingReplacement()
      elseif legacyBattleListenersInstalled and not legacyBattleAccepting
          and recoveryPostStartCleanup and recoveryBlockedScreen ~= nil
          and not stackContains(Game and Game.stack, recoveryBlockedScreen) then
        if finishFailedPostStart(recoveryBlockedScreen) then
          rotateRecoveryBlocker()
        end
      end
      -- Recovery fallback for a host that removed the exact screen without
      -- delivering screen.popped. Never act while that screen remains on the
      -- stack, and never let a stale logic-end event select a newer screen.
      if legacyBattleListenersInstalled
          and legacyBattleAccepting
          and pendingReplacementOwner == nil
          and pendingBattleEndOwner ~= nil and activeBattleOwner ~= nil
          and activeBattleScreen ~= nil
          and not stackContains(Game and Game.stack, activeBattleScreen) then
        retireActiveBattle(activeBattleScreen,
          "battle.stack_watchdog")
      end
    end)
    if not okService then return rollbackInstall(serviceReason) end
  end

  if mod.hooks and type(mod.hooks.wrap) == "function" and DayNight then
    local okHook, unsubscribe = pcall(
      mod.hooks.wrap, mod.hooks, "world.tod", function(next, tod, ctx)
      if not installCommitted then return next(tod, ctx) end
      local out = next(tod, ctx)
      syncNativeDaytime(ctx, out)
      if out ~= tod then return out end
      if type(DayNight.isNative) == "function" and DayNight.isNative() then
        return out
      end
      if type(DayNight.gen2Tod) == "function" then
        return DayNight.gen2Tod()
      end
      return DayNight.tod()
    end)
    if not okHook then
      return rollbackInstall("world.tod hook failed: " .. tostring(unsubscribe))
    end
    if type(unsubscribe) == "function" then
      environmentUnsubscribers[#environmentUnsubscribers + 1] = unsubscribe
    end
  end

  if legacyBattleOwned then
    local installed, reason = installLegacyBattleListeners(true)
    if installed ~= true then return rollbackInstall(reason) end
  end

  installCommitted = true
  M.installed = true
  return true
end

-- A Card graph which failed after battle.started cannot hand the current
-- encounter to listeners that missed its committed edges. Arm the proven
-- listener set with an exact blocker; it skips that encounter and accepts only
-- the next distinct battle.started owner. This keeps later LocalContent/music
-- latches exact-once without introducing parallel ownership.
function M.armLegacyBattleRecovery(failedEncounter)
  if M.installed ~= true
      or type(installLegacyBattleListeners) ~= "function" then
    return false, "VASC environment is not installed"
  end
  failedEncounter = type(failedEncounter) == "table"
    and failedEncounter or {}
  local logic = rawget(failedEncounter, "logic")
  local screen = rawget(failedEncounter, "screen")
  if logic == nil and screen == nil then
    return false, "failed Gen2 encounter identity is unavailable"
  end
  recoveryBlockedLogic = logic
    or (type(screen) == "table" and rawget(screen, "battle")) or nil
  recoveryBlockedScreen = screen
  recoveryStaleLogic = nil
  recoveryStaleScreen = nil
  recoveryPostStartCleanup = rawget(failedEncounter, "phase") == "start"
    or rawget(failedEncounter, "postStartCleanup") == true
  recoveryRendererFinished = false
  recoveryRendererAttempted = false
  recoveryContentFinished = false
  pendingReplacementOwner = nil
  pendingReplacementScreen = nil
  pendingReplacementEnded = false
  pendingReplacementEndWasLogic = false
  pendingReplacementKind = nil
  pendingReplacementRendererReplaced = false
  deferredReplacementOwner = nil
  deferredReplacementScreen = nil
  deferredReplacementEnded = false
  deferredReplacementEndWasLogic = false
  deferredReplacementKind = nil
  deferredReplacementRendererReplaced = false
  legacyBattleAccepting = false
  battleLifecycleOwner = "legacy-recovery"
  local installed, reason = installLegacyBattleListeners(false)
  if installed ~= true then
    recoveryPostStartCleanup = false
    recoveryRendererFinished = false
    recoveryRendererAttempted = false
    recoveryContentFinished = false
    recoveryBlockedLogic = nil
    recoveryBlockedScreen = nil
    battleLifecycleOwner = "quarantined-card"
    return false, reason
  end
  return true
end

-- Consumed by the isolated Voxel Ascendant hub. Gold/Silver/Crystal's native
-- OPTIONS screen stays untouched and therefore remains edition-authentic.
function M.menuRows()
  local rows = { cameraRow() }
  if LocalContent and type(LocalContent.row) == "function" then
    rows[#rows + 1] = LocalContent.row(mod)
  end
  return rows
end

M.cameraRow = cameraRow

function M.status()
  return {
    installed = M.installed,
    errors = M.errors,
    battleLifecycleOwner = battleLifecycleOwner,
    legacyBattleListenersInstalled = legacyBattleListenersInstalled,
    legacyBattleAccepting = legacyBattleAccepting,
    recoveryArmed = legacyBattleListenersInstalled
      and not legacyBattleAccepting,
    postStartCleanupPending = recoveryPostStartCleanup,
    battleActive = activeBattleOwner ~= nil,
    battleScreenBound = activeBattleScreen ~= nil,
    battleEndPending = pendingBattleEndOwner ~= nil,
    replacementPending = pendingReplacementOwner ~= nil,
    replacementScreenBound = pendingReplacementScreen ~= nil,
    replacementEndPending = pendingReplacementEnded,
    deferredReplacementPending = deferredReplacementOwner ~= nil,
    deferredReplacementScreenBound = deferredReplacementScreen ~= nil,
    deferredReplacementEndPending = deferredReplacementEnded,
  }
end

M.modules = {
  DayNight = DayNight, SkyEvents = SkyEvents, Weather = Weather,
  WeatherTweak = WeatherTweak, AmbientAudio = AmbientAudio,
  DeviceProfile = DeviceProfile, SpritePacks = SpritePacks,
  LocalMusic = LocalMusic, LocalSprites = LocalSprites,
  LocalContent = LocalContent, OverworldBattle = OverworldBattle,
}

return M
