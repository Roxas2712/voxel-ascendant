-- Authored HEVO paths only. Replace inert wall cells with solid voxel
-- formations; scripts still own gates, glyphs, objects, water and collision.
local V=...
local M={}
local rockBlocks={[125]=true,[1]=true}
local forestBlocks={[2]=true,[77]=true,[76]=true,[53]=true,[73]=true,
 [59]=true,[52]=true,[72]=true,[55]=true,[54]=true,[57]=true,[56]=true,[58]=true}
function M.register(P)
 local c=P.decorColors
 for _,theme in ipairs({'ember','tide','frost','grove'})do
  for variant=1,4 do
   local key='kasc_legend_'..theme..'_'..variant
   local m={boxes={},directBoxes=true,step=1,frameW=16,frameH=64,depth=16,offsetY=-48}
   local function b(...)m.boxes[#m.boxes+1]={...}end
   if theme=='grove'then
    -- Tapered conifer tiers and roots fit one blocked native cell, including
    -- the forest's narrow corner corridors. No canopy overhang into paths.
    b(6,0,6,4,32,4,c.walnut)
    b(2,0,7,12,2,2,c.oldBeam);b(7,0,2,2,2,12,c.oldBeam)
    for tier=0,4 do
     local w=16-tier*2;local y=7+tier*6
     b(8-w/2,y,8-w/2,w,3,w,tier%2==0 and c.leafDark or c.leaf)
     b(9-w/2,y+3,9-w/2,w-2,3,w-2,c.leaf)
    end
    b(7,37,7,2,5+variant,2,c.leafLight)
   else
    local dark=theme=='ember'and c.oldBeam or c.navy
    local stone=theme=='ember'and c.looseRock4 or theme=='frost'and c.silphGlass or c.slate
    -- Closed base, unequal strata, chipped tops. No grass caps or masonry
    -- courses and no transparent rock faces.
    b(0,-3,0,16,6,16,dark)
    for x=0,2 do for z=0,2 do
     local seed=(x*7+z*11+variant*5)%13
     local h=14+seed+(theme=='frost'and 8 or 0)
     local xx,zz=x*5,z*5
     b(xx,2,zz,6,h,6,stone)
     b(xx+.7,h+2,zz+.7,4.6,3+(seed%3),4.6,theme=='frost'and c.silver or dark)
     if theme=='tide'and seed%3==0 then b(xx+.2,7+seed,zz,5.6,1.2,6,c.dustyGlass)end
    end end
    if theme=='ember'and variant==1 then
     -- Recessed seams; lighting remains under LocalLights' normal cap.
     b(3,4,15.95,7,.8,.05,1);b(6,4.8,15.95,1,4,.05,11)
     m.lightSource={position={8,9,17},normal={0,0,1},radius=48,power=1.1,color={1,.24,.045},kind='ember'}
    elseif theme=='tide'and variant==2 then
     b(3,4,13,3,13,3,7);b(4,17,14,1,3,1,c.silver)
    end
   end
   P.models[key]=m
  end
 end
end
function M.find(P,map,occupied)
 local profile=V.require('KascLegendAtmosphere').profile(map)
 if not profile then return {}end
 local d=map.def
 if not(d.blocks and d.width and d.height)then return {}end
 local theme=profile.kind;local accepted=theme=='grove'and forestBlocks or rockBlocks
 local width,height=d.width*2,d.height*2
 local protected={}
 -- Mark all scripted points and their immediate approaches once, not once
 -- per wall candidate. Dynamic gate blocks are absent from accepted above.
 for _,list in ipairs({d.objects or{},d.signs or{},d.storyPositions or{},d.warps or{}})do
  for _,p in ipairs(list)do if p.x and p.y then
   for dy=-1,1 do for dx=-1,1 do protected[(p.y+dy)*width+p.x+dx]=true end end
  end end
 end
 local function inside(x,y)return x>=0 and y>=0 and x<width and y<height end
 local function exposed(x,y)
  for _,p in ipairs({{-1,0},{1,0},{0,-1},{0,1},{-2,0},{2,0},{0,-2},{0,2}})do
   local xx,yy=x+p[1],y+p[2]
   if inside(xx,yy)and(map:isWalkableCell(xx,yy)or map:isWaterCell(xx,yy))then return true end
  end
 end
 local function enabled()
  local s=V.require('Gen1OutdoorScenery')
  return V.require('VoxelItems').setting:get()and(theme=='grove'and s.trees:get()or theme~='grove'and s.stone:get())
 end
 local result={}
 for y=0,height-1 do for x=0,width-1 do
  local block=d.blocks[math.floor(y/2)*d.width+math.floor(x/2)+1]
  if accepted[block]and not protected[y*width+x]
    and not map:isWalkableCell(x,y)and not map:isWaterCell(x,y)
    and not(map.warpAtCell and map:warpAtCell(x,y))and exposed(x,y)then
   local used=false
   if occupied then for dy=0,1 do for dx=0,1 do used=used or occupied(x*2+dx,y*2+dy)end end end
   if not used then
    result[#result+1]={kind='kasc_legend_'..theme..'_'..(1+(x*3+y*7)%4),
     tx=x*2,ty=y*2,w=2,h=2,groundTile=theme=='grove'and 5 or 36,voxelOnly=true,enabled=enabled}
   end
  end
 end end
 return result
end
return M
