-- RC4 handoff behavioral tests, run against this worktree's actual modules.
local root=arg[1] or '.'
Restart=assert(loadfile(root..'/lib/SpriteContentRestart.lua'))()

local saves,restarts,shows=0,0,0
local ow={isOverworld=true};local top=ow
local g={overworld=ow,input={},stack={states={ow},top=function()return top end},writeSave=function()saves=saves+1;return true end,restartWithMods=function()assert(saves>0);restarts=restarts+1 end}
local safe=true
local r=Restart.new{worldSafe=function()return safe end,show=function(_,r)shows=shows+1;top={ascendantContentRestart=true}end}
local function ticks(n,complete,busy)for i=1,n do r:update(g,.1,complete,busy)end end
ticks(50,true,false);assert(shows==0,'installed-only boot restarted')
r:installed();ticks(50,false,true);assert(shows==0,'restarted mid queue')
safe=false;ticks(50,true,false);assert(r.phase=='waiting'and saves==0)
safe=true;top={isBattle=true};g.stack.states={ow,top};ticks(50,true,false);assert(saves==0,'saved in battle')
g.stack.states={ow};top=ow;ticks(50,true,false);assert(saves==1 and restarts==1 and r.phase=='restarted')
ticks(50,true,false);assert(saves==1 and restarts==1,'duplicate restart')
-- Save veto and exception must never restart. Retry goes through engine writer.
saves=0;restarts=0;top=ow;g.writeSave=function()saves=saves+1;return false end
r=Restart.new{worldSafe=function()return true end,show=function()top={ascendantContentRestart=true}end};r:installed();ticks(50,true,false)
assert(r.phase=='save_error'and saves==1 and restarts==0)
ticks(50,true,false);assert(saves==1,'save error retried automatically')
g.writeSave=function()saves=saves+1;error('disk full')end;r:retry();ticks(50,true,false);assert(r.phase=='save_error'and restarts==0)
g.writeSave=function()saves=saves+1;return true end;r:retry();ticks(50,true,false);assert(r.phase=='restarted'and restarts==1)
-- Title: no progress save or overwrite, still mandatory restart.
saves=0;restarts=0;top={screenId='TitleState'};g.stack.states={top};g.restartWithMods=function()restarts=restarts+1 end
r=Restart.new{worldSafe=function()return false end,show=function()end};r:installed();ticks(50,true,false);assert(saves==0 and restarts==1)
-- Unknown intro is neither a title nor a safe playable world.
top={screenId='OakIntro'};g.stack.states={top};restarts=0
r=Restart.new{worldSafe=function()return true end,show=function()error('must not show')end};r:installed();ticks(50,true,false);assert(restarts==0 and r.phase=='waiting')
print('PASS queue completion, no-op, title, battle/unsafe deferral, one save/restart, veto/error and explicit retry')
