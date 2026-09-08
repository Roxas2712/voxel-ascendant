local forced, attached = 0, 0
local mobile = {
 isMobileRuntime=function()return false end,
 attach=function(state)attached=attached+1;return state,false,'desktop-native-path'end,
}
local bridge=assert(loadfile('lib/Gen1MobileMenuBridge.lua'))({
 mod={},require=function(name)assert(name=='MobileMenuPresentation');return mobile end,
 OrasUiSkin={controller={decorateMobileBag=function(state)
  forced=forced+1;state.__vascOrasBagStyle='oras_wide';state.__vascOrasBagPresentation=true
  return state,true
 end}},
})
local bag={screenId='BagMenu',draw=function()end,uiSize=function()return 160,144 end}
for _=1,3 do
 local state,ok,why=bridge.attach(bag)
 assert(state==bag and not ok and why=='desktop-native-path')
 bridge.reconcileVisible(bag)
end
assert(forced==0 and attached==0,'mobile router mutated desktop bag ownership')
assert(not bag.__vascOrasBagPresentation,'desktop bag acquired wide modal parent marker')
print('desktop bag owner: ok')
