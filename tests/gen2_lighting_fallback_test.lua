local root=assert(arg[1]);local f=assert(io.open(root..'/gen2/lib/Voxel3D.lua'));local source=f:read('*a');f:close()
local a=assert(source:find('local litShaders={}',1,true));local b=assert(source:find('-- Read-only production-source',a,true))
local attempts=0;local failure;local good={};local G={}
local L={mobile=true,available=function()return not failure end,fail=function(e)failure=e end,glsl=function()return 'uniform float localLightCount;'end}
local fakeLove={graphics={newShader=function(s)
 attempts=attempts+1;if s:find('localLightCount',1,true)then error('injected mobile shader rejection')end;return good
end}}
local V={require=function(n)assert(n=='LocalLights');return L end}
assert(loadstring([[local V,Voxel3D,love=...;local shaders={};local SHADER='#ifdef PIXEL';local function derivativesOK()return false end;
]]..source:sub(a,b-1)))(V,G,fakeLove)
assert(G.shader(false,true)==good and failure and attempts==2,'3D lost after light shader rejection')
for _=1,10 do assert(G.shader(false,true)==good)end
assert(attempts==2,'failed lighting retried every frame')
failure=nil;assert(G.shader(false,true)==good and attempts==3 and failure,'explicit reset did not retry once')
failure=nil;assert(G.shader(true,true)==nil and not failure,'unsupported grid disabled lighting')
print('PASS_GEN2_LIGHTING_FALLBACK: baseline 3D preserved, bounded retry, grid capability isolation')
