-- Exact surface extraction for authored integer-lattice boxes. Work follows
-- box boundaries, not the number of occupied interior voxels. Later boxes
-- retain colour ownership and all boxes occlude internal neighbour faces.
local V=...
local Budget=V.require('BuildBudget')
return function(boxes,step,paletteSize,G)
 local bs={}
 for i,b in ipairs(boxes)do
  bs[i]={b[1]/step,b[2]/step,b[3]/step,(b[1]+b[4])/step,
   (b[2]+b[5])/step,(b[3]+b[6])/step,b[7]}
 end
 -- Index coarse occupied regions once. A face can only be covered by a box
 -- touching its source or neighbouring cell, not every box in the model.
 -- Keep original box order after lookup: later boxes still own overlaps.
 local bucket=math.max(1,math.floor(8/step))
 local bins={}
 local function address(x,y,z)return x..':'..y..':'..z end
 for i,b in ipairs(bs)do
  for z=math.floor(b[3]/bucket),math.floor((b[6]-1)/bucket)do
   for y=math.floor(b[2]/bucket),math.floor((b[5]-1)/bucket)do
    for x=math.floor(b[1]/bucket),math.floor((b[4]-1)/bucket)do
     Budget.tick()
     local k=address(x,y,z);local bin=bins[k]
     if not bin then bin={};bins[k]=bin end
     bin[#bin+1]=i
    end
   end
  end
 end
 local function candidates(b,axis,source,neighbor)
  local lo={b[1],b[2],b[3]};local hi={b[4]-1,b[5]-1,b[6]-1}
  lo[axis],hi[axis]=math.min(source,neighbor),math.max(source,neighbor)
  local found,out={},{}
  for z=math.floor(lo[3]/bucket),math.floor(hi[3]/bucket)do
   for y=math.floor(lo[2]/bucket),math.floor(hi[2]/bucket)do
    for x=math.floor(lo[1]/bucket),math.floor(hi[1]/bucket)do
     Budget.tick()
     for _,i in ipairs(bins[address(x,y,z)]or{})do
      if not found[i]then found[i]=true;out[#out+1]=i end
     end
    end
   end
  end
  table.sort(out)
  return out
 end
 local groups={}
 for face=1,6 do
  local axis=face<=2 and 1 or face<=4 and 2 or 3
  local ua=axis==1 and 3 or 1;local va=axis==2 and 3 or 2
  local plus=face%2==1
  for i,b in ipairs(bs)do
   Budget.check()
   local plane=plus and b[axis+3]or b[axis]
   local source=plus and plane-1 or plane
   local neighbor=plus and plane or plane-1
   local rects={{b[ua],b[va],b[ua+3],b[va+3]}}
   for _,j in ipairs(candidates(b,axis,source,neighbor))do local other=bs[j];if j~=i then
    local occludes=neighbor>=other[axis]and neighbor<other[axis+3]
    local owns=j>i and source>=other[axis]and source<other[axis+3]
    if occludes or owns then
     local nextRects={}
     for _,r in ipairs(rects)do
      Budget.tick()
      local x0,y0=math.max(r[1],other[ua]),math.max(r[2],other[va])
      local x1,y1=math.min(r[3],other[ua+3]),math.min(r[4],other[va+3])
      if x1<=x0 or y1<=y0 then nextRects[#nextRects+1]=r
      else
       if r[1]<x0 then nextRects[#nextRects+1]={r[1],r[2],x0,r[4]}end
       if x1<r[3]then nextRects[#nextRects+1]={x1,r[2],r[3],r[4]}end
       if r[2]<y0 then nextRects[#nextRects+1]={x0,r[2],x1,y0}end
       if y1<r[4]then nextRects[#nextRects+1]={x0,y1,x1,r[4]}end
      end
     end
     rects=nextRects;if #rects==0 then break end
    end
   end end
   if #rects>0 then
    local key=face..':'..plane..':'..b[7]
    local group=groups[key]
    if not group then group={face=face,axis=axis,ua=ua,va=va,plane=plane,color=b[7],rects={}};groups[key]=group end
    for _,r in ipairs(rects)do group.rects[#group.rects+1]=r end
   end
  end
 end
 -- Join matching strips before curvature tessellation. This removes seams
 -- introduced by different box partitions without rasterising large planes.
 local function merge(rects,horizontal)
  local lo,hi,crossLo,crossHi=horizontal and 1 or 2,horizontal and 3 or 4,horizontal and 2 or 1,horizontal and 4 or 3
  table.sort(rects,function(a,b)
   if a[crossLo]~=b[crossLo]then return a[crossLo]<b[crossLo]end
   if a[crossHi]~=b[crossHi]then return a[crossHi]<b[crossHi]end
   return a[lo]<b[lo]
  end)
  local out={}
  for _,r in ipairs(rects)do
   local last=out[#out]
   if last and last[crossLo]==r[crossLo]and last[crossHi]==r[crossHi]and last[hi]==r[lo]then last[hi]=r[hi]
   else out[#out+1]=r end
  end
  return out
 end
 local vertices,indices,faces={},{},{}
 local maxSpan=math.max(1,math.floor(8/step))
 local keys={};for key in pairs(groups)do keys[#keys+1]=key end;table.sort(keys)
 for _,key in ipairs(keys)do local g=groups[key]
  Budget.check()
  local rs=g.rects
  repeat local count=#rs;rs=merge(merge(rs,true),false);Budget.check();if #rs==count then break end until false
  for _,r in ipairs(rs)do
   for y=r[2],r[4]-1,maxSpan do for x=r[1],r[3]-1,maxSpan do
    Budget.tick()
    local origin,scale={0,0,0},{1,1,1}
    origin[g.axis]=g.plane-(g.face%2==1 and 1 or 0);origin[g.ua]=x;origin[g.va]=y
    scale[g.ua]=math.min(maxSpan,r[3]-x);scale[g.va]=math.min(maxSpan,r[4]-y)
    G.pushQuad(indices,#vertices/4);faces[#faces+1]=g.face
    for _,c in ipairs(G.FACE_CORNERS[g.face])do
     vertices[#vertices+1]={(origin[1]+c[1]*scale[1])*step,(origin[2]+c[2]*scale[2])*step,
      (origin[3]+c[3]*scale[3])*step,(g.color-.5)/paletteSize,.5,G.FACE_SHADE[g.face]}
    end
   end end
  end
 end
 return vertices,indices,faces
end
