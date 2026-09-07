-- The player's own camera controls: zoom everywhere, and the battle's orbit.
--
-- This mod has four cameras, and by the time a wheel notch arrives they all
-- want it. So one module owns the INPUTS and answers the only question that
-- matters -- which camera is this aimed at -- rather than each camera
-- growing its own wheel handler and racing the others for the event:
--
--   a staged battle      the camera the fight is shot with (BattleCam): the
--                        wheel and Q/E work its lens, and the right stick,
--                        a drag or the mouse walk it around the arena.
--
--   the 3RD rung         the boom behind the player's shoulder
--                        (ThirdPerson): the wheel, Q/E and a pinch let it
--                        out and pull it in.
--
--   an orbit rung        the engine's own survey zoom, which the wheel has
--                        always driven -- so here the module mostly gets
--                        out of the way, and only ADDS the two keys and the
--                        pinch that the engine has no handler for.
--
--   the 1ST rung         nothing. The eye is in the player's head; there is
--                        no distance to change, and a pinch there would
--                        silently wind the survey zoom for whenever they
--                        stepped back out. Inputs pass through untouched.
--
-- Every claim is answered by a GATE rather than by a mode flag, and every
-- wrap forwards whatever it does not claim -- so with voxel mode off, and
-- on every screen that is not the overworld or a battle, each byte flows
-- exactly where it always did.
--
-- Installed AFTER FirstPerson (see main.lua), which makes these wraps the
-- outer ones: a battle's controls get first refusal on the mouse and the
-- touch screen, which is right, because while a fight is staged the
-- free-roam look is not driving anyway.

-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local Voxel = V.require("VoxelState")
local Voxel3D = V.require("Voxel3D")
local FirstPerson = V.require("FirstPerson")
local ThirdPerson = V.require("ThirdPerson")
local BattleCam = V.require("BattleCam")
local DioramaZoom = V.require("DioramaZoom")
local BattleCinematic = V.require("BattleCinematic")

local CamControl = {}

-- ------- tuning
--
-- PINCH_SLACK is how far apart two fingers must travel, as a ratio of
-- their starting gap, before the gesture counts as a pinch at all -- below
-- it a two-finger tap wobbles rather than zooms.
--
-- SURVEY_PINCH is how many of the engine's integer survey steps one
-- doubling of the finger gap is worth. The survey ladder is coarse (whole
-- pixels per world pixel), so a pinch has to be geared down or the first
-- centimetre of travel crosses the whole range.
CamControl.PINCH_SLACK = 0.02
CamControl.SURVEY_PINCH = 2.2

-- ------- gates

-- A fight staged on the map, drawn and on screen. Asked of the shot rather
-- than of the battle state, because the shot is exactly "there is a 3D
-- battle in front of the player right now" -- with 3D-BTL off, or on a map
-- with no arena, the engine's own flat battle screen is up and its camera
-- is not ours to steer.
-- BACK SPRITES also closes it, through BattleCam.steerable: that setting
-- nails the player's own mon to the GB's slot on the menu while the foe
-- stands out on the map, and no camera angle holds a composition that is
-- half frame and half world (see BattleCam.steerable, which is where the
-- reasoning lives and which the RIG answers to as well -- so a stored
-- angle from before the setting was switched on stands down with it).
local function battleShot()
  local ok, shot = pcall(function()
    return V.require("OverworldBattle").shot()
  end)
  return ok and shot or nil
end

local function liveWorldBattle()
  local shot = battleShot()
  return shot and shot.liveWorld and true or false
end

local function battleLive()
  local shot = battleShot()
  if not shot then return false end
  -- Gold live-world battles use the normal voxel 1ST/3RD camera and never
  -- initialise BattleCam.steerable. Requiring that legacy staged-camera flag
  -- made every Android battle drag fail closed in v0.1.99.
  if shot.liveWorld then return true end
  return BattleCam.steerable and true or false
end

CamControl.battleLive = battleLive
CamControl.liveWorldBattle = liveWorldBattle

-- The free-roam overworld, with the 3D pass carrying it: the gate every
-- zoom that is not a battle's answers to.
local function roaming()
  return Voxel.active() and Voxel3D.available() and FirstPerson.onTop()
end

local function worldZoomTarget()
  if Voxel.isThirdPerson(Voxel.level) then return "boom" end
  if Voxel.isFirstPerson(Voxel.level) then return nil end
  if Voxel.isFull(Voxel.level) then return "diorama" end
  return "survey"
end

-- Which camera a zoom is aimed at: "battle", "boom", "diorama", "survey",
-- or nil for nothing that zooms. A live-world battle is deliberately NOT the
-- staged BattleCam: Gold keeps drawing the current world/1ST/3RD camera there.
-- Routing its phone pinch to BattleCam changed an invisible lens and made MAP
-- battles look as if mobile had no zoom control at all.
function CamControl.zoomTarget()
  if battleLive() then
    if type(BattleCinematic.ownsCamera) == "function"
        and BattleCinematic.ownsCamera() then return "cinematic" end
    if liveWorldBattle() then return worldZoomTarget() end
    return "battle"
  end
  if not roaming() then return nil end
  return worldZoomTarget()
end

-- ------- zoom
--
-- `notches` is signed the way every zoom in this file is: POSITIVE pulls
-- the camera OUT. The engine's own survey step runs the other way, and is
-- negated at the one place it is called rather than everywhere else being
-- bent to match it.
--
-- Returns true when the input was ours, which is what tells a wrap to stop
-- rather than forward.

local function surveyStep(notches)
  local ok = pcall(function()
    local Game = installedGame or (V.game and V.game)
    local dir = notches > 0 and -1 or 1

    -- Gold/Game2 owns survey zoom on the live World, not on src.core.Game.
    -- Its wheel handler calls world:zoomStep directly. Use that exact path so
    -- pinch changes the same zoom value the Gold voxel bridge reads each frame.
    if Game and Game.world and type(Game.world.zoomStep) == "function" then
      Game.world:zoomStep(dir)
      return
    end

    -- Gen-1 compatibility for the embedded renderer suite.
    local Gen1 = require("src.core.Game")
    if type(Gen1.zoomStep) == "function" then
      Gen1:zoomStep(dir)
      return
    end
    error("survey zoom host unavailable")
  end)
  return ok
end

local function battleZoom(notches)
  local ok, arena = pcall(function()
    local battle = V.require("OverworldBattle")
    return type(battle.arena) == "function" and battle.arena() or nil
  end)
  return BattleCam.stepZoom(notches, ok and arena or nil)
end

function CamControl.zoomBy(notches)
  if not notches or notches == 0 then return false end
  local target = CamControl.zoomTarget()
  if target == "cinematic" then
    return BattleCinematic.stepZoom(notches)
  elseif target == "battle" then
    battleZoom(notches)
    return true
  elseif target == "boom" then
    ThirdPerson.stepZoom(notches)
    return true
  elseif target == "diorama" then
    return DioramaZoom.step(notches)
  elseif target == "survey" then
    -- one call per notch: the engine's ladder is integer rungs, and a
    -- wheel spun hard should climb them all rather than one
    for _ = 1, math.min(8, math.abs(notches)) do surveyStep(notches) end
    return true
  end
  return false
end

-- A pinch's own scale: > 1 is fingers spreading, which means zoom IN
-- (pull the world closer), which is a NEGATIVE notch count.
function CamControl.pinchBy(factor)
  if not (factor and factor > 0) then return false end
  local target = CamControl.zoomTarget()
  if target == "cinematic" then
    return BattleCinematic.scaleZoom(1 / factor)
  elseif target == "boom" then
    return ThirdPerson.scaleZoom(1 / factor)
  elseif target == "diorama" then
    return DioramaZoom.scaleBy(1 / factor)
  elseif target == "battle" then
    -- battles take a pinch too: the wheel and the keys reach this camera
    -- and a phone has neither, so without it the lens would be the one
    -- control a touch screen could not work
    return battleZoom(math.log(1 / factor)
                              / math.log(BattleCam.ZOOM_STEP))
  elseif target == "survey" then
    CamControl.surveyAccum = (CamControl.surveyAccum or 0)
      + math.log(factor) / math.log(2) * CamControl.SURVEY_PINCH
    local moved = false
    while CamControl.surveyAccum >= 1 do
      CamControl.surveyAccum = CamControl.surveyAccum - 1
      surveyStep(-1)
      moved = true
    end
    while CamControl.surveyAccum <= -1 do
      CamControl.surveyAccum = CamControl.surveyAccum + 1
      surveyStep(1)
      moved = true
    end
    return moved
  end
  return false
end

CamControl.surveyAccum = 0

-- ------- the battle's orbit
--
-- Only ever the battle's: the free-roam rungs already steer their own look
-- through FirstPerson, and these wraps sit outside it precisely so a fight
-- can borrow the same devices without either of them growing a mode check.

-- The right stick, read as a rate off the axes FirstPerson's own wrap is
-- already recording (it records whatever the rung, so a battle can read
-- them without a second wrap on the same seam). Ticked from
-- OverworldBattle.update, which runs whatever is on top of the stack.
--
-- X walks the shot round the arena, Y raises the seat. The Y is NEGATED:
-- a stick pushed forward reads as negative on SDL's axis, and pushing
-- forward should send the camera UP and over -- the same "push the camera
-- where you want it" the drag and the mouse below use.
function CamControl.tick(dt)
  if not battleLive() then return end
  local x, y = FirstPerson.stickX(), FirstPerson.stickY()
  local dead = 0.10
  x = math.abs(x or 0) > dead and x or 0
  y = math.abs(y or 0) > dead and y or 0
  if liveWorldBattle() then
    -- The current Gold live battle is rendered by BattleCinematic, not the
    -- legacy BattleCam orbit. v0.2.27 was still feeding the right stick into
    -- BattleCam, so the values changed but the visible camera did not. Route
    -- the same right-stick axes to the camera that actually owns this frame.
    dt = math.max(0, math.min(0.05, tonumber(dt) or 0))
    if x ~= 0 or y ~= 0 then
      BattleCinematic.manualLook(x * dt * 2.9, -y * dt * 2.25)
    end
    return
  end
  if x ~= 0 then BattleCam.stickOrbit(x, dt) end
  if y ~= 0 then BattleCam.stickPitch(-y, dt) end
end

-- ------- the wraps

local installed = false
local installedGame = nil

function CamControl.install(game)
  -- Gold/Game2 is a separate service owner from src.core.Game. v0.1.93
  -- accidentally installed these wraps on the Gen-1 singleton, so Gold never
  -- delivered touch events to the pinch recognizer. Accept the live host just
  -- like FirstPerson.install(game) does and only fall back to Gen 1 when no
  -- host was supplied.
  game = game or (V.game and V.game) or require("src.core.Game")
  if installed then
    if not game or game == installedGame then return true end
    return false, "camera controls already installed on another game host"
  end
  if type(game) ~= "table" then
    return false, "no live game host for camera controls"
  end
  installed = true
  installedGame = game

  local Game = game

  -- ------- the wheel
  --
  -- The engine's own handler is the survey zoom, so the wrap only has to
  -- take the notch away when some OTHER camera wants it; "survey" falls
  -- through to exactly the code that always ran.
  do
    local inner = Game.wheelmoved
    function Game:wheelmoved(dx, dy)
      local target = CamControl.zoomTarget()
      if (target == "battle" or target == "boom" or target == "diorama") and dy and dy ~= 0 then
        CamControl.zoomBy(dy > 0 and -1 or 1)
        return
      end
      return inner(self, dx, dy)
    end
  end

  -- ------- the stick clicks
  --
  -- Q and E, on the pad: the left stick's click pulls the camera out and the
  -- right stick's pulls it in. A controller has no wheel and no number row,
  -- and the two clicks are the only buttons a Gen 1 pad layout leaves free
  -- (SELECT already walks the angle ladder).
  --
  -- Claimed for the two cameras a pad player can actually be looking at
  -- while pressing them -- the third-person boom and a staged battle's lens
  -- -- and forwarded untouched everywhere else, so a player who has rebound
  -- either click keeps it on every other screen, a rebind capture included.
  -- Not on the orbit rungs: the survey zoom has the OPTIONS row and the
  -- wheel already, and taking a pad button for it would be taking one from
  -- a player who never asked.
  local CLICK_ZOOMS = { boom = true, battle = true }
  do
    local inner = Game.gamepadpressed
    function Game:gamepadpressed(joystick, button)
      if (button == "leftstick" or button == "rightstick")
         and CLICK_ZOOMS[CamControl.zoomTarget() or ""] then
        CamControl.zoomBy(button == "leftstick" and 1 or -1)
        return
      end
      return inner(self, joystick, button)
    end
  end

  -- ------- the mouse
  --
  -- Battle only. The free-roam look already owns relative motion through
  -- FirstPerson's own wrap (this one is outside it, so what is claimed here
  -- never reaches it) and a fight is exactly when that look is not driving.
  --
  -- Bare motion, no button held: moving the mouse moves the shot.
  --
  -- Each event's contribution is CLAMPED, though, because not every motion
  -- event is a hand moving. The pointer entering the window, a warp back to
  -- centre, an alt-tab -- each arrives as ONE event carrying the whole
  -- distance from wherever the cursor was last seen, and in testing that
  -- was a couple of hundred counts: enough to swing the shot a quarter of
  -- the way to side-on before the player had touched anything. A real hand
  -- delivers its travel as a stream of small events and is unaffected; a
  -- teleport delivers it as one and is cut down to the size of a flick.
  local MOUSE_STEP = 40
  local function clamp(v)
    return math.max(-MOUSE_STEP, math.min(MOUSE_STEP, v or 0))
  end
  do
    local function mouseLook(dx, dy, istouch)
      if battleLive() and not istouch then
        if liveWorldBattle() then
          local w, h = 1280, 720
          pcall(function() w, h = love.graphics.getWidth(), love.graphics.getHeight() end)
          BattleCinematic.manualLook(-(clamp(dx) / math.max(320, w)) * 4.2,
                                     (clamp(dy) / math.max(240, h)) * 3.0)
        else
          -- dy is NEGATED for the same reason the stick's is: moving the
          -- mouse away from you sends the camera up and over
          if dx and dx ~= 0 then BattleCam.mouseOrbit(clamp(dx)) end
          if dy and dy ~= 0 then BattleCam.mousePitch(-clamp(dy)) end
        end
        -- forwarded anyway: the cursor still has UI to point at, and the
        -- steer is a read of the motion rather than a claim on it
      end
    end
    local hooks = V.mod and V.mod.hooks
    if type(hooks) == "table" and type(hooks.wrap) == "function" then
      hooks:wrap("input.pointer", function(nextInput, game, pointer)
        if type(pointer) == "table" and pointer.source == "mouse"
           and pointer.phase == "moved" then
          mouseLook(pointer.dx, pointer.dy, false)
        end
        return nextInput(game, pointer)
      end, 20)
    else
      -- Old hosts allow this fallback; the current sandbox does not. A
      -- missing mouse extra must never abort installation of phone gestures.
      pcall(function()
        local inner = love.mousemoved
        love.mousemoved = function(x, y, dx, dy, istouch)
          mouseLook(dx, dy, istouch)
          if inner then return inner(x, y, dx, dy, istouch) end
        end
      end)
    end
  end

  -- ------- the touch screen
  --
  -- Two gestures, told apart by how many fingers are down on OPEN screen
  -- (the overlay's own d-pad and buttons are never either):
  --
  --   one finger, in a battle    drags the shot around the arena
  --   two fingers               pinch to zoom, wherever zooming means
  --                             something -- and while they are down the
  --                             free-roam look stands aside, so a pinch in
  --                             3RD does not also spin the view
  local TouchControls = require("src.core.TouchControls")

  local free = {}          -- id -> {x, y} for every finger on open screen
  local pinch = nil        -- { a, b, gap } while two of them are pinching

  local function freeCount()
    local n = 0
    for _ in pairs(free) do n = n + 1 end
    return n
  end

  local function gapOf(a, b)
    local dx, dy = free[a].x - free[b].x, free[a].y - free[b].y
    return math.sqrt(dx * dx + dy * dy)
  end

  -- Two free fingers and a camera that zooms: start measuring. The look
  -- drag is dropped for the duration -- FirstPerson never sees the moves
  -- below -- and re-seated on whichever finger survives, so the view does
  -- not jump by however far the pinch travelled.
  local function startPinch()
    if pinch or freeCount() < 2 then return end
    local ids = {}
    for id in pairs(free) do ids[#ids + 1] = id end
    local gap = gapOf(ids[1], ids[2])
    if gap < 16 then return end
    pinch = { a = ids[1], b = ids[2], gap = gap }
    CamControl.surveyAccum = 0
    pcall(FirstPerson.dropLook)
  end

  local function endPinch(lifted)
    if not pinch then return end
    local survivor = nil
    for id in pairs(free) do
      if id ~= lifted then survivor = id break end
    end
    pinch = nil
    if survivor and free[survivor] then
      pcall(FirstPerson.reseatLook, survivor,
            free[survivor].x, free[survivor].y)
    end
  end

  local function onControl(x, y)
    local hit = nil
    pcall(function() hit = TouchControls:hitTest(x, y) end)
    return hit
  end

  local function advancePinch()
    if not pinch then return false end
    local gap = gapOf(pinch.a, pinch.b)
    local factor = gap / math.max(1, pinch.gap)
    if math.abs(factor - 1) <= CamControl.PINCH_SLACK then return false end
    local changed = CamControl.pinchBy(factor)
    pinch.gap = gap
    CamControl.lastPinchTarget = CamControl.zoomTarget()
    if changed then
      CamControl.pinchChanges = (CamControl.pinchChanges or 0) + 1
    end
    return changed
  end

  local function battleLook(dx, dy, w, h)
    if dx == 0 and dy == 0 then return end
    if liveWorldBattle() then
      BattleCinematic.manualLook(-(dx / math.max(320, w)) * 4.2,
                                 (dy / math.max(240, h)) * 3.0)
    else
      BattleCam.dragOrbit(dx / math.max(320, w))
      BattleCam.dragPitch(-dy / math.max(240, h))
    end
    CamControl.lookChanges = (CamControl.lookChanges or 0) + 1
  end

  -- Gold's mobile host can bypass late Game2 touch wrappers. Observe the
  -- physical contacts during battle updates too, feeding the SAME gap state
  -- as callbacks: receiving both paths cannot apply one gesture twice.
  -- Only this battle lane polls; existing free-roam/desktop input is intact.
  local pollRejected, pollWidth, pollHeight = {}, nil, nil
  function CamControl.pollBattleTouches(osName)
    -- The modern mod sandbox denies love.system; the bridge passes its
    -- engine-owned Platform.detect result. Keep the older-host fallback safe.
    if not osName then pcall(function() osName = love.system.getOS() end) end
    local T, G = love.touch, love.graphics
    if (osName ~= "iOS" and osName ~= "Android") or not battleLive()
        or not (T and T.getTouches and T.getPosition) then
      if pollWidth then free, pinch, pollRejected = {}, nil, {} end
      pollWidth, pollHeight = nil, nil
      return false
    end
    local w, h = G.getWidth(), G.getHeight()
    local flipped = false
    if osName == "Android" then
      pcall(function() flipped = V.mod.options:get("screenFlip") == true end)
    end
    if pollWidth and (w ~= pollWidth or h ~= pollHeight) then
      free, pinch, pollRejected = {}, nil, {}
    end
    pollWidth, pollHeight = w, h
    local ok, ids = pcall(T.getTouches)
    if not ok or type(ids) ~= "table" then return false end
    local seen, lookDelta = {}, {}
    local wasPinching = pinch ~= nil
    for _, id in ipairs(ids) do
      seen[id] = true
      local positioned, x, y = pcall(T.getPosition, id)
      if positioned and type(x) == "number" and type(y) == "number" then
        if flipped then x, y = w-x, h-y end
        if not free[id] and not pollRejected[id] then
          -- Controls own a contact until release, even after it slides out.
          local captured = TouchControls.touches and TouchControls.touches[id]
          if captured or onControl(x, y) then pollRejected[id] = true end
        end
        if not pollRejected[id] then
          local old = free[id]
          if old then lookDelta[id] = {x-old.x, y-old.y} end
          free[id] = {x=x, y=y}
        end
      end
    end
    for id in pairs(free) do if not seen[id] then free[id] = nil end end
    for id in pairs(pollRejected) do
      if not seen[id] then pollRejected[id] = nil end
    end
    if pinch and (not free[pinch.a] or not free[pinch.b]) then pinch = nil end
    startPinch()
    if not pinch then
      if freeCount() == 1 then
        local id = next(free)
        local delta = lookDelta[id]
        -- Releasing one pinch finger only seeds the survivor. Callback and
        -- poll share free[] positions, so neither zoom nor look is doubled.
        if delta and not wasPinching then battleLook(delta[1], delta[2], w, h) end
        return true -- this camera owns look too; suppress the old Android poll
      end
      return false
    end
    advancePinch()
    return true
  end

  local function rightLookZone(x)
    local osName = nil
    pcall(function() osName = love.system.getOS() end)
    if osName ~= "Android" then return true end
    local w = 1280
    pcall(function() w = love.graphics.getWidth() end)
    return (tonumber(x) or 0) >= w * 0.45
  end

  -- Whether this module has any interest in touches at all this frame.
  -- Kept deliberately wide -- a battle, or anything that zooms -- because
  -- the wrap forwards everything it does not claim regardless.
  local function wantsTouch()
    return battleLive() or CamControl.zoomTarget() ~= nil
  end

  do
    local inner = Game.touchpressed
    function Game:touchpressed(id, x, y, ...)
      if wantsTouch() and not onControl(x, y)
         and (not battleLive() or rightLookZone(x) or CamControl.zoomTarget() ~= "battle") then
        free[id] = { x = x, y = y }
        if CamControl.zoomTarget() then startPinch() end
        -- forwarded even so: a single free finger is the free-roam look's
        -- to claim (FirstPerson's wrap is inside this one), and in a
        -- battle it is nobody's until it MOVES
      end
      return inner(self, id, x, y, ...)
    end
  end

  do
    local inner = Game.touchmoved
    function Game:touchmoved(id, x, y, ...)
      local f = free[id]
      if f then
        local px, py = f.x, f.y
        f.x, f.y = x, y
        if pinch and (id == pinch.a or id == pinch.b) then
          advancePinch()
          return                       -- claimed: never a look drag too
        end
        if battleLive() and not pinch then
          local w, h = 1280, 720
          pcall(function()
            w, h = love.graphics.getWidth(), love.graphics.getHeight()
          end)
          battleLook(x - px, y - py, w, h)
          return
        end
      end
      return inner(self, id, x, y, ...)
    end
  end

  do
    local inner = Game.touchreleased
    function Game:touchreleased(id, x, y, ...)
      if free[id] then
        if pinch and (id == pinch.a or id == pinch.b) then endPinch(id) end
        free[id] = nil
      end
      return inner(self, id, x, y, ...)
    end
  end

  -- a reset that drops held input state drops ours with it, exactly as the
  -- free-roam look's does
  do
    local inner = Game.focus
    function Game:focus(f)
      free, pinch = {}, nil
      pollRejected, pollWidth, pollHeight = {}, nil, nil
      CamControl.surveyAccum = 0
      return inner(self, f)
    end
  end
end

return CamControl
