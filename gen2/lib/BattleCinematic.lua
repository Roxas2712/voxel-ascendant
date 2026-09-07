-- Stadium-style cinematic orbit camera for Gold live-overworld battles.
-- It frames both combatants in the actual encounter world, eases between
-- menu/attack framing, and yields temporarily to manual look input.
local V = ...
local FirstPerson = V.require("FirstPerson")
local okDiagnostics, Diagnostics = pcall(V.require, "Diagnostics")
if not okDiagnostics or type(Diagnostics) ~= "table" then Diagnostics = {} end

local BattleCinematic = {}

BattleCinematic.enabled = true
BattleCinematic.zoom = 1
BattleCinematic.ZOOM_STEP = 1.12
BattleCinematic.angle = nil
BattleCinematic.radius = 96
BattleCinematic.height = 48
BattleCinematic.manualHold = 0
BattleCinematic.manualPitch = 0
BattleCinematic.lastActive = false
BattleCinematic.t = 0
BattleCinematic.focusX = nil
BattleCinematic.focusZ = nil
BattleCinematic.activeSide = nil
BattleCinematic.lastToken = nil
BattleCinematic.lastSafeCamera = nil
BattleCinematic.lastSafetyReason = nil
BattleCinematic.fallbackToken = nil
BattleCinematic.fallbackOwner = nil
BattleCinematic.fallbackReason = nil
BattleCinematic.fallbackAttempts = nil
BattleCinematic.fallbackPhase = nil
BattleCinematic._frameOwnerToken = nil
BattleCinematic._frameLiveMap = false
BattleCinematic._framePhase = nil

BattleCinematic.MANUAL_HOLD_SECONDS = 4.0
BattleCinematic.MAX_AUTO_YAW_RATE = math.rad(24)
BattleCinematic.MAX_AUTO_YAW_ACCEL = math.rad(48)
BattleCinematic.MAX_AUTO_PITCH_RATE = math.rad(8)
BattleCinematic.MAX_AUTO_PITCH_ACCEL = math.rad(24)
BattleCinematic.MAX_RADIUS_RATE = 24
BattleCinematic.MAX_RADIUS_ACCEL = 48
BattleCinematic.MAX_HEIGHT_RATE = 10
BattleCinematic.MAX_HEIGHT_ACCEL = 24
BattleCinematic.MAX_FOCUS_RATE = 20
BattleCinematic.MAX_FOCUS_ACCEL = 40
BattleCinematic.angleVelocity = 0
BattleCinematic.pitchVelocity = 0
BattleCinematic.radiusVelocity = 0
BattleCinematic.heightVelocity = 0
BattleCinematic.focusVelocityX = 0
BattleCinematic.focusVelocityZ = 0

local TAU = math.pi * 2
local function wrap(a)
  a = (a or 0) % TAU
  if a < 0 then a = a + TAU end
  return a
end
local function clamp(v, low, high)
  return math.max(low, math.min(high, v))
end
local function approach(a, b, k)
  return a + (b - a) * math.max(0, math.min(1, k))
end

local function angleDelta(a, b)
  return ((b - a + math.pi) % TAU) - math.pi
end

local function chaseComfort(now, goal, velocity, dt, time, maxRate, maxAccel)
  dt = math.max(0, tonumber(dt) or 0)
  velocity = tonumber(velocity) or 0
  if dt <= 0 then return now, velocity end
  local remaining = goal - now
  if math.abs(remaining) < 1e-6
      and math.abs(velocity) <= maxAccel * dt then
    return goal, 0
  end
  local brakingRate = math.sqrt(2 * maxAccel * math.abs(remaining))
  local desired = clamp(remaining / math.max(time or 1, 1e-6),
                        -math.min(maxRate, brakingRate),
                        math.min(maxRate, brakingRate))
  velocity = velocity + clamp(desired - velocity,
                              -maxAccel * dt, maxAccel * dt)
  velocity = clamp(velocity, -maxRate, maxRate)
  return now + velocity * dt, velocity
end

local function chaseAngle(now, goal, velocity, dt)
  local delta = angleDelta(now, goal)
  local step, nextVelocity = chaseComfort(
    0, delta, velocity, dt, 1.15,
    BattleCinematic.MAX_AUTO_YAW_RATE,
    BattleCinematic.MAX_AUTO_YAW_ACCEL)
  return wrap(now + step), nextVelocity
end

local function orbitAngle(now, velocity, desired, dt)
  local maxDelta = BattleCinematic.MAX_AUTO_YAW_ACCEL * dt
  velocity = (tonumber(velocity) or 0)
    + clamp(desired - (tonumber(velocity) or 0), -maxDelta, maxDelta)
  velocity = clamp(velocity, -BattleCinematic.MAX_AUTO_YAW_RATE,
                   BattleCinematic.MAX_AUTO_YAW_RATE)
  return wrap(now + velocity * dt), velocity
end

local function chasePoint(x, z, goalX, goalZ, vx, vz, dt)
  local dx, dz = goalX - x, goalZ - z
  local distance = math.sqrt(dx * dx + dz * dz)
  vx, vz = tonumber(vx) or 0, tonumber(vz) or 0
  if distance < 1e-6
      and math.sqrt(vx * vx + vz * vz)
        <= BattleCinematic.MAX_FOCUS_ACCEL * dt then
    return goalX, goalZ, 0, 0
  end
  local desiredX, desiredZ = 0, 0
  if distance >= 1e-6 then
    local desiredSpeed = math.min(
      distance / .65, BattleCinematic.MAX_FOCUS_RATE,
      math.sqrt(2 * BattleCinematic.MAX_FOCUS_ACCEL * distance))
    desiredX, desiredZ = dx / distance * desiredSpeed,
                         dz / distance * desiredSpeed
  end
  local dvx, dvz = desiredX - vx, desiredZ - vz
  local dv = math.sqrt(dvx * dvx + dvz * dvz)
  local maxDv = BattleCinematic.MAX_FOCUS_ACCEL * dt
  if dv > maxDv and dv > 0 then
    local scale = maxDv / dv
    dvx, dvz = dvx * scale, dvz * scale
  end
  vx, vz = vx + dvx, vz + dvz
  local speed = math.sqrt(vx * vx + vz * vz)
  if speed > BattleCinematic.MAX_FOCUS_RATE then
    local scale = BattleCinematic.MAX_FOCUS_RATE / speed
    vx, vz = vx * scale, vz * scale
  end
  return x + vx * dt, z + vz * dt, vx, vz
end

local function approachAngle(a, b, k)
  local d = ((b - a + math.pi) % TAU) - math.pi
  return wrap(a + d * math.max(0, math.min(1, k)))
end

local function cameraCopy(cam)
  if type(cam) ~= "table" then return nil end
  local function vec(v)
    return type(v) == "table" and { v[1], v[2], v[3] } or nil
  end
  return {
    eye=vec(cam.eye), focus=vec(cam.focus), up=vec(cam.up) or { 0, 1, 0 },
    fov=cam.fov, curve=cam.curve,
    _stadiumBattleCinematic=cam._stadiumBattleCinematic,
  }
end

local function genericScreenSafe(shot)
  if not (type(shot) == "table" and tonumber(shot.pw)
      and tonumber(shot.ph) and type(shot.actorHulls) == "table"
      and type(shot.actorFeet) == "table") then
    return nil, "camera-projection-unavailable"
  end
  -- Native/GAME DEFAULT providers do not publish wide-HUD bounds. Keep the
  -- cartridge's lower command/text band free and both status corners clear.
  local pw, ph = shot.pw, shot.ph
  local left, top, right, bottom = pw * .08, ph * .11, pw * .92, ph * .70
  local feet = shot.actorFeet
  for _, side in ipairs({ "player", "enemy" }) do
    local hull, foot = shot.actorHulls[side], feet[side]
    if not (hull and foot and hull[1] >= left and hull[2] >= top
        and hull[1]+hull[3] <= right and hull[2]+hull[4] <= bottom
        and foot[1] >= left and foot[1] <= right
        and foot[2] >= top and foot[2] <= bottom) then
      return false, side .. "-outside-native-safe-zone"
    end
  end
  local dx = feet.player[1] - feet.enemy[1]
  local dy = feet.player[2] - feet.enemy[2]
  local minimum = math.max(56, math.min(pw, ph) * .10)
  if dx*dx + dy*dy < minimum*minimum then
    return false, "actor-screen-distance"
  end
  return true, "native-safe-zone-clear"
end

local function cameraVerdict(ctx, arena, groundY, cam, fromEye)
  if not (cam and cam.eye and cam.focus) then return false, "camera-missing" end
  local map = type(ctx) == "table" and (ctx.map or arena.map) or arena.map
  if not arena.discs and map then
    local okArena, BattleArena = pcall(V.require, "BattleArena")
    if okArena and BattleArena then
      if type(BattleArena.cameraClear) == "function"
          and not BattleArena.cameraClear(map, cam.eye) then
        return false, "camera-in-solid-or-map-edge"
      end
      if fromEye and type(BattleArena.cameraPathClear) == "function"
          and not BattleArena.cameraPathClear(map, fromEye, cam.eye) then
        return false, "camera-path-crosses-solid"
      end
      if type(BattleArena.visibility) == "function" then
        for _, side in ipairs({ "player", "enemy" }) do
          if BattleArena.visibility(map, cam.eye, arena[side], groundY) < 3 then
            return false, side .. "-terrain-occluded"
          end
        end
      end
    end
  end

  local okScene, BattleScene = pcall(V.require, "BattleScene")
  if not (okScene and BattleScene
      and type(BattleScene.cameraSafetyShot) == "function") then
    return nil, "camera-projection-unavailable"
  end
  local shot = BattleScene.cameraSafetyShot(
    arena, groundY, cam,
    type(ctx) == "table" and ctx.textures or nil,
    map,
    type(ctx) == "table" and ctx.token or nil)
  if not shot then return false, "camera-projection-unavailable" end
  local okUI, BattleUI = pcall(V.require, "BattleControllerUI")
  if okUI and BattleUI and type(BattleUI.cameraSafe) == "function" then
    local ok, safe, reason = pcall(BattleUI.cameraSafe, ctx.screen, shot)
    if ok and safe ~= nil then return safe == true, reason, shot end
  end
  local safe, reason = genericScreenSafe(shot)
  return safe, reason, shot
end

-- A bounded, provider-neutral recovery family. It rotates and lifts the same
-- semantic two-mark composition; it never names a map, background or species.
-- This is fast enough to run only after the desired camera was rejected and
-- gives future arena packs several honest seats before the authored rig wins.
local CAMERA_RECOVERY = {
  { da=0,     radius=1.00, height=0,  focus=0,  fov=55 },
  -- Wide/ultrawide command docks are physically taller than their 4:3
  -- counterpart. If the normal menu seat leaves the near actor under that
  -- dock, try honest pull-backs before moving closer: the latter only makes
  -- the overlap worse. Physical MAP stages still run every seat through the
  -- terrain/path checks; portable ARENA/DISCS can safely use the extra room.
  { da=0,     radius=1.24, height=8,  focus=0,  fov=58 },
  { da=.20,   radius=1.34, height=12, focus=-2, fov=60 },
  { da=-.20,  radius=1.34, height=12, focus=-2, fov=60 },
  { da=0,     radius=1.55, height=16, focus=-3, fov=63 },
  -- 16:9 needs a little more vertical separation once Gen 2 restores the
  -- padded Kanto command-canvas inset. This remains an honest wide lens over
  -- the same two world marks; it does not move either battler or HUD card.
  { da=0,     radius=1.80, height=20, focus=-5, fov=66 },
  { da=0,     radius=2.10, height=22, focus=-10, fov=72 },
  { da=0,     radius=.86,  height=9,  focus=-4, fov=57 },
  { da=.24,   radius=.90,  height=10, focus=-3, fov=57 },
  { da=-.24,  radius=.90,  height=10, focus=-3, fov=57 },
  { da=.48,   radius=.82,  height=14, focus=-5, fov=58 },
  { da=-.48,  radius=.82,  height=14, focus=-5, fov=58 },
  { da=.82,   radius=.76,  height=18, focus=-6, fov=59 },
  { da=-.82,  radius=.76,  height=18, focus=-6, fov=59 },
}

local function recoveryCamera(base, spec)
  local fx, fy, fz = base.focus[1], base.focus[2], base.focus[3]
  local dx, dz = base.eye[1]-fx, base.eye[3]-fz
  local radius = math.max(28, math.sqrt(dx*dx+dz*dz) * spec.radius)
  local angle = math.atan2(dx, dz) + spec.da
  return {
    eye={ fx+math.sin(angle)*radius, base.eye[2]+spec.height,
          fz+math.cos(angle)*radius },
    focus={ fx, fy+spec.focus, fz }, up={ 0, 1, 0 },
    fov=math.rad(spec.fov), curve=0, _stadiumBattleCinematic=true,
  }
end

local function safeCamera(ctx, arena, groundY, desired)
  local previous = BattleCinematic.lastSafeCamera
  local fromEye = previous and previous.eye or nil
  local lastReason = "no-candidate"
  local attempts = {}
  for index, spec in ipairs(CAMERA_RECOVERY) do
    local candidate = index == 1 and desired or recoveryCamera(desired, spec)
    local safe, reason, shot = cameraVerdict(
      ctx, arena, groundY, candidate, fromEye)
    lastReason = reason or lastReason
    local hull = shot and shot.actorHulls and shot.actorHulls.player
    attempts[#attempts + 1] = tostring(index) .. ":" .. tostring(reason)
      .. (hull and ("@%.1f,%.1f,%.1f,%.1f"):format(
          hull[1], hull[2], hull[3], hull[4]) or "")
    if safe then
      BattleCinematic.lastSafeCamera = cameraCopy(candidate)
      BattleCinematic.lastSafetyReason = reason
      BattleCinematic.lastSafetyAttempts = attempts
      return candidate, reason, index
    end
  end
  -- A phase change can add a dock under the current lens. Reuse the last
  -- accepted composition only when it remains valid for the NEW HUD phase.
  if previous then
    local safe, reason = cameraVerdict(ctx, arena, groundY, previous, previous.eye)
    if safe then
      BattleCinematic.lastSafetyReason = "last-safe:" .. tostring(reason)
      attempts[#attempts + 1] = "previous:" .. tostring(reason)
      BattleCinematic.lastSafetyAttempts = attempts
      return cameraCopy(previous), BattleCinematic.lastSafetyReason, 0
    end
    attempts[#attempts + 1] = "previous:" .. tostring(reason)
    lastReason = reason or lastReason
  end
  BattleCinematic.lastSafetyReason = lastReason
  BattleCinematic.lastSafetyAttempts = attempts
  return nil, lastReason, nil
end

local function eventActiveSide(screen)
  if type(screen) ~= "table" then return nil end
  -- During a real move animation Gold exposes the attacker through hudSide.
  -- Treat `anim` as opaque unless it is a table: older/newer engine builds can
  -- legitimately use a falsey/sentinel value while changing animation phases.
  local anim = type(screen.anim) == "table" and screen.anim or nil
  if anim and (anim.hudSide == "player" or anim.hudSide == "enemy") then
    return anim.hudSide
  end
  -- OverworldBattle's tiny advanceQueue observer keeps the acting side alive
  -- through the rest of the same resolving turn (damage text / HP drain).
  local phase = tostring(screen.phase or "")
  if phase ~= "menu" and phase ~= "moves" and phase ~= "submenu"
      and phase ~= "done"
      and (screen._stadiumActiveSide == "player" or screen._stadiumActiveSide == "enemy") then
    return screen._stadiumActiveSide
  end
  return nil
end

local function settingOn(ctx)
  -- Prefer the immutable battle-start receipt. The option remains the fallback
  -- for callers outside an active battle and for older OverworldBattle builds.
  if type(ctx) == "table" and ctx.smartCamera ~= nil then
    return ctx.smartCamera == true
  end
  local mod = V.mod
  if mod and mod.options and type(mod.options.get) == "function" then
    local ok, v = pcall(mod.options.get, mod.options, "battleSmartCamera")
    if ok and v ~= nil then
      return not (v == false or v == 0 or v == "0" or v == "false" or v == "off")
    end
  end
  return true
end

local function liveMapContext(ctx)
  if not (type(ctx) == "table" and type(ctx.arena) == "table") then
    return false
  end
  local arena = ctx.arena
  local map = ctx.map or arena.map
  -- Current Gold sessions publish both forms: presentationMode is the
  -- normalized stage receipt, while ctx.mode is the immutable option value
  -- captured at battle start. Portable ARENA can still carry its source map,
  -- so map presence alone is not enough to call it a live MAP stage.
  if arena.presentationMode ~= nil then
    return arena.presentationMode == "MAP"
  end
  if ctx.mode ~= nil then
    return ctx.mode == true or ctx.mode == "MAP" or ctx.mode == "map"
  end
  -- Compatibility for older sessions that predate presentationMode.
  return not arena.discs and map ~= nil
end

local function phaseOf(screen)
  local phase = type(screen) == "table" and screen.phase or nil
  if type(phase) == "string" or type(phase) == "number" then
    return tostring(phase)
  end
  return ""
end

local function clearFallback()
  BattleCinematic.fallbackToken = nil
  BattleCinematic.fallbackOwner = nil
  BattleCinematic.fallbackReason = nil
  BattleCinematic.fallbackAttempts = nil
  BattleCinematic.fallbackPhase = nil
end

local function fallbackReceipt(phase)
  return {
    schema="voxel-ascendant/gen2-smart-camera/v1", enabled=true,
    safe=false, fallback=BattleCinematic.fallbackOwner,
    fallbackLatched=true, cameraOwner=BattleCinematic.fallbackOwner,
    safetyReason=BattleCinematic.fallbackReason,
    safetyAttempts=BattleCinematic.fallbackAttempts,
    phase=phase or BattleCinematic.fallbackPhase or "",
  }
end

local function latchMapFallback(ownerToken, phase, reason, attempts)
  if ownerToken == nil then return false end
  BattleCinematic.fallbackToken = ownerToken
  -- VoxelScene has already placed FirstPerson/ThirdPerson before asking this
  -- optional SMART director for an override. Returning nil consistently lets
  -- that existing, playable MAP camera own the rest of this battle token.
  BattleCinematic.fallbackOwner = "map-camera"
  BattleCinematic.fallbackReason = tostring(reason or "smart-camera-error")
  BattleCinematic.fallbackAttempts = attempts
  BattleCinematic.fallbackPhase = phase or ""
  BattleCinematic.lastReceipt = fallbackReceipt(phase)
  BattleCinematic.lastActive = true
  return true
end

function BattleCinematic.reset(preserveFallback)
  BattleCinematic.zoom = 1
  BattleCinematic.angle = nil
  BattleCinematic.radius = 96
  BattleCinematic.height = 48
  BattleCinematic.manualHold = 0
  BattleCinematic.manualPitch = 0
  BattleCinematic.t = 0
  BattleCinematic.focusX = nil
  BattleCinematic.focusZ = nil
  BattleCinematic.activeSide = nil
  BattleCinematic.angleVelocity = 0
  BattleCinematic.pitchVelocity = 0
  BattleCinematic.radiusVelocity = 0
  BattleCinematic.heightVelocity = 0
  BattleCinematic.focusVelocityX = 0
  BattleCinematic.focusVelocityZ = 0
  BattleCinematic.lastFrameDt = nil
  BattleCinematic.lastActive = false
  BattleCinematic.lastReceipt = nil
  BattleCinematic.lastSafeCamera = nil
  BattleCinematic.lastSafetyReason = nil
  BattleCinematic._frameOwnerToken = nil
  BattleCinematic._frameLiveMap = false
  BattleCinematic._framePhase = nil
  if not preserveFallback then clearFallback() end
end

function BattleCinematic.ownsCamera()
  return BattleCinematic.lastActive == true
    and type(BattleCinematic.lastReceipt) == "table"
    and BattleCinematic.lastReceipt.cameraOwner == "smart"
end

function BattleCinematic.scaleZoom(factor)
  if not BattleCinematic.ownsCamera() or type(factor) ~= "number"
      or factor ~= factor or factor <= 0 or factor == math.huge then return false end
  BattleCinematic.zoom = clamp(BattleCinematic.zoom * factor, .65, 2.4)
  return true
end

function BattleCinematic.stepZoom(notches)
  return BattleCinematic.scaleZoom(BattleCinematic.ZOOM_STEP ^ notches)
end

function BattleCinematic.manualLook(dyaw, dpitch)
  BattleCinematic.angle = wrap((BattleCinematic.angle or FirstPerson.yaw or 0) - (tonumber(dyaw) or 0))
  BattleCinematic.manualPitch = math.max(-0.55, math.min(0.55,
    BattleCinematic.manualPitch + (tonumber(dpitch) or 0)))
  BattleCinematic.manualHold = BattleCinematic.MANUAL_HOLD_SECONDS
  BattleCinematic.angleVelocity = 0
  BattleCinematic.pitchVelocity = 0
  BattleCinematic.radiusVelocity = 0
  BattleCinematic.heightVelocity = 0
  BattleCinematic.focusVelocityX = 0
  BattleCinematic.focusVelocityZ = 0
  return true
end

function BattleCinematic.manualActive()
  return BattleCinematic.manualHold > 0
end

-- Returns placed camera, centre x/z when a Gold live-world battle is active.
local function frameImpl(dt)
  local ok, OverworldBattle = pcall(V.require, "OverworldBattle")
  if not ok or not OverworldBattle or type(OverworldBattle.cameraContext) ~= "function" then
    return nil
  end
  local ctx = OverworldBattle.cameraContext()
  if not settingOn(ctx) then
    -- A player may change the *next* battle's option while this battle keeps
    -- its latched camera. Once the owner disappears, that live OFF value used
    -- to bypass the normal no-context reset and leak the old angle/focus into
    -- a later SMART battle. Disabled means no camera state is observable, so
    -- retire it completely here.
    BattleCinematic.reset()
    return nil
  end
  if not ctx or not ctx.arena then
    -- Gold can briefly hide its camera context while another screen redraws.
    -- Preserve only the token-bound MAP fallback across that seam; the
    -- OverworldBattle lifecycle calls reset() explicitly when the battle
    -- actually finishes or becomes native.
    if BattleCinematic.lastActive then BattleCinematic.reset(true) end
    return nil
  end

  -- Retain an action receipt across Gold's short no-context redraw seams, but
  -- never carry it into another battle.  OverworldBattle exposes a unique
  -- token for precisely this ownership boundary.
  local ownerToken = ctx.battleToken or ctx.screen
  if ownerToken ~= BattleCinematic.lastToken then
    BattleCinematic.lastToken = ownerToken
    BattleCinematic.lastActionReceipt = nil
    BattleCinematic.lastSafeCamera = nil
    BattleCinematic.lastSafetyReason = nil
    clearFallback()
  end
  BattleCinematic._frameOwnerToken = ownerToken
  BattleCinematic._frameLiveMap = liveMapContext(ctx)
  BattleCinematic._framePhase = phaseOf(ctx.screen)
  if BattleCinematic.fallbackToken == ownerToken
      and BattleCinematic.fallbackOwner then
    BattleCinematic.lastReceipt = fallbackReceipt(BattleCinematic._framePhase)
    BattleCinematic.lastActive = true
    return nil
  end

  local arena = ctx.arena
  local p, e = arena.player, arena.enemy
  if not (type(p) == "table" and type(e) == "table") then return nil end
  local px, pz = tonumber(p[1]), tonumber(p[2])
  local ex, ez = tonumber(e[1]), tonumber(e[2])
  if not (px and pz and ex and ez) then return nil end
  -- Work only with validated numeric coordinates from this point onward.
  p, e = { px, pz }, { ex, ez }
  local cx = arena.mid and tonumber(arena.mid[1]) or ((px + ex) * 0.5)
  local cz = arena.mid and tonumber(arena.mid[2]) or ((pz + ez) * 0.5)
  if not (cx and cz) then
    cx, cz = (px + ex) * 0.5, (pz + ez) * 0.5
  end
  local gy = tonumber(ctx.groundY) or 0
  local screen = ctx.screen
  local attack = screen and screen.anim ~= nil and screen.anim ~= false
  local resolving = screen and screen.phase == "resolving"
  local activeSide = eventActiveSide(screen)
  -- While the player is directly steering the Stadium actor, keep the camera
  -- in the same shoulder/follow family used for an active attack turn. The
  -- controller moves arena.player itself, so this naturally follows the model.
  local manualControl, manualAttack = false, false
  local okControl, Control = pcall(V.require, "BattlePokemonControl")
  if okControl and Control then
    local okA, a = pcall(Control.active)
    manualControl = okA and a and true or false
    local okAtk, atk = pcall(Control.attacking)
    manualAttack = okAtk and atk and true or false
  end
  if manualControl then activeSide = "player" end
  if manualAttack then attack = true end

  dt = math.max(0, math.min(0.1,
    tonumber(dt) or tonumber(ctx.frameDt) or 0))
  BattleCinematic.lastFrameDt = dt

  -- Controller camera input is sampled INSIDE the camera that actually renders
  -- the Gold live-world battle. Earlier builds routed the right stick through
  -- CamControl.tick, but Gold's OverworldBattle intentionally skipped that
  -- tick; the values could therefore be correct without ever changing this
  -- camera. Polling SDL here removes that unreachable seam entirely.
  if type(FirstPerson.pollMappedRightStick) == "function" then
    pcall(FirstPerson.pollMappedRightStick)
  end
  local rx = type(FirstPerson.stickX) == "function" and FirstPerson.stickX() or 0
  local ry = type(FirstPerson.stickY) == "function" and FirstPerson.stickY() or 0
  rx, ry = tonumber(rx) or 0, tonumber(ry) or 0
  local rdead = 0.10
  if math.abs(rx) <= rdead then rx = 0 end
  if math.abs(ry) <= rdead then ry = 0 end
  if rx ~= 0 or ry ~= 0 then
    BattleCinematic.manualLook(rx * dt * 2.9, -ry * dt * 2.25)
  end

  local angleWasNil = BattleCinematic.angle == nil
  if angleWasNil then
    -- Start behind the player's side, offset enough to read both models.
    local dx, dz = e[1] - p[1], e[2] - p[2]
    BattleCinematic.angle = wrap(math.atan2(-dx, -dz) + 0.65)
  end

  local manual = BattleCinematic.manualHold > 0
  if manual then
    BattleCinematic.manualHold = math.max(0, BattleCinematic.manualHold - dt)
  else
    BattleCinematic.t = BattleCinematic.t + dt
    if activeSide then
      -- Stadium-style shoulder shot: stay mostly behind and to the side of the
      -- Pokemon whose turn is currently playing, rather than orbiting both
      -- combatants evenly. A very small drift keeps the frame alive.
      local actor = activeSide == "player" and p or e
      local other = activeSide == "player" and e or p
      local dx, dz = other[1] - actor[1], other[2] - actor[2]
      local len = math.sqrt(dx * dx + dz * dz)
      if len < 0.001 then len = 1 end
      local ux, uz = dx / len, dz / len
      local px2, pz2 = -uz, ux
      local sideSign = activeSide == "player" and 1 or -1
      local bx = -ux + px2 * 0.48 * sideSign
      local bz = -uz + pz2 * 0.48 * sideSign
      local targetAngle = wrap(math.atan2(bx, bz) + math.sin(BattleCinematic.t * 0.72) * 0.10)
      BattleCinematic.angle, BattleCinematic.angleVelocity = chaseAngle(
        BattleCinematic.angle, targetAngle,
        BattleCinematic.angleVelocity, dt)
    else
      -- Between turns/menu selection, widen back out and resume the slow orbit.
      local speed = resolving and 0.12 or 0.085
      if angleWasNil then BattleCinematic.angleVelocity = speed end
      BattleCinematic.angle, BattleCinematic.angleVelocity = orbitAngle(
        BattleCinematic.angle, BattleCinematic.angleVelocity, speed, dt)
    end
    BattleCinematic.manualPitch, BattleCinematic.pitchVelocity = chaseComfort(
      BattleCinematic.manualPitch, 0, BattleCinematic.pitchVelocity,
      dt, .9, BattleCinematic.MAX_AUTO_PITCH_RATE,
      BattleCinematic.MAX_AUTO_PITCH_ACCEL)
  end

  -- Active-turn shots push closer; menu/inter-turn shots leave more breathing room.
  local wantRadius = activeSide and (attack and 69 or 76) or (resolving and 88 or 100)
  local wantHeight = activeSide and (attack and 35 or 40) or 48
  -- Focus strongly favors the active Pokemon while retaining enough of the
  -- opponent's side to read the exchange. Between turns it eases to midpoint.
  local wantFx, wantFz = cx, cz
  if activeSide then
    local actor = activeSide == "player" and p or e
    local other = activeSide == "player" and e or p
    local actorWeight = attack and 0.82 or 0.74
    wantFx = actor[1] * actorWeight + other[1] * (1 - actorWeight)
    wantFz = actor[2] * actorWeight + other[2] * (1 - actorWeight)
  end
  BattleCinematic.focusX = BattleCinematic.focusX or cx
  BattleCinematic.focusZ = BattleCinematic.focusZ or cz
  if not manual then
    BattleCinematic.radius, BattleCinematic.radiusVelocity = chaseComfort(
      BattleCinematic.radius, wantRadius, BattleCinematic.radiusVelocity,
      dt, .65, BattleCinematic.MAX_RADIUS_RATE,
      BattleCinematic.MAX_RADIUS_ACCEL)
    BattleCinematic.height, BattleCinematic.heightVelocity = chaseComfort(
      BattleCinematic.height, wantHeight, BattleCinematic.heightVelocity,
      dt, .65, BattleCinematic.MAX_HEIGHT_RATE,
      BattleCinematic.MAX_HEIGHT_ACCEL)
    BattleCinematic.focusX, BattleCinematic.focusZ,
      BattleCinematic.focusVelocityX, BattleCinematic.focusVelocityZ = chasePoint(
        BattleCinematic.focusX, BattleCinematic.focusZ, wantFx, wantFz,
        BattleCinematic.focusVelocityX, BattleCinematic.focusVelocityZ, dt)
  end
  BattleCinematic.activeSide = activeSide

  local a = BattleCinematic.angle
  local r = BattleCinematic.radius * BattleCinematic.zoom
  local fx, fz = BattleCinematic.focusX, BattleCinematic.focusZ
  local eyeY = gy + 12 + (BattleCinematic.height - 12) * BattleCinematic.zoom
    + BattleCinematic.manualPitch * 42
  local eye = { fx + math.sin(a) * r, eyeY, fz + math.cos(a) * r }
  local focus = { fx, gy + 12, fz }
  local cam = {
    eye = eye,
    focus = focus,
    up = { 0, 1, 0 },
    fov = math.rad(55),
    curve = 0,
    _stadiumBattleCinematic = true,
  }
  local safetyReason, safetyCandidate
  cam, safetyReason, safetyCandidate = safeCamera(ctx, arena, gy, cam)
  if not cam then
    -- A live MAP battle is already rendering through VoxelScene, which placed
    -- the selected free-roam MAP camera immediately before calling us. Latch
    -- that owner for this battle token instead of alternating MAP -> SMART on
    -- the next safe frame. Portable ARENA/DISCS keep their authored rig.
    if BattleCinematic._frameLiveMap then
      latchMapFallback(ownerToken, phaseOf(screen), safetyReason,
                       BattleCinematic.lastSafetyAttempts)
      return nil
    end
    BattleCinematic.lastReceipt = {
      schema="voxel-ascendant/gen2-smart-camera/v1", enabled=true,
      safe=false, fallback="authored-rig", safetyReason=safetyReason,
      fallbackLatched=false, cameraOwner="authored-rig",
      safetyAttempts=BattleCinematic.lastSafetyAttempts,
      phase=tostring(screen and screen.phase or ""),
    }
    BattleCinematic.lastActive = true
    return nil
  end
  local phase = tostring(screen and screen.phase or "")
  local receipt = {
    schema="voxel-ascendant/gen2-smart-camera/v1",
    enabled=true, cameraOwner="smart", phase=phase, activeSide=activeSide,
    attack=attack and true or false,
    angle=BattleCinematic.angle, radius=BattleCinematic.radius,
    height=BattleCinematic.height,
    zoom=BattleCinematic.zoom,
    focusX=BattleCinematic.focusX, focusZ=BattleCinematic.focusZ,
    safe=true, safetyReason=safetyReason,
    safetyCandidate=safetyCandidate,
  }
  BattleCinematic.lastReceipt = receipt
  if activeSide then BattleCinematic.lastActionReceipt = receipt end
  local signature = table.concat({ phase, tostring(activeSide),
    tostring(receipt.attack) }, "|")
  if signature ~= BattleCinematic._diagnosticSignature then
    BattleCinematic._diagnosticSignature = signature
    if type(Diagnostics.write) == "function" then
      pcall(Diagnostics.write, "gen2-battle-smart-camera", {
        phase=phase, side=activeSide or "none", attack=receipt.attack,
        radius=("%.2f"):format(receipt.radius),
        height=("%.2f"):format(receipt.height),
      })
    end
  end
  BattleCinematic.lastActive = true
  return cam, cx, cz
end

function BattleCinematic.receipt()
  return BattleCinematic.lastReceipt
end

function BattleCinematic.actionReceipt()
  return BattleCinematic.lastActionReceipt
end

-- A presentation camera must never be able to take the game down. Gen1Recomp
-- battle internals are intentionally allowed to evolve, so keep the entire
-- optional cinematic behind one pcall. If a future/older BattleState exposes
-- a shape we did not expect, the live-world battle simply uses the ordinary
-- overworld camera for that frame and gameplay continues.
function BattleCinematic.frame(dt)
  local ok, cam, cx, cz = pcall(frameImpl, dt)
  if ok then return cam, cx, cz end

  if not BattleCinematic._errorLogged then
    BattleCinematic._errorLogged = true
    pcall(function()
      if V.mod and V.mod.log and type(V.mod.log.warn) == "function" then
        V.mod.log:warn("Stadium battle camera disabled after recoverable error: %s",
                       tostring(cam))
      end
    end)
  end
  -- Once a live MAP SMART camera errors, keep the already placed MAP camera
  -- in charge for this exact battle. Retrying SMART on the next frame caused
  -- the visible 3rd-person -> bird's-eye/free-roam -> SMART oscillation. The
  -- portable BattleScene path retains its original reset/authored behavior.
  if BattleCinematic._frameLiveMap
      and latchMapFallback(BattleCinematic._frameOwnerToken,
                           BattleCinematic._framePhase,
                           "camera-error:" .. tostring(cam), nil) then
    return nil
  end
  BattleCinematic.reset()
  return nil
end

return BattleCinematic
