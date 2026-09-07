-- Declarative RC11 battle-router Card for the Gen-1 lifecycle adapter.
--
-- This card is the sole state-changing owner for the three public lifecycle
-- events and the provider-only battle.move_used route. Independent read-only
-- observers may subscribe to the same names without taking renderer/lifecycle
-- ownership. Its renderer
-- dependency remains injected so the adapter can be tested and replaced
-- without giving it private access to another card's state.

local V = ...
local RouterOwnerControl = V.require(
  "cards/battle_router/BattleRouterOwnerControl")

local Card = {
  ID = "vasc.gen1.battle-lifecycle",
  VERSION = "1.0.0",
  EVENT = "ascendant.battle.lifecycle/v1",
  PUBLIC_EVENT = "mod.VOXEL_ASCENDANT.battle_lifecycle_v1",
  ROUTER_CAPABILITY = "ascendant.battle-router.gen1/v1",
}

local function safeText(value, fallback)
  if type(value) == "string" then return value end
  if value == nil then return fallback or "nil" end
  local ok, text = pcall(tostring, value)
  if ok and type(text) == "string" then return text end
  return fallback or ("<unprintable-%s>"):format(type(value))
end

local function sameBattle(left, right)
  return rawequal(left, right)
end

local function callUnsubscribers(installed)
  if type(installed) ~= "table" then return true end
  local unsubscribers = installed.unsubscribers or {}
  local pending = {}
  local failures = {}
  for index = #unsubscribers, 1, -1 do
    local unsubscribe = unsubscribers[index]
    if type(unsubscribe) == "function" then
      local ok, value = pcall(unsubscribe)
      if not ok or value == false then
        table.insert(pending, 1, unsubscribe)
        failures[#failures + 1] = ok
          and "unsubscribe returned false"
          or safeText(value, "unprintable unsubscribe error")
      end
    end
  end
  installed.unsubscribers = pending
  if #failures > 0 then return false, table.concat(failures, "; ") end
  return true
end

local function requireDependency(dependencies, name)
  local value = dependencies and dependencies[name]
  if value == nil then error("Gen1BattleLifecycleCard needs " .. name, 3) end
  return value
end

function Card.descriptor(dependencies)
  local mod = requireDependency(dependencies, "mod")
  local renderer = requireDependency(dependencies, "renderer")
  local lifecycle = requireDependency(dependencies, "lifecycle")
  local finishContent = dependencies.finishContent
  local contentCoordinator = dependencies.contentCoordinator

  local function currentLifecycle()
    local ok, value = pcall(lifecycle.current)
    if not ok then
      return nil, safeText(value, "unprintable lifecycle current error")
    end
    return value
  end

  local function cleanupLedger(installed)
    local ledger = installed.cleanupLedger
    if type(ledger) ~= "table" then
      ledger = {
        ownerCaptured=false,
        contentHandedOff=false,
        gateClosed=false,
        unsubscribed=false,
        criticalUnsubscribed=false,
        routerAborted=false,
        rendererFinished=false,
        lifecycleAborted=false,
        contentFinished=false,
        contentRequired=installed.contentPending == true
          or installed.cleanupContentHint == true,
        contentBattle=installed.contentPendingBattle
          or installed.cleanupBattleHint,
        contentDisposition=installed.cleanupDisposition or "live",
        complete=false,
      }
      installed.cleanupLedger = ledger
    end
    return ledger
  end

  local function captureCleanupOwner(installed, ledger)
    if ledger.ownerCaptured then return true end
    local current, currentReason = currentLifecycle()
    if currentReason then
      return false, "lifecycle current: " .. safeText(currentReason)
    end
    local battle = current and current.battle or nil
    local function merge(candidate)
      if candidate ~= nil then
        if battle ~= nil and not sameBattle(battle, candidate) then
          return false, "cleanup battle owner mismatch"
        end
        battle = candidate
      end
      return true
    end
    local merged, mergeReason = merge(installed.routerBattle)
    if not merged then return false, mergeReason end
    merged, mergeReason = merge(installed.exactBattle)
    if not merged then return false, mergeReason end
    -- An untrusted renderer callback can retire its exact owner and only then
    -- report failure. Preserve the pre-call BattleState as a cleanup hint when
    -- no live owner remains; never let that hint override a newer live owner.
    if battle == nil then battle = installed.cleanupBattleHint end
    ledger.battle = battle
    if ledger.contentBattle == nil then
      ledger.contentBattle = installed.contentPendingBattle
        or installed.cleanupBattleHint or battle
    end
    ledger.ownerCaptured = true
    return true
  end

  local function acquireRouterBarrier(installed, operation, scope)
    local handle = installed.routerBarrier
    if handle ~= nil then
      local ok, live = pcall(handle.active)
      if ok and live == true and type(handle.service) == "table" then
        if scope == "cleanup" then
          installed.routerBarrierScope = "cleanup"
        end
        return handle.service
      end
      return nil, "battle router transaction barrier was lost"
    end
    local acquired, reason = RouterOwnerControl.acquire(
      installed.router, operation)
    if type(acquired) ~= "table"
        or acquired.schema ~= "ascendant.battle-router-transaction/v1"
        or type(acquired.service) ~= "table"
        or type(acquired.release) ~= "function"
        or type(acquired.active) ~= "function" then
      return nil, reason or "battle router transaction barrier declined"
    end
    installed.routerBarrier = acquired
    installed.routerBarrierScope = scope or "transition"
    return acquired.service
  end

  local function releaseRouterBarrier(installed)
    local handle = installed.routerBarrier
    if handle == nil then return true end
    local ok, value, detail = pcall(handle.release)
    if not ok or value ~= true then
      return false, safeText(ok and detail or value,
        "battle router transaction barrier release failed")
    end
    installed.routerBarrier = nil
    installed.routerBarrierScope = nil
    return true
  end

  local function routerService(installed)
    local handle = installed.routerBarrier
    if type(handle) == "table" and type(handle.active) == "function"
        and type(handle.service) == "table" then
      local ok, live = pcall(handle.active)
      if ok and live == true then return handle.service end
    end
    return installed.router
  end

  local function cleanup(installed, reason)
    if type(installed) ~= "table" then return true end
    -- Retirement is monotone. A refused unsubscribe may leave a callback in
    -- the engine snapshot, but from this first cleanup instruction onward it
    -- has no authority to mutate renderer, lifecycle, router or public hooks.
    installed.retiring = true
    local ledger = cleanupLedger(installed)
    if ledger.complete then return true end
    local reasonText = safeText(reason, "battle-lifecycle-card-deactivated")
    local captured, captureReason = captureCleanupOwner(installed, ledger)
    if not captured then return false, captureReason end
    local battle = ledger.battle
    local contentBattle = ledger.contentBattle
    local cleanupRouter, routerBarrierReason = acquireRouterBarrier(
      installed, "lifecycle-card-cleanup", "cleanup")
    if cleanupRouter == nil and installed.router ~= nil then
      return false, routerBarrierReason
    end

    -- Quarantine every remaining cleanup phase behind the same exact-owner
    -- barrier. Gate setters, coordinator hand-offs, provider aborts and
    -- renderer finish callbacks are all executable boundaries; any of them
    -- could otherwise claim B while this ledger is frozen on A. The lease is
    -- intentionally durable across a rollback_pending retry and is released
    -- only after renderer unwind and successful listener removal.
    installed.cleanupBarrierActive = true
    installed.cleanupBarrierBattle = battle
    if battle ~= nil then
      if installed.callbackBattle == nil then
        installed.callbackBattle = battle
        installed.callbackPhase = "cleanup"
        installed.callbackViolation = nil
        installed.callbackBarrierRejected = nil
        installed.callbackPreviousBattle = nil
        installed.callbackPreviousTerminalSeen = false
      elseif installed.callbackPhase ~= "cleanup"
          or not sameBattle(installed.callbackBattle, battle) then
        return false, "cleanup callback owner mismatch"
      end
    end

    -- Freeze the content owner before closing the renderer gate. Gate closure
    -- may synchronously finish an OverworldBattle session; both that callback
    -- and every later Card/native path must converge on the same exact-once
    -- coordinator tombstone rather than calling global cleanup independently.
    if not ledger.contentHandedOff
        and type(contentCoordinator) == "table"
        and contentBattle ~= nil then
      local ok, value, detail = pcall(contentCoordinator.adopt,
        contentBattle, reasonText, "explicit-card-handoff")
      if not ok or value ~= true then
        ledger.contentHandoffError = "content handoff: " .. safeText(
          ok and detail or value, "content coordinator refused owner")
      else
        ledger.contentHandedOff = true
        ledger.contentHandoffError = nil
      end
    end

    -- Each successful phase is durable on the installed Card token. Registry
    -- keeps that exact token while rollback is pending, so a later retry can
    -- resume at the first refusal without repeating already-released owners.
    if not ledger.gateClosed
        and type(renderer.setBattleLifecycleReady) == "function" then
      local ok, value = pcall(renderer.setBattleLifecycleReady, false,
        reasonText)
      if not ok then
        return false, "gate: "
          .. safeText(value, "unprintable renderer gate error")
      end
      -- This setter returns the new readiness state. Only exact false proves
      -- that the mutation gate is actually closed.
      if value ~= false then
        return false, "gate: renderer lifecycle gate remained open"
      end
      ledger.gateClosed = true
    end
    if not ledger.gateClosed then ledger.gateClosed = true end

    -- A refused hand-off must remain retryable, but it may never leave the
    -- renderer mutation gate open while Registry advertises rollback_pending.
    -- Stop only after the monotone gate-close phase has completed.
    if not ledger.contentHandedOff
        and ledger.contentHandoffError ~= nil then
      return false, ledger.contentHandoffError
    end

    if not ledger.routerAborted
        and type(cleanupRouter) == "table"
        and type(cleanupRouter.abort) == "function"
        and battle ~= nil
        and type(cleanupRouter.owns) == "function"
        and cleanupRouter.owns(battle) then
      local ok, value, detail = pcall(cleanupRouter.abort, battle,
        reasonText)
      if not ok or value ~= true then
        return false, "router abort: " .. safeText(
          ok and detail or value, "unprintable router abort error")
      end
    end
    if not ledger.routerAborted then
      ledger.routerAborted = true
      if sameBattle(installed.routerBattle, battle) then
        installed.routerBattle = nil
      end
    end

    if not ledger.rendererFinished then
      if battle == nil then
        ledger.rendererFinished = true
        ledger.lifecycleAborted = true
        if not ledger.contentRequired then ledger.contentFinished = true end
      else
        local ok, value, detail = pcall(renderer.finish, battle)
        local cleanupViolation = installed.callbackViolation
        if cleanupViolation ~= nil then
          ledger.rendererCallbackViolation = cleanupViolation
        end
        if not ok then
          return false, "renderer finish: "
            .. safeText(value, "unprintable renderer finish error")
        end
        if value == false then
          return false, "renderer finish: "
            .. safeText(detail, "renderer cleanup refused")
        end
        if value ~= nil then
          -- A staged renderer owns lifecycle/content teardown as one exact
          -- transaction. It may report success only after releasing that same
          -- BattleState; otherwise retry its idempotent finish seam.
          local current, currentReason = currentLifecycle()
          if currentReason then
            return false, "lifecycle current: " .. safeText(currentReason)
          end
          if current and not sameBattle(current.battle, battle) then
            return false, "renderer finish changed exact battle owner"
          end
          if current and sameBattle(current.battle, battle) then
            return false, "renderer finish retained lifecycle owner"
          end
          ledger.rendererFinished = true
          ledger.lifecycleAborted = true
          -- A content phase which already failed before Card rollback remains
          -- independently retryable. A later renderer success cannot claim
          -- that external cleanup on its behalf.
          if not ledger.contentRequired then ledger.contentFinished = true end
        else
          ledger.rendererFinished = true
        end
      end
    end

    -- Ordinary listeners may be removed once renderer code has unwound. The
    -- critical deny owner deliberately remains installed through Lifecycle
    -- and content cleanup; otherwise a raw coordinator callback could claim a
    -- successor while this cleanup ledger is still frozen on its predecessor.
    if not ledger.unsubscribed then
      local unsubscribed, unsubscribeReason = callUnsubscribers(installed)
      if not unsubscribed then
        return false, "unsubscribe: " .. safeText(unsubscribeReason)
      end
      ledger.unsubscribed = true
    end

    if not ledger.lifecycleAborted then
      local current, currentReason = currentLifecycle()
      if currentReason then
        return false, "lifecycle current: " .. safeText(currentReason)
      end
      if current ~= nil then
        if not sameBattle(current.battle, battle) then
          return false, "lifecycle abort battle owner mismatch"
        end
        local control = installed.lifecycleCleanupControl
        if type(control) ~= "table"
            or control.schema
              ~= "ascendant.battle-lifecycle-critical-control/v1"
            or type(control.cleanupAbort) ~= "function" then
          return false, "lifecycle abort: critical owner control unavailable"
        end
        local ok, value, detail = pcall(
          control.cleanupAbort, battle, reasonText)
        if not ok or value == nil then
          return false, "lifecycle abort: "
            .. safeText(ok and detail or value,
              "unprintable lifecycle abort error")
        end
        ledger.contentRequired = true
      end
      ledger.lifecycleAborted = true
    end

    if not ledger.contentFinished then
      if type(contentCoordinator) == "table" and contentBattle ~= nil then
        if ledger.contentDisposition == "terminal" then
          local ok, value, detail = pcall(contentCoordinator.retire,
            contentBattle, reasonText)
          if not ok or value ~= true then
            return false, "content: " .. safeText(
              ok and detail or value, "content coordinator refused retire")
          end
        end
      elseif ledger.contentRequired and type(finishContent) == "function" then
        local ok, value, detail = pcall(finishContent)
        if not ok or value == false then
          return false, "content: " .. safeText(
            ok and detail or value, "unprintable content cleanup error")
        end
      end
      ledger.contentFinished = true
      installed.contentPending = false
      installed.contentPendingBattle = nil
    end

    -- Only a fully retired Lifecycle/content owner may release the critical
    -- deny listener. A refused unsubscribe remains a retryable final phase;
    -- the Router transaction stays live until that exact token is gone.
    if not ledger.criticalUnsubscribed then
      local critical = installed.criticalUnsubscriber
      if type(critical) == "function" then
        local ok, value = pcall(critical)
        if not ok or value == false then
          return false, "critical unsubscribe: " .. safeText(
            ok and "critical unsubscribe returned false" or value,
            "critical unsubscribe failed")
        end
      end
      installed.criticalUnsubscriber = nil
      installed.lifecycleCleanupControl = nil
      ledger.criticalUnsubscribed = true
    end

    local released, releaseReason = releaseRouterBarrier(installed)
    if not released then return false, releaseReason end
    ledger.complete = true
    installed.exactBattle = nil
    installed.routerBattle = nil
    installed.contentPendingBattle = nil
    installed.cleanupBattleHint = nil
    installed.cleanupContentHint = nil
    installed.cleanupDisposition = nil
    installed.callbackBattle = nil
    installed.callbackPhase = nil
    installed.callbackViolation = nil
    installed.callbackBarrierRejected = nil
    installed.criticalUnsubscriber = nil
    installed.lifecycleCleanupControl = nil
    installed.cleanupBarrierActive = false
    installed.cleanupBarrierBattle = nil
    installed.contentBarrierActive = false
    installed.contentBarrierBattle = nil
    installed.contentBarrierViolation = nil
    installed.publicRelayBarrierActive = false
    installed.publicRelayBarrierViolation = nil
    installed.engineBarrierActive = false
    installed.engineBarrierBattle = nil
    installed.engineBarrierViolation = nil
    installed.transitionBarrierViolation = nil
    return true
  end

  local function subscribe(installed, name, callback)
    local ok, unsubscribe = pcall(mod.events.on, mod.events, name, callback)
    if not ok or type(unsubscribe) ~= "function" then
      cleanup(installed, "engine-event-subscription-failed")
      error(("unable to subscribe %s: %s"):format(
        safeText(name, "unknown"),
        safeText(unsubscribe, "unprintable subscription error")), 0)
    end
    installed.unsubscribers[#installed.unsubscribers + 1] = unsubscribe
  end

  return {
    schema="ascendant.card/v1",
    id=Card.ID,
    version=Card.VERSION,
    owner="voxel_ascendant",
    requires={},
    optionalRequires={},
    consumes={ Card.ROUTER_CAPABILITY },
    provides={ "ascendant.battle-context/v1" },
    tests={
      "tests/gen1_battle_lifecycle_test.lua",
      "tests/gen1_battle_lifecycle_engine_test.lua",
      "tests/gen1_battle_lifecycle_card_test.lua",
      "tests/gen1_battle_content_coordinator_integration_test.lua",
      "tests/gen1_battle_switch_renderer_integration_test.lua",
      "tests/gen1_battle_lifecycle_reentry_test.lua",
      "tests/gen1_native_battle_cleanup_test.lua",
      "tests/gen1_native_battle_preflight_order_test.lua",
      "tests/gen1_native_battle_wrapper_order_test.lua",
    },
    docs={
      "docs/maintainer/RC11_ARCHITECTURE.md",
      "docs/maintainer/RC11_HOOK_OWNERSHIP.md",
      "docs/maintainer/RC11_TEST_MATRIX.md",
    },
    saveNamespace=false,
    impact={
      runtimeOwners={ "gen1.battle.lifecycle" },
      saveWrites={},
      publicHooks={ Card.EVENT, Card.PUBLIC_EVENT },
      files={
        "lib/adapters/gen1/Gen1BattleLifecycle.lua",
        "lib/adapters/gen1/NativeBattleCleanup.lua",
        "lib/cards/battle_router/Gen1BattleLifecycleCard.lua",
      },
    },
    lifecycle={
      install=function()
        if type(mod.events) ~= "table"
            or type(mod.events.on) ~= "function"
            or type(mod.events.emit) ~= "function" then
          return false, "public mod event API is unavailable"
        end
        for _, name in ipairs({
          "ensure", "battlerSwitched", "finish",
          "setBattleLifecycleReady",
        }) do
          if type(renderer[name]) ~= "function" then
            return false, "renderer seam is unavailable: " .. name
          end
        end
        for _, name in ipairs({
          "started", "finished", "subscribeCommittedFinalizer",
          "subscribeCritical", "cleanupAbort", "current", "public",
          "publicEvent", "health",
        }) do
          if type(lifecycle[name]) ~= "function" then
            return false, "lifecycle seam is unavailable: " .. name
          end
        end
        if contentCoordinator ~= nil then
          if type(contentCoordinator) ~= "table"
              or type(contentCoordinator.adopt) ~= "function"
              or type(contentCoordinator.retire) ~= "function" then
            return false, "exact content coordinator is unavailable"
          end
        end
        return { unsubscribers={} }
      end,

      activate=function(context, installed)
        installed.unsubscribers = {}
        installed.runtimeFailure = nil
        installed.failing = false
        installed.retiring = false
        installed.cleanupLedger = nil
        installed.exactBattle = nil
        installed.contentPending = false
        installed.contentPendingBattle = nil
        installed.cleanupBattleHint = nil
        installed.cleanupContentHint = nil
        installed.cleanupDisposition = nil
        installed.callbackBattle = nil
        installed.callbackPhase = nil
        installed.callbackViolation = nil
        installed.callbackBarrierRejected = nil
        installed.callbackPreviousBattle = nil
        installed.callbackPreviousTerminalSeen = false
        installed.criticalUnsubscriber = nil
        installed.lifecycleCleanupControl = nil
        installed.cleanupBarrierActive = false
        installed.cleanupBarrierBattle = nil
        installed.contentBarrierActive = false
        installed.contentBarrierBattle = nil
        installed.contentBarrierViolation = nil
        installed.publicRelayBarrierActive = false
        installed.publicRelayBarrierViolation = nil
        installed.engineBarrierActive = false
        installed.engineBarrierBattle = nil
        installed.engineBarrierViolation = nil
        installed.transitionBarrierViolation = nil
        installed.routerBarrier = nil
        installed.routerBarrierScope = nil
        local routerCapability, routerReason =
          context.capability(Card.ROUTER_CAPABILITY)
        local router = routerCapability and routerCapability.value or nil
        if type(router) ~= "table"
            or router.schema ~= "ascendant.battle-router/v1"
            or router.apiVersion ~= 1
            or type(router.start) ~= "function"
            or type(router.owns) ~= "function"
            or type(router.switch) ~= "function"
            or type(router.attack) ~= "function"
            or type(router.finish) ~= "function"
            or type(router.fallback) ~= "function"
            or type(router.abort) ~= "function"
            or type(router.health) ~= "function" then
          return false, routerReason or "Gen-1 battle router is unavailable"
        end
        installed.router = router
        installed.routerBattle = nil
        local function performRuntimeFailure(phaseText, reasonText,
            preformatted)
          if installed.failing then return false, false end
          local failureText = preformatted == true and reasonText
            or "battle lifecycle " .. phaseText .. " failed: " .. reasonText
          installed.failing = true
          installed.runtimeFailure = reasonText
          local called, aborted = pcall(context.fail, failureText)
          -- A false result means Registry already attempted cleanup and kept
          -- this exact installed/active token as rollback_pending. Retrying it
          -- immediately outside Registry would release private owners while
          -- the Registry still advertises a pending rollback. Only a thrown
          -- context boundary needs the local emergency cleanup path.
          if not called then
            cleanup(installed,
              "battle-lifecycle-" .. phaseText .. "-failed")
          end
          return false, called and aborted == true
        end
        local function failRuntime(phase, reason)
          -- Error objects cross an untrusted provider/renderer boundary. Build
          -- primitive diagnostics before mutating the Card so a hostile
          -- __tostring cannot strand an apparently active half-owner.
          local phaseText = safeText(phase, "runtime")
          local reasonText = safeText(reason, "unprintable runtime failure")
          -- A renderer callback is an indivisible lease.  Never tear the Card
          -- down synchronously while untrusted renderer code is still on the
          -- stack: cleanup would unsubscribe the frozen critical barrier and
          -- let the same callback create a foreign BattleState afterwards.
          -- Record the first failure, reject every later transition through
          -- the still-installed barrier, and let rendererCall perform the
          -- actual Registry failure only after the callback has unwound.
          if installed.publicRelayBarrierActive == true then
            if installed.publicRelayBarrierViolation == nil then
              installed.publicRelayBarrierViolation = "battle lifecycle "
                .. phaseText .. " failed: " .. reasonText
            end
            return false, false
          end
          if installed.engineBarrierActive == true then
            if installed.engineBarrierViolation == nil then
              installed.engineBarrierViolation = "battle lifecycle "
                .. phaseText .. " failed: " .. reasonText
            end
            return false, false
          end
          if installed.contentBarrierActive == true then
            if installed.contentBarrierViolation == nil then
              installed.contentBarrierViolation = "battle lifecycle "
                .. phaseText .. " failed: " .. reasonText
            end
            return false, false
          end
          if installed.callbackBattle ~= nil then
            if installed.callbackViolation == nil then
              installed.callbackViolation = "battle lifecycle "
                .. phaseText .. " failed: " .. reasonText
            end
            installed.callbackBarrierRejected = true
            return false, false
          end
          -- A direct Lifecycle transition holds the Router lease from the
          -- critical provider mutation through every ordinary observer and
          -- the committed relay. A nested engine callback must not tear that
          -- lease down while the observer which triggered it is on the stack.
          if installed.routerBarrierScope == "transition" then
            if installed.transitionBarrierViolation == nil then
              installed.transitionBarrierViolation = "battle lifecycle "
                .. phaseText .. " failed: " .. reasonText
            end
            return false, false
          end
          return performRuntimeFailure(phaseText, reasonText)
        end
        local function guarded(phase, callback)
          if installed.retiring or installed.failing then return nil end
          local ok, value, detail = pcall(callback)
          if not ok then return failRuntime(phase, value) end
          return value, detail
        end
        local function guardedEngine(phase, callback)
          return guarded(phase, function()
            if installed.engineBarrierActive == true
                or installed.routerBarrier ~= nil then
              error("nested engine battle transaction is forbidden", 0)
            end
            installed.engineBarrierActive = true
            installed.engineBarrierViolation = nil
            local _, barrierReason = acquireRouterBarrier(installed,
              "engine-battle-" .. safeText(phase, "event"), "event")
            if installed.routerBarrier == nil then
              installed.engineBarrierActive = false
              installed.engineBarrierViolation = nil
              error(barrierReason
                or "battle router event transaction declined", 0)
            end
            local ok, value, detail = pcall(callback)
            local violation = installed.engineBarrierViolation
            installed.engineBarrierActive = false
            installed.engineBarrierBattle = nil
            installed.engineBarrierViolation = nil
            if violation ~= nil then error(violation, 0) end
            if not ok then error(value, 0) end
            if installed.failing then
              error(installed.runtimeFailure
                or "engine battle transaction invalidated owner", 0)
            end
            if installed.routerBarrierScope == "event" then
              local released, releaseReason = releaseRouterBarrier(installed)
              if not released then error(releaseReason, 0) end
            end
            return value, detail
          end)
        end
        local function rendererCall(battle, phase, callback)
          if installed.callbackBattle ~= nil then
            error("nested renderer callback changed transaction owner", 0)
          end
          local previous, previousReason = currentLifecycle()
          if previousReason then error(previousReason, 0) end
          installed.callbackBattle = battle
          installed.callbackPhase = phase
          installed.callbackViolation = nil
          installed.callbackBarrierRejected = nil
          installed.callbackPreviousBattle = previous and previous.battle or nil
          installed.callbackPreviousTerminalSeen = false
          local ok, value, detail = pcall(callback)
          local violation = installed.callbackViolation
          installed.callbackBattle = nil
          installed.callbackPhase = nil
          installed.callbackViolation = nil
          installed.callbackBarrierRejected = nil
          installed.callbackPreviousBattle = nil
          installed.callbackPreviousTerminalSeen = false
          if violation ~= nil then error(violation, 0) end
          if not ok then error(value, 0) end
          if installed.failing then
            error(installed.runtimeFailure
              or "renderer callback invalidated battle owner", 0)
          end
          return value, detail
        end
        local function exactSwitchProgress(battle, previous)
          local current, currentReason = currentLifecycle()
          if currentReason then return nil, currentReason end
          if type(current) ~= "table"
              or not sameBattle(current.battle, battle) then
            return nil, "renderer switch changed exact battle owner"
          end
          if current.battleToken ~= previous.battleToken then
            return nil, "renderer switch changed battle token"
          end
          if current.deploymentToken ~= previous.deploymentToken + 1 then
            return nil, "renderer switch did not advance one deployment"
          end
          local exactRouter = routerService(installed)
          if exactRouter.owns(battle) then
            local routerHealth = exactRouter.health()
            local active = type(routerHealth) == "table"
              and routerHealth.active or nil
            if type(active) ~= "table"
                or active.provider ~= current.provider
                or active.battleToken ~= current.battleToken
                or active.deploymentToken ~= current.deploymentToken then
              return nil, tostring(current.provider)
                .. " switch router tokens diverged"
            end
          elseif current.provider == "DEFAULT" or current.provider == "DISCS" then
            return nil, tostring(current.provider)
              .. " switch lost exact router owner"
          end
          return current
        end
        local function exactNativeFallback(battle, previous)
          local current, currentReason
          if previous ~= nil then
            current, currentReason = exactSwitchProgress(battle, previous)
          else
            current, currentReason = currentLifecycle()
          end
          if currentReason then return nil, currentReason end
          if current and sameBattle(current.battle, battle)
              and current.state == "native_latched"
              and current.provider == "DEFAULT"
              and routerService(installed).owns(battle) then return current end
          return nil, "renderer did not establish an exact native fallback"
        end
        local function contentCall(battle, callback)
          if installed.contentBarrierActive == true then
            error("nested battle content transaction is forbidden", 0)
          end
          installed.contentBarrierActive = true
          installed.contentBarrierBattle = battle
          installed.contentBarrierViolation = nil
          local ok, value, detail = pcall(callback)
          local violation = installed.contentBarrierViolation
          installed.contentBarrierActive = false
          installed.contentBarrierBattle = nil
          installed.contentBarrierViolation = nil
          if violation ~= nil then error(violation, 0) end
          if not ok then error(value, 0) end
          return value, detail
        end
        local function retireTerminalContent(battle, reason)
          installed.contentPending = true
          installed.contentPendingBattle = battle
          contentCall(battle, function()
            if type(contentCoordinator) == "table" then
              local adopted, adoptReason = contentCoordinator.adopt(
                battle, reason, "explicit-card-handoff")
              if adopted ~= true then
                error(adoptReason or "content coordinator refused owner", 0)
              end
              local retired, retireReason = contentCoordinator.retire(
                battle, reason)
              if retired ~= true then
                error(retireReason or "battle content cleanup declined", 0)
              end
            elseif type(finishContent) == "function" then
              local contentFinished, contentReason = finishContent()
              if contentFinished == false then
                error(contentReason or "battle content cleanup declined", 0)
              end
            end
          end)
          installed.contentPending = false
          installed.contentPendingBattle = nil
        end
        local function armExactContent(battle, reason)
          if type(contentCoordinator) ~= "table" then return true end
          contentCall(battle, function()
            local adopted, adoptReason = contentCoordinator.adopt(
              battle, reason, "explicit-card-handoff")
            if adopted ~= true then
              error(adoptReason or "content coordinator refused owner", 0)
            end
          end)
          return true
        end
        -- Route the authoritative internal transition before it is sanitized
        -- and relayed publicly.  A public started/replacing/native-latched
        -- receipt must never describe ownership the provider graph has not
        -- already acquired (or explicitly classified as transitional).
        local routeUnsubscribe, routeControlOrReason =
          lifecycle.subscribeCritical(
          Card.ID .. ".provider-router", function(event)
            local raw = type(event) == "table" and event.receipt or nil
            local battle = type(raw) == "table" and raw.battle or nil
            -- Cleanup itself is also an untrusted renderer callback. Keep the
            -- still-subscribed critical owner as a deny lease: it permits only
            -- one exact terminal transition for cleanup A and rejects every
            -- foreign/new owner until renderer.finish has returned.
            if installed.cleanupBarrierActive == true then
              local cleanupBattle = installed.cleanupBarrierBattle
              local terminal = cleanupBattle ~= nil and sameBattle(
                  battle, cleanupBattle)
                and (event.kind == "ended" or event.kind == "aborted")
              if terminal then return true end
              installed.callbackViolation =
                "renderer cleanup violated exact battle owner"
              installed.callbackBarrierRejected = true
              return false, installed.callbackViolation
            end
            if installed.contentBarrierActive == true then
              installed.contentBarrierViolation =
                "battle content callback violated exact lifecycle owner"
              return false, installed.contentBarrierViolation
            end
            if installed.publicRelayBarrierActive == true then
              installed.publicRelayBarrierViolation =
                "public lifecycle callback violated exact owner"
              return false, installed.publicRelayBarrierViolation
            end
            -- A late listener snapshot during rollback must otherwise be an
            -- inert successful no-op. Returning false here would recursively
            -- invoke compensation while the same ledger is already active.
            if installed.retiring or installed.failing then return true end
            if battle == nil then
              return failRuntime("provider-route", "lifecycle omitted battle")
            end
            -- Once any transition in this renderer lease was rejected, the
            -- critical owner remains installed solely as a frozen deny gate.
            -- It may not route another otherwise phase-valid mutation before
            -- rendererCall unwinds and retires the complete Card graph.
            if installed.callbackBattle ~= nil
                and installed.callbackViolation ~= nil then
              installed.callbackBarrierRejected = true
              return false, installed.callbackViolation
            end
            -- Renderer callbacks are one exact-owner transaction. Ending A
            -- may legitimately clear the live lifecycle owner, but it must
            -- not let that same callback create/start/end B before returning.
            -- Keep this frozen barrier independent of exactBattle, which the
            -- accepted A-ended transition deliberately retires.
            if installed.callbackBattle ~= nil then
              local phase = installed.callbackPhase
              local kind = event.kind
              local allowedTargetKind = (phase == "start" and (
                    kind == "created" or kind == "committed"
                    or kind == "native-latched"))
                or (phase == "switch" and (
                    kind == "replacing"
                    or kind == "battler-switched-native"
                    or kind == "committed"
                    or kind == "native-latched"))
                or (phase == "end" and kind == "ended")
              local previousTerminal = phase == "start"
                and installed.callbackPreviousBattle ~= nil
                and not sameBattle(installed.callbackPreviousBattle,
                  installed.callbackBattle)
                and sameBattle(battle, installed.callbackPreviousBattle)
                and installed.callbackPreviousTerminalSeen ~= true
                and (kind == "ended" or kind == "aborted")
              if previousTerminal then
                installed.callbackPreviousTerminalSeen = true
              elseif not sameBattle(battle, installed.callbackBattle)
                  or not allowedTargetKind then
                installed.callbackViolation =
                  "renderer callback violated exact transition phase"
                -- Reject inside Lifecycle while the callback lease is still
                -- frozen, but defer Card teardown until rendererCall unwinds.
                -- Synchronous cleanup here would unsubscribe this critical
                -- barrier and let the hostile callback create a foreign owner
                -- before returning to the Card.
                installed.callbackBarrierRejected = true
                return false, installed.callbackViolation
              end
            end
            if installed.exactBattle ~= nil
                and not sameBattle(installed.exactBattle, battle) then
              return failRuntime("provider-route", "exact battle owner changed")
            end
            installed.exactBattle = battle
            local routeRouter, barrierReason = acquireRouterBarrier(installed,
              "lifecycle-" .. safeText(event.kind, "transition"),
              "transition")
            if routeRouter == nil then
              return failRuntime("provider-route", barrierReason)
            end
            local routeContext = {
              provider=raw.provider,
              requestedMode=raw.requestedMode,
              battleToken=raw.battleToken,
              deploymentToken=raw.deploymentToken,
              side=raw.side,
              reason=raw.reason,
              -- Internal provider payload only. Lifecycle's public finalizer
              -- still sanitizes both host references out of exported events.
              battler=event.battler,
              previous=event.previous,
              entry="lifecycle." .. tostring(event.kind),
            }
            local routed, routeReason
            if event.kind == "created" then
              routed, routeReason = routeRouter.start(battle, routeContext)
              local transitional = raw.provider ~= "DEFAULT"
                and routeReason == "provider-not-registered:"
                  .. tostring(raw.provider)
              if not routed and not transitional then
                return failRuntime("provider-start", routeReason)
              end
              if routed then installed.routerBattle = battle end
            elseif event.kind == "replacing"
                or event.kind == "battler-switched-native" then
              if routeRouter.owns(battle) then
                routed, routeReason = routeRouter.switch(battle, routeContext)
                if not routed then
                  return failRuntime("provider-switch", routeReason)
                end
                installed.routerBattle = battle
              end
            elseif event.kind == "native-latched" then
              routed, routeReason = routeRouter.fallback(battle, routeContext)
              if not routed then
                return failRuntime("provider-fallback", routeReason)
              end
              installed.routerBattle = battle
            elseif event.kind == "ended" then
              if routeRouter.owns(battle) then
                routed, routeReason = routeRouter.finish(battle, routeContext)
                if not routed then
                  return failRuntime("provider-finish", routeReason)
                end
              end
              if sameBattle(installed.routerBattle, battle) then
                installed.routerBattle = nil
              end
              if sameBattle(installed.exactBattle, battle) then
                installed.exactBattle = nil
              end
            elseif event.kind == "aborted" then
              if routeRouter.owns(battle) then
                routed, routeReason = routeRouter.abort(battle,
                  raw.reason or "lifecycle-aborted")
                if not routed then
                  return failRuntime("provider-abort", routeReason)
                end
              end
              if sameBattle(installed.routerBattle, battle) then
                installed.routerBattle = nil
              end
              if sameBattle(installed.exactBattle, battle) then
                installed.exactBattle = nil
              end
            end
            return true
          end, 1000, function(_, reason)
            if installed.callbackBattle ~= nil
                or installed.cleanupBarrierActive == true
                or installed.contentBarrierActive == true
                or installed.publicRelayBarrierActive == true
                or installed.engineBarrierActive == true then
              -- This also covers an ordinary observer veto *after* the
              -- critical Router mutation accepted. Lifecycle restores its
              -- local transition while this frozen barrier blocks any B/C
              -- claim. The outer rendererCall then retires Router, renderer,
              -- Lifecycle and content together after untrusted code returns.
              if installed.contentBarrierActive == true then
                if installed.contentBarrierViolation == nil then
                  installed.contentBarrierViolation = safeText(reason,
                    "content callback transition was rejected")
                end
                return true, installed.contentBarrierViolation
              end
              if installed.publicRelayBarrierActive == true then
                if installed.publicRelayBarrierViolation == nil then
                  installed.publicRelayBarrierViolation = safeText(reason,
                    "public callback transition was rejected")
                end
                return true, installed.publicRelayBarrierViolation
              end
              if installed.engineBarrierActive == true then
                if installed.engineBarrierViolation == nil then
                  installed.engineBarrierViolation = safeText(reason,
                    "engine callback transition was rejected")
                end
                return true, installed.engineBarrierViolation
              end
              if installed.callbackViolation == nil then
                installed.callbackViolation = safeText(reason,
                  "renderer callback transition was rejected")
              end
              installed.callbackBarrierRejected = true
              return true, installed.callbackViolation
            end
            -- A later mandatory observer may reject after the router already
            -- acquired/released the provider. Retire the complete Card graph
            -- instead of letting Lifecycle alone restore its previous state.
            local transitionViolation = installed.transitionBarrierViolation
            installed.transitionBarrierViolation = nil
            local failureReason = transitionViolation
              or safeText(reason, "post-critical transition was rejected")
            local _, complete = performRuntimeFailure(
              "post-critical-compensation", failureReason,
              transitionViolation ~= nil)
            return complete == true, installed.runtimeFailure
          end)
        if type(routeUnsubscribe) ~= "function" then
          cleanup(installed, "provider-router-subscription-failed")
          return false, routeControlOrReason
            or "provider router lifecycle subscription failed"
        end
        if type(routeControlOrReason) ~= "table"
            or routeControlOrReason.schema
              ~= "ascendant.battle-lifecycle-critical-control/v1"
            or type(routeControlOrReason.cleanupAbort) ~= "function" then
          pcall(routeUnsubscribe)
          cleanup(installed, "provider-router-control-missing")
          return false, "provider router lifecycle cleanup control missing"
        end
        -- Keep the mutation barrier separate from ordinary engine/public
        -- listeners. Cleanup may remove it only after every other unsubscribe
        -- has succeeded; a partial unsubscribe failure must leave the deny
        -- owner installed across rollback_pending.
        installed.criticalUnsubscriber = routeUnsubscribe
        installed.lifecycleCleanupControl = routeControlOrReason
        subscribe(installed, "battle.started", function(payload)
          return guardedEngine("start", function()
            local battle = payload and payload.battle
            if battle == nil then error("battle start omitted battle", 0) end
            installed.cleanupBattleHint = battle
            installed.cleanupContentHint = true
            installed.cleanupDisposition = "live"
            armExactContent(battle, "battle-started")
            local ensured, ensureReason = rendererCall(
              battle, "start", function() return renderer.ensure(battle) end)
            if ensured == false then
              local fallback, fallbackReason = exactNativeFallback(battle)
              if not fallback then
                error(ensureReason or fallbackReason
                  or "renderer ensure declined", 0)
              end
            end
            -- ensure() may publish `created`, whose critical provider route
            -- can synchronously self-abort this Card. Never resurrect that
            -- rejected owner with a subsequent battle.started transition.
            if installed.failing then return false, installed.runtimeFailure end
            local started, startedReason = lifecycle.started(payload)
            if not started then error(startedReason or "lifecycle start failed", 0) end
            installed.cleanupBattleHint = nil
            installed.cleanupContentHint = nil
            installed.cleanupDisposition = nil
            return started
          end)
        end)
        subscribe(installed, "battle.battler_switched", function(payload)
          return guardedEngine("switch", function()
            local battle = type(payload) == "table" and payload.battle or nil
            if battle == nil then
              error("battle switch omitted battle", 0)
            end
            -- Staleness is frozen before entering the renderer. A callback
            -- must not turn an exact refusal into an apparently stale event by
            -- releasing or replacing the owner before it returns false.
            local exactBefore = sameBattle(installed.exactBattle, battle)
            if not exactBefore then return nil end
            local before, beforeReason = currentLifecycle()
            if beforeReason then error(beforeReason, 0) end
            if type(before) ~= "table"
                or not sameBattle(before.battle, battle) then
              error("exact switch has no matching lifecycle owner", 0)
            end
            installed.cleanupBattleHint = battle
            installed.cleanupContentHint = true
            installed.cleanupDisposition = "live"
            armExactContent(battle, "battle-battler-switched")
            local switched, switchReason = rendererCall(
              battle, "switch",
              function() return renderer.battlerSwitched(payload) end)
            if switched ~= false then
              local progressed, progressReason = exactSwitchProgress(
                battle, before)
              if not progressed then error(progressReason, 0) end
              installed.cleanupBattleHint = nil
              installed.cleanupContentHint = nil
              installed.cleanupDisposition = nil
              return switched, switchReason
            end
            local fallback, fallbackReason = exactNativeFallback(battle, before)
            if fallback then
              installed.cleanupBattleHint = nil
              installed.cleanupContentHint = nil
              installed.cleanupDisposition = nil
              return fallback
            end
            -- The exact callback may already have retired lifecycle/provider
            -- state before refusing. Force the Card rollback to finish the
            -- remaining external content as well.
            error(switchReason or fallbackReason
              or "renderer switch declined exact battle", 0)
          end)
        end)
        subscribe(installed, "battle.move_used", function(payload)
          return guardedEngine("attack", function()
            local battle = type(payload) == "table" and payload.battle or nil
            if battle == nil then error("battle attack omitted battle", 0) end
            if not sameBattle(installed.exactBattle, battle) then return nil end
            local current, currentReason = currentLifecycle()
            if currentReason then error(currentReason, 0) end
            if type(current) ~= "table"
                or not sameBattle(current.battle, battle) then
              error("exact attack has no matching lifecycle owner", 0)
            end
            local exactRouter = routerService(installed)
            -- MAP/ARENA remain explicitly transitional until their own Cards
            -- exist. They keep their current renderer path without pretending
            -- this DISCS/DEFAULT provider boundary owns their move event.
            if not exactRouter.owns(battle) then return nil end
            local attacked, attackReason = exactRouter.attack(battle, {
              provider=current.provider,
              requestedMode=current.requestedMode,
              battleToken=current.battleToken,
              deploymentToken=current.deploymentToken,
              side=current.side,
              user=payload.user,
              target=payload.target,
              move=payload.move,
              isCalled=payload.isCalled == true,
              entry="engine.battle.move_used",
            })
            if not attacked then
              error(attackReason or "battle provider attack declined", 0)
            end
            return attacked
          end)
        end)
        subscribe(installed, "battle.ended", function(payload)
          return guardedEngine("end", function()
            local battle = payload and payload.battle
            if battle == nil then error("battle end omitted battle", 0) end
            -- Classify before invoking renderer.finish for the same reason as
            -- switch: callee-side teardown cannot retroactively make an exact
            -- refusal stale.
            local exactBefore = sameBattle(installed.exactBattle, battle)
            if not exactBefore then return end
            installed.cleanupBattleHint = battle
            installed.cleanupContentHint = true
            installed.cleanupDisposition = "terminal"
            armExactContent(battle, "battle-ended")
            local finished = rendererCall(
              battle, "end", function() return renderer.finish(battle) end)
            -- In the engine event path false means a delayed foreign end only
            -- when this Card does not own that BattleState. For the frozen
            -- exact owner it is a cleanup refusal and enters rollback.
            if finished == false then
              error("renderer finish declined exact battle cleanup", 0)
            end
            if finished == nil then
              local current, currentReason = currentLifecycle()
              if currentReason then error(currentReason, 0) end
              if current and not sameBattle(current.battle, battle) then
                error("renderer finish changed exact battle owner", 0)
              end
              if current and sameBattle(current.battle, battle) then
                local ended, endedReason = lifecycle.finished(payload)
                if not ended then
                  error(endedReason or "lifecycle finish declined", 0)
                end
              end
            else
              -- A staged renderer promises to retire the shared lifecycle as
              -- part of finish(). Verify that promise before releasing the
              -- Card's frozen exact owner.
              local current, currentReason = currentLifecycle()
              if currentReason then error(currentReason, 0) end
              if current and sameBattle(current.battle, battle) then
                error("renderer finish retained lifecycle owner", 0)
              end
              if current and not sameBattle(current.battle, battle) then
                error("renderer finish changed exact battle owner", 0)
              end
            end
            -- With the exact-once coordinator, even a renderer which already
            -- retired A converges here idempotently. The compatibility path
            -- without that coordinator preserves the legacy contract where
            -- staged renderer success owns its own content teardown.
            if type(contentCoordinator) == "table" or finished == nil then
              retireTerminalContent(battle, "battle-ended")
            end
            if finished ~= false
                and installed.contentPending ~= true
                and sameBattle(installed.exactBattle, battle) then
              installed.exactBattle = nil
            end
            installed.cleanupBattleHint = nil
            installed.cleanupContentHint = nil
            installed.cleanupDisposition = nil
          end)
        end)
        local unsubscribe, subscribeReason =
          lifecycle.subscribeCommittedFinalizer(Card.ID,
          function(event)
            if installed.retiring or installed.failing then return true end
            local transitionViolation = installed.transitionBarrierViolation
            if transitionViolation ~= nil then
              installed.transitionBarrierViolation = nil
              return performRuntimeFailure(
                "transition", transitionViolation, true)
            end
            installed.publicRelayBarrierActive = true
            installed.publicRelayBarrierViolation = nil
            local ok, value = pcall(function()
              local raw = type(event) == "table" and event.receipt or nil
              local battle = type(raw) == "table" and raw.battle or nil
              if raw and (raw.provider == "DEFAULT"
                    or raw.provider == "DISCS")
                  and event.kind ~= "ended" and event.kind ~= "aborted"
                  and (battle == nil or not router.owns(battle)) then
                error(raw.provider
                  .. " lifecycle event has no exact provider owner", 0)
              end
              local public = lifecycle.publicEvent(event)
              if public then
                -- Both extension boundaries receive the same pure-data
                -- receipt shape. The transaction remains frozen through both
                -- public callback buses, so neither can acquire a successor
                -- provider before this exact lifecycle commit is visible.
                context.hooks.emit(Card.EVENT, public)
                mod.events:emit(Card.PUBLIC_EVENT, public)
              end
              return true
            end)
            local violation = installed.publicRelayBarrierViolation
            installed.publicRelayBarrierActive = false
            installed.publicRelayBarrierViolation = nil
            if violation ~= nil then
              return performRuntimeFailure("public-relay", violation, true)
            end
            if not ok then
              return performRuntimeFailure("public-relay",
                safeText(value, "unprintable public relay failure"))
            end
            if installed.routerBarrierScope == "transition" then
              local released, releaseReason = releaseRouterBarrier(installed)
              if not released then
                return performRuntimeFailure(
                  "provider-transaction-release",
                  safeText(releaseReason,
                    "battle router transaction release failed"))
              end
            end
            return true
          end, 100)
        if type(unsubscribe) ~= "function" then
          cleanup(installed, "lifecycle-hook-subscription-failed")
          return false, subscribeReason or "lifecycle hook subscription failed"
        end
        installed.unsubscribers[#installed.unsubscribers + 1] = unsubscribe
        local readyOK, ready = pcall(renderer.setBattleLifecycleReady, true)
        if not readyOK or ready ~= true then
          cleanup(installed, "renderer-lifecycle-gate-failed")
          return false, readyOK and "renderer lifecycle gate declined"
            or safeText(ready, "unprintable renderer gate error")
        end
        return installed, lifecycle.public()
      end,

      deactivate=function(_, active, reason)
        return cleanup(active, reason or "battle-lifecycle-card-deactivated")
      end,

      abort=function(_, _, reason, installed, active)
        return cleanup(active or installed,
          reason or "battle-lifecycle-card-aborted")
      end,

      health=function(_, installed)
        -- Registry health receipts cross a pure-data boundary.  The internal
        -- lifecycle health intentionally retains the exact live BattleState
        -- for its owner, so expose only the already-sanitized public view.
        local public = lifecycle.public()
        local status = public.health()
        status.cardId = Card.ID
        if installed and installed.runtimeFailure then
          status.ok = false
          status.cardError = installed.runtimeFailure
        end
        return status
      end,
    },
  }
end

return Card
