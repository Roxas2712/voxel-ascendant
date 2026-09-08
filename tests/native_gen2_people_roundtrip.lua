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
  local expectedRole='kris'
  local function verify(enabled)
    local sprite=world.player.sprite
    local image=Renderer.resolveImage(sprite)
    assert(apo.walkingSprites.enabled()==enabled)
    if enabled then
      assert(sprite.def.ascendantAtlasImage,'HD binding missing')
      assert(sprite.def.ascendantRole==expectedRole,'Expected Kris HD, got '..tostring(sprite.def.ascendantRole))
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
  local identity=game.save.player.characterKey
  for i=1,12 do
    row.descriptor.step(game,i<=6 and 1 or -1)
    local enabled=i%2==0
    verify(enabled)
    U.wait(5);verify(enabled)
    U.hold(game,i%2==0 and 'right' or 'left',8);U.wait(10);verify(enabled)
    for _,npc in pairs(world.entities or {}) do
      if npc.sprite then print('NPC_HD',i,npc.id,tostring(npc.sprite.def.ascendantAtlasImage)) end
    end
    if enabled then
      local count=0
      for _,entity in pairs(world.entities or {})do if entity~=world.player and entity.sprite and entity.sprite.def.ascendantAtlasImage then count=count+1 end end
      assert(count>0,'Gen2 NPC HD bindings missing after ON')
    end
    assert(game.save.player.characterKey==identity)
    assert(U.shot(game,dir..'/people-'..i..'.png'))
  end
  for _,role in ipairs({'gold','kris','gold','kris'})do
    local save=require('src.core.gen2.Save').newGame({playerName='ROUNDTRIP'})
    save.player.gender=role=='kris' and 'female' or 'male';save.player.characterKey=role
    save.party={require('src.battle.gen2.Mon').new(game.data,'TOTODILE',10)}
    game.save=save;game:adoptSave(save);game.world.save=save
    Runtime.emit('save.loaded',{game=game,save=save});game:continueGame(save)
    U.wait(30);assert(game.world:setMap('ROUTE_29',15,7,'down'))
    world=game.overworld or game.world
    expectedRole=role;option('apo_hd_walking_sprites',true);U.wait(60);verify(true)
    local page=assert(Screens.build(game,'VascSettings',{section='pokemon'}))
    for _,item in ipairs(page.items)do if item.settingKey=='apo_hd_walking_sprites' then row=item end end
    row.descriptor.step(game,-1);verify(false);U.wait(60);verify(false)
    row.descriptor.step(game,1);verify(true);U.hold(game,'right',8);U.wait(60);verify(true)
    assert(U.shot(game,dir..'/reload-'..role..'.png'))
    print('HERO_RELOAD_ROUNDTRIP_PASS',role)
  end
  print('GEN2_PEOPLE_ROUNDTRIP_PASS');love.event.quit(0)
end
