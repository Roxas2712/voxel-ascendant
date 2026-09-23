-- Render-only glazing and a continuous, skyless city below the terrace.
-- The game owns the sky, weather and time of day. The native terrace,
-- stairs, vending interactions and roof-house door remain untouched.
local V=...
local M={}
local textures={}
local registered
local function texture(name)
 if not registered then
  require('src.render.Assets').register(function()
   for _,t in pairs(textures)do t:release()end;textures={}
  end);registered=true
 end
 if textures[name]then return textures[name]end
 local img
 if name=='frame'then
  local data=love.image.newImageData(4,1)
  for i,c in ipairs({{.27,.37,.42},{.65,.76,.79},{.79,.91,.95},{.45,.52,.55}})do data:setPixel(i-1,0,c[1],c[2],c[3],1)end
  img=love.graphics.newImage(data);data:release()
 else error('unknown rooftop material: '..tostring(name))end
 img:setFilter('linear','linear');img:setWrap('clamp','clamp');textures[name]=img;return img
end
function M.geometry(entry,emitWorld,yieldStep)
 local out={}
 local function group(name)
  local g={name=name,vertices={},indices={}};out[#out+1]=g;return g
 end
 local function quad(g,p,uv,shade)
  local n=#g.vertices
  for i,v in ipairs(p)do g.vertices[#g.vertices+1]={v[1],v[2],v[3],uv[i][1],uv[i][2],shade or 1}end
  for _,i in ipairs({1,2,3,1,3,4})do g.indices[#g.indices+1]=n+i end
 end
 local w,h=entry.w,entry.h
 local g=group('frame')
 local function box(x,y,z,bw,bh,bd,color)
  local u=(color-.5)/4;local uv={{u,.5},{u,.5},{u,.5},{u,.5}}
  for face,corners in ipairs(V.require('Voxel3D').FACE_CORNERS)do
   local p={};for _,v in ipairs(corners)do p[#p+1]={x+v[1]*bw,y+v[2]*bh,z+v[3]*bd}end
   quad(g,p,uv,({.82,.82,1,.65,.85,.85})[face])
  end
 end
 -- The mart's source map has 32px nonwalkable padding on either side.
 local inset=entry.map.id=='CELADON_MART_ROOF'and 32 or 0
 local x0,x1,z0,z1=inset,w-inset,0,h
 local terrace=V.require('VoxelItems').setting:get() and V.require('Gen1RoofTerrace').matches(entry.map)
 for _,edge in ipairs(terrace and {} or {'north','east','south','west'})do
  local horizontal=edge=='north'or edge=='south'
  local start,finish=horizontal and x0 or z0,horizontal and x1 or z1
  local at=edge=='north'and z0 or edge=='south'and z1 or edge=='west'and x0 or x1
  local function bar(along,y,length,height,color)
   if horizontal then box(along,y,at-1,length,height,2,color)
   else box(at-1,y,along,2,height,length,color)end
  end
  bar(start,40,finish-start,1.2,2)
  local bays=math.max(1,math.ceil((finish-start)/80));local span=(finish-start)/bays
  for i=0,bays do bar(start+i*span-.6,8,1.2,33,1)end
  -- Sparse glints imply clear glass without an opaque blue front sheet.
  for i=0,bays-1 do
   local a=start+i*span+8
   for j=0,5 do bar(a+j,28+j,1.5,1,3)end
  end
 end
 -- Exposed facade below the native roof edge establishes the building height.
 box(x0,-100,z0,x1-x0,100,1,4);box(x0,-100,z1-1,x1-x0,100,1,4)
 box(x0,-100,z0,1,100,z1-z0,4);box(x1-1,-100,z0,1,100,z1-z0,4)
 -- Layered cornice closes the top of the exposed facade while keeping
 -- railings, stair approaches and the view over the city open.
 for _,level in ipairs({{-5,3,2},{-2,2,3}})do
  local y,height,color=unpack(level)
  box(x0-1,y,z0-1,x1-x0+2,height,2,color)
  box(x0-1,y,z1-1,x1-x0+2,height,2,color)
  box(x0-1,y,z0+1,2,height,z1-z0-2,color)
  box(x1-1,y,z0+1,2,height,z1-z0-2,color)
 end
 if emitWorld then emitWorld(out,group,quad,yieldStep)end
 return out
end
function M.build(entry,yieldStep,worldMaps)
 local out={}
 local near,baked=V.require('RooftopCache').load(entry,worldMaps,yieldStep)
 for _,g in ipairs(M.geometry(entry,function(out,group,quad)
  local batches={}
  local function emit(x,y,z,w,h,d,c,lit,foliage)
   local key=lit and 'windows'or foliage and 'foliage'or 'world';local g=batches[key]
   if not g or (g.boxes or 0)>=128 then g=group(key);g.boxes=0;g.lit=lit;g.foliage=foliage==true;batches[key]=g end
   g.boxes=g.boxes+1
   local u=(c-.5)/#V.require('VoxelItems').palette;local uv={{u,.5},{u,.5},{u,.5},{u,.5}}
   for face,corners in ipairs(V.require('Voxel3D').FACE_CORNERS)do
    local p={};for _,v in ipairs(corners)do p[#p+1]={x+v[1]*w,y+v[2]*h,z+v[3]*d}end
    quad(g,p,uv,({.82,.82,1,.65,.85,.85})[face]+((face==3 and not lit and c~=8)and 2 or 0))
   end
  end
  if near then for _,b in ipairs(near)do emit(unpack(b))end
  else V.require('RooftopWorld').geometry(entry,worldMaps,emit,yieldStep)end
  V.require('RooftopWorld').mountains(entry,worldMaps,emit,yieldStep)
 end,yieldStep))do
  local mesh=V.require('Voxel3D').newMesh(g.vertices,g.indices)
  if not mesh then
   for _,p in ipairs(out)do p.mesh:release()end
   for _,p in ipairs(baked or{})do p.mesh:release();p.texture:release();if p.materialMask then p.materialMask:release()end end
   error('rooftop panorama mesh',0)
  end
  local city=g.name~='frame'
  out[#out+1]={mesh=mesh,texture=city and V.require('RooftopWorld').texture()or texture(g.name),ox=entry.ox or 0,oy=entry.oy or 0,
   kind='wall',class=city and 'voxel_horizon'or 'rooftop_panorama',windowLight=g.lit==true,seasonalFoliage=g.foliage==true,castsShadow=false}
  if yieldStep then yieldStep()end
 end
 for _,p in ipairs(baked or{})do out[#out+1]=p end
 return out
end
return M
