-- Safe Gen-2 Mod Manager persistence bridge.
--
-- v0.2.55/v0.2.56 patched ManagerState globally and also called Gold's
-- Game2:persistOptions after every mod-option change. That solved one old
-- persistence seam, but it was too invasive: it touched every mod and shared
-- ManagerState persistence paths that also own enable/disable/profile state.
--
-- v0.2.64 narrows the patch to ONE thing only:
--   when THIS mod changes one option, mirror that one key into the top-level
--   options.lua modOptions bucket that Loader restores on the next boot.
--
-- It deliberately does NOT patch ManagerState:persistOptions, does NOT replace
-- game.options, does NOT call Game2:persistOptions, and never writes another
-- mod's option bucket. Loader/ManagerState remain the owners of enable state,
-- profiles, restart staging and the live value/event path.

local V = ...
local mod = V and V.mod
local MOD_ID = (mod and mod.id) or "VASC4J"

local M = {
  installed = false,
  writes = 0,
  migrations = 0,
  failures = 0,
  lastError = nil,
}

local function loadSaveData()
  local ok, SaveData = pcall(require, "src.core.SaveData")
  if ok and type(SaveData) == "table" then return SaveData end
  return nil
end

local function loadWholeOptions()
  local SaveData = loadSaveData()
  if not (SaveData and type(SaveData.loadOptions) == "function") then
    return nil, nil, "SaveData.loadOptions unavailable"
  end
  local ok, file = pcall(SaveData.loadOptions)
  if not ok then return nil, SaveData, tostring(file) end
  if type(file) ~= "table" then file = {} end
  return file, SaveData
end

local function saveWholeOptions(SaveData, file)
  if not (SaveData and type(SaveData.saveOptions) == "function") then
    return false, "SaveData.saveOptions unavailable"
  end
  local ok, result, err = pcall(SaveData.saveOptions, file)
  if not ok then return false, tostring(result) end
  if result == false then
    return false, tostring(err or "SaveData.saveOptions returned false")
  end
  return true
end

local function writeTopLevel(modId, key, value)
  if modId ~= MOD_ID then return true end
  if type(key) ~= "string" or key == "" then return false, "invalid option key" end

  local file, SaveData, loadErr = loadWholeOptions()
  if not file then return false, loadErr end

  file.modOptions = type(file.modOptions) == "table" and file.modOptions or {}
  local bucket = type(file.modOptions[MOD_ID]) == "table"
    and file.modOptions[MOD_ID] or {}
  file.modOptions[MOD_ID] = bucket
  bucket[key] = value

  return saveWholeOptions(SaveData, file)
end

-- Recover values that v0.2.55 may have written into Gold's nested option block,
-- but only fill keys that do not already exist in the loader's canonical
-- top-level bucket. This is read/merge-only with respect to other settings.
local function migrateNestedGold(manager)
  local game = manager and manager.game
  local gold = game and (game.options or (game.save and game.save.options))
  local nested = gold and gold.modOptions and gold.modOptions[MOD_ID]
  if type(nested) ~= "table" then return true end

  local file, SaveData, loadErr = loadWholeOptions()
  if not file then return false, loadErr end
  file.modOptions = type(file.modOptions) == "table" and file.modOptions or {}
  local top = type(file.modOptions[MOD_ID]) == "table"
    and file.modOptions[MOD_ID] or {}
  file.modOptions[MOD_ID] = top

  local changed = false
  for key, value in pairs(nested) do
    if top[key] == nil then
      top[key] = value
      changed = true
    end
  end

  if changed then
    local ok, err = saveWholeOptions(SaveData, file)
    if not ok then return false, err end
    M.migrations = M.migrations + 1
  end

  local loader = game and game.mods
  if loader then
    loader.modOptions = loader.modOptions or {}
    loader.modOptions[MOD_ID] = loader.modOptions[MOD_ID] or {}
    for key, value in pairs(top) do
      if loader.modOptions[MOD_ID][key] == nil then
        loader.modOptions[MOD_ID][key] = value
      end
    end
  end
  return true
end

function M.install()
  if M.installed then return true end

  local ok, ManagerState = pcall(require, "src.mods.ManagerState")
  if not (ok and type(ManagerState) == "table") then
    return false, "src.mods.ManagerState unavailable"
  end
  if ManagerState._stadium2PersistencePatchedV264 then
    M.installed = true
    return true
  end
  if type(ManagerState.setOption) ~= "function" then
    return false, "ManagerState.setOption unavailable"
  end

  -- Migrate only when THIS mod's options are opened.
  if type(ManagerState.openOptions) == "function" then
    local nativeOpen = ManagerState.openOptions
    ManagerState.openOptions = function(self, m, ...)
      if m and m.id == MOD_ID then
        local okMigration, migrated, err = pcall(migrateNestedGold, self)
        if not okMigration then
          M.failures = M.failures + 1
          M.lastError = tostring(migrated)
        elseif migrated == false then
          M.failures = M.failures + 1
          M.lastError = tostring(err)
        end
      end
      return nativeOpen(self, m, ...)
    end
  end

  local nativeSetOption = ManagerState.setOption
  ManagerState.setOption = function(self, modId, key, value, ...)
    local result = nativeSetOption(self, modId, key, value, ...)

    -- Do not touch any other mod and do not touch enable/profile persistence.
    if modId == MOD_ID then
      local okWrite, err = writeTopLevel(modId, key, value)
      if okWrite then
        M.writes = M.writes + 1
        M.lastError = nil
      else
        M.failures = M.failures + 1
        M.lastError = tostring(err)
      end
    end
    return result
  end

  ManagerState._stadium2PersistencePatchedV264 = true
  M.installed = true
  return true
end

M.writeTopLevel = writeTopLevel
M.migrateNestedGold = migrateNestedGold

function M.status()
  return {
    installed = M.installed,
    writes = M.writes,
    migrations = M.migrations,
    failures = M.failures,
    lastError = M.lastError,
    modId = MOD_ID,
    globalPersistPatch = false,
  }
end

return M
