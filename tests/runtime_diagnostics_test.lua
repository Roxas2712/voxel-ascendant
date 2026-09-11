local now=0
love={timer={getTime=function()return now end},graphics={getRendererInfo=function()return 'OpenGL','4.1','Test','GPU' end,getDimensions=function()return 1920,1080 end,getStats=function()return {}end},system={getOS=function()return 'Windows'end}}
local ready
local mod={id='VOXEL_ASCENDANT',version='test',exports={},events={on=function(_,_,f)ready=f end}}
local R=assert(loadfile('lib/RuntimePerformanceDiagnostics.lua'))(mod)
mod._vascRuntimeDiagnostics=R
local game={overworld={map={id='SLOW_MAP'}},mods={mods={HGSS={enabled=true,state='loaded',manifest={version='2.1.0'}}}},update=function()now=now+.002;return 1,nil,3 end,draw=function()now=now+.004 end}
ready({game=game})
local a,b,c=game:update();assert(a==1 and b==nil and c==3)
local tested=R.wrap('VoxelScene',{render=function()error('original failure',0)end})
local ok,err=pcall(tested.render);assert(not ok and err=='original failure' and #R.stack==0)
for i=1,100 do now=now+.12;game:update();game:draw()end
for scene=1,7 do
 game.overworld.map.id='FAST_'..scene
 for i=1,250 do now=now+.01;game:update();game:draw()end
end
local e=R.evidence();assert(e:find('SLOW_MAP',1,true),'slow evidence lost after recovery')
assert(#R.recent<=3 and #R.worst<=3 and e:find('version=2.1.0',1,true))
assert(e:find('game.update',1,true) and e:find('game.draw',1,true))
local sender=assert(loadfile('lib/SupportSend.lua'))().new(mod,function()return string.rep('normal log\n',20000)end)
sender.code='12345678';local payload=assert(sender.payload());assert(#payload<=48*1024)
assert(payload:find('SLOW_MAP',1,true) and payload:find('RUNTIME EVIDENCE',1,true))
assert(sender.send()==false,'must not send without configured transport')
love.graphics={};assert(R.evidence():find('unavailable',1,true))
print('Runtime evidence: retained slowdown, no KASC, nil returns, errors, bounds, unavailable graphics: OK')
