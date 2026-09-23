-- Validate large geometry-cache bodies off the render thread when the
-- already-declared compute capability is available. At most two bounded
-- workers exist, including workers whose build coroutine was discarded.
local V=...
local B=V.require('BuildBudget')
local M={THRESHOLD=256*1024,MAX_BYTES=16*1024*1024}
local workers={}
local source,threadApi
local function available()
 if source==nil then
  local ok,value=pcall(function()
   local api=love.thread
   assert(api and api.newThread and api.newChannel)
   local text=V.mod:read('lib/GeometryDigestWorker.lua')
   assert(type(text)=='string' and #text>0)
   threadApi=api;return text
  end)
  source=ok and value or false
 end
 return source~=false
end
local function reap()
 local count=0
 for job in pairs(workers)do
  if job.thread:isRunning()then count=count+1
  else workers[job]=nil end
 end
 return count
end
local function compute(raw)
 while reap()>=2 do B.suspend()end
 local ok,job=pcall(function()
  local value={channel=threadApi.newChannel(),thread=threadApi.newThread(source)}
  value.thread:start(raw,value.channel)
  return value
 end)
 if not ok then return nil end
 workers[job]=true
 while true do
  local value=job.channel:pop()
  if value~=nil then
   reap()
   if type(value)=='string' and #value==64 and not value:find('[^0-9a-f]')then return value end
   return nil
  end
  if not job.thread:isRunning()then workers[job]=nil;return nil end
  B.suspend()
 end
end
function M.hex(d,raw)
 if #raw>=M.THRESHOLD and #raw<=M.MAX_BYTES and B.canYield
     and B.canYield() and available() then
  local ok,value=pcall(compute,raw)
  if ok and value then return value end
 end
 -- Small inputs, synchronous tools, older hosts and failed workers retain
 -- the exact native validation path. Never admit an unchecked cache entry.
 local bytes=d.hash('sha256',raw)
 if type(bytes)~='string' or #bytes~=32 then return nil end
 return (bytes:gsub('.',function(c)return ('%02x'):format(c:byte())end))
end
return M
