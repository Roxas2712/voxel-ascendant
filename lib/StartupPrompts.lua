-- Release-owner decision only: increment one revision to show that screen
-- once again. Never derive these numbers from package or guide versions.
local M={REVISIONS={downloads=1,setup=1}}
function M.new(cache)
 local seen={};local attempted={}
 local function key(kind)
  assert(M.REVISIONS[kind], 'unknown startup screen')
  return 'sprite-content/startup-seen-'..kind..'-v1'
 end
 local function read(k)local ok,v=pcall(cache.read,cache,k);return ok and v or nil end
 local self={}
 function self:mark(kind)
  local revision=M.REVISIONS[kind];local path=key(kind)
  seen[kind]=math.max(tonumber(read(path)) or 0,revision)
  attempted[kind]=true -- a broken persistence backend must not loop in one run
  local value=tostring(seen[kind]);local ok,result=pcall(cache.write,cache,path,value)
  return ok and result==true and read(path)==value
 end
 function self:due(kind,legacySeen)
  local revision=M.REVISIONS[kind];local path=key(kind)
  if seen[kind]==nil then seen[kind]=tonumber(read(path)) or 0 end
  -- Preserve existing opt-outs and any saved guide (including a draft).
  -- A deliberately increased release revision may invite everyone once again.
  if seen[kind]==0 and revision==1 and legacySeen then self:mark(kind)end
  return not attempted[kind] and seen[kind]<revision
 end
 return self
end
return M
