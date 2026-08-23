-- Loose user sprite overrides.  VASC ships no replacement art; it creates a
-- documented save-folder contract and resolves only valid PNGs found there.
-- Missing, malformed or removed files are exact pass-through to Game/KASC.

local V = ...
local LocalSprites = {}
local UserFiles = V.require("UserFiles")

LocalSprites.ROOT = "user/sprites"
LocalSprites.ENABLED_KEY = "localSprites.enabled"
local validation = {}
local enabled = false

local function info(path)
  return UserFiles.info(path, "file")
end


local DIRECTORIES = {
  "pokemon/front", "pokemon/back", "pokemon/dex", "pokemon/overworld",
  "pokemon/icons", "player", "trainers", "overworld",
}

function LocalSprites.ensureTree()
  return info(LocalSprites.ROOT .. "/README.txt") ~= nil
end

local function id(value)
  value = tostring(value or "UNKNOWN"):upper():gsub("[^A-Z0-9_%-]", "_")
  value = value:gsub("_+", "_"):gsub("^_", ""):gsub("_$", "")
  return value ~= "" and value or "UNKNOWN"
end

local function hash(value)
  local h = 2166136261
  for i = 1, #value do h = (h * 16777619 + value:byte(i)) % 2147483647 end
  return h
end

function LocalSprites.sourceKey(path)
  local stem = tostring(path or "sprite"):gsub("%.[Pp][Nn][Gg]$", "")
  stem = stem:gsub("[^A-Za-z0-9]+", "_"):gsub("^_", ""):gsub("_$", "")
  if stem == "" then stem = "sprite" end
  return (stem:lower() .. "_" .. ("%08x"):format(hash(tostring(path))))
end

local function validPng(path)
  local meta = info(path)
  if not meta then validation[path] = nil return false end
  local signature = tostring(meta.modtime or "") .. ":" .. tostring(meta.size or "")
  local held = validation[path]
  if held and held.signature == signature then return held.valid end
  local valid = true
  if love and love.image and type(love.image.newImageData) == "function" then
    local assetPath = UserFiles.path(path)
    local ok, image = false, nil
    if assetPath then ok, image = pcall(love.image.newImageData, assetPath) end
    if not ok or not image then
      valid = false
    else
      local okDim, w, h = pcall(image.getDimensions, image)
      valid = okDim and type(w) == "number" and type(h) == "number"
              and w >= 1 and h >= 1 and w <= 4096 and h <= 4096
      if type(image.release) == "function" then pcall(image.release, image) end
    end
  end
  validation[path] = { signature=signature, valid=valid }
  return valid
end

local function candidate(relative)
  local path = LocalSprites.ROOT .. "/" .. relative
  return validPng(path) and UserFiles.path(path) or nil
end

local function appendUnique(out, seen, value)
  value = id(value)
  if value ~= "UNKNOWN" and not seen[value] then
    seen[value] = true
    out[#out + 1] = value
  end
end

-- Most KASC Mega forms deliberately keep mon.species at the base species and
-- expose their visual form through mon._ascMegaForm. Turn that runtime state
-- into readable filenames without making VASC depend on KASC internals. The
-- raw form ID remains a fallback for future/third-party form controllers.
local function pokemonIds(ctx)
  ctx = ctx or {}
  local out, seen = {}, {}
  local species = id(ctx.species)
  local mon = type(ctx.mon) == "table" and ctx.mon or {}
  local form = mon._ascMegaForm or mon.formId or mon.form or ctx.formId
  if type(form) == "string" and form ~= "" then
    local formId = id(form)
    if formId == species then
      appendUnique(out, seen, species .. "_MEGA")
    elseif formId:sub(1, #species + 1) == species .. "_" then
      appendUnique(out, seen,
                   species .. "_MEGA_" .. formId:sub(#species + 2))
      appendUnique(out, seen, formId)
    else
      appendUnique(out, seen, formId)
    end
  end
  local letter = mon.unownLetter or ctx.letter
  if species == "UNOWN" and letter ~= nil then
    appendUnique(out, seen, species .. "_" .. tostring(letter))
  end
  appendUnique(out, seen, species)

  local shiny = ctx.shiny == true or mon.shiny == true
  if shiny then
    local withShiny = {}
    for _, value in ipairs(out) do withShiny[#withShiny + 1] = value .. "_SHINY" end
    for _, value in ipairs(out) do withShiny[#withShiny + 1] = value end
    out = withShiny
  end
  return out
end

local function pokemonCandidate(folder, ctx)
  for _, name in ipairs(pokemonIds(ctx)) do
    local found = candidate("pokemon/" .. folder .. "/" .. name .. ".png")
    if found then return found end
  end
end

local function pokemon(current, ctx)
  local kind, side = ctx and ctx.kind, ctx and ctx.side or "front"
  local found
  if kind == "dex" then found = pokemonCandidate("dex", ctx) end
  if not found and kind == "overworld" then
    found = pokemonCandidate("overworld", ctx)
  end
  if not found then
    found = pokemonCandidate(side == "back" and "back" or "front", ctx)
  end
  return found or current
end

local function player(current, ctx)
  local side = ctx and ctx.side == "back" and "back" or "front"
  local kind = id(ctx and ctx.kind):lower()
  local found = candidate("player/" .. kind .. "_" .. side .. ".png")
                or candidate("player/" .. side .. ".png")
  return found or current
end

local function icon(current, ctx)
  return pokemonCandidate("icons", ctx) or current
end

local function trainer(current, ctx)
  local trainerId = id(ctx and (ctx.trainerId or ctx.oppClass or ctx.id))
  return candidate("trainers/" .. trainerId .. ".png") or current
end

local function cloneDef(def, image)
  local out = {}
  for key, value in pairs(def or {}) do out[key] = value end
  out.image = image
  return out
end

local function overworld(current, ctx)
  if type(current) ~= "table" or type(current.image) ~= "string" then return current end
  -- Registered Game/KASC sheets have stable public IDs. Prefer that readable
  -- contract over the historical source-hash fallback so a player can replace
  -- exact visual states such as SPRITE_KA_CRYSTAL_GREEN_BIKE without knowing
  -- where KASC stores the source PNG. Old engines/anonymous definitions still
  -- retain the byte-stable source key below.
  local rawId = current.id or (ctx and ctx.spriteId)
  local direct = type(rawId) == "string" and rawId ~= ""
                 and id(rawId) or nil
  local found = direct and candidate("overworld/" .. direct .. ".png") or nil
  if not found then
    found = candidate("overworld/" .. LocalSprites.sourceKey(current.image)
                      .. ".png")
  end
  return found and cloneDef(current, found) or current
end

function LocalSprites.resolve(kind, current, ctx)
  if not enabled then return current end
  if kind == "pokemon" then return pokemon(current, ctx) end
  if kind == "player" then return player(current, ctx) end
  if kind == "trainer" then return trainer(current, ctx) end
  if kind == "icon" then return icon(current, ctx) end
  if kind == "overworld" then return overworld(current, ctx) end
  return current
end

local function gameBuckets(game)
  local modId = (V.mod and V.mod.id) or "VOXEL_ASCENDANT"
  local options = game and game.save and game.save.options
  if options then
    options.modOptions = options.modOptions or {}
    options.modOptions[modId] = options.modOptions[modId] or {}
  end
  local loader = game and game.mods
  if loader then
    loader.modOptions = loader.modOptions or {}
    loader.modOptions[modId] = loader.modOptions[modId] or {}
  end
  return options and options.modOptions[modId],
         loader and loader.modOptions[modId]
end

function LocalSprites.setEnabled(game, value)
  enabled = value == true
  local save, loader = gameBuckets(game)
  if save then save[LocalSprites.ENABLED_KEY] = enabled end
  if loader then loader[LocalSprites.ENABLED_KEY] = enabled end
  if game and type(game.writeOptions) == "function" then
    pcall(game.writeOptions, game)
  end
  return enabled
end

function LocalSprites.restore(game)
  local save, loader = gameBuckets(game)
  enabled = (save and save[LocalSprites.ENABLED_KEY]
             or loader and loader[LocalSprites.ENABLED_KEY]) == true
  return enabled
end

function LocalSprites.enabled() return enabled end

function LocalSprites.backToDefault(game)
  LocalSprites.setEnabled(game, false)
  local ok, packs = pcall(V.require, "SpritePacks")
  if ok and packs and type(packs.select) == "function" then
    packs.select("base", game)
  end
  return true
end

function LocalSprites.rescan()
  validation = {}
  return true
end

local function sortedKeys(value)
  local out = {}
  for key in pairs(value or {}) do out[#out + 1] = key end
  table.sort(out)
  return out
end

local inventoryText = ""

function LocalSprites.writeInventory(data)
  if type(data) ~= "table" then return false end
  local lines = {
    "VOXEL ASCENDANT - LIVE SPRITE INVENTORY\n",
    "Generated from the currently loaded Game + KASC data.\n",
    "All targets are relative to voxel_ascendant/user/sprites/.\n\n",
    "[POKEMON]\n",
  }
  for _, species in ipairs(sortedKeys(data.pokemon)) do
    local name = id(species)
    lines[#lines + 1] = "pokemon/front/" .. name .. ".png\n"
    lines[#lines + 1] = "pokemon/back/" .. name .. ".png\n"
    lines[#lines + 1] = "pokemon/dex/" .. name .. ".png\n"
    lines[#lines + 1] = "pokemon/icons/" .. name .. ".png\n"
    lines[#lines + 1] = "pokemon/overworld/" .. name .. ".png\n"
  end
  lines[#lines + 1] = "\n[OVERWORLD SPRITE IDS]\n"
  local spriteIds = {}
  for key, def in pairs(data.sprites or {}) do
    if type(def) == "table" and type(def.image) == "string" then
      local name = id(def.id or key)
      spriteIds[#spriteIds + 1] = {
        name=name, image=def.image,
        line="overworld/" .. name .. ".png <- " .. def.image .. "\n",
      }
    end
  end
  table.sort(spriteIds, function(a, b)
    if a.name ~= b.name then return a.name < b.name end
    return a.image < b.image
  end)
  for _, entry in ipairs(spriteIds) do lines[#lines + 1] = entry.line end

  lines[#lines + 1] = "\n[OVERWORLD SOURCE FALLBACKS]\n"
  local seen = {}
  for _, def in pairs(data.sprites or {}) do
    if type(def) == "table" and type(def.image) == "string" and not seen[def.image] then
      seen[def.image] = true
      lines[#lines + 1] = "overworld/" .. LocalSprites.sourceKey(def.image)
                          .. ".png <- " .. def.image .. "\n"
    end
  end
  lines[#lines + 1] = "\n[TRAINER BATTLE PORTRAITS]\n"
  for _, trainerId in ipairs(sortedKeys(data.trainers)) do
    lines[#lines + 1] = "trainers/" .. id(trainerId) .. ".png\n"
  end
  inventoryText = table.concat(lines)
  return true
end

function LocalSprites.inventory() return inventoryText end
function LocalSprites.pokemonIds(ctx) return pokemonIds(ctx) end

function LocalSprites.row(mod)
  return {
    id=((V.mod and V.mod.id) or "VOXEL_ASCENDANT") .. ":localSprites",
    label="USER SPRITES",
    value=function() return enabled and "ON" or "GAME/KASC" end,
    activate=function(game) mod.ui.push(game, "VascUserSprites") end,
  }
end

function LocalSprites.install(mod)
  LocalSprites.ensureTree()
  local screens = mod and mod.content and mod.content.screens
  if screens and type(screens.register) == "function" then
    screens:register("VascUserSprites", {
      new=function(game)
        local items = {
          {label="CUSTOM SPRITES", right=enabled and "ON" or "OFF",
           action="toggle"},
          {label="BACK TO GAME / KASC", action="default"},
          {label="RESCAN PNG FILES", action="rescan"},
          {label="README + INDEX", action="help"},
          {label="POKEMON: FRONT/BACK"},
          {label="PLAYER + TRAINERS"},
          {label="DEX/ICONS/OVERWORLD"},
        }
        return mod.ui.ListMenu.new(game, "USER SPRITES", items, {
          onChoose=function(item, menu)
            if item.action == "toggle" then
              LocalSprites.setEnabled(game, not enabled)
              menu:close()
            elseif item.action == "default" then
              LocalSprites.backToDefault(game)
              menu:close()
            elseif item.action == "rescan" then
              LocalSprites.rescan()
              LocalSprites.writeInventory(game.data)
              LocalSprites.setEnabled(game, true)
              menu:close()
            elseif item.action == "help" then
              LocalSprites.writeInventory(game.data)
              mod.ui.push(game, "VascUserSpritesHelp")
            end
          end,
        })
      end,
    })
    screens:register("VascUserSpritesHelp", {
      new=function(game)
        local items = {
          {label="SAVE DIR/MODS/"},
          {label="VOXEL_ASCENDANT/USER/"},
          {label="SPRITES/<TYPE>"},
          {label="FRONT: PIKACHU.PNG"},
          {label="FORM: CHARIZARD_MEGA_X"},
          {label="PLAYER: BATTLE_FRONT"},
          {label="WIN: %APPDATA%/LOVE"},
          {label="MAC: LIBRARY/APP SUPPORT"},
          {label="LINUX: .LOCAL/SHARE/LOVE"},
          {label="IOS: FILES/GEN1RECOMP++"},
          {label="ANDROID: ANDROID/DATA"},
          {label="README_EN + README_DE"},
          {label="BACK = GAME/KASC"},
        }
        return mod.ui.ListMenu.new(game, "SPRITE NAMING", items, {
          onChoose=function(_, menu) menu:close() end,
        })
      end,
    })
  end
  return true
end

return LocalSprites
