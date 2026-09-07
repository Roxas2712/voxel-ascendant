-- Startup notice only: fetch a catalog, never begin a payload download.
-- Decisions belong to the installation cache, not a particular game save.
local M={}
local KEY="hd-content/offers-v1.txt"
local function idOK(id)
  return type(id)=="string" and id:match("^apo%.pokemon%-hd%.g%d%d%.dex%d%d%d%d%-%d%d%d%d$")
end
local function idleInput(game)
  local input=game.input
  if not input or type(input.isDown)~="function"then return false end
  for _,key in ipairs({"a","b","start","select","up","down","left","right"})do
    if input:isDown(key)then return false end
  end
  return true
end
local function worldSafe(game,top)
  -- Native Gen2 keeps its world below an empty menu stack and exposes its
  -- own menu-input gate, including script VM, field move and warp blocking.
  if top==nil and game.phase=="play"then
    local w=game.world
    return type(w)=="table" and w.map~=nil and w.player~=nil
      and not w.player.moving and type(w.acceptsMenuInput)=="function"
      and w:acceptsMenuInput()==true and idleInput(game) or false
  end
  -- Gen1 has no equivalent public predicate. Only the actual native world
  -- owner qualifies. Mirror its scripted-input and early-animation holds,
  -- additionally deferring queued/parallel scripts and all player motion.
  local w=top
  if type(w)~="table" or not w.isOverworld or w~=game.overworld
    or not w.map or not w.player or not w.runner
    or type(w.runner.isRunning)~="function"then return false end
  if w.runner:isRunning() or w.player.moving or w.player.inputLocked
    or w.player.spinning or (w.player.hopFrames or 0)>0
    or (w.hopLand or 0)>0 then return false end
  for _,key in ipairs({"transitioning","engaging","emote","teleportOut",
    "flyFade","flyAnim","flyArrive","spinArrive","holeFall","holeArrive",
    "pikaHop","healAnim","shipAnim","cutAnim","fishPose","dustAnim"})do
    if w[key]then return false end
  end
  for _,key in ipairs({"scriptMoves","pendingScripts","parallelRunners"})do
    if type(w[key])=="table" and next(w[key])~=nil then return false end
  end
  return idleInput(game)
end
function M.safe(game)
  if type(game)~="table"then return false end
  local stack=type(game)=="table" and game.stack
  local top=stack and type(stack.top)=="function" and stack:top()
  if worldSafe(game,top)then return true end
  if type(top)~="table" then return false end
  if top.screenId=="Gen2MainMenu" then return top.phase=="menu" end
  -- Gen1's choice menu is above the native TitleState. Never interrupt the
  -- logo cinematic, Continue confirmation, battle, text, naming or options.
  local states=stack.states
  local parent=type(states)=="table" and states[#states-1]
  return type(parent)=="table" and parent.screenId=="TitleState"
    and type(parent.onNewGame)=="function" and type(top.titleUiBox)=="table"
    and type(top.items)=="table" and #top.items>=2 or false
end
function M.new(deps)
  local d,cache=assert(deps.downloader),assert(deps.cache)
  local self={seen={},attempted=false,open=false,stable=0,state="waiting"}
  local ok,raw=pcall(cache.read,cache,KEY)
  if ok and type(raw)=="string" and #raw<=16384 and raw:sub(1,13)=="VASC-OFFER-1\n" then
    for id,revision in raw:gmatch("(apo%.pokemon%-hd%.g%d%d%.dex%d%d%d%d%-%d%d%d%d)=(%d+)\n")do
      local n=tonumber(revision)
      if n and n>=1 and n<=2147483647 then self.seen[id]=math.max(self.seen[id] or 0,n)end
    end
  end
  local function remember(packages)
    for _,p in ipairs(packages)do self.seen[p.id]=math.max(self.seen[p.id] or 0,p.revision)end
    local keys={};for id in pairs(self.seen)do keys[#keys+1]=id end;table.sort(keys)
    local lines={"VASC-OFFER-1\n"}
    for _,id in ipairs(keys)do lines[#lines+1]=id.."="..self.seen[id].."\n"end
    local bytes=table.concat(lines)
    local wrote,result=pcall(cache.write,cache,KEY,bytes)
    local readBack,stored=pcall(cache.read,cache,KEY)
    self.persisted=wrote and result and readBack and stored==bytes or false
  end
  function self:tick(game,dt)
    if self.closed then return end
    local safe=(deps.safe or M.safe)(game)
    self.stable=safe and self.stable+math.max(0,math.min(tonumber(dt) or 0,0.25)) or 0
    if self.ownCheck then
      if d.status=="checking"then d:update()end
      if d.status~="checking"then self.ownCheck=false end
    end
    if self.open or self.stable<0.5 or (deps.enabled and not deps.enabled())then return end
    if not self.attempted then
      if not d:configured()then self.state="unconfigured";return end
      self.attempted=true
      if (d.catalogChecks or 0)==0 and not d:busy()then
        self.ownCheck=d:check();self.state=self.ownCheck and "checking" or "unavailable"
        return
      end
    end
    if d:busy() or (d.catalogChecks or 0)==0 or d.status=="error"then return end
    local packages,bytes={},0
    for _,p in ipairs(d.catalog.packages)do
      if idOK(p.id) and p.revision>(self.seen[p.id] or 0) and not d:installed(p)then
        packages[#packages+1]={id=p.id,revision=p.revision};bytes=bytes+p.fileBytes
      end
    end
    if #packages==0 then self.state="up-to-date";return end
    self.open=true
    local decided=false
    local function decide()
      if decided then return end
      decided=true;remember(packages);self.open=false;self.state="acknowledged"
    end
    local pushed,menu=pcall(deps.show,game,{count=#packages,bytes=bytes,decide=decide})
    if not pushed or not menu then
      self.state="presentation-unavailable"
      -- No tight retry loop and no persisted acknowledgement on a UI failure.
      return
    end
    self.state="offered"
  end
  function self:close()self.closed=true end
  return self
end
return M
