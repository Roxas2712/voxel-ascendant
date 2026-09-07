-- Render-only spacing for HD followers.
--
-- Logical cells, collision and the owner's movement trail remain untouched.
-- Visible followers are sampled from the already traversed, walkable trail.
-- This is deliberately not a straight vector extension: extending a card
-- away from its logical entity can put a large Pokemon through a fence or on
-- the wrong side of a corner. Each link accounts for both visible widths plus
-- breathing room. Native cards, Gen-2 VASC poses and Gen-1 VASC matrices
-- share the same trail targets.

local FollowerSpacing = {}
FollowerSpacing.__index = FollowerSpacing

FollowerSpacing.SCHEMA = "ascendant.follower-spacing/v2"

local TARGET_DISTANCE = {
  pokemon_small = 24,
  pokemon_medium = 32,
  pokemon_large = 42,
}

local PLAYER_HALF_WIDTH = 8
local EDGE_CLEARANCE = 8
local MAX_TRAIL = 64
local MAX_TRAIL_SEGMENT = 32

local function option(mod, key, fallback)
  local options = mod and mod.options
  if not (options and type(options.get) == "function") then return fallback end
  local ok, value = pcall(options.get, options, key)
  if not ok or value == nil then return fallback end
  return value == true
end

local function invoke(owner, name, ...)
  local fn = type(owner) == "table" and owner[name]
  if type(fn) ~= "function" then return nil end
  local ok, value = pcall(fn, ...)
  if not ok or value == nil then ok, value = pcall(fn, owner, ...) end
  return ok and value or nil
end

local function worldFor(game)
  return game and (game.overworld or game.world) or nil
end

local function coordinate(entity, pixel, cell)
  local value = entity and entity[pixel]
  if type(value) == "number" then return value end
  value = entity and entity[cell]
  return type(value) == "number" and value * 16 or nil
end

local function isMarkedFollower(entity)
  if type(entity) ~= "table" then return false end
  if entity.overworldWildSpawn or entity.ascendantPokemonSpriteContext == "city"
      or entity.ascendantPokemonSpriteContext == "grass"
      or entity.ascendantPokemonSpriteContext == "wilds_town" then return false end
  return entity.isPokemonFollower == true
    or entity._ascendantPokemonOverworld == true
    or entity._ascendantNativeFollower == true
    or entity.pokepcTrailer == true
    -- VASC Gen 2 publishes this on both its party trailers and the native
    -- follower fallback.  Some lifecycle frames do not expose any of the
    -- older PokePC/Ascendant markers yet, so discovery must accept the
    -- documented Wilds marker directly.
    or entity.wildsFollower == true
    or entity.followerMon ~= nil
    or entity.followerSpecies ~= nil
end

function FollowerSpacing.new(options)
  return setmetatable({
    mod=assert(options.mod), compat=assert(options.compat), activeGame=nil,
    installed=false, applied=0, lastError=nil,
    followers=setmetatable({}, { __mode="k" }),
    offsets=setmetatable({}, { __mode="k" }),
    visual=setmetatable({}, { __mode="k" }),
    native=setmetatable({}, { __mode="k" }), vasc=nil, singleFollower=nil,
    trailWorld=nil, trailMap=nil, trailHeadX=nil, trailHeadY=nil, trail={},
  }, FollowerSpacing)
end

function FollowerSpacing:enabled()
  -- Expanded spacing exists solely to make the larger HD cards clear the
  -- player. Once HD followers are disabled, restore every render bridge so
  -- the owning follower mod/vanilla renderer uses its exact native spacing.
  return option(self.mod, "hd_pokemon_followers", true)
    and option(self.mod, "dynamic_follower_spacing", true)
end

function FollowerSpacing:_minimum(entity)
  local def = entity and entity.sprite and entity.sprite.def
    or entity and entity.spriteDef or {}
  local class = entity and entity.ascendantScaleClass or def.ascendantScaleClass
  return TARGET_DISTANCE[class] or TARGET_DISTANCE.pokemon_medium
end

local function centre(entity)
  local x = coordinate(entity, "px", "cellX")
  local y = coordinate(entity, "py", "cellY")
  if x == nil or y == nil then return nil end
  return x + 8, y + 8
end

local function clock()
  if love and love.timer and type(love.timer.getTime) == "function" then
    return love.timer.getTime()
  end
  return os and type(os.clock) == "function" and os.clock() or 0
end

function FollowerSpacing:_halfWidth(entity)
  local def = entity and entity.sprite and entity.sprite.def
    or entity and entity.spriteDef or {}
  local info = entity and entity.scaleInfo or {}
  local rendered = tonumber(info.renderedW)
  if rendered and rendered > 0 then return rendered / 2 end
  local height = tonumber(entity and entity.ascendantWorldHeight)
    or tonumber(def.ascendantWorldHeight)
  local sourceW = tonumber(def.ascendantRuntimeContentWidth)
  local sourceH = tonumber(def.ascendantRuntimeContentHeight)
  if height and sourceW and sourceH and sourceH > 0 then
    return math.max(4, height * sourceW / sourceH / 2)
  end
  local class = entity and entity.ascendantScaleClass or def.ascendantScaleClass
  if class == "pokemon_large" then return 15 end
  if class == "pokemon_medium" then return 10 end
  return 6
end

function FollowerSpacing:_ordered(player)
  local list = {}
  local px, py = centre(player)
  for entity in pairs(self.followers) do
    local ex, ey = centre(entity)
    list[#list + 1] = {
      entity=entity,
      chain=tonumber(entity._ascendantChainIndex),
      distance=ex and px and (math.abs(ex-px) + math.abs(ey-py)) or math.huge,
    }
  end
  table.sort(list, function(a, b)
    if a.chain and b.chain and a.chain ~= b.chain then return a.chain < b.chain end
    if a.chain ~= nil and b.chain == nil then return true end
    if a.chain == nil and b.chain ~= nil then return false end
    if a.distance ~= b.distance then return a.distance < b.distance end
    return tostring(a.entity.id or a.entity) < tostring(b.entity.id or b.entity)
  end)
  return list
end

function FollowerSpacing:_rememberPlayer(world)
  local player = world and world.player
  local map = world and world.map
  local mapId = map and (map.id or map.name or tostring(map)) or ""
  if self.trailWorld ~= world or self.trailMap ~= mapId then
    self.trailWorld, self.trailMap = world, mapId
    self.trailHeadX, self.trailHeadY, self.trail = nil, nil, {}
  end
  local x = player and (player.targetX or player.cellX)
  local y = player and (player.targetY or player.cellY)
  if type(x) ~= "number" or type(y) ~= "number" then return end
  if self.trailHeadX == nil then
    self.trailHeadX, self.trailHeadY = x, y
    return
  end
  if x ~= self.trailHeadX or y ~= self.trailHeadY then
    table.insert(self.trail, 1, {
      x=self.trailHeadX * 16 + 8, y=self.trailHeadY * 16 + 8,
    })
    while #self.trail > MAX_TRAIL do table.remove(self.trail) end
    self.trailHeadX, self.trailHeadY = x, y
  end
end

local function addTrailPoint(points, x, y)
  if type(x) ~= "number" or type(y) ~= "number" then return false end
  local previous = points[#points]
  if previous then
    local dx, dy = x - previous.x, y - previous.y
    local length = math.sqrt(dx * dx + dy * dy)
    if length < .01 then return true end
    -- A map load/teleport must never become a visual bridge across the map.
    if length > MAX_TRAIL_SEGMENT then return false end
  end
  points[#points + 1] = { x=x, y=y }
  return true
end

function FollowerSpacing:_path(game, player)
  local points = {}
  local playerX, playerY = centre(player)
  addTrailPoint(points, playerX, playerY)

  -- KASC/JASC own movement. Their public history is the authoritative record
  -- of committed, walkable player cells and naturally follows corners.
  local movement = invoke(self.singleFollower, "movement", game)
  local history = movement and movement.history
  if type(history) == "table" then
    for index = #history, 1, -1 do
      local step = history[index]
      local x = step and (step.fromX or step.x)
      local y = step and (step.fromY or step.y)
      if type(x) == "number" and type(y) == "number"
          and not addTrailPoint(points, x * 16 + 8, y * 16 + 8) then
        break
      end
    end
  end

  -- Standalone and older providers may publish no history. Keep a small
  -- read-only observation trail as a safe fallback; it records only cells the
  -- player really occupied and never invents a position past its end.
  if #points <= 1 then
    for _, point in ipairs(self.trail) do
      if not addTrailPoint(points, point.x, point.y) then break end
    end
  end
  return points
end

local function pointAtDistance(points, wanted)
  local travelled = 0
  for index = 2, #points do
    local a, b = points[index - 1], points[index]
    local dx, dy = b.x - a.x, b.y - a.y
    local length = math.sqrt(dx * dx + dy * dy)
    if length > .001 then
      if travelled + length >= wanted then
        local ratio = (wanted - travelled) / length
        return a.x + dx * ratio, a.y + dy * ratio, true, wanted
      end
      travelled = travelled + length
    end
  end
  local last = points[#points]
  -- On a fresh spawn the trail may be shorter than a large Pokemon needs.
  -- Use its last safe point, never extrapolate through scenery.
  return last and last.x, last and last.y, false, travelled
end

function FollowerSpacing:_layout(game)
  local world = worldFor(game)
  local player = world and world.player
  local playerX, playerY = centre(player)
  local offsets = setmetatable({}, { __mode="k" })
  if not playerX then self.offsets = offsets return offsets end

  self:_rememberPlayer(world)
  local path = self:_path(game, player)
  local wanted = 0
  local previousHalf = PLAYER_HALF_WIDTH
  for _, item in ipairs(self:_ordered(player)) do
    local entity = item.entity
    local baseX, baseY = centre(entity)
    if baseX then
      local half = self:_halfWidth(entity)
      local required = math.max(self:_minimum(entity),
        previousHalf + half + EDGE_CLEARANCE)
      wanted = wanted + required
      local visualX, visualY, complete, available = pointAtDistance(path, wanted)
      visualX, visualY = visualX or baseX, visualY or baseY
      if not complete then
        local baseSeparation = math.sqrt((baseX-playerX)^2 + (baseY-playerY)^2)
        local trailSeparation = math.sqrt((visualX-playerX)^2 + (visualY-playerY)^2)
        if baseSeparation > trailSeparation then
          visualX, visualY = baseX, baseY
        end
      end
      local prior = self.visual[entity]
      local movingUntil = prior and prior.movingUntil or 0
      if prior and (math.abs(visualX-prior.x) + math.abs(visualY-prior.y)) > .05 then
        movingUntil = clock() + .24
      end
      self.visual[entity] = {
        x=visualX, y=visualY, movingUntil=movingUntil,
      }
      offsets[entity] = { dx=visualX-baseX, dy=visualY-baseY,
        target=wanted, available=available, halfWidth=half, complete=complete,
        moving=entity.moving == true or movingUntil > clock() }
      previousHalf = half
    end
  end
  self.offsets = offsets
  return offsets
end

function FollowerSpacing:_discover(game)
  local found = setmetatable({}, { __mode="k" })
  local _, api = self.compat.followerOwner()
  local single = api and api.singleFollower
  self.singleFollower = single
  local entity = invoke(single, "entity", game)
  if type(entity) == "table" then found[entity] = true end
  local entities = invoke(single, "entities", game)
  if type(entities) == "table" then
    for _, current in pairs(entities) do
      if type(current) == "table" then found[current] = true end
    end
  end
  local world = worldFor(game)
  for _, bucket in ipairs({ world and world.npcs, world and world.entities,
      world and world.objects }) do
    if type(bucket) == "table" then
      for _, current in pairs(bucket) do
        if isMarkedFollower(current) then found[current] = true end
      end
    end
  end
  self.followers = found
  return found
end

function FollowerSpacing:_delta(entity)
  local offset = self.offsets[entity]
  return offset and offset.dx or 0, offset and offset.dy or 0,
    offset and offset.moving == true or false
end

-- VASC deliberately parks a newly selected Gen-2 trailer on the player's
-- logical cell until the player creates a real, walkable trail.  Map-entry
-- trailers are hidden by VASC itself, but a PARTY -> FOLLOWING rebuild can
-- arrive without that entry flag.  Do not invent a behind-facing cell here:
-- merely suppress the coincident visual until the existing trail gives this
-- bridge a distinct render point.  Entity cells, collision and VASC state are
-- never mutated.
function FollowerSpacing:_hideCoincidentTrailer(entity, player)
  if not self:enabled() or type(entity) ~= "table"
      or type(player) ~= "table" then return false end
  if entity.pokepcTrailer ~= true and entity.wildsFollower ~= true then
    return false
  end
  if type(entity.cellX) ~= "number" or type(entity.cellY) ~= "number"
      or type(player.cellX) ~= "number" or type(player.cellY) ~= "number"
      or entity.cellX ~= player.cellX or entity.cellY ~= player.cellY then
    return false
  end
  local entityX, entityY = centre(entity)
  local playerX, playerY = centre(player)
  if entityX == nil or playerX == nil then return true end
  local dx, dy = self:_delta(entity)
  -- A published/observed trail may already provide a safe distinct render
  -- point even though VASC has not committed the trailer's logical cell yet.
  -- In that case it is no longer visually coincident and should be shown.
  return math.abs(entityX + dx - playerX) < .5
    and math.abs(entityY + dy - playerY) < .5
end

-- Gen-1 VASC captures entity poses directly and never calls sprite:draw.
-- Match the card matrix to the known live follower centre and return the same
-- chain offset used by the native/Gen-2 paths. This is render-only.
function FollowerSpacing:vascOffset(model)
  if type(model) ~= "table" or #model < 16 then
    return 0, 0, false, false
  end
  -- Transform the local card's foot-centre (8, 0, 0) into world X/Z.
  local cardX = (tonumber(model[1]) or 0) * 8 + (tonumber(model[4]) or 0)
  local cardY = (tonumber(model[9]) or 0) * 8 + (tonumber(model[12]) or 0)
  if not self:enabled() then
    -- Switching HD followers or expanded spacing off restores the owning
    -- renderer completely. Card animation is decided independently by
    -- VoxelCharacters from the authored Pokemon record, not by this bridge.
    return 0, 0, false, false
  end
  self:_layout(self.activeGame)
  local best, bestDistance, bestDx, bestDy
  for entity, offset in pairs(self.offsets) do
    local ex, ey = centre(entity)
    if ex then
      local baseDistance = math.abs(cardX-ex) + math.abs(cardY-ey)
      if baseDistance <= 2.5
          and (not bestDistance or baseDistance < bestDistance) then
        best, bestDistance = offset, baseDistance
        bestDx, bestDy = offset.dx, offset.dy
      end
      -- Gen-2's public VASC prepare hook has already consumed the pose offset
      -- before the card matrix is built. Recognise that shifted matrix too,
      -- but do not apply the offset for a second time.
      local visualDistance = math.abs(cardX-(ex+offset.dx))
        + math.abs(cardY-(ey+offset.dy))
      if visualDistance <= 2.5
          and (not bestDistance or visualDistance < bestDistance) then
        best, bestDistance = offset, visualDistance
        bestDx, bestDy = 0, 0
      end
    end
  end
  return best and bestDx or 0, best and bestDy or 0,
    best and best.moving == true or false, best ~= nil
end

function FollowerSpacing:_wrapNative(entity)
  local sprite = entity and entity.sprite
  if type(sprite) ~= "table" or type(sprite.draw) ~= "function" then return false end
  local previous = self.native[entity]
  if previous and previous.sprite == sprite and sprite.draw == previous.wrapped then
    return false
  end
  if previous and previous.sprite and previous.sprite.draw == previous.wrapped then
    previous.sprite.draw = previous.raw
  end
  local raw, spacing = sprite.draw, self
  local function wrapped(selfSprite, px, py, camX, camY, ...)
    local world = worldFor(spacing.activeGame)
    local player = world and world.player
    if spacing:enabled() and player then
      spacing:_layout(spacing.activeGame)
      if spacing:_hideCoincidentTrailer(entity, player) then return end
      local dx, dy = spacing:_delta(entity)
      px, py = (tonumber(px) or 0) + dx, (tonumber(py) or 0) + dy
    end
    return raw(selfSprite, px, py, camX, camY, ...)
  end
  sprite.draw = wrapped
  self.native[entity] = { sprite=sprite, raw=raw, wrapped=wrapped }
  return true
end

function FollowerSpacing:_restoreVasc()
  local bridge = self.vasc
  if bridge and bridge.api and bridge.api.prepare == bridge.wrapped then
    bridge.api.prepare = bridge.raw
  end
  self.vasc = nil
end

function FollowerSpacing:_installVasc()
  local api = self.compat.vascOverworld and self.compat.vascOverworld() or nil
  if not (type(api) == "table" and type(api.prepare) == "function") then
    self:_restoreVasc()
    return false
  end
  if self.vasc and self.vasc.api == api and api.prepare == self.vasc.wrapped then
    return false
  end
  self:_restoreVasc()
  local raw, spacing = api.prepare, self
  local function wrapped(posed, ...)
    local changed = {}
    local visible = posed
    local playerPose
    for _, pose in ipairs(posed or {}) do
      if pose and pose.isPlayer then playerPose = pose break end
    end
    local player = playerPose and playerPose.entity
      or worldFor(spacing.activeGame) and worldFor(spacing.activeGame).player
    if spacing:enabled() and player then
      spacing:_layout(spacing.activeGame)
      visible = {}
      for _, pose in ipairs(posed or {}) do
        local hidden = pose and spacing.followers[pose.entity]
          and spacing:_hideCoincidentTrailer(pose.entity, player)
        if not hidden then visible[#visible + 1] = pose end
        if pose and spacing.followers[pose.entity] and not hidden then
          local dx, dy = spacing:_delta(pose.entity)
          changed[#changed + 1] = { pose=pose, px=pose.px, py=pose.py }
          pose.px, pose.py = (tonumber(pose.px) or 0) + dx,
            (tonumber(pose.py) or 0) + dy
        end
      end
    end
    local results = { pcall(raw, visible, ...) }
    for _, old in ipairs(changed) do old.pose.px, old.pose.py = old.px, old.py end
    if not results[1] then error(results[2], 0) end
    return unpack(results, 2)
  end
  api.prepare = wrapped
  self.vasc = { api=api, raw=raw, wrapped=wrapped }
  return true
end

function FollowerSpacing:restore()
  local count = 0
  for entity, entry in pairs(self.native) do
    if entry.sprite and entry.sprite.draw == entry.wrapped then
      entry.sprite.draw = entry.raw
      count = count + 1
    end
    self.native[entity] = nil
  end
  self:_restoreVasc()
  self.followers = setmetatable({}, { __mode="k" })
  self.offsets = setmetatable({}, { __mode="k" })
  self.visual = setmetatable({}, { __mode="k" })
  self.singleFollower = nil
  self.trailWorld, self.trailMap = nil, nil
  self.trailHeadX, self.trailHeadY, self.trail = nil, nil, {}
  return count
end

function FollowerSpacing:apply(game)
  game = game or self.activeGame
  if game then self.activeGame = game end
  if not self:enabled() then return self:restore() end
  self:_discover(game)
  self:_layout(game)
  self:_installVasc()
  local count = 0
  for entity in pairs(self.followers) do
    if self:_wrapNative(entity) then count = count + 1 end
  end
  self.applied = self.applied + count
  return count
end

function FollowerSpacing:install()
  if self.installed then return true end
  self.installed = true
  if self.mod.events and type(self.mod.events.on) == "function" then
    local spacing = self
    for _, event in ipairs({ "game.ready", "save.loaded", "map.entered",
        "map.reloaded", "world.stepped" }) do
      self.mod.events:on(event, function(ev)
        spacing:apply(ev and ev.game or spacing.activeGame)
      end)
    end
    self.mod.events:on("mod.options_changed", function(ev)
      if not ev or not ev.mod or ev.mod == spacing.mod.id then
        spacing:apply(spacing.activeGame)
      end
    end)
  end
  return true
end

function FollowerSpacing:health()
  local count = 0
  for _ in pairs(self.followers) do count = count + 1 end
  return { schema=FollowerSpacing.SCHEMA, ok=self.installed,
    enabled=self:enabled(), followerCount=count,
    nativeApplied=self.applied, vasc=self.vasc ~= nil,
    targetDistance=TARGET_DISTANCE, edgeClearance=EDGE_CLEARANCE,
    placement="walked-trail", observedTrail=#self.trail,
    lastError=self.lastError }
end

function FollowerSpacing:public()
  local spacing = self
  return { schema=FollowerSpacing.SCHEMA,
    enabled=function() return spacing:enabled() end,
    refresh=function(game) return spacing:apply(game) end,
    restore=function() return spacing:restore() end,
    health=function() return spacing:health() end }
end

return FollowerSpacing
