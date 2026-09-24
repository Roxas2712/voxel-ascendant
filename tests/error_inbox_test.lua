local M=dofile('lib/ErrorInbox.lua');local now=0;local inbox=M.new(function()return now end)
inbox.context={map='ROUTE_1',x=5,y=3,version='TEST',platform='iOS',session='S'}
for _,f in ipairs({{expected=true},{status='pending'},{status='disabled'},{status='EXPECTED_FALLBACK'}})do assert(not inbox:observe('mobile-renderer-fallback',f))end
assert(not inbox:observe('battle-camera-static-fallback',{reason='deliberate motion setting'}))
assert(not inbox:observe('battle-scene-nil',{reason='cooperative-loading'}))
local r,fresh=inbox:observe('vasc.mobile.FIRST-FAILURE',{code='D07',status='FAILURE',reason='shader compiler rejected program'})
assert(r.code=='D07' and fresh and r.platform=='iOS' and inbox.unread==1)
for i=1,10000 do inbox:observe('vasc.mobile.FIRST-FAILURE',{code='D07',status='FAILURE',reason='shader compiler rejected program'})end
assert(#inbox.items==1 and r.count==1,'per-frame storm grew receipts')
now=2;inbox:observe('vasc.mobile.FIRST-FAILURE',{code='D07',status='FAILURE',reason='shader compiler rejected program'});assert(r.count==2)
inbox:read(r);assert(inbox.unread==0)
inbox.onNew=function()error('broken reporting observer')end
local art=inbox:observe('battle-sprite-unavailable',{requested='cobblemon',actual='crystal',reason='missing model'});assert(art.code=='E_ART')
local fallback=inbox:observe('vasc.battle.battle-native-latch',{provider='MAP',reason='scene-render-timeout'});assert(fallback.actual=='VANILLA / 2D')
local sanitized=M.clean('read /Users/private/secrets.txt https://x.test/token\nfailed');assert(not sanitized:find('private',1,true) and not sanitized:find('token',1,true))
for i=1,100 do inbox:observe('hook-error',{owner='test'..i,error=string.rep('x',10000)})end
assert(#inbox.items==32 and inbox.unread==32 and #inbox.items[1].reason==180)
print('PASS error receipts: quiet OFF/warmup, namespaced failure, bounded storm, classification, redaction and observer isolation')

local activities=M.new(function()return 0 end)
activities:observe('battle-native-latch',{activity='graphics-check',reason='timeout'})
activities:observe('battle-native-latch',{activity='gameplay',reason='timeout'})
assert(#activities.items==2 and activities.items[1].activity=='gameplay')
