-- Disposable native game QA only. Exercises the actual VASC setting row.
return function(game)
  io.stdout:setvbuf('no')
  assert((os.getenv('POKEPORT_IDENTITY') or ''):match('^vasc%-301%-native'))
  local U={}
  function U.wait(n) for _=1,n do coroutine.yield() end end
  function U.shot(g,path) g.capturePath=path;U.wait(60);return true end
  function U.hold(g,key,n) g.input:sourcePress(key,'qa');U.wait(n);g.input:sourceRelease(key,'qa') end
  local dir=assert(os.getenv('SHOT_DIR'))
  U.wait(30)
  local vasc=assert(game.mods.exports.VOXEL_ASCENDANT)
  local apo=assert(vasc.overworldPokemon)
  assert(not game.mods.exports['translation-german-universal'])
  local gen=require('src.core.GameVersion').generation()
  assert(gen==2,'Gen2-only fixture')
  local Runtime=require('src.mods.Runtime')
  if gen==2 then
    local save=require('src.core.gen2.Save').newGame({playerName='MENUQA'})
    save.player.gender='female';save.player.characterKey='kris'
    save.party={require('src.battle.gen2.Mon').new(game.data,'TOTODILE',10)}
    game.save=save;game:adoptSave(save);game.world.save=save
    Runtime.emit('save.created',{game=game,save=save});game:continueGame(save)
    U.wait(20);assert(game.world:setMap('ROUTE_29',15,7,'down'))
  else
    game:startNewGame({intro=false});U.wait(20)
    -- Keep this disposable new game in its starting room.
    local Pipelines=require('src.render.Pipelines')
    game.save.options.pipelines=game.save.options.pipelines or {}
    game.save.options.pipelines.voxel='full';Pipelines.syncOptions(game.save.options)
  end
  local function option(key,value)
    for _,owner in ipairs({game.mods,game.mods.loader or game.mods,game.options,game.save.options})do
      owner.modOptions=owner.modOptions or {};owner.modOptions.VOXEL_ASCENDANT=owner.modOptions.VOXEL_ASCENDANT or {}
      owner.modOptions.VOXEL_ASCENDANT[key]=value
    end
    Runtime.emit('mod.options_changed',{game=game,mod='VOXEL_ASCENDANT',key=key,value=value})
  end
  option('voxel3d',true);option('apo_hd_walking_sprites',true)
  U.wait(40)
  local world=game.overworld or game.world
  local Screens=require('src.ui.Screens')
  local Renderer=require('src.render.SpriteRenderer')
  local function upvalue(fn,key)
    for i=1,100 do local n,v=debug.getupvalue(fn,i);if not n then break end;if n==key then return v end end
    error('missing upvalue '..key)
  end
  local imageDefs=upvalue(Renderer.resolveImage,'imageDefs')
  local function verify(enabled)
    local sprite=world.player.sprite
    local image=Renderer.resolveImage(sprite)
    assert(apo.walkingSprites.enabled()==enabled)
    if enabled then
      assert(sprite.def.ascendantAtlasImage,'HD binding missing')
      assert(imageDefs[image],'HD player missing from renderer')
    else
      assert(not sprite.def.ascendantAtlasImage,'HD binding survived OFF')
      assert(not imageDefs[image],'hero identity forced HD back on')
    end
    print('PLAYER_HD_CHECK gen='..gen..' enabled='..tostring(enabled)..' sprite='..tostring(sprite.def.id))
  end
  love.window.setMode(1280,720,{resizable=true,vsync=0});U.wait(20)
  verify(true);assert(U.shot(game,dir..'/player-on.png'))
  local page=assert(Screens.build(game,'VascSettings',{section='pokemon'}))
  local row
  for _,item in ipairs(page.items)do if item.settingKey=='apo_hd_walking_sprites' then row=item end end
  assert(row and row.descriptor and row.descriptor.step,'actual HD PEOPLE setting missing')
  assert(vasc.pokemonHdContent.ready(),'real HD cache missing')
  option('battles',true);option('partyFollower',true);option('stadium3dSprites',true)
  local P=gen==1 and require('src.pokemon.Pokemon') or require('src.battle.gen2.Mon')
  game.save.party={P.new(game.data,'CHARMANDER',20),P.new(game.data,'SQUIRTLE',20),P.new(game.data,'BULBASAUR',20)}
  if gen==1 then world:setMap('ROUTE_1',10,20,'down') end
  local contexts={'apo_follower_sprite_source','apo_grass_pokemon_sprite_source','apo_city_pokemon_sprite_source','apo_wilds_town_pokemon_sprite_source'}
  local cases={{'stadium2','stadium_only','stadium2'},{'full_hd','go_only','crystal'},{'hd','sprite_only','crystal'},{'pokemmo','auto','crystal'},{'full_hd','go_only','crystal'},{'stadium2','stadium_only','stadium2'}}
  for n,c in ipairs(cases)do
    love.window.setMode(n%2==0 and 600 or 1280,n%2==0 and 1200 or 720,{resizable=true,vsync=0});U.wait(5)
    local function menuValue(key,value)
      local page=assert(Screens.build(game,'VascSettings',{section='pokemon'}))
      local row
      for _,item in ipairs(page.items)do if item.settingKey==key then row=item end end
      assert(row,'missing actual row '..key)
      local bucket=(game.mods.loader or game.mods).modOptions.VOXEL_ASCENDANT
      for tries=1,12 do
        if bucket[key]==value then return end
        row.descriptor.step(game,1)
      end
      error('row failed to reach '..key..'='..tostring(value))
    end
    menuValue('pokemonModelSkin',c[3]);menuValue('apo_pokemon_model_source',c[2])
    for _,key in ipairs(contexts)do menuValue(key,c[1])end
    local function probe(label)
      for _,npc in pairs(world.entities or {})do
        local d=npc.sprite and npc.sprite.def or {}
        if d.pokemonDex or npc.pokepcMon or npc.pokemonSpecies then print('LIVE_SOURCE',label,npc.id,d.pokemonDex,d.ascendantPokemonSpriteSource,d.ascendantPokemonContext,d.image)end
      end
      local matched=0
      for _,npc in pairs(world.entities or {})do
        if npc.pokepcMon and npc.pokepcMon.species=='CHARMANDER' then
          local d=npc.sprite.def
          local want=c[1]=='pokemmo' and 'pokemmo' or 'pokemon_go_549'
          if c[1]=='stadium2' then want=nil end
          assert(d.ascendantPokemonSpriteSource==(want or nil),'stale live follower source '..label..': '..tostring(d.ascendantPokemonSpriteSource))
          matched=matched+1
        end
      end
      assert(matched==1,'missing owned follower fixture')
      for k,v in pairs(world)do if type(v)=='table' and tostring(k):lower():find('follow')then print('FOLLOW_FIELD',k)end end
    end
    probe('immediate-'..n);U.wait(120);probe('stationary-'..n)
    for k,v in pairs(vasc.pokemonModelProvider.status())do print('MODEL_STATUS',k,v)end
    print('MODEL_PROBE',type(vasc.overworldPokemonModelAvailable)=='function' and vasc.overworldPokemonModelAvailable(4))
    print('CACHE_MARKER',love.filesystem.read('cache/stadium/pack.info'))
    U.wait(25)
    local h=apo.voxelCharacters.health()
    assert(h.ok and not h.vascError and not h.animationCardError and not h.fallbackCardError,'renderer error')
    for _,context in ipairs({'follower','grass','city','wilds_town'})do
      local choice=apo.presentationPolicy.select(4,{context=context,spriteSource=c[1]})
      if c[1]=='pokemmo' then assert(choice.id=='sprite','MMO masked by model')end
      if c[1]=='full_hd' then assert(choice.id~='stadium2','Full HD masked by model')end
      if c[1]=='stadium2' and gen==2 then assert(choice.id=='stadium2','imported Stadium model not selected')end
      print('SOURCE_MATRIX',gen,n,context,c[1],choice.id)
    end
    local screen
    if gen==1 then
      screen=require('src.ui.BoxMenu').new(game);game.stack:push(screen);U.wait(8)
      local host=assert(screen.hostState);local m=host:buildModel();local t=m.zones.party.entries[3]
      local result=host:deposit({target={id=t.id,zone='party',slot=t.slot}});assert(result.status=='applied')
      U.wait(8);m=host:buildModel();local e
      for _,entry in ipairs(m.zones.box.entries)do if entry.pokemon.species=='BULBASAUR' then e=entry end end
      assert(e,'deposited mon missing')
      assert(host:withdraw({target={id=e.id,zone='box',box=game.save.currentBox,slot=e.slot}}).status=='applied')
    else
      screen=require('src.ui.gen2.BoxMenu').new(game,{mode='deposit'});game.stack:push(screen);U.wait(8)
      assert(type(screen.doDeposit)=='function','Gen2 deposit screen unavailable');screen.index=3;screen:doDeposit();assert(#game.save.party==2,'Gen2 deposit failed')
      U.wait(8);game.stack:pop();screen=require('src.ui.gen2.BoxMenu').new(game,{mode='withdraw'});game.stack:push(screen);U.wait(8)
      screen.index=#screen:list();screen:doWithdraw();assert(#game.save.party==3,'Gen2 withdrawal failed')
    end
    U.wait(10);game.stack:pop();U.wait(10)
    assert(#game.save.party==3,'party loss');verify(true)
    assert(U.shot(game,dir..'/matrix-gen'..gen..'-'..n..'-'..c[1]..'.png'))
    print('PC_SOURCE_MATRIX_PASS',gen,n,c[1])
  end
  print('SOURCE_MATRIX_NATIVE_PASS gen='..gen)
  love.event.quit(0)
end
