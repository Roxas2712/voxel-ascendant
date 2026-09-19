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


 local total=0
 for _,id in ipairs({'SAFARI_ZONE_CENTER','SAFARI_ZONE_EAST','SAFARI_ZONE_NORTH','SAFARI_ZONE_WEST'})do
  U.teleport(game,id,4,4,'up');U.wait(2)
  local map=game.overworld.map;local gates=V.require('Gen1SafariGates').groups(map)
  print('GATE_COUNT',id,#gates);total=total+#gates
  local cx,cy=4,4
  for yy=1,map.def.height*4-1 do for xx=0,map.def.width*4-2 do
   if map:tileAt(xx,yy)==57 and map:tileAt(xx+1,yy)==95 then cx,cy=math.floor(xx/2),math.floor(yy/2)+2;break end
  end if cx~=4 then break end end
  U.teleport(game,id,cx,cy,'up');Pipes.setLevel('voxel',3)
  local before=rendered;for k=1,1800 do U.wait(1);if rendered>before+50 and State.ready then break end end
  shot(id..'-gravel')

  for i,g in ipairs(gates)do
   local dir=({north='up',south='down',east='right',west='left'})[g.side]
   local dx,dy=0,0
   if g.side=='north'then dy=1 elseif g.side=='south'then dy=-1 elseif g.side=='east'then dx=-1 else dx=1 end
   U.teleport(game,id,g.x+dx*3,g.y+dy*3,dir);Pipes.setLevel('voxel',7)
   F.yaw=({north=math.pi,south=0,east=math.pi/2,west=-math.pi/2})[g.side];F.pitch=.55
   local before=rendered;for k=1,1800 do U.wait(1);if rendered>before+50 and State.ready then break end end
   shot(id..'-gate-'..i)
   -- Assert the native coordinate map still owns every trigger and the
   -- semantic material removes only its actual direction-mark art.
   for cy=g.y,g.y+((g.side=='east'or g.side=='west')and 1 or 0)do
    for cx=g.x,g.x+((g.side=='north'or g.side=='south')and 1 or 0)do
     assert(map:warpAtCell(cx,cy),'missing native exit')
     for oy=0,1 do for ox=0,1 do local t=map:tileAt(cx*2+ox,cy*2+oy)
      if t>=80 and t<=83 then assert(V.require('Gen1OutdoorScenery').material(map,true,t,cx*2+ox,cy*2+oy)==-171)end
     end end
    end
   end
   -- Walk across the map edge using native input with the voxel renderer on.
   Pipes.setLevel('voxel',1);U.wait(45)
   U.teleport(game,id,g.x+dx,g.y+dy,dir);U.wait(2)
   U.hold(game,dir,25);U.wait(90)
   print('TRAVEL',id,i,g.side,g.dest,game.overworld.map.id)
   assert(game.overworld.map.id==g.dest,'native transition failed')
  end
 end
 assert(total==13,'missing Safari gates')
 print('PASS_13_SAFARI_GATES');love.event.quit()
end
