-- A finish for existing stair geometry, not new collision or warp geometry.
local V=...
local M={}
M.setting=V.require('ModSetting').new('voxelStairs','STAIRS',{true,false},{'ON','OFF'},true)
local families={REDS_HOUSE_1=2,REDS_HOUSE_2=2,GATE=2,SHIP=3,
 HOUSE=2,MANSION=2,LOBBY=7,MUSEUM=7,FACILITY=6,INTERIOR=6,
 CEMETERY=8,CAVERN=39,UNDERGROUND=39}
function M.material(map)
 local d=map and map.def
 if not d or d.generation==2 or not M.setting:get() then return nil end
 local f=families[d.tileset]
 return f and -128-f
end
-- Native CAVERN shelf stairs run north/south across a six-pixel shelf.
-- They are ordinary walkable terrain, not a ladder warp. Recognise the
-- complete motif and its two endpoints before assigning a physical flight.
function M.caveFloorHeight(map,tile)
 if map and map.def and map.def.tileset=='CAVERN' and M.material(map)
  and (tile==5 or tile==41)then return 6 end
end
function M.caveStep(map,cx,cy)
 if not(map and map.def and map.def.tileset=='CAVERN' and M.material(map)
  and type(map.tileAt)=='function' and type(map.cellTile)=='function')then return end
 local x,y=cx*2,cy*2
 if map:tileAt(x,y)~=21 or map:tileAt(x+1,y)~=22
  or map:tileAt(x,y+1)~=21 or map:tileAt(x+1,y+1)~=22 then return end
 if not M.caveFloorHeight(map,map:cellTile(cx,cy-1))then return end
 local south=map:cellTile(cx,cy+1)
 if M.caveFloorHeight(map,south)then return 6,0 end
 if south==20 or south==32 or south==33 or south==42 then return 0,6 end
end
function M.caveSupport(map,cx,cy)
 if not(map and type(map.cellTile)=='function')then return end
 local shelf=M.caveFloorHeight(map,map:cellTile(cx,cy));if shelf then return shelf end
 local base,h=M.caveStep(map,cx,cy);if base then return base+h/2 end
end
function M.claim(S,map)
 if not M.material(map) then return end
 if map.def.tileset=='CAVERN' and map.def.width and map.def.height then
  local budget=V.require('BuildBudget')
  for cy=0,map.def.height*2-1 do
   if budget.check then budget.check()end
   for cx=0,map.def.width*2-1 do
   local base,h=M.caveStep(map,cx,cy)
   if base then
    local free=true
    for dy=0,1 do for dx=0,1 do
     local k=(cy*2+dy+64)*4096+cx*2+dx+64
     if not S.shapeAt[k] or (S.voxelFurnitureClaims and S.voxelFurnitureClaims[k])then free=false end
    end end
    if free then for dy=0,1 do for dx=0,1 do
     local k=(cy*2+dy+64)*4096+cx*2+dx+64
     S.shapeAt[k]={class='stair_n',art='stair',h=h,stairBase=base,authored=true}
    end end end
   end
  end end
 end
 local cells=V.require('Gen1StairCells')
 for _,warp in ipairs(map.def.warps or {})do
  local class=cells.classForWarp(map,warp)
  if class then
   local occupied=false
   for dy=0,1 do for dx=0,1 do
    local k=(warp.y*2+dy+64)*4096+warp.x*2+dx+64
    if S.voxelFurnitureClaims and S.voxelFurnitureClaims[k] then occupied=true end
   end end
   if not occupied then
    for dy=0,1 do for dx=0,1 do
     local k=(warp.y*2+dy+64)*4096+warp.x*2+dx+64
     S.shapeAt[k]={class=class,art='stair',h=16,flat=false,authored=true}
    end end
   end
  end
 end
end
function M.finish(map,quads,first,s)
 local material=M.material(map)
 if not material then return end
 local last=#quads
 local down=s.class=='stair_down_e' or s.class=='stair_down_w'
 local east=s.class=='stair_e' or s.class=='stair_down_e'
 local axis=s.class=='stair_n' and 3 or 1
 local across=axis==1 and 3 or 1
 for i=first,last do
  local q=quads[i]
  q.uv={{material,0},{material,0},{material,0},{material,0}}
  local tread=q[1][2]==q[2][2] and q[2][2]==q[3][2] and q[3][2]==q[4][2]
  tread=tread and math.abs((q[2][1]-q[1][1])*(q[3][3]-q[1][3])-(q[2][3]-q[1][3])*(q[3][1]-q[1][1]))>1e-6
  if tread then
   q.shade=down and .88 or 1
   -- Split the actual tread, rather than overlaying a coplanar stripe.
   -- Its low edge is bright stone/timber; the darker riser underneath
   -- makes every physical step legible from oblique and overhead views.
   local lo,hi=math.min(q[1][axis],q[2][axis],q[3][axis],q[4][axis]),math.max(q[1][axis],q[2][axis],q[3][axis],q[4][axis])
   local lowEdge=(east and not down) or (not east and down)
   local a,b=lowEdge and lo or hi-.75,lowEdge and lo+.75 or hi
   local z0,z1=math.min(q[1][across],q[2][across],q[3][across],q[4][across]),math.max(q[1][across],q[2][across],q[3][across],q[4][across]);local y=q[1][2]
   for j=1,4 do
    if lowEdge and q[j][axis]==lo then q[j][axis]=b
    elseif not lowEdge and q[j][axis]==hi then q[j][axis]=a end
   end
   local corners=axis==1 and {{a,y,z0},{b,y,z0},{b,y,z1},{a,y,z1}}
    or {{z0,y,a},{z1,y,a},{z1,y,b},{z0,y,b}}
   quads[#quads+1]={corners[1],corners[2],corners[3],corners[4],
    uv={{material,0},{material,0},{material,0},{material,0}},shade=1.15,stairNosing=true}
  else
   q.shade=math.min(q.shade or .75,.68)
  end
 end
end
function M.bind(invalidate)
 for _,name in ipairs({'setIndex','sync'})do
  local previous=M.setting[name]
  M.setting[name]=function(self,...)
   local before=self:get();local value=previous(self,...)
   if before~=self:get()then invalidate()end
   return value
  end
 end
end
return M
