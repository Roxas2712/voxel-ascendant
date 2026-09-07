-- Native Gen-2 DEFAULT/2D battle provider Card.
--
-- DEFAULT is a real exact owner, not an empty legacy renderer session.  This
-- provider deliberately owns no pixels, stage, shot or nativeOnly bridge.
-- Gold's BattleState and animForMove remain the presentation owners.

local Card = {
  ID = "vasc.gen2.battle-provider.default",
  VERSION = "1.0.0",
  CAPABILITY = "ascendant.battle-provider.default/v1",
}

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

local function publicContentReceipt(routerReceipt)
  routerReceipt = type(routerReceipt) == "table" and routerReceipt or {}
  return {
    schema="ascendant.gen2-content-finish/v1",
    apiVersion=1,
    provider="DEFAULT",
    generation=2,
    battleToken=routerReceipt.battleToken,
    deploymentToken=routerReceipt.deploymentToken,
  }
end

local function finishContent(owner, battle, reason, routerReceipt)
  local tombstone = owner.contentTombstones[battle]
  if tombstone ~= nil and tombstone.complete == true then
    owner.contentDuplicates = owner.contentDuplicates + 1
    return true
  end
  if tombstone == nil then
    tombstone = { attempts=0, complete=false }
    owner.contentTombstones[battle] = tombstone
    owner.contentPending = owner.contentPending + 1
  elseif tombstone.running then
    return false, "Gen2 DEFAULT content finish is already running"
  else
    owner.contentRetries = owner.contentRetries + 1
  end
  tombstone.attempts = tombstone.attempts + 1
  tombstone.running = true
  owner.contentAttempts = owner.contentAttempts + 1
  local ok, value, detail = pcall(owner.finishContent, battle,
    safeText(reason, "Gen2-default-finished"),
    publicContentReceipt(routerReceipt))
  tombstone.running = false
  if not ok or value == false then
    owner.contentFailures = owner.contentFailures + 1
    tombstone.error = safeText(ok and detail or value,
      "Gen2 DEFAULT content finish declined")
    return false, tombstone.error
  end
  tombstone.complete = true
  tombstone.error = nil
  owner.contentPending = owner.contentPending - 1
  owner.contentCompletions = owner.contentCompletions + 1
  owner.contentOrder[#owner.contentOrder + 1] = battle
  if #owner.contentOrder > owner.contentTombstoneLimit then
    local expired = table.remove(owner.contentOrder, 1)
    local old = owner.contentTombstones[expired]
    if old ~= nil and old.complete == true then
      owner.contentTombstones[expired] = nil
    end
  end
  return true
end

local function receipt(owner, state)
  return {
    schema="ascendant.battle-provider-state/v1",
    apiVersion=1,
    provider="DEFAULT",
    generation=2,
    state=state or (owner.active and owner.active.state) or "idle",
    presentationOwner="GoldBattleState",
    movePresentationOwner="animForMove",
    battleToken=owner.active and owner.active.battleToken or nil,
    deploymentToken=owner.active and owner.active.deploymentToken or nil,
    starts=owner.starts,
    switches=owner.switches,
    observedAttacks=owner.observedAttacks,
    finishes=owner.finishes,
    aborts=owner.aborts,
  }
end

local function provider(owner)
  local function exact(battle)
    return owner.active ~= nil and battle ~= nil
      and same(owner.active.battle, battle)
  end
  return {
    schema="ascendant.battle-provider/v1",
    apiVersion=1,
    id="DEFAULT",
    version=Card.VERSION,
    generation=2,
    native=true,
    priority=-1000,
    canHandle=function(context)
      return type(context) == "table" and context.provider == "DEFAULT"
    end,
    start=function(battle, context)
      if battle == nil then return false, "battle owner is required" end
      if owner.retired then return false, "Gen2 DEFAULT provider is retired" end
      if owner.active ~= nil and not exact(battle) then
        return false, "another Gen2 DEFAULT owner is active"
      end
      if owner.active == nil then
        context = type(context) == "table" and context or {}
        owner.active = {
          battle=battle,
          state="active",
          battleToken=context.battleToken,
          deploymentToken=context.deploymentToken,
        }
        owner.starts = owner.starts + 1
      end
      return receipt(owner, "active")
    end,
    switch=function(battle, context)
      if not exact(battle) then return false, "battle owner mismatch" end
      context = type(context) == "table" and context or {}
      owner.active.deploymentToken = context.deploymentToken
        or owner.active.deploymentToken
      owner.switches = owner.switches + 1
      return receipt(owner, "active")
    end,
    attack=function(battle)
      if not exact(battle) then return false, "battle owner mismatch" end
      -- The Router contract requires this callback, but Gen-2 lifecycle does
      -- not route battle.move_used here.  If a diagnostic caller invokes it,
      -- record observation only; never start a second animation.
      owner.observedAttacks = owner.observedAttacks + 1
      return receipt(owner, "active")
    end,
    finish=function(battle, context, routerReceipt)
      if not exact(battle) then return false, "battle owner mismatch" end
      context = type(context) == "table" and context or {}
      local cleaned, cleanupReason = finishContent(owner, battle,
        context.result or "screen-popped", routerReceipt)
      if cleaned ~= true then return false, cleanupReason end
      owner.finishes = owner.finishes + 1
      owner.active = nil
      return receipt(owner, "ended")
    end,
    abort=function(battle, reason, routerReceipt)
      if owner.active == nil then
        local tombstone = battle ~= nil and owner.contentTombstones[battle]
        if tombstone ~= nil and tombstone.complete == true then
          owner.contentDuplicates = owner.contentDuplicates + 1
        end
        return true
      end
      if battle == nil or not exact(battle) then
        return false, "battle owner mismatch"
      end
      local cleaned, cleanupReason = finishContent(owner,
        owner.active.battle, reason or "Gen2-default-aborted", routerReceipt)
      if cleaned ~= true then return false, cleanupReason end
      owner.aborts = owner.aborts + 1
      owner.active = nil
      return receipt(owner, "aborted")
    end,
    health=function()
      return {
        schema="ascendant.compat-status/v1",
        apiVersion=1,
        ok=not owner.retired and owner.contentPending == 0,
        generation=2,
        state=owner.retired and "retired"
          or (owner.active and "active" or "idle"),
        active=owner.active ~= nil,
        battleToken=owner.active and owner.active.battleToken or nil,
        deploymentToken=owner.active and owner.active.deploymentToken or nil,
        starts=owner.starts,
        switches=owner.switches,
        observedAttacks=owner.observedAttacks,
        finishes=owner.finishes,
        aborts=owner.aborts,
        contentAttempts=owner.contentAttempts,
        contentRetries=owner.contentRetries,
        contentCompletions=owner.contentCompletions,
        contentFailures=owner.contentFailures,
        contentPending=owner.contentPending,
        contentDuplicates=owner.contentDuplicates,
        contentTombstones=#owner.contentOrder,
        contentTombstoneLimit=owner.contentTombstoneLimit,
        presentationOwner="GoldBattleState",
        movePresentationOwner="animForMove",
      }
    end,
  }
end

function Card.descriptor(dependencies)
  dependencies = type(dependencies) == "table" and dependencies or {}
  local contentCallback = dependencies.finishContent
  assert(type(contentCallback) == "function",
    "Gen2DefaultBattleProviderCard needs finishContent")
  return {
    schema="ascendant.card/v1",
    id=Card.ID,
    version=Card.VERSION,
    owner="voxel_ascendant",
    requires={},
    optionalRequires={},
    consumes={},
    provides={ Card.CAPABILITY },
    tests={ "tests/gen2_battle_provider_router_test.lua" },
    docs={ "docs/maintainer/RC11_ARCHITECTURE.md" },
    saveNamespace=false,
    impact={
      runtimeOwners={ "gen2.battle.provider.default" },
      saveWrites={},
      publicHooks={},
      files={
        "gen2/lib/cards/battle_router/Gen2DefaultBattleProviderCard.lua",
      },
    },
    lifecycle={
      install=function() return { installed=true } end,
      activate=function()
        local owner = {
          retired=false,
          active=nil,
          starts=0,
          switches=0,
          observedAttacks=0,
          finishes=0,
          aborts=0,
          finishContent=contentCallback,
          contentTombstones={},
          contentOrder={},
          contentTombstoneLimit=32,
          contentAttempts=0,
          contentRetries=0,
          contentCompletions=0,
          contentFailures=0,
          contentPending=0,
          contentDuplicates=0,
        }
        return owner, provider(owner)
      end,
      deactivate=function(_, owner, reason)
        if owner.active ~= nil then
          local stopped, stopReason = provider(owner).abort(
            owner.active.battle,
            reason or "Gen2-default-provider-deactivated", {
              battleToken=owner.active.battleToken,
              deploymentToken=owner.active.deploymentToken,
            })
          if stopped == false or stopped == nil then
            return false, stopReason
          end
        end
        owner.retired = true
        return true
      end,
      abort=function(_, _, reason, _, owner)
        if owner ~= nil then
          if owner.active ~= nil then
            local stopped, stopReason = provider(owner).abort(
              owner.active.battle,
              reason or "Gen2-default-provider-aborted", {
                battleToken=owner.active.battleToken,
                deploymentToken=owner.active.deploymentToken,
              })
            if stopped == false or stopped == nil then
              return false, stopReason
            end
          end
          owner.retired = true
        end
        return true
      end,
      health=function(_, _, owner)
        if owner == nil then
          return {
            schema="ascendant.compat-status/v1",
            ok=false,
            generation=2,
            state="inactive",
          }
        end
        return provider(owner).health()
      end,
    },
  }
end

return Card
