local root=assert(arg[1], 'package root required')..'/integrated/ascendant_pokemon_overworld/'
local function read(p)local f=assert(io.open(root..p,'rb'));local s=f:read('*a');f:close();return s end
local Cat=assert(loadfile(root..'src/catalog.lua'))()
local game={data={pokemon={CHANSEY={dex=113},VOLTORB={dex=100},KANGASKHAN={dex=115},SLOWPOKE={dex=79},LAPRAS={dex=131},SEEL={dex=86},NIDORAN_M={dex=32},MAGIKARP={dex=129}}}}
for _,s in ipairs{{'CHANSEY','FAIRY'},{'VOLTORB','POKE_BALL'},{'KANGASKHAN','MONSTER'},{'SLOWPOKE','MONSTER'},{'LAPRAS','SEEL'},{'NIDORAN_M','MONSTER'}}do
 assert(Cat.mapSpeciesFor(game,{def={name='FUCHSIACITY_'..s[1],sprite='SPRITE_'..s[2]}})==s[1])
end
assert(not Cat.mapSpeciesFor(game,{def={name='FUCHSIACITY_FOSSIL',sprite='SPRITE_FOSSIL'}}))
assert(not Cat.mapSpeciesFor(game,{def={name='MTMOONPOKECENTER_MAGIKARP_SALESMAN',sprite='SPRITE_MIDDLE_AGED_MAN'}}))
assert(not Cat.mapSpeciesFor(game,{def={name='ROUTE_VOLTORB',sprite='SPRITE_POKE_BALL',item='POTION'}}))
assert(not Cat.mapSpeciesFor(game,{def={name='OTHER_UNKNOWN',sprite='SPRITE_MONSTER'}}))
local mod={path=root,read=function(_,p)return read(p)end}
local N=assert(loadfile(root..'src/npc_catalog.lua'))().public(mod)
local W=assert(loadfile(root..'src/walking_sprites.lua'))()
local w=W.new{mod=mod,generation=1,compat={},npcCatalog=N}
local count,young=0,0
for _,row in ipairs(N.inventory(1))do
 local e={id=row.scriptOrText,def={sprite=row.sprite,x=row.x,y=row.y}}
 local found=w:_rowFor(row.map,e);assert(found,'missing map row '..row.map)
 local atlas=w:_atlasFor(row.map,e,found)
 assert(atlas,'unreachable HD row: '..row.map..' '..row.scriptOrText)
 assert(io.open(root..atlas,'rb')):close()
 assert(io.open(root..w.runtimeByAtlas[atlas],'rb')):close()
 if atlas:find('youngster-gen1-bald',1,true)then young=young+1 end
 count=count+1
end
assert(young==34,'expected 34 migrated Youngster rows')
print('PASS all '..count..' Gen1 human catalog rows resolve bundled HD atlases/native strips; '..young..' corrected Youngster mappings')
print('PASS exact zoo identities, Lapras vs Seel, Nidoran suffix, fossil/item/human/unknown exclusions')
