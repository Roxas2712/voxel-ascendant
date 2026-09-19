local roots=assert(loadfile('lib/Gen1Rooftops.lua'))()
local settings={new=function()return {get=function()return 'clear'end}end}
local W=assert(loadfile('lib/Weather.lua'))({require=function(n)
 if n=='ModSetting'then return settings end
 if n=='Gen1Rooftops'then return roots end
 return {}
end})
local G={FACE_CORNERS={
 {{0,0,0},{1,0,0},{1,1,0},{0,1,0}},{{0,0,1},{1,0,1},{1,1,1},{0,1,1}},
 {{0,1,0},{1,1,0},{1,1,1},{0,1,1}},{{0,0,0},{1,0,0},{1,0,1},{0,0,1}},
 {{0,0,0},{0,0,1},{0,1,1},{0,1,0}},{{1,0,0},{1,0,1},{1,1,1},{1,1,0}}}}
local B=assert(loadfile('lib/HorizonBuildings.lua'))()
local M=assert(loadfile('lib/RooftopPanorama.lua'))({require=function(n)
 if n=='VoxelItems'then return {setting={get=function()return false end}}elseif n=='Voxel3D'then return G elseif n=='OutdoorHorizon'then return {paletteSize=40} elseif n=='HorizonBuildings'then return B end
 error(n)
end})
local city={id='CELADON_CITY',def={tileset='OVERWORLD'}}
for _,spec in ipairs({{'CELADON_MART_ROOF','LOBBY',10,4},{'CELADON_MANSION_ROOF','MANSION',4,6}})do
 local map={id=spec[1],def={tileset=spec[2],width=spec[3],height=spec[4]}}
 assert(W.isOutdoor(map));assert(W.modeAt(map,'rain',0)=='rain')
 for clock=0,15360,240 do assert(W.modeAt(map,'auto',clock)==W.modeAt(city,'auto',clock),'roof rerolls regional weather')end
 local entry={map=map,w=spec[3]*32,h=spec[4]*32}
 local groups=M.geometry(entry)
 for _,g in ipairs(groups)do assert(g.name=='frame','baked sky retained in rooftop geometry')end
 local World=assert(loadfile('lib/RooftopWorld.lua'))({require=function(n)
  if n=='WorldPlacement'then return assert(loadfile('lib/WorldPlacement.lua'))()end
  error(n)
 end})
 assert(World.groundColor(-159,{leaf=1,stone=2,oak=3})==1,'Gen1 meadow became stone')
 assert(World.groundColor(-161,{leaf=1,stone=2,oak=3})==1)
 assert(World.groundColor(-163,{leaf=1,stone=2,oak=3})==2)
 assert(World.groundColor(-130,{leaf=1,stone=2,oak=3})==3)
 local wanted=spec[1]=='CELADON_MART_ROOF'and 'celadon_mart'or 'celadon_mansion'
 local anchor=World.anchor(entry,{{kind='real_building',tx=12,ty=8}},
  {real_building={template=wanted,frameW=128,depth=96,offsetY=-134}})
 assert(anchor.x+12*8+64==entry.w/2 and anchor.z+8*8+48==entry.h/2)
 assert(anchor.y==-134 and anchor.kind=='real_building')
 assert(not World.anchor(entry,{},{}),'missing source building guessed')
 local defs={
  CELADON_CITY={width=25,height=18,tileset='OVERWORLD',connections={east={map='ROUTE_7',offset=4}}},
  ROUTE_7={width=10,height=9,tileset='OVERWORLD',connections={east={map='SAFFRON_CITY',offset=-4}}},
  SAFFRON_CITY={width=20,height=18,tileset='OVERWORLD',connections={east={map='ROUTE_8',offset=4}}},
  ROUTE_8={width=30,height=9,tileset='OVERWORLD',connections={east={map='LAVENDER_TOWN',offset=-1}}},
  LAVENDER_TOWN={width=10,height=9,tileset='OVERWORLD'},
  FAKE_CITY={width=10,height=9,tileset='OVERWORLD'},
 }
 local positions={};for _,m in ipairs(World.maps(entry,defs))do positions[m.id]=m end
 assert(not positions.FAKE_CITY,'unconnected region added')
 assert(positions.ROUTE_7.x==800 and positions.ROUTE_7.z==128)
 assert(positions.SAFFRON_CITY.x==1120 and positions.SAFFRON_CITY.z==0)
 assert(positions.LAVENDER_TOWN.x==2720 and positions.LAVENDER_TOWN.z==96)
 map.def.width=map.def.width+1;assert(not W.isOutdoor(map),'custom room admitted')
 map.def.width=spec[3];map.def.generation=2;assert(not W.isOutdoor(map),'Gen2 same ID admitted')
 map.def.generation=1;map.id='CELADON_MANSION_3F';assert(W.modeAt(map,'rain',0)=='clear','rain leaked indoors')
end
print('PASS rooftop weather continuity, exact native roof guards, source-building anchors, connected source-world coordinates and no painted sky')

-- Large slabs must be clipped, or their near mesh hides the baked forest.
local Cache=assert(loadfile('lib/RooftopCache.lua'))({})
local entry={w=320,h=128}
for _,b in ipairs({{-3200,-1400,-3200,7200,1392,7200,12,false},
 {-400,0,-800,2000,5,2200,14,true},{0,0,0,12,8,12,1,false},
 {640,0,544,12,8,12,1,false},{-800,0,0,480,8,12,1,false}})do
 local volume,parts=0,{}
 Cache.partition(entry,b,function(p,near)
  assert(p[4]>0 and p[5]>0 and p[6]>0)
  assert(p[2]==b[2]and p[5]==b[5]and p[7]==b[7]and p[8]==b[8])
  assert(p[1]>=b[1]and p[1]+p[4]<=b[1]+b[4]and p[3]>=b[3]and p[3]+p[6]<=b[3]+b[6])
  if near then assert(p[1]>=-320 and p[1]+p[4]<=640 and p[3]>=-416 and p[3]+p[6]<=544)
  else assert(p[1]+p[4]<=-320 or p[1]>=640 or p[3]+p[6]<=-416 or p[3]>=544)end
  for _,old in ipairs(parts)do
   assert(p[1]>=old[1]+old[4]or p[1]+p[4]<=old[1]or p[3]>=old[3]+old[6]or p[3]+p[6]<=old[3],'overlapping pieces')
  end
  volume=volume+p[4]*p[5]*p[6];parts[#parts+1]=p
 end)
 assert(volume==b[4]*b[5]*b[6],'partition loses terrain')
end
print('PASS near/far clipping, conserved volume, nonoverlap and preserved materials')

local contracts=assert(loadfile('data/rooftop_terraces.lua'))()
local Terrace=assert(loadfile('lib/Gen1RoofTerrace.lua'))({data=function()return contracts end,require=function()return roots end})
local colors=setmetatable({},{__index=function()return 16 end});local Props={models={},decorColors=colors};local Furniture={patterns={}}
Terrace.register(Props,Furniture)
for _,p in ipairs(Furniture.patterns)do
 local mart=p.kind=='celadon_mart_terrace';local id=mart and 'CELADON_MART_ROOF'or 'CELADON_MANSION_ROOF'
 local blocks={};for i,v in ipairs(contracts[id].blocks)do blocks[i]=v end
 local warps=mart and {{x=15,y=2,destMap='CELADON_MART_5F'}}or {{x=6,y=1,destMap='CELADON_MANSION_3F'},
  {x=2,y=1,destMap='CELADON_MANSION_3F'},{x=2,y=7,destMap='CELADON_MANSION_ROOF_HOUSE'}}
 local map={id=id,def={width=mart and 10 or 4,height=mart and 4 or 6,tileset=mart and 'LOBBY'or 'MANSION',blocks=blocks,warps=warps}}
 function map:tileAt(x,y)return contracts[id].tiles[y+1][x+1]end
 assert(Terrace.matches(map))
 local m=Props.models[p.kind];assert(m.replacesGround and m.actorSurface and m.support==0)
 for _,b in ipairs(m.boxes)do assert(b[4]>0 and b[5]>0 and b[6]>0 and b[7]>0)end
 -- No floor sheet or wall closes the centre of a stair opening above the treads.
 for i,warp in ipairs(warps)do
  local x,z=warp.x*16+8,warp.y*16+8
  for _,b in ipairs(m.boxes)do
   if x>b[1] and x<b[1]+b[4] and z>b[3] and z<b[3]+b[6]then
    assert(b[2]+b[5]<=0 or b[2]>=23,'solid geometry closes original warp approach')
   end
  end
 end
 blocks[1]=blocks[1]+1;assert(not Terrace.matches(map));blocks[1]=blocks[1]-1
 warps[1].destMap='CUSTOM';assert(not Terrace.matches(map));warps[1].destMap=mart and 'CELADON_MART_5F'or 'CELADON_MANSION_3F'
 map.def.generation=2;assert(not Terrace.matches(map));map.def.generation=1
 map.tileAt=function()return -99 end;assert(not Terrace.matches(map),'edited tiles admitted')
end
print('PASS exact terrace contracts, edited art/layout guards and open native stair/door approaches')
