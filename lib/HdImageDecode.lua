-- One bounded PNG decoder, shared by all HD card queues. The worker owns
-- only immutable bytes/ImageData; GPU objects and game state stay here.
local V=...
local M={}
local active,source,api,unavailableReason
local counts={started=0,completed=0,cancelled=0,failed=0}
local function release(value)
 if type(value)=='userdata' and value.release then pcall(value.release,value) end
end
local function available()
 if source==nil then
  local ok,value=pcall(function()
   api=assert(love.thread)
   assert(api.newThread and api.newChannel)
   local channel=api.newChannel();assert(channel.performAtomic)
   return assert(V.mod:read('lib/HdImageDecodeWorker.lua'))
  end)
  source=ok and value or false
  if not ok then unavailableReason=tostring(value) end
 end
 return source~=false
end
function M.pump()
 if active and (active.cancelled or active.delivered) and not active.thread:isRunning() then
  active=nil
 end
end
local function u32(raw,offset)
 local a,b,c,d=raw:byte(offset,offset+3)
 return ((a*256+b)*256+c)*256+d
end
-- nil means capacity is busy; false asks the caller to use its native path.
function M.start(path,maxBytes,width,height,readVerified)
 M.pump()
 if not available() then return false end
 if active then return nil end
 local ok,job=pcall(function()
  local raw=readVerified and readVerified(path)
  if raw==nil then
   local info=assert(love.filesystem.getInfo(path))
   assert(info.size and info.size<=16*1024*1024)
   raw=assert(love.filesystem.read(path))
  end
  assert(type(raw)=='string' and #raw<=16*1024*1024)
  assert(#raw>=33 and raw:sub(1,8)=='\137PNG\13\10\26\10'
    and raw:sub(13,16)=='IHDR')
  -- The admitted sheets are 8-bit PNGs; wider formats keep the native path
  -- rather than exceeding the four-bytes-per-pixel reservation.
  assert(raw:byte(25)==8)
  local w,h=u32(raw,17),u32(raw,21)
  assert(w>0 and h>0 and w*h*4<=math.min(maxBytes or 0,96*1024*1024))
  assert(not width or width==w);assert(not height or height==h)
  local value={thread=api.newThread(source),channel=api.newChannel(),bytes=w*h*4}
  value.channel:push('pending')
  value.thread:start(raw,value.channel,w,h)
  return value
 end)
 if not ok then counts.failed=counts.failed+1;return false end
 active=job;counts.started=counts.started+1
 return job
end
function M.poll(job)
 if not job or job.cancelled or job.delivered then return false end
 local result=job.channel:performAtomic(function(channel)
  local value=channel:peek()
  if value=='pending' then return nil end
  return channel:pop()
 end)
 if result==nil then
  if job.thread:isRunning() then return nil end
  -- A worker failure must not strand a queue on "pending" forever.
  -- Completion can race the first peek; consume its final result again.
  result=job.channel:pop()
 end
 job.delivered=true
 if type(result)=='userdata' then counts.completed=counts.completed+1
 else counts.failed=counts.failed+1;result=false end
 M.pump()
 return result
end
function M.cancel(job)
 if not job or job.cancelled or job.delivered then return end
 job.cancelled=true;counts.cancelled=counts.cancelled+1
 -- Atomic with worker completion: whichever side owns ImageData releases
 -- it, even if the map disappears and this queue is never pumped again.
 job.channel:performAtomic(function(channel)
  release(channel:pop());channel:push('cancelled')
 end)
 M.pump()
end
function M.stats()
 M.pump()
 return {started=counts.started,completed=counts.completed,cancelled=counts.cancelled,
  failed=counts.failed,active=active and 1 or 0,bytes=active and active.bytes or 0,
  unavailableReason=unavailableReason}
end
return M
