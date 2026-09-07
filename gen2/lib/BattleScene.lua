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
local okPresentation, CanvasPresentation = pcall(V.require, "CanvasPresentation")
if not okPresentation then CanvasPresentation = {} end
local ShadowMap = V.require("ShadowMap")
local Shadows = V.require("Shadows")
local ChunkMesher = V.require("ChunkMesher")
local TerrainAtlas = V.require("TerrainAtlas")
local VoxelScene = V.require("VoxelScene")
local BattleCam = V.require("BattleCam")
local BattleCinematic = V.require("BattleCinematic")
local BattleBillboard = V.require("BattleBillboard")
local VoxelGrid = V.require("VoxelGrid")
local DayNight = V.require("DayNight")
local Weather = V.require("Weather")
-- local UiBackplates = V.require("UiBackplates")
local AntiAlias = V.require("AntiAlias")
local PaletteFX = require("src.render.PaletteFX")
local Map = require("src.world.gen2.Map")

local BattleScene = {}

-- Gen-2's native 56px cards read substantially larger in every full-window
-- voxel battle than the equivalent Kanto composition.  Apply one neutral
-- parity factor before the optional authored/profile adjustments, so MAP,
-- ARENA and DISCS cannot drift back to three unrelated Pokemon/trainer sizes.
BattleScene.GEN2_ACTOR_SCALE = 0.78

-- Optional shared editor/profile contract.  Resolve lazily: focused Gen-2
-- geometry tests intentionally provide a tiny V facade, while the real
-- runtime always exposes BattleLayout through the generation dispatcher.
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
  local host = map or (type(arena) == "table" and arena.map or nil)
  local mode = type(arena) == "table" and arena.presentationMode or nil
  if mode ~= "MAP" and mode ~= "ARENA" and mode ~= "DISCS" then
    mode = type(arena) == "table" and arena.arenaStyle and "ARENA"
      or type(arena) == "table" and arena.discs and "DISCS" or "MAP"
  end
  return { mapID=host and tostring(host.id or host) or nil,
           stageID=host and tostring(host.id or host) or nil,
           mode=mode }
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
BattleScene.SHADOW_ALPHA = 0.38

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
  local pw, ph = BattleScene.pixelSize()
  -- Game2 owns its own frame fit and never goes through src/render/Renderer.
  -- Use the live Gold owner's exact integer fit when available.
  if V.game and type(V.game.frameFit) == "function" then
    local ok, s, ox, oy = pcall(V.game.frameFit, V.game, pw, ph)
    if ok and tonumber(s) and tonumber(s) > 0 then
      return tonumber(ox) or math.floor((pw - BattleScene.GB_W * s) / 2),
             tonumber(oy) or math.floor((ph - BattleScene.GB_H * s) / 2),
             tonumber(s), pw, ph
    end
  end
  local okR, Renderer = pcall(require, "src.render.Renderer")
  local s = okR and Renderer and Renderer.fitScale and Renderer:fitScale()
  s = tonumber(s) or math.max(1, math.floor(math.min(pw / 160, ph / 144)))
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
  -- Gold's CGB colours are already baked into its tileset atlas and the
  -- standalone free-roam voxel bridge passes no SGB palette callback. Match
  -- that path here instead of calling Gen-1-only state:paletteNameFor().
  if V.game and V.game.world then return function() return nil end end
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
  if host == state.map then return VoxelScene.prefetch(state) end
  local live = { [host.id] = true, [state.map.id] = true }
  for _, nb in ipairs(state.neighbors or {}) do live[nb.map.id] = true end
  ChunkMesher.setLive(live)
  TerrainAtlas.setLive(live)
  ChunkMesher.request(host, false, nil, true)
  local terrain, water = ChunkMesher.pair(host, false)
  if not terrain then terrain, water = ChunkMesher.pair(host, true) end
  return terrain, {}, water, {}
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
-- `mirror` follows the same concrete view contract as the Gen-I renderer and
-- Battlemap Editor: fronts intrinsically face left, certified full-body backs
-- face right, and an explicit profile/user flip is absolute.
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
  if side == "player" and tex.trainer == true then return false end
  return side == "player"
end

local function monMatrix(tex, x, groundY, z, mirror, actorScale)
  local captureW = tonumber(tex.captureW) or BattleScene.GB_W
  local captureH = tonumber(tex.captureH) or BattleScene.GB_H
  local k = tonumber(tex.pixelWorld)
    or BattleBillboard.FULL_W / BattleBillboard.FULL_PIC
  k = k * math.max(.25, tonumber(actorScale) or 1)
  local w = captureW * k
  local h = captureH * k
  local ox = -(((tonumber(tex.ax) or captureW * 0.5) / captureW) - 0.5) * w
  -- `ay` is the cartridge slot baseline, not necessarily the visible foot.
  -- Crystal bottom-aligns small sprites inside that slot and HD/front/back
  -- replacements can have still more transparent padding.  Hanging the full
  -- capture from ay therefore leaves the actual ink floating above the arena
  -- floor.  The capture provider already publishes the exact alpha hull; pin
  -- its lower edge to groundY so Pokémon and trainers stand on the analysed
  -- floor mark regardless of species, sprite source or current pose.
  local visualBox = type(tex.visualBox) == "table" and tex.visualBox or nil
  local visibleBottom = visualBox and tonumber(visualBox[2])
    and tonumber(visualBox[4]) and (visualBox[2] + visualBox[4]) or nil
  if not (visibleBottom and visibleBottom == visibleBottom
      and visibleBottom >= 0 and visibleBottom <= captureH) then
    visibleBottom = tonumber(tex.ay) or captureH
  end
  local oy = -((captureH - visibleBottom) / captureH) * h
  local yaw = BattleBillboard.yawToward(x, z, Voxel3D.eye)
  local card = Mat4.mul(Mat4.translate(ox, oy, 0), Mat4.scale(w, h, 1))
  if mirror then card = Mat4.mul(Mat4.scale(-1, 1, 1), card) end
  return Mat4.mul(Mat4.mul(Mat4.translate(x, groundY, z), Mat4.rotateY(yaw)),
                  card)
end

function BattleScene.worldAtNormalized(vp, normalizedX, normalizedY, worldY)
  if type(vp) ~= "table" then return nil end
  local nx, ny = tonumber(normalizedX), tonumber(normalizedY)
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

local lastPresentation = setmetatable({}, { __mode="k" })
-- ARENA paintings stay fixed in screen space while Intro, Menu and SMART use
-- different cameras.  Cache their analysed *screen* foot marks, never the
-- derived world coordinates: freezing a world coordinate from the intro
-- camera makes the visible foot climb off the painted floor as soon as SMART
-- changes the view.  MAP/DISCS never enter this cache and retain their real
-- world/map anchors.
local arenaScreenAnchors = setmetatable({}, { __mode="k" })

local function arenaScreenComposition(stage, arena, trainer)
  if not (type(arena) == "table" and arena.arenaStyle
      and type(stage.presentationComposition) == "function") then return nil end
  local cache = arenaScreenAnchors[arena]
  if not cache then
    cache = {}
    arenaScreenAnchors[arena] = cache
  end
  local family = trainer and "trainer" or "pokemon"
  if cache[family] ~= nil then return cache[family] or nil end
  local composition = stage.presentationComposition(arena, trainer == true)
  local player = composition and composition.player
  local enemy = composition and composition.enemy
  if not (type(player) == "table" and type(enemy) == "table"
      and tonumber(player.x) and tonumber(player.y)
      and tonumber(enemy.x) and tonumber(enemy.y)
      and math.abs(enemy.x - player.x) >= .27) then
    cache[family] = false
    return nil
  end
  cache[family] = {
    player={ x=player.x, y=player.y },
    enemy={ x=enemy.x, y=enemy.y },
    source=composition.source or "bitmap-analysis",
  }
  return cache[family]
end

-- One provider-neutral actor layout shared by bitmap composition, imported
-- BattleLayout profiles, the actual cards and SMART's candidate safety pass.
function BattleScene.presentationLayout(arena, groundY, textures, map, vp)
  local stage = V.require("VoxelBattleStage")
  local baseScale = type(stage.presentationScale) == "function"
    and stage.presentationScale(arena) or 1
  baseScale = baseScale * BattleScene.GEN2_ACTOR_SCALE
  local context = battleLayoutContext(arena, map)
  local controller = battleLayout()
  local layout = { actorScale={}, profilePosition={}, layoutContext=context }
  vp = vp or Voxel3D.vp
  for _, side in ipairs({ "player", "enemy" }) do
    local tex = textures and textures[side]
    local x, y, z = stage.presentationPosition(
      arena, side, groundY, tex and tex.trainer == true)
    if x then
      local adjustment = { x=0, y=0, scale=1 }
      if controller and type(controller.actorAdjustment) == "function" then
        local ok, value = pcall(controller.actorAdjustment, side, tex,
          { worldInkWidth=BattleScene.CELL,
            worldInkHeight=BattleScene.CELL * 2 }, context)
        if ok and type(value) == "table" then adjustment = value end
      end
      local normalizedX = tonumber(adjustment.normalizedX)
      local normalizedY = tonumber(adjustment.normalizedY)
      if (normalizedX or normalizedY) and vp then
        local currentX, currentY = normalizedProjection(vp, x, y, z)
        normalizedX, normalizedY = normalizedX or currentX,
          normalizedY or currentY
        local authoredX, authoredZ = BattleScene.worldAtNormalized(
          vp, normalizedX, normalizedY, y)
        if authoredX and authoredZ then
          x, z = authoredX, authoredZ
          layout.profilePosition[side] = true
        end
      end
      local factor = tonumber(adjustment.scale) or 1
      if not (factor == factor and factor > 0 and factor < math.huge) then
        factor = 1
      end
      layout[side] = {
        x + (tonumber(adjustment.x) or 0),
        y - (tonumber(adjustment.y) or 0), z,
      }
      layout.actorScale[side] = baseScale * factor
    end
  end

  -- Analyse the exact loaded bitmap once.  The analyzer publishes only a
  -- conservative open-ground pair; it does not claim semantic knowledge of
  -- trees or platforms. Imported explicit positions win over this fallback.
  -- The normalized feet stay immutable; their world coordinates are resolved
  -- against the *current* VP so a moving camera cannot detach a card from the
  -- fixed painting. Trainer and Pokemon marks remain separate.
  if arena and arena.arenaStyle and vp then
    for _, side in ipairs({ "player", "enemy" }) do
      local tex = textures and textures[side]
      local composition = arenaScreenComposition(
        stage, arena, tex and tex.trainer == true)
      local mark = composition and composition[side]
      if mark and layout[side] and not layout.profilePosition[side] then
        local x, z = BattleScene.worldAtNormalized(
          vp, mark.x, mark.y, layout[side][2])
        if x and z then
          layout[side][1], layout[side][3] = x, z
          layout.smartArenaComposition = composition.source
        end
      end
    end
  end
  if type(arena) == "table" then lastPresentation[arena] = layout end
  return layout
end

-- Every mon that has something to show this frame, as (texture, matrix).
local function monCards(arena, groundY, textures, map, vp)
  local out = {}
  if not textures then return out end
  local layout = BattleScene.presentationLayout(arena, groundY, textures,
                                                 map, vp)
  for _, side in ipairs({ "enemy", "player" }) do
    local tex = textures[side]
    local position = layout[side]
    if tex and tex.canvas and position then
      local mirror = BattleScene.textureFlipX(side, tex)
      local captureW = tonumber(tex.captureW) or BattleScene.GB_W
      local box = type(tex.visualBox) == "table" and tex.visualBox or nil
      local inkPixels = box and tonumber(box[3]) or captureW
      local pixelWorld = tonumber(tex.pixelWorld)
        or BattleBillboard.FULL_W / BattleBillboard.FULL_PIC
      local inkWidth = math.max(1, inkPixels) * pixelWorld
        * (layout.actorScale[side] or 1)
      local contactRadiusX = math.max(2.5, math.min(7.5, inkWidth * .28))
      local contactRadiusZ = math.max(1.8,
        math.min(4.2, contactRadiusX * .58))
      out[#out + 1] = { side=side, tex = tex.canvas, source=tex,
                        shadowFoot={ position[1], position[2], position[3] },
                        shadowRadius={ contactRadiusX, contactRadiusZ },
                        model = monMatrix(tex, position[1], position[2],
                                          position[3], mirror,
                                          layout.actorScale[side]) }
    end
  end
  return out
end

BattleScene.monCards = monCards

-- A panorama owns only painted floor pixels, so ShadowMap has no receiver for
-- a Pokemon silhouette.  Draw a bounded, feathered world-space contact oval
-- before each card.  Its exact foot is the same normalized ARENA mark used by
-- the card; MAP and DISCS retain their physical shadow receivers instead.
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
  if type(Shadows.enabled) == "function" and not Shadows.enabled() then return 0 end
  local mesh = backdropShadowMesh()
  if not (mesh and opaqueBackdrop) then return 0 end
  local drawn = 0
  local savedAlpha = tonumber(Voxel3D.SHADOW_ALPHA) or BattleScene.SHADOW_ALPHA
  local eps = tonumber(Voxel3D.SHADOW_EPS) or .25
  Voxel3D.seams(false)
  Voxel3D.glass(false)
  local ok, err = pcall(function()
    for _, card in ipairs(cards or {}) do
      local foot, radius = card.shadowFoot, card.shadowRadius
      local x, y, z = foot and tonumber(foot[1]), foot and tonumber(foot[2]),
                      foot and tonumber(foot[3])
      local rx, rz = radius and tonumber(radius[1]), radius and tonumber(radius[2])
      if x and z and rx and rz and rx > 0 and rz > 0 then
        y = y or tonumber(groundY) or 0
        local eye = Voxel3D.eye
        local dx = type(eye) == "table" and tonumber(eye[1]) and eye[1] - x or 0
        local dz = type(eye) == "table" and tonumber(eye[3]) and eye[3] - z or 0
        local distance = math.sqrt(dx * dx + dz * dz)
        if distance > 1e-6 then
          x = x + dx / distance * rz * .35
          z = z + dz / distance * rz * .35
        end
        for _, layer in ipairs(BACKDROP_SHADOW_LAYERS) do
          local model = Mat4.mul(Mat4.translate(x, y + eps, z),
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

local function projectedModelPoint(mvp, x, y, pw, ph)
  local cx = mvp[1] * x + mvp[2] * y + mvp[4]
  local cy = mvp[5] * x + mvp[6] * y + mvp[8]
  local cw = mvp[13] * x + mvp[14] * y + mvp[16]
  if not (cw and cw > 1e-9) then return nil end
  return (cx / cw * .5 + .5) * pw,
         (cy / cw * .5 + .5) * ph
end

-- Project the exact alpha/ink box already published by goldSideTexture
-- through the very same billboard matrix drawn below.  The old actorVisuals
-- reused the 16x40 camera-safety prism; that prism intentionally extends far
-- above a small Crystal sprite and made a genuinely head-owned HP card look
-- like a fixed top-corner HUD.  Collision safety keeps its conservative hull
-- separately in actorHulls; this receipt describes only visible pixels.
local function actorVisualForCard(card, vp, pw, ph, renderToken)
  local source = card and card.source
  local box = type(source) == "table" and source.visualBox or nil
  local cw = type(source) == "table" and tonumber(source.captureW) or nil
  local ch = type(source) == "table" and tonumber(source.captureH) or nil
  if not (card and card.model and type(box) == "table"
      and cw and cw > 0 and ch and ch > 0
      and tonumber(box[1]) and tonumber(box[2])
      and tonumber(box[3]) and tonumber(box[4])
      and box[3] > 0 and box[4] > 0) then return nil end
  local x0 = box[1] / cw - .5
  local x1 = (box[1] + box[3]) / cw - .5
  local y0 = 1 - box[2] / ch
  local y1 = 1 - (box[2] + box[4]) / ch
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
    hull={ left, top, right-left, bottom-top },
    head={ x=(left+right)*.5, y=top },
    foot={ x=(left+right)*.5, y=bottom },
    battler=source.vascRenderBattler,
    mon=source.vascRenderMon,
    modelKey=source.vascRenderModelKey,
    inkIdentity=source.inkIdentity,
    textureToken=source.vascRenderTextureToken or source.canvas,
    canvas=source.canvas,
    view=source.vascSpriteView,
    viewportW=pw, viewportH=ph,
  }
end

local function stadiumActorVisual(side, vp, pw, ph, renderToken)
  local ok, stadium = pcall(V.require, "Stadium")
  if not (ok and type(stadium) == "table"
      and type(stadium.visualReceipt) == "function") then return nil end
  local receiptOk, receipt = pcall(
    stadium.visualReceipt, side, vp, pw, ph, renderToken)
  if receiptOk and type(receipt) == "table" then return receipt end
  return nil
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
  local layout = lastPresentation[arena]
  local player = layout and layout.player
  local enemy = layout and layout.enemy
  local Px, Py, Pz = player and player[1], player and player[2],
    player and player[3]
  local Ex, Ey, Ez = enemy and enemy[1], enemy and enemy[2],
    enemy and enemy[3]
  if not (Px and Ex) then
    Px, Py, Pz = stage.presentationPosition(arena, "player", groundY)
    Ex, Ey, Ez = stage.presentationPosition(arena, "enemy", groundY)
  end
  if not (Px and Ex) then return nil end
  local s = (BattleBillboard.FULL_W / BattleBillboard.FULL_PIC)
    * (type(stage.presentationScale) == "function"
       and stage.presentationScale(arena) or 1)
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
local function shadowSignature(state, arena, terrain, nbMesh, token)
  local host = arena.map or state.map
  -- `turn` is in the signature with the corner and the shape: the same corner
  -- turned a quarter is a different footprint standing on different ground,
  -- and a cast kept from the other one freezes the shadows across it
  local parts = { "battle", host.id, arena.x, arena.y, arena.shape,
                  tostring(arena.turn or 0),
                  tostring(terrain), tostring(token or 0),
                  -- the cycle keeps running through a fight, and an arena lit
                  -- from somewhere new must be re-cast from there
                  math.floor(ShadowMap.KX * 128),
                  math.floor(ShadowMap.KZ * 128) }
  for i = 1, #nbMesh do parts[#parts + 1] = tostring(nbMesh[i]) end
  return table.concat(parts, ",")
end

local function castShadows(state, arena, terrain, nbMesh, cx, cy, vw, vh,
                           atlasFor, cards, token, host, neighbors,
                           water, nbWater, groundY)
  if not ShadowMap.available() then return end
  local sig = shadowSignature(state, arena, terrain, nbMesh, token)
  if not ShadowMap.stale(sig) then return end
  if not ShadowMap.begin(cx, cy, vw, vh) then return end

  -- A DISC RUNG: the two discs are the only ground there is, so they are the
  -- only stage geometry the sun has to see. A map rung instead contributes its
  -- terrain, water and flowers. The Pokemon cards and Stadium actors below are
  -- shared by both paths and must be cast exactly once before the pass commits.
  if arena.discs then
    pcall(function()
      V.require("StadiumStage").cast(ShadowMap, arena, groundY or 0)
    end)
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
    -- thin cards are snugged toward the sun (ShadowMap.snug) so their shadows
    -- keep contact with their bases instead of starting a bias-width away
    ShadowMap.draw(ChunkMesher.flowers(host), atlasFor(host),
                   ShadowMap.snug(nil))
    for _, nb in ipairs(neighbors) do
      ShadowMap.draw(ChunkMesher.flowers(nb.map), atlasFor(nb.map),
                     ShadowMap.snug(Mat4.translate(nb.ox, 0, nb.oy)))
    end
  end

  -- the mons themselves, as the same cards the camera will see. Their alpha
  -- is the silhouette, so what lands on the ground is the shape of the
  -- Pokemon rather than a blob standing in for one.
  -- marked as the CAST, so a fight staged at the water's edge does not lay a
  -- cut-out of a Pokemon across the lake (see ShadowMap.sprites); the arena's
  -- own floor still takes them, which is the shadow that matters here
  ShadowMap.sprites(true)
  for _, card in ipairs(cards or {}) do
    ShadowMap.draw(BattleBillboard.mesh(), card.tex,
                   ShadowMap.snug(card.model))
  end
  ShadowMap.sprites(false)
  -- and the STADIUM models, when that rung is the one running. NOT marked
  -- as sprites: that flag exists so a flat card's cut-out is kept off the
  -- water (see ShadowMap.sprites), and these are real geometry standing in
  -- the world -- a Gyarados at the water's edge should put a Gyarados on
  -- the water. Un-snugged for the same reason: snug is a bias for a card
  -- rooted to the ground plane, and a model has thickness of its own.
  pcall(function() V.require("Stadium").cast(ShadowMap) end)

  ShadowMap.finish(sig)
end

-- Flat battle cards cast onto the physical MAP/DISCS floor, but sampling the
-- same packed depth while drawing the visible card makes tiny precision
-- differences darken the illustration itself. Suppress only that compare and
-- always restore it; terrain, platforms and Stadium geometry remain ordinary
-- receivers throughout the frame.
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
  -- Dynamic/author-authenticated Gen-2 arenas carry the complete footprint's
  -- checked floor, not merely one combatant cell. Reusing it here prevents a
  -- later map read from lowering the actors into the recess the selector just
  -- rejected.
  if arena and tonumber(arena.anchorHeight) then
    return tonumber(arena.anchorHeight)
  end
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

-- Conservative full-viewport projection used by Gen-2 SMART before it
-- commits a moving camera.  Future arena packs are deliberately not named
-- here: the contract describes the two actual battle marks and the live
-- camera, so it remains valid for replacement maps and portable stages.
BattleScene.CAMERA_SAFE_ACTOR_RADIUS = 16
BattleScene.CAMERA_SAFE_ACTOR_HEIGHT = 40

local function projectedPixel(vp, wx, wy, wz, pw, ph)
  local cx = vp[1] * wx + vp[2] * wy + vp[3] * wz + vp[4]
  local cy = vp[5] * wx + vp[6] * wy + vp[7] * wz + vp[8]
  local cz = vp[9] * wx + vp[10] * wy + vp[11] * wz + vp[12]
  local cw = vp[13] * wx + vp[14] * wy + vp[15] * wz + vp[16]
  if cw <= 1e-6 then return nil end
  local nz = cz / cw
  if nz < -1.05 or nz > 1.05 then return nil end
  return (cx / cw * 0.5 + 0.5) * pw,
         (cy / cw * 0.5 + 0.5) * ph
end

function BattleScene.projectedActorHull(vp, x, y, z, pw, ph,
                                         radius, height)
  radius = math.max(4, tonumber(radius)
    or BattleScene.CAMERA_SAFE_ACTOR_RADIUS)
  height = math.max(8, tonumber(height)
    or BattleScene.CAMERA_SAFE_ACTOR_HEIGHT)
  local left, top, right, bottom
  -- A battle card continually yaws toward the lens.  Its exact plane changes
  -- with the candidate, so project the complete conservative prism instead
  -- of guessing one billboard bearing.
  for _, ox in ipairs({ -radius, radius }) do
    for _, oz in ipairs({ -radius, radius }) do
      for _, oy in ipairs({ 0, height }) do
        local px, py = projectedPixel(vp, x + ox, y + oy, z + oz, pw, ph)
        if not px then return nil end
        left = left and math.min(left, px) or px
        right = right and math.max(right, px) or px
        top = top and math.min(top, py) or py
        bottom = bottom and math.max(bottom, py) or py
      end
    end
  end
  local fx, fy = projectedPixel(vp, x, y, z, pw, ph)
  local hx, hy = projectedPixel(vp, x, y + height, z, pw, ph)
  if not (fx and hx) then return nil end
  return { left, top, right - left, bottom - top },
         { fx, fy }, { x=hx, y=hy }
end

-- Read-only shot receipt for HUD-safe camera candidate evaluation.  This
-- mirrors Voxel3D.viewProjection's placed-camera branch but neither binds a
-- canvas nor mutates the renderer globals, so several recovery candidates can
-- be judged safely in one update.
function BattleScene.cameraSafetyShot(arena, groundY, camera, textures, map,
                                      renderToken)
  if not (arena and type(arena.player) == "table"
      and type(arena.enemy) == "table" and type(camera) == "table"
      and type(camera.eye) == "table" and type(camera.focus) == "table"
      and tonumber(camera.fov)) then return nil end
  local _, _, _, pw, ph = BattleScene.letterbox()
  pw, ph = tonumber(pw), tonumber(ph)
  if not (pw and ph and pw > 0 and ph > 0) then return nil end
  local eye, focus = camera.eye, camera.focus
  local dx = (eye[1] or 0) - (focus[1] or 0)
  local dy = (eye[2] or 0) - (focus[2] or 0)
  local dz = (eye[3] or 0) - (focus[3] or 0)
  local distance = math.max(1, math.sqrt(dx * dx + dy * dy + dz * dz))
  local projection = Mat4.perspective(camera.fov, pw / ph,
    math.max(1, distance * 0.05), distance * 4 + 4096)
  projection = Mat4.mul(Mat4.scale(1, -1, 1), projection)
  local vp = Mat4.mul(projection,
    Mat4.lookAt(eye, focus, camera.up or { 0, 1, 0 }))
  local shot = {
    schema="voxel-ascendant/gen2-camera-safety/v1",
    pw=pw, ph=ph, vp=vp, actorHulls={}, actorFeet={}, actorVisuals={},
    layoutContext=battleLayoutContext(arena, arena and arena.map),
  }
  local controller = battleLayout()
  if controller and type(controller.profileFor) == "function" then
    local okProfile, profile = pcall(controller.profileFor,
      shot.layoutContext)
    local safe = okProfile and type(profile) == "table"
      and profile.referenceViewport and profile.referenceViewport.safeArea
    if type(safe) == "table" then
      shot.profileSafeArea = {
        top=tonumber(safe.top) or 0,
        leading=tonumber(safe.leading) or 0,
        bottom=tonumber(safe.bottom) or 0,
        trailing=tonumber(safe.trailing) or 0,
      }
    end
  end
  groundY = tonumber(groundY) or 0
  local host = map or (arena and arena.map)
  local layout = BattleScene.presentationLayout(
    arena, groundY, textures, host, vp)
  shot.smartArenaComposition = layout.smartArenaComposition
  local exact = {}
  if textures then
    for _, card in ipairs(monCards(arena, groundY, textures, host, vp)) do
      local receipt = actorVisualForCard(
        card, vp, pw, ph, renderToken)
      if receipt then exact[card.side] = receipt end
    end
  end
  for _, side in ipairs({ "player", "enemy" }) do
    local mark = layout[side]
    if not mark then return nil end
    local hull, foot, head = BattleScene.projectedActorHull(
      vp, tonumber(mark[1]) or 0, tonumber(mark[2]) or groundY,
      tonumber(mark[3]) or 0,
      pw, ph)
    if not hull then return nil end
    shot.actorHulls[side], shot.actorFeet[side] = hull, foot
    shot.actorVisuals[side] = stadiumActorVisual(
      side, vp, pw, ph, renderToken) or exact[side]
      or { hull=hull, foot={x=foot[1], y=foot[2]}, head=head }
  end
  return shot
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
  local Game = V.game or require("src.core.Game")
  local ow = Game and (Game.world or Game.overworld)
  local top = Game and Game.stack and Game.stack:top()
  -- during the wipe INTO a battle the overworld can still be the one
  -- drawing, and it is ticking the clock itself; two ticks in a frame would
  -- run the water at double speed
  if top and ow and top == ow then return end
  pcall(require("src.render.TileRenderer").tick)
end

function BattleScene.render(state, arena, textures, token)
  if not (state and state.map and arena) then return nil end
  if not Voxel3D.available() then return nil end
  tickTiles()

  -- the floor the fight is staged on: normally the player's own, sometimes
  -- another floor of the same cave or building (see BattleArena)
  local host = arena.map or state.map
  local neighbors = (host == state.map) and (state.neighbors or {}) or {}

  -- the hour's light reaches the arena exactly as it reaches free-roam: the
  -- shared rig follows the clock on an outdoor floor and stays at noon on an
  -- indoor one, and the same tint multiplies the staged shot -- with the
  -- same window glass on whatever buildings stand in the background
  local outdoor = type(Weather.isOutdoor) == "function"
                  and Weather.isOutdoor(host)
                  or (host.def and Map.isOutdoor(host.def) or false)
  local stage = V.require("VoxelBattleStage")
  local painting = arena.painting == true
    and type(stage.hasAuthoredBackdrop) == "function"
    and stage.hasAuthoredBackdrop(arena)
  local panorama = arena.panoramaBackdrop == true
    and type(arena.backdropSpec) == "table"
  local skyPolicy = type(stage.skyPolicy) == "function"
    and stage.skyPolicy(arena)
    or { voxelSky=false, skyAperture=nil, source="stage-policy-missing" }
  local openSky = (painting or panorama) and skyPolicy.voxelSky == true
  local skyExposed = outdoor or openSky
  DayNight.applyRig(skyExposed)
  local weatherMode = type(Weather.mode) == "function"
                      and Weather.mode(host) or "clear"
  local skyWeatherMode, nativeGround = weatherMode, true
  if type(Weather.skyState) == "function" then
    skyWeatherMode, nativeGround = Weather.skyState(host)
  end
  local arenaSky, arenaSkyResolver
  if painting then
    local okResolver, resolver = pcall(V.require, "Gen2ArenaSkyResolver")
    if okResolver and type(resolver) == "table"
        and type(resolver.resolve) == "function" then
      local okPolicy, resolved = pcall(
        resolver.resolve, arena, outdoor, skyWeatherMode, skyPolicy)
      if okPolicy and type(resolved) == "table" then
        arenaSkyResolver = resolver
        arenaSky = resolved
        skyExposed = resolved.celestial == true
        skyWeatherMode = resolved.skyWeather or "clear"
      end
    end
  end
  -- a canopy floor (Viridian Forest) fights under the hour's tint too,
  -- with the rig and the void exactly as they were
  Voxel3D.tint = DayNight.tint(skyExposed or DayNight.isCanopy(host))
  local GlassMask = V.require("GlassMask")
  Voxel3D.glassMask = outdoor and GlassMask.texture(host.tileset) or nil
  Voxel3D.glassNight = outdoor and DayNight.windowLight() or 0
  -- no glint in the arena: the drift is the shot breathing, not the player
  -- moving, and a shimmer on background windows would fight the mons
  Voxel3D.glassGlint = 0
  -- the host floor's atmosphere reaches the staged shot at HALF density --
  -- a fight in Viridian Forest sits in the same haze the walk there did,
  -- thinned so neither mon goes soft -- and its god rays stay out of it:
  -- this camera is low and long, and a bright blade across a combatant
  -- reads as a rendering fault, not weather. nil almost everywhere.
  -- local ForestAtmos = V.require("ForestAtmos")
  -- local atmos = ForestAtmos.frame(host)
  -- Voxel3D.fog = atmos and { color = atmos.fog.color,
  --                           density = atmos.fog.density * 0.5,
  --                           start = atmos.fog.start,
  --                           heightK = atmos.fog.heightK } or nil

  -- A B RUNG stands the fight on two carried discs against the sky, with no
  -- map in the shot at all (see StadiumStage). Everything below still runs --
  -- the letterbox, the camera solve, the sun, the pins, the tint, the depth
  -- of field -- because none of it is about the terrain; what changes is
  -- which geometry the two passes draw.
  local discs = arena.discs and true or false

  -- Load and inspect a portable painting before camera/layout construction.
  -- Missing files or wrong dimensions decline the 3D override for this frame,
  -- leaving Gold's complete native battle visible instead of a white stage.
  local portableBackdrop
  if painting or panorama then
    portableBackdrop = stage.backdropFor(arena, skyExposed)
    if not portableBackdrop and painting then return nil end
    if not portableBackdrop then panorama = false end
    -- backdropFor performs the one-time alpha scan; refresh the read-only
    -- policy so Sky/SkyEvents receive its conservative aperture immediately.
    if type(stage.skyPolicy) == "function" then
      skyPolicy = stage.skyPolicy(arena)
    end
    if painting and arenaSkyResolver then
      local okPolicy, resolved = pcall(arenaSkyResolver.resolve,
        arena, outdoor, weatherMode, skyPolicy)
      if okPolicy and type(resolved) == "table" then
        arenaSky = resolved
        openSky = resolved.voxelSky == true
        skyExposed = resolved.celestial == true
        skyWeatherMode = resolved.skyWeather or "clear"
      end
    end
  end

  -- shares the free-roam mode's request/evict bookkeeping, so a battle warms
  -- exactly the meshes walking around would have and nothing extra
  local terrain, nbMesh, water, nbWater
  if painting then
    nbMesh, water, nbWater = {}, nil, {}
  else
    terrain, nbMesh, water, nbWater = prefetchArena(state, host)
  end
  if discs then
    -- and nothing is meshed for a disc fight, which is the other half of why
    -- the rung works everywhere: there is no waiting for a chunk to build, so
    -- the first frame of the first battle on a cold map is the finished shot
    nbMesh, water, nbWater = {}, nil, {}
  elseif not painting then
    if not terrain then return nil end
  end

  local lx, ly, s, pw, ph = BattleScene.letterbox()
  if not (pw > 0 and ph > 0 and s > 0) then return nil end

  local palette = paletteFor(state, host)
  local function atlasFor(map)
    return TerrainAtlas.forMap(map, VoxelScene._modeColors(palette, map))
  end

  local groundY = BattleScene.groundY(host, arena)
  local cam, pitch = BattleCam.rig(arena, groundY)
  local cx, cy = arena.mid[1], arena.mid[2]
  local smartCam, smartCx, smartCy = BattleCinematic.frame()
  local cinematic = smartCam and smartCam.eye and smartCam.focus
  if cinematic then
    -- MAP already uses this exact action-aware director through VoxelScene.
    -- ARENA and DISCS used to stop at BattleCam.rig(), making SMART appear to
    -- do nothing on two of the three selectable battle surfaces.  Portable
    -- stages now consume the same battle-start-latched camera and focus.
    cam = smartCam
    cx, cy = tonumber(smartCx) or cx, tonumber(smartCy) or cy
    local ex = (cam.eye[1] or 0) - (cam.focus[1] or 0)
    local ey = (cam.eye[2] or 0) - (cam.focus[2] or 0)
    local ez = (cam.eye[3] or 0) - (cam.focus[3] or 0)
    pitch = math.atan2(math.sqrt(ex * ex + ez * ez), math.max(1e-3, ey))
  else
    -- The authored static rig's FOV describes Gold's 160x144 frame. Widen it
    -- for the extra window area. The cinematic rig is already authored for
    -- the full live-world viewport and must not be widened a second time.
    cam.fov = BattleScene.letterboxFov(cam.fov, ph, s)
  end
  -- the world extents the sun frustum is fitted to; the camera itself is
  -- framed by cam.fov, so these only have to describe the ground in shot
  -- the player's zoom is part of this: the sun's box is fitted to what the
  -- frame holds, so a shot pulled wide has to light the ground it just
  -- brought into view rather than the ground the rig alone would have
  local vh
  if cinematic then
    local ex = (cam.eye[1] or 0) - (cam.focus[1] or 0)
    local ey = (cam.eye[2] or 0) - (cam.focus[2] or 0)
    local ez = (cam.eye[3] or 0) - (cam.focus[3] or 0)
    local distance = math.max(2, math.sqrt(ex * ex + ey * ey + ez * ez))
    vh = 2 * distance * math.tan((tonumber(cam.fov) or math.rad(55)) * 0.5)
  else
    vh = BattleCam.frameH(arena) * ph / (BattleScene.GB_H * s)
  end
  local vw = vh * pw / ph

  -- the cards need the camera's eye to face it, so the rig has to be live
  -- before they are built; Voxel3D.eye is set by viewProjection, which
  -- beginScene calls -- so a provisional one is taken here for the sun pass
  -- and the real one is rebuilt inside the scene below.
  Voxel3D.camera = cam
  Voxel3D.viewProjection(cx, cy, vw, vh)
  local cards = monCards(arena, groundY, textures, host, Voxel3D.vp)
  Voxel3D.camera = nil
  if not painting
      and (type(Shadows.enabled) ~= "function" or Shadows.enabled()) then
    castShadows(state, arena, terrain, nbMesh, cx, cy, vw, vh, atlasFor,
                cards, token, host, neighbors, water, nbWater, groundY)
  end

  -- An opaque void either way. Outdoors the camera is low enough that the
  -- horizon is genuinely in frame, so it is sky; indoors it is the dark end
  -- of the same ramp, which is a room's "past the wall". Transparent -- the
  -- free-roam default -- would let the letterbox clear through wherever the
  -- geometry stops.
  local nativeSky = VoxelScene.skyColor(host, 1)
  -- Reviewed alpha openings opt an otherwise INDOOR engine map into the same
  -- clock/weather sky used outdoors.  Without that explicit voxelSky receipt
  -- the room remains closed and receives only the neutral indoor shade.
  local sky = nativeSky
    or (openSky and VoxelScene.skyShade(2, 1))
    or VoxelScene.skyShade(INDOOR_SHADE, 1)
  -- On a disc rung the void is not a backdrop behind the scenery -- it IS the
  -- scenery, because the map is not drawn. So outdoors it gets the full
  -- treatment the free-roam camera gets: the banded gradient and the hour's
  -- own sun or moon hanging in it (Voxel3D.beginScene paints those when the
  -- sky it is handed carries bands). Indoors there is nothing to dress: a
  -- room's void is one flat shade, which is what a room looks like past the
  -- wall, and the disc fight in a cave is lit and coloured as that cave.
  if skyExposed then
    -- Gold's encounter-site battle is still standing under the same outdoor
    -- sky as free roam, so keep the full bands and sun/moon instead of
    -- collapsing the backdrop to one haze colour.
    local Sky = V.require("Sky")
    local okDress, dressed = pcall(Sky.dress, sky, skyWeatherMode)
    if okDress and dressed then sky = dressed end
  end

  Voxel3D.camera = cam
  -- the sun is turned up for the arena and put back afterwards, so the
  -- free-roam world it shares this module with keeps its own weight -- and
  -- the hour still has the last word: a sunset fades the arena's shadows
  -- out and the moon presses more softly, exactly as it does outside
  local sunWas = Voxel3D.SHADOW_ALPHA
  Voxel3D.SHADOW_ALPHA = BattleScene.SHADOW_ALPHA
                         * DayNight.shadowScale(skyExposed)
  -- and the wireframe is ON for a battle whatever the V-GRID row says. The
  -- arena is a staged shot rather than the world being walked through, and
  -- the seams are what make it read as built rather than photographed. Forced
  -- through the override so the player's own row is never written to.
  local gridWas = VoxelGrid.override
  VoxelGrid.override = VoxelGrid.battleEnabled()
  local out = nil
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
    -- ARENA FILL: WHITE covers the whole voxel world with a solid field and
    -- keeps only the mons (drawn below) above it -- the step between the OG
    -- battle and the full 3D one. Implemented by clearing the scene to white
    -- and skipping the terrain/water/grass/flower draws; the 2D attack
    -- animations and the menus composite on top afterwards, so they stay
    -- above the white too. Requires sprite light UNLIT (see UiBackplates).
  --  local whiteFill = UiBackplates.arenaWhite()
    --local skyFill = whiteFill and { 1, 1, 1 } or sky
    local skyFill = sky
    if not Voxel3D.beginScene(rw, rh, cx, cy, vw, vh, skyFill, "battle",
        { weather = skyWeatherMode,
          groundWeather = arenaSky and arenaSky.groundWeather
            or nativeGround and outdoor and skyWeatherMode or nil,
          mapId = host and host.id, arena = true, battleView = true,
          voxelSky = openSky,
          arenaSky = openSky and true or nil,
          skyAperture = openSky and skyPolicy.skyAperture or nil }) then
      return
    end
  --  if not whiteFill and not discs then
    if painting then
      assert(stage.drawBackdrop(arena, skyExposed, portableBackdrop,
               arenaSky and arenaSky.backdropWeather),
             "portable Arena backdrop draw failed")
    elseif not discs then
      -- A MAP panorama is background paint only.  The real map, its water,
      -- grass, collision-safe actor cells and shadows remain depth-tested in
      -- the passes below.  This is the missing Gen-2 counterpart to Kanto's
      -- panorama-framed voxel fights.
      if panorama then
        assert(stage.drawBackdrop(arena, skyExposed, portableBackdrop, skyWeatherMode),
               "portable MAP panorama draw failed")
      end
      -- BATTLE VISIBILITY BUBBLE: keep the actual encounter terrain, but
      -- dissolve tall tree/wall/shrub fragments that stand in either
      -- camera-to-Pokemon sight line. This is enabled only for terrain and
      -- disabled before the Pokemon/FX pass, so the fighters themselves are
      -- never faded.
      Voxel3D.battleOcclusion(arena, groundY)
      Voxel3D.draw(terrain, atlasFor(host), nil)
      for i, nb in ipairs(neighbors) do
        Voxel3D.draw(nbMesh[i], atlasFor(nb.map),
                   Mat4.translate(nb.ox, 0, nb.oy))
      end
      Voxel3D.battleOcclusion(nil)
    elseif discs then
      -- discs: the two platforms, and nothing else. No terrain, no
      -- neighbouring maps, no water, no grass and no flowers -- see the
      -- matching skips further down. What is behind them is the sky the
      -- clear painted.
      V.require("StadiumStage").draw(arena, groundY)
    else
      Voxel3D.draw(terrain, atlasFor(host), nil)
      for i, nb in ipairs(neighbors) do
        Voxel3D.draw(nbMesh[i], atlasFor(nb.map),
                    Mat4.translate(nb.ox, 0, nb.oy))
      end
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
    end
    if painting then drawBackdropShadows(cards, groundY, portableBackdrop) end
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
    -- Voxel3D.glass(false)
    -- for _, card in ipairs(monCards(arena, groundY, textures)) do
    --   -- the sun stored this card snugged (castShadows), so its own shadow
    --   -- lookup must read the same snugged transform -- see ShadowMap.snug
    --   Voxel3D.draw(BattleBillboard.mesh(), card.tex, card.model,
    --                BattleBillboard.PULL, ShadowMap.snug(card.model))
    -- end
    Voxel3D.glass(false)
    withoutCardShadowReception(function()
      for _, card in ipairs(monCards(
          arena, groundY, textures, host, Voxel3D.vp)) do
        -- Static front illustrations retain their authored brightness instead
        -- of being dimmed or colour-cast by the clock. Only the hour tint is
        -- neutral here; depth and alpha-shaped lighting/shadows stay active.
        if card.noDayTint then Voxel3D.dayTint({ 1, 1, 1 }) end
        -- SPRITE LIGHT: UNLIT draws the card flat and full bright -- no cast
        -- shadow (nil snug) AND no hour/day tint, so a cave or night tint does
        -- not dim it. Most visible on the white arena fill, where a darkened
        -- card would read wrong; but it is flat/full-bright everywhere. SHADED
        -- (the default) keeps the tints and its own shadow, as intended.
      --  local unlit = UiBackplates.spritesUnlit()
        local savedTint = Voxel3D.tint
        -- if unlit then
        --   Voxel3D.tint = { 1, 1, 1 }
        --   Voxel3D.dayTint({ 1, 1, 1 })
        -- end
        Voxel3D.draw(BattleBillboard.mesh(), card.tex, card.model,
                     BattleBillboard.PULL,
                     nil or ShadowMap.snug(card.model))
        -- if unlit then
        --   Voxel3D.tint = savedTint
        --   Voxel3D.dayTint()
        -- end
        if card.noDayTint then Voxel3D.dayTint() end
      end
    end)
    Voxel3D.glass(true)
    Voxel3D.seams(true)
    -- and the STADIUM models, inside the same flash window and with the
    -- same camera-ward pull, so a Pokemon standing on its tile still wins
    -- the depth test against the tile. They manage the wireframe and the
    -- glass mask around their own draws (StadiumRig), which is why this
    -- sits outside the pair above rather than inside it.
    local okStadium, stadiumErr = pcall(function()
      V.require("Stadium").draw(BattleBillboard.PULL)
    end)
    if not okStadium then V.require("Stadium").report(stadiumErr) end
    if flashing then Voxel3D.flatten(nil) end
    -- grass and flowers ride the same camera-ward pull the free-roam pass
    -- gives them, measured against THIS camera's pitch rather than the
    -- orbit's -- there is no character here for them to overdraw, but the
    -- pull is also what keeps a tuft from z-fighting the floor it stands on
    --if not whiteFill and not discs then
    if not discs and not painting then
      local pull = VoxelScene.pull(math.max(pitch, 0.05))
      Voxel3D.draw(ChunkMesher.grass(host), atlasFor(host), nil, pull)
      for _, nb in ipairs(neighbors) do
        Voxel3D.draw(ChunkMesher.grass(nb.map), atlasFor(nb.map),
                    Mat4.translate(nb.ox, 0, nb.oy), pull)
      end
      local fpull = math.max(0, pull - 8 * math.sin(math.max(pitch, 0.05)))
      Voxel3D.draw(ChunkMesher.flowers(host), atlasFor(host), nil, fpull,
                  ShadowMap.snug(nil))
      for _, nb in ipairs(neighbors) do
        Voxel3D.draw(ChunkMesher.flowers(nb.map), atlasFor(nb.map),
                    Mat4.translate(nb.ox, 0, nb.oy), fpull,
                    ShadowMap.snug(Mat4.translate(nb.ox, 0, nb.oy)))
      end
    end
    local canvas = AntiAlias.resolve(Voxel3D.endScene(), pw, ph, "battle")
    if not canvas then return end
    if type(Weather.applyBattle) == "function"
        and (not painting or outdoor) then
      canvas = Weather.applyBattle(canvas, pw, ph, host, Voxel3D.cell,
        arenaSky and arenaSky.particleWeather or weatherMode)
    end

    local vp = Voxel3D.vp
    local layout = BattleScene.presentationLayout(
      arena, groundY, textures, host, vp)
    local player, enemy = layout.player, layout.enemy
    if not (player and enemy) then return end
    local pmx, pmy = BattleScene.toGB(vp, player[1], player[2], player[3],
                                      lx, ly, s, pw, ph)
    local emx, emy = BattleScene.toGB(vp, enemy[1], enemy[2], enemy[3],
                                      lx, ly, s, pw, ph)
    if not (pmx and emx) then return end
    -- How wide one overworld square is on screen where each mon stands, in
    -- GB pixels. This is what the pics are scaled to: a mon covers its own
    -- square and no more, at whatever the drift has done to the distance.
    local half = BattleScene.CELL / 2
    local pl = BattleScene.toGB(vp, player[1] - half, player[2], player[3],
                                lx, ly, s, pw, ph)
    local pr = BattleScene.toGB(vp, player[1] + half, player[2], player[3],
                                lx, ly, s, pw, ph)
    local el = BattleScene.toGB(vp, enemy[1] - half, enemy[2], enemy[3],
                                lx, ly, s, pw, ph)
    local er = BattleScene.toGB(vp, enemy[1] + half, enemy[2], enemy[3],
                                lx, ly, s, pw, ph)
    if not (pl and pr and el and er) then return end
    local playerHull, playerFoot, playerHead = BattleScene.projectedActorHull(
      vp, player[1], player[2], player[3], pw, ph)
    local enemyHull, enemyFoot, enemyHead = BattleScene.projectedActorHull(
      vp, enemy[1], enemy[2], enemy[3], pw, ph)
    local actorVisuals = {}
    for _, card in ipairs(cards) do
      local receipt = actorVisualForCard(card, vp, pw, ph, token)
      if receipt then actorVisuals[card.side] = receipt end
    end
    for _, side in ipairs({ "player", "enemy" }) do
      actorVisuals[side] = stadiumActorVisual(
        side, vp, pw, ph, token) or actorVisuals[side]
    end
    actorVisuals.player = actorVisuals.player or {
      hull=playerHull,
      foot=playerFoot and { x=playerFoot[1], y=playerFoot[2] },
      head=playerHead,
    }
    actorVisuals.enemy = actorVisuals.enemy or {
      hull=enemyHull,
      foot=enemyFoot and { x=enemyFoot[1], y=enemyFoot[2] },
      head=enemyHead,
    }
    out = {
      canvas = canvas,
      coordinateSpace = "scene-canvas",
      presentationReceipt = type(CanvasPresentation.battlePresentation) == "function"
        and CanvasPresentation.battlePresentation() or nil,
      cameraMode = cinematic and "SMART" or "AUTHORED",
      -- Retain the exact projection used for this shot so read-only
      -- companion queries can project animated model attachment points after
      -- the 3D pass has ended, without consulting mutable camera globals.
      vp = vp,
      player = { pmx, pmy },
      enemy = { emx, emy },
      playerSpan = math.abs(pr - pl)
        * (layout.actorScale.player or 1),
      enemySpan = math.abs(er - el)
        * (layout.actorScale.enemy or 1),
      -- the letterbox, so the depth-of-field pass can put its sharp band on
      -- the two marks rather than on a fraction of the window
      lx = lx, ly = ly, scale = s, pw = pw, ph = ph,
      actorHulls = { player=playerHull, enemy=enemyHull },
      actorFeet = { player=playerFoot, enemy=enemyFoot },
      actorVisuals = actorVisuals,
      layoutContext = layout.layoutContext,
      smartArenaComposition = layout.smartArenaComposition,
      skyPolicy = {
        voxelSky=openSky,
        skyAperture=openSky and skyPolicy.skyAperture or nil,
        source=skyPolicy.source,
      },
      arenaSkyPolicy = arenaSky,
      -- and the hour's light, for anything drawn over this shot that is NOT
      -- geometry and so never went past the shader that applied it -- the back
      -- pic pinned to the menu (see OverworldBattle.backPinned). Neutral
      -- indoors, which is what DayNight.tint answers for a room.
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
  return out
end

return BattleScene
