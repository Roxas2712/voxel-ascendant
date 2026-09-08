local Public=assert(loadfile('lib/adapters/gen1/OverworldBattlePublic.lua'))()
for _,reason in ipairs({'battle wrapper runtime is rejected','battle wrapper runtime is retired'})do
 local calls=0
 local proxy=Public.new({setLegacyCompatibilityBridge=function()return false,reason end,
   sideTexture=function()calls=calls+1 end})
 assert(type(proxy)=='table' and proxy.sideTexture==nil and proxy.begin==nil)
 proxy.sideTexture=function()error('retired callback ran')end
 assert(proxy.sideTexture==nil and calls==0)
end
local bridge
local p=Public.new({setLegacyCompatibilityBridge=function(value)bridge=value;return true end,
 sideTexture=function()return 'texture' end})
assert(p.sideTexture and bridge)
local bad=pcall(Public.new,{})
assert(not bad,'missing owner contract must still fail')
print('public reload fallback PASS: rejected/retired stay inert; valid owner contract retained')
