-- Complete standalone and public-KASC VASC control-centre contract.
assert(loadfile("main.lua"))

-- VascMenuStyle is a LÖVE renderer. The contract runs under plain LuaJIT, so
-- provide only the inert drawing surface needed to exercise layout, labels
-- and focus-help ownership without turning this into a screenshot test.
love = love or {}
love.graphics = love.graphics or {}
love.graphics.setColor = love.graphics.setColor or function() end
love.graphics.rectangle = love.graphics.rectangle or function() end
love.graphics.setScissor = love.graphics.setScissor or function() end

local function eq(actual, expected, message)
  assert(actual == expected, (message or "values differ")
    .. (" (expected %s, got %s)"):format(tostring(expected), tostring(actual)))
end

local function graphFingerprint(value, seen)
  local kind = type(value)
  if kind ~= "table" then return kind .. ":" .. tostring(value) end
  seen = seen or {}
  if seen[value] then return "ref:" .. tostring(seen[value]) end
  local id = (seen.__count or 0) + 1
  seen.__count = id
  seen[value] = id
  local parts = {}
  for key, item in pairs(value) do
    parts[#parts + 1] = graphFingerprint(key, seen)
      .. "=" .. graphFingerprint(item, seen)
  end
  table.sort(parts)
  return "table{" .. table.concat(parts, ",") .. "}"
end

local function setting(key, label, values, onValue)
  local current = 1
  local object = { key=key, label=label }
  function object:get() return values[current] end
  function object:setValue(value)
    for index, candidate in ipairs(values) do
      if candidate == value then
        current = index
        if onValue then onValue(values[current]) end
        return true
      end
    end
    return false
  end
  function object:row()
    return {
      id="VOXEL_ASCENDANT:" .. key,
      label=label,
      value=function() return values[current] end,
      step=function(_, direction)
        current = ((current + (direction or 1) - 1) % #values) + 1
        if onValue then onValue(values[current]) end
        return true
      end,
    }
  end
  return object
end

local function fixture(ascendantUi)
  local pushes, registered = {}, {}
  local mod = {
    id="VOXEL_ASCENDANT",
    content={screens={register=function(_, name, def) registered[name] = def end}},
    find=function(id)
      if ascendantUi and id == "kanto_ascendant" then
        return { exports={ ascendantUi=ascendantUi } }
      end
    end,
    ui={
      push=function(game, screen, opts)
        pushes[#pushes + 1] = {game=game, screen=screen, opts=opts}
      end,
      ListMenu={new=function(game, title, items, opts)
        opts = opts or {}
        local menu = {
          game=game, title=title, items=items, index=1, opts=opts,
          isOpaque=true, onSelectKey=opts.onSelectKey,
        }
        function menu:update() self.baseUpdates = (self.baseUpdates or 0) + 1 end
        function menu:choose(index)
          self.index = index or self.index
          return self.opts.onChoose(self.items[self.index], self)
        end
        function menu:close() self.closed = true end
        return menu
      end},
    },
  }
  return mod, registered, pushes
end

local reset = {music=0, sprites=0, content=0}
local selectedContent
local standaloneStyle = assert(loadfile("lib/VascMenuStyle.lua"))()
local V = {require=function(name)
  if name == "VascMenuStyle" then return standaloneStyle end
  if name == "LocalContent" then
    return {select=function(profile)
      selectedContent = profile
      reset.content = reset.content + 1
      return true
    end}
  end
  if name == "LocalMusic" then
    return {backToDefault=function() reset.music = reset.music + 1; return true end}
  end
  if name == "LocalSprites" then
    return {backToDefault=function() reset.sprites = reset.sprites + 1; return true end}
  end
  error("unexpected module " .. tostring(name))
end}
local VascMenu = assert(loadfile("lib/VascMenu.lua"))(V)

local showArenaArt, showDiskArt = false, false
local contentProfile = setting("contentProfile.requested", "CONTENT SOURCE",
  {"KASC", "VASC DEFAULT", "RETRO", "CUSTOM"},
  function(value) selectedContent = value end)
local settings = {
  { setting("grid", "V-GRID", {"OFF", "ON"}), "World grid." },
  { setting("terrainHeights", "HEIGHTS",
            {"WORLD", "LOCAL", "FLAT"}),
    "Bounded visual terrain heights." },
  { setting("sky", "SKY", {"FULL", "OFF"}), "Sky presentation." },
  { setting("battles", "3D-BTL", {"MAP", "ARENA", "DISCS"},
            function(value)
              showArenaArt = value == "ARENA"
              showDiskArt = value == "DISCS"
            end),
    "Battle stage." },
  { setting("arenaArt", "ARENA BG", {"V+FRLG", "VASC", "FRLG"}),
    "Authored arena painting source.", when=function() return showArenaArt end },
  { setting("diskArt", "DISK ART", {"V+FRLG", "VASC", "FRLG"}),
    "Location-matched carried disk source.", when=function() return showDiskArt end },
  { setting("battleHudPosition", "HUD POS", {"AUTO", "WIDE"}),
    "Battle HUD position." },
  { setting("trainerBack", "TRAINER BACK", {"OFF", "ON"}),
    "Trainer battle picture." },
  { setting("battleBack", "PKMN BACK", {"OFF", "ON"}),
    "Pokemon back picture." },
  { setting("pokemonUiPartyMenu", "START TEAM UI",
      {"ASC BOX", "ORAS GLASS", "GAME DEFAULT"}),
    "Normal Start PartyMenu presentation." },
  { setting("pokemonUiBattleParty", "BATTLE TEAM UI",
      {"ASC BOX", "ORAS GLASS", "GAME DEFAULT"}),
    "Independent battle PartyMenu presentation." },
  { setting("deviceProfile", "PROFILE", {"AUTO", "HANDHELD"}),
    "Performance profile." },
  { setting("daytime", "DAYTIME", {"AUTO", "DAY"}), "World time." },
}

local mod, registered, pushes = fixture()
local layoutState = { target=1, x=0, y=0, scale=100, resetOne=0, resetAll=0 }
local layoutTargets = { "P FRONT", "P BACK" }
local function layoutDescriptor(label, field, step)
  return {
    label=label,
    value=function()
      if field == "target" then return layoutTargets[layoutState.target] end
      if field == "scale" then return tostring(layoutState.scale) .. "%" end
      return tostring(layoutState[field])
    end,
    step=function(_, direction)
      direction = direction or 1
      if field == "target" then
        layoutState.target = ((layoutState.target + direction - 1)
          % #layoutTargets) + 1
      else
        layoutState[field] = layoutState[field] + direction * step
      end
      return true
    end,
  }
end
local battleLayout = {
  menuRows=function(language)
    return {
      {label="TARGET", descriptor=layoutDescriptor("TARGET", "target", 1),
       help=language == "de" and "Ziel wählen." or "Choose target."},
      {label="X", descriptor=layoutDescriptor("X", "x", 4), help="X axis."},
      {label="Y", descriptor=layoutDescriptor("Y", "y", 4), help="Y axis."},
      {label="SIZE", descriptor=layoutDescriptor("SIZE", "scale", 10), help="Size."},
      {label="RESET ONE", action="layoutResetTarget", right="RESET", help="Reset target."},
      {label="RESET ALL", action="layoutResetAll", right="RESET", help="Reset all."},
    }
  end,
  refreshRows=function(rows)
    for _, row in ipairs(rows) do
      if row.descriptor then row.right = row.descriptor.value() end
    end
  end,
  resetTarget=function()
    layoutState.x, layoutState.y, layoutState.scale = 0, 0, 100
    layoutState.resetOne = layoutState.resetOne + 1
    return true
  end,
  resetAll=function()
    layoutState.x, layoutState.y, layoutState.scale = 0, 0, 100
    layoutState.resetAll = layoutState.resetAll + 1
    return true
  end,
  menuHelp=function(language)
    return language == "de" and "Gespeichertes Kampflayout."
      or "Saved battle layout."
  end,
}
assert(VascMenu.install(mod, {
  settings=settings,
  battleLayout=battleLayout,
  version="3.0.0-rc.10",
  contentProfileRow=function() return contentProfile:row() end,
  animationStatus=function()
    return {
      right="230 MOVES",
      help={en="230 attacker-to-target programs ready.",
            de="230 Programme vom Angreifer zum Ziel sind bereit."},
    }
  end,
}) == true)
assert(type(registered.VascMenu) == "table")
assert(type(registered.VascSettings) == "table")
assert(type(registered.VascBattleLayout) == "table")
assert(type(registered.VascDiagnostics) == "table")
assert(type(registered.VascHelp) == "table")
eq(#VascMenu.pages, 10, "manual fallback covers nine sections plus controls")

local pressed
local stackScreens = {}
local game = {
  input={wasPressed=function(_, key) return pressed == key end},
  stack={
    push=function(_, screen) stackScreens[#stackScreens + 1] = screen end,
    pop=function() stackScreens[#stackScreens] = nil end,
    top=function() return nil end,
  },
  writeOptions=function(self) self.writes = (self.writes or 0) + 1 end,
  writeSave=function(self) self.saveWrites = (self.saveWrites or 0) + 1 end,
  persistOptions=function(self)
    self.persistWrites = (self.persistWrites or 0) + 1
  end,
}

local hub = registered.VascMenu.new(game)
eq(hub.title, "VOXEL ASCENDANT", "hub title")
eq(hub.opts.wrap, true, "hub wraps like the KASC list")
eq(hub.__kantoAscendantStyle, "oras-fullscreen-glass",
   "standalone hub does not use the fullscreen ORAS style")
eq(hub.__voxelAscendantStandaloneStyle, true,
   "standalone style is owned by VASC rather than requiring KASC")
eq(hub.__voxelAscendantFocusHelp, true,
   "standalone VASC publishes its permanent help-strip receipt")
eq(hub.rows, 9, "standalone VASC does not expose its fullscreen row budget")
assert(type(hub.draw) == "function", "standalone style installs its renderer")
hub:draw()
eq(hub.ascendantFocusedHelp, hub.items[1].help,
   "the permanent strip renders the highlighted row's complete help")
eq(hub.__voxelAscendantRoot, true, "root receives the full-width label layout")
local localUi = VascMenu._standaloneUi(mod)
for index = 1, 9 do
  assert(localUi.displayWidth(hub.items[index].label) <= localUi.rootLabelBudget,
    "root label must fit verbatim: " .. hub.items[index].label)
end
eq(localUi.displayWidth("VIEW + WORLD"), 96,
  "the local plus glyph keeps the native eight-pixel advance")
eq(localUi.displayWidth("HUD 75%"), 56,
  "the local percent glyph keeps the native eight-pixel advance")
eq(#hub.items, 10, "nine requested sections plus contextual HELP")
eq(hub.items[1].label, "VIEW + WORLD")
eq(hub.items[2].label, "WEATHER + SCENERY")
eq(hub.items[3].label, "BATTLE")
eq(hub.items[4].label, "SKINS & OVERLAYS")
eq(hub.items[5].label, "POKéMON + MODELS")
eq(hub.items[6].label, "WILDS + FOLLOWERS")
eq(hub.items[7].label, "PERFORMANCE")
eq(hub.items[8].label, "USER CONTENT")
eq(hub.items[9].label, "ADVANCED")

hub:choose(1)
eq(pushes[#pushes].screen, "VascSettings", "world opens its settings page")
eq(pushes[#pushes].opts.section, "world")
hub:choose(2)
eq(pushes[#pushes].opts.section, "weather", "weather owns a direct page")
hub:choose(3)
eq(pushes[#pushes].opts.section, "battle", "battle owns a direct page")
hub:choose(4)
eq(pushes[#pushes].opts.section, "skins")
hub:choose(5)
eq(pushes[#pushes].opts.section, "pokemon")
hub:choose(6)
eq(pushes[#pushes].opts.section, "wilds")
hub:choose(7)
eq(pushes[#pushes].opts.section, "performance")
hub:choose(8)
eq(pushes[#pushes].opts.section, "user")
hub:choose(9)
eq(pushes[#pushes].opts.section, "advanced")
hub:choose(10)
eq(stackScreens[#stackScreens].title, "VASC START HELP",
   "HELP remains a selectable fullscreen popup")

local world = registered.VascSettings.new(game, {section="world"})
eq(world.items[1].label, "V-GRID")
eq(world.items[2].label, "HEIGHTS",
   "terrain-height switch is available in View + World")
eq(world.items[2].right, "WORLD")
world:choose(2)
eq(world.items[2].right, "LOCAL",
   "terrain-height mode skips the retired vertical slice")
world:choose(2)
eq(world.items[2].right, "FLAT",
   "terrain-height mode cycles directly from LOCAL to FLAT without SLICE")

local battle = registered.VascSettings.new(game, {section="battle"})
eq(battle.title, "BATTLE")
eq(battle.items[1].label, "3D-BTL")
eq(battle.items[1].right, "MAP")
battle:choose(1)
eq(battle.items[1].right, "ARENA", "A selects the authored arena")
eq(battle.items[2].label, "ARENA BG",
   "ARENA BG appears immediately when ARENA is selected")
eq(battle.items[2].right, "V+FRLG")
battle:choose(2)
eq(battle.items[2].right, "VASC", "A advances the arena source")
pressed = "left"
battle:update()
pressed = nil
eq(battle.items[2].right, "V+FRLG", "Left reverses a setting")
assert((game.writes or 0) >= 2, "direct settings are persisted immediately")

pressed = "start"
battle:update()
pressed = nil
eq(stackScreens[#stackScreens].title, "ARENA BG",
   "START opens highlighted-row help")

battle:choose(1)
eq(battle.items[1].right, "DISCS")
eq(battle.items[2].label, "DISK ART",
   "DISK ART appears immediately when DISCS is selected")
eq(battle.items[2].right, "V+FRLG")
for _, item in ipairs(battle.items) do
  assert(item.label ~= "ARENA BG",
         "ARENA BG must disappear immediately outside ARENA")
end

local animationIndex
local layoutIndex
for i, item in ipairs(battle.items) do
  if item.label == "MOVE ANIMATIONS" then animationIndex = i end
  if item.label == "BATTLE LAYOUT" then layoutIndex = i end
end
assert(layoutIndex, "battle page exposes saved per-role layout controls")
battle:choose(layoutIndex)
eq(pushes[#pushes].screen, "VascBattleLayout")
local layoutMenu = registered.VascBattleLayout.new(game)
eq(layoutMenu.title, "BATTLE LAYOUT")
eq(#layoutMenu.items, 7, "six controls plus contextual HELP")
eq(layoutMenu.items[1].right, "P FRONT")
layoutMenu:choose(1)
eq(layoutMenu.items[1].right, "P BACK", "target role advances")
layoutMenu:choose(2)
eq(layoutMenu.items[2].right, "4", "target X changes and refreshes")
layoutMenu:choose(5)
eq(layoutState.resetOne, 1, "selected role reset is called")
eq(layoutMenu.items[2].right, "0")
layoutMenu:choose(6)
eq(layoutState.resetAll, 1, "all-role reset is called")
assert(animationIndex, "battle page exposes move-animation receipt")
eq(battle.items[animationIndex].right, "230 MOVES")
battle:choose(animationIndex)
eq(stackScreens[#stackScreens].title, "MOVE ANIMATIONS",
   "battle page opens the animation acceptance help")

local pokemon = registered.VascSettings.new(game, {section="pokemon"})
eq(pokemon.title, "POKéMON + MODELS")
eq(pokemon.items[1].label, "TRAINER BACK")
eq(pokemon.items[2].label, "PKMN BACK")
eq(pokemon.items[3].label, "SPRITE GUIDE")
pokemon:choose(3)
eq(pushes[#pushes].screen, "VascUserSpritesHelp")

local skins = registered.VascSettings.new(game, {section="skins"})
eq(skins.title, "SKINS & OVERLAYS")
eq(skins.items[1].label, "START TEAM UI")
eq(skins.items[1].right, "ASC BOX")
eq(skins.items[2].label, "BATTLE TEAM UI")
eq(skins.items[2].right, "ASC BOX")
skins:choose(1)
eq(skins.items[1].right, "ORAS GLASS",
  "normal Start PartyMenu skin is independently selectable")
eq(skins.items[2].right, "ASC BOX",
  "normal Start skin changed the battle-team selection")

local wilds = registered.VascSettings.new(game, {section="wilds"})
eq(wilds.title, "WILDS + FOLLOWERS")
eq(wilds.items[1].label, "MOD OPTIONS")
wilds:choose(1)
eq(pushes[#pushes].screen, "OptionsMenu",
   "independent Wilds/follower mods retain their own options")
wilds:choose(2)
eq(stackScreens[#stackScreens].title, "COMPATIBILITY")

local user = registered.VascSettings.new(game, {section="user"})
eq(user.title, "USER CONTENT")
eq(user.items[1].label, "CONTENT SOURCE")
eq(user.items[1].right, "KASC")
user:choose(1)
eq(user.items[1].right, "VASC DEFAULT")
eq(selectedContent, "VASC DEFAULT",
   "one shared profile controls sprite and music ownership")
user:choose(2)
eq(pushes[#pushes].screen, "VascContentStatus")
user:choose(3)
eq(pushes[#pushes].screen, "VascUserMusic")
user:choose(4)
eq(pushes[#pushes].screen, "VascUserSprites")
assert(VascMenu.restoreAll(game), "restore selects the independent VASC profile")
eq(selectedContent, "VASC_DEFAULT")
eq(reset.content, 1, "content reset uses the single profile controller")

local advanced = registered.VascSettings.new(game, {section="advanced"})
eq(advanced.title, "ADVANCED")
advanced:choose(1)
eq(pushes[#pushes].screen, "OptionsMenu", "all engine/mod options remain reachable")
advanced:choose(2)
eq(stackScreens[#stackScreens].title, "VASC START HELP")
for _, item in ipairs(advanced.items) do
  assert(item.label ~= "RC DIAGNOSTICS",
    "diagnostics row appeared without an installed diagnostics service")
end
for _, item in ipairs(advanced.items) do
  assert(item.screen ~= "VascSupportLogs",
    "broken support-log route remained visible")
end
eq(advanced.items[3].right, "3.0.0-rc.10")
advanced:choose(3)
eq(stackScreens[#stackScreens].title, "VERSION")
battle.index = 1
pressed = "left"
battle:update()
pressed = nil
eq(battle.items[1].right, "ARENA")
eq(battle.items[2].label, "ARENA BG",
   "reverse stepping back to ARENA restores its source row live")
for _, item in ipairs(battle.items) do
  assert(item.label ~= "DISK ART",
         "DISK ART must disappear immediately outside DISCS")
end

local help = registered.VascHelp.new(game, {
  title="HUD POS", body="Choose where the readable battle HUD belongs."
})
eq(help.title, "HUD POS")
help:choose(#help.items)
eq(help.closed, true, "fallback help closes with its final row")
for _, page in ipairs(VascMenu.pages) do
  assert(type(page.title) == "string" and page.title ~= "")
  assert(#page >= 3, "every fallback page contains actionable guidance")
end

local standaloneForeign = VascMenu.decorateActive(mod, {})
eq(standaloneForeign.__kantoAscendantStyle, "oras-fullscreen-glass",
   "standalone VASC submenus do not receive the fullscreen skin")
eq(standaloneForeign.__voxelAscendantStandaloneStyle, true)

-- With public KASC active its Start-menu collector still opens this exact
-- VASC-owned tree. KASC's optional UI export is deliberately not imported:
-- menu rendering/help/save ownership remains standalone and update-proof.
local guidedSpecs, decorated = {}, 0
local exactUi = {
  guidedList=function(activeGame, spec)
    guidedSpecs[#guidedSpecs + 1] = spec
    local items = {}
    for i, row in ipairs(spec.rows) do items[i] = row end
    items[#items + 1] = {label="HELP", value="__kasc_help"}
    local menu = {
      game=activeGame, title=spec.title, items=items, index=1,
      __kantoAscendantLayout=true, __kantoAscendantStyle="firered",
      rows=6,
    }
    menu.onSelectKey=function(item)
      menu.helpFor = item and item.label
    end
    function menu:update() self.baseUpdates = (self.baseUpdates or 0) + 1 end
    function menu:choose(index)
      self.index = index or self.index
      return spec.onChoose(self.items[self.index], self)
    end
    return menu
  end,
  decorate=function(screen)
    decorated = decorated + 1
    screen.__kantoAscendantLayout = true
    screen.__kantoAscendantStyle = "firered"
    return screen
  end,
}
local kascMod, kascRegistered = fixture(exactUi)
VascMenu.install(kascMod, {settings=settings})
local kascHub = kascRegistered.VascMenu.new(game)
eq(#guidedSpecs, 0, "VASC does not import KASC's guidedList implementation")
eq(kascHub.__kantoAscendantStyle, "oras-fullscreen-glass",
   "VASC does not retain fullscreen ORAS while KASC is active")
eq(kascHub.__voxelAscendantStandaloneStyle, true,
   "the menu remains VASC-owned while KASC is active")
eq(kascHub.__voxelAscendantFocusHelp, true,
   "VASC keeps the permanent help strip inside the KASC options route")
eq(kascHub.rows, 9,
   "VASC does not keep the fullscreen list-row budget")
pressed = "start"
kascHub:update()
pressed = nil
eq(stackScreens[#stackScreens].title, "VIEW + WORLD",
   "START opens VASC's highlighted-row help while KASC is active")
local kascBattle = kascRegistered.VascSettings.new(game, {section="battle"})
eq(kascBattle.items[2].label, "ARENA BG",
   "KASC list receives the conditional ARENA row")
kascBattle:choose(1)
eq(kascBattle.items[2].label, "DISK ART",
   "KASC list receives the conditional DISCS row")
for _, item in ipairs(kascBattle.items) do
  assert(item.label ~= "ARENA BG",
         "KASC list updates conditional rows without reopening the screen")
end
local foreign = VascMenu.decorateActive(kascMod, {})
eq(foreign.__kantoAscendantStyle, "oras-fullscreen-glass")
eq(foreign.__voxelAscendantStandaloneStyle, true,
   "submenus also keep VASC-owned presentation")
eq(decorated, 0, "VASC does not mutate screens through KASC's UI facade")

-- In the combined stack KASC owns every battle-HUD choice. VASC's stage,
-- camera and music remain available, while both its ORAS rows and its legacy
-- readable-HUD rows disappear from this independently rendered VASC tree.
local delegatedSettings = {
  { setting("battles", "3D-BTL", {"MAP", "ARENA", "DISCS"}),
    "Battle stage." },
  { setting("battleCameraDistance", "BTL DIST", {"3X", "2X", "1X"}),
    "Battle camera distance." },
}
local delegatedHudRows = {
  {"battleHudStyle", "BATTLE HUD"},
  {"hud_language", "HUD LANGUAGE"},
  {"hud_scale", "ORAS HUD SIZE"},
  {"oras_status_glass", "STATUS GLASS"},
  {"oras_text_glass", "TEXT GLASS"},
  {"status_anchor", "ORAS HUD ANCHOR"},
  {"player_hud_x", "PLAYER HUD X"},
  {"player_hud_y", "PLAYER HUD Y"},
  {"enemy_hud_x", "ENEMY HUD X"},
  {"enemy_hud_y", "ENEMY HUD Y"},
  {"wild_dvs", "WILD DVs"},
  {"battleHudPosition", "HUD POS"},
  {"battleHudScale", "HUD SIZE"},
  {"battleHudAlpha", "HUD ALPHA"},
  {"battleHudGender", "HUD GENDER"},
  {"battleHudExp", "HUD EXP"},
  {"battleHudCaught", "HUD CAUGHT"},
}
for _, spec in ipairs(delegatedHudRows) do
  delegatedSettings[#delegatedSettings + 1] = {
    setting(spec[1], spec[2], {"SHOULD NOT APPEAR"}),
    "Delegated to KASC.",
    when=function() return false end,
  }
end

local delegatedMod, delegatedRegistered = fixture(exactUi)
VascMenu.install(delegatedMod, {settings=delegatedSettings})
local delegatedBattle = delegatedRegistered.VascSettings.new(
  game, {section="battle"})
local delegatedSeen = {}
for _, item in ipairs(delegatedBattle.items) do
  delegatedSeen[item.settingKey or item.label] = true
end
eq(delegatedSeen.battles, true,
  "KASC ownership hid VASC's independent battle stage")
eq(delegatedSeen.battleCameraDistance, true,
  "KASC ownership hid VASC's independent battle camera")
for _, spec in ipairs(delegatedHudRows) do
  eq(delegatedSeen[spec[1]], nil,
    "KASC-owned VASC menu leaked HUD row " .. spec[1])
end

-- Universal Translation publishes the language actually selected at boot.
-- VASC consumes that public receipt for every category and row-help page,
-- while remaining entirely usable when the optional package is absent.
local universalDe, universalDeRegistered = fixture()
universalDe.find = function(id)
  if id == "translation-german-universal" then
    return { exports={ bootLanguage="de" } }
  end
end
VascMenu.install(universalDe, {settings=settings, version="3.0.0-rc.10"})
local universalDeWorld = universalDeRegistered.VascSettings.new(
  game, {section="world"})
assert(universalDeWorld.items[2].help:find("Visuelle Geländehöhen", 1, true),
  "Universal German boot receipt did not localize VASC row help")
universalDeWorld:choose(#universalDeWorld.items)
eq(stackScreens[#stackScreens].title, "SICHT + WELT HILFE",
  "Universal German did not localize the VASC help title")

local universalEn, universalEnRegistered = fixture()
universalEn.find = function(id)
  if id == "translation-german-universal" then
    return { exports={ bootLanguage="en" } }
  elseif id == "deutsch" then
    return { id="deutsch" }
  end
end
VascMenu.install(universalEn, {settings=settings, version="3.0.0-rc.10"})
local universalEnWorld = universalEnRegistered.VascSettings.new(
  game, {section="world"})
eq(universalEnWorld.items[2].help, "Bounded visual terrain heights.",
  "Universal English boot receipt lost to a legacy German package")

-- Gen2 builds its UI adapter before installing VascMenu's complete config.
-- The later Universal boot receipt must reach chrome, help rows and popups,
-- not only the hand-localized setting labels. Cover both shipped copies.
for _,dir in ipairs({"lib/", "lib/gen2_a21_shared/"})do
  for _,lang in ipairs({"en","de"})do
    local host,registered=fixture()
    host.find=function(id)
      if id=="translation-german-universal"then return {exports={bootLanguage=lang}}end
    end
    local style=assert(loadfile(dir.."VascMenuStyle.lua"))()
    local earlyUi=style.new(host)
    local controller=assert(loadfile(dir.."VascMenu.lua"))(V)
    controller.install(host,{settings=settings,ui=earlyUi})
    local page=registered.VascSettings.new(game,{section="world"})
    eq(page.__vascLanguage,lang,"preconstructed UI language: "..dir)
    eq(page.items[#page.items].label,lang=="de" and "HILFE" or "HELP")
    page:choose(#page.items)
    eq(stackScreens[#stackScreens].language,lang,"preconstructed UI help language")
  end
end

-- German translation packs receive the same tree and contextual START help;
-- only the prose changes. Labels stay stable so guides and controller muscle
-- memory are identical between languages.
local germanMod, germanRegistered = fixture()
VascMenu.install(germanMod, {
  settings=settings, language="de", version="3.0.0-rc.10",
  contentProfileRow=function() return contentProfile:row() end,
  animationStatus=function()
    return {
      right="230 MOVES",
      help={en="230 attacker-to-target programs ready.",
            de="230 Programme vom Angreifer zum Ziel sind bereit."},
    }
  end,
})
local germanHub = germanRegistered.VascMenu.new(game)
eq(germanHub.items[1].label, "SICHT + WELT")
eq(germanHub.items[2].label, "WETTER + KULISSE")
eq(germanHub.items[3].label, "KAMPF")
eq(germanHub.items[4].label, "DESIGN + HUD")
eq(germanHub.items[5].label, "POKéMON + MODELLE")
eq(germanHub.items[6].label, "WILDE + BEGLEITER")
eq(germanHub.items[7].label, "LEISTUNG")
eq(germanHub.items[8].label, "EIGENE INHALTE")
eq(germanHub.items[9].label, "ERWEITERT")
assert(germanHub.items[1].help:find("Kamera", 1, true),
       "German category START help was not selected")
germanHub.onSelectKey(germanHub.items[1], germanHub)
eq(stackScreens[#stackScreens].language, "de",
   "German contextual help keeps localized controls")
local germanWeather = germanRegistered.VascSettings.new(game, {section="weather"})
local daytimeRow
for _, item in ipairs(germanWeather.items) do
  if item.settingKey == "daytime" then daytimeRow = item end
end
assert(daytimeRow and daytimeRow.help:find("Outdoor%-Tageszeit"),
       "German row-level START help is missing")
local germanBattle = germanRegistered.VascSettings.new(game, {section="battle"})
eq(germanBattle.title, "KAMPF")
local germanAnimation
for _, item in ipairs(germanBattle.items) do
  if item.label == "ATTACKEN-ANIM." then germanAnimation = item end
end
assert(germanAnimation and germanAnimation.help:find("Programme", 1, true),
       "German move-animation help was not selected")
eq(germanAnimation.right, "230 ATTACKEN",
  "German menu leaked the English move-count suffix")
VascMenu.showHelp(germanMod, game, "ASCENDANT-HILFE", "Deutsch")
eq(stackScreens[#stackScreens].title, "ASCENDANT-HILFE",
  "already localized help title received a duplicate HILFE suffix")

-- Bag ownership and only the complete WIDE presentations are public rows in
-- the same VASC tree. Compact renderers remain internal fallbacks.
local bagMenuSettings = {
  { setting("qol_ui_skin", "OVERWORLD MENUS",
      {"ORAS GLASS", "GAME DEFAULT"}), "Native UI presentation." },
  { setting("qol_bag_skin", "BAG MENU",
      {"GAME/KASC", "D/P ORAS WIDE", "FRLG ORAS WIDE"}),
    "Choose the owner-safe Bag presentation." },
  { setting("qol_bag_color", "TASCHEN-AKZENT",
      {"AUTO", "ROT", "BLAU", "GRÜN"}),
    "Choose only the VASC Bag accent." },
  { setting("qol_bag_form", "TASCHENFORM",
      {"AUTO", "NORMAL", "HENKEL"}),
    "Choose only the VASC Bag silhouette." },
}
local bagMenuMod, bagMenuRegistered = fixture()
VascMenu.install(bagMenuMod, {settings=bagMenuSettings})
local bagSkins = bagMenuRegistered.VascSettings.new(
  game, {section="skins"})
eq(bagSkins.items[1].label, "OVERWORLD MENUS")
eq(bagSkins.items[2].label, "BAG MENU")
eq(bagSkins.items[2].right, "GAME/KASC",
  "safe Bag owner is not the first VASC menu rung")
bagSkins:choose(2)
eq(bagSkins.items[2].right, "D/P ORAS WIDE",
  "D/P ORAS WIDE is not selectable in the VASC menu")
bagSkins:choose(2)
eq(bagSkins.items[2].right, "FRLG ORAS WIDE",
  "FRLG ORAS WIDE is not selectable in the VASC menu")
eq(bagSkins.items[3].label, "TASCHEN-AKZENT")
eq(bagSkins.items[4].label, "TASCHENFORM")

-- ORAS fullscreen is the only public VASC/KASC control-centre skin. It
-- requests a responsive logical surface, keeps focused help visible, disables
-- cartridge palette recolouring and restores every graphics-state boundary.
-- The compact renderer remains covered below only as an internal fallback.
local mainHandle = assert(io.open("main_gen1.lua", "rb"))
local mainSource = mainHandle:read("*a")
mainHandle:close()
assert(mainSource:find('"vascMenuSkin", "VASC MENU"', 1, true),
  "Gen1 entry does not define the saved VASC menu-skin setting")
assert(mainSource:find('menuSkinSetting=VascMenuSkinSetting', 1, true),
  "Gen1 entry does not wire the saved setting into VascMenu")
assert(mainSource:find('{ "oras_fullscreen" }', 1, true),
  "Gen1 entry exposes a compact VASC menu choice")
assert(mainSource:find('aliasLegacy("firered", "oras_fullscreen")', 1, true),
  "Gen1 entry does not migrate the former compact menu value")
-- The test resolver keeps a private compact rung solely to exercise the
-- emergency renderer. Production source above exposes ORAS FULLSCREEN only.
local menuSkin = setting("vascMenuSkin", "VASC MENU",
  {"oras_fullscreen", "firered"})
local skinMod, skinRegistered = fixture()
local skinStack, skinTop, skinPressed = {}, nil, nil
local skinGame = {
  save={ options={ modOptions={} } },
  mods={ modOptions={} },
  input={wasPressed=function(_, key) return skinPressed == key end},
  stack={
    push=function(_, screen) skinStack[#skinStack + 1] = screen; skinTop = screen end,
    pop=function() skinStack[#skinStack] = nil; skinTop = skinStack[#skinStack] end,
    top=function() return skinTop end,
  },
  writeOptions=function(self) self.writes = (self.writes or 0) + 1 end,
}
VascMenu.install(skinMod, {
  settings={
    {menuSkin, "Choose only the VASC/KASC settings presentation."},
    {setting("qol_ui_skin", "OVERWORLD MENUS",
      {"GAME DEFAULT", "ORAS GLASS"}), "Ordinary menu presentation."},
  },
  menuSkinSetting=menuSkin,
})
local skinHub = skinRegistered.VascMenu.new(skinGame)
local defaultSkinWidth = select(1, skinHub:uiSize())
assert(defaultSkinWidth >= 360 and defaultSkinWidth <= 640,
  "ORAS default did not request a bounded wide width")
eq(select(2, skinHub:uiSize()), 288, "ORAS default did not request full height")
eq(skinHub.rows, 9, "ORAS default did not expose its full row layout")
local skinPage = skinRegistered.VascSettings.new(skinGame, {section="skins"})
eq(skinPage.items[1].label, "VASC MENU")
eq(skinPage.items[2].label, "OVERWORLD MENUS",
  "the VASC menu skin is separate from ordinary menu skins")

local graphics = love.graphics
local previousGraphics = {}
for _, key in ipairs({
  "push", "pop", "origin", "newShader", "getShader", "setShader",
  "setLineWidth", "setBlendMode", "getPixelDimensions", "getDimensions",
}) do previousGraphics[key] = graphics[key] or false end
local isolation = {
  push=0, pop=0, origin=0, shader=0, shaderApplied=0,
  shaderSent=0, blend=0, lineWidths={},
}
graphics.push = function(mode) eq(mode, "all"); isolation.push = isolation.push + 1 end
graphics.pop = function() isolation.pop = isolation.pop + 1 end
graphics.origin = function() isolation.origin = isolation.origin + 1 end
local activeShader
local glassShader = {}
function glassShader:send(name, value)
  eq(name, "vascGlassInk")
  assert(type(value) == "table" and value[4] == 1,
    "ORAS glyph shader did not receive an opaque ink colour")
  isolation.shaderSent = isolation.shaderSent + 1
end
graphics.newShader = function(source)
  assert(source:find("glyph.a", 1, true),
    "ORAS glyph shader does not use the source alpha mask")
  return glassShader
end
graphics.getShader = function() return activeShader end
graphics.setShader = function(value)
  assert(value == nil or value == glassShader,
    "ORAS renderer installed an unrelated shader")
  activeShader = value
  isolation.shader = isolation.shader + 1
  if value == glassShader then
    isolation.shaderApplied = isolation.shaderApplied + 1
  end
end
graphics.setLineWidth = function(value)
  isolation.lineWidths[#isolation.lineWidths + 1] = value
end
graphics.setBlendMode = function(mode, alpha)
  eq(mode, "alpha"); eq(alpha, "alphamultiply"); isolation.blend = isolation.blend + 1
end
local pixelWidth, pixelHeight = 3420, 2214
graphics.getPixelDimensions = function() return pixelWidth, pixelHeight end
graphics.getDimensions = function() return 1710, 1107 end

eq(menuSkin:get(), "oras_fullscreen", "ORAS fullscreen is not the live default")
local orasWidth, orasHeight = skinPage:uiSize()
eq(orasWidth, 448, "ultrawide logical width follows the physical aspect grid")
eq(orasHeight, 288, "ORAS fullscreen uses the reviewed logical height")
pixelWidth, pixelHeight = 1080, 2400
eq(select(1, skinPage:uiSize()), 360,
  "portrait aspect is bounded by the readable fullscreen minimum")
pixelWidth, pixelHeight = 3840, 1080
eq(select(1, skinPage:uiSize()), 640,
  "ultrawide aspect is bounded by the renderer-safe maximum")
pixelWidth, pixelHeight = 3420, 2214
eq(skinPage:drawsWidescreen(), true)
eq(skinPage:wantsFillScale(), true,
  "ORAS fullscreen does not request Gen1 fill-scale presentation")
eq(skinPage.rows, 9, "ORAS fullscreen exposes its larger row budget")
eq(skinPage.__kantoAscendantStyle, "oras-fullscreen-glass")
local zones = skinPage:sgbPalettes()
eq(zones[1].colors, false, "ORAS glass bypasses the cartridge palette shader")
eq(zones[1].w, orasWidth)
eq(zones[1].h, orasHeight)
skinPage:draw()
eq(isolation.push, 1, "settings draw pushes the complete graphics state")
eq(isolation.pop, 1, "settings draw restores the complete graphics state")
assert(isolation.origin >= 1 and isolation.shader >= 1 and isolation.blend >= 1,
  "settings draw did not neutralize transform/shader/blend state")
assert(isolation.shaderApplied > 0 and isolation.shaderSent > 0,
  "ORAS text did not use the white alpha-mask glyph shader")
eq(activeShader, nil, "ORAS glyph shader leaked after the settings draw")
eq(isolation.lineWidths[1], 2, "ORAS outer edition frame is not emphasized")
eq(isolation.lineWidths[2], 1, "ORAS edition frame did not restore line width")
eq(skinPage.ascendantFocusedHelp, skinPage.items[1].help,
  "ORAS fullscreen permanently renders focused row help")
local geometry = assert(skinPage.__vascOrasGeometry)
eq(geometry.width, orasWidth)
eq(geometry.height, orasHeight)
assert(geometry.help.x >= geometry.list.x + geometry.list.w,
  "ORAS help panel overlaps the navigation panel")
assert(geometry.help.x + geometry.help.w <= orasWidth,
  "ORAS help panel exceeds the logical surface")

local ordinary = skinMod.ui.ListMenu.new(skinGame, "ITEMS", {}, {})
eq(ordinary.__vascMenuSkin, nil,
  "the VASC/KASC skin leaked into an ordinary ListMenu")
eq(ordinary.uiSize, nil,
  "ordinary Bag/PC/game lists were given VASC fullscreen geometry")

skinPage:choose(1)
eq(menuSkin:get(), "firered", "FIRE RED remains selectable")
eq(select(1, skinPage:uiSize()), 160, "live return restores classic width")
eq(select(2, skinPage:uiSize()), 144, "live return restores classic height")
eq(skinPage.rows, 5, "live return restores classic row budget")
eq(skinPage.__kantoAscendantStyle, "firered-focus-help")
eq(skinPage:wantsFillScale(), false,
  "FireRed compact unexpectedly owns Gen1 fill-scale presentation")

skinPage:choose(1)
local skinUi = VascMenu._standaloneUi(skinMod)
local publicMenuBridge = assert(VascMenu.menuSkinBridge(skinMod))
eq(publicMenuBridge.schema, VascMenu.MENU_SKIN_BRIDGE_SCHEMA,
  "public KASC menu-skin bridge schema")
eq(publicMenuBridge.currentSkin(), "oras_fullscreen",
  "public bridge does not read the live VASC menu setting")

-- A foreign guided list retains KASC's controller and exact FireRed methods;
-- only its presentation is multiplexed when ORAS is explicitly selected.
local foreignItems = {}
for index = 1, 12 do
  foreignItems[index] = {
    label="KASC " .. tostring(index), help="HELP",
    ascendantKey="kasc-row:" .. tostring(index),
  }
end
local foreign = skinMod.ui.ListMenu.new(skinGame, "KANTO ASCENDANT",
  foreignItems, {})
local fireDraws, fireUpdates = 0, 0
local foreignChoose = function() return "kasc-choice" end
foreign.__kantoAscendantLayout = true
foreign.__kantoAscendantStyle = "firered-focus-help"
foreign.__kantoAscendantFocusHelp = true
foreign.ascendantFocusHelp = function(item) return item and item.help end
foreign.rows, foreign.index, foreign.scroll = 5, 7, 2
foreign.onChoose = foreignChoose
foreign.draw = function() fireDraws = fireDraws + 1 end
foreign.update = function() fireUpdates = fireUpdates + 1 end
foreign.uiSize = function() return 160, 144 end
foreign.drawsWidescreen = function() return false end
foreign.wantsFillScale = function() return false end
foreign.sgbPalettes = function() return { { colors=true } } end
local decorated, didDecorate = publicMenuBridge.decorateGuided(
  foreign, foreign.ascendantFocusHelp, 9)
eq(decorated, foreign, "bridge rebuilt KASC's controller")
eq(didDecorate, true, "bridge did not acknowledge the guided KASC list")
eq(foreign.__kantoAscendantStyle, "oras-fullscreen-glass")
eq(foreign.rows, 9, "KASC ORAS root did not receive the fullscreen row budget")
eq(select(1, foreign:uiSize()), orasWidth)
eq(foreign.drawsWidescreen(foreign), true)
eq(foreign:wantsFillScale(), true,
  "bridged KASC ORAS root does not request Gen1 fill-scale presentation")
eq(foreign.onChoose, foreignChoose, "KASC callback ownership changed")
foreign:update(.016)
eq(fireUpdates, 1, "ORAS adapter did not delegate KASC update exactly once")
local bridgedUpdate = foreign.update
publicMenuBridge.decorateGuided(foreign, foreign.ascendantFocusHelp, 9)
eq(foreign.update, bridgedUpdate, "guided bridge stacked on a second install")

menuSkin:setValue("firered")
foreign:update(.016)
eq(foreign.__kantoAscendantStyle, "firered-focus-help",
  "live return did not restore KASC's FireRed renderer")
eq(foreign.rows, 5, "live return did not restore KASC's row budget")
eq(foreign.index, 7, "live skin switch lost KASC focus")
eq(foreign.scroll, 2, "live skin switch lost KASC FireRed scroll")
eq(foreign:wantsFillScale(), false,
  "bridged KASC FireRed root lost its native fill-scale contract")
foreign:draw()
eq(fireDraws, 1, "FIRE RED did not call KASC's original draw exactly once")

menuSkin:setValue("oras_fullscreen")
foreign:update(.016)
eq(foreign.__kantoAscendantStyle, "oras-fullscreen-glass",
  "same KASC menu did not switch back to ORAS live")
eq(foreign.index, 7, "ORAS return lost KASC focus")

-- KASC does not persist cursor state itself.  VASC's presentation bridge keeps
-- a process-local, Game-scoped slot for each skin so close/reopen returns to
-- the last row in that skin without writing options/save data.  Stable KASC
-- item keys survive a conditionally inserted row, while another Game and
-- another KASC page cannot inherit this navigation receipt.
local writesBeforeKascMemory = {
  options=skinGame.writes or 0,
  save=skinGame.saveWrites or 0,
  persist=skinGame.persistWrites or 0,
}
foreign.index, foreign.scroll = 10, 1
foreign:update(.016)
menuSkin:setValue("firered")
foreign:update(.016)
eq(foreign.index, 7, "FIRE RED slot was overwritten by ORAS navigation")
eq(foreign.scroll, 2, "FIRE RED scroll was overwritten by ORAS navigation")
foreign.index, foreign.scroll = 4, 0
foreign:update(.016)
foreign:close()

local function reopenForeign(game, title, items, index, scroll)
  local menu = skinMod.ui.ListMenu.new(game, title, items, {})
  menu.__kantoAscendantLayout = true
  menu.__kantoAscendantStyle = "firered-focus-help"
  menu.__kantoAscendantFocusHelp = true
  menu.ascendantFocusHelp = function(item) return item and item.help end
  menu.rows, menu.index, menu.scroll = 5, index or 1, scroll or 0
  menu.onChoose = foreignChoose
  menu.draw = function() end
  menu.update = function(self)
    self.nativeUpdates = (self.nativeUpdates or 0) + 1
  end
  menu.uiSize = function() return 160, 144 end
  menu.drawsWidescreen = function() return false end
  menu.wantsFillScale = function() return false end
  menu.sgbPalettes = function() return { { colors=true } } end
  publicMenuBridge.decorateGuided(menu, menu.ascendantFocusHelp, 9)
  return menu
end

local reopenedFire = reopenForeign(skinGame, "KANTO ASCENDANT",
  foreignItems, 1, 0)
eq(reopenedFire.index, 4, "FIRE RED focus did not survive close/reopen")
eq(reopenedFire.scroll, 0, "FIRE RED scroll did not survive close/reopen")
eq(reopenedFire.__vascKascMenuSkinBridge.navigation.schema,
  "voxel-ascendant/kasc-navigation/v1", "KASC navigation receipt schema")

menuSkin:setValue("oras_fullscreen")
reopenedFire:update(.016)
eq(reopenedFire.index, 10, "ORAS focus did not restore its separate slot")
eq(reopenedFire.scroll, 1, "ORAS scroll did not restore its separate slot")
reopenedFire:close()

local insertedItems = { { label="INSERTED", help="CONDITIONAL" } }
for _, item in ipairs(foreignItems) do
  insertedItems[#insertedItems + 1] = item
end
local reorderedOras = reopenForeign(skinGame, "KANTO ASCENDANT",
  insertedItems, 1, 0)
eq(reorderedOras.items[reorderedOras.index].label, "KASC 10",
  "KASC stable row identity did not survive an inserted item")
eq(reorderedOras.index, 11, "KASC stable row restored the stale numeric index")
eq(reorderedOras.scroll, 2,
  "KASC inserted-row restore did not clamp the ORAS viewport")

local isolatedGame = { input=skinGame.input, stack=skinGame.stack }
local isolated = reopenForeign(isolatedGame, "KANTO ASCENDANT",
  foreignItems, 2, 0)
eq(isolated.index, 2, "KASC navigation leaked into another Game owner")
local otherPage = reopenForeign(skinGame, "KASC CATEGORY",
  foreignItems, 3, 0)
eq(otherPage.index, 3, "KASC root navigation leaked into another page")

local duplicateItems = {
  {label="LEFT A"}, {label="DUPLICATE"}, {label="RIGHT A"},
  {label="LEFT B"}, {label="DUPLICATE"}, {label="RIGHT B"},
}
local duplicate = reopenForeign(skinGame, "KASC DUPLICATES",
  duplicateItems, 5, 0)
duplicate:update(.016)
duplicate:close()
local duplicateAgain = reopenForeign(skinGame, "KASC DUPLICATES",
  duplicateItems, 1, 0)
eq(duplicateAgain.index, 5,
  "second duplicate row restored as the first occurrence")
local reorderedDuplicates = {
  duplicateItems[4], duplicateItems[5], duplicateItems[6],
  duplicateItems[1], duplicateItems[2], duplicateItems[3],
}
local duplicateReordered = reopenForeign(skinGame, "KASC DUPLICATES",
  reorderedDuplicates, 1, 0)
eq(duplicateReordered.index, 2,
  "duplicate restore ignored its stable neighbour fingerprint")
eq(duplicateReordered.items[duplicateReordered.index - 1].label, "LEFT B",
  "duplicate restore selected the wrong reordered occurrence")
eq(skinGame.writes or 0, writesBeforeKascMemory.options,
  "KASC navigation memory performed an options write")
eq(skinGame.saveWrites or 0, writesBeforeKascMemory.save,
  "KASC navigation memory performed a save write")
eq(skinGame.persistWrites or 0, writesBeforeKascMemory.persist,
  "KASC navigation memory performed a persist write")

-- The live RC QA helper shares the already running Game object while it swaps
-- in cloned save/options backings. Its private isolation seam must therefore
-- put both process-local navigation stores on disposable graphs and restore
-- the exact prior objects/positions on normal and exceptional teardown.
local originalVascNav = VascMenu._navigationState(skinMod, skinGame)
local originalVascBucket = skinGame.save.options.modOptions.VOXEL_ASCENDANT
  [VascMenu.NAVIGATION_KEY]
local originalKascSlots = duplicateReordered.__vascKascMenuSkinBridge
  .navigation.slots
local originalVascBytes = graphFingerprint(originalVascNav)
local originalKascBytes = graphFingerprint(originalKascSlots)
local isolateCleanup, isolateReceipt =
  VascMenu._qaBeginNavigationIsolation(skinMod, skinGame)
assert(type(isolateCleanup) == "function",
  "QA navigation isolation did not return a cleanup")
eq(isolateReceipt.schema, "voxel-ascendant/qa-navigation-isolation/v1",
  "QA navigation isolation receipt schema")
local isolatedHub = skinRegistered.VascMenu.new(skinGame)
assert(isolatedHub.__vascNavigation.nav ~= originalVascNav,
  "QA VASC menu reused the player's process navigation graph")
isolatedHub.index, isolatedHub.scroll = 2, 0
isolatedHub:__vascRememberNavigation()
local isolatedDuplicate = reopenForeign(skinGame, "KASC DUPLICATES",
  duplicateItems, 1, 0)
local isolatedKascSlots = isolatedDuplicate.__vascKascMenuSkinBridge
  .navigation.slots
assert(isolatedKascSlots ~= originalKascSlots,
  "QA KASC menu reused the player's process navigation graph")
isolatedDuplicate.index, isolatedDuplicate.scroll = 2, 0
isolatedDuplicate:__vascRememberNavigation()
eq(graphFingerprint(originalVascNav), originalVascBytes,
  "isolated VASC navigation changed original bytes")
eq(graphFingerprint(originalKascSlots), originalKascBytes,
  "isolated KASC navigation changed original bytes")
assert(isolateCleanup(), "normal QA navigation cleanup failed")
eq(VascMenu._navigationState(skinMod, skinGame), originalVascNav,
  "normal QA cleanup changed VASC navigation object identity")
eq(skinGame.save.options.modOptions.VOXEL_ASCENDANT
    [VascMenu.NAVIGATION_KEY], originalVascBucket,
  "normal QA cleanup changed the options navigation object")
eq(graphFingerprint(originalVascNav), originalVascBytes,
  "normal QA cleanup changed VASC navigation bytes")
eq(graphFingerprint(originalKascSlots), originalKascBytes,
  "normal QA cleanup changed KASC navigation bytes")
local restoredDuplicate = reopenForeign(skinGame, "KASC DUPLICATES",
  reorderedDuplicates, 1, 0)
eq(restoredDuplicate.__vascKascMenuSkinBridge.navigation.slots,
  originalKascSlots,
  "normal QA cleanup changed KASC navigation object identity")

local exceptionCleanup = assert(
  VascMenu._qaBeginNavigationIsolation(skinMod, skinGame))
local exceptionOk = xpcall(function()
  local exceptionHub = skinRegistered.VascMenu.new(skinGame)
  exceptionHub.index, exceptionHub.scroll = 3, 1
  exceptionHub:__vascRememberNavigation()
  local exceptionKasc = reopenForeign(skinGame, "KASC DUPLICATES",
    duplicateItems, 1, 0)
  exceptionKasc.index, exceptionKasc.scroll = 5, 1
  exceptionKasc:__vascRememberNavigation()
  error("forced QA scenario failure", 0)
end, tostring)
eq(exceptionOk, false, "QA exception fixture did not fail")
assert(exceptionCleanup(), "exception QA navigation cleanup failed")
eq(VascMenu._navigationState(skinMod, skinGame), originalVascNav,
  "exception QA cleanup changed VASC navigation object identity")
local exceptionRestoredKasc = reopenForeign(
  skinGame, "KASC DUPLICATES", reorderedDuplicates, 1, 0)
eq(exceptionRestoredKasc.__vascKascMenuSkinBridge.navigation.slots,
  originalKascSlots,
  "exception QA cleanup changed KASC navigation object identity")
eq(graphFingerprint(originalVascNav), originalVascBytes,
  "exception QA cleanup changed VASC navigation bytes")
eq(graphFingerprint(originalKascSlots), originalKascBytes,
  "exception QA cleanup changed KASC navigation bytes")

assert(publicMenuBridge.showHelp(
  skinGame, "VASC MENU", skinPage.items[1].help))
local orasHelp = skinStack[#skinStack]
eq(select(1, orasHelp:uiSize()), orasWidth,
  "VascHelp shares only the selected VASC fullscreen surface")
eq(select(2, orasHelp:uiSize()), orasHeight)
orasHelp:draw()
eq(isolation.push, 2, "fullscreen help also isolates its draw state")
eq(isolation.pop, 2, "fullscreen help restores its draw state")

for key, value in pairs(previousGraphics) do
  graphics[key] = value ~= false and value or nil
end

-- Navigation memory is stored below the VASC mod-options bucket. Cursor and
-- scroll changes are cheap in-memory updates; close/page transitions flush
-- once. Stable item keys survive inserted/removed conditional rows, and a
-- missing remembered row clamps to the nearest valid replacement.
local navArena, navDisk = false, false
local navMode = setting("battles", "3D-BTL", {"MAP", "ARENA", "DISCS"},
  function(value)
    navArena, navDisk = value == "ARENA", value == "DISCS"
  end)
navMode:setValue("ARENA")
local navSettings = {
  {navMode, "Battle mode."},
  {setting("arenaArt", "ARENA BG", {"V+FRLG", "VASC"}), "Arena art.",
    when=function() return navArena end},
  {setting("diskArt", "DISK ART", {"V+FRLG", "VASC"}), "Disk art.",
    when=function() return navDisk end},
  {setting("battleHudPosition", "HUD POS", {"AUTO", "WIDE"}), "HUD position."},
  {setting("battleGrid", "BTL GRID", {"OFF", "ON"}), "Battle grid."},
  {setting("trainerBack", "TRAINER BACK", {"OFF", "ON"}), "Trainer back."},
  {setting("battleBack", "PKMN BACK", {"OFF", "ON"}), "Pokemon back."},
  {setting("battleCameraDistance", "BTL DIST", {"3X", "2X"}), "Distance."},
}
local navMod, navRegistered, navPushes = fixture()
VascMenu.install(navMod, {settings=navSettings, resumeLastSection=true})
local navPressed, navTop
local navGame = {
  save={options={modOptions={}}},
  mods={modOptions={}},
  input={wasPressed=function(_, key) return navPressed == key end},
  stack={
    push=function(_, screen) navTop = screen end,
    pop=function() navTop = nil end,
    top=function() return navTop end,
  },
  writeOptions=function(self) self.writes = (self.writes or 0) + 1 end,
}
local navRoot = navRegistered.VascMenu.new(navGame)
navRoot:choose(3)
eq(navPushes[#navPushes].opts.section, "battle")
local storedNav = navGame.save.options.modOptions.VOXEL_ASCENDANT
  [VascMenu.NAVIGATION_KEY]
eq(storedNav.lastSection, "battle", "last entered root section is saved")
eq(storedNav.pages.vasc_root.itemKey, "section:battle",
  "root selection is saved by stable section key")
assert(navGame.writes == 1, "root page transition did not flush exactly once")
eq(navGame.mods.modOptions.VOXEL_ASCENDANT[VascMenu.NAVIGATION_KEY], storedNav,
  "live loader and save do not diverge on navigation memory")

local navBattle = navRegistered.VascSettings.new(navGame, {section="battle"})
local hudIndex
for index, item in ipairs(navBattle.items) do
  if item.settingKey == "battleHudPosition" then hudIndex = index break end
end
assert(hudIndex and hudIndex > 1)
navBattle.index, navBattle.scroll = hudIndex, 1
local beforeFrameWrites = navGame.writes
navBattle:update(.016)
navBattle:update(.016)
eq(navGame.writes, beforeFrameWrites,
  "cursor tracking caused a per-frame options write")
navBattle:close()
eq(navGame.writes, beforeFrameWrites + 1,
  "leaving a dirty settings page does not flush exactly once")

navMode:setValue("MAP")
local restoredBattle = navRegistered.VascSettings.new(navGame, {section="battle"})
eq(restoredBattle.items[restoredBattle.index].settingKey, "battleHudPosition",
  "stable item key did not survive removal of the preceding ARENA row")
assert(restoredBattle.scroll >= 0
    and restoredBattle.scroll <= math.max(0, #restoredBattle.items - restoredBattle.rows),
  "restored scroll exceeds the rebuilt page")

navMode:setValue("ARENA")
local missingBattle = navRegistered.VascSettings.new(navGame, {section="battle"})
local arenaIndex
for index, item in ipairs(missingBattle.items) do
  if item.settingKey == "arenaArt" then arenaIndex = index break end
end
assert(arenaIndex)
missingBattle.index, missingBattle.scroll = arenaIndex, 0
missingBattle:close()
navMode:setValue("MAP")
local clampedBattle = navRegistered.VascSettings.new(navGame, {section="battle"})
assert(clampedBattle.index >= 1 and clampedBattle.index <= #clampedBattle.items,
  "missing conditional-row memory left an invalid cursor")
assert(clampedBattle.scroll >= 0
    and clampedBattle.scroll <= math.max(0, #clampedBattle.items - clampedBattle.rows),
  "missing conditional-row memory left an invalid scroll")

local resumeRoot = navRegistered.VascMenu.new(navGame)
navTop = resumeRoot
local pushesBeforeResume = #navPushes
resumeRoot:update(.016)
eq(#navPushes, pushesBeforeResume + 1,
  "fresh VASC opening did not resume the last entered section")
eq(navPushes[#navPushes].screen, "VascSettings")
eq(navPushes[#navPushes].opts.section, "battle")

-- Gen1 must expose the same model selection/import entry point as Gen2,
-- passing the selected game to the existing importer without claiming that
-- a host which rejects file picking successfully imported anything.
for _, publicUi in ipairs({false, {}}) do
  local modelMod, modelScreens = fixture(publicUi or nil)
  local selectedModel = setting("pokemonModelSkin", "POKéMON MODEL",
    {"AUTO", "CRYSTAL", "STADIUM 1", "STADIUM 2"})
  local owner, status, permitted = nil, "CHOOSE", true
  VascMenu.install(modelMod, {
    settings={{selectedModel, "Choose the local model provider."}},
    stadiumRomMenu={
      value=function(activeGame)
        eq(activeGame,game,"asynchronous picker poll lost active game")
        return status
      end,
      choose=function(activeGame)
        owner=activeGame
        status=permitted and "BUILDING" or "NO MOBILE PICKER"
        return permitted
      end,
    },
  })
  local page=modelScreens.VascSettings.new(game, {section="pokemon"})
  local modelIndex, importIndex
  for i,item in ipairs(page.items) do
    if item.settingKey=="pokemonModelSkin" then modelIndex=i end
    if item.action=="stadiumRom" then importIndex=i end
  end
  assert(modelIndex and importIndex, "Gen1 Pokemon segment omits models/import")
  page:choose(modelIndex)
  eq(selectedModel:get(), "CRYSTAL", "model selection is not connected")
  assert(page:choose(importIndex))
  eq(owner,game,"ROM picker lost selected game ownership")
  eq(page.items[importIndex].right,"BUILDING")
  permitted=false
  eq(page:choose(importIndex),false,"rejected host picker reported success")
  eq(page.items[importIndex].right,"NO MOBILE PICKER")
  status="READY"
  page:update(.016)
  eq(page.items[importIndex].right,"READY","mobile return did not refresh importer")
end

print("ok complete standalone/KASC VASC control centre and START help")
