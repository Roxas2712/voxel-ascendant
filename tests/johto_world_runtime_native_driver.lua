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
 local chosen={voxelDiskCache=false,voxel3d=true,daytime='day',weather='clear',enabled=false,town_pokemon=false,deviceProfile='auto',openWorld=true,worldZoomRange='world',cameraMode='full'}
 opts.get=function(self,k,...)if chosen[k]~=nil then return chosen[k] end return original(self,k,...)end

 local V=bridge.lib;local W=V.require('JohtoWorldBackdrop');local S=V.require('VoxelScene');local F=V.require('FirstPerson')
 assert(W.RELEASE_READY,'public far-view gate is not enabled')
 local output=assert(os.getenv('VIEW_OUTPUT'))
 love.window.setMode(1100,700,{vsync=1})
 local save=require('src.core.gen2.Save').newGame({playerName='VISTAQA'})
 game.save=save;game:adoptSave(save);game.world.save=save;require('src.mods.Runtime').emit('save.created',{game=game,save=save});game:continueGame(save);wait(120)
 V.require('DayNight').setting:setValue('day',game)
 game.world.checkTrainerBattle=function()return false end;game.world.trySceneScript=function()return false end;game.world.tryCoordScript=function()return false end;game.world.tryWildEncounter=function()return false end
 chosen.cameraMode='third';local yaw,pitch=math.pi,.10
 local latestState
 local render=S.render;S.render=function(state,...)latestState=state;F.yaw=yaw;F.pitch=pitch;return render(state,...)end
 local function shot(name)
  love.graphics.captureScreenshot(function(data)local f=assert(io.open(output..'/'..name..'.png','wb'));f:write(data:encode('png'):getString());f:close();data:release()end);wait(3)
 end
 for _,id in ipairs(os.getenv('VIEW_ONLY') and {os.getenv('VIEW_ONLY')} or {'GOLDENROD_CITY','NEW_BARK_TOWN','ECRUTEAK_CITY','OLIVINE_CITY'})do
  assert(game.world:setMap(id,10,8,'up'));wait(150)
  local status=W.status();print('WORLD_STATUS',id,status.ready,status.parts,status.bytes,status.error,status.key)
  assert(status.ready,'source-world view not active '..id..' '..tostring(status.error))
  local atlas=game.world.map.renderer._stadiumGeometryData or require('src.render.Assets').imageData(game.world.map.tileset.image)
  local w,h=atlas:getDimensions();local rects=V.require('GlassMask').scan(function(x,y)return atlas:getPixel(x,y)end,w,h);print('MASK_RECTS',id,#rects)
  local before=status.uploads;wait(20);assert(W.status().uploads==before,'static frame reuploads')
  shot(id..'-day');V.require('DayNight').setting:setValue('night',game);wait(90);shot(id..'-night');V.require('DayNight').setting:setValue('day',game)
 end
 assert(game.world:setMap('GOLDENROD_CITY',20,10,'up'));wait(120)
 F.EYE_HEIGHT=80
 for _,a in ipairs({{name='north',yaw=math.pi},{name='east',yaw=math.pi/2},{name='south',yaw=0},{name='west',yaw=-math.pi/2}})do yaw=a.yaw;wait(20);shot('elevated-'..a.name)end
 -- Source-map handoffs, all four native residency depths, extreme camera
 -- height and a full interior round trip. No QA calls to W.prepare here:
 -- the renderer's normal scheduling must finish every view itself.
 F.EYE_HEIGHT=128
 local Zoom=V.require('DioramaZoom')
 chosen.cameraMode='full'
 for _,spec in ipairs({{1,1},{2,2},{4,3},{8,4},{1,1}})do
  Zoom.set(spec[1]);wait(180)
  local status=W.status()
  assert(status.ready and status.bytes<=W.MAX_BYTES,'zoom view failed '..tostring(status.error))
  assert(latestState._stadiumOpenWorldDepth==spec[2],'native zoom residency did not change')
  assert(status.key:match(':'..spec[2]..'$'),'wrong far-view depth')
  print('DEPTH_TRANSITION',spec[1],spec[2],status.bytes,status.uploads)
  shot('zoom-'..spec[1])
 end
 if os.getenv('VIEW_PREVIEW')then print('PASS_JOHTO_WORLD_PREVIEW');love.event.quit();return end
 chosen.cameraMode='third';yaw=0;F.EYE_HEIGHT=80
 for _,id in ipairs({'ROUTE_35','ROUTE_36','ECRUTEAK_CITY','ROUTE_37','GOLDENROD_CITY'})do
  assert(game.world:setMap(id,6,6,'down'));wait(180)
  local status=W.status();assert(status.ready and not status.error,'map transition '..id)
  assert(latestState.map.id==id,'wrong native map')
  print('MAP_TRANSITION',id,status.bytes,status.uploads)
  if id=='ROUTE_36'then
   V.require('DayNight').setting:setValue('night',game);wait(45);shot('distant-windows-night')
   V.require('DayNight').setting:setValue('day',game);wait(45);shot('distant-windows-day')
  end
 end
 local H=V.require('HorizonWall')
 H.setting:setValue('off',game);wait(5)
 assert(not W.status().ready and W.status().bytes==0,'scenery OFF retained a view')
 H.setting:setValue('full',game);wait(180);assert(W.status().ready,'scenery ON failed')
 local interior
 for id,d in pairs(game.world.maps)do if d.environment=='INDOOR' and id:find('ELMS_LAB',1,true)then interior=id;break end end
 interior=interior or 'ELMS_LAB'
 assert(game.world:setMap(interior,4,4,'down'));wait(180)
 assert(not W.status().ready and W.status().bytes==0,'interior retained far-view GPU resources')
 assert(game.world:setMap('NEW_BARK_TOWN',6,6,'down'));wait(180)
 assert(W.status().ready,'exterior did not restore')
 W.invalidate();wait(180);assert(W.status().ready,'context invalidation did not recover')
 print('PASS_JOHTO_WORLD_RUNTIME',bridge.frames3d,W.status().bytes,W.status().uploads)
 love.event.quit()
end
