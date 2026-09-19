-- Offline build driver. Requires an isolated QA identity and explicit output.
return function(game)
 io.stdout:setvbuf('no')
 assert(os.getenv('POKEPORT_IDENTITY')=='vasc-safari-terrain-20260919')
 local output=assert(os.getenv('ROOFTOP_BAKE_DIR'));local U=require('tests.drivers.util')
 game:startNewGame{intro=false}
 local exports=game.mods.exports.VOXEL_ASCENDANT
 local function find(fn,name,seen)
  if type(fn)~='function'then return end;seen=seen or{};if seen[fn]then return end;seen[fn]=true
  for i=1,200 do local k,v=debug.getupvalue(fn,i);if not k then break end;if k==name then return v end end
  for i=1,200 do local k,v=debug.getupvalue(fn,i);if not k then break end;local r=find(v,name,seen);if r then return r end end
 end
 local V=assert(find(exports.lib.require('VoxelScene').render,'V'))
 local World=V.require('RooftopWorld');local Cache=V.require('RooftopCache');local P=V.require('VoxelItems')
 local G=V.require('Voxel3D');local Mat=V.require('Mat4');local g=love.graphics
 local Map=require('src.world.Map');local metadata={}
 local source=os.getenv('ROOFTOP_SOURCE');local suffix=os.getenv('ROOFTOP_SUFFIX') or ''
 if source then
  game.data.maps=assert(loadfile(source..'/data/generated/maps.lua'))()
  game.data.tilesets=assert(loadfile(source..'/data/generated/tilesets.lua'))()
  V.require('WorldPlacement').invalidate();V.require('TileShape').invalidate()
  metadata=V.data('rooftop_cache')
 end
 local function write(path,raw)local f=assert(io.open(output..'/'..path,'wb'));f:write(raw);f:close()end
 local function serial(v)
  if type(v)=='string'then return string.format('%q',v)elseif type(v)=='number'or type(v)=='boolean'then return tostring(v)end
  local keys={};for k in pairs(v)do keys[#keys+1]=k end;table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
  local rows={'{'};for _,k in ipairs(keys)do rows[#rows+1]='['..serial(k)..']='..serial(v[k])..','end;rows[#rows+1]='}';return table.concat(rows)
 end
 local shader=g.newShader([[
  uniform bool maskPass;
  uniform bool litPart;
  varying float shade;
  vec4 effect(vec4 c, Image image, vec2 uv, vec2 px) {
   if (maskPass) return litPart ? vec4(1.0) : vec4(0.0);
   return vec4(Texel(image,uv).rgb * shade,1.0);
  }
 ]],[[
  uniform mat4 vp;
  attribute float VertexShade;
  varying float shade;
  vec4 position(mat4 t,vec4 p){shade=VertexShade;return vp*p;}
 ]])
 local size=Cache.FACE_SIZE
 local color=g.newCanvas(size,size,{format='rgba8',dpiscale=1,msaa=0})
 local depth=g.newCanvas(size,size,{format='depth24',readable=false,dpiscale=1,msaa=0})
 for _,style in ipairs({'stone','wood'})do
  V.require('Gen1LavenderTower').setting:setValue(style,game)
  for _,id in ipairs({'CELADON_MART_ROOF','CELADON_MANSION_ROOF'})do
   local start=love.timer.getTime();local d=game.data.maps[id];local map=Map.new(d,game.data.tilesets[d.tileset])
   local entry={map=map,w=d.width*32,h=d.height*32};local key=Cache.key(entry)..suffix
   local batches,parts,near={}, {},{};local emitted=0
   local function emitPart(b,isNear)
    local x,y,z,w,h,dep,c,lit=unpack(b);emitted=emitted+1
    if isNear then near[#near+1]=b;return end
    local k=lit and 1 or 0;local batch=batches[k]
    if not batch or batch.count>=256 then batch={v={},i={},count=0,lit=lit};parts[#parts+1]=batch;batches[k]=batch end
    batch.count=batch.count+1
    for face,corners in ipairs(G.FACE_CORNERS)do
     local base=#batch.v
     for _,p in ipairs(corners)do batch.v[#batch.v+1]={x+p[1]*w,y+p[2]*h,z+p[3]*dep,(c-.5)/#P.palette,.5,G.FACE_SHADE[face]}end
     for _,j in ipairs({1,2,3,1,3,4})do batch.i[#batch.i+1]=base+j end
    end
   end
   World.geometry(entry,game.data.maps,function(...)Cache.partition(entry,{...},emitPart)end,function()U.wait(1)end)
   for _,part in ipairs(parts)do part.mesh=assert(G.newMesh(part.v,part.i));part.mesh:setTexture(World.texture());part.v=nil;part.i=nil;U.wait(1)end
   local ids={};for _,m in ipairs(World.maps(entry,game.data.maps))do ids[#ids+1]=m.id end
   local meta={revision=Cache.REVISION,path='assets/scenery/rooftops/'..key,signature=Cache.signature(game.data.maps,ids,game.data.tilesets),maps=ids,files={},near=#near,boxes=emitted,landmarks=World.last.landmarks}
   write(key..'/near.bin',Cache.pack(near))
   local eye={entry.w/2,40,entry.h/2}
   for _,face in ipairs(Cache.faces)do
    local target={eye[1]+face.dir[1],eye[2]+face.dir[2],eye[3]+face.dir[3]}
    local vp=Mat.mul(Mat.scale(1,-1,1),Mat.mul(Mat.perspective(math.pi/2,1,1,16000),Mat.lookAt(eye,target,face.up)))
    for _,layer in ipairs({'land','lights'})do
     g.push('all');g.origin();g.setCanvas({color,depthstencil=depth});g.clear(0,0,0,0,0,1)
     g.setShader(shader);shader:send('vp','row',vp);shader:send('maskPass',layer=='lights')
     g.setMeshCullMode('none');g.setDepthMode('lequal',true);g.setBlendMode('replace');g.setColor(1,1,1,1)
     for _,part in ipairs(parts)do shader:send('litPart',part.lit==true);g.draw(part.mesh)end
     g.setCanvas();g.pop()
     local image=color:newImageData();local nonzero=0;local x0,y0,x1,y1=size,size,-1,-1
     -- Full alpha inspection catches empty sky faces and keeps them absent.
     image:mapPixel(function(x,y,r,gg,b,a)if a>0 then nonzero=nonzero+1;x0=math.min(x0,x);x1=math.max(x1,x);y0=math.min(y0,y);y1=math.max(y1,y)end;return r,gg,b,a end)
     if nonzero>0 then
      x0,y0=math.max(0,x0-1),math.max(0,y0-1);x1,y1=math.min(size-1,x1+1),math.min(size-1,y1+1)
      local crop=love.image.newImageData(x1-x0+1,y1-y0+1);crop:paste(image,0,0,x0,y0,x1-x0+1,y1-y0+1)
      local name=face.name..'-'..layer;write(key..'/'..name..'.png',crop:encode('png'):getString());crop:release()
      meta.files[name]={x=x0,y=y0,w=x1-x0+1,h=y1-y0+1,pixels=nonzero}
     end
     print('BAKE_FACE',key,face.name,layer,nonzero);image:release();U.wait(1)
    end
   end
   metadata[key]=meta
   for _,part in ipairs(parts)do part.mesh:release()end
   collectgarbage('collect')
   print('BAKE_READY',key,#near,emitted,#parts,love.timer.getTime()-start,collectgarbage('count'))
   write('index.lua','return '..serial(metadata)..'\n')
  end
 end
 shader:release();color:release();depth:release();print('PASS_ROOFTOP_BAKE');love.event.quit()
end
