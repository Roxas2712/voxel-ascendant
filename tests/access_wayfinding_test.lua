local now,calls=0,0
local game={save={}}
package.loaded['src.core.Game']=game
love={timer={getTime=function()return now end}}
local rows={}
local api={forMap=function()calls=calls+1;return rows end}
local Mat=dofile('lib/Mat4.lua')
local V={mod={find=function()return{exports={worldAccessPresentation=api}}end}}
V.require=function(name)
 if name=='Mat4'then return Mat end
 if name=='VoxelScene'then return{groundAt=function()return 24 end}end
 error(name)
end
local M=assert(loadfile('lib/AccessWayfinding.lua'))(V)
local state={map={id='ROUTE_14'}}
assert(#M.rows(state)==0 and calls==1)
rows={{kind='entrance',x=19,y=51,facing='east',lit=true}}
assert(#M.rows(state)==0 and calls==1,'unbounded per-frame query')
now=.21;assert(#M.rows(state)==1 and calls==2)
local sources={};M.appendLights(state,sources)
assert(#sources==1 and sources[1].normal[2]==-1 and sources[1].y==26.3)
state.map.isWaterCell=function()return true end; sources={};M.appendLights(state,sources);assert(sources[1].y==30.3 and sources[1].radius==22,'buoy light must sit just above water')
rows={{kind='researcher',x=14,y=2,theme='REGICE',lit=false}}
game.save={};assert(M.rows(state)[1].lit==false,'save boundary retained unlocked lamps')
sources={};M.appendLights(state,sources);assert(#sources==0)
rows={};state.map={id='OTHER'};assert(#M.rows(state)==0,'map boundary retained route markers')
print('PASS access markers cache by map/save, remain unlit before solve, supply bounded lighting data')
