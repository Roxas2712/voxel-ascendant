-- Voxel world mode: assemble and draw one frame of the 3D scene.
--
-- World space is world pixels and shares its origin with the 2D paths, so
-- the terrain mesh needs no transform at all and a connected map just
-- translates by the same (ox, oy) the flat renderer already offsets it by.
--
-- Order is: the sun's shadow pass, then terrain, then characters, then a 2D
-- overlay for the field FX. There is no y-sort anywhere -- the depth buffer
-- resolves occlusion, which is the whole point of the mode. Walk behind a
-- building and the building is simply in front.

-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local Mat4 = V.require("Mat4")
local Voxel3D = V.require("Voxel3D")
local ShadowMap = V.require("ShadowMap")
local Shadows = V.require("Shadows")
local ShadowPolicy = V.require("ShadowPolicy")
local ChunkMesher = V.require("ChunkMesher")
local SpriteBillboards = V.require("SpriteBillboards")
local TileShape = V.require("TileShape")
local TerrainAtlas = V.require("TerrainAtlas")
local Voxel = V.require("VoxelState")
local Sky = V.require("Sky")
local SkyEvents = V.require("SkyEvents")
local Water = V.require("Water")
local VoxelGrid = V.require("VoxelGrid")
local DayNight = V.require("DayNight")
local FirstPerson = V.require("FirstPerson")
local HorizonWall = V.require("HorizonWall")
local ArenaScenery = V.require("SceneryWeather")
local InteriorCutaway = V.require("InteriorCutaway")
local PanoramaBackdrop = V.require("PanoramaBackdrop")
local Weather = V.require("Weather")
local CanvasPresentation = V.require("CanvasPresentation")
local MobileSceneryGate = V.require("MobileSceneryGate")
local ExternalKascWalker = V.require("ExternalKascWalker")
local okWeatherTweak, WeatherTweak = pcall(V.require, "WeatherTweak")
if not okWeatherTweak or type(WeatherTweak) ~= "table"
    or type(WeatherTweak.observe) ~= "function"
    or type(WeatherTweak.groundMode) ~= "function"
    or type(WeatherTweak.groundAmount) ~= "function"
    or type(WeatherTweak.apply) ~= "function" then
  -- One hot-reload frame may still run an older module namespace. Preserve
  -- the complete canonical scene until the new shared helper is available.
  WeatherTweak = {
    observe = function() end,
    groundMode = function(_, mode, native) return native == false and "clear" or mode end,
    groundAmount = function(_, _, native) return native == false and 0 or 1 end,
    apply = function(canvas) return canvas end,
  }
end
local PaletteFX = require("src.render.PaletteFX")
local Map = require("src.world.Map")

local VoxelScene = {}

local MOBILE_RUNTIME = CanvasPresentation.OS == "iOS"
  or CanvasPresentation.OS == "Android"

local MobileDiagnostic = V and V.mod and V.mod._vascMobileDiagnostic or nil
local function mobileDiagnostic(name, ...)
  local fn = MobileDiagnostic and MobileDiagnostic[name]
  if type(fn) ~= "function" then return nil end
  local ok, a, b = pcall(fn, ...)
  if ok then return a, b end
  return nil
end

local function resolveShadowPolicy(context)
  if type(ShadowPolicy.resolve) == "function" then
    return ShadowPolicy.resolve(context)
  end
  return { enabled = true, casters = "world", cloudOpacity = 0,
           cloudProgress = 0, cloudSeed = 0,
           birdOpacity = 0, birdEnabled = false,
           birdProgress = 0, birdSeed = 0,
           key = "legacy-world" }
end

-- Fail closed if an old hot-reload namespace or a focused test fixture has
-- not populated the new helper yet: the historical closed-room rendering is
-- always the safe fallback.
local function cutawayActive(map, level)
  return type(InteriorCutaway.active) == "function"
         and InteriorCutaway.active(map, level) == true
end

local function cutawayBodyOnly(map, level)
  return type(InteriorCutaway.bodyOnly) == "function"
         and InteriorCutaway.bodyOnly(map, level) == true
end

local function cutawayRimVisible(rim, enabled)
  if type(InteriorCutaway.rimVisible) ~= "function" then return true end
  return InteriorCutaway.rimVisible(rim, enabled)
end

-- Older compatible Voxel3D facades have no directional clip plane. FULL can
-- still remove the synthetic roof there; the camera-side wall simply stays
-- closed instead of crashing the complete scene during a hot reload.
local function setCutaway(...)
  if type(Voxel3D.setCutaway) == "function" then
    return Voxel3D.setCutaway(...)
  end
end

-- The map object whose CURRENT scene most recently passed the same atomic
-- gate render() uses.  Voxel.ready alone is not enough at a warp midpoint:
-- the map can change inside FixedStep and Transition may tick again before
-- the pipeline's next update has had a chance to clear the source map's ready
-- bit.  Object identity makes that stale source answer false immediately,
-- including under fast-forward's multiple logic steps per rendered frame.
local readyMap = nil

function VoxelScene.readyForReveal(state)
  return state ~= nil and state.map ~= nil
         and Voxel.ready == true and readyMap == state.map
end

-- What the active display mode actually paints with.
--
-- paletteFor hands back a map's RAW SGB zone palette, and that is not what
-- any of the non-colour modes draw. The flat path runs it through
-- PaletteFX.effectiveColors on the way to the shade-remap shader, and that
-- call IS where GRAY, INVERTED and CLASSIC happen -- OG / OG INV replace
-- the palette with the DMG greys (inverted for the latter), CLASSIC
-- replaces it with the green DMG set, and GBC INV permutes the zone's own
-- shades. GBC and RED++ pass through untouched.
--
-- This pass has no shader to apply that in: colour is baked into the atlas
-- and into the sprite sheets ahead of the draw, so it has to run the same
-- transform itself. Without it every mode that is not already a colour mode
-- comes through wearing the SGB palette -- grey and inverted both rendering
-- as plain SGB blue.
local function modeColors(paletteFor, map)
  local c = paletteFor and paletteFor(map) or nil
  return PaletteFX.effectiveColors(c)
end

VoxelScene._modeColors = modeColors   -- named for the suite

-- ------------------------------------------------------------------ sky --
--
-- The void behind the diorama is SKY, at every rung -- so the world reads as
-- standing under something rather than floating on a black plate.
--
-- What is up there differs by rung, and the sky follows it rather than being
-- retuned for each. At 75 degrees the camera is pitched far enough over that
-- the horizon is genuinely in frame, and the bands run down to meet it. At the
-- steeper rungs the horizon is above the top edge and the void that shows is
-- where the ground runs OUT -- past the map edge, past the curve -- so the
-- bands take a fixed slice of the frame instead (lib/Sky.lua, Sky.SPAN) and the
-- haze below them fills the rest.
--
-- INDOORS THERE IS NO SKY. A house, a cave or a gym is a room with a
-- ceiling, and the void past its walls is the outside of a box, not open
-- air. Map.isOutdoor is the same test the engine uses for door SFX and the
-- town map, and the same one Structures already asks to decide whether a
-- map rings with trees.
--
-- The colour is a four-shade ramp shaped like a world palette so the
-- display mode can transform it exactly like one: GRAY gets a grey sky,
-- CLASSIC a green one, GBC INV a dark one, and the colour modes the blue.
-- A hardcoded blue would sit wrong in every non-colour mode -- the same
-- mismatch the terrain bake had.
--
-- This ramp is the FLAT sky -- what a caller clears the void to. The free-roam
-- camera's banded sky has a palette of its own (lib/Sky.lua), transformed the
-- same way by the same seam; they are separate because the flat one also has to
-- serve an indoor void and a battle's arena, which want a colour rather than a
-- sky.
local SKY_SHADES = { { 222, 242, 255 }, { 135, 196, 240 },
                     { 64, 120, 192 }, { 16, 40, 80 } }
local SKY_SHADE = 2       -- the ramp's "sky" proper; 1 is its highlight
local CANOPY_SHADE = 2    -- sheltered forest fill, light enough not to void

-- the ramp as the display mode has it, which is the only form anything here
-- should be reading it in
local function skyRamp()
  return PaletteFX.effectiveColors(SKY_SHADES) or SKY_SHADES
end

-- Full strength at every rung: the sky is painted wherever the diorama is.
--
-- The ramp that is left is for ARRIVAL alone. Switching the mode on eases the
-- camera up from flat, and the sky comes up with it over the first few degrees
-- rather than appearing whole on the keypress -- which is also what keeps a
-- top-down camera, where there is no void worth speaking of, from painting one.
local SKY_FADE_DEG = 8

local function skyStrength(angleRad)
  local deg = math.deg(angleRad or 0)
  if deg <= 0 then return 0 end
  local t = deg / SKY_FADE_DEG
  return t < 1 and t or 1
end

-- One shade off the sky ramp, transformed by the display mode, as an
-- {r, g, b, a} in 0..1. `shade` picks the rung (SKY_SHADE is the sky
-- proper; 4 is its darkest, which is what an indoor void wants).
function VoxelScene.skyShade(shade, alpha)
  local shades = skyRamp()
  local c = shades[shade] or SKY_SHADES[shade] or SKY_SHADES[SKY_SHADE]
  return { c[1] / 255, c[2] / 255, c[3] / 255, alpha or 1 }
end

-- The sky `map` stands under at strength `t`, or nil where there is no sky
-- to paint: sealed interiors, or with the horizon out of frame. A canopy map
-- gets a flat, clock-coloured forest backdrop: it closes the void without
-- pretending that open sun, moon, stars or clouds are visible through leaves.
--
-- One flat colour, which is what a caller that only needs something to clear the
-- void to wants -- the overworld battle's arena shot is one of those. The
-- gradient is added on top of this by skyFor, for the free-roam camera alone.
local function sceneSkyColor(map, t, mobileScenery)
  -- The phone bootstrap deliberately has no semantic panorama.  Besides
  -- avoiding a desktop-only map-definition walk here, returning no sky keeps
  -- the first frame to one colour/depth target and the compact scene shader.
  if MOBILE_RUNTIME and mobileScenery ~= true then return nil end
  local canopy = DayNight.isCanopy(map)
  if not canopy and not HorizonWall.hasSky(map)
      and not HorizonWall.arenaViewFor(map) then return nil end
  if not Sky.enabled() then return nil end
  if not t or t <= 0 then return nil end
  if canopy then
    local raw = DayNight.canopyPalette()
    local shades = PaletteFX.effectiveColors(raw) or raw
    local c = shades[CANOPY_SHADE] or raw[CANOPY_SHADE]
    return { c[1] / 255, c[2] / 255, c[3] / 255, t, canopy = true }
  end
  local sky = VoxelScene.skyShade(SKY_SHADE, t)
  -- outdoors the flat fill follows the CLOCK: it becomes the hour's haze --
  -- gold at dusk, navy at night -- so a battle staged on the map at
  -- midnight is under a midnight void, not a noon one. Free-roam is
  -- unchanged by this: Sky.dress overwrites the fill with the same value.
  local haze = Sky.haze()
  if haze then sky[1], sky[2], sky[3] = haze[1], haze[2], haze[3] end
  return sky
end

-- Battle/compatibility callers keep M10's mobile answer. Only skyFor below,
-- the Gen-1 overworld seam guarded by MobileSceneryGate, may opt into P1.
function VoxelScene.skyColor(map, t)
  return sceneSkyColor(map, t, false)
end

-- Authored arena paintings expose transparent sky even on the compact mobile
-- world path. Resolve that background independently of overworld scenery;
-- indoor/canopy rules and the user's SKY setting still apply.
function VoxelScene.arenaSkyColor(map, t)
  return sceneSkyColor(map, t, true)
end

-- The free-roam sky: the flat one above, dressed with the banded gradient
-- (lib/Sky.lua).
--
-- Only here, and deliberately. This is the sky the walking camera stands under,
-- where the horizon is a quarter of the way down the frame at the top rung and
-- one flat blue reads as a wall of paint. A battle is a staged shot with its own
-- placed camera whose horizon sits above the frame entirely, so it keeps the
-- flat fill it has always had -- there is no gradient to see from down there,
-- and the arena's look is not this rung's to change.
local function skyFor(map, weatherMode)
  if type(Sky.setFrameWeather) == "function" then
    Sky.setFrameWeather(weatherMode)
  end
  local mobileScenery = MOBILE_RUNTIME
    and type(MobileSceneryGate.allow) == "function"
    and MobileSceneryGate.allow(map) == true
  local sky = sceneSkyColor(
    map, skyStrength(Voxel.angle), mobileScenery)
  if not sky then return nil end
  if sky.canopy then return sky end
  return Sky.dress(sky, weatherMode)
end

VoxelScene._skyFor = skyFor           -- named for the suite
VoxelScene._skyStrength = skyStrength

-- A facing as a yaw about +Y, kept for callers that reason about which way
-- an entity points (the mod exports it). The character cards themselves
-- never yaw -- they face south and lean, like the flat game.
local YAW = {
  down = 0,
  up = math.pi,
  right = math.pi / 2,
  left = -math.pi / 2,
}

-- The ground height a cell stands at: its collision-derived terrace datum
-- plus the same bottom-left TileShape support the engine walks on. On L the
-- datum is deliberately low and the intrinsic 6px ledge shape reaches the
-- high S surface; adding both blindly on the high datum would double the lip.
local function groundAt(map, cellX, cellY)
  -- Off the map, cellTile border-extends into the map's borderBlock --
  -- which on maps ringed with trees is a RAISED tile. The only entity
  -- ever standing off-map is the player mid seam-step (placed one cell
  -- before the connection entry), and the ground actually rendered
  -- there is the departed neighbour's flat walkway: height 0. Without
  -- this, crossing into such a map hoisted the walker tree-high for
  -- exactly one step -- the "hops like a ledge" seam bug.
  if not map:inBounds(cellX, cellY) then return 0 end
  local elevation = type(ChunkMesher.elevation) == "function"
                    and ChunkMesher.elevation(map) or nil
  local base = elevation and elevation:at(cellX, cellY) or 0
  local shapes = TileShape.forMap(map)
  local s = shapes[map:cellTile(cellX, cellY)]
  if not s then return base end
  -- The FLAT renderer removes the intrinsic ledge lip as well as the derived
  -- terrace datum. Keep actors/camera on that same plane; otherwise a player
  -- standing on hedge-separator collision art would float six pixels above
  -- the watertight mesh.
  if elevation and elevation.terrainMode == "flat"
     and s.class == "ledge" then return base end
  -- a recessed class (water) still supports whatever stands on it; only
  -- raised ground lifts the model.  Stairs never do: the class height is
  -- the flight's TALL end, but the player enters at floor level and the
  -- warp fires as they step in -- lifting them onto the geometry read as
  -- climbing an invisible block
  if s.art == "stair" then return base end
  return base + (s.h > 0 and s.h or 0)
end

VoxelScene.YAW = YAW
-- shared with the overworld battle, which stands its mons on map cells and
-- needs the same answer about what height "the floor" is there
VoxelScene.groundAt = groundAt

-- cellX/cellY remain the origin until an engine step completes. On a WORLD
-- boundary that means a wandering NPC moving uphill would otherwise keep the
-- lower support for all sixteen travel pixels, appear inside the terrace, and
-- pop upward only after arrival. Follow the actual rendered pose between the
-- two proven surfaces. Ledge hops keep their authored arc and origin support;
-- their two-cell discontinuity is intentionally not an ordinary slope.
local function groundForEntity(map, entity, hopping)
  local base = groundAt(map, entity.cellX, entity.cellY)
  if hopping or not entity.moving
      or type(entity.targetX) ~= "number"
      or type(entity.targetY) ~= "number" then
    return base
  end
  local dx = entity.targetX - entity.cellX
  local dy = entity.targetY - entity.cellY
  local span = math.max(math.abs(dx), math.abs(dy)) * 16
  if span <= 0 then return base end
  local px = tonumber(entity.px) or entity.cellX * 16
  local py = tonumber(entity.py) or entity.cellY * 16
  local travelled = math.max(math.abs(px - entity.cellX * 16),
                             math.abs(py - entity.cellY * 16))
  local t = math.max(0, math.min(1, travelled / span))
  local target = groundAt(map, entity.targetX, entity.targetY)
  return base + (target - base) * t
end

VoxelScene.groundForEntity = groundForEntity

-- Camera-ward pull distance for billboards (and the grass rows, which
-- must keep their relative depth to feet): just enough that a leaned-back
-- slab clears the wall it leans over. The lean flattens toward top-down,
-- so the needed pull grows exactly as real occlusion stops mattering.
function VoxelScene.pull(a)
  return 6 + math.max(0, 16 * math.cos(a) - 8) / math.max(math.sin(a), 0.2)
end

-- The sheet frame and mirror flag the 2D path would draw for this pose
-- (same tables as SpriteRenderer). Shared by the billboard pass and the
-- shadow pass so a walking character's shadow swings its legs too.
local function frameFor(def, facing, phase, flip)
  local SR = require("src.render.SpriteRenderer")
  local frame, mirror = 0, false
  if (def.frames or 1) > 1 then
    frame = (def.walker and phase == 1) and SR.WALK[facing]
            or SR.STAND[facing]
    mirror = facing == "right"
      or ((facing == "down" or facing == "up") and phase == 1 and flip)
  end
  return frame, mirror
end

-- The facing a pose SHOWS this camera. The flat frames are "how this pose
-- looks from the south", which is where the orbit always stands; a
-- first-person eye stands anywhere, so deep enough into the blend the
-- facing is remapped to how the pose looks from THERE -- walk behind an
-- NPC and their card wears the back sprite. Used by the camera draw and
-- the sun pass BOTH: the card the sun stored and the transform a lit card
-- reads its own shadowing with must describe the same frame, or the
-- mirror-flip half of the pair asks the map about texels the sun filed
-- under the other cheek.
-- The player's own card asks a different function for the same answer:
-- their body's bearing is what the camera is derived FROM, so it is known
-- continuously rather than as one of four directions, and measuring
-- against the compass point instead flicks the card to a profile for a
-- frame or two when the camera is spun fast (see playerFacing).
local function viewFacing(p)
  if FirstPerson.cardBlend() > 0.5 then
    if p.isPlayer then
      return FirstPerson.playerFacing(p.facing, p.px + 8, p.py + 8)
    end
    return FirstPerson.apparentFacing(p.facing, p.px + 8, p.py + 8)
  end
  return p.facing
end

-- FALLBACK ONLY (see castShadows below). Draw one entity's drop shadow as
-- a decal: its current sprite frame as a single quad, flattened onto the
-- ground along the sun line (Voxel3D.shadowMatrix). Runs inside
-- beginShadows, which supplies the translucent black; the texture is only
-- consulted for its alpha, so no palette work is needed.
local function drawShadow(sprite, px, py, facing, phase, flip, gh, lift)
  local def = sprite.def
  local frame, mirror = frameFor(def, facing, phase, flip)
  local mesh = SpriteBillboards.shadowQuad(def, frame)
  if not mesh then return end
  Voxel3D.draw(mesh, sprite:resolveImage(),
               Voxel3D.shadowMatrix(px, py, gh, lift, mirror))
end

-- Where a billboard character's card stands: on the middle of its cell at
-- height `y`, pivoted at the feet and tipped back by exactly the camera's
-- pitch. The slab is built centred on its sprite plane (z = 0), so only the
-- x anchor shifts; the relief bulges symmetrically front and back of it.
--
-- Shared by the solid draw and the silhouette below, so the two can never
-- drift apart -- a silhouette standing anywhere but exactly behind the
-- figure would read as a second character.
--
-- IN FIRST PERSON the card stops leaning and starts TURNING: upright, yawed
-- about its feet to face the eye (cylindrical billboarding). A south-facing
-- card is invisible edge-on to an eye standing east of it, which no orbit
-- camera could ever do and a first-person one does constantly. The blend
-- carries one pose into the other -- the lean eases out as the yaw eases in
-- -- and cardBlend is zero for every camera that is not the first-person
-- rig, the battle's placed shot included, so nothing else moves.
-- The pitch the sprite cards lean back by -- normally the rung's own
-- camera angle, overridable in radians. VR sets the override to the top
-- rung's 75 degrees for every diorama and battle frame: a table watched
-- from a freely moving head has no one camera pitch for the cards to
-- match, and the near-upright top-rung lean is the pose that reads as
-- "standing" from anywhere around it. nil (the default, and the flat
-- screen always) leans with the rung as ever.
VoxelScene.spriteLean = nil

local function leanAngle()
  return VoxelScene.spriteLean or V.require("VoxelState").angle
end

local function billboardMatrix(px, py, y, mirror)
  local b = FirstPerson.cardBlend()
  local m = Mat4.translate(px + 8, y, py + 8)
  if b > 0 then
    m = Mat4.mul(m, Mat4.rotateY(FirstPerson.cardYaw(px + 8, py + 8) * b))
  end
  m = Mat4.mul(m, Mat4.rotateX((leanAngle() - math.pi / 2) * (1 - b)))
  if mirror then m = Mat4.mul(m, Mat4.scale(-1, 1, 1)) end
  return Mat4.mul(m, Mat4.translate(-8, 0, 0))
end

local function billboardPull()
  return VoxelScene.pull(math.max(leanAngle(), 0.05))
end

-- An authored FIGURE's card -- a person the tileset draws INTO a piece of
-- furniture, cut out by the profile's mask (Structures.buildFigures). It is
-- a sprite, so it gets the sprite treatment: the mesh arrives in its own
-- local space with its feet on y = 0, and this stands it at its drawn
-- position and tips it back by exactly the camera's pitch -- the same
-- pivot-at-the-feet lean billboardMatrix gives a character, so the man on
-- the Pokemon Center couch reads face-on at every tilt like the NPCs
-- around him. No cell centring: unlike a character he is not standing on a
-- cell, he is standing where he was drawn, which may straddle two.
--
-- First person turns him at the eye like the walkers (see billboardMatrix)
-- -- about his own middle, because unlike a character card his local space
-- starts at x = 0 rather than being anchored by a -8 shift, and a yaw about
-- his edge would swing him off his seat. The width rode in on the record
-- for exactly this (ChunkMesher.buildFigureMeshes).
local function figureMatrix(f, offX, offZ)
  local b = FirstPerson.cardBlend()
  local wx, wz = f.wx + (offX or 0), f.wz + (offZ or 0)
  local m = Mat4.translate(wx, f.y, wz)
  if b > 0 and f.w and f.w > 0 then
    local half = f.w / 2
    m = Mat4.mul(m, Mat4.translate(half, 0, 0))
    m = Mat4.mul(m, Mat4.rotateY(FirstPerson.cardYaw(wx + half, wz) * b))
    m = Mat4.mul(m, Mat4.translate(-half, 0, 0))
  end
  return Mat4.mul(m,
                  Mat4.rotateX((leanAngle() - math.pi / 2) * (1 - b)))
end

-- What the sun sees: the same card UNLEANED and flattened, exactly as
-- Voxel3D.casterMatrix does it for a character.
local function figureCaster(f, offX, offZ)
  return Mat4.mul(
    Mat4.translate(f.wx + (offX or 0), f.y, f.wz + (offZ or 0)),
    Mat4.scale(1, 1, 0))
end

-- Every figure on `map`, drawn with `draw(mesh, model, caster)`.
local function eachFigure(map, offX, offZ, draw)
  for _, f in ipairs(ChunkMesher.figures(map) or {}) do
    draw(f.mesh, figureMatrix(f, offX, offZ), figureCaster(f, offX, offZ))
  end
end

-- Draw one posed entity. Returns true if 3D geometry carried it, false
-- when nothing could be built and the caller should fall back.
-- `colors` is the 4-color world palette the entity stands under in the SGB
-- modes (nil under RED++/trueColor): the 2D path colorizes sprites with a
-- screen-space shader the voxel canvas never runs through, so the model's
-- texture gets the palette baked in instead (TerrainAtlas.forSprite).
-- `lift` raises the figure off the ground plane (ledge hops arc UP in 3D,
-- where the 2D path could only slide the sprite north).
local function drawEntity(sprite, px, py, facing, phase, flip, gh, colors,
                          lift)
  local def = sprite.def
  local tex = sprite:resolveImage()
  if colors and not def.trueColor then
    tex = TerrainAtlas.forSprite(def.image, colors) or tex
  end
  local y = gh + (lift or 0)

  -- pick the very frame the 2D path would draw (same tables). The card
  -- always faces SOUTH -- the direction the 2D game implies -- and only
  -- LEANS BACK, pivoting at its feet, by exactly the camera's pitch, so
  -- at every tilt level the sprite reads face-on like the flat game.
  -- No camera-tracking yaw: every sprite leans in parallel.
  local frame, mirror = frameFor(def, facing, phase, flip)
  local mesh = SpriteBillboards.mesh(def, frame)
  if not mesh then return false end
  -- Camera-ward pull (applied per vertex in the shader, along each
  -- vertex's own eye ray, so it is a PURE depth bias with zero screen
  -- drift): lets the leaned-back head win against the wall it leans
  -- OVER while a character genuinely BEHIND a building is dozens of
  -- pixels deeper and still loses, so real occlusion works.
  -- the same card UNLEANED -- and SNUGGED, exactly as the sun stored it
  -- (castShadows draws this mesh through ShadowMap.snug) -- is where each
  -- vertex asks whether the light reached it; see ShadowMap.snug for why
  -- the lookup must match the stored transform to the letter
  Voxel3D.draw(mesh, tex, billboardMatrix(px, py, y, mirror),
               billboardPull(),
               ShadowMap.snug(Voxel3D.casterMatrix(px, py, y, mirror)))
  return true
end

VoxelScene.drawEntity = drawEntity

-- The player's silhouette, for wherever the scenery is standing in front of
-- them (Voxel3D.beginGhost inverts the depth test around this call).
--
-- The same flat card the solid pass and the sun pass draw. That it has no
-- self-overlap is what makes it safe here: with the depth test inverted, a
-- mesh carrying both front and back faces would read its own back faces as
-- "behind something" and repaint the figure on open ground, occluded or
-- not. One quad cannot do that, and cannot double-blend into a mottled
-- patch either. A silhouette is an outline, so an outline is the right
-- mesh for it.
local function drawGhost(p)
  local def = p.sprite.def
  local frame, mirror = frameFor(def, viewFacing(p), p.phase, p.flip)
  local mesh = SpriteBillboards.shadowQuad(def, frame)
  if not mesh then return end
  local tex = p.sprite:resolveImage()
  if p.colors and not def.trueColor then
    tex = TerrainAtlas.forSprite(def.image, p.colors) or tex
  end
  local y = p.gh + (p.lift or 0)
  Voxel3D.draw(mesh, tex, billboardMatrix(p.px, p.py, y, mirror),
               billboardPull())
end

-- Render the world. `state` is the OverworldState; `vw`/`vh` the world view
-- size in world pixels; `w`/`h` the pixel size of the canvas to render
-- into; `paletteFor(map)` yields a map's 4-color world palette (nil in the
-- color modes whose atlas is already true color). Returns the finished
-- canvas, or nil if the 3D pass could not run (headless, no depth support)
-- so the caller can fall back to 2D.
-- The last live-set key, so eviction only runs when the neighbourhood
-- actually changes (a map crossing), not every frame.
local lastLiveKey = nil

local function atlasPrepared(map)
  return not TerrainAtlas.prepared or TerrainAtlas.prepared(map)
end

local CONNECTION_DIRECTIONS = {
  { edge = "north", facing = "up" },
  { edge = "south", facing = "down" },
  { edge = "west", facing = "left" },
  { edge = "east", facing = "right" },
}

local function neighborIndex(state, mapId)
  for i, nb in ipairs(state.neighbors or {}) do
    if nb.map and nb.map.id == mapId then return i, nb end
  end
end

-- The direct connection the player can ACTUALLY reach by continuing in their
-- current movement/facing direction. Route 4's south connection, for example,
-- only overlaps cells 0..19; standing at x70 must not make Route 3 steal build
-- time. Conversely a player at Route 8's east end who is already walking west
-- should warm Saffron for the whole corridor, not spend the first twelve cells
-- boosting Lavender behind them. Priority changes only queue order: no extra
-- work, collision/input rule or frame slice is introduced.
local function seamCandidate(state)
  local player, def = state and state.player, state and state.map
                      and state.map.def
  if not (player and def and def.connections) then return nil end
  local bestIndex, bestDirection, bestScore
  for _, spec in ipairs(CONNECTION_DIRECTIONS) do
    local connection = def.connections[spec.edge]
    local i, nb
    if connection then i, nb = neighborIndex(state, connection.map) end
    if i and nb and nb.map and nb.map.def then
      local distance, along, destinationSpan
      if spec.edge == "north" then
        distance, along = player.cellY, player.cellX
        destinationSpan = nb.map.def.width * 2
      elseif spec.edge == "south" then
        distance = def.height * 2 - 1 - player.cellY
        along, destinationSpan = player.cellX, nb.map.def.width * 2
      elseif spec.edge == "west" then
        distance, along = player.cellX, player.cellY
        destinationSpan = nb.map.def.height * 2
      else
        distance = def.width * 2 - 1 - player.cellX
        along, destinationSpan = player.cellY, nb.map.def.height * 2
      end
      local landing = along - (connection.offset or 0) * 2
      if player.facing == spec.facing and distance >= -1
         and landing >= 0 and landing < destinationSpan then
        local score = distance
        if not bestScore or score < bestScore then
          bestIndex, bestDirection, bestScore = i, spec.edge, score
        end
      end
    end
  end
  return bestIndex, bestDirection
end

VoxelScene._seamCandidate = seamCandidate

local function visuallyReady(nb, index, nbMesh)
  return nbMesh[index] and ChunkMesher.auxReady(nb.map)
         and atlasPrepared(nb.map)
end

local function copySet(source)
  local out = {}
  for id, value in pairs(source or {}) do if value then out[id] = true end end
  return out
end

local function stateForIds(state, ids)
  if not (ids and ids[state.map.id]) then return nil end
  local neighbors, seen = {}, { [state.map.id] = true }
  for _, nb in ipairs(state.neighbors or {}) do
    if ids[nb.map.id] then
      neighbors[#neighbors + 1] = nb
      seen[nb.map.id] = true
    end
  end
  for id in pairs(ids) do if not seen[id] then return nil end end
  return { map = state.map, neighbors = neighbors,
           worldMaps = state.worldMaps }
end

local function planForIds(state, nbMesh, nbWater, ids)
  local planState = stateForIds(state, ids)
  if not planState then return nil end
  local meshes, waters, maps = {}, {}, { [state.map.id] = true }
  for i, nb in ipairs(state.neighbors or {}) do
    if ids[nb.map.id] then
      if not visuallyReady(nb, i, nbMesh) then return nil end
      meshes[#meshes + 1] = nbMesh[i]
      waters[#meshes] = nbWater[i]
      maps[nb.map.id] = true
    end
  end
  return { state = planState, meshes = meshes, waters = waters, maps = maps }
end

local function directIds(state)
  local ids, ordered = { [state.map.id] = true }, {}
  local connections = state.map.def and state.map.def.connections or {}
  for _, spec in ipairs(CONNECTION_DIRECTIONS) do
    local connection = connections[spec.edge]
    local i, nb
    if connection then i, nb = neighborIndex(state, connection.map) end
    if i and nb and not ids[nb.map.id] then
      ids[nb.map.id] = true
      ordered[#ordered + 1] = i
    end
  end
  return ids, ordered
end

-- The visible union can grow to the complete survey neighbourhood, but a
-- re-root must not depend on that arbitrary two-hop set remaining identical.
-- `handoffUnion` retains current + every direct connection (a guaranteed
-- subset after a direct crossing); `activeUnion` is the richer visible set.
local activeUnion, handoffUnion

local function setActive(state, ids)
  activeUnion = { rootId = state.map.id, ids = copySet(ids) }
end

local function unionStatus(union)
  local ids = {}
  for id in pairs(union and union.ids or {}) do ids[#ids + 1] = id end
  table.sort(ids, function(a, b) return tostring(a) < tostring(b) end)
  return { rootId = union and union.rootId or nil, ids = ids }
end

-- Passive QA visibility into the two semantic sets that decide whether a
-- seamless re-root can reuse a complete 3D scene.  This does not request a
-- mesh, advance a HorizonWall coroutine or expose the mutable set tables.
-- A native timeout can therefore distinguish "the target body vanished"
-- from "the ready body was no longer part of the retained union" without
-- perturbing the condition it is trying to measure.
function VoxelScene.planStatus()
  return {
    active = unionStatus(activeUnion),
    handoff = unionStatus(handoffUnion),
    liveKey = lastLiveKey,
  }
end

-- A draw plan is the compact, hole-free subset of connected maps that may be
-- painted THIS frame. The public prefetch tuple stays indexed like
-- state.neighbors for BattleScene and other existing callers; the overworld
-- uses this private fifth result instead, so a missing first neighbour cannot
-- make Lua's sparse-array length hide a ready second one (and, more
-- importantly, cannot make atlas/figure/grass work run for a body that is not
-- there yet).
local function drawPlan(state, nbMesh, nbWater)
  local neighbors, meshes, waters = {}, {}, {}
  local maps = { [state.map.id] = true }
  for i, nb in ipairs(state.neighbors or {}) do
    -- ChunkMesher deliberately lands a neighbour's terrain before its
    -- finishing overlays so several connected bodies can share the small
    -- background budget fairly.  That cached body is not yet a complete
    -- visual answer, though: exposing it here makes grass, flowers and
    -- authored figures appear a few frames later.  Keep the semantic horizon
    -- closed over the connection until the aux bundle has landed atomically.
    -- The current map remains independently progressive/urgent below, so a
    -- cold neighbour never delays the destination's first complete frame.
    if nbMesh[i] and ChunkMesher.auxReady(nb.map)
       and atlasPrepared(nb.map) then
      neighbors[#neighbors + 1] = nb
      meshes[#meshes + 1] = nbMesh[i]
      waters[#neighbors] = nbWater[i]
      maps[nb.map.id] = true
    end
  end
  return {
    -- HorizonWall additionally reads the immutable map-definition registry to
    -- verify optional future-map scenery contracts. It never mutates it.
    state = { map = state.map, neighbors = neighbors,
              worldMaps = state.worldMaps },
    meshes = meshes,
    waters = waters,
    maps = maps,
  }
end

local function currentOnlyPlan(state)
  return {
    state = { map = state.map, neighbors = {}, worldMaps = state.worldMaps },
    meshes = {}, waters = {}, maps = { [state.map.id] = true },
  }
end

-- Mobile first-frame policy -------------------------------------------------
--
-- DramaticShape's proven phone path becomes drawable as soon as the current
-- map's compact BODY exists. VASC's desktop scenery planner instead waits for
-- glass, an authored horizon, atlases and an atomic connected-map union. That
-- richer gate is valuable on desktop but makes one optional resource capable
-- of holding Gen1Recomp's opaque transition forever on a phone.
--
-- Keep the mobile bootstrap deliberately small: current map only, BODY first
-- and atlas CPU preparation. Once that exact scene has produced a real canvas,
-- its current-only Horizon/Panorama is staged and promoted. Direct connections
-- then enter a depth-1 ring one at a time; each BODY becomes visible only with
-- its own aux/atlas and future semantic horizon. No semantic phone map builds
-- current FULL, and no ring work can delay the first scene or a battle. A
-- two-hop survey never enters this path. Desktop continues through
-- semanticPlan unchanged below.
local mobileCoreTrace = {
  map = nil, mapObject = nil, phases = {}, presented = false,
}

-- The exact visible semantic state against which phone scenery is prepared.
-- It is retained by object identity only; a warp (including same-id map
-- replacement) drops it before any new semantic resource can be admitted.
local mobileSceneryPlanMap, mobileSceneryPlan = nil, nil
local mobileSceneryHorizonMap, mobileSceneryHorizon = nil, nil
local mobileSkyWarmMap, mobileSkyWarmPhase = nil, "clouds"
local mobileSceneryCanvasMap, mobileSceneryNextSlot = nil, "mobile-scenery"
local mobileSceneryLifecycleArmed = false

-- Gen2's useful phone invariant is an admitted depth-1 ring, not an atomic
-- FULL + every-neighbour transaction.  `admitted` is deliberately separate
-- from the visible plan: one direct map may enter the BODY/atlas work queue
-- per pipeline update, while a completed current-only canvas remains on
-- screen.  A neighbour becomes visible only after its own BODY, aux bundle,
-- atlas and the future semantic horizon all agree in one plan.
local mobileRingPlanMap, mobileRing = nil, nil
local mobileGateStatus

local function traceMobileCore(map, phase, fields)
  local id = map and map.id or "unknown"
  if mobileCoreTrace.map ~= id or mobileCoreTrace.mapObject ~= map then
    mobileCoreTrace.map, mobileCoreTrace.mapObject = id, map
    mobileCoreTrace.phases, mobileCoreTrace.presented = {}, false
  end
  if mobileCoreTrace.phases[phase] then return end
  mobileCoreTrace.phases[phase] = true
  fields = type(fields) == "table" and fields or {}
  fields.caller = fields.caller or "VoxelScene.prefetch"
  fields.context = fields.context or "world"
  fields.map = id
  mobileDiagnostic("checkpoint", "mobile-core-" .. phase, fields)
end

local function resetMobileRing(map)
  mobileRingPlanMap = map
  mobileRing = {
    map = map,
    admitted = {},
    failed = {},
    pending = nil,
    promoting = nil,
    semantic = nil,
  }
  return mobileRing
end

local function ringFor(map)
  if mobileRingPlanMap ~= map or not mobileRing then
    return resetMobileRing(map)
  end
  return mobileRing
end

local function semanticMobileRing(map)
  if type(HorizonWall.preferBody) ~= "function" then return false end
  local ok, answer = pcall(HorizonWall.preferBody, map)
  return ok and answer == true
end

-- Keep only current + already admitted direct maps resident.  ChunkMesher
-- itself retains one previous live set for a quick door/warp round-trip, so
-- this bounds the active phone ring without weakening that existing cache.
local function setMobileRingLive(state, ring)
  local live = { [state.map.id] = true }
  local key = "mobile-ring|" .. tostring(state.map.id)
  local _, directOrder = directIds(state)
  for _, i in ipairs(directOrder) do
    local nb = state.neighbors[i]
    local id = nb and nb.map and nb.map.id
    if id and ring.admitted[id] then
      live[id] = true
      key = key .. "|" .. tostring(id)
    end
  end
  if key ~= lastLiveKey then
    lastLiveKey = key
    ChunkMesher.setLive(live)
    TerrainAtlas.setLive(live)
  end
  return live
end

local function mobileCorePrefetch(state)
  local VoxelState = V.require("VoxelState")
  local map = state and state.map
  if not map then
    VoxelState.ready = false
    readyMap = nil
    return nil, {}, nil, {}, currentOnlyPlan(state or {
      map = { id = "missing" }, worldMaps = nil,
    })
  end

  -- Once the real phone path has run, a following map object owns a complete
  -- core->direct->scenery transaction even if the engine briefly lowers the
  -- general VOXEL-active gate during its transition.  OFF at cold startup
  -- never reaches this point and therefore cannot arm background work.
  mobileSceneryLifecycleArmed = true

  if mobileSceneryPlanMap ~= map then
    mobileSceneryPlanMap, mobileSceneryPlan = map, nil
    mobileSceneryHorizonMap, mobileSceneryHorizon = map, nil
    mobileSkyWarmMap, mobileSkyWarmPhase = map, "clouds"
    mobileSceneryCanvasMap, mobileSceneryNextSlot = map, "mobile-scenery"
    resetMobileRing(map)
  end
  local ring = ringFor(map)
  ring.semantic = semanticMobileRing(map)
  if type(MobileSceneryGate.enterMap) == "function" then
    MobileSceneryGate.enterMap(map)
  end

  traceMobileCore(map, "prefetch-start", {
    reason="phone-current-map-first",
  })

  -- TerrainAtlas's mobile implementation is CPU-first and never performs
  -- a GPU readback. Complete it before advertising the body; unlike glass or
  -- scenery this texture is required to draw the source map at all.
  if TerrainAtlas.prepared and TerrainAtlas.prepare
      and not TerrainAtlas.prepared(map) then
    traceMobileCore(map, "atlas-prepare-start")
    TerrainAtlas.prepare(map)
    if TerrainAtlas.prepared(map) then
      traceMobileCore(map, "atlas-ready")
    end
  end

  -- Priority 2 keeps the current BODY ahead of background work without the
  -- desktop `urgent` contract that withholds terrain until grass, flowers and
  -- figures are all built.  Those finishing overlays may land later on a
  -- phone; the first dependable terrain canvas must not wait for them.
  traceMobileCore(map, "body-requested", {
    urgent=false, priority=2, terrainFirst=true,
  })
  ChunkMesher.request(map, true, nil, false, 2)
  local body, bodyWater = ChunkMesher.pair(map, true)

  local baseReady = body ~= nil and atlasPrepared(map)
  if body then
    traceMobileCore(map, "body-ready", {
      auxReady=ChunkMesher.auxReady(map), atlasReady=atlasPrepared(map),
    })
  end

  -- Before a real canvas has been returned, current-map work is the entire
  -- live set.  This prevents render()'s second prefetch in the publication
  -- frame from doing a synchronous neighbour-atlas prepare before that first
  -- canvas has actually reached the caller.
  local _, directOrder = directIds(state)
  local live = setMobileRingLive(state, ring)
  traceMobileCore(map, "live-set", {
    maps=(function()
      local count = 0
      for _ in pairs(live) do count = count + 1 end
      return count
    end)(),
    depth=1,
  })

  local corePlan = currentOnlyPlan(state)
  -- render() treats this flag as "do not ask HorizonWall for a draw-time
  -- mesh". Here it is the intentional mobile core path, not an error.
  corePlan.horizonFallback = true
  corePlan.mobileCoreBootstrap = true
  -- Once the update-only scenery lane has completed this exact current-only
  -- HorizonWall key, the same BODY is a closed battle arena too.  A battle no
  -- longer has to wait for unrelated direct-neighbour geometry.
  if type(HorizonWall.cacheStatus) == "function" then
    local okStatus, status = pcall(HorizonWall.cacheStatus, corePlan.state)
    if okStatus and status and status.ready == true then
      corePlan.horizonFallback = nil
      corePlan.mobileCoreClosed = true
    end
  end
  if not baseReady then
    VoxelState.ready = false
    readyMap = nil
    return body, {}, bodyWater, {}, corePlan
  end

  -- BODY + atlas is a complete first publication.  Direct streaming is gated
  -- by the successful endScene receipt set in render(), never by a timer or a
  -- guessed number of update calls.
  VoxelState.ready = true
  readyMap = map
  setActive(state, corePlan.maps)
  traceMobileCore(map, "scene-ready", { mesh="body", directMaps=#directOrder })
  if mobileCoreTrace.presented == true then
    -- Keep one stable current-only plan for the staged resource coroutine. Its
    -- canonical address is value based, so the fresh plan returned to callers
    -- above/below resolves the same HorizonWall receipt.
    if not mobileSceneryPlan then mobileSceneryPlan = corePlan end
    if type(MobileSceneryGate.noteCoreReady) == "function" then
      MobileSceneryGate.noteCoreReady(map)
    end
  end
  -- The ring is admitted from stageMobileScenery(), which runs once in the
  -- pipeline update.  Prefetch merely keeps already admitted BODY jobs alive;
  -- render() can therefore call prefetch again without admitting a second
  -- cold map/atlas in the same physical frame.
  local approachedIndex = seamCandidate(state)
  local nbMesh, nbWater = {}, {}
  for _, i in ipairs(directOrder) do
    local nb = state.neighbors[i]
    if ring.admitted[nb.map.id] then
      local priority = i == approachedIndex and 2 or 1
      ChunkMesher.request(nb.map, true, nil, false, priority)
      nbMesh[i], nbWater[i] = ChunkMesher.pair(nb.map, true)
    end
  end

  -- Semantic outdoor maps never enqueue the current FULL slot on a phone.
  -- Their current-only HorizonWall is already the closed edge treatment and
  -- every admitted direct BODY is promoted independently behind a future
  -- horizon.  Non-semantic interiors/settings retain a maskless current FULL
  -- fallback, but it is independent of the ring and never waits for a direct
  -- map; this removes the old FULL+all-direct atomic dependency everywhere.
  local terrain, terrainWater = body, bodyWater
  -- A failed rich probe is latched for this map object.  Keep drawing the
  -- already proven current BODY contract rather than leaking the unproven
  -- candidate ring into the ordinary (non-scenery) render path.
  local gateState = mobileGateStatus and mobileGateStatus(map) or nil
  local visiblePlan = gateState and gateState.failed and corePlan
                      or mobileSceneryPlan or corePlan
  if not ring.semantic and mobileCoreTrace.presented == true then
    ChunkMesher.request(map, false, nil, false, 2)
    local full, fullWater = ChunkMesher.pair(map, false)
    if full then
      terrain, terrainWater = full, fullWater
      visiblePlan.mobileClosedFull = true
      -- Compatibility receipt for BattleScene versions which predate the
      -- more precise mobileCoreClosed marker.  This is a closed current map,
      -- not the removed all-direct union.
      visiblePlan.mobileDirectUnion = true
      visiblePlan.mobileCoreClosed = true
    end
  end
  setActive(state, visiblePlan.maps)
  return terrain, nbMesh, terrainWater, nbWater, visiblePlan
end

local function semanticPlan(state, nbMesh, nbWater, approachedIndex)
  local previousHandoff = handoffUnion
  local plan, horizonReady

  local function tryUnion(union)
    if not (union and union.ids[state.map.id]) then return nil end
    local candidate = planForIds(state, nbMesh, nbWater, union.ids)
    if not candidate then return nil end
    local _, ready = HorizonWall.meshes(candidate.state)
    if not ready then return nil end
    return candidate
  end

  -- First preserve the exact complete union when only its root changed. If
  -- the new two-hop neighbourhood omits part of that rich survey set, use the
  -- deliberately retained direct-connection handoff instead.
  plan = tryUnion(activeUnion)
  if not plan and previousHandoff ~= activeUnion then
    plan = tryUnion(previousHandoff)
  end
  if plan then
    setActive(state, plan.maps)
    horizonReady = true
  else
    plan = currentOnlyPlan(state)
    local _, ready, buildFailed = HorizonWall.meshes(plan.state)
    horizonReady = ready
    setActive(state, plan.maps)
    -- Active/handoff unions are optional reuse candidates, but this
    -- current-only curtain is the minimum semantic scene. If its exact build
    -- failed, stop staging wider variants and let prefetch switch atomically
    -- to the established FULL-ring path.
    if buildFailed then return plan, false, true end
  end

  -- Keep one root-independent seam answer warm: current plus every direct
  -- connection. All of those maps remain within two hops after crossing any
  -- one of them, unlike an arbitrary survey/full union. The mesh may build
  -- before terrain/aux/atlas; it is only recorded as a handoff after the
  -- complete horizon itself is ready, and tryUnion still gates every body.
  local handoffIds, directOrder = directIds(state)
  local handoffState = stateForIds(state, handoffIds)
  if handoffState then
    local _, ready = HorizonWall.meshes(handoffState)
    if ready then
      handoffUnion = { rootId = state.map.id, ids = copySet(handoffIds) }
    end
  end

  -- Stage exactly one expansion around the currently visible answer. The
  -- approached direct map wins; then remaining direct maps; only after those
  -- do farther survey neighbours enter. A body is promoted in the same call
  -- only when body + aux + atlas + the future horizon are all complete.
  local candidateIndex
  if approachedIndex then
    local nb = state.neighbors[approachedIndex]
    if nb and not activeUnion.ids[nb.map.id] then candidateIndex = approachedIndex end
  end
  if not candidateIndex then
    local waitingDirect
    for _, i in ipairs(directOrder) do
      local nb = state.neighbors[i]
      if nb and not activeUnion.ids[nb.map.id] then
        waitingDirect = waitingDirect or i
        if visuallyReady(nb, i, nbMesh) then
          candidateIndex = i
          break
        end
      end
    end
    candidateIndex = candidateIndex or waitingDirect
  end
  if not candidateIndex then
    for i, nb in ipairs(state.neighbors or {}) do
      if not activeUnion.ids[nb.map.id]
         and visuallyReady(nb, i, nbMesh) then
        candidateIndex = i
        break
      end
    end
  end

  if candidateIndex then
    local futureIds = copySet(activeUnion.ids)
    futureIds[state.neighbors[candidateIndex].map.id] = true
    local futureState = stateForIds(state, futureIds)
    if futureState then
      local _, ready = HorizonWall.meshes(futureState)
      if ready and visuallyReady(state.neighbors[candidateIndex],
                                  candidateIndex, nbMesh) then
        local futurePlan = planForIds(state, nbMesh, nbWater, futureIds)
        if futurePlan then
          plan, horizonReady = futurePlan, true
          setActive(state, futureIds)
        end
      end
    end
  end

  return plan, horizonReady, false
end

-- Request everything `state`'s frame wants and evict what it no longer
-- does; returns the current map's terrain mesh (or nil while it builds)
-- and the neighbour meshes ready to draw. render() calls this for the
-- frame it is drawing, and the pipeline's update hook calls it EVERY
-- frame -- including the frames a warp's Transition covers, when the
-- world pass is off. That update-side call is what lets a door fade hide
-- the destination's build: the map swaps behind the fade, and waiting
-- for the first visible frame to request meshes would show the flat
-- fallback while the first slices run.
function VoxelScene.prefetch(state)
  if MOBILE_RUNTIME then return mobileCorePrefetch(state) end
  local Voxel = V.require("VoxelState")
  local approachedIndex = seamCandidate(state)

  -- The live set is the current map plus its rendered neighbours. When
  -- it changes, everything outside it (and the previous set, which
  -- ChunkMesher retains so stepping into a house keeps the town warm)
  -- is evicted -- meshes released, analysis dropped -- so memory stays
  -- bounded by the neighbourhood instead of growing with every area
  -- ever visited.
  local liveKey = state.map.id
  local live = { [state.map.id] = true }
  for _, nb in ipairs(state.neighbors or {}) do
    live[nb.map.id] = true
    liveKey = liveKey .. "|" .. nb.map.id
  end
  if liveKey ~= lastLiveKey then
    lastLiveKey = liveKey
    ChunkMesher.setLive(live)
    -- RED++ bakes one atlas per map, so its animated copy is per map too
    -- and is bounded by the same neighbourhood
    TerrainAtlas.setLive(live)
  end

  -- Retire one cold draw resource per prefetch call, while transitions and
  -- the complete 2D fallback are still in charge. Glass is current-map-only;
  -- RED++ animation atlases then warm current map first and connected maps in
  -- source order. A ready neighbour whose atlas is still cold stays out of
  -- drawPlan (and therefore behind the already closed horizon) until a later
  -- call finishes it. This removes first-use work from the visible draw while
  -- keeping every eventual pixel identical.
  local preparedOne = false
  local GlassMask = V.require("GlassMask")
  local wantsGlass = not MOBILE_RUNTIME and HorizonWall.hasSky(state.map)
  if wantsGlass and GlassMask.prepared and GlassMask.prepare
     and not GlassMask.prepared(state.map.tileset) then
    GlassMask.prepare(state.map.tileset)
    preparedOne = true
  end
  if not preparedOne and TerrainAtlas.prepared and TerrainAtlas.prepare then
    local warmMaps = { state.map }
    if approachedIndex and state.neighbors[approachedIndex] then
      warmMaps[#warmMaps + 1] = state.neighbors[approachedIndex].map
    end
    for i, nb in ipairs(state.neighbors or {}) do
      if i ~= approachedIndex then warmMaps[#warmMaps + 1] = nb.map end
    end
    for _, map in ipairs(warmMaps) do
      if not TerrainAtlas.prepared(map) then
        TerrainAtlas.prepare(map)
        break
      end
    end
  end

  -- masks: where connected neighbour BODIES sit, so the border ring is
  -- suppressed under them (see runGeometry)
  local masks = {}
  for _, nb in ipairs(state.neighbors or {}) do
    masks[#masks + 1] = { nb.ox, nb.oy,
                          nb.ox + nb.map.def.width * 32,
                          nb.oy + nb.map.def.height * 32 }
  end

  -- Builds are asynchronous (ChunkMesher.pump runs in the pipeline's
  -- update): request what this frame wants and draw what is ready.
  -- The current map asks for the one variant its edge treatment needs:
  -- body-only under semantic scenery, or the masked full border otherwise.
  -- A connected map contributes only once its body-only slot and atomic aux
  -- bundle exist. Until then the filtered horizon closes that seam; there is
  -- no terrain-first grass/flower/figure pop and no mismatched full stand-in
  -- whose border could overlap the curtain or the current body.
  -- The water surface rides along with whichever variant answers: it was
  -- cut out of that build's own geometry (ChunkMesher.pair), so the two
  -- always come from the same slot and a lake is never drawn twice or left
  -- as a hole.
  -- On a cold semantic map the body is the smallest complete scene the player
  -- can walk on because the horizon supplies its edge. Previously the swap
  -- still waited for every connected body, even when they were off-screen.
  local semanticBody = HorizonWall.preferBody(state.map)
  local cutawayBody = cutawayBodyOnly(state.map, Voxel.level)
  local preferBody = semanticBody or cutawayBody
  -- Request the geometry this visual mode actually needs. A body mesh is not
  -- a complete fallback when SCENERY is off (or indoors): without its ring it
  -- exposes the void. Outdoor semantic scenery deliberately chooses body-only
  -- because the cheap panorama is its edge closure.
  ChunkMesher.request(state.map, preferBody,
                      preferBody and nil or masks, true)
  local terrain, water = ChunkMesher.pair(state.map, preferBody)
  local nbMesh, nbWater = {}, {}
  local directSet = directIds(state)
  for i, nb in ipairs(state.neighbors or {}) do
    -- Connected bodies are enough here: the current map's masked full ring is
    -- the legacy closure when SCENERY is off, while semantic scenery closes
    -- the whole streamed union itself. With semantic scenery the current map
    -- is the only urgent job: cold neighbours continue on the ordinary frame
    -- budget after that complete first scene has appeared. The legacy/full
    -- path remains atomic and therefore keeps all of its required bodies
    -- urgent, exactly as before.
    local backgroundRank = 0
    if preferBody then
      if i == approachedIndex then backgroundRank = 2
      elseif directSet[nb.map.id] then backgroundRank = 1 end
    end
    ChunkMesher.request(nb.map, true, nil, not preferBody, backgroundRank)
    -- Neighbours are always requested body-only above; their own panorama
    -- class only controls the union's curtain, not this cache slot.
    nbMesh[i], nbWater[i] = ChunkMesher.pair(nb.map, true)
  end

  -- Prepare the tiny panorama mesh/Canvas during update-time prefetch. It is
  -- independent of terrain atlases, so the eventual first 3D draw only reads
  -- an already complete background and never changes Canvas targets mid-pass.
  --
  -- Outdoors/caves with semantic scenery can safely open on the CURRENT body
  -- alone. The horizon is built from exactly the neighbours whose bodies are
  -- already drawable: its curtain therefore closes every still-cold seam.
  -- When another body lands, the synchronous horizon cache swap removes that
  -- seam's curtain and extends around the new union in the same frame -- never
  -- a body over an old wall (z-fighting), and never an absent body behind an
  -- already-open edge (void).
  --
  -- A failed expanded horizon is not allowed to expose the new body. Rebuild
  -- the cheap current-only closure and retain a complete smaller scene. If
  -- even that cannot be made, Voxel.ready keeps the engine's 2D world.
  local plan
  local horizonReady
  if semanticBody then
    local horizonFailed
    plan, horizonReady, horizonFailed = semanticPlan(
      state, nbMesh, nbWater, approachedIndex)
    if horizonFailed then
      -- A failed semantic curtain can never make a body-only map complete.
      -- Fall back to the same masked FULL ring used when scenery is off, and
      -- preserve that path's atomic rule: the full current map plus every
      -- connected body/aux/atlas must be ready together. Until then
      -- Voxel.ready remains false and the engine keeps its complete 2D world.
      ChunkMesher.request(state.map, false, masks, true)
      terrain, water = ChunkMesher.pair(state.map, false)
      for i, nb in ipairs(state.neighbors or {}) do
        ChunkMesher.request(nb.map, true, nil, true)
        nbMesh[i], nbWater[i] = ChunkMesher.pair(nb.map, true)
      end
      plan = drawPlan(state, nbMesh, nbWater)
      plan.horizonFallback = true
      horizonReady = #plan.state.neighbors == #(state.neighbors or {})
    end
  elseif cutawayBody then
    -- FULL presents an ordinary interior as an open dollhouse. Its body-only
    -- mesh is complete by design: the omitted repeated border ring is exactly
    -- the camera-side wall/roof being removed, not missing streamed scenery.
    -- Connected bodies (unusual for an interior, but valid for extensions)
    -- remain atomic so a real doorway can never open onto a cold void.
    plan = drawPlan(state, nbMesh, nbWater)
    horizonReady = #plan.state.neighbors == #(state.neighbors or {})
  else
    -- SCENERY OFF/interiors use the current map's masked full border. Its
    -- connection masks assume every neighbour body is present, so this path
    -- must preserve the old atomic swap or it would reveal real holes.
    plan = drawPlan(state, nbMesh, nbWater)
    local allReady = #plan.state.neighbors == #(state.neighbors or {})
    local _, fullHorizonReady = HorizonWall.meshes(state)
    horizonReady = fullHorizonReady and allReady
  end
  local glassReady = not wantsGlass or not GlassMask.prepared
                     or GlassMask.prepared(state.map.tileset)
  local complete = terrain ~= nil and horizonReady and atlasPrepared(state.map)
                   and glassReady
  Voxel.ready = complete
  readyMap = complete and state.map or nil
  -- Publish the exact plan that can become visible, regardless of which edge
  -- treatment produced it. Semantic scenery maintains this receipt while it
  -- stages seam unions, but FULL interiors, cutaways and the masked FULL
  -- fallback also need to replace a previous map's root once their complete
  -- scene is ready. Never advertise an incomplete plan: until this gate opens
  -- the engine is still presenting its 2D fallback.
  if complete then setActive(state, plan.maps) end
  -- The first four values are BattleScene's established, sparse/index-aligned
  -- contract. The fifth is overworld-private and safe for old Lua callers to
  -- ignore.
  return terrain, nbMesh, water, nbWater, plan
end

mobileGateStatus = function(map)
  if type(MobileSceneryGate.status) ~= "function" then return nil end
  local ok, status = pcall(MobileSceneryGate.status, map)
  return ok and type(status) == "table" and status or nil
end

local function mobileRingPairs(state, ring)
  local meshes, waters = {}, {}
  local _, directOrder = directIds(state)
  for _, i in ipairs(directOrder) do
    local nb = state.neighbors[i]
    if nb and nb.map and ring.admitted[nb.map.id] then
      meshes[i], waters[i] = ChunkMesher.pair(nb.map, true)
    end
  end
  return meshes, waters, directOrder
end

local function nextMobileRingAdmission(state, ring, directOrder)
  local approached = seamCandidate(state)
  if approached then
    local nb = state.neighbors[approached]
    local id = nb and nb.map and nb.map.id
    if id and not ring.admitted[id] and not ring.failed[id] then
      return approached
    end
  end
  for _, i in ipairs(directOrder) do
    local nb = state.neighbors[i]
    local id = nb and nb.map and nb.map.id
    if id and not ring.admitted[id] and not ring.failed[id] then return i end
  end
end

local function nextMobileRingCandidate(state, ring, meshes, directOrder)
  local visible = mobileSceneryPlan and mobileSceneryPlan.maps
                  or { [state.map.id] = true }
  local approached = seamCandidate(state)
  local function ready(i)
    local nb = i and state.neighbors[i]
    local id = nb and nb.map and nb.map.id
    return id and ring.admitted[id] and not ring.failed[id]
           and not visible[id] and visuallyReady(nb, i, meshes)
  end
  if ready(approached) then return approached end
  for _, i in ipairs(directOrder) do if ready(i) then return i end end
end

-- Advance Gen2-style depth-1 residency from the pipeline update only.  The
-- return tuple begins with `handled`: callers must not fall through into a
-- second upload/mesh action when a ring step already consumed this update.
local function advanceMobileRing(state)
  local map = state.map
  local ring = ringFor(map)
  if not ring.semantic then return false end

  local status = mobileGateStatus(map)
  if not status or status.failed then return false end

  -- finishProbe is the only proof that the candidate canvas actually became
  -- safe.  Until that render happens, keep every other admission/promotion
  -- paused and let render() consume the already prepared plan.
  if ring.promoting then
    if not status.active then return true, false, "direct-ring-probe" end
    setActive(state, mobileSceneryPlan.maps)
    traceMobileCore(map,
      "direct-visible-" .. tostring(ring.promoting.mapId), {
        neighbor=ring.promoting.mapId,
        visibleMaps=#(mobileSceneryPlan.state.neighbors or {}) + 1,
        depth=1,
      })
    ring.promoting = nil
  end

  if not status.active then return false end

  -- The future horizon is cooperative and may need several updates.  It is
  -- built while Gate.active keeps the previous canvas visible.  Only a ready
  -- horizon can arm the one-frame ping-pong promotion; a failed neighbour is
  -- skipped without poisoning the current core or its other direct seams.
  if ring.pending then
    local pending = ring.pending
    local ok, horizonOrError, ready, failed = pcall(
      HorizonWall.meshes, pending.plan.state)
    if ok and ready == true then
      local begin = type(MobileSceneryGate.beginRingPromotion) == "function"
                    and MobileSceneryGate.beginRingPromotion(map) == true
      if not begin then return true, false, "direct-ring-promotion-gate" end
      pending.plan.horizonFallback = nil
      pending.plan.mobileCoreClosed = true
      pending.plan.mobileRingDepth = 1
      mobileSceneryPlan = pending.plan
      mobileSceneryHorizonMap, mobileSceneryHorizon =
        map, horizonOrError or {}
      ring.pending = nil
      ring.promoting = pending
      traceMobileCore(map,
        "direct-horizon-ready-" .. tostring(pending.mapId), {
          neighbor=pending.mapId,
          visibleMaps=#(pending.plan.state.neighbors or {}) + 1,
          depth=1,
        })
      return true, true, "direct-ring-horizon"
    end
    if not ok or failed == true then
      ring.failed[pending.mapId] = true
      ring.pending = nil
      mobileDiagnostic("fallback", "mobile-direct-ring-horizon",
        ok and "build-failed" or tostring(horizonOrError),
        "previous-ring-retained", {
          caller="VoxelScene.stageMobileScenery", context="world",
          map=map.id, neighbor=pending.mapId, depth=1,
        })
      return true, false, "direct-ring-horizon-failed"
    end
    return true, false, "direct-ring-horizon"
  end

  local meshes, waters, directOrder = mobileRingPairs(state, ring)
  local candidateIndex = nextMobileRingCandidate(
    state, ring, meshes, directOrder)
  if candidateIndex then
    local nb = state.neighbors[candidateIndex]
    local futureIds = copySet(mobileSceneryPlan.maps)
    futureIds[nb.map.id] = true
    local plan = planForIds(state, meshes, waters, futureIds)
    if plan then
      ring.pending = {
        mapId=nb.map.id, index=candidateIndex, plan=plan,
      }
      return true, false, "direct-ring-candidate"
    end
  end

  -- Admit no more than one cold map in this update.  Atlas preparation and
  -- the first BODY request stay together so the following bounded mesher pump
  -- can immediately spend its slice on that exact direct neighbour.
  local admission = nextMobileRingAdmission(state, ring, directOrder)
  if admission then
    local nb = state.neighbors[admission]
    local id = nb.map.id
    ring.admitted[id] = true
    setMobileRingLive(state, ring)
    if TerrainAtlas.prepared and TerrainAtlas.prepare
        and not TerrainAtlas.prepared(nb.map) then
      TerrainAtlas.prepare(nb.map)
    end
    local approached = seamCandidate(state)
    ChunkMesher.request(nb.map, true, nil, false,
                        admission == approached and 2 or 1)
    traceMobileCore(map, "direct-admitted-" .. tostring(id), {
      neighbor=id, depth=1, atlasReady=atlasPrepared(nb.map),
    })
    return true, true, "direct-ring-admit"
  end

  return false
end

-- Update-only P1 resource lane. The draw path never resumes a HorizonWall
-- coroutine or decodes a panorama/sky atlas. Each invocation performs at most
-- one bounded resource/ring action after the real current BODY canvas receipt.
function VoxelScene.stageMobileScenery(state)
  if not MOBILE_RUNTIME or not (state and state.map) then return false end
  local map = state.map
  if mobileSceneryPlanMap ~= map or not mobileSceneryPlan then return false end

  if type(MobileSceneryGate.nextResource) ~= "function" then return false end

  local resource = MobileSceneryGate.nextResource(map)
  if resource == "horizon" then
    if type(HorizonWall.enabled) == "function"
        and HorizonWall.enabled() == false then
      mobileSceneryHorizonMap, mobileSceneryHorizon = map, {}
      MobileSceneryGate.noteResource(map, "horizon", true,
        "disabled-by-user-setting")
      return true, "horizon-disabled"
    end
    local ok, meshesOrError, ready, failed = pcall(
      HorizonWall.meshes, mobileSceneryPlan.state)
    if ok and ready == true then
      mobileSceneryPlan.horizonFallback = nil
      mobileSceneryPlan.mobileCoreClosed = true
      mobileSceneryHorizonMap, mobileSceneryHorizon = map, meshesOrError or {}
      MobileSceneryGate.noteResource(map, "horizon", true)
      return true, "horizon"
    end
    if not ok or failed == true then
      mobileDiagnostic("fallback", "mobile-scenery-horizon",
        ok and "build-failed" or tostring(meshesOrError),
        "m10-retained", {
          caller="VoxelScene.stageMobileScenery", context="world",
          map=map.id,
        })
      if type(MobileSceneryGate.fail) == "function" then
        MobileSceneryGate.fail(map,
          ok and "horizon-build-failed" or tostring(meshesOrError))
      end
    end
    return false, "horizon"
  end

  if resource == "panorama" then
    local enabled = type(HorizonWall.enabled) ~= "function"
                    or HorizonWall.enabled() ~= false
    PanoramaBackdrop.setEnabled(enabled)
    if not enabled or not HorizonWall.hasSky(map) then
      MobileSceneryGate.noteResource(map, "panorama", true,
        enabled and "not-applicable-indoors" or "disabled-by-user-setting")
      return true, "panorama-not-applicable"
    end
    local ready = type(PanoramaBackdrop.ready) == "function"
                  and PanoramaBackdrop.ready() == true
    local prepareReason, prepareRetryable = nil, false
    if not ready then
      local ok, result, reason, retryable = pcall(PanoramaBackdrop.prepare)
      if not ok then
        if type(MobileSceneryGate.fail) == "function" then
          MobileSceneryGate.fail(map,
            "panorama-prepare-error:" .. tostring(result))
        end
        return false, "panorama-error"
      end
      ready = result == true
      prepareReason = reason or "panorama-prepare-failed"
      -- Keep compatibility with a provider that still returns only boolean,
      -- but the product PanoramaBackdrop always supplies this classification.
      prepareRetryable = retryable ~= false
    end
    if ready then
      MobileSceneryGate.noteResource(map, "panorama", true)
      return true, "panorama"
    end

    MobileSceneryGate.noteResource(map, "panorama", false,
      prepareReason)
    local rearm = type(MobileSceneryGate.retryResource) == "function"
      and MobileSceneryGate.retryResource(
        map, "panorama", prepareReason, prepareRetryable) == true
    if rearm then
      -- Rearm only the failed GPU stage. Preserve already decoded ImageData or
      -- a successfully uploaded texture across this bounded map lifecycle.
      local reset = PanoramaBackdrop.rearm or PanoramaBackdrop.invalidate
      local resetOK, resetResult = pcall(reset)
      if resetOK and resetResult ~= false then
        return false, "panorama-rearm"
      end
      if type(MobileSceneryGate.fail) == "function" then
        MobileSceneryGate.fail(map,
          "panorama-rearm-error:" .. tostring(resetResult))
      end
      return false, "panorama-error"
    end
    if type(MobileSceneryGate.fail) == "function" then
      MobileSceneryGate.fail(map,
        "panorama-prepare-terminal:" .. tostring(prepareReason))
    end
    return false, "panorama-terminal"
  end

  local ringHandled, ringReady, ringName = advanceMobileRing(state)
  if ringHandled then return ringReady, ringName end

  if type(MobileSceneryGate.assetWarmAllowed) ~= "function"
      or MobileSceneryGate.assetWarmAllowed(map) ~= true then
    return false
  end

  if mobileSkyWarmMap ~= map then
    mobileSkyWarmMap, mobileSkyWarmPhase = map, "clouds"
  end
  local cloudsOff = Sky.cloudSetting
    and type(Sky.cloudSetting.get) == "function"
    and Sky.cloudSetting:get() == "off"
  if mobileSkyWarmPhase == "events" and not cloudsOff
      and type(Sky.cloudAssetStatus) == "function" then
    local ok, status = pcall(Sky.cloudAssetStatus)
    if ok and status == "cold" then mobileSkyWarmPhase = "clouds" end
  end
  if mobileSkyWarmPhase == "clouds" then
    if cloudsOff or type(Sky.prewarmClouds) ~= "function" then
      mobileSkyWarmPhase = "events"
      return true, "clouds-not-applicable"
    end
    local ok, ready, attempted = pcall(Sky.prewarmClouds)
    if ok and (ready == true or (tonumber(attempted) or 0) > 0) then
      mobileSkyWarmPhase = "events"
    end
    return ok and ready == true, "clouds"
  end

  if type(SkyEvents.prewarm) == "function" then
    -- prewarm(1) guarantees no more than one event family upload this update.
    local ok = pcall(SkyEvents.prewarm, 1)
    return ok, "sky-event"
  end
  return false
end

-- Read-only update predicate used outside the ordinary VOXEL active/warm
-- branch.  It never creates a cold transaction; it only finishes an already
-- armed map lifecycle, one bounded action per update via stageMobileScenery.
function VoxelScene.mobileSceneryLifecyclePending(state)
  if not MOBILE_RUNTIME or not mobileSceneryLifecycleArmed
      or not (state and state.map) then return false end
  local map = state.map
  if mobileSceneryPlanMap ~= map or not mobileSceneryPlan then return true end
  if type(MobileSceneryGate.shouldDrive) == "function"
      and MobileSceneryGate.shouldDrive(map) == true then
    return true
  end
  if mobileRingPlanMap == map and mobileRing and mobileRing.semantic then
    local status = mobileGateStatus(map)
    if status and not status.failed then
      if mobileRing.pending or mobileRing.promoting then return true end
      local visible = mobileSceneryPlan.maps or {}
      local _, directOrder = directIds(state)
      for _, i in ipairs(directOrder) do
        local nb = state.neighbors[i]
        local id = nb and nb.map and nb.map.id
        if id and not visible[id] and not mobileRing.failed[id] then
          return true
        end
      end
    end
  end
  return false
end

function VoxelScene.invalidateMobileScenery(reason)
  mobileSceneryPlanMap, mobileSceneryPlan = nil, nil
  mobileRingPlanMap, mobileRing = nil, nil
  mobileSceneryHorizonMap, mobileSceneryHorizon = nil, nil
  mobileSkyWarmMap, mobileSkyWarmPhase = nil, "clouds"
  mobileSceneryCanvasMap, mobileSceneryNextSlot = nil, "mobile-scenery"
  mobileCoreTrace.map, mobileCoreTrace.mapObject = nil, nil
  mobileCoreTrace.phases, mobileCoreTrace.presented = {}, false
  mobileSceneryLifecycleArmed = false
  readyMap, Voxel.ready = nil, false
  if type(MobileSceneryGate.invalidate) == "function" then
    MobileSceneryGate.invalidate(reason or "graphics-context")
  end
end

function VoxelScene.requireExternalKascWalker(player, sprite)
  return ExternalKascWalker.resolve(player, sprite)
end

-- Capture every entity's pose for this frame. pose() advances the hop /
-- surf bob / spinner timers, so it must be called EXACTLY once per entity
-- per frame -- the sun pass and the character pass then read the same
-- answer instead of disagreeing by a tick. Ghost NPCs live on a neighbour
-- map, so their position, ground lookup and palette all belong to that
-- map. pose() returns the VISUAL y (ledge hops arc it, surfing bobs it);
-- the difference from the entity's base y becomes vertical LIFT in 3D, so
-- a hop rises off the ground instead of sliding north.
-- Returns the pose list and, separately, the PLAYER's entry in it (nil
-- during a Fly animation, which draws the player itself and is skipped
-- below). Only that one entry gets the see-through treatment: NPCs and the
-- ghosts standing on a neighbour map are left to honest occlusion, because
-- it is only your own character you cannot afford to lose behind a roof.
local function posesOf(state, spriteColors, drawableMaps, externalPlayerWalker)
  local colors = spriteColors(state.map)
  local posed = {}
  local me = nil
  for _, g in ipairs(state.ghosts or {}) do
    local ghostMap = g.map or state.map
    -- A connected-map NPC must arrive with its ground, not hover over the
    -- temporary horizon closure while that neighbour is still meshing.
    if not drawableMaps or drawableMaps[ghostMap.id] then
      local sprite, vx, vy, facing, phase, flip, hopping = g.npc:pose()
      posed[#posed + 1] = {
        sprite = sprite, px = vx + g.ox, py = g.npc.py + g.oy,
        facing = facing, phase = phase, flip = flip,
        gh = groundForEntity(ghostMap, g.npc, hopping),
        lift = g.npc.py - vy, colors = spriteColors(ghostMap),
      }
    end
  end
  for _, e in ipairs(state.entities or {}) do
    if not (state.flyAnim and e == state.player) then
      local sprite, vx, vy, facing, phase, flip, hopping = e:pose()
      if e == state.player and externalPlayerWalker then
        -- Keep the native/KASC 2-D renderer on the entity. Only this captured
        -- 3-D pose receives the approved preflighted walker for its identity.
        sprite = externalPlayerWalker
      end
      posed[#posed + 1] = {
        sprite = sprite, px = vx, py = e.py,
        facing = facing, phase = phase, flip = flip,
        gh = groundForEntity(state.map, e, hopping),
        lift = e.py - vy, colors = colors,
      }
      if e == state.player then
        me = posed[#posed]
        -- marked so the camera draw can leave the card out in first
        -- person, where it would fill the lens from inside; the SUN pass
        -- reads the same list and deliberately does not check the mark
        me.isPlayer = true
      end
    end
  end
  return posed, me
end

-- ------- the glint's drive
--
-- A reflection is something the VIEWPOINT does, so the window glint is fed
-- by the camera's own travel rather than by a clock: its phase advances
-- with distance covered and its strength fades in over a few steps of
-- walking and back out within a beat of standing still. Stand still and
-- the glass is still; move and the light crosses it.
-- The rate is slow on purpose: the sweep pattern lives in the pane's own
-- texels (see the scene shader), so this is a FRACTION of a texel per world
-- pixel walked -- one full pass of the glint across a pane per eight or so
-- cells of travel, with no frame ever jumping it far enough to strobe.
VoxelScene.GLINT_RATE = 0.05     -- radians of sweep per world pixel travelled
VoxelScene.GLINT_IN = 0.12      -- strength gained per moving frame
VoxelScene.GLINT_OUT = 0.08     -- and lost per resting frame

function VoxelScene.glintStep(g, cx, cy)
  local dist = 0
  if g.x then
    dist = math.abs(cx - g.x) + math.abs(cy - g.y)
  end
  g.x, g.y = cx, cy
  g.phase = ((g.phase or 0) + dist * VoxelScene.GLINT_RATE) % (2 * math.pi)
  if dist > 0.05 then
    g.amp = math.min(1, (g.amp or 0) + VoxelScene.GLINT_IN)
  else
    g.amp = math.max(0, (g.amp or 0) - VoxelScene.GLINT_OUT)
  end
  return g
end

local glint = {}

-- A character card is exactly one 16px cell wide and tall
-- (SpriteBillboards.buildCard).  The first-person eye stands at the centre
-- of the player's cell, thirteen pixels above its floor.  Therefore a card
-- one cell straight ahead occupies
--
--   atan(13 / 16) + atan(3 / 16) = 49.7 degrees
--
-- of the 65-degree vertical lens: a follower in the nearest legal trail cell
-- is not a readable character, it is the inside of a card covering the view.
-- At two cells that span is only 27.5 degrees and the character is readable,
-- so the near volume is pinned to ONE card width rather than an aesthetic
-- distance.  Width is tested just as strictly: the camera's optical-centre
-- ray must actually pierce the eye-facing 16x16 card.  A close actor behind,
-- beside, above or below the look ray consequently stays drawn.
local ACTOR_CARD_SIZE = 16
local ACTOR_CARD_HALF = ACTOR_CARD_SIZE / 2
local ACTOR_NEAR_SQ = ACTOR_CARD_SIZE * ACTOR_CARD_SIZE
local ACTOR_EPS = 1e-6

local function actorEngulfsEye(p)
  local eye, focus = Voxel3D.eye, Voxel3D.focus
  if not (p and type(p.px) == "number" and type(p.py) == "number"
          and eye and focus and eye[1] and eye[2] and eye[3]
          and focus[1] and focus[2] and focus[3]) then
    return false
  end

  local foot = (p.gh or 0) + (p.lift or 0)
  local cx, cz = p.px + ACTOR_CARD_HALF, p.py + ACTOR_CARD_HALF
  local dx, dz = cx - eye[1], cz - eye[3]
  local rangeSq = dx * dx + dz * dz
  if rangeSq > ACTOR_NEAR_SQ + ACTOR_EPS then return false end

  -- A follower may spawn on the player's own cell when the cell behind is
  -- blocked.  The camera is then in the card plane itself; vertical overlap
  -- is the complete and direction-independent answer.
  if rangeSq < ACTOR_EPS * ACTOR_EPS then
    return eye[2] >= foot - ACTOR_EPS
           and eye[2] <= foot + ACTOR_CARD_SIZE + ACTOR_EPS
  end

  -- Normalized optical-centre ray.  Its intersection with the cylindrical
  -- billboard's plane is solved in scalars: the card normal points from its
  -- centre to the eye, so t = range^2 / dot(forward_xz, eye_to_card).
  local fx, fy, fz = focus[1] - eye[1], focus[2] - eye[2],
                     focus[3] - eye[3]
  local forwardSq = fx * fx + fy * fy + fz * fz
  if forwardSq < ACTOR_EPS * ACTOR_EPS then return false end
  local invForward = 1 / math.sqrt(forwardSq)
  fx, fy, fz = fx * invForward, fy * invForward, fz * invForward
  local ahead = fx * dx + fz * dz
  if ahead <= ACTOR_EPS then return false end
  local t = rangeSq / ahead

  local hitX, hitY, hitZ = eye[1] + fx * t, eye[2] + fy * t,
                           eye[3] + fz * t
  local range = math.sqrt(rangeSq)
  -- A horizontal tangent of the card that cardYaw turns toward this eye.
  -- Only its sign is arbitrary, and the bound below is symmetric.
  local tangentX, tangentZ = -dz / range, dx / range
  local lateral = (hitX - cx) * tangentX + (hitZ - cz) * tangentZ
  return math.abs(lateral) <= ACTOR_CARD_HALF + ACTOR_EPS
         and hitY >= foot - ACTOR_EPS
         and hitY <= foot + ACTOR_CARD_SIZE + ACTOR_EPS
end

-- A named, pure camera-space seam for the focused headless contract.  It
-- allocates nothing and owns no render/game state.
VoxelScene._actorEngulfsEye = actorEngulfsEye

-- ------- the cast
--
-- Everybody standing on the map: the walkers, and the authored FIGURES the
-- tileset draws into its own furniture (they ARE characters as far as the
-- artwork is concerned, just ones drawn by the tileset instead of by a
-- sprite sheet, so they get the same lean and the same camera-ward pull).
--
-- One function because it is drawn TWICE and the two must be identical: once
-- into the frame, and once into the water's reflection copy (see drawWater --
-- Gen 1 draws people over the world, and water is world, so the cast cannot
-- be composited before the water it has to appear in).
--
-- Characters carry no wireframe out here, whatever the V-GRID row says. The
-- seams are what makes the WORLD read as built out of voxels, and the people
-- walking around in it are the one thing that should read as drawn instead --
-- a grid over a 16x16 sprite lands a line every couple of display pixels and
-- turns a face into a mesh. (The battle pass makes the opposite call for its
-- own combatants, deliberately -- see BattleBillboard.)
--
-- Sprite sheets until the figure pass: their texture coordinates mean
-- nothing to the tileset-shaped glass mask, so the glass is off or the
-- panes' atlas positions stripe the cast with lamplight at night.
local function drawCast(state, posed, atlasFor)
  Voxel3D.glass(false)
  Voxel3D.seams(false)
  -- Characters, normally depth-tested: the camera-ward pull inside
  -- drawEntity resolves the lean-over-the-wall-in-front case, and a
  -- character genuinely behind a building is far deeper and loses the
  -- test, so buildings and trees really occlude.
  --
  -- In first person three of them change: the player's own card is left out
  -- (the eye is standing in it); another actor whose nearest-cell card
  -- actually engulfs the optical centre is left out for the same reason; and
  -- every other card wears the frame its pose SHOWS this eye (viewFacing)
  -- rather than the one it shows the south.  The near test is gated by the
  -- exact 1ST level as well as hideMe: a wall-collapsed 3RD camera may hide
  -- its own player card, but must never make surrounding actors disappear.
  -- Both camera draws run through here, so the water's reflection copy
  -- agrees with the frame to the pixel; the sun pass deliberately does not
  -- and the hidden actor keeps casting its ordinary world shadow.
  local hideMe = FirstPerson.hidePlayer()
  -- SURF replaces player+mount with one dense card. During a 3RD camera or
  -- zoom transition its boom can momentarily be wall-collapsed; suppressing
  -- that whole card produces the photographed rider/mount disappearance.
  -- Genuine 1ST remains unchanged because this exception is 3RD-only and
  -- SpeciesSurfCinematic sets the marker only around its VASC draw call.
  local player = state and state.player
  if hideMe and player and player.__vascSpeciesSurfForceVisible
      and type(Voxel.isThirdPerson) == "function"
      and Voxel.isThirdPerson(Voxel.level) then
    hideMe = false
  end
  local hideNearActor = hideMe and Voxel.isFirstPerson(Voxel.level)
  for _, p in ipairs(posed) do
    local hidden = p.isPlayer and hideMe
    if not hidden and hideNearActor and not p.isPlayer then
      hidden = actorEngulfsEye(p)
    end
    if not hidden then
      drawEntity(p.sprite, p.px, p.py, viewFacing(p), p.phase, p.flip, p.gh,
                 p.colors, p.lift)
    end
  end
  -- back on for everything textured from the atlas again -- figures, grass
  -- and flowers all sample it, where the mask's coordinates are honest
  Voxel3D.glass(true)
  -- Figures after the walkers, so a player standing in front of the couch
  -- wins the overlap -- the order the flat game draws them in.
  local figPull = billboardPull()
  eachFigure(state.map, 0, 0, function(mesh, model, caster)
    Voxel3D.draw(mesh, atlasFor(state.map), model, figPull,
                 ShadowMap.snug(caster))
  end)
  for _, nb in ipairs(state.neighbors or {}) do
    eachFigure(nb.map, nb.ox, nb.oy, function(mesh, model, caster)
      Voxel3D.draw(mesh, atlasFor(nb.map), model, figPull,
                   ShadowMap.snug(caster))
    end)
  end
  -- and the seams are back on for the terrain art that follows: grass and
  -- flowers are the world's own drawing, not people
  Voxel3D.seams(true)
end

VoxelScene._drawCast = drawCast       -- named for the focused draw contract

-- ------- the water pass
--
-- Between the terrain and everything that stands on it, because water is a
-- MIRROR and a mirror can only reflect what is already down: the ground, the
-- shoreline, the trees and buildings behind it, and the sky the frame opened
-- with.
--
-- THE CAST IS THE AWKWARD ONE, and it is settled by drawing it twice. Gen 1
-- draws people over the world and water is world, so a surfing player has to
-- composite OVER the water they are sitting on -- which puts them after it,
-- and a reflection can only hold what came before it. So `cast` is painted
-- into the reflection copy alone (Voxel3D.beginWater), where it is in the
-- picture the water reflects and not yet in the picture the water is drawn
-- into. Both draws go through drawCast, so they cannot come out different.
--
-- The ray march finds them the honest way round: a sprite is not in the
-- DEPTH buffer at that point, so a ray aimed at one passes through to the
-- terrain standing behind it and reads the copy there -- where the sprite is
-- already painted. The reflection lands a hair off the sprite's own depth
-- and exactly on its colour, which at a lake's worth of ripple is the same
-- picture.
--
-- `draws` is a list of { mesh, texture, model }. Nothing is a special case:
-- with the row OFF, no depth texture to read, or a shader that would not
-- build, the same meshes go through the ordinary scene shader and come out
-- as the flat animated water this mode always drew.
-- The overworld's alone: the staged battle draws its water plain, always --
-- its placed camera reads this pass wrong, and a stage set wants painted
-- water anyway (see BattleScene, where the choice is argued).
-- ------- and why the flat draw happens FIRST while the world is curved
--
-- The reflective pass writes no depth -- it cannot, the depth canvas is
-- detached for the length of it so the shader can READ it -- and it does its
-- own depth test against that texture instead. That test asks whether
-- something opaque is in front, and it answers correctly for every case but
-- one: WATER IN FRONT OF WATER. Nothing puts water in the depth buffer, so
-- no lake can hide another, and the pass simply paints them in mesh order.
--
-- On a flat world that never matters: every surface lies in the one plane
-- at its own recessed height, and a farther sheet always lands farther down
-- the screen. THE WORLD CURVE ENDS THAT. The bend drops the world by the
-- square of its distance, so the far side of the map swings down and back
-- up into the near field of view -- and a sheet of sea a hundred and fifty
-- tiles away, drawn later in the same mesh, paints straight over the pond
-- at the player's feet. Not a reflection of the far shore: the far shore
-- itself, rasterised on top of the water in front of you.
--
-- So WHILE THE CURVE IS ON, the meshes go down flat first, through the
-- ordinary scene shader with depth writes on, and the reflective pass draws
-- over the top of what survived: the depth buffer now holds the water
-- surface, so the pass's own test throws the far sheet away, and the
-- reflection COPY holds it too, so a ray grazing another part of the lake
-- reads water rather than the void behind it.
--
-- With the curve OFF the prepass is not just unnecessary, it is a LIABILITY,
-- and it stays off -- the reflective pass tests only against terrain, as it
-- always did. Painting the surface into the depth texture turns the pass's
-- test into a comparison of the surface against ITSELF, which asks the two
-- rasterisations to agree to within interpolation error -- and on mobile
-- GPUs they don't reliably (that fight is what put the Android port back on
-- flat water). Confined to the curve there is no regression to reach: the
-- flat world never had the far-shore bug in the first place.
function VoxelScene.drawWater(draws, cast, options)
  -- Reflections need another scene copy, optional readable depth and a second
  -- fragment program. The mobile world-core pass keeps water as ordinary
  -- textured geometry; it is still water from the ROM atlas, merely without
  -- the desktop-only screen-space reflection chain.
  if MOBILE_RUNTIME then
    for _, d in ipairs(draws) do
      Voxel3D.draw(d[1], d[2], d[3])
    end
    return
  end
  -- prepass only under the bend; see the header
  local curved = (Voxel3D.curveK or 0) > 0
  if curved then
    for _, d in ipairs(draws) do
      Voxel3D.draw(d[1], d[2], d[3])
    end
  end
  local plain = not curved
  if Water.enabled() and Voxel3D.depthReadable() then
    local mirror, depth = Voxel3D.beginWater(cast)
    local w, h = Voxel3D.size()
    local ok = mirror and depth and Water.begin({
      reflect = mirror, depth = depth,
      vp = Voxel3D.vp, eye = Voxel3D.eye, curve = { Voxel3D.curveX or 0,
                                                    Voxel3D.curveZ or 0,
                                                    Voxel3D.curveK or 0 },
      screen = { w, h }, cell = Voxel3D.cell, fov = Voxel3D.fovY,
      skyEdge = Voxel3D.skyEdge, grid = VoxelGrid.enabled(),
      skyRay = Voxel3D.skyRayLive,
      lookFlat = Voxel3D.lookFlat, descent = Voxel3D.descent,
      maritime = options and options.maritime == true,
    })
    if ok then
      for _, d in ipairs(draws) do
        Water.draw(d[1], d[2], d[3])
      end
      Water.finish()
      plain = false
    end
    -- Unconditionally, and OUTSIDE the success branch: beginWater unbinds
    -- the shader and the depth mode BEFORE it can discover it cannot go on,
    -- so a frame that bails halfway through has to be put back together
    -- exactly like one that succeeded -- otherwise every pass after it runs
    -- with no shader and no depth test.
    Voxel3D.endWater()
  end
  -- the fallback flat draw -- unless the curve's prepass already put the
  -- same meshes down, in which case a bailed frame is already whole
  if plain then
    for _, d in ipairs(draws) do
      Voxel3D.draw(d[1], d[2], d[3])
    end
  end
end

-- A stamp of everything the sun pass depends on. Nothing in it moving
-- means the shadow map it produced last frame is still exactly right, and
-- redrawing the whole world from the sun would buy nothing -- which is
-- most of a dialog, a menu, or any moment standing still.
local sigBuf = {}
local function shadowSignature(terrain, nbMesh, posed, cx, cy, vw, vh,
                               policy, horizon)
  local n = 0
  local function put(v)
    n = n + 1
    sigBuf[n] = v
  end
  -- quarter-pixel camera granularity: the light frustum is snapped to
  -- whole texels anyway, each a third of a world pixel
  put(math.floor(cx * 4))
  put(math.floor(cy * 4))
  -- the view size and the camera PITCH are both what the light frustum is
  -- fitted to (a lower camera sees further north, so the box grows), so a
  -- zoom step, a window resize or a rung change invalidates the map even
  -- standing perfectly still
  put(vw); put(vh)
  put(math.floor((V.require("VoxelState").angle or 0) * 512))
  -- the sun itself: the cycle swings the shear as the clock runs, and a map
  -- lit from somewhere new must be redrawn from there too. Quantised by the
  -- rig's own step (DayNight.rigTime), so a running cycle redraws the map a
  -- few times a minute rather than every frame.
  put(math.floor(ShadowMap.KX * 128))
  put(math.floor(ShadowMap.KZ * 128))
  put(policy and policy.key or "legacy-world")
  put(FirstPerson.signature())
  put(tostring(terrain))
  for i = 1, #nbMesh do put(tostring(nbMesh[i])) end
  for _, rim in ipairs(horizon or {}) do
    if rim.castsShadow then
      -- Animated water changes UVs, not the solid fountain hull. Keep the
      -- caster on frame zero so an 8 FPS jet does not rebuild the complete
      -- world shadow map eight times per second.
      put(tostring(rim.animationMeshes and rim.animationMeshes[1]
                   or rim.mesh))
      put(rim.ox or 0); put(rim.oy or 0)
    end
  end
  for _, p in ipairs(posed) do
    put(p.sprite.def.image)
    put(p.px); put(p.py); put(p.gh); put(p.lift or 0)
    put(p.facing); put(p.phase); put(p.flip and 1 or 0)
  end
  for i = n + 1, #sigBuf do sigBuf[i] = nil end
  return table.concat(sigBuf, ",")
end

-- The sun pass: render the selected casters once from the light, so the main
-- pass can ask any fragment whether the sun reached it. The legacy policy
-- includes the complete terrain mesh. A companion may narrow this to signed
-- map-object quads (modelled buildings, trees and props) plus object cards
-- (flowers, authored figures and live actors), while ground, cliffs, water
-- and border geometry are discarded.
--
-- Runs BEFORE Voxel3D.beginScene, because canvases do not nest. Grass is
-- left out on purpose: thousands of tufts would cast a speckle no bigger
-- than the pixels it lands on, at the cost of the mesh being drawn twice.
local function castShadows(state, terrain, nbMesh, posed, cx, cy, vw, vh,
                           atlasFor, water, nbWater, policy, horizon)
  if not Shadows.enabled() then return end
  if not (policy and policy.enabled) then
    if type(ShadowMap.deactivate) == "function" then ShadowMap.deactivate() end
    return
  end
  -- An ambient-only weather exception can keep the procedural flyer shadow
  -- alive without authorising any map, object or actor caster. Also discard
  -- the last sunny depth map immediately so it cannot bleed into the rain.
  if policy.casters == "none" then
    if type(ShadowMap.deactivate) == "function" then ShadowMap.deactivate() end
    return
  end
  if not ShadowMap.available() then return end
  local sig = shadowSignature(terrain, nbMesh, posed, cx, cy, vw, vh,
                              policy, horizon)
  if not ShadowMap.stale(sig) then return end
  if not ShadowMap.begin(cx, cy, vw, vh) then return end
  if type(ShadowMap.objectOnly) == "function" then
    ShadowMap.objectOnly(policy.casters == "objects")
  end

  -- Object-only still submits the existing terrain bundle once: the sun
  -- shader discards every ordinary quad and keeps only ChunkMesher's signed
  -- building/tree/prop markers. This avoids a duplicate GPU mesh while
  -- preventing ground, cliffs, water and the map border from casting.
  ShadowMap.draw(terrain, atlasFor(state.map), nil)
  for i, nb in ipairs(state.neighbors or {}) do
    ShadowMap.draw(nbMesh[i], atlasFor(nb.map),
                   Mat4.translate(nb.ox, 0, nb.oy))
  end
  if policy.casters == "world" then
    -- The water surface is a receiver, but the legacy full-world pass also
    -- records it so its depth agrees with shoreline world geometry.
    ShadowMap.draw(water, atlasFor(state.map), nil)
    for i, nb in ipairs(state.neighbors or {}) do
      ShadowMap.draw(nbWater and nbWater[i], atlasFor(nb.map),
                     Mat4.translate(nb.ox, 0, nb.oy))
    end
  end
  -- Ground-standing editor models live in HorizonWall's retained decoration
  -- batches rather than ChunkMesher's terrain bundle. Their faces carry the
  -- same negative object marker as native buildings, so this one bounded loop
  -- supplies a real contact shadow in both world- and object-caster policies.
  for _, rim in ipairs(horizon or {}) do
    if rim.castsShadow then
      local caster = rim.animationMeshes and rim.animationMeshes[1] or rim.mesh
      ShadowMap.draw(caster, rim.texture,
                     Mat4.translate(rim.ox or 0, 0, rim.oy or 0))
    end
  end
  -- flower billboards live outside the terrain mesh (they draw after the
  -- characters, pulled -- see render), but the sun still sees them: a
  -- handful of cutouts per meadow, unlike the grass left out below.
  -- Every thin card from here down is SNUGGED toward the sun along its own
  -- ray (ShadowMap.snug) so its shadow keeps contact with its feet instead
  -- of starting a bias-width away.
  if policy.casters == "objects" then ShadowMap.sprites(true) end
  ShadowMap.draw(ChunkMesher.flowers(state.map), atlasFor(state.map),
                 ShadowMap.snug(nil))
  for _, nb in ipairs(state.neighbors or {}) do
    ShadowMap.draw(ChunkMesher.flowers(nb.map), atlasFor(nb.map),
                   ShadowMap.snug(Mat4.translate(nb.ox, 0, nb.oy)))
  end
  -- From here down it is the CAST, marked as such in the map (see
  -- ShadowMap.sprites) so water can decline them: everything the world casts
  -- still shades a lake, a silhouette of somebody standing beside it does
  -- not. Ground, roofs and the characters themselves take them as before.
  ShadowMap.sprites(true)
  -- authored figures cast too, for the same reason the flowers do: a
  -- handful of cards per map, and a person with no shadow reads as pasted on
  eachFigure(state.map, 0, 0, function(mesh, _, caster)
    ShadowMap.draw(mesh, atlasFor(state.map), ShadowMap.snug(caster))
  end)
  for _, nb in ipairs(state.neighbors or {}) do
    eachFigure(nb.map, nb.ox, nb.oy, function(mesh, _, caster)
      ShadowMap.draw(mesh, atlasFor(nb.map), ShadowMap.snug(caster))
    end)
  end
  for _, p in ipairs(posed) do
    local def = p.sprite.def
    -- viewFacing, exactly as the camera draw picks it (see viewFacing for
    -- why the two passes must agree): in first person the sun's card
    -- swaps frame as the eye circles, which costs a redraw the signature
    -- already charges for (FirstPerson.signature) and keeps a card from
    -- fringing against a mirror-flipped record of itself
    local frame, mirror = frameFor(def, viewFacing(p), p.phase, p.flip)
    local mesh = SpriteBillboards.shadowQuad(def, frame)
    if mesh then
      ShadowMap.draw(mesh, p.sprite:resolveImage(),
                     ShadowMap.snug(
                       Voxel3D.casterMatrix(p.px, p.py, p.gh + (p.lift or 0),
                                            mirror)))
    end
  end
  ShadowMap.sprites(false)

  ShadowMap.finish(sig)
end

-- A candidate may fail after beginScene has already rebound part of LOVE's
-- graphics state but before Voxel3D marks the scene active. Voxel3D itself is
-- part of the frozen P2 surface, so this narrow P1 seam restores the same
-- neutral state endScene establishes, plus scissor/blend/color that Sky.paint
-- can transiently own. Every call is best-effort and idempotent.
local function abortMobileSceneryGraphics()
  local g = love and love.graphics or nil
  if not g then return end
  if type(g.setShader) == "function" then pcall(g.setShader) end
  if type(g.setDepthMode) == "function" then pcall(g.setDepthMode) end
  if type(g.setMeshCullMode) == "function" then
    pcall(g.setMeshCullMode, "none")
  end
  if type(g.setScissor) == "function" then pcall(g.setScissor) end
  if type(g.setBlendMode) == "function" then
    pcall(g.setBlendMode, "alpha")
  end
  if type(g.setColor) == "function" then pcall(g.setColor, 1, 1, 1, 1) end
  if type(g.setCanvas) == "function" then pcall(g.setCanvas) end
end

local renderWorld

-- The transaction begins before the gate can enter probing state and covers
-- every rich-only semantic lookup, sky calculation, begin/draw/end operation.
-- M10 core errors and all desktop errors retain their historical propagation.
function VoxelScene.render(state, w, h, vw, vh, paletteFor)
  if not MOBILE_RUNTIME then
    return renderWorld(state, w, h, vw, vh, paletteFor)
  end
  local ok, canvasOrError = pcall(
    renderWorld, state, w, h, vw, vh, paletteFor)
  if ok then return canvasOrError end

  local map = state and state.map or nil
  local rich = map and type(MobileSceneryGate.allow) == "function"
               and MobileSceneryGate.allow(map) == true
  if not rich then error(canvasOrError, 0) end
  abortMobileSceneryGraphics()
  if type(MobileSceneryGate.fail) == "function" then
    MobileSceneryGate.fail(map, tostring(canvasOrError))
  end
  mobileDiagnostic("fallback", "mobile-scenery-transaction",
    tostring(canvasOrError), "m10-retained", {
      caller="VoxelScene.render", context="world",
      map=map and map.id or nil,
    })
  return type(MobileSceneryGate.lastSafeCanvas) == "function"
         and MobileSceneryGate.lastSafeCanvas(map) or nil
end

-- Render the world once into the active window-resolution scene canvas.
renderWorld = function(state, w, h, vw, vh, paletteFor)
  -- With nothing cached at all (the first frame of a fresh toggle),
  -- return nil: the engine keeps the 2D path for the frame and
  -- Voxel.ready holds the camera tween at flat, so the switch waits
  -- invisibly instead of freezing or tilting an empty stage.
  local terrain, nbMesh, water, nbWater, plan = VoxelScene.prefetch(state)
  -- `prefetch` marks the scene ready once the current terrain and a horizon
  -- closed around the currently drawable union exist. On semantic-scenery
  -- maps that union can begin with the current map alone; missing neighbours
  -- keep building behind its curtain. The full-ring fallback remains atomic.
  local Voxel = V.require("VoxelState")
  if not terrain or not Voxel.ready then
    mobileDiagnostic("pending", "gen1-VoxelScene.prefetch",
      "terrain-or-scene-not-ready", {
        caller="VoxelScene.prefetch", context="world",
        terrainReady=terrain ~= nil, sceneReady=Voxel.ready == true,
      })
    return nil
  end
  plan = plan or drawPlan(state, nbMesh, nbWater)
  local mobileSceneryProbe = false
  local mobileScenery = false
  if MOBILE_RUNTIME then
    if type(MobileSceneryGate.enterMap) == "function" then
      MobileSceneryGate.enterMap(state.map)
    end
    mobileScenery = type(MobileSceneryGate.allow) == "function"
                      and MobileSceneryGate.allow(state.map) == true
    if not mobileScenery
        and type(MobileSceneryGate.beginProbe) == "function" then
      mobileSceneryProbe = MobileSceneryGate.beginProbe(state.map) == true
      mobileScenery = mobileSceneryProbe
    end
  end
  local drawState, drawMesh, drawWater = plan.state, plan.meshes, plan.waters

  -- Resolve normal WALK before pose() advances any entity timer. KASC owns
  -- three registered walker resources, but there is still only one engine
  -- player and only one renderer is selected for this captured 3-D pose. If
  -- KASC is absent, loader-rejected or malformed, keep the live actor renderer
  -- and continue the completed Voxel canvas. Optional artwork must never turn
  -- a successful world draw into the E31 nil-return loop. Fly omits the player
  -- entirely; independent states keep pose()'s own renderer.
  local externalPlayerWalker = nil
  if state.player and not state.flyAnim then
    local resolved, route = VoxelScene.requireExternalKascWalker(
      state.player, state.player.sprite)
    local liveFallback = type(route) == "string"
      and route:find("live-actor-fallback:", 1, true) == 1
    if not resolved or liveFallback then
      mobileDiagnostic("fallback", "gen1-external-kasc-walker",
        route or "external-walker-unavailable", "inactive", {
          caller="ExternalKascWalker.resolve", context="world",
          map=state.map and state.map.id or nil,
          optionalArtwork=true,
        })
    end
    if resolved and not liveFallback and route ~= "independent-state" then
      externalPlayerWalker = resolved
    end
  end

  local cam = state.camera
  local cx, cy = cam.x + vw / 2, cam.y + vh / 2
  local renderVw, renderVh = vw, vh
  if MOBILE_RUNTIME
      and type(CanvasPresentation.mobileWorldView) == "function" then
    renderVw, renderVh = CanvasPresentation.mobileWorldView(w, h, vw, vh)
  end

  -- the hour's light, before anything is cast or drawn: point the shared
  -- rig at the clock (or at noon, indoors -- a cave at midnight is exactly
  -- as dark as a cave at noon) and set the tint the scene shader multiplies
  -- every surface by. A CANOPY map (Viridian Forest) is the case between:
  -- the rig stays at noon and its backdrop is closed by muted leaf colour,
  -- while the hour's tint still falls through -- night reaches the forest.
  -- Semantic sky/horizon discovery belongs to the desktop scene.  Mobile's
  -- bounded world-core pass intentionally starts with neutral lighting and
  -- adds no horizon, glass or weather dependency before the first canvas.
  local outdoor = (not MOBILE_RUNTIME or mobileScenery)
                  and HorizonWall.hasSky(state.map)
  DayNight.applyRig(outdoor)
  Voxel3D.tint = DayNight.tint(outdoor or DayNight.isCanopy(state.map))

  -- Resolve the effective sky weather before the sun pass. This includes the
  -- optional standalone weather owner, so a storm can never leave VASC's
  -- previous clear-frame shadow map active underneath it.
  local weatherMode = Weather.mode(state.map)
  local skyWeatherMode, nativeGround = weatherMode, true
  if type(Weather.skyState) == "function" then
    skyWeatherMode, nativeGround = Weather.skyState(state.map)
  elseif type(Weather.skyMode) == "function" then
    skyWeatherMode = Weather.skyMode(state.map)
  end
  WeatherTweak.observe(state.map, weatherMode, Weather.clock, outdoor)
  local groundWeather = WeatherTweak.groundMode(
    state.map, skyWeatherMode, nativeGround)
  local groundAmount = WeatherTweak.groundAmount(
    state.map, skyWeatherMode, nativeGround)
  local shadowPolicy = resolveShadowPolicy({
    map = state.map,
    mapId = state.map and (state.map.id
      or (state.map.def and state.map.def.id)) or nil,
    outdoor = outdoor,
    weather = skyWeatherMode,
    daytime = type(DayNight.tod) == "function" and DayNight.tod() or "DAY",
    clock = Sky.clock or 0,
    clouds = not (Sky.cloudSetting and Sky.cloudSetting:get() == "off"),
  })
  if MOBILE_RUNTIME then
    -- The phone bootstrap has no shadow map and must not replace it with a
    -- per-character decal pass while proving the first core world canvas.
    -- Desktop retains the complete policy and all authored shadows.
    shadowPolicy = {
      enabled = false, casters = "none", key = "mobile-world-core",
      cloudOpacity = 0, cloudProgress = 0, cloudSeed = 0,
      birdOpacity = 0, birdEnabled = false,
      birdProgress = 0, birdSeed = 0,
    }
  end
  if type(SkyEvents.requestShadowFlyer) == "function" then
    local native = shadowPolicy.birdEnabled
                   and type(SkyEvents.shadowState) == "function"
                   and SkyEvents.shadowState({ weather = skyWeatherMode })
                   or nil
    if native then
      -- A real ambient VASC flight already in the sky wins. This includes all
      -- four legendaries; the ground shadow mirrors its exact live phase.
      shadowPolicy.birdOpacity = native.opacity
      shadowPolicy.birdProgress = native.progress
      shadowPolicy.birdSeed = native.seed
      shadowPolicy.birdCount = native.count
      shadowPolicy.birdScale = native.scale
      shadowPolicy.birdDirection = native.direction
      shadowPolicy.birdSpecies = native.species
      shadowPolicy.birdLegendary = native.legendary
      shadowPolicy.birdPaired = false
      if native.weatherException
          and type(SkyEvents.requestShadowLegend) == "function" then
        SkyEvents.requestShadowLegend(native.species, true)
      else
        SkyEvents.requestShadowFlyer(nil, false)
      end
    else
      local paired = shadowPolicy.birdEnabled
                     and (shadowPolicy.birdOpacity or 0) > 0
      local plan = SkyEvents.requestShadowFlyer(shadowPolicy.birdSeed, paired)
      shadowPolicy.birdPaired = paired
      if paired and plan then
        shadowPolicy.birdCount = plan.count or 1
        shadowPolicy.birdScale = math.max(0.78, math.min(1.6,
          (plan.apparentHeightCells or 6) / 7))
        shadowPolicy.birdDirection = plan.occurrence % 2 == 0 and 1 or -1
        shadowPolicy.birdSpecies = plan.species
      end
    end
  end
  -- and the window glass: the tileset's own panes (found in its art --
  -- GlassMask), lit after dark. Outdoors only, like everything the clock
  -- touches, which also keeps any pane-shaped art in an interior tileset
  -- from picking up a glint.
  local GlassMask = not MOBILE_RUNTIME and V.require("GlassMask") or nil
  Voxel3D.glassMask = GlassMask and outdoor
                      and GlassMask.texture(state.map.tileset) or nil
  Voxel3D.glassNight = outdoor and DayNight.windowLight() or 0
  local g = VoxelScene.glintStep(glint, cx, cy)
  Voxel3D.glassPhase, Voxel3D.glassGlint = g.phase, g.amp

  -- One map has one effective palette and one terrain atlas for the whole
  -- render. Terrain, water, grass, flowers, figures, reflections and a stale
  -- shadow pass all ask through these closures, so resolving the display-mode
  -- palette (and its world.tod/map hooks) at every draw was pure repeated
  -- work. Separate ready tables matter because both colors and atlas may
  -- legitimately be nil in a compatibility path.
  local colorsByMap, colorsReady = {}, {}
  local atlasByMap, atlasReady = {}, {}
  local function effectiveColorsFor(map)
    if not colorsReady[map] then
      colorsReady[map] = true
      colorsByMap[map] = modeColors(paletteFor, map)
    end
    return colorsByMap[map]
  end
  local function atlasFor(map)
    if not atlasReady[map] then
      atlasReady[map] = true
      atlasByMap[map] = TerrainAtlas.forMap(map, effectiveColorsFor(map))
    end
    return atlasByMap[map]
  end

  -- Generate panorama textures/meshes before beginScene binds the world
  -- canvas. The former lazy call happened inside drawScene; its temporary
  -- Canvas could detach the active world target on the first frame, leaving
  -- no background or isolated black fragments until later frames recovered.
  local sceneryEnabled = (not MOBILE_RUNTIME or mobileScenery)
                         and HorizonWall.enabled()
  if not MOBILE_RUNTIME or mobileScenery then
    -- While P1 is merely preparing, disabling PanoramaBackdrop would reset
    -- its terminal-attempt latch and turn a failed upload into a retry loop.
    PanoramaBackdrop.setEnabled(sceneryEnabled)
  end
  local horizon
  if MOBILE_RUNTIME then
    -- Candidate paint consumes only the exact mesh receipt prepared by the
    -- update lane. Validate the borrowed handles against HorizonWall's passive
    -- cache receipt; invalidation restages P1 and presents the untouched safe
    -- canvas for this frame instead of drawing released GPU objects.
    horizon = {}
    if mobileScenery and sceneryEnabled then
      local status = type(HorizonWall.cacheStatus) == "function"
                     and HorizonWall.cacheStatus(drawState) or nil
      local valid = mobileSceneryHorizonMap == state.map
                    and mobileSceneryHorizon ~= nil
                    and (status == nil or status.ready == true)
      if not valid then
        mobileSceneryHorizon = nil
        if type(MobileSceneryGate.restage) == "function" then
          MobileSceneryGate.restage(state.map, "horizon-cache-invalidated")
        end
        return type(MobileSceneryGate.lastSafeCanvas) == "function"
               and MobileSceneryGate.lastSafeCanvas(state.map) or nil
      end
      horizon = mobileSceneryHorizon
    end
  else
    horizon = plan.horizonFallback and {} or HorizonWall.meshes(drawState)
  end
  local indoorCutaway = cutawayActive(state.map, Voxel.level)
  local panoramaAllowed = outdoor and sceneryEnabled
    and (type(HorizonWall.allowsFarBackdrop) ~= "function"
         or HorizonWall.allowsFarBackdrop(drawState))
  local panoramaReady = false
  if panoramaAllowed then
    if MOBILE_RUNTIME then
      -- The update-only stage owns first allocation on a phone.
      panoramaReady = type(PanoramaBackdrop.ready) == "function"
                      and PanoramaBackdrop.ready() == true
      if not panoramaReady then
        mobileSceneryHorizon = nil
        if type(MobileSceneryGate.restage) == "function" then
          MobileSceneryGate.restage(state.map, "panorama-cache-invalidated")
        end
        return type(MobileSceneryGate.lastSafeCanvas) == "function"
               and MobileSceneryGate.lastSafeCanvas(state.map) or nil
      end
    else
      panoramaReady = PanoramaBackdrop.prepare()
    end
  end

  -- sprite palettes only exist in the SGB modes; under RED++ the OBP bake
  -- inside sprite:resolveImage() already colors the sheet
  local function spriteColors(map)
    if PaletteFX.usesGbcPack() then return nil end
    return effectiveColorsFor(map)
  end

  local posed, me = posesOf(
    state, spriteColors, plan.maps, externalPlayerWalker)
  -- Complete owner-filtered frame demand, before shadows resolve any textures.
  -- An optional visual provider must never enumerate other building residents.
  if type(Voxel3D.preparePokemonFrame) == "function" then
    Voxel3D.preparePokemonFrame(state, posed)
  end

  -- Place the free-roam rig before either the shadow or eye pass. The scene
  -- centre follows the player during the blend so curve, depth and lighting
  -- stay centred on the camera actually drawing the frame.
  local fpRig, fpCx, fpCy = FirstPerson.frame(
    me, cx, cy, renderVw, renderVh)
  if fpRig then cx, cy = fpCx, fpCy end

  local shCx, shCy = FirstPerson.shadowCenter(cx, cy, renderVh)
  castShadows(drawState, terrain, drawMesh, posed, shCx, shCy,
              renderVw, renderVh,
              atlasFor, water, drawWater, shadowPolicy, horizon)

  -- Everything between beginScene and endScene, as one function: the flat
  -- path runs it once, a VR frame runs it once PER EYE -- same posed
  -- list, same shadow map, same glint, so the two eyes can never disagree
  -- about anything but their viewpoint.
  local function drawScene()

  local surfaceWeather = false
  if type(Voxel3D.weatherGround) == "function" then
    surfaceWeather = Voxel3D.weatherGround(true) == true
  end
  if panoramaReady then
    local painted = PanoramaBackdrop.drawAt(
      me and me.px or cx, 0, me and me.py or cy, {
        weather=groundWeather, amount=groundAmount, outdoor=outdoor,
        surfaces=surfaceWeather,
      })
    if MOBILE_RUNTIME and mobileScenery and painted ~= true then
      error("mobile-panorama-draw-failed", 0)
    end
  end

  local terrainDrawn = Voxel3D.draw(terrain, atlasFor(state.map), nil)
  if MOBILE_RUNTIME and mobileScenery and terrainDrawn == false then
    error("mobile-terrain-draw-failed", 0)
  end
  for i, nb in ipairs(drawState.neighbors or {}) do
    Voxel3D.draw(drawMesh[i], atlasFor(nb.map),
                 Mat4.translate(nb.ox, 0, nb.oy))
  end
  if type(Voxel3D.weatherGround) == "function" then
    Voxel3D.weatherGround(false)
  end
  -- A low-cost textured belt and curtain around the streamed map union.
  -- This closes the world edge for 1ST/3RD without extending fully carved
  -- tree hulls to the far plane (which is prohibitively expensive on iPhone).
  Voxel3D.glass(false)
  for _, rim in ipairs(horizon) do
    if rim.kind ~= "water"
       and cutawayRimVisible(rim, indoorCutaway) then
      -- The cold Route 8 seam proxy samples the current Route 8 atlas instead
      -- of retaining a duplicate $39 texture.  All ordinary horizon parts
      -- keep their baked texture; the proxy is absent as soon as Lavender's
      -- real body joins the draw union.
      local rimTexture = rim.textureMap and atlasFor(rim.textureMap)
                         or rim.texture
      if indoorCutaway and rim.kind == "wall" then
        if type(InteriorCutaway.wallPlane) == "function" then
          setCutaway(InteriorCutaway.wallPlane(
            Voxel3D.eye, Voxel3D.focus))
        else
          setCutaway()
        end
      else
        setCutaway()
      end
      if HorizonWall.architecturalRoom(state.map) then
        ArenaScenery.draw(Voxel3D, rim, rimTexture,
          Mat4.translate(rim.ox, 0, rim.oy), {
            outdoor=false, surfaces=false,
            prismLight=ArenaScenery.prismLight(DayNight,skyWeatherMode),
            prismClock=DayNight,
          })
      else
      Voxel3D.draw(rim.mesh, rimTexture,
                   Mat4.translate(rim.ox, 0, rim.oy))
      end
    end
  end
  setCutaway()
  Voxel3D.glass(true)

  -- Without a shadow map (headless, or a driver that could not make the
  -- canvas) the old flat decals stand in: ground-only, characters only,
  -- but better than a world with nothing under anybody. They go down
  -- first, as decals the characters then stand over -- depth-tested
  -- against the terrain just drawn (a shadow behind a building stays
  -- hidden) but never depth-writing, so the grass pass at the end of the
  -- frame still wins its feet-overdraw fights.
  if shadowPolicy.enabled and shadowPolicy.casters ~= "none"
      and Shadows.enabled()
      and not Voxel3D.shadowsActive() then
    Voxel3D.beginShadows()
    for _, p in ipairs(posed) do
      drawShadow(p.sprite, p.px, p.py, viewFacing(p), p.phase, p.flip, p.gh,
                 p.lift)
    end
    Voxel3D.endShadows()
  end

  -- and the water over the top of it, reflecting everything just drawn plus
  -- the sky the frame opened with (see drawWater).
  --
  -- After the fallback decals deliberately: those are the stand-in drop
  -- shadows for a frame with no shadow map, they write no depth, and a
  -- lake would otherwise wear one as a black smear. Water covers them,
  -- which is the same answer the shadow map's own pass gives (see
  -- ShadowMap.sprites) -- people do not shadow water either way.
  local waterDraws = {}
  local function maritime(map)
    return type(Water.maritime) == "function" and Water.maritime(map) == true
  end
  local maritimeWater = maritime(state.map)
  if water then
    waterDraws[#waterDraws + 1] = { water, atlasFor(state.map), nil }
  end
  for i, nb in ipairs(drawState.neighbors or {}) do
    maritimeWater = maritimeWater or maritime(nb.map)
    if drawWater and drawWater[i] then
      waterDraws[#waterDraws + 1] = { drawWater[i], atlasFor(nb.map),
                                      Mat4.translate(nb.ox, 0, nb.oy) }
    end
  end
  -- Directional horizon water (currently Cinnabar's whole free southern
  -- edge) belongs in the same reflective/fallback pass as native map water.
  -- Drawing it with the opaque panorama meshes would make a static blue mat
  -- meet animated ocean at a visible seam.
  for _, rim in ipairs(horizon) do
    if rim.kind == "water" then
      waterDraws[#waterDraws + 1] = {
        rim.mesh, rim.texture, Mat4.translate(rim.ox, 0, rim.oy),
      }
    end
  end
  -- the cast goes into the reflection copy only -- see drawWater for why it
  -- cannot be composited yet and why it is drawn through the same function
  -- the real pass below uses
  if #waterDraws > 0 then
    VoxelScene.drawWater(waterDraws, function()
      drawCast(drawState, posed, atlasFor)
    end, { maritime = maritimeWater })
  end


  -- Sprite sheets from here to the figure pass: their texture coordinates
  -- mean nothing to the tileset-shaped glass mask, so the glass is off or
  -- the panes' atlas positions stripe the cast with lamplight at night
  Voxel3D.glass(false)

  -- The player's silhouette goes down BEFORE the characters, so the only
  -- thing it can meet in the depth buffer is the WORLD -- terrain, buildings,
  -- trees. Drawn after the solid pass it would meet the player's own card
  -- instead, and every fragment of a figure sits behind the one that just
  -- wrote it, so the silhouette would paint over the player at all times.
  -- Every character then draws on top as usual, which leaves the silhouette
  -- showing in exactly one situation: where the world hides them.
  --
  -- Not in first person: the card it silhouettes is the one the camera is
  -- standing inside, and "the world is in front of the player" is every
  -- wall the player faces.
  if me and not FirstPerson.hidePlayer() then
    Voxel3D.beginGhost()
    drawGhost(me)
    Voxel3D.endGhost()
  end

  -- Characters carry no wireframe out here, whatever the V-GRID row says.
  -- The seams are what makes the WORLD read as built out of voxels, and
  -- the people walking around in it are the one thing that should read as
  -- drawn instead -- a grid over a 16x16 sprite lands a line every couple
  -- of display pixels and turns a face into a mesh. (The battle pass makes
  -- the opposite call for its own combatants, deliberately: that is a
  -- staged shot rather than the world being walked around in -- see
  -- BattleBillboard.)
  --
  -- Characters, normally depth-tested: the camera-ward pull inside
  -- drawEntity resolves the lean-over-the-wall-in-front case, and a
  -- character genuinely behind a building is far deeper and loses the
  -- test, so buildings and trees really occlude.
  drawCast(drawState, posed, atlasFor)
  -- tall grass last, pulled camera-ward exactly as far as the characters
  -- were (same per-vertex shader bias, so grass never drifts either):
  -- relative depth between a walker and the tuft row south of their feet
  -- is preserved, so the row still overdraws feet -- the 3D version of
  -- the GB's grass-over-feet trick -- while grass keeps losing to the
  -- buildings it genuinely stands behind (far deeper than the pull).
  -- the same angle the cards leaned by (leanAngle honours VR's override),
  -- so the tuft rows keep exactly the characters' own depth handicap
  local lean = math.max(leanAngle(), 0.05)
  local pull = VoxelScene.pull(lean)
  if type(Voxel3D.weatherGrass) == "function" then
    Voxel3D.weatherGrass(true)
  end
  Voxel3D.draw(ChunkMesher.grass(state.map), atlasFor(state.map), nil, pull)
  for _, nb in ipairs(drawState.neighbors or {}) do
    Voxel3D.draw(ChunkMesher.grass(nb.map), atlasFor(nb.map),
                 Mat4.translate(nb.ox, 0, nb.oy), pull)
  end
  if type(Voxel3D.weatherGrass) == "function" then
    Voxel3D.weatherGrass(false)
  end
  -- flower billboards: pulled like the characters and the grass, MINUS
  -- the depth of 8 world pixels along the view (8 sin a -- the camera
  -- looks along (0, -cos a, -sin a), so that is exactly one tile row of
  -- northness). A pure depth handicap with zero screen drift: every
  -- flower is judged as if it stood one tile row further north. The
  -- character card's feet plane sits at its cell's MIDDLE (py + 8), so
  -- a flower on the walker's own cell (z +4 or +12 across the cell)
  -- lands behind the card and the player obscures the patch they stand
  -- ON, while the nearest flower of the cell south (+20) stays in front
  -- and keeps overdrawing their feet.
  local fpull = math.max(0, pull - 8 * math.sin(lean))
  -- flowers are snugged casters too, so they read their own shadowing
  -- through the same snugged transform the sun stored them with
  Voxel3D.draw(ChunkMesher.flowers(state.map), atlasFor(state.map), nil,
               fpull, ShadowMap.snug(nil))
  for _, nb in ipairs(drawState.neighbors or {}) do
    Voxel3D.draw(ChunkMesher.flowers(nb.map), atlasFor(nb.map),
                 Mat4.translate(nb.ox, 0, nb.oy), fpull,
                 ShadowMap.snug(Mat4.translate(nb.ox, 0, nb.oy)))
  end

  end   -- drawScene

  if mobileScenery and mobileSceneryCanvasMap ~= state.map then
    mobileSceneryCanvasMap, mobileSceneryNextSlot =
      state.map, "mobile-scenery"
  end
  -- Ping-pong between M10's existing world slot and one P1 slot. The frame
  -- being painted is therefore never the object held as lastSafeCanvas.
  local sceneSlot = mobileScenery and mobileSceneryNextSlot or nil
  local sceneArgs = {
    weather = skyWeatherMode,
    mapId = state.map and state.map.id or nil,
    groundWeather = groundWeather,
    groundAmount = groundAmount,
    shadowPolicy = shadowPolicy,
  }
  local sceneSky = skyFor(state.map, skyWeatherMode)
  local beginOK, began
  if mobileScenery then
    beginOK, began = pcall(Voxel3D.beginScene,
      w, h, cx, cy, renderVw, renderVh,
      sceneSky, sceneSlot, sceneArgs)
  else
    beginOK = true
    began = Voxel3D.beginScene(
      w, h, cx, cy, renderVw, renderVh,
      sceneSky, sceneSlot, sceneArgs)
  end
  if not beginOK or not began then
    if mobileScenery then abortMobileSceneryGraphics() end
    mobileDiagnostic("fallback", "gen1-VoxelScene.beginScene",
      beginOK and "world-canvas-depth-attach-failed" or tostring(began),
      "failed", {
        caller="Voxel3D.beginScene", context="world", width=w, height=h,
      })
    if mobileScenery and type(MobileSceneryGate.fail) == "function" then
      MobileSceneryGate.fail(state.map,
        beginOK and "world-canvas-depth-attach-failed" or tostring(began))
    elseif mobileSceneryProbe
        and type(MobileSceneryGate.finishProbe) == "function" then
      MobileSceneryGate.finishProbe(state.map, nil, tostring(began))
    end
    if mobileScenery
        and type(MobileSceneryGate.lastSafeCanvas) == "function" then
      return MobileSceneryGate.lastSafeCanvas(state.map)
    end
    return nil
  end
  local drawOK, drawError = true, nil
  if mobileScenery then
    drawOK, drawError = pcall(drawScene)
  else
    drawScene()
  end
  if not drawOK then
    -- Release the candidate binding, but never publish its partial canvas.
    pcall(Voxel3D.endScene)
    abortMobileSceneryGraphics()
    if type(MobileSceneryGate.fail) == "function" then
      MobileSceneryGate.fail(state.map, tostring(drawError))
    elseif mobileSceneryProbe
        and type(MobileSceneryGate.finishProbe) == "function" then
      MobileSceneryGate.finishProbe(state.map, nil, tostring(drawError))
    end
    mobileDiagnostic("fallback", "mobile-scenery-draw",
      tostring(drawError), "m10-retained", {
        caller="VoxelScene.render", context="world",
        map=state.map and state.map.id or nil,
      })
    if type(MobileSceneryGate.lastSafeCanvas) == "function" then
      return MobileSceneryGate.lastSafeCanvas(state.map)
    end
    return nil
  end
  if not MOBILE_RUNTIME then
    local WallDecals = V.require("WallDecals")
    WallDecals.drawState(drawState)
  end
  local endOK, out = true, nil
  if mobileScenery then
    endOK, out = pcall(Voxel3D.endScene)
  else
    out = Voxel3D.endScene()
  end
  if not endOK or not out then
    if mobileScenery then
      if not endOK then pcall(Voxel3D.endScene) end
      abortMobileSceneryGraphics()
    end
    mobileDiagnostic("fail", "D08", "gen1-world-scene-output",
      endOK and "Voxel3D.endScene-returned-nil" or tostring(out), {
        caller="Voxel3D.endScene", context="world", width=w, height=h,
      })
    if mobileScenery and type(MobileSceneryGate.fail) == "function" then
      MobileSceneryGate.fail(state.map,
        endOK and "Voxel3D.endScene-returned-nil" or tostring(out))
    elseif mobileSceneryProbe
        and type(MobileSceneryGate.finishProbe) == "function" then
      MobileSceneryGate.finishProbe(state.map, nil, tostring(out))
    end
    if mobileScenery
        and type(MobileSceneryGate.lastSafeCanvas) == "function" then
      return MobileSceneryGate.lastSafeCanvas(state.map)
    end
    return nil
  end
  mobileDiagnostic("checkpoint", "gen1-world-scene-canvas-ready", {
    caller="VoxelScene.render", context="world", width=w, height=h,
  })
  -- Mobile validates the completed core canvas before decorating it, but the
  -- canonical weather painters draw in-place and do not allocate a second
  -- full-frame target.  Apply them before publishing the safe receipt: once
  -- the voxel canvas replaces the 2-D fallback there is no engine weather
  -- layer underneath it (the real-device symptom was weather music with a
  -- permanently clear picture).
  if MOBILE_RUNTIME then
    out = Weather.apply(out, w, h, state.map, Voxel3D.cell, weatherMode)
    out = WeatherTweak.apply(
      out, w, h, state.map, Voxel3D.cell, weatherMode, false)
    -- Only an actual completed canvas opens direct-map streaming.  Merely
    -- having BODY/atlas in the cache is insufficient because update and render
    -- both call prefetch in the first publication frame.
    mobileCoreTrace.presented = true
    traceMobileCore(state.map, "canvas-presented", {
      caller="VoxelScene.render", context="world",
    })
    if mobileScenery then
      mobileSceneryNextSlot = sceneSlot == "mobile-scenery"
        and "world" or "mobile-scenery"
    else
      -- A restage presents the M10 core in the ordinary world slot while P1
      -- resources are rebuilt.  Re-arm the candidate slot at that exact
      -- publication boundary so the next probe can never alias/overwrite the
      -- newly retained safe world canvas.
      mobileSceneryCanvasMap, mobileSceneryNextSlot =
        state.map, "mobile-scenery"
    end
    if mobileSceneryProbe
        and type(MobileSceneryGate.finishProbe) == "function" then
      MobileSceneryGate.finishProbe(state.map, out)
    elseif type(MobileSceneryGate.noteSafeCanvas) == "function" then
      MobileSceneryGate.noteSafeCanvas(state.map, out)
    end
    return out
  end
  out = Weather.apply(out, w, h, state.map, Voxel3D.cell, weatherMode)
  return WeatherTweak.apply(
    out, w, h, state.map, Voxel3D.cell, weatherMode, false)
end

return VoxelScene
