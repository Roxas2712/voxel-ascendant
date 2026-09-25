local root='integrated/ascendant_pokemon_overworld/'
local Runtime=assert(loadfile(root..'src/runtime.lua'))()
local Catalog=assert(loadfile(root..'src/catalog.lua'))()
local Follower=assert(loadfile(root..'src/follower_gen1.lua'))()
local path='assets/pokemmo-runtime/follower_025_male_normal_base.png'
local function fixture(existing,missing)
 local record=existing;local writes=0
 local content={get=function()return record end,register=function(_,_,v)record=v;writes=writes+1 end,patch=function(_,_,v)record=v;writes=writes+1 end}
 local mod={_vascIntegrated=true,path='mods/VASC',content={sprites=content}}
 function mod:info(p)if not missing and p==path then return {type='file',size=100}end end
 local runtime=setmetatable({mod=mod,catalog=Catalog},Runtime)
 return runtime,function()return record,writes end
end
for _,generation in ipairs({1,2})do
 local runtime,result=fixture();runtime.generation=generation
 assert(runtime:_registerSprite())
 local def,writes=result();assert(writes==1 and def.id=='SPRITE_PIKACHU' and def.image=='mods/VASC/'..path)
 assert(def.frames==6 and def.walker and def.trueColor)
end
local existing={id='SPRITE_PIKACHU',image='native/pikachu.png'}
local owned,ownedResult=fixture(existing,false)
assert(owned:_registerSprite());local original,changes=ownedResult();assert(original==existing and changes==0)
local runtime,result=fixture(existing,true)
assert(runtime:_registerSprite());local def,writes=result();assert(def==existing and writes==0)
runtime,result=fixture(nil,true)
local ok,why=runtime:_registerSprite();assert(not ok and why=='follower_bootstrap_sheet_unavailable')
assert(result()==nil)
-- A download-free Red/Blue installation still owns a usable follower. The
-- cartridge's generic Pokemon sheet is reused without recolouring or claiming
-- a species-specific DLC image, and the original source record stays intact.
local native={id='SPRITE_MONSTER',image='assets/generated/sprites/monster.png',frames=6,walker=true}
local registered
local mod={_vascIntegrated=true,path='mods/VASC',info=function()end,
 content={sprites={get=function(_,id)if id=='SPRITE_MONSTER'then return native end end,
 register=function(_,id,record)assert(id=='SPRITE_PIKACHU');registered=record end}}}
local rt=setmetatable({mod=mod,catalog=Catalog},Runtime)
assert(rt:_registerSprite());assert(registered and registered~=native and registered.ascendantNativeFollowerFallback)
assert(registered.image==native.image and registered.frames==native.frames and not registered.trueColor)
local game={data={sprites={SPRITE_PIKACHU=registered},pokemon={BULBASAUR={dex=1},PIKACHU={dex=25}}}}
for _,species in ipairs({'BULBASAUR','PIKACHU'})do
 local def,image,dex=rt:configure(game,{}, {species=species,hp=10})
 assert(def~=registered and image==native.image and def.pokemonSpecies==species)
 assert(dex==game.data.pokemon[species].dex and def.frames==6 and not def.trueColor)
end
assert(native.id=='SPRITE_MONSTER' and not native.ascendantNativeFollowerFallback and not native.pokemonSpecies)
-- A temporarily absent record during a data reload must never reach NPC.new.
local calls=0;local previous=package.loaded['src.world.NPC']
package.loaded['src.world.NPC']={new=function()calls=calls+1;return {}end}
local controller=Follower.new(function()return true end)
local world={map={id='TEST',inBounds=function()return true end,isWalkableCell=function()return true end},player={cellX=2,cellY=2,facing='down'},npcs={},entities={}}
controller.onMapEntered({data={sprites={}}},world);controller.update({data={sprites={}}},world);assert(calls==0 and #world.npcs==0)
controller.onMapEntered({data={sprites={SPRITE_PIKACHU=existing}}},world);assert(calls==1 and #world.npcs==1)
package.loaded['src.world.NPC']=previous
print('PASS: standalone bootstrap in both generations; missing art/record guarded; existing owner retained; later spawn recovers')
