local root=arg[1] or '.'
local M=assert(loadfile(root..'/lib/Gen1InteriorLayout.lua'))({data=function()return dofile(root..'/data/voxel_heights.lua')end,require=function(n)return assert(loadfile(root..'/lib/'..n..'.lua'))()end})
local P=assert(loadfile(root..'/lib/Gen1InteriorPanoramas.lua'))()
local e=assert(os.getenv('GEN1RECOMP_DIR'))
local maps=dofile(e..'/red/data/generated/maps.lua');local ts=dofile(e..'/red/data/generated/tilesets.lua')
local function panels(id)
 local map={id=id,def=maps[id],tileset=ts[maps[id].tileset]}
 local before=table.concat(map.def.blocks,',')
 local out=M.panelsFor(map,P.profileFor(map))
 assert(before==table.concat(map.def.blocks,','),'layout edited native blocks')
 return out
end
for id,d in pairs(maps)do
 if id:match('^SS_ANNE_')then assert(not P.profileFor({id=id,def=d}),'MS Anne panorama '..id)end
end
local lance=panels('LANCES_ROOM');assert(#lance>1)
for _,p in ipairs(lance)do if p.edge=='north' and p.at==0 then assert(not(p.from<288 and p.upto>192),'Lance void bridged')end end
local silph=panels('SILPH_CO_2F');local internal,lintel=false,false
for _,p in ipairs(silph)do
 if p.edge=='south' and p.at==64 then internal=true end
 if #p.openings>0 and p.at>0 then lintel=true end
end
assert(internal and lintel,'Silph interior partitions/door heads missing')
local closedTip=false
for _,p in ipairs(silph)do
 if p.edge=='north'and p.at==184 and p.from==352 and p.upto==368 then closedTip=true end
end
assert(closedTip,'Silph thick partition exposes its open end')
local lab=panels('CINNABAR_LAB');local inset=false
for _,p in ipairs(lab)do if p.edge=='north' and p.at>0 then inset=true end end
assert(inset,'Cinnabar L-shaped laboratory still uses the padded perimeter')
for floor=1,3 do
 local id='CELADON_MANSION_'..floor..'F'
 local out=panels(id);local left,right,portals=false,false,0
 for _,p in ipairs(out)do
  if p.edge=='east' and p.at==80 then left=true end
  if p.edge=='west' and p.at==96 then right=true end
  if (p.edge=='south' and p.at==144) or (p.edge=='north' and p.at==160) then
   assert(#p.openings==0,'blocked decorative front wall was opened: '..id)
  end
  for _,o in ipairs(p.openings)do
   if o.open and o.from==128 and o.upto==144 and o.height==24 then
    assert((p.edge=='east' and p.at==80)or(p.edge=='west'and p.at==96))
    portals=portals+1
   end
   assert(not(p.edge=='east'and p.at==80 and o.from==0),'rear exit leaked into perpendicular partition')
  end
 end
 assert(left and right and portals==2,'native side access lacks both framed faces: '..id)
 local plaques=0
 for _,p in ipairs(out)do for _,sign in ipairs(p.signs or{})do
  plaques=plaques+1
  assert(p.edge=='north'and p.at==160 and #p.openings==0,'sign replaced solid corridor wall')
  assert(sign.from==65 and sign.upto==79 and sign.bottom>0 and sign.top>sign.bottom,'sign moved away from native event')
  local found=false;for _,event in ipairs(maps[id].signs)do
   if event.x==4 and event.y==9 and event.text==sign.text then found=true end
  end
  assert(found,'plaque lost its native sign event')
 end end
 assert(plaques==1,'wall sign missing or PC text events converted to plaques '..id)
end
for _,id in ipairs({'UNDERGROUND_PATH_NORTH_SOUTH','UNDERGROUND_PATH_WEST_EAST'})do
 local out=panels(id);assert(#out==4)
 local bounds={};for _,p in ipairs(out)do bounds[p.edge]=p.at end
 assert(bounds.west==32 and bounds.north>=16,'tunnel walls remain outside native corridor')
 assert(bounds.east<maps[id].width*32 and bounds.south<maps[id].height*32,'tunnel padding left inside room')
 for _,p in ipairs(out)do assert(#p.openings==0,'tunnel stairs got a wall door')end
end
local elite=panels('LORELEIS_ROOM');assert(#elite==4 and #elite[1].openings==1 and elite[1].openings[1].upto-elite[1].openings[1].from==32)
for _,door in ipairs(elite[1].openings)do assert(door.height==24)end
local breach=panels('CERULEAN_TRASHED_HOUSE');assert(breach[1].openings[1].breach and breach[1].openings[1].open and breach[1].openings[1].height==28,'story breach needs an open damaged doorway, not a full-height black slit')
local V={require=function(name)
 if name=='VoxelState' then return {isFull=function(n)return n==1 end,FP_LEVEL=6}end
 if name=='HorizonWall' then return {interiorProfileFor=function()return {nativeRoomPanels=true}end,
  classFor=function()return 'interior'end,isOutdoorMap=function()return false end}end
 return {}
end}
local C=assert(loadfile(root..'/lib/InteriorCutaway.lua'))(V)
for level=1,5 do assert(C.active({},level),'orbit needs room cutaway '..level)end
assert(not C.active({},6) and not C.active({},7),'first/third person cut away walls')
local rim={kind='wall',interiorPanel={edge='north',at=0},oy=0}
-- A diagonal camera must retain the WHOLE wall even when its half-space
-- would intersect that wall. Camera or focus behind it hides it as a unit.
assert(C.rimVisible(rim,true,{400,100,20},{0,0,40}))
assert(C.rimVisible(rim,true,{-400,100,20},{0,0,40}))
assert(not C.rimVisible(rim,true,{0,100,-20},{0,0,40}))
assert(not C.rimVisible(rim,true,{0,100,20},{0,0,-40}))
assert(C.rimVisible(rim,false,{0,100,-20},{0,0,40}))
rim.oy=100;assert(not C.rimVisible(rim,true,{0,100,20},{0,0,40}))
assert(not C.rimVisible({kind='ground'},true))
local cap={kind='wall',interiorPanel={edge='south',at=128,endcap=true,
 cutawayFaces={{edge='east',at=80},{edge='west',at=96}}}}
assert(not C.rimVisible(cap,true,{88,100,180},{72,0,160}),
 'orphan end cap remains when both parent faces are hidden')
assert(C.rimVisible(cap,true,{72,100,100},{72,0,100}),
 'visible partition lost its closing end')
assert(C.rimVisible(cap,false,{88,100,180},{72,0,160}),
 'eye-level wall end was removed')
for _,p in ipairs(panels('CELADON_MANSION_1F'))do
 if p.endcap then assert(p.cutawayFaces and #p.cutawayFaces==2,'end cap lacks its partition owners')end
end
for _,id in ipairs({'OAKS_LAB','VIRIDIAN_POKECENTER','VIRIDIAN_MART','BLUES_HOUSE','LORELEIS_ROOM'})do
 local out=panels(id);local edges={}
 for _,p in ipairs(out)do edges[p.edge]=true end
 assert(edges.north and edges.south and edges.west and edges.east,'missing room side '..id)
end
for _,entry in ipairs({{'north',{50,100,50},{50,0,50}}, {'south',{50,100,-50},{50,0,-50}},
 {'west',{50,100,50},{50,0,50}}, {'east',{-50,100,50},{-50,0,50}}})do
 local p={kind='wall',interiorPanel={edge=entry[1],at=0}}
 assert(C.rimVisible(p,true,entry[2],entry[3]),entry[1])
 local opposite={-entry[2][1],100,-entry[2][3]}
 assert(not C.rimVisible(p,true,opposite,entry[3]),'camera-side wall remains '..entry[1])
end

print('PASS native room partitions, internal walls, complete lintels, story breach, whole-wall camera visibility and world offsets')

for _,id in ipairs({'REDS_HOUSE_1F','REDS_HOUSE_2F'})do
 for _,panel in ipairs(panels(id))do
  if panel.edge=='east' then assert(#panel.openings==0,'stairs received a wall doorway '..id)end
 end
end
print('PASS real bedroom stair transitions receive no wall door')

local ladders=0
for id,d in pairs(maps)do if d.tileset=='CAVERN' then
 local map={id=id,def=d,tileset=ts.CAVERN}
 for _,warp in ipairs(d.warps or {})do
  if M.verticalWarp(map,warp) then ladders=ladders+1 end
 end
end end
assert(ladders>50,'native cave ladder recognition unavailable')
print('PASS cave stair/ladder warp cells classified',ladders)

for _,p in ipairs(panels('BLUES_HOUSE'))do
 if p.edge=='north' then assert(p.at==16,'domestic back wall leaves old rim gap')end
 if p.edge=='east' or p.edge=='west' then assert(p.from==16,'side wall protrudes behind shifted back wall')end
end
print('PASS domestic corners meet at shifted native wall course')

local caps,rooms=0,0
for id in pairs(P.profiles)do
 local found=false
 for _,p in ipairs(panels(id))do if p.endcap then
  assert(#p.openings==0,'warp stamped onto wall end '..id)
  assert(p.upto>p.from and p.upto-p.from<=32,'wall cap crosses passage '..id)
  assert(not assert(loadfile(root..'/lib/Gen1InteriorFinish.lua'))().placement(p,'corporate',80),'wall end got cropped mural')
  caps=caps+1;found=true
 end end
 if found then rooms=rooms+1 end
end
assert(caps>20 and rooms>5,'partition caps not applied to shared room layout')
print('PASS thick partition ends',caps,rooms)
