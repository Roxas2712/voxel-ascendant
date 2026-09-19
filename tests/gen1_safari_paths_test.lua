local settings={new=function(_,_,values)return {value=values[1],get=function(s)return s.value end}end}
local O=assert(loadfile('lib/Gen1OutdoorScenery.lua'))({require=function()return settings end})
local signs=assert(loadfile('lib/Gen1VoxelSigns.lua'))({require=function()return settings end})
local language='en';signs.language=function()return language end
local G=assert(loadfile('lib/Gen1SafariGates.lua'))({require=function(n)
 if n=='Gen1VoxelSigns'then return signs end;if n=='Gen1OutdoorScenery'then return O end;error(n)
end})
local C={looseRock1=1,oldTimber=2,oldBoard=3,oldBeam=4}
local P={models={},decorColors=C}
for _,side in ipairs({'north','south','east','west'})do
 local horiz=side=='north'or side=='south'
 local x,y=horiz and 4 or (side=='west'and 0 or 19),horiz and (side=='north'and 0 or 19)or 4
 local dx,dy=horiz and 1 or 0,horiz and 0 or 1
 local d={tileset='FOREST',width=10,height=10,warps={
 {x=x,y=y,destMap='SAFARI_ZONE_NORTH'},
 {x=x+dx,y=y+dy,destMap='SAFARI_ZONE_NORTH'},
 {x=12,y=12,destMap='SAFARI_ZONE_NORTH_REST_HOUSE'}}}
 local map={id='SAFARI_ZONE_CENTER',def=d,isWalkableCell=function(_,cx,cy)
  return (cx==x and cy==y)or(cx==x+dx and cy==y+dy)
 end}
 local groups=G.groups(map);assert(#groups==1 and groups[1].side==side)
 local props=G.find(P,map);assert(#props==1 and props[1].keepTerrain and props[1].enabled())
 local a=P.models[props[1].kind];assert(a.label=='NORTH')
 for _,b in ipairs(a.boxes)do
  if b[2]<28 then
   local start,extent=horiz and b[1]or b[3],horiz and b[4]or b[6]
   assert(start+extent<=0 or start>=32,'post blocks native opening')
  end
 end
 language='de';assert(P.models[G.find(P,map)[1].kind].label=='NORD');language='en'
 local originalWalk=map.isWalkableCell
 map.isWalkableCell=function(_,cx,cy)
  local along=horiz and cx or cy;local across=horiz and cy or cx
  return across==(horiz and y or x) and along>=(horiz and x or y)-1 and along<=(horiz and x or y)+2
 end
 local wide=G.find(P,map);assert(wide[1].safariGate.width==64)
 for _,b in ipairs(P.models[wide[1].kind].boxes)do if b[2]<28 then
  local start,extent=horiz and b[1]or b[3],horiz and b[4]or b[6]
  assert(start+extent<=0 or start>=64,'post intrudes on walking shoulder')
 end end
 map.isWalkableCell=function()return true end;assert(#G.groups(map)==0,'unbounded custom opening guessed')
 map.isWalkableCell=originalWalk
 O.stone.value=false;assert(not props[1].enabled());O.stone.value=true
 map.def.generation=2;assert(#G.groups(map)==0);map.def.generation=1
 map.id='VIRIDIAN_FOREST';assert(#G.groups(map)==0);map.id='SAFARI_ZONE_CENTER'
 d.warps[2]=nil;assert(#G.groups(map)==0,'single custom warp acquired wide gate')
end
local map={id='SAFARI_ZONE_CENTER',def={tileset='FOREST'},warpAtCell=function()return {} end,
 tileAt=function(_,x)return x%2==0 and 57 or 95 end}
assert(O.material(map,true,57,2,3)==-171 and O.material(map,true,95,3,3)==-171)
map.tileAt=function()return 48 end
assert(not O.material(map,true,57,2,3)and not O.material(map,true,95,3,3),'partial pair replaced')
for t=80,83 do assert(O.material(map,true,t,2,2)==-171)end
map.warpAtCell=function()return nil end
for t=80,83 do assert(not O.material(map,true,t,2,2))end
for _,id in ipairs({'SAFARI_ZONE_CENTER','SAFARI_ZONE_EAST','SAFARI_ZONE_NORTH','SAFARI_ZONE_WEST'})do
 map.id=id;assert(O.material(map,true,32,2,2)==-161);assert(not O.material(map,true,20,2,2))
end
map.id='VIRIDIAN_FOREST';assert(not O.material(map,true,57,2,2))
assert(not O.material(map,false,57,2,2))
print('PASS Safari gate clearances in four directions, exact warp pairing, language, native/Gen2 exclusions, ground pair/warp/grass/water guards')
