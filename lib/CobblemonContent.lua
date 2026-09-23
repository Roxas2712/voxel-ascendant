-- Pinned official graphics ship with the base pack. Older/extended catalogs
-- can still fetch missing data files. No downloaded scripts are executed.
local V=...;local M={};local J=assert((loadstring or load)(assert(V.mod:read('lib/ContentJson.lua'))))();local Encode=V.require('CobblemonJson').encode
local C=J.decode(assert(V.mod:read('assets/cobblemon-catalog.json')))
local cache=assert(V.mod.cache);local Fetch=assert((loadstring or load)(assert(V.mod:read('lib/HdBinaryFetch.lua'))))().new(V.mod)
local Import=V.require('CobblemonImport')
local ROOT='cobblemon/v1/'..C.commit..'/'
local function sha(s)return love.data.encode('string','hex',love.data.hash('sha256',s))end
local byPath={};for _,f in ipairs(C.files)do
 assert(f.path:match('^assets/cobblemon/') and not f.path:find('..',1,true) and f.bytes>0 and f.bytes<=4194304,'invalid shipped catalog')
 byPath[f.path]=f
end
local function read(path)
 local f=byPath[path];if not f then return nil end
 if f.bundled then return V.mod:read(f.bundled)end
 return cache:read(ROOT..'blobs/'..f.sha256)
end
local catalogHash=sha(V.mod:read('assets/cobblemon-catalog.json'))
local installed={};local complete=false;local candidate;local receiptRaw=cache:read(ROOT..'installed.json')
if receiptRaw then local ok,r=pcall(J.decode,receiptRaw);if ok and r.schema==1 and r.commit==C.commit and type(r.species)=='table'then installed=r.species;complete=r.complete==true and r.catalogHash==catalogHash end end
local state={phase='idle',done=0,total=0,bytes=0,totalBytes=0,message='',failures={}}
local jobs={};local queue,position,compileList,compileIndex,variantIndex,working={},1,nil,1,1,nil
local function now()return love.timer and love.timer.getTime() or 0 end
local samples={}
local function progress()
 local received=state.downloadedBytes or 0
 for _,f in pairs(jobs)do received=received+(f.received or 0)end
 received=math.max(received,state.receivedBytes or 0)
 state.receivedBytes=received
 local t=now();state.elapsed=math.max(0,t-(state.startedAt or t))
 if #samples==0 or t-samples[#samples].time>=0.25 then
  samples[#samples+1]={time=t,bytes=received}
 end
 while #samples>2 and samples[2].time<t-5 do table.remove(samples,1)end
 local first=samples[1];local dt=first and t-first.time or 0
 state.bytesPerSecond=state.phase=='download' and dt>=0.25 and math.max(0,(received-first.bytes)/dt) or 0
 state.stage=state.phase=='download' and (next(jobs) and 'download' or 'verify') or state.phase
end
local baseVariants={{key='normal',aspects={}},{key='female',aspects={female=true}},{key='shiny',aspects={shiny=true}},{key='female_shiny',aspects={female=true,shiny=true}}}
function M.status()return state end
function M.complete()return complete end
function M.available(dex,variant)
 if dex==nil then return next(installed)~=nil end
 local r=installed[tostring(dex)];return type(r)=='table' and type(r[variant or 'normal'])=='string'
end
function M.read(path)return read(path)end
function M.record(dex,variant)
 local r=installed[tostring(dex)];local h=r and r[variant or 'normal'];if not h then return nil end
 local raw=cache:read(ROOT..'models/'..h..'.json');if not raw or sha(raw)~=h then return nil end
 local ok,m=pcall(J.decode,raw);return ok and m or nil
end
function M.busy()return state.phase=='download' or state.phase=='prepare'end
local function stop(phase,message)
 for job in pairs(jobs)do pcall(Fetch.cancel,Fetch,job);pcall(Fetch.release,Fetch,job)end
 jobs={};state.phase=phase;state.message=message;progress()
end
function M.cancel()stop('cancelled','Download stopped. Verified files are retained.')end
function M.start(generation)
 if M.busy()then return false,'busy'end
 candidate={};for k,v in pairs(installed)do candidate[k]=v end
 queue={};position=1;compileList={};compileIndex=1;variantIndex=1;working=nil
 state={phase='download',stage='verify',done=0,total=0,bytes=0,totalBytes=0,downloadedBytes=0,receivedBytes=0,bytesPerSecond=0,localBytes=0,startedAt=now(),elapsed=0,message='Cobblemon '..C.version,failures={}}
 samples={{time=state.startedAt,bytes=0}}
 for _,f in ipairs(C.files)do if f.dex==0 or generation==nil or generation==1 and f.dex<=151 or generation==2 and f.dex>151 then
  queue[#queue+1]=f;state.totalBytes=state.totalBytes+f.bytes
 end end
 for d in pairs(C.species)do local n=tonumber(d);if generation==nil or generation==1 and n<=151 or generation==2 and n>151 then compileList[#compileList+1]=n end end
 table.sort(compileList);state.total=#queue;return true
end
function M.size(generation)local n=0;for _,f in ipairs(C.files)do if not generation or generation==1 and f.dex<=151 or generation==2 and f.dex>151 then n=n+f.bytes end end;return n end
function M.update()
 if state.phase=='download'then
  for job,f in pairs(jobs)do
   local ok,r=pcall(Fetch.poll,Fetch,job)
   if not ok then stop('error','Network polling failed');return end
   f.received=math.min(f.bytes,math.max(f.received or 0,tonumber(r.receivedBytes) or 0))
   if r.status~='pending'then
    Fetch:release(job);jobs[job]=nil
    if r.status~='ok' or type(r.body)~='string' or #r.body~=f.bytes or sha(r.body)~=f.sha256 then stop('error','Download verification failed: '..f.path);return end
    if cache:write(ROOT..'blobs/'..f.sha256,r.body)~=true then stop('error','Cannot save graphics');return end
    state.done=state.done+1;state.bytes=state.bytes+f.bytes
    state.downloadedBytes=state.downloadedBytes+f.bytes
   end
  end
  local count=0;for _ in pairs(jobs)do count=count+1 end
  -- Verify local data without thousands of frame-sized waits, while keeping
  -- a four-millisecond budget and at most four live network requests.
  local deadline=now()+0.004
  for _=1,32 do
   if count>=4 or now()>deadline then break end
   local f=queue[position];if not f then break end
   position=position+1
   local raw=read(f.path)
   if raw and #raw==f.bytes and sha(raw)==f.sha256 then state.done=state.done+1;state.bytes=state.bytes+f.bytes;state.localBytes=state.localBytes+f.bytes
   elseif f.bundled then stop('error','Bundled graphics verification failed: '..f.path);return
   else
    if not Fetch or not Fetch.available or not Fetch:available()then stop('error','Network unavailable. Verified files are retained.');return end
    local options={maxBytes=f.bytes,maxSeconds=30}
    local caps=Fetch.capabilities and Fetch:capabilities();if caps and caps.boundedHttpsGet==1 then options.boundedHttpsGet=1 end
    local url='https://gitlab.com/cable-mc/cobblemon/-/raw/'..C.commit..'/common/src/main/resources/'..f.path
    local job,err=Fetch:get(url,options)
    if not job then stop('error',tostring(err or 'Download unavailable'));return end
    jobs[job]={path=f.path,bytes=f.bytes,sha256=f.sha256,received=0};count=count+1
   end
  end
  state.message=string.format('Cobblemon: %d / %d',state.done,state.total)
  if position>#queue and next(jobs)==nil then state.phase='prepare';state.prepared=0;state.prepareTotal=#compileList end
  progress()
 elseif state.phase=='prepare'then
  local dex=compileList[compileIndex]
  if not dex then
   local raw=Encode{schema=1,commit=C.commit,species=candidate,catalogHash=catalogHash,complete=#compileList==C.speciesCount}
   if cache:write(ROOT..'installed.json',raw)~=true then stop('error','Cannot activate graphics');return end
   installed=candidate;complete=#compileList==C.speciesCount
   local supported=0;for _,entry in pairs(installed)do if entry.normal then supported=supported+1 end end
   state.supported=supported;state.phase='ready';state.message=string.format('Cobblemon: %d species ready. Missing models use existing sprites.',supported);M.epoch=(M.epoch or 0)+1;progress();return
  end
  working=working or {}
  local variants=C.variants and C.variants[tostring(dex)] or baseVariants
  local variant=variants[variantIndex]
  local ok,model=pcall(function()return Encode(Import.compile(C,dex,variant.aspects,read,J.decode))end)
  if ok then
   local raw=model;local h=sha(raw)
   if cache:write(ROOT..'models/'..h..'.json',raw)~=true then stop('error','Cannot save prepared model');return end
   working[variant.key]=h
  else state.failures[#state.failures+1]={dex=dex,variant=variant.key,error=tostring(model)}end
  state.message=string.format('Preparing %d / %d: #%d',compileIndex,#compileList,dex)
  state.prepared=compileIndex-1;state.prepareTotal=#compileList
  variantIndex=variantIndex+1
  if variantIndex>#variants then
   if working.normal then candidate[tostring(dex)]=working end
   compileIndex=compileIndex+1;variantIndex=1;working=nil
  end
  progress()
 end
end
M.version=C.version;M.source=C.source;M.catalog=C
return M
