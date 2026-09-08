local f=assert(io.open('lib/OverworldBattle.lua'));local source=f:read('*a');f:close()
local a=assert(source:find('function OverworldBattle.ensure(battle)',1,true))
local b=assert(source:find('-- The engine owns switch semantics.',a,true))
local O={capturePresentationPlan=function()return {mode=true}end}
local current,claims,latches=nil,0,0
local env={OverworldBattle=O,battleLifecycleReady=true,legacyBattleGuard=function()return false,'deliberate native' end,retireRendererSessionToNative=function()return false end}
env.lifecycle=function(method,battle)
 if method=='current' then return current end
 assert(method=='nativeLatched')
 if current and current.battle==battle then current.state='native_latched';latches=latches+1;return current end
 return nil,'battle owner mismatch'
end
env.claimLifecycle=function(battle,plan,provider)
 assert(not current and provider=='DEFAULT' and plan.mode==true)
 claims=claims+1;current={battle=battle,provider=provider};return current
end
setfenv(assert(loadstring(source:sub(a,b-1))),setmetatable(env,{__index=_G}))()
local first={};assert(O.ensure(first)==false)
assert(claims==1 and latches==1 and current.battle==first and current.state=='native_latched')
assert(O.ensure(first)==false);assert(claims==1 and latches==2,'repeated ensure claimed twice')
local second={};assert(O.ensure(second)==false)
assert(claims==1 and latches==2 and current.battle==first,'guard took ownership from another battle')
current=nil;assert(O.ensure(second)==false);assert(claims==2 and current.battle==second)
env.session={battle=first};current=nil;assert(O.ensure(second)==false);assert(claims==2,'foreign renderer session stolen')
print('Direct native guard establishes only its exact unowned lifecycle: PASS')
