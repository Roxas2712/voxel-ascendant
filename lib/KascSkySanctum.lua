-- Rayquaza's authored sky island: retain native paths and scripted return,
-- but replace void walls and stretched atlas columns with floating stone.
local V=...
local M={}
function M.matches(map)
 local d=map and map.def
 return d and (map.id or d.id)=='KA_HEVO_RAYQUAZA_CHAMBER'
  and d.tileset=='KA_HOENN_SKY_67'and d.outdoor==true
  and d.width==12 and d.height==10
end
local mist={color={.57,.68,.73},density=.006,height=24}
function M.mist(map)if M.matches(map)then return mist end end
function M.find(P,map)
 if not M.matches(map)then return {}end
 local d=map.def;local width,depth=d.width*32,d.height*32
 local kind='kasc_rayquaza_sky_platform'
 local landmarks={}
 for _,list in ipairs({d.objects or{},d.signs or{}})do
  for _,point in ipairs(list)do if point.x and point.y then landmarks[point.y*32+point.x]=true end end
 end
 local c=P.decorColors
 local m={boxes={},frameW=width,frameH=depth+40,depth=depth,offsetY=-40,
  directBoxes=true,step=1,replacesGround=true,groundAt=function(x,z)
   local cx,cy=math.floor(x/16),math.floor(z/16)
   if map:isWalkableCell(cx,cy)or landmarks[cy*32+cx]then return 36 end
  end,
  support=0,actorSurface=true}
 local function b(x,y,z,w,h,d,color)m.boxes[#m.boxes+1]={x,y,z,w,h,d,color}end
 for cy=0,d.height*2-1 do for cx=0,d.width*2-1 do
  local block=d.blocks[math.floor(cy/2)*d.width+math.floor(cx/2)+1]
  if block~=0 then
   local x,z=cx*16,cy*16
   local walk=map:isWalkableCell(cx,cy)or landmarks[cy*32+cx]
   b(x,-6,z,16,5,16,c.slate)
   if not walk then b(x+.2,-1,z+.2,15.6,1,15.6,c.navy)end
   if not walk then
    -- Low fractured edge courses reveal the sky without masquerading as
    -- traversable land. Never add a column over a playable cell.
    local h=2+(cx*3+cy*7)%2
    b(x+1,0,z+1,14,h,14,c.slate)
    b(x+2,h,z+2,12,1,12,c.silver)
    local away=true
    for dy=-2,2 do for dx=-2,2 do if landmarks[(cy+dy)*32+cx+dx]then away=false end end end
    if away and (cx+cy*3)%7==0 then
     -- Broken sky-temple pillars stand on already blocked cells. Their
     -- square capitals never extend across a path or the return portal.
     local shaft=20+(cx*7+cy*3)%17
     b(x+3,h+1,z+3,10,2,10,c.silver)
     b(x+5,h+3,z+5,6,shaft,6,c.slate)
     b(x+4,h+7,z+4,8,1,8,11)
     b(x+4,h+shaft+3,z+4,8,2,8,c.silver)
     b(x+3,h+shaft+5,z+4,10,2,7,c.silver)
     b(x+5,h+shaft+7,z+5,5,3,4,c.slate)
     -- Vertical jade inlay, not a light or a separate bitmap.
     b(x+7,h+10,z+4.95,2,math.max(2,shaft-9),.05,c.roofGreen)
    end
   end
   if (cx*7+cy*11)%9==0 then b(x+3,-12,z+3,10,6,10,c.navy)end
  end
 end end
 -- Scripted return signs get a low cyan compass mark, not a wall or a
 -- generic forest signboard. Native interaction and landing remain intact.
 for _,point in ipairs(d.signs or{})do
  if point.x and point.y then
   local x,z=point.x*16,point.y*16
   for i=0,2 do b(x+3+i,.08,z+5+i,2,.3,2,7);b(x+10-i,.08,z+5+i,2,.3,2,7)end
  end
 end
 P.models[kind]=m
 return {{kind=kind,tx=0,ty=0,w=d.width*4,h=d.height*4,voxelOnly=true}}
end
return M
