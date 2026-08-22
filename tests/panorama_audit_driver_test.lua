VASC_PANORAMA_AUDIT_TEST = true
local Audit = assert(loadfile("tests/manual_panorama_audit.lua"))()
VASC_PANORAMA_AUDIT_TEST = nil

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected " .. tostring(expected)
          .. ", got " .. tostring(actual), 0)
  end
end

local function contains(value, needle, message)
  if not tostring(value):find(needle, 1, true) then
    error((message or "text missing") .. ": " .. tostring(needle), 0)
  end
end

-- Pin the exact public-0.1.90 state and input contracts the QA-only legacy
-- bootstrap consumes. GEN1RECOMP_0190_ROOT may name the dirty current engine
-- in the shared suite, so accept a candidate only when Game.lua itself proves
-- that it predates playtestAutoContinueRequested.
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
  local versionSource = candidate
    and readFile(candidate .. "/src/core/Version.lua")
  if gameSource
     and versionSource
     and versionSource:find('engine = "0.1.90"', 1, true)
     and gameSource:find("function Game:load()", 1, true)
     and gameSource:find("onContinue = function()", 1, true)
     and not gameSource:find("playtestAutoContinueRequested", 1, true) then
    frozenRoot = candidate
    break
  end
end
if not frozenRoot then
  error("exact frozen Gen1Recomp 0.1.90 panorama fixture unavailable", 0)
end

local frozenMain = assert(readFile(frozenRoot .. "/main.lua"))
local frozenGame = assert(readFile(frozenRoot .. "/src/core/Game.lua"))
local frozenIntro = assert(readFile(frozenRoot .. "/src/ui/IntroMovie.lua"))
local frozenYellow = assert(readFile(frozenRoot .. "/src/ui/YellowIntro.lua"))
local frozenTitle = assert(readFile(frozenRoot .. "/src/ui/TitleState.lua"))
local frozenMenu = assert(readFile(frozenRoot .. "/src/ui/Menu.lua"))
local frozenInput = assert(readFile(frozenRoot .. "/src/core/Input.lua"))
local frozenScreens = assert(readFile(frozenRoot .. "/src/ui/Screens.lua"))
local frozenReport = assert(
  readFile(frozenRoot .. "/src/ui/QuarantineReport.lua"))
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
contains(frozenGame, "pcall(Screens.push, self, \"QuarantineReport\", report)",
  "frozen restoreSave report path drifted")
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
contains(frozenScreens, "inst.screenId = inst.screenId or id",
  "frozen screen registry no longer stamps load-report identity")
contains(frozenReport, "input:wasPressed(\"a\") or input:wasPressed(\"start\")",
  "frozen load-report acknowledgement drifted")
contains(frozenReport, "self.game.stack:pop()",
  "frozen load report no longer reveals its restored Overworld")

-- The bootstrap itself may observe engine state and emit public input only.
-- Later panorama setup legitimately calls setMap for each requested audit map,
-- so inspect just the bootstrap source slice rather than the complete driver.
local panoramaSource = assert(readFile("tests/manual_panorama_audit.lua"))
local bootstrapStart = assert(
  panoramaSource:find("local function qaBootStateType", 1, true))
local bootstrapEnd = assert(
  panoramaSource:find("local function safeRelativePath", bootstrapStart, true))
local bootstrapSource = panoramaSource:sub(bootstrapStart, bootstrapEnd - 1)
for _, denied in ipairs({
  "SaveData", "restoreSave", ":setMap", ".setMap",
  "stack:push", "stack:pop", "stack.states =",
}) do
  if bootstrapSource:find(denied, 1, true) then
    error("panorama bootstrap gained forbidden direct path: " .. denied, 0)
  end
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
  local info = {
    kind = "continue_info", title = title, save = { active = true },
  }
  local report = {
    kind = "quarantine_report", screenId = "QuarantineReport",
    isOpaque = true, report = { recovered = true },
    lines = { "LOAD REPORT" }, offset = 0,
    maxOffset = function() return 0 end,
  }
  local states = {
    intro = { kind = "intro" }, yellow = { kind = "intro" },
    title = title, menu = menu, continue_info = info,
    quarantine_report = report, overworld = overworld,
    unknown = { kind = "unknown" },
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
  report.game = game
  if options.current then
    game.playtestAutoContinueRequested = function() return true end
  end
  local titleWait = options.titleWait or 2
  local function setTop(nextTop, beneath)
    top = nextTop
    stack.states = beneath and { beneath, nextTop } or { nextTop }
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
      if options.withReport then
        if options.badReportStack then
          setTop(report)
        else
          setTop(report, overworld)
        end
      else
        setTop(overworld)
      end
    elseif top.kind == "quarantine_report" and button == "a"
       and not options.stickyReport then
      setTop(overworld)
    end
  end
  return game, update, events, function() return normalContinueCalls end, setTop
end

local function fixtureClassifier(state)
  return state and state.kind or "unknown"
end

local function driveBootstrap(game, update, values, options)
  options = options or {}
  options.classify = fixtureClassifier
  options.continueLabel = options.continueLabel or "CONTINUE"
  options.emit = options.emit or function() end
  local bootstrap = Audit.newQAContinueBootstrap(game, env(values), options)
  for _ = 1, (options.maxFrames or 1800) + 1 do
    if bootstrap:step() then return bootstrap end
    update()
  end
  error("panorama bootstrap fixture escaped its own deadline", 0)
end

-- Real old-engine route, with and without restoreSave's optional load report.
-- Only the simulated onContinue callback mutates Overworld, proving the helper
-- cannot certify a direct map jump.
for _, introKind in ipairs({ "intro", "yellow" }) do
  for _, withReport in ipairs({ false, true }) do
    local game, update, events, continueCalls = makeBootstrapGame(introKind, {
      withReport = withReport,
    })
    local bootstrap = driveBootstrap(game, update, {
      POKEPORT_DRIVER = "tests/manual_panorama_audit.lua",
    })
    eq(bootstrap.done, true, "legacy panorama bootstrap did not finish")
    eq(continueCalls(), 1, "panorama bootstrap bypassed normal CONTINUE")
    eq(game.overworld.map.id, "ACTIVE_SAVE_MAP",
      "normal CONTINUE did not restore the active save map")
    eq(bootstrap.inputEdges, withReport and 5 or 4,
      "legacy panorama input-edge count changed")
    local wantedPath = "intro_requested>title>title_requested>menu>"
      .. "menu_confirmed>continue_confirmed>"
      .. (withReport and "quarantine_acknowledged>" or "")
      .. "overworld"
    eq(table.concat(bootstrap.path, ">"), wantedPath,
      "legacy panorama bootstrap state proof changed")
    eq(#events, bootstrap.inputEdges * 2,
      "panorama tap did not pair every source press/release")
  end
end

-- A localized/hooked menu is navigated by authentic direction edges; its
-- index is never assigned by the bootstrap.
do
  local label = "WEITERSPIELEN"
  local game, update, _, continueCalls = makeBootstrapGame("title", {
    titlePhase = "loop", continueLabel = label, menuIndex = 1,
    items = { { label = "NEWS" }, { label = label }, { label = "NEW GAME" } },
  })
  local bootstrap = driveBootstrap(game, update, {
    POKEPORT_DRIVER = "tests/manual_panorama_audit.lua",
  }, { continueLabel = label })
  eq(continueCalls(), 1, "localized CONTINUE bypassed normal callback")
  eq(bootstrap.inputEdges, 4,
    "localized non-first CONTINUE did not add one direction edge")
end

-- Structurally identical impostors are insufficient: the real helper also
-- requires the QuarantineReport.lua source identity and all stable fields.
do
  local chunk = assert(loadstring(
    "return function() end", "@src/ui/QuarantineReport.lua"))
  local sourcedUpdate = chunk()
  local report = {
    update = sourcedUpdate, screenId = "QuarantineReport", isOpaque = true,
    report = {}, lines = {}, offset = 0,
    maxOffset = function() return 0 end, game = {},
  }
  eq(Audit.qaBootStateKind(report), "quarantine_report",
    "authentic load-report source/shape was not classified")
  report.lines = nil
  eq(Audit.qaBootStateKind(report), "unknown",
    "incomplete load-report shape was accepted")
  report.lines, report.update = {}, function() end
  eq(Audit.qaBootStateKind(report), "unknown",
    "wrong-source load-report impostor was accepted")
end

-- Kanto Ascendant 6.7 owns the final TitleState.update wrapper, so debug
-- provenance changes while the live state remains the authentic engine title.
-- Accept exactly that source and registry/shape receipt, never a lookalike.
do
  local chunk = assert(loadstring(
    "return function() end", "@mods/kanto_ascendant/crystal_v15_features.lua"))
  local title = {
    update = chunk(), screenId = "TitleState", phase = "loop",
    openMenu = function() end, currentSprite = function() end,
    cycleSpecies = { "PIKACHU" }, cycleIndex = 1,
  }
  eq(Audit.qaBootStateKind(title), "title",
    "authentic Kanto 6.7 TitleState wrapper was not classified")
  title.screenId = nil
  eq(Audit.qaBootStateKind(title), "unknown",
    "Kanto title wrapper without TitleState registry identity was accepted")
  title.screenId, title.cycleSpecies = "TitleState", nil
  eq(Audit.qaBootStateKind(title), "unknown",
    "incomplete Kanto title wrapper shape was accepted")
  title.cycleSpecies = { "PIKACHU" }
  title.update = assert(loadstring(
    "return function() end", "@mods/kanto_ascendant/Notcrystal_v15_features.lua"))()
  eq(Audit.qaBootStateKind(title), "unknown",
    "lookalike Kanto title wrapper source was accepted")
end

-- Current engines retain their own double-opt-in path and receive zero input.
do
  local game, update, events = makeBootstrapGame("overworld", { current = true })
  game.overworld.map = { id = "ACTIVE_SAVE_MAP" }
  local bootstrap = driveBootstrap(game, update, {
    POKEPORT_DRIVER = "tests/manual_panorama_audit.lua",
    POKEPORT_PLAYTEST = "1", POKEPORT_PLAYTEST_AUTO_CONTINUE = "1",
  })
  eq(bootstrap.mode, "current_auto_continue", "current mode not detected")
  eq(bootstrap.inputEdges, 0, "current auto-continue received legacy input")
  eq(#events, 0, "current auto-continue touched the input API")
end

for _, flags in ipairs({
  { POKEPORT_DRIVER = "driver" },
  { POKEPORT_DRIVER = "driver", POKEPORT_PLAYTEST = "1" },
  { POKEPORT_DRIVER = "driver", POKEPORT_PLAYTEST_AUTO_CONTINUE = "1" },
}) do
  local game = select(1, makeBootstrapGame("title", { current = true }))
  local accepted, failure = pcall(Audit.newQAContinueBootstrap,
    game, env(flags), { classify = fixtureClassifier })
  eq(accepted, false, "current default/partial flags enabled legacy autodrive")
  contains(failure, "VASC_QA_BOOTSTRAP_CURRENT_FLAGS_REQUIRED",
    "current panorama flag failure lost stable code")
end

-- Legacy Overworld may appear only after ContinueInfo. Reports before that,
-- repeated reports after the one acknowledgement, and every current report
-- path all fail closed.
do
  local game = select(1, makeBootstrapGame("overworld"))
  game.overworld.map = { id = "BYPASS" }
  local bootstrap = Audit.newQAContinueBootstrap(game, env({
    POKEPORT_DRIVER = "driver",
  }), { classify = fixtureClassifier, emit = function() end })
  local accepted, failure = pcall(bootstrap.step, bootstrap)
  eq(accepted, false, "legacy direct Overworld bypass was certified")
  contains(failure, "VASC_QA_BOOTSTRAP_LEGACY_CONTINUE_BYPASSED",
    "legacy panorama bypass failure lost stable code")
end

do
  local game = select(1, makeBootstrapGame("quarantine_report"))
  local bootstrap = Audit.newQAContinueBootstrap(game, env({
    POKEPORT_DRIVER = "driver",
  }), { classify = fixtureClassifier, emit = function() end })
  local accepted, failure = pcall(bootstrap.step, bootstrap)
  eq(accepted, false, "pre-CONTINUE load report was acknowledged")
  contains(failure, "VASC_QA_BOOTSTRAP_UNEXPECTED_STATE",
    "early load-report failure lost stable code")
end

do
  local game, update = makeBootstrapGame("intro", {
    withReport = true, stickyReport = true,
  })
  local bootstrap = Audit.newQAContinueBootstrap(game, env({
    POKEPORT_DRIVER = "driver",
  }), { classify = fixtureClassifier, emit = function() end })
  for _ = 1, 30 do
    local accepted, result = pcall(bootstrap.step, bootstrap)
    if not accepted then
      contains(result, "VASC_QA_BOOTSTRAP_UNEXPECTED_STATE",
        "repeated load-report failure lost stable code")
      bootstrap = nil
      break
    end
    update()
  end
  eq(bootstrap, nil, "repeated load report did not fail closed")
end

do
  local game, update = makeBootstrapGame("intro", {
    withReport = true, badReportStack = true,
  })
  local accepted, failure = pcall(driveBootstrap, game, update, {
    POKEPORT_DRIVER = "driver",
  })
  eq(accepted, false, "detached load report was acknowledged")
  contains(failure, "VASC_QA_BOOTSTRAP_QUARANTINE_STACK",
    "load-report stack failure lost stable code")
end

do
  local game = select(1, makeBootstrapGame(
    "quarantine_report", { current = true }))
  local bootstrap = Audit.newQAContinueBootstrap(game, env({
    POKEPORT_DRIVER = "driver", POKEPORT_PLAYTEST = "1",
    POKEPORT_PLAYTEST_AUTO_CONTINUE = "1",
  }), { classify = fixtureClassifier, emit = function() end })
  local accepted, failure = pcall(bootstrap.step, bootstrap)
  eq(accepted, false, "current load report received QA acknowledgement")
  contains(failure, "VASC_QA_BOOTSTRAP_CURRENT_AUTO_CONTINUE_FAILED",
    "current load-report failure lost stable code")
end

local values = Audit.csv(" route_1,ROUTE_2, route_1 ", true)
eq(#values, 2, "CSV did not deduplicate")
eq(values[1], "ROUTE_1", "CSV did not normalize explicit ids")
eq(Audit.safeRelativePath("qa/panorama-audit", "out"),
   "qa/panorama-audit", "safe relative path changed")
for _, unsafe in ipairs({ "/tmp/a", "../a", "qa/../a", "C:\\tmp\\a" }) do
  local ok = pcall(Audit.safeRelativePath, unsafe, "probe")
  eq(ok, false, "unsafe output path was accepted: " .. unsafe)
end

-- Screenshot QA suppresses KASC's transient location label in memory only.
-- Both option mirrors must agree because KASC 6.x readers use either one,
-- depending on the feature bundle. Unrelated mods and absent KASC stay intact.
local bannerGame = {
  save = { options = { modOptions = {
    kanto_ascendant = { qol_location_banners = 3, keep = "save" },
    unrelated = { qol_location_banners = 2 },
  } } },
  mods = {
    exports = { kanto_ascendant = {} },
    modOptions = {
      kanto_ascendant = { qol_location_banners = 1, keep = "live" },
      unrelated = { qol_location_banners = 2 },
    },
  },
}
eq(Audit.disableLocationBanners(bannerGame), 1,
   "installed KASC banner option was not found")
eq(bannerGame.save.options.modOptions.kanto_ascendant.qol_location_banners,
   false, "saved KASC banner mirror stayed enabled")
eq(bannerGame.mods.modOptions.kanto_ascendant.qol_location_banners,
   false, "live KASC banner mirror stayed enabled")
eq(bannerGame.save.options.modOptions.kanto_ascendant.keep, "save",
   "KASC save option bucket was replaced")
eq(bannerGame.mods.modOptions.kanto_ascendant.keep, "live",
   "KASC live option bucket was replaced")
eq(bannerGame.mods.modOptions.unrelated.qol_location_banners, 2,
   "unrelated mod option was changed")

local noKasc = {
  save = { options = { modOptions = {} } },
  mods = { exports = {}, modOptions = {} },
}
eq(Audit.disableLocationBanners(noKasc), 0,
   "absent KASC was treated as installed")
eq(next(noKasc.save.options.modOptions), nil,
   "absent KASC created a save option bucket")

local data = { maps = {
  ROUTE_10 = { id = "ROUTE_10", tileset = "OVERWORLD", width = 2, height = 2 },
  ROUTE_2 = { id = "ROUTE_2", tileset = "OVERWORLD", width = 2, height = 2 },
  VIRIDIAN_CITY = { id = "VIRIDIAN_CITY", tileset = "OVERWORLD",
                    width = 2, height = 2 },
  MT_MOON_1F = { id = "MT_MOON_1F", tileset = "CAVERN", width = 2, height = 2 },
} }
local routes = Audit.mapsForPreset(data, "routes")
eq(table.concat(routes, ","), "ROUTE_2,ROUTE_10",
   "route preset is not naturally ordered")
eq(#Audit.mapsForPreset(data, "caves"), 1, "cave preset selected wrong maps")

local blocked = {}
local fake = {
  def = { objects = {} }, widthCells = 11, heightCells = 11,
  inBounds = function(self, x, y)
    return x >= 0 and y >= 0 and x < self.widthCells and y < self.heightCells
  end,
  isWalkableCell = function(_, x, y) return not blocked[y * 11 + x] end,
  isWaterCell = function() return false end,
  isWarpTileCell = function() return false end,
  warpAtCell = function() return nil end,
}
local representative = Audit.representativeCell(fake)
eq(representative.x, 5, "representative cell is not horizontally central")
eq(representative.y, 5, "representative cell is not vertically central")
eq(representative.clear, 3, "representative cell lacks boom clearance")

local view = Audit.viewCell(fake, 5, 2, "south", 4)
if not view or view.y <= 2 or view.boom < 3 then
  error("frontal point-of-interest view did not retain a clear southern boom", 0)
end

-- East/west POIs need row alignment.  Penalizing dx for every preferred side
-- used to put a long westward view eight cells north of its target even on a
-- completely open map, so the later cardinal-yaw override looked past it.
local wide = {
  def = { objects = {} }, widthCells = 25, heightCells = 25,
  inBounds = function(self, x, y)
    return x >= 0 and y >= 0 and x < self.widthCells and y < self.heightCells
  end,
  isWalkableCell = function() return true end,
  isWaterCell = function() return false end,
  isWarpTileCell = function() return false end,
  warpAtCell = function() return nil end,
}
local westView = Audit.viewCell(wide, 18, 12, "west", 8)
if not westView or westView.x >= 18 or westView.y ~= 12 then
  error("westward point-of-interest view is not aligned to its target row", 0)
end

-- Route 4's two outdoor Mt. Moon portals use a deliberately narrower opt-in
-- than the generic warp tour. It can certify only exact 1ST/3RD Route 4 warp
-- evidence, never an orbit, a stress boom, another map, or another POI mode.
local firstPortalCamera = Audit.panoramaCameraConfig({ preset = "1st" })
local thirdPortalCamera = Audit.panoramaCameraConfig({ preset = "3rd" })
eq(Audit.route4PortalModeConfig(nil, { "ROUTE_4" }, { warps = true },
                                firstPortalCamera),
   false, "Route 4 portal views unexpectedly became the default")
eq(Audit.route4PortalModeConfig("1", { "ROUTE_4" }, { warps = true },
                                firstPortalCamera),
   true, "exact Route 4 1ST portal scope was rejected")
eq(Audit.route4PortalModeConfig("1", { "ROUTE_4" }, { warps = true },
                                thirdPortalCamera),
   true, "exact Route 4 3RD portal scope was rejected")
for _, invalid in ipairs({
  { "1", { "ROUTE_3" }, { warps = true }, firstPortalCamera },
  { "1", { "ROUTE_4", "ROUTE_5" }, { warps = true }, firstPortalCamera },
  { "1", { "ROUTE_4" }, { warps = true, panorama = true },
    firstPortalCamera },
  { "1", { "ROUTE_4" }, { warps = true },
    Audit.panoramaCameraConfig({ preset = "orbit35-fit" }) },
  { "1", { "ROUTE_4" }, { warps = true },
    Audit.panoramaCameraConfig({ camera = "7", allowCollapsed = "1" }) },
  { "yes", { "ROUTE_4" }, { warps = true }, firstPortalCamera },
}) do
  eq(pcall(Audit.route4PortalModeConfig, invalid[1], invalid[2], invalid[3],
           invalid[4]), false,
     "Route 4 portal opt-in accepted an ambiguous/non-release scope")
end

-- The Route 8/Saffron focus is similarly exact. In particular the map order
-- is part of the cold/current evidence contract, and unrelated Saffron
-- connections cannot run first and consume the 3RD timeout window.
eq(Audit.route8SaffronFocusConfig(
     nil, { "ROUTE_8", "SAFFRON_CITY" }, { connections = true },
     firstPortalCamera), false,
   "Route 8/Saffron focus unexpectedly became the default")
for _, camera in ipairs({ firstPortalCamera, thirdPortalCamera }) do
  eq(Audit.route8SaffronFocusConfig(
       "1", { "ROUTE_8", "SAFFRON_CITY" }, { connections = true }, camera),
     true, "exact Route 8/Saffron normal-camera focus was rejected")
end
for _, invalid in ipairs({
  { "1", { "SAFFRON_CITY", "ROUTE_8" }, { connections = true },
    firstPortalCamera },
  { "1", { "ROUTE_8" }, { connections = true }, firstPortalCamera },
  { "1", { "ROUTE_8", "SAFFRON_CITY" },
    { connections = true, panorama = true }, firstPortalCamera },
  { "1", { "ROUTE_8", "SAFFRON_CITY" }, { connections = true },
    Audit.panoramaCameraConfig({ preset = "orbit75-maxout" }) },
  { "1", { "ROUTE_8", "SAFFRON_CITY" }, { connections = true },
    Audit.panoramaCameraConfig({ camera = "7", allowCollapsed = "1" }) },
  { "route8", { "ROUTE_8", "SAFFRON_CITY" }, { connections = true },
    firstPortalCamera },
}) do
  eq(pcall(Audit.route8SaffronFocusConfig, invalid[1], invalid[2],
           invalid[3], invalid[4]), false,
     "Route 8/Saffron focus accepted an ambiguous/non-release scope")
end
local route8Focus = Audit.route8SaffronFocusEdge(
  "ROUTE_8", "west", { map = "SAFFRON_CITY" })
if not route8Focus then error("Route 8 source focus edge was rejected", 0) end
eq(route8Focus.entryContext, false,
   "Route 8 source edge incorrectly requested a town context")
local saffronFocus = Audit.route8SaffronFocusEdge(
  "SAFFRON_CITY", "east", { map = "ROUTE_8" })
if not saffronFocus then error("Saffron reciprocal focus edge was rejected", 0) end
eq(saffronFocus.entryContext, true,
   "Saffron focus edge lost its separate entry context")
for _, probe in ipairs({
  { "ROUTE_8", "east", { map = "LAVENDER_TOWN" } },
  { "SAFFRON_CITY", "north", { map = "ROUTE_5" } },
  { "SAFFRON_CITY", "east", { map = "ROUTE_7" } },
  { "ROUTE_7", "east", { map = "SAFFRON_CITY" } },
}) do
  eq(Audit.route8SaffronFocusEdge(probe[1], probe[2], probe[3]), nil,
     "unrelated connection leaked into Route 8/Saffron focus")
end

local function route4PortalFixture()
  local def = {
    id = "ROUTE_4", tileset = "OVERWORLD", width = 45, height = 9,
    objects = {}, signs = {
      { x = 12, y = 5 }, { x = 17, y = 7 }, { x = 27, y = 7 },
    },
    warps = {
      { x = 11, y = 5, destMap = "MT_MOON_POKECENTER", destWarp = 1 },
      { x = 18, y = 5, destMap = "MT_MOON_1F", destWarp = 1 },
      { x = 24, y = 5, destMap = "MT_MOON_B1F", destWarp = 8 },
    },
  }
  local map = {
    id = "ROUTE_4", def = def, widthCells = 90, heightCells = 18,
    blocked = {}, warpViews = {},
    inBounds = function(self, x, y)
      return x >= 0 and y >= 0 and x < self.widthCells
        and y < self.heightCells
    end,
    isWalkableCell = function(self, x, y)
      return not self.blocked[y * self.widthCells + x]
    end,
    isWaterCell = function() return false end,
    isWarpTileCell = function(self, x, y)
      return self.warpViews[y * self.widthCells + x] == true
    end,
  }
  function map:warpAtCell(x, y)
    for index, warp in ipairs(self.def.warps) do
      if warp.x == x and warp.y == y then
        return { index = index, def = warp }
      end
    end
    return nil
  end
  return map
end

local portalMap = route4PortalFixture()
local portal2, portal2Reason = Audit.route4PortalViewPlans(
  portalMap, 2, "qa/PILOT/ROUTE_4")
if not portal2 then
  error("valid Route 4 portal #2 plans failed: " .. tostring(portal2Reason), 0)
end
local portal3, portal3Reason = Audit.route4PortalViewPlans(
  portalMap, 3, "qa/PILOT/ROUTE_4")
if not portal3 then
  error("valid Route 4 portal #3 plans failed: " .. tostring(portal3Reason), 0)
end
eq(#portal2, 2, "Route 4 portal #2 did not receive two fixed views")
eq(#portal3, 2, "Route 4 portal #3 did not receive two fixed views")
eq(portal2[1].name, "front", "portal #2 front order changed")
eq(portal2[1].view.x, 18, "portal #2 front x changed")
eq(portal2[1].view.y, 6, "portal #2 front y changed")
eq(portal2[1].view.yaw, math.pi, "portal #2 front yaw changed")
eq(portal2[1].view.facing, "up", "portal #2 front facing changed")
eq(portal2[1].expectedDirection, "N", "portal #2 front bearing changed")
eq(portal2[1].captureKind, "portal-front",
   "portal front manifest kind changed")
eq(portal2[1].path,
   "qa/PILOT/ROUTE_4/warps/002-MT_MOON_1F-18-5-front.png",
   "portal #2 front file identity changed")
eq(portal2[2].name, "three-quarter", "portal #2 oblique order changed")
eq(portal2[2].view.x, 14, "portal #2 three-quarter x changed")
eq(portal2[2].view.y, 6, "portal #2 three-quarter y changed")
eq(portal2[2].view.facing, "right",
   "portal #2 three-quarter facing changed")
eq(portal2[2].expectedDirection, "E",
   "portal #2 three-quarter bearing changed")
eq(portal2[2].captureKind, "portal-three-quarter",
   "portal three-quarter manifest kind changed")
eq(portal3[1].view.x, 24, "portal #3 front x changed")
eq(portal3[1].view.y, 6, "portal #3 front y changed")
eq(portal3[1].captureKind, "portal-front",
   "portal #3 front manifest kind changed")
eq(portal3[2].view.x, 28, "portal #3 three-quarter x changed")
eq(portal3[2].view.y, 6, "portal #3 three-quarter y changed")
eq(portal3[2].view.facing, "left",
   "portal #3 three-quarter facing changed")
eq(portal3[2].expectedDirection, "W",
   "portal #3 three-quarter bearing changed")
eq(portal3[2].path,
   "qa/PILOT/ROUTE_4/warps/003-MT_MOON_B1F-24-5-three-quarter.png",
   "portal #3 three-quarter file identity changed")
local portalManifestJSON = Audit.encodeJSON({ {
  map = "ROUTE_4", category = "warps", poi = portal2[1].poi,
  coords = "18,5", view = "18,6", target_coords = "18,5",
  capture_kind = portal2[1].captureKind,
  direction = portal2[1].expectedDirection, status = "captured",
  path = portal2[1].path,
} })
if not portalManifestJSON:find('"view":"18,6"', 1, true)
   or not portalManifestJSON:find('"target_coords":"18,5"', 1, true)
   or not portalManifestJSON:find('"capture_kind":"portal-front"', 1, true)
   or not portalManifestJSON:find('"direction":"N"', 1, true) then
  error("Route 4 portal JSON lost fixed pose/view identity", 0)
end
local portalManifestTSV = Audit.encodeTSV({ {
  map = "ROUTE_4", category = "warps", poi = portal3[2].poi,
  coords = "24,5", view = "28,6", target_coords = "24,5",
  capture_kind = portal3[2].captureKind,
  direction = portal3[2].expectedDirection, status = "captured",
  path = portal3[2].path,
} })
if not portalManifestTSV:find("24,5\t28,6\t24,5\tportal%-three%-quarter")
   or not portalManifestTSV:find("\tW\t") then
  error("Route 4 portal TSV lost fixed three-quarter identity", 0)
end
for warpIndex, plansForWarp in pairs({ [2] = portal2, [3] = portal3 }) do
  local targetX = warpIndex == 2 and 18 or 24
  for _, plan in ipairs(plansForWarp) do
    local targetYaw = math.atan2(targetX - plan.view.x, 5 - plan.view.y)
    if math.abs((targetYaw - plan.view.yaw + math.pi) % (2 * math.pi)
                - math.pi) > 1e-9 then
      error("Route 4 portal fixed yaw no longer targets its exact warp", 0)
    end
  end
end

local blockedPortal = route4PortalFixture()
blockedPortal.blocked[6 * blockedPortal.widthCells + 18] = true
eq(Audit.route4PortalViewPlans(blockedPortal, 2), nil,
   "blocked portal front cell was accepted")
local occupiedPortal = route4PortalFixture()
occupiedPortal.def.objects = { { x = 14, y = 6 } }
eq(Audit.route4PortalViewPlans(occupiedPortal, 2), nil,
   "occupied portal three-quarter cell was accepted")
local warpViewPortal = route4PortalFixture()
warpViewPortal.warpViews[6 * warpViewPortal.widthCells + 28] = true
eq(Audit.route4PortalViewPlans(warpViewPortal, 3), nil,
   "warp-tile portal observer cell was accepted")
local changedPortal = route4PortalFixture()
changedPortal.def.warps[3].destWarp = 7
eq(Audit.route4PortalViewPlans(changedPortal, 3), nil,
   "changed Route 4 warp contract was accepted")

local function openMap(id, width, height, predicate, waterPredicate)
  return {
    id = id, def = { objects = {} }, widthCells = width, heightCells = height,
    inBounds = function(self, x, y)
      return x >= 0 and y >= 0 and x < self.widthCells and y < self.heightCells
    end,
    isWalkableCell = function(_, x, y)
      return predicate == nil or predicate(x, y)
    end,
    isWaterCell = function(_, x, y)
      return waterPredicate ~= nil and waterPredicate(x, y) or false
    end,
    isWarpTileCell = function() return false end,
    warpAtCell = function() return nil end,
  }
end

-- A 27+ block route is sampled near 20/50/80 percent of its long axis. The
-- stable anchor names are part of the output/manifest contract.
local longRoute = openMap("ROUTE_12", 20, 108)
local anchors = Audit.panoramaAnchors(longRoute)
eq(#anchors, 3, "elongated route did not receive three anchors")
for index, fraction in ipairs({ 0.2, 0.5, 0.8 }) do
  local anchor = anchors[index]
  eq(anchor.name, ("anchor%02d"):format(index), "anchor name changed")
  if math.abs(anchor.y - 107 * fraction) > 2 then
    error("long-route anchor was not selected near its requested slice", 0)
  end
end
eq(#Audit.panoramaAnchors(openMap("ROUTE_1", 20, 36)), 1,
   "ordinary route unexpectedly received multiple anchors")
eq(#Audit.panoramaAnchors(openMap("CERULEAN_CITY", 80, 18)), 1,
   "non-route map unexpectedly received multiple anchors")

-- The explicit release edge audit samples four distinct walkable positions,
-- each looking through a different edge.  Their unequal along-edge fractions
-- prove that a city is not judged only at its centre or on one survey line.
do
  local function testEdgeAuditAnchors()
    local edgeMap = openMap("CERULEAN_CITY", 80, 18)
    local edgeAnchors = Audit.panoramaAnchors(edgeMap, true)
    eq(#edgeAnchors, 4, "edge audit did not receive four spatial stations")
    local expectedEdges = {
      { "edge-north", "north", "N" },
      { "edge-east", "east", "E" },
      { "edge-south", "south", "S" },
      { "edge-west", "west", "W" },
    }
    local edgeCells = {}
    for index, expected in ipairs(expectedEdges) do
      local anchor = edgeAnchors[index]
      eq(anchor.name, expected[1], "edge station name changed")
      eq(anchor.edge, expected[2], "edge station ownership changed")
      eq(anchor.direction, expected[3], "edge station bearing changed")
      eq(anchor.clear, 3, "edge station lacks normal camera clearance")
      local cell = anchor.x .. ":" .. anchor.y
      if edgeCells[cell] then error("edge audit reused one observer cell", 0) end
      edgeCells[cell] = true
    end
    if not (edgeAnchors[1].y < edgeAnchors[3].y
            and edgeAnchors[4].x < edgeAnchors[2].x
            and edgeAnchors[1].x ~= edgeAnchors[3].x
            and edgeAnchors[2].y ~= edgeAnchors[4].y) then
      error("edge audit stations collapsed back onto a centre/axis line", 0)
    end
  end
  testEdgeAuditAnchors()
end

local surfMap = openMap("ROUTE_20", 40, 18,
                        function() return false end,
                        function(x, y) return x >= 5 and x <= 34
                          and y >= 4 and y <= 13 end)
local surf = Audit.representativeSurfCell(surfMap)
if not surf or surf.x < 5 or surf.x > 34 or surf.y < 4 or surf.y > 13
   or surf.clear < 3 then
  error("surf panorama anchor is not a safe deterministic water cell", 0)
end

-- The real 3RD boom can retract on water because ordinary map collision marks
-- surf tiles non-walkable. That is a valid rendered surf pose, not an asset or
-- camera-transition wait. Land shots retain the player-visibility threshold so
-- an obstructed anchor cannot masquerade as a third-person panorama.
eq(Audit.thirdPersonPoseReady(1, 0, 14, true), true,
   "retracted surf camera was rejected as not ready")
eq(Audit.thirdPersonPoseReady(1, 0, 14, false), false,
   "retracted land camera was accepted as ready")
eq(Audit.thirdPersonPoseReady(0.8, 48, 14, true), false,
   "surf camera transition was accepted before full extension")
eq(Audit.thirdPersonPoseReady(1, 48, 14, false), true,
   "clear third-person land camera was rejected")
eq(Audit.freeCameraPoseReady(6, 0, 0, 14, false), true,
   "settled first-person rig was rejected")
eq(Audit.freeCameraPoseReady(6, 0.1, 0, 14, false), false,
   "first-person transition was accepted before the boom fully retracted")
eq(Audit.freeCameraPoseReady(7, 1, 48, 14, false), true,
   "settled third-person rig was rejected by shared camera gate")
eq(Audit.freeCameraPoseReady(5, 0, 0, 14, false), false,
   "orbit rung was accepted as a free-camera audit pose")

-- Numeric selection now admits every real voxel rung but still rejects OFF,
-- out-of-range, and fractional values. The legacy default remains strict 3RD
-- and keeps its historical filenames unchanged.
local defaultCamera = Audit.panoramaCameraConfig({})
eq(defaultCamera.level, 7, "default panorama camera changed from 3RD")
eq(defaultCamera.mode, "3rd", "default camera mode is not 3RD")
eq(defaultCamera.allowCollapsed, false,
   "default 3RD unexpectedly allows a collapsed boom")
eq(Audit.cameraOutputPath("qa/ROUTE_8/N.png", defaultCamera),
   "qa/ROUTE_8/N.png", "legacy 3RD filename changed")
local firstCamera = Audit.panoramaCameraConfig({ camera = "6" })
eq(firstCamera.mode, "1st", "numeric level 6 stopped selecting 1ST")
eq(Audit.cameraOutputPath("qa/ROUTE_8/N.png", firstCamera),
   "qa/ROUTE_8/N.png", "legacy 1ST filename changed")
for level = 1, 7 do
  local config = Audit.panoramaCameraConfig({ camera = tostring(level) })
  eq(config.level, level, "valid voxel camera rung was rejected")
  eq(config.mode, level <= 5 and "orbit" or (level == 6 and "1st" or "3rd"),
     "valid voxel camera rung selected wrong rig")
end
for _, invalid in ipairs({ "0", "8", "-1", "3.5", "birdseye" }) do
  eq(pcall(Audit.panoramaCameraConfig, { camera = invalid }), false,
     "invalid/2D camera was accepted: " .. invalid)
end

local orbit35 = Audit.panoramaCameraConfig({ preset = "orbit35-fit" })
eq(orbit35.level, 3, "35-degree preset selected wrong pipeline rung")
eq(orbit35.pitchDeg, 35, "35-degree preset lost exact orbit pitch")
eq(orbit35.orbitZoom, "fit", "35-degree preset lost FIT zoom")
eq(Audit.cameraDirectionAllowed(orbit35, "N"), true,
   "normal orbit rejected its real north yaw")
eq(Audit.cameraDirectionAllowed(orbit35, "E"), false,
   "normal orbit accepted a relabelled east yaw")
eq(Audit.cameraOutputPath("qa/ROUTE_8/N.png", orbit35),
   "qa/ROUTE_8/N-orbit35-fit.png",
   "35-degree orbit filename lost its camera identity")

local orbit75 = Audit.panoramaCameraConfig({ preset = "orbit75-maxout" })
eq(orbit75.level, 5, "75-degree preset selected wrong pipeline rung")
eq(orbit75.pitchDeg, 75, "75-degree preset lost exact orbit pitch")
eq(orbit75.orbitZoom, "maxout", "75-degree preset lost max-out zoom")
eq(Audit.cameraOutputPath("qa/ROUTE_8/N.png", orbit75),
   "qa/ROUTE_8/N-orbit75-maxout.png",
   "max-out orbit filename lost its camera identity")

for _, invalidOptions in ipairs({
  { preset = "orbit90" },
  { camera = "3", preset = "orbit35-fit" },
  { camera = "3", orbitZoom = "near" },
  { preset = "orbit75-maxout", orbitZoom = "fit" },
  { camera = "6", orbitZoom = "maxout" },
  { camera = "6", allowCollapsed = "1" },
  { camera = "7", allowCollapsed = "yes" },
}) do
  eq(pcall(Audit.panoramaCameraConfig, invalidOptions), false,
     "ambiguous/invalid camera configuration was accepted")
end

-- Collapsed-boom evidence is a separately named stress policy, never a quiet
-- relaxation of normal 3RD. Full extension remains mandatory in either case.
eq(Audit.freeCameraPoseReady(7, 1, 0, 14, false), false,
   "strict 3RD accepted a collapsed land boom")
eq(Audit.freeCameraPoseReady(7, 1, 0, 14, false, true), true,
   "explicit collapsed-boom stress pose was rejected")
eq(Audit.freeCameraPoseReady(7, 0.9, 0, 14, false, true), false,
   "stress mode accepted a partially extended camera transition")
local stressCamera = Audit.panoramaCameraConfig({
  camera = "7", pitch = "-50", allowCollapsed = "1",
})
eq(stressCamera.boomPolicy, "collapsed-stress",
   "collapsed-boom opt-in lost its explicit policy")
eq(Audit.cameraOutputPath("qa/CENTER/N.png", stressCamera),
   "qa/CENTER/N-3rd-collapsed-stress.png",
   "stress screenshot filename is indistinguishable from strict 3RD")

-- Exact normal-orbit readiness proves the completed angle, absence of a
-- player-attached rig, resolved survey scale, and the actual Scene.render
-- frame/view. A stale 2D/cover frame or a differently zoomed render fails.
orbit35.surveyOffset, orbit35.surveyScale = 0, 4
local orbitLive = {
  ready = true, level = 3, angle = math.rad(35), goal = math.rad(35),
  blend = 0, cameraKind = "orbit", zoomOffset = 0, zoomScale = 4,
}
eq(Audit.auditCameraPoseReady(orbit35, orbitLive), true,
   "settled 35-degree normal orbit was rejected")
for field, wrong in pairs({
  blend = 0.2, cameraKind = "placed", zoomOffset = -1,
  zoomScale = 3, angle = math.rad(34), level = 5,
}) do
  local probe = {}
  for key, value in pairs(orbitLive) do probe[key] = value end
  probe[field] = wrong
  eq(Audit.auditCameraPoseReady(orbit35, probe), false,
     "orbit readiness ignored wrong " .. field)
end

local orbitRendered = {
  map = "ROUTE_8", frame = 42, x = 30, y = 9, surfing = false,
  level = 3, angle = math.rad(35), cameraKind = "orbit",
  blend = 0,
  yaw = math.pi, pitch = math.rad(35), zoomOffset = 0, zoomScale = 4,
  viewW = 480, viewH = 270,
}
local orbitExpected = {
  map = "ROUTE_8", frame = 42, x = 30, y = 9, surfing = false,
  yaw = math.pi, viewW = 480, viewH = 270,
}
eq(Audit.renderedCameraPoseReady(orbit35, orbitRendered, orbitExpected), true,
   "exact normal-voxel Scene.render frame was rejected")
local orbitManifest = Audit.cameraManifestFields(orbit35, {
  rendered = orbitRendered,
})
eq(orbitManifest.camera_mode, "orbit", "orbit manifest lost camera mode")
eq(orbitManifest.camera_level, 3, "orbit manifest lost pipeline rung")
eq(orbitManifest.camera_pitch_deg, 35, "orbit manifest lost exact pitch")
eq(orbitManifest.camera_yaw_deg, 180, "orbit manifest lost fixed north yaw")
eq(orbitManifest.camera_zoom_kind, "fit", "orbit manifest lost zoom preset")
eq(orbitManifest.camera_zoom_offset, 0,
   "orbit manifest lost resolved survey offset")
eq(orbitManifest.camera_view, "480x270",
   "orbit manifest lost exact rendered view dimensions")
eq(orbitManifest.render_frame, 42,
   "orbit manifest lost exact Scene.render frame")
for field, wrong in pairs({
  map = "SAFFRON_CITY", frame = 41, yaw = math.pi / 2,
  pitch = math.rad(75), zoomOffset = -1, zoomScale = 3,
  viewW = 320, cameraKind = "placed",
}) do
  local probe = {}
  for key, value in pairs(orbitRendered) do probe[key] = value end
  probe[field] = wrong
  eq(Audit.renderedCameraPoseReady(orbit35, probe, orbitExpected), false,
     "exact orbit render proof ignored wrong " .. field)
end

-- 1ST/3RD still require their original placed rig, 75-degree transition rung,
-- exact head pitch/yaw, and boom zoom. The new orbit branch cannot satisfy it.
local firstLive = {
  ready = true, level = 6, angle = math.rad(75), goal = math.rad(75),
  blend = 1, cameraKind = "placed", extension = 0, boom = 0, showAt = 14,
  surfing = false, boomZoom = 1,
}
eq(Audit.auditCameraPoseReady(firstCamera, firstLive), true,
   "1ST readiness regressed while adding normal orbits")
local thirdLive = {
  ready = true, level = 7, angle = math.rad(75), goal = math.rad(75),
  blend = 1, cameraKind = "placed", extension = 1, boom = 48, showAt = 14,
  surfing = false, boomZoom = 1,
}
eq(Audit.auditCameraPoseReady(defaultCamera, thirdLive), true,
   "strict 3RD readiness regressed while adding normal orbits")
thirdLive.cameraKind = "orbit"
eq(Audit.auditCameraPoseReady(defaultCamera, thirdLive), false,
   "3RD accepted a normal-orbit render rig")
thirdLive.cameraKind = "placed"

local firstRendered = {
  map = "ROUTE_8", frame = 60, x = 30, y = 9, surfing = false,
  level = 6, angle = math.rad(75), cameraKind = "placed", blend = 1,
  yaw = math.pi / 2, pitch = math.rad(10), boomZoom = 1,
  extension = 0, boom = 0, showAt = 14,
}
local freeExpected = {
  map = "ROUTE_8", frame = 60, x = 30, y = 9, surfing = false,
  yaw = math.pi / 2,
}
eq(Audit.renderedCameraPoseReady(firstCamera, firstRendered, freeExpected), true,
   "exact 1ST Scene.render pose regressed")
firstRendered.extension = 0.1
eq(Audit.renderedCameraPoseReady(firstCamera, firstRendered, freeExpected), false,
   "exact 1ST render accepted a partial boom transition")
firstRendered.extension = 0

local strictThirdRendered = {
  map = "ROUTE_8", frame = 60, x = 30, y = 9, surfing = false,
  level = 7, angle = math.rad(75), cameraKind = "placed", blend = 1,
  yaw = math.pi / 2, pitch = math.rad(10), boomZoom = 1,
  extension = 1, boom = 48, showAt = 14,
}
eq(Audit.renderedCameraPoseReady(defaultCamera, strictThirdRendered,
                                 freeExpected), true,
   "exact strict 3RD Scene.render pose regressed")
strictThirdRendered.boom = 0
eq(Audit.renderedCameraPoseReady(defaultCamera, strictThirdRendered,
                                 freeExpected), false,
   "exact strict 3RD render accepted collapsed land boom")

local stressRendered = {}
for key, value in pairs(strictThirdRendered) do stressRendered[key] = value end
stressRendered.pitch = math.rad(-50)
eq(Audit.renderedCameraPoseReady(stressCamera, stressRendered,
                                 freeExpected), true,
   "exact collapsed-boom stress Scene.render pose was rejected")
stressRendered.extension = 0.9
eq(Audit.renderedCameraPoseReady(stressCamera, stressRendered,
                                 freeExpected), false,
   "stress render accepted partial 3RD extension")

local stressManifest = Audit.cameraManifestFields(stressCamera, { rendered = {
  frame = 52, yaw = math.pi, pitch = math.rad(-50), boomZoom = 1,
  boom = 0, showAt = 14, viewW = 320, viewH = 180,
} })
eq(stressManifest.camera_level, 7, "stress manifest lost camera level")
eq(stressManifest.camera_pitch_deg, -50, "stress manifest lost exact pitch")
eq(stressManifest.camera_yaw_deg, 180, "stress manifest lost exact yaw")
eq(stressManifest.boom_policy, "collapsed-stress",
   "stress manifest hid the relaxed boom policy")
eq(stressManifest.boom_collapsed, 1,
   "stress manifest did not identify the collapsed rendered boom")
eq(stressManifest.camera_stress, "collapsed-boom",
   "stress manifest lost its explicit evidence class")
eq(stressManifest.render_frame, 52, "stress manifest lost render frame")
local cameraJSON = Audit.encodeJSON({ stressManifest })
if not cameraJSON:find('"camera_mode":"3rd"', 1, true)
   or not cameraJSON:find('"camera_pitch_deg":-50', 1, true)
   or not cameraJSON:find('"boom_collapsed":1', 1, true)
   or not cameraJSON:find('"camera_stress":"collapsed-boom"', 1, true) then
  error("JSON manifest omitted exact/stress camera evidence", 0)
end
local cameraTSV = Audit.encodeTSV({ stressManifest })
if not cameraTSV:find("camera_mode\tcamera_level\tcamera_preset", 1, true)
   or not cameraTSV:find("collapsed%-stress") then
  error("TSV manifest omitted camera evidence fields", 0)
end

local buildingMap = openMap("SAFFRON_CITY", 40, 40)
local stamp = {
  tx = 20, ty = 20, bw = 8, bh = 8,
  doorGroundSamples = { 22, 27 },
}
local plans = Audit.buildingViewPlans(buildingMap, stamp, 7, "qa/RUN/MAP")
eq(#plans, 4, "building did not receive four view plans")
eq(plans[1].name, "front", "front building view order changed")
eq(plans[2].name, "rear", "rear building view order changed")
eq(plans[3].name, "left", "left building view order changed")
eq(plans[4].name, "right", "right building view order changed")
local seenPaths, seenPois = {}, {}
for _, plan in ipairs(plans) do
  if seenPaths[plan.path] or seenPois[plan.poi] then
    error("building view plan did not produce distinct output identities", 0)
  end
  seenPaths[plan.path], seenPois[plan.poi] = true, true
  if not plan.view then error("open-map building view unexpectedly missing", 0) end
end
eq(plans[1].side, "south", "south portal did not define the front side")
eq(plans[2].side, "north", "south portal did not define the rear side")
eq(plans[3].side, "west", "south portal did not define the left side")
eq(plans[4].side, "east", "south portal did not define the right side")
eq(plans[1].expectedDirection, "N", "front bearing is not cardinal")
eq(plans[2].expectedDirection, "S", "rear bearing is not cardinal")
eq(plans[3].expectedDirection, "E", "left bearing is not cardinal")
eq(plans[4].expectedDirection, "W", "right bearing is not cardinal")
eq(plans[1].trueFront, true, "authored portal was not marked true front")
eq(plans[2].trueFront, false, "rear elevation was marked true front")
if plans[1].view.y <= plans[1].targetY
   or plans[2].view.y >= plans[2].targetY
   or plans[3].view.x >= plans[3].targetX
   or plans[4].view.x <= plans[4].targetX then
  error("building view escaped its requested front/rear/left/right side", 0)
end
if not plans[1].path:find("-front.png", 1, true)
   or not plans[2].path:find("-rear.png", 1, true) then
  error("building output filename lost its view name", 0)
end

local exactPoseChecks = 0
local poseRejected = Audit.buildingViewPlans(
  buildingMap, stamp, 8, "qa/RUN/MAP",
  function(view)
    exactPoseChecks = exactPoseChecks + 1
    return view.side ~= "south"
  end)
if exactPoseChecks == 0 then
  error("live third-person pose validator was not consulted", 0)
end
eq(poseRejected[1].view, nil,
   "exact third-person rejection did not become no-safe-view")
if not poseRejected[2].view then
  error("exact third-person validator rejected an allowed rear pose", 0)
end

local southOnly = openMap("TEST", 40, 40,
                          function(_, y) return y >= 14 end)
local limitedPlans = Audit.buildingViewPlans(southOnly, stamp, 1, "qa/RUN/MAP")
if not limitedPlans[1].view or limitedPlans[2].view ~= nil then
  error("strict per-side building planning did not preserve no-safe-view", 0)
end

-- Elevation labels rotate with the portal normal. An east-facing authored
-- door makes world south the left elevation as seen from that facade.
local eastDoorStamp = {
  tx = 10, ty = 10, bw = 8, bh = 8,
  doorGroundSamples = { 16, 15 },
}
local eastPlans = Audit.buildingViewPlans(buildingMap, eastDoorStamp, 2,
                                          "qa/RUN/MAP")
eq(eastPlans[1].side, "east", "east portal was mislabeled as south front")
eq(eastPlans[1].expectedDirection, "W", "east front faces wrong direction")
eq(eastPlans[2].side, "west", "east facade rear did not rotate")
eq(eastPlans[3].side, "south", "east facade left did not rotate")
eq(eastPlans[4].side, "north", "east facade right did not rotate")

-- Route 2's north gate used to accept a far lateral cell and label a
-- west-looking oblique image as "front". With no walkable cell on the portal
-- normal, the only truthful result is an immediate no-safe-view.
local route2Building = {
  tx = 4, ty = 24, bw = 8, bh = 8,
  doorGroundSamples = { 6, 31 },
}
local route2Layout = openMap("ROUTE_2", 20, 60,
  function(x, y) return y < 16 or x >= 14 end)
local route2Plans = Audit.buildingViewPlans(route2Layout, route2Building, 1,
                                            "qa/RUN/ROUTE_2")
eq(route2Plans[1].side, "south", "Route 2 portal normal changed")
eq(route2Plans[1].view, nil,
   "Route 2 wrong-orientation front was accepted")

-- Route 5 had the same failure in the other lateral direction: the old plan
-- stood five cells west of the door and photographed east while calling it a
-- frontal elevation.
local route5Building = {
  tx = 12, ty = 60, bw = 16, bh = 8,
  doorGroundSamples = { 20, 67 },
}
local route5Layout = openMap("ROUTE_5", 20, 40,
  function(x, y) return y < 34 or x <= 5 end)
local route5Plans = Audit.buildingViewPlans(route5Layout, route5Building, 2,
                                            "qa/RUN/ROUTE_5")
eq(route5Plans[1].side, "south", "Route 5 portal normal changed")
eq(route5Plans[1].view, nil,
   "Route 5 wrong-orientation front was accepted")

-- Route 8's only nominal left-side observer was the west edge cell. Its boom
-- immediately left the map, so ThirdPerson never reached SHOW_AT and the
-- driver waited a full minute with voxel=0. Static boom proof now rejects the
-- pose before any readiness loop starts.
local route8Building = {
  tx = 4, ty = 16, bw = 12, bh = 8,
  doorGroundSamples = { 10, 24 },
}
local route8Layout = openMap("ROUTE_8", 60, 18,
  function(x, y) return not (x == 1 and y == 10) end)
local route8Plans = Audit.buildingViewPlans(route8Layout, route8Building, 1,
                                            "qa/RUN/ROUTE_8")
eq(route8Plans[3].side, "west", "Route 8 left elevation changed sides")
eq(route8Plans[3].view, nil,
   "Route 8 edge pose could still enter a voxel=0 timeout")

-- Route 11's right elevation is the mirrored east-edge case.
local route11Building = {
  tx = 100, ty = 12, bw = 16, bh = 8,
  doorGroundSamples = { 108, 20 },
}
local route11Layout = openMap("ROUTE_11", 60, 18,
  function(x, y) return not (x == 58 and y == 8) end)
local route11Plans = Audit.buildingViewPlans(route11Layout, route11Building, 1,
                                             "qa/RUN/ROUTE_11")
eq(route11Plans[4].side, "east", "Route 11 right elevation changed sides")
eq(route11Plans[4].view, nil,
   "Route 11 edge pose could still enter a voxel=0 timeout")

-- XREF is allowed only for an actually captured, portal-derived front. A
-- doorless facade and a skipped true front both remain independent warp POIs.
eq(Audit.reusableBuildingFront({ results = { front = {
  status = "captured", _trueFront = true,
} } }).status, "captured", "valid true front was not reusable")
eq(Audit.reusableBuildingFront({ results = { front = {
  status = "captured", _trueFront = false,
} } }), nil, "doorless facade was accepted for warp XREF")
eq(Audit.reusableBuildingFront({ results = { front = {
  status = "no-safe-view", _trueFront = true,
} } }), nil, "skipped true front was accepted for warp XREF")

-- Connection offsets are block offsets.  The driver works in 16px cells, so
-- Route 4's real south overlap (-25 blocks against Route 3's 35-block width)
-- is source cells 0..19 and its representative seam cell is x=9.
local route4 = { widthCells = 90, heightCells = 18 }
local maps = {
  ROUTE_3 = { width = 35, height = 9 },
  CERULEAN_CITY = { width = 20, height = 18 },
}
local sx, sy, side, bearing = Audit.connectionTarget(
  route4, "south", { map = "ROUTE_3", offset = -25 }, { maps = maps })
eq(sx, 9, "negative connection overlap chose the wrong cell")
eq(sy, 17, "south connection did not use the source edge")
eq(side, "north", "south connection selected the wrong viewing side")
eq(bearing.name, "S", "south connection selected the wrong bearing")
local ex, ey = Audit.connectionTarget(
  route4, "east", { map = "CERULEAN_CITY", offset = -4 }, { maps = maps })
eq(ex, 89, "east connection did not use the source edge")
eq(ey, 8, "east connection offset was not converted from blocks to cells")

-- Land captures now stand on an actually traversable seam cell. Route 8's
-- west overlap maps source y to Saffron y+8; the only bidirectional lanes are
-- 8/9/10, so their deterministic median is exactly (0,9) <-> (39,17).
local route8Exact = openMap("ROUTE_8", 60, 18,
  function(x, y) return (x == 0 or x == 1) and y >= 8 and y <= 10 end)
local saffronExact = openMap("SAFFRON_CITY", 40, 36,
  function(x, y) return (x == 38 or x == 39) and y >= 16 and y <= 18 end)
local route8West = { map = "SAFFRON_CITY", offset = -4 }
route8Exact.def.connections = { west = route8West }
saffronExact.def.connections = {
  east = { map = "ROUTE_8", offset = 4 },
}
local pairSX, pairSY, pairTX, pairTY = Audit.connectionCellPair(
  route8Exact, saffronExact, "west", route8West, 9)
eq(pairSX, 0, "Route 8 mapped seam left the west edge")
eq(pairSY, 9, "Route 8 mapped seam changed source row")
eq(pairTX, 39, "Route 8 mapped seam missed Saffron east edge")
eq(pairTY, 17, "Route 8 offset mapped to wrong Saffron row")
local route8Seam, route8SeamReason = Audit.landConnectionSeam(
  route8Exact, saffronExact, "west", route8West)
if not route8Seam then
  error("Route 8 lost its bidirectional seam: " .. tostring(route8SeamReason), 0)
end
eq(route8Seam.x, 0, "Route 8 exact view did not stand on source seam")
eq(route8Seam.y, 9, "Route 8 exact view did not choose median lane")
eq(route8Seam.targetX, 39, "Route 8 exact view lost target edge")
eq(route8Seam.targetY, 17, "Route 8 exact view lost target row")
eq(route8Seam.laneCount, 3, "Route 8 valid lane count changed")
eq(route8Seam.seamExact, true, "Route 8 view was not marked seam-exact")
eq(route8Seam.surfing, false, "Route 8 land seam was marked surfing")
local seamFields = Audit.seamExactManifestFields(route8Seam)
if not seamFields then error("seam-exact manifest fields were missing", 0) end
eq(seamFields.coords, "0,9", "seam manifest source coords changed")
eq(seamFields.view, seamFields.coords,
   "seam-exact manifest no longer proves coords == view")
eq(seamFields.target_coords, "39,17",
   "seam manifest lost mapped target coords")
eq(seamFields.capture_kind, "seam-exact",
   "seam manifest lost explicit capture kind")

-- Entry context is deliberately a second, town-side record.  The planner may
-- use only a reciprocal Route -> Town lane, walks a bounded passable path from
-- that lane, and needs three clear cells both behind and in front of the
-- camera.  A simple corridor pins the helper and every manifest coordinate.
local function entryFixture()
  local route = openMap("ROUTE_99", 6, 5,
    function(x, y) return x == 0 and y == 2 end)
  local town = openMap("FIXTURE_TOWN", 10, 7,
    function(x, y) return y == 2 and x >= 2 end)
  route.def.connections = {
    west = { map = "FIXTURE_TOWN", offset = 0 },
  }
  town.def.connections = {
    east = { map = "ROUTE_99", offset = 0 },
  }
  return route, town
end

local fixtureRoute, fixtureTown = entryFixture()
local fixtureContext, fixtureReason = Audit.landConnectionEntryContext(
  fixtureRoute, fixtureTown, "west", fixtureRoute.def.connections.west)
if not fixtureContext then
  error("valid entry context was rejected: " .. tostring(fixtureReason), 0)
end
eq(fixtureContext.x, 5, "entry context changed its four-cell inset")
eq(fixtureContext.y, 2, "entry context left the reciprocal lane")
eq(fixtureContext.boomClear, 3, "entry context lost boom clearance")
eq(fixtureContext.forwardClear, 3, "entry context lost forward clearance")
eq(fixtureContext.captureKind, "entry-context",
   "entry helper lost its distinct capture kind")
eq(fixtureContext.seamExact, false,
   "entry context was mislabeled as seam evidence")
eq(Audit.seamExactManifestFields(fixtureContext), nil,
   "entry context could pass the seam-exact manifest gate")

local contextFields = Audit.entryContextManifestFields(fixtureContext)
if not contextFields then error("entry-context manifest fields were missing", 0) end
eq(contextFields.coords, "9,2", "entry manifest lost town edge coords")
eq(contextFields.view, "5,2", "entry manifest lost distinct observer coords")
eq(contextFields.target_coords, "0,2",
   "entry manifest lost reciprocal route coords")
eq(contextFields.capture_kind, "entry-context",
   "entry manifest was not explicitly separated from seam evidence")
eq(Audit.entryContextManifestFields({
  captureKind = "entry-context", seamExact = true,
  x = 5, y = 2, entryX = 9, entryY = 2, routeX = 0, routeY = 2,
}), nil, "entry manifest accepted a seam-exact collision")

-- Reciprocity and offsets fail closed before the beauty search.  Occupied,
-- warp, boom and forward cells use the same conservative walkable predicate
-- as the observer, so none can be papered over by a nearby false pose.
local noReverseRoute, noReverseTown = entryFixture()
noReverseTown.def.connections = {}
local badContext, badContextReason = Audit.landConnectionEntryContext(
  noReverseRoute, noReverseTown, "west", noReverseRoute.def.connections.west)
eq(badContext, nil, "one-way Route -> Town produced entry context")
eq(badContextReason, "no-reciprocal-connection",
   "one-way entry context reported wrong reason")

local offsetRoute, offsetTown = entryFixture()
offsetTown.def.connections.east.offset = 1
badContext, badContextReason = Audit.landConnectionEntryContext(
  offsetRoute, offsetTown, "west", offsetRoute.def.connections.west)
eq(badContext, nil, "mismatched reciprocal offset produced entry context")
eq(badContextReason, "reciprocal-offset-mismatch",
   "offset mismatch reported wrong entry-context reason")

local occupiedRoute, occupiedTown = entryFixture()
occupiedTown.def.objects = { { x = 5, y = 2 } }
badContext, badContextReason = Audit.landConnectionEntryContext(
  occupiedRoute, occupiedTown, "west", occupiedRoute.def.connections.west)
eq(badContext, nil, "occupied observer produced entry context")
eq(badContextReason, "no-safe-entry-context",
   "occupied observer reported wrong entry-context reason")

local warpRoute, warpTown = entryFixture()
warpTown.isWarpTileCell = function(_, x, y) return x == 6 and y == 2 end
badContext, badContextReason = Audit.landConnectionEntryContext(
  warpRoute, warpTown, "west", warpRoute.def.connections.west)
eq(badContext, nil, "warp inside the boom run produced entry context")
eq(badContextReason, "no-safe-entry-context",
   "warp-blocked boom reported wrong entry-context reason")

local wallRoute, wallTown = entryFixture()
wallTown.isWalkableCell = function(_, x, y)
  return y == 2 and x >= 5
end
badContext, badContextReason = Audit.landConnectionEntryContext(
  wallRoute, wallTown, "west", wallRoute.def.connections.west)
eq(badContext, nil, "blocked forward view produced entry context")
eq(badContextReason, "no-safe-entry-context",
   "blocked forward view reported wrong entry-context reason")

local notTown = openMap("ROUTE_98", 10, 7)
notTown.def.connections = { east = { map = "ROUTE_99", offset = 0 } }
badContext, badContextReason = Audit.landConnectionEntryContext(
  fixtureRoute, notTown, "west", fixtureRoute.def.connections.west)
eq(badContext, nil, "Route -> Route was accepted as town entry context")
eq(badContextReason, "not-route-to-town",
   "non-town entry context reported wrong reason")

-- Pin the two real Saffron side entries only while the generated map data,
-- collision, occupants and reciprocal offsets still prove them.  Route 8's
-- east-side T-junction needs the northward detour found by BFS; Route 7 is its
-- actual mirrored west-side composition.
local engineRoot = os.getenv("GEN1RECOMP_0190_ROOT") or "../gen1recomp"
local realMaps = assert(loadfile(engineRoot .. "/data/generated/maps.lua"))()
local realTilesets =
  assert(loadfile(engineRoot .. "/data/generated/tilesets.lua"))()
local RealMap = assert(loadfile(engineRoot .. "/src/world/Map.lua"))()
local function realMap(id)
  local def = assert(realMaps[id], "missing real map " .. id)
  return RealMap.new(def, assert(realTilesets[def.tileset]))
end

local TurnContextTest = {}
function TurnContextTest.tileKey(tx, ty)
  return (ty + 64) * 4096 + (tx + 64)
end

-- Mirror only the renderer-visible tables supplied to the QA planner.  The
-- independent saffron_route8_turn_test pins their production construction;
-- this fixture proves the focus planner accepts exactly that 31-top/17-phase
-- contract and fails closed if any part is absent or widened.
TurnContextTest.guideCells = {
  { 35, 15 }, { 36, 15 }, { 37, 15 }, { 38, 15 },
  { 36, 16 }, { 37, 16 }, { 38, 16 }, { 39, 16 },
  { 36, 17 }, { 37, 17 }, { 38, 17 }, { 39, 17 },
  { 36, 18 }, { 37, 18 }, { 38, 18 }, { 39, 18 },
}
function TurnContextTest.structureFixture(map)
  local out = { tileAt = {}, topTileAt = {}, topUVAt = {} }
  for _, cell in ipairs(TurnContextTest.guideCells) do
    for dy = 0, 1 do
      for dx = 0, 1 do
        local tx, ty = cell[1] * 2 + dx, cell[2] * 2 + dy
        if map:tileAt(tx, ty) == 0x23 then
          local key = TurnContextTest.tileKey(tx, ty)
          out.tileAt[key] = 0x23
          out.topTileAt[key] = 0x39
        end
      end
    end
  end
  for ty = 30, 37 do
    local transform = ty % 2 == 0 and "cw" or "ccw"
    out.topUVAt[TurnContextTest.tileKey(73, ty)] = transform
    out.topUVAt[TurnContextTest.tileKey(74, ty)] = transform
  end
  out.topUVAt[TurnContextTest.tileKey(75, 37)] = "ccw"
  return out
end

function TurnContextTest.copyStructure(source)
  local out = { tileAt = {}, topTileAt = {}, topUVAt = {} }
  for _, name in ipairs({ "tileAt", "topTileAt", "topUVAt" }) do
    for key, value in pairs(source[name]) do out[name][key] = value end
  end
  return out
end

function TurnContextTest.context(route, town, structure)
  return Audit.route8SaffronTurnContext(
    route, town, "west", route.def.connections.west, structure)
end

local realSaffron = realMap("SAFFRON_CITY")
local realRoute8 = realMap("ROUTE_8")
local realRoute4 = realMap("ROUTE_4")
for _, warpIndex in ipairs({ 2, 3 }) do
  local realPortalPlans, realPortalReason = Audit.route4PortalViewPlans(
    realRoute4, warpIndex, "qa/PILOT/ROUTE_4")
  if not realPortalPlans or #realPortalPlans ~= 2 then
    error("real Route 4 portal contract failed for warp "
          .. tostring(warpIndex) .. ": " .. tostring(realPortalReason), 0)
  end
  for _, plan in ipairs(realPortalPlans) do
    local x, y = plan.view.x, plan.view.y
    if not realRoute4:isWalkableCell(x, y)
       or realRoute4:isWaterCell(x, y)
       or realRoute4:isWarpTileCell(x, y)
       or realRoute4:warpAtCell(x, y) then
      error("real Route 4 portal observer stopped being passable land", 0)
    end
  end
end
local route8Context, route8ContextReason = Audit.landConnectionEntryContext(
  realRoute8, realSaffron, "west", realRoute8.def.connections.west)
if not route8Context then
  error("real Route 8 -> Saffron context failed: "
        .. tostring(route8ContextReason), 0)
end
eq(route8Context.x, 35, "real Route 8 context left preferred Saffron x")
eq(route8Context.y, 15, "real Route 8 context left preferred Saffron y")
eq(route8Context.facing, "left", "real Route 8 context no longer looks west")
eq(route8Context.routeX, 0, "real Route 8 context lost source seam x")
eq(route8Context.routeY, 9, "real Route 8 context lost source seam median")
eq(route8Context.entryX, 39, "real Route 8 context lost Saffron edge x")
eq(route8Context.entryY, 17, "real Route 8 context lost Saffron edge median")
eq(route8Context.searchDepth, 6,
   "real Route 8 context no longer uses the bounded T-junction detour")

-- The focused retake replaces only that generic west-looking composition.
-- It stands on the real bend and looks north, with an exact three-cell run in
-- front and behind so both 1ST and 3RD can use the same truthful observer.
do
local realTurnStructure = TurnContextTest.structureFixture(realSaffron)
local route8Turn, route8TurnReason = TurnContextTest.context(
  realRoute8, realSaffron, realTurnStructure)
if not route8Turn then
  error("real Route 8 -> Saffron turn context failed: "
        .. tostring(route8TurnReason), 0)
end
eq(route8Turn.x, 37, "Route 8 turn observer x drifted")
eq(route8Turn.y, 17, "Route 8 turn observer y drifted")
eq(route8Turn.yaw, math.pi, "Route 8 turn no longer looks north")
eq(route8Turn.facing, "up", "Route 8 turn facing no longer matches yaw")
eq(route8Turn.direction, "N", "Route 8 turn manifest bearing drifted")
eq(route8Turn.boomClear, 3, "Route 8 turn lost three-cell boom")
eq(route8Turn.forwardClear, 3, "Route 8 turn lost three-cell forward run")
eq(route8Turn.turnContext, true, "Route 8 focus lost turn-context identity")
eq(route8Turn.captureKind, "entry-context",
   "Route 8 turn no longer replaces the existing context record")
eq(route8Turn.routeX, 0, "Route 8 turn lost source seam x")
eq(route8Turn.routeY, 9, "Route 8 turn lost source seam median")
eq(route8Turn.entryX, 39, "Route 8 turn lost Saffron entry x")
eq(route8Turn.entryY, 17, "Route 8 turn lost Saffron entry y")
eq(route8Turn.laneCount, 3, "Route 8 turn lane count drifted")
local route8TurnFields = Audit.entryContextManifestFields(route8Turn)
if not route8TurnFields then
  error("Route 8 turn lost its separate context manifest", 0)
end
eq(route8TurnFields.coords, "39,17", "turn manifest lost edge coords")
eq(route8TurnFields.view, "37,17", "turn manifest lost observer coords")
eq(route8TurnFields.target_coords, "0,9",
   "turn manifest lost reciprocal route coords")

for y = 14, 20 do
  local map = realMap("SAFFRON_CITY")
  local rawWalkable = map.isWalkableCell
  function map:isWalkableCell(x, cy)
    if x == 37 and cy == y then return false end
    return rawWalkable(self, x, cy)
  end
  local rejected, rejectedReason = TurnContextTest.context(
    realRoute8, map, TurnContextTest.structureFixture(map))
  eq(rejected, nil, "turn context accepted blocked safety cell y=" .. y)
  eq(rejectedReason, "route8-saffron-turn-unsafe-cell",
     "blocked turn safety cell reported wrong reason y=" .. y)
end

for _, mutation in ipairs({
  { method = "isWaterCell", value = true, label = "water" },
  { method = "isDoorTileCell", value = true, label = "door" },
  { method = "isWarpTileCell", value = true, label = "warp tile" },
  { method = "warpAtCell", value = { index = 99 }, label = "warp" },
}) do
  local map = realMap("SAFFRON_CITY")
  local raw = map[mutation.method]
  map[mutation.method] = function(self, x, y)
    if x == 37 and y == 17 then return mutation.value end
    return raw(self, x, y)
  end
  local rejected, rejectedReason = TurnContextTest.context(
    realRoute8, map, TurnContextTest.structureFixture(map))
  eq(rejected, nil, "turn context accepted observer " .. mutation.label)
  eq(rejectedReason, "route8-saffron-turn-unsafe-cell",
     mutation.label .. " observer reported wrong turn-context reason")
end

do
  local map = realMap("SAFFRON_CITY")
  local def = {}
  for key, value in pairs(map.def) do def[key] = value end
  def.objects = { { x = 37, y = 20 } }
  map.def = def
  local rejected, rejectedReason = TurnContextTest.context(
    realRoute8, map, TurnContextTest.structureFixture(map))
  eq(rejected, nil, "turn context accepted occupied boom cell")
  eq(rejectedReason, "route8-saffron-turn-unsafe-cell",
     "occupied boom cell reported wrong turn-context reason")
end

do
  local bad = TurnContextTest.copyStructure(realTurnStructure)
  bad.topTileAt[TurnContextTest.tileKey(73, 34)] = nil
  local rejected, rejectedReason = TurnContextTest.context(
    realRoute8, realSaffron, bad)
  eq(rejected, nil, "turn context accepted missing $39 top")
  eq(rejectedReason, "route8-saffron-turn-structure-drift",
     "missing $39 top reported wrong turn-context reason")

  bad = TurnContextTest.copyStructure(realTurnStructure)
  bad.topUVAt[TurnContextTest.tileKey(73, 34)] = "ccw"
  rejected, rejectedReason = TurnContextTest.context(
    realRoute8, realSaffron, bad)
  eq(rejected, nil, "turn context accepted wrong $39 phase")
  eq(rejectedReason, "route8-saffron-turn-structure-drift",
     "wrong $39 phase reported wrong turn-context reason")

  bad = TurnContextTest.copyStructure(realTurnStructure)
  bad.topTileAt[TurnContextTest.tileKey(70, 34)] = 0x39
  rejected, rejectedReason = TurnContextTest.context(
    realRoute8, realSaffron, bad)
  eq(rejected, nil, "turn context painted the solid blocker as path")
  eq(rejectedReason, "route8-saffron-turn-structure-drift",
     "painted blocker reported wrong turn-context reason")
end

do
  local map = realMap("SAFFRON_CITY")
  local rawCollision = map.cellTile
  function map:cellTile(x, y)
    if x == 35 and y == 17 then return 0x00 end
    return rawCollision(self, x, y)
  end
  local rejected, rejectedReason = TurnContextTest.context(
    realRoute8, map, TurnContextTest.structureFixture(map))
  eq(rejected, nil, "turn context accepted changed solid blocker")
  eq(rejectedReason, "route8-saffron-turn-structure-drift",
     "changed blocker reported wrong turn-context reason")
end
end

local realRoute7 = realMap("ROUTE_7")
local route7Context, route7ContextReason = Audit.landConnectionEntryContext(
  realRoute7, realSaffron, "east", realRoute7.def.connections.east)
if not route7Context then
  error("real Route 7 -> Saffron context failed: "
        .. tostring(route7ContextReason), 0)
end
eq(route7Context.x, 4, "real Route 7 context left mirrored Saffron x")
eq(route7Context.y, 15, "real Route 7 context left mirrored Saffron y")
eq(route7Context.facing, "right", "real Route 7 context no longer looks east")
eq(route7Context.boomClear, 3, "real Route 7 context lost boom clearance")
eq(route7Context.forwardClear, 3,
   "real Route 7 context lost forward clearance")

-- A one-way declaration or solid target edge is not evidence. Do not fall
-- back to a nearby contextual lawn shot and label that as the connection.
local oneWaySaffron = openMap("SAFFRON_CITY", 40, 36)
local noReciprocal, noReciprocalReason = Audit.landConnectionSeam(
  route8Exact, oneWaySaffron, "west", route8West)
eq(noReciprocal, nil, "one-way connection produced seam evidence")
eq(noReciprocalReason, "no-reciprocal-connection",
   "one-way connection reported wrong no-safe reason")
local blockedSaffron = openMap("SAFFRON_CITY", 40, 36,
  function(x, _) return x == 38 end)
blockedSaffron.def.connections = {
  east = { map = "ROUTE_8", offset = 4 },
}
local blockedSeam, blockedReason = Audit.landConnectionSeam(
  route8Exact, blockedSaffron, "west", route8West)
eq(blockedSeam, nil, "solid target edge produced seam evidence")
eq(blockedReason, "no-bidirectional-land-lane",
   "solid target edge reported wrong no-safe reason")

-- Route 21's southern Cinnabar seam is open water. The old generic POI
-- fallback selected a nearby cell as a walking pose, then overwrote only its
-- yaw; ThirdPerson could never become ready. Connection planning must preserve
-- the exact seam bearing and pin a genuine surf pose instead.
local route21Water = function(x, y)
  return x >= 7 and x <= 12 and y >= 80
end
local route21 = openMap("ROUTE_21", 20, 90,
  function(x, y) return not route21Water(x, y) end, route21Water)
local route21Maps = { CINNABAR_ISLAND = { width = 10, height = 9 } }
local r21x, r21y, r21side, r21bearing = Audit.connectionTarget(
  route21, "south", { map = "CINNABAR_ISLAND", offset = 0 },
  { maps = route21Maps })
local route21View = Audit.connectionView(
  route21, r21x, r21y, r21side, r21bearing, 4)
if not route21View then error("Route 21 water seam had no surf view", 0) end
eq(route21View.x, r21x, "Route 21 surf view left the seam axis")
eq(route21View.y, r21y - 4, "Route 21 surf view chose wrong distance")
eq(route21View.yaw, r21bearing.yaw, "Route 21 surf view changed bearing")
eq(route21View.facing, r21bearing.facing,
   "Route 21 surf view changed facing")
eq(route21View.surfing, true,
   "Route 21 water connection was not pinned as surfing")

-- Route 22's east/Viridian overlap is a blocked/static edge in the audited
-- state. A generic POI search can still find an oblique lawn cell, but that is
-- not evidence for the seam and its fixed east yaw has no proven camera pose.
-- It must become no-safe-view immediately rather than a 60-second timeout.
local route22 = openMap("ROUTE_22", 40, 18,
  function(x, y)
    return (x == 36 and y == 6) or (x == 35 and y == 5)
      or (x == 34 and y == 5) or (x == 34 and y == 4)
  end)
local route22Maps = { VIRIDIAN_CITY = { width = 20, height = 18 } }
local r22x, r22y, r22side, r22bearing = Audit.connectionTarget(
  route22, "east", { map = "VIRIDIAN_CITY", offset = -4 },
  { maps = route22Maps })
local oldRoute22View = Audit.viewCell(route22, r22x, r22y, r22side, 4)
if not oldRoute22View then
  error("Route 22 regression fixture lacks the old oblique fallback", 0)
end
eq(route22:isWalkableCell(oldRoute22View.x - r22bearing.dx,
                          oldRoute22View.y - r22bearing.dy), false,
   "Route 22 fixture unexpectedly has fixed-yaw boom clearance")
eq(Audit.connectionView(route22, r22x, r22y, r22side, r22bearing, 4), nil,
   "Route 22 blocked seam still produced a timeout-prone view")

-- The old generic connectionView helper is now surf-only. Even a wide-open
-- land map cannot silently reintroduce an oblique pseudo-seam capture.
local route4Open = openMap("ROUTE_4", 90, 18)
eq(Audit.connectionView(route4Open, sx, sy, side, bearing, 4), nil,
   "generic POI fallback still accepted a land connection")

local json = Audit.encodeJSON({ {
  map = "ROUTE_8", category = "connections", path = "qa/a.png",
  status = "captured", terrain = 1, coords = seamFields.coords,
  view = seamFields.view, target_coords = seamFields.target_coords,
  capture_kind = seamFields.capture_kind,
} })
if not json:find('"map":"ROUTE_8"', 1, true)
   or not json:find('"terrain":1', 1, true)
   or not json:find('"coords":"0,9"', 1, true)
   or not json:find('"view":"0,9"', 1, true)
   or not json:find('"target_coords":"39,17"', 1, true)
   or not json:find('"capture_kind":"seam-exact"', 1, true) then
  error("JSON manifest lost typed fields", 0)
end
local contextJSON = Audit.encodeJSON({ {
  map = "SAFFRON_CITY", category = "connections",
  poi = "east-ROUTE_8-1-entry-context", path = "qa/context.png",
  status = "captured", coords = contextFields.coords,
  view = contextFields.view, target_coords = contextFields.target_coords,
  capture_kind = contextFields.capture_kind,
} })
if not contextJSON:find('"coords":"9,2"', 1, true)
   or not contextJSON:find('"view":"5,2"', 1, true)
   or not contextJSON:find('"target_coords":"0,2"', 1, true)
   or not contextJSON:find('"capture_kind":"entry-context"', 1, true)
   or contextJSON:find('"capture_kind":"seam-exact"', 1, true) then
  error("JSON manifest conflated entry context with seam evidence", 0)
end
local tsv = Audit.encodeTSV({ { map = "ROUTE_2", status = "captured" } })
if not tsv:find("map\tmap_category", 1, true)
   or not tsv:find("ROUTE_2", 1, true) then
  error("TSV manifest contract changed", 0)
end
local contextTSV = Audit.encodeTSV({ {
  map = "SAFFRON_CITY", status = "captured",
  coords = contextFields.coords, view = contextFields.view,
  target_coords = contextFields.target_coords,
  capture_kind = contextFields.capture_kind,
} })
if not contextTSV:find("9,2\t5,2\t0,2\tentry%-context")
   or contextTSV:find("seam%-exact") then
  error("TSV manifest conflated entry context with seam evidence", 0)
end

-- Continue-on-failure is deliberately exact and opt-in. Unknown spellings
-- retain fail-fast so a typo cannot weaken a release audit unnoticed.
eq(Audit.continueOnFailureEnabled(nil), false,
   "continue-on-failure unexpectedly became the default")
eq(Audit.continueOnFailureEnabled("0"), false,
   "zero enabled continue-on-failure")
eq(Audit.continueOnFailureEnabled("yes"), false,
   "non-contract spelling enabled continue-on-failure")
eq(Audit.continueOnFailureEnabled(" 1 "), true,
   "documented continue-on-failure opt-in was rejected")

local failFastVisited = {}
local failFastOK = pcall(Audit.runMapBatch,
  { "ROUTE_1", "ROUTE_2", "ROUTE_3" }, false,
  function(_, mapId)
    failFastVisited[#failFastVisited + 1] = mapId
    if mapId == "ROUTE_2" then
      error("VASC_PANORAMA_FAIL phase=pose map=ROUTE_2 reason=probe", 0)
    end
  end,
  function() error("fail-fast unexpectedly called recovery", 0) end)
eq(failFastOK, false, "default map batch swallowed a map failure")
eq(table.concat(failFastVisited, ","), "ROUTE_1,ROUTE_2",
   "default map batch visited a map after failure")

local continuedVisited, recovered = {}, {}
local completed, failures = Audit.runMapBatch(
  { "ROUTE_1", "ROUTE_2", "ROUTE_3" }, true,
  function(_, mapId)
    continuedVisited[#continuedVisited + 1] = mapId
    if mapId == "ROUTE_2" then
      error("VASC_PANORAMA_FAIL phase=capture map=ROUTE_2\nreason=bad png", 0)
    end
  end,
  function(failure, index, total)
    recovered[#recovered + 1] = failure.map .. ":" .. index .. ":" .. total
  end)
eq(completed, 2, "continued map batch reported wrong completion count")
eq(#failures, 1, "continued map batch reported wrong failure count")
eq(failures[1].map, "ROUTE_2", "continued map failure lost map id")
eq(failures[1].phase, "capture", "continued map failure lost phase")
if failures[1].reason:find("\n", 1, true) then
  error("continued map failure retained a manifest-breaking newline", 0)
end
eq(table.concat(continuedVisited, ","), "ROUTE_1,ROUTE_2,ROUTE_3",
   "continued map batch did not visit the later map")
eq(recovered[1], "ROUTE_2:2:3", "continued map recovery metadata changed")

local failureJSON = Audit.encodeJSON({ {
  map = "ROUTE_2", category = "map-summary", poi = "map-failure",
  status = "failed", phase = failures[1].phase, reason = failures[1].reason,
} })
if not failureJSON:find('"status":"failed"', 1, true)
   or not failureJSON:find('"phase":"capture"', 1, true)
   or not failureJSON:find('"reason":', 1, true) then
  error("failure manifest lost status, phase, or reason", 0)
end

-- Direct audit teleports have no production Transition. The QA-owned cover is
-- deliberately non-opaque so the real voxel renderer keeps building/drawing
-- below it, while every presented pre-ready frame receives the renderer's
-- full-window black fade. It may reveal only after an exact 3D render, and the
-- screenshot entry point itself refuses to run while the cover is active.
local qaWorld = { id = "QA_OVERWORLD" }
local qaStack = { states = { qaWorld } }
function qaStack:top() return self.states[#self.states] end
function qaStack:push(state) self.states[#self.states + 1] = state end
function qaStack:pop() return table.remove(self.states) end

local qaRenderer = { worldActive = true }
local qaGame = { stack = qaStack, renderer = qaRenderer }
local cover = Audit.newReadyCover(qaGame, qaWorld)
eq(cover.isOpaque, false, "ready cover stopped the underlying voxel draw")
eq(cover:show(), true, "ready cover did not enter above the overworld")
eq(qaStack:top(), cover, "ready cover was not the top QA state")
eq(cover:topAllowed(), true, "owned cover was rejected by readiness")

local presented = {}
local function present(kind, pose)
  qaRenderer.worldFadeAlpha = nil
  if cover.active then cover:draw() end
  local covered = qaRenderer.worldFadeAlpha == 1
  presented[#presented + 1] = {
    kind = covered and "covered" or kind,
    pose = covered and nil or pose,
  }
end

for _ = 1, 3 do present("2d") end
for i = 1, 3 do
  eq(presented[i].kind, "covered",
     "pre-ready flat frame " .. i .. " was presented")
end

local captures = 0
local function fakeCapture(path)
  captures = captures + 1
  eq(path, "qa/exact.png", "capture path changed")
end
local captureOK, captureReason = Audit.captureScreenshotWhenUncovered(
  cover, fakeCapture, "qa/exact.png")
eq(captureOK, nil, "screenshot started under the ready cover")
eq(captureReason, "qa-cover-active", "covered screenshot reported wrong reason")
eq(captures, 0, "covered screenshot callback was invoked")

local exactPose = {
  map = "ROUTE_8", frame = 12, yaw = math.pi, pitch = math.rad(10),
  x = 30, y = 9, surfing = false,
}
local exactStatus = {
  terrain = true, aux = true, atlas = true, horizon = true,
  sky = true, union = true, voxel = true,
  render3d = exactPose.map == "ROUTE_8" and exactPose.frame >= 12
    and exactPose.x == 30 and exactPose.y == 9,
}
local inexactStatus = {}
for key, value in pairs(exactStatus) do inexactStatus[key] = value end
inexactStatus.render3d = false
eq(Audit.readyForReveal(inexactStatus), false,
   "cover accepted a frame without the exact 3D pose")
local revealOK, revealReason = cover:hide(inexactStatus)
eq(revealOK, nil, "cover revealed an inexact frame")
eq(revealReason, "scene-not-exact-3d", "inexact reveal reported wrong reason")
eq(cover.active, true, "inexact reveal removed the cover")

eq(Audit.readyForReveal(exactStatus), true,
   "complete exact 3D status was not revealable")
eq(cover:hide(exactStatus), true, "exact 3D frame did not remove the cover")
eq(cover.active, false, "ready cover stayed active after reveal")
eq(qaStack:top(), qaWorld, "reveal did not restore the overworld top")
present("3d", exactPose)
eq(presented[4].kind, "3d", "first uncovered frame was not 3D")
eq(presented[4].pose.map, "ROUTE_8",
   "first uncovered frame came from the wrong map")
eq(presented[4].pose.frame, 12,
   "first uncovered frame did not carry the proven render frame")
eq(presented[4].pose.x, 30, "first uncovered frame changed exact pose x")
eq(presented[4].pose.y, 9, "first uncovered frame changed exact pose y")

captureOK, captureReason = Audit.captureScreenshotWhenUncovered(
  cover, fakeCapture, "qa/exact.png")
eq(captureOK, true, "uncovered exact frame could not start capture")
eq(captureReason, nil, "successful screenshot returned a failure reason")
eq(captures, 1, "uncovered screenshot callback did not run exactly once")

-- Recovery may have a map-enter screen above the QA cover. The existing
-- uncover loop pops both; syncAfterUncover must then clear the owned flag so a
-- continued map cannot inherit a stale capture lock.
eq(cover:show(), true, "ready cover could not be reused")
qaStack:push({ id = "MAP_ENTER_SCREEN" })
while qaStack:top() ~= qaWorld do qaStack:pop() end
eq(cover:syncAfterUncover(), true, "recovery left the ready cover active")
eq(cover.active, false, "recovery retained the QA-owned cover flag")
eq(cover:allowsCapture(), true, "recovery left screenshot capture locked")

print("panorama audit driver helpers: ok")
