-- Gen-2 battle Card graph bootstrap.
--
-- This module is the only composition root which may join Gold's engine event
-- surface, the shared generation-neutral Card Core and the transitional
-- OverworldBattle renderer.  The public result exposes receipts/health only;
-- raw logic tables, BattleState screens, renderer controls and Registry
-- mutation authority stay private here.

local V = ...
assert(V and type(V.require) == "function",
  "Gen2BattleCardHost needs V.require")

local Contracts = V.require("core/AscendantContracts")
local Registry = V.require("core/AscendantCardRegistry")
local PublicHost = V.require("core/AscendantCardHost")
local LifecycleModule = V.require("adapters/gen2/Gen2BattleLifecycle")
local RendererModule = V.require("adapters/gen2/Gen2BattleRenderer")
local DefaultCard = V.require(
  "cards/battle_router/Gen2DefaultBattleProviderCard")
local RouterCard = V.require("cards/battle_router/Gen2BattleRouterCard")
local LifecycleCard = V.require("cards/battle_router/Gen2BattleLifecycleCard")

local M = {
  installed=false,
  active=false,
  state="unavailable",
  fallbackSafe=true,
  recoveryActivator=nil,
  recoveryArmed=false,
  failedEncounter=nil,
  lastError=nil,
  runtime=nil,
  statusSerial=0,
  statusObservers={},
}

local function safeText(value, fallback)
  if type(value) == "string" then return value end
  if value == nil then return fallback or "nil" end
  local ok, text = pcall(tostring, value)
  if ok and type(text) == "string" then return text end
  return fallback or ("<unprintable-%s>"):format(type(value))
end

local function stackContains(stack, state)
  if type(stack) ~= "table" or type(state) ~= "table" then return false end
  for _, candidate in ipairs(stack.states or {}) do
    if rawequal(candidate, state) then return true end
  end
  return false
end

local function currentGame(mod)
  if type(mod) == "table" and type(mod.game) == "table" then
    return mod.game
  end
  if type(V.game) == "table" then return V.game end
  local world = mod and mod.world
  if world and type(world.game) == "table" then
    return world.game
  end
  if world and type(world.game) == "function" then
    local ok, game = pcall(world.game, world)
    if ok and type(game) == "table" then return game end
  end
  local ok, Game = pcall(require, "src.core.Game2")
  if ok and type(Game) == "table" then return Game end
  return nil
end

local joinErrors

local function armBoundRecovery(reason, failedEncounter)
  if type(M.recoveryActivator) ~= "function" then
    return nil, "Gen2 post-failure recovery owner is not bound"
  end
  local ok, value, detail = pcall(M.recoveryActivator,
    failedEncounter, reason)
  if not ok or value ~= true then
    return false, safeText(ok and detail or value,
      "Gen2 post-failure recovery activation failed")
  end
  return true
end

local function errorReport(report)
  local messages = {}
  for _, failure in ipairs(type(report) == "table"
      and type(report.errors) == "table" and report.errors or {}) do
    messages[#messages + 1] = safeText(failure.id, "unknown") .. ": "
      .. safeText(failure.error, "teardown failed")
  end
  return #messages > 0 and table.concat(messages, "; ") or nil
end

joinErrors = function(...)
  local messages = {}
  for index = 1, select("#", ...) do
    local value = select(index, ...)
    if type(value) == "string" and value ~= "" then
      messages[#messages + 1] = value
    end
  end
  return #messages > 0 and table.concat(messages, "; ") or nil
end

local function publicHealth(runtime)
  if type(runtime) ~= "table" or type(runtime.registry) ~= "table" then
    return {
      schema="ascendant.compat-status/v1",
      apiVersion=1,
      generation=2,
      ok=false,
      state=M.state,
      fallbackSafe=M.fallbackSafe == true,
      recoveryArmed=M.recoveryArmed == true,
      error=M.lastError,
    }
  end
  local lifecycle = runtime.registry:health(LifecycleCard.ID, {
    generation=2, host="VOXEL_ASCENDANT", public=true,
  })
  local router = runtime.registry:health(RouterCard.ID, {
    generation=2, host="VOXEL_ASCENDANT", public=true,
  })
  local defaultProvider = runtime.registry:health(DefaultCard.ID, {
    generation=2, host="VOXEL_ASCENDANT", public=true,
  })
  local rendererOK, renderer = pcall(runtime.renderer.health)
  if not rendererOK or type(renderer) ~= "table" then
    renderer = {
      schema="ascendant.compat-status/v1",
      apiVersion=1,
      generation=2,
      ok=false,
      state="error",
      error=safeText(renderer, "renderer health failed"),
    }
  end
  local lifecycleDetail = lifecycle and lifecycle.detail or nil
  return {
    schema="ascendant.compat-status/v1",
    apiVersion=1,
    generation=2,
    ok=M.active == true
      and lifecycle and lifecycle.ok == true
      and router and router.ok == true
      and defaultProvider and defaultProvider.ok == true
      and renderer.ok == true,
    state=M.state,
    fallbackSafe=M.fallbackSafe == true,
    recoveryArmed=M.recoveryArmed == true,
    error=M.lastError,
    lifecycle=lifecycle,
    providerRouter=router,
    defaultProvider=defaultProvider,
    transitionalRenderer=renderer,
    movePresentationOwner="animForMove",
    terminalOwner="exact-screen-pop-or-watchdog",
    selectedProvider=lifecycleDetail and lifecycleDetail.lifecycle
      and lifecycleDetail.lifecycle.active
      and lifecycleDetail.lifecycle.active.provider or nil,
  }
end

local function notifyStatus()
  local status = publicHealth(M.runtime)
  for _, entry in pairs(M.statusObservers) do
    if entry.live == true then pcall(entry.callback, status) end
  end
end

local function retireRuntime(runtime, reason)
  if type(runtime) ~= "table" then return true end
  if runtime.lifecycle and type(runtime.lifecycle.canCleanup) == "function" then
    local ready, readyReason = runtime.lifecycle:canCleanup()
    if ready ~= true then
      return false, safeText(readyReason,
        "Gen2 lifecycle cleanup preflight declined"), true
    end
  end
  local report = runtime.registry and runtime.registry:deactivateAll(
    { generation=2, host="VOXEL_ASCENDANT", teardown=true },
    reason or "Gen2-battle-card-host-retired") or nil
  local failure = errorReport(report)
  if failure ~= nil then
    -- Registry/Card teardown owns provider and engine-listener retirement. If
    -- that transaction did not commit, do not continue into the lower renderer
    -- or adapter layers and create a half-retired graph.
    return false, failure
  end
  local rendererOK, rendererReason = true, nil
  if runtime.renderer and type(runtime.renderer.retire) == "function" then
    local called, value, detail = pcall(runtime.renderer.retire,
      reason or "Gen2-battle-card-host-retired")
    rendererOK = called and value ~= false and value ~= nil
    if not rendererOK then
      rendererReason = safeText(called and detail or value,
        "renderer retirement failed")
    end
  end
  local lifecycleOK, lifecycleReason = true, nil
  if runtime.lifecycle and type(runtime.lifecycle.retire) == "function" then
    local called, value, detail = pcall(runtime.lifecycle.retire,
      runtime.lifecycle)
    lifecycleOK = called and value ~= false and value ~= nil
    if not lifecycleOK then
      lifecycleReason = safeText(called and detail or value,
        "lifecycle retirement failed")
    end
  end
  if not rendererOK or not lifecycleOK then
    return false, joinErrors(rendererReason, lifecycleReason)
  end
  return true
end

local function failInstall(runtime, reason, teardownReason)
  local message = safeText(reason, "Gen2 Card host install failed")
  local retired, retireReason = retireRuntime(runtime, teardownReason)
  M.installed = true
  M.active = false
  if retired == true then
    M.state = "legacy-fallback"
    M.fallbackSafe = true
    M.runtime = nil
    M.lastError = message
  else
    M.state = "rollback_pending"
    M.fallbackSafe = false
    M.runtime = runtime
    M.lastError = joinErrors(message,
      "Card teardown incomplete: "
        .. safeText(retireReason, "unknown cleanup failure"))
  end
  return false, M.lastError
end

function M.install(options)
  if M.installed then return M.active, M.lastError end
  options = type(options) == "table" and options or {}
  local mod = options.mod or V.mod
  if type(mod) ~= "table" or type(mod.events) ~= "table" then
    M.lastError = "Gen2 battle Card host needs the mod event surface"
    return false, M.lastError
  end

  local OverworldBattle = V.require("OverworldBattle")
  local LocalContent = V.require("LocalContent")
  local PresetRuntime = V.require("PresetRuntime")
  if type(OverworldBattle) ~= "table"
      or type(OverworldBattle.ensure) ~= "function"
      or type(OverworldBattle.finish) ~= "function"
      or type(OverworldBattle.finishForReplacement) ~= "function"
      or type(OverworldBattle.invalidate) ~= "function"
      or type(OverworldBattle.isBattleScreen) ~= "function"
      or type(OverworldBattle.capturePresentationPlan) ~= "function"
      or type(OverworldBattle.arena) ~= "function"
      or type(OverworldBattle.bindPresetArenaBackdrop) ~= "function" then
    M.lastError = "Gen2 OverworldBattle boundary is incomplete"
    return false, M.lastError
  end
  if type(LocalContent) ~= "table"
      or type(LocalContent.finish) ~= "function" then
    M.lastError = "Gen2 LocalContent cleanup boundary is incomplete"
    return false, M.lastError
  end
  if type(PresetRuntime) ~= "table"
      or type(PresetRuntime.status) ~= "function"
      or type(PresetRuntime.resolveArenaBackdrop) ~= "function"
      or type(PresetRuntime.finishArenaBackdrop) ~= "function" then
    M.lastError = "Gen2 preset backdrop boundary is incomplete"
    return false, M.lastError
  end

  local lifecycle = LifecycleModule.new({
    isBattleScreen=function(screen)
      local ok, value = pcall(OverworldBattle.isBattleScreen, screen)
      return ok and value == true
    end,
  })

  -- Both provider families own their own exact-once tombstones.  DEFAULT also
  -- retires the historical nativeOnly OverworldBattle latch which is created
  -- earlier by Gold's pushBattle hook; the DEFAULT Card itself never creates
  -- or exposes that bridge.  A second idempotent finish from the transitional
  -- adapter is accepted as success.
  local function finishContent(owner, reason, receipt)
    local current = lifecycle:current(owner)
    local expected = current and (current.screen or current.logic) or nil
    if type(receipt) == "table" and receipt.provider == "DEFAULT"
        and expected ~= nil
        -- Gold has already begun renderer B before screen.pushed(B) exposes a
        -- same-logic concrete-screen replacement to this lifecycle. A's
        -- screen still points at B's reused logic, so finishing A here would
        -- terminate B. The DEFAULT Card owns only A's remaining local content
        -- on this presentation-only edge.
        and reason ~= "same-logic-screen-replaced" then
      local replacement = reason == "battle-logic-replaced"
      local finish = replacement and OverworldBattle.finishForReplacement
        or OverworldBattle.finish
      local ok, value = pcall(finish, expected)
      if not ok or value == false then
        return false, "Gen2 native renderer cleanup failed: "
          .. safeText(value, "exact owner rejected")
      end
    end
    -- The deterministic choice is owned by the lifecycle's opaque exact
    -- battle owner, not by a Pokemon deployment.  Drop only that receipt at
    -- this owner's successful terminal edge; switches never enter here.
    pcall(PresetRuntime.finishArenaBackdrop, owner)
    local ok, value = pcall(LocalContent.finish)
    if not ok or value == false then
      return false, "Gen2 local content cleanup failed: "
        .. safeText(value, "cleanup rejected")
    end
    return true
  end

  local PRESET_BACKGROUND_KINDS = {
    wild=true, trainer=true, rival=true, gym=true, elite4=true,
    champion=true, special=true,
  }

  -- Optional ARENA content binds only after OverworldBattle has an exact
  -- session.  Returning false means the adapter may retry on the concrete
  -- BattleState bind edge; every resolved nil is deliberately latched as the
  -- unchanged authored/portable fallback for this battle token.
  local function bindArenaBackdrop(owner, receipt)
    if type(receipt) ~= "table" or receipt.provider ~= "ARENA" then
      return true
    end
    local arena = OverworldBattle.arena()
    if type(arena) ~= "table" or arena.presentationMode ~= "ARENA"
        or type(arena.map) ~= "table" or arena.map.id == nil then
      return false
    end
    local status = PresetRuntime.status()
    local logic = receipt.logic
    if type(status) ~= "table" or status.valid ~= true
        or type(status.generation) ~= "string"
        or type(status.game) ~= "string" or type(logic) ~= "table" then
      return OverworldBattle.bindPresetArenaBackdrop(
        receipt.screen or logic, nil)
    end
    local context = {
      presentationMode="ARENA",
      battleToken=receipt.battleToken,
      generation=status.generation,
      game=status.game,
      route_or_map=tostring(arena.map.id),
      -- Gen-2 BattleArena entries are placement contracts.  The established
      -- portable stage has no authored bitmap, so v1 ADD is the honest lane;
      -- REPLACE therefore fails closed in the shared resolver.
      authoredBackdropExists=false,
    }
    local kind = type(logic.kind) == "string" and logic.kind:lower() or nil
    if kind == nil then
      if logic.wild == true then
        kind = "wild"
      elseif type(logic.trainer) == "table" then
        kind = "trainer"
      end
    end
    if PRESET_BACKGROUND_KINDS[kind] then context.battle_kind = kind end
    local trainer = type(logic.trainer) == "table" and logic.trainer or nil
    local trainerId = logic.trainerId or (trainer
      and (trainer.classId or trainer.class or trainer.id) or nil)
    if type(trainerId) == "string" and trainerId ~= "" then
      context.trainer_id = trainerId
    end
    local battleId = logic.battleId or logic.encounterId
    if type(battleId) == "string" and battleId ~= "" then
      context.battle_id = battleId
    end
    local ok, choice = pcall(
      PresetRuntime.resolveArenaBackdrop, owner, context)
    if not ok or type(choice) ~= "table" then choice = nil end
    return OverworldBattle.bindPresetArenaBackdrop(
      receipt.screen or logic, choice)
  end

  local renderer = RendererModule.new({
    OverworldBattle=OverworldBattle,
    finishContent=finishContent,
    bindArenaBackdrop=bindArenaBackdrop,
  })
  local registry = Registry.new({
    onHookError=function(event, failure)
      if mod.log and type(mod.log.warn) == "function" then
        mod.log:warn("Gen2 Ascendant hook %s owner %s failed open: %s",
          safeText(event), safeText(failure and failure.owner),
          safeText(failure and failure.error))
      end
    end,
  })

  local runtime

  local registered, reason = registry:register(DefaultCard.descriptor({
    finishContent=finishContent,
  }))
  if registered then registered, reason = registry:register(
    RouterCard.descriptor()) end
  if registered then registered, reason = registry:register(
    LifecycleCard.descriptor({
      mod=mod,
      lifecycle=lifecycle,
      legacyRenderer=renderer,
      resolveMode=function(payload)
        if type(payload) == "table" and payload.mode ~= nil then
          return payload.mode
        end
        local ok, plan = pcall(OverworldBattle.capturePresentationPlan)
        if not ok or type(plan) ~= "table" or plan.mode == nil then
          error("Gen2 presentation plan is unavailable: "
            .. safeText(plan, "missing mode"), 0)
        end
        return plan.mode
      end,
      watchdogExpired=function(current)
        if type(current) ~= "table" or current.state ~= "end_pending" then
          return false
        end
        local screen = current.screen
        -- A logic end may race ahead of the concrete BattleState bind. Without
        -- an exact screen receipt the watchdog cannot prove that presentation
        -- has left the stack; treating nil as expired would make battle.ended a
        -- delayed terminal edge on the next world tick.
        if screen == nil then return false end
        local game = currentGame(mod)
        return not stackContains(game and game.stack, screen)
      end,
      onRuntimeFailure=function(reason, fallbackSafe, failedEncounter)
        M.installed = true
        M.active = false
        -- Even a complete Card teardown cannot transfer the already-running
        -- encounter to listeners which were not present for its start/screen
        -- edges.  Never layer the legacy owner into that encounter.  Keep the
        -- process fail-closed and let the next clean boot choose fallback.
        M.state = fallbackSafe == true
          and "restart-required" or "rollback_pending"
        M.fallbackSafe = false
        M.recoveryArmed = false
        M.failedEncounter = failedEncounter
        M.lastError = joinErrors(safeText(reason,
          "Gen2 battle Card runtime failure"), fallbackSafe == true
            and "clean teardown completed; restart required before legacy fallback"
            or nil)
        M.runtime = runtime
        if fallbackSafe == true then
          local armed, armReason = armBoundRecovery(M.lastError,
            failedEncounter)
          if armed == true then
            M.state = "legacy-recovery-armed"
            M.recoveryArmed = true
          elseif armed == false then
            M.state = "rollback_pending"
            M.lastError = joinErrors(M.lastError,
              "post-failure recovery unavailable: " .. armReason)
          end
        end
        notifyStatus()
      end,
    }))
  end

  runtime = {
    registry=registry,
    lifecycle=lifecycle,
    renderer=renderer,
  }
  if not registered then
    return failInstall(runtime,
      safeText(reason, "Gen2 Card registration failed"),
      "Gen2-battle-card-registration-failed")
  end

  local active, activateReason = registry:activate(LifecycleCard.ID, {
    generation=2, host="VOXEL_ASCENDANT",
  })
  if active ~= true then
    return failInstall(runtime,
      safeText(activateReason, "Gen2 Card activation failed"),
      "Gen2-battle-card-activation-failed")
  end

  runtime.public = PublicHost.new({
    cardSchema=Contracts.CARD_SCHEMA,
    lifecycle={
      event=LifecycleCard.PUBLIC_EVENT,
      schema="ascendant.battle-lifecycle-public-event/v1",
      apiVersion=LifecycleModule.API_VERSION,
      generation=2,
    },
    health=function() return publicHealth(runtime) end,
  })
  M.installed = true
  M.active = true
  M.state = "active"
  -- The healthy Card graph still owns engine listeners, so installing the
  -- legacy fallback alongside it would be unsafe. Main selects this graph by
  -- `ok` before consulting the fallback receipt.
  M.fallbackSafe = false
  M.recoveryArmed = false
  M.failedEncounter = nil
  M.lastError = nil
  M.runtime = runtime
  return true
end

function M.bindPostFailureRecovery(callback)
  if type(callback) ~= "function" then
    return false, "Gen2 post-failure recovery activator must be a function"
  end
  if M.recoveryActivator ~= nil
      and not rawequal(M.recoveryActivator, callback) then
    return false, "Gen2 post-failure recovery activator is already bound"
  end
  M.recoveryActivator = callback
  if M.active ~= true and M.state == "restart-required"
      and M.failedEncounter ~= nil then
    local armed, reason = armBoundRecovery(M.lastError, M.failedEncounter)
    if armed == true then
      M.state = "legacy-recovery-armed"
      M.recoveryArmed = true
      notifyStatus()
      return true
    end
    if armed == false then
      M.state = "rollback_pending"
      M.fallbackSafe = false
      M.lastError = joinErrors(M.lastError,
        "post-failure recovery unavailable: " .. reason)
      notifyStatus()
      return false, reason
    end
  end
  return true
end

function M.subscribeStatus(callback)
  if type(callback) ~= "function" then
    return nil, "Gen2 status observer must be a function"
  end
  M.statusSerial = M.statusSerial + 1
  local entry = { callback=callback, live=true }
  M.statusObservers[M.statusSerial] = entry
  local serial = M.statusSerial
  pcall(callback, publicHealth(M.runtime))
  return function()
    if entry.live ~= true or M.statusObservers[serial] ~= entry then
      return false
    end
    entry.live = false
    M.statusObservers[serial] = nil
    return true
  end
end

function M.deactivate(reason)
  if not M.installed or M.runtime == nil then
    M.active = false
    M.state = "inactive"
    M.fallbackSafe = true
    M.recoveryArmed = false
    M.failedEncounter = nil
    notifyStatus()
    return true
  end
  local stopped, stopReason, untouched = retireRuntime(M.runtime,
    reason or "Gen2-battle-card-host-deactivated")
  if stopped ~= true then
    if untouched == true then return false, stopReason end
    M.active = false
    M.state = "rollback_pending"
    M.fallbackSafe = false
    M.recoveryArmed = false
    M.lastError = stopReason
    notifyStatus()
    return false, stopReason
  end
  M.runtime = nil
  M.active = false
  M.state = "inactive"
  M.fallbackSafe = true
  M.recoveryArmed = false
  M.failedEncounter = nil
  M.lastError = nil
  notifyStatus()
  return true
end

function M.public()
  return M.active and M.runtime and M.runtime.public or nil
end

function M.lifecycle()
  return M.active and M.runtime and M.runtime.lifecycle:public() or nil
end

function M.status()
  return publicHealth(M.runtime)
end

return M
