-- Native test-only encounters; run with an isolated vasc-...-qa identity.
return function(game)
 io.stdout:setvbuf('no')
 assert((os.getenv('POKEPORT_IDENTITY')or''):match('^vasc%-.*%-qa$'))
 local out=assert(os.getenv('TERRARIUM_QA'))
 love.window.hasFocus=function()return true end;love.window.isVisible=function()return true end
 local U=require('tests.drivers.util')
 local restore=os.getenv('TERRARIUM_QA_RESTORE')=='1'
 if restore then
  local save=assert(require('src.core.SaveData').load());game:restoreSave(save,false,{freshBoot=true,continued=true})
 else game:startNewGame{intro=false}end
 local e=assert(game.mods.exports.VOXEL_ASCENDANT)
 e.setupCard.suspended=true;e.ascendantContent.promptDisabled=true;e.ascendantContent.onboardingShown=true
 local function find(fn,name,seen)
  if type(fn)~='function'then return end;seen=seen or{};if seen[fn]then return end;seen[fn]=true
  for i=1,200 do local k,v=debug.getupvalue(fn,i);if not k then break end;if k==name then return v end end
  for i=1,200 do local k,v=debug.getupvalue(fn,i);if not k then break end;local x=find(v,name,seen);if x then return x end end
 end
 local V=assert(find(e.lib.require('VoxelScene').render,'V'))
 local B=V.require('OverworldBattle');local BS=V.require('BattleScene');local service=V.require('TerarriumHost').service
 local settings=e.setupCard.new(game).settings
 settings.terarriumIdleAnimation:setValue(false,game);settings.terarriumDome:setValue('clear',game)
 local renders=0;local render=BS.render
 BS.render=function(...)local image=render(...);if image then renders=renders+1 end;return image end
 require('src.render.Pipelines').setLevel('voxel',1)
 game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB=true;game.save.flags.EVENT_GOT_STARTER=true;game.save.repelSteps=999999
 local C=V.require('BattleCam');local Control=V.require('CamControl')
 V.require('PokemonModelProvider').setting:setValue('crystal',game)
 local function same(a,b)
  for _,k in ipairs{'eye','focus','up'}do for i=1,3 do assert(math.abs(a[k][i]-b[k][i])<1e-9,k..' moved')end end
 end
 U.teleport(game,'CERULEAN_GYM',5,14,'up')
 game.save.party={require('src.pokemon.Pokemon').new(game.data,'PIKACHU',30)}
 settings.terarriumBehindRed:setValue(false,game);B.setting:setValue('terarrium',game)
 love.window.setMode(1100,760,{resizable=true,vsync=1});U.wait(15)
 local battle=require('src.battle.BattleState').newWild(game,'STARMIE',25);game.overworld:pushBattle(battle)
 for i=1,1200 do U.wait(1)
  if game.stack:top()==battle and battle.phase=='menu'and not battle.current and not battle.sendingOut then break end
  if i%15==0 then U.tap(game,'a')end
 end
 U.wait(60)
 assert(game.stack:top()==battle and battle.phase=='menu','battle menu')
 local ar=assert(B.arena());assert(ar.terarrium,'Terrarium fell back')
 local ground=BS.groundY(ar.map or game.overworld.map,ar)
 local base=C.rig(ar,ground)
 if restore then
  local f=assert(io.open(out..'/expected-zoom.txt'));local expected=assert(tonumber(f:read('*a')));f:close()
  assert(math.abs(C.terrariumZoomGoal-expected)<1e-9,'zoom not restored after process restart')
  assert(U.shot(game,out..'/restart-restored.png'))
  print('TERRARIUM_ZOOM_RESTART_PASS',expected);love.event.quit();return
 end
 assert(U.shot(game,out..'/landscape-default.png'))
 game:keypressed('q');U.wait(30)
 assert(C.rig(ar,ground).fov<base.fov,'Q did not zoom');same(base,C.rig(ar,ground))
 game:wheelmoved(0,2);U.wait(30)
 assert(U.shot(game,out..'/landscape-close.png'))
 local close=C.rig(ar,ground);local closeGoal=C.terrariumZoomGoal;same(base,close)
 game:gamepadpressed(nil,'leftstick');U.wait(30)
 assert(C.rig(ar,ground).fov>close.fov,'L3 did not zoom out');same(base,C.rig(ar,ground))
 game:gamepadpressed(nil,'rightstick');U.wait(30)
 assert(math.abs(C.terrariumZoomGoal-closeGoal)<1e-9,'R3 did not zoom back')
 game:keypressed('e');U.wait(30);assert(C.rig(ar,ground).fov>close.fov,'E did not zoom out')
 print('PASS_NATIVE_TERRARIUM_KEYS_WHEEL_PAD_FIXED_POSE')
 love.window.setMode(540,960,{resizable=true,vsync=1})
 local T=require('src.core.TouchControls');T:setPreview(true);U.wait(40)
 local before=C.terrariumZoomGoal
 local x1,x2,y=180,320,180
 assert(not T:hitTest(x1,y)and not T:hitTest(x2,y),'gesture overlaps controls')
 game:touchpressed('zoom-left',x1,y,0,0,1);game:touchpressed('zoom-right',x2,y,0,0,1)
 game:touchmoved('zoom-left',x1-40,y,-40,0,1);game:touchmoved('zoom-right',x2+40,y,40,0,1)
 game:touchreleased('zoom-left',x1-40,y,0,0,1);game:touchreleased('zoom-right',x2+40,y,0,0,1)
 U.wait(40);assert(C.terrariumZoomGoal<before,'real pointer pinch did not zoom')
 same(base,C.rig(ar,ground));assert(U.shot(game,out..'/portrait-close.png'))
 local zoom=C.terrariumZoomGoal
 settings.terarriumBehindRed:setValue(true,game);U.wait(65)
 ar=assert(B.arena());assert(ar.terarrium and ar.terarrium.cameraMode=='behind')
 assert(C.terrariumZoomGoal==zoom,'layout switch lost zoom')
 assert(U.shot(game,out..'/portrait-behind-close.png'))
 settings.terarriumBehindRed:setValue(false,game);U.wait(65)
 ar=assert(B.arena());assert(ar.terarrium and ar.terarrium.cameraMode=='side')
 local beforeRenders=renders
 U.tap(game,'a');U.wait(20);assert(C.terrariumZoomGoal==zoom,'move menu reset zoom')
 U.tap(game,'a');U.wait(100)
 assert(renders>beforeRenders+20,'attack stopped rendering')
 assert(C.terrariumZoomGoal==zoom,'attack reset zoom')
 print('PASS_NATIVE_TERRARIUM_TOUCH_PORTRAIT_LAYOUT_ATTACK')
 assert(C.flushTerrariumZoom(),'profile persistence failed')
 local expected=C.terrariumZoomGoal
 local f=assert(io.open(out..'/expected-zoom.txt','w'));f:write(string.format('%.17g',expected));f:close()
 B.finish();game:writeSave();U.wait(5)
 print('TERRARIUM_ZOOM_NATIVE_PASS');love.event.quit()
end
