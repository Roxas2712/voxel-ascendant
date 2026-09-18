-- Ascendant's single installed-content session, shared by both game generations.
local M={}
function M.new(mod,options)
  options=options or {}
  local importIds=options.importIds or {['stadium2-local']=true}
  local modules={}
  local function load(name)
    if not modules[name] then modules[name]=assert((loadstring or _G.load)(assert(mod:read('lib/'..name..'.lua')),'@'..name))() end
    return modules[name]
  end
  local Json=load('ContentJson')
  local Text=load('SpriteContentText')
  local function encode(v)
    local t=type(v)
    if t=='nil' then return 'null' elseif t=='boolean' or t=='number' then return tostring(v)
    elseif t=='string' then return '"'..v:gsub('[%z\1-\31\\"]',function(c)
      local map={['"']='\\"',['\\']='\\\\',['\n']='\\n',['\r']='\\r',['\t']='\\t'}
      return map[c] or string.format('\\u%04x',c:byte())end)..'"'
    elseif t=='table' then
      local count,array=0,true;for k in pairs(v)do count=count+1;if type(k)~='number' or k<1 or k%1~=0 then array=false end end
      local out={};if array and #v==count then for i,x in ipairs(v)do out[i]=encode(x)end;return '['..table.concat(out,',')..']' end
      local keys={};for k in pairs(v)do keys[#keys+1]=k end;table.sort(keys)
      for _,k in ipairs(keys)do out[#out+1]=encode(k)..':'..encode(v[k])end;return '{'..table.concat(out,',')..'}'
    end
    error('unsupported JSON value')
  end
  local cache=assert(options.cache or mod.cache,'Ascendant requires installation cache support')
  local ca={read=function(_,k)return cache:read(k)end,write=function(_,k,v)return cache:write(k,v)end,
    info=function(_,k)return cache:info(k)end,remove=function(_,k)return cache:delete(k)end}
  local sha=function(raw)return love.data.encode('string','hex',love.data.hash('sha256',raw))end
  local catalog=load('SpriteCatalog').new(load(options.catalogModule or 'SpriteCatalogData'))
  -- The approved longer fronts are part of the normal Mega collection.
  local repairedMega='vasc.sprite.pokemon-mega-original-20260830.all.part01'
  local megaStyle=catalog.styles['pokemon-mega']
  if megaStyle and catalog.packages[repairedMega]then
    local found=false;for _,id in ipairs(megaStyle.packages)do if id==repairedMega then found=true end end
    if not found then megaStyle.packages[#megaStyle.packages+1]=repairedMega end
  end
  local packageScope=load('SpritePackageScope')
  catalog.activeOwners={[options.owner or 'vasc']=true}
  function catalog:relevant(p)
    -- Gorochu is authored, bundled art; its obsolete catalogue placeholder
    -- must not turn it into a user-download requirement.
    if p.family=='pokemon-gorochu' then return false end
    if p.adapter=='existing-HdContentStore'then return true end
    for _,owner in ipairs(p.owners or {})do
      if self.activeOwners[owner] and (not packageScope[p.id] or (packageScope[p.id][owner] or 0)>0)then return true end
    end
    return p.owners==nil
  end
  local cfg=load('SpriteHostConfig')
  local bundles=load('SpriteBundleData')
  for _,p in ipairs(catalog.data.packages)do if bundles[p.id]then p.transferBytes=bundles[p.id].bytes end end
  local self={catalog=catalog,cache=ca,state='idle',epoch=0,mod=mod,lastNotice='',safeBoot=true,
    downloadScreenId=options.downloadScreenId or 'VascPokemonHdDownloads',offerScreenId=options.offerScreenId or 'VascPokemonHdOffer'}
  local Compat=assert((loadstring or _G.load)(assert(mod:read(options.compatPath or 'gen2/lib/EngineCompat.lua')),'@ContentCompat'))()
  local fs=assert(Compat.fs(),'content filesystem unavailable')
  if not fs.newFile or not fs.getDirectoryItems or not fs.getSaveDirectory then
    local ok,SaveData=pcall(require,'src.core.SaveData')
    local base=ok and SaveData.portableBaseDir and SaveData.portableBaseDir()
    if base then
      fs=load('AscendantPortableContentFs').new{fs=fs,base=base,shell=Compat.hostShell(),
        modId=mod.id,cacheId=options.cacheId,osName=Compat.osName(),
        base64=function(raw)return love.data.encode('string','base64',raw)end}
    end
  end
  if not fs.newFileData then
    -- FileData constructed from bytes is independent of persistence routing.
    -- The engine's portable filesystem omits this factory; its sandbox
    -- compatibility API still exposes the in-memory constructor. Do not
    -- redirect cache reads/writes to that API's different storage root.
    local ok,factory=pcall(function()return love.filesystem.newFileData end)
    if ok and type(factory)=='function' then
      local copy={};for k,v in pairs(fs)do copy[k]=v end
      copy.newFileData=factory;fs=copy
    end
  end
  local StadiumContent=load('StadiumContentState')
  local stadiumPath=StadiumContent.path
  local originalRead,originalInfo,originalRemove=ca.read,ca.info,ca.remove
  function ca:read(key)local path=stadiumPath(key);if path then return fs.read(path)end;return originalRead(self,key)end
  function ca:info(key)local path=stadiumPath(key);if path then return fs.getInfo(path,'file')end;return originalInfo(self,key)end
  function ca:remove(key)local path=stadiumPath(key);if path then return fs.remove(path)end;return originalRemove(self,key)end
  local function list(dir)
    if not fs.getDirectoryItems then return nil end
    local ok,rows=pcall(fs.getDirectoryItems,'mod_cache/'..(options.cacheId or mod.id)..'/'..dir)
    if not ok or type(rows)~='table' then error('content inventory unavailable')end
    return rows
  end
  local function inventory()
    local active=list('hd-content/active') or {};local installed=list('sprite-content/installed') or {};local pending=list('sprite-content/pending') or {}
    if not fs.getDirectoryItems then return {complete=false} end
    local rows={};local function row(id)
      rows[id]=rows[id] or {id=id,activationKeys={},payloadKeys={}};return rows[id]
    end
    local function addManifest(r,raw,key)
      local m=type(raw)=='string' and Json.decode(raw)
      if type(m)~='table' or type(m.files)~='table' then return false end
      r.payloadKeys[#r.payloadKeys+1]=key
      for _,f in ipairs(m.files)do
        if type(f.sha256)~='string' or not f.sha256:match('^[a-f0-9]+$') or #f.sha256~=64 then return false end
        for _,c in ipairs(f.chunks or {})do
          if type(c.sha256)~='string' or not c.sha256:match('^[a-f0-9]+$') or #c.sha256~=64 then return false end
          r.payloadKeys[#r.payloadKeys+1]=(m.schema:match('^apo%.content%-package/') and 'hd-content/blobs/' or 'sprite-content/blobs/')..c.sha256
        end
        if f.owner and type(f.logicalPath)=='string' then
          local ext=f.logicalPath:match('%.([a-z]+)$');if ext then r.payloadKeys[#r.payloadKeys+1]='sprite-content/files/'..f.sha256..'.'..ext end
        end
      end
      return true
    end
    for _,name in ipairs(active)do
      local id=name:match('^(.*)%.[01]$')
      if id then
        local r=row(id);local key='hd-content/active/'..name;r.activationKeys[#r.activationKeys+1]=key
        local raw=ca:read(key);local h=raw and raw:match('^VASC%-HD%-1\n%d+\n([a-f0-9]+)\n')
        if not h or #h~=64 or not addManifest(r,ca:read('hd-content/manifests/'..h),'hd-content/manifests/'..h)then return {complete=false}end
      end
    end
    for _,id in ipairs(installed)do
      local r=row(id);local key='sprite-content/installed/'..id;r.activationKeys[#r.activationKeys+1]=key
      local h=ca:read(key)
      if not h or #h~=64 or not addManifest(r,ca:read('sprite-content/manifests/'..h..'.json'),'sprite-content/manifests/'..h..'.json')then return {complete=false}end
    end
    for _,id in ipairs(pending)do
      local r=row(id);local key='sprite-content/pending/'..id;r.activationKeys[#r.activationKeys+1]=key
      if not addManifest(r,ca:read(key),key)then return {complete=false}end
    end
    for _,id in ipairs(list('sprite-content/archive-pending') or {})do
      local meta=bundles[id];if not meta then return {complete=false}end
      local r=row(id);r.activationKeys[#r.activationKeys+1]='sprite-content/archive-pending/'..id
      for _,c in ipairs(meta.chunks)do r.payloadKeys[#r.payloadKeys+1]='sprite-content/archive-blobs/'..c.sha256 end
    end
    if importIds['stadium2-local'] then
      local stadium=StadiumContent.inventory(fs)
      if not stadium then return {complete=false}end
      if #stadium.activationKeys>0 then rows[stadium.id]=stadium end
    end
    local out={};for _,r in pairs(rows)do out[#out+1]=r end;return {complete=true,packages=out}
  end
  self.removal=load('SpriteContentRemoval').new{cache=ca,inventory=inventory,encode=encode,decode=Json.decode,
    ownedRoots={'sprite-content/archive-blobs/','sprite-content/archive-pending/','stadium-generated/stadium/','stadium-generated/stadium2-gen1/','sprite-content/pending/','sprite-content/installed/','sprite-content/manifests/','sprite-content/blobs/','sprite-content/files/','hd-content/active/','hd-content/manifests/','hd-content/blobs/'},
    busy=function()return self:busy()end,safeBeforeMount=function()return self.safeBoot end}
  self.maintenance=load('SpriteMaintenance').new{cache=ca,list=list,encode=encode,decode=Json.decode,sha256=sha,
    safeBeforeMount=function()return self.safeBoot end,
    busy=function()return self:busy() or self.removal:pending()~=nil end,
    check=function(id)return self:maintenanceCheck(id)end,
    startDownload=function(ids)return self:startMaintenanceDownload(ids)end,
    downloadState=function()return self.installer.state,self.installer.error end,
    cancel=function()if self.installer then self.installer:cancel()end end}
  local maintenanceOK,maintenanceError=self.maintenance:beforeMount()
  if not maintenanceOK then error('Sprite maintenance: '..tostring(maintenanceError))end
  local pendingDeletion=self.removal:pending()
  if pendingDeletion and pendingDeletion.id=='stadium2-local' then assert(ca:write('sprite-content/stadium-disabled','1'),'could not disable automatic rebuild')end
  local removed,why=self.removal:applyBeforeMount();if not removed then error('Content removal pending: '..tostring(why))end
  local bootStarted=love.timer.getTime()
  self.bootTimings={}
  local hd=load('HdContentStore').new{cache=cache,decode=Json.decode,sha256=sha,legacyFlame155=load('HdLegacyFlame155')}
  for _,p in ipairs(catalog.data.packages)do if p.adapter=='existing-HdContentStore' then hd:restoreIndex(p.id)end end
  self.hdBoot=hd;self.hdWrite=hd:forkVerified()
  self.bootTimings.hdSeconds=love.timer.getTime()-bootStarted
  local genericStarted=love.timer.getTime()
  local generic=load('SpritePackageStore').new{catalog=catalog,cache=ca,decode=Json.decode,sha256=sha}
  for _,p in ipairs(catalog.data.packages)do if p.adapter~='existing-HdContentStore' then generic:restoreIndex(p)end end
  self.generic=generic
  self.bootTimings.genericSeconds=love.timer.getTime()-genericStarted
  self.store=load('SpriteStoreBridge').new{catalog=catalog,generic=generic,legacyBoot=hd,legacyWrite=self.hdWrite,
    hasImport=function(id)return self:hasImport(id)end}
  self.restart=load('SpriteContentRestart').new{
    worldSafe=load('HdContentOffer').worldSafe,
    show=function(game,restart)
      self.game=game
      local top=game.stack:top()
      if not top or not top.ascendantContentRestart then
        local screen=self:openStatus();screen.ascendantContentRestart=true
      end
    end}
  local activate=self.store.activate
  function self.store:activate(...)
    local ok,err=activate(self,...)
    if ok==true then self.contentSession.restart:installed()end
    return ok,err
  end
  self.store.contentSession=self
  local inspect=self.store.inspect
  function self.store:inspect(raw,p)
    local m,err=inspect(self,raw,p)
    if m and ca:write('sprite-content/pending/'..p.id,raw)~=true then return nil,'cache_write_failed' end
    return m,err
  end
  self.safeBoot=false
  local native=load('HdBinaryFetch').new(mod)
  local reportNet
  local ok,Fetch=pcall(require,'src.net.Fetch')
  if ok then reportNet=load('SpriteReportTransport').new(Fetch,Json.decode)end
  self.diagnostics=load('SpriteDownloadDiagnostics').new{cache=ca,encode=encode,decode=Json.decode,now=os.time,
    newId=function()return sha(tostring(os.time())..tostring(love.timer.getTime())..tostring({})):sub(1,32)end,
    version=mod.version,platform=Compat.osName(),endpoint=cfg.reportEndpoint,transport=reportNet}
  local fetch=load('SpriteMirrorFetch').new{transport=native,mirrors=cfg.mirrors,
    now=love.timer.getTime,sha256=sha,diagnostics=self.diagnostics}
  self.installer=load('SpriteBundleInstaller').new{catalog=catalog,store=self.store,fetch=fetch,diagnostics=self.diagnostics,
    bundles=bundles,cache=ca,sha256=sha,now=love.timer.getTime,Importer=load('SpritePackageImport')}
  -- A receipt restores fast at boot; explicit maintenance verifies its payload.
  local originalInstalled=catalog.installed
  function catalog:installed(id,store)
    if self.maintenanceMissing and self.maintenanceMissing[id] then return false end
    return originalInstalled(self,id,store)
  end
  function self:maintenanceIds()
    local ids={}
    for _,p in ipairs(catalog.data.packages)do
      if p.published and (ca:info('sprite-content/installed/'..p.id)
        or ca:info('sprite-content/pending/'..p.id) or ca:info('sprite-content/archive-pending/'..p.id)
        or ca:info('hd-content/active/'..p.id..'.0') or ca:info('hd-content/active/'..p.id..'.1'))then ids[#ids+1]=p.id end
    end
    table.sort(ids);return ids
  end
  function self:maintenanceCheck(id)
    local p=catalog.packages[id];local m,fi,ci
    local legacy=p and p.adapter=='existing-HdContentStore'
    local target=legacy and self.hdWrite or generic
    return function()
      if not p then return false end
      if not self.store:receipt(id) then return false end
      if not legacy and ca:read('sprite-content/installed/'..id)~=p.manifestSha256 then return false end
      if legacy then
        local valid=false
        for slot=0,1 do
          local raw=ca:read('hd-content/active/'..id..'.'..slot)
          local seq,digest,checksum
          if type(raw)=='string'and #raw<=256 then seq,digest,checksum=raw:match('^VASC%-HD%-1\n(%d+)\n([0-9a-f]+)\n([0-9a-f]+)$')end
          if seq and digest==p.manifestSha256 and sha('VASC-HD-1\n'..seq..'\n'..digest..'\n')==checksum then valid=true end
        end
        if not valid then return false end
      end
      if not m then
        local key=legacy and 'hd-content/manifests/'..p.manifestSha256 or 'sprite-content/manifests/'..p.manifestSha256..'.json'
        local raw=ca:read(key)
        if legacy then m=self.hdWrite:inspect(raw,p.manifestSha256)else m=generic:inspect(raw,p)end
        if not m or m.id~=p.id or m.revision~=p.revision then return false end
        fi,ci=1,1;return nil
      end
      local f=m.files[fi];if not f then return true end
      local c=f.chunks[ci]
      if c then
        if not target:hasChunk(c.sha256,c.bytes)then return false end
        ci=ci+1;return nil
      end
      if not legacy then
        local ext=f.logicalPath:match('%.(%w+)$');local key='sprite-content/files/'..f.sha256..'.'..ext
        local raw=ca:read(key)
        if raw and sha(raw)~=f.sha256 then
          if ca:remove(key)~=true or ca:info(key)~=nil then error('maintenance_delete_failed')end
        end
      end
      fi=fi+1;ci=1;return nil
    end
  end
  function self:startMaintenanceDownload(ids)
    catalog.maintenanceMissing=self.maintenance.missing
    local plan=catalog:plan(ids,self.store)
    if not plan.canDownload then return false,'not_yet_available'end
    self.downloadIds=ids;self.lastPackage=ids[1];self.activeOperation='maintenance'
    return self.installer:start(plan,true)
  end
  function self:confirmMaintenance(mode)
    if self:busy() or self.removal:pending()then return self:openStatus()end
    if self.maintenance:pending()then
      local yes,why=self.maintenance:resume();if not yes then return self:notice(why)end
      return self:openStatus()
    end
    local ids=self:maintenanceIds()
    local labels={repair={'CHECK / REPAIR SPRITES','SPRITES PRUEFEN / REPARIEREN'},reinstall={'REINSTALL DOWNLOADED SPRITES','DOWNLOAD-SPRITES NEU INSTALLIEREN'},delete={'DELETE ALL DOWNLOADED SPRITES','ALLE DOWNLOAD-SPRITES LOESCHEN'}}
    local label=labels[mode];if not label then return end
    local help=mode=='repair'and(self.de and 'Prueft vorhandene und unterbrochene Pakete. Nur beschaedigte Pakete werden erneut geladen. Spielstaende bleiben erhalten.'or'Checks existing and interrupted packs. Only broken packs are downloaded again. Saves are kept.')
      or(self.de and 'Betrifft den gemeinsamen KASC/VASC-Downloadspeicher. Loeschen erst nach Speichern und Neustart. Spielstaende, mitgelieferte Grafiken und Stadium-Importe bleiben erhalten.'or'Affects the shared KASC/VASC download cache. Deletes only after saving and restarting. Saves, bundled graphics and Stadium imports are kept.')
    if mode=='reinstall'then help=help..(self.de and ' Danach werden die bisherigen Pakete automatisch neu geladen.'or' Previously downloaded packs then download again automatically.')end
    self:pushMenu('ascendant_sprite_maintenance_confirm',self.de and label[2]or label[1],{
      {label=self.de and 'ABBRECHEN'or'CANCEL',action='cancel'},
      {label=self.de and 'BESTAETIGEN'or'CONFIRM',action='confirm',right=tostring(#ids)..(self.de and ' Pakete'or' packs')}
    },function(row)
      if row.action=='cancel'then return self.game.stack:pop()end
      local ok,why=self.maintenance:request(mode,ids,true)
      if not ok then return self:notice(why)end
      self.game.stack:pop();self.activeOperation='maintenance';self.maintenanceNotified=false
      if why=='restart_required'then self.restart:installed()end
      self:openStatus()
    end,help)
  end
  self.model=load('SpriteDownloadMenuModel').new(catalog,self.store,{language='de',importIds=importIds,hasPartial=function(id)return ca:info('sprite-content/pending/'..id)~=nil or ca:info('sprite-content/archive-pending/'..id)~=nil end})
  function self:busy()
    if self.stadiumState then local s=self.stadiumState();if s and s.building then return true end end
    return self.maintenance and (self.maintenance.state=='checking' or self.maintenance.state=='downloading') or self.pendingDownloadIds~=nil or self.installer and self.installer.state=='downloading' or self.importer and self.importer:busy() or false
  end
  function self:hasImport(id)
    if id~='stadium2-local' then return false end
    if not self.stadiumState then return false end
    local state=self.stadiumState()
    return state and state.ready==true or false
  end
  function self:notice(code)
    if code=='busy_or_restart_required' and (self.pendingDownloadIds or self.installer.state=='downloading') then return self:openStatus()end
    self.lastNotice=tostring(code or '');self.epoch=self.epoch+1
    if self.guided and self.game then
      local message=Text.message(self.lastNotice,self.de)
      self:pushMenu('vasc_content_notice','ASCENDANT DOWNLOADS',{{label=message},{label='OK',action='ok'}},function(row)if row.action=='ok' then self.game.stack:pop()end end,message)
    end
  end
  function self:allowSetting(key,value,game,get)
    local style=load('SpriteSettingContent').required(key,value,get)
    if not style or not catalog.styles[style] or self.store:styleMounted(style) then return true end
    self.game=game
    -- A manager preset/reset may write several options in one callback. Keep
    -- the first download page instead of stacking one page per missing value.
    for _,screen in ipairs(game.stack and game.stack.states or {})do
      if screen==self.settingRedirect then return false end
    end
    local plan=catalog:stylePlan(style,self.store)
    local menu=require('src.ui.Screens').push(game,self.downloadScreenId)
    self.settingRedirect=menu
    if plan.ready then self:notice(self.de and 'Sprites geprueft. Bitte zuerst neu starten.' or 'Sprites verified. Please restart first.')
    elseif menu and menu.openFamily then menu:openFamily(style)end
    return false -- keep the previous style until its replacement is installed and mounted
  end
  function self:planFor(ids)return catalog:plan(ids,self.store)end
  function self:confirmDownload(ids)
    if self.maintenance:pending() then return self:openStatus()end
    if self.restart.phase~='idle'and self.restart.phase~='waiting'then return self:openStatus()end
    ids=load('SpriteDownloadSelection').expand(catalog,ids)
    if self.pendingDownloadIds or self.installer.state=='downloading' then return self:openStatus()end
    self.lastPackage=ids[1]
    local p=self:planFor(ids)
    if p.ready then return self:notice('already_installed')end
    if not p.canDownload then return self:notice('not_yet_available')end
    local help=(self.de and 'Alle fehlenden Pakete laufen automatisch nacheinander. Bereits installierte Inhalte werden uebersprungen. Fehlende Pakete: ' or 'All missing packages download automatically, one after another. Installed content is skipped. Missing packages: ')..#p.missing..(self.de and ' Danach wird das Spiel automatisch gespeichert und neu gestartet.' or ' When finished, the game saves and restarts automatically.')
    local rows={{label=self.de and 'ABBRECHEN' or 'CANCEL',action='cancel'},{label=self.de and 'HERUNTERLADEN' or 'DOWNLOAD',action='start',right=string.format('%.1f MiB',p.downloadBytes/1048576)}}
    self:pushMenu('vasc_content_confirm',self.de and 'DOWNLOAD BESTÄTIGEN' or 'CONFIRM DOWNLOAD',rows,function(row)
      if row.action=='start' then
        if self:busy() or self.removal:pending() then return self:notice('busy_or_restart_required')end
        local current=self:planFor(ids)
        if current.ready then self.game.stack:pop();return self:notice('already_installed')end
        if not current.canDownload then return self:notice('not_yet_available')end
        local checked,total=0,0
        if self.inventoryProgress then checked,total=self:inventoryProgress(ids)end
        if checked<total then
          self.pendingDownloadIds={};for i,id in ipairs(ids)do self.pendingDownloadIds[i]=id end
          if self.bundledRemoval then for i=#ids,1,-1 do self.bundledRemoval:prioritize(ids[i])end end
        else
          local yes,err=self.installer:start(current,true);if not yes then return self:notice(err)end
        end
        self.activeOperation='download'
        self.downloadIds={};for i,id in ipairs(ids)do self.downloadIds[i]=id end
        self.lastPackage=current.missing[1]
        self.game.stack:pop()
        return self:openStatus()
      end
      self.game.stack:pop()
    end,help)
  end
  function self:pushMenu(key,title,rows,choose,help)
    local menu=self.guided(mod,self.game,{key=key,title=title,rows=rows,help=help or '',footer=self.de and 'A:WAHL SEL:HILFE B:ZURÜCK' or 'A:SELECT SEL:HELP B:BACK',onChoose=choose})
    menu.showFirstGuide=function()return false end
    self.game.stack:push(menu);return menu
  end
  function self:openStatus()
    self.downloadFamilyLabels={}
    for _,g in ipairs(self.model:groups())do self.downloadFamilyLabels[g.id]=g.label end
    local top=self.game.stack:top()
    if top and top.key=='vasc_content_status'then return top end
    local menu=load('SpriteDownloadStatus').new(self.game,self,Text)
    self.game.stack:push(menu);return menu
  end
  function self:openDiagnostics()
    return self:pushMenu('vasc_content_diagnostics',self.de and 'DIAGNOSE & BERICHTE' or 'DIAGNOSTICS & REPORTS',{
      {label=self.de and 'OFFENE BERICHTE' or 'PENDING REPORTS',right=tostring(#self.diagnostics.state.outbox)},
      {label=self.de and 'LOKALE VORGÄNGE' or 'LOCAL OPERATIONS',right=tostring(#self.diagnostics.state.history)},
      {label=self.de and 'VERSAND' or 'REPORT DELIVERY',right=self.diagnostics.warning and Text.message(self.diagnostics.warning,self.de) or Text.state('idle',self.de)},
      {label=self.de and 'ZURÜCK' or 'BACK',action='back'}},function(row)if row.action=='back' then self.game.stack:pop()end end,
      self.de and 'Erfolge und Fehler werden automatisch gemeldet. Private Pfade, Codes und ROM-Daten werden nicht gesendet.' or 'Successes and errors are reported automatically. Private paths, codes and ROM data are not sent.')
  end
  function self:openImport(id)
    if id~='stadium2-local' or not self.stadiumChoose then return self:notice('importer_unavailable')end
    return self.stadiumChoose(self.game)
  end
  self.manual=load('SpriteManualDownload').new{catalog=catalog,links=cfg.manualLinks,
    copy=mod.contentActions and function(text)return mod.contentActions:copy(text)end,
    open=mod.contentActions and function(url)return mod.contentActions:open(url)end}
  function self:openLinkCard(id)
    local matrix=load('SpriteLinkQrData')[id]
    if matrix then return self.game.stack:push(load('SpriteLinkCard').new(self.game,matrix,id))end
    self:notice('link_card_unavailable')
  end
  function self:openManual(id,de)return self.manual:show(self,id,de)end
  function self:importStaged(path,id)
    if self.maintenance:pending() then return self:openStatus()end
    local function rejected(code)self.diagnostics:begin();self.diagnostics:finish('error',{code=code});return self:notice(code)end
    if self:busy() then return self:notice('busy_or_restart_required')end
    local checked,info=pcall(fs.getInfo,path,'file')
    if not checked or not info or type(info.size)~='number' or info.size<1 or info.size>1073741824 then return rejected('invalid_size')end
    local made,file=pcall(fs.newFile,path)
    if not made or not file then return rejected('file_open_failed')end
    local opened=file:open('r')
    if not opened then return rejected('file_open_failed')end
    local header=file:read(89)
    local digest=type(header)=='string' and header:match('^VASC%-[A-Z%-]+%-1\n([a-f0-9]+)\n')
    local p
    for _,candidate in ipairs(catalog.data.packages)do if candidate.manifestSha256==digest and (not id or candidate.id==id)then p=candidate;break end end
    if not p then file:close();return rejected('manifest_mismatch')end
    -- Replay the small sniffed header instead of seeking. Portable imports
    -- can then stay sequential and bounded even for very large HD packages.
    local prefix=header;local reader={}
    function reader:read(n)
      local first=prefix:sub(1,n);prefix=prefix:sub(#first+1)
      if #first==n then return first end
      local rest=file:read(n-#first)
      if type(rest)~='string' then return #first>0 and first or nil end
      return first..rest
    end
    function reader:close()prefix='';return file:close()end
    self.importer=load('SpritePackageImport').new{store=self.store}
    self.diagnostics:begin();self.diagnostics:event('package_started',{packageId=p.id})
    local yes,why=self.importer:start(reader,info.size,p,true)
    if not yes then self.diagnostics:finish('error',{code=why});self:notice(why)end
    self.activeOperation='import';self.importDiagnostic=yes;self.lastPackage=p.id;self:openStatus()
  end
  function self:openPackageImport(id)
    if self:busy() or self.removal:pending() then return self:notice('busy_or_restart_required')end
    -- A selected file is consent to import; its manifest must match the pinned package.
    local ok,Picker=pcall(require,'src.core.FilePicker')
    if ok and Picker.available and Picker.available() then
      local selected=Picker.open(self.de and 'Ascendant: Sprite-/HD-Paket importieren' or 'Ascendant: Import sprite / HD package',{label='Ascendant sprite package',exts={'spritepack','vaschd'},tempName='ascendant-selected-package'})
      if not selected then return self:notice('selection_cancelled')end
      local relative='mod_cache/'..mod.id..'/sprite-content/selected-package'
      fs.createDirectory('mod_cache/'..mod.id..'/sprite-content')
      fs.remove(relative)
      local called,copied=pcall(fs.stageExternal or Compat.stageExternal,selected,relative)
      if not called or not copied then return self:notice('file_copy_failed')end
      self:importStaged(relative,id)
      if self.importDiagnostic then self.importStagingPath=relative else fs.remove(relative)end
      return
    end
    local osName=Compat.osName()
    if osName=='Android' or osName=='iOS' then
      self.nativePicker=self.nativePicker or load('SpriteNativePicker').new{mod=mod,fs=fs,decode=Json.decode}
      local started,reason=self.nativePicker:open()
      if started then self.nativeImportId=id or true;return self:notice('choose_package_file')end
      return self:notice(reason)
    end
    if mod.contentActions and mod.contentActions.pick then
      local started=mod.contentActions:pick({'spritepack','vaschd'})
      if started then self.pendingImport=id or true;return self:notice('choose_package_file')end
    end
    self:notice(self.de and 'Dateiauswahl nicht verfügbar. Paket im Spiel-Speicher unter sprite-import.spritepack ablegen und hier erneut wählen.' or 'File picker unavailable. Place the package in game storage as sprite-import.spritepack, then choose import again.')
    if fs.getInfo('sprite-import.spritepack','file')then return self:importStaged('sprite-import.spritepack',id)end
  end
  function self:menu(game,guided,de,rom)
    self.game=game;self.guided=guided;self.de=de
    if rom then
      self.stadiumChoose=function(g)return rom.choose(g)end
      self.stadiumState=rom.contentState
    end
    self.model=load('SpriteDownloadMenuModel').new(catalog,self.store,{language=de and 'de' or 'en',importIds=importIds,hasPartial=function(id)
      if id=='stadium2-local' then local inv=StadiumContent.inventory(fs);return inv and #inv.payloadKeys>0 or false end
      return ca:info('sprite-content/pending/'..id)~=nil or ca:info('sprite-content/archive-pending/'..id)~=nil
    end})
    return load('SpriteContentMenu').new(mod,game,guided,de,self)
  end
  local last=self.installer.state
  function self:update(game,dt)
    if self.pendingDownloadIds then
      local checked,total=self:inventoryProgress(self.pendingDownloadIds)
      if checked>=total then
        local ids=self.pendingDownloadIds;self.pendingDownloadIds=nil
        local plan=self:planFor(ids)
        local ok,err=self.installer:start(plan,true)
        if not ok then self:notice(err)end
      end
    end
    self.game=game or self.game
    if self.stadiumState then
      local state=self.stadiumState() or {}
      local key=tostring(state.ready)..':'..tostring(state.building)..':'..tostring(state.state)
      if key~=self.stadiumEpoch then self.stadiumEpoch=key;self.epoch=self.epoch+1 end
    end
    local safeOk,safe=pcall(load('HdContentOffer').safe,game)
    self.offerStable=safeOk and safe and (self.offerStable or 0)+math.min(dt or 0,0.25) or 0
    if not self.promptDisabled and not self.onboardingShown and not self.offerRequested and self.offerStable>=0.5 and self:hasAvailableDownloads() then
      self.offerRequested=true
      local ok,Screens=pcall(require,'src.ui.Screens')
      local pushed,screen=false,nil
      if ok then pushed,screen=pcall(Screens.push,game,self.offerScreenId)end
      if not pushed or not screen then self.offerRequested=false end
    end
    if self.nativeImportId and self.nativePicker then
      local path=self.nativePicker:poll(dt)
      if path then
        local id=self.nativeImportId;self.nativeImportId=nil
        self:importStaged(path,id~=true and id or nil)
        if self.importDiagnostic then self.importStagingPath=path else fs.remove(path)end
      end
    end
    self.installer:update()
    self.maintenance:update()
    catalog.maintenanceMissing=self.maintenance.missing
    if self.maintenance.state=='ready'and not self.maintenanceNotified then
      self.maintenanceNotified=true;self.epoch=self.epoch+1
      if self.maintenance.result=='healthy'then self:notice(self.de and 'Alle geprueften Sprite-Pakete sind vollstaendig und korrekt.'or'All checked sprite packs are complete and valid.')end
    end
    if self.importer then
      self.importer:update()
      if self.importDiagnostic and not self.importer:busy()then
        self.importDiagnostic=false
        if self.importStagingPath then fs.remove(self.importStagingPath);self.importStagingPath=nil end
        self.diagnostics:finish(self.importer.state=='ready' and 'success' or self.importer.state=='cancelled' and 'cancelled' or 'error',{code=self.importer.error})
        if self.importer.state~='ready'then self:notice(self.importer.error)end
      end
    end
    if self.pendingImport and mod.contentActions and mod.contentActions.pollPick then
      local path=mod.contentActions:pollPick()
      if path then local id=self.pendingImport;self.pendingImport=nil;self:importStaged(path,id~=true and id or nil)end
    end
    for _,gate in pairs(self.rewardMods or {})do gate:update()end
    self.diagnostics:update()
    self.restart:update(self.game,dt,self.maintenance.state=='restart_required'or self.installer.state=='ready'or self.importer and self.importer.state=='ready',self:busy())
    if self.installer.state~=last then last=self.installer.state;self.epoch=self.epoch+1 end
  end
  -- The old seen-once marker is not an explicit opt-out and must not silence this prompt.
  local PROMPT_KEY='sprite-content/startup-prompt-disabled-v1'
  self.promptDisabled=ca:read(PROMPT_KEY)=='1'
  self.onboardingShown=false
  function self:hasAvailableDownloads()
    for _,p in ipairs(catalog.data.packages)do
      if p.published==true and catalog:relevant(p) and not catalog:installed(p.id,self.store)then return true end
    end
    return false
  end
  function self:setStartupPrompt(enabled)
    local value=enabled and '0' or '1'
    if ca:write(PROMPT_KEY,value)~=true or ca:read(PROMPT_KEY)~=value then return false,'cache_write_failed'end
    self.promptDisabled=not enabled;self.epoch=self.epoch+1
    -- Re-enabling applies from the next start; never interrupt the settings screen.
    if enabled then self.onboardingShown=true end
    return true
  end
  function self:offer(game,guided,de,rom)
    self.game=game;self.guided=guided;self.de=de
    local function tr(en,german)return de and german or en end
    local later=tr('More graphics: Ascendant - DLC / Sprites. This prompt appears each start until you explicitly turn it off.','Weitere Grafiken: Ascendant - DLC / Sprites. Diese Abfrage erscheint bei jedem Start, bis du sie ausdruecklich abschaltest.')
    local rows={
      {label=tr('PLAY WITHOUT DOWNLOAD','OHNE DOWNLOAD SPIELEN'),action='skip',help=tr('Continue without a download. Ask again next start.','Kein Download. Weiterspielen und beim naechsten Start erneut fragen.')},
      {label=tr('DOWNLOAD / UPDATE ALL','ALLES LADEN / UPDATEN'),action='all',help=tr('Download all missing sprite collections in one go: HD, Crystal, Mega and more. Installed sprites are kept. Stadium needs your own file.','Alle fehlenden Sprite-Sammlungen in einem Durchgang laden: HD, Crystal, Mega und weitere. Vorhandene Sprites bleiben. Stadium braucht deine eigene Datei.')},
      {label=tr('HD WALKING SPRITES','HD-LAUFSPRITES'),action='hd',help=tr('Animated HD Pokemon in the world and as followers. Kanto, Johto and Hoenn; download all or choose a generation.','Animierte HD-Pokemon in der Spielwelt und als Begleiter. Kanto, Johto und Hoenn; alle laden oder Generation waehlen.')},
      {label=tr('BASE SPRITE PACK','BASIS-SPRITEPAKET'),action='graphics',help=tr('Complete base pack: Crystal, Mega, animations, pixel sprites and icons. One download for all normal Ascendant Pokemon graphics.','Komplettes Basispaket: Crystal, Mega, Animationen, Pixel-Sprites und Icons. Ein Download fuer alle normalen Ascendant-Pokemon-Grafiken.')},
      {label=tr('IMPORT A FILE','DATEI IMPORTIEREN'),action='import',help=tr('Choose a spritepack or vaschd file you already downloaded. The file is checked before import.','Eine geladene spritepack- oder vaschd-Datei auswaehlen. Sie wird vor dem Import geprueft.')},
      {label=tr('TURN OFF THIS PROMPT','ABFRAGE ABSCHALTEN'),action='disablePrompt',help=tr('Stop showing this choice at startup. You can turn it back on in Sprite Downloads.','Diese Startabfrage dauerhaft abschalten. Im Download-Menue kannst du sie wieder einschalten.')},
    }
    local baseRow=table.remove(rows,4);table.insert(rows,1,baseRow)
    if options.includeHd==false then table.remove(rows,4)end
    local menu=guided(mod,game,{key='vasc_content_first_choice',title=tr('POKEMON GRAPHICS','POKEMON-GRAFIKEN'),rows=rows,
      help=tr('Start with the complete base sprite pack. HD is optional. Original game graphics need no download. ','Zuerst das komplette Basis-Spritepaket laden. HD ist optional. Original-Spielgrafiken brauchen keinen Download. ')..later,
      footer=tr('A:CHOOSE SEL:HELP','A:WAHL SEL:HILFE'),
      onChoose=function(row)
        if not row or not row.action then return end
        if row.action=='disablePrompt' then
          local ok,err=self:setStartupPrompt(false);if not ok then return self:notice(err)end
        end
        self.onboardingShown=true;game.stack:pop()
        if row.action=='skip' or row.action=='disablePrompt' then return end
        local menu=self:menu(game,guided,de,rom)
        if row.action=='graphics'then game.stack:push(menu);return self:confirmDownload(load('SpriteDownloadSelection').base(catalog))end
        if row.action=='all' then game.stack:push(menu);return menu:downloadAll()end
        if row.action=='import' then return self:openPackageImport()end
        menu:openCategory(row.action=='hd' and 'full-hd' or 'pokemon')
      end})
    menu.showFirstGuide=function()return false end
    return menu
  end
  if fs.newFileData and love.graphics and love.image then
    local ok,Assets=pcall(require,'src.render.Assets')
    self.assetResolver=load('SpriteAssetResolver').install(mod,generic,ca,fs,love.graphics,love.image,ok and Assets or nil,options.owner)
  end
  self.rewardMods={}
  function self:rewardContent(rewardMod,eventArchive,game)
    self.game=game or self.game
    load('SpriteManagerSettingGuard').install(rewardMod.id)
    if self.rewardMods[rewardMod.id]then return self.rewardMods[rewardMod.id]end
    local gate=load('SpriteRewardContent').new{session=self,mod=rewardMod,assetIndex=load('SpriteGiftAssetIndex'),
      CodeContent=load('SpriteCodeContent'),cache=ca,encode=encode,decode=Json.decode,
      assets=function(profile)return load('SpriteRewardAssetPaths').resolve(rewardMod,self.game,profile,require('src.pokemon.Sprites'))end,
      profile=function(id)
        if eventArchive.profileForGame then return eventArchive.profileForGame(self.game,id)end
        return eventArchive.profile(id)
      end,safe=function()return self.offerStable>=0.5 end}
    if rewardMod==mod and options.owner=='kasc' then gate.resolver=self.assetResolver
    elseif fs.newFileData and love.graphics and love.image then
      local ok,Assets=pcall(require,'src.render.Assets')
      gate.resolver=load('SpriteAssetResolver').install(rewardMod,generic,ca,fs,love.graphics,love.image,ok and Assets or nil,'kasc')
    end
    self.rewardMods[rewardMod.id]=gate;return gate
  end
  mod.exports.ascendantContent=self
  self.managerSettingGuard=load('SpriteManagerSettingGuard').install(mod.id)
  return self
end
return M
