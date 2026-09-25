return function(game)
 assert((os.getenv('POKEPORT_IDENTITY')or''):match('^vasc%-cobblemon%-battle%-.*%-qa$'))
 io.stdout:setvbuf('no');love.window.hasFocus=function()return true end;love.window.isVisible=function()return true end
 local U=require('tests.drivers.util');local Mon=require('src.battle.gen2.Mon');local Save=require('src.core.gen2.Save')
 local save=Save.newGame{version='crystal',playerName='ANIMQA'};save.party={Mon.new(game.data,'KOFFING',40)}
 game.save=save;game:adoptSave(save);game.world.save=save;require('src.mods.Runtime').emit('save.created',{game=game,save=save});game:continueGame(save)
 local ex=assert(game.mods.exports.VOXEL_ASCENDANT);if ex.setupCard then ex.setupCard.suspended=true end;ex.ascendantContent.promptDisabled=true;ex.ascendantContent.onboardingShown=true
 local V;for i=1,30 do local k,v=debug.getupvalue(ex.dexModelPreview.draw,i);if k=='V'then V=v end end;assert(V,'private renderer owner')
 local options=assert(ex.vascMenuGen2.settingsByKey);options.voxel3d:setValue(true,game);options.battle3dWorld:setValue(true,game)
 options.pokemonModelSkin:setValue('cobblemon',game);options.stadium3dSprites:setValue(true,game)
 love.window.setMode(1100,760,{resizable=true,vsync=1});assert(game.world:setMap('NEW_BARK_TOWN',8,8,'down'));U.wait(90)
 local done=false;game.world:startBattle({wild=Mon.new(game.data,'PIKACHU',3)},function()done=true end)
 local screen
 for i=1,2000 do local p=game.stack:top();if p and p.battle and p.phase=='menu'then screen=p;break end;if i%10==0 then U.tap(game,'a')end;U.wait(1)end
 assert(screen,'battle did not open');U.wait(100)
 local Stadium=V.require('Stadium');local a=assert(Stadium.stage1Actor('player'));assert(a.model and a.model.source=='cobblemon' and a.rig,'Cobblemon not active in battle')
 local dir=assert(os.getenv('MENU_QA'));assert(U.shot(game,dir..'/cobblemon-battle-idle.png'))
 local Bridge=V.require('BattleStadiumAnimations')
 for _,case in ipairs({{'TACKLE','attack_physical'},{'THUNDERBOLT','attack_special'},{'GROWL','attack_status'}})do
  a:play('idle');screen:animForMove(case[1],'player');assert(a.state=='attack' and a.anim==a.model.actions[case[2]],case[1]..' wrong action '..tostring(a.anim));assert(a.model.actionSources[case[2]]=='cobblemon','not original '..case[2])
  U.wait(6);assert(U.shot(game,dir..'/cobblemon-'..case[2]..'.png'));print('PASS_LIVE_CATEGORY',case[1],case[2]);U.wait(100)
 end
 -- A missing category uses VASC; do not substitute a different original.
 local actions=a.model.actions;local special=actions.attack_special;actions.attack_special=nil;a:play('idle');screen:animForMove('THUNDERBOLT','player');assert(a.anim==actions.attack_default and a.model.actionSources.attack_default=='vasc');actions.attack_special=special
 U.wait(5);assert(U.shot(game,dir..'/cobblemon-missing-action-fallback.png'));U.wait(100)
 a:play('idle');assert(Stadium.hit('player','neutral'));assert(a.anim==actions.flinch and a.model.actionSources.flinch=='cobblemon');U.wait(4);assert(U.shot(game,dir..'/cobblemon-original-recoil.png'));U.wait(100)
 a:play('idle');local hp=screen:activeMon('player').hp;Stadium.updateGen2(0,screen);screen:activeMon('player').hp=hp-1;Stadium.updateGen2(0,screen);assert(a.anim==actions.flinch and not a._stage1Recoil,'HP hit must prefer skeletal recoil');screen:activeMon('player').hp=hp
 print('PASS_LIVE_RECOIL_AND_MISSING_ACTION')
 -- Actual live source switch retires the Cobblemon actor and keeps the battle.
 assert(options.pokemonModelSkin:setValue('crystal',game)=='crystal');U.wait(60)
 assert(not Stadium.showing('player'),'Crystal still covered by Cobblemon');assert(ex.lib.require('OverworldBattle').shot(),'Crystal battle presentation lost');assert(U.shot(game,dir..'/crystal-after-cobblemon.png'))
 local runner=screen:animForMove('THUNDERBOLT','player');assert(runner,'Crystal move effect renderer absent');print('PASS_LIVE_CRYSTAL_FALLBACK')
 assert(options.pokemonModelSkin:setValue('cobblemon',game)=='cobblemon');U.wait(60);assert(Stadium.showing('player') and Stadium.stage1Actor('player').model.source=='cobblemon','switch back lost original actor');print('PASS_LIVE_COBBLEMON_RETURN')
 assert(screen:chooseMenu('run'));for i=1,1500 do if done then break end;if i%10==0 then U.tap(game,'a')end;U.wait(1)end;assert(done,'battle did not close')
 print('PASS_COBBLEMON_BATTLE_NATIVE');love.event.quit(0)
end
