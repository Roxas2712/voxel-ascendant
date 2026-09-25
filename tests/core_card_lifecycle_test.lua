local V={};function V.require(n)return assert(loadfile('lib/'..n..'.lua'))(V)end
local Registry=V.require('core/AscendantCardRegistry');local r=Registry.new();local context;local aborts=0;local allowAbort=false;local delivered=0
local function descriptor(id)
 return{schema='ascendant.card/v1',id=id,version='1.0.0',owner='test',requires={},optionalRequires={},consumes={},provides={},saveNamespace=false,
 tests={'tests/core_card_lifecycle_test.lua'},docs={'FULL_CODE_AUDIT_2026-09-25.md'},impact={runtimeOwners={},saveWrites={},publicHooks={'test.event'},files={'tests/core_card_lifecycle_test.lua'}},
 lifecycle={install=function()return{}end,activate=function(c)context=c;assert(c.hooks.on('test.event',function()delivered=delivered+1 end));return{}end,
 deactivate=function()return true end,abort=function()aborts=aborts+1;return allowAbort end,health=function()return{ok=true}end}}
end
local provider=descriptor('provider');provider.provides={'test.service/v1'};provider.lifecycle.activate=function()return{private=true},{value=42}end
assert(r:register(provider));local consumer=descriptor('consumer');consumer.requires={'provider'};assert(r:register(consumer));assert(r:activate('consumer'))
assert(r:state('provider')=='active');assert(not r:deactivate('provider'),'active provider retired under consumer')
r.hooks:emit('test.event',{});assert(delivered==1)
assert(r:deactivate('consumer'));assert(r.hooks:emit('test.event',{}).delivered==0)
assert(not context.hooks.on('test.event',function()end),'stale activation lease accepted hook')
assert(r:deactivate('provider'))
local broken=descriptor('broken');broken.lifecycle.activate=function(c)assert(c.hooks.on('test.event',function()error('leaked hook')end));error('activation failed')end
assert(r:register(broken));assert(not r:activate('broken'));assert(r:state('broken')=='rollback_pending')
assert(r.hooks:health().listeners==0);assert(not r:activate('broken'),'failed cleanup allowed reactivation')
allowAbort=true;assert(r:deactivate('broken'));assert(r:state('broken')=='failed'and aborts==2)
print('PASS card lifecycle: dependency ownership, deactivate, stale lease rejection, failed activation and rollback retry')
