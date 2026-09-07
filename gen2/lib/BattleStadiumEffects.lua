-- Pokemon Stadium Overworld Models - Phase 2 + Phase 3 + Phase 4 battle presentation
--
-- Safe presentation-only overlay for common Gen 1 move families plus dedicated
-- Phase 3 signature-move effects plus Phase 4 timing/impact polish. The
-- engine already owns timing, damage, sounds and battle animation sequencing;
-- this module only adds a more Stadium-like particle pass to drawAnimLayer.
-- Dramatic Shape captures that same layer for its arena effects billboard, so
-- these particles automatically follow the staged 3D battle camera too.
--
-- No Stadium effect assets are bundled.  These are procedural LÖVE effects
-- inspired by the Stadium presentation, drawn from the live move type.
local V = ...
local M = {}

local PI = math.pi
local TAU = PI * 2
local unpackResults = (table and table.unpack) or unpack

-- Dramatic Shape's world-space Stadium effect pass already provides proper 3D
-- lightning for Electric moves.  The older Phase 2 Electric polyline was drawn
-- on Gen1Recomp's flat animation plane; once that plane is perspective-mapped
-- into the voxel arena it can become a huge diagonal yellow streak across the
-- screen.  Detect the live Phase 5 renderer and suppress only that redundant
-- flat Electric overlay.  The game's stock move animation and the 3D lightning
-- remain intact.
local Stadium3D
do
  local ok, stadium = pcall(V.require, "Stadium")
  if ok and type(stadium) == "table" then Stadium3D = stadium end
end

local function stadiumWorldFxActive()
  if not (Stadium3D and Stadium3D._stadiumPhase5WorldFx) then return false end
  if type(Stadium3D.active) == "function" then
    local ok, active = pcall(Stadium3D.active)
    if ok then return active and true or false end
  end
  -- If the Phase 5 hook is installed but this Dramatic Shape revision does not
  -- expose active(), prefer avoiding the known stretched 2D bolt.
  return true
end

local function safeLog(level, fmt, ...)
  local log = V and V.mod and V.mod.log
  local fn = log and log[level]
  if type(fn) == "function" then pcall(fn, log, fmt, ...) end
end

local function clamp(x, a, b)
  if x < a then return a end
  if x > b then return b end
  return x
end

local function moveDef(battle)
  if not (battle and battle.animName and battle.data and battle.data.moves) then
    return nil
  end
  return battle.data.moves[battle.animName]
end

local function moveType(def)
  if type(def) ~= "table" then return nil end
  local t = def.type or def.moveType
  if type(t) == "table" then t = t.id or t.name end
  if type(t) ~= "string" then return nil end
  return string.upper(t):gsub("[^A-Z]", "")
end

local function movePower(def)
  local p = def and tonumber(def.power)
  return p or 0
end

local function normalizedMoveName(battle, def)
  local candidates = {
    def and def.name,
    def and def.id,
    battle and battle.animName,
  }
  for _, raw in ipairs(candidates) do
    if type(raw) == "string" and raw ~= "" then
      local k = string.upper(raw):gsub("[^A-Z0-9]", "")
      if k ~= "" then return k end
    end
  end
  return ""
end

-- Classic Gen 1 battle-slot anchor points.  These are the same two authored
-- points Dramatic Shape uses to pin the move-animation plane onto its arena.
local PLAYER = { 26, 78 }
local ENEMY  = { 124, 46 }

local function endpoints(battle)
  local playerAttacks = battle.animAttackerIsPlayer and true or false
  if playerAttacks then return PLAYER[1], PLAYER[2], ENEMY[1], ENEMY[2] end
  return ENEMY[1], ENEMY[2], PLAYER[1], PLAYER[2]
end

local function seedFor(battle)
  local f = tonumber(battle.frame) or 0
  local name = tostring(battle.animName or "")
  local h = 0
  for i = 1, #name do h = (h * 33 + name:byte(i)) % 104729 end
  return f * 0.173 + h * 0.00137
end

local function rand(seed, n)
  local x = math.sin(seed * 12.9898 + n * 78.233) * 43758.5453
  return x - math.floor(x)
end

local function withGraphics(fn)
  local g = love and love.graphics
  if not g then return end

  -- Keep the host battle renderer's canvas/shader/blend state intact. Some
  -- Android/LÖVE builds are stricter about graphics-state stack errors, so
  -- both push and pop are guarded and an effect failure is presentation-only.
  local pushed = false
  if type(g.push) == "function" then
    local okPush = pcall(g.push, "all")
    if not okPush then okPush = pcall(g.push) end
    pushed = okPush and true or false
  end

  local ok, err = pcall(fn, g)

  if pushed and type(g.pop) == "function" then
    pcall(g.pop)
  end
  if not ok then
    safeLog("warn", "Phase 2 battle effect draw failed: %s", tostring(err))
  end
end

local function linePoint(ax, ay, bx, by, t)
  return ax + (bx - ax) * t, ay + (by - ay) * t
end

local function drawImpact(g, tx, ty, phase, strength)
  local pulse = math.sin(clamp(phase, 0, 1) * PI)
  local r = 4 + 10 * pulse * strength
  g.setLineWidth(1.5)
  g.setColor(1.0, 0.96, 0.68, 0.78 * pulse)
  g.circle("line", tx, ty, r)
  g.setColor(1.0, 1.0, 1.0, 0.9 * pulse)
  for i = 1, 10 do
    local a = TAU * i / 10 + phase * 0.8
    local r0 = 3 + 4 * pulse
    local r1 = r + 4 + (i % 3)
    g.line(tx + math.cos(a) * r0, ty + math.sin(a) * r0,
           tx + math.cos(a) * r1, ty + math.sin(a) * r1)
  end
end

local function drawFire(g, ax, ay, tx, ty, phase, seed, strength)
  for i = 1, 18 do
    local q = (phase * 1.45 - i * 0.045) % 1
    local x, y = linePoint(ax, ay, tx, ty, q)
    local wobble = math.sin(q * 12 + seed + i) * (2 + 3 * q)
    local dx, dy = tx - ax, ty - ay
    local len = math.max(1, math.sqrt(dx * dx + dy * dy))
    x = x - dy / len * wobble
    y = y + dx / len * wobble
    local fade = 1 - math.abs(q - 0.55) * 0.65
    local rr = (2.2 + 3.6 * q) * strength
    g.setColor(1.0, 0.22 + 0.55 * (1 - q), 0.04, 0.72 * fade)
    g.circle("fill", x, y, rr)
    g.setColor(1.0, 0.86, 0.28, 0.75 * fade)
    g.circle("fill", x, y - rr * 0.3, rr * 0.48)
  end
  if phase > 0.52 then drawImpact(g, tx, ty, (phase - 0.52) / 0.48, strength) end
end

local function drawWater(g, ax, ay, tx, ty, phase, seed, strength)
  g.setLineWidth(2.2 * strength)
  local pts = {}
  for i = 0, 20 do
    local q = i / 20
    local travel = clamp((q - (1 - phase) * 1.4), 0, 1)
    local x, y = linePoint(ax, ay, tx, ty, q)
    local arc = math.sin(q * PI) * (8 + 5 * strength)
    local wave = math.sin(q * 20 + seed * 3) * 1.5
    y = y - arc + wave
    if travel > 0 then pts[#pts+1], pts[#pts+1] = x, y end
  end
  if #pts >= 4 then
    g.setColor(0.20, 0.67, 1.0, 0.78)
    g.line(pts)
    g.setLineWidth(1)
    g.setColor(0.78, 0.94, 1.0, 0.85)
    g.line(pts)
  end
  for i = 1, 10 do
    local q = (phase * 1.25 + i * 0.093) % 1
    local x, y = linePoint(ax, ay, tx, ty, q)
    y = y - math.sin(q * PI) * 9
    local rr = 1.2 + rand(seed, i) * 1.5
    g.setColor(0.38, 0.78, 1.0, 0.65)
    g.circle("fill", x, y, rr)
  end
  if phase > 0.58 then drawImpact(g, tx, ty, (phase - 0.58) / 0.42, strength * 0.9) end
end

local function drawElectric(g, ax, ay, tx, ty, phase, seed, strength)
  local dx, dy = tx - ax, ty - ay
  local len = math.max(1, math.sqrt(dx * dx + dy * dy))
  local nx, ny = -dy / len, dx / len
  local pts = { ax, ay }
  local segments = 12
  for i = 1, segments - 1 do
    local q = i / segments
    local x, y = linePoint(ax, ay, tx, ty, q)
    local jitter = (rand(seed + phase * 31, i) - 0.5) * 12 * strength
    pts[#pts+1], pts[#pts+1] = x + nx * jitter, y + ny * jitter
  end
  pts[#pts+1], pts[#pts+1] = tx, ty
  local pulse = 0.65 + 0.35 * math.sin(phase * TAU * 5)
  g.setLineWidth(3.4 * strength)
  g.setColor(1.0, 0.88, 0.10, 0.42 * pulse)
  g.line(pts)
  g.setLineWidth(1.2 * strength)
  g.setColor(1.0, 1.0, 0.86, 0.95 * pulse)
  g.line(pts)
  for i = 1, 7 do
    local a = rand(seed, i + 30) * TAU
    local r0 = 3 + rand(seed, i + 50) * 7
    local r1 = r0 + 3 + rand(seed, i + 70) * 6
    g.line(tx + math.cos(a) * r0, ty + math.sin(a) * r0,
           tx + math.cos(a) * r1, ty + math.sin(a) * r1)
  end
end

local function drawIce(g, ax, ay, tx, ty, phase, seed, strength)
  for i = 1, 14 do
    local q = clamp(phase * 1.25 - (i - 1) * 0.035, 0, 1)
    if q > 0 then
      local x, y = linePoint(ax, ay, tx, ty, q)
      y = y - math.sin(q * PI) * (5 + (i % 3))
      local a = seed + i * 1.7 + q * 2
      local s = (2.3 + rand(seed, i) * 2.8) * strength
      g.setColor(0.68, 0.94, 1.0, 0.78)
      g.polygon("fill",
        x + math.cos(a) * s * 1.7, y + math.sin(a) * s * 1.7,
        x + math.cos(a + 2.3) * s, y + math.sin(a + 2.3) * s,
        x + math.cos(a + 4.2) * s, y + math.sin(a + 4.2) * s)
      g.setColor(1, 1, 1, 0.65)
      g.circle("fill", x, y, 0.8 * strength)
    end
  end
  if phase > 0.55 then
    local p = (phase - 0.55) / 0.45
    g.setColor(0.72, 0.96, 1.0, 0.55 * (1 - p * 0.5))
    for i = 1, 6 do
      local a = TAU * i / 6 + seed
      local r = 4 + p * (10 + i)
      g.line(tx, ty, tx + math.cos(a) * r, ty + math.sin(a) * r)
    end
  end
end

local function drawPsychic(g, ax, ay, tx, ty, phase, seed, strength)
  local pulse = 0.5 + 0.5 * math.sin(phase * TAU * 3)
  for i = 1, 5 do
    local q = (phase * 1.35 + i * 0.16) % 1
    local x, y = linePoint(ax, ay, tx, ty, q)
    local r = (3 + q * 11 + i * 0.8) * strength
    g.setLineWidth(1.2)
    g.setColor(0.86, 0.25 + i * 0.06, 1.0, (0.55 - q * 0.28) * (0.65 + pulse * 0.35))
    g.ellipse("line", x, y, r, r * 0.52)
  end
  g.setColor(1.0, 0.65, 1.0, 0.40 + pulse * 0.30)
  g.circle("fill", tx, ty, (3 + 3 * pulse) * strength)
end

local function drawPoison(g, ax, ay, tx, ty, phase, seed, strength)
  for i = 1, 16 do
    local q = (phase * 1.05 + rand(seed, i) * 0.35) % 1
    local x, y = linePoint(ax, ay, tx, ty, q)
    x = x + (rand(seed + 2, i) - 0.5) * 12
    y = y - math.sin(q * PI) * 7 + (rand(seed + 4, i) - 0.5) * 5
    local rr = (1.8 + rand(seed + 6, i) * 3.2) * strength
    g.setColor(0.68, 0.15, 0.78, 0.48)
    g.circle("fill", x, y, rr)
    g.setColor(0.92, 0.46, 1.0, 0.55)
    g.circle("line", x, y, rr)
  end
  if phase > 0.62 then drawImpact(g, tx, ty, (phase - 0.62) / 0.38, strength * 0.75) end
end

local function drawNormal(g, ax, ay, tx, ty, phase, seed, strength)
  local travel = clamp(phase * 1.55, 0, 1)
  local x, y = linePoint(ax, ay, tx, ty, travel)
  local dx, dy = tx - ax, ty - ay
  local len = math.max(1, math.sqrt(dx * dx + dy * dy))
  local nx, ny = -dy / len, dx / len
  g.setLineWidth(1.2)
  for i = 1, 5 do
    local off = (i - 3) * 2.4
    local tail = 9 + i * 2
    g.setColor(1, 1, 1, 0.18 + i * 0.08)
    g.line(x + nx * off, y + ny * off,
           x - dx / len * tail + nx * off,
           y - dy / len * tail + ny * off)
  end
  if phase > 0.55 then drawImpact(g, tx, ty, (phase - 0.55) / 0.45, strength) end
end

-- Phase 3: dedicated signature-move renderers. These intentionally stay
-- entirely inside the normal move-animation layer; they never touch the active
-- Stadium model slot or battle-state transitions.

local function beamBasis(ax, ay, tx, ty)
  local dx, dy = tx - ax, ty - ay
  local len = math.max(1, math.sqrt(dx * dx + dy * dy))
  return dx, dy, len, -dy / len, dx / len
end

local function drawHyperBeam(g, ax, ay, tx, ty, phase, seed, strength)
  local dx, dy, len, nx, ny = beamBasis(ax, ay, tx, ty)
  local charge = clamp(phase / 0.22, 0, 1)
  if phase < 0.22 then
    local pulse = 0.55 + 0.45 * math.sin(phase * TAU * 12)
    g.setLineWidth(1.2)
    for i = 1, 4 do
      local r = (4 + i * 3) * charge * strength
      g.setColor(1.0, 0.86, 0.28, (0.70 - i * 0.10) * pulse)
      g.circle("line", ax, ay, r)
    end
    g.setColor(1, 1, 0.86, 0.85 * charge)
    g.circle("fill", ax, ay, (2 + 3 * charge) * strength)
    return
  end

  local fire = clamp((phase - 0.22) / 0.48, 0, 1)
  local tail = clamp((phase - 0.70) / 0.30, 0, 1)
  local alpha = 1 - tail
  local front = math.min(1, fire * 1.35)
  local ex, ey = linePoint(ax, ay, tx, ty, front)
  g.setLineWidth(10 * strength)
  g.setColor(1.0, 0.44, 0.12, 0.28 * alpha)
  g.line(ax, ay, ex, ey)
  g.setLineWidth(6 * strength)
  g.setColor(1.0, 0.82, 0.18, 0.78 * alpha)
  g.line(ax, ay, ex, ey)
  g.setLineWidth(2.1 * strength)
  g.setColor(1.0, 1.0, 0.90, 0.98 * alpha)
  g.line(ax, ay, ex, ey)
  for i = 1, 9 do
    local q = ((fire * 1.8 + i * 0.11) % 1) * front
    local x, y = linePoint(ax, ay, ex, ey, q)
    local r = (3 + i % 3) * strength
    g.setColor(1.0, 0.72, 0.12, 0.48 * alpha)
    g.circle("line", x + nx * math.sin(seed+i)*2, y + ny * math.sin(seed+i)*2, r)
  end
  if front > 0.94 then drawImpact(g, tx, ty, clamp((phase - 0.48) / 0.52, 0, 1), strength * 1.45) end
end

local function drawSolarBeam(g, ax, ay, tx, ty, phase, seed, strength)
  if phase < 0.34 then
    local q = phase / 0.34
    g.setLineWidth(1.2)
    for i = 1, 14 do
      local a = seed + i * 2.399 + phase * 2
      local r = (18 - q * 13) + (i % 4)
      local x, y = ax + math.cos(a) * r, ay + math.sin(a) * r
      g.setColor(0.72, 1.0, 0.32, 0.30 + q * 0.45)
      g.line(x, y, ax, ay)
    end
    g.setColor(0.88, 1.0, 0.72, 0.85 * q)
    g.circle("fill", ax, ay, (2 + q * 4) * strength)
    return
  end
  local q = clamp((phase - 0.34) / 0.50, 0, 1)
  local fade = 1 - clamp((phase - 0.84) / 0.16, 0, 1)
  local ex, ey = linePoint(ax, ay, tx, ty, math.min(1, q * 1.35))
  g.setLineWidth(9 * strength)
  g.setColor(0.35, 1.0, 0.30, 0.28 * fade)
  g.line(ax, ay, ex, ey)
  g.setLineWidth(4.4 * strength)
  g.setColor(0.78, 1.0, 0.42, 0.78 * fade)
  g.line(ax, ay, ex, ey)
  g.setLineWidth(1.6 * strength)
  g.setColor(0.96, 1.0, 0.90, 0.98 * fade)
  g.line(ax, ay, ex, ey)
  if q > 0.72 then drawImpact(g, tx, ty, clamp((q - 0.72) / 0.28, 0, 1), strength * 1.25) end
end

local function drawThunder(g, ax, ay, tx, ty, phase, seed, strength)
  local pulse = math.sin(clamp(phase * 1.25, 0, 1) * PI)
  local topY = -12
  for branch = 1, 3 do
    local pts = { tx + (branch - 2) * 7, topY }
    local sx = pts[1]
    local segments = 10
    for i = 1, segments do
      local q = i / segments
      local y = topY + (ty - topY) * q
      local x = sx + (rand(seed + branch * 7 + phase * 9, i) - 0.5) * (16 - q * 7)
      if i == segments then x = tx end
      pts[#pts+1], pts[#pts+1] = x, y
    end
    g.setLineWidth((branch == 2 and 4.2 or 2.2) * strength)
    g.setColor(1.0, 0.90, 0.12, 0.32 * pulse)
    g.line(pts)
    g.setLineWidth((branch == 2 and 1.6 or 0.9) * strength)
    g.setColor(1.0, 1.0, 0.92, 0.95 * pulse)
    g.line(pts)
  end
  g.setColor(1, 1, 1, 0.18 * pulse)
  g.rectangle("fill", 0, 0, 160, 112)
  if phase > 0.40 then drawImpact(g, tx, ty, clamp((phase - 0.40) / 0.60, 0, 1), strength * 1.2) end
end

local function drawSurf(g, ax, ay, tx, ty, phase, seed, strength)
  local q = clamp(phase * 1.12, 0, 1)
  local crestX = -32 + q * 224
  local base = 82
  local pts = { -30, 116 }
  for i = 0, 24 do
    local x = -24 + i * 9
    local near = math.exp(-((x - crestX) * (x - crestX)) / 900)
    local y = base - near * (24 + 7 * math.sin(phase * TAU)) - math.sin(i * 0.8 + seed) * 2
    pts[#pts+1], pts[#pts+1] = x, y
  end
  pts[#pts+1], pts[#pts+1] = 190, 116
  g.setColor(0.08, 0.48, 0.92, 0.50)
  g.polygon("fill", pts)
  g.setLineWidth(2.2 * strength)
  g.setColor(0.62, 0.92, 1.0, 0.86)
  for i = 0, 18 do
    local x = -20 + i * 11
    local near = math.exp(-((x - crestX) * (x - crestX)) / 900)
    local y = base - near * (24 + 7 * math.sin(phase * TAU)) - math.sin(i * 0.8 + seed) * 2
    if i > 0 then g.line(x - 11, y + math.sin((i-1)*0.8+seed)*2, x, y) end
  end
  for i = 1, 14 do
    local x = crestX + (rand(seed, i)-0.5)*35
    local y = base - 25 - rand(seed+1, i)*14
    g.setColor(0.82, 0.97, 1.0, 0.55)
    g.circle("fill", x, y, 1 + rand(seed+2, i)*1.8)
  end
end

local function drawEarthquake(g, ax, ay, tx, ty, phase, seed, strength)
  local q = math.sin(clamp(phase, 0, 1) * PI)
  local cx, cy = 80, 91
  g.setLineWidth(1.4)
  for i = 1, 8 do
    local a = (i / 8) * TAU + seed * 0.2
    local r1 = 7 + (i % 3) * 2
    local r2 = 22 + q * (14 + i)
    local mx = cx + math.cos(a + 0.18) * (r1 + r2) * 0.5
    local my = cy + math.sin(a + 0.18) * (r1 + r2) * 0.18
    g.setColor(0.62, 0.44, 0.20, 0.75 * q)
    g.line(cx + math.cos(a)*r1, cy + math.sin(a)*r1*0.20, mx, my,
           cx + math.cos(a)*r2, cy + math.sin(a)*r2*0.20)
  end
  for i = 1, 12 do
    local a = rand(seed, i) * TAU
    local r = 7 + rand(seed+4, i) * 32 * q
    local x, y = cx + math.cos(a)*r, cy + math.sin(a)*r*0.28
    g.setColor(0.74, 0.57, 0.32, 0.45 * q)
    g.circle("fill", x, y, 1 + rand(seed+7, i)*2.3)
  end
end

local function drawExplosion(g, ax, ay, tx, ty, phase, seed, strength)
  local cx, cy = ax, ay
  local q = clamp(phase / 0.78, 0, 1)
  local fade = 1 - clamp((phase - 0.58) / 0.42, 0, 1)
  local r = (5 + q * 45) * strength
  g.setColor(1.0, 0.90, 0.52, 0.26 * fade)
  g.circle("fill", cx, cy, r)
  g.setColor(1.0, 0.36, 0.06, 0.72 * fade)
  g.circle("line", cx, cy, r * 0.72)
  g.setColor(1.0, 1.0, 0.92, 0.75 * fade)
  g.circle("fill", cx, cy, math.max(0, r * 0.28))
  g.setLineWidth(2.0)
  for i = 1, 16 do
    local a = TAU * i / 16 + seed
    local r0 = 5 + q * 12
    local r1 = 10 + q * (34 + (i % 4) * 4)
    g.setColor(1.0, 0.55 + (i%2)*0.25, 0.12, 0.72 * fade)
    g.line(cx + math.cos(a)*r0, cy + math.sin(a)*r0,
           cx + math.cos(a)*r1, cy + math.sin(a)*r1)
  end
  g.setColor(1, 1, 1, 0.35 * math.sin(clamp(phase*1.8,0,1)*PI))
  g.rectangle("fill", 0, 0, 160, 112)
end

local function drawFireBlast(g, ax, ay, tx, ty, phase, seed, strength)
  local q = clamp(phase * 1.35, 0, 1)
  local x, y = linePoint(ax, ay, tx, ty, q)
  local radius = (6 + 7 * q) * strength
  g.setLineWidth(3 * strength)
  g.setColor(1.0, 0.28, 0.03, 0.75)
  for arm = 1, 5 do
    local a = -PI/2 + (arm-1)*TAU/5 + phase*0.6
    g.line(x, y, x + math.cos(a)*radius*1.7, y + math.sin(a)*radius*1.7)
  end
  g.setColor(1.0, 0.84, 0.18, 0.86)
  g.circle("fill", x, y, radius * 0.55)
  if q > 0.82 then
    local p = clamp((q - 0.82) / 0.18, 0, 1)
    for i = 1, 14 do
      local a = TAU * i/14 + seed
      local r = 5 + p * (10 + i%5)
      g.setColor(1.0, 0.35 + (i%3)*0.14, 0.03, 0.65*(1-p*0.45))
      g.circle("fill", tx + math.cos(a)*r, ty + math.sin(a)*r, 1.5 + (i%3))
    end
  end
end

local function drawHydroPump(g, ax, ay, tx, ty, phase, seed, strength)
  local q = clamp(phase * 1.3, 0, 1)
  local ex, ey = linePoint(ax, ay, tx, ty, q)
  local dx, dy, len, nx, ny = beamBasis(ax, ay, tx, ty)
  for lane = -2, 2 do
    local off = lane * 2.2 * strength
    local wob = math.sin(phase*TAU*3 + lane) * 1.2
    g.setLineWidth((lane == 0 and 3.4 or 2.2) * strength)
    if lane == 0 then g.setColor(0.85, 0.98, 1.0, 0.92)
    else g.setColor(0.12, 0.58, 1.0, 0.58) end
    g.line(ax + nx*(off+wob), ay + ny*(off+wob),
           ex + nx*(off-wob), ey + ny*(off-wob))
  end
  for i = 1, 18 do
    local t = (q + rand(seed, i)*0.24) % 1
    local x, y = linePoint(ax, ay, tx, ty, t)
    local o = (rand(seed+3, i)-0.5)*13
    g.setColor(0.56, 0.88, 1.0, 0.62)
    g.circle("fill", x + nx*o, y + ny*o, 1 + rand(seed+5,i)*2.2)
  end
  if q > 0.88 then drawImpact(g, tx, ty, clamp((q-.88)/.12,0,1), strength*1.35) end
end

local function drawBlizzard(g, ax, ay, tx, ty, phase, seed, strength)
  local q = math.sin(clamp(phase,0,1)*PI)
  for i = 1, 28 do
    local a = phase * TAU * (0.45 + (i%4)*0.08) + rand(seed,i)*TAU
    local r = 4 + rand(seed+2,i) * (28 + 12*q)
    local x = tx + math.cos(a)*r
    local y = ty + math.sin(a)*r*0.55 - phase*10
    local s = 1.1 + rand(seed+4,i)*2.1
    g.setColor(0.82, 0.97, 1.0, (0.30 + rand(seed+5,i)*0.5)*q)
    g.line(x-s, y, x+s, y)
    g.line(x, y-s, x, y+s)
  end
  g.setColor(0.68, 0.92, 1.0, 0.12*q)
  g.circle("fill", tx, ty, 30*strength)
end

local function drawIceBeam(g, ax, ay, tx, ty, phase, seed, strength)
  local q = clamp(phase * 1.35, 0, 1)
  local ex, ey = linePoint(ax, ay, tx, ty, q)
  g.setLineWidth(6*strength)
  g.setColor(0.42, 0.88, 1.0, 0.28)
  g.line(ax, ay, ex, ey)
  g.setLineWidth(2.2*strength)
  g.setColor(0.88, 0.99, 1.0, 0.94)
  g.line(ax, ay, ex, ey)
  if q > 0.80 then
    local p=clamp((q-.80)/.20,0,1)
    for i=1,10 do
      local a=TAU*i/10+seed
      local r=3+p*(8+i%4)
      g.setColor(0.62,0.93,1.0,0.72)
      g.line(tx,ty,tx+math.cos(a)*r,ty+math.sin(a)*r)
    end
  end
end

local function drawPsychicSignature(g, ax, ay, tx, ty, phase, seed, strength)
  local q = math.sin(clamp(phase,0,1)*PI)
  for i=1,7 do
    local r=(4+i*4 + math.sin(phase*TAU*2+i)*3)*strength
    g.setLineWidth(1.2 + (i%2)*0.5)
    g.setColor(0.85,0.28+0.06*i,1.0,(0.62-i*0.055)*q)
    g.ellipse("line",tx,ty,r,r*(0.38+0.04*i))
  end
  g.setColor(1.0,0.68,1.0,0.28*q)
  g.circle("fill",tx,ty,8*strength)
end

local function drawRockSlide(g, ax, ay, tx, ty, phase, seed, strength)
  local q=clamp(phase*1.1,0,1)
  for i=1,12 do
    local delay=(i-1)*0.035
    local p=clamp((q-delay)/(1-delay),0,1)
    local x=tx+(rand(seed,i)-0.5)*35
    local y=-8 + p*(ty+18)
    local rr=(2.5+rand(seed+2,i)*4.2)*strength
    g.setColor(0.55,0.40,0.24,0.82)
    g.polygon("fill",x-rr,y,x-rr*.3,y-rr,x+rr,y-rr*.2,x+rr*.5,y+rr,x-rr*.6,y+rr*.7)
  end
  if q>.72 then drawImpact(g,tx,ty,clamp((q-.72)/.28,0,1),strength) end
end

local function drawSwift(g, ax, ay, tx, ty, phase, seed, strength)
  for i=1,7 do
    local q=clamp(phase*1.35-(i-1)*.055,0,1)
    if q>0 then
      local x,y=linePoint(ax,ay,tx,ty,q)
      local o=math.sin(q*PI*2+i)*7
      local dx,dy,len,nx,ny=beamBasis(ax,ay,tx,ty)
      x,y=x+nx*o,y+ny*o
      local r=(2.2+(i%2))*strength
      g.setColor(1.0,0.92,0.28,0.86)
      local pts={}
      for k=1,10 do
        local a=-PI/2+(k-1)*PI/5
        local rr=(k%2==1) and r*1.7 or r*.75
        pts[#pts+1],pts[#pts+1]=x+math.cos(a)*rr,y+math.sin(a)*rr
      end
      g.polygon("fill",pts)
    end
  end
end

local SPECIAL = {
  HYPERBEAM = "hyperbeam",
  SOLARBEAM = "solarbeam",
  THUNDER = "thunder",
  SURF = "surf",
  EARTHQUAKE = "earthquake",
  EXPLOSION = "explosion",
  SELFDESTRUCT = "explosion",
  FIREBLAST = "fireblast",
  HYDROPUMP = "hydropump",
  BLIZZARD = "blizzard",
  ICEBEAM = "icebeam",
  PSYCHIC = "psychicspecial",
  ROCKSLIDE = "rockslide",
  SWIFT = "swift",
}

local function drawSpecial(g, special, ax, ay, tx, ty, phase, seed, strength)
  if special == "hyperbeam" then drawHyperBeam(g,ax,ay,tx,ty,phase,seed,strength)
  elseif special == "solarbeam" then drawSolarBeam(g,ax,ay,tx,ty,phase,seed,strength)
  elseif special == "thunder" then drawThunder(g,ax,ay,tx,ty,phase,seed,strength)
  elseif special == "surf" then drawSurf(g,ax,ay,tx,ty,phase,seed,strength)
  elseif special == "earthquake" then drawEarthquake(g,ax,ay,tx,ty,phase,seed,strength)
  elseif special == "explosion" then drawExplosion(g,ax,ay,tx,ty,phase,seed,strength)
  elseif special == "fireblast" then drawFireBlast(g,ax,ay,tx,ty,phase,seed,strength)
  elseif special == "hydropump" then drawHydroPump(g,ax,ay,tx,ty,phase,seed,strength)
  elseif special == "blizzard" then drawBlizzard(g,ax,ay,tx,ty,phase,seed,strength)
  elseif special == "icebeam" then drawIceBeam(g,ax,ay,tx,ty,phase,seed,strength)
  elseif special == "psychicspecial" then drawPsychicSignature(g,ax,ay,tx,ty,phase,seed,strength)
  elseif special == "rockslide" then drawRockSlide(g,ax,ay,tx,ty,phase,seed,strength)
  elseif special == "swift" then drawSwift(g,ax,ay,tx,ty,phase,seed,strength)
  else return false end
  return true
end



-- Phase 4 presentation profiles. These are deliberately presentation-only:
-- no battle timers, HP state, damage logic, or Pokemon model lifecycle is
-- modified. "Hit stop" is a short visual hold in our effect phase rather than
-- actually freezing BattleState, which keeps this compatible with Android and
-- Dramatic Shape's projected animation layer.
local PHASE4_PROFILE = {
  hyperbeam   = { impact = 0.58, hold = 0.085, shake = 3.0, flash = 0.26 },
  solarbeam   = { impact = 0.72, hold = 0.060, shake = 2.0, flash = 0.18 },
  thunder     = { impact = 0.46, hold = 0.080, shake = 3.4, flash = 0.30 },
  surf        = { impact = 0.62, hold = 0.045, shake = 1.8, flash = 0.10 },
  earthquake  = { impact = 0.42, hold = 0.095, shake = 3.8, flash = 0.08 },
  explosion   = { impact = 0.38, hold = 0.110, shake = 4.5, flash = 0.38 },
  fireblast   = { impact = 0.78, hold = 0.060, shake = 2.5, flash = 0.18 },
  hydropump   = { impact = 0.82, hold = 0.060, shake = 2.7, flash = 0.16 },
  blizzard    = { impact = 0.66, hold = 0.050, shake = 1.7, flash = 0.14 },
  icebeam     = { impact = 0.79, hold = 0.055, shake = 1.8, flash = 0.18 },
  psychicspecial = { impact = 0.55, hold = 0.065, shake = 2.0, flash = 0.16 },
  rockslide   = { impact = 0.58, hold = 0.075, shake = 3.0, flash = 0.10 },
  swift       = { impact = 0.76, hold = 0.035, shake = 1.2, flash = 0.12 },

  fire     = { impact = 0.62, hold = 0.035, shake = 1.5, flash = 0.10 },
  water    = { impact = 0.67, hold = 0.030, shake = 1.3, flash = 0.08 },
  electric = { impact = 0.52, hold = 0.045, shake = 2.0, flash = 0.18 },
  ice      = { impact = 0.64, hold = 0.035, shake = 1.3, flash = 0.12 },
  psychic  = { impact = 0.58, hold = 0.040, shake = 1.3, flash = 0.12 },
  poison   = { impact = 0.68, hold = 0.025, shake = 0.9, flash = 0.06 },
  normal   = { impact = 0.63, hold = 0.050, shake = 2.2, flash = 0.12 },
}

local function phase4Profile(special, family, strength)
  local src = PHASE4_PROFILE[special] or PHASE4_PROFILE[family] or PHASE4_PROFILE.normal
  local k = clamp(tonumber(strength) or 1, 0.75, 1.55)
  return {
    impact = src.impact,
    hold = src.hold,
    shake = src.shake * (0.78 + 0.22 * k),
    flash = src.flash * (0.82 + 0.18 * k),
  }
end

-- Remap the normalized effect phase into a tiny plateau centered on impact.
-- The battle itself keeps running normally; only our procedural overlay appears
-- to "hang" for a few frames, which reads like Stadium hit-stop without ever
-- interfering with battle sequencing.
local function visualHitStop(phase, profile)
  local impact = profile and profile.impact or 0.62
  local hold = profile and profile.hold or 0
  if hold <= 0 then return phase end
  local half = hold * 0.5
  local a, b = impact - half, impact + half
  if phase < a then
    return phase * impact / math.max(0.001, a)
  elseif phase <= b then
    return impact
  end
  return impact + (phase - b) * (1 - impact) / math.max(0.001, 1 - b)
end

local function impactEnvelope(phase, profile)
  local impact = profile and profile.impact or 0.62
  local d = math.abs(phase - impact)
  local width = 0.13 + (profile and profile.hold or 0) * 0.6
  return clamp(1 - d / width, 0, 1)
end

local function drawPhase4Polish(g, tx, ty, rawPhase, profile, seed, strength)
  local env = impactEnvelope(rawPhase, profile)
  if env <= 0 then return end

  -- Tight target flash and concentric impact rings. Keep the full-screen flash
  -- brief and translucent so Gen1Recomp's own move readability remains intact.
  local pulse = math.sin(env * PI * 0.5)
  local flash = (profile.flash or 0.1) * pulse
  if flash > 0.01 then
    g.setColor(1, 1, 1, flash)
    g.rectangle("fill", 0, 0, 160, 112)
  end

  local r = (4 + (1 - env) * 13) * (0.8 + strength * 0.2)
  g.setLineWidth(1.2)
  g.setColor(1, 1, 1, 0.48 * env)
  g.circle("line", tx, ty, r)
  g.setColor(1.0, 0.86, 0.52, 0.32 * env)
  g.circle("line", tx, ty, r * 1.45)

  for i = 1, 6 do
    local a = TAU * i / 6 + seed * 0.37
    local rr = 5 + (1 - env) * (8 + i)
    g.setColor(1, 1, 1, 0.36 * env)
    g.line(tx + math.cos(a) * 3, ty + math.sin(a) * 3,
           tx + math.cos(a) * rr, ty + math.sin(a) * rr)
  end
end

local function phase4Shake(rawPhase, profile, seed)
  local env = impactEnvelope(rawPhase, profile)
  local amount = (profile and profile.shake or 0) * env
  if amount <= 0.01 then return 0, 0 end
  -- Deterministic per frame: avoids random-state coupling with the game.
  local sx = (rand(seed + rawPhase * 71, 301) - 0.5) * 2 * amount
  local sy = (rand(seed + rawPhase * 83, 307) - 0.5) * 2 * amount * 0.65
  return sx, sy
end

local FAMILY = {
  FIRE = "fire",
  WATER = "water",
  ELECTRIC = "electric",
  ICE = "ice",
  PSYCHIC = "psychic",
  POISON = "poison",
  -- Dark is a special type in Gen 2; reuse the readable psychic/shadow-like
  -- procedural family for moves without a dedicated signature effect.
  DARK = "psychic",
}

local PHYSICAL = {
  NORMAL = true, FIGHTING = true, GROUND = true, ROCK = true,
  BUG = true, GHOST = true, DRAGON = true, STEEL = true,
}

local function familyFor(def)
  local t = moveType(def)
  if FAMILY[t] then return FAMILY[t] end
  if PHYSICAL[t] and movePower(def) > 0 then return "normal" end
  return nil
end

local function drawEffect(battle)
  local def = moveDef(battle)
  if not def then return end
  local family = familyFor(def)
  local special = SPECIAL[normalizedMoveName(battle, def)]
  if not family and not special then return end

  -- Electric attacks already have a real world-space lightning pass in Phase 5.
  -- Do not also draw the legacy 2D bolt on Dramatic Shape's projected animation
  -- plane; that duplicate is the long diagonal line seen on Android/3D cameras.
  if family == "electric" and stadiumWorldFxActive() then return end

  -- drawAnimLayer exists only while the engine is displaying an animation.
  -- Using the battle frame modulo a compact cycle keeps us independent from
  -- internal AnimPlayer frame fields that have changed across recomp builds.
  local duration = special and 52 or 42
  local rawPhase = ((tonumber(battle.frame) or 0) % duration) / (duration - 1)
  local power = movePower(def)
  local strength = clamp(0.80 + power / 240, 0.80, 1.45)
  local ax, ay, tx, ty = endpoints(battle)
  local seed = seedFor(battle)
  local profile = phase4Profile(special, family, strength)
  local phase = visualHitStop(rawPhase, profile)
  local sx, sy = phase4Shake(rawPhase, profile, seed)

  withGraphics(function(g)
    g.setBlendMode("alpha")
    -- Shake only this animation plane/effect composition, never BattleState or
    -- the Pokemon model lifecycle. Dramatic Shape projects this same layer into
    -- its arena, so the shake reads as impact motion in 3D too.
    if type(g.translate) == "function" and (sx ~= 0 or sy ~= 0) then
      g.translate(sx, sy)
    end

    -- Signature moves replace, rather than stack on top of, their generic
    -- Phase 2 family. This keeps Hyper Beam/Surf/etc visually distinct.
    if special and drawSpecial(g, special, ax, ay, tx, ty, phase, seed, strength) then
      drawPhase4Polish(g, tx, ty, rawPhase, profile, seed, strength)
      return
    elseif family == "fire" then
      drawFire(g, ax, ay, tx, ty, phase, seed, strength)
    elseif family == "water" then
      drawWater(g, ax, ay, tx, ty, phase, seed, strength)
    elseif family == "electric" then
      drawElectric(g, ax, ay, tx, ty, phase, seed, strength)
    elseif family == "ice" then
      drawIce(g, ax, ay, tx, ty, phase, seed, strength)
    elseif family == "psychic" then
      drawPsychic(g, ax, ay, tx, ty, phase, seed, strength)
    elseif family == "poison" then
      drawPoison(g, ax, ay, tx, ty, phase, seed, strength)
    elseif family == "normal" then
      drawNormal(g, ax, ay, tx, ty, phase, seed, strength)
    end
    drawPhase4Polish(g, tx, ty, rawPhase, profile, seed, strength)
  end)
end

function M.install()
  local ok, BattleState = pcall(require, "src.battle.BattleState")
  if not (ok and type(BattleState) == "table") then
    return false, "BattleState unavailable"
  end
  if BattleState._stadiumPhase234Effects then return true end
  if type(BattleState.drawAnimLayer) ~= "function" then
    return false, "BattleState.drawAnimLayer unavailable"
  end

  local inner = BattleState.drawAnimLayer
  BattleState.drawAnimLayer = function(self, colorized, ...)
    -- Preserve every return value from the original renderer. Gen1Recomp uses
    -- LuaJIT/Lua 5.1 on some targets, where table.unpack does not exist, so use
    -- the cross-version helper captured above.
    local out = { inner(self, colorized, ...) }

    -- Only add the overlay while a real move animation is active. Ball toss,
    -- POOF/send-out and menu-state rows have no move definition and decline.
    if self and self.animPlaying and self.animName then
      local okDraw, err = pcall(drawEffect, self)
      if not okDraw then
        safeLog("warn", "Phase 2 effect skipped: %s", tostring(err))
      end
    end

    if unpackResults then
      return unpackResults(out)
    end
    -- drawAnimLayer normally has no meaningful return value; on an extremely
    -- unusual runtime without either unpack function, returning nil is safer
    -- than crashing the battle.
    return nil
  end

  BattleState._stadiumPhase234Effects = true
  safeLog("info", "Pokemon Stadium Phase 2 + Phase 3 + Phase 4 battle presentation installed")
  return true
end

return M
