-- Overworld battles: one frame of the arena, as geometry.
--
-- The same world the free-roam mode draws, from a placed camera instead of
-- the orbit, at the WINDOW's own pixel resolution -- not the GB's. The
-- backdrop reaches the screen through Renderer's worldOverride, the seam a
-- render pipeline's finished world image already composites through, which
-- is drawn one canvas pixel to one screen pixel; the 160x144 battle screen
-- then blits over it in the classic letterbox. So the world is as crisp as
-- the free-roam diorama and the pics, HUDs and text box stay exactly the
-- chunky GB art they are.
--
-- Rendering the whole window rather than just the letterbox means the
-- framing has to be split in two. The RIG frames the GB's 160x144 (see
-- BattleCam, which is solved against coordinates in that frame); this
-- module widens the lens by exactly the ratio the window bears to the
-- letterbox, so the letterbox sub-rectangle of what gets rendered is
-- bit-for-bit the framing the rig asked for, and everything outside it is
-- extra picture. That is what lets the two mons be PINNED: their cells
-- project to the same GB coordinates at any window size or zoom.
--
-- Characters are deliberately absent. The overworld cast is culled for the
-- length of the battle (see OverworldBattle), so this pass has terrain,
-- grass and flowers and nothing that walks -- the arena is empty, which is
-- what makes it an arena.
--
-- Everything expensive is shared with the free-roam mode rather than
-- duplicated: the same chunk meshes out of ChunkMesher, the same palette
-- atlas out of TerrainAtlas, the same sun out of ShadowMap. A battle on a
-- map already meshed for walking around costs the frame it draws and
-- nothing else.

-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local Mat4 = V.require("Mat4")
local Voxel3D = V.require("Voxel3D")
local ShadowMap = V.require("ShadowMap")
local Shadows = V.require("Shadows")
local ChunkMesher = V.require("ChunkMesher")
local TerrainAtlas = V.require("TerrainAtlas")
local VoxelScene = V.require("VoxelScene")
local BattleCam = V.require("BattleCam")
local BattleBillboard = V.require("BattleBillboard")
local BattlePics = V.require("BattlePics")
local VoxelGrid = V.require("VoxelGrid")
local DayNight = V.require("DayNight")
local AntiAlias = V.require("AntiAlias")
local Weather = V.require("Weather")
local HorizonWall = V.require("HorizonWall")
local PanoramaBackdrop = V.require("PanoramaBackdrop")
local okWeatherTweak, WeatherTweak = pcall(V.require, "WeatherTweak")
if not okWeatherTweak or type(WeatherTweak) ~= "table"
    or type(WeatherTweak.observe) ~= "function"
    or type(WeatherTweak.groundMode) ~= "function"
    or type(WeatherTweak.groundAmount) ~= "function" then
  WeatherTweak = {
    observe = function() end,
    groundMode = function(_, mode, native)
      return native == false and "clear" or mode
    end,
    groundAmount = function(_, _, native)
      return native == false and 0 or 1
    end,
  }
end
local PaletteFX = require("src.render.PaletteFX")

local BattleScene = {}

-- BattleScene is unit-tested with deliberately tiny V namespaces.  Resolve
-- the optional controller lazily so those geometry tests retain their neutral
-- baseline, while the real VASC runtime always supplies BattleLayout.
local layoutModule, layoutChecked
local function battleLayout()
  if layoutChecked then return layoutModule end
  layoutChecked = true
  local ok, value = pcall(V.require, "BattleLayout")
  if ok and type(value) == "table" then layoutModule = value end
  return layoutModule
end

local function battleLayoutContext(arena, map)
  local controller = battleLayout()
  if controller and type(controller.stageContext) == "function" then
    local ok, value = pcall(controller.stageContext, arena, map)
    if ok and type(value) == "table" then return value end
  end
  local host = map or type(arena) == "table" and arena.map or nil
  local declared = type(arena) == "table" and arena.presentationMode or nil
  local mode = (declared == "MAP" or declared == "ARENA"
      or declared == "DISCS") and declared
    or type(arena) == "table" and arena.arenaStyle and "ARENA"
    or type(arena) == "table" and arena.discs and "DISCS" or "MAP"
  return {mapID=host and tostring(host.id or host) or nil,
          stageID=host and tostring(host.id or host) or nil,
          mode=mode}
end

-- The GB frame the battle screen is drawn in, and the frame BattleCam's rig
-- is solved against.
BattleScene.GB_W = 160
BattleScene.GB_H = 144

-- A map cell in world pixels: the overworld square a mon stands on, which is
-- both what the arena is measured in and what a mon is sized to.
BattleScene.CELL = 16

-- How far into black a shadow goes in the arena, against the free-roam
-- mode's own lighter setting.
--
-- Darker on purpose, and only here. Walking around, a shadow is scenery and
-- wants to stay out of the way of reading the map. In a battle it is doing
-- one specific job: the two mons are flat cards, and the ONLY thing telling
-- the eye they are standing on that floor rather than hanging in front of it
-- is the shadow they put on it. A faint one leaves them floating.
BattleScene.SHADOW_ALPHA = 0.68

-- Which rung of the sky ramp an indoor void is painted with. A room has no
-- sky, but it does have somewhere the geometry stops, and leaving that
-- transparent would show the letterbox clear through the gaps.
local INDOOR_SHADE = 4

-- ------- where the GB frame sits inside the window
--
-- Renderer blits worldOverride one canvas pixel to one screen pixel and then
-- blits the 160x144 UI canvas into a centred, integer-scaled letterbox. So
-- these have to agree with Renderer:endFrame exactly, or the pins land off
-- the mons by however much they disagree.
function BattleScene.letterbox()
  local Renderer = require("src.render.Renderer")
  local pw, ph = BattleScene.pixelSize()
  local s = Renderer:fitScale()
  local uw, uh
  if type(Renderer.uiSize) == "function" then uw, uh = Renderer:uiSize() end
  if uw and uh and (uw ~= BattleScene.GB_W or uh ~= BattleScene.GB_H) then
    -- A pushed full-size party/bag screen temporarily changes Renderer.uiSize.
    -- Its fit must not resize the battle projection/HUD underneath it: on
    -- return during send-out, that invented viewport change can deadlock the
    -- atomic owner-card latch and retire an otherwise healthy 3D battle.
    s = math.max(1, math.floor(math.min(
      pw / BattleScene.GB_W, ph / BattleScene.GB_H)))
    local ok, faithful = pcall(require, "src.core.FaithfulRes")
    local cap = ok and faithful and type(faithful.scaleCap) == "function"
      and faithful.scaleCap() or nil
    if cap and cap < s then s = cap end
  end
  return math.floor((pw - BattleScene.GB_W * s) / 2),
         math.floor((ph - BattleScene.GB_H * s) / 2),
         s, pw, ph
end

-- The window in FRAMEBUFFER pixels, which is what the override blit works
-- in. love.graphics.getDimensions is in LOVE units and differs from this by
-- the display density on mobile.
function BattleScene.pixelSize()
  if love.graphics.getPixelDimensions then
    local pw, ph = love.graphics.getPixelDimensions()
    if pw and ph and pw > 0 and ph > 0 then return pw, ph end
  end
  return love.graphics.getDimensions()
end

-- Widen the rig's vertical field of view from the GB frame to the whole
-- window, so the letterbox rows show exactly what the rig framed.
--
-- The horizontal falls out of it: at aspect pw/ph the window's half-width is
-- tan(fov/2) * pw/ph, and the letterbox is 160*s of those pw pixels, which
-- works back out to the GB frame's own 160/144. So one scale on the vertical
-- pins both axes.
function BattleScene.letterboxFov(fovGB, ph, s)
  local span = BattleScene.GB_H * s
  if span <= 0 then return fovGB end
  return 2 * math.atan(math.tan(fovGB / 2) * ph / span)
end

-- ------- palette
--
-- The world palette a map draws under, in the shape VoxelScene's colour
-- helpers take. Rebuilt per frame from the overworld state, which is where
-- the engine's own pipeline context gets it too (OverworldController's
-- ctx.paletteFor).
local function paletteFor(state, home)
  return function(map)
    return PaletteFX.pal(require("src.core.Game").data,
                         state:paletteNameFor(map or home))
  end
end

-- ------- the map the fight is staged on
--
-- Normally the one the player is standing on. An authored arena may name
-- another floor of the same cave or building (see BattleArena), and then the
-- scene is THAT map: its terrain, its palette, its sky. Nothing else in the
-- battle changes -- the fight, the party, the player's own position are all
-- exactly where they were.
--
-- A foreign floor is meshed alone, with no connected neighbours: connections
-- are the player's neighbourhood, and the map the camera has gone to visit is
-- not standing in it. Both maps are kept live so neither the arena's mesh nor
-- the one waiting to be walked back onto is evicted mid-battle.
local function prefetchArena(state, host)
  if host == state.map then
    local terrain, nbMesh, water, nbWater, plan = VoxelScene.prefetch(state)
    if not (terrain and plan and plan.state) then return nil end

    -- VoxelScene's fifth result is the hole-free subset of connected maps:
    -- every included body already exists, and HorizonWall closes each seam
    -- whose neighbour is still cold. Battles used to ignore that result and
    -- draw the sparse first-four-value tuple directly. The wider 2X/3X lens
    -- made the missing bodies -- and the body-only current map's bare edge --
    -- plainly visible.
    local horizon, horizonReady
    if plan.horizonFallback then
      -- VoxelScene has already gated this plan on the masked FULL current
      -- ring and every connected body. It deliberately carries no semantic
      -- horizon after that exact state build failed.
      horizon, horizonReady = {}, true
    else
      horizon, horizonReady = HorizonWall.meshes(plan.state)
    end
    if not horizonReady then return nil end

    -- With semantic scenery disabled the current FULL mesh is closed by its
    -- masked border ring instead. Those masks assume every connected body is
    -- present, so preserve VoxelScene's atomic rule rather than accepting a
    -- compact partial plan in that mode.
    -- Mobile's bounded path proves an atomic masked FULL plus every *direct*
    -- connection and stamps that exact receipt. Two-hop survey maps are not
    -- connection masks and must not make a complete phone arena return nil.
    -- The initial current-only BODY has no receipt and remains rejected here,
    -- so a battle never opens on an unclosed bootstrap edge.
    if not plan.mobileDirectUnion
       and (plan.horizonFallback or not HorizonWall.preferBody(host))
       and #(plan.state.neighbors or {}) ~= #(state.neighbors or {}) then
      return nil
    end
    return {
      terrain = terrain, water = water,
      neighbors = plan.state.neighbors or {},
      meshes = plan.meshes or nbMesh or {},
      waters = plan.waters or nbWater or {},
      horizon = horizon or {},
    }
  end

  local live = { [host.id] = true, [state.map.id] = true }
  for _, nb in ipairs(state.neighbors or {}) do live[nb.map.id] = true end
  ChunkMesher.setLive(live)
  TerrainAtlas.setLive(live)
  -- A foreign authored arena has no connected-map state from which to build a
  -- semantic union. Wait for its closed FULL ring; drawing the quicker BODY
  -- fallback here leaves a naked edge, especially under the 3X battle lens.
  ChunkMesher.request(host, false, nil, true)
  local terrain, water = ChunkMesher.pair(host, false)
  if not terrain then return nil end
  return {
    terrain = terrain, water = water,
    neighbors = {}, meshes = {}, waters = {}, horizon = {},
  }
end

BattleScene._prefetchArena = prefetchArena -- named for the focused suite

-- Queue the arena before the transition starts drawing. BattleScene.render
-- also calls the same path every frame, but the first covered update pumps
-- before that first render. Preparing from OverworldBattle.begin lets that
-- otherwise-unused slice work on the destination immediately.
function BattleScene.prepare(state, arena)
  if not (state and state.map and arena) then return false end
  if arena.discs then return true end
  prefetchArena(state, arena.map or state.map)
  return true
end

-- ------- the sun
--
-- Only has to be drawn once per battle: the arena does not move, and neither
-- does the light. So the signature is the map, the arena and the meshes --
-- not the camera, which is the one thing that IS moving and the one thing
-- the sun does not care about.
-- ------- the two mons, hung on their cells
--
-- The billboard texture is the battle screen's own 160x144 pics layer with
-- one side rendered into it (see OverworldBattle.sideTexture), so the quad is
-- that whole frame stood up on the map -- which is what carries every pic
-- effect the engine applies without any of them being reimplemented here.
--
-- Its size follows from one number: a full 7x7-tile mon covers one overworld
-- square, so a canvas pixel is FULL_W / FULL_PIC world pixels and the card is
-- the canvas at that scale. Its placement follows from the anchor the
-- texture reports -- the column the pic was centred on and the row its feet
-- were put on -- which is translated onto the cell before the card is stood
-- up, so a mon of any size in any pose has its feet on the ground.
-- `mirror` flips the card about its own anchor column.  The value is resolved
-- from an explicit view/flip receipt below: bundled fronts intrinsically face
-- left, while certified full-body backs intrinsically face right.  This keeps
-- editor preview, native test battle and runtime on the same contract and,
-- crucially, lets a rejected Back -> HD Front fallback change direction too.
-- A companion may return a high-DPI canvas while retaining the logical
-- Gen-1 anchor (80,96).  Never assume that such a card is still 160x144:
-- doing so maps only its upper-left quarter onto the billboard and makes the
-- visible monster half-sized.  Unknown/malformed surfaces retain the native
-- dimensions so an unrelated provider still fails neutral.
function BattleScene.textureDimensions(tex)
  local canvas = tex and tex.canvas
  if canvas and type(canvas.getDimensions) == "function" then
    local ok, w, h = pcall(canvas.getDimensions, canvas)
    if ok and type(w) == "number" and type(h) == "number"
        and w == w and h == h and w > 0 and h > 0
        and w < math.huge and h < math.huge then
      return w, h
    end
  end
  return BattleScene.GB_W, BattleScene.GB_H
end

-- Visible bounds are meaningful only with a content identity.  The engine
-- reuses one canvas per side, so caching by that canvas alone would make the
-- next species inherit the previous species' silhouette.  KASC Megas provide
-- their source path; VASC's ordinary path supplies the actual sprite object.
--
-- An animated companion form can provide a different source path on every
-- authored frame.  Those paths are content identities, not actor ownership:
-- feeding their independent alpha boxes straight into density, camera fit and
-- HUD safety made all three targets cycle with the animation.  Learn one
-- conservative envelope per exact VASC deployment/model instead.  The weak
-- owner key releases naturally with the mon, while `vascRenderModelKey`
-- separates form/view changes on a surviving object.  Grow/shrink canvases
-- remain transient and never teach this deployed envelope.
local companionInkEnvelopes = setmetatable({}, { __mode="k" })

local function companionInkOwner(tex)
  if not (tex and (tex.kantoAscendantMegaSupersampled == true
      or tex.kantoAscendantGorochuSupersampled == true)) then return nil end
  local owner = tex.vascRenderMon or tex.vascRenderBattler
                or tex.vascRenderTextureToken
  local modelKey = tex.vascRenderModelKey
  if (type(owner) ~= "table" and type(owner) ~= "userdata")
      or type(modelKey) ~= "string" or modelKey == "" then return nil end
  return owner, modelKey
end

function BattleScene.textureInkBounds(tex)
  if not (tex and tex.canvas
          and type(BattlePics.inkBounds) == "function") then return nil end
  local identity = tex.kantoAscendantMegaSource or tex.inkIdentity
  local transient = tex.inkTransient == true
  local x0, y0, x1, y1
  if identity ~= nil then
    x0, y0, x1, y1 = BattlePics.inkBounds(
      tex.canvas, identity, transient)
  end
  if transient then return x0, y0, x1, y1 end

  local owner, modelKey = companionInkOwner(tex)
  if not owner then return x0, y0, x1, y1 end
  local models = companionInkEnvelopes[owner]
  if not models then
    models = {}
    companionInkEnvelopes[owner] = models
  end
  local envelope = models[modelKey]
  local valid = type(x0) == "number" and type(y0) == "number"
    and type(x1) == "number" and type(y1) == "number"
    and x1 >= x0 and y1 >= y0
  if valid then
    if envelope then
      envelope[1] = math.min(envelope[1], x0)
      envelope[2] = math.min(envelope[2], y0)
      envelope[3] = math.max(envelope[3], x1)
      envelope[4] = math.max(envelope[4], y1)
    else
      envelope = { x0, y0, x1, y1 }
      models[modelKey] = envelope
    end
  end
  if not envelope then return nil end
  return envelope[1], envelope[2], envelope[3], envelope[4]
end

-- A trainer can be mirrored like a regular player card while still being
-- human-scale art.  Keep that presentation fact separate from `trainer`,
-- whose historical meaning also controls the player-card mirror.
function BattleScene.isTrainerTexture(tex)
  return tex and (tex.trainer == true or tex.trainerArt == true
                  or tex.ascendantHighResTrainer == true) or false
end

-- Concrete horizontal orientation shared with the VASC Battlemap Editor.
-- A user/profile flip is absolute and therefore wins.  Otherwise fronts face
-- the opponent by mirroring only the player card; genuine full-body backs do
-- the inverse.  Unknown legacy cards retain the historical safe default.
-- Capability is never inferred from dimensions: a 64px image can be either a
-- reviewed full-body trainer back or a cropped Game Boy battle sprite.
function BattleScene.textureFlipX(side, tex)
  tex = type(tex) == "table" and tex or {}
  if type(tex.flipX) == "boolean" then return tex.flipX end
  if type(tex.vascFlipX) == "boolean" then return tex.vascFlipX end

  local receipt = type(tex.vascEmbeddedTrainer) == "table"
    and tex.vascEmbeddedTrainer or nil
  local view = tex.vascSpriteView or tex.ascendantSpriteView
    or tex.battleSpriteView or (receipt and receipt.view)
  if view == "full_back" then view = "back" end
  if view == "back" then return side == "enemy" end
  if view == "front" then return side == "player" end

  if tex.vascFullBodyBack == true or tex.ascendantFullBodyBack == true then
    return side == "enemy"
  end
  -- `trainer=true` is the engine's native player-back marker, but enemy
  -- trainer fronts carry it too.  Preserve that distinction by side.
  if side == "player" and tex.trainer == true then return false end
  return side == "player"
end

-- KASC's reviewed HD standee is a 2x raster of the logical 160x144 battle
-- card.  Its ax/ay fields deliberately stay in logical coordinates; the
-- raster is denser, not physically twice as large.  Recognise only that
-- explicit companion receipt, and fail neutral for every unknown provider.
function BattleScene.texturePixelScale(tex)
  if not (tex and tex.ascendantHighResTrainer == true) then return 1 end
  local cw, ch = BattleScene.textureDimensions(tex)
  -- KASC 6.5.17 publishes the source-density receipt explicitly.  Honour it
  -- only when the actual canvas agrees, so a stale/partial wrapper can never
  -- enlarge an unrelated surface.  Older compatible wrappers did not expose
  -- the field; their exact 160x144 multiple remains a supported fallback.
  local declared = tonumber(tex.ascendantTrainerSourceScale)
  if declared ~= nil then
    if not (declared == declared and declared > 0 and declared <= 8
            and declared == math.floor(declared)
            and cw == BattleScene.GB_W * declared
            and ch == BattleScene.GB_H * declared) then
      return 1
    end
    return declared
  end
  local sx, sy = cw / BattleScene.GB_W, ch / BattleScene.GB_H
  if not (sx == sx and sy == sy and sx > 0 and sy > 0
          and sx < math.huge and sy < math.huge
          and math.abs(sx - sy) < 0.001) then return 1 end
  return sx
end

function BattleScene.textureAnchorX(tex)
  local cw = BattleScene.textureDimensions(tex)
  local ax = tonumber(tex and tex.ax) or cw / 2
  return ax * BattleScene.texturePixelScale(tex)
end

-- A sprite's feet are its last visible alpha row, not the bottom of its
-- transparent card. This fixes both the differently padded 33 Mega masters
-- and ordinary compact species such as Rattata. The reported engine anchor is
-- still the hard lower bound, so an animation/provider can never push a card
-- beneath the ground by extending ink outside its declared slot.
function BattleScene.textureBaseline(tex)
  local ay = tonumber(tex and tex.ay) or BattleScene.GB_H
  ay = ay * BattleScene.texturePixelScale(tex)
  local _, _, _, y1 = BattleScene.textureInkBounds(tex)
  if type(y1) ~= "number" then return ay end
  -- Trainer canvases contain the engine's final placement, including KASC's
  -- 64px fronts and per-character back offset.  Their last alpha row is the
  -- only truthful foot line; clamping it to the legacy 56/96 anchor is the
  -- exact operation that buried the lower body in the voxel floor.
  if BattleScene.isTrainerTexture(tex) then return y1 + 1 end
  return math.min(ay, y1 + 1)
end

-- The engine's 160x144 battle cards deliberately normalise every species to
-- nearly the same picture box. That is faithful in the Game Boy frame, but in
-- a staged world it made a Rattata and a Charizard stand at the same physical
-- height. Use the canonical Pokédex height carried by OverworldBattle, with a
-- deliberately restrained curve: small species remain readable, enormous
-- species still fit indoors, and authored scene scale continues to own the
-- overall room/arena composition. Trainers have their own human-scale art and
-- therefore stay exactly at the scene scale.
BattleScene.SPECIES_HEIGHT_REFERENCE = 36
BattleScene.SPECIES_SCALE_MIN = 0.72
BattleScene.SPECIES_SCALE_MAX = 1.80
-- Intimate painted rooms already enlarge every actor around the authored
-- feet. Preserve their reviewed composition while still letting Onix read as
-- larger than Charizard outdoors: the product of room and species scale may
-- not exceed the largest previously accepted indoor actor envelope.
BattleScene.PRESENTATION_SCALE_MAX = 2.75
BattleScene.COMPANION_MASTER_CARD = 96
BattleScene.MEGA_DENSITY_MAX = 1
BattleScene.PAIR_SPREAD_WIDTH = 40
BattleScene.PAIR_SPREAD_FACTOR = 0.75
local GOROCHU_CRYSTAL_PRIMARY_DENSITY = 1.08

-- Maximum visible actor footprint that the deliberately tight 1X camera may
-- frame without widening. These are world units after canonical species,
-- room and high-density KASC/Mega scaling have all been applied. The result
-- is a transient camera floor, not a sprite shrink: feet, relative species
-- size and authored ARENA compositions therefore remain untouched.
BattleScene.ACTOR_FIT_WORLD_HEIGHT = 10.9
BattleScene.ACTOR_FIT_WORLD_WIDTH = 14.5

-- KASC redraws Mega/Gorochu art from a 96px master so it stays crisp. Those
-- extra pixels are source density, not extra physical height. A fixed 56/96
-- conversion was still wrong for low or broadly posed masters: their visible
-- alpha could occupy only half of that nominal card, making Mega Charizard X
-- smaller than ordinary Charizard and the Raichu forms smaller still.
--
-- Normalize the longest visible axis of every Mega to the ordinary 56px
-- battle-card envelope.  Using alpha HEIGHT alone made broad, low poses such
-- as Mega Charizard and Mega Alakazam almost twice as large after the form
-- swap: their short height produced a huge density multiplier even though
-- their wings/spoons already filled the full master width.  The master is a
-- higher-resolution source, not a larger creature. Canonical Pokédex height
-- still supplies the physical species scale below; this conversion only
-- removes source-density from the equation.
function BattleScene.textureDensityScale(tex, combinedScale)
  local legacy = BattleBillboard.FULL_PIC
    / BattleScene.COMPANION_MASTER_CARD
  if BattleScene.isTrainerTexture(tex)
      and tex.ascendantHighResTrainer == true then
    return 1 / BattleScene.texturePixelScale(tex), "trainer-hires"
  end
  if tex and tex.kantoAscendantMegaSupersampled == true then
    local x0, y0, x1, y1 = BattleScene.textureInkBounds(tex)
    if not (type(x0) == "number" and type(y0) == "number"
            and type(x1) == "number" and type(y1) == "number"
            and x1 >= x0 and y1 >= y0) then
      return legacy, "master-no-ink"
    end
    local inkWidth, inkHeight = x1 - x0 + 1, y1 - y0 + 1
    local longest = math.max(inkWidth, inkHeight)
    local density = BattleBillboard.FULL_PIC / longest
    density = math.max(legacy,
      math.min(BattleScene.MEGA_DENSITY_MAX, density))
    return density, "master-normalized"
  end
  if tex and tex.kantoAscendantGorochuSupersampled == true then
    -- KASC's current Crystal-primary lane is a native 56x56 card painted 1:1
    -- into the ordinary 160x144 side canvas.  Treating it as the older 96px
    -- illustrated master applied 56/96 twice and made Gorochu smaller than
    -- Raichu.  The provider already publishes the exact asset lane: use that
    -- narrow receipt for the reviewed Gorochu-only presentation adjustment.
    -- Its 1.08 factor makes the measured painted area approximately 1.5x
    -- Raichu while its visible height remains just below Blastoise under the
    -- same anchor, room scale and camera.  Unknown or illustrated lanes keep
    -- the legacy fail-open conversion below.
    if tex.kantoAscendantGorochuAssetLane == "crystal-primary" then
      return GOROCHU_CRYSTAL_PRIMARY_DENSITY, "gorochu-crystal-primary"
    end
    return legacy, "gorochu-legacy"
  end
  return 1, "native"
end

function BattleScene.speciesScale(tex)
  if not tex or BattleScene.isTrainerTexture(tex) then return 1 end
  local height = tonumber(tex.heightIn)
  if not (height and height == height and height > 0
          and height < math.huge) then
    return 1
  end
  local scale = math.sqrt(height / BattleScene.SPECIES_HEIGHT_REFERENCE)
  return math.max(BattleScene.SPECIES_SCALE_MIN,
                  math.min(BattleScene.SPECIES_SCALE_MAX, scale))
end

function BattleScene.presentationMetrics(tex, actorScale, profileObject)
  local cw, ch = BattleScene.textureDimensions(tex)
  local room = tonumber(actorScale) or 1
  if not (room == room and room > 0 and room < math.huge) then room = 1 end
  local combined = room
  if not BattleScene.isTrainerTexture(tex) then
    combined = math.min(BattleScene.PRESENTATION_SCALE_MAX,
                        room * BattleScene.speciesScale(tex))
  end
  local density, densityPolicy = BattleScene.textureDensityScale(tex, combined)
  local k = (BattleBillboard.FULL_W / BattleBillboard.FULL_PIC)
    * combined * density
  local x0, y0, x1, y1 = BattleScene.textureInkBounds(tex)
  local anchorX = BattleScene.textureAnchorX(tex)
  local baseline = BattleScene.textureBaseline(tex)
  local foot = type(profileObject) == "table" and profileObject.footAnchor
  if type(foot) == "table" then
    local fx, fy = tonumber(foot.x), tonumber(foot.y)
    if fx and fx == fx and fx >= 0 and fx <= 1 then anchorX = fx * cw end
    if fy and fy == fy and fy >= 0 and fy <= 1 then baseline = fy * ch end
  elseif type(profileObject) == "table" then
    local authored = tonumber(profileObject.baseline)
    if authored and authored == authored and authored >= 0
        and authored <= 1 then baseline = authored * ch end
  end
  return {
    canvasWidth = cw, canvasHeight = ch,
    anchorX = anchorX,
    baseline = baseline,
    scale = k, combinedScale = combined, densityScale = density,
    densityPolicy = densityPolicy,
    inkX0 = x0, inkY0 = y0, inkX1 = x1, inkY1 = y1,
    inkWidth = x0 and (x1 - x0 + 1) or nil,
    inkHeight = y0 and (y1 - y0 + 1) or nil,
    worldInkWidth = x0 and (x1 - x0 + 1) * k or nil,
    worldInkHeight = y0 and (y1 - y0 + 1) * k or nil,
  }
end

-- Resolve one role's user correction after source-density/species metrics are
-- known.  The neutral answer is byte-for-byte the historical presentation,
-- which keeps authored arena anchors and existing saves unchanged.
function BattleScene.actorPresentation(side, tex, baseScale, context)
  baseScale = tonumber(baseScale) or 1
  local metrics = tex and BattleScene.presentationMetrics(tex, baseScale)
  local adjustment, target = { x=0, y=0, scale=1 }, nil
  local controller = battleLayout()
  if controller and type(controller.actorAdjustment) == "function" then
    local ok, got, id = pcall(controller.actorAdjustment, side, tex, metrics,
                              context)
    if ok and type(got) == "table" then
      adjustment, target = got, id
    end
  end
  local scale = tonumber(adjustment.scale) or 1
  if not (scale == scale and scale > 0 and scale < math.huge) then scale = 1 end
  return {
    x = tonumber(adjustment.x) or 0,
    y = tonumber(adjustment.y) or 0,
    scale = baseScale * scale,
    factor = scale,
    target = target,
    metrics = metrics,
    normalizedX = tonumber(adjustment.normalizedX),
    normalizedY = tonumber(adjustment.normalizedY),
    flipX = type(adjustment.flipX) == "boolean" and adjustment.flipX or nil,
    profileObject = adjustment.profileObject,
  }
end

function BattleScene.presentationFitDistance(arena, textures, map)
  -- Authored paintings already open on their reviewed 3X master and own the
  -- exact clearings/foot positions. The fit floor is for steerable MAP and
  -- DISCS close-ups only.
  if arena and arena.arenaStyle then return 1 end
  if type(textures) ~= "table" then return 1 end
  local stage = V.require("VoxelBattleStage")
  local actorScale = stage and type(stage.presentationScale) == "function"
                     and stage.presentationScale(arena) or 1
  local context = battleLayoutContext(arena, map)
  local fit = 1
  for _, side in ipairs({ "player", "enemy" }) do
    local tex = textures[side]
    if tex then
      local role = BattleScene.actorPresentation(side, tex, actorScale,
                                                  context)
      local metrics = BattleScene.presentationMetrics(
        tex, role.scale, role.profileObject)
      local h, w = tonumber(metrics.worldInkHeight),
                   tonumber(metrics.worldInkWidth)
      if h and h > 0 then
        fit = math.max(fit, h / BattleScene.ACTOR_FIT_WORLD_HEIGHT)
      end
      if w and w > 0 then
        fit = math.max(fit, w / BattleScene.ACTOR_FIT_WORLD_WIDTH)
      end
    end
  end
  return math.max(1, math.min(tonumber(BattleCam.ZOOM_MAX) or 3, fit))
end

local function monMatrix(tex, x, groundY, z, mirror, yaw, actorScale,
                         profileObject)
  local metrics = BattleScene.presentationMetrics(tex, actorScale,
                                                   profileObject)
  local k = metrics.scale
  local w = metrics.canvasWidth * k
  local h = metrics.canvasHeight * k
  local ax = metrics.anchorX
  local ox = -((ax / metrics.canvasWidth) - 0.5) * w
  local oy = -((metrics.canvasHeight - metrics.baseline)
               / metrics.canvasHeight) * h
  -- The visible card follows the camera. A caller may instead supply the
  -- object's own stable bearing for the sun pass; this keeps a shadow rooted
  -- to the combatant while the presentation camera drifts around it.
  yaw = yaw or BattleBillboard.yawToward(x, z, Voxel3D.eye)
  local card = Mat4.mul(Mat4.translate(ox, oy, 0), Mat4.scale(w, h, 1))
  if mirror then card = Mat4.mul(Mat4.scale(-1, 1, 1), card) end
  return Mat4.mul(Mat4.mul(Mat4.translate(x, groundY, z), Mat4.rotateY(yaw)),
                  card)
end

-- The canonical arena cells are separated in depth, which is enough for the
-- normal 56px cards. Two physically large silhouettes can still touch after
-- that depth line is projected into the oblique battle camera. Keep every
-- reviewed anchor unchanged for an ordinary pair; only the excess combined
-- visible width is taken from the free lower-left/player side. The upper-right
-- opponent remains on its authored mark and therefore cannot be pushed under
-- its original right-side HUD. This preserves size (rather than shrinking a
-- Mega/Onix), and it applies to the card, shadow and returned HUD/effect pins
-- through one common layout.
-- Return a world's x/z point on a fixed ground plane for a normalized
-- full-viewport screen anchor. This is the inverse of the VP projection for
-- the two free coordinates, and therefore stays resolution/aspect agnostic.
function BattleScene.worldAtNormalized(vp, normalizedX, normalizedY, worldY)
  if type(vp) ~= "table" then return nil end
  local nx = tonumber(normalizedX)
  local ny = tonumber(normalizedY)
  local y = tonumber(worldY) or 0
  if not (nx and ny and nx == nx and ny == ny
          and nx >= 0 and nx <= 1 and ny >= 0 and ny <= 1) then return nil end
  nx, ny = nx * 2 - 1, ny * 2 - 1
  local ax, az = vp[1] - nx * vp[13], vp[3] - nx * vp[15]
  local bx, bz = vp[5] - ny * vp[13], vp[7] - ny * vp[15]
  local ar = nx * (vp[14] * y + vp[16]) - (vp[2] * y + vp[4])
  local br = ny * (vp[14] * y + vp[16]) - (vp[6] * y + vp[8])
  local determinant = ax * bz - az * bx
  if not (determinant == determinant and math.abs(determinant) > 1e-9) then
    return nil
  end
  return (ar * bz - az * br) / determinant,
         (ax * br - ar * bx) / determinant
end

local function normalizedProjection(vp, x, y, z)
  if type(vp) ~= "table" then return nil end
  local cx = vp[1] * x + vp[2] * y + vp[3] * z + vp[4]
  local cy = vp[5] * x + vp[6] * y + vp[7] * z + vp[8]
  local cw = vp[13] * x + vp[14] * y + vp[15] * z + vp[16]
  if not (cw and cw > 1e-9) then return nil end
  return cx / cw * .5 + .5, cy / cw * .5 + .5
end

-- Conservative screen-space envelope used by the STADIUM director before a
-- frame is drawn.  It deliberately describes a large battle card rather than
-- a species id: camera safety stays generation/provider neutral, while the
-- final renderer may still use tighter per-texture metrics for presentation.
BattleScene.CAMERA_SAFE_ACTOR_RADIUS = 16
BattleScene.CAMERA_SAFE_ACTOR_HEIGHT = 32

-- Assigned after monCards is defined.  Camera-safety candidates and the real
-- renderer deliberately share this exact alpha-ink projection path.
local actorVisualsFor
local projectedArenaGeometry

local function projectedPixels(vp, x, y, z, pw, ph)
  local nx, ny = normalizedProjection(vp, x, y, z)
  if not (nx and ny) then return nil end
  return nx * pw, ny * ph
end

function BattleScene.projectedActorHull(vp, x, y, z, pw, ph,
                                         radius, height)
  radius = tonumber(radius) or BattleScene.CAMERA_SAFE_ACTOR_RADIUS
  height = tonumber(height) or BattleScene.CAMERA_SAFE_ACTOR_HEIGHT
  local left, top, right, bottom
  -- A camera-facing card can expose either world axis over a 360-degree orbit.
  -- Project the complete conservative prism so no bearing gets a thinner hull
  -- merely because its billboard has not yet been built.
  for _, ox in ipairs({ -radius, radius }) do
    for _, oz in ipairs({ -radius, radius }) do
      for _, oy in ipairs({ 0, height }) do
        local px, py = projectedPixels(vp, x + ox, y + oy, z + oz, pw, ph)
        if not px then return nil end
        left = left and math.min(left, px) or px
        right = right and math.max(right, px) or px
        top = top and math.min(top, py) or py
        bottom = bottom and math.max(bottom, py) or py
      end
    end
  end
  local fx, fy = projectedPixels(vp, x, y, z, pw, ph)
  if not fx then return nil end
  return { left, top, right - left, bottom - top }, { fx, fy }
end

-- Build the candidate shot record consumed by public HUD camera-bounds
-- providers. This is the exact BattleScene projection/letterbox transform but
-- does not bind a canvas or mutate Voxel3D's live camera.
function BattleScene.cameraSafetyShot(arena, groundY, camera, textures, map,
                                      renderToken)
  if not (arena and arena.player and arena.enemy and camera
          and camera.eye and camera.focus and camera.fov) then return nil end
  local lx, ly, s, pw, ph = BattleScene.letterbox()
  if not (pw > 0 and ph > 0 and s > 0) then return nil end
  -- Match the real renderer's complete finishing pass. fitPortrait mutates
  -- the camera, so operate on a private copy: camera-safety queries must be
  -- observational and may not tilt the director's live rig.
  local fitted = {
    eye={ camera.eye[1], camera.eye[2], camera.eye[3] },
    focus={ camera.focus[1], camera.focus[2], camera.focus[3] },
    up=camera.up and { camera.up[1], camera.up[2], camera.up[3] }
                    or { 0, 1, 0 },
    fov=BattleScene.letterboxFov(camera.fov, ph, s),
    curve=camera.curve,
  }
  fitted = BattleCam.fitPortrait(fitted, nil, pw, ph, arena)
  local fov = fitted.fov
  local dx = fitted.eye[1] - fitted.focus[1]
  local dy = fitted.eye[2] - fitted.focus[2]
  local dz = fitted.eye[3] - fitted.focus[3]
  local dist = math.max(1, math.sqrt(dx * dx + dy * dy + dz * dz))
  local proj = Mat4.perspective(fov, pw / ph,
    math.max(1, dist * .05), dist * 4 + 4096)
  proj = Mat4.mul(Mat4.scale(1, -1, 1), proj)
  local vp = Mat4.mul(proj, Mat4.lookAt(
    fitted.eye, fitted.focus, fitted.up))
  local shot = {
    lx=lx, ly=ly, scale=s, pw=pw, ph=ph,
    actorHulls={}, actorFeet={}, cameraSafety=true,
    renderToken=renderToken,
    layoutContext=battleLayoutContext(arena, map or arena.map),
  }
  groundY = tonumber(groundY) or 0
  local geometry = projectedArenaGeometry and projectedArenaGeometry(
    arena, groundY, textures, map or arena.map, vp, pw, ph, lx, ly, s)
  if not geometry then return nil end
  shot.player, shot.enemy = geometry.player, geometry.enemy
  shot.playerSpan, shot.enemySpan = geometry.playerSpan, geometry.enemySpan
  shot.actorHulls, shot.actorFeet = geometry.actorHulls, geometry.actorFeet
  if textures and actorVisualsFor then
    shot.actorVisuals = actorVisualsFor(
      arena, groundY, textures, map or arena.map, vp, pw, ph,
      renderToken, fitted.eye)
  end
  return shot
end

function BattleScene.presentationLayout(arena, groundY, textures, map, vp)
  local stage = V.require("VoxelBattleStage")
  local layout = { actorScale={}, target={}, flipX={}, profileObject={},
                   profilePosition={} }
  local baseScale = stage.presentationScale(arena)
  local context = battleLayoutContext(arena, map)
  vp = vp or Voxel3D.vp
  for _, side in ipairs({ "player", "enemy" }) do
    local texture = textures and textures[side]
    local x, y, z = stage.presentationPosition(
      arena, side, groundY, texture and texture.trainer == true)
    if x then
      local role = BattleScene.actorPresentation(side, texture, baseScale,
                                                  context)
      local normalizedX, normalizedY = role.normalizedX, role.normalizedY
      if (normalizedX or normalizedY) and vp then
        local currentX, currentY = normalizedProjection(vp, x, y, z)
        normalizedX = normalizedX or currentX
        normalizedY = normalizedY or currentY
        local authoredX, authoredZ = BattleScene.worldAtNormalized(
          vp, normalizedX, normalizedY, y)
        if authoredX and authoredZ then
          x, z = authoredX, authoredZ
          layout.profilePosition[side] = true
        end
      end
      -- Menu axes follow screen convention: positive Y moves down.  World Y
      -- grows upward, hence the subtraction here.
      layout[side] = { x + role.x, y - role.y, z }
      layout.actorScale[side] = role.scale
      layout.target[side] = role.target
      layout.flipX[side] = role.flipX
      layout.profileObject[side] = role.profileObject
    end
  end

  -- Portable ARENA paintings may be replaced or selected per route by an
  -- Injector content pack. Their historical world offsets can then put both
  -- actors on one clearing, in transparent sky or against a frame edge.
  -- VoxelBattleStage analyses the exact chosen bitmap once and publishes two
  -- open-ground foot marks. Apply those marks only when no imported Battle
  -- Layout profile explicitly owns either actor; inverse projection keeps
  -- cards, shadows, effects and HUD receipts on one shared world contract.
  if arena and arena.arenaStyle and vp
      and not layout.profilePosition.player
      and not layout.profilePosition.enemy
      and layout.player and layout.enemy
      and type(stage.presentationComposition) == "function" then
    local playerTexture = textures and textures.player
    local enemyTexture = textures and textures.enemy
    local playerComposition = stage.presentationComposition(
      arena, playerTexture and playerTexture.trainer == true)
    local enemyComposition = stage.presentationComposition(
      arena, enemyTexture and enemyTexture.trainer == true)
    local playerMark = playerComposition and playerComposition.player
    local enemyMark = enemyComposition and enemyComposition.enemy
    if playerMark and enemyMark then
      local pnx, pny = normalizedProjection(
        vp, layout.player[1], layout.player[2], layout.player[3])
      local enx, eny = normalizedProjection(
        vp, layout.enemy[1], layout.enemy[2], layout.enemy[3])
      local pairUnsafe = not (pnx and pny and enx and eny)
        or math.abs(enx - pnx) < .27
        or pnx < .14 or pnx > .86 or enx < .14 or enx > .86
        or pny < .46 or pny > .74 or eny < .46 or eny > .74
        or math.abs(pnx - playerMark.x) + math.abs(pny - playerMark.y) > .20
        or math.abs(enx - enemyMark.x) + math.abs(eny - enemyMark.y) > .20
      if pairUnsafe then
        local px, pz = BattleScene.worldAtNormalized(
          vp, playerMark.x, playerMark.y, layout.player[2])
        local ex, ez = BattleScene.worldAtNormalized(
          vp, enemyMark.x, enemyMark.y, layout.enemy[2])
        if px and ex then
          layout.player[1], layout.player[3] = px, pz
          layout.enemy[1], layout.enemy[3] = ex, ez
          layout.smartArenaComposition = playerComposition.source
            or enemyComposition.source or "automatic"
        end
      end
    end
  end
  if not (textures and layout.player and layout.enemy) then return layout end
  local playerMetrics = textures.player
    and BattleScene.presentationMetrics(textures.player,
      layout.actorScale.player or baseScale, layout.profileObject.player)
  local enemyMetrics = textures.enemy
    and BattleScene.presentationMetrics(textures.enemy,
      layout.actorScale.enemy or baseScale, layout.profileObject.enemy)
  local playerWidth = playerMetrics
    and tonumber(playerMetrics.worldInkWidth)
  local enemyWidth = enemyMetrics and tonumber(enemyMetrics.worldInkWidth)
  if not (playerWidth and playerWidth > 0
          and enemyWidth and enemyWidth > 0) then return layout end
  if layout.profilePosition.player or layout.profilePosition.enemy then
    return layout
  end
  local excess = playerWidth + enemyWidth
    - BattleScene.PAIR_SPREAD_WIDTH * baseScale
  if excess <= 0 then return layout end
  local spread = excess * BattleScene.PAIR_SPREAD_FACTOR
  layout.player[1] = layout.player[1] - spread
  layout.spread = spread
  return layout
end

-- One pure projection record shared by candidate safety and the actual frame.
-- Profile positions, pair spread, actor-specific Y/Z and species scale must be
-- reflected in both places; projecting raw arena cells in one path lets a
-- camera pass safety for actors that the renderer subsequently moves.
projectedArenaGeometry = function(
    arena, groundY, textures, map, vp, pw, ph, lx, ly, s)
  local stage = V.require("VoxelBattleStage")
  local layout = BattleScene.presentationLayout(
    arena, groundY, textures, map, vp)
  local player = layout.player
  local enemy = layout.enemy
  local playerX, playerY, playerZ = player and player[1],
    player and player[2], player and player[3]
  local enemyX, enemyY, enemyZ = enemy and enemy[1],
    enemy and enemy[2], enemy and enemy[3]
  if not (playerX and enemyX) then return nil end
  local pmx, pmy = BattleScene.toGB(
    vp, playerX, playerY, playerZ, lx, ly, s, pw, ph)
  local emx, emy = BattleScene.toGB(
    vp, enemyX, enemyY, enemyZ, lx, ly, s, pw, ph)
  if not (pmx and emx) then return nil end
  local half = BattleScene.CELL / 2
  local pl = BattleScene.toGB(
    vp, playerX - half, playerY, playerZ, lx, ly, s, pw, ph)
  local pr = BattleScene.toGB(
    vp, playerX + half, playerY, playerZ, lx, ly, s, pw, ph)
  local el = BattleScene.toGB(
    vp, enemyX - half, enemyY, enemyZ, lx, ly, s, pw, ph)
  local er = BattleScene.toGB(
    vp, enemyX + half, enemyY, enemyZ, lx, ly, s, pw, ph)
  if not (pl and pr and el and er) then return nil end
  local playerHull, playerFoot = BattleScene.projectedActorHull(
    vp, playerX, playerY, playerZ, pw, ph)
  local enemyHull, enemyFoot = BattleScene.projectedActorHull(
    vp, enemyX, enemyY, enemyZ, pw, ph)
  if not (playerHull and playerFoot and enemyHull and enemyFoot) then return nil end
  return {
    layout=layout,
    player={ pmx, pmy }, enemy={ emx, emy },
    playerSpan=math.abs(pr - pl)
      * (layout.actorScale.player or stage.presentationScale(arena)),
    enemySpan=math.abs(er - el)
      * (layout.actorScale.enemy or stage.presentationScale(arena)),
    actorHulls={ player=playerHull, enemy=enemyHull },
    actorFeet={ player=playerFoot, enemy=enemyFoot },
  }
end

-- Every mon that has something to show this frame. `model` is the
-- camera-facing presentation card; `shadowModel` is the same silhouette
-- standing on the same feet but facing its opponent. Keeping those separate
-- matters because camera drift is a property of the shot, not movement by the
-- Pokemon: using `model` for the sun made the shadow rotate and slide while
-- its owner stood still. Authored full-frame backdrops cannot receive that
-- silhouette through ShadowMap, so they also retain one conservative contact
-- footprint derived from the visible ink width.
local function monCards(arena, groundY, textures, map, vp, eye)
  local out = {}
  if not textures then return out end
  local stage = V.require("VoxelBattleStage")
  local baseScale = stage.presentationScale(arena)
  local layout = BattleScene.presentationLayout(arena, groundY, textures,
                                                 map, vp)
  for _, side in ipairs({ "enemy", "player" }) do
    local tex = textures[side]
    local cell = (side == "player") and arena.player or arena.enemy
    local position = layout[side]
    local cardX, cardY, cardZ = position and position[1],
      position and position[2], position and position[3]
    if tex and tex.canvas and cell and cardX then
      local explicit = type(tex.flipX) == "boolean"
        or type(tex.vascFlipX) == "boolean"
      local mirror
      if not explicit and type(layout.flipX[side]) == "boolean" then
        mirror = layout.flipX[side]
      else
        mirror = BattleScene.textureFlipX(side, tex)
      end
      local otherSide = (side == "player") and "enemy" or "player"
      local other = layout[otherSide]
      local otherX, otherZ = other and other[1], other and other[3]
      local objectYaw = otherX
                        and BattleBillboard.yawToward(
                              cardX, cardZ, { otherX, 0, otherZ })
                        or 0
      local actorScale = layout.actorScale[side] or baseScale
      local profileObject = layout.profileObject[side]
      local visibleYaw = BattleBillboard.yawToward(
        cardX, cardZ, eye or Voxel3D.eye)
      local metrics = BattleScene.presentationMetrics(
        tex, actorScale, profileObject)
      local inkWidth = tonumber(metrics.worldInkWidth) or BattleScene.CELL
      local contactRadiusX = math.max(2.5, math.min(7.5, inkWidth * .28))
      local contactRadiusZ = math.max(1.8,
        math.min(4.2, contactRadiusX * .58))
      out[#out + 1] = { side=side, tex = tex.canvas, source=tex,
                        metrics=metrics,
                        -- Authored backdrops move each reviewed foot mark in
                        -- Y independently.  Keep the projected contact plane
                        -- on that exact mark; flattening both silhouettes to
                        -- the arena's unadjusted groundY shears them away from
                        -- their owners before they ever reach screen space.
                        shadowGroundY=cardY,
                        shadowFoot={cardX, cardY, cardZ},
                        shadowRadius={contactRadiusX, contactRadiusZ},
                        model = monMatrix(tex, cardX, cardY, cardZ,
                                          mirror, visibleYaw,
                                          actorScale, profileObject),
                        shadowModel = monMatrix(tex, cardX, cardY,
                                                cardZ, mirror, objectYaw,
                                                actorScale, profileObject) }
    end
  end
  return out
end

BattleScene.monCards = monCards

local function projectedModelPoint(mvp, x, y, pw, ph)
  local cx = mvp[1] * x + mvp[2] * y + mvp[4]
  local cy = mvp[5] * x + mvp[6] * y + mvp[8]
  local cw = mvp[13] * x + mvp[14] * y + mvp[16]
  if not (cw and cw > 1e-9) then return nil end
  return (cx / cw * .5 + .5) * pw,
         (cy / cw * .5 + .5) * ph
end

-- Exact visible alpha envelope of the same billboard matrix sent to Voxel3D.
-- This is intentionally distinct from projectedActorHull's conservative
-- 16x32 world prism: HUD ownership needs the real species/form/model head,
-- while collision safety may still retain the conservative hull as a floor.
local function actorVisualForCard(card, vp, pw, ph, renderToken)
  local metrics = card and card.metrics
  local source = card and card.source
  if not (metrics and card.model and source
      and tonumber(metrics.canvasWidth) and metrics.canvasWidth > 0
      and tonumber(metrics.canvasHeight) and metrics.canvasHeight > 0
      and tonumber(metrics.inkX0) and tonumber(metrics.inkY0)
      and tonumber(metrics.inkX1) and tonumber(metrics.inkY1)) then
    return nil
  end
  local cw, ch = metrics.canvasWidth, metrics.canvasHeight
  local x0 = metrics.inkX0 / cw - .5
  local x1 = (metrics.inkX1 + 1) / cw - .5
  local y0 = 1 - metrics.inkY0 / ch
  local y1 = 1 - (metrics.inkY1 + 1) / ch
  local mvp = Mat4.mul(vp, card.model)
  local left, top, right, bottom
  for _, point in ipairs({ {x0,y0}, {x1,y0}, {x0,y1}, {x1,y1} }) do
    local x, y = projectedModelPoint(mvp, point[1], point[2], pw, ph)
    if not x then return nil end
    left = left and math.min(left, x) or x
    right = right and math.max(right, x) or x
    top = top and math.min(top, y) or y
    bottom = bottom and math.max(bottom, y) or y
  end
  if not (right > left and bottom > top) then return nil end
  return {
    schema="voxel-ascendant/actor-render/v1",
    side=card.side, renderToken=renderToken,
    hull={ left, top, right - left, bottom - top },
    head={ x=(left + right) * .5, y=top },
    foot={ x=(left + right) * .5, y=bottom },
    battler=source.vascRenderBattler,
    mon=source.vascRenderMon,
    modelKey=source.vascRenderModelKey,
    inkIdentity=source.inkIdentity,
    textureToken=source.vascRenderTextureToken,
    canvas=source.canvas,
    view=source.vascSpriteView,
    viewportW=pw, viewportH=ph,
  }
end

actorVisualsFor = function(arena, groundY, textures, map, vp, pw, ph,
                           renderToken, eye)
  local visuals = {}
  for _, card in ipairs(monCards(
      arena, groundY, textures, map, vp, eye)) do
    local receipt = actorVisualForCard(card, vp, pw, ph, renderToken)
    if receipt then visuals[card.side] = receipt end
  end
  local okStadium, stadium = pcall(V.require, "Stadium")
  if okStadium and type(stadium) == "table"
      and type(stadium.visualReceipt) == "function" then
    for _, side in ipairs({ "player", "enemy" }) do
      local okReceipt, receipt = pcall(
        stadium.visualReceipt, side, vp, pw, ph, renderToken)
      if okReceipt and type(receipt) == "table" then
        visuals[side] = receipt
      end
    end
  end
  return visuals
end

-- The MOVE-ANIMATION layer's place in the world: a BILLBOARD facing the
-- eye, for the GB-frame effects texture OverworldBattle.animTexture
-- renders (the engine's own drawAnimLayer, caught on a canvas).
--
-- Effects are 2D drawings like the pics, and the pics' answer holds for
-- them too: a drawing must FACE the eye that is looking (the mon cards
-- yaw toward it per eye -- see monMatrix). So the frame stands on the
-- arena's midpoint, yawed at the eye like the cards are, and the classic
-- layout's two slot marks are pinned where each CELL lands on that plane
-- along this very eye's own ray -- so from the eye that is looking, a
-- burst authored at a slot sits exactly over the mon standing in for it,
-- and a projectile crossing the frame crosses the arena. The vertical
-- scale is the mon cards' own (FULL_W / FULL_PIC), so an effect is sized
-- like the pics it plays over.
--
-- An eye standing (nearly) ON the arena's axis sees the two cells in
-- line and the pinning degenerates; the frame then falls back to the
-- fixed plane through both cells, which that eye views edge-on anyway.
--
-- Reads Voxel3D.eye at CALL time, like the cards -- call it per eye.
-- Returns the model matrix for BattleBillboard's unit card (x -0.5..0.5,
-- y 0..1 up, v flipped), or nil where the anchors are degenerate.
function BattleScene.fxCard(arena, groundY, anchors)
  local p, e = anchors.player, anchors.enemy
  local dgb = e[1] - p[1]
  if math.abs(dgb) < 1 then return nil end
  local GW, GH = BattleScene.GB_W, BattleScene.GB_H
  local stage = V.require("VoxelBattleStage")
  local Px, Py, Pz = stage.presentationPosition(arena, "player", groundY)
  local Ex, Ey, Ez = stage.presentationPosition(arena, "enemy", groundY)
  if not (Px and Ex) then return nil end
  local s = (BattleBillboard.FULL_W / BattleBillboard.FULL_PIC)
            * stage.presentationScale(arena)
  local Mx, My, Mz = (Px + Ex) / 2, (Py + Ey) / 2, (Pz + Ez) / 2

  local eye = Voxel3D.eye
  local yaw = BattleBillboard.yawToward(Mx, Mz, eye)
  local nx, nz = math.sin(yaw), math.cos(yaw)     -- out of the frame, at the eye
  local rx, rz = math.cos(yaw), -math.sin(yaw)    -- the frame's own right

  -- where a world point sits ON the billboard, as (right, up) coordinates
  -- about the midpoint: slid along the eye's ray onto the plane, so the
  -- mark and the mon line up from exactly the seat that is looking
  local function inPlane(qx_, qy_, qz_)
    if eye then
      local dqx, dqy, dqz = qx_ - eye[1], qy_ - eye[2], qz_ - eye[3]
      local denom = dqx * nx + dqz * nz
      if math.abs(denom) > 1e-6 then
        local t = ((Mx - eye[1]) * nx + (Mz - eye[3]) * nz) / denom
        qx_ = eye[1] + dqx * t
        qy_ = eye[2] + dqy * t
        qz_ = eye[3] + dqz * t
      end
    end
    return (qx_ - Mx) * rx + (qz_ - Mz) * rz, qy_ - My
  end
  local pax, pay = inPlane(Px, Py, Pz)
  local eax, eay = inPlane(Ex, Ey, Ez)

  if math.abs(eax - pax) < 4 then
    -- edge-on: the fixed plane through both cells, world-axis mapping
    local ux = (Ex - Px) / dgb
    local uy = (Ey - Py - s * (p[2] - e[2])) / dgb
    local uz = (Ez - Pz) / dgb
    local cx = Px + ux * (0.5 * GW - p[1])
    local cy = Py + uy * (0.5 * GW - p[1]) + s * (p[2] - GH)
    local cz = Pz + uz * (0.5 * GW - p[1])
    local nl = math.sqrt(ux * ux + uz * uz)
    local fx, fz = 0, 1
    if nl > 1e-9 then fx, fz = uz / nl, -ux / nl end
    return { ux * GW, 0, fx, cx,
             uy * GW, s * GH, 0, cy,
             uz * GW, 0, fz, cz,
             0, 0, 0, 1 }
  end

  -- in-plane travel per GB pixel of frame x, solved so both marks land:
  -- inPlane(gb) = (pax, pay) + U * (gbx - p.x) + (0, s) * (p.y - gby)
  local ux = (eax - pax) / dgb
  local uy = (eay - pay - s * (p[2] - e[2])) / dgb
  local cxp = pax + ux * (0.5 * GW - p[1])
  local cyp = pay + uy * (0.5 * GW - p[1]) + s * (p[2] - GH)
  return { rx * ux * GW, 0, nx, Mx + rx * cxp,
           uy * GW, s * GH, 0, My + cyp,
           rz * ux * GW, 0, nz, Mz + rz * cxp,
           0, 0, 0, 1 }
end

-- The sun has to see the mons too, or they stand on the ground without
-- putting anything on it. They are the one thing in this scene that MOVES,
-- so `token` -- a counter the caller bumps whenever a pic could have changed
-- -- goes in the signature; the terrain half of the answer would otherwise
-- keep a stale pass alive and freeze the shadows in whatever pose they were
-- first drawn in.
local function shadowSignature(state, arena, terrain, nbMesh, token, horizon,
                               backdropIdentity)
  local host = arena.map or state.map
  local parts = { "battle", host.id, arena.x, arena.y, arena.shape,
                  tostring(terrain), tostring(token or 0),
                  tostring(backdropIdentity),
                  -- the cycle keeps running through a fight, and an arena lit
                  -- from somewhere new must be re-cast from there
                  math.floor(ShadowMap.KX * 128),
                  math.floor(ShadowMap.KZ * 128) }
  for i = 1, #nbMesh do parts[#parts + 1] = tostring(nbMesh[i]) end
  for _, rim in ipairs(horizon or {}) do
    if rim.castsShadow then
      -- The fountain's water/jet batch animates independently and never
      -- casts.  Pin a possible animated solid caster to frame zero so visual
      -- UV animation cannot invalidate the complete arena shadow map.
      parts[#parts + 1] = tostring(
        rim.animationMeshes and rim.animationMeshes[1] or rim.mesh)
      parts[#parts + 1] = tostring(rim.ox or 0)
      parts[#parts + 1] = tostring(rim.oy or 0)
    end
  end
  return table.concat(parts, ",")
end

local function castShadows(state, arena, terrain, nbMesh, cx, cy, vw, vh,
                           atlasFor, cards, token, host, neighbors,
                           water, nbWater, groundY, horizon, screenBackdrop,
                           backdropIdentity)
  if not Shadows.enabled() then return end
  if not ShadowMap.available() then return end
  local sig = shadowSignature(state, arena, terrain, nbMesh, token, horizon,
                              backdropIdentity)
  if not ShadowMap.stale(sig) then return end
  if not ShadowMap.begin(cx, cy, vw, vh) then return end
  local ok, err = pcall(function()
    -- A DISC RUNG: the two discs are the only ground there is, so they are the
    -- only thing the sun has to see besides the Pokemon themselves. Everything
    -- below this is a map that is not in the shot.
    if arena.discs then
      V.require("VoxelBattleStage").cast(ShadowMap, arena, groundY or 0)
    else
      ShadowMap.draw(terrain, atlasFor(host), nil)
      for i, nb in ipairs(neighbors) do
        ShadowMap.draw(nbMesh[i], atlasFor(nb.map),
                       Mat4.translate(nb.ox, 0, nb.oy))
      end
      -- the water surface is its own reflective pass now (see Water) and so is
      -- no longer inside the terrain mesh; the sun still has to see it, or the
      -- light's map has a hole at every lake
      ShadowMap.draw(water, atlasFor(host), nil)
      for i, nb in ipairs(neighbors) do
        ShadowMap.draw(nbWater and nbWater[i], atlasFor(nb.map),
                       Mat4.translate(nb.ox, 0, nb.oy))
      end
      -- Ground-standing scenery-editor models are retained by HorizonWall
      -- rather than ChunkMesher. Only their explicitly static solid batches
      -- enter the sun pass; animated fountain water and crossed jet planes
      -- publish `castsShadow = false` and are therefore excluded here.
      for _, rim in ipairs(horizon or {}) do
        if rim.castsShadow then
          local caster = rim.animationMeshes and rim.animationMeshes[1]
                         or rim.mesh
          ShadowMap.draw(caster, rim.texture,
                         Mat4.translate(rim.ox or 0, 0, rim.oy or 0))
        end
      end
      -- thin cards are snugged toward the sun (ShadowMap.snug) so their
      -- shadows keep contact with their bases instead of starting a
      -- bias-width away
      ShadowMap.draw(ChunkMesher.flowers(host), atlasFor(host),
                     ShadowMap.snug(nil))
      for _, nb in ipairs(neighbors) do
        ShadowMap.draw(ChunkMesher.flowers(nb.map), atlasFor(nb.map),
                       ShadowMap.snug(Mat4.translate(nb.ox, 0, nb.oy)))
      end
    end

    -- the mons themselves, with the same texture/silhouette the camera sees
    -- but on the stable opponent-facing transform monCards prepared. The
    -- camera-facing presentation card is allowed to drift; its owner and the
    -- shadow on the floor are not.
    -- marked as the CAST, so a fight staged at the water's edge does not lay a
    -- cut-out of a Pokemon across the lake (see ShadowMap.sprites); the arena's
    -- own floor still takes them, which is the shadow that matters here
    -- A reviewed full-frame battle painting has no 3D receiver: storing the
    -- cards here can only make those same visible cards compare against their
    -- own packed depth. Its ground-contact silhouettes are composited in the
    -- camera pass below instead. Physical MAP/DISCS stages retain the real
    -- shadow-map caster path so terrain, walls and platforms receive them.
    if not screenBackdrop then
      ShadowMap.sprites(true)
      for _, card in ipairs(cards or {}) do
        ShadowMap.draw(BattleBillboard.mesh(), card.tex,
                       ShadowMap.snug(card.shadowModel))
      end
      ShadowMap.sprites(false)
    end
    local okCast, casted, castErr = pcall(function()
      return V.require("Stadium").cast(ShadowMap)
    end)
    if not okCast or casted == false then
      local okStadium, stadium = pcall(V.require, "Stadium")
      if okStadium and type(stadium.report) == "function" then
        pcall(stadium.report, castErr or casted)
      end
    end
  end)

  local closed, closeErr
  if ok then
    closed, closeErr = pcall(ShadowMap.finish, sig)
  elseif type(ShadowMap.abort) == "function" then
    closed, closeErr = pcall(ShadowMap.abort)
  else
    closed, closeErr = pcall(ShadowMap.finish, nil)
  end
  if not ok then
    if not closed then
      error(tostring(err) .. "; shadow cleanup failed: "
            .. tostring(closeErr), 0)
    end
    error(err, 0)
  end
  if not closed then error(closeErr, 0) end
end

-- Full-frame arena paintings have no depth receiver. Projecting an entire
-- Pokemon alpha silhouette onto that flat image produced a sharp black
-- wing/star shape (and could overlap the visible card). The authored stage
-- therefore gets a deliberately narrow contact cue instead: a small world-
-- space disc under the reviewed feet. Perspective flattens it into an ellipse
-- and three translucent rings feather the edge without ever sampling or
-- recolouring a Pokemon texture.
local backdropShadowMeshCache = nil
local function backdropShadowMesh()
  if backdropShadowMeshCache ~= nil then
    return backdropShadowMeshCache or nil
  end
  if type(Voxel3D.newMesh) ~= "function" then
    backdropShadowMeshCache = false
    return nil
  end
  local segments = 32
  local verts = { { 0, 0, 0, .5, .5, 1 } }
  local indices = {}
  for i = 0, segments - 1 do
    local angle = i * math.pi * 2 / segments
    verts[#verts + 1] = { math.cos(angle), 0, math.sin(angle), .5, .5, 1 }
  end
  for i = 1, segments do
    indices[#indices + 1] = 1
    indices[#indices + 1] = i + 1
    indices[#indices + 1] = (i % segments) + 2
  end
  backdropShadowMeshCache = Voxel3D.newMesh(verts, indices) or false
  return backdropShadowMeshCache or nil
end

local BACKDROP_SHADOW_LAYERS = {
  { scale=1.00, alpha=.12 },
  { scale=.76, alpha=.15 },
  { scale=.50, alpha=.18 },
}

local function drawBackdropShadows(cards, groundY, opaqueBackdrop)
  if not Shadows.enabled() then return 0 end
  local mesh = backdropShadowMesh()
  if not (mesh and opaqueBackdrop) then return 0 end
  local drawn = 0
  local savedAlpha = tonumber(Voxel3D.SHADOW_ALPHA) or BattleScene.SHADOW_ALPHA
  local eps = tonumber(Voxel3D.SHADOW_EPS) or .25
  Voxel3D.seams(false)
  Voxel3D.glass(false)
  local ok, err = pcall(function()
    for _, card in ipairs(cards or {}) do
      local foot = type(card.shadowFoot) == "table" and card.shadowFoot or nil
      local radius = type(card.shadowRadius) == "table"
                     and card.shadowRadius or nil
      local x, y, z = foot and tonumber(foot[1]), foot and tonumber(foot[2]),
                      foot and tonumber(foot[3])
      local rx, rz = radius and tonumber(radius[1]),
                     radius and tonumber(radius[2])
      if x and z and rx and rz and rx > 0 and rz > 0 then
        y = y or tonumber(card.shadowGroundY) or tonumber(groundY) or 0
        -- Bias the oval slightly toward the camera: most of it remains under
        -- the feet, while its lower rim stays visible instead of disappearing
        -- completely behind the upright card's conservative hull.
        local eye = Voxel3D.eye
        local dx = type(eye) == "table" and tonumber(eye[1]) and eye[1] - x or 0
        local dz = type(eye) == "table" and tonumber(eye[3]) and eye[3] - z or 0
        local dl = math.sqrt(dx * dx + dz * dz)
        if dl > 1e-6 then
          x = x + dx / dl * rz * .35
          z = z + dz / dl * rz * .35
        end
        for _, layer in ipairs(BACKDROP_SHADOW_LAYERS) do
          local model = Mat4.mul(
            Mat4.translate(x, y + eps, z),
            Mat4.scale(rx * layer.scale, 1, rz * layer.scale))
          Voxel3D.SHADOW_ALPHA = savedAlpha * layer.alpha
          Voxel3D.beginShadows()
          Voxel3D.draw(mesh, opaqueBackdrop, model, 0, model)
          drawn = drawn + 1
        end
      end
    end
  end)
  Voxel3D.SHADOW_ALPHA = savedAlpha
  Voxel3D.glass(true)
  Voxel3D.seams(true)
  Voxel3D.endShadows()
  if not ok then error(err, 0) end
  return drawn
end

-- The card must CAST onto the stage, but must not RECEIVE its own precision-
-- packed silhouette. Always restore the world receiver state, including when
-- a texture/driver draw fails, so the following grass and scenery stay lit.
local function withoutCardShadowReception(draw)
  local toggle = type(Voxel3D.shadowReception) == "function"
                 and Voxel3D.shadowReception or nil
  if toggle then toggle(false) end
  local ok, err = pcall(draw)
  if toggle then toggle(true) end
  if not ok then error(err, 0) end
end

-- The height of the arena floor: the ground the two mons stand on. Both
-- cells are open, so they are normally the same; take the player's, which is
-- the one nearer the camera and therefore the one a mismatch would show up
-- against.
function BattleScene.groundY(map, arena)
  -- A disc rung's discs are carried, not found: their tops ARE the ground
  -- plane, so there is no terrain height to read and reading one would put
  -- the stage at whatever elevation the map happens to have at a spot the
  -- fight is not actually happening on
  if arena and arena.discs then return 0 end
  local ok, h = pcall(VoxelScene.groundAt, map,
                      arena.playerCell[1], arena.playerCell[2])
  return (ok and h) or 0
end

-- Where a world point lands in GB frame coordinates under `vp`, or nil when
-- it is behind the camera. This is the function the pins are built on: it
-- takes the window-resolution clip position and divides the letterbox back
-- out of it, so the answer is in the same 160x144 space the battle screen
-- draws its pics in.
function BattleScene.toGB(vp, wx, wy, wz, lx, ly, s, pw, ph)
  local cx = vp[1] * wx + vp[2] * wy + vp[3] * wz + vp[4]
  local cy = vp[5] * wx + vp[6] * wy + vp[7] * wz + vp[8]
  local cw = vp[13] * wx + vp[14] * wy + vp[15] * wz + vp[16]
  if cw <= 1e-6 then return nil end
  -- viewProjection already flipped clip Y into LOVE's Y-down convention
  local px = (cx / cw * 0.5 + 0.5) * pw
  local py = (cy / cw * 0.5 + 0.5) * ph
  return (px - lx) / s, (py - ly) / s
end

-- Render the arena and hand back { canvas, player = {x,y}, enemy = {x,y} },
-- the two marks in GB coordinates -- or nil when there is nothing to draw
-- yet (the terrain mesh is still building, the driver has no depth support).
-- nil is not a failure: the caller simply leaves the battle screen as the
-- engine drew it for that frame.
-- White, for the hit flash, and how far toward it the card goes.
--
-- The shader replaces the card's colour rather than multiplying it, so at
-- full strength this is the sprite turned into a solid white silhouette --
-- which is what the effect is on a flat GB screen and far too much on a
-- sprite standing in a lit world. Held well short of 1, the mon's own
-- shading still reads through the flash: it looks struck rather than
-- deleted.
BattleScene.FLASH_COLOR = { 1, 1, 1 }
BattleScene.FLASH_STRENGTH = 0.5

-- Resolve the arena's weather from the map that actually supplies its floor,
-- not blindly from the overworld map. Authored battles may move the camera to
-- another floor of the same building/cave. skyMode also observes the optional
-- Weather-FX/VASC presentation bridge, so the exact overworld spell survives
-- the battle transition; both paths keep every interior clear. Kept as a seam so the
-- battle/weather contract can be exercised without constructing a full GPU
-- scene in the Lua test runner.
function BattleScene.weatherMode(host)
  if Weather.skyMode then return Weather.skyMode(host) end
  return Weather.mode(host)
end

function BattleScene.groundWeather(host, mode, nativeGround)
  if nativeGround == nil then nativeGround = true end
  local baseMode = type(Weather.mode) == "function" and Weather.mode(host)
                   or mode
  local outdoor = type(Weather.isOutdoor) == "function"
                  and Weather.isOutdoor(host) or nil
  WeatherTweak.observe(host, baseMode, Weather.clock, outdoor)
  return WeatherTweak.groundMode(host, mode, nativeGround),
         WeatherTweak.groundAmount(host, mode, nativeGround)
end

function BattleScene.applyWeather(canvas, w, h, host, cell, mode)
  local painter = Weather.applyBattle or Weather.apply
  return painter(canvas, w, h, host, cell,
                 mode or BattleScene.weatherMode(host))
end

-- ------- the tile clock, while the overworld is not the one drawing
--
-- Water and flowers animate off TileRenderer's 60Hz counter, and the ENGINE
-- only advances it from OverworldState:drawWorld -- which runs under dialogs
-- and menus, but not under a battle, because a battle draws instead of the
-- overworld rather than over it. So for the length of a staged fight the
-- counter stood still: the water tiles stopped rotating their pixels and the
-- wave field, which is driven off the same number so the two cannot drift
-- (see Water), stopped with them. A lake in the background of a battle was a
-- photograph.
--
-- Ticked HERE rather than from the mod's update hook, because here is the
-- one place that means "a staged battle is drawing this frame, and the
-- overworld is not". From the update hook the condition would have to be
-- guessed at, and a frame where both ran would double the rate.
local function tickTiles()
  local Game = require("src.core.Game")
  local ow = Game and Game.overworld
  local top = Game and Game.stack and Game.stack:top()
  -- during the wipe INTO a battle the overworld can still be the one
  -- drawing, and it is ticking the clock itself; two ticks in a frame would
  -- run the water at double speed
  if top and ow and top == ow then return end
  pcall(require("src.render.TileRenderer").tick)
end

local function decline(reason)
  BattleScene.lastDeclineReason = tostring(reason or "unspecified")
  return nil
end

function BattleScene.render(state, arena, textures, token)
  BattleScene.lastDeclineReason = nil
  if not (state and state.map and arena) then
    return decline("missing-state-map-or-arena")
  end
  if not Voxel3D.available() then return decline("voxel-unavailable") end
  tickTiles()

  -- the floor the fight is staged on: normally the player's own, sometimes
  -- another floor of the same cave or building (see BattleArena)
  local host = arena.map or state.map
  local neighbors = {}

  -- the hour's light reaches the arena exactly as it reaches free-roam: the
  -- shared rig follows the clock on an outdoor floor and stays at noon on an
  -- indoor one, and the same tint multiplies the staged shot -- with the
  -- same window glass on whatever buildings stand in the background
  local outdoor = Weather.isOutdoor(host)
  DayNight.applyRig(outdoor)
  -- a canopy floor (Viridian Forest) fights under the hour's tint too,
  -- with the rig and the void exactly as they were
  Voxel3D.tint = DayNight.tint(outdoor or DayNight.isCanopy(host))
  local GlassMask = V.require("GlassMask")
  Voxel3D.glassMask = outdoor and GlassMask.texture(host.tileset) or nil
  Voxel3D.glassNight = outdoor and DayNight.windowLight() or 0
  -- no glint in the arena: the drift is the shot breathing, not the player
  -- moving, and a shimmer on background windows would fight the mons
  Voxel3D.glassGlint = 0

  -- A B RUNG stands the fight on two carried discs against the sky, with no
  -- map in the shot at all (see StadiumStage). Everything below still runs --
  -- the letterbox, the camera solve, the sun, the pins, the tint, the depth
  -- of field -- because none of it is about the terrain; what changes is
  -- which geometry the two passes draw.
  local discs = arena.discs and true or false

  -- shares the free-roam mode's request/evict bookkeeping, so a battle warms
  -- exactly the meshes walking around would have and nothing extra
  local terrain, nbMesh, water, nbWater, horizon
  if discs then
    -- and nothing is meshed for a disc fight, which is the other half of why
    -- the rung works everywhere: there is no waiting for a chunk to build, so
    -- the first frame of the first battle on a cold map is the finished shot
    nbMesh, water, nbWater, horizon = {}, nil, {}, {}
  else
    local stage = prefetchArena(state, host)
    if not stage then return decline("arena-prefetch-pending") end
    terrain, water = stage.terrain, stage.water
    neighbors, nbMesh = stage.neighbors, stage.meshes
    nbWater, horizon = stage.waters, stage.horizon
  end

  local lx, ly, s, pw, ph = BattleScene.letterbox()
  if not (pw > 0 and ph > 0 and s > 0) then
    return decline("invalid-letterbox")
  end

  local palette = paletteFor(state, host)
  local function atlasFor(map)
    return TerrainAtlas.forMap(map, VoxelScene._modeColors(palette, map))
  end

  local groundY = BattleScene.groundY(host, arena)
  local sceneryEnabled = HorizonWall.enabled()
  PanoramaBackdrop.setEnabled(sceneryEnabled)
  local panoramaReady = not discs and outdoor and sceneryEnabled
                         and HorizonWall.allowsFarBackdrop({
                           map=host, neighbors=neighbors,
                         })
                         and PanoramaBackdrop.prepare()
  local portableBackdrop = nil
  local screenBackdrop = false
  if discs and arena.arenaStyle then
    local Stage = V.require("VoxelBattleStage")
    portableBackdrop = Stage.backdropFor(arena, outdoor)
    -- ARENA promises a complete picture.  If this driver's image path cannot
    -- prepare it, an authored replacement still declines this frame. A v1
    -- ADD over an otherwise unpainted portable stage is different: its image
    -- is optional, so a late decode/upload failure keeps ARENA and lets the
    -- established generated stage below draw instead of changing provider.
    if not portableBackdrop
        and not Stage.customAddPortableFallback(arena) then
      return decline("arena-backdrop-pending")
    end
    -- Only an authored/REPLACE composition lacks a 3D receiver. ADD keeps the
    -- portable stage, including its ordinary physical Pokemon shadows; its
    -- full-frame image is merely behind that stage.
    screenBackdrop = portableBackdrop ~= nil
      and Stage.hasAuthoredBackdrop(arena)
  end
  local actorFit = BattleScene.presentationFitDistance(arena, textures, host)
  BattleCam.setPresentationFit(actorFit)
  if type(BattleCam.noteViewport) == "function" then
    BattleCam.noteViewport(pw, ph)
  end
  local cam, pitch = BattleCam.rig(arena, groundY)
  -- The final provider-neutral safety gate may deliberately decline this
  -- voxel frame when neither the eased camera nor its last safe snapshot fits
  -- the current immutable HUD/actor geometry. Native battle rendering stays
  -- available and the next update may retry with a recovered camera.
  if not cam then
    local cameraState = type(BattleCam.directorState) == "function"
      and BattleCam.directorState() or nil
    return decline("camera-unavailable:"
      .. tostring(cameraState and cameraState.screenReason or "unknown"))
  end
  cam.fov = BattleScene.letterboxFov(cam.fov, ph, s)
  cam, pitch = BattleCam.fitPortrait(cam, pitch, pw, ph, arena)

  local cx, cy = arena.mid[1], arena.mid[2]
  -- the world extents the sun frustum is fitted to; the camera itself is
  -- framed by cam.fov, so these only have to describe the ground in shot
  -- the player's zoom is part of this: the sun's box is fitted to what the
  -- frame holds, so a shot pulled wide has to light the ground it just
  -- brought into view rather than the ground the rig alone would have
  local vh = BattleCam.frameH(arena) * ph / (BattleScene.GB_H * s)
  local vw = vh * pw / ph

  -- the cards need the camera's eye to face it, so the rig has to be live
  -- before they are built; Voxel3D.eye is set by viewProjection, which
  -- beginScene calls -- so a provisional one is taken here for the sun pass
  -- and the real one is rebuilt inside the scene below.
  Voxel3D.camera = cam
  local provisionalVP = Voxel3D.viewProjection(cx, cy, vw, vh)
  local cards = monCards(arena, groundY, textures, host, provisionalVP)
  Voxel3D.camera = nil
  castShadows(state, arena, terrain, nbMesh, cx, cy, vw, vh, atlasFor,
              cards, token, host, neighbors, water, nbWater, groundY, horizon,
              screenBackdrop, portableBackdrop)

  -- An opaque void either way. Outdoors the camera is low enough that the
  -- horizon is genuinely in frame, so it is sky; indoors it is the dark end
  -- of the same ramp, which is a room's "past the wall". Transparent -- the
  -- free-roam default -- would let the letterbox clear through wherever the
  -- geometry stops.
  local mapSky = VoxelScene.skyColor(host, 1)
  local sky = mapSky or VoxelScene.skyShade(INDOOR_SHADE, 1)
  local diskBackground = discs and arena.diskStyle
      and V.require("VoxelBattleStage").diskBackgroundColor(arena) or nil
  -- FRLG-like DISCS deliberately use a near-white flat renderer clear tinted
  -- to their material.  It is not an authored backdrop and carries no image
  -- or sky bands; the later weather overlay still belongs to the live map.
  if diskBackground then sky = diskBackground end
  -- On a disc rung the void is not a backdrop behind the scenery -- it IS the
  -- scenery, because the map is not drawn. So outdoors it gets the full
  -- treatment the free-roam camera gets: the banded gradient and the hour's
  -- own sun or moon hanging in it (Voxel3D.beginScene paints those when the
  -- sky it is handed carries bands). Indoors there is nothing to dress: a
  -- room's void is one flat shade, which is what a room looks like past the
  -- wall, and the disc fight in a cave is lit and coloured as that cave.
  -- A canopy colour closes Viridian Forest's void, but is explicitly not an
  -- open sky: even a disc-only arena must not punch sun, moon, clouds or
  -- stars through the leaves.
  if discs and not diskBackground and mapSky and not mapSky.canopy then
    local Sky = V.require("Sky")
    local okDress, dressed = pcall(Sky.dress, sky)
    if okDress and dressed then sky = dressed end
  end

  -- Weather belongs to the arena map for the same reason as its palette and
  -- sky. Pass the already-resolved mode to both sky dressing and the final
  -- overlay so AUTO cannot roll differently within one frame. Indoors this
  -- is always clear, including disc fights staged in caves or buildings.
  local weatherMode, nativeGround = BattleScene.weatherMode(host)
  local groundWeather, groundAmount = BattleScene.groundWeather(
    host, weatherMode, nativeGround)

  Voxel3D.camera = cam
  -- the sun is turned up for the arena and put back afterwards, so the
  -- free-roam world it shares this module with keeps its own weight -- and
  -- the hour still has the last word: a sunset fades the arena's shadows
  -- out and the moon presses more softly, exactly as it does outside
  local sunWas = Voxel3D.SHADOW_ALPHA
  Voxel3D.SHADOW_ALPHA = BattleScene.SHADOW_ALPHA
                         * DayNight.shadowScale(outdoor)
  -- The battle has its own BTL GRID row. Apply it through the temporary
  -- override so the free-roam V-GRID choice is never rewritten.
  local gridWas = VoxelGrid.override
  VoxelGrid.override = VoxelGrid.battleEnabled()
  local out = nil
  local declineReason = nil
  local renderedCards = {}
  local ok, err = pcall(function()
    -- its own canvas slot: this renders at the window's pixel size and the
    -- free-roam pass does too, but the two are alive at different moments
    -- and a shared slot would reallocate on every battle entry and exit
    --
    -- AA, if the row asks for it, renders it larger still and folds it back
    -- to pw x ph below (see AntiAlias). The framing is untouched by that:
    -- the lens was widened by the window's RATIO to the letterbox and the
    -- rig solved in the GB's own frame, so a bigger canvas is more samples
    -- of the identical shot -- which is why the pins below still measure in
    -- pw and ph, and why the HUDs and the depth of field, drawn onto the
    -- folded canvas afterwards, stay the chunky GB art they are.
    local rw, rh = AntiAlias.expand(pw, ph)
    if not Voxel3D.beginScene(rw, rh, cx, cy, vw, vh, sky, "battle", {
      weather = weatherMode,
      groundWeather = groundWeather,
      groundAmount = groundAmount,
      mapId = host and host.id or nil,
      arena = discs and arena.arenaStyle and true or false,
      battleView = true,
    }) then
      declineReason = "begin-scene-declined"
      return
    end
    if discs then
      if arena.arenaStyle then
        if portableBackdrop then
          local Stage = V.require("VoxelBattleStage")
          local backdropDrawn, backdropReason = Stage.drawBackdrop(
            arena, outdoor, portableBackdrop)
          if not backdropDrawn then
            if backdropReason == "backdrop-selection-changed" then
              -- Stage rejected this custom selection. Close and discard the
              -- already-started scene: its camera and shadow receipts were
              -- computed for that bitmap, so the fallback must be selected
              -- before the next frame rather than mixed into this one.
              Voxel3D.endScene()
              declineReason = backdropReason
              return
            end
            if not Stage.customAddPortableFallback(arena) then
              error("ARENA backdrop draw failed", 0)
            end
          end
        end
      end
      -- discs: the two platforms, and nothing else. No terrain, no
      -- neighbouring maps, no water, no grass and no flowers -- see the
      -- matching skips further down. What is behind them is the sky the
      -- clear painted.
      -- A reviewed full-frame painting already contains its two grounded
      -- combat clearings.  The old generated platform would sit over it as a
      -- conspicuous pixel oval, so only legacy/plain disc stages draw here.
      if not V.require("VoxelBattleStage").hasAuthoredBackdrop(arena) then
        V.require("VoxelBattleStage").draw(arena, groundY)
      end
    else
      local surfaceWeather = Voxel3D.weatherGround(true) == true
      if panoramaReady then
        PanoramaBackdrop.drawAt(arena.mid[1], groundY, arena.mid[2], {
          weather=groundWeather, amount=groundAmount, outdoor=outdoor,
          surfaces=surfaceWeather,
        })
      end
    Voxel3D.draw(terrain, atlasFor(host), nil)
    for i, nb in ipairs(neighbors) do
      Voxel3D.draw(nbMesh[i], atlasFor(nb.map),
                   Mat4.translate(nb.ox, 0, nb.oy))
    end
    Voxel3D.weatherGround(false)
    -- The same compact panorama that closes the overworld union closes MAP
    -- battles. It is prepared before beginScene, so this pass only draws
    -- known-good meshes and a cold neighbour can never become a sky-coloured
    -- hole when BTL CAM widens to 2X or 3X.
    Voxel3D.glass(false)
    for _, rim in ipairs(horizon or {}) do
      if rim.kind ~= "water" then
        Voxel3D.draw(rim.mesh, rim.texture,
                     Mat4.translate(rim.ox, 0, rim.oy))
      end
    end
    Voxel3D.glass(true)
    -- and the water over it -- PLAIN, always: the flat animated tiles, never
    -- the reflective pass, whatever the WATER row says. The reflection is
    -- tuned for the overworld's ladder of cameras; this shot's is PLACED --
    -- low, tilted and framed like a picture -- and under it the pass reads
    -- wrong: Fresnel opens all the way up, the leaned sky lands on bands the
    -- framing never shows, and a lake-sized arena comes out as murk wearing
    -- the tile art. The battle is a stage set, and stage water is painted.
    -- (No mirror also means the mons need no second draw into one -- they
    -- just composite over the water below, like everything else on the set.)
    if water then Voxel3D.draw(water, atlasFor(host)) end
    for i, nb in ipairs(neighbors) do
      if nbWater and nbWater[i] then
        Voxel3D.draw(nbWater[i], atlasFor(nb.map),
                     Mat4.translate(nb.ox, 0, nb.oy))
      end
    end
    -- This texture is procedural rather than a tileset-atlas slot, so the
    -- host map's window mask has no meaningful coordinates on it.
    Voxel3D.glass(false)
    for _, rim in ipairs(horizon or {}) do
      if rim.kind == "water" then
        Voxel3D.draw(rim.mesh, rim.texture,
                     Mat4.translate(rim.ox, 0, rim.oy))
      end
    end
    Voxel3D.glass(true)
    end
    -- A full-frame painting owns the visible ground pixels and has no depth
    -- surface for ShadowMap to shade. Put the bounded soft contact ellipses
    -- onto that painting before the Pokemon themselves; OFF performs no draw.
    if screenBackdrop then
      drawBackdropShadows(cards, groundY, portableBackdrop)
    end
    -- The mons, standing on their tiles. Depth-tested like everything else,
    -- so a ledge or a tree between the camera and a Pokemon really is in
    -- front of it, and the alpha discard cuts the sprite's own outline out of
    -- the card. A small camera-ward pull keeps a card rooted to the ground
    -- plane from z-fighting the tile it is standing on.
    -- The engine's hit flash is a full-screen white rectangle, which on a
    -- white battle field is a flash and over a world is a whiteout of the
    -- map, the HUD and the text box alike. It is dropped on the way past
    -- (see OverworldBattle) and put back HERE, on the two things it was ever
    -- about: the mons themselves go solid white for those frames.
    local flashing = textures and textures.flash
    if flashing then
      Voxel3D.flatten(BattleScene.FLASH_COLOR, BattleScene.FLASH_STRENGTH)
    end
    -- and no voxel wireframe on the pair. Everything else in this frame is
    -- built a unit per voxel and wears the seams that fall out of that; a
    -- mon's card is one quad wearing the battle screen (see
    -- BattleBillboard), so it is off the grid and has no seams to draw.
    Voxel3D.seams(false)
    -- and no glass either: the cards wear the battle screen, not the
    -- tileset atlas, so the mask's coordinates mean nothing on them
    Voxel3D.glass(false)
    renderedCards = monCards(arena, groundY, textures, host,
                             Voxel3D.vp, Voxel3D.eye)
    withoutCardShadowReception(function()
      for _, card in ipairs(renderedCards) do
        -- The visible card keeps its authored colour. Its stable opponent-
        -- facing twin was submitted only as a caster/ground silhouette.
        Voxel3D.draw(BattleBillboard.mesh(), card.tex, card.model,
                     BattleBillboard.PULL, ShadowMap.snug(card.shadowModel))
      end
    end)
    Voxel3D.glass(true)
    Voxel3D.seams(true)
    local okModel, drawn, drawErr = pcall(function()
      return V.require("Stadium").draw(BattleBillboard.PULL)
    end)
    if not okModel or drawn == false then
      local okStadium, stadium = pcall(V.require, "Stadium")
      if okStadium and type(stadium.report) == "function" then
        pcall(stadium.report, drawErr or drawn)
      end
    end
    if flashing then Voxel3D.flatten(nil) end
    -- grass and flowers ride the same camera-ward pull the free-roam pass
    -- gives them, measured against THIS camera's pitch rather than the
    -- orbit's -- there is no character here for them to overdraw, but the
    -- pull is also what keeps a tuft from z-fighting the floor it stands on
    local pull = VoxelScene.pull(math.max(pitch, 0.05))
    if not discs then
      Voxel3D.weatherGrass(true)
      Voxel3D.draw(ChunkMesher.grass(host), atlasFor(host), nil, pull)
      for _, nb in ipairs(neighbors) do
        Voxel3D.draw(ChunkMesher.grass(nb.map), atlasFor(nb.map),
                     Mat4.translate(nb.ox, 0, nb.oy), pull)
      end
      Voxel3D.weatherGrass(false)
      local fpull = math.max(0, pull - 8 * math.sin(math.max(pitch, 0.05)))
      Voxel3D.draw(ChunkMesher.flowers(host), atlasFor(host), nil, fpull,
                   ShadowMap.snug(nil))
      for _, nb in ipairs(neighbors) do
        Voxel3D.draw(ChunkMesher.flowers(nb.map), atlasFor(nb.map),
                     Mat4.translate(nb.ox, 0, nb.oy), fpull,
                     ShadowMap.snug(Mat4.translate(nb.ox, 0, nb.oy)))
      end
    end
    -- Paint onto the expanded scene before AA resolves it, exactly like the
    -- overworld path. Rain/snow therefore keep the same pixel scale and fog
    -- or lightning cover the whole 3D shot without touching the engine HUD,
    -- which is composited later by OverworldBattle.
    local rendered = Voxel3D.endScene()
    rendered = BattleScene.applyWeather(rendered, rw, rh, host,
                                        Voxel3D.cell, weatherMode)
    local canvas = AntiAlias.resolve(rendered, pw, ph, "battle")
    if not canvas then
      declineReason = "anti-alias-resolve-pending"
      return
    end

    local vp = Voxel3D.vp
    local geometry = projectedArenaGeometry(
      arena, groundY, textures, host, vp, pw, ph, lx, ly, s)
    if not geometry then
      declineReason = "projected-geometry-unavailable"
      return
    end
    local actorVisuals = {}
    for _, card in ipairs(renderedCards) do
      local receipt = actorVisualForCard(card, vp, pw, ph, token)
      if receipt then actorVisuals[card.side] = receipt end
    end
    local okStadium, stadium = pcall(V.require, "Stadium")
    if okStadium and type(stadium) == "table"
        and type(stadium.visualReceipt) == "function" then
      for _, side in ipairs({ "player", "enemy" }) do
        local okReceipt, receipt = pcall(
          stadium.visualReceipt, side, vp, pw, ph, token)
        if okReceipt and type(receipt) == "table" then
          actorVisuals[side] = receipt
        end
      end
    end
    out = {
      canvas = canvas,
      player = geometry.player,
      enemy = geometry.enemy,
      playerSpan = geometry.playerSpan,
      enemySpan = geometry.enemySpan,
      -- Full-frame conservative envelopes are shared with the active HUD owner.
      -- They keep status/menu furniture away from the complete visible actors,
      -- while player/enemy above remain the historical GB-coordinate pins.
      actorHulls = geometry.actorHulls,
      actorFeet = geometry.actorFeet,
      actorVisuals = actorVisuals,
      renderToken = token,
      actorFit = actorFit,
      layoutContext = battleLayoutContext(arena, host),
      smartArenaComposition = geometry.layout
        and geometry.layout.smartArenaComposition or nil,
      -- the letterbox, so the depth-of-field pass can put its sharp band on
      -- the two marks rather than on a fraction of the window
      lx = lx, ly = ly, scale = s, pw = pw, ph = ph,
      -- and the hour's light, retained for optional non-geometry overlays and
      -- companion capability consumers. Battler front/rear cards themselves
      -- are geometry and already pass through this tint. Neutral indoors,
      -- which is what DayNight.tint answers for a room.
      tint = Voxel3D.tint,
    }
  end)
  -- the placed camera is ours for exactly this pass; anything else that
  -- renders (the free-roam pipeline, next frame) must find the orbit back
  Voxel3D.camera = nil
  Voxel3D.SHADOW_ALPHA = sunWas
  VoxelGrid.override = gridWas
  if not ok then
    -- endScene never ran, so the canvas is still bound and the shader still
    -- set; put the frame back the way it was found before rethrowing
    pcall(love.graphics.setShader)
    pcall(love.graphics.setDepthMode)
    pcall(love.graphics.setCanvas)
    error(err, 0)
  end
  if not out then
    BattleScene.lastDeclineReason = declineReason or "render-incomplete"
  end
  return out
end

return BattleScene
