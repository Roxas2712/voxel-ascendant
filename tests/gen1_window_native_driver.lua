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



 local P=V.require('VoxelItems')
 U.teleport(game,'SAFARI_ZONE_CENTER',17,14,'down');Pipes.setLevel('voxel',7)
 for i=1,300 do U.wait(1);if State.ready and rendered>40 then break end end
 for _,p in ipairs(V.require('VoxelFurniture').find(game.overworld.map))do
  local a=P.models[p.kind]
  if a and a.glassKind then print('HOUSE',p.kind,p.tx,p.ty,a.frameW,a.depth,a.template)end
 end
 local map=game.overworld.map
 for y=14,17 do print('WALK',17,y,map:isWalkableCell(17,y))end
 if map:isWalkableCell(17,17)then U.teleport(game,map.id,17,17,'down')end
 Pipes.setLevel('voxel',8)
 for _,time in ipairs({'day','night'})do
  V.require('DayNight').setting:setValue(time,game)
  for index,yaw in ipairs({-.15,0,.15})do
   F.yaw=yaw;F.pitch=0;U.wait(45)
   assert(U.shot(game,os.getenv('SHOT_DIR')..'/'..time..'-'..index..'.png'))
  end
 end
 print('PASS_WINDOW_SURVEY');love.event.quit()
end
