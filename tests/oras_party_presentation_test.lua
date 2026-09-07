-- Real 0.5.3 Party/Overlay/Summary presentation adapters: behavior remains
-- native while spatial input and drawing are changed per concrete instance.

local engineRoot = arg and arg[1] or os.getenv("GEN1RECOMP_ROOT")
if engineRoot and engineRoot ~= "" then
  package.path = engineRoot .. "/?.lua;" .. engineRoot .. "/?/init.lua;"
    .. package.path
  local testRoot = os.getenv("GEN1RECOMP_TEST_ROOT")
    or os.getenv("GEN1RECOMP_0190_DATA_ROOT") or engineRoot
  if rawget(_G, "love") == nil then
    _G.love = assert(loadfile(testRoot .. "/tests/love_stub.lua"))()
  end
end

local function eq(actual, expected, message)
  assert(actual == expected, (message or "values differ")
    .. (" (expected %s, got %s)"):format(tostring(expected), tostring(actual)))
end

local mod = {
  id="VOXEL_ASCENDANT",
  options={get=function() return nil end},
  find=function() return nil end,
}
local V = {mod=mod}
local cached = {}
local bundledFrontCalls = 0
local ModSetting = {}
function ModSetting.new(_, _, _, _, default)
  return { get=function() return default end }
end
function V.require(name)
  if cached[name] then return cached[name] end
  if name == "ModSetting" then return ModSetting end
  if name == "Gen2CrystalFronts" then
    cached[name] = {
      resolve=function(_, mon, opts)
        bundledFrontCalls = bundledFrontCalls + 1
        if mon and mon.species == "BUNDLED_MON" then
          assert(opts and opts.kind == "summary")
          return {path="assets/crystal_fronts/normal/3.png",
            trueColor=true, source="vasc_crystal_front"}
        end
      end,
    }
    return cached[name]
  end
  if name == "BattleHudExtras" then
    cached[name] = assert(loadfile("lib/BattleHudExtras.lua"))(V)
    return cached[name]
  end
  local path = ({
    OrasPartyPresentation="lib/OrasPartyPresentation.lua",
    OrasPartyOverlayPresentation="lib/OrasPartyOverlayPresentation.lua",
    OrasPartySummaryPresentation="lib/OrasPartySummaryPresentation.lua",
  })[name]
  assert(path, "unexpected module " .. tostring(name))
  cached[name] = assert(loadfile(path))(V)
  return cached[name]
end

local Party = V.require("OrasPartyPresentation")
local Overlay = V.require("OrasPartyOverlayPresentation")
local Summary = V.require("OrasPartySummaryPresentation")

-- Gen 1 must now use the same bundled menu-front resolver as Gen 2 before it
-- considers KASC or the engine sprite seam.  This is the visual-parity fix
-- for the visibly blockier Gen-1 Team/Status cards.
do
  local path, trueColor, source = Party.resolveSpritePath({data={pokemon={}}},
    {species="BUNDLED_MON"}, "summary")
  eq(path, "assets/crystal_fronts/normal/3.png",
    "Gen1 Team skipped the bundled Crystal front")
  eq(trueColor, true, "bundled Crystal front lost true-colour ownership")
  eq(source, "vasc_crystal_front",
    "Gen1 Team reported the wrong sprite owner")
  eq(bundledFrontCalls, 1,
    "Gen1 Team did not consult the shared front resolver exactly once")
end

eq(Party.WIDTH, 512)
eq(Party.HEIGHT, 288)
eq(Party.partyGridMove(1, "right", 6), 2)
eq(Party.partyGridMove(2, "left", 6), 1)
eq(Party.partyGridMove(5, "down", 5), 1)
eq(Party.partyGridMove(4, "down", 5), 2)
eq(Party.partyGridMove(1, "up", 5), 5)
eq(Party.partyGridMove(1, "left", 1), 1)
assert(type(Party.drawTypeGlyphForQa) == "function",
  "Gen1 Team detail lost the per-type symbol renderer")

-- The portrait badge must contain the actual type pictogram, not merely a
-- translated TYP/TYPE label. WATER is intentionally a filled droplet. A dual
-- type keeps two Crystal-sized cards instead of splitting one box into tiny
-- 11/14px buttons, and both language contracts retain explicit type names.
do
  local graphics = love.graphics
  local oldPolygon, oldRectangle, oldEllipse, oldCircle =
    graphics.polygon, graphics.rectangle, graphics.ellipse, graphics.circle
  local polygons, rectangles, circles = 0, {}, 0
  graphics.polygon = function(mode, ...)
    if mode == "fill" then polygons = polygons + 1 end
    if oldPolygon then return oldPolygon(mode, ...) end
  end
  graphics.rectangle = function(mode, x, y, w, h, ...)
    if mode == "fill" then
      rectangles[#rectangles + 1] = {x=x, y=y, w=w, h=h}
    end
    if oldRectangle then return oldRectangle(mode, x, y, w, h, ...) end
  end
  graphics.ellipse = function(mode, ...)
    if oldEllipse then return oldEllipse(mode, ...) end
  end
  graphics.circle = function(mode, ...)
    if mode == "fill" or mode == "line" then circles = circles + 1 end
    if oldCircle then return oldCircle(mode, ...) end
  end
  local function hasFill(x, y, w, h)
    for _, row in ipairs(rectangles) do
      if row.x == x and row.y == y and row.w == w and row.h == h then
        return true
      end
    end
    return false
  end
  Party.drawTypeBadgeForQa({data={pokemon={
    SQUIRTLE={types={"WATER"}},
    CELEBI={types={"PSYCHIC_TYPE", "GRASS"}},
  }}}, {species="SQUIRTLE"}, 0, 0, 30)
  assert(polygons >= 1, "WATER type badge did not paint its droplet glyph")
  assert(hasFill(0, 0, 30, 30),
    "single type badge did not retain the full 30px icon card")

  rectangles = {}
  Party.drawTypeBadgeForQa({data={pokemon={
    CELEBI={types={"PSYCHIC_TYPE", "GRASS"}},
  }}}, {species="CELEBI"}, 0, 0, 30)
  assert(hasFill(0, 3, 24, 24) and hasFill(26, 3, 24, 24),
    "dual-type cards are not two aligned Crystal-sized 24px icons")
  assert(not hasFill(0, 8, 14, 14),
    "dual-type badge regressed to split mini-buttons")

  rectangles, circles = {}, 0
  Party.drawTypeBadgeForQa({data={pokemon={}}},
    {species="MISSINGMON"}, 0, 0, 30)
  assert(hasFill(0, 0, 30, 30) and circles >= 2,
    "missing type asset did not retain the NORMAL fallback pictogram")

  eq(Party.typeNameForQa("GRASS", "de"), "PFLANZE",
    "German type pill lost its explicit localization")
  eq(Party.typeNameForQa("GRASS", "en"), "GRASS",
    "English type pill was translated unexpectedly")
  eq(Party.typeNameForQa("PSYCHIC_TYPE", "de"), "PSYCHO",
    "German Psychic alias was not localized")
  eq(Party.typeNameForQa("STEEL", "de"), "STAHL",
    "German forward-compatible Steel type name is missing")
  local gen1TypeNames = {
    NORMAL={"NORMAL", "NORMAL"}, FIGHTING={"KAMPF", "FIGHTING"},
    FLYING={"FLUG", "FLYING"}, POISON={"GIFT", "POISON"},
    GROUND={"BODEN", "GROUND"}, ROCK={"GESTEIN", "ROCK"},
    BUG={"KÄFER", "BUG"}, GHOST={"GEIST", "GHOST"},
    FIRE={"FEUER", "FIRE"}, WATER={"WASSER", "WATER"},
    GRASS={"PFLANZE", "GRASS"}, ELECTRIC={"ELEKTRO", "ELECTRIC"},
    PSYCHIC_TYPE={"PSYCHO", "PSYCHIC"}, ICE={"EIS", "ICE"},
    DRAGON={"DRACHE", "DRAGON"},
  }
  for kind, expected in pairs(gen1TypeNames) do
    eq(Party.typeNameForQa(kind, "de"), expected[1],
      "German Gen-I type name mismatch: " .. kind)
    eq(Party.typeNameForQa(kind, "en"), expected[2],
      "English Gen-I type name mismatch: " .. kind)
  end
  graphics.polygon, graphics.rectangle, graphics.ellipse, graphics.circle =
    oldPolygon, oldRectangle, oldEllipse, oldCircle
end

local function colorKey(value)
  return table.concat({
    ("%.6f"):format(value[1]), ("%.6f"):format(value[2]),
    ("%.6f"):format(value[3]),
  }, ":")
end
local canonicalTypes = {
  "NORMAL", "FIGHTING", "FLYING", "POISON", "GROUND", "ROCK", "BUG",
  "GHOST", "STEEL", "FIRE", "WATER", "GRASS", "ELECTRIC",
  "PSYCHIC_TYPE", "ICE", "DRAGON", "DARK",
}
local seenTypeColors = {}
for _, kind in ipairs(canonicalTypes) do
  local key = colorKey(Party.typeAccentFor(kind))
  assert(not seenTypeColors[key],
    ("type accent collision: %s and %s"):format(seenTypeColors[key], kind))
  seenTypeColors[key] = kind
end
assert(colorKey(Party.typeAccentFor("POISON"))
  ~= colorKey(Party.typeAccentFor("PSYCHIC_TYPE")),
  "Poison and Psychic still share the ORAS Team/Box accent")
eq(colorKey(Party.typeAccentFor("PSYCHIC")),
  colorKey(Party.typeAccentFor("PSYCHIC_TYPE")),
  "Gen-II Psychic alias does not use the canonical accent")

local genderGame = { data={ pokemon={
  BULBASAUR={dex=1}, PIKACHU={dex=25}, MEWTWO={dex=150},
} } }
eq(Party.genderSymbol(genderGame,
  {species="BULBASAUR", dvs={attack=0}}), "♀",
  "native Party detail did not derive female gender from DVs")
eq(Party.genderSymbol(genderGame,
  {species="PIKACHU", dvs={attack=15}}), "♂",
  "native Party detail did not derive male gender from DVs")
eq(Party.genderSymbol(genderGame,
  {species="MEWTWO", dvs={attack=0}}), "-",
  "native Party detail did not retain the genderless fallback")
eq(Party.partyCardGender(genderGame,
  {species="BULBASAUR", dvs={attack=0}}, "BULBASAUR"), "♀",
  "native Gen-I Team card did not derive female gender from DVs")
eq(Party.partyCardGender(genderGame,
  {species="PIKACHU", dvs={attack=15}}, "PIKACHU"), "♂",
  "native Gen-I Team card did not derive male gender from DVs")
eq(Party.partyCardGender(genderGame,
  {species="MEWTWO", dvs={attack=0}}, "MEWTWO"), nil,
  "genderless Team card rendered a fabricated marker")
eq(Party.partyCardGender(genderGame,
  {species="BULBASAUR", egg=true, gender="FEMALE"}, "EGG"), nil,
  "Egg Team card leaked a gender marker")
eq(Party.partyCardGender(genderGame,
  {species="NIDORAN_F", gender="FEMALE"}, "NIDORAN♀"), nil,
  "Nidoran Team card duplicated the gender encoded in its name")
eq(Party.partyCardGender(genderGame,
  {species="NIDORAN_M", gender="MALE", nickname="SPIKE"}, "SPIKE"), "♂",
  "nicknamed Nidoran lost the useful Team-card gender marker")

-- KASC eggs retain their future species internally. The party skin must not
-- reveal either species Ability data or a held-item field before hatching.
local privateEgg = {
  egg=true, species="FUTUREMON", ability="SECRET_ABILITY",
  heldItem="SECRET_ITEM",
}
local privateGame = {
  data={pokemon={FUTUREMON={ability="SPECIES_SECRET"}}},
}
eq(Party.abilityName(privateGame, privateEgg), "---",
  "egg ability leaked future species data")
eq(Party.itemName(privateGame, privateEgg), "---",
  "egg held item leaked private data")

local pressed = {}
local input = {}
function input:wasPressed(button) return pressed[button] == true end
local originalWasPressed = input.wasPressed
local nativeCalls = 0
local callbackCalls = 0
local nativeDraw = function() return "native draw" end
local nativeUpdate = function(self)
  nativeCalls = nativeCalls + 1
  if self.game.input:wasPressed("a") then callbackCalls = callbackCalls + 1 end
  return nil, "native update", 23
end
local game = {
  input=input,
  save={party={{species=1}, {species=4}, {species=7}}},
  stack={states={}},
}
local menu = {
  game=game, screenId="PartyMenu", index=1,
  update=nativeUpdate, draw=nativeDraw,
}
local nativeMeta = {__index={sentinel=true}}
setmetatable(menu, nativeMeta)
Party.decoratePartyMenu(menu, {context="start", language="de"})
eq(menu.__vascOrasPartyDecorated, true)
eq(menu.__vascOrasStartParty, true)
eq(menu.language, "de")
eq(menu.view, "party")
eq(menu.drawsWidescreen(), true)
assert(type(menu.drawWidescreen) == "function",
  "ORAS PartyMenu has no physical widescreen presenter")
eq(select(1, menu.uiSize()), 512)
eq(select(2, menu.uiSize()), 288)
eq(getmetatable(menu), nativeMeta, "Start PartyMenu metatable changed")
assert(menu.draw ~= nativeDraw, "ASC BOX did not replace presentation draw")
assert(menu.update ~= nativeUpdate, "ASC BOX did not add spatial adapter")

-- Game2 calls drawWidescreen directly in physical coordinates. Exercise the
-- concrete instance seam without initializing a graphics window and require
-- the fixed 512x288 presentation to be fitted exactly once.
do
  local oldLove, oldDraw = love, Party.draw
  local pushes, pops, translations, scales, logicalDraws = 0, 0, {}, {}, 0
  love = { graphics={
    push=function() pushes = pushes + 1 end,
    pop=function() pops = pops + 1 end,
    origin=function() end,
    setColor=function() end,
    rectangle=function() end,
    translate=function(x, y) translations[#translations + 1] = {x, y} end,
    scale=function(x, y) scales[#scales + 1] = {x, y or x} end,
  } }
  Party.draw = function(owner)
    eq(owner, menu, "physical Party presenter changed its owner")
    logicalDraws = logicalDraws + 1
  end
  menu:drawWidescreen(2560, 1440)
  eq(pushes, 1, "physical Party presenter push count")
  eq(pops, 1, "physical Party presenter pop count")
  eq(logicalDraws, 1, "physical Party presenter logical draw count")
  eq(translations[1][1], 0, "physical Party presenter x origin")
  eq(translations[1][2], 0, "physical Party presenter y origin")
  eq(scales[1][1], 5, "physical Party presenter scale")
  Party.draw, love = oldDraw, oldLove
end

pressed.a = true
local first, second, third = menu:update()
eq(first, nil)
eq(second, "native update")
eq(third, 23)
eq(nativeCalls, 1)
eq(callbackCalls, 1, "native A behavior did not run")
eq(input.wasPressed, originalWasPressed, "input method changed without movement")

pressed.a = false
pressed.right = true
menu.index = 1
first, second, third = menu:update()
eq(menu.index, 2, "two-column spatial movement did not select right card")
eq(nativeCalls, 2, "native update did not run after spatial movement")
eq(callbackCalls, 1, "movement leaked a simultaneous A action")
eq(input.wasPressed, originalWasPressed,
  "temporary input mask was not restored")
eq(second, "native update")
eq(third, 23)

-- Even an error from an external/native update cannot leave the shared input
-- method masked for subsequent screens.
local failingInput = {}
function failingInput:wasPressed(button) return button == "down" end
local failingWasPressed = failingInput.wasPressed
local failing = {
  game={input=failingInput, save={party={{}, {}}}},
  index=1,
  draw=nativeDraw,
  update=function() error("native update failure") end,
}
Party.decoratePartyMenu(failing, {context="start"})
local ok, err = pcall(failing.update, failing)
eq(ok, false)
assert(tostring(err):find("native update failure", 1, true))
eq(failingInput.wasPressed, failingWasPressed,
  "failed native update leaked the spatial input mask")

-- Real engine battle pickers keep all authoritative behavior after the
-- 0.5.3 presentation is applied. Forced B is the Host-v1 no-op, forced A
-- selects exactly once, voluntary A still opens SWITCH/STATS/CANCEL, and a
-- voluntary B still closes through the exact native onCancel callback.
local EnginePartyMenu = require("src.ui.PartyMenu")
local function engineBattleFixture(forceSwitch)
  local down = {}
  local engineInput = {}
  function engineInput:wasPressed(button) return down[button] == true end
  local engineStack = { states={} }
  function engineStack:push(state) self.states[#self.states + 1] = state end
  function engineStack:pop() return table.remove(self.states) end
  function engineStack:top() return self.states[#self.states] end
  local engineMon = {
    species="PIKACHU", nickname="PIKA", level=20, hp=40,
    stats={hp=40, attack=20, defense=18, speed=30, special=25},
    moves={}, dvs={}, statExp={},
  }
  local selected, selectedCount, cancelCount
  local engineGame = {
    input=engineInput, stack=engineStack,
    save={party={engineMon}},
    data={pokemon={PIKACHU={name="PIKACHU", types={"ELECTRIC"}}},
      text={}},
  }
  local battleOwner = { player={mon=engineMon} }
  local picker = EnginePartyMenu.new(engineGame, {
    battle=battleOwner, forceSwitch=forceSwitch,
    onSwitch=function(mon)
      selected, selectedCount = mon, (selectedCount or 0) + 1
    end,
    onCancel=function() cancelCount = (cancelCount or 0) + 1 end,
  })
  Party.decoratePartyMenu(picker, {
    context="battle", battle=battleOwner, language="en",
  })
  engineStack:push(picker)
  return {
    menu=picker, mon=engineMon, stack=engineStack, pressed=down,
    selected=function() return selected, selectedCount or 0 end,
    cancelled=function() return cancelCount or 0 end,
  }
end

local forced = engineBattleFixture(true)
eq(Party.isActive({context="battle", battle={player=forced.mon}}, forced.mon),
  true, "Gen2 direct active battler was not recognized")
eq(Party.isActive({context="battle", battle={player={mon=forced.mon}}},
  forced.mon), true, "Gen1 wrapped active battler was not recognized")
forced.pressed.b = true
forced.menu:update(0)
eq(forced.stack:top(), forced.menu, "forced B closed the battle picker")
eq(forced.cancelled(), 0, "forced B fired native onCancel")
forced.pressed.b = false
forced.pressed.a = true
forced.menu:update(0)
local selectedMon, selectedCount = forced.selected()
eq(selectedMon, forced.mon, "forced A selected the wrong live Pokemon")
eq(selectedCount, 1, "forced A callback did not fire exactly once")
eq(forced.stack:top(), nil, "forced A did not close before callback")

local voluntary = engineBattleFixture(false)
voluntary.pressed.a = true
voluntary.menu:update(0)
eq(voluntary.menu.submenu, true,
  "voluntary A bypassed native SWITCH/STATS/CANCEL")
eq(select(2, voluntary.selected()), 0,
  "voluntary first A fired switch before submenu confirmation")
voluntary.pressed.a = false
voluntary.pressed.a = true
voluntary.menu.subIndex = 1
voluntary.menu:update(0)
selectedMon, selectedCount = voluntary.selected()
eq(selectedMon, voluntary.mon, "voluntary SWITCH selected wrong Pokemon")
eq(selectedCount, 1, "voluntary SWITCH callback did not fire exactly once")
eq(voluntary.stack:top(), nil,
  "voluntary SWITCH did not preserve native close-before-callback order")

local cancelled = engineBattleFixture(false)
cancelled.pressed.b = true
cancelled.menu:update(0)
eq(cancelled.stack:top(), nil, "voluntary B did not close native picker")
eq(cancelled.cancelled(), 1, "voluntary B callback did not fire exactly once")

-- SHIFT uses the same forceSwitch flag as mandatory faint replacement.
-- Its active Pokemon is still alive and the defeated trainer foe remains
-- current until this optional picker closes; B must reach native update.
for _, alternativesFainted in ipairs({false, true}) do
  local shift = engineBattleFixture(true)
  local owner = shift.menu.battle
  owner.kind = "trainer"
  owner.enemy = {mon={hp=0}, fainted=true}
  shift.menu.game.save.party[2] = {hp=alternativesFainted and 0 or 20}
  shift.pressed.b = true
  shift.menu:update(0)
  eq(shift.stack:top(), nil, "SHIFT B was swallowed")
  eq(shift.cancelled(), 1, "SHIFT B did not reach native cancellation")
  eq(select(2, shift.selected()), 0, "SHIFT B selected a Pokemon")
end
local doubleFaint = engineBattleFixture(true)
doubleFaint.menu.battle.kind = "trainer"
doubleFaint.menu.battle.enemy = {mon={hp=0}, fainted=true}
doubleFaint.menu.battle.player.fainted = true
doubleFaint.mon.hp = 0
doubleFaint.pressed.b = true
doubleFaint.menu:update(0)
eq(doubleFaint.stack:top(), doubleFaint.menu, "own faint lost mandatory selection")
eq(doubleFaint.cancelled(), 0, "own faint cancellation fired")

-- Summary captures and delegates the existing native/KASC update. Directional
-- page cycling only acts after that owner left page and stack unchanged.
local summaryPressed = {}
local summaryInput = {}
function summaryInput:wasPressed(button) return summaryPressed[button] == true end
local summaryNativeCalls = 0
local summaryGame = {
  input=summaryInput,
  stack={states={}},
}
local summary = {
  game=summaryGame,
  mon={species=1, hp=10, level=5},
  page=1,
  draw=nativeDraw,
  update=function()
    summaryNativeCalls = summaryNativeCalls + 1
    return "summary native"
  end,
}
summaryGame.stack.states[1] = summary
Summary.decorateSummaryMenu(summary, {language="en"})
eq(summary.__vascOrasSummaryDecorated, true)
assert(summary.draw ~= nativeDraw, "Summary presentation did not install")
eq(summary:update(), "summary native")
eq(summaryNativeCalls, 1, "native Summary update did not run")
summaryPressed.right = true
eq(summary:update(), "summary native")
eq(summaryNativeCalls, 2)
eq(summary.page, 2, "ORAS Summary directional page did not advance")

-- Modal decorators replace drawing/geometry only. Typewriter, choice index,
-- callbacks and update remain the native instances' responsibility.
eq(Overlay.isOrasBase({__vascOrasBagPresentation=true}), true,
  "wide ORAS Bag was not accepted as modal underlay")
eq(Overlay.isOrasBase({__vascOrasFrlgBagPresentation=true}), true,
  "wide FRLG Bag was not accepted as modal underlay")
eq(Overlay.isOrasBase({__vascMoveLearnPresentation=true}), true,
  "MoveLearn owner was not accepted as modal underlay")
assert(not Overlay.isOrasBase({}),
  "unowned screen was accepted as ORAS modal underlay")
local modalUpdate = function() return "modal native" end
local text = {update=modalUpdate, draw=nativeDraw, shown={}, game=game}
Overlay.decorateTextBox(text, {wideBattle=false})
eq(text.__vascOrasWideTextBox, true)
eq(text.update, modalUpdate)
eq(text:update(), "modal native")
assert(text.draw ~= nativeDraw)
eq(select(1, text.uiSize()), 512)
eq(select(2, text.uiSize()), 288)

local onChoice = function() return "chosen" end
local choice = {
  update=modalUpdate, draw=nativeDraw, onChoose=onChoice, index=1, game=game,
}
Overlay.decorateChoiceBox(choice, {wideBattle=false})
eq(choice.__vascOrasWideChoiceBox, true)
eq(choice.update, modalUpdate)
eq(choice.onChoose, onChoice)
eq(choice.onChoose(), "chosen")
assert(choice.draw ~= nativeDraw)

-- The Bag's complete 512x288 surface owns its three native transient
-- controls as well.  Presentation changes must not replace their update or
-- completion callbacks, and all three drawings must be valid in the actual
-- engine graphics stub.
local bagBase = {__vascOrasBagSkin=true}
eq(Overlay.isWideBagBase(bagBase), true,
  "wide Bag marker was not recognized")
assert(not Overlay.isWideBagBase({}),
  "unowned screen was accepted as a wide Bag")
local oldBagPolygon = love.graphics.polygon
love.graphics.polygon = oldBagPolygon or function() end

local bagActionCallback = function() return "bag-action" end
local bagAction = {
  items={{label="BENUTZEN", onSelect=bagActionCallback},
    {label="WEGWERFEN"}},
  index=1, update=modalUpdate, draw=nativeDraw,
}
Overlay.decorateBagActionMenu(bagAction)
eq(bagAction.__vascOrasWideBagAction, true)
eq(bagAction.update, modalUpdate, "Bag action update owner changed")
eq(bagAction.items[1].onSelect, bagActionCallback,
  "Bag action callback owner changed")
eq(select(1, bagAction.uiSize()), 512)
local bagDrawOK, bagDrawError = pcall(bagAction.draw, bagAction)
assert(bagDrawOK, "wide Bag action renderer failed: "
  .. tostring(bagDrawError))

local quantityDone = function(value) return value end
local bagQuantity = {
  qty=3, max=12, onDone=quantityDone,
  update=modalUpdate, draw=nativeDraw,
}
Overlay.decorateBagQuantity(bagQuantity)
eq(bagQuantity.__vascOrasWideBagQuantity, true)
eq(bagQuantity.update, modalUpdate, "Bag quantity update owner changed")
eq(bagQuantity.onDone, quantityDone, "Bag quantity callback owner changed")
bagDrawOK, bagDrawError = pcall(bagQuantity.draw, bagQuantity)
assert(bagDrawOK, "wide Bag quantity renderer failed: "
  .. tostring(bagDrawError))

local bagChoiceDone = function(value) return value end
local bagChoice = {
  labels={"YES", "NO"}, index=2, onChoose=bagChoiceDone,
  update=modalUpdate, draw=nativeDraw,
}
Overlay.decorateBagChoice(bagChoice)
eq(bagChoice.__vascOrasWideBagChoice, true)
eq(bagChoice.update, modalUpdate, "Bag choice update owner changed")
eq(bagChoice.onChoose, bagChoiceDone, "Bag choice callback owner changed")
bagDrawOK, bagDrawError = pcall(bagChoice.draw, bagChoice)
assert(bagDrawOK, "wide Bag choice renderer failed: "
  .. tostring(bagDrawError))
love.graphics.polygon = oldBagPolygon

print("ok real ORAS Party/Summary/Overlay presentation preserves native behavior")
