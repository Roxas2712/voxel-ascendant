-- Native source adapter tests: no Gen1 map semantics and no render-time builds.
local root=assert(arg[1]);local enabled=true;local glow=1;local cache={};local builds=0
local V={lightingGeneration=2};local modules={}
V.mod={_vascHostGeneration=2,options={get=function()return enabled end},
 read=function(_,p)assert(p=='lib/lighting/LocalLightsCore.lua');local f=assert(io.open(root..'/lib/LocalLights.lua'));local s=f:read('*a');f:close();return s end}
modules.ModSetting={new=function()return {setGate=function()end,onChange=function()end,get=function()return enabled end}end}
modules.CanvasPresentation={OS='Android'}
modules.Structures={lightingForMap=function(m)return cache[m]end,forMap=function()builds=builds+1;error('lighting started a geometry build')end}
local rects={{x=2,y=2,w=2,h=5}}
modules.GlassMask={rects=function()return rects end}
modules.Voxel3D={tint={.4,.4,.6}}
modules.DayNight={windowLight=function()return glow end,isCanopy=function()return false end,
 rigTime=function()return 1 end,time=function()return 1 end,shearAt=function()return .4,.5,false end,strengthAt=function()return 1 end}
modules.LightVisibility={invalidate=function()end}
V.require=function(n)
 if modules[n]then return modules[n]end
 assert(n=='NativeWindowLights','Gen1 dependency leaked: '..n)
 modules[n]=assert(loadfile(root..'/lib/'..n..'.lua'))(V);return modules[n]
end
local L=assert(loadfile(root..'/gen2/lib/LocalLights.lua'))(V)
assert(L.supported and L.MAX_LIGHTS==4 and L.MAX_BLOCKERS==4)
local W=V.require('NativeWindowLights')
-- Native facade quads span a complete atlas tile. Its midpoint is a mullion;
-- the pane overlaps must still produce light, but never a horizontal roof.
local face={{0,0,8},{8,0,8},{8,8,8},{0,8,8},uv={{0,1},{1,1},{1,0},{0,0}}}
local roof={{0,8,0},{8,8,0},{8,8,8},{0,8,8},uv=face.uv}
local shape=W.shape({face,roof},rects,8,8);assert(#shape.panes==1)
local a,b={id='GOLDENROD_CITY',def={generation=2},tileset={}},{id='ROUTE_35',def={generation=2},tileset={}}
-- Compact receipts survive Structures.releaseAux; no geometry is retained.
cache[a]={lightBuildingStamps={}};cache[b]={lightBuildingStamps={{mx=0,mz=0,lightShape=shape}}}
for i=1,10 do cache[a].lightBuildingStamps[i]={mx=i*12,mz=0,lightShape=shape}end
local s={map=a,neighbors={{map=b,ox=24,oy=64}}}
L.prepare(s,true,{30,4,16},false,'clear')
assert(#L.current().lights==4 and #L.current().blockers<=4 and L.current().sky)
for _,l in ipairs(L.current().lights)do assert(l.owner and l.weight and l.normal[3]==1)end
-- Off is authoritative even when a separate menu setting object wrote it.
enabled=false;L.prepare(s,true,{30,4,16});assert(not L.active() and #L.current().lights==0)
enabled=true;glow=0;L.prepare(s,true,{30,4,16});assert(L.current().sky and #L.current().lights==0)
glow=1;L.prepare({map=b},false,{0,0,0});assert(not L.current().sky and #L.current().lights==0)
cache[b]=nil;L.prepare({map=b},true,{0,0,0});assert(#L.current().lights==0 and builds==0)
L.fail('test failure');assert(not L.enabled());L.invalidate();assert(L.enabled())
print('PASS_GEN2_LOCAL_LIGHTS: mobile caps, pane overlap, compact caches, OFF persistence source, map/interior reset, no synchronous geometry and recovery')
