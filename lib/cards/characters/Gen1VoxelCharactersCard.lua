-- Optional local-test Card. Appearance only: the existing wardrobe, battle
-- and species-cinematic owners keep all gameplay and animation timelines.
local V=...
local C={ID='vasc.gen1.voxel-characters',VERSION='0.1.0-test.3'}
local registry,setting,settings
local function walking()
 local api=V.mod.exports.overworldPokemon
 return api and api.walkingSprites
end
local function refresh(game)local api=walking();if api then api.refresh(game)end end
function C.entries()
 if not setting then
  setting=V.require('ModSetting').new('voxelCharacterCardEnabled','VOXEL CHARACTERS CARD',{false,true},{'OFF','ON'},true)
  setting:onChange(function(game,value)
   if registry then
    if value then registry:activate(C.ID,{generation=1})else registry:deactivate(C.ID,{generation=1})end
   end
   refresh(game)
  end)
 end
 return{{setting,'Optional local test: voxel characters and wardrobe. F6: Original / HD / Voxel. Uses existing ball-throw, fishing, surfing and flying scripts.',full=true}}
end
function C.enabled()return setting and setting:get()==true end
function C.bind(entries)
 settings={};for _,entry in ipairs(entries)do settings[entry[1].key]=entry[1]end
end
function C.mode()
 local opts=V.mod.options
 if opts:get('apo_hd_walking_sprites')==false then return 'native' end
 return C.enabled()and opts:get('apo_human_art_style')=='voxel'and'voxel'or'hd'
end
function C.canChange(game)
 if not(game and game.overworld and game.stack and game.stack:top()==game.overworld)then return false end
 local player=game.overworld.player
 if not player or player.fishing or game.overworld.fishing then return false end
 local h=V.mod:find('kanto_ascendant');local w=h and h.exports and h.exports.wardrobe or V.mod.exports.wardrobe
 if w and w.canChange and not w.canChange(game)then return false end
 for _,api in pairs(V.mod.exports.speciesCinematics or{})do
  if type(api)=='table'and type(api.status)=='function'then
   local state=api.status(game.overworld)
   if state and(state.active==true or state.phase~=nil)then return false end
  end
 end
 return true
end
function C.select(mode,game)
 if mode~='native'and mode~='hd'and mode~='voxel'then return false end
 if not C.canChange(game)or not settings then return false end
 if mode=='voxel'and not C.enabled()then return false end
 local hd,style=settings.apo_hd_walking_sprites,settings.apo_human_art_style
 if not(hd and style)then return false end
 -- Same persisted option owners as the full settings page.
 if mode=='native'then hd:setValue(false,game)
 else style:setValue(mode,game);hd:setValue(true,game)end
 refresh(game)
 return C.mode()==mode
end
function C.cycle(game)
 local modes=C.enabled()and{'native','hd','voxel'}or{'native','hd'}
 local current=C.mode();local at=1
 for i,value in ipairs(modes)do if value==current then at=i end end
 return C.select(modes[at%#modes+1],game)
end
function C.label()return({native='2D / ORIGINAL',hd='HD',voxel='VOXEL'})[C.mode()]end
function C.descriptor()
 return{schema='ascendant.card/v1',id=C.ID,version=C.VERSION,owner='voxel_ascendant',
 requires={},optionalRequires={},consumes={},provides={'ascendant.voxel-characters/v1'},saveNamespace=false,
 tests={'tests/voxel_characters_card_test.lua'},docs={'docs/maintainer/VOXEL_CHARACTERS_CARD.md'},
 impact={runtimeOwners={'gen1.characters.voxel-style'},saveWrites={},publicHooks={},files={'lib/cards/characters/Gen1VoxelCharactersCard.lua'}},
 lifecycle={install=function()return{}end,
 activate=function()return{},{schema='ascendant.voxel-characters/v1',mode=C.mode,select=C.select,cycle=C.cycle}end,
 deactivate=function()refresh();return true end,abort=function()refresh();return true end,
 health=function()return{ok=walking()~=nil,enabled=C.enabled(),mode=C.mode(),quality='local-test',animationOwner='existing-battle-and-field-scripts'}end}}
end
function C.boot()
 if registry then return true end
 C.entries();registry=V.require('core/AscendantCardRegistry').new()
 local ok,why=registry:register(C.descriptor())
 if ok and C.enabled()then ok,why=registry:activate(C.ID,{generation=1})end
 C.health=function()return registry:health(C.ID,{generation=1})end
 C.setting=setting;V.mod.exports.voxelCharacterCard=C
 V.mod.events:on('mod.options_changed',function(ev)
  if ev and(ev.mod or ev.modId)==V.mod.id then
   setting:sync(V.mod.options:get(setting.key))
   if C.enabled()then registry:activate(C.ID,{generation=1})else registry:deactivate(C.ID,{generation=1})end
   refresh(ev.game)
  end
 end)
 return ok,why
end
return C
