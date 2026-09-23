-- Optional, native-footprint voxel architecture for Pallet Town.
-- Tiles, collision, entrances and map connections remain owned by the game.
local V=...
local M={}
local Setting=V.require('ModSetting')
M.buildings=Setting.new('palletBuildings','BUILDINGS',{true,false},{'ON','OFF'})
M.surrounds=Setting.new('palletSurrounds','SURROUNDINGS',{true,false},{'ON','OFF'})
M.lights=Setting.new('palletWindowLights','WINDOW LIGHTS',{true,false},{'ON','OFF'})
M.specs={
 {kind='pallet_red_house',template='gabled_house',x=8,y=6,w=8,h=6,door={5,5,'REDS_HOUSE_1F'}},
 {kind='pallet_blue_house',template='gabled_house',x=24,y=6,w=8,h=6,door={13,5,'BLUES_HOUSE'}},
 {kind='pallet_oak_lab',template='oaks_lab',x=20,y=16,w=12,h=8,door={12,11,'OAKS_LAB'}},
}
function M.native(map)
 local d=map and map.def
 return map and map.id=='PALLET_TOWN' and d and d.width==10 and d.height==9
  and d.tileset=='OVERWORLD' and d.generation~=2
end
function M.windowLight()
 return M.lights:get() and V.require('DayNight').windowLight() or 0
end
function M.register(P,F)
 local C=P.decorColors
 local function model(kind,w,d)
  -- Pallet can inherit a non-zero world datum from Route 1. Houses and
  -- boundary props must follow that same ground after ordinary or Dig warps.
  local a={terrain=true,boxes={},step=1,frameW=w,frameH=math.ceil(36+d*.65),depth=d,offsetY=-36}
  P.models[kind]=a
  return a,function(x,y,z,bw,bh,bd,color)
   if bw>0 and bh>0 and bd>0 then a.boxes[#a.boxes+1]={x,y,z,bw,bh,bd,color or 2}end
  end
 end
 local function building(kind,lab,blue)
  local w,d=lab and 96 or 64,lab and 64 or 48
  local a,b=model(kind,w,d)
  local panes,g=model(kind..'_glass',w,d);panes.step=1
  a.glassKind=kind..'_glass';a.windowLight=M.windowLight
  a.winterKind=V.require('VoxelWinterDetails').roof(P,kind,w,d,lab and 26 or 24,
    lab and {'north','south','west','east'} or {'west','east'},
    {{side='south',at=lab and 40 or 24,width=18}})
  local front=d-8;local roof=blue and C.navy or lab and 10 or 13
  local roofLight=blue and 8 or lab and 9 or 1
  local facade=lab and 2 or blue and (C.sage or 40)or(C.warmBrick or 14)
  a.wallMaterial=lab and 'plaster' or blue and 'half_timber' or 'stone'
  a.facadeColor,a.roofColor=facade,roof
  -- Hollow walls, a low stone foundation and raised corner courses.
  b(4,0,4,w-8,2,front-4,14)
  b(4,2,4,w-8,22,2,facade);b(4,2,4,2,22,front-4,facade)
  b(w-6,2,4,2,22,front-4,facade);b(4,2,front-2,w-8,22,2,facade)
  if not lab then
   if blue then
    for _,x in ipairs({5,16,35,w-8})do b(x,3,front,2,19,1,C.walnut)end
    b(4,20,front,w-8,2,1,C.walnut)
    for _,x in ipairs({4,w-6})do for z=7,front-4,12 do b(x,3,z,2,19,2,C.walnut)end end
   else
    for y=4,19,5 do for x=6,w-12,10 do
     b(x,y,3,7,3,1,C.stone or 14)
     if x<14 or x>34 then b(x,y,front,7,3,1,C.stone or 14)end
    end end
   end
  end
  for _,x in ipairs({4,w-8})do
   for y=2,22,4 do b(x,y,front-1,4,3,2,4)end
  end
  b(4,3,front,w-8,2,1,C.oak)
  b(4,22,front,w-8,2,2,4)
  -- Front windows use their own pane mesh; trim remains normally shaded.
  local function window(x,y,z,ww,hh)
   b(x-1,y-1,z,ww+2,1,2,4);b(x-1,y+hh,z,ww+2,1,2,4)
   b(x-1,y,z,1,hh,2,4);b(x+ww,y,z,1,hh,2,4)
   g(x,y,z,ww,hh,1,7)
   b(x+math.floor(ww/2),y,z+1,1,hh,1,4)
   b(x,y+math.floor(hh/2),z+1,ww,1,1,4)
   b(x-2,y-2,z-1,ww+4,1,3,C.oak)
  end
  local door=lab and 40 or 24
  b(door-9,2,front,2,18,2,4);b(door+7,2,front,2,18,2,4)
  b(door-9,20,front,18,2,3,4)
  b(door-7,2,front,14,18,1,lab and C.navy or C.walnut)
  b(door-5,4,front+1,10,6,1,lab and 10 or C.oak)
  g(door-5,12,front+1,10,6,1,7)
  b(door+4,10,front+2,1,2,1,11)
  b(door-8,0,front,16,1,8,14)
  if lab then
   window(9,9,front,16,11);window(61,9,front,20,11)
   b(4,6,front,w-8,2,1,10)
   b(4,24,4,w-8,2,front-4,4)
   b(0,26,0,w,2,d,C.navy);b(2,28,2,w-4,2,d-4,4)
   b(5,30,5,w-10,2,d-10,10)
   -- A framed laboratory skylight, kept below the old 36px roof envelope.
   b(24,32,20,48,2,24,4);g(26,34,22,44,1,20,7)
   for x=26,66,10 do b(x,34,22,2,2,20,4)end
   b(24,34,20,48,2,2,4);b(24,34,42,48,2,2,4)
   -- Raised laboratory plaque: three starter-colour squares under a ball.
   b(58,23,front,23,3,2,C.navy)
   for i,color in ipairs({12,7,1})do b(60+(i-1)*7,23,front+2,5,2,1,color)end
  else
   window(7,9,front,6,10);window(41,9,front,12,10)
   -- Stepped gable roof with an inset cream front, not a repeated bitmap.
   for y=0,11 do
    local inset=math.floor(y*2.5);local rw=w-inset*2
    b(inset,24+y,0,rw,1,d-2,y%3==0 and roofLight or roof)
    b(inset,24+y,d-2,2,1,2,roof)
    b(w-inset-2,24+y,d-2,2,1,2,roof)
    b(inset+2,24+y,d-2,rw-4,1,1,2)
   end
   -- Small attic glazing within the same roof and footprint.
   g(28,26,d-1,8,5,1,7)
   b(27,25,d-1,10,1,1,4);b(27,31,d-1,10,1,1,4)
   b(27,26,d-1,1,5,1,4);b(36,26,d-1,1,5,1,4)
   b(31,26,d-1,1,5,1,4)
   b(blue and 46 or 10,25,8,6,9,6,14)
   b(blue and 45 or 9,34,7,8,2,8,16)
   -- Flower boxes distinguish the two homes, while their doors stay native.
   b(41,5,front+1,14,3,3,C.walnut)
   for x=42,52,3 do b(x,8,front+2,2,2,2,12);b(x,10,front+2,2,1,2,blue and 11 or 1)end
  end
  -- Side windows are visible when walking around the building.
  for _,x in ipairs({3,w-4})do for _,z in ipairs(lab and {13,35} or {12,26})do
   g(x,10,z,1,9,7,7)
   b(x,9,z-1,1,1,9,4);b(x,19,z-1,1,1,9,4)
   b(x,10,z-1,1,9,1,4);b(x,10,z+7,1,9,1,4)
   b(x,14,z,1,1,7,4);b(x,10,z+3,1,9,1,4)
  end end
 end
 building('pallet_red_house',false,false)
 building('pallet_blue_house',false,true)
 building('pallet_oak_lab',true,false)
 -- Rounded, stepped foliage and different mineral silhouettes, all within
 -- the old 16x16 border-cell footprint. No random generator or map writes.
 for variant=1,5 do
  local _,b=model('pallet_border_'..variant,16,16)
  if variant<=3 then
   b(6,0,6,4,14,4,C.walnut);b(5,0,5,6,2,6,C.oak)
   local layers=variant==3 and {{4,9,8,4},{1,13,14,3},{3,16,10,4},{5,20,6,4},{7,24,2,3}}
    or {{4,9,8,3},{2,12,12,4},{1,16,14,5},{3,21,10,3},{5,24,6,2}}
   for i,row in ipairs(layers)do b(row[1],row[2],row[1],row[3],row[4],row[3],i%2==0 and 12 or 10)end
   if variant==2 then for _,p in ipairs({{3,17,2},{11,19,4},{6,22,11}})do b(p[1],p[2],p[3],2,2,2,1)end end
  else
   b(2,0,3,12,3,11,16);b(3,3,2,10,5,12,14)
   b(4,8,4,8,variant==4 and 4 or 7,8,C.silver)
   b(6,variant==4 and 12 or 15,6,5,2,5,14)
   b(3,3,3,4,1,3,10);b(10,4,10,3,1,3,12)
  end
 end
 do
  local _,b=model('pallet_post_tall',8,16)
  local z=6
  b(2,0,z,4,9,4,C.oak);b(1,9,z-1,6,2,6,C.walnut)
  b(2,11,z,4,1,4,14);b(3,4,z+3,2,1,1,11)
 end
 local templates={};for _,p in ipairs(V.data('voxel_heights').buildings.OVERWORLD)do templates[p.id]=p.tiles end
 local function enabled(setting)return function()return setting:get()end end
 local buildingsOn,surroundsOn=enabled(M.buildings),enabled(M.surrounds)
 local function add(p)
  p.sets={OVERWORLD=true};p.maps={PALLET_TOWN=true};p.voxelOnly=true
  p.groundTile=44;F.patterns[#F.patterns+1]=p
 end
 for _,spec in ipairs(M.specs)do
  add({kind=spec.kind,x=spec.x,y=spec.y,tiles=templates[spec.template],enabled=buildingsOn,
   guard=function(map)
    if not M.native(map) then return false end
    for _,warp in ipairs(map.def.warps or {})do
     if warp.x==spec.door[1] and warp.y==spec.door[2] and warp.destMap==spec.door[3] then return true end
    end
    return false
   end})
 end
 local function solid(map,x,y)
  if not M.native(map) then return false end
  local cx,cy=math.floor(x/2),math.floor(y/2)
  return not map:isWalkableCell(cx,cy) and not map:isWarpTileCell(cx,cy)
 end
 add({kind='pallet_border_1',tiles={{42,43},{58,59}},enabled=surroundsOn,guard=solid,
  variant=function(_,x,y)return 'pallet_border_'..(1+(x*3+y*7)%5)end})
 add({kind='pallet_post_tall',tiles={{14},{85}},enabled=surroundsOn,guard=solid})
end
function M.bind(invalidate)
 for _,setting in ipairs({M.buildings,M.surrounds,M.lights})do
  for _,name in ipairs({'setIndex','sync'})do
   local previous=setting[name]
   setting[name]=function(self,...)
    local before=self:get();local value=previous(self,...)
    if before~=self:get() then invalidate() end
    return value
   end
  end
 end
end
return M
