-- Native engine audit of all maps, surfaces and FLAT/LOCAL/WORLD terrain.
return function(game)
 io.stdout:setvbuf('no')
 local identity=os.getenv('POKEPORT_IDENTITY')
 assert(identity and identity:match('^vasc%-.*%-qa$'),'Requires an isolated vasc-...-qa save')
 assert(os.getenv('VASC_COVERAGE_OUT'),'VASC_COVERAGE_OUT required')
 local U=require('tests.drivers.util');game:startNewGame{intro=false}
 local raw=game.update;game.update=function(self,dt)return require('src.mods.Runtime').call('core.update',raw,self,dt)end
 local e=game.mods.exports.VOXEL_ASCENDANT;e.ascendantContent.onboardingShown=true;e.ascendantContent.promptDisabled=true
 local function find(fn,name,seen)
  if type(fn)~='function'then return end;seen=seen or {};if seen[fn]then return end;seen[fn]=true
  for i=1,200 do local k,v=debug.getupvalue(fn,i);if not k then break end;if k==name then return v end end
  for i=1,200 do local k,v=debug.getupvalue(fn,i);if not k then break end;local x=find(v,name,seen);if x then return x end end
 end
 local V=assert(find(e.lib.require('VoxelScene').render,'V'));
 local BA=V.require('BattleArena');local Loader=require('src.world.MapLoader')
 local ids={};for id in pairs(game.data.maps)do ids[#ids+1]=id end;table.sort(ids)
 local output={maps={},totalCells=0,unassigned=0,plannedFallbackCells=0,unexpectedUnassigned=0,distanceGaps=0};local J=V.require('CobblemonJson')
 for _,mode in ipairs({'flat','local','world'})do
 V.require('LedgeElevation').setting:setValue(mode,game);V.require('LedgeElevation').invalidate()
 for _,id in ipairs(ids)do
  local map=Loader.load(game.data,id); local enc=game.data.encounters[id]
  local record={id=id,terrain=mode,width=map.widthCells,height=map.heightCells,hasEncounters=enc~=nil,surfaces={}}
  for _,water in ipairs({false,true})do
   local rev=BA.withVisibilitySamples(BA.review,map,water)
   local surface={candidates=#rev.candidates,rejected=table.concat(rev.rejected,','),plannedFallback=rev.fallbackMode,reason=rev.reason,cells=0,unassigned=0,distanceGaps=0,anchors={},samples={}}
   for y=0,map.heightCells-1 do for x=0,map.widthCells-1 do
    local eligible=water and map:isWaterCell(x,y) or not water and map:isWalkableCell(x,y)
    if eligible then
     surface.cells=surface.cells+1
     local a=BA.assign(rev,x,y)
     if a then
      surface.anchors[tostring(a.anchorIndex)]=(surface.anchors[tostring(a.anchorIndex)]or 0)+1
      local dx,dy=a.mid[1]/16-x,a.mid[2]/16-y
      if a.map==map and dx*dx+dy*dy>18*18 then surface.distanceGaps=surface.distanceGaps+1 end
     else surface.unassigned=surface.unassigned+1;if #surface.samples<4 then surface.samples[#surface.samples+1]={x,y}end end
    end
   end end
   record.surfaces[water and 'water' or 'land']=surface
   if enc then output.totalCells=output.totalCells+surface.cells;output.unassigned=output.unassigned+surface.unassigned;output.distanceGaps=output.distanceGaps+surface.distanceGaps
    if surface.plannedFallback then output.plannedFallbackCells=output.plannedFallbackCells+surface.unassigned
    else output.unexpectedUnassigned=output.unexpectedUnassigned+surface.unassigned end
   end
  end
  output.maps[#output.maps+1]=record
  print('COVERAGE',mode,id,enc and 'ENCOUNTERS' or '-',record.surfaces.land.cells,record.surfaces.land.candidates,record.surfaces.land.unassigned,record.surfaces.water.cells,record.surfaces.water.candidates,record.surfaces.water.unassigned,record.surfaces.land.rejected)
  U.wait(1)
 end
 end
 local f=assert(io.open(os.getenv('VASC_COVERAGE_OUT'),'w'));f:write(J.encode(output));f:close()
 assert(output.unexpectedUnassigned==0,"Encounter cells lack a MAP court or explicit fallback: "..output.unexpectedUnassigned)
 love.event.quit()
end
