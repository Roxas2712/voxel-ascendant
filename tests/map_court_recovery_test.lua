local f=assert(io.open('lib/OverworldBattle.lua'));local s=f:read('*a');f:close()
local a=assert(s:find('function OverworldBattle.tryMapRecovery(',1,true))
local b=assert(s:find('function OverworldBattle.trySceneRecovery(',a,true))
local O={};local map={id='ROUTE_1'}
local old={presentationMode='MAP',anchorIndex=1,map=map}
local active={arena=old,state={map=map,player={surfing=false}},rendererOwnerKind='legacy'}
local attempts,events={},0
local env={OverworldBattle=O,session=active,Diagnostics={write=function()events=events+1 end},
 BattleArena={withVisibilitySamples=function(fn,...)return fn(...)end,review=function(m,water)
  assert(m==map and not water)
  return{candidates={old,{anchorIndex=2,map=map},{anchorIndex=3,map=map}}}
 end}}
setfenv(assert(loadstring(s:sub(a,b-1))),setmetatable(env,{__index=_G}))()
O.applyPendingPresentation=function(owner,dt,textures)
 assert(owner==active and dt==0 and textures.ready)
 local p=owner.pendingPresentation;assert(p.emergency and p.mode==true)
 attempts[#attempts+1]=p.arena.anchorIndex
 if p.arena.anchorIndex==3 then owner.arena=p.arena;owner.pendingPresentation=nil;return true end
 return false
end
assert(O.tryMapRecovery(active,{ready=true},'player-under-message'))
assert(table.concat(attempts,',')=='2,3' and events==1)
assert(active.arena.presentationMode=='MAP' and not active.pendingPresentation)
assert(not O.tryMapRecovery(active,{ready=true},'player-under-message'),'repeated unbounded court search')
active.mapCourtsTried=nil;active.rendererOwnerKind='external'
assert(not O.tryMapRecovery(active,{ready=true},'owner-error'),'external owner was hijacked')
print('PASS bounded MAP court recovery preserves presentation transaction and owner')
