local root=arg[1] or '.'
local L=assert(loadfile(root..'/lib/adapters/gen1/Gen1BattleLifecycle.lua'))({mod={log={warn=function()end}}})
local b={phase='menu',player={hp=42},enemy={hp=77}}
assert(L.claim(b,{provider='MAP',requestedMode=true}))
assert(not L.retryPresentation(b,'ARENA'),'unsettled owner reopened')
assert(L.started({battle=b}))
assert(not L.retryPresentation(b,'ARENA'),'active 3D owner reopened')
assert(L.nativeLatched(b,'MAP failed'))
local old=L.current(b)
assert(not L.retryPresentation({},'ARENA'),'foreign battle reopened')
assert(not L.retryPresentation(b,'DEFAULT'),'invalid destination accepted')
assert(not L.committed(b,{provider='ARENA'}),'automatic commit reopened latch')
assert(not L.changePresentation(b,'DEFAULT','ARENA'),'ordinary change reopened latch')
local events={}
L.subscribeCritical('owner',function()return true end,1000,function()return true end)
local unsub=L.subscribe('events',function(e)events[#events+1]=e.kind end)
local stop=L.subscribe('veto',function(e)if e.kind=='presentation-retried' then return false,'veto' end end)
assert(not L.retryPresentation(b,'ARENA'))
assert(L.current(b).state=='native_latched' and L.current(b).provider=='DEFAULT')
assert(L.current(b).transition==old.transition and L.current(b).reason==old.reason)
stop()
local reentry=L.subscribe('reentry',function(e)
 if e.kind=='presentation-retried' then
  assert(not L.retryPresentation(b,'MAP'),'reentrant retry accepted')
 end
end)
assert(not L.retryPresentation(b,'ARENA'),'reentrant transition published')
assert(L.current(b).state=='native_latched' and L.current(b).provider=='DEFAULT')
reentry()
for _,provider in ipairs({'ARENA','DISCS','MAP','ARENA','DISCS'}) do
 local changed=assert(L.retryPresentation(b,provider))
 assert(changed.provider==provider and changed.state=='active')
 assert(changed.battleToken==old.battleToken and changed.deploymentToken==old.deploymentToken)
 assert(changed.context.liveLegacyPresentation and changed.context.pokemonBack==false)
 assert(L.committed(b,{provider=provider}))
 assert(L.nativeLatched(b,'injected failure'))
 assert(b.player.hp==42 and b.enemy.hp==77)
end
for _,kind in ipairs(events) do
 assert(kind~='created' and kind~='started' and kind~='ended' and kind~='replacing','engine lifecycle replay')
end
-- A deployment completed while native must remain the authoritative identity.
assert(L.replacing({battle=b,side='player',battler={}}))
local deployed=L.current(b)
assert(deployed.deploymentToken>old.deploymentToken)
assert(L.retryPresentation(b,'DISCS').deploymentToken==deployed.deploymentToken)
assert(L.finished({battle=b}))
assert(not L.retryPresentation(b,'MAP'),'ended battle reopened')
-- Stage preparation may have failed before a renderer ever adopted the battle.
local early={}
assert(L.claim(early,{provider='DEFAULT',requestedMode='ARENA'}))
assert(L.started({battle=early}))
assert(L.retryPresentation(early,'DISCS'))
assert(L.finished({battle=early}))

-- Exercise the actual input handler, including failures with no renderer.
local file=assert(io.open(root..'/lib/OverworldBattle.lua'));local source=file:read('*a');file:close()
local handler=assert(source:match('(function OverworldBattle.cycleLivePresentation%(g%).-)\n%-%- Called by update'))
local request={mode=true,plan={mode=true}}
local owner={provider='DEFAULT',state='native_latched'}
local OB={ARENA='arena',FLAT_B='flat-b',presentationRequests={[b]=request}}
local env={Diagnostics={write=function()end},OverworldBattle=OB,V={require=function()return {notify=function()end,available=function()return false end}end},
 lifecycle=function()return owner end,runtimeLeaseActive=function()return true end,
 battleLifecycleReady=true,supported=true,sameBattle=rawequal}
setmetatable(env,{__index=_G});assert(setfenv(assert(loadstring(handler)),env))()
local g={stack={top=function()return b end}}
for _,mode in ipairs({'arena','flat-b',true,'arena'}) do
 assert(OB.cycleLivePresentation(g));assert(request.mode==mode and request.pending)
 request.pending=nil -- Failed attempt: the next press still advances.
end
owner={provider='ARENA',state='active'}
env.session={battle=b,plan={mode='arena'},rendererOwnerKind='legacy'}
assert(OB.cycleLivePresentation(g));assert(env.session.pendingPresentation.mode=='flat-b')
env.session.pendingPresentation=nil -- Failed live DISCS attempt.
assert(OB.cycleLivePresentation(g));assert(env.session.pendingPresentation.mode==true)
request.plan.mode=false
assert(OB.cycleLivePresentation(g),'explicit view request from OFF was refused')
assert(request.plan.mode==false,'explicit request changed committed OFF plan')
-- An available Terrarium host adds a fourth rung, including when native
-- fallback owns the current frame. Its shared DISCS renderer is not its ID.
OB.TERARRIUM='terarrium'
env.V.require=function()return {notify=function()end,available=function()return true end}end
env.session=nil;owner={provider='DEFAULT',state='native_latched'}
request.plan.mode=true;request.mode=true
for _,mode in ipairs({'arena','flat-b','terarrium',true}) do
 assert(OB.cycleLivePresentation(g));assert(request.mode==mode and request.pending)
 request.pending=nil
end
print('PASS explicit native recovery, tokens/HP/no replay, veto/owner/ended guards, native deployment, no-session fallback, failed-mode cursor')
