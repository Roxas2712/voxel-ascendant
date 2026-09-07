local root=assert(arg[1])
local Options=assert(loadfile(root..'/lib/OverworldPokemonOptions.lua'))()
for _,gen in ipairs({'lib','gen2/lib'})do
  local values={apo_hd_walking_sprites=true}
  local calls=0
  local game={save={options={}},mods={modOptions={VOXEL_ASCENDANT=values}}}
  local mod={id='VOXEL_ASCENDANT',options={get=function(_,k)return values[k]end},exports={
    overworldPokemon={walkingSprites={refresh=function(g)
      assert(g==game);calls=calls+1
      assert(values.apo_hd_walking_sprites==(calls%2==0))
    end}}}}
  local Setting=assert(loadfile(root..'/'..gen..'/ModSetting.lua'))({mod=mod})
  local s=Setting.new('apo_hd_walking_sprites','HD PEOPLE',{false,true},{'OFF','ON'},true)
  Options.decorateSetting(mod,s);Options.decorateSetting(mod,s)
  s:row().step(game,1);assert(calls==1 and values.apo_hd_walking_sprites==false)
  s:row().step(game,1);assert(calls==2 and values.apo_hd_walking_sprites==true)
end
print('PASS HD PEOPLE: both real ModSetting rows refresh immediately and decoration is idempotent')
