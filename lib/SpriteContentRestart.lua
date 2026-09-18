-- One mandatory, save-aware restart after the complete content operation.
-- Never bypass the engine save lifecycle or restart while a battle/script runs.
local M={}
function M.new(d)
 local self={phase='idle',changed=false,remaining=3}
 function self:installed()self.changed=true end
 local function context(game)
  local stack=game and game.stack
  if not stack or not stack.top then return end
  local top=stack:top();local world=false
  for _,state in ipairs(stack.states or {})do
   if state==game.overworld then world=true end
   if state.isBattle then return end
  end
  if game.phase=='play'and game.world then world=true end
  if not world then
   for _,state in ipairs(stack.states or {})do
    if state.screenId=='TitleState' or state.screenId=='Gen2MainMenu'then return true,false end
   end
   return -- Unknown/intro state: do not mistake it for the title menu.
  end
  if top and top~=game.overworld and not top.ascendantContentInventory
   and not top.ascendantContentRestart then return end
  local surface=game.overworld
  if game.phase=='play'and game.world then surface=nil end
  if d.worldSafe(game,surface)then return true,true end
 end
 function self:retry()
  if self.phase=='save_error'or self.phase=='restart_error'then
   self.phase='countdown';self.remaining=1
  end
 end
 function self:update(game,dt,complete,busy)
  if self.phase=='idle'then
   if not self.changed or not complete or busy then return end
   self.phase='waiting'
  end
  if self.phase=='waiting'then
   if busy then return end
   local safe,inGame=context(game)
   if not safe then return end
   self.inGame=inGame;self.phase='countdown';self.remaining=3
  end
  d.show(game,self)
  if self.phase=='countdown'then
   self.remaining=math.max(0,self.remaining-math.min(dt or 0,.1))
   if self.remaining==0 then self.phase=self.inGame and 'saving'or'restarting'end
  elseif self.phase=='saving'then
   local ok,saved=pcall(function()return game:writeSave()end)
   if not ok or saved~=true then self.phase='save_error';return end
   self.saved=true;self.phase='restarting'
  elseif self.phase=='restarting'then
   self.phase='restarted' -- Never send multiple restart requests.
   local ok,result=pcall(function()return game:restartWithMods()end)
   if not ok or result==false then self.phase='restart_error'end
  end
 end
 return self
end
return M
