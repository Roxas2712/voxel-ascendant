-- Admission layer for the renderer's existing cooperative queue.
-- A generation token must include map/source/options identity at the call site.
local Preparation={}
function Preparation.new(queue,limit,dispose,weights)
 assert(queue and limit>=1 and limit%1==0 and type(dispose)=='function')
 local entries,epoch,enabled={},nil,false
 local readyWeight=0
 weights=weights or {budget=math.huge,weight=function()return 0 end}
 assert(weights.budget>0 and type(weights.weight)=='function')
 local metrics={ready=0,failed=0,pending=0,cancelled=0}
 local api={metrics=metrics}
 local function drop(key)
  local e=entries[key]
  if e then
   if e.value then dispose(e.value);readyWeight=readyWeight-(e.weight or 0)end
   entries[key]=nil;metrics.cancelled=metrics.cancelled+1
  end
 end
 local function count()
  metrics.readyWeight=readyWeight
  metrics.ready,metrics.failed,metrics.pending=0,0,0
  for _,e in pairs(entries)do
   local k=e.value and 'ready' or e.failed and 'failed' or 'pending'
   metrics[k]=metrics[k]+1
  end
 end
 function api:clear()
  queue.prune({})
  for key in pairs(entries)do drop(key)end
  enabled=false;epoch=nil;count()
 end
 function api:frame(token,allowed,demands)
  if not allowed then self:clear();return end
  if token~=epoch then self:clear();epoch=token end
  assert(token~=nil,'generation token required')
  enabled=true
  local wanted,order={},{}
  for _,d in ipairs(demands or {})do
   if #order>=limit then break end
   if d.key and type(d.factory)=='function' and not wanted[d.key]then
    wanted[d.key]=true;order[#order+1]=d.key
   end
  end
  -- Cancellation releases partially prepared resources before new work starts.
  queue.prune(wanted)
  for key in pairs(entries)do if not wanted[key]then drop(key)end end
  for _,d in ipairs(demands or {})do
   local key=d.key
   if wanted[key] and not entries[key]then
    local entry={};entries[key]=entry;local generation=epoch
    queue.push(key,d.factory,function(value)
     if enabled and epoch==generation and entries[key]==entry then
      if value then
       local ok,weight=pcall(weights.weight,value)
       if not ok or type(weight)~='number' or weight<0 or weight~=weight or weight==math.huge or readyWeight+weight>weights.budget then
        dispose(value);value=nil
       else entry.weight=weight;readyWeight=readyWeight+weight end
      end
      entry.value=value or nil;entry.failed=not value
     elseif value then dispose(value)end
    end)
   end
  end
  queue.pump(order);count()
 end
 function api:get(token,key)
  if not enabled or token~=epoch then return nil end
  local e=entries[key];return e and e.value or nil
 end
 return api
end
return Preparation
