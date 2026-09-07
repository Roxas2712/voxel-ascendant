-- Exact-owner router for versioned battle presentation providers.
--
-- Registration is private to a built-in Card.  Consumers receive the public
-- service returned by public(), which can route an exact BattleState but
-- cannot add or replace providers.  A provider failure never selects another
-- non-native architecture implicitly.

local V = ...
assert(V and type(V.require) == "function", "BattleProviderRouter needs V.require")
local Contracts = assert(V.require("core/BattleProviderContracts"))

local Router = {}
Router.__index = Router
Router.SCHEMA = "ascendant.battle-router/v1"
Router.API_VERSION = 1

local ROLLBACK_PENDING_REASON = "battle provider rollback is pending"

local function safeText(value, fallback)
  if type(value) == "string" then return value end
  if value == nil then return fallback or "nil" end
  local ok, text = pcall(tostring, value)
  if ok and type(text) == "string" then return text end
  return fallback or ("<unprintable-%s>"):format(type(value))
end

local function rejectRollbackPending(self)
  local active = self.active
  if active and active.state == "rollback_pending" then
    return true, ROLLBACK_PENDING_REASON
  end
  return false
end

local function receipt(self, active)
  if not active then return nil end
  return {
    schema="ascendant.battle-provider-receipt/v1",
    apiVersion=Router.API_VERSION,
    generation=self.generation,
    battleToken=active.battleToken,
    deploymentToken=active.deploymentToken,
    provider=active.provider.id,
    requestedMode=active.requestedMode,
    state=active.state,
    reason=active.reason,
    native=active.provider.native,
  }
end

local function invoke(provider, method, ...)
  local ok, value, detail = pcall(provider[method], ...)
  if not ok then
    return nil, ("provider %s %s threw: %s"):format(
      provider.id, method, safeText(value, "unprintable callback error"))
  end
  if value == false or value == nil then
    return nil, safeText(detail, "provider " .. provider.id
      .. " declined " .. method)
  end
  return value, detail
end

-- Public mutations are serialized across provider callbacks.  Providers are
-- deliberately allowed to call read-only Router seams, but a synchronous
-- callback must not replace or clear the exact owner under the operation
-- which invoked it.  Internal compensation keeps using the same lease.
local function leaseLive(self, lease)
  return type(lease) == "table"
    and lease.live == true
    and rawequal(self.mutationLease, lease)
    and self.mutationEpoch == lease.epoch
end

local function outerLeaseLive(self, lease)
  return type(lease) == "table"
    and lease.live == true
    and rawequal(self.outerLease, lease)
    and self.outerEpoch == lease.epoch
end

local function beginMutation(self, operation, outerLease)
  local outer = self.outerLease
  if outer ~= nil then
    if outerLease == nil or not outerLeaseLive(self, outerLease) then
      return nil, ("battle router transaction is already in progress: %s; rejected %s")
        :format(safeText(outer.operation, "unknown"), operation)
    end
  elseif outerLease ~= nil then
    return nil, "battle router transaction lease is no longer active"
  end
  local busy = self.mutationLease
  if busy ~= nil then
    return nil, ("battle router mutation is already in progress: %s; rejected %s")
      :format(safeText(busy.operation, "unknown"), operation)
  end
  self.mutationEpoch = self.mutationEpoch + 1
  local lease = {
    epoch=self.mutationEpoch,
    operation=operation,
    live=true,
  }
  self.mutationLease = lease
  return lease
end

local function runMutation(self, operation, failureValue, callback, outerLease)
  local lease, busyReason = beginMutation(self, operation, outerLease)
  if not lease then return failureValue, busyReason end

  local ok, value, detail = pcall(callback, lease)
  local intact = leaseLive(self, lease)
  if rawequal(self.mutationLease, lease) then self.mutationLease = nil end
  lease.live = false

  if not ok then
    return failureValue, ("battle router %s threw: %s"):format(
      operation, safeText(value, "unprintable mutation error"))
  end
  if not intact then
    return failureValue,
      "battle router mutation lease changed during " .. operation
  end
  return value, detail
end

local function exactSnapshot(self)
  local active = self.active
  local snapshot = {
    active=active,
    enabled=self.enabled,
  }
  if active ~= nil then
    snapshot.battle = active.battle
    snapshot.battleToken = active.battleToken
    snapshot.deploymentToken = active.deploymentToken
    snapshot.provider = active.provider
    snapshot.requestedMode = active.requestedMode
    snapshot.state = active.state
    snapshot.reason = active.reason
  end
  return snapshot
end

local function exactPostcondition(self, lease, snapshot, provider, method)
  if not leaseLive(self, lease) then
    return false, ("provider %s %s changed the router mutation lease")
      :format(provider.id, method)
  end
  local active = self.active
  if not rawequal(active, snapshot.active)
      or self.enabled ~= snapshot.enabled then
    return false, ("provider %s %s changed the exact router owner")
      :format(provider.id, method)
  end
  if active ~= nil
      and (not rawequal(active.battle, snapshot.battle)
        or active.battleToken ~= snapshot.battleToken
        or active.deploymentToken ~= snapshot.deploymentToken
        or not rawequal(active.provider, snapshot.provider)
        or not rawequal(active.requestedMode, snapshot.requestedMode)
        or active.state ~= snapshot.state
        or active.reason ~= snapshot.reason) then
    return false, ("provider %s %s changed the exact router owner")
      :format(provider.id, method)
  end
  return true
end

local function invokeLeased(self, lease, provider, method, ...)
  if not leaseLive(self, lease) then
    return nil, "battle router mutation lease is not active", true
  end
  local snapshot = exactSnapshot(self)
  local value, detail = invoke(provider, method, ...)
  local exact, exactReason = exactPostcondition(
    self, lease, snapshot, provider, method)
  if not exact then return nil, exactReason, true end
  return value, detail, false
end

local function quarantineIntegrityFailure(self, expected, reason)
  self.failures = self.failures + 1
  if expected ~= nil and rawequal(self.active, expected) then
    expected.state = "rollback_pending"
    expected.reason = safeText(reason, "provider changed exact router owner")
  end
end

local function positiveInteger(value, field)
  value = tonumber(value)
  if value == nil or value < 1 or value % 1 ~= 0 then
    return nil, field .. " must be a positive integer"
  end
  return value
end

local function nonNegativeInteger(value, field)
  value = tonumber(value)
  if value == nil or value < 0 or value % 1 ~= 0 then
    return nil, field .. " must be a non-negative integer"
  end
  return value
end

local function tokens(context)
  local battleToken, reason = positiveInteger(
    context and context.battleToken, "battleToken")
  if not battleToken then return nil, nil, reason end
  local deploymentToken
  deploymentToken, reason = nonNegativeInteger(
    context and context.deploymentToken, "deploymentToken")
  if not deploymentToken then return nil, nil, reason end
  return battleToken, deploymentToken
end

function Router.new(options)
  options = options or {}
  local generation = tonumber(options.generation)
  assert(generation and generation >= 1 and generation % 1 == 0,
    "BattleProviderRouter needs a positive generation")
  return setmetatable({
    generation=generation,
    providers={},
    active=nil,
    failures=0,
    transitions=0,
    legacyPassThroughs=0,
    enabled=true,
    retiredReason=nil,
    mutationEpoch=0,
    mutationLease=nil,
    outerEpoch=0,
    outerLease=nil,
  }, Router)
end

local function registerMutation(self, raw)
  if not self.enabled then return false, "battle router is retired" end
  local provider, reason = Contracts.validate(raw)
  if not provider then return false, reason end
  if provider.generation ~= self.generation then
    return false, ("provider generation mismatch: expected %d, got %d")
      :format(self.generation, provider.generation)
  end
  if self.providers[provider.id] then
    return false, "provider is already registered: " .. provider.id
  end
  self.providers[provider.id] = provider
  return true, Contracts.metadata(provider)
end

function Router:register(raw)
  return runMutation(self, "register", false, function()
    return registerMutation(self, raw)
  end)
end

function Router:_abortActive(reason, lease)
  if not leaseLive(self, lease) then
    return false, "battle router abort needs the active mutation lease"
  end
  local active = self.active
  if not active then return true end
  local aborted, abortReason, invalidated = invokeLeased(
    self, lease, active.provider, "abort", active.battle,
    safeText(reason, "router-aborted"), receipt(self, active))
  if invalidated then
    quarantineIntegrityFailure(self, active, abortReason)
    return false, abortReason
  end
  if not aborted then
    active.state = "rollback_pending"
    active.reason = safeText(abortReason,
      safeText(reason, "router-abort-failed"))
    self.failures = self.failures + 1
    return false, active.reason
  end
  active.state = "aborted"
  active.reason = safeText(reason, "router-aborted")
  self.transitions = self.transitions + 1
  self.active = nil
  return true
end

local function startMutation(self, battle, context, lease)
  if not self.enabled then return nil, "battle router is retired" end
  local pending, pendingReason = rejectRollbackPending(self)
  if pending then return nil, pendingReason end
  if battle == nil then return nil, "battle owner is required" end
  context = type(context) == "table" and context or {}
  local providerId = context.provider
  if type(providerId) ~= "string" or providerId == "" then
    return nil, "provider id is required"
  end
  local battleToken, deploymentToken, tokenReason = tokens(context)
  if not battleToken then return nil, tokenReason end
  local requestedMode = context.requestedMode
  if requestedMode == nil then requestedMode = providerId end

  if self.active and rawequal(self.active.battle, battle) then
    if self.active.provider.id ~= providerId then
      return nil, ("battle provider mismatch: expected %s, got %s")
        :format(self.active.provider.id, providerId)
    end
    if self.active.battleToken ~= battleToken then
      return nil, ("battle token mismatch: expected %d, got %d")
        :format(self.active.battleToken, battleToken)
    end
    if self.active.deploymentToken ~= deploymentToken then
      return nil, ("deployment token mismatch: expected %d, got %d")
        :format(self.active.deploymentToken, deploymentToken)
    end
    if self.active.requestedMode ~= requestedMode then
      return nil, "requested mode mismatch"
    end
    return receipt(self, self.active)
  end

  if self.active then
    local retired, retireReason = self:_abortActive(
      "replaced-by-new-battle", lease)
    if not retired then return nil, retireReason end
  end

  local provider = self.providers[providerId]
  if not provider then
    self.legacyPassThroughs = self.legacyPassThroughs + 1
    return nil, "provider-not-registered:" .. providerId
  end
  local canHandle, handleReason, handleInvalidated = invokeLeased(
    self, lease, provider, "canHandle", context)
  if handleInvalidated then
    quarantineIntegrityFailure(self, nil, handleReason)
    return nil, handleReason
  end
  if not canHandle then
    self.failures = self.failures + 1
    return nil, handleReason
  end

  local active = {
    battle=battle,
    battleToken=battleToken,
    deploymentToken=deploymentToken,
    provider=provider,
    requestedMode=requestedMode,
    state="starting",
  }
  -- Publish the private owner before calling the provider.  A failed start may
  -- have acquired resources, so its exact BattleState must remain available
  -- for retryable abort instead of disappearing on a false return.
  self.active = active
  local started, startReason, startInvalidated = invokeLeased(
    self, lease, provider, "start", battle, context, receipt(self, active))
  if startInvalidated then
    quarantineIntegrityFailure(self, active, startReason)
    return nil, startReason
  end
  if not started then
    self.failures = self.failures + 1
    local cleaned, cleanupReason = self:_abortActive(
      "provider-start-failed", lease)
    if not cleaned then
      return nil, safeText(startReason, "provider start failed")
        .. "; rollback failed: "
        .. safeText(cleanupReason, "provider rollback failed")
    end
    return nil, startReason
  end
  active.state = "active"
  self.transitions = self.transitions + 1
  return receipt(self, active)
end

function Router:start(battle, context)
  return runMutation(self, "start", nil, function(lease)
    return startMutation(self, battle, context, lease)
  end)
end

function Router:_startWithin(battle, context, outerLease)
  return runMutation(self, "start", nil, function(lease)
    return startMutation(self, battle, context, lease)
  end, outerLease)
end

function Router:owns(battle)
  return self.active ~= nil and battle ~= nil
    and rawequal(self.active.battle, battle)
end

local function switchMutation(self, battle, context, lease)
  local pending, pendingReason = rejectRollbackPending(self)
  if pending then return nil, pendingReason end
  local active = self.active
  if not active or not rawequal(active.battle, battle) then
    return nil, "battle owner mismatch"
  end
  context = type(context) == "table" and context or {}
  local battleToken, deploymentToken, tokenReason = tokens(context)
  if not battleToken then return nil, tokenReason end
  if battleToken ~= active.battleToken then
    return nil, ("battle token mismatch: expected %d, got %d")
      :format(active.battleToken, battleToken)
  end
  if deploymentToken <= active.deploymentToken then
    return nil, ("deployment token must advance beyond %d")
      :format(active.deploymentToken)
  end
  active.deploymentToken = deploymentToken
  active.state = "switching"
  local switched, reason, invalidated = invokeLeased(
    self, lease, active.provider, "switch", battle, context,
    receipt(self, active))
  if invalidated then
    quarantineIntegrityFailure(self, active, reason)
    return nil, reason
  end
  if not switched then
    self.failures = self.failures + 1
    self:_abortActive("provider-switch-failed", lease)
    return nil, reason
  end
  active.state = "active"
  self.transitions = self.transitions + 1
  return receipt(self, active)
end

function Router:switch(battle, context)
  return runMutation(self, "switch", nil, function(lease)
    return switchMutation(self, battle, context, lease)
  end)
end

function Router:_switchWithin(battle, context, outerLease)
  return runMutation(self, "switch", nil, function(lease)
    return switchMutation(self, battle, context, lease)
  end, outerLease)
end

local function attackMutation(self, battle, context, lease)
  local pending, pendingReason = rejectRollbackPending(self)
  if pending then return nil, pendingReason end
  local active = self.active
  if not active or not rawequal(active.battle, battle) then
    return nil, "battle owner mismatch"
  end
  context = type(context) == "table" and context or {}
  local battleToken, deploymentToken, tokenReason = tokens(context)
  if not battleToken then return nil, tokenReason end
  if battleToken ~= active.battleToken then
    return nil, "battle token mismatch"
  end
  if deploymentToken ~= active.deploymentToken then
    return nil, "deployment token mismatch"
  end
  local attacked, reason, invalidated = invokeLeased(
    self, lease, active.provider, "attack", battle, context,
    receipt(self, active))
  if invalidated then
    quarantineIntegrityFailure(self, active, reason)
    return nil, reason
  end
  if not attacked then
    self.failures = self.failures + 1
    return nil, reason
  end
  self.transitions = self.transitions + 1
  return receipt(self, active)
end

function Router:attack(battle, context)
  return runMutation(self, "attack", nil, function(lease)
    return attackMutation(self, battle, context, lease)
  end)
end

function Router:_attackWithin(battle, context, outerLease)
  return runMutation(self, "attack", nil, function(lease)
    return attackMutation(self, battle, context, lease)
  end, outerLease)
end

local function finishMutation(self, battle, context, lease)
  local pending, pendingReason = rejectRollbackPending(self)
  if pending then return nil, pendingReason end
  local active = self.active
  if not active or not rawequal(active.battle, battle) then
    return nil, "battle owner mismatch"
  end
  context = type(context) == "table" and context or {}
  local battleToken, deploymentToken, tokenReason = tokens(context)
  if not battleToken then return nil, tokenReason end
  if battleToken ~= active.battleToken then
    return nil, "battle token mismatch"
  end
  if deploymentToken ~= active.deploymentToken then
    return nil, "deployment token mismatch"
  end
  local finished, reason, invalidated = invokeLeased(
    self, lease, active.provider, "finish", battle,
    context, receipt(self, active))
  if invalidated then
    quarantineIntegrityFailure(self, active, reason)
    return nil, reason
  end
  if not finished then
    self.failures = self.failures + 1
    self:_abortActive("provider-finish-failed", lease)
    return nil, reason
  end
  active.state = "ended"
  self.transitions = self.transitions + 1
  local ended = receipt(self, active)
  self.active = nil
  return ended
end

function Router:finish(battle, context)
  return runMutation(self, "finish", nil, function(lease)
    return finishMutation(self, battle, context, lease)
  end)
end

function Router:_finishWithin(battle, context, outerLease)
  return runMutation(self, "finish", nil, function(lease)
    return finishMutation(self, battle, context, lease)
  end, outerLease)
end

-- One-way provider fallback for the same authoritative lifecycle owner.
-- This is distinct from start(): changing a live provider requires its exact
-- abort to succeed before DEFAULT may acquire the BattleState.
local function fallbackMutation(self, battle, context, lease)
  if not self.enabled then return nil, "battle router is retired" end
  local pending, pendingReason = rejectRollbackPending(self)
  if pending then return nil, pendingReason end
  if battle == nil then return nil, "battle owner is required" end
  context = type(context) == "table" and context or {}
  local battleToken, deploymentToken, tokenReason = tokens(context)
  if not battleToken then return nil, tokenReason end
  local active = self.active
  if active then
    if not rawequal(active.battle, battle) then
      return nil, "battle owner mismatch"
    end
    if active.battleToken ~= battleToken then return nil, "battle token mismatch" end
    if deploymentToken < active.deploymentToken then
      return nil, "deployment token regressed during fallback"
    end
    if active.provider.id == "DEFAULT" then
      active.deploymentToken = deploymentToken
      active.state = "active"
      active.reason = safeText(context.reason, "native-latched")
      return receipt(self, active)
    end
    local cleaned, cleanupReason = self:_abortActive(
      context.reason or "native-latched", lease)
    if not cleaned then return nil, cleanupReason end
  end
  local startContext = {}
  for key, value in pairs(context) do startContext[key] = value end
  startContext.provider = "DEFAULT"
  return startMutation(self, battle, startContext, lease)
end

function Router:fallback(battle, context)
  return runMutation(self, "fallback", nil, function(lease)
    return fallbackMutation(self, battle, context, lease)
  end)
end

function Router:_fallbackWithin(battle, context, outerLease)
  return runMutation(self, "fallback", nil, function(lease)
    return fallbackMutation(self, battle, context, lease)
  end, outerLease)
end

local function deactivateMutation(self, reason, lease)
  if not self.enabled then return true end
  local clean, cleanupReason = self:_abortActive(
    reason or "router-deactivated", lease)
  if not clean then return false, cleanupReason end
  self.enabled = false
  self.retiredReason = safeText(reason, "router-deactivated")
  return true
end

function Router:deactivate(reason)
  return runMutation(self, "deactivate", false, function(lease)
    return deactivateMutation(self, reason, lease)
  end)
end

function Router:_deactivateWithin(reason, outerLease)
  return runMutation(self, "deactivate", false, function(lease)
    return deactivateMutation(self, reason, lease)
  end, outerLease)
end

local function abortMutation(self, battle, reason, lease)
  if battle == nil then return nil, "battle owner is required" end
  if not self:owns(battle) then return nil, "battle owner mismatch" end
  local ok, detail = self:_abortActive(reason or "router-aborted", lease)
  return ok and true or nil, detail
end

function Router:abort(battle, reason)
  return runMutation(self, "abort", nil, function(lease)
    return abortMutation(self, battle, reason, lease)
  end)
end

function Router:_abortWithin(battle, reason, outerLease)
  return runMutation(self, "abort", nil, function(lease)
    return abortMutation(self, battle, reason, lease)
  end, outerLease)
end

local function healthReceipt(self, providers, errorReason)
  providers = providers or {}
  local count = 0
  for _ in pairs(self.providers) do count = count + 1 end
  return {
    schema="ascendant.compat-status/v1",
    apiVersion=Router.API_VERSION,
    ok=errorReason == nil and self.enabled and self.failures == 0,
    generation=self.generation,
    active=receipt(self, self.active),
    providerCount=count,
    providers=providers,
    transitions=self.transitions,
    failures=self.failures,
    legacyPassThroughs=self.legacyPassThroughs,
    retiredReason=self.retiredReason,
    error=errorReason,
  }
end

function Router:_healthWithin(outerLease)
  -- Provider diagnostics are callbacks too. Keep them behind the same
  -- serialization boundary as start/switch/end so a supposedly read-only
  -- health probe cannot synchronously acquire or retire a BattleState. A
  -- nested health call receives a closed diagnostic rather than recursing.
  local lease, busyReason = beginMutation(self, "health", outerLease)
  if not lease then return healthReceipt(self, {}, busyReason) end

  local providers = {}
  local integrityReason = nil
  for id, provider in pairs(self.providers) do
    local snapshot = exactSnapshot(self)
    local ok, value = pcall(provider.health)
    local exact, exactReason = exactPostcondition(
      self, lease, snapshot, provider, "health")
    if not exact then
      integrityReason = exactReason
      self.failures = self.failures + 1
      providers[id] = { ok=false, error=exactReason }
      break
    else
      providers[id] = ok and type(value) == "table" and value or {
        ok=false,
        error=ok and "provider health returned no receipt"
          or safeText(value, "unprintable provider health error"),
      }
    end
  end
  if rawequal(self.mutationLease, lease) then self.mutationLease = nil end
  lease.live = false
  return healthReceipt(self, providers, integrityReason)
end


function Router:health()
  return self:_healthWithin(nil)
end

-- A Card-level transaction outlives individual provider method calls. Public
-- mutations are denied for its complete lifetime, while the scoped service
-- held by the owner may perform the exact internal start/switch/end/abort.
-- The handle can intentionally survive rollback_pending and is unforgeable:
-- a copied scoped service stops working as soon as release() retires its
-- object-identity lease.
function Router:acquire(operation)
  operation = safeText(operation, "card-transaction")
  if self.outerLease ~= nil then
    return nil, ("battle router transaction is already in progress: %s")
      :format(safeText(self.outerLease.operation, "unknown"))
  end
  if self.mutationLease ~= nil then
    return nil, ("battle router mutation is already in progress: %s")
      :format(safeText(self.mutationLease.operation, "unknown"))
  end
  self.outerEpoch = self.outerEpoch + 1
  local lease = {
    epoch=self.outerEpoch,
    operation=operation,
    live=true,
  }
  self.outerLease = lease
  local owner = self
  local service = {
    schema=Router.SCHEMA,
    apiVersion=Router.API_VERSION,
    generation=self.generation,
    providerSchema=Contracts.SCHEMA,
    start=function(battle, context)
      return owner:_startWithin(battle, context, lease)
    end,
    owns=function(battle)
      return outerLeaseLive(owner, lease) and owner:owns(battle) or false
    end,
    switch=function(battle, context)
      return owner:_switchWithin(battle, context, lease)
    end,
    attack=function(battle, context)
      return owner:_attackWithin(battle, context, lease)
    end,
    finish=function(battle, context)
      return owner:_finishWithin(battle, context, lease)
    end,
    fallback=function(battle, context)
      return owner:_fallbackWithin(battle, context, lease)
    end,
    abort=function(battle, reason)
      return owner:_abortWithin(battle, reason, lease)
    end,
    health=function() return owner:_healthWithin(lease) end,
  }
  local handle = {
    schema="ascendant.battle-router-transaction/v1",
    apiVersion=Router.API_VERSION,
    service=service,
  }
  function handle.release()
    if not outerLeaseLive(owner, lease) then return false end
    if owner.mutationLease ~= nil then
      return false, "battle router mutation is still in progress"
    end
    owner.outerLease = nil
    lease.live = false
    return true
  end
  function handle.active()
    return outerLeaseLive(owner, lease)
  end
  return handle
end

function Router:public()
  local owner = self
  return {
    schema=Router.SCHEMA,
    apiVersion=Router.API_VERSION,
    generation=self.generation,
    providerSchema=Contracts.SCHEMA,
    start=function(battle, context) return owner:start(battle, context) end,
    owns=function(battle) return owner:owns(battle) end,
    switch=function(battle, context) return owner:switch(battle, context) end,
    attack=function(battle, context) return owner:attack(battle, context) end,
    finish=function(battle, context) return owner:finish(battle, context) end,
    fallback=function(battle, context) return owner:fallback(battle, context) end,
    abort=function(battle, reason) return owner:abort(battle, reason) end,
    health=function() return owner:health() end,
  }
end

return Router
