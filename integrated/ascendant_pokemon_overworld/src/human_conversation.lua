-- Exact ownership adapter for explicit world.talk calls. The caller limits
-- use to admitted actors/hosts; this does not authorize arbitrary modal poses.
local M={}
local unpack=table.unpack or unpack
local function pack(...)return {n=select('#',...),...}end
function M.new(game)
 local stack=assert(game.stack);local original=assert(stack.push)
 local current;local closed=false;local boxes=setmetatable({},{__mode='k'})
 local function valid(s)
  return s and s.map~=nil and s.player~=nil and not closed and game.save==s.save
   and (game.overworld==s.world or game.world==s.world)
   and s.world.map==s.map and s.world.player==s.player
   and s.sprite~=nil and s.actor.sprite==s.sprite and s.sprite.def==s.def
   and (not s.def or (s.def.ascendantAtlasImage==s.atlas and s.def.ascendantRole==s.role and s.def.ascendantCharacterAction==s.action))
   and s.actor.px==s.px and s.actor.py==s.py
   and not s.actor.moving and not s.actor.scriptedMoving
 end
 local function runnerMatches(s)
  local runner=s.world.runner
  if type(runner)~='table' or type(runner.ctx)~='table' or runner.ctx.npc~=s.actor then return false end
  if s.ctx and (s.ctx~=runner.ctx or s.co~=runner.co)then return false end
  return runner
 end
 local function pushed(self,box,...)
  local result=pack(original(self,box,...))
  local s=current
  if self==stack and valid(s) and box and box.isTextBox==true then
   local runner=runnerMatches(s)
   if runner and coroutine.running()==runner.co then
    s.ctx,s.co=runner.ctx,runner.co;boxes[box]=s
   elseif not s.ctx then
    -- Plain extracted map text is pushed synchronously by world.talk and
    -- has no ScriptRunner coroutine. The dynamic world.talk scope still
    -- proves the exact actor and box; later overlays never pass this branch.
    s.direct=true;s.box=box;boxes[box]=s
   end
  end
  return unpack(result,1,result.n)
 end
 stack.push=pushed
 local api={}
 function api:reset()
  if current~=nil then current=nil;boxes=setmetatable({},{__mode='k'})end
 end
 function api:talk(world,actor,nextFn,...)
  self:reset()
  if not closed and type(world)=='table' and type(actor)=='table' and type(actor.sprite)=='table' then
   local def=actor.sprite and actor.sprite.def
   current={world=world,map=world.map,player=world.player,save=game.save,
    actor=actor,sprite=actor.sprite,px=actor.px,py=actor.py,def=def,
    atlas=def and def.ascendantAtlasImage,role=def and def.ascendantRole,action=def and def.ascendantCharacterAction}
  end
  local result=pack(pcall(nextFn,...))
  if not result[1] then self:reset();error(result[2],0)end
  if current then
   local runner=valid(current) and runnerMatches(current)
   if runner then current.ctx,current.co=runner.ctx,runner.co
   elseif not (current.direct and current.box and boxes[current.box]==current and valid(current))then self:reset()end
  end
  return unpack(result,2,result.n)
 end
 function api:owns(world,actor,box)
  local s=current
  if not s then return false end
  if not valid(s) then self:reset();return false end
  if s.world~=world or s.actor~=actor or boxes[box]~=s or actor.frozen~=true then return false end
  if s.direct then
   local ok,top=pcall(stack.top,stack)
   if not ok or top~=box then self:reset();return false end
   return true
  end
  local runner=runnerMatches(s)
  if not runner or type(runner.isRunning)~='function' then return false end
  local ok,running=pcall(runner.isRunning,runner)
  return ok and running==true
 end
 function api:participants(world,box)
  local s=current
  if not s or not self:owns(world,s.actor,box)then return end
  return s.actor,s.player
 end
 function api:close()
  closed=true;self:reset()
  if stack.push==pushed then stack.push=original end
 end
 return api
end
return M
