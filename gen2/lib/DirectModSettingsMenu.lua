-- Direct pause-menu shortcut into THIS mod's ManagerState options page.
--
-- Gold exposes ui.start_menu.items specifically so mods can inject rows without
-- patching StartMenu.  This adds MOD SETTINGS immediately after OPTION and
-- opens the existing ManagerState options screen for Voxel Ascendant.
-- The ManagerState remains the sole owner of option persistence/events; this
-- module only changes how the player reaches it.

local V = ...
local mod = V and V.mod

local M = {
  installed = false,
  opens = 0,
  lastError = nil,
}

local function customUIEnabled()
  -- The legacy key is kept false only as an upgrade tombstone.  Current
  -- settings/menu presentation is controlled by the public skin options.
  return true
end

local function modId()
  return (mod and mod.id) or "VOXEL_ASCENDANT"
end

local function findCurrentMod(manager)
  local id = modId()
  local byId = manager and manager.byId
  if byId and byId[id] then return byId[id] end
  local status = manager and manager.status
  for _, entry in ipairs((status and status.available) or {}) do
    if entry.id == id then return entry end
  end
  return nil
end

local function openDirect(game)
  local okScreens, Screens = pcall(require, "src.ui.Screens")
  if not (okScreens and Screens and type(Screens.push) == "function") then
    M.lastError = "src.ui.Screens.push unavailable"
    return false
  end

  local okPush, manager = pcall(Screens.push, game, "ManagerState")
  if not okPush or type(manager) ~= "table" then
    M.lastError = "ManagerState push failed: " .. tostring(manager)
    return false
  end

  -- StateStack:push calls ManagerState:enter before Screens.push returns, so the
  -- status/byId tables should already be settled.  Refresh once defensively for
  -- minimal/test hosts that construct the state differently.
  if (not manager.byId or not manager.status) and type(manager.refresh) == "function" then
    pcall(manager.refresh, manager)
  end

  local target = findCurrentMod(manager)
  if not target then
    M.lastError = "this mod was not found in ManagerState"
    if type(manager.notify) == "function" then
      pcall(manager.notify, manager, "MOD SETTINGS UNAVAILABLE")
    end
    return false
  end
  if type(manager.openOptions) ~= "function" then
    M.lastError = "ManagerState.openOptions unavailable"
    return false
  end

  manager.currentMod = target
  local okOpen, openErr = pcall(manager.openOptions, manager, target)
  if not okOpen then
    M.lastError = "ManagerState.openOptions failed: " .. tostring(openErr)
    return false
  end

  if manager.screen ~= "options" then
    -- A malformed/missing schema is allowed to degrade to the ordinary manager
    -- instead of trapping the player on a broken custom screen.
    M.lastError = "this mod has no ManagerState options screen"
    return false
  end

  -- openOptions() normally records the MODS list in backStack.  Because this is
  -- a direct pause shortcut, B should return straight to START, not detour
  -- through MODS -> detail.  Leaving the stack state itself in place preserves
  -- all ManagerState option editing/persistence behavior.
  manager.backStack = {}
  manager._stadium2DirectModSettings = true
  manager._stadium2PauseSkinChain = true
  manager.isOpaque = false

  M.opens = M.opens + 1
  M.lastError = nil
  return true
end

local function alreadyPresent(items)
  for _, item in ipairs(items or {}) do
    if type(item) == "table" and item._stadium2DirectModSettings then
      return true
    end
  end
  return false
end

local function insertAfterOption(items, row)
  local out = {}
  local inserted = false
  for _, item in ipairs(items or {}) do
    out[#out + 1] = item
    if not inserted and type(item) == "table" and item.value == "option" then
      out[#out + 1] = row
      inserted = true
    end
  end
  if not inserted then out[#out + 1] = row end
  return out
end

function M.install()
  if M.installed then return true end
  if not (mod and mod.hooks and type(mod.hooks.wrap) == "function") then
    return false, "mod.hooks:wrap unavailable"
  end

  local ok, err = pcall(function()
    mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
      local out = next(game, items)
      if type(out) ~= "table" then return out end
      if not customUIEnabled() then return out end
      if alreadyPresent(out) then return out end

      local row = {
        label = "VOXEL ASCENDANT",
        desc = { "Voxel View", "Johto menus" },
        _stadium2DirectModSettings = true,
        onSelect = function(selectedGame)
          openDirect(selectedGame or game)
        end,
      }
      return insertAfterOption(out, row)
    end)
  end)
  if not ok then return false, tostring(err) end

  M.installed = true
  return true
end

M.openDirect = openDirect
M.insertAfterOption = insertAfterOption

function M.status()
  return {
    installed = M.installed,
    opens = M.opens,
    lastError = M.lastError,
    modId = modId(),
  }
end

return M
