-- Native Gen-1 DEFAULT/2D provider Card.
--
-- This provider intentionally owns no pixels and patches no engine methods.
-- Its job is to make native presentation a first-class exact owner with a
-- complete lifecycle, rather than an absence of VASC state.

local Card = {
  ID = "vasc.gen1.battle-provider.default",
  VERSION = "1.0.0",
  CAPABILITY = "ascendant.battle-provider.default/v1",
}

local function sameBattle(left, right)
  return rawequal(left, right)
end

local function buildProvider(owner)
  local function exact(battle)
    return owner.active ~= nil and sameBattle(owner.active.battle, battle)
  end
  local function publicReceipt(state)
    return {
      schema="ascendant.battle-provider-state/v1",
      apiVersion=1,
      provider="DEFAULT",
      generation=1,
      state=state or (owner.active and owner.active.state) or "idle",
      switches=owner.switches,
      attacks=owner.attacks,
      starts=owner.starts,
      finishes=owner.finishes,
      aborts=owner.aborts,
    }
  end
  return {
    schema="ascendant.battle-provider/v1",
    apiVersion=1,
    id="DEFAULT",
    version=Card.VERSION,
    generation=1,
    native=true,
    priority=-1000,
    canHandle=function(context)
      return type(context) == "table" and context.provider == "DEFAULT"
    end,
    start=function(battle)
      if battle == nil then return false, "battle owner is required" end
      if owner.retired then return false, "DEFAULT provider is retired" end
      if owner.active and not sameBattle(owner.active.battle, battle) then
        owner.aborts = owner.aborts + 1
      end
      owner.active = { battle=battle, state="active" }
      owner.starts = owner.starts + 1
      return publicReceipt("active")
    end,
    switch=function(battle)
      if not exact(battle) then return false, "battle owner mismatch" end
      owner.switches = owner.switches + 1
      return publicReceipt("active")
    end,
    attack=function(battle)
      if not exact(battle) then return false, "battle owner mismatch" end
      owner.attacks = owner.attacks + 1
      return publicReceipt("active")
    end,
    finish=function(battle)
      if not exact(battle) then return false, "battle owner mismatch" end
      owner.finishes = owner.finishes + 1
      owner.active = nil
      return publicReceipt("ended")
    end,
    abort=function(battle)
      if owner.active == nil then return true end
      if battle ~= nil and not exact(battle) then
        return false, "battle owner mismatch"
      end
      owner.aborts = owner.aborts + 1
      owner.active = nil
      return publicReceipt("aborted")
    end,
    health=function()
      return {
        schema="ascendant.compat-status/v1",
        apiVersion=1,
        ok=not owner.retired,
        state=owner.retired and "retired"
          or (owner.active and "active" or "idle"),
        active=owner.active ~= nil,
        starts=owner.starts,
        switches=owner.switches,
        attacks=owner.attacks,
        finishes=owner.finishes,
        aborts=owner.aborts,
      }
    end,
  }
end

function Card.descriptor()
  return {
    schema="ascendant.card/v1",
    id=Card.ID,
    version=Card.VERSION,
    owner="voxel_ascendant",
    requires={},
    optionalRequires={},
    consumes={},
    provides={ Card.CAPABILITY },
    tests={ "tests/gen1_battle_provider_router_test.lua" },
    docs={
      "docs/maintainer/RC11_ARCHITECTURE.md",
      "docs/maintainer/RC11_HOOK_OWNERSHIP.md",
      "docs/maintainer/RC11_TEST_MATRIX.md",
    },
    saveNamespace=false,
    impact={
      runtimeOwners={ "gen1.battle.provider.default" },
      saveWrites={},
      publicHooks={},
      files={
        "lib/cards/battle_router/Gen1DefaultBattleProviderCard.lua",
      },
    },
    lifecycle={
      install=function() return { installed=true } end,
      activate=function()
        local owner = {
          retired=false, active=nil, starts=0, switches=0, attacks=0,
          finishes=0, aborts=0,
        }
        return owner, buildProvider(owner)
      end,
      deactivate=function(_, owner)
        if owner.active then owner.aborts = owner.aborts + 1 end
        owner.active = nil
        owner.retired = true
        return true
      end,
      abort=function(_, _, _, _, owner)
        if owner then
          if owner.active then owner.aborts = owner.aborts + 1 end
          owner.active = nil
          owner.retired = true
        end
        return true
      end,
      health=function(_, _, owner)
        if not owner then
          return { schema="ascendant.compat-status/v1", ok=false,
            state="inactive" }
        end
        return buildProvider(owner).health()
      end,
    },
  }
end

return Card
