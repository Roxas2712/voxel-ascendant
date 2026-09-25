-- Persistence failures must remain retryable, including after process restart.
local Journal=dofile('lib/HdReceiptJournal.lua')
local disk,fail={},false
local cache={read=function(_,p)return disk[p]end,info=function(_,p)return disk[p]and{type='file',size=#disk[p]}end,
 write=function(_,p,v)if fail then return false end;disk[p]=v;return true end}
local deps={cache=cache,sha256=function()return string.rep('a',64)end,now=function()return 1000 end,origin='https://example.invalid'}
local id,digest,ticket='apo.pokemon-hd.g01.dex0001-0151',string.rep('b',64),string.rep('c',48)
local j=Journal.new(deps);assert(j:put(id,digest,ticket,100))
fail=true;assert(not j:remove(id,ticket));assert(#j:list()==1,'failed remove lost its retry state')
fail=false;assert(j:remove(id,ticket));assert(#Journal.new(deps):list()==0,'retry did not persist removal')
fail=true;assert(not j:put(id,digest,ticket,100));assert(#j:list()==0,'failed insert escaped into live state')
fail=false;assert(j:put(id,digest,ticket,100));fail=true
assert(not j:put(id,digest,string.rep('d',48),100));assert(j:list()[1].ticket==ticket,'failed replacement lost old ticket')
fail=false;assert(not j:remove(id,string.rep('d',48)));assert(j:remove(id,ticket))
print('PASS journal failed insert/replace/remove rollback, retry, restart and ticket ownership')
