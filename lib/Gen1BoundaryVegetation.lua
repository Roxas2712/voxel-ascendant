-- Selected native retaining edges become planted banks. The original
-- blocked cells remain authoritative; jump lips and their approach/landing
-- neighbourhood never participate. No extra cells or collision are created.
local V=...
local Game=require('src.core.Game')
local B={}
local regions={
 ROUTE_8='garden', FUCHSIA_CITY='garden',
 VIRIDIAN_CITY='woodland', PEWTER_CITY='rocky',
}
local lips={[13]=true,[29]=true,[39]=true,[52]=true,[54]=true,[55]=true}
local water={[20]=true,[49]=true,[50]=true,[51]=true,[84]=true}
local stone={[1]=true,[2]=true,[17]=true,[19]=true,[30]=true,[36]=true}
function B.at(map,x,y)
 local d=map and map.def;local region=map and regions[map.id]
 if not region or not d or d.generation==2 or d.tileset~='OVERWORLD'
  or x%2~=0 or y%2~=0 or x<2 or y<2
  or x+3>=d.width*4 or y+3>=d.height*4 then return nil end
 -- Four-cell stretches alternate with the existing rock, so neither a
 -- checkerboard of single bushes nor a uniform replacement wall is made.
 local section=math.floor(x/8)+math.floor(y/8)
 if section%3==0 or (region=='rocky' and section%3~=1)then return nil end
 for dy=0,1 do for dx=0,1 do
  if not stone[map:tileAt(x+dx,y+dy)]then return nil end
 end end
 local cx,cy=x/2,y/2
 if map:isWalkableCell(cx,cy) or map:isWarpTileCell(cx,cy)then return nil end
 local besidePath=false
 for _,dir in ipairs({{-1,0},{1,0},{0,-1},{0,1}})do
  if map:isWalkableCell(cx+dir[1],cy+dir[2])then besidePath=true end
 end
 if not besidePath then return nil end -- no plants throughout mountain interiors
 local customLips={}
 for _,rule in ipairs(Game.data and Game.data.field and Game.data.field.ledges or {})do
  if (rule.tileset or 'OVERWORLD')==d.tileset and rule.ledgeTile then
   customLips[rule.ledgeTile]=true
  end
 end
 for yy=y-2,y+3 do for xx=x-2,x+3 do
  local t=map:tileAt(xx,yy)
  if lips[t] or customLips[t] or water[t]then return nil end
 end end
 for yy=cy-1,cy+1 do for xx=cx-1,cx+1 do
  if map:isWarpTileCell(xx,yy)then return nil end
 end end
 return region,1+(math.floor(x/2)+math.floor(y/2))%3
end
function B.register(P,F,settings)
 local C=P.decorColors
 for _,region in ipairs({'garden','woodland','rocky'})do for variant=1,3 do
  local kind='kanto_planted_bank_'..region..'_'..variant
  local model={boxes={},frameW=16,frameH=64,depth=16,offsetY=-48,
   boundaryVegetation=true,region=region}
  P.models[kind]=model
  local function box(x,y,z,w,h,d,c)
   model.boxes[#model.boxes+1]={x,y,z,w,h,d,c}
  end
  -- Keep the former retaining height solid, so vegetation cannot open a
  -- trench into the adjacent plateau. Soil/moss replace the dressed masonry.
  box(0,0,0,16,16,16,C.oldTimber or C.walnut)
  box(0,12,0,16,4,16,C.leafDark or 10)
  for _,p in ipairs({{0,2},{7,0},{12,9}})do
   box(p[1],3+variant%2,p[2],4,4,4,C.looseRock2 or C.stone or 14)
  end
  local dark,leaf,light=C.leafDark or 10,C.leaf or 12,C.leafLight or C.sage
  if region=='woodland' then
   -- Two slim trunks and overlapping crowns give the woods a different
   -- silhouette from the clipped town hedges, within the same footprint.
   for _,p in ipairs({{4,5},{11,10}})do
    box(p[1],15,p[2],2,15,2,C.oldTimber or C.walnut)
    box(p[1],19,p[2],1,2,2,C.oak)
   end
  end
  local height=region=='woodland' and 25 or region=='rocky' and 15 or 19
  for i,p in ipairs({{0,2,8,10},{6,0,10,9},{4,8,10,8}})do
   local base=region=='woodland' and 23 or 14
   local h=height+(variant+i)%3*2
   box(p[1],base,p[2],p[3],h-8,p[4],dark)
   box(p[1],base+h-8,p[2],p[3],4,p[4],leaf)
   box(p[1]+2,base+h-4,p[2]+1,p[3]-4,3,p[4]-2,light)
  end
  if region=='garden' and variant==2 then
   box(3,29,2,2,2,2,C.purple or 39);box(12,27,11,2,2,2,4)
  end
 end end
 for _,grid in ipairs({{{1,1},{17,17}},{{36,36},{36,36}}})do
  F.patterns[#F.patterns+1]={kind='kanto_planted_bank',sets={OVERWORLD=true},
   tiles=grid,voxelOnly=true,groundTile=44,
   guard=function(map,x,y)return B.at(map,x,y)~=nil end,
   variant=function(map,x,y)local region,n=B.at(map,x,y)
    return 'kanto_planted_bank_'..region..'_'..n end,
   enabled=function()return settings.stone:get() and settings.trees:get()end}
 end
end
return B
