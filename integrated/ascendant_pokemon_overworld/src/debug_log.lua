local DebugLog = {}
DebugLog.__index = DebugLog

DebugLog.EVENT_INTERVALS = {
  COLLISION = 0.5,
  SOURCE = 2,
  ANIMATION = 2,
}

local EVENT_KINDS = {
  COLLISION = true,
  SOURCE = true,
  ANIMATION = true,
}

local EXTRA_FIELDS = {
  "source", "provider", "palette", "animation", "clip", "state", "phase", "style",
  "context", "reason", "mode", "hook", "api", "fromX", "fromY",
  "toX", "toY", "candidateX", "candidateY", "frame", "allowed",
}

local function identity(player)
  local def = player and player.sprite and player.sprite.def or {}
  return tostring(def.ascendantRole or def.id
    or player and player.ascendantCharacter or "nil")
end

local function first(...)
  for index = 1, select("#", ...) do
    local value = select(index, ...)
    if value ~= nil then return value end
  end
  return nil
end

local function clockNow()
  if love and love.timer and type(love.timer.getTime) == "function" then
    local ok, value = pcall(love.timer.getTime)
    if ok and type(value) == "number" then return value end
  end
  if os and type(os.clock) == "function" then return os.clock() end
  return 0
end

local function clean(value)
  if value == nil then return "nil" end
  if type(value) == "table" then
    value = first(value.id, value.kind, value.name, value.state, "table")
  end
  local text = tostring(value)
  text = text:gsub("\\", "\\\\"):gsub("\r", "\\r")
    :gsub("\n", "\\n"):gsub("\t", "\\t")
  if #text > 240 then text = text:sub(1, 237) .. "..." end
  return text
end

local function normalizeEdition(value, generation)
  local edition = tostring(value or ""):lower()
  edition = edition:gsub("[^a-z0-9]+", "-"):gsub("^-+", "")
    :gsub("-+$", "")
  if edition == "" then edition = generation == 2 and "gen2" or "gen1" end
  return edition
end

local function editionFor(game, generation, hint)
  local save = game and game.save or {}
  return normalizeEdition(first(hint, save.version), generation)
end

local function worldFor(game)
  return game and (game.overworld or game.world) or nil
end

local function mapIdFor(data, game)
  local world = worldFor(game)
  local ctx = type(data.ctx) == "table" and data.ctx or nil
  local value = first(data.mapId, data.map, ctx and ctx.map,
    world and world.map, world and world.mapId)
  if type(value) == "table" then
    value = first(value.id, value.mapId, value.name)
  end
  return value
end

local function entityFields(data)
  local ctx = type(data.ctx) == "table" and data.ctx or nil
  local entity = type(data.entity) == "table" and data.entity
    or type(data.target) == "table" and data.target
    or ctx and type(ctx.entity) == "table" and ctx.entity or nil
  local nested = entity and (entity.mon or entity.pokemon) or nil
  local def = entity and (entity.sprite and entity.sprite.def
    or entity.spriteDef or type(entity.def) == "table" and entity.def) or nil
  local entityId = first(data.entityId, data.actorId,
    entity and entity.id, entity and entity.entityId,
    entity and entity.uid, entity and entity.spawnId,
    entity and entity.token, def and def.id)
  local species = first(data.species, data.pokemonSpecies,
    entity and entity.pokemonSpecies, entity and entity.species,
    entity and entity.followerSpecies, entity and entity.ambientSpecies,
    entity and entity.wildSpecies, nested and nested.species,
    def and (def.pokemonSpecies or def.species))
  local owner = first(data.owner, data.entityOwner,
    entity and entity.ascendantPokemonOwner,
    entity and entity.ownerId, entity and entity.providerMod,
    entity and entity.providerId, def and def.providerMod,
    def and def.providerId, def and def.owner,
    entity and (entity.overworldWildSpawn == true
      or entity._owwildEntity == true) and "overworld_wild_spawns",
    entity and entity._ascendantPokemonOverworld == true
      and "ascendant_pokemon_overworld")
  return entityId, species, owner
end

local function playerFields(data, game)
  local world = worldFor(game)
  local ctx = type(data.ctx) == "table" and data.ctx or nil
  local position = type(data.playerPosition) == "table"
    and data.playerPosition or nil
  local player = type(data.player) == "table" and data.player
    or ctx and type(ctx.mover) == "table" and ctx.mover
    or world and world.player or nil
  local x = first(data.playerX, data.playerCellX,
    position and first(position.cellX, position.x),
    player and first(player.cellX, player.x))
  local y = first(data.playerY, data.playerCellY,
    position and first(position.cellY, position.y),
    player and first(player.cellY, player.y))
  return x, y
end

local function detail(data, key)
  if data[key] ~= nil then return data[key] end
  local ctx = type(data.ctx) == "table" and data.ctx or nil
  return ctx and ctx[key] or nil
end

local function decisionFor(data)
  local decision = first(data.decision, data.result)
  if decision == nil and data.allowed ~= nil then
    decision = data.allowed == true and "allow" or "block"
  end
  if decision == nil and data.blocked ~= nil then
    decision = data.blocked == true and "block" or "allow"
  end
  return first(decision, data.action)
end

local function eventRecord(kind, data, game)
  local mapId = mapIdFor(data, game)
  local entityId, species, owner = entityFields(data)
  local playerX, playerY = playerFields(data, game)
  local decision = decisionFor(data)
  local fields = {
    "map=" .. clean(mapId),
    "entityId=" .. clean(entityId),
    "species=" .. clean(species),
    "owner=" .. clean(owner),
    "playerX=" .. clean(playerX),
    "playerY=" .. clean(playerY),
    "decision=" .. clean(decision),
  }
  for _, key in ipairs(EXTRA_FIELDS) do
    local value = detail(data, key)
    if value ~= nil then
      fields[#fields + 1] = key .. "=" .. clean(value)
    end
  end
  local message = table.concat(fields, " ")
  local bucket = table.concat({ kind, clean(mapId), clean(entityId),
    clean(species), clean(owner), clean(decision), clean(data.source),
    clean(data.provider), clean(data.animation), clean(data.clip),
    clean(data.state), clean(detail(data, "style")), clean(data.context), clean(detail(data, "reason")),
    clean(data.mode), clean(first(data.rateKey, data.key)) }, "|")
  return message, bucket
end

function DebugLog.new(mod, generation, options)
  options = options or {}
  local stamp = os.date("%Y%m%d-%H%M%S")
  local nonce = math.floor((os.clock() % 1) * 1000000)
  return setmetatable({ mod=mod, generation=generation, last={}, recent={},
    session=("%s-%06d"):format(stamp, nonce), files={}, writeErrors={},
    warnedWriteErrors={},
    eventLast={}, clock=options.clock or clockNow,
    eventStats={ emitted=0, deduplicated=0, rateLimited=0 } }, DebugLog)
end

function DebugLog:_write(edition, line)
  if not (love and love.filesystem) then
    return false, "love_filesystem_unavailable"
  end
  local directory = "ascendant-pokemon-overworld-logs"
  love.filesystem.createDirectory(directory)
  local relative = self.files[edition]
  if not relative then
    relative = ("%s/%s-%s.log"):format(directory, edition, self.session)
    self.files[edition] = relative
    local header = ("[AscendantPokemonOverworld][SESSION] session=%s edition=%s gen=%s\n")
      :format(self.session, edition, tostring(self.generation))
    local ok, err = love.filesystem.write(relative, header)
    if not ok then self.writeErrors[edition] = tostring(err); return false, err end
    if self.mod.log then
      local base = type(love.filesystem.getSaveDirectory) == "function"
        and love.filesystem.getSaveDirectory() or "<LOVE-save>"
      self.mod.log:info("[AscendantPokemonOverworld][LOG] file=%s/%s",
        tostring(base), relative)
    end
  end
  local ok, err = love.filesystem.append(relative, line .. "\n")
  if not ok then self.writeErrors[edition] = tostring(err) end
  return ok, err
end

function DebugLog:_record(kind, message, game, editionHint, recent)
  self.recent[#self.recent + 1] = recent or "[" .. kind .. "] " .. message
  if #self.recent > 80 then table.remove(self.recent, 1) end
  local edition = editionFor(game, self.generation, editionHint)
  local line = "[AscendantPokemonOverworld][" .. kind .. "] " .. message
  local ok, err = self:_write(edition, line)
  if self.mod.log then
    self.mod.log:info("%s", line)
    local writeError = tostring(err)
    if not ok and self.warnedWriteErrors[edition] ~= writeError then
      self.warnedWriteErrors[edition] = writeError
      self.mod.log:warn("[AscendantPokemonOverworld][LOG] write failed: %s",
        writeError)
    end
  end
  return true
end

function DebugLog:_emit(key, message, game)
  if self.last[key] == message then return false end
  self.last[key] = message
  return self:_record("IDENTITY", message, game, nil, message)
end

function DebugLog:role(source, role, game, player)
  local save = game and game.save or {}
  local owner = save.player or {}
  return self:_emit("player-role", string.format(
    "gen=%s source=%s role=%s rendered=%s version=%s key=%s route=%s gender=%s",
    tostring(self.generation), tostring(source), tostring(role), identity(player),
    tostring(save.version), tostring(owner.characterKey),
    tostring(owner.routeKey), tostring(owner.gender)), game)
end

function DebugLog:event(kind, data, game)
  if type(kind) == "table" then
    game, data = data or kind.game, kind
    kind = first(data.kind, data.type, data.event)
  end
  kind = tostring(kind or ""):upper()
  if not EVENT_KINDS[kind] then return false, "unsupported_event" end
  if type(data) ~= "table" then data = { decision=data } end
  game = game or data.game
  local message, bucket = eventRecord(kind, data, game)
  local clockOk, now = pcall(self.clock)
  if not clockOk or type(now) ~= "number" then now = 0 end
  local previous = self.eventLast[bucket]
  local interval = DebugLog.EVENT_INTERVALS[kind]
  if previous and now >= previous.at and now - previous.at < interval then
    if previous.message == message then
      previous.deduplicated = previous.deduplicated + 1
      self.eventStats.deduplicated = self.eventStats.deduplicated + 1
      return false, "deduplicated"
    end
    previous.rateLimited = previous.rateLimited + 1
    self.eventStats.rateLimited = self.eventStats.rateLimited + 1
    return false, "rate_limited"
  end
  if previous then
    if previous.deduplicated > 0 then
      message = message .. " deduplicated=" .. previous.deduplicated
    end
    if previous.rateLimited > 0 then
      message = message .. " rateLimited=" .. previous.rateLimited
    end
  end
  self.eventLast[bucket] = {
    at=now, message=eventRecord(kind, data, game),
    deduplicated=0, rateLimited=0,
  }
  self.eventStats.emitted = self.eventStats.emitted + 1
  return self:_record(kind, message, game, data.edition)
end

function DebugLog:public()
  local owner = self
  local api = {
    schema="ascendant.pokemon-overworld.diagnostics/v1",
    recent=function()
      local out={} for i,v in ipairs(owner.recent) do out[i]=v end return out
    end,
    session=function() return owner.session end,
    files=function()
      local out={} for k,v in pairs(owner.files) do out[k]=v end return out
    end,
    errors=function()
      local out={} for k,v in pairs(owner.writeErrors) do out[k]=v end return out
    end,
    stats=function()
      local out={}
      for key,value in pairs(owner.eventStats) do out[key]=value end
      return out
    end,
  }
  api.event = function(firstArg, secondArg, thirdArg, fourthArg)
    if firstArg == api then
      return owner:event(secondArg, thirdArg, fourthArg)
    end
    return owner:event(firstArg, secondArg, thirdArg)
  end
  return api
end

return DebugLog
