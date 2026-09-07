-- Direct player control for Gold live-world Stadium battles.
--
-- This is deliberately presentation-only. Gold still owns turns, HP, items,
-- switching and battle outcomes. While the player's Stadium model is actually
-- standing in the 3D arena, the left stick can move that model around and the
-- west face button (SDL gamepad "x": PlayStation Square / Xbox X) plays one
-- of that species' imported Stadium 2 attack performances.
local V = ...
local M = {}

M.SPEED = 38.0
M.DEADZONE = 0.18
M.ARENA_RADIUS = 60.0
M.MIN_ENEMY_GAP = 11.0

local state = {
  active = false,
  attackHeld = false,
  attackPulse = 0,
  originX = nil,
  originZ = nil,
  lastArena = nil,
  moved = false,
}

local function clamp(v, lo, hi)
  return math.max(lo, math.min(hi, v))
end

local function mappedPad()
  local J = love and love.joystick
  if not (J and type(J.getJoysticks) == "function") then return nil end
  local ok, list = pcall(J.getJoysticks)
  if not ok or type(list) ~= "table" then return nil end
  local best, bestMag = nil, -1
  for _, js in ipairs(list) do
    local okPad, isPad = pcall(function()
      return js and type(js.isGamepad) == "function" and js:isGamepad()
    end)
    if okPad and isPad and type(js.getGamepadAxis) == "function" then
      local okX, lx = pcall(js.getGamepadAxis, js, "leftx")
      local okY, ly = pcall(js.getGamepadAxis, js, "lefty")
      if okX and okY then
        lx, ly = tonumber(lx) or 0, tonumber(ly) or 0
        local mag = lx * lx + ly * ly
        if mag > bestMag then
          best, bestMag = { js = js, x = lx, y = ly }, mag
        end
      end
    end
  end
  return best
end

local function buttonDown(js, button)
  if not (js and type(js.isGamepadDown) == "function") then return false end
  local ok, down = pcall(js.isGamepadDown, js, button)
  return ok and down and true or false
end

local function keyboardMove()
  local K = love and love.keyboard
  if not (K and type(K.isDown) == "function") then return 0, 0 end
  local function down(key)
    local ok, yes = pcall(K.isDown, key)
    return ok and yes and 1 or 0
  end
  -- Arrow keys belong to the new command diamond while the main menu is up.
  -- WASD therefore gives desktop players uninterrupted Pokemon locomotion
  -- without stealing Gold's move-list arrows after FIGHT is opened.
  local x = down("d") - down("a")
  local y = down("s") - down("w")
  return x, y
end

local function cameraBasis(arena)
  -- Prefer the camera that actually rendered the previous frame. This makes
  -- stick movement camera-relative without coupling this module to one camera
  -- implementation. If no placed camera exists yet, face from player to foe.
  local okV, Voxel3D = pcall(V.require, "Voxel3D")
  local cam = okV and Voxel3D and Voxel3D.camera or nil
  local eye, focus = cam and cam.eye, cam and cam.focus
  local fx, fz
  if type(eye) == "table" and type(focus) == "table" then
    fx = (tonumber(focus[1]) or 0) - (tonumber(eye[1]) or 0)
    fz = (tonumber(focus[3]) or 0) - (tonumber(eye[3]) or 0)
  end
  local len = fx and math.sqrt(fx * fx + fz * fz) or 0
  if not (len and len > 0.001) then
    local p, e = arena and arena.player, arena and arena.enemy
    fx = ((e and tonumber(e[1])) or 0) - ((p and tonumber(p[1])) or 0)
    fz = ((e and tonumber(e[2])) or 0) - ((p and tonumber(p[2])) or 0)
    len = math.sqrt(fx * fx + fz * fz)
  end
  if not (len and len > 0.001) then fx, fz, len = 0, -1, 1 end
  fx, fz = fx / len, fz / len
  -- right = forward x up in the X/Z plane
  return fx, fz, -fz, fx
end

local function reset()
  state.active = false
  state.attackHeld = false
  state.attackPulse = 0
  state.originX, state.originZ = nil, nil
  state.lastArena = nil
  state.moved = false
end

local function controlContext(screen)
  local okO, OverworldBattle = pcall(V.require, "OverworldBattle")
  if not okO or not OverworldBattle or type(OverworldBattle.cameraContext) ~= "function" then
    return nil
  end
  local ctx = OverworldBattle.cameraContext()
  if not (ctx and ctx.arena and ctx.screen == screen) then return nil end
  local okS, Stadium = pcall(V.require, "Stadium")
  if not okS or not Stadium then return nil end
  if type(Stadium.controlReady) == "function" then
    local okReady, ready = pcall(Stadium.controlReady, "player")
    if not (okReady and ready) then return nil end
  elseif type(Stadium.visible) == "function" then
    local okReady, ready = pcall(Stadium.visible, "player")
    if not (okReady and ready) then return nil end
  end
  return ctx, Stadium
end

local function movePlayer(dt, arena, lx, ly)
  local p, e = arena.player, arena.enemy
  if not (type(p) == "table" and type(e) == "table") then return false end
  local px, pz = tonumber(p[1]), tonumber(p[2])
  local ex, ez = tonumber(e[1]), tonumber(e[2])
  if not (px and pz and ex and ez) then return false end

  local mag = math.sqrt(lx * lx + ly * ly)
  if mag <= M.DEADZONE then return false end
  local scaled = (mag - M.DEADZONE) / (1 - M.DEADZONE)
  scaled = clamp(scaled, 0, 1)
  lx, ly = lx / mag * scaled, ly / mag * scaled

  local fx, fz, rx, rz = cameraBasis(arena)
  local wishX = rx * lx + fx * (-ly)
  local wishZ = rz * lx + fz * (-ly)
  local wishLen = math.sqrt(wishX * wishX + wishZ * wishZ)
  if wishLen <= 0.001 then return false end
  wishX, wishZ = wishX / wishLen, wishZ / wishLen

  local step = M.SPEED * math.max(0, math.min(0.05, tonumber(dt) or 0)) * scaled
  local nx, nz = px + wishX * step, pz + wishZ * step

  -- Keep the player in the staged encounter area. The centre is captured once
  -- per battle so updating arena.mid for the camera never moves the boundary.
  local ox, oz = state.originX, state.originZ
  local dx, dz = nx - ox, nz - oz
  local d = math.sqrt(dx * dx + dz * dz)
  if d > M.ARENA_RADIUS then
    nx = ox + dx / d * M.ARENA_RADIUS
    nz = oz + dz / d * M.ARENA_RADIUS
  end

  -- Do not allow the two model centres to occupy the same point. Sliding along
  -- this small circle still lets the player run around the opponent.
  local edx, edz = nx - ex, nz - ez
  local ed = math.sqrt(edx * edx + edz * edz)
  if ed < M.MIN_ENEMY_GAP then
    if ed < 0.001 then edx, edz, ed = -wishX, -wishZ, 1 end
    nx = ex + edx / ed * M.MIN_ENEMY_GAP
    nz = ez + edz / ed * M.MIN_ENEMY_GAP
  end

  p[1], p[2] = nx, nz
  arena.playerCell = { math.floor(nx / 16), math.floor(nz / 16) }
  arena.mid = arena.mid or { 0, 0 }
  arena.mid[1], arena.mid[2] = (nx + ex) * 0.5, (nz + ez) * 0.5
  state.moved = true
  return true
end

function M.update(dt, screen)
  local ctx, Stadium = controlContext(screen)
  if not ctx then
    if state.active then reset() end
    return false
  end

  local arena = ctx.arena
  if state.lastArena ~= arena then
    state.lastArena = arena
    local p, e = arena.player, arena.enemy
    local px, pz = p and tonumber(p[1]), p and tonumber(p[2])
    local ex, ez = e and tonumber(e[1]), e and tonumber(e[2])
    if px and pz and ex and ez then
      -- Centre the movement boundary on the encounter pair, not on a mutable
      -- cinematic midpoint.
      state.originX, state.originZ = (px + ex) * 0.5, (pz + ez) * 0.5
    else
      state.originX, state.originZ = 0, 0
    end
  end
  state.active = true
  state.attackPulse = math.max(0, state.attackPulse - (tonumber(dt) or 0))

  local pad = mappedPad()
  local lx, ly = 0, 0
  if pad then lx, ly = pad.x, pad.y end
  local kx, ky = keyboardMove()
  -- Prefer whichever device has the stronger intent this frame. This avoids a
  -- resting controller adding drift to a keyboard player and vice versa.
  if kx ~= 0 or ky ~= 0 then lx, ly = kx, ky end
  movePlayer(dt, arena, lx, ly)

  local down = pad and buttonDown(pad.js, "x") or false
  -- Square/X now belongs to FIGHT while Gold's four-command menu is visible,
  -- and the normal confirm path owns it inside the move list. Keep the old
  -- presentation-only manual attack available only while the turn is already
  -- resolving, where it cannot hijack a menu command.
  local allowManualAttack = screen and screen.phase == "resolving"
  if allowManualAttack and down and not state.attackHeld then
    local okAttack, played = false, false
    if type(Stadium.manualAttack) == "function" then
      okAttack, played = pcall(Stadium.manualAttack, "player")
    end
    if okAttack and played then state.attackPulse = 0.35 end
  end
  state.attackHeld = down
  return true
end

function M.active()
  return state.active and true or false
end

function M.attacking()
  return state.attackPulse > 0
end

function M.moved()
  return state.moved and true or false
end

function M.reset()
  reset()
end

function M.status()
  return {
    active = M.active(),
    attacking = M.attacking(),
    moved = state.moved and true or false,
    speed = M.SPEED,
    radius = M.ARENA_RADIUS,
    controls = "left stick or WASD move; Square is Fight on command menu; manual clip only while resolving",
  }
end

return M
