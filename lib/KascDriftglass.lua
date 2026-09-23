-- Research landing around the existing Driftglass routes. Native NPCs,
-- prism admission and return travel retain their original scripts.
local V=...
local M={}
function M.matches(map)
 local d=map and map.def
 if not(d and (map.id or d.id)=='KANTO_ASCENDANT_DRIFTGLASS'and d.index==1900
  and d.tileset=='OVERWORLD'and d.width==12 and d.height==10 and d.generation~=2)then return false end
 local seam,boat=false,false
 for _,o in ipairs(d.objects or{})do
  seam=seam or(o.name=='DRIFTGLASS_PRISM_SEAM'and o.x==12 and o.y==9)
  boat=boat or(o.name=='DRIFTGLASS_RETURN_BOAT'and o.x==8 and o.y==15)
 end
 return seam and boat
end
function M.prism(P)
 local kind='kasc_driftglass_prism'
 if not P.models[kind]then
  local c=P.decorColors;local boxes={}
  local function b(...)boxes[#boxes+1]={...}end
  b(1,0,1,14,2,14,c.slate);b(3,2,3,10,2,10,c.navy)
  -- Faceted crystal, bounded by the original actor cell, no billboard wall.
  for i=0,8 do
   local width=math.max(2,8-math.abs(i-4))
   b(8-width/2,4+i*2,8-width/2,width,2,width,i%3==0 and c.silver or c.silphGlass)
  end
  b(3,4,4,2,7,2,c.purple);b(11,4,10,2,5,2,c.purple)
  P.models[kind]={boxes=boxes,directBoxes=true,step=1,frameW=16,frameH=40,depth=16,offsetY=-24}
 end
 return kind
end
function M.find(P,map)
 if not M.matches(map)then return {}end
 -- The only two interior solid cells anchor the desk and cantilever. Reject
 -- changed maps instead of introducing invisible collision over open ground.
 if map:isWalkableCell(10,13)or map:isWalkableCell(11,13)then return {}end
 local c=P.decorColors;local kind='kasc_driftglass_research_station'
 local m={boxes={},directBoxes=true,step=1,frameW=64,frameH=96,depth=48,offsetY=-48,
  replacesGround=true,support=0,actorSurface=true,groundAt=function()return 48 end}
 local function b(...)m.boxes[#m.boxes+1]={...}end
 -- Native counter cells: x10/11,y13. The researcher at 9,11 and both
 -- approaches to the return sailor stay clear below the 30-unit canopy.
 b(33,0,33,30,2,14,c.slate);b(35,2,35,26,7,10,c.navy)
 b(33,9,33,30,2,14,c.silver)
 b(38,11,38,8,6,2,c.navy);b(39,12,37.8,6,4,.2,7)
 b(49,11,39,10,1,5,c.slate);b(51,12,40,2,.3,2,11)
 for _,x in ipairs({33,61})do
  b(x,0,44,2,31,2,c.navy)
  b(x-1,29,4,4,2,42,c.silver)
 end
 -- Open slatted canopy: enough gaps to see the station in the diorama.
 for x=2,60,8 do b(x,31,4,3,1,42,c.silphGlass)end
 b(1,30,4,62,2,2,c.navy);b(1,30,44,62,2,2,c.navy)
 -- A compact receiver on the anchored rear beam.
 b(48,32,42,2,10,2,c.silver);b(42,40,42,14,1,1,c.silver)
 b(44,38,40,10,1,1,c.silver)
 P.models[kind]=m
 local dock='kasc_driftglass_landing'
 if not P.models[dock]then
  local deck={boxes={},directBoxes=true,step=1,frameW=48,frameH=104,depth=80,offsetY=-24,
   replacesGround=true,waterUnderlaySide='left',support=0,
   groundAt=function(_,z)return z<16 and 35 or 20 end}
  local function b(...)deck.boxes[#deck.boxes+1]={...}end
  -- A flush landing at the existing sailor, with a narrow timber jetty.
  -- Return interaction, native walkability and arrival coordinates stay owned
  -- by KASC; the low rope rail marks the blocked end of the visual gangway.
  for z=0,44,4 do b(0,.04,z,18,.8,3.6,c.oldBoard)end
  for _,x in ipairs({0,16})do
   for _,z in ipairs({12,34,46})do b(x,-5,z,2,12,2,c.oldBeam)end
   b(x,5,14,1,1,31,c.oak)
  end
  b(0,6,28,18,1,1,c.oak)
  -- Closed stepped launch hull moored alongside the pier in native water.
  for z=32,68,4 do
   local inset=(z==32 or z==68) and 5 or (z==36 or z==64) and 2 or 0
   b(22+inset,-3,z,24-inset*2,4,4,c.navy)
   b(22+inset,1,z,24-inset*2,1,4,c.oak)
  end
  b(22,2,40,2,5,24,c.walnut);b(44,2,40,2,5,24,c.walnut)
  b(25,2,36,18,5,2,c.walnut);b(27,2,67,14,5,2,c.walnut)
  for _,z in ipairs({44,58})do b(24,5,z,20,2,3,c.oldBoard)end
  b(42,7,43,1,1,23,c.oak);b(40,7,60,3,1,8,c.oak)
  b(17,3,39,8,1,1,c.silver)
  P.models[dock]=deck
 end
 local enabled=function()return V.require('VoxelItems').setting:get()end
 return {{kind=kind,tx=16,ty=22,w=8,h=6,voxelOnly=true,enabled=enabled},
  {kind=dock,tx=16,ty=30,w=6,h=10,voxelOnly=true,enabled=enabled}}
end
return M
