-- Presentation-only volcanic atmosphere. Native drills, seals, encounters and
-- the three scripted passages keep their KASC owner and original cell layout.
local V=...
local M={}
local stages={KA_MOLTRES_VOLCANO_BASE='base',KA_MOLTRES_VOLCANO_ASCENT='ascent',KA_MOLTRES_VOLCANO='summit'}
function M.profile(map)
 local d=map and map.def
 if not d or d.tileset~='KA_MOLTRES_VOLCANO_67'or d.kaOwner~='kasc.hoenn-moltres-volcano/v4'then return nil end
 return stages[map.id or d.id]
end
function M.openSky(map)return M.profile(map)=='summit'end
local mist={color={.38,.22,.18},density=.012,height=56}
function M.mist(map)if M.profile(map)then return mist end end
-- Bounded procedural ash in the existing weather canvas; no bitmap, particle
-- allocations, extra render target or accumulating simulation state.
function M.ash(g,w,h,clock,cell)
 local size=math.max(1,math.min(3,cell or 1))
 for i=1,52 do
  local x=((i*127.7+clock*(9+i%5))%(w+24))-12
  local y=((i*79.3+clock*(5+i%7))%(h+24))-12
  local ember=i%13==0
  if ember then g.setColor(1,.34,.09,.52)else g.setColor(.55,.49,.45,.23+(i%4)*.055)end
  g.rectangle('fill',math.floor(x/size)*size,math.floor(y/size)*size,size,size)
 end
end
-- Distant rising ash columns, projected from world bearings like the normal
-- sky. Bounded solid voxel silhouettes; no bitmap atlas or particle storage.
function M.skySmoke(g,w,h,edge,clock,project,alpha)
 local pixel=math.max(1,math.floor(math.min(w,h)/180))
 for plume=0,11 do
  local az=plume*math.pi/6+clock*.0007
  for layer=0,3 do
   local bearing=az+math.sin(plume*2.3+clock*.015+layer*.4)*.025+layer*.016
   local elevation=.014+(plume%3)*.012+layer*(.048+(plume%4)*.006)
   local half=.036+layer*.015
   local x,y=project(bearing,elevation)
   local left=project(bearing-half,elevation)
   local right=project(bearing+half,elevation)
   local _,top=project(bearing,elevation+.105)
   if x and left and right and top then
    local wide=math.abs(right-left);local high=math.abs(y-top)
    if wide<w*.65 and high<h*.6 and x+wide>w*0 and x-wide<w and y+high>0 and y-high<edge then
     g.setColor(.13,.105,.11,(alpha or 1)*(.13-layer*.018))
     for part=0,2 do
      local bx=x-wide/2+wide*part*.22
      local by=y-high/2+(part==1 and -high*.18 or high*.1)
      g.rectangle('fill',math.floor(bx/pixel)*pixel,math.floor(by/pixel)*pixel,
       math.max(pixel,math.floor(wide*.60/pixel)*pixel),math.max(pixel,math.floor(high*.8/pixel)*pixel))
     end
    end
   end
  end
 end
end
function M.boulder(P,index)
 local variant=1+(tonumber(index)or 0)%3
 local kind='kasc_volcano_boulder_'..variant
 if not P.models[kind]then
  local c=P.decorColors;local boxes={}
  -- A chipped, asymmetric solid stone, small enough for its native cell.
  -- Drawn through the live item actor path, so moving/drilling/hiding remains
  -- owned by KASC rather than a permanently baked duplicate in the terrain.
  for x=0,6 do for y=0,6 do for z=0,6 do
   local dx,dy,dz=(x-3)/3.3,(y-2.7)/3.7,(z-3)/3.1
   local cut=dx*dx+dy*dy+dz*dz
   if cut<1 and not(x==5 and z==1 and y>3)then
    boxes[#boxes+1]={1+x*2,y*2,1+z*2,2,2,2,(x+y*3+z+variant)%5==0 and c.looseRock4 or c.oldBeam}
   end
  end end end
  P.models[kind]={boxes=boxes,step=2,frameW=16,frameH=32,depth=16,offsetY=-16}
 end
 return kind
end
function M.find(P,map)
 if not M.profile(map)then return {}end
 local d=map.def;local result={};local c=P.decorColors
 local function enabled()return V.require('VoxelItems').setting:get()and V.require('Gen1OutdoorScenery').stone:get()end
 for variant=1,4 do
  local kind='kasc_volcano_basalt_'..variant
  if not P.models[kind]then
   local m={boxes={},frameW=16,frameH=64,depth=16,offsetY=-48,step=1,directBoxes=true}
   local function box(x,y,z,w,h,depth,color)m.boxes[#m.boxes+1]={x,y,z,w,h,depth,color}end
   for x=0,3 do for z=0,3 do
    local height=16+(x*7+z*5+variant*3)%13
    box(x*4,0,z*4,4,height,4,(x+z)%3==0 and c.looseRock4 or c.oldBeam)
   end end
   if variant==1 then
    box(1,4,15.9,14,1,.2,11);box(6,5,15.9,2,5,.2,11)
    m.lightSource={position={8,9,18},normal={0,0,1},radius=64,power=1.4,color={1,.23,.04},kind='ember'}
   end
   P.models[kind]=m
  end
 end
 -- Opaque broken rock closes the old padding without punched-out sky
 -- gaps or tiny placeholder cubes. It stays inside blocked native cells.
 for variant=1,4 do
  local kind='kasc_volcano_apron_'..variant
  if not P.models[kind]then
   local m={boxes={{0,-8,0,16,8,16,c.oldBeam}},frameW=16,frameH=32,depth=16,offsetY=-16,step=1,directBoxes=true,replacesGround=true,groundAt=function()return nil end}
   for x=0,3 do for z=0,3 do
    local h=3+(x*3+z*7+variant*5)%6
    local hot=variant==2 and x==(z<2 and 1 or 2)
    if hot then
     -- Recessed glowing seams only in impassable ash/crater padding.
     -- Solid rock remains underneath: this is never a hole in the scene.
     m.boxes[#m.boxes+1]={x*4,0,z*4,4,.2,4,1}
     m.boxes[#m.boxes+1]={x*4+1,.2,z*4,2,.1,4,11}
    else
     m.boxes[#m.boxes+1]={x*4,0,z*4,4,h,4,(x+z+variant)%3==0 and c.looseRock4 or c.oldBeam}
    end
   end end
   P.models[kind]=m
  end
 end
 P.models.kasc_volcano_floor=P.models.kasc_volcano_floor or{boxes={{0,-1,0,1,1,1,c.oldBeam}},frameW=16,frameH=32,depth=16,offsetY=-16,step=1}
 for cy=0,d.height*2-1 do for cx=0,d.width*2-1 do
  local block=d.blocks[math.floor(cy/2)*d.width+math.floor(cx/2)+1]
  if block==0 and not map:isWalkableCell(cx,cy)then
   result[#result+1]={kind='kasc_volcano_apron_'..(1+(cx*3+cy)%4),tx=cx*2,ty=cy*2,w=2,h=2,voxelOnly=true,enabled=enabled}
  elseif map:isWalkableCell(cx,cy)and not map:isWaterCell(cx,cy)and block~=41 then
   result[#result+1]={kind='kasc_volcano_floor',tx=cx*2,ty=cy*2,w=2,h=2,terrainDecoration=true,groundTile=5,voxelOnly=true,enabled=enabled}
  elseif block~=0 and not map:isWalkableCell(cx,cy)and not map:isWaterCell(cx,cy)and not map:warpAtCell(cx,cy)then
   local safe=true
   for _,list in ipairs({d.objects or{},d.signs or{},d.storyPositions or{}})do for _,p in ipairs(list)do
    if p.x and p.y and cx==p.x and cy==p.y then safe=false end
   end end
   if safe then result[#result+1]={kind='kasc_volcano_basalt_'..(1+(cx*3+cy)%4),tx=cx*2,ty=cy*2,w=2,h=2,groundTile=5,voxelOnly=true,enabled=enabled}end
  end
 end end
 -- Native passage signs retain their trigger. A recessed stone stair
 -- occupies only that exact cell, without a lintel in the camera or a wall
 -- across the approach. Closed step boxes prevent views through the floor.
 local stair='kasc_volcano_exit_steps'
 if not P.models[stair]then
  local boxes={}
  for z=0,3 do
   boxes[#boxes+1]={0,-10,z*4,16,10-z*2,4,c.looseRock4}
   boxes[#boxes+1]={1,-z*2-.15,z*4+.25,14,.15,.5,c.stone}
  end
  P.models[stair]={boxes=boxes,directBoxes=true,step=1,frameW=16,frameH=32,depth=16,offsetY=-16,
   replacesGround=true,groundAt=function()return nil end,actorSurface=true,
   support=function(x,z)return -math.min(3,math.floor(z/4))*2 end}
 end
 for _,p in ipairs(d.signs or{})do
  if p.name and p.name:match('^KA_MOLTRES_')and p.x and p.y then
   result[#result+1]={kind=stair,tx=p.x*2,ty=p.y*2,w=2,h=2,voxelOnly=true,enabled=enabled}
  end
 end
 return result
end
return M
