-- Pokemon Stadium models for overworld Pokemon entities.
--
-- This module deliberately reuses Dramatic Shape's existing StadiumPack,
-- StadiumMon and StadiumRig pipeline.  It does not contain or redistribute
-- Pokemon Stadium models.  A model exists only after the user has imported a
-- compatible Stadium ROM through Dramatic Shape's own model builder.
--
-- Integration contract:
--   * VoxelScene captures the real entity beside each rendered pose.
--   * prepare(posed) resolves an exact species, advances one StadiumMon per
--     entity, skins it once, and stores the model matrix on the pose.
--   * draw(pose) is used by both the main cast and water reflection.
--   * cast(pose, ShadowMap) sends the same skinned geometry to the sun pass.
--
-- Companion mods can tag a spawned NPC without mutating engine internals:
--
--   local ds = mod.find("DRAMATIC_SHAPE")
--   local ow = ds and ds.exports and ds.exports.lib
--              and ds.exports.lib.require("OverworldStadium")
--   if ow then ow.tag(npc, "PIKACHU") end
--
-- Accepted tags are National Dex numbers (1..251) or engine species strings.
local V = ...

local StadiumMon = V.require("StadiumMon")
local StadiumPack = V.require("StadiumPack")
local Mat4 = V.require("Mat4")
local Config = V.require("OverworldStadiumConfig")
local PokemonHeights = V.require("PokemonHeights")
local PokemonLocomotion = V.require("PokemonLocomotion")
local FirstPerson = V.require("FirstPerson")

local function modelsEnabled()
  if type(V.modelsEnabled) == "function" then
    local ok, value = pcall(V.modelsEnabled)
    if ok then return value ~= false end
  end
  return true
end

local function playerModelsEnabled()
  if type(V.playerModelsEnabled) == "function" then
    local ok, value = pcall(V.playerModelsEnabled)
    if ok then return value ~= false end
  end
  return true
end

-- Dex 249 no longer touches the unstable Stadium-2 ROM hierarchy. v0.2.20
-- gives Lugia a dedicated procedural 3D rescue rig through StadiumMon. Keep the
-- species-correct card only as a LAST-RESORT safety path for a host/driver where
-- even that isolated 3D mesh cannot be created.
local lugiaFallbackRenderer = nil
local LUGIA_FALLBACK_SCALE = 2.35
local LUGIA_FALLBACK_NORMAL = "assets/enhanced_overworld/poke_followers/follower_249_normal.png"
local LUGIA_FALLBACK_SHINY = "assets/enhanced_overworld/poke_followers/follower_249_shiny.png"

-- Optional 3D Character Selector bridge (red_3d_player).  The selector installs
-- its live ActiveRenderer on src.world.gen2.Player.red3dPlayerRenderer.  Gold's
-- standalone voxel renderer never calls Player:draw(), so without this bridge
-- the selector can change state successfully while this scene keeps drawing the
-- stock trainer card.  Resolve the renderer dynamically every frame so load
-- order, hot reloads, imported skins, and later selector changes all work.
local red3dPlayerClass = nil
local red3dFieldMoves = nil

local function gen2PlayerClass()
  if type(red3dPlayerClass) == "table" then return red3dPlayerClass end
  local ok, Player = pcall(require, "src.world.gen2.Player")
  if ok and type(Player) == "table" then
    red3dPlayerClass = Player
    return Player
  end
  return nil
end

local function liveGoldWorld()
  -- The standalone Gold bridge already owns the exact live Game2 instance.
  -- Prefer it before any compatibility facade: Game.overworld/StateStack can
  -- lag during the first map and only refresh after a map connection, which
  -- previously made third-person skin animation appear to "wake up" only
  -- after transitioning.
  if type(V.game) == "table" then
    local direct = V.game.world or V.game.overworld
    if type(direct) == "table" then return direct end
  end

  -- Gen2Compat's supported Gen-1 spelling is still a fallback for host builds
  -- that do not expose the Game2 instance through the bridge.
  local okGame, Game = pcall(require, "src.core.Game")
  if okGame and type(Game) == "table" then
    local okWorld, world = pcall(function() return Game.overworld end)
    if okWorld and type(world) == "table" then return world end
  end

  local okStack, StateStack = pcall(require, "src.core.StateStack")
  if okStack and type(StateStack) == "table" and type(StateStack.top) == "function" then
    local okTop, top = pcall(StateStack.top, StateStack)
    if okTop and type(top) == "table" then
      local game = top.game or top.g
      if type(game) == "table" then
        local world = game.world or game.overworld
        if type(world) == "table" then return world end
      end
    end
  end
  return nil
end

local function red3dSpecialCard(player)
  if type(player) ~= "table" then return false end
  if player.fishing then return true end

  local world = liveGoldWorld()
  if type(world) ~= "table" then return false end
  if world.fishing then return true end

  if red3dFieldMoves == nil then
    local ok, FieldMoves = pcall(require, "src.world.gen2.FieldMoves")
    red3dFieldMoves = (ok and type(FieldMoves) == "table") and FieldMoves or false
  end
  if not red3dFieldMoves then return false end

  local state = world.playerState
  if state == nil then return false end
  if type(red3dFieldMoves.isSurfing) == "function" then
    local ok, yes = pcall(red3dFieldMoves.isSurfing, state)
    if ok and yes then return true end
  end
  if type(red3dFieldMoves.isBiking) == "function" then
    local ok, yes = pcall(red3dFieldMoves.isBiking, state)
    if ok and yes then return true end
  end
  return false
end

local function red3dPokemonControl(player)
  return type(player) == "table" and (player._pokepcAsPokemon == true
    or player._pokepcControlSpecies ~= nil or player.pokepcControlSpecies ~= nil)
end

local function red3dRendererForPose(p)
  if not playerModelsEnabled() then return nil end
  if not (p and p.isPlayer and type(p.entity) == "table") then return nil end
  if red3dPokemonControl(p.entity) or red3dSpecialCard(p.entity) then return nil end

  local Player = gen2PlayerClass()
  local renderer = Player and Player.red3dPlayerRenderer or nil
  if type(renderer) ~= "table" or renderer.failed then return nil end
  if type(renderer.drawVoxel) ~= "function" then return nil end
  return renderer
end

local OverworldStadium = {}
local MAX_DEX = 251

local tagged = setmetatable({}, { __mode = "k" })
-- Last confirmed Pokemon identity for an entity.  Flight/control mods can
-- temporarily replace or strip follower metadata while swapping sprites; keep
-- the Stadium identity stable across that visual transition.
local entityDexCache = setmetatable({}, { __mode = "k" })
local slots = setmetatable({}, { __mode = "k" })
local nameCache = {}
local spriteCache = {}
local frameNo = 0
local reported = {}
local basePackKeep = tonumber(StadiumPack.KEEP) or 4

local function logOnce(key, fmt, ...)
  if reported[key] then return end
  reported[key] = true
  local log = V.mod and V.mod.log
  if log and log.warn then
    pcall(log.warn, log, fmt, ...)
  end
end

local function gameObject()
  -- Gold/Game2 is supplied live by GoldVoxelBridge as V.game. Prefer it so
  -- party slot #1 and Gen-2 data resolve from the active save. Keep the old
  -- Gen-1 singleton fallback for compatibility with the shared renderer.
  if type(V.game) == "table" then return V.game end
  local ok2, Game2 = pcall(require, "src.core.Game2")
  if ok2 and type(Game2) == "table" and (Game2.world or Game2.save) then
    return Game2
  end
  local ok, Game = pcall(require, "src.core.Game")
  if not ok or type(Game) ~= "table" then return nil end
  return Game
end

local function gameData()
  local Game = gameObject()
  return Game and Game.data or nil
end

local function cleanName(v)
  if type(v) ~= "string" then return nil end
  local s = v:upper()
  s = s:gsub("[^A-Z0-9]", "")
  return s ~= "" and s or nil
end

local function dexNumber(v)
  if type(v) == "number" then
    local n = math.floor(v)
    if n >= 1 and n <= MAX_DEX then return n end
  elseif type(v) == "string" then
    local n = tonumber(v)
    if n then return dexNumber(n) end
  end
  return nil
end

local function speciesDex(v)
  local n = dexNumber(v)
  if n then return n end
  if type(v) ~= "string" then return nil end

  local cacheKey = cleanName(v) or v
  local cached = nameCache[cacheKey]
  if cached ~= nil then return cached or nil end

  local data = gameData()
  local pokemon = data and data.pokemon
  if not pokemon then
    nameCache[cacheKey] = false
    return nil
  end

  -- Engine species are normally canonical string keys such as "PIKACHU".
  local direct = pokemon[v] or pokemon[v:upper()]
  if direct and direct.dex then
    local d = dexNumber(direct.dex)
    nameCache[cacheKey] = d or false
    return d
  end

  -- Be forgiving for tags written as "Mr. Mime", "Nidoran-F", etc.  This
  -- runs only on a cache miss and the active game species table is small enough for a cache miss scan.
  for key, def in pairs(pokemon) do
    if cleanName(key) == cacheKey then
      local d = def and dexNumber(def.dex)
      nameCache[cacheKey] = d or false
      return d
    end
  end

  nameCache[cacheKey] = false
  return nil
end

local function firstDex(t, explicitOnly)
  if type(t) ~= "table" then return nil end
  if t.stadiumModel == false or t.pokemonModel == false then return false end

  local keys = {
    "stadiumDex", "pokemonDex", "pokedex", "dexNo", "dexNumber",
    "stadiumSpecies", "pokemonSpecies",
  }
  for _, key in ipairs(keys) do
    local d = speciesDex(t[key])
    if d then return d end
  end

  -- A nested Pokemon/battler record is unambiguous enough to accept normal
  -- `dex` / `species` field names.  At the top entity level, a generic
  -- `species` is also useful for follower/roaming mods; it is accepted only
  -- when it resolves to an actual Gen 1 Pokemon key.
  local nested = t.pokemon or t.mon or t.battler
  if type(nested) == "table" then
    local d = speciesDex(nested.pokemonDex or nested.dex or nested.species)
    if d then return d end
  elseif nested ~= nil then
    local d = speciesDex(nested)
    if d then return d end
  end

  if not explicitOnly then
    local d = speciesDex(t.species)
    if d then return d end
  end
  return nil
end

local function entityName(entity)
  if type(entity) ~= "table" then return nil end
  -- Prefer authored object names over the runtime-generated map_obj_N id.
  -- Yellow's follower, for example, is authored as PIKACHU_FOLLOWER.
  return entity.name or entity.objectName
      or (type(entity.def) == "table" and (entity.def.name or entity.def.id))
      or entity.id
end

-- Gen1Recomp Yellow creates the behind-the-player companion as an ordinary
-- NPC with def.name = PIKACHU_FOLLOWER and def.sprite = SPRITE_PIKACHU.
-- We keep that NPC for its movement/pathing, but render the CURRENT first
-- party Pokemon in its place. Reordering the party therefore changes the
-- follower immediately without touching Yellow's follower controller.
local function builtInFollowerDex(entity)
  if not Config.firstPartyFollower or type(entity) ~= "table" then return nil end
  local def = type(entity.def) == "table" and entity.def or nil
  if not def then return nil end

  local name = cleanName(def.name or entity.name or entity.objectName)

  -- The engine marks the real trailing entity with pikachuFollower=true.
  -- Fall back to its unique authored name for compatible older builds.
  -- Do NOT key only on SPRITE_PIKACHU: ordinary map Pikachu NPCs may share
  -- that sheet and must keep rendering as Pikachu rather than the party lead.
  local isPrimaryFollower = entity.pikachuFollower == true
      or name == "PIKACHUFOLLOWER"
  if not isPrimaryFollower then return nil end

  -- v0.1.52: party slot #1 is authoritative for the PRIMARY follower.
  -- Followers EX can leave _pokepcFollowerSpecies / pokepcMon metadata on the
  -- stock Yellow follower entity after a party reorder.  Reading that cached
  -- metadata first made Pikachu remain the visible lead even when another mon
  -- was moved to slot #1.  Always resolve the live party lead first here.
  -- Extra Followers EX trailer entities are resolved later by
  -- externalPokemonDex(), so their own species assignments are preserved.
  local Game = gameObject()
  local save = Game and Game.save
  local party = save and save.party
  local lead = type(party) == "table" and party[1] or nil
  local leadDex
  if type(lead) == "table" then
    -- Normal gen1recomp party mons use `species`; accept a few aliases so
    -- total-conversion / companion mods can use the same follower path.
    leadDex = speciesDex(lead.species or lead.pokemonSpecies
                      or lead.stadiumSpecies or lead.pokemonDex or lead.dex)
  else
    leadDex = speciesDex(lead)
  end
  if leadDex then return leadDex end

  -- Only if party slot #1 cannot be resolved at all, fall back to follower
  -- metadata so unusual companion mods do not lose their model entirely.
  return speciesDex(entity._pokepcFollowerSpecies
      or entity.pokepcFollowerSpecies
      or (type(entity.pokepcMon) == "table" and entity.pokepcMon.species))
end

-- Wilds of Kanto has several Pokemon entity families that do not all use the
-- same metadata shape. Normal encounter bodies expose `species`, peaceful
-- town/ambient NPCs expose `ambientSpecies`, and follower entities expose
-- `_wildsFollowerSpecies`. Resolve those explicit Pokemon-only fields before
-- falling back to generic NPC/sprite metadata so two instances of the same
-- species cannot split between 3D and 2D merely because they came from
-- different Wilds subsystems.
local function externalPokemonDex(entity)
  if type(entity) ~= "table" then return nil end

  -- These field names are Pokemon-specific and therefore safe even on a
  -- normal NPC table. Some are used by Wilds today; the aliases keep this
  -- bridge friendly with other roaming/follower mods using the same idea.
  local pokemonSpecific = {
    "ambientSpecies",
    "_wildsFollowerSpecies",
    -- Followers EX / PokePC controller identities.
    "_pokepcControlSpecies",
    "_pokepcFollowerSpecies",
    "pokepcFollowerSpecies",
    "dramaticSkyRideMountSpecies",
    "skyRideMountSpecies",
    "_stadiumSkyRideSpecies",
    "followerSpecies",
    "wildSpecies",
    "spawnSpecies",
    "encounterSpecies",
    "stadiumSpecies",
    "pokemonSpecies",
    "stadiumDex",
    "pokemonDex",
    -- Gen-2 roaming/follower providers commonly publish the National Dex as
    -- speciesId/dexId even when the human-readable species key is absent.
    -- These names are Pokemon-specific enough to accept before generic NPC
    -- metadata and prevent otherwise identical spawns splitting 3D/2D.
    "speciesId",
    "dexId",
    "nationalDex",
    "enhancedDexId",
  }
  for _, key in ipairs(pokemonSpecific) do
    local d = speciesDex(entity[key])
    if d then return d end
  end

  -- Followers EX pack trailers carry the actual party Pokemon object here.
  -- Trainer trailers intentionally have no pokepcMon and therefore remain
  -- normal 2D/voxel trainer sprites.
  if type(entity.pokepcMon) == "table" then
    local d = speciesDex(entity.pokepcMon.species
        or entity.pokepcMon.pokemonSpecies
        or entity.pokepcMon.dex)
    if d then return d end
  end

  -- Wilds ambient entities also use the authored name AMBIENT_<SPECIES>.
  -- This is a useful last-resort identity if another sprite provider has
  -- stripped the species field from the renderer/entity during a refresh.
  if entity.wildsAmbientPokemon == true then
    local raw = entity.name or entity.objectName
      or (type(entity.def) == "table" and entity.def.name)
    if type(raw) == "string" then
      local species = raw:upper():match("^AMBIENT[_%- ]+(.+)$")
      local d = species and speciesDex(species)
      if d then return d end
    end
  end

  return nil
end

local function knownPokemonEntity(entity)
  if type(entity) ~= "table" then return false end
  if entity.overworldWildSpawn == true
      or entity.wildsAmbientPokemon == true
      or entity.wildsFollower == true
      or entity.pokepcTrailer == true
      or entity._pokepcAsPokemon == true
      or entity._pokepcControlSpecies ~= nil
      or entity._pokepcFollowerSpecies ~= nil
      or entity.dramaticSkyRideMountSpecies ~= nil
      or entity.skyRideMountSpecies ~= nil
      or entity._stadiumSkyRideSpecies ~= nil
      or entity.pikachuFollower == true
      or entity.isPokemonFollower == true then
    return true
  end
  return externalPokemonDex(entity) ~= nil
end

local function overrideDex(p)
  local all = Config.overrides
  if type(all) ~= "table" then return nil end
  local map = all[p.mapId]
  if type(map) ~= "table" then return nil end
  local v = p.entityIndex and map[p.entityIndex] or nil
  if v == nil then
    local name = entityName(p.entity)
    if name ~= nil then v = map[name] end
  end
  return speciesDex(v)
end

local function spriteDex(sprite)
  if not (Config.autoSpriteSpecies and sprite and sprite.def) then return nil end
  local def = sprite.def

  -- Dramatic Sky Ride tags its generated mount sprite definition with the
  -- exact species and also names it SKY_RIDE_<SPECIES>. Treat either form as
  -- authoritative Pokemon identity so the flying mount can stay a Stadium
  -- model instead of falling back to the generated 2D follower sheet.
  local skyRideSpecies = speciesDex(def.dramaticSkyRideMountSpecies
      or def.skyRideMountSpecies)
  if skyRideSpecies then return skyRideSpecies end
  if type(def.id) == "string" then
    local skyName = def.id:upper():match("^SKY_RIDE[_%-](.+)$")
    local skyDex = skyName and speciesDex(skyName)
    if skyDex then return skyDex end
  end

  local explicit = firstDex(def, false)
  if explicit == false then return nil end
  if explicit then return explicit end

  local image = def.image
  if type(image) ~= "string" then return nil end
  if spriteCache[image] ~= nil then return spriteCache[image] or nil end

  -- Only infer from a species-specific basename.  This intentionally refuses
  -- generic sheets such as MONSTER/BIRD/BUG instead of inventing a Pokemon.
  local base = image:gsub("\\", "/"):match("([^/]+)$") or image
  base = base:gsub("%.[^%.]+$", "")
  base = base:gsub("^[Ss][Pp][Rr][Ii][Tt][Ee][_-]", "")
  -- Followers EX / PokePC sheets use follower_<SPECIES>.png.  Several flight
  -- mods temporarily leave only this sprite identity on the entity, so accept
  -- it as an explicit species-specific filename instead of falling back to 2D.
  base = base:gsub("^[Ff][Oo][Ll][Ll][Oo][Ww][Ee][Rr][_-]", "")
  base = base:gsub("^[Pp][Oo][Kk][Ee][Pp][Cc][_-]", "")
  local d = speciesDex(base)
  spriteCache[image] = d or false
  return d
end

local function resolveDex(p)
  local entity = p.entity
  local function remember(d)
    if d and type(entity) == "table" then entityDexCache[entity] = d end
    return d
  end
  -- Respect an explicit opt-out before any external compatibility aliases.
  if type(entity) == "table"
      and (entity.stadiumModel == false or entity.pokemonModel == false) then
    return nil
  end
  if entity and tagged[entity] ~= nil then
    local v = tagged[entity]
    if v == false then return nil end
    return remember(speciesDex(v))
  end

  -- Yellow's official trailing Pikachu is a special engine-created NPC, not
  -- a map object with Pokemon species metadata. Keep its pathing/visibility,
  -- but resolve its rendered species from party slot #1 every frame.
  local follower = builtInFollowerDex(entity)
  if follower then return remember(follower) end

  -- Resolve alternate roaming/follower metadata before map overrides and
  -- sprite filenames. This is what catches Wilds ambient Pokemon and its
  -- extra follower entities, which are not marked as normal wild spawns.
  local external = externalPokemonDex(entity)
  if external then return remember(external) end

  local d = overrideDex(p)
  if d then return remember(d) end

  if type(entity) == "table" then
    local top = firstDex(entity, false)
    if top == false then return nil end
    if top then return remember(top) end

    for _, key in ipairs({ "def", "obj", "object", "objDef", "data", "event" }) do
      local sub = entity[key]
      local got = firstDex(sub, true)
      if got == false then return nil end
      if got then return remember(got) end
    end
  end

  local fromSprite = spriteDex(p.sprite)
  if fromSprite then return remember(fromSprite) end

  -- Some flying/control mods replace the entity's normal Pokemon metadata for
  -- a few frames while keeping the same entity object.  Reuse the last species
  -- we positively identified rather than letting that transition turn the model
  -- back into a billboard.
  if type(entity) == "table" and entityDexCache[entity] then
    return entityDexCache[entity]
  end
  return nil
end

local function facingVector(facing)
  if facing == "up" then return 0, -1 end
  if facing == "left" then return -1, 0 end
  if facing == "right" then return 1, 0 end
  return 0, 1 -- down, nil, and unknown values use Stadium's native +Z
end

local function dtForFrame()
  local dt = 1 / 60
  if love and love.timer and love.timer.getDelta then
    local ok, got = pcall(love.timer.getDelta)
    if ok and type(got) == "number" and got >= 0 then dt = got end
  end
  -- A debugger pause should not fling animation anchors across the map.
  if dt > 0.10 then dt = 0.10 end
  return dt
end


-- Convert a canonical Pokedex height into this overworld's world-pixel scale.
-- StadiumMon:worldHeight() is intentionally battle-compressed (roughly 5..18
-- world px), so we leave StadiumMon itself untouched and apply a per-entity
-- scale multiplier here. This keeps Dramatic Shape battle sizing unchanged.
local function pokedexWorldHeight(dex)
  if not Config.pokedexScale then return nil end
  local meters = PokemonHeights and PokemonHeights.meters
                 and PokemonHeights.meters(dex) or nil
  if not (meters and meters > 0) then return nil end

  local humanMeters = tonumber(Config.humanReferenceMeters) or 1.60
  local humanWorld = tonumber(Config.humanReferenceWorldHeight) or 24
  if humanMeters <= 0 then humanMeters = 1.60 end
  if humanWorld <= 0 then humanWorld = 24 end

  local target = meters * (humanWorld / humanMeters)
  target = target * (tonumber(Config.pokedexScaleMultiplier) or 1)

  local overrides = Config.heightOverrides
  if type(overrides) == "table" then
    local mul = tonumber(overrides[dex])
    if mul and mul > 0 then target = target * mul end
  end

  local minH = tonumber(Config.minPokemonWorldHeight)
  local maxH = tonumber(Config.maxPokemonWorldHeight)
  if minH and minH > 0 and target < minH then target = minH end
  if maxH and maxH > 0 and target > maxH then target = maxH end
  return target, meters
end

local function scaleForDex(mon, dex)
  local base = mon and mon.worldHeight and mon:worldHeight() or nil

  -- Keep the restored pre-v0.1.6 Dramatic Shape sizing, but do not let very
  -- small Stadium models vanish completely inside Gen 1 tall grass. This is
  -- deliberately a ONE-WAY floor: medium/large Pokemon are never shrunk or
  -- enlarged by it, while tiny/low-profile species are brought up to a
  -- readable minimum visual height.
  if not Config.pokedexScale then
    if not (base and base > 0) then return 1, nil, nil end
    local floor = tonumber(Config.smallPokemonMinWorldHeight)
    local overrides = Config.smallPokemonMinHeightOverrides
    if type(overrides) == "table" then
      local speciesFloor = tonumber(overrides[dex])
      if speciesFloor and speciesFloor > 0 then floor = speciesFloor end
    end
    local scale = 1
    local target = base

    if floor and floor > 0 and target < floor then
      scale = floor / base
      target = floor
    end

    -- v0.1.39: give selected naturally large species more visual presence.
    -- Apply this after the small-species floor so the two systems never fight.
    local large = Config.largePokemonScaleOverrides
    if type(large) == "table" then
      local mul = tonumber(large[dex])
      if mul and mul > 1 then
        scale = scale * mul
        target = target * mul
      end
    end

    return scale, target, nil
  end

  local target, meters = pokedexWorldHeight(dex)
  if not target then return 1, base, nil end
  if not (base and base > 0) then return 1, target, meters end
  return target / base, target, meters
end

local TWO_PI = math.pi * 2

local function safeSlotAnim(mon, name)
  if not (mon and type(mon.slotAnim) == "function") then return nil end
  local ok, index = pcall(mon.slotAnim, mon, name)
  if ok and type(index) == "number" then return index end
  return nil
end

local function startWalkClip(slot, mon, dex)
  if slot.walkClip then return end
  -- `idle_alt` is the second Stadium standby loop and is the safest source
  -- skeletal motion for overworld locomotion. Some species do not have one;
  -- those use their ordinary idle plus the distance-driven footfall motion.
  local index
  if dex == 25 then
    -- Pikachu's alternate standby is too subtle to read as walking. Its Stadium
    -- STRUGGLE context provides a clearer alternating limb/body cycle; the
    -- per-species clipRate slows that motion into a quick ground-walk cadence.
    index = safeSlotAnim(mon, "struggle")
        or safeSlotAnim(mon, "idle_alt")
        or safeSlotAnim(mon, "idle")
  elseif dex == 56 then
    -- Mankey's alternate standby is too close to standing to read as a walk.
    -- Its Stadium STRUGGLE context has the useful alternating limb/body action;
    -- we loop that skeleton under the normal locomotion clock at a deliberately
    -- reduced rate (PokemonLocomotion.clipRate) so it becomes a brisk primate
    -- walk instead of looking like a battle attack.
    index = safeSlotAnim(mon, "struggle")
        or safeSlotAnim(mon, "idle_alt")
        or safeSlotAnim(mon, "idle")
  else
    index = safeSlotAnim(mon, "idle_alt") or safeSlotAnim(mon, "idle")
  end
  if index then
    local ok, played = pcall(mon.play, mon, "idle", index)
    if ok and played ~= false then
      slot.walkClip = true
      slot.walkAnim = index

      local anim = mon.model and mon.model.anims and mon.model.anims[index]
      local fps = tonumber(StadiumMon.FPS) or tonumber(StadiumPack.FPS) or 30
      local first = anim and tonumber(anim.loopStart) or 0
      if not (first and first >= 0) then first = 0 end

      -- Most species start directly on the authored loop so restarting a
      -- follower does not replay a standby flourish. Charizard is different:
      -- its idle_alt lead-in gives us useful in-between poses between the
      -- standing stance and the grounded gait. Play those frames once, eased
      -- over a short transition, then enter the normal distance-driven loop.
      local charizardBridge = dex == 6
          and Config.charizardWalkUseIntro ~= false
          and first > 0
      if charizardBridge then
        slot.walkTransition = true
        slot.walkTransitionElapsed = 0
        slot.walkTransitionFirstSec = first / fps
        slot.walkClipTime = 0
      else
        slot.walkTransition = false
        slot.walkTransitionElapsed = nil
        slot.walkTransitionFirstSec = nil
        slot.walkClipTime = first / fps
      end
      mon.time = slot.walkClipTime
    end
  end
end

local function stopWalkClip(slot, mon)
  if not slot.walkClip then return end
  pcall(mon.play, mon, "idle")
  slot.walkClip = false
  slot.walkAnim = nil
  slot.walkClipTime = nil
  slot.walkTransition = false
  slot.walkTransitionElapsed = nil
  slot.walkTransitionFirstSec = nil
end

-- Advance a gait from ACTUAL distance travelled instead of wall-clock time.
-- That keeps the feet locked to the overworld: a Pokemon that pauses freezes
-- its step instead of moonwalking, and a faster movement mod naturally makes
-- the gait advance faster. The returned bob/pitch are applied to the model
-- matrix after the Stadium skeleton is posed.
local function locomotionFor(slot, p, dex, targetHeight, dt, mon)
  local x, z = tonumber(p.px) or 0, tonumber(p.py) or 0
  -- A model that the full-3D pose guard marked static must stay on its known
  -- good bind pose.  Do not let overworld locomotion select idle_alt/struggle
  -- and accidentally reintroduce the exact broken skeletal data we rejected.
  if mon and mon.staticPose then
    stopWalkClip(slot, mon)
    slot.walkX, slot.walkZ = x, z
    slot.walkPhase, slot.walkBlend = 0, 0
    return 0, 0, false
  end
  local eligible = Config.walkingAnimations ~= false
      and PokemonLocomotion
      and PokemonLocomotion.isGroundedBiped(dex, Config.walkSpeciesOverrides)

  if slot.walkDex ~= dex then
    stopWalkClip(slot, mon)
    slot.walkDex = dex
    slot.walkX, slot.walkZ = x, z
    slot.walkPhase = 0
    slot.walkBlend = 0
  end

  local dx, dz, dist = 0, 0, 0
  if slot.walkX ~= nil and slot.walkZ ~= nil then
    dx, dz = x - slot.walkX, z - slot.walkZ
    dist = math.sqrt(dx * dx + dz * dz)
  end
  slot.walkX, slot.walkZ = x, z

  if not eligible then
    stopWalkClip(slot, mon)
    slot.walkBlend = 0
    return 0, 0, false
  end

  -- A seam/warp can move an entity dozens of pixels in one frame. That is a
  -- teleport, not a forty-step sprint, so do not feed it into the gait clock.
  local moving = dist > 0.01 and dist <= 8
  local blend = tonumber(slot.walkBlend) or 0
  local target = moving and 1 or 0
  local rate
  if dex == 6 then
    -- Give Charizard's large body time to settle into/out of the gait instead
    -- of applying the procedural bob/pitch almost instantly.
    rate = moving and 5.5 or 4.5
  else
    rate = moving and 12 or 7
  end
  local k = math.min(1, math.max(0, (dt or 0) * rate))
  blend = blend + (target - blend) * k
  if blend < 0.001 then blend = 0 end
  slot.walkBlend = blend

  if moving then
    local cycle = PokemonLocomotion.cycleDistance(
      targetHeight, dex, Config.walkCadenceMultiplier)
    if not (cycle and cycle > 0) then cycle = 18 end
    slot.walkPhase = ((tonumber(slot.walkPhase) or 0)
                     + dist / cycle * TWO_PI) % TWO_PI
    startWalkClip(slot, mon, dex)
  elseif blend <= 0.06 then
    stopWalkClip(slot, mon)
  end

  local active = slot.walkClip and blend > 0
  if active and mon and mon.model and mon.anim then
    -- Keep the Stadium skeleton near its authored speed. Older builds mapped
    -- the ENTIRE standby loop onto every short procedural gait cycle, turning
    -- a 48-84 frame clip into a fast-forward blur. The skeletal clock now
    -- advances from actual distance travelled and is capped per real frame.
    local anim = mon.model.anims and mon.model.anims[mon.anim]
    if anim and anim.frames and anim.frames > 0 then
      local fps = tonumber(StadiumMon.FPS) or tonumber(StadiumPack.FPS) or 30
      local first = tonumber(anim.loopStart) or 0
      if first < 0 or first >= anim.frames then first = 0 end
      local span = math.max(1, anim.frames - first)
      local firstSec = first / fps
      local spanSec = span / fps

      local advance = 0
      if moving then
        advance = PokemonLocomotion.clipSecondsForDistance(
          dist, dex, Config.walkCadenceMultiplier, Config.walkClipWorldSpeed)
        if type(PokemonLocomotion.clipRate) == "function" then
          advance = advance * PokemonLocomotion.clipRate(dex)
        end
        local maxRate = tonumber(Config.walkClipMaxRate) or 1.25
        if maxRate <= 0 then maxRate = 1.25 end
        local maxAdvance = math.max(0, tonumber(dt) or 0) * maxRate
        if maxAdvance > 0 and advance > maxAdvance then advance = maxAdvance end
      end

      local clipTime = tonumber(slot.walkClipTime) or firstSec

      -- Charizard gets a one-shot eased bridge through idle_alt's pre-loop
      -- frames. This is the closest equivalent to adding Blender-style
      -- in-betweens without replacing Dramatic Shape's skeleton sampler: the
      -- authored poses are sampled continuously instead of snapping directly
      -- from standing to loopStart.
      if slot.walkTransition and dex == 6 then
        local duration = tonumber(Config.charizardWalkTransitionSeconds) or 0.34
        if duration < 0.12 then duration = 0.12 end
        local elapsed = (tonumber(slot.walkTransitionElapsed) or 0)
        if moving then elapsed = elapsed + math.max(0, tonumber(dt) or 0) end
        slot.walkTransitionElapsed = elapsed

        local t = math.min(1, elapsed / duration)
        -- Smoothstep: zero acceleration at each end, so the hand-off into the
        -- looping walk does not have a visible velocity discontinuity.
        local eased = t * t * (3 - 2 * t)
        local bridgeEnd = tonumber(slot.walkTransitionFirstSec) or firstSec
        clipTime = bridgeEnd * eased

        if t >= 1 then
          slot.walkTransition = false
          slot.walkTransitionElapsed = nil
          slot.walkTransitionFirstSec = nil
          clipTime = firstSec
        end
      else
        if clipTime < firstSec then clipTime = firstSec end
        clipTime = clipTime + advance
        if spanSec > 0 and clipTime >= firstSec + spanSec then
          clipTime = firstSec + ((clipTime - firstSec) % spanSec)
        end
      end

      slot.walkClipTime = clipTime
      mon.time = clipTime
    end
  end

  if not active then return 0, 0, false end
  local phase = tonumber(slot.walkPhase) or 0
  local bob = math.abs(math.sin(phase))
      * PokemonLocomotion.bobAmount(targetHeight, dex, Config.walkBobMultiplier)
      * blend
  local pitch = math.sin(phase)
      * PokemonLocomotion.pitchAmount(dex, Config.walkPitchMultiplier)
      * blend
  return bob, pitch, true
end

local function releaseSlot(slot)
  if slot and slot.mon then pcall(slot.mon.release, slot.mon) end
end

function OverworldStadium.tag(entity, speciesOrDex)
  if type(entity) ~= "table" then return false end
  if speciesOrDex == nil then
    tagged[entity] = nil
    return true
  end
  if speciesOrDex == false then
    tagged[entity] = false
    return true
  end
  if not speciesDex(speciesOrDex) then return false end
  tagged[entity] = speciesOrDex
  return true
end

function OverworldStadium.untag(entity)
  if type(entity) ~= "table" then return false end
  tagged[entity] = nil
  return true
end

function OverworldStadium.dexFor(pose)
  return resolveDex(pose or {})
end

-- True when this entity has enough information to be rendered directly from
-- the user's Stadium pack.  In particular this does NOT require a healthy 2D
-- SpriteRenderer, which is what lets us rescue Wilds of Kanto entities that
-- its billboard adapter has put on the emergency overlay path.
function OverworldStadium.canRenderEntity(entity)
  if not modelsEnabled() then return false, nil end
  if type(entity) ~= "table" then return false end
  local dex = resolveDex({ entity = entity, sprite = entity.sprite,
                           mapId = entity.mapId })
  if not dex then return false end
  -- Lugia normally uses the real Stadium 2 pack in v0.2.22, but its
  -- procedural rescue rig remains a last-resort fallback. Keep roaming/wild
  -- claim logic permissive so Dex 249 can still render if the pack is absent.
  if tonumber(dex) == 249 then return true, dex end
  local ok, available = pcall(StadiumPack.available, dex)
  return ok and available == true, dex
end

local function wildBodyVisible(entity)
  if type(entity) ~= "table" then return false end
  if entity.hiddenEncounter or entity.visibleSprite == false
      or entity.hiddenBody == true or entity.state == "removed" then
    return false
  end
  -- Mirror Wilds' SpawnFx.bodyVisible gate closely enough that claiming its
  -- body does not make a Pokemon appear during the hidden part of spawn FX.
  local fx = entity.spawnFx
  if type(fx) == "table" and not fx.done and not fx.bodyShown then
    return false
  end
  return true
end

function OverworldStadium.claimWildEntity(entity)
  if type(entity) ~= "table" or entity.overworldWildSpawn ~= true then
    return false
  end
  if not wildBodyVisible(entity) then
    entity._stadiumOverworldWildClaim = nil
    return false
  end
  local ok, dex = OverworldStadium.canRenderEntity(entity)
  if not ok then
    entity._stadiumOverworldWildClaim = nil
    return false
  end

  -- Wilds' emergency overlay and Dramatic Shape filter key off this renderer
  -- string.  Claim the Pokemon for the depth-rendered world pass instead; its
  -- Entity:draw() then also knows not to paint a second 2D body later.
  entity._stadiumOverworldWildClaim = dex
  entity.worldRenderer = V.voxelHostId or "DRAMATIC_SHAPE"
  entity.pokemonRenderer = "NATIVE_SPRITE_RENDERER"
  entity.dramaticBillboardSkipped = false
  entity.voxelDisabled = false
  entity.voxelRegistered = true
  entity.voxelUpdateOk = true
  entity.render2DFallback = false
  return true, dex
end

function OverworldStadium.claimWilds(state)
  for _, entity in ipairs((state and state.entities) or {}) do
    if entity and entity.overworldWildSpawn == true then
      OverworldStadium.claimWildEntity(entity)
    end
  end
end

function OverworldStadium.isClaimedWild(entity)
  return type(entity) == "table" and entity._stadiumOverworldWildClaim ~= nil
end

-- Pose rescue is intentionally broader than `isClaimedWild`. Wilds ambient
-- Pokemon and follower entities are ordinary NPCs (`overworldWildSpawn=false`)
-- but can still lose their native SpriteRenderer during provider refreshes.
-- If the entity is positively identified as a Pokemon AND its Stadium model
-- exists, world position/facing are sufficient for the 3D renderer.
function OverworldStadium.canRescuePose(entity)
  if not knownPokemonEntity(entity) then return false end
  -- Do not resurrect hidden encounter bodies or the concealed phase of Wilds'
  -- spawn effect just because their 2D pose intentionally returns nil.
  if not wildBodyVisible(entity) then return false end
  local ok = OverworldStadium.canRenderEntity(entity)
  return ok == true
end

local function prepareOne(p, dex, dt)
  if not (p and p.entity and dex) then return false end

  local slot = slots[p.entity]
  if not slot then
    local okNew, mon = pcall(StadiumMon.new, "overworld")
    if not okNew or not mon then return false end
    slot = { mon = mon, lastSeen = frameNo }
    slots[p.entity] = slot
  end
  slot.lastSeen = frameNo
  local mon = slot.mon

  local okSpecies, ready = pcall(mon.setSpecies, mon, dex, true)
  if not okSpecies or not ready or not mon.rig then return false end

  -- keep() and KEEP appeared as the battle cache evolved.  Use them when
  -- present but never make an older/newer cache implementation a reason for
  -- the visible overworld model to disappear.
  if type(StadiumPack.keep) == "function" then pcall(StadiumPack.keep, dex) end

  local okScale, speciesScale, targetHeight, heightMeters =
    pcall(scaleForDex, mon, dex)
  if not okScale then
    speciesScale, targetHeight, heightMeters = 1, nil, nil
  end
  mon.scale = speciesScale or 1
  p.stadiumTargetHeight = targetHeight
  p.stadiumHeightMeters = heightMeters

  pcall(mon.update, mon, dt)
  local walkBob, walkPitch, walking = 0, 0, false
  local okWalk, wb, wp, wk = pcall(locomotionFor, slot, p, dex,
    targetHeight or (type(mon.worldHeight) == "function" and mon:worldHeight()) or 14,
    dt, mon)
  if okWalk then walkBob, walkPitch, walking = wb or 0, wp or 0, wk and true or false end

  local entity = type(p.entity) == "table" and p.entity or nil
  local skyMount = entity and entity._stadiumSkyRideMount == true

  -- Ordinary overworld Pokemon use their own pose/facing.  A Sky Ride mount is
  -- different: the Followers EX NPC is only the Pokemon ID / lifecycle owner.
  -- Its trail coordinates must NOT decide where the ridden model appears.
  -- Anchor the rendered Stadium body directly to the live rider position that
  -- main.lua publishes after Sky Ride and Followers EX finish updating.
  local renderFacing = (skyMount and entity._stadiumSkyRideAnchorFacing)
      or p.facing
  local fx, fz = facingVector(renderFacing)
  local x = ((skyMount and tonumber(entity._stadiumSkyRideAnchorPx))
      or (p.px or 0)) + 8
  local z = ((skyMount and tonumber(entity._stadiumSkyRideAnchorPy))
      or (p.py or 0)) + 8
  local y = (p.gh or 0) + (p.lift or 0) + (walkBob or 0)

  if skyMount then
    -- StadiumMon documents the same facing convention as the map: +Z is
    -- SOUTH / "down".  Older compatibility builds flipped the model 180
    -- degrees, which is why Charizard faced backwards.  No flip is needed.
    --
    -- Sky Ride exposes both absolute altitude and relative lift.  Use the
    -- mount's render-only ground/altitude rather than the follower NPC's own
    -- grounded pose.  Then lower the Pokemon's feet by a fraction of its
    -- visual height so the trainer sits on the upper back instead of at the
    -- Pokemon's feet.  This is purely a render transform; Followers EX's NPC
    -- remains untouched for landing and normal following.
    local lift = tonumber(entity._stadiumSkyRideLift) or 0
    local ground = tonumber(entity._stadiumSkyRideGround)
    if ground == nil then
      local absolute = tonumber(entity._stadiumSkyRideAltitude)
      ground = absolute and (absolute - lift) or (p.gh or 0)
    end

    local h = tonumber(targetHeight)
      or (type(mon.worldHeight) == "function" and mon:worldHeight()) or 14
    -- Approximate the saddle/back point.  Larger winged mounts need the rider
    -- near the upper half of the body, not at the model origin/feet.
    local seatFraction = 0.52
    if dex == 6 then seatFraction = 0.50       -- Charizard
    elseif dex == 18 then seatFraction = 0.58 -- Pidgeot
    elseif dex == 22 then seatFraction = 0.58 -- Fearow
    elseif dex == 42 then seatFraction = 0.50 -- Golbat
    elseif dex == 142 then seatFraction = 0.50 -- Aerodactyl
    elseif dex == 144 or dex == 145 or dex == 146 then seatFraction = 0.56
    elseif dex == 148 then seatFraction = 0.48 -- Dragonair
    elseif dex == 149 then seatFraction = 0.50 -- Dragonite
    end
    local riderFootLift = 7.0
    y = ground + lift + riderFootLift - h * seatFraction
  elseif entity and tonumber(entity._stadiumSkyRideLift) then
    -- Non-mount airborne party members keep their own X/Z trail position but
    -- follow the same vertical flight lift.
    y = y + tonumber(entity._stadiumSkyRideLift)
  end
  local okMatrix, matrix = pcall(mon.matrix, mon, x, y, z, fx, fz)
  if not okMatrix or not matrix then return false end

  if walking and walkPitch and walkPitch ~= 0 then
    local okPitch, pitched = pcall(function()
      return Mat4.mul(matrix, Mat4.rotateX(walkPitch))
    end)
    if okPitch and pitched then matrix = pitched end
  end
  mon.model_matrix = matrix

  local okBuild, didBuild = pcall(mon.build, mon)
  if not okBuild or not didBuild then return false end

  p.stadiumMon = mon
  p.stadiumMatrix = matrix
  p.stadiumDex = dex
  p.stadiumWalking = walking
  p.stadiumShadowTick = math.floor((tonumber(mon.time) or 0) * 12)
  return true
end


local function isPokemonPlayerPose(p, dex)
  if not (p and p.isPlayer) then return false end
  local e = p.entity
  if type(e) == "table" and (e._pokepcAsPokemon == true
      or e._pokepcControlSpecies ~= nil or e.pokepcControlSpecies ~= nil) then
    return dex ~= nil or externalPokemonDex(e) ~= nil
  end
  -- Dramatic Sky Ride must never turn the PLAYER pose into the Stadium mount.
  -- The existing party follower entity is used as the mount instead. This
  -- prevents the rider from becoming a duplicate Charizard/Pokemon.
  return false
end

function OverworldStadium.shouldHidePose(p)
  if not modelsEnabled() then return false end
  local e = p and p.entity
  if type(e) ~= "table" or e.skyRideRider ~= true then return false end
  local m = V.mod and V.mod.find and V.mod:find("DRAMATIC_SKY_RIDE")
  local ex = m and m.exports
  if ex and type(ex.isFlying) == "function" then
    local ok, flying = pcall(ex.isFlying)
    return ok and flying == true
  end
  return false
end

function OverworldStadium.safeShouldHidePose(p)
  local ok, hide = pcall(OverworldStadium.shouldHidePose, p)
  return ok and hide == true
end

function OverworldStadium.prepare(posed)
  if not modelsEnabled() then
    -- Clear stale model ownership immediately when the option is flipped OFF.
    -- VoxelScene will then draw each pose through its ordinary sprite/card path.
    OverworldStadium.releaseAll()
    for _, p in ipairs(posed or {}) do
      p.stadiumMon = nil
      p.stadiumMatrix = nil
      p.stadiumDex = nil
    end
    return posed
  end
  frameNo = frameNo + 1
  if not Config.enabled then return true end
  local dt = dtForFrame()

  local dexForPose = {}
  local liveDex, liveCount = {}, 0
  for i, p in ipairs(posed or {}) do
    -- Ordinary player/trainer rendering stays untouched. Followers EX can,
    -- however, turn the player entity itself into a Pokemon. In that mode its
    -- explicit _pokepcControlSpecies identity is safe to pass through Stadium.
    local okDex, dex = pcall(resolveDex, p)
    local playerPokemon = isPokemonPlayerPose(p, okDex and dex or nil)
    if (not p.isPlayer or playerPokemon) and p.entity then
      if okDex then dexForPose[i] = dex end
      if dex and not liveDex[dex] then
        local available = true
        if type(StadiumPack.available) == "function" then
          local okAvail, got = pcall(StadiumPack.available, dex)
          available = okAvail and got == true
        end
        if available then
          liveDex[dex] = true
          liveCount = liveCount + 1
        end
      end
    end
  end

  -- The stock Stadium battle cache is intentionally tiny.  Expanding it is
  -- useful in the overworld, but treat the field as optional compatibility
  -- metadata rather than an API contract.
  pcall(function()
    StadiumPack.KEEP = math.max(basePackKeep, liveCount + basePackKeep)
  end)

  for i, p in ipairs(posed or {}) do
    p.stadiumMon = nil
    p.stadiumMatrix = nil
    p.stadiumDex = nil
    p.stadiumShadowTick = nil
    p.stadiumTargetHeight = nil
    p.stadiumHeightMeters = nil
    p.stadiumWalking = nil

    local playerPokemon = isPokemonPlayerPose(p, dexForPose[i])
    if (not p.isPlayer or playerPokemon) and p.entity and dexForPose[i] then
      local dex = dexForPose[i]
      -- Keep the resolved identity even when the 3D rig deliberately rejects
      -- this species. Dedicated species fallbacks (notably Lugia) need the
      -- exact Dex number instead of falling through to an unrelated NPC card.
      p.stadiumDex = dex
      local ok, did = pcall(prepareOne, p, dex, dt)
      if not ok or not did then
        logOnce("prepare:" .. tostring(dex),
          "Stadium overworld model %d could not prepare this frame; using sprite", dex)
      end
    end
  end

  local stale = tonumber(Config.staleFrames) or 120
  for entity, slot in pairs(slots) do
    if frameNo - (slot.lastSeen or 0) > stale then
      pcall(releaseSlot, slot)
      slots[entity] = nil
    end
  end
  return true
end

-- Non-throwing entry points used by VoxelScenePatch.  The renderer itself is
-- never disabled globally because one species/model/provider had a bad frame.
function OverworldStadium.safePrepare(posed)
  -- Character Selector owns its animation state separately from Stadium
  -- Pokemon. Advance it once for this newly captured player pose before the
  -- sun/reflection/main passes consume that same pose.
  if type(OverworldStadium.preparePlayerSkinFrame) == "function" then
    for _, p in ipairs(posed or {}) do
      if p and p.isPlayer then
        pcall(OverworldStadium.preparePlayerSkinFrame, p)
      end
    end
  end
  local ok, result = pcall(OverworldStadium.prepare, posed)
  if not ok then
    logOnce("prepare-frame", "Stadium overworld prepare error: %s", tostring(result))
    return false
  end
  return result ~= false
end

function OverworldStadium.safeClaimWilds(state)
  local ok, result = pcall(OverworldStadium.claimWilds, state)
  if not ok then
    logOnce("claim-wilds", "Stadium Wilds claim error: %s", tostring(result))
    return false
  end
  return result ~= false
end

local function entityIsShiny(entity)
  if type(entity) ~= "table" then return false end
  if entity.shiny == true or entity.isShiny == true then return true end
  local mon = entity.pokemon or entity.mon or entity.partyMon
  return type(mon) == "table" and (mon.shiny == true or mon.isShiny == true)
end

local function lugiaFallbackDef(entity)
  return {
    image = entityIsShiny(entity) and LUGIA_FALLBACK_SHINY or LUGIA_FALLBACK_NORMAL,
    frames = 6, walker = true, trueColor = true,
  }
end

local function drawLugiaFallback(p)
  if not (p and p.stadiumDex == 249) then return false end

  local okVoxel, Voxel3D = pcall(V.require, "Voxel3D")
  local okCards, SpriteBillboards = pcall(V.require, "SpriteBillboards")
  local okState, VoxelState = pcall(V.require, "VoxelState")
  local okSR, SpriteRenderer = pcall(require, "src.render.SpriteRenderer")
  if not (okVoxel and type(Voxel3D) == "table"
      and okCards and type(SpriteBillboards) == "table"
      and okState and type(VoxelState) == "table"
      and okSR and type(SpriteRenderer) == "table") then
    return false
  end

  local def = lugiaFallbackDef(p.entity)
  if not lugiaFallbackRenderer or lugiaFallbackRenderer.def.image ~= def.image then
    local okNew, made = pcall(SpriteRenderer.new, def, "stadium-lugia-fallback")
    if not okNew or not made then return false end
    lugiaFallbackRenderer = made
  end

  local facing = p.facing or "down"
  local phase = tonumber(p.phase) or 0
  local flip = p.flip == true
  local geometry
  if type(lugiaFallbackRenderer.getPoseGeometry) == "function" then
    local okGeo, got = pcall(lugiaFallbackRenderer.getPoseGeometry,
      lugiaFallbackRenderer, facing, phase, flip)
    if okGeo then geometry = got end
  end
  local frame = geometry and geometry.frame or 0
  local mirror = geometry and geometry.mirror or (facing == "right")
  local mesh = SpriteBillboards.mesh(def, frame)
  if not mesh then return false end

  local okTex, tex = pcall(lugiaFallbackRenderer.resolveImage, lugiaFallbackRenderer)
  if not okTex or not tex then return false end

  local px, py = tonumber(p.px) or 0, tonumber(p.py) or 0
  local y = (tonumber(p.gh) or 0) + (tonumber(p.lift) or 0)
  local b = type(FirstPerson.cardBlend) == "function" and FirstPerson.cardBlend() or 0
  local m = Mat4.translate(px + 8, y, py + 8)
  if b > 0 and type(FirstPerson.cardYaw) == "function" then
    m = Mat4.mul(m, Mat4.rotateY(FirstPerson.cardYaw(px + 8, py + 8) * b))
  end
  local angle = tonumber(VoxelState.angle) or (math.pi / 2)
  m = Mat4.mul(m, Mat4.rotateX((angle - math.pi / 2) * (1 - b)))
  m = Mat4.mul(m, Mat4.scale(LUGIA_FALLBACK_SCALE, LUGIA_FALLBACK_SCALE, LUGIA_FALLBACK_SCALE))
  if mirror then m = Mat4.mul(m, Mat4.scale(-1, 1, 1)) end
  m = Mat4.mul(m, Mat4.translate(-8, 0, 0))

  -- Stadium effect renderers can leave additive/no-depth-write state active.
  -- Explicitly restore solid alpha/depth state so Lugia cannot inherit a
  -- translucent pass. The sprite shader still discards only the transparent
  -- background pixels.
  if type(Voxel3D.blend) == "function" then pcall(Voxel3D.blend, nil) end
  if love and love.graphics and love.graphics.setColor then
    pcall(love.graphics.setColor, 1, 1, 1, 1)
  end
  local okDraw = pcall(Voxel3D.draw, mesh, tex, m, nil)
  return okDraw
end

local function withFreeVisualWalk(p, fn)
  if not (p and type(p.entity) == "table" and type(fn) == "function") then
    return false, nil
  end
  -- A live battle owns the trainer pose and explicitly pins it to terrain.
  -- Do not let the free-roam visual-walk bridge re-enable a walking/bobbing
  -- animation on that static battle stand point.
  if p.stadiumBattleGrounded == true then return pcall(fn) end
  -- Prefer the animation bit captured with this exact VoxelScene pose.  This
  -- is frame-local and cannot be stale across boot/map transitions.  Keep the
  -- live-world lookup only as a compatibility fallback for older callers that
  -- construct a player pose without VoxelScene.
  local visual = p.stadiumVisualMoving == true
  if not visual and p.stadiumVisualMoving == nil then
    local world = liveGoldWorld()
    visual = type(world) == "table"
      and world._stadiumFreeMoveActive == true
      and world._stadiumFreeVisualMoving == true
  end
  if not visual then return pcall(fn) end

  -- Visual-only bridge: true camera-relative free movement advances px/py and
  -- animClock without owning Gold's grid-step Player.moving flag. Temporarily
  -- expose a walking pose ONLY while the external 3D skin is being rendered,
  -- then restore every gameplay field immediately.
  local entity = p.entity
  local oldMoving, oldPhase, oldFlip = entity.moving, p.phase, p.flip
  entity.moving = true
  -- Use the same alternating 16-tick cadence as Gold's Player:pose(). A
  -- constant walk frame still looks like a frozen model sliding over terrain.
  local clock = tonumber(entity.animClock) or 0
  local cycle = clock % 16
  p.phase = tonumber(p.stadiumVisualPhase)
    or ((cycle >= 4 and cycle < 12) and 1 or 0)
  if p.stadiumVisualFlip ~= nil then
    p.flip = p.stadiumVisualFlip == true
  else
    p.flip = math.floor(clock / 16) % 2 == 1
  end
  local ok, result = pcall(fn)
  entity.moving, p.phase, p.flip = oldMoving, oldPhase, oldFlip
  return ok, result
end

-- Current Character Selector renderers separate animation advancement from
-- drawVoxel(). VASC4J replaces the selector's ordinary VoxelScene hook, so
-- call the feature-detected preparation seam once per captured pose. The pose
-- marker prevents reflection/main reuse from advancing the animation twice.
function OverworldStadium.preparePlayerSkinFrame(p)
  if not (p and type(p.entity) == "table") then return false end
  if p._red3dFramePrepared == true then return true end
  local renderer = red3dRendererForPose(p)
  if not renderer then return false end
  p._red3dFramePrepared = true
  if type(renderer.beginVoxelFrame) ~= "function" then return true end
  local ok, result = withFreeVisualWalk(p, function()
    return renderer:beginVoxelFrame(p.entity, p)
  end)
  if not ok then
    logOnce("red3d-frame",
      "3D Character Selector animation preparation failed; preserving its last safe pose: %s",
      tostring(result))
    return false
  end
  return result ~= false
end

function OverworldStadium.draw(p)
  if not modelsEnabled() then return false end
  if p and p.stadiumDex == 249 and not (p.stadiumMon and p.stadiumMon.rig) then
    return drawLugiaFallback(p)
  end
  local mon = p and p.stadiumMon
  local matrix = p and p.stadiumMatrix
  if not (mon and mon.rig and matrix) then return false end
  local ok, result = pcall(mon.rig.draw, mon.rig, matrix, nil)
  if not ok then
    logOnce("draw:" .. tostring(p.stadiumDex),
      "Stadium overworld draw failed for dex %s; using sprite", tostring(p.stadiumDex))
    return false
  end
  return result ~= false
end

function OverworldStadium.safeDraw(p)
  local ok, result = pcall(OverworldStadium.draw, p)
  return ok and result == true
end

-- Draw the 3D Character Selector's CURRENT Gold skin inside this standalone
-- voxel scene.  This deliberately calls the selector's own drawVoxel method
-- rather than copying any character/model logic, so all built-in, imported,
-- renamed, scaled, accessory-equipped, and future skins remain selector-owned.
function OverworldStadium.drawPlayerSkin(p)
  if not playerModelsEnabled() then return false end
  local renderer = red3dRendererForPose(p)
  if not renderer then return false end
  OverworldStadium.preparePlayerSkinFrame(p)

  local okVoxel, Voxel3D = pcall(V.require, "Voxel3D")
  local okFP, FirstPerson = pcall(V.require, "FirstPerson")
  if not okVoxel or type(Voxel3D) ~= "table" or not okFP or type(FirstPerson) ~= "table" then
    return false
  end

  local ok, result = withFreeVisualWalk(p, function()
    return renderer:drawVoxel(p.entity, p, Voxel3D, Mat4, FirstPerson)
  end)
  if not ok then
    logOnce("red3d-draw",
      "3D Character Selector player draw failed in Gold voxel mode; using the stock trainer card: %s",
      tostring(result))
    return false
  end
  if result == true then
    p.red3dPlayerSkin = true
    return true
  end
  return false
end

function OverworldStadium.safeDrawPlayerSkin(p)
  local ok, result = pcall(OverworldStadium.drawPlayerSkin, p)
  if not ok then
    logOnce("red3d-draw-bridge",
      "3D Character Selector compatibility bridge failed; using the stock trainer card: %s",
      tostring(result))
    return false
  end
  return result == true
end

-- The Character Selector has first refusal for the Gold player.  If it is not
-- installed or deliberately declines a frame, VoxelScene falls back to its
-- ordinary sprite card.  Normal overworld cards lean with the diorama camera;
-- that same transform makes the displaced live-battle trainer look flat or
-- clip through the ground.  Scope the upright override to the captured battle
-- pose and restore it even when the base renderer throws, so the outer
-- VoxelScene transaction can still retry its untouched native implementation.
function OverworldStadium.drawStockPlayerCard(p, scene, drawEntity, facing)
  if type(p) ~= "table" or type(drawEntity) ~= "function" then return false end
  local upright = p.isPlayer == true and p.stadiumBattleGrounded == true
    and type(scene) == "table"
  local oldLean
  if upright then
    oldLean = scene.spriteLean
    scene.spriteLean = math.pi / 2
  end
  local ok, result = pcall(drawEntity,
    p.sprite, p.px, p.py, facing or p.facing, p.phase, p.flip, p.gh,
    p.colors, p.lift)
  if upright then scene.spriteLean = oldLean end
  if not ok then error(result, 0) end
  return result
end

-- Best-effort real mesh shadow.  The base Dramatic Shape card shadow remains a
-- harmless fallback if this seam is unavailable in a host revision.
function OverworldStadium.castPlayerSkin(p, shadowMap)
  local renderer = red3dRendererForPose(p)
  if not renderer or type(renderer.drawVoxelShadow) ~= "function" then return false end
  OverworldStadium.preparePlayerSkinFrame(p)
  local okVoxel, Voxel3D = pcall(V.require, "Voxel3D")
  local okFP, FirstPerson = pcall(V.require, "FirstPerson")
  if not okVoxel or type(Voxel3D) ~= "table" or not okFP or type(FirstPerson) ~= "table" then
    return false
  end
  local ok, result = withFreeVisualWalk(p, function()
    return renderer:drawVoxelShadow(p.entity, p, Voxel3D, Mat4, shadowMap, FirstPerson)
  end)
  if not ok then
    logOnce("red3d-shadow",
      "3D Character Selector player shadow failed in Gold voxel mode: %s", tostring(result))
    return false
  end
  return result == true
end

function OverworldStadium.safeCastPlayerSkin(p, shadowMap)
  local ok, result = pcall(OverworldStadium.castPlayerSkin, p, shadowMap)
  return ok and result == true
end

function OverworldStadium.playerSkinActive(p)
  return red3dRendererForPose(p) ~= nil
end

function OverworldStadium.safePlayerSkinActive(p)
  local ok, result = pcall(OverworldStadium.playerSkinActive, p)
  return ok and result == true
end

function OverworldStadium.cast(p, shadowMap)
  if not modelsEnabled() then return false end
  local mon = p and p.stadiumMon
  local matrix = p and p.stadiumMatrix
  if not (mon and mon.rig and matrix and shadowMap) then return false end
  local ok, result = pcall(mon.rig.caster, mon.rig, shadowMap, matrix)
  return ok and result ~= false
end

function OverworldStadium.safeCast(p, shadowMap)
  local ok, result = pcall(OverworldStadium.cast, p, shadowMap)
  return ok and result == true
end

function OverworldStadium.releaseAll()
  for entity, slot in pairs(slots) do
    releaseSlot(slot)
    slots[entity] = nil
  end
end

OverworldStadium.MAX_DEX = MAX_DEX

return OverworldStadium
