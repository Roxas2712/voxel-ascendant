-- Smart world-space anchors for Gen-2 battle effects.
--
-- The battle arena owns the horizontal positions.  This module adds a stable
-- vertical profile derived from the Pokemon's rendered world height, so move
-- effects can aim at the body instead of sharing one hard-coded Y coordinate.
-- It contains no battle rules and is intentionally usable by the Lua QA
-- harness without LÖVE or a ROM.
local M = {}

local function finite(value, fallback)
  value = tonumber(value)
  if value == nil or value ~= value or value == math.huge
      or value == -math.huge then
    return fallback
  end
  return value
end

local function clamp(value, low, high)
  if value < low then return low end
  if value > high then return high end
  return value
end

local function point(x, y, z)
  return { x, y, z }
end

-- Build all useful anchors in the same world-pixel coordinate system used by
-- Stadium and BattleScene.  The minimum grow factor prevents an attack queued
-- immediately after send-out from collapsing its target back into the floor.
function M.profile(x, z, groundY, worldHeight, worldRadius, growScale, source)
  x = finite(x, 0)
  z = finite(z, 0)
  groundY = finite(groundY, 0)
  local height = clamp(finite(worldHeight, 18), 6, 48)
  local grow = clamp(finite(growScale, 1), 0.65, 1)
  height = height * grow
  local radius = clamp(finite(worldRadius, height * 0.24), 2.25, 18)
  local floor = groundY + math.max(0.55, height * 0.035)

  return {
    x = x,
    z = z,
    groundY = groundY,
    height = height,
    radius = radius,
    source = source or "fallback",
    ground = point(x, floor, z),
    low = point(x, groundY + height * 0.27, z),
    body = point(x, groundY + height * 0.52, z),
    emitter = point(x, groundY + height * 0.64, z),
    head = point(x, groundY + height * 0.81, z),
    top = point(x, groundY + height * 0.96, z),
  }
end

function M.point(profile, kind)
  if type(profile) ~= "table" then return nil end
  kind = tostring(kind or "body")
  local value = profile[kind] or profile.body
  if type(value) ~= "table" then return nil end
  return { finite(value[1], profile.x or 0),
           finite(value[2], profile.groundY or 0),
           finite(value[3], profile.z or 0) }
end

-- Fire Spin and other enclosing effects need the whole target silhouette,
-- not just one point.  Keep the lower edge visibly above the map and scale the
-- cage radius with the actual footprint while retaining sane fallback bounds.
function M.cage(profile)
  if type(profile) ~= "table" then
    profile = M.profile(0, 0, 0, 18, 4.5, 1, "fallback")
  end
  local ground = M.point(profile, "ground")
  local height = clamp(finite(profile.height, 18), 6, 48)
  return {
    base = ground[2] + math.max(0.35, height * 0.025),
    span = height * 0.92,
    center = M.point(profile, "body"),
    radius = clamp(finite(profile.radius, height * 0.24) * 1.32, 3.4, 10.5),
  }
end

return M
