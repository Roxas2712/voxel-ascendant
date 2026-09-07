-- Owner-scoped Gen-1 DISCS provider Card.
--
-- Stage construction remains in the legacy entry path for this first vertical
-- slice.  The provider adopts only an already-prepared private renderer
-- session and never emits lifecycle events or retires external battle content.

local Card = {
  ID = "vasc.gen1.battle-provider.discs",
  VERSION = "1.0.0",
  CAPABILITY = "ascendant.battle-provider.discs/v1",
}

local PROVIDER = "DISCS"
local PROVIDER_SCHEMA = "ascendant.battle-provider/v1"
local PROVIDER_STATE_SCHEMA = "ascendant.battle-provider-state/v1"
local ROUTER_RECEIPT_SCHEMA = "ascendant.battle-provider-receipt/v1"
local RENDERER_SESSION_SCHEMA =
  "ascendant.gen1-battle-renderer-session/v1"
local RENDERER_OWNER_SCHEMA =
  "ascendant.gen1-battle-renderer-owner/v1"

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

local function positiveInteger(value)
  return type(value) == "number" and value >= 1 and value % 1 == 0
end

local function nonNegativeInteger(value)
  return type(value) == "number" and value >= 0 and value % 1 == 0
end

local function requireDependency(dependencies, name)
  local value = dependencies and dependencies[name]
  if value == nil then
    error("Gen1DiscsBattleProviderCard needs " .. name, 3)
  end
  return value
end

local function validRenderer(renderer)
  if type(renderer) ~= "table"
      or renderer.schema ~= RENDERER_SESSION_SCHEMA
      or renderer.apiVersion ~= 1
      or renderer.generation ~= 1 then
    return false
  end
  for _, method in ipairs({
    "adopt", "switch", "finish", "abort", "owns", "owner", "health",
  }) do
    if type(renderer[method]) ~= "function" then return false end
  end
  return true
end

local function contextTokens(context)
  if type(context) ~= "table" then
    return nil, nil, "lifecycle context is required"
  end
  if context.provider ~= nil and context.provider ~= PROVIDER then
    return nil, nil, "lifecycle provider mismatch"
  end
  if not positiveInteger(context.battleToken) then
    return nil, nil, "battleToken must be a positive integer"
  end
  if not nonNegativeInteger(context.deploymentToken) then
    return nil, nil, "deploymentToken must be a non-negative integer"
  end
  return context.battleToken, context.deploymentToken
end

local function exactRoute(context, routerReceipt)
  local battleToken, deploymentToken, reason = contextTokens(context)
  if not battleToken then return nil, nil, reason end
  if type(routerReceipt) ~= "table"
      or routerReceipt.schema ~= ROUTER_RECEIPT_SCHEMA
      or routerReceipt.apiVersion ~= 1
      or routerReceipt.generation ~= 1
      or routerReceipt.provider ~= PROVIDER
      or not positiveInteger(routerReceipt.battleToken)
      or not nonNegativeInteger(routerReceipt.deploymentToken) then
    return nil, nil, "exact DISCS router receipt is required"
  end
  if routerReceipt.battleToken ~= battleToken then
    return nil, nil, "battle token diverged from router receipt"
  end
  if routerReceipt.deploymentToken ~= deploymentToken then
    return nil, nil, "deployment token diverged from router receipt"
  end
  return battleToken, deploymentToken
end

local function exactAbortRoute(routerReceipt)
  if type(routerReceipt) ~= "table"
      or routerReceipt.schema ~= ROUTER_RECEIPT_SCHEMA
      or routerReceipt.apiVersion ~= 1
      or routerReceipt.generation ~= 1
      or routerReceipt.provider ~= PROVIDER
      or not positiveInteger(routerReceipt.battleToken)
      or not nonNegativeInteger(routerReceipt.deploymentToken) then
    return nil, nil, "exact DISCS router receipt is required"
  end
  return routerReceipt.battleToken, routerReceipt.deploymentToken
end

local function rendererOwner(active, deploymentToken)
  return {
    schema=RENDERER_OWNER_SCHEMA,
    apiVersion=1,
    ownerKind="provider",
    provider=PROVIDER,
    battleToken=active.battleToken,
    deploymentToken=deploymentToken or active.rendererDeploymentToken,
  }
end

local function routeDeployment(active)
  return active.pendingDeploymentToken or active.deploymentToken
end

local function recordMatches(record, battleToken, deploymentToken)
  return type(record) == "table"
    and record.battleToken == battleToken
    and record.deploymentToken == deploymentToken
end

local function activeRouteMatches(active, battle, battleToken,
                                  deploymentToken)
  return active ~= nil
    and sameBattle(active.battle, battle)
    and active.battleToken == battleToken
    and routeDeployment(active) == deploymentToken
end

local function providerReceipt(owner, record, state, operation, reason)
  local receipt = {
    schema=PROVIDER_STATE_SCHEMA,
    apiVersion=1,
    generation=1,
    provider=PROVIDER,
    ownerKind="provider",
    state=state or (record and record.state) or "idle",
    battleToken=record and record.battleToken or nil,
    deploymentToken=record and (record.pendingDeploymentToken
      or record.deploymentToken) or nil,
    rendererDeploymentToken=record and record.rendererDeploymentToken or nil,
    operation=operation,
    reason=reason,
    starts=owner.starts,
    switches=owner.switches,
    attacks=owner.attacks,
    finishes=owner.finishes,
    aborts=owner.aborts,
    failures=owner.failures,
  }
  if operation == "attack" then
    receipt.rendererNeutral = true
    receipt.rendered = false
  end
  return receipt
end

local function callRenderer(owner, method, ...)
  local callback = owner.renderer[method]
  local ok, value, detail = pcall(callback, ...)
  if not ok then
    return nil, ("DISCS renderer %s threw: %s"):format(
      method, safeText(value, "unprintable renderer error"))
  end
  if value == false or value == nil then
    return nil, safeText(detail, "DISCS renderer declined " .. method)
  end
  return value, detail
end

-- The private renderer owner receipt intentionally contains no BattleState.
-- Exact battle identity is established by the argument to renderer.owner()
-- and renderer.owns(), both of which are required to use rawequal internally.
local function rendererOwnerState(owner, battle)
  local ok, raw = pcall(owner.renderer.owner, battle)
  if not ok then
    return nil, "DISCS renderer owner threw: "
      .. safeText(raw, "unprintable renderer owner error")
  end
  if raw == nil then return nil, nil, "absent" end
  if type(raw) == "table" and raw.state == "prepared"
      and raw.provider == PROVIDER and raw.ownerKind == nil then
    return nil, nil, "prepared"
  end
  if type(raw) ~= "table"
      or raw.schema ~= RENDERER_OWNER_SCHEMA
      or raw.apiVersion ~= 1
      or raw.ownerKind ~= "provider"
      or raw.provider ~= PROVIDER
      or not positiveInteger(raw.battleToken)
      or not nonNegativeInteger(raw.deploymentToken)
      or type(raw.state) ~= "string" then
    return nil, "invalid DISCS renderer owner receipt"
  end
  return {
    battleToken=raw.battleToken,
    deploymentToken=raw.deploymentToken,
    state=raw.state,
  }, nil, "owned"
end

local function rendererOwns(owner, battle, expected)
  local ok, value = pcall(owner.renderer.owns, battle)
  if not ok then
    return false, "DISCS renderer owns threw: "
      .. safeText(value, "unprintable renderer owns error")
  end
  if value ~= expected then
    return false, expected and "DISCS renderer did not acquire exact battle"
      or "DISCS renderer retained exact battle"
  end
  return true
end

local function exactRendererState(owner, active, expectedDeployment,
                                  expectedState, expectedOwns)
  local current, reason = rendererOwnerState(owner, active.battle)
  if not current then
    return nil, reason or "DISCS renderer owner is unavailable"
  end
  if current.battleToken ~= active.battleToken
      or current.deploymentToken ~= expectedDeployment
      or current.state ~= expectedState then
    return nil, "DISCS renderer owner mismatch"
  end
  local owns, ownsReason = rendererOwns(
    owner, active.battle, expectedOwns)
  if not owns then return nil, ownsReason end
  return current
end

local function rememberTerminal(owner, active, state, reason)
  owner.terminals[active.battle] = {
    battleToken=active.battleToken,
    deploymentToken=routeDeployment(active),
    rendererDeploymentToken=active.rendererDeploymentToken,
    state=state,
    reason=reason,
  }
  owner.active = nil
end

local function failOperation(owner, active, operation, reason)
  owner.failures = owner.failures + 1
  owner.lastError = safeText(reason, "DISCS provider operation failed")
  if active ~= nil then
    active.state = "rollback_pending"
    active.pendingOperation = operation
    active.reason = owner.lastError
  end
  return false, owner.lastError
end

local function clearFailure(owner, active)
  owner.lastError = nil
  if active then
    active.state = "active"
    active.pendingOperation = nil
    active.reason = nil
  end
end

local function terminalReceipt(owner, battle, battleToken, deploymentToken,
                               operation)
  local terminal = owner.terminals[battle]
  if not recordMatches(terminal, battleToken, deploymentToken) then return nil end
  return providerReceipt(owner, terminal, terminal.state, operation,
    terminal.reason)
end

local function finishActive(owner, active, reason)
  local current, currentReason = rendererOwnerState(owner, active.battle)
  if not current then
    return failOperation(owner, active, "finish",
      currentReason or "DISCS renderer owner is unavailable")
  end
  if current.battleToken ~= active.battleToken
      or current.deploymentToken ~= active.rendererDeploymentToken then
    return failOperation(owner, active, "finish",
      "DISCS renderer finish owner mismatch")
  end
  if current.state == "ended" then
    local owns, ownsReason = rendererOwns(owner, active.battle, false)
    if not owns then return failOperation(owner, active, "finish", ownsReason) end
  elseif current.state == "active" then
    local finished, finishReason = callRenderer(owner, "finish",
      active.battle, rendererOwner(active))
    if not finished then
      return failOperation(owner, active, "finish", finishReason)
    end
    local exact, exactReason = exactRendererState(owner, active,
      active.rendererDeploymentToken, "ended", false)
    if not exact then
      return failOperation(owner, active, "finish", exactReason)
    end
  else
    return failOperation(owner, active, "finish",
      "DISCS renderer is already terminal: " .. current.state)
  end
  owner.finishes = owner.finishes + 1
  clearFailure(owner)
  rememberTerminal(owner, active, "ended", reason)
  return providerReceipt(owner, owner.terminals[active.battle],
    "ended", "finish", reason)
end

local function abortActive(owner, active, reason)
  local current, currentReason, currentDisposition =
    rendererOwnerState(owner, active.battle)
  if not current then
    -- adopt() may have returned after mutating the private renderer while its
    -- owner probe was temporarily unavailable.  Keep that ambiguity under
    -- provider ownership until a later probe proves either the exact owner or
    -- that no provider session was acquired.  Only the latter permits a
    -- no-renderer-call compensation.
    if currentReason == nil and active.acquisitionAmbiguous == true
        and (currentDisposition == "absent"
          or currentDisposition == "prepared") then
      owner.aborts = owner.aborts + 1
      clearFailure(owner)
      rememberTerminal(owner, active, "aborted", reason)
      return providerReceipt(owner, owner.terminals[active.battle],
        "aborted", "abort", reason)
    end
    return failOperation(owner, active, "abort",
      currentReason or "DISCS renderer owner is unavailable")
  end
  local exactDeployment = current.deploymentToken
    == active.rendererDeploymentToken
    or (active.pendingDeploymentToken ~= nil
      and current.deploymentToken == active.pendingDeploymentToken)
  if current.battleToken ~= active.battleToken or not exactDeployment then
    return failOperation(owner, active, "abort",
      "DISCS renderer abort owner mismatch")
  end
  -- A renderer switch can commit its new token before the postcondition probe
  -- fails.  The Router receipt still names that exact pending token, so adopt
  -- the probed token only when it is either the last confirmed token or that
  -- one pending successor.  Arbitrary tokens remain fail-closed.
  active.rendererDeploymentToken = current.deploymentToken
  active.acquisitionAmbiguous = false
  local terminalState
  if current.state == "active" then
    local aborted, abortReason = callRenderer(owner, "abort",
      active.battle, reason,
      rendererOwner(active, current.deploymentToken))
    if not aborted then
      return failOperation(owner, active, "abort", abortReason)
    end
    local exact, exactReason = exactRendererState(owner, active,
      active.rendererDeploymentToken, "aborted", false)
    if not exact then
      return failOperation(owner, active, "abort", exactReason)
    end
    terminalState = "aborted"
  elseif current.state == "aborted" or current.state == "native"
      or current.state == "ended" then
    local owns, ownsReason = rendererOwns(owner, active.battle, false)
    if not owns then return failOperation(owner, active, "abort", ownsReason) end
    terminalState = current.state
  else
    return failOperation(owner, active, "abort",
      "DISCS renderer abort state mismatch: " .. current.state)
  end
  owner.aborts = owner.aborts + 1
  clearFailure(owner)
  rememberTerminal(owner, active, terminalState, reason)
  return providerReceipt(owner, owner.terminals[active.battle],
    terminalState, "abort", reason)
end

local function buildProvider(owner)
  return {
    schema=PROVIDER_SCHEMA,
    apiVersion=1,
    id=PROVIDER,
    version=Card.VERSION,
    generation=1,
    native=false,
    priority=100,

    canHandle=function(context)
      if owner.retired then return false, "DISCS provider is retired" end
      if type(context) ~= "table" or context.provider ~= PROVIDER then
        return false, "DISCS provider mismatch"
      end
      local battleToken, _, reason = contextTokens(context)
      if not battleToken then return false, reason end
      return true
    end,

    start=function(battle, context, routerReceipt)
      if owner.retired then return false, "DISCS provider is retired" end
      if battle == nil then return false, "battle owner is required" end
      local battleToken, deploymentToken, reason = exactRoute(
        context, routerReceipt)
      if not battleToken then return false, reason end
      if deploymentToken ~= 0 then
        return false, "DISCS start deploymentToken must equal 0"
      end

      local active = owner.active
      if active ~= nil then
        if not activeRouteMatches(active, battle, battleToken,
            deploymentToken) then
          return false, "battle owner mismatch"
        end
        if active.state ~= "active" then
          return false, "DISCS provider cleanup is pending"
        end
        return providerReceipt(owner, active, "active", "start")
      end
      local terminal = owner.terminals[battle]
      if recordMatches(terminal, battleToken, deploymentToken) then
        return false, "DISCS battle owner is already terminal"
      end

      local candidate = {
        battle=battle,
        battleToken=battleToken,
        deploymentToken=deploymentToken,
        rendererDeploymentToken=deploymentToken,
        acquisitionAmbiguous=false,
        state="starting",
      }
      local adopted, adoptReason = callRenderer(owner, "adopt",
        battle, rendererOwner(candidate, deploymentToken))
      local exact, exactReason = exactRendererState(owner, candidate,
        deploymentToken, "active", true)
      if not adopted or not exact then
        -- A throwing/false renderer may have acquired the exact owner before
        -- reporting failure. Preserve that owner for Router compensation; an
        -- untouched preparation remains outside this provider's authority.
        local current, currentReason = rendererOwnerState(owner, battle)
        if current and current.state == "active"
            and current.battleToken == battleToken
            and current.deploymentToken == deploymentToken then
          owner.active = candidate
          candidate.state = "rollback_pending"
        elseif currentReason ~= nil then
          -- We cannot distinguish an untouched preparation from a renderer
          -- that acquired the exact owner before its owner() seam failed.
          -- Retain a retryable provider record so Router compensation cannot
          -- silently strand a raw renderer session.
          owner.active = candidate
          candidate.state = "rollback_pending"
          candidate.acquisitionAmbiguous = true
        else
          owner.failedStarts[battle] = {
            battleToken=battleToken,
            deploymentToken=deploymentToken,
          }
        end
        return failOperation(owner, owner.active, "start",
          adoptReason or exactReason or "DISCS renderer adopt failed")
      end

      owner.active = candidate
      owner.terminals[battle] = nil
      owner.failedStarts[battle] = nil
      owner.starts = owner.starts + 1
      clearFailure(owner, candidate)
      return providerReceipt(owner, candidate, "active", "start")
    end,

    switch=function(battle, context, routerReceipt)
      if owner.retired then return false, "DISCS provider is retired" end
      local battleToken, deploymentToken, reason = exactRoute(
        context, routerReceipt)
      if not battleToken then return false, reason end
      local active = owner.active
      if active == nil or not sameBattle(active.battle, battle) then
        return false, "battle owner mismatch"
      end
      if active.battleToken ~= battleToken then
        return false, "battle token mismatch"
      end
      if active.pendingDeploymentToken ~= nil
          and active.pendingDeploymentToken ~= deploymentToken then
        return false, "DISCS provider cleanup is pending"
      end
      if deploymentToken == active.deploymentToken
          and active.pendingDeploymentToken == nil
          and active.state == "active" then
        return providerReceipt(owner, active, "active", "switch")
      end
      if deploymentToken <= active.deploymentToken then
        return false, "deployment token regressed"
      end

      -- Router has already advanced its authoritative deployment token before
      -- invoking this callback. Remember it even when the step is invalid so
      -- the compensating abort can validate the exact Router receipt, while
      -- still cleaning the last successfully adopted renderer owner below.
      active.pendingDeploymentToken = deploymentToken
      if deploymentToken ~= active.deploymentToken + 1 then
        return failOperation(owner, active, "switch",
          ("deployment token must advance exactly beyond %d")
            :format(active.deploymentToken))
      end

      local payload = type(context) == "table" and {
        side=context.side,
        battler=context.battler,
        previous=context.previous,
      } or {}
      local switched, switchReason = callRenderer(owner, "switch",
        battle, payload, rendererOwner(active, deploymentToken))
      if not switched then
        return failOperation(owner, active, "switch", switchReason)
      end
      local exact, exactReason = exactRendererState(owner, active,
        deploymentToken, "active", true)
      if not exact then
        return failOperation(owner, active, "switch", exactReason)
      end
      active.deploymentToken = deploymentToken
      active.rendererDeploymentToken = deploymentToken
      active.pendingDeploymentToken = nil
      owner.switches = owner.switches + 1
      clearFailure(owner, active)
      return providerReceipt(owner, active, "active", "switch")
    end,

    attack=function(battle, context, routerReceipt)
      if owner.retired then return false, "DISCS provider is retired" end
      local battleToken, deploymentToken, reason = exactRoute(
        context, routerReceipt)
      if not battleToken then return false, reason end
      local active = owner.active
      if active == nil or not sameBattle(active.battle, battle) then
        return false, "battle owner mismatch"
      end
      if active.pendingDeploymentToken ~= nil or active.state ~= "active" then
        return false, "DISCS provider cleanup is pending"
      end
      if active.battleToken ~= battleToken then
        return false, "battle token mismatch"
      end
      if active.deploymentToken ~= deploymentToken then
        return false, "deployment token mismatch"
      end
      -- Engine battle.move_used wiring is deliberately not part of this Card.
      -- A successful receipt proves only exact token validation; it never
      -- claims that an animation ran or mutates the renderer session.
      owner.attacks = owner.attacks + 1
      return providerReceipt(owner, active, "active", "attack")
    end,

    finish=function(battle, context, routerReceipt)
      if owner.retired then return false, "DISCS provider is retired" end
      local battleToken, deploymentToken, reason = exactRoute(
        context, routerReceipt)
      if not battleToken then return false, reason end
      local active = owner.active
      if active == nil then
        local repeated = terminalReceipt(owner, battle, battleToken,
          deploymentToken, "finish")
        if repeated and repeated.state == "ended" then return repeated end
        return false, "battle owner mismatch"
      end
      if not activeRouteMatches(active, battle, battleToken,
          deploymentToken) then
        return false, "battle owner mismatch"
      end
      if active.pendingDeploymentToken ~= nil then
        return false, "DISCS provider cleanup is pending"
      end
      return finishActive(owner, active, context and context.reason)
    end,

    abort=function(battle, reason, routerReceipt)
      if owner.retired then return false, "DISCS provider is retired" end
      if battle == nil then return false, "battle owner is required" end
      local battleToken, deploymentToken, receiptReason =
        exactAbortRoute(routerReceipt)
      if not battleToken then return false, receiptReason end
      local active = owner.active
      if active == nil then
        local failed = owner.failedStarts[battle]
        if recordMatches(failed, battleToken, deploymentToken) then
          owner.failedStarts[battle] = nil
          owner.aborts = owner.aborts + 1
          owner.lastError = nil
          local terminal = {
            battleToken=battleToken,
            deploymentToken=deploymentToken,
            rendererDeploymentToken=deploymentToken,
            state="aborted",
            reason=reason,
          }
          owner.terminals[battle] = terminal
          return providerReceipt(owner, terminal, "aborted", "abort", reason)
        end
        local repeated = terminalReceipt(owner, battle, battleToken,
          deploymentToken, "abort")
        if repeated then return repeated end
        return false, "battle owner mismatch"
      end
      if not activeRouteMatches(active, battle, battleToken,
          deploymentToken) then
        return false, "battle owner mismatch"
      end
      return abortActive(owner, active, reason)
    end,

    health=function()
      local rendererOK, rendererHealth = pcall(owner.renderer.health)
      local rendererValid = rendererOK
        and type(rendererHealth) == "table"
        and rendererHealth.schema == RENDERER_SESSION_SCHEMA
        and rendererHealth.apiVersion == 1
        and rendererHealth.generation == 1
      local active = owner.active
      local exact = true
      local exactReason
      if active ~= nil then
        local current, reason = rendererOwnerState(owner, active.battle)
        exact = current ~= nil
          and current.battleToken == active.battleToken
          and current.deploymentToken == active.rendererDeploymentToken
          and (current.state == "active" or current.state == "ended"
            or current.state == "aborted" or current.state == "native")
        if not exact then
          exactReason = reason or "DISCS renderer health owner mismatch"
        end
      end
      local ok = not owner.retired and owner.lastError == nil
        and rendererValid and exact
      return {
        schema="ascendant.compat-status/v1",
        apiVersion=1,
        ok=ok,
        state=owner.retired and "retired"
          or active and active.state or "idle",
        active=active ~= nil,
        provider=PROVIDER,
        ownerKind="provider",
        battleToken=active and active.battleToken or nil,
        deploymentToken=active and routeDeployment(active) or nil,
        rendererDeploymentToken=active
          and active.rendererDeploymentToken or nil,
        rendererState=rendererValid and rendererHealth.state or "unavailable",
        rendererActive=rendererValid
          and rendererHealth.active == true or false,
        starts=owner.starts,
        switches=owner.switches,
        attacks=owner.attacks,
        finishes=owner.finishes,
        aborts=owner.aborts,
        failures=owner.failures,
        error=owner.lastError or exactReason
          or (rendererOK and not rendererValid
            and "invalid DISCS renderer health receipt"
            or not rendererOK and ("DISCS renderer health threw: "
              .. safeText(rendererHealth,
                "unprintable renderer health error")) or nil),
      }
    end,
  }
end

local function retire(owner, reason)
  if type(owner) ~= "table" or owner.retired then return true end
  if owner.active ~= nil then
    local cleaned, cleanupReason = abortActive(owner, owner.active,
      reason or "DISCS provider retired")
    if not cleaned then return false, cleanupReason end
  end
  owner.failedStarts = setmetatable({}, { __mode="k" })
  owner.terminals = setmetatable({}, { __mode="k" })
  owner.retired = true
  return true
end

function Card.descriptor(dependencies)
  local renderer = requireDependency(dependencies, "renderer")
  return {
    schema="ascendant.card/v1",
    id=Card.ID,
    version=Card.VERSION,
    owner="voxel_ascendant",
    requires={},
    optionalRequires={},
    consumes={},
    provides={ Card.CAPABILITY },
    tests={ "tests/gen1_battle_provider_discs_test.lua" },
    docs={
      "docs/maintainer/RC11_ARCHITECTURE.md",
      "docs/maintainer/RC11_HOOK_OWNERSHIP.md",
      "docs/maintainer/RC11_TEST_MATRIX.md",
    },
    saveNamespace=false,
    impact={
      runtimeOwners={ "gen1.battle.provider.discs" },
      saveWrites={},
      publicHooks={},
      files={
        "lib/cards/battle_router/Gen1DiscsBattleProviderCard.lua",
      },
    },
    lifecycle={
      install=function()
        if type(renderer) ~= "table"
            or type(renderer.rendererSessionControlV1) ~= "function" then
          return false, "private Gen-1 renderer session seam is unavailable"
        end
        local ok, control = pcall(renderer.rendererSessionControlV1)
        if not ok or not validRenderer(control) then
          return false, ok
            and "private Gen-1 renderer session seam is unavailable"
            or ("private Gen-1 renderer session seam threw: "
              .. safeText(control, "unprintable renderer bind error"))
        end
        return { rendererSession=control }
      end,
      activate=function(_, installed)
        if type(installed) ~= "table"
            or not validRenderer(installed.rendererSession) then
          return false, "private Gen-1 renderer session seam was lost"
        end
        local owner = {
          renderer=installed.rendererSession,
          active=nil,
          terminals=setmetatable({}, { __mode="k" }),
          failedStarts=setmetatable({}, { __mode="k" }),
          retired=false,
          lastError=nil,
          starts=0,
          switches=0,
          attacks=0,
          finishes=0,
          aborts=0,
          failures=0,
        }
        return owner, buildProvider(owner)
      end,
      deactivate=function(_, owner, reason)
        return retire(owner, reason or "DISCS provider Card deactivated")
      end,
      abort=function(_, _, reason, _, owner)
        return retire(owner, reason or "DISCS provider Card aborted")
      end,
      health=function(_, _, owner)
        if not owner then
          return {
            schema="ascendant.compat-status/v1",
            apiVersion=1,
            ok=false,
            state="inactive",
            provider=PROVIDER,
          }
        end
        return buildProvider(owner).health()
      end,
    },
  }
end

return Card
