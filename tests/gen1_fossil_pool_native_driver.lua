return function(game)
 io.stdout:setvbuf('no');assert(os.getenv('POKEPORT_IDENTITY')=='vasc-safari-terrain-20260919')
 local U=require('tests.drivers.util');local Pipes=require('src.render.Pipelines');game:startNewGame{intro=false}
 local raw=game.update;game.update=function(self,dt)return require('src.mods.Runtime').call('core.update',raw,self,dt)end
 local e=game.mods.exports.VOXEL_ASCENDANT;for k,v in pairs(e.ascendantContent.bootTimings or{})do print('CONTENT_BOOT',k,v)end;e.ascendantContent.onboardingShown=true;e.ascendantContent.promptDisabled=true
 local function find(fn,name,seen)
 if type(fn)~='function' then return end;seen=seen or {};if seen[fn]then return end;seen[fn]=true
 for i=1,200 do local k,v=debug.getupvalue(fn,i);if not k then break end;if k==name then return v end end
 for i=1,200 do local k,v=debug.getupvalue(fn,i);if not k then break end;local x=find(v,name,seen);if x then return x end end
 end
 local V=assert(find(e.lib.require('VoxelScene').render,'V'));local C=V.require('ChunkMesher');local S=V.require('VoxelScene');local State=V.require('VoxelState')
 love.window.setMode(1000,600,{vsync=1});love.window.setTitle('VASC – Videofeedback: isolierte Sichtprüfung')
 game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB=true;game.save.flags.EVENT_GOT_STARTER=true;game.save.repelSteps=999999
 Pipes.setLevel('voxel',7)
 local rendered=0;local fn=S.render;S.render=function(...)local c=fn(...);if c then rendered=rendered+1 end;return c end
 local function scene(id,x,y,n)
  print('ENTER',id);U.teleport(game,id,x,y,'down');local before=rendered
  for i=1,1800 do U.wait(1);if rendered>before+60 then break end end
  local st=V.require('Structures').forMap(game.overworld.map);local count=0;for _,b in ipairs(st.buildingStamps or{})do count=count+#(b.quads or b.template or{})end
  print('SCENE',id,State.ready,Pipes.eligible('voxel'),rendered-before,#(st.buildingStamps or{}),count,#(st.objectQuads or{}))
  love.graphics.captureScreenshot('rc15-'..n..'.png');U.wait(2)
  assert(Pipes.eligible('voxel') and rendered>before+30,'pipeline failed at '..id)
 end


 V.require('Weather').setting:setValue('clear',game);V.require('DayNight').setting:setValue('day',game)
 game.save.party={}
 local F=V.require('FirstPerson');local R=V.require('CurrentRoom');R.setting:setValue(true,game)


 local function shot(name)
  assert(U.shot(game,os.getenv('SHOT_DIR')..'/'..name..'.png'))
 end

 U.teleport(game,'FUCHSIA_CITY',6,8,'up');Pipes.setLevel('voxel',3)
 local map=game.overworld.map
 for y=2,8 do local row={} for x=2,10 do row[#row+1]=map:isWaterCell(x,y) and '~' or '.' end print('WATER',y,table.concat(row)) end
 V.require('WaterActors').setting:setValue(false,game)
 local model=V.require('Gen1OverworldStadium')
 local oldPrepare=model.prepare;local last
 model.prepare=function(poses)
  for _,p in ipairs(poses)do if p.fossilPoolSpecies then last={species=p.fossilPoolSpecies,x=p.px,y=p.py,water=p.waterline,swimming=p.swimming,sprite=p.sprite.def.id} end end
  return oldPrepare(poses)
 end
 for _,kind in ipairs({'before','dome','helix'})do
  game.save.flags.EVENT_GOT_DOME_FOSSIL=kind=='dome'
  game.save.flags.EVENT_GOT_HELIX_FOSSIL=kind=='helix'
  local before=rendered
  for i=1,1800 do U.wait(1);if rendered>before+80 and State.ready then break end end
  assert(rendered>before+30 and State.ready)
  shot(kind..'-a')
  if kind~='before' then
   assert(last and last.swimming=='pokemon','exhibit not swimming')
   local x,y=last.x,last.y
   print('EXHIBIT',kind,last.species,last.x,last.y,last.water,last.sprite)
   U.wait(120);shot(kind..'-b')
   assert(math.abs(last.x-x)+math.abs(last.y-y)>1,'exhibit stationary')
   print('MOVED',last.x,last.y,'STADIUM',model.status().drawn,model.status().lastError)
  end
 end
 print('PASS_FOSSIL_POOL');love.event.quit()
end
