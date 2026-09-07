-- Gold/Silver visible-only ordinary encounter guard.
--
-- v0.1.78's World:tryWildEncounter checks roaming beasts BEFORE it calls the
-- public encounter.roll hook. Therefore returning nil from encounter.roll is
-- insufficient to guarantee that every ordinary grass/cave encounter has a
-- visible roaming body. This wrapper only gates the automatic STEP encounter
-- method. Sweet Scent, fishing, Headbutt, Rock Smash and scripted battles use
-- other methods and are intentionally left alone. Bug Catching Contest keeps
-- its native step encounters because those are part of the contest rules.
local V = ...

local Guard = {
  installed = false,
  blocked = 0,
  passed = 0,
  lastReason = nil,
}

local Config = V.require("config")

local function isBugContest(world)
  local ok, BugContest = pcall(require, "src.core.gen2.BugContest")
  local save = world and world.game and world.game.save
  if ok and BugContest and type(BugContest.isActive) == "function" and save then
    local okActive, active = pcall(BugContest.isActive, save)
    return okActive and active == true
  end
  return false
end

local function standingOnWater(world)
  local ok, FieldMoves = pcall(require, "src.world.gen2.FieldMoves")
  local map, player = world and world.map, world and world.player
  if not (ok and FieldMoves and map and player and type(map.cellCollision) == "function") then
    return false
  end
  local okColl, coll = pcall(map.cellCollision, map, player.cellX, player.cellY)
  if not okColl then return false end
  if type(FieldMoves.encounterTable) == "function" then
    local okKind, kind = pcall(FieldMoves.encounterTable, coll)
    return okKind and kind == "water"
  end
  return false
end

function Guard.shouldBlock(world, mod)
  if not Config.isEnabled(mod) then
    Guard.lastReason = "wilds disabled"
    return false
  end
  if Config.randomEncountersEnabled(mod) then
    Guard.lastReason = "classic step encounters enabled"
    return false
  end
  if isBugContest(world) then
    Guard.lastReason = "bug contest preserved"
    return false
  end
  -- The Water Mons = Classic Enc option is an explicit request for native
  -- invisible water rolls. Preserve it even while land/cave stays visible-only.
  if Config.waterDisplayMode(mod) == "classic_encounters" and standingOnWater(world) then
    Guard.lastReason = "classic water mode preserved"
    return false
  end
  Guard.lastReason = "visible-only ordinary step encounter"
  return true
end

function Guard.install(mod)
  if Guard.installed then return true end
  local okWorld, World = pcall(require, "src.world.gen2.World")
  if not okWorld or type(World) ~= "table" or type(World.tryWildEncounter) ~= "function" then
    return false, "src.world.gen2.World.tryWildEncounter unavailable"
  end

  -- Do not stack duplicate wrappers if the module is reloaded during dev work.
  if World._stadium2VisibleEncounterOriginal then
    Guard.installed = true
    return true
  end

  local original = World.tryWildEncounter
  World._stadium2VisibleEncounterOriginal = original
  World.tryWildEncounter = function(self, ...)
    if Guard.shouldBlock(self, mod) then
      Guard.blocked = Guard.blocked + 1
      return false
    end
    Guard.passed = Guard.passed + 1
    return original(self, ...)
  end
  World._stadium2VisibleEncounterGuard = Guard
  Guard.installed = true
  return true
end

function Guard.status()
  return {
    installed = Guard.installed,
    blocked = Guard.blocked,
    passed = Guard.passed,
    lastReason = Guard.lastReason,
  }
end

return Guard
