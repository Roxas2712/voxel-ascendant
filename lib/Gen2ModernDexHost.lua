-- Gen-2 host for the reviewed Gen-1 ASCENDANT DEX presentation.
--
-- The renderer in lib/ModernDex.lua remains the visual owner: red hardware
-- shell, camera lens, status LEDs, list/entry rails and 512x288 layout.  This
-- adapter changes only the data and screen boundaries needed by Game2.  Gold,
-- Silver and Crystal keep their own Pokedex save flags and the native screen
-- remains the fail-open owner when GAME DEFAULT is selected or construction
-- fails.

local V = ...
local mod = assert(V and V.mod, "Gen2ModernDexHost needs mod")

local M = { installed=false, active=false, lastError=nil }
local proxies = setmetatable({}, { __mode="k" })
local panorama
local SAVE_KEY = "gen2AscendantDex"
local Gen2CrystalFronts
if V and type(V.require) == "function" then
  local ok, value = pcall(V.require, "Gen2CrystalFronts")
  if ok and type(value) == "table" then Gen2CrystalFronts = value end
end

local function log(level, message, ...)
  local logger = mod.log
  local fn = logger and logger[level]
  if type(fn) == "function" then pcall(fn, logger, message, ...) end
end

local function useModern()
  local options = mod.options
  if not (options and type(options.get) == "function") then return true end
  local ok, value = pcall(options.get, options, "qol_ui_skin")
  if not ok or value == nil then return true end
  value = tostring(value):lower()
  return value ~= "standard" and value ~= "native"
    and value ~= "game_default" and value ~= "off"
end

local function copy(source)
  local out = {}
  for key, value in pairs(type(source) == "table" and source or {}) do
    out[key] = value
  end
  return out
end

local function speciesDex(game, species)
  if not species then return nil end
  local data = game and game.data or {}
  local definition = data.pokemon and data.pokemon[species]
  local entry = data.gen2Pokedex and data.gen2Pokedex.entries
    and data.gen2Pokedex.entries[species]
  return tonumber(definition and definition.dex)
    or tonumber(entry and entry.dex)
end

local function ownsGen3(game)
  local save = game and game.save or {}
  local function isGen3(species)
    local number = speciesDex(game, species)
    return number and number >= 252 and number <= 386
  end
  for species, owned in pairs(save.pokedex and
      (save.pokedex.owned or save.pokedex.caught) or {}) do
    if owned and isGen3(species) then return true end
  end
  for _, mon in ipairs(save.party or {}) do
    if isGen3(type(mon) == "table" and (mon.species or mon.id) or mon) then
      return true
    end
  end
  for _, box in pairs(save.boxes or {}) do
    if type(box) == "table" then
      for _, mon in ipairs(box) do
        if isGen3(type(mon) == "table" and (mon.species or mon.id) or mon) then
          return true
        end
      end
    end
  end
  return false
end

local function savedGlobalUnlock()
  local saveApi = mod and mod.save
  if not (saveApi and type(saveApi.get) == "function") then return false end
  local ok, state = pcall(saveApi.get, saveApi, SAVE_KEY)
  return ok and type(state) == "table" and state.globalUnlocked == true
end

local function storeGlobalUnlock()
  local saveApi = mod and mod.save
  if not (saveApi and type(saveApi.set) == "function") then return false end
  local ok = pcall(saveApi.set, saveApi, SAVE_KEY, {
    schema="voxel-ascendant/gen2-ascendant-dex/v1",
    globalUnlocked=true,
  })
  return ok
end

local function globalDexUnlocked(game)
  if savedGlobalUnlock() then return true end
  if not ownsGen3(game) then return false end
  storeGlobalUnlock()
  return true
end

local function gameProxy(game)
  if proxies[game] then return proxies[game] end
  local data = copy(game and game.data)
  local pokemon = {}
  local dex = data.gen2Pokedex
  for species, definition in pairs(data.pokemon or {}) do
    local row = copy(definition)
    local entry = dex and dex.entries and dex.entries[species]
    if entry then
      row.dex = row.dex or entry.dex
      row.dexEntry = row.dexEntry or entry
    end
    pokemon[species] = row
  end
  data.pokemon = pokemon

  local save = copy(game and game.save)
  local pokedex = copy(save.pokedex)
  pokedex.owned = pokedex.owned or pokedex.caught or {}
  save.pokedex = pokedex

  local proxy = setmetatable({ data=data, save=save }, { __index=game })
  proxies[game] = proxy
  return proxy
end

local function panoramaImage()
  if panorama ~= nil then return panorama or nil end
  local path = tostring(mod.path or "VOXEL_ASCENDANT")
    .. "/assets/ui/gen2/johto_kanto_panorama.png"
  local image
  if type(mod.assets) == "table" and type(mod.assets.image) == "function" then
    local ok, value = pcall(mod.assets.image, mod.assets,
      "assets/ui/gen2/johto_kanto_panorama.png")
    if ok then image = value end
  end
  if not image and love and love.graphics
      and type(love.graphics.newImage) == "function" then
    local ok, value = pcall(love.graphics.newImage, path)
    if ok then image = value end
  end
  panorama = image or false
  if image and type(image.setFilter) == "function" then
    pcall(image.setFilter, image, "linear", "linear")
  end
  return image
end

local FRAME = {
  johto={ x=.010, y=.055, w=.620, h=.850 },
  kanto={ x=.585, y=.060, w=.405, h=.835 },
}

local function areaProvider()
  return {
    apiVersion=1,
    resolve=function(game, species)
      local image = panoramaImage()
      local okNests, Nests = pcall(require, "src.core.gen2.Nests")
      if not (image and okNests and type(Nests) == "table"
          and type(Nests.find) == "function") then return nil end
      local data, save = game and game.data, game and game.save
      local width, height = image:getDimensions()
      local markers = {}
      for _, index in ipairs(Nests.find(data, species, nil, save) or {}) do
        local entry = type(Nests.landmark) == "function"
          and Nests.landmark(data, index) or nil
        local region = type(Nests.regionOf) == "function"
          and Nests.regionOf(index) or nil
        local frame = region and FRAME[region]
        if entry and frame then
          local nx = math.max(0, math.min(159, tonumber(entry.x) or 0)) / 159
          local ny = math.max(0, math.min(143, tonumber(entry.y) or 0)) / 143
          markers[#markers + 1] = {
            id=entry.id or index,
            x=(frame.x + nx * frame.w) * width,
            y=(frame.y + ny * frame.h) * height,
          }
        end
      end
      return {
        image=image, width=width, height=height, markers=markers,
        species=species, source="VOXEL_ASCENDANT:gen2-world-atlas",
      }
    end,
  }
end

local function featureMod()
  local feature = setmetatable({
    id=mod.id, path=mod.path, log=mod.log,
    options={ get=function(_, key)
      if key == "sprite_source" then return "kasc_crystal" end
    end },
  }, { __index=mod })
  feature.find = function(first, second)
    local id = first == feature and second or first
    -- The Gen-2 card ships the reviewed coloured Crystal fronts itself.  The
    -- shared Gen-1 Dex asks for them through KASC's public provider contract,
    -- so satisfy that contract locally instead of falling through to the
    -- monochrome cartridge sprite when KASC is not installed/active.
    if id == "kanto_ascendant" and type(Gen2CrystalFronts) == "table"
        and type(Gen2CrystalFronts.resolve) == "function" then
      return {
        id="VOXEL_ASCENDANT:gen2-crystal-fronts", enabled=true,
        exports={ crystalSpriteProvider={
          apiVersion=1,
          resolveFront=function(gameOrData, mon, opts)
            return Gen2CrystalFronts.resolve(gameOrData, mon, opts)
          end,
        } },
      }
    end
    if id == "vasc_kanto_fly_map" then
      return { id="VOXEL_ASCENDANT:gen2-world-atlas", enabled=true,
        exports={ active=true, pokedexAreaProvider=areaProvider() } }
    end
    local finder = mod.find
    if type(finder) ~= "function" then return nil end
    local ok, value = pcall(finder, id)
    if ok then return value end
    ok, value = pcall(finder, mod, id)
    return ok and value or nil
  end
  return feature
end

local function loadUi()
  local relative = "lib/gen2_dex/AscendantDex.lua"
  local source, readError = mod:read(relative)
  if not source then return nil, tostring(readError or "AscendantDex missing") end
  local chunk, compileError = (loadstring or load)(source,
    "@" .. tostring(mod.path or "VOXEL_ASCENDANT") .. "/" .. relative)
  if not chunk then return nil, tostring(compileError) end
  local ok, ui = pcall(chunk, {
    mod=featureMod(),
    globalDexUnlocked=globalDexUnlocked,
  })
  if not ok then return nil, tostring(ui) end
  if type(ui) ~= "table" or type(ui.ListScreen) ~= "table"
      or type(ui.EntryScreen) ~= "table" then
    return nil, "ModernDex surface contract incomplete"
  end
  return ui
end

local function frameScale(width, height)
  return math.min((tonumber(width) or 0) * .90 / 512,
                  (tonumber(height) or 0) * .90 / 288)
end

local function fullscreen(state)
  if type(state) ~= "table" or type(state.draw) ~= "function" then return state end
  local logicalDraw = state.draw
  state.drawsWidescreen = function() return true end
  state.wantsFillScale = function() return true end
  state.drawWidescreen = function(self, width, height)
    local G = love and love.graphics
    if not (G and width and height and width > 0 and height > 0) then
      return logicalDraw(self)
    end
    G.push("all")
    G.origin()
    G.setColor(.008, .014, .025, 1)
    G.rectangle("fill", 0, 0, width, height)
    -- Menus are a centred 16:9 card, matching the supplied Gen-2 Team/Bag
    -- presentation.  They are widescreen-aware but deliberately not
    -- edge-to-edge fullscreen.
    local scale = frameScale(width, height)
    G.translate((width - 512 * scale) * .5, (height - 288 * scale) * .5)
    G.scale(scale, scale)
    local ok, reason = pcall(logicalDraw, self)
    G.pop()
    if not ok then error(reason, 0) end
  end
  state.__vascGen2AscendantDex = true
  -- GoldSubmenuBattleStyle's generic responsive fallback watches pushed
  -- screens.  Mark this state as already resolved so it cannot replace the
  -- reviewed red Gen-1 Ascendant renderer after construction.
  state._vascGen2ResolvedPresentation = "ascendant-dex"
  return state
end

function M.install()
  if M.installed then return M.active, M.lastError end
  local screens = mod.content and mod.content.screens
  if not (screens and type(screens.override) == "function") then
    M.installed, M.lastError = true, "screen override registry unavailable"
    return false, M.lastError
  end
  local okNative, Native = pcall(require, "src.ui.gen2.PokedexMenu")
  if not (okNative and type(Native) == "table" and type(Native.new) == "function") then
    M.installed, M.lastError = true, "native Gen-2 Pokedex unavailable"
    return false, M.lastError
  end
  local nativeNew = Native.new
  local ui, reason = loadUi()
  if not ui then
    M.installed, M.lastError = true, reason
    return false, reason
  end

  local listFactory = {
    new=function(game, opts)
      if not useModern() then return nativeNew(game, opts) end
      opts = type(opts) == "table" and opts or {}
      local constructor = opts.entrySpecies and ui.EntryScreen.new
        or ui.ListScreen.new
      local stateOpts = {
        onCancel=opts.onClose,
        modeIndex=opts.modeIndex,
        regionIndex=opts.regionIndex,
        species=opts.species or opts.entrySpecies,
        forceOwned=opts.newEntry == true,
        newEntry=opts.newEntry == true,
        language=opts.language,
      }
      local ok, state = pcall(constructor, gameProxy(game), stateOpts)
      if ok and type(state) == "table" then
        state.screenId = "Gen2PokedexMenu"
        return fullscreen(state)
      end
      log("warn", "Gen-2 ASCENDANT DEX list failed; native fallback: %s",
        tostring(state))
      return nativeNew(game, opts)
    end,
  }
  -- Current Game2 opens Gen2PokedexMenu; older compatibility hosts and the
  -- shared StartMenu route use PokedexMenu. Both must resolve to the same
  -- red-header Ascendant list, not just the DexEntry detail screen.
  screens:override("Gen2PokedexMenu", listFactory)
  screens:override("PokedexMenu", listFactory)
  screens:override("DexEntryMenu", {
    new=function(game, speciesOrOpts)
      local ok, state = pcall(ui.EntryScreen.new, gameProxy(game), speciesOrOpts)
      if ok and type(state) == "table" then
        state.screenId = "DexEntryMenu"
        return fullscreen(state)
      end
      local species = type(speciesOrOpts) == "table"
        and (speciesOrOpts.species or speciesOrOpts[1]) or speciesOrOpts
      return nativeNew(game, { entrySpecies=species })
    end,
  })

  M.installed, M.active = true, true
  mod.exports = mod.exports or {}
  mod.exports.gen2ModernDex = {
    apiVersion=1, active=true, owner="vasc.gen2.ascendant-dex",
    source="lib/gen2_dex/AscendantDex.lua", logicalSize={ 512, 288 },
    screen="Gen2PokedexMenu", nativeFallback=true,
    frameSource="lib/ModernDex.lua",
    initialOrder="johto-first-national",
    firstSpecies="CHIKORITA", firstDisplayNumber=1,
    globalUnlock="first-owned-gen3-species",
    globalUnlockPersistent=true,
  }
  return true, mod.exports.gen2ModernDex
end

function M.status()
  return {
    installed=M.installed, active=M.active, lastError=M.lastError,
    globalUnlocked=savedGlobalUnlock(),
  }
end

M._ownsGen3 = ownsGen3
M._globalDexUnlocked = globalDexUnlocked
M._frameScale = frameScale

return M
