local root=assert(arg[1])
local Options=assert(loadfile(root..'/lib/OverworldPokemonOptions.lua'))()
for _,gen in ipairs({'lib','gen2/lib'})do
  local values={}
  local game={save={options={}},mods={modOptions={VOXEL_ASCENDANT=values}}}
  local calls,people=0,0
  local mod={id='VOXEL_ASCENDANT',options={get=function(_,k)return values[k]end},exports={
    pokemonHdContent={ready=function()return true end},
    overworldPokemon={pokemonWorldSprites={refresh=function(g)assert(g==game);calls=calls+1 end},
      walkingSprites={refresh=function()people=people+1 end}}}}
  local Setting=assert(loadfile(root..'/'..gen..'/ModSetting.lua'))({mod=mod})
  for _,key in ipairs({'apo_pokemon_model_source','apo_follower_sprite_source',
      'apo_grass_pokemon_sprite_source','apo_city_pokemon_sprite_source','apo_wilds_town_pokemon_sprite_source'})do
    local choices=key=='apo_pokemon_model_source' and {'auto','stadium_only','go_only','sprite_only'}
      or {'hd','stadium2','full_hd','pokemmo'}
    local s=Setting.new(key,key,choices,choices,choices[1])
    Options.decorateSetting(mod,s);Options.decorateSetting(mod,s)
    for i=1,12 do
      local before=calls;s:row().step(game,i<=6 and 1 or -1)
      assert(calls==before+1,'source change must refresh exactly once: '..key)
      assert(values[key]==s:get(),'saved source differs from menu')
    end
  end
  assert(people==0,'Pokemon source refreshed human identity')
end
print('PASS both generations: all 5 source rows refresh immediately in both directions')
