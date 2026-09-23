-- A source-map LOD view from Celadon's real building plot. All positions use
-- WorldPlacement; native map data, collisions and foreground caches stay owned
-- by the engine. No independently authored sky or randomly placed city blocks.
local V=...
local M={}
local tex,registered
function M.texture()
 if not registered then require('src.render.Assets').register(function()if tex then tex:release();tex=nil end end);registered=true end
 if not tex then
  local colors=V.require('VoxelItems').palette;local data=love.image.newImageData(#colors,1)
  for i,c in ipairs(colors)do data:setPixel(i-1,0,c[1]/255,c[2]/255,c[3]/255,1)end
  tex=love.graphics.newImage(data);data:release();tex:setFilter('nearest','nearest')
 end
 return tex
end
function M.anchor(entry,buildings,models)
 local wanted=entry.map.id=='CELADON_MART_ROOF'and 'celadon_mart'or 'celadon_mansion'
 for _,p in ipairs(buildings)do
  local a=models[p.kind]
  if a and a.template==wanted then
   -- Native interior dimensions differ from the exterior plot. Centre the
   -- terrace on its building without stretching the rest of the world.
   return {x=entry.w/2-(p.tx*8+a.frameW/2),z=entry.h/2-(p.ty*8+a.depth/2),
    y=a.offsetY or -100,kind=p.kind}
  end
 end
end
function M.maps(entry,defs)
 local Place=V.require('WorldPlacement');local origin=Place.position('CELADON_CITY',defs)
 if not origin then return {} end
 local out={}
 for id,d in pairs(defs)do
  if d.generation~=2 and d.tileset=='OVERWORLD'then
   local p=Place.position(id,defs)
   if p and p.anchor==origin.anchor then
    local x,z=p.x-origin.x,p.y-origin.y
    local dx=math.max(0,x-entry.w,x*-1-d.width*32)
    local dz=math.max(0,z-entry.h,z*-1-d.height*32)
    if dx*dx+dz*dz<3200*3200 then out[#out+1]={id=id,def=d,x=x,z=z}end
   end
  end
 end
 table.sort(out,function(a,b)return a.id<b.id end)
 return out
end
function M.groundColor(material,C)
 if material==-162 or material==-163 or material==-165 or material==-167 or material==-173 then return C.stone end
 if material==-160 then return 25 end
 if material==-130 or material==-171 then return C.oak end
 return C.leaf
end
-- Distant mountains use the same native rock footprint, height field and
-- strata as the walkable maps. Only the sampling density is reduced; no
-- extra peaks are invented north of the routes or scaled above the skyline.
function M.mountains(entry,defs,emit,yieldStep)
 if not V.require('Gen1Rooftops').matches(entry.map)then return end
 local game=require('src.core.Game');defs=defs or game.data.maps
 local source=defs.CELADON_CITY;if not source then return end
 local Map=require('src.world.Map');local F=V.require('VoxelFurniture')
 local P=V.require('VoxelItems');local Mountains=V.require('Gen1MountainExteriors')
 local city=Map.new(source,game.data.tilesets[source.tileset])
 local anchor=M.anchor(entry,F.findBuildings(city),P.models)
 if not anchor then return end
 M.lastMountains={maps={},boxes=0}
 for _,place in ipairs(M.maps(entry,defs))do
  if Mountains.supports({id=place.id,def=place.def})then
   local map=Map.new(place.def,game.data.tilesets[place.def.tileset])
   local occupied={}
   for _,p in ipairs(F.findBuildings(map))do
    for y=p.ty,p.ty+p.h-1 do for x=p.tx,p.tx+p.w-1 do occupied[y*4096+x]=true end end
   end
   local scratch={models={},decorColors=P.decorColors}
   local props=Mountains.find(scratch,map,function(x,y)return occupied[y*4096+x]end,
    {coarse=true,yieldStep=yieldStep})
   if #props>0 then M.lastMountains.maps[#M.lastMountains.maps+1]=place.id end
   for _,p in ipairs(props)do
    local model=scratch.models[p.kind]
    for _,box in ipairs(model.boxes)do
     emit(place.x+p.tx*8+box[1]+anchor.x,box[2]+anchor.y,
      place.z+p.ty*8+box[3]+anchor.z,box[4],box[5],box[6],box[7],false)
     M.lastMountains.boxes=M.lastMountains.boxes+1
    end
    scratch.models[p.kind]=nil
    if yieldStep then yieldStep()end
   end
  end
 end
end

function M.geometry(entry,defs,emit,yieldStep)
 if not V.require('Gen1Rooftops').matches(entry.map)then return end
 local game=require('src.core.Game');defs=defs or game.data.maps
 local Map=require('src.world.Map');local P=V.require('VoxelItems');local F=V.require('VoxelFurniture')
 local source=defs.CELADON_CITY;if not source then return end
 local city=Map.new(source,game.data.tilesets[source.tileset])
 local buildings=F.findBuildings(city);local anchor=M.anchor(entry,buildings,P.models)
 if not anchor then return end
 local C=P.decorColors;local Shapes=V.require('TileShape')
 local detail=V.require('Gen1OutdoorScenery')
 M.last={maps=0,buildings=0,boxes=0,landmarks={}}
 local function box(x,y,z,w,h,d,c,lit,foliage)
  M.last.boxes=M.last.boxes+1
  emit(x+anchor.x,y+anchor.y,z+anchor.z,w,h,d,c,lit,foliage==true)
 end
 local maps=M.maps(entry,defs)
 -- Source maps describe playable corridors, not the land between them.
 -- Fill only unmapped space with a distant forest shoulder; source roads,
 -- shores and building plots always win. A deep base closes downward views.
 box(-3200,-1400,-3200,7200,1392,7200,C.leaf or 12)
 for z=-3008,3008,64 do for x=-3008,3008,64 do
  if x*x+z*z<3000*3000 then
   local occupied=false
   for _,m in ipairs(maps)do
    if x<m.x+m.def.width*32 and x+64>m.x and z<m.z+m.def.height*32 and z+64>m.z then occupied=true;break end
   end
   if not occupied then
    local height=24+((x/64*13+z/64*7)%4)*5
    box(x,0,z,64,8,64,C.leafDark)
    for n=0,3 do
     local tx=x+(n%2)*32;local tz=z+math.floor(n/2)*32
     local top=height+(n*7+x/64)%11
     box(tx+5,7,tz+5,22,top-7,22,C.leafDark,false,true)
     box(tx+2,top-15,tz+3,28,12,26,C.leaf,false,true)
     box(tx+8,top-3,tz+8,16,7,16,C.leafLight,false,true)
    end
   end
  end
 end;if yieldStep then yieldStep()end end
 for _,e in ipairs(maps)do
  local map=e.id=='CELADON_CITY'and city or Map.new(e.def,game.data.tilesets[e.def.tileset])
  local props=e.id=='CELADON_CITY'and buildings or F.findBuildings(map)
  local occupied={};local shapes=Shapes.forMap(map)
  for _,p in ipairs(props)do local a=P.models[p.kind]
   if a then
    for y=p.ty,p.ty+p.h-1 do for x=p.tx,p.tx+p.w-1 do occupied[y*4096+x]=true end end
    if p.kind~=anchor.kind then
     M.last.buildings=M.last.buildings+1
     if a.template=='silph_co'or a.template=='pokemon_tower'or a.template=='pokemon_tower_top'then
      M.last.landmarks[#M.last.landmarks+1]={map=e.id,template=a.template,x=e.x+p.tx*8+anchor.x,z=e.z+p.ty*8+anchor.z}
     end
     -- Use the actual facade/roof boxes and original colours. Their texture
     -- atlas is tiny; no foreground voxel meshes or sprite caches are loaded.
     for _,kind in ipairs({p.kind,a.glassKind})do
      local m=P.models[kind]
      if m then for _,b in ipairs(m.boxes)do
       box(e.x+p.tx*8+b[1],b[2],e.z+p.ty*8+b[3],b[4],b[5],b[6],b[7],kind==a.glassKind)
      end end
     end
    end
   end
  end
  -- Coarse terrain follows actual native cells. Merge identical horizontal
  -- runs; a road/shore/forest keeps its position across every map boundary.
  local step=e.id=='CELADON_CITY'and 2 or 4
  for ty=0,e.def.height*4-1,step do
   local run
   local function flush()
    if not run then return end
    local x,z=e.x+run.x*8,e.z+ty*8;local w=run.w*8;local d=step*8
    box(x,-4,z,w,4,d,run.color)
    if run.tree then
     box(x+2,0,z+2,math.max(2,w-4),run.tree,d-4,C.leafDark,false,true)
     box(x+4,run.tree,z+4,math.max(2,w-8),5,d-8,C.leafLight,false,true)
    end
   end
   for tx=0,e.def.width*4-1,step do
    local t=map:tileAt(tx,ty);local s=Shapes.at(map,shapes,t,tx,ty)
    local cls=s and s.class;local tree=not occupied[ty*4096+tx] and (cls=='canopy'or cls=='tree'or cls=='cylinder')and 22 or nil
    local color=C.leaf or 12
    if map:isWaterCell(math.floor(tx/2),math.floor(ty/2))then color=8
    elseif occupied[ty*4096+tx]then color=C.stone or 14
    elseif tree or cls=='grass'or cls=='flower'then color=C.leaf or 12
    elseif map:isWalkableCell(math.floor(tx/2),math.floor(ty/2))then
     local material=detail.material(map,true,t,tx,ty)
     color=M.groundColor(material,C)
    end
    if run and run.color==color and run.tree==tree then run.w=run.w+step
    else flush();run={x=tx,w=step,color=color,tree=tree}end
   end
   flush()
   if yieldStep and ty%16==0 then yieldStep()end
  end
  M.last.maps=M.last.maps+1
  if yieldStep then yieldStep()end
 end
end
return M
