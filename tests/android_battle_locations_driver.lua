return function(game)
 io.stdout:setvbuf('no');love.window.hasFocus=function()return true end;love.window.isVisible=function()return true end
 local U=require('tests.drivers.util');game:startNewGame{intro=false}
 local e=assert(game.mods.exports.VOXEL_ASCENDANT);e.setupCard.suspended=true;e.ascendantContent.promptDisabled=true;e.ascendantContent.onboardingShown=true
 local function find(fn,name,seen)
  if type(fn)~='function'then return end;seen=seen or {};if seen[fn]then return end;seen[fn]=true
  for i=1,200 do local k,v=debug.getupvalue(fn,i);if not k then break end;if k==name then return v end end
  for i=1,200 do local k,v=debug.getupvalue(fn,i);if not k then break end;local x=find(v,name,seen);if x then return x end end
 end
 local V=assert(find(e.lib.require('VoxelScene').render,'V'));local B=V.require('OverworldBattle');local BS=V.require('BattleScene')
 local settings=e.setupCard.new(game).settings;assert(settings.terarriumDome);settings.terarriumDome:setValue('clear',game)
 local render=BS.render;local counts={};local last;local reasons={};local caseName
 BS.render=function(state,arena,...)
  local ok,shot=pcall(render,state,arena,...)
  local mode=arena.terarrium and 'TERRARIUM' or arena.presentationMode
  if not ok then print('RENDER_ERROR',caseName,mode,shot);error(shot,0)end
  if shot then counts[mode]=(counts[mode]or 0)+1;last=mode
  else local reason=tostring(BS.lastDeclineReason);if not reasons[reason]then reasons[reason]=true;print('DECLINE',caseName,mode,reason)end end
  return shot
 end
 local D=V.require('Diagnostics');local dw=D.write
 D.write=function(event,fields)if event=='battle-scene-error' or event=='battle-native-latch' or event=='terrarium-dome-error' then print('DIAG',caseName,event,fields.reason)end;return dw(event,fields)end
 require('src.render.Pipelines').setLevel('voxel',3)
 game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB=true;game.save.flags.EVENT_GOT_STARTER=true;game.save.repelSteps=999999
 local failures=0
 for _,place in ipairs{{'ROUTE_2',7,6,'WEEDLE',6},{'MT_MOON_1F',14,31,'GEODUDE',10},{'KA_MOLTRES_VOLCANO_BASE',13,8,'GEODUDE',10}}do
  for _,mode in ipairs{'flatB','terarrium'}do
   B.finish();U.teleport(game,place[1],place[2],place[3],'down')
   local portrait=place[1]=='ROUTE_2'
   love.window.setMode(portrait and 540 or 1170,portrait and 960 or 540,{resizable=true,vsync=1});require('src.core.TouchControls'):setPreview(true)
   game.save.party={require('src.pokemon.Pokemon').new(game.data,'PIDGEOT',14)}
   B.setting:setValue(mode,game);U.wait(90)
   counts={};reasons={};last=nil;caseName=place[1]..'-'..mode
   local battle=require('src.battle.BattleState').newWild(game,place[4],place[5]);game.overworld:pushBattle(battle)
   for i=1,1000 do
    U.wait(1)
    if game.stack:top()==battle and battle.phase=='menu' and not battle.current and not battle.sendingOut then break end
    if i%15==0 then U.tap(game,'a')end
   end
   local before=counts[mode=='terarrium' and 'TERRARIUM' or 'DISCS']or 0
   U.wait(90)
   local expected=mode=='terarrium' and 'TERRARIUM' or 'DISCS';local fresh=(counts[expected]or 0)-before
   local pass=last==expected and fresh>=30 and battle.phase=='menu'
   print('CASE',caseName,pass and 'PASS' or 'FAIL','actual',last,'fresh',fresh,'phase',battle.phase,'reason',BS.lastDeclineReason)
   if not pass then failures=failures+1 end
   assert(U.shot(game,os.getenv('BATTLE_QA')..'/'..caseName..'.png'))
  end
 end
 print('BATTLE_FAILURES',failures);assert(failures==0,'reported battle locations still fail');print('ANDROID_BATTLE_PASS');love.event.quit()
end
