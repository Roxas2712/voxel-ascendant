return function(game)
 io.stdout:setvbuf('no')
 assert(os.getenv('POKEPORT_IDENTITY')=='vasc-gen2-light-preview-20260919' or os.getenv('POKEPORT_IDENTITY')=='vasc-gen2-regression-20260919-gold-matrix')
 local function wait(n)for _=1,n do coroutine.yield()end end
 local ex=assert(game.mods.exports.VOXEL_ASCENDANT);local bridge
 for i=1,50 do local n,v=debug.getupvalue(ex.voxelStatus,i);if n=='GoldVoxelBridge'then bridge=v;break end end
 assert(bridge and ex.active and ex.rendererInstalled)
 if ex.ascendantContent then ex.ascendantContent.promptDisabled=true end
 local V=bridge.lib;local G=V.require('Voxel3D');local L=V.require('LocalLights');local S=V.require('VoxelScene');local D=V.require('DayNight')
 assert(L.supported and L.enabled(),'production lighting unavailable')
 local chosen={voxelDiskCache=false,voxel3d=true,weather='clear',enabled=false,town_pokemon=false,openWorld=true,cameraMode='third'}
 local opts=V.mod.options;local get=opts.get
 opts.get=function(self,k,...)if chosen[k]~=nil then return chosen[k]end;return get(self,k,...)end
 local cardLightSends=0;local sendCard=G.sendCardLighting;G.sendCardLighting=function(...)cardLightSends=cardLightSends+1;return sendCard(...)end
 local state;local lastRenderMs=0;local render=S.render
 S.render=function(s,...)state=s;V.require('FirstPerson').yaw=math.pi;V.require('FirstPerson').pitch=.13;local t=love.timer.getTime();local a,b,c=render(s,...);lastRenderMs=(love.timer.getTime()-t)*1000;return a,b,c end
 love.window.setMode(1100,700,{vsync=1})
 local save=require('src.core.gen2.Save').newGame({playerName='LIGHTQA'})
 game.save=save;game:adoptSave(save);game.world.save=save;require('src.mods.Runtime').emit('save.created',{game=game,save=save});game:continueGame(save);wait(120)
 game.world.checkTrainerBattle=function()return false end;game.world.trySceneScript=function()return false end;game.world.tryCoordScript=function()return false end;game.world.tryWildEncounter=function()return false end
 local output=assert(os.getenv('VIEW_OUTPUT'))
 local function shot(name)
  love.graphics.captureScreenshot(function(data)local f=assert(io.open(output..'/'..name..'.png','wb'));f:write(data:encode('png'):getString());f:close();data:release()end);wait(3)
 end
 local plain=assert(G.shader(false,false));assert(not plain:hasUniform('localLightCount'),'OFF shader includes light loops')
 for _,id in ipairs({'GOLDENROD_CITY','NEW_BARK_TOWN','ECRUTEAK_CITY'})do
  assert(game.world:setMap(id,10,8,'up'));wait(240)
  for _,hour in ipairs({'day','night'})do
   D.setting:setValue(hour,game);L.setting:setValue(true,game);wait(60)
   assert(not L.failure,tostring(L.failure));assert(L.current().map==state.map,'stale map lighting')
   assert(L.current().sky,'missing directional light')
   if hour=='night'then assert(#L.current().lights>0,'no native window emitters '..id)end
   assert(#L.current().lights<=8 and #L.current().blockers<=8)
   print('PRODUCTION_LIGHTING',id,hour,#L.current().lights,#L.current().blockers)
   shot(id..'-'..hour..'-on')
   L.setting:setValue(false,game);wait(10)
   assert(not L.enabled() and #L.current().lights==0 and not G.localLightsActive,'OFF retained lights')
   assert(game.save.options.modOptions[V.mod.id].localLights==false,'OFF not persisted')
   L.setting.index=nil;assert(not L.setting:get(),'OFF did not survive setting reload')
   shot(id..'-'..hour..'-off')
  end
 end
 L.setting:setValue(true,game);assert(game.world:setMap('ELMS_LAB',4,4,'down'));wait(180)
 assert(#L.current().lights==0 and not L.current().sky,'interior inherited exterior lamps')
 assert(game.world:setMap('NEW_BARK_TOWN',6,6,'down'));wait(240)
 assert(not L.failure and #L.current().lights>0,'exterior lighting did not return')
 assert(cardLightSends>0,'HD actors did not use production light shader');print('HD_CARD_LIGHTING',cardLightSends)
 -- Compile the actual mobile shader and visibility programs with phone caps.
 G.invalidate();L.mobile=true;L.MAX_LIGHTS=4;L.MAX_BLOCKERS=4;L.MAX_PORTALS=2
 wait(60);assert(not L.failure,tostring(L.failure));assert(#L.current().lights<=4 and #L.current().blockers<=4)
 shot('NEW_BARK_TOWN-night-mobile-budget')
 -- Failure must preserve the baseline 3D program and recover explicitly.
 L.fail('QA forced shader failure');wait(10)
 assert(G.shader(false,true)==plain and not G.localLightsActive,'fallback lost baseline 3D')
 L.setting:setValue(false,game);L.setting:setValue(true,game);wait(60)
 assert(not L.failure and G.localLightsActive,'toggle did not recover lighting')
 love.window.setVSync(0)
 local function bench(label)
  for _,on in ipairs({false,true})do
   L.setting:setValue(on,game);wait(90)
   local dt,cpu={},{};local total,sum=0,0
   for i=1,240 do wait(1);local d=love.timer.getDelta()*1000;dt[i]=d;cpu[i]=lastRenderMs;total=total+d;sum=sum+lastRenderMs end
   table.sort(dt);table.sort(cpu)
   print('LIGHT_BENCH',label,on,'fps',240000/total,'frame_ms',total/240,'p95_ms',dt[228],'render_ms',sum/240,'render_p95',cpu[228])
  end
 end
 bench('phone-budget')
 G.invalidate();L.mobile=false;L.MAX_LIGHTS=8;L.MAX_BLOCKERS=8;L.MAX_PORTALS=4;wait(60)
 bench('desktop')
 assert(game.world:setMap('GOLDENROD_CITY',10,8,'up'));wait(240);bench('Goldenrod-desktop')
 G.invalidate();L.mobile=true;L.MAX_LIGHTS=4;L.MAX_BLOCKERS=4;L.MAX_PORTALS=2;wait(60);bench('Goldenrod-phone-budget')
 print('PASS_GEN2_DYNAMIC_LIGHT_PRODUCTION',bridge.frames3d,#L.current().lights)
 love.event.quit()
end
