-- Native test-only encounters; run with an isolated vasc-...-qa identity.
return function(game)
 io.stdout:setvbuf('no')
 assert((os.getenv('POKEPORT_IDENTITY')or''):match('^vasc%-.*%-qa$'))
 local out=assert(os.getenv('TERRARIUM_QA'))
 love.window.hasFocus=function()return true end;love.window.isVisible=function()return true end
 local U=require('tests.drivers.util');game:startNewGame{intro=false}
 local e=assert(game.mods.exports.VOXEL_ASCENDANT)
 e.setupCard.suspended=true;e.ascendantContent.promptDisabled=true;e.ascendantContent.onboardingShown=true
 local function find(fn,name,seen)
  if type(fn)~='function'then return end;seen=seen or{};if seen[fn]then return end;seen[fn]=true
  for i=1,200 do local k,v=debug.getupvalue(fn,i);if not k then break end;if k==name then return v end end
  for i=1,200 do local k,v=debug.getupvalue(fn,i);if not k then break end;local x=find(v,name,seen);if x then return x end end
 end
 local V=assert(find(e.lib.require('VoxelScene').render,'V'))
 local B=V.require('OverworldBattle');local BS=V.require('BattleScene');local service=V.require('TerarriumHost').service
 local settings=e.setupCard.new(game).settings
 settings.terarriumIdleAnimation:setValue(false,game);settings.terarriumDome:setValue('clear',game)
 local renders=0;local render=BS.render
 BS.render=function(...)local image=render(...);if image then renders=renders+1 end;return image end
 require('src.render.Pipelines').setLevel('voxel',1)
 game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB=true;game.save.flags.EVENT_GOT_STARTER=true;game.save.repelSteps=999999
 local ids={'SS_ANNE_BOW','FIGHTING_DOJO','POWER_PLANT','VIRIDIAN_FOREST','ROCKET_HIDEOUT_B2F','SILPH_CO_11F',
 'POKEMON_MANSION_B1F','SAFARI_ZONE_CENTER','MT_MOON_1F','DIGLETTS_CAVE','CERULEAN_CAVE_B1F','OAKS_LAB',
 'VICTORY_ROAD_2F','ROUTE_17','SEAFOAM_ISLANDS_B4F'}
 for _,id in ipairs(ids)do
  B.finish()
  local map=require('src.world.MapLoader').load(game.data,id);local x,y
  for yy=2,map.heightCells-3 do for xx=2,map.widthCells-3 do
   if not x and map:isWalkableCell(xx,yy)then x,y=xx,yy end
  end end
  assert(x,'No walkable cell: '..id);U.teleport(game,id,x,y,'down')
  game.save.party={require('src.pokemon.Pokemon').new(game.data,'CHARIZARD',70)}
  settings.terarriumBehindRed:setValue(false,game);B.setting:setValue('terarrium',game)
  love.window.setMode(1100,760,{resizable=true,vsync=1});U.wait(15)
  local battle=require('src.battle.BattleState').newWild(game,'BLASTOISE',65);game.overworld:pushBattle(battle)
  for i=1,1200 do U.wait(1)
   if game.stack:top()==battle and battle.phase=='menu'and not battle.current and not battle.sendingOut then break end
   if i%15==0 then U.tap(game,'a')end
  end
  assert(game.stack:top()==battle and battle.phase=='menu','battle startup: '..id)
  for _,mode in ipairs({'side','behind'})do
   settings.terarriumBehindRed:setValue(mode=='behind',game)
   local before=renders;U.wait(35)
   local ar=assert(B.arena());assert(ar.terarrium and ar.terarrium.id==id and ar.terarrium.gymDesign,'wrong scene: '..id)
   assert(ar.terarrium.cameraMode==mode and renders>before+10,'camera/render stalled: '..id)
   local bakes=service.lightingStatus().bakes;U.wait(8);assert(service.lightingStatus().bakes==bakes,'rebaked idle lightmap')
   assert(U.shot(game,out..'/'..id..'-'..mode..'.png'))
   print('PASS_LOCATION',id,mode,ar.terarrium.family,ar.terarrium.gymDesign.revision,'renders',renders-before)
  end
 end
 -- The live host must select from the replacement save flags, not cached state.
 game.save.flags.EVENT_BEAT_SILPH_CO_GIOVANNI=true
 assert(not service.setup({id='SILPH_CO_11F'}).gymDesign,'liberated Silph still occupied')
 game.save.flags.EVENT_BEAT_SILPH_CO_GIOVANNI=nil
 assert(service.setup({id='SILPH_CO_11F'}).gymDesign,'new game occupation did not return')
 -- Physical GPU + touch layout coverage on the current host, no phone claim.
 love.window.setMode(540,960,{resizable=true,vsync=1});require('src.core.TouchControls'):setPreview(true)
 U.wait(30);assert(U.shot(game,out..'/seafoam-portrait.png'))
 U.tap(game,'a');U.wait(30);assert(U.shot(game,out..'/seafoam-moves.png'))
 local before=renders;U.tap(game,'a');U.wait(180);assert(renders>before+20,'attack interrupted rendering')
 assert(U.shot(game,out..'/seafoam-attack.png'))
 print('PASS_LOCATION_STORY_AND_ATTACK');print('TERRARIUM_LOCATIONS_NATIVE_PASS');love.event.quit()
end
