-- VASC owner bridge for the reviewed Modern Pokedex 0.4.0 presentation.
--
-- lib/ModernDex.lua remains byte-for-byte identical to the accepted standalone
-- renderer.  This host supplies only VASC-scoped settings, the already-owned
-- Kanto map receipt and a native fail-open boundary around both screen ids.
-- Engine save flags, species data, cries, forceOwned previews, Start-menu
-- callbacks and stack ownership are never reimplemented here.

local V = ...
local ModernDexHost = {}
local ModSetting = V.require("ModSetting")
local MobileMenuPresentation
pcall(function()
  MobileMenuPresentation = V.require("MobileMenuPresentation")
end)

ModernDexHost.styleSetting = ModSetting.new(
  "pokedexStyle", "POKéDEX",
  { "modern", "game" },
  { "VASC WIDESCREEN", "GAME DEFAULT" },
  "modern")
ModernDexHost.styleSetting:aliasLegacy("native", "game")
ModernDexHost.styleSetting:aliasLegacy("default", "game")

ModernDexHost.spriteSetting = ModSetting.new(
  "modernDexSpriteSource", "DEX SPRITES",
  { "kasc_crystal", "active", "game" },
  { "KASC CRYSTAL (AUTO)", "ACTIVE SPRITE STYLE", "GAME ORIGINAL" },
  "kasc_crystal")
ModernDexHost.spriteSetting:aliasLegacy("auto", "active")
ModernDexHost.spriteSetting:aliasLegacy("original", "game")

local unpackValues = table.unpack or unpack
local function packValues(...)
  return { n=select("#", ...), ... }
end

local function log(level, message, ...)
  local logger = V.mod and V.mod.log
  local fn = logger and logger[level]
  if type(fn) == "function" then pcall(fn, logger, message, ...) end
end

local function findThrough(root, id)
  local finder = root and root.find
  if type(finder) ~= "function" then return nil end
  local ok, handle = pcall(finder, id)
  if ok and handle ~= nil then return handle end
  ok, handle = pcall(finder, root, id)
  if ok then return handle end
  return nil
end

local function integratedAreaHandle(root)
  local receipt = root and root.exports and root.exports.kantoFlyMap
  local provider = type(receipt) == "table" and receipt.pokedexAreaProvider
  if receipt and receipt.active == true and type(provider) == "table"
      and tonumber(provider.apiVersion) == 1
      and type(provider.resolve) == "function" then
    return {
      id="VOXEL_ASCENDANT:kantoFlyMap",
      manifest={ id="VOXEL_ASCENDANT", version=root.version },
      enabled=true,
      -- ModernDex supports both the reviewed provider API and a legacy
      -- screenId/locations contract.  This integrated handle deliberately
      -- exposes only the provider seam: if resolve throws or returns an
      -- invalid value, the renderer must open the exact native TownMap rather
      -- than silently retrying VASC's own map through its legacy fields.
      exports={
        active=receipt.active,
        pokedexAreaProvider=provider,
      },
    }
  end
  return nil
end

-- The reviewed renderer historically asks its standalone option object for
-- `sprite_source`.  That private compatibility spelling never enters VASC's
-- schema/save: the bridge translates it to modernDexSpriteSource in memory.
local function featureMod(root)
  local feature = setmetatable({
    id="VOXEL_ASCENDANT",
    path=root.path,
    log=root.log,
  }, { __index=root })
  feature.options = {
    get=function(_, key)
      if key ~= "sprite_source" then return nil end
      local value = ModernDexHost.spriteSetting:get()
      return value == "active" and "auto" or value
    end,
  }
  feature.find = function(first, second)
    local id = first == feature and second or first
    if id == "vasc_kanto_fly_map" then return integratedAreaHandle(root) end
    if id == "VOXEL_ASCENDANT" then return root end
    return findThrough(root, id)
  end
  return feature
end

local function loadReviewedUi(root)
  local relative = "lib/ModernDex.lua"
  local source, readError = root:read(relative)
  if not source then
    return nil, ("missing %s: %s"):format(relative,
      tostring(readError or "unavailable"))
  end
  local chunk, compileError = (loadstring or load)(source,
    "@" .. tostring(root.path or "VOXEL_ASCENDANT") .. "/" .. relative)
  if not chunk then return nil, tostring(compileError) end
  local ok, ui = pcall(chunk, { mod=featureMod(root) })
  if not ok then return nil, tostring(ui) end
  if type(ui) ~= "table"
      or type(ui.ListScreen) ~= "table"
      or type(ui.ListScreen.new) ~= "function"
      or type(ui.EntryScreen) ~= "table"
      or type(ui.EntryScreen.new) ~= "function"
      or type(ui.AreaScreen) ~= "table"
      or type(ui.AreaScreen.new) ~= "function" then
    return nil, "reviewed ModernDex surface contract is incomplete"
  end
  return ui
end

local function nativeFactory(screenId)
  local ok, factory = pcall(require, "src.ui." .. screenId)
  if not ok or type(factory) ~= "table" or type(factory.new) ~= "function" then
    return nil, ok and "native screen factory is incomplete" or tostring(factory)
  end
  return factory
end

local function newNative(screenId, game, argument, ...)
  local factory, reason = nativeFactory(screenId)
  if not factory then return nil, reason end
  local ok, state = pcall(factory.new, game, argument, ...)
  if not ok or type(state) ~= "table" then
    return nil, ok and "native screen constructor returned no state"
      or tostring(state)
  end
  return state
end

local function callState(state, method, ...)
  local fn = state and state[method]
  if type(fn) ~= "function" then return nil end
  return fn(state, ...)
end

local function graphicsProtected(fn, state, ...)
  local graphics = love and love.graphics
  local originalPush = graphics and graphics.push
  local originalPop = graphics and graphics.pop
  if type(originalPush) ~= "function" or type(originalPop) ~= "function" then
    return pcall(fn, state, ...)
  end

  -- The reviewed AREA renderer has its own scissor push. If an image/provider
  -- call throws before that matching pop, a single outer pop would remove only
  -- the renderer frame and leak this host's push("all") into every later draw.
  -- Track every successful nested operation while the untrusted renderer owns
  -- the graphics table, then unwind exactly to our boundary before native draw.
  local pushed, pushError = pcall(originalPush, "all")
  if not pushed then pushed, pushError = pcall(originalPush) end
  if not pushed then
    return false, "Modern Pokedex graphics guard push failed: "
      .. tostring(pushError)
  end

  local depth = 1
  local function trackedPush(...)
    local values = packValues(originalPush(...))
    depth = depth + 1
    return unpackValues(values, 1, values.n)
  end
  local function trackedPop(...)
    if depth <= 1 then
      error("Modern Pokedex renderer crossed its graphics guard", 0)
    end
    local values = packValues(originalPop(...))
    depth = depth - 1
    return unpackValues(values, 1, values.n)
  end

  local instrumented, instrumentError = pcall(function()
    graphics.push = trackedPush
    graphics.pop = trackedPop
  end)
  if not instrumented then
    pcall(function()
      graphics.push = originalPush
      graphics.pop = originalPop
    end)
    pcall(originalPop)
    return false, "Modern Pokedex graphics guard could not be installed: "
      .. tostring(instrumentError)
  end

  local result = packValues(pcall(fn, state, ...))
  local restored, restoreError = pcall(function()
    graphics.push = originalPush
    graphics.pop = originalPop
  end)
  local cleanupError
  for _ = 1, depth do
    local ok, reason = pcall(originalPop)
    if not ok then
      cleanupError = reason
      break
    end
  end
  if not restored or cleanupError ~= nil then
    return false, "Modern Pokedex graphics guard cleanup failed: "
      .. tostring(restoreError or cleanupError)
  end
  return unpackValues(result, 1, result.n)
end

-- The reviewed ModernDex renderer already authors one complete 512x288
-- surface. Enrol it in the same mobile-only HUD owner used by Team and Box.
-- Desktop attach remains a hard no-op, and a native fallback releases the
-- presentation owner on the next pass.
local function mobilePresentation(state)
  if type(state) ~= "table"
      or type(MobileMenuPresentation) ~= "table"
      or type(MobileMenuPresentation.attach) ~= "function" then
    return state
  end
  MobileMenuPresentation.attach(state, {
    owner="pokedex",
    logicalSize=function(screen)
      if type(screen.uiSize) == "function" then
        local ok, width, height = pcall(screen.uiSize, screen)
        if ok and tonumber(width) and tonumber(height)
            and width > 0 and height > 0 then return width, height end
      end
      return 512, 288
    end,
    enabled=function(screen)
      return rawget(screen, "__vascModernDexNative") == nil
    end,
    backdrop={ 12/255, 24/255, 40/255, 1 },
  })
  return state
end

local function guardState(screenId, game, argument, state, ...)
  local nativeTail = packValues(...)
  local original = {
    draw=state.draw,
    update=state.update,
    uiSize=state.uiSize,
    sgbPalettes=state.sgbPalettes,
    wantsFillScale=state.wantsFillScale,
  }
  local failed = false

  local function activateNative(self, phase, reason)
    if self.__vascModernDexNative then return self.__vascModernDexNative end
    if failed then return nil end
    failed = true
    local native, nativeReason = newNative(screenId, game, argument,
      unpackValues(nativeTail, 1, nativeTail.n))
    if not native then
      log("error", "Modern Pokedex %s failed during %s (%s); native fallback could not be constructed (%s)",
        screenId, phase, tostring(reason), tostring(nativeReason))
      return nil
    end
    native.screenId = self.screenId or native.screenId or screenId
    self.__vascModernDexNative = native
    self.__vascModernDexFailedOpen = true
    self.__vascModernDexFailPhase = phase
    self.__vascModernDexFailReason = tostring(reason)
    log("warn", "Modern Pokedex %s failed during %s (%s); using exact native screen",
      screenId, phase, tostring(reason))
    return native
  end

  if type(original.update) == "function" then
    state.update = function(self, ...)
      if self.__vascModernDexNative then
        return callState(self.__vascModernDexNative, "update", ...)
      end
      local result = packValues(pcall(original.update, self, ...))
      if result[1] then return unpackValues(result, 2, result.n) end
      local native = activateNative(self, "update", result[2])
      return callState(native, "update", ...)
    end
  end

  if type(original.draw) == "function" then
    state.draw = function(self, ...)
      if self.__vascModernDexNative then
        return callState(self.__vascModernDexNative, "draw", ...)
      end
      local result = packValues(graphicsProtected(original.draw, self, ...))
      if result[1] then return unpackValues(result, 2, result.n) end
      local native = activateNative(self, "draw", result[2])
      return callState(native, "draw", ...)
    end
  end

  state.uiSize = function(self)
    if self.__vascModernDexNative then
      local fn = self.__vascModernDexNative.uiSize
      if type(fn) == "function" then return fn(self.__vascModernDexNative) end
      return 160, 144
    end
    if type(original.uiSize) == "function" then
      local ok, width, height = pcall(original.uiSize, self)
      if ok and tonumber(width) and tonumber(height) then return width, height end
      activateNative(self, "uiSize", ok and "invalid dimensions" or width)
      return 160, 144
    end
    return 512, 288
  end

  state.sgbPalettes = function(self, ...)
    if self.__vascModernDexNative then
      return callState(self.__vascModernDexNative, "sgbPalettes", ...)
    end
    if type(original.sgbPalettes) ~= "function" then return nil end
    local result = packValues(pcall(original.sgbPalettes, self, ...))
    if result[1] then return unpackValues(result, 2, result.n) end
    local native = activateNative(self, "sgbPalettes", result[2])
    return callState(native, "sgbPalettes", ...)
  end

  -- Gen 1's Renderer uses this public marker to choose the largest
  -- aspect-preserving scale instead of the fixed whole-pixel zoom.  The
  -- reviewed 512x288 Dex otherwise occupies only the last integer step on a
  -- high-resolution display, leaving the conspicuous outer margin reported
  -- in fullscreen.  Native fallback restores the engine owner's own policy.
  state.wantsFillScale = function(self, ...)
    if self.__vascModernDexNative then
      local fn = self.__vascModernDexNative.wantsFillScale
      return type(fn) == "function" and fn(self.__vascModernDexNative, ...)
        or false
    end
    return true
  end

  return mobilePresentation(state)
end

local function nativeArea(game, species, phase, reason)
  local native, nativeReason = newNative("TownMap", game,
    { nestSpecies=species })
  if native then
    if reason ~= nil then
      log("warn", "Modern Pokedex AREA failed during %s (%s); using exact native TownMap",
        tostring(phase or "construction"), tostring(reason))
    end
    return native
  end
  log("error", "Modern Pokedex AREA native fallback could not be constructed after %s (%s): %s",
    tostring(phase or "construction"), tostring(reason), tostring(nativeReason))
  return nil, nativeReason
end

-- openArea() closes over UI.AreaScreen, so replacing only its constructor
-- adds the VASC boundary without changing a byte of the reviewed renderer.
-- No provider means the exact native AREA immediately. A valid integrated
-- provider may use the private widescreen shell; every later method failure
-- delegates to a native TownMap built with the original nestSpecies.
local function bindAreaBoundary(ui, root)
  local originalNew = ui and ui.AreaScreen and ui.AreaScreen.new
  if type(originalNew) ~= "function" then
    return false, "ModernDex AREA constructor is unavailable"
  end
  ui.AreaScreen.new = function(game, species, lang)
    if not integratedAreaHandle(root) then
      return nativeArea(game, species, "provider", "unavailable")
    end
    local ok, state = pcall(originalNew, game, species, lang)
    if not ok or type(state) ~= "table" then
      return nativeArea(game, species, "construction",
        ok and "constructor returned no state" or state)
    end
    -- providerArea() deliberately contains thrown/invalid providers. In that
    -- case the reviewed source has already constructed the exact native map;
    -- return it directly instead of wrapping it in the widescreen shell.
    if state.mapArea == nil then
      if type(state.native) == "table" then return state.native end
      return nativeArea(game, species, "provider", "invalid result")
    end
    state.__vascModernDexAreaHostGuard = true
    return guardState("TownMap", game, { nestSpecies=species }, state)
  end
  return true
end

-- DexEntryMenu's native constructor accepts an optional completion callback.
-- The reviewed renderer predates that third argument and pops itself directly,
-- so preserve the host API here without changing the byte-pinned renderer.
-- Calling after the successful pop matches the native ordering exactly.
local function bindEntryCompletion(state, game, onDone)
  if type(onDone) ~= "function" or type(state.update) ~= "function" then
    return state
  end
  local innerUpdate = state.update
  local completed = false
  state.update = function(self, ...)
    local stack = game and game.stack
    local top = stack and stack.top
    local before = type(top) == "function" and top(stack) or nil
    local result = packValues(innerUpdate(self, ...))
    local after = type(top) == "function" and top(stack) or nil
    -- A runtime fallback delegates to the exact native state with the same
    -- onDone parameter. That native owner invokes it; the outer custom shell
    -- must not synthesize a second completion for the same pop.
    if not self.__vascModernDexNative
        and not completed and before == self and after ~= self then
      completed = true
      onDone()
    end
    return unpackValues(result, 1, result.n)
  end
  return state
end

local function customState(ui, screenId, game, argument, ...)
  local nativeTail = packValues(...)
  if ModernDexHost.styleSetting:get() == "game" then
    return newNative(screenId, game, argument,
      unpackValues(nativeTail, 1, nativeTail.n))
  end
  local class = screenId == "PokedexMenu" and ui.ListScreen or ui.EntryScreen
  local ok, state = pcall(class.new, game, argument)
  if ok and type(state) == "table" then
    local guarded = guardState(screenId, game, argument, state,
      unpackValues(nativeTail, 1, nativeTail.n))
    if screenId == "DexEntryMenu" then
      bindEntryCompletion(guarded, game, nativeTail[1])
    end
    return guarded
  end
  log("warn", "Modern Pokedex %s construction failed (%s); using exact native screen",
    screenId, tostring(state))
  return newNative(screenId, game, argument,
    unpackValues(nativeTail, 1, nativeTail.n))
end

function ModernDexHost.install()
  local root = V.mod
  root.exports = root.exports or {}
  if type(root.exports.modernDex) == "table"
      and root.exports.modernDex.active == true then
    return true, root.exports.modernDex
  end
  local screens = root.content and root.content.screens
  if not screens or type(screens.override) ~= "function" then
    return false, "screen override registry unavailable"
  end
  local ui, reason = loadReviewedUi(root)
  if not ui then return false, reason end
  local areaBound, areaReason = bindAreaBoundary(ui, root)
  if not areaBound then return false, areaReason end

  screens:override("PokedexMenu", {
    new=function(game, opts)
      local state, fallbackReason = customState(ui, "PokedexMenu", game, opts)
      if state then return state end
      error("native PokedexMenu unavailable: " .. tostring(fallbackReason), 0)
    end,
  })
  screens:override("DexEntryMenu", {
    new=function(game, speciesOrOpts, onDone)
      local state, fallbackReason = customState(ui, "DexEntryMenu", game,
        speciesOrOpts, onDone)
      if state then return state end
      error("native DexEntryMenu unavailable: " .. tostring(fallbackReason), 0)
    end,
  })

  local receipt = {
    apiVersion=1,
    active=true,
    owner="VOXEL_ASCENDANT",
    bundled=true,
    sourceVersion="0.4.0",
    sourceArchiveSha256=
      "31644f8f054f62d3821a1a71e96fca866a2f8b768545dba149bbee64644b14ef",
    sourceRendererSha256=
      "54a8876aa9af58ae912a93ded8590241a7adfa8aa119cf92919b623180d7356d",
    screens={ "PokedexMenu", "DexEntryMenu", "VascDexArea" },
    mapOwner="VOXEL_ASCENDANT:kantoFlyMap",
    mode=function() return ModernDexHost.styleSetting:get() end,
    spriteSource=function() return ModernDexHost.spriteSetting:get() end,
  }
  -- Public, presentation-only opener for companion menus which registered a
  -- private screen id and therefore bypass Gen1Recomp's PokedexMenu override.
  -- KASC 6.5.x's NATIONALDEX does exactly that.  Construct through the same
  -- guarded owner used by the engine screen and push only a complete state;
  -- callers retain their original callback as a fail-open path.
  receipt.open = function(game, opts)
    local stack = game and game.stack
    if not (stack and type(stack.push) == "function") then
      return false, "game stack unavailable"
    end
    local state, openReason = customState(ui, "PokedexMenu", game, opts)
    if not state then return false, openReason end
    local ok, pushReason = pcall(stack.push, stack, state)
    if not ok then return false, tostring(pushReason) end
    return true, state
  end
  root.exports.modernDex = receipt
  return true, receipt
end

ModernDexHost._featureMod = featureMod
ModernDexHost._integratedAreaHandle = integratedAreaHandle
ModernDexHost._guardState = guardState
ModernDexHost._customState = customState
ModernDexHost._loadReviewedUi = loadReviewedUi
ModernDexHost._bindAreaBoundary = bindAreaBoundary

return ModernDexHost
