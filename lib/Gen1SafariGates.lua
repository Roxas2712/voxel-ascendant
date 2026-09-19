-- Open wayfinding portals on the native Safari boundary warps. No changes
-- to connections, spawn coordinates, triggers or walking/collision data.
local V=...
local M={}
local regions={SAFARI_ZONE_CENTER={'CENTER','MITTE'},SAFARI_ZONE_NORTH={'NORTH','NORD'},
 SAFARI_ZONE_EAST={'EAST','OST'},SAFARI_ZONE_WEST={'WEST','WEST'},SAFARI_ZONE_GATE={'EXIT','AUSGANG'}}
function M.groups(map)
 local d=map and map.def
 if not d or d.generation==2 or d.tileset~='FOREST' or not regions[map.id]
  or map.id=='SAFARI_ZONE_GATE' then return {} end
 local buckets={}
 for _,w in ipairs(d.warps or{})do
  local side=w.y==0 and 'north' or w.y==d.height*2-1 and 'south'
   or w.x==0 and 'west' or w.x==d.width*2-1 and 'east'
  if side and regions[w.destMap] and map:isWalkableCell(w.x,w.y)then
   local key=side..':'..w.destMap
   local group=buckets[key]or{};buckets[key]=group;group[#group+1]=w
  end
 end
 local out={}
 for key,warps in pairs(buckets)do
  local side=key:match('^(.-):');local along=(side=='north'or side=='south')and 'x'or'y'
  table.sort(warps,function(a,b)return a[along]<b[along]end)
  local i=1
  while i<=#warps do
   local first,last=warps[i],warps[i];i=i+1
   while i<=#warps and warps[i][along]==last[along]+1 do last=warps[i];i=i+1 end
   local count=last[along]-first[along]+1
   -- Posts flank the entire native opening, including walkable shoulders
   -- beside the two trigger cells. They remain on blocked ground.
   local dx,dy=along=='x'and 1 or 0,along=='y'and 1 or 0
   if count==2 then
    local left,right=0,0
    while left<8 and map:isWalkableCell(first.x-dx*(left+1),first.y-dy*(left+1))do left=left+1 end
    while right<8 and map:isWalkableCell(last.x+dx*(right+1),last.y+dy*(right+1))do right=right+1 end
    if left<8 and right<8 then
     out[#out+1]={side=side,x=first.x,y=first.y,dest=first.destMap,width=(count+left+right)*16,
      frameX=first.x-dx*left,frameY=first.y-dy*left}
    end
   end
  end
 end
 table.sort(out,function(a,b)return a.y==b.y and a.x<b.x or a.y<b.y end)
 return out
end
function M.find(P,map)
 local out={};local signs=V.require('Gen1VoxelSigns')
 local de=signs.language()=='de';local C=P.decorColors
 for _,gate in ipairs(M.groups(map))do
  local label=regions[gate.dest][de and 2 or 1]
  local span=gate.width
  local kind='safari_gate_'..gate.side..'_'..label..'_'..span
  if not P.models[kind]then
   local vertical=gate.side=='west'or gate.side=='east'
   local a={terrain=true,boxes={},step=1,frameW=vertical and 16 or span,
    depth=vertical and span or 16,frameH=span+48,offsetY=-48,label=label,openingWidth=span,openingHeight=28}
   P.models[kind]=a
   -- Author a south-facing frame; rotate boxes into the boundary plane.
   local function b(x,y,z,w,h,d,c)
    if gate.side=='north'then a.boxes[#a.boxes+1]={x,y,z,w,h,d,c}
    elseif gate.side=='south'then a.boxes[#a.boxes+1]={span-x-w,y,16-z-d,w,h,d,c}
    elseif gate.side=='west'then a.boxes[#a.boxes+1]={z,y,span-x-w,d,h,w,c}
    else a.boxes[#a.boxes+1]={16-z-d,y,x,d,h,w,c}end
   end
   for _,x in ipairs({-4,span})do
    b(x,0,1,4,3,7,C.looseRock1);b(x+1,3,2,2,25,5,C.oldTimber)
    b(x,22,1,4,2,7,C.oldBeam);b(x,27,1,4,2,7,C.oldBoard)
   end
   b(-4,28,1,span+8,2,7,C.oldBeam)
   local labelStart=(span-32)/2
   b(labelStart-2,30,2,36,8,5,C.oldTimber)
   b(labelStart,31,7,32,6,1,C.oldBeam)
   b(labelStart-3,38,1,38,1,7,C.oldBoard)
   local offset=math.floor((span-(#label*4-1))/2)
   for i=1,#label do for row,line in ipairs(signs.glyphs[label:sub(i,i)]or{})do
    for col=1,3 do if line:sub(col,col)=='1'then b(offset+(i-1)*4+col-1,37-row,8,1,1,1,4)end end
   end end
  end
  out[#out+1]={kind=kind,tx=gate.frameX*2,ty=gate.frameY*2,w=(gate.side=='north'or gate.side=='south')and span/8 or 2,
   h=(gate.side=='north'or gate.side=='south')and 2 or span/8,mapId=map.id,keepTerrain=true,voxelOnly=true,
   enabled=function()return V.require('Gen1OutdoorScenery').stone:get()end,
   safariGate=gate}
 end
 return out
end
return M
