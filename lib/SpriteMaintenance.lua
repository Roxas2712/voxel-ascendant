-- Shared downloaded-sprite maintenance. All removal is scoped to known cache
-- roots and happens before mounting. A checksummed two-slot journal survives
-- process termination while deleting, verifying or reinstalling.
local M={ROOTS={'sprite-content/installed','hd-content/active','sprite-content/pending','sprite-content/archive-pending',
 'sprite-content/manifests','hd-content/manifests','sprite-content/files','sprite-content/blobs','hd-content/blobs','sprite-content/archive-blobs'}}
local PREFIX='sprite-content/maintenance-v1.'
local function idOK(s)return type(s)=='string'and #s<=160 and s:match('^[a-z0-9][a-z0-9_.-]*$')end
function M.new(d)
 local self={state='idle',checked=0,broken={},missing={}}
 local function valid(j)
  if type(j)~='table'or j.schema~=1 or type(j.seq)~='number'or j.seq<1 or j.seq%1~=0 then return false end
  if j.mode~='repair'and j.mode~='reinstall'and j.mode~='delete'then return false end
  if j.phase~='purge'and j.phase~='verify'and j.phase~='download'and j.phase~='paused'and j.phase~='done'then return false end
  if type(j.ids)~='table'or #j.ids>10000 then return false end
  local seen={};for _,id in ipairs(j.ids)do if not idOK(id)or seen[id]then return false end;seen[id]=true end
  return true
 end
 local function readJournal()
  local best,bad
  for i=0,1 do
   local raw=d.cache:read(PREFIX..i)
   if raw then
    local ok,j=pcall(function()
     assert(type(raw)=='string'and #raw<4194304)
     local outer=d.decode(raw);assert(type(outer.body)=='string'and d.sha256(outer.body)==outer.sha256)
     local value=d.decode(outer.body);assert(valid(value));return value
    end)
    if ok and(not best or j.seq>best.seq)then best=j elseif not ok then bad=true end
   end
  end
  return best,bad
 end
 local function save(j)
  local copy={schema=1,seq=(self.job and self.job.seq or 0)+1,mode=j.mode,phase=j.phase,ids=j.ids}
  assert(valid(copy),'invalid maintenance job')
  local body=d.encode(copy);local raw=d.encode({body=body,sha256=d.sha256(body)});local key=PREFIX..(copy.seq%2)
  if d.cache:write(key,raw)~=true or d.cache:read(key)~=raw then return false,'maintenance_write_failed'end
  self.job=copy;return true
 end
 local job,bad=readJournal();self.job=job
 self.state=job and(job.phase=='purge'and'restart_required'or job.phase=='paused'and'paused'or job.phase~='done'and'checking')or'idle'
 if not job and bad then self.error='maintenance_journal_corrupt' end
 function self:pending()return self.job and self.job.phase~='done' and self.job or nil end
 function self:request(mode,ids,consent)
  if consent~=true then return false,'confirmation_required'end
  if d.busy and d.busy()then return false,'busy'end
  if self:pending()then return false,'maintenance_pending'end
  local candidate={mode=mode,ids=ids,phase=mode=='repair'and'verify'or'purge'}
  local ok,err=save(candidate);if not ok then return false,err end
  self.checked=0;self.broken={};self.missing={};self.step=nil;self.error=nil;self.started=false
  self.state=candidate.phase=='purge'and'restart_required'or'checking'
  return true,candidate.phase=='purge'and'restart_required'or'checking'
 end
 local function remove(key)
  local info=d.cache:info(key)
  if not info then return true end
  if d.cache:remove(key)~=true or d.cache:info(key)~=nil then return false end
  return true
 end
 function self:beforeMount()
  if not d.safeBeforeMount()then return false,'not_safe_before_mount'end
  local j=self:pending();if not j or j.phase~='purge'then return true end
  for _,root in ipairs(M.ROOTS)do
   local ok,names=pcall(d.list,root)
   if not ok or type(names)~='table'then return false,'maintenance_inventory_failed'end
   for _,name in ipairs(names)do
    -- Cache formats are flat; no recursion, traversal, source ROMs or saves.
    if type(name)~='string'or not name:match('^[%w_.-]+$')or name:find('..',1,true)then return false,'maintenance_invalid_cache_entry'end
    if not remove(root..'/'..name)then return false,'maintenance_delete_failed'end
   end
  end
  local ok,err=save({mode=j.mode,ids=j.ids,phase=j.mode=='delete'and'done'or'verify'})
  if ok then self.state=j.mode=='delete'and'idle'or'checking' end
  return ok,err
 end
 function self:pause()
  local j=self:pending();if not j or j.phase=='purge'then return false end
  if d.cancel then d.cancel()end
  local ok,err=save({mode=j.mode,ids=j.ids,phase='paused'})
  if ok then self.state='paused';self.step=nil;self.started=false end
  return ok,err
 end
 function self:resume()
  local j=self:pending();if not j or j.phase=='purge'then return false,'restart_required'end
  local ok,err=save({mode=j.mode,ids=j.ids,phase='verify'})
  if ok then self.checked=0;self.broken={};self.missing={};self.step=nil;self.started=false;self.error=nil;self.state='checking'end
  return ok,err
 end
 local function fail(err)self.state='error';self.error=tostring(err);return false,err end
 function self:update()
  local j=self:pending()
  if not j or j.phase=='purge'or j.phase=='paused'or self.state=='error'then return end
  if j.phase=='download' and not self.started then
   -- A fresh process must recheck before skipping an existing receipt.
   return self:resume()
  end
  if j.phase=='verify'then
   self.state='checking';local id=j.ids[self.checked+1]
   if not id then
    if #self.broken==0 then
     local ok,err=save({mode=j.mode,ids=j.ids,phase='done'})
     if not ok then return fail(err)end
     self.state='ready';self.result='healthy';return
    end
    local ok,err=save({mode=j.mode,ids=j.ids,phase='download'})
    if not ok then return fail(err)end
    self.started=true;self.state='downloading'
    local started,why=d.startDownload(self.broken)
    if not started then return fail(why)end
    return
   end
   if not self.step then
    local ok,step=pcall(d.check,id)
    if not ok then return fail(step)end
    self.step=step
   end
   local ok,result=pcall(self.step)
   if not ok then return fail(result)end
   if result~=nil then
    if not result then self.broken[#self.broken+1]=id;self.missing[id]=true else self.missing[id]=nil end
    self.checked=self.checked+1;self.step=nil
   end
  elseif j.phase=='download'then
   local state,err=d.downloadState()
   if state=='error'then return fail(err)end
   if state=='cancelled'then return self:pause()end
   if state=='ready'then
    local ok,why=save({mode=j.mode,ids=j.ids,phase='done'});if not ok then return fail(why)end
    self.missing={};self.state='ready';self.result='repaired'
   end
  end
 end
 return self
end
return M
