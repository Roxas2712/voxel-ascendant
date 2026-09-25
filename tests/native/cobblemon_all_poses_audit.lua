return function(game)
 io.stdout:setvbuf('no');assert((os.getenv('POKEPORT_IDENTITY')or''):match('^vasc%-.*%-qa$'))
 love.window.hasFocus=function()return true end;love.window.isVisible=function()return true end
 local U=require('tests.drivers.util');local Screens=require('src.ui.Screens');local gen2=os.getenv('POKEPORT_VERSION')=='crystal'
 if gen2 then
  local save=require('src.core.gen2.Save').newGame{version='crystal',playerName='MENUQA'}
  game.save=save;game:adoptSave(save);game.world.save=save;require('src.mods.Runtime').emit('save.created',{game=game,save=save});game:continueGame(save)
 else game:startNewGame{intro=false}end
 local e=assert(game.mods.exports.VOXEL_ASCENDANT);if e.setupCard then e.setupCard.suspended=true end
 local content=assert(e.ascendantContent);content.promptDisabled=true;content.onboardingShown=true
 local out=assert(os.getenv('MENU_QA'));U.wait(10)
 local floor=#game.stack.states;local function clear()while #game.stack.states>floor do game.stack:pop()end end

 local function selectSource(value,key)
  key=key or 'modernDexSpriteSource'
  local menu=Screens.push(game,'VascSettings',{section=gen2 and 'skins' or key=='pokedexStyle' and 'skins' or 'pokemon'});menu.showFirstGuide=function()return false end
  local row;for _,r in ipairs(menu.items)do if r.settingKey==key then row=r;break end end;assert(row,'Dex source missing')
  local owner;for i=1,20 do local name,value=debug.getupvalue(row.descriptor.step,i);if name=='self_'then owner=value;break end end
  assert(owner,'setting owner missing');assert(owner:setValue(value,game,true)==value,'Dex source rejected '..value);game.stack:pop()

 end
 selectSource('modern','pokedexStyle')

 selectSource('cobblemon');love.window.setMode(1100,760,{resizable=true,vsync=1})
 local count=0;local sources={cobblemon=0,vasc=0}
 for _,species in ipairs({'SQUIRTLE','PIKACHU','VULPIX','PIDGEOT','MAGIKARP','DITTO','UNOWN','ONIX','LUGIA','RAYQUAZA'})do
  if game.data.pokemon[species]then
   local entry=Screens.push(game,'DexEntryMenu',{species=species,forceOwned=true});U.wait(3)
   assert(entry.__vascDexSource=='cobblemon',species..' model unavailable')
   local a=assert(entry._vascDexModel.actor);local model=a.model
   for _,action in ipairs({'idle','battle','walk','entrance','attack_default','attack_physical','attack_special','attack_status','flinch','faint'})do
    local index=assert(model.actions[action],species..' missing '..action);local state=action=='faint' and 'faint' or action=='flinch' and 'hit' or action=='entrance' and 'entrance' or action:match('^attack') and 'attack' or 'idle'
    assert(a:play(state,index));a.time=model.anims[index].seconds*.35
    U.wait(2);assert(entry.__vascDexSource=='cobblemon' and not entry._vascDexModel.error,species..'/'..action..' render fallback')
    assert(U.shot(game,out..'/'..species..'-'..action..'.png'))
    sources[model.actionSources[action]]=sources[model.actionSources[action]]+1;count=count+1
   end
   print('PASS_POSE_SET',species,model.motionProfile.kind);game.stack:pop();assert(not entry._vascDexModel,'preview leak')
  end
 end
 print('PASS_ALL_POSES_NATIVE',count,sources.cobblemon,sources.vasc);love.event.quit(0)
end
