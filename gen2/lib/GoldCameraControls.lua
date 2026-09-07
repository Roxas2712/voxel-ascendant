-- Gold/Game2 true camera-relative free movement for voxel first/third person.
--
-- Continuous 360-degree movement belongs to both 1ST and 3RD PERSON. Their
-- character renderer consumes the continuous displacement signal below, so
-- third-person travel animates without falling back to cardinal grid steps.
-- DIORAMA stays on Gold's ordinary grid movement. Camera-space intent
-- is rotated by the live free-camera yaw, preserving analog magnitude and
-- diagonal travel, with a small circular collision body and axis-separated wall
-- sliding.
--
-- Gold's logical grid still owns gameplay. Whenever the free body's centre
-- crosses into another cell, the normal Gen-2 landing chain is replayed: trainer
-- sight, world.stepped, warp, coord script, step counter and wild encounter.
-- Scripts/cutscenes, ledges, map connections, forced tiles, bike and surf hand
-- back to Gold's native mover instead of being reimplemented here.
--
-- Unlike the accidental v0.1.84/v0.1.85 animation bridge, this build does NOT
-- spoof Player.moving and does not install a fake Player:walkPhase. Character
-- Selector animation/body yaw can follow the player's actual px/py displacement.
local V = ...

local FirstPerson = V.require("FirstPerson")
local Voxel = V.require("VoxelState")

local Controls = {
  installed = false,
  remaps = 0,
  freeFrames = 0,
  freeCells = 0,
  wallSlides = 0,
  specialHandoffs = 0,
  lastDir = nil,
  lastWorldX = 0,
  lastWorldZ = 0,
}

-- Circular player footprint in world pixels.  A Gold cell is 16x16; 5.5 keeps
-- one-cell corridors traversable while preventing diagonal corner cutting.
Controls.RADIUS = 5.5
Controls.WALK_SPEED = 1.0 -- world px / fixed 60 Hz logic frame (Gold = 16/16)
local EPS = 0.01

local DIR_SCORE = {
  right = function(x, z) return x end,
  left  = function(x, z) return -x end,
  down  = function(x, z) return z end,
  up    = function(x, z) return -z end,
}
local DIR_ORDER = { "down", "right", "up", "left" }
local KEEP_MARGIN = 0.10
local DELTA_DIR = {
  ["1,0"] = "right", ["-1,0"] = "left",
  ["0,1"] = "down", ["0,-1"] = "up",
}

local FieldMoves, Permissions, Runtime, Player
local unpackResults = (table and table.unpack) or unpack

function Controls.directionFromWorld(x, z, previous)
  x, z = tonumber(x) or 0, tonumber(z) or 0
  if math.abs(x) < 1e-6 and math.abs(z) < 1e-6 then return nil end
  local best, bestScore = nil, -math.huge
  for _, dir in ipairs(DIR_ORDER) do
    local score = DIR_SCORE[dir](x, z)
    if score > bestScore then best, bestScore = dir, score end
  end
  if previous and DIR_SCORE[previous] then
    local oldScore = DIR_SCORE[previous](x, z)
    if oldScore > 0 and oldScore >= bestScore - KEEP_MARGIN then best = previous end
  end
  return best
end

function Controls.directionFromCameraVector(mx, mz, previous)
  local wx, wz = FirstPerson.moveWorld(mx or 0, mz or 0)
  return Controls.directionFromWorld(wx, wz, previous), wx, wz
end

function Controls.directionFromYaw()
  return Controls.directionFromCameraVector(0, 1, nil)
end

local function safeBusy(world)
  if type(world.busy) ~= "function" then return false end
  local ok, yes = pcall(world.busy, world)
  return ok and yes or false
end

local function collisionOf(world)
  if type(world.playerCollision) ~= "function" then return nil end
  local ok, c = pcall(world.playerCollision, world)
  return ok and c or nil
end

local function externalCameraOwner()
  local fn = V and V.externalCameraOwner
  if type(fn) ~= "function" then return false end
  local ok, yes = pcall(fn)
  return ok and yes == true
end

local function nativeSpecialState(world)
  if not world then return true end
  if FieldMoves.isBiking(world.playerState) or FieldMoves.isSurfing(world.playerState) then
    return true
  end
  local c = collisionOf(world)
  if c ~= nil then
    if type(Permissions.isIce) == "function" and Permissions.isIce(c) then return true end
    if type(Permissions.currentDirection) == "function"
       and Permissions.currentDirection(c) then return true end
    if type(Permissions.doorForcedDirection) == "function"
       and Permissions.doorForcedDirection(c) then return true end
  end
  return false
end

local function freeInputEligible(world)
  return not externalCameraOwner()
    and FirstPerson.driving()
    and world and world.map and world.player
    and not nativeSpecialState(world)
end

local function freeTickEligible(world)
  local p = world and world.player
  return freeInputEligible(world)
    and p and not p.moving
    and not safeBusy(world)
    and not world.mapSetup and not world.moveState
    and not world.fieldMove and not world.fishing and not world.headbutt
end

local function clearFreeState(world, snap)
  if not world then return end
  local p = world.player
  if snap and p and not p.moving and world._stadiumFreeMoveActive then
    p.px, p.py = p.cellX * 16, p.cellY * 16
  end
  world._stadiumFreeMoveActive = nil
  world._stadiumFreeX, world._stadiumFreeZ = nil, nil
  world._stadiumFreeMapId = nil
  world._stadiumFreeIntentX, world._stadiumFreeIntentZ = nil, nil
  world._stadiumFreeAnimDist = nil
  world._stadiumFreeVisualMoving = nil
  FirstPerson.releaseBody()
end

local function adopt(world)
  local p = world.player
  world._stadiumFreeX = (tonumber(p.px) or p.cellX * 16) + 8
  world._stadiumFreeZ = (tonumber(p.py) or p.cellY * 16) + 8
  world._stadiumFreeMapId = world.map and world.map.id or nil
  world._stadiumFreeMoveActive = true
  world._stadiumFreeVisualMoving = false
end

local function entityBlocked(world, p, cx, cy)
  if type(world.npcAt) == "function" then
    local ok, npc = pcall(world.npcAt, world, cx, cy)
    if ok and npc and npc ~= p and not npc.passable then return true end
  end
  for _, e in ipairs(world.entities or {}) do
    if e ~= p and not e.passable then
      if e.cellX == cx and e.cellY == cy then return true end
      if e.moving and e.targetX == cx and e.targetY == cy then return true end
    end
  end
  return false
end

local function stepPermitted(world, p, cx, cy)
  local dx, dy = cx - p.cellX, cy - p.cellY
  local dir = DELTA_DIR[tostring(dx) .. "," .. tostring(dy)]
  if not dir or type(Permissions.stepPermitted) ~= "function" then return true end
  local ok, allowed = pcall(Permissions.stepPermitted,
    function(x, y) return world.map:cellCollision(x, y) end,
    p.cellX, p.cellY, dir)
  return not ok or allowed ~= false
end

local function collisionHook(world, p, allowed, reason, cx, cy)
  if not (Runtime and type(Runtime.wantsHook) == "function"
      and Runtime.wantsHook("movement.collision")) then
    return allowed, reason
  end
  local dx, dy = cx - p.cellX, cy - p.cellY
  local dir = DELTA_DIR[tostring(dx) .. "," .. tostring(dy)]
    or Controls.directionFromWorld(dx, dy, nil)
  local ctx = {
    map = world.map, mover = p, dir = dir,
    fromX = p.cellX, fromY = p.cellY,
    toX = cx, toY = cy, reason = reason,
  }
  local function passthrough(v) return v end
  local ok, result = pcall(Runtime.call, "movement.collision", passthrough,
    allowed, ctx)
  if ok then return result and true or false, ctx.reason end
  return allowed, reason
end

-- Why this body-overlapped cell refuses entry, or nil if it is available.
local function blockedCell(world, p, cx, cy)
  if cx == p.cellX and cy == p.cellY then return nil end
  local map = world.map
  if not map:inBounds(cx, cy) then return "bounds" end

  local allowed = map:isWalkable(cx, cy) and stepPermitted(world, p, cx, cy)
  local reason = allowed and nil or "tile"
  if allowed and entityBlocked(world, p, cx, cy) then
    allowed, reason = false, "entity"
  end
  allowed, reason = collisionHook(world, p, allowed, reason, cx, cy)
  if allowed then return nil end
  return reason or "tile"
end

Controls._blockedCell = blockedCell

local function slideX(world, p, dx)
  if dx == 0 then return nil end
  local r = Controls.RADIUS
  local x, z = world._stadiumFreeX, world._stadiumFreeZ
  local nx = x + dx
  local z0 = math.floor((z - r + EPS) / 16)
  local z1 = math.floor((z + r - EPS) / 16)
  local edge = dx > 0 and math.floor((nx + r) / 16)
    or math.floor((nx - r) / 16)
  local hit
  for cz = z0, z1 do
    hit = blockedCell(world, p, edge, cz)
    if hit then break end
  end
  if hit then
    if dx > 0 then nx = math.min(nx, edge * 16 - r - EPS)
    else nx = math.max(nx, (edge + 1) * 16 + r + EPS) end
  end
  world._stadiumFreeX = nx
  return hit
end

local function slideZ(world, p, dz)
  if dz == 0 then return nil end
  local r = Controls.RADIUS
  local x, z = world._stadiumFreeX, world._stadiumFreeZ
  local nz = z + dz
  local x0 = math.floor((x - r + EPS) / 16)
  local x1 = math.floor((x + r - EPS) / 16)
  local edge = dz > 0 and math.floor((nz + r) / 16)
    or math.floor((nz - r) / 16)
  local hit
  for cx = x0, x1 do
    hit = blockedCell(world, p, cx, edge)
    if hit then break end
  end
  if hit then
    if dz > 0 then nz = math.min(nz, edge * 16 - r - EPS)
    else nz = math.max(nz, (edge + 1) * 16 + r + EPS) end
  end
  world._stadiumFreeZ = nz
  return hit
end

local function emitStepped(world, p)
  if Runtime and type(Runtime.wants) == "function" and Runtime.wants("world.stepped") then
    Runtime.emit("world.stepped", {
      mapId = world.map.id, x = p.cellX, y = p.cellY,
      tile = world.map:cellCollision(p.cellX, p.cellY),
      tod = world.tod, daytime = world.daytime,
    })
  end
end

-- Replays the exact public landing sequence used by current Gold World:stepBody.
-- true means a trainer/script/warp/encounter took control of the frame.
local function landingEvents(world, p)
  if type(world.grassAt) == "function" then
    p.inGrass = world:grassAt(p.cellX, p.cellY)
    p.grassShake = p.inGrass or nil
  end
  if type(world.checkTrainerBattle) == "function" and world:checkTrainerBattle() then
    return true
  end
  emitStepped(world, p)
  if type(world.clearWarpCooldownIfLeft) == "function" then world:clearWarpCooldownIfLeft() end
  if type(world.checkWarpOnArrive) == "function" and world:checkWarpOnArrive() then
    return true
  end
  if not world.map then return true end
  if type(world.tryCoordScript) == "function" and world:tryCoordScript() then return true end
  if type(world.countStep) == "function" and world:countStep() then return true end
  if type(world.tryWildEncounter) == "function" and world:tryWildEncounter() then return true end
  return false
end

local function dominantDir(dx, dz)
  return Controls.directionFromWorld(dx, dz, nil)
end

local function handoffBlockedSpecial(world, p, dir, why)
  if not dir then return false end
  p.facing = dir
  if why == "bounds" and type(world.tryConnection) == "function"
     and world:tryConnection(dir) then
    Controls.specialHandoffs = Controls.specialHandoffs + 1
    clearFreeState(world, false)
    return true
  end
  if why == "tile" and type(world.tryLedgeJump) == "function"
     and world:tryLedgeJump(dir) then
    Controls.specialHandoffs = Controls.specialHandoffs + 1
    clearFreeState(world, false)
    return true
  end
  if why == "entity" and type(world.tryPushBoulder) == "function" then
    local d = ({ up={0,-1}, down={0,1}, left={-1,0}, right={1,0} })[dir]
    if d and world:tryPushBoulder(dir, p.cellX + d[1], p.cellY + d[2]) then
      Controls.specialHandoffs = Controls.specialHandoffs + 1
      clearFreeState(world, false)
      return true
    end
  end
  return false
end

local function forcedCellHandoff(world, p)
  local c = collisionOf(world)
  if c == nil then return false end
  local forced = (type(Permissions.currentDirection) == "function"
      and Permissions.currentDirection(c))
    or (type(Permissions.doorForcedDirection) == "function"
      and Permissions.doorForcedDirection(c))
  local ice = type(Permissions.isIce) == "function" and Permissions.isIce(c)
  if forced or ice then
    -- Native Player:update starts interpolation from cell*16, so centre the
    -- continuous body before handing a forced/ice step back to Gold.
    p.px, p.py = p.cellX * 16, p.cellY * 16
    if ice then world.turningDirection = p.facing end
    clearFreeState(world, false)
    Controls.specialHandoffs = Controls.specialHandoffs + 1
    return true
  end
  return false
end

local function freeTick(world)
  local p = world.player
  if not p then return end

  if world._stadiumFreeMapId ~= (world.map and world.map.id)
     or world._stadiumFreeX == nil or world._stadiumFreeZ == nil then
    adopt(world)
  end

  local wx = tonumber(world._stadiumFreeIntentX) or 0
  local wz = tonumber(world._stadiumFreeIntentZ) or 0
  local mag = math.sqrt(wx * wx + wz * wz)
  if mag > 1 then wx, wz, mag = wx / mag, wz / mag, 1 end

  if mag <= 1e-6 then
    -- Hold the last travel bearing while standing. First-person A/interact is
    -- still aimed from the live camera by the wrapper below, but orbiting a
    -- third-person camera no longer spins the character in place.
    -- Keep a render-only motion bit separate from Gold Player.moving: free
    -- movement intentionally owns px/py directly, but character skin renderers
    -- still need to know whether to play their walking clip.
    world._stadiumFreeVisualMoving = false
    return
  end

  p.facing = FirstPerson.pointBody(wx, wz)
  p.animClock = (p.animClock or 0) + 1

  local speed = Controls.WALK_SPEED
  local dx, dz = wx * speed, wz * speed
  local oldX, oldZ = world._stadiumFreeX, world._stadiumFreeZ
  local hitX = slideX(world, p, dx)
  local hitZ = slideZ(world, p, dz)
  if hitX or hitZ then Controls.wallSlides = Controls.wallSlides + 1 end

  local movedX = world._stadiumFreeX - oldX
  local movedZ = world._stadiumFreeZ - oldZ
  local moved = math.sqrt(movedX * movedX + movedZ * movedZ)
  world._stadiumFreeVisualMoving = moved > 0.01
  world._stadiumFreeAnimDist = (world._stadiumFreeAnimDist or 0) + moved
  while world._stadiumFreeAnimDist >= 16 do
    world._stadiumFreeAnimDist = world._stadiumFreeAnimDist - 16
    p.stepFlip = not p.stepFlip
  end

  p.px, p.py = world._stadiumFreeX - 8, world._stadiumFreeZ - 8
  Controls.freeFrames = Controls.freeFrames + 1
  Controls.lastWorldX, Controls.lastWorldZ = wx, wz

  -- Nearest cell to the continuous body centre. Initial cell centre = 8, next
  -- centre = 24; ownership changes at their midpoint (16).
  local ncx = math.floor(world._stadiumFreeX / 16)
  local ncy = math.floor(world._stadiumFreeZ / 16)
  if ncx ~= p.cellX or ncy ~= p.cellY then
    p.cellX, p.cellY = ncx, ncy
    Controls.freeCells = Controls.freeCells + 1
    -- Directional carpet warps key off heldDir. Free walk has no heldDir, so
    -- expose the travel-facing cardinal only while the landing chain checks it.
    local savedHeld = world.heldDir
    world.heldDir = p.facing
    local taken = landingEvents(world, p)
    world.heldDir = savedHeld
    if taken then
      clearFreeState(world, false)
      return
    end
    if forcedCellHandoff(world, p) then return end
  end

  local why, dir
  if hitX and (not hitZ or math.abs(dx) >= math.abs(dz)) then
    why, dir = hitX, dx > 0 and "right" or "left"
  elseif hitZ then
    why, dir = hitZ, dz > 0 and "down" or "up"
  end
  if why and moved < speed * 0.75 then
    if handoffBlockedSpecial(world, p, dir, why) then return end
    -- Restore the true travel-facing body after a failed special probe.
    p.facing = FirstPerson.pointBody(wx, wz)
  end
end

function Controls.install()
  if Controls.installed then return true end

  local okW, World = pcall(require, "src.world.gen2.World")
  if not okW or type(World) ~= "table" then
    return false, "Gold World class unavailable: " .. tostring(World)
  end
  local okP, P = pcall(require, "src.world.gen2.Player")
  local okF, F = pcall(require, "src.world.gen2.FieldMoves")
  local okPerm, Perm = pcall(require, "src.world.gen2.Permissions")
  local okR, R = pcall(require, "src.mods.Runtime")
  if not (okP and okF and okPerm and okR) then
    return false, "Gold free-movement dependencies unavailable"
  end
  Player, FieldMoves, Permissions, Runtime = P, F, Perm, R
  if type(World.pollInput) ~= "function" or type(World.stepBody) ~= "function" then
    return false, "Gold World movement seams unavailable"
  end

  if World.stadiumTrueDirectionalControlsHook then
    Controls.installed = true
    return true
  end

  local vanillaPollInput = World.pollInput
  function World:pollInput(input)
    local out = vanillaPollInput(self, input)

    -- Explicit CHARACTER SELECTOR ownership covers its camera-relative mover
    -- as well as its view state. Never quantise or consume a second copy of
    -- the same input after the external wrapper has handled it.
    if externalCameraOwner() then
      Controls.lastDir = nil
      Controls.lastWorldX, Controls.lastWorldZ = 0, 0
      self._stadiumFreeIntentX, self._stadiumFreeIntentZ = nil, nil
      return out
    end

    if not FirstPerson.driving() then
      Controls.lastDir = nil
      Controls.lastWorldX, Controls.lastWorldZ = 0, 0
      self._stadiumFreeIntentX, self._stadiumFreeIntentZ = nil, nil
      return out
    end

    local mx, mz = FirstPerson.moveVector()
    local wx, wz = FirstPerson.moveWorld(mx, mz)

    if freeInputEligible(self) then
      -- Normal walking: do NOT hand the input to Gold's cardinal mover. The
      -- stepBody wrapper below consumes this unquantised vector after vanilla
      -- has run all of its normal script/NPC/forced-tile logic.
      self._stadiumFreeIntentX, self._stadiumFreeIntentZ = wx, wz
      self.heldDir = nil
      Controls.lastDir = nil
      Controls.lastWorldX, Controls.lastWorldZ = wx, wz
      return out
    end

    -- Bike, surf and forced/special movement remain native Gold grid movement,
    -- with camera-relative cardinal interpretation.
    self._stadiumFreeIntentX, self._stadiumFreeIntentZ = nil, nil
    if mx == 0 and mz == 0 then
      Controls.lastDir = nil
      return out
    end
    local dir = Controls.directionFromWorld(wx, wz, Controls.lastDir)
    if dir then
      self.heldDir = dir
      Controls.lastDir = dir
      Controls.lastWorldX, Controls.lastWorldZ = wx, wz
      Controls.remaps = Controls.remaps + 1
    end
    return out
  end

  local vanillaStepBody = World.stepBody
  function World:stepBody(...)
    local out = { vanillaStepBody(self, ...) }

    if freeTickEligible(self) then
      freeTick(self)
    else
      -- If Gold itself started a step (ice/current/connection/cutscene), never
      -- recenter over that animation. Otherwise leaving FIRST/THIRD PERSON or
      -- opening a script/menu cleanly hands the player back to the grid centre.
      local snap = self.player and not self.player.moving
      clearFreeState(self, snap)
    end

    return unpackResults(out)
  end

  -- No Player.moving / walkPhase spoofing in v0.1.98. Actual px/py
  -- displacement is the animation signal for external character renderers.

  -- In first person the camera is the player's head. Keep A/interact aligned to
  -- the look direction; third person uses the last continuous travel-facing.
  if type(World.interact) == "function" then
    local vanillaInteract = World.interact
    function World:interact(...)
      if not externalCameraOwner()
         and FirstPerson.driving() and Voxel.isFirstPerson(Voxel.level)
         and self.player and not self.player.moving then
        local dir = Controls.directionFromYaw()
        if dir then self.player.facing = dir end
      end
      return vanillaInteract(self, ...)
    end
  end

  World.stadiumTrueDirectionalControlsHook = true
  -- Compatibility marker used by existing diagnostics. This implementation is
  -- the true-directional variant, not the old cardinal-only adapter.
  World.stadiumCameraRelativeControlsHook = true
  Controls.installed = true
  return true
end

function Controls.status()
  return {
    installed = Controls.installed,
    mode = "first_and_third_person_continuous",
    remaps = Controls.remaps,
    freeFrames = Controls.freeFrames,
    freeCells = Controls.freeCells,
    wallSlides = Controls.wallSlides,
    specialHandoffs = Controls.specialHandoffs,
    lastDir = Controls.lastDir,
    lastWorldX = Controls.lastWorldX,
    lastWorldZ = Controls.lastWorldZ,
  }
end

return Controls
