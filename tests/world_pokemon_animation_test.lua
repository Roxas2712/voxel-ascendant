local root=assert(arg[1]);local loads=0
local function image(path)return{path=path,getDimensions=function()return 56,56 end}end
package.loaded['src.render.Assets']={register=function()end,image=function(p)loads=loads+1;return image(p)end}
local motion=true
local owner={crystalAnimation={voxelPresentationAnimation=function()return nil end},
 worldEncounterAnimations={path='mod',enabled=function()return motion end,rows={
 MEWTWO={root='mewtwo',durations={50,50}},GROUDON={root='groudon',durations={50,50}}}},
 postgameData={staticLegends={MEWTWO={map='CERULEAN_CAVE_B1F',object='CERULEANCAVEB1F_MEWTWO'}}}}
local M=assert(loadfile(root..'/lib/WorldPokemonAnimation.lua'))({mod={find=function()return{exports=owner}end}})
local map={id='CERULEAN_CAVE_B1F',def={}}
local native={def={id='SPRITE_MONSTER',frames=6}}
local e={def={name='CERULEANCAVEB1F_MEWTWO'},sprite=native,px=128,py=64,cellX=8,cellY=4}
local game={data={},overworld={map=map}}
local function pose()return{mapId=map.id,entity=e,sprite=native,px=e.px,py=e.py,gh=0}end
M.update(game,.01,7);local p=pose();M.prepare(game.overworld,{p});assert(loads==0 and p.sprite==native,'load happened in draw')
M.update(game,.01,7);p=pose();M.prepare(game.overworld,{p})
assert(p.sprite~=native and p.sprite.def.voxelWorldHeight==24,'Mewtwo must use two metre body scale')
assert(e.sprite==native and e.px==128 and e.py==64 and e.cellX==8 and e.cellY==4,'encounter moved')
local first=p.sprite.image;local shadow=p.sprite.shadowImage
local before=loads;M.prepare(game.overworld,{p});assert(loads==before,'extra render pass loaded/advanced')
M.update(game,.06,7);p=pose();M.prepare(game.overworld,{p});assert(p.sprite.image~=first and p.sprite.shadowImage==shadow)
motion=false;local held=p.sprite.image;M.update(game,.1,7);p=pose();M.prepare(game.overworld,{p});assert(p.sprite.image==held and p.sprite.def.voxelWorldHeight==24,'OFF lost scale or advanced')
assert(M.identify({entity={species='PIKACHU'},sprite={def={frames=6}},mapId=map.id})==nil,'animated walker replaced')
assert(M.identify({entity={species='GROUDON'},sprite=native,mapId='ROUTE_1'})=='GROUDON')
assert(M.identify({entity={species='GROUDON',ascendantPokemonModelSource='stadium2'},sprite=native})==nil)
assert(M.identify({entity={species='PIKACHU',_wildsFollowerSpecies='PIKACHU'},sprite={def={frames=1}}})==nil)
assert(M.identify({entity={species='PIKACHU'},sprite={def={frames=1}},isPlayer=true})==nil)
assert(M.identify({entity={species='PIKACHU'},sprite={def={frames=1}}})=='PIKACHU')
for _,hd in ipairs({{ascendantAtlasImage='hd.png'},{ascendantPokemonAnimationCards={}},{providerId='ascendant_walksheets'}})do
 local p=pose();p.sprite={def=hd};local original=p.sprite
 assert(M.identify(p)==nil,'fixed legend bypassed selected HD source')
 M.prepare(game.overworld,{p});assert(p.sprite==original,'cached pixel animation overwrote HD')
end
M.update(game,.1,0);p=pose();M.prepare(game.overworld,{p});assert(p.sprite==native and M.status().active==0)
game.overworld.map={id='GEN2',def={generation=2}};M.update(game,.1,7);assert(M.status().active==0)
print('PASS world animation: update-only admission, authored frames, stable shadows, motion OFF, two metre Mewtwo, native position/2D and other owners retained')

local C=assert(loadfile(root..'/integrated/ascendant_pokemon_overworld/src/catalog.lua'))()
local cg={data={pokemon={MOLTRES={},MAGMAR={}}},overworld={map={id='KA_MOLTRES_VOLCANO'}}}
local boss={def={name='KA_MOLTRES_VOLCANO',sprite='SPRITE_BIRD'}}
assert(C.mapSpeciesFor(cg,boss)=='MOLTRES','volcano boss missing HD identity')
cg.overworld.map.id='PALLET_TOWN';assert(C.mapSpeciesFor(cg,boss)==nil,'wrong map adopted')
print('PASS exact volcano HD identity')
