-- In-world Poké Ball capture minigame for visible Gold/Silver wild Pokémon.
--
-- v0.2.12 splits overworld capture into a true AIM then THROW flow BEFORE
-- contact. Hold controller L2 or right mouse to enter an over-the-shoulder aim
-- at a visible roaming Pokemon; aiming alone never spends or launches a Ball.
-- While aim is held, press R2 or left mouse to throw. Releasing aim before a
-- throw simply returns to the overworld. Normal Wilds contact keeps its ordinary
-- battle path. Stronger/higher-level Pokemon resist capture more based on their
-- Gen-2 base stats plus encounter level, layered on top of Gold's real Ball and
-- species catch-rate rules. Unsupported/special encounters stay on Gold's path.
-- The capture overlay is
-- a non-opaque StateStack state:
-- Game2 therefore freezes overworld simulation while GoldComposeBridge keeps
-- drawing the live voxel world underneath it.
local V = ...

local Mat4 = V.require("Mat4")
local Voxel3D = V.require("Voxel3D")
local FirstPerson = V.require("FirstPerson")

local Capture = {
  session = nil,
  installed = false,
  directHookInstalled = false,
  manualHookInstalled = false,
  starts = 0,
  manualStarts = 0,
  throws = 0,
  catches = 0,
  breakouts = 0,
  misses = 0,
  fallbacks = 0,
  lastError = nil,
  lastReason = nil,
  _manualAimDown = false,
}

-- Every Gold Ball that Catching knows how to resolve. The supplied regular
-- Poké Ball model is the visual for all of them for now; the selected item id
-- still reaches Gen-2's real catch-rate rules and is removed from the real bag.
-- Prefer ordinary balls and leave MASTER_BALL last so a player does not burn it
-- just because the regular stack is empty.
local BALL_IDS = {
  "POKE_BALL", "GREAT_BALL", "ULTRA_BALL",
  "FAST_BALL", "LEVEL_BALL", "LURE_BALL", "HEAVY_BALL",
  "LOVE_BALL", "MOON_BALL", "FRIEND_BALL", "PARK_BALL",
  "MASTER_BALL",
}
local BALL_SCALE = 40
local THROW_TIME = 0.68
local IMPACT_HOLD = 0.22
local SHAKE_TIME = 0.54
local SUCCESS_TIME = 0.78
local BREAKOUT_TIME = 0.60
local INTRO_TIME = 0.08
-- v0.2.15: the original 20.5% screen-radius was extremely forgiving.  The
-- base zone is now 14.5%, and strong/high-level Pokemon shrink it further.
local HIT_RADIUS = 0.145 -- fraction of smaller canvas dimension
local MIN_HIT_RADIUS = 0.082
local RING_MIN = 0.22

local mesh, texture

local function log(level, fmt, ...)
  local m = V and V.mod
  local logger = m and m.log
  local fn = logger and logger[level]
  if type(fn) == "function" then
    pcall(fn, logger, "[Overworld Capture] " .. fmt, ...)
  end
end

local function gameOf(logic)
  local m = logic and logic.mod or (V and V.mod)
  if m and type(m.game) == "table" then return m.game end
  if m and m.world and type(m.world.game) == "table" then return m.world.game end
  if V and type(V.game) == "table" then return V.game end
  return nil
end

local function worldOf(logic)
  local game = gameOf(logic)
  if game and type(game.world) == "table" then return game.world end
  local m = logic and logic.mod or (V and V.mod)
  if m and m.world and m.world.overworld then
    local ok, ow = pcall(m.world.overworld, m.world)
    if ok then return ow end
  end
  return nil
end

local function itemCount(game, id)
  local save = game and game.save
  return math.max(0, tonumber(save and save.inventory and save.inventory[id]) or 0)
end

local function chooseBall(game, preferred)
  if preferred and itemCount(game, preferred) > 0 then
    return preferred, itemCount(game, preferred)
  end
  for _, id in ipairs(BALL_IDS) do
    local n = itemCount(game, id)
    if n > 0 then return id, n end
  end
  return nil, 0
end

local function ballCount(game)
  local n = 0
  for _, id in ipairs(BALL_IDS) do n = n + itemCount(game, id) end
  return n
end

local function ballLabel(id)
  if not id then return "BALL" end
  local name = tostring(id):gsub("_", " ")
  name = name:gsub("POKE BALL", "POKé BALL")
  return name
end

local function currentBox(save)
  local n = tonumber(save and save.currentBox) or 1
  if n < 1 then n = 1 elseif n > 14 then n = 14 end
  return n
end

local function voxelEnabled()
  local m = V and V.mod
  if not (m and m.options and type(m.options.get) == "function") then return true end
  local ok, value = pcall(m.options.get, m.options, "voxel3d")
  if not ok or value == nil then return true end
  return not (value == false or value == 0 or value == "0"
    or value == "false" or value == "off")
end

local function storageAvailable(game)
  local save = game and game.save
  if not save then return false end
  local okBoxes, Boxes = pcall(require, "src.core.gen2.Boxes")
  if not okBoxes or type(Boxes) ~= "table" then return false end
  save.party = save.party or {}
  if #save.party < (Boxes.PARTY_SIZE or 6) then return true end
  return not Boxes.isFull(save, currentBox(save))
end

local function targetEntity(logic, record)
  return logic and logic.entities and record and logic.entities[record.id] or nil
end

local function targetWorld(session)
  local e, r = session.entity, session.record
  local x = (e and tonumber(e.px)) and (tonumber(e.px) + 8)
    or ((tonumber(r and r.x) or 0) * 16 + 8)
  local z = (e and tonumber(e.py)) and (tonumber(e.py) + 8)
    or ((tonumber(r and r.y) or 0) * 16 + 8)
  local y = session.targetGround or 0
  return x, y + 8, z
end

local function playerWorld(session)
  local world = session.world
  local p = world and world.player
  local x = (p and tonumber(p.px)) and (tonumber(p.px) + 8)
    or ((tonumber(p and p.cellX) or 0) * 16 + 8)
  local z = (p and tonumber(p.py)) and (tonumber(p.py) + 8)
    or ((tonumber(p and p.cellY) or 0) * 16 + 8)
  local y = session.playerGround or 0
  return x, y + 10, z
end

local function faceTarget(session)
  local px, py, pz = playerWorld(session)
  local tx, ty, tz = targetWorld(session)
  local dx, dz = tx - px, tz - pz
  local flat = math.sqrt(dx * dx + dz * dz)
  if flat < 0.001 then return end
  FirstPerson.yaw = math.atan2(dx, dz)
  local pitch = math.atan2(py - ty, flat)
  FirstPerson.pitch = math.max(FirstPerson.PITCH_UP or -0.75,
    math.min(FirstPerson.PITCH_DOWN or 0.95, pitch))
end

local function fallbackBallMesh()
  -- Use a deterministic UV sphere for the runtime capture prop. The supplied
  -- DAE uses an atlas UV layout that does not survive Voxel3D's single-texture
  -- path consistently on every LOVE backend; this sphere gives the Ball a
  -- stable equirectangular map while preserving the same physical size.
  local verts, indices = {}, {}
  local rings, segs = 12, 24
  local radius = 0.061
  for r = 0, rings do
    local v = r / rings
    local phi = (v - 0.5) * math.pi
    local cp, sp = math.cos(phi), math.sin(phi)
    for c = 0, segs do
      local u = c / segs
      local th = u * math.pi * 2
      -- LOVE image V=0 is the top of the texture. r=0 is the sphere's
      -- SOUTH/bottom pole, so invert V or the red/white hemispheres swap.
      local texV = 1 - v
      verts[#verts + 1] = {
        radius * cp * math.sin(th), radius * sp, radius * cp * math.cos(th),
        u, texV, 1,
      }
    end
  end
  local stride = segs + 1
  for r = 0, rings - 1 do
    for c = 0, segs - 1 do
      local a = r * stride + c + 1
      local b = a + stride
      indices[#indices + 1] = a
      indices[#indices + 1] = b
      indices[#indices + 1] = a + 1
      indices[#indices + 1] = a + 1
      indices[#indices + 1] = b
      indices[#indices + 1] = b + 1
    end
  end
  return Voxel3D.newMesh(verts, indices)
end

local function loadBall()
  if mesh and texture then return mesh, texture end
  if not (love and love.graphics) then return nil end

  if not mesh then
    -- Always use the corrected UV sphere. Keep the supplied DAE/FBX in the
    -- package as source/reference assets, but do not let their atlas mapping
    -- produce a scrambled in-game Ball.
    mesh = fallbackBallMesh()
  end

  local rel = "assets/capture/pokeball_runtime.png"
  local path = rel
  local m = V and V.mod
  if m and m.assets and type(m.assets.path) == "function" then
    local ok, pth = pcall(m.assets.path, m.assets, rel)
    if ok and type(pth) == "string" then path = pth end
  end
  local okAssets, Assets = pcall(require, "src.render.Assets")
  if okAssets and Assets and type(Assets.image) == "function" then
    local ok, img = pcall(Assets.image, path)
    if ok then texture = img end
  end
  if not texture then
    local ok, img = pcall(love.graphics.newImage, path)
    if ok then texture = img end
  end
  if texture then
    pcall(texture.setFilter, texture, "linear", "linear")
    pcall(texture.setWrap, texture, "repeat", "repeat")
  end
  return mesh, texture
end

local function resetHidden(session)
  if session and session.entity then
    session.entity._stadiumCaptureHidden = nil
  end
end

local function popState(session)
  local game = session and session.game
  local stack = game and game.stack
  if not (stack and type(stack.top) == "function" and type(stack.pop) == "function") then
    return
  end
  local ok, top = pcall(stack.top, stack)
  if ok and top == session.state then pcall(stack.pop, stack) end
end

local function finishSession(session)
  if Capture.session ~= session then return end
  resetHidden(session)
  popState(session)
  Capture.session = nil
end

local function fallbackBattle(session)
  if not session or Capture.session ~= session then return false end
  resetHidden(session)
  popState(session)
  Capture.session = nil
  Capture.fallbacks = Capture.fallbacks + 1
  local fn, logic, record = session.originalStart, session.logic, session.record
  if type(fn) ~= "function" then return false end
  local ok, result = pcall(fn, logic, record)
  if not ok then
    Capture.lastError = tostring(result)
    log("warn", "normal battle fallback failed: %s", tostring(result))
    return false
  end
  return result and true or false
end

local function addCaught(session, mon)
  local game, save = session.game, session.game and session.game.save
  if not (game and save and mon) then return false, "save unavailable" end
  local okBoxes, Boxes = pcall(require, "src.core.gen2.Boxes")
  local okMon, Mon = pcall(require, "src.battle.gen2.Mon")
  if not (okBoxes and Boxes and okMon and Mon) then return false, "Gold storage unavailable" end

  Mon.stampOT(save, mon)
  save.pokedex = save.pokedex or { seen = {}, caught = {} }
  save.pokedex.seen = save.pokedex.seen or {}
  save.pokedex.caught = save.pokedex.caught or {}
  save.pokedex.seen[mon.species] = true
  save.pokedex.caught[mon.species] = true
  save.party = save.party or {}

  local sentToBox = false
  if #save.party < (Boxes.PARTY_SIZE or 6) then
    save.party[#save.party + 1] = mon
  else
    local boxIndex = currentBox(save)
    if Boxes.isFull(save, boxIndex) then return false, "BOX is full" end
    table.insert(Boxes.box(save, boxIndex), 1, mon)
    sentToBox = true
  end
  return true, sentToBox
end

local QUALITY = {
  excellent = { boost = 3.0, hp = 0.18, label = "EXCELLENT!" },
  great     = { boost = 2.1, hp = 0.34, label = "GREAT!" },
  nice      = { boost = 1.5, hp = 0.55, label = "NICE!" },
  hit       = { boost = 1.0, hp = 0.76, label = "HIT!" },
}

-- Additional overworld-capture resistance. Gold's species catchRate and Ball
-- logic remain authoritative inside Catching.attempt(); this factor represents
-- how much raw strength the roaming Pokemon can put behind breaking the Ball.
-- It uses the actual Gen-2 six-stat base block plus encounter level so a low-
-- level weak species is forgiving while a high-level legendary is stubborn.
local function strengthResistance(def, level)
  local b = def and def.baseStats or {}
  local bst = (tonumber(b.hp) or 1) + (tonumber(b.attack) or 1)
    + (tonumber(b.defense) or 1) + (tonumber(b.speed) or 1)
    + (tonumber(b.specialAttack) or 1) + (tonumber(b.specialDefense) or 1)
  local bstNorm = math.max(0, math.min(1, (bst - 180) / 500))
  local levelNorm = math.max(0, math.min(1, ((tonumber(level) or 1) - 1) / 99))
  local strength = bstNorm * 0.72 + levelNorm * 0.28
  -- Weak targets may be slightly easier than stock; the strongest are reduced
  -- to 38% of their post-quality catch rate before Gold applies Ball rules.
  local factor = 1.12 - strength * 0.74
  factor = math.max(0.38, math.min(1.12, factor))
  local tier
  if strength < 0.20 then tier = "LOW"
  elseif strength < 0.42 then tier = "NORMAL"
  elseif strength < 0.62 then tier = "HIGH"
  elseif strength < 0.80 then tier = "VERY HIGH"
  else tier = "EXTREME" end
  return factor, tier, strength, bst
end

local function throwQuality(session)
  local sw, sh = session.screenW or 1, session.screenH or 1
  local tx, ty = session.targetSX, session.targetSY
  if not (tx and ty and sw > 0 and sh > 0) then return nil, 1 end
  local cx, cy = sw / 2, sh / 2
  local dim = math.max(1, math.min(sw, sh))
  local dx, dy = (tx - cx) / dim, (ty - cy) / dim
  local err = math.sqrt(dx * dx + dy * dy)

  -- Stronger Pokemon are physically less forgiving to tag with a clean throw,
  -- not merely less likely to stay caught after impact.  The same strength
  -- score used by the catch-resistance layer therefore shrinks the aim zone.
  local strength = tonumber(session.strengthScore) or 0
  local hitRadius = math.max(MIN_HIT_RADIUS, HIT_RADIUS * (1 - strength * 0.42))
  session.hitRadius = hitRadius
  session.aimDX, session.aimDY = dx, dy
  if err > hitRadius then return nil, err, 0 end

  local aim = math.max(0, 1 - err / hitRadius)
  local ring = session.ringScale or 1
  -- ring ranges RING_MIN..1.0; the smallest ring is the hardest timing window.
  local timing = math.max(0, math.min(1, (1.0 - ring) / (1.0 - RING_MIN)))
  local score = aim * 0.78 + timing * 0.22
  if score >= 0.91 then return "excellent", err, score end
  if score >= 0.75 then return "great", err, score end
  if score >= 0.55 then return "nice", err, score end
  return "hit", err, score
end

local function cosmeticShakes(caught, rate, score)
  if caught then return 3 end
  local chance = math.max(0.18, math.min(0.80,
    0.20 + (tonumber(rate) or 0) / 480 + (tonumber(score) or 0) * 0.30))
  local n = 0
  for _ = 1, 2 do
    local r
    if love and love.math and love.math.random then r = love.math.random()
    else r = math.random() end
    if r <= chance then n = n + 1 else break end
  end
  return n
end

local function attemptCatch(session)
  local game, record = session.game, session.record
  local data = game and game.data
  local species = record and record.species
  local level = tonumber(record and record.level) or 5
  local def = data and data.pokemon and data.pokemon[species]
  local okMon, Mon = pcall(require, "src.battle.gen2.Mon")
  local okCatch, Catching = pcall(require, "src.battle.gen2.Catching")
  if not (def and okMon and Mon and okCatch and Catching) then
    return false, 0, nil, "Gold catch data unavailable"
  end
  local mon = Mon.new(data, species, level)
  if not mon then return false, 0, nil, "could not build wild Pokémon" end
  local q = QUALITY[session.quality or "hit"] or QUALITY.hit
  local maxHp = math.max(1, tonumber(mon.maxHp) or 1)
  local hp = math.max(1, math.floor(maxHp * q.hp))
  local resistance, tier, strength, bst = strengthResistance(def, level)
  session.resistanceFactor = resistance
  session.resistanceTier = tier
  session.strengthScore = strength
  session.baseStatTotal = bst
  local catchRate = math.min(255, math.max(1,
    math.floor((tonumber(def.catchRate) or 45) * q.boost * resistance)))
  local caught, rate = Catching.attempt({
    maxHp = maxHp, hp = hp, catchRate = catchRate,
    ball = session.ballId or "POKE_BALL", status = nil, species = species,
    mon = mon, def = def, data = data,
  })
  return caught and true or false, rate or 0, mon
end

local function rawGamepadState(button, axis)
  local J = love and love.joystick
  if not (J and type(J.getJoysticks) == "function") then return false end
  local ok, sticks = pcall(J.getJoysticks)
  if not ok or type(sticks) ~= "table" then return false end
  for _, js in ipairs(sticks) do
    local mapped = js and js.isGamepad and js:isGamepad()
    if mapped then
      if button and js.isGamepadDown then
        local okDown, down = pcall(js.isGamepadDown, js, button)
        if okDown and down then return true end
      end
      if axis and js.getGamepadAxis then
        local okAxis, value = pcall(js.getGamepadAxis, js, axis)
        -- Standard mapped triggers rest at 0 and rise toward 1. A few drivers
        -- expose a tiny negative idle value, so only the positive half counts.
        if okAxis and (tonumber(value) or 0) > 0.55 then return true end
      end
    end
  end
  return false
end

local function rawMouseDown(button)
  local M = love and love.mouse
  if not (M and type(M.isDown) == "function") then return false end
  local ok, down = pcall(M.isDown, button)
  return ok and down and true or false
end

local function triggerPressed(session)
  -- v0.2.12: THROW is deliberately separate from AIM. Controller R2 and
  -- left mouse are the only throw verbs here; holding L2/right mouse cannot
  -- reach this function as a throw, so aim can never consume a Ball by itself.
  local leftMouse = rawMouseDown(1)
  local leftMouseEdge = leftMouse and not session.mouseLeftDown
  session.mouseLeftDown = leftMouse

  local triggerDown = rawGamepadState(nil, "triggerright")
  local triggerEdge = triggerDown and not session.triggerDown
  session.triggerDown = triggerDown
  return leftMouseEdge or triggerEdge
end

local function aimHeld(session)
  local controller = rawGamepadState(nil, "triggerleft")
  local mouse = rawMouseDown(2)
  if session then
    session.aimControllerDown = controller
    session.mouseRightDown = mouse
  end
  return controller or mouse
end

local function battlePressed(session)
  -- Right mouse belongs to AIM. B remains the explicit normal-battle escape.
  local input = session.game and session.game.input
  return input and type(input.wasPressed) == "function" and input:wasPressed("b")
end

local function refreshBall(session)
  local id = session.ballId
  if id and itemCount(session.game, id) > 0 then return id end
  id = chooseBall(session.game)
  session.ballId = id
  return id
end

local function consumeBall(session)
  local save = session.game and session.game.save
  local id = refreshBall(session)
  if not (save and id and itemCount(session.game, id) > 0) then return false end
  local okBag, Bag = pcall(require, "src.inventory.Bag")
  if not okBag or not Bag or type(Bag.remove) ~= "function" then return false end
  Bag.remove(save, id, 1)
  return true
end

local function startThrow(session)
  -- Do not spend a ball until the renderer has projected the target at least
  -- once. This protects the first fixed tick after entering the transparent
  -- capture state, before its first voxel frame exists.
  if not (session.targetSX and session.targetSY) then return false end
  if not consumeBall(session) then return false end
  local quality, err, score = throwQuality(session)
  session.quality = quality
  session.aimError = err
  session.score = score or 0

  -- The ball now flies where the crosshair actually was.  A miss no longer
  -- visually homes into the Pokemon and only declares MISS afterward.  Screen
  -- horizontal error becomes a world-space lateral miss; vertical error changes
  -- impact height.  The deterministic mapping keeps replays/debugging stable.
  local sx, sy, sz = playerWorld(session)
  local tx, ty, tz = targetWorld(session)
  local vx, vz = tx - sx, tz - sz
  local len = math.sqrt(vx * vx + vz * vz)
  if len < 1e-4 then len = 1 end
  local px, pz = -vz / len, vx / len
  local radius = math.max(MIN_HIT_RADIUS, tonumber(session.hitRadius) or HIT_RADIUS)
  local nx = math.max(-2.2, math.min(2.2, (tonumber(session.aimDX) or 0) / radius))
  local ny = math.max(-2.2, math.min(2.2, (tonumber(session.aimDY) or 0) / radius))
  local missScale = quality and 2.0 or 13.0
  session.throwEndX = tx - px * nx * missScale
  session.throwEndZ = tz - pz * nx * missScale
  session.throwEndY = ty + ny * missScale * 0.72
  if quality then
    -- Successful contact still converges on the Pokemon, with only a tiny
    -- visible placement offset proportional to imperfect aim.
    session.throwEndX = tx - px * nx * 1.8
    session.throwEndZ = tz - pz * nx * 1.8
    session.throwEndY = ty + ny * 1.0
  end

  session.phase = "throw"
  session.timer = 0
  session.throwSpin = 0
  session.caught = false
  session.rate = 0
  session.mon = nil
  session.shakes = 0
  session.shakeDone = 0
  session.resultLabel = quality and QUALITY[quality].label or "MISS!"
  Capture.throws = Capture.throws + 1
  return true
end

local function resolveImpact(session)
  if not session.quality then
    session.phase = "miss"
    session.timer = 0
    Capture.misses = Capture.misses + 1
    return
  end
  session.entity._stadiumCaptureHidden = true
  local caught, rate, mon, err = attemptCatch(session)
  if err then
    Capture.lastError = tostring(err)
    log("warn", "%s", tostring(err))
  end
  session.caught, session.rate, session.mon = caught, rate, mon
  session.shakes = cosmeticShakes(caught, rate, session.score)
  session.shakeDone = 0
  session.phase = "impact"
  session.timer = 0
end

local function completeCatch(session)
  local ok, sent = addCaught(session, session.mon)
  if not ok then
    -- Storage changed under us; preserve the Pokémon by dropping back into the
    -- ordinary battle rather than silently deleting the encounter.
    resetHidden(session)
    return fallbackBattle(session)
  end
  local logic, record = session.logic, session.record
  if logic and record and type(logic._despawn) == "function" then
    pcall(logic._despawn, logic, record.id, true)
    if type(logic._recountRegions) == "function" then pcall(logic._recountRegions, logic) end
  end
  Capture.catches = Capture.catches + 1
  local name = (session.mon and (session.mon.nickname or session.mon.name))
    or tostring(record and record.species or "POKéMON")
  local game = session.game
  finishSession(session)
  if game and type(game.say) == "function" then
    local text = "Gotcha! " .. tostring(name) .. " was caught!"
    if sent then text = text .. "\fSent to your current BOX." end
    pcall(game.say, game, text)
  end
  return true
end

local nearestCandidate

local function fixedUpdate(session, dt)
  if Capture.session ~= session then return end
  dt = tonumber(dt) or 1 / 60
  session.total = session.total + dt
  session.timer = session.timer + dt
  -- Fail closed if the minigame somehow outlives its target/session.
  if session.total > 30 then fallbackBattle(session) return end

  if battlePressed(session) and (session.phase == "intro" or session.phase == "aim"
      or session.phase == "miss" or session.phase == "breakout") then
    fallbackBattle(session)
    return
  end

  if session.phase == "intro" then
    -- AIM is a hold action. Releasing L2/right mouse before throwing cancels
    -- cleanly back to the overworld and never spends a Ball.
    if not aimHeld(session) then finishSession(session) return end
    if session.timer >= INTRO_TIME then
      session.phase, session.timer = "aim", 0
    end
    return
  end

  if session.phase == "aim" then
    if not aimHeld(session) then finishSession(session) return end
    -- Keep the selected target synced to the current camera cone while aiming.
    -- This lets the player pan across multiple roaming Pokemon before R2/click.
    local candidate = nearestCandidate and nearestCandidate(session.logic, 104) or nil
    if candidate then
      local entity = targetEntity(session.logic, candidate)
      if entity then
        session.record, session.entity = candidate, entity
      end
    end
    local strength = tonumber(session.strengthScore) or 0
    -- Strong targets cycle the precision ring faster as well as shrinking the
    -- valid hit radius, so legendaries demand both steadier aim and timing.
    local wave = 0.5 + 0.5 * math.cos(session.total * (5.0 + strength * 2.2))
    session.ringScale = RING_MIN + (1.0 - RING_MIN) * wave
    if triggerPressed(session) then startThrow(session) end
    return
  end

  if session.phase == "throw" then
    session.throwSpin = session.throwSpin + dt * 17
    if session.timer >= THROW_TIME then resolveImpact(session) end
    return
  end

  if session.phase == "miss" then
    if session.timer >= BREAKOUT_TIME then
      if ballCount(session.game) <= 0 then fallbackBattle(session) return end
      refreshBall(session)
      session.phase, session.timer = "aim", 0
    end
    return
  end

  if session.phase == "impact" then
    if session.timer >= IMPACT_HOLD then
      session.phase, session.timer = "shake", 0
      if session.shakes == 0 and not session.caught then
        session.phase = "breakout"
      end
    end
    return
  end

  if session.phase == "shake" then
    if session.timer >= SHAKE_TIME then
      session.timer = session.timer - SHAKE_TIME
      session.shakeDone = session.shakeDone + 1
      if session.shakeDone >= session.shakes then
        if session.caught then
          session.phase, session.timer = "success", 0
        else
          session.phase, session.timer = "breakout", 0
          Capture.breakouts = Capture.breakouts + 1
        end
      end
    end
    return
  end

  if session.phase == "breakout" then
    if session.timer >= BREAKOUT_TIME then
      resetHidden(session)
      if ballCount(session.game) <= 0 then fallbackBattle(session) return end
      refreshBall(session)
      session.phase, session.timer = "aim", 0
    end
    return
  end

  if session.phase == "success" and session.timer >= SUCCESS_TIME then
    completeCatch(session)
  end
end

local function captureState(session)
  return {
    isOpaque = false,
    _stadiumCaptureOverlay = true,
    update = function(_, dt) fixedUpdate(session, dt) end,
    draw = function() end,
  }
end

function Capture.active()
  return Capture.session ~= nil
end

function Capture.cameraOverride()
  local s = Capture.session
  if not s then return nil end
  -- Aim is always the proven shoulder-offset third-person rig, independent of
  -- the player's normal DIORAMA / 1ST / 3RD camera. The saved mode is untouched.
  return "third"
end

function Capture.afterCameraUpdate()
  local session = Capture.session
  if not session or session.cameraFaced then return false end
  -- Existing 1ST/3RD users keep the direction they were already looking.
  -- DIORAMA has no free-look yaw, so entering L2/right-mouse shoulder aim starts
  -- by facing the selected Pokemon; mouse/right-stick can then refine the shot.
  -- Keep the non-manual arm as a defensive fallback for external callers.
  if not session.manual or session.userCamera == "diorama" then faceTarget(session) end
  session.cameraFaced = true
  return not session.manual
end

function Capture.hideEntity(e)
  return e and e._stadiumCaptureHidden == true
end

local function freeAimCameraActive()
  local ok, Voxel = pcall(V.require, "VoxelState")
  if not ok or type(Voxel) ~= "table" then return false end
  return Voxel.level == Voxel.TP_LEVEL or Voxel.level == Voxel.FP_LEVEL
end

nearestCandidate = function(logic, maxWorldDistance)
  local world = worldOf(logic)
  local p = world and world.player
  if not (p and logic and type(logic.spawns) == "table") then return nil end
  local px = (tonumber(p.px) and tonumber(p.px) + 8)
    or ((tonumber(p.cellX) or 0) * 16 + 8)
  local pz = (tonumber(p.py) and tonumber(p.py) + 8)
    or ((tonumber(p.cellY) or 0) * 16 + 8)
  local yaw = tonumber(FirstPerson.yaw) or 0
  local fx, fz = math.sin(yaw), math.cos(yaw)
  local best, bestScore, nearest, nearestD2
  local limit = tonumber(maxWorldDistance) or 88
  local limit2 = limit * limit
  for _, r in pairs(logic.spawns) do
    if r and (r.state == nil or r.state == "available" or r.state == "AVAILABLE") then
      local e = targetEntity(logic, r)
      if e and e.wildsAmbientPokemon ~= true and e.visibleSprite ~= false
         and e.hiddenEncounter ~= true and e.caveScenery ~= true then
        local x = tonumber(e.px) and (tonumber(e.px) + 8)
          or ((tonumber(r.x) or 0) * 16 + 8)
        local z = tonumber(e.py) and (tonumber(e.py) + 8)
          or ((tonumber(r.y) or 0) * 16 + 8)
        local dx, dz = x - px, z - pz
        local d2 = dx * dx + dz * dz
        if d2 <= limit2 then
          if not nearestD2 or d2 < nearestD2 then
            nearest, nearestD2 = r, d2
          end
          local dist = math.sqrt(math.max(d2, 1e-6))
          local dot = (dx * fx + dz * fz) / dist
          -- Prefer what the camera is actually pointing toward. Distance is a
          -- light tie-breaker so two Pokemon in the same sightline pick front.
          if dot >= 0.40 then
            local score = dot * 4 - dist / limit
            if not bestScore or score > bestScore then
              best, bestScore = r, score
            end
          end
        end
      end
    end
  end
  -- 1ST/3RD have a true camera-facing aim direction: require the target to be
  -- inside the cone. DIORAMA has no equivalent free-look yaw, so use the
  -- nearest visible candidate and temporarily face it in the capture camera.
  if freeAimCameraActive() then return best end
  return best or nearest
end

local function manualAimHeld()
  local held = rawGamepadState(nil, "triggerleft") or rawMouseDown(2)
  Capture._manualAimDown = held
  return held
end

function Capture.pollManual(logic)
  if Capture.session or not Capture.installed then return false end
  -- L2 / right mouse is HOLD TO AIM, not a throw edge. While held, keep looking
  -- for a valid visible target; this makes entering aim reliable while standing.
  if not manualAimHeld() then return false end
  local record = nearestCandidate(logic, 104)
  if not record then
    Capture.lastReason = "no visible wild Pokémon within capture range"
    return false
  end
  local native = logic and (logic._startBattleNative or logic._stadiumCaptureNative)
  local ok, handled = pcall(Capture.begin, logic, record, native, true)
  if not ok then
    Capture.lastError = tostring(handled)
    return false
  end
  if handled and Capture.session then
    Capture.manualStarts = Capture.manualStarts + 1
    -- Preserve the live hold states. No autoThrow flag exists in v0.2.12:
    -- only a later R2/left-click edge can call startThrow().
    Capture.session.aimControllerDown = rawGamepadState(nil, "triggerleft")
    Capture.session.mouseRightDown = rawMouseDown(2)
  end
  return handled and true or false
end

function Capture.begin(logic, record, originalStart, manual)
  if Capture.session or not (logic and record) then return false end
  local game = gameOf(logic)
  local world = worldOf(logic)
  local entity = targetEntity(logic, record)
  if not (game and world and entity) then
    Capture.lastReason = "Gold world or visible wild entity unavailable"
    return false
  end
  if record.state ~= nil and record.state ~= "available"
      and record.state ~= "AVAILABLE" then return false end
  if logic.pendingBattle then return false end
  if entity.wildsAmbientPokemon == true or entity.wildsBattleable == false
      or entity.wildsEncounterEnabled == false
      or (entity.hiddenEncounter == true and entity.visibleSprite == false) then
    return false
  end
  -- Safari owns its own ball/session rules; never bypass that path, whether a
  -- Safari session is currently active or the player is merely on a Safari map.
  local okSafariMod, SafariCompat = pcall(V.require, "safari_compat")
  if okSafariMod and SafariCompat and type(SafariCompat.isSafariMap) == "function" then
    local okSafariMap, isSafari = pcall(SafariCompat.isSafariMap, game,
      record.mapId or (world.map and world.map.id), world)
    if okSafariMap and isSafari then return false end
  elseif logic._safariActive then
    local ok, safari = pcall(logic._safariActive, logic, game, world,
      record.mapId or (world.map and world.map.id))
    if ok and safari then return false end
  end
  if not voxelEnabled() then
    Capture.lastReason = "3D overworld is disabled"
    return false
  end
  local ballId = chooseBall(game)
  if not ballId then
    Capture.lastReason = "no supported Ball in the Gold bag"
    return false
  end
  if not storageAvailable(game) then
    Capture.lastReason = "party and current BOX are full"
    return false
  end
  local okAvail, available = pcall(Voxel3D.available)
  if not okAvail or not available then
    Capture.lastReason = "3D renderer unavailable"
    return false
  end
  -- Do not block the gameplay mechanic on a GPU asset upload. drawWorld() will
  -- retry and has a generated sphere fallback for the supplied ball texture.
  pcall(loadBall)
  local stack = game.stack
  if not (stack and type(stack.push) == "function" and type(stack.top) == "function") then
    return false
  end
  local okTop, top = pcall(stack.top, stack)
  if not okTop or top ~= nil then return false end

  local mode = "diorama"
  -- Prefer the renderer's live rung so AUTO / Character Selector ownership is
  -- respected. Fall back to this mod's saved option before the first 3D frame.
  local okVoxel, Voxel = pcall(V.require, "VoxelState")
  if okVoxel and Voxel then
    if Voxel.level == Voxel.TP_LEVEL then mode = "third"
    elseif Voxel.level == Voxel.FP_LEVEL then mode = "first" end
  end
  if mode == "diorama" then
    local m = V and V.mod
    if m and m.options and type(m.options.get) == "function" then
      local ok, v = pcall(m.options.get, m.options, "cameraMode")
      if ok and (v == "third" or v == "first" or v == "diorama") then mode = v end
    end
  end
  local captureDef = game and game.data and game.data.pokemon
    and game.data.pokemon[record.species]
  local resistanceFactor, resistanceTier, strengthScore, baseStatTotal =
    strengthResistance(captureDef, record.level)

  local session = {
    logic = logic, record = record, entity = entity, originalStart = originalStart,
    game = game, world = world, phase = "intro", timer = 0, total = 0,
    ringScale = 1, triggerDown = rawGamepadState(nil, "triggerright"),
    aimControllerDown = rawGamepadState(nil, "triggerleft"),
    mouseLeftDown = rawMouseDown(1), mouseRightDown = rawMouseDown(2),
    userCamera = mode, ballId = ballId, manual = manual and true or false,
    targetSX = nil, targetSY = nil, screenW = nil, screenH = nil,
    cameraFaced = false,
    resistanceFactor = resistanceFactor, resistanceTier = resistanceTier,
    strengthScore = strengthScore, baseStatTotal = baseStatTotal,
    hitRadius = math.max(MIN_HIT_RADIUS, HIT_RADIUS * (1 - strengthScore * 0.42)),
  }
  session.state = captureState(session)
  Capture.session = session
  local okPush, pushErr = pcall(stack.push, stack, session.state)
  if not okPush then
    Capture.session = nil
    Capture.lastError = tostring(pushErr)
    return false
  end
  Capture.starts = Capture.starts + 1
  Capture.lastReason = nil
  log("info", "capture minigame: %s Lv%s (%s x%d; %d supported Ball%s total%s)",
    tostring(record.species), tostring(record.level), ballLabel(ballId),
    itemCount(game, ballId), ballCount(game), ballCount(game) == 1 and "" or "s",
    manual and "; hold-to-aim" or "; contact")
  return true
end

function Capture.install(logic)
  if Capture.installed then return true end
  if type(logic) ~= "table" or type(logic._startBattle) ~= "function" then
    return false, "visible Wilds battle seam unavailable"
  end

  -- v0.2.12 does NOT intercept touch/contact. Touching a roaming Pokemon starts
  -- the normal Gold battle. Capture is pre-contact: hold L2/right mouse to aim,
  -- then R2/left mouse throws while the shoulder-aim state is active.
  logic._stadiumCaptureHandler = nil
  Capture.directHookInstalled = false
  Capture.installed = true

  local m = logic.mod or (V and V.mod)
  -- Poll on input.step, not world.stepped. Gold raises input.step every fixed
  -- logic tick immediately before Input:step consumes the device queue, while
  -- world.stepped only fires after the player actually lands on another cell.
  -- A stationary player must be able to hold L2/right mouse and enter shoulder
  -- aim without taking a step first; R2/left mouse is read inside that state.
  if m and m.hooks and type(m.hooks.wrap) == "function" then
    local ok = pcall(m.hooks.wrap, m.hooks, "input.step", function(next, G, dt)
      local okPoll, err = pcall(Capture.pollManual, logic)
      if not okPoll then Capture.lastError = tostring(err) end
      return next(G, dt)
    end)
    Capture.manualHookInstalled = ok and true or false
  end

  if not Capture.manualHookInstalled then
    Capture.installed = false
    return false, "input.step capture hook unavailable"
  end

  return true
end

function Capture.drawWorld(state)
  local session = Capture.session
  if not session then return false end
  local ballMesh, ballTex = loadBall()
  if not (ballMesh and ballTex) then return false end
  local VoxelScene = V.require("VoxelScene")
  local record = session.record
  session.targetGround = VoxelScene.groundAt(state.map,
    tonumber(record.x) or 0, tonumber(record.y) or 0)
  local p = state.player
  session.playerGround = VoxelScene.groundAt(state.map,
    tonumber(p and p.cellX) or 0, tonumber(p and p.cellY) or 0)

  local phase = session.phase
  if phase == "intro" or phase == "aim" then return true end

  local sx, sy, sz = playerWorld(session)
  local tx, ty, tz = targetWorld(session)
  local x, y, z, spin = sx, sy, sz, session.throwSpin or 0
  if phase == "throw" then
    local t = math.max(0, math.min(1, session.timer / THROW_TIME))
    local smooth = t * t * (3 - 2 * t)
    local ex = tonumber(session.throwEndX) or tx
    local ey = tonumber(session.throwEndY) or ty
    local ez = tonumber(session.throwEndZ) or tz
    x = sx + (ex - sx) * smooth
    z = sz + (ez - sz) * smooth
    y = sy + (ey - sy) * smooth + math.sin(math.pi * t) * 17
  elseif phase == "miss" then
    local t = math.max(0, math.min(1, session.timer / BREAKOUT_TIME))
    -- Continue from the ACTUAL missed impact point and fall away.
    local ex = tonumber(session.throwEndX) or tx
    local ey = tonumber(session.throwEndY) or ty
    local ez = tonumber(session.throwEndZ) or tz
    x = ex + (ex - sx) * 0.55 * t
    z = ez + (ez - sz) * 0.55 * t
    y = ey + 8 * (1 - t) - 14 * t * t
    spin = spin + t * 12
  else
    x, z = tx, tz
    y = session.targetGround + 2.5
    if phase == "shake" then
      local u = math.min(1, session.timer / SHAKE_TIME)
      local dir = ((session.shakeDone or 0) % 2 == 0) and 1 or -1
      spin = dir * math.sin(u * math.pi) * 0.45
    elseif phase == "success" then
      y = y + math.sin(session.timer * 12) * 0.8
    end
  end

  local model = Mat4.translate(x, y, z)
  model = Mat4.mul(model, Mat4.rotateY(spin))
  model = Mat4.mul(model, Mat4.rotateX((session.throwSpin or 0) * 0.65))
  model = Mat4.mul(model, Mat4.scale(BALL_SCALE, BALL_SCALE, BALL_SCALE))
  Voxel3D.draw(ballMesh, ballTex, model, 1.2)
  session.ballX, session.ballY, session.ballZ = x, y, z
  return true
end

local function printCentered(G, text, y, scale)
  scale = scale or 1
  local font = G.getFont and G.getFont() or nil
  local tw = font and font:getWidth(text) or (#text * 6)
  G.print(text, math.floor((G.getWidth() - tw * scale) / 2), y, 0, scale, scale)
end

function Capture.drawOverlay(w, h)
  local session = Capture.session
  if not session then return false end
  local G = love and love.graphics
  if not G then return false end
  w, h = tonumber(w) or G.getWidth(), tonumber(h) or G.getHeight()
  session.screenW, session.screenH = w, h
  local tx, ty, tz = targetWorld(session)
  local px, py = Voxel3D.project(tx, ty, tz)
  session.targetSX, session.targetSY = px, py

  G.push("all")
  G.origin()
  G.setShader()
  G.setDepthMode()
  G.setBlendMode("alpha")

  local cx, cy = w / 2, h / 2
  -- Crosshair remains screen-centred while mouse/right-stick steer the camera.
  G.setLineWidth(math.max(1, math.floor(math.min(w, h) / 420)))
  G.setColor(1, 1, 1, 0.92)
  local arm = math.max(8, math.min(w, h) * 0.014)
  local gap = arm * 0.45
  G.line(cx - arm, cy, cx - gap, cy)
  G.line(cx + gap, cy, cx + arm, cy)
  G.line(cx, cy - arm, cx, cy - gap)
  G.line(cx, cy + gap, cx, cy + arm)
  G.circle("line", cx, cy, gap * 0.62)

  if px and py and (session.phase == "intro" or session.phase == "aim") then
    local difficultyScale = math.max(0.56, math.min(1.0,
      (tonumber(session.hitRadius) or HIT_RADIUS) / HIT_RADIUS))
    local base = math.max(18, math.min(w, h) * 0.058 * difficultyScale)
    local ring = base * (session.ringScale or 1)
    G.setColor(1, 1, 1, 0.34)
    G.circle("line", px, py, base)
    G.setColor(1, 1, 1, 0.94)
    G.circle("line", px, py, ring)
  end

  -- Compact dark HUD card; no dependency on Gold's 160x144 font path.
  local bw = math.min(w * 0.72, 560)
  local bh = math.max(54, math.min(h * 0.11, 86))
  local bx, by = (w - bw) / 2, h - bh - math.max(18, h * 0.035)
  G.setColor(0, 0, 0, 0.62)
  G.rectangle("fill", bx, by, bw, bh, 10, 10)
  G.setColor(1, 1, 1, 0.94)
  local species = tostring(session.record.species or "POKéMON")
  local activeBall = refreshBall(session) or session.ballId
  local resistance = session.resistanceTier
  if not resistance then
    local data = session.game and session.game.data
    local def = data and data.pokemon and data.pokemon[session.record.species]
    local _, tier = strengthResistance(def, session.record.level)
    resistance = tier
  end
  local line = species .. "  Lv" .. tostring(session.record.level or "?")
    .. "     " .. ballLabel(activeBall) .. " ×"
    .. tostring(activeBall and itemCount(session.game, activeBall) or 0)
    .. "     RESIST " .. tostring(resistance or "NORMAL")
  local font = G.getFont and G.getFont() or nil
  local tw = font and font:getWidth(line) or #line * 6
  G.print(line, bx + (bw - tw) / 2, by + 10)

  local prompt
  if session.phase == "intro" then prompt = "GET READY"
  elseif session.phase == "aim" then prompt = "HOLD L2 + R2: THROW     HOLD RIGHT + LEFT CLICK: THROW"
  elseif session.phase == "throw" then prompt = session.resultLabel or "THROW!"
  elseif session.phase == "miss" then prompt = "MISS!"
  elseif session.phase == "impact" or session.phase == "shake" then
    prompt = "..." .. string.rep("  •", session.shakeDone or 0)
  elseif session.phase == "breakout" then prompt = "BROKE FREE!"
  elseif session.phase == "success" then prompt = "GOTCHA!"
  else prompt = "CAPTURE" end
  local pw = font and font:getWidth(prompt) or #prompt * 6
  G.setColor(1, 1, 1, 1)
  G.print(prompt, bx + (bw - pw) / 2, by + bh - 25)

  if session.phase == "success" and session.ballX then
    local sx2, sy2 = Voxel3D.project(session.ballX, session.ballY + 2, session.ballZ)
    if sx2 and sy2 then
      local r = 12 + session.timer * 30
      G.setColor(1, 1, 1, math.max(0, 1 - session.timer / SUCCESS_TIME))
      G.circle("line", sx2, sy2, r)
      G.circle("line", sx2, sy2, r * 1.55)
    end
  end
  G.pop()
  return true
end

function Capture.status()
  local s = Capture.session
  return {
    installed = Capture.installed,
    directHookInstalled = Capture.directHookInstalled,
    manualHookInstalled = Capture.manualHookInstalled,
    active = s ~= nil,
    phase = s and s.phase or nil,
    species = s and s.record and s.record.species or nil,
    ball = s and s.ballId or nil,
    balls = s and ballCount(s.game) or nil,
    resistance = s and s.resistanceTier or nil,
    strengthScore = s and s.strengthScore or nil,
    baseStatTotal = s and s.baseStatTotal or nil,
    starts = Capture.starts, manualStarts = Capture.manualStarts,
    throws = Capture.throws, catches = Capture.catches,
    breakouts = Capture.breakouts, misses = Capture.misses,
    fallbacks = Capture.fallbacks, lastReason = Capture.lastReason,
    lastError = Capture.lastError,
  }
end

return Capture
