local root = (... and (...):match("^(.*)/tests/")) or "."

local function eq(actual, expected, message)
  assert(actual == expected, (message or "values differ") .. ": expected "
    .. tostring(expected) .. ", got " .. tostring(actual))
end

local function check(value, message)
  assert(value, message or "check failed")
end

local cache = {}
local V = {}
function V.require(name)
  if cache[name] ~= nil then return cache[name] end
  local chunk, loadReason = loadfile(root .. "/lib/" .. name .. ".lua")
  assert(chunk, loadReason)
  local value = chunk(V)
  cache[name] = value
  return value
end

local Registry = V.require("core/AscendantCardRegistry")
local DefaultCard = assert(loadfile(root
  .. "/gen2/lib/cards/battle_router/Gen2DefaultBattleProviderCard.lua"))(V)
local RouterCard = assert(loadfile(root
  .. "/gen2/lib/cards/battle_router/Gen2BattleRouterCard.lua"))(V)

local contentCalls = {}
local registry = Registry.new()
check(registry:register(DefaultCard.descriptor({
  finishContent=function(owner, reason, receipt)
    contentCalls[#contentCalls + 1] = {
      owner=owner, reason=reason, receipt=receipt,
    }
    return true
  end,
})))
check(registry:register(RouterCard.descriptor()))
local active, activeReason = registry:activate(RouterCard.ID, {
  generation=2, host="headless",
})
check(active, activeReason)
eq(registry:state(DefaultCard.ID), "active", "Gen2 DEFAULT Card state")
eq(registry:state(RouterCard.ID), "active", "Gen2 Router Card state")

local capability = assert(registry:capability(RouterCard.CAPABILITY))
local router = capability.value
eq(router.schema, "ascendant.battle-router/v1", "Router schema")
eq(router.apiVersion, 1, "Router API")
eq(router.generation, 2, "Router generation")
check(router.register == nil and router.acquire == nil,
  "public Gen2 Router exposed owner-only mutation seams")

local alwaysEqual = { __eq=function() return true end }
local battle = setmetatable({}, alwaysEqual)
local equalButForeign = setmetatable({}, alwaysEqual)
local started = assert(router.start(battle, {
  provider="DEFAULT",
  requestedMode="DEFAULT",
  battleToken=21,
  deploymentToken=0,
}))
eq(started.provider, "DEFAULT", "DEFAULT provider")
eq(started.generation, 2, "DEFAULT generation")
eq(started.battleToken, 21, "authoritative battle token")
check(started.battle == nil, "Router receipt leaked exact battle owner")
check(router.owns(battle), "Gen2 Router lost exact owner")
check(not router.owns(equalButForeign), "Lua __eq forged Gen2 Router owner")

local staleSwitch, staleReason = router.switch(equalButForeign, {
  battleToken=21, deploymentToken=1,
})
eq(staleSwitch, nil, "foreign equal object switched DEFAULT")
eq(staleReason, "battle owner mismatch", "foreign switch diagnostic")
local switched = assert(router.switch(battle, {
  battleToken=21, deploymentToken=1, side="player",
}))
eq(switched.deploymentToken, 1, "switch deployment token")

-- The callback exists because the shared Router contract requires it. It is
-- observation-only and advertises animForMove as the real presentation
-- owner; Gen2BattleLifecycleCard never calls this route for battle.move_used.
local attacked = assert(router.attack(battle, {
  battleToken=21, deploymentToken=1, move="SURF",
}))
eq(attacked.provider, "DEFAULT", "attack observation provider")
local health = router.health()
eq(health.providers.DEFAULT.observedAttacks, 1,
  "DEFAULT attack observation metric")
eq(health.providers.DEFAULT.movePresentationOwner, "animForMove",
  "DEFAULT provider claimed move animation")
eq(health.providers.DEFAULT.presentationOwner, "GoldBattleState",
  "DEFAULT provider created a legacy nativeOnly presentation")
check(health.providers.DEFAULT.owner == nil
    and health.providers.DEFAULT.battle == nil,
  "DEFAULT provider health leaked exact owner")

local tokenMismatch, tokenReason = router.finish(battle, {
  battleToken=21, deploymentToken=0,
})
eq(tokenMismatch, nil, "regressed finish token ended Gen2 owner")
eq(tokenReason, "deployment token mismatch", "finish token diagnostic")
check(router.owns(battle), "failed finish cleared exact owner")
local ended = assert(router.finish(battle, {
  battleToken=21, deploymentToken=1, result="screen-popped",
}))
eq(ended.state, "ended", "finished receipt")
check(not router.owns(battle), "finish retained exact Gen2 owner")
eq(#contentCalls, 1, "DEFAULT finish did not close content exactly once")
check(rawequal(contentCalls[1].owner, battle),
  "DEFAULT finishContent lost exact owner")
eq(contentCalls[1].reason, "screen-popped",
  "DEFAULT finishContent reason")
check(contentCalls[1].receipt.owner == nil
    and contentCalls[1].receipt.battle == nil,
  "DEFAULT finishContent receipt leaked exact owner")
eq(contentCalls[1].receipt.schema, "ascendant.gen2-content-finish/v1",
  "DEFAULT finishContent receipt schema")
eq(contentCalls[1].receipt.battleToken, 21,
  "DEFAULT finishContent battle token")
eq(contentCalls[1].receipt.deploymentToken, 1,
  "DEFAULT finishContent deployment token")

local abortedOwner = {}
assert(router.start(abortedOwner, {
  provider="DEFAULT", requestedMode="DEFAULT",
  battleToken=22, deploymentToken=0,
}))
local nilAbort, nilAbortReason = router.abort(nil, "ownerless")
eq(nilAbort, nil, "ownerless abort retired DEFAULT")
eq(nilAbortReason, "battle owner is required", "ownerless abort diagnostic")
check(router.owns(abortedOwner), "ownerless abort cleared DEFAULT")
local wrongAbort, wrongAbortReason = router.abort({}, "foreign")
eq(wrongAbort, nil, "foreign owner aborted DEFAULT")
eq(wrongAbortReason, "battle owner mismatch", "foreign abort diagnostic")
check(router.owns(abortedOwner), "foreign abort cleared DEFAULT")
check(router.abort(abortedOwner, "watchdog") == true,
  "exact watchdog abort failed")
check(not router.owns(abortedOwner), "watchdog abort retained owner")
eq(#contentCalls, 2, "DEFAULT watchdog did not close content once")
eq(contentCalls[2].reason, "watchdog", "watchdog content reason")

-- Provider callback failure is contained by the shared generation-neutral
-- Router and invokes exact abort compensation once.
local RawRouter = V.require("core/BattleProviderRouter")

-- The provider itself must reject an ownerless abort while active, and the
-- Card lifecycle must accept the provider's public receipt (a table) as a
-- successful cleanup result.  These paths are used by Registry teardown and
-- activation rollback, not only by the public Router boolean wrapper.
local directCleanupCalls = 0
local directDescriptor = DefaultCard.descriptor({
  finishContent=function()
    directCleanupCalls = directCleanupCalls + 1
    return true
  end,
})
local directOwner, directProvider = directDescriptor.lifecycle.activate()
local directBattle = {}
assert(directProvider.start(directBattle, {
  battleToken=41, deploymentToken=0,
}))
local directNilAbort, directNilReason = directProvider.abort(nil, "ownerless")
eq(directNilAbort, false, "direct ownerless abort retired DEFAULT")
eq(directNilReason, "battle owner mismatch",
  "direct ownerless abort diagnostic")
eq(directCleanupCalls, 0, "direct ownerless abort ran content cleanup")
local directStopped, directStopReason =
  directDescriptor.lifecycle.deactivate(nil, directOwner, "deactivate-live")
check(directStopped, directStopReason)
eq(directCleanupCalls, 1,
  "live provider deactivation did not accept receipt cleanup")
eq(directProvider.health().state, "retired",
  "live provider deactivation did not retire owner")

local abortCleanupCalls = 0
local abortDescriptor = DefaultCard.descriptor({
  finishContent=function()
    abortCleanupCalls = abortCleanupCalls + 1
    return true
  end,
})
local abortOwner, abortProvider = abortDescriptor.lifecycle.activate()
local abortBattle = {}
assert(abortProvider.start(abortBattle, {
  battleToken=42, deploymentToken=0,
}))
local lifecycleAborted, lifecycleAbortReason =
  abortDescriptor.lifecycle.abort(nil, "external", "rollback-live", nil,
    abortOwner)
check(lifecycleAborted, lifecycleAbortReason)
eq(abortCleanupCalls, 1,
  "live provider rollback did not accept receipt cleanup")
eq(abortProvider.health().state, "retired",
  "live provider rollback did not retire owner")

-- A transient content cleanup refusal is tombstoned and retried by the
-- Router's exact abort compensation. The retry completes once; later aborts
-- do not invoke LocalContent/LocalMusic again.
local retryCalls = 0
local retryDescriptor = DefaultCard.descriptor({
  finishContent=function()
    retryCalls = retryCalls + 1
    if retryCalls == 1 then
      return false, "synthetic DEFAULT content failure"
    end
    return true
  end,
})
local _, retryProvider = retryDescriptor.lifecycle.activate()
local retryRouter = RawRouter.new({generation=2})
assert(retryRouter:register(retryProvider))
local retryOwner = {}
assert(retryRouter:start(retryOwner, {
  provider="DEFAULT", requestedMode="DEFAULT",
  battleToken=31, deploymentToken=0,
}))
local retryFinish, retryReason = retryRouter:finish(retryOwner, {
  battleToken=31, deploymentToken=0, result="screen-popped",
})
eq(retryFinish, nil, "failed first content attempt reported success")
check(tostring(retryReason):find("synthetic DEFAULT content failure", 1, true),
  "content retry lost original diagnostic")
eq(retryCalls, 2, "Router compensation did not retry content once")
check(not retryRouter:owns(retryOwner),
  "content retry retained Router owner")
eq(retryProvider.health().contentCompletions, 1,
  "content retry did not create one completed tombstone")
eq(retryProvider.health().contentRetries, 1,
  "content retry metric")
assert(retryProvider.abort(retryOwner, "late-duplicate"))
eq(retryCalls, 2, "completed content tombstone invoked callback again")
eq(retryProvider.health().contentDuplicates, 1,
  "completed content tombstone did not record duplicate terminal edge")

local injectedRouter = RawRouter.new({generation=2})
local injectedAborts = 0
assert(injectedRouter:register({
  schema="ascendant.battle-provider/v1",
  apiVersion=1,
  id="BROKEN",
  version="1.0.0",
  generation=2,
  native=false,
  priority=0,
  canHandle=function() return true end,
  start=function() error("synthetic Gen2 provider start failure") end,
  switch=function() return true end,
  attack=function() return true end,
  finish=function() return true end,
  abort=function()
    injectedAborts = injectedAborts + 1
    return true
  end,
  health=function() return {ok=true} end,
}))
local injectedBattle = {}
local injectedStart, injectedReason = injectedRouter:start(injectedBattle, {
  provider="BROKEN", requestedMode="BROKEN",
  battleToken=1, deploymentToken=0,
})
eq(injectedStart, nil, "throwing Gen2 provider started")
check(tostring(injectedReason):find("synthetic Gen2 provider", 1, true),
  "provider error injection lost diagnostic")
eq(injectedAborts, 1, "failed provider start was not compensated once")
check(not injectedRouter:owns(injectedBattle),
  "failed provider start retained Router owner")

local cardHealth = registry:health(RouterCard.ID, {generation=2})
eq(cardHealth.ok, true, "Gen2 Router Card health")
eq(cardHealth.detail.generation, 2, "Gen2 Router health generation")
eq(cardHealth.detail.providers.DEFAULT.ok, true,
  "Gen2 DEFAULT provider health")

local deactivate, deactivateReason = registry:deactivate(
  RouterCard.ID, {generation=2}, "test-complete")
check(deactivate, deactivateReason)
eq(registry:state(RouterCard.ID), "installed",
  "Gen2 Router did not deactivate")
eq(registry:capability(RouterCard.CAPABILITY), nil,
  "deactivated Gen2 Router capability remained public")

print("Gen2 DEFAULT provider and shared Router contract: ok")
