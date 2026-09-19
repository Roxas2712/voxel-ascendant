-- Render-only glazing and distant matte paintings. The native terrace,
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
 else img=love.graphics.newImage(V.path..'/assets/scenery/celadon-rooftop-'..name..'.png')end
 img:setFilter('linear','linear');img:setWrap('clamp','clamp');textures[name]=img;return img
end
function M.geometry(entry)
 local out={}
 local function group(name)
  local g={name=name,vertices={},indices={}};out[#out+1]=g;return g
 end
 local function quad(g,p,uv,shade)
  local n=#g.vertices
  for i,v in ipairs(p)do g.vertices[#g.vertices+1]={v[1],v[2],v[3],uv[i][1],uv[i][2],shade or 1}end
  for _,i in ipairs({1,2,3,1,3,4})do g.indices[#g.indices+1]=n+i end
 end
 local w,h=entry.w,entry.h;local cx,cz=w/2,h/2
 local radius=math.max(w,h)*.7+128
 -- Two 180-degree paintings meet behind the rooftop. The eastern painting
 -- contains the distant Saffron skyline; the west opens over Celadon's gardens.
 for half,name in ipairs({'east','west'})do
  local g=group(name)
  for segment=0,15 do
   local a=-math.pi/2+(half-1)*math.pi+segment*math.pi/16
   local b=a+math.pi/16
   local x,z=cx+math.cos(a)*radius,cz+math.sin(a)*radius
   local xx,zz=cx+math.cos(b)*radius,cz+math.sin(b)*radius
   quad(g,{{x,-180,z},{xx,-180,zz},{xx,140,zz},{x,140,z}},
    {{segment/16,1},{(segment+1)/16,1},{(segment+1)/16,0},{segment/16,0}})
   -- Extend the nearest painted rooftops below the view to close downward
   -- orbit angles, instead of a same-height lawn surrounding a high terrace.
   quad(g,{{cx,-180,cz},{xx,-180,zz},{x,-180,z},{cx,-180,cz}},
    {{(segment+.5)/16,1},{(segment+1)/16,1},{segment/16,1},{(segment+.5)/16,1}})
  end
 end
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
 for _,edge in ipairs({'north','east','south','west'})do
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
 return out
end
function M.build(entry)
 local out={}
 for _,g in ipairs(M.geometry(entry))do
  local mesh=assert(V.require('Voxel3D').newMesh(g.vertices,g.indices),'rooftop panorama mesh')
  out[#out+1]={mesh=mesh,texture=texture(g.name),ox=entry.ox or 0,oy=entry.oy or 0,
   kind='wall',class='rooftop_panorama',castsShadow=false}
 end
 return out
end
return M
