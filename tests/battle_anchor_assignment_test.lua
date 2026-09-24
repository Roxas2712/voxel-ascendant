local mode='flat'
local entries={ROUTE_TEST={fixed=true,spots={
 {x=5,y=5,shape='court_east',surface='land'},
 {x=25,y=5,shape='court_east',surface='water'},
 {x=45,y=5,shape='court_east',surface='land',terrain='world'},
}}}
local modules={VoxelScene={groundAt=function()return 0 end},LedgeElevation={mode=function()return mode end}}
local A=assert(loadfile('lib/BattleArena.lua'))({data=function(id)if id=='battle_arenas'then return entries end end,require=function(id)return assert(modules[id],id)end})
local map={id='ROUTE_TEST',widthCells=100,heightCells=40,def={tileset='OVERWORLD'}}
function map:inBounds(x,y)return x>=0 and y>=0 and x<100 and y<40 end
function map:warpAtCell()return false end
function map:isWarpTileCell()return false end
function map:isGrassCell()return false end
function map:isWalkableCell(x,y)return x<25 or x>=40 end
function map:isWaterCell(x,y)return x>=25 and x<40 end
A.keepRouteAnchorInBounds=function()return true end
local blocked={}
A.keepAnchorSafe=function(_,a)return not blocked[a.anchorIndex]end
local land=A.review(map,false)
assert(#land.candidates==1)
for y=0,39 do for x=0,99 do assert(A.assign(land,x,y).anchorIndex==1,'unassigned route end')end end
assert(A.assign(A.review(map,true),99,39).anchorIndex==2,'surf encounter chose a land court')
blocked[1]=true
assert(not A.find(map,1,1,false),'obstructed court bypassed safety')
mode='world';local raised=assert(A.find(map,1,1,false));assert(raised.anchorIndex==3)
mode='flat';assert(not A.find(map,1,1,false),'raised-only court used on flat terrain')
print('PASS encounter assignments: every cell, far route ends, land/water, terrain mode and blocked courts')
-- Geometry is relative to terrain, and empty space below world zero is empty.
local structures={shapeAt={[64+64*4096]={h=12}},objectQuads={}}
local base=-24
local H=assert(loadfile('lib/BattleHeroesBridge.lua'))({require=function(id)
 if id=='Structures'then return{forMap=function()return structures end}end
 if id=='VoxelFurniture'then return{find=function()return{}end}end
 if id=='VoxelItems'then return{models={}}end
 if id=='LedgeElevation'then return{map=function()return{atWorld=function()return base end}end}end
 error(id)
end})
local geometry=H.geometryForMap(map)
assert(geometry(4,4)==-12,'object ignored negative terrain datum')
assert(geometry(40,40)==-math.huge,'empty space became an invisible plane')
assert(H.geometryClear(geometry,{20,-20,40},{60,-20,40}),'empty world-negative ray blocked')
assert(not H.geometryClear(geometry,{-8,-20,4},{16,-20,4}),'real object was ignored')
base=24;assert(H.geometryForMap(map)(4,4)==36,'cached field retained old terrain height')
print('PASS authored geometry follows positive/negative terrain; empty rays and real obstacles remain distinct')
