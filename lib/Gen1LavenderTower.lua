-- Two materials on one tower, split only at the native Route 10 / Lavender seam.
-- Authoring in one coordinate system keeps all seven roofs continuous.
local V=...
local T={height=272,width=96,depth=160,seam=96}
T.setting=V.require('ModSetting').new('lavenderTowerStyle','POKEMON TOWER',{'stone','wood'},{'STONE','WOOD'})
function T.bind(invalidate)
 for _,name in ipairs({'setIndex','sync'})do
  local previous=T.setting[name]
  T.setting[name]=function(self,...)
   local before=self:get();local value=previous(self,...)
   if before~=self:get()then invalidate()end
   return value
  end
 end
end
function T.create(P,kind,template,light)
 local C=P.decorColors
 local stone=T.setting:get()=='stone'
 local back=template=='pokemon_tower_top'
 local start,depth=back and 0 or T.seam,back and T.seam or T.depth-T.seam
 local function model(name)
  local m={terrain=true,boxes={},step=2,frameW=T.width,frameH=T.height+depth,
   depth=depth,offsetY=-T.height,template=template,nativeDoors={},landmarkHeight=T.height}
  P.models[name]=m
  local function b(x,y,z,w,h,d,c)
   local z0,z1=math.max(start,z),math.min(start+depth,z+d)
   if w>0 and h>0 and z1>z0 then m.boxes[#m.boxes+1]={x,y,z0-start,w,h,z1-z0,c}end
  end
  return m,b
 end
 local m,b=model(kind);local glass,g=model(kind..'_glass')
 m.glassKind=kind..'_glass';m.windowLight=light
 local wood,dark,weathered,roof=C.oldTimber or C.oak,C.oldBeam or C.walnut,
  C.oldBoard or C.oak,C.oldShingle or C.walnut
 local paper=C.paperWindow or 11
 if stone then
  wood,dark,weathered,roof=C.hauntedStone,C.hauntedMortar,C.hauntedWeathered,C.hauntedSlate
  paper=C.hauntedGlass
 end
 m.towerStyle=stone and 'stone'or 'wood'
 -- Shared low footing; weathered timber or masonry above it.
 b(4,0,4,88,4,152,C.stone or 14)
 for level=0,6 do
  local inset=6+level*4;local y=4+level*36
  local x0,x1=inset,96-inset;local z0,z1=inset,160-inset
  b(x0,y,z0,x1-x0,28,2,wood);b(x0,y,z1-2,x1-x0,28,2,wood)
  b(x0,y,z0,2,28,z1-z0,dark);b(x1-2,y,z0,2,28,z1-z0,wood)
  if stone then
   -- Staggered heavy masonry, deep seams and occasional weathered stones.
   -- Relief remains inside the original timber tower's silhouette.
   for row=0,3 do
    local yy=y+row*7
    for _,z in ipairs({z0-1,z1-1})do
     b(x0,yy,z,x1-x0,1,2,dark)
     for x=x0+((row%2)*6),x1-2,12 do
      b(x,yy,z,1,7,2,dark)
      if (x+row*7+level)%5==0 then b(x+1,yy+1,z,math.min(10,x1-x-1),5,2,weathered)end
     end
    end
    for _,x in ipairs({x0-1,x1-1})do
     b(x,yy,z0,2,1,z1-z0,dark)
     for z=z0+((row%2)*6),z1-2,12 do b(x,yy,z,2,7,1,dark)end
    end
   end
  else
   -- Preserve the complete original wooden variant.
   for yy=y+4,y+24,6 do
    b(x0,yy,z0,x1-x0,2,2,weathered);b(x0,yy,z1-2,x1-x0,2,2,weathered)
    b(x0,yy,z0,2,2,z1-z0,weathered);b(x1-2,yy,z0,2,2,z1-z0,weathered)
   end
  end
  for _,x in ipairs({x0,x1-4})do for _,z in ipairs({z0,z1-4})do b(x,y,z,4,30,4,dark)end end
  for _,z in ipairs({z0-2,z1})do
   local face=z==z1 and z+2 or z-2
   for x=x0+10,x1-14,18 do
    b(x-2,y+8,z,2,16,2,dark);b(x+8,y+8,z,2,16,2,dark);b(x,y+8,z,8,2,2,dark);b(x,y+22,z,8,2,2,dark);g(x,y+10,z,8,12,2,paper)
    b(x+2,y+10,face,2,12,2,dark);b(x,y+14,face,8,2,2,dark)
   end
  end
  for _,x in ipairs({x0-2,x1})do
   local face=x==x1 and x+2 or x-2
   for z=z0+12,z1-16,22 do
    b(x,y+8,z-2,2,16,2,dark);b(x,y+8,z+8,2,16,2,dark);b(x,y+8,z,2,2,8,dark);b(x,y+22,z,2,2,8,dark);g(x,y+10,z,2,12,8,paper)
    b(face,y+10,z+2,2,12,2,dark);b(face,y+14,z,2,2,8,dark)
   end
  end
  -- Broad eaves and a stepped hip roof. Hollow wall shells avoid filling a
  -- quarter-million interior voxels that can never be seen.
  b(inset-4,y+28,inset-4,104-inset*2,2,168-inset*2,dark)
  for r=0,3 do
   local i=inset-4+r*2
   b(i,y+30+r*2,i,96-i*2,2,160-i*2,roof)
  end
  -- Lifted roof tips and aged lighter fascia, without modern bright glazing.
  for _,x in ipairs({inset-4,96-inset})do
   for _,z in ipairs({inset-4,160-inset})do b(x,y+30,z,4,4,4,dark)end
  end
 end
 b(44,260,74,8,4,12,dark);b(46,264,78,4,8,4,stone and dark or C.oak)
 return kind
end
return T
