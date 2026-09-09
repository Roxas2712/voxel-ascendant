local root=assert(arg[1], 'package root required')..'/'
local O=assert(loadfile(root..'lib/OverworldPokemonOptions.lua'))()
local values={}
local refreshed=0
local mod={id='VOXEL_ASCENDANT',options={get=function(_,k)return values[k]end},exports={overworldPokemon={walkingSprites={refresh=function()refreshed=refreshed+1 end}}}}
local S=assert(loadfile(root..'lib/ModSetting.lua')){mod=mod}
local game={save={options={modOptions={VOXEL_ASCENDANT=values}}},mods={modOptions={VOXEL_ASCENDANT=values}},writeOptions=function()end}
local hd
for _,entry in ipairs(O.entries(mod,S))do if entry[1].key=='apo_hd_walking_sprites'then hd=entry[1]end end
assert(hd,'HD PEOPLE missing')
for _,master in ipairs{true,false}do
 for _,source in ipairs{'auto','stadium_only','go_first','go_only','sprite_only'}do
  for _,grid in ipairs{'off','characters','pokemon','both'}do
   for _,relief in ipairs{true,false}do
    values.apo_enabled=master;values.apo_pokemon_model_source=source
    values.apo_actor_voxel_grid=grid;values.apo_voxel_character_finish=relief
    assert(hd:allows(1) and hd:allows(2),'HD switch blocked by another option')
    hd:setIndex(1,game);assert(values.apo_hd_walking_sprites==false)
    hd:setIndex(2,game);assert(values.apo_hd_walking_sprites==true)
   end
  end
 end
end
assert(refreshed==160,'HD native-menu switch must refresh immediately')
assert(O.section('apo_hd_walking_sprites')=='pokemon')
print('PASS HD PEOPLE reachable without downloads across 80 master/model/grid/relief combinations; 160 immediate refreshes')
for _,name in ipairs{'overworld_pokemon_hybrid_test.lua','overworld_pokemon_rc32_options_test.lua'}do
 arg[1]=root:sub(1,-2)
 assert(loadfile(root..'tests/'..name))()
end
