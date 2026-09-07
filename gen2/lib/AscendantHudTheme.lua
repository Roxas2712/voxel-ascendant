-- Generation-neutral ASC/ORAS colour receipt for the draw-only Gen-2 HUD.
-- BattleControllerUI is intentionally never installed as an input wrapper:
-- Gold/Silver/Crystal's battle state and controls remain engine-owned.

local V = ...
local Theme = {}

local okAccent, EditionAccent = pcall(function()
  return type(V) == "table" and type(V.require) == "function"
    and V.require("EditionAccent") or nil
end)
if not okAccent or type(EditionAccent) ~= "table" then EditionAccent = nil end

local ORAS = {
  id="oras",
  generation="shared",
  -- Match VASC's established Gen-1 ORAS furniture: charcoal glass with the
  -- Ascendant red rim.  The cyan prototype was useful for proving ownership,
  -- but looked like a separate Gen-2 HUD instead of the same product skin.
  panel={0.018, 0.022, 0.030},
  -- Kanto's production rule: shared charcoal ORAS furniture, with only the
  -- thin outer signal recoloured for the active cartridge edition.
  frame={0.040, 0.800, 0.970},
  selection={0.965, 0.185, 0.120},
  selectionFrame={1.000, 0.710, 0.180},
  accent={0.955, 0.170, 0.135},
  neutral={0.965, 0.975, 0.990},
}

local cache = {}

local function explicitEdition(game)
  if type(game) == "string" then return game end
  if type(game) ~= "table" then return nil end
  local save = game.save or game
  return type(save) == "table" and (save.version or save.edition) or nil
end

local function editionPalette(game)
  local explicit = explicitEdition(game)
  local border, id
  if EditionAccent and type(EditionAccent.color) == "function" then
    local ok, value, resolved = pcall(EditionAccent.color, explicit)
    if ok and type(value) == "table" then border, id = value, resolved end
  end
  id = tostring(id or explicit or "shared"):lower()
  if cache[id] then return cache[id], id end
  local palette = {}
  for key, value in pairs(ORAS) do palette[key] = value end
  palette.id = id
  palette.edition = id
  palette.frame = border or ORAS.frame
  cache[id] = palette
  return palette, id
end

local function recognizedEdition(value)
  value = tostring(value or ""):lower()
  value = value:gsub("pokemon", ""):gsub("pokémon", "")
               :gsub("[%s_%-]", "")
  return value == "red" or value == "blue" or value == "yellow"
      or value == "gold" or value == "silver" or value == "crystal"
      or value == "oras"
end

function Theme.resolve(game)
  return editionPalette(game)
end

function Theme.palette(id)
  if id == nil or recognizedEdition(id) then return editionPalette(id) end
  return nil
end

function Theme.editions()
  return { "red", "blue", "yellow", "gold", "silver", "crystal" }
end

Theme.apiVersion = 3
Theme.policy = "shared-oras-thin-edition-border"
Theme.palettes = setmetatable({ oras=ORAS }, {
  __index=function(_, id)
    if recognizedEdition(id) then return editionPalette(id) end
  end,
})

return Theme
