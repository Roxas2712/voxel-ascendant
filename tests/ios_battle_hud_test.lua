-- Cross-mod regression for VASC + KASC 6.5.17 + Gen1Recomp on iOS.
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

local function fixture(osName, loveOS, hudMode, hudScale)
  local calls = {
    layerTexture = 0,
    panel = 0,
    setCanvas = 0,
    newQuad = 0,
    draw = 0,
    innerHUD = 0,
    innerText = 0,
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
    _os = loveOS,
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

  package.loaded["src.core.Platform"] = nil
  if osName == "__missing__" then
    package.preload["src.core.Platform"] = function()
      error("src.core.Platform unavailable")
    end
  else
    local Platform = {
      detect = function() return { os = osName } end,
    }
    package.preload["src.core.Platform"] = function() return Platform end
  end

  local BattleHud = {}
  function BattleHud.position() return hudMode or "edges" end
  function BattleHud.scale() return hudScale or 1 end
  function BattleHud.edgeInset() return 0 end
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
    BattlePartyBalls = {
      PERSISTENT_RECT={ enemy={8,34,48,10}, player={104,48,48,10} },
      persistentLive=function(battle, side)
        return not battle.introBalls
          and battle[side == "enemy" and "enemyParty" or "playerParty"] ~= nil
      end,
      drawPersistent=function() end,
    },
    BattlePics = {},
    CanvasPresentation = {
      preflips=function(os) return os == "iOS" end,
      begin2D=function(g, h)
        if g.translate and g.scale then g.translate(0, h); g.scale(1, -1) end
        return true
      end,
    },
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
    drawTextArea = function()
      calls.innerText = calls.innerText + 1
    end,
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
  local OverworldBattlePublic = assert(loadfile(
    "lib/adapters/gen1/OverworldBattlePublic.lua"))()
  local PublicFacade = assert(loadfile("lib/PublicFacade.lua"))()
  local publicLib = PublicFacade.new({
    OverworldBattle = OverworldBattlePublic.new(OverworldBattle),
  })
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

-- This path must point at the byte-exact public Kanto Ascendant 6.5.17
-- renderer_battle_hud.lua.  tests/test_contract.py verifies its release hash
-- before invoking this harness; keeping it outside this repository prevents a
-- hand-maintained miniature from silently drifting away from production.
local kascSource = arg and arg[1]
check(type(kascSource) == "string" and kascSource ~= "",
  "pass the public KASC 6.5.17 renderer_battle_hud.lua as argv[1]")
local kascFactory = assert(loadfile(kascSource))()

-- Portrait STACK is one deliberate vertical hierarchy, not three pieces of
-- furniture competing for the phone's lower edge: foe HUD, clear fight,
-- player HUD, then message/command frame. Messages use that same bottom
-- anchor so rotating mid-battle cannot reintroduce the old overlap.
local androidPortrait = fixture("Android", nil, "stacked", 1)
androidPortrait.shot.pw = 412
androidPortrait.shot.ph = 915
androidPortrait.shot.scale = 2
androidPortrait.shot.lx = 46
androidPortrait.shot.ly = 313
local portraitCommand = androidPortrait.ownerOverworldBattle.textPlacements(
  { phase="menu" }, androidPortrait.shot)
eq(#portraitCommand, 3,
  "portrait command frame keeps the contiguous three-piece silhouette")
eq(portraitCommand[1].target[2], 801,
  "portrait command frame docks at the phone's safe bottom edge")
local portraitRects = androidPortrait.ownerOverworldBattle.snapRects(
  androidPortrait.shot, portraitCommand)
eq(portraitRects.enemy[2], 37,
  "portrait enemy status docks at the safe top edge")
eq(portraitRects.player[2], 710,
  "portrait player status docks immediately above command furniture")
check(portraitRects.player[2] + portraitRects.player[4]
      < portraitCommand[1].target[2],
  "portrait player status no longer overlaps the command frame")
local portraitMessage = androidPortrait.ownerOverworldBattle.textPlacements(
  { phase="messages" }, androidPortrait.shot)
eq(portraitMessage[1].target[1], 46,
  "portrait message frame remains centred at native pixel scale")
eq(portraitMessage[1].target[2], 801,
  "portrait message frame shares the safe bottom baseline")

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
-- companions on iOS never see it.  That makes the real KASC 6.5.17 capability
-- check fail before it can install panel suppression/recovery.
local ios = fixture("iOS")
check(ios.OverworldBattle ~= ios.ownerOverworldBattle,
  "iOS public facade leaked the owner module identity")
eq(type(ios.OverworldBattle.snapHUDs), "nil",
  "iOS module does not advertise snapHUDs")
local originalSideTexture = ios.ownerOverworldBattle.sideTexture
local originalHudTexture = ios.ownerOverworldBattle.hudTexture
local sideReplacement = function() return "companion-side" end
local hudReplacement = function() return "companion-hud" end
ios.OverworldBattle.sideTexture = sideReplacement
ios.OverworldBattle.hudTexture = hudReplacement
eq(ios.ownerOverworldBattle.sideTexture, originalSideTexture,
  "public sideTexture wrapper changed the private owner identity")
eq(ios.ownerOverworldBattle.hudTexture, originalHudTexture,
  "public hudTexture wrapper changed the private owner identity")
eq(ios.OverworldBattle.sideTexture(), "companion-side",
  "public sideTexture wrapper is not observable through the legacy facade")
eq(ios.OverworldBattle.hudTexture(), "companion-hud",
  "public hudTexture wrapper is not observable through the legacy facade")
ios.OverworldBattle.sideTexture = nil
ios.OverworldBattle.hudTexture = nil
local iosPanels = ios.OverworldBattle.drawHudPanels
local iosHUDs = ios.BattleState.drawHUDs
local iosKasc, emitIOS = installExactKasc(ios)
local iosInspection = iosKasc.inspect()
eq(iosInspection.profile, "RENDERER_NATIVE",
  "KASC 6.5.17 selects renderer-native HUD on iOS")
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
local slidingParty = ios.ownerOverworldBattle.partyRects(ios.battle, 4)
eq(next(slidingParty), nil,
  "intro slide must not receive empty party-ball glass")
local landedParty = ios.ownerOverworldBattle.partyRects(ios.battle, 0)
check(landedParty.player ~= nil,
  "landed intro keeps the player party-ball panel")
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

-- Public Gen1Recomp currently has no src.core.Platform module. LÖVE's
-- sandbox-safe bootstrap receipt must therefore recover the desktop edge
-- compositor rather than reproducing the centered 2.0.1 HUD everywhere.
local loveDesktop = fixture("__missing__", "OS X")
eq(type(loveDesktop.OverworldBattle.snapHUDs), "function",
  "LÖVE bootstrap receipt recovers the edge compositor")

-- On an explicitly detected desktop the exported compatibility module remains
-- the owner table and KASC can still select and install its established
-- cooperative wide-HUD path.
local desktop = fixture("OS X")
local snappedRects, snappedPlacement =
  desktop.ownerOverworldBattle.snapRects(desktop.shot)
eq(snappedPlacement.enemy.x, 0,
  "enemy source band was shifted outside the wide framebuffer")
eq(snappedRects.enemy[1], 0,
  "enemy readable glass no longer starts at the safe left edge")
eq(snappedRects.enemy[3], (8 + 80) * desktop.shot.scale,
  "enemy readable glass no longer covers the leading name glyphs")
local commandLayout = desktop.ownerOverworldBattle.textPlacements(
  { phase="menu" }, desktop.shot)
eq(#commandLayout, 3,
  "wide command menu uses a left cap, elastic empty rail and native commands")
eq(commandLayout[1].target[1], 60, "command frame left safe inset")
eq(commandLayout[1].target[1] + commandLayout[1].target[3],
   commandLayout[2].target[1],
  "left command-frame cap meets the empty rail")
eq(commandLayout[2].target[1] + commandLayout[2].target[3],
   commandLayout[3].target[1],
  "empty command rail meets the four-command pane without a middle gap")
eq(commandLayout[2].source[3], 1,
  "only one empty source column is widened across the spare rail")
eq(commandLayout[3].target[1] + commandLayout[3].target[3], 2340,
  "right command pane safe inset")
eq(commandLayout[1].target[2], commandLayout[3].target[2],
  "complete command frame shares one bottom baseline")
local receiptBattle = {
  phase="menu", introBalls=false,
  enemyParty={ { hp=1 } }, playerParty={ { hp=1 } },
}
local receiptRects, receiptBands =
  desktop.ownerOverworldBattle.snapRects(desktop.shot, commandLayout)
local receipts = desktop.ownerOverworldBattle.persistentPartyPlacements(
  receiptBattle, desktop.shot, 0, receiptRects, receiptBands, commandLayout)
eq(#receipts, 2, "both persistent team receipts receive a fallback target")
eq(receipts[1].side, "enemy", "enemy receipt order")
eq(receipts[2].side, "player", "player receipt order")
check(receipts[2].target[2] >= receiptRects.player[2]
      + receiptRects.player[4],
  "player team receipt overlaps its HP card")
check(receipts[2].target[2] + receipts[2].target[4]
      <= commandLayout[1].target[2],
  "player team receipt no longer fits between HP and command furniture")
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
local wrappedMegaMon = {
  species = "CHARIZARD", _ascMegaForm = "CHARIZARD_X",
}
local wrappedMegaBattler = { mon=wrappedMegaMon, sprite="mega-sprite" }
local wrappedMegaBattle = {
  data = { pokemon = {
    CHARIZARD = { dexEntry = { heightFt = 5, heightIn = 7 } },
  } },
  player = wrappedMegaBattler,
}
local wrappedMega = desktop.ownerOverworldBattle.finalizeSideTexture(
  wrappedMegaBattle, "player", {
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
eq(wrappedMega.vascRenderTextureToken, wrappedMegaMon,
  "companion Mega render token used an animation-frame source")
local wrappedMegaFrameA = desktop.ownerOverworldBattle.finalizeSideTexture(
  wrappedMegaBattle, "player", {
    canvas={}, kantoAscendantMegaSupersampled=true,
    kantoAscendantMegaSource="assets/mega_animated/charizard_x/001.png",
  })
local wrappedMegaFrameB = desktop.ownerOverworldBattle.finalizeSideTexture(
  wrappedMegaBattle, "player", {
    canvas={}, kantoAscendantMegaSupersampled=true,
    kantoAscendantMegaSource="assets/mega_animated/charizard_x/002.png",
  })
eq(wrappedMegaFrameA.vascRenderTextureToken, wrappedMegaMon,
  "first animated Mega frame replaced semantic deployment identity")
eq(wrappedMegaFrameB.vascRenderTextureToken, wrappedMegaMon,
  "second animated Mega frame replaced semantic deployment identity")
check(wrappedMegaFrameA.inkIdentity ~= wrappedMegaFrameB.inkIdentity,
  "animated Mega frames lost their distinct alpha-content identities")
eq(wrappedMegaFrameA.vascRenderModelKey,
  wrappedMegaFrameB.vascRenderModelKey,
  "animated Mega frames changed the form-level model identity")
local trainerFilter
local wrappedTrainer = desktop.ownerOverworldBattle.finalizeSideTexture({
  player = { sprite = "active-pokemon" },
}, "player", {
  canvas = { setFilter = function(_, min, mag)
    trainerFilter = min .. "/" .. mag
  end },
  trainer = false,
  ascendantHighResTrainer = true,
  ascendantTrainerSourceScale = 2,
  ascendantHighResSource = "assets/characters/green_voxel_front_hd.png",
  ascendantStandingTrainer = "green",
  ascendantApprovedTrainerResolver = "kasc-public-receipt",
})
eq(wrappedTrainer.trainerArt, true,
  "mirrored KASC player standee lost its trainer presentation role")
eq(wrappedTrainer.inkIdentity,
  "assets/characters/green_voxel_front_hd.png",
  "KASC trainer alpha cache used the active Pokemon identity")
eq(wrappedTrainer.vascRenderTextureToken,
  "assets/characters/green_voxel_front_hd.png",
  "KASC trainer render token lost its stable source identity")
eq(wrappedTrainer.heightIn, nil,
  "KASC trainer inherited the active Pokemon's physical height")
eq(wrappedTrainer.ascendantTrainerSourceScale, 2,
  "KASC trainer source-density receipt was not preserved")
eq(wrappedTrainer.ascendantStandingTrainer, "green",
  "KASC trainer identity receipt was not preserved")
eq(wrappedTrainer.ascendantApprovedTrainerResolver, "kasc-public-receipt",
  "KASC approved-resolver receipt was not preserved")
eq(trainerFilter, "nearest/nearest",
  "KASC HD trainer canvas did not retain nearest sampling")
local animatedMon = { species="PIKACHU" }
local animatedBattler = { mon=animatedMon, sprite={} }
local animatedBattle = { player=animatedBattler }
local animatedA = desktop.ownerOverworldBattle.finalizeSideTexture(
  animatedBattle, "player", { canvas={}, inkIdentity={} })
local animatedB = desktop.ownerOverworldBattle.finalizeSideTexture(
  animatedBattle, "player", { canvas={}, inkIdentity={} })
eq(animatedA.vascRenderTextureToken, animatedMon,
  "ordinary Pokemon render token used its ephemeral animation frame")
eq(animatedB.vascRenderTextureToken, animatedMon,
  "ordinary Pokemon animation changed its deployment token")
check(desktop.OverworldBattle ~= desktop.ownerOverworldBattle,
  "desktop public facade leaked the owner module identity")
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
local vascReceipt = desktop.ownerOverworldBattle.hudSnapReceipt(desktop.battle)
eq(vascReceipt.shot, desktop.shot,
  "VASC did not retain the exact shot identity it composited")
eq(vascReceipt.snapped, true,
  "VASC did not retain successful ownership of the wide HUD frame")
eq(desktop.calls.layerTexture, 2,
  "desktop separates status bands from overlapping battle text")
check(desktop.calls.panel > 0, "desktop draws HUD/text panels")
check(desktop.calls.draw > 0, "desktop composites HUD bands")
check(desktop.calls.setCanvas > 0, "desktop visits its offscreen/world canvases")
desktop.battle.voxelAscendantShot = desktop.shot
local nativeHudBefore = desktop.calls.innerHUD
desktop.BattleState.drawHUDs(desktop.battle, 0)
eq(desktop.calls.innerHUD, nativeHudBefore,
  "KASC/VASC chain redrew the centred native HUD after a successful snap")
local nativeTextBefore = desktop.calls.innerText
desktop.BattleState.drawTextArea(desktop.battle)
eq(desktop.calls.innerText, nativeTextBefore,
  "centred opaque command/text frame survived beside the wide VASC frame")

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

print("ok iOS companion capability gate and KASC 6.5.17 HUD isolation")
