-- The B rungs: the two discs the fight is staged on.
--
-- Where an A rung puts the fight on the MAP -- real ground, whatever the
-- route happens to look like -- a B rung puts it on two platforms against
-- the sky and draws no map at all.
--
-- ------- one stage, two rungs
--
-- The discs do not know what is standing on them. 2D-3D B stands the Game
-- Boy's own battle pics there and native cards stands the Pokemon Stadium
-- models, and this file is identical for both: it draws two platforms at two
-- cells and sizes each to whatever footprint it is given. That is why the
-- flat disc rung cost a value in the 3D-BTL ladder and nothing else.
--
-- ------- why this is a rung and not a fix
--
-- Staging on the map is the better picture when the map cooperates, and it
-- often does not. Half of Kanto's interiors are furniture; a cave floor can
-- be nothing but two-cell corridors; some maps have nowhere a fight can be
-- SEEN from a low camera and are declined outright (see BattleArena), which
-- drops the player back to the flat battle screen with no warning. And even
-- where a spot exists, the ground behind the foe is a hedge or a shop counter
-- rather than anything a battle wants behind it.
--
-- Discs have none of those problems, because the stage is CARRIED rather than
-- found: it works on every map, in every building, at every step, and the
-- framing is the same every time. What it gives up is the thing STADIUM A is
-- for -- fighting somewhere real.
--
-- ------- what stays
--
-- The sky, and the light. A battle outdoors is under the hour's own sky, with
-- its bands and its sun or moon (Voxel3D.beginScene paints it when handed a
-- dressed one); a battle in a cave or a room is under that place's own void
-- and its own neutral light, exactly as the map itself would be. So the mode
-- is abstracted from the GROUND, not from the world -- walk into a cave at
-- midnight and the fight looks like a cave at midnight.
--
-- And the framing. The camera, the pins, the HUDs, the text box, the move
-- animations and the depth of field are all identical, because every one of
-- them is hung off the arena's CELLS rather than off what is under them. That
-- is the same reason STADIUM A could be an option on the mode rather than a
-- second mode, and it is why this file is a few hundred lines and not a few
-- thousand.

-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local Mat4 = V.require("Mat4")
local Voxel3D = V.require("Voxel3D")
local DayNight = V.require("DayNight")
local Assets = require("src.render.Assets")

local VoxelBattleStage = {}

local floor = math.floor
local sin, cos = math.sin, math.cos
local pi = math.pi

-- ------- the shape of a disc
--
-- Radius in world pixels, where a map cell is 16 and the two mons stand three
-- cells apart.
--
-- A PLATFORM FOLLOWS WHAT STANDS ON IT rather than being one fixed size,
-- because the set's footprints run nearly tenfold: a Caterpie is under four
-- world pixels across and Moltres, wings out, is twenty-six. One radius for
-- both is either a dinner plate under the caterpillar or a doily under the
-- bird.
--
-- RADIUS is the floor, and it is the number most species land on -- it is a
-- little over the map cell a Pokemon is sized to cover, which is the
-- proportion the Game Boy's own battle platforms have. PAD is the margin
-- around a mon that needs more than that, and MAX_RADIUS stops Moltres from
-- being handed something the frame cannot hold.
--
-- These are the FULL radius, out to where the fade has finished; the solid
-- centre a Pokemon actually stands on is SOLID of it. PAD is sized so that a
-- mon's own footprint fits inside that centre rather than out over the
-- stipple -- 1.8 x 0.70 is a little over 1.25, so a big Pokemon still has
-- solid ground under its edges.
VoxelBattleStage.RADIUS = 18
VoxelBattleStage.MAX_RADIUS = 34
VoxelBattleStage.PAD = 1.8

-- The platform for a mon of this footprint. `r` may be nil -- nothing is
-- standing there yet, which is every frame of the send-out before the model
-- appears, and it is also the whole of the flat 2D-3D B rung, where a
-- Pokemon is a battle pic sized to cover exactly one map cell and RADIUS is
-- already a little over that. Either way the platform is the plain one, and
-- it has to be there BEFORE the Pokemon lands on it.
function VoxelBattleStage.radiusFor(r)
  local want = (r or 0) * VoxelBattleStage.PAD
  if want < VoxelBattleStage.RADIUS then return VoxelBattleStage.RADIUS end
  if want > VoxelBattleStage.MAX_RADIUS then return VoxelBattleStage.MAX_RADIUS end
  return want
end

-- Per-vertex shading, in the same terms Voxel3D lights the models with, so
-- a disc and the Pokemon standing on it agree about where the sun is. Fitted
-- to Voxel3D.FACE_SHADE's six values: the constant is the average, and each
-- axis term is half the spread between that axis's two faces.
local SHADE_BASE = 0.7725
local SHADE_X = 0.06
local SHADE_Y = 0.225
local SHADE_Z = 0.11

local function shadeFor(nx, ny, nz)
  local s = SHADE_BASE + nx * SHADE_X + ny * SHADE_Y + nz * SHADE_Z
  if s < 0.30 then return 0.30 end
  if s > 1.00 then return 1.00 end
  return s
end

-- ------- the texture
--
-- The platform is a FLAT painted disc that fades out at its rim -- no rim
-- wall, no thickness, the whole thing carried in one texture on one quad
-- lying on the ground plane. That is what the Game Boy's own battle
-- platforms are, and it is what keeps the stage from competing with the
-- Pokemon standing on it.
--
-- ------- why the fade is DITHERED
--
-- The scene shader discards any texel under half alpha outright (it has to:
-- that is what keeps a sprite's transparent corners out of the depth buffer).
-- So a smooth alpha ramp does not fade -- it comes out as a hard circle cut
-- at wherever the ramp crosses 0.5, which is the one thing this must not be.
--
-- The fade is therefore an ORDERED DITHER baked into the texture's alpha:
-- every texel is fully on or fully off, and the proportion that are on falls
-- away toward the rim. It is the same trick the sky already uses for its
-- bands (Sky.DITHER), it needs no shader change and so risks nothing in any
-- other pass, and on a mode built out of visible texels it reads as intended
-- rather than as a limitation.
--
-- The COLOUR is deliberately neutral. Everything the shader does to it after
-- this is the environment's: Voxel3D.tint carries the hour outdoors and the
-- room's own flat light indoors, and the shadow pass darkens whatever the
-- Pokemon standing on it occludes. So one texture is a sunlit platform, a
-- dusk platform and a cave platform, without a variant for each.
VoxelBattleStage.TEX = 128

-- Where the solid centre ends, as a fraction of the disc's radius. Inside
-- this everything is opaque; from here to the rim the dither thins out.
VoxelBattleStage.SOLID = 0.76

local TOP = { 0.74, 0.71, 0.63 }
local TOP_ALT = { 0.67, 0.64, 0.57 }

local texture = nil
local arenaTextures, arenaOrder = {}, {}
local backdropTextures, backdropOrder = {}, {}

-- A small deterministic scatter, for the surface itself. Not a random one: an
-- authored constant that happens to look unpatterned is worth more here than
-- a seed, because it can never change under a different Lua.
--
-- Quantised into blocks, so the surface reads as TEXELS rather than as noise.
-- Per-pixel it came out as a fine mottle that fought the dithered rim for
-- attention -- and the rim is the thing worth looking at. At this size the
-- grain is roughly the size of the voxels everywhere else in the mode.
VoxelBattleStage.GRAIN = 4

local function grain(x, y)
  local bx = (x - x % VoxelBattleStage.GRAIN) / VoxelBattleStage.GRAIN
  local by = (y - y % VoxelBattleStage.GRAIN) / VoxelBattleStage.GRAIN
  local v = (bx * 37 + by * 71 + ((bx * by) % 13) * 17) % 100
  return v < 34
end

-- The 8x8 ordered (Bayer) matrix, as thresholds in 0..63. Ordered rather than
-- random because a random dither crawls: this pattern is fixed in the
-- texture, so the fade holds still while the camera drifts across it.
local BAYER = {
  { 0, 32,  8, 40,  2, 34, 10, 42 },
  { 48, 16, 56, 24, 50, 18, 58, 26 },
  { 12, 44,  4, 36, 14, 46,  6, 38 },
  { 60, 28, 52, 20, 62, 30, 54, 22 },
  {  3, 35, 11, 43,  1, 33,  9, 41 },
  { 51, 19, 59, 27, 49, 17, 57, 25 },
  { 15, 47,  7, 39, 13, 45,  5, 37 },
  { 63, 31, 55, 23, 61, 29, 53, 21 },
}

function VoxelBattleStage.texture()
  if texture ~= nil then return texture or nil end
  local ok, img = pcall(function()
    local n = VoxelBattleStage.TEX
    local data = love.image.newImageData(n, n)
    local half = (n - 1) / 2
    local solid = VoxelBattleStage.SOLID
    for y = 0, n - 1 do
      local dy = (y - half) / half
      for x = 0, n - 1 do
        local dx = (x - half) / half
        local d = (dx * dx + dy * dy) ^ 0.5
        -- how much of this texel's neighbourhood should survive: everything
        -- inside the solid core, nothing past the rim, and a smooth ramp
        -- between the two that the dither turns into a stipple
        local cover
        if d <= solid then
          cover = 1.0
        elseif d >= 1.0 then
          cover = 0.0
        else
          local t = (d - solid) / (1.0 - solid)
          cover = 1.0 - t * t * (3 - 2 * t)     -- smoothstep, falling
        end
        local threshold = (BAYER[y % 8 + 1][x % 8 + 1] + 0.5) / 64
        local a = (cover > threshold) and 1 or 0
        local c = grain(x, y) and TOP_ALT or TOP
        data:setPixel(x, y, c[1], c[2], c[3], a)
      end
    end
    local image = love.graphics.newImage(data)
    -- nearest, like every other texture in this mode: the grain and the
    -- stipple are both meant to read as texels. Clamped rather than
    -- repeating now that one texture covers the whole disc.
    image:setFilter("nearest", "nearest")
    image:setWrap("clampzero", "clampzero")
    return image
  end)
  texture = (ok and img) or false
  return texture or nil
end

local function arenaGrain(profile, x, y, seed)
  local bx, by = floor(x / 6), floor(y / 6)
  local n = (bx * 37 + by * 71 + seed) % 17
  local p = profile.pattern
  if p == "waves" then return (by + floor(bx / 2) + seed) % 4 == 0 end
  if p == "paving" or p == "tiles" then return bx % 2 == by % 2 end
  if p == "panels" then return bx % 4 == 0 or by % 4 == 0 end
  if p == "deck" then return by % 3 == 0 end
  if p == "bridge" then return by % 4 == 0 or bx == 4 or bx == 17 end
  if p == "canal" then return by % 5 == 0 or (bx + by + seed) % 11 == 0 end
  if p == "gate" then return bx % 6 == 0 or by % 6 == 0 end
  if p == "runes" then return n == 0 or n == 5 end
  if p == "crystal" then return (bx + by * 2 + seed) % 5 == 0 end
  if p == "scales" then return (bx + floor(by / 2)) % 3 == 0 end
  if p == "court" then return bx == 10 or by == 10 end
  local limit = (p == "grass" or p == "leaves" or p == "sand") and 6 or 4
  return n < limit
end

-- Strong location motifs over the shared procedural grain. They are broad
-- deterministic colour regions rather than imported pictures, so they stay
-- readable at 3X without adding a texture asset or another draw.
local WATER = { .20, .49, .68 }
local WATER_LIGHT = { .34, .65, .73 }
local GOLD = { .88, .67, .18 }
local FLOWER = { .88, .28, .31 }
local PALE = { .76, .76, .68 }
local VIOLET = { .45, .35, .65 }

local function landmark(profile, x, y, base)
  local motif = profile.motif
  if not motif then return base end
  local dx, dy = (x - 63.5) / 63.5, (y - 63.5) / 63.5
  local ax, ay = math.abs(dx), math.abs(dy)
  if motif == "nugget_bridge" then
    if ax > .51 then return WATER end
    if ax > .41 then return GOLD end
    if y % 16 <= 2 then return profile.edge end
  elseif motif == "cerulean_canal" then
    if ax > .24 and ax < .43 then return WATER_LIGHT end
    if ax <= .08 then return PALE end
    if ax > .48 and ((floor(y / 10) + floor(x / 8)) % 3 == 0) then
      return FLOWER
    end
  elseif motif == "route2_gate" then
    if ax < .22 then return PALE end
    if ay > .42 and ax > .27 and ax < .55 then return profile.edge end
  elseif motif == "moon" then
    local r = math.sqrt(dx * dx + dy * dy)
    if r > .43 and r < .58 then return profile.edge end
    if ax < .12 then return PALE end
  elseif motif == "moon_exit" then
    if ax < .17 then return PALE end
    if ay > .34 and ax > .28 then return profile.edge end
  elseif motif == "rock_water" then
    if ax > .43 then return WATER end
    if (floor(x / 12) + floor(y / 10)) % 5 == 0 then return profile.edge end
  elseif motif == "vermilion_gate" then
    if ax > .55 then return WATER end
    if x % 18 <= 2 then return profile.edge end
  elseif motif == "indigo_gate" then
    if ax < .20 then return PALE end
    if ay > .42 and ax > .30 and ax < .58 then return VIOLET end
  elseif motif == "indigo_road" then
    if ax < .24 then
      return ((floor(y / 10) + floor(x / 8)) % 3 == 0) and VIOLET or PALE
    end
  elseif motif == "cape" then
    if ax > .48 or dy < -.60 then return WATER_LIGHT end
    if ax < .08 then return PALE end
  end
  return base
end

local function arenaTexture(style)
  if not (style and style.profile and style.variant) then return nil end
  local key = style.id .. ":" .. style.variant
  if arenaTextures[key] then return arenaTextures[key] end
  local ok, img = pcall(function()
    local n, profile, seed = 128, style.profile, style.seed or 0
    local data = love.image.newImageData(n, n)
    local half = (n - 1) / 2
    for y = 0, n - 1 do
      local dy = (y - half) / half
      for x = 0, n - 1 do
        local dx = (x - half) / half
        local d = math.sqrt(dx * dx + dy * dy)
        local cover = d <= .90 and 1 or d >= 1 and 0 or (1 - d) / .10
        local threshold = (BAYER[y % 8 + 1][x % 8 + 1] + .5) / 64
        local a = cover > threshold and 1 or 0
        local c = arenaGrain(profile, x, y, seed) and profile.alt or profile.top
        c = landmark(profile, x, y, c)
        -- A dark court ring and centre tick make this read as a battlefield,
        -- not a floating square of generic ground.
        if d > .76 and d < .80 or math.abs(x - half) < 1.1 and math.abs(y-half) < 8 then
          c = profile.edge
        end
        data:setPixel(x, y, c[1], c[2], c[3], a)
      end
    end
    local out = love.graphics.newImage(data)
    out:setFilter("nearest", "nearest")
    out:setWrap("clampzero", "clampzero")
    return out
  end)
  if not (ok and img) then return nil end
  arenaTextures[key] = img
  arenaOrder[#arenaOrder + 1] = key
  if #arenaOrder > 8 then
    local old = table.remove(arenaOrder, 1)
    local victim = arenaTextures[old]
    if victim and victim.release then pcall(victim.release, victim) end
    arenaTextures[old] = nil
  end
  return img
end

-- ------- full-frame Arena Scenery
--
-- ARENA is deliberately opt-in per reviewed place.  Every authored bitmap
-- keeps its upper sky transparent, so the engine remains responsible for
-- clock, weather, sun, moon and stars; the painting supplies only the place.
-- Unknown or malformed art never falls back to the rejected procedural
-- pixel collage: the ARENA frame declines and the ordinary battle remains.
VoxelBattleStage.BACKDROP_W = 1280
VoxelBattleStage.BACKDROP_H = 800
VoxelBattleStage.BACKDROP_CACHE = 8

local AUTHORED_BACKDROPS = {
  nugget_bridge = {
    path = "assets/battle/nugget_bridge_a.compact.png",
    width = 1280,
    height = 800,
    camera = "3X",
    outdoor = true,
    actorScale = 1,
    clockTint = false,
    -- Every reviewed painting owns both of its presentation anchors.  These
    -- offsets are from the canonical arena cells in world X/Y/Z; they are not
    -- shared defaults.  The painted bank rises toward the bridge, so the
    -- player is pulled onto the broad foreground meadow and the foe onto the
    -- higher right clearing.  STADIUM moves the camera around these same
    -- fixed anchors.
    anchors = {
      -- Pull the near/player card onto the broad foreground meadow rather
      -- than balancing it on the narrow blue/green riverbank boundary.
      player = { x=0, y=-8, z=0 },
      enemy = { x=0, y=-17, z=0 },
    },
  },
}

-- The selected 111-anchor gallery is compiled to a small map-id table.  Keep
-- the original Nugget Bridge entry above as a fail-closed compatibility
-- receipt; a missing/corrupt generated table must never make that reviewed
-- arena disappear or turn unknown places into authored ones.
local okReviewed, REVIEWED_BACKDROPS = pcall(function()
  return V.data("arena_scenery")
end)
if not okReviewed or type(REVIEWED_BACKDROPS) ~= "table" then
  REVIEWED_BACKDROPS = {}
end

local function finite(v)
  return type(v) == "number" and v == v and v > -math.huge and v < math.huge
end

local function validWindow(region, width, height)
  if type(region) ~= "table" then return false end
  for _, key in ipairs({ "tintScale", "alphaScale", "starsScale" }) do
    local value = region[key]
    if value ~= nil and not (finite(value) and value >= 0 and value <= 1) then
      return false
    end
  end
  if region.moon ~= nil and type(region.moon) ~= "boolean" then return false end
  local shape = region.shape
  if shape == "rect" or shape == "ellipse" then
    return finite(region.x) and finite(region.y)
           and finite(region.w) and finite(region.h)
           and region.w > 0 and region.h > 0
           and region.x >= 0 and region.y >= 0
           and region.x + region.w <= width
           and region.y + region.h <= height
  end
  if shape ~= "poly" or type(region.points) ~= "table"
     or #region.points < 6 or #region.points % 2 ~= 0 then
    return false
  end
  for i=1,#region.points,2 do
    local x, y = region.points[i], region.points[i + 1]
    if not (finite(x) and finite(y) and x >= 0 and y >= 0
            and x <= width and y <= height) then
      return false
    end
  end
  return true
end

local function authoredSpec(arena)
  local style = arena and arena.arenaStyle
  local spec = style and (REVIEWED_BACKDROPS[style.mapId]
                          or AUTHORED_BACKDROPS[style.id])
  if not (spec and spec.camera == "3X" and type(spec.outdoor) == "boolean"
          and type(spec.path) == "string" and spec.path ~= ""
          and spec.width == VoxelBattleStage.BACKDROP_W
          and spec.height == VoxelBattleStage.BACKDROP_H
          and finite(spec.actorScale) and spec.actorScale >= 1
          and spec.actorScale <= 2.25
          and type(spec.clockTint) == "boolean"
          and type(spec.anchors) == "table") then
    return nil
  end
  for _, side in ipairs({ "player", "enemy" }) do
    local anchor = spec.anchors[side]
    if not (type(anchor) == "table" and finite(anchor.x)
            and finite(anchor.y) and finite(anchor.z)) then
      return nil
    end
  end
  if spec.clockTint then
    if type(spec.windows) ~= "table" or #spec.windows == 0 then return nil end
    for _, region in ipairs(spec.windows) do
      if not validWindow(region, spec.width, spec.height) then return nil end
    end
  elseif spec.windows ~= nil then
    return nil
  end
  return spec
end

local function clamp01(v)
  return math.max(0, math.min(1, v or 0))
end

local function paint(data, x, y, c, k, a, lift)
  if not c or (a or 1) <= 0 then
    data:setPixel(x, y, 0, 0, 0, 0)
    return
  end
  k, lift = k or 1, lift or 0
  data:setPixel(x, y,
    clamp01(c[1] * k + lift), clamp01(c[2] * k + lift),
    clamp01(c[3] * k + lift), clamp01(a or 1))
end

local function hashPixel(seed, x, y)
  return (seed + x * 37 + y * 71 + ((x * y) % 29) * 17) % 101
end

local function ellipse(x, y, cx, cy, rx, ry)
  local dx, dy = (x - cx) / rx, (y - cy) / ry
  return dx * dx + dy * dy <= 1
end

local function foreground(profile, seed, x, y)
  local row = floor(math.max(0, y - 78) / 7)
  local span = math.max(4, 13 - floor(row / 2))
  local checker = (floor((x + row * 3) / span) + row) % 2 == 0
  local grainy = arenaGrain(profile, x * 2, y * 2, seed)
  return (checker ~= grainy) and profile.top or profile.alt
end

local function indoorPixel(style, x, y)
  local p, seed = style.profile, style.seed or 0
  if y < 16 then
    return p.edge, .48 + (hashPixel(seed, floor(x / 8), 0) % 2) * .06
  end
  if y < 82 then
    -- A complete rear wall with columns and a central room-specific crest.
    local panel = floor(x / 20) % 2 == 0
    local c = panel and p.alt or p.top
    local k = .76 + (y - 16) / 210
    if x % 32 < 3 or x % 32 > 28 then c, k = p.edge, .78 end
    if y > 69 and y < 74 then c, k = p.edge, .88 end
    local cx = 80
    if ellipse(x, y, cx, 45, 15, 18) then
      local ring = not ellipse(x, y, cx, 45, 10, 13)
      if ring then c, k = p.edge, 1.18
      elseif (x + y + seed) % 7 < 2 then c, k = p.top, 1.20 end
    end
    -- Lamps/windows keep League, Rocket and KASC rooms from reading as one
    -- flat rectangle while still deriving solely from the profile palette.
    if y > 28 and y < 50 and (x % 40) > 8 and (x % 40) < 16 then
      c, k = p.top, 1.28
    end
    return c, k
  end
  local c = foreground(p, seed, x, y)
  if y < 88 then return p.edge, .83 end
  if (floor((x - 80) / math.max(5, (150 - y) / 5))
      + floor((y - 88) / 8)) % 2 == 0 then
    return c, 1.04
  end
  return c, .88
end

local function genericOutdoor(style, x, y)
  local p, seed = style.profile, style.seed or 0
  local pattern = p.pattern
  local horizon = 29 + hashPixel(seed, floor(x / 9), 1) % 7
  if pattern == "forest" or pattern == "leaves" then
    horizon = 22 + hashPixel(seed, floor(x / 7), 2) % 12
  elseif pattern == "waves" then
    horizon = 37 + hashPixel(seed, floor(x / 18), 2) % 3
  end
  if y < horizon then return nil end
  if y < horizon + 18 then
    if pattern == "paving" or pattern == "tiles" then
      local bx = floor(x / 18)
      local roof = horizon + (bx % 3) * 3
      if y < roof + 4 then return p.edge, .82 end
      local window = y > roof + 8 and x % 18 > 5 and x % 18 < 10
      return window and p.top or p.alt, window and 1.26 or .96
    end
    if pattern == "forest" or pattern == "leaves" then
      local trunk = x % 19 > 8 and x % 19 < 12 and y > horizon + 9
      return trunk and p.edge or p.alt, trunk and .72 or .90
    end
    if pattern == "waves" then return WATER, .92 end
    return ((x + floor(y / 3) + seed) % 11 < 4) and p.edge or p.alt,
           .78
  end
  if pattern == "waves" and y < 96 then
    return ((y + floor(x / 9)) % 9 < 2) and WATER_LIGHT or WATER,
           .94
  end
  if y < 78 then
    return ((floor(x / 11) + floor(y / 7) + seed) % 3 == 0)
           and p.alt or p.top, .86
  end
  return foreground(p, seed, x, y), 1
end

local function outdoorPixel(style, x, y)
  local p, seed, motif = style.profile, style.seed or 0, style.profile.motif

  if motif == "nugget_bridge" then
    if y < 27 then return nil end
    if y < 46 then
      -- Cerulean/tree line at the far end of the bridge.
      local house = x > 18 and x < 42 or x > 116 and x < 143
      if house then
        if y < 32 then return FLOWER, .72 end
        local window = y > 36 and x % 13 > 5 and x % 13 < 9
        return window and PALE or p.alt, window and 1.20 or .94
      end
      return ((x + seed) % 17 < 8) and p.edge or p.alt, .76
    end
    local t = (y - 46) / 98
    local half = 8 + t * 48
    local dx = math.abs(x - 79.5)
    if dx <= half then
      if dx > half - 3 then return GOLD, .98 end
      local joint = (floor(y / 9) + floor(x / 14)) % 2 == 0
      return joint and p.top or p.alt, joint and 1.03 or .94
    end
    return ((y + floor(x / 8)) % 11 < 2) and WATER_LIGHT or WATER,
           .96
  end

  if motif == "cerulean_canal" then
    if y < 26 then return nil end
    if y < 51 then
      local house = x % 38 > 5 and x % 38 < 27
      if house then
        if y < 31 + (x % 4) then return FLOWER, .78 end
        local window = y > 37 and x % 11 > 4 and x % 11 < 8
        return window and PALE or p.alt, window and 1.20 or .95
      end
      return p.edge, .78
    end
    if y < 89 then
      local bank = y < 55 or y > 84
      if bank then return PALE, .90 end
      return ((y + floor(x / 10)) % 10 < 2) and WATER_LIGHT or WATER,
             .96
    end
    if x % 23 > 16 and y < 112 then return FLOWER, 1.05 end
    return foreground(p, seed, x, y), 1
  end

  if motif == "moon" or motif == "moon_exit" then
    local peak = 17 + math.abs(x - 80) * (motif == "moon" and .37 or .46)
    if y < peak then return nil end
    if y < 82 then
      if ellipse(x, y, 80, 70, 15, 20) and y > 55 then
        return p.edge, .38
      end
      local vein = (x * 3 + y * 5 + seed) % 31 < 5
      return vein and p.alt or p.top, vein and .78 or .92
    end
    return foreground(p, seed, x, y), 1
  end

  if motif == "route2_gate" then
    if y < 23 + hashPixel(seed, floor(x / 8), 3) % 8 then return nil end
    local gate = x >= 54 and x <= 105 and y >= 31 and y <= 78
    if gate then
      if y < 38 then return p.edge, .92 end
      if x > 70 and x < 90 and y > 53 then return p.edge, .42 end
      local window = y > 44 and y < 54 and (x < 69 or x > 91)
      return window and PALE or p.alt, window and 1.16 or 1
    end
    if y < 77 then
      local trunk = x % 17 > 7 and x % 17 < 11 and y > 55
      return trunk and p.edge or p.alt, trunk and .65 or .83
    end
    if math.abs(x - 80) < (y - 72) * .36 then return PALE, .82 end
    return foreground(p, seed, x, y), .96
  end

  if motif == "rock_water" or motif == "cape" then
    if y < 30 + hashPixel(seed, floor(x / 12), 4) % 7 then return nil end
    if y < 68 and (x < 36 or x > 124) then return p.edge, .86 end
    if y < 96 then
      return ((y + floor(x / 10)) % 10 < 2) and WATER_LIGHT or WATER,
             .95
    end
    return foreground(p, seed, x, y), .96
  end

  if motif == "vermilion_gate" or motif == "indigo_gate"
     or motif == "indigo_road" then
    if y < 27 then return nil end
    local gateHalf = motif == "indigo_road" and 18 or 27
    if y < 80 and math.abs(x - 80) < gateHalf then
      if y < 35 then return p.edge, .88 end
      if math.abs(x - 80) < 9 and y > 48 then return p.edge, .38 end
      return (x % 13 > 8) and p.alt or p.top, .96
    end
    if y < 76 then return p.alt, .75 end
    if math.abs(x - 80) < (y - 64) * .35 then return PALE, .86 end
    return foreground(p, seed, x, y), 1
  end

  return genericOutdoor(style, x, y)
end

local function backdropImage(arena, outdoor)
  local style = arena and arena.arenaStyle
  local spec = authoredSpec(arena)
  outdoor = outdoor and true or false
  if not (spec and spec.outdoor == outdoor and type(V.path) == "string") then
    return nil
  end
  local key = style.id .. ":" .. spec.path
  if backdropTextures[key] ~= nil then
    return backdropTextures[key] or nil
  end
  local ok, image = pcall(function()
    local path = V.path .. "/" .. spec.path
    local data = Assets.imageData(path)
    if not (data and type(data.getDimensions) == "function") then
      error("missing Arena Scenery ImageData")
    end
    local w, h = data:getDimensions()
    if w ~= spec.width or h ~= spec.height then
      if data.release then pcall(data.release, data) end
      error("Arena Scenery dimensions changed")
    end
    local okImage, out = pcall(love.graphics.newImage, data)
    if data.release then pcall(data.release, data) end
    if not okImage or not out then error("Arena Scenery image upload failed") end
    pcall(out.setFilter, out, "linear", "linear")
    pcall(out.setWrap, out, "clamp", "clamp")
    return out
  end)
  if not (ok and image) then
    backdropTextures[key] = false
    return nil
  end
  backdropTextures[key] = image
  backdropOrder[#backdropOrder + 1] = key
  if #backdropOrder > VoxelBattleStage.BACKDROP_CACHE then
    local old = table.remove(backdropOrder, 1)
    local victim = backdropTextures[old]
    if victim and victim.release then pcall(victim.release, victim) end
    backdropTextures[old] = nil
  end
  return image
end

function VoxelBattleStage.hasAuthoredBackdrop(arena)
  return authoredSpec(arena) ~= nil
end

function VoxelBattleStage.presentationPosition(arena, side, groundY)
  local cell = arena and arena[side]
  if not (type(cell) == "table" and finite(cell[1]) and finite(cell[2])) then
    return nil
  end
  local spec = authoredSpec(arena)
  local anchor = spec and spec.anchors[side]
  return cell[1] + (anchor and anchor.x or 0),
         (groundY or 0) + (anchor and anchor.y or 0),
         cell[2] + (anchor and anchor.z or 0)
end

function VoxelBattleStage.presentationGroundY(arena, side, groundY)
  local _, y = VoxelBattleStage.presentationPosition(arena, side, groundY)
  return y
end

-- A full-frame painting can depict a stadium or an intimate cabin while the
-- two feet remain at exactly the same reviewed pixels.  Scale the cards about
-- those feet instead of moving the anchors or the engine HUD.  Unknown,
-- malformed and every non-ARENA surface retain the historical 1:1 size.
function VoxelBattleStage.presentationScale(arena)
  local spec = authoredSpec(arena)
  return spec and spec.actorScale or 1
end

function VoxelBattleStage.backdropFor(arena, outdoor)
  return backdropImage(arena, outdoor and true or false)
end

function VoxelBattleStage.presentationTint(arena)
  return Voxel3D.tint
end

function VoxelBattleStage.presentationWindowTint(arena)
  local scene = VoxelBattleStage.presentationWindowScene(arena)
  return scene and scene.tint or nil
end

function VoxelBattleStage.presentationWindowScene(arena)
  local spec = authoredSpec(arena)
  if not (spec and spec.clockTint) then return nil end
  local scene = DayNight.windowScene and DayNight.windowScene() or {
    tint = DayNight.tint(true), sky = { 0, 0, 0 },
    alpha = 0, stars = 0, moon = 0,
  }
  local clock = type(scene) == "table" and scene.tint
  if not (type(clock) == "table" and finite(clock[1])
          and finite(clock[2]) and finite(clock[3])
          and type(scene.sky) == "table" and finite(scene.sky[1])
          and finite(scene.sky[2]) and finite(scene.sky[3])
          and finite(scene.alpha) and scene.alpha >= 0 and scene.alpha <= 1
          and finite(scene.stars) and scene.stars >= 0 and scene.stars <= 1
          and finite(scene.moon) and scene.moon >= 0 and scene.moon <= 1) then
    return nil
  end
  return scene
end

-- `image` is prepared before beginScene.  The draw itself is one alpha
-- composited screen quad behind the depth buffer, tinted by the same clock
-- value as the platform and Pokemon.
function VoxelBattleStage.drawBackdrop(arena, outdoor, image)
  if not (arena and arena.arenaStyle) then return false end
  image = image or backdropImage(arena, outdoor and true or false)
  if not image then return false end
  local drawn = Voxel3D.backdrop(
    image, VoxelBattleStage.presentationTint(arena))
  if not drawn then return false end
  local spec = authoredSpec(arena)
  local windowScene = VoxelBattleStage.presentationWindowScene(arena)
  if spec and windowScene then
    -- The room keeps its authored lamps. Only reviewed panes receive the
    -- continuous outside sky, stars and moon.
    Voxel3D.backdropWindows(windowScene, spec.windows,
                            spec.width, spec.height)
  end
  return true
end

function VoxelBattleStage.textureFor(arena)
  return arena and arena.arenaStyle and arenaTexture(arena.arenaStyle)
         or VoxelBattleStage.texture()
end

-- ------- the mesh
--
-- One quad, lying flat on the ground plane, spanning -1..1 in x and z with
-- the whole texture stretched across it. The DISC is the texture's business,
-- not the geometry's -- everything outside the painted circle is alpha the
-- shader discards -- which is what "a flat texture that fades out at the
-- edges" means and what makes this four vertices rather than a hundred and
-- fifty.
--
-- Shaded as a face pointing straight up, because it is one.

local mesh = nil

local function build()
  local s = shadeFor(0, 1, 0)
  local verts = {
    { -1, 0, -1, 0, 0, s },
    {  1, 0, -1, 1, 0, s },
    {  1, 0,  1, 1, 1, s },
    { -1, 0,  1, 0, 1, s },
  }
  return Voxel3D.newMesh(verts, { 1, 2, 3, 1, 3, 4 })
end

function VoxelBattleStage.mesh()
  if mesh == nil then mesh = build() or false end
  return mesh or nil
end

function VoxelBattleStage.invalidate()
  if texture and texture.release then pcall(texture.release, texture) end
  if mesh and mesh.release then pcall(mesh.release, mesh) end
  for _, image in pairs(arenaTextures) do
    if image and image.release then pcall(image.release, image) end
  end
  for _, image in pairs(backdropTextures) do
    if image and image.release then pcall(image.release, image) end
  end
  texture, mesh, arenaTextures, arenaOrder = nil, nil, {}, {}
  backdropTextures, backdropOrder = {}, {}
end

-- How far under the ground plane the disc actually sits. A hair, and only so
-- that a flat-footed Pokemon's sole -- which is AT the ground plane -- is not
-- coplanar with it and left to the depth buffer's mercy.
VoxelBattleStage.SINK = 0.06

-- Where one disc sits: centred on a cell, at the ground plane, so a Pokemon
-- placed at that same height stands ON it rather than in it.
function VoxelBattleStage.matrix(x, groundY, z, radius)
  radius = radius or VoxelBattleStage.RADIUS
  return Mat4.mul(Mat4.translate(x, groundY - VoxelBattleStage.SINK, z),
                  Mat4.scale(radius, 1, radius))
end

-- The two platforms this frame, as (side, matrix) -- shared by the camera's
-- pass and the sun's, so the two can never disagree about where they are.
local function each(arena, groundY, fn)
  if arena.arenaStyle and arena.mid then
    fn(Mat4.mul(
      Mat4.translate(arena.mid[1], groundY - VoxelBattleStage.SINK,
                     arena.mid[2]),
      Mat4.scale(44, 1, 62)))
    return
  end
  for _, side in ipairs({ "enemy", "player" }) do
    local cell = arena[side]
    if cell then
      fn(VoxelBattleStage.matrix(cell[1], groundY, cell[2],
                                 VoxelBattleStage.radiusFor(nil)))
    end
  end
end

-- ------- the synthetic arena
--
-- A B rung does not search the map, because it does not stand on it. The
-- arena is the same WIDE shape every other staged fight uses -- so the two
-- cells are three apart down the middle and BattleCam frames them exactly as
-- it always has -- just placed at a fixed spot rather than a found one.
--
-- Away from the origin on purpose. The coordinates run through the camera
-- solve, the sun's frustum fit and the projection to Game Boy pixels, and
-- putting a stage at (0, 0) is the kind of thing that hides a sign error for
-- months.
VoxelBattleStage.ORIGIN = { 16, 16 }

function VoxelBattleStage.arena(map, style)
  local BattleArena = V.require("BattleArena")
  local arena = BattleArena.at(VoxelBattleStage.ORIGIN[1], VoxelBattleStage.ORIGIN[2],
                               "wide")
  if not arena then return nil end
  -- the map is carried for its SKY and its palette only -- what kind of place
  -- the fight is happening in -- never for its geometry
  arena.map = map
  arena.discs = true
  arena.arenaStyle = style
  arena.portableStage = style and "arena" or "discs"
  return arena
end

-- ------- the draws

-- The discs, in the main pass. No wireframe: everything else in this frame is
-- built a unit per voxel and wears the seams that fall out of that, and a
-- disc is a turned solid with no grid to draw.
function VoxelBattleStage.draw(arena, groundY)
  if not (arena and arena.discs) then return end
  local m = VoxelBattleStage.mesh()
  local tex = VoxelBattleStage.textureFor(arena)
  if not (m and tex) then return end
  Voxel3D.seams(false)
  Voxel3D.glass(false)
  each(arena, groundY, function(matrix) Voxel3D.draw(m, tex, matrix) end)
  Voxel3D.glass(true)
  Voxel3D.seams(true)
end

-- And into the sun, so the two Pokemon put real shadows on the platforms they
-- are standing on. Without this the shadow map is empty where the discs are
-- and a mon casts onto nothing at all -- which, with no ground behind it
-- either, reads as the pair floating.
function VoxelBattleStage.cast(shadowMap, arena, groundY)
  if not (arena and arena.discs and shadowMap) then return end
  local m = VoxelBattleStage.mesh()
  local tex = VoxelBattleStage.textureFor(arena)
  if not (m and tex) then return end
  each(arena, groundY, function(matrix) shadowMap.draw(m, tex, matrix) end)
end

return VoxelBattleStage
