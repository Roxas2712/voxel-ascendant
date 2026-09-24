-- One installation-level offer, shared by standalone KASC and VASC.
local M={}
function M.attach(session,ownerMod)
 if session.__ascendantStartupOnce then return end
 session.__ascendantStartupOnce=true
 if not session.startupPrompts then
  -- Updated KASC may share a session owned by an older VASC package.
  local owner=ownerMod or session.mod
  local policy=assert((loadstring or load)(assert(owner:read('lib/StartupPrompts.lua'))))()
  session.startupPrompts=policy.new(session.cache)
  session.promptDisabled=not session.startupPrompts:due('downloads',session.promptDisabled)
  session.onboardingShown=session.promptDisabled
  local offer=session.offer
  function session:offer(...)
   local menu=offer(self,...)
   if menu then self.onboardingShown=true;self.promptDisabled=true;self.startupPrompts:mark('downloads')end
   return menu
  end
 end
 -- Older KASC must not add its per-process reminder over the new session.
 session.__kascStartupOfferV2=true
 local update=session.update
 function session:update(game,dt,...)
  local requested=self.offerRequested
  self.offerRequested=true -- suppress legacy inventory-triggered startup branch
  local ok,err=pcall(update,self,game,dt,...)
  self.offerRequested=requested
  if not ok then error(err,0)end
  if self.promptDisabled or self.onboardingShown or self.offerRequested
    or (self.offerStable or 0)<0.5
    or not self.startupPrompts:due('downloads') then return end
  -- Show the introduction once even if all optional files are installed.
  self.offerRequested=true
  local success,page=pcall(require('src.ui.Screens').push,game,self.offerScreenId)
  if not success or not page then self.offerRequested=false end
 end
end
return M
