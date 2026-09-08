local stamp=0
love={timer={getTime=function()return stamp end},graphics={getStats=function()return {} end}}
local P=assert(loadfile('lib/PerformanceDiagnostics.lua'))({})
local hudWrites=0
P.diagnostics={write=function(event)
 if event=='vasc.performance.battle-hud-layout' then hudWrites=hudWrites+1 end
end}
P.beginLoad('battle',{source='battle.requested'})
stamp=.125
local function receipt(x,bad)
 return {hud='GEN1-ORAS',viewportWidth=1560,viewportHeight=720,
 orientation='landscape',playerX=x,playerY=100,enemyX=x+500,enemyY=100,
 playerWidth=100,enemyWidth=100,inBounds=not bad,orientationOk=true,
 reason=bad and 'status-anchor-unsafe' or 'anchors-in-bounds'}
end
P.reportHud(receipt(20))
assert(P.latestLoads.battle.result=='ready' and P.latestLoads.battle.elapsedMs==125)
assert(not P.pendingLoads.battle,'first rendered HUD did not close load measurement')
for i=1,600 do stamp=.125+i/120;P.reportHud(receipt(20+i*.1))end
assert(hudWrites==1,'moving camera writes diagnostics every frame')
assert(P.hud.playerX==80,'live position stopped updating')
stamp=6;P.reportHud(receipt(80,true));assert(hudWrites==2,'new layout failure was not logged immediately')
stamp=7;P.reportHud(receipt(80));assert(hudWrites==3,'layout recovery was not logged')
stamp=18;P.reportHud(receipt(90));assert(hudWrites==4,'periodic position sample missing')
print('HUD readiness and bounded moving-camera diagnostics: ok')
