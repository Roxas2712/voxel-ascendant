local root=arg[1] or "."
local Download=assert(loadfile(root.."/lib/HdContentDownload.lua"))()
Download.FALLBACK=nil -- Primary-only fault tests; failover has its own suite.
local function driver(poll,store,decode)
  return Download.new({store=store or {packages={}},catalog={packages={}},
    decode=decode or function()return {schema="apo.content-catalog/v1",packages={}}end,
    fetch={available=function()return true end,get=function()return {}end,
      release=function()end,poll=poll}})
end
for _,bad in ipairs({false,42,"unexpected"})do
  Download.BASE="https://content.example.invalid"
  local d=driver(function()return bad end)
  assert(d:check())
  local ok=pcall(d.update,d)
  assert(ok and d.status=="error","malformed poll must fail without crashing the game")
end
do
  local d=driver(function()return nil end)
  assert(d:check());assert(pcall(d.update,d) and d.status=="error")
end
-- A restored cache entry must be checked against the catalog too, not only
-- entries already present in memory when the check starts.
local id="apo.pokemon-hd.g01.dex0001-0020"
local package={id=id,manifestSha256=string.rep("a",64),revision=1,
  manifestBytes=100,fileBytes=100,rosterGeneration=1}
local store={packages={}}
function store:restore(key)self.packages[key]={manifest={revision=2}}end
local d=driver(function()return {status="ok",body="catalog"}end,store,
  function()return {schema="apo.content-catalog/v1",packages={package}}end)
assert(d:check());d:update()
assert(d.status=="error" and d.message=="Catalog downgrade rejected","restored downgrade accepted")
assert(store.packages[id].manifest.revision==2)
for _,base in ipairs({false,{},"http://content.example.invalid","https://",
  "https://user:secret@content.example.invalid","https://content.example.invalid/path",
  "https://content.example.invalid?token=secret"})do
  Download.BASE=base
  local calls=0
  local blocked=Download.new({store={},catalog={packages={}},fetch={
    available=function()calls=calls+1;return true end,get=function()calls=calls+1 end}})
  assert(not blocked:configured() and not blocked:check() and not blocked:start(1,nil,true))
  assert(calls==0,"invalid configuration reached network")
end
Download.BASE="https://content.example.invalid"
-- A catalog persistence fault must not escape the UI update; the verified
-- in-memory catalog remains usable and the unavailable persistence is explicit.
for _,throws in ipairs({false,true})do
  local test=Download.new({store={packages={}},catalog={packages={}},
    decode=function()return {schema="apo.content-catalog/v1",packages={}}end,
    cache={write=function()if throws then error("disk error")end;return false end},
    fetch={available=function()return true end,get=function()return {}end,
      release=function()end,poll=function()return {status="ok",body="catalog"}end}})
  assert(test:check());assert(pcall(test.update,test))
  assert(test.status=="idle" and test.catalogChecks==1 and test.warnings.catalog_not_saved)
end

local function receiptCase(target,fault)
  local packages,manifests={},{}
  for n=1,2 do
    local raw="manifest-"..n
    local p={id=("apo.pokemon-hd.g01.dex%04d-%04d"):format(1+(n-1)*20,n*20),
      manifestSha256=string.rep(n==1 and "a" or "b",64),revision=1,
      manifestBytes=#raw,fileBytes=4,rosterGeneration=1}
    packages[n]=p
    manifests[raw]={id=p.id,revision=1,rosterGeneration=1,
      files={{chunks={{sha256=string.rep(n==1 and "c" or "d",64),bytes=4}}}}}
  end
  local activated,requested={},{}
  local fakeStore={packages={},inspect=function(_,raw)return manifests[raw]end,
    hasChunk=function()return false end,putChunk=function()return true end}
  function fakeStore:activate(raw)
    local m=assert(manifests[raw]);activated[m.id]=true
    self.packages[m.id]={manifest=m};return true
  end
  local transport={available=function()return true end,release=function()end}
  function transport:get(url)
    local kind,body
    if url:find("/manifests/",1,true)then
      kind="manifest";body=url:find(packages[1].manifestSha256,1,true) and "manifest-1" or "manifest-2"
    elseif url:find("/downloads/start/",1,true)then kind="start";body="start-ok"
    elseif url:find("/downloads/complete/",1,true)then kind="complete";body="complete-ok"
    else kind="chunk";body="1234"end
    requested[kind]=(requested[kind] or 0)+1
    if kind==target then
      if fault=="get-throws"then error("offline")end
      if fault=="get-nil"then return nil,"offline"end
      if fault=="missing-body"then body=false end
      if fault=="large-body"then body=string.rep("x",4*1024*1024+1)end
      if fault=="json-throws"then body="invalid-json"end
      if fault=="bad-schema"then body="bad-schema"end
    end
    return {kind=kind,status="ok",body=body}
  end
  function transport:poll(job)
    if job.kind==target then
      if fault=="poll-throws"then error("offline")end
      if fault=="poll-malformed"then return false end
    end
    return job
  end
  local test=Download.new({store=fakeStore,catalog={packages=packages},fetch=transport,
    decode=function(body)
      if body=="invalid-json"then error("invalid json")end
      if body=="start-ok"then return {ticket=string.rep("e",48)}end
      if body=="complete-ok"then return {ok=true}end
      return {}
    end})
  assert(test:start(1,nil,true))
  for _=1,100 do if not test:busy()then break end;assert(pcall(test.update,test))end
  if target=="chunk"then
    assert(test.status=="error" and not next(activated),"payload failure bypassed")
  else
    assert(test.status=="ready" and test.changed,"receipt failure broke download queue")
    assert(activated[packages[1].id] and activated[packages[2].id],"second package lost")
    assert(requested.chunk==2 and requested.manifest==2,"payload retried or skipped")
    assert(test.warnings.receipt_unconfirmed,"unconfirmed counting hidden")
    if target=="start"then assert(not requested.complete,"invalid ticket reported complete")end
  end
end
for _,target in ipairs({"start","complete"})do
  for _,fault in ipairs({"get-throws","get-nil","poll-throws","poll-malformed",
    "missing-body","large-body","json-throws","bad-schema"})do receiptCase(target,fault)end
end
receiptCase("chunk","get-throws");receiptCase("chunk","poll-malformed")
print("PASS HD transport: invalid origins blocked; malformed replies contained; restored downgrade rejected; catalog persistence warning; 16 receipt faults keep verified two-package queue; payload faults remain fatal")
