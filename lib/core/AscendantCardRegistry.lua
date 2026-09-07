-- Generation-neutral lifecycle registry for versioned Ascendant cards.
--
-- The registry is deliberately local: callers create an instance and pass it
-- to the generation adapter that owns it.  It does not inspect globals, patch
-- classes or reach into the engine.  Card dependencies are activated before
-- consumers, capabilities have exactly one registered provider, and a card
-- whose lifecycle fails is aborted and stripped of all owner-scoped hooks.

local V = ...
assert(V and type(V.require) == "function", "AscendantCardRegistry needs V.require")
local Contracts = assert(V.require("core/AscendantContracts"))
local Hooks = assert(V.require("core/AscendantHooks"))

local Registry = {}
Registry.__index = Registry

local function sortedKeys(values)
  local result = {}
  for key in pairs(values) do result[#result + 1] = key end
  table.sort(result)
  return result
end

local function appendUnique(result, seen, value)
  if not seen[value] then
    seen[value] = true
    result[#result + 1] = value
  end
end

local function removeValue(values, target)
  for index = #values, 1, -1 do
    if values[index] == target then table.remove(values, index) end
  end
end

local function containsValue(values, target)
  for _, value in ipairs(values) do
    if value == target then return true end
  end
  return false
end

-- Capability services cross a Card ownership boundary.  Function values are
-- allowed because they are the service API, but tables are copied so a
-- consumer can never replace fields in the provider's retained service (or in
-- another consumer's receipt).  Engine userdata, threads, cyclic tables and
-- non-finite numbers are not valid boundary data.
local function copyBoundary(value, allowFunctions, seen)
  local kind = type(value)
  if kind == "number" then
    if value ~= value or value == math.huge or value == -math.huge then
      error("boundary contains a non-finite number", 0)
    end
    return value
  end
  if kind == "nil" or kind == "boolean" or kind == "string"
      or (allowFunctions and kind == "function") then
    return value
  end
  if kind ~= "table" then
    error("boundary contains unsupported " .. kind .. " value", 0)
  end
  seen = seen or {}
  if seen[value] then error("boundary contains a cyclic table", 0) end
  seen[value] = true
  local result = {}
  for key, item in pairs(value) do
    local keyKind = type(key)
    if keyKind ~= "string" and keyKind ~= "number"
        and keyKind ~= "boolean" then
      error("boundary contains unsupported " .. keyKind .. " key", 0)
    end
    result[key] = copyBoundary(item, allowFunctions, seen)
  end
  seen[value] = nil
  return result
end

local function copyCapability(value)
  return copyBoundary(value, true)
end

local function copyData(value)
  return copyBoundary(value, false)
end

local function valueSet(values)
  local result = {}
  for _, value in ipairs(values or {}) do result[value] = true end
  return result
end

function Registry.new(options)
  options = options or {}
  local hooks = options.hooks or Hooks.new({ onError=options.onHookError })
  return setmetatable({
    hooks=hooks,
    cards={},
    capabilities={},
    runtimeOwners={},
    saveNamespaces={},
    saveAdapter=options.saveAdapter,
    activationOrder={},
  }, Registry)
end

function Registry:register(raw)
  local ok, card, validationError = pcall(Contracts.validateCard, raw)
  if not ok then return false, "card validation failed: " .. tostring(card) end
  if not card then return false, validationError end
  if self.cards[card.id] then return false, "card is already registered: " .. card.id end

  -- Check every capability before mutating either index. Registration is
  -- therefore atomic even when the last capability conflicts.
  for _, name in ipairs(card.provides) do
    local existing = self.capabilities[name]
    if existing then
      return false, ("capability %s is already owned by %s"):format(name, existing)
    end
  end
  for _, name in ipairs(card.impact.runtimeOwners) do
    local existing = self.runtimeOwners[name]
    if existing then
      return false, ("runtime owner %s is already claimed by %s"):format(
        name, existing)
    end
  end
  if card.saveNamespace ~= false then
    local existing = self.saveNamespaces[card.saveNamespace]
    if existing then
      return false, ("save namespace %s is already owned by %s"):format(
        card.saveNamespace, existing)
    end
  end

  self.cards[card.id] = {
    card=card,
    state="registered",
    installedValue=nil,
    activeValue=nil,
    capabilityValue=nil,
    lastError=nil,
    hookTokens={},
    activeDependencies={},
    activationEpoch=0,
    activationLease=nil,
    transitionEpoch=0,
    transitionLease=nil,
    abortIntent=false,
    rollbackPhase=nil,
    rollbackMessage=nil,
  }
  for _, name in ipairs(card.provides) do self.capabilities[name] = card.id end
  for _, name in ipairs(card.impact.runtimeOwners) do
    self.runtimeOwners[name] = card.id
  end
  if card.saveNamespace ~= false then
    self.saveNamespaces[card.saveNamespace] = card.id
  end
  return true, Contracts.cardMetadata(card)
end

function Registry:card(id)
  local record = self.cards[id]
  return record and Contracts.cardMetadata(record.card) or nil
end

function Registry:state(id)
  local record = self.cards[id]
  if not record then return nil end
  return record.state, record.lastError
end

function Registry:_dependencies(record)
  local result, seen = {}, {}
  for _, id in ipairs(record.card.requires) do appendUnique(result, seen, id) end
  for _, id in ipairs(record.card.optionalRequires) do
    if self.cards[id] then appendUnique(result, seen, id) end
  end
  for _, name in ipairs(record.card.consumes) do
    local provider = self.capabilities[name]
    if provider then appendUnique(result, seen, provider) end
  end
  return result
end

function Registry:_dependencyError(record)
  for _, id in ipairs(record.card.requires) do
    local dependency = self.cards[id]
    if not dependency then return "required card is missing: " .. id end
    if dependency.abortIntent then
      return "required card is retiring: " .. id
    end
  end
  for _, id in ipairs(record.card.optionalRequires) do
    local dependency = self.cards[id]
    if dependency and dependency.abortIntent then
      return "optional card is retiring: " .. id
    end
  end
  for _, name in ipairs(record.card.consumes) do
    local providerId = self.capabilities[name]
    if not providerId then
      return "required capability has no provider: " .. name
    end
    local provider = self.cards[providerId]
    if provider and provider.abortIntent then
      return "required capability provider is retiring: " .. name
    end
  end
  return nil
end

local function liveContextLease(record, lease)
  if lease == nil or lease.alive ~= true then return false end
  if lease.kind == "activation" then
    return record.activationLease == lease
      and record.activationEpoch == lease.epoch
  end
  return record.transitionLease == lease
    and record.transitionEpoch == lease.epoch
end

function Registry:_revokeActivation(record)
  local lease = record.activationLease
  if lease then lease.alive = false end
  record.activationLease = nil
end

function Registry:_beginTransition(record, kind)
  local current = record.transitionLease
  if current and current.alive == true then
    return nil, "card lifecycle transition is already in progress: "
      .. tostring(current.kind)
  end
  record.transitionEpoch = record.transitionEpoch + 1
  local lease = {
    kind=kind,
    epoch=record.transitionEpoch,
    alive=true,
  }
  record.transitionLease = lease
  return lease
end

function Registry:_transitionLive(record, lease, state)
  return liveContextLease(record, lease)
    and (state == nil or record.state == state)
end

function Registry:_endTransition(record, lease)
  if record.transitionLease ~= lease then return false end
  lease.alive = false
  record.transitionLease = nil
  return true
end

function Registry:_revokeTransition(record)
  local lease = record.transitionLease
  if lease then lease.alive = false end
  record.transitionLease = nil
end

function Registry:_trackForTeardown(record)
  if not containsValue(self.activationOrder, record.card.id) then
    self.activationOrder[#self.activationOrder + 1] = record.card.id
  end
end

function Registry:_saveFacade(record, phase, contextLease)
  if record.card.saveNamespace == false then return nil end
  local registry = self
  local namespace = record.card.saveNamespace
  local adapter = registry.saveAdapter
  local declaredWrites = valueSet(record.card.impact.saveWrites)
  local namespaceWide = declaredWrites[namespace] == true

  local function live()
    if liveContextLease(record, contextLease) then return true end
    return false, "context lease is no longer alive"
  end

  local function validKey(key)
    if type(key) ~= "string" or key == "" then
      return false, "save key must be a non-empty string"
    end
    if key:find("%z") then return false, "save key contains a NUL byte" end
    return true
  end

  local facade = { namespace=namespace }

  function facade.read(key)
    local alive, leaseError = live()
    if not alive then return nil, leaseError end
    local valid, keyError = validKey(key)
    if not valid then return nil, keyError end
    if type(adapter) ~= "table" or type(adapter.read) ~= "function" then
      return nil, "save adapter is unavailable"
    end
    local called, value, detail = pcall(adapter.read, namespace, key)
    if not called then return nil, tostring(value) end
    if value == nil and detail ~= nil then return nil, tostring(detail) end
    local copied, result = pcall(copyData, value)
    if not copied then return nil, tostring(result) end
    return result
  end

  local function canWrite(key)
    local alive, leaseError = live()
    if not alive then return false, leaseError end
    local valid, keyError = validKey(key)
    if not valid then return false, keyError end
    if phase == "health" then
      return false, "health contexts are read-only"
    end
    local fullKey = namespace .. "." .. key
    if not namespaceWide and not declaredWrites[fullKey] then
      return false, "save key is not declared in impact.saveWrites: "
        .. fullKey
    end
    if type(adapter) ~= "table" or type(adapter.write) ~= "function" then
      return false, "save adapter is unavailable"
    end
    return true
  end

  function facade.write(key, value)
    local allowed, writeError = canWrite(key)
    if not allowed then return false, writeError end
    local copied, isolated = pcall(copyData, value)
    if not copied then return false, tostring(isolated) end
    local called, result, detail = pcall(
      adapter.write, namespace, key, isolated)
    if not called then return false, tostring(result) end
    if result == false then return false, tostring(detail or "save write declined") end
    return true
  end

  function facade.delete(key)
    local allowed, writeError = canWrite(key)
    if not allowed then return false, writeError end
    if type(adapter.delete) ~= "function" then
      return false, "save delete adapter is unavailable"
    end
    local called, result, detail = pcall(adapter.delete, namespace, key)
    if not called then return false, tostring(result) end
    if result == false then return false, tostring(detail or "save delete declined") end
    return true
  end

  return facade
end

function Registry:_context(record, phase, runtime, detail, contextLease)
  local registry = self
  local cardId = record.card.id
  local hookFacade = {}
  local declaredHooks = valueSet(record.card.impact.publicHooks)
  local declaredCapabilities = valueSet(record.card.consumes)
  local declaredCards = valueSet(record.card.requires)
  for _, id in ipairs(record.card.optionalRequires) do declaredCards[id] = true end

  local function requireLiveContext()
    if liveContextLease(record, contextLease) then return true end
    return false, "context lease is no longer alive"
  end

  local function requireDeclaredHook(event)
    if declaredHooks[event] then return true end
    return false, "hook is not declared by this card: " .. tostring(event)
  end

  function hookFacade.on(event, callback, priority)
    if phase ~= "activate" then
      return nil, "card hooks may only be subscribed during activate"
    end
    local alive, leaseError = requireLiveContext()
    if not alive then return nil, leaseError end
    local declared, declarationError = requireDeclaredHook(event)
    if not declared then return nil, declarationError end
    local token, unsubscribe = registry.hooks:subscribe(event, cardId, callback, priority)
    if token then record.hookTokens[token] = true end
    if not token then return nil, unsubscribe end
    return token, function()
      if not liveContextLease(record, contextLease) then return false end
      record.hookTokens[token] = nil
      return unsubscribe()
    end
  end

  function hookFacade.off(token)
    if phase ~= "activate" then
      return false, "card hooks may only be removed during activate"
    end
    local alive, leaseError = requireLiveContext()
    if not alive then return false, leaseError end
    if not record.hookTokens[token] then return false end
    record.hookTokens[token] = nil
    return registry.hooks:unsubscribe(token)
  end

  function hookFacade.emit(event, payload)
    if phase ~= "activate" then
      return nil, "card hooks may only be emitted during activate"
    end
    local alive, leaseError = requireLiveContext()
    if not alive then return nil, leaseError end
    local declared, declarationError = requireDeclaredHook(event)
    if not declared then return nil, declarationError end
    return registry.hooks:emit(event, payload)
  end

  local runtimeOK, runtimeSnapshot = pcall(copyData, runtime)
  local detailOK, detailSnapshot = pcall(copyData, detail)
  local context = {
    phase=phase,
    card=Contracts.cardMetadata(record.card),
    runtime=runtimeOK and runtimeSnapshot or nil,
    runtimeError=runtimeOK and nil or tostring(runtimeSnapshot),
    detail=detailOK and detailSnapshot or nil,
    detailError=detailOK and nil or tostring(detailSnapshot),
    hooks=hookFacade,
  }
  context.save = self:_saveFacade(record, phase, contextLease)

  function context.capability(name)
    local alive, leaseError = requireLiveContext()
    if not alive then return nil, leaseError end
    if not declaredCapabilities[name] then
      return nil, "capability is not declared in consumes: " .. tostring(name)
    end
    local capability = registry:capability(name)
    if not capability then
      return nil, "declared capability is unavailable: " .. tostring(name)
    end
    return capability
  end

  -- Required Card ids establish ordering/ownership only. Consumers may inspect
  -- dependency metadata through `dependency()`, while `context.card` remains
  -- the current Card's immutable metadata receipt. Private installed/active
  -- values never cross the boundary; executable services travel exclusively
  -- through `consumes`.
  function context.dependency(id)
    local alive, leaseError = requireLiveContext()
    if not alive then return nil, leaseError end
    if not declaredCards[id] then
      return nil, "card is not declared as a dependency: " .. tostring(id)
    end
    local dependency = registry.cards[id]
    if not dependency or dependency.state ~= "active" then
      return nil, "declared card dependency is unavailable: " .. tostring(id)
    end
    return Contracts.cardMetadata(dependency.card)
  end

  -- A live card may retire itself when an asynchronous engine callback
  -- fails.  This keeps runtime failures inside the same abort/cleanup path as
  -- install and activate failures instead of leaving the registry "active"
  -- after its engine subscriptions have died.
  function context.fail(reason)
    if contextLease == nil or contextLease.kind ~= "activation" then
      return false, "context.fail requires a live activation context"
    end
    local alive, leaseError = requireLiveContext()
    if not alive then return false, leaseError end
    return registry:_abort(cardId, runtime,
      reason or (cardId .. " requested fail-closed"), contextLease)
  end

  return context
end

function Registry:_dropHooks(record)
  local removed = self.hooks:deactivateOwner(record.card.id)
  record.hookTokens = {}
  return removed
end

function Registry:_abortRecord(record, phase, message, runtime)
  self:_revokeActivation(record)
  self:_revokeTransition(record)
  self:_dropHooks(record)
  record.abortIntent = true
  record.capabilityValue = nil
  record.state = "aborting"
  local contextLease = assert(self:_beginTransition(record, "abort"))
  local context = self:_context(record, "abort", runtime, {
    failedPhase=phase,
    error=tostring(message),
  }, contextLease)
  local called, abortValue, abortDetail = pcall(
    record.card.lifecycle.abort,
    context,
    phase,
    tostring(message),
    record.installedValue,
    record.activeValue
  )
  local transitionIntact = self:_transitionLive(
    record, contextLease, "aborting")
  self:_endTransition(record, contextLease)
  local abortSucceeded = called and abortValue ~= false
  local abortError
  if not transitionIntact then
    abortSucceeded = false
    abortError = "abort transition was superseded"
  elseif not called then
    abortError = tostring(abortValue)
  elseif abortValue == false then
    abortError = tostring(abortDetail or "abort returned false")
  end

  -- A failed abort still closes the Card publicly, but its private active
  -- owner token must remain available for a diagnostic/retry abort.  Clearing
  -- that token before rollback succeeds makes engine leases impossible to
  -- release safely.
  record.abortIntent = false
  if abortSucceeded then
    record.activeValue = nil
    record.activeDependencies = {}
    record.rollbackPhase = nil
    record.rollbackMessage = nil
    record.state = "failed"
    removeValue(self.activationOrder, record.card.id)
  else
    record.rollbackPhase = record.rollbackPhase or phase
    record.rollbackMessage = record.rollbackMessage or tostring(message)
    record.state = "rollback_pending"
    self:_trackForTeardown(record)
  end
  record.lastError = tostring(message)
  if not abortSucceeded then
    record.lastError = record.lastError .. "; abort failed: " .. tostring(abortError)
  end
  return false, record.lastError, abortSucceeded
end

local function lifecycleResult(ok, value, detail, phase)
  if not ok then return false, tostring(value) end
  if value == false then return false, tostring(detail or (phase .. " returned false")) end
  return true, value
end

function Registry:_install(id, runtime, visiting)
  local record = self.cards[id]
  if not record then return false, "card is not registered: " .. tostring(id) end
  if record.abortIntent then
    return false, "card is retiring: " .. tostring(id)
  end
  if record.state == "failed" or record.state == "rollback_pending" then
    return false, record.lastError
  end
  if record.state == "installed" or record.state == "active" then return true end
  if record.state ~= "registered" then
    return false, "card lifecycle transition is already in progress: "
      .. tostring(record.state)
  end

  visiting = visiting or {}
  if visiting[id] then return false, "card dependency cycle at " .. id end
  local dependencyError = self:_dependencyError(record)
  if dependencyError then return false, dependencyError end
  visiting[id] = true
  for _, dependency in ipairs(self:_dependencies(record)) do
    local ok, err = self:_install(dependency, runtime, visiting)
    if not ok then
      visiting[id] = nil
      return false, ("%s cannot install because %s: %s"):format(id, dependency, err)
    end
  end
  visiting[id] = nil

  record.state = "installing"
  local contextLease, transitionError =
    self:_beginTransition(record, "install")
  if not contextLease then
    record.state = "registered"
    return false, transitionError
  end
  local context = self:_context(record, "install", runtime, nil, contextLease)
  local called, value, detail = pcall(record.card.lifecycle.install, context)
  if not self:_transitionLive(record, contextLease, "installing") then
    return false, record.lastError or "install transition was superseded"
  end
  local succeeded, result = lifecycleResult(called, value, detail, "install")
  if not succeeded then return self:_abortRecord(record, "install", result, runtime) end
  self:_endTransition(record, contextLease)
  record.installedValue = result
  record.state = "installed"
  record.lastError = nil
  return true
end

function Registry:install(id, runtime)
  return self:_install(id, runtime, {})
end

function Registry:_activate(id, runtime, visiting)
  local record = self.cards[id]
  if not record then return false, "card is not registered: " .. tostring(id) end
  if record.abortIntent then
    return false, "card is retiring: " .. tostring(id)
  end
  if record.state == "active" then return true end
  if record.state == "failed" or record.state == "rollback_pending" then
    return false, record.lastError
  end
  if record.state ~= "registered" and record.state ~= "installed" then
    return false, "card lifecycle transition is already in progress: "
      .. tostring(record.state)
  end

  visiting = visiting or {}
  if visiting[id] then return false, "card dependency cycle at " .. id end
  local dependencyError = self:_dependencyError(record)
  if dependencyError then return false, dependencyError end
  visiting[id] = true
  for _, dependency in ipairs(self:_dependencies(record)) do
    local ok, err = self:_activate(dependency, runtime, visiting)
    if not ok then
      visiting[id] = nil
      return false, ("%s cannot activate because %s: %s"):format(id, dependency, err)
    end
  end
  visiting[id] = nil

  -- Dependency owners are already active at this point. Record the edge before
  -- install so a failed install whose abort is still pending cannot strand a
  -- consumer token while its provider is torn down underneath it.
  record.activeDependencies = self:_dependencies(record)
  local installed, installError = self:_install(id, runtime, {})
  if not installed then return false, installError end
  record.state = "activating"
  local transitionLease, transitionError =
    self:_beginTransition(record, "activate")
  if not transitionLease then
    record.state = "installed"
    return false, transitionError
  end
  record.activationEpoch = record.activationEpoch + 1
  local activationLease = {
    kind="activation",
    epoch=record.activationEpoch,
    alive=true,
  }
  record.activationLease = activationLease
  local context = self:_context(record, "activate", runtime, nil, activationLease)
  local called, value, detail = pcall(
    record.card.lifecycle.activate,
    context,
    record.installedValue
  )
  -- `context.fail()` may synchronously abort from inside activate.  Its
  -- revoked generation must win over any later return from that same callback
  -- so a failed Card can never be resurrected as active.
  if not self:_transitionLive(record, transitionLease, "activating")
      or not liveContextLease(record, activationLease)
      or record.state ~= "activating" then
    return false, record.lastError or "activation context lease was revoked"
  end
  local succeeded, result = lifecycleResult(called, value, detail, "activate")
  if not succeeded then return self:_abortRecord(record, "activate", result, runtime) end
  record.activeValue = result
  -- The first successful return is always private lifecycle state.  A Card
  -- which advertises capabilities must explicitly return its public service as
  -- the second value; silently publishing the private owner token would undo
  -- the entire Card boundary.
  if #record.card.provides > 0 then
    if detail == nil then
      return self:_abortRecord(record, "activate",
        "capability provider returned no explicit public service", runtime)
    end
    local publicOK, publicValue = pcall(copyCapability, detail)
    if not publicOK then
      return self:_abortRecord(record, "activate", publicValue, runtime)
    end
    record.capabilityValue = publicValue
  else
    record.capabilityValue = nil
  end
  self:_endTransition(record, transitionLease)
  record.activeDependencies = self:_dependencies(record)
  record.state = "active"
  record.lastError = nil
  self:_trackForTeardown(record)
  return true
end

function Registry:activate(id, runtime)
  return self:_activate(id, runtime, {})
end

function Registry:_activeDependents(id)
  local result = {}
  for otherId, other in pairs(self.cards) do
    if otherId ~= id and (other.state == "active"
        or other.state == "activating"
        or other.state == "deactivating"
        or other.state == "rollback_pending") then
      local depends = false
      for _, dependency in ipairs(other.activeDependencies) do
        if dependency == id then depends = true end
      end
      if depends then result[#result + 1] = otherId end
    end
  end
  table.sort(result)
  return result
end

function Registry:deactivate(id, runtime, reason)
  local record = self.cards[id]
  if not record then return false, "card is not registered: " .. tostring(id) end
  -- Retirement is marked before dependent callbacks run.  Neither a
  -- dependent abort callback nor a health callback may enter teardown again
  -- while that owner/record transition is still live.
  if record.abortIntent then
    return false, "card abort is already in progress: " .. tostring(id)
  end
  if record.transitionLease and record.transitionLease.alive == true then
    return false, "card lifecycle transition is already in progress: "
      .. tostring(record.transitionLease.kind)
  end
  if record.state == "rollback_pending" then
    local dependents = self:_activeDependents(id)
    if #dependents > 0 then
      return false, "live dependents must be rolled back first: "
        .. table.concat(dependents, ", ")
    end
    local _, message, abortOK = self:_abortRecord(
      record,
      record.rollbackPhase or "external",
      record.rollbackMessage or reason or "rollback retry",
      runtime
    )
    return abortOK, message
  end
  if record.state == "registered" or record.state == "installed"
      or record.state == "failed" then
    self:_dropHooks(record)
    return true
  end
  if record.state ~= "active" then
    return false, "card lifecycle transition is already in progress: "
      .. tostring(record.state)
  end
  local dependents = self:_activeDependents(id)
  if #dependents > 0 then
    return false, "active dependents must be deactivated first: " .. table.concat(dependents, ", ")
  end

  self:_revokeActivation(record)
  record.state = "deactivating"
  local contextLease, transitionError =
    self:_beginTransition(record, "deactivate")
  if not contextLease then
    record.state = "active"
    return false, transitionError
  end
  local reasonText = reason == nil and nil or tostring(reason)
  local context = self:_context(
    record, "deactivate", runtime, { reason=reasonText }, contextLease)
  local called, value, detail = pcall(
    record.card.lifecycle.deactivate,
    context,
    record.activeValue,
    reasonText
  )
  if not self:_transitionLive(record, contextLease, "deactivating") then
    return false, record.lastError or "deactivate transition was superseded"
  end
  local succeeded, result = lifecycleResult(called, value, detail, "deactivate")
  -- Abort is the mandatory last rollback boundary.  If deactivate itself
  -- fails, keep the private active value intact until _abortRecord has handed
  -- it to lifecycle.abort; clearing it first would make owner/token cleanup
  -- impossible for Cards whose installed and active states are distinct.
  if not succeeded then
    return self:_abortRecord(record, "deactivate", result, runtime)
  end
  self:_endTransition(record, contextLease)
  self:_dropHooks(record)
  record.activeValue = nil
  record.capabilityValue = nil
  record.activeDependencies = {}
  removeValue(self.activationOrder, id)
  record.state = "installed"
  record.lastError = nil
  return true
end

function Registry:_abort(id, runtime, reason, activationLease)
  local record = self.cards[id]
  if not record then return false, "card is not registered: " .. tostring(id) end
  -- The first legitimate context.fail enters with no abort intent. Once an
  -- external/provider abort has announced retirement, even a still-live
  -- activation context must not nest a second abort beneath that operation.
  if record.abortIntent then
    return false, "card abort is already in progress: " .. tostring(id)
  end
  local transition = record.transitionLease
  if transition and transition.alive == true then
    local activationSelfAbort = record.state == "activating"
      and transition.kind == "activate"
      and activationLease ~= nil
      and record.activationLease == activationLease
      and liveContextLease(record, activationLease)
    if not activationSelfAbort then
      return false, "card lifecycle transition is already in progress: "
        .. tostring(transition.kind)
    end
  end
  if record.state == "failed" and record.activeValue == nil
      and record.rollbackPhase == nil then
    return true, record.lastError
  end
  record.abortIntent = true
  local dependentErrors = {}
  for _, dependent in ipairs(self:_activeDependents(id)) do
    local ok, err = self:_abort(
      dependent, runtime, reason or "provider aborted", nil)
    if not ok then dependentErrors[#dependentErrors + 1] = dependent .. ": " .. err end
  end
  if #dependentErrors > 0 then
    record.abortIntent = false
    return false, "provider rollback blocked; dependent abort failed: "
      .. table.concat(dependentErrors, "; ")
  end
  local phase = record.rollbackPhase or "external"
  local message = record.rollbackMessage or reason or "external abort"
  local _, abortMessage, abortOk = self:_abortRecord(
    record, phase, message, runtime
  )
  return abortOk, abortMessage
end

function Registry:abort(id, runtime, reason)
  return self:_abort(id, runtime, reason, nil)
end

function Registry:installAll(runtime)
  local report = { installed={}, errors={} }
  for _, id in ipairs(sortedKeys(self.cards)) do
    local ok, err = self:install(id, runtime)
    if ok then
      report.installed[#report.installed + 1] = id
    else
      report.errors[#report.errors + 1] = { id=id, error=err }
    end
  end
  return report
end

function Registry:activateAll(runtime)
  local report = { active={}, errors={} }
  for _, id in ipairs(sortedKeys(self.cards)) do
    local ok, err = self:activate(id, runtime)
    if ok then
      report.active[#report.active + 1] = id
    else
      report.errors[#report.errors + 1] = { id=id, error=err }
    end
  end
  return report
end

function Registry:deactivateAll(runtime, reason)
  local report = { deactivated={}, errors={} }
  local order = {}
  for index = #self.activationOrder, 1, -1 do
    order[#order + 1] = self.activationOrder[index]
  end
  for _, id in ipairs(order) do
    local ok, err = self:deactivate(id, runtime, reason)
    if ok then
      report.deactivated[#report.deactivated + 1] = id
    else
      report.errors[#report.errors + 1] = { id=id, error=err }
    end
  end
  return report
end

function Registry:capability(name)
  local id = self.capabilities[name]
  local record = id and self.cards[id] or nil
  if not record or record.state ~= "active" then return nil end
  local ok, value = pcall(copyCapability, record.capabilityValue)
  if not ok then return nil end
  return {
    name=name,
    card=Contracts.cardMetadata(record.card),
    value=value,
  }
end

function Registry:health(id, runtime)
  local record = self.cards[id]
  if not record then return nil, "card is not registered: " .. tostring(id) end
  local contextLease, transitionError =
    self:_beginTransition(record, "health")
  if not contextLease then
    return {
      ok=false,
      state=record.state,
      error=transitionError,
      lastError=record.lastError,
    }
  end
  local context = self:_context(record, "health", runtime, nil, contextLease)
  local ok, value = pcall(
    record.card.lifecycle.health,
    context,
    record.installedValue,
    record.activeValue
  )
  local transitionIntact = self:_transitionLive(record, contextLease)
  self:_endTransition(record, contextLease)
  if not transitionIntact then
    return {
      ok=false,
      state=record.state,
      error="health transition was superseded",
      lastError=record.lastError,
    }
  end
  if not ok then
    return {
      ok=false,
      state=record.state,
      error=tostring(value),
      lastError=record.lastError,
    }
  end
  local copied, isolated = pcall(copyData, value)
  if not copied then
    return {
      ok=false,
      state=record.state,
      error="health receipt crossed a non-data boundary: "
        .. tostring(isolated),
      lastError=record.lastError,
    }
  end
  value = isolated
  -- A mandatory health callback that returns no receipt has not established
  -- health. Treat nil like an explicit negative result instead of painting an
  -- absent diagnostic green merely because the pcall itself succeeded.
  local lifecycleHealthy = value ~= false and value ~= nil
  if type(value) == "table" and value.ok ~= nil then
    lifecycleHealthy = value.ok == true
  end
  return {
    ok=record.state ~= "failed"
      and record.state ~= "rollback_pending"
      and lifecycleHealthy,
    state=record.state,
    detail=value,
    lastError=record.lastError,
  }
end

function Registry:healthAll(runtime)
  local report = { hooks=self.hooks:health(), cards={} }
  for _, id in ipairs(sortedKeys(self.cards)) do
    report.cards[id] = self:health(id, runtime)
  end
  return report
end

return Registry
