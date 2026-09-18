-- Sparse wall-mounted lamps beside real entrances/ladder landings.
-- This is visual furniture only: never claim floors, add collision or light FLASH maps.
local V=...
local M={}
M.setting=V.require('ModSetting').new('caveTorches','WALL TORCHES',{true,false},{'ON','OFF'},true)
local caves={MT_MOON_1F=true,MT_MOON_B1F=true,MT_MOON_B2F=true,
 ROCK_TUNNEL_1F=true,ROCK_TUNNEL_B1F=true,DIGLETTS_CAVE=true,
 VICTORY_ROAD_1F=true,VICTORY_ROAD_2F=true,VICTORY_ROAD_3F=true,
 CERULEAN_CAVE_1F=true,CERULEAN_CAVE_2F=true,CERULEAN_CAVE_B1F=true}
local rock={};for _,t in ipairs({2,3,18,19,12,13,28,29,16,17,49,23,4,7,40,37,38,14,15,30,31,6,39,36,1})do rock[t]=true end
local masonry={[9]=true,[10]=true,[25]=true,[26]=true,[17]=true}
local caveFloor={[5]=true,[41]=true,[32]=true,[33]=true,[42]=true,[35]=true}
local dirs={{0,1},{1,0},{0,-1},{-1,0}}
local unlit={.085,.085,.10}
function M.nativeTint(map,dark,normal)
 -- Authored textures bypass the native atlas's DARK_BGP palette. Restore
 -- that darkness for both real Rock Tunnel floors, independently of the
 -- cosmetic switch. Only the game's FLASH state may remove this tint.
 if dark and map and map.def and map.def.generation~=2
   and map.def.tileset=='CAVERN'and(map.id=='ROCK_TUNNEL_1F'or map.id=='ROCK_TUNNEL_B1F')then return unlit end
 return normal
end
function M.eligible(map)
 local d=map and map.def;local id=map and map.id
 if not d or d.generation==2 then return false end
 return d.tileset=='CAVERN'and caves[id]or d.tileset=='CEMETERY'
  and(id=='POKEMON_TOWER_1F'or id=='POKEMON_TOWER_7F')or false
end
function M.enabled()return M.setting:get()and V.require('VoxelItems').setting:get()end
function M.find(map,occupied)
 local result={}
 if not M.eligible(map)or not map.isWalkableCell then return result end
 local d=map.def;local tower=d.tileset=='CEMETERY';local walls=tower and masonry or rock
 local floors=tower and{[1]=true}or caveFloor
 local candidates={}
 local function clear(cx,cy,mask)
  for dy=0,1 do for dx=0,1 do
   local x,y=cx*2+dx,cy*2+dy
   if not mask[map:tileAt(x,y)]or occupied and occupied(x,y)then return false end
  end end
  return true
 end
 local function wallFace(x,y,dir)
  -- Cave ridges contain rock-top tiles inside their blocked cell. Check
  -- the two actual rim tiles facing the floor, not an all-rock 16px mask.
  for i=0,1 do
   local dx=dir==2 and 1 or dir==4 and 0 or i
   local dy=dir==1 and 1 or dir==3 and 0 or i
   if not walls[map:tileAt(x*2+dx,y*2+dy)]then return false end
  end
  for dy=0,1 do for dx=0,1 do
   if occupied and occupied(x*2+dx,y*2+dy)then return false end
  end end
  return true
 end
 for y=0,d.height*2-1 do for x=0,d.width*2-1 do
  if not map:isWalkableCell(x,y)then
   for dir,delta in ipairs(dirs)do
    local fx,fy=x+delta[1],y+delta[2]
    if fx>=0 and fy>=0 and fx<d.width*2 and fy<d.height*2
      and wallFace(x,y,dir)and map:isWalkableCell(fx,fy)and clear(fx,fy,floors)then
     local distance=math.huge;local safe=true
     for _,w in ipairs(d.warps or{})do
      local ds=math.abs(fx-w.x)+math.abs(fy-w.y)
      distance=math.min(distance,ds)
      if ds<3 then safe=false end
     end
     for _,obj in ipairs(d.objects or{})do
      if obj.x and obj.y and math.abs(fx-obj.x)+math.abs(fy-obj.y)<3 then safe=false end
     end
     if safe and distance<=7 then candidates[#candidates+1]={x=x,y=y,dir=dir,distance=distance,fx=fx,fy=fy}end
    end
   end
  end
 end end
 table.sort(candidates,function(a,b)
  if a.distance~=b.distance then return a.distance<b.distance end
  if a.y~=b.y then return a.y<b.y end
  if a.x~=b.x then return a.x<b.x end
  return a.dir<b.dir
 end)
 for _,c in ipairs(candidates)do
  local separate=true
  for _,p in ipairs(result)do if(c.x-p.tx/2)^2+(c.y-p.ty/2)^2<64 then separate=false end end
  if separate then
   local delta=dirs[c.dir]
   result[#result+1]={kind='wall_torch_'..c.dir,mapId=map.id,tx=c.x*2,ty=c.y*2,w=2,h=2,
    keepTerrain=true,voxelOnly=true,enabled=M.enabled,
    torchLight={c.x*16+8+delta[1]*10,c.y*16+8+delta[2]*10},
    approachX=c.fx,approachY=c.fy}
   if #result>=(tower and 2 or 4)then break end
  end
 end
 return result
end
function M.register(P)
 local colors=P.decorColors or{}
 local body={{6,7,14,4,7,2,colors.navy or 3},{7,8,16,2,3,2,colors.slate or 16},
  {7,10,16,2,8,2,colors.walnut or 5},{6,16,15,4,3,3,colors.navy or 3}}
 local flame={{6,19,15,4,2,3,1},{7,21,16,2,3,2,11},{7,19,16,1,2,1,4}}
 local function rotated(boxes,dir)
  local out={}
  for _,b in ipairs(boxes)do
   local x,y,z,w,h,depth,color=unpack(b)
   for _=2,dir do x,z,w,depth=z,16-x-w,depth,w end
   out[#out+1]={x,y,z,w,h,depth,color}
  end
  return out
 end
 for dir=1,4 do
  local kind='wall_torch_'..dir;local extra=kind..'_flame'
  P.models[kind]={boxes=rotated(body,dir),step=1,frameW=16,frameH=48,depth=16,offsetY=-32,
   glassKind=extra,windowLight=function()return V.require('TowerAtmosphere').candleLight()end}
  P.models[extra]={boxes=rotated(flame,dir),step=1,frameW=16,frameH=48,depth=16,offsetY=-32}
 end
end
return M
