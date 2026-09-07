-- Extra far-survey range for the Gold OPEN WORLD presentation.
--
-- DioramaZoom owns the 3D camera's continuous distance.  This module extends
-- the engine's separate integer survey ladder through the official zoom.range
-- hook, so Character Selector/native ZOOM users also get one whole-region rung
-- below the historical 1 screen-pixel/world-pixel floor.  Zoom.scale itself
-- keeps the hard safety floor at 0.25.
local V = ...
local mod = V and V.mod

local M = {
  installed = false,
  rangeCalls = 0,
  unwrap = nil,
  lastError = nil,
}

M.LIMITS = {
  standard = 2.20,
  far = 4.00,
  world = 8.00,
  extreme = 12.00,
}

local function option(key, fallback)
  local options = mod and mod.options
  if not (options and type(options.get) == "function") then return fallback end
  local ok, value = pcall(options.get, options, key)
  if not ok or value == nil then return fallback end
  return value
end

function M.mode()
  local value = tostring(option("worldZoomRange", "world")):lower()
  if M.LIMITS[value] then return value end
  return "world"
end

function M.dioramaMax()
  return M.LIMITS[M.mode()] or M.LIMITS.world
end

function M.openWorldEnabled()
  return option("openWorld", false) == true
end

function M.install()
  if M.installed then return true end
  if not (mod and mod.hooks and type(mod.hooks.wrap) == "function") then
    return false, "mod.hooks:wrap unavailable"
  end

  local ok, unwrap = pcall(function()
    return mod.hooks:wrap("zoom.range", function(next, lo, hi, S)
      lo, hi = next(lo, hi, S)
      M.rangeCalls = M.rangeCalls + 1
      -- Keep the engine's normal range unless OPEN WORLD is actually active.
      -- For the extended modes, offset=-S makes the raw effective scale zero;
      -- src.render.Zoom.scale then applies its documented 0.25 safety floor.
      -- This creates one extra whole-region OUT rung without changing integer
      -- stepping or option persistence.
      if M.openWorldEnabled() and M.mode() ~= "standard" then
        local fit = math.max(1, math.floor(tonumber(S) or 1))
        lo = math.min(math.floor(tonumber(lo) or (1 - fit)), -fit)
      end
      return lo, hi
    end)
  end)
  if not ok then
    M.lastError = tostring(unwrap)
    return false, M.lastError
  end
  M.unwrap = unwrap
  M.installed = true
  M.lastError = nil
  return true
end

function M.status()
  return {
    installed = M.installed,
    rangeCalls = M.rangeCalls,
    mode = M.mode(),
    dioramaMax = M.dioramaMax(),
    openWorld = M.openWorldEnabled(),
    lastError = M.lastError,
  }
end

return M
