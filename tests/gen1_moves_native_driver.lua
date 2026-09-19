return function(game)
 io.stdout:setvbuf('no');assert(os.getenv('POKEPORT_IDENTITY')=='vasc-safari-terrain-20260919')
 local U=require('tests.drivers.util');local Pipes=require('src.render.Pipelines');game:startNewGame{intro=false}
 local raw=game.update;game.update=function(self,dt)return require('src.mods.Runtime').call('core.update',raw,self,dt)end
 local e=game.mods.exports.VOXEL_ASCENDANT;for k,v in pairs(e.ascendantContent.bootTimings or{})do print('CONTENT_BOOT',k,v)end;e.ascendantContent.onboardingShown=true;e.ascendantContent.promptDisabled=true
 local function find(fn,name,seen)
 if type(fn)~='function' then return end;seen=seen or {};if seen[fn]then return end;seen[fn]=true
 for i=1,200 do local k,v=debug.getupvalue(fn,i);if not k then break end;if k==name then return v end end
 for i=1,200 do local k,v=debug.getupvalue(fn,i);if not k then break end;local x=find(v,name,seen);if x then return x end end
 end
 local V=assert(find(e.lib.require('VoxelScene').render,'V'));local C=V.require('ChunkMesher');local S=V.require('VoxelScene');local State=V.require('VoxelState')
 love.window.setMode(1000,600,{vsync=1});love.window.setTitle('VASC – Videofeedback: isolierte Sichtprüfung')
 game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB=true;game.save.flags.EVENT_GOT_STARTER=true;game.save.repelSteps=999999
 Pipes.setLevel('voxel',7)
 local rendered=0;local fn=S.render;S.render=function(...)local c=fn(...);if c then rendered=rendered+1 end;return c end
 local function scene(id,x,y,n)
  print('ENTER',id);U.teleport(game,id,x,y,'down');local before=rendered
  for i=1,1800 do U.wait(1);if rendered>before+60 then break end end
  local st=V.require('Structures').forMap(game.overworld.map);local count=0;for _,b in ipairs(st.buildingStamps or{})do count=count+#(b.quads or b.template or{})end
  print('SCENE',id,State.ready,Pipes.eligible('voxel'),rendered-before,#(st.buildingStamps or{}),count,#(st.objectQuads or{}))
  love.graphics.captureScreenshot('rc15-'..n..'.png');U.wait(2)
  assert(Pipes.eligible('voxel') and rendered>before+30,'pipeline failed at '..id)
 end


 V.require('Weather').setting:setValue('clear',game);V.require('DayNight').setting:setValue('day',game)
 game.save.party={};require('src.world.OverworldController').checkTrainerSight=function()end
 local F=V.require('FirstPerson');local R=V.require('CurrentRoom');R.setting:setValue(true,game)


 local function shot(name)
  assert(U.shot(game,os.getenv('SHOT_DIR')..'/'..name..'.png'))
 end




 local Pokemon=require('src.pokemon.Pokemon');local Battle=require('src.battle.BattleState')
 game.save.party={Pokemon.new(game.data,'PIKACHU',71)}
 scene('ROUTE_1',8,10,'battle-start');Pipes.setLevel('voxel',3)
 local OB=V.require('OverworldBattle');OB.setting:setValue(true,game)
 local D=V.require('Diagnostics');local write=D.write
 D.write=function(event,data,...)
  if tostring(event):find('battle',1,true) and type(data)=='table'then local fields={};for k,v in pairs(data)do if type(v)~='table'then fields[#fields+1]=tostring(k)..'='..tostring(v)end end;print('DIAG',event,table.concat(fields,';'))end
  return write(event,data,...)
 end
 local BS=V.require('BattleScene');local render=BS.render;local drawn,declines=0,{}
 BS.render=function(...)
  local result=render(...);if result then drawn=drawn+1 else local why=tostring(BS.lastDeclineReason);if not declines[why]then print('FIRST_DECLINE',why)end;declines[why]=(declines[why]or 0)+1 end
  return result
 end
 local Cam=V.require('BattleCam');local lastShot;local snapshot=BS.cameraSafetyShot
 BS.cameraSafetyShot=function(...)local shot=snapshot(...);lastShot=shot;return shot end
 local probes=0
 Cam.setScreenSafetyEvaluator(function(b,a,g,c,context)
  local ok,why=OB.battleHudCameraSafe(b,a,g,c,context)
  if b.phase=='moveSelect' and probes<100 then
   probes=probes+1;local v=lastShot and lastShot.actorVisuals and lastShot.actorVisuals.playerHero
   print('PROBE',context and context.phase,ok,why,math.deg(c.fov),table.concat(c.eye,','),table.concat(c.focus,','),v and v.hull and table.concat(v.hull,',') or '?')
  end
  return ok,why
 end)
 local ow=game.overworld;local b=Battle.newWild(game,'ZUBAT',51)
 b.onFinish=function(result)ow:afterBattle(result,b)end;ow:pushBattle(b)
 for i=1,1800 do U.wait(1);if game.stack:top()==b and b.phase=='menu'then break end;if i%15==0 then U.tap(game,'a')end end
 assert(game.stack:top()==b and b.phase=='menu','battle intro stalled')
 U.wait(120);shot('Before-move');print('PROVIDER_BEFORE_MOVE',e.battleLifecycle.current().provider,drawn);U.tap(game,'a');U.wait(30);assert(b.phase=='moveSelect','fight did not open move selection')
 for _,size in ipairs({{1000,600,'landscape'},{480,900,'portrait'}})do
  love.window.setMode(size[1],size[2],{vsync=1});U.wait(90)
  local before=drawn;local started=love.timer.getTime();local frames=0
  while love.timer.getTime()-started<12 do
   U.wait(1);frames=frames+1
   assert(b.phase=='moveSelect' and game.stack:top()==b,'move selection closed without input')
   local life=e.battleLifecycle.current();if not life or life.provider~='MAP'then shot('Failure');for k,v in pairs(declines)do print('DECLINE_COUNT',k,v)end end;assert(life and life.provider=='MAP','MAP retired: '..tostring(life and life.provider))
  end
  assert(drawn>before+120,'3D renderer stopped presenting')
  shot('Moves-'..size[3]..'-12s');print('PASS_GEN1_MOVES_HELD',size[3],frames,drawn-before,#b.player.curMoves)
  local initial=b.moveIndex;U.tap(game,'down');assert(b.moveIndex~=initial,'move navigation not working');U.tap(game,'up');U.wait(4)
 end
 U.tap(game,'b');U.wait(30);assert(b.phase=='menu','B did not return to fight menu')
 for k,v in pairs(declines)do print('SCENE_DECLINE',k,v)end
 print('PASS_GEN1_NATIVE_MOVE_SELECTION');love.event.quit()
end
