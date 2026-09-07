-- Categorized options browser for Voxel Ascendant Gen 2.
--
-- Gen1Recomp's ManagerState options_schema support intentionally exposes one
-- flat list.  This mod now has enough controls that the list is unwieldy on a
-- phone, so keep ManagerState as the option/persistence owner but present THIS
-- mod through a small category root.  Entering a category swaps optionRows for
-- a subset built by ManagerState:buildOptionRows(), so toggles, choices,
-- persistence, mod.options_changed and RESET DEFAULTS all keep the engine's
-- existing behavior.

local V = ...
local mod = V and V.mod

local M = {
  installed = false,
  opens = 0,
  categoryOpens = 0,
  lastError = nil,
}

local MOD_ID = (mod and mod.id) or "VOXEL_ASCENDANT"

local function customUIEnabled()
  -- `customUI` was retired and is deliberately persisted as false by the
  -- Gen-2 upgrader to disable wrappers from old VASC builds.  It must never
  -- gate the current renderer generation; the visible per-surface choices
  -- (qol_ui_skin, battleHudStyle, party skins) are authoritative now.
  return true
end

local CATEGORIES = {
  {
    id = "ui", label = "KASC / VASC MENUS",
    description = "Switch the gold-and-silver Johto menu shell on or return to Gold's originals.",
    keys = { customUI=true },
  },
  {
    id = "world", label = "VOXEL VIEW + WORLD",
    description = "Diorama/third/first-person view, voxel world, OPEN WORLD, renderer cost and weather.",
    keys = {
      cameraMode=true, voxel3d=true, openWorld=true, gen2WorldMap=true,
      voxelDiskCache=true,
      grid=true, curve=true, water=true,
      renderScale=true, shadowQuality=true,
      deviceProfile=true, sky=true, clouds=true, skyEvents=true,
      weather=true, scenery=true, shadows=true, daytime=true,
    },
  },
  {
    id = "camera", label = "CAMERA / DISPLAY",
    description = "Advanced camera ownership, zoom, antialiasing and Android display controls.",
    keys = {
      cameraControl=true, worldZoomRange=true, aa=true,
      cameraSlider=true, screenFlip=true,
    },
  },
  {
    id = "battle", label = "BATTLE",
    description = "Live 3D battles, cinematic camera and independent battle grid. Gold owns the HUD.",
    keys = {
      battle3dWorld=true, battleSmartCamera=true,
      battleGrid=true,
    },
  },
  {
    id = "models", label = "3D MODELS",
    description = "Independent Pokémon/player 3D model layers and Stadium 2 model-pack source.",
    keys = {
      stadium3dSprites=true, pokemonModelSkin=true,
      player3dModel=true, stadiumRomFile=true,
    },
  },
  {
    id = "wilds", label = "WILD POKéMON",
    description = "Visible wild Pokémon, sprite style, spawn density and terrain rules.",
    keys = {
      enabled=true, sprite_style=true, sprite_fade=true,
      spawn_density=true, random_encounters=true,
      water_spawns=true, cave_spawns=true, town_pokemon=true,
      pokemon_grass_render_mode=true, wild_silhouettes=true,
    },
  },
  {
    id = "followers", label = "FOLLOWERS / BEHAVIOR",
    description = "Lead follower, Pokémon control and roaming behavior.",
    keys = {
      partyFollower=true, follow_control=true, trainer_trail=true,
      follower_count=true, enable_idle=true, enable_wander=true,
      enable_aggressive=true, enable_hidden=true,
    },
  },
  {
    id = "comfort", label = "FIELD / COMFORT",
    description = "Independent field presentations and safe KASC-style Gen-2 conveniences. FIELD KIT remains off by default.",
    keys = {
      speciesSurfPresentation=true, fieldKitPresentation=true,
      speciesFlyPresentation=true, fishingPresentation=true,
      qolExpBar=true, qolCaughtIndicator=true, battleGender=true,
      statusValues=true, qolLocationBanners=true, qolEasyInteractions=true,
      qolRegisteredItem=true, qolCatchBoxNotice=true,
      qolFastBoxSwitch=true, qolModernBallSkins=true,
    },
  },
  {
    id = "developer", label = "DEVELOPER",
    description = "Debug and diagnostic controls.",
    keys = { dev_overlay=true },
  },
}

local byId = {}
for _, category in ipairs(CATEGORIES) do byId[category.id] = category end

local OPTION_TYPES = { toggle=true, choice=true, number=true, text=true }

local function optionSchema(self, m)
  if self and type(self.schemaFor) == "function" then
    local ok, schema = pcall(self.schemaFor, self, m)
    if ok and type(schema) == "table" then return schema end
  end
  return nil
end

local function schemaSubset(schema, category)
  local out = {}
  for _, row in ipairs(schema or {}) do
    if type(row) == "table" and category.keys[row.key] then
      out[#out + 1] = row
    end
  end
  return out
end

local function categorizedKeys()
  local set = {}
  for _, category in ipairs(CATEGORIES) do
    for key in pairs(category.keys) do set[key] = true end
  end
  return set
end

local KNOWN_KEYS = categorizedKeys()

local function uncategorizedSubset(schema)
  local out = {}
  for _, row in ipairs(schema or {}) do
    if type(row) == "table" and type(row.key) == "string"
       and not KNOWN_KEYS[row.key] then
      out[#out + 1] = row
    end
  end
  return out
end

local function countOptions(schema)
  local n = 0
  for _, row in ipairs(schema or {}) do
    if type(row) == "table" and type(row.key) == "string"
       and OPTION_TYPES[row.type] then
      n = n + 1
    end
  end
  return n
end

local showRoot, showCategory

local function rememberRootPosition(self)
  if not self then return end
  if self._stadium2OptionCategory == nil then
    self._stadium2RootCursor = tonumber(self.cursor) or 1
    self._stadium2RootScroll = tonumber(self.scroll) or 0
  end
end

showCategory = function(self, categoryId)
  -- Preserve the exact category-folder row the player entered from.  The
  -- engine's flat options screen normally resets cursor/scroll when a new row
  -- set is installed; without this, B from any category always jumped to the
  -- first folder instead of returning to the folder just opened.
  rememberRootPosition(self)
  local category = byId[categoryId]
  local schema = self and self._stadium2FullOptionSchema
  local currentMod = self and self._stadium2CategorizedMod
  if not (category and type(schema) == "table" and currentMod) then return false end
  local subset = schemaSubset(schema, category)
  if #subset == 0 then return false end
  if type(self.buildOptionRows) ~= "function" then return false end

  local ok, rows = pcall(self.buildOptionRows, self, currentMod, subset)
  if not ok or type(rows) ~= "table" then
    M.lastError = "category build failed: " .. tostring(rows)
    return false
  end

  self.optionRows = rows
  self.cursor = 1
  self.scroll = 0
  self._stadium2OptionCategory = category.id
  self._stadium2OptionCategoryLabel = category.label
  self._stadium2OptionCategoryDescription = category.description
  M.categoryOpens = M.categoryOpens + 1
  M.lastError = nil
  return true
end

showRoot = function(self, restorePosition)
  if not customUIEnabled() then return false end
  local schema = self and self._stadium2FullOptionSchema
  local currentMod = self and self._stadium2CategorizedMod
  if not (type(schema) == "table" and currentMod) then return false end

  local rows = {}
  for _, category in ipairs(CATEGORIES) do
    local subset = schemaSubset(schema, category)
    if #subset > 0 then
      local catId = category.id
      rows[#rows + 1] = {
        id = "__stadium_category_" .. catId,
        label = category.label,
        value = function() return tostring(countOptions(subset)) .. " SETTINGS" end,
        activate = function() showCategory(self, catId) end,
      }
    end
  end

  -- Future options should never disappear just because this release did not
  -- know their category yet.  They land in OTHER automatically.
  local other = uncategorizedSubset(schema)
  if #other > 0 then
    rows[#rows + 1] = {
      id = "__stadium_category_other",
      label = "OTHER",
      value = function() return tostring(countOptions(other)) .. " SETTINGS" end,
      activate = function()
        rememberRootPosition(self)
        if type(self.buildOptionRows) ~= "function" then return end
        local ok, built = pcall(self.buildOptionRows, self, currentMod, other)
        if ok and type(built) == "table" then
          self.optionRows = built
          self.cursor, self.scroll = 1, 0
          self._stadium2OptionCategory = "other"
          self._stadium2OptionCategoryLabel = "OTHER"
          self._stadium2OptionCategoryDescription = "Additional settings not assigned to a category yet."
        end
      end,
    }
  end

  rows[#rows + 1] = {
    id = "__stadium_reset_all",
    label = "RESET ALL DEFAULTS",
    value = function() return "" end,
    activate = function()
      if type(self.setOption) ~= "function" then return end
      for _, row in ipairs(schema) do
        if type(row) == "table" and type(row.key) == "string"
           and OPTION_TYPES[row.type] then
          self:setOption(MOD_ID, row.key, row.default)
        end
      end
      if type(self.notify) == "function" then self:notify("ALL DEFAULTS RESTORED") end
    end,
  }

  self.optionRows = rows
  if restorePosition then
    self.cursor = math.max(1, math.min(#rows, tonumber(self._stadium2RootCursor) or 1))
    self.scroll = math.max(0, tonumber(self._stadium2RootScroll) or 0)
    -- Keep a stale saved scroll from placing the restored cursor outside the
    -- visible window after categories are added/removed between opens.
    if self.cursor < self.scroll + 1 then self.scroll = math.max(0, self.cursor - 1) end
  else
    self.cursor = 1
    self.scroll = 0
    self._stadium2RootCursor = 1
    self._stadium2RootScroll = 0
  end
  self._stadium2OptionCategory = nil
  self._stadium2OptionCategoryLabel = nil
  self._stadium2OptionCategoryDescription = nil
  self._stadium2CategorizedOptions = true
  return true
end

function M.install()
  if M.installed then return true end
  local ok, ManagerState = pcall(require, "src.mods.ManagerState")
  if not (ok and type(ManagerState) == "table") then
    return false, "src.mods.ManagerState unavailable"
  end
  if ManagerState._stadium2CategoriesPatched then
    M.installed = true
    return true
  end
  if type(ManagerState.openOptions) ~= "function"
      or type(ManagerState.updateOptions) ~= "function" then
    return false, "ManagerState options methods unavailable"
  end

  local nativeOpen = ManagerState.openOptions
  local nativeUpdate = ManagerState.updateOptions

  ManagerState.openOptions = function(self, m, ...)
    -- Clear old category state before opening any add-on, including another mod.
    self._stadium2CategorizedOptions = nil
    self._stadium2FullOptionSchema = nil
    self._stadium2CategorizedMod = nil
    self._stadium2OptionCategory = nil
    self._stadium2OptionCategoryLabel = nil
    self._stadium2OptionCategoryDescription = nil
    self._stadium2RootCursor = 1
    self._stadium2RootScroll = 0

    local result = nativeOpen(self, m, ...)
    if not (m and m.id == MOD_ID and self.screen == "options") then return result end
    if not customUIEnabled() then return result end

    local schema = optionSchema(self, m)
    if not schema then
      M.lastError = "this mod option schema unavailable"
      return result
    end
    self._stadium2FullOptionSchema = schema
    self._stadium2CategorizedMod = m
    if showRoot(self, false) then
      M.opens = M.opens + 1
      M.lastError = nil
    end
    return result
  end

  ManagerState.updateOptions = function(self, input, ...)
    if self and self._stadium2CategorizedOptions and not customUIEnabled() then
      self._stadium2CategorizedOptions = nil
      self._stadium2OptionCategory = nil
      self._stadium2OptionCategoryLabel = nil
      self._stadium2OptionCategoryDescription = nil
      -- Rebuild the engine's ordinary flat options list immediately so the
      -- CUSTOM UI toggle can switch to native menus without requiring restart.
      local currentMod = self._stadium2CategorizedMod
      local schema = self._stadium2FullOptionSchema
      if currentMod and type(schema) == "table" and type(self.buildOptionRows) == "function" then
        local okRows, rows = pcall(self.buildOptionRows, self, currentMod, schema)
        if okRows and type(rows) == "table" then
          self.optionRows = rows
          self.cursor, self.scroll = 1, 0
        end
      end
    end
    if self and self._stadium2CategorizedOptions and self.screen == "options"
       and self._stadium2OptionCategory ~= nil
       and input and type(input.wasPressed) == "function"
       and input:wasPressed("b") then
      if showRoot(self, true) then return end
    end
    return nativeUpdate(self, input, ...)
  end

  ManagerState._stadium2CategoriesPatched = true
  M.installed = true
  return true
end

M.showRoot = showRoot
M.showCategory = showCategory
M.categories = CATEGORIES

function M.status()
  return {
    installed = M.installed,
    opens = M.opens,
    categoryOpens = M.categoryOpens,
    lastError = M.lastError,
    modId = MOD_ID,
  }
end

return M
