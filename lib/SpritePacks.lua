-- Runtime registry for optional sprite packs. Voxel Ascendant ships no
-- replacement art: another, separately installed mod registers a provider
-- with provenance and a pinned package hash, and the player selects it here.

local V = ...
local SpritePacks = {}

SpritePacks.API_VERSION = 1
SpritePacks.KEY = "spritePreset"

local packs, order = {}, {}
local selected = "base"

local function validId(id)
  return type(id) == "string" and id:match("^[A-Za-z0-9_.%-]+$") ~= nil
end

local function https(value)
  return type(value) == "string" and value:match("^https://[^%s]+$") ~= nil
end

local function validHash(value)
  return type(value) == "string" and #value == 64
         and value:match("^[0-9a-fA-F]+$") ~= nil
end

local function validProviders(value)
  if type(value) ~= "table" then return false end
  local found = false
  for _, key in ipairs({ "pokemon", "player", "icon", "overworld" }) do
    if value[key] ~= nil and type(value[key]) ~= "function" then return false end
    found = found or type(value[key]) == "function"
  end
  return found
end

local function gameBuckets(game)
  local id = (V.mod and V.mod.id) or "VOXEL_ASCENDANT"
  local opts = game and game.save and game.save.options
  if opts then
    opts.modOptions = opts.modOptions or {}
    opts.modOptions[id] = opts.modOptions[id] or {}
  end
  local loader = game and game.mods
  if loader then
    loader.modOptions = loader.modOptions or {}
    loader.modOptions[id] = loader.modOptions[id] or {}
  end
  return opts and opts.modOptions[id], loader and loader.modOptions[id]
end

local function persist(game)
  local save, loader = gameBuckets(game)
  if save then save[SpritePacks.KEY] = selected end
  if loader then loader[SpritePacks.KEY] = selected end
  if game and game.writeOptions then pcall(game.writeOptions, game) end
end

function SpritePacks.register(pack)
  if type(pack) ~= "table" or not validId(pack.id)
     or pack.id == "base" or packs[pack.id]
     or type(pack.label) ~= "string" or pack.label == ""
     or type(pack.version) ~= "string" or pack.version == ""
     or not https(pack.sourceUrl) or not validHash(pack.sha256)
     or type(pack.license) ~= "table"
     or type(pack.license.spdx) ~= "string" or pack.license.spdx == ""
     or not https(pack.license.url)
     or not validProviders(pack.providers) then
    return nil, "invalid or duplicate sprite-pack receipt"
  end
  local receipt = {
    id = pack.id, label = pack.label, version = pack.version,
    sourceUrl = pack.sourceUrl, sha256 = string.lower(pack.sha256),
    license = { spdx = pack.license.spdx, url = pack.license.url },
    providers = pack.providers,
  }
  packs[pack.id] = receipt
  order[#order + 1] = pack.id
  table.sort(order)
  return function()
    if packs[pack.id] ~= receipt then return false end
    packs[pack.id] = nil
    for i = #order, 1, -1 do
      if order[i] == pack.id then table.remove(order, i) break end
    end
    return true
  end
end

function SpritePacks.select(id, game)
  if id ~= "base" and not packs[id] then return false end
  selected = id
  persist(game)
  return true
end

function SpritePacks.restore(game)
  local save, loader = gameBuckets(game)
  local value = save and save[SpritePacks.KEY]
                or loader and loader[SpritePacks.KEY]
  selected = validId(value) and value or "base"
  return SpritePacks.active()
end

function SpritePacks.active()
  return packs[selected], selected
end

function SpritePacks.list()
  local out = {{ id="base", label="GAME/KASC", bundled=true }}
  for _, id in ipairs(order) do
    local p = packs[id]
    out[#out + 1] = {
      id=p.id, label=p.label, version=p.version, sourceUrl=p.sourceUrl,
      sha256=p.sha256, license={spdx=p.license.spdx, url=p.license.url},
      bundled=false,
    }
  end
  return out
end

local function cloneDef(def, image)
  if type(def) ~= "table" then return def end
  local out = {}
  for k, v in pairs(def) do out[k] = v end
  out.image = image
  return out
end

local function validSpriteDef(def)
  return type(def) == "table" and type(def.image) == "string"
         and def.image ~= "" and type(def.frames) == "number"
         and def.frames == math.floor(def.frames)
         and def.frames >= 1 and def.frames <= 256
end

function SpritePacks.resolve(kind, current, ctx)
  local pack = packs[selected]
  local provider = pack and pack.providers[kind]
  if type(provider) ~= "function" then return current end
  local ok, result = pcall(provider, current, ctx)
  if not ok or result == nil or result == false then return current end
  if kind == "overworld" then
    if type(result) == "string" and result ~= "" then
      return cloneDef(current, result)
    end
    return validSpriteDef(result) and result or current
  end
  return type(result) == "string" and result ~= "" and result or current
end

function SpritePacks.row()
  return {
    id = ((V.mod and V.mod.id) or "VOXEL_ASCENDANT") .. ":spritePreset",
    label = "SPRITE PACK",
    value = function()
      local pack = packs[selected]
      return pack and pack.label or (selected == "base" and "GAME/KASC"
             or "MISSING/" .. string.upper(selected))
    end,
    step = function(game, dir)
      local ids = { "base" }
      for _, id in ipairs(order) do ids[#ids + 1] = id end
      local at = 1
      for i, id in ipairs(ids) do if id == selected then at = i break end end
      at = ((at + (dir or 1) - 1) % #ids) + 1
      SpritePacks.select(ids[at], game)
      return true
    end,
  }
end

function SpritePacks.public()
  return {
    apiVersion = SpritePacks.API_VERSION,
    register = SpritePacks.register,
    select = SpritePacks.select,
    active = SpritePacks.active,
    list = SpritePacks.list,
    requirements = {
      separateMod=true, explicitUserInstall=true, https=true,
      sha256=true, licenseReceipt=true, bundledAssets=false,
      liveActivation=true,
    },
  }
end

return SpritePacks
