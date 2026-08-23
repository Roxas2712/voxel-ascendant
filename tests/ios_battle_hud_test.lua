-- Cross-mod regression for VASC + KASC 6.5.6 + Gen1Recomp 0.1.90 on iOS.
--
-- Merely returning false from public snapHUDs is too late.  KASC sees the
-- function during capability negotiation, installs its compact-panel bridge,
-- and restores those panels from inside Gen1's colorized drawHUDs pass while
-- bgCanvas is bound.  During the wild-intro ball row, VASC's old hudLive
-- mirror then produced an empty 80x32 enemy panel which the zone shader turned
-- GREENBAR green.  The iOS companion view must hide the unsafe capability so
-- KASC declines before installing either wrapper.

local function check(value, message)
  if not value then error("FAIL " .. message, 2) end
end

local function eq(actual, expected, message)
  if actual ~= expected then
    error(("FAIL %s (got %s, expected %s)")
      :format(message, tostring(actual), tostring(expected)), 2)
  end
end

local function fixture(osName)
  local calls = {
    layerTexture = 0,
    panel = 0,
    setCanvas = 0,
    newQuad = 0,
    draw = 0,
    innerHUD = 0,
    hudTargets = {},
    engineEnemy = {},
    enginePlayer = {},
    panelRects = {},
    panelTargets = {},
  }

  local screenCanvas = { name = "ui" }
  local bgCanvas = { name = "battle-bg" }
  local worldCanvas = { name = "world" }
  local hudLayer = {
    name = "hud-layer",
    getWidth = function() return 160 end,
    getHeight = function() return 144 end,
  }
  local currentCanvas = screenCanvas

  -- Preserve the headless runner's event module; the fixture replaces only
  -- graphics, and the runner still needs love.event.quit after this file ends.
  local runnerEvent = love and love.event
  _G.love = {
    event = runnerEvent,
    graphics = {
      getCanvas = function() return currentCanvas end,
      setCanvas = function(canvas)
        calls.setCanvas = calls.setCanvas + 1
        currentCanvas = canvas or nil
      end,
      getBlendMode = function() return "alpha", "alphamultiply" end,
      setBlendMode = function() end,
      setColor = function() end,
      clear = function() end,
      getColor = function() return 1, 1, 1, 1 end,
      rectangle = function() end,
      newQuad = function(x, y, w, h, tw, th)
        calls.newQuad = calls.newQuad + 1
        return { x = x, y = y, w = w, h = h, tw = tw, th = th }
      end,
      draw = function()
        calls.draw = calls.draw + 1
      end,
    },
  }

  local Platform = {
    detect = function() return { os = osName } end,
  }
  package.loaded["src.core.Platform"] = nil
  package.preload["src.core.Platform"] = function() return Platform end

  local BattleHud = {}
  function BattleHud.layerTexture(_, _, drawHUD)
    calls.layerTexture = calls.layerTexture + 1
    local previous = currentCanvas
    love.graphics.setCanvas(hudLayer)
    drawHUD()
    love.graphics.setCanvas(previous)
    return hudLayer
  end
  function BattleHud.panel(rect)
    calls.panel = calls.panel + 1
    calls.panelRects[#calls.panelRects + 1] = rect
    calls.panelTargets[#calls.panelTargets + 1] = currentCanvas
    return true
  end

  local ModSetting = {}
  function ModSetting.new()
    return {
      get = function() return true end,
      setIndex = function() end,
    }
  end

  local modules = {
    ModSetting = ModSetting,
    BattleArena = { find = function() return nil end },
    BattleCam = { reset = function() end, update = function() end },
    BattleScene = { GB_W = 160, GB_H = 144 },
    BattleDOF = {},
    BattleHud = BattleHud,
    BattlePics = {},
    Voxel3D = {},
    ChunkMesher = {},
  }
  local V = {
    require = function(name)
      local module = modules[name]
      check(module ~= nil, "fixture supplies V.require(" .. tostring(name) .. ")")
      return module
    end,
    mod = { log = { warn = function() end } },
  }

  local OverworldState = {
    pushBattle = function() end,
  }
  local BattleState = {
    resolveBattleScale = function() return 1 end,
    picImage = function(_, image) return image end,
    backPlacement = function() return 0, 0 end,
    frontPlacement = function() return 0, 0 end,
    draw = function() end,
    drawPicsLayer = function() end,
    drawTextArea = function() end,
    drawAnimLayer = function() end,
    drawZonePass = function() end,
    statusHUDVisible = function() return true end,
    drawHUDs = function(self, slide)
      calls.innerHUD = calls.innerHUD + 1
      calls.hudTargets[#calls.hudTargets + 1] = currentCanvas
      -- Exact Gen1Recomp 0.1.90 status gates relevant to the photographed
      -- wild-intro frame.  The party balls are live, but both HP/status HUDs
      -- intentionally remain absent until the send-out text is dismissed.
      local showStatus = self:statusHUDVisible()
      calls.engineEnemy[#calls.engineEnemy + 1] = showStatus
        and self.enemy and not self.showEnemyTrainer
        and not self.enemySendingOut and not self:growInScale(self.enemy)
        and slide == 0 and not self.introBalls and not self.enemy.fainted
        and true or false
      calls.enginePlayer[#calls.enginePlayer + 1] = showStatus
        and self.player and not (self.safari or self.demo)
        and not self.showPlayerBack and slide == 0 and true or false
    end,
    fxHidden = function() return false end,
    growInScale = function() return false end,
  }
  package.loaded["src.world.OverworldController"] = nil
  package.loaded["src.battle.BattleState"] = nil
  package.loaded["src.core.Game"] = nil
  package.preload["src.world.OverworldController"] = function()
    return OverworldState
  end
  package.preload["src.battle.BattleState"] = function()
    return BattleState
  end
  package.preload["src.core.Game"] = function()
    return { renderer = { setWorldOverride = function() end } }
  end

  local chunk = assert(loadfile("lib/OverworldBattle.lua"))
  local OverworldBattle = chunk(V)
  check(OverworldBattle.install(), "battle hook fixture installs")
  local PublicFacade = assert(loadfile("lib/PublicFacade.lua"))()
  local publicLib = PublicFacade.new({ OverworldBattle = OverworldBattle })
  local exportedOverworldBattle = publicLib.require("OverworldBattle")

  local battle = setmetatable({
    enemy = { fainted = false },
    player = {},
    showEnemyTrainer = false,
    enemySendingOut = false,
    safari = false,
    demo = false,
    introSlide = 0,
    introBalls = true,
    phase = "messages",
    showPlayerBack = true,
  }, { __index = BattleState })
  local shot = {
    canvas = worldCanvas,
    scale = 7,
    pw = 2400,
    ph = 1080,
    lx = 640,
    ly = 36,
  }

  return {
    calls = calls,
    screenCanvas = screenCanvas,
    bgCanvas = bgCanvas,
    worldCanvas = worldCanvas,
    BattleState = BattleState,
    battle = battle,
    shot = shot,
    ownerOverworldBattle = OverworldBattle,
    OverworldBattle = exportedOverworldBattle,
    bindCanvas = function(value) currentCanvas = value end,
  }
end

-- This path must point at the byte-exact public Kanto Ascendant 6.5.6
-- renderer_battle_hud.lua.  tests/test_contract.py verifies its release hash
-- before invoking this harness; keeping it outside this repository prevents a
-- hand-maintained miniature from silently drifting away from production.
local kascSource = arg and arg[1]
check(type(kascSource) == "string" and kascSource ~= "",
  "pass the public KASC 6.5.6 renderer_battle_hud.lua as argv[1]")
local kascFactory = assert(loadfile(kascSource))()

local function installExactKasc(fx)
  local once, listeners = {}, {}
  local events = {}
  function events:once(name, callback)
    once[name] = once[name] or {}
    once[name][#once[name] + 1] = callback
  end
  function events:on(name, callback)
    listeners[name] = listeners[name] or {}
    listeners[name][#listeners[name] + 1] = callback
  end

  local mod = { events = events }
  local resolver = {}
  function resolver.module(_, name)
    eq(name, "OverworldBattle", "KASC resolves only the reviewed VASC module")
    return fx.OverworldBattle, "VOXEL_ASCENDANT", nil,
      { rendererVersion = "0.1.5" }
  end
  local service = kascFactory(mod, { voxelRenderer = resolver })

  local function emit(name, payload)
    local oneShot = once[name] or {}
    once[name] = nil
    for _, callback in ipairs(oneShot) do callback(payload) end
    for _, callback in ipairs(listeners[name] or {}) do callback(payload) end
  end

  emit("mods.loaded", { game = {} })
  return service, emit
end

local function hasPanel(calls, canvas, expected, first)
  for index = first or 1, #calls.panelTargets do
    local target = calls.panelTargets[index]
    local rect = calls.panelRects[index]
    if target == canvas and rect
        and rect[1] == expected[1] and rect[2] == expected[2]
        and rect[3] == expected[3] and rect[4] == expected[4] then
      return true
    end
  end
  return false
end

-- The historical helper is attached only on platforms where it is safe, so
-- companions on iOS never see it.  That makes the real KASC 6.5.6 capability
-- check fail before it can install panel suppression/recovery.
local ios = fixture("iOS")
eq(ios.OverworldBattle, ios.ownerOverworldBattle,
  "iOS public facade retains the owner module identity")
eq(type(ios.OverworldBattle.snapHUDs), "nil",
  "iOS module does not advertise snapHUDs")
local originalSideTexture = ios.ownerOverworldBattle.sideTexture
local originalHudTexture = ios.ownerOverworldBattle.hudTexture
local sideReplacement = function() return "companion-side" end
local hudReplacement = function() return "companion-hud" end
ios.OverworldBattle.sideTexture = sideReplacement
ios.OverworldBattle.hudTexture = hudReplacement
eq(ios.ownerOverworldBattle.sideTexture, sideReplacement,
  "public sideTexture mutations reach the owner module")
eq(ios.ownerOverworldBattle.hudTexture, hudReplacement,
  "public hudTexture mutations reach the owner module")
ios.ownerOverworldBattle.sideTexture = originalSideTexture
ios.ownerOverworldBattle.hudTexture = originalHudTexture
local iosPanels = ios.OverworldBattle.drawHudPanels
local iosHUDs = ios.BattleState.drawHUDs
local iosKasc, emitIOS = installExactKasc(ios)
local iosInspection = iosKasc.inspect()
eq(iosInspection.profile, "RENDERER_NATIVE",
  "KASC 6.5.6 selects renderer-native HUD on iOS")
eq(iosInspection.lastError, "wide-hud-capability-missing",
  "KASC declines the incomplete wide-HUD capability")
eq(rawget(ios.OverworldBattle, "__kascRendererBattleHudSnapHook"), nil,
  "KASC installs no snap receipt wrapper on iOS")
eq(rawget(ios.OverworldBattle, "__kascWideBattleHudPanelState"), nil,
  "KASC installs no compact-panel bridge on iOS")
eq(rawget(ios.BattleState, "__kascWideBattleHudState"), nil,
  "KASC installs no drawHUDs owner on iOS")
eq(ios.OverworldBattle.drawHudPanels, iosPanels,
  "iOS public panel function remains unwrapped")
eq(ios.BattleState.drawHUDs, iosHUDs,
  "iOS BattleState HUD chain remains VASC plus engine only")
emitIOS("game.ready", { game = {} })
iosInspection = iosKasc.inspect()
eq(iosInspection.profile, "RENDERER_NATIVE",
  "KASC game.ready refresh keeps the native iOS profile")
eq(ios.OverworldBattle.drawHudPanels, iosPanels,
  "KASC refresh still leaves the iOS panel function untouched")
eq(ios.BattleState.drawHUDs, iosHUDs,
  "KASC refresh still leaves the iOS HUD chain untouched")

-- Reproduce the screenshot state: wild mon visible, trainer back still up,
-- intro party balls active.  VASC lays panels on the UI before Gen1 binds its
-- grayscale bgCanvas.  No KASC fallback is now available to inject a panel
-- into bgCanvas, and the corrected visibility mirror rejects the empty enemy
-- panel outright.
ios.battle.voxelAscendantShot = ios.shot
ios.bindCanvas(ios.screenCanvas)
ios.ownerOverworldBattle.drawHudPanels(ios.battle)
ios.bindCanvas(ios.bgCanvas)
ios.BattleState.drawHUDs(ios.battle, 0)
eq(ios.calls.innerHUD, 1, "intro frame still delegates to Gen1 drawHUDs")
eq(ios.calls.engineEnemy[1], false,
  "Gen1 intentionally hides enemy HP during the intro-ball row")
eq(ios.calls.enginePlayer[1], false,
  "Gen1 intentionally hides player HP behind the trainer back")
eq(ios.ownerOverworldBattle.hudLive(ios.battle, 0), false,
  "VASC visibility mirror agrees that enemy status is not live")
check(not hasPanel(ios.calls, ios.bgCanvas, { 8, 0, 80, 32 }),
  "no empty enemy panel reaches the colorized bgCanvas")
check(not hasPanel(ios.calls, ios.screenCanvas, { 8, 0, 80, 32 }),
  "wild intro has no phantom enemy panel on the UI canvas")

-- Once the intro is over, both compact HP panels belong in VASC's normal UI
-- panel pass.  Gen1's glyphs are first baked into bgCanvas and then brought
-- upright through its zone pass; the KASC restore path must remain absent.
local steadyFirstPanel = #ios.calls.panelRects + 1
ios.battle.introBalls = false
ios.battle.showPlayerBack = false
ios.bindCanvas(ios.screenCanvas)
ios.ownerOverworldBattle.drawHudPanels(ios.battle)
ios.bindCanvas(ios.bgCanvas)
ios.BattleState.drawHUDs(ios.battle, 0)
eq(ios.calls.innerHUD, 2, "steady battle still delegates to Gen1 drawHUDs")
eq(ios.calls.engineEnemy[2], true,
  "enemy status glyphs become live after the intro")
eq(ios.calls.enginePlayer[2], true,
  "player status glyphs become live after the trainer back leaves")
check(hasPanel(ios.calls, ios.screenCanvas, { 8, 0, 80, 32 },
    steadyFirstPanel),
  "steady enemy panel is drawn on the upright UI canvas")
check(hasPanel(ios.calls, ios.screenCanvas, { 72, 56, 88, 40 },
    steadyFirstPanel),
  "steady player panel is drawn on the upright UI canvas")
check(not hasPanel(ios.calls, ios.bgCanvas, { 8, 0, 80, 32 },
    steadyFirstPanel),
  "steady enemy panel never enters colorized bgCanvas")
check(not hasPanel(ios.calls, ios.bgCanvas, { 72, 56, 88, 40 },
    steadyFirstPanel),
  "steady player panel never enters colorized bgCanvas")

-- A companion may suppress the native status HUD through Gen1's public
-- visibility hook.  VASC must mirror that verdict for both panel sides while
-- still allowing unrelated text glass to draw.
local hiddenFirstPanel = #ios.calls.panelRects + 1
ios.battle.statusHUDVisible = function() return false end
local hiddenEnemy, hiddenPlayer =
  ios.ownerOverworldBattle.hudLive(ios.battle, 0)
eq(hiddenEnemy, false, "hidden status suppresses enemy panel visibility")
eq(hiddenPlayer, false, "hidden status suppresses player panel visibility")
ios.bindCanvas(ios.screenCanvas)
ios.ownerOverworldBattle.drawHudPanels(ios.battle)
ios.bindCanvas(ios.bgCanvas)
ios.BattleState.drawHUDs(ios.battle, 0)
eq(ios.calls.engineEnemy[3], false,
  "Gen1 hidden-status verdict suppresses enemy glyphs")
eq(ios.calls.enginePlayer[3], false,
  "Gen1 hidden-status verdict suppresses player glyphs")
check(not hasPanel(ios.calls, ios.screenCanvas, { 8, 0, 80, 32 },
    hiddenFirstPanel),
  "hidden status draws no enemy panel")
check(not hasPanel(ios.calls, ios.screenCanvas, { 72, 56, 88, 40 },
    hiddenFirstPanel),
  "hidden status draws no player panel")
check(not hasPanel(ios.calls, ios.bgCanvas, { 8, 0, 80, 32 },
    hiddenFirstPanel),
  "hidden enemy panel cannot leak into bgCanvas")
check(not hasPanel(ios.calls, ios.bgCanvas, { 72, 56, 88, 40 },
    hiddenFirstPanel),
  "hidden player panel cannot leak into bgCanvas")

-- A missing or malformed platform receipt must fail closed as well.  Module
-- initialization happens before companions negotiate capabilities, so a
-- temporary detection failure must never be mistaken for a safe desktop.
local missingPlatform = fixture(nil)
eq(type(missingPlatform.OverworldBattle.snapHUDs), "nil",
  "missing platform receipt does not advertise the legacy snap seam")
local missingPanels = missingPlatform.OverworldBattle.drawHudPanels
local missingHUDs = missingPlatform.BattleState.drawHUDs
local missingKasc = installExactKasc(missingPlatform)
eq(missingKasc.inspect().profile, "RENDERER_NATIVE",
  "KASC keeps the native HUD when platform detection is unavailable")
eq(missingPlatform.OverworldBattle.drawHudPanels, missingPanels,
  "missing platform receipt leaves the panel seam unwrapped")
eq(missingPlatform.BattleState.drawHUDs, missingHUDs,
  "missing platform receipt leaves the engine HUD seam unwrapped")

local unknownPlatform = fixture("Unknown")
eq(type(unknownPlatform.OverworldBattle.snapHUDs), "nil",
  "Gen1's Unknown sentinel does not advertise the legacy snap seam")
local unknownPanels = unknownPlatform.OverworldBattle.drawHudPanels
local unknownHUDs = unknownPlatform.BattleState.drawHUDs
local unknownKasc = installExactKasc(unknownPlatform)
eq(unknownKasc.inspect().profile, "RENDERER_NATIVE",
  "KASC keeps the native HUD for Gen1's Unknown platform sentinel")
eq(unknownPlatform.OverworldBattle.drawHudPanels, unknownPanels,
  "Unknown sentinel leaves the panel seam unwrapped")
eq(unknownPlatform.BattleState.drawHUDs, unknownHUDs,
  "Unknown sentinel leaves the engine HUD seam unwrapped")

-- On an explicitly detected desktop the exported compatibility module remains
-- the owner table and KASC can still select and install its established
-- cooperative wide-HUD path.
local desktop = fixture("OS X")
eq(desktop.ownerOverworldBattle.battlerHeightIn({
  enemy = { def = { dexEntry = { heightFt = 5, heightIn = 7 } } },
}, "enemy"), 67, "canonical Charizard height is carried into its card")
eq(desktop.ownerOverworldBattle.battlerHeightIn({
  enemy = { def = { dexEntry = { heightFt = 1, heightIn = 0 } } },
}, "enemy"), 12, "canonical Rattata height is carried into its card")
eq(desktop.ownerOverworldBattle.battlerHeightIn({
  enemy = { def = { dexEntry = { heightFt = 1, heightIn = 12 } } },
}, "enemy"), nil, "malformed Pokédex height fails neutral")
eq(desktop.ownerOverworldBattle.battlerHeightIn({
  data = { pokemon = {
    CHARIZARD = { dexEntry = { heightFt = 5, heightIn = 7 } },
  } },
  player = { mon = { species = "CHARIZARD" }, def = {} },
}, "player"), 67,
  "form-only battle definition did not fall back to canonical species height")
local wrappedMega = desktop.ownerOverworldBattle.finalizeSideTexture({
  data = { pokemon = {
    CHARIZARD = { dexEntry = { heightFt = 5, heightIn = 7 } },
  } },
  player = { mon = { species = "CHARIZARD" }, sprite = "mega-sprite" },
}, "player", {
  trainer = true,
  kantoAscendantMegaSupersampled = true,
  kantoAscendantMegaSource = "assets/mega/mega_charizard_x_front.png",
})
eq(wrappedMega.trainer, false,
  "companion Mega card retained a transitional trainer role")
eq(wrappedMega.heightIn, 67,
  "companion Mega card lost canonical physical height after wrapping")
eq(wrappedMega.inkIdentity,
  "assets/mega/mega_charizard_x_front.png",
  "companion Mega card lost content-keyed alpha identity")
eq(desktop.OverworldBattle, desktop.ownerOverworldBattle,
  "desktop public facade retains the owner module identity")
eq(type(desktop.OverworldBattle.snapHUDs), "function",
  "desktop still advertises the cooperative snap seam")
desktop.ownerOverworldBattle.shot = function() return desktop.shot end
local desktopPanels = desktop.OverworldBattle.drawHudPanels
local desktopHUDs = desktop.BattleState.drawHUDs
local desktopSnap = desktop.OverworldBattle.snapHUDs
local desktopKasc = installExactKasc(desktop)
local desktopInspection = desktopKasc.inspect()
eq(desktopInspection.profile, "KASC_VASC_WIDE",
  "desktop KASC retains the wide VASC profile")
check(type(rawget(desktop.OverworldBattle,
    "__kascRendererBattleHudSnapHook")) == "table",
  "desktop KASC retains its snap receipt wrapper")
check(type(rawget(desktop.OverworldBattle,
    "__kascWideBattleHudPanelState")) == "table",
  "desktop KASC retains compact-panel suppression/recovery")
check(type(rawget(desktop.BattleState,
    "__kascWideBattleHudState")) == "table",
  "desktop KASC retains cooperative drawHUDs ownership")
check(desktop.OverworldBattle.snapHUDs ~= desktopSnap,
  "desktop snap seam is wrapped by exact KASC")
check(desktop.OverworldBattle.drawHudPanels ~= desktopPanels,
  "desktop panel seam is wrapped")
check(desktop.BattleState.drawHUDs ~= desktopHUDs,
  "desktop HUD seam is wrapped")
eq(desktop.OverworldBattle.snapHUDs(desktop.battle, desktop.shot), true,
   "desktop compatibility snap remains available")
eq(desktop.calls.layerTexture, 1, "desktop builds one HUD layer")
check(desktop.calls.panel > 0, "desktop draws HUD/text panels")
check(desktop.calls.draw > 0, "desktop composites HUD bands")
check(desktop.calls.setCanvas > 0, "desktop visits its offscreen/world canvases")

-- Kanto Ascendant's shared Mega renderer retains one historical staged-shot
-- marker.  VASC must publish the exact same shot there for the duration of a
-- staged frame, otherwise every Mega form paints a second classic rear sprite
-- and its opaque white paper over the arena.  Losing the shot must clear both
-- fields atomically so an ordinary 2D battle remains untouched.
desktop.battle:draw()
eq(desktop.battle.voxelAscendantShot, desktop.shot,
  "VASC publishes its live staged-shot marker")
eq(desktop.battle.dramaticShapeShot, desktop.shot,
  "all Mega forms see the shared historical staged-shot marker")
desktop.ownerOverworldBattle.shot = function() return nil end
desktop.battle:draw()
eq(desktop.battle.voxelAscendantShot, nil,
  "VASC clears its staged-shot marker when the arena is unavailable")
eq(desktop.battle.dramaticShapeShot, nil,
  "Mega compatibility marker cannot outlive the staged shot")

print("ok iOS companion capability gate and KASC 6.5.6 HUD isolation")
