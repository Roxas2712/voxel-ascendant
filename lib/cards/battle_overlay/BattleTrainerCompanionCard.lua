-- Optional trainer-companion composition for VASC's three staged battle modes.
--
-- This Card is deliberately dormant until a generation host registers it.
-- It owns no engine hook and mutates no BattleState.  The pure planner proves
-- the shared geometry/lifetime contract before MAP, ARENA or DISCS rendering
-- is touched: approved HD front art is retained behind each deployed Pokemon;
-- a wild battle retains only the player's trainer.

local Card = {
  ID = "vasc.battle.trainer-companions",
  VERSION = "0.1.0",
  CAPABILITY = "ascendant.battle-trainer-companions/v1",
  OPTION_KEY = "battleTrainerCompanions",
  STEP_SECONDS = 0.42,
  RETREAT_WORLD = 14,
  SHOULDER_WORLD = 10,
}

local SUPPORTED_MODE = { MAP=true, ARENA=true, DISCS=true }

local function finite(value)
  value = tonumber(value)
  return value and value == value and math.abs(value) < math.huge and value
    or nil
end

local function point(value)
  if type(value) ~= "table" then return nil end
  local x = finite(value.x or value[1])
  local y = finite(value.y or value[2]) or 0
  local z = finite(value.z or value[3])
  if not (x and z) then return nil end
  return { x=x, y=y, z=z }
end

local function clamp01(value)
  return math.max(0, math.min(1, finite(value) or 0))
end

local function smooth(value)
  value = clamp01(value)
  return value * value * (3 - 2 * value)
end

local function lerp(a, b, amount)
  return a + (b - a) * amount
end

-- Dimensions are not sufficient evidence: an old 56px cartridge trainer can
-- also sit in a larger transparent carrier.  Accept only the explicit front
-- and HD-source receipts already published by the Gen-1 KASC/VASC resolver or
-- Crystal's Gen2TrainerArt resolver.
function Card.isApprovedHdFront(texture)
  if type(texture) ~= "table"
      or texture.trainerArt ~= true
      or texture.vascSpriteView ~= "front" then return false end
  if texture.ascendantHighResTrainer == true then return true end
  local source = tostring(texture.source or "")
  return source:find("kasc%-hd", 1, false) ~= nil
    or type(texture.vascEmbeddedTrainer) == "table"
      and texture.vascEmbeddedTrainer.body == "full"
end

local function targetFor(side, pokemon, ux, uz)
  local px, pz = -uz, ux
  if side == "player" then
    return {
      x=pokemon.x - ux * Card.RETREAT_WORLD + px * Card.SHOULDER_WORLD,
      y=pokemon.y,
      z=pokemon.z - uz * Card.RETREAT_WORLD + pz * Card.SHOULDER_WORLD,
    }
  end
  return {
    x=pokemon.x + ux * Card.RETREAT_WORLD - px * Card.SHOULDER_WORLD,
    y=pokemon.y,
    z=pokemon.z + uz * Card.RETREAT_WORLD - pz * Card.SHOULDER_WORLD,
  }
end

local function actor(side, pokemon, texture, elapsed, ux, uz)
  if not (pokemon and Card.isApprovedHdFront(texture)) then return nil end
  local start = point(texture.introPosition) or pokemon
  local target = targetFor(side, pokemon, ux, uz)
  local progress = smooth((finite(elapsed) or 0) / Card.STEP_SECONDS)
  return {
    side=side,
    role=side .. "-trainer-companion",
    texture=texture,
    position={
      x=lerp(start.x, target.x, progress),
      y=lerp(start.y, target.y, progress),
      z=lerp(start.z, target.z, progress),
    },
    target=target,
    progress=progress,
    layer="behind-pokemon",
    occlusion="world-depth",
  }
end

function Card.plan(request)
  request = type(request) == "table" and request or {}
  local mode = tostring(request.mode or ""):upper()
  local result = {
    schema=Card.CAPABILITY,
    optionKey=Card.OPTION_KEY,
    mode=mode,
    active=false,
    actors={},
  }
  if request.enabled ~= true then
    result.reason = "option-disabled"
    return result
  end
  if not SUPPORTED_MODE[mode] then
    result.reason = "mode-not-staged"
    return result
  end
  local pokemon = type(request.pokemon) == "table" and request.pokemon or {}
  local player, enemy = point(pokemon.player), point(pokemon.enemy)
  if not (player and enemy) then
    result.reason = "pokemon-anchors-unavailable"
    return result
  end
  local dx, dz = enemy.x - player.x, enemy.z - player.z
  local length = math.sqrt(dx * dx + dz * dz)
  if length < 0.001 then
    result.reason = "pokemon-anchors-overlap"
    return result
  end
  local ux, uz = dx / length, dz / length
  local trainers = type(request.trainers) == "table" and request.trainers or {}
  local playerActor = actor("player", player, trainers.player,
    request.elapsed, ux, uz)
  if playerActor then result.actors[#result.actors + 1] = playerActor end
  if tostring(request.battleKind or ""):lower() ~= "wild" then
    local enemyActor = actor("enemy", enemy, trainers.enemy,
      request.elapsed, ux, uz)
    if enemyActor then result.actors[#result.actors + 1] = enemyActor end
  end
  result.active = #result.actors > 0
  result.reason = result.active and nil or "approved-hd-front-unavailable"
  return result
end

function Card.optionDescriptor()
  return {
    key=Card.OPTION_KEY,
    label="TRAINER IM KAMPF",
    values={ false, true },
    labels={ "AUS", "AN" },
    default=false,
    help="HD-Trainer begleiten MAP-, ARENA- und DISCS-Kaempfe.",
  }
end

function Card.descriptor()
  return {
    schema="ascendant.card/v1",
    id=Card.ID,
    version=Card.VERSION,
    owner="voxel_ascendant",
    requires={},
    optionalRequires={},
    consumes={},
    provides={ Card.CAPABILITY },
    tests={ "tests/battle_trainer_companion_card_test.lua" },
    docs={},
    saveNamespace=false,
    impact={
      runtimeOwners={ "battle.trainer-companion-plan" },
      saveWrites={},
      publicHooks={},
      files={
        "lib/cards/battle_overlay/BattleTrainerCompanionCard.lua",
      },
    },
    lifecycle={
      install=function() return { planner=Card.plan } end,
      activate=function(_, installed)
        local service = {
          schema=Card.CAPABILITY,
          plan=installed.planner,
          option=Card.optionDescriptor,
        }
        return { service=service }, service
      end,
      deactivate=function() return true end,
      abort=function() return true end,
      health=function(_, _, active)
        return {
          schema="ascendant.compat-status/v1",
          ok=type(active) == "table" and type(active.service) == "table",
          state=type(active) == "table" and "active" or "inactive",
          rendererAttached=false,
        }
      end,
    },
  }
end

return Card
