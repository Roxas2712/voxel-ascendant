-- Whole, native-footprint loose rocks. Continuous cave walls and movable
-- Strength objects keep their separate geometry/interaction owners.
local V=...
return function(P,F)
 local setting=V.require('Gen1OutdoorScenery').stone
 local colors={}
 for i=1,6 do colors[i]=P.decorColors['looseRock'..i]or(i%3==0 and 14 or 16)end
 for family=1,2 do for variant=1,4 do
  local kind='loose_rock_'..family..'_'..variant
  local boxes={}
  P.models[kind]={boxes=boxes,step=1,frameW=16,frameH=32,depth=16,offsetY=-16,terrain=true}
  for x=0,14,2 do for z=0,14,2 do
   local dx,dz=(x+1-7-variant%2)/7,(z+1-8)/7
   local r=dx*dx+dz*dz
   local shoulder=((x*7+z*3+variant*11)%7-3)*.05
   if r<.94+shoulder then
    local h=math.min(16,math.max(2,math.floor((1-r*.62)*14+shoulder*7)))
    local base=colors[(family-1)*3+1]
    local middle=colors[(family-1)*3+2]
    local top=colors[(family-1)*3+3]
    local split=math.min(h-1,4+math.floor((x+z+variant*2)/6)%4)
    boxes[#boxes+1]={x,0,z,2,split,2,base}
    boxes[#boxes+1]={x,split,z,2,h-split,2,middle}
    if (x+z+variant)%4==0 then boxes[#boxes+1]={x,h-1,z,2,1,2,top}end
   end
  end end
 end end
 local function on()return setting:get()end
 local function solid(map,x,y)
  return map.def.generation~=2 and not map:isWalkableCell(math.floor(x/2),math.floor(y/2))
    and not map:isWarpTileCell(math.floor(x/2),math.floor(y/2))
 end
 local function variant(map,x,y)
  local family=map.def.tileset=='CAVERN'and 2 or 1
  return 'loose_rock_'..family..'_'..(1+(math.floor(x/2)*7+math.floor(y/2)*11)%4)
 end
 -- Native cliff end-caps ($35/$37 over $24/$35), not a hop-down
 -- cell: replace the isolated patterned cube with our shared grey boulder.
 F.patterns[#F.patterns+1]={kind='loose_rock_1_1',sets={OVERWORLD=true},
  tiles={{53,55},{36,53}},groundTile=44,voxelOnly=true,enabled=on,guard=solid,variant=variant}
 F.patterns[#F.patterns+1]={kind='loose_rock_1_1',sets={GYM=true},
  tiles={{7,8},{23,24}},groundTile=17,voxelOnly=true,enabled=on,guard=solid,variant=variant}
 F.patterns[#F.patterns+1]={kind='loose_rock_2_1',sets={CAVERN=true},
  tiles={{14,15},{30,31}},groundTile=32,voxelOnly=true,enabled=on,
  guard=function(map,x,y)
   if not solid(map,x,y)then return false end
   local free=0
   for _,d in ipairs({{-1,0},{1,0},{0,-1},{0,1}})do
    if map:isWalkableCell(math.floor(x/2)+d[1],math.floor(y/2)+d[2])then free=free+1 end
   end
   return free>=2 -- never turn a continuous wall into separated props
  end,variant=variant}
end
