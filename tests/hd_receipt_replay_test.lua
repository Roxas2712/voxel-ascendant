local root=arg[1]or'.'
local Download=assert(loadfile(root..'/lib/HdContentDownload.lua'))()
local Journal=assert(loadfile(root..'/lib/HdReceiptJournal.lua'))()
local id='apo.pokemon-hd.g01.dex0001-0020'
local manifest,ticket=string.rep('a',64),string.rep('b',48)
local files,clock={},100000
local function hash(s)local h=7;for i=1,#s do h=(h*131+s:byte(i))%2147483647 end;return string.rep(('%08x'):format(h),8)end
local cache={info=function(_,k)return files[k]and{type='file',size=#files[k]}end,
  read=function(_,k)return files[k]end,write=function(_,k,v)files[k]=v;return true end}
Download.BASE='https://content.example.invalid'
local function journal()return Journal.new({origin=Download.BASE,cache=cache,sha256=hash,now=function()return clock end})end
local requests,cancelled,acknowledged,serverCount=0,0,{},0
local mode='pending'
local fetch={available=function()return true end,release=function()end,cancel=function()cancelled=cancelled+1 end}
function fetch:capabilities()return {boundedHttpsGet=1,maxResponseBytes=4194304}end
function fetch:get(url,opts)
  assert(opts.boundedHttpsGet==1 and opts.maxBytes==(url:find('/catalog.json',1,true)and 4194304 or 4096))
  requests=requests+1
  if mode=='get-error'then error('offline')end
  assert(url==Download.BASE..'/downloads/complete/'..ticket or url==Download.BASE..'/catalog.json')
  return {url=url}
end
function fetch:poll(job)
  if mode=='pending'then return {status='pending'}end
  if job.url:find('/catalog.json',1,true)then return {status='ok',body='catalog'}end
  if mode=='network-error'then return {status='error'}end
  if mode=='malformed'then return {status='ok',body='malformed'}end
  -- Server idempotency double: delivery can succeed while its response is lost.
  if not acknowledged[ticket]then acknowledged[ticket]=true;serverCount=serverCount+1 end
  if mode=='lost-response'then return {status='error'}end
  return {status='ok',body='ack'}
end
local function decode(body)
  if body=='ack'then return {ok=true}end
  if body=='catalog'then return {schema='apo.content-catalog/v1',packages={}}end
  return false
end
local function instance(installed,receipt)
  return Download.new({store={packages=installed or {}},catalog={packages={}},fetch=fetch,
    receipts=receipt or journal(),decode=decode})
end
assert(journal():put(id,manifest,ticket))
local partial=instance();for _=1,5 do partial:background()end;assert(requests==0,'partial data counted')
local wrong=instance({[id]={digest=string.rep('c',64)}});wrong:background();assert(requests==0,'different manifest counted')
local installed={[id]={digest=manifest,manifest={revision=1}}}
local restarted=instance(installed);restarted:background();assert(requests==1)
restarted:background();assert(requests==1 and restarted.status=='idle','metrics changed foreground state')
mode='lost-response';restarted:background()
assert(serverCount==1 and restarted.warnings.receipt_unconfirmed and #journal():list()==1)
for _=1,20 do restarted:background()end;assert(requests==1,'receipt retry flooded same process')
local retry=instance(installed);mode='ok';retry:background();retry:background()
assert(requests==2 and serverCount==1 and #journal():list()==0,'restart lost receipt or counted twice')
assert(journal():put(id,manifest,ticket));mode='pending'
local foreground=instance(installed);foreground:background();assert(foreground:check())
assert(cancelled==1,'foreground check did not preempt optional receipt')
mode='ok';foreground:update();assert(foreground.status=='idle')
assert(#journal():list()==1,'preempted receipt was lost')
local previous=requests
mode='get-error';local offline=instance(installed);offline:background()
assert(offline.status=='idle' and offline.warnings.receipt_unconfirmed)
for _=1,20 do offline:background()end;assert(requests==previous+1)
local foreign=journal();Download.BASE='https://other.example.invalid'
instance(installed,foreign):background();assert(requests==previous+1,'old-origin ticket leaked')
Download.BASE=foreign.origin;clock=clock+86401;instance(installed):background()
assert(requests==previous+1,'expired ticket sent')
print('PASS downloader restart receipts: verified digest only, lost response + idempotent replay, once/process, foreground preemption, offline/expiry/origin containment; transport/server are doubles')
