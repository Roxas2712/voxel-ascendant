-- Built-in Gen-2 exact-owner battle provider Router Card.

local V = ...
local BattleProviderRouter = V.require("core/BattleProviderRouter")
local OwnerControl = V.require(
  "cards/battle_router/BattleRouterOwnerControl")

local Card = {
  ID = "vasc.gen2.battle-router",
  VERSION = "1.0.0",
  CAPABILITY = "ascendant.battle-router.gen2/v1",
  DEFAULT_CAPABILITY = "ascendant.battle-provider.default/v1",
}

function Card.descriptor()
  return {
    schema="ascendant.card/v1",
    id=Card.ID,
    version=Card.VERSION,
    owner="voxel_ascendant",
    requires={},
    optionalRequires={},
    consumes={ Card.DEFAULT_CAPABILITY },
    provides={ Card.CAPABILITY },
    tests={ "tests/gen2_battle_provider_router_test.lua" },
    docs={ "docs/maintainer/RC11_ARCHITECTURE.md" },
    saveNamespace=false,
    impact={
      runtimeOwners={ "gen2.battle.router" },
      saveWrites={},
      publicHooks={},
      files={
        "lib/core/BattleProviderContracts.lua",
        "lib/core/BattleProviderRouter.lua",
        "lib/cards/battle_router/BattleRouterOwnerControl.lua",
        "gen2/lib/cards/battle_router/Gen2BattleRouterCard.lua",
      },
    },
    lifecycle={
      install=function() return { installed=true } end,
      activate=function(context)
        local capability, reason =
          context.capability(Card.DEFAULT_CAPABILITY)
        if type(capability) ~= "table"
            or type(capability.value) ~= "table" then
          return false, reason or "Gen2 DEFAULT provider is unavailable"
        end
        local router = BattleProviderRouter.new({ generation=2 })
        local registered, registerReason = router:register(capability.value)
        if registered ~= true then return false, registerReason end
        local public = router:public()
        local bound, bindReason = OwnerControl.bind(public, router)
        if bound ~= true then
          router:deactivate("Gen2-router-owner-bind-failed")
          return false, bindReason
        end
        return { router=router, public=public }, public
      end,
      deactivate=function(_, active, reason)
        if active == nil or active.router == nil then return true end
        local stopped, stopReason = active.router:deactivate(
          reason or "Gen2-battle-router-card-deactivated")
        if stopped == true then
          OwnerControl.unbind(active.public, active.router)
        end
        return stopped, stopReason
      end,
      abort=function(_, _, reason, _, active)
        if active == nil or active.router == nil then return true end
        local stopped, stopReason = active.router:deactivate(
          reason or "Gen2-battle-router-card-aborted")
        if stopped == true then
          OwnerControl.unbind(active.public, active.router)
        end
        return stopped, stopReason
      end,
      health=function(_, _, active)
        if active == nil or active.router == nil then
          return {
            schema="ascendant.compat-status/v1",
            ok=false,
            generation=2,
            state="inactive",
          }
        end
        return active.router:health()
      end,
    },
  }
end

return Card
