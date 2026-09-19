-- Real, inexpensive box geometry at the outer boundary of the visible union.
-- Never claims native tiles and never inserts a curtain between loaded maps.
local V=...
local H={}
H.SHOULDER_DEPTH=208
H.setting=V.require('ModSetting').new('outdoorHorizon','OUTDOOR HORIZON',
 {'voxel','bitmap','off'},{'VOXEL','BITMAP','OFF'})
local G=V.require('Voxel3D')
local Buildings=V.require('HorizonBuildings')
local colors={{48,86,57},{64,104,64},{88,125,71},{82,65,47},
 {113,117,106},{141,139,119},{168,157,129},{88,70,59},{99,109,103},
 {191,174,126},{94,135,143},{137,117,82},
 {112,87,64},{67,50,41},{133,108,79},{75,67,57},{205,182,130},{146,153,145},{177,137,88},
 {44,60,54},{64,78,67},{84,91,75},{83,73,82},{128,116,97},
 {37,77,63},{67,118,80},{117,144,82},{170,82,67},{213,198,157},{58,77,99},{96,99,111},{49,51,63},{128,130,133},{55,58,74},{112,133,119},{203,213,210},{251,247,224},{40,62,85},{159,180,181},{113,178,199}}
local texture,registered
local function palette()
 if not registered then
  require('src.render.Assets').register(function()if texture then texture:release();texture=nil end end)
  registered=true
 end
 if texture then return texture end
 local d=love.image.newImageData(#colors,1)
 for i,c in ipairs(colors)do d:setPixel(i-1,0,c[1]/255,c[2]/255,c[3]/255,1)end
 texture=love.graphics.newImage(d);texture:setFilter('nearest','nearest');d:release()
 return texture
end
function H.active(map,horizon)
 local canopy=horizon.classFor and horizon.classFor(map)=='canopy'
 return (horizon.hasSky(map)or canopy) and H.setting:get()~='bitmap'
end
function H.silphLandmark(maps,worldMaps,emit)
 local T=V.require('Gen1SilphCo')
 if not worldMaps or not T.matches(worldMaps.SAFFRON_CITY)then return end
 for _,e in ipairs(maps)do if e.map.id=='SAFFRON_CITY'then return end end
 local root=maps[1];if not root then return end
 local placement=V.require('WorldPlacement')
 local sp=placement.position('SAFFRON_CITY',worldMaps)
 local rp=placement.position(root.map.id,worldMaps)
 if not(sp and rp and sp.anchor==rp.anchor)then return end
 local px,pz=sp.x+T.tx*8+(root.ox or 0)-rp.x,sp.y+T.ty*8+(root.oy or 0)-rp.y
 local colors={wall=36,trim=37,navy=38,silver=39,glass=40,stone=18}
 -- The buried footing prevents a remote tower from floating above an
 -- unloaded map. It vanishes with the landmark when Saffron becomes resident.
 emit(px+4,-512,pz+4,120,512,184,18,false)
 T.geometry(function(x,y,z,w,h,d,c,lit)emit(px+x,y,pz+z,w,h,d,colors[c],lit)end)
end
function H.landmarks(maps,worldMaps,emit)
 if not V.require('Gen1PalletVillage').buildings:get() or not V.require('VoxelItems').setting:get()then return end
 if not worldMaps then local game=require('src.core.Game');worldMaps=game.data and game.data.maps end
 H.silphLandmark(maps,worldMaps,emit)
 local stone=V.require('Gen1LavenderTower').setting:get()=='stone'
 local lavender=worldMaps and worldMaps.LAVENDER_TOWN
 local route=worldMaps and worldMaps.ROUTE_10
 if not(lavender and route and lavender.width==10 and lavender.height==9 and route.width==10 and route.height==36)then return end
 local entrance=false
 for _,w in ipairs(lavender.warps or{})do if w.x==14 and w.y==5 and w.destMap=='POKEMON_TOWER_1F'then entrance=true end end
 if not entrance then return end
 local placement=V.require('WorldPlacement')
 local lp=placement.position('LAVENDER_TOWN',worldMaps)
 local root=maps[1];local rp=root and placement.position(root.map.id,worldMaps)
 if not(lp and rp and lp.anchor==rp.anchor)then return end
 local present={};for _,e in ipairs(maps)do present[e.map.id]=true end
 if present.LAVENDER_TOWN and present.ROUTE_10 then return end
 local px,pz=lp.x+192+root.ox-rp.x,lp.y-96+root.oy-rp.y
 if present.LAVENDER_TOWN or present.ROUTE_10 then
  -- A tower straddles two maps: if only one map is resident, use matching
  -- timber/window geometry for its missing half, not half of a coarse LOD.
  local P=V.require('VoxelItems');local C=P.decorColors
  local top=not present.ROUTE_10
  local kind='landmark_lavender_'..(top and 'top'or 'front')..(stone and '_stone'or '_wood')
  if not P.models[kind]then V.require('Gen1LavenderTower').create(P,kind,top and 'pokemon_tower_top'or 'pokemon_tower',V.require('Gen1PalletVillage').windowLight)end
  local indices={[C.oldTimber]=13,[C.oldBeam]=14,[C.oldBoard]=15,[C.oldShingle]=16,[C.paperWindow]=17,[C.stone]=18,[C.oak]=19,[C.hauntedStone]=31,[C.hauntedMortar]=32,[C.hauntedWeathered]=33,[C.hauntedSlate]=34,[C.hauntedGlass]=35}
  local m=P.models[kind]
  for _,name in ipairs({kind,m.glassKind})do for _,box in ipairs(P.models[name].boxes)do
   emit(px+box[1],box[2],pz+(top and 0 or 96)+box[3],box[4],box[5],box[6],indices[box[7]]or 8,name==m.glassKind)
  end end
  return
 end
 -- Only the absent portion receives a coarse counterpart. The complete
 -- tower has exactly the same footprint, height and seven roof lines as the
 -- near model; approaching it never creates a second tower at the seam.
 local function b(x,y,z,w,h,d,c)
  for _,part in ipairs({{0,96,'ROUTE_10'},{96,160,'LAVENDER_TOWN'}})do
   if not present[part[3]]then
    local z0,z1=math.max(z,part[1]),math.min(z+d,part[2])
    if z1>z0 then emit(px+x,y,pz+z0,w,h,z1-z0,c,false)end
   end
  end
 end
 -- Ground the remote landmark in the actual two-map land footprint. Deep
 -- skirts prevent a floating tower against the sky when terrain is outside
 -- the resident ring. These are cheap background land masses, never native
 -- tiles or collision. Both disappear as their real maps become resident.
 for _,part in ipairs({{px-192,pz,320,96},{px-192,pz+96,320,288}})do
  emit(part[1],-512,part[2],part[3],512,part[4],21,false)
 end
 b(4,0,4,88,4,152,18)
 for level=0,6 do
  local inset,y=6+level*4,4+level*36
  b(inset,y,inset,96-inset*2,28,160-inset*2,stone and 31 or 13)
  b(inset-4,y+28,inset-4,104-inset*2,2,168-inset*2,stone and 32 or 14)
  for r=0,3 do local i=inset-4+r*2;b(i,y+30+r*2,i,96-i*2,2,160-i*2,stone and 34 or 16)end
 end
 b(44,260,74,8,4,12,stone and 32 or 14);b(46,264,78,4,8,4,stone and 32 or 19)
end
-- Regional silhouettes use a shared palette/mesh, not separately loaded props.
-- Woodland dominates rural edges; buildings appear as occasional clearings.
function H.profile(map,kind)
 local id=map.id or ''
 if id=='LAVENDER_TOWN'or id=='ROUTE_8'or id=='ROUTE_10'or id=='ROUTE_12'then return 'lavender' end
 if id=='FUCHSIA_CITY'or id:find('SAFARI')or id=='ROUTE_15'then return 'safari' end
 if id=='CINNABAR_ISLAND'or id=='ROUTE_20'or id=='ROUTE_21'then return 'volcanic' end
 if id=='PEWTER_CITY'or id=='ROUTE_3'or id:find('MT_MOON')then return 'foothills' end
 if id=='CELADON_CITY'then return 'garden' end
 if id=='SAFFRON_CITY'then return 'city' end
 if id=='VERMILION_CITY'or kind=='harbor'then return 'harbor' end
 if id=='CERULEAN_CITY'then return 'riverside' end
 return 'woodland'
end
-- Complete the near shoulder independently of whether a whole 48px prop
-- fits at a corner. Only the exterior of the loaded-map union is eligible.
-- Merge cells into rectangles: this is terrain, not one new tree per cell.
-- Reserve genuine walkable connections even while the neighbouring mesh is
-- still cooking. Decorative scenery must never pretend a route is blocked.
function H.connectionCorridors(maps,worldMaps)
 local out={}
 for _,e in ipairs(maps)do
  local map=e.map;local def=map and map.def
  if def and map.isWalkableCell then
   for _,edge in ipairs({'north','south','west','east'})do
    local conn=def.connections and def.connections[edge]
    local target=conn and worldMaps and worldMaps[conn.map]
    if target and target.def then target=target.def end
    if conn and target then
     local horizontal=edge=='north'or edge=='south'
     local count=(horizontal and def.width or def.height)*2
     local span=(horizontal and target.width or target.height)*2
     for along=0,count-1 do
      local landing=along-(conn.offset or 0)*2
      local cx=horizontal and along or edge=='west'and 0 or def.width*2-1
      local cy=not horizontal and along or edge=='north'and 0 or def.height*2-1
      if landing>=0 and landing<span and map:isWalkableCell(cx,cy)then
       local x,z=e.x0+cx*16,e.z0+cy*16
       local x0,x1,z0,z1=x,x+16,z,z+16
       if edge=='north'then z0,z1=e.z0-256,e.z0
       elseif edge=='south'then z0,z1=e.z1,e.z1+256
       elseif edge=='west'then x0,x1=e.x0-256,e.x0
       else x0,x1=e.x1,e.x1+256 end
       out[#out+1]={x0=x0,x1=x1,z0=z0,z1=z1}
      end
     end
    end
   end
  end
 end
 return out
end
local function inCorridor(corridors,x,z,w,d)
 for _,c in ipairs(corridors)do
  if x<c.x1 and x+w>c.x0 and z<c.z1 and z+d>c.z0 then return true end
 end
 return false
end
function H.shoulders(maps,horizon,emit,yieldStep,depth,corridors)
 corridors=corridors or {}
 local step=16;depth=depth or 48
 local work=0
 local function checkpoint()
  work=work+1
  if work>=128 then work=0;if yieldStep then yieldStep()end end
 end
 local gates=V.require('Gen1ForestLandmarks').gates(maps,horizon)
 local function land(kind)
  return kind and kind~='none'and kind~='open_water'
   and not kind:find('water')and not kind:find('sea')
 end
 local function edgeKind(e,edge,x,z)
  local along=(edge=='north'or edge=='south')and x-e.x0 or z-e.z0
  local len=(edge=='north'or edge=='south')and e.w or e.h
  return horizon.edgeClass(e.map,edge,math.max(0,math.min(len-1,along)))
 end
 local function clear(x,z)
  for _,e in ipairs(maps)do
   if x<e.x1 and x+step>e.x0 and z<e.z1 and z+step>e.z0 then return false end
   -- A land corner adjoining a coast must not extend across the open sea.
   if x>=e.x0-depth and x<e.x1+depth and z>=e.z0-depth and z<e.z1+depth then
    local cx,cz=x+step/2,z+step/2
    if z<e.z0 and not land(edgeKind(e,'north',cx,cz))then return false end
    if z>=e.z1 and not land(edgeKind(e,'south',cx,cz))then return false end
    if x<e.x0 and not land(edgeKind(e,'west',cx,cz))then return false end
    if x>=e.x1 and not land(edgeKind(e,'east',cx,cz))then return false end
   end
  end
  for _,g in ipairs(gates)do
   if x<g.x1+8 and x+step>g.x0-8 and z<g.z1 and z+step>g.z0 then return false end
  end
  return true
 end
 local cells,rows={},{ }
 for _,e in ipairs(maps)do
  for _,edge in ipairs({'north','south','west','east'})do
   local horizontal=edge=='north'or edge=='south'
   local len=horizontal and e.w or e.h
   for along=-depth,len+depth-step,step do
    local kind=edgeKind(e,edge,e.x0+along,e.z0+along)
    if land(kind)then
     local profile=H.profile(e.map,kind)
     local color=profile=='lavender'and 21 or profile=='volcanic'and 5 or 2
     for n=step,depth,step do
      checkpoint()
      local x=horizontal and e.x0+along or edge=='west'and e.x0-n or e.x1+n-step
      local z=not horizontal and e.z0+along or edge=='north'and e.z0-n or e.z1+n-step
      if clear(x,z)then
       if not cells[z]then cells[z]={};rows[#rows+1]=z end
       -- A route continues at ground level, not up a synthetic 16px wall.
       cells[z][x]=cells[z][x]or (inCorridor(corridors,x,z,step,step)and -color or color)
      end
     end
    end
   end
  end
 end
 table.sort(rows)
 for _,z in ipairs(rows)do
  checkpoint()
  local xs={};for x in pairs(cells[z])do xs[#xs+1]=x end;table.sort(xs)
  for _,x in ipairs(xs)do
   local color=cells[z][x]
   if color then
    local w=step;while cells[z][x+w]==color do w=w+step end
    local d=step
    while cells[z+d]do
     local match=true;for xx=x,x+w-step,step do if cells[z+d][xx]~=color then match=false;break end end
     if not match then break end;d=d+step
    end
    for zz=z,z+d-step,step do for xx=x,x+w-step,step do cells[zz][xx]=nil end end
    -- Low, opaque ground/undergrowth closes views beneath the canopy.
    -- Deep skirts also survive downward-looking and curved-world cameras.
    emit(x,-128,z,w,color<0 and 128 or 144,d,math.abs(color),false)
   end
  end
 end
end
-- Pure geometry callback also supports tests without a graphics context.
function H.geometry(maps,horizon,emit,yieldStep,worldMaps)
 local corridors=H.connectionCorridors(maps,worldMaps)
 H.shoulders(maps,horizon,emit,yieldStep,H.SHOULDER_DEPTH,corridors)
 local gates=V.require('Gen1ForestLandmarks').gates(maps,horizon)
 local function vacant(x,z,w,d)
  if inCorridor(corridors,x,z,w,d)then return false end
  for _,gate in ipairs(gates)do
   if x<gate.x1+8 and x+w>gate.x0-8 and z<gate.z1 and z+d>gate.z0 then return false end
  end
  for _,e in ipairs(maps)do
   if x<e.x1 and x+w>e.x0 and z<e.z1 and z+d>e.z0 then return false end
  end
  return true
 end
 local function land(kind)
  return kind and kind~='none' and kind~='open_water'
   and not kind:find('water') and not kind:find('sea')
 end
 local function landCorner(x,z)
  for _,e in ipairs(maps)do
   if x+48>e.x0-208 and x<e.x1+208 and z+48>e.z0-208 and z<e.z1+208 then
    local cx,cz=x+24,z+24
    local function allows(edge,along,len)
     return land(horizon.edgeClass(e.map,edge,math.max(0,math.min(len-1,along))))
    end
    if z<e.z0 and not allows('north',cx-e.x0,e.w)then return false end
    if z+48>e.z1 and not allows('south',cx-e.x0,e.w)then return false end
    if x<e.x0 and not allows('west',cz-e.z0,e.h)then return false end
    if x+48>e.x1 and not allows('east',cz-e.z0,e.h)then return false end
   end
  end
  return true
 end
 local occupied={}
 local function object(x,z,kind,seed,row,profile,edge)
  x,z=math.floor(x/16)*16,math.floor(z/16)*16
  local key=x..':'..z
  if occupied[key] or not vacant(x,z,48,48) or not landCorner(x,z)then return end
  occupied[key]=true
  local dark=profile=='lavender'
  local grass=dark and 21 or profile=='volcanic'and 5 or 2
  local function b(dx,y,dz,w,h,d,c,lit)
   emit(x+dx,y,z+dz,w,h,d,c,lit)
  end
  -- Joined ground shoulders continue below the skyline instead of exposing
  -- bright gaps under trees. Every shoulder stays outside the resident union.
  b(0,-96,0,48,96,48,grass)
  local mountain=kind:find('mountain')or kind:find('rock')or kind:find('cliff')
  local house=Buildings.selected(kind,seed,row)
  local rock=(mountain and seed%5<3) or ((profile=='foothills'or profile=='volcanic')and seed%4==0)
  local rise=row>=3 and 24+(seed%4)*8 or 0
  if rise>0 then b(0,0,0,48,rise,48,grass) end
  if rock then
   -- Asymmetric outcrops: overlapping shelves, a split peak and a weathered
   -- shoulder. Different widths/heights avoid a line of identical pyramids.
   local h=18+seed%5*6+row*12
   local c=profile=='volcanic'and 9 or 5
   local highlight=profile=='volcanic'and 5 or 6
   b(0,rise,0,48,h*.4,48,c)
   b(4,rise+h*.4,2,38,h*.3,42,highlight)
   b(6+seed%3*4,rise+h*.7,6,22,h*.3,28,c)
   b(28,rise+h*.4,18,16,h*.25,24,highlight)
   b(2,rise+h*.4-3,0,40,3,44,highlight)
   if profile~='volcanic'then b(4,rise+h*.4,4,12,3,12,grass)end
  elseif house then
   Buildings.geometry(profile,seed,row,edge,function(dx,y,dz,w,h,d,c,lit)
    b(dx,rise+y,dz,w,h,d,c,lit)
   end)
  else
   local h=38+seed%5*8+row*8
   local leaf=dark and 20 or profile=='safari'and 25 or 1
   local trunk=dark and 14 or 4
   b(21,rise,21,6,h*.65,6,trunk)
   if (dark and seed%5<3)or seed%4==0 then
    -- Tall firs and cypress shapes among broad crowns.
    for tier=0,3 do
     local w=40-tier*8;b(24-w/2,rise+16+tier*(h-12)/4,24-w/2,w,(h-12)/4+5,w,leaf+tier%2)
    end
   else
    -- Interlocking lobes and lower branches make a dense, irregular canopy.
    b(4,rise+h*.45,10,32,h*.35,30,leaf)
    b(12,rise+h*.55,2,30,h*.3,32,leaf+1)
    b(10,rise+h*.8,10,26,h*.2,28,leaf+1)
    b(16,rise+h,16,16,6,18,leaf+2)
    b(2,rise+h*.5,18,12,10,16,leaf)
   end
   if row<2 and seed%3==0 then
    b(3,rise,3,13,8,12,leaf+1);b(29,rise,32,16,10,14,leaf)
    if not dark and seed%7==0 then b(6,rise+8,6,3,3,3,28)end
   end
  end
 end
 for _,e in ipairs(maps)do
  for _,edge in ipairs({'north','south','west','east'})do
   local horizontal=edge=='north'or edge=='south'
   local len=horizontal and e.w or e.h
   for along=0,len-1,48 do
    local kind=horizon.edgeClass(e.map,edge,along)
    if kind and kind~='none'and kind~='open_water'and not kind:find('water')and not kind:find('sea')then
     local profile=H.profile(e.map,kind)
     for row=0,4 do
      local shift=(row%2)*16
      local x=horizontal and e.x0+along+shift or edge=='west'and e.x0-48-row*40 or e.x1+row*40
      local z=not horizontal and e.z0+along+shift or edge=='north'and e.z0-48-row*40 or e.z1+row*40
      -- A coordinate hash avoids the former diagonal repetition of shapes.
      local gx,gz=math.floor(x/16),math.floor(z/16)
      local seed=(gx*73856093+gz*19349663+gx*gz*83492791)%100003
      object(x,z,kind,seed,row,profile,edge)
     end
    end
    if yieldStep then yieldStep()end
   end
  end
 end
 -- Side rows stop at their map endpoints. Their two outer quadrants used
 -- to stay empty beyond the 48px near shoulder, visible as a sky wedge in
 -- wide MAP cameras. Continue the same inexpensive silhouettes diagonally.
 -- Test both adjoining edge policies; a wooded shore must stay open at sea.
 for _,e in ipairs(maps)do
  for _,corner in ipairs({{'west','north',-1,-1},{'east','north',1,-1},
      {'west','south',-1,1},{'east','south',1,1}})do
   local sx,sz=corner[3],corner[4]
   local kind=horizon.edgeClass(e.map,corner[1],sz<0 and 0 or e.h-1)
   local other=horizon.edgeClass(e.map,corner[2],sx<0 and 0 or e.w-1)
   if land(kind)and land(other)then
    for iz=0,3 do for ix=0,3 do
     local x=sx<0 and e.x0-48-ix*48 or e.x1+ix*48
     local z=sz<0 and e.z0-48-iz*48 or e.z1+iz*48
     if landCorner(x,z)then
      local gx,gz=math.floor(x/16),math.floor(z/16)
      local seed=(gx*73856093+gz*19349663+gx*gz*83492791)%100003
      object(x,z,kind,seed,math.max(ix,iz),H.profile(e.map,kind),corner[1])
     end
    end end
   end
   if yieldStep then yieldStep()end
  end
 end
end
-- Spatial batches retain the exact scenery but allow the draw camera to
-- reject whole off-screen sections. Limit upload size independently of a
-- section's density (forest gate/tower details can share the same cell).
H.BATCH_CELL = 256
H.BATCH_BOXES = 256
function H.build(maps,horizon,yieldStep,worldMaps)
 if H.setting:get()=='off'then return {} end
 local groups,byCell={},{}
 local function emit(x,y,z,w,h,d,c,lit)
  local key=math.floor(x/H.BATCH_CELL)..':'..math.floor(z/H.BATCH_CELL)..':'..(lit and 1 or 0)
  local a=byCell[key]
  if not a or a.boxes>=H.BATCH_BOXES then
   a={vertices={},indices={},boxes=0,lit=lit,
      bounds={x,y,z,x+w,y+h,z+d}}
   byCell[key]=a;groups[#groups+1]=a
  end
  a.boxes=a.boxes+1
  local q=a.bounds
  q[1],q[2],q[3]=math.min(q[1],x),math.min(q[2],y),math.min(q[3],z)
  q[4],q[5],q[6]=math.max(q[4],x+w),math.max(q[5],y+h),math.max(q[6],z+d)
  for face,corners in ipairs(G.FACE_CORNERS)do
   G.pushQuad(a.indices,#a.vertices/4)
   for _,p in ipairs(corners)do
    a.vertices[#a.vertices+1]={x+p[1]*w,y+p[2]*h,z+p[3]*d,(c-.5)/#colors,.5,G.FACE_SHADE[face]}
   end
  end
 end
 if not worldMaps then local game=require('src.core.Game');worldMaps=game.data and game.data.maps end
 H.silphLandmark(maps,worldMaps,emit)
 H.geometry(maps,horizon,emit,yieldStep,worldMaps)
 V.require('Gen1ForestLandmarks').geometry(maps,horizon,emit,yieldStep)
 H.landmarks(maps,worldMaps,emit)
 V.require('OceanLandmarks').geometry(maps,horizon,emit,yieldStep,worldMaps)
 local tex=palette();local out={}
 local clock=love.timer and love.timer.getTime
 local sliceStart=clock and clock() or 0
 local uploads=0
 for _,a in ipairs(groups)do
  if uploads>=4 or (uploads>0 and clock and clock()-sliceStart>=.002)then
   if yieldStep then yieldStep()end
   uploads=0;sliceStart=clock and clock() or 0
  end
  local mesh=G.newMesh(a.vertices,a.indices)
  if not mesh then for _,part in ipairs(out)do part.mesh:release()end;error('voxel horizon allocation failed',0)end
  uploads=uploads+1
  out[#out+1]={mesh=mesh,texture=tex,ox=0,oy=0,kind='wall',class='voxel_horizon',
   bounds=a.bounds,windowLight=a.lit==true,castsShadow=false}
  a.vertices,a.indices=nil,nil
 end
 return out
end
function H.visibility()
 return V.require('PropVisibility').forView(G.vp,G.curveK,G.curveX,G.curveZ)
end
function H.draw(rim,matrix,visible)
 if visible and not visible(rim.bounds,matrix)then return false end
 if rim.windowLight then G.flatten({1,.86,.6},V.require('Gen1PalletVillage').windowLight())end
 G.draw(rim.mesh,rim.texture,matrix)
 if rim.windowLight then G.flatten(nil)end
 return true
end
return H
