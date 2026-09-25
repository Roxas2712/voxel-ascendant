package.loaded['src.pokemon.Stats']={isShiny=function(dvs)return dvs.shiny end}
for _,prefix in ipairs({'','gen2/'})do
 for _,metadata in ipairs({false,true})do
  local reads,stats=0,0;local present={['assets/crystal_fronts/normal/1.png']=true}
  local mod={path='pack',read=function(_,p)reads=reads+1;return present[p]and 'png'end}
  if metadata then mod.info=function(_,p)stats=stats+1;return present[p]and{type='file'}end end
  local fronts=assert(loadfile(prefix..'lib/Gen2CrystalFronts.lua'))({mod=mod})
  local data={pokemon={BULBASAUR={dex=1}}};local mon={species='BULBASAUR',dvs={shiny=true}}
  for i=1,600 do local r=assert(fronts.resolve(data,mon));assert(r.variant=='normal'and r.dex==1 and r.trueColor)end
  assert(reads+stats==2,'repeated shiny fallback reads the same files: '..(reads+stats))
  assert(not metadata or reads==0,'existence check reads PNG contents')
  assert(not fronts.resolve(data,{species='BULBASAUR',ascMegaForm=true}))
  assert(not fronts.resolve(data,0)and not fronts.resolve(data,1000))
  for i=1,60 do assert(not fronts.resolve(data,2))end
  assert(reads+stats==3,'missing normal image is checked twice or repeatedly')
  local r=fronts.resolve(data,1);r.path='changed';assert(fronts.resolve(data,1).path~='changed','mutable receipt escaped cache')
  present['assets/crystal_fronts/shiny/1.png']=true;fronts.invalidate()
  assert(fronts.resolve(data,mon).variant=='shiny','explicit reload did not discover image')
  print('PASS '..prefix..'Crystal lookup: bounded checks, shiny fallback, metadata/legacy, missing art, fresh receipts and reload')
 end
 local failed=true;local attempts=0
 local fronts=assert(loadfile(prefix..'lib/Gen2CrystalFronts.lua'))({mod={path='pack',
  info=function()error('metadata unsupported')end,
  read=function()attempts=attempts+1;if failed then error('transient read failure')end;return 'png'end}})
 assert(not fronts.resolve({},1));failed=false;assert(fronts.resolve({},1));assert(fronts.resolve({},1))
 assert(attempts==2,'transient failure was permanently cached or success was not cached')
end
