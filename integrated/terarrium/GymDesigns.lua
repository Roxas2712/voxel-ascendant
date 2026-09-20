-- Exact arena mapping: no city/route or unrelated Johto-gym substitutions.
return function(read,generation)
 local names={PEWTER_GYM='Pewter',CERULEAN_GYM='Cerulean',VERMILION_GYM='Vermilion',
  CELADON_GYM='Celadon',FUCHSIA_GYM='Fuchsia',SAFFRON_GYM='Saffron',CINNABAR_GYM='Cinnabar',VIRIDIAN_GYM='Viridian'}
 -- Gen2 reuses some room IDs for different opponents: their future designs
 -- must not inherit the Gen1 Elite Four/Champion interiors.
 if generation~=2 then
  names.ROCKET_HIDEOUT_B4F='RocketHideout2'
  for floor=2,7 do names['POKEMON_TOWER_'..floor..'F']='PokemonTower'end
  names.LORELEIS_ROOM='Lorelei';names.BRUNOS_ROOM='Bruno'
  names.AGATHAS_ROOM='Agatha';names.LANCES_ROOM='Lance';names.CHAMPIONS_ROOM='Champion'
 end
 local loaded={}

 return function(id)
  local name=names[id];if not name then return end
  if not loaded[id]then
   local path='gyms/'..name..'Terrarium.lua'
   local design=assert((loadstring or load)(assert(read(path)), '@terarrium/'..path))()
   assert(design.appliesTo(id) and type(design.build)=='function' and type(design.button)=='function' and type(design.revision)=='string','Invalid gym design: '..id)
   if name=='PokemonTower'then design={build=design.build,appliesTo=design.appliesTo,button=function()end,revision=design.revision..'-no-ghost'}end
   loaded[id]=design
  end
  return loaded[id]
 end
end
