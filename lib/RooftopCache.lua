-- Packaged, skyless cube captures of the source-map world. Baking is an
-- offline QA/build step; a normal phone only decodes images and near boxes.
local V=...
local C={REVISION=1,RADIUS=2048,NEAR=480,FACE_SIZE=1536,hits=0,misses=0}
-- Right/up vectors also define texture orientation, shared by baker and draw.
C.faces={
 {name='east',dir={1,0,0},right={0,0,1},up={0,1,0}},
 {name='west',dir={-1,0,0},right={0,0,-1},up={0,1,0}},
 {name='south',dir={0,0,1},right={-1,0,0},up={0,1,0}},
 {name='north',dir={0,0,-1},right={1,0,0},up={0,1,0}},
 {name='up',dir={0,1,0},right={1,0,0},up={0,0,1}},
 {name='down',dir={0,-1,0},right={1,0,0},up={0,0,-1}},
}
function C.key(entry)
 return entry.map.id..'-'..V.require('Gen1LavenderTower').setting:get()
end
function C.signature(defs,ids,tilesets)
 local rows={'rooftop-world-v'..C.REVISION}
 for _,id in ipairs(ids)do
  local d=defs[id];if not d then return end
  rows[#rows+1]=table.concat({id,d.width,d.height,d.tileset,d.generation or 1},':')
  rows[#rows+1]=table.concat(d.blocks or{},',')
  for _,edge in ipairs({'north','south','east','west'})do local p=d.connections and d.connections[edge]
   rows[#rows+1]=p and edge..':'..p.map..':'..(p.offset or 0)or edge
  end
 end
 local sets={};for _,id in ipairs(ids)do sets[defs[id].tileset]=true end
 local names={};for n in pairs(sets)do names[#names+1]=n end;table.sort(names)
 for _,name in ipairs(names)do
  local t=tilesets[name];if not t then return end
  rows[#rows+1]=name
  for _,b in ipairs(t.blocks or{})do rows[#rows+1]=table.concat(b,',')end
 end
 return love.data.encode('string','hex',love.data.hash('sha256',table.concat(rows,';')))
end
function C.near(entry,b)
 local x,z=entry.w/2,entry.h/2
 return b[1]<x+C.NEAR and b[1]+b[4]>x-C.NEAR and b[3]<z+C.NEAR and b[3]+b[6]>z-C.NEAR
end
-- Split wide terrain at the near/far boundary. Merely classifying a large
-- ground slab as near would let it extend behind and cover the baked world.
function C.partition(entry,b,emit)
 local function cuts(start,length,center)
  local out={start};for _,edge in ipairs({center-C.NEAR,center+C.NEAR})do if edge>start and edge<start+length then out[#out+1]=edge end end
  out[#out+1]=start+length;return out
 end
 local xs,zs=cuts(b[1],b[4],entry.w/2),cuts(b[3],b[6],entry.h/2)
 for ix=1,#xs-1 do for iz=1,#zs-1 do
  local p={xs[ix],b[2],zs[iz],xs[ix+1]-xs[ix],b[5],zs[iz+1]-zs[iz],b[7],b[8]}
  emit(p,C.near(entry,p))
 end end
end
function C.pack(boxes)
 local parts={'RWB1',love.data.pack('string','<I4',#boxes)}
 for _,b in ipairs(boxes)do parts[#parts+1]=love.data.pack('string','<ffffffI4I4',b[1],b[2],b[3],b[4],b[5],b[6],b[7],b[8]and 1 or 0)end
 return table.concat(parts)
end
function C.unpack(raw)
 if type(raw)~='string'or raw:sub(1,4)~='RWB1'or #raw<8 then return end
 local count,pos=love.data.unpack('<I4',raw,5)
 if count>12000 or #raw~=8+count*32 then return end
 local out={}
 for i=1,count do
  local x,y,z,w,h,d,c,lit,nextPos=love.data.unpack('<ffffffI4I4',raw,pos);pos=nextPos
  for _,n in ipairs({x,y,z,w,h,d})do if n~=n or math.abs(n)>20000 then return end end
  if w<=0 or h<=0 or d<=0 or c<1 or c>#V.require('VoxelItems').palette or lit>1 then return end
  out[i]={x,y,z,w,h,d,c,lit==1}
 end
 return out
end
function C.faceGeometry(entry,face,radius,crop)
 local vv={};radius=radius or C.RADIUS
 for _,uv in ipairs({{0,0},{1,0},{1,1},{0,1}})do
  local u=crop and (crop.x+uv[1]*crop.w)/C.FACE_SIZE or uv[1]
  local v=crop and (crop.y+uv[2]*crop.h)/C.FACE_SIZE or uv[2]
  local a,b=u*2-1,1-v*2
  vv[#vv+1]={entry.w/2+radius*(face.dir[1]+a*face.right[1]+b*face.up[1]),
   40+radius*(face.dir[2]+a*face.right[2]+b*face.up[2]),
   entry.h/2+radius*(face.dir[3]+a*face.right[3]+b*face.up[3]),uv[1],uv[2],1}
 end
 return vv,{1,2,3,1,3,4}
end
function C.load(entry,defs,yieldStep)
 local ok,index=pcall(V.data,'rooftop_cache')
 local key=C.key(entry);local meta=ok and index and index[key]
 if not(meta and meta.revision==C.REVISION)then C.misses=C.misses+1;return end
 local game=require('src.core.Game');defs=defs or game.data.maps
 if C.signature(defs,meta.maps,game.data.tilesets)~=meta.signature then
  local alternative=index[key..'-rb']
  if not(alternative and alternative.revision==C.REVISION and C.signature(defs,alternative.maps,game.data.tilesets)==alternative.signature)then C.misses=C.misses+1;return end
  meta=alternative
 end
 local readOK,raw=pcall(V.mod.read,V.mod,meta.path..'/near.bin');local near=readOK and C.unpack(raw)
 if not near then C.misses=C.misses+1;return end
 local newTextures={};local parts={}
 local success,err=pcall(function()
  for _,face in ipairs(C.faces)do for _,layer in ipairs({'land','lights'})do
   local name=face.name..'-'..layer
   if meta.files[name]then
    local tex
    do
     tex=love.graphics.newImage(V.path..'/'..meta.path..'/'..name..'.png',{mipmaps=false,linear=false})
     tex:setFilter('linear','linear');tex:setWrap('clamp','clamp');newTextures[name]=tex
    end
    local v,i=C.faceGeometry(entry,face,layer=='lights'and C.RADIUS-.1 or C.RADIUS,meta.files[name])
    local mesh=assert(V.require('Voxel3D').newMesh(v,i),'rooftop cache mesh')
    parts[#parts+1]={mesh=mesh,texture=tex,ox=entry.ox or 0,oy=entry.oy or 0,
     kind='wall',class='rooftop_baked',windowLight=layer=='lights',ownsTexture=true,castsShadow=false}
    if yieldStep then yieldStep()end
   end
  end end
 end)
 if not success then
  for _,p in ipairs(parts)do p.mesh:release()end
  for _,t in pairs(newTextures)do t:release()end
  C.misses=C.misses+1;return nil,err
 end
 C.hits=C.hits+1;return near,parts
end
function C.draw(rim,matrix)
 local G=V.require('Voxel3D');local g=love.graphics;local shader=g.getShader()
 local light=V.require('Gen1PalletVillage').windowLight()
 if rim.windowLight and light<=0 then return end
 -- A baked direction field must not acquire the world's quadratic bend.
 -- All other palette, clock and weather presentation stays on the world path.
 if shader then pcall(shader.send,shader,'curve',{0,0,0})end
 if rim.windowLight then G.flatten({1,.86,.6},light)end
 G.draw(rim.mesh,rim.texture,matrix)
 if rim.windowLight then G.flatten(nil)end
 if shader then pcall(shader.send,shader,'curve',{G.curveX or 0,G.curveZ or 0,G.curveK or 0})end
end
return C
