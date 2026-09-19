-- The visual hill finish must never put a raised rock on native walking or
-- warp cells, including stairs; it must be repeatable and cell-contained.
local root=arg[1]or'.'
local settings={new=function(_,_,values)
 local s={value=values[1]};function s:get()return self.value end;return s
end}
local V={require=function(name)assert(name=='ModSetting');return settings end}
local O=assert(loadfile(root..'/lib/Gen1OutdoorScenery.lua'))(V)
local map={id='SAFARI_ZONE_EAST',def={tileset='FOREST',generation=1},
 isWalkableCell=function(self)return self.walkable end,
 isWarpTileCell=function(self)return self.warp end}
local walls={14,15,29,31,45,47,61,62,63}
local function crown(tile,class)
 local faces={}
 local yes=O.safariRockCrown(map,class or 'wall',tile,10,12,24,function(q,uv,shade)
  faces[#faces+1]=q
  for i,p in ipairs(q)do
   assert(p[1]>=80 and p[1]<=88 and p[3]>=96 and p[3]<=104,'rock spills into another tile')
   assert(p[2]>=24 and p[2]<=38,'rock leaves its bounded crown')
   assert(uv[i][1]==-175,'old atlas art survives in crown')
  end
  assert(shade>0 and shade<=1)
 end)
 return yes,faces
end
for _,id in ipairs({'SAFARI_ZONE_CENTER','SAFARI_ZONE_EAST','SAFARI_ZONE_NORTH','SAFARI_ZONE_WEST'})do
 map.id=id
 for _,tile in ipairs(walls)do
  map.walkable,map.warp=false,false
  local yes,faces=crown(tile);assert(yes and #faces>=16 and #faces<=80)
  local tops={};local area=0
  for _,q in ipairs(faces)do
   if q[1][2]==q[2][2]and q[2][2]==q[3][2]and q[3][2]==q[4][2]then
    area=area+(q[2][1]-q[1][1])*(q[4][3]-q[1][3]);tops[q[1][2]]=true
   end
  end
  assert(area==64,'cap contains a hole or overlapping top faces')
  local n=0;for _ in pairs(tops)do n=n+1 end;assert(n>=3,'rim is flat')
  local _,again=crown(tile);assert(#again==#faces)
  for i,q in ipairs(faces)do for j,p in ipairs(q)do for axis=1,3 do assert(p[axis]==again[i][j][axis])end end end
  map.walkable=true;local admitted,none=crown(tile);assert(not admitted and #none==0)
  map.walkable=false;map.warp=true;admitted,none=crown(tile);assert(not admitted and #none==0)
 end
 map.walkable,map.warp=false,false
 for _,tile in ipairs({0,20,30,32,33,34,46,48,49,50,64,65,84,85,86,87})do
  assert(not crown(tile),'floor, water, stairs, sign or separate boulder claimed')
 end
 assert(not crown(46,'ledge'),'walkable raised floor changed')
end
map.id='VIRIDIAN_FOREST';assert(not crown(45));assert(O.wallMaterial(map,'wall',45)==nil)
map.id='SAFARI_ZONE_EAST';map.def.generation=2;assert(not crown(45))
map.def.generation=1;O.stone.value=false;assert(not crown(45));assert(O.wallMaterial(map,'wall',45)==nil)
print('PASS Safari stone crowns: bounds, complete cap, varied heights, determinism, walking/warp/stair guards, map/generation/setting isolation')
