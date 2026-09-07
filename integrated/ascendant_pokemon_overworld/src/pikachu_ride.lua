-- Optional presentation only. Never changes entities or retains input tables.
local M = {}
local Ride = {}
Ride.__index = Ride

local UP, CARRY, DOWN = 0.45, 3, 0.45
local ARC, NEAR_SQUARED, TELEPORT_SQUARED = 4, 48 * 48, 32 * 32

local function finite(value)
  return type(value) == 'number' and value == value
    and value ~= math.huge and value ~= -math.huge
end

local function smooth(t)
  return t * t * (3 - 2 * t)
end

function M.new(options)
  options = options or {}
  local low = options.delayMin == nil and 24 or options.delayMin
  local high = options.delayMax == nil and 42 or options.delayMax
  assert(finite(low) and low >= 0, 'delayMin must be finite and nonnegative')
  assert(finite(high) and high >= low, 'delayMax must be finite and >= delayMin')
  assert(options.random == nil or type(options.random) == 'function', 'random must be a function')
  return setmetatable({delayMin=low, delayMax=high, random=options.random or math.random,
    state='inactive', reason='uninitialized'}, Ride)
end

function Ride:_reset(now, reason)
  self.startedAt, self.fromX, self.fromY, self.fromZ = nil, nil, nil, nil
  self.downX, self.downY, self.downZ = nil, nil, nil
  self.state, self.reason = 'cooldown', reason
  local ok, value = pcall(self.random)
  if not ok or not finite(value) then value = 0.5 end
  value = math.max(0, math.min(1, value))
  self.nextAt = now + self.delayMin + (self.delayMax - self.delayMin) * value
end

-- Input coordinates are world-space anchor positions, including the ordinary
-- follower presentation offset. Returned offsets are added to THAT sample's
-- follower position, not fed back into native movement/collision coordinates.
function Ride:sample(input)
  input = input or {}
  local now = input.now
  if not finite(now) then
    self.lastNow, self.nextAt, self.startedAt = nil, nil, nil
    self.lastX, self.lastY, self.lastZ, self.ready = nil, nil, nil, false
    self.worldKey, self.actorKey = nil, nil
    self.fromX, self.fromY, self.fromZ = nil, nil, nil
    self.downX, self.downY, self.downZ = nil, nil, nil
    self.state, self.reason = 'inactive', 'invalid-time'
    return nil
  end
  local valid = finite(input.playerX) and finite(input.playerY) and finite(input.playerZ)
    and finite(input.playerHeight) and input.playerHeight > 0
    and finite(input.followerX) and finite(input.followerY) and finite(input.followerZ)
    and input.worldKey ~= nil and input.actorKey ~= nil
  local ready = input.enabled == true and input.eligible == true and valid
  local reason
  if self.lastNow == nil then reason = 'first-sample'
  elseif now < self.lastNow then reason = 'clock-rewind'
  elseif now - self.lastNow > 0.5 then reason = 'pause-gap'
  elseif input.worldKey ~= self.worldKey then reason = 'world-change'
  elseif input.actorKey ~= self.actorKey then reason = 'actor-change'
  elseif ready ~= self.ready then reason = ready and 'eligible-again' or 'ineligible'
  elseif valid and self.lastX ~= nil then
    local x, y, z = input.playerX-self.lastX, input.playerY-self.lastY, input.playerZ-self.lastZ
    if x*x + y*y + z*z > TELEPORT_SQUARED then reason = 'player-teleport' end
  end
  self.lastNow, self.worldKey, self.actorKey, self.ready = now, input.worldKey, input.actorKey, ready
  self.lastX, self.lastY, self.lastZ = valid and input.playerX or nil,
    valid and input.playerY or nil, valid and input.playerZ or nil
  if reason then self:_reset(now, reason) end
  if not ready then
    self.state = 'inactive'
    return nil
  end
  -- Even delay=0 cannot start on a registration/reset sample.
  if reason then return nil end
  if not self.startedAt then
    if now < self.nextAt then return nil end
    local x, z = input.playerX-input.followerX, input.playerZ-input.followerZ
    -- Nearness is horizontal ground distance; player teleports above include Y.
    if x*x + z*z > NEAR_SQUARED then return nil end
    self.startedAt = now
    self.fromX, self.fromY, self.fromZ = input.followerX, input.followerY, input.followerZ
    self.reason = 'started'
  end

  -- Compare absolute deadlines: subtracting startedAt first can leave a sample
  -- exactly at a boundary in the previous phase through floating-point rounding.
  local upEnd = self.startedAt + UP
  local carryEnd = upEnd + CARRY
  local downEnd = carryEnd + DOWN
  local headX, headY, headZ = input.playerX, input.playerY + input.playerHeight - 0.6, input.playerZ
  local x, y, z
  if now < upEnd then
    self.state = 'jump-up'
    local t = (now-self.startedAt) / UP
    local s = smooth(t)
    x, z = self.fromX + (headX-self.fromX)*s, self.fromZ + (headZ-self.fromZ)*s
    y = self.fromY + (headY-self.fromY)*s + ARC*4*t*(1-t)
  elseif now < carryEnd then
    self.state = 'ride'
    x, y, z = headX, headY, headZ
  elseif now < downEnd then
    self.state = 'jump-down'
    if self.downX == nil then self.downX, self.downY, self.downZ = headX, headY, headZ end
    local t = (now-carryEnd) / DOWN
    local s = smooth(t)
    x, z = self.downX + (input.followerX-self.downX)*s, self.downZ + (input.followerZ-self.downZ)*s
    y = self.downY + (input.followerY-self.downY)*s + ARC*4*t*(1-t)
  else
    self:_reset(now, 'finished')
    return nil
  end
  return {dx=x-input.followerX, dy=y-input.followerY, dz=z-input.followerZ,
    state=self.state, forceIdle=true}
end

-- Fixed-size snapshot, no history, entity handles or mutable internal tables.
function Ride:health()
  return {state=self.state, reason=self.reason, active=self.startedAt ~= nil,
    nextAt=self.nextAt, startedAt=self.startedAt,
    cooldownRemaining=self.nextAt and self.lastNow and math.max(0, self.nextAt-self.lastNow) or nil}
end

return M
