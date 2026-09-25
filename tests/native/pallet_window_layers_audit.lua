return function(game)
 assert(os.getenv('POKEPORT_IDENTITY')=='vasc-window-scale-qa')
 io.stdout:setvbuf('no');love.window.hasFocus=function()return true end;love.window.isVisible=function()return true end
 local U=require('tests.drivers.util');game:startNewGame{intro=false}
 local ex=game.mods.exports.VOXEL_ASCENDANT;ex.setupCard.suspended=true;ex.ascendantContent.promptDisabled=true;ex.ascendantContent.onboardingShown=true
 local function find(fn,name,seen)
  if type(fn)~='function'then return end;seen=seen or{};if seen[fn]then return end;seen[fn]=true
  for i=1,100 do local k,v=debug.getupvalue(fn,i);if not k then break end;if k==name then return v end end
  for i=1,100 do local k,v=debug.getupvalue(fn,i);if not k then break end;local r=find(v,name,seen);if r then return r end end
 end
 local V=assert(find(ex.lib.require('VoxelScene').render,'V'));local P=require('src.render.Pipelines');local fp=V.require('FirstPerson')
 game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB=true;game.save.flags.EVENT_GOT_STARTER=true
 V.require('Gen1PalletVillage').buildings:setValue(true,game);V.require('Gen1PalletVillage').lights:setValue(true,game)
 V.require('DayNight').setting:setValue('night',game);V.require('Weather').setting:setValue('clear',game)
 love.window.setMode(1200,800,{resizable=true,vsync=1})
 local dir=assert(os.getenv('SHOT_DIR'))
 for _,view in ipairs{{'red',5,8},{'blue',14,8},{'lab',12,13}}do
  U.teleport(game,'PALLET_TOWN',view[2],view[3],'up');P.setLevel('voxel',7);U.wait(90);fp.lookBy(math.pi-.3-fp.yaw,-.06-fp.pitch);U.wait(40)
  for _,on in ipairs{true,false}do V.require('Shadows').setting:setValue(on,game);U.wait(25);assert(U.shot(game,dir..'/'..view[1]..(on and '-shadows-on' or '-shadows-off')..'.png'))end
 end
 print('PASS_WINDOW_NATIVE_CAPTURE');love.event.quit(0)
end
