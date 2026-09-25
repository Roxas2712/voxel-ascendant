local occupied=function(x,z)return z<-8 and 24 or -math.huge end
local ground=function()return 0 end
local modules={
 BattleArena={openCell=function()return true end,visibility=function()return 3 end},
 VoxelScene={groundAt=function(_,x,z)return ground(x*16,z*16)end},
 BattleBillboard={yawToward=function()return 0 end,matrix=function()return{}end},
 Voxel3D={},
}
local B=assert(loadfile('lib/BattleHeroesBridge.lua'))({require=function(id)return assert(modules[id],id)end})
B.geometryForMap=function()return function(x,z)return occupied(x,z)end end
local function open()return true end
local function flat()return 0 end
assert(not B.supportsFoot({0,0,0},16,1,0,open,flat,function(x)return x>=6 and 20 or -math.huge end),
 'walkable centre accepted a shoulder inside a hedge')
assert(not B.supportsFoot({0,0,0},16,1,math.pi/2,open,flat,function(_,z)return z>=6 and 20 or -math.huge end),
 'rotated trainer footprint ignored hedge')
assert(not B.supportsFoot({0,0,0},16,1,0,function(x)return x<6 end,flat,function()return -math.huge end),
 'body crossed blocked tile')
assert(not B.supportsFoot({0,0,0},16,1,0,open,function(x)return x>=6 and -16 or 0 end,function()return -math.huge end),
 'body straddled unsupported ledge')
local hero={canvas={},width=14,height=28}
local textures={battleHeroes={player=hero,settled=true}}
local arena={presentationMode='MAP'};local map={}
local layout={player={0,0,0},enemy={100,0,0},actorInkWidth={player=30,enemy=10}}
local eye={100,40,100}
local function render()
 local cards={};B.append(cards,textures,layout,eye,map,arena);return assert(cards[1])
end
local card=render()
assert(hero.mapFoot.clear and hero.mapFoot.supportSafe and card.placementSafe,
 'relaxed search did not find a supported position')
assert(B.supportsFoot(card.shadowFoot,14,1,0,open,flat,occupied),'relaxed placement intersected hedge')
render();assert(hero.mapFoot.locked,'settled trainer not locked')
local old=hero.mapFoot.foot
occupied=function(x,z)return math.abs(x-old[1])<9 and math.abs(z-old[3])<4 and 24 or -math.huge end
card=render()
assert(hero.mapFoot.clear and (card.shadowFoot[1]~=old[1] or card.shadowFoot[3]~=old[3]),
 'unsafe cached seat was retained')
assert(B.supportsFoot(card.shadowFoot,14,1,0,open,flat,occupied))
modules.BattleArena.visibility=function()return 0 end
hero.mapFoot=nil
card=render();assert(not card.placementSafe,'occluded trainer accepted as an overlap fallback')
modules.BattleArena.visibility=function()return 3 end
occupied=function()return 24 end
hero.mapFoot=nil;layout.actorInkWidth=nil;hero.intro=true
card=render()
assert(not hero.mapFoot.supportSafe and not card.placementSafe,'unsafe introduction bypassed placement guard')
print('PASS trainer support: full body, rotated hedge, blocked tile, ledge, occlusion rejection, cached seat and intro guard')
