return function(game)
 love.window.hasFocus=function()return true end;love.window.isVisible=function()return true end
 io.stdout:setvbuf('no');local U=require('tests.drivers.util');game:startNewGame{intro=false}
 local e=assert(game.mods.exports.VOXEL_ASCENDANT);e.setupCard.suspended=true;e.ascendantContent.promptDisabled=true;e.ascendantContent.onboardingShown=true
 local function find(fn,name,seen)
  if type(fn)~='function'then return end;seen=seen or {};if seen[fn]then return end;seen[fn]=true
  for i=1,200 do local k,v=debug.getupvalue(fn,i);if not k then break end;if k==name then return v end end
  for i=1,200 do local k,v=debug.getupvalue(fn,i);if not k then break end;local x=find(v,name,seen);if x then return x end end
 end
 local scene=e.lib.require('VoxelScene');local V=assert(find(scene.render,'V'))
 local G=V.require('Voxel3D');local W=V.require('Weather');local B=V.require('SpringBlossom')
 local H=V.require('OutdoorHorizon');local horizonBloom=0;local build=H.build
 H.build=function(...)local parts=build(...);for _,part in ipairs(parts or {})do if part.springBlossom then horizonBloom=horizonBloom+1 end end;return parts end
 H.setting:setValue('voxel',game);V.require('HorizonWall').setting:setValue('full',game)
 local clock=240;W.update=function(_,map)W.clock=clock;return 'clear'end;W.mode=function()return 'clear'end
 W.setting:setValue('auto',game);V.require('DayNight').setting:setValue('day',game)
 local frame=0;local original=scene.render
 scene.render=function(...)local result=original(...);if result then frame=frame+1 end;return result end
 game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB=true;game.save.flags.EVENT_GOT_STARTER=true;game.save.repelSteps=999999
 game.save.party={require('src.pokemon.Pokemon').new(game.data,'PIKACHU',5)}
 local mobile=os.getenv('VASC_QA_OS')=='iOS'
 love.window.setMode(mobile and 540 or 1000,mobile and 960 or 760,{resizable=true,vsync=1});require('src.core.TouchControls'):setPreview(mobile);require('src.render.Pipelines').setLevel('voxel',3)
 U.teleport(game,'ROUTE_1',10,25,'up');U.wait(180)
 for _,case in ipairs{{240,'spring'},{1200,'summer'},{240,'spring-again'}}do
  clock=case[1];W.clock=clock
  local before=frame;local start=love.timer.getTime()
  for i=1,600 do U.wait(1);if frame>=before+60 then break end end
  print('FRAMES',case[2],frame-before,'seconds',love.timer.getTime()-start,'sources',B.count,'bloom',G._seasonUniform and G._seasonUniform[3])
  assert(frame>=before+60,'fresh world frames required')
  if case[2]=='summer'then assert(B.amount==0 and G._seasonUniform[3]==0)else assert(G._seasonUniform[3]==1 and B.count>0,'missing cherry sources')end
  assert(U.shot(game,os.getenv('SPRING_QA')..'/'..(mobile and 'ios-' or '')..case[2]..'.png'))
 end
 for i=1,900 do if horizonBloom>0 then break end;U.wait(1)end
 print('HORIZON_BLOOM_BATCHES',horizonBloom,'mode',H.setting:get(),V.require('HorizonWall').setting:get());assert(horizonBloom>0,'missing skyline blossoms')
 print('SPRING_NATIVE_PASS');love.event.quit()
end
