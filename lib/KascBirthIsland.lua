-- A visual island around the original six-position Deoxys puzzle. No writes
-- to map blocks, object positions, collision, puzzle state or travel scripts.
local V=...
local M={}
function M.matches(map)
 local d=map and map.def
 if not(d and (map.id or d.id)=='KA_HOENN_BIRTH_ISLAND'and d.tileset=='CAVERN'
  and d.index==1987 and d.width==8 and d.height==8 and d.generation~=2)then return false end
 local triangle,boat=false,false
 for _,p in ipairs(d.objects or{})do
  triangle=triangle or(p.name=='KA_HOENN_BIRTH_TRIANGLE'and p.x==8 and p.y==8)
  boat=boat or(p.name=='KA_HOENN_BIRTH_RETURN'and p.x==8 and p.y==13)
 end
 return triangle and boat
end
local mist={color={.51,.65,.70},density=.0035,height=20}
function M.mist(map)if M.matches(map)then return mist end end
function M.material(map,x,y)
 if not(x and y)then return -178 end
 if not map:isWalkableCell(math.floor(x/2),math.floor(y/2))then return -174 end
 local d=map.def
 local block=d.blocks[math.floor(y/4)*d.width+math.floor(x/4)+1]
 return block==21 and -179 or -178
end
function M.triangle(P)
 local kind='kasc_birth_triangle'
 if not P.models[kind]then
  local boxes={}
  for level=0,5 do
   boxes[#boxes+1]={2+level,level*2,6,12-level*2,2,4,3}
   if level<4 then boxes[#boxes+1]={3+level,level*2+.3,9.9,1,1.4,.15,13}end
  end
  boxes[#boxes+1]={7,4,10,2,2,.2,1}
  P.models[kind]={boxes=boxes,step=1,directBoxes=true,frameW=16,frameH=32,depth=16,offsetY=-16}
 end
 return kind
end
function M.find(P,map)
 if not M.matches(map)then return {}end
 local c=P.decorColors;local kind='kasc_birth_island';local d=map.def
 local m={boxes={},directBoxes=true,step=1,frameW=256,frameH=288,depth=256,offsetY=-32,
  replacesGround=true,groundAt=function(x,z)
   return map:isWalkableCell(math.floor(x/16),math.floor(z/16))and 5 or 20
  end,support=0,actorSurface=true}
 local function box(x,y,z,w,h,depth,color)m.boxes[#m.boxes+1]={x,y,z,w,h,depth,color}end
 for cy=0,15 do for cx=0,15 do
  local x,z=cx*16,cy*16
  if map:isWalkableCell(cx,cy)then
   -- Opaque sandstone foundation, continuous beneath every puzzle position.
   box(x,-7,z,16,6.9,16,c.looseRock6)
  else
   -- Broken shoreline on the blocked side only, never on puzzle approaches.
   local edge=false
   for _,p in ipairs({{0,1},{0,-1},{1,0},{-1,0}})do
    if map:isWalkableCell(cx+p[1],cy+p[2])then edge=true end
   end
   if edge then
    for i=0,3 do
     local sx=(cx*5+cy*3+i*7)%10;local sz=(cx*3+cy*7+i*5)%10
     local size=4+(cx*13+cy*7+i)%3
     box(x+sx,-3,z+sz,size,4+(cx*7+cy*11+i*3)%4,size,i%2==0 and c.looseRock5 or c.looseRock6)
    end
   end
  end
 end end
 -- An open landing by the return sailor; visual deck stays flush with the
 -- native walking surface and leaves both sides available for interaction.
 for z=13*16,14*16-1,4 do box(8*16+.5,.03,z+.3,15,.12,3.4,c.oldBoard)end
 -- A small beached return boat sits beyond the walkable landing, not on
 -- the sailor's interaction cell. Its tapered hull is entirely closed.
 box(130,-1,225,12,2,25,c.oldBeam)
 box(128,1,229,16,1,18,c.oldBoard)
 box(126,1,230,2,4,16,c.walnut);box(144,1,230,2,4,16,c.walnut)
 box(128,1,227,16,4,3,c.walnut);box(130,1,246,12,4,3,c.walnut)
 box(128,3,236,16,1.5,3,c.oak);box(128,3,243,16,1.5,2,c.oak)
 P.models[kind]=m
 return {{kind=kind,tx=0,ty=0,w=d.width*4,h=d.height*4,voxelOnly=true,
  enabled=function()return V.require('VoxelItems').setting:get()end}}
end
return M
