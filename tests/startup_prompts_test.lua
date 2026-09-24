local root=arg[1] or '.'
local M=assert(loadfile(root..'/lib/StartupPrompts.lua'))()
local data={};local cache={read=function(_,k)return data[k]end,write=function(_,k,v)data[k]=v;return true end}
local p=M.new(cache)
assert(p:due('downloads') and p:due('setup'))
assert(p:mark('downloads'));assert(not p:due('downloads') and p:due('setup'))
p=M.new(cache);assert(not p:due('downloads'),'restart repeats download introduction')
assert(p:mark('setup'));p=M.new(cache);assert(not p:due('setup'),'restart repeats guide')
M.REVISIONS.downloads=2;p=M.new(cache)
assert(p:due('downloads') and not p:due('setup'),'independent update invitation')
p:mark('downloads');p=M.new(cache);assert(not p:due('downloads'))
M.REVISIONS.setup=2;p=M.new(cache);assert(p:due('setup') and not p:due('downloads'));p:mark('setup')
M.REVISIONS.downloads=1;M.REVISIONS.setup=1;p=M.new(cache);assert(not p:due('downloads') and not p:due('setup'),'downgrade must not reissue')
data={};p=M.new(cache);assert(not p:due('setup',true),'legacy draft counts as shown');assert(not p:due('downloads',true),'legacy opt-out preserved')
M.REVISIONS.setup=2;M.REVISIONS.downloads=2;p=M.new(cache);assert(p:due('setup',true) and p:due('downloads',true),'maintainer can reinvite everyone')
local failing={read=function()return nil end,write=function()error('read-only backend')end}
p=M.new(failing);assert(p:due('downloads'));assert(not p:mark('downloads'));assert(not p:due('downloads'),'write failure loops in same process')
print('PASS startup prompts: persistent once, independent release revisions, migration, downgrade and write failure')

-- New KASC can attach over a legacy VASC session without restoring per-start prompts.
local mod={read=function(_,path)local f=assert(io.open(root..'/'..path));local s=f:read('*a');f:close();return s end}
local session={cache=cache,mod=mod,offerStable=1,promptDisabled=false,onboardingShown=false,update=function()end,offer=function()return {}end}
local shim=assert(loadfile(root..'/lib/SpriteStartupOffer.lua'))();shim.attach(session,mod)
assert(session.startupPrompts and session.__kascStartupOfferV2)
local screen=session:offer();assert(screen and session.onboardingShown and session.promptDisabled)
print('PASS mixed-version startup shim retains persistent policy')
