-- Original building art remains a light source when replacement cities are
-- disabled. Consume only published building stamps, never hidden replacements.
local V=...
local M={}
local models=setmetatable({},{__mode='k'})
local function point(q,i)
 if type(q[1])=='number'then local k=(i-1)*3;return q[k+1],q[k+2],q[k+3]end
 return q[i][1],q[i][2],q[i][3]
end
function M.shape(template,rects,w,h)
 local old=models[template]
 if old and old.rects==rects and old.w==w and old.h==h then return old end
 local out={rects=rects,w=w,h=h,panes={},lo={1e9,1e9,1e9},hi={-1e9,-1e9,-1e9}}
 for _,q in ipairs(template)do for i=1,4 do
  local x,y,z=point(q,i)
  for a,p in ipairs({x,y,z})do out.lo[a]=math.min(out.lo[a],p);out.hi[a]=math.max(out.hi[a],p)end
 end end
 local bins={}
 for _,q in ipairs(template)do
  local glass=false
  local u,v=0,0
  for i=1,4 do
   if type(q[1])=='number'then u=u+q[11+i*2]/4;v=v+q[12+i*2]/4
   elseif q.uv then u=u+q.uv[i][1]/4;v=v+q.uv[i][2]/4
   else u=q.u or 0;v=q.v or 0;break end
  end
  u,v=u*w,v*h
  local u0,v0,u1,v1=u,v,u,v
  if V.lightingGeneration==2 and q.uv then
   for _,uv in ipairs(q.uv)do
    u0=math.min(u0,uv[1]*w);u1=math.max(u1,uv[1]*w)
    v0=math.min(v0,uv[2]*h);v1=math.max(v1,uv[2]*h)
   end
  end
  for _,r in ipairs(rects)do
   if (u>=r.x and u<r.x+r.w and v>=r.y and v<r.y+r.h)
      or (V.lightingGeneration==2 and u1>r.x and u0<r.x+r.w and v1>r.y and v0<r.y+r.h) then glass=true;break end
  end
  if glass then
   local x1,y1,z1=point(q,1);local x2,y2,z2=point(q,2);local x3,y3,z3=point(q,3)
   local nx=(y2-y1)*(z3-z1)-(z2-z1)*(y3-y1)
   local ny=(z2-z1)*(x3-x1)-(x2-x1)*(z3-z1)
   local nz=(x2-x1)*(y3-y1)-(y2-y1)*(x3-x1)
   local len=math.sqrt(nx*nx+ny*ny+nz*nz)
   -- A flat roof/decal may reuse window texels; it is not a window lamp.
   if len>0 and math.abs(ny)<len*.1 then
    local x,y,z=0,0,0;for i=1,4 do local a,b,c=point(q,i);x=x+a/4;y=y+b/4;z=z+c/4 end
    nx,nz=nx/len,nz/len
    if nx*(x-(out.lo[1]+out.hi[1])/2)+nz*(z-(out.lo[3]+out.hi[3])/2)<0 then nx,nz=-nx,-nz end
    local key=math.floor(x/12)..':'..math.floor(y/12)..':'..math.floor(z/12)..':'..math.floor(nx+.5)..':'..math.floor(nz+.5)
    local p=bins[key]
    if not p then p={x=0,y=0,z=0,n=0,normal={nx,0,nz}};bins[key]=p;out.panes[#out.panes+1]=p end
    p.x,p.y,p.z,p.n=p.x+x,p.y+y,p.z+z,p.n+1
   end
  end
 end
 for _,p in ipairs(out.panes)do p.x=p.x/p.n+p.normal[1]*.75;p.y=p.y/p.n;p.z=p.z/p.n+p.normal[3]*.75 end
 models[template]=out;return out
end
local function base(st,field)
 local function at(tx,ty)return field.atTile and field:atTile(tx,ty)or field:at(math.floor(tx/2),math.floor(ty/2))end
 local answer
 for i=1,#(st.doorGroundSamples or{}),2 do
  local y=at(st.doorGroundSamples[i],st.doorGroundSamples[i+1])
  if answer~=nil and y~=answer then answer=nil;break end
  answer=y
 end
 return answer or at(math.floor((st.mx+.001)/8),math.floor((st.mz+.001)/8))
end
function M.append(state,sources,blockers,glow,focus)
 local function mapSources(map,ox,oz)
  if not(map and map.tileset)then return end
  local structures=V.require('Structures')
  local S=V.lightingGeneration==2 and structures.lightingForMap(map) or nil
  if V.lightingGeneration~=2 then S=structures.forMap(map) end
  if not S then return end
  local rects=V.require('GlassMask').rects(map.tileset)
  if #rects==0 then return end
  local field=V.lightingGeneration~=2 and V.require('LedgeElevation').map(map)
  local w,h=map.tileset.imageWidth or 128,map.tileset.imageHeight or 128
  for _,st in ipairs(S.buildingStamps or S.lightBuildingStamps or{})do
   local template=st.quads
   if st.lightShape or (template and #template>0) then
    local shape=st.lightShape or M.shape(template,rects,w,h)
    local x,y,z=st.mx+ox,field and base(st,field) or (st.my or 0),st.mz+oz
    local owner={lo={shape.lo[1]+x,shape.lo[2]+y,shape.lo[3]+z},hi={shape.hi[1]+x,shape.hi[2]+y,shape.hi[3]+z}}
    blockers[#blockers+1]=owner
    for _,p in ipairs(shape.panes)do
     local px,py,pz=p.x+x,p.y+y,p.z+z
     if (px-focus[1])^2+(py-focus[2])^2+(pz-focus[3])^2<384^2 then
      sources[#sources+1]={x=px,y=py,z=pz,normal=p.normal,radius=56,power=.9*glow,
        color={1,.67,.30},owner=owner,kind='window'}
     end
    end
   end
  end
 end
 mapSources(state.map,0,0)
 for _,nb in ipairs(state.neighbors or{})do mapSources(nb.map,nb.ox or 0,nb.oy or 0)end
end
function M.invalidate()models=setmetatable({},{__mode='k'})end
return M
