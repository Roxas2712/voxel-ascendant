return function(game)
 assert((os.getenv('POKEPORT_IDENTITY')or''):match('^vasc%-cobblemon%-battle%-.*%-qa$'))
 io.stdout:setvbuf('no');love.window.hasFocus=function()return true end;love.window.isVisible=function()return true end
 local U=require('tests.drivers.util');game:startNewGame{intro=false}
 local ex=game.mods.exports.VOXEL_ASCENDANT;ex.setupCard.suspended=true;ex.ascendantContent.promptDisabled=true;ex.ascendantContent.onboardingShown=true
 local function find(fn,name,seen)
  if type(fn)~='function'then return end;seen=seen or {};if seen[fn]then return end;seen[fn]=true
  for i=1,100 do local k,v=debug.getupvalue(fn,i);if not k then break end;if k==name then return v end end
  for i=1,100 do local k,v=debug.getupvalue(fn,i);if not k then break end;local got=find(v,name,seen);if got then return got end end
 end
 local V=assert(find(ex.lib.require('VoxelScene').render,'V'));local O=V.require('OverworldBattle')
 O.setting:setValue(true,game);V.require('PokemonModelProvider').setting:setValue('cobblemon',game)
 local Screens=require('src.ui.Screens');local menu=Screens.push(game,'VascSettings',{section='world'})
 for _,row in ipairs(menu.items)do if row.settingKey=='voxel3d'then local owner=find(row.descriptor.step,'self_');if owner then owner:setValue(true,game)end end end;game.stack:pop()
 game.save.party={require('src.pokemon.Pokemon').new(game.data,'KOFFING',40)}
 local world=game.stack:top();world:setMap('PALLET_TOWN',8,8,'down');U.wait(40)
 local B=require('src.battle.BattleState');local screen=B.newWild(game,'PIKACHU',3);world:pushBattle(screen)
 for i=1,2000 do if screen.phase=='menu'then break end;if i%10==0 then U.tap(game,'a')end;U.wait(1)end
 U.wait(60);local Stadium=V.require('Stadium');local a=assert(Stadium.stage1Actor('player'));assert(a.model and a.model.source=='cobblemon')
 local dir=assert(os.getenv('MENU_QA'))
 for _,case in ipairs({{'TACKLE','attack_physical'},{'THUNDERBOLT','attack_special'},{'GROWL','attack_status'}})do
  a:play('idle');screen:performMove(screen.player,screen.enemy,{id=case[1],pp=20});assert(a.state=='attack' and a.anim==a.model.actions[case[2]],'Gen1 actual move hook '..case[1]);print('PASS_GEN1_MOVE_HOOK',case[1],case[2]);U.wait(5);assert(U.shot(game,dir..'/gen1-'..case[2]..'.png'));U.wait(90)
 end
 a:play('idle');assert(Stadium.hit('player','neutral') and a.anim==a.model.actions.flinch);print('PASS_GEN1_ORIGINAL_RECOIL')
 V.require('PokemonModelProvider').setting:setValue('crystal',game);U.wait(10);assert(not Stadium.showing('player'));assert(O.shot());assert(U.shot(game,dir..'/gen1-crystal-fallback.png'))
 print('PASS_COBBLEMON_GEN1_BATTLE_NATIVE');love.event.quit(0)
end
