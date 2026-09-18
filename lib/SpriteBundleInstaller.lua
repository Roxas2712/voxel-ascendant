-- Download bounded slices of a complete data package, then reuse the exact
-- same verified importer as a local file. This avoids one HTTP request per PNG.
local M={ROOT='sprite-content/archive-blobs/'}
function M.new(d)
 local self={state='idle',doneBytes=0}
 local function log(name,fields)if d.diagnostics then d.diagnostics:event(name,fields or {})end end
 local function finish(outcome,code)if d.diagnostics then d.diagnostics:finish(outcome,{code=code,doneBytes=self.doneBytes})end end
 local function fail(code)self.state='error';self.finishedAt=d.now();self.error=code;if self.importer then self.importer:cancel()end;finish('error',code);return false,code end
 local function cached(c)
  local info=d.cache:info(M.ROOT..c.sha256)
  -- Portable engine caches may report only the file type. Validate the
  -- actual bytes below; a supplied, contradictory size still rejects it.
  if not info or (info.size~=nil and info.size~=c.bytes) then return end
  local raw=d.cache:read(M.ROOT..c.sha256)
  if type(raw)=='string'and #raw==c.bytes and d.sha256(raw)==c.sha256 then return raw end
 end
 local function reader(meta)
  local r={index=1,offset=1}
  function r:read(n)
   local parts={};local remaining=n
   while remaining>0 do
    local c=meta.chunks[self.index];if not c then break end
    if not self.raw then self.raw=cached(c);if not self.raw then error('missing_archive_chunk')end end
    local count=math.min(remaining,#self.raw-self.offset+1)
    parts[#parts+1]=self.raw:sub(self.offset,self.offset+count-1);self.offset=self.offset+count;remaining=remaining-count
    if self.offset>#self.raw then self.index=self.index+1;self.offset=1;self.raw=nil end
   end
   return table.concat(parts)
  end
  function r:close()self.raw=nil end
  return r
 end
 function self:start(plan,consent)
  if consent~=true then return false,'confirmation_required'end
  if self.state=='downloading'then return false,'busy'end
  if d.diagnostics then d.diagnostics:begin()end
  self.queue={};self.index=1;self.current=nil;self.pending=nil;self.importer=nil;self.doneBytes=0;self.error=nil;self.totalBytes=0;self.networkBytes=0;self.startedAt=d.now();self.finishedAt=nil
  for _,id in ipairs(plan.missing)do
   local p=d.catalog.packages[id];local meta=d.bundles[id]
   if not p or not p.published or not meta then return fail('package_not_published')end
   if type(meta.sha256)~='string' or #meta.sha256~=64 or meta.sha256:find('[^a-f0-9]')then return fail('invalid_manifest')end
   local total=0
   for _,c in ipairs(meta.chunks)do
    if type(c.bytes)~='number'or c.bytes<1 or c.bytes>4194304 or c.bytes%1~=0 or type(c.sha256)~='string'or #c.sha256~=64 or c.sha256:find('[^a-f0-9]')then return fail('invalid_manifest')end
    total=total+c.bytes
   end
   if total~=meta.bytes or total>1073741824 then return fail('invalid_size')end
   self.totalBytes=self.totalBytes+total;self.queue[#self.queue+1]=p
  end
  self.state='downloading';return true
 end
 function self:update()
  if self.state~='downloading'then return end
  if self.importer then
   local began=d.now()
   for i=1,16 do
    self.importer:update()
    if not self.importer:busy()or d.now()-began>.004 then break end
   end
   if self.importer.state=='error'then return fail(self.importer.error)end
   if self.importer.state~='ready'then return end
   log('package_verified',{packageId=self.current.id,doneBytes=self.doneBytes})
   -- Verified file chunks now own the data. The transport staging is disposable.
   for _,c in ipairs(self.meta.chunks)do d.cache:remove(M.ROOT..c.sha256)end
   d.cache:remove('sprite-content/archive-pending/'..self.current.id)
   self.importer=nil;self.current=nil;self.index=self.index+1;return
  end
  if self.pending then
   d.fetch:update()
   if d.fetch.state=='error'then return fail(d.fetch.error)end
   if d.fetch.state~='ready'then return end
   local c=self.meta.chunks[self.chunkIndex];local raw=d.fetch.body;d.fetch.body=nil
   if d.cache:write(M.ROOT..c.sha256,raw)~=true or not cached(c)then return fail('cache_write_failed')end
   log('chunk_stored',{packageId=self.current.id,bytes=c.bytes});self.doneBytes=self.doneBytes+c.bytes;self.networkBytes=self.networkBytes+c.bytes
   self.chunkIndex=self.chunkIndex+1;self.pending=nil;return
  end
  if not self.current then
   self.current=self.queue[self.index]
   if not self.current then self.state='ready';self.finishedAt=d.now();finish('success');return end
   self.meta=d.bundles[self.current.id];self.chunkIndex=1
   local key='sprite-content/archive-pending/'..self.current.id
   if d.cache:write(key,self.current.manifestSha256)~=true or d.cache:read(key)~=self.current.manifestSha256 then return fail('cache_write_failed')end
   log('package_started',{packageId=self.current.id,bytes=self.meta.bytes})
  end
  local c=self.meta.chunks[self.chunkIndex]
  if c then
   if cached(c)then self.doneBytes=self.doneBytes+c.bytes;log('chunk_cached',{packageId=self.current.id,bytes=c.bytes});self.chunkIndex=self.chunkIndex+1;return end
   local ok,err=d.fetch:start('/package-versions/'..self.meta.sha256..'/chunks/'..(self.chunkIndex-1),c.bytes,c.sha256)
   if not ok then return fail(err)end
   self.pending=true;return
  end
  self.importer=d.Importer.new{store=d.store}
  local ok,err=self.importer:start(reader(self.meta),self.meta.bytes,self.current,true)
  if not ok then return fail(err)end
 end
 function self:progress()
  local elapsed=math.max(.001,(self.finishedAt or d.now())-(self.startedAt or d.now()))
  local received=self.pending and d.fetch.state=='fetching' and (d.fetch.receivedBytes or 0) or 0
  local count=#(self.queue or {})
  return {state=self.state,stage=self.importer and 'installing' or self.pending and (d.fetch.state=='waiting' and (d.fetch.attempt>0 and 'retrying' or 'connecting') or 'downloading') or 'checking',
   totalBytes=self.totalBytes or 0,doneBytes=math.min(self.totalBytes or 0,self.doneBytes+received),
   speed=((self.networkBytes or 0)+received)/elapsed,elapsed=elapsed,
   completed=self.state=='ready' and count or math.max(0,(self.index or 1)-1),total=count,
   current=self.current,attempt=d.fetch.attempt or 0,server=d.fetch.mirror and d.fetch.mirror.provider,
   retrySeconds=math.max(0,math.ceil((d.fetch.retryAt or 0)-d.now())),error=self.error}
 end
 function self:cancel()
  d.fetch:cancel();if self.importer then self.importer:cancel()end
  self.state='cancelled';self.finishedAt=d.now();self.pending=nil;finish('cancelled')
 end
 return self
end
return M
