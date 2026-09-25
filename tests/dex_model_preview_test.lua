local made,released,loads,draws,depth=0,0,0,0,0
local current='ui';local now=0;local fail=false;local epoch={epoch=1}
local function resource()made=made+1;return{release=function()released=released+1 end,send=function()end}end
local G={getCanvas=function()return current end,setCanvas=function(v)current=v end,push=function()depth=depth+1 end,pop=function()depth=depth-1 end,
 newShader=resource,newCanvas=resource,draw=function()draws=draws+1;if fail then error('GPU failure')end end}
setmetatable(G,{__index=function()return function()end end});love={graphics=G,timer={getTime=function()now=now+.016;return now end}}
local runtime={require=function(name)
 if name=='CobblemonContent'then return epoch end
 if name=='CobblemonPack'then return{}end
 assert(name=='StadiumMon');return{new=function()
  local actor=resource();actor.setSpecies=function(_,dex)loads=loads+1;return dex~=999 end
  actor.update=function()end;actor.pose=function()end;actor.upload=function()end
  actor.rig={posedBounds=function()return -5,0,-5,5,10,5 end,parts={{texture={},mesh={setTexture=function()end}}}}
  return actor
 end}
end}
local V={mod={exports={ascendantContent=epoch}},require=runtime.require}
local M=assert(loadfile('lib/DexModelPreview.lua'))(V)
local screen={game={data={pokemon={PIKACHU={dex=25},MISSING={dex=999}}}}}
assert(M.draw(screen,'PIKACHU',0,0,80,90));local first=made
for _=1,30 do assert(M.draw(screen,'PIKACHU',0,0,80,90))end
assert(made==first and loads==1,'steady preview reallocates/reloads');assert(current=='ui'and depth==0,'graphics state leaked')
assert(not M.draw(screen,'MISSING',0,0,80,90));local attempts=loads
for _=1,10 do assert(not M.draw(screen,'MISSING',0,0,80,90))end
assert(loads==attempts,'missing model retried every frame')
epoch.epoch=2;assert(not M.draw(screen,'MISSING',0,0,80,90));assert(loads==attempts+1)
fail=true;assert(not M.draw(screen,'PIKACHU',0,0,80,90));assert(current=='ui'and depth==0,'failed draw leaked state');fail=false
M.release(screen);assert(not screen._vascDexModel and made==released,'GPU/actor leak')
assert(not M.draw(screen,'UNKNOWN',0,0,80,90))
print('PASS Dex models: shared runtime, bounded resources, missing/error fallback, epoch retry and release')
