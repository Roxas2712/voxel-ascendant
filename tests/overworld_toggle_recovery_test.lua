local root=arg[1] or '.'
local Options=assert(loadfile(root..'/lib/OverworldPokemonOptions.lua'))()
local values={};local refreshed=0
local mod={id='VOXEL_ASCENDANT',options={get=function(_,k)return values[k]end},exports={
 pokemonHdContent={ready=function()return false end},
 overworldPokemon={pokemonWorldSprites={refresh=function()refreshed=refreshed+1 end}}}}
local Setting=assert(loadfile(root..'/lib/ModSetting.lua'))({mod=mod})
local game={save={options={modOptions={VOXEL_ASCENDANT=values}}},mods={modOptions={VOXEL_ASCENDANT=values}},writeOptions=function()end}
local wanted={apo_hd_pokemon_followers=true,apo_hd_pokemon_grass=true,apo_hd_pokemon_city=true,apo_hd_pokemon_wilds_towns=true}
for _,e in ipairs(Options.entries(mod,Setting))do
 local setting=e[1]
 if wanted[setting.key]then
  values[setting.key]=false
  setting:row().step(game,1)
  assert(values[setting.key]==true,'Cannot restore bundled Pokemon fallback: '..setting.key)
  setting:row().step(game,1)
  assert(values[setting.key]==false,'Cannot turn Pokemon fallback off: '..setting.key)
 end
end
assert(refreshed==8,'Every toggle must refresh visible Pokemon immediately')
print('PASS Pokemon context toggles restore bundled fallback without downloaded HD content')
