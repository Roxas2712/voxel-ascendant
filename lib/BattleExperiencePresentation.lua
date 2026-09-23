-- Cosmetic experience only: the engine retains rewards, levels and input.
local M = {}
local states = setmetatable({}, {__mode='k'})
local source, soundUnavailable
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
function M.update(owner, mon, dt, expForLevel, cap)
  if not mon then states[owner]=nil; return end
  local level=tonumber(mon.level) or 1
  cap=cap or 100
  local target=tonumber(mon.exp) or expForLevel(level)
  local s=states[owner]
  if not s or s.mon~=mon or target<s.target then
    s={mon=mon,level=level,shown=target,target=target,clock=0}
    states[owner]=s
  end
  s.target=target
  dt=clamp(tonumber(dt) or 0,0,.1)
  local before=s.shown
  -- Fill the old level completely before crossing into the next one. The
  -- engine may commit several levels before another presentation update.
  local budget=dt*math.max(1.25,math.min(12,(level-s.level)*2))
  while budget>0 and s.level<cap do
    local lo,hi=expForLevel(s.level),expForLevel(s.level+1)
    local span=math.max(1,hi-lo)
    local goal=math.min(target,hi)
    local cost=math.max(0,goal-s.shown)/span
    local used=math.min(budget,cost)
    s.shown=math.min(goal,s.shown+used*span)
    budget=budget-used
    if s.shown>=hi-.00001 and level>s.level then
      s.level=s.level+1
    else break end
  end
  if s.level>=cap then s.shown=target end
  s.moving=s.shown>before+.00001
  s.clock=s.clock+dt
  return s
end
function M.ratio(owner, fallback)
  local s=states[owner]
  return s and s.ratio or fallback
end
function M.advance(owner,mon,dt,expForLevel,cap)
  local s=M.update(owner,mon,dt,expForLevel,cap)
  if not s then return end
  local lo,hi=expForLevel(s.level),expForLevel(math.min(cap or 100,s.level+1))
  s.ratio=s.level>=(cap or 100) and 1 or clamp((s.shown-lo)/math.max(1,hi-lo),0,1)
  return s
end
-- A short synthesized fill pulse, independent of move/music channels. No
-- loop survives a menu, battle exit or mute; the sound is allocated once.
function M.sound(owner,volume)
  local s=states[owner]
  if not s or not s.moving or s.clock<.08 or volume<=0 then return end
  s.clock=0
  if soundUnavailable or not(love and love.sound and love.audio) then return end
  if not source then
    local ok,value=pcall(function()
      local rate,n=22050,1323
      -- Stereo UI audio stays on the main output pair. A mono Source can be
      -- spatialized onto other device channels by OpenAL (as with native SFX).
      local data=love.sound.newSoundData(n,rate,16,2)
      for i=0,n-1 do
        local t=i/rate
        local envelope=math.min(1,i/80)*math.max(0,1-i/n)
        local sample=math.sin(t*math.pi*2*880)*envelope*.28
        data:setSample(i,1,sample);data:setSample(i,2,sample)
      end
      local out=love.audio.newSource(data,'static');data:release();return out
    end)
    if not ok then soundUnavailable=true;return end
    source=value
  end
  source:setVolume(clamp(volume,0,1));source:setPitch(1+s.ratio*.4);source:play()
end
return M
