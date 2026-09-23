-- Keep one mesh/draw call while allowing large authored props to upload
-- between build slices. Vertex rows and triangle order remain unchanged.
local V=...
local Budget=V.require('BuildBudget')
local M={VERTEX_PAGE=1024,INDEX_PAGE=1536}
local unpackValues=unpack or table.unpack
function M.available()
 local d=love and love.data
 return d and type(d.pack)=='function' and type(d.newByteData)=='function'
end
function M.create(format,vertices,indices)
 local mesh,indexData
 local ok,result=pcall(function()
  Budget.check()
  mesh=assert(love.graphics.newMesh(format,#vertices,'triangles','static'))
  assert(type(mesh.setVertices)=='function','paged mesh upload unavailable')
  local page={}
  for first=1,#vertices,M.VERTEX_PAGE do
   Budget.check()
   local count=math.min(M.VERTEX_PAGE,#vertices-first+1)
   for i=1,count do page[i]=vertices[first+i-1] end
   for i=count+1,#page do page[i]=nil end
   mesh:setVertices(page,first,count)
   Budget.check()
  end
  page=nil
  if indices and #indices>0 then
   local pieces={}
   local indexPage={}
   for first=1,#indices,M.INDEX_PAGE do
    Budget.check()
    local last=math.min(#indices,first+M.INDEX_PAGE-1)
    local count=last-first+1
    -- Native Data index buffers are zero-based; Lua index arrays are one-based.
    for i=1,count do indexPage[i]=indices[first+i-1]-1 end
    pieces[#pieces+1]=love.data.pack('string','='..string.rep('I4',count),unpackValues(indexPage,1,count))
   end
   Budget.check()
   indexData=love.data.newByteData(table.concat(pieces))
   pieces=nil
   local mapped=pcall(mesh.setVertexMap,mesh,indexData,'uint32')
   indexData:release();indexData=nil
   if not mapped then
    -- Retain the original table API on drivers which reject Data index maps.
    Budget.check();mesh:setVertexMap(indices)
   end
  end
  Budget.check()
  return mesh
 end)
 if not ok then
  if indexData then pcall(indexData.release,indexData)end
  if mesh and mesh.release then pcall(mesh.release,mesh)end
  return nil,result
 end
 return result
end
return M
