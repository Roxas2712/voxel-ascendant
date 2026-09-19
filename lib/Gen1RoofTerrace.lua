-- Native roof furnishings replaced as one exact, render-only footprint.
-- No gameplay object, sign, walkability table or warp is removed.
local V=...
local M={}
local contracts=V.data('rooftop_terraces')
local required={
 CELADON_MART_ROOF={{15,2,'CELADON_MART_5F'}},
 CELADON_MANSION_ROOF={{6,1,'CELADON_MANSION_3F'},{2,1,'CELADON_MANSION_3F'},
  {2,7,'CELADON_MANSION_ROOF_HOUSE'}},
}
function M.matches(map)
 if not V.require('Gen1Rooftops').matches(map)then return false end
 local contract=contracts[map.id];local d=map.def
 if not contract or #(d.blocks or{})~=#contract.blocks then return false end
 for i,b in ipairs(contract.blocks)do if d.blocks[i]~=b then return false end end
 if #(d.warps or{})~=#required[map.id]then return false end
 for _,want in ipairs(required[map.id])do
  local found=false
  for _,warp in ipairs(d.warps)do
   if warp.x==want[1]and warp.y==want[2]and warp.destMap==want[3]then found=true end
  end
  if not found then return false end
 end
 if type(map.tileAt)~='function'then return false end
 for y,row in ipairs(contract.tiles)do for x,tile in ipairs(row)do
  if map:tileAt(x-1,y-1)~=tile then return false end
 end end
 return true
end
function M.register(P,F)
 local C=P.decorColors
 for _,id in ipairs({'CELADON_MART_ROOF','CELADON_MANSION_ROOF'})do
  local mart=id=='CELADON_MART_ROOF';local w,d=mart and 320 or 128,mart and 128 or 192
  local kind=mart and 'celadon_mart_terrace'or 'celadon_mansion_terrace'
  local m={boxes={},frameW=w,frameH=d+40,depth=d,offsetY=-40,
   support=0,actorSurface=true,replacesGround=true,roofTerrace=true,directBoxes=true,step=1}
  P.models[kind]=m
  local function b(x,y,z,bw,h,bd,c)
   assert(bw>0 and h>0 and bd>0)
   m.boxes[#m.boxes+1]={x,y,z,bw,h,bd,c}
  end
  local holes=mart and {{240,32}}or {{32,16},{96,16}}
  -- The ordinary terrain pass retains the floor, using the roof's modern
  -- material. Keep real stair wells open instead of laying a sheet over them.
  local x0,x1=mart and 32 or 0,mart and 288 or w
  m.groundAt=function(x,z)
   if x<x0 or x>=x1 then return nil end
   for _,p in ipairs(holes)do if x>=p[1]and x<p[1]+16 and z>=p[2]and z<p[2]+16 then return nil end end
   return 1
  end
  -- Glazing is clear space between slender solid frames. No opaque blue
  -- image or depth-writing transparent plane can hide the real skyline.
  local function rail(x,z,length,alongX,height)
   height=height or 29
   local function bar(a,y,len,h,c)
    if alongX then b(x+a,y,z-.55,len,h,1.1,c)
    else b(x-.55,y,z+a,1.1,h,len,c)end
   end
   bar(0,0,length,1.2,C.slate);bar(0,height,length,.9,C.silver)
   local bays=math.max(1,math.ceil(length/64))
   for i=0,bays do bar(i*length/bays-.45,1,.9,height-1,C.silver)end
  end
  rail(x0+1,1,x1-x0-2,true);rail(x0+1,d-1,x1-x0-2,true)
  rail(x0+1,1,d-2,false);rail(x1-1,1,d-2,false)
  if not mart then
   -- Original mansion corridor is separated by a blocked band.
   rail(88,1,151,false);rail(16,152,72,true)
  end
  local function stairs(x,z)
   -- Descent stays inside the original 16px warp cell. A low portal and
   -- handrails stand on its blocked shoulders, leaving the approach open.
   for i=0,5 do
    local zz=z+i*16/6;local top=-12+i*2
    b(x,top-1,zz,16,1,16/6,C.slate)
    b(x,top,zz+16/6-.45,16,.25,.45,14)
   end
   b(x-1,0,z,1,27,16,C.silver);b(x+16,0,z,1,27,16,C.silver)
   b(x-1,27,z,18,1,16,14)
   b(x+1,23,z+15,14,3,.7,C.navy)
   -- Small downward chevron built from voxels, readable without language.
   for i=0,2 do b(x+5+i,24-i*.5,z+15.7,1,.7,.4,7);b(x+10-i,24-i*.5,z+15.7,1,.7,.4,7)end
  end
  for _,p in ipairs(holes)do stairs(p[1],p[2])end
  if mart then
   -- Three native vending interactions: same cells and facing as before.
   for i,p in ipairs({{160,16},{176,16},{192,32}})do
    local x,z=p[1],p[2];local accent=({C.martBlue,7,1})[i]
    b(x+.5,0,z+.5,15,1,15,C.slate);b(x+1,1,z+1,14,26,14,14)
    b(x+1,27,z+1,14,1,14,accent)
    b(x+2,10,z+15,9,14,.7,C.navy)
    for row=0,2 do for col=0,2 do
     b(x+3+col*2.5,11+row*4,z+15.7,1.5,2.7,.6,({7,9,11})[col+1])
    end end
    b(x+12,14,z+15,2,6,.7,C.slate);b(x+12.5,17,z+15.7,1,2,.4,9)
    b(x+3,4,z+15,9,3,.8,C.navy);b(x+2,25,z+15,12,1,.8,accent)
   end
   -- Original table footprints remain visibly occupied, with modern tops.
   for _,p in ipairs({{64,32},{128,64}})do
    local x,z=p[1],p[2]
    b(x+12,0,z+12,8,9,8,C.slate);b(x+1,9,z+1,30,1.5,30,C.silver)
    b(x+2,10.5,z+2,28,.5,28,2)
   end
   -- Service/stair enclosure: low walls preserve the blocked footprint,
   -- while open upper glazing keeps the horizon visible.
   b(208,0,16,80,5,16,C.slate)
   b(208,0,32,32,5,16,C.slate);b(256,0,32,32,5,16,C.slate)
   rail(208,16,80,true);rail(208,16,32,false);rail(288,16,32,false)
   b(210,10,47,9,9,1,C.navy);b(212,12,48,5,1,.4,14);b(212,15,48,5,1,.4,14)
  else
   -- Replace the old patterned roof shed with a compact glazed pavilion.
   -- Native south door remains x=32..48 and z=112..128.
   b(16,0,64,48,3,48,C.slate)
   for _,x in ipairs({16,62})do b(x,3,64,2,29,62,14)end
   b(16,3,64,48,29,2,14)
   b(16,0,124,16,4,2,C.slate);b(48,0,124,16,4,2,C.slate)
   for _,x in ipairs({16,30,48,62})do b(x,4,124,2,27,2,C.silver)end
   b(16,31,64,48,2,64,14);b(15,33,63,50,1,66,C.slate)
   b(31,27,126,18,3,1,C.navy);b(35,28,127,10,.8,.3,7)
   b(51,8,126,10,9,1,C.navy);b(53,10,127,6,1,.3,14);b(53,13,127,6,1,.3,14)
  end
  local p={kind=kind,sets={[mart and 'LOBBY'or 'MANSION']=true},maps={[id]=true},
   x=0,y=0,tiles=contracts[id].tiles,guard=M.matches}
  table.insert(F.patterns,1,p)
 end
end
return M
