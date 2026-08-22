-- Optional Kanto Ascendant menu bridge.
--
-- KASC owns its ASCENDANT menu and deliberately discovers entries through
-- Gen1Recomp's public ui.start_menu.items hook.  Feature rows carry the small
-- descriptor protocol below; KASC's higher-priority collector removes them
-- from the ordinary Start menu and presents them in its own list.  Keeping
-- the bridge on that public hook means neither mod needs the other's loader,
-- save data or private modules.

local Compat = {}

local KASC_IDS = {
  "kanto_ascendant", -- current KASC 6.7+
  "trainer_rematch", -- legacy KASC releases through 6.0
}

local MENU_KEY = "voxel_ascendant"
local MENU_ORDER = 990
local HOOK_PRIORITY = 900 -- KASC's documented collector runs at 1000.

local function validAscendant(handle)
  local exports = type(handle) == "table" and handle.exports or nil
  local menu = type(exports) == "table" and exports.ascendantMenu or nil
  return type(menu) == "table"
     and type(menu.collect) == "function"
     and type(menu.open) == "function"
end

function Compat.find(mod)
  if type(mod) ~= "table" or type(mod.find) ~= "function" then return nil end
  for _, id in ipairs(KASC_IDS) do
    local ok, handle = pcall(mod.find, id)
    if ok and validAscendant(handle) then return handle, id end
  end
  return nil
end

local function alreadyPresent(items)
  for _, item in ipairs(items or {}) do
    if type(item) == "table"
        and (item.ascendantKey == MENU_KEY
          or item.label == "VOXEL ASCENDANT"
          or item.ascendantLabel == "VOXEL ASCENDANT") then
      return true
    end
  end
  return false
end

function Compat.row(mod, game)
  return {
    label = "VOXEL ASCENDANT",
    ascendantMenu = true,
    ascendantLabel = "VOXEL ASCENDANT",
    ascendantOrder = MENU_ORDER,
    ascendantKey = MENU_KEY,
    onSelect = function()
      -- The normal Options screen remains the single settings authority.
      -- Pushing it over KASC's list also makes CANCEL return to that list.
      mod.ui.push(game, "OptionsMenu")
    end,
  }
end

function Compat.decorate(mod, game, items)
  if type(items) ~= "table" or alreadyPresent(items) then return items end
  if not Compat.find(mod) then return items end
  return mod.ui.insertBefore(items, "SAVE", Compat.row(mod, game))
end

function Compat.install(mod)
  if type(mod) ~= "table" or type(mod.hooks) ~= "table"
      or type(mod.hooks.wrap) ~= "function" then
    return false
  end
  mod.hooks:wrap("ui.start_menu.items", function(nextItems, game, items)
    local out = nextItems(game, items)
    return Compat.decorate(mod, game, out)
  end, HOOK_PRIORITY)
  return true
end

function Compat.receipt()
  local ids = {}
  for i, id in ipairs(KASC_IDS) do ids[i] = id end
  return {
    schema = "voxel-ascendant/kanto-menu/v1",
    optional = true,
    hook = "ui.start_menu.items",
    menuKey = MENU_KEY,
    kantoAscendantIds = ids,
  }
end

Compat.MENU_KEY = MENU_KEY
Compat.MENU_ORDER = MENU_ORDER
Compat.HOOK_PRIORITY = HOOK_PRIORITY

return Compat
