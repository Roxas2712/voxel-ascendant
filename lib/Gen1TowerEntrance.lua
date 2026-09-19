-- Lavender's real entrance is in the retaining wall in front of the tower,
-- outside its upper building template. Keep that warp in the same place.
local V=...
return function(P,F)
 local C=P.decorColors
 local timber,beam,paper=C.oldTimber or C.oak,C.oldBeam or C.walnut,C.paperWindow or 11
 local function model(kind)
  local m={terrain=true,boxes={},step=1,frameW=48,frameH=70,depth=32,offsetY=-38}
  P.models[kind]=m
  return m,function(x,y,z,w,h,d,c)m.boxes[#m.boxes+1]={x,y,z,w,h,d,c}end
 end
 local m,b=model('kanto_tower_entrance')
 local glass,g=model('kanto_tower_entrance_glass')
 m.glassKind='kanto_tower_entrance_glass'
 m.windowLight=V.require('Gen1PalletVillage').windowLight
 m.nativeDoors={{side='south',at=24,width=14,dest='POKEMON_TOWER_1F'}}
 -- Old timber vestibule on the unchanged native entrance footprint.
 b(0,0,0,48,2,32,C.slate or 16)
 for _,x in ipairs({0,34})do
  b(x,2,0,14,24,32,timber)
  for y=3,23,5 do b(x, y,29,14,1,2,beam)end
 end
 b(0,26,0,48,3,32,beam);b(2,29,0,44,2,32,beam)
 b(4,31,0,40,2,30,timber);b(7,33,0,34,2,28,beam)
 -- Closed double door sits on the native entrance cell, framed in timber.
 b(14,2,28,3,24,4,beam);b(31,2,28,3,24,4,beam)
 b(17,3,29,14,22,2,beam)
 for _,x in ipairs({18,25})do
  b(x,5,31,5,8,1,timber);g(x,16,31,5,6,1,paper)
 end
 b(23,3,31,2,22,1,C.navy)
 b(21,13,31,1,3,1,11);b(26,13,31,1,3,1,11)
 b(14,25,28,20,2,4,beam)
 for _,x in ipairs({8,37})do
  b(x,14,29,3,8,3,C.navy);g(x+1,15,31,1,6,1,11)
  b(x,22,28,3,1,4,4)
 end
 -- The entrance follows the selected exterior; the native wooden doors stay.
 local sm={};for k,v in pairs(m)do sm[k]=v end;sm.boxes={};sm.glassKind='kanto_tower_entrance_stone_glass'
 P.models.kanto_tower_entrance_stone=sm
 for _,box in ipairs(m.boxes)do
  local a={};for i,v in ipairs(box)do a[i]=v end
  if a[1]<14 or a[1]>=34 or a[2]>=25 then
   if a[7]==timber then a[7]=C.hauntedStone elseif a[7]==beam then a[7]=C.hauntedMortar end
  end
  sm.boxes[#sm.boxes+1]=a
 end
 local sg={};for k,v in pairs(glass)do sg[k]=v end;sg.boxes={}
 for _,box in ipairs(glass.boxes)do local a={};for i,v in ipairs(box)do a[i]=v end;a[7]=C.hauntedGlass;sg.boxes[#sg.boxes+1]=a end
 P.models.kanto_tower_entrance_stone_glass=sg
 F.patterns[#F.patterns+1]={kind='kanto_tower_entrance',sets={OVERWORLD=true},
  variant=function()return V.require('Gen1LavenderTower').setting:get()=='stone'and 'kanto_tower_entrance_stone'or 'kanto_tower_entrance'end,
  maps={LAVENDER_TOWN=true},x=26,y=8,voxelOnly=true,groundTile=44,
  tiles={{17,17,17,17,17,17},{17,17,17,17,17,17},
   {55,55,72,73,55,55},{55,55,88,89,55,55}},
  enabled=function()return V.require('Gen1PalletVillage').buildings:get()end,
  guard=function(map)
   local d=map.def
   if d.generation==2 or d.width~=10 or d.height~=9 then return false end
   for _,w in ipairs(d.warps or{})do
    if w.x==14 and w.y==5 and w.destMap=='POKEMON_TOWER_1F'then return true end
   end
   return false
  end}

 -- The tower lobby's two south warps are plain floor ($01), with no door
 -- art for the generic tower enclosure to lift. Put the inside of the old
 -- timber entrance at their far edge; do not claim the floor or add support.
 local exit={boxes={},step=1,frameW=32,frameH=52,depth=16,offsetY=-36,
  nativeDoors={{side='north',at=16,width=28,dest='LAST_MAP'}}}
 P.models.kanto_tower_exit=exit
 local function e(x,y,z,w,h,d,c)exit.boxes[#exit.boxes+1]={x,y,z,w,h,d,c}end
 e(0,0,12,2,31,4,beam);e(30,0,12,2,31,4,beam)
 e(0,30,12,32,3,4,beam);e(2,33,13,28,2,3,timber)
 for _,x in ipairs({2,16})do
  e(x,0,14,14,30,2,beam)
  for plank=0,2 do e(x+1+plank*4,2,13,3,26,1,timber)end
  for _,y in ipairs({7,23})do e(x+1,y,12,12,1,1,C.slate or 16)end
 end
 for _,x in ipairs({13,18})do e(x,13,11,1,4,2,11)end
 -- Pale threshold/arch accents remain readable against the dark interior.
 e(2,0,10,28,1,4,C.silver);e(4,30,11,24,1,1,C.silver)
 F.patterns[#F.patterns+1]={kind='kanto_tower_exit',sets={CEMETERY=true},
  maps={POKEMON_TOWER_1F=true},x=20,y=34,voxelOnly=true,keepTerrain=true,
  tiles={{1,1,1,1},{1,1,1,1}},
  guard=function(map)
   local d=map.def
   if d.generation==2 or d.width~=10 or d.height~=9 then return false end
   local left,right=false,false
   for _,w in ipairs(d.warps or{})do
    if w.y==17 and w.destMap=='LAST_MAP' and w.destWarp==2 then
     if w.x==10 then left=true elseif w.x==11 then right=true end
    end
   end
   return left and right
  end}
end
