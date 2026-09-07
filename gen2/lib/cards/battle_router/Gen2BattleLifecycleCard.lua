-- Gen-2 engine-event adapter Card.
--
-- DEFAULT is routed through the shared exact-owner Router. MAP, ARENA and
-- DISCS deliberately remain behind one injected legacy renderer adapter in
-- this first segmentation tranche. battle.move_used is observation-only:
-- Gold BattleState:animForMove remains the sole animation owner.

local V = ...
local RouterOwnerControl = V.require(
  "cards/battle_router/BattleRouterOwnerControl")

local Card = {
  ID = "vasc.gen2.battle-lifecycle",
  VERSION = "1.0.0",
  CAPABILITY = "ascendant.battle-context.gen2/v1",
  EVENT = "ascendant.gen2.battle.lifecycle/v1",
  PUBLIC_EVENT = "mod.VOXEL_ASCENDANT.gen2_battle_lifecycle_v1",
  ROUTER_CAPABILITY = "ascendant.battle-router.gen2/v1",
}

local TRANSITIONAL = { MAP=true, ARENA=true, DISCS=true }

local function same(left, right)
  return rawequal(left, right)
end

local function safeText(value, fallback)
  if type(value) == "string" then return value end
  if value == nil then return fallback or "nil" end
  local ok, text = pcall(tostring, value)
  if ok and type(text) == "string" then return text end
  return fallback or ("<unprintable-%s>"):format(type(value))
end

local function dependency(dependencies, name)
  local value = dependencies and dependencies[name]
  if value == nil then error("Gen2BattleLifecycleCard needs " .. name, 3) end
  return value
end

local function callUnsubscribers(installed)
  local pending, failures = {}, {}
  for index = #(installed.unsubscribers or {}), 1, -1 do
    local unsubscribe = installed.unsubscribers[index]
    local ok, value = pcall(unsubscribe)
    if not ok or value == false then
      table.insert(pending, 1, unsubscribe)
      failures[#failures + 1] = safeText(ok and value or value,
        "unsubscribe failed")
    end
  end
  installed.unsubscribers = pending
  if #failures > 0 then return false, table.concat(failures, "; ") end
  return true
end

function Card.descriptor(dependencies)
  local mod = dependency(dependencies, "mod")
  local lifecycle = dependency(dependencies, "lifecycle")
  local legacy = dependency(dependencies, "legacyRenderer")
  local resolveMode = dependencies.resolveMode or function(payload)
    payload = type(payload) == "table" and payload or {}
    return payload.requestedMode or payload.provider or payload.mode
      or "DEFAULT"
  end
  local watchdogExpired = dependencies.watchdogExpired
  local onRuntimeFailure = dependencies.onRuntimeFailure

  local function withRouter(installed, operation, callback)
    local handle, acquireReason = RouterOwnerControl.acquire(
      installed.router, operation)
    if type(handle) ~= "table"
        or handle.schema ~= "ascendant.battle-router-transaction/v1"
        or type(handle.service) ~= "table"
        or type(handle.release) ~= "function" then
      return nil, acquireReason or "Gen2 Router transaction declined"
    end
    local ok, value, detail = pcall(callback, handle.service)
    local releaseOK, released, releaseReason = pcall(handle.release)
    if not releaseOK or released ~= true then
      return nil, safeText(releaseOK and releaseReason or released,
        "Gen2 Router transaction release failed")
    end
    if not ok then
      return nil, safeText(value, "Gen2 Router callback threw")
    end
    return value, detail
  end

  local function legacyCall(method, owner, event, reason)
    local callback = legacy[method]
    if type(callback) ~= "function" then
      return nil, "legacy Gen2 renderer has no " .. method .. " seam"
    end
    local ok, value, detail = pcall(callback, owner, event, reason)
    if not ok then
      return nil, "legacy Gen2 renderer " .. method .. " threw: "
        .. safeText(value, "unprintable renderer error")
    end
    if value == false or value == nil then
      return nil, safeText(detail,
        "legacy Gen2 renderer declined " .. method)
    end
    if method ~= "finish" and method ~= "abort"
        and type(legacy.owns) == "function" then
      local ownsOK, owns = pcall(legacy.owns, owner)
      if not ownsOK or owns ~= true then
        return nil, "legacy Gen2 renderer lost exact owner after " .. method
      end
    end
    return value, detail
  end

  local function routerContext(raw, extra)
    local context = {
      provider="DEFAULT",
      requestedMode=raw.requestedMode,
      battleToken=raw.battleToken,
      deploymentToken=raw.deploymentToken,
      side=raw.side,
      entry=raw.entry,
    }
    if type(extra) == "table" then
      for key, value in pairs(extra) do context[key] = value end
    end
    return context
  end

  local function cleanup(installed, reason)
    if type(installed) ~= "table" then return true end
    if installed.cleanupComplete then return true end
    if type(lifecycle.canCleanup) ~= "function" then
      return false, "Gen2 lifecycle cleanup preflight is unavailable"
    end
    local ready, readyReason = lifecycle:canCleanup()
    if ready ~= true then return false, readyReason end
    installed.retiring = true
    local unsubscribed, unsubscribeReason = callUnsubscribers(installed)
    if not unsubscribed then return false, unsubscribeReason end

    local current = lifecycle:current()
    if current ~= nil then
      local owner = current.owner
      if current.provider == "DEFAULT" then
        if installed.router and installed.router.owns(owner) then
          local aborted, abortReason = withRouter(installed,
            "gen2-lifecycle-cleanup", function(router)
              return router.abort(owner,
                reason or "Gen2-lifecycle-card-cleanup")
            end)
          if aborted ~= true then return false, abortReason end
        end
      elseif TRANSITIONAL[current.provider] then
        local shouldAbort = true
        if type(legacy.owns) == "function" then
          local ownsOK, owns = pcall(legacy.owns, owner)
          if not ownsOK then return false, safeText(owns) end
          shouldAbort = owns == true
        end
        if shouldAbort then
          local aborted, abortReason = legacyCall("abort", owner, {
            kind="cleanup",
            receipt=current,
          }, reason or "Gen2-lifecycle-card-cleanup")
          if aborted == nil then return false, abortReason end
        end
      end
    end

    if installed.criticalUnsubscribe ~= nil then
      local ok, value = pcall(installed.criticalUnsubscribe)
      if not ok or value == false then
        return false, safeText(ok and value or value,
          "critical lifecycle unsubscribe failed")
      end
      installed.criticalUnsubscribe = nil
    end
    if installed.relayUnsubscribe ~= nil then
      local ok, value = pcall(installed.relayUnsubscribe)
      if not ok or value == false then
        return false, safeText(ok and value or value,
          "lifecycle relay unsubscribe failed")
      end
      installed.relayUnsubscribe = nil
    end
    if current ~= nil then
      local aborted, abortReason = lifecycle:cleanupAbort(current.owner,
        reason or "Gen2-lifecycle-card-cleanup")
      if aborted == nil then return false, abortReason end
    end
    installed.cleanupComplete = true
    installed.router = nil
    return true
  end

  local function subscribeEngine(installed, name, callback)
    local ok, unsubscribe = pcall(mod.events.on, mod.events, name, callback)
    if not ok or type(unsubscribe) ~= "function" then
      return false, ("unable to subscribe %s: %s"):format(name,
        safeText(unsubscribe, "engine subscription failed"))
    end
    installed.unsubscribers[#installed.unsubscribers + 1] = unsubscribe
    return true
  end

  return {
    schema="ascendant.card/v1",
    id=Card.ID,
    version=Card.VERSION,
    owner="voxel_ascendant",
    requires={},
    optionalRequires={},
    consumes={ Card.ROUTER_CAPABILITY },
    provides={ Card.CAPABILITY },
    tests={
      "tests/gen2_battle_lifecycle_adapter_test.lua",
      "tests/gen2_battle_lifecycle_card_test.lua",
      "tests/gen2_battle_renderer_adapter_test.lua",
    },
    docs={ "docs/maintainer/RC11_ARCHITECTURE.md" },
    saveNamespace=false,
    impact={
      runtimeOwners={ "gen2.battle.lifecycle" },
      saveWrites={},
      publicHooks={ Card.EVENT, Card.PUBLIC_EVENT },
      files={
        "gen2/lib/adapters/gen2/Gen2BattleLifecycle.lua",
        "gen2/lib/adapters/gen2/Gen2BattleRenderer.lua",
        "gen2/lib/cards/battle_router/Gen2BattleLifecycleCard.lua",
      },
    },
    lifecycle={
      install=function()
        if type(mod.events) ~= "table"
            or type(mod.events.on) ~= "function"
            or type(mod.events.emit) ~= "function" then
          return false, "Gen2 mod event API is unavailable"
        end
        for _, name in ipairs({
          "started", "screenPushed", "battlerSwitched", "moveUsed",
          "logicEnded", "screenPopped", "watchdogAbort", "cleanupAbort",
          "current", "subscribeCritical", "subscribe", "publicEvent",
          "public", "health",
        }) do
          if type(lifecycle[name]) ~= "function" then
            return false, "Gen2 lifecycle seam is unavailable: " .. name
          end
        end
        for _, name in ipairs({
          "start", "bind", "switch", "finish", "abort", "owns", "health",
        }) do
          if type(legacy[name]) ~= "function" then
            return false, "legacy Gen2 renderer seam is unavailable: " .. name
          end
        end
        if type(resolveMode) ~= "function" then
          return false, "Gen2 battle mode resolver is unavailable"
        end
        if watchdogExpired ~= nil and type(watchdogExpired) ~= "function" then
          return false, "Gen2 battle watchdog predicate is invalid"
        end
        if onRuntimeFailure ~= nil
            and type(onRuntimeFailure) ~= "function" then
          return false, "Gen2 runtime-failure observer is invalid"
        end
        return { unsubscribers={} }
      end,

      activate=function(context, installed)
        installed.unsubscribers = {}
        installed.criticalUnsubscribe = nil
        installed.relayUnsubscribe = nil
        installed.runtimeFailure = nil
        installed.runtimeFailureNotified = false
        installed.retiring = false
        installed.cleanupComplete = false

        local capability, capabilityReason =
          context.capability(Card.ROUTER_CAPABILITY)
        local router = capability and capability.value or nil
        if type(router) ~= "table"
            or router.schema ~= "ascendant.battle-router/v1"
            or router.generation ~= 2
            or type(router.start) ~= "function"
            or type(router.owns) ~= "function"
            or type(router.switch) ~= "function"
            or type(router.finish) ~= "function"
            or type(router.abort) ~= "function"
            or type(router.health) ~= "function" then
          return false, capabilityReason or "Gen2 Router is unavailable"
        end
        installed.router = router

        local function route(event)
          local raw = type(event) == "table" and event.receipt or nil
          local owner = type(raw) == "table" and raw.owner or nil
          if owner == nil then return false, "Gen2 lifecycle omitted owner" end
          local kind = event.kind
          if raw.provider == "DEFAULT" then
            if kind == "started" then
              local started, reason = withRouter(installed,
                "gen2-default-start", function(exactRouter)
                  return exactRouter.start(owner, routerContext(raw))
                end)
              if started == nil then return false, reason end
            elseif kind == "battler-switched" then
              local switched, reason = withRouter(installed,
                "gen2-default-switch", function(exactRouter)
                  return exactRouter.switch(owner, routerContext(raw))
                end)
              if switched == nil then return false, reason end
            elseif kind == "screen-popped" then
              local finished, reason = withRouter(installed,
                "gen2-default-finish", function(exactRouter)
                  return exactRouter.finish(owner, routerContext(raw, {
                    result=raw.reason,
                  }))
                end)
              if finished == nil then return false, reason end
            elseif kind == "watchdog-aborted" then
              local aborted, reason = withRouter(installed,
                "gen2-default-watchdog-abort", function(exactRouter)
                  return exactRouter.abort(owner,
                    raw.reason or "Gen2-watchdog-aborted")
                end)
              if aborted ~= true then return false, reason end
            elseif kind == "screen-bound" or kind == "logic-ended"
                or kind == "move-observed" then
              -- move-observed intentionally does not call Router.attack.
              if not router.owns(owner) then
                return false, "Gen2 DEFAULT lost exact Router owner"
              end
            else
              return false, "unsupported Gen2 DEFAULT transition "
                .. safeText(kind)
            end
            return true
          end

          if not TRANSITIONAL[raw.provider] then
            return false, "unknown transitional Gen2 provider "
              .. safeText(raw.provider)
          end
          if kind == "started" then
            local value, reason = legacyCall("start", owner, event)
            if value == nil then return false, reason end
          elseif kind == "screen-bound" then
            local value, reason = legacyCall("bind", owner, event)
            if value == nil then return false, reason end
          elseif kind == "battler-switched" then
            local value, reason = legacyCall("switch", owner, event)
            if value == nil then return false, reason end
          elseif kind == "screen-popped" then
            local value, reason = legacyCall("finish", owner, event)
            if value == nil then return false, reason end
          elseif kind == "watchdog-aborted" then
            local value, reason = legacyCall("abort", owner, event,
              raw.reason or "Gen2-watchdog-aborted")
            if value == nil then return false, reason end
          elseif kind == "logic-ended" or kind == "move-observed" then
            -- Neither transition may finish or animate the legacy renderer.
            if type(legacy.owns) == "function" then
              local ok, owns = pcall(legacy.owns, owner)
              if not ok or owns ~= true then
                return false, "legacy Gen2 renderer lost exact owner"
              end
            end
          else
            return false, "unsupported transitional Gen2 transition "
              .. safeText(kind)
          end
          return true
        end

        local function compensate(event, reason)
          local raw = type(event) == "table" and event.receipt or nil
          local owner = type(raw) == "table" and raw.owner or nil
          if owner == nil then return false end
          if router.owns(owner) then
            local aborted = withRouter(installed,
              "gen2-transition-compensation", function(exactRouter)
                return exactRouter.abort(owner,
                  reason or "Gen2-transition-compensation")
              end)
            return aborted == true
          end
          if raw and TRANSITIONAL[raw.provider] then
            local shouldAbort = true
            if type(legacy.owns) == "function" then
              local ok, owns = pcall(legacy.owns, owner)
              if not ok then return false end
              shouldAbort = owns == true
            end
            if shouldAbort then
              local aborted = legacyCall("abort", owner, event,
                reason or "Gen2-transition-compensation")
              return aborted ~= nil
            end
          end
          return true
        end

        local critical, criticalReason = lifecycle:subscribeCritical(
          Card.ID .. ".provider-owner", route, compensate)
        if type(critical) ~= "function" then
          cleanup(installed, "Gen2-critical-subscription-failed")
          return false, criticalReason
        end
        installed.criticalUnsubscribe = critical

        local relay, relayReason = lifecycle:subscribe(Card.ID .. ".relay",
          function(event)
            local public = lifecycle:publicEvent(event)
            if public == nil then return false end
            context.hooks.emit(Card.EVENT, public)
            mod.events:emit(Card.PUBLIC_EVENT, public)
            return true
          end, -1000)
        if type(relay) ~= "function" then
          cleanup(installed, "Gen2-relay-subscription-failed")
          return false, relayReason
        end
        installed.relayUnsubscribe = relay

        local function failRuntime(phase, reason, payload)
          if installed.retiring then return nil end
          installed.runtimeFailure = "Gen2 battle lifecycle "
            .. safeText(phase, "runtime") .. " failed: "
            .. safeText(reason, "unprintable runtime error")
          local current = lifecycle:current()
          local screen = type(payload) == "table"
            and (rawget(payload, "state") or rawget(payload, "screen")) or nil
          local payloadLogic = type(payload) == "table"
            and (rawget(payload, "battle")
              or (type(screen) == "table" and rawget(screen, "battle")))
            or nil
          -- A replacement start can fail before lifecycle:started(B) commits,
          -- while lifecycle:current() still names A. The engine nevertheless
          -- continues constructing B after this synchronous event, so recovery
          -- must quarantine B, not the owner which rollback just retired.
          local startFailure = phase == "start"
          local failureLogic, failureScreen
          if startFailure then
            failureLogic = payloadLogic
            failureScreen = screen
          else
            failureLogic = (current and current.logic) or payloadLogic
            failureScreen = (current and current.screen) or screen
          end
          local failureOwner = {
            logic=failureLogic,
            screen=failureScreen,
            phase=phase,
            postStartCleanup=startFailure,
          }
          local ok, value = pcall(context.fail, installed.runtimeFailure)
          if not ok then
            cleanup(installed, installed.runtimeFailure)
          end
          local fallbackSafe = ok and value == true
          if not installed.runtimeFailureNotified
              and type(onRuntimeFailure) == "function" then
            installed.runtimeFailureNotified = true
            pcall(onRuntimeFailure, installed.runtimeFailure, fallbackSafe,
              failureOwner)
          end
          return nil, installed.runtimeFailure
        end

        local function guarded(phase, payload, callback)
          if installed.retiring then return nil end
          local ok, value, detail, ignored = pcall(callback)
          if not ok then return failRuntime(phase, value, payload) end
          if value == nil and ignored ~= true then
            return failRuntime(phase, detail, payload)
          end
          return value, detail
        end

        local subscriptions = {
          { "battle.started", function(payload)
            return guarded("start", payload, function()
              local ok, mode = pcall(resolveMode, payload)
              if not ok then error(mode, 0) end
              local normalized = lifecycle.normalizeProvider
                and lifecycle.normalizeProvider(mode) or mode
              if normalized == nil then
                error("unknown Gen2 battle mode " .. safeText(mode), 0)
              end
              return lifecycle:started(payload, {
                provider=normalized,
                requestedMode=normalized,
                entry="engine.battle.started",
              })
            end)
          end },
          { "screen.pushed", function(payload)
            return guarded("screen-pushed", payload, function()
              return lifecycle:screenPushed(payload)
            end)
          end },
          { "battle.battler_switched", function(payload)
            return guarded("switch", payload, function()
              return lifecycle:battlerSwitched(payload)
            end)
          end },
          { "battle.move_used", function(payload)
            return guarded("move-observed", payload, function()
              return lifecycle:moveUsed(payload)
            end)
          end },
          { "battle.ended", function(payload)
            return guarded("logic-end", payload, function()
              return lifecycle:logicEnded(payload)
            end)
          end },
          { "screen.popped", function(payload)
            return guarded("screen-popped", payload, function()
              return lifecycle:screenPopped(payload)
            end)
          end },
        }
        if watchdogExpired ~= nil then
          subscriptions[#subscriptions + 1] = { "world.stepped",
            function(payload)
              return guarded("watchdog", payload, function()
                local current = lifecycle:current()
                if current == nil then return true end
                local ok, expired = pcall(watchdogExpired, current, payload)
                if not ok then error(expired, 0) end
                if expired ~= true then return true end
                return lifecycle:watchdogAbort(current.owner,
                  "Gen2-stack-watchdog")
              end)
            end }
        end
        for _, entry in ipairs(subscriptions) do
          local subscribed, reason = subscribeEngine(
            installed, entry[1], entry[2])
          if subscribed ~= true then
            cleanup(installed, "Gen2-engine-subscription-failed")
            return false, reason
          end
        end
        return installed, lifecycle:public()
      end,

      deactivate=function(_, active, reason)
        return cleanup(active, reason or "Gen2-lifecycle-card-deactivated")
      end,

      abort=function(_, _, reason, installed, active)
        return cleanup(active or installed,
          reason or "Gen2-lifecycle-card-aborted")
      end,

      health=function(_, installed, active)
        local state = active or installed
        local lifecycleHealth = lifecycle:health()
        local routerHealth = state and state.router
          and state.router.health and state.router.health() or nil
        local legacyOK, legacyHealth = pcall(legacy.health)
        if not legacyOK or type(legacyHealth) ~= "table" then
          legacyHealth = {
            schema="ascendant.compat-status/v1",
            ok=false,
            state="error",
            error=safeText(legacyHealth, "legacy health failed"),
          }
        end
        return {
          schema="ascendant.compat-status/v1",
          apiVersion=1,
          generation=2,
          ok=state ~= nil
            and state.retiring ~= true
            and state.runtimeFailure == nil
            and type(lifecycleHealth) == "table"
            and lifecycleHealth.ok == true
            and type(routerHealth) == "table"
            and routerHealth.ok == true
            and legacyHealth.ok == true,
          state=state and (state.retiring and "retiring" or "active")
            or "inactive",
          runtimeFailure=state and state.runtimeFailure or nil,
          lifecycle=lifecycleHealth,
          router=routerHealth,
          legacy=legacyHealth,
          movePresentationOwner="animForMove",
          terminalOwner="exact-screen-pop-or-watchdog",
        }
      end,
    },
  }
end

return Card
