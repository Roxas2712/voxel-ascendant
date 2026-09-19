-- Bounded source-world image residency. No source geometry is built at play
-- time. One image/upload per preparation step; expose a view only when whole.
local V=...
-- Native Crystal/Gold captures; mismatched worlds keep the semantic horizon.
local M={RELEASE_READY=true,MAX_BYTES=6*1024*1024,uploads=0,failures=0}
local G=V.require('Voxel3D');local Mat=V.require('Mat4')
local S=V.require('JohtoWorldSignature');local Assets=require('src.render.Assets')
local Palette=require('src.render.GbcPalette')
local faces={east={1,0,0,1},west={-1,0,0,-1},south={0,1,-1,0},north={0,-1,1,0}}
local order={'north','east','south','west'}
local parts,queue={},{};local key,meta,index,verdicts
local enabled=true;local done=false;local active=false;local bytes=0;local errorText
local function release(v)if v and v.release then pcall(v.release,v)end end
local function clear()
 for _,p in ipairs(parts)do release(p.mesh);release(p.texture)end
 parts={};queue={};meta=nil;bytes=0;done=false;active=false
end
local function hash(raw)return love.data.encode('string','hex',love.data.hash('sha256',raw))end
local function catalog(state)
 if not index then local ok,value=pcall(V.data,'johto_world_cache');index=ok and value or {}end
 verdicts=verdicts or {}
 local renderer=state.map.renderer;local data=renderer and renderer.data
 if not data then return nil end
 for name,entry in pairs(index)do
  if verdicts[name]==nil then
   local ok,digest=pcall(S.digest,state.worldMaps or data.maps,data.gen2Tilesets or data.tilesets,data.gen2Roofs or data.roofs,data.gen2Palettes,entry.maps,
    function(path)return hash(Assets.imageData(path):getString())end,hash)
   verdicts[name]=ok and digest==entry.signature
  end
  if verdicts[name]then return entry end
 end
end
local function select(state)
 local map=state and state.map
 local depth=math.max(1,math.min(4,math.floor(tonumber(state and state._stadiumOpenWorldDepth)or 1)))
 local wanted=M.RELEASE_READY and enabled and map and (map.def.environment=='TOWN' or map.def.environment=='ROUTE') and Palette.mode=='gbc' and (map.def.tileset=='TILESET_JOHTO' or map.def.tileset=='TILESET_JOHTO_MODERN')
 local nextKey=wanted and tostring(map)..':'..depth or 'none'
 if nextKey==key then return end
 clear();key=nextKey;errorText=nil
 if not wanted then done=true;return end
 local found=catalog(state);meta=found and found.views[map.id..':'..depth]
 if not meta then done=true;return end
 if meta.ground then
  queue[#queue+1]={face='ground',layer='land',crop={x=0,y=0,w=meta.ground.w,h=meta.ground.h},path=meta.ground.path}
 end
 for _,face in ipairs(order)do for _,layer in ipairs({'land','lights'})do
  local name=face..'-'..layer;local crop=meta.files[name]
  if crop then queue[#queue+1]={face=face,layer=layer,crop=crop,path=meta.path..'/'..name..'.png'}end
 end end
 if #queue==0 then meta=nil;done=true end
end
function M.prepare(state)
 select(state);if done then return true end
 local item=table.remove(queue,1);local pixels,texture,mesh
 local ok,err=pcall(function()
  local raw=assert(V.mod:read(item.path),'source-world image missing')
  pixels=love.image.newImageData(love.filesystem.newFileData(raw,item.path))
  local w,h=pixels:getDimensions();local c=item.crop;local size=item.face=='ground' and 1024 or meta.size or 1024
  assert(size>=64 and size<=1024,'source-world capture size')
  assert(w==c.w and h==c.h and w>0 and h>0 and c.x>=0 and c.y>=0
    and c.x+w<=size and c.y+h<=size,'source-world crop mismatch')
  assert(bytes+w*h*4<=M.MAX_BYTES,'source-world image budget')
  texture=love.graphics.newImage(pixels);release(pixels);pixels=nil
  texture:setFilter('linear','linear');texture:setWrap('clamp','clamp')
  local f=faces[item.face];local vertices={}
  for _,uv in ipairs({{0,0},{1,0},{1,1},{0,1}})do
   local u=(c.x+uv[1]*w)/size*2-1;local v=1-(c.y+uv[2]*h)/size*2
   if item.face=='ground'then
    local ground=meta.ground
    vertices[#vertices+1]={ground.x+uv[1]*ground.spanX,-8,ground.z+uv[2]*ground.spanZ,uv[1],uv[2],1}
   else
    vertices[#vertices+1]={f[1]+u*f[3],v,f[2]+u*f[4],uv[1],uv[2],1}
   end
  end
  mesh=assert(G.newMesh(vertices,{1,2,3,1,3,4}),'source-world mesh')
  parts[#parts+1]={mesh=mesh,texture=texture,lights=item.layer=='lights',ground=item.face=='ground'}
  bytes=bytes+w*h*4;M.uploads=M.uploads+1
 end)
 if not ok then
  release(pixels);release(mesh);release(texture);clear();done=true;M.failures=M.failures+1;errorText=tostring(err)
  return true -- optional backdrop failed: keep the complete semantic horizon
 end
 if #queue==0 then done=true;active=true end
 return done
end
function M.ready(state)select(state);return active end
function M.setEnabled(value)
 value=value~=false
 if enabled~=value then enabled=value;clear();key=nil end
end
function M.invalidate()clear();key=nil;index=nil;verdicts=nil end
function M.status()return {ready=active,done=done,bytes=bytes,parts=#parts,pending=#queue,key=key,error=errorText,uploads=M.uploads}end
function M.draw(state)
 if not active or not meta then return false end
 local g=love.graphics;local shader=g.getShader();local eye=G.eye or meta.eye
 local distance=math.sqrt((eye[1]-meta.eye[1])^2+(eye[2]-meta.eye[2])^2+(eye[3]-meta.eye[3])^2)
 local radius=math.max(1800,distance+512)
 local model=Mat.mul(Mat.translate(unpack(meta.eye)),Mat.scale(radius,radius,radius))
 local light=V.require('DayNight').windowLight()
 g.push('all');g.setDepthMode('lequal',false);G.glass(false)
 local ok,err=pcall(function()
  if shader then shader:send('curve',{0,0,0})end
  for _,p in ipairs(parts)do
   if not p.lights or light>0 then
    if p.lights then G.flatten({1,.83,.48},1);g.setColor(1,1,1,light)end
    G.draw(p.mesh,p.texture,p.ground and Mat.identity() or model)
    if p.lights then G.flatten(nil);g.setColor(1,1,1,1)end
   end
  end
 end)
 G.flatten(nil);G.glass(true)
 if shader then pcall(shader.send,shader,'curve',{G.curveX or 0,G.curveZ or 0,G.curveK or 0})end
 g.pop()
 if not ok then clear();done=true;M.failures=M.failures+1;errorText=tostring(err)end
 return ok
end
if Assets.register then Assets.register(M.invalidate)end
return M
