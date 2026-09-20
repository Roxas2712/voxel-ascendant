local root=assert(arg[1])
local setting={get=function()return true end}
local mods={VoxelItems={setting=setting},Gen1OutdoorScenery={trees=setting,stone=setting}}
local V={require=function(n)return assert(mods[n],n)end}
local H=assert(loadfile(root..'/lib/KascHabitatScenery.lua'))(V)
local P={models={kanto_tree_1_3={boxes={{2,0,2,12,20,12,1}}}},decorColors={slate=1,navy=2,silver=3,leaf=4}}
H.register(P)
local defs={TURTWIG='PLANT',SNIVY='PLANT',CHESPIN='PLANT',ROWLET='PLANT',CHIMCHAR='FIRE',TEPIG='FIRE',FENNEKIN='FIRE',LITTEN='FIRE',PIPLUP='WATER',OSHAWOTT='WATER',FROAKIE='WATER',POPPLIO='WATER'}
for species,category in pairs(defs)do
 local fire=category=='FIRE'
 local d={runtimeAuthority='KASC_6_7_STARTER_HABITAT_V2_3',voxelOwner='kanto_ascendant',
  tileset=fire and(species=='FENNEKIN'and'KA_HABITAT_MYSTIC'or'KA_HABITAT_STONE')or'KA_HABITAT_G2_JOHTO',
  width=3,height=2,blocks={},objects={{x=2,y=0}},signs={{x=4,y=0}},storyPositions={{x=0,y=2}}}
 for i=1,6 do d.blocks[i]=fire and 29 or 5 end
 local map={id='KA_HABITAT_'..species..'_PROTOTYPE',def=d}
 function map:isWalkableCell(x,y)return y%2==1 end
 function map:isWaterCell(x,y)return x==5 and y==2 end
 function map:warpAtCell(x,y)return x==3 and y==2 and {}or nil end
 assert(H.profile(map)==category and H.mist(map).height<=34)
 local snapshot=table.concat(d.blocks,',');local props=H.find(P,map);assert(#props>0)
 for _,p in ipairs(props)do
  local x,y=p.tx/2,p.ty/2
  if not p.terrainDecoration then
   assert(not map:isWalkableCell(x,y)and not map:isWaterCell(x,y)and not map:warpAtCell(x,y))
   for _,list in ipairs({d.objects,d.signs,d.storyPositions})do for _,point in ipairs(list)do assert(x~=point.x or y~=point.y)end end
  else assert(map:isWalkableCell(x,y))end
  for _,b in ipairs(assert(P.models[p.kind]).boxes)do
   assert(b[1]>=0 and b[3]>=0 and b[1]+b[4]<=16 and b[3]+b[6]<=16)
  end
 end
 assert(snapshot==table.concat(d.blocks,','),'visual adapter changed layout')
 d.tileset='OVERWORLD';assert(not H.profile(map)and #H.find(P,map)==0)
end
local S=assert(loadfile(root..'/lib/KascSkySanctum.lua'))(V)
local d={tileset='KA_HOENN_SKY_67',outdoor=true,width=12,height=10,blocks={},objects={{x=4,y=4}},signs={{x=8,y=13}}}
for i=1,120 do d.blocks[i]=i%12==0 and 0 or 9 end
local map={id='KA_HEVO_RAYQUAZA_CHAMBER',def=d}
function map:isWalkableCell(x,y)return x%3==1 end
assert(S.matches(map));local props=S.find(P,map);assert(#props==1)
local model=P.models[props[1].kind]
assert(model.groundAt(4*16,4*16)==36,'boss buried beneath pillar')
assert(model.groundAt(8*16,13*16)==36,'scripted return buried')
assert(model.support==0)
for _,b in ipairs(model.boxes)do
 local cx,cy=math.floor(b[1]/16),math.floor(b[3]/16)
 assert(b[4]>0 and b[5]>0 and b[6]>0)
 if map:isWalkableCell(cx,cy)then assert(b[2]+b[5]<=0,'column occupies a walking cell')end
end
d.tileset='OVERWORLD';assert(not S.matches(map)and #S.find(P,map)==0)
print('PASS_KASC_SCENERY: all 12 contracts, cell-safe trees/rocks, original blocks, private atlas exclusion, sky walkways and landmarks')
