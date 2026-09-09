-- Overworld battles: fights that happen on the map you were standing on.
--
-- The engine's battle is a screen: a white field with two pics on it, pushed
-- over a frozen overworld that stops drawing. This turns that white field
-- into the world -- the same terrain AND the same free-roam camera the
-- encounter was already using. Gold no longer cuts to a separately staged
-- battle camera; the battle UI is layered over the frozen overworld itself --
-- while leaving the battle ITSELF alone. Every pic, HUD, HP bar, move
-- animation, faint slide and text box is the engine's own, drawn in the
-- engine's own order. What changes is what is behind them, and where the two
-- pics stand.
--
-- The sequence, from the moment something picks a fight:
--
--   1. the overworld cast is culled -- every NPC vanishes, so the wipe
--      plays over an empty map and no bystander is left standing in the
--      arena shot
--   2. the engine's own transition wipes the screen (untouched: it is the
--      right wipe, picked by the right three bits)
--   3. on Gold, the battle draws over the frozen free-roam voxel frame at the
--      encounter site, using the exact overworld camera that was already on
--      screen. Stadium models stand in that world; the battle never changes
--      to a second arena camera
--   4. the battle ends, the cast comes back, and the player is exactly
--      where they were standing
--
-- WHAT DOES NOT MOVE. The arena is where the CAMERA goes, not where the
-- player goes: nothing here writes a cell, a facing, a flag or a warp. A
-- real warp would have to survive trainer sight-lines, post-battle
-- dialogue, the blackout path and every script that assumes the player is
-- where it left them -- and it would have to put them back afterwards.
-- Moving the camera buys the whole shot and owes nothing back.
--
-- The feature declines cleanly rather than half-working: no depth support,
-- no open ground on the map, the row switched off, or a mesh still building
-- all end at the same place, which is the battle screen the engine has
-- always drawn.

-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local ModSetting = V.require("ModSetting")
local BattleArena = V.require("BattleArena")
local BattleCam = V.require("BattleCam")
local BattleScene = V.require("BattleScene")
local BattleDOF = V.require("BattleDOF")
local BattleHud = V.require("BattleHud")
local BattlePics = V.require("BattlePics")
local okTrainerArt, Gen2TrainerArt = pcall(V.require, "Gen2TrainerArt")
if not okTrainerArt or type(Gen2TrainerArt) ~= "table" then
  Gen2TrainerArt = {}
end
local Voxel3D = V.require("Voxel3D")
local ChunkMesher = V.require("ChunkMesher")
local Weather = V.require("Weather")
local okDiagnostics, Diagnostics = pcall(V.require, "Diagnostics")
if not okDiagnostics or type(Diagnostics) ~= "table" then Diagnostics = {} end
local function diagnostic(event, fields)
  if type(Diagnostics.write) == "function" then
    local merged = {}
    for key, value in pairs(type(fields) == "table" and fields or {}) do
      merged[key] = value
    end
    local bridge = V and V.goldBridge
    if bridge and type(bridge.status) == "function" then
      local okStatus, status = pcall(bridge.status)
      if okStatus and type(status) == "table" then
        merged.voxelActive = status.active
        merged.voxelConfigured = status.configuredVoxel
        merged.voxelMap = status.currentMapId or status.mapId
        merged.voxelCamera = status.cameraMode
        merged.voxelCameraLevel = status.cameraLevel
        merged.voxelPipeline = status.selectorPipelineLevel
        merged.voxelRestore = status.pendingPipelineRestoreMode
        merged.voxelRestoreFrames = status.pendingPipelineRestoreFrames
        merged.voxelFrames3d = status.frames3d
        merged.voxelPending = status.framesPending
        merged.voxelFailures = status.framesFailed
        merged.voxelLastError = status.mapLifecycleError
      end
    end
    pcall(Diagnostics.write, event, merged)
  end
end

local OverworldBattle = {}
local session = nil
local nextBattleToken = 0
local selectedGoldBattleMode

-- LuaJIT/Lua 5.1 compatibility: some LÖVE targets expose only global
-- `unpack`, while desktop Lua 5.2+ exposes table.unpack. The v0.2.02 camera
-- observer used table.unpack directly and could crash the first time Gold
-- advanced its battle event queue on those targets.
local unpackResults = (table and table.unpack) or unpack
local function packResults(...)
  return { n = select("#", ...), ... }
end

-- Run renderer-owned code behind an exact graphics-stack boundary. Native
-- Gold draw helpers can call mod/provider callbacks, so treating them as
-- trusted just because the first function is engine code is unsafe: a thrown
-- callback may leave nested pushes open, while an extra pop must never consume
-- the frame below ours. Snapshot function entries too; a callback that patches
-- love.graphics for one draw must not leave that patch installed globally.
local function withGraphicsBoundary(label, fn, ...)
  local G = love and love.graphics
  local originalPush = G and G.push
  local originalPop = G and G.pop
  if type(originalPush) ~= "function" or type(originalPop) ~= "function" then
    return pcall(fn, ...)
  end

  local originalFields = {}
  for key, value in pairs(G) do
    originalFields[key] = { value=value }
  end
  -- Some hosts expose C functions through a metatable rather than pairs().
  originalFields.push = { value=originalPush }
  originalFields.pop = { value=originalPop }

  local outerOK, outerErr = pcall(originalPush, "all")
  if not outerOK then
    return false, tostring(label) .. " graphics guard push failed: "
      .. tostring(outerErr)
  end

  local depth = 1
  local function trackedPush(...)
    local values = packResults(originalPush(...))
    depth = depth + 1
    return unpackResults(values, 1, values.n)
  end
  local function trackedPop(...)
    if depth <= 1 then
      error(tostring(label) .. " crossed its graphics guard", 0)
    end
    local values = packResults(originalPop(...))
    depth = depth - 1
    return unpackResults(values, 1, values.n)
  end

  local installed, installErr = pcall(function()
    G.push = trackedPush
    G.pop = trackedPop
  end)
  if not installed then
    pcall(function()
      G.push = originalPush
      G.pop = originalPop
    end)
    pcall(originalPop)
    return false, tostring(label) .. " graphics guard install failed: "
      .. tostring(installErr)
  end

  local results = packResults(pcall(fn, ...))
  local restored, restoreErr = pcall(function()
    local repairs = {}
    for key, value in pairs(G) do
      local original = originalFields[key]
      if type(value) == "function"
          and (not original or original.value ~= value) then
        repairs[#repairs + 1] = {
          key=key, value=original and original.value or nil,
        }
      end
    end
    for key, original in pairs(originalFields) do
      if type(original.value) == "function" and G[key] ~= original.value then
        repairs[#repairs + 1] = { key=key, value=original.value }
      end
    end
    for _, repair in ipairs(repairs) do G[repair.key] = repair.value end
  end)

  local cleanupErr
  for _ = 1, depth do
    local ok, reason = pcall(originalPop)
    if not ok then
      cleanupErr = reason
      break
    end
  end
  if not restored or cleanupErr ~= nil then
    local primary = results[1] and nil or results[2]
    local detail = tostring(restoreErr or cleanupErr)
    if primary ~= nil then detail = tostring(primary) .. "; " .. detail end
    return false, tostring(label) .. " graphics cleanup failed: " .. detail
  end
  return unpackResults(results, 1, results.n)
end

-- DS_BATTLE_DEBUG=1 logs what the HUD's brightness probe is reading, once a
-- second, which is how the glyph flip is checked from a shot run. Read
-- through pcall: the loader's sandbox does not hand a mod `os`, and a
-- diagnostic must never be the reason the mod fails to load.
local DEBUG = select(2, pcall(function() return os.getenv("DS_BATTLE_DEBUG") end))
if DEBUG == nil or DEBUG == false then DEBUG = nil end

OverworldBattle.KEY = "battles"
OverworldBattle.LABEL = "3D-BTL"

-- Five rungs. Two independent choices, laid out as one ladder because they
-- are one question to the player -- WHAT is standing there, and WHERE:
--
--              on the MAP              on two DISCS
--   pics       2D-3D A                 2D-3D B
--   models     STADIUM A               STADIUM B
--
--   2D-3D A    the mode this file was written for: the fight is staged on
--              the map and the two Pokemon are the GB's OWN PICS, stood up
--              on their tiles as quads (BattleBillboard).
--   2D-3D B    those same pics on a pair of DISCS against the sky, with no
--              map at all (see lib/StadiumStage.lua). The Game Boy's own
--              framing with the Game Boy's own art, in three dimensions --
--              and, like every B rung, it works everywhere, including the
--              caves and shop floors that have nowhere to stage a fight.
--   STADIUM A  the staged fight with the Pokemon Stadium battle models in
--              place of those quads -- skinned, animated, and playing the
--              animation the move being used actually calls for (see
--              lib/Stadium.lua). The world is still the world: the fight
--              happens on real ground, in the map's own weather and light.
--   STADIUM B  the models on the discs: both halves swapped at once.
--   OFF        the engine's own white battle screen.
--
-- A and B is the STAGE and it is the same stage either way -- the discs do
-- not know what is standing on them and BattleScene draws them off
-- `arena.discs` alone, which is why the second column cost a value in this
-- table and nothing else. The four combinations are all reachable rather
-- than only the diagonal, because a player who cannot use the STADIUM rungs
-- -- no ROM, or a ROM they would rather not go and find -- should still be
-- able to have the disc framing, and because the discs are the answer to
-- "this map has nowhere to fight" whichever art is standing on them.
--
-- 2D-3D A stays FIRST because ModSetting's values[1] is both the default and
-- what an unrecognised stored value falls back to, and the stored value for
-- this row has been `true` since the row existed. Keeping `true` at the head
-- means every save written before the later rungs existed reads back as the
-- 2D-3D it was written for, and a mod whose headline is "the world in 3D"
-- still does not need the player to go and find the switch.
--
-- Every other stored value is likewise the one it has always been --
-- "stadium" from before there was a B, "stadiumB" from before there was a
-- flat one -- so no save loses the mode it chose.
--
-- Both STADIUM rungs are GATED on the models existing: the mod ships no
-- Pokemon Stadium data, and until the player's own ROM has been found and
-- built from (StadiumInstall) the row simply has two fewer stops. See
-- ModSetting.setGate for why they are skipped rather than shown and refused.
-- 2D-3D B is NOT gated: its stage is generated in Lua and its Pokemon are
-- the game's own art, so it needs nothing the base game did not ship.
OverworldBattle.FLAT_B = "flatB"

-- Gold/Silver/Crystal use the public battle3dWorld option as a four-rung
-- architecture choice. Keep MAP/DEFAULT as the historical booleans so saves
-- written by the former toggle remain valid without a migration write.
OverworldBattle.MAP = true
OverworldBattle.ARENA = "arena"
OverworldBattle.DISCS = "discs"
OverworldBattle.DEFAULT = false

OverworldBattle.setting =
  ModSetting.new(OverworldBattle.KEY, OverworldBattle.LABEL,
                 { true, "flatB", "stadium", "stadiumB", false },
                 { "2D-3D A", "2D-3D B", "STADIUM A", "STADIUM B", "OFF" })
  :setGate(function(value)
    if value ~= "stadium" and value ~= "stadiumB" then return true end
    local ok, install = pcall(V.require, "StadiumInstall")
    return ok and install and install.available()
  end)

-- Whether the fight stands on the two carried DISCS rather than on the map
-- -- the B column above, whichever row of it. Asked by stageFor (what to
-- stage on), wantsFront (whether this map needs an arena at all) and, once
-- the arena carries the answer as `arena.discs`, by BattleScene and
-- VoxelScene for what to draw.
--
-- Read straight off the row rather than through Stadium, because it is a
-- question about the STAGE and half the rungs that answer yes have no
-- Stadium models on them at all.
function OverworldBattle.discs()
  if V.game and V.game.world then
    return selectedGoldBattleMode ~= nil
      and selectedGoldBattleMode() == OverworldBattle.DISCS
  end
  local value = OverworldBattle.setting:get()
  return (value == OverworldBattle.FLAT_B or value == "stadiumB")
end

-- Whether the VR row is ON -- read lazily, because VR requires modules
-- that sit above this one. While it is, this mode stops being optional:
-- the headset's battle seat, the pokedex screen and the effects plane
-- all assume a fight standing on the world, and a white-field battle
-- inside a headset is exactly the flat screen VR exists to replace.
local function vrOn()
  local ok, vr = pcall(V.require, "VR")
  return ok and vr and vr.enabled and vr.enabled() or false
end

local function modelsEnabledNow()
  if type(V.modelsEnabled) == "function" then
    local ok, value = pcall(V.modelsEnabled)
    if ok then return value ~= false end
  end
  local mod = V.mod
  local options = mod and mod.options
  if not (options and type(options.get) == "function") then return false end
  local ok, value = pcall(options.get, options, "stadium3dSprites")
  if not ok or value == nil then return false end
  return not (value == false or value == 0 or value == "0"
    or value == "false" or value == "off")
end

local function modelsEnabled()
  local plan = session and session.plan
  if plan and plan.modelsEnabled ~= nil then
    return plan.modelsEnabled == true
  end
  return modelsEnabledNow()
end

local function standardBattleHudNow()
  local mod = V.mod
  local options = mod and mod.options
  if not (options and type(options.get) == "function") then return false end
  local ok, value = pcall(options.get, options, "battleHudStyle")
  if not ok or value == nil then return false end
  value = tostring(value):lower()
  return value == "standard" or value == "native"
      or value == "game_default" or value == "off"
end

local function normalizeGoldBattleMode(value)
  if value == OverworldBattle.ARENA or value == "stadium" then
    return OverworldBattle.ARENA
  end
  if value == OverworldBattle.DISCS or value == OverworldBattle.FLAT_B
      or value == "stadiumB" then
    return OverworldBattle.DISCS
  end
  if value == false or value == 0 then return OverworldBattle.DEFAULT end
  if type(value) == "string" then
    local key = value:lower():gsub("[%s_-]+", "")
    if key == "off" or key == "false" or key == "0" or key == "default"
        or key == "gamedefault" or key == "native" or key == "2d" then
      return OverworldBattle.DEFAULT
    end
    if key == "arena" or key == "stadium" then return OverworldBattle.ARENA end
    if key == "discs" or key == "disc" or key == "flatb"
        or key == "stadiumb" then return OverworldBattle.DISCS end
  end
  -- nil/true/unknown values preserve the historical default: exact MAP.
  return OverworldBattle.MAP
end

local function goldBattleModeNow()
  if not (V.game and V.game.world) then return nil end
  local mod = V.mod
  local value = true
  if mod and mod.options and type(mod.options.get) == "function" then
    local ok, got = pcall(mod.options.get, mod.options, "battle3dWorld")
    if ok and got ~= nil then value = got end
  end
  return normalizeGoldBattleMode(value)
end

local function smartCameraNow()
  local mod = V.mod
  local value = true
  if mod and mod.options and type(mod.options.get) == "function" then
    local ok, got = pcall(mod.options.get, mod.options, "battleSmartCamera")
    if ok and got ~= nil then value = got end
  end
  return not (value == false or value == 0 or value == "0"
    or value == "false" or value == "off")
end

local function capturePresentationPlan()
  local mode = goldBattleModeNow()
  if mode == nil then mode = OverworldBattle.setting:get() end
  return {
    schema="voxel-ascendant/gen2-battle-presentation-plan/v2",
    mode=mode,
    smartCamera=smartCameraNow(),
    standardHud=standardBattleHudNow(),
    modelsEnabled=modelsEnabledNow(),
    backPinned=false,
  }
end

OverworldBattle.capturePresentationPlan = capturePresentationPlan

selectedGoldBattleMode = function()
  if not (V.game and V.game.world) then return nil end
  local plan = session and session.plan
  if plan and plan.mode ~= nil then return normalizeGoldBattleMode(plan.mode) end
  return goldBattleModeNow()
end

function OverworldBattle.enabled()
  local gold = selectedGoldBattleMode()
  if gold ~= nil then return gold ~= OverworldBattle.DEFAULT end
  if vrOn() then return true end
  return OverworldBattle.setting:get() and true or false
end

-- The exact architecture selected for the current battle. On Gold this is
-- immutable once begin() captures the plan; changing the option affects only
-- the next encounter. Legacy callers retain their historical row values.
function OverworldBattle.mode()
  local gold = selectedGoldBattleMode()
  if gold ~= nil then return gold end
  return OverworldBattle.setting:get()
end

-- Whether the STADIUM rung is the one selected -- read through Stadium so
-- there is one answer to that question and it lives with the mode it
-- describes. Required lazily: Stadium sits above this file and requires it
-- back (for the row), which a load-time require would deadlock.
function OverworldBattle.stadium()
  if not modelsEnabled() then return false end
  local gold = selectedGoldBattleMode()
  if gold ~= nil then
    return gold ~= OverworldBattle.DEFAULT and Voxel3D.available()
  end
  local ok, stadium = pcall(V.require, "Stadium")
  return (ok and stadium and stadium.enabled()) and true or false
end

-- ------- BACK SPRITES: the player's own mon stays on the menu
--
-- The staged shot stands BOTH mons on the map, which is the mode's whole
-- claim -- but it costs the one piece of framing Gen 1 is most recognisable
-- by: your own Pokemon, seen from behind, sitting on top of the battle menu
-- with its feet on the box. That silhouette is the series' shot.
--
-- So BACK SPRITES is offered as a middle setting rather than a compromise
-- imposed on everyone. With it on the foe is still geometry standing on its
-- tile at the far end of the arena, and the player's side goes back to being
-- the GB's own flat back pic in the GB's own slot: same art, same 2x, same
-- feet on row 96.
-- Nothing else about the shot moves -- the arena, the camera and the drift are
-- solved exactly as they were, so the foe stands where it always stood and the
-- player's cell is simply empty ground in the foreground.
--
-- OFF by default: what the mode advertises is the pair of them out there.
OverworldBattle.BACK_KEY = "battleBack"
OverworldBattle.BACK_LABEL = "BACK SPRITES"

OverworldBattle.backSetting = ModSetting.new(OverworldBattle.BACK_KEY,
                                             OverworldBattle.BACK_LABEL,
                                             { false, true }, { "OFF", "ON" })

-- Gated on 3D-BTL rather than read alone: with staged battles off there is no
-- staged shot for a back pic to be pinned in FRONT of, and the engine's own
-- battle screen already draws exactly this. And held OFF under VR: the
-- headset stands both mons on the world -- a flat back pic pinned to the
-- 2D frame would keep your own mon off the arena the battle seat looks at.
function OverworldBattle.backPinned()
  if V.game and V.game.world then return false end
  if not OverworldBattle.enabled() then return false end
  if vrOn() then return false end
  return OverworldBattle.backSetting:get() and true or false
end

-- Whether a pic is the one drawn in the GB's own slot with its feet on the
-- text box, rather than geometry standing out on the map.
--
-- Exactly the player's side under BACK SPRITES -- its mon, or the trainer back
-- that holds the slot until "Go!" -- because that is the only pic this mod
-- ever leaves flat (see drawPicsLayer below). The foe is a billboard on its
-- tile whichever mode is on, and with the mode off the player's side is one
-- too, so both of those keep the open bottom that lets the arena through a
-- stride. What the answer buys is in BattlePics: a pic on the box has nothing
-- behind its lowest row, so its bottom edge seals.
-- Read by TRUTHINESS rather than against nil, because sideTexture blanks the
-- side it is not rendering by setting the field to FALSE (see OFF) and holds
-- it that way for the whole render -- during which the pic layer runs, and
-- picImage asks this. A nil test passes a `false` straight through to the
-- index below, and the error comes out of sideTexture into the pcall that
-- calls it: the foe's billboard is dropped for the frame and the Pokemon
-- simply is not there.
function OverworldBattle.pinnedPic(battle, img)
  if not (battle and img) then return false end
  if not OverworldBattle.backPinned() then return false end
  if img == battle.playerBackPic then return true end
  local player = battle.player
  return (player and img == player.sprite) and true or false
end

-- ------- both mons face you
--
-- Standing on a map, seen from in front, a Pokemon showing you its BACK is
-- wrong twice over: it is turned away from the camera that is looking at it,
-- and the back pics are a different, smaller drawing made for a slot the
-- player never really sees. So the player's side asks for the FRONT pic too,
-- through the engine's own pokemon.sprite hook -- the seam that exists for
-- exactly this, so no battle code has to be touched to get it.
--
-- Unless BACK SPRITES is on, the setting that asks for the back pic back:
-- that mon is drawn in its own slot on the menu, seen from behind, and the
-- front art would be it turned round to face the player it belongs to.
--
-- Answered BEFORE a battle exists, because the battler is built before the
-- battle is pushed. So it cannot ask whether this fight is staged; it asks
-- whether one on this map WOULD be -- the row is on, the 3D pass is
-- available, and the map has an arena -- which is the same question with the
-- same answer a moment later. Cached per map, because the arena search walks
-- the whole grid and this runs once per battler.
local staged = { mapId = nil, ok = false }

function OverworldBattle.wantsFront()
  if not OverworldBattle.enabled() then return false end
  if OverworldBattle.backPinned() then return false end
  if not Voxel3D.available() then return false end
  -- Gold's in-world battle stage is built from the live Game2 world and the
  -- exact encounter snapshot, so there is no Gen-1 BattleArena search to do.
  -- If the Gold world exists, the front model is wanted; stageFor() will do
  -- the conservative fall-back if a shot cannot actually be produced.
  if V.game and V.game.world and V.game.world.map then return true end
  -- required here rather than through the file's own helper: this runs
  -- while a battler is being built, which is before that helper is defined
  local g = require("src.core.Game")
  local ow = g and g.overworld
  if not (ow and ow.map and ow.player) then return false end
  -- a B rung carries its own stage, so the answer is yes on every map and
  -- there is nothing to search or to cache
  if OverworldBattle.discs() then return true end
  if staged.mapId ~= ow.map.id then
    local ok, arena = pcall(BattleArena.find, ow.map,
                            ow.player.cellX, ow.player.cellY,
                            ow.player.surfing)
    staged = { mapId = ow.map.id, ok = (ok and arena) and true or false }
  end
  return staged.ok
end

-- ------- where the engine's own pics stand
--
-- The GB draws the player's back pic with its feet on the text box at row 96
-- and its 7x7-tile slot centred on x=40, and the enemy's front pic
-- bottom-aligned in a 7x7 slot centred on x=124 ending at row 56. Those two
-- points are the pics' FEET, they hold for every species at every scale (the
-- engine's placement helpers pin the bottom edge and the centre), and they
-- are what BattleCam is solved to put the two arena cells under.
--
-- Which makes the pin a subtraction: whatever the drift has done to the
-- camera this frame, each pic moves by its own cell's projected position
-- minus its anchor. At the middle of the drift that is zero.
OverworldBattle.ANCHOR = {
  player = { 26, 96 },
  enemy = { 124, 56 },
}

-- ------- how big a mon is
--
-- Not a decision made here. A pic is drawn at its own integer scale -- 1x for
-- a 56px front pic, 2x for a 32px back one -- because that is the only way it
-- keeps every pixel the artist drew, and the CAMERA is solved so that one
-- overworld square is that big on screen (see BattleCam). The mon fits its
-- tile because the tile was sized to the mon, not the other way round.
OverworldBattle.SLOT_W = { front = 56, back = 32 }

-- The two HUD blocks, as the pixel spans DrawEnemyHUDAndHPBar and
-- DrawPlayerHUDAndHPBar actually reach. Neither overlaps its side's pic at
-- the anchors above.
OverworldBattle.HUD_RECT = {
  enemy = { 8, 0, 80, 32 },
  player = { 72, 56, 88, 40 },
}

-- ------- the box at the bottom, on the same glass
--
-- The HUDs got frosted panels because black glyphs on grass are not readable.
-- The battle's text box and its menu had the opposite problem and the same
-- cause: they are drawn as an OPAQUE WHITE slab with a black border, which was
-- the field's own colour when the field was white and is a sheet of paper laid
-- over the bottom third of the diorama now that it is not.
--
-- So the box gets exactly what the HUDs get: the world behind it, blurred to
-- frosted glass and laid back down translucent, with the border and the text
-- drawn over it unchanged, and the same brightness verdict flipping the ink
-- when the ground under it is dark. Only the FILL is taken away -- every glyph
-- the engine draws inside the box is still the engine's own, in its own place.
--
-- These are the boxes BattleState:drawTextArea lays down, as GB-frame rects.
-- READ-ONLY duplicates of that function's own branches, the same kind of
-- mirror hudLive is and for the same reason: there is no seam that reports "a
-- move menu is up", and glass has to go down BEFORE the box that sits on it.
-- The worst a future engine change can do is frost a rectangle nothing lands
-- on, or leave a box unfrosted -- never break a battle.
--
-- Each rect stops where the next one starts rather than overlapping it: two
-- panels over the same pixels would frost it twice and leave a visible step
-- along the seam.
OverworldBattle.TEXT_RECT = {
  box = { 0, 96, 160, 48 },       -- Font.drawBox(0, 12, 20, 6), always
  -- moveSelect's TYPE/PP box, Font.drawBox(0, 8, 11, 5), trimmed to the rows
  -- above the box above -- its last tile row sits inside that one
  moves = { 0, 64, 88, 32 },
  -- mimicSelect's copy menu, Font.drawBox(0, 7, 16, 6), trimmed the same way
  mimic = { 0, 56, 128, 40 },
}

-- How far apart the two anchors are: the spacing every move animation was
-- authored against, and so the yardstick the live pair is measured with.
OverworldBattle.ANCHOR_SPAN = math.sqrt(
  (OverworldBattle.ANCHOR.enemy[1] - OverworldBattle.ANCHOR.player[1]) ^ 2
  + (OverworldBattle.ANCHOR.enemy[2] - OverworldBattle.ANCHOR.player[2]) ^ 2)

-- The effects layer's scale for this shot: how far apart the two mons
-- actually are on screen, over how far apart the slots they were authored
-- for were. Clamped hard at both ends -- an effect is pixel art and a wild
-- factor is worse than a slightly wrong one -- and held at exactly 1 when
-- the marks coincide, which is a projection about to degenerate rather
-- than a pair that has genuinely closed up.
OverworldBattle.ANIM_SCALE_MIN = 0.5
OverworldBattle.ANIM_SCALE_MAX = 2.0

function OverworldBattle.animScale(shot, px, py)
  if not (shot and shot.enemy and px and py) then return 1 end
  local dx, dy = shot.enemy[1] - px, shot.enemy[2] - py
  local span = math.sqrt(dx * dx + dy * dy)
  if not (span > 1) then return 1 end
  local k = span / OverworldBattle.ANCHOR_SPAN
  return math.max(OverworldBattle.ANIM_SCALE_MIN,
                  math.min(OverworldBattle.ANIM_SCALE_MAX, k))
end

function OverworldBattle.textRects(battle)
  if not battle or battle.blankForAskName then return {} end
  local r = OverworldBattle.TEXT_RECT
  local out = { box = r.box }
  if battle.phase == "moveSelect" then
    out.moves = r.moves
  elseif battle.phase == "mimicSelect" then
    out.mimic = r.mimic
  end
  return out
end

-- ------- the HUDs, out at the window's own edges
--
-- The battle screen is 160x144 in the MIDDLE of the window and the world is the
-- whole of it. That left both HUD blocks huddled together in the middle of the
-- frame with map showing on either side of them, which reads as a Game Boy
-- screenshot pasted over a diorama rather than as the diorama's own furniture.
--
-- So each block is snapped to its own side: the foe's to the left edge of the
-- window, the player's to the right. Nothing about either block changes -- same
-- tiles, same size, same rows, drawn by the engine's own DrawEnemyHUDAndHPBar
-- and DrawPlayerHUDAndHPBar -- only where the pair sits. On a window the shape
-- of the GB screen there is nowhere to go and the snap is a no-op.
--
-- They cannot simply be MOVED there: the engine draws them into the 160x144 UI
-- canvas and everything outside it is clipped away. So the layer is rendered to
-- a texture and composited into the WORLD image instead, which is the one
-- surface in this mode that covers the whole window.

-- The rows each block is cut out of, full width. Generous on purpose:
-- AnimationShakeEnemyHUD nudges the foe's block sideways, a long name reaches
-- further than the panel does, and the pokeball rows and the safari ball count
-- belong to the block whose rows they sit in. Nothing drawHUDs draws lies
-- outside rows 0-96, and the two bands split that between them.
OverworldBattle.HUD_BAND = {
  enemy = { 0, 0, 160, 48 },
  player = { 0, 48, 160, 48 },
}

-- Where each block lands, in WORLD-canvas pixels: the panel rect the frosted
-- glass is cut to, plus the x its band is blitted at.
--
-- The foe's panel starts at the window's left edge and the player's ends at the
-- right one. The vertical is untouched, so both stay on the rows the GB put
-- them on. A band's own origin sits outside the window by the panel's inset --
-- the couple of pixels a HUD shake can push past the edge are clipped there,
-- which is the whole cost of the snap and is invisible.
function OverworldBattle.snapRects(shot)
  local s = shot.scale
  local e, p = OverworldBattle.HUD_RECT.enemy, OverworldBattle.HUD_RECT.player
  local ex = -e[1] * s                       -- foe: panel's left edge to 0
  local px = shot.pw - (p[1] + p[3]) * s     -- player: right edge to the far side
  local rects = {
    enemy = { ex + e[1] * s, shot.ly + e[2] * s, e[3] * s, e[4] * s },
    player = { px + p[1] * s, shot.ly + p[2] * s, p[3] * s, p[4] * s },
  }
  return rects, { enemy = ex, player = px }
end

-- A rect measured in the GB frame, in WORLD-canvas pixels: where the letterbox
-- blit will actually put it. The text box has not moved anywhere -- it is drawn
-- where it always was -- but its glass is laid into the world image alongside
-- the HUDs' (see snapHUDs), which is the surface that reaches the screen a
-- pixel to a pixel rather than magnified out of a 160x144 canvas.
local function toWorld(rect, shot)
  local s = shot.scale
  return { shot.lx + rect[1] * s, shot.ly + rect[2] * s,
           rect[3] * s, rect[4] * s }
end

-- ------- the live battle
--
-- nil when no overworld battle is running. Never more than one: battles do
-- not nest.
local goldCompositorReady = false
local nativeFallbackDepth = 0
local goldBattleScreenClass = nil
local goldNativeDrawWidescreen = nil
local PRESENTATION_KEY = "_vascGen2BattlePresentation"

local function presentationOf(screen)
  return type(screen) == "table" and rawget(screen, PRESENTATION_KEY) or nil
end

local function isGoldBattleScreen(screen)
  if type(screen) ~= "table" then return false end
  if rawget(screen, "_vascGen2BattleScreenOwner") == true then return true end
  local mt = getmetatable(screen)
  return goldBattleScreenClass ~= nil
    and (mt == goldBattleScreenClass
      or (type(mt) == "table" and mt.__index == goldBattleScreenClass))
end

-- Public, side-effect-free owner predicate shared with VascEnvironment and
-- the window compositor.  A Party/Summary submenu may deliberately retain a
-- `.battle` pointer; that pointer is not proof that the submenu is the concrete
-- Gen-2 BattleState which owns presentation/content teardown.
function OverworldBattle.isBattleScreen(screen)
  return isGoldBattleScreen(screen)
end

local function currentSessionOwner()
  return session and (session.battle or session.logicBattle) or nil
end

local function resolvedGoldMon(screen, side, battle)
  local mon = type(battle) == "table" and battle[side] or nil
  if type(screen) == "table" and type(screen.activeMon) == "function" then
    local ok, active = pcall(screen.activeMon, screen, side)
    if not ok then
      error(("Crystal %s active-mon resolution failed: %s")
        :format(tostring(side), tostring(active)), 0)
    end
    if active ~= nil then mon = active end
  end
  return mon
end

-- Gold reuses the same BattleState and world Canvas while party members are
-- switched. Session identity therefore is not enough to decide whether an old
-- completed frame is still safe: its Stadium actors may belong to the previous
-- deployment. Keep a deliberately narrow, pointer-first receipt of everything
-- that decides which combatants VoxelScene submits.
local function deploymentReceipt(screen)
  local battle = type(screen) == "table" and screen.battle or nil
  if type(battle) ~= "table" then return nil end
  local player, enemy = battle.player, battle.enemy
  local activePlayer = resolvedGoldMon(screen, "player", battle)
  local activeEnemy = resolvedGoldMon(screen, "enemy", battle)
  local hidden = type(screen.picHidden) == "table" and screen.picHidden or nil
  return {
    player=player,
    enemy=enemy,
    playerSpecies=type(player) == "table" and player.species or nil,
    enemySpecies=type(enemy) == "table" and enemy.species or nil,
    playerSprite=type(player) == "table" and player.sprite or nil,
    enemySprite=type(enemy) == "table" and enemy.sprite or nil,
    activePlayer=activePlayer,
    activeEnemy=activeEnemy,
    activePlayerSpecies=type(activePlayer) == "table"
      and activePlayer.species or nil,
    activeEnemySpecies=type(activeEnemy) == "table"
      and activeEnemy.species or nil,
    activePlayerSprite=type(activePlayer) == "table"
      and activePlayer.sprite or nil,
    activeEnemySprite=type(activeEnemy) == "table"
      and activeEnemy.sprite or nil,
    playerHidden=hidden and hidden.player == true or false,
    enemyHidden=hidden and hidden.enemy == true or false,
    showPlayerTrainer=screen.showPlayerTrainer == true,
    showEnemyTrainer=screen.showEnemyTrainer == true,
    enemyTrainerImage=screen.enemyTrainerImage,
    enemyTrainerPath=screen.enemyTrainerPath,
    slidingBackpic=screen.slidingBackpic == true,
    tutorial=screen.tutorial == true,
  }
end

local function sameDeployment(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  for _, key in ipairs({
    "player", "enemy", "playerSpecies", "enemySpecies",
    "playerSprite", "enemySprite", "playerHidden", "enemyHidden",
    "activePlayer", "activeEnemy", "activePlayerSpecies", "activeEnemySpecies",
    "activePlayerSprite", "activeEnemySprite",
    "showPlayerTrainer", "showEnemyTrainer", "enemyTrainerImage",
    "enemyTrainerPath", "slidingBackpic", "tutorial",
  }) do
    if a[key] ~= b[key] then return false end
  end
  return true
end

local MAX_TRANSIENT_SCENE_WAIT = 1.0
local MAX_COLD_SCENE_WAIT = 5.0

local function sceneClock()
  local timer = love and love.timer
  if timer and type(timer.getTime) == "function" then
    local ok, value = pcall(timer.getTime)
    if ok and tonumber(value) then return tonumber(value) end
  end
  return os.clock()
end

local function retryAfterNilFrame(active, gold, deployment, mode)
  local retain = active.presentationCommitted and active.shot
    and (not gold or sameDeployment(active.deployment, deployment))
  active.renderFailures = (tonumber(active.renderFailures) or 0) + 1
  local now = sceneClock()
  if active.nilFrameStartedAt == nil then active.nilFrameStartedAt = now end
  -- BattleState.new performs a zero-delta prewarm and some hosts can invoke
  -- more than one compositor path in one physical frame.  Counting calls made
  -- the old 12-miss budget expire in a few milliseconds.  Real elapsed time is
  -- the stable contract; a prewarm can request work without consuming it.
  local elapsed = math.max(0, now - active.nilFrameStartedAt)
  if mode == "prewarm" then
    -- Prewarm may be followed by loading work before the first visible
    -- compositor pass.  Merely reporting zero here still left the original
    -- timestamp aging in the background, so that first real pass could spend
    -- an already-expired budget.  Rebase it while covered instead.
    active.nilFrameStartedAt = now
    elapsed = 0
  end
  local limit = retain and MAX_TRANSIENT_SCENE_WAIT or MAX_COLD_SCENE_WAIT
  active.nilFrameElapsed = elapsed
  return elapsed < limit, retain
end

local function sessionMatchesOwner(active, expected)
  if not (active and expected ~= nil) then return false end
  -- Identity is part of the lifecycle contract. Lua tables may define __eq;
  -- accepting that metamethod lets a foreign screen impersonate the active
  -- encounter and tear it down. Use pointer equality throughout.
  if rawequal(expected, active.battle) then return true end
  -- Once a concrete BattleState is bound it is the encounter-instance owner.
  -- A logic table can be reused by a replacement screen, so a delayed
  -- battle.ended{battle=logic} must not be allowed to retire that screen.
  if rawequal(expected, active.logicBattle) then return active.battle == nil end
  if type(expected) == "table" and type(expected.battle) == "table" then
    if active.battle ~= nil then
      return rawequal(expected, active.battle)
        and rawequal(expected.battle, active.logicBattle)
    end
    return rawequal(expected.battle, active.logicBattle)
  end
  return false
end

function OverworldBattle.setGoldCompositorReady(ready)
  goldCompositorReady = ready == true
  return goldCompositorReady
end

local function isIOS()
  -- Current mod sandboxes reject direct love.system access. Use the same
  -- engine-owned platform seam as the voxel/compose bridges and keep legacy
  -- LÖVE detection fully protected for older hosts.
  local okNative, nativeName = pcall(function()
    local sys = love and love.system
    return sys and sys.getOS and sys.getOS()
  end)
  if okNative and (nativeName == "iOS" or nativeName == "Android") then
    return nativeName == "iOS"
  end
  local okPlatform, Platform = pcall(require, "src.core.Platform")
  if okPlatform and type(Platform) == "table" and type(Platform.detect) == "function" then
    local okDetect, info = pcall(Platform.detect)
    if okDetect and type(info) == "table" and type(info.os) == "string" then
      return info.os == "iOS"
    end
  end
  return okNative and nativeName == "iOS" or false
end

local function game()
  if V.game then return V.game end
  return require("src.core.Game")
end

local function isGoldGame()
  local g = game()
  return g and g.world ~= nil
end

local function finishForReplacement(expectedOwner)
  -- World records the incoming encounter before pushBattleTransition invokes
  -- begin(). If an obsolete session still exists, its normal cleanup clears
  -- that shared field. Preserve the incoming snapshot across only this
  -- replacement boundary, then let exactGoldArena consume it normally.
  local g = game()
  local world = g and g.world
  local incoming = world and world._stadiumEncounterSnapshot or nil
  -- Cleanup may legitimately surface a renderer/state restoration error. The
  -- incoming encounter nevertheless already owns this snapshot, so restore it
  -- in a finally-style boundary before propagating the original failure.
  local ok, finished = pcall(OverworldBattle.finish,
    expectedOwner or currentSessionOwner())
  if world then world._stadiumEncounterSnapshot = incoming end
  if not ok then error(finished, 0) end
  return finished
end

-- The generation-owned Battle Card adapter is the only caller that needs the
-- replacement boundary.  Keep the implementation local, but publish the
-- exact function rather than making the adapter duplicate snapshot ownership.
OverworldBattle.finishForReplacement = finishForReplacement

-- Whether this frame's HUDs went out to the window's edges instead of being
-- drawn in the GB frame. False whenever the composite could not be made, which
-- is what leaves the in-frame HUD as the fallback rather than no HUD at all.
local function snapped()
  return (session and session.snapped) and true or false
end

-- Put the map's cast back. Both lists are handed back by identity, so
-- anything that captured one before the battle still sees the same table.
local function restoreCast()
  if not (session and session.state) then return end
  if session.entities then session.state.entities = session.entities end
  if session.ghosts then session.state.ghosts = session.ghosts end
  session.entities, session.ghosts = nil, nil
end

-- Cull them. The player stays -- they are not an NPC, they are who the
-- battle belongs to, and Fly/surf animations and the save's own capture read
-- state.player through this list.
--
-- Only the DRAW lists are touched, and only while the overworld is frozen
-- underneath a battle: StateStack updates the top state alone, so nothing
-- walks, wanders, triggers or collides against a list that is short for
-- these frames. The originals go back at battle.ended.
local function cullCast(state)
  session.entities = state.entities
  session.ghosts = state.ghosts
  state.entities = { state.player }
  state.ghosts = {}
end

-- ------- one right battle layout
--
-- Everything this file composes is measured in the GB's own 160x144 frame: the
-- two ANCHORs the arena camera is solved to put a cell under, the HUD_RECTs
-- the frosted panels are cut to, and the full-frame white intercepted to let
-- the world through. BATTLE LAYOUT's WIDE lays the same battle out on a
-- 304x144 surface (src/battle/WideBattle.lua), which moves every one of those
-- -- the mons would stand where no camera was solved for them, and the panels
-- would land beside the HUDs they are supposed to be under.
--
-- So while a fight can be staged on the map there is one right answer, and it
-- is SET rather than worked around. The engine reads the option live
-- (BattleState:isWideBattleLayout is asked per frame, and Renderer asks the
-- top state for its surface the same way), so writing it here lands on the
-- battle being pushed as well as every one after it.
--
-- This is the last line rather than the first: the OPTIONS menu takes the row
-- off the list and pins the value while 3D-BTL is on (see main.lua), so a
-- player is never offered a switch that gets reverted under them. What reaches
-- here is a value that arrived some other way -- a save written before the mod
-- was installed, the mod manager's own page, another mod.
function OverworldBattle.forceOG(g)
  g = g or game()
  local opts = g and g.save and g.save.options
  if not opts or opts.battleLayout ~= "wide" then return false end
  opts.battleLayout = "og"
  if g.writeOptions then pcall(g.writeOptions, g) end
  return true
end

-- Where THIS fight stands, on whichever rung is running: the map's own
-- ground, or the pair of discs a B rung carries with it.
--
-- The one place the two columns actually diverge, and it is worth stating
-- plainly. On an A rung the answer can be NO -- a corridor, a shop floor, a
-- map whose authored entry is a refusal -- and the battle then plays exactly
-- as the vanilla game does. A B rung cannot fail: its stage is not something
-- the map has to have room for, so a fight in the tightest cave in Kanto is
-- staged as readily as one on Route 1.
local function exactGoldArena(state)
  local g = game()
  local world = g and g.world
  local p = state and state.player
  if not (world and p and state.map) then return nil end

  local tx = tonumber(world._stadiumFreeX)
    or ((tonumber(p.px) or ((tonumber(p.cellX) or 0) * 16)) + 8)
  local tz = tonumber(world._stadiumFreeZ)
    or ((tonumber(p.py) or ((tonumber(p.cellY) or 0) * 16)) + 8)

  local snap = world._stadiumEncounterSnapshot
  if snap and snap.mapId ~= nil and state.map.id ~= nil
     and tostring(snap.mapId) ~= tostring(state.map.id) then
    snap = nil
  end

  local ex, ez
  if snap then ex, ez = tonumber(snap.x), tonumber(snap.z) end

  -- MAP is still the frozen live world, but its presentation actors must not
  -- inherit an encounter coordinate that happens to be water, a hedge, a
  -- roof/structure cell or a blocked camera lane.  Solve the nearest complete
  -- physical-map composition first and require BattleArena's strict terrain,
  -- floor, camera-seat and three-ray visibility contract.
  local fromX = math.floor(((ex and (tx + ex) * 0.5 or tx) / 16))
  local fromY = math.floor(((ez and (tz + ez) * 0.5 or tz) / 16))
  local okSearch, searched = pcall(BattleArena.search, state.map,
    fromX, fromY, p.surfing, true)

  local function attachMetadata(arena, source)
    if not arena then return nil end
    arena.map = state.map
    arena.encounter = snap
    arena.encounterAnchor = (ex and ez) and { ex, ez } or nil
    arena.trainer = { tx, tz }
    arena.anchorSource = arena.anchorSource or source

    -- Put the trainer on the safe footprint searched above, nearest to the
    -- old shoulder pose but never on either combatant.  This is visual-only;
    -- the native Gold player and encounter metadata remain untouched.
    local px, pz = arena.player[1], arena.player[2]
    local enx, enz = arena.enemy[1], arena.enemy[2]
    local dx, dz = enx - px, enz - pz
    local dist = math.sqrt(dx * dx + dz * dz)
    if dist < 1 then dx, dz, dist = 0, -1, 1 end
    local ux, uz = dx / dist, dz / dist
    local desiredX, desiredZ = px - ux * 10 - uz * 20,
                               pz - uz * 10 + ux * 20
    local best, bestD
    if arena.x and arena.y and arena.w and arena.h then
      for cy = arena.y, arena.y + arena.h - 1 do
        for cx = arena.x, arena.x + arena.w - 1 do
          local wx, wz = cx * 16 + 8, cy * 16 + 8
          local pdx, pdz = wx - px, wz - pz
          local edx, edz = wx - enx, wz - enz
          if pdx * pdx + pdz * pdz >= 16 * 16
              and edx * edx + edz * edz >= 16 * 16
              and BattleArena.openCell(state.map, cx, cy, p.surfing) then
            local ddx, ddz = wx - desiredX, wz - desiredZ
            local d = ddx * ddx + ddz * ddz
            if not bestD or d < bestD then best, bestD = { wx, wz }, d end
          end
        end
      end
    end
    arena.trainerStand = best or { tx, tz }
    return arena
  end

  if okSearch and searched then
    -- A searched seat is not necessarily inside the frozen encounter lens.
    -- Render this physical-map arena through its validated BattleCam rig;
    -- exact snapshots alone retain the untouched encounter camera.
    searched.mapReframe = true
    -- The original lens solves a 160x144 GB slot. A searched MAP reframe owns
    -- the full desktop viewport, where that same vertical reach magnifies the
    -- pixel cards into HUDs and screen edges. Open only the lens, without
    -- moving the already validated eye or either terrain-safe mark.
    searched.mapFrameScale = (searched.cam == "wide" or searched.cam == "court"
      or searched.cam == "court_lift")
      and 1.6 or 2.2
    world._stadiumEncounterSnapshot = nil
    return attachMetadata(searched, "dynamic-gen2-clear")
  end

  local dx, dz = ex and (ex - tx) or 0, ez and (ez - tz) or 0
  local dist = math.sqrt(dx * dx + dz * dz)
  if dist < 1 then
    local facing = p.facing or "up"
    local d = ({ up={0,-1}, down={0,1}, left={-1,0}, right={1,0} })[facing]
              or {0,-1}
    dx, dz, dist = d[1], d[2], 1
  end
  local ux, uz = dx / dist, dz / dist

  -- Keep the pair centered on the encounter itself, but give the battle
  -- models enough separation for Stadium's camera and attack staging. A
  -- visible wild's stored point therefore anchors the battle area instead of
  -- being replaced by a pre-authored arena elsewhere on the map.
  local cx, cz
  if ex and ez then
    cx, cz = (tx + ex) * 0.5, (tz + ez) * 0.5
  else
    cx, cz = tx + ux * 20, tz + uz * 20
  end
  local halfGap = 20
  local px, pz = cx - ux * halfGap, cz - uz * halfGap
  local enx, enz = cx + ux * halfGap, cz + uz * halfGap
  -- Keep the trainer visibly attached to their Pokemon but out of the combat
  -- line: one shoulder to the outside and a little farther back. This is a
  -- presentation-only stand point; Gold's real player coordinates never move.
  local sideX, sideZ = -uz, ux
  local trainerX = px - ux * 10 + sideX * 20
  local trainerZ = pz - uz * 10 + sideZ * 20
  local bearing = math.atan2(ux, -uz)
  local deg = math.deg(bearing)
  local turn = (math.floor((deg + 45) / 90) * 90) % 360

  local exact = {
    x = math.floor(cx / 16), y = math.floor(cz / 16),
    shape = "encounter", cam = "tele", exact = true,
    turn = turn, bearing = bearing,
    playerCell = { math.floor(px / 16), math.floor(pz / 16) },
    enemyCell = { math.floor(enx / 16), math.floor(enz / 16) },
    player = { px, pz }, enemy = { enx, enz }, mid = { cx, cz },
    trainer = { tx, tz }, trainerStand = { trainerX, trainerZ }, map = state.map,
    encounter = snap,
  }

  -- A compact exact snapshot remains eligible only when the entire rectangle
  -- between its marks is ordinary legal ground on one level and the canonical
  -- battle lens sees both actors.  Give floorProfile the real inspected
  -- footprint rather than allowing a point-only composition to bypass it.
  local minX = math.min(exact.playerCell[1], exact.enemyCell[1])
  local maxX = math.max(exact.playerCell[1], exact.enemyCell[1])
  local minY = math.min(exact.playerCell[2], exact.enemyCell[2])
  local maxY = math.max(exact.playerCell[2], exact.enemyCell[2])
  exact.x, exact.y = minX, minY
  exact.w, exact.h = maxX - minX + 1, maxY - minY + 1
  local exactSafe = true
  for cy = exact.y, exact.y + exact.h - 1 do
    for cx2 = exact.x, exact.x + exact.w - 1 do
      if not BattleArena.openCell(state.map, cx2, cy, p.surfing) then
        exactSafe = false
      end
    end
  end
  exact.anchorHeight = exactSafe and BattleArena.floorProfile(state.map, exact)
    or nil
  exactSafe = exact.anchorHeight ~= nil
    and BattleArena.clearance(state.map, exact)
  if exactSafe then
    exact.anchorSource = "exact-gold-clear"
    world._stadiumEncounterSnapshot = nil
    return attachMetadata(exact, "exact-gold-clear")
  end

  -- There is no honest physical MAP composition.  Decline cleanly instead of
  -- inventing discs, accepting obstructed cells, or mislabelling an ARENA
  -- backdrop as MAP; begin() keeps the native battle lifecycle intact.
  world._stadiumEncounterSnapshot = nil
  return nil
end

function OverworldBattle.stageFor(state, plan)
  if isGoldGame() then
    local requested = plan and plan.mode
    if requested == nil then requested = selectedGoldBattleMode() end
    local mode = normalizeGoldBattleMode(requested)
    local arena = nil
    if mode == OverworldBattle.MAP then
      arena = exactGoldArena(state)
      -- MAP is the live/frozen voxel map itself.  A location painting belongs
      -- exclusively to ARENA: attaching it here made BattleScene treat the
      -- bitmap as a panorama and visibly hang a second arena in the sky above
      -- the real encounter terrain.
    elseif mode == OverworldBattle.ARENA then
      -- Gen 2 owns a private Johto/Kanto location-art catalog.  Resolve it
      -- before touching the physical-map selector; the latter remains the
      -- fail-open path for a missing/corrupt catalog or an unavailable image.
      local okPortable, portable = pcall(function()
        return V.require("BattleBackdrop").arena(state and state.map)
      end)
      local physical
      if not (okPortable and portable) then
        local okFind, found = pcall(BattleArena.find, state and state.map,
          state and state.player and state.player.cellX,
          state and state.player and state.player.cellY,
          state and state.player and state.player.surfing)
        physical = okFind and found or nil
      end
      arena = okPortable and portable or physical
      if arena and not arena.gen2ArenaSource then
        arena.gen2ArenaSource = "physical-map"
      end
    elseif mode == OverworldBattle.DISCS then
      local okStage, found = pcall(function()
        return V.require("StadiumStage").arena(state and state.map)
      end)
      if okStage then arena = found end
    end
    if arena then
      arena.map = arena.map or (state and state.map)
      arena.presentationMode = mode == OverworldBattle.MAP and "MAP"
        or mode == OverworldBattle.ARENA and "ARENA" or "DISCS"
    end
    return arena
  end
  if OverworldBattle.discs() and Voxel3D.available() then
    local okStage, arena = pcall(function()
      return V.require("StadiumStage").arena(state.map)
    end)
    if okStage and arena then return arena end
  end
  local okFind, arena = pcall(BattleArena.find, state.map,
                              state.player.cellX, state.player.cellY,
                              state.player.surfing)
  return (okFind and arena) or nil
end

local function beginGoldNativeOnly(state, battle, plan, reason)
  if battle == nil then return false end
  nextBattleToken = nextBattleToken + 1
  session = {
    state=state, arena=nil, battle=nil, logicBattle=battle,
    shot=nil, plan=plan, nativeOnly=true,
    armed=false, token=0, battleToken=nextBattleToken,
    presentationCommitted=false,
    renderFailures=0, presentationState="native",
    failureReason=reason and tostring(reason) or nil,
  }
  diagnostic("gen2-battle-presentation", {
    result="native", reason=reason, mode=plan and plan.mode,
    smartCamera=plan and plan.smartCamera,
    models=plan and plan.modelsEnabled,
    map=state and state.map and state.map.id,
  })
  return false
end

-- Stage a battle triggered from `state`, if this mode can. Returns true only
-- when VASC owns the scene transition. GAME DEFAULT still receives a tiny
-- immutable owner session so its HUD choice cannot change halfway through the
-- BattleState, but returns false and never culls/stages: Gold must run its own
-- complete cartridge transition and presentation in that case.
function OverworldBattle.begin(state, battle)
  if session then finishForReplacement() end
  local gold = isGoldGame()
  local plan = capturePresentationPlan()
  if gold and normalizeGoldBattleMode(plan.mode) == OverworldBattle.DEFAULT then
    return beginGoldNativeOnly(state, battle, plan, "GAME DEFAULT selected")
  end
  if not gold and not OverworldBattle.enabled() then return false end
  -- Gold's battle screen and world share one sceneCanvas. Only the compose
  -- bridge can place the voxel shot beneath the now-transparent native panel;
  -- without it, retain Gold's complete native transition/background.
  if gold and not goldCompositorReady then
    return beginGoldNativeOnly(state, battle, plan, "Gold compositor unavailable")
  end
  if not (state and state.map and state.player) then
    if gold then
      return beginGoldNativeOnly(state, battle, plan, "invalid overworld state")
    end
    return false
  end
  if not Voxel3D.available() then
    if gold then
      return beginGoldNativeOnly(state, battle, plan, "voxel renderer unavailable")
    end
    return false
  end

  local arena = OverworldBattle.stageFor(state, plan)
  if not arena then
    if gold then
      return beginGoldNativeOnly(state, battle, plan,
        tostring(plan.mode) .. " stage unavailable")
    end
    return false
  end

  -- Legacy Gen-1 wide layout is incompatible with the 160x144 arena solver.
  -- Gen-2 owns a native 160x144 battle surface already, so never mutate the
  -- player's unrelated saved battle-layout option on Gold/Silver/Crystal.
  if not gold then OverworldBattle.forceOG() end

  local liveScreen = nil
  if not gold then liveScreen = battle end
  nextBattleToken = nextBattleToken + 1
  session = { state = state, arena = arena,
              -- Do not write this as `isGoldGame() and nil or battle`: in Lua
              -- that expression always falls through to `battle` when the
              -- true arm is nil. v0.1.85 therefore stored the Gen-2 *logic*
              -- object here and tried to render it as a BattleState screen.
              battle = liveScreen,
              logicBattle = battle, shot = nil,
              plan = plan,
              armed = false, token = 0, battleToken = nextBattleToken,
              presentationCommitted = false,
              renderFailures = 0, presentationState = "unseen" }
  diagnostic("gen2-battle-presentation", {
    result="voxel", mode=plan.mode, smartCamera=plan.smartCamera,
    models=plan.modelsEnabled, standardHud=plan.standardHud,
    map=state.map and state.map.id,
    arenaMode=arena.presentationMode,
  })
  cullCast(state)
  BattleCam.reset()
  BattleCam.still = false
  BattleCam.steerable = true
  pcall(function() V.require("BattleCinematic").reset() end)
  -- and, on the STADIUM rung, the pair of models that will stand on this
  -- arena's two cells. Declines quietly on any other rung.
  pcall(function() V.require("Stadium").begin(arena) end)
  return true
end

-- The fallback entry point: a battle that arrived without going through the
-- overworld's own pushBattle (a link battle, a script pushing a BattleState
-- directly). Nothing visible depends on the cull for those -- the wipe has
-- already been and gone -- but the arena still has to be picked.
function OverworldBattle.ensure(battle)
  local screen = nil
  local logicBattle = battle
  if isGoldGame() and type(battle) == "table"
      and type(battle.battle) == "table" then
    screen = battle
    logicBattle = battle.battle
    if screen.tutorial == true or screen.contest == true
        or screen.safari == true or screen.link == true
        or logicBattle.tutorial == true or logicBattle.contest == true
        or logicBattle.safari == true or logicBattle.link == true then
      return false
    end
  end

  if session then
    if screen then
      -- A pushed Party/Summary page can expose the same `.battle` field but is
      -- not the BattleState that owns this presentation. Never bind or retire
      -- the live session for such a submenu.
      if not isGoldBattleScreen(screen) then return false end
      if session.battle == screen and session.logicBattle == logicBattle then
        local presented = presentationOf(screen)
        if presented ~= nil then session.presentationState = presented end
        return not session.nativeOnly and session.presentationState ~= "native"
      end
      if session.battle == nil and session.logicBattle == logicBattle then
        if presentationOf(screen) == "native" then
          OverworldBattle.finish(session.logicBattle)
          return false
        end
        session.battle = screen
        if session.nativeOnly then
          screen[PRESENTATION_KEY] = "native"
          session.presentationState = "native"
          return false
        end
        session.presentationState = presentationOf(screen) or "unseen"
        return true
      end
      -- A different concrete BattleState is a new encounter even when an
      -- engine or test driver reuses the same logic table. Retire the old
      -- arena before recovering it so no stage/cast/shot leaks forward.
      finishForReplacement()
    elseif logicBattle == session.logicBattle then
      return not session.nativeOnly
    else
      finishForReplacement()
    end
  end
  if screen and presentationOf(screen) == "native" then return false end
  local g = game()
  local ow = g and (g.world or g.overworld)
  if ow and ow.map then
    local state = ow
    if g.world and type(V.goldStateForWorld) == "function" then
      local okState, adapted = pcall(V.goldStateForWorld, ow)
      if okState and adapted then state = adapted end
    end
    local began = OverworldBattle.begin(state, logicBattle)
    if screen and session and session.logicBattle == logicBattle then
      session.battle = screen
      if session.nativeOnly then
        screen[PRESENTATION_KEY] = "native"
        session.presentationState = "native"
      else
        session.presentationState = presentationOf(screen) or "unseen"
      end
    end
    return began and session and session.presentationState ~= "native" or false
  end
  return false
end

-- The arena this battle is staged on, or nil. Read by the shot driver so a
-- screenshot can be labelled with the ground it was taken on.
function OverworldBattle.arena()
  return session and session.arena or nil
end

-- Bind the optional preset ARENA painting to the exact live BattleState (or
-- its exact logic owner).  A stale screen must never be able to decorate a
-- replacement battle, and MAP/DISCS must never inherit ARENA-only content.
-- `nil` is a valid, latched "use the authored portable fallback" choice.
function OverworldBattle.bindPresetArenaBackdrop(expectedOwner, choice)
  local arena = session and session.arena or nil
  if expectedOwner == nil or not session
      or not sessionMatchesOwner(session, expectedOwner)
      or type(arena) ~= "table"
      or arena.presentationMode ~= OverworldBattle.ARENA then
    return false
  end
  if choice ~= nil then
    if type(choice) ~= "table"
        or choice.surface ~= "arena.backdrop"
        or choice.slot ~= "ARENA_BACKDROP"
        or (choice.action ~= "add" and choice.action ~= "replace") then
      return false
    end
  end
  arena._vascPresetArenaBackdrop = choice
  return true
end

-- Retire only the exact live BattleState after an exception escaped update().
-- Gold's compose bridge catches that exception outside this module; without a
-- callback into the owner, a cold session still advertises pending=true and
-- can leave the physical window behind its black reveal cover indefinitely.
-- Keep the session as a native-only latch until the normal battle-ended path
-- calls finish(): destroying it here would let ensure() stage the same screen
-- again on the following compose heartbeat.
function OverworldBattle.failToNative(expectedOwner, reason)
  if not session or expectedOwner == nil
      or not sessionMatchesOwner(session, expectedOwner) then
    return false
  end

  local screen = session.battle
  session.shot = nil
  session.deployment = nil
  session.textures = nil
  session.animTex = nil
  session.snapped = false
  session.prewarmed = nil
  session.presentationCommitted = false
  session.renderFailures = 0
  session.nativeOnly = true
  session.broken = true
  session.presentationState = "native"
  session.failureReason = tostring(reason or "Gen-2 battle update failed")
  diagnostic("gen2-battle-presentation", {
    result="native-after-error", reason=session.failureReason,
    mode=session.plan and session.plan.mode,
    map=session.state and session.state.map and session.state.map.id,
  })
  if type(screen) == "table" then
    screen[PRESENTATION_KEY] = "native"
  end
  if session.state then session.state._stadiumLiveBattle = nil end
  BattleCam.still = false
  BattleCam.steerable = true
  pcall(function() V.require("BattleCinematic").reset() end)

  -- Stadium actors are presentation state, not battle logic. Drop them now so
  -- neither a later world frame nor cleanup diagnostics can observe the failed
  -- deployment. finish() deliberately remains idempotent and will call this
  -- cleanup again when the BattleState actually leaves the stack.
  pcall(function() V.require("Stadium").finish() end)
  pcall(function()
    V.mod.log:warn("Gen-2 live-world battle update failed: %s -- this exact "
      .. "battle stays native", session.failureReason)
  end)
  return true
end

function OverworldBattle.finish(expectedOwner)
  if not session then return end
  -- A delayed end/recovery callback from the preceding encounter must never
  -- tear down the new one. Only the exact bound BattleState or its exact logic
  -- owner may finish this session; internal watchdogs pass the owner observed.
  if expectedOwner ~= nil and not sessionMatchesOwner(session, expectedOwner) then
    return false
  end
  diagnostic("gen2-battle-finished", {
    mode=session.plan and session.plan.mode,
    presentation=session.presentationState,
    nativeOnly=session.nativeOnly == true,
    renderFailures=session.renderFailures,
    transitionBackground=session.transitionBackgroundReceipt
      and session.transitionBackgroundReceipt.owner or nil,
    transitionBackgroundFrames=session.transitionBackgroundReceipt
      and session.transitionBackgroundReceipt.frames or nil,
    transitionBackgroundFailure=session.transitionBackgroundReceipt
      and session.transitionBackgroundReceipt.failureReason or nil,
  })
  local g = game()
  if g and g.world then g.world._stadiumEncounterSnapshot = nil end
  if session.state then session.state._stadiumLiveBattle = nil end
  restoreCast()
  session = nil
  Voxel3D.camera = nil
  BattleCam.still = false
  BattleCam.steerable = true
  pcall(function() V.require("BattleCinematic").reset() end)
  pcall(function() V.require("Stadium").finish() end)
  return true
end

-- ------- per-frame
--
-- Driven from the voxel pipeline's update hook, which the engine ticks every
-- frame regardless of which state is on top -- including the frames the
-- transition wipe covers, which is what gets the arena's meshes built before
-- the first battle frame needs them.
--
-- The scene is rendered HERE rather than inside the battle's draw, because
-- update runs with no canvas bound: a 3D pass that binds a depth target and
-- unbinds to the screen when it is done cannot do that in the middle of
-- someone else's frame without putting the frame back itself.
function OverworldBattle.update(dt, mode)
  if not session then return end
  if session.broken then return end

  -- The live-world camera is built later inside VoxelScene. Carry the actual
  -- update delta across that render seam so 30/60/120-Hz hosts travel the same
  -- distance per second. Prewarm deliberately contributes zero elapsed time.
  session.frameDt = math.max(0, math.min(0.1, tonumber(dt) or 0))

  -- GoldBattleState.new can prepare the first shot during the engine's update
  -- phase, before Game2 binds sceneCanvas. Consume that exact shot on the next
  -- ordinary pipeline/compose tick instead of rendering it twice and advancing
  -- the battle camera twice before the first visible frame.
  if session.prewarmed and mode ~= "prewarm" then
    session.prewarmed = nil
    return
  end

  local g = game()
  local top = g and g.stack and g.stack:top()
  local ow = g and (g.world or g.overworld)
  local gold = g and g.world ~= nil
  local goldMode = gold and normalizeGoldBattleMode(
    session.plan and session.plan.mode) or nil
  local portableGold = gold and (goldMode == OverworldBattle.ARENA
    or goldMode == OverworldBattle.DISCS)
  -- Gold's overworld is NOT a stack state: empty stack means free roam. The
  -- transition arrives first and only later is the shared BattleState pushed,
  -- so do not mistake the transition object for the battle renderer.
  if gold then
    if top ~= nil then
      session.armed = true
      -- Current Gold's screen is src.ui.gen2.BattleState.  It is opaque but
      -- deliberately has no `isBattle` marker; the v0.1.85 hook therefore
      -- mistook it for an unrelated pushed screen and never rendered a shot.
      -- Match the actual Gen-2 battle object captured at pushBattleTransition
      -- instead.  Submenus pushed above it do not own that exact object.
      if type(top) == "table" and top.battle ~= nil
          and isGoldBattleScreen(top) then
        if session.battle == nil and top.battle == session.logicBattle then
          session.battle = top
          session.presentationState = presentationOf(top) or "unseen"
        elseif session.battle ~= top then
          OverworldBattle.finish(currentSessionOwner())
          return
        end
      end
    elseif session.armed then
      OverworldBattle.finish(currentSessionOwner())
      return
    end
  else
    if top ~= nil and top ~= ow then
      session.armed = true
    elseif session.armed then
      OverworldBattle.finish(currentSessionOwner())
      return
    end
  end

  -- Whether the shot is the player's to steer at all. BACK SPRITES pins
  -- their own mon to the GB's slot on the menu while the foe stands out on
  -- the map, and there is no angle that half-framed, half-solid
  -- composition survives -- so under it the camera holds the shot the rig
  -- was solved for (the slow drift aside, which was always there). Polled
  -- per frame rather than latched at battle start: the row is reachable
  -- from the mod manager's page mid-session.
  -- Gold's exact live-world MAP retains its world camera. A searched MAP
  -- footprint instead renders the validated BattleCam rig; portable stages
  -- use that rig too, with their own battle-start SMART contract.
  if not gold then
    BattleCam.steerable = not OverworldBattle.backPinned()
    -- the right stick, read as a rate before the rig is built from it: the
    -- wheel, the keys, the mouse and a drag all arrive as events and have
    -- already landed, but a stick is a HELD position and only a tick can
    -- turn it into travel (CamControl, which owns every one of those inputs)
    pcall(V.require("CamControl").tick, dt)
    BattleCam.update(dt)
  elseif portableGold then
    -- Portable Gold stages use BattleScene's solved rig. SMART CAMERA is a
    -- battle-start contract here: OFF holds the canonical authored shot;
    -- changing the setting mid-battle cannot make the camera jump.
    local smart = session.plan and session.plan.smartCamera == true
    BattleCam.steerable = smart
    BattleCam.still = not smart
    BattleCam.update(dt)
  elseif goldMode == OverworldBattle.MAP
      and session.arena and session.arena.mapReframe then
    -- Searched MAPs render BattleScene's rig, not the frozen live-world
    -- camera. Its zoom target is set by CamControl, but without this tick
    -- the rendered lens stayed at 1 forever. Preserve the validated seat
    -- and the existing no-idle-drift policy; only advance the manual lens.
    BattleCam.updateZoom(session.frameDt)
  end
  -- the battle only exists once it has been pushed; a session opened at
  -- pushBattle time has it, one opened from battle.started was handed it
  if not gold then
    session.battle = session.battle or (top ~= ow and top or nil)
  end
  -- Only the transition is a genuine cover.  Once Crystal's BattleState is
  -- visible, the live MAP/ARENA scene and its HUD are on screen and a covered
  -- slice may consume 30-50 ms (profile dependent) on every cold mesh resume.
  -- That made command/move selection trail physical input even though the
  -- battle logic itself was fast.  Keep the wide warm-up slice behind the
  -- reveal, then use the normal visible-frame budget for the whole fight.
  ChunkMesher.pump(gold and session.battle == nil)

  -- During Gold's transition there is no BattleState yet. Warm the map mesh,
  -- but wait to render combatants/UI textures until the actual battle screen
  -- exists.
  if gold and not session.battle then return end
  if gold then
    local presented = presentationOf(session.battle)
    if presented ~= nil then session.presentationState = presented end
  end
  if gold and session.nativeOnly then
    -- DEFAULT and every preflight failure are complete-cartridge contracts.
    -- Keep their exact owner latch alive, but never prepare a staged shot.
    session.presentationState = "native"
    session.battle[PRESENTATION_KEY] = "native"
    session.shot = nil
    session.deployment = nil
    return
  end
  if gold and session.presentationState == "native" then
    -- Once Gold's own canvas was visible, this encounter stays native. A
    -- renderer that becomes ready later must wait for the next BattleState,
    -- avoiding a visible native -> black -> voxel switch mid-fight.
    OverworldBattle.finish(session.battle)
    return
  end

  -- Free roam advances Weather from GoldVoxelBridge. BattleState replaces
  -- that update owner while a MAP/ARENA/DISCS fight is visible, so advance the
  -- same clock once here or rain becomes a frozen overlay for the whole fight.
  if Weather and type(Weather.update) == "function" then
    local weatherMap = (session.arena and session.arena.map)
      or (session.state and session.state.map)
    Weather.update(session.frameDt, weatherMap)
  end

  -- The STADIUM models, ahead of the pics, because what they decide is
  -- WHICH pics are needed: a side a model is standing on gets no billboard
  -- texture rendered for it at all (see Stadium.covers). Posed and skinned
  -- here too, once for the frame -- the sun pass, the camera and, in a
  -- headset, both eyes all draw the same skinned meshes.
  local okActors, actorErr = pcall(function()
    local host = (session.arena and session.arena.map) or session.state.map
    local stadium = V.require("Stadium")
    local groundY = BattleScene.groundY(host, session.arena)
    if not modelsEnabled() then
      -- Keep the live voxel battlefield, but release Stadium combatants and let
      -- Gold's original battle pics represent the Pokemon.
      if type(stadium.finish) == "function" then pcall(stadium.finish) end
    elseif gold and type(stadium.updateGen2) == "function" then
      stadium.updateGen2(dt, session.battle, groundY)
    else
      stadium.update(dt, session.battle, groundY)
    end
  end)
  if not okActors then error(actorErr, 0) end

  -- The mons' textures are rendered HERE, with no canvas bound, for the same
  -- reason the scene is: the pics layer binds its own targets, and doing that
  -- inside somebody else's frame means putting the frame back afterwards.
  local okTex, textures = pcall(OverworldBattle.textures, session.battle)
  if not okTex then error(textures, 0) end
  -- stashed for the VR eye pass, which stands these same pics on the map
  -- in ITS view of the world (VoxelScene's eyes path). Stashed HERE
  -- because rendering them binds canvases, which the eye pass -- mid-scene
  -- when it wants them -- must never do; reading a stashed canvas is free.
  session.textures = textures
  -- and the move-animation layer, for the same eyes -- rendered only
  -- while a headset is actually watching, because only the VR world
  -- pass draws it (the flat screen has the animations in-frame already)
  session.animTex = nil
  local okVR, vrOn = pcall(function()
    local vr = V.require("VR")
    return vr.active and vr.active() or false
  end)
  if okVR and vrOn and session.battle then
    local okA, anim = pcall(OverworldBattle.animTexture, session.battle)
    if okA then session.animTex = anim end
  end
  session.token = (session.token or 0) + 1
  local ok, shot, renderReason, renderStatus
  local deployment = gold and deploymentReceipt(session.battle) or nil
  local pendingActors = textures == nil
  if gold and goldMode == OverworldBattle.MAP
      and not (session.arena and session.arena.mapReframe) then
    -- Gold's battle backdrop is the ACTUAL frozen overworld frame, not a
    -- second BattleScene camera. Render the same VoxelScene the player was
    -- already looking at and let it draw the two live Stadium combatants in
    -- world space. The state was captured from GoldVoxelBridge before the
    -- transition, so camera, map, player and terrain all remain identical to
    -- the encounter frame.
    ok, shot, renderReason, renderStatus = pcall(function()
      local G = love and love.graphics
      if not G then return nil end
      local pw, ph
      local goldBridge = V and V.goldBridge
      if goldBridge and type(goldBridge.renderDimensions) == "function" then
        local okDim, a, b = pcall(goldBridge.renderDimensions)
        if okDim then pw, ph = tonumber(a), tonumber(b) end
      end
      if not (pw and ph and pw > 0 and ph > 0) then
        pw, ph = G.getDimensions()
      end
      local world = g and g.world
      local vw = tonumber(world and world.viewW)
      local vh = tonumber(world and world.viewH)
      if not (vw and vh and vw > 0 and vh > 0) then
        local ww, wh = G.getDimensions()
        local scale = 1
        if world and type(world.zoomScale) == "function" then
          local okScale, value = pcall(world.zoomScale, world)
          if okScale and tonumber(value) and tonumber(value) > 0 then
            scale = tonumber(value)
          end
        end
        vw, vh = math.max(1, math.ceil(ww / scale)),
                 math.max(1, math.ceil(wh / scale))
      end
      session.state._stadiumLiveBattle = true
      local canvas, reason, status = V.require("VoxelScene").render(
        session.state, pw, ph, vw, vh, nil)
      if not canvas then return nil, reason, status end
      local rendered = {
        canvas = canvas,
        liveWorld = true,
        goldStaged = true,
        presentationMode = "MAP",
        nativeHud = session.plan and session.plan.standardHud == true or nil,
        pw = pw, ph = ph,
        -- Kept for diagnostics and callers that label the battle site.
        arena = session.arena,
      }
      -- Gold's compositor draws the battle HUD after VoxelScene has returned.
      -- Publish the actor receipt on that exact frame as well as using it in
      -- VoxelScene's optional in-scene HUD path.  This prevents the compositor
      -- from falling back to the old screen-corner anchors.
      -- Consume the receipt captured before endScene restored camera state;
      -- recomputing it here can project the actors through a different pass.
      local projection = session.state._stadiumBattleProjection
      if projection then
        rendered.projectionSchema = projection.schema
        rendered.projectionToken = projection.token
        rendered.actorVisuals = projection.actorVisuals
        rendered.coordinateSpace = projection.coordinateSpace
        rendered.presentationReceipt = projection.presentationReceipt
        rendered.viewportW = projection.viewportW
        rendered.viewportH = projection.viewportH
      end
      return rendered
    end)
  else
    if gold and session.state then session.state._stadiumLiveBattle = nil end
    ok, shot, renderReason, renderStatus = pcall(
      BattleScene.render, session.state, session.arena,
      textures, session.token)
    if gold and ok and shot then
      shot.goldStaged = true
      shot.liveWorld = nil
      shot.presentationMode = goldMode == OverworldBattle.MAP and "MAP"
        or goldMode == OverworldBattle.ARENA and "ARENA" or "DISCS"
      shot.nativeHud = session.plan and session.plan.standardHud == true or nil
    end
  end
  if not ok then
    if session.presentationCommitted and session.shot
        and (not gold or sameDeployment(session.deployment, deployment))
        and (tonumber(session.renderFailures) or 0) < 2 then
      session.renderFailures = (tonumber(session.renderFailures) or 0) + 1
      if not session.renderFailureWarned then
        session.renderFailureWarned = true
        V.mod.log:warn("overworld battle scene missed a frame: %s -- holding "
          .. "the last committed presentation while the renderer retries",
          tostring(shot))
      end
      return
    end
    -- One failure retires the arena for THIS battle and nothing else: the
    -- battle screen carries on as the engine's own, the free-roam pipeline
    -- this runs inside keeps rendering the overworld, and the next battle
    -- tries again. Rethrowing would hand the whole voxel mode to Pipelines'
    -- guard, which retires a pipeline for the session.
    V.mod.log:warn("overworld battle scene failed: %s -- this battle draws "
                   .. "on the plain battle background", tostring(shot))
    OverworldBattle.failToNative(session.battle or session.logicBattle, shot)
    return
  end
  if not shot then
    -- The ordinary Gold voxel frame pumps this bounded queue itself. MAP and
    -- ARENA battle composition bypass that entry point, so a fresh map could
    -- otherwise remain an eternally incomplete nil frame and exhaust the
    -- retry budget into native 2D. Advance one normal slice before retrying.
    if gold and V and type(V.require) == "function" then
      local okMesher, mesher = pcall(V.require, "ChunkMesher")
      if okMesher and mesher and type(mesher.pump) == "function" then
        -- Reaching this branch requires a live Crystal BattleState.  Its
        -- staged world/HUD is therefore already the visible presentation;
        -- spend only the normal visible-frame slice while the missing mesh
        -- retries instead of adding a profile-dependent 30-50 ms covered
        -- slice to command and attack input.
        local okPump, pumpError = pcall(mesher.pump, false)
        if not okPump and not session.mesherPumpWarned then
          session.mesherPumpWarned = true
          V.mod.log:warn("Gen-2 battle mesh warmup failed: %s",
            tostring(pumpError))
        end
      end
    end
    local reason = tostring(renderReason or "renderer returned no canvas")
    local status = tostring(renderStatus or "pending")
    if session.lastNilReason ~= reason or session.lastNilStatus ~= status then
      session.lastNilReason, session.lastNilStatus = reason, status
      diagnostic("gen2-battle-render-wait", {
        result="pending", reason=reason, status=status,
        map=session.state and session.state.map and session.state.map.id,
        mode=goldMode,
      })
    end
    local retry, retain = retryAfterNilFrame(
      session, gold, deployment, mode)
    if retry then
      if retain then return end
      -- The old deployment is never eligible for publication while a new
      -- Pokémon is being prepared. Gold's compositor may keep its exact
      -- transition/switch cover only for this bounded replacement window.
      session.shot = nil
      session.deployment = nil
      session.snapped = false
      return
    end
    local waitLimit = session.presentationCommitted and session.shot
      and (not gold or sameDeployment(session.deployment, deployment))
      and MAX_TRANSIENT_SCENE_WAIT or MAX_COLD_SCENE_WAIT
    V.mod.log:warn("overworld battle scene produced no complete frame within "
      .. "its %.1fs retry window (%s/%s) -- this battle stays native",
      waitLimit, status, reason)
    OverworldBattle.failToNative(session.battle or session.logicBattle,
      ("scene retry window exhausted: %s/%s"):format(status, reason))
    return
  end
  session.renderFailures = 0
  session.nilFrameStartedAt = nil
  session.nilFrameElapsed = nil
  session.lastNilReason = nil
  session.lastNilStatus = nil
  session.renderFailureWarned = false
  session.snapped = false
  if shot and shot.canvas then
    shot.pendingActors = pendingActors and true or nil
    if pendingActors then
      session.deployment = nil
    else
      session.presentationCommitted = true
      if gold then session.deployment = deployment end
    end
  elseif gold then
    -- A declined replacement frame must never leave the preceding Pokémon's
    -- canvas eligible for publication under the new battle/HUD identity.
    session.deployment = nil
  end
  if shot and shot.canvas and not gold then
    -- the depth of field is measured off the two marks: the slab in focus is
    -- the one the mons are standing in, at whatever the drift has done to
    -- where that lands
    local y1 = shot.ly + shot.player[2] * shot.scale
    local y2 = shot.ly + shot.enemy[2] * shot.scale
    local focusY, band, range = BattleDOF.bandFor(y1, y2, shot.ph)
    local okDof, blurred = pcall(BattleDOF.apply, shot.canvas,
                                 focusY, band, range)
    if okDof and blurred then shot.canvas = blurred end
    -- the frosted glass the HUDs sit on is built from the FINISHED backdrop,
    -- so a panel over a blurred far field is frosted from what is actually
    -- behind it
    pcall(BattleHud.build, shot.canvas)
    -- and then the HUDs go ON that backdrop, snapped out to the window's own
    -- edges (snapHUDs). Here rather than in the battle's draw for the same
    -- reason the scene is: it binds a canvas of its own. After the frost, so
    -- the glass is frosted from the world alone and never from the glyphs
    -- about to sit on it.
    local ios = isIOS()
    local okHud, up = false, false
    if not ios then
      okHud, up = pcall(OverworldBattle.snapHUDs, session.battle, shot)
    end
    session.snapped = (okHud and up) and true or false
    -- once per battle, not once per frame: a driver that cannot do this cannot
    -- do it sixty times a second either, and the fallback is silent and fine
    if not ios and not okHud and not session.hudWarned then
      session.hudWarned = true
      V.mod.log:warn("overworld battle HUD snap failed: %s -- the HUDs draw "
                     .. "in the battle frame this battle", tostring(up))
    end
  end
  session.shot = shot
  if mode == "prewarm" and shot and shot.canvas then
    session.prewarmed = true
  end
end


-- Camera-facing context for the Stadium-style live-world orbit. Kept narrow so
-- the camera module does not reach into this file's private session table.
function OverworldBattle.cameraContext()
  if not (session and not session.broken and session.arena and session.battle) then return nil end
  local host = (session.arena and session.arena.map)
    or (session.state and session.state.map) or nil
  local groundY = host and BattleScene.groundY(host, session.arena) or 0
  return {
    arena = session.arena,
    -- The SMART director validates its lens against this exact live host.
    -- Portable DISCS may deliberately ignore terrain, but MAP/ARENA never
    -- infer a similarly named Gen-1 floor.
    map = host,
    groundY = groundY,
    -- Read-only render receipt for the shared Kanto HUD anchoring contract.
    -- VoxelScene projects these exact currently drawn cards after its camera
    -- matrix is final; BattleControllerUI never guesses from logical slots.
    textures = session.textures,
    token = session.token,
    battleToken = session.battleToken,
    screen = session.battle,
    battle = session.logicBattle,
    mode = session.plan and session.plan.mode or nil,
    smartCamera = session.plan and session.plan.smartCamera == true or false,
    frameDt = session.frameDt,
    plan = session.plan,
  }
end

-- Project the exact currently rendered Gen-2 side captures into the live
-- voxel camera. This is intentionally owned here, beside the arena/textures
-- session, so both VoxelScene's in-pass HUD and GoldComposeBridge's later
-- window composite consume one immutable actor receipt.
function OverworldBattle.actorProjection(w, h)
  local ctx = OverworldBattle.cameraContext()
  local diagnostic = { viewportW=w, viewportH=h, sides={} }
  OverworldBattle.lastActorProjectionDiagnostic = diagnostic
  if not (ctx and type(ctx.arena) == "table") then
    diagnostic.error = "camera-context-incomplete"
    return nil
  end
  local visuals = {}
  for _, side in ipairs({ "player", "enemy" }) do
    local cell = ctx.arena[side]
    local tex = type(ctx.textures) == "table" and ctx.textures[side] or nil
    local canvas = type(tex) == "table" and tex.canvas or nil
    diagnostic.sides[side] = {
      cell=type(cell), texture=type(tex), canvas=type(canvas),
    }
    if type(cell) == "table" and canvas
        and type(canvas.getDimensions) == "function" then
      local sourceW, sourceH = canvas:getDimensions()
      local captureW = tonumber(tex.captureW) or sourceW
      local captureH = tonumber(tex.captureH) or sourceH
      local pixelWorld = tonumber(tex.pixelWorld) or (32 / 56)
      local worldW, worldH = captureW * pixelWorld, captureH * pixelWorld
      local ox = -(((tonumber(tex.ax) or captureW * .5) / captureW) - .5)
        * worldW
      local oy = -((captureH - (tonumber(tex.ay) or captureH)) / captureH)
        * worldH
      local wx, wz = tonumber(cell[1]), tonumber(cell[2])
      local groundY = tonumber(ctx.groundY) or 0
      if wx and wz and worldW > 0 and worldH > 0 then
        local eye = Voxel3D.eye
        local yaw = eye and math.atan2(eye[1] - wx, eye[3] - wz) or 0
        local c, s = math.cos(yaw), math.sin(yaw)
        local box = type(tex.visualBox) == "table" and tex.visualBox or nil
        local bx = box and tonumber(box[1]) or 0
        local by = box and tonumber(box[2]) or 0
        local bw = box and tonumber(box[3]) or captureW
        local bh = box and tonumber(box[4]) or captureH
        if not (bx and by and bw and bh and bw > 0 and bh > 0) then
          bx, by, bw, bh = 0, 0, captureW, captureH
        end
        local left = ox + (bx / captureW - .5) * worldW
        local right = ox + ((bx + bw) / captureW - .5) * worldW
        local bottom = oy + (1 - (by + bh) / captureH) * worldH
        local top = oy + (1 - by / captureH) * worldH
        local points = {}
        for _, lx in ipairs({ left, right }) do
          for _, ly in ipairs({ bottom, top }) do
            local px, py = Voxel3D.project(wx + c * lx, groundY + ly,
              wz - s * lx)
            if px and py then points[#points + 1] = { px, py } end
          end
        end
        local centre = (left + right) * .5
        local hx, hy = Voxel3D.project(wx + c * centre, groundY + top,
          wz - s * centre)
        local fx, fy = Voxel3D.project(wx + c * centre, groundY + bottom,
          wz - s * centre)
        if #points == 4 and hx and hy and fx and fy then
          local minX, maxX = points[1][1], points[1][1]
          local minY, maxY = points[1][2], points[1][2]
          for i = 2, #points do
            minX, maxX = math.min(minX, points[i][1]),
              math.max(maxX, points[i][1])
            minY, maxY = math.min(minY, points[i][2]),
              math.max(maxY, points[i][2])
          end
          visuals[side] = {
            head={ x=hx, y=hy }, foot={ x=fx, y=fy },
            hull={ minX, minY, math.max(1, maxX-minX),
              math.max(1, maxY-minY) },
            canvas=canvas,
          }
          diagnostic.sides[side].projected = true
          diagnostic.sides[side].source = "battle-pic"
        end
      end
    end
    -- A loaded Stadium model deliberately suppresses its flat battle pic, so
    -- there is no texture canvas to measure. Project the model's live physical
    -- profile instead: this is the exact height/radius used by its world-space
    -- effects and follows send-out growth, Transform and species changes.
    if not visuals[side] and type(cell) == "table" then
      local okStadium, stadium = pcall(V.require, "Stadium")
      local okProfile, profile = false, nil
      if okStadium and stadium and type(stadium.effectProfile) == "function" then
        okProfile, profile = pcall(stadium.effectProfile, side)
      end
      if okProfile and type(profile) == "table" then
        local wx, wz = tonumber(profile.x), tonumber(profile.z)
        local radius = math.max(1, tonumber(profile.radius) or 4)
        local groundY = tonumber(profile.groundY) or 0
        local topY = groundY + math.max(4, tonumber(profile.height) or 18)
        local eye = Voxel3D.eye
        local yaw = eye and wx and wz
          and math.atan2(eye[1] - wx, eye[3] - wz) or 0
        local c, s = math.cos(yaw), math.sin(yaw)
        local points = {}
        if wx and wz then
          for _, lx in ipairs({ -radius, radius }) do
            for _, wy in ipairs({ groundY, topY }) do
              local px, py = Voxel3D.project(wx + c * lx, wy, wz - s * lx)
              if px and py then points[#points + 1] = { px, py } end
            end
          end
        end
        local hx, hy, fx, fy
        if wx then
          hx, hy = Voxel3D.project(wx, topY, wz)
          fx, fy = Voxel3D.project(wx, groundY, wz)
        end
        if #points == 4 and hx and hy and fx and fy then
          local minX, maxX = points[1][1], points[1][1]
          local minY, maxY = points[1][2], points[1][2]
          for i = 2, #points do
            minX, maxX = math.min(minX, points[i][1]),
              math.max(maxX, points[i][1])
            minY, maxY = math.min(minY, points[i][2]),
              math.max(maxY, points[i][2])
          end
          visuals[side] = {
            head={ x=hx, y=hy }, foot={ x=fx, y=fy },
            hull={ minX, minY, math.max(1, maxX-minX),
              math.max(1, maxY-minY) },
          }
          diagnostic.sides[side].projected = true
          diagnostic.sides[side].source = tostring(profile.source or "stadium-model")
        else
          diagnostic.sides[side].error = "model-profile-behind-camera"
        end
      else
        diagnostic.sides[side].error = "no-rendered-actor-profile"
      end
    end
  end
  if not (visuals.player or visuals.enemy) then
    diagnostic.error = "no-actor-projection"
    return nil
  end
  diagnostic.projected = true
  return {
    schema="voxel-ascendant/gen2-actor-projection/v1",
    viewportW=w, viewportH=h, token=ctx.token, actorVisuals=visuals,
  }
end

-- The finished shot for this frame, or nil when there is none and the battle
-- should draw the way it always did.
function OverworldBattle.shot()
  if not session or session.broken then return nil end
  local presented = presentationOf(session.battle)
  if presented ~= nil then session.presentationState = presented end
  if session.presentationState == "native" then return nil end
  local s = session.shot
  if s and s.canvas then return s end
  return nil
end

-- True only for the exact ordinary Gold BattleState whose staged live-world
-- session is still building its first drawable shot. The window compositor
-- uses this receipt to keep the transition's black cover up; it must never
-- hide a pushed submenu or a special/native encounter.
function OverworldBattle.pending(screen)
  if not (isGoldGame()
      and type(screen) == "table" and type(screen.battle) == "table"
      and session ~= nil and session.broken ~= true
      and session.battle == screen
      and (session.logicBattle == nil or session.logicBattle == screen.battle)) then
    return false
  end
  local presented = presentationOf(screen)
  if presented ~= nil then session.presentationState = presented end
  return session.presentationState ~= "native"
    and not (session.shot and session.shot.canvas)
end

-- The staged fight's WORLD-side pieces, for a pass that stands the mons in
-- its own view of the map rather than in the arena's composed shot -- the
-- VR eyes. Returns the two cards as BattleScene.monCards builds them (yawed
-- toward whatever Voxel3D.eye is at CALL time, so a per-eye caller gets
-- per-eye cards), the live textures table (for the hit-flash flag), and the
-- token the shadow signature keys on. nil while nothing is staged, the
-- arena is broken, or the pics have not been rendered yet.
function OverworldBattle.worldCards()
  if not (session and session.arena and not session.broken) then return nil end
  local tex = session.textures
  if not tex then return nil end
  local host = (session.state and session.state.map) or nil
  if not host then return nil end
  local groundY = BattleScene.groundY(host, session.arena)
  return BattleScene.monCards(session.arena, groundY, tex), tex, session.token
end

-- The live session's BATTLE STATE, once the pushed battle has been met
-- (session.battle fills in from the stack in update). The VR quad reads
-- it to tell "the battle screen is on top" from "a menu is over the
-- battle" -- the UI-only panel is right for the first and wrong for the
-- second. nil with no session, a broken one, or a battle not yet pushed.
function OverworldBattle.battle()
  if not (session and not session.broken) then return nil end
  return session.battle
end

function OverworldBattle.presentationPlan(expectedScreen)
  if expectedScreen ~= nil
      and (not session or session.battle ~= expectedScreen) then
    return nil
  end
  return session and session.plan or nil
end

-- Read-only QA receipt for the transition background bound to this encounter.
-- It is nil for native/default/special battles and remains exact to the active
-- session; callers must not retain it after the BattleState has finished.
function OverworldBattle.transitionBackgroundReceipt()
  return session and session.transitionBackgroundReceipt or nil
end

-- The move-animation layer as a texture: the engine's own drawAnimLayer,
-- rendered UNSHIFTED (slot-authored coordinates) into a GB-sized
-- transparent canvas of its own. This is what stands the effects up in
-- the VR eyes' world -- see worldAnim below -- the same move the pics
-- made through sideTexture: let the engine draw what it always draws,
-- catch it on a canvas, stand the canvas in the scene.
local animLayer = nil
-- the engine's own drawAnimLayer, captured by install(). Declared HERE,
-- above the function that reads it: a local declared further down the
-- chunk would leave this function reading a global of the same name --
-- nil forever, and the effects silently absent from the eyes (the bug
-- this comment is the tombstone of).
local innerAnim = nil

function OverworldBattle.animTexture(battle)
  if not battle then return nil end
  local runner = type(battle) == "table" and battle.anim or nil
  local view = type(battle) == "table" and battle.animView or nil
  local drawObjects = type(runner) == "table" and type(view) == "table"
    and type(view.drawObjects) == "function" and view.drawObjects or nil
  -- Current Game2 renders capture balls as BattleAnimView OAM objects.  Older
  -- builds exposed BattleState:drawAnimLayer instead.  Support both seams,
  -- preferring the current object layer so the thrown/shaking ball cannot be
  -- silently omitted merely because the legacy method is absent.
  if not (drawObjects or innerAnim) then return nil end
  if not (love.graphics and love.graphics.newCanvas) then return nil end
  if not animLayer then
    local ok, c = pcall(love.graphics.newCanvas,
                        BattleScene.GB_W, BattleScene.GB_H)
    if not (ok and c) then return nil end
    pcall(c.setFilter, c, "nearest", "nearest")
    animLayer = c
  end
  local g = love.graphics
  local prevCanvas = g.getCanvas()
  local ok = pcall(function()
    g.push("all")
    g.origin()
    g.setCanvas(animLayer)
    g.clear(0, 0, 0, 0)
    g.setBlendMode("alpha")
    g.setColor(1, 1, 1, 1)
    if drawObjects then view:drawObjects(runner, battle.battle)
    else innerAnim(battle, false) end
    g.pop()
  end)
  -- love.graphics functions are plain functions, not methods. Passing the
  -- graphics table as an implicit `self` makes both cleanup calls fail in
  -- LÖVE. During move/intro animation capture that left the window-sized
  -- battle Canvas bound and leaked one graphics push per frame until present()
  -- or the stack-depth guard aborted the game.
  if not ok then pcall(g.pop) end
  if prevCanvas then pcall(g.setCanvas, prevCanvas)
  else pcall(g.setCanvas) end
  return ok and animLayer or nil
end

-- The ORAS compositor replaces Gold's complete battle canvas, but a capture
-- is still authored and timed by Gold's ANIM_THROW_POKE_BALL runner. Lift
-- just that transparent layer onto the final viewport; ordinary move effects
-- remain owned by Gen2VascBattleAnimations and therefore cannot double-draw.
function OverworldBattle.drawCaptureAnimation(screen, projection, targetW, targetH)
  local anim = type(screen) == "table" and screen.anim or nil
  if not (type(anim) == "table" and anim.animId == "ANIM_THROW_POKE_BALL") then
    return false, "inactive"
  end
  local tex = OverworldBattle.animTexture(screen)
  local G = love and love.graphics
  if not (tex and G and type(G.draw) == "function") then
    return false, "capture animation texture unavailable"
  end
  targetW, targetH = tonumber(targetW), tonumber(targetH)
  if not (targetW and targetH and targetW > 0 and targetH > 0) then
    return false, "capture animation viewport unavailable"
  end
  local pageScale = math.min(targetW / BattleScene.GB_W,
                             targetH / BattleScene.GB_H)
  local ox = (targetW - BattleScene.GB_W * pageScale) * .5
  local oy = (targetH - BattleScene.GB_H * pageScale) * .5
  local visuals = type(projection) == "table" and projection.actorVisuals or nil
  local playerVisual = type(visuals) == "table" and visuals.player or nil
  local enemyVisual = type(visuals) == "table" and visuals.enemy or nil
  local function body(visual)
    local hull = type(visual) == "table" and visual.hull or nil
    if type(hull) ~= "table" then return nil end
    local x, y, w, h = tonumber(hull[1]), tonumber(hull[2]),
      tonumber(hull[3]), tonumber(hull[4])
    if not (x and y and w and h) then return nil end
    return x + w * .5, y + h * .62
  end
  local px, py = body(playerVisual)
  local ex, ey = body(enemyVisual)
  if px and ex then
    local adx = OverworldBattle.ANCHOR.enemy[1]
      - OverworldBattle.ANCHOR.player[1]
    local ady = OverworldBattle.ANCHOR.enemy[2]
      - OverworldBattle.ANCHOR.player[2]
    local span = math.sqrt((ex-px)^2 + (ey-py)^2)
    local authored = math.sqrt(adx^2 + ady^2)
    -- This layer already contains only 8px OBJ sprites.  Scaling it by the
    -- viewport page scale *and* the actor-span ratio made a single ball over
    -- 100px wide and expanded its authored flight beyond the opponent.  The
    -- actor-span ratio is itself the complete GB->world transform.
    local k = math.max(.75, math.min(4, span / authored))
    local amx = (OverworldBattle.ANCHOR.player[1]
      + OverworldBattle.ANCHOR.enemy[1]) * .5
    local amy = (OverworldBattle.ANCHOR.player[2]
      + OverworldBattle.ANCHOR.enemy[2]) * .5
    pageScale = k
    ox, oy = (px + ex) * .5 - amx * pageScale,
             (py + ey) * .5 - amy * pageScale
    -- `anim_keepsprites` leaves the caught ball visible after the opponent is
    -- hidden.  At that point its physical owner is the opponent's ground
    -- contact, not the old body centre.  Shift the retained OBJ layer so the
    -- ball rests on the floor; the flight itself keeps the authored arc.
    local captureState = 0
    local structs = type(anim.objects) == "table" and anim.objects.structs or nil
    for _, object in ipairs(type(structs) == "table" and structs or {}) do
      if object and object.index ~= 0
          and (object.func == "BATTLE_ANIM_FUNC_POKEBALL"
            or object.func == "BATTLE_ANIM_FUNC_POKEBALL_BLOCKED") then
        captureState = tonumber(object.jt) or 0
        break
      end
    end
    local caughtAndLatched = captureState >= 3 or (type(screen.ballThrow) == "table"
      and screen.ballThrow.caught == true
      and type(screen.picHidden) == "table"
      and screen.picHidden.enemy == true)
    if caughtAndLatched then
      local foot = type(enemyVisual) == "table" and enemyVisual.foot or nil
      local hull = type(enemyVisual) == "table" and enemyVisual.hull or nil
      local groundY = type(foot) == "table" and tonumber(foot.y)
        or (type(hull) == "table" and tonumber(hull[2])
          and tonumber(hull[4]) and hull[2] + hull[4] or nil)
      if groundY then oy = oy + (groundY - ey) - 8 * pageScale end
    end
  end
  G.push("all")
  G.origin()
  G.setBlendMode("alpha")
  G.setColor(1, 1, 1, 1)
  G.draw(tex, ox, oy, 0, pageScale, pageScale)
  G.pop()
  return true
end

-- The staged fight's effects, for the VR eyes: the animation layer plus
-- the plane to stand it on (BattleScene.fxCard -- anchored so a hit
-- authored at a slot lands on the mon standing in for that slot). nil
-- while nothing is staged or no layer was rendered this frame.
function OverworldBattle.worldAnim()
  if not (session and session.arena and not session.broken) then return nil end
  local tex = session.animTex
  if not tex then return nil end
  local host = (session.state and session.state.map) or nil
  if not host then return nil end
  local groundY = BattleScene.groundY(host, session.arena)
  local model = BattleScene.fxCard(session.arena, groundY,
                                   OverworldBattle.ANCHOR)
  if not model then return nil end
  return tex, model
end

-- Where the staged fight STANDS -- the arena and its floor height -- for a
-- camera that wants to look at it rather than draw it (the VR battle
-- mount). Answered as soon as the stage exists, textures or not: the
-- camera should be seated behind the fade before the first pic lands.
-- nil whenever no fight is staged on the world.
function OverworldBattle.stage()
  if not (session and session.arena and not session.broken) then return nil end
  local host = (session.state and session.state.map) or nil
  if not host then return nil end
  return session.arena, BattleScene.groundY(host, session.arena)
end

function OverworldBattle.invalidate()
  BattleDOF.invalidate()
  BattleHud.invalidate()
  BattlePics.invalidate()
  -- the STADIUM models hold meshes and textures of this graphics context
  -- like everything else here does
  pcall(function() V.require("Stadium").invalidate() end)
end

-- ------- the battle screen's background
--
-- BattleState opens by filling 160x144 white -- that fill IS the battle's
-- background, and in the colorized pipeline it is also the BG canvas's clear
-- (nothing else clears it, so skipping it outright would ghost last frame).
-- So for the length of one draw, that one call is intercepted: on the two
-- offscreen canvases it becomes a transparent clear, so the shade-remap pass
-- composites the HUD and the text box over the arena and leaves the empty
-- field showing it; on the screen it is simply dropped, because the UI canvas
-- has already been cleared transparent for the world to show through.
--
-- Matched exactly -- fill, the full frame, at the origin, in opaque white --
-- so the text box (a 20x6 box lower down), a mon pic, an HP bar and the
-- move-animation flash (which is white at 0.85) all pass through untouched.
--
-- This is a shim over love.graphics and it is the one invasive thing here,
-- so it is scoped as tightly as it can be: installed around a single call,
-- removed on the way out including on error, and never live outside a battle
-- frame this mode is drawing.
local function withoutBackgroundFill(battle, fn)
  local g = love.graphics
  local rectangle = g.rectangle
  g.rectangle = function(mode, x, y, w, h, ...)
    if mode == "fill" and x == 0 and y == 0
       and w == BattleScene.GB_W and h == BattleScene.GB_H then
      local r, gr, b, a = g.getColor()
      if r > 0.99 and gr > 0.99 and b > 0.99 then
        -- Two different full-frame whites, both replaced rather than drawn.
        --
        -- OPAQUE is the battle's background, and on the offscreen canvases it
        -- doubles as their clear, so there it becomes a transparent one.
        --
        -- TRANSLUCENT is the hit flash. Over a white field that reads as a
        -- flash; over a world it whites out the map, the HUD and the text box
        -- together. BattleScene puts it back on the mons alone.
        if a > 0.99 then
          local target = g.getCanvas()
          if target ~= nil
             and (target == battle.bgCanvas or target == battle.waveCanvas) then
            g.clear(0, 0, 0, 0)
          end
        end
        return
      end
    end
    return rectangle(mode, x, y, w, h, ...)
  end
  local ok, err = pcall(fn, battle)
  g.rectangle = rectangle
  if not ok then error(err, 0) end
end

-- ------- the box, without its paper
--
-- Font.drawBox is a white fill and then six border glyphs, and the fill is the
-- opaque slab the frosted panel underneath is there to replace. So for the
-- length of one drawTextArea the white fills are dropped and everything else
-- -- the border, the text, the cursor, the down arrow -- draws exactly as it
-- always did, over the glass instead of over paper.
--
-- Every fill drawTextArea issues is one of those: the box's own, and the two
-- eight-pixel cells MoveSelectionMenu wipes back to box white before it writes
-- the border glyphs that hardware would have overwritten. Both are opaque
-- white, both are paper, and both go.
--
-- The same shim shape as withoutBackgroundFill above, and scoped as tightly:
-- installed around a single call, removed on the way out including on error,
-- never live outside a battle frame this mode is drawing.
local function withoutBoxFill(battle, fn)
  local g = love.graphics
  local rectangle = g.rectangle
  g.rectangle = function(mode, ...)
    if mode == "fill" then
      local r, gr, b, a = g.getColor()
      if r > 0.99 and gr > 0.99 and b > 0.99 and a > 0.99 then return end
    end
    return rectangle(mode, ...)
  end
  local ok, err = pcall(fn, battle)
  g.rectangle = rectangle
  if not ok then error(err, 0) end
end

-- ------- the hour's light, on a pic that is not geometry
--
-- Everything standing in the arena goes through the voxel shader, and that
-- shader multiplies by the hour's tint: at dusk the whole diorama warms, at
-- night it goes blue, and the two mons' cards go with it because they are
-- drawn in the same pass as the ground they stand on.
--
-- A back pic pinned to the menu is not in that pass. It is the engine's own
-- flat blit over the finished shot, so it arrived at noon while the world
-- behind it was at midnight -- a mon lit by nothing in the frame.
--
-- So the tint is applied by hand, to that one draw. Every colour the pics
-- layer sets is multiplied on its way past, which is the whole of it: the
-- layer draws the pic with love.graphics.draw and LOVE multiplies by the draw
-- colour, so tinting the colour tints the pixels -- and the alpha, the faint
-- slide's fade and the blink's own colour all compose with it rather than
-- being overwritten.
--
-- What this does NOT get is the sun: the cards are shadow-mapped, so one
-- standing under a tree is darker than the tint alone, and this pic has no
-- position in the scene to be shadowed at. It carries the hour and not the
-- weather, which is the part the eye reads.
local function withTint(tint, fn, ...)
  if not tint then return fn(...) end
  local r, g, b = tint[1] or 1, tint[2] or 1, tint[3] or 1
  if r > 0.999 and g > 0.999 and b > 0.999 then return fn(...) end
  local gfx = love.graphics
  local setColor = gfx.setColor
  gfx.setColor = function(cr, cg, cb, ca, ...)
    if type(cr) == "table" then
      return setColor({ (cr[1] or 1) * r, (cr[2] or 1) * g, (cr[3] or 1) * b,
                        cr[4] }, cg, ...)
    end
    if cr == nil then return setColor(cr, cg, cb, ca, ...) end
    return setColor(cr * r, (cg or 1) * g, (cb or 1) * b, ca, ...)
  end
  local ok, err = pcall(fn, ...)
  gfx.setColor = setColor
  -- the layer leaves whatever colour it last set, and that one is tinted;
  -- hand the next caller plain white rather than a dimmed one
  setColor(1, 1, 1, 1)
  if not ok then error(err, 0) end
end

-- ------- the mons, as textures for the 3D pass
--
-- The two Pokemon are not composited over the world any more: they are quads
-- standing in it (see BattleBillboard). What that needs from the battle
-- screen is a TEXTURE per side -- and the honest way to get one is to let the
-- engine draw its own pics layer, unchanged, into a canvas.
--
-- So the layer is rendered twice, once per side, with the other side
-- falsified out of existence by nulling exactly the fields its branches
-- test. Everything the engine does to a pic comes along for free that way:
-- the trainer pic before the send-out, the grow-out-of-the-ball scale, the
-- faint slide, the damage blink, the squish, every SE displacement. None of
-- it is reimplemented and none of it can drift.
--
-- Two things are forced during that render. The scale, to 1, so the texture
-- carries the artwork's own pixels and the BILLBOARD does the sizing; and the
-- placement, so the pic lands centred on a known column with its feet on a
-- known row. That known point is what the quad is then hung from.
local TEX_AX, TEX_AY = 80, 96          -- forced pic centre and baseline
local TRAINER_AX, TRAINER_AY = 124, 56 -- the intro trainer pic's own slot

OverworldBattle.TEX_AX, OverworldBattle.TEX_AY = TEX_AX, TEX_AY

-- Which side is being rendered, or nil. The placement wrappers read it.
local texturing = nil

local texCanvas = {}
-- Gold owns a different BattleState class and draws each sharp Crystal pic
-- through drawPic(). Capture that authored side into a transparent GB-sized
-- carrier instead of scaling the complete 160x144 battle screen over the
-- voxel world. Weak state keys release the two canvases with each battle.
local goldPicCanvases = setmetatable({}, { __mode = "k" })
local goldInkBoxes = setmetatable({}, { __mode = "k" })
local goldNativeDrawPic = nil
local innerPics = nil                   -- captured by install()
local innerHUDs = nil                   -- likewise, for the snapped HUD layer
-- (innerAnim, their sibling, is declared up beside animTexture, which
-- sits earlier in the chunk than this group and must see the local)

local function texCanvasFor(side)
  local c = texCanvas[side]
  if c then return c end
  local ok, made = pcall(love.graphics.newCanvas, BattleScene.GB_W,
                         BattleScene.GB_H, { dpiscale = 1 })
  if not ok or not made then
    error(("Gen-2 legacy %s battle-pic Canvas allocation failed: %s")
      :format(tostring(side), tostring(made)), 0)
  end
  made:setFilter("nearest", "nearest")
  texCanvas[side] = made
  return made
end

local function goldCanvasFor(screen, side)
  if not (love and love.graphics and love.graphics.newCanvas) then return nil end
  local pair = goldPicCanvases[screen]
  if not pair then pair = {}; goldPicCanvases[screen] = pair end
  if pair[side] then return pair[side] end
  local ok, canvas = pcall(love.graphics.newCanvas,
    BattleScene.GB_W, BattleScene.GB_H, { dpiscale = 1 })
  if not ok or not canvas then
    ok, canvas = pcall(love.graphics.newCanvas,
      BattleScene.GB_W, BattleScene.GB_H)
  end
  if not ok or not canvas then
    error(("Crystal %s battle-pic Canvas allocation failed: %s")
      :format(tostring(side), tostring(canvas)), 0)
  end
  if type(canvas.setFilter) == "function" then
    pcall(canvas.setFilter, canvas, "nearest", "nearest")
  end
  pair[side] = canvas
  return canvas
end

local function capturedInkBox(screen, side, canvas, identity)
  local pair = goldInkBoxes[screen]
  if not pair then pair = {}; goldInkBoxes[screen] = pair end
  local hit = pair[side]
  if hit and hit.identity == identity then return hit.rect end
  -- Only sample a settled command frame. Send-out/squash/faint frames alter
  -- the canvas on purpose and must never become the persistent head anchor.
  if screen.phase ~= "menu" and screen.phase ~= "moves" then return nil end
  local rect
  local ok = pcall(function()
    local data = canvas:newImageData()
    local w, h = data:getDimensions()
    local x0, y0, x1, y1 = w, h, -1, -1
    for y = 0, h - 1 do
      for x = 0, w - 1 do
        local _, _, _, a = data:getPixel(x, y)
        if a > 0.02 then
          x0, y0 = math.min(x0, x), math.min(y0, y)
          x1, y1 = math.max(x1, x), math.max(y1, y)
        end
      end
    end
    if x1 >= x0 then rect = { x0, y0, x1-x0+1, y1-y0+1 } end
    if data.release then pcall(data.release, data) end
  end)
  if ok and rect then pair[side] = { identity=identity, rect=rect } end
  return rect
end

-- Gen2 equivalent of the mature Gen1 side-texture contract. The full carrier
-- stays 160x144 so Gold's own placement/animation code remains authoritative;
-- only the roughly 56px authored pic contains ink. BattleScene consequently
-- gives a full-size Pokemon one 16-world-pixel footprint, exactly like Red.
local function goldSideTexture(screen, side)
  if not (type(screen) == "table" and type(screen.battle) == "table"
      and type(goldNativeDrawPic) == "function") then return nil end
  local playerSide = side == "player"
  if not playerSide and side ~= "enemy" then return nil end
  local enemyTrainerCapture = (not playerSide)
    and screen.showEnemyTrainer == true
  local portableTrainerCapture = playerSide
    and (screen.showPlayerBack == true or screen.showPlayerTrainer == true)
    and screen.showEnemyTrainer ~= true and screen.enemySendingOut ~= true
  -- Every live-world stage uses a dedicated battle trainer standee. Keeping
  -- the walking overworld entity in MAP mode made it survive the send-out and
  -- left a locomotion pose in the combat line. The engine flag above owns the
  -- lifetime, so the trainer disappears at precisely the native send-out step.
  if playerSide and (screen.showPlayerBack or screen.showPlayerTrainer)
      and not portableTrainerCapture then
    return nil
  end
  if playerSide and screen.slidingBackpic and not portableTrainerCapture then
    return nil
  end
  if type(screen.picHidden) == "table" and screen.picHidden[side] then return nil end

  local mon = resolvedGoldMon(screen, side, screen.battle)
  if not mon then return nil end
  local okStadium, stadium = pcall(V.require, "Stadium")
  if okStadium and stadium and type(stadium.visible) == "function" then
    local okVisible, visible = pcall(stadium.visible, side)
    if not okVisible then
      error(("Crystal %s Stadium visibility failed: %s")
        :format(tostring(side), tostring(visible)), 0)
    end
    -- A Stadium Pokemon model may already be marked visible while the native
    -- trainer intro flag still owns the stage. Trainer art wins until Gen 2
    -- clears that flag; afterwards the model/Pokemon path resumes normally.
    if okVisible and visible == true
        and not (portableTrainerCapture or enemyTrainerCapture) then return nil end
  end
  if type(screen.animPicState) == "function" then
    local ok, anim = pcall(screen.animPicState, screen, side)
    if not ok then
      error(("Crystal %s animation visibility failed: %s")
        :format(tostring(side), tostring(anim)), 0)
    end
    if ok and type(anim) == "table" and anim.hidden then return nil end
  end
  if type(screen.isVanished) == "function"
      and not (screen.vanishAnim and screen.vanishAnim == screen.anim) then
    local ok, vanished = pcall(screen.isVanished, mon)
    if not ok then
      error(("Crystal %s vanish-state resolution failed: %s")
        :format(tostring(side), tostring(vanished)), 0)
    end
    if ok and vanished
        and not (enemyTrainerCapture or portableTrainerCapture) then return nil end
  end

  local trainerCapture = enemyTrainerCapture or portableTrainerCapture
  if trainerCapture and Gen2TrainerArt
      and type(Gen2TrainerArt.resolve) == "function" then
    local okArt, custom = pcall(Gen2TrainerArt.resolve, screen, side)
    if not okArt then
      diagnostic("gen2-battle-trainer-art", {
        side=side, source="native-fallback", reason=tostring(custom),
      })
    elseif custom then
      return custom
    end
  end

  local canvas = goldCanvasFor(screen, side)
  if not canvas then return nil end
  -- Gold's native BattleState must retain its real player rear for a complete
  -- DEFAULT/cartridge fallback. The live-world billboard is an isolated
  -- capture, so request front art without mutating the BattleState, battler or
  -- mon. `drawPic(..., false)` also selects Gold's *enemy* animation slot;
  -- feed it a render-only proxy which maps that slot back to the player's
  -- visibility/faint state and disables the unrelated enemy-trainer override.
  local renderBack = portableTrainerCapture and true or false
  local captureScreen = screen
  if enemyTrainerCapture and type(Gen2TrainerArt.nativeCaptureScreen)=="function"then
    captureScreen=Gen2TrainerArt.nativeCaptureScreen(screen,side)
  end
  if portableTrainerCapture then
    -- drawScene temporarily raises this flag while the native intro bands are
    -- moving, because presentSlide draws the trainer separately. Our isolated
    -- portable-stage capture is that separate draw, fixed at its final anchor.
    captureScreen = setmetatable({ slidingBackpic=false }, { __index=screen })
  elseif playerSide then
    local hidden = type(screen.picHidden) == "table" and screen.picHidden or {}
    local proxy = {
      showEnemyTrainer=false,
      enemyTrainerImage=nil,
      enemyTrainerPath=nil,
      enemyTrainerTrueColor=false,
      trainerSlide=nil,
      picHidden={ enemy=hidden.player == true },
    }
    proxy.animPicState = function()
      if type(screen.animPicState) ~= "function" then return nil end
      return screen:animPicState("player")
    end
    proxy.faintSink = function()
      if type(screen.faintSink) ~= "function" then return 0 end
      return screen:faintSink("player")
    end
    setmetatable(proxy, { __index=screen })
    captureScreen = proxy
  end
  local G = love.graphics
  local previous = type(G.getCanvas) == "function" and G.getCanvas() or nil
  local guarded = packResults(withGraphicsBoundary(
    "Crystal " .. tostring(side) .. " battle-pic capture", function()
    G.origin()
    G.setCanvas(canvas)
    G.clear(0, 0, 0, 0)
    G.setBlendMode("alpha")
    G.setColor(1, 1, 1, 1)
    return goldNativeDrawPic(captureScreen, mon, renderBack)
  end))
  local okRestore, restoreErr = true, nil
  if type(G.setCanvas) == "function" then
    if previous then
      okRestore, restoreErr = pcall(G.setCanvas, previous)
    else
      okRestore, restoreErr = pcall(G.setCanvas)
    end
  end
  if not guarded[1] or not okRestore then
    local failures = {}
    if not guarded[1] then
      failures[#failures + 1] = "draw: " .. tostring(guarded[2])
    end
    if not okRestore then
      failures[#failures + 1] = "Canvas restore: " .. tostring(restoreErr)
    end
    error(("Crystal %s battle-pic capture failed: %s")
      :format(tostring(side), table.concat(failures, "; ")), 0)
  end

  local ax, ay = renderBack and 40 or 124, renderBack and 96 or 56
  -- The capture canvas is the complete 160x144 Game Boy battle layer, but the
  -- Pokemon itself occupies only its cartridge-authored pic box. Publish that
  -- box so world HUDs anchor to the visible head rather than to the transparent
  -- top edge of the full capture (which looked like a fixed corner HUD).
  local visualBox = renderBack and { 16, 48, 48, 48 }
                               or { 96, 0, 56, 56 }
  -- Refine the box to the rendered species picture. Small Crystal sprites are
  -- bottom-aligned in the cartridge box; treating every one as 56px tall put
  -- its projected "head" a long way above the visible ink. This mirrors the
  -- native drawPic placement without a per-frame GPU readback.
  pcall(function()
    local image, _, path = captureScreen:pic(mon, renderBack)
    if not (image and type(image.getDimensions) == "function") then return end
    local pw, ph = image:getDimensions()
    if not (pw and ph and pw > 0 and ph > 0) then return end
    local boxTiles = renderBack and 6 or 7
    local box = boxTiles * 8
    local px = (renderBack and 2 or 12) * 8
      + (renderBack and math.floor((box - pw) / 2)
         or math.max(0, math.floor((box - pw) / 2)))
    local py = (renderBack and 6 or 0) * 8
      + (renderBack and (box - ph) or math.max(0, box - ph))
    local scale = type(captureScreen.picScale) == "function"
      and tonumber(captureScreen:picScale(path, mon, renderBack)) or 1
    scale = scale or 1
    local anim = type(captureScreen.animPicState) == "function"
      and captureScreen:animPicState(renderBack and "player" or "enemy") or nil
    local resized = anim and anim.size
      and ({ [0]=6, [1]=4, [2]=2, [3]=7, [4]=5, [5]=3 })[anim.size]
    if resized then scale = scale * resized / boxTiles end
    if anim and not captureScreen.liftedPass then px = px + (anim.slide or 0) end
    if scale ~= 1 then
      px = px + math.floor(pw * (1 - scale) / 2)
      py = py + math.floor(ph * (1 - scale))
    end
    local ix, iy, iw, ih = type(BattlePics.inkRect) == "function"
      and BattlePics.inkRect(image) or nil
    if ix then
      visualBox = { px + ix * scale, py + iy * scale,
                    math.max(1, iw * scale), math.max(1, ih * scale) }
    else
      visualBox = { px, py, math.max(1, pw * scale), math.max(1, ph * scale) }
    end
  end)
  local sampled = not trainerCapture
    and capturedInkBox(screen, side, canvas, mon)
  if sampled then visualBox = sampled end
  return {
    canvas=canvas, ax=ax, ay=ay,
    trainer=trainerCapture,
    trainerArt=trainerCapture,
    inkIdentity=enemyTrainerCapture and screen.enemyTrainerImage
      or portableTrainerCapture and screen.playerBackImage or mon,
    captureW=BattleScene.GB_W, captureH=BattleScene.GB_H,
    visualBox=visualBox,
    vascRenderBattler=screen.battle[side],
    vascRenderMon=mon,
    vascRenderModelKey=tostring(mon.species or mon.id or side),
    vascRenderTextureToken=canvas,
    vascSpriteView=renderBack and "back" or "front",
    source="gen2-native-side-capture",
  }
end

-- Whether this side has anything to draw at all. Mirrors drawPicsLayer's own
-- guards, so an empty canvas is never hung on a quad: a fainted, hidden or
-- not-yet-sent-out mon simply has no billboard this frame.
local function sideVisible(battle, side)
  if side == "enemy" then
    if battle.showEnemyTrainer and battle.trainerPic then return true end
    return (battle.enemy and battle.enemy.sprite and not battle.enemyHidden
            and not battle.enemySendingOut
            and not battle:fxHidden(battle.enemy)) and true or false
  end
  if battle.showPlayerBack and battle.playerBackPic then return true end
  local hide = battle.safari or battle.demo
  return (battle.player and battle.player.sprite and not hide
          and not battle.sendingOut
          and not battle:fxHidden(battle.player)) and true or false
end

local OFF = {
  enemy = { player = false, showPlayerBack = false },
  player = { enemy = false, showEnemyTrainer = false },
}

-- Render one side's pics layer into its canvas and report where the pic's
-- feet ended up, in canvas coordinates.
function OverworldBattle.sideTexture(battle, side)
  if type(battle) == "table" and type(battle.battle) == "table" then
    return goldSideTexture(battle, side)
  end
  if not (innerPics and battle) then return nil end
  -- On the STADIUM rung a side standing a MODEL needs no pic: rendering one
  -- anyway would hang a second, flat copy of the same Pokemon on the same
  -- cell. Asked per side, so a species with no pack -- or a substitute
  -- doll, or the trainer before the send-out -- still comes through here.
  local okS, covered = pcall(function()
    return V.require("Stadium").covers(battle, side)
  end)
  if okS and covered then return nil end
  if not sideVisible(battle, side) then return nil end
  local canvas = texCanvasFor(side)
  if not canvas then return nil end

  local g = love.graphics
  local prevCanvas = g.getCanvas()
  local prevBlend, prevAlpha = g.getBlendMode()
  -- The pic-window scissors are in the battle screen's fixed coordinates and
  -- would clip a pic that has been moved to the middle of its own canvas.
  -- There is nothing here for them to protect -- no HUD, no text box, just
  -- the one pic -- so they are switched off for the render.
  local setScissor, intersectScissor = g.setScissor, g.intersectScissor
  local getScissor = g.getScissor
  g.setScissor = function() end
  g.intersectScissor = function() end
  g.getScissor = function() return nil end

  local saved = {}
  for k, v in pairs(OFF[side]) do saved[k] = battle[k]; battle[k] = v end
  texturing = side

  local ok, err = pcall(function()
    g.setCanvas(canvas)
    g.clear(0, 0, 0, 0)
    g.setBlendMode("alpha")
    g.setColor(1, 1, 1, 1)
    innerPics(battle, 0, 0, 0)
  end)

  texturing = nil
  for k in pairs(OFF[side]) do battle[k] = saved[k] end
  g.setScissor, g.intersectScissor, g.getScissor =
    setScissor, intersectScissor, getScissor
  if prevCanvas then g.setCanvas(prevCanvas) else g.setCanvas() end
  g.setBlendMode(prevBlend or "alpha", prevAlpha)
  if not ok then error(err, 0) end

  local ax, ay = TEX_AX, TEX_AY
  local trainer = false
  -- The intro trainer pic draws itself straight into its own 7x7 slot rather
  -- than through the placement helpers, so it is hung from that slot instead.
  if side == "enemy" and battle.showEnemyTrainer and battle.trainerPic then
    ax, ay, trainer = TRAINER_AX, TRAINER_AY, true
  elseif side == "player" and battle.showPlayerBack and battle.playerBackPic then
    trainer = true
  end
  return { canvas = canvas, ax = ax, ay = ay, trainer = trainer }
end

-- Whether the hit flash is showing this frame.
--
-- Mirrors BattleState:draw's own test, because the flash is a DRAW-time
-- decision there (a counter plus the frame parity that makes it flicker) and
-- there is no seam that reports it. Read-only, so the worst a future engine
-- change can do is flash on a frame the engine would not have.
function OverworldBattle.flashing(battle)
  local fx = battle and battle.fx
  if not (fx and fx.flash and fx.flash > 0) then return false end
  return (battle.frame or 0) % 4 < 2
end

-- Both sides, or nil when neither has anything to show.
--
-- One side under BACK SPRITES: the player's mon is not standing on the map at all
-- there, it is on the menu, so it has no card to be a texture for -- and
-- nothing downstream has to know that. No billboard, and no shadow on the
-- ground under a mon that is not on it.
function OverworldBattle.textures(battle)
  if not battle then return nil end
  local out = {}
  local okE, enemy = pcall(OverworldBattle.sideTexture, battle, "enemy")
  local okP, player = true, nil
  if not OverworldBattle.backPinned() then
    okP, player = pcall(OverworldBattle.sideTexture, battle, "player")
  end
  if not okE then error(enemy, 0) end
  if not okP then error(player, 0) end
  out.enemy = okE and enemy or nil
  out.player = okP and player or nil
  -- On the STADIUM rung both sides can legitimately have no pic -- the pair
  -- of them are models -- and this table must still come back, because it
  -- carries the HIT FLASH, and because the VR eye pass uses its presence to
  -- decide there is a staged fight to draw at all.
  local okStanding, standing = pcall(function()
    return V.require("Stadium").standing()
  end)
  if not okStanding then error(standing, 0) end
  if not (out.enemy or out.player or (okStanding and standing)) then
    return nil
  end
  out.flash = OverworldBattle.flashing(battle)
  return out
end

-- ------- engine seams
--
-- Four wraps, each idempotent so a hot reload cannot stack them.

-- Current Gold's battle UI is a separate class from the Gen-1 BattleState
-- this module originally wrapped.  v0.1.85 only patched the latter, so even a
-- successfully rendered encounter-site canvas was covered by Gen2's opaque
-- white panel and its flat Pokemon pics.  Keep the Gold shim deliberately
-- small: Gold continues to own every menu/HUD/text/animation; we only make the
-- field transparent and omit the flat copy already owned by the staged shot.
local function goldShotFor(screen)
  if nativeFallbackDepth > 0
      or not (session and not session.broken and session.battle == screen) then
    return nil
  end
  local shot = session.shot
  return (shot and shot.canvas) and shot or nil
end

-- Re-enter Gold's own battle renderer with every live-world presentation
-- override suspended. This is the fail-open path used when a voxel composite
-- fails after native pics/trainers were already omitted from sceneCanvas.
function OverworldBattle.drawGoldNativeFallback(winW, winH)
  local screen = session and session.battle
  if not (screen and type(goldNativeDrawWidescreen) == "function") then
    return false, "native Gen-2 battle screen is unavailable"
  end
  nativeFallbackDepth = nativeFallbackDepth + 1
  local ok, err = pcall(goldNativeDrawWidescreen, screen,
    tonumber(winW) or 160, tonumber(winH) or 144)
  nativeFallbackDepth = math.max(0, nativeFallbackDepth - 1)
  if not ok then return false, tostring(err) end
  return true
end

local function installGoldBattleState()
  local okState, GoldBattleState = pcall(require, "src.ui.gen2.BattleState")
  if not okState or type(GoldBattleState) ~= "table" then return false end
  goldBattleScreenClass = GoldBattleState
  if GoldBattleState.stadiumInWorldBattleUiHook then return true end

  local okChrome, Chrome = pcall(require, "src.ui.gen2.Chrome")
  if not okChrome or type(Chrome) ~= "table" then return false end

  -- Bind the presentation screen as soon as Gold constructs it. Waiting for
  -- the next compose update leaves the first sceneCanvas opaque white even
  -- though the encounter was staged successfully.
  if type(GoldBattleState.new) == "function" then
    local innerNew = GoldBattleState.new
    function GoldBattleState.new(gameValue, opts, ...)
      local screen = innerNew(gameValue, opts, ...)
      if type(screen) == "table" then
        screen._vascGen2BattleScreenOwner = true
      end
      if session and not session.battle and type(screen) == "table"
          and (session.logicBattle == nil
            or (opts and opts.battle == session.logicBattle)
            or screen.battle == session.logicBattle) then
        session.battle = screen
        if session.nativeOnly then
          screen[PRESENTATION_KEY] = "native"
          session.presentationState = "native"
        else
          session.presentationState = presentationOf(screen) or "unseen"
        end
        -- Screens.push constructs this state from World:startBattle's update
        -- callback, when no present canvas is bound. Build the first live-world
        -- shot here so drawWidescreen can decide between transparent native UI
        -- and Gold's complete white fallback without ever starting a nested 3D
        -- pass from inside Game2:draw(). If a future host constructs screens
        -- while a canvas is bound, decline the prewarm and fail open instead.
        local G = love and love.graphics
        local canPrewarm = true
        if G and type(G.getCanvas) == "function" then
          local okCanvas, canvas = pcall(G.getCanvas)
          canPrewarm = okCanvas and canvas == nil
        end
        if canPrewarm and session.presentationState ~= "native" then
          pcall(OverworldBattle.update, 0, "prewarm")
        end
      end
      return screen
    end
  end

  -- BattlePack normally remembers the last field pocket. Wild encounters are
  -- capture-first: start directly on BALL while leaving the field PACK's
  -- remembered pocket and all item rules untouched.
  if type(GoldBattleState.openPack) == "function"
      and not GoldBattleState._vascWildBallPocketHook then
    local innerOpenPack = GoldBattleState.openPack
    function GoldBattleState:openPack(...)
      local battle = type(self.battle) == "table" and self.battle or nil
      if not (battle and battle.wild == true) then
        return innerOpenPack(self, ...)
      end
      local gameValue = self.game
      if type(gameValue) ~= "table" then return innerOpenPack(self, ...) end
      gameValue.packCursor = gameValue.packCursor
        or { cursor = {}, scroll = {} }
      local previous = gameValue.packCursor.pocket
      gameValue.packCursor.pocket = "BALL"
      local out = packResults(pcall(innerOpenPack, self, ...))
      gameValue.packCursor.pocket = previous
      if not out[1] then error(out[2], 0) end
      return unpackResults(out, 2, out.n)
    end
    GoldBattleState._vascWildBallPocketHook = true
  end

  -- Current Gold's AnimRunner stores the requested animation id in
  -- `runner.env.animId`, while BattleState:latchCaughtPic and this live-world
  -- compositor read the public `runner.animId` field.  Native 2-D happens to
  -- draw the OAM without that alias, but MAP/ARENA therefore omitted the ball
  -- and the successful-catch latch never hid the opponent.  Normalize only
  -- the ball runner at its native construction seam; timing, commands and
  -- catch logic remain wholly engine-owned.
  if type(GoldBattleState.startBallAnim) == "function"
      and not GoldBattleState._vascBallRunnerIdCompat then
    local innerStartBallAnim = GoldBattleState.startBallAnim
    function GoldBattleState:startBallAnim(...)
      local started = innerStartBallAnim(self, ...)
      local runner = type(self.anim) == "table" and self.anim or nil
      if started and runner and runner.animId == nil
          and type(runner.env) == "table"
          and runner.env.animId == "ANIM_THROW_POKE_BALL" then
        runner.animId = "ANIM_THROW_POKE_BALL"
      end
      return started
    end
    GoldBattleState._vascBallRunnerIdCompat = true
  end

  -- End the VASC session in the same transaction that clears World's
  -- battleActive flag and pops BattleState. Waiting for a later compositor
  -- frame leaves one stale battle owner between the player and START.
  if type(GoldBattleState.finishBattle) == "function"
      and not GoldBattleState._vascImmediateFinishHook then
    local innerFinishBattle = GoldBattleState.finishBattle
    function GoldBattleState:finishBattle(...)
      local out = packResults(pcall(innerFinishBattle, self, ...))
      OverworldBattle.finish(self)
      if not out[1] then error(out[2], 0) end
      return unpackResults(out, 2, out.n)
    end
    GoldBattleState._vascImmediateFinishHook = true
  end

  -- Gold's native battle-animation presenter assumes an opaque white 160x144
  -- battle BG. During attacks it bakes that panel to a canvas, fills exposed
  -- scanlines white, and blits the rows back after SCX/SCY/BGP effects. Once
  -- our panel is transparent those "blank BG" rows become the black/white
  -- rectangle seen over the voxel world. For a live-world battle, keep Gold's
  -- OBJ effect sprites but do not run the old opaque-background scanline pass.
  -- BattleState calls drawObjects immediately after `present`, so calling the
  -- panel directly here preserves the attack effects without ever replacing
  -- the overworld backdrop.
  local okAnimView, GoldAnimView = pcall(require, "src.ui.gen2.BattleAnimView")
  if okAnimView and type(GoldAnimView) == "table"
     and not GoldAnimView.stadiumLiveWorldBackgroundHook then
    if type(GoldAnimView.present) == "function" then
      local innerPresent = GoldAnimView.present
      function GoldAnimView:present(runner, drawBg, ...)
        if nativeFallbackDepth == 0 and session and session.battle and session.shot
           and session.shot.canvas and session.shot.goldStaged then
          if type(drawBg) == "function" then drawBg() end
          return
        end
        return innerPresent(self, runner, drawBg, ...)
      end
    end
    if type(GoldAnimView.presentSlide) == "function" then
      local innerSlide = GoldAnimView.presentSlide
      function GoldAnimView:presentSlide(frame, drawBg, drawBack, ...)
        if nativeFallbackDepth == 0 and session and session.battle and session.shot
           and session.shot.canvas and session.shot.goldStaged then
          if type(drawBg) == "function" then drawBg() end
          -- The caller has lifted the trainer back-pic out of the BG while an
          -- intro slide is active. Put it at its final position rather than
          -- leaving it missing; the world itself intentionally does not slide.
          if type(drawBack) == "function" then drawBack(0) end
          return
        end
        return innerSlide(self, frame, drawBg, drawBack, ...)
      end
    end
    GoldAnimView.stadiumLiveWorldBackgroundHook = true
  end

  -- Record the side whose turn is currently being presented. This observes
  -- Gold's existing queue only; it does not consume, reorder, or modify events.
  -- BattleCinematic uses it to hold the camera on the acting Pokemon through
  -- the move line, damage text and HP drain that make up one resolving turn.
  if type(GoldBattleState.advanceQueue) == "function"
      and not GoldBattleState.stadiumActiveTurnCameraHook then
    local innerAdvance = GoldBattleState.advanceQueue
    function GoldBattleState:advanceQueue(...)
      local event = type(self.queue) == "table" and self.queue[1] or nil
      if type(event) == "table" then
        local side = nil
        if event.kind == "move" and (event.side == "player" or event.side == "enemy") then
          side = event.side
        elseif event.kind == "damage" and (event.side == "player" or event.side == "enemy") then
          side = event.animSide
            or (event.side == "player" and "enemy" or "player")
        elseif (event.kind == "heal" or event.kind == "send")
            and (event.side == "player" or event.side == "enemy") then
          side = event.side
        end
        if side then self._stadiumActiveSide = side end
      end
      local out = packResults(innerAdvance(self, ...))
      if self.phase == "menu" or self.phase == "moves" then
        self._stadiumActiveSide = nil
      end
      if unpackResults then
        return unpackResults(out, 1, out.n)
      end
      -- No unpack function is an extremely old/nonstandard host. Gold's
      -- current advanceQueue has no meaningful return contract, so returning
      -- nil is safer than letting an optional camera observer crash gameplay.
      return nil
    end
    GoldBattleState.stadiumActiveTurnCameraHook = true
  end

  if type(GoldBattleState.drawPanel) == "function" then
    local innerPanel = GoldBattleState.drawPanel
    function GoldBattleState:drawPanel(...)
      if not goldShotFor(self) then return innerPanel(self, ...) end
      local clear = Chrome.clear
      Chrome.clear = function()
        -- Preserve the native panel's end-state (black ink colour), but make
        -- its full 160x144 paper transparent so GoldComposeBridge can put the
        -- voxel encounter site underneath it.
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.setColor(0, 0, 0, 1)
      end
      local ok, a, b, c = pcall(innerPanel, self, ...)
      Chrome.clear = clear
      if not ok then error(a, 0) end
      return a, b, c
    end
  end

  if type(GoldBattleState.drawPic) == "function" then
    local innerPic = GoldBattleState.drawPic
    goldNativeDrawPic = innerPic
    function GoldBattleState:drawPic(mon, playerSide, ...)
      if goldShotFor(self) then
        -- The staged shot already owns this exact trainer/Pokemon through a
        -- model or an isolated native-pic capture. Keeping Gold's sceneCanvas
        -- copy would double it. drawGoldNativeFallback suspends goldShotFor,
        -- so a renderer failure still restores the complete cartridge frame.
        return
      end
      return innerPic(self, mon, playerSide, ...)
    end
  end

  if type(GoldBattleState.drawWidescreen) == "function" then
    local innerWide = GoldBattleState.drawWidescreen
    -- Gold 0.1.90 pushes its transform before drawScene and pops only after it.
    -- A renderer/HUD exception therefore leaves that push on the global LÖVE
    -- stack. Track every nested push made by the exact native implementation,
    -- drain it on failure, and protect the rest of the graphics state with one
    -- outer `all` frame. This preserves the engine renderer and its return
    -- contract instead of reimplementing the cartridge battle screen.
    goldNativeDrawWidescreen = function(screen, winW, winH, ...)
      local results = packResults(withGraphicsBoundary(
        "native Crystal widescreen", innerWide, screen, winW, winH, ...))
      if not results[1] then error(results[2], 0) end
      return unpackResults(results, 2, results.n)
    end
    function GoldBattleState:drawWidescreen(winW, winH, ...)
      if not goldShotFor(self) then
        return goldNativeDrawWidescreen(self, winW, winH, ...)
      end
      -- Gen2's native implementation starts with a window-sized white fill.
      -- Reproduce only its centred integer-scaled 160x144 UI draw; the world
      -- itself is already a window-sized canvas underneath in compose.
      local G = love.graphics
      local scale = Chrome.fitScale(winW, winH)
      local ox, oy = Chrome.fitOrigin(winW, winH, scale)
      G.setColor(1, 1, 1, 1)
      local results = packResults(withGraphicsBoundary(
        "staged Crystal widescreen", function()
        G.translate(ox, oy)
        G.scale(scale, scale)
        return self:drawScene()
      end))
      if not results[1] then error(results[2], 0) end
      return unpackResults(results, 2, results.n)
    end
  end

  -- Useful both for diagnostics and for the session matcher in older engine
  -- builds.  Current Gold does not publish an isBattle marker itself.
  GoldBattleState.stadiumInWorldBattleUiHook = true
  return true
end

function OverworldBattle.install()
  pcall(installGoldBattleState)

  -- Gold: snapshot/stage at the exact moment World has constructed the battle
  -- object but before Gen2BattleTransition is pushed. This is the last point
  -- where the live encounter map and player position are guaranteed present.
  local okGold, GoldWorld = pcall(require, "src.world.gen2.World")
  if okGold and type(GoldWorld) == "table"
     and not GoldWorld.stadiumInWorldBattleHook then
    local inner = GoldWorld.pushBattleTransition
    function GoldWorld:pushBattleTransition(battle, opts, onDone)
      -- v0.2.23: the live-world renderer is battle-object based, not wild-only.
      -- Trainer battles use the same two active battlers, HUD and Stadium actor
      -- lifecycle, and exactGoldArena already has a no-encounter-snapshot path
      -- that stages the foe in front of the player.  Keeping this gated on
      -- `battle.wild` was the reason 3D/live mode worked for encounters but
      -- silently fell back to the native flat scene for trainer fights.
      -- Tutorial/contest/safari remain native because their send-out/capture
      -- choreography is intentionally special.
      local specialBattle = opts and (opts.tutorial or opts.contest or opts.safari)
      local ordinaryBattle = battle ~= nil and not specialBattle
      local transitionOpts = opts
      if ordinaryBattle then
        local state = self
        if type(V.goldStateForWorld) == "function" then
          local okState, adapted = pcall(V.goldStateForWorld, self)
          if okState and adapted then state = adapted end
        end
        local okBegin, staged = pcall(OverworldBattle.begin, state, battle)
        if okBegin and staged == true then
          local bridge = V and V.goldBridge
          if bridge and type(bridge.transitionBackgroundProvider) == "function" then
            local okProvider, provider, receipt, providerErr = pcall(
              bridge.transitionBackgroundProvider, self)
            if okProvider and type(provider) == "function" then
              -- The engine consumes this optional field only inside the
              -- transition state. Copy the caller's options instead of
              -- mutating a battle/script table another owner may retain.
              transitionOpts = {}
              for key, value in pairs(type(opts) == "table" and opts or {}) do
                transitionOpts[key] = value
              end
              transitionOpts.backgroundProvider = provider
              transitionOpts.backgroundProviderReceipt = receipt
              if session then session.transitionBackgroundReceipt = receipt end
              diagnostic("gen2-transition-background-bound", {
                result="provider", map=receipt and receipt.mapId,
                camera=receipt and receipt.cameraMode,
                sourceFrame=receipt and receipt.sourceFrame,
              })
            else
              diagnostic("gen2-transition-background-bound", {
                result="native", reason=okProvider and providerErr or provider,
                map=self.map and self.map.id,
              })
            end
          end
        elseif not okBegin then
          diagnostic("gen2-transition-background-bound", {
            result="native", reason="battle-stage-error: " .. tostring(staged),
            map=self.map and self.map.id,
          })
        end
        -- Keep the cartridge's visible Gen2BattleTransition even though the
        -- destination presentation reuses the encounter-site voxel world.
        -- Earlier live-battle builds returned false after a successful stage,
        -- which made World:startBattle push Gen2BattleState immediately; the
        -- result was an abrupt cut with no Crystal battle-start animation.
        -- Staging still happens here, before the wipe, while the native screen
        -- owner below performs the transition and invokes onDone normally.
        -- A failed stage also remains fail-open through the same native path.
      end
      return inner(self, battle, transitionOpts, onDone)
    end
    GoldWorld.stadiumInWorldBattleHook = true
  end

  -- Legacy host retained for compatibility with the embedded renderer suite.
  local okLegacy, OverworldState = pcall(require, "src.world.OverworldController")
  if okLegacy and type(OverworldState) == "table"
     and not OverworldState.dramaticShapeBattleHook then
    local inner = OverworldState.pushBattle
    function OverworldState:pushBattle(battle)
      pcall(OverworldBattle.begin, self, battle)
      return inner(self, battle)
    end
    OverworldState.dramaticShapeBattleHook = true
  end

  -- the STADIUM rung's own four wraps, which drive the models' animations
  -- off the fight (see Stadium.install). Idempotent in the same way, and
  -- installed whichever rung the row is on: the wraps do nothing at all
  -- while no stadium session is live.
  pcall(function() V.require("Stadium").install() end)

  local BattleState = require("src.battle.BattleState")
  if BattleState.dramaticShapeBattleHook then return end

  -- Integer scales only. The camera is solved to make one overworld square
  -- exactly big enough for a pic at its own integer scale (see BattleCam), so
  -- the fit never has to come out of the pixels -- and a species override or
  -- a battle_sprite_scales entry that asks for 1.7x would undo that and
  -- resample the sprite into mush. Rounded rather than refused, so such a mod
  -- still gets the bigger or smaller mon it asked for, on the pixel grid.
  local innerScale = BattleState.resolveBattleScale
  function BattleState.resolveBattleScale(data, side, path, species)
    local base = innerScale(data, side, path, species)
    -- 1:1 into the billboard texture: the artwork's own pixels, with the
    -- quad's world size doing every bit of the scaling. Anything else would
    -- resample the sprite twice -- once into the texture and again on the way
    -- to the screen -- and a twice-resampled Gen 1 pic is mush.
    if texturing then return 1 end
    if not OverworldBattle.shot() then return base end
    return math.max(1, math.floor((tonumber(base) or 1) + 0.5))
  end

  -- Keyed-out whites inside a pic used to be filled by the white field
  -- behind it. There is a world back there now, so they are filled here
  -- instead -- see BattlePics, which puts the paper back without touching
  -- the silhouette.
  --
  -- The pinned pic is told that its feet are on the box, which is what lets
  -- the pale-bodied back sprites be filled at all: their bellies leak out
  -- through an opening too wide to read as a drain, and only the box under
  -- them settles that it is not a hole. Passed the pre-bake image, because
  -- that is the one the battle holds a reference to.
  local innerPic = BattleState.picImage
  function BattleState:picImage(img)
    local out = innerPic(self, img)
    if not OverworldBattle.shot() then return out end
    return BattlePics.filled(out, OverworldBattle.pinnedPic(self, img))
  end

  -- While a billboard texture is being rendered both pics are put in the same
  -- known place -- centred on TEX_AX with their feet on TEX_AY -- so the quad
  -- has one anchor to hang from whichever side and whichever species it is
  -- carrying. Outside that render both helpers answer exactly as they always
  -- did.
  local innerBack = BattleState.backPlacement
  function BattleState.backPlacement(w, h, pad, padL, scale)
    local x, y, s = innerBack(w, h, pad, padL, scale)
    if not texturing then return x, y, s end
    return TEX_AX - w * scale / 2, TEX_AY - (h - pad) * scale, s
  end

  local innerFront = BattleState.frontPlacement
  function BattleState.frontPlacement(ex, ey, w, h, scale)
    local x, y, s = innerFront(ex, ey, w, h, scale)
    if not texturing then return x, y, s end
    return TEX_AX - w * scale / 2, TEX_AY - h * scale, s
  end

  local innerDraw = BattleState.draw
  function BattleState:draw()
    local shot = OverworldBattle.shot()
    -- AskName blanks the field on purpose (the nickname prompt is meant to
    -- sit on nothing); leave that one alone.
    if not shot or self.blankForAskName then
      -- nil, not false: the class default is inherited again, so a battle
      -- that loses its arena mid-fight goes back to white voids
      self.letterboxWhite = nil
      self.dramaticShapeShot = nil
      return innerDraw(self)
    end
    self.dramaticShapeShot = shot
    -- The world reaches the screen through the seam a render pipeline's
    -- finished world image already uses: one window-resolution canvas,
    -- blitted a pixel to a pixel, with the 160x144 UI canvas composited over
    -- it in the classic letterbox afterwards. That is what makes the backdrop
    -- as crisp as the free-roam diorama while the pics and text stay GB art.
    local renderer = game().renderer
    if renderer and renderer.setWorldOverride then
      renderer:setWorldOverride(shot.canvas)
    end
    -- beginFrame clears the UI canvas white for an opaque state; the world is
    -- under it now, so clear it back to nothing and let it through. Safe to
    -- do here: an opaque battle is the lowest state drawn, so nothing has
    -- drawn into this canvas yet.
    love.graphics.clear(0, 0, 0, 0)
    -- the white letterbox exists so the window matches the white battle
    -- canvas; there is a world out to the window edges now
    self.letterboxWhite = false
    if not isGoldGame() then OverworldBattle.drawHudPanels(self) end
    withoutBackgroundFill(self, innerDraw)
  end

  -- The mons are geometry standing on the map now, drawn in the 3D pass
  -- before this screen is composited at all, so the flat pics layer has
  -- nothing left to do here. Skipped rather than left to draw underneath, or
  -- every Pokemon would appear twice: once on its tile and once in its slot.
  --
  -- Except under BACK SPRITES, where the player's side never became geometry and this
  -- layer is the only thing that draws it. The engine's own onlySide argument
  -- does the whole job: one call, the player's branches alone, in the slot and
  -- at the scale the GB always put them -- feet on the box, 2x, back view.
  innerPics = BattleState.drawPicsLayer
  function BattleState:drawPicsLayer(slide, sx, sy, onlySide, skipMenuClip)
    local shot = self.dramaticShapeShot
    if not shot then
      return innerPics(self, slide, sx, sy, onlySide, skipMenuClip)
    end
    if OverworldBattle.backPinned() and onlySide ~= "enemy" then
      -- under the hour's own light, like everything else in the frame -- see
      -- withTint, and the tint BattleScene hands over with the shot.
      --
      -- Except on the wavy path, where the pic is baked into the GRAYSCALE bg
      -- canvas for the zone pass to colour by region. That pass keys off the
      -- red channel, and a night tint pulls red down -- it would not darken
      -- the mon, it would remap it to the wrong shade. SE_WAVY_SCREEN lasts a
      -- second and the hour survives it fine.
      local tint = not self.grayPics and shot.tint or nil
      return withTint(tint, innerPics, self, slide, sx, sy, "player",
                      skipMenuClip)
    end
  end

  -- The battle's text box and its menus, over the frosted glass laid down for
  -- them rather than over their own white paper. The INK is Gen 1's own black
  -- and stays that way whatever is behind the glass -- the panel's tint is
  -- what earns it its contrast (see BattleHud).
  local innerText = BattleState.drawTextArea
  function BattleState:drawTextArea()
    if not self.dramaticShapeShot then return innerText(self) end
    -- Gold keeps its native battle text/menu paper. Only the full-screen white
    -- field is removed; menu readability and cartridge UI stay untouched.
    if isGoldGame() or isIOS() then return innerText(self) end
    return withoutBoxFill(self, innerText)
  end

  -- Move animations are authored against the pics' fixed slots, and a single
  -- animation reaches across both sides, so there is no per-side offset to
  -- give them. They ride the average, which is where the pair's centre went
  -- -- a few pixels at most, and it keeps a hit landing on the mon it is
  -- aimed at instead of drifting off it.
  innerAnim = BattleState.drawAnimLayer
  function BattleState:drawAnimLayer(colorized)
    local shot = self.dramaticShapeShot
    if not shot then return innerAnim(self, colorized) end
    -- Move animations are authored against the pics' old fixed slots, and one
    -- animation reaches across both sides, so there is no per-side offset to
    -- give them. They ride to where the PAIR went: the midpoint of the two
    -- mons' projected positions, less the midpoint of the slots they used to
    -- sit in. A hit still lands on the mon it is aimed at.
    --
    -- And they ride the pair's SEPARATION as well, because the mons
    -- themselves do. Both are geometry standing on the map, so the camera
    -- sizes them: zoom in and they grow, swing round to side-on and the two
    -- marks close up as the axis foreshortens. A layer that only slid would
    -- have held the authored 106-pixel spacing through all of it -- a beam
    -- fired between two mons that are no longer that far apart, ending in
    -- the air beside the one it was aimed at. Scaling about the same
    -- midpoint keeps every authored offset the same fraction of the gap it
    -- was authored as.
    local a = OverworldBattle.ANCHOR
    -- BACK SPRITES leaves the player's mon exactly where the GB put it, so that side
    -- contributes no movement at all and the pair's centre has gone half as
    -- far as the foe's mark did.
    local px, py = shot.player[1], shot.player[2]
    if OverworldBattle.backPinned() then px, py = a.player[1], a.player[2] end
    local cx, cy = (shot.enemy[1] + px) / 2, (shot.enemy[2] + py) / 2
    local ax = (a.enemy[1] + a.player[1]) / 2
    local ay = (a.enemy[2] + a.player[2]) / 2
    love.graphics.push()
    love.graphics.translate(cx - ax, cy - ay)
    -- Clamped, and skipped outright if the marks ever coincide: a
    -- degenerate projection must leave the effects the size they were
    -- rather than collapse them to nothing or blow them across the screen.
    local k = OverworldBattle.animScale(shot, px, py)
    if k ~= 1 then
      love.graphics.translate(ax, ay)
      love.graphics.scale(k, k)
      love.graphics.translate(-ax, -ay)
    end
    local ok, err = pcall(innerAnim, self, colorized)
    love.graphics.pop()
    if not ok then error(err, 0) end
  end

  -- The engine's flash has a SECOND half, and it is the one that reaches the
  -- menu. Beside the white rectangle (dropped above) the flash moves are
  -- driven by a BGP palette fade -- BGP_LIGHT and friends -- which the
  -- colorized pipeline applies in drawZonePass to the WHOLE background
  -- canvas. That canvas carries the HUD glyphs and the text box, so a fade
  -- meant for the two mons washed the menu out with them.
  --
  -- The fade is left switched on for the pics, which read it through
  -- picImage, and switched off for the zone pass alone. So the mons flash
  -- and the furniture around them does not.
  --
  -- The zone pass has a SECOND thing it paints, and this is the one that
  -- reads as the menu box flashing. A screen shake makes it fill every zone
  -- with the zone's own color 0 before it draws the offset copy -- the
  -- hardware showing empty BG in the strip the shake vacated. On a white
  -- battle field that fill is invisible; over a world it is an opaque white
  -- sheet across the whole frame, and since a shake program alternates
  -- offset and no-offset frames (SE_SHAKE_SCREEN steps dx 1, 0, 1, 0...) it
  -- switches on and off a few times a second. It is dropped: the background
  -- here is the map, so what the shake vacates should show the map.
  local innerZone = BattleState.drawZonePass
  function BattleState:drawZonePass(src, sx, sy)
    if not self.dramaticShapeShot then return innerZone(self, src, sx, sy) end
    -- shadow the method on the instance for this call only; putting the
    -- field back to whatever it was (normally nil) lets the class method be
    -- found again
    local had = rawget(self, "activeBgp")
    self.activeBgp = function() return nil end
    local g = love.graphics
    local rectangle = g.rectangle
    g.rectangle = function(mode, ...)
      -- the pass draws no other rectangle; the shake still shifts the copy
      if mode == "fill" then return end
      return rectangle(mode, ...)
    end
    local ok, err = pcall(innerZone, self, src, sx, sy)
    g.rectangle = rectangle
    self.activeBgp = had
    if not ok then error(err, 0) end
  end

  innerHUDs = BattleState.drawHUDs
  function BattleState:drawHUDs(slide)
    -- Normally the HUDs have already been drawn this frame, snapped out to the
    -- window's edges and composited into the world image (snapHUDs). Drawing
    -- them here as well would show each block twice, once in each place.
    if self.dramaticShapeShot and snapped() then return end
    return innerHUDs(self, slide)
  end

  BattleState.dramaticShapeBattleHook = true
end

-- Whether each HUD block is on screen this frame.
--
-- READ-ONLY duplicates of drawHUDs' own two guards, because there is no seam
-- that reports "the enemy HUD is up". A panel under a HUD that is not there
-- would be a frosted slab floating in the arena, so it is worth mirroring;
-- the worst a future engine change can do is show an empty one for a frame,
-- never break a battle.
function OverworldBattle.hudLive(battle, slide)
  local enemy = battle.enemy and not battle.showEnemyTrainer
                and not battle.enemySendingOut
                and not battle:growInScale(battle.enemy) and slide == 0
                and not battle.enemy.fainted
  local player = battle.player and not (battle.safari or battle.demo)
                 and not battle.showPlayerBack and slide == 0
  return enemy and true or false, player and true or false
end

-- ------- the snapped composite
--
-- The engine's own HUD layer, rendered into a texture.
--
-- One thing is falsified for the render, and it is falsified because this layer
-- never reaches the battle's zone pass -- it is composited into the world image,
-- outside the frame that pass covers. In the colorized pipeline drawHUDs leaves
-- the HP bar's fill as DMG gray for the zone pass to colour by region (#229);
-- answered false, it tints its own greens and reds instead, exactly as it does
-- on the flat path.
--
-- Shadowed on the instance for this call only, the way drawZonePass shadows
-- activeBgp: putting the field back to whatever it was (normally nil) lets the
-- class method be found again.
function OverworldBattle.hudTexture(battle, slide)
  if not (innerHUDs and battle) then return nil end
  local had = rawget(battle, "colorMode")
  battle.colorMode = function() return false end
  local ok, layer = pcall(BattleHud.layerTexture,
                          BattleScene.GB_W, BattleScene.GB_H,
                          function() innerHUDs(battle, slide) end)
  battle.colorMode = had
  return ok and layer or nil
end

-- Draw both HUD blocks into the world image at the window's edges, each on its
-- own frosted panel. Returns true when the frame's HUDs are up there and the
-- in-frame draw must be skipped; false leaves the battle screen's own HUD
-- exactly as it was before any of this existed.
--
-- Both bands are blitted whether or not that side's HUD is LIVE, because a band
-- carries more than the HUD: the pokeball rows of the intro and of an enemy
-- faint, and the safari ball count, all draw in these rows and belong at the
-- same edge as the block they share it with. The panels are the ones that
-- follow hudLive -- frosted glass under nothing is a slab floating in the arena.
function OverworldBattle.snapHUDs(battle, shot)
  if not (battle and shot and shot.canvas and (shot.scale or 0) > 0) then
    return false
  end
  -- With a headset live the HUDs stay IN the GB frame -- the classic
  -- slots, on the glass drawHudPanels lays for the unsnapped path. Both
  -- of VR's battle screens (the floating panel and the pokedex's) crop
  -- to the letterbox, and a block snapped out to the window's edge would
  -- be cropped away with the window around it.
  local okV, vr = pcall(V.require, "VR")
  if okV and vr and vr.active and vr.active() then return false end
  local slide = (battle.introSlide or 0) * 4
  local rects, bandX = OverworldBattle.snapRects(shot)
  local enemy, player = OverworldBattle.hudLive(battle, slide)
  local live = {}
  if enemy then live.enemy = rects.enemy end
  if player then live.player = rects.player end
  -- and the text box's own glass, on the same pass. It stays in the middle of
  -- the frame where the engine draws it -- only the HUDs were snapped out --
  -- so its GB rect is mapped into the letterbox rather than to an edge.
  for key, rect in pairs(OverworldBattle.textRects(battle)) do
    live[key] = toWorld(rect, shot)
  end
  local layer = OverworldBattle.hudTexture(battle, slide)
  if not layer then return false end

  local g = love.graphics
  local prevCanvas = g.getCanvas()
  local prevBlend, prevAlpha = g.getBlendMode()
  local ok, err = pcall(function()
    g.setCanvas(shot.canvas)
    g.setBlendMode("alpha")
    for _, rect in pairs(live) do BattleHud.panel(rect, shot, true) end
    g.setColor(1, 1, 1, 1)
    for side, band in pairs(OverworldBattle.HUD_BAND) do
      local quad = g.newQuad(band[1], band[2], band[3], band[4],
                             BattleScene.GB_W, BattleScene.GB_H)
      g.draw(layer, quad, bandX[side] + band[1] * shot.scale,
             shot.ly + band[2] * shot.scale, 0, shot.scale, shot.scale)
    end
  end)
  if prevCanvas then g.setCanvas(prevCanvas) else g.setCanvas() end
  g.setBlendMode(prevBlend or "alpha", prevAlpha)
  g.setColor(1, 1, 1, 1)
  if not ok then error(err, 0) end
  return true
end

-- Lay the frosted glass down under whichever HUD and box are about to draw,
-- and record which way the glyphs have to flip.
--
-- The panels are the fallback path only: normally the HUDs are snapped out to
-- the window's edges and their glass, and the box's, went into the world image
-- with them (snapHUDs). The VERDICT is needed either way -- the box's ink is
-- drawn here, in the GB frame, whichever path laid the glass under it.
function OverworldBattle.drawHudPanels(battle)
  local shot = battle.dramaticShapeShot
  if not shot then return end
  if isIOS() then
    local slide = (battle.introSlide or 0) * 4
    local enemy, player = OverworldBattle.hudLive(battle, slide)
    local rect = OverworldBattle.HUD_RECT
    love.graphics.setColor(1, 1, 1, 0.84)
    if enemy then love.graphics.rectangle("fill", rect.enemy[1], rect.enemy[2], rect.enemy[3], rect.enemy[4]) end
    if player then love.graphics.rectangle("fill", rect.player[1], rect.player[2], rect.player[3], rect.player[4]) end
    love.graphics.setColor(1, 1, 1, 1)
      return
  end
  if snapped() then
    return
  end
  local slide = (battle.introSlide or 0) * 4
  local enemy, player = OverworldBattle.hudLive(battle, slide)
  local rect = OverworldBattle.HUD_RECT
  local live = {}
  if enemy then live.enemy = rect.enemy end
  if player then live.player = rect.player end
  for key, r in pairs(OverworldBattle.textRects(battle)) do live[key] = r end
  if not next(live) then return end
  for _, r in pairs(live) do BattleHud.panel(r, shot) end
end

return OverworldBattle
