-- Mountain volumes follow native, impassable rock cells. Rectangular batches
-- never span an open cell, so native entrances and paths remain authoritative.
local V=...
local M={}
local regions={ROUTE_2='diglett',ROUTE_11='diglett',ROUTE_4='moon',ROUTE_10='tunnel',CERULEAN_CITY='cerulean',ROUTE_20='seafoam'}
local rock={[1]=true,[2]=true,[17]=true,[19]=true,[30]=true,[36]=true,
 [39]=true,[52]=true,[53]=true,[54]=true,[55]=true}
local function cave(dest)
 return dest and (dest:match('^DIGLETTS_CAVE_')or dest:match('^MT_MOON_[1B]')or dest=='ROCK_TUNNEL_1F'or dest=='CERULEAN_CAVE_1F'or dest=='SEAFOAM_ISLANDS_1F')
end
function M.supports(map)
 local d=map and map.def
 return d and regions[map.id]~=nil and d.generation~=2 and d.tileset=='OVERWORLD'
end
function M.find(P,map,occupied,options)
 local d=map and map.def;local region=map and regions[map.id]
 if not region or not d or d.generation==2 or d.tileset~='OVERWORLD'
  or not map.isWalkableCell or not map.isWarpTileCell then return {} end
 local entrances={}
 for _,w in ipairs(d.warps or{})do if cave(w.destMap)then entrances[#entrances+1]=w end end
 if #entrances==0 then return {} end
 -- The rooftop samples this same native footprint and height field at cell
 -- resolution. Its private model table never replaces foreground geometry.
 local step=options and options.coarse and 16 or 4
 local checkpoint=options and options.yieldStep
 local width,height=d.width*2,d.height*2
 local function key(x,z)return z*width+x+1 end
 local mask,seen={},{}
 for z=0,height-1 do for x=0,width-1 do
  local valid=not map:isWalkableCell(x,z)and not map:isWarpTileCell(x,z)
  for dz=0,1 do for dx=0,1 do
   if not rock[map:tileAt(x*2+dx,z*2+dz)]or occupied(x*2+dx,z*2+dz)then valid=false end
  end end
  if valid then mask[key(x,z)]=true end
 end end
 -- Only rock connected to a genuine cave mouth is a mountain, never an
 -- unrelated ledge or decoration elsewhere on the same route.
 local queue={}
 local function seed(x,z)
  if x>=0 and z>=0 and x<width and z<height then local k=key(x,z)
   if mask[k]and not seen[k]then seen[k]=true;queue[#queue+1]={x,z}end
  end
 end
 for _,w in ipairs(entrances)do seed(w.x,w.y-1);seed(w.x-1,w.y);seed(w.x+1,w.y)end
 local index=1
 while index<=#queue do local p=queue[index];index=index+1
  seed(p[1]-1,p[2]);seed(p[1]+1,p[2]);seed(p[1],p[2]-1);seed(p[1],p[2]+1)
 end
 local distance,edgeQueue={},{}
 local directions={{-1,0},{1,0},{0,-1},{0,1}}
 for _,p in ipairs(queue)do
  for _,dir in ipairs(directions)do local x,z=p[1]+dir[1],p[2]+dir[2]
   if x>=0 and z>=0 and x<width and z<height and not seen[key(x,z)]then
    distance[key(p[1],p[2])]=0;edgeQueue[#edgeQueue+1]=p;break
   end
  end
 end
 index=1
 while index<=#edgeQueue do local p=edgeQueue[index];index=index+1
  for _,dir in ipairs(directions)do local x,z=p[1]+dir[1],p[2]+dir[2];local k=key(x,z)
   if x>=0 and z>=0 and x<width and z<height and seen[k]and distance[k]==nil then
    distance[k]=distance[key(p[1],p[2])]+1;edgeQueue[#edgeQueue+1]={x,z}
   end
  end
 end
 local C=P.decorColors
 local palette=region=='diglett'and {C.looseRock4 or 16,C.looseRock5 or 14,C.looseRock6 or 4}
  or {C.looseRock1 or 16,C.looseRock2 or 14,C.looseRock3 or 4}
 local result,used={},{}
 local function enabled()return V.require('Gen1OutdoorScenery').stone:get()end
 local function add(x,z,w,h,door)
  local kind='kanto_mountain_'..map.id..'_'..x..'_'..z..(door and '_mouth'or '')
  local a={terrain=true,boxes={},step=4,frameW=w*16,depth=h*16,frameH=h*16+192,
   offsetY=-192,landmarkHeight=192,mountain=true}
  P.models[kind]=a
  local function box(xx,y,zz,bw,bh,bd,c)
   if bh>0 then
    a.boxes[#a.boxes+1]={xx,y,zz,bw,bh,bd,c}
    a.landmarkHeight=math.max(a.landmarkHeight,y+bh)
    a.offsetY=-a.landmarkHeight;a.frameH=a.depth+a.landmarkHeight
   end
  end
  if door then
   -- A clear native 16px-wide mouth; its lintel starts above the player.
   -- A dark rear terminal sits beyond the walk-in recess; the original
   -- warp fires before reaching it. The approach has no foot or door leaf.
   box(0,0,0,16,32,4,3)
   box(0,32,0,16,8,16,palette[1]);box(0,40,0,16,8,12,palette[2])
   box(0,48,0,16,4,8,palette[3])
  else
   for zz=0,h*16-step,step do for xx=0,w*16-step,step do
    local wx,wz=x*16+xx+2,z*16+zz+2
    local peak=0
    for _,entry in ipairs(entrances)do
     local cx,cz=entry.x*16+8,(entry.y-2)*16
     local rx=region=='diglett'and 65 or 130
     local rz=region=='diglett'and 48 or 108
     local r=((wx-cx)/rx)^2+((wz-cz)/rz)^2
     peak=math.max(peak,(region=='diglett'and 90 or 164)*math.max(0,1-math.sqrt(r)))
    end
    -- Broad overlapping ridges keep long native mountain bodies coherent;
    -- rounded shoulders and unequal strata break the old flat tile boxes.
    local ridge=region=='diglett'and 20 or 44+20*math.sin(wx*.017+wz*.009)^2
    local top=4*math.floor((ridge+peak+5*math.sin(wx*.12+wz*.07))/4)
    local inset=distance[key(math.floor(wx/16),math.floor(wz/16))]or 6
    top=math.min(top,40+inset*(region=='seafoam'and 52 or 32))
    local lower=math.max(4,top-12)
    local y=0
    while y<lower do
     local layer=math.floor(y/16)
     local thickness=math.min(lower-y,12+4*((layer+math.floor(wx/32)+math.floor(wz/48))%2))
     box(xx,y,zz,step,thickness,step,palette[layer%3==1 and 2 or 1]);y=y+thickness
    end
    box(xx,lower,zz,step,8,step,palette[2])
    box(xx,lower+8,zz,step,4,step,palette[3])
    if top<52 and (math.floor(wx/4)*7+math.floor(wz/4)*13)%41==0 then
     box(xx,lower+12,zz,4,4,4,C.leafDark or 10)
    end
   end end
  end
  result[#result+1]={kind=kind,mapId=map.id,tx=x*2,ty=z*2,w=w*2,h=h*2,
   enabled=enabled,groundTile=44,voxelOnly=true,replacesPortal=door}
  if checkpoint then checkpoint()end
 end
 for z=0,height-1 do for x=0,width-1 do local k=key(x,z)
  if seen[k]and not used[k]then
   local w=1
   while w<4 and x+w<width and seen[key(x+w,z)]and not used[key(x+w,z)]do w=w+1 end
   local h=1
   while h<4 and z+h<height do
    local full=true;for dx=0,w-1 do if not seen[key(x+dx,z+h)]or used[key(x+dx,z+h)]then full=false end end
    if not full then break end;h=h+1
   end
   for dz=0,h-1 do for dx=0,w-1 do used[key(x+dx,z+dz)]=true end end
   add(x,z,w,h)
  end
 end end
 for _,e in ipairs(entrances)do
  if seen[key(e.x,e.y-1)]and map:tileAt(e.x*2,e.y*2)==72
   and map:tileAt(e.x*2,e.y*2+1)==88 and not occupied(e.x*2,e.y*2)then add(e.x,e.y,1,1,true)end
 end
 return result
end
return M
