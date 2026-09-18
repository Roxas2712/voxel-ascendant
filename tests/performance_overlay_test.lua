local root=arg[1]or'.'
assert(loadfile(root..'/main_gen1.lua'))
local t,c,counters,prints,stack=0,0,{time=0,cpu=0,gpu=0,font=0},{},0
local saved={};local writes=0
local game={save={options={}},mods={modOptions={}},writeOptions=function()writes=writes+1 end}
local V={mod={id='VOXEL_ASCENDANT',options={get=function(_,k)return saved[k]end}}}
local S=assert(loadfile(root..'/lib/ModSetting.lua'))(V)
V.require=function(n)assert(n=='ModSetting');return S end
local oldOs=os;os={clock=function()counters.cpu=counters.cpu+1;return c end,date=function()return'14:23'end}
local g={}
love={timer={getTime=function()counters.time=counters.time+1;return t end},graphics=g}
g.getDimensions=function()return 320,240 end
g.newFont=function(size)counters.font=counters.font+1;return{getWidth=function(_,s)return #s*size*.6 end,getHeight=function()return size end,release=function()end}end
g.getStats=function()counters.gpu=counters.gpu+1;return{texturememory=32*1048576}end
g.push=function()stack=stack+1 end;g.pop=function()stack=stack-1 end
for _,n in ipairs({'setCanvas','origin','setShader','setScissor','setDepthMode','setStencilTest','setBlendMode','translate','scale','setFont','setColor','rectangle','setLineWidth'})do g[n]=function()end end
g.print=function(s)prints[#prints+1]=s end
local M=assert(loadfile(root..'/lib/PerformanceOverlay.lua'))(V)
local function frame()t=t+1/60;c=c+.004;prints={};M.draw();assert(stack==0)end
local function output()return table.concat(prints,'\n')end
assert(M.enabled:get()==false and M.enabled:schema().default==false)
for i=1,70 do frame();assert(#prints==0)end
assert(counters.time+counters.cpu+counters.gpu+counters.font==0,'default overlay polls')
M.enabled:setValue(true,game)
for i=1,70 do frame()end
assert(output():find('14:23',1,true)and output():find('60 FPS  /  16.7 ms',1,true),output())
assert(output():find('CPU 4.0 ms',1,true)and output():find('GPU-Tex 32 MiB',1,true),output())
assert(counters.gpu<=3 and counters.font==1,'expensive per-frame resource/stats work')
M.enabled:setValue(false,game);frame();local before=counters.time+counters.cpu+counters.gpu+counters.font
for i=1,100 do frame();assert(#prints==0)end
assert(counters.time+counters.cpu+counters.gpu+counters.font==before,'disabled overlay polls')
-- All independent combinations and master cycling retain persisted choices.
for mask=0,15 do
 for i,s in ipairs({M.clock,M.fps,M.cpu,M.gpu})do s:setValue(math.floor(mask/2^(i-1))%2==1,game)end
 M.enabled:setValue(true,game)
 for i=1,65 do frame()end
 local o=output()
 for i,label in ipairs({'14:23','FPS','CPU','GPU-Tex'})do assert((o:find(label,1,true)~=nil)==(math.floor(mask/2^(i-1))%2==1),mask..':'..o)end
 M.enabled:setValue(false,game);frame();M.enabled:setValue(true,game)
 for _,s in ipairs({M.clock,M.fps,M.cpu,M.gpu})do assert(s:get()==game.save.options.modOptions.VOXEL_ASCENDANT[s.key])end
end
assert(writes>0);saved=game.mods.modOptions.VOXEL_ASCENDANT
local reload=assert(loadfile(root..'/lib/PerformanceOverlay.lua'))(V)
for _,entry in ipairs(reload.entries())do assert(entry[1]:get()==saved[entry[1].key]);assert(entry.full)end
-- Unsupported counters report unavailable, not zero or invented percentages.
os.clock=nil;g.getStats=function()error('unsupported')end
M.enabled:setValue(false);frame();M.enabled:setValue(true)
for i=1,65 do frame()end
assert(output():find('CPU -- ms',1,true)and output():find('GPU-Tex -- MiB',1,true),output())
-- Final seam preserves exact nil-bearing returns, installs once, restores
-- graphics state even on a failed draw, and never consumes update/input.
local calls=0;game.draw=function()calls=calls+1;return'original',nil,42 end
M.install(game);local installed=game.draw;M.install(game);assert(game.draw==installed)
g.print=function()error('lost graphics resource')end
local a,b,d=game:draw();assert(a=='original'and b==nil and d==42 and calls==1 and stack==0)
os=oldOs
print('PASS live overlay: all switches, persistence, real timing, unavailable counters, cached resources, disabled zero polling, draw-state/error isolation')
