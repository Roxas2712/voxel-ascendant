-- Generation-neutral, read-only character provider.
--
-- The engine and Ascendant mods continue to own character selection, story,
-- movement and artwork.  This module normalizes the live public identities and
-- walker definitions so a renderer (and later a VASC Card) has one stable seam.

local Characters = {}
Characters.__index = Characters

local function call(provider, name, ...)
  local fn = type(provider) == "table" and provider[name]
  if type(fn) ~= "function" then return nil end
  local ok, value = pcall(fn, ...)
  if ok then return value end
  ok, value = pcall(fn, provider, ...)
  return ok and value or nil
end

local function upper(value)
  return type(value) == "string" and value:upper() or nil
end

local function sourceOwner(id, def)
  local image = type(def) == "table" and tostring(def.image or "") or ""
  if tostring(id):find("^SPRITE_KA_")
      or image:find("kanto_ascendant", 1, true) then
    return "kanto_ascendant"
  end
  if tostring(id):find("^SPRITE_JASC_")
      or image:find("johto_ascendant", 1, true) then
    return "johto_ascendant"
  end
  if image:find("red_3d_player", 1, true) then return "red_3d_player" end
  return "game"
end

local function spriteTables(game)
  local data = game and game.data or {}
  local seen, result = {}, {}
  for _, sprites in ipairs({ data.gen2Sprites, data.sprites,
      game and game.world and game.world.sprites,
      game and game.overworld and game.overworld.sprites }) do
    if type(sprites) == "table" and not seen[sprites] then
      seen[sprites] = true
      result[#result + 1] = sprites
    end
  end
  return result
end

local function isCharacter(id, def)
  return type(def) == "table" and def.walker == true
    and id ~= "SPRITE_PIKACHU" and def.pokemonDex == nil
    and def.pokemonSpecies == nil and def.isPokemonFollower ~= true
end

function Characters.new(options)
  return setmetatable({
    mod=assert(options.mod), generation=assert(options.generation),
    compat=assert(options.compat), activeGame=nil, installed=false,
  }, Characters)
end

function Characters:inventory(game)
  game = game or self.activeGame
  local byId = {}
  for _, sprites in ipairs(spriteTables(game)) do
    for key, def in pairs(sprites) do
      local id = type(def) == "table" and def.id or key
      if type(id) == "string" and isCharacter(id, def) then
        byId[id] = {
          schema="ascendant.overworld-character/v1",
          id=id, owner=sourceOwner(id, def), generation=self.generation,
          image=def.image, frames=def.frames, walker=true,
          trueColor=def.trueColor == true,
        }
      end
    end
  end
  local list = {}
  for _, row in pairs(byId) do list[#list + 1] = row end
  table.sort(list, function(a, b) return a.id < b.id end)
  return list
end

function Characters:active(game)
  game = game or self.activeGame
  local result = {}
  for _, source in ipairs(self.compat.characterSources()) do
    local provider = source.provider
    if source.kind == "kasc" then
      for _, role in ipairs({ "Player", "Rival", "Third" }) do
        local id = upper(call(provider, "get" .. role .. "Character"))
        if id then result[#result + 1] = {
          role=role:lower(), id=id, owner=source.id,
        } end
      end
    elseif source.kind == "jasc" then
      local id = upper(call(provider, "current", game))
      if id then result[#result + 1] = {
        role="player", id=id, owner=source.id,
      } end
    elseif source.kind == "character-selector" then
      local id = upper(call(provider, "currentCharacter", game)
        or call(provider, "activeCharacter", game)
        or call(provider, "current", game))
      result[#result + 1] = {
        role="player-renderer", id=id, owner=source.id,
        available=true,
      }
    elseif source.kind == "vasc" then
      result[#result + 1] = {
        role="renderer", id="VOXEL_ASCENDANT", owner=source.id,
        available=true,
      }
    end
  end
  return result
end

function Characters:tag(entity, role)
  if type(entity) ~= "table" then return false end
  local def = entity.spriteDef or entity.sprite and entity.sprite.def
  local id = type(def) == "table" and (def.id or entity.spriteId
    or entity.def and entity.def.sprite) or nil
  if type(def) ~= "table" or not isCharacter(id, def) then return false end
  entity.ascendantCharacter = entity.ascendantCharacter or id
  entity.ascendantCharacterRole = entity.ascendantCharacterRole or role or "npc"
  entity.ascendantCharacterOwner = entity.ascendantCharacterOwner
    or sourceOwner(id, def)
  entity.ascendantCharacterSchema = "ascendant.overworld-character/v1"
  return true
end

function Characters:tagWorld(game)
  game = game or self.activeGame
  local world = game and (game.world or game.overworld)
  if type(world) ~= "table" then return 0 end
  self.activeGame = game
  local count = self:tag(world.player, "player") and 1 or 0
  for _, bucket in ipairs({ world.npcs, world.entities, world.objects }) do
    if type(bucket) == "table" then
      for _, entity in pairs(bucket) do
        if self:tag(entity, "npc") then count = count + 1 end
      end
    end
  end
  return count
end

function Characters:install()
  if self.installed then return true end
  self.installed = true
  local registry = self
  if self.mod.events and type(self.mod.events.on) == "function" then
    for _, event in ipairs({ "game.ready", "save.loaded", "map.entered" }) do
      self.mod.events:on(event, function(ev)
        registry:tagWorld(ev and ev.game or registry.activeGame)
      end)
    end
  end
  return true
end

function Characters:health()
  local sources = self.compat.characterSources()
  return {
    schema="ascendant.compat-status/v1", ok=self.installed,
    state=self.installed and "active" or "inactive",
    generation=self.generation, owner=self.mod.id,
    characterCount=#self:inventory(), sourceCount=#sources,
  }
end

function Characters:public()
  local registry = self
  return {
    schema="ascendant.overworld-characters/v1",
    generation=self.generation,
    ownership="read-only-provider-delegation",
    inventory=function(game) return registry:inventory(game) end,
    active=function(game) return registry:active(game) end,
    tag=function(entity, role) return registry:tag(entity, role) end,
    refresh=function(game) return registry:tagWorld(game) end,
    health=function() return registry:health() end,
  }
end

return Characters
