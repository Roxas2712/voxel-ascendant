local rootRows={{id='first'},{id='second',submenu='group'}};local childRows={{id='child'}}
local V={controlsHost={Game={},ready=function()return true end,context=function()return'world'end,rows=function(_,group)return group and childRows or rootRows end}}
local M=assert(loadfile('lib/VascControls.lua'))(V)
local states={{}};local game={stack={top=function()return states[#states]end,push=function(_,v)states[#states+1]=v end,pop=function()table.remove(states)end}}
assert(M.open(game,2));assert(M.activate(game,2));assert(M.current(game).group=='group');M.back(game)
assert(M.current(game).rows[M.current(game).selected].id=='second','F3 Back lost the originating group')
childRows={};assert(not M.activate(game,2),'empty group entered');assert(M.current(game).group==nil and #M.current(game).rows==2)
M.panelKey(game,'f3');assert(not M.current(game));assert(M.open(game,-2));assert(M.current(game).selected==1)
M.panelKey(game,'escape');assert(#states==1)
print('PASS F3: parent focus, empty groups, close/back and selection bounds')
assert(M.open(game));M.current(game).rows[1].status=function()error('optional provider unavailable')end
assert(M.status(game,1)=='Unavailable','optional status failure crashed F3')
