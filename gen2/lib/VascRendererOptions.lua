-- Live synchronization for VASC controls exposed by the integrated Gen-2 schema.
local C = ...
local mod = C and C.mod
local BaseV = C and C.BaseV

local M = {
  installed = false,
  syncs = 0,
  lastKey = nil,
  lastError = nil,
}

local profileConfigured = false
local module
local liveGame = nil

local function currentGame()
  if type(liveGame) == "table" then return liveGame end
  local world = mod and mod.world
  if type(world) == "table" and type(world.game) == "table" then
    return world.game
  end
  if type(world) == "table" and type(world.game) == "function" then
    local ok, value = pcall(world.game, world)
    if ok and type(value) == "table" then return value end
  end
  local ok, Game = pcall(require, "src.core.Game2")
  return ok and type(Game) == "table" and Game.world and Game or nil
end

local function configureProfile()
  if profileConfigured then return end
  local profile = module("DeviceProfile")
  if not (profile and type(profile.configure) == "function") then return end
  local sky, events, weather = module("Sky"), module("SkyEvents"), module("Weather")
  local scenery, shadows = module("HorizonWall"), module("Shadows")
  local water, aa, daytime = module("Water"), module("AntiAlias"), module("DayNight")
  local quality = module("Quality")
  profile.configure({
    { setting = sky and sky.setting,
      max = "full", handheld = "full", eco = "flat" },
    { setting = sky and sky.cloudSetting,
      max = "on", handheld = "on", eco = "off" },
    { setting = events and events.setting,
      max = "full", handheld = "flyers", eco = "off" },
    { setting = weather and weather.setting,
      max = "auto", handheld = "auto", eco = "auto" },
    { setting = scenery and scenery.setting,
      max = "full", handheld = "full", eco = "full" },
    { setting = shadows and shadows.setting,
      max = true, handheld = true, eco = false },
    { setting = water and water.setting,
      max = "full", handheld = "sky", eco = "sky" },
    { setting = daytime and daytime.setting,
      max = "native", handheld = "native", eco = "native" },
    { setting = aa and aa.setting,
      max = 2, handheld = 0, eco = 0 },
    { setting = quality and quality.setting,
      max = 1, handheld = 2, eco = 3 },
    { setting = quality and quality.shadowSetting,
      max = "high", handheld = "low", eco = "off" },
  })
  profileConfigured = true
end

module = function(name)
  if not (BaseV and type(BaseV.require) == "function") then return nil end
  local ok, value = pcall(BaseV.require, name)
  if ok and type(value) == "table" then return value end
  return nil
end

local function syncSetting(setting, value)
  if setting and type(setting.sync) == "function" then
    local ok, err = pcall(setting.sync, setting, value)
    if ok then return true end
    M.lastError = tostring(err)
  end
  return false
end

local function syncModule(target, value)
  if target and type(target.sync) == "function" then
    local ok, err = pcall(target.sync, value)
    if ok then return true end
    M.lastError = tostring(err)
  end
  return false
end

local function syncKey(key, value)
  local changed = false
  if key == "grid" then
    local grid = module("VoxelGrid")
    changed = syncModule(grid, value)
  elseif key == "battleGrid" then
    local grid = module("VoxelGrid")
    changed = syncSetting(grid and grid.battleSetting, value)
  elseif key == "curve" then
    local curve = module("WorldCurve")
    changed = syncModule(curve, value)
  elseif key == "water" then
    local water = module("Water")
    changed = syncSetting(water and water.setting, value)
  elseif key == "aa" then
    local aa = module("AntiAlias")
    changed = syncSetting(aa and aa.setting, value)
  elseif key == "renderScale" then
    local quality = module("Quality")
    changed = syncSetting(quality and quality.setting, value)
  elseif key == "pokemonModelSkin" then
    local provider = module("PokemonModelProvider")
    changed = syncSetting(provider and provider.setting, value)
  elseif key == "shadowQuality" then
    local quality = module("Quality")
    changed = syncSetting(quality and quality.shadowSetting, value)
  elseif key == "weather" or key == "weatherMode" then
    local weather = module("Weather")
    changed = syncSetting(weather and weather.setting, value)
  elseif key == "sky" then
    local sky = module("Sky")
    changed = syncSetting(sky and sky.setting, value)
  elseif key == "clouds" or key == "weatherClouds" then
    local sky = module("Sky")
    changed = syncSetting(sky and sky.cloudSetting,
      type(value) == "boolean" and (value and "on" or "off") or value)
  elseif key == "skyEvents" then
    local events = module("SkyEvents")
    changed = syncSetting(events and events.setting, value)
  elseif key == "scenery" then
    local scenery = module("HorizonWall")
    changed = syncSetting(scenery and scenery.setting, value)
  elseif key == "daytime" then
    local daytime = module("DayNight")
    changed = syncSetting(daytime and daytime.setting, value)
  elseif key == "shadows" then
    local shadows = module("Shadows")
    changed = syncSetting(shadows and shadows.setting, value)
  elseif key == "deviceProfile" then
    configureProfile()
    local profile = module("DeviceProfile")
    changed = syncSetting(profile and profile.setting, value)
    if changed and profile and type(profile.apply) == "function" then
      pcall(profile.apply, currentGame(), value)
    end
  end
  if changed then
    M.syncs = M.syncs + 1
    M.lastKey = key
  end
  return changed
end

local KEYS = {
  "grid", "battleGrid", "curve", "water", "aa", "renderScale",
  "pokemonModelSkin",
  "shadowQuality", "sky", "clouds", "skyEvents", "weather", "scenery",
  "shadows", "daytime", "deviceProfile",
}
local PROFILE_CHILD = {
  sky=true, clouds=true, skyEvents=true, weather=true, scenery=true,
  shadows=true, shadowQuality=true, water=true, daytime=true, aa=true,
  renderScale=true,
}

local function read(key)
  if not (mod and mod.options and type(mod.options.get) == "function") then
    return nil
  end
  local ok, value = pcall(mod.options.get, mod.options, key)
  if ok then return value end
  return nil
end

function M.refresh()
  configureProfile()
  for _, key in ipairs(KEYS) do syncKey(key, read(key)) end
  return true
end

-- Shared direct-menu/event seam. Hub writes cannot emit the engine-owned
-- mod.options_changed event, so they call this same handler explicitly. In
-- particular, manual AA/SKY/WATER/etc changes must mark DEVICE as CUSTOM via
-- DeviceProfile.externalChanged instead of being overwritten by its old preset.
function M.handleOptionsChanged(payload)
  if type(payload) ~= "table" or type(payload.key) ~= "string" then return false end
  if payload.mod ~= nil and mod and payload.mod ~= mod.id then return false end
  local changed = syncKey(payload.key, payload.value)
  if changed and PROFILE_CHILD[payload.key] then
    local profile = module("DeviceProfile")
    if profile and type(profile.externalChanged) == "function" then
      pcall(profile.externalChanged, payload.game or currentGame(), payload.key,
            payload.value)
    end
  end
  return changed
end

function M.install()
  if M.installed then return true end
  M.refresh()
  if mod and mod.events and type(mod.events.on) == "function" then
    local ok, err = pcall(mod.events.on, mod.events, "mod.options_changed",
      M.handleOptionsChanged)
    if not ok then
      M.lastError = tostring(err)
      return false, M.lastError
    end
    pcall(mod.events.on, mod.events, "game.ready", function(payload)
      if type(payload) == "table" and type(payload.game) == "table" then
        liveGame = payload.game
      end
    end)
  end
  M.installed = true
  M.lastError = nil
  return true
end

function M.status()
  return {
    installed = M.installed,
    syncs = M.syncs,
    lastKey = M.lastKey,
    lastError = M.lastError,
  }
end

return M
