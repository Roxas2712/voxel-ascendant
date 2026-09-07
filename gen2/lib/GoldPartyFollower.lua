-- Gold/Silver party follower ownership bridge.
--
-- Gen1Recomp Gold exposes src.world.gen2.Follower, while the embedded Wilds
-- runtime also owns a complete party-trailer mover. v0.2.71 let both systems
-- create follower slot #1, which produced duplicates at zone seams. v0.2.72
-- tried to reserve slot #1 for the native Gold mover, but that kept the stale
-- transition copy on affected engine builds and removed the Wilds trailer that
-- was actually advancing with the player.
--
-- v0.2.73 makes ownership explicit: when embedded Wilds is available, Wilds
-- owns ALL visible party followers, including slot #1, and Gold's native
-- follower is kept disabled/cleaned up. The native Gen-2 mover remains only as
-- a fallback if the embedded Wilds follower runtime failed to boot.
local V = ...
local mod = V.mod

local Bridge = {
  installed = false,
  spawned = false,
  lastSpecies = nil,
  runtimeOwner = "pending",
  nativeFollowersRemoved = 0,
  lastCleanupReason = nil,
  lastError = nil,
}

-- Native fallback sprites ---------------------------------------------------
-- Gold's engine follower is born from SPRITE_PIKACHU. If Wilds ever fails to
-- boot and the native fallback is used, bind that entity to the selected party
-- species so the 2D fallback remains correct as well.
local follower2DDefs = {}

local function dexNumber(v)
  local n = tonumber(v)
  if not n then return nil end
  n = math.floor(n)
  if n < 1 or n > 251 then return nil end
  return n
end

local function cleanSpecies(v)
  if type(v) ~= "string" then return nil end
  return v:upper():gsub("[^A-Z0-9]", "")
end

local function speciesDex(game, species)
  local n = dexNumber(species)
  if n then return n end
  if type(species) ~= "string" then return nil end
  local data = game and game.data
  local pokemon = data and data.pokemon
  if type(pokemon) == "table" then
    local def = pokemon[species] or pokemon[species:upper()]
    n = def and dexNumber(def.dex or def.number or def.id)
    if n then return n end
    local wanted = cleanSpecies(species)
    if wanted then
      for key, candidate in pairs(pokemon) do
        if cleanSpecies(key) == wanted then
          n = candidate and dexNumber(candidate.dex or candidate.number or candidate.id)
          if n then return n end
        end
      end
    end
  end
  local dex = data and data.gen2Pokedex
  local entry = dex and dex.entries and (dex.entries[species] or dex.entries[species:upper()])
  return entry and dexNumber(entry.dex or entry.number or entry.id) or nil
end

local function monShiny(mon)
  if not mon then return false end
  if mon.shiny == true or mon.isShiny == true then return true end
  local okStats, Stats = pcall(require, "src.pokemon.Stats")
  if okStats and Stats and type(Stats.isShiny) == "function" and mon.dvs then
    local ok, shiny = pcall(Stats.isShiny, mon.dvs)
    if ok then return shiny == true end
  end
  return false
end

local function assetPath(rel)
  if mod and mod.assets and type(mod.assets.path) == "function" then
    local ok, path = pcall(mod.assets.path, mod.assets, rel)
    if ok and path then return path end
  end
  if mod and mod.path then return mod.path .. "/" .. rel end
  return rel
end

local function assetExists(rel)
  if mod and type(mod.read) == "function" then
    local ok, data = pcall(mod.read, mod, rel)
    return ok and data ~= nil
  end
  return true
end

local function follower2DDef(game, mon)
  local dex = speciesDex(game, mon and mon.species)
  if not dex then return nil, nil end
  local shiny = monShiny(mon)
  local variant = shiny and "shiny" or "normal"
  local key = string.format("%03d:%s", dex, variant)
  if follower2DDefs[key] then return follower2DDefs[key], key end

  local rel = string.format(
    "assets/enhanced_overworld/poke_followers/follower_%03d_%s.png", dex, variant)
  if shiny and not assetExists(rel) then
    variant = "normal"
    key = string.format("%03d:normal", dex)
    if follower2DDefs[key] then return follower2DDefs[key], key end
    rel = string.format(
      "assets/enhanced_overworld/poke_followers/follower_%03d_normal.png", dex)
  end
  if not assetExists(rel) then return nil, nil end

  local def = {
    id = "SPRITE_STADIUM2_FOLLOWER_" .. string.format("%03d", dex),
    image = assetPath(rel),
    frames = 6,
    walker = true,
    trueColor = true,
  }
  follower2DDefs[key] = def
  return def, key
end

local function bindFollower2D(game, npc, mon)
  if not (npc and mon) then return false end
  local def, key = follower2DDef(game, mon)
  if not (def and key) then return false end
  if npc._stadium2Follower2DKey == key then return true end

  local changed = false
  if type(npc.setSpriteDef) == "function" then
    local ok, result = pcall(npc.setSpriteDef, npc, def)
    changed = ok and result ~= false
  else
    local okRenderer, SpriteRenderer = pcall(require, "src.render.SpriteRenderer")
    if okRenderer and SpriteRenderer and type(SpriteRenderer.new) == "function" then
      local ok, renderer = pcall(SpriteRenderer.new, def, npc.id)
      if ok and renderer then
        npc.sprite, npc.spriteDef = renderer, def
        changed = true
      end
    end
  end
  if changed or (npc.spriteDef and npc.spriteDef.image == def.image) then
    npc._stadium2Follower2DKey = key
    npc._stadium2FollowerDex = speciesDex(game, mon.species)
    return true
  end
  return false
end

-- Ownership ----------------------------------------------------------------
local function optionEnabled()
  if not (mod and mod.options and type(mod.options.get) == "function") then
    return true
  end
  local ok, value = pcall(mod.options.get, mod.options, "partyFollower")
  if not ok or value == nil then return true end
  return value ~= false
end

local function validFollowerMon(mon)
  if type(mon) ~= "table" or mon.species == nil then return nil end
  local species = tostring(mon.species or "")
  if species == "" or species:upper() == "EGG" then return nil end
  return mon
end

local function embeddedWildsFollower()
  local exports = mod and mod.exports
  if type(exports) ~= "table" then return nil end

  -- Normal post-load shape from main.lua.
  local wilds = exports.wilds
  if type(wilds) == "table" and type(wilds.follower) == "table" then
    return wilds.follower
  end

  -- During the embedded factory's own load phase the child exports temporarily
  -- live directly on mod.exports. Keeping this fallback makes hot reloads safe.
  if type(exports.follower) == "table" and type(exports.follower.control) == "table" then
    return exports.follower
  end
  return nil
end

local function wildsOwnsPrimary()
  return embeddedWildsFollower() ~= nil
end

local function leadMon(game)
  local follower = embeddedWildsFollower()
  if follower and type(follower.getActiveFollowerMon) == "function" then
    local ok, selected = pcall(follower.getActiveFollowerMon, follower, game, true)
    if ok then
      selected = validFollowerMon(selected)
      if selected then return selected end
    end
  end

  local save = game and game.save
  local party = save and save.party
  return validFollowerMon(type(party) == "table" and party[1] or nil)
end

local function isNativeFollower(entity)
  return type(entity) == "table"
     and entity.pikachuFollower == true
     and entity.pokepcTrailer ~= true
end

local function removeIdentity(list, victim)
  if type(list) ~= "table" or victim == nil then return false end
  local removed = false
  for i = #list, 1, -1 do
    if list[i] == victim then
      table.remove(list, i)
      removed = true
    end
  end
  return removed
end

-- When Wilds owns follower slot #1, remove every engine-native follower copy.
-- Wilds trailers are explicitly marked pokepcTrailer=true and are never
-- touched here. This is intentionally an all-native cleanup rather than a
-- "pick one to keep" dedupe: preserving an old world.follower pointer is the
-- exact v0.2.72 bug that kept the frozen previous-zone entity alive.
local function purgeNativeFollowers(world, reason)
  if not world then return 0 end
  local victims, seen = {}, {}
  local function collect(list)
    for _, entity in ipairs(type(list) == "table" and list or {}) do
      if isNativeFollower(entity) and not seen[entity] then
        seen[entity] = true
        victims[#victims + 1] = entity
      end
    end
  end
  collect(world.npcs)
  collect(world.entities)
  if isNativeFollower(world.follower) and not seen[world.follower] then
    victims[#victims + 1] = world.follower
  end

  local removed = 0
  for _, victim in ipairs(victims) do
    local a = removeIdentity(world.npcs, victim)
    local b = removeIdentity(world.entities, victim)
    if a or b then removed = removed + 1 end
    if world.follower == victim then world.follower = nil end
  end

  if removed > 0 then
    Bridge.nativeFollowersRemoved = Bridge.nativeFollowersRemoved + removed
    Bridge.lastCleanupReason = reason or "runtime"
  end
  return removed
end

local function normalWalkingState(world)
  if not world then return false end
  local ok, FieldMoves = pcall(require, "src.world.gen2.FieldMoves")
  if not ok or type(FieldMoves) ~= "table" then return true end
  if type(FieldMoves.isBiking) == "function" and FieldMoves.isBiking(world.playerState) then
    return false
  end
  if type(FieldMoves.isSurfing) == "function" and FieldMoves.isSurfing(world.playerState) then
    return false
  end
  return true
end

local function markNativeFallback(game, world, Follower)
  if not (world and Follower and type(Follower.current) == "function") then
    return nil
  end
  local npc = Follower.current(world)
  local mon = leadMon(game)
  if not npc or not mon then return npc end

  npc.pokepcMon = mon
  npc._pokepcFollowerSpecies = mon.species
  npc.pokepcFollowerSpecies = mon.species
  npc.pokemonSpecies = mon.species
  npc.wildsFollower = true
  npc.passable = true
  pcall(bindFollower2D, game, npc, mon)
  Bridge.spawned = true
  Bridge.lastSpecies = mon.species
  return npc
end

local function currentGame()
  local mw = mod and mod.world
  if type(mw) == "table" and type(mw.game) == "table" then
    return mw.game
  end
  -- On Gold, the mod-side Gen2Compat require of src.core.Game is a live proxy.
  local ok, Game = pcall(require, "src.core.Game")
  if ok and type(Game) == "table" then return Game end
  return nil
end

local function refreshOwnership(game, world, Follower, reason)
  if wildsOwnsPrimary() then
    Bridge.runtimeOwner = "wilds"
    Bridge.spawned = false
    purgeNativeFollowers(world, reason or "wilds_owner")

    local follower = embeddedWildsFollower()
    local mon = follower and type(follower.getActiveFollowerMon) == "function"
      and select(2, pcall(follower.getActiveFollowerMon, follower, game, true)) or nil
    mon = validFollowerMon(mon)
    Bridge.lastSpecies = mon and mon.species or Bridge.lastSpecies
    return false
  end

  Bridge.runtimeOwner = "native_fallback"
  markNativeFallback(game, world, Follower)
  return optionEnabled() and leadMon(game) ~= nil and normalWalkingState(world)
end

function Bridge.install()
  if Bridge.installed then return true end
  local okFollower, Follower = pcall(require, "src.world.gen2.Follower")
  if not okFollower or type(Follower) ~= "table"
      or type(Follower.setShouldSpawn) ~= "function" then
    Bridge.lastError = "src.world.gen2.Follower.setShouldSpawn unavailable"
    return false, Bridge.lastError
  end

  Follower.setShouldSpawn(function(game, world)
    return refreshOwnership(game, world, Follower, "native_tick")
  end)

  if mod and mod.events and type(mod.events.on) == "function" then
    mod.events:on("map.entered", function()
      local game = currentGame()
      local world = game and (game.world or game.overworld)
      if world then pcall(refreshOwnership, game, world, Follower, "map_entered") end
    end)
    mod.events:on("game.ready", function(game)
      local g = game or currentGame()
      local world = g and (g.world or g.overworld)
      if world then pcall(refreshOwnership, g, world, Follower, "game_ready") end
    end)
    mod.events:on("mod.options_changed", function(payload)
      if not (payload and payload.mod == mod.id and payload.key == "partyFollower") then
        return
      end
      local game = currentGame()
      local world = game and (game.world or game.overworld)
      if world then pcall(refreshOwnership, game, world, Follower, "option_changed") end
    end)
  end

  Bridge.installed = true
  Bridge.lastError = nil
  return true
end

function Bridge.status()
  return {
    installed = Bridge.installed,
    enabled = optionEnabled(),
    spawned = Bridge.spawned,
    species = Bridge.lastSpecies,
    owner = Bridge.runtimeOwner,
    nativeFollowersRemoved = Bridge.nativeFollowersRemoved,
    lastCleanupReason = Bridge.lastCleanupReason,
    error = Bridge.lastError,
  }
end

return Bridge
