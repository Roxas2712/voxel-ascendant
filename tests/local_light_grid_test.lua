local root=assert(arg[1]);local modules={CanvasPresentation={OS='iOS'},ModSetting={new=function()return{get=function()return true end,setGate=function()end}end},Sky={clock=0},DayNight={},Shadows={enabled=function()return false end}}
local V={mod={read=function(_,p)local f=assert(io.open(root..'/'..p));local s=f:read('*a');f:close();return s end}}
V.require=function(n)if modules[n]then return modules[n]end;local m=assert(loadfile(root..'/lib/'..n..'.lua'))(V);modules[n]=m;return m end
local L=V.require('LocalLights');local Grid=V.require('LocalLightGrid')
local pool={};for i=1,72 do pool[i]={x=i*128,y=16,z=0,radius=56,power=1,normal={0,0,0},color={1,.5,.2},owner={}}end
local layout=Grid.layout(pool);assert(layout.stride==2,'disjoint lights should cost one lamp per cell')
local g=love.graphics
local shader=g.newShader(L.glsl()..[[
uniform vec3 probe;uniform float mode;
vec4 effect(vec4 c,Image t,vec2 uv,vec2 screen) {
 vec3 light=localIrradiance(probe,vec3(0,1,0));
 if(mode>.5)light=localActorIrradiance(probe,vec3(0,1,0));
 return vec4(light,1.0);
}]])
local canvas=g.newCanvas(1,1,{dpiscale=1})
local function setup(focus,buildings)
 L.clear();L.current().map={def={width=200,height=20}};L.current().tint={1,1,1}
 L.assign(pool,buildings or {},focus,false);L.send(shader,true)
end
local function probe(x,y,z,mode)
 shader:send('probe',{x,y,z});shader:send('mode',mode or 0)
 g.push('all');g.setCanvas(canvas);g.origin();g.setShader(shader);g.setBlendMode('replace');g.setColor(1,1,1,1);g.rectangle('fill',0,0,1,1);g.pop()
 local d=canvas:newImageData();local r=d:getPixel(0,0);d:release();return r
end
setup({128,0,0});local first=probe(128,0,0)
assert(first>.25,'first lamp dark')
for i=1,72 do assert(math.abs(probe(i*128,0,0)-first)<.02,'screen-wide lamp '..i..' dark')end
assert(probe(128,0,100)==0,'sphere range ignored')
assert(probe(128,16,10,1)>.1,'actor illumination missing')
local rebuilds=Grid.last.visibilityRebuilds
setup({9216,0,0})
assert(Grid.last.visibilityRebuilds==rebuilds,'player movement rebuilt geometry')
for i=1,72 do assert(math.abs(probe(i*128,0,0)-first)<.02,'walking changed lamp '..i)end
-- Every light receives its own blocker budget, not the four nearest the hero.
local walls={};for i=1,72 do walls[i]={lo={i*128-40,-2,8},hi={i*128+40,40,12}}end
setup({128,0,0},walls)
assert(probe(128,0,20)==0 and probe(9216,0,20)==0,'distant wall leaks')
local before=Grid.last.visibilityRebuilds;pool[1].power=.5;setup({128,0,0},walls)
assert(Grid.last.visibilityRebuilds==before,'flicker rebaked visibility')
L.clear(true);L.send(shader,false);assert(probe(128,0,0)==0,'OFF retains light')
L.invalidate();setup({128,0,0});assert(probe(9216,0,0)>.25,'reset lost distant lights')
print('PASS 72 simultaneous lights, mobile budget, actors, movement invariance, range, per-light walls, cached flicker, OFF and reset')
