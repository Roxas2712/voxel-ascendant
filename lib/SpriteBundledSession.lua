-- Compose actual retained files from every installed Ascendant owner.
local M={}
function M.attach(session,mod,nativeInfo,owner)
 owner=owner or 'kasc'
 if session.catalog.activeOwners then session.catalog.activeOwners[owner]=true end
 session.bundledInventories=session.bundledInventories or {}
 if session.bundledInventories[owner]then return session.bundledInventories[owner]end
 local function load(name)return assert((loadstring or _G.load)(assert(mod:read('lib/'..name..'.lua')),'@'..name))()end
 local Json=load('ContentJson')
 local function encode(job)
  assert(job.packageIds[1]:match('^[a-z0-9_.-]+$'))
  return '{"schema":"ascendant-legacy-delete-v1","owner":"'..owner..'","packageIds":["'..job.packageIds[1]..'"],"catalogSha256":"'..job.catalogSha256..'"}'
 end
 local original={read=function(_,path)return mod:read(path)end,info=function(_,path)return assert(nativeInfo)(mod,path)end}
 local inventory=load('SpriteBundledInventory').new{mod=original,owner=owner,directoryInfo=true,protected=owner=='kasc' and load('SpriteOwnedAssets')or nil,
  pin=load(owner=='vasc'and 'SpriteVascBundledManifestIndex'or'SpriteBundledManifestIndex'),decode=Json.decode,
  sha=function(raw)return love.data.encode('string','hex',love.data.hash('sha256',raw))end,
  now=love.timer.getTime,cache=session.cache,encode=encode,changed=function()session.epoch=session.epoch+1 end}
 session.bundledInventories[owner]=inventory
 if owner=='kasc'then session.kascBundledInventory=inventory end
 for _,p in ipairs(session.catalog.data.packages)do inventory:status(p.id)end
 if session.__bundledAdapter then return inventory end
 session.__bundledAdapter=true
 session.bundledRemoval={}
 function session.bundledRemoval:prioritize(id)
  for _,inv in pairs(session.bundledInventories)do inv:prioritize(id)end
 end
 function session.bundledRemoval:pending()
  for _,inv in pairs(session.bundledInventories)do local job=inv:pending();if job then return job end end
 end
 function session.bundledRemoval:request(id,consent)
  local any=false
  for _,inv in pairs(session.bundledInventories)do
   local state=inv:status(id)
   if state and state.checking then return false,'bundled_inventory_checking'end
   if state and state.present>0 then
    local ok,why=inv:request(id,consent);if not ok then return false,why end;any=true
   end
  end
  return any,any and 'bundled_removal_pending'or'not_installed'
 end
 function session.bundledRemoval:cancel(id)
  for _,inv in pairs(session.bundledInventories)do
   local job=inv:pending();if job and job.packageIds[1]==id then
    local ok,why=inv:cancel(id);if not ok then return false,why end
   end
  end
  return true,'bundled_removal_cancelled'
 end
 local store,catalog=session.store,session.catalog
 function store:localStatus(id)
  local states={};for own,inv in pairs(session.bundledInventories)do
   local state=inv:status(id);if state then states[#states+1]={owner=own,state=state}end
  end
  if #states==0 then return nil end
  local out={id=id,total=0,present=0,checked=0,checking=false,owners={}}
  for _,row in ipairs(states)do
   local s=row.state;out.total=out.total+s.total;out.present=out.present+s.present;out.checked=out.checked+s.checked
   out.checking=out.checking or s.checking;out.failed=out.failed or s.failed;out.owners[row.owner]=s
  end
  out.complete=not out.checking and not out.failed and out.total>0 and out.present==out.total
  out.partial=out.present>0 and not out.complete
  return out
 end
 function session:inventoryProgress(ids)
  local checked,total=0,0
  for _,id in ipairs(ids or {})do
   if not store:receipt(id)then
    local state=store:localStatus(id)
    if state then total=total+1;if not state.checking then checked=checked+1 end end
   end
  end
  return checked,total
 end
 local installed=catalog.installed
 function catalog:installed(id,s)
  if self.maintenanceMissing and self.maintenanceMissing[id]then return false end
  if installed(self,id,s)then return true end
  local state=store:localStatus(id);return state and state.complete==true or false
 end
 local mounted=store.packageMounted
 function store:packageMounted(id)
  if mounted(self,id)then return true end
  local state=self:localStatus(id);return state and state.complete==true or false
 end
 local style=store.styleMounted
 function store:styleMounted(id)
  if style(self,id)then return true end
  local row=catalog.styles[id];if not row or row.kind~='download'then return false end
  if row.activationPolicy=='any-package'then
   for _,key in ipairs(row.packages)do if self:packageMounted(key)then return true end end
   return false
  end
  for _,key in ipairs(row.packages)do if not self:packageMounted(key)then return false end end
  return #row.packages>0
 end
 local update=session.update
 function session:update(game,...)
  local top=game and game.stack and game.stack:top()
  if self.pendingDownloadIds or top and top.ascendantContentInventory and not self:busy()then
   for _,inv in pairs(self.bundledInventories)do inv:advance(2048)end
  end
  return update(self,game,...)
 end
 local menu=session.menu
 function session:menu(game,guided,de,rom)
  menu(self,game,guided,de,rom)
  self.model=load('SpriteDownloadMenuModel').new(catalog,store,{language=de and 'de'or'en',
   importIds=self.mod.id=='kanto_ascendant'and{}or{['stadium2-local']=true},
   hasPartial=function(id)return self.cache:info('sprite-content/pending/'..id)~=nil or self.cache:info('sprite-content/archive-pending/'..id)~=nil end})
  return load('SpriteContentMenu').new(mod,game,guided,de,self)
 end
 return inventory
end
return M
