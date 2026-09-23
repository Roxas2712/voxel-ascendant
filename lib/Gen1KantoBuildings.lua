-- Authored, optional architecture on the original Gen1 building footprints.
-- Each visual entrance follows a native warp; native maps remain untouched.
local V=...
local M={}
local village=V.require('Gen1PalletVillage')
local gates=V.require('GateDoors')
local themes={PALLET_TOWN=1,VIRIDIAN_CITY=2,PEWTER_CITY=3,CERULEAN_CITY=4,
 VERMILION_CITY=5,LAVENDER_TOWN=6,CELADON_CITY=7,FUCHSIA_CITY=8,
 SAFFRON_CITY=9,CINNABAR_ISLAND=10,INDIGO_PLATEAU=11}
function M.theme(id)
 if themes[id]then return themes[id]end
 if id:find('SAFARI')then return 8 end
 local n=tonumber(id:match('ROUTE_(%d+)'))or 0
 return n>=19 and 10 or n>=12 and 8 or n>=5 and 4 or 2
end
function M.doors(map,x,y,w,h)
 local out,seen={},{}
 local function add(side,at,width,dest)
  local k=side..':'..at
  if not seen[k]then seen[k]=true;out[#out+1]={side=side,at=at,width=width or 14,dest=dest}end
 end
 for _,warp in ipairs(map.def.warps or{})do
  local a,b=warp.x*16+8-x*8,warp.y*16+8-y*8
  if a>=0 and a<w*8 then
   if b>=h*8-16 and b<h*8+1 then add('south',a,14,warp.destMap)
   elseif b>=-16 and b<=8 then add('north',a,14,warp.destMap)end
  end
 end
 for _,d in ipairs(gates.forBuilding(map,x,y,w,h))do
  if d.side=='west' or d.side=='east' then add(d.side,d.z+d.width/2,d.width-2)end
 end
 return out
end
function M.register(P,F)
 local C=P.decorColors
 local accents={C.clay or 13,C.roofGreen or 10,C.slate or 16,8,C.clay or 11,C.purple,C.roofGreen or 12,C.sage,C.navy,1,C.navy}
 local function make(kind,w,d,height)
  local a={terrain=true,boxes={},step=1,frameW=w,frameH=height+d,depth=d,offsetY=-height}
  P.models[kind]=a
  local function box(x,y,z,bw,bh,bd,c)
   local x1,z1=math.max(0,x),math.max(0,z)
   local x2,z2=math.min(w,x+bw),math.min(d,z+bd)
   if x2>x1 and z2>z1 and bh>0 then a.boxes[#a.boxes+1]={x1,y,z1,x2-x1,bh,z2-z1,c or 2}end
  end
  return a,box
 end
 local function ball(b,cx,cy,cz,r)
  -- Chunky sphere made of short runs, with the familiar belt and button.
  for y=-r,r-1,2 do for z=-r,r-1,2 do
   local rr=r*r-(y+1)^2-(z+1)^2
   if rr>0 then local dx=math.floor(math.sqrt(rr));b(cx-dx,cy+y,cz+z,dx*2,2,2,y>=2 and 1 or y>=-2 and 3 or 4)end
  end end
  b(cx-3,cy-3,cz+r-2,6,6,2,3);b(cx-2,cy-2,cz+r,4,4,1,4)
 end
 local function create(kind,map,tx,ty,tw,th,template)
  if template:find('pokemon_tower')then kind=kind..'_'..V.require('Gen1LavenderTower').setting:get()end
  if P.models[kind]then return kind end
  local w,d=tw*8,th*8;local theme=M.theme(map.id)
  local doors=M.doors(map,tx,ty,tw,th)
  local doorSides={};for _,door in ipairs(doors)do doorSides[door.side]=true end
  local center=template=='pokecenter';local mart=template=='pokemart' or template=='celadon_mart'
  local tower=template:find('pokemon_tower')~=nil
  if tower then return V.require('Gen1LavenderTower').create(P,kind,template,village.windowLight)end
  if tower then theme=6 end
  if template=='silph_co' and V.require('Gen1SilphCo').matches(map.def)then
   return V.require('Gen1SilphCo').create(P,kind,doors,village.windowLight)
  end
  local office=template=='silph_co';local tall=office or template=='celadon_mart' or template=='celadon_mansion'
  local house=template:find('gabled') or template=='daycare' or template=='safari_rest_house'
  local flat=template:find('flat_')==1
  local museum=template=='museum';local gym=template:find('gym')~=nil
  local league=template:find('league')~=nil
  local routeGate=template=='victory_road_gate'or template=='route23_south_gate'
  local department=template=='celadon_mart'
  local height=department and 114 or tower and 68 or league and 56 or tall and 54 or 36
  local a,b=make(kind,w,d,height+20);local panes,g=make(kind..'_glass',w,d,height+20)
  local haunted=map.id=='LAVENDER_TOWN'
  if haunted then
   local rawBox=b
   b=function(x,y,z,bw,bh,bd,c)
    if c==4 then c=C.oldPlaster or 14 elseif c==12 then c=C.dryLeaves or C.walnut end
    rawBox(x,y,z,bw,bh,bd,c)
   end
   local rawGlass=g
   g=function(x,y,z,bw,bh,bd,c)
    rawGlass(x,y,z,bw,bh,bd,c==7 and (C.dustyGlass or 10)or c)
   end
  end
  a.glassKind=kind..'_glass';a.windowLight=village.windowLight;a.nativeDoors=doors;a.template=template
  if haunted then a.windowLight=function()return village.windowLight()*.7 end end
  local accent=center and 1 or mart and (C.martBlue or 8) or accents[theme]
  if haunted and not center and not mart then accent=C.fadedPlum or C.purple end
  if routeGate then accent=C.slate or 16 end
  local facade=routeGate and 14 or theme==3 and 14 or theme==6 and 14 or 2
  if haunted then facade=house and (C.oldTimber or C.walnut)or(C.oldPlaster or 14)end
  if house or flat then
   local style=V.require('Gen1FacadeDetails').style(C,theme,tx,ty)
   a.facadeVariant,a.wallMaterial,a.roofShape=style.variant,style.material,flat and 'flat' or style.roofShape
   facade,accent=style.wall,style.roof
   a.facadeColor,a.roofColor=facade,accent
  end
  local front=d-8
  -- The Lavender tower is one continuous volume across its map seam.
  local back=tower and template=='pokemon_tower' and 0 or doorSides.north and 4 or 2
  local left=doorSides.west and 4 or 2
  local right=doorSides.east and w-6 or w-4
  if tower and template=='pokemon_tower_top'then front=d end
  b(2,0,back,w-4,3,front-back,16)
  b(left,3,back,2,height-9,front-back,facade);b(right,3,back,2,height-9,front-back,facade)
  if not tower or template=='pokemon_tower_top'then b(2,3,back,w-4,height-9,2,facade)end
  if not tower or template=='pokemon_tower'then b(2,3,front-2,w-4,height-9,2,facade)end
  local levels=department and 6 or tall and 3 or tower and 4 or 1
  for level=0,levels-1 do
   local yy=math.floor(level*(height-9)/levels)+4
   local hh=math.floor(math.min(12,(height-9)/levels-4))
   if not tower or template=='pokemon_tower'then
    b(2,yy-1,front,w-4,2,1,accent)
    for x=7,w-12,16 do
     local clear=true
     if level==0 then for _,door in ipairs(doors)do if door.side=='south' and math.abs(x+4-door.at)<14 then clear=false end end end
     if clear then
      b(x-1,yy+4,front,10,hh+2,1,4);g(x,yy+5,front+1,8,hh,1,7)
      b(x+3,yy+5,front+2,1,hh,1,4)
     end
    end
   end
   for z=back+9,front-12,18 do for _,side in ipairs({left,right+1})do
    local clear=true;for _,door in ipairs(doors)do if (door.side=='west' or door.side=='east')and level==0 and math.abs(z+4-door.at)<door.width/2+7 then clear=false end end
    if clear then b(side,yy+4,z-1,1,hh+2,10,4);g(side+(side==left and -1 or 1),yy+5,z,1,hh,8,7)end
   end end
  end
  -- Foundation courses and dressed quoins make the facade read as a
  -- building at human height rather than a featureless cream box.
  if not tower or template=='pokemon_tower'then
   b(2,2,front,w-4,2,1,C.stone or 14)
   for _,xx in ipairs({3,w-7})do for yy=5,height-10,5 do
    b(xx,yy,front,4,3,1,theme==3 and 4 or C.warmBrick or 14)
   end end
  end
  if house then
   for xx=6,w-14,16 do
    local clear=true;for _,dd in ipairs(doors)do if dd.side=='south' and math.abs(xx+5-dd.at)<15 then clear=false end end
    if clear then
     b(xx-2,9,front+2,2,13,1,accent);b(xx+10,9,front+2,2,13,1,accent)
     b(xx-3,8,front+2,16,1,2,C.oak)
    end
   end
  end
  if haunted then
   -- Lavender is inhabited but worn: dark lintels, weathered board courses,
   -- patched shutters and dry planters. Keep every real door unobstructed.
   local timber,beam=C.oldBoard or C.oak,C.oldBeam or C.walnut
   for yy=6,24,6 do
    b(left,yy,back,2,1,front-back,beam)
    b(right,yy,back,2,1,front-back,beam)
   end
   for x=7,w-12,16 do
    local clear=true
    for _,door in ipairs(doors)do if door.side=='south'and math.abs(x+4-door.at)<14 then clear=false end end
    if clear then
     b(x-2,7,front+2,2,12,2,beam);b(x+8,7,front+2,2,12,2,beam)
     b(x-2,19,front+2,12,2,2,beam)
     if house and (math.floor(x/16)+tx)%3==0 then
      -- Stepped diagonal boards are real relief, not a new window bitmap.
      for step=0,4 do b(x+step*2,8+step*2,front+3,2,3,1,timber)end
     end
     b(x-2,3,front+1,12,2,3,timber)
     b(x,5,front+2,2,3,2,C.dryLeaves or C.walnut)
    end
   end
  end
  for _,door in ipairs(doors)do
   local side,at=door.side,door.at
   local half=door.width/2
   local function db(bx,by,bz,bw,bh,bd,c,glass)
    local f=glass and g or b
    if side=='south'then f(at+bx,by,front+bz,bw,bh,bd,c)
    -- Recess door-bearing walls so every facade layer stays in bounds,
    -- ordered from wall to panel to glass to mullion on each bearing.
    elseif side=='north'then f(at+bx,by,5-bz-bd,bw,bh,bd,c)
    elseif side=='west'then f(5-bz-bd,by,at+bx,bd,bh,bw,c)
    else f(w-5+bz,by,at+bx,bd,bh,bw,c)end
   end
   db(-half-1,1,0,door.width+2,23,2,4);db(-half,2,2,door.width,20,1,C.navy)
   db(1-half,5,3,door.width-2,15,1,7,true);db(-1,3,4,2,18,1,4)
   db(-half-1,0,0,door.width+2,1,8,14);db(-half-3,24,0,door.width+6,2,5,accent)
   -- Wall lanterns are part of the independently emissive window mesh.
   for _,lx in ipairs({-half-4,half+2})do
    db(lx,15,1,3,7,2,C.navy);db(lx,22,1,3,1,3,4)
    db(lx+1,16,3,1,5,1,11,true)
   end
  end
  if house then
   -- Stepped pitched roof and visible end gables, varied by region.
   b(0,26,0,w,2,d,accent)
   for y=0,9 do
    local cross=a.roofShape=='side_gable'
    local inset=math.floor(y*(cross and d or w)/20)
    local hip=a.roofShape=='hipped' and math.floor(y*d/24)or 0
    if cross then
     b(0,28+y,inset,w,1,d-inset*2,accent)
     b(1,28+y,inset+1,1,1,d-inset*2-2,facade)
    else
     b(inset,28+y,hip,w-inset*2,1,d-hip*2,accent)
     if hip==0 then b(inset+2,28+y,d-1,w-inset*2-4,1,1,facade)end
    end
   end
   if d>=40 then b(w-15,29,8,6,10,6,C.walnut);b(w-16,39,7,8,2,8,14)end
  elseif center then
   -- Modern Center: broad red curved cap, white fascia and glazed doors.
   for y=0,9 do local inset=math.floor(y*y/16)
    b(inset,27+y,2,w-inset*2,1,d-4,y==0 and 4 or 1)
   end
   b(w/2-12,24,front+2,24,10,2,4)
   b(w/2-9,22,d-2,18,18,1,4)
   -- A relief emblem at the outermost fascia, fully in front of the cap.
   for yy=-7,7 do for xx=-7,7 do
    local rr=xx*xx+yy*yy
    if rr<=49 then
     local color=rr>=36 and 3 or yy>1 and 1 or yy< -1 and 4 or 3
     if rr<=5 then color=4 end
     if color==4 then g(w/2+xx,31+yy,d-1,1,1,1,4)else b(w/2+xx,31+yy,d-1,1,1,1,color)end
    end
   end end
   b(6,23,front,w-12,1,3,4)
  elseif league then
   b(0,38,0,w,4,d,14);b(2,42,2,w-4,3,d-4,C.navy)
   for _,x in ipairs({3,w-23})do
    b(x,0,2,20,48,d-4,14);b(x-1,47,1,22,4,d-2,4)
    b(x,51,2,20,3,d-4,C.navy);ball(b,x+10,64,math.min(d-12,26),9)
    for yy=7,37,10 do b(x+5,yy-1,d-1,10,8,1,4);g(x+6,yy,d-1,8,6,1,7);b(x+9,yy,d-1,2,6,1,C.navy)end
   end
   if template=='league_center'then ball(b,w/2,48,d-8,10)end
  elseif routeGate then
   -- Dressed gatehouse with a shallow pitched roof and stone end towers.
   for y=0,7 do
    b(0,32+y,y*2,w,1,d-y*4,accent)
    if y%2==0 then for x=4,w-4,12 do b(x,32+y,y*2,1,1,d-y*4,14)end end
   end
   b(0,30,0,w,2,d,4)
   for _,x in ipairs({0,w-16})do
    b(x,0,0,16,40,d,14);b(x,40,0,16,2,d,4)
    for y=8,32,8 do b(x,y,0,16,1,d,C.stone or 14)end
    if template=='victory_road_gate'then
     for _,box in ipairs(P.models.rhydon_pillar_statue.boxes)do
      -- Only the sculpture: the gate tower itself owns the plinth.
      if box[2]>=32 then b(x+box[1],42+box[2]-32,d-32+box[3],box[4],box[5],box[6],box[7])end
     end
    end
   end
   -- North-facing return gate needs its windows on the approach side too.
   if template=='route23_south_gate'then
    for _,x in ipairs({24,48,w-56,w-32})do
     b(x-1,10,0,10,13,2,4);g(x,11,0,8,11,1,7);b(x+3,11,0,1,11,1,C.navy)
    end
   end
  else
   b(0,height-5,0,w,3,d,4);b(2,height-2,2,w-4,2,d-4,accent)
   if tower then
    -- No cross-seam end cornice: both chunks meet at the same height.
    if template=='pokemon_tower_top'then b(0,height-5,d-2,w,5,2,accent)end
    for x=4,w-6,12 do b(x,height,4,5,5,5,14)end
   elseif office then
    b(w/2-18,height,8,36,4,26,C.navy);g(w/2-16,height+4,10,32,1,22,7)
    b(w/2-2,height+4,18,4,12,4,14)
   elseif museum or gym then
    for _,x in ipairs({4,w-8})do b(x,3,front+1,4,23,3,4)end
    b(w/2-15,26,front+1,30,5,2,accent)
    if gym then ball(b,w/2,30,front+2,5)end
   elseif mart then
    -- Shop emblem is mounted on the front by Gen1BuildingLandmarks.
   else
    b(8,height,8,12,3,12,14);b(9,height+3,9,10,1,10,16)
    if theme==7 or theme==8 then b(w-21,height,7,12,3,12,C.oak);b(w-20,height+3,8,10,3,10,12)end
   end
  end
  V.require('Gen1FacadeDetails').add(a,b,g,C,doors,w,d,front,theme,tx,ty,house or flat,museum)
  V.require('Gen1BuildingLandmarks').add(a,b,g,C,P,doors,w,d,front,height)
  -- Follow the low eaves of each roof instead of hanging ornaments in air
  -- in front of the tall gable or over a native doorway.
  local sides=house and (a.roofShape=='side_gable' and {'north','south'}
    or a.roofShape=='hipped' and {'north','south','west','east'} or {'west','east'})
    or {'north','south','west','east'}
  local eaves=house and 26 or center and 27 or league and 38 or routeGate and 30 or height-5
  a.winterKind=V.require('VoxelWinterDetails').roof(P,kind,w,d,eaves,sides,doors)
  return kind
 end
 for _,set in ipairs({'OVERWORLD','FOREST'})do
  for _,template in ipairs(V.data('voxel_heights').buildings[set]or{})do
   local p=template
   F.patterns[#F.patterns+1]={kind='kanto_building',sets={[set]=true},tiles=p.tiles,voxelOnly=true,
    groundTile=set=='FOREST' and 0 or 44,enabled=function()return village.buildings:get()end,
    guard=function(map,x,y)
     if map.def.generation==2 or map.id=='PALLET_TOWN'then return false end
     -- Some original templates have an extra neighbour constraint.
     for j,row in ipairs(p.tiles)do for i,t in ipairs(row)do if map:tileAt(x+i-1,y+j-1)~=t then return false end end end
     return true
    end,
    variant=function(map,x,y)return create('kanto_building_'..map.id..'_'..x..'_'..y,map,x,y,#p.tiles[1],#p.tiles,p.id)end}
  end
 end
 -- Exact native Indigo silhouette; the two courtyard recesses stay open.
 M.create=create
 M.addLeague=function(grid,x,y,w,h,name)
  F.patterns[#F.patterns+1]={kind='kanto_building',sets={PLATEAU=true},maps={INDIGO_PLATEAU=true},
   x=x,y=y,tiles=grid,voxelOnly=true,groundTile=35,enabled=function()return village.buildings:get()end,
   guard=function(map)return map.def.width==10 and map.def.height==9 and map.def.generation~=2 end,
   variant=function(map)return create('kanto_building_'..name,map,x,y,w,h,name)end}
 end
 V.require('Gen1LeagueFootprints')(M.addLeague)
 V.require('Gen1Route23Gates')(M,F)
end
return M
