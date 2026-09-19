-- Exercise the actual enumeration: light preparation must not resolve
-- ordinary scenery or tick decorative harbor/healing draws.
local root=assert(arg[1]);local f=assert(io.open(root..'/lib/VoxelFurniture.lua','rb'))
local source=f:read('*a');f:close()
local first=assert(source:find('function F.each(',1,true))
local last=assert(source:find('-- A battle captures',first,true))
local worldFirst=assert(source:find('local shiftedMatrices=',last,true))
local worldLast=assert(source:find('function F.shadowHeight',worldFirst,true))
local resolved,boats,healers={},0,0
local lamp={glassKind='flame',windowLight=function()return .7 end}
local chair={};local P={models={chair=chair,lamp=lamp},setting={get=function()return true end}}
P.resolveKind=function(kind)resolved[#resolved+1]=kind;return kind..'-mesh',kind..'-tex'end
local F={find=function()return {{kind='chair',claimed=true,tx=0,ty=0},{kind='lamp',claimed=true,tx=2,ty=3}}end,
 enabled=function()return true end,activeHealer=function()healers=healers+1;return nil end}
local M={translate=function(x,y,z)return {1,0,0,x,0,1,0,y,0,0,1,z,0,0,0,1}end}
local V={require=function(n)assert(n=='Gen1Harbor',n);return {each=function()boats=boats+1 end}end}
assert(loadstring('local V,F,P,M=...; '..source:sub(first,last-1)..source:sub(worldFirst,worldLast-1)))(V,F,P,M)
local map,neighbor={},{};local rows={}
F.eachWorld({map=map,neighbors={{map=neighbor,ox=160,oy=-80}}},function(...)rows[#rows+1]={...}end,true)
assert(#rows==2 and #resolved==4 and resolved[1]=='lamp' and resolved[2]=='flame')
assert(rows[1][5].lightModel==lamp and rows[1][5].glow==.7)
assert(rows[2][3][4]==176 and rows[2][3][12]==-56,'neighbor light translation changed')
assert(boats==0 and healers==0,'light-only scan still visits non-luminous decorations')
F.each({map=map},function()end)
assert(boats==1 and healers==1,'normal scenery lost decoration draws')
local count=0
F.each({sightFurniture={{extra={}},{extra={lightModel=lamp}}}},function()count=count+1 end,true)
assert(count==1,'snapshot scan retained non-light geometry')
print('PASS_FURNITURE_LIGHT_SCAN: emitter-only resolution, visible defaults, snapshots and neighbor transforms')
