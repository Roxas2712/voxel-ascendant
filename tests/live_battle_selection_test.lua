local f=assert(io.open('lib/OverworldBattle.lua'));local source=f:read('*a');f:close()
local first=assert(source:find('function OverworldBattle.cycleLivePresentation(',1,true))
local last=assert(source:find('function OverworldBattle.retryNativePresentation(',first,true))
local battle={};local receipt={provider='DEFAULT',state='active'}
local request={plan={mode=false},mode=false}
local O={ARENA='arena',FLAT_B='flatB',presentationRequests={[battle]=request}}
local notifications=0
local events={}
local env={Diagnostics={write=function(event,fields)events[#events+1]={event,fields}end},OverworldBattle=O,battleLifecycleReady=true,supported=true,
 runtimeLeaseActive=function()return true end,
 lifecycle=function()return receipt end,sameBattle=rawequal,
 V={require=function(name)
  if name=='ShortcutToast' then return {notify=function()notifications=notifications+1 end}end
  if name=='TerarriumHost' then return {available=function()return false end}end
  error(name)
 end}}
setfenv(assert(loadstring(source:sub(first,last-1))),setmetatable(env,{__index=_G}))()
local g={stack={top=function()return battle end}}
assert(O.cycleLivePresentation(g),'explicit OFF-to-MAP request was rejected')
assert(request.pending and request.mode==true and notifications==1)
assert(#events==1 and events[1][1]=='battle-view-request' and events[1][2].actual=='DEFAULT')
assert(request.plan.mode==false,'request mutated the committed OFF plan')
-- Once adopted by the legacy renderer, every explicit view remains reachable.
receipt.provider='MAP'
env.session={battle=battle,plan={mode=true},rendererOwnerKind='legacy'}
for _,mode in ipairs({'arena','flatB',true})do
 assert(O.cycleLivePresentation(g))
 assert(env.session.pendingPresentation.mode==mode and request.mode==mode)
end
env.session.battle={}
assert(not O.cycleLivePresentation(g),'another encounter stole the request')
env.session=nil;receipt.provider='DEFAULT';request.plan.mode=nil
assert(not O.cycleLivePresentation(g),'missing plan was accepted')
request.plan=nil
assert(not O.cycleLivePresentation(g),'missing plan crashed or was accepted')
print('PASS explicit OFF-to-MAP and legacy view cycle retain encounter ownership')

-- A failed candidate must retain the active stage and explain the refusal,
-- without logging each retry frame or changing the saved presentation.
first=assert(source:find('function OverworldBattle.applyPendingPresentation(',1,true))
last=assert(source:find('function OverworldBattle.tryPortableRecovery(',first,true))
local originalArena={presentationMode='ARENA',map={}}
local originalPlan={mode='arena'}
local candidate={presentationMode='DISCS',discs=true}
local active={battle=battle,state={map={}},arena=originalArena,plan=originalPlan,
 rendererProvider='ARENA',presentationCommitted=true}
battle.phase='menu'
local failure,restores,saved=nil,0,0
local scene={prepare=function()if failure=='prepare' then error('GPU upload rejected')end end,
 groundY=function()return 0 end,presentationFitDistance=function()return 1 end}
scene.render=function()scene.lastDeclineReason='camera-unavailable:owner-render-unsafe';return nil end
local camera={checkpoint=function()return function()restores=restores+1 end end,
 reset=function()end,setPresentationFit=function()end,update=function()end}
local modules={Stadium={active=function()return false end},ShortcutToast={notify=function()end}}
O.stageFor=function()if failure=='stage' then error('missing stage resource')end;return candidate end
O.setPlanStage=function(plan,mode)plan.mode=mode end
O.setting={setValue=function()saved=saved+1 end}
env.session=active;env.game=function()return g end
env.BattleScene=scene;env.BattleCam=camera;env.ChunkMesher={pump=function()end}
env.Voxel3D={};env.V={require=function(name)return assert(modules[name],name)end}
setfenv(assert(loadstring(source:sub(first,last-1))),setmetatable(env,{__index=_G}))()
local function requestFailure(kind)
 events={};failure=kind;active.pendingPresentation={mode='flatB',elapsed=0}
end
for _,kind in ipairs({'stage','prepare'})do
 requestFailure(kind)
 assert(not O.applyPendingPresentation(active,.1,{}))
 assert(not active.pendingPresentation and #events==1)
 assert(events[1][2].action==kind and events[1][2].reason:find(kind=='stage' and 'missing stage resource' or 'GPU upload rejected',1,true))
 assert(active.arena==originalArena and active.plan==originalPlan and saved==0)
end
requestFailure(nil)
assert(not O.applyPendingPresentation(active,1,{}))
assert(active.pendingPresentation and #events==0,'transient readiness logged every frame')
assert(not O.applyPendingPresentation(active,1,{}))
assert(not active.pendingPresentation and #events==1 and restores==2)
assert(events[1][2].reason=='camera-unavailable:owner-render-unsafe')
assert(active.arena==originalArena and active.plan==originalPlan and active.rendererProvider=='ARENA' and saved==0)
print('PASS failed stage, GPU upload and camera candidate retain old view with one original-cause receipt')
