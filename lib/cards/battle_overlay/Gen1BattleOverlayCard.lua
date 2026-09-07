-- Public, read-only Gen-1 battle overlay capability Card.

local V = ...
local BattleOverlayPublic = V.require("core/BattleOverlayPublic")

local Card = {
  ID = "vasc.gen1.battle-overlay",
  VERSION = "1.0.0",
  CAPABILITY = "ascendant.battle-overlay/v1",
  LIFECYCLE_CARD = "vasc.gen1.battle-lifecycle",
  LIFECYCLE_CAPABILITY = "ascendant.battle-context/v1",
  SNAPSHOT_SCHEMA = "voxel-ascendant/hud-snap/v1",
}

function Card.descriptor(dependencies)
  dependencies = dependencies or {}
  local renderer = dependencies.renderer
  return {
    schema="ascendant.card/v1",
    id=Card.ID,
    version=Card.VERSION,
    owner="voxel_ascendant",
    requires={ Card.LIFECYCLE_CARD },
    optionalRequires={},
    consumes={ Card.LIFECYCLE_CAPABILITY },
    provides={ Card.CAPABILITY },
    tests={ "tests/gen1_battle_overlay_card_test.lua" },
    docs={
      "docs/maintainer/RC11_ARCHITECTURE.md",
      "docs/maintainer/RC11_HOOK_OWNERSHIP.md",
      "docs/maintainer/RC11_TEST_MATRIX.md",
    },
    saveNamespace=false,
    impact={
      runtimeOwners={ "gen1.battle.overlay-public" },
      saveWrites={},
      publicHooks={},
      files={
        "lib/core/BattleOverlayPublic.lua",
        "lib/cards/battle_overlay/Gen1BattleOverlayCard.lua",
      },
    },
    lifecycle={
      install=function()
        if type(renderer) ~= "table"
            or type(renderer.hudSnapReceipt) ~= "function" then
          return false, "renderer HUD snapshot seam is unavailable"
        end
        return { installed=true }
      end,
      activate=function(context)
        local capability, reason = context.capability(
          Card.LIFECYCLE_CAPABILITY)
        local lifecycle = capability and capability.value or nil
        local service, control = BattleOverlayPublic.new({
          generation=1,
          owner="VOXEL_ASCENDANT",
          lifecycle=lifecycle,
          snapshot=renderer.hudSnapReceipt,
          currentFrame=function(battle)
            return type(battle) == "table"
              and rawget(battle, "voxelAscendantShot") or nil
          end,
          snapshotSchema=Card.SNAPSHOT_SCHEMA,
        })
        if not service then return false, control or reason end
        return { control=control, service=service }, service
      end,
      deactivate=function(_, active)
        if active and active.control then return active.control.retire() end
        return true
      end,
      abort=function(_, _, _, _, active)
        if active and active.control then return active.control.retire() end
        return true
      end,
      health=function(_, _, active)
        if not active or not active.service then
          return { schema="ascendant.compat-status/v1", ok=false,
            state="inactive" }
        end
        return active.service.health()
      end,
    },
  }
end

return Card
