-- Gen1 render owner: independent of the combat registry and save lifecycle.
local V = ...
local Lights = V.require('LocalLights')
local Card = {
  ID='vasc.gen1.dynamic-lighting', VERSION='1.0.0',
  CAPABILITY='ascendant.gen1.dynamic-lighting/v1',
}
function Card.status()
  return {
    schema=Card.CAPABILITY, active=Lights.available(),
    profile=Lights.mobile and 'mobile' or 'desktop',
    world=Lights.enabled(),
    battle=Lights.available() and V.require('BattleLights').setting:get(),
    maxLights=Lights.MAX_LIGHTS, maxBattleLights=Lights.MAX_BATTLE_LIGHTS,
    maxPortals=Lights.MAX_PORTALS, error=Lights.failure,
  }
end
local function stop()
  Lights.setOwnerActive(false)
  V.require('LightAtmosphere').invalidate()
  return true
end
function Card.descriptor()
  return {
    schema='ascendant.card/v1', id=Card.ID, version=Card.VERSION,
    owner='voxel_ascendant', requires={}, optionalRequires={}, consumes={},
    provides={Card.CAPABILITY}, saveNamespace=false,
    tests={'tests/dynamic_lighting_card_test.lua','tests/local_lights_test.lua',
      'tests/native_window_lights_test.lua','tests/indoor_mist_lighting_test.lua',
      'tests/mobile_local_lights_test.lua','tests/mobile_lighting_fallback_test.lua'},
    docs={'docs/maintainer/GEN1_DYNAMIC_LIGHTING.md'},
    impact={runtimeOwners={'gen1.dynamic-lighting'},saveWrites={},publicHooks={},
      files={'lib/cards/lighting/Gen1DynamicLightingCard.lua','lib/LocalLights.lua',
        'lib/BattleLights.lua','lib/InteriorLights.lua','lib/LightVisibility.lua','lib/NativeWindowLights.lua',
        'lib/LightAtmosphere.lua','lib/Voxel3D.lua','lib/VoxelScene.lua',
        'lib/BattleScene.lua','lib/DayNight.lua','lib/Water.lua','lib/IndoorMist.lua',
        'lib/CaveTorches.lua','lib/TowerAtmosphere.lua','lib/VoxelFurniture.lua',
        'lib/VoxelPropBatch.lua','lib/VascMenu.lua','main_gen1.lua',
        'integrated/ascendant_pokemon_overworld/src/pokemon_card_style.lua',
        'integrated/ascendant_pokemon_overworld/src/voxel_characters.lua'}},
    lifecycle={
      install=function() return {installed=true} end,
      activate=function(context)
        if not context.runtime or context.runtime.generation~=1 then
          return false,'Gen1 only'
        end
        Lights.setOwnerActive(true)
        return {active=true},{status=Card.status}
      end,
      deactivate=stop, abort=stop, health=Card.status,
    },
  }
end
function Card.installHost(mod,diagnostics)
  local registry=V.require('core/AscendantCardRegistry').new()
  local runtime={generation=1,host='VOXEL_ASCENDANT'}
  Lights.setOwnerActive(false)
  local registered,reason=registry:register(Card.descriptor())
  local active=false
  if registered then active,reason=registry:activate(Card.ID,runtime) end
  if not active then Lights.setOwnerActive(false) end
  diagnostics.registerSegment({
    segmentId=Card.ID,cardId=Card.ID,version=Card.VERSION,
    schema='ascendant.card/v1',owner='voxel_ascendant',active=active,
    dependencyStatus=registry:state(Card.ID) or 'unavailable',
    providerStatus=active and 'active' or tostring(reason),
    buildReceiptId='GEN1-DYNAMIC-LIGHTING-20260919',
    rollbackReceiptId='GEN1-DYNAMIC-LIGHTING-OFF',
  })
  mod.exports.dynamicLighting={
    apiVersion=1,status=Card.status,
    setActive=function(value)
      if value then return registry:activate(Card.ID,runtime) end
      return registry:deactivateAll(runtime,'disabled')
    end,
  }
end
return Card
