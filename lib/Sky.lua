-- The sky, generated rather than shipped.
--
-- The overworld's, on every VOXEL rung. Wherever the diorama is drawn the void
-- behind it is sky rather than a black plate: at 75 degrees the horizon is
-- genuinely in frame and the bands run down to meet it, and at the steeper rungs
-- the void that shows is the ground running out past the map edge, which gets
-- the same sky above the same haze. A battle's placed camera keeps the flat fill
-- it has always had -- its horizon is above the frame and its look is not this
-- rung's to change.
--
-- THE RECIPE starts with DayNight's short 8-bit key palette, then expands it to
-- a ninety-six-step nearest-sampled ramp. The source colours still decide the
-- look of every hour, but no single step is tall enough to read as one of the
-- enormous curved blue stripes a low 1ST/3RD camera exposed. The steps remain
-- hard pixel colours -- this is not a filtered bitmap or an airbrushed shader.
-- The compact checker transition is retained only for the level screen path;
-- a perspective ray fan never turns it into curved checker ribbons. Moving
-- atmosphere is a separate, world-anchored sprite layer below; it never changes
-- how the colour field itself is sampled.
--
-- NOTHING IS RESAMPLED, which is the whole of why it is drawn this way. There is
-- no baked 160x144 picture scaled up to the window and no downsized buffer blown
-- back up: one full-region rectangle through a shader that answers every pixel
-- from its own canvas coordinate. A pixel of sky is computed at the size it is
-- displayed at, so there is nothing for a filter to soften and nothing to go
-- stale when the window or the zoom changes. The shader does bind one texture,
-- but it is a palette rather than an image -- the bands, one texel each, sampled
-- nearest (see rampFor, and why it is not a uniform array).
--
-- THE PIXEL GRID follows the zoom for the same reason. Bands and dither cells
-- are measured in DIORAMA pixels -- the pass's own pixels-per-world-pixel, handed
-- in fresh every frame -- so a chunky sky at 4x is a chunky sky at 12x, band
-- edges land on the same grid the world's own texels do, and a ZOOM keypress is
-- reflected in the frame that follows it rather than whenever something else
-- happened to rebuild.
--
-- PALETTE ORDER, which is easy to get wrong. Stored LIGHTEST FIRST, because that
-- is shade order: a display mode transforms a four-colour palette by replacing it
-- outright (PaletteFX.effectiveColors hands back GRAYS or CLASSIC), and those are
-- written light to dark. So the sky reads the list backwards -- deepest shade
-- overhead, shade 1 at the horizon -- and GRAY gets greys the right way up for
-- nothing.
--
-- WHAT TIME IT IS decides the colours. The palette itself lives in DayNight
-- (four phase palettes, blended along the clock and re-quantised to the
-- lattice), and this file paints whatever the clock says: blue at noon, gold
-- and violet through the twilights -- warmed further around the low sun by a
-- dithered GLOW -- and deep navy under the moon. The sun and moon themselves
-- hang here too: cell-art discs on the same grid as the dither, scissored to
-- the sky's own region so a setting body slips below the horizon point and is
-- gone, never wandering under the map.

-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local DayNight = V.require("DayNight")
local ModSetting = V.require("ModSetting")
local SkyEvents = V.require("SkyEvents")
local PaletteFX = require("src.render.PaletteFX")

local Sky = {}

-- How much sky the voxel renderer paints. This is deliberately separate
-- from DAYTIME: DAYTIME chooses the hour and therefore the colours, while
-- SKY chooses whether Kanto has a full banded sky, a cheap flat backdrop,
-- or no outdoor backdrop at all. FULL remains the established default.
Sky.setting = ModSetting.new("sky", "SKY",
  { "full", "flat", "off" }, { "FULL", "FLAT", "OFF" })

Sky.cloudSetting = ModSetting.new("clouds", "CLOUDS",
  { "on", "off" }, { "ON", "OFF" })

Sky.clock = 0

function Sky.update(dt)
  if dt and dt > 0 then Sky.clock = (Sky.clock + dt) % 65521 end
  -- Decode the one compact cloud atlas outside paint(). Graphics may not exist
  -- during module construction, so the update seam is the first safe prewarm.
  -- CLOUDS OFF deliberately avoids even this one-time I/O/allocation.
  if Sky.cloudSetting:get() ~= "off" and Sky.prewarmClouds then
    Sky.prewarmClouds()
  end
end

function Sky.mode()
  return Sky.setting:get()
end

function Sky.enabled()
  return Sky.mode() ~= "off"
end

function Sky.banded()
  return Sky.mode() == "full"
end

-- The most KEY colours a phase palette may contribute. DayNight currently has
-- six; eight leaves display-mode headroom. These are expanded below rather than
-- painted directly, because six steps across a low camera's sky become a few
-- huge curved stripes.
Sky.MAX_BANDS = 8

-- A low 65-degree 1ST/3RD view exposes only about 20 degrees of the fixed
-- 55-degree sky field. With 24 texels that was merely 8-9 visible colours --
-- 40-49 canvas pixels per ring in the native 1710x1069 pilot. Ninety-six puts
-- about 35 colours in the same slice (roughly 10-12 crisp pixels per ring),
-- while the complete nearest-sampled RGBA8 texture is still only 384 bytes.
-- The pass remains one rectangle / one draw call, and water consumes this exact
-- same ramp and count.
Sky.GRADIENT_BANDS = 96
Sky.GRADIENT_RGBA_BYTES = Sky.GRADIENT_BANDS * 4

-- The checkerboard between bands. DITHER_START is how far down a band it begins,
-- as a fraction of that band: lower is a wider blend, and 1 switches it off. 0.6
-- leaves the top of each band flat -- a band dithered all the way through reads
-- as one averaged colour instead of as a step with a soft bottom edge.
Sky.DITHER = true
Sky.DITHER_START = 0.6

-- A checker transition looks intentional on the level, screen-linear sky,
-- where its cells stay square and the transition is only a few rows tall. On
-- a perspective ray fan the same angular grid projects into broad curved
-- checker ribbons (especially in 3RD at a low pitch), which are easily read as
-- enormous striped clouds. Keep the world-anchored colour bands, but make
-- their transitions clean in free cameras; the actual clouds below provide
-- the pixel texture there.
Sky.RAY_DITHER = false

function Sky.ditherStart(ray)
  return Sky.DITHER and (not ray or Sky.RAY_DITHER)
         and Sky.DITHER_START or 2
end

-- How much of the frame the bands cover when the horizon is NOT in it, as a
-- fraction of the canvas height.
--
-- At the steeper rungs the camera looks down far enough that the ground plane's
-- vanishing line is above the top edge -- there is no horizon to hang the pale
-- end on, but there is still void up there where the map runs out, and it should
-- read as sky. So the bands take the same slice of the frame the top rung's own
-- horizon gives them, which keeps the sky looking like one sky across the whole
-- ladder instead of changing character rung by rung.
Sky.SPAN = 0.23

-- How much ELEVATION the gradient spans above the horizon, in radians, for
-- a caller that anchors the sky IN SPACE rather than to the frame (the VR
-- eyes -- see Voxel3D.beginScene). On the flat screen the bands run from
-- the top edge of the frame down to the horizon, which is right for a
-- camera whose pitch is the rung's: the frame IS the window on the sky.
-- A headset's frame is wherever the head points, so glueing the zenith
-- band to its top edge drags the whole gradient around with the head. An
-- anchored caller instead hangs the gradient over a fixed slice of sky --
-- horizon to ELEV_SPAN up -- and hands paint() the canvas row that span's
-- top lands on this frame (the `top` argument), so tilting the head slides
-- the frame across a sky that stays put.
Sky.ELEV_SPAN = math.rad(55)

-- ------- the bands
--
-- Top first, each a { r, g, b } in 0..1, as the display mode has them.
--
-- Memoised, because this runs once a frame and the answer only moves when the
-- mode does.
local cache = {
  bands = nil, anchors = nil, key = {}, ramp = nil, anchorCount = nil,
}

-- Expand the few authored/display-mode key colours into the fine ramp without
-- adding a texture filter. Interpolation happens only when the tiny palette is
-- rebuilt (normally once per clock second); every frame and every reflected
-- water pixel still performs one nearest texel lookup. Endpoints are exact, so
-- haze at the horizon and the deepest zenith shade cannot drift from DayNight.
local function densify(anchors, count)
  local n = #anchors
  if n < 1 or count < 1 then return {} end
  local result = {}
  if n == 1 or count == 1 then
    local c = anchors[1]
    for i = 1, count do result[i] = { c[1], c[2], c[3] } end
    return result
  end
  for i = 1, count do
    local p = (i - 1) / (count - 1) * (n - 1)
    local a = math.floor(p) + 1
    local b = math.min(a + 1, n)
    local t = p - math.floor(p)
    local ca, cb = anchors[a], anchors[b]
    result[i] = {
      ca[1] + (cb[1] - ca[1]) * t,
      ca[2] + (cb[2] - ca[2]) * t,
      ca[3] + (cb[3] - ca[3]) * t,
    }
  end
  return result
end

Sky._densify = densify             -- focused palette/runtime contract seam

function Sky.bands()
  local pal = DayNight.palette()
  local shades = PaletteFX.effectiveColors(pal) or pal
  local n = math.min(#shades, #pal, Sky.MAX_BANDS)
  local key, k = cache.key, 0
  local same = cache.bands ~= nil
               and #cache.bands == Sky.GRADIENT_BANDS
               and cache.anchorCount == n
  for i = 1, n do
    local c = shades[i]
    for ch = 1, 3 do
      k = k + 1
      if key[k] ~= c[ch] then same = false end
      key[k] = c[ch]
    end
  end
  if same then return cache.bands end

  -- the ramp is these bands as a texture (see rampFor); a new list is a new
  -- ramp, and the old one is nothing's to keep
  if cache.ramp and cache.ramp.release then pcall(cache.ramp.release, cache.ramp) end
  cache.ramp, cache.rampFor = nil, nil

  local anchors = {}
  for i = 1, n do
    -- backwards: the palette's darkest key is the top of the gradient
    local c = shades[n - i + 1]
    anchors[i] = { c[1] / 255, c[2] / 255, c[3] / 255 }
  end
  local bands = densify(anchors, Sky.GRADIENT_BANDS)
  cache.anchorCount = n
  cache.anchors = anchors
  cache.bands = bands
  return bands
end

-- The hour's haze -- the palest band, in 0..1 -- which is both the sky's
-- bottom edge and the right flat fill for any outdoor void that wants to
-- match the clock without painting bands (the battle arena's backdrop).
function Sky.haze()
  local bands = Sky.bands()
  return bands and bands[#bands] or nil
end

-- Put the sky onto a flat descriptor: the bands to paint, plus the flat fill
-- replaced by the palest of them. That fill is what the caller CLEARS to, so
-- making it the bottom band's own colour means the haze below the sky and the
-- bottom of the sky are one colour -- the join has no seam, and a frame that
-- cannot paint the bands is a hazy sky rather than a wrong one.
--
-- Mutates the descriptor, which is a fresh table per frame from its caller.
function Sky.dress(sky)
  if not Sky.enabled() then return nil end
  if not Sky.banded() then
    if sky then sky.bands = nil end
    return sky
  end
  local bands = Sky.bands()
  local haze = bands and bands[#bands]
  if not (sky and haze) then return sky end
  sky[1], sky[2], sky[3] = haze[1], haze[2], haze[3]
  sky.bands = bands
  return sky
end

-- Where the sky's bottom edge goes, in canvas pixels: the camera's own horizon
-- when that is in frame, and SPAN of the frame when it is not (see SPAN). nil
-- when there is no room for any of it.
function Sky.region(h, horizonY)
  if not (h and h > 0) then return nil end
  local edge = horizonY
  if not (edge and edge > 0) then edge = h * Sky.SPAN end
  edge = math.min(edge, h)
  if edge < 1 then return nil end
  return edge
end

-- ------- the pass
--
-- One rectangle, one shader. Every pixel answers for itself from its canvas
-- coordinate, so the sky is drawn at exactly the resolution it is displayed at
-- -- there is no image being scaled and so nothing to be soft. The one texture
-- bound is the band ramp, which is a PALETTE and not a picture: n texels wide,
-- sampled nearest, one lookup per pixel (see rampFor).
--
-- `cell` quantises BOTH the band edges and the dither: the y a pixel is judged
-- by is the top of its own cell row, so a whole cell row is one colour and every
-- edge in the sky lands on the diorama's pixel grid.
local SHADER_SRC = [[
uniform Image ramp;     // the bands, one texel each, top of the sky first
uniform float count;    // how many texels wide that ramp is
uniform float edge;     // the sky's bottom, in canvas pixels
uniform float top;      // where the deepest band begins, in canvas pixels --
                        // 0 glues the gradient to the frame (the flat
                        // screen); an anchored caller passes the row its
                        // fixed elevation span starts on, often negative
uniform float cell;     // the diorama's pixel size, in canvas pixels
uniform float start;    // where the checker begins inside a band
uniform float axisX;    // the "toward the ground" direction on the canvas:
uniform float axisY;    // (0,1) for a level camera; a rolled VR eye tips
                        // it, and edge/top are distances along it
uniform vec3 rayBase;   // the eye's ray fan (VRRig eyeCamera.skyRay): a
uniform vec3 rayDu;     // canvas point at fractions (u, v) looks along
uniform vec3 rayDv;     // base + u*du + v*dv, world axes -- so each pixel
                        // knows its TRUE elevation and the gradient is a
                        // real skybox, untouched by any head motion
uniform float raySpan;  // radians of elevation the gradient covers
uniform vec2 invSize;   // 1/w, 1/h: canvas pixels to fractions
uniform float useRay;   // 0 = the flat screen's frame-linear gradient
uniform float cellAng;  // one checker cell in RADIANS (ray path): the
                        // dither's own grid, laid on azimuth/elevation so
                        // the pattern is glued to the SKY -- a screen-cell
                        // parity flips under every head motion and the
                        // whole gradient shimmers
uniform float alpha;
uniform float glowAmt;  // twilight warmth around the low sun; 0 = none
uniform vec2 glowPos;   // the sun disc, in canvas pixels (flat path)
uniform float glowInvR; // 1 / the glow's reach in pixels (flat path)
uniform vec3 glowDir;   // the sun's world direction (ray path)
uniform float glowInvA; // 1 / the glow's reach in radians (ray path)
uniform vec3 glowColor;

// Band `i`, read from its own texel centre. The index is clamped rather than
// trusted: `pos` below can land exactly on `count` when the arithmetic is
// carried at mediump -- which is the fragment default on GLSL ES -- and a
// sample past the last band must be the last band, not whatever is off the
// end of the image.
vec3 bandAt(float i) {
  return Texel(ramp, vec2((clamp(i, 0.0, count - 1.0) + 0.5) / count, 0.5)).rgb;
}

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
  float tn;
  float parity;
  float glowD = 2.0;                                  // past the reach
  if (useRay > 0.5) {
    // A SKYBOX, computed instead of stored: the pixel's own ray lands in
    // a cell of the sky's angular grid (azimuth columns and elevation
    // rows, cellAng square), and EVERYTHING -- the band, the checker's
    // parity, the glow -- is answered from that cell's centre. The
    // screen grid quantises nothing here; that is the point. A screen
    // quantisation of similar pitch laid under the sky grid beats
    // against it (moire), and every subpixel head motion re-snaps the
    // beat -- the fizz. Sampled per pixel, the picture is exactly a
    // nearest-filtered texture on a dome: its cells slide smoothly with
    // the world and no motion of the head recomputes the pattern. The
    // one seam, where azimuth wraps behind the camera, is a single cell
    // column of a dither pattern.
    vec3 dir = rayBase + rayDu * (sc.x * invSize.x)
                       + rayDv * (sc.y * invSize.y);
    float elev = atan(dir.y, length(dir.xz));
    float ei = floor(elev / cellAng);                 // elevation row
    if (ei < 0.0) { discard; }                        // below the horizon
    float ai = floor(atan(dir.x, dir.z) / cellAng);   // azimuth column
    float elc = (ei + 0.5) * cellAng;                 // the row's centre
    tn = 1.0 - clamp(elc / max(raySpan, 0.001), 0.0, 1.0);
    parity = mod(ai + ei, 2.0);
    if (glowAmt > 0.0) {
      // the glow by the angle between the CELL's centre direction and
      // the sun's own, so its rings are pinned to the same sky grid
      float azc = (ai + 0.5) * cellAng;
      vec3 cd = vec3(cos(elc) * sin(azc), sin(elc), cos(elc) * cos(azc));
      glowD = acos(clamp(dot(cd, glowDir), -1.0, 1.0)) * glowInvA;
    }
  } else {
    vec2 cc0 = floor(sc / cell) * cell;               // top of this cell
    float row = cc0.x * axisX + cc0.y * axisY;        // along the axis
    if (row > edge) { discard; }                      // below the horizon
    tn = clamp((row - top) / max(edge - top, 1.0), 0.0, 1.0);
    parity = mod(floor(sc.x / cell) + floor(sc.y / cell), 2.0);
    if (glowAmt > 0.0) {
      vec2 cc = (floor(sc / cell) + 0.5) * cell;
      glowD = length(cc - glowPos) * glowInvR;
    }
  }
  float pos = tn * count;
  float base = min(floor(pos), count - 1.0);
  vec3 c = bandAt(base);
  if (base < count - 1.0 && (pos - base) > start) {
    if (parity < 0.5) { c = bandAt(base + 1.0); }
  }
  // The sunset's warmth, radiating from the disc: posterised to a few rungs
  // and checker-dithered between them -- the same 8-bit move as the bands,
  // so the glow reads as painted light rather than as a smooth airbrush --
  // measured cell-to-cell on the flat frame and angle-to-angle on the
  // skybox, so its rings ride whichever grid the checker itself is on.
  if (glowAmt > 0.0) {
    float g = glowAmt * pow(clamp(1.0 - glowD, 0.0, 1.0), 2.0);
    float lvl = floor(g * 4.0);
    if (g * 4.0 - lvl > 0.5 && parity < 0.5) { lvl += 1.0; }
    c = mix(c, glowColor, min(lvl / 3.0, 1.0) * 0.65);
  }
  return vec4(c, alpha);
}
]]

-- ------- the ramp
--
-- The fine ramp as a one-texel-per-step TEXTURE rather than as a uniform array,
-- which is what they used to be: `uniform vec3 bands[8]`, filled from Lua and
-- read through a loop counter. On desktop GL that is as portable as it looks.
-- On Android it was not. The sky's lower bands came back BLACK -- a hard-edged
-- strip running from partway down the gradient to the horizon point, with the
-- moon still drawn correctly over it, and with the haze BELOW the sky (the
-- palest band again, but delivered by love.graphics.clear instead of by the
-- array) landing in exactly the right colour. Same colour, two routes, one of
-- them black: the fault was the array, not the palette.
--
-- Which of the ES failure modes it was hardly matters -- a driver that
-- truncates a partially-filled array, a fragment uniform budget the guaranteed
-- floor of which is sixteen vectors (eight bands plus the glow plus LOVE's own
-- built-ins is over it), a reflection that finds bands[0] and nothing after --
-- because they all have the same shape: slots past the first few read as zero,
-- and zero is black.
--
-- A sampler has none of them. One texture unit replaces an array of uniforms,
-- there is no array to index and no budget to overrun, and a texel that does
-- not exist cannot read as black because the image is built at exactly the
-- width the shader divides by. Nearest and clamped, so a sample lands on one
-- band's own colour and an out-of-range one lands on the end band rather than
-- on nothing.
--
-- Rebuilt only when the key colours move, which is when the clock or the display
-- mode does; Sky.bands drops it as it rebuilds the 96-step list. At RGBA8 the
-- complete allocation is 384 bytes, with no mip chain.
local function rampFor(bands)
  if cache.ramp and cache.rampFor == bands then return cache.ramp end
  if not (love.image and love.image.newImageData
          and love.graphics and love.graphics.newImage) then return nil end
  local n = #bands
  if n < 1 then return nil end
  local ok, data = pcall(love.image.newImageData, n, 1)
  if not (ok and data) then return nil end
  for i = 1, n do
    local c = bands[i]
    pcall(data.setPixel, data, i - 1, 0, c[1], c[2], c[3], 1)
  end
  local built, img = pcall(love.graphics.newImage, data)
  if not (built and img) then return nil end
  -- nearest: a band is a flat colour, not something to interpolate between.
  -- clamp: the shader clamps its index too, so this is the second of two
  -- guards against ever sampling off the end -- and it returns the edge band.
  pcall(img.setFilter, img, "nearest", "nearest")
  pcall(img.setMipmapFilter, img, nil)
  pcall(img.setWrap, img, "clamp", "clamp")
  cache.ramp, cache.rampFor = img, bands
  return img
end

Sky._rampFor = rampFor            -- named for the suite

-- The band ramp for the CURRENT bands, plus how many texels wide it is --
-- for a pass that wants to read the same sky this one paints. The water's
-- reflection is the one caller: it looks the reflected direction up on this
-- very ramp, so the sky on the lake and the sky over it are one palette,
-- through one display-mode transform, off one clock.
--
-- nil where the ramp could not be built, which is exactly when Sky.paint
-- falls back to flat bands -- so a driver that loses the gradient loses the
-- reflected gradient with it rather than showing two different skies.
function Sky.ramp()
  if not Sky.banded() then return nil end
  local bands = Sky.bands()
  if not (bands and bands[1]) then return nil end
  local img = rampFor(bands)
  if not img then return nil end
  return img, #bands, bands
end

-- How far the twilight glow reaches around the disc, in canvas pixels, for
-- a `w`-wide frame. The same number Sky.paint sends as `glowInvR`.
Sky.GLOW_REACH = 0.55

local shader = nil            -- nil = untried, false = unavailable

local function getShader()
  if shader == nil then
    shader = false
    if love.graphics and love.graphics.newShader then
      local ok, sh = pcall(love.graphics.newShader, SHADER_SRC)
      if ok and sh then
        shader = sh
      elseif V and V.mod and V.mod.log then
        -- once, and only where it can be read: the fallback below is a sky
        -- without its dither, which is easy to look at and impossible to
        -- diagnose without this line
        V.mod.log:warn("sky shader did not compile: %s -- the bands draw flat, "
                       .. "with no dither between them", tostring(sh))
      end
    end
  end
  return shader or nil
end

Sky._getShader = getShader        -- named for the suite

-- The flat fallback: the authored key colours as solid rectangles, no checker,
-- on the same quantised edges. A driver that cannot compile the one-draw shader
-- therefore keeps the old bounded draw count (normally six), rather than turning
-- the 96 palette texels into 96 rectangle calls. Every supported GPU uses the
-- fine ramp above; this path is also what headless contract runs exercise.
local function paintFlat(w, h, bands, edge, alpha, cell, top)
  local g = love.graphics
  local paintBands = (bands == cache.bands and cache.anchors) or bands
  local n = #paintBands
  local span = edge - (top or 0)
  local prev = 0
  for i = 1, n do
    local cut = (i == n) and math.min(h, math.ceil(edge))
                or math.floor(((top or 0) + i / n * span) / cell + 0.5) * cell
    cut = math.max(prev, math.min(cut, math.min(h, math.ceil(edge))))
    if cut > prev then
      local c = paintBands[i]
      g.setColor(c[1], c[2], c[3], alpha)
      g.rectangle("fill", 0, prev, w, cut - prev)
    end
    prev = cut
  end
end

-- ------- the discs
--
-- The sun and moon, as cell art: a circle of whole diorama cells with a
-- lighter core, a dithered rim, and -- for the moon -- a few fixed crater
-- cells. Drawn as plain rectangles on the same grid as the sky's own dither,
-- through the same display-mode transform as every palette here, and
-- SCISSORED to the sky's region: the horizon point is where a setting body
-- disappears, so it can never hang under the map at a high pitch.
--
-- SIZED BY THE FRAME, not by the world: a celestial body's apparent size is
-- an angle, so zooming the ground in and out must not swell and shrink the
-- sun with it. The radius is a fraction of the frame height, converted to
-- whole cells so the disc still sits on the diorama's grid -- chunky cells
-- up close, fine ones at survey zoom, the same size body either way.
Sky.DISC_FRAC = 0.030     -- disc radius, as a fraction of the frame height
Sky.DISC_MIN = 3          -- but never fewer cells than this across a radius

-- crater centres as fractions of the radius, so they ride any disc size.
-- Public because the water's reflection draws the same moon (see Water):
-- one list, so the disc on the lake cannot drift from the one in the sky.
Sky.MOON_CRATERS = { { -0.4, -0.2 }, { 0.2, 0.45 }, { 0.5, -0.4 },
                     { -0.15, 0.7 }, { 0.05, 0.05 } }

-- a crater's radius, as a fraction of the disc's -- the r/5 paintDisc uses
Sky.CRATER_FRAC = 0.2

local MOON_CRATERS = Sky.MOON_CRATERS

-- The disc's four shades as the display mode has them, lightest first.
-- Shared with the reflection pass, so the sun on the water is the same sun
-- that is in the sky, in the same mode's palette.
function Sky.discShades(moon)
  local src = moon and DayNight.MOON_COLORS or DayNight.SUN_COLORS
  return PaletteFX.effectiveColors(src) or src
end

-- Whether this body is the LOOMING low sun -- the sunset exaggeration.
local function looming(body)
  return (body.glowAmt or 0) > 0.25 and not body.moon
end

-- The disc's radius for a `h`-tall frame on a `cell`-pixel grid: in CANVAS
-- PIXELS, and in whole cells. Sized by the FRAME rather than by the world
-- (see DISC_FRAC), so a zoom does not swell the sun.
--
-- Read by paintDisc below and by the reflection, which needs the same
-- number in radians -- a disc drawn one size and mirrored another would
-- read as two different suns.
function Sky.discRadius(h, cell, body)
  cell = math.max(1, cell or 1)
  local r = math.max(Sky.DISC_MIN,
                     math.floor(h * Sky.DISC_FRAC / cell + 0.5))
  -- Authored Arena Scenery may expose only a shallow live-sky aperture while
  -- its battle canvas still uses a comparatively coarse diorama grid.  The
  -- ordinary three-cell minimum can therefore collapse the moon into a tiny
  -- plus sign at phone scale.  Arena bodies opt into a bounded enlargement of
  -- the SAME cell-art disc; free cameras and the reflected world disc keep the
  -- established apparent size.
  local scale = body and tonumber(body.discScale) or 1
  if scale ~= scale or scale == math.huge or scale == -math.huge then scale = 1 end
  scale = math.max(1, math.min(2, scale))
  r = math.max(r, math.floor(r * scale + 0.5))
  if body and looming(body) then r = r + math.max(1, math.floor(r * 0.4)) end
  return r * cell, r
end

-- One disc's worth of cell art -- shared verbatim by the screen-space
-- painter below (the flat screen) and by the BAKE the VR eyes texture
-- their world-anchored quad with (Sky.discImage). `plot(dx, dy, c)` gets
-- every kept cell in disc-local cell coordinates and its 0..255 colour.
local function discCells(r, moon, shades, twilight, plot)
  local core = shades[1]
  local main = shades[twilight and 3 or 2]
  local craterR = math.max(1, math.floor(r / 5))
  for dy = -r, r do
    for dx = -r, r do
      local d = math.sqrt(dx * dx + dy * dy)
      if d <= r + 0.1 then
        local c = d <= r * 0.5 and core or main
        -- dithered rim: the outer ring keeps only one parity of its cells
        local keep = d <= r - 0.9 or (dx + dy) % 2 == 0
        if moon then
          for _, cr in ipairs(MOON_CRATERS) do
            local cdx = dx - math.floor(cr[1] * r + 0.5)
            local cdy = dy - math.floor(cr[2] * r + 0.5)
            if cdx * cdx + cdy * cdy <= craterR * craterR then
              c = shades[3]
            end
          end
        end
        if keep then plot(dx, dy, c) end
      end
    end
  end
end

local function paintDisc(body, edge, cell, w, h)
  local g = love.graphics
  if not (body and body.y and g.setScissor) then return end
  local shades = Sky.discShades(body.moon)
  local twilight = looming(body)
  local _, r = Sky.discRadius(h, cell, body)
  -- snap the centre to the cell grid, like everything else in this sky
  local bx = math.floor(body.x / cell) * cell + cell / 2
  local by = math.floor(body.y / cell) * cell + cell / 2
  if by - r * cell > edge then return end     -- wholly below the horizon point
  local sx, sy, sw, sh = g.getScissor()
  g.setScissor(0, 0, math.ceil(w), math.floor(edge))
  discCells(r, body.moon, shades, twilight, function(dx, dy, c)
    g.setColor(c[1] / 255, c[2] / 255, c[3] / 255, 1)
    g.rectangle("fill", bx + dx * cell - cell / 2,
                by + dy * cell - cell / 2, cell, cell)
  end)
  if sx then g.setScissor(sx, sy, sw, sh) else g.setScissor() end
  g.setColor(1, 1, 1, 1)
end

-- ------- clouds, stars and shooting stars
--
-- The original atmosphere painter chose every cloud and star directly in
-- CANVAS coordinates. That is harmless for the pitch-only orbit (there is no
-- yaw to reveal the shortcut), but 1ST and 3RD can turn freely: a cloud glued
-- to x=40 on the canvas then turns with the player's head instead of staying
-- over the same part of Kanto.
--
-- A free-pitch camera already hands the sky its ray fan. The helpers below use
-- that fan in reverse: a stable WORLD direction is intersected with the
-- camera's image plane and becomes a canvas point. Clouds are allowed to drift
-- through world azimuth over time, but moving the camera never changes their
-- direction; stars are completely fixed. The pitch-only orbit keeps its
-- established screen composition, while every camera with a ray fan gets the
-- honest world-space path.

local TAU = math.pi * 2
local GOLDEN_ANGLE = math.pi * (3 - math.sqrt(5))

local function wrapPi(a)
  return (a + math.pi) % TAU - math.pi
end

-- A bearing/elevation pair as a unit direction in the voxel world's axes.
-- Bearing zero is +Z, matching FirstPerson's yaw. DayNight.body uses its own
-- astronomical bearing convention and already returns an explicit vector.
function Sky.direction(azimuth, elevation)
  local ce = math.cos(elevation or 0)
  return { math.sin(azimuth or 0) * ce, math.sin(elevation or 0),
           math.cos(azimuth or 0) * ce }
end

-- Project one WORLD direction through the affine ray fan built by Voxel3D.
--
-- The fan says that canvas fraction (u,v) looks along
--     base + u*du + v*dv.
-- We solve for the point where that direction is parallel to `direction`.
-- A positive scale is in front of the eye; a negative one is the opposite
-- half of the sky and must not wrap onto the display. Returns x, y and whether
-- the centre lies inside the canvas. Off-canvas forward points still return
-- their coordinates so a caller may admit a wide sprite by its own margin.
local function projectXYZ(ray, w, h, dx, dy, dz)
  if not (ray and ray.base and ray.du and ray.dv
          and dx and dy and dz and w and h and w > 0 and h > 0) then
    return nil, nil, false
  end
  local dl = math.sqrt(dx * dx + dy * dy + dz * dz)
  if dl < 1e-9 then return nil, nil, false end
  dx, dy, dz = dx / dl, dy / dl, dz / dl
  local b, du, dv = ray.base, ray.du, ray.dv
  -- cross(dv, d) and cross(du, d), kept scalar: this runs once per visible
  -- star/cloud candidate and must not create hundreds of short-lived tables
  -- per frame on iPhone.
  local nux = dv[2] * dz - dv[3] * dy
  local nuy = dv[3] * dx - dv[1] * dz
  local nuz = dv[1] * dy - dv[2] * dx
  local nvx = du[2] * dz - du[3] * dy
  local nvy = du[3] * dx - du[1] * dz
  local nvz = du[1] * dy - du[2] * dx
  local denU = du[1] * nux + du[2] * nuy + du[3] * nuz
  local denV = dv[1] * nvx + dv[2] * nvy + dv[3] * nvz
  if math.abs(denU) < 1e-9 or math.abs(denV) < 1e-9 then
    return nil, nil, false
  end
  local u = -(b[1] * nux + b[2] * nuy + b[3] * nuz) / denU
  local v = -(b[1] * nvx + b[2] * nvy + b[3] * nvz) / denV
  local px = b[1] + du[1] * u + dv[1] * v
  local py = b[2] + du[2] * u + dv[2] * v
  local pz = b[3] + du[3] * u + dv[3] * v
  if px * dx + py * dy + pz * dz <= 1e-7 then return nil, nil, false end
  local x, y = u * w, v * h
  return x, y, u >= 0 and u <= 1 and v >= 0 and v <= 1
end

function Sky.projectDirection(ray, w, h, direction)
  if not direction then return nil, nil, false end
  return projectXYZ(ray, w, h, direction[1], direction[2], direction[3])
end

-- Convenience form used by atmosphere/event painters.
function Sky.projectSky(ray, w, h, azimuth, elevation)
  if type(azimuth) ~= "number" or type(elevation) ~= "number" then
    return nil, nil, false
  end
  local ce = math.cos(elevation or 0)
  return projectXYZ(ray, w, h, math.sin(azimuth or 0) * ce,
                    math.sin(elevation or 0), math.cos(azimuth or 0) * ce)
end

-- One projection closure for optional sky-event painters. Production cameras
-- always supply their true ray fan, including the orbit's atmosphere-only fan.
-- The fallback below is for headless/compatibility callers: the orbit looks
-- north (-Z, azimuth pi), and `edge` lets elevation meet its real horizon.
function Sky.projector(ray, w, h, edge)
  if ray then
    return function(azimuth, elevation)
      return Sky.projectSky(ray, w, h, azimuth, elevation)
    end
  end
  edge = math.max(1, math.min(h or 1, edge or (h or 1) * Sky.SPAN))
  local halfAz = math.rad(52)
  return function(azimuth, elevation)
    local relative = wrapPi((azimuth or math.pi) - math.pi)
    local x = (0.5 + relative / (halfAz * 2)) * w
    local y = edge * (1 - (elevation or 0) / Sky.ELEV_SPAN)
    return x, y, x >= 0 and x <= w and y >= 0 and y <= edge
  end
end

local function nightStrength()
  local mix = DayNight.mix(DayNight.time())
  return math.min(1, (mix.night or 0) + (mix.violet or 0) * 0.8
                     + (mix.dusk or 0) * 0.15)
end

Sky.CLOUD_COUNT = 18
Sky.CLOUD_MAX_DRAWS = Sky.CLOUD_COUNT
Sky.CLOUD_DRIFT = math.rad(0.22) -- world radians per second, a slow high wind

-- Four authored 128x128 transparent sprites in one row. The atlas is a single
-- 256 KiB RGBA8 GPU allocation (plus negligible Quad metadata), shared by all
-- eighteen stable cloud addresses. No per-cloud texture and no mip chain.
Sky.CLOUD_ASSET = {
  path = "assets/sky/clouds.png",
  width = 512, height = 128,
  frameWidth = 128, frameHeight = 128, frames = 4,
  rgbaBytes = 512 * 128 * 4,
}

local cloudAtlas = { state = "cold", image = nil, quads = nil, error = nil }

local function releaseCloudAtlas()
  if cloudAtlas.image and cloudAtlas.image.release then
    pcall(cloudAtlas.image.release, cloudAtlas.image)
  end
end

function Sky.invalidateCloudAsset()
  releaseCloudAtlas()
  cloudAtlas = { state = "cold", image = nil, quads = nil, error = nil }
end

function Sky.cloudAssetStatus()
  return cloudAtlas.state, cloudAtlas.error
end

-- One explicit, idempotent prewarm. A missing/invalid image fails closed and
-- stays failed rather than attempting filesystem I/O from a later paint call.
-- Returns (ready, attempted), where attempted is 1 only for the decode pass.
function Sky.prewarmClouds()
  if Sky.cloudSetting:get() == "off" then return false, 0 end
  if cloudAtlas.state == "ready" then return true, 0 end
  if cloudAtlas.state ~= "cold" then return false, 0 end
  local graphics = love and love.graphics or nil
  if not (graphics and type(graphics.newImage) == "function"
          and type(graphics.newQuad) == "function") then
    return false, 0 -- graphics can become available on a later update
  end
  if type(V.path) ~= "string" then
    cloudAtlas.state, cloudAtlas.error = "missing", "path"
    return false, 1
  end

  cloudAtlas.state = "loading"
  local spec = Sky.CLOUD_ASSET
  local source = V.path .. "/" .. spec.path
  local ok, image = pcall(graphics.newImage, source,
                          { mipmaps = false, linear = false })
  if not ok or not image then
    -- LÖVE versions predating ImageSettings already default to no mipmaps.
    ok, image = pcall(graphics.newImage, source)
  end
  if not ok or not image then
    cloudAtlas.state, cloudAtlas.error = "missing", "decode"
    return false, 1
  end
  if image.setFilter then
    pcall(image.setFilter, image, "nearest", "nearest", 1)
  end
  if image.setMipmapFilter then pcall(image.setMipmapFilter, image, nil) end
  local dimOk, width, height = pcall(image.getDimensions, image)
  if not dimOk or width ~= spec.width or height ~= spec.height then
    if image.release then pcall(image.release, image) end
    cloudAtlas.state, cloudAtlas.error = "invalid", "dimensions"
    return false, 1
  end

  local quads = {}
  for frame = 0, spec.frames - 1 do
    local quadOk, quad = pcall(graphics.newQuad,
      frame * spec.frameWidth, 0, spec.frameWidth, spec.frameHeight,
      spec.width, spec.height)
    if not quadOk or not quad then
      if image.release then pcall(image.release, image) end
      cloudAtlas.state, cloudAtlas.error = "invalid", "quad"
      return false, 1
    end
    quads[frame + 1] = quad
  end
  cloudAtlas.state, cloudAtlas.error = "ready", nil
  cloudAtlas.image, cloudAtlas.quads = image, quads
  return true, 1
end

-- Stable sky address for cloud `i`. Time moves the CLOUD through the world;
-- the camera is deliberately absent from this calculation.
function Sky.cloudDirection(i, clock)
  local az, el = Sky.cloudAngles(i, clock)
  return Sky.direction(az, el), az, el
end

function Sky.cloudAngles(i, clock)
  i = math.max(1, math.floor(i or 1))
  -- Three wind/elevation layers keep the sky varied without spawning or
  -- destroying anything. Their addresses remain functions of (i, clock)
  -- alone: camera yaw/pitch never enters the result.
  local layer = (i - 1) % 3
  local speed = Sky.CLOUD_DRIFT * (0.76 + layer * 0.11 + (i % 4) * 0.025)
  local az = wrapPi(i * GOLDEN_ANGLE + (clock or Sky.clock) * speed)
  local el = math.rad(13 + layer * 6 + ((i * 7) % 6))
  return az, el
end

-- Deterministic art/size assignment, independent of clock and camera. Square
-- source cells include transparent breathing room, so these dimensions match
-- the old puffs' visible footprint while allowing softer authored contours.
function Sky.cloudVisual(i, cell)
  i = math.max(1, math.floor(i or 1))
  cell = math.max(1, cell or 1)
  local variant = ((i * 3 + math.floor(i / 4)) % Sky.CLOUD_ASSET.frames) + 1
  local cells = 12 + ((i * 5) % 4) * 2
  if i % 4 == 0 then cells = cells + 4 end
  local size = cells * cell
  return variant, size, size
end

local function paintClouds(w, h, edge, cell, alpha, ray, night)
  if Sky.cloudSetting:get() == "off" then return end
  if cloudAtlas.state ~= "ready" then return end
  local g = love and love.graphics or nil
  if not (g and type(g.draw) == "function" and type(g.setColor) == "function") then
    return
  end
  local shade = 1 - night * 0.55
  -- Use the same bearing/elevation projection in every camera. The nil-ray
  -- projector is the north-facing compatibility/orbit view, not a new set of
  -- canvas coordinates, so no cloud can follow a turn of the camera.
  local project = Sky.projector(ray, w, h, edge)
  -- Every cloud shares the hour/weather tint, so bind it once rather than
  -- creating eighteen redundant graphics-state changes in the worst case.
  g.setColor(shade, shade, math.min(1, shade + 0.04), alpha * 0.88)
  for i = 1, Sky.CLOUD_COUNT do
    local variant, width, height = Sky.cloudVisual(i, cell)
    local az, el = Sky.cloudAngles(i, Sky.clock)
    local x, y = project(az, el)
    -- Admit an off-canvas centre only while transparent atlas bounds can still
    -- reach the scissor. An admitted cloud is exactly one textured draw.
    local mx, my = width * 0.5, height * 0.5
    if x and x >= -mx and x <= w + mx and y >= -my and y <= edge + my then
      g.draw(cloudAtlas.image, cloudAtlas.quads[variant], x, y, 0,
             width / Sky.CLOUD_ASSET.frameWidth,
             height / Sky.CLOUD_ASSET.frameHeight,
             Sky.CLOUD_ASSET.frameWidth * 0.5,
             Sky.CLOUD_ASSET.frameHeight * 0.5)
    end
  end
  g.setColor(1, 1, 1, 1)
end

Sky._paintClouds = paintClouds -- focused headless budget/zero-work QA seam

-- Night is still a zero-work path by day, but when it is visible the old
-- 160 identical blue-white squares were too uniform to read as a real sky.
-- Keep the field deterministic/world-fixed and expand it with five bounded
-- colour/size/twinkle families. Rectangles remain texture-free and allocate
-- no retained GPU memory.
Sky.STAR_COUNT = 224
Sky.FALLBACK_STAR_COUNT = 72
Sky.STAR_VARIANTS = {
  { color = { 0.96, 0.98, 1.00 }, cells = 1, speed = 1.7 },
  { color = { 0.78, 0.88, 1.00 }, cells = 1, speed = 2.1 },
  { color = { 1.00, 0.90, 0.70 }, cells = 1, speed = 1.3 },
  { color = { 0.90, 0.80, 1.00 }, cells = 1, speed = 2.6 },
  { color = { 1.00, 0.98, 0.86 }, cells = 2, speed = 1.1 },
}

function Sky.starVisual(i)
  i = math.max(1, math.floor(i or 1))
  local variant = ((i * 11 + math.floor(i / 7)) % #Sky.STAR_VARIANTS) + 1
  local visual = Sky.STAR_VARIANTS[variant]
  return visual.color, visual.cells, visual.speed, i * 1.37
end

local starDirections = {}

-- A deterministic low-discrepancy scatter over the upper hemisphere. Stars
-- never read Sky.clock here: only their brightness twinkles, never their place.
function Sky.starDirection(i)
  i = math.max(1, math.floor(i or 1))
  if starDirections[i] then return starDirections[i] end
  local az = wrapPi(i * GOLDEN_ANGLE)
  local u = ((i * 73) % 167 + 0.5) / 167
  local el = math.asin(0.06 + u * 0.92)
  local direction = Sky.direction(az, el)
  starDirections[i] = direction
  return direction, az, el
end

-- Three small, deliberately abstract Pokemon constellations. They are point
-- drawings, not borrowed sprite pixels: ears and a lightning tail, a fish
-- body and tail, and a long neck over a shell. Their fixed bearing/elevation
-- makes them genuine places in Kanto's sky instead of HUD ornaments.
Sky.CONSTELLATIONS = {
  {
    id = "PIKACHU", az = math.rad(-52), el = math.rad(48),
    color = { 1.00, 0.90, 0.58 },
    points = {
      { -2.0, -1.0 }, { -3.2, 3.0 }, { -1.2, 1.3 },
      {  1.2, 1.3 }, {  3.2, 3.0 }, {  2.0, -1.0 },
      {  0.0, -2.4 }, { -3.6, -0.7 }, { -5.0, -2.0 },
      { -3.7, -2.6 },
    },
    segments = { {1,2},{2,3},{3,4},{4,5},{5,6},{6,7},{7,1},
                 {1,8},{8,9},{9,10},{10,8} },
  },
  {
    id = "MAGIKARP", az = math.rad(36), el = math.rad(38),
    color = { 0.72, 0.88, 1.00 },
    points = {
      { -3.4, 0.0 }, { -1.7, 1.7 }, { 0.7, 1.8 }, { 2.5, 0.0 },
      {  0.7,-1.8 }, { -1.7,-1.7 }, { -5.0, 1.7 }, { -5.0,-1.7 },
      {  1.0, 0.2 },
    },
    segments = { {1,2},{2,3},{3,4},{4,5},{5,6},{6,1},
                 {1,7},{7,8},{8,1},{3,9} },
  },
  {
    id = "LAPRAS", az = math.rad(139), el = math.rad(43),
    color = { 0.86, 0.80, 1.00 },
    points = {
      { -3.8,-1.4 }, { -2.4, 0.2 }, { -0.5, 1.0 }, { 1.6, 0.6 },
      {  3.4,-0.8 }, {  1.5,-1.7 }, { -1.1,-1.8 }, { -2.8,-1.2 },
      {  2.4, 2.2 }, {  2.7, 4.1 }, { 3.5, 4.7 },
    },
    segments = { {1,2},{2,3},{3,4},{4,5},{5,6},{6,7},{7,8},{8,1},
                 {4,9},{9,10},{10,11} },
  },
}

local constellationDirections = {}

function Sky.constellationDirection(constellation, point)
  local def = type(constellation) == "number"
              and Sky.CONSTELLATIONS[constellation] or constellation
  local p = def and def.points and def.points[point]
  if not p then return nil end
  local key = tostring(def.id) .. ":" .. tostring(point)
  local cached = constellationDirections[key]
  if cached then return cached.direction, cached.az, cached.el end
  local az = wrapPi(def.az + math.rad(p[1]))
  local el = math.max(math.rad(8), math.min(math.rad(82),
                                           def.el + math.rad(p[2])))
  local answer = { direction = Sky.direction(az, el), az = az, el = el }
  constellationDirections[key] = answer
  return answer.direction, az, el
end

Sky.CONSTELLATION_MAX_LINES = 0
for _, constellation in ipairs(Sky.CONSTELLATIONS) do
  Sky.CONSTELLATION_MAX_LINES = Sky.CONSTELLATION_MAX_LINES
                                + #constellation.segments
end

-- The active shooting star's stable world direction. A new thirteen-second
-- window chooses another bearing; during its short life the meteor itself
-- crosses that part of the sky. `trail` walks backward along the same arc.
function Sky.shootingDirection(clock, trail)
  local az, el = Sky.shootingAngles(clock, trail)
  if not az then return nil end
  return Sky.direction(az, el), az, el
end

function Sky.shootingAngles(clock, trail)
  clock = clock or Sky.clock
  local phase = clock % 13
  if phase >= 0.85 then return nil end
  local cycle = math.floor(clock / 13)
  local p = phase / 0.85 - (trail or 0) * 0.032
  local start = wrapPi((cycle + 1) * GOLDEN_ANGLE)
  local az = wrapPi(start + math.rad(18) * p)
  local el = math.rad(55 - 17 * p)
  return az, el
end

local function paintStars(w, h, edge, cell, alpha, ray, strength, context)
  if strength <= 0.03 then return end
  local g = love.graphics
  local function star(i, x, y, strengthScale)
    local color, cells, speed, phase = Sky.starVisual(i)
    local twinkle = 0.58 + 0.42 * math.sin(Sky.clock * speed + phase)
    local a = alpha * strength * (strengthScale or 1) * twinkle
    g.setColor(color[1], color[2], color[3], a)
    local s = cell * cells
    g.rectangle("fill", math.floor((x - s / 2) / cell) * cell,
                math.floor((y - s / 2) / cell) * cell, s, s)
  end

  local function constellations()
    if strength <= 0.48 then return end
    local project = ray and nil or Sky.projector(nil, w, h, edge)
    for ci, def in ipairs(Sky.CONSTELLATIONS) do
      local xs, ys, seen = {}, {}, {}
      for pi = 1, #def.points do
        local direction, az, el = Sky.constellationDirection(def, pi)
        local x, y, visible
        if ray then x, y, visible = Sky.projectDirection(ray, w, h, direction)
        else x, y, visible = project(az, el) end
        xs[pi], ys[pi], seen[pi] = x, y, visible
      end

      -- Rough one-pixel lines keep the drawings subtle. A compatibility
      -- renderer without line support still gets every authored star.
      if type(g.line) == "function" then
        local oldWidth = type(g.getLineWidth) == "function"
                         and g.getLineWidth() or nil
        local oldStyle = type(g.getLineStyle) == "function"
                         and g.getLineStyle() or nil
        if type(g.setLineWidth) == "function" then
          g.setLineWidth(math.max(1, cell * 0.45))
        end
        if type(g.setLineStyle) == "function" then g.setLineStyle("rough") end
        g.setColor(def.color[1], def.color[2], def.color[3],
                   alpha * strength * 0.20)
        for _, segment in ipairs(def.segments) do
          local a, b = segment[1], segment[2]
          if seen[a] and seen[b] then g.line(xs[a], ys[a], xs[b], ys[b]) end
        end
        if oldWidth and type(g.setLineWidth) == "function" then
          g.setLineWidth(oldWidth)
        end
        if oldStyle and type(g.setLineStyle) == "function" then
          g.setLineStyle(oldStyle)
        end
      end
      for pi = 1, #def.points do
        if seen[pi] then
          local x, y = xs[pi], ys[pi]
          local s = (pi == 1 or pi == #def.points) and cell * 2 or cell
          g.setColor(def.color[1], def.color[2], def.color[3],
                     alpha * strength * 0.88)
          g.rectangle("fill", math.floor((x - s / 2) / cell) * cell,
                      math.floor((y - s / 2) / cell) * cell, s, s)
        end
      end
    end
  end

  -- Full-picture Arena Scenery has a fixed, authored camera and a deliberately
  -- transparent upper sky. World-fixed stars are correct for steerable
  -- 1ST/3RD/MAP cameras, but an authored arena may face any bearing: at some
  -- bearings the whole deterministic hemisphere can miss its narrow aperture.
  -- Use the bounded screen composition for that one surface. It still
  -- twinkles from the shared clock and remains behind the painting.
  local screenArena = context and context.arena
  if ray and not screenArena then
    for i = 1, Sky.STAR_COUNT do
      local x, y, visible = Sky.projectDirection(ray, w, h,
                                                 Sky.starDirection(i))
      if visible then star(i, x, y) end
    end
    constellations()
    if strength > 0.35 then
      for p = 0, 7 do
        local az, el = Sky.shootingAngles(Sky.clock, p)
        local x, y, visible = Sky.projectSky(ray, w, h, az, el)
        if visible then
          g.setColor(1, 1, 1, alpha * strength * (1 - p / 8))
          g.rectangle("fill", math.floor(x / cell) * cell,
                      math.floor(y / cell) * cell, cell, cell)
        end
      end
    end
    return
  end

  local starEdge = math.max(cell, edge * 0.82)
  for i = 1, Sky.FALLBACK_STAR_COUNT do
    local x = (i * 113 + (i * i) * 7) % math.max(1, math.floor(w))
    local y = (i * 61 + (i * i) * 3) % math.max(1, math.floor(starEdge))
    star(i, x, y)
  end
  constellations()

  -- A short deterministic window every thirteen seconds: rare enough to be
  -- noticed, frequent enough that a pinned NIGHT setting is not static.
  local phase = Sky.clock % 13
  if phase < 0.85 and strength > 0.35 then
    local travel = phase / 0.85
    local x = w * (0.18 + travel * 0.52)
    local y = edge * (0.20 + travel * 0.18)
    for p = 0, 7 do
      g.setColor(1, 1, 1, alpha * strength * (1 - p / 8))
      g.rectangle("fill", math.floor((x - p * cell * 2) / cell) * cell,
                  math.floor((y - p * cell) / cell) * cell, cell, cell)
    end
  end
end

Sky._paintStars = paintStars -- focused deterministic/night-only QA seam

local function paintAtmosphere(w, h, edge, cell, alpha, ray, context)
  local g = love.graphics
  if not (g and g.setScissor and g.rectangle) then return end
  local sx, sy, sw, sh = g.getScissor()
  local x, y, rw, rh = 0, 0, math.ceil(w), math.max(1, math.floor(edge))
  if sx then
    local x2, y2 = math.min(x + rw, sx + sw), math.min(y + rh, sy + sh)
    x, y = math.max(x, sx), math.max(y, sy)
    rw, rh = math.max(0, x2 - x), math.max(0, y2 - y)
  end
  if rw <= 0 or rh <= 0 then return end
  g.setScissor(x, y, rw, rh)
  local night = nightStrength()
  paintStars(w, h, edge, cell, alpha, ray, night, context)
  local eventContext = {
    skyEnabled = Sky.banded(),
    g = g, w = w, h = h, edge = edge, cell = cell, alpha = alpha,
    project = Sky.projector(ray, w, h, edge),
    weather = context and context.weather or nil,
  }
  -- Rainbow is distant atmosphere; clouds can pass in front of it. Flyers
  -- are nearer silhouettes and cross over both. Both layers use the same
  -- world projector and their own zero-draw performance gate.
  SkyEvents.paint(eventContext, "back")
  paintClouds(w, h, edge, cell, alpha, ray, night)
  SkyEvents.paint(eventContext, "front")
  if sx then g.setScissor(sx, sy, sw, sh) else g.setScissor() end
end

-- ------- the disc as a TEXTURE, for the VR eyes
--
-- A VR eye must not paint the disc in screen space at all: a canvas-grid
-- painting re-snaps to different cells every head movement (jitter) and
-- holds its pattern square to the CANVAS (a rolled or pitched head
-- watches the sun's face turn). So the same cell art is baked once into
-- a texture, and Voxel3D hangs it on a quad ANCHORED IN THE WORLD --
-- projected through the eye's own matrix like any geometry, stable under
-- every head motion. Rebaked only when the palette or the twilight state
-- moves the colours.
local discBake = { key = nil, img = nil }

Sky.DISC_BAKE_R = 9          -- bake radius, in cells
Sky.DISC_BAKE_PX = 8         -- texture pixels per cell

function Sky.discImage(moon, twilight)
  if not (love.graphics and love.graphics.newCanvas) then return nil end
  local shades = Sky.discShades(moon)
  local key = (moon and "m" or "s") .. (twilight and "t" or "-")
  for i = 1, math.min(3, #shades) do
    local c = shades[i]
    key = key .. ":" .. c[1] .. "," .. c[2] .. "," .. c[3]
  end
  if discBake.key == key and discBake.img then return discBake.img end
  local r, px = Sky.DISC_BAKE_R, Sky.DISC_BAKE_PX
  local size = (2 * r + 1) * px
  local ok, canvas = pcall(love.graphics.newCanvas, size, size)
  if not (ok and canvas) then return nil end
  pcall(canvas.setFilter, canvas, "nearest", "nearest")
  local g = love.graphics
  local done = pcall(function()
    g.push("all")
    g.origin()
    g.setCanvas(canvas)
    g.clear(0, 0, 0, 0)
    g.setBlendMode("alpha")
    discCells(r, moon, shades, twilight, function(dx, dy, c)
      g.setColor(c[1] / 255, c[2] / 255, c[3] / 255, 1)
      g.rectangle("fill", (dx + r) * px, (dy + r) * px, px, px)
    end)
    g.pop()
  end)
  if not done then return nil end
  discBake.key, discBake.img = key, canvas
  return canvas
end

-- Whether this body is the looming low sun, for callers sizing the baked
-- disc (the same exaggeration paintDisc applies through discRadius).
function Sky.discLooming(glowAmt, moon)
  return (glowAmt or 0) > 0.25 and not moon
end

-- A reviewed full-picture arena owns a fixed screen composition rather than
-- a freely turning world camera. Keep its body inside the authored live-sky
-- aperture: the moon is intentionally high-right, while the rising/setting
-- sun follows its east/west world sign across a smaller central range. The
-- existing cell-art painter supplies the shared palette, craters and size.
function Sky.arenaBody(body, w, edge)
  if not (type(body) == "table" and type(w) == "number" and w > 0
          and type(edge) == "number" and edge > 0) then return nil end
  local x
  if body.moon then
    x = w * .78
  else
    local east = math.max(-1, math.min(1, tonumber(body.dx) or 0))
    x = w * (.50 + east * .30)
  end
  return {
    x = x, y = edge * (body.moon and .18 or .22),
    moon = body.moon and true or false,
    glowAmt = body.glowAmt or 0,
    glowColor = body.glowColor,
    -- Five cells across the radius at the coarsest established Arena grid:
    -- enough for a round rim, core and distinct craters instead of one white
    -- pixel/cross, still well inside the authored upper-sky aperture.
    discScale = 1.65,
  }
end

-- Paint the sky into the bound canvas, filling it from the top edge down to
-- `horizonY` (or to SPAN of the frame when the horizon is out of it).
--
-- `cell` is the diorama's pixel size in canvas pixels -- the pass's own
-- pixels-per-world-pixel, handed in every frame so a zoom lands immediately.
--
-- `body` is the sun or moon to hang, already projected to canvas pixels by
-- the caller's own camera (Voxel3D.skyBody), with the twilight glow riding
-- along; nil hangs nothing and warms nothing.
--
-- `top` anchors the gradient in space rather than to the frame: the canvas
-- row band 1 starts on (often negative -- above the frame), from a caller
-- that mapped a fixed elevation span to its own camera (see ELEV_SPAN).
-- nil or 0 is the flat screen's behaviour: zenith band at the top edge.
--
-- `axis` tips the whole painting to a rolled camera's true horizon: a unit
-- {ax, ay} pointing "toward the ground" on the canvas (Voxel3D.horizonLine),
-- with `horizonY` and `top` then read as distances ALONG it rather than as
-- rows. nil is the level default. Only the shader path can tilt; the flat
-- fallback paints level, which only a headless run ever sees. Under an
-- axis the DISC is not painted here at all -- the VR caller hangs the
-- baked disc (Sky.discImage) in the world instead; `body` still carries
-- the twilight glow into the bands.
--
-- `ray` makes the gradient a SKYBOX: the eye's own ray fan (the camera
-- record's skyRay, from VRRig.eyeCamera), letting every pixel take its
-- band from its TRUE elevation -- so no motion of the head, on any axis,
-- moves a band; only the clock does. nil keeps the linear frame gradient
-- the flat screen has always painted.
--
-- Returns false when there is nothing to paint, in which case the caller's flat
-- fill is the whole sky. That fill is the palest band, so a frame that declines
-- this looks like a hazy day rather than like a bug.
function Sky.paint(w, h, sky, horizonY, cell, body, top, axis, ray, context)
  local bands = sky and sky.bands
  if not (bands and bands[1]) then return false end
  if not (w and h and w > 0 and h > 0) then return false end
  local g = love.graphics
  if not (g and g.rectangle) then return false end
  -- with a ray fan the shader's own per-pixel elevation test is the only
  -- boundary and the whole frame goes through it; along an axis the
  -- caller's edge is already the signed distance and has no row to be
  -- clamped to; level callers keep the SPAN fallback
  local edge
  if ray then
    edge = h
  elseif axis then
    edge = horizonY
  else
    edge = Sky.region(h, horizonY)
  end
  if not edge then return false end
  local alpha = sky[4] or 1
  cell = math.max(1, math.floor((cell or 1) + 0.5))

  -- State to put aside. The scene's shader is one, and the blend mode another --
  -- a pass that left "replace" behind would make the fade-in strength meaningless
  -- -- but the DEPTH MODE is the one that would break the frame: a rectangle
  -- drawn under the pass's own ("lequal", true) stamps itself across the depth
  -- buffer at the near plane and hides the entire world behind the sky.
  local prevShader = g.getShader and g.getShader() or nil
  local cmp, write
  if g.getDepthMode then cmp, write = g.getDepthMode() end
  if g.setDepthMode then g.setDepthMode("always", false) end
  local blend, blendAlpha
  if g.getBlendMode then blend, blendAlpha = g.getBlendMode() end
  if g.setBlendMode then g.setBlendMode("alpha") end

  local glowAmt = body and not body.moon and (body.glowAmt or 0) or 0
  -- The fixed Arena composition already paints its sun in screen space below.
  -- Feeding that body's world glow into the rayed shader creates enormous,
  -- weak checker arcs across the authored transparent opening.  Keep the
  -- phase palette and the visible sun, but omit only this redundant Arena-only
  -- glow field.  Steerable MAP/1ST/3RD skies retain their established glow.
  if context and context.arena then glowAmt = 0 end
  -- the skybox glow needs the sun's world DIRECTION (skyBody carries it);
  -- a body without one has nothing to measure angles against, so no glow
  if ray and glowAmt > 0 and not (body and body.dx) then glowAmt = 0 end
  -- the world direction a canvas fraction (u, v) looks along, normalised
  -- -- for sizing the angular checker and the glow's angular reach below
  local function rayDirAt(u, v)
    local b, du, dv = ray.base, ray.du, ray.dv
    local x = b[1] + du[1] * u + dv[1] * v
    local y = b[2] + du[2] * u + dv[2] * v
    local z = b[3] + du[3] * u + dv[3] * v
    local l = math.sqrt(x * x + y * y + z * z)
    if l < 1e-9 then return 0, 0, -1 end
    return x / l, y / l, z / l
  end
  local function rayAngle(u0, v0, u1, v1)
    local ax, ay, az = rayDirAt(u0, v0)
    local bx, by, bz = rayDirAt(u1, v1)
    local d = ax * bx + ay * by + az * bz
    return math.acos(math.max(-1, math.min(1, d)))
  end
  local sh = getShader()
  local ramp = sh and rampFor(bands)
  if not ramp then sh = nil end       -- no ramp, no gradient: paint it flat
  if sh then
    local sent = pcall(function()
      -- the bands arrive as a texture, one texel each, and `count` is that
      -- texture's width -- see rampFor for why they are not a uniform array
      sh:send("ramp", ramp)
      sh:send("count", #bands)
      sh:send("edge", edge)
      sh:send("top", math.min(top or 0, edge - 1))
      sh:send("axisX", axis and axis[1] or 0)
      sh:send("axisY", axis and axis[2] or 1)
      sh:send("useRay", ray and 1 or 0)
      if ray then
        sh:send("rayBase", ray.base)
        sh:send("rayDu", ray.du)
        sh:send("rayDv", ray.dv)
        sh:send("raySpan", Sky.ELEV_SPAN)
        sh:send("invSize", { 1 / w, 1 / h })
        -- the angular checker's cell: the angle one dither cell spans at
        -- the frame's centre, so the sky-glued grid comes out the same
        -- size on screen as the diorama's own pixel grid
        sh:send("cellAng",
                math.max(1e-4, rayAngle(0.5, 0, 0.5, 1) * cell / h))
      end
      sh:send("cell", cell)
      sh:send("start", Sky.ditherStart(ray))
      sh:send("alpha", alpha)
      sh:send("glowAmt", glowAmt)
      if glowAmt > 0 then
        local gc = body.glowColor or { 248, 224, 168 }
        if ray then
          -- the glow in ANGLES: its direction is the sun's own, and its
          -- reach is the same fraction of the view the pixel reach was
          -- of the frame, so the two paths agree on how wide it looks
          local dx, dy, dz = body.dx, body.dy, body.dz
          local l = math.sqrt(dx * dx + dy * dy + dz * dz)
          sh:send("glowDir", { dx / l, dy / l, dz / l })
          sh:send("glowInvA", 1 / math.max(
            1e-3, rayAngle(0, 0.5, 1, 0.5) * Sky.GLOW_REACH))
        else
          sh:send("glowPos", { body.x, body.y })
          sh:send("glowInvR", 1 / math.max(1, w * Sky.GLOW_REACH))
        end
        sh:send("glowColor", { gc[1] / 255, gc[2] / 255, gc[3] / 255 })
      end
    end)
    if sent then
      g.setShader(sh)
      g.setColor(1, 1, 1, 1)
      -- tilted or rayed, the sky's reach is not a row: the full frame
      -- goes through the shader and the discard is the boundary
      local rectH = (axis or ray) and h or math.min(h, math.ceil(edge))
      g.rectangle("fill", 0, 0, w, rectH)
      g.setShader()
    else
      sh = nil
    end
  end
  if not sh then
    paintFlat(w, h, bands, (axis or ray) and math.min(h, edge) or edge,
              alpha, cell, math.min(top or 0, edge - 1))
  end
  local atmosphereRay = context and context.ray or ray
  paintAtmosphere(w, h, math.min(h, edge), cell, alpha,
                  atmosphereRay, context)
  -- the disc goes over the glow, under nothing: plain rectangles, so it is
  -- there whether or not the shader built. NOT under an axis or a ray fan:
  -- those cameras hang the baked disc in the world instead (drawWorldDisc,
  -- with Sky.discImage)
  if context and context.arena and body then
    paintDisc(Sky.arenaBody(body, w, math.min(h, edge)),
              math.min(h, edge), cell, w, h)
  elseif not (axis or ray) then
    paintDisc(body, math.min(h, edge), cell, w, h)
  end
  g.setColor(1, 1, 1, 1)

  if g.setBlendMode and blend then g.setBlendMode(blend, blendAlpha) end
  if g.setDepthMode then g.setDepthMode(cmp or "always", write or false) end
  if prevShader and g.setShader then g.setShader(prevShader) end
  return true
end

-- Drop every GPU object owned by the sky family (window resize, context loss,
-- hot reload), so a re-created graphics context never sees a stale handle.
-- Cloud and rare-event atlases deliberately go through their public module
-- invalidators: both reset to cold and therefore remain reloadable by their
-- ordinary staged prewarm paths. Every release path is idempotent.
function Sky.invalidate()
  shader = nil
  if cache.ramp and cache.ramp.release then pcall(cache.ramp.release, cache.ramp) end
  cache.ramp, cache.rampFor = nil, nil
  if discBake.img and discBake.img.release then
    pcall(discBake.img.release, discBake.img)
  end
  discBake.key, discBake.img = nil, nil
  Sky.invalidateCloudAsset()
  if SkyEvents and type(SkyEvents.invalidateAssets) == "function" then
    pcall(SkyEvents.invalidateAssets)
  end
end

return Sky
