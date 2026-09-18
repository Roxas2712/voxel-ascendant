-- Static, native-footprint landmarks. These boxes join the building mesh;
-- no live actors, individual lamps or per-frame sculpture construction.
local V=...
local L={}
local gyms={PEWTER_GYM='ROCK',CERULEAN_GYM='WATER',VERMILION_GYM='ELECTRIC',
 CELADON_GYM='GRASS',FUCHSIA_GYM='POISON',SAFFRON_GYM='PSYCHIC',
 CINNABAR_GYM='FIRE',VIRIDIAN_GYM='GROUND'}
function L.identity(template,doors)
 if template=='route_22_gate'then return 'league_gate'end
 for _,door in ipairs(doors)do local dest=door.dest or ''
  if dest=='FIGHTING_DOJO'then return 'dojo','FIGHTING'end
  if gyms[dest]then return 'gym',gyms[dest]end
  if dest=='BIKE_SHOP'then return 'bike'end
  if dest:match('_MART$')or dest:match('^CELADON_MART_')then return 'mart'end
 end
 if template=='museum'then return 'museum'end
end
local function lettering(b,text,x,y,z,color,scale)
 local glyphs=V.require('Gen1VoxelSigns').glyphs
 for i=1,#text do for row,line in ipairs(glyphs[text:sub(i,i)]or{})do
  local col=1
  while col<=3 do
   if line:sub(col,col)=='1'then
    local stop=col+1;while stop<=3 and line:sub(stop,stop)=='1'do stop=stop+1 end
    b(x+((i-1)*4+col-1)*scale,y+(5-row)*scale,z,(stop-col)*scale,scale,1,color);col=stop
   else col=col+1 end
  end
 end end
end
local function wheel(b,x,y,z,C)
 -- Octagonal tread and inset rim leave a real open center, not a square tile.
 for _,run in ipairs({{-5,-9,10,2},{-7,-7,3,2},{4,-7,3,2},
  {-9,-5,2,10},{7,-5,2,10},{-7,5,3,2},{4,5,3,2},{-5,7,10,2}})do
  b(x+run[1],y+run[2],z,run[3],run[4],4,3)
 end
 local silver=C.silver or 14
 b(x-4,y-7,z+1,8,1,2,silver);b(x-4,y+6,z+1,8,1,2,silver)
 b(x-7,y-4,z+1,1,8,2,silver);b(x+6,y-4,z+1,1,8,2,silver)
 b(x-1,y-6,z+1,2,12,2,silver);b(x-6,y-1,z+1,12,2,2,silver)
end
function L.add(a,b,g,C,P,doors,w,d,front,height)
 local role,gymType=L.identity(a.template,doors)
 if not role then return end
 a.buildingRole,a.gymType=role,gymType
 local start,litStart=#a.boxes,#P.models[a.glassKind].boxes
 local blue=C.navy or 38;local bone=4;local silver=C.silver or 14
 if role=='league_gate'then
  -- A single large, cap-inspired League L above the entrance. All runs join
  -- the existing facade/window meshes and remain inside the native footprint.
  local cx=math.floor(w/2);local y=height+3;local z=front+1
  b(cx-16,height,z,4,5,3,blue);b(cx+12,height,z,4,5,3,blue)
  b(cx-18,y,z,36,42,3,blue);b(cx-21,y+3,z,42,36,3,blue)
  b(cx-17,y+2,z+3,34,38,1,4);b(cx-19,y+4,z+3,38,34,1,4)
  local symbol={'00000000111','00000001110','00000011100','00000111000',
    '00001110000','00011100000','00111000000','01110000000',
    '11111111111','01111111110','00000000000'}
  for row,line in ipairs(symbol)do
   local first,last=line:find('1+');if first then
    g(cx-16+(first-1)*3,y+4+(11-row)*3,z+4,(last-first+1)*3,3,2,C.roofGreen or 12)
   end
  end
  a.landmarkEmblem='league-L';a.landmarkSignBase=y
 elseif role=='mart'then
  local shopBlue=C.martBlue or 8
  -- Broad striped awning and display windows distinguish the shop at once.
  for x=4,w-8,4 do b(x,25,front,4,3,d-front,math.floor(x/4)%2==0 and 4 or shopBlue)end
  b(4,24,d-2,w-8,2,2,shopBlue)
  for x=7,w-12,16 do
   local clear=true;for _,door in ipairs(doors)do if door.side=='south'and math.abs(x+4-door.at)<14 then clear=false end end
   if clear then
    g(x,10,front+2,8,11,1,7)
    for n=0,2 do b(x+n*3,11,front+3,2,4,2,({1,11,12})[n+1]);b(x+n*3,15,front+3,1,1,1,4)end
   end
  end
  -- Compact Center-style sign, but a raised Pokedollar glyph identifies the
  -- shop. Horizontal runs share the existing emissive window mesh at night.
  local cx=math.floor(w/2)
  -- Keep the complete currency symbol above the roof cornice. A low front
  -- plate crossed the eave, hiding both horizontal bars in normal views.
  local signBase=height+1
  a.landmarkSignBase=signBase
  b(cx-10,signBase,d-4,20,18,2,4)
  b(cx-8,signBase+2,d-2,16,14,1,blue)
  local symbol={'00111111000','00110001100','00110000110','00110000110',
    '00110001100','00111111000','11111111100','00110000000',
    '11111111100','00110000000','00110000000','00110000000'}
  for row,line in ipairs(symbol)do
   local col=1
   while col<=#line do
    if line:sub(col,col)=='1'then
     local stop=col+1;while stop<=#line and line:sub(stop,stop)=='1'do stop=stop+1 end
     g(cx-6+col-1,signBase+15-row,d-1,stop-col,1,1,11);col=stop
    else col=col+1 end
   end
  end
  a.landmarkEmblem='pokedollar'
 elseif role=='museum'then
  -- A full freestanding saurian skeleton, visible above the pediment.
  local floor=48;local z=math.floor(d/2)
  b(12,floor-2,z-14,w-24,2,28,silver)
  for x=30,w-44,8 do
   local y=floor+20+math.floor((x-30)/24)
   b(x,y,z-2,7,3,4,bone)
   for _,side in ipairs({-1,1})do
    b(x,y-2,z+side*5-1,2,3,5,bone)
    b(x,y-10,z+side*10-1,2,9,2,bone)
    b(x,y-12,z+side*6-1,2,2,5,bone)
   end
  end
  -- Separate hind legs and feet, with thin exhibition supports.
  for _,x in ipairs({42,w-54})do for _,side in ipairs({-1,1})do
   b(x,floor+8,z+side*8-1,4,12,3,bone);b(x-3,floor+2,z+side*9-1,4,8,3,bone)
   b(x-4,floor,z+side*9-1,10,2,4,bone)
  end end
  -- Long tapering tail and uplifted neck lead to an open-jawed skull.
  for i=0,5 do b(28-i*3,floor+20-i*2,z-1,5,2,3,bone)end
  for i=0,4 do b(w-49+i*4,floor+23+i*2,z-2,6,3,4,bone)end
  b(w-34,floor+30,z-5,20,8,10,bone)
  b(w-29,floor+32,z+5,5,4,1,3);b(w-29,floor+32,z-6,5,4,1,3)
  b(w-33,floor+26,z-5,18,2,10,bone)
  for x=w-30,w-16,4 do b(x,floor+28,z+4,1,2,1,bone);b(x,floor+28,z-5,1,2,1,bone)end
  for _,x in ipairs({18,w-24})do b(x,floor,z-2,2,15,2,blue)end
  for _,x in ipairs({18,w-24})do g(x,floor, z+11,6,2,2,11)end
 elseif role=='bike'then
  a.landmarkDetail='bicycle-shop';a.bicyclePlacement='roof-only'
  -- Large open bicycle silhouette above the roof, readable from both sides.
  local y=43;local cx=math.floor(w/2);local z=24
  b(6,39,16,w-12,3,18,blue)
  for _,wx in ipairs({cx-17,cx+17})do
   wheel(b,wx,y+9,z,C)
  end
  b(cx-17,y+8,z+4,18,2,2,11);b(cx-7,y+20,z+4,19,2,2,11)
  for i=0,11 do
   b(cx-17+math.floor(i*10/12),y+9+i,z+4,2,2,2,11)
   b(cx-math.floor(i*7/12),y+9+i,z+4,2,2,2,11)
   b(cx+math.floor(i*11/12),y+9+i,z+4,2,2,2,11)
   b(cx+17-math.floor(i*6/12),y+9+i,z+4,2,2,2,11)
  end
  b(cx-8,y+20,z+4,2,5,2,11);b(cx-12,y+24,z+3,10,2,4,blue)
  b(cx+10,y+20,z+4,2,7,2,11);b(cx+8,y+26,z+3,8,2,3,blue)
  b(cx-2,y+7,z+6,4,4,1,silver);b(cx,y+6,z+7,5,1,1,3)
  g(cx+15,y+23,z+4,2,2,2,4)
 else
  local text=role=='dojo'and'DOJO'or(V.require('Gen1VoxelSigns').language()=='de'and'ARENA'or'GYM')
  a.landmarkLabel=text
  local labelW=(#text*4-1)*2
  b(6,36,front-1,labelW+4,15,3,blue)
  lettering(g,text,8,39,front+2,4,2)
  b(6,51,front-2,labelW+4,2,5,C.slate or 16)
  local sx=w-40;local sz=front-10
  b(sx-2,36,sz-4,36,3,16,silver)
  V.require('VoxelTypeEmblems').add(b,g,gymType,sx,39,sz)
 end
 a.landmarkBoxes=#a.boxes-start;a.landmarkLitBoxes=#P.models[a.glassKind].boxes-litStart
 local top=0;for _,part in ipairs({a,P.models[a.glassKind]})do for _,box in ipairs(part.boxes)do top=math.max(top,box[2]+box[5])end end
 a.landmarkHeight=top
 for _,part in ipairs({a,P.models[a.glassKind]})do part.offsetY=-top;part.frameH=top+d end
end
return L
