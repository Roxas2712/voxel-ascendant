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

 local found=false
 for _,id in ipairs({'ROUTE_18','ROUTE_16','FUCHSIA_CITY'})do
  U.teleport(game,id,4,4,'down');Pipes.setLevel('voxel',7);U.wait(180)
  for _,p in ipairs(V.require('VoxelFurniture').find(game.overworld.map))do
   local a=P.models[p.kind]
   if a and a.wallMaterial=='timber' then
    for _,door in ipairs(a.nativeDoors or {})do
     print('TIMBER_DOOR',id,p.tx,p.ty,door.side,door.at,door.width)
     local x,y,yaw
     if door.side=='north'then x=math.floor((p.tx*8+door.at)/16);y=math.floor(p.ty/2)-2;yaw=0
     elseif door.side=='west'then x=math.floor(p.tx/2)-2;y=math.floor((p.ty*8+door.at)/16);yaw=math.pi/2
     elseif door.side=='east'then x=math.floor((p.tx*8+a.frameW)/16)+1;y=math.floor((p.ty*8+door.at)/16);yaw=-math.pi/2 end
     if x and game.overworld.map:isWalkableCell(x,y)and not found then
      U.teleport(game,id,x,y,'down');Pipes.setLevel('voxel',8);F.yaw=yaw;F.pitch=0;U.wait(90)
      for _,time in ipairs({'day','night'})do
       V.require('DayNight').setting:setValue(time,game);U.wait(60)
       assert(U.shot(game,os.getenv('SHOT_DIR')..'/'..time..'.png'))
      end
      found=true;print('PASS_NATIVE_DOOR_VIEW',id,x,y,door.side)
     end
    end
   end
  end
 end
 assert(found,'no unobstructed side/rear timber door located')
 love.event.quit()
end
