-- Continuous visual ground on native walkable routes. Cell centres keep the
-- authored elevation; shared corners meet at the higher neighbouring course.
-- Jump lips, water, furniture and blocked ground retain their own geometry.
-- Tall-grass blades share their ground grade, retaining reusable templates.
local V=...
local M={}
local Budget=V.require("BuildBudget")
local cache=setmetatable({},{__mode='k'})
local function key(x,y)return (y+64)*4096+x+64 end
local function snapshot(map,elevation,S)
 if not map or not map.def or map.def.generation==2 or map.def.tileset~='OVERWORLD'
    or not elevation or (elevation.terrainMode~='world'and elevation.terrainMode~='local')
    or not S then return end
 local old=cache[map]
 if old and old.elevation==elevation and old.structure==S then return old end
 local profile=V.require('TileShape').forMap(map)
 local cells,tiles,quads,vertices={},{},{},{}
 local function eligibleCell(x,y)
  local k=key(x,y);local hit=cells[k]
  if hit~=nil then return hit end
  local sh=profile[map:cellTile(x,y)]
  hit=map:inBounds(x,y)and map:isWalkableCell(x,y)and sh and (sh.art=='flat'or sh.art=='grass')
    and sh.h==0 and(sh.class=='ground'or sh.class=='grass')or false
  cells[k]=hit;return hit
 end
 local function tile(x,y)
  local k=key(x,y);local hit=tiles[k]
  if hit~=nil then return hit or nil end
  local sh=S.shapeAt[k]
  if not eligibleCell(math.floor(x/2),math.floor(y/2))or S.skip[k]or S.runs[k]
     or not sh or (sh.art~='flat'and sh.art~='grass')or sh.h~=0
     or(sh.class~='ground'and sh.class~='grass')then tiles[k]=false;return end
  local d,hi,lo=elevation:rampAtTile(x,y)
  local a,b,c,f
  if d=='down'then a,b,c,f=hi,hi,lo,lo
  elseif d=='up'then a,b,c,f=lo,lo,hi,hi
  elseif d=='right'then a,b,c,f=hi,lo,lo,hi
  elseif d=='left'then a,b,c,f=lo,hi,hi,lo
  else a=elevation:atTile(x,y);b,c,f=a,a,a end
  hit={a,b,c,f};tiles[k]=hit;return hit
 end
 local offsets={{-1,-1,3},{0,-1,4},{0,0,1},{-1,0,2}}
 local function vertex(x,y,source)
  if x%2==1 and y%2==1 then return elevation:at(math.floor(x/2),math.floor(y/2))end
  local k=key(x,y);local stored=vertices[k]
  if stored and stored[source]~=nil then return stored[source]end
  stored=stored or {};vertices[k]=stored
  local around={}
  for i,o in ipairs(offsets)do local t=tile(x+o[1],y+o[2]);if t then around[i]=t[o[3]]end end
  -- A diagonal alone cannot raise a disconnected patch across a wall/lip.
  -- Four cells form a ring. The opposite cell connects only through one
  -- adjacent cell; no queue/visited tables are needed for this fixed graph.
  -- This also avoids a LuaJIT trace failure in the former growing BFS loop.
  local clockwise=source%4+1
  local counterclockwise=(source+2)%4+1
  local opposite=(source+1)%4+1
  local a,b=around[clockwise],around[counterclockwise]
  local c=(a~=nil or b~=nil)and around[opposite]or nil
  local height=around[source]
  if a~=nil then height=math.max(height,a)end
  if b~=nil then height=math.max(height,b)end
  if c~=nil then height=math.max(height,c)end
  stored[source]=height
  if a~=nil then stored[clockwise]=height end
  if b~=nil then stored[counterclockwise]=height end
  if c~=nil then stored[opposite]=height end
  return height
 end
 local result={elevation=elevation,structure=S}
 function result.corners(x,y)
  local k=key(x,y);local q=quads[k]
  if q==false then return end
  if not q then
   if not tile(x,y)then quads[k]=false;return end
   q={vertex(x,y,3),vertex(x+1,y,4),vertex(x+1,y+1,1),vertex(x,y+1,2)}
   quads[k]=q
  end
  return q[1],q[2],q[3],q[4]
 end
 cache[map]=result;return result
end
function M.corners(map,elevation,S,x,y)
 local s=snapshot(map,elevation,S);if s then return s.corners(x,y)end
end
function M.height(map,elevation,S,wx,wz)
 local x,y=math.floor(wx/8),math.floor(wz/8)
 local a,b,c,d=M.corners(map,elevation,S,x,y)
 if a==nil then return end
 local u,v=wx/8-x,wz/8-y
 -- Same NW-SE diagonal as the renderer's two triangles, not a bilinear patch.
 if u>=v then return a+(b-a)*u+(c-b)*v end
 return a+(c-d)*u+(d-a)*v
end
-- Deform each reusable grass template by the ground's triangle heights.
-- Placements with identical relative corners still share one instanced mesh.
-- A uniform elevation uses the original template without copying its vertices.
function M.grassGroups(map,elevation,S,groups)
 if not snapshot(map,elevation,S)then return groups end
 local result={}
 for _,group in ipairs(groups)do
  Budget.check()
  local variants={}
  for at=1,#(group.placements or{}),2 do
   Budget.tick()
   local mx,mz=group.placements[at],group.placements[at+1]
   local a,b,c,d=M.corners(map,elevation,S,mx/8,mz/8)
   local signature=a and table.concat({b-a,c-a,d-a},':')or 'original'
   local variant=variants[signature]
   if not variant then
    local quads=group.quads
    if a and(b~=a or c~=a or d~=a)then
     quads={}
     for _,q in ipairs(group.quads or{})do
      Budget.tick()
      local copy={};for k,value in pairs(q)do copy[k]=value end
      for i=1,4 do
       local point=q[i];local u,w=point[1]/8,point[3]/8
       local delta=u>=w and (b-a)*u+(c-b)*w or (c-d)*u+(d-a)*w
       copy[i]={point[1],point[2]+delta,point[3]}
      end
      quads[#quads+1]=copy
     end
    end
    variant={quads=quads,placements={},elevationBases={}}
    variants[signature]=variant;result[#result+1]=variant
   end
   local count=#variant.placements
   variant.placements[count+1],variant.placements[count+2]=mx,mz
   -- nil retains the historical anchor for ungraded or protected placements.
   variant.elevationBases[count+1]=a
  end
 end
 return result
end
return M
