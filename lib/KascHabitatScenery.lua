-- Presentation adapter for KASC's reviewed twelve starter habitats.
-- A Gen2 atlas inside the Gen1 game is not a Gen2 runtime. Exact ownership
-- and tileset contracts admit these maps without weakening general guards.
local V=...
local M={}
local species={TURTWIG='PLANT',SNIVY='PLANT',CHESPIN='PLANT',ROWLET='PLANT',
 CHIMCHAR='FIRE',TEPIG='FIRE',FENNEKIN='FIRE',LITTEN='FIRE',
 PIPLUP='WATER',OSHAWOTT='WATER',FROAKIE='WATER',POPPLIO='WATER'}
function M.profile(map)
 local d=map and map.def
 if not d or d.runtimeAuthority~='KASC_6_7_STARTER_HABITAT_V2_3'
  or d.voxelOwner~='kanto_ascendant' then return nil end
 local name=(map.id or d.id or ''):match('^KA_HABITAT_(%u+)_PROTOTYPE$')
 local category=species[name]
 if not category then return nil end
 local ts=category=='FIRE'and(name=='FENNEKIN'and'KA_HABITAT_MYSTIC'or'KA_HABITAT_STONE')or'KA_HABITAT_G2_JOHTO'
 if d.tileset~=ts then return nil end
 return category,name
end
function M.material(map,tile)
 local category=M.profile(map)
 if category=='FIRE'then return -171 end
 if category then
  if tile==6 then return -159 end -- habitat meadow
  if tile==5 or tile==3 or tile==4 or tile==62 or tile==63 then return -159 end -- meadow / low flowers
 end
end
local haze={FIRE={color={.46,.37,.32},density=.009,height=34},
 PLANT={color={.42,.51,.43},density=.004,height=28},
 WATER={color={.46,.57,.61},density=.005,height=24}}
function M.mist(map)return haze[M.profile(map)]end
function M.register(P)
 local c=P.decorColors
 for variant=1,4 do
  local source=P.models.kanto_tree_1_3
  local model={boxes={},frameW=16,frameH=56,depth=16,offsetY=-40,step=1}
  for _,box in ipairs(source.boxes)do
   local t={unpack(box)};local scale=.94+variant*.04;t[2]=t[2]*scale;t[5]=t[5]*scale
   model.boxes[#model.boxes+1]=t
  end
  P.models['kasc_habitat_pine_'..variant]=model
 end
 for variant=1,4 do
  local model={boxes={},frameW=16,frameH=56,depth=16,offsetY=-40,step=1,directBoxes=true}
  P.models['kasc_habitat_rock_'..variant]=model
  local function b(x,y,z,w,h,d,color)model.boxes[#model.boxes+1]={x,y,z,w,h,d,color}end
  -- Unequal basalt columns keep a broken rock silhouette and real depth.
  for x=0,3 do for z=0,3 do
   local h=12+(x*7+z*11+variant*5)%13
   b(x*4,0,z*4,4,h,4,(x+z+variant)%3==0 and c.slate or c.navy)
   b(x*4+.5,h,z*4+.5,3,1,3,c.slate)
  end end
  if variant==1 then
   b(2,6,15,12,1.5,.5,1);b(4,7.5,15,4,1,.5,11)
   model.lightSource={position={8,9,18},normal={0,0,1},radius=65,power=1.5,color={1,.25,.045},kind='ember'}
  end
 end
end
function M.find(P,map)
 local category,name=M.profile(map);if not category then return {}end
 local d=map.def;local result={};local scenery=V.require('Gen1OutdoorScenery')
 local function enabled()return V.require('VoxelItems').setting:get()and(category=='FIRE'and scenery.stone:get()or category~='FIRE'and scenery.trees:get())end
 for cy=0,d.height*2-1 do for cx=0,d.width*2-1 do
  local block=d.blocks[math.floor(cy/2)*d.width+math.floor(cx/2)+1]
  if category=='FIRE'and(block==29 or block==9)or category~='FIRE'and block==5 then
   local safe=not(map:isWalkableCell(cx,cy)or map:isWaterCell(cx,cy)or map:warpAtCell(cx,cy))
   for _,list in ipairs({d.objects or{},d.signs or{},d.storyPositions or{}})do
    for _,p in ipairs(list)do if p.x==cx and p.y==cy then safe=false end end
   end
   if safe then
    local variant=1+(cx*3+cy*7)%4
    local kind=category=='FIRE'and'kasc_habitat_rock_'..variant
      or'kasc_habitat_pine_'..variant
    result[#result+1]={kind=kind,tx=cx*2,ty=cy*2,w=2,h=2,
     groundTile=category=='FIRE'and 36 or 5,voxelOnly=true,enabled=enabled}
   end
  end
 end end
 -- The southern row of the original tree drawing is walkable in Gen1's
 -- atlas collision rules. Remove its flat artwork without placing a trunk
 -- there or changing the ground/encounter surface.
 if category~='FIRE'then
  P.models.kasc_habitat_floor=P.models.kasc_habitat_floor or {boxes={{0,-1,0,1,1,1,P.decorColors.leaf}},frameW=16,frameH=32,depth=16,offsetY=-16,step=1}
  for cy=1,d.height*2-1,2 do for cx=0,d.width*2-1 do
   local block=d.blocks[math.floor(cy/2)*d.width+math.floor(cx/2)+1]
   if block==5 and map:isWalkableCell(cx,cy)and not map:warpAtCell(cx,cy)then
    result[#result+1]={kind='kasc_habitat_floor',tx=cx*2,ty=cy*2,w=2,h=2,
     terrainDecoration=true,groundTile=5,voxelOnly=true,enabled=enabled}
   end
  end end
 end
 return result
end
return M
