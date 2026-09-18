-- Blickfrei: camera-to-actor visibility shared by world and MAP battles.
-- Only disposable drawing copies change. Native tiles, collision, warps and
-- actor state are never modified. Clear sight restores the original mesh.
local V=...
local C={}
local cache=setmetatable({},{__mode='k'})
local localBounds=setmetatable({},{__mode='k'})
local staticBounds=setmetatable({},{__mode='k'})
local instanceGeometry=setmetatable({},{__mode='k'})
function C.intersects(box,a,b,pad)
 local lo,hi=0,1;pad=pad or 0
 for axis=1,3 do
  local delta=b[axis]-a[axis]
  local min,max=box[axis]-pad,box[axis+3]+pad
  if math.abs(delta)<.00001 then
   if a[axis]<min or a[axis]>max then return false end
  else
   local t0,t1=(min-a[axis])/delta,(max-a[axis])/delta
   if t0>t1 then t0,t1=t1,t0 end
   lo,hi=math.max(lo,t0),math.min(hi,t1)
   if lo>hi then return false end
  end
 end
 return hi>0 and lo<1
end
function C.blocks(box,targets,eye)
 for _,target in ipairs(targets or {})do
  if C.intersects(box,eye,target,0) then return true end
 end
 return false
end
function C.cardTargets(cards)
 local targets={actors={}}
 for _,card in ipairs(cards or {})do
  local p,m=card.shadowFoot,card.model
  if p and m then
   local first=#targets+1
   for _,fraction in ipairs({.1,.5,.9})do
    for _,side in ipairs({-.4,0,.4})do
     targets[#targets+1]={p[1]+m[1]*side,p[2]+math.abs(m[6])*fraction,p[3]+m[9]*side}
    end
   end
   targets.actors[#targets.actors+1]={first=first,last=#targets,body={p[1],p[2]+math.abs(m[6])*.5,p[3]}}
  end
 end
 return targets
end
function C.removeQuad(quad,boxes)
 local x,y,z=0,0,0
 for _,p in ipairs(quad)do x=x+p[1];y=y+p[2];z=z+p[3]end
 x,y,z=x/4,y/4,z/4
 for _,b in ipairs(boxes)do
  if y>b[2]+.05 and y<=b[5]+.5 and x>=b[1]-.1 and x<=b[4]+.1 and z>=b[3]-.1 and z<=b[6]+.1 then return true end
 end
 return false
end
-- Split a polygon against a half-space, interpolating UVs at the cut.
local function split(poly,axis,edge,sign)
 local inside,outside={},{}
 local prev=poly[#poly];local pd=(prev[axis]-edge)*sign
 for _,p in ipairs(poly)do
  local d=(p[axis]-edge)*sign
  if (d<0)~=(pd<0) then
   local t=pd/(pd-d);local q={}
   for j=1,#p do q[j]=prev[j]+(p[j]-prev[j])*t end
   inside[#inside+1]=q;outside[#outside+1]=q
  end
  local dst=d>=0 and inside or outside;dst[#dst+1]=p
  prev,pd=p,d
 end
 return inside,outside
end
function C.cutQuad(quad,boxes)
 local pieces={quad}
 for _,b in ipairs(boxes)do
  local nextPieces={}
  for _,poly in ipairs(pieces)do
   local min,max={math.huge,math.huge,math.huge},{-math.huge,-math.huge,-math.huge}
   for _,p in ipairs(poly)do for j=1,3 do min[j]=math.min(min[j],p[j]);max[j]=math.max(max[j],p[j])end end
   if max[1]<b[1]-.01 or min[1]>b[4]+.01 or max[3]<b[3]-.01 or min[3]>b[6]+.01 or max[2]<=b[2]+.05 or min[2]>b[5]+.01 then
    nextPieces[#nextPieces+1]=poly
   else
    local rest=poly
    for _,plane in ipairs({{1,b[1]-.01,1},{1,b[4]+.01,-1},{2,b[2]+.05,1},{2,b[5]+.01,-1},{3,b[3]-.01,1},{3,b[6]+.01,-1}})do
     if #rest<3 then break end
     local inside,outside=split(rest,plane[1],plane[2],plane[3])
     if #outside>=3 then nextPieces[#nextPieces+1]=outside end
     rest=inside
    end
   end
  end
  pieces=nextPieces
 end
 return pieces
end
local function floorTile(map,tx,ty)
 local shapes=V.require('TileShape').forMap(map)
 for radius=0,8 do
  for y=ty-radius,ty+radius do for x=tx-radius,tx+radius do
   if x>=0 and y>=0 and x<map.def.width*4 and y<map.def.height*4 then
    local tile=map:tileAt(x,y);local shape=shapes[tile]
    if shape and shape.flat and shape.class=='ground' then return tile end
   end
  end end
 end
 return V.require('VoxelFurniture').floorTile(map,tx,ty)
end
local function filteredMesh(source,boxes,map)
 if source.__voxelMeshBundle then
  return {__voxelMeshBundle=true,base=source.base and filteredMesh(source.base,boxes,map),instances=source.instances}
 end
 local count=source:getVertexCount();assert(count%4==0,'Blickfrei terrain must retain quad layout')
 local vertices,indices={},{}
 local function push(q)
  local n=#vertices/4
  for _,p in ipairs(q)do vertices[#vertices+1]=p end
  V.require('Voxel3D').pushQuad(indices,n)
 end
 for i=1,count,4 do
  local q={}
  for n=0,3 do q[#q+1]={source:getVertex(i+n)}end
  for _,poly in ipairs(C.cutQuad(q,boxes))do
   if #poly==4 then push(poly)
   else for n=2,#poly-1 do push({poly[1],poly[n],poly[n+1],poly[n+1]})end end
  end
 end
 -- A removed pedestal must reveal matching floor, never a hole into the sky.
 local filled={};local aw,ah=map.tileset.imageWidth or 128,map.tileset.imageHeight or 48
 local columns=map.tileset.tilesPerRow or 16
 local floors=V.require('Gen1InteriorFloors')
 local floorProfile=floors and floors.profile and floors.profile(map)
 local caves=map.def and map.def.tileset=='CAVERN' and V.require('Gen1CaveSurfaces')
 local caveProfile=caves and caves.profile and caves.profile(map)
 for _,b in ipairs(boxes)do
  for ty=math.floor(b[3]/8),math.ceil(b[6]/8)-1 do
   for tx=math.floor(b[1]/8),math.ceil(b[4]/8)-1 do
    local key=ty*4096+tx
    if not filled[key] then
     filled[key]=true
     local tile=floorTile(map,tx,ty);local u,v=(tile%columns)*8/aw,math.floor(tile/columns)*8/ah
     local x,z,y=tx*8,ty*8,b[2]+.02
     local material=(caveProfile and caves.material(caveProfile,'ground',tile,'top',true)) or (floorProfile and floors.material(map,floorProfile,tile,true))
     local u0,u1=material or u,material or (u+8/aw)
     push({{x,y,z,u0,v,3},{x,y,z+8,u0,v+8/ah,3},{x+8,y,z+8,u1,v+8/ah,3},{x+8,y,z,u1,v,3}})
    end
   end
  end
 end
 return assert(V.require('Voxel3D').newMesh(vertices,indices),'Blickfrei mesh creation failed')
end
function C.propBounds(prop)
 local saved=prop.mat._voxelStatic and staticBounds[prop.mat]
 if saved and saved.mesh==prop.mesh then return saved.bounds end
 local mesh=prop.mesh;local b=localBounds[mesh]
 if not b then
  b={math.huge,math.huge,math.huge,-math.huge,-math.huge,-math.huge}
  for i=1,mesh:getVertexCount() do
   local x,y,z=mesh:getVertex(i)
   b[1],b[2],b[3]=math.min(b[1],x),math.min(b[2],y),math.min(b[3],z)
   b[4],b[5],b[6]=math.max(b[4],x),math.max(b[5],y),math.max(b[6],z)
  end
  localBounds[mesh]=b
 end
 local m=prop.mat;local out={math.huge,math.huge,math.huge,-math.huge,-math.huge,-math.huge}
 for _,x in ipairs({b[1],b[4]})do for _,y in ipairs({b[2],b[5]})do for _,z in ipairs({b[3],b[6]})do
  local p={m[1]*x+m[2]*y+m[3]*z+m[4],m[5]*x+m[6]*y+m[7]*z+m[8],m[9]*x+m[10]*y+m[11]*z+m[12]}
  for a=1,3 do out[a]=math.min(out[a],p[a]);out[a+3]=math.max(out[a+3],p[a])end
 end end end
 if m._voxelStatic then staticBounds[m]={mesh=mesh,bounds=out}end
 return out
end
-- Instanced scenery (trees/buildings) keeps its original placement stream.
-- A changed view owns a cloned template/stream; reattaching the original
-- template would also alter the cached map and its other drawing passes.
-- Only completed ChunkMesher streams opt in. Dynamic/foreign streams keep
-- reading their live offsets. Weak group keys follow terrain cache lifetime;
-- these entries own CPU numbers only, never GPU resources.
local function geometry(group)
 local saved=group.static and instanceGeometry[group]
 if saved and saved.mesh==group.mesh and saved.source==group.source and saved.count==group.count then return saved end
 local out={mesh=group.mesh,source=group.source,count=group.count,offsets={},boxes={}}
 local zero={1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}
 local b=C.propBounds({mesh=group.mesh,mat=zero})
 for i=1,group.count do
  local x,y,z=group.source:getVertex(i)
  out.offsets[i]={x,y,z}
  out.boxes[i]={b[1]+x,b[2]+y,b[3]+z,b[4]+x,b[5]+y,b[6]+z}
 end
 if group.static then instanceGeometry[group]=out end
 return out
end
function C.instancePlan(bundle,selected)
 local plans,hidden={},{}
 for gi,group in ipairs(bundle.instances or {})do
  local offsets=geometry(group).offsets
  local visible={}
  for i=1,group.count do
   local id='instance:'..gi..'.'..i
   if selected[id]then hidden[#hidden+1]=id
   else visible[#visible+1]=offsets[i]end
  end
  plans[gi]=visible
 end
 return plans,table.concat(hidden,','),#hidden
end
local function instanceBoxes(bundle,boxes)
 for gi,group in ipairs(bundle.instances or {})do
  local bounds=geometry(group).boxes
  for i=1,group.count do
   boxes['instance:'..gi..'.'..i]=bounds[i]
  end
 end
end
-- Partial cover is normal scenery. Clear it ONLY when every silhouette
-- sample of one actor is hidden (possibly by several different objects),
-- or when the actor's body centre really penetrates an internal wall.
-- There is deliberately no padded "near an object" collision test.
function C.select(boxes,targets,eye)
 local selected={}
 local actors=targets.actors or {{first=1,last=#targets,body=targets[math.ceil(#targets/2)]}}
 for _,actor in ipairs(actors)do
  -- Every visibility segment lies inside the eye/actor envelope. Reject
  -- distant objects once before the nine exact ray tests; do not weaken the
  -- requirement that an actor be completely hidden before clearing props.
  local lo={eye[1],eye[2],eye[3]};local hi={eye[1],eye[2],eye[3]}
  local function include(p)if p then for a=1,3 do lo[a]=math.min(lo[a],p[a]);hi[a]=math.max(hi[a],p[a])end end end
  for i=actor.first,actor.last do include(targets[i])end;include(actor.body)
  local nearby={}
  for id,b in pairs(boxes)do
   if b[1]<=hi[1]and b[4]>=lo[1]and b[2]<=hi[2]and b[5]>=lo[2]and b[3]<=hi[3]and b[6]>=lo[3]then nearby[id]=b end
  end
  local hits={};local fullyHidden=true
  for i=actor.first,actor.last do
   local covered=false
   for id,box in pairs(nearby)do
    if C.intersects(box,eye,targets[i],0)then covered=true;hits[id]=true end
   end
   if not covered then fullyHidden=false end
  end
  if fullyHidden then for id in pairs(hits)do selected[id]=true end end
  local body=actor.body
  for id,b in pairs(nearby)do
   if id:sub(1,5)=='wall:' and body
     and body[1]>b[1]+.05 and body[1]<b[4]-.05
     and body[2]>b[2]+.05 and body[2]<b[5]-.05
     and body[3]>b[3]+.05 and body[3]<b[6]-.05 then selected[id]=true end
  end
 end
 return selected
end
local function instanceMesh(group,offsets)
 local vertices,indices={},{}
 local count=group.mesh:getVertexCount()
 assert(count%4==0,'Blickfrei instance template must retain quad layout')
 for i=1,count do vertices[i]={group.mesh:getVertex(i)}end
 for i=0,count/4-1 do V.require('Voxel3D').pushQuad(indices,i)end
 local mesh=assert(V.require('Voxel3D').newMesh(vertices,indices))
 local source=love.graphics.newMesh({{'InstanceOffset','float',3}},offsets,'points','static')
 mesh:attachAttribute('InstanceOffset',source,'perinstance')
 return {mesh=mesh,source=source,count=#offsets}
end
local function drawingCopy(terrain,boxes,map,plans)
 if not terrain.__voxelMeshBundle then return #boxes>0 and filteredMesh(terrain,boxes,map) or nil end
 local out={__voxelMeshBundle=true,base=terrain.base,instances={},sightOwned={}}
 if #boxes>0 and terrain.base then
  out.base=filteredMesh(terrain.base,boxes,map);out.sightOwned[#out.sightOwned+1]=out.base
 end
 for i,group in ipairs(terrain.instances or {})do
  local offsets=plans and plans[i]
  if not offsets or #offsets==group.count then out.instances[#out.instances+1]=group
  elseif #offsets>0 then
   local copy=instanceMesh(group,offsets);out.instances[#out.instances+1]=copy
   out.sightOwned[#out.sightOwned+1]=copy.mesh;out.sightOwned[#out.sightOwned+1]=copy.source
  end
 end
 return out
end
local function release(mesh)
 if mesh and mesh.sightOwned then for _,owned in ipairs(mesh.sightOwned)do release(owned)end
 elseif mesh and mesh.__voxelMeshBundle then release(mesh.base)
 elseif mesh and mesh.release then mesh:release()end
end
local function key(x,y)return(y+64)*4096+x+64 end
local function candidates(map,structures,eye,targets)
 local boxes={}
 local elevation=V.require('ChunkMesher').elevation(map)
 local function datum(tx,ty)
  return elevation and elevation:at(math.floor(tx/2),math.floor(ty/2)) or 0
 end
 for i,b in ipairs(structures.battleObjects or {})do
  if b[4]-b[1]<=64 and b[6]-b[3]<=64 then
   local base=datum(math.floor(b[1]/8),math.floor(b[3]/8))
   boxes['object:'..i]={math.floor((b[1]-1)/8)*8,base,math.floor((b[3]-1)/8)*8,
    math.ceil((b[4]+1)/8)*8,b[5]+base+1,math.ceil((b[6]+1)/8)*8}
  end
 end
 -- Visit only tiles touched by the ray fan, never enumerate a whole cave.
 -- Perimeter art remains owned by the existing room/cave cutaway renderer.
 local visited,rayEnds={},{};local w,h=map.def.width*4,map.def.height*4
 for _,target in ipairs(targets)do
  -- Body samples at different heights share the exact same horizontal ray.
  -- Enumerate its tile corridor once; C.select still tests every 3D sample.
  local column=rayEnds[target[1]]
  if not column then column={};rayEnds[target[1]]=column end
  if not column[target[3]] then
  column[target[3]]=true
  local dx,dz=target[1]-eye[1],target[3]-eye[3]
  local steps=math.max(1,math.ceil(math.max(math.abs(dx),math.abs(dz))/4))
  for step=0,steps do
   local tx,ty=math.floor((eye[1]+dx*step/steps)/8),math.floor((eye[3]+dz*step/steps)/8)
   for yy=ty-1,ty+1 do for xx=tx-1,tx+1 do
    local k=key(xx,yy)
    if not visited[k] and xx>0 and yy>0 and xx<w-1 and yy<h-1 then
     visited[k]=true
     local shape=structures.shapeAt[k]
     if shape and (shape.class=='wall' or shape.class=='cliff') and (shape.h or 0)>0
       and not (structures.interiorWallClaims and structures.interiorWallClaims[k]) then
      local base=datum(xx,yy)
      boxes['wall:'..k]={xx*8,base,yy*8,xx*8+8,base+shape.h,yy*8+8}
     end
    end
   end end
  end
  end
 end
 return boxes
end
local propLists={'furniture','items'}
-- Mutable private comparison storage, never part of a published draw receipt.
-- Identity/value comparisons avoid rebuilding a long text key for every tree
-- every frame. List boundaries and actor grouping are explicit: moving a prop
-- between furniture/items or regrouping the same rays must reclassify it.
local function classificationChanged(entry,structures,props,map,targets,eye,terrain)
 local values=entry.probeValues
 if not values then values={};entry.probeValues=values end
 local n,changed=0,not entry.probeValid
 local function check(value)
  n=n+1;value=value or false
  if values[n]~=value then values[n]=value;changed=true;return true end
  return false
 end
 check(map);check(structures)
 local groups=terrain.__voxelMeshBundle and terrain.instances or {}
 local geometryChanged=check(#groups)
 for _,group in ipairs(groups)do
  geometryChanged=check(group)or geometryChanged
  geometryChanged=check(group.mesh)or geometryChanged
  geometryChanged=check(group.source)or geometryChanged
  geometryChanged=check(group.count)or geometryChanged
  geometryChanged=check(group.static==true)or geometryChanged
  -- Unmarked providers may update their offset buffer without replacing it.
  if not group.static then changed=true;geometryChanged=true end
 end
 if geometryChanged then entry.instanceRevision=(entry.instanceRevision or 0)+1 end
 for a=1,3 do check(math.floor(eye[a]*4))end
 check(#targets)
 for _,point in ipairs(targets)do for a=1,3 do check(math.floor(point[a]*4))end end
 local actors=targets.actors
 check(actors and #actors or false)
 for _,actor in ipairs(actors or {})do
  check(actor.first);check(actor.last);check(actor.body~=nil)
  if actor.body then for a=1,3 do check(actor.body[a])end end
 end
 for _,list in ipairs(propLists)do
  local items=props and props[list]
  check(items and #items or 0)
  for _,prop in ipairs(items or {})do
   check(prop.mesh);check(prop.mat._voxelStatic==true)
   if prop.mat._voxelStatic then check(prop.mat)
   else for a=1,12 do check(prop.mat[a])end end
  end
 end
 for i=#values,n+1,-1 do values[i]=nil;changed=true end
 if changed then entry.probeValid=false end
 return changed
end
-- Public seam also lets native QA compare before/after without touching saves.
function C.status(owner)return cache[owner] and cache[owner].receipt end
function C.clear(owner)
 local entry=cache[owner]
 if entry then release(entry.mesh);cache[owner]=nil end
end
function C.scene(owner,terrain,props,map,targets,eye)
 if not(owner and terrain and map and eye and targets and #targets>0)then return terrain,props end
 local entry=cache[owner]
 if not entry or entry.source~=terrain then
  C.clear(owner);entry={source=terrain,held={},signature=''};cache[owner]=entry
 end
 local now=love and love.timer and love.timer.getTime() or 0
 local structures=V.require('Structures').forMap(map)
 -- Reuse classification while camera, bodies and prop transforms are stable.
 if classificationChanged(entry,structures,props,map,targets,eye,terrain)then
  local found=candidates(map,structures,eye,targets)
  for _,list in ipairs(propLists)do
   for index,prop in ipairs(props and props[list] or {})do found[list..':'..index]=C.propBounds(prop)end
  end
  if terrain.__voxelMeshBundle then instanceBoxes(terrain,found)end
  entry.selected=C.select(found,targets,eye)
  entry.visible={}
  for id in pairs(entry.selected)do
   if id:sub(1,7)=='object:' or id:sub(1,5)=='wall:' then entry.visible[id]=found[id]end
  end
  if terrain.__voxelMeshBundle then
   entry.instancePlan,entry.instanceKey,entry.hiddenInstances=C.instancePlan(terrain,entry.selected)
  end
  entry.probeValid=true
 end
 for id,box in pairs(entry.visible)do entry.held[id]={box=box,untilTime=now+.18}end
 local ids={}
 for id,held in pairs(entry.held)do
  if now>held.untilTime then entry.held[id]=nil else ids[#ids+1]=id end
 end
 table.sort(ids)
 local signature=table.concat(ids,',')..(entry.instanceKey and entry.instanceKey~='' and ';instances:'..entry.instanceKey..'@'..entry.instanceRevision or '');local boxes={}
 for _,id in ipairs(ids)do boxes[#boxes+1]=entry.held[id].box end
 if signature~=entry.signature then
  local old=entry.mesh
  local started=love and love.timer and love.timer.getTime() or 0
  entry.mesh=(#boxes>0 or (entry.hiddenInstances or 0)>0) and drawingCopy(terrain,boxes,map,entry.instancePlan) or nil
  entry.buildSeconds=(love and love.timer and love.timer.getTime() or started)-started
  entry.builds=(entry.builds or 0)+1
  entry.signature=signature;release(old)
 end
 local filtered={map=props and props.map,furniture={},items={},signature={}}
 local hidden={}
 for _,list in ipairs(propLists)do
  for index,prop in ipairs(props and props[list] or {})do
   if not entry.selected[list..':'..index]then filtered[list][#filtered[list]+1]=prop
   else hidden[#hidden+1]=list..index end
  end
 end
 for _,part in ipairs(props and props.signature or {})do filtered.signature[#filtered.signature+1]=part end
 filtered.signature[#filtered.signature+1]='blickfrei:'..signature..':'..table.concat(hidden,',')
 entry.receipt={objects=#boxes,instances=entry.hiddenInstances or 0,furniture=#(props and props.furniture or {})-#filtered.furniture,
  items=#(props and props.items or {})-#filtered.items,signature=signature,source=terrain,mesh=entry.mesh or terrain,builds=entry.builds or 0,buildSeconds=entry.buildSeconds or 0}
 return entry.mesh or terrain,filtered
end
return C
