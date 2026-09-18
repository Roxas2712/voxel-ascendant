-- Bounded geometry/actor cache. The caller queues preparation separately.
local Cache={}
function Cache.new(newMesh,templateLimit,meshLimit,limits)
 assert(type(newMesh)=='function' and type(templateLimit)=='number' and templateLimit>=1 and templateLimit%1==0)
 assert(type(meshLimit)=='number' and meshLimit>=1 and meshLimit%1==0)
 limits=limits or {}
 local vertexLimit=limits.templateVertices or 128000
 local bufferLimit=limits.bufferBytes or 8*1024*1024
 assert(vertexLimit>0 and vertexLimit<math.huge and bufferLimit>0 and bufferLimit<math.huge)
 local templates,entries={},{};local owners=setmetatable({},{__mode='k'})
 local serial=0;local metrics={templates=0,meshes=0,uploads=0,hits=0,evictions=0,meshEvictions=0,templateVertices=0,bufferBytes=0,rejected=0}
 local function tick()serial=serial+1;return serial end
 local function release(e)
  if e.mesh then e.mesh:release();metrics.meshes=metrics.meshes-1;metrics.bufferBytes=metrics.bufferBytes-e.bytes end
  if e.parent then e.parent[e.key]=nil end
  entries[e]=nil;e.mesh,e.template,e.key,e.parent=nil,nil,nil,nil
 end
 local function evict(key)
  local t=templates[key];if not t then return end
  for e in pairs(entries)do if e.template==t then release(e)end end
  templates[key]=nil;metrics.templates=metrics.templates-1;metrics.templateVertices=metrics.templateVertices-#t.shape.vertices;metrics.evictions=metrics.evictions+1
 end
 local function oldest(map)
  local key,age
  for k,v in pairs(map)do if not age or v.used<age then key,age=k,v.used end end
  return key
 end
 local api={metrics=metrics}
 function api:get(key)
  local t=templates[key]
  if t then t.used=tick();return t.shape end
 end
 function api:put(key,shape)
  if templates[key]then return templates[key].shape end
  assert(key and shape and #shape.vertices>0 and #shape.indices>0)
  local vertices=#shape.vertices
  -- Six float32 vertex components plus conservatively counted uint32 indices.
  -- This accounts for buffer payload, not driver allocations or Lua table overhead.
  local bytes=vertices*24+#shape.indices*4
  if vertices>vertexLimit or bytes>bufferLimit then metrics.rejected=metrics.rejected+1;return nil,'geometry exceeds cache budget' end
  while metrics.templates>=templateLimit or metrics.templateVertices+vertices>vertexLimit do evict(oldest(templates))end
  templates[key]={shape=shape,used=tick(),bytes=bytes};metrics.templates=metrics.templates+1;metrics.templateVertices=metrics.templateVertices+vertices
  return shape
 end
 function api:draw(key,owner,pose,deform)
  local t=templates[key];if not t then return nil end
  assert(owner and pose~=nil and type(deform)=='function')
  t.used=tick();local state=owners[owner]
  if not state then state={};owners[owner]=state end
  local e=state[key]
  if not e then
   while metrics.meshes>=meshLimit or metrics.bufferBytes+t.bytes>bufferLimit do release(oldest(entries));metrics.meshEvictions=metrics.meshEvictions+1 end
   local vertices={}
   for i,v in ipairs(t.shape.vertices)do vertices[i]={unpack(v)}end
   local ok,mesh=pcall(newMesh,vertices,t.shape.indices)
   if not ok or not mesh then return nil,mesh or 'mesh allocation failed' end
   e={mesh=mesh,vertices=vertices,template=t,key=key,parent=state,used=tick(),bytes=t.bytes}
   entries[e]=e;state[key]=e;metrics.meshes=metrics.meshes+1;metrics.bufferBytes=metrics.bufferBytes+t.bytes
  end
  e.used=tick()
  if e.pose==pose then metrics.hits=metrics.hits+1;return e.mesh end
  local ok,err=pcall(function()
   for i,v in ipairs(t.shape.vertices)do
    local x,y=deform(v,i)
    assert(type(x)=='number' and type(y)=='number' and x==x and y==y and math.abs(x)<math.huge and math.abs(y)<math.huge,'invalid deformation')
    e.vertices[i][1],e.vertices[i][2]=x,y
   end
   e.mesh:setVertices(e.vertices)
  end)
  if not ok then e.pose=nil;return nil,err end
  e.pose=pose;metrics.uploads=metrics.uploads+1;return e.mesh
 end
 function api:clear()
  for e in pairs(entries)do release(e)end
  templates={};owners=setmetatable({},{__mode='k'});metrics.templates=0;metrics.templateVertices=0
 end
 return api
end
return Cache
