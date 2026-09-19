return function(game)
 io.stdout:setvbuf('no')
 assert(os.getenv('POKEPORT_IDENTITY')=='vasc-gen2-panorama-ready-20260919' or os.getenv('POKEPORT_IDENTITY')=='vasc-gen2-regression-20260919-gold-matrix','offline bake requires the isolated QA identity')
 local function wait(n) for _=1,n do coroutine.yield() end end
 print('BENCH_DRIVER_READY')
 local ex=assert(game.mods.exports.VOXEL_ASCENDANT)
 local bridge
 for i=1,50 do local n,v=debug.getupvalue(ex.voxelStatus,i);if n=='GoldVoxelBridge'then bridge=v;break end end
 assert(bridge and ex.active and ex.rendererInstalled)
 if ex.ascendantContent then ex.ascendantContent.promptDisabled=true end
 local opts=bridge.lib.mod.options;local original=opts.get
 local chosen={voxelDiskCache=false,voxel3d=true,daytime='day',weather='clear',enabled=false,town_pokemon=false,deviceProfile='auto',openWorld=true,cameraMode='full'}
 opts.get=function(self,k,...)if chosen[k]~=nil then return chosen[k] end return original(self,k,...)end

 local V=bridge.lib;local B=V.require('Buildings');local P=V.require('WorldPlacement');local Mat=V.require('Mat4')
 local G=V.require('Voxel3D');local batches={};local target;local maps;local origin
 local Sig=V.require('JohtoWorldSignature');local output=assert(os.getenv('BAKE_OUTPUT'));local function write(name,bytes)local f=assert(io.open(output..'/'..name,'wb'));f:write(bytes);f:close()end
 local function serial(v)
  if type(v)=='number'or type(v)=='boolean'then return tostring(v)elseif type(v)=='string'then return string.format('%q',v)end
  local keys={};for k in pairs(v)do keys[#keys+1]=k end;table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
  local out={'{'};for _,k in ipairs(keys)do out[#out+1]='['..serial(k)..']='..serial(v[k])..','end;out[#out+1]='}';return table.concat(out)
 end
 local metadata={revision=3,maps={},buildings={},excluded={},files={}}
 local format={{'VertexPosition','float',3},{'VertexTexCoord','float',2},{'VertexColor','float',4},{'WindowLight','float',1}}
 local current;local baseLayer=false;local material;local materials={}
 local function flush()
  if current and #current.v>0 then
   current.mesh=love.graphics.newMesh(format,current.v,'triangles','static');current.mesh:setVertexMap(current.indices)
   metadata.vertices=(metadata.vertices or 0)+#current.v;current.v=nil;current.indices=nil;batches[#batches+1]=current
  end
  current={v={},indices={},mapId=baseLayer and false or target,base=baseLayer,material=material}
 end
 local function quad(q,color,ox,oz,shade,lit,uv)
  if #current.v>12000 then flush()end
  local base=#current.v;shade=shade or 1
  for i=1,4 do local p=q[i];current.v[#current.v+1]={p[1]+ox,p[2],p[3]+oz,uv and uv[i][1] or 0,uv and uv[i][2] or 0,color[1]*shade,color[2]*shade,color[3]*shade,1,lit and 1 or 0}end
  for _,i in ipairs({1,2,3,1,3,4})do current.indices[#current.indices+1]=base+i end
 end
 local function box(x,y,z,w,h,d,c,ox,oz)
  for i,face in ipairs(G.FACE_CORNERS)do local q={};for _,p in ipairs(face)do q[#q+1]={x+p[1]*w,y+p[2]*h,z+p[3]*d}end;quad(q,c,ox,oz,G.FACE_SHADE[i])end
 end
 -- Offline-only crown LOD: open trunks and staggered, tapering tiers.
 -- Full-height green cubes turn into a palisade when seen from ground level.
 local function tree(x,z,seed,ox,oz)
  local h=seed%9
  local dx=seed%15-7;local dz=math.floor(seed/7)%15-7
  local spread=22+seed%6*2
  local tone=1+(seed%5-2)*.07
  box(x+14+dx,0,z+14+dz,4,13+h,4,{.24,.19,.10},ox,oz)
  box(x+(32-spread)/2+dx,10+h,z+(32-spread)/2+dz,spread,10,spread,{.17*tone,.34*tone,.11*tone},ox,oz)
  box(x+6+dx,20+h,z+6+dz,20,7,20,{.21*tone,.40*tone,.13*tone},ox,oz)
  box(x+11+dx,27+h,z+11+dz,10,5,10,{.25*tone,.45*tone,.16*tone},ox,oz)
 end
 local function tileColor(data,map,tile)
  local w,h=data:getDimensions();local per=map.tileset.tilesPerRow or 16
  local x,y=(tile%per)*8,math.floor(tile/per)*8;local rr,gg,bb,n=0,0,0,0
  for dy=1,6,2 do for dx=1,6,2 do if x+dx<w and y+dy<h then local a,b,c,alpha=data:getPixel(x+dx,y+dy);if alpha>.5 then rr=rr+a;gg=gg+b;bb=bb+c;n=n+1 end end end end
  if n==0 then return {.18,.35,.16}end
  return {rr/n,gg/n,bb/n}
 end
 local masks={}
 local stamp=B.stamp
 B.stamp=function(S,map,quads,tx,ty,bw,bh,t)
  if map.id==target then
   local pos=P.position(map.id,maps);local ox,oz=pos.x-origin.x,pos.y-origin.y
   local data=assert(map.renderer._stadiumAtlasData,'colored native atlas missing');local aw,ah=data:getDimensions()
   if not masks[map.id]then
    local source=map.renderer._stadiumGeometryData or require('src.render.Assets').imageData(map.tileset.image)
    local w,h=source:getDimensions()
    masks[map.id]=V.require('GlassMask').scan(function(x,y)return source:getPixel(x,y)end,w,h)
   end
   if not materials[map.id]then
    local mask=love.image.newImageData(aw,ah)
    for _,rect in ipairs(masks[map.id])do for y=rect.y,rect.y+rect.h-1 do for x=rect.x,rect.x+rect.w-1 do mask:setPixel(x,y,1,1,1,1)end end end
    local texture=love.graphics.newImage(data);texture:setFilter('nearest','nearest')
    local windows=love.graphics.newImage(mask);windows:setFilter('nearest','nearest');mask:release()
    materials[map.id]={texture=texture,windows=windows}
   end
   if material~=materials[map.id]then flush();material=materials[map.id];flush()end
   for _,q in ipairs(quads)do
    local u,v=0,0;for _,uv in ipairs(q.uv)do u=u+uv[1]/4;v=v+uv[2]/4 end
    local r,g,b,a=data:getPixel(math.min(aw-1,math.max(0,math.floor(u*aw))),math.min(ah-1,math.max(0,math.floor(v*ah))))
    local lit=false
    for _,rect in ipairs(masks[map.id])do if u*aw>=rect.x and u*aw<rect.x+rect.w and v*ah>=rect.y and v*ah<rect.y+rect.h then lit=true;break end end
    if lit then metadata.windowQuads=(metadata.windowQuads or 0)+1 end
    quad(q,{1,1,1},ox+tx*8,oz+ty*8,q.shade,lit,q.uv)
   end
   metadata.buildings[#metadata.buildings+1]={map=map.id,id=t.id,x=ox+tx*8,z=oz+ty*8,quads=#quads}
  end
  return stamp(S,map,quads,tx,ty,bw,bh,t)
 end
 local build=B.build;local done={}
 B.build=function(S,map,...)
  local wanted=map.id==target and not done[map.id]
  if map.id==target and done[map.id]then local prior=target;target=nil;local result=build(S,map,...);target=prior;return result end
  local result=build(S,map,...)
  if wanted then
   done[map.id]=true;local p=P.position(map.id,maps);local ox,oz=p.x-origin.x,p.y-origin.y
   local pixels=assert(map.renderer._stadiumAtlasData);local trees=0;local classes={}
   flush();baseLayer=true;material=nil;flush()
   for y=0,map.def.height*4-1,4 do for x=0,map.def.width*4-1,4 do
    local key=(y+65)*4096+x+65;local shape=S.shapeAt[key];local tile=S.tileAt[key]
    if tile and shape then
     local groundTile=S.ground[key] or tile
     local color=tileColor(pixels,map,groundTile)
     local c=shape.class;classes[c]=(classes[c]or 0)+1
     local isTree=not S.skip[key]and(c=='canopy'or c=='tree'or c=='cylinder'or c=='planter')
     if isTree then color={.20,.39,.12}end
     quad({{x*8,-1,y*8},{x*8+32,-1,y*8},{x*8+32,-1,y*8+32},{x*8,-1,y*8+32}},color,ox,oz)
     
    end
   end end
   flush();baseLayer=false;flush()
   for y=0,map.def.height*4-1,4 do for x=0,map.def.width*4-1,4 do
    local key=(y+65)*4096+x+65;local shape=S.shapeAt[key];local c=shape and shape.class
    if not S.skip[key]and(c=='canopy'or c=='tree'or c=='cylinder'or c=='planter')then
     trees=trees+1;tree(x*8,y*8,(x*13+y*31)%97,ox,oz)
    end
   end end
   metadata.maps[#metadata.maps+1]={id=map.id,x=ox,z=oz,w=map.def.width*32,h=map.def.height*32,trees=trees}
   print('SOURCE_CAPTURED',map.id,#metadata.buildings,trees,serial(classes))
  end
  return result
 end
 love.window.setMode(1000,700,{vsync=1})
 local save=require('src.core.gen2.Save').newGame({playerName='VISTAQA'})
 game.save=save;game:adoptSave(save);game.world.save=save;require('src.mods.Runtime').emit('save.created',{game=game,save=save})
 game:continueGame(save);wait(120)
 V.require('DayNight').setting:setValue('day',game)
 game.world.checkTrainerBattle=function()return false end;game.world.trySceneScript=function()return false end
 game.world.tryCoordScript=function()return false end;game.world.tryWildEncounter=function()return false end
 maps=game.world.maps;local root='GOLDENROD_CITY';origin=assert(P.position(root,maps))
 local ids,roots={},{}
 for id,d in pairs(maps)do
  local p=P.position(id,maps)
  if p and p.anchor==origin.anchor and(d.environment=='TOWN' or d.environment=='ROUTE')then
   ids[#ids+1]=id
   if d.tileset=='TILESET_JOHTO' or d.tileset=='TILESET_JOHTO_MODERN'then roots[#roots+1]=id end
  end
 end
 table.sort(roots)
 if os.getenv('BAKE_ONLY')then roots={os.getenv('BAKE_ONLY')}end
 table.sort(ids);flush()
 for _,id in ipairs(ids)do
  target=id;flush();current.mapId=id;V.require('Structures').invalidate();assert(game.world:setMap(id,4,4,'down'))
  local start=love.timer.getTime()
  repeat wait(1);assert(love.timer.getTime()-start<40,'source build timeout '..id)until done[id]
  target=nil;flush();wait(2)
 end
 assert(#metadata.maps==#ids,'missing source map')
 -- Continuous stepped woods fill only unmapped land near a source map.
 -- Native maps (including excluded near maps) and exposed coastal edges win.
 local H=V.require('HorizonWall');local footprint={}
 for id,d in pairs(maps)do local p=P.position(id,maps)
  if p and p.anchor==origin.anchor and(d.environment=='TOWN'or d.environment=='ROUTE')then
   footprint[#footprint+1]={id=id,def=d,x=p.x-origin.x,z=p.y-origin.y,w=d.width*32,h=d.height*32}
  end
 end
 table.sort(footprint,function(a,b)return a.id<b.id end)
 local forestCells=0
 local minx,minz,maxx,maxz=0,0,0,0
 for _,m in ipairs(footprint)do minx=math.min(minx,m.x);minz=math.min(minz,m.z);maxx=math.max(maxx,m.x+m.w);maxz=math.max(maxz,m.z+m.h)end
 minx=math.floor(minx/64)*64-1024;minz=math.floor(minz/64)*64-1024
 maxx=math.ceil(maxx/64)*64+1024;maxz=math.ceil(maxz/64)*64+1024
 for z=minz,maxz,64 do for x=minx,maxx,64 do
  local cx,cz=x+32,z+32;local occupied=false;local nearest,best
  for _,m in ipairs(footprint)do
   if x<m.x+m.w and x+64>m.x and z<m.z+m.h and z+64>m.z then occupied=true;break end
   local dx=math.max(m.x-cx,0,cx-m.x-m.w);local dz=math.max(m.z-cz,0,cz-m.z-m.h)
   local distance=dx*dx+dz*dz
   if not best or distance<best then nearest,best=m,distance end
  end
  local tone=1+((x*7+z*13)%11-5)*.008
  quad({{x,-8,z},{x+64,-8,z},{x+64,-8,z+64},{x,-8,z+64}},{.16*tone,.30*tone,.105*tone},0,0)
  if not occupied and nearest then
   local m=nearest;local mx,mz=cx-m.x,cz-m.z
   local open=false
   for _,edge in ipairs({'north','south','west','east'})do
    local outside=edge=='north'and mz<0 or edge=='south'and mz>m.h or edge=='west'and mx<0 or edge=='east'and mx>m.w
    if outside then local along=(edge=='north'or edge=='south')and mx or mz
     local kind=H.panelProfile({id=m.id,def=m.def},edge,along)
     if kind=='open_water'or kind=='water'then open=true end
    end
   end
   if open then
    quad({{x,-2,z},{x+64,-2,z},{x+64,-2,z+64},{x,-2,z+64}},{.10,.30,.45},0,0)
    metadata.waterCells=(metadata.waterCells or 0)+1
   else
    forestCells=forestCells+1
    box(x,-6,z,64,6,64,{.10,.23,.08},0,0)
    for iz=0,1 do for ix=0,1 do
     local xx,zz=x+ix*32,z+iz*32
     tree(xx,zz,(xx*7+zz*13)%97,0,0)
    end end
   end
  end
 end;wait(1)end
 flush();metadata.forestCells=forestCells
 print('SOURCE_FOREST_FILL',forestCells)
 local g=love.graphics
 local shader=g.newShader([[uniform float maskMode;uniform float windowOn;uniform Image windowMask;
 vec4 effect(vec4 c,Image t,vec2 uv,vec2 p){float lamp=Texel(windowMask,uv).a*windowOn;return maskMode>.5?vec4(lamp,lamp,lamp,1.0):Texel(t,uv)*c;}]],
 [[uniform mat4 vp;vec4 position(mat4 t,vec4 p){return vp*p;}]])
 local blankPixels=love.image.newImageData(1,1);blankPixels:setPixel(0,0,1,1,1,1);local blank=love.graphics.newImage(blankPixels);blankPixels:release()
 local size=640;local canvas=g.newCanvas(size,size,{format='rgba8',dpiscale=1,msaa=0});local depthCanvas=g.newCanvas(size,size,{format='depth24',readable=false,dpiscale=1,msaa=0})
 local faces={{name='east',dir={1,0,0}},{name='west',dir={-1,0,0}},{name='south',dir={0,0,1}},{name='north',dir={0,0,-1}}}
 -- A world-aligned orthographic ground capture closes downward views.
 -- Putting this in the cubemap stretches an entire city across the floor
 -- when the diorama camera pulls back. The plane retains source map scale.
 local groundSize=1024
 local groundCanvas=g.newCanvas(groundSize,groundSize,{format='rgba8',dpiscale=1,msaa=0})
 local groundDepth=g.newCanvas(groundSize,groundSize,{format='depth24',readable=false,dpiscale=1,msaa=0})
 local centerX,centerZ=(minx+maxx+64)/2,(minz+maxz+64)/2
 local spanX,spanZ=maxx+64-minx,maxz+64-minz
 local groundVP=Mat.mul(Mat.scale(1,-1,1),Mat.mul(Mat.ortho(-spanX/2,spanX/2,-spanZ/2,spanZ/2,1,4096),Mat.lookAt({centerX,2048,centerZ},{centerX,0,centerZ},{0,0,-1})))
 g.push('all');g.origin();g.setCanvas({groundCanvas,depthstencil=groundDepth});g.clear(0,0,0,0,0,1)
 g.setShader(shader);shader:send('vp','row',groundVP);shader:send('maskMode',0)
 g.setDepthMode('lequal',true);g.setMeshCullMode('none');g.setBlendMode('replace');g.setColor(1,1,1,1)
 for _,b in ipairs(batches)do local m=b.material;b.mesh:setTexture(m and m.texture or blank)
  shader:send('windowMask',m and m.windows or blank);shader:send('windowOn',0);g.draw(b.mesh)
 end
 g.pop();local groundPixels=groundCanvas:newImageData()
 write('shared--ground-land.png',groundPixels:encode('png'):getString())
 groundPixels:release();groundCanvas:release();groundDepth:release()
 local groundPath='assets/scenery/johto-world/'..assert(os.getenv('POKEPORT_VERSION'))..'/shared/ground-land.png'
 local views={}
 for _,id in ipairs(roots)do
  local pos=P.position(id,maps);local ox,oz=pos.x-origin.x,pos.y-origin.y
  local eye={ox+maps[id].width*16,128,oz+maps[id].height*16}
  for nearDepth=1,4 do
   local excluded=Sig.near(maps,id,nearDepth)
   local prefix=id..'-'..nearDepth
   local view={size=size,eye={maps[id].width*16,128,maps[id].height*16},files={},path='assets/scenery/johto-world/'..assert(os.getenv('POKEPORT_VERSION'))..'/'..prefix}
   view.ground={path=groundPath,w=groundSize,h=groundSize,x=minx-ox,z=minz-oz,spanX=spanX,spanZ=spanZ}
   for _,face in ipairs(faces)do for _,layer in ipairs({'land','lights'})do
    local target={eye[1]+face.dir[1],eye[2]+face.dir[2],eye[3]+face.dir[3]}
    local vp=Mat.mul(Mat.scale(1,-1,1),Mat.mul(Mat.perspective(math.pi/2,1,1,16000),Mat.lookAt(eye,target,face.up or {0,1,0})))
    g.push('all');g.origin();g.setCanvas({canvas,depthstencil=depthCanvas});g.clear(0,0,0,0,0,1)
    g.setShader(shader);shader:send('vp','row',vp);shader:send('maskMode',layer=='lights' and 1 or 0)
    g.setDepthMode('lequal',true);g.setMeshCullMode('none');g.setBlendMode('replace');g.setColor(1,1,1,1)
    for _,b in ipairs(batches)do if b.base or not b.mapId or not excluded[b.mapId]then
     local m=b.material;b.mesh:setTexture(m and m.texture or blank)
     shader:send('windowMask',m and m.windows or blank);shader:send('windowOn',m and 1 or 0);g.draw(b.mesh)
    end end
    g.pop();local data=canvas:newImageData();local x0,y0,x1,y1=size,size,-1,-1
    for y=0,size-1 do for x=0,size-1 do
     local r,gg,bb,alpha=data:getPixel(x,y)
     local fade=math.max(0,math.min(1,(size*.6-y)/(size*.075)))
     alpha=alpha*fade
     if layer=='lights'then alpha=alpha*r;data:setPixel(x,y,1,1,1,alpha)else data:setPixel(x,y,r,gg,bb,alpha)end
     if alpha>0 then x0=math.min(x0,x);y0=math.min(y0,y);x1=math.max(x1,x);y1=math.max(y1,y)end
    end end
    if x1>=x0 then
     x0=math.max(0,x0-1);y0=math.max(0,y0-1);x1=math.min(size-1,x1+1);y1=math.min(size-1,y1+1)
     local crop=love.image.newImageData(x1-x0+1,y1-y0+1);crop:paste(data,0,0,x0,y0,crop:getDimensions())
     local name=face.name..'-'..layer
     write(prefix..'--'..name..'.png',crop:encode('png'):getString())
     if layer=='lights'then metadata.lightImages=(metadata.lightImages or 0)+1 end
     view.files[name]={x=x0,y=y0,w=x1-x0+1,h=y1-y0+1};crop:release()
    end
    data:release();wait(1)
   end end
   local bytes=groundSize*groundSize*4;for _,c in pairs(view.files)do bytes=bytes+c.w*c.h*4 end
   assert(bytes<=6*1024*1024,'view memory limit '..prefix)
   views[id..':'..nearDepth]=view
   print('VIEW_CAPTURED',id,nearDepth,bytes)
  end
 end
 local function hash(raw)return love.data.encode('string','hex',love.data.hash('sha256',raw))end
 local signature=assert(Sig.digest(maps,game.world.tilesets,game.world.roofs,game.data.gen2Palettes,ids,
  function(path)return hash(require('src.render.Assets').imageData(path):getString())end,hash))
 assert((metadata.windowQuads or 0)>0,'native window mask matched no building geometry')
 if not os.getenv('BAKE_ONLY')then assert((metadata.lightImages or 0)>0,'no visible night windows in complete catalogue')end
 print('WINDOW_CAPTURE',metadata.windowQuads,metadata.lightImages or 0)
 write('index.lua','return '..Sig.serialize({signature=signature,maps=ids,views=views})..'\n')
 write('source.lua','return '..serial(metadata)..'\n')
 for _,b in ipairs(batches)do b.mesh:release()end
 for _,m in pairs(materials)do m.texture:release();m.windows:release()end;blank:release();canvas:release();depthCanvas:release();shader:release()
 print('PASS_JOHTO_WORLD_CATALOG_BAKE',#ids,#roots,#metadata.buildings,metadata.vertices)
 love.event.quit()
end
