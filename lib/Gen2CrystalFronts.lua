-- Standalone, menu-only Crystal front-sprite resolver.
--
-- VASC Gen 2 must not require Kanto Ascendant to be installed merely to draw
-- the coloured Crystal artwork used by its own ORAS menus. The bundled assets
-- are frame one only, so this service cannot interfere with battle animation.

local V = ...
local mod = V.mod
local Stats = require("src.pokemon.Stats")

local Fronts = { apiVersion = 1 }

local function isShiny(mon)
  if type(mon) ~= "table" then return false end
  if mon.shiny == true or mon.isShiny == true then return true end
  if type(Stats.isShiny) == "function" and mon.dvs ~= nil then
    local ok, value = pcall(Stats.isShiny, mon.dvs)
    if ok then return value == true end
  end
  return false
end

local function dexFor(data, species)
  if species == nil then return nil end
  local def = data and data.pokemon and data.pokemon[species]
  local dex = type(def) == "table" and tonumber(
    def.dex or def.dexNo or def.dexNumber or def.number or def.id) or nil
  if not dex then dex = tonumber(species) end
  if dex and dex >= 1 and dex <= 999 then return math.floor(dex) end
  return nil
end

local function relativePath(dex, variant)
  return ("assets/crystal_fronts/%s/%d.png"):format(variant, dex)
end

function Fronts.resolve(gameOrData, monOrSpecies, opts)
  opts = opts or {}
  local data = gameOrData and gameOrData.data or gameOrData
  local mon = type(monOrSpecies) == "table" and monOrSpecies or nil
  local species = mon and mon.species or monOrSpecies
  if mon and (mon._ascMegaForm or mon.ascMegaForm) then return nil end
  local dex = dexFor(data, species)
  if not dex then return nil end
  local variant = (opts.shiny == true or isShiny(mon)) and "shiny" or "normal"
  local relative = relativePath(dex, variant)
  if not (mod and type(mod.read) == "function" and mod:read(relative) ~= nil) then
    if variant == "shiny" then
      variant = "normal"
      relative = relativePath(dex, variant)
    end
    if not (mod and type(mod.read) == "function" and mod:read(relative) ~= nil) then
      return nil
    end
  end
  return {
    path = mod.path .. "/" .. relative,
    trueColor = true,
    source = "vasc_crystal_front",
    dex = dex,
    variant = variant,
  }
end

Fronts.isShiny = isShiny
Fronts.dexFor = dexFor

return Fronts
