VASC_TRANSITION_QA_TEST = true
local QA = assert(loadfile("tests/manual_transition_qa.lua"))()
VASC_TRANSITION_QA_TEST = nil

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected "
          .. tostring(expected) .. ", got " .. tostring(actual), 0)
  end
end

local function contains(value, needle, message)
  if not tostring(value):find(needle, 1, true) then
    error((message or "text missing") .. ": " .. tostring(needle), 0)
  end
end

-- Pin the state/input receipts used by the legacy bootstrap against the exact
-- public 0.1.90 tree selected by test_contract. The fallback mirrors that
-- selector for the standalone Lua test; a current ../gen1recomp tree is never
-- silently accepted as the frozen compatibility fixture.
local function readFile(path)
  local handle = io.open(path, "rb")
  if not handle then return nil end
  local payload = handle:read("*a")
  handle:close()
  return payload
end

local frozenCandidates = {}
local function addFrozenCandidate(candidate)
  if candidate and candidate ~= "" then
    frozenCandidates[#frozenCandidates + 1] = candidate
  end
end
addFrozenCandidate(arg and arg[1] or nil)
addFrozenCandidate(os.getenv("GEN1RECOMP_0190_ROOT"))
addFrozenCandidate(
  "../qa/gen1recomp-0.1.90-clientfix-rc-20260815-2c645aef/build-A/stage")
addFrozenCandidate("../gen1recomp")
local frozenRoot
for _, candidate in ipairs(frozenCandidates) do
  local gameSource = candidate and readFile(candidate .. "/src/core/Game.lua")
  if gameSource
     and gameSource:find("function Game:load()", 1, true)
     and gameSource:find("onContinue = function()", 1, true)
     and not gameSource:find("playtestAutoContinueRequested", 1, true) then
    frozenRoot = candidate
    break
  end
end
if not frozenRoot then
  error("exact frozen Gen1Recomp 0.1.90 bootstrap fixture unavailable", 0)
end

local frozenMain = assert(readFile(frozenRoot .. "/main.lua"))
local frozenGame = assert(readFile(frozenRoot .. "/src/core/Game.lua"))
local frozenIntro = assert(readFile(frozenRoot .. "/src/ui/IntroMovie.lua"))
local frozenYellow = assert(readFile(frozenRoot .. "/src/ui/YellowIntro.lua"))
local frozenTitle = assert(readFile(frozenRoot .. "/src/ui/TitleState.lua"))
local frozenMenu = assert(readFile(frozenRoot .. "/src/ui/Menu.lua"))
local frozenInput = assert(readFile(frozenRoot .. "/src/core/Input.lua"))
local frozenQuarantine =
  assert(readFile(frozenRoot .. "/src/ui/QuarantineReport.lua"))
local transitionReveal = assert(readFile("lib/TransitionReveal.lua"))
local transitionDriver = assert(readFile("tests/manual_transition_qa.lua"))
contains(frozenMain, "Game:load()", "frozen boot no longer loads Game")
contains(frozenMain, "local driverPath = os.getenv(\"POKEPORT_DRIVER\")",
  "frozen driver environment hook missing")
if assert(frozenMain:find("Game:load()", 1, true))
   >= assert(frozenMain:find("local driverPath = os.getenv", 1, true)) then
  error("frozen POKEPORT_DRIVER no longer starts after Game:load", 0)
end
contains(frozenGame, "Screens.push(self, bootScreens(self).splash or splash",
  "frozen boot no longer enters its authentic intro")
contains(frozenGame, "self:restoreSave(loaded, recovered, { freshBoot = true })",
  "frozen title CONTINUE no longer uses restoreSave")
contains(frozenIntro, "input:wasPressed(\"a\") or input:wasPressed(\"start\")",
  "frozen IntroMovie skip contract drifted")
contains(frozenYellow, "or input:wasPressed(\"start\") then",
  "frozen YellowIntro skip contract drifted")
contains(frozenTitle, "table.insert(items, { label = Strings(\"CONTINUE\")",
  "frozen localized CONTINUE row drifted")
contains(frozenTitle, "game.stack:push(ContinueInfo.new(self, loaded))",
  "frozen CONTINUE info step drifted")
contains(frozenTitle, "if self.title.onContinue then self.title.onContinue() end",
  "frozen ContinueInfo confirmation drifted")
contains(frozenMenu, "if item.onSelect then item.onSelect() end",
  "frozen menu selection contract drifted")
contains(frozenInput, "function Input:sourcePress(btn, source)",
  "frozen public programmatic input hook missing")
contains(frozenInput, "function Input:sourceRelease(btn, source)",
  "frozen public programmatic input release hook missing")
contains(frozenQuarantine, "QuarantineReport.isOpaque = true",
  "frozen quarantine screen identity drifted")
contains(frozenQuarantine, "elseif input:wasPressed(\"a\") or input:wasPressed(\"start\")",
  "frozen quarantine acknowledgement input drifted")
contains(frozenQuarantine, "self.game.stack:pop()",
  "frozen quarantine acknowledgement no longer reveals Overworld")
contains(transitionReveal, "state.wrapper = function(self, ...)",
  "0.1.90 reveal compatibility wrapper source drifted")
contains(transitionReveal, "Transition.update = state.wrapper",
  "0.1.90 reveal wrapper no longer owns the real Transition update")
local doneAt = assert(transitionDriver:find(
  'print("VASC_QA_TRANSITION_DONE")', 1, true),
  "transition driver lost its terminal evidence marker")
local flushAt = assert(transitionDriver:find(
  "pcall(io.stdout.flush, io.stdout)", doneAt, true),
  "transition driver no longer flushes redirected evidence after DONE")
local yieldAt = assert(transitionDriver:find(
  "while true do coroutine.yield() end", flushAt, true),
  "transition driver no longer remains alive after flushing DONE")
if not (doneAt < flushAt and flushAt < yieldAt) then
  error("transition evidence flush ordering drifted", 0)
end

local function env(values)
  return function(name) return values[name] end
end

local function makeBootstrapGame(initialKind, options)
  options = options or {}
  local events, normalContinueCalls = {}, 0
  local overworld = { kind = "overworld", map = nil }
  local title = { kind = "title", phase = options.titlePhase or "drop" }
  local continueLabel = options.continueLabel or "CONTINUE"
  local menu = {
    kind = "menu", index = options.menuIndex or 1,
    items = options.items or {
      { label = continueLabel }, { label = "NEW GAME" },
    },
  }
  local info = { kind = "continue_info", title = title, save = { active = true } }
  local quarantine = {
    kind = "quarantine_report", screenId = "QuarantineReport",
    report = { remappedMaps = { { id = "OLD", to = "PALLET_TOWN" } } },
    lines = { "Location reset:" }, offset = 0,
  }
  function quarantine:maxOffset() return 0 end
  local states = {
    intro = { kind = "intro" }, yellow = { kind = "intro" },
    title = title, menu = menu, continue_info = info, overworld = overworld,
    quarantine_report = quarantine, unknown = { kind = "unknown" },
  }
  local top = assert(states[initialKind])
  local stack = { states = { top } }
  function stack:top() return top end
  local input = { queue = {} }
  function input:sourcePress(button, source)
    self.queue[#self.queue + 1] = button
    events[#events + 1] = "press:" .. button .. ":" .. source
  end
  function input:sourceRelease(button, source)
    events[#events + 1] = "release:" .. button .. ":" .. source
  end
  local game = { stack = stack, overworld = overworld, input = input }
  if options.current then
    game.playtestAutoContinueRequested = function() return true end
  end
  local titleWait = options.titleWait or 2
  local function setTop(nextTop)
    top = nextTop
    stack.states = { nextTop }
  end
  local function update()
    local button = table.remove(input.queue, 1)
    if top.kind == "intro" then
      if button == "start" then setTop(title) end
    elseif top.kind == "title" then
      if top.phase ~= "loop" then
        titleWait = titleWait - 1
        if titleWait <= 0 then top.phase = "loop" end
      elseif button == "start" then
        setTop(menu)
      end
    elseif top.kind == "menu" then
      if button == "down" then
        top.index = top.index < #top.items and top.index + 1 or 1
      elseif button == "up" then
        top.index = top.index > 1 and top.index - 1 or #top.items
      elseif button == "a" then
        local item = top.items[top.index]
        if item and item.label == continueLabel then setTop(info) end
      end
    elseif top.kind == "continue_info" and button == "a" then
      normalContinueCalls = normalContinueCalls + 1
      overworld.map = { id = "ACTIVE_SAVE_MAP" }
      if options.quarantineAfterContinue then
        top = quarantine
        stack.states = { overworld, quarantine }
      else
        setTop(overworld)
      end
    elseif top.kind == "quarantine_report" and button == "a"
       and not options.quarantineStuck then
      setTop(overworld)
    end
  end
  return game, update, events, function() return normalContinueCalls end, setTop
end

local function fixtureClassifier(state)
  return state and state.kind or "unknown"
end

-- Runtime classification requires both the real module source and the exact
-- Screens/instance shape; neither a forged screenId nor a source-only table
-- is sufficient to unlock the acknowledgement path.
do
  local reportUpdate = assert(loadstring(
    "return function() end", "@src/ui/QuarantineReport.lua"))()
  local Report = {
    update = reportUpdate,
    maxOffset = function() return 0 end,
  }
  Report.__index = Report
  local report = setmetatable({
    screenId = "QuarantineReport", report = {}, lines = {}, offset = 0,
  }, Report)
  eq(QA.qaBootStateKind(report), "quarantine_report",
    "exact quarantine source/shape was not classified")
  report.screenId = nil
  eq(QA.qaBootStateKind(report), "unknown",
    "quarantine source without Screens identity was accepted")
  local forged = setmetatable({
    screenId = "QuarantineReport", report = {}, lines = {}, offset = 0,
  }, { __index = {
    update = function() end, maxOffset = function() return 0 end,
  } })
  eq(QA.qaBootStateKind(forged), "unknown",
    "forged quarantine structure without module source was accepted")
end

-- Kanto Ascendant 6.7 wraps only TitleState.update in its Crystal-v1.5
-- presentation module.  The bootstrap accepts that exact source only when
-- every interactive TitleState receipt needed by the real CONTINUE path is
-- present; either a source lookalike or a partial structure stays closed.
do
  local wrappedUpdate = assert(loadstring(
    "return function() end",
    "@mods/kanto_ascendant/crystal_v15_features.lua"))()
  local WrappedTitle = {
    update = wrappedUpdate, isOpaque = true,
    openMenu = function() end, currentSprite = function() end,
  }
  WrappedTitle.__index = WrappedTitle
  local title = setmetatable({
    screenId = "TitleState", game = {}, onContinue = function() end,
    phase = "loop",
    cycleSpecies = { "PIKACHU" },
  }, WrappedTitle)
  eq(QA.qaBootStateKind(title), "title",
    "exact Kanto-wrapped TitleState source/shape was not classified")
  title.onContinue = nil
  eq(QA.qaBootStateKind(title), "unknown",
    "wrapped title without an active CONTINUE callback was accepted")
  title.onContinue = function() end
  title.screenId = nil
  eq(QA.qaBootStateKind(title), "unknown",
    "wrapped title without the registered screen identity was accepted")
  title.screenId = "TitleState"
  WrappedTitle.update = function() end
  eq(QA.qaBootStateKind(title), "unknown",
    "wrapped-title shape without the exact Kanto source was accepted")
end

local function driveBootstrap(game, update, values, options)
  options = options or {}
  options.classify = fixtureClassifier
  options.continueLabel = options.continueLabel or "CONTINUE"
  options.emit = options.emit or function() end
  local bootstrap = QA.newQAContinueBootstrap(game, env(values), options)
  for _ = 1, (options.maxFrames or 1800) + 1 do
    if bootstrap:step() then return bootstrap end
    update()
  end
  error("bootstrap fixture escaped its own deadline", 0)
end

-- A non-empty exact restore report is a legitimate one-screen continuation
-- of the legacy CONTINUE chain. It is accepted only over the already restored
-- Overworld, receives one authentic A tap, and remains explicit in the proof.
do
  local game, update, events, continueCalls = makeBootstrapGame("intro", {
    quarantineAfterContinue = true,
  })
  local bootstrap = driveBootstrap(game, update, {
    POKEPORT_DRIVER = "tests/manual_transition_qa.lua",
  })
  eq(continueCalls(), 1, "quarantine path bypassed normal CONTINUE")
  eq(bootstrap.inputEdges, 5,
    "quarantine path did not add exactly one acknowledgement edge")
  eq(#events, 10, "quarantine acknowledgement was not one paired tap")
  eq(table.concat(bootstrap.path, ">"),
    "intro_requested>title>title_requested>menu>menu_confirmed>"
    .. "continue_confirmed>quarantine_acknowledged>overworld",
    "quarantine acknowledgement disappeared from the boot proof")
end

do
  local game, update = makeBootstrapGame("intro", {
    quarantineAfterContinue = true,
  })
  local bootstrap = QA.newQAContinueBootstrap(game, env({
    POKEPORT_DRIVER = "driver",
  }), { classify = fixtureClassifier, emit = function() end })
  while bootstrap.stage ~= "continue_confirmed" do
    bootstrap:step()
    update()
  end
  game.stack.states = { game.stack:top() }
  local accepted, failure = pcall(bootstrap.step, bootstrap)
  eq(accepted, false, "quarantine without Overworld ancestry was accepted")
  contains(failure, "VASC_QA_BOOTSTRAP_QUARANTINE_STACK",
    "quarantine ancestry failure lost stable code")
end

-- Exact old-engine shape: movie -> non-interactive title sequence -> title
-- menu -> ContinueInfo -> the normal onContinue restore. The harness mutates
-- Overworld only inside that final simulated callback, so an early/direct-map
-- implementation cannot make this certificate pass.
for _, introKind in ipairs({ "intro", "yellow" }) do
  local game, update, events, continueCalls = makeBootstrapGame(introKind)
  local bootstrap = driveBootstrap(game, update, {
    POKEPORT_DRIVER = "tests/manual_transition_qa.lua",
  })
  eq(bootstrap.done, true, introKind .. " bootstrap did not finish")
  eq(continueCalls(), 1,
    introKind .. " bootstrap bypassed or duplicated normal CONTINUE")
  eq(game.overworld.map.id, "ACTIVE_SAVE_MAP",
    introKind .. " bootstrap did not restore the active save map")
  eq(bootstrap.inputEdges, 4,
    introKind .. " bootstrap input path changed")
  eq(table.concat(bootstrap.path, ">"),
    "intro_requested>title>title_requested>menu>menu_confirmed>"
    .. "continue_confirmed>overworld",
    introKind .. " bootstrap state proof changed")
  eq(#events, bootstrap.inputEdges * 2,
    introKind .. " tap did not pair every source press/release")
end

-- A localized/hooked menu is navigated through real direction input; the
-- helper neither assumes index one nor writes Menu.index directly.
do
  local label = "WEITERSPIELEN"
  local game, update, _, continueCalls = makeBootstrapGame("title", {
    titlePhase = "loop", continueLabel = label, menuIndex = 1,
    items = { { label = "NEWS" }, { label = label }, { label = "NEW GAME" } },
  })
  local bootstrap = driveBootstrap(game, update, {
    POKEPORT_DRIVER = "tests/manual_transition_qa.lua",
  }, { continueLabel = label })
  eq(continueCalls(), 1, "localized CONTINUE did not use normal callback")
  eq(bootstrap.inputEdges, 4,
    "localized non-first CONTINUE did not add exactly one direction edge")
end

-- Current engines keep their built-in, double-opt-in auto-continue entirely
-- untouched: an already restored Overworld is accepted with zero QA input.
do
  local game, update, events = makeBootstrapGame("overworld", { current = true })
  game.overworld.map = { id = "ACTIVE_SAVE_MAP" }
  local bootstrap = driveBootstrap(game, update, {
    POKEPORT_DRIVER = "tests/manual_transition_qa.lua",
    POKEPORT_PLAYTEST = "1", POKEPORT_PLAYTEST_AUTO_CONTINUE = "1",
  })
  eq(bootstrap.mode, "current_auto_continue", "current mode not detected")
  eq(bootstrap.inputEdges, 0, "current auto-continue received legacy input")
  eq(#events, 0, "current auto-continue touched the input API")
end

for _, values in ipairs({
  { POKEPORT_DRIVER = "driver" },
  { POKEPORT_DRIVER = "driver", POKEPORT_PLAYTEST = "1" },
  { POKEPORT_DRIVER = "driver", POKEPORT_PLAYTEST_AUTO_CONTINUE = "1" },
}) do
  local game = select(1, makeBootstrapGame("title", { current = true }))
  local accepted, failure = pcall(QA.newQAContinueBootstrap,
    game, env(values), { classify = fixtureClassifier })
  eq(accepted, false, "current default/partial flags enabled legacy autodrive")
  contains(failure, "VASC_QA_BOOTSTRAP_CURRENT_FLAGS_REQUIRED",
    "current flag failure lost stable code")
end

do
  local game = select(1, makeBootstrapGame("title", { current = true }))
  local bootstrap = QA.newQAContinueBootstrap(game, env({
    POKEPORT_DRIVER = "driver", POKEPORT_PLAYTEST = "1",
    POKEPORT_PLAYTEST_AUTO_CONTINUE = "1",
  }), { classify = fixtureClassifier, emit = function() end })
  local accepted, failure = pcall(bootstrap.step, bootstrap)
  eq(accepted, false, "current no-save title was accepted as auto-continue")
  contains(failure, "VASC_QA_BOOTSTRAP_CURRENT_AUTO_CONTINUE_FAILED",
    "current no-save failure lost stable code")
end

do
  local game, _, events = makeBootstrapGame("quarantine_report", {
    current = true,
  })
  game.overworld.map = { id = "ACTIVE_SAVE_MAP" }
  game.stack.states = { game.overworld, game.stack:top() }
  local bootstrap = QA.newQAContinueBootstrap(game, env({
    POKEPORT_DRIVER = "driver", POKEPORT_PLAYTEST = "1",
    POKEPORT_PLAYTEST_AUTO_CONTINUE = "1",
  }), { classify = fixtureClassifier, emit = function() end })
  local accepted, failure = pcall(bootstrap.step, bootstrap)
  eq(accepted, false, "current engine accepted legacy quarantine autodrive")
  contains(failure, "VASC_QA_BOOTSTRAP_CURRENT_AUTO_CONTINUE_FAILED",
    "current quarantine failure lost stable code")
  eq(#events, 0, "current quarantine received a QA input edge")
end

do
  local game = select(1, makeBootstrapGame("intro"))
  local accepted, failure = pcall(QA.newQAContinueBootstrap,
    game, env({}), { classify = fixtureClassifier })
  eq(accepted, false, "bootstrap ran without POKEPORT_DRIVER")
  contains(failure, "VASC_QA_BOOTSTRAP_DRIVER_REQUIRED",
    "missing-driver failure lost stable code")
end

do
  local game, update = makeBootstrapGame("overworld")
  game.overworld.map = { id = "BYPASS" }
  local bootstrap = QA.newQAContinueBootstrap(game, env({
    POKEPORT_DRIVER = "driver",
  }), { classify = fixtureClassifier, emit = function() end })
  local accepted, failure = pcall(bootstrap.step, bootstrap)
  eq(accepted, false, "legacy direct Overworld bypass was certified")
  contains(failure, "VASC_QA_BOOTSTRAP_LEGACY_CONTINUE_BYPASSED",
    "legacy bypass failure lost stable code")
end

do
  local game = select(1, makeBootstrapGame("unknown"))
  local bootstrap = QA.newQAContinueBootstrap(game, env({
    POKEPORT_DRIVER = "driver",
  }), { classify = fixtureClassifier, emit = function() end })
  local accepted, failure = pcall(bootstrap.step, bootstrap)
  eq(accepted, false, "unknown legacy boot state was accepted")
  contains(failure, "VASC_QA_BOOTSTRAP_UNEXPECTED_STATE",
    "unknown-state failure lost stable code")
end

do
  local game = select(1, makeBootstrapGame("quarantine_report"))
  game.overworld.map = { id = "ACTIVE_SAVE_MAP" }
  game.stack.states = { game.overworld, game.stack:top() }
  local bootstrap = QA.newQAContinueBootstrap(game, env({
    POKEPORT_DRIVER = "driver",
  }), { classify = fixtureClassifier, emit = function() end })
  local accepted, failure = pcall(bootstrap.step, bootstrap)
  eq(accepted, false, "pre-confirmation quarantine was acknowledged")
  contains(failure, "VASC_QA_BOOTSTRAP_UNEXPECTED_STATE",
    "pre-confirmation quarantine failure lost stable code")
end

do
  local game, update = makeBootstrapGame("intro", {
    quarantineAfterContinue = true, quarantineStuck = true,
  })
  local accepted, failure = pcall(driveBootstrap, game, update, {
    POKEPORT_DRIVER = "driver",
  })
  eq(accepted, false, "repeated quarantine report was acknowledged twice")
  contains(failure, "VASC_QA_BOOTSTRAP_UNEXPECTED_STATE",
    "repeated quarantine failure lost stable code")
end

do
  local game, update = makeBootstrapGame("title", {
    titlePhase = "loop", items = { { label = "NEW GAME" } },
  })
  local bootstrap = QA.newQAContinueBootstrap(game, env({
    POKEPORT_DRIVER = "driver",
  }), { classify = fixtureClassifier, emit = function() end })
  bootstrap:step(); update()
  local accepted, failure = pcall(bootstrap.step, bootstrap)
  eq(accepted, false, "menu without active CONTINUE was accepted")
  contains(failure, "VASC_QA_BOOTSTRAP_CONTINUE_MISSING",
    "missing-save failure lost stable code")
end

do
  local game, update = makeBootstrapGame("title", {
    titlePhase = "loop",
    items = { { label = "CONTINUE" }, { label = "CONTINUE" } },
  })
  local bootstrap = QA.newQAContinueBootstrap(game, env({
    POKEPORT_DRIVER = "driver",
  }), { classify = fixtureClassifier, emit = function() end })
  bootstrap:step(); update()
  local accepted, failure = pcall(bootstrap.step, bootstrap)
  eq(accepted, false, "duplicate CONTINUE rows were accepted")
  contains(failure, "VASC_QA_BOOTSTRAP_AMBIGUOUS_CONTINUE",
    "duplicate-CONTINUE failure lost stable code")
end

do
  local game = select(1, makeBootstrapGame("intro"))
  game.input = {}
  local bootstrap = QA.newQAContinueBootstrap(game, env({
    POKEPORT_DRIVER = "driver",
  }), { classify = fixtureClassifier, emit = function() end })
  local accepted, failure = pcall(bootstrap.step, bootstrap)
  eq(accepted, false, "legacy bootstrap used a private input fallback")
  contains(failure, "VASC_QA_BOOTSTRAP_INPUT_API_REQUIRED",
    "missing-input failure lost stable code")
end

do
  local game, update = makeBootstrapGame("title", { titleWait = 999 })
  local accepted, failure = pcall(driveBootstrap, game, update, {
    POKEPORT_DRIVER = "driver",
  }, { maxFrames = 3 })
  eq(accepted, false, "non-interactive title escaped the hard deadline")
  contains(failure, "VASC_QA_BOOTSTRAP_TIMEOUT",
    "bootstrap timeout lost stable code")
end

local ow = {
  player = { moving = false },
  engaging = false,
  emote = nil,
}
local top = ow
local stack = { states = { ow } }
function stack:top() return top end
local game = { stack = stack }

local originalSight = function() return "original-sight" end
local originalInput = function() return "original-input" end
ow.checkTrainerSight = originalSight
ow.handleInput = originalInput

local guard = QA.newSyntheticFrameGuard(game, ow, "GUARD")
guard:install(13, 1)
if ow.checkTrainerSight == originalSight or ow.handleInput == originalInput then
  error("synthetic frame did not install its instance-only guards", 0)
end
eq(ow.checkTrainerSight(), false,
   "synthetic trainer-sight guard did not reject acquisition")
eq(ow.handleInput(), nil,
   "synthetic input guard did not quiesce native input")
eq(guard:restore(), true, "first synthetic-frame restore was rejected")
eq(ow.checkTrainerSight, originalSight,
   "trainer-sight instance value was not restored exactly")
eq(ow.handleInput, originalInput,
   "input instance value was not restored exactly")
eq(guard:restore(), false, "synthetic-frame restore was not idempotent")
eq(ow.checkTrainerSight, originalSight,
   "idempotent restore changed trainer-sight ownership")

-- Exact Kanto 6.7 uses bundled internal Wilds 1.12.2. Keep its full LOS
-- calculation in the synthetic frame, but discard the result that arose from
-- the probe's directly assigned player coordinate. The provider function and
-- every entity state value must remain byte-for-byte owned by Wilds.
local wildSightCalls, wildSightArgs = 0, nil
local function originalWildSight(...)
  wildSightCalls = wildSightCalls + 1
  wildSightArgs = { ... }
  return true
end
local wildBehavior = {
  AGGRESSIVE = "AGGRESSIVE",
  playerInSight = originalWildSight,
}
local wildNil = { behavior = "IDLE_LOOK", surface = "GRASS",
  behaviorState = { state = "IDLE", behavior = "IDLE_LOOK" } }
local wildFalse = { behaviorState = {
  state = "IDLE", behavior = "AGGRESSIVE", sightDisabled = false,
}, behavior = "AGGRESSIVE", surface = "GRASS" }
local wildTrue = { behaviorState = {
  state = "IDLE", behavior = "IDLE_LOOK", sightDisabled = true,
}, behavior = "IDLE_LOOK", surface = "GRASS" }
local activeWildEntities = {
  nil_value = wildNil, false_value = wildFalse, true_value = wildTrue,
}
local wildLogic = { entities = activeWildEntities,
  state = { initialized = true, mapId = "ROUTE_8",
    mapSupported = true, pipelineVerified = true,
    fallbackToVanilla = false, unsupportedReason = nil, lastError = nil },
  activeMapId = "ROUTE_8" }
local wildBehaviorTick = { logic = wildLogic }
local wildBehaviorRequires = 0
local function validKantoWilds()
  return {
    internalWilds = {
      bundled = true, source = "bundled", version = "1.12.2",
      exports = {
        version = "1.12.2", bundledBy = "kanto_ascendant",
        logic = wildLogic, behaviorTick = wildBehaviorTick,
        lib = { require = function(name)
          wildBehaviorRequires = wildBehaviorRequires + 1
          eq(name, "behavior", "synthetic guard requested another Wilds lib")
          return wildBehavior
        end },
      },
    },
  }
end
ow.map = { id = "ROUTE_8" }
ow.entities = { wildNil, wildFalse, wildTrue }
game.mods = { exports = { kanto_ascendant = validKantoWilds() } }
local wildGuard = QA.newSyntheticFrameGuard(game, ow, "GUARD")
wildGuard:install(13, 2)
if wildBehavior.playerInSight == originalWildSight then
  error("synthetic Wilds sight wrapper was not installed", 0)
end
eq(wildBehavior.playerInSight(
     wildFalse, ow.player, ow.map, ow.entities, 4, {}), false,
   "synthetic Wilds sight result was not suppressed")
eq(wildSightCalls, 1, "real Wilds LOS calculation was not executed")
eq(wildSightArgs[1], wildFalse, "real Wilds LOS lost its entity argument")
eq(wildSightArgs[2], ow.player, "real Wilds LOS lost its player argument")
eq(wildSightArgs[3], ow.map, "real Wilds LOS lost its map argument")
eq(wildGuard.wildSightSuppressed, 1,
   "auditable Wilds suppression count did not advance")
eq(rawget(wildNil.behaviorState, "sightDisabled"), nil,
   "nil Wilds sight state changed during the synthetic frame")
eq(wildFalse.behaviorState.sightDisabled, false,
   "false Wilds sight state changed during the synthetic frame")
eq(wildTrue.behaviorState.sightDisabled, true,
   "true Wilds sight state changed during the synthetic frame")
eq(wildGuard:restore(), true, "Wilds synthetic-frame restore was rejected")
eq(wildBehavior.playerInSight, originalWildSight,
   "Wilds LOS provider was not restored exactly")
eq(rawget(wildNil.behaviorState, "sightDisabled"), nil,
   "nil Wilds sight state changed after restore")
eq(wildFalse.behaviorState.sightDisabled, false,
   "false Wilds sight state changed after restore")
eq(wildTrue.behaviorState.sightDisabled, true,
   "true Wilds sight state changed after restore")

-- Saffron and Lavender have no encounter surface in the frozen Kanto data.
-- Wilds owns an explicit unsupported/fallback receipt there and its tick
-- returns before LOS. Exercise both B/D starting rotations and prove QA adds
-- no Behavior lookup or override in that exact inactive state.
local function exerciseInactiveWilds(mapId)
  local priorRequires = wildBehaviorRequires
  ow.map = { id = mapId }
  wildLogic.activeMapId = mapId
  wildLogic.entities = {}
  wildLogic.pendingBattle = nil
  wildLogic.state = {
    initialized = false,
    mapId = mapId,
    mapSupported = false,
    fallbackToVanilla = true,
    phase = "idle",
    unsupportedReason = "no supported encounter surface",
    encounterDataAvailable = false,
    pipelineVerified = false,
    vanillaSuppressed = false,
    encounterSource = "none",
    assetError = nil,
    lastError = nil,
  }
  local inactiveGuard = QA.newSyntheticFrameGuard(game, ow, "GUARD")
  inactiveGuard:install(13, 2)
  eq(wildBehavior.playerInSight, originalWildSight,
     "inactive Wilds map installed an unnecessary LOS wrapper")
  eq(wildBehaviorRequires, priorRequires,
     "inactive Wilds map loaded Behavior despite its early-return receipt")
  eq(inactiveGuard.wildSightSuppressed, 0,
     "inactive Wilds map reported a fabricated suppression")
  eq(inactiveGuard:restore(), true,
     "inactive Wilds synthetic-frame restore was rejected")
end

exerciseInactiveWilds("SAFFRON_CITY")
exerciseInactiveWilds("LAVENDER_TOWN")

-- Only the two exact no-encounter cities and their real Surface receipt are
-- accepted; another map or a hand-written reason cannot impersonate it.
wildLogic.state.unsupportedReason = "No encounter data available"
local inactiveOk, inactiveMessage = pcall(
  QA.newSyntheticFrameGuard, game, ow, "GUARD")
eq(inactiveOk, false, "synthetic guard accepted a fabricated idle reason")
contains(inactiveMessage, "invalid active/inactive live-map receipt",
  "wrong inactive reason lost its stable contract failure")
ow.map = { id = "CELADON_CITY" }
wildLogic.activeMapId = "CELADON_CITY"
wildLogic.state.mapId = "CELADON_CITY"
wildLogic.state.unsupportedReason = "no supported encounter surface"
inactiveOk, inactiveMessage = pcall(
  QA.newSyntheticFrameGuard, game, ow, "GUARD")
eq(inactiveOk, false, "synthetic guard accepted another unsupported city")
contains(inactiveMessage, "invalid active/inactive live-map receipt",
  "foreign inactive map lost its stable contract failure")
ow.map = { id = "LAVENDER_TOWN" }
wildLogic.activeMapId = "LAVENDER_TOWN"
wildLogic.state.mapId = "LAVENDER_TOWN"

-- An inactive receipt with entities is not an unsupported idle state; reject
-- it before changing either Overworld instance method.
wildLogic.entities = { unexpected = wildNil }
inactiveOk, inactiveMessage = pcall(
  QA.newSyntheticFrameGuard, game, ow, "GUARD")
eq(inactiveOk, false, "synthetic guard accepted active entities on idle Wilds")
contains(inactiveMessage, "invalid active/inactive live-map receipt",
  "malformed inactive Wilds failure lost its stable receipt")
eq(ow.checkTrainerSight, originalSight,
   "malformed inactive Wilds receipt changed trainer-sight ownership")

-- Rotate back to the active Route-8 receipt used by every remaining fixture.
ow.map = { id = "ROUTE_8" }
wildLogic.activeMapId = "ROUTE_8"
wildLogic.entities = activeWildEntities
wildLogic.state = {
  initialized = true, mapId = "ROUTE_8",
  mapSupported = true, pipelineVerified = true,
  fallbackToVanilla = false, unsupportedReason = nil, lastError = nil,
}
local rotatedActiveGuard = QA.newSyntheticFrameGuard(game, ow, "GUARD")
rotatedActiveGuard:install(13, 2)
if wildBehavior.playerInSight == originalWildSight then
  error("active Wilds rotation did not reinstall its LOS wrapper", 0)
end
eq(rotatedActiveGuard:restore(), true,
   "active Wilds rotation did not restore its LOS provider")

local function rejectUnexpectedWildSight(entity, behaviorName, message)
  local priorBehavior = entity.behaviorState.behavior
  entity.behaviorState.behavior = behaviorName
  local unexpectedGuard = QA.newSyntheticFrameGuard(game, ow, "GUARD")
  unexpectedGuard:install(13, 2)
  local accepted, failure = pcall(wildBehavior.playerInSight,
    entity, ow.player, ow.map, ow.entities, 4, {})
  eq(accepted, false, message)
  contains(failure, "VASC_QA_GUARD_WILDS_SIGHT_UNEXPECTED_TRUE",
    "unexpected Wilds sight result lost its stable code")
  eq(unexpectedGuard:restore(), true,
    "unexpected Wilds sight failure stranded the guard")
  eq(wildBehavior.playerInSight, originalWildSight,
    "unexpected Wilds sight failure stranded LOS ownership")
  entity.behaviorState.behavior = priorBehavior
end

rejectUnexpectedWildSight(wildNil, "WATER_AGGRESSIVE",
  "synthetic guard accepted water-aggressive sight")
rejectUnexpectedWildSight(wildNil, "SAFARI_FLEE",
  "synthetic guard accepted Safari sight")
local foreignWild = {
  behaviorState = { state = "IDLE", behavior = "AGGRESSIVE" },
}
rejectUnexpectedWildSight(foreignWild, "AGGRESSIVE",
  "synthetic guard accepted foreign-actor sight")

-- The string AGGRESSIVE alone is insufficient: only the exact Route-8 land
-- entity state may have a positive synthetic-coordinate result discarded.
local function rejectMalformedLandActor(mutator, restore, message)
  mutator()
  local malformedGuard = QA.newSyntheticFrameGuard(game, ow, "GUARD")
  malformedGuard:install(13, 2)
  local accepted, failure = pcall(wildBehavior.playerInSight,
    wildFalse, ow.player, ow.map, ow.entities, 4, {})
  eq(accepted, false, message)
  contains(failure, "VASC_QA_GUARD_WILDS_SIGHT_UNEXPECTED_TRUE",
    "malformed land actor lost its stable failure")
  eq(malformedGuard:restore(), true,
    "malformed land actor stranded the synthetic guard")
  restore()
end

rejectMalformedLandActor(
  function() wildFalse.surface = "WATER" end,
  function() wildFalse.surface = "GRASS" end,
  "synthetic guard accepted water surface with AGGRESSIVE state")
rejectMalformedLandActor(
  function() wildFalse.behaviorState.behavior = nil end,
  function() wildFalse.behaviorState.behavior = "AGGRESSIVE" end,
  "synthetic guard fell back from missing behaviorState.behavior")
rejectMalformedLandActor(
  function() wildFalse.behavior = "IDLE_LOOK" end,
  function() wildFalse.behavior = "AGGRESSIVE" end,
  "synthetic guard accepted mismatched entity/behaviorState behavior")

-- A present Kanto export may not silently fall back to an unknown or partial
-- Wilds provider. Failure happens at construction, before Overworld methods
-- or entity state can be changed.
game.mods.exports.kanto_ascendant = {
  internalWilds = {
    bundled = false, source = "external", version = "1.12.2",
    exports = { version = "1.12.2", bundledBy = "external_wilds",
      logic = wildLogic, behaviorTick = wildBehaviorTick,
      lib = { require = function() return wildBehavior end } },
  },
}
local malformedOk, malformedMessage = pcall(
  QA.newSyntheticFrameGuard, game, ow, "GUARD")
eq(malformedOk, false, "synthetic guard accepted malformed Kanto Wilds")
contains(malformedMessage, "VASC_QA_SYNTHETIC_WILDS_CONTRACT",
  "malformed Wilds failure lost its stable code")
eq(ow.checkTrainerSight, originalSight,
   "malformed Wilds contract changed trainer-sight ownership")
eq(wildBehavior.playerInSight, originalWildSight,
   "malformed Wilds contract changed LOS ownership")

-- A real alert/chase/battle already in flight is never erased by QA. It must
-- fail before any provider override, just like a pre-existing trainer emote.
game.mods.exports.kanto_ascendant = validKantoWilds()
wildFalse.behaviorState.state = "ALERT"
wildFalse.behaviorState.playerDetected = true
local busyGuard = QA.newSyntheticFrameGuard(game, ow, "GUARD")
local busyOk, busyMessage = pcall(busyGuard.install, busyGuard, 13, 3)
eq(busyOk, false, "synthetic guard accepted a pre-existing Wilds alert")
contains(busyMessage, "VASC_QA_GUARD_WILDS_BUSY",
  "Wilds busy failure lost its stable code")
eq(wildBehavior.playerInSight, originalWildSight,
   "Wilds busy failure changed LOS ownership")
eq(ow.checkTrainerSight, originalSight,
   "Wilds busy failure changed trainer-sight ownership")
wildFalse.behaviorState.state = "IDLE"
wildFalse.behaviorState.playerDetected = nil

wildFalse.behaviorState.state = "CLEANUP"
local cleanupGuard = QA.newSyntheticFrameGuard(game, ow, "GUARD")
local cleanupOk, cleanupMessage = pcall(
  cleanupGuard.install, cleanupGuard, 13, 3)
eq(cleanupOk, false, "synthetic guard accepted Wilds CLEANUP state")
contains(cleanupMessage, "VASC_QA_GUARD_WILDS_BUSY",
  "Wilds CLEANUP failure lost its stable code")
eq(wildBehavior.playerInSight, originalWildSight,
   "Wilds CLEANUP failure changed LOS ownership")
wildFalse.behaviorState.state = "IDLE"

wildFalse.state = "encounter_starting"
local entityBattleGuard = QA.newSyntheticFrameGuard(game, ow, "GUARD")
local entityBattleOk, entityBattleMessage = pcall(
  entityBattleGuard.install, entityBattleGuard, 13, 3)
eq(entityBattleOk, false,
   "synthetic guard accepted entity-level encounter start")
contains(entityBattleMessage, "entity_state=encounter_starting",
  "entity-level encounter failure lost its stable receipt")
wildFalse.state = nil

-- Provider replacement during the yielded frame is also a hard failure, but
-- cleanup restores both global Wilds and instance Overworld ownership first.
local driftGuard = QA.newSyntheticFrameGuard(game, ow, "GUARD")
driftGuard:install(13, 4)
local foreignWildSight = function() return true end
wildBehavior.playerInSight = foreignWildSight
local driftOk, driftMessage = pcall(driftGuard.restore, driftGuard)
eq(driftOk, false, "synthetic guard accepted Wilds provider drift")
contains(driftMessage, "VASC_QA_GUARD_WILDS_SIGHT_PROVIDER_DRIFT",
  "Wilds provider-drift failure lost its stable code")
eq(wildBehavior.playerInSight, foreignWildSight,
   "provider-drift cleanup clobbered the foreign LOS function")
eq(ow.checkTrainerSight, originalSight,
   "provider-drift cleanup stranded trainer-sight override")
wildBehavior.playerInSight = originalWildSight

-- A logic-level pending battle is rejected both before and after the yielded
-- frame; QA never clears or completes Wilds encounter ownership.
wildLogic.pendingBattle = { id = "pending" }
local pendingGuard = QA.newSyntheticFrameGuard(game, ow, "GUARD")
local pendingOk, pendingMessage = pcall(
  pendingGuard.install, pendingGuard, 13, 5)
eq(pendingOk, false, "synthetic guard accepted a pending Wilds battle")
contains(pendingMessage, "pending_battle=true",
  "pending Wilds battle failure lost its stable receipt")
eq(wildBehavior.playerInSight, originalWildSight,
   "pending battle failure changed LOS ownership")
wildLogic.pendingBattle = nil
local postPendingGuard = QA.newSyntheticFrameGuard(game, ow, "GUARD")
postPendingGuard:install(13, 6)
wildLogic.pendingBattle = { id = "post-pending" }
postPendingGuard:restore()
pendingOk, pendingMessage = pcall(QA.requireSyntheticWildIdle,
  wildLogic, "GUARD", "post-yield", 13, 6)
eq(pendingOk, false, "post-yield pending Wilds battle was accepted")
contains(pendingMessage, "phase=post-yield",
  "post-yield pending battle lost its phase receipt")
wildLogic.pendingBattle = nil

-- Post-yield entity battle and live-map receipt drift are both hard failures.
local postEntityGuard = QA.newSyntheticFrameGuard(game, ow, "GUARD")
postEntityGuard:install(13, 6)
wildFalse.state = "in_battle"
postEntityGuard:restore()
local postEntityOk, postEntityMessage = pcall(
  QA.requireSyntheticWildIdle, wildLogic, "GUARD", "post-yield", 13, 6,
  ow, "ACTIVE")
eq(postEntityOk, false,
   "post-yield entity-level Wilds battle was accepted")
contains(postEntityMessage, "entity_state=in_battle",
  "post-yield entity battle lost its stable receipt")
wildFalse.state = nil

local stateDriftGuard = QA.newSyntheticFrameGuard(game, ow, "GUARD")
stateDriftGuard:install(13, 6)
wildLogic.activeMapId = "SAFFRON_CITY"
stateDriftGuard:restore()
local stateDriftOk, stateDriftMessage = pcall(
  QA.requireSyntheticWildIdle, wildLogic, "GUARD", "post-yield", 13, 6,
  ow, "ACTIVE")
eq(stateDriftOk, false, "post-yield Wilds live-map drift was accepted")
contains(stateDriftMessage, "VASC_QA_GUARD_WILDS_STATE_DRIFT",
  "post-yield Wilds state drift lost its stable code")
wildLogic.activeMapId = "ROUTE_8"

-- A Wilds emote created despite the wrapper remains visible to the existing
-- post-yield WORLD_BUSY check; the guard never clears gameplay state.
local emoteGuard = QA.newSyntheticFrameGuard(game, ow, "GUARD")
emoteGuard:install(13, 7)
ow.emote = { npc = wildFalse, frames = 60 }
emoteGuard:restore()
local emoteOk, emoteMessage = pcall(QA.requireSyntheticIdle,
  game, ow, "GUARD", "post-yield", 13, 7)
eq(emoteOk, false, "post-yield Wilds emote was silently cleared")
contains(emoteMessage, "VASC_QA_GUARD_WORLD_BUSY",
  "post-yield Wilds emote failure lost its stable code")
eq(wildBehavior.playerInSight, originalWildSight,
   "post-yield emote stranded Wilds LOS override")
ow.emote = nil
game.mods = nil

-- Normal engine instances inherit both methods from their metatable. Nil raw
-- values must come back as nil, not as a copied bound method or permanent
-- no-op that leaks into the seam itself.
ow.checkTrainerSight, ow.handleInput = nil, nil
local inheritedGuard = QA.newSyntheticFrameGuard(game, ow, "GUARD")
inheritedGuard:install(14, 2)
eq(type(rawget(ow, "checkTrainerSight")), "function",
   "inherited trainer-sight method was not shadowed for the frame")
inheritedGuard:restore()
eq(rawget(ow, "checkTrainerSight"), nil,
   "inherited trainer-sight method did not restore to nil")
eq(rawget(ow, "handleInput"), nil,
   "inherited input method did not restore to nil")

-- A pre-existing overlay must fail before either raw method is changed. The
-- error includes a stable source/type hint, TextBox marker and stack depth.
local Box = { __index = nil }
Box.__index = Box
function Box:update() end
local box = setmetatable({ isTextBox = true }, Box)
top = box
stack.states = { ow, box }
local beforeSight, beforeInput = rawget(ow, "checkTrainerSight"),
  rawget(ow, "handleInput")
local coveredGuard = QA.newSyntheticFrameGuard(game, ow, "GUARD")
local ok, message = pcall(coveredGuard.install, coveredGuard, 15, 3)
eq(ok, false, "synthetic guard accepted a covered overworld")
message = tostring(message)
if not message:find("VASC_QA_GUARD_STACK_LOST", 1, true)
   or not message:find("is_textbox=true", 1, true)
   or not message:find("depth=2", 1, true)
   or not message:find(".lua", 1, true) then
  error("stack fail-fast diagnostic was incomplete: " .. message, 0)
end
eq(rawget(ow, "checkTrainerSight"), beforeSight,
   "pre-yield stack failure changed trainer-sight ownership")
eq(rawget(ow, "handleInput"), beforeInput,
   "pre-yield stack failure changed input ownership")

-- Model the actual coroutine order: restore immediately after resume, then
-- diagnose a TextBox pushed by the engine update. The error cannot strand
-- either temporary override on the Overworld instance.
top = ow
stack.states = { ow }
ow.checkTrainerSight, ow.handleInput = originalSight, originalInput
local postGuard = QA.newSyntheticFrameGuard(game, ow, "GUARD")
postGuard:install(16, 4)
top = box
stack.states = { ow, box }
postGuard:restore()
ok, message = pcall(QA.requireOverworldTop,
  game, ow, "GUARD", "post-yield", 16, 4)
eq(ok, false, "post-yield overlay did not fail fast")
eq(ow.checkTrainerSight, originalSight,
   "post-yield error stranded trainer-sight guard")
eq(ow.handleInput, originalInput,
   "post-yield error stranded input guard")

-- The scan may only start from a stationary, unengaged Overworld. This catches
-- the trainer's 60-frame emote phase before it has pushed its TextBox.
top = ow
stack.states = { ow }
ow.player.moving = true
ok, message = pcall(QA.requireSyntheticIdle,
  game, ow, "GUARD", "pre-approach", 17, 0)
eq(ok, false, "moving player was accepted for synthetic scan")
if not tostring(message):find("player_moving=true", 1, true) then
  error("moving-player failure lacked its diagnostic: " .. tostring(message), 0)
end
ow.player.moving = false
ow.engaging = true
ok, message = pcall(QA.requireSyntheticIdle,
  game, ow, "GUARD", "pre-cross", 17, 0)
eq(ok, false, "trainer engagement was accepted before crossConnection")
if not tostring(message):find("engaging=true", 1, true) then
  error("engagement failure lacked its diagnostic: " .. tostring(message), 0)
end

-- The Center loop is pinned to the real route doors, first interior landing,
-- and alternate half of each two-cell exit mat. The same records drive the
-- native sequence, so a generated-map drift cannot turn this into a direct
-- setMap test while the helper contract still passes.
local specs = QA.centerEntrySpecs()
eq(#specs, 2, "Center entry matrix lost a map")
eq(specs[1].sourceMap, "ROUTE_4", "Mt Moon Center source changed")
eq(specs[1].sourceX, 11, "Mt Moon Center door x changed")
eq(specs[1].sourceY, 5, "Mt Moon Center door y changed")
eq(specs[1].centerMap, "MT_MOON_POKECENTER",
   "Mt Moon Center destination changed")
eq(specs[1].entryX, 3, "Mt Moon Center landing x changed")
eq(specs[1].entryY, 7, "Mt Moon Center landing y changed")
eq(specs[1].exitX, 4, "Mt Moon Center reciprocal exit x changed")
eq(specs[1].exitY, 7, "Mt Moon Center reciprocal exit y changed")
eq(specs[2].sourceMap, "ROUTE_10", "Rock Tunnel Center source changed")
eq(specs[2].sourceX, 11, "Rock Tunnel Center door x changed")
eq(specs[2].sourceY, 19, "Rock Tunnel Center door y changed")
eq(specs[2].centerMap, "ROCK_TUNNEL_POKECENTER",
   "Rock Tunnel Center destination changed")
eq(specs[2].entryX, 3, "Rock Tunnel Center landing x changed")
eq(specs[2].exitX, 4, "Rock Tunnel Center reciprocal exit x changed")
specs[1].sourceMap = "MUTATED"
eq(QA.centerEntrySpecs()[1].sourceMap, "ROUTE_4",
   "Center entry specifications leaked mutable shared state")

local legs = QA.centerEntryLegs(QA.centerEntrySpecs()[1])
eq(#legs, 3, "Center cold/return/warm loop lost a leg")
eq(legs[1].temperature, "cold", "first Center entry is not cold")
eq(legs[1].warpDest, "MT_MOON_POKECENTER",
   "cold Center leg bypasses the real route warp")
eq(legs[2].temperature, "return", "middle Center leg is not the return")
eq(legs[2].fromMap, "MT_MOON_POKECENTER",
   "Center return starts on the wrong map")
eq(legs[2].x, 4, "Center return does not exercise the second exit mat")
eq(legs[2].warpDest, "LAST_MAP",
   "Center return bypasses LAST_MAP resolution")
eq(legs[3].temperature, "warm", "last Center entry is not warm")
eq(legs[3].toMap, "MT_MOON_POKECENTER",
   "warm Center leg targets the wrong map")

local function frame(values)
  local row = {
    frame = 1, temperature = "cold", expectedLevel = 7,
    pipelineId = "voxel", pipelineLevel = 7,
    top = "table:Transition.lua", stackCurrent = false,
    map = "ROUTE_4", cellX = 11, cellY = 5, ready = true,
    renderCalled = true, renderCanvas = true, renderMap = "ROUTE_4",
    pipelineCanvas = true, worldActive = true, worldOverride = true,
    fadeAlpha = 0.5, qaCover = false,
  }
  for key, value in pairs(values or {}) do row[key] = value end
  return row
end

eq(QA.transitionStackType("table:Transition.lua"), true,
   "engine Transition source was rejected")
eq(QA.transitionStackType("table:TransitionReveal.lua"), true,
   "exact 0.1.90 compat Transition wrapper source was rejected")
for _, lookalike in ipairs({
  "TransitionReveal.lua", "function:TransitionReveal.lua",
  "table:FakeTransitionReveal.lua", "table:TransitionReveal.lua.bak",
  "table:WrappedTransition.lua", "table:NotTransition.lua",
}) do
  eq(QA.transitionStackType(lookalike), false,
     "lookalike transition source was accepted: " .. lookalike)
end
eq(QA.transitionStackType(nil), false,
   "nil transition source was accepted")

local wrappedVisible = QA.classifyCenterEntryFrame(frame({
  top = "table:TransitionReveal.lua",
}))
eq(wrappedVisible.render3d, true,
   "compat-wrapped real Transition frame lost product 3D classification")
local wrappedCount = QA.summarizeCenterEntryFrames({ frame({
  top = "table:TransitionReveal.lua",
}) }, { fromMap = "ROUTE_4", toMap = "MT_MOON_POKECENTER",
       toX = 3, toY = 7 })
eq(wrappedCount.transition, 1,
   "compat-wrapped real Transition was omitted from frame audit counts")

local visible = QA.classifyCenterEntryFrame(frame())
eq(visible.render3d, true, "exact product 3D frame was rejected")
eq(visible.birdseye, false, "exact product 3D frame became bird's-eye")
eq(visible.black, false, "exact product 3D frame became black")

-- The only accepted black interval is Transition's own alpha=1 midpoint.
-- It may legitimately stay closed over a cold target for several frames while
-- its 3D scene becomes ready;
-- the same missing render one frame into fade-in is a visible bird's-eye
-- fallback and must fail.
local productBlackRow = frame({
  frame = 2, map = "MT_MOON_POKECENTER", cellX = 3, cellY = 7,
  ready = false, renderCalled = false, renderCanvas = false,
  renderMap = nil, pipelineCanvas = false, worldOverride = false,
  fadeAlpha = 1,
})
local productBlack = QA.classifyCenterEntryFrame(productBlackRow)
eq(productBlack.productBlack, true, "real Transition midpoint was not identified")
eq(productBlack.birdseye, false,
   "fully product-covered cold build was mislabelled bird's-eye")
eq(productBlack.qaCover, false, "product fade was mislabelled QA cover")
local fallback = QA.classifyCenterEntryFrame(frame({
  map = "MT_MOON_POKECENTER", cellX = 3, cellY = 7,
  ready = false, renderCalled = false, renderCanvas = false,
  renderMap = nil, pipelineCanvas = false, worldOverride = false,
  fadeAlpha = 0.9,
}))
eq(fallback.birdseye, true,
   "visible cold 2D fallback escaped Center frame certification")
eq(QA.classifyCenterEntryFrame(frame({ worldActive = false })).black, true,
   "visible missing world composite escaped black certification")
eq(QA.classifyCenterEntryFrame(frame({ qaCover = true })).qaCover, true,
   "QA cover was not independently rejected")
eq(QA.classifyCenterEntryFrame(frame({ pipelineLevel = 6 })).wrongLevel, true,
   "wrong product pipeline level was not detected")

local targetVisible = frame({
  frame = 3, map = "MT_MOON_POKECENTER", cellX = 3, cellY = 7,
  ready = true, renderMap = "MT_MOON_POKECENTER", fadeAlpha = 0.5,
})
local final = frame({
  frame = 4, top = "table:OverworldController.lua", stackCurrent = true,
  map = "MT_MOON_POKECENTER", cellX = 3, cellY = 7, ready = true,
  renderMap = "MT_MOON_POKECENTER", fadeAlpha = 0,
})
local summary = QA.summarizeCenterEntryFrames(
  { frame(), productBlackRow, targetVisible, final },
  { fromMap = "ROUTE_4", toMap = "MT_MOON_POKECENTER", toX = 3, toY = 7 })
eq(summary.pass, true, "valid real Center transition certificate failed")
eq(summary.birdseye, 0, "valid Center transition counted bird's-eye frames")
eq(summary.black, 0, "valid Center transition counted black defects")
eq(summary.qaCover, 0, "valid Center transition used a QA cover")
eq(summary.productBlack, 1, "product fade midpoint count drifted")
eq(summary.targetUnderTransition, 2,
   "target map was not proved under the real Transition stack")
eq(summary.targetLanding, 3, "exact Center landing was not proved")
eq(summary.finalReady3d, 1,
   "final uncovered ready 3D Center frame was not proved")

local badSummary = QA.summarizeCenterEntryFrames(
  { frame(), productBlackRow,
    frame({ map = "MT_MOON_POKECENTER", cellX = 3, cellY = 7,
            ready = false, renderCalled = false, renderCanvas = false,
            renderMap = nil, pipelineCanvas = false, worldOverride = false,
            fadeAlpha = 0.9 }), final },
  { fromMap = "ROUTE_4", toMap = "MT_MOON_POKECENTER", toX = 3, toY = 7 })
eq(badSummary.pass, false, "visible bird's-eye frame produced a PASS certificate")
eq(badSummary.birdseye, 1, "visible bird's-eye frame count drifted")

local line = QA.centerEntryFrameLine("MTMOON_CENTER_COLD", final)
for _, token in ipairs({
  "VASC_QA_MTMOON_CENTER_COLD_FRAME", "product_pipeline=voxel",
  "pipeline_level=7", "top=table:OverworldController.lua",
  "map=MT_MOON_POKECENTER", "cell=3,7", "ready=1",
  "render_called=1", "render_map=MT_MOON_POKECENTER", "render3d=1",
  "product_black=0", "qa_cover=0", "birdseye=0", "black=0",
}) do
  if not line:find(token, 1, true) then
    error("Center frame log lost exact field: " .. token .. " in " .. line, 0)
  end
end

-- The default remains the historical Route8->Saffron->Route8->Lavender->
-- Route8 cycle. Rotations change only which exact reciprocal leg owns the
-- cold process start, and a second pass repeats the same cyclic order.
local defaultMatrix = QA.route8SeamMatrix()
eq(defaultMatrix.startCase, "A", "Route 8 default start case drifted")
eq(defaultMatrix.passes, 1, "Route 8 default pass count drifted")
eq(defaultMatrix.order, "ABCD", "Route 8 default order drifted")
eq(#defaultMatrix.legs, 4, "Route 8 matrix lost a reciprocal leg")

local expectedOrders = { A = "ABCD", B = "BCDA", C = "CDAB", D = "DABC" }
for startCase, expectedOrder in pairs(expectedOrders) do
  local matrix = QA.route8SeamMatrix(startCase, "2")
  eq(matrix.startCase, startCase, "Route 8 start case was not retained")
  eq(matrix.passes, 2, "Route 8 second pass was not retained")
  eq(matrix.order, expectedOrder, "Route 8 cyclic order drifted")
  local rebuilt = ""
  for _, leg in ipairs(matrix.legs) do rebuilt = rebuilt .. leg.key end
  eq(rebuilt, expectedOrder, "Route 8 order and leg records disagree")
end

local A, B, C, D = defaultMatrix.legs[1], defaultMatrix.legs[2],
  defaultMatrix.legs[3], defaultMatrix.legs[4]
for _, row in ipairs({
  { A, "ROUTE_8", "SAFFRON_CITY", "left", 0, 9, 59, 0, 9 },
  { B, "SAFFRON_CITY", "ROUTE_8", "right", 39, 17, 0, 39, 17 },
  { C, "ROUTE_8", "LAVENDER_TOWN", "right", 59, 8, 0, 59, 8 },
  { D, "LAVENDER_TOWN", "ROUTE_8", "left", 0, 8, 19, 0, 8 },
}) do
  local leg = row[1]
  eq(leg.sourceMap, row[2], leg.key .. " source map drifted")
  eq(leg.targetMap, row[3], leg.key .. " target map drifted")
  eq(leg.direction, row[4], leg.key .. " direction drifted")
  eq(leg.crossX, row[5], leg.key .. " cross x drifted")
  eq(leg.crossY, row[6], leg.key .. " cross y drifted")
  eq(leg.approachFirst, row[7], leg.key .. " approach start drifted")
  eq(leg.approachLast, row[8], leg.key .. " approach end drifted")
  eq(leg.approachFixed, row[9], leg.key .. " approach lane drifted")
end
eq(A.bootMap, "ROUTE_8", "A cold boot root drifted")
eq(A.bootX, 59, "A cold boot x drifted")
eq(A.bootY, 9, "A cold boot y drifted")
eq(B.bootMap, "SAFFRON_CITY", "B cold boot root drifted")
eq(B.bootX, 0, "B cold boot x drifted")
eq(B.bootY, 17, "B cold boot y drifted")
eq(C.bootMap, "ROUTE_8", "C cold boot root drifted")
eq(C.bootX, 0, "C cold boot x drifted")
eq(C.bootY, 8, "C cold boot y drifted")
eq(D.bootMap, "LAVENDER_TOWN", "D cold boot root drifted")
eq(D.bootX, 19, "D cold boot x drifted")
eq(D.bootY, 8, "D cold boot y drifted")
eq(A.sourceMap == "ROUTE_8", true, "default A approach was removed")
eq(B.sourceMap == "ROUTE_8", false, "default B became a corridor approach")
eq(C.sourceMap == "ROUTE_8", true, "default C approach was removed")
eq(D.sourceMap == "ROUTE_8", false, "default D became a corridor approach")
defaultMatrix.legs[1].sourceMap = "MUTATED"
eq(QA.route8SeamMatrix().legs[1].sourceMap, "ROUTE_8",
   "Route 8 matrix leaked mutable shared records")

for _, invalid in ipairs({
  { "", "1" }, { "a", "1" }, { "E", "1" },
  { "A", "" }, { "A", "0" }, { "A", "3" }, { "A", "1.0" },
  { "A", 1 },
}) do
  local accepted, failure = pcall(QA.route8SeamMatrix, invalid[1], invalid[2])
  eq(accepted, false, "Route 8 matrix accepted an out-of-contract env value")
  if not tostring(failure):find("VASC_QA_ROUTE8_SEAMS invalid", 1, true) then
    error("Route 8 invalid-env failure lost its stable prefix: "
          .. tostring(failure), 0)
  end
end

-- One fixed 0..999-ms histogram accounts for every measured frame. Exercise
-- the percentile boundary and the saturated overflow bin without allocating a
-- row per frame, then pin the compact log/heap markers consumed by RC parsing.
local gcMetric = QA.newGCMetric(1000)
for _ = 1, 94 do QA.recordGCMetric(gcMetric, 0, 0, 1, 0, 1001) end
for _ = 1, 4 do QA.recordGCMetric(gcMetric, 0.001, 0.0005, 1, 0, 1002) end
QA.recordGCMetric(gcMetric, 0.008, 0.006, 1, 1, 1003)
QA.recordGCMetric(gcMetric, 2.000, 1.250, 2, 1, 1004)
eq(gcMetric.frames, 100, "GC metric lost measured frames")
eq(gcMetric.calls, 101, "GC metric lost explicit collector calls")
eq(gcMetric.cycles, 2, "GC metric lost completed collector cycles")
eq(QA.gcMetricPercentile(gcMetric, 0.95), 0.001,
   "GC p95 boundary drifted")
eq(QA.gcMetricPercentile(gcMetric, 0.99), 0.008,
   "GC p99 boundary drifted")
eq(gcMetric.bins[999], 1, "GC overflow did not saturate at 999 ms")
for bin in pairs(gcMetric.bins) do
  if bin < 0 or bin > 999 then
    error("GC histogram escaped its fixed 0..999-ms range: " .. tostring(bin), 0)
  end
end

local gcLine = QA.gcSummaryLine("ROUTE8_SAFFRON", "APPROACH",
                                gcMetric, "normal")
for _, token in ipairs({
  "VASC_QA_ROUTE8_SAFFRON_APPROACH_GC_SUMMARY", "frames=100",
  "calls=101", "cycles=2", "p95_ms=1.000", "p99_ms=8.000",
  "frame_max_ms=2000.000", "call_max_ms=1250.000", "mode=normal",
  "source=explicit_collectgarbage", "bins=1000",
}) do
  if not gcLine:find(token, 1, true) then
    error("GC summary lost exact field: " .. token .. " in " .. gcLine, 0)
  end
end
local heapLine = QA.heapEndLine("ROUTE8_SAFFRON", "APPROACH", gcMetric)
for _, token in ipairs({
  "VASC_QA_ROUTE8_SAFFRON_APPROACH_HEAP_END", "start_kb=1000",
  "end_kb=1004", "peak_kb=1004", "delta_kb=+4",
}) do
  if not heapLine:find(token, 1, true) then
    error("heap endpoint lost exact field: " .. token .. " in " .. heapLine, 0)
  end
end
eq(QA.route8PassHeapLine(2, "warm", 4321.4),
   "VASC_QA_ROUTE8_PASS_HEAP_END index=2 temperature=warm heap_kb=4321",
   "Route 8 pass heap endpoint marker drifted")

eq(QA.route8FinalFullGCEnabled(nil, "forest", false, nil), false,
   "unset final full-GC diagnostic changed another sequence")
eq(QA.route8FinalFullGCEnabled("0", "forest", false, nil), false,
   "explicitly disabled final full-GC diagnostic changed another sequence")
eq(QA.route8FinalFullGCEnabled("1", "route8_seams", true, 2), true,
   "valid final full-GC diagnostic opt-in was rejected")
for _, invalid in ipairs({
  { "", "route8_seams", true, 2 },
  { "true", "route8_seams", true, 2 },
  { "1", "forest", true, 2 },
  { "1", "route8_seams", false, 2 },
  { "1", "route8_seams", true, 1 },
}) do
  local accepted, failure = pcall(QA.route8FinalFullGCEnabled,
    invalid[1], invalid[2], invalid[3], invalid[4])
  eq(accepted, false, "final full-GC diagnostic accepted an invalid gate")
  contains(failure, "VASC_QA_ROUTE8_FINAL_FULL_GC",
           "final full-GC gate failure lost its stable prefix")
end

local gcValues, gcCalls = { 5000, 3500, 3400 }, {}
local function diagnosticGC(option)
  gcCalls[#gcCalls + 1] = option
  if option == "count" then return table.remove(gcValues, 1) end
  if option ~= "collect" then
    error("unexpected diagnostic collector operation " .. tostring(option), 0)
  end
end
local clockValues = { 10.000, 10.010, 20.000, 20.004 }
local function diagnosticClock()
  return table.remove(clockValues, 1)
end
local fullGC = QA.collectRoute8FinalFullGC(diagnosticGC, diagnosticClock)
eq(table.concat(gcCalls, ","), "count,collect,count,collect,count",
   "final full-GC diagnostic call ordering drifted")
eq(fullGC.before, 5000, "final full-GC pre-heap drifted")
eq(fullGC.afterFirst, 3500, "final full-GC first heap drifted")
eq(fullGC.afterSecond, 3400, "final full-GC second heap drifted")
local fullGCLine = QA.route8FinalFullGCLine(fullGC, 3000, 0)
for _, token in ipairs({
  "VASC_QA_ROUTE8_FINAL_FULL_GC", "pass1_kb=3000", "pre_kb=5000",
  "after1_kb=3500", "after2_kb=3400", "reclaimed_kb=+1600",
  "retained_vs_pass1_kb=+400", "collect1_ms=10.000",
  "collect2_ms=4.000", "pending=0", "source=explicit_collectgarbage",
}) do
  contains(fullGCLine, token, "final full-GC marker lost exact field")
end

local hitLine = QA.targetCacheLine("ROUTE8_SAFFRON_SEAM", {
  target = "SAFFRON_CITY", found = true, body = true, aux = true,
  atlas = true, planned = true, planReady = true, planPending = false,
  planResumes = 0, planMaps = 3,
})
for _, token in ipairs({
  "VASC_QA_ROUTE8_SAFFRON_SEAM_TARGET_CACHE", "target=SAFFRON_CITY",
  "found=1", "body=1", "aux=1", "atlas=1", "plan=1",
  "plan_ready=1", "plan_pending=0", "plan_resumes=0", "plan_maps=3",
  "hit=1",
}) do
  if not hitLine:find(token, 1, true) then
    error("target cache marker lost exact field: " .. token .. " in "
          .. hitLine, 0)
  end
end
local missLine = QA.targetCacheLine("MISS", {
  target = "ROUTE_8", found = true, body = true, aux = true, atlas = true,
  planned = true, planReady = true, planPending = false,
  planResumes = 1, planMaps = 3,
})
if not missLine:find("hit=0", 1, true) then
  error("resumed target cache was falsely certified as a hit: " .. missLine, 0)
end

print("manual_transition_qa_driver_test: ok")
