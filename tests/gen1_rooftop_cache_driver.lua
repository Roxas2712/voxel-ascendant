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


 local Cache=V.require('RooftopCache');local World=V.require('RooftopWorld');local W=V.require('Weather');local D=V.require('DayNight')
 local rows={{1,2,3,4,5,6,1,false},{-3,5,8,1,2,3,4,true}}
 local packed=Cache.pack(rows);local decoded=assert(Cache.unpack(packed));assert(#decoded==2 and decoded[2][8] and not decoded[1][8])
 assert(not Cache.unpack(packed:sub(1,-2))and not Cache.unpack('BAD!'..packed:sub(5)))
 assert(not Cache.unpack(Cache.pack({{0,0,0,0,1,1,1,false}})))
 assert(not Cache.unpack(Cache.pack({{0,0,0,1,1,1,999,false}})))
 -- Native source maps are read only; alter a separate definition for the cache guard.
 local index=V.data('rooftop_cache');local meta=index['CELADON_MART_ROOF-stone']
 local original=Cache.signature(game.data.maps,meta.maps,game.data.tilesets);assert(original==meta.signature)
 local changed={};for k,v in pairs(game.data.maps)do changed[k]=v end
 local d={};for k,v in pairs(changed.CELADON_CITY)do d[k]=v end;changed.CELADON_CITY=d
 d.blocks={};for k,v in ipairs(game.data.maps.CELADON_CITY.blocks)do d.blocks[k]=v end;d.blocks[1]=d.blocks[1]+1
 assert(Cache.signature(changed,meta.maps,game.data.tilesets)~=original,'stale maps admitted')

 -- Compare background building discovery with the original full discovery.
 local Furniture=V.require('VoxelFurniture');local Map=require('src.world.Map');local P=V.require('VoxelItems')
 for _,id in ipairs({'CELADON_CITY','SAFFRON_CITY','LAVENDER_TOWN','PALLET_TOWN'})do
  local def=game.data.maps[id];local map=Map.new(def,game.data.tilesets[def.tileset])
  local full=Furniture.find(map);local background=Furniture.findBuildings(map);local expected={}
  for _,p in ipairs(full)do local m=P.models[p.kind];if m and (m.template or p.kind=='pallet_red_house' or p.kind=='pallet_blue_house' or p.kind=='pallet_oak_lab') then expected[p.kind..':'..p.tx..':'..p.ty]=true end end
  for _,p in ipairs(background)do assert(expected[p.kind..':'..p.tx..':'..p.ty],id..': unexpected building');expected[p.kind..':'..p.tx..':'..p.ty]=nil end
  for k in pairs(expected)do error(id..': missing '..k)end
  assert(Furniture.find(map)==full,'background discovery replaced native claims')
 end
 print('PASS_BUILDING_DISCOVERY_ISOLATION')
 -- Native Red/Blue map and tile imports: same cache only if source matches.
 local sources=os.getenv('ROOFTOP_SOURCE_QA')
 if sources then for _,version in ipairs({'red','blue'})do
  local maps=assert(loadfile(sources..'/'..version..'/data/generated/maps.lua'))()
  local tiles=assert(loadfile(sources..'/'..version..'/data/generated/tilesets.lua'))()
  print('EDITION_SIGNATURE',version,Cache.signature(maps,meta.maps,tiles),meta.signature)
 end end
 local originalMaps,originalTiles=game.data.maps,game.data.tilesets
 if sources then for _,version in ipairs({'red','blue'})do
  game.data.maps=assert(loadfile(sources..'/'..version..'/data/generated/maps.lua'))()
  game.data.tilesets=assert(loadfile(sources..'/'..version..'/data/generated/tilesets.lua'))()
  for _,style in ipairs({'stone','wood'})do
   V.require('Gen1LavenderTower').setting:setValue(style,game)
   for _,id in ipairs({'CELADON_MART_ROOF','CELADON_MANSION_ROOF'})do
    local d=game.data.maps[id];local map=Map.new(d,game.data.tilesets[d.tileset]);assert(V.require('Gen1RoofTerrace').matches(map))
    local boxes,parts=Cache.load({map=map,w=d.width*32,h=d.height*32},game.data.maps);assert(boxes and parts,'edition cache missing: '..version)
    for _,part in ipairs(parts)do part.mesh:release();part.texture:release()end
    print('PASS_EDITION_CACHE',version,id,style,#boxes)
   end
  end
 end end
 game.data.maps,game.data.tilesets=originalMaps,originalTiles
 -- Thin frames must survive the mesh builder with their exact dimensions.
 P.models.rooftop_test_thin={directBoxes=true,boxes={{0,0,0,.3,.5,.7,1}}}
 local vv,ii=P.geometry('rooftop_test_thin');assert(#vv==24 and #ii==36)
 local mx,my,mz=0,0,0;for _,v in ipairs(vv)do mx=math.max(mx,v[1]);my=math.max(my,v[2]);mz=math.max(mz,v[3])end
 assert(mx==.3 and my==.5 and mz==.7);P.models.rooftop_test_thin=nil;print('PASS_THIN_ARCHITECTURE')
 local totalFaces=0
 for _,face in ipairs(Cache.faces)do
  local v,i=Cache.faceGeometry({w=320,h=128},face)
  assert(#v==4 and #i==6);for _,p in ipairs(v)do
   local dot=(p[1]-160)*face.dir[1]+(p[2]-40)*face.dir[2]+(p[3]-64)*face.dir[3]
   assert(math.abs(dot-Cache.RADIUS)<.001,'cube orientation')
  end;totalFaces=totalFaces+1
 end
 assert(totalFaces==6)
 World.geometry=function()error('NORMAL_RUNTIME_ATTEMPTED_WORLD_BUILD')end
 local baseline=Cache.hits
 local missing=Cache.misses
 for _,style in ipairs({'stone','wood'})do
  V.require('Gen1LavenderTower').setting:setValue(style,game)
  for _,id in ipairs({'CELADON_MART_ROOF','CELADON_MANSION_ROOF'})do
   local x=id=='CELADON_MART_ROOF'and 17 or 4
   local y=id=='CELADON_MART_ROOF'and 3 or 4
   W.setting:setValue('clear',game);D.setting:setValue('day',game)
   local started=love.timer.getTime();scene(id,x,y,id..style)
   print('CACHE_READY',id,style,love.timer.getTime()-started,Cache.hits,Cache.misses)
   Pipes.setLevel('voxel',7);U.wait(60);F.yaw=math.pi/2;F.pitch=.2;V.require('ThirdPerson').zoomGoal=id=='CELADON_MART_ROOF'and 2 or 1;U.wait(90)
   shot(id..'-'..style..'-day');if style=='stone'then Pipes.setLevel('voxel',3);U.wait(75);shot(id..'-overview');Pipes.setLevel('voxel',7);U.wait(75)end;local props=Furniture.find(game.overworld.map);assert(#props==1 and P.models[props[1].kind].roofTerrace and props[1].claimed,'terrace not claimed');print('PASS_TERRACE_CLAIM',id,#V.require('Structures').forMap(game.overworld.map).objectQuads)
   D.setting:setValue('night',game);U.wait(45);shot(id..'-'..style..'-night')
   W.setting:setValue('rain',game);U.wait(90);assert(W.isOutdoor(game.overworld.map));shot(id..'-'..style..'-rain')
   print('STATS',id,style,love.timer.getFPS(),collectgarbage('count'),love.graphics.getStats().texturememory)
  end
 end
 assert(Cache.hits>=baseline+4 and Cache.misses==missing,'cache not used for every variant')
 -- Exercise each original roof exit through normal movement.
 Pipes.setLevel('voxel',3)
 for _,p in ipairs({{'CELADON_MART_ROOF',15,3,'CELADON_MART_5F'},
  {'CELADON_MANSION_ROOF',6,2,'CELADON_MANSION_3F'},
  {'CELADON_MANSION_ROOF',2,2,'CELADON_MANSION_3F'},
  {'CELADON_MANSION_ROOF',2,8,'CELADON_MANSION_ROOF_HOUSE'}})do
  U.teleport(game,p[1],p[2],p[3],'up');U.wait(60);U.hold(game,'up',18);U.wait(90)
  assert(game.overworld.map.id==p[4],'roof exit failed: '..p[1]..':'..p[2]);print('PASS_NATIVE_EXIT',p[1],p[2],p[3],game.overworld.map.id)
 end
 for _,p in ipairs({{10,2},{11,2},{12,3}})do
  U.teleport(game,'CELADON_MART_ROOF',p[1],p[2],'up');U.wait(60)
  U.tap(game,'a');U.wait(30);assert(game.stack:top()~=game.overworld,'vending action did not open');print('PASS_VENDING_INTERACTION',p[1],p[2])
 end
 local H=V.require('HorizonWall');local mem=love.graphics.getStats().texturememory
 H.invalidate();collectgarbage('collect');local after=love.graphics.getStats().texturememory
 assert(after<mem,'rooftop textures retained after cache invalidation');print('PASS_CACHE_RELEASE',mem,after)
 print('PASS_PACKAGED_ROOF_CACHE_WITH_WORLD_BUILD_DISABLED');love.event.quit()
end
