-- Regression: Gen1Recomp 0.1.90 presents a render pipeline's worldOverride
-- with a negative Y scale on iOS/LÖVE 12.  A status HUD composited into that
-- canvas is therefore upside down even though the normal UI canvas remains
-- upright.  Kanto Ascendant calls the public snapHUDs helper, so the helper
-- itself (not only Voxel Ascendant's own update loop) must decline on iOS.

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
  }

  local screenCanvas = { name = "ui" }
  local worldCanvas = { name = "world" }
  local hudLayer = {
    name = "hud-layer",
    getWidth = function() return 160 end,
    getHeight = function() return 144 end,
  }
  local currentCanvas = screenCanvas

  _G.love = {
    graphics = {
      getCanvas = function() return currentCanvas end,
      setCanvas = function(canvas)
        calls.setCanvas = calls.setCanvas + 1
        currentCanvas = canvas or nil
      end,
      getBlendMode = function() return "alpha", "alphamultiply" end,
      setBlendMode = function() end,
      setColor = function() end,
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
  function BattleHud.panel()
    calls.panel = calls.panel + 1
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
    drawHUDs = function()
      calls.innerHUD = calls.innerHUD + 1
      calls.hudTargets[#calls.hudTargets + 1] = currentCanvas
    end,
    fxHidden = function() return false end,
    growInScale = function() return false end,
  }
  package.loaded["src.world.OverworldController"] = nil
  package.loaded["src.battle.BattleState"] = nil
  package.preload["src.world.OverworldController"] = function()
    return OverworldState
  end
  package.preload["src.battle.BattleState"] = function()
    return BattleState
  end

  local chunk = assert(loadfile("lib/OverworldBattle.lua"))
  local OverworldBattle = chunk(V)
  check(OverworldBattle.install(), "battle hook fixture installs")
  local PublicFacade = assert(loadfile("lib/PublicFacade.lua"))()
  local publicLib = PublicFacade.new({ OverworldBattle = OverworldBattle })
  local exportedOverworldBattle = publicLib.require("OverworldBattle")
  eq(exportedOverworldBattle, OverworldBattle,
     "public compatibility facade returns the guarded battle module")

  local battle = setmetatable({
    enemy = { fainted = false },
    player = {},
    showEnemyTrainer = false,
    enemySendingOut = false,
    showPlayerBack = false,
    safari = false,
    demo = false,
    introSlide = 0,
    phase = "command",
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
    worldCanvas = worldCanvas,
    BattleState = BattleState,
    battle = battle,
    shot = shot,
    OverworldBattle = exportedOverworldBattle,
  }
end

-- iOS must return before producing/copying a HUD texture or binding the
-- world canvas.  These are deliberately zero-work assertions: returning
-- false after touching the canvas would still risk a corrupt partial frame.
local ios = fixture("iOS")
eq(ios.OverworldBattle.snapHUDs(ios.battle, ios.shot), false,
   "iOS declines the world-canvas HUD composite")
eq(ios.calls.layerTexture, 0, "iOS creates no HUD layer")
eq(ios.calls.panel, 0, "iOS draws no frosted panel into the world")
eq(ios.calls.setCanvas, 0, "iOS never binds an offscreen/world canvas")
eq(ios.calls.newQuad, 0, "iOS creates no HUD-band quad")
eq(ios.calls.draw, 0, "iOS performs no world-canvas HUD draw")
eq(ios.calls.innerHUD, 0, "iOS does not pre-render the engine HUD")

-- KASC 6.5.6 receipt contract: its compatibility wrapper records whether the
-- exported seam really snapped this battle.  False makes KASC discard the
-- world-space overlay context; its separately tested panel bridge then falls
-- back to drawHUDs.  The installed VASC wrapper must let that normal draw
-- through on the upright UI canvas.
local KASC_SNAP_STATE = "__kascRendererBattleHudSnapReceipt"
local KASC_SNAP_SCHEMA = "ka-renderer-battle-hud-snap/v1"
local function kascSnap(overworldBattle, battle, ...)
  local shot = select(1, ...)
  if battle then
    battle[KASC_SNAP_STATE] = {
      schema = KASC_SNAP_SCHEMA,
      rendererId = "VOXEL_ASCENDANT",
      shot = shot,
      snapped = false,
      reason = "snap-pending",
    }
  end
  local snapped = overworldBattle.snapHUDs(battle, ...)
  if battle then
    battle[KASC_SNAP_STATE].snapped = snapped == true
    battle[KASC_SNAP_STATE].reason = snapped == true
      and nil or "snap-declined"
  end
  return snapped
end
local snapped = kascSnap(ios.OverworldBattle, ios.battle, ios.shot)
local receipt = rawget(ios.battle, KASC_SNAP_STATE)
eq(receipt.schema, KASC_SNAP_SCHEMA, "KASC receives its versioned receipt")
eq(receipt.shot, ios.shot, "KASC receipt is scoped to the current shot")
eq(receipt.snapped, false,
   "KASC records that the iOS HUD was not snapped")
eq(receipt.reason, "snap-declined", "KASC records a clean snap decline")
if not snapped then
  ios.battle.voxelAscendantShot = ios.shot
  ios.BattleState.drawHUDs(ios.battle, 0)
end
eq(ios.calls.innerHUD, 1, "declined KASC snap falls back to the engine HUD")
eq(ios.calls.hudTargets[1], ios.screenCanvas,
   "fallback HUD stays on the upright UI canvas")
eq(ios.calls.setCanvas, 0,
   "fallback never visits the vertically flipped world canvas")

-- The guard is deliberately iOS-only.  On desktop the exported compatibility
-- helper still performs the existing edge composite for callers that request
-- it, proving the test cannot pass through an unconditional early return.
local desktop = fixture("OS X")
eq(desktop.OverworldBattle.snapHUDs(desktop.battle, desktop.shot), true,
   "desktop compatibility snap remains available")
eq(desktop.calls.layerTexture, 1, "desktop builds one HUD layer")
check(desktop.calls.panel > 0, "desktop draws HUD/text panels")
check(desktop.calls.draw > 0, "desktop composites HUD bands")
check(desktop.calls.setCanvas > 0, "desktop visits its offscreen/world canvases")

print("ok iOS HUD snap guard and KASC fallback")
