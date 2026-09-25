local file=assert(io.open('lib/OverworldBattle.lua'));local source=file:read('*a');file:close()
local snippet=assert(source:match('(local timeoutReason="scene%-render%-timeout".-markSessionNative%(session, "scene%-render%-timeout", timeoutReason%))'))
local inbox=assert(loadfile('lib/ErrorInbox.lua'))().new()
local scene={lastDeclineReason='camera-unavailable:playerHero-under-command'}
local function run()
 local f=assert(loadstring(snippet));setfenv(f,setmetatable({BattleScene=scene,session={},markSessionNative=function(_,_,reason)
  local row=inbox:observe('battle-native-latch',{reason=reason});assert(row.reason:find(reason,1,true));return row
 end},{__index=_G}));f()
end
run();assert(inbox.items[1].reason=='scene-render-timeout: camera-unavailable:playerHero-under-command')
scene.lastDeclineReason=nil;run();assert(inbox.items[1].reason=='scene-render-timeout')
print('PASS timeout retains actual camera/asset decline in screenshot error; nil reason remains safe')
