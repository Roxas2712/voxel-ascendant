-- Gen1Recomp renamed its final-frame effects API in 0.2.22: the fixed
-- GBCFX ladder disappeared and the two-slot ShaderFX preset runner replaced
-- it. VASC owns the finished world presentation, so either engine effect has
-- to be held off without making either engine generation a hard dependency.

local EngineFxCompat = {}

local resolved = false
local kind, engineFx

local function resolve()
  if resolved then return kind, engineFx end
  resolved = true

  local okLegacy, legacy = pcall(require, "src.render.GBCFX")
  if okLegacy and type(legacy) == "table"
     and type(legacy.setLevel) == "function" then
    kind, engineFx = "gbcfx", legacy
    return kind, engineFx
  end

  local okCurrent, current = pcall(require, "src.render.ShaderFX")
  if okCurrent and type(current) == "table"
     and type(current.deactivate) == "function" then
    kind, engineFx = "shaderfx", current
    return kind, engineFx
  end

  kind, engineFx = "none", nil
  return kind, engineFx
end

function EngineFxCompat.kind()
  return resolve()
end

-- Returns true only when the persisted legacy value changed. ShaderFX preset
-- names remain saved while VASC is active, so disabling VASC restores the
-- player's two selected presets rather than silently erasing them.
function EngineFxCompat.disable(opts)
  local changed = false
  if opts and (tonumber(opts.gbcfx) or 0) ~= 0 then
    opts.gbcfx = 0
    changed = true
  end

  local mode, api = resolve()
  if mode == "gbcfx" then
    pcall(api.setLevel, 0)
  elseif mode == "shaderfx" then
    -- A nil slot deliberately deactivates both current-engine slots.
    pcall(api.deactivate)
  end
  return changed
end

-- Remove every historical/current row. Engines expose only the ids they own,
-- so applying the complete list is harmless across both generations.
EngineFxCompat.ROW_IDS = { "gbcfx", "shaderfx", "shaderfx2" }

return EngineFxCompat
