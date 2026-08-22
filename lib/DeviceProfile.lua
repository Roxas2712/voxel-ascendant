-- Persistent device profiles for the expensive, non-compositional parts of
-- the renderer. AUTO is resolved locally; CUSTOM never rewrites child rows.

local V = ...
local ModSetting = V.require("ModSetting")

local DeviceProfile = {}

DeviceProfile.KEY = "deviceProfile"
DeviceProfile.LABEL = "DEVICE"
DeviceProfile.setting = ModSetting.new(
  DeviceProfile.KEY, DeviceProfile.LABEL,
  { "auto", "max", "handheld", "eco", "custom" },
  { "AUTO", "PC/MAX", "HANDHELD", "ECO", "CUSTOM" }, "auto")

local bindings = {}
local applying = false

local function modId()
  return (V.mod and V.mod.id) or "VOXEL_ASCENDANT"
end

local function bucket(game)
  local id = modId()
  local opts = game and game.save and game.save.options
  if opts then
    opts.modOptions = opts.modOptions or {}
    opts.modOptions[id] = opts.modOptions[id] or {}
  end
  local loader = game and game.mods
  if loader then
    loader.modOptions = loader.modOptions or {}
    loader.modOptions[id] = loader.modOptions[id] or {}
  end
  return opts and opts.modOptions[id], loader and loader.modOptions[id]
end

local function rawStore(game, setting, value)
  setting:sync(value)
  local save, loader = bucket(game)
  if save then save[setting.key] = value end
  if loader then loader[setting.key] = value end
end

function DeviceProfile.resolve(value)
  if value ~= "auto" then return value end
  -- Reuse the engine's public AUTO detector instead of probing LÖVE here.
  -- That keeps one device policy for the whole game (including ARM Linux
  -- handhelds and low-core desktops) and avoids a raw platform API in a mod.
  local ok, Performance = pcall(require, "src.core.Performance")
  local tier
  if ok and type(Performance) == "table"
     and type(Performance.detect) == "function" then
    local detected, got = pcall(Performance.detect)
    if detected then tier = got end
  end
  if tier == "low" then return "eco" end
  if tier == "balanced" then return "handheld" end
  return "max"
end

function DeviceProfile.configure(list)
  bindings = list or {}
  for _, binding in ipairs(bindings) do
    binding.setting:onChange(function(game)
      DeviceProfile.markCustom(game)
    end)
  end
  DeviceProfile.setting:onChange(function(game, value)
    DeviceProfile.apply(game, value)
  end)
end

function DeviceProfile.apply(game, selected)
  selected = selected or DeviceProfile.setting:get()
  local effective = DeviceProfile.resolve(selected)
  if effective == "custom" then return true, effective end
  applying = true
  for _, binding in ipairs(bindings) do
    local value = binding[effective]
    if value ~= nil then rawStore(game, binding.setting, value) end
  end
  applying = false
  if game and game.writeOptions then pcall(game.writeOptions, game) end
  return true, effective
end

function DeviceProfile.markCustom(game)
  if applying or DeviceProfile.setting:get() == "custom" then return false end
  rawStore(game, DeviceProfile.setting, "custom")
  if game and game.writeOptions then pcall(game.writeOptions, game) end
  return true
end

-- On an upgrade, preserve an existing hand-tuned collection rather than
-- silently treating it as the new AUTO preset. A genuinely new/default save
-- with no child values receives AUTO.
function DeviceProfile.restore(game, created)
  local save = bucket(game)
  local stored = save and save[DeviceProfile.KEY]
  if stored == nil and not created then
    local hasChild = false
    for _, binding in ipairs(bindings) do
      if save and save[binding.setting.key] ~= nil then hasChild = true break end
    end
    if hasChild then
      rawStore(game, DeviceProfile.setting, "custom")
      if game and game.writeOptions then pcall(game.writeOptions, game) end
      return true, "custom"
    end
  end
  DeviceProfile.setting:sync(stored or "auto")
  return DeviceProfile.apply(game, DeviceProfile.setting:get())
end

function DeviceProfile.externalChanged(game, key, value)
  if key == DeviceProfile.KEY then
    DeviceProfile.setting:sync(value)
    return DeviceProfile.apply(game, DeviceProfile.setting:get())
  end
  for _, binding in ipairs(bindings) do
    if key == binding.setting.key then
      binding.setting:sync(value)
      DeviceProfile.markCustom(game)
      return true
    end
  end
  return false
end

function DeviceProfile.effective()
  return DeviceProfile.resolve(DeviceProfile.setting:get())
end

function DeviceProfile.row()
  local row = DeviceProfile.setting:row()
  local base = row.value
  row.value = function()
    local value = base()
    if DeviceProfile.setting:get() == "auto" then
      return value .. "/" .. string.upper(DeviceProfile.effective())
    end
    return value
  end
  return row
end

return DeviceProfile
