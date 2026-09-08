-- Small Gen-1 controller built on the public NPC surface.  It replaces only
-- the two engine callbacks that create and advance the one follower entity;
-- no private closure or Yellow story routine is accessed.

local Gen1Follower = {}
local INDEX = 250

local function find(world)
  for index, npc in ipairs(world and world.npcs or {}) do
    if npc._ascendantPokemonOverworld or npc.pikachuFollower then
      return npc, index
    end
  end
  return nil
end

local function remove(world)
  local npc, index = find(world)
  if not npc then return end
  table.remove(world.npcs, index)
  for drawIndex, entity in ipairs(world.entities or {}) do
    if entity == npc then table.remove(world.entities, drawIndex) break end
  end
end

local function behind(world)
  local player = world.player
  local delta = {
    up={ 0, 1 }, down={ 0, -1 }, left={ 1, 0 }, right={ -1, 0 },
  }
  local step = delta[player.facing] or delta.down
  local x, y = player.cellX + step[1], player.cellY + step[2]
  if world.map:inBounds(x, y) and world.map:isWalkableCell(x, y) then
    return x, y
  end
  return player.cellX, player.cellY
end

local function spawn(game, world, x, y)
  local NPC = require("src.world.NPC")
  local npc = NPC.new(game.data, world.map.id, {
    index=INDEX, name="ASCENDANT_FOLLOWER", sprite="SPRITE_PIKACHU",
    movement="STAY", range="NONE", x=x, y=y,
  })
  npc.pikachuFollower = true
  npc._ascendantPokemonOverworld = true
  npc.passable = true
  npc.facing = world.player.facing or "down"
  world.npcs = world.npcs or {}
  world.entities = world.entities or {}
  table.insert(world.npcs, npc)
  table.insert(world.entities, npc)
  world.pikachuTrail = { x=world.player.cellX, y=world.player.cellY }
  return npc
end

function Gen1Follower.new(shouldSpawn)
  assert(type(shouldSpawn) == "function")
  local Controller = {}

  function Controller.onMapEntered(game, world, options, viaMapLoad)
    if not (world and world.map and world.player) then return end
    -- The engine's native follower also waits for this transport record.
    -- A data reload or unavailable provider must not reach NPC.new without it.
    if not (game and game.data and game.data.sprites
        and game.data.sprites.SPRITE_PIKACHU) then return end
    local kept = options and (options.keepPikachu or options.keepFollower)
    remove(world)
    if not shouldSpawn(game, world) then return end
    if kept and kept._ascendantPokemonOverworld then
      table.insert(world.npcs, kept)
      table.insert(world.entities, kept)
      return kept
    end
    local x, y = behind(world)
    if viaMapLoad then x, y = world.player.cellX, world.player.cellY end
    return spawn(game, world, x, y)
  end

  function Controller.update(game, world)
    if not (world and world.map and world.player) then return end
    local npc = find(world)
    if not shouldSpawn(game, world) then remove(world) return end
    if not npc then
      Controller.onMapEntered(game, world)
      return
    end

    local player = world.player
    local trail = world.pikachuTrail
    if not trail then
      trail = { x=player.cellX, y=player.cellY }
      world.pikachuTrail = trail
    end
    local destinationX = player.targetX or player.cellX
    local destinationY = player.targetY or player.cellY
    if destinationX ~= trail.x or destinationY ~= trail.y then
      npc.goalX, npc.goalY = trail.x, trail.y
      trail.x, trail.y = destinationX, destinationY
    end
    if npc.moving or not npc.goalX then return end
    if npc.cellX == npc.goalX and npc.cellY == npc.goalY then
      npc.goalX, npc.goalY = nil, nil
      return
    end

    local distance = math.abs(npc.cellX - npc.goalX)
      + math.abs(npc.cellY - npc.goalY)
    if distance > 6 then
      npc.cellX, npc.cellY = npc.goalX, npc.goalY
      npc.px, npc.py = npc.cellX * 16, npc.cellY * 16
      npc.goalX, npc.goalY = nil, nil
      return
    end

    local direction
    if npc.cellX < npc.goalX then direction = "right"
    elseif npc.cellX > npc.goalX then direction = "left"
    elseif npc.cellY < npc.goalY then direction = "down"
    else direction = "up" end
    local dx = direction == "right" and 1 or direction == "left" and -1 or 0
    local dy = direction == "down" and 1 or direction == "up" and -1 or 0
    npc.facing = direction
    npc.targetX, npc.targetY = npc.cellX + dx, npc.cellY + dy
    npc.stepFrames = math.max(1, math.floor((player.stepFramesCur
      or player.stepFrames or 16) / (distance > 1 and 2 or 1)))
    npc.moving, npc.progress = true, 0
    npc:update(world.map, world.entities)
  end

  return Controller
end

return Gen1Follower
