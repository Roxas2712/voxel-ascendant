-- UI state machine shared by Gen1/Gen2. Adapters own menus, persistence and install.
local M={OFFER_KEY="sprite-content/onboarding-v1.txt", OFFER_VALUE="VASC-SPRITE-ONBOARDING-1\n"}
M.TEXT={
  de={title="Welche Sprites möchtest du herunterladen?",later="Du kannst weitere Sprite-Pakete jederzeit im VASC-Menü unter HD-Downloads & Importe herunterladen.",
    missing="Dieser Sprite-Stil ist noch nicht installiert. Lade die benötigten Pakete herunter oder wähle einen anderen Stil.",
    restart="Download geprüft. Starte das Spiel neu und wähle anschließend den Sprite-Stil.",
    unavailable="Dieses Paket ist noch nicht verfügbar. Wähle einen installierten Stil.",
    cancelled="Download abgebrochen. Der bisherige Sprite-Stil bleibt aktiv.",
    failed="Download fehlgeschlagen. Erneut versuchen, manuell importieren oder einen anderen Stil wählen."},
  en={title="Which sprites would you like to download?",later="You can download more sprite packs at any time from HD Downloads & Imports in the VASC menu.",
    missing="This sprite style is not installed. Download its required packages or choose another style.",
    restart="Download verified. Restart the game, then select the sprite style.",
    unavailable="This package is not available yet. Choose an installed style.",
    cancelled="Download cancelled. Your previous sprite style remains active.",
    failed="Download failed. Retry, import manually or choose another style."}}
function M.new(d)
  assert(d.catalog and d.store and d.cache and d.ui and d.settings,"missing adapter")
  local self={state="idle",pending=nil,stable=0,offerOpen=false,offeredSession=false,warning=nil,navigation=0}
  local text=M.TEXT[d.language] or M.TEXT.en
  local ok,raw=pcall(d.cache.read,d.cache,M.OFFER_KEY)
  self.acknowledged=ok and raw==M.OFFER_VALUE
  local function notice(key)
    if type(d.ui.notice)=="function" then pcall(d.ui.notice,d.ui,text[key] or key) end
  end
  local function remember()
    self.acknowledged=true;self.offeredSession=true
    local wrote,yes=pcall(d.cache.write,d.cache,M.OFFER_KEY,M.OFFER_VALUE)
    local read,value=pcall(d.cache.read,d.cache,M.OFFER_KEY)
    if not wrote or yes~=true or not read or value~=M.OFFER_VALUE then self.warning="onboarding_not_persisted" end
  end
  function self:tick(game,dt)
    if self.acknowledged or self.offeredSession or self.offerOpen or self.state~="idle" then return end
    local safe,yes=pcall(d.safe,game)
    self.stable=safe and yes==true and self.stable+math.min(math.max(tonumber(dt) or 0,0),0.25) or 0
    if self.stable<0.5 then return end
    self.offerOpen=true
    local decided=false
    local shown,result=pcall(d.ui.onboarding,d.ui,{title=text.title,hint=text.later,
      catalog=d.catalog.data,selected={}, -- no download preselected or started
      decide=function(action,keys)
        if decided then return false,"already_decided" end
        if action~="later" and action~="download" then return false,"invalid_action" end
        local plan
        if action=="download" then
          local valid,value=pcall(d.catalog.plan,d.catalog,keys or {},d.store)
          if not valid then return false,"invalid_selection" end
          plan=value
          if #plan.unavailable>0 then notice("unavailable");return false,"unavailable" end
        end
        decided=true;self.offerOpen=false;remember()
        if plan and #plan.missing>0 then return self:download(plan,true) end
        return true
      end})
    if not shown or not result then
      self.offerOpen=false;self.offeredSession=true;self.warning="onboarding_ui_unavailable"
      -- Retry next application launch; never persist a UI failure as a decision.
    end
  end
  function self:download(plan,consent)
    if consent~=true then return false,"confirmation_required" end
    if plan.kind=="import" then return false,"local_import_required" end
    if self.state=="downloading" then return false,"busy" end
    -- Replan on confirmation: never trust stale UI sizes or arbitrary package rows.
    local valid,current=pcall(d.catalog.plan,d.catalog,plan.packages,d.store)
    if not valid then return false,"invalid_selection" end
    if #current.unavailable>0 then notice("unavailable");return false,"unavailable" end
    if current.ready then return self:completed() end
    local started,job=pcall(d.install.start,d.install,current,true)
    if not started or not job then self.state="error";notice("failed");return false,"start_failed" end
    self.state="downloading";self.plan=current;return true
  end
  function self:select(slot,style)
    if self.state=="downloading" then return false,"busy" end
    if not d.catalog.styles[style] then return false,"unknown_style" end
    self.navigation=self.navigation+1;local navigation=self.navigation
    local plan=d.catalog:stylePlan(style,d.store)
    if plan.ready then
      local ready,mounted=pcall(d.store.styleMounted,d.store,style)
      if plan.kind~="native" and (not ready or mounted~=true) then notice("restart");return false,"restart_required" end
      local changed,yes=pcall(d.settings.set,d.settings,slot,style)
      if not changed or yes~=true then return false,"setting_write_failed" end
      self.pending=nil;self.state="idle";return true,"selected"
    end
    self.pending={slot=slot,style=style};self.state="choosing"
    -- Selection is intentionally not persisted before successful installation.
    local shown,yes=pcall(d.ui.downloads,d.ui,{style=style,plan=plan,hint=text.missing,
      importRequired=plan.kind=="import",canDownload=plan.canDownload,
      confirm=function(consent)
        if navigation~=self.navigation then return false,"stale_menu" end
        return self:download(plan,consent)
      end,
      cancel=function()
        if navigation~=self.navigation then return false,"stale_menu" end
        return self:cancel()
      end,
      chooseOther=function(other)
        if navigation~=self.navigation then return false,"stale_menu" end
        if self.state=="downloading" then return false,"busy" end
        self.pending=nil;self.state="idle";return self:select(slot,other)
      end})
    if not shown or not yes then self.pending=nil;self.state="idle";return false,"download_menu_unavailable" end
    return false,"download_required"
  end
  function self:completed()
    if self.plan then
      local plan=d.catalog:plan(self.plan.packages,d.store)
      if not plan.ready then return self:failed("verification_incomplete") end
      for _,key in ipairs(self.plan.packages) do
        local ok,yes=pcall(d.store.packageMounted,d.store,key)
        if not ok or yes~=true then
          self.state="idle";self.plan=nil;notice("restart");return false,"restart_required"
        end
      end
    end
    self.state="idle";self.plan=nil
    if self.pending then
      local p=self.pending
      -- Keep the pending choice only in memory. No silent next-launch activation.
      local plan=d.catalog:stylePlan(p.style,d.store)
      if not plan.ready then return self:failed("verification_incomplete") end
      return self:select(p.slot,p.style)
    end
    notice("restart");return true,"installed"
  end
  function self:failed(reason)
    self.state="error";self.lastError=reason;notice("failed");return false,reason
  end
  function self:cancel()
    if self.state=="downloading" and type(d.install.cancel)=="function" then pcall(d.install.cancel,d.install) end
    self.navigation=self.navigation+1
    self.state="idle";self.pending=nil;self.plan=nil;notice("cancelled");return true
  end
  return self
end
return M
