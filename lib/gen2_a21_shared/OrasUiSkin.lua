-- Optional ORAS presentation skin for native UI boxes and Bag lists.
--
-- Drawing is decorated per pushed state. Constructors, pagination, update,
-- callbacks and input remain native. An explicitly selected draw-only adapter
-- may repaint a native/Useful/KASC Bag; GAME/KASC and every adapter failure
-- retain the exact provider draw. PC, Ascendant/Voxel menus and Battle-HUD
-- screens keep their own renderers.

local V = ...
local M = { apiVersion = 2 }
local unpackValues = table.unpack or unpack

local SharedEditionAccent
if type(V) == "table" and type(V.require) == "function" then
  local ok, value = pcall(V.require, "EditionAccent")
  if ok and type(value) == "table" then SharedEditionAccent = value end
end

local SHARED_ACCENT = { 0.04, 0.80, 0.97, 1 }

local function safeRequire(name)
  local ok, value = pcall(require, name)
  if ok and type(value) == "table" then return value end
  return nil
end

local function packed(...)
  return { n = select("#", ...), ... }
end

local function traceback(message)
  if debug and type(debug.traceback) == "function" then
    return debug.traceback(tostring(message), 2)
  end
  return tostring(message)
end

local function createController(mod, opts)
  opts = opts or {}
  local accentResolver = type(opts.editionAccent) == "table"
      and opts.editionAccent or SharedEditionAccent
  local editionAccent, editionAccentId = SHARED_ACCENT, "shared"
  if accentResolver and type(accentResolver.color) == "function" then
    local ok, color, id = pcall(accentResolver.color, opts.edition)
    if ok and type(color) == "table" then
      editionAccent, editionAccentId = color, id or "shared"
    end
  end
  local companionOptionBuckets = opts.companionOptionBuckets
  if companionOptionBuckets == nil then
    -- Preserve the existing Gen-1 compatibility seam. Other generation
    -- adapters can pass an empty list and remain entirely self-owned.
    companionOptionBuckets = { "kanto_ascendant" }
  end
  local ui = opts.ui or mod.ui or safeRequire("src.ui.ModUI") or {}
  local Font = opts.Font or ui.Font or safeRequire("src.render.Font")
  local PaletteFX = opts.PaletteFX or safeRequire("src.render.PaletteFX")
  local BagSkin = opts.bagSkin
  local FrlgBagSkin = opts.frlgBagSkin
  local Diagnostics = opts.Diagnostics
  -- Wide variants intentionally reuse the same audited artwork adapters. The
  -- adapter receives an explicit layout flag below and composes a real
  -- 512x288 surface; it does not scale the compact 160x144 result.
  local BagSkins = {
    oras = BagSkin,
    frlg = FrlgBagSkin,
    oras_wide = BagSkin,
    frlg_wide = FrlgBagSkin,
  }
  local bagImageLoader = opts.bagImageLoader
  if type(bagImageLoader) ~= "function" and type(mod.assets) == "table"
      and type(mod.assets.image) == "function" then
    bagImageLoader = function(path) return mod.assets:image(path) end
  end
  local function recordBag(event, fields)
    if type(Diagnostics) == "table"
        and type(Diagnostics.write) == "function" then
      pcall(Diagnostics.write, event, fields)
    end
  end
  local supplied = opts.classes or {}
  local classes = {
    TextBox = supplied.TextBox or ui.TextBox
      or safeRequire("src.render.TextBox"),
    ChoiceBox = supplied.ChoiceBox or ui.ChoiceBox
      or safeRequire("src.ui.ChoiceBox"),
    Menu = supplied.Menu or ui.Menu or safeRequire("src.ui.Menu"),
    ListMenu = supplied.ListMenu or ui.ListMenu
      or safeRequire("src.ui.ListMenu"),
    QuantityBox = supplied.QuantityBox or ui.QuantityBox
      or safeRequire("src.ui.QuantityBox"),
    OptionsMenu = supplied.OptionsMenu or safeRequire("src.ui.OptionsMenu"),
    NamingScreen = supplied.NamingScreen or safeRequire("src.ui.NamingScreen"),
    MoveLearnMenu = supplied.MoveLearnMenu or safeRequire("src.ui.MoveLearnMenu"),
  }

  local G = {
    apiVersion = 2,
    optionKey = "qol_ui_skin",
    bagOptionKey = "qol_bag_skin",
    bagAccentOptionKey = "qol_bag_color",
    bagBodyOptionKey = "qol_bag_body",
    bagFormOptionKey = "qol_bag_form",
    skipMarker = "__ascendantGlobalUiSkinSkip",
    decoratedMarker = "__ascendantGlobalUiSkinDecorated",
    active = false,
    installed = false,
    classes = classes,
    editionAccentResolver = accentResolver,
    bagSkin = BagSkin,
    frlgBagSkin = FrlgBagSkin,
    bagSkins = BagSkins,
  }
  local KASC_IDS = { "kanto_ascendant", "trainer_rematch" }

  -- Only public KASC identity surfaces inform AUTO accent/form. Missing,
  -- malformed or throwing providers fail closed to standalone RED.
  local function kascBagCharacter(game)
    if type(mod.find) ~= "function" then return "RED" end
    for _, id in ipairs(KASC_IDS) do
      local ok, handle = pcall(mod.find, id)
      if ok and type(handle) == "table" then
        local exports = type(handle.exports) == "table" and handle.exports or nil
        local journey = exports and exports.legacyJourney
        local resolver = type(journey) == "table" and journey.activeCharacter
        if type(resolver) == "function" then
          local resolved, character = pcall(resolver,
            type(game) == "table" and game.save or nil)
          character = resolved and type(character) == "string"
            and character:upper() or nil
          if character == "RED" or character == "BLUE" or character == "GREEN" then
            return character
          end
        end
        local characters = exports and exports.extendedCharacters
        resolver = type(characters) == "table" and characters.getPlayerCharacter
        if type(resolver) == "function" then
          local resolved, character = pcall(resolver)
          character = resolved and type(character) == "string"
            and character:upper() or nil
          if character == "RED" or character == "BLUE" or character == "GREEN" then
            return character
          end
        end
        return "RED"
      end
    end
    return "RED"
  end

  local function readSavedOption(game, key)
    local ok, value = pcall(function()
      local options = game and game.save and game.save.options
      local buckets = options and options.modOptions
      if type(buckets) ~= "table" then return nil end
      local own = type(mod.id) == "string" and buckets[mod.id] or nil
      if type(own) == "table" and own[key] ~= nil then
        return own[key]
      end
      for _, id in ipairs(companionOptionBuckets) do
        local companion = buckets[id]
        if type(companion) == "table" and companion[key] ~= nil then
          return companion[key]
        end
      end
      return nil
    end)
    return ok and value or nil
  end

  local function configuredOption(game, key)
    local value = readSavedOption(game, key)
    if value == nil and mod.options and type(mod.options.get) == "function" then
      local ok, configured = pcall(mod.options.get, mod.options, key)
      if ok then value = configured end
    end
    return value
  end

  -- Save choice wins because a QoL menu can update it live. Unknown values or
  -- option-reader failures yield to the exact native UI.
  function G.style(game)
    local value = configuredOption(game, G.optionKey)
    if type(value) == "string" and value:lower() == "oras" then return "oras" end
    return "standard"
  end

  function G.enabled(game)
    return G.style(game) == "oras"
  end

  -- GAME/KASC is intentionally the default. Unknown legacy values are also
  -- provider-owned so no new VASC build can silently take a Bag renderer.
  function G.bagStyle(game)
    local value = configuredOption(game, G.bagOptionKey)
    value = type(value) == "string" and value:lower() or "external"
    -- Compact VASC Bag values shipped before RC10. They remain implemented as
    -- internal emergency renderers, but an old saved public choice upgrades
    -- to the matching complete 512x288 surface instead of reopening a small
    -- selectable Bag.
    if value == "oras" then return "oras_wide" end
    if value == "frlg" then return "frlg_wide" end
    if value == "oras_wide" or value == "frlg_wide" then
      return value
    end
    return "external"
  end

  function G.bagEnabled(game)
    local style = G.bagStyle(game)
    return type(BagSkins[style]) == "table"
  end

  function G.bagStyleEnabled(game, style)
    return G.bagStyle(game) == style
      and type(BagSkins[style]) == "table"
  end

  function G.bagAccent(game)
    local value = configuredOption(game, G.bagAccentOptionKey)
    value = type(value) == "string" and value:lower() or "auto"
    if value == "red" or value == "blue" or value == "green" then
      return value
    end
    return kascBagCharacter(game):lower()
  end

  function G.bagBody(game)
    local value = configuredOption(game, G.bagBodyOptionKey)
    value = type(value) == "string" and value:lower() or "auto"
    local supported = {
      oras=true, red=true, blue=true, yellow=true, gold=true, silver=true,
      crystal=true,
    }
    if supported[value] then return value end
    return supported[editionAccentId] and editionAccentId or "oras"
  end

  function G.bagForm(game)
    local value = configuredOption(game, G.bagFormOptionKey)
    value = type(value) == "string" and value:lower() or "auto"
    if value == "round" or value == "handle" then return value end
    return kascBagCharacter(game) == "GREEN" and "handle" or "round"
  end

  -- The ORAS surfaces remain identical for every supported game. Only this
  -- one-pixel public accent changes with Red/Blue/Yellow/Gold/Silver/Crystal.
  function G.editionAccent()
    return editionAccent, editionAccentId
  end

  local function classInstance(state, class)
    if type(state) ~= "table" or type(class) ~= "table" then return false end
    local mt = getmetatable(state)
    local visited = {}
    while type(mt) == "table" and not visited[mt] do
      if mt == class or rawget(mt, "__index") == class then return true end
      visited[mt] = true
      mt = getmetatable(mt)
    end
    return false
  end

  local function isCoreInstance(state)
    for _, class in pairs(classes) do
      if classInstance(state, class) then return true end
    end
    -- TitleState's private CONTINUE information pane publishes this stable
    -- geometry even though its class is local to TitleState.lua.
    return type(state) == "table" and type(state.titleUiBox) == "table"
      and type(state.draw) == "function"
  end

  local function isTitleFlow(state)
    if type(state) ~= "table" then return false end
    if state.screenId == "TitleState" or type(state.titleUiBox) == "table" then
      return true
    end
    local stack = state.game and state.game.stack
    local states = stack and stack.states
    if type(states) ~= "table" then return false end
    for _, candidate in ipairs(states) do
      if candidate ~= state and type(candidate) == "table"
          and candidate.screenId == "TitleState" then
        return true
      end
    end
    return false
  end

  local function isOpaqueBackdropInstance(state)
    return classInstance(state, classes.ListMenu)
      or classInstance(state, classes.OptionsMenu)
      or classInstance(state, classes.NamingScreen)
  end

  local function normalizedOwnerTitle(state)
    return type(state) == "table" and type(state.title) == "string"
      and state.title:upper():gsub("^%s+", ""):gsub("%s+$", "") or nil
  end

  -- Some authored surfaces open a native Menu/ChoiceBox above themselves.
  -- Useful Bag 3.x's TAB sort and R3 action prompts are the important example:
  -- the provider owns that whole flow although only the Bag list is marked.
  local function authoredSurfaceMarker(state)
    if type(state) ~= "table" then return nil end
    -- Native Menu/Choice overlays above an explicitly selected VASC Bag may
    -- share the ordinary ORAS box skin. GAME/KASC continues through the owner
    -- markers below and therefore keeps the complete provider presentation.
    local presentedStyle = state.__vascOrasBagStyle
    if (state.__vascOrasBagSkin or state.__vascOrasBagPresentation
        or state.__vascOrasFrlgBagPresentation)
        and presentedStyle == G.bagStyle(state.game)
        and G.bagEnabled(state.game) then
      return "vasc-oras-bag"
    end
    for key, value in pairs(state) do
      if value and type(key) == "string" then
        if key:match("^__fireRed")
            or key:match("^__ascendantModernBag")
            or key:match("^__ascendantBag")
            or key:match("^__ascendantBox")
            or key:match("^__ascendantFeature")
            or key:match("^__kantoAscendantBag")
            or key:match("^__kantoAscendantLayout")
            or key:match("^__kantoAscendantStyle")
            or key:match("^__kascBag")
            or key:match("^__voxelAscendantRoot")
            or key:match("^__voxelAscendantStandaloneStyle")
            -- KASC 6.5.17's Oak-hosted PicBox publishes these public owner
            -- fields without the historical double-underscore prefix. The
            -- portrait and its overlaid native TextBox are one authored flow.
            or key:match("^kascTrueColorPortrait")
            or key:match("^kascLegacyOak") then
          return key
        end
      end
    end
    local title = normalizedOwnerTitle(state)
    if title == "KANTO ASCENDANT" or title == "VOXEL ASCENDANT" then
      return "owner-title:" .. title
    end
    -- A broad third-party Bag adapter may accept any ListMenu-shaped state.
    -- Without an instance-owned Bag receipt, only the cartridge's exact ITEMS
    -- screen is eligible for VASC's native Gen-I Bag projection. This keeps
    -- authored pickers such as MEGA-FORM WÄHLEN and ADVANCED on their own
    -- renderer while still allowing explicitly marked provider Bags whose
    -- localized pocket title is not ITEMS.
    if classInstance(state, classes.ListMenu) and title ~= "ITEMS" then
      return "non-bag-list-title:" .. tostring(title or "")
    end
    return nil
  end

  local function authoredUnderlayMarker(state)
    local stack = type(state) == "table" and state.game and state.game.stack
    local states = stack and stack.states
    if type(states) ~= "table" then return nil end
    local currentIndex
    for index = #states, 1, -1 do
      if states[index] == state then
        currentIndex = index
        break
      end
    end
    if not currentIndex then return nil end
    for index = currentIndex - 1, 1, -1 do
      local marker = authoredSurfaceMarker(states[index])
      if marker then return "owner-underlay:" .. marker end
    end
    return nil
  end

  local function customMarker(state)
    if type(state) ~= "table" then return nil end
    if state[G.skipMarker] then return G.skipMarker end
    for key, value in pairs(state) do
      if value and type(key) == "string"
          and not key:match("^__ascendantGlobalUiSkin") then
        if key:match("^__floatingBattle")
            or key:match("^__ascendant")
            or key:match("^__kantoAscendant")
            or key:match("^__kasc")
            or key:match("^__orasBattleHud")
            or key:match("^__fireRed")
            or key:match("^__voxel") then
          return key
        end
      end
    end
    -- The current KASC and VASC menus publish owner markers. Keep a narrow
    -- title fallback for their root screens as well, so older builds and a
    -- late style-provider startup cannot briefly receive this native UI skin.
    local title = normalizedOwnerTitle(state)
    if title == "KANTO ASCENDANT" or title == "VOXEL ASCENDANT" then
      return "owner-title:" .. title
    end
    local underlay = authoredUnderlayMarker(state)
    if underlay == "owner-underlay:vasc-oras-bag" then return nil end
    return underlay
  end

  local function isBagState(state)
    if type(state) ~= "table" or (not BagSkin and not FrlgBagSkin) then
      return false
    end
    for _, candidate in pairs(BagSkins) do
      if type(candidate) == "table" and type(candidate.isBag) == "function" then
        local ok, result = pcall(candidate.isBag, state)
        if ok and result then return true end
      end
    end
    if state.__fireRedSkin or state.__ascendantModernBag
        or state.__ascendantBag or state.__kantoAscendantBag
        or state.__kascBag or state.__usefulBag
        or state.__vascOrasBagPresentation
        or state.__vascOrasFrlgBagPresentation then
      return true
    end
    -- The native Gen-I Bag loses its constructor hint, but this public shape
    -- is unique among ListMenus and avoids class replacement or engine hooks.
    return classInstance(state, classes.ListMenu)
      and normalizedOwnerTitle(state) == "ITEMS"
      and type(state.onSelectKey) == "function"
      and type(state.footer) == "string"
  end

  local GEN1_POCKETS = {
    { id="items", label="ITEMS" },
    { id="medicine", label="MEDS" },
    { id="balls", label="BALLS" },
    { id="tms", label="TMs" },
    { id="battle", label="BATTLE" },
    { id="key", label="KEY" },
  }
  local MEDICINE_IDS = {
    POTION=true, SUPER_POTION=true, HYPER_POTION=true, MAX_POTION=true,
    FULL_RESTORE=true, REVIVE=true, MAX_REVIVE=true, ANTIDOTE=true,
    BURN_HEAL=true, ICE_HEAL=true, AWAKENING=true, PARLYZ_HEAL=true,
    FULL_HEAL=true, ETHER=true, MAX_ETHER=true, ELIXER=true,
    MAX_ELIXER=true, HP_UP=true, PROTEIN=true, IRON=true, CARBOS=true,
    CALCIUM=true, PP_UP=true, RARE_CANDY=true,
  }
  local BATTLE_IDS = {
    X_ATTACK=true, X_DEFEND=true, X_SPEED=true, X_SPECIAL=true,
    X_ACCURACY=true, DIRE_HIT=true, GUARD_SPEC=true, POKE_DOLL=true,
  }
  local BALL_IDS = {
    POKE_BALL=true, GREAT_BALL=true, ULTRA_BALL=true,
    MASTER_BALL=true, SAFARI_BALL=true,
  }

  local function nativePocketFor(state, row)
    local id = row and row.value
    local game = state and state.game
    local def = id and game and game.data and game.data.items
      and game.data.items[id] or nil
    local declared = def and (def.pocket or def.category)
    if type(declared) == "string" then
      declared = declared:lower():gsub("[^a-z]", "")
      if declared == "ball" or declared == "pokeballs" then return "balls" end
      if declared == "tm" or declared == "hm" or declared == "tmshms" then
        return "tms"
      end
      if declared == "keyitem" then return "key" end
      for _, pocket in ipairs(GEN1_POCKETS) do
        if declared == pocket.id then return pocket.id end
      end
    end
    if def and def.machine then return "tms" end
    if def and def.keyItem then return "key" end
    if BALL_IDS[id] or (def and def.ball == true) then return "balls" end
    if BATTLE_IDS[id] then return "battle" end
    if MEDICINE_IDS[id] then return "medicine" end
    return "items"
  end

  -- Red/Blue/Yellow expose one cartridge list. VASC's Bag is explicitly a
  -- six-pocket UI, so give only that exact native ListMenu a thin projection
  -- controller. It never edits inventory: rows retain their original value
  -- and callbacks, while L/R selects a filtered view of the same rows.
  local function installNativeGen1Pockets(state)
    if type(state) ~= "table" or state.__vascGen1BagPockets then return end
    if not (classInstance(state, classes.ListMenu)
        and normalizedOwnerTitle(state) == "ITEMS"
        and type(state.onSelectKey) == "function") then return end
    for _, marker in ipairs({ "__usefulBag", "__fireRedSkin",
        "__ascendantModernBag", "__ascendantBag", "__kantoAscendantBag",
        "__kascBag" }) do
      if rawget(state, marker) then return end
    end

    local nativeUpdate = state.update
    local nativeSelect = state.onSelectKey
    local cursors = {}
    state.__vascGen1BagPockets = true
    state.__pockets = GEN1_POCKETS
    state.__pocketCount = #GEN1_POCKETS
    state.__pocketIndex = 1
    state.__vascGen1BagAllItems = state.items or {}

    local function rebuild(self)
      local pocket = GEN1_POCKETS[self.__pocketIndex] or GEN1_POCKETS[1]
      local filtered = {}
      for _, row in ipairs(self.__vascGen1BagAllItems or {}) do
        if nativePocketFor(self, row) == pocket.id then
          filtered[#filtered + 1] = row
        end
      end
      self.__pocketId = pocket.id
      self.__pocketLabel = pocket.label
      self.items = filtered
      self.__vascGen1BagFilteredItems = filtered
      self.index = math.max(1, math.min(#filtered > 0 and #filtered or 1,
        math.floor(tonumber(cursors[self.__pocketIndex]) or 1)))
      self.scroll = math.max(0, math.min(math.floor(tonumber(self.scroll) or 0),
        math.max(0, #filtered - math.max(1, tonumber(self.rows) or 7))))
    end

    local function captureReplacement(self)
      if self.items ~= self.__vascGen1BagFilteredItems then
        self.__vascGen1BagAllItems = self.items or {}
        rebuild(self)
      end
    end

    state.onSelectKey = function(item, list)
      captureReplacement(list)
      local all = list.__vascGen1BagAllItems or {}
      local globalIndex = 1
      for index, candidate in ipairs(all) do
        if candidate == item or (candidate.value ~= nil
            and candidate.value == (item and item.value)) then
          globalIndex = index
          break
        end
      end
      local localIndex, localItems, localSwap = list.index, list.items,
        list.swapIndex
      list.index = globalIndex
      list.items = all
      list.swapIndex = list.__vascGen1BagSwapGlobal
      nativeSelect(all[globalIndex], list)
      list.__vascGen1BagAllItems = list.items or all
      list.__vascGen1BagSwapGlobal = list.swapIndex
      list.index, list.items, list.swapIndex = localIndex, localItems, localSwap
      rebuild(list)
      if list.__vascGen1BagSwapGlobal then
        local pending = list.__vascGen1BagAllItems[list.__vascGen1BagSwapGlobal]
        list.swapIndex = nil
        for index, candidate in ipairs(list.items) do
          if candidate == pending then list.swapIndex = index break end
        end
      else
        list.swapIndex = nil
      end
    end

    state.update = function(self, ...)
      captureReplacement(self)
      local input = self.game and self.game.input
      local delta = input and type(input.wasPressed) == "function"
        and ((input:wasPressed("left") and -1)
          or (input:wasPressed("right") and 1)) or nil
      if delta then
        cursors[self.__pocketIndex] = self.index
        self.__pocketIndex = ((self.__pocketIndex - 1 + delta)
          % #GEN1_POCKETS) + 1
        self.scroll, self.swapIndex, self.__vascGen1BagSwapGlobal = 0, nil, nil
        rebuild(self)
        return
      end
      local out = packed(nativeUpdate(self, ...))
      captureReplacement(self)
      cursors[self.__pocketIndex] = self.index
      return unpackValues(out, 1, out.n)
    end
    rebuild(state)
  end

  -- Bag adapters are allowed to recognize foreign/provider bags, and some
  -- older adapters used deliberately broad shape checks.  That recognition
  -- must never seize an already authored Ascendant configuration surface:
  -- changing the Bag style while VASC/KASC is open otherwise turns the
  -- configuration menu itself into a Bag until it is closed.  Real bags keep
  -- their explicit Bag receipt and therefore pass through to isBagState.
  local function authoredNonBagMenuMarker(state)
    if type(state) ~= "table" then return nil end
    -- Only an instance-owned receipt may outrank the instance's authored menu
    -- identity here. Some Bag providers publish a marker on their shared
    -- ListMenu class/metatable; ordinary VASC/KASC hubs inherit that field too
    -- and must not become Bags after the first Bag screen has been opened.
    -- isBagState below may still use inherited markers to recognize the actual
    -- provider Bag when the state has no authored-menu marker of its own.
    if rawget(state, "__fireRedSkin")
        or rawget(state, "__ascendantModernBag")
        or rawget(state, "__ascendantBag")
        or rawget(state, "__kantoAscendantBag")
        or rawget(state, "__kascBag")
        or rawget(state, "__usefulBag")
        or rawget(state, "__vascOrasBagPresentation")
        or rawget(state, "__vascOrasFrlgBagPresentation") then
      return nil
    end
    for _, key in ipairs({
      "__voxelAscendantRoot",
      "__voxelAscendantStandaloneStyle",
      "__voxelAscendantFocusHelp",
      "__kantoAscendantLayout",
    }) do
      if state[key] then return key end
    end
    for key, value in pairs(state) do
      if value and type(key) == "string"
          and (key:match("^__ascendantFeature")
            or key:match("^__voxelAscendantMenu")
            or key:match("^__kantoAscendantMenu")
            or key:match("^__kascMenu")) then
        return key
      end
    end
    local title = normalizedOwnerTitle(state)
    if title == "KANTO ASCENDANT" or title == "VOXEL ASCENDANT" then
      return "owner-title:" .. title
    end
    -- A broad third-party Bag adapter may accept any ListMenu-shaped state.
    -- Without an instance-owned Bag receipt, only the cartridge's exact ITEMS
    -- screen is eligible for VASC's native Gen-I Bag projection. This keeps
    -- authored pickers such as MEGA-FORM WÄHLEN and ADVANCED on their own
    -- renderer while still allowing explicitly marked provider Bags whose
    -- localized pocket title is not ITEMS.
    if classInstance(state, classes.ListMenu) and title ~= "ITEMS" then
      return "non-bag-list-title:" .. tostring(title or "")
    end
    return nil
  end

  function G.markCustom(state)
    if type(state) == "table" then state[G.skipMarker] = true end
    return state
  end

  local TEXT_MASK_SHADER_SOURCE = [[
    uniform vec4 ink;
    vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
      vec4 src = Texel(tex, tc);
      return vec4(ink.rgb, ink.a * src.a * color.a);
    }
  ]]
  local textMaskShader = nil
  local textMaskAttempted = false

  local function getTextMaskShader()
    if textMaskAttempted then return textMaskShader or nil end
    textMaskAttempted = true
    local loveRef = rawget(_G, "love")
    local graphics = loveRef and loveRef.graphics
    if type(graphics) ~= "table" or type(graphics.newShader) ~= "function" then
      textMaskShader = false
      return nil
    end
    local ok, shader = pcall(graphics.newShader, TEXT_MASK_SHADER_SOURCE)
    if not (ok and shader) then
      textMaskShader = false
      return nil
    end
    if type(shader.send) ~= "function" then
      textMaskShader = false
      return nil
    end
    local sent = pcall(shader.send, shader, "ink", { 0.97, 0.99, 1.0, 1.0 })
    if not sent then
      textMaskShader = false
      return nil
    end
    textMaskShader = shader
    return shader
  end

  local function transformedRectBounds(graphics, x, y, width, height)
    local left, top, right, bottom = x, y, x + width, y + height
    if graphics and type(graphics.transformPoint) == "function" then
      local transformed = {}
      for _, point in ipairs({
        { left, top }, { right, top }, { left, bottom }, { right, bottom },
      }) do
        local ok, tx, ty = pcall(graphics.transformPoint, point[1], point[2])
        if not ok then transformed = nil break end
        transformed[#transformed + 1] = { tx, ty }
      end
      if transformed then
        left, top, right, bottom = math.huge, math.huge, -math.huge, -math.huge
        for _, point in ipairs(transformed) do
          left, top = math.min(left, point[1]), math.min(top, point[2])
          right, bottom = math.max(right, point[1]), math.max(bottom, point[2])
        end
      end
    end
    return left, top, right, bottom
  end

  -- PaletteFX stores canvas-space rectangles. Wide battles translate classic
  -- 160px overlays before draw, so local box coordinates must pass through the
  -- active LOVE transform or the unshaded zone lands on the wrong pixels.
  local function markTrueColorRect(graphics, x, y, width, height)
    if not PaletteFX or type(PaletteFX.markTrueColor) ~= "function" then return end
    local left, top, right, bottom = transformedRectBounds(
      graphics, x, y, width, height)
    pcall(PaletteFX.markTrueColor, left, top,
          math.max(0, right - left), math.max(0, bottom - top))
  end

  -- Game:draw centres classic menus in a retained 304x144 WideBattle surface
  -- with a live graphics translation. Repainting ListMenu's 160x144 opaque
  -- clear as translucent glass under that transform exposes a full-height dark
  -- edge at x=72. Detect only an axis-aligned translated classic surface;
  -- ordinary 160x144 menus and any non-trivial transform retain their existing
  -- presentation.
  local function translatedClassicSurface(graphics, x, y, width, height)
    if not graphics or type(graphics.transformPoint) ~= "function" then
      return false
    end
    local left, top, right, bottom = transformedRectBounds(
      graphics, x, y, width, height)
    local epsilon = 0.001
    return math.abs((right - left) - width) <= epsilon
      and math.abs((bottom - top) - height) <= epsilon
      and (math.abs(left - x) > epsilon or math.abs(top - y) > epsilon)
  end

  -- With a shader, this is the same dark translucent surface and white ink as
  -- the battle message plate. If a backend cannot compile the tiny mask shader,
  -- the box deliberately becomes pale so the native black bitmap font remains
  -- readable instead of disappearing against the dark panel.
  local function paintOrasBox(tx, ty, tw, th, darkText)
    local loveRef = rawget(_G, "love")
    local graphics = loveRef and loveRef.graphics
    if type(graphics) ~= "table"
        or type(graphics.setColor) ~= "function"
        or type(graphics.rectangle) ~= "function" then
      error("ORAS UI graphics are unavailable", 0)
    end

    local previousColor
    if type(graphics.getColor) == "function" then
      local color = packed(pcall(graphics.getColor))
      if color[1] then previousColor = { color[2], color[3], color[4], color[5] } end
    end
    local previousWidth
    if type(graphics.getLineWidth) == "function" then
      local ok, width = pcall(graphics.getLineWidth)
      if ok then previousWidth = width end
    end
    local previousStyle
    if type(graphics.getLineStyle) == "function" then
      local ok, style = pcall(graphics.getLineStyle)
      if ok then previousStyle = style end
    end

    local function restoreGraphics()
      if previousStyle ~= nil and type(graphics.setLineStyle) == "function" then
        pcall(graphics.setLineStyle, previousStyle)
      end
      if previousWidth ~= nil and type(graphics.setLineWidth) == "function" then
        pcall(graphics.setLineWidth, previousWidth)
      end
      if previousColor then
        pcall(graphics.setColor, unpackValues(previousColor, 1, 4))
      else
        pcall(graphics.setColor, 1, 1, 1, 1)
      end
    end

    local x, y = tx * 8, ty * 8
    local width, height = tw * 8, th * 8
    local ok, err = xpcall(function()
      if type(graphics.setLineWidth) == "function" then graphics.setLineWidth(1) end
      -- LÖVE's default smooth rounded-line rasterizer spills a fractional
      -- alpha pixel outside the authored box. Dynamic right anchoring moves
      -- only the exact box bounds, leaving that old pixel behind as a dark
      -- vertical seam. Rough lines stay pixel-exact at native resolution.
      if previousStyle ~= nil and type(graphics.setLineStyle) == "function" then
        graphics.setLineStyle("rough")
      end
      if darkText then
        -- One translucent surface keeps the world visible. An older full-size
        -- shadow was offset by two classic pixels; wide integer scaling turned
        -- its exposed right/bottom edge into a conspicuous black screen stripe.
        -- Depth now stays completely inside the authored box bounds.
        graphics.setColor(0.01, 0.05, 0.08, 0.78)
        graphics.rectangle("fill", x, y, width, height, 4, 4)
        graphics.setColor(0, 0, 0, 0.24)
        graphics.rectangle("fill", x + 3, y + math.max(0, height - 3),
                           math.max(0, width - 6), math.min(1, height), 2, 2)
      else
        graphics.setColor(0.005, 0.02, 0.03, 0.94)
        graphics.rectangle("fill", x, y, width, height, 4, 4)
        graphics.setColor(0.94, 0.985, 1.0, 0.90)
        graphics.rectangle("fill", x + 1, y + 1,
                           math.max(0, width - 2), math.max(0, height - 2), 3, 3)
      end
      graphics.setColor(editionAccent[1], editionAccent[2],
                        editionAccent[3], editionAccent[4] or 0.98)
      graphics.rectangle("line", x + 0.5, y + 0.5,
                         math.max(0, width - 1), math.max(0, height - 1), 4, 4)
      graphics.setColor(0.53, 0.94, 1.0, 0.46)
      graphics.rectangle("line", x + 1.5, y + 1.5,
                         math.max(0, width - 3), math.max(0, height - 3), 3, 3)
      graphics.setColor(0.66, 0.97, 1.0, 0.62)
      graphics.rectangle("fill", x + 7, y + 3, math.max(0, width - 14), 1)
    end, traceback)
    restoreGraphics()
    if not ok then error(err, 0) end
    markTrueColorRect(graphics, x, y, width, height)
    return true
  end

  function G.drawOrasBox(fallback, tx, ty, tw, th, darkText)
    local ok, err = pcall(paintOrasBox, tx, ty, tw, th, darkText)
    if ok then return true end
    G.lastError = tostring(err)
    if type(fallback) == "function" then return fallback(tx, ty, tw, th) end
    return nil
  end

  local function gameFor(state)
    if type(state) == "table" and state.game then return state.game end
    return mod.world and mod.world.game or nil
  end

  local function drawWithSkin(state, originalDraw, forceEnabled, ...)
    if not Font or type(Font.drawBox) ~= "function"
        or (not forceEnabled and not G.enabled(gameFor(state)))
        or (not forceEnabled and customMarker(state)) then
      return originalDraw(state, ...)
    end

    local args = packed(...)
    local previousDrawBox = Font.drawBox
    local graphics = rawget(_G, "love") and love.graphics or nil
    local previousRectangle = graphics and graphics.rectangle or nil
    local previousDrawCode = Font.drawCode
    local inkShader = getTextMaskShader()
    local backdropPainted = false
    Font.drawBox = function(tx, ty, tw, th)
      return G.drawOrasBox(previousDrawBox, tx, ty, tw, th, inkShader ~= nil)
    end

    if inkShader and type(previousDrawCode) == "function"
        and graphics and type(graphics.setShader) == "function" then
      Font.drawCode = function(code, x, y, ...)
        local glyphArgs = packed(...)
        local previousShader
        if type(graphics.getShader) == "function" then
          local got, shader = pcall(graphics.getShader)
          if got then previousShader = shader end
        end
        local previousColor
        if type(graphics.getColor) == "function" then
          local color = packed(pcall(graphics.getColor))
          if color[1] then previousColor = { color[2], color[3], color[4], color[5] } end
        end
        local returned
        local ok, err = xpcall(function()
          graphics.setShader(inkShader)
          if type(graphics.setColor) == "function" then
            graphics.setColor(1, 1, 1, previousColor and previousColor[4] or 1)
          end
          returned = packed(previousDrawCode(code, x, y,
                            unpackValues(glyphArgs, 1, glyphArgs.n)))
        end, traceback)
        if previousShader ~= nil then
          pcall(graphics.setShader, previousShader)
        else
          pcall(graphics.setShader)
        end
        if previousColor then
          pcall(graphics.setColor, unpackValues(previousColor, 1, 4))
        end
        if not ok then error(err, 0) end
        return unpackValues(returned, 1, returned.n)
      end
    end

    -- Opaque engine lists/options/naming screens clear white. Replace only that
    -- clear; custom KASC/VASC lists, FRLG Bag/PC and Ascendant menus are
    -- excluded by their owner markers (with root-title fallback).
    if isOpaqueBackdropInstance(state) and type(previousRectangle) == "function" then
      graphics.rectangle = function(mode, x, y, width, height, ...)
        if not backdropPainted and mode == "fill"
            and x == 0 and y == 0 and width == 160 and height == 144 then
          backdropPainted = true
          local translated = translatedClassicSurface(
            graphics, x, y, width, height)
          if inkShader then
            graphics.setColor(0.005, 0.025, 0.04, 0.84)
          else
            graphics.setColor(0.90, 0.965, 0.985, 0.92)
          end
          if translated then
            -- The individual Font.drawBox calls below already paint every
            -- visible menu plate.  Any replacement for this translated
            -- 160x144 clear -- even an inset one -- exposes its tall left
            -- border in the 304px WideBattle canvas as the blue/black seam
            -- reported in live menus.  Suppress only the native clear and
            -- leave the world plus exact authored boxes untouched.
            return
          end
          previousRectangle("fill", 0, 0, 160, 144)
          graphics.setColor(0.02, 0.66, 0.86, 1)
          previousRectangle("fill", 0, 0, 160, 2)
          previousRectangle("fill", 0, 142, 160, 2)
          graphics.setColor(0.38, 0.86, 0.96, 0.46)
          previousRectangle("line", 3, 14, 154, 116, 3, 3)
          graphics.setColor(editionAccent[1], editionAccent[2],
                            editionAccent[3], editionAccent[4] or 1)
          previousRectangle("line", 0.5, 0.5, 159, 143)
          markTrueColorRect(graphics, 0, 0, 160, 144)
          return
        end
        return previousRectangle(mode, x, y, width, height, ...)
      end
    end

    local returned
    local ok, err = xpcall(function()
      returned = packed(originalDraw(state, unpackValues(args, 1, args.n)))
    end, traceback)
    Font.drawBox = previousDrawBox
    Font.drawCode = previousDrawCode
    if graphics and previousRectangle then graphics.rectangle = previousRectangle end
    if not ok then error(err, 0) end
    return unpackValues(returned, 1, returned.n)
  end

  function G.decorate(state)
    if type(state) ~= "table" or state[G.decoratedMarker] then return state, false end

    -- Boot/title ownership is separate from in-game OVERWORLD MENUS.  Keep
    -- CONTINUE/NEW GAME, continue-info and title-launched options on their
    -- authored cartridge surfaces; VASC's edge/full START and Bag adapters
    -- begin only after a game has actually been entered.
    if isTitleFlow(state) then
      state.__ascendantGlobalUiSkinSkipped = "title-flow"
      return state, false
    end

    -- Ask the concrete screen for authored non-Bag ownership before any
    -- adapter is allowed to apply a broad shape heuristic.  Real provider
    -- Bags carry an instance-owned receipt and authoredNonBagMenuMarker()
    -- deliberately returns nil for them; KASC/VASC root menus instead retain
    -- their own renderer even though they also expose items plus draw.
    local authoredMenu = authoredNonBagMenuMarker(state)
    if authoredMenu then
      state.__ascendantGlobalUiSkinSkipped = authoredMenu
      state.__ascendantGlobalUiSkinBagSkipped = "authored_menu"
      return state, false
    end

    -- Bags are complete behavior-bearing screens before screen.pushed. A
    -- deliberate VASC style wraps only draw; GAME/KASC does not wrap at all.
    if isBagState(state) then
      installNativeGen1Pockets(state)
      local requestedStyle = G.bagStyle(gameFor(state))
      local ActiveBagSkin = BagSkins[requestedStyle]
      if type(ActiveBagSkin) ~= "table"
          or type(ActiveBagSkin.decorate) ~= "function" then
        state.__ascendantGlobalUiSkinBagSkipped =
          requestedStyle == "external" and "provider_owned"
            or "adapter_unavailable:" .. tostring(requestedStyle)
        recordBag("bag-open", {
          style=requestedStyle,
          result="fallback",
          reason=state.__ascendantGlobalUiSkinBagSkipped,
          title=normalizedOwnerTitle(state) or "",
        })
        return state, false
      end
      local function describeBagItem(item, list)
        local provider = type(list) == "table"
          and rawget(list, "ascendantBagDescription") or nil
        if type(provider) ~= "function" then return nil end
        local ok, value = pcall(provider, item, list)
        return ok and value or nil
      end
      local ok, resultOrError, decorated, reason = pcall(
          ActiveBagSkin.decorate, state, {
        -- Explicit selection may replace an existing presentation, but never
        -- any behavior field. The captured native/provider draw is the live
        -- fallback for GAME/KASC and rendering failures. Bag selection is
        -- intentionally independent from the ordinary OVERWORLD MENUS skin.
        force = true,
        enabled = function(list)
          return G.bagStyleEnabled(gameFor(list or state), requestedStyle)
        end,
        describeItem = describeBagItem,
        Font = Font,
        PaletteFX = PaletteFX,
        loadImage = bagImageLoader,
        resolveCharacter = function(list)
          return kascBagCharacter(gameFor(list or state))
        end,
        resolveAccent = function(list)
          return G.bagAccent(gameFor(list or state))
        end,
        resolveBody = function(list)
          return G.bagBody(gameFor(list or state))
        end,
        resolveForm = function(list)
          return G.bagForm(gameFor(list or state))
        end,
        wide = requestedStyle == "oras_wide"
          or requestedStyle == "frlg_wide",
      })
      local alreadyDecorated = false
      if ok and type(ActiveBagSkin.isDecorated) == "function" then
        local checked, value = pcall(ActiveBagSkin.isDecorated, state)
        alreadyDecorated = checked and value == true
      end
      if ok and (decorated == true or alreadyDecorated) then
        state.__vascOrasBagStyle = requestedStyle
        state.__ascendantGlobalUiSkinBagDecorated = true
        state[G.decoratedMarker] = true
        recordBag("bag-open", {
          style=requestedStyle,
          result="vasc-bag",
          owner=ActiveBagSkin.owner or "vasc",
          title=normalizedOwnerTitle(state) or "",
          items=type(state.items) == "table" and #state.items or 0,
        })
        return state, true
      end
      if not ok then
        G.lastError = tostring(resultOrError)
      elseif reason and reason ~= "already_decorated" then
        G.lastError = tostring(reason)
      end
      state.__ascendantGlobalUiSkinBagSkipped = reason or "adapter_unavailable"
      recordBag("bag-open", {
        style=requestedStyle,
        result="fallback",
        reason=state.__ascendantGlobalUiSkinBagSkipped,
        error=G.lastError or "",
        title=normalizedOwnerTitle(state) or "",
      })
      return state, false
    end

    if not isCoreInstance(state) or type(state.draw) ~= "function" then
      return state, false
    end
    local skip = customMarker(state)
    if skip then
      state.__ascendantGlobalUiSkinSkipped = skip
      return state, false
    end
    local originalDraw = state.draw
    local originalWide = type(state.drawWidescreen) == "function"
      and state.drawWidescreen or nil
    state.__ascendantGlobalUiSkinOriginalDraw = originalDraw
    state.__ascendantGlobalUiSkinOriginalDrawWidescreen = originalWide
    state[G.decoratedMarker] = true
    state.__ascendantGlobalUiSkinEditionAccent = editionAccentId
    state.draw = function(self, ...)
      return drawWithSkin(self, originalDraw, false, ...)
    end
    if originalWide then
      -- Game2 passes physical dimensions straight to the active screen. Keep
      -- that presenter and its transform entirely engine-owned; the shared
      -- skin only replaces Font/box drawing for the duration of the call.
      state.drawWidescreen = function(self, winW, winH, ...)
        return drawWithSkin(self, originalWide, false, winW, winH, ...)
      end
    end
    return state, true
  end

  -- An owning UI surface can explicitly request the ORAS GLASS box treatment
  -- for one already-constructed native state. Only draw is wrapped: update,
  -- callbacks, pagination and every constructor-owned behavior remain intact.
  -- The ordinary screen.pushed listener sees the shared marker and therefore
  -- cannot wrap the same state a second time.
  function G.decorateInstance(state)
    if type(state) ~= "table" or type(state.draw) ~= "function" then
      return state, false, "not_drawable"
    end
    if state[G.decoratedMarker] then
      return state, false, "already_decorated"
    end
    local originalDraw = state.draw
    local originalWide = type(state.drawWidescreen) == "function"
      and state.drawWidescreen or nil
    state.__ascendantGlobalUiSkinOriginalDraw = originalDraw
    state.__ascendantGlobalUiSkinOriginalDrawWidescreen = originalWide
    state[G.decoratedMarker] = true
    state.__ascendantGlobalUiSkinEditionAccent = editionAccentId
    state.draw = function(self, ...)
      return drawWithSkin(self, originalDraw, true, ...)
    end
    if originalWide then
      state.drawWidescreen = function(self, winW, winH, ...)
        return drawWithSkin(self, originalWide, true, winW, winH, ...)
      end
    end
    return state, true
  end

  function G.install()
    if G.installed then return true end
    G.installed = true
    local events = mod.events
    if not events or type(events.on) ~= "function" then return true end
    local ok, err = pcall(events.on, events, "screen.pushed", function(event)
      G.decorate(type(event) == "table" and event.state or nil)
    end)
    if not ok then
      G.lastError = tostring(err)
      return true
    end
    G.active = true
    return true
  end

  return G
end

function M.install(context)
  local mod = context and context.mod or context
  if type(mod) ~= "table" then return false, "missing_mod" end
  if M.controller then
    mod.exports = mod.exports or {}
    mod.exports.editionAccent = M.publicEditionAccent
    return true, "already_installed"
  end
  local controller = createController(mod, context or {})
  local ok, reason = controller.install()
  if not ok then return false, reason end
  M.controller = controller
  M.publicEditionAccent = controller.editionAccentResolver
  if type(M.publicEditionAccent) ~= "table" then
    M.publicEditionAccent = {
      apiVersion = 1,
      policy = "shared-oras-thin-edition-border",
      color = function() return controller.editionAccent() end,
      resolve = function()
        local color, id = controller.editionAccent()
        return { id=id, border=color }, id
      end,
    }
  end
  mod.exports = mod.exports or {}
  mod.exports.editionAccent = M.publicEditionAccent
  return true
end

function M.enabled(game)
  return M.controller and M.controller.enabled(game) or false
end

function M.bagEnabled(game)
  return M.controller and M.controller.bagEnabled(game) or false
end

function M.markCustom(state)
  if M.controller then return M.controller.markCustom(state) end
  return state
end

function M.decorateInstance(state)
  if not M.controller then return state, false, "not_installed" end
  return M.controller.decorateInstance(state)
end

return M
