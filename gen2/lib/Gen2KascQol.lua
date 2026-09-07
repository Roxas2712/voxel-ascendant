-- Safe KASC comfort parity for the Gold/Silver/Crystal runtime.
--
-- Every adapter below sits on a concrete Gen2Recomp seam and is independently
-- switchable.  The engine still owns item legality and effects, box contents,
-- capture order and catch math, and the complete battle-animation script.  In
-- particular, disabling registered-item access preserves the saved assignment
-- so turning the option back on is lossless.

local C = ... or {}
local mod = C.mod

local M = {
  installed = false,
  seams = {
    registeredItem = false,
    catchBoxNotice = false,
    fastBoxSwitch = false,
    modernBallSkins = false,
  },
  registeredUses = 0,
  blockedRegisteredActions = 0,
  catchNotices = 0,
  boxSwitches = 0,
  blockedBoxSwitches = 0,
  skinRequests = 0,
  lastError = nil,
}

local unpackValues = table.unpack or unpack
local BALL_MARKER = "VASC_GEN2_BALL:"

-- Four-colour palettes match BattleAnimView/GbcPalette's native 0..255
-- contract.  This is deliberately a palette skin for the real Gen-2 thrown
-- ball object, not KASC's Gen-1 true-colour replacement sprite.
local BALL_SKINS = {
  MASTER_BALL = {
    { 255, 238, 255 }, { 196, 82, 224 }, { 94, 35, 140 }, { 20, 18, 32 },
  },
  ULTRA_BALL = {
    { 255, 250, 210 }, { 246, 198, 45 }, { 72, 70, 72 }, { 18, 20, 24 },
  },
  GREAT_BALL = {
    { 238, 250, 255 }, { 55, 139, 230 }, { 190, 45, 68 }, { 20, 28, 48 },
  },
  POKE_BALL = {
    { 255, 250, 245 }, { 236, 76, 78 }, { 142, 31, 43 }, { 24, 24, 30 },
  },
  HEAVY_BALL = {
    { 240, 247, 250 }, { 126, 151, 165 }, { 54, 72, 86 }, { 18, 24, 30 },
  },
  LEVEL_BALL = {
    { 255, 246, 190 }, { 244, 163, 38 }, { 198, 58, 42 }, { 38, 28, 26 },
  },
  LURE_BALL = {
    { 225, 255, 255 }, { 48, 170, 218 }, { 34, 83, 157 }, { 18, 26, 45 },
  },
  FAST_BALL = {
    { 255, 249, 198 }, { 245, 197, 42 }, { 214, 57, 45 }, { 42, 27, 24 },
  },
  FRIEND_BALL = {
    { 231, 255, 223 }, { 92, 191, 91 }, { 38, 119, 70 }, { 20, 38, 27 },
  },
  MOON_BALL = {
    { 234, 238, 255 }, { 121, 133, 218 }, { 47, 57, 127 }, { 20, 22, 43 },
  },
  LOVE_BALL = {
    { 255, 235, 246 }, { 242, 111, 169 }, { 169, 43, 101 }, { 43, 20, 38 },
  },
  PARK_BALL = {
    { 255, 249, 207 }, { 228, 184, 58 }, { 67, 128, 68 }, { 31, 35, 25 },
  },
}

local function pack(...)
  return { n = select("#", ...), ... }
end

local function option(key, fallback)
  local options = mod and mod.options
  if not (options and type(options.get) == "function") then return fallback end
  local ok, value = pcall(options.get, options, key)
  if not ok or value == nil then return fallback end
  return value
end

local function enabled(key, fallback)
  local value = option(key, fallback)
  if value == true or value == 1 then return true end
  if value == false or value == 0 then return false end
  local text = tostring(value):lower()
  if text == "true" or text == "on" or text == "1" then return true end
  if text == "false" or text == "off" or text == "0" then return false end
  return fallback == true
end

local function findStoredBox(save, mon, Boxes)
  local all = save and save.boxes
  if type(all) ~= "table" then return nil end
  local count = tonumber(Boxes and Boxes.NUM_BOXES) or #all
  for boxIndex = 1, count do
    local box = all[boxIndex]
    if type(box) == "table" then
      for _, stored in ipairs(box) do
        if stored == mon then return boxIndex end
      end
    end
  end
  return nil
end

local Provider = {
  owner = M,
  registeredItemEnabled = function()
    return enabled("qolRegisteredItem", true)
  end,
  catchBoxNoticeEnabled = function()
    return enabled("qolCatchBoxNotice", true)
  end,
  fastBoxSwitchEnabled = function()
    return enabled("qolFastBoxSwitch", true)
  end,
  modernBallSkinsEnabled = function()
    return enabled("qolModernBallSkins", true)
  end,
  paletteForMarker = function(name)
    if type(name) ~= "string" or name:sub(1, #BALL_MARKER) ~= BALL_MARKER then
      return nil
    end
    return BALL_SKINS[name:sub(#BALL_MARKER + 1)]
  end,
}

local function installRegisteredItem(World)
  if type(World.registerItem) ~= "function"
      or type(World.useSelectItem) ~= "function" then
    return false, "native registered-item methods unavailable"
  end
  local bridge = rawget(World, "__vascGen2KascRegisteredItem")
  if type(bridge) ~= "table" then
    bridge = {
      originalRegisterItem = World.registerItem,
      originalUseSelectItem = World.useSelectItem,
    }
    bridge.registerItem = function(world, ...)
      local provider = bridge.provider
      if provider and not provider.registeredItemEnabled() then
        provider.owner.blockedRegisteredActions =
          provider.owner.blockedRegisteredActions + 1
        return false
      end
      return bridge.originalRegisterItem(world, ...)
    end
    bridge.useSelectItem = function(world, ...)
      local provider = bridge.provider
      if provider and not provider.registeredItemEnabled() then
        provider.owner.blockedRegisteredActions =
          provider.owner.blockedRegisteredActions + 1
        -- Game2 deliberately has no message branch for this private sentinel,
        -- so OFF makes SELECT inert without deleting save.registeredItem.
        return "disabled"
      end
      local results = pack(bridge.originalUseSelectItem(world, ...))
      if provider then
        provider.owner.registeredUses = provider.owner.registeredUses + 1
      end
      return unpackValues(results, 1, results.n)
    end
    World.registerItem = bridge.registerItem
    World.useSelectItem = bridge.useSelectItem
    World.__vascGen2KascRegisteredItem = bridge
  end
  bridge.provider = Provider
  return true
end

local function installFastBoxSwitch(BoxMenu)
  if type(BoxMenu.stepBox) ~= "function" then
    return false, "native BoxMenu:stepBox unavailable"
  end
  local bridge = rawget(BoxMenu, "__vascGen2KascFastBoxSwitch")
  if type(bridge) ~= "table" then
    bridge = { originalStepBox = BoxMenu.stepBox }
    bridge.stepBox = function(screen, ...)
      local provider = bridge.provider
      -- MOVE/insert needs box navigation to complete the native operation.
      -- Only WITHDRAW's direct L/R shortcut is optional KASC comfort.
      if provider and not provider.fastBoxSwitchEnabled()
          and screen.mode == "withdraw" and screen.phase == nil then
        provider.owner.blockedBoxSwitches =
          provider.owner.blockedBoxSwitches + 1
        return false
      end
      local results = pack(bridge.originalStepBox(screen, ...))
      if provider and screen.mode == "withdraw" and screen.phase == nil then
        provider.owner.boxSwitches = provider.owner.boxSwitches + 1
      end
      return unpackValues(results, 1, results.n)
    end
    BoxMenu.stepBox = bridge.stepBox
    BoxMenu.__vascGen2KascFastBoxSwitch = bridge
  end
  bridge.provider = Provider
  return true
end

local function installCatchBoxNotice(BattleState, Boxes)
  if type(BattleState.pushCaught) ~= "function"
      or type(Boxes) ~= "table" or tonumber(Boxes.NUM_BOXES) == nil then
    return false, "native capture/storage seam unavailable"
  end
  local bridge = rawget(BattleState, "__vascGen2KascCatchBoxNotice")
  if type(bridge) ~= "table" then
    bridge = { originalPushCaught = BattleState.pushCaught, Boxes = Boxes }
    bridge.pushCaught = function(screen, enemy, ...)
      local results = pack(bridge.originalPushCaught(screen, enemy, ...))
      local provider = bridge.provider
      if provider and provider.catchBoxNoticeEnabled()
          and type(screen.push) == "function" then
        local boxIndex = findStoredBox(screen.save, enemy, bridge.Boxes)
        if boxIndex then
          local name = enemy and (enemy.nickname or enemy.name or enemy.species)
            or "POKéMON"
          if type(screen.name) == "function" then
            local okName, nativeName = pcall(screen.name, screen, enemy)
            if okName and nativeName then name = nativeName end
          end
          screen:push({ kind = "message",
            text = tostring(name or "POKéMON") .. " was sent to\nBOX "
              .. tostring(boxIndex) .. "." })
          provider.owner.catchNotices = provider.owner.catchNotices + 1
        end
      end
      return unpackValues(results, 1, results.n)
    end
    BattleState.pushCaught = bridge.pushCaught
    BattleState.__vascGen2KascCatchBoxNotice = bridge
  end
  bridge.Boxes = Boxes
  bridge.provider = Provider
  return true
end

local function installModernBallSkins(BattleState, BattleAnimView)
  if type(BattleState.ballPalette) ~= "function"
      or type(BattleAnimView.objPalette) ~= "function" then
    return false, "native thrown-ball palette seam unavailable"
  end

  local stateBridge = rawget(BattleState, "__vascGen2KascBallPalette")
  if type(stateBridge) ~= "table" then
    stateBridge = { originalBallPalette = BattleState.ballPalette }
    stateBridge.ballPalette = function(screen, itemId, ...)
      local original = stateBridge.originalBallPalette(screen, itemId, ...)
      local provider = stateBridge.provider
      if provider and provider.modernBallSkinsEnabled()
          and BALL_SKINS[itemId] then
        provider.owner.skinRequests = provider.owner.skinRequests + 1
        return BALL_MARKER .. itemId
      end
      return original
    end
    BattleState.ballPalette = stateBridge.ballPalette
    BattleState.__vascGen2KascBallPalette = stateBridge
  end
  stateBridge.provider = Provider

  local viewBridge = rawget(BattleAnimView, "__vascGen2KascBallPalette")
  if type(viewBridge) ~= "table" then
    viewBridge = { originalObjPalette = BattleAnimView.objPalette }
    viewBridge.objPalette = function(view, name, battle, ...)
      local provider = viewBridge.provider
      local palette = provider and provider.paletteForMarker(name) or nil
      -- Resolve markers already captured by a running throw even if the user
      -- switches the option off mid-animation.  The next throw uses native.
      if palette then return palette end
      return viewBridge.originalObjPalette(view, name, battle, ...)
    end
    BattleAnimView.objPalette = viewBridge.objPalette
    BattleAnimView.__vascGen2KascBallPalette = viewBridge
  end
  viewBridge.provider = Provider
  return true
end

local function loadModule(name)
  local ok, value = pcall(require, name)
  if ok and type(value) == "table" then return value end
  return nil, tostring(value or (name .. " unavailable"))
end

function M.install()
  if M.installed then return true, M.lastError end

  local errors = {}
  local World, worldErr = loadModule("src.world.gen2.World")
  local BoxMenu, boxErr = loadModule("src.ui.gen2.BoxMenu")
  local BattleState, battleErr = loadModule("src.ui.gen2.BattleState")
  local BattleAnimView, viewErr = loadModule("src.ui.gen2.BattleAnimView")
  local Boxes, boxesErr = loadModule("src.core.gen2.Boxes")

  local function record(key, ok, reason)
    M.seams[key] = ok == true
    if not ok then errors[#errors + 1] = key .. ": " .. tostring(reason) end
  end

  if World then
    record("registeredItem", installRegisteredItem(World))
  else
    record("registeredItem", false, worldErr)
  end
  if BoxMenu then
    record("fastBoxSwitch", installFastBoxSwitch(BoxMenu))
  else
    record("fastBoxSwitch", false, boxErr)
  end
  if BattleState and Boxes then
    record("catchBoxNotice", installCatchBoxNotice(BattleState, Boxes))
  else
    record("catchBoxNotice", false, battleErr or boxesErr)
  end
  if BattleState and BattleAnimView then
    record("modernBallSkins",
      installModernBallSkins(BattleState, BattleAnimView))
  else
    record("modernBallSkins", false, battleErr or viewErr)
  end

  M.installed = M.seams.registeredItem or M.seams.catchBoxNotice
    or M.seams.fastBoxSwitch or M.seams.modernBallSkins
  M.lastError = #errors > 0 and table.concat(errors, "; ") or nil
  if not M.installed then return false, M.lastError end
  return true, M.lastError
end

function M.status()
  return {
    installed = M.installed,
    registeredItem = M.seams.registeredItem
      and enabled("qolRegisteredItem", true),
    catchBoxNotice = M.seams.catchBoxNotice
      and enabled("qolCatchBoxNotice", true),
    fastBoxSwitch = M.seams.fastBoxSwitch
      and enabled("qolFastBoxSwitch", true),
    modernBallSkins = M.seams.modernBallSkins
      and enabled("qolModernBallSkins", true),
    seams = {
      registeredItem = M.seams.registeredItem,
      catchBoxNotice = M.seams.catchBoxNotice,
      fastBoxSwitch = M.seams.fastBoxSwitch,
      modernBallSkins = M.seams.modernBallSkins,
    },
    registeredUses = M.registeredUses,
    blockedRegisteredActions = M.blockedRegisteredActions,
    catchNotices = M.catchNotices,
    boxSwitches = M.boxSwitches,
    blockedBoxSwitches = M.blockedBoxSwitches,
    skinRequests = M.skinRequests,
    nativeRules = true,
    fieldKitDefault = false,
    lastError = M.lastError,
  }
end

return M
