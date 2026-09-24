-- Native GPU regression: mobile layers compile, render and retain their mesh.
local root=assert(arg[1])
 local world={curveX=160,curveZ=160,curveK=.0002}
 local modules={Voxel3D=world,Sky={clock=65000},Weather={isLavender=function()return true end},LedgeElevation={basisAtCell=function()return 0 end}}
 local M=assert(loadfile(root..'/lib/IndoorMist.lua'))({require=function(n)return assert(modules[n],n)end})
 local g=love.graphics;local meshes=0;local original=g.newMesh
 g.newMesh=function(...)meshes=meshes+1;return original(...)end
 local canvas=g.newCanvas(128,128,{dpiscale=1})
 local map={id='LAVENDER_TOWN',def={width=10,height=9}};local profile={height=48,color={.43,.44,.49}}
 local vp={1/176,0,0,-.82, 0,0,1/176,-.82, 0,-1/128,0,0, 0,0,0,1}
 g.setCanvas{canvas,depth=true};g.clear(.2,.2,.2,1,0,1)
 assert(M.drawLayers(map,profile,vp));assert(meshes==1)
 g.setCanvas()
 for i=1,30 do
  world.curveX=world.curveX+.125;modules.Sky.clock=modules.Sky.clock+1/60
  g.setCanvas{canvas,depth=true};g.clear(.2,.2,.2,1,0,1);assert(M.drawLayers(map,profile,vp));g.setCanvas()
 end
 assert(meshes==1,'camera/clock rebuilt static fog mesh')
 local im=canvas:newImageData();local lit=0
 for y=0,127 do for x=0,127 do local r,b,c,a=im:getPixel(x,y);assert(r==r and b==b and c==c and a==a);if r>.205 then lit=lit+1 end end end
 assert(lit>1000,'fog did not render');im:release()
 profile.height=42;g.setCanvas{canvas,depth=true};M.drawLayers(map,profile,vp);g.setCanvas();assert(meshes==2,'height change kept old fog layers')
 M.invalidate();canvas:release();g.newMesh=original;print('PASS mobile fog native draw, finite late-session pixels, camera-stable mesh, profile rebuild',lit)
