-- One startup reminder per process, shared with VASC when it owns the session.
-- Optional-file inventory must not hold the reminder hostage. Only explicit
-- opt-out disables it; declining for now is never persisted as opt-out.
local M={}
function M.attach(session)
  if session.__kascStartupOfferV2 then return end
  session.__kascStartupOfferV2=true
  local update=session.update
  function session:update(game,dt,...)
    -- Older VASC sessions gate their reminder on a complete file inventory.
    -- Suppress that one branch, leaving their download/update owner intact.
    local requested=self.offerRequested
    self.offerRequested=true
    local ok,err=pcall(update,self,game,dt,...)
    self.offerRequested=requested
    if not ok then error(err,0)end
    if self.promptDisabled or self.onboardingShown or self.offerRequested
      or (self.offerStable or 0)<0.5 then return end
    local configured=false
    for _,p in ipairs(self.catalog.data.packages)do
      if p.published==true and (not self.catalog.relevant or self.catalog:relevant(p)) and not self.catalog:installed(p.id,self.store) then configured=true;break end
    end
    if not configured then return end
    self.offerRequested=true
    local success,page=pcall(require('src.ui.Screens').push,game,self.offerScreenId)
    if not success or not page then self.offerRequested=false end
  end
end
return M
