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
  "kanto_ascendant", -- current public KASC package id
  "trainer_rematch", -- legacy KASC releases through 6.0
}

local MENU_KEY = "voxel_ascendant"
local MENU_ORDER = 990
local HOOK_PRIORITY = 900 -- KASC's documented collector runs at 1000.
local MENU_SKIN_BRIDGE_SCHEMA = "voxel-ascendant/kasc-menu-skin/v1"
local MENU_SKIN_INSTALL_KEY = "__voxelAscendantMenuSkinBridge"
local MENU_SKIN_RETRY_KEY = "__voxelAscendantMenuSkinBridgeRetry"
local INFO_ROUTE_MARKER = "__vascOrasInformationalRouteOriginal"
local unpackValues = table.unpack or unpack

local function packed(...)
  return { n=select("#", ...), ... }
end

local function validAscendant(handle)
  local exports = type(handle) == "table" and handle.exports or nil
  local menu = type(exports) == "table" and exports.ascendantMenu or nil
  return type(menu) == "table"
     and type(menu.collect) == "function"
     and type(menu.open) == "function"
end

-- mod.find only returns enabled handles. Animation and sprite compatibility
-- must not depend on a particular menu-export revision, so this lighter
-- probe answers whether either current or legacy KASC is actually active.
function Compat.active(mod)
  if type(mod) ~= "table" or type(mod.find) ~= "function" then return false end
  for _, id in ipairs(KASC_IDS) do
    local ok, handle = pcall(mod.find, id)
    if ok and type(handle) == "table" then return true, handle, id end
  end
  return false
end

-- Resolve only KASC's documented public Field-Tech service. Integrated VASC
-- features consume this bounded surface instead of reaching through a private
-- KASC module path or save bucket. A missing/older provider is simply absent.
function Compat.fieldTech(mod)
  local active, handle = Compat.active(mod)
  local exports = active and type(handle) == "table" and handle.exports or nil
  local service = type(exports) == "table" and exports.fieldTech or nil
  if type(service) ~= "table"
      or type(service.open) ~= "function"
      or type(service.activate) ~= "function"
      or type(service.useFieldMove) ~= "function" then
    return nil
  end
  return service
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

local function isGerman(mod)
  if type(mod) == "table" and type(mod.find) == "function" then
    local okUniversal, universal = pcall(
      mod.find, "translation-german-universal")
    local exports = okUniversal and type(universal) == "table"
                    and universal.exports or nil
    local language = type(exports) == "table" and exports.bootLanguage or nil
    if language == "de" or language == "en" then return language == "de" end
  end

  local okVersion, GameVersion = pcall(require, "src.core.GameVersion")
  local version = okVersion and type(GameVersion) == "table"
                  and type(GameVersion.get) == "function"
                  and GameVersion.get() or "red"
  local expected = {
    red="deutsch", blue="deutsch-blau", yellow="deutsch-gelb",
  }
  local id = expected[version]
  if not id or type(mod) ~= "table" or type(mod.find) ~= "function" then
    return false
  end
  local okFind, handle = pcall(mod.find, id)
  return okFind and handle ~= nil
end

local function localizedHelpTitle(mod, title)
  title = tostring(title or "ASCENDANT HELP")
  if not isGerman(mod) then return title end
  if title == "ASCENDANT HELP" then return "ASCENDANT-HILFE" end
  return (title:gsub(" HELP$", " HILFE"))
end

function Compat.row(mod, game)
  local help
  if isGerman(mod) then
    help = "Öffnet Voxel Ascendants vollständigen, eigenständigen Baum mit "
      .. "VIEW + WORLD, WEATHER + SCENERY, BATTLE, SKINS & OVERLAYS, "
      .. "POKéMON + MODELS, "
      .. "WILDS + FOLLOWERS, PERFORMANCE, USER CONTENT und ADVANCED. "
      .. "START oder SELECT erklärt jede Zeile."
  else
    help = "Open Voxel Ascendant's complete standalone tree: VIEW + WORLD, "
      .. "WEATHER + SCENERY, BATTLE, SKINS & OVERLAYS, POKéMON + MODELS, "
      .. "WILDS + FOLLOWERS, "
      .. "PERFORMANCE, USER CONTENT and ADVANCED. START or SELECT explains rows."
  end
  return {
    label = "VOXEL ASCENDANT",
    ascendantMenu = true,
    ascendantLabel = "VOXEL ASCENDANT",
    ascendantOrder = MENU_ORDER,
    ascendantKey = MENU_KEY,
    ascendantHelp = help,
    onSelect = function()
      -- One hub in both configurations: KASC collects this descriptor into
      -- ASCENDANT; without KASC it stays in the ordinary Start menu.
      mod.ui.push(game, "VascMenu")
    end,
  }
end

function Compat.decorate(mod, game, items)
  if type(items) ~= "table" or alreadyPresent(items) then return items end
  return mod.ui.insertBefore(items, "SAVE", Compat.row(mod, game))
end

local function validMenuSkinBridge(bridge)
  return type(bridge) == "table"
     and bridge.schema == MENU_SKIN_BRIDGE_SCHEMA
     and type(bridge.currentSkin) == "function"
     and type(bridge.decorateGuided) == "function"
     and type(bridge.showHelp) == "function"
end

local function bridgeUsesOras(bridge)
  local ok, value = pcall(bridge.currentSkin)
  value = ok and tostring(value or ""):lower() or ""
  return value == "oras_fullscreen"
      or value == "oras-fullscreen"
      or value == "oras fullscreen"
end

-- KASC deliberately exports its Ascendant UI factory. Wrap that one public
-- factory, not the engine ListMenu and not KASC's Bag/Bank/question helpers.
-- A receipt on the exported facade makes hot reload idempotent: a later VASC
-- instance updates the live bridge callbacks without stacking another layer.
function Compat.installMenuSkinBridge(mod, bridge)
  if not validMenuSkinBridge(bridge) then return false, "invalid-bridge" end
  local active, handle = Compat.active(mod)
  local exports = active and handle and handle.exports
  local ui = type(exports) == "table" and exports.ascendantUi or nil
  local list = type(ui) == "table" and ui.ListMenu or nil
  if not (type(list) == "table" and type(list.new) == "function") then
    return false, "kasc-ui-unavailable"
  end

  local installed = rawget(ui, MENU_SKIN_INSTALL_KEY)
  if type(installed) == "table" and installed.wrapper == list.new
      and (type(ui.guidedList) ~= "function"
        or installed.guidedWrapper == ui.guidedList) then
    installed.bridge = bridge
    return true, "updated"
  end

  local originalNew = list.new
  local originalGuided = type(ui.guidedList) == "function"
    and ui.guidedList or nil
  local receipt = {
    bridge=bridge, original=originalNew, originalGuided=originalGuided,
  }

  local function activeAscendantParent(game)
    local stack = game and game.stack
    if not (stack and type(stack.top) == "function") then return false end
    local ok, parent = pcall(stack.top, stack)
    return ok and type(parent) == "table"
      and (parent.__kantoAscendantFocusHelp == true
        or parent.__vascAscendantWidescreenRoute == true)
  end

  local function ordinaryHelp(item, _, title)
    if type(item) ~= "table" then return tostring(title or "ASCENDANT") end
    if item.help ~= nil and tostring(item.help) ~= "" then return item.help end
    local label = tostring(item.label or title or "ASCENDANT")
    local right = item.right ~= nil and tostring(item.right) or ""
    return right ~= "" and (label .. "  " .. right) or label
  end

  -- KASC's older status hubs still push a plain engine TextBox directly from
  -- their row callback.  When that row lives inside an ORAS Ascendant screen,
  -- keep the authored parent at full size and route only callback-free
  -- informational text through VASC's matching HelpPopup.  Stateful dialogue
  -- (onDone/choice/auto/stay/sound/money) retains the exact native stack path.
  local function informationalBody(state)
    if type(state) ~= "table" or state.isTextBox ~= true
        or state.onDone ~= nil or state.choice ~= nil or state.auto ~= nil
        or state.stay ~= nil or state.preSound ~= nil or state.money ~= nil
        or type(state.pages) ~= "table" then
      return nil
    end
    local pages = {}
    for _, page in ipairs(state.pages) do
      if type(page) ~= "table" then return nil end
      local lines = {}
      for _, line in ipairs(page) do lines[#lines + 1] = tostring(line or "") end
      pages[#pages + 1] = table.concat(lines, "\n")
    end
    return #pages > 0 and table.concat(pages, "\f") or nil
  end

  local function routeInformationalPush(game, title, callback, ...)
    local stack = game and game.stack
    if type(callback) ~= "function" or not (type(stack) == "table"
        and type(stack.push) == "function") then
      return callback(...)
    end
    local activeBridge = receipt.bridge
    if not (validMenuSkinBridge(activeBridge)
        and bridgeUsesOras(activeBridge)) then
      return callback(...)
    end
    local originalPush = stack.push
    stack.push = function(owner, state, ...)
      local body = informationalBody(state)
      if body ~= nil then
        local okHelp, handled = pcall(activeBridge.showHelp,
          game, localizedHelpTitle(mod, title), body)
        if okHelp and handled == true then
          return nil
        end
      end
      return originalPush(owner, state, ...)
    end
    local args = packed(...)
    local ok, result = xpcall(function()
      return packed(callback(unpackValues(args, 1, args.n)))
    end, function(message)
      return debug and type(debug.traceback) == "function"
        and debug.traceback(tostring(message), 2) or tostring(message)
    end)
    stack.push = originalPush
    if not ok then error(result, 0) end
    return unpackValues(result, 1, result.n)
  end

  local function routeInformationalRows(game, items)
    for _, item in ipairs(type(items) == "table" and items or {}) do
      if type(item) == "table" and type(item.onSelect) == "function"
          and rawget(item, INFO_ROUTE_MARKER) == nil then
        local original = item.onSelect
        item[INFO_ROUTE_MARKER] = original
        item.onSelect = function(...)
          return routeInformationalPush(game,
            item.label or "ASCENDANT", original, ...)
        end
      end
    end
  end

  local function routeNationalDex(game, items)
    local receipt = mod.exports and mod.exports.modernDex
    if type(items) ~= "table" or type(receipt) ~= "table"
        or receipt.active ~= true or type(receipt.open) ~= "function" then
      return items
    end
    for index, item in ipairs(items) do
      -- KASC assigns the stable order:30 identity to its Nationaldex research
      -- row.  Route only that exact row; Research Atlas, Shiny-Dex and Mega
      -- Stone descendants remain KASC-owned widescreen lists.
      if type(item) == "table" and item.ascendantKey == "order:30" then
        local routedItems = {}
        for copyIndex, value in ipairs(items) do routedItems[copyIndex] = value end
        local routed = {}
        for key, value in pairs(item) do routed[key] = value end
        local originalSelect = item.onSelect
        routed.onSelect = function(...)
          local active = mod.exports and mod.exports.modernDex
          if type(active) == "table" and active.active == true
              and type(active.open) == "function" then
            local ok, handled = pcall(active.open, game, {
              language=isGerman(mod) and "de" or "en",
            })
            if ok and handled == true then return true end
          end
          if type(originalSelect) == "function" then
            return originalSelect(...)
          end
          return false
        end
        routedItems[index] = routed
        return routedItems
      end
    end
    return items
  end

  receipt.wrapper = function(game, title, items, options)
    local requested = type(options) == "table" and options or nil
    local parentIsAscendant = requested and activeAscendantParent(game)
    local routedItems = parentIsAscendant and routeNationalDex(game, items)
      or items
    local menu = originalNew(game, title, routedItems, options)
    local focusProvider = requested
      and type(requested.ascendantFocusHelp) == "function"
      and requested.ascendantFocusHelp or nil
    local style = tostring(requested and requested.ascendantStyle
      or type(menu) == "table" and menu.__kantoAscendantStyle or "")
    local ordinaryAscendantRoute = requested and not focusProvider
      and parentIsAscendant
      and (style == "" or style == "firered")
    if type(menu) == "table" and requested
        and (focusProvider or ordinaryAscendantRoute)
        and requested.ascendantLayout ~= false and not requested.dialogue
        and not requested.messageBox
        and menu.__kantoAscendantLayout == true then
      local current = receipt.bridge
      if validMenuSkinBridge(current) then
        local provider = focusProvider or function(item, selectedMenu)
          return ordinaryHelp(item, selectedMenu, title)
        end
        -- FireRed retains KASC's five-row renderer. ORAS gets the full nine-row
        -- surface; the VASC decorator multiplexes these live on the same menu.
        local okDecorate, _, didDecorate = pcall(current.decorateGuided,
          menu, provider, 9)

        if okDecorate and didDecorate == true then
          -- Descendants opened from this exact screen inherit the widescreen
          -- route. This catches authored Dex, Research Atlas and Mega-Stone
          -- lists that predate KASC's focus-help marker, without touching the
          -- same list factory when it is used from Bag, PC or field pickers.
          menu.__vascAscendantWidescreenRoute = true

          -- Descendant status/help rows from older KASC modules are allowed
          -- to retain their callbacks, but their plain informational TextBox
          -- should not collapse this fullscreen surface back to 160x144.
          if ordinaryAscendantRoute then
            routeInformationalRows(game, routedItems)
          end

          -- Help routing belongs only to an explicitly marked guided menu.
          -- Ordinary descendant lists retain their original SELECT behavior.
          local originalSelect = menu.onSelectKey
          if focusProvider then
            menu.onSelectKey = function(item, selectedMenu, ...)
              local activeBridge = receipt.bridge
              if validMenuSkinBridge(activeBridge)
                  and bridgeUsesOras(activeBridge) then
                local okBody, body = pcall(focusProvider,
                  item, selectedMenu or menu)
                if okBody and body ~= nil and tostring(body) ~= "" then
                  local okHelp, handled = pcall(activeBridge.showHelp,
                    game, item and item.label or title, body)
                  if okHelp and handled == true then return true end
                end
              end
              if type(originalSelect) == "function" then
                return originalSelect(item, selectedMenu, ...)
              end
              return false
            end
          end
        end
      end
    end
    return menu
  end
  list.new = receipt.wrapper

  -- KASC's first-time guide is attached *after* ListMenu.new returns and is
  -- opened immediately by pushGuidedList.  Wrapping only the constructor can
  -- therefore skin the list and every later SELECT popup while still letting
  -- this one introductory popup use KASC's old compact page.  Intercept the
  -- public guided-list factory as well, after that callback exists, and route
  -- only the ORAS fullscreen guide through VASC's menu-scoped HelpPopup.
  if originalGuided then
    receipt.guidedWrapper = function(game, spec)
      local menu = originalGuided(game, spec)
      local originalFirstGuide = type(menu) == "table"
        and menu.showFirstGuide or nil
      if type(originalFirstGuide) == "function" and type(spec) == "table"
          and spec.help ~= nil and tostring(spec.help) ~= "" then
        menu.showFirstGuide = function(self, ...)
          local activeBridge = receipt.bridge
          if validMenuSkinBridge(activeBridge)
              and bridgeUsesOras(activeBridge) then
            if self.__vascOrasFirstGuideShown == true then return false end
            local okHelp, handled = pcall(activeBridge.showHelp,
              game, localizedHelpTitle(mod,
                spec.helpTitle or spec.title or "ASCENDANT HELP"), spec.help)
            if okHelp and handled == true then
              self.__vascOrasFirstGuideShown = true
              return true
            end
          end
          return originalFirstGuide(self, ...)
        end
      end
      return menu
    end
    ui.guidedList = receipt.guidedWrapper
  end
  ui[MENU_SKIN_INSTALL_KEY] = receipt
  return true, "installed"
end

function Compat.install(mod, opts)
  if type(mod) ~= "table" or type(mod.hooks) ~= "table"
      or type(mod.hooks.wrap) ~= "function" then
    return false
  end
  mod.hooks:wrap("ui.start_menu.items", function(nextItems, game, items)
    local out = nextItems(game, items)
    return Compat.decorate(mod, game, out)
  end, HOOK_PRIORITY)
  if type(opts) == "table" and opts.menuSkinBridge then
    local installed, reason = Compat.installMenuSkinBridge(
      mod, opts.menuSkinBridge)
    if not installed and reason == "kasc-ui-unavailable"
        and type(mod.events) == "table"
        and type(mod.events.once) == "function"
        and not rawget(mod, MENU_SKIN_RETRY_KEY) then
      local bridge = opts.menuSkinBridge
      mod[MENU_SKIN_RETRY_KEY] = true
      mod.events:once("mods.loaded", function()
        Compat.installMenuSkinBridge(mod, bridge)
      end)
    end
  end
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
    menuSkinBridgeSchema = MENU_SKIN_BRIDGE_SCHEMA,
    kantoAscendantIds = ids,
  }
end

Compat.MENU_KEY = MENU_KEY
Compat.MENU_ORDER = MENU_ORDER
Compat.HOOK_PRIORITY = HOOK_PRIORITY
Compat.MENU_SKIN_BRIDGE_SCHEMA = MENU_SKIN_BRIDGE_SCHEMA

return Compat
