-- Conservative bounds against the actual draw pass, including world bend.
-- A missing bound/matrix keeps the prop. No resource or gameplay ownership.
local M={}
function M.bounds(vertices,budget)
  if not vertices or #vertices==0 then return nil end
  local x0,y0,z0=math.huge,math.huge,math.huge
  local x1,y1,z1=-math.huge,-math.huge,-math.huge
  for i=1,#vertices do
    local v=vertices[i];local x,y,z=v[1],v[2],v[3]
    if x<x0 then x0=x end;if y<y0 then y0=y end;if z<z0 then z0=z end
    if x>x1 then x1=x end;if y>y1 then y1=y end;if z>z1 then z1=z end
    -- Large authored props can exceed 400k vertices. Their bounds are part
    -- of the asynchronous build too, not an unbudgeted final pass.
    if budget and i%256==0 then budget.check()end
  end
  return {x0,y0,z0,x1,y1,z1}
end
local staticBounds=setmetatable({},{__mode='k'})
-- Only call for immutable scene meshes (water from a completed terrain slot).
-- Cache weakly so retired map meshes never stay alive through this lookup.
function M.staticMeshBounds(mesh)
  if not mesh or mesh.__voxelMeshBundle or not mesh.getVertexCount or not mesh.getVertex then return nil end
  local cached=staticBounds[mesh]
  if cached~=nil then return cached or nil end
  local b={math.huge,math.huge,math.huge,-math.huge,-math.huge,-math.huge}
  local count=mesh:getVertexCount()
  if count==0 then staticBounds[mesh]=false;return nil end
  for i=1,count do
    local x,y,z=mesh:getVertex(i)
    b[1],b[2],b[3]=math.min(b[1],x),math.min(b[2],y),math.min(b[3],z)
    b[4],b[5],b[6]=math.max(b[4],x),math.max(b[5],y),math.max(b[6],z)
  end
  staticBounds[mesh]=b;return b
end
local identity={1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}
function M.visibleWater(draws,vp,k,cx,cz)
  local accepts=M.forView(vp,k,cx,cz);local kept={}
  for _,d in ipairs(draws)do
    if accepts(M.staticMeshBounds(d[1]),d[3]or identity)then kept[#kept+1]=d end
  end
  return kept
end
function M.forView(vp,k,cx,cz)
  if not vp then return function()return true end end
  local planes={}
  for axis=0,2 do for _,sign in ipairs({-1,1})do
    local p={};local margin=axis<2 and 1.05 or 1
    for i=1,4 do p[i]=vp[12+i]*margin+sign*vp[axis*4+i]end
    p[5],p[6],p[7]=p[1]>=0,p[2]>=0,p[3]>=0
    planes[#planes+1]=p
  end end
  k,cx,cz=k or 0,cx or 0,cz or 0
  local function distance(lo,hi,c)
    local a,b=lo-c,hi-c
    return a<=0 and b>=0 and 0 or math.min(a*a,b*b),math.max(a*a,b*b)
  end
  return function(b,m)
    if not b or not m then return true end
    -- Furniture is translated; transformed actors stay on their established
    -- path rather than risking a false rejection of rotated/scaled bounds.
    if m[1]~=1 or m[2]~=0 or m[3]~=0 or m[5]~=0 or m[6]~=1 or m[7]~=0
      or m[9]~=0 or m[10]~=0 or m[11]~=1 then return true end
    local x0,y0,z0=b[1]+m[4],b[2]+m[8],b[3]+m[12]
    local x1,y1,z1=b[4]+m[4],b[5]+m[8],b[6]+m[12]
    if k~=0 then
      local nearX,farX=distance(x0,x1,cx)
      local nearZ,farZ=distance(z0,z1,cz)
      local a,bend=k*(nearX+nearZ),k*(farX+farZ)
      y0,y1=y0-math.max(a,bend),y1-math.min(a,bend)
    end
    -- The positive support vertex gives the same plane maximum as
    -- center + absolute normal * half-size, without rebuilding extents or
    -- taking eighteen absolute values per object in both render passes.
    for _,p in ipairs(planes)do
      local far=p[1]*(p[5] and x1 or x0)+p[2]*(p[6] and y1 or y0)
        +p[3]*(p[7] and z1 or z0)+p[4]
      if far < -1e-5 then return false end
    end
    return true
  end
end
return M
