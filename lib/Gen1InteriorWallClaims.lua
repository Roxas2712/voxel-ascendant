local V=...
local M={}
-- FACILITY calls equipment and locked key shutters "wall" too. Those have
-- their own visual/gameplay owner and must survive when Voxel Items is OFF.
local facilityWall={[42]=true,[43]=true,[44]=true,[45]=true,[46]=true,
 [58]=true,[59]=true,[60]=true,[87]=true,[89]=true}
local officeWall={[16]=true,[45]=true,[46]=true,[87]=true,[88]=true,
 [89]=true,[90]=true,[91]=true,[92]=true}
local officeJunctionBlocks={[37]=true,[39]=true,[46]=true,[55]=true}
local officeFaceBlocks={[18]=true,[19]=true,[22]=true,[51]=true,[53]=true}
local officeFaceTiles={[19]=true,[20]=true,[35]=true,[36]=true,[52]=true,[68]=true}
local function officeSpecial(map,x,y,id)
 if map.id~='SILPH_CO_11F' or not map.def.blocks then return false end
 local b=map.def.blocks[math.floor(y/4)*map.def.width+math.floor(x/4)+1]
 -- 91/92 also form the table pedestal and terminal apron. Only the
 -- native partition junction blocks belong to the panorama replacement.
 return ((id==91 or id==92) and officeJunctionBlocks[b])
   or (officeFaceTiles[id] and officeFaceBlocks[b]) or false
end
local lanceWall={[16]=true,[36]=true,[37]=true,[38]=true,[39]=true,[53]=true,[62]=true,[66]=true}
local function lanceFrame(map,x,y)
 local d=map.def
 if map.id~='LANCES_ROOM'or d.generation==2 or d.tileset~='DOJO'
   or d.width~=13 or d.height~=13 or not d.blocks then return false end
 local bx,by=math.floor(x/4),math.floor(y/4)
 -- These two blocks switch between the open entry and the story lock.
 if by==6 and (bx==2 or bx==3)then return false end
 local b=d.blocks[by*d.width+bx+1]
 if b==nil or b==d.borderBlock then return false end
 for _,w in ipairs(d.warps or{})do
  if math.floor(x/2)==w.x and math.floor(y/2)==w.y then return false end
 end
 return true
end
function M.claim(S,map)
 local H=V.require("HorizonWall")
 local p=H.enabled() and H.interiorProfileFor(map)
 if not (p and p.nativeRoomPanels) then return end
 S.interiorWallClaims={}
 local tw,th=map.def.width*4,map.def.height*4
 local key=function(x,y)return (y+64)*4096+x+64 end
 -- Layout owns the replacement faces, including indented room outlines and
 -- the two sides of facility partitions. Claim only the narrow native wall
 -- course beside a real panel; an unrelated internal wall must remain.
 local covered={}
 for _,panel in ipairs(V.require('Gen1InteriorLayout').panelsFor(map,p))do
  local horizontal=panel.edge=='north' or panel.edge=='south'
  local first,last=math.floor(panel.from/8),math.ceil(panel.upto/8)-1
  local near,far=math.floor(panel.at/8)-2,math.ceil(panel.at/8)+1
  for along=first,last do for across=near,far do
   local x,y=horizontal and along or across,horizontal and across or along
   if x>=0 and y>=0 and x<tw and y<th then covered[key(x,y)]=true end
  end end
 end
 for y=0,th-1 do for x=0,tw-1 do
  local k=key(x,y);local shape=S.shapeAt[k]
  local special=officeSpecial(map,x,y,(S.tileAt or {})[k])
  local lance=lanceFrame(map,x,y)
  local frame=lance and lanceWall[(S.tileAt or{})[k]]
  local corner=lance and shape and shape.class=='void'and (S.tileAt or{})[k]==15
  if (covered[k] or y<4 or y>=th-2 or x<2 or x>=tw-2 or frame or corner) and shape and (shape.class=='wall' or special or corner)
      and (map.def.tileset~='FACILITY' or facilityWall[(S.tileAt or {})[k]])
      and (map.id~='SILPH_CO_11F' or officeWall[(S.tileAt or {})[k]] or special)
      and not (S.voxelFurnitureClaims and S.voxelFurnitureClaims[k]) then
   -- A low native wall face would sit in front of the new full-height wall.
   S.interiorWallClaims[k]=true
   S.skip[k]=true;S.ground[k]=V.require("VoxelFurniture").floorTile(map,x,y)
   S.shapeAt[k]={class='ground',h=0,art='flat',flat=true}
  end
 end end
 -- Native script gates are a separate exact pattern, never inferred from
 -- a generic wall/counter tile that could belong to equipment elsewhere.
 for _,door in ipairs(V.require('Gen1SecurityDoors').forMap(map))do
  if door.closed then for dy=0,door.h-1 do for dx=0,door.w-1 do
   local x,y=door.tx+dx,door.ty+dy;local k=key(x,y)
   S.interiorWallClaims[k]=true;S.skip[k]=true
   S.ground[k]=V.require('VoxelFurniture').floorTile(map,x,y)
   S.shapeAt[k]={class='ground',h=0,art='flat',flat=true}
  end end end
 end

 -- The original black-and-white break drawing lies flat across the north
 -- warp. Only its verified 2x2 graphic is replaced by the matching room floor;
 -- the real wall breach, rubble and outside view have their own geometry.
 if V.require('Gen1BreachExterior').source(map)then
  for y=0,1 do for x=6,7 do
   local k=key(x,y);S.interiorWallClaims[k]=true;S.skip[k]=true
   S.ground[k]=V.require('VoxelFurniture').floorTile(map,x,y)
   S.shapeAt[k]={class='ground',h=0,art='flat',flat=true}
  end end
 end
end
return M
