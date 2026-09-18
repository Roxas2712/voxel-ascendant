-- The native Nugget Bridge spans Route24 and the north edge of Cerulean.
-- Preserve its four-tile walking deck and all trainer/event coordinates.
local V=...
local B={}
local spans={ROUTE_24={width=10,height=18,x=20,y0=32,y1=72},
 CERULEAN_CITY={width=20,height=18,x=40,y0=0,y1=8}}
function B.span(map)
 local s=map and spans[map.id];local d=map and map.def
 if s and d and d.generation~=2 and d.tileset=='OVERWORLD'and d.width==s.width and d.height==s.height then return s end
end
-- Two 16px landings at either end, joined by a 12px raised deck.
-- Route24's south edge and Cerulean's north edge share the level section.
function B.section(map,y)
 local s=B.span(map);if not s then return end
 if map.id=='ROUTE_24' then
  if y==s.y0 then return 'north_low' elseif y==s.y0+2 then return 'north_high' end
  if y==s.y1-2 then return 'seam_south' end
 else
  if y==s.y0 then return 'seam_north' end
  if y==s.y1-4 then return 'south_high' elseif y==s.y1-2 then return 'south_low' end
 end
 return 'level'
end
local function top(section,z)
 local tread=z<5 and 1 or z<10 and 2 or 3
 if section=='north_low' then return tread*2 end
 if section=='north_high' then return 6+tread*2 end
 if section=='south_high' then return 14-tread*2 end
 if section=='south_low' then return 8-tread*2 end
 return 12
end
function B.railAt(map,x,y)
 local s=B.span(map)
 if not s or y<s.y0 or y>=s.y1 or y%2~=0 then return end
 if x==s.x-2 then return 'left'elseif x==s.x+4 then return 'right'end
end
function B.register(P,F)
 local C=P.decorColors
 local stone=C.paperWindow or 4;local shade=C.oak;local gold=11
 local function model(kind,w,d)
  local m={terrain=true,boxes={},frameW=w,depth=d,frameH=d+28,offsetY=-28,step=1};P.models[kind]=m
  return m,function(x,y,z,bw,bh,bd,c)
   assert(x>=0 and z>=0 and x+bw<=w and z+bd<=d,'Nugget footprint')
   m.boxes[#m.boxes+1]={x,y,z,bw,bh,bd,c}
  end
 end
 local sections={'level','north_low','north_high','south_high','south_low','seam_north','seam_south'}
 for _,section in ipairs(sections)do for _,side in ipairs({'left','right'})do for variant=0,1 do
  local m,b=model('nugget_rail_'..side..'_'..variant..'_'..section,16,16)
  local raw=b;local rise=top(section,8)
  b=function(x,y,z,bw,bh,bd,c)raw(x,y+rise,z,bw,bh,bd,c)end
  m.frameH=56;m.offsetY=-40;m.waterUnderlaySide=side
  local x=side=='left'and 10 or 0
  -- Stone coping and supporting pier on the blocked border footprint.
  b(x,-20,0,6,23,16,stone);b(x,3,0,6,1,16,shade)
  b(x,4,0,6,2,16,stone)
  local rail=side=='left'and 14 or 0
  b(rail,6,0,2,1,16,gold)
  -- A gold half-arch, with vertical infill and a clearly open center.
  for z=0,14,2 do
   local h=2+math.floor(math.sqrt(math.max(0,49-(z+1-8)^2)))
   b(rail,7+h,z,2,2,2,gold)
   if z%4==0 then b(rail,7,z,1,h,1,gold)end
  end
  if variant==0 then
   b(x,6,0,6,10,5,stone);b(x,16,0,6,2,6,shade)
   b(x,18,0,6,1,6,stone)
   -- Faceted golden sphere; no per-voxel sphere mesh at draw time.
   b(x+1,19,1,4,1,4,gold);b(x,20,0,6,3,6,gold);b(x+1,23,1,4,1,4,gold)
  end
 end end end
 for _,section in ipairs(sections)do for variant=0,1 do
  local m,b=model('nugget_deck_'..variant..'_'..section,32,16)
  m.support=function(_,z)return top(section,z)end
  m.supportRelative=true;m.actorSurface=true
  m.supportSeam=section=='seam_north'and'north'or section=='seam_south'and'south'or nil
  if section:find('low')or section:find('high')then
   for i,run in ipairs({{0,5},{5,5},{10,6}})do
    local z,depth=run[1],run[2];local h=top(section,z)
    b(0,-4,z,32,h+3,depth,shade)
    b(0,h-1,z,32,1,depth,stone)
    local nose=section:find('north')and z or z+depth-1
    b(1,h-1,nose,30,1,1,gold)
   end
  else
   b(0,-4,0,32,15,16,shade)
   for z=0,12,4 do for x=0,28,4 do
    b(x,11,z,4,1,4,(x/4+z/4+variant)%7==0 and gold or stone)
   end end
   b(0,11,0,1,1,16,gold);b(31,11,0,1,1,16,gold)
  end
 end end
 local function on()return V.require('Gen1OutdoorScenery').stone:get()end
 -- Register before the generic tree patterns, so these native border trees
 -- become railings rather than a canopy that hides the river.
 F.patterns[#F.patterns+1]={kind='nugget_rail_left_0_level',sets={OVERWORLD=true},
  tiles={{42,43},{58,59}},voxelOnly=true,groundTile=20,enabled=on,
  guard=function(map,x,y)
   return B.railAt(map,x,y)~=nil and not map:isWalkableCell(x/2,y/2)
    and not map:isWarpTileCell(x/2,y/2)
  end,
  variant=function(map,x,y)return 'nugget_rail_'..B.railAt(map,x,y)..'_'..(math.floor(y/2)%2)..'_'..B.section(map,y)end}
 F.patterns[#F.patterns+1]={kind='nugget_deck_0_level',sets={OVERWORLD=true},
  tiles={{60,60,60,60},{60,60,60,60}},voxelOnly=true,groundTile=60,enabled=on,
  guard=function(map,x,y)
   local s=B.span(map)
   return s and x==s.x and y>=s.y0 and y<s.y1 and y%2==0
    and map:isWalkableCell(x/2,y/2)and map:isWalkableCell(x/2+1,y/2)
    and not map:isWarpTileCell(x/2,y/2)and not map:isWarpTileCell(x/2+1,y/2)
  end,
  variant=function(map,_,y)return 'nugget_deck_'..(math.floor(y/2)%2)..'_'..B.section(map,y)end}
end
return B
