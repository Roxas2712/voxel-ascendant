-- Gen-2 registry/adapter for the upstream-compatible VascMenu controller.
--
-- Load with a small dependency bundle, then call install():
--   local Gen2Menu = loadLocal("lib/VascMenuGen2.lua", {
--     mod=mod, V=MenuV, Menu=VascMenu, Style=VascMenuStyle,
--     ModSetting=BaseV.require("ModSetting"), RomMenu=StadiumRomMenu,
--     RendererOptions=VascRendererOptions, onChanged=wilds.handleOptionsChanged,
--   })
--   Gen2Menu.install()
--
-- The adapter owns no game logic. It turns options.lua toggle/choice schemas
-- into the same local ModSetting descriptors VASC uses, while the engine and
-- existing option bridges remain persistence/runtime owners.

local C = ... or {}
local mod = C.mod or (C.V and C.V.mod) or (C.BaseV and C.BaseV.mod)
local V = C.V or C.BaseV

local M = {
  installed=false,
  screensInstalled=false,
  startHookInstalled=false,
  settingsByKey={},
  extraKeys={},
  lastError=nil,
}

local MENU_KEY = "voxel_ascendant"
local MENU_ORDER = 990
local HOOK_PRIORITY = 900

local SECTION_ORDER = {
  "world", "weather", "battle", "skins", "pokemon",
  "wilds", "performance", "user", "advanced",
}

local SECTION_KEYS = {
  world = {
    "voxel3d", "cameraMode", "worldZoomRange", "cameraSlider", "cameraControl",
    "shortcutToast", "openWorld", "gen2WorldMap", "grid", "curve", "water",
  },
  weather = {
    "sky", "clouds", "skyEvents", "weather", "weatherTweak", "scenery", "daytime",
  },
  battle = {
    "battle3dWorld", "battleSmartCamera", "battleGrid",
    "qolExpBar", "qolCaughtIndicator", "battleGender",
    "statusValues",
  },
  skins = {
    "pokemonUiPartyMenu", "pokemonUiBattleParty", "pokemonUiLegacyBank",
    "battleHudStyle",
    "battle_textbox_x", "battle_textbox_y",
    "battle_controls_scale", "battle_controls_x",
    "battle_controls_y", "battle_controls_shape", "battle_controls_transparency",
    "vascMenuSkin", "qol_ui_skin",
    "qol_bag_skin", "qol_bag_color", "qol_bag_body", "qol_bag_form",
    "pokedexStyle", "modernDexSpriteSource",
  },
  pokemon = {
    "stadium3dSprites", "pokemonModelSkin", "player3dModel",
    "speciesSurfPresentation", "fieldKitPresentation",
    "speciesFlyPresentation", "fishingPresentation",
    "qolLocationBanners", "qolEasyInteractions", "qolRegisteredItem",
    "qolCatchBoxNotice", "qolFastBoxSwitch", "qolModernBallSkins",
  },
  wilds = {
    "enabled", "sprite_style", "sprite_fade", "spawn_density",
    "random_encounters", "water_spawns", "cave_spawns", "town_pokemon",
    "pokemon_grass_render_mode", "wild_silhouettes", "partyFollower",
    "follow_control", "trainer_trail", "follower_count", "enable_idle",
    "enable_wander", "enable_aggressive", "enable_hidden",
  },
  performance = {
    "deviceProfile", "renderScale", "shadowQuality", "shadows", "aa",
  },
  user = {},
  advanced = {
    "voxelDiskCache", "screenFlip", "dev_overlay",
  },
}

local SECTION_META = {
  world = {
    title="VIEW + WORLD",
    help="Choose the complete voxel camera, open-world stitching, Johto map, terrain grid, curves and water.",
  },
  weather = {
    title="WEATHER + SCENERY",
    help="Time, Johto weather, sky events, clouds and map-aware scenery share one resolved outdoor state.",
  },
  battle = {
    title="VOXEL BATTLES",
    help="Keep Gold/Silver/Crystal's battle rules while choosing the voxel stage, Stadium camera and battle grid.",
  },
  skins = {
    title="SKINS & OVERLAYS",
    help="Choose ORAS GLASS or GAME DEFAULT independently for team, battle HUD and ordinary Gen-2 menus, plus the real wide Bag, Pokédex layout and Dex image source. Only presentation changes; native callbacks and rules remain authoritative.",
  },
  pokemon = {
    title="POKéMON + MODELS",
    help="Pokémon and player models plus the independently switchable Surf, Fly, Fishing and Field-Kit presentations. Native Crystal rules and outcomes remain authoritative.",
  },
  wilds = {
    title="WILDS / FOLLOWERS",
    help="Visible wild Pokémon, encounter presentation, follower control and roaming behaviour.",
  },
  performance = {
    title="PERFORMANCE",
    help="Device profile, internal resolution, antialiasing and shadow cost.",
  },
  user = {
    title="USER CONTENT",
    help="Choose KASC, VASC DEFAULT, RETRO or CUSTOM as one shared public content profile. Optional sources use receipts; VASC remains autonomous.",
  },
  advanced = {
    title="ADVANCED",
    help="Recovery, platform and developer controls. Ordinary players can leave these unchanged.",
  },
}

local function keySet(values)
  local out = {}
  for _, key in ipairs(values or {}) do out[key] = true end
  return out
end

local function dependency(explicit, name)
  if type(explicit) == "table" then return explicit end
  if V and type(V.require) == "function" then
    local ok, value = pcall(V.require, name)
    if ok and type(value) == "table" then return value end
  end
  return nil
end

local function schemaFromFile(supplied)
  if type(supplied) == "table" then return supplied end
  if not (mod and type(mod.read) == "function") then
    return nil, "mod:read unavailable"
  end
  local source, readErr = mod:read("options.lua")
  if not source then return nil, tostring(readErr or "options.lua unavailable") end
  local loadcode = loadstring or load
  local chunk, compileErr = loadcode(source, "@" .. tostring(mod.path or "VOXEL_ASCENDANT") .. "/options.lua")
  if not chunk then return nil, tostring(compileErr) end
  local ok, schema = pcall(chunk)
  if not ok or type(schema) ~= "table" then
    return nil, tostring(ok and "options.lua did not return a table" or schema)
  end
  return schema
end

local function schemaMap(schema)
  local out = {}
  for _, spec in ipairs(schema or {}) do
    if type(spec) == "table" and type(spec.key) == "string" then
      out[spec.key] = spec
    end
  end
  return out
end

local function settingLadder(spec)
  if spec.type == "toggle" then
    return { false, true }, { "OFF", "ON" }
  end
  if spec.type ~= "choice" then return nil end
  local values, labels = {}, {}
  local seen = {}
  for _, choice in ipairs(spec.choices or {}) do
    if type(choice) == "table" and choice[2] ~= nil then
      local token = type(choice[2]) .. ":" .. tostring(choice[2])
      if not seen[token] then
        seen[token] = true
        labels[#labels + 1] = tostring(choice[1] or choice[2])
        values[#values + 1] = choice[2]
      end
    end
  end
  if #values == 0 then return nil end
  return values, labels
end

local function syncAllSettings(settingsByKey)
  local options = mod and mod.options
  if not (options and type(options.get) == "function") then return false end
  local synced = false
  for key, setting in pairs(settingsByKey or {}) do
    if setting and type(setting.sync) == "function" then
      local okValue, value = pcall(options.get, options, key)
      if okValue then
        local okSync = pcall(setting.sync, setting, value)
        synced = okSync or synced
      end
    end
  end
  return synced
end

local function changedCallback(opts, key)
  return function(game, value)
    local payload = {
      mod=(mod and mod.id) or "VOXEL_ASCENDANT", key=key, value=value,
      source="vasc_menu", game=game,
    }
    local onChanged = opts.onChanged or C.onChanged
    if type(onChanged) == "function" then pcall(onChanged, payload) end
    local renderer = opts.rendererOptions or C.RendererOptions
    if renderer and type(renderer.handleOptionsChanged) == "function" then
      pcall(renderer.handleOptionsChanged, payload)
    elseif renderer and type(renderer.refresh) == "function" then
      pcall(renderer.refresh)
    end
    local pipeline = opts.pipelineBridge or C.PipelineBridge
    if (key == "voxel3d" or key == "openWorld")
        and pipeline and type(pipeline.sync) == "function" then
      pcall(pipeline.sync, game)
    end
    local voxel = opts.voxelBridge or C.VoxelBridge
    if key == "voxel3d" and voxel
        and type(voxel.handleUserVoxelOption) == "function" then
      pcall(voxel.handleUserVoxelOption, value)
    end
    -- DEVICE can rewrite several child values, and a manual child change can
    -- in turn rewrite DEVICE to CUSTOM. Hub ModSetting objects are deliberately
    -- separate from renderer-owned ones, so pull every resulting value back
    -- from the canonical option bucket before the active page is rebuilt.
    syncAllSettings(M.settingsByKey)
  end
end

local function makeSetting(ModSetting, spec, opts)
  local values, labels = settingLadder(spec)
  if not values then return nil end
  local setting = ModSetting.new(
    spec.key, spec.label or spec.key:upper(), values, labels, spec.default)
  local apo=mod._vascOverworldCard and mod._vascOverworldCard.options
  if apo and apo.decorateSetting then apo.decorateSetting(mod,setting) end
  if type(setting.onChange) == "function" then
    setting:onChange(changedCallback(opts, spec.key))
  end
  return setting
end

local function buildSettings(schema, opts)
  local apo = mod._vascOverworldCard and mod._vascOverworldCard.options
  if apo and not M.apoKeysAdded then
    for _, spec in ipairs(apo.schema(mod)) do
      local section = apo.section(spec.key)
      SECTION_KEYS[section][#SECTION_KEYS[section]+1] = spec.key
    end
    M.apoKeysAdded = true
  end
  local ModSetting = dependency(opts.ModSetting or C.ModSetting, "ModSetting")
  if not (ModSetting and type(ModSetting.new) == "function") then
    return nil, "ModSetting.new unavailable"
  end
  local byKey = schemaMap(schema)
  local entries, settingsByKey, assigned, extraKeys = {}, {}, {}, {}
  for _, sectionId in ipairs(SECTION_ORDER) do
    for _, key in ipairs(SECTION_KEYS[sectionId]) do
      local spec = byKey[key]
      if spec then
        local setting = makeSetting(ModSetting, spec, opts)
        if setting then
          entries[#entries + 1] = { setting, spec.description or spec.help or "" }
          settingsByKey[key] = setting
          assigned[key] = true
        end
      end
    end
  end

  -- Merge-safe catch-all: a newly imported VASC toggle/choice must never
  -- silently disappear because the Gen-2 registry predates its key. Route it
  -- into ADVANCED in schema order. Unsupported future types fail installation
  -- with the exact key/type instead of shipping an unreachable option.
  for _, spec in ipairs(schema or {}) do
    local key = type(spec) == "table" and spec.key or nil
    if type(key) == "string" and key ~= "stadiumRomFile" and not assigned[key] then
      local setting = makeSetting(ModSetting, spec, opts)
      if not setting then
        return nil, ("unsupported option %s (%s)"):format(
          tostring(key), tostring(spec.type))
      end
      entries[#entries + 1] = { setting, spec.description or spec.help or "" }
      settingsByKey[key] = setting
      assigned[key] = true
      extraKeys[#extraKeys + 1] = key
    end
  end
  return entries, settingsByKey, extraKeys
end

local function syncExternalChanges(settingsByKey)
  if not (mod and mod.events and type(mod.events.on) == "function") then return end
  pcall(mod.events.on, mod.events, "mod.options_changed", function(payload)
    if type(payload) ~= "table" or type(payload.key) ~= "string" then return end
    if payload.mod ~= nil and payload.mod ~= mod.id then return end
    -- This listener runs after VascRendererOptions (priority 0), which has
    -- applied any DEVICE profile fan-out by the time the hub reads all keys.
    -- Reading all keys also keeps a previously opened hub coherent after a
    -- Mod Manager change whose side effects span multiple rows.
    syncAllSettings(settingsByKey)
  end, -100)
end

local function safeValue(fn, fallback, ...)
  if type(fn) ~= "function" then return fallback end
  local ok, value = pcall(fn, ...)
  return ok and value ~= nil and tostring(value) or fallback
end

local function romRow(romMenu, game)
  if not romMenu then return nil end
  return {
    label="STADIUM 2 ROM",
    help="Choose a legally obtained Stadium 2 ROM and build the local Pokémon model pack. No ROM data ships with Voxel Ascendant.",
    value=function() return safeValue(romMenu.value, "CHOOSE", game) end,
    activate=function(selectedGame)
      if type(romMenu.choose) ~= "function" then return false end
      local ok, chosen = pcall(romMenu.choose, selectedGame or game)
      return ok and chosen ~= false
    end,
  }
end

local function contentRows(opts)
  local rows = {}
  local LocalContent = dependency(opts.LocalContent or C.LocalContent, "LocalContent")
  if LocalContent and type(LocalContent.row) == "function" then
    local ok, row = pcall(LocalContent.row, mod)
    if ok and type(row) == "table" then
      row.help = row.help or "Choose KASC, VASC DEFAULT, RETRO or CUSTOM."
      rows[#rows + 1] = row
    end
    if type(LocalContent.laneRow) == "function" then
      for _, lane in ipairs({"sprites", "music", "backdrops"}) do
        local okLane, laneRow = pcall(LocalContent.laneRow, lane)
        if okLane and type(laneRow) == "table" then
          laneRow.help = "Toggle only this Injector lane. Other imported lanes and VASC defaults remain unchanged."
          rows[#rows + 1] = laneRow
        end
      end
    end
    rows[#rows + 1] = {
      label="PRESET & SCOPE",
      help="Show the active game/generation preset, hash verification, fallback and VASC DEFAULT control.",
      value=function() return "OPEN" end,
      activate=function(game)
        return mod and mod.ui and type(mod.ui.push) == "function"
               and mod.ui.push(game, "VascContentStatus")
      end,
    }
  end
  return rows
end

local function optionEnabled(key)
  local options = mod and mod.options
  if not (options and type(options.get) == "function") then return false end
  local ok, value = pcall(options.get, options, key)
  return ok and (value == true or value == 1 or value == "1"
    or value == "true" or value == "on")
end

local function advancedRows(game)
  if not optionEnabled("dev_overlay") then return {} end
  return {
    {
      label="TEST SPAWN",
      help="Open the developer-only Pokémon spawn/model preview browser.",
      value=function() return "OPEN" end,
      activate=function(selectedGame)
        if mod and mod.ui and type(mod.ui.push) == "function" then
          return mod.ui.push(selectedGame or game, "OverworldSpawnPreview")
        end
        return false
      end,
    },
  }
end

local function buildSections(opts, extraKeys)
  local sections = {}
  local apo = mod._vascOverworldCard and mod._vascOverworldCard.options
  local de = apo and apo.isGerman and apo.isGerman(mod)
  local translated = {
    world={"SICHT + WELT", "Voxel-Kamera, offene Kartenübergänge, Johto-Karte, Geländeraster, Krümmung und Wasser einstellen."},
    weather={"WETTER + KULISSE", "Tageszeit, Johto-Wetter, Himmelsereignisse, Wolken und Kulissen folgen einem gemeinsamen Außenweltzustand."},
    battle={"VOXEL-KÄMPFE", "Voxel-Bühne, Stadium-Kamera und Kampfraster wählen. Die Kampfregeln bleiben unverändert."},
    skins={"DESIGN + HUD", "Team, Kampf-HUD, Menüs, Tasche und Pokédex gestalten. Nur Darstellung; Spielregeln bleiben unverändert."},
    pokemon={"POKéMON + MODELLE", "Pokémon- und Spielermodelle sowie Surfen, Fliegen, Angeln und Feld-Kit unabhängig einstellen. Die Spielregeln bleiben unverändert."},
    wilds={"WILDE + BEGLEITER", "Sichtbare wilde Pokémon, Begegnungsdarstellung, Begleitersteuerung und Wanderverhalten."},
    performance={"LEISTUNG", "Geräteprofil, interne Auflösung, Kantenglättung und Schattenaufwand."},
    user={"EIGENE INHALTE", "KASC, VASC-STANDARD, RETRO oder EIGEN als gemeinsames Inhaltsprofil wählen. Optionale Quellen werden geprüft; VASC bleibt unabhängig."},
    advanced={"ERWEITERT", "Wiederherstellung, Plattform- und Entwickleroptionen. Im normalen Spiel sind keine Änderungen nötig."},
  }
  for _, id in ipairs(SECTION_ORDER) do
    local meta = SECTION_META[id]
    sections[id] = {
      title=de and translated[id][1] or meta.title,
      help=de and translated[id][2] or meta.help, keys=keySet(SECTION_KEYS[id]),
    }
  end
  local RomMenu = dependency(opts.RomMenu or C.RomMenu, "StadiumRomMenu")
  sections.pokemon.rows = function(game)
    local row = romRow(RomMenu, game)
    return row and { row } or {}
  end
  sections.user.rows = function()
    return contentRows(opts)
  end
  sections.battle.actions = {
    {
      label="BATTLE LAYOUT", screen="VascBattleLayout",
      help="Adjust and save the Gen-2 front, back, Mega, trainer and fallback-HUD layout zones.",
    },
    {
      label="MOVE ANIMATIONS", action="animations",
      help="Show the installed Gen-2 move-animation coverage.",
    },
  }
  sections.pokemon.actions = {
    { label="POKEMON HD DOWNLOADS", screen="VascPokemonHdDownloads",
      help={en="Download optional Pokemon HD packages by generation. Restart after downloading. HD characters remain installed.",
        de="Optionale Pokémon-HD-Pakete pro Generation laden. Danach das Spiel neu starten. HD-Charaktere bleiben installiert."} },
    {
      label="SPRITE GUIDE", screen="VascUserSpritesHelp",
      help="Open the installed naming, size, baseline and fallback guide.",
    },
  }
  sections.wilds.actions = {
    {
      label="MOD OPTIONS", screen="OptionsMenu",
      help="Open the complete game/mod option list for Wilds and followers.",
    },
    {
      label="COMPATIBILITY", action="info",
      help="Installed companions retain their own behaviour and saves; VASC consumes public render hooks only.",
    },
  }
  sections.user.actions = {
    {
      label="CUSTOM MUSIC", screen="VascUserMusic",
      help="Configure user-owned music for the CUSTOM content profile.",
    },
    {
      label="CUSTOM SPRITES", screen="VascUserSprites",
      help="Inspect and rescan documented PNG overrides for the CUSTOM profile.",
    },
  }
  sections.advanced.actions = {
    {
      label="ALL GAME OPTIONS", screen="OptionsMenu",
      help="Open the complete engine list, including rows owned by other enabled mods.",
    },
    {
      label="START GUIDE", action="rootHelp",
      help="Repeat the complete Voxel Ascendant START-menu guide.",
    },
    {
      label="LOGGER / RC DIAGNOSTICS", screen="VascDiagnostics",
      help="Enter the private maintainer code for deep QA controls.",
    },
    {
      label="VERSION", action="version",
      help="Show the exact installed Voxel Ascendant package version.",
    },
  }
  sections.advanced.rows = advancedRows
  sections.advanced.dynamic = true
  sections.performance.dynamic = true
  for _, key in ipairs(extraKeys or {}) do
    sections.advanced.keys[key] = true
  end
  return sections
end

local function alreadyPresent(items)
  for _, item in ipairs(items or {}) do
    if type(item) == "table" and (item.ascendantKey == MENU_KEY
        or item.label == "ASCENDANT"
        or item.label == "VOXEL ASCENDANT"
        or item.ascendantLabel == "ASCENDANT"
        or item.ascendantLabel == "VOXEL ASCENDANT") then
      return true
    end
  end
  return false
end

function M.startRow(game)
  return {
    -- Standalone VASC uses the same public identity and menu position as the
    -- Kanto hub. The ORAS START adapter owns the responsive row width.
    label="ASCENDANT",
    desc={ "Voxel", "settings" },
    ascendantMenu=true,
    ascendantLabel="ASCENDANT",
    ascendantOrder=MENU_ORDER,
    ascendantKey=MENU_KEY,
    ascendantHelp="Open Voxel Ascendant's Johto control centre for view, world, weather, battles, skins, models, wild Pokémon, followers, performance and user content.",
    onSelect=function(selectedGame)
      local target = selectedGame or game
      if mod and mod.ui and type(mod.ui.push) == "function" then
        return mod.ui.push(target, "VascMenu")
      end
    end,
  }
end

function M.decorateStart(game, items)
  if type(items) ~= "table" or alreadyPresent(items) then return items end
  local row = M.startRow(game)
  if mod and mod.ui and type(mod.ui.insertAfter) == "function" then
    return mod.ui.insertAfter(items, "OPTION", row)
  end
  local out, inserted = {}, false
  for _, item in ipairs(items) do
    out[#out + 1] = item
    if not inserted and type(item) == "table"
        and tostring(item.value or item.label or ""):lower() == "option" then
      out[#out + 1], inserted = row, true
    end
  end
  if not inserted then out[#out + 1] = row end
  return out
end

function M.installStartHook()
  if M.startHookInstalled then return true end
  if not (mod and mod.hooks and type(mod.hooks.wrap) == "function") then
    return false, "mod.hooks:wrap unavailable"
  end
  local ok, err = pcall(function()
    mod.hooks:wrap("ui.start_menu.items", function(nextItems, game, items)
      local out = nextItems(game, items)
      return M.decorateStart(game, out)
    end, HOOK_PRIORITY)
  end)
  if not ok then return false, tostring(err) end
  M.startHookInstalled = true
  return true
end

function M.buildConfig(opts)
  opts = opts or {}
  local schema, schemaErr = schemaFromFile(opts.schema or C.schema)
  if not schema then return nil, schemaErr end
  local settings, settingsByKey, extraKeys = buildSettings(schema, opts)
  if not settings then return nil, settingsByKey end
  M.settingsByKey = settingsByKey
  M.extraKeys = extraKeys or {}

  local Style = dependency(opts.Style or C.Style, "VascMenuStyle")
  local ui = opts.ui
  if not ui and Style and type(Style.new) == "function" then
    -- The shared style is the exact generation-neutral FireRed/LeafGreen
    -- Ascendant renderer used by Gen 1. Never pass an edition palette here.
    local ok, built = pcall(Style.new, mod, opts.styleOptions or {})
    if ok and type(built) == "table" then ui = built end
  end

  local preferExternalUi = opts.preferExternalUi
  if preferExternalUi == nil then preferExternalUi = false end

  return {
    title="ASCENDANT",
    version=opts.version or C.version or mod._vascPackageVersion or mod.version
      or (mod.exports and mod.exports.packageVersion),
    rootHelp="The shared FireRed/LeafGreen Ascendant hub groups every active Gen-2 voxel feature into clean sections. Gold/Silver/Crystal's native menu and battle semantics stay unchanged; ORAS GLASS only replaces their drawing. START or SELECT explains the highlighted row.",
    ui=ui,
    preferExternalUi=preferExternalUi,
    styleOptions={},
    sections=buildSections(opts, M.extraKeys),
    sectionOrder=SECTION_ORDER,
    settings=settings,
    factoryResetPrepare=function(game)
      local content = opts.LocalContent or C.LocalContent
      if content and content.select then assert(content.select("VASC_DEFAULT", game)) end
    end,
    factoryResetFinish=function(game)
      local pipeline = opts.pipelineBridge or C.PipelineBridge
      if pipeline and pipeline.sync then pipeline.sync(game) end
      local voxel = opts.voxelBridge or C.VoxelBridge
      if voxel and voxel.handleUserVoxelOption then
        voxel.handleUserVoxelOption(true)
      end
      syncAllSettings(M.settingsByKey)
    end,
    menuSkinSetting=settingsByKey.vascMenuSkin,
    diagnostics=opts.Diagnostics or C.Diagnostics,
    performanceDiagnostics=opts.PerformanceDiagnostics
      or C.PerformanceDiagnostics,
    animationStatus=opts.animationStatus or C.animationStatus,
  }
end

function M.install(opts)
  if M.installed then return true end
  opts = opts or {}
  if not mod then return false, "mod unavailable" end
  local Menu = dependency(opts.Menu or C.Menu, "VascMenu")
  if not (Menu and type(Menu.install) == "function") then
    return false, "VascMenu.install unavailable"
  end
  local menuConfig, configErr = M.buildConfig(opts)
  if not menuConfig then M.lastError = configErr return false, configErr end
  local okScreens, screensErr = Menu.install(mod, menuConfig)
  if okScreens == false then
    M.lastError = tostring(screensErr or "VascMenu screen registration failed")
    return false, M.lastError
  end
  M.screensInstalled = true
  syncExternalChanges(M.settingsByKey)

  if opts.startHook ~= false then
    local okHook, hookErr = M.installStartHook()
    if not okHook then M.lastError = hookErr return false, hookErr end
  end
  M.installed, M.lastError = true, nil
  return true
end

function M.status()
  local count = 0
  for _ in pairs(M.settingsByKey) do count = count + 1 end
  return {
    installed=M.installed,
    screensInstalled=M.screensInstalled,
    startHookInstalled=M.startHookInstalled,
    settings=count,
    extraKeys=M.extraKeys,
    menuKey=MENU_KEY,
    hook="ui.start_menu.items",
    lastError=M.lastError,
  }
end

M.sections = SECTION_META
M.sectionKeys = SECTION_KEYS
M.sectionOrder = SECTION_ORDER
M.MENU_KEY = MENU_KEY
M.MENU_ORDER = MENU_ORDER
M.HOOK_PRIORITY = HOOK_PRIORITY

return M
