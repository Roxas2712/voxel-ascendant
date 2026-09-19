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
 local chosen={voxel3d=true,daytime='day',weather='clear',sceneResolution='balanced',enabled=false,town_pokemon=false,cameraMode='full',deviceProfile='auto'}
 opts.get=function(self,k,...)if chosen[k]~=nil then return chosen[k]end return original(self,k,...)end
 local save=require('src.core.gen2.Save').newGame({playerName='GEN2QA'});save.party={require('src.battle.gen2.Mon').new(game.data,'TOTODILE',12)}
 game.save=save;game:adoptSave(save);game.world.save=save
 require('src.mods.Runtime').emit('save.created',{game=game,save=save});game:continueGame(save)
 game.world.checkTrainerBattle=function()return false end;game.world.trySceneScript=function()return false end;game.world.tryCoordScript=function()return false end;game.world.tryWildEncounter=function()return false end

 if ex.ascendantContent then ex.ascendantContent.promptDisabled=true end
 love.window.setMode(1920,1080,{resizable=true,vsync=0})
 assert(game.world:setMap('ROUTE_29',15,7,'down'));chosen.cameraMode='full';bridge.lib.controlsHost.write(game,'battle3dWorld',true);chosen.partyFollower=true
 untilFrame(bridge,'ROUTE_29','full');wait(90)
 wait(240)


 local beforeFind=bridge.lib.mod.find
 local Assets=require('src.render.Assets')
 local states={};local seenModes={};local advanceCalls=0;local fail=false
 local api={}
 api.voxelPresentationAnimation=function(species,mon,mode,ctx)
  assert(mon~=save.party[1],'provider must receive isolated player mon')
  assert(ctx.data==game.data and(mode=='MAP'or mode=='DISK'or mode=='ARENA'))
  local def=game.data.pokemon[species];local data=assert(def.anim,'authored Crystal front frames')
  local sheet=Assets.image(data.sheet);local size=data.tiles*8
  local sw,sh=sheet:getDimensions();assert(sh>=size*2,'two authored frames required')
  local images={};local g=love.graphics
  for i=0,1 do
   local c=g.newCanvas(size*2,size*2,{dpiscale=1});g.push('all');g.setCanvas(c);g.clear(0,0,0,0);g.origin();g.setColor(1,1,1,1)
   g.draw(sheet,g.newQuad(0,i*size,size,size,sw,sh),0,0,0,2,2);g.pop();images[i+1]=c
  end
  local state={side='front',image=images[1],frames=images,frame=1,elapsed=0,trueColor=false,path='qa/'..species,mon=mon}
  states[#states+1]=state;seenModes[mode]=true;return state
 end
 api.advancePresentation=function(state,dt)
  advanceCalls=advanceCalls+1;if fail then error('QA provider failure')end
  state.elapsed=state.elapsed+dt
  if state.elapsed>.15 then state.elapsed=0;state.frame=state.frame%2+1;state.image=state.frames[state.frame]end
  return state.image
 end
 bridge.lib.mod.find=function(a,b)local id=b or a;if id=='kanto_ascendant'then return {exports={crystalAnimation=api}}end;return beforeFind(a,b)end
 assert(game.world:startBattle({wild=require('src.battle.gen2.Mon').new(game.data,'PIDGEY',3)}))
 for i=1,180 do wait(12);local b=game.stack:top();if b and b.screenId=='Gen2BattleState'and b.phase=='menu'then break end;game.input:sourcePress('a','qa');game.input:sourceRelease('a','qa')end
 wait(90);local b=game.stack:top();assert(b.phase=='menu');local ow=bridge.lib.require('OverworldBattle')
 assert(ow.shot(),'3D battle retained');assert(#states>=2 and advanceCalls>10,'both front presentations advance')
 local originalPic=b.pic;local originalRunner=b.frontAnim;local rear=b:pic(b.battle.player,true)
 local function pixelHash(tex)local d=tex.canvas:newImageData();local h=love.data.hash('sha256',d:getString());d:release();return h end
 local previous=ow.textures(b);local hashes={player=pixelHash(previous.player),enemy=pixelHash(previous.enemy)};local changed={}
 for i=1,45 do
  wait(1);local textures=ow.textures(b)
  for _,side in ipairs({'player','enemy'})do
   assert(textures[side].vascReferenceExtent>0);if pixelHash(textures[side])~=hashes[side]then changed[side]=true end
  end
 end
 assert(changed.player and changed.enemy,'both captured Pokemon visibly change frames')
 assert(b.pic==originalPic and b.frontAnim==originalRunner and b:pic(b.battle.player,true)==rear,'native rear and entrance runner retained')

 local menu=ex.quickMenu
 for i=1,2 do
  game:keypressed('f3');local index
  for n,row in ipairs(menu.current(game).rows)do if row.id=='battle3dWorld'then index=n end end
  assert(index);menu.activate(game,index);menu.close(game);wait(150);assert(ow.shot())
 end
 assert(seenModes.MAP and seenModes.ARENA and seenModes.DISK,'all three front animation surfaces connected')
 fail=true;wait(30);assert(ow.shot(),'provider failure preserves scene');assert(b.pic==originalPic)
 bridge.lib.mod.find=beforeFind
 print('QA_ANIMATED_GEN2_FRONTS_PASS: two authored Crystal frames, both sides, independent mon, oversize fitting, pixel changes, native rear preserved, provider failure contained')
 love.event.quit()
end
