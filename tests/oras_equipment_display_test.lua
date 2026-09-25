-- Presentation must read KASC's owned values, not species guesses; immutable
-- PC snapshots must retain their resolved values without a second owner read.
for _,name in ipairs({'pokemon.Party','render.Assets','render.Font','render.PaletteFX','pokemon.Sprites','pokemon.Stats','inventory.ItemEffects','battle.TypeChart'})do
 package.loaded['src.'..name]={}
end
local reads=0
local equipment={read=function(_,game,mon)
 reads=reads+1
 if mon.unknown then return nil,true end
 if mon.standalone then return nil,false end
 return {isEgg=false,ability={name='Chlorophyll'},item={name='Leftovers'}},true
end}
local P=assert(loadfile('lib/OrasPartyPresentation.lua'))({mod={},require=function(name)
 if name=='PokemonEquipmentView'then return equipment end
 return {}
end})
local game={data={pokemon={BULBASAUR={ability='WRONG'}},items={BERRY={name='Berry'}}}}
local mon={species='BULBASAUR',ability='STALE',item='STALE'}
assert(P.abilityName(game,mon)=='Chlorophyll' and P.itemName(game,mon)=='Leftovers')
mon.unknown=true
assert(P.abilityName(game,mon)=='---' and P.itemName(game,mon)=='---','unknown owner fell back to guesses')
mon.unknown=nil;mon.standalone=true;mon.ability='OVERGROW';mon.item='BERRY'
assert(P.abilityName(game,mon)=='OVERGROW' and P.itemName(game,mon)=='Berry')
local prior=reads;mon.isEgg=true
assert(P.abilityName(game,mon)=='---' and P.itemName(game,mon)=='---' and reads==prior,'egg leaked metadata')
local model={surface='pc_box',surfaceData={currentBox=1},focus={zone='box',slot=1},zones={box={entries={{slot=1,pokemon={species='BULBASAUR',ability='Overgrow',item='Leftovers'}}}},party={entries={}}}}
local screen=assert(P.hostStorageScreen(model,{}));local selected=screen.game.save.boxes[1][1]
prior=reads
assert(P.abilityName(screen.game,selected)=='Overgrow' and P.itemName(screen.game,selected)=='Leftovers')
assert(reads==prior,'immutable descriptor reread live owner')
model.zones.box.entries[1].pokemon.ability=nil;model.zones.box.entries[1].pokemon.item=nil
screen=P.hostStorageScreen(model,{});selected=screen.game.save.boxes[1][1]
assert(P.abilityName(screen.game,selected)=='---' and P.itemName(screen.game,selected)=='---')
print('PASS owned equipment, unknown/none, standalone, eggs and immutable PC descriptors')
