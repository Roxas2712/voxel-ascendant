-- Persistent device profiles for the expensive, non-compositional parts of
-- the renderer. AUTO is resolved locally; CUSTOM never rewrites child rows.

local V = ...
local ModSetting = V.require("ModSetting")

local DeviceProfile = {}

DeviceProfile.KEY = "deviceProfile"
DeviceProfile.HARDWARE_KEY = "_deviceProfileHardwareV1"
DeviceProfile.LABEL = "DEVICE"
DeviceProfile.setting = ModSetting.new(
  DeviceProfile.KEY, DeviceProfile.LABEL,
  { "auto", "light", "balanced", "high", "ultra", "custom" },
  { "AUTO", "LIGHT", "BALANCED", "HIGH", "ULTRA", "CUSTOM" }, "auto")

local bindings = {}
local applying = false

local LEGACY_BINDING = {
  light="eco",
  balanced="handheld",
  high="max",
}

local function bindingValue(binding, effective)
  local value = binding[effective]
  if value == nil then value = binding[LEGACY_BINDING[effective]] end
  return value
end

local function cleanPart(value)
  value = tostring(value or "unknown"):lower()
  return value:gsub("[^%w%._%-]+", "_"):sub(1, 96)
end

function DeviceProfile.hardwareSignature()
  local ok, Performance = pcall(require, "src.core.Performance")
  if ok and type(Performance) == "table"
      and type(Performance.deviceSignature) == "function" then
    local got, value = pcall(Performance.deviceSignature)
    if got and value ~= nil then return cleanPart(value) end
  end
  local osName, cores, renderer, vendor, device = "unknown", 0,
    "unknown", "unknown", "unknown"
  local okSystem, system = pcall(function()
    local loveApi = rawget(_G, "love")
    return loveApi and loveApi.system or nil
  end)
  if okSystem and system then
    local got, value = pcall(system.getOS)
    if got and value then osName = value end
    got, value = pcall(system.getProcessorCount)
    if got and value then cores = value end
  end
  if osName == "unknown" then
    local okPlatform, Platform = pcall(require, "src.core.Platform")
    if okPlatform and type(Platform) == "table"
        and type(Platform.detect) == "function" then
      local got, info = pcall(Platform.detect)
      if got and type(info) == "table" and info.os then osName = info.os end
    end
  end
  if love and love.graphics and love.graphics.getRendererInfo then
    local got, a, _, c, d = pcall(love.graphics.getRendererInfo)
    if got then renderer, vendor, device = a or renderer, c or vendor, d or device end
  end
  local arch = jit and jit.arch or "unknown"
  return table.concat({ cleanPart(osName), cleanPart(arch), cleanPart(cores),
    cleanPart(renderer), cleanPart(vendor), cleanPart(device) }, ":")
end

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
    if loader.loader then
      loader.loader.modOptions = loader.loader.modOptions or {}
      loader.loader.modOptions[id] = loader.loader.modOptions[id] or {}
    end
  end
  return opts and opts.modOptions[id], loader and loader.modOptions[id],
         loader and loader.loader and loader.loader.modOptions[id]
end

local function rawStore(game, setting, value)
  setting:sync(value)
  local save, loader, nestedLoader = bucket(game)
  if save then save[setting.key] = value end
  if loader then loader[setting.key] = value end
  if nestedLoader then nestedLoader[setting.key] = value end
end

local function persistOptions(game)
  if game and type(game.writeOptions) == "function" then
    pcall(game.writeOptions, game)
  elseif game and type(game.persistOptions) == "function" then
    pcall(game.persistOptions, game)
  end
end

function DeviceProfile.resolve(value)
  value = ({ eco="light", handheld="balanced", max="high" })[value] or value
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
  if tier == "low" then return "light" end
  if tier == "balanced" then return "balanced" end
  return "high"
end

function DeviceProfile.configure(list)
  bindings = list or {}
  for _, binding in ipairs(bindings) do
    local setting = binding.setting
    local defaultIndex = setting and setting.defaultIndex or 1
    binding.profileDefault = binding.default
    if binding.profileDefault == nil then
      binding.profileDefault = setting and setting.values
        and setting.values[defaultIndex] or nil
    end
    binding.setting:onChange(function(game)
      DeviceProfile.markCustom(game, "setting:" .. tostring(binding.setting.key))
    end)
  end
  DeviceProfile.setting:onChange(function(game, value)
    DeviceProfile.apply(game, value)
  end)
end

function DeviceProfile.apply(game, selected)
  selected = selected or DeviceProfile.setting:get()
  selected = ({ eco="light", handheld="balanced", max="high" })[selected]
    or selected
  local effective = DeviceProfile.resolve(selected)
  if effective == "custom" then return true, effective end
  applying = true
  for _, binding in ipairs(bindings) do
    local value = bindingValue(binding, effective)
    if value ~= nil then rawStore(game, binding.setting, value) end
  end
  applying = false
  persistOptions(game)
  return true, effective
end

function DeviceProfile.markCustom(game, reason)
  if applying or DeviceProfile.setting:get() == "custom" then return false end
  DeviceProfile.lastCustomReason = tostring(reason or "manual")
  print("[VASC] device profile -> CUSTOM (" .. DeviceProfile.lastCustomReason .. ")")
  rawStore(game, DeviceProfile.setting, "custom")
  persistOptions(game)
  return true
end

-- CUSTOM is explicit state. Child rows can already contain AUTO's resolved
-- values before restore and therefore cannot identify manual tuning.
function DeviceProfile.restore(game, created)
  local save, loader, nestedLoader = bucket(game)
  local stores = { save, loader, nestedLoader }
  local stored
  local storedHardware
  for _, store in ipairs(stores) do
    if store and store[DeviceProfile.KEY] ~= nil then
      stored = store[DeviceProfile.KEY]
      break
    end
  end
  for _, store in ipairs(stores) do
    if store and store[DeviceProfile.HARDWARE_KEY] ~= nil then
      storedHardware = store[DeviceProfile.HARDWARE_KEY]
      break
    end
  end
  local hardware = DeviceProfile.hardwareSignature()
  if stored == "custom" and storedHardware ~= nil
      and storedHardware ~= hardware then
    stored = "auto"
  end
  stored = ({ eco="light", handheld="balanced", max="high" })[stored]
    or stored
  stored = stored or "auto"
  -- Persist AUTO explicitly. Schema-populated child defaults are not proof
  -- of a hand-tuned legacy installation.
  rawStore(game, DeviceProfile.setting, stored)
  for _, store in ipairs(stores) do
    if store then store[DeviceProfile.HARDWARE_KEY] = hardware end
  end
  return DeviceProfile.apply(game, DeviceProfile.setting:get())
end

function DeviceProfile.externalChanged(game, key, value)
  if key == DeviceProfile.KEY then
    value = ({ eco="light", handheld="balanced", max="high" })[value]
      or value
    DeviceProfile.setting:sync(value)
    return DeviceProfile.apply(game, DeviceProfile.setting:get())
  end
  for _, binding in ipairs(bindings) do
    if key == binding.setting.key then
      binding.setting:sync(value)
      local selected = DeviceProfile.setting:get()
      local expected = bindingValue(binding, DeviceProfile.resolve(selected))
      -- Ignore delayed host echoes of values written by the selected preset.
      -- A genuinely different child value still switches to CUSTOM below.
      if selected ~= "custom" and value == expected then return true end
      DeviceProfile.markCustom(game, "external:" .. tostring(key)
        .. "=" .. tostring(value) .. "/expected=" .. tostring(expected))
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
