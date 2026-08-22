VASC_BATTLE_VISUAL_QA_TEST = true
local QA = assert(loadfile("tests/manual_battle_visual_qa.lua"))()
VASC_BATTLE_VISUAL_QA_TEST = nil

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
local function env(values)
  return function(name) return values[name] end
end

local config = QA.configFromEnv(env({}))
eq(config.root, "qa/visual-reset/battle-map", "default output root")
eq(config.map, "PALLET_TOWN", "default map")
eq(config.stage, "MAP", "default stage")
eq(config.daytime, "AUTO", "default daytime")
eq(config.hold, false, "default hold mode")
eq(config.x, 10, "default x")
eq(config.y, 12, "default y")
eq(config.species, "RATTATA", "default species")
eq(config.level, 3, "default level")
eq(config.stable, 30, "default stable frame count")
eq(config.timeout, 1800, "default ready timeout")
eq(config.captureTimeout, 300, "default capture timeout")
config = QA.configFromEnv(env({
  VASC_BATTLE_QA_OUT = "qa/run", VASC_BATTLE_QA_RUN_ID = "review-3x",
  VASC_BATTLE_QA_STABLE_FRAMES = "7",
  VASC_BATTLE_QA_TIMEOUT_FRAMES = "90",
  VASC_BATTLE_QA_CAPTURE_TIMEOUT_FRAMES = "12",
  VASC_BATTLE_QA_MAP = "ROUTE_13", VASC_BATTLE_QA_X = "14",
  VASC_BATTLE_QA_STAGE = "ARENA",
  VASC_BATTLE_QA_DAYTIME = "DUSK", VASC_BATTLE_QA_HOLD = "1",
  VASC_BATTLE_QA_Y = "21", VASC_BATTLE_QA_SPECIES = "PIDGEY",
  VASC_BATTLE_QA_LEVEL = "7",
}))
eq(config.root, "qa/run/review-3x", "explicit output root")
eq(config.map, "ROUTE_13", "explicit map")
eq(config.stage, "ARENA", "explicit stage")
eq(config.daytime, "DUSK", "explicit daytime")
eq(config.hold, true, "explicit hold mode")
eq(config.x, 14, "explicit x")
eq(config.y, 21, "explicit y")
eq(config.species, "PIDGEY", "explicit species")
eq(config.level, 7, "explicit level")
eq(config.stable, 7, "explicit stable frame count")
eq(config.timeout, 90, "explicit ready timeout")
eq(config.captureTimeout, 12, "explicit capture timeout")

eq(QA.relativePath("qa/visual-reset"), true, "safe relative path refused")
eq(QA.relativePath("/tmp/escape"), false, "absolute path accepted")
eq(QA.relativePath("qa/../escape"), false, "parent traversal accepted")
eq(QA.relativePath("qa\\escape"), false, "backslash path accepted")
eq(QA.relativePath("qa//escape"), false, "empty segment accepted")

local png = "\137PNG\r\n\26\n" .. string.rep("x", 24)
  .. "IEND\174B\096\130"
eq(QA.completePNG(png), true, "complete PNG refused")
eq(QA.completePNG(png:sub(1, -2)), false, "truncated PNG accepted")
eq(QA.completePNG("not a png"), false, "non-PNG accepted")

local canvas = {}
local arena = { map = { id = "PALLET_TOWN" } }
local shot = { canvas = canvas }
local top = { voxelAscendantShot = { canvas = canvas } }
local ready, reason = QA.presentedShotReady(
  top, arena, shot, "PALLET_TOWN")
eq(ready, true, "presented shot refused")
eq(reason, nil, "presented shot returned a reason")
ready, reason = QA.presentedShotReady(
  {}, arena, shot, "PALLET_TOWN")
eq(ready, false, "unpresented shot accepted")
eq(reason, "shot-not-presented", "wrong unpresented-shot reason")
ready, reason = QA.presentedShotReady(
  { voxelAscendantShot = { canvas = {} } }, arena, shot, "PALLET_TOWN",
  nil)
eq(ready, false, "mismatched presented canvas accepted")
eq(reason, "presented-canvas-mismatch", "wrong mismatch reason")
ready, reason = QA.presentedShotReady(
  top, { map = { id = "ROUTE_13" } }, shot, "PALLET_TOWN")
eq(ready, false, "wrong arena map accepted")
eq(reason, "arena-not-ready", "wrong arena reason")

local diagnostics = QA.globalPendingDiagnostics(
  { pending = function() return 7 end },
  { buildStatus = function() return { pending = 3 } end })
eq(diagnostics.mesher, 7, "global mesher diagnostic")
eq(diagnostics.horizon, 3, "global horizon diagnostic")
diagnostics = QA.globalPendingDiagnostics(
  { pending = function() return "7" end },
  { buildStatus = function() error("diagnostic unavailable") end })
eq(diagnostics.mesher, -1, "malformed mesher diagnostic did not degrade")
eq(diagnostics.horizon, -1, "failed horizon diagnostic did not degrade")

local neighbor = {
  map = { id = "ROUTE_1" }, ox = 0, oy = -144, w = 320, h = 144,
}
local ow = {
  map = { id = "PALLET_TOWN" }, neighbors = { neighbor }, worldMaps = {},
}
local Scene = {
  planStatus = function()
    return { active = { rootId = "PALLET_TOWN",
                        ids = { "PALLET_TOWN", "ROUTE_1" } } }
  end,
}
local observedState
local Horizon = {
  cacheStatus = function(state)
    observedState = state
    return {
      enabled = true, ready = true, pending = false, failed = false,
      maps = 2, key = "full|world|PALLET_TOWN|ROUTE_1",
    }
  end,
}
local plan, planReason = QA.exactPlanReceipt(
  Scene, Horizon, ow, "PALLET_TOWN")
eq(plan.key, "full|world|PALLET_TOWN|ROUTE_1", "exact plan key")
eq(plan.maps, 2, "exact plan map count")
eq(planReason, nil, "ready exact plan returned a reason")
eq(observedState.map, ow.map, "plan probe changed root map identity")
eq(observedState.neighbors[1], neighbor,
  "plan probe changed neighbor identity")
eq(observedState.worldMaps, ow.worldMaps,
  "plan probe omitted canonical world metadata")

Horizon.cacheStatus = function()
  return { enabled = true, ready = false, pending = true, failed = false,
           maps = 2, key = "pending-key" }
end
plan, planReason = QA.exactPlanReceipt(Scene, Horizon, ow, "PALLET_TOWN")
eq(plan, nil, "pending exact plan accepted")
eq(planReason, "active-horizon-pending", "wrong pending-plan reason")
Scene.planStatus = function()
  return { active = { rootId = "PALLET_TOWN",
                      ids = { "PALLET_TOWN", "MISSING_MAP" } } }
end
plan, planReason = QA.exactPlanReceipt(Scene, Horizon, ow, "PALLET_TOWN")
eq(plan, nil, "unreconstructable active plan accepted")
eq(planReason, "active-plan-member-unavailable",
  "wrong missing-plan-member reason")

local lockedArena, lockedCanvas = {}, {}
local locked = {
  arena = lockedArena, canvas = lockedCanvas, planKey = "exact-plan-a",
}
eq(QA.sameReceiptIdentity(locked, {
  arena = lockedArena, canvas = lockedCanvas, planKey = "exact-plan-a",
}), true, "identical plan/shot receipt refused")
eq(QA.sameReceiptIdentity(locked, {
  arena = lockedArena, canvas = lockedCanvas, planKey = "exact-plan-b",
}), false, "progressive plan change was accepted as stable")
eq(QA.sameReceiptIdentity(locked, {
  arena = lockedArena, canvas = {}, planKey = "exact-plan-a",
}), false, "shot canvas change was accepted as stable")
eq(QA.sameReceiptIdentity(locked, {
  arena = {}, canvas = lockedCanvas, planKey = "exact-plan-a",
}), false, "arena identity change was accepted as stable")

local function configFails(values, needle)
  local ok, message = pcall(QA.configFromEnv, env(values))
  eq(ok, false, "invalid configuration was accepted")
  contains(message, needle, "wrong configuration failure")
end
configFails({ VASC_BATTLE_QA_MAP = "../ROUTE_13" }, "unsafe-map")
configFails({ VASC_BATTLE_QA_SPECIES = "Mr Mime" }, "unsafe-species")
configFails({ VASC_BATTLE_QA_STAGE = "STADIUM" }, "unsafe-stage")
configFails({ VASC_BATTLE_QA_DAYTIME = "SUNSET" }, "unsafe-daytime")
configFails({ VASC_BATTLE_QA_HOLD = "2" }, "invalid-hold")
configFails({ VASC_BATTLE_QA_X = "2.5" }, "invalid-number")
configFails({ VASC_BATTLE_QA_LEVEL = "0" }, "invalid-number")
configFails({ VASC_BATTLE_QA_STABLE_FRAMES = "1" }, "invalid-number")

local handle = assert(io.open("tests/manual_battle_visual_qa.lua", "rb"))
local source = handle:read("*a")
handle:close()
contains(source, 'selectValue("battles", config.stage)',
  "driver no longer selects its stage through the real option row")
contains(source, 'selectValue("daytime", config.daytime)',
  "driver no longer selects the shared Overworld/Arena clock option")
contains(source, 'config.stage == "ARENA"',
  "driver no longer separates authored and map camera contracts")
contains(source, 'arenaCameraRow = selectValue("arenaCamera", "3X")',
  "driver lost the authored fixed-3X receipt")
contains(source, 'arenaCameraRow = selectValue("arenaCamera", "STADIUM")',
  "driver lost the authored Stadium receipt")
contains(source, 'capture("1X")', "MAP/DISCS driver lost the close receipt")
contains(source, 'capture("2X")', "MAP/DISCS driver lost the middle receipt")
contains(source, 'capture("3X")', "driver lost the 3X receipt")
contains(source, "VASC_BATTLE_QA_DONE captures=2",
  "driver no longer requires both legal ARENA compositions")
contains(source, "VASC_BATTLE_QA_DONE captures=3",
  "driver no longer requires all three MAP/DISCS BTL CAM receipts")
contains(source, "VASC_BATTLE_QA_DEMO_READY",
  "driver lost its visible held-demo marker")
contains(source, "top.voxelAscendantShot",
  "driver no longer proves the shot reached a presented draw")
contains(source, "graphics.captureScreenshot(path)",
  "driver no longer captures the real framebuffer")
contains(source, "Horizon.cacheStatus, planState",
  "driver no longer probes the exact active horizon key passively")
contains(source, "sameReceiptIdentity(current, previous)",
  "driver no longer resets stability when the active plan changes")
contains(source, "sameReceiptIdentity(current, locked)",
  "capture no longer pins the stable plan/shot identity")
contains(source, "global_mesher_pending=%d",
  "READY marker lost the non-gating global mesher diagnostic")
contains(source, "global_horizon_pending=%d",
  "READY marker lost the non-gating global horizon diagnostic")
local doneAt = assert(source:find("VASC_BATTLE_QA_DONE", 1, true))
local flushAt = assert(source:find(
  "pcall(io.stdout.flush, io.stdout)", doneAt, true))
local quitAt = assert(source:find("event.quit(0)", flushAt, true))
if not (doneAt < flushAt and flushAt < quitAt) then
  error("DONE is not flushed before clean native quit", 0)
end

print("battle visual QA driver tests passed")
