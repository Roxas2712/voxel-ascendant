local stored = {}
local cache = {}

local V = {
  mod = {
    id = "VOXEL_ASCENDANT",
    options = { get = function(_, key) return stored[key] end },
  },
}

function V.require(name)
  if cache[name] then return cache[name] end
  cache[name] = assert(loadfile("lib/" .. name .. ".lua"))(V)
  return cache[name]
end

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected "
          .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function near(actual, expected, tolerance, message)
  if math.abs(actual - expected) > tolerance then
    error((message or "values differ") .. ": expected "
          .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local BattleCam = V.require("BattleCam")
local arena = { mid = { 128, 160 } }

eq(BattleCam.distanceSetting.key, "battleCameraDistance",
   "battle distance has its own persisted option")
eq(BattleCam.distanceSetting.label, "BTL CAM",
   "battle distance has a concise menu label")
eq(BattleCam.DEFAULT_DISTANCE, 3, "product default is explicitly 3X")
eq(BattleCam.distanceSetting:get(), 3, "a new save defaults to 3X")
eq(BattleCam.distanceSetting.values[1], 1, "the ladder still starts at 1X")
eq(BattleCam.distanceSetting.values[2], 2, "2X remains the middle rung")
eq(BattleCam.distanceSetting.values[3], 3, "the saved ladder reaches 3X")
eq(BattleCam.distanceSetting.labels[1], "1X", "1X remains exposed by name")
eq(BattleCam.distanceSetting.labels[2], "2X", "2X remains exposed by name")
eq(BattleCam.distanceSetting.labels[3], "3X", "3X is exposed by name")
eq(BattleCam.ZOOM_MAX, 3, "direct battle zoom shares the 3X hard stop")
local schema = BattleCam.distanceSetting:schema("distance help")
eq(schema.default, 3, "mod-manager schema defaults new saves to 3X")
eq(schema.choices[1][2], 1, "schema keeps 1X first")
eq(schema.choices[2][2], 2, "schema keeps 2X in the middle")
eq(schema.choices[3][2], 3, "schema keeps 3X last")
eq(BattleCam.arenaCameraSetting.key, "arenaCamera",
   "ARENA camera has its own persisted option")
eq(BattleCam.arenaCameraSetting:get(), BattleCam.ARENA_STADIUM,
   "new ARENA battles default to the Stadium director")
local arenaSchema = BattleCam.arenaCameraSetting:schema("arena help")
eq(arenaSchema.default, BattleCam.ARENA_STADIUM,
   "ARENA schema defaults to Stadium")
eq(arenaSchema.choices[1][1], "3X", "fixed ARENA shot is named 3X")
eq(arenaSchema.choices[2][1], "STADIUM",
   "dynamic ARENA shot is named STADIUM")

-- Missing data gets the new 3X default, but every valid old persisted value
-- remains value-addressed rather than being mistaken for the new default.
local ModSetting = V.require("ModSetting")
stored.battleCameraDistance = 1
local oldOne = ModSetting.new("battleCameraDistance", "BTL CAM",
  { 1, 2, 3 }, { "1X", "2X", "3X" }, 3)
eq(oldOne:get(), 1, "an old saved 1X choice is preserved")
stored.battleCameraDistance = 2
local oldTwo = ModSetting.new("battleCameraDistance", "BTL CAM",
  { 1, 2, 3 }, { "1X", "2X", "3X" }, 3)
eq(oldTwo:get(), 2, "an old saved 2X choice is preserved")
stored.battleCameraDistance = nil

BattleCam.applyDistanceSetting(true)
eq(BattleCam.zoom, 3, "the 3X default applies to the live lens")
eq(BattleCam.zoomGoal, 3, "the 3X default applies to its eased goal")

BattleCam.distanceSetting:sync(1)
BattleCam.update(0)
eq(BattleCam.zoom, 1, "a saved 1X choice synchronizes the live lens")
eq(BattleCam.zoomGoal, 1, "a saved 1X choice synchronizes its goal")
BattleCam.distanceSetting:sync(2)
BattleCam.update(0)
eq(BattleCam.zoom, 2, "changing the setting synchronizes the live lens")
eq(BattleCam.zoomGoal, 2, "changing the setting synchronizes its goal")

eq(BattleCam.stepZoom(-1), true,
   "Q/E, wheel or pinch can still fine-tune after the setting")
local manualGoal = BattleCam.zoomGoal
if not (manualGoal < 2) then error("manual zoom did not move inward") end
BattleCam.update(0)
eq(BattleCam.zoomGoal, manualGoal,
   "the saved rung does not overwrite manual zoom every frame")

BattleCam.distanceSetting:sync(3)
local wideFrame = BattleCam.frameH(arena)
eq(BattleCam.zoom, 3, "frame construction notices a new saved rung")
eq(BattleCam.zoomGoal, 3, "3X becomes the exact live goal")
near(wideFrame, BattleCam.RIGS.tele.frameH * 3, 1e-6,
     "3X shows three times the authored vertical world reach")
eq(BattleCam.stepZoom(1), false, "manual zoom cannot move beyond 3X")

BattleCam.distanceSetting:sync(1)
local authored = BattleCam.rig(arena, 0)
eq(BattleCam.zoom, 1, "the rig synchronizes 1X without a prior update")
BattleCam.distanceSetting:sync(3)
local pulledBack = BattleCam.rig(arena, 0)
if not (pulledBack.fov > authored.fov) then
  error("3X did not widen the common staged-battle camera")
end

-- A classic player-side back picture pins orbit/pitch and direct controls,
-- but BTL CAM is an independent saved framing row. It must keep affecting
-- both MAP and DISCS through their shared rig instead of silently reading 1X.
BattleCam.steerable = false
near(BattleCam.frameH(arena), BattleCam.RIGS.tele.frameH * 3, 1e-6,
     "3X remains active while a back picture pins steering")
local pinnedWide = BattleCam.rig(arena, 0)
if not (pinnedWide.fov > authored.fov) then
  error("a pinned back picture incorrectly disabled BTL CAM")
end
eq(BattleCam.stepZoom(-1), false,
   "direct zoom controls remain locked with the pinned composition")
BattleCam.steerable = true

-- Arena validation asks for canonical framing; a user's wide presentation
-- must not change where MAP battles are allowed to stage.
local canonical = BattleCam.rig(arena, 0, true)
near(canonical.fov, authored.fov, 1e-9,
     "canonical arena checks ignore presentation distance")

-- Full-picture ARENA owns an authored 3X master composition.  The ordinary
-- MAP/DISCS distance is ignored there, manual framing is locked, and its own
-- row chooses only exact 3X or the bounded Stadium director.
local styled = {
  mid={128,160}, player={128,184}, enemy={128,136},
  arenaStyle={ id="nugget_bridge" },
}
BattleCam.distanceSetting:sync(1)
BattleCam.arenaCameraSetting:sync(BattleCam.ARENA_FIXED)
BattleCam.reset()
BattleCam.update(.20, styled, { phase="intro" })
near(BattleCam.presentationDistance(styled), 3, 1e-9,
     "ARENA ignores a stored 1X MAP/DISCS distance")
near(BattleCam.frameH(styled), BattleCam.RIGS.tele.frameH * 3,
     1e-9, "fixed ARENA uses its authored 3X reach")
local fixed = BattleCam.directorState()
near(fixed.yaw, 0, 1e-9, "fixed ARENA has no director yaw")
near(fixed.focus, 0, 1e-9, "fixed ARENA has no director focus")
eq(BattleCam.dragOrbit(.08), false, "ARENA refuses manual orbit")
eq(BattleCam.dragPitch(.08), false, "ARENA refuses manual pitch")
eq(BattleCam.stepZoom(-1, styled), false, "ARENA refuses manual zoom")
local fixedRigA = BattleCam.rig(styled, 0)
BattleCam.update(4, styled, { phase="menu" })
local fixedRigB = BattleCam.rig(styled, 0)
near(fixedRigA.eye[1], fixedRigB.eye[1], 1e-9,
     "fixed ARENA has no generic camera drift")
near(fixedRigA.eye[2], fixedRigB.eye[2], 1e-9,
     "fixed ARENA has no generic dolly")
near(fixedRigA.fov, fixedRigB.fov, 1e-9,
     "fixed ARENA preserves its exact lens")

BattleCam.arenaCameraSetting:sync(BattleCam.ARENA_STADIUM)
BattleCam.reset()
BattleCam.update(.20, styled, { phase="intro" })
local opening = BattleCam.directorState()
if not (opening.yaw < 0 and opening.lift > 0) then
  error("ARENA did not begin with its establishing crane")
end
near(BattleCam.frameH(styled), BattleCam.RIGS.tele.frameH * 3,
     .0001, "establishing shot preserves the authored 3X reach")

-- After the opening, a live move first favours its attacker and then crosses
-- toward the target, while narrowing only the additive director lens.
BattleCam.update(1.30, styled, { phase="menu" })
local action = { phase="messages", animPlaying=true, animName="TACKLE",
                 animAttackerIsPlayer=true }
BattleCam.update(.05, styled, action)
local attackerCut = BattleCam.directorState()
if not (attackerCut.action and attackerCut.focus > 0
        and attackerCut.frame < 1) then
  error("ARENA attacker cut was not derived from the live battle animation")
end
BattleCam.update(.40, styled, action)
local targetCut = BattleCam.directorState()
if not (targetCut.focus < attackerCut.focus) then
  error("ARENA action cut did not cross from attacker toward target")
end

eq(BattleCam.dragOrbit(.08), false,
   "manual input cannot move an authored Stadium composition")

-- MAP/DISCS keep the historical camera even when battle animation fields
-- happen to be present.
BattleCam.reset()
BattleCam.update(.50, arena, action)
local plainDirector = BattleCam.directorState()
near(plainDirector.yaw, 0, 1e-9, "MAP/DISCS gain no director yaw")
near(plainDirector.focus, 0, 1e-9, "MAP/DISCS gain no director focus")
near(plainDirector.frame, 1, 1e-9, "MAP/DISCS keep their exact lens")

BattleCam.stepZoom(-1)
BattleCam.distanceSetting:sync(2)
BattleCam.recentre()
eq(BattleCam.zoom, 2, "recentre returns to the saved distance")
eq(BattleCam.zoomGoal, 2, "recentre keeps the saved goal")

local main = assert(io.open("main.lua", "rb"))
local mainSource = main:read("*a")
main:close()
local fullStart = assert(mainSource:find("applyFull = function", 1, true))
local fullEnd = assert(mainSource:find("local function stagedBattles", fullStart,
                                       true))
local fullSource = mainSource:sub(fullStart, fullEnd - 1)
if fullSource:find("BattleCam.distanceSetting:set", 1, true) then
  error("FULL still overwrites the player's persisted BTL CAM choice")
end
if not mainSource:find("MAP and DISCS battles", 1, true)
   or not mainSource:find("1X is the ", 1, true)
   or not mainSource:find("closest, tightest view", 1, true)
   or not mainSource:find("2X is the ", 1, true)
   or not mainSource:find("balanced middle ground", 1, true)
   or not mainSource:find("3X is the ", 1, true)
   or not mainSource:find("default and widest view", 1, true) then
  error("BTL CAM help no longer explains close, middle and default views")
end
local helpStart = assert(mainSource:find(
  '"Set the saved starting distance of MAP and DISCS battles.', 1, true))
local helpEnd = assert(mainSource:find(
  'when = adjustableBattleCamera', helpStart, true))
local distanceHelp = mainSource:sub(helpStart, helpEnd - 1):lower()
if distanceHelp:find("resource", 1, true)
   or distanceHelp:find("saving", 1, true) then
  error("BTL CAM help overclaims an unmeasured resource saving")
end
if not mainSource:find('"ARENA keeps every authored Pokemon footing', 1, true)
   or not mainSource:find('"background-reviewed automatic action director',
                          1, true)
   or not mainSource:find('when = authoredBattleCamera', 1, true) then
  error("ARENA CAM help no longer pins 3X/STADIUM ownership")
end
if not mainSource:find("stadium = false", 1, true) then
  error("ARENA director was confused with KASC's legacy Stadium capability")
end

print("battle camera distance: ok")
