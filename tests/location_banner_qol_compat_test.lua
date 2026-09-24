local level={level=1};local clock=10;local draws={}
local g={}
for _,name in ipairs{'push','pop','origin','setCanvas','setShader','setScissor','setDepthMode','setBlendMode','setFont','setColor','setLineWidth','rectangle','circle','arc','line'}do g[name]=function()end end
g.newFont=function()return {getWidth=function(_,s)return #s*8 end,getHeight=function()return 15 end}end
g.print=function(text)draws[#draws+1]=text end
love={graphics=g,timer={getTime=function()return clock end}}
package.loaded['src.core.SafeArea']={windowRect=function()return 0,0,780,360 end}
local M=assert(loadfile('lib/LocationBanner.lua'))({require=function(n)assert(n=='VoxelState');return level end})
local ow={};local top=ow;local game={overworld=ow,stack={top=function()return top end},mods={exports={}}}
M.bridgeToasts(game) -- late-loading mods
local q={toastLayout=function(toast,t)if toast and t<toast.expire then return {text=toast.text,alpha=math.min(1,(toast.expire-t)/.5),offset=3}end end}
game.mods.exports.qol_toggles=q
local original=q.toastLayout;M.bridgeToasts(game);local wrapped=q.toastLayout;M.bridgeToasts(game);assert(q.toastLayout==wrapped)
local toast={text='LAVENDER TOWN',expire=12,duration=3}
for _,t in ipairs{10,11.6,11.9}do clock=t;local row=q.toastLayout(toast,t);assert(row.alpha==0 and row.offset==3 and toast.expire==12);M.draw();assert(draws[#draws]=='LAVENDER TOWN')end
local count=#draws;clock=12;assert(not q.toastLayout(toast,clock));M.draw();assert(#draws==count,'expired toast redrawn')
clock=10;top={};assert(q.toastLayout(toast,clock).alpha==0);M.draw();assert(#draws==count,'toast covers menu')
top=ow;ow.transitioning=true;q.toastLayout(toast,clock);M.draw();assert(#draws==count,'toast covers transition');ow.transitioning=false
level.level=0;assert(q.toastLayout(toast,11.75).alpha==.5,'2D owner changed');M.draw();assert(#draws==count)
level.level=1;q.toastLayout=original;M.bridgeToasts(game);assert(q.toastLayout~=original,'reload not bridged')
print('PASS QOL toast: fade, lifetime, modal/transition gates, 2D, late load and reload')
