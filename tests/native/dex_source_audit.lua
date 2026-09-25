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
 game.save.pokedex=game.save.pokedex or {};game.save.pokedex.seen=game.save.pokedex.seen or {};game.save.pokedex.owned=game.save.pokedex.owned or {}
 for _,species in ipairs({'BULBASAUR','CHARIZARD','PIKACHU','CHIKORITA','LUGIA','RAYQUAZA'})do game.save.pokedex.seen[species]=true;game.save.pokedex.owned[species]=true end
 for _,source in ipairs(gen2 and {'crystal','active','game','cobblemon'} or {'kasc_crystal','active','game','hd','cobblemon'})do
  selectSource(source)
  for _,size in ipairs({{1100,760,'landscape'},{540,960,'portrait'}})do
   love.window.setMode(size[1],size[2],{resizable=true,vsync=1})
   local entry=Screens.push(game,'DexEntryMenu',{species='PIKACHU',forceOwned=true});U.wait(5)
   assert(not entry.__vascModernDexFailedOpen,'Dex failed open to native')
   if source=='cobblemon'then assert(entry.__vascDexSource=='cobblemon',tostring(entry._vascDexModel and entry._vascDexModel.error or entry.__vascDexSource))end
   if source=='game'then print('ORIGINAL_RESULT',entry.__vascDexSource,type(game.data.pokemon.PIKACHU.spriteFront),tostring(game.data.pokemon.PIKACHU.spriteFront));assert(entry.__vascDexSource=='game','Original Dex selection ignored')end
   assert(U.shot(game,out..'/dex-'..source..'-'..size[3]..'.png'));game.stack:pop();assert(not entry._vascDexModel,'Dex exit leaked model')
  end
  print('PASS_DEX_SOURCE',source)
 end
 selectSource('cobblemon')
 for _,species in ipairs({'BULBASAUR','CHARIZARD','CHIKORITA','LUGIA','RAYQUAZA'})do
  if game.data.pokemon[species]then local entry=Screens.push(game,'DexEntryMenu',{species=species,forceOwned=true});U.wait(4)
   assert(entry.__vascDexSource=='cobblemon',species..' model missing '..tostring(entry._vascDexModel and entry._vascDexModel.error));assert(U.shot(game,out..'/dex-model-'..species..'.png'));game.stack:pop()
  end
 end
 local list=Screens.push(game,gen2 and 'Gen2PokedexMenu' or 'PokedexMenu',{species='PIKACHU'});U.wait(4);assert(list.__vascDexSource=='cobblemon','List preview missing');assert(U.shot(game,out..'/dex-list-cobblemon.png'));game.stack:pop();assert(not list._vascDexModel)
 if not gen2 then
  local setup=e.setupCard.new(game);game.stack:push(setup);for i,page in ipairs(setup.pages)do if page.id=='dex'then setup.page=i end end
  setup.draft.modernDexSpriteSource='cobblemon';setup:refreshPreview();U.wait(4);assert(setup.preview.mon,'Setup Dex model absent');assert(U.shot(game,out..'/setup-dex-cobblemon.png'));assert(setup:pause())
 end
 for _,size in ipairs({{1100,760,'landscape'},{540,960,'portrait'}})do
  love.window.setMode(size[1],size[2],{resizable=true,vsync=1})
  local entry=Screens.push(game,'DexEntryMenu',{species='PIKACHU',forceOwned=true,language='de'});U.wait(3)
  assert(entry.lang=='de' and entry.__vascDexSource=='cobblemon');assert(U.shot(game,out..'/dex-cobblemon-de-'..size[3]..'.png'));game.stack:pop()
 end
 selectSource('game','pokedexStyle')
 local native=Screens.push(game,gen2 and 'Gen2PokedexMenu' or 'PokedexMenu');U.wait(2)
 assert(not native.__vascGen2AscendantDex and not native.__vascModernDex,'game-default Dex switch ignored');game.stack:pop()
 selectSource('modern','pokedexStyle')
 print('PASS_DEX_LAYOUT_SWITCH')
 print('PASS_DEX_NATIVE' ,gen2 and 'gen2' or 'gen1');love.event.quit(0)
end
