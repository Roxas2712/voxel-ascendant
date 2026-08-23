-- Voxel Ascendant: a standalone Gen1Recomp voxel-world renderer.
--
-- This fork starts at the MIT-licensed DramaticShapeVoxelMod v1.6.1 tag.
-- VR, Stadium ROM/model support and Horde mode are intentionally absent.
--
-- The engine's render_pipelines registry (src/mods/Schemas.lua) lets a mod
-- own part of the frame.  This mod registers two:
--
--   voxel      a drawWorld pipeline.  Instead of the flat tile blit, the
--              overworld's terrain is extruded into real geometry, walked
--              by a depth-buffered 3D camera, with characters as leaning
--              sprite slabs and a shadow map throwing real cast shadows
--              across whatever they land on.  Occlusion is the depth
--              buffer, not a y-sort: walk behind a building and the
--              building is simply in front.
--
--   tiltshift  a worldPresent pipeline -- the stage that post-processes
--              the finished world BEFORE the UI composites over it.  A
--              tilt-shift blur that sells the miniature-model look, on the
--              diorama only, leaving text boxes and menus crisp.
--
-- Everything a display mode needs beyond the two draw functions -- the
-- OFF/15/35/50 ladder, the options rows, the hotkeys, persistence in
-- save.options.pipelines, the free-roam gate, the mutual exclusion with
-- the engine's TILT mode -- is engine plumbing driven by the records
-- below.  This file declares; lib/ draws.
--
-- Orbit rungs remain purely presentational. 1ST and 3RD attach the camera to
-- the player and use camera-relative free movement while reusing the engine's
-- own collision, cell-arrival, encounter, warp and scripted-move paths.

local mod = ...

local unpackValues = table.unpack or unpack
local function packValues(...)
  return { n = select("#", ...), ... }
end

-- ------- the mod namespace
--
-- lib/ modules require each other through V rather than package.path: a
-- mod directory is not on it, and may live inside a mounted .love archive
-- that plain require cannot reach.  Each module is loaded once, with V
-- passed in as its vararg (`local V = ...`).

local V = { mod = mod, path = mod.path }

local function chunkFor(rel)
  local source = mod:read(rel)
  if not source then
    error(("VOXEL_ASCENDANT: %s is missing -- reinstall the mod"):format(rel), 0)
  end
  local chunk, err = load(source, "@" .. mod.path .. "/" .. rel)
  if not chunk then
    error(("VOXEL_ASCENDANT: %s did not compile: %s"):format(rel, tostring(err)), 0)
  end
  return chunk
end

local modules = {}
function V.require(name)
  local hit = modules[name]
  if hit ~= nil then return hit end
  local value = chunkFor("lib/" .. name .. ".lua")(V)
  modules[name] = value
  return value
end

local dataFiles = {}
function V.data(name)
  local hit = dataFiles[name]
  if hit ~= nil then return hit end
  local value = chunkFor("data/" .. name .. ".lua")(V)
  dataFiles[name] = value
  return value
end

-- ------- pipelines

local Voxel = V.require("VoxelState")
local Voxel3D = V.require("Voxel3D")
local VoxelScene = V.require("VoxelScene")
local TiltShift = V.require("TiltShift")
local ChunkMesher = V.require("ChunkMesher")
local WarpPrefetch = V.require("WarpPrefetch")
local VoxelGrid = V.require("VoxelGrid")
local Shadows = V.require("Shadows")
local WorldCurve = V.require("WorldCurve")
local OverworldBattle = V.require("OverworldBattle")
local BattlePartyBalls = V.require("BattlePartyBalls")
local BattleMusic = V.require("BattleMusic")
local LocalMusic = V.require("LocalMusic")
local SpritePacks = V.require("SpritePacks")
local LocalSprites = V.require("LocalSprites")
local SpriteHooks = V.require("SpriteHooks")
local BattleCam = V.require("BattleCam")
local BattleExit = V.require("BattleExit")
local DayNight = V.require("DayNight")
local DayTint = V.require("DayTint")
local Sky = V.require("Sky")
local SkyEvents = V.require("SkyEvents")
local Weather = V.require("Weather")
local Water = V.require("Water")
local AntiAlias = V.require("AntiAlias")
local DeviceProfile = V.require("DeviceProfile")
local WallDecals = V.require("WallDecals")
local PublicFacade = V.require("PublicFacade")
local KantoAscendantCompat = V.require("KantoAscendantCompat")
local VascMenu = V.require("VascMenu")
local FirstPerson = V.require("FirstPerson")
local FreeMove = V.require("FreeMove")
local CamControl = V.require("CamControl")
local VoxelShortcut = V.require("VoxelShortcut")
local HorizonWall = V.require("HorizonWall")
local PanoramaBackdrop = V.require("PanoramaBackdrop")
local TransitionReveal = V.require("TransitionReveal")

-- Forward declaration: the voxel pipeline's update hook (registered below)
-- calls this, and it is defined further down with the settings it drives.
-- Declared rather than left global -- a mod writing to _G would leak into
-- every other mod's namespace.
local applyFull

-- The last VOID FILL the terrain was meshed under; see the update hook.
-- The scene canvas's size, in FRAMEBUFFER PIXELS.
--
-- `ctx.width/height` are the window measured in LOVE UNITS
-- (love.graphics.getDimensions), but the engine composites a pipeline's
-- returned canvas with `draw(canvas, 0, 0, 0, 1/dpiX, 1/dpiY)` -- a scale
-- that only covers the window when the canvas is at PIXEL resolution.
-- Sizing it in units costs the DPI scale TWICE: the canvas is that much
-- smaller, then it is drawn that much smaller again, so the diorama lands
-- in the top-left corner at 1/dpi of the screen.  Desktop never sees it --
-- units and pixels are the same thing there -- but on Android the DPI scale
-- is the display density (2.625 on a 420dpi panel), and the world came out
-- a third of the size in each direction.
--
-- So ask for the pixel dimensions rather than trusting the ctx.  That is
-- the number a fixed engine would hand over, so this keeps working either
-- way instead of double-correcting.  It also squares the FX pass: ctx.scale
-- is ALREADY in pixels per world pixel (Zoom.scale over Renderer:fitScale,
-- which measures the drawable), so the closures ctx.drawFx runs were being
-- scaled for a canvas 2.6x bigger than the one they drew into.
local function sceneSize(ctx)
  if love.graphics and love.graphics.getPixelDimensions then
    local pw, ph = love.graphics.getPixelDimensions()
    if pw and ph and pw > 0 and ph > 0 then return pw, ph end
  end
  return ctx.width, ctx.height
end

local voidFill = { last = nil }
function voidFill.check()
  local TileRenderer = require("src.render.TileRenderer")
  local now = TileRenderer.voidFill
  if voidFill.last ~= nil and now ~= voidFill.last then
    ChunkMesher.invalidate()   -- no map id: every ring on every map is stale
    HorizonWall.invalidate()
    PanoramaBackdrop.invalidate()
  end
  voidFill.last = now
end

local voxelPipeline = {
  label = "VOXEL",
  levels = Voxel.ANGLE_LABELS,
  -- 3 is the engine's TILT key, which this mode supersedes -- see the
  -- hotkey block near the bottom of this file for how it is claimed
  hotkey = "3",
  -- above tiltshift, so the two sort together in the options list with the
  -- mode first and its post-process under it
  priority = 20,

  -- Headless runs and drivers without a depth canvas or shader support
  -- answer false here, and the engine keeps the vanilla 2D path -- which
  -- is why no caller ever has to guard for a missing 3D pass.
  available = function()
    return Voxel3D.available()
  end,

  -- the engine hands over the live level; we ease the camera toward it.
  -- pump() advances queued mesh builds inside a few-millisecond budget,
  -- so entering voxel mode (and streaming neighbours while walking)
  -- costs frames nothing visible -- the old synchronous build froze the
  -- first frame for seconds. prefetch() runs here as well as in the
  -- draw, because update ticks even while a warp's Transition covers
  -- the screen: the destination's meshes start building the moment the
  -- map swaps behind the fade, and the fade-covered frames get a wider
  -- pump slice -- so stepping out of a door lands on terrain that is
  -- already there instead of a flat flash.
  update = function(dt, level)
    -- FULL is a preset, so it is applied ON THE PRESS rather than held every
    -- frame: it SETS the other rows and then leaves them alone. Holding them
    -- would make the zoom keys and the wheel dead while the mode was on, and
    -- would fight anyone who changed one deliberately.
    applyFull(level)
    Voxel.update(dt, level)
    -- The player-attached rig must keep easing both into and out of its
    -- rungs, so it ticks even after 1ST/3RD has just been left.
    FirstPerson.update(dt)
    -- the day/night clock, on the same always-running tick: Pipelines.update
    -- runs whatever the level, so time passes with the mode off, through
    -- battles and menus, and a CYCLE evening falls mid-fight exactly as it
    -- would mid-walk
    DayNight.update(dt)
    Sky.update(dt)
    SkyEvents.update(dt)
    Weather.update(dt)
    -- The overworld battle rides this hook rather than owning a pipeline of
    -- its own, because it owns no pass of the FRAME: it draws under a battle
    -- screen the engine composites, which is not a stage the registry has.
    -- What it needs is a tick that keeps running once the overworld stops
    -- being the top state, and this is one -- Game:update calls
    -- Pipelines.update unconditionally, so it survives the transition wipe
    -- and the whole battle. Ahead of the active() gate below, because a 3D
    -- battle does not require the free-roam mode to be switched on.
    OverworldBattle.update(dt)
    -- VOID FILL picks the block the border ring is made of, and in this
    -- mode that ring is BAKED INTO THE MESH rather than drawn each frame.
    -- So the option has to reach the cache or nothing happens on screen
    -- until the meshes are dropped for some other reason -- which reads
    -- exactly like the option doing nothing at all. Polled rather than
    -- hooked because the engine changes it from three places (the options
    -- row, applyOptions on load, TileRenderer.setVoidFill) and none of
    -- them announces it. Ahead of the active() gate, so switching it
    -- while voxel mode is OFF still invalidates what is cached.
    voidFill.check()
    local Game = require("src.core.Game")
    local ow = Game and Game.overworld
    local covered = Game and Game.stack and Game.stack:top() ~= ow
    local warpWarm = WarpPrefetch.update(Game, covered)
    local warm = ChunkMesher.preloadSetting:get()
    if ow and ow.map and ow.camera and (Voxel.active() or warm) then
      pcall(VoxelScene.prefetch, ow)
    end
    if not Voxel.active() then
      if warm then
        ChunkMesher.pump(Game and Game.stack and Game.stack:top() ~= ow, true)
      end
      return
    end
    -- A fade/menu still runs the engine's own animation and input work. Keep
    -- its covered build slice to 6ms; while the complete 2D fallback is
    -- visible, the bounded 8ms loading slice likewise keeps iPhone responsive
    -- until the atomic swap.
    local loading = not Voxel.ready
    -- Once the current scene and every relevant seam are complete, two-hop
    -- survey maps receive only a 1ms trickle. They are promoted automatically
    -- when approached. This still drains the bounded cache over long walks,
    -- but removes distant speculative work from the normal 4ms visible slice.
    local priorityWork = ChunkMesher.hasPriorityWork()
    ChunkMesher.pump(covered, false, loading, warpWarm,
                     not covered and not loading and not priorityWork)
  end,

  drawWorld = function(ctx)
    -- Terrain and characters are geometry; the field FX stay ordinary 2D
    -- draws composited on top, anchored through the same camera the 3D
    -- pass used (ctx.drawFx below).  The scene renders at the window's
    -- PIXEL resolution (see sceneSize) so the 3D pass is crisp rather than
    -- a magnified low-res image, while the FX closures keep drawing in
    -- world-pixel units.
    local sw, sh = sceneSize(ctx)
    -- With AA on, the whole pass runs into a canvas BIGGER than the window
    -- and is folded back down at the end (see AntiAlias).  Nothing between
    -- these two lines knows: every pass in the frame measures itself in the
    -- canvas it was handed, so the sky's dither, the water's march and the
    -- camera itself all come out the same picture at a higher sample rate.
    local rw, rh = AntiAlias.expand(sw, sh)
    local canvas = VoxelScene.render(ctx.state, rw, rh,
                                     ctx.vw, ctx.vh, ctx.paletteFor)
    if not canvas then return nil end   -- fall back to the 2D path
    if Voxel3D.beginOverlay() then
      -- the FX closures are ordinary 2D draws sized in DISPLAY pixels, and
      -- they are drawing into the supersampled canvas alongside everything
      -- else -- so the scale goes up with it, or the "!" bubble lands the
      -- right place at half the size.  project() already answers in canvas
      -- pixels, so only the scale needs saying.
      ctx.drawFx(function(wx, wy) return Voxel3D.project(wx, 0, wy) end,
                 ctx.scale * AntiAlias.factor())
      Voxel3D.endOverlay()
    end
    -- and back to the window's own size, which is what the engine composites
    -- one canvas pixel to one display pixel.  A pass-through when AA is off.
    return AntiAlias.resolve(canvas, sw, sh, "world")
  end,

  invalidate = function()
    Voxel3D.invalidate()
    OverworldBattle.invalidate()
    AntiAlias.invalidate()
    ChunkMesher.invalidate()   -- no map id = every cached mesh
    HorizonWall.invalidate()
    PanoramaBackdrop.invalidate()
  end,
}

-- Gen1Recomp 0.1.90 does not know the optional revealReady schema field, so
-- include it only after feature-detecting the complete new engine seam.  On
-- 0.1.90 configure() installs an idempotent engine_internals compatibility
-- wrapper with the exact same predicate instead; the registered record stays
-- byte-for-byte valid against that baseline schema.
local revealReady = TransitionReveal.configure()
if revealReady then voxelPipeline.revealReady = revealReady end
mod.content.render_pipelines:register("voxel", voxelPipeline)

mod.content.render_pipelines:register("tiltshift", {
  label = "T-SHIFT",
  levels = TiltShift.LABELS,
  -- 6 is free: no engine branch claims it, so this one alone reaches the
  -- registry by the documented route
  hotkey = "6",
  priority = 10,

  update = function(dt, level)
    TiltShift.update(dt, level)
  end,

  -- worldPresent, not present: the blur belongs on the diorama, not on the
  -- dialog box in front of it.  A pass-through when the level is 0 or the
  -- shader is unavailable, so the frame is untouched in every other case.
  worldPresent = function(canvas)
    return TiltShift.apply(canvas)
  end,

  invalidate = function()
    TiltShift.invalidate()
  end,
})

-- ------- this mod's own settings
--
-- Neither of these is a pipeline: they own no pass of the frame, they
-- PARAMETERISE the voxel one, so they have nothing to put in drawWorld or
-- present and the registry would rightly reject them.  Plain mod settings
-- instead -- see ModSetting for where they persist and how the two rows
-- each ends up on stay in step.

-- ------- the FULL preset
--
-- Everything the mode wants switched to at once. Applied when the VOXEL row
-- ARRIVES at FULL and not again, so the player can still move the camera or
-- the zoom afterwards -- it is a starting point, not a lock.
--
-- Leaving FULL deliberately does NOT undo any of it. A preset that reverted
-- would throw away whatever the player had changed since, and "put it back
-- how it was" is not a thing this can know.
local fullWas = nil

applyFull = function(level)
  local isFull = Voxel.isFull(level)
  local was = fullWas
  fullWas = isFull
  if not isFull or was == true or was == nil then return end

  local Game = require("src.core.Game")
  local Pipelines = require("src.render.Pipelines")
  local Zoom = require("src.render.Zoom")
  local opts = Game.save and Game.save.options
  if not opts then return end

  -- the miniature blur at its strongest: FULL is the diorama look, and the
  -- tilt-shift is most of what makes it read as a model
  Pipelines.setLevel("tiltshift", Pipelines.maxLevel("tiltshift"))
  Pipelines.syncOptions(opts)
  -- the horizon flat. The curve bends the world away from a walking player,
  -- which fights a fixed diorama framing
  WorldCurve.setting:setIndex(1, Game)
  -- and the water reflecting everything it can: FULL is the diorama at its
  -- most photographed, and a lake with the sky and the shoreline in it is
  -- most of what makes the model read as being outdoors
  Water.setting:setIndex(1, Game)
  Sky.setting:setValue("full", Game)
  Sky.cloudSetting:setValue("on", Game)
  SkyEvents.setting:setValue("full", Game)
  HorizonWall.setting:setValue("full", Game)
  -- and the view fitted to the window
  opts.zoom = 0
  Zoom.applyOptions(opts)
  -- battles on the map too: FULL means the whole mode, and a fight is where
  -- half of it is spent. Set and then LET GO of -- unlike the rows above, both
  -- battle rows stay on the menu under FULL (see the rows hook), so this is
  -- where the preset puts them and not where they are held.
  OverworldBattle.setting:setIndex(1, Game)
  -- BTL CAM is a persisted presentation/resource choice, not part of the
  -- diorama preset. FULL enables staged battles but never overwrites an old
  -- 1X/2X choice; a save without that key starts at BattleCam's 3X default.
  -- Keep both player-side cards in the 3D scene when the FULL preset is first
  -- selected. Each remains independently changeable afterwards.
  OverworldBattle.pokemonBackSetting:setIndex(1, Game)
  OverworldBattle.trainerBackSetting:setIndex(1, Game)
  -- and the battle screen the staged fight is composed for. WIDE re-lays that
  -- screen out on a 304x144 surface, which moves every anchor the arena camera
  -- is solved against (OverworldBattle.forceOG); FULL has just switched staged
  -- fights on, so the layout follows them.
  OverworldBattle.forceOG(Game)
  -- FULL showcases the complete outdoor system, including the colour-graded
  -- day/night clock. DAYTIME remains selectable afterwards, so this is a
  -- starting value rather than a lock.
  DayNight.setting:setValue("cycle", Game)
  if Game.writeOptions then pcall(Game.writeOptions, Game) end
end

-- Whether a fight can be staged on the map, as far as the OPTIONS menu is
-- concerned: the 3D-BTL row, and nothing else.
--
-- It used to answer yes under FULL as well, on the grounds that FULL owned
-- that row and switched it on. FULL no longer owns it -- the row stays on the
-- menu under FULL and can be switched off there (see the rows hook) -- so that
-- clause would now claim staged battles for a preset the player had just
-- turned them off inside, pinning BATTLE LAYOUT to OG for a fight that is
-- never staged. The row is the only thing that decides, which is what every
-- other reader of this setting already believed: OverworldBattle.begin and
-- wantsFront both gate on enabled() alone.
--
-- Deliberately NOT gated on Voxel3D.available(): the engine offers a
-- pipeline's row whether or not the hardware can run it (Pipelines.rows), so
-- this mode's rows say ON on a machine without a depth buffer too, and a menu
-- that claims 3D battles are on must not also offer the layout they cannot be
-- drawn in.
local function stagedBattles()
  return OverworldBattle.enabled()
end

local function adjustableBattleCamera()
  return stagedBattles() and not OverworldBattle.arenaMode()
end

local function authoredBattleCamera()
  return stagedBattles() and OverworldBattle.arenaMode()
end

local SETTINGS = {
  { DeviceProfile.setting,
    "Choose a persistent hardware profile. AUTO selects PC/MAX on desktop, "
    .. "HANDHELD on iOS/Android and ECO on Web. Changing any managed row "
    .. "switches to CUSTOM and preserves those individual values.",
    row = DeviceProfile.row },
  { Sky.setting,
    "Outdoor sky over Kanto. FULL draws the time-aware banded sky with sun "
    .. "or moon, FLAT keeps only the cheaper horizon colour, and OFF leaves "
    .. "the outdoor backdrop unpainted." },
  { Sky.cloudSetting,
    "Pixel-art clouds crossing the outdoor sky. They follow the current "
    .. "day/night colour and can be disabled independently for performance." },
  { SkyEvents.setting,
    "Rare world-anchored sky events. FULL permits rainbows plus distant "
    .. "Pidgeot and Ho-Oh flights; RAINBOW or FLYERS keeps only that class, "
    .. "and OFF skips all event drawing for slower devices.",
    full = true },
  { Weather.setting,
    "Outdoor weather. CLEAR preserves the dry default, AUTO chooses stable "
    .. "map-appropriate spells; RAIN, SNOW, FOG or STORM forces that effect. "
    .. "The same weather remains visible in staged outdoor battles." },
  { HorizonWall.setting,
    "Close the streamed world edge with a map-aware near layer and original "
    .. "distant Kanto panorama outdoors, plus rock walls in caves. Water, "
    .. "coastal openings and connected maps stay real. OFF draws neither "
    .. "the scenery curtain nor the outdoor panorama." },
  { ChunkMesher.preloadSetting,
    "Build the current map and connected neighbours into a safe in-memory "
    .. "mesh cache while voxel mode is off. ON makes the first switch and "
    .. "most map changes appear immediately; OFF saves background CPU.",
    full = true },
  { VoxelGrid.setting, "One-pixel wireframe along every voxel edge." },
  -- The staged fight used to force this on even when V-GRID said OFF. It is
  -- deliberately independent: battle framing should not rewrite the look the
  -- player chose for free-roam.
  { VoxelGrid.battleSetting,
    "Draw voxel seams in 3D battles. Independent of V-GRID, which controls "
    .. "the overworld.",
    full = true },
  -- A quality/performance switch rather than a FULL-preset knob. Keep it on
  -- the menu under FULL so mobile players can disable the shadow-map pass
  -- without leaving the curated camera preset.
  { Shadows.setting,
    "Turn object-anchored world and character shadows ON or OFF in voxel "
    .. "scenes and 3D battles. Turn "
    .. "this off on mobile devices where the shadow pass is slow or renders "
    .. "poorly.",
    full = true },
  { WorldCurve.setting,
    "Bend the world down over the horizon, Animal Crossing style." },
  { Water.setting,
    "Reflections on water. FULL adds screen-space reflections of the "
    .. "shoreline, the trees and the buildings behind it; SKY is the sky, "
    .. "the sun and the moon alone, which is most of the look for a "
    .. "fraction of the cost." },
  -- `full` marks a row FULL does not take away. FULL owns the diorama's own
  -- knobs; what a battle is drawn over, and how it is framed, are not that.
  { OverworldBattle.setting,
    "Fight in three dimensions using the game's native Gen 1 pictures as "
    .. "camera-facing cards. MAP uses nearby voxel terrain; ARENA builds a "
    .. "location- and anchor-aware field; DISCS uses two neutral platforms.",
    full = true },
  { BattleCam.distanceSetting,
    "Set the saved starting distance of MAP and DISCS battles. 1X is the "
    .. "closest, tightest view; 2X is the balanced middle ground; 3X is the "
    .. "default and widest view. Q/E, wheel and pinch "
    .. "can still fine-tune it during a fight.",
    when = adjustableBattleCamera,
    full = true },
  { BattleCam.arenaCameraSetting,
    "ARENA keeps every authored Pokemon footing on its fixed 3X master "
    .. "composition. 3X holds that exact shot; STADIUM adds only the "
    .. "background-reviewed automatic action director. Manual orbit, pitch "
    .. "and zoom stay locked in both ARENA modes.",
    when = authoredBattleCamera,
    full = true },
  -- Only offered while a fight can actually be staged on the map: with 3D-BTL
  -- off the engine draws the classic screen, which is this row's ON already,
  -- and a row that no longer decides anything is worse than no row.
  { OverworldBattle.trainerBackSetting,
    "Keep the trainer's classic rear-view throw sprite in the original intro "
    .. "slot. OFF uses the trainer's standing front art in the 3D scene.",
    when = stagedBattles,
    full = true },
  { OverworldBattle.pokemonBackSetting,
    "Keep your own Pokemon on the battle menu, seen from behind in its "
    .. "original slot, instead of standing it on the map facing the foe. "
    .. "The foe is still out there on its own tile.",
    when = stagedBattles,
    full = true },
  { BattleMusic.setting,
    "Optional companion-pack music. ORIGINAL keeps the game/KASC cue; "
    .. "SHUFFLE chooses once per fight from installed packs, while GEN 2-6 "
    .. "pins one available generation. USER MUSIC below is the simpler "
    .. "choice for loose files you own. VASC includes no audio.",
    full = true },
  { DayNight.setting,
    "What time it is outdoors: pin the sky to DAY, NIGHT, DUSK or DAWN, "
    .. "or leave AUTO to run it -- long DAY and NIGHT plateaus with short "
    .. "graded dawn and dusk transitions. The "
    .. "colour-graded world, clouds, stars, windows, shadows and sky "
    .. "following the same clock.",
    full = true },
  -- Marked `full` for the opposite reason the battle rows are: this is not a
  -- knob on the look at all, it is what the look COSTS. FULL is a preset for
  -- the diorama, not a licence to spend four times the fill rate on the
  -- machine it happens to be running on, so it neither sets this nor takes
  -- the row away -- the player decides what their hardware can carry, from
  -- inside FULL like anywhere else.
  { AntiAlias.setting,
    "Smooth the stair-stepped edges of the 3D world -- roof ridges, ledge "
    .. "lips, a tree against the sky -- by rendering the diorama larger than "
    .. "the window and folding it back down. Every edge in the picture "
    .. "softens with them, the tileset's own texels included, so the diorama "
    .. "reads smoother rather than sharper. 2X costs half again as many "
    .. "pixels in each direction and 4X twice, which makes this the most "
    .. "expensive row in the mod.",
    full = true },
}

-- Profiles own only cost/automation choices, never camera composition,
-- world curve or the player's sprite/back-picture preferences.
DeviceProfile.configure({
  { setting = Sky.setting,
    max = "full", handheld = "full", eco = "flat" },
  { setting = Sky.cloudSetting,
    max = "on", handheld = "on", eco = "off" },
  { setting = SkyEvents.setting,
    max = "full", handheld = "flyers", eco = "off" },
  { setting = Weather.setting,
    max = "auto", handheld = "auto", eco = "auto" },
  { setting = HorizonWall.setting,
    max = "full", handheld = "full", eco = "full" },
  { setting = ChunkMesher.preloadSetting,
    max = true, handheld = true, eco = false },
  { setting = Shadows.setting,
    max = true, handheld = true, eco = false },
  { setting = Water.setting,
    max = "full", handheld = "sky", eco = "sky" },
  { setting = OverworldBattle.setting,
    max = true, handheld = true, eco = false },
  { setting = DayNight.setting,
    max = "cycle", handheld = "cycle", eco = "cycle" },
  { setting = AntiAlias.setting,
    max = 2, handheld = 0, eco = 0 },
})

local schema = {}
for _, entry in ipairs(SETTINGS) do
  schema[#schema + 1] = entry[1]:schema(entry[2])
end
mod.options:define(schema)

-- ------- this mod's hotkeys
--
-- 3/V  VOXEL    cycle the camera ladder      (was 6; skips FULL)
--   5  V-GRID   toggle the wireframe         (new)
--   6  T-SHIFT  cycle the blur ladder        (was 9)
--   7  V-CURVE  cycle the horizon bend       (new)
--   8  3D-BTL   cycle overworld battles      (new)
--   9  WATER    cycle the water reflections  (new; 9 was T-SHIFT's old key)
--
-- Only 6 arrives by the documented route. Game:keypressed answers the
-- engine's own display keys FIRST and returns -- 2 COLORS, 3 TILT, 4 ZOOM,
-- 5 GBC FX -- and only then offers the key to Pipelines.hotkey, expressly
-- so "a pipeline can never shadow one" (Schemas, render_pipelines.hotkey).
-- 3 and 5 are two of those, and 7 and 8 belong to plain mod settings that
-- own no pass and so have no registry to claim a key from at all.
--
-- So this wraps Game:keypressed. It is the invasive option and it is the
-- only one: polling the keyboard in update() would fire alongside the
-- engine's handler rather than instead of it, so 3 would cycle this mode
-- AND the engine's TILT on the same press.
--
-- Consequences worth being explicit about: while this mod is enabled, TILT
-- (3) and GBC FX (5) are unreachable by key -- and unreachable on the OPTIONS
-- menu too, where both rows are taken away and both values held at zero (see
-- pinEngineFx). Nothing is being hidden that still does something: TILT is the
-- flat fake of what this mode does for real, the registry already forces it
-- off whenever a world pipeline takes the pass, and GBC FX is a full-screen
-- present pass over the top of the diorama. Uninstalling puts both back.
--
-- Everything the engine does around a pipeline hotkey has to happen here
-- too, so the work is DELEGATED rather than reimplemented: Pipelines.hotkey
-- applies its own gate and ladder, and the three lines after it are the
-- engine's own (syncOptions, the tilt exclusion, writeOptions).

local HOTKEYS = {
  ["3"] = "pipeline",           -- voxel, by its declared hotkey
  ["6"] = "pipeline",           -- tiltshift, likewise
  ["5"] = VoxelGrid.setting,
  ["7"] = WorldCurve.setting,
  ["8"] = OverworldBattle.setting,
  ["9"] = Water.setting,
}

-- One step of the VOXEL angle ladder: everything a "3" press does, named
-- so the pad's SELECT button (below) can make exactly the same step. The
-- gate is the registry's own; the tilt/GBC FX clearing is the engine work
-- the key has always delegated (see the wrap below for why).
local function cycleVoxel(game)
  local Pipelines = require("src.render.Pipelines")
  local top = game.stack and game.stack:top()
  if not Pipelines.canToggle("voxel", top, game.overworld) then return false end
  Pipelines.setLevel("voxel", Voxel.nextHotkeyLevel(Pipelines.level("voxel")))
  Pipelines.syncOptions(game.save.options)
  -- 3 is the key that used to turn TILT on and sits next to the one that
  -- used to turn GBC FX on, and this mod has taken both away. A player who
  -- left either running before enabling the mod would otherwise have no
  -- way back to off, and both fight the diorama -- so the VOXEL step
  -- clears them on EVERY press, not just the press that switches on.
  game.save.options.tilt = 0
  game.save.options.gbcfx = 0
  require("src.render.GBCFX").setLevel(0)
  require("src.render.Tilt").setLevel(game.save.options.tilt or 0)
  game:writeOptions()
  return true
end

do
  local Game = require("src.core.Game")
  local Pipelines = require("src.render.Pipelines")
  local Tilt = require("src.render.Tilt")
  local GBCFX = require("src.render.GBCFX")
  local inner = Game.keypressed
  local pipelineShape = type(Pipelines.canToggle) == "function"
                        and type(Pipelines.hotkey) == "function"
                        and type(Pipelines.syncOptions) == "function"
                        and type(Pipelines.setLevel) == "function"
                        and type(Pipelines.level) == "function"
                        and type(Tilt.setLevel) == "function"
                        and type(GBCFX.setLevel) == "function"

  if pipelineShape and type(inner) == "function"
     and not Game.voxelAscendantKeyHook then
    function Game:keypressed(key, ...)
      local claim = HOTKEYS[key]
      local top = self.stack and self.stack:top()
      -- Q/E control whichever camera is currently in front: the staged
      -- battle lens, the third-person boom, or the regular survey zoom.
      if (key == "q" or key == "e")
         and not (top and top.onKeyPressed) then
        if CamControl.zoomBy(key == "q" and 1 or -1) then return end
      end
      -- A screen with its own key handler gets the key first, exactly as the
      -- engine's first branch does: typing a nickname must not toggle a
      -- render mode. Only free-roam presses are ours to take.
      if claim and not (top and top.onKeyPressed) then
        if claim == "pipeline" then
          -- 3 walks the ANGLE rungs and steps over FULL (Voxel.HOTKEY_ORDER),
          -- so the registry's plain "advance one and wrap" is not what it
          -- wants; 6 still is. The gate is the registry's own either way.
          if key == "3" then
            if cycleVoxel(self) then return end
          elseif Pipelines.hotkey(key, top, self.overworld) then
            Pipelines.syncOptions(self.save.options)
            require("src.render.Tilt").setLevel(self.save.options.tilt or 0)
            self:writeOptions()
            return
          end
        elseif Pipelines.canToggle("voxel", top, self.overworld) then
          claim:cycle(self)
          if stagedBattles() then OverworldBattle.forceOG(self) end
          return
        end
      end
      return inner(self, key, ...)
    end
    Game.voxelAscendantKeyHook = true
  end
end

-- ------- the mode's rows, kept together
--
-- The engine splices a pipeline's row in beside TILT, because a display mode
-- belongs with the other display modes; a mod's own ui.options.rows
-- additions land at the END of the list. That left this mod's four rows in
-- two places with unrelated engine rows between them, which reads as two
-- unrelated features rather than one mode with settings.
--
-- So the plain settings are inserted directly after the last of this mod's
-- PIPELINE rows instead of appended. Nothing else moves: the block lands
-- where the engine already decided display modes go.
local function insertGrouped(out, extra)
  local anchor = nil
  for i, row in ipairs(out) do
    local id = type(row) == "table" and row.id
    if id == "pipeline:voxel" or id == "pipeline:tiltshift" then anchor = i end
  end
  if not anchor then
    for _, row in ipairs(extra) do out[#out + 1] = row end
    return out
  end
  for i, row in ipairs(extra) do table.insert(out, anchor + i, row) end
  return out
end

-- FULL owns the settings that describe the LOOK, so while it is selected those
-- are taken off the menu rather than left to be changed under it -- including
-- T-SHIFT, which is a pipeline row the engine put there. A row that no longer
-- decides anything is worse than no row.
--
-- The battle rows are the exception and they stay; see the rows hook.
local function dropRow(out, id)
  for i = #out, 1, -1 do
    if type(out[i]) == "table" and out[i].id == id then table.remove(out, i) end
  end
  return out
end

-- ------- TILT and GBC FX are gone while this mod is installed
--
-- Both fight the diorama, and both were already half-taken: the mode's own key
-- (3) forces them off on every press, and the registry switches TILT off
-- whenever a world pipeline takes the pass. What was left was two rows the
-- player could set and watch get reverted -- TILT is the flat fake of what
-- this mode does for real, and GBC FX is a full-screen present pass over the
-- top of the whole thing.
--
-- So they come OFF the menu, and are HELD at zero rather than merely dropped.
-- Hiding a live setting is a trap: a save written before the mod was installed
-- can carry TILT 3, and a row that is not there is a row that cannot turn it
-- back off. Pinned wherever the value could have arrived from -- the menu
-- opening, a save being loaded or begun -- so there is no route by which one
-- of them is on and unreachable.
--
-- Everything they did is still reachable: uninstall the mod and both rows are
-- back, at whatever they were last set to.
-- BATTLE BG rides the same reasoning, and comes off for a reason of its own.
-- The row picks what fills the screen AROUND the battle's 160x144 field --
-- WHITE paper, BLACK bars, or the frozen overworld dimmed behind it -- and
-- all three were answers to the same question: what to do with the voids,
-- given the battle is a small picture in the middle of a big window.
--
-- This mod answers that question differently and permanently. A staged fight
-- fills the whole window with the map the fight is standing on, and the
-- flat battle screen it composites over it is drawn on the mode's own
-- surface; there are no voids left for the row to fill. WORLD is the worst
-- of the three under it -- it makes the battle non-opaque so the engine
-- draws the overworld underneath, which is a SECOND copy of the world drawn
-- under the one the arena pass already put there, dimmed and at a different
-- camera. BLACK bars over a diorama read as a letterboxed screenshot.
--
-- So the value is pinned at WHITE, which is the one the mode was composed
-- against, and the row comes off the menu on the same reasoning as TILT and
-- GBC FX: a row that no longer decides anything is worse than no row.
-- Uninstall the mod and it is back, at whatever it was last set to.
local function pinEngineFx(game)
  game = game or require("src.core.Game")
  local opts = game and game.save and game.save.options
  local Tilt = require("src.render.Tilt")
  local GBCFX = require("src.render.GBCFX")
  local changed = false
  if opts then
    changed = (opts.tilt or 0) ~= 0 or (opts.gbcfx or 0) ~= 0
                or (opts.battleBg or "white") ~= "white"
    opts.tilt, opts.gbcfx = 0, 0
    opts.battleBg = "white"
  end
  pcall(Tilt.setLevel, 0)
  pcall(GBCFX.setLevel, 0)
  if changed and game.writeOptions then pcall(game.writeOptions, game) end
end

-- call next() first and decorate what comes back, so every other mod's
-- rows survive this one
mod.hooks:wrap("ui.options.rows", function(next, game, rows)
  local out = next(game, rows)
  if type(out) ~= "table" then return out end
  local Pipelines = require("src.render.Pipelines")
  -- ahead of every branch below, including FULL's early return: these two are
  -- off the menu whatever else this mod is or is not doing
  pinEngineFx(game)
  dropRow(out, "tilt")
  dropRow(out, "gbcfx")
  -- and BATTLE BG with them: this mode fills the window with the map, so
  -- the row's whole question -- what to put in the voids around the battle
  -- -- no longer has voids to be about (see pinEngineFx)
  dropRow(out, "battleBg")
  -- BATTLE LAYOUT is the ENGINE's row, and this is the one place the mod takes
  -- one away. While a fight can be staged on the map, OG is the only layout it
  -- can be composed in (OverworldBattle.forceOG), so the value is pinned there
  -- and the row comes off the list on the same reasoning as the rows FULL owns:
  -- a row that no longer decides anything is worse than no row. Nothing is
  -- lost by switching 3D-BTL off -- the row is back, WIDE and all, on the same
  -- keypress.
  if stagedBattles() then
    OverworldBattle.forceOG(game)
    dropRow(out, "battleLayout")
  end
  local full = Voxel.isFull(Pipelines.level("voxel"))
  if full then
    -- FULL owns the rows that PARAMETERISE the diorama -- the wireframe, the
    -- horizon bend and blur -- so those come off the menu. DAYTIME remains
    -- available because the complete preset now includes the running clock.
    dropRow(out, "pipeline:tiltshift")
  end
  local extra = {}
  for _, entry in ipairs(SETTINGS) do
    -- Two things decide whether a row is offered.
    --
    -- FULL: a preset that owns the look, so the rows that describe the look go
    -- with it. The BATTLE rows are not that -- 3D-BTL decides what a fight is
    -- drawn over and TRAINER/PKMN BACK how it is framed; neither is a knob on
    -- the diorama FULL is a preset for. FULL still SETS them on arrival (see
    -- applyFull); it does not hold them, so leaving them on the menu is the
    -- difference between a preset and a lock.
    --
    -- And a row whose own switch is off the table this frame (the two BACK
    -- rows need a staged fight to be about) is left off with it. The mod
    -- manager's page carries every one of them either way.
    local offered = (entry.full or not full)
                    and (not entry.when or entry.when())
    if offered then
      extra[#extra + 1] = entry.row and entry.row() or entry[1]:row()
    end
  end
  -- Optional sprite packs are separate mods, never bundled artwork. The
  -- dynamic row can therefore only be built after every provider registered;
  -- it deliberately lives outside the static manager schema.
  extra[#extra + 1] = SpritePacks.row()
  extra[#extra + 1] = LocalMusic.row(mod)
  extra[#extra + 1] = LocalSprites.row(mod)
  return insertGrouped(out, extra)
end)

-- The mod manager writes and persists on its own, so the only thing left
-- to do is move our cached index and pick the new value up.
mod.events:on("mod.options_changed", function(payload)
  if not (payload and payload.mod == mod.id) then return end
  for _, entry in ipairs(SETTINGS) do
    if payload.key == entry[1].key then entry[1]:sync(payload.value) end
  end
  DeviceProfile.externalChanged(require("src.core.Game"),
                                payload.key, payload.value)
  -- 3D-BTL switched on from the manager's page pins BATTLE LAYOUT exactly as
  -- the OPTIONS row does. The manager persists its own value; this is the one
  -- that has to follow it.
  if stagedBattles() then OverworldBattle.forceOG() end
end)

-- ------- keeping the geometry in step with the world
--
-- Terrain meshes are derived from a map's block layer, so anything that
-- rewrites a block (a cut tree, a smashed rock, a script's replaceBlock)
-- has to drop that map's cached mesh or the 3D world keeps showing the
-- tree that is no longer there.  The 2D tile renderer invalidates its own
-- caches off the same edit.

-- refresh, not invalidate: the stale mesh keeps drawing while the
-- replacement builds in the background, so a one-block edit (Cut, a
-- door stamp, the tree regrowing on re-entry) repopulates in place
-- instead of blinking the whole scene down to the flat 2D path
mod.events:on("world.block_replaced", function(payload)
  local mapId = payload and (payload.mapId or (payload.map and payload.map.id))
  if mapId then
    ChunkMesher.refresh(mapId)
    local map = payload and payload.map
    if not map then
      local Game = require("src.core.Game")
      local active = Game and Game.overworld and Game.overworld.map
      if active and active.id == mapId then map = active end
    end
    if HorizonWall.blockAffectsGeometry(
         map, payload and payload.bx, payload and payload.by) then
      HorizonWall.invalidateMap(mapId)
    end
  end
end)

-- The event above is the ANNOUNCED edit -- OverworldState:replaceBlock
-- emits it, which is the path Victory Road's barriers and a script's
-- replaceBlock take. Several edits do not go through it:
--
--   Cut          swaps the tree block and rebuilds the 2D renderer
--   the regrowth restores those blocks when the map is re-entered
--   card-key doors are stamped closed on floor load
--
-- all of them writing the block layer directly. Meshes derived from that
-- layer went stale with no announcement -- the cut tree stayed standing,
-- and after a round trip through a door the stump stayed cut because this
-- map's mesh survives in the cache (that is what prevLive is for).
--
-- The engine could announce each of those, and an earlier cut of this
-- work changed it to. That is the wrong place: it edits the game for one
-- mod's benefit, and every future path that writes a block has to
-- remember to do the same. They all funnel through ONE choke point --
-- Map:setBlock -- so wrap that from here instead. Map is a plain
-- metatable shared by every map instance, so this covers all of them,
-- including paths written after this mod.
--
-- Read back rather than trust the argument: setBlock silently ignores an
-- out-of-bounds write, and a stamp that rewrites a block with the value
-- it already held (the door code guards for this, the regrowth does not)
-- is not a change and must not throw the mesh away.
do
  local Map = require("src.world.Map")
  if not Map.voxelAscendantBlockHook
     and type(Map.setBlock) == "function"
     and type(Map.blockAt) == "function" then
    local setBlock = Map.setBlock
    Map.setBlock = function(self, bx, by, block, ...)
      local before = self:blockAt(bx, by)
      local results = packValues(setBlock(self, bx, by, block, ...))
      if self.id and self:blockAt(bx, by) ~= before then
        ChunkMesher.refresh(self.id)
        if HorizonWall.blockAffectsGeometry(self, bx, by) then
          HorizonWall.invalidateMap(self.id)
        end
      end
      return unpackValues(results, 1, results.n)
    end
    Map.voxelAscendantBlockHook = true
  end
end

-- A reloaded map is rebuilt from scratch (warps that re-enter the same map,
-- hot reload), so its mesh is stale for the same reason -- with one
-- exception, and it is the common one.
--
-- A palette switch reloads the map ONLY to rebuild its atlas
-- (PaletteFX.setMode -> reloadMap(id, "colors")). The geometry that comes
-- back is identical: this mesher reads block layout and tile ids and never
-- reads colour, and the palette lives entirely in the texture TerrainAtlas
-- hands back per frame -- which is keyed BY palette, so the new colours are
-- already built by the time the next frame draws.
--
-- Dropping the mesh anyway cost a visible flash of the flat 2D world on
-- every palette toggle. Mesh builds are asynchronous, so the frames between
-- the drop and the first finished mesh have no terrain to draw, and
-- drawWorld returning nil IS the 2D fallback. Keeping the geometry lets the
-- new colours land on the diorama already on screen, in one frame, which is
-- what a palette toggle should look like from inside voxel mode.
mod.events:on("map.reloaded", function(payload)
  if payload and payload.reason == "colors" then return end
  local mapId = payload and (payload.mapId or (payload.map and payload.map.id))
  if mapId then
    ChunkMesher.invalidate(mapId)
    HorizonWall.invalidateMap(mapId)
  end
end)

-- ------- rows come and go, so the menu has to notice
--
-- OptionsMenu builds its row list ONCE, when it is opened, and then reads
-- that list every frame. So stepping the VOXEL row onto or off FULL changed
-- which rows the hook would return but not which rows were on screen -- the
-- settings FULL owns stayed visible until the menu was closed and reopened,
-- and a player who stepped off FULL could not see the rows come back.
--
-- Rebuilt in place, and only on a step that changes the LIST: crossing FULL,
-- or toggling 3D-BTL, which is the other row that owns one (BATTLE LAYOUT).
-- Every other rung returns the same list, and rebuilding on all of them would
-- rerun every mod's ui.options.rows hook once per keypress. The cursor is
-- clamped rather than reset, so it stays on the row it was just used on
-- instead of jumping to the top when the list below it shortens.
do
  local OptionsMenu = require("src.ui.OptionsMenu")
  local Pipelines = require("src.render.Pipelines")
  if not OptionsMenu.voxelAscendantFullHook
     and type(OptionsMenu.update) == "function"
     and type(OptionsMenu.new) == "function"
     and type(Pipelines.level) == "function" then
    local inner = OptionsMenu.update

    local function idAt(menu, index)
      local row = menu.rows and menu.rows[index or 1]
      return type(row) == "table" and row.id or nil
    end

    function OptionsMenu:update(dt, ...)
      local before = Pipelines.level("voxel")
      local hadBattles = OverworldBattle.enabled()
      local wasOn = idAt(self, self.index)
      local results = packValues(inner(self, dt, ...))
      local after = Pipelines.level("voxel")
      local crossedFull = after ~= before
                          and (Voxel.isFull(before) or Voxel.isFull(after))
      if crossedFull or OverworldBattle.enabled() ~= hadBattles then
        local rebuilt = OptionsMenu.new(self.game)
        self.rows = rebuilt.rows
        -- Follow the row the cursor was ON rather than the slot it was in:
        -- 3D-BTL takes BATTLE LAYOUT off the list ABOVE itself, which would
        -- otherwise slide the cursor onto the row under the one just used.
        for i = 1, #self.rows do
          if wasOn and idAt(self, i) == wasOn then self.index = i; break end
        end
        local cancel = #self.rows + 1
        if (self.index or 1) > cancel then self.index = cancel end
      end
      return unpackValues(results, 1, results.n)
    end

    OptionsMenu.voxelAscendantFullHook = true
  end
end

-- ------- battles on the map
--
-- The wraps this needs -- OverworldState:pushBattle, BattleState:draw and
-- BattleState:drawHUDs -- all live in lib/OverworldBattle.lua, which is
-- where the reasoning for each one is written down. Installed once, here,
-- so this file keeps naming every engine seam the mod touches.
OverworldBattle.install()
BattlePartyBalls.install()
BattleMusic.install(mod)
LocalMusic.install(mod)
LocalSprites.install(mod)
VascMenu.install(mod)
SpriteHooks.install(mod)

-- When Kanto Ascendant is present, contribute one descriptor through the
-- public Start-menu hook. Its higher-priority collector moves that row into
-- ASCENDANT; without KASC this bridge is a complete no-op.
KantoAscendantCompat.install(mod)

-- 1ST and 3RD share one player-attached camera and one camera-relative
-- movement path. These installers only claim input while either rung is
-- active and the overworld is actually on top of the state stack.
FirstPerson.install()
FreeMove.install()
CamControl.install()
VoxelShortcut.install(cycleVoxel)

-- SELECT remains the compatibility controller shortcut for the same VOXEL
-- camera ladder. VoxelShortcut adds the dedicated V key and mapped ZR/R2/RT
-- trigger; retaining SELECT keeps touch devices and older muscle memory
-- working without making either path behave differently.
do
  local OverworldState = require("src.world.OverworldController")
  if not OverworldState.voxelAscendantSelectHook then
    local inner = OverworldState.handleInput
    function OverworldState:handleInput(...)
      local Game = require("src.core.Game")
      if Game.input:wasPressed("select") and cycleVoxel(Game) then return end
      return inner(self, ...)
    end
    OverworldState.voxelAscendantSelectHook = true
  end
end

-- The overworld's own pushBattle is the choke point for a wild encounter or
-- a trainer, and it is wrapped. A battle that arrives some other way -- a
-- link battle, a script pushing a BattleState directly -- reaches this
-- instead, which stages the arena from wherever the player is standing.
-- Nothing visible is lost by being late: the cull only has to beat the
-- battle screen, and the wipe those battles skip is where it would have
-- shown.
mod.events:on("battle.started", function(payload)
  OverworldBattle.ensure(payload and payload.battle)
end)

-- Both mons face the camera, so the player's side wants its FRONT pic where
-- the battle screen would have used the back one. The engine's own
-- pokemon.sprite hook is the seam for exactly this: it is asked for every
-- battle pic with the side it is resolving, so swapping one side's answer
-- needs no battle code at all -- and every path that builds a battler goes
-- through it, including a Transform mid-fight.
--
-- next() first, so a sprite-replacing mod loaded before this one still gets
-- the last word on WHICH art is used; this only changes which SIDE is asked
-- for.
mod.hooks:wrap("pokemon.sprite", function(next, path, ctx)
  local out = next(path, ctx)
  if not (ctx and ctx.kind == "battle" and ctx.side == "back") then
    return out
  end
  if not OverworldBattle.wantsFront() then return out end
  local def = ctx.data and ctx.data.pokemon and ctx.data.pokemon[ctx.species]
  return (def and def.spriteFront) or out
end)

-- Trainer presentation is independent of the Pokemon card. Gen1 loads the
-- trainer through the battle-back slot until the throw completes; in a staged
-- fight TRAINER BACK = OFF replaces that slot with standing front art.
--
-- The high hook priority also lets the ON path ask character companions for
-- their actual battle-back visual. Older Kanto Ascendant builds selected a
-- voxel front solely from ctx.kind == "battle"; the compatibility kind below
-- preserves every other context field while routing that one request to the
-- companion's normal back-art branch.
mod.hooks:wrap("player.sprite", function(next, path, ctx)
  return OverworldBattle.routeTrainerSprite(
    next, path, ctx,
    OverworldBattle.wantsTrainerBack(),
    OverworldBattle.wantsTrainerFront())
end, 100)

-- Every ending path emits this, including a battle skipped before it drew,
-- so this is where the map's cast comes back.
mod.events:on("battle.ended", function()
  OverworldBattle.finish()
  BattleMusic.finish()
  LocalMusic.finish()
end)

-- ------- and the way back out
--
-- The engine wipes INTO a battle with one of the original's eight transitions
-- and cuts straight OUT of it. That cut is between two very different cameras
-- in this mode, so while voxel mode is on the battle fades out, closes behind
-- the black, and the map fades up. The two seams it needs -- BattleState:finish
-- and Renderer:endFrame -- and the reasoning for each live in lib/BattleExit.lua.
--
-- Declared as a transitions record rather than a constant in that file, so the
-- fade is retunable in data exactly like the eight wipes it answers, and a total
-- conversion can make it as long or as short as its own pacing wants.
mod.content.transitions:register(BattleExit.ID, {
  frames = BattleExit.FRAMES,
})

BattleExit.install()

-- ------- and the hour on the flat world
--
-- The clock reaches the diorama through the voxel shader's own tint uniform,
-- which the 2D tile path never runs -- so with the mode off, the same evening
-- that fell on the diorama left the flat world at permanent noon. One clock,
-- two worlds, one of them ignoring it. DayTint paints the same multiply over
-- the composited flat world, between the world blit and the UI blit; the
-- reasoning for that exact instant is in the file.
DayTint.install()

-- ------- what time it is
--
-- The cycle's clock rides the SAVE SLOT (save.modData, via mod.save): what
-- time it is in Kanto is a fact about that journey, like where the player is
-- standing. Written on the engine's save.writing event -- the moment before
-- the bytes hit disk -- and read back whenever a save is opened or begun. A
-- A save with no clock in it starts at noon on the default AUTO dial;
-- explicit DAY/NIGHT/DUSK/DAWN pins remain stored options.
mod.events:on("save.writing", function()
  DayNight.store()
  SkyEvents.store()
end)

mod.events:on("save.loaded", function()
  DayNight.restore()
  SkyEvents.restore()
  DeviceProfile.restore(require("src.core.Game"), false)
  SpritePacks.restore(require("src.core.Game"))
  LocalMusic.restore(require("src.core.Game"))
  LocalSprites.restore(require("src.core.Game"))
  -- a save written before this mod was installed can carry TILT or GBC FX
  -- switched on, and their rows are not there to switch them back off (see
  -- pinEngineFx). Answered here rather than only when the menu opens, so a
  -- player who never opens it is not left playing under one.
  pinEngineFx()
end)

mod.events:on("save.created", function()
  DayNight.restore()
  SkyEvents.restore()
  DeviceProfile.restore(require("src.core.Game"), true)
  SpritePacks.restore(require("src.core.Game"))
  LocalMusic.restore(require("src.core.Game"))
  LocalSprites.restore(require("src.core.Game"))
  pinEngineFx()
end)

-- Hot reload constructs a new mod loader around an already loaded save, so
-- no save.loaded event is guaranteed. Restore the selected pack here too;
-- providers may register before or after this without losing the stored id.
mod.events:on("game.ready", function()
  local Game = require("src.core.Game")
  WarpPrefetch.install(Game)
  SpritePacks.restore(Game)
  LocalMusic.restore(Game)
  LocalSprites.restore(Game)
  LocalSprites.writeInventory(Game.data)
end)

-- The engine's own time-of-day seam. OverworldState:timeOfDay() is an
-- eternal "DAY" until a mod answers here; answering it hands the period to
-- the map.palette hook (ctx.tod) and music.select, so a palette or music
-- pack keyed to night works with this mod's clock for free. next() first: a
-- mod loaded before this one that already moved the time keeps its answer.
mod.hooks:wrap("world.tod", function(next, tod, ctx)
  local out = next(tod, ctx)
  if out ~= tod then return out end
  return DayNight.tod()
end)

mod.exports.version = "2.0.1"
mod.exports.apiVersion = 1
mod.exports.renderer = {
  id = "VOXEL_ASCENDANT",
  version = "2.0.1",
  pipeline = "voxel",
  -- Stable staged-battle discriminator consumed by Kanto Ascendant's
  -- reviewed renderer facade. The staged battle camera is still orbit-only;
  -- overworld 1ST/3RD are advertised on their own field and capability.
  cameraProfile = "orbit-only",
  overworldCameraProfile = "orbit-first-third",
}
mod.exports.capabilities = {
  voxelWorld = true,
  -- KASC 6.7's public compatibility receipt pins the historical first two
  -- entries as MAP/DISCS. New capabilities append; the OPTIONS ladder may
  -- still present MAP/ARENA/DISCS in its more useful player-facing order.
  battleCards = { "MAP", "DISCS", "ARENA" },
  wallDecals = WallDecals.API_VERSION,
  cameraModes = { "ORBIT", "FIRST_PERSON", "THIRD_PERSON" },
  spriteOverrideHooks = {
    "vasc.sprite.pokemon", "vasc.sprite.battle", "vasc.sprite.dex",
    "vasc.sprite.overworld_pokemon", "vasc.sprite.player",
    "vasc.sprite.trainer", "vasc.sprite.icon", "vasc.sprite.overworld",
  },
  spritePacks = { apiVersion=SpritePacks.API_VERSION, bundledAssets=false,
                  liveActivation=true, licenseReceipt=true, sha256=true },
  battleMusicPacks = {
    apiVersion=BattleMusic.API_VERSION, bundledAudio=false,
    networkDownloads=false, liveActivation=true,
  },
  looseUserMusic = {
    root=LocalMusic.ROOT, categories={
      "wild", "trainer", "rival", "gym", "elite4", "champion", "field",
      "bike", "surf", "victory", "evolution", "title", "halloffame",
      "credits", "jingle", "scene",
    }, exactSongReplacement="replace/<SONG_ID>.<ext>",
       shuffle=true, bundledAudio=false, liveRescan=true,
       default="GAME/KASC", explicitOptIn=true,
  },
  looseUserSprites = {
    root=LocalSprites.ROOT, live=true, bundledAssets=false,
    default="GAME/KASC", explicitOptIn=true,
    roles={"pokemon", "player", "trainer", "dex", "icon", "overworld"},
  },
  freeMovement = true,
  backgroundMeshCache = "memory",
  skyEvents = {
    "RAINBOW", "PIDGEY", "PIDGEOTTO", "PIDGEOT",
    "SPEAROW", "FEAROW", "MURKROW",
    "ARTICUNO", "ZAPDOS", "MOLTRES", "HO_OH",
  },
  diskCache = false,
  -- Historical KASC capability: this means the old model-backed Stadium
  -- renderer, not ARENA CAM's internal presentation director.
  stadium = false,
  vr = false,
}
mod.exports.integrations = {
  kantoAscendantMenu = KantoAscendantCompat.receipt(),
}
mod.exports.Voxel3D = Voxel3D
mod.exports.WallDecals = WallDecals
mod.exports.spritePacks = SpritePacks.public()
mod.exports.battleMusic = BattleMusic.public()
mod.exports.localMusic = { root=LocalMusic.ROOT, list=LocalMusic.list,
                           enabled=LocalMusic.enabled }
mod.exports.localSprites = { root=LocalSprites.ROOT,
                             rescan=LocalSprites.rescan,
                             inventory=LocalSprites.inventory,
                             refreshInventory=LocalSprites.writeInventory,
                             enabled=LocalSprites.enabled }

-- Compatibility modules are selected eagerly into a closed table. Unknown
-- names never reach the private owner-scoped loader, and the facade exposes
-- neither the mod handle nor its path/data/module caches.
local publicModules = {
  AntiAlias = AntiAlias,
  BattleArena = V.require("BattleArena"),
  BattleCam = BattleCam,
  OverworldBattle = OverworldBattle,
  SkyEvents = SkyEvents,
  Voxel3D = Voxel3D,
  VoxelScene = VoxelScene,
  VoxelState = Voxel,
  WallDecals = WallDecals,
}
mod.exports.lib = PublicFacade.new(publicModules)
