-- Optional-owner and VASC discovery.  No foreign private modules are loaded.

return function(mod, generation)
  local Compat = {}

  local function find(id)
    if type(mod.find) ~= "function" then return nil end
    local ok, handle = pcall(mod.find, mod, id)
    if not ok or handle == nil then ok, handle = pcall(mod.find, id) end
    return ok and type(handle) == "table" and handle or nil
  end

  local function exports(handle)
    return type(handle) == "table" and type(handle.exports) == "table"
      and handle.exports or nil
  end

  local ownerIds = generation == 2
    and { "johto_ascendant", "kanto_ascendant" }
    or { "kanto_ascendant" }
  local followerIds = {
    "FOLLOWERS_EX", "PokePCFollowers_VoxelMerge", "pokepcfollowers",
    "pokepc_followers_rb",
  }

  function Compat.followerOwner()
    for _, id in ipairs(ownerIds) do
      local handle = find(id)
      local api = exports(handle)
      if api and (type(api.singleFollower) == "table"
          or type(api.followerSelection) == "table"
          or type(api.followerSprites) == "table") then
        return id, api
      end
    end
    for _, id in ipairs(followerIds) do
      local handle = find(id)
      local api = exports(handle)
      if api and (type(api.activeMon) == "function"
          or type(api.singleFollower) == "table") then
        return id, api
      end
    end
    return nil
  end

  function Compat.vascStatus()
    local api = exports(find("VOXEL_ASCENDANT"))
    if not api then
      return {
        schema = "ascendant.pokemon-overworld.vasc-status/v1",
        available = false,
        stadium2Models = false,
        modelMetadata = false,
        externalCards = false,
        reason = "vasc_not_loaded",
      }
    end
    local capabilities = type(api.capabilities) == "table" and api.capabilities or {}
    local host = type(api.ascendantCards) == "table" and api.ascendantCards or nil
    return {
      schema = "ascendant.pokemon-overworld.vasc-status/v1",
      available = true,
      generation = tonumber(api.targetGeneration or api.generation
        or capabilities.generation),
      stadium2Models = capabilities.stadium2Models == true,
      modelMetadata = capabilities.stadium2Models == true
        or capabilities.partyFollowers == true,
      externalCards = host and host.externalRegistration == true or false,
      cardHostSchema = host and host.schema or nil,
      reason = host and host.externalRegistration == true
        and nil or "vasc_external_card_registration_unavailable",
    }
  end

  function Compat.vascOverworld()
    local api = exports(find("VOXEL_ASCENDANT"))
    return api and type(api.overworld) == "table" and api.overworld or nil
  end

  -- Only public exports are returned.  The standalone package never loads a
  -- KASC/JASC/VASC source file and therefore cannot accidentally take over
  -- their save or story authority.
  function Compat.characterSources()
    local result = {}
    local kasc = exports(find("kanto_ascendant"))
    if kasc and type(kasc.extendedCharacters) == "table" then
      result[#result + 1] = {
        id="kanto_ascendant", kind="kasc",
        provider=kasc.extendedCharacters,
      }
    end
    local jasc = exports(find("johto_ascendant"))
    local jascCharacters = jasc and jasc.jasc and jasc.jasc.characters
      or jasc and jasc.johtoAscendant and jasc.johtoAscendant.characters
    if type(jascCharacters) == "table" then
      result[#result + 1] = {
        id="johto_ascendant", kind="jasc", provider=jascCharacters,
      }
    end
    local selector = exports(find("red_3d_player"))
    if selector then
      result[#result + 1] = {
        id="red_3d_player", kind="character-selector", provider=selector,
      }
    end
    local vasc = exports(find("VOXEL_ASCENDANT"))
    if vasc then
      result[#result + 1] = {
        id="VOXEL_ASCENDANT", kind="vasc", provider=vasc,
      }
    end
    return result
  end

  -- Public Wilds runtimes can be installed directly or embedded by an
  -- Ascendant package. Return each export table once; callers only decorate
  -- its published renderer/ambient seams and never start another spawn core.
  function Compat.wildsSources()
    local result, seen = {}, {}
    local function add(id, api, kind)
      if type(api) ~= "table" or seen[api] then return end
      if type(api.render) ~= "table" and type(api.ambient) ~= "table"
          and type(api.registerSpriteProvider) ~= "function" then return end
      seen[api] = true
      result[#result + 1] = { id=id, kind=kind, provider=api }
    end
    local direct = exports(find("overworld_wild_spawns"))
    add("overworld_wild_spawns", direct, "standalone")
    for _, id in ipairs({ "kanto_ascendant", "johto_ascendant" }) do
      local api = exports(find(id))
      local embedded = api and api.internalWilds
      add(id, embedded and (embedded.exports or embedded), "embedded")
      add(id, api and api.wilds, "embedded")
    end
    -- Current VASC Gen 2 publishes the embedded Wilds owner directly on its
    -- public export.  Without this seam APO could find the standalone/KASC
    -- variants in tests yet miss the actual ambient binder used in-game.
    local vasc = exports(find("VOXEL_ASCENDANT"))
    add("VOXEL_ASCENDANT", vasc and vasc.wilds, "embedded")
    return result
  end

  -- These are documented Pokemon-specific metadata fields consumed by VASC's
  -- model resolver.  They do not replace or mutate the foreign renderer.
  function Compat.tagFollower(entity, mon, dex)
    if type(entity) ~= "table" or type(mon) ~= "table" or not dex then
      return false
    end
    entity.isPokemonFollower = true
    entity.followerSpecies = mon.species
    entity.pokemonSpecies = mon.species
    entity.pokemonDex = dex
    entity.followerMon = mon -- runtime-only; the engine never serializes NPCs
    return true
  end

  Compat.public = {
    schema = "ascendant.pokemon-overworld.compat/v1",
    generation = generation,
    ownership = "single-owner-delegation",
    ascendantIds = ownerIds,
    vasc = Compat.vascStatus,
    vascOverworld = Compat.vascOverworld,
    characterSources = Compat.characterSources,
    wildsSources = Compat.wildsSources,
  }
  return Compat
end
