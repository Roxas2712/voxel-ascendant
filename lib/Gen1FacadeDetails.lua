-- Small shared voxel reliefs give native footprints a readable identity.
-- All geometry stays inside the building bounds and uses the existing atlas.
local D={}
function D.style(C,theme,tx,ty)
 -- Mix coarse and fine coordinates: native rows spaced 16 tiles apart
 -- must not all resolve to the same facade or roof.
 local x,y=math.floor(tx/4),math.floor(ty/4)
 local n=(x*3+y*5+math.floor(x/4)+math.floor(y/4)+theme)%4
 local r=(x+y*3+math.floor(x/3)+math.floor(y/3)+theme)%4
 local materials={'plaster','timber','stone','half_timber'}
 local walls={C.warmBrick or 14,C.oak or 37,C.stone or 14,C.sage or 40}
 local roofs={C.clay or 13,C.roofGreen or 10,C.slate or 16,C.walnut or 36}
 if theme==6 then
  walls={C.oldPlaster or 14,C.oldTimber or 36,C.looseRock1 or 16,C.oldBoard or 37}
  roofs={C.oldShingle or 16,C.fadedPlum or 39,C.oldBeam or 36,C.slate or 16}
 elseif theme==3 then walls[1]=C.silver or 41;walls[4]=C.warmBrick or 14
 elseif theme==10 then walls[1]=4;walls[4]=C.warmBrick or 14 end
 return {variant=n,material=materials[n+1],wall=walls[n+1],roof=roofs[r+1],
  roofShape=n==1 and 'side_gable' or n==2 and 'hipped' or 'gable'}
end
function D.add(a,b,g,C,doors,w,d,front,theme,tx,ty,house,museum)
 local variant=a.facadeVariant or (math.floor(tx/4)*3+math.floor(ty/4)*5+theme)%4
 a.facadeVariant=variant
 local timber=C.oak or 37
 local dark=C.walnut or 36
 local function doorNear(side,center,margin)
  for _,door in ipairs(doors)do
   if door.side==side and math.abs(center-door.at)<door.width/2+margin then return true end
  end
  return false
 end
 local function planter(x,z)
  b(x,7,z,12,3,4,timber);b(x+1,10,z+1,10,1,2,dark)
  for n=0,2 do
   local xx=x+2+n*3
   b(xx,11,z+1,1,3+(n+variant)%2,1,12)
   b(xx-1,14+(n+variant)%2,z,3,2,3,({1,11,39,4})[(n+variant)%4+1])
  end
 end
 if house then
  -- Surface relief follows the building's material, not a random overlay.
  if a.wallMaterial=='timber' then
   for y=4,24,4 do
    b(2,y,1,w-4,1,2,dark)
    b(1,y,3,2,1,front-3,dark);b(w-3,y,3,2,1,front-3,dark)
    for x=3,w-4,4 do
     if not doorNear('south',x+2,4)then b(x,y,front,4,1,1,dark)end
    end
   end
  elseif a.wallMaterial=='stone' then
   for y=4,24,5 do
    local shift=(math.floor(y/5)%2)*3
    for x=4+shift,w-8,8 do
     if not doorNear('south',x+3,5)then b(x,y,front,6,3,1,C.silver or 41)end
     b(x,y,1,6,3,1,C.silver or 41)
    end
   end
  end
  -- Flower boxes belong under windows, never over the doormat.
  for x=7,w-12,16 do
   if not doorNear('south',x+4,8) then
    if theme~=6 then planter(x-2,front+2)end
    if variant%2==1 then
     b(x-3,12,front+2,2,10,2,dark);b(x+9,12,front+2,2,10,2,dark)
    end
   end
  end
  -- The back is visible in free camera and from adjoining maps too.
  for x=8,w-15,20 do if not doorNear('north',x+5,8)then
   b(x-1,12,0,12,13,2,timber);g(x,13,0,10,11,1,theme==6 and (C.dustyGlass or 10)or 7)
   b(x+4,13,0,2,11,1,timber);b(x,18,0,10,1,1,timber)
  end end
  -- Regional timber bands and offset attic windows break repeated boxes.
  if variant==0 or variant==3 then
   b(2,24,front+1,w-4,2,2,dark)
   for x=6,w-7,18 do if not doorNear('south',x,4)then b(x,3,front+1,2,21,2,timber)end end
  end
  if w>=40 and a.roofShape=='gable' then
   local x=math.floor(w/2)-4
   b(x-1,28,front+1,10,8,2,timber);g(x,29,front+2,8,6,1,7)
  end
 end
 if museum then
  a.landmarkDetail='fossil-museum'
  -- Layered pediment and columns; a fossil relief identifies the museum
  -- at play scale without adding giant text to an ordinary building sign.
  for tier=0,4 do b(4+tier*4,36+tier*2,2,w-8-tier*8,2,d-4,14)end
  for _,x in ipairs({5,15,w-19,w-9})do
   if not doorNear('south',x+2,3)then
    b(x-1,3,front+1,6,3,4,4);b(x,6,front+1,4,19,3,14);b(x-1,25,front+1,6,3,4,4)
   end
  end
  local cx=math.floor(w/2)
  b(cx-16,29,front+2,32,13,2,dark)
  -- Curled fossil: stepped shell outline, ribs and tail in warm stone.
  for _,r in ipairs({{-9,1,12,2},{-12,3,3,5},{-9,8,12,2},{3,3,3,5},{-5,4,7,2},{-5,6,2,2},{6,1,7,2}})do
   b(cx+r[1],30+r[2],front+4,r[3],r[4],1,4)
  end
 end
end
return D
