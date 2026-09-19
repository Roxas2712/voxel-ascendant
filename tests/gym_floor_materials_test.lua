-- Floor art must not replace teleport pads, quiz tiles or native maze data.
local root=assert(arg[1])
local engine=assert(os.getenv('GEN1RECOMP_ROOT'))
local maps=dofile(engine..'/red/data/generated/maps.lua')
local enabled=true
local rooms=dofile(root..'/lib/Gen1InteriorPanoramas.lua')
local M=assert(loadfile(root..'/lib/Gen1InteriorFloors.lua'))({require=function(name)
  if name=='ModSetting' then return {new=function()return {get=function()return enabled end}end} end
  assert(name=='Gen1InteriorPanoramas');return rooms
end})
local wanted={SAFFRON_GYM=8,FUCHSIA_GYM=2,CINNABAR_GYM=6}
for id,family in pairs(wanted)do
  local def=maps[id];local map={id=id,def=def}
  local blocks=table.concat(def.blocks,',');local warps=def.warps
  assert(M.profile(map)==family)
  for tile=0,255 do
    local allowed=def.tileset=='FACILITY' and tile==1
      or def.tileset=='GYM' and ({[17]=true,[9]=true,[10]=true,[25]=true,[26]=true})[tile]
    assert(M.material(map,family,tile,false)==(allowed and -128-family or nil),id..' tile '..tile)
  end
  assert(M.material(map,family,1,true)==-128-family)
  for key,value in pairs({generation=2,width=99,height=99,tileset='HOUSE',connections={north={}}})do
    local d={};for k,v in pairs(def)do d[k]=v end;d[key]=value
    assert(M.profile({id=id,def=d})==nil,'unsupported gym '..key)
  end
  enabled=false;assert(M.profile(map)==nil);enabled=true
  assert(blocks==table.concat(def.blocks,',') and warps==def.warps)
end
for _,id in ipairs({'PEWTER_GYM','CERULEAN_GYM','VERMILION_GYM','CELADON_GYM','VIRIDIAN_GYM'})do
  if maps[id] then assert(M.profile({id=id,def=maps[id]})==nil)end
end
print('PASS_GYM_FLOOR_MATERIALS: three native arenas, puzzle atlas preserved, scope and off switch')
