-- Future VASC external-Card descriptor.
--
-- VASC 3.0 exposes a read-only Card host with externalRegistration=false.
-- Keeping this descriptor in the standalone package makes the future move an
-- adapter change instead of a runtime rewrite; current releases only publish
-- the metadata and never attempt private registration.

local Card = {
  SCHEMA = "ascendant.card/v1",
  ID = "ascendant.pokemon-overworld.visual-provider",
  VERSION = "1.0.0",
  CAPABILITIES = {
    "ascendant.overworld-pokemon/v1",
    "ascendant.overworld-characters/v1",
    "ascendant.character-actions/v1",
    "ascendant.npc-catalog/v1",
  },
}

function Card.descriptor(runtime, characters, characterActions, npcCatalog)
  return {
    schema=Card.SCHEMA,
    id=Card.ID,
    version=Card.VERSION,
    owner="ascendant_pokemon_overworld",
    requires={},
    optionalRequires={},
    consumes={},
    provides=Card.CAPABILITIES,
    tests={ "tests/package_test.py", "tests/runtime_test.lua",
      "tests/pokemon_collision_test.lua" },
    docs={ "README-DE.md", "docs/CARD_INTEGRATION_DE.md" },
    saveNamespace="ascendant_pokemon_overworld",
    impact={
      runtimeOwners={ "overworld.pokemon-follower.visual-provider" },
      saveWrites={ "ascendant_pokemon_overworld" },
      publicHooks={ "ui.party.submenu" },
      files={
        "src/catalog.lua", "src/characters.lua", "src/compat.lua",
        "src/runtime.lua", "src/follower_gen1.lua",
        "src/character_actions.lua",
        "src/npc_catalog.lua",
        "cards/overworld_pokemon_card.lua",
      },
    },
    lifecycle={
      install=function() return { runtime=runtime, characters=characters } end,
      activate=function(_, installed)
        local service = installed and installed.runtime
          and installed.runtime:public() or nil
        if not service then return false, "standalone runtime unavailable" end
        return {
          service=service,
          characters=installed.characters and installed.characters:public(),
          characterActions=characterActions,
          npcCatalog=npcCatalog,
        }, service
      end,
      deactivate=function() return true end,
      abort=function() return true end,
      health=function()
        return runtime and runtime:health() or {
          schema="ascendant.compat-status/v1", ok=false, state="unavailable",
        }
      end,
    },
  }
end

function Card.public(runtime, characters, characterActions, npcCatalog)
  return {
    schema=Card.SCHEMA,
    id=Card.ID,
    version=Card.VERSION,
    provides=Card.CAPABILITIES,
    registration="deferred-until-host-supports-external-registration",
    descriptor=function()
      return Card.descriptor(runtime, characters, characterActions, npcCatalog)
    end,
  }
end

return Card
