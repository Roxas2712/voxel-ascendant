-- Exact, reversible chair placement for Red's mother. Animation updates once
-- in frame preparation, never in the shadow/colour draw passes.
local M={}
local path='assets/characters/acting/mother/'
local original='assets/characters/npcs/reds-mother-kasc-hd-4x3-walk-sheet-v2.png'
function M.new(options)
 local mod=assert(options.mod);local api={angle=0,loads=0,selected=0}
 local blinkState={}
 local breathStarted
 local resources={};local pose,source,attempted,last,actorIdentity,spriteIdentity,pending,sliceStart
 local function own(resource)
  resources[#resources+1]=resource
  -- Allocation boundaries are outside every graphics push/pop block.
  -- Heavy native decode/upload calls cannot yield internally, but subsequent
  -- work is spread over later frames instead of adding a single 70ms stall.
  if pending and love.timer.getTime()-sliceStart>=.002 then coroutine.yield()end
  return resource
 end
 local function release()
  for i=#resources,1,-1 do pcall(resources[i].release,resources[i]);resources[i]=nil end
  pose,source=nil,nil
 end
 function api:reset()
  breathStarted=nil;self.breathAmount=0;if source then source.seatedBreath=0 end
  self.angle=0;last=nil;actorIdentity=nil;spriteIdentity=nil;self.blinkAmount=0
  if options.idle then options.idle.blink(blinkState,0,false,.37)end
 end
 function api:retry()if not pose and not pending then attempted=nil;self.error=nil end;self:reset()end
 function api:restore()self:reset();pending=nil;release();attempted=nil end
 local function build()
  local ok,result=pcall(function()
   local Assets=require('src.render.Assets')
   local function image(name,w,h)
    local data=Assets.imageData(mod.path..'/'..path..name)
    assert(data and data:getWidth()==w and data:getHeight()==h,'seated atlas dimensions')
    return own(love.graphics.newImage(data))
   end
   local heads=image('heads.png',1536,1024)
   local layers=options.headLayers.new(heads,options.frames,own,true)
   local morph=options.headMorph.new(layers,function(name)return mod:read(path..name)end,own)
   local seat=image('seated.png',1024,1536)
   local built=options.seatLayers.new(seat,morph,own)
   -- The runtime layers now own the pixels they need.
   heads:release();seat:release()
   return built
  end)
  if not ok then api.error=tostring(result);release();return end
  pose=result;api.loads=api.loads+1
  local b={left=112,right=400,top=30,bottom=665,imageWidth=512,imageHeight=768}
  source={id=mod.path..'/'..path..'seated-v1',texture=pose.texture,bounds={},worldHeight=18,offsetY=-5,offsetZ=8}
  for r=0,3 do source.bounds[r]={};for c=0,2 do source.bounds[r][c]=b end end
 end
 function api:queue()
  if pose or attempted or pending then return end
  attempted=true;self.loadSeconds=0;self.peakSlice=0;self.loadSlices=0
  pending=coroutine.create(build)
 end
 function api:load()
  self:queue();if not pending then return end
  sliceStart=love.timer.getTime()
  local ok,err=coroutine.resume(pending)
  local elapsed=love.timer.getTime()-sliceStart
  self.loadSeconds=self.loadSeconds+elapsed;self.peakSlice=math.max(self.peakSlice,elapsed);self.loadSlices=self.loadSlices+1
  if not ok then self.error=tostring(err);pending=nil;release();return end
  if coroutine.status(pending)=='dead' then pending=nil end
 end
 function api:frame(game,world,conversation,now)
  if not world or not world.map or world.map.id~='REDS_HOUSE_1F' then self:reset();return end
  local mother
  for _,npc in pairs(world.npcs or {})do
   if npc.def and npc.def.name=='REDSHOUSE1F_MOM' then
    if mother then self:reset();return end
    mother=npc
   end
  end
  local def=mother and mother.sprite and mother.sprite.def
  if not def or def.ascendantAtlasImage~=mod.path..'/'..original
   or def.ascendantCharacterAction~=nil or mother.cellX~=5 or mother.cellY~=4
   or mother.px~=80 or mother.py~=64 or mother.moving or mother.scriptedMoving then self:reset();return end
  self:load();if not pose then return end
  if actorIdentity~=mother or spriteIdentity~=mother.sprite then
   self:reset();actorIdentity,spriteIdentity=mother,mother.sprite
  end
  local top=game.stack and game.stack:top()
  local talking=conversation and conversation:owns(world,mother,top)
  local target=0
  if talking then
   local dx=world.player.px-mother.px
   target=dx<0 and -1 or dx>0 and 1 or 0
  end
  local dt=last and math.min(.1,math.max(0,now-last))or 0;last=now
  if talking or (top and top.isOverworld)then
   self.angle=self.angle+(target-self.angle)*(1-math.exp(-dt*10))
   if math.abs(target-self.angle)<.002 then self.angle=target end
  else self.angle=0 end
  local resting=top and top.isOverworld and not world.emote
  if resting and world.runner and type(world.runner.isRunning)=='function' then
   local ok,running=pcall(world.runner.isRunning,world.runner)
   resting=ok and not running
  end
  local eligible=(talking or resting) and self.angle==target
  local breathing=talking or resting
  if breathing then
   breathStarted=breathStarted or now
   self.breathAmount=(1-math.cos((now-breathStarted)*math.pi*2/4.8))*.5
  else breathStarted=nil;self.breathAmount=0 end
  source.seatedBreath=self.breathAmount
  self.blinkAmount=options.idle and options.idle.blink(blinkState,now,eligible,.37)or 0
  local u=math.abs(self.angle);local middle,final=self.angle<0 and 5 or 2,self.angle<0 and 6 or 3
  if u<=.5 then pose:update(1,middle,u*2,self.blinkAmount)else pose:update(middle,final,(u-.5)*2,self.blinkAmount)end
  self.updates=pose.updates;self.selected=self.selected+1
  return mother.sprite,source
 end
 return api
end
return M
