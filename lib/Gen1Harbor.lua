-- Native MS Anne presentation. Never writes story flags, blocks or collision.
local V=...
local H={}
function H.kind(map)
 local d=map and map.def
 if not d or d.generation==2 or (next(d.connections or{}) and map.id=='VERMILION_DOCK') then return nil end
 local city=map.id=='VERMILION_CITY'and d.tileset=='OVERWORLD'and d.width==20 and d.height==18
 local dock=map.id=='VERMILION_DOCK'and d.tileset=='SHIP_PORT'and d.width==14 and d.height==6
 if not(city or dock)then return nil end
 for _,w in ipairs(d.warps or{})do
  if city and w.x==18 and w.y==31 and w.destMap=='VERMILION_DOCK'then return 'city'end
  if dock and w.x==14 and w.y==2 and w.destMap=='SS_ANNE_1F'then return 'dock'end
 end
end
function H.quayAt(map,x,y)
 return H.kind(map)=='city'and ((y==62 and x>=2 and x<=72)
  or (y>=54 and y<62 and (x==32 or x==34 or x==40 or x==42)))
end
function H.shipState(map,game)
 local kind=H.kind(map);if not kind then return nil end
 local ow=game and game.overworld
 local sa=ow and ow.map==map and ow.shipAnim
 if kind=='dock' then
  if sa then return not sa.gone,tonumber(sa.off)or 0,true end
  -- The departure flag is set before the horn/wait; retain the ship while
  -- its native hull still exists. During sailing, only shipAnim owns it.
  return type(map.tileAt)=='function'and map:tileAt(22,6)==2,0,false
 end
 return not(game and game.save and game.save.flags and game.save.flags.EVENT_SS_ANNE_LEFT==true),0,false
end
function H.models(P)
 if P.models.ss_anne_liner then return end
 local C=P.decorColors
 local navy,white,red,wood,metal,glass=C.navy or 16,14,C.clay or 1,C.oak or 4,C.silver or 4,8
 local function make(name,w,d)
  local m={boxes={},frameW=w,frameH=d+16,depth=d,offsetY=-16};P.models[name]=m
  return function(x,y,z,bw,bh,bd,c)m.boxes[#m.boxes+1]={x,y,z,bw,bh,bd,c}end
 end
 local b=make('ss_anne_liner',320,112)
 -- Stepped bow/stern, dark waterline, white passenger decks and two funnels.
 for x=0,304,16 do
  local endDistance=math.min(x+8,312-x)
  local width=16+math.floor(96*math.min(1,endDistance/64))
  local z=(112-width)/2
  b(x,-5,z+10,16,7,width-20,red)
  b(x,2,z+4,16,13,width-8,navy)
  b(x,15,z,16,4,width,white)
  b(x,19,z+2,16,1,width-4,wood)
 end
 b(32,15,24,256,4,64,white);b(36,19,28,248,2,56,wood)
 b(48,21,34,216,22,44,white);b(44,43,30,224,3,52,white)
 b(76,46,38,152,19,36,white);b(72,65,34,160,3,44,white)
 b(84,68,42,136,2,28,wood)
 for x=58,253,15 do
  for _,z in ipairs({33,78})do b(x,27,z,7,8,1,glass);b(x-1,26,z,9,1,1,metal)end
 end
 for x=87,215,16 do for _,z in ipairs({37,74})do b(x,51,z,9,8,1,glass)end end
 for _,x in ipairs({123,177})do
  b(x,70,46,20,27,20,red);b(x-2,95,44,24,6,24,navy)
  b(x,77,45,20,4,1,white)
 end
 for _,x in ipairs({38,275})do
  b(x,21,50,3,87,3,wood);b(x-15,91,50,33,2,2,metal)
  b(x+3,96,50,15,9,1,x==38 and red or navy)
 end
 -- Railings remain one model, with open gaps rather than opaque walls.
 for _,z in ipairs({23,88})do
  b(28,31,z,264,2,1,white)
  for x=28,292,24 do b(x,19,z,1,12,1,metal)end
 end
 for x=52,244,48 do for _,z in ipairs({23,82})do
  b(x,36,z,24,5,7,white);b(x+2,40,z+1,20,2,5,wood)
 end end
 -- Door faces the fixed boarding warp at dock cell (14,2). The landing
 -- remains native walkable ground; this is only a readable hull entrance.
 b(160,1,0,16,20,3,navy)
 b(158,0,0,2,23,3,white);b(176,0,0,2,23,3,white)
 b(158,21,0,20,2,3,white);b(173,9,0,1,3,1,metal)
 b=make('ss_anne_pier',104,48)
 b(0,-8,0,104,8,48,navy);b(0,0,0,104,3,48,metal)
 for x=4,99,24 do b(x,3,40,4,5,4,navy);b(x-1,8,39,6,2,6,navy)end
 b=make('ss_anne_truck',30,16)
 b(3,4,2,25,7,12,red);b(4,11,3,10,6,10,white)
 b(4,12,2,9,4,1,glass);b(4,12,13,9,4,1,glass)
 b(16,11,3,11,1,10,wood)
 for _,x in ipairs({6,22})do for _,z in ipairs({1,13})do b(x,1,z,5,6,2,navy);b(x+1,3,z,3,2,2,metal)end end
end
local matrices=setmetatable({},{__mode='k'})
function H.each(state,draw)
 local map=state.map;local kind=H.kind(map);if not kind then return end
 local P=V.require('VoxelItems')
 if not P.setting:get()or not V.require('Gen1PalletVillage').buildings:get()then return end
 H.models(P)
 local game=state.game or require('src.core.Game')
 local present,off,moving=H.shipState(map,game)
 local M=V.require('Mat4');local cache=matrices[map]
 if not cache then cache={};matrices[map]=cache end
 local function emit(name,x,y,z,dynamic)
  local mesh,tex=P.resolveKind(name);if not mesh then return end
  local mat=cache[name]
  if not mat or mat[4]~=x or mat[8]~=y or mat[12]~=z or (mat._voxelStatic==true)==dynamic then
   mat=M.translate(x,y,z);mat._voxelStatic=not dynamic;cache[name]=mat
  end
  draw(mesh,tex,mat,1)
 end
 if kind=='city'then
  emit('ss_anne_pier',384,0,584,false)
  emit('ss_anne_truck',408,3,598,false)
  if present then emit('ss_anne_liner',144,0,648,false)end
 else
  if present then emit('ss_anne_liner',64-off*3,0,48,moving)end
 end
end
function H.claim(S,map)
 local kind=H.kind(map);if not kind then return end
 local P=V.require('VoxelItems')
 if not P.setting:get()or not V.require('Gen1PalletVillage').buildings:get()then return end
 -- Resolve while the terrain plan is being prepared, not first on screen.
 H.models(P)
 local ready=P.resolveKind('ss_anne_liner')~=nil
 if kind=='city'then
  P.resolveKind('ss_anne_pier');P.resolveKind('ss_anne_truck');return
 end
 if not ready or type(map.tileAt)~='function'then return end
 local function key(x,y)return(y+64)*4096+x+64 end
 local water=S.shapeAt[key(4,7)]
 if not water or water.class~='water'then return end
 -- The source map closes the sea with pallet artwork at the far south
 -- and west edge. Render those exact non-walkable cells as water; keep
 -- the real north/east quay, corner crates, gangway and collision intact.
 local function sea(x,y)
  local k=key(x,y)
  S.shapeAt[k]=water;S.tileAt[k]=20
  if S.topTileAt then S.topTileAt[k]=20 end
  if S.topUVAt then S.topUVAt[k]=nil end
  S.skip[k]=nil;S.ground[k]=nil
 end
 for y=5,23 do for x=0,51 do
  if (x<2 or y>=22)and map:tileAt(x,y)==49 then sea(x,y)end
 end end
 if map:tileAt(22,6)~=2 then return end
 -- Only the original painted hull, below the fixed gangway and warp, is
 -- replaced. Its water is still terrain and follows the normal water pass.
 for y=6,11 do for x=20,35 do
  sea(x,y)
 end end
end
return H
