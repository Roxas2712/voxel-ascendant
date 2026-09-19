return function(game)
 io.stdout:setvbuf('no')
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
 local V=bridge.lib
 local P=V.require('WorldPlacement');local H=V.require('HorizonWall');local Buildings=V.require('Buildings')
 local stamp=Buildings.stamp
 Buildings.stamp=function(S,map,quads,tx,ty,bw,bh,template)
  if template and tostring(template.id):match('tower') or template and tostring(template.id):match('lighthouse')then
   print('LANDMARK',map.id,template.id,tx,ty,bw,bh,#quads)
  end
  return stamp(S,map,quads,tx,ty,bw,bh,template)
 end
 local build=Buildings.build;local dumped={}
 Buildings.build=function(S,map,...)
  if not dumped[map.id]and map.id=='OLIVINE_CITY'then
   dumped[map.id]=true
   for ty=28,55 do local row={};for tx=56,63 do row[#row+1]=tostring(S.tileAt[(ty+64)*4096+tx+64])end;print('LIGHTHOUSE_ROW',ty,table.concat(row,','))end
   print('TILESET',map.tileset.id,map.def.tileset)
  end
  return build(S,map,...)
 end
 local portrait=os.getenv('BENCH_PORTRAIT')=='1'
 love.window.setMode(portrait and 480 or 1100,portrait and 900 or 700,{vsync=1})
 local save=require('src.core.gen2.Save').newGame({playerName='LOADQA'})
 save.party={require('src.battle.gen2.Mon').new(game.data,'TOTODILE',12)}
 game.save=save;game:adoptSave(save);game.world.save=save
 require('src.mods.Runtime').emit('save.created',{game=game,save=save})
 local function measure(name,action)
  local before=bridge.frames3d or 0
  local t=love.timer.getTime();action()
  local actionDone=love.timer.getTime();local map=game.world.map
  local frames=0
  repeat
   wait(1);frames=frames+1
   local f=bridge.lastPresentedFrame
   if f and f.map==map and f.mapId==map.id and (bridge.frames3d or 0)>before then break end
   assert(love.timer.getTime()-t<30,'world did not render: '..name)
  until false
  local first=love.timer.getTime()-t
  if name=='startup_world'then print('BENCH_FIRST_WORLD')end
  local intervals={};local prev=love.timer.getTime()
  for _=1,30 do wait(1);local now=love.timer.getTime();intervals[#intervals+1]=now-prev;prev=now end
  table.sort(intervals)
  print('BENCH_MAP',name,map.id,string.format('%.6f',first),string.format('%.6f',actionDone-t),frames,
   string.format('%.6f',intervals[15]),string.format('%.6f',intervals[30]),bridge.openWorldMaps or 0,
   tostring(bridge.neighborDirectComplete),tostring(bridge.neighborWarmupPending))
 end
 measure('startup_world',function()game:continueGame(save)end)
 for _,id in ipairs({'NEW_BARK_TOWN','GOLDENROD_CITY','ECRUTEAK_CITY','OLIVINE_CITY','CIANWOOD_CITY','BLACKTHORN_CITY','MAHOGANY_TOWN','LAKE_OF_RAGE','VIOLET_CITY','AZALEA_TOWN'})do
  local d=game.world.maps[id];local pos=P.position(id,game.world.maps)
  print('PLACEMENT',id,d and d.width,d and d.height,pos and pos.x,pos and pos.y,pos and pos.anchor)
  if d then for _,edge in ipairs({'north','south','east','west'})do local kind=H.panelProfile({id=id,def=d},edge,0);print('EDGE',id,edge,kind)end end
 end
 game.world.checkTrainerBattle=function()return false end;game.world.trySceneScript=function()return false end
 game.world.tryCoordScript=function()return false end;game.world.tryWildEncounter=function()return false end
 V.require('DayNight').setting:setValue('day',game)
 for _,id in ipairs({'OLIVINE_CITY'})do
  measure(id,function()assert(game.world:setMap(id,28,29,'up'))end)
  V.require('DioramaZoom').set(2.2);wait(150)
  local shot=os.getenv('AUDIT_OUTPUT')..'/'..id..'.png'
  love.graphics.captureScreenshot(function(data)local f=assert(io.open(shot,'wb'));f:write(data:encode('png'):getString());f:close();data:release()end);wait(3)
 end
 local d=game.world.maps.OLIVINE_CITY;local wanted
 for _,w in ipairs(d.warps or{})do if w.x==29 and w.y==27 then wanted=w.destMap end end
 assert(wanted,'native lighthouse door warp missing')
 assert(game.world:setMap('OLIVINE_CITY',29,29,'up'));wait(90)
 assert(game.world:movePlayer('up')=='moved','first doorway approach blocked');wait(30)
 assert(game.world:movePlayer('up')=='moved','lighthouse doorway blocked')
 for _=1,240 do wait(1);if game.world.map.id==wanted then break end end
 assert(game.world.map.id==wanted,'lighthouse warp did not arrive')
 print('PASS_NATIVE_LIGHTHOUSE_ENTRY',wanted)
 assert((bridge.framesFailed or 0)==0,'renderer failure')

 print('BENCH_PASS',ex.version)
 love.event.quit()
end
