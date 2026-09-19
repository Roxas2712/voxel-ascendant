local root=assert(arg[1])
local function read(path)local f=assert(io.open(root..'/'..path));local s=f:read('*a');f:close();return s end
local source=read('lib/Voxel3D.lua');local a=assert(source:find('function Voxel3D.shader(grid)',1,true));local b=assert(source:find('-- Private QA receipts.',a,true))
local calls={};local failure;local good={};local G={}
local function compile(variant,grid,lighting)
 calls[#calls+1]={variant,grid,lighting}
 if lighting~=false then return nil,'injected mobile linker rejection' end
 return good
end
local V={require=function(name)assert(name=='LocalLights');return {fail=function(reason)failure=reason end}end}
local factory=assert(loadstring([[local Voxel3D,V,compileShader=...;local shaders,shaderVariants,shaderErrors={},{},{};local MOBILE_RUNTIME=true;local function warnShader()end;local function mobileDiagnostic()end;
]]..source:sub(a,b-1)))
factory(G,V,compile)
assert(G.shader(false)==good and #calls==2 and failure,'lighting failure removed 3D')
assert(calls[1][1]=='mobile-core' and calls[2][3]==false,'unsafe fallback order')
assert(G.shader(false)==good and #calls==2,'rejected light shader recompiled each frame')
local style=assert(loadfile(root..'/integrated/ascendant_pokemon_overworld/src/pokemon_card_style.lua'))()
local shader={send=function()end};local attempts=0;local failed=false
local graphics={newShader=function(text)attempts=attempts+1;if text=='reject' then error('injected light-card rejection')end;assert(text==style.shaderSource);return shader end}
local scene={lightCardSource=function()return 'reject'end,cardLightFailed=function()failed=true end}
local instance=style.new()
local result=instance:prepare(graphics,scene,nil,0,{mode='anime',source='go',kind='hd-cards',imageWidth=64,imageHeight=64,columns=4,rows=4,column=0,row=0})
assert(result==shader and attempts==2 and failed,'HD sprite did not retain original shader')
print('PASS_MOBILE_LIGHTING_FALLBACK: failed light shader keeps 3D and HD cards, no per-frame retries')
