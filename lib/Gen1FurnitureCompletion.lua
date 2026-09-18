-- Remaining native indoor furnishings. Visual ownership only; no script,
-- walkability, warp or save edits. Exact masks are registered after the larger
-- authored furnishings so a small component cannot split an existing model.
return function(P,F,patterns)
 local C=P.decorColors
 local function model(name,w,d,support)
  local m={boxes={},frameW=w,frameH=d+32,depth=d,offsetY=-32,support=support}
  P.models[name]=m
  return function(x,y,z,a,h,c,color)m.boxes[#m.boxes+1]={x,y,z,a,h,c,color}end
 end
 local function legs(b,w,d,h)
  for _,x in ipairs({1,w-3})do for _,z in ipairs({1,d-3})do b(x,0,z,2,h,2,C.walnut)end end
 end
 local function top(b,w,d)
  legs(b,w,d,7);b(0,7,0,w,1,d,C.walnut);b(0,8,0,w,1,d,C.oak)
  b(1,9,1,w-2,1,d-2,2)
 end
 -- Stable per-location plant varieties: never change when returning to a room.
 for variant=0,3 do
  local b=model('indoor_plant_'..variant,16,32)
  local pot=({C.oak,7,14,C.purple})[variant+1]
  b(4,0,20,8,1,8,16);b(3,1,19,10,6,10,pot)
  b(2,6,18,12,2,12,pot);b(3,8,19,10,1,10,C.walnut)
  b(7,9,23,2,variant==1 and 16 or 9,2,C.walnut)
  if variant==0 then -- broad-leaf fern
   for level=0,2 do for side=-1,1,2 do
    local y=12+level*4
    for i=0,5 do
     local x=side<0 and 7-i or 8+i
     b(x,y-math.floor(i/3),20+level,1,2,6-level, i%2==0 and 12 or 10)
    end
   end end
  elseif variant==1 then -- small palm, compact enough for the native plant cell
   for i=0,6 do
    b(1+i,25-math.floor(math.abs(i-3)/2),20+i,2,2,3,12)
    b(12-i,25-math.floor(math.abs(i-3)/2),20+i,2,2,3,10)
   end
   b(6,26,22,4,3,4,12)
  elseif variant==2 then -- flowering shrub
   b(3,12,19,10,6,10,10);b(2,16,21,12,5,6,12);b(5,21,21,6,3,6,C.sage)
   for _,p in ipairs({{3,18,26},{10,19,22},{6,23,24}})do
    b(p[1],p[2],p[3],3,2,3,15);b(p[1]+1,p[2]+2,p[3]+1,1,1,1,11)
   end
  else -- succulent rosette
   b(4,10,20,8,4,8,10);b(2,12,22,12,2,4,12)
   b(6,12,18,4,3,12,12);b(5,14,21,6,3,6,C.sage);b(7,17,23,2,2,2,12)
  end
 end
 for _,dir in ipairs({'north','south','west'})do
  local b=model('wood_chair_'..dir,16,16,6)
  legs(b,16,16,5);b(2,5,2,12,2,12,C.oak);b(3,7,3,10,1,10,10)
  if dir=='west' then
   b(1,6,2,2,9,2,C.walnut);b(1,6,12,2,9,2,C.walnut)
   b(1,12,3,2,3,10,C.oak)
  else
   local z=dir=='north' and 1 or 13
   b(2,6,z,2,9,2,C.walnut);b(12,6,z,2,9,2,C.walnut)
   b(3,12,z,10,3,2,C.oak)
  end
 end
 local b=model('wood_stool',16,16,6);legs(b,14,14,6);b(1,6,1,12,2,12,C.oak);b(3,8,3,8,1,8,10)
 b=model('waiting_bench',16,16,6)
 legs(b,16,16,5);b(0,5,3,16,2,12,7);b(0,7,2,16,7,2,8)
 for x=1,14,3 do b(x,9,4,2,3,1,7)end
 b=model('dining_table',32,32,10);top(b,32,32)
 b(13,10,12,6,1,8,4);b(15,11,14,2,2,3,7)
 b=model('writing_table',32,32,10);top(b,32,32)
 b(4,10,7,12,1,10,4);b(5,11,9,9,1,1,16);b(5,11,12,7,1,1,16)
 b(24,10,7,3,4,3,7);b(25,14,8,1,2,1,16)
 b=model('round_table',32,32,10)
 b(11,0,11,10,2,10,C.walnut);b(14,2,14,4,6,4,C.oak)
 for x=0,31 do for z=0,31 do
  if (x-15.5)^2+(z-15.5)^2<250 then b(x,8,z,1,2,1,C.oak)end
 end end
 for _,kind in ipairs({'table_surface','table_edge','table_corner'})do
  b=model(kind,8,8,10);b(0,7,0,8,1,8,C.walnut);b(0,8,0,8,2,8,C.oak)
  if kind~='table_surface'then b(1,0,1,2,7,2,C.walnut)end
 end
 -- Narrow counter sections butt together; low cabinets leave the clerk visible.
 for _,kind in ipairs({'counter_unit','counter_top'})do
  b=model(kind,8,8,9);b(0,0,0,8,1,8,16);b(0,1,0,8,6,8,C.walnut)
  b(0,7,0,8,1,8,C.oak);b(0,8,0,8,1,8,4);b(1,3,7,6,2,1,7)
 end
 b=model('office_terminal',32,16,9)
 top(b,32,16);b(3,10,2,12,9,4,14);b(4,11,6,10,6,1,8)
 b(5,14,7,7,1,1,7);b(5,12,7,4,1,1,12)
 b(3,10,10,12,1,4,3);for x=4,12,2 do b(x,11,11,1,1,1,14)end
 b(20,10,2,8,10,9,14);b(21,17,11,6,1,1,3);b(22,12,11,1,1,1,12)
 b=model('console_cabinet',16,24)
 b(1,0,7,14,2,16,16);b(0,2,7,16,17,16,14);b(1,19,7,14,1,16,8)
 b(2,11,23,12,6,1,3);b(3,12,24-1,10,4,1,7)
 for _,x in ipairs({3,10})do
  b(x,5,23,4,4,1,16);b(x+1,6,23,2,2,1,14)
 end
 b(2,3,23,12,1,1,3)
 b=model('wall_recorder',16,16)
 b(1,7,1,14,10,4,14);b(2,8,5,12,8,1,3)
 for _,x in ipairs({3,10})do b(x,11,6,3,3,1,14);b(x+1,12,7,1,1,1,16)end
 b(6,8,6,4,2,1,7);b(12,8,6,1,1,1,12)
 -- Flat woven mats, raised just half a pixel, including original exit mats.
 for _,w in ipairs({16,32})do
  b=model('woven_rug_'..w,w,16);P.models['woven_rug_'..w].step=.5
  b(0,0,0,w,.5,16,16);b(1,0,1,w-2,.5,14,5)
  b(2,0,2,w-4,.5,1,11);b(2,0,13,w-4,.5,1,11)
  for x=3,w-4,4 do b(x,0,5,2,.5,6,13);b(x,0,7,2,.5,2,11)end
 end
 for variant=0,2 do
  b=model('memorial_stone_'..variant,16,16)
  b(1,0,2,14,2,13,16);b(2,2,4,12,2,10,C.silver)
  b(3,4,7,10,10,5,C.silver);b(4,14,7,8,2,5,14)
  b(5,16,8,6,1,3,14);b(4,5,12,8,8,1,16)
  for y=6,10,2 do b(6,y,13,4,1,1,14)end
  if variant==1 then b(2,2,2,3,2,3,12);b(2,4,2,3,1,3,15)
  elseif variant==2 then b(11,2,2,2,4,2,4);b(11,6,2,2,1,2,11)end
 end
 b=model('plain_bed',16,32)
 legs(b,16,32,4);b(1,4,1,14,2,30,C.walnut);b(1,6,2,14,3,28,4)
 b(2,9,4,12,2,7,14);b(1,9,13,14,1,17,10);b(1,0,0,14,14,2,C.oak)
 -- Display bicycles keep their original three-by-two tile footprint.
 -- Thin circular wheels, spokes and open frames remain readable from either side.
 for variant=0,3 do
  b=model('shop_bicycle_'..variant,24,16)
  local accent=({5,7,11,10})[variant+1]
  for _,cx in ipairs({5,18})do
   for x=cx-4,cx+4 do for y=0,8 do
    local radius=(x-cx)^2+(y-4)^2
    if radius>=10 and radius<=20 then b(x,y,7,1,1,2,16)
    elseif radius<=9 and (x==cx or y==4)then b(x,y,7,1,1,1,C.silver)end
   end end
   b(cx,4,6,1,1,4,C.silver)
  end
  local function tube(x1,y1,x2,y2)
   local n=math.max(math.abs(x2-x1),math.abs(y2-y1))
   for i=0,n do
    b(math.floor(x1+(x2-x1)*i/n+.5),math.floor(y1+(y2-y1)*i/n+.5),7,1,1,2,accent)
   end
  end
  tube(5,4,11,4);tube(5,4,9,11);tube(9,11,11,4)
  tube(9,11,16,11);tube(16,11,11,4);tube(16,13,18,4)
  b(8,12,7,1,2,2,C.silver);b(6,14,6,6,1,4,16)
  b(16,12,7,1,4,2,C.silver);b(16,16,4,1,1,8,C.silver)
  b(16,16,3,2,1,2,16);b(16,16,11,2,1,2,16)
  b(11,4,5,1,1,6,C.silver);b(10,4,4,3,1,2,16)
  b(17,12,7,2,2,2,4);b(3,8,7,1,1,2,5)
  b(10,0,10,1,5,1,C.silver);b(9,0,10,3,1,2,16)
 end
 for _,kind in ipairs({'shop_counter_run','shop_counter_end','shop_counter_front'})do
  local w,d=kind=='shop_counter_front'and 32 or 16,kind=='shop_counter_front'and 16 or 8
  b=model(kind,w,d)
  b(0,0,0,w,2,d,16);b(0,2,0,w,7,d,C.walnut)
  b(0,9,0,w,1,d,C.oak);b(0,10,0,w,1,d,C.silver)
  if kind=='shop_counter_run'then
   b(0,3,1,1,5,d-2,7);b(0,5,2,1,1,d-4,C.silver)
  else
   b(1,3,d-1,w-2,5,1,7)
   for x=3,w-6,8 do b(x,6,d-1,4,1,1,C.silver)end
   if kind=='shop_counter_front'then
    b(23,11,3,7,2,7,14);b(24,13,3,5,4,2,16)
    b(25,14,5,3,2,1,7);b(24,13,7,5,1,2,3)
   end
  end
 end
 b=model('link_club_seat',16,16,6)
 legs(b,16,16,5);b(2,5,2,12,2,12,C.silver);b(3,7,3,10,1,10,7)
 b(2,7,1,12,7,2,14);b(3,8,3,10,5,1,7)
 for _,x in ipairs({1,13})do b(x,6,4,2,4,10,14)end
 b=model('trade_transfer_station',32,16)
 b(0,0,0,32,2,16,16);b(1,2,1,30,7,14,14)
 b(0,9,0,32,2,16,C.silver);b(2,11,2,28,1,12,C.navy)
 for _,x in ipairs({3,20})do
  b(x,12,2,9,2,8,16);b(x+1,14,3,7,1,6,7)
  b(x+2,15,4,5,2,4,5);b(x+2,17,5,5,1,2,4)
  b(x+3,16,7,3,1,1,16);b(x+4,16,8,1,1,1,4)
  b(x,12,12,9,1,2,3);b(x+1,13,12,3,1,1,12)
 end
 b(13,11,5,6,1,5,C.silver);b(14,12,6,4,1,3,8)
 b(14,13,7,4,1,1,7);b(12,4,15,8,3,1,8)
 b(13,5,15,6,1,1,7)
 b=model('link_battle_console',32,24)
 b(1,0,7,30,2,16,16);b(2,2,8,28,6,14,14)
 b(1,8,7,30,2,16,C.silver);b(3,10,9,26,1,12,C.navy)
 for _,x in ipairs({4,20})do
  b(x,11,10,8,1,8,14);b(x+1,12,11,6,1,6,8)
  b(x+2,13,13,4,1,1,7)
 end
 b(13,10,6,6,4,3,14);b(14,11,9,4,2,1,12)
 -- Link-club desktop and its original low stool occupy one native unit.
 b=model('club_terminal',16,32,6)
 b(1,0,1,2,8,13,C.walnut);b(13,0,1,2,8,13,C.walnut)
 b(0,8,0,16,2,16,14);b(2,10,1,12,10,4,14)
 b(3,11,5,10,7,1,8);b(4,14,6,8,1,1,7)
 b(2,10,10,12,1,4,3);b(4,0,22,2,6,6,C.walnut);b(10,0,22,2,6,6,C.walnut)
 b(3,6,20,10,2,10,7)
 b=model('open_book_table',16,8,10)
 b(0,7,0,16,3,8,C.oak);b(1,10,1,14,1,6,16)
 b(2,11,1,5,1,6,4);b(9,11,1,5,1,6,4)
 for z=2,5,2 do b(3,12,z,3,1,1,14);b(10,12,z,3,1,1,14)end
 b=model('dining_place',16,16,10)
 b(0,7,0,16,3,16,C.oak);b(3,10,3,10,1,10,14);b(4,11,4,8,1,8,4)
 b(6,12,6,4,1,4,15);b(12,10,1,2,4,2,7)
 b=model('office_station',32,32,6)
 for _,box in ipairs(P.models.office_terminal.boxes)do b(unpack(box))end
 for _,box in ipairs(P.models.wood_chair_south.boxes)do
  b(box[1],box[2],box[3]+16,box[4],box[5],box[6],box[7])
 end
 b=model('cell_separator',48,40)
 for x=4,43 do for z=2,37 do
  local r=((x-23.5)/20)^2+((z-19.5)/18)^2
  if r<1 then b(x,0,z,1,2,1,16);b(x,2,z,1,1,1,7)end
  if r<1 and r>.74 then b(x,29,z,1,2,1,14)end
 end end
 for _,x in ipairs({6,39})do for _,z in ipairs({7,30})do
  b(x,3,z,3,26,3,14);b(x+1,5,z+1,1,22,1,7)
 end end
 b(15,31,5,18,2,4,8);b(20,32,9,8,2,3,7)
 b(7,3,33,5,9,4,14);b(8,7,37,3,3,1,7)
 b=model('console_tall',16,32)
 for _,box in ipairs(P.models.console_cabinet.boxes)do
  b(box[1],box[2],box[3]+8,box[4],box[5],box[6],box[7])
 end
 -- Silph's lobby reuses terminal tiles for the pool coping. Join low stone
 -- modules across their full native footprint; water and collision stay native.
 b=model('fountain_rim',16,16,8)
 b(0,0,0,16,2,16,C.silver);b(1,2,1,14,3,14,14)
 b(0,5,0,16,1,16,C.navy);b(0,6,0,16,1,16,C.silver)
 b(1,7,1,14,1,14,14)
 b=model('utility_table',32,32,10);top(b,32,32)
 b=model('wood_crate',16,16)
 b(1,0,1,14,13,14,C.walnut)
 for i=0,3 do
  b(2+i*3,13,1,2,1,14,C.oak);b(2+i*3,1,0,2,11,1,C.oak)
  b(0,1,2+i*3,1,11,2,C.oak);b(15,1,2+i*3,1,11,2,C.oak)
  b(2+i*3,1,15,2,11,1,C.oak)
 end
 for _,y in ipairs({1,10})do
  b(0,y,0,16,2,1,14);b(0,y,15,16,2,1,14)
 end
 -- The robbed house stays damaged: a broken tabletop, toppled furniture,
 -- fallen pictures and the native trail. Nothing restores the story room.
 b=model('damaged_home_table',32,32,9)
 for _,leg in ipairs({{2,2},{27,2},{27,27}})do b(leg[1],0,leg[2],3,8,3,C.walnut)end
 b(1,7,1,30,1,13,C.walnut);b(17,7,14,14,1,17,C.walnut)
 for z=0,28,4 do
  local start=z<16 and 0 or ({[16]=3,[20]=9,[24]=13,[28]=16})[z]
  b(start,8,z,32-start,2,4,C.oak)
  b(math.min(25,start+3+z%5),10,z+1,4,1,1,C.walnut)
 end
 -- Splintered underside and fallen leg remain within the blocked table cells.
 b(3,1,21,3,2,9,C.walnut);b(7,0,25,7,1,2,C.oak)
 b(12,0,20,2,1,5,C.oak);b(2,0,30,8,1,1,C.oak)
 b=model('toppled_home_chair',16,16)
 b(3,0,3,10,2,9,C.walnut);b(4,2,4,8,1,7,10)
 b(1,1,1,2,3,14,C.oak);b(13,1,1,2,3,14,C.oak)
 b(3,1,1,10,2,2,C.oak);b(3,1,13,10,2,2,C.oak)
 for _,x in ipairs({4,10})do b(x,0,13,2,5,2,C.walnut)end
 b=model('toppled_home_plant',32,16)
 b(24,0,4,6,9,8,15);b(24,1,3,6,7,10,15)
 b(30,2,5,1,5,6,C.oak);b(22,0,2,2,9,12,C.oak)
 b(21,2,4,1,5,8,C.walnut);b(23,1,3,1,7,10,15)
 b(7,3,7,15,2,2,C.walnut)
 for _,leaf in ipairs({{1,3,4,9,2,4},{4,5,2,9,2,3},{3,1,10,10,2,4},
  {10,5,9,8,2,5},{12,2,2,7,2,4},{0,2,7,7,2,3}})do
  b(leaf[1],leaf[2],leaf[3],leaf[4],leaf[5],leaf[6],C.sage)
  b(leaf[1]+1,leaf[2]+leaf[5],leaf[3]+1,leaf[4]-2,1,1,12)
 end
 b(18,0,12,3,1,2,C.walnut);b(19,0,1,2,1,2,C.walnut)
 b=model('fallen_home_picture',8,8);P.models.fallen_home_picture.step=.25
 b(0,0,0,8,.5,8,C.walnut);b(1,.5,1,6,.25,6,4)
 b(2,.75,2,4,.25,2,8);b(2,.75,4,4,.25,2,12)
 b(3,1,2,1,.25,4,14)
 for _,kind in ipairs({'home_track_dark','home_track_scuff'})do
  b=model(kind,8,8);P.models[kind].step=.25
  local color=kind=='home_track_dark' and C.walnut or C.oak
  b(2,0,3,4,.25,3,color);b(3,0,6,2,.25,1,color)
  for _,x in ipairs({1,3,5})do b(x,0,1,2,.25,2,color)end
  if kind=='home_track_scuff'then
   b(2,.25,3,3,.25,1,14);b(3,.25,5,2,.25,1,C.silver)
  end
 end
 -- Mansion debris stays inside the native blocked cell. Low irregular stone
 -- chunks and broken timber replace the tall extruded monochrome tile card.
 for variant=0,2 do
  local add=model('mansion_rubble_'..variant,16,16)
  local dark,stone,edge=C.looseRock1 or 3,C.looseRock2 or C.silver,C.looseRock3 or 14
  local timber,split=C.oldBeam or C.walnut,C.oldBoard or C.oak
  local function r(x,y,z,w,h,d,color)
   for turn=1,variant do x,z,w,d=16-z-d,x,d,w end
   add(x,y,z,w,h,d,color)
  end
  r(1,0,2,13,1,12,dark)
  r(1,1,4,6,3,7,dark);r(2,4,5,4,1,5,stone)
  r(7,1,2,6,5,6,stone);r(8,6,3,4,2,4,edge)
  r(6,1,9,8,4,5,stone);r(8,5,10,5,1,3,edge)
  r(4,3,6,6,6,5,stone);r(5,9,7,4,2,3,edge)
  r(0,0,12,3,2,3,stone);r(13,0,4,3,3,4,dark)
  r(2,1,1,3,2,3,edge);r(3,2,12,2,2,2,dark)
  -- Two snapped beams, not a repeated crate or another usable terminal.
  r(2,5,3,2,2,8,timber);r(2,7,4,1,1,5,split)
  r(9,6,8,5,2,2,timber);r(10,8,8,3,1,1,split)
 end
 -- Compact generators retain each original16x16 machinery footprint.
 -- Stepped octagonal coils, cooling fins and inspection panels read as
 -- industrial equipment rather than another bank of computer desks.
 for variant=0,2 do
  local g=model('power_generator_'..variant,16,16)
  local metal=({C.sage,C.silver,C.navy})[variant+1]
  local copper=variant==1 and C.oak or 11
  g(0,0,0,16,2,16,16);g(1,2,1,14,2,14,C.silver)
  for _,x in ipairs({1,13})do for _,z in ipairs({1,13})do g(x,3,z,2,1,2,16)end end
  -- Octagonal core with full-depth stepped sides.
  g(3,4,2,10,10,12,metal);g(2,4,3,12,10,10,metal)
  g(1,6,5,14,6,6,metal)
  for y=5,13,2 do
   g(3,y,1,10,1,1,C.silver);g(3,y,14,10,1,1,C.silver)
   g(1,y,4,1,1,8,C.silver);g(14,y,4,1,1,8,C.silver)
  end
  -- Alternating copper windings around a dark insulated core.
  g(6,14,5,4,9,6,16)
  for y=15,21,2 do
   g(5,y,4,6,1,8,copper);g(4,y,5,8,1,6,copper)
   g(6,y+1,5,4,1,6,16)
  end
  g(6,23,6,4,2,4,C.silver);g(7,25,7,2,1,2,16)
  -- Front service panel, amber status lens and foot-level cable socket.
  g(5,5,14,6,7,1,16);g(6,7,15,4,4,1,C.navy)
  g(7,9,15,2,1,1,variant==2 and 12 or 11)
  g(6,5,15,1,1,1,C.silver);g(9,5,15,1,1,1,C.silver)
  g(2,4,12,2,2,3,16);g(2,4,15,2,2,1,C.oak)
 end
 -- The ruined mansion reuses FACILITY's terminal mask as long barriers.
 -- Closed wooden storage cabinets fit those rows without implying usable PCs.
 -- Keep the complete native 16x16 footprint and 16-pixel barrier height.
 b=model('mansion_storage_cabinet',16,16)
 b(0,0,0,16,2,16,C.walnut);b(0,2,0,16,12,16,C.oak)
 b(0,14,0,16,2,16,C.walnut);b(1,15,1,14,1,14,C.oak)
 for _,z in ipairs({0,15})do
  for _,x in ipairs({1,8})do
   b(x,3,z,6,10,1,C.walnut);b(x+1,4,z,4,8,1,C.oak)
  end
  b(5,7,z,1,2,1,11);b(10,7,z,1,2,1,11)
 end
 -- Compact steel terminals, with the original 16-pixel barrier height.
 b=model('facility_terminal',16,16)
 b(0,0,0,16,2,16,16);b(0,2,0,16,5,16,C.silver)
 b(0,7,0,16,9,7,14);b(1,8,7,14,7,1,3)
 b(2,9,8,12,5,1,C.navy);b(3,11,9,5,1,1,7);b(3,9,9,8,1,1,12)
 b(1,7,9,14,1,6,16)
 for x=2,12,2 do for z=10,12,2 do b(x,8,z,1,1,1,14)end end
 b(13,8,13,1,1,1,12);b(2,3,16-1,8,2,1,16)
 b(12,3,16-1,2,2,1,7);b(0,15,0,16,1,7,C.silver)
 -- Full-width faces join adjoining maze cells without gaps or false handles.
 b=model('facility_partition',16,16)
 b(0,0,0,16,2,16,16);b(0,2,0,16,12,16,C.silver)
 b(0,14,0,16,2,16,16)
 for _,z in ipairs({0,15})do
  b(1,4,z,14,8,1,C.navy);b(2,5,z,12,6,1,14)
  b(0,2,z,1,12,1,16);b(15,2,z,1,12,1,16)
 end
 for _,x in ipairs({0,15})do
  b(x,4,1,1,8,14,C.navy);b(x,5,2,1,6,12,14)
 end
 -- A home desk with its native open front-right walking cell retained.
 b=model('warden_desk',32,32)
 b(1,0,5,2,9,15,C.walnut);b(29,0,5,2,9,15,C.walnut)
 b(1,0,19,13,9,12,C.walnut);b(2,2,30,11,6,1,C.oak)
 b(6,5,31,3,1,1,11);b(0,9,4,32,2,17,C.oak)
 b(1,11,5,30,1,15,2)
 b(8,12,7,4,2,4,16);b(3,14,5,15,10,3,14)
 b(4,15,8,13,8,1,3);b(5,16,9,11,6,1,C.navy)
 b(6,19,10,7,1,1,7);b(6,17,10,4,1,1,12)
 b(3,12,15,15,1,4,16)
 for x=4,16,2 do b(x,13,16,1,1,1,14)end
 b(22,12,8,7,1,9,4);b(23,13,10,5,1,1,C.navy)
 b(25,14,10,1,1,5,1)
 -- Native text describes photos, fossils and old merchandise, so this is a
 -- wooden collector's cabinet, not a laboratory reactor.
 b=model('warden_display',32,32)
 b(1,0,4,30,2,27,16);b(1,2,4,30,7,27,C.walnut)
 b(0,9,3,32,2,29,C.oak);b(2,11,4,28,1,26,2)
 b(1,11,4,2,22,25,C.walnut);b(29,11,4,2,22,25,C.walnut)
 b(3,11,4,26,21,2,C.oak);b(1,32,4,30,2,25,C.oak)
 b(3,21,5,26,1,24,C.oak);b(3,22,6,26,1,22,2)
 for _,x in ipairs({5,18})do
  b(x,24,22,9,7,1,C.walnut);b(x+1,25,23,7,5,1,4)
  b(x+2,26,24,5,3,1,7);b(x+3,26,25,3,2,1,12)
 end
 -- Fossil relief on a little plinth; fixed exhibit, no collectible ownership.
 b(5,12,20,10,1,10,C.navy);b(6,13,23,8,7,2,2)
 for _,v in ipairs({{1,1},{2,0},{3,0},{4,1},{4,2},{4,3},{3,4},{2,4},{1,3},{2,2}})do
  b(7+v[1],14+v[2],25,1,1,1,C.walnut)
 end
 b(20,12,22,5,1,7,C.navy);b(20,13,23,6,4,5,11)
 b(21,17,24,4,1,3,2);b(22,14,28,2,2,1,C.walnut)
 b(7,4,31,6,1,1,11);b(20,4,31,6,1,1,11)
 for variant=0,2 do
  b=model('warden_specimen_'..variant,16,16)
  b(2,0,2,12,1,12,16);b(3,1,3,10,6,10,C.walnut)
  b(2,7,2,12,1,12,C.oak);b(3,8,3,10,1,10,2)
  if variant==0 then -- old ball merchandise
   for x=0,4 do for y=0,4 do for z=0,4 do
    if (x-2)^2+(y-2)^2+(z-2)^2<=6 then
     b(5+x,9+y,5+z,1,1,1,y<2 and 4 or y==2 and 3 or 1)
    end
   end end end
   b(7,11,10,1,1,1,4)
  elseif variant==1 then -- fossil specimen
   b(4,9,4,8,2,8,2);b(5,11,5,6,1,6,C.oak)
   for _,v in ipairs({{0,0},{1,0},{2,0},{3,1},{3,2},{2,3},{1,3},{0,2},{1,1}})do
    b(6+v[1],12,6+v[2],1,1,1,C.walnut)
   end
  else -- amber souvenir
   b(5,9,5,6,5,6,11);b(6,14,6,4,1,4,2)
   b(7,11,11,2,2,1,C.walnut);b(6,12,11,1,1,1,4)
  end
  b(6,5,13,4,1,1,2)
 end
 -- Coin-operated observation binoculars: two lenses, pivot and one pedestal.
 b=model('observation_binoculars',16,24)
 b(3,0,6,10,2,14,16);b(5,2,8,6,2,10,C.silver)
 b(7,4,11,2,13,4,C.navy);b(6,15,10,4,3,6,C.silver)
 b(3,17,11,10,2,3,C.silver)
 for _,x in ipairs({1,9})do
  -- Bevelled circular housings rather than two rectangular boxes.
  b(x+1,16,6,4,6,10,C.navy);b(x,17,6,6,4,10,C.navy)
  b(x+1,17,5,4,4,1,C.silver);b(x+2,18,4,2,2,1,8)
  b(x+1,17,16,4,4,2,3);b(x+2,18,18,2,2,1,7)
  b(x+1,21,7,4,1,8,14)
 end
 b(6,11,15,4,3,1,C.silver);b(7,12,16,2,1,1,3)
 b=model('captain_chair',16,24,6)
 for _,box in ipairs(P.models.wood_chair_north.boxes)do
  b(box[1],box[2],box[3]+8,box[4],box[5],box[6],box[7])
 end
 -- All additions share the existing Voxel Items switch and GPU fallback.
 for _,p in ipairs(patterns)do
  if p.complete then table.insert(F.patterns,1,p)else F.patterns[#F.patterns+1]=p end
 end
 -- Diner strips run after its complete tables, which share some native tiles.
 local strips={}
 for _,p in ipairs(F.patterns)do
  if p.sets.MUSEUM and p.kind:match('^counter_')then
   strips[#strips+1]={kind=p.kind,sets={GATE=true,FOREST_GATE=true},tiles=p.tiles}
  end
  if p.maps and p.sets.LOBBY and p.kind:match('^counter_')then
   strips[#strips+1]={kind=p.kind,sets=p.sets,tiles=p.tiles,maps={CELADON_DINER=true}}
  end
 end
 for _,p in ipairs(strips)do F.patterns[#F.patterns+1]=p end
end
