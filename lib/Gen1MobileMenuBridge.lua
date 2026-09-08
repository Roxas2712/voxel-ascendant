-- Gen-1 menu presentation bridge for phones.
--
-- Every menu keeps its authoritative constructor, update method, callbacks and
-- stack ownership.  This bridge only asks MobileMenuPresentation to render the
-- already-decorated final surface in the largest notch-safe phone rectangle.
-- It is deliberately installed after the Bag, Party, Box and Dex providers so
-- it captures their finished Ascendant/A21 appearance instead of an earlier
-- native renderer.

local V = ...
local mod = V and V.mod
local MobileMenuPresentation = V and V.require
  and V.require("MobileMenuPresentation") or nil
local OrasUiSkin = V and V.OrasUiSkin or nil

local M = {
  apiVersion = 1,
  installed = false,
  attached = 0,
  skipped = 0,
  lastError = nil,
  reconciled = 0,
}

local MENU_IDS = {
  BagMenu=true,
  BoxMenu=true,
  DexEntryMenu=true,
  FlyMenu=true,
  MoveLearnMenu=true,
  NamingScreen=true,
  OptionsMenu=true,
  PartyMenu=true,
  PlayerPC=true,
  PokedexMenu=true,
  ShopMenu=true,
  SummaryMenu=true,
  TownMap=true,
  TrainerCard=true,
}

local PRESENTATION_MARKERS = {
  "__kantoAscendantLayout",
  "__vascOrasBagStyle",
  "__vascPartyMenuStyle",
  "__vascGen1TitleMenuPresentation",
  "__voxelAscendantRoot",
  "__voxelAscendantStandaloneStyle",
  "__ascendantBoxHost",
  "__ascendantPokemonUiHost",
}

local function positive(value)
  value = tonumber(value)
  return value and value > 0 and value or nil
end

local function screenId(state)
  return tostring(type(state) == "table"
    and (state.screenId or state.id or state.__name) or "")
end

local function hasPresentationMarker(state)
  for _, marker in ipairs(PRESENTATION_MARKERS) do
    if rawget(state, marker) ~= nil then return true end
  end
  return false
end

local function isNativeTitleRoot(state)
  return type(state) == "table"
    and screenId(state) == "TitleState"
    and type(state.onNewGame) == "function"
end

local function eligible(state)
  if type(state) ~= "table" then return false, "not-state" end
  -- Never place the generic phone canvas around the cartridge title owner.
  -- Its logo, animation, palette and Press Start screen must remain native;
  -- TitleMenuHub handles only the menu states pushed after it.
  if isNativeTitleRoot(state) then return false, "native-title-owner" end
  local id = screenId(state)
  if id == "StartMenu" or id:match("^Gen2") then
    return false, "separate-owner"
  end
  if state.__vascPersistentStartMode then return false, "start-owner" end
  if MENU_IDS[id] then return true, "screen:" .. id end
  if hasPresentationMarker(state) then return true, "authored-marker" end
  -- Generic opaque ListMenu derivatives are genuine full menu surfaces.
  -- Transparent Menu/ChoiceBox/TextBox states remain modal overlays so field
  -- and battle dialogue never receives an invented full-screen backdrop.
  if state.isOpaque == true and type(state.draw) == "function"
      and (state.items ~= nil or state.rows ~= nil or state.title ~= nil) then
    return true, "opaque-menu"
  end
  return false, "not-menu"
end

local function logicalSize(state, hasWide)
  if type(state.uiSize) == "function" then
    local ok, width, height = pcall(state.uiSize, state)
    width, height = positive(width), positive(height)
    if ok and width and height then
      -- A widescreen renderer paired with the native 160x144 uiSize still
      -- composes in Ascendant's reviewed 512x288 surface.
      if hasWide and width <= 160 and height <= 144 then return 512, 288 end
      return width, height
    end
  end
  if hasWide then return 512, 288 end
  return 160, 144
end

function M.attach(state)
  if type(MobileMenuPresentation) == "table"
      and type(MobileMenuPresentation.isMobileRuntime) == "function"
      and not MobileMenuPresentation.isMobileRuntime() then
    return state, false, "desktop-native-path"
  end
  if type(state) == "table" and state.__vascGen1MobileMenuBridge then
    return state, true, state.__vascMobileMenuOwner or "already-attached"
  end
  local allowed, reason = eligible(state)
  if not allowed then
    M.skipped = M.skipped + 1
    return state, false, reason
  end
  if type(MobileMenuPresentation) ~= "table"
      or type(MobileMenuPresentation.attach) ~= "function" then
    return state, false, "mobile-presenter-unavailable"
  end
  local id = screenId(state)
  if id == "BagMenu" then
    local controller = type(OrasUiSkin) == "table" and OrasUiSkin.controller
    local decorator = type(controller) == "table"
      and controller.decorateMobileBag or nil
    if type(decorator) ~= "function" then
      return state, false, "mobile-oras-bag-router-unavailable"
    end
    local ok, _, decorated, decorateReason = pcall(decorator, state)
    local ownsOras = rawget(state, "__vascOrasBagStyle") == "oras_wide"
      and rawget(state, "__vascOrasBagPresentation") == true
    if not ok or decorated ~= true or not ownsOras then
      state.__vascMobileBagRouteError = tostring(
        ok and (decorateReason or "oras-owner-not-published") or _)
      return state, false, "mobile-oras-bag-route-failed:"
        .. state.__vascMobileBagRouteError
    end
  end
  local wide = rawget(state, "drawWidescreen") or state.drawWidescreen
  local hasWide = type(wide) == "function"
  local width, height = logicalSize(state, hasWide)
  if id == "" then id = "menu" end
  local _, attached, attachReason = MobileMenuPresentation.attach(state, {
    owner="gen1_" .. id:lower(),
    logicalW=width,
    logicalH=height,
    -- Only the Continue/New Game artwork hub needs source-resolution detail.
    -- The cartridge title, continue receipt and every other menu stay native.
    displayDensity=state.__vascGen1TitleMenuPresentation == "title-choice",
    logicalSize=function(owner)
      return logicalSize(owner, hasWide)
    end,
    backdrop={ .018, .032, .060, 1 },
    drawLogical=hasWide and function(owner, plan)
      return wide(owner, plan.logicalW, plan.logicalH)
    end or nil,
  })
  if attached then
    state.__vascGen1MobileMenuBridge = reason
    M.attached = M.attached + 1
  elseif attachReason ~= "desktop-native-path" then
    M.lastError = tostring(attachReason)
  end
  return state, attached, attachReason
end

-- screen.pushed is the normal ownership seam, but provider-owned Gen-1
-- menus can finish decorating after that event (notably the ORAS Bag and the
-- standalone ASCENDANT tree).  Reconcile the concrete state that the engine
-- is about to draw, before its draw method is resolved.  This is deliberately
-- not a generic stack scan: battle, Gen-2, translucent dialogue and the
-- cartridge TitleState all fail eligible() and remain completely untouched.
function M.reconcileVisible(state)
  if type(state) ~= "table" or state.__vascGen1MobileMenuBridge then
    return state, false, "already-attached"
  end
  local allowed, reason = eligible(state)
  if not allowed then return state, false, reason end
  local owner, attached, attachReason = M.attach(state)
  if attached then M.reconciled = M.reconciled + 1 end
  return owner, attached, attachReason
end

function M.install()
  if M.installed then return true end
  local events = mod and mod.events
  if not (events and type(events.on) == "function") then
    return false, "screen event bus unavailable"
  end
  local ok, err = pcall(events.on, events, "screen.pushed", function(event)
    M.attach(type(event) == "table" and event.state or nil)
  -- Capture only the final, generation-owned presentation.  The ORAS/title
  -- decorators above run at positive priority; this terminal bridge runs
  -- after ordinary provider listeners instead of relying on equal-priority
  -- insertion/sort order.
  end, -12000)
  if not ok then
    M.lastError = tostring(err)
    return false, M.lastError
  end
  -- A late provider decoration must not leave a 512x288 logical surface at
  -- the physical window origin.  Run just outside MobileMenuPresentation's
  -- visibility wrapper so a recovered owner is suppressed in the native UI
  -- pass and redrawn, scaled and centred, in the same frame's render.hud pass.
  local hooks = mod and mod.hooks
  if hooks and type(hooks.wrap) == "function" then
    local hookOk, hookErr = pcall(hooks.wrap, hooks,
      "screen.render_visible", function(next, state)
        M.reconcileVisible(state)
        return next(state)
      end, 15170)
    if not hookOk then
      M.lastError = tostring(hookErr)
      return false, M.lastError
    end
  end
  M.installed = true
  return true
end

function M.status()
  return {
    installed=M.installed,
    attached=M.attached,
    skipped=M.skipped,
    reconciled=M.reconciled,
    lastError=M.lastError,
  }
end

return M
