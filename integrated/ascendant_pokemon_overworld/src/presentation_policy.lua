-- Standalone presentation policy for optional Pokemon model providers.
--
-- This module never loads or edits Voxel Ascendant internals.  It only reads
-- public capabilities, lets optional model mods register themselves, and tags
-- existing Pokemon entities with the user's preferred source.  The packaged
-- HD walksheet remains the final, always-available 2D fallback.

local PresentationPolicy = {}
PresentationPolicy.__index = PresentationPolicy
PresentationPolicy.SCHEMA = "ascendant.pokemon-presentation/v1"

local VALID_SOURCE = {
  auto=true, stadium_only=true, go_first=true, go_only=true, sprite_only=true,
}
local VALID_GRID = { off=true, characters=true, pokemon=true, both=true }

local function optionValue(mod, key, fallback)
  local options = mod and mod.options
  if not (options and type(options.get) == "function") then return fallback end
  local ok, value = pcall(options.get, options, key)
  if not ok or value == nil then return fallback end
  return value
end

local function normalizeProvider(id)
  id = type(id) == "string" and id:lower():gsub("[%s%-]+", "_") or ""
  if id == "go" or id == "pokemon_go_models" then id = "pokemon_go" end
  if id == "stadium" or id == "stadium_2" then id = "stadium2" end
  return id
end

function PresentationPolicy.new(options)
  return setmetatable({
    mod=assert(options.mod), compat=assert(options.compat), providers={},
    selections=0, lastSource="sprite", lastReason="not_resolved",
  }, PresentationPolicy)
end

function PresentationPolicy:mode()
  local value = optionValue(self.mod, "pokemon_model_source", "auto")
  return VALID_SOURCE[value] and value or "auto"
end

function PresentationPolicy:gridMode()
  local value = optionValue(self.mod, "actor_voxel_grid", "off")
  return VALID_GRID[value] and value or "off"
end

function PresentationPolicy:gridEnabled(kind)
  local mode = self:gridMode()
  if mode == "both" then return true end
  if kind == "pokemon" then return mode == "pokemon" end
  return mode == "characters"
end

function PresentationPolicy:order(dex, mode)
  mode = VALID_SOURCE[mode] and mode or self:mode()
  dex = tonumber(dex)
  if mode == "sprite_only" then return { "sprite" } end
  if mode == "stadium_only" then return { "stadium2", "sprite" } end
  if mode == "go_only" then return { "pokemon_go", "sprite" } end
  if mode == "go_first" then
    return { "pokemon_go", "stadium2", "sprite" }
  end
  if dex and dex > 251 then return { "pokemon_go", "stadium2", "sprite" } end
  return { "stadium2", "pokemon_go", "sprite" }
end

function PresentationPolicy:register(id, provider)
  id = normalizeProvider(id)
  if id == "" or id == "sprite" or id == "stadium2" then
    return false, "reserved_or_invalid_provider_id"
  end
  if type(provider) ~= "table" or type(provider.available) ~= "function" then
    return false, "provider_available_required"
  end
  self.providers[id] = provider
  return true
end

function PresentationPolicy:unregister(id, provider)
  id = normalizeProvider(id)
  local current = self.providers[id]
  if current == nil or provider ~= nil and current ~= provider then return false end
  self.providers[id] = nil
  return true
end

function PresentationPolicy:_stadiumAvailable(dex)
  dex = tonumber(dex)
  if not dex or dex < 1 or dex > 251 then return false end
  if self.mod._vascIntegrated then
    local probe=self.mod._vascStadiumAvailable
    if type(probe)~="function" then return false end
    local ok,ready=pcall(probe,dex)
    return ok and ready==true
  end
  local status = self.compat.vascStatus and self.compat.vascStatus() or nil
  return type(status) == "table" and status.available == true
    and (status.stadium2Models == true
      or status.stadium2Models == nil and status.modelMetadata == true)
end

function PresentationPolicy:_providerAvailable(id, dex, context)
  local provider = self.providers[id]
  if not provider then return false end
  local ok, value = pcall(provider.available, dex, context)
  return ok and value == true
end

function PresentationPolicy:_animated(id, dex, context)
  if id == "stadium2" then
    local status = self.compat.vascStatus and self.compat.vascStatus() or nil
    return type(status) == "table" and status.stadium2Animations == true
  end
  local provider = self.providers[id]
  if type(provider) ~= "table" then return false end
  if provider.animated == true then return true end
  if type(provider.animationAvailable) == "function" then
    local ok, value = pcall(provider.animationAvailable, dex, context)
    return ok and value == true
  end
  return false
end

function PresentationPolicy:select(dex, context)
  -- A per-context PokeMMO choice is an explicit animated-card request. It must
  -- win over the global 3D preference; otherwise VASC's Stadium-2 mesh masks
  -- the selected PokeMMO card while the menu misleadingly reports PokeMMO.
  if type(context) == "table" and context.spriteSource == "pokemmo" then
    self.selections, self.lastSource = self.selections + 1, "sprite"
    self.lastReason = "explicit_pokemmo_card"
    return { id="sprite", provider=nil, reason=self.lastReason }
  end
  local mode = self:mode()
  if self.mod._vascIntegrated and type(context)=="table" then
    if context.spriteSource=="stadium2" then mode="stadium_only"
    elseif context.spriteSource=="full_hd" then mode="go_only" end
  end
  for _, id in ipairs(self:order(dex, mode)) do
    if id == "sprite" then
      self.selections, self.lastSource = self.selections + 1, id
      self.lastReason = "packaged_hd_fallback"
      return { id=id, provider=nil, reason=self.lastReason }
    elseif id == "stadium2" and self:_stadiumAvailable(dex)
        and (self.mod._vascIntegrated or mode ~= "auto" or self:_animated(id, dex, context)) then
      self.selections, self.lastSource = self.selections + 1, id
      self.lastReason = "vasc_public_capability"
      return { id=id, provider=nil, reason=self.lastReason }
    elseif self:_providerAvailable(id, dex, context)
        and (mode ~= "auto" or self:_animated(id, dex, context)) then
      self.selections, self.lastSource = self.selections + 1, id
      self.lastReason = "registered_provider"
      return { id=id, provider=self.providers[id], reason=self.lastReason }
    end
  end
  return { id="sprite", provider=nil, reason="packaged_hd_fallback" }
end

function PresentationPolicy:decorate(entity, dex, context)
  local selected = self:select(dex, context)
  if type(entity) == "table" then
    entity.ascendantPokemonModelSource = selected.id
    entity.ascendantPokemonModelDex = selected.id == "stadium2" and tonumber(dex) or nil
    entity.ascendantActorVoxelGrid = self:gridEnabled("pokemon")
    if selected.provider and type(selected.provider.apply) == "function" then
      pcall(selected.provider.apply, entity, dex, context)
    end
  end
  return selected
end

function PresentationPolicy:health()
  local inventory = {}
  for id, provider in pairs(self.providers) do
    inventory[#inventory + 1] = { id=id, version=provider.version }
  end
  table.sort(inventory, function(a, b) return a.id < b.id end)
  return {
    schema=self.SCHEMA, mode=self:mode(), actorVoxelGrid=self:gridMode(),
    selections=self.selections, lastSource=self.lastSource,
    lastReason=self.lastReason, providers=inventory,
  }
end

function PresentationPolicy:public()
  local policy = self
  return {
    schema=self.SCHEMA,
    mode=function() return policy:mode() end,
    order=function(dex, mode) return policy:order(dex, mode) end,
    select=function(dex, context) return policy:select(dex, context) end,
    gridMode=function() return policy:gridMode() end,
    gridEnabled=function(kind) return policy:gridEnabled(kind) end,
    register=function(id, provider) return policy:register(id, provider) end,
    unregister=function(id, provider) return policy:unregister(id, provider) end,
    health=function() return policy:health() end,
  }
end

return PresentationPolicy
