local root=assert(arg[1]);local active=true;local clock=.8
local G={vp={.1,0,0,0,0,.1,0,0,0,0,.1,0,0,0,0,1},focus={0,0,0}}
local frame={map={id='CAVE',def={generation=1,width=10,height=10}},lights={
 {kind='torch',x=0,y=-1,z=0,radius=24,power=1,weight=1}}}
local modules={Voxel3D=G,LocalLights={current=function()return frame end,active=function()return active end},
 Sky={clock=clock},DayNight={windowLight=function()return 1 end}}
local M=assert(loadfile(root..'/lib/LightAtmosphere.lua'))({require=function(n)return assert(modules[n],n)end})
local forest={id='VIRIDIAN_FOREST',def={generation=1,width=30,height=40},isWalkableCell=function()return true end}
local scene={map=forest,lights={},sky={canopy=1}}
local a,n=M.sample(scene,{240,0,240},1,1);assert(n>0 and n<=25)
local x,z=a[1].x,a[1].z
local b,m=M.sample(scene,{240,0,240},2,1);assert(m>0 and (b[1].x~=x or b[1].z~=z),'fireflies do not move')
local _,day=M.sample(scene,{240,0,240},2,0);assert(day==0,'fireflies visible at noon')
forest.isWalkableCell=function()return false end
local _,blocked=M.sample(scene,{240,0,240},2,1);assert(blocked==0,'fireflies spawn inside solid forest')
for i=1,100 do scene.lights[i]={kind='torch',x=i,y=0,z=i,radius=62,power=1,weight=1}end
local _,budget=M.sample(scene,{240,0,240},1,1);assert(budget==M.MAX_PARTICLES)
scene.lights={{kind='window',x=0,y=0,z=0,power=1,radius=62}};local _,windows=M.sample(scene,{0,0,0},1,0);assert(windows==0,'windows emit sparks')
scene.map={id='FOREST',def={generation=2}};local _,gen2=M.sample(scene,{0,0,0},1,1);assert(gen2==0)
local outside,inside={def={generation=1}},{def={generation=1}}
local first={tint={1,.8,.6}};M.transition(first,{map=outside},true,0)
local nextFrame={tint={.4,.5,.7}};M.transition(nextFrame,{map=inside},true,.1)
assert(nextFrame.tint[1]==1,'doorway starts with a hard tint jump')
nextFrame={tint={.4,.5,.7}};M.transition(nextFrame,{map=inside},true,.325)
assert(math.abs(nextFrame.tint[1]-.7)<.001,'doorway does not interpolate')
nextFrame={tint={.4,.5,.7}};M.transition(nextFrame,{map=inside},true,.7);assert(nextFrame.tint[1]==.4)
local dark={tint={.08,.08,.1}};M.transition(dark,{map=outside,dark=true},true,.8);assert(dark.tint[1]==.08,'FLASH darkness lifted')
local off={tint={1,1,1}};M.transition(off,{map=inside},false,.9);assert(off.tint[1]==1)
-- Real framebuffer: the new batch must obey scene depth and restore state.
local g=love.graphics;local target=g.newCanvas(32,32,{dpiscale=1})
local function draw(depth)
 g.push('all');g.setCanvas({target,depth=true});g.origin();g.clear(0,0,0,0,0,depth)
 g.setShader();g.setBlendMode('alpha');g.setDepthMode('always',true)
 local rendered=M.draw({map=frame.map})
 assert(g.getShader()==nil and g.getBlendMode()=='alpha','particle draw leaked graphics state')
 local mode,write=g.getDepthMode();assert(mode=='always' and write,'particle draw leaked depth state')
 g.setCanvas();g.pop();local data=target:newImageData();local total=0
 for y=0,31 do for x=0,31 do local r,green,b=data:getPixel(x,y);total=total+r+green+b end end
 data:release();return total,rendered
end
local visible=draw(1);assert(visible>0,'spark shader draws no visible pixels')
assert(draw(0)==0,'sparks shine through opaque foreground depth')
active=false;local pixels,rendered=draw(1);assert(pixels==0 and not rendered,'OFF retains particles')
active=true;M.invalidate();assert(draw(1)>0,'particle renderer failed after reset')
M.invalidate();target:release()
print('PASS_LIGHT_ATMOSPHERE: bounded motes, night gating, solid-cell exclusion, animation, doorway fade, FLASH/OFF, GPU depth occlusion, state restoration and reset')
