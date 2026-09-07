-- Declarative Card boundaries around the supplied, proven Gen-2 A21 runtime.
-- The Cards deliberately do not rewrite or wrap those implementation files.
-- They reserve one capability and one runtime owner per change surface so a
-- later feature cannot silently claim the same responsibility twice.

local V = ...
local CardSet = {}
local A21Ownership = V.require("cards/gen2/A21FileOwnership")

assert(A21Ownership.count() == 217,
  "A21 Gen-2 ownership ledger must cover exactly 217 source files")

local DOC = "docs/maintainer/VASC_66_GEN2_A21_SEGMENT_ROLLBACK.md"
local TEST = "tests/gen2_segment_cards_test.lua"

local DEFINITIONS = {
  {
    id="vasc.gen2.bootstrap",
    capability="ascendant.gen2.bootstrap/v1",
    runtimeOwner="gen2.bootstrap",
    files={
      "main.lua", "lib/Gen2SegmentCardHost.lua",
      "lib/cards/gen2/Gen2SegmentCards.lua",
      "lib/cards/gen2/A21FileOwnership.lua",
      "gen2/main.lua", "gen2/options.lua", "gen2/lib/Gen2PublicExports.lua",
      "gen2/lib/PublicFacade.lua",
    },
  },
  {
    id="vasc.gen2.a21-shared-runtime",
    capability="ascendant.gen2.a21-shared-runtime/v1",
    runtimeOwner="gen2.a21-shared-runtime",
    files={
      "lib/gen2_a21_shared/EditionAccent.lua",
      "lib/gen2_a21_shared/ShortcutToast.lua",
      "lib/gen2_a21_shared/VascMenu.lua",
      "lib/gen2_a21_shared/VascMenuStyle.lua",
      "lib/gen2_a21_shared/Diagnostics.lua",
      "lib/gen2_a21_shared/OrasUiSkin.lua",
      "lib/gen2_a21_shared/OrasPartyPresentation.lua",
      "lib/gen2_a21_shared/OrasPartySummaryPresentation.lua",
      "lib/gen2_a21_shared/OrasBagSkin.lua",
      "lib/gen2_a21_shared/OrasFrlgBagSkin.lua",
      "lib/gen2_a21_shared/PokemonUi.lua",
      "lib/gen2_a21_shared/AscBoxProvider.lua",
      "lib/gen2_a21_shared/BattleLayout.lua",
      "lib/gen2_a21_shared/BattleLayoutProfile.lua",
      "lib/gen2_a21_shared/BattleArenaStyle.lua",
      "lib/gen2_a21_shared/VoxelBattleStage.lua",
      "lib/gen2_a21_shared/data/battle_disks.lua",
    },
  },
  {
    id="vasc.gen2.voxel-world",
    capability="ascendant.gen2.voxel-world/v1",
    runtimeOwner="gen2.voxel-world",
    files={
      "gen2/lib/GoldVoxelBridge.lua", "gen2/lib/GoldPipelineBridge.lua",
      "gen2/lib/GoldComposeBridge.lua", "gen2/lib/VoxelScene.lua",
      "gen2/lib/ChunkMesher.lua", "gen2/lib/Gen2MapWarmup.lua",
      "gen2/lib/Gen2NeighborWarmup.lua",
    },
  },
  {
    id="vasc.gen2.menu-ui",
    capability="ascendant.gen2.menu-ui/v1",
    runtimeOwner="gen2.menu-ui",
    files={
      "gen2/lib/VascMenuGen2.lua", "gen2/lib/PauseMenuBattleStyle.lua",
      "gen2/lib/GoldSubmenuBattleStyle.lua",
      "gen2/lib/SharedVascMenuPresentation.lua",
      "gen2/lib/TitleMenuVascStyle.lua",
      "lib/TitleHubPresentation.lua",
      "gen2/lib/DirectModSettingsMenu.lua",
      "gen2/lib/CategorizedModSettings.lua",
      "assets/ui/gen2/trainer_card/hgss_badge_case_runtime.png",
      "docs/GEN2_TRAINER_CARD_BADGE_CASE.md",
    },
  },
  {
    id="vasc.gen2.ascendant-dex",
    capability="ascendant.gen2.johto-first-dex/v1",
    runtimeOwner="gen2.ascendant-dex",
    files={
      "lib/ModernDex.lua", "lib/Gen2ModernDexHost.lua",
      "lib/gen2_dex/AscendantDex.lua",
    },
    activationModules={ "Gen2ModernDexHost" },
    saveNamespace="modData.VOXEL_ASCENDANT.gen2AscendantDex",
    saveWrites={
      "modData.VOXEL_ASCENDANT.gen2AscendantDex.globalUnlocked",
    },
  },
  {
    id="vasc.gen2.battle-presentation",
    capability="ascendant.gen2.battle-presentation/v1",
    runtimeOwner="gen2.battle-presentation",
    files={
      "gen2/lib/OverworldBattle.lua",
      "gen2/lib/BattleScene.lua", "gen2/lib/BattleControllerUI.lua",
      "gen2/lib/BattleAnimationCompat.lua",
      "gen2/lib/BattleEffectAnchors.lua",
      "gen2/lib/BattleStadiumAnimations.lua",
      "gen2/lib/BattleStadiumEffects.lua",
      "gen2/lib/BattleStadium3DFx.lua",
    },
  },
  {
    id="vasc.gen2.field-wilds",
    capability="ascendant.gen2.field-wilds/v1",
    runtimeOwner="gen2.field-wilds",
    files={
      "gen2/lib/EmbeddedWildsMain.lua", "gen2/lib/GoldWildsBridge.lua",
      "gen2/lib/GoldPartyFollower.lua", "gen2/lib/Gen2WorldMap.lua",
      "gen2/lib/GoldFieldMovePresentation.lua",
      "gen2/lib/SpeciesFishingCinematic.lua",
    },
  },
  {
    id="vasc.gen2.device-diagnostics",
    capability="ascendant.gen2.device-diagnostics/v1",
    runtimeOwner="gen2.device-diagnostics",
    files={
      "gen2/lib/DeviceProfile.lua", "gen2/lib/Gen2PerformancePolicy.lua",
      "gen2/lib/VascRendererOptions.lua", "gen2/lib/BuildBudget.lua",
      "gen2/lib/Quality.lua",
      "gen2/lib/AndroidFullFrameFlip.lua", "gen2/lib/GoldCameraControls.lua",
      "gen2/lib/VascEnvironment.lua", "gen2/lib/diagnostics.lua",
    },
  },
}

-- Replace each representative list with the complete A21 file ledger for that
-- owner, retaining root adapters and Card infrastructure as explicit extras.
for _, definition in ipairs(DEFINITIONS) do
  definition.files = A21Ownership.filesFor(definition.id, definition.files)
end

local function descriptor(definition)
  local service = {
    schema="voxel-ascendant/gen2-segment/v1",
    id=definition.id,
    capability=definition.capability,
    runtimeOwner=definition.runtimeOwner,
  }
  return {
    schema="ascendant.card/v1",
    id=definition.id,
    version="1.0.0",
    owner="voxel_ascendant",
    requires={},
    optionalRequires={},
    consumes={},
    provides={ definition.capability },
    tests={ TEST },
    docs={ DOC },
    saveNamespace=definition.saveNamespace or false,
    impact={
      runtimeOwners={ definition.runtimeOwner },
      saveWrites=definition.saveWrites or {},
      publicHooks={},
      files=definition.files,
    },
    lifecycle={
      install=function() return { installed=true } end,
      activate=function()
        local adapters = {}
        if definition.activationModules and V.mod and V.mod.content then
          for _, moduleName in ipairs(definition.activationModules) do
            local adapter = V.require(moduleName)
            local ok, reason = adapter.install()
            if ok ~= true then return false, reason end
            adapters[moduleName] = adapter
          end
        end
        return { active=true, adapters=adapters }, service
      end,
      deactivate=function() return true end,
      abort=function() return true end,
      health=function(_, _, active)
        return {
          schema="ascendant.compat-status/v1", apiVersion=1,
          generation=2, ok=active ~= nil and active.active == true,
          state=active and "active" or "inactive", card=definition.id,
        }
      end,
    },
  }
end

function CardSet.descriptors()
  local result = {}
  for _, definition in ipairs(DEFINITIONS) do
    result[#result + 1] = descriptor(definition)
  end
  return result
end

return CardSet
