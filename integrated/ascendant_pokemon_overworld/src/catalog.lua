-- Generation-neutral National-Dex to artwork resolver.

local Catalog = {
  SCHEMA = "ascendant.pokemon-overworld.catalog/v1",
  FIRST_DEX = 1,
  -- The cartridge follower matrix remains intentionally bounded to the
  -- original 251. Presentation-only GO cards can cover the imported
  -- expansion independently without manufacturing nonexistent follower PNGs.
  LAST_DEX = 251,
  LAST_PRESENTATION_DEX = 411,
  FRAMES = 6,
  WIDTH = 16,
  HEIGHT = 96,
}

local SHINY_ATTACK_DV = {
  [2]=true, [3]=true, [6]=true, [7]=true,
  [10]=true, [11]=true, [14]=true, [15]=true,
}

local function integer(value)
  local number = tonumber(value)
  if not number then return nil end
  number = math.floor(number)
  return number
end

function Catalog.validDex(value)
  local dex = integer(value)
  if dex and dex >= Catalog.FIRST_DEX and dex <= Catalog.LAST_DEX then
    return dex
  end
  return nil
end

function Catalog.validPresentationDex(value)
  local dex = integer(value)
  if dex and dex >= Catalog.FIRST_DEX
      and dex <= Catalog.LAST_PRESENTATION_DEX then
    return dex
  end
  return nil
end

local function dexFor(game, value, validator)
  if type(value) == "table" then
    local direct = validator(value.nationalDex or value.pokemonDex
      or value.dexNo or value.dex)
    if direct then return direct end
    value = value.species or value.pokemonSpecies
  end
  local direct = validator(value)
  if direct then return direct end
  if type(value) ~= "string" then return nil end
  local pokemon = game and game.data and game.data.pokemon
  local def = pokemon and (pokemon[value] or pokemon[value:upper()])
  return validator(def and (def.dex or def.nationalDex))
end

function Catalog.dexFor(game, value)
  return dexFor(game, value, Catalog.validDex)
end

function Catalog.presentationDexFor(game, value)
  return dexFor(game, value, Catalog.validPresentationDex)
end

-- Gen-1 map objects publish exact names/text IDs even when their artwork is
-- a shared MONSTER/FAIRY/SEEL/POKE_BALL sheet. Resolve that authored identity
-- before the sprite name (the zoo's Lapras otherwise becomes Seel). Never
-- infer a species for humans, items or the fossil exhibit.
local MAP_POKEMON_SPRITES = {
  SPRITE_MONSTER=true, SPRITE_FAIRY=true, SPRITE_SEEL=true,
  SPRITE_BIRD=true, SPRITE_BUG=true, SPRITE_SLOWBRO=true,
  SPRITE_SNORLAX=true, SPRITE_POKE_BALL=true,
}
function Catalog.mapSpeciesFor(game, entity)
  local def = type(entity) == "table" and entity.def
  if type(def) ~= "table" or not MAP_POKEMON_SPRITES[def.sprite]
      or def.item or def.trainer or def.trainerClass then return nil end
  local pokemon = game and game.data and game.data.pokemon
  if type(pokemon) ~= "table" then return nil end
  for _, key in ipairs({"name", "text"}) do
    local name = def[key]
    if type(name) == "string" then
      -- Each suffix is matched against an exact species key, including
      -- NIDORAN_M/F. No approximate matching of names or sprite silhouettes.
      for at in name:gmatch("_()") do
        local species = name:sub(at):upper()
        if pokemon[species] then return species end
      end
    end
  end
  return nil
end

function Catalog.isShiny(mon)
  if type(mon) ~= "table" then return false end
  if mon.shiny ~= nil then return mon.shiny == true end
  if mon.isShiny ~= nil and type(mon.isShiny) ~= "function" then
    return mon.isShiny == true
  end
  local dvs = mon.dvs or mon.dv
  if type(dvs) ~= "table" then return false end
  local attack = integer(dvs.attack or dvs.atk)
  return integer(dvs.defense or dvs.def) == 10
    and integer(dvs.speed or dvs.spd) == 10
    and integer(dvs.special or dvs.spc) == 10
    and SHINY_ATTACK_DV[attack] == true
end

function Catalog.relative(dex, shiny, submerged)
  dex = Catalog.validDex(dex)
  if not dex then return nil end
  local suffix = shiny and "shiny" or "normal"
  if submerged then suffix = suffix .. "_submerged" end
  return ("assets/followers/follower_%03d_%s.png"):format(dex, suffix)
end

function Catalog.asset(mod, game, mon, submerged)
  local dex = Catalog.dexFor(game, mon)
  local relative = Catalog.relative(dex, Catalog.isShiny(mon), submerged)
  return relative and (mod.path .. "/" .. relative) or nil, dex, relative
end

function Catalog.public(mod)
  return {
    schema = Catalog.SCHEMA,
    firstDex = Catalog.FIRST_DEX,
    lastDex = Catalog.LAST_DEX,
    speciesCount = Catalog.LAST_DEX - Catalog.FIRST_DEX + 1,
    lastPresentationDex = Catalog.LAST_PRESENTATION_DEX,
    presentationSpeciesCount = Catalog.LAST_PRESENTATION_DEX
      - Catalog.FIRST_DEX + 1,
    variants = { "normal", "shiny", "normal_submerged", "shiny_submerged" },
    frames = Catalog.FRAMES,
    width = Catalog.WIDTH,
    height = Catalog.HEIGHT,
    dexFor = Catalog.dexFor,
    presentationDexFor = Catalog.presentationDexFor,
    isShiny = Catalog.isShiny,
    relative = Catalog.relative,
    asset = function(game, mon, submerged)
      return Catalog.asset(mod, game, mon, submerged)
    end,
  }
end

return Catalog
