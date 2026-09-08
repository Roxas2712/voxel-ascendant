local scene={groundAt=function(map,x,y)return map.floor(x,y)end}
local V={data=function()return {}end,requireVoxelScene=function()return scene end,
 require=function(name)if name=='TileShape' then return {forMap=function()return {[1]={art='grass'},[0]={}}end}end;if name=='VoxelScene' then return scene end;if name=='BattleCam' then return {rig=function()return nil end}end;error('unavailable fixture module '..name)end}
local A=assert(loadfile('lib/BattleArena.lua'))(V)
local map={id='ROUTE_24',widthCells=24,heightCells=32,def={tileset='OVERWORLD'}}
function map:inBounds(x,y)return x>=0 and y>=0 and x<24 and y<32 end
function map:warpAtCell()return false end
function map:isWarpTileCell()return false end
function map:isGrassCell(x,y)return x==12 and y==20 end
function map:cellTile(x,y)return self:isGrassCell(x,y) and 1 or 0 end
function map:isWaterCell()return false end
function map:isWalkableCell()return true end
map.floor=function()return 0 end
local a=assert(A.find(map,12,20,false),'grass encounter rejected a clear court on the same floor')
assert(a.anchorHeight==0,'grass top became the footing height')
assert(not A.openCell(map,12,20,false),'tall grass accepted as a battler footprint')
map.floor=function(x,y)return x==12 and y==20 and 16 or 0 end
assert(not A.find(map,12,20,false),'different terrain floor accepted')
map.floor=function()return 16 end
assert(assert(A.find(map,12,20,false)).anchorHeight==16,'elevated grass encounter rejected')
map.floor=function()return 0 end
local eye={10*16+8,4,20*16+8};local target={14*16+8,20*16+8}
local grassScore=A.visibility(map,eye,target,0,8)
map.isGrassCell=function()return false end
assert(A.visibility(map,eye,target,0,8)>grassScore,'grass ceased to occlude camera rays')
map.isWalkableCell=function(_,x,y)return x~=12 end
assert(A.visibility(map,eye,target,0,8)==0,'wall ceased to occlude camera rays')
print('Battle arena terrain floor, grass and wall regression: PASS')
