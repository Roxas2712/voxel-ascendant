local D=assert(loadfile('lib/HdContentDownload.lua'))()
assert(D.FALLBACK=='https://vasc-content.maarten-paus.chatgpt.site','verified fallback must be configured')
D.BASE='https://primary.example.invalid'
D.FALLBACK='https://mirror.example.invalid'
local hash=string.rep('a',64)
local p={id='apo.pokemon-hd.g01.dex0001-0020',manifestSha256=hash,revision=1,manifestBytes=8,fileBytes=4,rosterGeneration=1}
local catalog={schema='apo.content-catalog/v1',packages={p}}
local function scenario(fault,target,badMirror)
  local calls,released,activated={},0,0
  local store={packages={},restore=function()end,hasChunk=function()return false end}
  function store:inspect(raw)if raw~='manifest'then return nil end;return {id=p.id,revision=1,rosterGeneration=1,files={{chunks={{sha256=hash,bytes=4}}}}}end
  function store:putChunk(_,body)
    if fault=='disk' then return nil,'cache_write_failed' end
    if body~='data'then return nil,'chunk_verification_failed'end
    return true
  end
  function store:activate()activated=activated+1;return true end
  local f={available=function()return true end,cancel=function()end,release=function()released=released+1 end}
  function f:get(url,opts)
    calls[#calls+1]=url
    assert(opts.maxSeconds==30)
    local mirror=url:sub(1,#D.FALLBACK)==D.FALLBACK
    assert(not (mirror and url:find('/downloads/',1,true)),'receipt leaked to mirror')
    local kind=url:find('/catalog.json',1,true) and 'catalog' or url:find('/manifests/',1,true) and 'manifest' or url:find('/blobs/',1,true) and 'chunk' or 'receipt'
    local body=({catalog='catalog',manifest='manifest',chunk='data',receipt='receipt'})[kind]
    if (not mirror and kind==target) or (mirror and badMirror)then
      if fault=='throw'then error('DNS failure')end
      if fault=='nil'then return nil,'TLS failure'end
      if fault=='body'then body='invalid-body'end
      if fault=='hash'then body='xxxx'end
      if fault=='poll'then return {status='error',err='timeout'}end
    end
    return {status='ok',body=body}
  end
  function f:poll(job)return job end
  local d=D.new({catalog=catalog,store=store,fetch=f,decode=function(body)
    if body=='catalog'then return catalog end
    if body=='receipt'then return {ticket=string.rep('b',48),ok=true}end
    return {}
  end})
  assert(d:check())
  for _=1,10 do if not d:busy()then break end;d:update()end
  if d.status=='error'then return d,calls,activated end
  d:start(1,nil,true)
  for _=1,30 do if not d:busy()then break end;d:update()end
  return d,calls,activated
end
for _,target in ipairs({'catalog','manifest','chunk'})do
  for _,fault in ipairs({'throw','nil','poll','body'})do
    local d,calls,n=scenario(fault,target)
    assert(d.status=='ready' and n==1 and d.usingFallback,target..'/'..fault..': '..d.message)
    assert(#calls<=6,'retry loop')
  end
end
local d,calls,n=scenario('hash','chunk')
assert(d.status=='ready' and n==1 and d.usingFallback)
d,calls,n=scenario('disk','chunk')
assert(d.status=='error' and n==0 and not d.usingFallback,'disk fault caused mirror retry')
d,calls,n=scenario('poll','catalog',true)
assert(d.status=='error' and #calls==2 and n==0,'both sources failed without stopping')
d,calls,n=scenario('hash','chunk',true)
assert(d.status=='error' and n==0,'corrupt mirror activated')
d,calls,n=scenario('poll','receipt')
assert(d.status=='ready' and n==1 and not d.usingFallback,'metrics outage switched payload source')
-- Cancellation must not retry the mirror from a late response.
local count=0
local c=D.new({store={},catalog=catalog,fetch={available=function()return true end,
  get=function()count=count+1;return {}end,poll=function()return {status='error'}end,
  release=function()end,cancel=function()end}})
assert(c:check());c:cancel();c:update();assert(count==1 and c.status=='cancelled')
for _,origin in ipairs({'http://mirror.invalid','https://user:secret@mirror.invalid','https://mirror.invalid/share','https://mirror.invalid?token=x',D.BASE})do
  D.FALLBACK=origin
  local c=D.new({store={},catalog=catalog,fetch={available=function()return true end,get=function()return nil end}})
  assert(not c:check() and not c.usingFallback)
end
print('PASS failover: catalog/manifest/chunk GET, DNS/TLS/timeout/invalid body, hash recovery, corrupt mirror rejection, disk errors, receipt isolation, cancellation, bounded retries and invalid origins')
