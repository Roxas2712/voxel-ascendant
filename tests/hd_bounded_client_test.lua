local Download=assert(loadfile('lib/HdContentDownload.lua'))()
Download.FALLBACK=nil -- Primary-only fault tests; failover has its own suite.
local calls,expected=0,'existing'
local fetch={available=function()return true end,get=function(_,url,opts)
  calls=calls+1
  assert(url==Download.BASE..'/catalog.json' and opts.maxSeconds==30)
  if expected=='bounded'then assert(opts.boundedHttpsGet==1 and opts.maxBytes==4194304)
  else assert(opts.boundedHttpsGet==nil and opts.maxBytes==nil,'new native API required on old engine')end
  return {}
end,release=function()end,cancel=function()end}
local function client()return Download.new({catalog={packages={}},store={},fetch=fetch})end
local c=client();assert(c:available() and c:check() and calls==1)
for _,caps in ipairs({{}, {boundedHttpsGet=0,maxResponseBytes=4194304},
    {boundedHttpsGet=1,maxResponseBytes=1024}, {boundedHttpsGet=true,maxResponseBytes=4194304}})do
  fetch.capabilities=function()return caps end
  c=client();assert(c:check() and c:transportMode()=='existing')
end
fetch.capabilities=function()error('old bridge')end
assert(client():check())
fetch.capabilities=function()return {boundedHttpsGet=1,maxResponseBytes=4194304}end
expected='bounded';c=client();assert(c:available() and c:check() and c:transportMode()=='bounded')
fetch.available=function()return false end
local before=calls;assert(not client():check() and calls==before)
-- Both paths still reject oversized results before decoding, caching or mounting.
fetch.available=function()return true end
fetch.capabilities=nil;expected='existing'
fetch.poll=function()return {status='ok',body=string.rep('x',4194305)}end
c=client();assert(c:check());c:update()
assert(c.status=='error' and c.message=='Response exceeds content limit')
print('PASS existing engine GET supported; bounded preferred; unavailable network and oversized response rejected')
