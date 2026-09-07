-- Exact-owner Gen-2 battle lifecycle adapter.
--
-- Gold's logic emits battle.ended before the concrete BattleState has drained
-- its visible faint/victory/evolution/exit queue.  A logic end is therefore a
-- latch, never a terminal edge.  The composite logic/screen owner remains
-- live until the exact screen is popped or an explicit watchdog abort retires
-- it.  This module owns no engine subscriptions and no renderer; both are
-- injected by Gen2BattleLifecycleCard.

local Lifecycle = {
  API_VERSION = 1,
  CONTEXT_SCHEMA = "ascendant.battle-context/v1",
  EVENT_SCHEMA = "ascendant.battle-lifecycle-event/v1",
}

local STATES = {
  active=true,
  screen_bound=true,
  end_pending=true,
  rollback_pending=true,
  ended=true,
  aborted=true,
}

local PROVIDERS = {
  DEFAULT=true,
  MAP=true,
  ARENA=true,
  DISCS=true,
}

local Adapter = {}
Adapter.__index = Adapter

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

local function primitiveReason(value, fallback)
  local kind = type(value)
  if kind == "string" then return value end
  if kind == "number" or kind == "boolean" then
    return safeText(value, fallback)
  end
  return fallback
end

local function normalizeProvider(value)
  if value == true then return "MAP" end
  if value == false or value == nil then return "DEFAULT" end
  if type(value) == "string" then
    local key = value:lower():gsub("[%s_-]+", "")
    if key == "map" or key == "true" or key == "2d3da" then
      return "MAP"
    end
    if key == "arena" or key == "stadium" then return "ARENA" end
    if key == "discs" or key == "disc" or key == "flatb"
        or key == "stadiumb" or key == "2d3db" then
      return "DISCS"
    end
    if key == "default" or key == "off" or key == "false" or key == "0"
        or key == "native" or key == "2d" or key == "gamedefault" then
      return "DEFAULT"
    end
  end
  return nil
end

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

local function copyPrimitives(source)
  if type(source) ~= "table" then return nil end
  local result = {}
  for key, value in pairs(source) do
    local keyKind, valueKind = type(key), type(value)
    if (keyKind == "string" or keyKind == "number")
        and (valueKind == "nil" or valueKind == "boolean"
          or valueKind == "number" or valueKind == "string") then
      result[key] = value
    end
  end
  return result
end

local function internalReceipt(session)
  if session == nil then return nil end
  return {
    schema=Lifecycle.CONTEXT_SCHEMA,
    apiVersion=Lifecycle.API_VERSION,
    generation=2,
    owner=session.owner,
    logic=session.logic,
    screen=session.screen,
    battleToken=session.battleToken,
    deploymentToken=session.deploymentToken,
    transition=session.transition,
    state=session.state,
    provider=session.provider,
    requestedMode=session.requestedMode,
    side=session.side,
    reason=primitiveReason(session.reason, nil),
    entry=session.entry,
  }
end

local function publicReceipt(value)
  if type(value) ~= "table"
      or value.schema ~= Lifecycle.CONTEXT_SCHEMA
      or value.apiVersion ~= Lifecycle.API_VERSION
      or value.generation ~= 2
      or not STATES[value.state]
      or not PROVIDERS[value.provider]
      or not PROVIDERS[value.requestedMode]
      or type(value.battleToken) ~= "number"
      or value.battleToken < 1
      or value.battleToken % 1 ~= 0
      or type(value.deploymentToken) ~= "number"
      or value.deploymentToken < 0
      or value.deploymentToken % 1 ~= 0
      or type(value.transition) ~= "number"
      or value.transition < 1
      or value.transition % 1 ~= 0 then
    return nil
  end
  return {
    schema=Lifecycle.CONTEXT_SCHEMA,
    apiVersion=Lifecycle.API_VERSION,
    generation=2,
    battleToken=value.battleToken,
    deploymentToken=value.deploymentToken,
    transition=value.transition,
    state=value.state,
    provider=value.provider,
    requestedMode=value.requestedMode,
    side=sideIdentity(value.side),
    reason=primitiveReason(value.reason, nil),
    entry=type(value.entry) == "string" and value.entry or nil,
    screenBound=value.screen ~= nil or value.screenBound == true,
    endPending=value.state == "end_pending" or value.endPending == true,
  }
end

local function eventEnvelope(kind, session, extra)
  local event = {
    schema=Lifecycle.EVENT_SCHEMA,
    apiVersion=Lifecycle.API_VERSION,
    generation=2,
    kind=kind,
    receipt=internalReceipt(session),
  }
  if type(extra) == "table" then
    for key, value in pairs(extra) do event[key] = value end
  end
  return event
end

local function exactLogic(session, value)
  return session ~= nil and value ~= nil and same(session.logic, value)
end

local function exactScreen(session, value)
  return session ~= nil and session.screen ~= nil and value ~= nil
    and same(session.screen, value)
end

local function exactOwner(session, value)
  if session == nil or value == nil then return false end
  if same(session.owner, value) or exactScreen(session, value) then return true end
  -- Once a concrete screen is bound, its identity protects a later screen
  -- which deliberately reuses the same logic table from a stale logic abort.
  return session.screen == nil and exactLogic(session, value)
end

local function engineOwner(session, payload)
  if session == nil or type(payload) ~= "table" then return false end
  if exactLogic(session, rawget(payload, "battle")) then return true end
  if exactScreen(session, rawget(payload, "screen")) then return true end
  if same(session.owner, rawget(payload, "owner")) then return true end
  return false
end

function Lifecycle.new(options)
  options = type(options) == "table" and options or {}
  return setmetatable({
    isBattleScreen=options.isBattleScreen,
    active=nil,
    lastEnded=nil,
    battleSerial=0,
    transitionSerial=0,
    listenerSerial=0,
    critical=nil,
    observers={},
    dispatching=false,
    retired=false,
    transitions=0,
    starts=0,
    screenBinds=0,
    replacements=0,
    switches=0,
    movesObserved=0,
    logicEnds=0,
    finishes=0,
    aborts=0,
    ignored=0,
    listenerFailures=0,
    criticalFailures=0,
    compensationFailures=0,
    reentryFailures=0,
    lastError=nil,
  }, Adapter)
end

function Adapter:_ignored(reason)
  self.ignored = self.ignored + 1
  return nil, reason or "ignored", true
end

function Adapter:_isBattleScreen(state)
  if type(state) ~= "table" then return false end
  local predicate = self.isBattleScreen
  if type(predicate) ~= "function" then
    return rawget(state, "_vascGen2BattleScreenOwner") == true
  end
  local ok, value = pcall(predicate, state)
  if not ok then
    self.lastError = "battle screen predicate threw: "
      .. safeText(value, "unprintable predicate error")
    return false
  end
  return value == true
end

function Adapter:_reentryError()
  if not self.dispatching then return nil end
  self.reentryFailures = self.reentryFailures + 1
  return "Gen2 battle lifecycle transition reentry is forbidden"
end

-- Card teardown is a multi-owner transaction (engine subscriptions, provider,
-- critical relay and lifecycle token). Callers must preflight it before the
-- first mutation so a synchronous public observer cannot half-retire the
-- graph from inside the transition it is currently observing.
function Adapter:canCleanup()
  if self.dispatching then
    return false, "Gen2 battle lifecycle dispatch is in progress"
  end
  if self.retired then
    return false, "Gen2 battle lifecycle is retired"
  end
  return true
end

function Adapter:_dispatch(kind, session, extra, rollback)
  if self.retired then return nil, "Gen2 battle lifecycle is retired" end
  local reentryError = self:_reentryError()
  if reentryError ~= nil then
    if type(rollback) == "function" then rollback() end
    return nil, reentryError
  end

  self.transitionSerial = self.transitionSerial + 1
  self.transitions = self.transitions + 1
  session.transition = self.transitionSerial
  local critical = self.critical
  if critical == nil then
    if type(rollback) == "function" then rollback() end
    self.criticalFailures = self.criticalFailures + 1
    self.lastError = "Gen2 battle lifecycle has no critical owner"
    return nil, self.lastError
  end

  self.dispatching = true
  local event = eventEnvelope(kind, session, extra)
  local ok, value, detail = pcall(critical.callback, event)
  local criticalChanged = not same(self.critical, critical)
  if not ok or value ~= true or criticalChanged then
    self.listenerFailures = self.listenerFailures + 1
    self.criticalFailures = self.criticalFailures + 1
    local outcome = criticalChanged and "changed ownership during"
      or (ok and "declined" or "threw")
    local failure = criticalChanged and "critical owner identity changed"
      or safeText(ok and detail or value, "transition was not accepted")
    local reason = ("critical Gen2 lifecycle owner %s %s %s: %s")
      :format(safeText(critical.owner, "unknown"), outcome, kind, failure)
    self.lastError = reason
    local compensated = false
    if type(critical.compensate) == "function" then
      local compensatedOK, result = pcall(
        critical.compensate, eventEnvelope(kind, session, extra), reason)
      compensated = compensatedOK and result == true
    end
    -- Compensation belongs to the same transition transaction.  Keeping the
    -- dispatch lease raised prevents a compensator from publishing a nested
    -- watchdog/end/cleanup transition while the outer mutation is rolling
    -- back.  It may still compensate its injected provider/renderer owner.
    self.dispatching = false
    if compensated then
      if type(rollback) == "function" then rollback() end
    else
      self.compensationFailures = self.compensationFailures + 1
      session.state = "rollback_pending"
      session.reason = reason
    end
    return nil, reason
  end

  local ordered = {}
  for _, observer in pairs(self.observers) do
    ordered[#ordered + 1] = observer
  end
  table.sort(ordered, function(left, right)
    if left.priority ~= right.priority then
      return left.priority > right.priority
    end
    return left.serial < right.serial
  end)
  for _, observer in ipairs(ordered) do
    if self.observers[observer.serial] == observer then
      local observedOK, observedValue = pcall(
        observer.callback, eventEnvelope(kind, session, extra))
      if not observedOK or observedValue == false then
        -- Observers are diagnostics/publication only.  They can never undo a
        -- provider mutation which the exclusive critical owner committed.
        self.listenerFailures = self.listenerFailures + 1
      end
    end
  end
  self.dispatching = false
  return internalReceipt(session)
end

function Adapter:subscribeCritical(owner, callback, compensate)
  if self.retired then
    return nil, "Gen2 battle lifecycle is retired"
  end
  if type(callback) ~= "function" then
    return nil, "critical Gen2 lifecycle callback is required"
  end
  if type(compensate) ~= "function" then
    return nil, "critical Gen2 lifecycle compensation is required"
  end
  if self.dispatching then
    return nil, "Gen2 battle lifecycle dispatch is in progress"
  end
  if self.critical ~= nil then
    return nil, "critical Gen2 lifecycle owner is already subscribed: "
      .. safeText(self.critical.owner, "unknown")
  end
  self.listenerSerial = self.listenerSerial + 1
  local entry = {
    serial=self.listenerSerial,
    owner=safeText(owner, "anonymous"),
    callback=callback,
    compensate=compensate,
  }
  self.critical = entry
  local removed = false
  return function()
    if removed or not same(self.critical, entry) then return false end
    if self.dispatching then return false end
    removed = true
    self.critical = nil
    return true
  end
end

function Adapter:subscribe(owner, callback, priority)
  if self.retired then
    return nil, "Gen2 battle lifecycle is retired"
  end
  if self.dispatching then
    return nil, "Gen2 battle lifecycle dispatch is in progress"
  end
  if type(callback) ~= "function" then
    return nil, "Gen2 lifecycle observer callback is required"
  end
  self.listenerSerial = self.listenerSerial + 1
  local entry = {
    serial=self.listenerSerial,
    owner=safeText(owner, "anonymous"),
    callback=callback,
    priority=tonumber(priority) or 0,
  }
  self.observers[entry.serial] = entry
  local removed = false
  return function()
    if removed or self.observers[entry.serial] ~= entry then return false end
    removed = true
    self.observers[entry.serial] = nil
    return true
  end
end

function Adapter:_newSession(logic, context, screen)
  local requestedValue = context.requestedMode
  if requestedValue == nil then requestedValue = context.mode end
  local requested = normalizeProvider(requestedValue)
  if requestedValue ~= nil and requested == nil then
    return nil, "unknown Gen2 requested battle mode "
      .. safeText(requestedValue)
  end
  local providerValue = context.provider
  local provider = providerValue == nil and (requested or "DEFAULT")
    or normalizeProvider(providerValue)
  if provider == nil or not PROVIDERS[provider] then
    return nil, "unknown Gen2 battle provider " .. safeText(providerValue)
  end
  requested = requested or provider
  local inheritedEnd = context.inheritEndPending == true
  self.battleSerial = self.battleSerial + 1
  return {
    owner={},
    logic=logic,
    screen=screen,
    battleToken=self.battleSerial,
    deploymentToken=0,
    transition=0,
    state=inheritedEnd and "end_pending"
      or (screen and "screen_bound" or "active"),
    provider=provider,
    requestedMode=requested,
    reason=inheritedEnd
      and primitiveReason(context.reason, "logic-ended") or nil,
    entry=type(context.entry) == "string" and context.entry or nil,
  }
end

function Adapter:started(payload, context)
  if self.retired then return nil, "Gen2 battle lifecycle is retired" end
  local reentryError = self:_reentryError()
  if reentryError ~= nil then return nil, reentryError, true end
  payload = type(payload) == "table" and payload or {}
  context = type(context) == "table" and context or {}
  local logic = rawget(payload, "battle") or rawget(payload, "logic")
  if logic == nil then return nil, "battle.started omitted Gen2 logic owner" end
  local screen = rawget(payload, "screen")
  if screen ~= nil and (not self:_isBattleScreen(screen)
      or not same(rawget(screen, "battle"), logic)) then
    return nil, "battle.started supplied a foreign Gen2 screen"
  end
  if self.active ~= nil then
    local previous = self.active
    local sameLogicOwner = exactLogic(previous, logic)
    if sameLogicOwner then
      if screen == nil or exactScreen(self.active, screen) then
        return internalReceipt(self.active)
      end
      if self.active.screen == nil then
        return self:screenPushed({screen=screen})
      end
      -- A concrete presentation replacement may arrive either through the
      -- normal screen.pushed event or directly on battle.started. Preserve a
      -- previously latched logic end identically on both supported seams.
      local inherited = {}
      for key, value in pairs(context) do inherited[key] = value end
      -- A second concrete screen for the same logic owner is a presentation
      -- replacement, never a new encounter/provider decision.  Freeze both
      -- values from the first accepted start even when a caller supplies a
      -- freshly resolved (and now different) option in this direct seam.
      inherited.provider = previous.provider
      inherited.requestedMode = previous.requestedMode
      inherited.inheritEndPending = previous.state == "end_pending"
      inherited.reason = previous.reason
      inherited.entry = inherited.entry or "screen-replacement"
      context = inherited
    end
    -- Gold may start encounter B before the delayed logic-end/screen-pop from
    -- encounter A arrives. Retire A through the same exact watchdog edge used
    -- by replacement recovery, including provider/content compensation, then
    -- mint a fresh owner/token for B. Delayed A events cannot match B's exact
    -- logic or screen.
    local aborted, abortReason = self:watchdogAbort(previous.owner,
      sameLogicOwner and "same-logic-screen-replaced"
        or "battle-logic-replaced")
    if not aborted then return nil, abortReason end
    self.replacements = self.replacements + 1
  end
  local session, reason = self:_newSession(logic, context, screen)
  if not session then return nil, reason end
  self.active = session
  local started, startReason = self:_dispatch("started", session, {
    payload=copyPrimitives(payload),
  }, function()
    if same(self.active, session) then self.active = nil end
  end)
  if not started then return nil, startReason end
  self.starts = self.starts + 1
  return started
end

function Adapter:screenPushed(payload)
  local reentryError = self:_reentryError()
  if reentryError ~= nil then return nil, reentryError, true end
  payload = type(payload) == "table" and payload or {}
  local screen = rawget(payload, "state") or rawget(payload, "screen")
  local current = self.active
  if current == nil or not self:_isBattleScreen(screen)
      or not same(rawget(screen, "battle"), current.logic) then
    return self:_ignored("screen.pushed is not the exact Gen2 battle screen")
  end
  if exactScreen(current, screen) then return internalReceipt(current) end
  if current.screen ~= nil then
    return self:started({battle=current.logic, screen=screen}, {
      provider=current.provider,
      requestedMode=current.requestedMode,
      entry="screen-replacement",
    })
  end

  local previousState, previousScreen = current.state, current.screen
  local previousReason, previousTransition = current.reason,
    current.transition
  current.screen = screen
  if previousState ~= "end_pending" then
    current.state = "screen_bound"
    current.reason = nil
  end
  local bound, boundReason = self:_dispatch("screen-bound", current, nil,
    function()
      current.screen = previousScreen
      current.state = previousState
      current.reason = previousReason
      current.transition = previousTransition
    end)
  if not bound then return nil, boundReason end
  self.screenBinds = self.screenBinds + 1
  return bound
end

function Adapter:battlerSwitched(payload)
  local reentryError = self:_reentryError()
  if reentryError ~= nil then return nil, reentryError, true end
  payload = type(payload) == "table" and payload or {}
  local current = self.active
  if current == nil or not engineOwner(current, payload) then
    return self:_ignored("battle.battler_switched is stale")
  end
  if current.state == "end_pending" then
    return nil, "Gen2 battler switch arrived after logic end"
  end
  if current.state == "rollback_pending" then
    return nil, "Gen2 battle lifecycle rollback is pending"
  end
  local previousDeployment, previousState = current.deploymentToken,
    current.state
  local previousSide, previousReason = current.side, current.reason
  local previousTransition = current.transition
  current.deploymentToken = current.deploymentToken + 1
  current.side = sideIdentity(rawget(payload, "side"))
  current.state = current.screen and "screen_bound" or "active"
  current.reason = nil
  local switched, switchReason = self:_dispatch(
    "battler-switched", current, {
      battler=rawget(payload, "battler"),
      previous=rawget(payload, "previous"),
    }, function()
      current.deploymentToken = previousDeployment
      current.state = previousState
      current.side = previousSide
      current.reason = previousReason
      current.transition = previousTransition
    end)
  if not switched then return nil, switchReason end
  self.switches = self.switches + 1
  return switched
end

function Adapter:moveUsed(payload)
  local reentryError = self:_reentryError()
  if reentryError ~= nil then return nil, reentryError, true end
  payload = type(payload) == "table" and payload or {}
  local current = self.active
  if current == nil or not engineOwner(current, payload) then
    return self:_ignored("battle.move_used is stale")
  end
  if current.state == "rollback_pending" then
    return nil, "Gen2 battle lifecycle rollback is pending"
  end
  local previousTransition = current.transition
  local observed, observedReason = self:_dispatch("move-observed", current, {
    move=rawget(payload, "move"),
    user=rawget(payload, "user"),
    target=rawget(payload, "target"),
    isCalled=rawget(payload, "isCalled") == true,
    presentationOwner="animForMove",
  }, function()
    current.transition = previousTransition
  end)
  if not observed then return nil, observedReason end
  self.movesObserved = self.movesObserved + 1
  return observed
end

function Adapter:logicEnded(payload, reason)
  local reentryError = self:_reentryError()
  if reentryError ~= nil then return nil, reentryError, true end
  payload = type(payload) == "table" and payload or {}
  local current = self.active
  local logic = rawget(payload, "battle") or rawget(payload, "logic")
  if current == nil or not exactLogic(current, logic) then
    return self:_ignored("battle.ended is stale")
  end
  if current.state == "end_pending" then return internalReceipt(current) end
  if current.state == "rollback_pending" then
    return nil, "Gen2 battle lifecycle rollback is pending"
  end
  local previousState, previousReason = current.state, current.reason
  local previousTransition = current.transition
  current.state = "end_pending"
  current.reason = primitiveReason(reason,
    primitiveReason(rawget(payload, "result"), "logic-ended"))
  local ended, endReason = self:_dispatch("logic-ended", current, nil,
    function()
      current.state = previousState
      current.reason = previousReason
      current.transition = previousTransition
    end)
  if not ended then return nil, endReason end
  self.logicEnds = self.logicEnds + 1
  return ended
end

function Adapter:screenPopped(payload)
  local reentryError = self:_reentryError()
  if reentryError ~= nil then return nil, reentryError, true end
  payload = type(payload) == "table" and payload or {}
  local screen = rawget(payload, "state") or rawget(payload, "screen")
  local current = self.active
  if current == nil or not exactScreen(current, screen) then
    return self:_ignored("screen.popped is not the exact Gen2 battle screen")
  end
  if current.state == "rollback_pending" then
    return nil, "Gen2 battle lifecycle rollback is pending"
  end
  local previousState, previousReason = current.state, current.reason
  local previousTransition = current.transition
  current.state = "ended"
  current.reason = primitiveReason(rawget(payload, "reason"),
    primitiveReason(current.reason, "screen-popped"))
  local ended, endReason = self:_dispatch("screen-popped", current, nil,
    function()
      current.state = previousState
      current.reason = previousReason
      current.transition = previousTransition
    end)
  if not ended then return nil, endReason end
  self.finishes = self.finishes + 1
  self.lastEnded = publicReceipt(internalReceipt(current))
  if same(self.active, current) then self.active = nil end
  return ended
end

function Adapter:watchdogAbort(expected, reason)
  local reentryError = self:_reentryError()
  if reentryError ~= nil then return nil, reentryError, true end
  local current = self.active
  if current == nil then return true end
  if not exactOwner(current, expected) then
    return nil, "watchdog abort owner mismatch"
  end
  local previousState, previousReason = current.state, current.reason
  local previousTransition = current.transition
  current.state = "aborted"
  current.reason = primitiveReason(reason, "watchdog-aborted")
  local aborted, abortReason = self:_dispatch(
    "watchdog-aborted", current, nil, function()
      current.state = previousState
      current.reason = previousReason
      current.transition = previousTransition
    end)
  if not aborted then return nil, abortReason end
  self.aborts = self.aborts + 1
  self.lastEnded = publicReceipt(internalReceipt(current))
  if same(self.active, current) then self.active = nil end
  return aborted
end

Adapter.abort = Adapter.watchdogAbort

-- Registry cleanup first removes the exclusive critical subscriber, then
-- calls this non-publishing seam after provider/legacy cleanup.  It cannot be
-- used while a mutation owner is still installed.
function Adapter:cleanupAbort(expected, reason)
  local reentryError = self:_reentryError()
  if reentryError ~= nil then return nil, reentryError, true end
  local current = self.active
  if current == nil then return true end
  if self.critical ~= nil then
    return nil, "critical Gen2 lifecycle owner remains during cleanup abort"
  end
  if not exactOwner(current, expected) then
    return nil, "cleanup abort owner mismatch"
  end
  self.transitionSerial = self.transitionSerial + 1
  current.transition = self.transitionSerial
  current.state = "aborted"
  current.reason = primitiveReason(reason, "cleanup-aborted")
  self.aborts = self.aborts + 1
  self.lastEnded = publicReceipt(internalReceipt(current))
  self.active = nil
  return internalReceipt(current)
end

function Adapter:current(expected)
  local current = self.active
  if expected ~= nil and not exactOwner(current, expected)
      and not exactLogic(current, expected)
      and not exactScreen(current, expected) then
    return nil
  end
  return internalReceipt(current)
end

function Adapter:last()
  if self.lastEnded == nil then return nil end
  local result = {}
  for key, value in pairs(self.lastEnded) do result[key] = value end
  return result
end

function Adapter:isExactScreen(screen)
  return exactScreen(self.active, screen)
end

function Adapter:isExactLogic(logic)
  return exactLogic(self.active, logic)
end

function Adapter:retire()
  if self.active ~= nil then
    return false, "active Gen2 lifecycle owner must be aborted before retire"
  end
  if self.critical ~= nil then
    return false, "critical Gen2 lifecycle owner must unsubscribe before retire"
  end
  self.retired = true
  self.observers = {}
  return true
end

function Adapter:health()
  local observerCount = 0
  for _ in pairs(self.observers) do observerCount = observerCount + 1 end
  return {
    schema="ascendant.compat-status/v1",
    apiVersion=Lifecycle.API_VERSION,
    ok=not self.retired
      and self.criticalFailures == 0
      and self.compensationFailures == 0,
    state=self.retired and "retired"
      or (self.active and self.active.state or "idle"),
    active=publicReceipt(internalReceipt(self.active)),
    criticalOwner=self.critical and self.critical.owner or nil,
    observerCount=observerCount,
    transitions=self.transitions,
    starts=self.starts,
    screenBinds=self.screenBinds,
    replacements=self.replacements,
    switches=self.switches,
    movesObserved=self.movesObserved,
    logicEnds=self.logicEnds,
    finishes=self.finishes,
    aborts=self.aborts,
    ignored=self.ignored,
    listenerFailures=self.listenerFailures,
    criticalFailures=self.criticalFailures,
    compensationFailures=self.compensationFailures,
    reentryFailures=self.reentryFailures,
    lastError=self.lastError,
  }
end

function Adapter:publicEvent(event)
  if type(event) ~= "table"
      or event.schema ~= Lifecycle.EVENT_SCHEMA
      or event.apiVersion ~= Lifecycle.API_VERSION
      or event.generation ~= 2
      or type(event.kind) ~= "string" then
    return nil
  end
  local receipt = publicReceipt(event.receipt)
  if receipt == nil then return nil end
  return {
    schema="ascendant.battle-lifecycle-public-event/v1",
    apiVersion=Lifecycle.API_VERSION,
    generation=2,
    kind=event.kind,
    receipt=receipt,
  }
end

function Adapter:public()
  local owner = self
  return {
    apiVersion=Lifecycle.API_VERSION,
    contextSchema=Lifecycle.CONTEXT_SCHEMA,
    event="mod.VOXEL_ASCENDANT.gen2_battle_lifecycle_v1",
    generation=2,
    states=copyPrimitives(STATES),
    providers=copyPrimitives(PROVIDERS),
    current=function()
      return publicReceipt(internalReceipt(owner.active))
    end,
    last=function() return owner:last() end,
    health=function() return owner:health() end,
  }
end

Adapter.normalizeProvider = normalizeProvider
Lifecycle.normalizeProvider = normalizeProvider
Lifecycle.sideIdentity = sideIdentity
Lifecycle.publicReceipt = publicReceipt

return Lifecycle
