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
 for _,id in ipairs({'SAFARI_ZONE_CENTER','SAFARI_ZONE_EAST','SAFARI_ZONE_NORTH','SAFARI_ZONE_WEST'})do
  U.teleport(game,id,4,4,'up');U.wait(2)
  local map=game.overworld.map;local x,y=4,4
  for yy=1,map.def.height*2-2 do for xx=1,map.def.width*2-2 do
   if map:tileAt(xx*2,yy*2)==46 and map:isWalkableCell(xx,yy)then x,y=xx,yy;break end
  end if x~=4 then break end end
  U.teleport(game,id,x,y,'up');Pipes.setLevel('voxel',1)
  local before=rendered
  for i=1,1800 do U.wait(1);if rendered>before+40 and State.ready then break end end
  assert(rendered>before+30 and State.ready,'no native3D '..id)
  print('SCENE',id,x,y)
  shot(id..'-overview')
  Pipes.setLevel('voxel',3);U.wait(30);shot(id..'-close')
  -- Native tile renderer, same map and atlas, no generated comparison art.
  local rawDraw=love.draw
  love.draw=function()
   rawDraw();love.graphics.push('all');love.graphics.setShader();love.graphics.origin()
   love.graphics.clear(.12,.14,.13,1)
   local w,h=map.def.width*32,map.def.height*32
   local scale=math.min(980/w,580/h)
   love.graphics.translate((1000-w*scale)/2,(600-h*scale)/2);love.graphics.scale(scale)
   love.graphics.setColor(1,1,1,1);map.renderer:drawMapOnly(0,0,w,h)
   love.graphics.pop()
  end
  U.wait(2)
  -- captureScreenshot occurs after the native map overlay.
  local path=os.getenv('SHOT_DIR')..'/'..id..'-2d.png'
  love.graphics.captureScreenshot(function(img) local file=assert(io.open(path,'wb'));file:write(img:encode('png'):getString());file:close()end)
  U.wait(3);love.draw=rawDraw
  local st=V.require('Structures').forMap(map)
  local hash=0;local shapeHash=0;local crowns,quads=0,0
  local O=V.require('Gen1OutdoorScenery')
  local keys={}
  for k in pairs(st.shapeAt)do keys[#keys+1]=k end;table.sort(keys)
  for _,k in ipairs(keys)do
   local spec=st.shapeAt[k];local value=tostring(k)..':'..spec.class..':'..tostring(spec.h)..':'..tostring(st.runs[k]and st.runs[k].h)
   for i=1,#value do shapeHash=(shapeHash*31+value:byte(i))%1000000007 end
  end
  print('NATIVE_SHAPE_HASH',id,shapeHash)
  for cy=0,map.def.height*2-1 do for cx=0,map.def.width*2-1 do
   hash=(hash*31+map:cellTile(cx,cy)+(map:isWalkableCell(cx,cy)and 1 or 0))%1000000007
  end end
  for _,warp in ipairs(map.def.warps or{})do print('WARP',id,warp.x,warp.y,warp.destMap)end
  print('NATIVE_MAP_HASH',id,hash)
 end
 print('PASS_SAFARI_TERRAIN');love.event.quit()
end
