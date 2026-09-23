-- Optional appearance Card. KASC owns character identity and save-local
-- combinations; this Card owns activation and the renderer-facing service.
local V=...
local C={ID='vasc.gen1.wardrobe',VERSION='1.3.0'}
local registry,setting
local function provider()
  local handle=V.mod:find('kanto_ascendant')
  if handle then return handle.exports and handle.exports.wardrobe end
  return V.mod.exports.wardrobe
end
local function active(value,game)
  local api=provider()
  if api and api.setActive then api.setActive(value,game)end
end
function C.entries()
  if not setting then
    setting=V.require('ModSetting').new('wardrobeEnabled','WARDROBE CARD',{false,true},{'OFF','ON'},true)
    setting:onChange(function(game,value)
      if registry then
        if value then registry:activate(C.ID,{generation=1,host='VOXEL_ASCENDANT'})
        else registry:deactivate(C.ID,{generation=1,host='VOXEL_ASCENDANT'})end
      end
      active(value,game)
    end)
  end
  return{{setting,'Outfits in HD or 2D, Champion looks, caps and accessories. Wardrobe upstairs at home.',full=true}}
end
function C.enabled()return setting and setting:get()==true end
function C.descriptor()
  local solo=V.mod.exports.wardrobe~=nil
  return{schema='ascendant.card/v1',id=C.ID,version=C.VERSION,owner='voxel_ascendant',
    requires={},optionalRequires={},consumes={},provides={'ascendant.wardrobe/v1'},saveNamespace=solo and'wardrobe_v1'or false,
    tests={'tests/wardrobe_card_test.lua'},docs={'docs/maintainer/WARDROBE_CARD.md'},
    impact={runtimeOwners={'gen1.characters.wardrobe'},saveWrites=solo and{'wardrobe_v1'}or{},publicHooks=solo and{'core.update','render.hud'}or{},
      files={'lib/cards/wardrobe/Gen1WardrobeCard.lua','lib/cards/wardrobe/SoloWardrobe.lua'}},
    lifecycle={
      install=function()C.entries();return{}end,
      activate=function()
        active(C.enabled())
        return{state='active'},{schema='ascendant.wardrobe-service/v1',
          resolve=function(path,id)
            local api=provider();return api and C.enabled()and api.resolve(path,id)or path
          end,
          selection=function(id)local api=provider();return api and api.get(id)or nil end}
      end,
      deactivate=function()active(false);return true end,
      abort=function()active(false);return true end,
      health=function()
        local api=provider()
        return{schema='ascendant.wardrobe-health/v1',ok=api~=nil,enabled=C.enabled(),
          provider=api and api.schema or'missing-provider',nativeSprites='untouched',
          appearanceReady=api and api.appearanceReady==true or false}
      end,
    },
  }
end
function C.boot()
  if registry then return true end
  C.entries()
  if not V.mod:find('kanto_ascendant')then
    V.require('cards/wardrobe/SoloWardrobe').install(C.enabled)
  end
  registry=V.require('core/AscendantCardRegistry').new()
  local ok,why=registry:register(C.descriptor())
  if ok then ok,why=registry:activate(C.ID,{generation=1,host='VOXEL_ASCENDANT'})end
  V.mod.exports.wardrobeCard={id=C.ID,version=C.VERSION,enabled=C.enabled,
    health=function()return registry:health(C.ID,{generation=1,host='VOXEL_ASCENDANT'})end,
    descriptor=C.descriptor,setting=setting}
  V.mod.events:on('game.ready',function(ev)active(C.enabled(),ev and ev.game)end)
  V.mod.events:on('save.loaded',function(ev)active(C.enabled(),ev and ev.game)end)
  if not ok then V.mod.log:warn('Wardrobe Card unavailable: %s',tostring(why))end
  return ok,why
end
return C
