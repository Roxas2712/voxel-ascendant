local root=assert(arg[1]);local settings={get=function()return true end}
local mods={VoxelItems={setting=settings},Gen1OutdoorScenery={trees=settings,stone=settings}}
mods.KascLegendAtmosphere=assert(loadfile(root..'/lib/KascLegendAtmosphere.lua'))()
local V={require=function(n)return assert(mods[n],n)end}
local M=assert(loadfile(root..'/lib/KascLegendScenery.lua'))(V)
local colors={};for i,k in ipairs({'walnut','oldBeam','leafDark','leaf','leafLight','navy','looseRock4','silphGlass','slate','silver','dustyGlass'})do colors[k]=i end
local P={models={},decorColors=colors};M.register(P)
for key,m in pairs(P.models)do
 assert(#m.boxes<=33,'unbounded model '..key)
 for _,b in ipairs(m.boxes)do
  assert(b[1]>=0 and b[3]>=0 and b[1]+b[4]<=16.001 and b[3]+b[6]<=16.001,'overhang into adjacent path')
  assert(b[4]>0 and b[5]>0 and b[6]>0 and b[7],'invalid model box')
 end
end
for _,row in ipairs({{'KA_HEVO_GROUDON_CHAMBER','CAVERN',125},{'KA_HEVO_BLUE_TIDAL_DEPTHS','CAVERN',125},
 {'KA_HEVO_BLUE_GLACIER_MAZE','CAVERN',125},{'KA_HEVO_GREEN_MIST','FOREST',2}})do
 local d={tileset=row[2],width=8,height=4,blocks={},objects={{x=2,y=1}},signs={{x=10,y=1}}}
 for i=1,32 do d.blocks[i]=row[3]end
 local map={id=row[1],def=d}
 function map:isWalkableCell(x,y)return y==2 end
 function map:isWaterCell(x,y)return x==8 and y==1 end
 function map:warpAtCell(x,y)return x==6 and y==1 end
 local snap=table.concat(d.blocks,',');local props=M.find(P,map,function(x,y)return x==26 and y==2 end)
 assert(#props>0)
 for _,p in ipairs(props)do
  local x,y=p.tx/2,p.ty/2
  assert(not map:isWalkableCell(x,y)and not map:isWaterCell(x,y)and not map:warpAtCell(x,y))
  assert(not(x==13 and y==1),'existing prop overwritten')
  for _,list in ipairs({d.objects,d.signs})do for _,point in ipairs(list)do
   assert(math.abs(point.x-x)>1 or math.abs(point.y-y)>1,'interaction approach covered')
  end end
 end
 assert(snap==table.concat(d.blocks,','),'native geometry mutated')
 d.generation=2;assert(#M.find(P,map)==0);d.generation=nil;d.tileset='PRIVATE';assert(#M.find(P,map)==0)
end
print('PASS legend formations: bounded geometry, no path/water/warp/interaction overlap, exact maps and original blocks')
