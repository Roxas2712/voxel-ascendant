local calls=0
local mobile={isMobileRuntime=function()return true end,
 attach=function(state)calls=calls+1;return state,true end}
local bridge=assert(loadfile('lib/Gen1MobileMenuBridge.lua'))({
 mod={},require=function(name)assert(name=='MobileMenuPresentation');return mobile end})
local native=function()end
local state={screenId='MoveLearnMenu',isOpaque=true,items={},draw=native,
 uiSize=function()return 160,144 end}
-- Enter pushes a nested prompt before the final presentation is installed.
for _,operation in ipairs({bridge.attach,bridge.reconcileVisible})do
 local result,ok,reason=operation(state)
 assert(result==state and not ok and reason=='move-learn-owner')
end
assert(calls==0 and state.draw==native)
state.__vascMoveLearnPresentation=true
state.__kantoAscendantLayout=true
state.__vascMobileMenuOwner='move_learn'
state.uiSize=function()return 512,288 end
for _,operation in ipairs({bridge.attach,bridge.reconcileVisible})do
 local _,ok,reason=operation(state)
 assert(not ok and reason=='move-learn-owner')
end
assert(calls==0,'generic bridge captured dedicated move-learning renderer')
local _,floatingOk,floatingReason=bridge.attach({screenId='PartyMenu',draw=native,__floatingBattleParty={}})
assert(not floatingOk and floatingReason=='battle-hud-owner' and calls==0,
 'window-space battle HUD captured in menu canvas')
local _,ok=bridge.attach({screenId='PartyMenu',draw=native})
assert(ok and calls==1,'ordinary mobile menus lost their presenter')
print('mobile move-learn ownership: ok')
