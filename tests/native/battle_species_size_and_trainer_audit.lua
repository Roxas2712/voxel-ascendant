return function(game)
 assert(os.getenv('POKEPORT_IDENTITY')=='vasc-window-scale-qa')
 io.stdout:setvbuf('no');love.window.hasFocus=function()return true end;love.window.isVisible=function()return true end
 local U=require('tests.drivers.util');love.keypressed=function()end;love.mousepressed=function()end;local species=assert(os.getenv('QA_SPECIES'));game:startNewGame{intro=false}
 local ex=game.mods.exports.VOXEL_ASCENDANT;ex.setupCard.suspended=true;ex.ascendantContent.promptDisabled=true;ex.ascendantContent.onboardingShown=true
 local function find(fn,name,seen)
  if type(fn)~='function'then return end;seen=seen or {};if seen[fn]then return end;seen[fn]=true
  for i=1,100 do local k,v=debug.getupvalue(fn,i);if not k then break end;if k==name then return v end end
  for i=1,100 do local k,v=debug.getupvalue(fn,i);if not k then break end;local got=find(v,name,seen);if got then return got end end
 end
 local V=assert(find(ex.lib.require('VoxelScene').render,'V'));local O=V.require('OverworldBattle')
 local Heroes=V.require('BattleHeroesBridge');local append=Heroes.append;local last
 Heroes.append=function(cards,textures,layout,eye,map,arena,vp,probe)
  append(cards,textures,layout,eye,map,arena,vp,probe)
  if not probe then for _,card in ipairs(cards)do if card.side=='playerHero'then last={card=card,eye=eye,map=map,arena=arena,layout=layout}end end end
 end

 O.setting:setValue(true,game);V.require('PokemonModelProvider').setting:setValue('cobblemon',game)
 local Screens=require('src.ui.Screens');local menu=Screens.push(game,'VascSettings',{section='world'})
 for _,row in ipairs(menu.items)do if row.settingKey=='voxel3d'then local owner=find(row.descriptor.step,'self_');if owner then owner:setValue(true,game)end end end;game.stack:pop()
 game.save.party={require('src.pokemon.Pokemon').new(game.data,species,40)}
 love.window.setMode(1100,760,{resizable=true,vsync=1});V.require('DayNight').setting:setValue('day',game);local world=game.stack:top();world:setMap('ROUTE_1',10,25,'up');U.wait(40)
 local B=require('src.battle.BattleState');local screen=B.newWild(game,'RATTATA',3);world:pushBattle(screen)
 for i=1,2000 do if screen.phase=='menu'then break end;if i%10==0 then U.tap(game,'a')end;U.wait(1)end
 U.wait(60);local Stadium=V.require('Stadium');local a=assert(Stadium.stage1Actor('player'));assert(a.model and a.model.source=='cobblemon')
 local dir=assert(os.getenv('SHOT_DIR'))


 local m=a.model;local x,y,z,X,Y,Z=a.rig:posedBounds()
 local actual=(Y-y)*m.rootScale*a:worldHeight()/m.height
 assert(last,'native trainer presentation missing')
 if last then
  local c=last.card;local h=Heroes.geometryForMap(last.map);local f=c.shadowFoot
  print('TRAINER_FOOT',unpack(f));print('TRAINER_STATE',c.placementSafe,c.source.mapFoot and c.source.mapFoot.allowsOwnOverlap,c.source.width,c.source.height)
  print('TRAINER_EYE',unpack(last.eye));print('TRAINER_ANCHOR',unpack(last.layout.player))
  assert(c.placementSafe,'unsafe trainer card reached draw')
  assert(Heroes.supportsFoot(f,c.source.width,last.layout.actorScale and last.layout.actorScale.player or 1,V.require('BattleBillboard').yawToward(f[1],f[3],last.eye),function(x,z)return V.require('BattleArena').openCell(last.map,math.floor(x/16),math.floor(z/16),last.arena.surfing==true)end,function(x,z)return V.require('VoxelScene').groundAt(last.map,math.floor(x/16),math.floor(z/16))end,h),'trainer footprint blocked')
 end
 print('BATTLE_SIZE',species,'metres',a.heightMeters,'visibleWorldHeight',actual)
 assert(a.heightMeters and actual>0 and actual<40)
 local rw,rh=V.require('CobblemonSize').reference(a.model.crystalDex or a.dex)
 assert(actual<=rh+.05,'Crystal silhouette height exceeded')
 assert(U.shot(game,dir..'/'..species..'-battle.png'))
 print('PASS_ACTUAL_SPECIES_BATTLE',species);love.event.quit(0)
end
