-- Gentle torso rise on the registered seated card. Lap and feet stay planted;
-- the cached pose texture (including eyes/head yaw) needs no extra redraw.
local M={}
function M.new(voxel)
 local entries={};local serial,count=0,0
 local api={updates=0,meshes=0}
 local function release(key)
  entries[key].mesh:release();entries[key]=nil;count=count-1;api.meshes=count
 end
 local function weight(y)
  local t=math.max(0,math.min(1,(y-310)/155))
  return 1-t*t*(3-2*t)
 end
 function api:prepare(original,amount)
  if type(amount)~='number' or amount~=amount or amount<0 or amount>1 then return nil end
  if amount==0 then return original end
  local n=original:getVertexCount();if n~=4 and n~=16 then return nil end
  serial=serial+1
  local entry=entries[original]
  if not entry then
   if count>=8 then
    local oldest,used
    for key,value in pairs(entries)do if not used or value.used<used then oldest,used=key,value.used end end
    release(oldest)
   end
   local vertices,indices,baseY,deltas={},{},{},{}
   for quad=0,n/4-1 do
    local a,b,c,d={original:getVertex(quad*4+1)},{original:getVertex(quad*4+2)},
      {original:getVertex(quad*4+3)},{original:getVertex(quad*4+4)}
    local bottom,top=a[5]*768,d[5]*768
    if bottom<=top then return nil end
    local unit=(d[2]-a[2])/(bottom-top)
    local cuts={bottom}
    for _,y in ipairs({465,420,370,320,280})do if y<bottom and y>top then cuts[#cuts+1]=y end end
    cuts[#cuts+1]=top
    local function vertex(lo,hi,y)
     local t=(bottom-y)/(bottom-top);local v={}
     for k=1,6 do v[k]=lo[k]+(hi[k]-lo[k])*t end
     vertices[#vertices+1]=v;baseY[#vertices]=v[2];deltas[#vertices]=3*unit*weight(y)
    end
    for i=1,#cuts-1 do
     local base=#vertices/4
     vertex(a,d,cuts[i]);vertex(b,c,cuts[i]);vertex(b,c,cuts[i+1]);vertex(a,d,cuts[i+1])
     voxel.pushQuad(indices,base)
    end
   end
   entry={mesh=assert(voxel.newMesh(vertices,indices)),vertices=vertices,baseY=baseY,deltas=deltas}
   entries[original]=entry;count=count+1;api.meshes=count
  end
  entry.used=serial
  if entry.amount~=amount then
   for i,v in ipairs(entry.vertices)do v[2]=entry.baseY[i]+entry.deltas[i]*amount end
   entry.mesh:setVertices(entry.vertices);entry.amount=amount;api.updates=api.updates+1
  end
  return entry.mesh
 end
 function api:clear()for key in pairs(entries)do release(key)end end
 return api
end
return M
