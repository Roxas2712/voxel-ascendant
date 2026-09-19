return function(game)
 local function wait(n)for i=1,n do coroutine.yield()end end
 local function untilFrame(bridge,id,mode)
  local before=bridge.frames3d or 0;local t=love.timer.getTime()
  repeat wait(1);local f=bridge.lastPresentedFrame
   if f and f.mapId==id and f.cameraMode==mode and(bridge.frames3d or 0)>before+6 then return end
  until love.timer.getTime()-t>25
  error('no rendered '..id..' '..mode..' '..tostring(bridge.lastError))
 end
 wait(10);local ex=assert(game.mods.exports.VOXEL_ASCENDANT)
 assert(ex.active and ex.rendererInstalled and ex.gen2SegmentCards.ok)
 local bridge;for i=1,50 do local n,v=debug.getupvalue(ex.voxelStatus,i);if n=='GoldVoxelBridge'then bridge=v;break end end
 assert(bridge)
 local opts=bridge.lib.mod.options;local original=opts.get
 local chosen={voxel3d=true,daytime='day',weather='clear',enabled=false,town_pokemon=false,cameraMode='full',deviceProfile='auto'}
 opts.get=function(self,k,...)if chosen[k]~=nil then return chosen[k]end return original(self,k,...)end
 local save=require('src.core.gen2.Save').newGame({playerName='GEN2QA'});save.party={require('src.battle.gen2.Mon').new(game.data,'TOTODILE',12)}
 game.save=save;game:adoptSave(save);game.world.save=save
 require('src.mods.Runtime').emit('save.created',{game=game,save=save});game:continueGame(save)
 game.world.checkTrainerBattle=function()return false end;game.world.trySceneScript=function()return false end;game.world.tryCoordScript=function()return false end;game.world.tryWildEncounter=function()return false end

 ex.ascendantContent.promptDisabled=true

 love.window.setMode(1000,600,{vsync=1})
 for _,p in ipairs({{'ROUTE_8',8,9},{'ROUTE_17',5,19}})do
  assert(game.world:setMap(p[1],p[2],p[3],'down'));chosen.cameraMode='full';untilFrame(bridge,p[1],'full');wait(120)
  local n=0
  for _,npc in ipairs(game.world.entities or{})do if npc.def and npc.def.sprite=='SPRITE_BIKER'then
   local d=npc.sprite.def;print('RIDER_NATIVE_G2',p[1],npc.def.x,npc.def.y,d.ascendantRole,d.ascendantCharacterAction)
   assert(d.ascendantCharacterAction=='bicycle','native Gen2 NPC not riding');n=n+1
  end end
  assert(n>0,'no native riders found');game.capturePath=os.getenv('SHOT_DIR')..'/gen2-'..p[1]..'.png';wait(4)
 end
 print('PASS_NATIVE_GEN2_BIKERS');love.event.quit()
end
