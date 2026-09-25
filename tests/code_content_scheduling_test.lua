local M=dofile('lib/SpriteCodeContent.lua')
local safe,busy,ready,plans,starts,callbacks=false,false,false,0,0,0
local raw;local installer={state='idle',start=function(self)starts=starts+1;self.state='downloading';return true end}
local q=M.new{cache={read=function()return raw end,write=function(_,_,v)raw=v;return true end},encode=function()return 'queue'end,decode=function()return {}end,
 resolve=function()return {'package'}end,catalog={plan=function()plans=plans+1;return{ready=ready,canDownload=true,packages={'package'}}end},
 store={packageMounted=function()return true end},installer=installer,safe=function()return safe end,busy=function()return busy end,
 onReady=function()callbacks=callbacks+1;return true end}
assert(q:enqueue('receipt','event',true));assert(plans==1)
for i=1,600 do q:update()end
assert(plans==1,'unsafe updates repeatedly replan content: '..plans)
safe=true;busy=true;for i=1,600 do q:update()end;assert(plans==1,'busy updates replan content')
busy=false;q:update();assert(starts==1 and plans==2)
for i=1,600 do q:update()end;assert(plans==2 and starts==1)
-- Finalize an already-started transfer even if the scene became unsafe.
safe=false;ready=true;installer.state='ready';q:update();assert(callbacks==1 and #q.queue==0)
q:update();assert(callbacks==1)
print('PASS content scheduling: zero redundant planning while unsafe/busy, start once, finalize once')
