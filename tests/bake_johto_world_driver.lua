return function(game)
 io.stdout:setvbuf('no')
 assert(os.getenv('POKEPORT_IDENTITY')=='vasc-gen2-panorama-ready-20260919','offline bake requires the isolated QA identity')
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
 local output=assert(os.getenv('BAKE_OUTPUT'));local function write(name,bytes)local f=assert(io.open(output..'/'..name,'wb'));f:write(bytes);f:close()end
 local function serial(v)
  if type(v)=='number'or type(v)=='boolean'then return tostring(v)elseif type(v)=='string'then return string.format('%q',v)end
  local keys={};for k in pairs(v)do keys[#keys+1]=k end;table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
  local out={'{'};for _,k in ipairs(keys)do out[#out+1]='['..serial(k)..']='..serial(v[k])..','end;out[#out+1]='}';return table.concat(out)
 end
 local metadata={revision=2,maps={},buildings={},excluded={},files={}}
 local format={{'VertexPosition','float',3},{'VertexTexCoord','float',2},{'VertexColor','float',4}}
 local current
 local function flush()
  if current and #current.v>0 then
   current.mesh=love.graphics.newMesh(format,current.v,'triangles','static');current.mesh:setVertexMap(current.indices)
   metadata.vertices=(metadata.vertices or 0)+#current.v;current.v=nil;current.indices=nil;batches[#batches+1]=current
  end
  current={v={},indices={}}
 end
 local function quad(q,color,ox,oz,shade)
  if #current.v>12000 then flush()end
  local base=#current.v;shade=shade or 1
  for i=1,4 do local p=q[i];current.v[#current.v+1]={p[1]+ox,p[2],p[3]+oz,0,0,color[1]*shade,color[2]*shade,color[3]*shade,1}end
  for _,i in ipairs({1,2,3,1,3,4})do current.indices[#current.indices+1]=base+i end
 end
 local function box(x,y,z,w,h,d,c,ox,oz)
  for i,face in ipairs(G.FACE_CORNERS)do local q={};for _,p in ipairs(face)do q[#q+1]={x+p[1]*w,y+p[2]*h,z+p[3]*d}end;quad(q,c,ox,oz,G.FACE_SHADE[i])end
 end
 -- Offline-only crown LOD: open trunks and staggered, tapering tiers.
 -- Full-height green cubes turn into a palisade when seen from ground level.
 local function tree(x,z,seed,ox,oz)
  local h=seed%9
  local dx=seed%7-3;local dz=math.floor(seed/7)%7-3
  local tone=1+(seed%5-2)*.07
  box(x+14+dx,0,z+14+dz,4,13+h,4,{.24,.19,.10},ox,oz)
  box(x+3+dx,10+h,z+3+dz,26,10,26,{.17*tone,.34*tone,.11*tone},ox,oz)
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
 local stamp=B.stamp
 B.stamp=function(S,map,quads,tx,ty,bw,bh,t)
  if map.id==target then
   local pos=P.position(map.id,maps);local ox,oz=pos.x-origin.x,pos.y-origin.y
   local data=assert(map.renderer._stadiumAtlasData,'colored native atlas missing');local aw,ah=data:getDimensions()
   for _,q in ipairs(quads)do
    local u,v=0,0;for _,uv in ipairs(q.uv)do u=u+uv[1]/4;v=v+uv[2]/4 end
    local r,g,b,a=data:getPixel(math.min(aw-1,math.max(0,math.floor(u*aw))),math.min(ah-1,math.max(0,math.floor(v*ah))))
    quad(q,{r,g,b},ox+tx*8,oz+ty*8,q.shade)
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
   for y=0,map.def.height*4-1,4 do for x=0,map.def.width*4-1,4 do
    local key=(y+65)*4096+x+65;local shape=S.shapeAt[key];local tile=S.tileAt[key]
    if tile and shape then
     local color=tileColor(pixels,map,tile)
     local c=shape.class;classes[c]=(classes[c]or 0)+1
     local isTree=not S.skip[key]and(c=='canopy'or c=='tree'or c=='cylinder'or c=='planter')
     if isTree then color={.20,.39,.12}end
     quad({{x*8,-1,y*8},{x*8+32,-1,y*8},{x*8+32,-1,y*8+32},{x*8,-1,y*8+32}},color,ox,oz)
     if isTree then trees=trees+1;tree(x*8,y*8,(x*13+y*31)%97,ox,oz)end
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
 -- Match the actual placed-camera residency (one hop), not a guessed ring.
 -- No duplicate near buildings are allowed in this background candidate.
 local excluded={[root]=true};local todo={root};local depth={[root]=0}
 for i=1,100 do local id=todo[i];if not id then break end;if depth[id]<1 then for _,c in pairs(maps[id].connections or{})do local n=c.mapId or c.map;if maps[n]and not excluded[n]then excluded[n]=true;depth[n]=depth[id]+1;todo[#todo+1]=n end end end end
 metadata.excluded=excluded;metadata.root=root;metadata.nearDepth=1
 local ids={}
 for id,d in pairs(maps)do
  local p=P.position(id,maps)
  if p and p.anchor==origin.anchor and not excluded[id]and(d.environment=='TOWN'or d.environment=='ROUTE')then
   local dx,dz=p.x-origin.x,p.y-origin.y
   if dx*dx+dz*dz<4200*4200 then ids[#ids+1]=id end
  end
 end
 table.sort(ids);flush()
 for _,id in ipairs(ids)do
  target=id;V.require('Structures').invalidate();assert(game.world:setMap(id,4,4,'down'))
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
 for z=-4096,4096,64 do for x=-4096,4096,64 do
  local cx,cz=x+32,z+32;local occupied=false;local nearest,best
  for _,m in ipairs(footprint)do
   if x<m.x+m.w and x+64>m.x and z<m.z+m.h and z+64>m.z then occupied=true;break end
   local dx=math.max(m.x-cx,0,cx-m.x-m.w);local dz=math.max(m.z-cz,0,cz-m.z-m.h)
   local distance=dx*dx+dz*dz
   if not best or distance<best then nearest,best=m,distance end
  end
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
   elseif best<384*384 then
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
 local shader=g.newShader([[vec4 effect(vec4 c,Image t,vec2 uv,vec2 p){return c;}]],[[uniform mat4 vp;vec4 position(mat4 t,vec4 p){return vp*p;}]])
 local size=1024;local canvas=g.newCanvas(size,size,{format='rgba8',dpiscale=1,msaa=0});local depthCanvas=g.newCanvas(size,size,{format='depth24',readable=false,dpiscale=1,msaa=0})
 local eye={maps[root].width*16,32,maps[root].height*16};metadata.eye=eye;metadata.faceSize=size;local faces={
  {name='east',dir={1,0,0},up={0,1,0}}, {name='west',dir={-1,0,0},up={0,1,0}},
  {name='south',dir={0,0,1},up={0,1,0}}, {name='north',dir={0,0,-1},up={0,1,0}}}
 for _,face in ipairs(faces)do
  local target={eye[1]+face.dir[1],eye[2]+face.dir[2],eye[3]+face.dir[3]}
  local vp=Mat.mul(Mat.scale(1,-1,1),Mat.mul(Mat.perspective(math.pi/2,1,1,16000),Mat.lookAt(eye,target,face.up)))
  g.push('all');g.origin();g.setCanvas({canvas,depthstencil=depthCanvas});g.clear(0,0,0,0,0,1)
  g.setShader(shader);shader:send('vp','row',vp);g.setDepthMode('lequal',true);g.setMeshCullMode('none');g.setBlendMode('replace');g.setColor(1,1,1,1)
  for _,b in ipairs(batches)do g.draw(b.mesh)end
  g.setCanvas();g.pop();local data=canvas:newImageData()
  local x0,y0,x1,y1=size,size,-1,-1
  for y=0,size-1 do for x=0,size-1 do
   local _,_,_,a=data:getPixel(x,y)
   if a>0 then x0=math.min(x0,x);y0=math.min(y0,y);x1=math.max(x1,x);y1=math.max(y1,y)end
  end end
  if x1>=x0 then
   x0=math.max(0,x0-1);y0=math.max(0,y0-1);x1=math.min(size-1,x1+1);y1=math.min(size-1,y1+1)
   local crop=love.image.newImageData(x1-x0+1,y1-y0+1)
   crop:paste(data,0,0,x0,y0,crop:getDimensions())
   write(face.name..'.png',crop:encode('png'):getString())
   metadata.files[face.name]={x=x0,y=y0,w=x1-x0+1,h=y1-y0+1}
   crop:release()
  end
  data:release();wait(1)
 end
 write('source.lua','return '..serial(metadata)..'\n')
 for _,b in ipairs(batches)do b.mesh:release()end;canvas:release();depthCanvas:release();shader:release()
 print('PASS_JOHTO_SOURCE_WORLD_BAKE',#metadata.maps,#metadata.buildings,metadata.vertices)
 love.event.quit()
end
