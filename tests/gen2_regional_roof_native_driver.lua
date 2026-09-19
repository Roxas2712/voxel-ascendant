return function(game)
 io.stdout:setvbuf('no')
 assert(os.getenv('POKEPORT_IDENTITY')=='vasc-gen2-panorama-ready-20260919' or os.getenv('POKEPORT_IDENTITY')=='vasc-gen2-regression-20260919-gold-matrix','offline bake requires the isolated QA identity')
 local function wait(n) for _=1,n do coroutine.yield() end end
 print('BENCH_DRIVER_READY')
 local ex=assert(game.mods.exports.VOXEL_ASCENDANT)
 local bridge
 for i=1,50 do local n,v=debug.getupvalue(ex.voxelStatus,i);if n=='GoldVoxelBridge'then bridge=v;break end end
 assert(bridge and ex.active and ex.rendererInstalled)
 if ex.ascendantContent then ex.ascendantContent.promptDisabled=true end
 local opts=bridge.lib.mod.options;local original=opts.get
 local chosen={voxelDiskCache=false,voxel3d=true,daytime='day',weather='clear',enabled=false,town_pokemon=false,deviceProfile='auto',openWorld=true,cameraMode='full'}
 opts.get=function(self,k,...)if chosen[k]~=nil then return chosen[k] end return original(self,k,...)end


 local V=bridge.lib;local B=V.require('Buildings');local seen={}
 local stamp=B.stamp
 B.stamp=function(S,map,quads,tx,ty,bw,bh,t)
  if map.id=='GOLDENROD_CITY' then
   local key=t.id..':'..tx..':'..ty
   if not seen[key]then
    seen[key]=true;local ymax=0;for _,q in ipairs(quads)do for i=1,4 do ymax=math.max(ymax,q[i][2])end end
    print('HOUSE',map.id,t.id,tx,ty,bw,bh,#quads,ymax)
   end
  end
  return stamp(S,map,quads,tx,ty,bw,bh,t)
 end
 local views=assert(os.getenv('VIEW_OUTPUT'))
 love.window.setMode(1100,700,{vsync=1})
 local save=require('src.core.gen2.Save').newGame({playerName='VISTAQA'})
 game.save=save;game:adoptSave(save);game.world.save=save;require('src.mods.Runtime').emit('save.created',{game=game,save=save});game:continueGame(save);wait(120)
 V.require('DayNight').setting:setValue('day',game)
 game.world.checkTrainerBattle=function()return false end;game.world.trySceneScript=function()return false end;game.world.tryCoordScript=function()return false end;game.world.tryWildEncounter=function()return false end
 local A=require('src.render.Assets');local TA=require('src.world.gen2.TileAttrs')
 for _,id in ipairs({'GOLDENROD_CITY','NEW_BARK_TOWN','ECRUTEAK_CITY','OLIVINE_CITY','GOLDENROD_CITY'})do
  assert(game.world:setMap(id,id=='GOLDENROD_CITY' and 20 or 10,10,'up'));wait(150)
  local map=game.world.map;local raw,ts=game.world:atlasFor(map.def);local w,h=raw:getDimensions()
  local canvas=love.graphics.newCanvas(w,h,{dpiscale=1,format='rgba8'})
  love.graphics.push('all');love.graphics.setCanvas(canvas);love.graphics.origin();love.graphics.setShader();love.graphics.clear(0,0,0,0);love.graphics.setColor(1,1,1,1);love.graphics.draw(raw);love.graphics.pop()
  local native=canvas:newImageData();local base=A.imageData(ts.image);local changed=0;local tileCounts={};local attrs=0;local mismatch=0;local geometry=assert(map.renderer._stadiumGeometryData,'regional geometry missing')
  for y=0,h-1 do for x=0,w-1 do
   local a,b,c=native:getPixel(x,y);local d,e,f=base:getPixel(x,y);local gr,gg,gb=geometry:getPixel(x,y);if math.abs(a-gr)+math.abs(b-gg)+math.abs(c-gb)>.01 then mismatch=mismatch+1 end
   if math.abs(a-d)+math.abs(b-e)+math.abs(c-f)>.01 then
    changed=changed+1;local tile=math.floor(y/8)*16+math.floor(x/8);tileCounts[tile]=(tileCounts[tile]or 0)+1
   end
  end end
  for t=0,w*h/64-1 do local a=TA.forTile(ts,t);if a.xFlip or a.yFlip or TA.sheetTileId(t,a)~=t or a.palette~=ts.tilePalettes[t+1]then attrs=attrs+1 end end
  local used={};for y=0,map.def.height*4-1 do for x=0,map.def.width*4-1 do used[map:tileAt(x,y)]=true end end;local activeAttrs=0;for t in pairs(used)do local a=TA.forTile(ts,t);if a.xFlip or a.yFlip or TA.sheetTileId(t,a)~=t or a.palette~=ts.tilePalettes[t+1]then activeAttrs=activeAttrs+1 end end;print('USED_ATTR_DIFFERENCES',id,activeAttrs);local name=game.world.roofs.mapGroupRoofs[map.def.group];print('ATLAS_AUDIT',id,name,changed,attrs)
  local counts={};for t,n in pairs(tileCounts)do counts[#counts+1]=string.format('%02X:%d',t,n)end;table.sort(counts);print('CHANGED_TILES',table.concat(counts,','))
  assert(mismatch==0,'regional source differs from native atlas: '..id..' '..mismatch)
  print('PASS_NATIVE_ROOF_PIXELS',id,w*h)
  if id=='GOLDENROD_CITY'then
   chosen.cameraMode='full';V.require('DioramaZoom').set(1.6);wait(20)
   love.graphics.captureScreenshot(function(data)local f=assert(io.open(views..'/Dukatia.png','wb'));f:write(data:encode('png'):getString());f:close();data:release()end);wait(4)
  end
  native:release();canvas:release()
 end
 print('PASS_NATIVE_ATLAS_AUDIT');love.event.quit()
end
