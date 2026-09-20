local root=assert(arg[1]);local M=assert(loadfile(root..'/lib/KascLegendAtmosphere.lua'))()
for _,row in ipairs({{'KA_HEVO_GROUDON_CHAMBER','CAVERN','ember'},{'KA_HEVO_RED_LOWER','CAVERN','ember'}, {'KA_HEVO_KYOGRE_CHAMBER','CAVERN','tide'},{'KA_HEVO_BLUE_GLACIER_MAZE','CAVERN','frost'}, {'KA_HEVO_GREEN_MIST','FOREST','grove'}})do
 local map={id=row[1],def={tileset=row[2],generation=1}};local p=assert(M.profile(map));assert(p.kind==row[3]and p.density>0 and p.height>0)
 map.def.tileset='PRIVATE';assert(not M.profile(map));map.def.tileset=row[2];map.def.generation=2;assert(not M.profile(map))
end
for _,id in ipairs({'MT_MOON_1F','UNKNOWN','KA_HEVO_RED_NEW','KA_HOENN_DESERT_RUINS'})do assert(not M.profile({id=id,def={tileset='CAVERN'}}))end
print('PASS exact legend atmosphere contracts and native/private/Gen2 exclusions')

local floor={id='KA_HEVO_GROUDON_CHAMBER',def={tileset='CAVERN',width=2,height=1,blocks={25,21}},
 isWalkableCell=function()return true end,isWaterCell=function()return false end}
assert(M.material(floor,0,0)==-177)
assert(M.material(floor,4,0)==nil,'authored puzzle glyph must survive')
assert(M.material(floor,-1,0)==nil)
floor.id='KA_HEVO_KYOGRE_CHAMBER';assert(M.material(floor,0,0)==-180)
floor.id='KA_HEVO_BLUE_GLACIER_MAZE';assert(M.material(floor,0,0)==-181)
for _,block in ipairs({1,21,22,41,118,125})do floor.def.blocks[1]=block;assert(not M.material(floor,0,0),'special floor must survive')end
floor.def.blocks[1]=25;floor.isWaterCell=function()return true end;assert(not M.material(floor,0,0))
floor.isWaterCell=function()return false end;floor.warpAtCell=function()return {}end;assert(not M.material(floor,0,0))
print('PASS theme floors preserve water, puzzle marks, stairs, ice and warps')
