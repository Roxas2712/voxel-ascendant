-- Exact native Gen1 furniture patterns. Tile collision and interactions remain
-- with the engine; only recognised artwork is claimed by the visual models.
local V=...
local P=V.require('VoxelItems')
local G=V.require('Voxel3D')
local M=V.require('Mat4')
local Budget=V.require('BuildBudget')
local Assets=require('src.render.Assets')
local F={}
local function model(kind,w,h)
  local m={boxes={},frameW=w,frameH=h+16,depth=h,offsetY=-16}
  P.models[kind]=m
  return function(x,y,z,bw,bh,bd,c)m.boxes[#m.boxes+1]={x,y,z,bw,bh,bd,c}end
end
local function screen(b,x,y,z,w,h)
  b(x,y,z,w,h,2,3);b(x+1,y+1,z+2,w-2,h-2,1,8)
  b(x+2,y+h-3,z+3,w-4,1,1,7)
  b(x+3,y+2,z+3,math.max(1,w-7),1,1,9)
end
local b=model('television',16,16)
b(3,0,4,10,2,9,16);b(7,2,7,2,2,3,3)
screen(b,1,4,5,14,10);b(13,5,8,1,1,1,12)
b(2,2,5,1,1,2,3);b(13,2,5,1,1,2,3)
b=model('switch_console',16,16)
b(3,0,3,10,1,10,16);b(5,1,5,6,2,7,3)
b(3,2,5,10,2,6,3);b(3,2,5,2,2,6,7);b(11,2,5,2,2,6,1)
b(5,4,6,6,1,4,8);b(6,5,7,4,1,1,9)
b(3,4,6,1,1,1,3);b(4,4,9,1,1,1,3)
b(12,4,6,1,1,1,3);b(11,4,9,1,1,1,3)
b(7,1,12,2,1,2,3)
b=model('home_pc',16,32)
b(1,0,16,3,8,13,16);b(12,0,16,3,8,13,16)
b(0,8,14,16,2,16,14);b(2,2,17,11,1,2,16)
b(6,10,18,4,2,4,3);screen(b,1,12,16,14,10)
b(2,10,24,10,1,4,3);for x=3,10,2 do b(x,11,24,1,1,2,14)end
b(13,10,25,2,1,3,7)
b=model('center_pc',16,24)
for _,v in ipairs(P.models.home_pc.boxes)do b(v[1],v[2],v[3]-8,v[4],v[5],v[6],v[7])end
local function goods(b,x,y,z,c)
  b(x,y,z,3,4,3,c);b(x+1,y+4,z+1,1,1,1,3)
  b(x,y+1,z+3,3,2,1,4)
end
for _,kind in ipairs({'mart_shelf','mart_shelf_half'})do
  local half=kind=='mart_shelf_half'
  b=model(kind,32,half and 16 or 32)
  local d=half and 12 or 24
  b(1,0,3,30,2,d,16)
  b(1,2,3,2,20,d,14);b(29,2,3,2,20,d,14)
  b(3,2,half and 3 or 13,26,20,2,8)
  for _,y in ipairs({2,9,16})do
    b(3,y,3,26,1,d,14);b(3,y,3+d,26,1,1,7)
    for i=0,4 do goods(b,5+i*5,y+1,half and 11 or 23,({7,5,12,11,15})[i+1])end
    if not half then for i=0,4 do goods(b,5+i*5,y+1,5,({11,7,12,5,15})[i+1])end end
  end
  b(3,22,half and 3 or 13,26,1,3,7)
end
for _,kind in ipairs({'mart_fridge','mart_display'})do
  b=model(kind,16,32)
  b(0,0,16,16,2,15,16);b(0,2,16,2,27,14,14);b(14,2,16,2,27,14,14)
  b(2,2,16,12,27,2,8);b(0,29,16,16,2,15,7)
  for _,y in ipairs({3,10,17})do
    b(2,y,18,12,1,11,14)
    for i=0,2 do goods(b,3+i*4,y+1,24,({7,12,15})[i+1])end
  end
  if kind=='mart_fridge' then
    b(7,2,29,1,26,1,14);b(8,12,30,1,5,1,3)
  else
    b(2,24,29,12,4,1,11);b(4,25,30,8,1,1,1)
  end
end
b=model('mart_till',16,16)
b(0,0,0,16,7,16,16);b(0,7,0,16,1,16,7)
b(2,8,4,12,2,10,14);screen(b,4,10,4,9,7)
b(3,10,10,8,1,3,3);for x=4,9,2 do b(x,11,10,1,1,2,14)end
b(12,10,10,2,1,3,12);b(4,5,16,8,1,1,3)
-- The department-store lift is a north-facing doorway. Its walkable native
-- warp cell must not leave the two door tiles painted flat on the floor.
b=model('mart_lift_door',16,16)
b(-2,0,-16,20,30,17,3)
b(-2,0,1,2,28,2,14);b(16,0,1,2,28,2,14)
b(-2,28,1,20,2,2,14)
b(0,1,1,7.5,25,1,8);b(8.5,1,1,7.5,25,1,8)
b(1,2,2,5.5,22,.5,2);b(9.5,2,2,5.5,22,.5,2)
b(0,0,1,16,1,4,14)
b(5,26,2,6,2,1,3);b(7,26.5,3,2,1,.5,12)
b(18,12,0,2,5,1,3);b(18.5,14,1,1,1,.5,12)
for _,kind in ipairs({'healing_station','link_station'})do
  local accent=kind=='healing_station' and 5 or 7
  b=model(kind,32,32)
  -- Recessed deck, rounded cabinet corners, side rails and a broad display.
  b(3,0,9,26,2,21,16);b(4,2,10,24,2,20,3)
  b(4,4,11,24,7,18,14);b(5,4,29,22,6,1,2)
  b(6,10,12,20,2,17,4);b(7,12,13,18,1,15,accent)
  b(3,5,13,2,8,14,2);b(27,5,13,2,8,14,2)
  b(3,13,14,2,1,12,7);b(27,13,14,2,1,12,7)
  b(5,5,29,22,1,1,accent);b(13,6,30,6,3,1,accent)
  b(15,6,31,2,3,1,4);b(14,7,31,4,1,1,4)
  for x=7,11,2 do b(x,7,30,1,1,1,16);b(x+12,7,30,1,1,1,16)end
  b(8,5,6,3,13,5,14);b(21,5,6,3,13,5,14)
  b(3,17,4,26,12,4,14);b(4,16,5,24,14,3,3)
  b(5,18,8,22,11,1,8);b(5,29,5,22,1,3,2)
  b(6,22,9,4,1,1,12);b(7,21,9,1,3,1,12)
  for y=21,25,2 do b(24,y,9,2,1,1,7)end
  for i=0,5 do b(7+i*3,18,9,2,1,1,7)end
  for row=0,2 do for col=0,1 do
    local x,z=11+col*10,16+row*5
    b(x-2,13,z-1,4,1,3,3);b(x-1,14,z,2,1,1,7)
  end end
end
b=model('elevator_control',8,16)
-- The original sign remains the interaction target. The front of this
-- raised panel faces its walkable approach cell, not the panorama wall.
b(1,9,12,6,15,2,3);b(1.5,9.5,14,5,14,1,14)
b(2,19,15,4,3,1,8);b(3,20,16,2,1,.5,12)
for y=11,16,3 do
  b(2,y,15,1.5,1.5,1,7);b(4.5,y,15,1.5,1.5,1,7)
end
F.patterns={
  {kind='elevator_control',sets={LOBBY=true},tiles={{62},{63}},
    maps={CELADON_MART_ELEVATOR=true,SILPH_CO_ELEVATOR=true,ROCKET_HIDEOUT_ELEVATOR=true},
    groundTile=32,guard=function(map,x,y)
      for _,sign in ipairs(map.def.signs or{})do
        if sign.x==math.floor(x/2) and sign.y==math.floor(y/2) then return true end
      end
      return false
    end},
  {kind='mart_lift_door',sets={LOBBY=true},tiles={{40,40},{56,56}},
    maps={CELADON_MART_1F=true,CELADON_MART_2F=true,CELADON_MART_3F=true,
      CELADON_MART_4F=true,CELADON_MART_5F=true},groundTile=32,
    guard=function(map,x,y)
      for _,warp in ipairs(map.def.warps or{})do
        if warp.destMap=='CELADON_MART_ELEVATOR' and warp.x*2==x and warp.y*2==y then return true end
      end
      return false
    end},
  {kind='home_pc',sets={REDS_HOUSE_2=true},tiles={{64,65},{32,33},{66,67},{50,51}}},
  {kind='television',sets={REDS_HOUSE_1=true,REDS_HOUSE_2=true},tiles={{6,7},{22,23}}},
  {kind='switch_console',sets={REDS_HOUSE_2=true},tiles={{14,15},{30,31}}},
  {kind='mart_shelf',sets={MART=true},tiles={{64,65,65,67},{80,81,81,83},{68,69,69,71},{84,85,85,87}}},
  {kind='mart_shelf_half',sets={MART=true},tiles={{64,65,65,67},{80,81,81,83}}},
  {kind='mart_fridge',sets={MART=true},tiles={{90,91},{44,45},{46,47},{62,63}}},
  {kind='mart_display',sets={MART=true},tiles={{40,40},{78,79},{76,77},{23,29}}},
  {kind='mart_till',sets={MART=true},tiles={{14,15},{30,31}}},
  {kind='healing_station',sets={POKECENTER=true,MART=true},tiles={{40,58,59,40},{40,74,75,40},{72,76,77,7},{72,6,22,13}}},
  {kind='link_station',sets={POKECENTER=true,MART=true},tiles={{40,58,59,40},{40,74,75,40},{72,76,77,73},{72,6,22,73}}},
}
F.patterns[#F.patterns+1]={kind='center_pc',sets={POKECENTER=true,MART=true},tiles={{66,70},{82,86},{9,88}}}
V.require('VoxelInteriorModels')(P,F)
local interiorPatterns=V.require('VoxelInteriorPatterns')
for i=#interiorPatterns,1,-1 do table.insert(F.patterns,1,interiorPatterns[i])end
function F.variantKind(kind,map,x,y)
  -- The near bank faces its research table; the far bank faces south.
  if kind=='lounge_chair' and map.id=='CINNABAR_LAB_TRADE_ROOM' and y==10 then
    return 'lounge_chair_south'
  end
  if kind=='wood_chair_north' and map.id=='VIRIDIAN_SCHOOL_HOUSE' and x==6 and y==10 then
    return 'wood_chair_south'
  end
  if kind=='lounge_chair' and map.id=='GAME_CORNER' and y>=20 then
    return 'lounge_chair_'..(x%12==4 and 'left' or 'right')
  end
  if kind=='bookshelf' or kind=='bookshelf_short' then
    return 'bookshelf_'..((math.floor(x/2)+math.floor(y/2))%3)..(kind=='bookshelf_short' and '_short' or '')
  end
  if kind=='museum_skeleton_0' then return 'museum_skeleton_'..(y>=8 and 1 or 0)end
  if kind=='retail_mixed' or kind=='mart_shelf' or kind=='mart_shelf_half' then
    local theme=({CELADON_MART_2F='balls',CELADON_MART_3F='tech',
      CELADON_MART_4F='stones',CELADON_MART_5F='medicine'})[map.id]
    if not theme then theme=({'balls','medicine','mixed'})[(math.floor(x/4)+math.floor(y/4))%3+1]end
    local phase=(math.floor(x/4)+math.floor(y/6))%3
    return 'retail_'..theme..(kind=='mart_shelf_half' and '_half' or '')..(phase>0 and '_v'..phase or '')
  end
  return kind
end
V.require('Gen1RhyhornStatues').register(P,F)
V.require('Gen1GymBallMarkers').register(P,F)
V.require('Gen1PalletVillage').register(P,F)
V.require('Gen1KantoBuildings').register(P,F)
V.require('Gen1TowerEntrance')(P,F)
V.require('Gen1OutdoorScenery').register(P,F)
V.require('Gen1LooseRocks')(P,F)
V.require('Gen1VoxelSigns').register(P,F)
V.require('Gen1FurnitureCompletion')(P,F,V.require('Gen1FurniturePatterns'))
V.require('Gen1Rooftops').register(P,F)
V.require('TowerAtmosphere').register(P)
V.require('CaveTorches').register(P)
local found=setmetatable({},{__mode='k'})
local publishedForMap
local function key(x,y)return (y+64)*4096+x+64 end
function F.invalidateAll()found=setmetatable({},{__mode='k'})end
function F.invalidate(map)
  found[map]=nil
end
function F.find(map)
  -- ChunkMesher/Structures retain terrain by map id across native Map objects.
  -- Reuse its exact replacement descriptors too: fresh unclaimed descriptors
  -- would hide every house although the cached terrain already cut them out.
  local published=publishedForMap and publishedForMap(map)
  if published and published.voxelFurnitureProps then
    found[map]=published.voxelFurnitureProps
  end
  if found[map] then return found[map] end
  local result,used={},{}
  if not map or not map.def or map.def.generation==2 then return result end
  local tw,th=map.def.width*4,map.def.height*4
  -- Index only tiles that can begin a pattern on this map. Previously every
  -- pattern rescanned the complete map, including large empty floor areas.
  -- Pattern priority and row-major match order remain exactly the same.
  local candidates,active={},{}
  for _,p in ipairs(F.patterns)do
    if p.sets[map.def.tileset] and (not p.maps or p.maps[map.id]) then
      active[#active+1]=p
      candidates[p.tiles[1][1]]=candidates[p.tiles[1][1]] or {}
    end
  end
  if #active>0 then
    for y=0,th-1 do for x=0,tw-1 do
      Budget.tick()
      local positions=candidates[map:tileAt(x,y)]
      if positions then positions[#positions+1]=y*tw+x end
    end end
  end
  for _,p in ipairs(active)do
      local h,w=#p.tiles,#p.tiles[1]
      for _,position in ipairs(candidates[p.tiles[1][1]])do
        Budget.tick()
        local x,y=position%tw,math.floor(position/tw)
        if x<=tw-w and y<=th-h
            and (not p.x or p.x==x) and (not p.y or p.y==y)
            and not used[key(x,y)]
            and (not p.guard or p.guard(map,x,y)) then
          local match=true
          for dy=0,h-1 do for dx=0,w-1 do
            if used[key(x+dx,y+dy)] or map:tileAt(x+dx,y+dy)~=p.tiles[dy+1][dx+1] then match=false end
          end end
          if match then
            result[#result+1]={kind=p.variant and p.variant(map,x,y) or F.variantKind(p.kind,map,x,y),
              mapId=map.id,tx=x,ty=y,w=w,h=h,enabled=p.enabled,groundTile=type(p.groundTile)=='function'and p.groundTile(map,x,y)or p.groundTile,voxelOnly=p.voxelOnly,keepTerrain=p.keepTerrain,terrainDecoration=p.terrainDecoration}
            for dy=0,h-1 do for dx=0,w-1 do used[key(x+dx,y+dy)]=true end end
          end
        end
      end
  end
  for _,p in ipairs(V.require('Gen1MountainExteriors').find(P,map,function(x,y)return used[key(x,y)]end))do
    result[#result+1]=p
  end
  for _,p in ipairs(V.require('CaveTorches').find(map,function(x,y)return used[key(x,y)]end))do
    result[#result+1]=p
  end
  found[map]=result;return result
end
local function floorTile(map,x,y)
  if map.def.tileset=='CEMETERY' then return 1 end
  if map.def.tileset=='INTERIOR' then return 31 end
  if map.def.tileset=='CLUB' then return (x+y)%2==0 and 15 or 31 end
  if map.def.tileset=='PLATEAU' then return 35 end
  if map.def.tileset=='DOJO' or map.def.tileset=='GYM' then return 17 end
  if map.def.tileset=='FACILITY' then return 1 end
  if map.def.tileset=='LAB' then return (x+y)%2==0 and 1 or 38 end
  if map.def.tileset=='MUSEUM' then return (x+y)%2==0 and 17 or 1 end
  if map.def.tileset=='LOBBY' then
    if map.id=='GAME_CORNER' or map.id=='GAME_CORNER_PRIZE_ROOM' or map.id=='CELADON_MART_ROOF' then
      return (x+y)%2==0 and 55 or 69
    end
    return 32
  end
  if map.def.tileset=='HOUSE' then return 1 end
  if map.def.tileset=='MANSION' then return 80 end
  if map.def.tileset=='GATE' then return (x+y)%2==0 and 17 or 1 end
  if map.def.tileset=='SHIP' then return (x+y)%2==0 and 13 or 29 end
  if map.def.tileset=='REDS_HOUSE_1' or map.def.tileset=='REDS_HOUSE_2' then return 1 end
  return (y%2==0 and {1,11} or {17,27})[x%2+1]
end
F.floorTile=floorTile
function F.enabled(p)
  if p.enabled then return p.enabled(p) end
  return P.setting:get()
end
function F.claim(S,map,peekTerrain)
  publishedForMap=peekTerrain or publishedForMap
  S.voxelFurnitureClaims={}
  S.furnitureWater={}
  local props=F.find(map)
  S.voxelFurnitureProps=props
  for _,p in ipairs(props)do
    local model=P.models[p.kind]
    p.claimed=F.enabled(p) and P.resolveKind(p.kind)~=nil
      and (not (model and model.glassKind) or P.resolveKind(model.glassKind)~=nil)
    if p.claimed and model and model.cutawayKind then
      local low=P.models[model.cutawayKind]
      p.claimed=P.resolveKind(model.cutawayKind)~=nil
        and (not low.glassKind or P.resolveKind(low.glassKind)~=nil)
    end
    if p.claimed and p.replacesPortal then
      for i=#(S.portalStamps or {}),1,-1 do
        local portal=S.portalStamps[i]
        if portal.baseTx==p.tx and portal.baseTy==p.ty then table.remove(S.portalStamps,i)end
      end
      if S.portalCells then S.portalCells[key(p.tx,p.ty)]=nil end
    end
    if p.claimed and p.terrainDecoration then
      -- Small plants replace their atlas art, not the walkable ground shape.
      -- Keep this tile in the ordinary terrain/grade path; solid furniture
      -- still owns a level foundation through the separate branch below.
      S.topTileAt=S.topTileAt or {}
      for dy=0,p.h-1 do for dx=0,p.w-1 do
        local k=key(p.tx+dx,p.ty+dy)
        S.skip[k]=nil;S.ground[k]=nil
        S.topTileAt[k]=p.groundTile
        S.shapeAt[k]={class='ground',h=0,art='flat',flat=true,authored=true}
      end end
    elseif p.claimed and not p.keepTerrain then
      for dy=0,p.h-1 do for dx=0,p.w-1 do
        local k=key(p.tx+dx,p.ty+dy)
        S.voxelFurnitureClaims[k]=true
        S.skip[k]=true;S.ground[k]=p.groundTile or floorTile(map,p.tx+dx,p.ty+dy)
        S.shapeAt[k]={class='building',h=0,art='building',flat=false,authored=true}
        -- A bridge rail replaces a native bank tree, but its open footprint
        -- must contain the adjoining river, not a raised floor painted blue.
        -- Require a real water neighbour; dry landing cells stay dry.
        if model and model.waterUnderlaySide then
          local wx=model.waterUnderlaySide=='left'and p.tx-1 or p.tx+p.w
          local wy=p.ty+dy
          local wet=S.shapeAt[key(wx,wy)]
          if wet and wet.class=='water' then
            S.furnitureWater[k]={tx=wx,ty=wy,h=wet.h or -2,tile=map:tileAt(wx,wy)}
          end
        end
      end end
    end
  end
  V.require('Gen1Harbor').claim(S,map)
end
function F.prepareTerrainDecoration(S,map)
  V.require('GroundedDecoration').prepare(map,S,F.find(map))
end
-- Live actors and item sprites use the replacement furniture's actual deck,
-- rather than the old tile classifier's taller extrusion.
-- Planning may reserve known furniture even before its GPU mesh is claimed;
-- ordinary actor footing still depends on the active replacement below.
local supportIndices=setmetatable({},{__mode='k'})
local noSupport={}
local function supportQuery(map,px,py,reserveUnclaimed,actorOnly,seam)
  local props=F.find(map)
  local index=supportIndices[map]
  if not index or index.props~=props then
    index={props=props,cells={},actorCells={}};supportIndices[map]=index
    -- Camera visibility casts thousands of ground probes. A tree or house
    -- without a supporting deck must not be scanned for every ray sample.
    -- Keep references, not cached heights, so live claims/options still win.
    for _,p in ipairs(props)do
      local model=P.models[p.kind]
      if model and model.support~=nil then
        for cy=math.floor(p.ty/2),math.ceil((p.ty+p.h)/2)-1 do
          for cx=math.floor(p.tx/2),math.ceil((p.tx+p.w)/2)-1 do
            local k=key(cx,cy);local cell=index.cells[k]
            if not cell then cell={};index.cells[k]=cell end
            cell[#cell+1]=p
            if model.actorSurface then
              local actors=index.actorCells[k]
              if not actors then actors={};index.actorCells[k]=actors end
              actors[#actors+1]=p
            end
          end
        end
      end
    end
  end
  local cells=actorOnly and index.actorCells or index.cells
  for _,p in ipairs(cells[key(math.floor(px/16),math.floor(py/16))]or noSupport)do
    local model=P.models[p.kind]
    if (reserveUnclaimed or (p.claimed and F.enabled(p))) and model and model.support and px>=p.tx*8 and px<(p.tx+p.w)*8
        and py>=p.ty*8 and py<(p.ty+p.h)*8
        and (not actorOnly or model.actorSurface)
        and (not seam or model.supportSeam==seam) then
      local h=model.support
      if type(h)=='function' then h=h(px-p.tx*8,py-p.ty*8)end
      if model.supportRelative then
        -- Match the exact datum used by F.each when placing this terrain prop.
        local elevation=V.require('LedgeElevation')
        local x,y=math.floor((p.tx+p.w/2)/2),math.floor((p.ty+p.h-1)/2)
        h=h+elevation.basisAtCell(map,x,y)
      end
      return h
    end
  end
end
function F.supportAt(map,px,py,reserveUnclaimed)
  return supportQuery(map,px,py,reserveUnclaimed)
end
-- Actor coordinates name the cell's northwest corner; rendered feet sit at
-- +8,+8. Only authored walkable surfaces opt into per-position footing.
-- A bridge that crosses a native seam may extend its proven end height for
-- the one out-of-bounds step used by the engine, never across a side railing.
function F.actorSupportAt(map,px,py)
  local x,y=px+8,py+8
  local height=map and map.def and tonumber(map.def.height)
  local seam
  if height then
    height=height*32
    if y<0 and y>=-16 then y=0;seam='north'
    elseif y>=height and y<height+16 then y=height-0.001;seam='south' end
  end
  return supportQuery(map,x,y,false,true,seam)
end
function F.activeHealer(state)
  local ha=state and state.healAnim
  if not ha then return end
  local best,distance
  for _,p in ipairs(F.find(state.map))do
    if p.kind=='healing_station' then
      local d=(p.tx*8+16-(ha.px-24))^2+(p.ty*8+24-(ha.py-32))^2
      if not distance or d<distance then best,distance=p,d end
    end
  end
  return best,ha
end
function F.each(state,draw)
  if state.sightFurniture then
    for _,p in ipairs(state.sightFurniture)do draw(p.mesh,p.tex,p.mat,p.shade,p.extra)end
    return
  end
  local elevation, heights
  for _,p in ipairs(F.find(state.map))do
    if F.enabled(p) and p.claimed then
      local decoration=p.terrainDecoration and p.decorPlacement
      local kind=decoration and decoration.kind or p.kind
      local model=P.models[p.kind];local cut=state.landmarkCutaway and model and model.cutawayKind
      if cut then kind=cut;model=P.models[kind]end
      local mesh,tex=P.resolveKind(kind)
      local extra
      if model and model.glassKind and (not model.glassVisible or model.glassVisible(state.map)) then
        local glass,glassTex=P.resolveKind(model.glassKind)
        if glass then
          if cut then p.cutawayExtra=p.cutawayExtra or {};extra=p.cutawayExtra
          else p.drawExtra=p.drawExtra or {};extra=p.drawExtra end
          extra.mesh,extra.tex,extra.glow=glass,glassTex,model.windowLight and model.windowLight()or 0
        end
      end
      if mesh then
        local base=0
        if decoration then
          base=decoration.base
        elseif model and model.terrain then
          elevation=elevation or V.require('LedgeElevation')
          if not heights and type(elevation.map)=='function' then heights=elevation.map(state.map)end
          local x,y=math.floor((p.tx+p.w/2)/2),math.floor((p.ty+p.h-1)/2)
          base=heights and heights:at(x,y)or elevation.basisAtCell(state.map,x,y)
        end
        local mat=p.drawMatrix
        if not mat or mat[4]~=p.tx*8 or mat[8]~=base or mat[12]~=p.ty*8 then
          mat=M.translate(p.tx*8,base,p.ty*8);mat._voxelStatic=true;p.drawMatrix=mat
        end
        draw(mesh,tex,mat,1,extra)
      end
    end
  end
  V.require('Gen1Harbor').each(state,draw)
  local p,ha=F.activeHealer(state)
  if p and P.setting:get() then
    local mesh,tex=P.resolveKind('ball')
    if mesh then
      for i=1,math.min(6,tonumber(ha.lit) or 0)do
        local cx,cz=11+((i-1)%2)*10,16+math.floor((i-1)/2)*5
        local mat=M.mul(M.translate(p.tx*8+cx-3.6,14,p.ty*8+cz-3.6),M.scale(.45,.45,.45))
        draw(mesh,tex,mat,ha.visible==false and .4 or 1)
      end
    end
  end
end
-- A battle captures the same stationary furniture repeatedly. Retain its
-- prepared descriptors while checking live visibility/claims and resource
-- ownership. Moving harbor props and healing animations use ordinary each().
local snapshots=setmetatable({},{__mode='k'})
function F.snapshot(state)
  if not state or not state.map or state.sightFurniture or state.healAnim
      or V.require('Gen1Harbor').kind(state.map) then return nil end
  local map=state.map
  local props=F.find(map)
  local elevation=V.require('LedgeElevation')
  local heights=type(elevation.map)=='function' and elevation.map(map) or nil
  local previous=snapshots[map]
  local changed=not previous or previous.props~=props or previous.heights~=heights
    or previous.version~=P.resourceVersion or previous.source~=F.each
  local stamps=previous and previous.stamps or {}
  local active=0
  for i,p in ipairs(props)do
    local enabled=p.claimed and F.enabled(p) or false
    local model=P.models[p.kind]
    local glass=model and model.glassKind
    local visible=glass and (not model.glassVisible or model.glassVisible(map)) or false
    local old=stamps[i]
    if not old or old.p~=p or old.kind~=p.kind or old.model~=model
        or old.enabled~=enabled or old.glass~=glass or old.visible~=visible
        or old.x~=p.tx or old.y~=p.ty or old.w~=p.w or old.h~=p.h
        or old.decoration~=p.decorPlacement then
      stamps[i]={p=p,kind=p.kind,model=model,enabled=enabled,glass=glass,
        visible=visible,x=p.tx,y=p.ty,w=p.w,h=p.h,decoration=p.decorPlacement}
      changed=true
    end
    if enabled then active=active+1 end
  end
  if #stamps~=#props then for i=#stamps,#props+1,-1 do stamps[i]=nil end;changed=true end
  if changed then
    local entries,lights={},{}
    F.each(state,function(mesh,tex,mat,shade,extra)
      entries[#entries+1]={mesh=mesh,tex=tex,mat=mat,shade=shade,extra=extra}
    end)
    -- A failed GPU resolve must be retried, never cached as an empty scene.
    if #entries~=active then snapshots[map]=nil;return entries end
    -- Ownership token for consumers: geometry descriptors remain unchanged
    -- until this array is replaced. Only extra.glow is updated in place.
    entries._voxelStaticSnapshot=true
    for _,stamp in ipairs(stamps)do
      local p,model=stamp.p,stamp.model
      if stamp.enabled and stamp.visible and p.drawExtra then
        lights[#lights+1]={extra=p.drawExtra,model=model}
      end
    end
    previous={props=props,heights=heights,version=P.resourceVersion,
      source=F.each,stamps=stamps,entries=entries,lights=lights}
    snapshots[map]=previous
  else
    -- Pane intensity and candle flicker stay live; neither changes geometry.
    for _,light in ipairs(previous.lights)do
      light.extra.glow=light.model.windowLight and light.model.windowLight() or 0
    end
  end
  return previous.entries
end
-- The published terrain plan owns the visible neighborhood. Replacement
-- props must follow that same plan: claiming their tiles removes the native
-- geometry even when their map is only a neighbor. Keep each() map-local for
-- battle snapshots, which already enumerate and translate their own maps.
local shiftedMatrices=setmetatable({},{__mode='k'})
function F.eachWorld(state,draw)
  F.each(state,draw)
  if state.sightFurniture then return end -- already a complete world snapshot
  local seen={[state.map]=true}
  for _,nb in ipairs(state.neighbors or {})do
    if nb.map and not seen[nb.map]then
      seen[nb.map]=true
      F.each({map=nb.map},function(mesh,tex,mat,shade,extra)
        local ox,oz=nb.ox or 0,nb.oy or 0
        local shifted
        if mat._voxelStatic then
          local saved=shiftedMatrices[mat]
          if not saved or saved.ox~=ox or saved.oz~=oz then
            shifted=M.translate(mat[4]+ox,mat[8],mat[12]+oz);shifted._voxelStatic=true
            saved={ox=ox,oz=oz,mat=shifted};shiftedMatrices[mat]=saved
          end
          shifted=saved.mat
        else shifted=M.mul(M.translate(ox,0,oz),mat)end
        draw(mesh,tex,shifted,shade,extra)
      end)
    end
  end
end
function F.shadowHeight(state)
  local height=160
  local function include(map)
    for _,p in ipairs(F.find(map))do
      local m=P.models[p.kind]
      if p.claimed and m and m.landmarkHeight then height=math.max(height,m.landmarkHeight+16)end
    end
  end
  include(state.map)
  for _,nb in ipairs(state.neighbors or{})do if nb.map then include(nb.map)end end
  return height
end
function F.drawProp(mesh,tex,mat,shade,extra)
  local light=shade or 1;love.graphics.setColor(light,light,light,1)
  if extra and extra.batchWindow then
    if extra.glow>0 then G.flatten({1,.78,.38},extra.glow)end
    local drawn=G.draw(mesh,tex,mat,0)
    if extra.glow>0 then G.flatten(nil)end
    return drawn
  end
  local drawn=G.draw(mesh,tex,mat,0)
  if drawn==false then return false end
  if extra then
    if extra.glow>0 then G.flatten({1,.78,.38},extra.glow)end
    G.draw(extra.mesh,extra.tex,mat,0)
    if extra.glow>0 then G.flatten(nil)end
  end
  return drawn
end
function F.draw(state)
  if not state.sightFurniture and state.map and state.map.id=='SAFFRON_CITY'
      and V.require('Gen1SilphCo').occludes(state.map,
      V.require('VoxelState').level,G.eye,G.focus)then
    local view={};for k,v in pairs(state)do view[k]=v end
    view.landmarkCutaway=true;state=view
  end
  local visible=V.require('PropVisibility').forView(G.vp,G.curveK,G.curveX,G.curveZ)
  local function each(view,draw)
    F.eachWorld(view,function(mesh,tex,mat,shade,extra)
      if not P.bounds or visible(P.bounds(mesh),mat)
        or (extra and visible(P.bounds(extra.mesh),mat))then draw(mesh,tex,mat,shade,extra)end
    end)
  end
  V.require('VoxelPropBatch').draw(state,each,F.drawProp)
  love.graphics.setColor(1,1,1,1)
  local p,ha=F.activeHealer(state)
  local visible=not state.sightFurniture
  if p and state.sightFurniture then
    for _,entry in ipairs(state.sightFurniture)do
      if entry.mat[4]==p.tx*8 and entry.mat[12]==p.ty*8 then visible=true;break end
    end
  end
  if visible and P.setting:get() and p and p.claimed then V.require("VoxelHealingDisplay").draw(p,ha)end
end
function F.cast(state,shadow)
  local visible=V.require('PropVisibility').forView(shadow.clipVP)
  local function each(view,draw)
    F.eachWorld(view,function(mesh,tex,mat,shade,extra)
      if not P.bounds or visible(P.bounds(mesh),mat)
        or (extra and visible(P.bounds(extra.mesh),mat))then draw(mesh,tex,mat,shade,extra)end
    end)
  end
  V.require('VoxelPropBatch').draw(state,each,function(mesh,tex,mat,shade,extra)
    shadow.draw(mesh,tex,mat)
    if extra and extra.mesh then shadow.draw(extra.mesh,extra.tex,mat)end
  end,'shadow')
end
local images={}
local function image(kind)
  if images[kind]==nil then
    local ok,img=pcall(Assets.image,V.path..'/assets/voxel_items/'..kind..'.png')
    images[kind]=ok and img or false
  end
  return images[kind] or nil
end
function F.draw2D(renderer,camX,camY)
  if not P.setting:get() then return end
  local g=love.graphics;local map=renderer.map
  if not P.use2D(map) then return end
  local PaletteFX=require('src.render.PaletteFX')
  local Game=require('src.core.Game')
  local active,ha=F.activeHealer(Game.overworld)
  for _,p in ipairs(F.find(map))do
    local img=not p.voxelOnly and image(p.kind)
    if img then
      local x,y=p.tx*8-math.floor(camX),p.ty*8-math.floor(camY)
      g.setColor(1,1,1,1)
      for dy=0,p.h-1 do for dx=0,p.w-1 do
        local quad=renderer.quads[floorTile(map,p.tx+dx,p.ty+dy)]
        if quad then g.draw(renderer.image,quad,x+dx*8,y+dy*8)end
      end end
      local model=P.models[p.kind]
      local iy=y+model.offsetY
      PaletteFX.markTrueColor(x,iy,model.frameW,model.frameH)
      g.draw(img,x,iy,0,.25,.25)
      if active==p and Game.overworld.map==map then
        local ball=image('ball')
        if ball then
          for i=1,math.min(6,tonumber(ha.lit) or 0)do
            local cx,cz=11+((i-1)%2)*10,16+math.floor((i-1)/2)*5
            local by=model.frameH+(cz-model.depth)*.65-14*.65-2
            local v=ha.visible==false and .4 or 1;g.setColor(v,v,v,1)
            g.draw(ball,x+cx-3.84,iy+by-5,0,.12,.12)
          end
          g.setColor(1,1,1,1)
        end
      end
    end
  end
end
function F.install2D()
  local Renderer=require('src.render.TileRenderer')
  if not Renderer.voxelFurnitureDraw then
    local original=Renderer.drawWindow;Renderer.voxelFurnitureDraw=original
    Renderer.drawWindow=function(self,camX,camY,...)
      original(self,camX,camY,...);F.draw2D(self,camX,camY)
    end
  end
  local World=require('src.world.OverworldController')
  if not World.voxelFurnitureHeal then
    local original=World.drawWorld;World.voxelFurnitureHeal=original
    World.drawWorld=function(self,...)
      local pipeline=require('src.render.Pipelines').worldPipeline()
      local voxel=pipeline=='voxel' and V.require('VoxelState').ready
      if not P.setting:get() or not F.activeHealer(self)
          or not (voxel or P.use2D(self.map)) then return original(self,...)end
      -- Only the obsolete FX artwork is hidden. The actual healing state,
      -- count, timing, sound, party restoration and completion callback run.
      local previous,quads=self.healMachineImg,self.healMachineQuads
      self.healMachineImg=false;self.healMachineQuads=nil
      local ok,result=pcall(original,self,...)
      self.healMachineImg,self.healMachineQuads=previous,quads
      if not ok then error(result,0)end
      return result
    end
  end
end
Assets.register(function()found=setmetatable({},{__mode='k'});images={}end)
return F
