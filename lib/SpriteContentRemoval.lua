-- Durable deletion at the next safe boot, before any sprite store/renderer mounts.
-- inventory() must include ALL cached versions and imported packages, not just catalog entries.
-- It returns {complete=true, packages={id,activationKeys={},payloadKeys={}}}.
local M={KEY="sprite-content/removal-pending-v1.json"}
local function validId(s)return type(s)=="string" and #s<=160 and s:match("^[a-z0-9][a-z0-9_.-]*$")end
function M.new(d)
  assert(d.cache and d.inventory and d.encode and d.decode,"missing removal adapter")
  local roots=d.ownedRoots or {"sprite-content/installed/","sprite-content/manifests/","sprite-content/blobs/","sprite-content/files/","hd-content/active/","hd-content/manifests/","hd-content/blobs/"}
  local self={}
  local function keyOK(k)
    if type(k)~="string" or #k>512 or k:find("..",1,true) or k:find("//",1,true) or k:sub(1,1)=="/" then return false end
    for _,root in ipairs(roots) do
      -- Only cache roots; never the user's source ROM or arbitrary save files.
      if root~="" and root:sub(-1)=="/" and k:sub(1,#root)==root and #k>#root then return true end
    end
    return false
  end
  local function validate(row)
    if type(row)~="table" or not validId(row.id) or type(row.activationKeys)~="table" or type(row.payloadKeys)~="table" then return false end
    for _,list in ipairs({row.activationKeys,row.payloadKeys}) do
      for _,key in ipairs(list) do if not keyOK(key) then return false end end
    end
    return #row.activationKeys>0
  end
  local function inventory()
    local ok,s=pcall(d.inventory)
    if not ok or type(s)~="table" or s.complete~=true or type(s.packages)~="table" then return nil end
    local seen={}
    for _,p in ipairs(s.packages) do
      if not validate(p) or seen[p.id] then return nil end
      seen[p.id]=true
    end
    return s
  end
  function self:pending()
    local ok,raw=pcall(d.cache.read,d.cache,M.KEY)
    if not ok then return nil,"queue_read_failed" end
    if raw==nil then return nil end
    if type(raw)~="string" or #raw>4194304 then return nil,"invalid_queue" end
    local yes,job=pcall(d.decode,raw)
    if not yes or not validate(job) then return nil,"invalid_queue" end
    return job
  end
  function self:request(id,consent)
    if consent~=true then return false,"confirmation_required" end
    if d.busy and d.busy() then return false,"busy" end
    local pending,err=self:pending();if pending or err then return false,err or "restart_required" end
    local s=inventory();if not s then return false,"inventory_incomplete" end
    local target
    for _,p in ipairs(s.packages) do if p.id==id then target=p end end
    if not target then return false,"not_installed" end
    local raw=d.encode(target);if type(raw)~="string" or #raw>4194304 then return false,"invalid_queue" end
    local ok,yes=pcall(d.cache.write,d.cache,M.KEY,raw)
    local read,back=pcall(d.cache.read,d.cache,M.KEY)
    if not ok or yes~=true or not read or back~=raw then return false,"queue_write_failed" end
    return true,"restart_required"
  end
  local function remove(key)
    local ok,info=pcall(d.cache.info,d.cache,key)
    if not ok then return false end
    if info==nil then return true end
    local yes,result=pcall(d.cache.remove,d.cache,key)
    local checked,after=pcall(d.cache.info,d.cache,key)
    return yes and result==true and checked and after==nil
  end
  function self:applyBeforeMount()
    if not d.safeBeforeMount or d.safeBeforeMount()~=true then return false,"not_safe_before_mount" end
    local job,err=self:pending();if err then return false,err end
    if not job then return true,"nothing_pending" end
    local s=inventory();if not s then return false,"inventory_incomplete" end
    local protected={}
    for _,p in ipairs(s.packages) do
      if p.id~=job.id then
        for _,k in ipairs(p.activationKeys) do protected[k]=true end
        for _,k in ipairs(p.payloadKeys) do protected[k]=true end
      end
    end
    for _,k in ipairs(job.activationKeys) do if protected[k] then return false,"shared_activation_key" end end
    -- Fail closed: renderer must not mount anything until this completes.
    -- Invalidate receipts first. The persisted job retains the full cleanup list
    -- across interruption, even when the target disappears from the inventory.
    for _,k in ipairs(job.activationKeys) do if not remove(k) then return false,"activation_remove_failed" end end
    for _,k in ipairs(job.payloadKeys) do if not protected[k] and not remove(k) then return false,"payload_remove_failed" end end
    if not remove(M.KEY) then return false,"queue_remove_failed" end
    return true,"removed"
  end
  return self
end
return M
