-- Close only sealed decorative shelf pockets inside native cave rock.
-- The plan is render-only: never mutate map blocks, collision or Structures.
local M={}
local rock={};for _,t in ipairs({2,3,18,19,12,13,28,29,16,17,49,23,4,7,40,37,38,14,15,30,31,6,39,36,1})do rock[t]=true end
local function key(x,y)return (y+64)*4096+x+64 end
local steps={{1,0,'right','left'},{-1,0,'left','right'},{0,1,'down','up'},{0,-1,'up','down'}}
function M.plan(map,S,height)
 local def=map and map.def
 if not def or def.tileset~='CAVERN' or type(map.isWalkableCell)~='function' then return {} end
 local w,h=def.width*4,def.height*4
 local protected={}
 for _,list in ipairs({def.warps or{},def.objects or{},def.signs or{}})do
  for _,o in ipairs(list)do
   if type(o.x)=='number'and type(o.y)=='number'then
    protected[key(o.x,o.y)]=true
   end
  end
 end
 local function shelf(x,y)
  if x<0 or y<0 or x>=w or y>=h then return false end
  local k=key(x,y);local s=S.shapeAt[k];local t=S.tileAt[k]
  return s and not S.skip[k]and not S.runs[k]and
   (s.class=='ledge' or s.class=='ground')and(t==5 or t==41)
 end
 local seen,caps={},{}
 for y=0,h-1 do for x=0,w-1 do
  if shelf(x,y)and not seen[key(x,y)]then
   local queue={{x,y}};seen[key(x,y)]=true
   local cells,valid,top={},true,nil
   local at=1
   while at<=#queue do
    local p=queue[at];at=at+1
    local cx,cy=math.floor(p[1]/2),math.floor(p[2]/2)
    cells[key(cx,cy)]={cx,cy}
    if protected[key(cx,cy)]then valid=false end
    for _,d in ipairs(steps)do
     local nx,ny=p[1]+d[1],p[2]+d[2];local k=key(nx,ny)
     if shelf(nx,ny)then
      if not seen[k]then seen[k]=true;queue[#queue+1]={nx,ny}end
     else
      local s=S.shapeAt[k]
      if nx<0 or ny<0 or nx>=w or ny>=h or not s or s.class~='wall'
       or not rock[S.tileAt[k]]or S.skip[k]or S.runs[k]then valid=false
      else
       local edge=height(nx,ny)
       top=top and math.min(top,edge)or edge
      end
     end
    end
   end
   -- A tile drawing can share a walkable 16px cell with its rock rim.
   -- Reject any pocket whose gameplay cells connect to an outside route.
   -- Ask actual collision: cave $05/$20 are both walkable, but their
   -- height-transition pair blocks crossing without the authored stairs.
   -- Stairs, ladders, holes and water already fail the boundary whitelist.
   for _,c in pairs(cells)do
    if map:isWalkableCell(c[1],c[2])then
     for _,d in ipairs(steps)do
      local nx,ny=c[1]+d[1],c[2]+d[2]
      if not cells[key(nx,ny)]and map:isWalkableCell(nx,ny)then
       local C=require('src.world.Collision')
       local out=C.canMove(map,{}, {cellX=c[1],cellY=c[2],surfing=false},d[3])
       local inward=C.canMove(map,{}, {cellX=nx,cellY=ny,surfing=false},d[4])
       if out or inward then valid=false end
      end
     end
    end
   end
   if valid and top then
    for _,p in ipairs(queue)do if height(p[1],p[2])>=top then valid=false end end
   end
   if valid and top then for _,p in ipairs(queue)do caps[key(p[1],p[2])]=top end end
  end
 end end
 return caps
end
return M
