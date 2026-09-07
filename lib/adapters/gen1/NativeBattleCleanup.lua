-- Exact-owner native cleanup fallback and content-cleanup coordinator for the
-- Gen-1 lifecycle adapter.
--
-- Direct class wrappers cannot be rolled back by the current engine loader.
-- When the mandatory lifecycle Card is unavailable they remain inert, while
-- this small engine-owned adapter keeps battle-scoped music/content cleanup
-- alive.  It never guesses from global state: one battle.started latches one
-- exact native owner and only that same battle.ended may retire it. Content
-- cleanup is coordinated per BattleState so renderer, Card and native paths
-- can converge on one idempotent completion without sharing mutable owners.

local Cleanup = {
  API_VERSION = 1,
  SCHEMA = "ascendant.gen1-native-battle-cleanup/v1",
}

local function battleFrom(payload)
  return type(payload) == "table" and payload.battle or nil
end

local function sameBattle(left, right)
  return rawequal(left, right)
end

local function safeText(value, fallback)
  if type(value) == "string" then return value end
  if value == nil then return fallback or "nil" end
  local ok, result = pcall(tostring, value)
  if ok and type(result) == "string" then return result end
  return fallback or ("<unprintable-%s>"):format(type(value))
end

function Cleanup.install(mod, options)
  options = options or {}
  local renderer = options.renderer
  local lifecycle = options.lifecycle
  local finishContent = options.finishContent
  if type(mod) ~= "table" or type(mod.events) ~= "table"
      or type(mod.events.on) ~= "function" then
    return nil, "native battle cleanup needs mod.events:on"
  end
  if type(renderer) ~= "table"
      or type(renderer.battleLifecycleHealth) ~= "function"
      or type(renderer.ownsBattle) ~= "function" then
    return nil, "native battle cleanup needs exact renderer ownership"
  end
  if type(lifecycle) ~= "table"
      or type(lifecycle.current) ~= "function" then
    return nil, "native battle cleanup needs exact lifecycle ownership"
  end
  if type(finishContent) ~= "function" then
    return nil, "native battle cleanup needs finishContent"
  end

  local cleanupCount = 0
  local failureCount = 0
  local lastError = nil
  local cleanupStates = setmetatable({}, { __mode="k" })
  local obligations = {}
  local nextSequence = 0
  local draining = false
  local unsubscribers = {}
  local active = true

  local function ready()
    local ok, health = pcall(renderer.battleLifecycleHealth)
    return ok and type(health) == "table" and health.ready == true
  end

  local function reasonLabel(reason, fallback)
    if type(reason) == "string" and reason ~= "" then return reason end
    return fallback
  end

  local function cleanupState(battle)
    local state = cleanupStates[battle]
    if state == nil then
      nextSequence = nextSequence + 1
      state = {
        status="pending",
        attempts=0,
        lastReason=nil,
        lastError=nil,
        terminal=false,
        terminalReason=nil,
        cleanupAllowed=false,
        source=nil,
        sequence=nextSequence,
        queued=false,
      }
      cleanupStates[battle] = state
    end
    return state
  end

  local function queueEntry(state)
    if state == nil or state.queued ~= true then return nil end
    for _, entry in ipairs(obligations) do
      if rawequal(entry.state, state) then return entry end
    end
    -- A stale flag must never make an obligation undiscoverable.
    state.queued = false
    return nil
  end

  local function entryForBattle(battle)
    local state = cleanupStates[battle]
    return queueEntry(state)
  end

  local function enqueue(battle, state)
    local existing = queueEntry(state)
    if existing ~= nil then return existing end
    local entry = { battle=battle, state=state }
    local inserted = false
    for index, candidate in ipairs(obligations) do
      if state.sequence < candidate.state.sequence then
        table.insert(obligations, index, entry)
        inserted = true
        break
      end
    end
    if not inserted then obligations[#obligations + 1] = entry end
    state.queued = true
    return entry
  end

  local function removeEntry(entry)
    if entry == nil then return false end
    for index, candidate in ipairs(obligations) do
      if rawequal(candidate, entry) then
        table.remove(obligations, index)
        entry.state.queued = false
        return true
      end
    end
    entry.state.queued = false
    return false
  end

  local function liveTail()
    for index = #obligations, 1, -1 do
      local entry = obligations[index]
      if entry.state.status ~= "finished"
          and entry.state.terminal ~= true then
        return entry
      end
    end
    return nil
  end

  local function pendingHead()
    return obligations[1]
  end

  local function receipt(state, reason, idempotent, source)
    return {
      schema="ascendant.gen1-native-content-cleanup-receipt/v1",
      apiVersion=Cleanup.API_VERSION,
      status=state.status,
      attempts=state.attempts,
      reason=reasonLabel(reason, "native-content-finished"),
      source=type(source) == "string" and source or nil,
      idempotent=idempotent == true,
      terminal=state.terminal == true,
    }
  end

  -- Raw content is global, so per-BattleState tombstones alone are not
  -- enough: every call must also follow first-observation order. A failed
  -- head remains in place and prevents every younger obligation from calling
  -- the raw seam until that exact head succeeds.
  local function drain()
    if draining then
      return false, "native content cleanup queue is already in progress"
    end
    draining = true
    while true do
      local entry = pendingHead()
      if entry == nil then
        draining = false
        return true
      end
      local state = entry.state
      if state.status == "finished" then
        removeEntry(entry)
      elseif state.status == "finishing" then
        draining = false
        return false, "native content cleanup is already in progress"
      elseif state.terminal ~= true or state.cleanupAllowed ~= true then
        -- The youngest live battle (or a healthy explicit Card end awaiting
        -- renderer proof) is the durable queue tail, never a cleanup target.
        draining = false
        return true
      else
        local why = reasonLabel(
          state.terminalReason, "native-content-finished")
        state.status = "finishing"
        state.attempts = state.attempts + 1
        state.lastReason = why
        local called, result, detail = pcall(finishContent, why)
        if called and result ~= false then
          state.status = "finished"
          state.lastError = nil
          cleanupCount = cleanupCount + 1
          removeEntry(entry)
        else
          -- Throw and explicit false both restore the same head. Younger
          -- starts/ends may already be queued, but cannot be lost or skipped.
          state.status = "pending"
          state.lastError = called
            and safeText(detail, "finishContent returned false")
            or safeText(result, "finishContent threw an unprintable error")
          failureCount = failureCount + 1
          lastError = state.lastError
          draining = false
          if mod.log and type(mod.log.warn) == "function" then
            pcall(mod.log.warn, mod.log,
              "native battle cleanup remains retryable: %s", lastError)
          end
          return false, state.lastError
        end
      end
    end
  end

  -- OverworldBattle may prove renderer teardown before a native/Card handoff.
  -- Queue that exact terminal obligation, then drain only in global order.
  local function finishExact(battle, reason)
    if battle == nil then
      return false, "native content cleanup omitted battle"
    end
    local state = cleanupState(battle)
    local why = reasonLabel(reason, "native-content-finished")
    if state.status == "finished" then
      return true, receipt(state, why, true, state.source)
    end
    if state.status == "finishing" then
      return false, "native content cleanup is already in progress"
    end
    enqueue(battle, state)
    state.terminal = true
    state.cleanupAllowed = true
    state.terminalReason = why
    local drained, drainReason = drain()
    if not drained then return false, drainReason end
    if state.status ~= "finished" then
      return false, "native content cleanup is blocked by an older obligation"
    end
    return true, receipt(state, why, false, state.source)
  end

  local retire

  local function adoptionDetails(reason, source)
    if type(reason) == "table" then
      source = reason.source
      reason = reason.reason
    end
    return reasonLabel(reason, "native-battle-adopted"),
      reasonLabel(source, "explicit-card-handoff")
  end

  -- Public callers are explicit Card hand-offs by default. Internal native
  -- observation sites always pass their source as the third argument. The
  -- table form `adopt(battle, { reason=..., source=... })` is also accepted so
  -- the ownership intent remains reviewable at call sites.
  local function adopt(battle, reason, source, deferPreviousCleanup)
    if not active then return false, "native cleanup adapter is inactive" end
    if battle == nil then return false, "native cleanup adopt omitted battle" end
    local why, adoptedFrom = adoptionDetails(reason, source)
    local knownState = cleanupStates[battle]
    local state = knownState or cleanupState(battle)
    if state.status == "finished" then
      return true, receipt(state, why, true, adoptedFrom)
    end

    local existing = queueEntry(state)
    if existing == nil then
      if knownState == nil then
        -- Capture the new BattleState before attempting its predecessor. This
        -- is the critical guarantee which keeps A/C reachable behind a
        -- retry-pending B.
        local previousLive = liveTail()
        for _, previous in ipairs(obligations) do
          local prior = previous.state
          if prior.status ~= "finished" then
            if rawequal(previous, previousLive) then
              prior.terminal = true
              prior.terminalReason = "native-battle-replaced"
              prior.cleanupAllowed = deferPreviousCleanup ~= true
            elseif prior.terminal == true then
              -- A newer start also releases an ended predecessor which was
              -- waiting for an explicit Card proof that can no longer arrive.
              prior.cleanupAllowed = true
            end
          end
        end
        enqueue(battle, state)
      else
        -- A late handoff of an older, already observed BattleState is inserted
        -- at its original sequence. It may never replace a younger live C.
        local tail = liveTail()
        if state.terminal == true then
          -- No explicit owner remains to provide a second end event. The late
          -- handoff itself makes the preserved terminal tombstone drainable.
          state.cleanupAllowed = true
        elseif tail ~= nil and state.sequence < tail.state.sequence then
          state.terminal = true
          state.cleanupAllowed = true
          state.terminalReason = state.terminalReason
            or "native-battle-replaced"
        end
        enqueue(battle, state)
      end
    end

    if adoptedFrom == "explicit-card-handoff"
        or state.source ~= "explicit-card-handoff" then
      state.source = adoptedFrom
    end

    local drained, drainReason = drain()
    if not drained then return false, drainReason end
    -- Only the early finished-tombstone branch above is idempotent. If this
    -- call itself drained a previously terminal battle, it performed the
    -- first completion even though the resulting status is now `finished`.
    return true, receipt(state, why, false, state.source or adoptedFrom)
  end

  retire = function(battle, reason)
    if battle == nil then return false, "native cleanup retire omitted battle" end
    local state = cleanupStates[battle]
    if state ~= nil and state.status == "finished" then
      return true, receipt(state, reason, true, state.source)
    end
    if state == nil or queueEntry(state) == nil then
      return false, "native cleanup retire rejected non-owner battle"
    end
    local why = reasonLabel(reason, "native-content-finished")
    state.terminal = true
    state.cleanupAllowed = true
    state.terminalReason = why
    local drained, drainReason = drain()
    if not drained then return false, drainReason end
    if state.status ~= "finished" then
      return false, "native cleanup retire is blocked by an older obligation"
    end
    return true, receipt(state, why, false, state.source)
  end

  local function subscribe(name, callback, priority)
    local ok, unsubscribe = pcall(
      mod.events.on, mod.events, name, callback, priority or 1000)
    if not ok or type(unsubscribe) ~= "function" then
      -- Installation is atomic even when an event host refuses to remove an
      -- earlier listener. Poison every already-published callback before the
      -- best-effort unsubscribe pass, so a leaked `battle.started` observer
      -- can never become a second cleanup owner without its matching end
      -- observer.
      active = false
      obligations = {}
      for index = #unsubscribers, 1, -1 do
        pcall(unsubscribers[index])
      end
      unsubscribers = {}
      return false, ok and (name .. " returned no unsubscribe")
        or safeText(unsubscribe, name .. " subscription threw")
    end
    unsubscribers[#unsubscribers + 1] = unsubscribe
    return true
  end

  -- OverworldController selects battle music before battle.started.  The host
  -- calls this seam before delegating to its original pushBattle so a native
  -- replacement cannot reuse the previous battle's music/content choice.
  -- Direct/scripted BattleState pushes still enter through battle.started.
  local function beforeBattle(battle)
    if not active then return false, "native cleanup adapter is inactive" end
    if battle == nil then return false, "native cleanup preflight omitted battle" end
    if ready() then
      -- A healthy preflight is only provisional until the Card's start hook
      -- upgrades it to an explicit handoff. If another preflight arrives
      -- first, discard that unconfirmed tail without pretending it ended.
      local provisional = liveTail()
      if provisional ~= nil
          and provisional.state.source == "native-preflight"
          and not sameBattle(provisional.battle, battle) then
        removeEntry(provisional)
        provisional.state.source = nil
      end
      -- A healthy Card also owns native DEFAULT fights, but those deliberately
      -- have no renderer session. If such a fight is replaced before its end
      -- event, retire its content now. A staged predecessor is left alone:
      -- OverworldBattle.begin synchronously finishes that exact session.
      local currentOK, current = pcall(lifecycle.current)
      local staged = false
      if currentOK and type(current) == "table"
          and current.battle ~= nil
          and not sameBattle(current.battle, battle) then
        local stagedOK, stagedValue = pcall(
          renderer.ownsBattle, current.battle)
        staged = stagedOK and stagedValue == true
        if not staged and entryForBattle(current.battle) == nil then
          local adopted, adoptReason = adopt(
            current.battle, "native-card-default-observed",
            "native-card-default-observer")
          if not adopted then return false, adoptReason end
        end
      end
      -- Capture the successor before touching the predecessor. A staged
      -- renderer predecessor remains blocked until its own finishExact proof;
      -- native DEFAULT content can be drained immediately in queue order.
      local adopted, adoptReason = adopt(
        battle, "native-battle-preflight", "native-preflight", staged)
      if not adopted then return false, adoptReason end
      return false
    end
    return adopt(
      battle, "native-battle-preflight", "native-preflight")
  end

  -- Observe starts after the mandatory Card.  A healthy Card leaves the gate
  -- open and therefore owns the battle as before.  If its start callback
  -- self-aborts during this same engine dispatch, the closed gate is visible
  -- here and the exact live BattleState is adopted by the native fallback.
  -- This avoids a listener-free gap without coupling the Card back to this
  -- adapter or guessing an owner from global state.
  local started, startError = subscribe("battle.started", function(payload)
    if not active then return end
    local battle = battleFrom(payload)
    if battle == nil then return end
    if ready() then
      local entry = entryForBattle(battle)
      if entry ~= nil then
        -- The Card owns this exact start; keep the cleanup record but release
        -- only an implicitly observed fallback owner. An explicit Card
        -- hand-off must not be erased merely because the gate became healthy.
        if entry.state.source ~= "explicit-card-handoff" then
          removeEntry(entry)
          entry.state.source = nil
        end
      end
      return
    end
    adopt(battle, "native-battle-started", "native-start-observer")
  end, -1000)
  if not started then return nil, startError end

  local ended, endError = subscribe("battle.ended", function(payload)
    if not active then return end
    local battle = battleFrom(payload)
    if battle == nil then return end
    local state = cleanupState(battle)
    state.terminal = true
    state.terminalReason = "native-battle-ended"
    local entry = queueEntry(state)
    if entry == nil then return end
    -- The mandatory Card runs after this native observer and still has to
    -- prove the renderer's exact terminal transaction. Do not let the outer
    -- fallback clean content ahead of that proof while its gate is healthy;
    -- the Card will call retire(A) in its terminal phase. Once the gate is
    -- closed, the same explicit hand-off belongs to this fallback and exact
    -- native end retirement proceeds normally.
    if state.source == "explicit-card-handoff" and ready() then
      state.cleanupAllowed = false
      return
    end
    state.cleanupAllowed = true
    -- A younger end cannot usefully hammer a retry-pending predecessor. It is
    -- nevertheless tombstoned above, so any later ordered retry will consume
    -- it without waiting for another event.
    if rawequal(pendingHead(), entry) then drain() end
  end)
  if not ended then return nil, endError end

  return {
    schema=Cleanup.SCHEMA,
    apiVersion=Cleanup.API_VERSION,
    beforeBattle=beforeBattle,
    finishExact=finishExact,
    adopt=adopt,
    retire=retire,
    deactivate=function()
      if not active then return false end
      local live = liveTail()
      local head = pendingHead()
      local retiredOwner = live and live.battle or (head and head.battle or nil)
      if head ~= nil then
        -- Retirement is an ownership boundary, not permission to forget a
        -- live fallback battle.  This is especially important after a Card
        -- self-abort: a later module re-entry must release the native music
        -- and Local Content latch before removing the adapter listeners.
        for _, entry in ipairs(obligations) do
          local state = entry.state
          state.terminal = true
          state.cleanupAllowed = true
          if state.terminalReason == nil or sameBattle(entry.battle, retiredOwner) then
            state.terminalReason = "native-cleanup-deactivated"
          end
        end
        local retired, retireReason = drain()
        if not retired or pendingHead() ~= nil then
          local pending = pendingHead()
          -- `nil` distinguishes an incomplete retirement from the historical
          -- idempotent `false` returned by an already inactive adapter. Keep
          -- the exact owner in the established second return slot so the
          -- process lease can retry that object without global discovery.
          return nil, pending and pending.battle or retiredOwner,
            retireReason or "native cleanup queue remained pending"
        end
      end
      active = false
      obligations = {}
      for index = #unsubscribers, 1, -1 do
        pcall(unsubscribers[index])
      end
      unsubscribers = {}
      -- The process-level renderer lease cannot infer a native DEFAULT owner
      -- once the lifecycle Card has aborted. Hand that exact object back to
      -- the host so retirement can clear only its compatibility markers.
      return true, retiredOwner
    end,
    health=function()
      local head = pendingHead()
      local state = head and head.state or nil
      local live = liveTail()
      return {
        schema="ascendant.compat-status/v1",
        apiVersion=Cleanup.API_VERSION,
        ok=active and failureCount == 0,
        state=active and "active" or "inactive",
        nativeOwnerActive=head ~= nil,
        ownerSource=state and state.source or nil,
        pendingCount=#obligations,
        liveOwnerActive=live ~= nil,
        cleanupState=state and state.status or "none",
        cleanupPending=head ~= nil,
        terminalObserved=state ~= nil and state.terminal == true or false,
        cleanups=cleanupCount,
        failures=failureCount,
        lastError=lastError,
      }
    end,
  }
end

return Cleanup
