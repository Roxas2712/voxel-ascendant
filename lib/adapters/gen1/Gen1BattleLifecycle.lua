-- Gen-1 battle ownership adapter module.
--
-- The current VASC renderer is intentionally still one implementation.  This
-- adapter is the first real separation seam: engine events are translated
-- into one versioned, exact-owner lifecycle which future MAP/ARENA/DISCS
-- providers can consume without wrapping BattleState themselves.
--
-- It owns no graphics, settings or save data.  Listener failures are isolated
-- and a native latch is one-way for the exact battle, so diagnostics can never
-- make an encounter jump back and forth between renderers.

local V = ...

local Lifecycle = {
  API_VERSION = 1,
  CONTEXT_SCHEMA = "ascendant.battle-context/v1",
  PROVIDER_SCHEMA = "ascendant.battle-provider/v1",
}

local STATES = {
  created=true,
  active=true,
  replacing=true,
  native_latched=true,
  ended=true,
}

local PROVIDERS = {
  DEFAULT=true,
  MAP=true,
  ARENA=true,
  DISCS=true,
}

local serial = 0
local transitionSerial = 0
local listenerSerial = 0
local listenerFailures = 0
local criticalFailures = 0
local reentryFailures = 0
local observerRefusals = 0
local lastCriticalError = nil
local lastReentryError = nil
local lastObserverError = nil
local active = nil
local lastEnded = nil
local listeners = {}
local committedListeners = {}
local committedFinalizer = nil
local criticalListener = nil
local criticalDispatch = nil
local transitionDispatch = nil
local transitionReentrySerial = 0

local function sameIdentity(left, right)
  return rawequal(left, right)
end

local function safeText(value, fallback)
  if type(value) == "string" then return value end
  if value == nil then return fallback or "nil" end
  local ok, text = pcall(tostring, value)
  if ok and type(text) == "string" then return text end
  return fallback or ("<unprintable-%s>"):format(type(value))
end

local function reasonText(value, fallback)
  if value == nil then return fallback end
  local kind = type(value)
  if kind == "string" then return value end
  if kind == "number" or kind == "boolean" then
    return safeText(value, fallback)
  end
  return fallback or ("non-primitive-%s"):format(kind)
end

local function warn(format, ...)
  local log = V and V.mod and V.mod.log
  if log and type(log.warn) == "function" then
    pcall(log.warn, log, format, ...)
  end
end

local function modeName(value)
  if value == true then return "MAP" end
  if value == false or value == nil then return "DEFAULT" end
  if value == "arena" or value == "ARENA" then return "ARENA" end
  if value == "flatB" or value == "DISCS" then return "DISCS" end
  if value == "MAP" or value == "DEFAULT" then return value end
  return nil
end

local function shallowCopy(value)
  if type(value) ~= "table" then return value end
  local copy = {}
  for key, entry in pairs(value) do copy[key] = entry end
  return copy
end

-- Engine switch events carry the live side table.  That table owns battlers,
-- screens, hazards and extension tokens, so retaining it in a receipt would
-- turn a read-only public lifecycle event into a mutation channel.  Collapse
-- every supported engine shape to one primitive identity at the boundary.
local function sideIdentity(value)
  if type(value) == "table" then
    local key = rawget(value, "key")
    if key == "player" or key == "enemy" then return key end
    value = rawget(value, "index")
  end
  if value == "player" or value == 1 then return "player" end
  if value == "enemy" or value == 2 then return "enemy" end
  return nil
end

local function receipt(session)
  if not session then return nil end
  return {
    schema=Lifecycle.CONTEXT_SCHEMA,
    apiVersion=Lifecycle.API_VERSION,
    generation=1,
    battle=session.battle,
    battleToken=session.battleToken,
    deploymentToken=session.deploymentToken,
    state=session.state,
    provider=session.provider,
    requestedMode=session.requestedMode,
    side=session.side,
    reason=reasonText(session.reason, nil),
    context=shallowCopy(session.context),
    transition=session.transition,
  }
end

local function publicInteger(value, minimum)
  if type(value) ~= "number" or value % 1 ~= 0 or value < minimum then
    return nil
  end
  return value
end

local function sanitizePublicReceipt(value)
  if type(value) ~= "table"
      or value.schema ~= Lifecycle.CONTEXT_SCHEMA
      or value.apiVersion ~= Lifecycle.API_VERSION
      or value.generation ~= 1
      or not STATES[value.state]
      or not PROVIDERS[value.provider]
      or not PROVIDERS[value.requestedMode] then
    return nil
  end
  local battleToken = publicInteger(value.battleToken, 1)
  local deploymentToken = publicInteger(value.deploymentToken, 0)
  local transition = publicInteger(value.transition, 1)
  if not battleToken or not deploymentToken or not transition then return nil end
  local side = sideIdentity(value.side)
  return {
    schema=Lifecycle.CONTEXT_SCHEMA,
    apiVersion=Lifecycle.API_VERSION,
    generation=1,
    battleToken=battleToken,
    deploymentToken=deploymentToken,
    state=value.state,
    provider=value.provider,
    requestedMode=value.requestedMode,
    side=side,
    reason=reasonText(value.reason, nil),
    transition=transition,
  }
end

local function publicReceipt(session)
  return sanitizePublicReceipt(receipt(session))
end

local function orderedListeners()
  local ordered = {}
  for _, entry in pairs(listeners) do ordered[#ordered + 1] = entry end
  table.sort(ordered, function(a, b)
    -- Mutation ownership is an absolute visibility barrier, not a numeric
    -- priority convention an observer can accidentally outrank.
    if a.critical ~= b.critical then return a.critical == true end
    if a.priority ~= b.priority then return a.priority > b.priority end
    return a.serial < b.serial
  end)
  return ordered
end

local function orderedCommittedListeners()
  local ordered = {}
  for _, entry in pairs(committedListeners) do
    ordered[#ordered + 1] = entry
  end
  table.sort(ordered, function(a, b) return a.serial < b.serial end)
  return ordered
end

local function eventFor(kind, session, extra)
  local event = {
    schema="ascendant.battle-lifecycle-event/v1",
    apiVersion=Lifecycle.API_VERSION,
    kind=kind,
    receipt=receipt(session),
  }
  if type(extra) == "table" then
    for key, value in pairs(extra) do event[key] = value end
  end
  return event
end

local function publishCommitted(kind, session, extra)
  for _, listener in ipairs(orderedCommittedListeners()) do
    if committedListeners[listener.serial] == listener then
      -- Commit callbacks are a post-transaction notification boundary. Each
      -- receives a fresh envelope, and its failure cannot retroactively undo
      -- provider/observer work which has already committed.
      local event = eventFor(kind, session, extra)
      transitionDispatch = listener
      local ok, value, detail = pcall(listener.callback, event)
      transitionDispatch = nil
      if not ok or value == false then
        listenerFailures = listenerFailures + 1
        warn("committed battle lifecycle listener %s failed open: %s",
          safeText(listener.owner, "unknown"),
          safeText(ok and detail or value,
            "no successful committed callback receipt"))
      end
    end
  end
  local finalizer = committedFinalizer
  if finalizer ~= nil and committedFinalizer == finalizer then
    local event = eventFor(kind, session, extra)
    transitionDispatch = finalizer
    local ok, value, detail = pcall(finalizer.callback, event)
    transitionDispatch = nil
    if not ok or value ~= true then
      listenerFailures = listenerFailures + 1
      criticalFailures = criticalFailures + 1
      local reason = ("committed battle lifecycle finalizer %s %s: %s")
        :format(safeText(finalizer.owner, "unknown"),
          ok and "declined" or "threw",
          safeText(ok and detail or value,
            "no successful finalizer receipt"))
      lastCriticalError = reason
      warn("%s", reason)
      return nil, reason
    end
  end
  return true
end

local function compensateCritical(listener, event, reason, session)
  -- A Card may already have self-aborted while its callback was running. In
  -- that case the exact owner graph is gone and no second compensation is
  -- allowed to re-enter the retired activation lease.
  if not sameIdentity(active, session) then return true, reason end
  local compensate = listener and listener.compensate or nil
  if type(compensate) ~= "function" then
    local failure = "critical battle lifecycle owner has no compensation seam"
    listenerFailures = listenerFailures + 1
    criticalFailures = criticalFailures + 1
    lastCriticalError = failure
    return false, reason .. "; " .. failure
  end
  local ok, value, detail = pcall(compensate, event, reason)
  if ok and value == true then return true, reason end
  local failure = ("critical battle lifecycle compensation failed: %s")
    :format(safeText(ok and detail or value,
      "no successful compensation receipt"))
  listenerFailures = listenerFailures + 1
  criticalFailures = criticalFailures + 1
  lastCriticalError = failure
  warn("%s", failure)
  return false, reason .. "; " .. failure
end

local function publish(kind, session, extra)
  transitionSerial = transitionSerial + 1
  session.transition = transitionSerial
  local acceptedCritical = nil
  for _, listener in ipairs(orderedListeners()) do
    -- Dispatch uses a snapshot, but an earlier listener may deactivate its
    -- owner (or a sibling) while handling this same transition.  A removed
    -- listener must stop immediately rather than receiving one final stale
    -- mutable engine receipt after its rollback boundary has closed.
    if listeners[listener.serial] == listener then
      -- Each internal subscriber receives a fresh envelope and receipt. The
      -- exact host references remain available to that subscriber, but its
      -- table mutations cannot rewrite canonical tokens or a later relay.
      local event = eventFor(kind, session, extra)
      local expectedActive = active
      local expectedTransition = session.transition
      local expectedReentrySerial = transitionReentrySerial
      local expectedCritical = criticalListener
      transitionDispatch = listener
      if listener.critical then criticalDispatch = listener end
      local ok, value, detail = pcall(listener.callback, event)
      if listener.critical then criticalDispatch = nil end
      transitionDispatch = nil
      local superseded = transitionReentrySerial ~= expectedReentrySerial
        or not sameIdentity(active, expectedActive)
        or not sameIdentity(active, session)
        or session.transition ~= expectedTransition
        or criticalListener ~= expectedCritical
        or (listener.critical and listeners[listener.serial] ~= listener)

      local rejectionReason
      if listener.critical and not ok then
        listenerFailures = listenerFailures + 1
        criticalFailures = criticalFailures + 1
        rejectionReason = ("critical battle lifecycle listener %s threw: %s")
          :format(safeText(listener.owner, "unknown"),
            safeText(value, "unprintable callback error"))
        lastCriticalError = rejectionReason
      elseif superseded then
        listenerFailures = listenerFailures + 1
        if transitionReentrySerial == expectedReentrySerial then
          reentryFailures = reentryFailures + 1
        end
        if listener.critical then criticalFailures = criticalFailures + 1 end
        rejectionReason = ("battle lifecycle listener %s "
          .. "superseded %s while acquiring the transition")
          :format(safeText(listener.owner, "unknown"), safeText(kind))
        lastReentryError = rejectionReason
        if listener.critical then lastCriticalError = rejectionReason end
      elseif listener.critical and value ~= true then
        listenerFailures = listenerFailures + 1
        criticalFailures = criticalFailures + 1
        rejectionReason =
          ("critical battle lifecycle listener %s declined %s: %s")
          :format(safeText(listener.owner, "unknown"), safeText(kind),
            safeText(detail, "no successful transition receipt"))
        lastCriticalError = rejectionReason
      elseif not listener.critical and not ok then
        listenerFailures = listenerFailures + 1
        warn("battle lifecycle listener %s failed open: %s",
          safeText(listener.owner, "unknown"),
          safeText(value, "unprintable callback error"))
      elseif not listener.critical and value == false then
        -- Ordinary observers cannot roll a committed provider mutation back
        -- themselves. Their explicit refusal stops lower observers and asks
        -- the accepted critical owner to compensate the whole transaction.
        listenerFailures = listenerFailures + 1
        observerRefusals = observerRefusals + 1
        rejectionReason =
          ("battle lifecycle listener %s declined %s: %s")
          :format(safeText(listener.owner, "unknown"), safeText(kind),
            safeText(detail, "explicit observer refusal"))
        lastObserverError = rejectionReason
      end

      if rejectionReason then
        warn("%s", rejectionReason)
        local owner = listener.critical and listener or acceptedCritical
        local compensated, finalReason = compensateCritical(
          owner, event, rejectionReason, session)
        -- A failed compensator leaves the mutated owner quarantined. Callers
        -- must not restore only Lifecycle and thereby split it from Provider.
        return nil, finalReason, not compensated
      end
      if listener.critical then acceptedCritical = listener end
    end
  end
  local finalized, finalizerReason = publishCommitted(kind, session, extra)
  if finalized ~= true then
    -- The exclusive finalizer owns the provider transaction boundary. Its
    -- failure may already have retired the exact graph, so callers must not
    -- restore Lifecycle alone and split it from Provider state.
    return nil, finalizerReason, true
  end
  return receipt(session)
end

local function exactOwner(battle)
  return active ~= nil and battle ~= nil
    and sameIdentity(active.battle, battle)
end

local function eventBattle(value)
  if type(value) == "table" and rawget(value, "battle") ~= nil then
    return value.battle
  end
  return value
end

local function rejectTransitionReentry()
  local listener = transitionDispatch
  if listener then
    transitionReentrySerial = transitionReentrySerial + 1
    reentryFailures = reentryFailures + 1
    local reason = ("battle lifecycle transition reentry from listener %s "
      .. "is forbidden"):format(safeText(listener.owner, "unknown"))
    lastReentryError = reason
    return reason
  end
  return nil
end

local function endActive(reason, kind)
  if not active then return nil end
  local session = active
  local previousState = session.state
  local previousReason = session.reason
  local previousTransition = session.transition
  session.state = "ended"
  session.reason = reasonText(reason,
    reasonText(session.reason, "ended"))
  local ended, publishReason, rollbackUnsafe =
    publish(kind or "ended", session)
  if not ended then
    if sameIdentity(active, session) and not rollbackUnsafe then
      session.state = previousState
      session.reason = previousReason
      session.transition = previousTransition
    end
    return nil, publishReason
  end
  -- The live event may carry the exact BattleState to internal listeners, but
  -- the diagnostic "last" receipt outlives that battle.  Retaining the raw
  -- object here would keep its canvases, parties and companion state alive
  -- until another battle ends. Tokens are the durable identity contract.
  lastEnded = shallowCopy(ended)
  lastEnded.battle = nil
  lastEnded.context = nil
  if sameIdentity(active, session) then active = nil end
  return ended
end

-- Reserve presentation ownership before BattleState is visible.  Repeating a
-- claim for the same object is idempotent; a different object retires the old
-- owner first rather than lending it a stale camera/HUD/renderer session.
function Lifecycle.claim(battle, context)
  local reentryReason = rejectTransitionReentry()
  if reentryReason then return nil, reentryReason end
  context = type(context) == "table" and shallowCopy(context) or {}
  if battle == nil then return nil, "battle owner is required" end
  local requestedValue = context.requestedMode
  if requestedValue == nil then requestedValue = context.mode end
  local requested = modeName(requestedValue)
  if requestedValue ~= nil and requested == nil then
    return nil, "unknown requested battle mode " .. tostring(requestedValue)
  end
  local provider
  if context.provider ~= nil then
    provider = modeName(context.provider)
  else
    provider = requested or "DEFAULT"
  end
  if provider == nil or not PROVIDERS[provider] then
    return nil, "unknown battle provider " .. tostring(context.provider)
  end
  if active and sameIdentity(active.battle, battle) then
    local requestedMode = requested or provider
    if provider ~= active.provider then
      return nil, "battle provider mismatch: expected "
        .. tostring(active.provider) .. ", got " .. tostring(provider)
    end
    if requestedMode ~= active.requestedMode then
      return nil, "requested battle mode mismatch: expected "
        .. tostring(active.requestedMode) .. ", got "
        .. tostring(requestedMode)
    end
    return receipt(active)
  end
  if active then
    local retired, retireReason = endActive(
      "replaced-by-new-battle", "aborted")
    if not retired then return nil, retireReason end
  end
  serial = serial + 1
  local session = {
    battle=battle,
    battleToken=serial,
    deploymentToken=0,
    state="created",
    provider=provider,
    requestedMode=requested or provider,
    context=context,
  }
  active = session
  local created, createReason, rollbackUnsafe = publish("created", session)
  if not created then
    if sameIdentity(active, session) and not rollbackUnsafe then active = nil end
    return nil, createReason
  end
  return created
end

-- battle.started is the point at which the engine's exact BattleState owns
-- the stack.  Battles which bypass the overworld seam are represented as
-- DEFAULT until a staged renderer explicitly claims them during ensure().
function Lifecycle.started(payload)
  local reentryReason = rejectTransitionReentry()
  if reentryReason then return nil, reentryReason end
  local battle = eventBattle(payload)
  if battle == nil then return nil, "battle.started omitted battle" end
  if not active or not sameIdentity(active.battle, battle) then
    local claimed, claimReason = Lifecycle.claim(battle, {
      provider="DEFAULT",
      requestedMode="DEFAULT",
      entry="battle.started",
    })
    if not claimed then return nil, claimReason end
  end
  if not exactOwner(battle) then return nil, "battle owner mismatch" end
  if active.state == "created" then
    local session = active
    local previousState = session.state
    local previousReason = session.reason
    local previousTransition = session.transition
    session.state = "active"
    session.reason = nil
    local started, startReason, rollbackUnsafe = publish("started", session)
    if not started and sameIdentity(active, session) and not rollbackUnsafe then
      session.state = previousState
      session.reason = previousReason
      session.transition = previousTransition
    end
    return started, startReason
  end
  return receipt(active)
end

-- Translate the public engine event into a deployment boundary.  This is
-- deliberately exact-owner: a delayed event from a previous battle cannot
-- perturb the replacement state of the current one.
function Lifecycle.replacing(payload)
  local reentryReason = rejectTransitionReentry()
  if reentryReason then return nil, reentryReason end
  local battle = type(payload) == "table" and payload.battle or nil
  if not exactOwner(battle) then return nil, "battle owner mismatch" end
  local session = active
  if session.state == "ended" then return nil, "battle already ended" end
  local previousDeploymentToken = session.deploymentToken
  local previousSide = session.side
  local previousState = session.state
  local previousReason = session.reason
  local previousTransition = session.transition
  session.deploymentToken = session.deploymentToken + 1
  session.side = sideIdentity(payload.side)
  local replaced, replaceReason
  if session.state == "native_latched" then
    local rollbackUnsafe
    replaced, replaceReason, rollbackUnsafe =
      publish("battler-switched-native", session, {
      battler=payload.battler,
      previous=payload.previous,
    })
    if not replaced and sameIdentity(active, session) and not rollbackUnsafe then
      session.deploymentToken = previousDeploymentToken
      session.side = previousSide
      session.state = previousState
      session.reason = previousReason
      session.transition = previousTransition
    end
    return replaced, replaceReason
  end
  session.state = "replacing"
  session.reason = nil
  local rollbackUnsafe
  replaced, replaceReason, rollbackUnsafe = publish("replacing", session, {
    battler=payload.battler,
    previous=payload.previous,
  })
  if not replaced and sameIdentity(active, session) and not rollbackUnsafe then
    session.deploymentToken = previousDeploymentToken
    session.side = previousSide
    session.state = previousState
    session.reason = previousReason
    session.transition = previousTransition
  end
  return replaced, replaceReason
end

-- A provider calls committed only after a complete frame for the current
-- deployment has been published.  Once native_latched, recovery is rejected
-- for this battle to prevent visible renderer oscillation.
function Lifecycle.committed(battle, context)
  local reentryReason = rejectTransitionReentry()
  if reentryReason then return nil, reentryReason end
  if not exactOwner(battle) then return nil, "battle owner mismatch" end
  if active.state == "native_latched" then
    return nil, "battle is native-latched"
  end
  if active.state == "ended" then return nil, "battle already ended" end
  local session = active
  local previousState = session.state
  local previousReason = session.reason
  local previousContext = session.context
  local previousTransition = session.transition
  if type(context) == "table" then
    if context.provider ~= nil then
      local provider = modeName(context.provider)
      if not PROVIDERS[provider] then
        return nil, "unknown battle provider " .. tostring(context.provider)
      end
      -- The provider is selected once, at claim time.  A frame/deployment
      -- receipt may confirm that choice but can never silently turn MAP into
      -- ARENA (or any other architecture) halfway through the encounter.
      -- Native fallback is the sole exception and travels through the
      -- explicit, one-way nativeLatched transition below.
      if provider ~= active.provider then
        return nil, "battle provider mismatch: expected "
          .. tostring(active.provider) .. ", got " .. tostring(provider)
      end
    end
    session.context = shallowCopy(context)
  end
  session.state = "active"
  session.reason = nil
  local committed, commitReason, rollbackUnsafe = publish("committed", session)
  if not committed and sameIdentity(active, session) and not rollbackUnsafe then
    session.state = previousState
    session.reason = previousReason
    session.context = previousContext
    session.transition = previousTransition
  end
  return committed, commitReason
end

function Lifecycle.nativeLatched(battle, reason)
  local reentryReason = rejectTransitionReentry()
  if reentryReason then return nil, reentryReason end
  if not exactOwner(battle) then return nil, "battle owner mismatch" end
  if active.state == "ended" then return nil, "battle already ended" end
  if active.state == "native_latched" then return receipt(active) end
  local session = active
  local previousState = session.state
  local previousProvider = session.provider
  local previousReason = session.reason
  local previousTransition = session.transition
  session.state = "native_latched"
  session.provider = "DEFAULT"
  session.reason = reasonText(reason, "provider-failed")
  local latched, latchReason, rollbackUnsafe = publish(
    "native-latched", session)
  if not latched and sameIdentity(active, session) and not rollbackUnsafe then
    session.state = previousState
    session.provider = previousProvider
    session.reason = previousReason
    session.transition = previousTransition
  end
  return latched, latchReason
end

function Lifecycle.finished(payload, reason)
  local reentryReason = rejectTransitionReentry()
  if reentryReason then return nil, reentryReason end
  local battle = eventBattle(payload)
  if not exactOwner(battle) then return nil, "battle owner mismatch" end
  local result = type(payload) == "table" and payload.result or nil
  return endActive(reason or result or "ended", "ended")
end

function Lifecycle.abort(battle, reason)
  local reentryReason = rejectTransitionReentry()
  if reentryReason then return nil, reentryReason end
  if not exactOwner(battle) then return nil, "battle owner mismatch" end
  return endActive(reason or "aborted", "aborted")
end

local function cleanupAbortExact(battle, reason)
  if not exactOwner(battle) then return nil, "battle owner mismatch" end
  local session = active
  transitionSerial = transitionSerial + 1
  session.transition = transitionSerial
  session.state = "ended"
  session.reason = reasonText(reason, "aborted")
  local ended = receipt(session)
  lastEnded = shallowCopy(ended)
  lastEnded.battle = nil
  lastEnded.context = nil
  active = nil
  return ended
end

-- Card rollback sometimes starts synchronously inside the critical provider
-- callback which rejected a transition. The Card first removes every
-- lifecycle listener, then needs to release the exact lifecycle owner without
-- recursively publishing another transition from the still-running callback
-- or from a later compensation pass. This internal seam is not exposed by
-- public() and is valid only after the critical owner has been removed.
function Lifecycle.cleanupAbort(battle, reason)
  local dispatch = transitionDispatch
  if dispatch and (listeners[dispatch.serial] == dispatch
      or committedListeners[dispatch.serial] == dispatch
      or committedFinalizer == dispatch) then
    transitionReentrySerial = transitionReentrySerial + 1
    reentryFailures = reentryFailures + 1
    lastReentryError =
      "dispatching lifecycle listener must unsubscribe before cleanup abort"
    return nil, lastReentryError
  end
  if criticalListener ~= nil then
    transitionReentrySerial = transitionReentrySerial + 1
    reentryFailures = reentryFailures + 1
    lastReentryError =
      "a critical lifecycle owner remains during cleanup abort"
    return nil, lastReentryError
  end
  return cleanupAbortExact(battle, reason)
end

function Lifecycle.current(battle)
  if battle ~= nil and not exactOwner(battle) then return nil end
  return receipt(active)
end

function Lifecycle.last()
  return lastEnded and shallowCopy(lastEnded) or nil
end

local function subscribe(owner, callback, priority, critical, compensate)
  if type(owner) == "function" and callback == nil then
    callback, owner = owner, "anonymous"
  end
  if type(callback) ~= "function" then
    return nil, "battle lifecycle callback is required"
  end
  if critical and type(compensate) ~= "function" then
    return nil, "critical battle lifecycle compensation is required"
  end
  if critical and transitionDispatch ~= nil then
    return nil, "battle lifecycle dispatch is already in progress"
  end
  if critical and criticalListener
      and listeners[criticalListener.serial] == criticalListener then
    return nil, "critical battle lifecycle owner is already subscribed: "
      .. tostring(criticalListener.owner)
  end
  listenerSerial = listenerSerial + 1
  local token = listenerSerial
  local entry = {
    serial=token,
    owner=safeText(owner, "anonymous"),
    callback=callback,
    priority=tonumber(priority) or 0,
    critical=critical == true,
    compensate=critical and compensate or nil,
  }
  listeners[token] = entry
  if critical then criticalListener = entry end
  local removed = false
  local function unsubscribe()
    if removed then return false end
    removed = true
    listeners[token] = nil
    if criticalListener == entry then criticalListener = nil end
    return true
  end
  if not critical then return unsubscribe end

  -- The critical owner is also the only component allowed to retire its exact
  -- Lifecycle session while keeping the deny listener installed.  This
  -- owner-private token lets Card cleanup keep that barrier alive across
  -- renderer/content teardown without exposing a generic mutation seam.
  local control = {
    schema="ascendant.battle-lifecycle-critical-control/v1",
    cleanupAbort=function(battle, reason)
      if removed or listeners[token] ~= entry
          or criticalListener ~= entry then
        return nil, "critical lifecycle cleanup control is inactive"
      end
      return cleanupAbortExact(battle, reason)
    end,
  }
  return unsubscribe, control
end

function Lifecycle.subscribe(owner, callback, priority)
  return subscribe(owner, callback, priority, false)
end

-- Critical listeners are private mutation owners, not observers.  Returning
-- anything other than true (or throwing) rejects the transition before later
-- public observers can see it.  The API is deliberately absent from public().
function Lifecycle.subscribeCritical(owner, callback, priority, compensate)
  return subscribe(owner, callback, priority, true, compensate)
end

-- Committed listeners run only after the critical owner and every ordinary
-- observer accepted the transition. They are the publication boundary for
-- sanitized relays and deliberately cannot veto an already-committed owner.
-- This private seam is absent from public().
function Lifecycle.subscribeCommitted(owner, callback)
  if type(owner) == "function" and callback == nil then
    callback, owner = owner, "anonymous"
  end
  if type(callback) ~= "function" then
    return nil, "committed battle lifecycle callback is required"
  end
  listenerSerial = listenerSerial + 1
  local token = listenerSerial
  local entry = {
    serial=token,
    owner=safeText(owner, "anonymous"),
    callback=callback,
  }
  committedListeners[token] = entry
  local removed = false
  return function()
    if removed then return false end
    removed = true
    committedListeners[token] = nil
    return true
  end
end

-- One private finalizer runs after every committed observer and closes the
-- mutation transaction which the critical owner opened before observers.
-- Unlike ordinary committed listeners it is fail-closed and exclusive: a
-- second owner could otherwise release or replace the provider out of order.
-- This seam is intentionally absent from public().
function Lifecycle.subscribeCommittedFinalizer(owner, callback)
  if type(owner) == "function" and callback == nil then
    callback, owner = owner, "anonymous"
  end
  if type(callback) ~= "function" then
    return nil, "committed battle lifecycle finalizer is required"
  end
  if transitionDispatch ~= nil then
    return nil, "battle lifecycle dispatch is already in progress"
  end
  if committedFinalizer ~= nil then
    return nil, "committed battle lifecycle finalizer is already subscribed: "
      .. tostring(committedFinalizer.owner)
  end
  listenerSerial = listenerSerial + 1
  local entry = {
    serial=listenerSerial,
    owner=safeText(owner, "anonymous"),
    callback=callback,
  }
  committedFinalizer = entry
  local removed = false
  return function()
    if removed then return false end
    removed = true
    if committedFinalizer == entry then committedFinalizer = nil end
    return true
  end
end

function Lifecycle.health()
  local current = receipt(active)
  return {
    schema="ascendant.compat-status/v1",
    apiVersion=Lifecycle.API_VERSION,
    ok=criticalFailures == 0 and reentryFailures == 0
      and observerRefusals == 0,
    active=current,
    listenerCount=(function()
      local count = 0
      for _ in pairs(listeners) do count = count + 1 end
      for _ in pairs(committedListeners) do count = count + 1 end
      if committedFinalizer ~= nil then count = count + 1 end
      return count
    end)(),
    listenerFailures=listenerFailures,
    criticalFailures=criticalFailures,
    reentryFailures=reentryFailures,
    observerRefusals=observerRefusals,
    criticalOwner=criticalListener and criticalListener.owner or nil,
    committedFinalizerOwner=committedFinalizer
      and committedFinalizer.owner or nil,
    lastCriticalError=lastCriticalError,
    lastReentryError=lastReentryError,
    lastObserverError=lastObserverError,
    transitions=transitionSerial,
  }
end


-- Public observers receive identity tokens and presentation state, never the
-- mutable BattleState, battlers or renderer context tables.  Engine-owned
-- event subscriptions provide their rollback/owner boundary.
function Lifecycle.publicEvent(event)
  if type(event) ~= "table" or type(event.kind) ~= "string" then return nil end
  return {
    schema="ascendant.battle-lifecycle-public-event/v1",
    apiVersion=Lifecycle.API_VERSION,
    kind=event.kind,
    receipt=sanitizePublicReceipt(event.receipt),
  }
end

function Lifecycle.public()
  return {
    apiVersion=Lifecycle.API_VERSION,
    contextSchema=Lifecycle.CONTEXT_SCHEMA,
    providerSchema=Lifecycle.PROVIDER_SCHEMA,
    states=shallowCopy(STATES),
    providers=shallowCopy(PROVIDERS),
    event="mod.VOXEL_ASCENDANT.battle_lifecycle_v1",
    current=function(battle)
      local value = Lifecycle.current(battle)
      return sanitizePublicReceipt(value)
    end,
    last=function()
      local value = Lifecycle.last()
      return sanitizePublicReceipt(value)
    end,
    health=function()
      local value = Lifecycle.health()
      return {
        schema=value.schema,
        apiVersion=value.apiVersion,
        ok=value.ok,
        active=publicReceipt(active),
        listenerCount=value.listenerCount,
        listenerFailures=value.listenerFailures,
        criticalFailures=value.criticalFailures,
        reentryFailures=value.reentryFailures,
        observerRefusals=value.observerRefusals,
        criticalOwner=value.criticalOwner,
        lastCriticalError=value.lastCriticalError,
        lastReentryError=value.lastReentryError,
        lastObserverError=value.lastObserverError,
        transitions=value.transitions,
      }
    end,
  }
end

Lifecycle.modeName = modeName
Lifecycle.sideIdentity = sideIdentity
return Lifecycle
