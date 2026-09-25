-- Exact arena mapping: no city/route or unrelated Johto-gym substitutions.
return function(read,generation,silphOccupied)
 local names={PEWTER_GYM='Pewter',CERULEAN_GYM='Cerulean',VERMILION_GYM='Vermilion',
  CELADON_GYM='Celadon',FUCHSIA_GYM='Fuchsia',SAFFRON_GYM='Saffron',CINNABAR_GYM='Cinnabar',VIRIDIAN_GYM='Viridian'}
 -- Gen2 reuses some room IDs for different opponents: their future designs
 -- must not inherit the Gen1 Elite Four/Champion interiors.
 if generation~=2 then
  names.ROCKET_HIDEOUT_B4F='RocketHideout2'
  for floor=2,7 do names['POKEMON_TOWER_'..floor..'F']='PokemonTower'end
  names.LORELEIS_ROOM='Lorelei';names.BRUNOS_ROOM='Bruno'
  names.AGATHAS_ROOM='Agatha';names.LANCES_ROOM='Lance';names.CHAMPIONS_ROOM='Champion'
  names.SS_ANNE_BOW='SSAnne';names.FIGHTING_DOJO='FightingDojo'
  names.POWER_PLANT='PowerPlant';names.VIRIDIAN_FOREST='ViridianForest'
  names.DIGLETTS_CAVE='DiglettsCave';names.OAKS_LAB='OakLab';names.ROUTE_17='Route17'
  for floor=1,3 do
   names['ROCKET_HIDEOUT_B'..floor..'F']='RocketHideout1'
   names['VICTORY_ROAD_'..floor..'F']='ChampionRoad'
   names['POKEMON_MANSION_'..floor..'F']='PokemonMansion'
  end
  names.POKEMON_MANSION_B1F='PokemonMansion'
  for floor=1,11 do names['SILPH_CO_'..floor..'F']='SilphCompany'end
  for _,area in ipairs({'CENTER','EAST','NORTH','WEST'})do names['SAFARI_ZONE_'..area]='SafariZone'end
  for _,floor in ipairs({'1F','B1F','B2F'})do names['MT_MOON_'..floor]='MtMoon'end
  for _,floor in ipairs({'1F','2F','B1F'})do names['CERULEAN_CAVE_'..floor]='CeruleanCave'end
  for _,floor in ipairs({'1F','B1F','B2F','B3F','B4F'})do names['SEAFOAM_ISLANDS_'..floor]='SeafoamIslands'end
 end
 -- Location art uses the authored-geometry path without becoming a gym.
 local families={SSAnne='ship',FightingDojo='gym',PowerPlant='industrial',ViridianForest='forest',
  RocketHideout1='industrial',SilphCompany='industrial',PokemonMansion='interior',SafariZone='safari',
  MtMoon='cave',DiglettsCave='cave',CeruleanCave='cave',OakLab='interior',ChampionRoad='cave',
  Route17='coast',SeafoamIslands='ice'}
 local loaded={}

 return function(id)
  local name=names[id];if not name then return end
  -- Evaluate live story state before the module cache on every selection.
  -- Missing state is not evidence that the Rocket occupation is active.
  if name=='SilphCompany'and(not silphOccupied or silphOccupied()~=true)then return end
  if not loaded[id]then
   local path='gyms/'..name..'Terrarium.lua'
   local design=assert((loadstring or load)(assert(read(path)), '@terarrium/'..path))()
   assert(design.appliesTo(id) and type(design.build)=='function' and type(design.button)=='function' and type(design.revision)=='string','Invalid gym design: '..id)
   if name=='PokemonTower'then design={build=design.build,appliesTo=design.appliesTo,button=function()end,revision=design.revision..'-no-ghost'}end
   if families[name]then design={build=design.build,appliesTo=design.appliesTo,button=design.button,
    revision=design.revision,family=families[name]}end
   loaded[id]=design
  end
  return loaded[id]
 end
end
