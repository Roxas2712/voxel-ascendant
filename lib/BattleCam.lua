-- Overworld battles: the over-the-shoulder camera and its parallax drift.
--
-- The two mons are PINNED to their cells: each pic is drawn wherever its
-- patch of ground projects to, not at a fixed screen slot. So the camera is
-- not decoration -- it is the thing that decides where the fight appears,
-- and it has to put those two patches of ground exactly where the battle
-- screen wants its two pics:
--
--     the player's mon   (26, 96)    back pic, feet on the text box, well left
--     the enemy's mon   (124, 56)    front pic, bottom of the 7x7 slot
--
-- Four screen coordinates, so four equations. The rig below is the solution:
-- SIDE / BACK / HEIGHT place the eye relative to the arena's midpoint, LOOK
-- aims it, and FRAME_H sets the lens, and together they land both marks
-- within a thousandth of a pixel of the targets. They are not hand-picked
-- numbers that looked about right -- they came out of a solver, and the
-- suite reprojects them so a future edit either still lands or says so.
--
-- East is what decides which mon is on which side. The arena axis runs north
-- (the enemy) to south (the player's mon), and a camera east of that axis
-- sees the near end swing LEFT and the far end RIGHT -- the layout arrived
-- at by standing in the right place rather than by mirroring anything.
--
-- ------- and two more equations, from the pixels
--
-- The pics are pixel art and their size on screen is not something the mod
-- gets to choose: 56 pixels for a front pic, 64 for a back one. And a mon has
-- to stand in ONE OVERWORLD SQUARE, or it towers over the houses and gives
-- away that the world behind it is a picture. Together those say the square
-- each mon stands on must project to about the width of its own pic, which is
-- two more equations for the same six unknowns -- and they are what set the
-- distance.
--
-- The answer is a LONG LENS FROM A LOW STANCE: twelve degrees above the
-- floor, twelve degrees wide, from five blocks back. Not a stylistic choice
-- -- it is what a 56-pixel sprite standing on a 16-pixel tile forces on a
-- 160-pixel screen. Roughly three tiles fit across the frame, so the camera
-- has to be far away and zoomed in rather than near and wide. That is the
-- DEFAULT rig, and every map that can take it gets it.
--
-- ------- the exception: rooms too small to stand back from
--
-- Five blocks back is further than some rooms are wide. A gym is about ten
-- cells across, so on one the eye lands OUTSIDE the map, where the border
-- ring the engine draws round every map -- extruded into a cliff by this mode
-- -- crosses the near Pokemon wherever it stands. Three gyms could not be
-- staged anywhere at all for that reason.
--
-- So there is a second rig, and an arena asks for it by name (cam = "wide"
-- in data/battle_arenas.lua). It comes in to about four cells with the lens
-- opened up to match: an ordinary 44-degree shot that fits inside the room.
-- The mons render smaller for it -- a bit over half a tile rather than a
-- whole one -- which is the price. Both rigs are solved against the SAME four
-- anchors, so the composition is identical either way; only the lens and the
-- distance differ, which is what makes it safe to pick per map.
--
-- Rooms too small for the long lens are the reason it exists, but it is not
-- only for them: an area that simply reads better with more of itself in
-- shot can ask for it too.
--
-- Purely presentational, like everything else in this mod: the camera looks
-- at the map, and nothing it does reaches collision, movement or scripts.

-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local ModSetting = V.require("ModSetting")

local BattleCam = {}

-- ------- the rig, in world pixels (a map cell is 16, a block 32)
--
-- Solved against the four anchors and two spans above, with the two mons 48
-- world pixels (three cells) apart -- BattleArena.SHAPES is where that gap is
-- set, and changing it invalidates these.

-- `frameH` is how much world the frame is tall enough to hold at the aim
-- distance, which together with that distance is the lens.
-- Named for the LENS, because that is what an author is choosing between
-- when they look at a shot and decide it wants more room in it.
BattleCam.RIGS = {
  -- the default: a long 11.5-degree lens from five blocks back, which is
  -- what makes one tile big enough to stand a 56-pixel mon on
  tele = {
    side = 78.79, back = 144.96, height = 37.88,
    lookX = -0.26, lookY = 0.34, frameH = 34.11,
  },
  -- 44 degrees from four cells: fits inside a room the long lens cannot
  -- stand back from, and shows more of anywhere else, at the cost of a
  -- smaller pair
  wide = {
    side = 41.98, back = 41.16, height = 28.48,
    lookX = -3.24, lookY = -1.35, frameH = 55.62,
  },
}

BattleCam.DEFAULT_RIG = "tele"

-- The rig an arena asks for, falling back to the default for anything that
-- does not ask (and for a name that is not one of the two).
function BattleCam.rigFor(arena)
  local want = arena and arena.cam
  return BattleCam.RIGS[want] or BattleCam.RIGS[BattleCam.DEFAULT_RIG]
end

-- ------- the drift
--
-- A slow orbit about the arena's vertical axis. Rotating about a point
-- BETWEEN the two mons is what makes it parallax rather than a pan: the mons
-- are pinned to the ground, so the near one slides one way across the frame
-- and the far one slides the OTHER, by the amount their difference in
-- distance implies. Over a full swing that is about eight pixels of relative
-- movement -- plainly visible as depth, far too slow to fight the fight.
-- The angle is small because the lens is long: two degrees of orbit is seven
-- pixels of travel through an eleven-degree field of view.
--
-- Under it, a much smaller breath in and out along the same line, on an
-- unrelated period, so the pair never returns to the same pose on any cycle
-- a battle is long enough to show. A DOLLY rather than a pan of the aim:
-- moving the aim point would slide both mons the same way, which with pinned
-- pics is just the whole picture walking sideways. Changing the DISTANCE
-- moves them apart and back together about the frame's centre, which is the
-- same depth cue the orbit gives, from the other axis.
BattleCam.PAN_YAW = math.rad(2)   -- half-angle of the orbit
BattleCam.PAN_PERIOD = 26         -- seconds for one there-and-back
BattleCam.PAN_DOLLY = 0.02        -- how far the eye breathes, as a fraction
BattleCam.DOLLY_PERIOD = 37

-- ------- the player's own orbit
--
-- The drift above is the shot breathing. THIS is the player steering it:
-- a right stick, a drag across the screen or the mouse walks the eye
-- around the arena's axis, and it stops at both ends.
--
-- 0 is the shot the rig was solved for and the LEFT stop, because there is
-- nothing to the left of it -- the composition below is what the whole
-- module exists to land, and past it the two mons start swapping sides.
--
-- 1 is SIDE-ON: the eye swung round until it is square to the arena's
-- north-south axis, where the two mons stand at the same distance instead
-- of one behind the other. That is as far as the picture stays a battle
-- rather than a diorama with two Pokemon in it, and it is a different angle
-- for each rig -- the tele lens starts 28 degrees off the axis and the wide
-- one 45 -- so the stop is COMPUTED from the rig rather than written down,
-- and retuning either moves its own stop with it.
--
-- The input is deliberately not 1:1 with the pixels: it accumulates into
-- `orbitGoal` and the live angle eases after it, so a flick reads as the
-- camera being pushed rather than as the camera being dragged.
BattleCam.ORBIT_TIME = 0.22       -- seconds for the eye to catch its goal
BattleCam.ORBIT_DRAG = 1.15       -- fraction of the range per screen width
BattleCam.ORBIT_STICK = 0.9       -- fraction of the range per second, full tilt
BattleCam.ORBIT_MOUSE = 0.0011    -- fraction of the range per mouse count
BattleCam.STICK_DEAD = 0.2

-- ------- and the height it is watched from
--
-- The same steering on the other axis, with the same shape of stop at each
-- end: 0 is the rig's own stance -- the low, near-floor seat the whole
-- composition is solved around, and the DOWN stop, because below it the
-- camera starts looking up the arena's nose -- and 1 is 45 degrees above
-- it, which is high enough to read the ground the fight is standing on
-- without becoming the diorama's own top-down.
--
-- Raised about the FOCUS rather than about the eye, so the aim stays on
-- the two mons and only the seat climbs; and at a constant radius, so
-- climbing never changes how big anything is -- that is the zoom's job.
BattleCam.PITCH_RANGE = math.rad(45)
BattleCam.PITCH_TIME = 0.22
BattleCam.PITCH_DRAG = 1.6        -- fraction of the range per screen HEIGHT
BattleCam.PITCH_STICK = 0.9
BattleCam.PITCH_MOUSE = 0.0016

-- ------- and the player's own zoom / saved distance
--
-- How much world the frame holds, as a multiple of the rig's own frameH:
-- BELOW one is zoomed in. It has to be the LENS rather than the distance,
-- because the rig derives its field of view from frameH and the distance
-- together -- so moving the eye alone changes the perspective and not the
-- framing, which is exactly what the dolly breath above is for.
--
-- Q/E, wheel and pinch remain a fine, session-local adjustment. BTL CAM is
-- the persistent starting distance: changing that row snaps the live goal to
-- exactly 1X/2X/3X once, then lets the direct controls move freely again.
-- Keeping the remembered rung separate from `zoomGoal` is important -- if we
-- copied it every frame, the first wheel notch would be undone immediately.
BattleCam.DISTANCE_KEY = "battleCameraDistance"
BattleCam.DISTANCE_LABEL = "BTL CAM"
BattleCam.DEFAULT_DISTANCE = 3
BattleCam.distanceSetting =
  ModSetting.new(BattleCam.DISTANCE_KEY, BattleCam.DISTANCE_LABEL,
                 { 1, 2, 3 }, { "1X", "2X", "3X" },
                 BattleCam.DEFAULT_DISTANCE)

-- Stadium is the cinematic camera style for every terrain-backed battle:
-- ordinary MAP fights use the real voxel world directly, while ARENA first
-- tries that same world and retains its reviewed painting as a safe fallback.
-- DISCS deliberately keep their existing camera because there is no surrounding
-- terrain for an orbit to reveal.  Keep the historical key/value names so an
-- existing saved `stadium` choice begins working in MAP without migration.
BattleCam.ARENA_CAMERA_KEY = "arenaCamera"
BattleCam.ARENA_CAMERA_LABEL = "STADIUM CAM"
BattleCam.ARENA_FIXED = "fixed3x"
BattleCam.ARENA_STADIUM = "stadium"
BattleCam.arenaCameraSetting = ModSetting.new(
  BattleCam.ARENA_CAMERA_KEY, BattleCam.ARENA_CAMERA_LABEL,
  { BattleCam.ARENA_FIXED, BattleCam.ARENA_STADIUM },
  { "STATISCH 3X", "SMART / STADIUM" }, BattleCam.ARENA_STADIUM)

BattleCam.ZOOM_MIN = 0.45         -- the pair filling the frame
BattleCam.ZOOM_MAX = 3.0          -- widest saved rung and manual hard stop
BattleCam.ZOOM_STEP = 1.15
BattleCam.ZOOM_TIME = 0.18

-- A tall phone framebuffer contains far more vertical picture than the
-- classic 160x144 battle frame.  BattleScene deliberately widens the lens
-- instead of stretching that picture, but with the ordinary low camera this
-- used to expose a large empty cap of sky above MAP/DISCS fights.  Keep the
-- fight's midpoint nailed to the optical centre and raise the eye around it:
-- the extra portrait rows then show useful ground, while the two combatants
-- retain their horizontal separation and their feet stay on the same world
-- anchors.  Full-picture ARENA scenery is authored in screen space and has
-- its own aspect-preserving cover crop, so it must never receive this lift.
BattleCam.PORTRAIT_HORIZON = 0.18
BattleCam.PORTRAIT_LIFT_MAX = math.rad(20)

BattleCam.orbit = 0
BattleCam.orbitGoal = 0
BattleCam.pitch = 0
BattleCam.pitchGoal = 0
BattleCam.zoom = 1
BattleCam.zoomGoal = 1

-- A 1X lens is intentionally close, but a very large species or Mega must
-- still remain a complete, readable combatant rather than becoming a crop at
-- the edge of the framebuffer. BattleScene derives this transient floor from
-- the two cards' visible alpha bounds. It never rewrites BTL CAM: small pairs
-- still receive the requested 1X shot, while only the current oversized pair
-- widens as much as it needs to fit.
BattleCam.presentationFit = 1

function BattleCam.setPresentationFit(distance)
  distance = tonumber(distance) or 1
  if not (distance == distance and distance > 0
          and distance < math.huge) then distance = 1 end
  BattleCam.presentationFit = math.max(
    1, math.min(BattleCam.ZOOM_MAX, distance))
  return BattleCam.presentationFit
end

-- The last STORED rung copied into the live camera. Manual zoom deliberately
-- does not change this: it remains free until the saved rung itself changes.
local appliedDistance = nil
local activeArena = nil
local activeBattle = nil
local lastScreenSafe = nil
-- An owner may need to see one exact rendered candidate before it can publish
-- the replacement actor/status receipt used by the final safety evaluator.
-- That circular hand-off gets one provisional frame per exact arena/battle
-- owner. It is never shared through __eq aliases and is re-armed only by a
-- definitive safe verdict or a new exact owner.
local pendingScreenProbe = nil
local SCREEN_PENDING_FRAME_BUDGET = 1
local pendingManualRollback = nil

local function authoredArena(arena)
  return arena and arena.arenaStyle ~= nil
end

function BattleCam.arenaDirectorSelected()
  return BattleCam.arenaCameraSetting:get() == BattleCam.ARENA_STADIUM
end

-- Physical rooms are inspected once when the battle starts.  If too few
-- camera seats can see both combatants, the safest one is latched for the
-- whole fight instead of repeatedly asking the cinematic director to travel
-- through the same walls.  The user may still zoom; only orbit, pitch and
-- automatic motion are withheld while this seat owns the composition.
BattleCam.staticSafetySeat = nil
BattleCam.staticSafetyArena = nil

-- Optional, public screen-space safety seam.  BattleCam owns world geometry;
-- the active HUD owner owns the rectangles it will paint over that world.
-- OverworldBattle connects the two without teaching this module any provider
-- id, generation or skin.  A configured evaluator returns true/false, while
-- nil means an active owner could not supply versioned bounds and therefore
-- requires a conservative static composition.
local screenSafetyEvaluator = nil
BattleCam.screenSafetyOK = true
BattleCam.screenSafetyReason = "not-configured"
BattleCam.screenSafetyFallbackUsed = false

function BattleCam.setScreenSafetyEvaluator(evaluator)
  if evaluator ~= nil and type(evaluator) ~= "function" then
    return false, "invalid-evaluator"
  end
  screenSafetyEvaluator = evaluator
  -- The room decision is cached for one arena. Replacing the public HUD owner
  -- changes that decision, so the next update must inspect it again.
  BattleCam.staticSafetyArena, BattleCam.staticSafetySeat = nil, nil
  lastScreenSafe = nil
  pendingScreenProbe = nil
  return true
end

-- Screen-space proofs cannot survive a drawable resize. In particular a
-- spent pending-HUD allowance from portrait must not prevent the first
-- landscape render from publishing its new head receipts during an attack.
-- Keep gameplay, camera pose and zoom; invalidate only the old screen proof.
function BattleCam.noteViewport(w, h)
  if not (type(w) == "number" and type(h) == "number"
      and w > 0 and h > 0 and w < math.huge and h < math.huge) then return false end
  local changed = BattleCam.viewportW ~= nil
    and (BattleCam.viewportW ~= w or BattleCam.viewportH ~= h)
  BattleCam.viewportW, BattleCam.viewportH = w, h
  if not changed then return false end
  lastScreenSafe, pendingScreenProbe = nil, nil
  BattleCam.staticSafetyArena, BattleCam.staticSafetySeat = nil, nil
  BattleCam.directorPathArena = nil
  BattleCam.directorPathProven = false
  BattleCam.directorPathLegs = 0
  BattleCam.directorSafetyProbeAt = 0
  BattleCam.directorSafeEye, BattleCam.directorSafeFocus = nil, nil
  BattleCam.directorSafeCutSerial = -1
  return true
end

function BattleCam.arenaDirectorEnabled(arena)
  local physical = arena and arena.map and not arena.discs
  return arena and (not arena.discs or authoredArena(arena))
         and BattleCam.arenaDirectorSelected()
         and not (BattleCam.staticSafetySeat
                  and rawequal(BattleCam.staticSafetyArena, arena))
         -- A physical camera does not begin moving on the optimistic first
         -- frame.  Its complete route is inspected and latched first; until
         -- that succeeds the reviewed home composition stays motionless.
         and (not physical or rawequal(BattleCam.directorPathArena, arena))
         and BattleCam.steerable and not BattleCam.still
end

local function wantedDistance()
  return math.max(1, math.min(BattleCam.ZOOM_MAX,
    tonumber(BattleCam.distanceSetting:get()) or BattleCam.DEFAULT_DISTANCE))
end

-- Public for recentering and explicit option changes. Ordinary frames never
-- force the saved rung over the player's fine session-local zoom.
function BattleCam.applyDistanceSetting(force)
  local wanted = wantedDistance()
  if not force and appliedDistance == wanted then return false end
  BattleCam.zoom, BattleCam.zoomGoal = wanted, wanted
  appliedDistance = wanted
  return true
end

-- The distance actually used to compose this frame. ARENA starts from its 3X
-- master but keeps the live lens after direct input.
function BattleCam.presentationDistance(arena)
  if authoredArena(arena) then return BattleCam.zoom end
  BattleCam.applyDistanceSetting(false)
  return math.max(BattleCam.zoom, BattleCam.presentationFit)
end

-- Whether the player may steer at all. The active player-side BACK setting
-- clears it: that setting pins the trainer or Pokemon to the GB slot instead
-- of standing it out on the map, so
-- half the picture is nailed to the frame and half of it is geometry. Swing
-- the camera under that and the two halves come apart -- the foe walks
-- around an arena its opponent is not standing in, and the move animations
-- that reach between them stretch across the gap. There is no angle that
-- composition survives, so the answer is not to allow one.
--
-- Only the STEER is withheld: the slow drift stays, because it was always
-- there under a pinned back sprite and two degrees is not a composition problem.
BattleCam.steerable = true

-- Hold the rig perfectly still (VR sets this while a session runs). The
-- drift exists to give a FLAT screen the depth cue the picture cannot
-- have; a headset gets real parallax from the player's own head, and a
-- picture that sways on its own inside VR reads as the world lurching --
-- on the floating panel especially, where the battle screen is watched
-- from a fixed seat.
BattleCam.still = false

BattleCam.t = 0

-- STADIUM is a shot director, not ambient drift.  ARENA+STADIUM prefers a real
-- map arena (OverworldBattle.stageFor), then uses a deterministic, comfort-led
-- language: short moves followed by long holds, enemy/player portraits,
-- shoulder views and a segmented slow orbit. The authored painting remains a fallback, where the
-- same subject cuts run with a bounded angle because that backdrop is flat.
-- A manual camera input wins temporarily. The automatic timeline pauses and
-- later continues around the user's persistent orbit/pitch basis.
BattleCam.DIRECTOR_MANUAL_HOLD = 4.0
BattleCam.DIRECTOR_ESTABLISH = 3.0
BattleCam.DIRECTOR_TIME = 1.15
BattleCam.DIRECTOR_CYCLE = 60.0
BattleCam.DIRECTOR_ORBIT_MOVE = 6.0
BattleCam.DIRECTOR_ORBIT_HOLD = 2.0
-- A physical STADIUM path is deliberately slower than the old semantic shot
-- sequence.  It advances in one direction only, then rests at a waypoint.
-- The complete 360-degree corridor is preflighted before any of these legs
-- may run, so there is never a frame-time choice between two camera seats.
BattleCam.DIRECTOR_PATH_ESTABLISH = 4.0
BattleCam.DIRECTOR_PATH_MOVE = 8.0
BattleCam.DIRECTOR_PATH_HOLD = 4.0
BattleCam.DIRECTOR_PATH_STEP = math.rad(40)
BattleCam.DIRECTOR_PATH_MAX_YAW_RATE =
  1.5 * BattleCam.DIRECTOR_PATH_STEP / BattleCam.DIRECTOR_PATH_MOVE
BattleCam.DIRECTOR_MAX_YAW_RATE = math.rad(24)
-- Automatic STADIUM motion is intentionally much gentler on the vertical
-- axis than the player's manual camera.  Twelve degrees is enough to reveal
-- arena depth without turning a battle into a steep crane shot; rate and
-- acceleration caps apply across semantic shot changes as well as within a
-- phrase, so a new attacker/target can never teleport the viewer vertically.
BattleCam.DIRECTOR_MAX_LIFT = math.rad(12)
BattleCam.DIRECTOR_MAX_LIFT_RATE = math.rad(8)
BattleCam.DIRECTOR_MAX_YAW_ACCEL = math.rad(48)
BattleCam.DIRECTOR_MAX_LIFT_ACCEL = math.rad(24)
BattleCam.DIRECTOR_ACTOR_H = 16
-- Keep both-combatant shots above the command/text furniture.  The original
-- five/six-pixel world lift landed dense fronts and rears directly on the
-- menu's upper rule; high-resolution Mega cards then lost their feet behind
-- it even though the fixed 3X composition was clear.  Subject portraits keep
-- their own focus, while shared establishing/orbit shots use this safe cap.
BattleCam.DIRECTOR_BOTH_FOCUS_Y = 0
-- Trainer introductions still share the lower text/command safe area even
-- though the director calls them a one-side portrait.  The old .58/.78 close
-- lens enlarged HD trainer cards to almost twice their fixed-3X size and put
-- their feet behind the dialogue frame.  Keep an intentional approach, but
-- no closer than a readable full-body shot and aim at the same safe ground
-- band used by the two-combatant compositions.
BattleCam.DIRECTOR_TRAINER_FOCUS_Y = -4
BattleCam.DIRECTOR_TRAINER_FRAME = .96
BattleCam.DIRECTOR_TRAINER_DOLLY = 1
BattleCam.DIRECTOR_SAFETY_HOLD = 2.0
BattleCam.DIRECTOR_SAFETY_PROBE = 0.12
BattleCam.directorClock = 0
BattleCam.directorAutoClock = 0
BattleCam.directorManualUntil = 0
BattleCam.directorYaw, BattleCam.directorYawGoal = 0, 0
BattleCam.directorLift, BattleCam.directorLiftGoal = 0, 0
BattleCam.directorYawVelocity, BattleCam.directorLiftVelocity = 0, 0
BattleCam.directorFocus, BattleCam.directorFocusGoal = 0, 0
BattleCam.directorFocusY, BattleCam.directorFocusYGoal = 0, 0
BattleCam.directorFrame, BattleCam.directorFrameGoal = 1, 1
BattleCam.directorDolly, BattleCam.directorDollyGoal = 1, 1
BattleCam.directorSafetyYaw, BattleCam.directorSafetyYawGoal = 0, 0
BattleCam.directorSafetyLift, BattleCam.directorSafetyLiftGoal = 0, 0
BattleCam.directorSafetyYawVelocity = 0
BattleCam.directorSafetyLiftVelocity = 0
BattleCam.directorSafetyFrame, BattleCam.directorSafetyFrameGoal = 1, 1
BattleCam.directorSafetyDolly, BattleCam.directorSafetyDollyGoal = 1, 1
BattleCam.directorSafetyUntil = 0
BattleCam.directorSafetyProbeAt = 0
BattleCam.directorShot, BattleCam.directorSubject = "opening", "both"
BattleCam.directorActionToken, BattleCam.directorActionAge = nil, 0
BattleCam.directorCutSerial = 0
BattleCam.directorSafeEye, BattleCam.directorSafeFocus = nil, nil
BattleCam.directorSafeCutSerial = -1
BattleCam.directorPathArena = nil
BattleCam.directorPathProven = false
BattleCam.directorPathDirection = 1
BattleCam.directorPathLegs = 0

-- Only the DRIFT's phase, so every fight opens on the same breath. Where
-- the player last put the camera is deliberately NOT reset: an angle and a
-- lens they chose are how they want to watch battles, not a thing about
-- this battle, and having to re-find them every encounter would make them
-- not worth setting. They are session state -- a fresh run opens on the
-- rig's own shot, which is the one the composition is solved for.
function BattleCam.reset()
  BattleCam.viewportW, BattleCam.viewportH = nil, nil
  local leftAuthoredArena = authoredArena(activeArena)
                            or activeArena and activeArena.stadiumDirector
  BattleCam.t = 0
  BattleCam.directorClock = 0
  BattleCam.directorAutoClock = 0
  BattleCam.directorManualUntil = 0
  BattleCam.directorYaw, BattleCam.directorYawGoal = 0, 0
  BattleCam.directorLift, BattleCam.directorLiftGoal = 0, 0
  BattleCam.directorYawVelocity, BattleCam.directorLiftVelocity = 0, 0
  BattleCam.directorFocus, BattleCam.directorFocusGoal = 0, 0
  BattleCam.directorFocusY, BattleCam.directorFocusYGoal = 0, 0
  BattleCam.directorFrame, BattleCam.directorFrameGoal = 1, 1
  BattleCam.directorDolly, BattleCam.directorDollyGoal = 1, 1
  BattleCam.directorSafetyYaw, BattleCam.directorSafetyYawGoal = 0, 0
  BattleCam.directorSafetyLift, BattleCam.directorSafetyLiftGoal = 0, 0
  BattleCam.directorSafetyYawVelocity = 0
  BattleCam.directorSafetyLiftVelocity = 0
  BattleCam.directorSafetyFrame, BattleCam.directorSafetyFrameGoal = 1, 1
  BattleCam.directorSafetyDolly, BattleCam.directorSafetyDollyGoal = 1, 1
  BattleCam.directorSafetyUntil = 0
  BattleCam.directorSafetyProbeAt = 0
  BattleCam.directorShot, BattleCam.directorSubject = "opening", "both"
  BattleCam.directorActionToken, BattleCam.directorActionAge = nil, 0
  BattleCam.directorCutSerial = 0
  BattleCam.directorSafeEye, BattleCam.directorSafeFocus = nil, nil
  BattleCam.directorSafeCutSerial = -1
  BattleCam.directorPathArena = nil
  BattleCam.directorPathProven = false
  BattleCam.directorPathDirection = 1
  BattleCam.directorPathLegs = 0
  BattleCam.staticSafetySeat, BattleCam.staticSafetyArena = nil, nil
  BattleCam.screenSafetyOK, BattleCam.screenSafetyReason = true, "reset"
  BattleCam.screenSafetyFallbackUsed = false
  activeArena = nil
  activeBattle = nil
  lastScreenSafe = nil
  pendingScreenProbe = nil
  pendingManualRollback = nil
  BattleCam.presentationFit = 1
  -- ARENA temporarily starts from 3X without changing BTL CAM. Re-entering a
  -- MAP/DISCS battle must therefore re-read that saved rung instead of keeping
  -- the previous arena's live lens merely because the option itself did not
  -- change.
  if leftAuthoredArena then appliedDistance = nil end
  BattleCam.applyDistanceSetting(false)
end

-- Back to the solved angle at the player's saved distance, for anything that
-- wants the composition recentred rather than left at its manual steer.
function BattleCam.recentre()
  local moved = BattleCam.orbit ~= 0 or BattleCam.orbitGoal ~= 0
             or BattleCam.pitch ~= 0 or BattleCam.pitchGoal ~= 0
  if moved and not pendingManualRollback then
    pendingManualRollback = {
      orbit=BattleCam.orbit, orbitGoal=BattleCam.orbitGoal,
      pitch=BattleCam.pitch, pitchGoal=BattleCam.pitchGoal,
      zoom=BattleCam.zoom, zoomGoal=BattleCam.zoomGoal,
      manualUntil=BattleCam.directorManualUntil,
    }
  end
  BattleCam.orbit, BattleCam.orbitGoal = 0, 0
  BattleCam.pitch, BattleCam.pitchGoal = 0, 0
  BattleCam.applyDistanceSetting(true)
  return moved
end

-- How far the eye may swing, in radians, before it is square to the arena's
-- axis. The rig's own stance decides it: `side` and `back` are the offset
-- it starts at, so the bearing it starts on is atan2(side, back) and what
-- is left to a quarter turn is the room the player has.
function BattleCam.orbitRange(arena)
  local R = BattleCam.rigFor(arena)
  return math.max(0, math.pi / 2 - math.atan2(R.side, R.back))
end

-- ------- what the player's inputs reach
--
-- All four take a signed amount and clamp; positive is RIGHTWARD, toward
-- the side-on stop. Returning whether the goal actually moved lets a
-- caller tell "steered" from "already against the stop".

-- Both axes go through here, so the "nothing while a BACK row holds the
-- composition" rule and the two stops live in one place each.
local function setAxis(key, goal)
  if not BattleCam.steerable then return false end
  if authoredArena(activeArena) then return false end
  if BattleCam.staticSafetySeat
      and rawequal(BattleCam.staticSafetyArena, activeArena) then return false end
  local was = BattleCam[key]
  local nextValue = math.max(0, math.min(1, goal))
  local changed = nextValue ~= was
  if changed then
    if not pendingManualRollback then
      pendingManualRollback = {
        orbit=BattleCam.orbit, orbitGoal=BattleCam.orbitGoal,
        pitch=BattleCam.pitch, pitchGoal=BattleCam.pitchGoal,
        zoom=BattleCam.zoom, zoomGoal=BattleCam.zoomGoal,
        manualUntil=BattleCam.directorManualUntil,
      }
    end
    BattleCam[key] = nextValue
    BattleCam.directorManualUntil = BattleCam.directorClock
                                    + BattleCam.DIRECTOR_MANUAL_HOLD
  end
  return changed
end

-- A drag, in fractions of the screen's width (orbit) or height (pitch).
function BattleCam.dragOrbit(fraction)
  return setAxis("orbitGoal",
                 BattleCam.orbitGoal + (fraction or 0) * BattleCam.ORBIT_DRAG)
end

function BattleCam.dragPitch(fraction)
  return setAxis("pitchGoal",
                 BattleCam.pitchGoal + (fraction or 0) * BattleCam.PITCH_DRAG)
end

-- Relative mouse motion, in counts.
function BattleCam.mouseOrbit(dx)
  return setAxis("orbitGoal",
                 BattleCam.orbitGoal + (dx or 0) * BattleCam.ORBIT_MOUSE)
end

function BattleCam.mousePitch(dy)
  return setAxis("pitchGoal",
                 BattleCam.pitchGoal + (dy or 0) * BattleCam.PITCH_MOUSE)
end

-- A stick held for `dt` seconds, as a rate with a squared response -- the
-- first half of the throw aims and the rest travels, the same curve the
-- free-roam look uses.
local function curve(v)
  local a = math.abs(v or 0)
  if a < BattleCam.STICK_DEAD then return 0 end
  a = (a - BattleCam.STICK_DEAD) / (1 - BattleCam.STICK_DEAD)
  return ((v < 0) and -1 or 1) * a * a
end

function BattleCam.stickOrbit(x, dt)
  local v = curve(x)
  if v == 0 then return false end
  return setAxis("orbitGoal",
                 BattleCam.orbitGoal + v * BattleCam.ORBIT_STICK * (dt or 0))
end

function BattleCam.stickPitch(y, dt)
  local v = curve(y)
  if v == 0 then return false end
  return setAxis("pitchGoal",
                 BattleCam.pitchGoal + v * BattleCam.PITCH_STICK * (dt or 0))
end

-- The zoom, in notches (positive pulls OUT, like every other zoom here).
function BattleCam.stepZoom(notches, arena)
  if not BattleCam.steerable then return false end
  BattleCam.applyDistanceSetting(false)
  local was = BattleCam.zoomGoal
  local nextValue = math.max(BattleCam.ZOOM_MIN,
                    math.min(BattleCam.ZOOM_MAX,
                      was * (BattleCam.ZOOM_STEP ^ (notches or 0))))
  local changed = nextValue ~= was
  if changed then
    if not pendingManualRollback then
      pendingManualRollback = {
        orbit=BattleCam.orbit, orbitGoal=BattleCam.orbitGoal,
        pitch=BattleCam.pitch, pitchGoal=BattleCam.pitchGoal,
        zoom=BattleCam.zoom, zoomGoal=BattleCam.zoomGoal,
        manualUntil=BattleCam.directorManualUntil,
      }
    end
    BattleCam.zoomGoal = nextValue
    BattleCam.directorManualUntil = BattleCam.directorClock
                                    + BattleCam.DIRECTOR_MANUAL_HOLD
  end
  return changed
end

-- How far apart the two mons READ from the current orbit, as a multiple of
-- how far apart they read from the solved shot.
--
-- The arena's axis runs from one mon to the other, and the solved shot
-- looks along it at a shallow 28 degrees, which foreshortens that gap to
-- less than half its length. Swing round to square-on and the
-- foreshortening is gone: the same two cells now read at their full
-- separation, better than twice as wide. Left alone, that threw the pair
-- out to the edges of the frame -- half of each mon off-screen at the
-- side-on stop, which made the whole far end of the range unusable.
--
-- Climbing does the same thing on the other axis -- a raised camera looks
-- less along the ground and more across it, which un-foreshortens the gap
-- again -- so the correction has to answer to both.
--
-- What it measures is how much of the arena's axis survives projection:
-- the axis runs due north-south, the view line points back at the arena at
-- plan bearing `beta` and elevation `elev`, and the part of a unit axis
-- that lands across the frame rather than along the view is the sine of
-- the angle between them. The ratio of that to the solved shot's own is
-- the factor the lens opens by -- 1 at the solved shot by construction,
-- about 1.9 at side-on, about 1.7 fully raised.
--
-- Analytic rather than measured off the built rig, so nothing has to
-- reason about a camera to ask the question, and so the sun's box (which
-- asks through frameH) gets the identical number the lens does.
--
-- Measured off the STEER alone, deliberately: the drift's own two degrees
-- moved this before and must keep moving it by exactly as much, or every
-- battle shot that has ever been taken shifts.
local function axisSpan(beta, elev)
  local c = math.cos(elev)
  local s = math.sin(beta) * c
  local v = math.sin(elev)
  return math.sqrt(s * s + v * v)
end

function BattleCam.spread(arena)
  local R = BattleCam.rigFor(arena)
  local beta = math.atan2(R.side, R.back)
  local elev = math.atan2(R.height - R.lookY,
                          math.sqrt((R.side - R.lookX) ^ 2 + R.back ^ 2))
  local home = axisSpan(beta, elev)
  if home < 1e-6 then return 1 end
  return axisSpan(beta + BattleCam.orbit * BattleCam.orbitRange(arena),
                  elev + BattleCam.pitch * BattleCam.PITCH_RANGE) / home
end

-- The automatic full orbit is not constrained to the manual camera's
-- quarter-turn range.  When it looks square across the battle axis, the two
-- grounded marks separate almost twice as far as in the solved home shot.
-- Widen only compositions that promise both actors; portraits are allowed to
-- let their non-subject leave the edge, which is what makes them portraits.
function BattleCam.directorSpread(arena)
  if not (BattleCam.arenaDirectorEnabled(arena)
          and BattleCam.directorSubject == "both") then return 1 end
  local R = BattleCam.rigFor(arena)
  local beta = math.atan2(R.side, R.back)
  local elev = math.atan2(R.height - R.lookY,
                          math.sqrt((R.side - R.lookX) ^ 2 + R.back ^ 2))
  local home = axisSpan(beta, elev)
  if home < 1e-6 then return 1 end
  local yaw = BattleCam.directorYaw + BattleCam.directorSafetyYaw
  return math.max(1, axisSpan(beta + yaw,
    elev + BattleCam.directorLift + BattleCam.directorSafetyLift) / home)
end

-- How much world the frame holds right now: the rig's own reach at the
-- player's zoom and at whatever the orbit has done to the pair's spacing.
-- A pinned BACK picture withholds orbit and pitch, but not the saved BTL CAM
-- distance: distance is a framing preference in its own row, and silently
-- snapping 2X/3X back to 1X while that picture was active made the row lie.
-- VR still gets the authored frame because its fixed seat owns the whole
-- camera. The sun's box is fitted to this too, so a zoomed shot lights exactly
-- the ground it shows -- which is why BattleScene asks this rather than
-- multiplying for itself.
function BattleCam.frameH(arena)
  BattleCam.applyDistanceSetting(false)
  local base = BattleCam.rigFor(arena).frameH
  if BattleCam.still then return base end
  -- `rig` ignores the stored orbit/pitch while steering is withheld. Its lens
  -- must ignore their spread too or a stale angle would widen a fixed shot.
  local isAuthored = authoredArena(arena)
  local staticSafety = BattleCam.staticSafetySeat
                       and rawequal(BattleCam.staticSafetyArena, arena)
  local spread = BattleCam.steerable and not isAuthored and not staticSafety
                 and BattleCam.spread(arena) or 1
  local directed = not staticSafety and BattleCam.arenaDirectorEnabled(arena)
  if directed and not isAuthored then
    spread = math.max(spread, BattleCam.directorSpread(arena))
  end
  local frame = staticSafety
    and math.max(.25, tonumber(BattleCam.staticSafetySeat.frame) or 1)
    or directed and BattleCam.directorFrame * BattleCam.directorSafetyFrame
    or 1
  local distance = isAuthored and BattleCam.zoom
                   or math.max(BattleCam.zoom, BattleCam.presentationFit)
  -- A portrait may zoom in, but never crop a large actor below the transient
  -- fit floor BattleScene measured from its visible alpha bounds.
  if directed and not isAuthored and distance * frame < BattleCam.presentationFit then
    frame = BattleCam.presentationFit / math.max(distance, 1e-6)
  end
  return base * distance * spread * frame
end

local function chase(now, goal, dt, time)
  if now == goal then return goal end
  local v = now + (goal - now) * math.min(1, (dt or 0) / time)
  return (math.abs(goal - v) < 1e-4) and goal or v
end

-- Rate limiting alone still starts and stops at full speed.  This small
-- acceleration-bounded chase keeps the camera body's velocity continuous.
-- It is used only by the automatic director; direct/manual input retains its
-- existing responsive easing and becomes the basis around which this chase
-- resumes after the manual hold.
local function chaseComfort(now, goal, velocity, dt, time, maxRate, maxAccel)
  dt = math.max(0, tonumber(dt) or 0)
  if dt <= 0 then return now, velocity or 0 end
  local remaining = goal - now
  if math.abs(remaining) < 1e-6 then return goal, 0 end
  local desired = math.max(-maxRate, math.min(maxRate,
    remaining / math.max(time or 1, 1e-6)))
  velocity = tonumber(velocity) or 0
  local dv = math.max(-maxAccel * dt,
                      math.min(maxAccel * dt, desired - velocity))
  velocity = math.max(-maxRate, math.min(maxRate, velocity + dv))
  local step = velocity * dt
  if math.abs(step) >= math.abs(remaining)
      and step * remaining >= 0 then return goal, 0 end
  return now + step, velocity
end

local function smooth(t)
  t = math.max(0, math.min(1, t or 0))
  return t * t * (3 - 2 * t)
end

local function between(a, b, t)
  return a + (b - a) * smooth(t)
end

local function directorPhrase(clock, arena, battle, actionToken, actionAge)
  local shot, subject = "opening", "both"
  local yaw, lift, focus, focusY, frame, dolly = 0, 0, 0, 5, 1, 1

  -- Trainer cards and wild opponents receive an intentional opening portrait
  -- before the passive cycle begins.  These flags are the engine's real
  -- presentation lifecycle, so a fast or skipped intro never leaves the
  -- camera waiting for a timer the battle has already moved past.
  if battle and battle.showEnemyTrainer and battle.trainerPic then
    -- VASC stages both trainer cards on the world marks.  Treating this as an
    -- enemy-only portrait enlarged the foe but pushed the player's full body
    -- below the text frame.  It is therefore a shared full-body intro shot.
    shot, subject = "trainer-intro", "both"
    yaw, lift, focus, focusY, frame, dolly = math.rad(-12), math.rad(5),
      0, BattleCam.DIRECTOR_TRAINER_FOCUS_Y,
      BattleCam.DIRECTOR_TRAINER_FRAME, BattleCam.DIRECTOR_TRAINER_DOLLY
  elseif battle and battle.showPlayerBack and battle.playerBackPic then
    shot, subject = "player-trainer-intro", "both"
    yaw, lift, focus, focusY, frame, dolly = math.rad(8), math.rad(5),
      0, BattleCam.DIRECTOR_TRAINER_FOCUS_Y,
      BattleCam.DIRECTOR_TRAINER_FRAME, BattleCam.DIRECTOR_TRAINER_DOLLY
  elseif actionToken then
    local attacker = battle and battle.animAttackerIsPlayer and 1 or -1
    local firstBeat = actionAge < .32
    local side = firstBeat and attacker or -attacker
    shot = firstBeat and "attack-launch" or "attack-impact"
    subject = side > 0 and "player" or "enemy"
    focus = side * 20
    yaw = side * math.rad(firstBeat and 10 or 18)
    lift, focusY = math.rad(firstBeat and 3 or 6), 7
    frame, dolly = firstBeat and .62 or .54, firstBeat and .82 or .72
  elseif clock < BattleCam.DIRECTOR_ESTABLISH then
    -- Wild battles have no trainer card to introduce, so the first readable
    -- subject is the wild Pokemon itself.  Trainer battles whose card already
    -- left the frame settle briefly on both send-out marks.
    local wild = battle and battle.kind == "wild"
    shot, subject = wild and "wild-intro" or "opening", wild and "enemy" or "both"
    local u = clock / BattleCam.DIRECTOR_ESTABLISH
    yaw = between(math.rad(-16), math.rad(4), u)
    lift = between(math.rad(10), math.rad(4), u)
    focus, focusY = wild and -20 or 0, wild and 7 or 5
    frame, dolly = wild and between(.72, .58, u) or 1, wild and .82 or 1
  else
    local elapsed = clock - BattleCam.DIRECTOR_ESTABLISH
    local cycle = math.floor(elapsed / BattleCam.DIRECTOR_CYCLE)
    local t = elapsed - cycle * BattleCam.DIRECTOR_CYCLE
    local turn = cycle * math.pi * 2
    if t < 6 then
      -- Move for the first two seconds, then leave the establishing frame alone
      -- long enough to read the field and both combatants.
      local u = math.min(1, t / 2)
      shot, subject = "establish:" .. cycle, "both"
      yaw = turn + between(math.rad(-10), math.rad(8), u)
      lift, focusY = between(math.rad(9), math.rad(3), u), 5
      frame, dolly = .96, 1
    elseif t < 12 then
      local u = math.min(1, (t - 6) / 1.5)
      shot, subject = "enemy-portrait:" .. cycle, "enemy"
      yaw = turn + between(math.rad(-8), math.rad(6), u)
      lift, focus, focusY = math.rad(4), -20, 7
      frame, dolly = between(.64, .58, u), .80
    elseif t < 18 then
      local u = math.min(1, (t - 12) / 1.5)
      shot, subject = "player-portrait:" .. cycle, "player"
      yaw = turn + math.pi + between(math.rad(-8), math.rad(6), u)
      lift, focus, focusY = math.rad(5), 20, 7
      frame, dolly = between(.66, .60, u), .82
    elseif t < 50 then
      -- Four calm quarter-orbits. Each travels for six seconds at no more than
      -- 24 degrees/sec, then holds completely still for two seconds. This keeps
      -- the promised full revolution without the permanent merry-go-round.
      local orbitT = t - 18
      local legTime = BattleCam.DIRECTOR_ORBIT_MOVE
                      + BattleCam.DIRECTOR_ORBIT_HOLD
      local leg = math.min(3, math.floor(orbitT / legTime))
      local localT = orbitT - leg * legTime
      local u = math.min(1, localT / BattleCam.DIRECTOR_ORBIT_MOVE)
      local holding = localT >= BattleCam.DIRECTOR_ORBIT_MOVE
      shot = (holding and "orbit-hold:" or "orbit-move:")
             .. leg .. ":" .. cycle
      subject = "both"
      yaw = turn + leg * math.pi / 2 + between(0, math.pi / 2, u)
      lift = math.rad(5 + 5 * math.sin((leg + u) * math.pi / 2))
      focus, focusY, frame, dolly = 0, 6, .80, .92
    elseif t < 55 then
      local u = math.min(1, (t - 50) / 1.5)
      shot, subject = "behind-player:" .. cycle, "player"
      yaw = turn + between(math.rad(-5), math.rad(5), u)
      lift, focus, focusY = math.rad(3), 17, 6
      frame, dolly = .64, .80
    else
      local u = math.min(1, (t - 55) / 1.5)
      shot, subject = "behind-enemy:" .. cycle, "enemy"
      yaw = turn + math.pi + between(math.rad(-5), math.rad(5), u)
      lift, focus, focusY = math.rad(4), -17, 6
      frame, dolly = .64, .80
    end
  end

  if authoredArena(arena) then
    -- A painted ARENA fallback is already a complete screen-space
    -- composition. Moving the world camera under that fixed painting changes
    -- only the projected battlers: they appear to grow/shrink while the arena
    -- itself stays still. Keep the SMART option for real Voxel terrain, but
    -- make its portable painting fallback optically identical to the reviewed
    -- static shot. Manual optical zoom remains available through `zoom`.
    shot, subject = "authored-static", "both"
    yaw, lift, focus, focusY, frame, dolly = 0, 0, 0, 0, 1, 1
  end
  if subject == "both" then
    focusY = math.min(focusY, BattleCam.DIRECTOR_BOTH_FOCUS_Y)
  end
  lift = math.max(-BattleCam.DIRECTOR_MAX_LIFT,
                  math.min(BattleCam.DIRECTOR_MAX_LIFT, lift))
  return shot, subject, yaw, lift, focus, focusY, frame, dolly
end

-- Physical MAP/ARENA cameras use the route that inspectStaticSafety proved
-- before presentation began.  Unlike the screen-space director above, this
-- path never cuts from attacker to target (which can reverse the world eye)
-- and never recomputes a direction from the current battle message.  Each
-- waypoint is approached monotonically with a smooth start/stop and then held
-- exactly.  Combat remains dynamic around the camera; the camera itself only
-- travels when its preflighted path says it can.
local function physicalDirectorPhrase(clock)
  local establish = BattleCam.DIRECTOR_PATH_ESTABLISH
  if clock < establish then
    return "path-establish", "both", 0, 0, 0,
           BattleCam.DIRECTOR_BOTH_FOCUS_Y, 1, 1
  end

  local legTime = BattleCam.DIRECTOR_PATH_MOVE
                  + BattleCam.DIRECTOR_PATH_HOLD
  local elapsed = clock - establish
  local leg = math.floor(elapsed / legTime)
  local legs = math.max(0, tonumber(BattleCam.directorPathLegs) or 0)
  local direction = BattleCam.directorPathDirection == -1 and -1 or 1
  if leg >= legs then
    local yaw = direction * legs * BattleCam.DIRECTOR_PATH_STEP
    return "path-final-hold", "both", yaw, 0, 0,
           BattleCam.DIRECTOR_BOTH_FOCUS_Y, 1, 1
  end
  local localT = elapsed - leg * legTime
  local moving = localT < BattleCam.DIRECTOR_PATH_MOVE
  local u = moving and localT / BattleCam.DIRECTOR_PATH_MOVE or 1
  local startYaw = direction * leg * BattleCam.DIRECTOR_PATH_STEP
  local yaw = startYaw + direction
              * between(0, BattleCam.DIRECTOR_PATH_STEP, u)
  local shot = (moving and "path-move:" or "path-hold:") .. tostring(leg)
  return shot, "both", yaw, 0, 0,
         BattleCam.DIRECTOR_BOTH_FOCUS_Y, 1, 1
end

local function raisedEye(eye, focus, lift)
  if not (lift and lift > 0) then return eye end
  local vx, vy, vz = eye[1] - focus[1], eye[2] - focus[2], eye[3] - focus[3]
  local flat = math.sqrt(vx * vx + vz * vz)
  local radius = math.sqrt(flat * flat + vy * vy)
  if flat <= 1e-6 or radius <= 1e-6 then return eye end
  local angle = math.min(math.atan2(vy, flat) + lift, math.rad(85))
  local nextFlat = radius * math.cos(angle)
  return {
    focus[1] + vx / flat * nextFlat,
    focus[2] + radius * math.sin(angle),
    focus[3] + vz / flat * nextFlat,
  }
end

-- Arena geometry is authored in one canonical north/south frame. A small
-- number of physical encounters run across a room instead; rotate the whole
-- rig basis with the staged combatants instead of adding map-name camera
-- exceptions. A missing value is the historical zero-yaw contract.
local function arenaVector(arena, x, z)
  local yaw = tonumber(arena and arena.axisYaw) or 0
  if yaw == 0 then return x, z end
  local c, s = math.cos(yaw), math.sin(yaw)
  return x * c - z * s, x * s + z * c
end

local function safetyCandidate(arena, groundY, yawOffset, liftOffset,
                               dollyScale, currentPose)
  local R = BattleCam.rigFor(arena)
  local mx, mz = arena.mid[1], arena.mid[2]
  -- Automatic movement resumes around the player's persistent manual basis.
  -- Safety must inspect that same composite bearing, not the pre-input camera.
  -- Authored screen-space ARENA locks manual steer in rig().  A stale MAP
  -- orbit/pitch is still retained as the player's next MAP preference, so the
  -- safety probe must ignore it here as well or it approves a different eye
  -- from the one that will actually be rendered.
  local isAuthored = authoredArena(arena)
  local steer = isAuthored and 0
                or -BattleCam.orbit * BattleCam.orbitRange(arena)
  local directorYaw = currentPose and BattleCam.directorYaw
                      or BattleCam.directorYawGoal
  local directorLift = currentPose and BattleCam.directorLift
                       or BattleCam.directorLiftGoal
  local directorFocus = currentPose and BattleCam.directorFocus
                        or BattleCam.directorFocusGoal
  local directorFocusY = currentPose and BattleCam.directorFocusY
                         or BattleCam.directorFocusYGoal
  local directorDolly = currentPose and BattleCam.directorDolly
                        or BattleCam.directorDollyGoal
  local yaw = steer + directorYaw + (yawOffset or 0)
  local c, s = math.cos(yaw), math.sin(yaw)
  local k = directorDolly * (dollyScale or 1)
  local dx, dz = arenaVector(arena,
    (R.side * c - R.back * s) * k,
    (R.side * s + R.back * c) * k)
  local eye = {
    mx + dx,
    groundY + R.height * k,
    mz + dz,
  }
  local fx, fz = arenaVector(arena, R.lookX, directorFocus)
  local focus = { mx + fx,
    groundY + R.lookY + directorFocusY,
    mz + fz }
  local automaticLift = directorLift + (liftOffset or 0)
  automaticLift = math.max(-BattleCam.DIRECTOR_MAX_LIFT,
                  math.min(BattleCam.DIRECTOR_MAX_LIFT, automaticLift))
  local lift = (isAuthored and 0
                or BattleCam.pitch * BattleCam.PITCH_RANGE) + automaticLift
  eye = raisedEye(eye, focus, lift)
  return eye, focus, yaw,
         lift
end

local function visibilityScore(BattleArena, map, arena, eye, groundY, subject)
  if not BattleArena.cameraClear(map, eye) then return -1, false end
  local player = BattleArena.visibility(map, eye, arena.player, groundY,
                                        BattleCam.DIRECTOR_ACTOR_H)
  local enemy = BattleArena.visibility(map, eye, arena.enemy, groundY,
                                       BattleCam.DIRECTOR_ACTOR_H)
  local readable
  if subject == "player" then readable = player >= 2
  elseif subject == "enemy" then readable = enemy >= 2
  else readable = player >= 2 and enemy >= 2 end
  return player + enemy, readable
end

local function travelClear(BattleArena, map, fromEye, toEye)
  if type(BattleArena.cameraPathClear) ~= "function" then return true end
  return BattleArena.cameraPathClear(map, fromEye, toEye)
end

local function staticSeatEye(arena, groundY, seat)
  local R = BattleCam.rigFor(arena)
  local mx, mz = arena.mid[1], arena.mid[2]
  local yaw, k = seat.yaw or 0, seat.dolly or 1
  local c, s = math.cos(yaw), math.sin(yaw)
  local dx, dz = arenaVector(arena,
    (R.side * c - R.back * s) * k,
    (R.side * s + R.back * c) * k)
  local fx, fz = arenaVector(arena, R.lookX, 0)
  local focus = { mx + fx, groundY + R.lookY, mz + fz }
  local eye = {
    mx + dx,
    groundY + R.height * k,
    mz + dz,
  }
  return raisedEye(eye, focus, seat.lift or 0), focus
end

local function candidateSpread(arena, yaw, lift, subject)
  if subject ~= "both" then return 1 end
  local R = BattleCam.rigFor(arena)
  local beta = math.atan2(R.side, R.back)
  local elev = math.atan2(R.height - R.lookY,
                          math.sqrt((R.side - R.lookX) ^ 2 + R.back ^ 2))
  local home = axisSpan(beta, elev)
  if home < 1e-6 then return 1 end
  return math.max(1, axisSpan(beta + (yaw or 0), elev + (lift or 0)) / home)
end

-- Build the same lens record BattleScene will receive, but without touching
-- Voxel3D's live camera.  The HUD evaluator can therefore project a candidate
-- seat before any pixels are rendered.
local function screenCandidate(arena, eye, focus, context)
  if not (eye and focus) then return nil end
  context = context or {}
  local dx, dy, dz = eye[1] - focus[1], eye[2] - focus[2],
                     eye[3] - focus[3]
  local dist = math.max(1, math.sqrt(dx * dx + dy * dy + dz * dz))
  local distance = authoredArena(arena) and BattleCam.zoom
    or math.max(BattleCam.zoom, BattleCam.presentationFit)
  local staticSeat = context.staticSeat == true
  -- frameH() deliberately leaves authored paintings at spread=1; their lens
  -- is composed against the fixed clearing, not the off-axis world span.
  local spread = (staticSeat or authoredArena(arena)) and 1
    or candidateSpread(
      arena, context.absoluteYaw, context.absoluteLift, context.subject)
  local frame = staticSeat and 1 or tonumber(context.directorFrame) or 1
  local safetyFrame = tonumber(context.safetyFrame) or 1
  local combinedFrame = frame * safetyFrame
  if BattleCam.arenaDirectorEnabled(arena) and not authoredArena(arena)
      and distance * combinedFrame < BattleCam.presentationFit then
    combinedFrame = BattleCam.presentationFit / math.max(distance, 1e-6)
  end
  local frameH = BattleCam.rigFor(arena).frameH * distance * spread
                 * combinedFrame
  return {
    eye={ eye[1], eye[2], eye[3] },
    focus={ focus[1], focus[2], focus[3] },
    fov=2 * math.atan((frameH / 2) / dist),
    curve=0,
  }
end

local function screenSafeCamera(battle, arena, groundY, camera, context)
  if type(screenSafetyEvaluator) ~= "function" then
    return true, "not-configured"
  end
  if not camera then return nil, "camera-unavailable" end
  local ok, safe, reason = pcall(screenSafetyEvaluator, battle, arena,
                                 groundY, camera, context or {})
  if not ok then return nil, "evaluator-error:" .. tostring(safe) end
  if safe == nil then return nil, reason or "bounds-unavailable" end
  return safe == true, reason
end

local function screenSafe(battle, arena, groundY, eye, focus, context)
  return screenSafeCamera(battle, arena, groundY,
    screenCandidate(arena, eye, focus, context), context)
end

local function copyCamera(camera)
  if not camera then return nil end
  return {
    eye={ camera.eye[1], camera.eye[2], camera.eye[3] },
    focus={ camera.focus[1], camera.focus[2], camera.focus[3] },
    up=camera.up and { camera.up[1], camera.up[2], camera.up[3] } or nil,
    fov=camera.fov, curve=camera.curve,
  }
end

local function rollbackManualInput()
  local saved = pendingManualRollback
  if not saved then return false end
  BattleCam.orbit, BattleCam.orbitGoal = saved.orbit, saved.orbitGoal
  BattleCam.pitch, BattleCam.pitchGoal = saved.pitch, saved.pitchGoal
  BattleCam.zoom, BattleCam.zoomGoal = saved.zoom, saved.zoomGoal
  BattleCam.directorManualUntil = saved.manualUntil
  pendingManualRollback = nil
  return true
end

local function manualInputSettled()
  return math.abs(BattleCam.orbit - BattleCam.orbitGoal) < 1e-4
     and math.abs(BattleCam.pitch - BattleCam.pitchGoal) < 1e-4
     and math.abs(BattleCam.zoom - BattleCam.zoomGoal) < 1e-4
end

local function sameScreenOwner(record, arena, battle)
  return record ~= nil and rawequal(record.arena, arena)
         and rawequal(record.battle, battle)
end

local function consumePendingScreenFrame(arena, battle, camera, pitch)
  local pending = pendingScreenProbe
  if not sameScreenOwner(pending, arena, battle) then
    pending = { arena=arena, battle=battle, frames=0 }
    pendingScreenProbe = pending
  end
  if pending.frames >= SCREEN_PENDING_FRAME_BUDGET then return false end
  pending.frames = pending.frames + 1
  pending.camera = copyCamera(camera)
  pending.pitch = pitch
  return true
end

local function exhaustPendingScreenFrames(arena, battle)
  if not sameScreenOwner(pendingScreenProbe, arena, battle) then
    pendingScreenProbe = { arena=arena, battle=battle,
                           frames=SCREEN_PENDING_FRAME_BUDGET }
  else
    pendingScreenProbe.frames = SCREEN_PENDING_FRAME_BUDGET
  end
end

local function freezeRejectedDirectorPath(arena)
  if not rawequal(BattleCam.directorPathArena, arena) then return end
  BattleCam.staticSafetyArena = arena
  BattleCam.staticSafetySeat = {
    yaw=BattleCam.directorYaw, lift=BattleCam.directorLift,
    dolly=BattleCam.directorDolly, frame=BattleCam.directorFrame,
    reason="latched-path-invalidated",
  }
  BattleCam.directorPathArena = nil
  BattleCam.directorPathProven = false
  BattleCam.directorPathLegs = 0
  BattleCam.directorYawVelocity, BattleCam.directorLiftVelocity = 0, 0
  BattleCam.directorSafetyYawVelocity = 0
  BattleCam.directorSafetyLiftVelocity = 0
end

local function returnRevalidatedScreenCamera(
    arena, camera, pitch, reason, rejectedPath)
  if rejectedPath then freezeRejectedDirectorPath(arena) end
  BattleCam.screenSafetyOK = true
  BattleCam.screenSafetyReason = reason
  BattleCam.screenSafetyFallbackUsed = false
  return copyCamera(camera), pitch
end

-- A phone can expose substantially more rows than the GB-shaped camera solve
-- anticipated.  The ordinary director safety pass widens its *goal*, but the
-- eased camera presented in this frame can still be the old narrow lens.  On
-- the first battle frame there is no previous safe camera to return, so that
-- one-frame mismatch used to reject an otherwise healthy MAP scene and latch
-- the complete native 2-D battle for the rest of the encounter.
--
-- Recover only the two definitive actor-envelope failures observed at the
-- rendered boundary, only for a physical MAP, and only by widening the exact
-- same eye/focus lens.  HUD collisions, malformed provider bounds, world
-- clearance and manual-camera failures retain their fail-closed behaviour.
local function renderedActorFrameRescue(arena, groundY, camera, pitch, reason,
                                        context)
  if not (arena and arena.map and not arena.discs and camera
      and type(reason) == "string"
      and (reason == "player-outside-safe-frame"
        or reason == "enemy-outside-safe-frame")) then
    return nil
  end
  if context and context.manual then return nil end
  local base = tonumber(camera.fov)
  if not (base and base > 0 and base < math.pi) then return nil end
  local tangent = math.tan(base * .5)
  -- Do not turn a transient phone/HUD reflow into a nearly orthographic,
  -- postage-stamp battle. Wider layouts are retried by the owner transaction;
  -- this one-frame rescue remains inside a comfortable 1.75x optical bound.
  for _, factor in ipairs({ 1.15, 1.30, 1.45, 1.60, 1.75 }) do
    local candidate = copyCamera(camera)
    candidate.fov = 2 * math.atan(tangent * factor)
    local safe, safeReason = screenSafeCamera(
      activeBattle, arena, groundY, candidate, {
        phase="rendered-actor-frame-rescue",
        shot=BattleCam.directorShot, subject=BattleCam.directorSubject,
        actual=true, opticalOnly=true, safetyFrame=factor,
      })
    if safe == true then
      pendingScreenProbe = nil
      lastScreenSafe = {
        arena=arena, battle=activeBattle,
        camera=copyCamera(candidate), pitch=pitch,
      }
      BattleCam.screenSafetyOK = true
      BattleCam.screenSafetyReason = "rendered-optical-rescue:"
        .. tostring(safeReason or reason)
      BattleCam.screenSafetyFallbackUsed = true
      return candidate, pitch
    end
  end
  return nil
end

-- Definitive provider-neutral safety gate for the camera that will actually
-- be rendered. Candidate search is deliberately allowed to be approximate;
-- this check runs after easing and after the physical-world fallback in rig,
-- against the exact pre-letterbox camera consumed by BattleScene. An unsafe
-- frame reuses a still-valid previous camera or declines the voxel shot for
-- this frame. It is never allowed to leak through merely because a probe was
-- throttled or the player currently owns the camera.
local function guardRenderedCamera(arena, groundY, camera, pitch, canonical)
  if canonical or activeBattle == nil
      or type(screenSafetyEvaluator) ~= "function" then
    return camera, pitch
  end
  if not rawequal(activeArena, arena) then
    BattleCam.screenSafetyOK = false
    BattleCam.screenSafetyReason = "rendered-owner-mismatch"
    BattleCam.screenSafetyFallbackUsed = false
    return nil, nil
  end
  local context = {
    phase="rendered-final", shot=BattleCam.directorShot,
    subject=BattleCam.directorSubject, actual=true,
    manual=BattleCam.directorClock < BattleCam.directorManualUntil,
  }
  local safe, reason = screenSafeCamera(
    activeBattle, arena, groundY, camera, context)
  if safe == true then
    pendingScreenProbe = nil
    lastScreenSafe = {
      arena=arena, battle=activeBattle, camera=copyCamera(camera), pitch=pitch,
    }
    BattleCam.screenSafetyOK = true
    BattleCam.screenSafetyReason = reason or "rendered-safe"
    BattleCam.screenSafetyFallbackUsed = false
    if pendingManualRollback and manualInputSettled() then
      pendingManualRollback = nil
    end
    return camera, pitch
  end

  if safe == false then
    local rescued, rescuedPitch = renderedActorFrameRescue(
      arena, groundY, camera, pitch, reason, context)
    if rescued then return rescued, rescuedPitch end
  end

  if safe == false
      or (safe == nil and reason ~= "owner-render-pending") then
    -- A rejected/erroring current camera cannot be followed by a provisional
    -- frame until this exact owner produces a rendered-final safe verdict.
    exhaustPendingScreenFrames(arena, activeBattle)
  end
  local manualRolledBack = rollbackManualInput()
  local previous = lastScreenSafe
  local matchingPrevious = sameScreenOwner(previous, arena, activeBattle)
  local rollbackSafe = nil
  local rollbackReason = nil
  if matchingPrevious then
    rollbackSafe, rollbackReason = screenSafeCamera(
      activeBattle, arena, groundY, previous.camera, {
        phase="rendered-rollback", shot=BattleCam.directorShot,
        subject=BattleCam.directorSubject, actual=true,
      })
  end

  -- Re-evaluate the exact camera which consumed the provisional receipt. It
  -- may become last-safe only after this independent check. Keep the budget
  -- spent even on success: only a safe live candidate may re-arm motion, so a
  -- provider which remains pending cannot advance every other frame forever.
  local probe = sameScreenOwner(pendingScreenProbe, arena, activeBattle)
                and pendingScreenProbe or nil
  if probe and probe.camera then
    local probeSafe, probeReason = screenSafeCamera(
      activeBattle, arena, groundY, probe.camera, {
        phase="rendered-pending-recheck", shot=BattleCam.directorShot,
        subject=BattleCam.directorSubject, actual=true,
      })
    if probeSafe == true then
      lastScreenSafe = {
        arena=arena, battle=activeBattle,
        camera=copyCamera(probe.camera), pitch=probe.pitch,
      }
      probe.camera, probe.pitch = nil, nil
      return returnRevalidatedScreenCamera(
        arena, lastScreenSafe.camera, lastScreenSafe.pitch,
        "pending-confirmed:" .. tostring(probeReason or "rendered-safe"),
        safe == false)
    end
  end

  -- Only the exact owner receipt cycle is allowed to publish an unproven live
  -- candidate, and then once. It must run before a safe previous-camera return
  -- or that previous camera can prevent the exact candidate receipt forever.
  -- Manual input is different: first return its revalidated pre-input camera,
  -- then let the next recomputed (rolled-back) candidate consume the budget.
  if safe == nil and reason == "owner-render-pending" then
    if manualRolledBack and rollbackSafe == true then
      return returnRevalidatedScreenCamera(
        arena, previous.camera, previous.pitch,
        "rolled-back:" .. tostring(reason), false)
    end
    local provisional, provisionalPitch = camera, pitch
    if manualRolledBack then
      if matchingPrevious and rollbackSafe == nil
          and rollbackReason == "owner-render-pending" then
        provisional, provisionalPitch = previous.camera, previous.pitch
      else
        BattleCam.screenSafetyOK = false
        BattleCam.screenSafetyReason = "deferred:owner-render-pending"
        BattleCam.screenSafetyFallbackUsed = false
        return nil, nil
      end
    end
    if provisional and consumePendingScreenFrame(
        arena, activeBattle, provisional, provisionalPitch) then
      BattleCam.screenSafetyOK = false
      BattleCam.screenSafetyReason = "transient:owner-render-pending"
      BattleCam.screenSafetyFallbackUsed = false
      return copyCamera(provisional), provisionalPitch
    end
    if rollbackSafe == true then
      return returnRevalidatedScreenCamera(
        arena, previous.camera, previous.pitch,
        "rolled-back:" .. tostring(reason), false)
    end
    BattleCam.screenSafetyOK = false
    BattleCam.screenSafetyReason = "pending-exhausted:owner-render-pending"
    BattleCam.screenSafetyFallbackUsed = false
    return nil, nil
  end

  -- A definitive collision and every non-owner-pending nil verdict block the
  -- provisional budget. Alternating false/error/pending results therefore
  -- cannot expose one unverified frame on every other update.
  exhaustPendingScreenFrames(arena, activeBattle)

  if rollbackSafe == true then
    return returnRevalidatedScreenCamera(
      arena, previous.camera, previous.pitch,
      "rolled-back:" .. tostring(reason or rollbackReason or "unsafe"),
      safe == false)
  end

  -- A physical SMART path is preflighted against the HUD geometry visible at
  -- that time.  Attack/message furniture can be replaced by the command HUD
  -- later in the same battle.  If that new, definitive geometry rejects both
  -- the current camera and the last rendered camera, the old path is no longer
  -- a valid proof.  Drop only that proof so the next update can solve a new
  -- route/static seat while OverworldBattle retains the exact last-good shot.
  -- Tri-state nil means the HUD owner is still publishing its bounds and must
  -- not churn an otherwise valid path.
  if safe == false and rawequal(BattleCam.directorPathArena, arena) then
    BattleCam.staticSafetyArena, BattleCam.staticSafetySeat = nil, nil
    BattleCam.directorPathArena = nil
    BattleCam.directorPathProven = false
    BattleCam.directorPathLegs = 0
    BattleCam.directorAutoClock = 0
    BattleCam.directorYawVelocity, BattleCam.directorLiftVelocity = 0, 0
    BattleCam.directorSafetyYawVelocity = 0
    BattleCam.directorSafetyLiftVelocity = 0
    BattleCam.directorSafetyProbeAt = 0
    BattleCam.directorSafeEye, BattleCam.directorSafeFocus = nil, nil
    BattleCam.directorSafeCutSerial = -1
  end
  BattleCam.screenSafetyOK = false
  BattleCam.screenSafetyReason = reason or "rendered-camera-unsafe"
  BattleCam.screenSafetyFallbackUsed = false
  return nil, nil
end

-- Decide once whether this physical arena has enough free camera space for
-- moving Stadium shots.  Nine bearings provide a conservative room test; a
-- narrow arena is constrained by definition.  If constrained, choose the
-- highest-visibility endpoint from a deterministic list and keep it fixed.
local function inspectStaticSafety(arena, groundY, battle)
  if rawequal(BattleCam.staticSafetyArena, arena) then
    local cached = BattleCam.staticSafetySeat
    if not cached then return end
    local eye, focus = staticSeatEye(arena, groundY, cached)
    local safe, reason = screenSafe(battle, arena, groundY, eye, focus, {
      phase="static-seat-revalidate", shot="static-seat",
      subject="both", absoluteYaw=cached.yaw,
      absoluteLift=cached.lift, directorFrame=1,
      safetyFrame=cached.frame or 1, staticSeat=true,
    })
    if safe == true then return end
    -- Viewport, UI scale, safe insets and rendered actor identity can all
    -- change inside one arena. An arena-only cache must never outlive those
    -- public bounds; discard and solve again instead of rendering the stale
    -- seat underneath a newly latched card.
    BattleCam.staticSafetyArena, BattleCam.staticSafetySeat = nil, nil
    BattleCam.directorPathArena = nil
    BattleCam.directorPathProven = false
    if safe == nil and (reason == "owner-latch-pending"
        or reason == "owner-render-pending") then
      BattleCam.screenSafetyOK = false
      BattleCam.screenSafetyReason = reason
      return
    end
  end
  BattleCam.staticSafetyArena, BattleCam.staticSafetySeat = arena, nil
  BattleCam.directorPathArena = nil
  BattleCam.directorPathProven = false
  BattleCam.directorPathLegs = 0
  if not (arena and arena.map and not arena.discs
          and arena.player and arena.enemy) then return end

  local okArena, BattleArena = pcall(V.require, "BattleArena")
  if not (okArena and BattleArena
          and type(BattleArena.cameraClear) == "function"
          and type(BattleArena.visibility) == "function") then return end

  -- Ordered in the same positive direction the planned path uses.  Index one
  -- is the reviewed home seat; walking the table forward or backward gives us
  -- the two possible non-reversing routes from that seat.
  local bearings, routeSeats = {}, {}
  for index = 0, 8 do
    bearings[#bearings + 1] = index * BattleCam.DIRECTOR_PATH_STEP
  end
  local boundsUnknown = false
  for index, yaw in ipairs(bearings) do
    local seat = { yaw = yaw, lift = 0, dolly = 1 }
    local eye, focus = staticSeatEye(arena, groundY, seat)
    local _, readable = visibilityScore(
      BattleArena, arena.map, arena, eye, groundY, "both")
    local safe, reason = screenSafe(battle, arena, groundY, eye, focus, {
      phase="orbit-seat", shot="orbit-seat", subject="both",
      absoluteYaw=yaw, absoluteLift=0, directorFrame=.80, safetyFrame=1,
    })
    -- VASC's per-battle owner cards are latched from the first real render,
    -- which happens immediately after this update. Do not cache that single
    -- pre-render frame as an unknown-provider static arena; retry next update.
    if safe == nil and (reason == "owner-latch-pending"
        or reason == "owner-render-pending") then
      BattleCam.staticSafetyArena, BattleCam.staticSafetySeat = nil, nil
      BattleCam.screenSafetyOK = false
      BattleCam.screenSafetyReason = reason
      return
    end
    if safe == nil then
      boundsUnknown = true
      BattleCam.screenSafetyReason = reason or "bounds-unavailable"
    end
    routeSeats[index] = {
      yaw=yaw, eye=eye, readable=readable, screenSafe=safe == true,
    }
  end
  local narrow = arena.narrow == true or arena.shape == "narrow"
  -- Find the longest connected, readable, HUD-safe arc from home. It can run
  -- clockwise or anticlockwise, but its direction is chosen once and never
  -- changes. This retains useful motion in a partly open arena without the old
  -- behaviour of steering toward a blocked seat and rolling backward again.
  local function clearLegs(direction)
    if narrow or boundsUnknown
        or type(BattleArena.cameraPathClear) ~= "function" then return 0 end
    local home = routeSeats[1]
    if not (home and home.readable and home.screenSafe) then return 0 end
    local previous, count = home, 0
    for step = 1, #routeSeats - 1 do
      local index = direction > 0 and (step + 1) or (#routeSeats - step + 1)
      local candidate = routeSeats[index]
      if not (candidate and candidate.readable and candidate.screenSafe
          and BattleArena.cameraPathClear(
            arena.map, previous.eye, candidate.eye)) then break end
      count, previous = count + 1, candidate
    end
    return count
  end
  local positiveLegs = clearLegs(1)
  local negativeLegs = clearLegs(-1)
  local pathLegs = math.max(positiveLegs, negativeLegs)
  if pathLegs > 0 then
    BattleCam.directorPathArena = arena
    BattleCam.directorPathProven = true
    BattleCam.directorPathDirection = positiveLegs >= negativeLegs and 1 or -1
    BattleCam.directorPathLegs = pathLegs
    BattleCam.screenSafetyOK = true
    BattleCam.screenSafetyReason = "latched-path-preflight"
    BattleCam.directorSafetyYaw, BattleCam.directorSafetyYawGoal = 0, 0
    BattleCam.directorSafetyLift, BattleCam.directorSafetyLiftGoal = 0, 0
    BattleCam.directorSafetyFrame, BattleCam.directorSafetyFrameGoal = 1, 1
    BattleCam.directorSafetyDolly, BattleCam.directorSafetyDollyGoal = 1, 1
    return
  end

  local candidates = {
    { yaw=0, lift=0, dolly=1, order=1 },
    { yaw= math.rad(14), lift=math.rad(7), dolly=1, order=2 },
    { yaw=-math.rad(14), lift=math.rad(7), dolly=1, order=3 },
    { yaw= math.rad(28), lift=math.rad(12), dolly=1, order=4 },
    { yaw=-math.rad(28), lift=math.rad(12), dolly=1, order=5 },
    { yaw= math.rad(50), lift=math.rad(18), dolly=.92, order=6 },
    { yaw=-math.rad(50), lift=math.rad(18), dolly=.92, order=7 },
    { yaw= math.rad(82), lift=math.rad(26), dolly=.86, order=8 },
    { yaw=-math.rad(82), lift=math.rad(26), dolly=.86, order=9 },
    { yaw= math.rad(120), lift=math.rad(34), dolly=.80, order=10 },
    { yaw=-math.rad(120), lift=math.rad(34), dolly=.80, order=11 },
    { yaw=math.pi, lift=math.rad(40), dolly=.76, order=12 },
    { yaw= math.rad(90), lift=math.rad(44), dolly=.62, order=13 },
    { yaw=-math.rad(90), lift=math.rad(44), dolly=.62, order=14 },
    { yaw=0, lift=math.rad(48), dolly=.55, order=15 },
  }
  local best, bestScore = nil, -math.huge
  for _, seat in ipairs(candidates) do
    local eye, focus = staticSeatEye(arena, groundY, seat)
    local score, readable = visibilityScore(
      BattleArena, arena.map, arena, eye, groundY, "both")
    local safe = screenSafe(battle, arena, groundY, eye, focus, {
      phase="static-seat", shot="static-seat", subject="both",
      absoluteYaw=seat.yaw, absoluteLift=seat.lift,
      directorFrame=1, safetyFrame=seat.frame or 1, staticSeat=true,
    })
    -- Unknown provider geometry cannot rank screen positions. Keep the best
    -- world-readable deterministic seat and hold it; guessing dynamically is
    -- the dangerous operation, not this fixed fallback.
    if readable and (safe == true or boundsUnknown) and score > bestScore then
      best, bestScore = seat, score
    end
  end
  if best then
    best.reason = boundsUnknown and "hud-bounds-unavailable"
                  or narrow and "narrow-arena" or "constrained-room"
    BattleCam.staticSafetySeat = best
    BattleCam.screenSafetyOK = not boundsUnknown
  end
end

-- Authored portable ARENA sets have no traversable camera body, but their
-- projected battlers still have to clear the active HUD.  Physical MAP safety
-- below can move the eye through proven world corridors; a painted set must
-- keep its reviewed bearing and recover optically instead.  Probe the exact
-- authored shot and, only when necessary, widen its additive director lens.
-- Applying an already-proven factor immediately prevents the final rendered
-- guard from declining the first Voxel frame before a previous safe camera
-- exists (which otherwise presents as an ARENA -> 2D fallback).
local function updateAuthoredSafety(arena, groundY, shotChanged, battle)
  if not shotChanged
      and BattleCam.directorClock < BattleCam.directorSafetyProbeAt then return end
  BattleCam.directorSafetyProbeAt = BattleCam.directorClock
                                     + BattleCam.DIRECTOR_SAFETY_PROBE

  local currentEye, currentFocus, currentYaw, currentLift = safetyCandidate(
    arena, groundY, BattleCam.directorSafetyYaw,
    BattleCam.directorSafetyLift, BattleCam.directorSafetyDolly, true)
  local currentScreen, currentReason = screenSafe(
    battle, arena, groundY, currentEye, currentFocus, {
      phase="director", shot=BattleCam.directorShot,
      subject=BattleCam.directorSubject,
      absoluteYaw=currentYaw, absoluteLift=currentLift,
      directorFrame=BattleCam.directorFrame,
      safetyFrame=BattleCam.directorSafetyFrame,
    })
  BattleCam.screenSafetyOK = currentScreen == true
  BattleCam.screenSafetyReason = currentReason
  -- Once the first exact HUD receipt needed a wider lens, keep that lens for
  -- the remainder of this battle. Releasing it when a temporary textbox
  -- closes makes both battlers visibly grow even though neither model changed
  -- scale. A new exact arena/BattleState reset still starts from the canonical
  -- lens and may choose a different fixed factor before its first Voxel frame.
  if currentScreen == true and BattleCam.directorSafetyFrame > 1 + 1e-4 then
    BattleCam.directorSafetyFrameGoal = math.max(
      BattleCam.directorSafetyFrameGoal, BattleCam.directorSafetyFrame)
    return
  end
  if currentScreen == true and not shotChanged
      and BattleCam.directorClock < BattleCam.directorSafetyUntil then return end

  local rawEye, rawFocus, rawYaw, rawLift = safetyCandidate(
    arena, groundY, 0, 0, 1, true)
  local rawScreen, rawReason = screenSafe(
    battle, arena, groundY, rawEye, rawFocus, {
      phase="director-recovery", shot=BattleCam.directorShot,
      subject=BattleCam.directorSubject,
      absoluteYaw=rawYaw, absoluteLift=rawLift,
      directorFrame=BattleCam.directorFrame, safetyFrame=1,
    })
  if rawScreen == true then
    if BattleCam.directorClock >= BattleCam.directorSafetyUntil
        or currentScreen ~= true then
      BattleCam.directorSafetyYawGoal, BattleCam.directorSafetyLiftGoal = 0, 0
      BattleCam.directorSafetyFrameGoal, BattleCam.directorSafetyDollyGoal = 1, 1
      if currentScreen ~= true then
        BattleCam.directorSafetyYaw, BattleCam.directorSafetyLift = 0, 0
        BattleCam.directorSafetyFrame, BattleCam.directorSafetyDolly = 1, 1
      end
    end
    BattleCam.screenSafetyOK = true
    BattleCam.screenSafetyReason = rawReason or "authored-raw-safe"
    return
  end

  local best = nil
  for _, factor in ipairs({ 1.15, 1.30, 1.45, 1.60, 1.75 }) do
    local safe = screenSafe(battle, arena, groundY, rawEye, rawFocus, {
      phase="director-recovery", shot=BattleCam.directorShot,
      subject=BattleCam.directorSubject,
      absoluteYaw=rawYaw, absoluteLift=rawLift,
      directorFrame=BattleCam.directorFrame, safetyFrame=factor,
    })
    if safe == true then best = factor; break end
  end
  if best then
    BattleCam.directorSafetyYawGoal, BattleCam.directorSafetyLiftGoal = 0, 0
    BattleCam.directorSafetyDollyGoal = 1
    BattleCam.directorSafetyFrameGoal = best
    BattleCam.directorSafetyUntil = BattleCam.directorClock
                                    + BattleCam.DIRECTOR_SAFETY_HOLD
    BattleCam.screenSafetyOK = true
    BattleCam.screenSafetyReason = "authored-optical-recovery"
    if currentScreen ~= true then
      BattleCam.directorSafetyYaw, BattleCam.directorSafetyLift = 0, 0
      BattleCam.directorSafetyDolly = 1
      BattleCam.directorSafetyFrame = best
    end
    return
  end

  BattleCam.screenSafetyOK = false
  BattleCam.screenSafetyReason = rawReason or currentReason
  BattleCam.directorYawGoal = BattleCam.directorYaw
  BattleCam.directorLiftGoal = BattleCam.directorLift
  BattleCam.directorFocusGoal = BattleCam.directorFocus
  BattleCam.directorFocusYGoal = BattleCam.directorFocusY
  BattleCam.directorFrameGoal = BattleCam.directorFrame
  BattleCam.directorDollyGoal = BattleCam.directorDolly
end

local function updateSafety(arena, groundY, shotChanged, battle)
  if authoredArena(arena) then
    updateAuthoredSafety(arena, groundY, shotChanged, battle)
    return
  end
  local physical = arena and arena.map and not arena.discs
  if not physical then
    BattleCam.directorSafetyYawGoal, BattleCam.directorSafetyLiftGoal = 0, 0
    BattleCam.directorSafetyFrameGoal, BattleCam.directorSafetyDollyGoal = 1, 1
    return
  end
  if not shotChanged
      and BattleCam.directorClock < BattleCam.directorSafetyProbeAt then return end
  BattleCam.directorSafetyProbeAt = BattleCam.directorClock
                                     + BattleCam.DIRECTOR_SAFETY_PROBE
  local okArena, BattleArena = pcall(V.require, "BattleArena")
  local map = arena.map
  if not (okArena and BattleArena and map and arena.player and arena.enemy) then
    return
  end

  local currentEye, currentFocus, currentYaw, currentLift = safetyCandidate(
    arena, groundY, BattleCam.directorSafetyYaw,
    BattleCam.directorSafetyLift, BattleCam.directorSafetyDolly, true)
  local _, currentReadable = visibilityScore(
    BattleArena, map, arena, currentEye, groundY, BattleCam.directorSubject)
  local currentScreen, currentScreenReason = screenSafe(
    battle, arena, groundY, currentEye, currentFocus, {
      phase="director", shot=BattleCam.directorShot,
      subject=BattleCam.directorSubject,
      absoluteYaw=currentYaw, absoluteLift=currentLift,
      directorFrame=BattleCam.directorFrame,
      safetyFrame=BattleCam.directorSafetyFrame,
    })
  BattleCam.screenSafetyOK = currentScreen == true
  BattleCam.screenSafetyReason = currentScreenReason
  if currentReadable and currentScreen == true and not shotChanged
      and BattleCam.directorClock < BattleCam.directorSafetyUntil then return end

  local rawEye, rawFocus, rawYaw, rawLift = safetyCandidate(
    arena, groundY, 0, 0, 1)
  local rawScore, rawReadable = visibilityScore(
    BattleArena, map, arena, rawEye, groundY, BattleCam.directorSubject)
  local rawScreen, rawScreenReason = screenSafe(
    battle, arena, groundY, rawEye, rawFocus, {
      phase="director", shot=BattleCam.directorShot,
      subject=BattleCam.directorSubject,
      absoluteYaw=rawYaw, absoluteLift=rawLift,
      directorFrame=BattleCam.directorFrameGoal, safetyFrame=1,
    })
  if rawReadable and rawScreen == true
      and travelClear(BattleArena, map, currentEye, rawEye) then
    if BattleCam.directorClock >= BattleCam.directorSafetyUntil then
      BattleCam.directorSafetyYawGoal, BattleCam.directorSafetyLiftGoal = 0, 0
      BattleCam.directorSafetyFrameGoal, BattleCam.directorSafetyDollyGoal = 1, 1
    end
    BattleCam.screenSafetyOK = true
    BattleCam.screenSafetyReason = rawScreenReason
    return
  end

  -- Nearest cinematic escape first: use a restrained optical push and lift to
  -- move inside the foreground obstruction, then try progressively wider side
  -- seats. Every candidate must have a clear COMPLETE route from the current
  -- eye; a valid endpoint behind a house is not a valid camera move.
  local candidates = {
    -- Screen-space recovery comes first. A wider lens retains the cinematic
    -- bearing and world-clear eye while moving both actor hulls away from HUD
    -- furniture. These factors multiply the authored phrase lens only; the
    -- player's saved BTL CAM row remains untouched.
    { 0, 0, 1, 1.25 },
    { 0, 0, 1, 1.50 },
    { 0, 0, 1, 1.75 },
    { 0, 0, 1, 2.00 },
    { 0, 0, 1, 2.25 },
    -- Lift/turn from the current travel radius first, so the recovery path
    -- does not blindly dolly through the foreground object it is escaping.
    { 0,  math.rad(9),  1, .76 },
    { math.rad(14), math.rad(7), 1, .74 },
    { -math.rad(14), math.rad(7), 1, .74 },
    { math.rad(28), math.rad(12), 1, .70 },
    { -math.rad(28), math.rad(12), 1, .70 },
    { math.rad(50), math.rad(18), .92, .68 },
    { -math.rad(50), math.rad(18), .92, .68 },
    { math.rad(82), math.rad(26), .86, .66 },
    { -math.rad(82), math.rad(26), .86, .66 },
    { math.rad(120), math.rad(34), .80, .64 },
    { -math.rad(120), math.rad(34), .80, .64 },
    { math.pi, math.rad(40), .76, .62 },
  }
  local best, bestScore = nil, rawScore
  for _, candidate in ipairs(candidates) do
    local eye, focus, yaw, lift = safetyCandidate(
      arena, groundY, candidate[1], candidate[2], candidate[3])
    local score, readable = visibilityScore(
      BattleArena, map, arena, eye, groundY, BattleCam.directorSubject)
    local pathOK = travelClear(BattleArena, map, currentEye, eye)
    local safe = screenSafe(battle, arena, groundY, eye, focus, {
      phase="director-recovery", shot=BattleCam.directorShot,
      subject=BattleCam.directorSubject,
      absoluteYaw=yaw, absoluteLift=lift,
      directorFrame=BattleCam.directorFrameGoal,
      safetyFrame=candidate[4],
    })
    if readable and safe == true and pathOK then best = candidate; break end
    if safe == true and pathOK and score > bestScore then
      best, bestScore = candidate, score
    end
  end
  if not best then
    -- Last-resort return to the reviewed canonical bearing.  This is a shot
    -- substitution, not a path through the intervening wall: the easing below
    -- moves the presentation there while the eye stays above its floor.
    local cancelYaw = math.atan2(math.sin(-BattleCam.directorYawGoal),
                                 math.cos(-BattleCam.directorYawGoal))
    local canonical = {
      cancelYaw,
      -BattleCam.directorLiftGoal,
      1 / math.max(.25, BattleCam.directorDollyGoal),
      1 / math.max(.25, BattleCam.directorFrameGoal),
    }
    local eye, focus, yaw, lift = safetyCandidate(
      arena, groundY, canonical[1], canonical[2], canonical[3])
    local _, readable = visibilityScore(
      BattleArena, map, arena, eye, groundY, BattleCam.directorSubject)
    local safe = screenSafe(battle, arena, groundY, eye, focus, {
      phase="director-recovery", shot=BattleCam.directorShot,
      subject=BattleCam.directorSubject,
      absoluteYaw=yaw, absoluteLift=lift,
      directorFrame=BattleCam.directorFrameGoal,
      safetyFrame=canonical[4],
    })
    if readable and safe == true
        and travelClear(BattleArena, map, currentEye, eye) then
      best = canonical
    end
  end
  if best then
    BattleCam.directorSafetyYawGoal = best[1]
    BattleCam.directorSafetyLiftGoal = best[2]
    BattleCam.directorSafetyDollyGoal = best[3]
    BattleCam.directorSafetyFrameGoal = best[4]
    BattleCam.directorSafetyUntil = BattleCam.directorClock
                                    + BattleCam.DIRECTOR_SAFETY_HOLD
    BattleCam.screenSafetyOK = true
    BattleCam.screenSafetyReason = "recovered"
    -- Never animate through a frame already known to be hidden by HUD. World
    -- motion remains eased when readable; an unsafe screen composition cuts to
    -- the nearest safe optical correction before it can be presented.
    if currentScreen ~= true then
      BattleCam.directorSafetyYaw = best[1]
      BattleCam.directorSafetyLift = best[2]
      BattleCam.directorSafetyDolly = best[3]
      BattleCam.directorSafetyFrame = best[4]
    end
  else
    BattleCam.screenSafetyOK = false
    BattleCam.screenSafetyReason = rawScreenReason or currentScreenReason
    -- No endpoint with a clear complete corridor was found.  Keep the last
    -- proven pose instead of letting the authored goal start moving while the
    -- final per-frame guard repeatedly rolls it back.
    BattleCam.directorYawGoal = BattleCam.directorYaw
    BattleCam.directorLiftGoal = BattleCam.directorLift
    BattleCam.directorFocusGoal = BattleCam.directorFocus
    BattleCam.directorFocusYGoal = BattleCam.directorFocusY
    BattleCam.directorFrameGoal = BattleCam.directorFrame
    BattleCam.directorDollyGoal = BattleCam.directorDolly
  end
end

-- Real frame time, like every other presentational tween in this mod: a
-- fast-forwarded battle must not spin the camera.
function BattleCam.update(dt, arena, battle, groundY)
  BattleCam.applyDistanceSetting(false)
  groundY = tonumber(groundY) or 0
  local enteredAuthored = (authoredArena(arena) or arena and arena.stadiumDirector)
    and not (authoredArena(activeArena)
             or activeArena and activeArena.stadiumDirector)
  if not rawequal(activeArena, arena) or not rawequal(activeBattle, battle) then
    -- A safe camera or a spent provisional budget belongs only to this exact
    -- arena/BattleState pair. In particular, A -> B -> A must not resurrect an
    -- old A receipt, and a BattleState __eq alias is still a different owner.
    lastScreenSafe = nil
    pendingScreenProbe = nil
    pendingManualRollback = nil
    BattleCam.screenSafetyFallbackUsed = false
  end
  activeArena = arena
  activeBattle = battle
  inspectStaticSafety(arena, groundY, battle)
  if enteredAuthored then
    BattleCam.zoom, BattleCam.zoomGoal = BattleCam.DEFAULT_DISTANCE,
                                           BattleCam.DEFAULT_DISTANCE
  end
  dt = math.max(0, tonumber(dt) or 0)
  BattleCam.t = BattleCam.t + dt
  local previousClock = BattleCam.directorClock
  BattleCam.directorClock = BattleCam.directorClock + dt
  local staticSafety = BattleCam.staticSafetySeat
                       and rawequal(BattleCam.staticSafetyArena, arena)
  local directorAvailable = not staticSafety
                            and BattleCam.arenaDirectorEnabled(arena)
  local held = directorAvailable and math.max(0,
    math.min(BattleCam.directorClock, BattleCam.directorManualUntil)
      - previousClock) or 0
  BattleCam.directorAutoClock = BattleCam.directorAutoClock + dt - held
  local manual = directorAvailable
                 and BattleCam.directorClock < BattleCam.directorManualUntil
  -- keep the phase small forever rather than letting a long session lose
  -- float precision in the sines below
  local wrap = BattleCam.PAN_PERIOD * BattleCam.DOLLY_PERIOD
  if BattleCam.t > wrap then BattleCam.t = BattleCam.t - wrap end
  -- and the steered three easing after whatever the player last asked for,
  -- which is what keeps a flick of the stick from being a cut
  BattleCam.orbit = chase(BattleCam.orbit, BattleCam.orbitGoal, dt,
                          BattleCam.ORBIT_TIME)
  BattleCam.pitch = chase(BattleCam.pitch, BattleCam.pitchGoal, dt,
                          BattleCam.PITCH_TIME)
  BattleCam.zoom = chase(BattleCam.zoom, BattleCam.zoomGoal, dt,
                         BattleCam.ZOOM_TIME)

  local token = nil
  if battle and battle.animPlaying then
    token = tostring(battle.animName or "move") .. ":"
            .. tostring(battle.animAttackerIsPlayer and 1 or 0)
  end
  if token then
    if token ~= BattleCam.directorActionToken then
      BattleCam.directorActionToken, BattleCam.directorActionAge = token, 0
    else
      BattleCam.directorActionAge = BattleCam.directorActionAge
                                    + (manual and 0 or dt)
    end
  else
    BattleCam.directorActionToken, BattleCam.directorActionAge = nil, 0
  end

  local enabled = directorAvailable and not manual
  local shot, subject = staticSafety and "static-safety" or "static", "both"
  local yaw, lift, focus, focusY, frame, dolly = 0, 0, 0, 0, 1, 1
  if manual then
    shot, subject = BattleCam.directorShot, BattleCam.directorSubject
    yaw, lift = BattleCam.directorYawGoal, BattleCam.directorLiftGoal
    focus, focusY = BattleCam.directorFocusGoal,
                    BattleCam.directorFocusYGoal
    frame, dolly = BattleCam.directorFrameGoal, BattleCam.directorDollyGoal
  elseif enabled then
    if rawequal(BattleCam.directorPathArena, arena) then
      shot, subject, yaw, lift, focus, focusY, frame, dolly =
        physicalDirectorPhrase(BattleCam.directorAutoClock)
    else
      shot, subject, yaw, lift, focus, focusY, frame, dolly = directorPhrase(
        BattleCam.directorAutoClock, arena, battle, token,
        BattleCam.directorActionAge)
    end
  end
  local shotChanged = shot ~= BattleCam.directorShot
  BattleCam.directorShot, BattleCam.directorSubject = shot, subject
  if shotChanged then
    BattleCam.directorCutSerial = BattleCam.directorCutSerial + 1
  end
  BattleCam.directorYawGoal = yaw
  BattleCam.directorLiftGoal = lift
  BattleCam.directorFocusGoal = focus
  BattleCam.directorFocusYGoal = focusY
  BattleCam.directorFrameGoal = frame
  BattleCam.directorDollyGoal = dolly
  if shotChanged then
    BattleCam.directorSafetyUntil = 0
    BattleCam.directorSafetyYawGoal, BattleCam.directorSafetyLiftGoal = 0, 0
    BattleCam.directorSafetyFrameGoal, BattleCam.directorSafetyDollyGoal = 1, 1
  end
  local latchedPhysicalPath = rawequal(BattleCam.directorPathArena, arena)
  if not staticSafety and not manual and not latchedPhysicalPath
      and not authoredArena(arena) then
    updateSafety(arena, groundY, shotChanged, battle)
  end
  if manual then
    -- The player's orbit/pitch eases above, but the automatic component and
    -- its safety correction stay exactly where they were. When the hold ends,
    -- the paused automatic clock resumes from this composition.
    BattleCam.directorYawVelocity, BattleCam.directorLiftVelocity = 0, 0
    BattleCam.directorSafetyYawVelocity = 0
    BattleCam.directorSafetyLiftVelocity = 0
  elseif latchedPhysicalPath then
    -- The planned yaw already is a smoothstep curve with zero velocity at
    -- both ends. Applying a second goal chase made its four-second holds
    -- asymptotic: the eye kept creeping, then the next leg pulled it forward
    -- again. Consume the proven curve directly so travel is monotonic and a
    -- hold is mathematically still rather than merely very slow.
    local previousYaw, previousLift = BattleCam.directorYaw,
                                       BattleCam.directorLift
    BattleCam.directorYaw, BattleCam.directorLift = yaw, lift
    BattleCam.directorFocus, BattleCam.directorFocusY = focus, focusY
    BattleCam.directorFrame, BattleCam.directorDolly = frame, dolly
    if dt > 0 then
      BattleCam.directorYawVelocity = (yaw - previousYaw) / dt
      BattleCam.directorLiftVelocity = (lift - previousLift) / dt
    else
      BattleCam.directorYawVelocity, BattleCam.directorLiftVelocity = 0, 0
    end
    BattleCam.directorSafetyYaw, BattleCam.directorSafetyYawGoal = 0, 0
    BattleCam.directorSafetyLift, BattleCam.directorSafetyLiftGoal = 0, 0
    BattleCam.directorSafetyFrame, BattleCam.directorSafetyFrameGoal = 1, 1
    BattleCam.directorSafetyDolly, BattleCam.directorSafetyDollyGoal = 1, 1
    BattleCam.directorSafetyYawVelocity = 0
    BattleCam.directorSafetyLiftVelocity = 0
  elseif shotChanged and not (arena and arena.map and not arena.discs) then
    -- Painted screen-space arenas have no traversable camera body and retain
    -- their authored semantic cuts. Physical Voxel arenas always take the
    -- acceleration-bounded path below, including at a subject change.
    BattleCam.directorYaw, BattleCam.directorLift = yaw, lift
    BattleCam.directorFocus, BattleCam.directorFocusY = focus, focusY
    BattleCam.directorFrame, BattleCam.directorDolly = frame, dolly
    BattleCam.directorSafetyYaw = BattleCam.directorSafetyYawGoal
    BattleCam.directorSafetyLift = BattleCam.directorSafetyLiftGoal
    BattleCam.directorSafetyFrame = BattleCam.directorSafetyFrameGoal
    BattleCam.directorSafetyDolly = BattleCam.directorSafetyDollyGoal
    BattleCam.directorYawVelocity, BattleCam.directorLiftVelocity = 0, 0
    BattleCam.directorSafetyYawVelocity = 0
    BattleCam.directorSafetyLiftVelocity = 0
  else
    BattleCam.directorYaw, BattleCam.directorYawVelocity = chaseComfort(
      BattleCam.directorYaw, BattleCam.directorYawGoal,
      BattleCam.directorYawVelocity, dt, BattleCam.DIRECTOR_TIME,
      BattleCam.DIRECTOR_MAX_YAW_RATE, BattleCam.DIRECTOR_MAX_YAW_ACCEL)
    BattleCam.directorLift, BattleCam.directorLiftVelocity = chaseComfort(
      BattleCam.directorLift, BattleCam.directorLiftGoal,
      BattleCam.directorLiftVelocity, dt, BattleCam.DIRECTOR_TIME,
      BattleCam.DIRECTOR_MAX_LIFT_RATE, BattleCam.DIRECTOR_MAX_LIFT_ACCEL)
    BattleCam.directorFocus = chase(BattleCam.directorFocus,
                                    BattleCam.directorFocusGoal, dt,
                                    BattleCam.DIRECTOR_TIME)
    BattleCam.directorFocusY = chase(BattleCam.directorFocusY,
                                     BattleCam.directorFocusYGoal, dt,
                                     BattleCam.DIRECTOR_TIME)
    BattleCam.directorFrame = chase(BattleCam.directorFrame,
                                    BattleCam.directorFrameGoal, dt,
                                    BattleCam.DIRECTOR_TIME)
    BattleCam.directorDolly = chase(BattleCam.directorDolly,
                                    BattleCam.directorDollyGoal, dt,
                                    BattleCam.DIRECTOR_TIME)
    BattleCam.directorSafetyYaw,
      BattleCam.directorSafetyYawVelocity = chaseComfort(
        BattleCam.directorSafetyYaw, BattleCam.directorSafetyYawGoal,
        BattleCam.directorSafetyYawVelocity, dt, BattleCam.DIRECTOR_TIME,
        BattleCam.DIRECTOR_MAX_YAW_RATE, BattleCam.DIRECTOR_MAX_YAW_ACCEL)
    BattleCam.directorSafetyLift,
      BattleCam.directorSafetyLiftVelocity = chaseComfort(
        BattleCam.directorSafetyLift, BattleCam.directorSafetyLiftGoal,
        BattleCam.directorSafetyLiftVelocity, dt, BattleCam.DIRECTOR_TIME,
        BattleCam.DIRECTOR_MAX_LIFT_RATE, BattleCam.DIRECTOR_MAX_LIFT_ACCEL)
    BattleCam.directorSafetyFrame = chase(
      BattleCam.directorSafetyFrame, BattleCam.directorSafetyFrameGoal, dt,
      BattleCam.DIRECTOR_TIME)
    BattleCam.directorSafetyDolly = chase(
      BattleCam.directorSafetyDolly, BattleCam.directorSafetyDollyGoal, dt,
      BattleCam.DIRECTOR_TIME)
  end

  -- A portable painted ARENA has no world path to preflight. Probe after the
  -- director's eased pose is final for this update so its approved optical
  -- lens is byte-for-byte the camera rig() will present below.
  if directorAvailable and not manual and not latchedPhysicalPath
      and authoredArena(arena) then
    updateSafety(arena, groundY, shotChanged, battle)
  end

end

function BattleCam.directorState()
  return {
    yaw = BattleCam.directorYaw, lift = BattleCam.directorLift,
    yawVelocity = BattleCam.directorYawVelocity,
    liftVelocity = BattleCam.directorLiftVelocity,
    focus = BattleCam.directorFocus, focusY = BattleCam.directorFocusY,
    frame = BattleCam.directorFrame, dolly = BattleCam.directorDolly,
    shot = BattleCam.directorShot, subject = BattleCam.directorSubject,
    safetyYaw = BattleCam.directorSafetyYaw,
    safetyLift = BattleCam.directorSafetyLift,
    safetyFrame = BattleCam.directorSafetyFrame,
    safetyDolly = BattleCam.directorSafetyDolly,
    action = BattleCam.directorActionToken,
    autoClock = BattleCam.directorAutoClock,
    manual = BattleCam.directorClock < BattleCam.directorManualUntil,
    staticSafety = BattleCam.staticSafetySeat ~= nil,
    staticReason = BattleCam.staticSafetySeat
                   and BattleCam.staticSafetySeat.reason or nil,
    pathLatched = BattleCam.directorPathProven == true,
    screenSafe = BattleCam.screenSafetyOK,
    screenReason = BattleCam.screenSafetyReason,
    screenFallback = BattleCam.screenSafetyFallbackUsed == true,
  }
end

local function phase(t, period)
  return math.sin(2 * math.pi * t / period)
end

-- The camera for `arena` this instant: the record Voxel3D.camera takes, plus
-- the pitch the pull and the sun frustum want (measured from straight down,
-- the same convention Voxel.angle uses).
--
-- `fov` here frames the GB's 160x144. A caller rendering at window
-- resolution widens it for the extra picture around that frame -- see
-- BattleScene.letterboxFov, which is what keeps the pins exact at any window
-- size.
--
-- `groundY` is the height of the arena floor, so a fight staged on a ledge
-- or a raised walkway is shot from above THAT rather than from inside it.
-- `canonical` asks for the shot the rig was SOLVED for -- no drift, no
-- breath, no steer, no zoom -- from a caller that is reasoning about the
-- arena rather than drawing it. BattleArena's clearance test is the one
-- that needs it: whether a fight can be staged somewhere is a fact about
-- the ground, and answering it through whatever angle the player happened
-- to leave the last battle on would pick a different arena depending on
-- where they had swung the camera an hour ago.
function BattleCam.rig(arena, groundY, canonical)
  groundY = groundY or 0
  local R = BattleCam.rigFor(arena)
  local mx, mz = arena.mid[1], arena.mid[2]
  -- VR asks for the same stillness for its own reason (see BattleCam.still)
  local fixed = BattleCam.still or canonical
  local staticSafety = not canonical and BattleCam.staticSafetySeat
                       and rawequal(BattleCam.staticSafetyArena, arena)
  -- and the steer is withheld a second way, on its own: a BACK row holds
  -- the composition and the DRIFT still runs under it (see steerable)
  local steered = (not fixed) and not staticSafety and BattleCam.steerable

  -- The drift, plus wherever the player has steered to. The steer is
  -- NEGATIVE because the rotation below runs the other way from the bearing
  -- it turns: rotating (side, back) by +yaw carries the eye back toward the
  -- arena's own axis, and the room the player has is all on the far side of
  -- that -- out toward square-on. (orbitRange measures exactly that room.)
  local isAuthored = authoredArena(arena)
  local directed = steered and BattleCam.arenaDirectorEnabled(arena)
  local playerSteer = steered and not isAuthored
  local steer = playerSteer
                and -BattleCam.orbit * BattleCam.orbitRange(arena) or 0
  -- A static ARENA must be pixel-repeatable against its painted clearings.
  -- STADIUM supplies its own bounded motion, so the generic drift/dolly is
  -- disabled for both ARENA choices.
  local yaw = staticSafety and BattleCam.staticSafetySeat.yaw
              or steer + (directed and (BattleCam.directorYaw
                                        + BattleCam.directorSafetyYaw) or 0)
              + ((fixed or staticSafety or isAuthored or directed) and 0
                 or BattleCam.PAN_YAW * phase(
                      BattleCam.t, BattleCam.PAN_PERIOD))
  local c, s = math.cos(yaw), math.sin(yaw)
  -- the breath scales the whole offset, height included, so the eye moves
  -- along its own line to the arena and the pitch of the shot never changes
  local k = staticSafety and BattleCam.staticSafetySeat.dolly
            or directed and (BattleCam.directorDolly
                             * BattleCam.directorSafetyDolly)
            or (fixed or isAuthored) and 1
            or 1 + BattleCam.PAN_DOLLY
                   * phase(BattleCam.t, BattleCam.DOLLY_PERIOD)
  local dx, dz = arenaVector(arena,
    (R.side * c - R.back * s) * k,
    (R.side * s + R.back * c) * k)

  local eye = { mx + dx, groundY + R.height * k, mz + dz }
  local fx, fz = arenaVector(arena, R.lookX,
                             directed and BattleCam.directorFocus or 0)
  local focus = { mx + fx,
                  groundY + R.lookY
                    + (directed and BattleCam.directorFocusY or 0),
                  mz + fz }

  -- and the climb: the eye swung UP about the focus, at a constant radius.
  -- About the focus so the aim stays nailed to the two mons and only the
  -- seat moves, and at a constant radius so climbing never changes how big
  -- anything is -- that is the lens's job below, and a rig that did both at
  -- once would have no way to do either on purpose.
  local lift = staticSafety and BattleCam.staticSafetySeat.lift
               or playerSteer and BattleCam.pitch * BattleCam.PITCH_RANGE or 0
  if directed then
    local automaticLift = BattleCam.directorLift
                          + BattleCam.directorSafetyLift
    automaticLift = math.max(-BattleCam.DIRECTOR_MAX_LIFT,
                    math.min(BattleCam.DIRECTOR_MAX_LIFT, automaticLift))
    lift = lift + automaticLift
  end
  if lift > 0 then
    local vx, vy, vz = eye[1] - focus[1], eye[2] - focus[2], eye[3] - focus[3]
    local flat = math.sqrt(vx * vx + vz * vz)
    local r = math.sqrt(flat * flat + vy * vy)
    if flat > 1e-6 and r > 1e-6 then
      local a = math.atan2(vy, flat) + lift
      -- short of straight down, always: the placed camera's up vector is
      -- world up, which degenerates against a view looking exactly along it
      a = math.min(a, math.rad(85))
      local nf = r * math.cos(a)
      eye[1] = focus[1] + vx / flat * nf
      eye[3] = focus[3] + vz / flat * nf
      eye[2] = focus[2] + r * math.sin(a)
    end
  end

  -- Last line of defence for physical MAP travel. The visibility solver above
  -- chooses readable destinations; this guard additionally checks every small
  -- travelled segment between rendered frames. If a facade, wall or tree body
  -- enters that segment, keep the last safe seat and focus instead of letting
  -- the near plane pass through geometry. Authored cuts may jump between two
  -- individually clear seats because no in-world path is animated during a cut.
  if directed and arena.map and not arena.discs then
    local okArena, BattleArena = pcall(V.require, "BattleArena")
    if okArena and BattleArena and type(BattleArena.cameraClear) == "function" then
      local destinationOK = BattleArena.cameraClear(arena.map, eye)
      local isCut = BattleCam.directorSafeCutSerial
                    ~= BattleCam.directorCutSerial
      local travelOK = isCut or not BattleCam.directorSafeEye
                       or type(BattleArena.cameraPathClear) ~= "function"
      if not travelOK and type(BattleArena.cameraPathClear) == "function" then
        travelOK = BattleArena.cameraPathClear(
          arena.map, BattleCam.directorSafeEye, eye)
      end
      if destinationOK and travelOK then
        BattleCam.directorSafeEye = { eye[1], eye[2], eye[3] }
        BattleCam.directorSafeFocus = { focus[1], focus[2], focus[3] }
        BattleCam.directorSafeCutSerial = BattleCam.directorCutSerial
      elseif BattleCam.directorSafeEye and BattleCam.directorSafeFocus then
        eye = { BattleCam.directorSafeEye[1], BattleCam.directorSafeEye[2],
                BattleCam.directorSafeEye[3] }
        focus = { BattleCam.directorSafeFocus[1], BattleCam.directorSafeFocus[2],
                  BattleCam.directorSafeFocus[3] }
      end
    end
  end

  local ex = eye[1] - focus[1]
  local ey = eye[2] - focus[2]
  local ez = eye[3] - focus[3]
  local dist = math.max(1, math.sqrt(ex * ex + ey * ey + ez * ez))
  local horiz = math.sqrt(ex * ex + ez * ez)

  -- The lens carries the player's zoom: how much world the frame holds is
  -- the one thing that actually changes the framing here, because the field
  -- of view is DERIVED from that reach and the distance. Moving the eye
  -- instead would leave the picture the same size and only change its
  -- perspective -- which is what the dolly breath above is deliberately
  -- for, and is not what "zoom" means to anyone holding a wheel.
  local frameH = fixed and R.frameH or BattleCam.frameH(arena)
  local camera = {
    eye = eye,
    focus = focus,
    fov = 2 * math.atan((frameH / 2) / dist),
    -- the world curve is a free-roam flourish that bends the horizon away
    -- from the player; a fixed camera on a staged shot has no player to bend
    -- around, and the bend would tip the arena floor out from under the mons
    -- the pics are pinned to
    curve = 0,
  }
  local pitch = math.atan2(horiz, math.max(1e-3, ey))
  return guardRenderedCamera(arena, groundY, camera, pitch, canonical)
end

-- Responsive finishing pass for the already widened window lens.  `cam.fov`
-- must be the final framebuffer FOV (after BattleScene.letterboxFov).  The
-- desired horizon is solved from perspective rather than from a device list:
--
--   screenY = (1 - tan(elevation) / tan(fov / 2)) / 2
--
-- Rotating the eye about `focus` preserves distance and focus exactly.  A
-- twenty-degree cap keeps extremely tall displays from turning the fight
-- into a top-down shot; the remaining rows simply continue the sky/ground.
function BattleCam.fitPortrait(cam, pitch, pw, ph, arena)
  if not (cam and cam.eye and cam.focus and cam.fov)
     or not (tonumber(pw) and tonumber(ph))
     or pw <= 0 or ph <= 0 or pw >= ph or authoredArena(arena) then
    return cam, pitch, 0
  end

  local eye, focus = cam.eye, cam.focus
  local vx = eye[1] - focus[1]
  local vy = eye[2] - focus[2]
  local vz = eye[3] - focus[3]
  local flat = math.sqrt(vx * vx + vz * vz)
  local radius = math.sqrt(flat * flat + vy * vy)
  if flat < 1e-6 or radius < 1e-6 then return cam, pitch, 0 end

  local elevation = math.atan2(vy, flat)
  local ndc = 1 - 2 * BattleCam.PORTRAIT_HORIZON
  local wanted = math.atan(ndc * math.tan(cam.fov / 2))
  wanted = math.min(wanted, elevation + BattleCam.PORTRAIT_LIFT_MAX,
                    math.rad(70))
  if wanted <= elevation then return cam, pitch, 0 end

  local nextFlat = radius * math.cos(wanted)
  eye[1] = focus[1] + vx / flat * nextFlat
  eye[3] = focus[3] + vz / flat * nextFlat
  eye[2] = focus[2] + radius * math.sin(wanted)
  return cam, math.atan2(nextFlat, math.max(1e-3, eye[2] - focus[2])),
         wanted - elevation
end

return BattleCam
