return function(game)
 assert(os.getenv('POKEPORT_IDENTITY')=='vasc-window-scale-gen2-qa')
 io.stdout:setvbuf('no');love.window.hasFocus=function()return true end;love.window.isVisible=function()return true end
 local U=require('tests.drivers.util');local Mon=require('src.battle.gen2.Mon');local Save=require('src.core.gen2.Save')
 local save=Save.newGame{version='crystal',playerName='ANIMQA'};save.party={Mon.new(game.data,'VENUSAUR',40)}
 game.save=save;game:adoptSave(save);game.world.save=save;require('src.mods.Runtime').emit('save.created',{game=game,save=save});game:continueGame(save)
 local ex=assert(game.mods.exports.VOXEL_ASCENDANT);if ex.setupCard then ex.setupCard.suspended=true end;ex.ascendantContent.promptDisabled=true;ex.ascendantContent.onboardingShown=true
 local V;for i=1,30 do local k,v=debug.getupvalue(ex.dexModelPreview.draw,i);if k=='V'then V=v end end;assert(V,'private renderer owner')
 local options=assert(ex.vascMenuGen2.settingsByKey);options.voxel3d:setValue(true,game);options.battle3dWorld:setValue(true,game)
 options.pokemonModelSkin:setValue('cobblemon',game);options.stadium3dSprites:setValue(true,game)
 love.window.setMode(1100,760,{resizable=true,vsync=1});assert(game.world:setMap('NEW_BARK_TOWN',8,8,'down'));U.wait(90)
 local done=false;game.world:startBattle({wild=Mon.new(game.data,'RATTATA',3)},function()done=true end)
 local screen
 for i=1,2000 do local p=game.stack:top();if p and p.battle and p.phase=='menu'then screen=p;break end;if i%10==0 then U.tap(game,'a')end;U.wait(1)end
 assert(screen,'battle did not open');U.wait(100)
 local Stadium=V.require('Stadium');local a=assert(Stadium.stage1Actor('player'));assert(a.model and a.model.source=='cobblemon' and a.rig,'Cobblemon not active in battle')
 local dir=assert(os.getenv('MENU_QA'));assert(U.shot(game,dir..'/cobblemon-battle-idle.png'))

 local m=a.model;local x,y,z,X,Y,Z=a.rig:posedBounds();local h=(Y-y)*m.rootScale*a:worldHeight()/m.height
 assert(a.heightMeters>1.9 and a.heightMeters<2.1,'native Crystal metadata lost');assert(h>18 and h<22,'Gen2 size differs from Gen1')
 print('PASS_GEN2_SPECIES_SIZE',a.heightMeters,h);love.event.quit(0)
end
