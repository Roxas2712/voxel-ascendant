-- Transitional Gen-2 renderer adapter.
--
-- This is the only first-tranche seam allowed to call the existing
-- OverworldBattle implementation for MAP/ARENA/DISCS. It owns no engine
-- events and never sees the public lifecycle receipt: Gen2BattleLifecycleCard
-- passes its opaque exact owner plus the internal lifecycle event.

local Renderer = {}
Renderer.__index = Renderer

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

local function receiptOf(owner, event)
  local receipt = type(event) == "table" and event.receipt or nil
  if type(receipt) ~= "table"
      or receipt.schema ~= "ascendant.battle-context/v1"
      or receipt.apiVersion ~= 1
      or receipt.generation ~= 2
      or not same(receipt.owner, owner)
      or not TRANSITIONAL[receipt.provider]
      or type(receipt.battleToken) ~= "number"
      or receipt.battleToken < 1
      or receipt.battleToken % 1 ~= 0
      or type(receipt.deploymentToken) ~= "number"
      or receipt.deploymentToken < 0
      or receipt.deploymentToken % 1 ~= 0
      or receipt.logic == nil
      or (receipt.screen ~= nil
        and not same(rawget(receipt.screen, "battle"), receipt.logic)) then
    return nil, "invalid transitional Gen2 renderer receipt"
  end
  return receipt
end

local function stateReceipt(state, override)
  return {
    schema="ascendant.gen2-legacy-renderer-state/v1",
    apiVersion=1,
    generation=2,
    provider=state.active and state.active.provider or nil,
    battleToken=state.active and state.active.battleToken or nil,
    deploymentToken=state.active and state.active.deploymentToken or nil,
    state=override or (state.active and state.active.state) or "idle",
    staged=state.active and state.active.staged == true or false,
    screenBound=state.active and state.active.screen ~= nil or false,
    starts=state.starts,
    binds=state.binds,
    switches=state.switches,
    finishes=state.finishes,
    aborts=state.aborts,
    fallbacks=state.fallbacks,
    contentFinishes=state.contentFinishes,
    backgroundBinds=state.backgroundBinds,
    backgroundFailures=state.backgroundFailures,
  }
end

local function exact(state, owner)
  return state.active ~= nil and owner ~= nil
    and same(state.active.owner, owner)
end

local function finishRenderer(state, active)
  if active.rendererFinished then return true end
  -- Gold begins concrete screen B before screen.pushed(B) tells the lifecycle
  -- that B replaced screen A while reusing A's logic table. At this point the
  -- legacy OverworldBattle session already belongs to B. Finishing by A's
  -- screen would still match B through screen.battle == B.logic and would
  -- therefore tear down the incoming renderer. Only A-owned local content is
  -- left for this adapter to clean on that exact presentation-only edge.
  if active.reason == "same-logic-screen-replaced" then
    active.rendererFinished = true
    return true
  end
  local expected = active.screen or active.logic
  local finish = state.OverworldBattle.finish
  if active.reason == "battle-logic-replaced" then
    finish = state.OverworldBattle.finishForReplacement
  end
  local ok, value = pcall(finish, expected)
  if not ok then
    return nil, "OverworldBattle.finish threw: "
      .. safeText(value, "unprintable finish error")
  end
  if value == false then
    return nil, "OverworldBattle.finish rejected exact Gen2 owner"
  end
  -- nil is the legacy module's idempotent "no session" result. The adapter's
  -- own opaque owner still makes this a successful exact cleanup.
  active.rendererFinished = true
  return true
end

local function finishContent(state, active)
  if active.contentFinished then return true end
  local callback = state.finishContent
  if callback ~= nil then
    local ok, value, detail = pcall(callback, active.owner,
      active.reason or "screen-popped", {
        schema="ascendant.gen2-content-finish/v1",
        apiVersion=1,
        generation=2,
        provider=active.provider,
        battleToken=active.battleToken,
        deploymentToken=active.deploymentToken,
      })
    if not ok or value == false then
      return nil, "Gen2 battle content finish failed: "
        .. safeText(ok and detail or value, "content cleanup declined")
    end
  end
  active.contentFinished = true
  state.contentFinishes = state.contentFinishes + 1
  return true
end

local function terminate(state, owner, event, aborted)
  if state.active == nil then return true end
  if not exact(state, owner) then return nil, "legacy renderer owner mismatch" end
  local active = state.active
  if type(event) == "table" and event.kind ~= "cleanup" then
    local receipt, reason = receiptOf(owner, event)
    if not receipt then return nil, reason end
    if receipt.provider ~= active.provider
        or receipt.battleToken ~= active.battleToken
        or receipt.deploymentToken ~= active.deploymentToken
        or not same(receipt.logic, active.logic)
        or ((active.screen ~= nil or receipt.screen ~= nil)
          and not same(receipt.screen, active.screen)) then
      return nil, "legacy renderer terminal token mismatch"
    end
    active.reason = safeText(receipt.reason,
      event.kind == "screen-popped" and "screen-popped"
        or "legacy-renderer-finished")
  end
  active.state = "rollback_pending"
  local rendererOK, rendererReason = finishRenderer(state, active)
  if not rendererOK then
    state.failures = state.failures + 1
    state.lastError = rendererReason
    return nil, rendererReason
  end
  local contentOK, contentReason = finishContent(state, active)
  if not contentOK then
    state.failures = state.failures + 1
    state.lastError = contentReason
    return nil, contentReason
  end
  if aborted then
    state.aborts = state.aborts + 1
  else
    state.finishes = state.finishes + 1
  end
  state.active = nil
  return stateReceipt(state, aborted and "aborted" or "ended")
end

local Module = {}

function Module.new(options)
  options = type(options) == "table" and options or {}
  local OverworldBattle = assert(options.OverworldBattle,
    "Gen2BattleRenderer needs OverworldBattle")
  for _, method in ipairs({
    "ensure", "finish", "finishForReplacement", "invalidate",
  }) do
    assert(type(OverworldBattle[method]) == "function",
      "Gen2BattleRenderer needs OverworldBattle." .. method)
  end
  assert(type(options.finishContent) == "function",
    "Gen2BattleRenderer needs finishContent")
  local state = setmetatable({
    OverworldBattle=OverworldBattle,
    finishContent=options.finishContent,
    bindArenaBackdrop=type(options.bindArenaBackdrop) == "function"
      and options.bindArenaBackdrop or nil,
    active=nil,
    retired=false,
    starts=0,
    binds=0,
    switches=0,
    finishes=0,
    aborts=0,
    fallbacks=0,
    contentFinishes=0,
    backgroundBinds=0,
    backgroundFailures=0,
    failures=0,
    lastError=nil,
  }, Renderer)

  local function maybeBindArenaBackdrop(active)
    if active.provider ~= "ARENA" or active.backgroundBound == true then
      return true
    end
    if state.bindArenaBackdrop == nil then
      active.backgroundBound = true
      return true
    end
    local receipt = {
      schema="ascendant.battle-context/v1", apiVersion=1, generation=2,
      owner=active.owner, provider=active.provider,
      requestedMode=active.requestedMode, battleToken=active.battleToken,
      deploymentToken=active.deploymentToken, logic=active.logic,
      screen=active.screen,
    }
    local ok, value = pcall(state.bindArenaBackdrop, active.owner, receipt)
    if not ok then
      -- Optional content never owns renderer/lifecycle failure. One callback
      -- error latches the unchanged ARENA fallback for this exact battle.
      active.backgroundBound = true
      state.backgroundFailures = state.backgroundFailures + 1
      return true
    end
    if value == false then return false end -- host session not ready: bind edge retries
    active.backgroundBound = true
    state.backgroundBinds = state.backgroundBinds + 1
    return true
  end

  local service = {}

  function service.start(owner, event)
    if state.retired then return nil, "legacy Gen2 renderer is retired" end
    local receipt, reason = receiptOf(owner, event)
    if not receipt then return nil, reason end
    if state.active ~= nil then
      if exact(state, owner) then
        local active = state.active
        if receipt.provider ~= active.provider
            or receipt.battleToken ~= active.battleToken
            or receipt.deploymentToken ~= active.deploymentToken
            or not same(receipt.logic, active.logic)
            or ((active.screen ~= nil or receipt.screen ~= nil)
              and not same(receipt.screen, active.screen)) then
          return nil, "legacy renderer duplicate start context mismatch"
        end
        return stateReceipt(state)
      end
      return nil, "another legacy Gen2 renderer owner is active"
    end
    local active = {
      owner=owner,
      logic=receipt.logic,
      screen=receipt.screen,
      provider=receipt.provider,
      requestedMode=receipt.requestedMode,
      battleToken=receipt.battleToken,
      deploymentToken=receipt.deploymentToken,
      -- Gold constructs/emits Battle.new before World:pushBattleTransition.
      -- That existing world wrapper owns the encounter snapshot and the one
      -- legitimate OverworldBattle.begin call.  The Card therefore records
      -- ownership here and waits for the concrete BattleState before asking
      -- ensure() to adopt (or recover) that host-created session.
      state="awaiting_host",
      staged=false,
      rendererFinished=false,
      contentFinished=false,
    }
    state.active = active
    -- A same-logic concrete-screen replacement is discovered from
    -- screen.pushed after the original owner has been aborted. The lifecycle
    -- emits one fresh `started` event already carrying that exact screen, so
    -- there is no later `screen-bound` edge to wake an awaiting adapter. This
    -- path is safely after pushBattleTransition and may adopt/recover now.
    if active.screen ~= nil then
      local ok, value = pcall(OverworldBattle.ensure, active.screen)
      if not ok then
        local failure = "OverworldBattle.ensure replacement screen threw: "
          .. safeText(value, "unprintable replacement error")
        state.failures = state.failures + 1
        state.lastError = failure
        active.state = "rollback_pending"
        return nil, failure
      end
      active.staged = value == true
      if not active.staged then state.fallbacks = state.fallbacks + 1 end
      active.state = "active"
      state.binds = state.binds + 1
    end
    maybeBindArenaBackdrop(active)
    state.starts = state.starts + 1
    return stateReceipt(state)
  end

  function service.bind(owner, event)
    if not exact(state, owner) then return nil, "legacy renderer owner mismatch" end
    local receipt, reason = receiptOf(owner, event)
    if not receipt then return nil, reason end
    local active = state.active
    if receipt.provider ~= active.provider
        or receipt.battleToken ~= active.battleToken
        or receipt.deploymentToken ~= active.deploymentToken
        or not same(receipt.logic, active.logic)
        or receipt.screen == nil
        or not same(rawget(receipt.screen, "battle"), active.logic) then
      return nil, "legacy renderer screen bind token/owner mismatch"
    end
    if active.screen ~= nil and not same(active.screen, receipt.screen) then
      return nil, "legacy renderer cannot replace screen without abort"
    end
    -- This runs after the engine's pushBattleTransition wrapper. In ordinary
    -- world battles ensure() adopts the already begun session; in direct/link
    -- test hosts it remains the reviewed recovery path that may begin once.
    local ok, value = pcall(OverworldBattle.ensure, receipt.screen)
    if not ok then
      local failure = "OverworldBattle.ensure screen bind threw: "
        .. safeText(value, "unprintable bind error")
      state.failures = state.failures + 1
      state.lastError = failure
      active.state = "rollback_pending"
      return nil, failure
    end
    active.screen = receipt.screen
    active.staged = value == true
    if not active.staged then state.fallbacks = state.fallbacks + 1 end
    active.state = "active"
    state.binds = state.binds + 1
    maybeBindArenaBackdrop(active)
    return stateReceipt(state)
  end

  function service.switch(owner, event)
    if not exact(state, owner) then return nil, "legacy renderer owner mismatch" end
    local receipt, reason = receiptOf(owner, event)
    if not receipt then return nil, reason end
    local active = state.active
    if receipt.provider ~= active.provider
        or receipt.battleToken ~= active.battleToken
        or receipt.deploymentToken ~= active.deploymentToken + 1
        or not same(receipt.logic, active.logic)
        or (active.screen ~= nil and not same(receipt.screen, active.screen)) then
      return nil, "legacy renderer switch token/owner mismatch"
    end
    -- Invalidate only presentation caches. Gold's animForMove and battle logic
    -- remain untouched and the ordinary per-frame deployment detector stays a
    -- defensive second line.
    local ok, value = pcall(OverworldBattle.invalidate)
    if not ok then
      local failure = "OverworldBattle.invalidate threw: "
        .. safeText(value, "unprintable switch error")
      state.failures = state.failures + 1
      state.lastError = failure
      active.state = "rollback_pending"
      return nil, failure
    end
    active.deploymentToken = receipt.deploymentToken
    active.state = "active"
    state.switches = state.switches + 1
    return stateReceipt(state)
  end

  function service.finish(owner, event)
    return terminate(state, owner, event, false)
  end

  function service.abort(owner, event, reason)
    -- reason is diagnostic only; executable cleanup remains exact to owner.
    if state.active ~= nil and not exact(state, owner) then
      return nil, "legacy renderer owner mismatch"
    end
    if state.active ~= nil and reason ~= nil then
      state.active.reason = safeText(reason, "legacy-renderer-aborted")
    end
    return terminate(state, owner, event, true)
  end

  function service.owns(owner)
    return exact(state, owner)
  end

  function service.health()
    local current = stateReceipt(state)
    return {
      schema="ascendant.compat-status/v1",
      apiVersion=1,
      ok=not state.retired and state.failures == 0
        and (state.active == nil or state.active.state ~= "rollback_pending"),
      generation=2,
      state=state.retired and "retired" or current.state,
      active=state.active ~= nil,
      provider=current.provider,
      battleToken=current.battleToken,
      deploymentToken=current.deploymentToken,
      staged=current.staged,
      screenBound=current.screenBound,
      starts=state.starts,
      binds=state.binds,
      switches=state.switches,
      finishes=state.finishes,
      aborts=state.aborts,
      fallbacks=state.fallbacks,
      contentFinishes=state.contentFinishes,
      backgroundBinds=state.backgroundBinds,
      backgroundFailures=state.backgroundFailures,
      failures=state.failures,
      lastError=state.lastError,
      movePresentationOwner="animForMove",
    }
  end

  function service.retire(reason)
    if state.active ~= nil then
      local ended, endReason = service.abort(state.active.owner, {
        kind="cleanup",
        receipt={ owner=state.active.owner },
      }, reason or "legacy-renderer-retired")
      if ended == nil then return nil, endReason end
    end
    state.retired = true
    return true
  end

  return service
end

return Module
