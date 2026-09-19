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
 game.save.party={};require('src.world.OverworldController').checkTrainerSight=function()end
 local F=V.require('FirstPerson');local R=V.require('CurrentRoom');R.setting:setValue(true,game)


 local function shot(name)
  assert(U.shot(game,os.getenv('SHOT_DIR')..'/'..name..'.png'))
 end



 for _,p in ipairs({{'ROUTE_14',5,37},{'ROUTE_17',9,19}})do
  scene(p[1],p[2],p[3],p[1]);local ow=game.overworld
  for _,npc in ipairs(ow.npcs)do if npc.def.sprite=='SPRITE_BIKER'then
   local d=npc.sprite.def;print('RIDER_NATIVE',p[1],npc.def.x,npc.def.y,d.ascendantRole,d.ascendantCharacterAction,d.ascendantAtlasImage)
   assert(d.ascendantCharacterAction=='bicycle','native NPC not riding')
  end end
  F.yaw=math.pi/2;F.pitch=.25;V.require('ThirdPerson').zoomGoal=1;U.wait(60)
  Pipes.setLevel('voxel',3);U.wait(120);shot(p[1]..'-overhead');Pipes.setLevel('voxel',7);U.wait(120);shot(p[1]..'-riders')
  if p[1]=='ROUTE_17'then
   for _,npc in ipairs(ow.npcs)do if npc.def.sprite=='SPRITE_BIKER'then npc.update=function()end end end
   for _,dir in ipairs({'down','left','up','right'})do
    for _,npc in ipairs(ow.npcs)do if npc.def.sprite=='SPRITE_BIKER'then npc.facing=dir end end
    U.wait(30);shot('Gen1-'..dir)
   end
  end
 end
 print('PASS_NATIVE_GEN1_BIKERS');love.event.quit()
end
