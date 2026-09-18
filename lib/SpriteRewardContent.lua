-- The caller has already validated the code and gameplay profile. This gate
-- handles image bytes only: no plaintext code, digest, grant or reservation.
local M={}
function M.new(d)
 local session=assert(d.session);local memo={};local self={}
 local function packagesForPath(path)
  if memo[path]then return memo[path]end
  local out={};local needle='\n'..path..'\n'
  for id,paths in pairs(d.assetIndex)do if paths:find(needle,1,true)then out[#out+1]=id end end
  table.sort(out);memo[path]=out;return out
 end
 function self:hasAsset(path)
  if type(path)~='string' or path:find('\n',1,true)then return false end
  if #packagesForPath(path)>0 then return true end
  local ok,raw=pcall(d.mod.read,d.mod,path);return ok and type(raw)=='string'and #raw>0
 end
 local function resolve(id)
  local profile=d.profile(id)
  if type(profile)~='table'then return nil end
  local authority=profile.assetAuthority
  local paths={}
  if not authority then
   if type(d.assets)~='function'then return nil end
   paths=d.assets(profile)
   if type(paths)~='table'then return nil end
  else
   for _,role in ipairs({'front','back','icon','follower'})do
    if type(authority[role])~='string'then return nil end
    paths[#paths+1]=authority[role]
   end
  end
  local selected={}
  for _,path in ipairs(paths)do
   if type(path)~='string'or path:find('\n',1,true)then return nil end
   if not path:match('^registry:[A-Z_]+$')then
    if not self:hasAsset(path)then return nil end
    -- An additive upgrade keeps earlier bundled art, including older variants.
    -- Actual readable bytes already satisfy this reward's image requirement;
    -- a missing current package receipt must not force downloading them again.
    -- Optional declarations never fabricate bytes, so missing art still queues.
    local ok,raw=pcall(d.mod.read,d.mod,path)
    if not ok or type(raw)~='string' or #raw==0 then
     for _,package in ipairs(packagesForPath(path))do selected[package]=true end
    end
   end
  end
  local keys={};for key in pairs(selected)do keys[#keys+1]=key end;table.sort(keys);return keys
 end
 function self:requiredPackages(profileId)return resolve(profileId)end
 self.queue=d.CodeContent.new{catalog=session.catalog,store=session.store,cache=d.cache,encode=d.encode,decode=d.decode,
  installer=session.installer,resolve=resolve,busy=function()return session:busy()or session.removal:pending()~=nil end,
  safe=d.safe,onReady=function()return true end}
 function self:ensure(profileId,validated)
  if validated~=true then return false,'code_not_validated'end
  local keys=resolve(profileId)
  if not keys then return false,'sprite_contract_missing'end
  if #keys==0 then return true end
  local plan=session.catalog:plan(keys,session.store)
  if plan.ready then
   local mounted=true;for _,id in ipairs(keys)do if not session.store:packageMounted(id)then mounted=false end end
   if mounted then return true end
  end
  local yes,err=self.queue:enqueue('profile:'..profileId,profileId,true)
  if not yes then return false,err end
  if self.queue.state=='waiting_retry'then self.queue:retry()end
  return false,plan.ready and 'sprite_restart_required'or 'sprite_download_pending'
 end
 function self:update()
  if d.mod.options and d.mod.options.get then
   local ok,enabled=pcall(d.mod.options.get,d.mod.options,'gift_codes_enabled')
   if not ok or enabled==false then
    if self.queue.state=='downloading'then session.installer:cancel();self.queue.state='waiting_retry'end
    return
   end
  end
  self.queue:update()
 end
 return self
end
return M
