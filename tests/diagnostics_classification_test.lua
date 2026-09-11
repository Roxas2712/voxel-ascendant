local time=0
love={timer={getTime=function()return time end},graphics={getStats=function()return {}end}}
local P=assert(loadfile('lib/PerformanceDiagnostics.lua'))({})
P.noteEvent('vasc.walker.fallback',{status='EXPECTED_FALLBACK',reason='KASC absent'})
assert(next(P.findings)==nil,'optional KASC absence classified as runtime error')
P.beginLoad('battle',{});time=30
P.endLoad('battle',{status='unobserved',source='battle.ended-before-first-hud'})
assert(next(P.findings)==nil,'missing HUD observation classified as failed/slow load')
P.beginLoad('battle',{})
P.noteEvent('vasc.battle.battle-native-latch',{status='native_latched',reason='scene-cover-unavailable'})
assert(not P.pendingLoads.battle and P.latestLoads.battle.result=='unobserved','native HUD wait would become a false timeout')
P.beginLoad('battle',{})
P.noteEvent('vasc.battle.ended',{})
assert(P.latestLoads.battle.result=='unobserved','event observer still reports false failure')
P.noteEvent('vasc.render.error' ,{status='failed'})
assert(next(P.findings)~=nil,'real errors must remain visible')
print('Expected fallback and missing observation are not runtime failures: OK')
