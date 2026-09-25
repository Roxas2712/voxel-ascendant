local root=arg[1] or '.'
local platform='Windows'
local payload='PK\003\004\r\n\026compressed\000bytes'
local modeSeen
local function host()
 local h={popen=function(_,mode)
  modeSeen=mode;local bytes=mode=='rb'and payload or 'PK\003\004\n';local offset=1
  return {read=function(_,format)
   if offset>#bytes then return nil end
   local count=format=='*a'and #bytes or assert(tonumber(format),'read format')
   local part=bytes:sub(offset,offset+count-1);offset=offset+#part;return part
  end}
 end,pclose=function()return true end}
 h.httpGet=function()local pipe=h.popen('curl','r');local body=pipe:read('*a');h.pclose(pipe);return body end
 return h
end
assert(host().httpGet()~=payload,'baseline Windows text pipe must corrupt fixture')
love={system={getOS=function()return platform end},filesystem={load=function()return host end},thread={}}
for _,n in ipairs({'love.system','love.filesystem','love.thread'})do package.loaded[n]=true end
local source=assert(io.open(root..'/lib/HdBinaryFetchWorker.lua')):read('*a')
local native={available=function()return true end}
local threads={}
function love.thread.newChannel()return {push=function(s,v)s[#s+1]=v end,pop=function(s)return table.remove(s,1)end}end
function love.thread.newThread(body)
 local t={running=true}
 function t:start(url,seconds,channel,maxBytes)self.run=function()assert(loadstring(body))(url,seconds,channel,maxBytes)end;self.seconds=seconds;self.maxBytes=maxBytes end
 function t:isRunning()return self.running end
 function t:getError()return self.err end
 function t:finish()self.run();self.running=false end
 threads[#threads+1]=t;return t
end
local mod={fetch=native,read=function()return source end}
local M=assert(loadfile(root..'/lib/HdBinaryFetch.lua'))()
local f=M.new(mod);assert(f~=native and f:available() and not f:capabilities().boundedHttpsGet)
local url='https://vasc-downloads.ascendant-content.workers.dev/catalog.json'
local j=assert(f:get(url,{maxSeconds=999}));assert(threads[1].seconds==30);assert(f:poll(j).status=='pending');threads[1]:finish()
assert(f:poll(j).body==payload and modeSeen=='rb','binary payload including CRLF, Ctrl-Z and NUL must survive')
f:release(j);assert(f:poll(j).status=='error')
for i=1,4 do assert(f:get(url))end
assert(not f:get(url),'outstanding workers remain bounded')
local t=threads[2];t:finish();local extra=assert(f:get(url));assert(f:cancel(extra));threads[#threads]:finish();assert(f:poll(extra).status=='cancelled')
f:close();assert(not f:available() and not f:get(url))
platform='OS X';assert(M.new(mod)==native,'other platforms retain native transport')
platform='Windows'
local c=love.thread.newChannel();assert(loadstring(source))('https://unapproved.example/catalog.json',30,c);assert(c:pop().status=='error')
local c2=love.thread.newChannel();assert(loadstring(source))(url..'?secret=x',30,c2);assert(c2:pop().status=='error')
local c3=love.thread.newChannel();assert(loadstring(source))(url,30,c3,8);local result;repeat local r=c3:pop();if not r then break end;result=r until false;assert(result.status=='error','per-request byte cap ignored')
print('PASS Windows streamed binary body and response cap; native-platform delegation; timeout; worker limit; cancellation; close; origin validation')
