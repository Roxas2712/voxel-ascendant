local meshCount,shaderCount,releasedMesh,releasedShader,pushes,reports=0,0,0,0,0,0
local failCompile,failMesh,failDraw=true,false,false
local shader={send=function()end,release=function()releasedShader=releasedShader+1 end}
love={graphics={newMesh=function()meshCount=meshCount+1;if failMesh then error('injected allocation failure')end;return {release=function()releasedMesh=releasedMesh+1 end}end,
 newShader=function(pixel)shaderCount=shaderCount+1;assert(not pixel:match('float%s+patch%s*='));if failCompile then error('injected compiler rejection')end;return shader end,
 push=function()pushes=pushes+1 end,pop=function()pushes=pushes-1 end,
 setShader=function()end,setColor=function()end,setBlendMode=function()end,setMeshCullMode=function()end,setDepthMode=function()end,
 draw=function()if failDraw then error('injected draw failure')end end}}
local api={Voxel3D={eye={0,20,100},vp={}},Mat4={translate=function()return {}end},ballAppearance=function()return {kind=0,base={},accent={}}end,reportDomeFailure=function()reports=reports+1 end}
local factory=assert(loadfile('integrated/terarrium/Dome.lua'))()
local dome=factory(api);local arena={mid={0,0},terarrium={ballStyle='poke'}}
assert(dome.draw(arena,0,'clear')==false and dome.failure)
assert(meshCount==1 and releasedMesh==1 and reports==1,'partial resources leaked')
for i=1,60 do assert(dome.draw(arena,0,'clear')==false)end
assert(shaderCount==1 and meshCount==1,'failed effect recompiles every frame')
dome.release();failCompile=false;assert(dome.draw(arena,0,'blue'));assert(pushes==0)
failDraw=true;assert(dome.draw(arena,0,'blue')==false);assert(pushes==0 and reports==2,'draw state not restored')
dome.release();assert(releasedMesh==2 and releasedShader==1)
failDraw=false;failMesh=true;assert(dome.draw(arena,0,'clear')==false);dome.release()
failMesh=false;assert(dome.draw(arena,0,'rose'));dome.release()
print('PASS optional dome: atomic creation, bounded failure, cleanup, retry after release, restored draw state')
