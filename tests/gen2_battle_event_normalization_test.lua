local root=assert(arg[1])
local Lifecycle=assert(loadfile(root..'/gen2/lib/adapters/gen2/Gen2BattleLifecycle.lua'))()
local events={}
local l=Lifecycle.new({isBattleScreen=function(s)return type(s)=='table' and s.screenId=='Gen2BattleState' end})
assert(l:subscribeCritical({},function(e)events[#events+1]=e.kind;return true end,function()return true end))
local logic={player={hp=42}};local screen={screenId='Gen2BattleState',battle=logic}
local first=assert(l:started({battle=logic},{provider='MAP'}))
local bound=assert(l:started({battle=screen},{provider='ARENA'}))
assert(bound.owner==first.owner and bound.logic==logic and bound.screen==screen)
assert(bound.provider=='MAP' and l.starts==1 and l.replacements==0)
assert(l:screenPushed({state=screen}).owner==first.owner)
assert(#events==2 and events[1]=='started' and events[2]=='screen-bound')
local foreign={screenId='Gen2BattleState',battle=logic}
l:logicEnded({battle=foreign});assert(l:current(screen).state=='screen_bound','stale concrete screen ignored')
assert(l:logicEnded({battle=screen}).state=='end_pending')
assert(l:screenPopped({state=screen}));assert(l:current()==nil)
-- Explicit presentation replacement receives a fresh owner while retaining
-- the exact native screen and logic; normal duplicate starts cannot do that.
assert(l:started({battle=logic,screen=screen},{provider='MAP'}))
local prior=l:current(screen);assert(l:watchdogAbort(prior.owner,'presentation-mode-changed'))
local next=assert(l:started({battle=logic,screen=screen},{provider='DISCS'}))
assert(next.owner~=prior.owner and next.logic==logic and next.screen==screen and next.provider=='DISCS')
assert(logic.player.hp==42)
assert(l:logicEnded({battle=logic}).state=='end_pending')
assert(l:screenPopped({state=screen}));assert(l:current()==nil)
print('PASS Gen2 double-start normalization, exact screen end and presentation owner replacement')
