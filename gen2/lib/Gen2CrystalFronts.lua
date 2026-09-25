-- Standalone, menu-only Crystal front-sprite resolver.
--
-- Optional packaged Crystal artwork is frame one only. Some distributions
-- omit these files; return nil so menus can use a companion provider or their
-- cartridge artwork. This resolver never controls battle animation.

local V = ...
local mod = V.mod
local Stats = require("src.pokemon.Stats")

local Fronts = { apiVersion = 1 }
-- Packaged assets change on reload, not while painting a menu. Keep only
-- presence (at most 999 species x two variants), never the PNG contents.
local present = {}
function Fronts.invalidate() present = {} end
local function exists(relative)
  if present[relative] ~= nil then return present[relative] end
  if not mod then return false end
  if type(mod.info) == "function" then
    local ok, info = pcall(mod.info, mod, relative)
    if ok then
      present[relative] = type(info) == "table" and info.type == "file"
      return present[relative]
    end
  end
  -- Older hosts only expose read(). A transient error must remain retryable.
  if type(mod.read) == "function" then
    local ok, bytes = pcall(mod.read, mod, relative)
    if ok then present[relative] = bytes ~= nil; return present[relative] end
  end
  return false
end

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
  if not exists(relative) then
    if variant ~= "shiny" then return nil end
    variant = "normal"
    relative = relativePath(dex, variant)
    if not exists(relative) then return nil end
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
