-- Presentation-only floor topology. Native land permissions alone are not
-- adjacency: COLL_*_WALL edges separate the floors beside a staircase.
local E = {}
local dirs={{0,-1,'up','down'},{0,1,'down','up'},
 {-1,0,'left','right'},{1,0,'right','left'}}
local sides={ [0]={right=true}, {left=true}, {up=true}, {down=true},
 {down=true,right=true}, {down=true,left=true},
 {up=true,right=true}, {up=true,left=true} }
local function blocks(c,dir)
 local high=math.floor(c/16)
 return (high==0xB or high==0xC) and sides[c%8][dir] or false
end
function E.build(map,config)
 local w,h=map.widthCells,map.heightCells
 local function key(x,y)return y*w+x end
 local function inside(x,y)return x>=0 and y>=0 and x<w and y<h end
 local stairs,region,sizes,edges,water={}, {}, {}, {}, {}
 local tiles=config.stairTiles
 for y=0,h-1 do for x=0,w-1 do
  if map:tileAt(x*2,y*2)==tiles[1] and map:tileAt(x*2+1,y*2)==tiles[2]
   and map:tileAt(x*2,y*2+1)==tiles[3] and map:tileAt(x*2+1,y*2+1)==tiles[4] then
   stairs[key(x,y)]={x=x,y=y}
  end
 end end
 local function floor(x,y)
  if not inside(x,y) or stairs[key(x,y)]then return false end
  if config.includeWater and map:isWaterCell(x,y) then
   if map:tileAt(x*2,y*2)==config.waterfallTile then return false end
   water[key(x,y)]=true;return true
  end
  return map:isWalkableCell(x,y)
 end
 for y=0,h-1 do for x=0,w-1 do
  if floor(x,y) and not region[key(x,y)] then
   local r=#sizes+1;local queue={{x,y}};region[key(x,y)]=r;local at=1
   while at<=#queue do
    local p=queue[at];at=at+1
    for _,d in ipairs(dirs)do
     local nx,ny=p[1]+d[1],p[2]+d[2]
     if floor(nx,ny) and not region[key(nx,ny)]
      and not blocks(map:cellCollision(p[1],p[2]),d[3])
      and not blocks(map:cellCollision(nx,ny),d[4])then
      region[key(nx,ny)]=r;queue[#queue+1]={nx,ny}
     end
    end
   end
   sizes[r]=#queue;edges[r]={}
  end
 end end
 local conflicts={}
 local rise=config.rise or 16
 local function connect(n,b,delta,label)
  if n and b and n~=b then
   edges[b][#edges[b]+1]={n,delta};edges[n][#edges[n]+1]={b,-delta}
  else conflicts[#conflicts+1]=label end
 end
 for _,s in pairs(stairs)do
  local n=inside(s.x,s.y-1) and region[key(s.x,s.y-1)]
  local b=inside(s.x,s.y+1) and region[key(s.x,s.y+1)]
  s.north,s.south=n,b
  connect(n,b,rise,'unseparated stair '..s.x..','..s.y)
 end
 local falls={}
 if config.includeWater and config.waterfallTile then
  for x=0,w-1 do local y=0
   while y<h do
    if map:tileAt(x*2,y*2)==config.waterfallTile then
     local first=y
     repeat y=y+1 until y>=h or map:tileAt(x*2,y*2)~=config.waterfallTile
     local last=y-1;local n=region[key(x,first-1)];local b=region[key(x,y)]
     local extent=(last-first+1)*2
     local drop=extent*math.min(8,math.floor((config.waterfallMax or 96)/extent))
     falls[#falls+1]={x=x,first=first,last=last,north=n,south=b,drop=drop}
     -- An incoming fall may start outside the cartridge map. It gets its
     -- base from the local downstream pool; no invented out-of-map region.
     if n and b then connect(n,b,drop,'unseparated waterfall '..x..','..first)end
    else y=y+1 end
   end
  end
 end
 local bounds={}
 if config.minimumFloorTiles then
  for cell,r in pairs(region)do
   local cx,cy=cell%w,math.floor(cell/w)
   for dy=0,1 do for dx=0,1 do
    local minimum=config.minimumFloorTiles[map:tileAt(cx*2+dx,cy*2+dy)]
    -- A drawn doorstep/edge ($24) may occur in an otherwise low region.
    -- Use its lowest explicit floor hint, not the tallest decorative tile.
    if minimum~=nil then
     bounds[r]=bounds[r]==nil and minimum or math.min(bounds[r],minimum)
    end
   end end
  end
 end
 local heights,connected={},{}
 for start=1,#sizes do if heights[start]==nil then
  heights[start]=0;local queue={start};local at=1;local minimum=0
  while at<=#queue do
   local r=queue[at];at=at+1
   for _,edge in ipairs(edges[r])do
    local next_,expected=edge[1],heights[r]+edge[2]
    if heights[next_]==nil then
     heights[next_]=expected;minimum=math.min(minimum,expected);queue[#queue+1]=next_
    elseif heights[next_]~=expected then
     conflicts[#conflicts+1]='inconsistent floor constraints '..r..'/'..next_
    end
   end
  end
  -- Rock caves already distinguish low ground from authored raised ground.
  -- Keep those lower bounds; disconnected shelves need no inferred rewrite.
  local offset=-minimum
  for _,r in ipairs(queue)do
   offset=math.max(offset,(bounds[r]or 0)-heights[r])
  end
  for _,r in ipairs(queue)do
   heights[r]=heights[r]+offset
   connected[r]=#edges[r]>0
  end
 end end
 local floors,waterLevels={},{}
 for cell,r in pairs(region)do
  if not config.preserveUnconnected or connected[r] then
   if water[cell] then waterLevels[cell]=heights[r] else floors[cell]=heights[r] end
  end
 end
 for _,s in pairs(stairs)do
  s.low=s.south and heights[s.south];s.high=s.north and heights[s.north]
 end
 return {width=w,hydrology=config.includeWater==true,floors=floors,waterLevels=waterLevels,falls=falls,stairs=stairs,regions=region,
  heights=heights,conflicts=conflicts,regionCount=#sizes}
end
return E
