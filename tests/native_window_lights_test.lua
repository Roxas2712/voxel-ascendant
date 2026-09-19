local root=assert(arg[1]);local structs={}
local rects={{x=8,y=8,w=6,h=5}}
local modules={Structures={forMap=function(m)return structs[m]end},
 GlassMask={rects=function()return rects end},
 LedgeElevation={map=function()return {atTile=function(_,x)return x>=2 and 12 or 0 end}end}}
local M=assert(loadfile(root..'/lib/NativeWindowLights.lua'))({require=function(n)return modules[n]end})
local pane={{8,8,32},{16,8,32},{16,16,32},{8,16,32},u=10/128,v=10/128}
local roof={{0,20,0},{32,20,0},{32,20,32},{0,20,32},u=10/128,v=10/128}
local template={pane,roof}
local shape=M.shape(template,rects,128,128)
assert(#shape.panes==1 and shape.panes[1].normal[3]==1,'roof or reversed window source')
assert(M.shape(template,rects,128,128)==shape,'template rescanned')
local compact={compact=true}
for _,q in ipairs(template)do
 local c={};for i=1,4 do for a=1,3 do c[#c+1]=q[i][a]end end
 for i=1,4 do c[#c+1]=q.u;c[#c+1]=q.v end;c[21]=1;compact[#compact+1]=c
end
local packed=M.shape(compact,rects,128,128)
assert(#packed.panes==1 and packed.panes[1].z==shape.panes[1].z,'compact geometry mismatch')
local a,b={tileset={}},{tileset={}}
structs[a]={buildingStamps={{quads=template,mx=0,mz=0,doorGroundSamples={2,3}}}}
structs[b]={buildingStamps={{quads=compact,mx=0,mz=0}}}
local sources,blockers={},{}
M.append({map=a,neighbors={{map=b,ox=80,oy=-32}}},sources,blockers,1,{0,0,0})
assert(#sources==2 and #blockers==2,'native world enumeration')
assert(sources[1].y==24 and sources[1].owner==blockers[1],'door elevation/owner lost')
assert(sources[2].x==sources[1].x+80 and sources[2].z==sources[1].z-32,'neighbor transform')
structs[a]={buildingStamps={}};sources,blockers={},{}
M.append({map=a},sources,blockers,1,{0,0,0})
assert(#sources==0 and #blockers==0,'hidden native building retained a ghost lamp')
M.invalidate();assert(M.shape(template,rects,128,128)~=shape,'reset retained templates')
print('PASS_NATIVE_WINDOW_LIGHTS: original and compact geometry, roof exclusion, template cache, elevation, neighbors and replacement ownership')
