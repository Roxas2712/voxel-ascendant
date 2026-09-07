-- Built-in Gen-1 battle provider router Card.

local V = ...
local BattleProviderRouter = V.require("core/BattleProviderRouter")
local OwnerControl = V.require(
  "cards/battle_router/BattleRouterOwnerControl")

local Card = {
  ID = "vasc.gen1.battle-router",
  VERSION = "1.0.0",
  CAPABILITY = "ascendant.battle-router.gen1/v1",
  DEFAULT_CAPABILITY = "ascendant.battle-provider.default/v1",
  DISCS_CAPABILITY = "ascendant.battle-provider.discs/v1",
}

function Card.descriptor()
  return {
    schema="ascendant.card/v1",
    id=Card.ID,
    version=Card.VERSION,
    owner="voxel_ascendant",
    requires={},
    optionalRequires={},
    consumes={ Card.DEFAULT_CAPABILITY, Card.DISCS_CAPABILITY },
    provides={ Card.CAPABILITY },
    tests={ "tests/gen1_battle_provider_router_test.lua" },
    docs={
      "docs/maintainer/RC11_ARCHITECTURE.md",
      "docs/maintainer/RC11_HOOK_OWNERSHIP.md",
      "docs/maintainer/RC11_TEST_MATRIX.md",
    },
    saveNamespace=false,
    impact={
      runtimeOwners={ "gen1.battle.router" },
      saveWrites={},
      publicHooks={},
      files={
        "lib/core/BattleProviderContracts.lua",
        "lib/core/BattleProviderRouter.lua",
        "lib/cards/battle_router/BattleRouterOwnerControl.lua",
        "lib/cards/battle_router/Gen1BattleRouterCard.lua",
      },
    },
    lifecycle={
      install=function() return { installed=true } end,
      activate=function(context)
        local capability, reason = context.capability(Card.DEFAULT_CAPABILITY)
        if not capability or type(capability.value) ~= "table" then
          return false, reason or "DEFAULT provider capability is unavailable"
        end
        local discsCapability, discsReason =
          context.capability(Card.DISCS_CAPABILITY)
        if not discsCapability or type(discsCapability.value) ~= "table" then
          return false, discsReason or "DISCS provider capability is unavailable"
        end
        local router = BattleProviderRouter.new({ generation=1 })
        local registered, registerReason = router:register(capability.value)
        if not registered then return false, registerReason end
        registered, registerReason = router:register(discsCapability.value)
        if not registered then
          router:deactivate("DISCS-provider-registration-failed")
          return false, registerReason
        end
        local public = router:public()
        local bound, bindReason = OwnerControl.bind(public, router)
        if not bound then
          router:deactivate("battle-router-owner-bind-failed")
          return false, bindReason
        end
        return { router=router, public=public }, public
      end,
      deactivate=function(_, active, reason)
        if active and active.router then
          local stopped, stopReason = active.router:deactivate(
            reason or "battle-router-card-deactivated")
          if stopped == true then
            OwnerControl.unbind(active.public, active.router)
          end
          return stopped, stopReason
        end
        return true
      end,
      abort=function(_, _, reason, _, active)
        if active and active.router then
          local stopped, stopReason = active.router:deactivate(
            reason or "battle-router-card-aborted")
          if stopped == true then
            OwnerControl.unbind(active.public, active.router)
          end
          return stopped, stopReason
        end
        return true
      end,
      health=function(_, _, active)
        if not active or not active.router then
          return { schema="ascendant.compat-status/v1", ok=false,
            state="inactive" }
        end
        return active.router:health()
      end,
    },
  }
end

return Card
