local f=assert(io.open('main_gen1.lua'));local text=f:read('*a');f:close()
local a=assert(text:find('if mod.events and type(mod.events.on)',text:find('V.stadiumRomManagerOptionsInstalled',1,true),true))
local b=assert(text:find('local battleRuntimeInstallStatus',a,true))
local handler,polled
local V={StadiumRomMenu={poll=function(g)polled=g end}}
local env=setmetatable({V=V,mod={events={on=function(_,name,fn)assert(name=='game.ready');handler=fn end}}},{__index=_G})
local code=assert(loadstring(text:sub(a,b-1),'@gen1-stadium-ready'));setfenv(code,env);code()
local game={data={pokemon={ONIX={dex=95}}}}
handler({game=game})
assert(V.game==game and polled==game,'Stadium bound event envelope instead of species catalogue')
local legacy={data={pokemon={CATERPIE={dex=10}}}}
handler(legacy);assert(V.game==legacy and polled==legacy,'legacy direct event regressed')
handler({});assert(V.game==legacy,'malformed event discarded the live catalogue')
print('Gen1 Stadium ready payload: ok')
