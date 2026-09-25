local Hooks=dofile('lib/core/AscendantHooks.lua')
local bus=Hooks.new{onError=function()error('diagnostics unavailable')end};local calls={};local second;local first=true
local function add(s)calls[#calls+1]=s end
bus:subscribe('event','a',function(payload)
 add('a'..payload.n);payload.n=99
 if first then first=false;bus:unsubscribe(second);bus:subscribe('event','c',function(p)add('c'..p.n)end,0);bus:emit('event',{n=2})end
end,10)
second=bus:subscribe('event','b',function()error('removed listener ran')end)
bus:subscribe('event','broken',function()error('expected failure')end,-10)
local input={n=1};local result=bus:emit('event',input)
assert(table.concat(calls,',')=='a1,a2,c2','recursive snapshot changed callback ordering: '..table.concat(calls,','))
assert(input.n==1 and result.delivered==1 and #result.errors==1)
calls={};bus:emit('event',{n=3});assert(table.concat(calls,',')=='a3,c3')
assert(bus:deactivateOwner('c')==1 and bus:deactivateOwner('c')==0);calls={};bus:emit('event',{n=4});assert(table.concat(calls,',')=='a4')
local cycle={};cycle.self=cycle;assert(bus:emit('event',cycle).delivered==0)
assert(bus:health().invalidPayloads==1 and bus:health().listenerFailures==4)
for i=1,1000 do bus:emit('unsubscribed.'..i,{})end
if bus.eventSnapshots then local n=0;for _ in pairs(bus.eventSnapshots)do n=n+1 end;assert(n==1,'empty events grew cache')end
print('PASS core hooks: priority, recursive emit, mutation, removal, payload isolation and failing listener/diagnostics')
