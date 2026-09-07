-- Optional collision policy for existing overworld Pokemon.
--
-- This module never creates entities and never changes people, trainers,
-- events, grass encounters or map collision. PASSABLE is the only mode that
-- owns an entity field, and every captured value is restored exactly when
-- that mode ends. SOFT never moves or changes an owner-managed entity: it may
-- only accept an explicit, attempt-scoped yield result from that owner.

local PokemonCollision = {}
PokemonCollision.__index = PokemonCollision
PokemonCollision.SCHEMA = "ascendant.pokemon-collision/v1"

local function optionValue(mod, key, fallback)
  local options = mod and mod.options
  if not (options and type(options.get) == "function") then return fallback end
  local ok, value = pcall(options.get, options, key)
  if not ok or value == nil then return fallback end
  return tostring(value)
end

local function worldFor(game)
  return game and (game.overworld or game.world) or nil
end

local function context(entity)
  if type(entity) ~= "table" then return nil end
  local marked = entity.ascendantPokemonSpriteContext
  if marked == "grass" or marked == "wilds_grass" then return nil end
  if marked == "follower" or marked == "city" or marked == "wilds_town" then
    return marked
  end
  if entity.isPokemonFollower == true or entity.pikachuFollower == true
      or entity.pokepcTrailer == true or entity.wildsFollower == true
      or entity._ascendantPokemonOverworld == true
      or entity._ascendantNativeFollower == true or entity.followerMon ~= nil
      or entity.followerSpecies ~= nil
      or entity._pokepcFollowerSpecies ~= nil
      or entity.pokepcFollowerSpecies ~= nil
      or entity._wildsFollowerSpecies ~= nil
      or entity.pokepcMon ~= nil then return "follower" end
  if entity.wildsAmbientPokemon == true or entity.ambientSpecies ~= nil then
    return "wilds_town"
  end
  -- Explicit species metadata is required for ordinary city/indoor actors.
  -- Never infer Pokemon from a generic sprite name: that could make a trainer
  -- or story actor passable.
  if entity.pokemonDex ~= nil or entity.enhancedDexId ~= nil
      or entity.stadiumDex ~= nil or entity.nationalDex ~= nil
      or entity.pokemonSpecies ~= nil then return "city" end
  return nil
end

local function ownerProtected(entity)
  -- These owners remove bodies overlapping the player even if passable=true.
  -- Preserve their occupancy contract until they expose safe passage; never
  -- disable their story-cell protection or counterfeit private owner flags.
  return entity.wildsAmbientPokemon == true
    or entity.overworldWildSpawn == true
    or entity._owwildEntity == true
    or entity._kantoAscendantWildsSafetyNpc == true
end

local function atCell(entity, x, y)
  return entity.cellX == x and entity.cellY == y
    or entity.moving == true and entity.targetX == x and entity.targetY == y
end

function PokemonCollision.new(options)
  return setmetatable({
    mod=assert(options.mod), debugLog=options.debugLog,
    generation=options.generation, nativeFollower=options.nativeFollower,
    activeGame=nil, installed=false,
    originals=setmetatable({}, { __mode="k" }),
    touched=setmetatable({}, { __mode="k" }),
    softState=nil, softPasses=0,
  }, PokemonCollision)
end

function PokemonCollision:_protected(entity, game)
  if ownerProtected(entity) then return true end
  local world = worldFor(game or self.activeGame)
  if self.generation == 1 and entity.pikachuFollower and world then
    -- Original Yellow story/counter hops own this actor, even in PASSABLE.
    if world.pikaHop or world.pikachuBillsScene or world.pikachuFanClubScene
        or world.pikachuPewterSleepScene then return true end
  end
  return false
end

function PokemonCollision:mode()
  local mode = optionValue(self.mod, "pokemon_collision_mode", "normal")
  if mode ~= "soft" and mode ~= "passable" then return "normal" end
  return mode
end

function PokemonCollision:_entities(game)
  local world = worldFor(game or self.activeGame)
  local list, seen = {}, {}
  for _, bucket in ipairs({ world and world.npcs, world and world.entities,
      world and world.objects }) do
    if type(bucket) == "table" then
      for _, entity in pairs(bucket) do
        if type(entity) == "table" and not seen[entity] then
          seen[entity] = true
          if context(entity) then list[#list + 1] = entity end
        end
      end
    end
  end
  return list
end

function PokemonCollision:_remember(entity)
  if self.originals[entity] == nil then
    self.originals[entity] = { value=entity.passable, captured=true }
  end
  self.touched[entity] = true
end

function PokemonCollision:_restore(entity)
  local original = self.originals[entity]
  if original and original.captured then entity.passable = original.value end
  self.originals[entity], self.touched[entity] = nil, nil
end

function PokemonCollision:_resetSoft()
  self.softState = nil
end

local function mapIdentity(map)
  if type(map) ~= "table" then return map end
  return map.id or map.name or map
end

function PokemonCollision:apply(game)
  if game then self.activeGame = game end
  local mode, current = self:mode(), {}
  -- Only PASSABLE owns passable. SOFT and NORMAL neither capture nor refresh
  -- this field; they only finish a previous PASSABLE transaction once.
  if mode == "passable" then
    for _, entity in ipairs(self:_entities(self.activeGame)) do
      if self:_protected(entity) then
        self:_logCollision("owner-protected", entity, nil,
          { state="original-owner-collision", api="unavailable" })
      else
        current[entity] = true
        self:_remember(entity)
        entity.passable = true
      end
    end
  end
  for entity in pairs(self.touched) do
    if mode ~= "passable" or not current[entity] then self:_restore(entity) end
  end

  if mode ~= "soft" then
    self:_resetSoft()
  elseif self.softState then
    local world = worldFor(self.activeGame)
    local map = world and world.map
    if self.softState.world ~= world or self.softState.map ~= map
        or self.softState.mapId ~= mapIdentity(map) then
      self:_resetSoft()
    end
  end
  return true
end

function PokemonCollision:_installNativePassable()
  if self.generation ~= 1 then return false end
  local api = self.nativeFollower
  if not api then
    local ok, value = pcall(require, "src.world.PikachuFollower")
    if ok then api = value end
  end
  if type(api) ~= "table" or type(api.update) ~= "function" then return false end
  local key = "_ascendantPokemonCollisionPassage"
  local previous = rawget(api, key)
  if previous and type(previous.restore) == "function" then previous.restore() end
  local original, policy = api.update, self
  local function packed(...) return {n=select("#", ...), ...} end
  local function wrapped(game, world, ...)
    local result = packed(original(game, world, ...))
    -- The native update owns the turn counter and can reassert false on every
    -- frame. Apply only the user's PASSABLE choice after it, to the exact native
    -- follower. Do not reset counters, move actors or interfere with SOFT.
    if world and world == worldFor(game) and not world.pikaHop then
      policy.activeGame = game
      for _, npc in ipairs(world.npcs or {}) do
        if npc.pikachuFollower then
          -- The owner just supplied the authoritative value. Discard our old
          -- snapshot instead of restoring it over that fresh native decision.
          policy.originals[npc], policy.touched[npc] = nil, nil
          if policy:mode() == "passable" and not policy:_protected(npc, game) then
            policy:_remember(npc)
            npc.passable = true
          end
          break
        end
      end
    end
    return unpack(result, 1, result.n)
  end
  local bridge = {}
  function bridge.restore()
    policy:restore()
    if api.update == wrapped then api.update = original end
    if rawget(api, key) == bridge then api[key] = nil end
  end
  api.update, api[key], self.nativeBridge = wrapped, bridge, bridge
  return true
end

function PokemonCollision:_target(ctx)
  if type(ctx) ~= "table" then return nil end
  local x, y = tonumber(ctx.toX), tonumber(ctx.toY)
  if x == nil or y == nil then return nil end
  for _, entity in ipairs(self:_entities(self.activeGame)) do
    if atCell(entity, x, y) then return entity end
  end
  return nil
end

local function sameSoftContact(a, b)
  return a and b
    and a.world == b.world and a.map == b.map and a.mapId == b.mapId
    and a.mover == b.mover and a.entity == b.entity
    and a.fromX == b.fromX and a.fromY == b.fromY
    and a.toX == b.toX and a.toY == b.toY
end

local function collisionRateKey(decision, entity, ctx)
  return table.concat({
    tostring(decision), tostring(context(entity)),
    tostring(ctx and ctx.fromX), tostring(ctx and ctx.fromY),
    tostring(ctx and ctx.toX), tostring(ctx and ctx.toY),
  }, ":")
end

function PokemonCollision:_logCollision(decision, entity, ctx, details)
  local log = self.debugLog
  if not (log and type(log.event) == "function") then return false end
  details = details or {}
  local reason = ctx and ctx.reason
  if reason == nil and decision == "passable" then
    reason = "pokemon_passable_mode"
  end
  local data = {
    source="pokemon_collision", hook="movement.collision",
    entity=entity, ctx=ctx, context=context(entity),
    mode=self:mode(), reason=reason, decision=decision,
    state=details.state, api=details.api,
    allowed=decision == "passable" or decision == "owner-yield",
    rateKey=collisionRateKey(decision, entity, ctx),
  }
  local ok, emitted = pcall(log.event, log, "COLLISION", data,
    self.activeGame)
  return ok and emitted == true
end

function PokemonCollision:_softContact(world, entity, ctx)
  local map = ctx.map or world.map
  return {
    world=world, map=map, mapId=mapIdentity(map), mover=ctx.mover,
    entity=entity, fromX=ctx.fromX, fromY=ctx.fromY,
    toX=ctx.toX, toY=ctx.toY, attemptId=ctx.attemptId,
  }
end

function PokemonCollision:_ownerYield(ctx, contact)
  -- The movement owner may attach this narrow callback to a canonical
  -- movement.collision context. Returning true promises that the owner has
  -- atomically made this exact attempt safe (including its own queues,
  -- occupancy and protected-cell rules). APO never performs that mutation.
  if type(ctx.ownerYield) ~= "function" then return false, "unavailable" end
  local request = {
    schema="ascendant.pokemon-owner-yield/v1",
    world=contact.world, map=contact.map, mover=contact.mover,
    entity=contact.entity, fromX=contact.fromX, fromY=contact.fromY,
    toX=contact.toX, toY=contact.toY, dir=ctx.dir,
    attemptId=contact.attemptId,
  }
  local ok, yielded = pcall(ctx.ownerYield, request)
  if not ok then return false, "error" end
  if yielded ~= true then return false, "rejected" end
  return true, "accepted"
end

function PokemonCollision:collision(nextFn, allowed, ctx)
  local base = nextFn(allowed, ctx)
  local mode = self:mode()
  if mode ~= "soft" then
    self:_resetSoft()
    local world = worldFor(self.activeGame)
    if type(ctx) == "table" and world and ctx.mover == world.player
        and (ctx.map == nil or world.map == nil or ctx.map == world.map) then
      local entity = self:_target(ctx)
      if entity then
        if mode == "passable" and ownerProtected(entity) then
          self:_logCollision("owner-protected", entity, ctx,
            { state="original-owner-collision", api="unavailable" })
        elseif mode == "passable" and base ~= false then
          self:_logCollision("passable", entity, ctx,
            { state="passable-mode" })
        elseif base == false and ctx.reason == "entity" then
          self:_logCollision("block", entity, ctx,
            { state="owner-collision" })
        end
      end
    end
    return base
  end

  local world = worldFor(self.activeGame)
  -- Entity-vs-entity probes must neither arm nor consume the player's soft
  -- contact. APO only has authority over the active player's request.
  if type(ctx) ~= "table" or not world or ctx.mover ~= world.player then
    return base
  end
  if base ~= false or ctx.reason ~= "entity" then
    self:_resetSoft()
    return base
  end
  if ctx.map ~= nil and world.map ~= nil and ctx.map ~= world.map then
    self:_resetSoft()
    return base
  end

  local entity = self:_target(ctx)
  if not entity then
    self:_resetSoft()
    return base
  end

  local contact = self:_softContact(world, entity, ctx)
  local previous = self.softState
  self.softState = contact

  -- Continuous controllers may probe both axes more than once per frame. A
  -- repeated bump is therefore meaningful only when the movement owner gives
  -- both calls explicit and different attempt ids. Without that contract (or
  -- without an owner yield callback), SOFT deliberately fails closed.
  local sameContact = sameSoftContact(previous, contact)
  if not sameContact then
    self:_logCollision("block", entity, ctx, { state="first-contact" })
    return base
  end
  if previous.attemptId == nil or contact.attemptId == nil then
    self:_logCollision("fail-closed", entity, ctx,
      { state="attempt-id-required", api="unavailable" })
    return base
  end
  if previous.attemptId == contact.attemptId then
    self:_logCollision("block", entity, ctx, { state="same-attempt" })
    return base
  end

  local yielded, ownerStatus = self:_ownerYield(ctx, contact)
  if yielded then
    self:_resetSoft()
    self.softPasses = self.softPasses + 1
    self:_logCollision("owner-yield", entity, ctx,
      { state="owner-accepted", api=ownerStatus })
    return true
  end
  self:_logCollision("fail-closed", entity, ctx,
    { state="owner-not-accepted", api=ownerStatus })
  return base
end

function PokemonCollision:restore()
  for entity in pairs(self.touched) do self:_restore(entity) end
  self:_resetSoft()
  return true
end

function PokemonCollision:install()
  if self.installed then return true end
  self.installed = true
  self:_installNativePassable()
  local policy = self
  if self.mod.hooks and type(self.mod.hooks.wrap) == "function" then
    self.mod.hooks:wrap("movement.collision", function(nextFn, allowed, ctx)
      return policy:collision(nextFn, allowed, ctx)
    end, 850000)
  end
  if self.mod.events and type(self.mod.events.on) == "function" then
    for _, event in ipairs({ "game.ready", "save.loaded", "map.entered",
        "map.reloaded" }) do
      self.mod.events:on(event, function(ev)
        policy:_resetSoft()
        policy:apply(ev and ev.game or policy.activeGame)
      end)
    end
    self.mod.events:on("world.stepped", function(ev)
      policy:apply(ev and ev.game or policy.activeGame)
    end)
    self.mod.events:on("mod.options_changed", function(ev)
      if not ev or not ev.mod or ev.mod == policy.mod.id then
        policy:_resetSoft()
        policy:apply(policy.activeGame)
      end
    end)
  end
  return true
end

function PokemonCollision:health()
  local count = 0
  for _ in pairs(self.touched) do count = count + 1 end
  local requested = self:mode()
  return { schema=PokemonCollision.SCHEMA, ok=self.installed,
    mode=requested, requestedMode=requested,
    effectiveBehavior=requested == "soft" and "solid/fail-closed"
      or requested == "passable" and "passable-compatible-actors-only" or "original-owner",
    reason=requested == "soft" and "owner_yield_unavailable" or nil,
    supportedModes={"normal", "passable"},
    protectedAmbientBehavior="original-owner",
    nativeFollowerPassableScope=self.nativeBridge and "gen1-native-follower-excluding-story-hop" or nil,
    ownerYieldScope="explicit-compatible-attempt-only-no-global-capability",
    pokemonCount=count, softPasses=self.softPasses,
    nativeFollowerPassableBridge=self.nativeBridge ~= nil }
end

function PokemonCollision:public()
  local policy = self
  return { schema=PokemonCollision.SCHEMA,
    mode=function() return policy:mode() end,
    refresh=function(game) return policy:apply(game) end,
    restore=function() return policy:restore() end,
    health=function() return policy:health() end }
end

PokemonCollision.context = context
return PokemonCollision
