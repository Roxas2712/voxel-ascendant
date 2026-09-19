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


 local V=bridge.lib;local G=V.require('Voxel3D');local Mat=V.require('Mat4');local P=V.require('PanoramaBackdrop');local S=V.require('VoxelScene')
 local output=assert(os.getenv('BAKE_OUTPUT'));local views=assert(os.getenv('VIEW_OUTPUT'))
 local function replace(fn,name,value,seen)
  if type(fn)~='function'then return false end;seen=seen or{};if seen[fn]then return false end;seen[fn]=true
  for i=1,200 do local n,v=debug.getupvalue(fn,i);if not n then break end;if n==name then debug.setupvalue(fn,i,value);return true end end
  for i=1,200 do local n,v=debug.getupvalue(fn,i);if not n then break end;if replace(v,name,value,seen)then return true end end
  return false
 end
 local faces={
  {name='east',dir={1,0,0},right={0,0,1}}, {name='west',dir={-1,0,0},right={0,0,-1}},
  {name='south',dir={0,0,1},right={-1,0,0}}, {name='north',dir={0,0,-1},right={1,0,0}}}
 local metadata=assert(loadfile(output..'/source.lua'))();assert(metadata.nearDepth==1);local parts={};local enabled=false;local loaded=false;local uploads=0;local gpuBytes=0
 P.prepare=function()
  if loaded then return true end
  for _,f in ipairs(faces)do
   local file=assert(io.open(output..'/'..f.name..'.png','rb'));local raw=file:read('*a');file:close()
   local data=love.image.newImageData(love.filesystem.newFileData(raw,f.name..'.png'));local w,h=data:getDimensions();local crop=assert(metadata.files[f.name]);assert(w==crop.w and h==crop.h,'crop extent mismatch');gpuBytes=gpuBytes+w*h*4;assert(gpuBytes<=2*1024*1024,'panorama exceeded 2 MiB');local tex=love.graphics.newImage(data);uploads=uploads+1;data:release();tex:setFilter('nearest','nearest')
   local vertices={};local radius=1800
   for _,uv in ipairs({{0,0},{1,0},{1,1},{0,1}})do local crop=assert(metadata.files[f.name]);local u=(crop.x+uv[1]*crop.w)/metadata.faceSize*2-1;local v=1-(crop.y+uv[2]*crop.h)/metadata.faceSize*2
    vertices[#vertices+1]={metadata.eye[1]+radius*(f.dir[1]+u*f.right[1]),metadata.eye[2]+radius*v,metadata.eye[3]+radius*(f.dir[3]+u*f.right[3]),uv[1],uv[2],1}
   end
   parts[#parts+1]={mesh=assert(G.newMesh(vertices,{1,2,3,1,3,4})),tex=tex}
  end
  loaded=true;return true
 end
 P.ready=function()return loaded end;P.setEnabled=function()end
 P.drawAt=function()
  love.graphics.setDepthMode('lequal',false);G.glass(false)
  local shader=love.graphics.getShader();if shader then shader:send('curve',{0,0,0})end
  for _,p in ipairs(parts)do G.draw(p.mesh,p.tex,Mat.identity())end
  if shader then shader:send('curve',{G.curveX or 0,G.curveZ or 0,G.curveK or 0})end
  G.glass(true);love.graphics.setDepthMode('lequal',true);return true
 end
 assert(replace(S.render,'hasAuthoredPanorama',function(map)return enabled and map.id=='GOLDENROD_CITY'end),'no panorama predicate')
 love.window.setMode(1100,700,{vsync=1})
 local save=require('src.core.gen2.Save').newGame({playerName='VISTAQA'})
 game.save=save;game:adoptSave(save);game.world.save=save;require('src.mods.Runtime').emit('save.created',{game=game,save=save});game:continueGame(save);wait(120)
 V.require('DayNight').setting:setValue('day',game)
 game.world.checkTrainerBattle=function()return false end;game.world.trySceneScript=function()return false end;game.world.tryCoordScript=function()return false end;game.world.tryWildEncounter=function()return false end
 chosen.cameraMode='third';assert(game.world:setMap('GOLDENROD_CITY',20,10,'up'));wait(210)
 local F=V.require('FirstPerson');local yaw,pitch=math.pi,.06
 local render=S.render;S.render=function(...)F.yaw=yaw;F.pitch=pitch;return render(...)end
 wait(10)
 local function shot(name)
  love.graphics.captureScreenshot(function(data)local f=assert(io.open(views..'/'..name..'.png','wb'));f:write(data:encode('png'):getString());f:close();data:release()end);wait(3)
 end
 shot('before');enabled=true;wait(90);shot('source-world')
 local H=V.require('HorizonWall');local meshes=H.meshes;local seen={}
 H.meshes=function(...)
  local parts=meshes(...);local out={}
  for _,p in ipairs(parts or{})do
   local key=tostring(p.kind)..'/'..tostring(p.class);if not seen[key]then print('RIM',key);seen[key]=true end
   if not (enabled and game.world.map.id==metadata.root and p.kind=='wall' and p.class=='regional') then out[#out+1]=p end
  end
  return out
 end
 wait(90);shot('without-outer-curtain')
 
 F.EYE_HEIGHT=80;pitch=.16;enabled=false;wait(90);shot('elevated-before');enabled=true;wait(90);shot('elevated-north')
 for _,a in ipairs({{name='east',yaw=math.pi/2},{name='south',yaw=0},{name='west',yaw=-math.pi/2}})do
  yaw=a.yaw;wait(30);shot('elevated-'..a.name)
 end
 yaw=math.pi;V.require('DayNight').setting:setValue('night',game);wait(120);shot('night')

 V.require('DayNight').setting:setValue('day',game);F.EYE_HEIGHT=13
 for _,p in ipairs({{13,10},{25,10}})do
  assert(game.world:setMap('GOLDENROD_CITY',p[1],p[2],'up'));wait(90);shot('move-'..p[1]);assert(bridge.openWorldDepth==metadata.nearDepth)
 end
 assert(game.world:setMap('NEW_BARK_TOWN',8,8,'down'));wait(120);shot('other-map-fallback')
 assert(game.world:setMap('GOLDENROD_CITY',20,10,'up'));wait(120);shot('return-cache')
 assert(uploads==4,'redecoded cache on map return');print('PASS_JOHTO_WORLD_VIEW_PROTOTYPE',bridge.frames3d,#parts,gpuBytes,uploads)
 enabled=false;loaded=false
 for _,p in ipairs(parts)do p.mesh:release();p.tex:release()end
 parts={}
 love.event.quit()

end
