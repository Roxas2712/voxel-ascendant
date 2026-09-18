-- Solid Rhydon (Rizeros) stonework for the remaining native, freestanding statues.
-- Exact figure + plinth masks distinguish them from pillars, walls and graves.
-- Rendering only: the original tiles still own collision and statue switches.
local M={}
M.specs={
 ROUTE_22_GATE={'GATE',5,4},
 LANCES_ROOM={'DOJO',13,13},LORELEIS_ROOM={'GYM',5,6},
 BRUNOS_ROOM={'GYM',5,6},CHAMPIONS_ROOM={'GYM',4,4},
 INDIGO_PLATEAU={'PLATEAU',10,9},ROUTE_23={'PLATEAU',10,72},
 POKEMON_MANSION_1F={'FACILITY',15,14},POKEMON_MANSION_2F={'FACILITY',15,14},
 POKEMON_MANSION_3F={'FACILITY',15,9},POKEMON_MANSION_B1F={'FACILITY',15,14},
 POKEMON_FAN_CLUB={'INTERIOR',4,4},SILPH_CO_11F={'INTERIOR',9,9},
}
M.masks={GATE={{0,0},{14,15},{30,31},{50,51}},
 GYM={{2,56},{18,19},{34,35},{50,51}},
 DOJO={{2,56},{18,19},{34,35},{50,51}},
 FACILITY={{1,1},{39,47},{55,63},{61,62}},
 PLATEAU={{16,18},{40,41},{21,22},{48,49}},
 INTERIOR={{17,18},{33,34},{91,92}}}
function M.register(P,F)
 local stone=P.decorColors.silver
 local body={}
 local function b(x,y,z,w,h,d,c)body[#body+1]={x,y,z,w,h,d,c or stone}end
 -- Upright Rhydon: two broad feet, a plated belly and separate clawed arms.
 -- Keep the historical model keys so existing furniture consumers stay valid.
 b(3,14,16,4,7,7);b(9,14,16,4,7,7)
 b(2,14,20,5,3,7);b(9,14,20,5,3,7)
 for _,x in ipairs({2,4,6,9,11,13})do b(x,14,26,1,2,2,14)end
 b(3,20,14,10,9,10);b(4,26,15,8,8,9)
 b(4,23,23,8,7,1,14) -- pale segmented abdominal armour
 b(5,30,23,6,3,1,14)
 for _,y in ipairs({24,27,30})do b(5,y,24,6,1,1,16)end
 -- Rounded shoulder armour and arms at the sides, not another pair of legs.
 b(1,28,16,3,5,6);b(12,28,16,3,5,6)
 b(0,25,18,3,5,5);b(13,25,18,3,5,5)
 b(0,23,21,3,4,4);b(13,23,21,3,4,4)
 for _,x in ipairs({0,2,13,15})do b(x,23,24,1,3,1,14)end
 -- Thick tapering tail counterbalances the upright torso.
 b(5,19,10,6,6,6);b(6,17,6,4,5,5)
 b(7,16,3,2,4,4);b(7,17,1,2,2,2)
 for _,y in ipairs({23,27,31})do b(6,y,13,4,2,2,14)end
 -- Neck, angular cheeks, brow and projecting rhino muzzle.
 b(5,32,17,6,3,6);b(3,34,16,10,7,9)
 b(2,34,20,12,4,5);b(4,33,24,8,5,4)
 b(5,34,28,6,3,1);b(4,33,25,8,1,3,16)
 b(3,40,18,10,2,5,14)
 b(2,37,23,2,2,2,3);b(12,37,23,2,2,2,3)
 b(2,38,23,2,1,1,14);b(12,38,23,2,1,1,14)
 b(4,35,28,1,1,1,16);b(11,35,28,1,1,1,16)
 -- Rhydon's tall side ears and single forward drill horn.
 b(3,41,17,3,3,3);b(10,41,17,3,3,3)
 b(3,44,17,2,2,2,14);b(11,44,17,2,2,2,14)
 b(4,42,19,1,2,1,16);b(11,42,19,1,2,1,16)
 b(6,38,25,4,3,3,14);b(7,39,28,2,3,2,14)
 b(7,40,30,2,2,1,14);b(7,41,31,1,1,1,14)
 local model={boxes={},frameW=16,frameH=48,depth=32,offsetY=-16}
 local boxes=model.boxes
 boxes[#boxes+1]={0,0,0,16,2,32,16}
 boxes[#boxes+1]={1,2,9,14,10,17,stone}
 boxes[#boxes+1]={0,12,8,16,2,19,14}
 boxes[#boxes+1]={3,4,26,10,6,1,16}
 boxes[#boxes+1]={5,6,27,6,1,1,14}
 for _,box in ipairs(body)do boxes[#boxes+1]=box end
 P.models.rhyhorn_statue=model
 -- The small Route22 gate has a lower room shell than the League halls.
 -- Fit this same Rhydon sculpture to its original compact plinth; quantise
 -- shared boundaries together so its solid body stays connected.
 local gate={boxes={},step=.5,frameW=16,frameH=48,depth=32,offsetY=-16}
 local function scaled(v)return math.floor(v*.7*2+.5)/2 end
 for _,box in ipairs(boxes)do
  local x,y,z,w,h,d,c=unpack(box)
  gate.boxes[#gate.boxes+1]={2+scaled(x),scaled(y),4+scaled(z),
   scaled(x+w)-scaled(x),scaled(y+h)-scaled(y),scaled(z+d)-scaled(z),c}
 end
 P.models.rhyhorn_gate_statue=gate
 -- Tabletop ornaments retain a solid eight-pixel support in their old mask.
 local small={boxes={{0,0,0,16,8,24,stone}},step=.5,
  frameW=16,frameH=40,depth=24,offsetY=-16}
 for _,box in ipairs(boxes)do
  local x,y,z,w,h,d,c=unpack(box)
  small.boxes[#small.boxes+1]={4+x*.5,8+y*.5,4+z*.5,w*.5,h*.5,d*.5,c}
 end
 P.models.rhyhorn_table_statue=small
 -- The repeated Route23 relief uses a different crown above a solid
 -- pillar cell. Retain that support and fit the existing Rhydon on top.
 -- Gate-corner reliefs use another mask and belong to whole buildings.
 local masonry=P.decorColors.stone or 14
 local pillar={terrain=true,boxes={{1,0,17,14,32,14,masonry},{0,0,16,16,2,16,masonry},{0,30,16,16,2,16,14}},step=.5,
  frameW=16,frameH=64,depth=32,offsetY=-32}
 for y=8,24,8 do
  for _,edge in ipairs({{1,y,17,14,.5,.5},{1,y,30.5,14,.5,.5},{1,y,17,.5,.5,14},{14.5,y,17,.5,.5,14}})do
   edge[7]=14;pillar.boxes[#pillar.boxes+1]=edge
  end
 end
 for _,box in ipairs(body)do
  local x,y,z,w,h,d,c=unpack(box)
  pillar.boxes[#pillar.boxes+1]={4+x*.5,32+(y-14)*.5,16+(z-1)*.5,w*.5,h*.5,d*.5,c}
 end
 P.models.rhydon_pillar_statue=pillar
 for _,mask in ipairs({{{37,38},{40,41},{46,47},{46,47}},{{37,38},{40,41},{21,22},{5,6}}})do
 F.patterns[#F.patterns+1]={kind='rhydon_pillar_statue',maps={ROUTE_23=true},sets={PLATEAU=true},
  tiles=mask,
  guard=function(map,x,y)
   local d=map.def
   if d.generation==2 or d.tileset~='PLATEAU'or d.width~=10 or d.height~=72 or y==58 or x%2~=0 or y%2~=0 then return false end
   for cy=y/2,y/2+1 do
    if map:isWalkableCell(x/2,cy)or map:isWarpTileCell(x/2,cy)then return false end
   end
   return true
  end}
 end
 for id,spec in pairs(M.specs)do
  local id,spec=id,spec
  -- Gate statues use the same plinth but have either wall or floor behind
  -- their crown; both masks span the same two blocked native cells.
  local masks={M.masks[spec[1]]}
  if spec[1]=='GATE' then masks[2]={{17,1},{14,15},{30,31},{50,51}} end
  for _,mask in ipairs(masks)do
  F.patterns[#F.patterns+1]={kind=spec[1]=='INTERIOR' and 'rhyhorn_table_statue' or spec[1]=='GATE' and 'rhyhorn_gate_statue' or 'rhyhorn_statue',
   maps={[id]=true},sets={[spec[1]]=true},tiles=mask,
   guard=function(map,x,y)
    local d=map.def
    if d.generation==2 or d.tileset~=spec[1] or d.width~=spec[2] or d.height~=spec[3] then return false end
    if spec[1]=='INTERIOR' then return true end
    if x%2~=0 or y%2~=0 then return false end
    for cy=y/2,y/2+1 do
     if map:isWalkableCell(x/2,cy) or map:isWarpTileCell(x/2,cy) then return false end
    end
    return true
   end}
  end
 end
end
return M
