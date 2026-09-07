-- Voxel world mode: the 3D pass -- shader, depth buffer and camera.
--
-- World space is world PIXELS, so every coordinate the 2D paths already
-- compute drops straight in with no unit conversion:
--
--   +X  map east   (world-pixel x)
--   +Y  up         (0 is the ground plane)
--   +Z  map south  (world-pixel y)
--
-- A character at rest faces +Z, i.e. toward a camera parked to the south,
-- which is what "facing down" means in the 2D game -- and a character card
-- is drawn in exactly that pose, leaning back rather than yawing.
--
-- The camera orbits the view centre at Voxel.angle: 0 is straight down
-- (what the flat 2D view already is) and 50 degrees leans toward the
-- horizon. Distance and field of view are tied to Voxel.FOCAL, which is the
-- same constant Tilt projects with, so a given angle frames the world
-- identically in both modes -- switching between them changes the geometry,
-- not the framing.
--
-- Every GPU object is pcall-guarded and `available()` reports the result:
-- headless test runs and any driver without depth-canvas support fall back
-- to the existing tilt/flat paths rather than erroring.

-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local Mat4 = V.require("Mat4")
local Voxel = V.require("VoxelState")
local ShadowMap = V.require("ShadowMap")
local Shadows = V.require("Shadows")
local VoxelGrid = V.require("VoxelGrid")
local WorldCurve = V.require("WorldCurve")
local Sky = V.require("Sky")
local DayNight = V.require("DayNight")
local GlassMask = V.require("GlassMask")
local PixelCanvas = V.require("PixelCanvas")
local CanvasPresentation = V.require("CanvasPresentation")

local Voxel3D = {}

local MobileDiagnostic = V and V.mod and V.mod._vascMobileDiagnostic or nil
local function mobileDiagnostic(name, ...)
  local fn = MobileDiagnostic and MobileDiagnostic[name]
  if type(fn) ~= "function" then return nil end
  local ok, a, b = pcall(fn, ...)
  if ok then return a, b end
  return nil
end

local MOBILE_RUNTIME = CanvasPresentation.OS == "iOS"
  or CanvasPresentation.OS == "Android"

-- Shared read-only platform receipt for builders that must choose a native
-- buffer layout before any scene exists. Keeping detection here guarantees
-- the mesher and the shader select the same phone policy.
function Voxel3D.mobileRuntime()
  return MOBILE_RUNTIME
end

-- Vertex format shared by terrain chunks and character models: a position,
-- the map-canvas / sprite-sheet pixel it samples, and a per-vertex darken
-- factor that gives a face its angle to the sun without a normal or a
-- light uniform. Cast shadows are a separate thing entirely -- see
-- ShadowMap, which the pixel shader below samples on top of this.
Voxel3D.FORMAT = {
  { "VertexPosition", "float", 3 },
  { "VertexTexCoord", "float", 2 },
  { "VertexShade", "float", 1 },
}

-- Face shading by direction id: top faces stay
-- full brightness, sides step down so an extruded block reads as solid
-- instead of a flat sticker, and the faces turned away from the sun are
-- darkest. The sun hangs in the SOUTHEAST (see ShadowMap), so south and
-- east are the lit flanks and north and west the shaded ones -- east and
-- west used to share one value back when the sun sat due northwest and the
-- two were symmetric about it.
--
-- This is still worth baking even now that the shadow pass throws real
-- shadows: a face turned away from the sun is dark because of its ANGLE,
-- which no shadow map measures, and the two compound the way they should
-- -- an away-facing wall that is also occluded goes darker still.
Voxel3D.FACE_SHADE = {
  [1] = 0.84,   -- +X east (toward the sun)
  [2] = 0.72,   -- -X west (away)
  [3] = 1.00,   -- +Y up
  [4] = 0.55,   -- -Y down
  [5] = 0.90,   -- +Z south (toward the camera, and toward the sun)
  [6] = 0.68,   -- -Z north (away)
}

local SHADER = [[
  varying float vShade;
  varying float vWeatherTop;
  varying vec3 vSun;          // this fragment's place in the sun's view
  varying LOVE_HIGHP_OR_MEDIUMP vec3 vWorld;
#ifdef VOXEL_GRID
  // model space, one unit per voxel -- see VoxelGrid. Precision matters
  // here in a way it does not for a colour: the seam is the FRACTIONAL
  // part of a coordinate that runs to a few thousand across a big route,
  // so a mediump varying would quantise the fraction away entirely.
  varying LOVE_HIGHP_OR_MEDIUMP vec3 vGrid;
#endif
#ifdef VERTEX
  uniform mat4 vp;
  uniform mat4 model;
  uniform mat4 sunModel;      // where the SUN sees this vertex (see below)
  uniform mat4 sunVP;         // world -> the shadow map's unit cube
  uniform vec3 eye;
  uniform float pull;
  uniform vec3 curve;         // xy = the focus in world XZ, z = k; 0 = off
  attribute float VertexShade;
  // ChunkMesher attaches this as a per-instance attribute only for repeated
  // structure hulls. Ordinary meshes leave it disabled, whose graphics-API
  // default is (0, 0, 0): one shader therefore preserves the exact old path and
  // also places a shared hull without a second shader switch per group.
  attribute vec3 InstanceOffset;
  vec4 position(mat4 transform_projection, vec4 vertex_position) {
    // A negative shade is the internal "map object" caster bit. The visible
    // pass keeps the exact historical lighting magnitude; only ShadowMap
    // reads the sign when a companion requests object-only casting.
    // ChunkMesher encodes a real upward-facing terrain/canopy/roof surface
    // by adding 2 to the shade magnitude. Decode it here instead of trying
    // to infer geometry from a colour value in the pixel shader: authored
    // facades are allowed to share exactly the same lighting as a roof.
    float encodedShade = abs(VertexShade);
    vWeatherTop = step(1.5, encodedShade);
    vShade = encodedShade - vWeatherTop * 2.0;
    vec4 placed = vertex_position;
    placed.xyz += InstanceOffset;
#ifdef VOXEL_GRID
    // MODEL space, deliberately: every mesh here is built a unit per
    // voxel in its own frame, so the seams ride the model however it is
    // posed rather than the world's grid sliding across a leaning sprite
    vGrid = placed.xyz;
#endif
    vec4 w = model * placed;
    // Uncurved world position for FULL's indoor dollhouse cut.  The cut plane
    // belongs to the room, not to the optional presentation curve, so moving
    // or disabling that curve can never make a wall reappear in strips.
    vWorld = w.xyz;
    // The shadow lookup runs off `sunModel`, not `model`. For terrain the
    // two are the same matrix, but a character is drawn as a slab LEANING
    // back by the camera's pitch -- a trick played on the viewer, which
    // the sun never saw: it lit the upright card. Looking up with the
    // leaned position asks whether the sun reached a place the figure is
    // not, and since the lean tips the body north and shadows now fall
    // north, every sprite's own card fell across its front. Looking up
    // with the card's position asks the question the sun actually
    // answered. (The pull below is excluded for the same reason: it is a
    // depth trick aimed at the camera's own buffer.)
    vSun = (sunVP * (sunModel * placed)).xyz;
    // The curved world (see WorldCurve): drop every vertex by the square
    // of how far its column stands from the camera's focus. Applied AFTER
    // the shadow lookup above and clear of the wireframe's model space, so
    // both are worked out on the flat world and the bend carries them
    // along -- which is why neither has to know this exists. Along Y only,
    // so a column moves as one piece: the world tips away and the
    // buildings standing on it stay upright.
    if (curve.z > 0.0) {
      vec2 cd = w.xz - curve.xy;
      w.y -= dot(cd, cd) * curve.z;
    }
    // camera-ward pull: move the vertex along ITS OWN ray to the eye.
    // This is a pure depth bias -- the projection of a point moved along
    // its eye ray is bit-identical, so there is no screen drift at all.
    // (An earlier CPU version translated along the central view axis,
    // which preserved only the screen centre and made off-centre sprites
    // and grass swim against the ground while the camera scrolled.)
    if (pull > 0.0) {
      w.xyz += normalize(eye - w.xyz) * pull;
    }
    return vp * w;
  }
#endif
#ifdef PIXEL
  uniform Image sunMap;
  uniform float sunDark;      // how far into black a shadow goes; 0 = off
  uniform float sunReceive;   // 0 for presentation cards; their floor receives
  uniform float sunBias;
  uniform vec2 sunTexel;
  // VASC_MOBILE_AERIAL_UNIFORMS_BEGIN
  uniform float cloudShadow; // restrained maximum darkening; 0 = no clouds
  uniform float cloudTime;   // deterministic VASC sky clock
  uniform float cloudProgress;// 0..1 across the current cloud flyover
  uniform float cloudSeed;   // deterministic per-map cloud lane
  uniform float birdShadow;  // animated flyover silhouette; 0 = no birds
  uniform float birdProgress;// 0..1 across the current flyover
  uniform float birdSeed;    // deterministic per-map placement
  uniform float birdCount;   // formation count selected by SkyEvents
  uniform float birdScale;   // apparent size of that same VASC species
  uniform float birdDirection;// matches the visible atlas flight direction
  uniform float birdLegendary;// broader solitary silhouette for legends
  uniform vec2 shadowAnchor; // current player/focus point in world XZ
  // VASC_MOBILE_AERIAL_UNIFORMS_END

  // the two-channel pack ShadowMap writes: high byte, then low
  float sunDepth(vec2 uv) {
    vec4 c = Texel(sunMap, uv);
    return c.r + c.g * (1.0 / 255.0);
  }

  // 1.0 in full sun, 1.0 - sunDark in full shadow. Four taps half a texel
  // out on the diagonals: a 2x2 box filter, which is what turns the
  // shadow map's texel staircase into a one-pixel soft edge.
  float sunlight(vec3 p) {
    if (sunDark <= 0.0 || sunReceive <= 0.0) return 1.0;
    // outside the sun's frustum nothing was recorded, so nothing occludes
    if (p.x < 0.0 || p.x > 1.0 || p.y < 0.0 || p.y > 1.0 || p.z > 1.0) {
      return 1.0;
    }
    // Ease the shadows off at the frustum's rim. The map covers the ground
    // the camera can see out to a cap, and past the low rungs -- 75 degrees
    // especially -- the horizon is further than any box worth paying for.
    // Without this the covered region simply ENDS, drawing a hard line
    // across the middle distance where every shadow stops at once; with it
    // the far field just loses them, which reads as distance.
    vec2 e = min(p.xy, 1.0 - p.xy);
    float edge = smoothstep(0.0, 0.06, min(e.x, e.y));
    if (edge <= 0.0) return 1.0;
    float z = p.z - sunBias;
    float lit = step(z, sunDepth(p.xy + sunTexel * vec2(-0.5, -0.5)))
              + step(z, sunDepth(p.xy + sunTexel * vec2( 0.5, -0.5)))
              + step(z, sunDepth(p.xy + sunTexel * vec2(-0.5,  0.5)))
              + step(z, sunDepth(p.xy + sunTexel * vec2( 0.5,  0.5)));
    return 1.0 - sunDark * edge * (1.0 - lit * 0.25);
  }

  // VASC_MOBILE_AERIAL_FUNCTIONS_BEGIN
  float cloudLobe(vec2 p, vec2 centre, vec2 radius) {
    vec2 d = (p - centre) / radius;
    return 1.0 - smoothstep(0.42, 1.0, dot(d, d));
  }

  // A guaranteed local flyover: the cloud bank crosses the current focus
  // instead of relying on a random distant cell happening to enter view.
  // Four soft lobes keep it cloud-shaped and below map-sized dimensions.
  float cloudlight(vec2 world) {
    if (cloudShadow <= 0.0) return 1.0;
    vec2 p = world - shadowAnchor;
    float lane = (fract(cloudSeed * 0.417) - 0.5) * 42.0;
    float travel = fract(cloudSeed * 0.233) >= 0.5
                   ? cloudProgress : 1.0 - cloudProgress;
    vec2 centre = vec2(mix(-190.0, 190.0, travel), lane);
    float cover = cloudLobe(p, centre, vec2(62.0, 38.0));
    cover = max(cover, cloudLobe(p, centre + vec2(-42.0, 12.0),
                                 vec2(48.0, 31.0)));
    cover = max(cover, cloudLobe(p, centre + vec2(38.0, -10.0),
                                 vec2(53.0, 34.0)));
    cover = max(cover, cloudLobe(p, centre + vec2(3.0, 23.0),
                                 vec2(39.0, 27.0)));
    return 1.0 - cloudShadow * clamp(cover, 0.0, 1.0);
  }

  float birdStroke(vec2 p, vec2 a, vec2 b, float width) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.001), 0.0, 1.0);
    float distanceToWing = length(pa - ba * h);
    return 1.0 - smoothstep(width, width + 0.85, distanceToWing);
  }

  // A compact flying silhouette made from two tapered wing strokes and a
  // short body. Three copies form a loose chevron. The repeat is wider than
  // an ordinary map view, so a flyover reads as one passing flock rather than
  // a wallpaper pattern while remaining independent of camera position.
  float birdShape(vec2 p, float phase) {
    float flap = sin(cloudTime * 8.5 + phase) * 2.2;
    float wing = mix(7.0, 10.5, birdLegendary);
    float width = mix(1.15, 1.65, birdLegendary);
    float left = birdStroke(p, vec2(0.0, 0.0),
                            vec2(-wing, 2.6 + flap), width);
    float right = birdStroke(p, vec2(0.0, 0.0),
                             vec2(wing, 2.6 + flap), width);
    vec2 body = p / mix(vec2(1.45, 4.2), vec2(2.0, 6.3), birdLegendary);
    float centre = 1.0 - smoothstep(0.72, 1.0, dot(body, body));
    return max(centre, max(left, right));
  }

  float birdlight(vec2 world) {
    if (birdShadow <= 0.0) return 1.0;
    float lane = (fract(birdSeed * 0.371) - 0.5) * 34.0;
    float travel = birdDirection >= 0.0 ? birdProgress : 1.0 - birdProgress;
    vec2 centre = shadowAnchor
                  + vec2(mix(-150.0, 150.0, travel), lane);
    vec2 p = (world - centre) / max(0.5, birdScale);
    float flock = birdShape(p, 0.0);
    flock = max(flock, birdShape(p - vec2(-17.0, 10.0), 1.9)
                       * step(1.5, birdCount));
    flock = max(flock, birdShape(p - vec2(17.0, 10.0), 3.7)
                       * step(2.5, birdCount));
    flock = max(flock, birdShape(p - vec2(0.0, 20.0), 5.1)
                       * step(3.5, birdCount));
    return 1.0 - birdShadow * clamp(flock, 0.0, 1.0);
  }
  // VASC_MOBILE_AERIAL_FUNCTIONS_END

#ifdef VOXEL_GRID
  uniform float gridDark;     // how far toward black a seam pulls; 0 = off
  uniform float gridWidth;    // seam width, in display pixels

  // How much of this fragment a voxel seam covers, 0 to 1.
  float voxelSeam(vec3 p) {
    // how much of `p` this fragment spans on screen, per axis: the
    // conversion from model units to display pixels, measured rather than
    // derived, so it holds under any camera pitch or zoom
    vec3 w = fwidth(p);
    vec3 d = abs(fract(p + 0.5) - 0.5);      // distance to the nearest plane
    // The axis a face does not vary along is that face's own normal, and
    // its distance is a constant zero -- take it at face value and every
    // face floods solid. Push those axes out of reach instead of dividing
    // by their zero.
    vec3 live = step(1e-4, w);
    vec3 px = d / max(w, vec3(1e-6)) + (1.0 - live) * 1e6;
    float near = min(min(px.x, px.y), px.z);
    // Fade out where a voxel is too small to hold a line. Survey zoom
    // draws a world pixel at about a display pixel, and a wall seen nearly
    // edge-on squashes one to nothing at any zoom -- either way the seams
    // land closer together than they are wide, and drawn anyway they stop
    // being a wireframe and become a flat 45% dimming of the whole scene.
    // The tightest axis decides, which is the honest test of whether the
    // grid can be resolved at all.
    float span = 1.0 / max(max(w.x, max(w.y, w.z)), 1e-6);
    float fade = clamp((span - 2.0) * 0.5, 0.0, 1.0);
    // the textbook antialiased line: solid within the half-width, fading
    // over the one pixel outside it
    return fade * clamp(gridWidth * 0.5 + 0.5 - near, 0.0, 1.0);
  }
#endif

  uniform vec3 ghostColor;    // the flat silhouette colour
  uniform float ghost;        // 0 = shade normally, 1 = flatten to it
  uniform vec3 dayTint;       // the hour's light on the world; 1,1,1 = noon
  uniform float weatherGround;// 0 off, 1 wet, 2 snow, 3 heat-dried green tops
  uniform float weatherGrass; // 1 snow / 2 heat, only during grass mesh draws
  uniform float weatherAmount;// 0..1 accumulated coat / draining wetness
  uniform float weatherTime;  // shared deterministic animation clock
  uniform Image glassMask;    // opaque where the atlas texel is window glass
  uniform vec2 glassSize;     // the mask's dimensions: tc -> atlas texels
  uniform float glassNight;   // 0 = daylight .. 1 = the lamps are on
  uniform float glassPhase;   // the glint's phase: advances with TRAVEL
  uniform float glassGlint;   // and its strength: 0 while standing still
  uniform float glassOn;      // 0 for sprite-sheet draws (see Voxel3D.glass)
  // xy = camera-side ground-plane normal, z = plane offset, w = enabled.
  // Sent only for the synthetic enclosure wall draw; terrain, furniture and
  // actors always receive w=0 and therefore keep their complete geometry.
  uniform vec4 cutaway;

  vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    if (cutaway.w > 0.5 && dot(vWorld.xz, cutaway.xy) > cutaway.z) discard;
    vec4 p = Texel(tex, tc);
    // sprite sheets key GB OBJ color 0 to alpha 0; discarding rather than
    // blending keeps those texels out of the depth buffer, so a model never
    // carves a transparent hole out of whatever stands behind it
    if (p.a < 0.5) discard;
    // the hour's tint multiplies like the sun terms do: it is LIGHT, the
    // same warm or moonlit cast on every surface, not a palette swap
    // VASC_MOBILE_AERIAL_LIGHT_BEGIN
    vec3 rgb = p.rgb * vShade * sunlight(vSun)
               * cloudlight(vWorld.xz) * birdlight(vWorld.xz) * dayTint;
    // VASC_MOBILE_AERIAL_LIGHT_END
    // This bit is geometric, not chromatic. Ground, sloped/flat roofs and
    // tree crowns receive weather; vertical house art never can, even when a
    // facade deliberately uses the same brightness as an upper surface.
    if (weatherGround > 0.5 && vWeatherTop > 0.5) {
      // Broad world-fixed basins, each with its own birth/drain phase. They
      // live on real upward voxel surfaces, so perspective, roofs, occlusion
      // and camera motion all come for free. No screen-space ellipses remain
      // when VASC owns the ground.
      float seed = fract(sin(dot(floor(vWorld.xz / 11.0),
                                  vec2(12.9898, 78.233))) * 43758.5453);
      float life = fract(weatherTime * (0.020 + seed * 0.012) + seed);
      float born = smoothstep(0.02, 0.20, life);
      float drained = 1.0 - smoothstep(0.70, 0.98, life);
      float basin = sin(vWorld.x * 0.075 + seed * 5.0)
                  + cos(vWorld.z * 0.069 - seed * 4.0)
                  + sin((vWorld.x + vWorld.z) * 0.031);
      float weatherPatch = smoothstep(0.25, 1.05, basin) * born * drained;
      if (weatherGround < 1.5) {
        // Wet ground is darker at its rim and carries a moving grey-sky glint
        // through its centre, which reads much closer to shallow water than a
        // blue tint. Every pool still returns completely to the source tile.
        vec3 wet = mix(rgb * 0.48, vec3(0.34, 0.39, 0.40), 0.46);
        float glint = max(0.0, sin((vWorld.x - vWorld.z) * 0.18
                                  + weatherTime * 0.72));
        wet += vec3(0.13, 0.15, 0.15) * glint * weatherPatch;
        rgb = mix(rgb, wet,
                  weatherPatch * 0.72 * clamp(weatherAmount, 0.0, 1.0));
      } else if (weatherGround < 2.5) {
        // Snow must read as snow even on a red or blue authored roof. Keep a
        // little world-fixed variation, but guarantee a dense near-white coat
        // on every real upper surface for the whole active snow spell. The
        // source colour returns immediately when the weather state clears.
        float cover = .78 + smoothstep(-0.55, .75, basin) * .16;
        rgb = mix(rgb, vec3(.965, .975, .985),
                  cover * .96 * clamp(weatherAmount, 0.0, 1.0));
      } else {
        // HEAT dries only authored green texels. The upward-face gate above
        // keeps facades and trunks intact, while a broad slow world pattern
        // prevents the terrain from becoming one perfectly flat brown plate.
        float green = smoothstep(.015, .13, p.g - max(p.r, p.b));
        float dry = .68 + .12 * sin(vWorld.x * .055 - vWorld.z * .047
                                    + weatherTime * .025);
        vec3 earth = vec3(.43, .285, .125) * (.72 + p.g * .34);
        rgb = mix(rgb, earth * dayTint, green * dry);
      }
    }
    if (weatherGrass > 0.5) {
      // Tall-grass blades are camera-facing cards, not upward terrain faces,
      // so they use a separately gated draw state. The texture's alpha was
      // discarded above; only the authored blades become frosted white.
      if (weatherGrass < 1.5) {
        float frost = 0.72 + 0.10 * sin(vWorld.x * .31 + vWorld.z * .23
                                        + weatherTime * .08);
        rgb = mix(rgb, vec3(.86, .89, .89),
                  frost * clamp(weatherAmount, 0.0, 1.0));
      } else {
        float green = smoothstep(.015, .12, p.g - max(p.r, p.b));
        vec3 straw = vec3(.46, .30, .12) * (.76 + p.g * .30);
        rgb = mix(rgb, straw * dayTint, green * .82);
      }
    }
#ifdef VOXEL_GRID
    // darken what is there rather than painting a colour, so a seam across
    // dark grass and one across a white roof each stay in their own palette
    rgb *= 1.0 - gridDark * voxelSeam(vGrid);
#endif
    // WINDOW GLASS, marked per atlas texel by the mask (see GlassMask).
    // By day a thin diagonal glint crosses the panes WHILE THE VIEW MOVES
    // -- the phase is fed by the camera's own travel and the strength dies
    // within a beat of standing still, because a reflection is something
    // the viewpoint does: still camera, still glass. It lifts the texel
    // toward sky-white and leaves the art visible through it. After dark
    // the pane is LIT: the texel's own shine pattern carried into a warm
    // lamp colour, replacing the shaded answer above -- so a lit window
    // ignores the sun, every shadow and the hour's tint, exactly as a
    // window with a lamp behind it does.
    // glassOn gates the whole thing per DRAW: the mask is shaped like the
    // tileset atlas, and only meshes textured FROM that atlas may consult
    // it -- a character samples its own sprite sheet, whose coordinates
    // land on the mask's pane rectangles by accident and would stripe the
    // cast with lamplight at night.
    float glass = Texel(glassMask, tc).a * glassOn;
    if (glass > 0.0) {
      // the sweep lives in the PANE's own space (atlas texels), not the
      // screen's: a pattern anchored to the screen has the world sliding
      // through it at zoom speed whenever the camera pans, which strobed --
      // worst where the pan and the phase ran opposite ways. Anchored to
      // the glass, panning moves nothing; only the phase does, a fraction
      // of a texel per step, the same in every walking direction.
      float sweep = sin(tc.x * glassSize.x * 0.8 - glassPhase);
      float glint = pow(max(sweep, 0.0), 20.0) * 0.55 * glassGlint;
      vec3 pane = mix(rgb, vec3(0.93, 0.97, 1.0), glint * glass);
      float shine = dot(p.rgb, vec3(0.299, 0.587, 0.114));
      vec3 lamp = vec3(1.0, 0.84, 0.5) * (0.5 + 0.55 * shine);
      rgb = mix(pane, lamp, glassNight * glass);
    }
    // The hidden player is a SHAPE, not a dimmed picture of itself. Tinting
    // through `color` could only multiply the sprite's own pixels, which
    // darkens each one by its own amount and keeps the character's internal
    // detail; replacing the colour outright is what makes it read as one
    // solid silhouette. Last in the chain, so neither the sun nor a voxel
    // seam can mottle it.
    rgb = mix(rgb, ghostColor, ghost);
    return vec4(rgb, 1.0) * color;
  }
#endif
]]

-- Some otherwise fully capable mobile GLES compilers reject the complete
-- Gen-1 fragment program once both animated aerial shadow functions are
-- present. Gen 2 does not carry those functions and stays 3D on the same
-- devices. Build a strictly delimited fallback source which omits only that
-- optional cloud/bird contribution. Terrain, sun/shadows, vWeatherTop,
-- weatherGround/weatherGrass, glass and the indoor cutaway remain byte-for-
-- byte the same source as the full shader.
local function removeMarkedBlock(source, beginMarker, endMarker)
  local beginAt = source:find(beginMarker, 1, true)
  if not beginAt then
    return nil, "missing shader marker " .. tostring(beginMarker)
  end
  local endAt, endLast = source:find(endMarker, beginAt, true)
  if not endAt then
    return nil, "missing shader marker " .. tostring(endMarker)
  end
  if source:find(beginMarker, beginAt + #beginMarker, true) then
    return nil, "duplicate shader marker " .. tostring(beginMarker)
  end
  if source:find(endMarker, endLast + 1, true) then
    return nil, "duplicate shader marker " .. tostring(endMarker)
  end
  return source:sub(1, beginAt - 1)
    .. "// VASC mobile-safe: optional aerial lighting omitted\n"
    .. source:sub(endLast + 1)
end

local function mobileSafeShaderSource(source)
  local stripped, err = removeMarkedBlock(source,
    "// VASC_MOBILE_AERIAL_UNIFORMS_BEGIN",
    "// VASC_MOBILE_AERIAL_UNIFORMS_END")
  if not stripped then return nil, err end
  stripped, err = removeMarkedBlock(stripped,
    "// VASC_MOBILE_AERIAL_FUNCTIONS_BEGIN",
    "// VASC_MOBILE_AERIAL_FUNCTIONS_END")
  if not stripped then return nil, err end

  local lightBegin = "// VASC_MOBILE_AERIAL_LIGHT_BEGIN"
  local lightEnd = "// VASC_MOBILE_AERIAL_LIGHT_END"
  local beginAt = stripped:find(lightBegin, 1, true)
  local endAt, endLast
  if beginAt then
    endAt, endLast = stripped:find(lightEnd, beginAt + #lightBegin, true)
  end
  if not (beginAt and endAt and endLast) then
    return nil, "missing mobile aerial light markers"
  end
  if stripped:find(lightBegin, beginAt + #lightBegin, true)
      or stripped:find(lightEnd, endLast + 1, true) then
    return nil, "duplicate mobile aerial light markers"
  end
  local replacement = [[// VASC mobile-safe: keep the complete scene lighting,
    // weather and cutaway path; only optional cloud/bird shadows are neutral.
    vec3 rgb = p.rgb * vShade * sunlight(vSun) * dayTint;
]]
  stripped = stripped:sub(1, beginAt - 1)
    .. replacement .. stripped:sub(endLast + 1)

  -- A malformed fallback is worse than a logged refusal. These receipts make
  -- it impossible for a future shader edit to silently strip weather or
  -- cutaway while still being accepted as the mobile-safe 3D path.
  for _, required in ipairs({
    "varying float vWeatherTop;",
    "uniform float weatherGround;",
    "uniform float weatherGrass;",
    "uniform float weatherAmount;",
    "uniform float weatherTime;",
    "uniform vec4 cutaway;",
    "if (cutaway.w > 0.5",
    "weatherGround > 0.5 && vWeatherTop > 0.5",
  }) do
    if not stripped:find(required, 1, true) then
      return nil, "mobile-safe shader lost required receipt: " .. required
    end
  end
  for _, forbidden in ipairs({ "cloudlight(", "birdlight(" }) do
    if stripped:find(forbidden, 1, true) then
      return nil, "mobile-safe shader retained aerial receipt: " .. forbidden
    end
  end
  return stripped
end

-- The first phone frame needs one dependable textured/depth-tested program,
-- not every desktop lighting feature compiled behind uniform branches.  M5
-- proved that the larger "mobile-safe" program can return from newShader, but
-- a driver may still realize it lazily at setShader/first draw.  This is a
-- standalone vertex + fragment program: it deliberately does not inherit the
-- desktop instance, sun or weather varyings, so a mobile driver has nothing
-- optional to link or lazily realize at first draw.  Its irreducible contract
-- is the ROM atlas texel, baked face shade, day tint, alpha cut-out, player
-- ghost, camera pull, world curve and indoor cutaway.
local function mobileCoreShaderSource(_)
  local core = [[
varying float vShade;
varying LOVE_HIGHP_OR_MEDIUMP vec3 vWorld;

#ifdef VERTEX
  uniform mat4 vp;
  uniform mat4 model;
  uniform vec3 eye;
  uniform float pull;
  uniform vec3 curve;
  attribute float VertexShade;

  vec4 position(mat4 transform_projection, vec4 vertex_position) {
    float encodedShade = abs(VertexShade);
    float weatherTop = step(1.5, encodedShade);
    vShade = encodedShade - weatherTop * 2.0;
    vec4 w = model * vertex_position;
    vWorld = w.xyz;
    if (curve.z > 0.0) {
      vec2 cd = w.xz - curve.xy;
      w.y -= dot(cd, cd) * curve.z;
    }
    if (pull > 0.0) {
      w.xyz += normalize(eye - w.xyz) * pull;
    }
    return vp * w;
  }
#endif

#ifdef PIXEL
  uniform vec3 ghostColor;
  uniform float ghost;
  uniform vec3 dayTint;
  uniform vec4 cutaway;

  vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    if (cutaway.w > 0.5 && dot(vWorld.xz, cutaway.xy) > cutaway.z) discard;
    vec4 p = Texel(tex, tc);
    if (p.a < 0.5) discard;
    vec3 rgb = p.rgb * vShade * dayTint;
    rgb = mix(rgb, ghostColor, ghost);
    return vec4(rgb, 1.0) * color;
  }
#endif
]]
  for _, required in ipairs({
    "uniform mat4 vp;",
    "uniform mat4 model;",
    "attribute float VertexShade;",
    "uniform vec3 curve;",
    "uniform float pull;",
    "uniform vec4 cutaway;",
    "vec4 p = Texel(tex, tc);",
    "vec3 rgb = p.rgb * vShade * dayTint;",
  }) do
    if not core:find(required, 1, true) then
      return nil, "mobile-core shader lost required receipt: " .. required
    end
  end
  for _, forbidden in ipairs({
    "uniform Image sunMap;", "uniform Image glassMask;",
    "uniform float weatherGround;", "uniform mat4 sunModel;",
    "uniform mat4 sunVP;", "attribute vec3 InstanceOffset;",
    "varying vec3 vSun;", "varying float vWeatherTop;",
    "cloudlight(", "birdlight(",
  }) do
    if core:find(forbidden, 1, true) then
      return nil, "mobile-core shader retained optional receipt: " .. forbidden
    end
  end
  return core
end

-- Two compilations of SHADER: the plain scene, and the same thing with the
-- voxel wireframe compiled in. The wireframe needs shader derivatives
-- (fwidth), the one piece of this a driver can refuse, so it is a separate
-- build rather than a branch -- a refusal costs the grid and nothing else.
-- Each entry is nil = untried, false = unavailable.
local shaders = { [false] = nil, [true] = nil }
local shaderVariants = { [false] = nil, [true] = nil }
local shaderErrors = { [false] = nil, [true] = nil }
local activeShader = nil      -- the variant this pass bound

-- Scene canvases, one per NAMED SLOT. There are exactly two callers and
-- they want different sizes -- the free-roam pass renders at the window's
-- pixel dimensions, the overworld battle at the GB's 160x144 -- and a
-- single cached canvas made every battle entry and exit reallocate one.
-- A slot reallocates only when its OWN size changes, which is a window
-- resize, so the pair is stable for a session.
local slots = {}
local canvas, canvasW, canvasH = nil, 0, 0   -- the slot this pass bound
local held = nil                             -- and the whole record for it
local active = false
local firstDrawPending = false

-- A READABLE depth canvas, so a later pass in the same frame can ask the
-- buffer questions rather than only write to it -- which is the whole of
-- what makes screen-space reflections possible (see Water).
--
-- `depth = true` in the target list, which is what this used to bind,
-- allocates an internal depth buffer that is written and tested and can
-- never be sampled. An explicit canvas is the same buffer with a texture
-- handle on it, and costs the same memory.
--
-- nil where the driver will not make one -- every depth format is optional
-- in GLES and a canvas is the only honest test of any of them, so this asks
-- for several in order of preference: 24 bits, the same 24 riding a stencil
-- (a pairing some mobile drivers will texture when the bare format they
-- refuse), 32-bit float, and 16 as the floor every GLES3 device can read.
-- Refused all four, beginScene falls straight back to the internal buffer,
-- which is exactly the old behaviour minus the reflections.
local DEPTH_FORMATS = { "depth24", "depth24stencil8", "depth32f", "depth16" }

local function newDepth(w, h)
  -- The LIGHT mobile path needs depth testing, not a readable depth texture.
  -- Skip four optional format allocations and let depthTarget() request the
  -- engine's internal depth buffer instead. Full-water reflections already
  -- degrade to their sky path when no sampled depth is present.
  if MOBILE_RUNTIME then
    mobileDiagnostic("checkpoint", "mobile-internal-depth-only", {
      caller="Voxel3D.newDepth", width=w, height=h,
      reason="skip-readable-depth-probes-on-mobile",
    })
    return nil
  end
  if not (love.graphics and love.graphics.newCanvas) then
    mobileDiagnostic("capability", "D06", "depth-canvas-api", false,
      "love.graphics.newCanvas-unavailable", { caller="Voxel3D.newDepth" })
    return nil
  end
  local c = nil
  local selected = nil
  local failures = {}
  for _, format in ipairs(DEPTH_FORMATS) do
    -- This attachment must have the same physical dimensions as the scene
    -- colour canvas; PixelCanvas pins both to one texel per requested pixel.
    mobileDiagnostic("checkpoint", "readable-depth-create-start:" .. format, {
      caller="PixelCanvas.new", format=format, width=w, height=h,
    })
    local ok, made = PixelCanvas.new(w, h,
                                     { format = format, readable = true })
    if ok and made then
      c, selected = made, format
      break
    end
    failures[#failures + 1] = format .. ":" .. tostring(made or "nil")
  end
  if not c then
    mobileDiagnostic("checkpoint", "readable-depth-unavailable", {
      caller="Voxel3D.newDepth", result="internal-depth-fallback",
      attempts=table.concat(failures, " | "), width=w, height=h,
    })
    return nil
  end
  mobileDiagnostic("checkpoint", "readable-depth-created", {
    caller="Voxel3D.newDepth", format=selected, width=w, height=h,
  })
  -- nearest: a depth is a distance, and a blend of two of them is a
  -- distance to nothing. The march wants the texel it landed on.
  pcall(c.setFilter, c, "nearest", "nearest")
  pcall(c.setWrap, c, "clamp", "clamp")
  -- and no compare mode: with one set, Texel returns a 0/1 shadow verdict
  -- instead of the depth, which is not what any reader here wants
  pcall(c.setDepthSampleMode, c)
  return c
end

-- The bound target for the slot this pass holds: the colour canvas plus
-- either the readable depth canvas or the internal buffer.
local function depthTarget()
  if held and held.depth then
    return { held.canvas, depthstencil = held.depth }
  end
  return { canvas, depth = true }
end

-- Every GPU object one slot owns. The mirror is the copy of the frame the
-- water pass reads (see beginWater); it is only ever made if something asks
-- for one, so a session that never sees a lake never pays for it.
local function releaseSlot(slotHeld)
  for _, key in ipairs({ "canvas", "depth", "mirror" }) do
    local obj = slotHeld[key]
    if obj and obj.release then pcall(obj.release, obj) end
    slotHeld[key] = nil
  end
end

local IDENTITY = Mat4.identity()

-- Whether the driver admits to supporting derivatives. Only a hint --
-- the compile below is the real test -- but it saves building a shader
-- that was never going to work, and it is how LOVE reports the ES2
-- extension the grid rides on.
local function derivativesOK()
  if MOBILE_RUNTIME then return false end
  if not (love.graphics and love.graphics.getSupported) then return false end
  local ok, caps = pcall(love.graphics.getSupported)
  return ok and caps and caps.shaderderivatives == true
end

local function shaderSource(variant, grid)
  local source, err = SHADER, nil
  if variant == "mobile-core" then
    source, err = mobileCoreShaderSource(SHADER)
    if not source then return nil, err end
  elseif variant == "mobile-safe" then
    source, err = mobileSafeShaderSource(SHADER)
    if not source then return nil, err end
  elseif variant ~= "full" then
    return nil, "unknown Voxel3D shader variant " .. tostring(variant)
  end
  if grid then source = "#define VOXEL_GRID 1\n" .. source end
  return source
end

local function warnShader(message)
  local logger = V and V.mod and V.mod.log
  if logger and type(logger.warn) == "function" then
    local ok = pcall(logger.warn, logger, "%s", tostring(message))
    if ok then return end
  end
  if type(print) == "function" then
    pcall(print, "VOXEL_ASCENDANT: " .. tostring(message))
  end
end

local function compileShader(variant, grid)
  local source, sourceErr = shaderSource(variant, grid)
  if not source then return nil, tostring(sourceErr) end
  local traceVariant = tostring(variant) .. ":grid=" .. tostring(grid == true)
  mobileDiagnostic("checkpoint", "shader-compile-start:" .. traceVariant, {
    caller="love.graphics.newShader", variant=variant,
    grid=grid == true,
  })
  local ok, shaderOrError = pcall(love.graphics.newShader, source)
  if ok and shaderOrError then
    mobileDiagnostic("checkpoint", "shader-compiled:" .. traceVariant, {
      caller="Voxel3D.compileShader", variant=variant,
      grid=grid == true,
    })
    return shaderOrError, nil
  end
  mobileDiagnostic("checkpoint", "shader-compile-rejected:" .. traceVariant, {
    caller="Voxel3D.compileShader", variant=variant,
    grid=grid == true, error=shaderOrError,
  })
  return nil, tostring(shaderOrError or "shader compiler returned no object")
end

-- The scene shader. `grid` asks for the wireframe variant, and nil comes
-- back when that one will not build -- callers then fall back to the plain
-- one rather than losing the whole 3D pass.
function Voxel3D.shader(grid)
  grid = grid and true or false
  if shaders[grid] == nil then
    if grid and MOBILE_RUNTIME then
      -- The optional grid requires derivatives and a second shader program.
      -- Keep the first phone frame to one known-small program.
      shaders[grid] = false
      shaderVariants[grid] = "mobile-disabled-grid"
      shaderErrors[grid] = {
        full = "grid disabled by mobile first-frame policy",
      }
    elseif grid and not derivativesOK() then
      shaders[grid] = false
      shaderVariants[grid] = "unsupported-derivatives"
      shaderErrors[grid] = {
        full = "driver does not expose shader derivatives",
      }
    elseif MOBILE_RUNTIME then
      -- A native shader compiler can block instead of returning an error, so
      -- attempting FULL before the fallback defeats the fallback completely.
      -- Phones compile only the bounded world-core program; desktop keeps the
      -- full -> mobile-safe rejection path below.
      local shader, mobileError = compileShader("mobile-core", false)
      shaderErrors[grid] = {
        full = "skipped-on-mobile",
        mobileCore = mobileError and tostring(mobileError) or nil,
      }
      if shader then
        shaders[grid] = shader
        shaderVariants[grid] = "mobile-core"
        warnShader("Gen-1 Voxel3D mobile first-frame policy: using the "
          .. "mobile-core 3D shader; optional shadows, weather, glass, "
          .. "reflections and voxel grid are disabled")
      else
        shaders[grid] = false
        shaderVariants[grid] = "unavailable"
        mobileDiagnostic("capability", "D07", "shader-compile-link", false,
          tostring(mobileError), {
            caller="Voxel3D.shader", variant="mobile-core-only", grid=false,
          })
        warnShader("Gen-1 Voxel3D mobile-core shader failed: "
          .. tostring(mobileError) .. " -- 3D remains unavailable")
      end
    else
      local shader, fullError = compileShader("full", grid)
      if shader then
        shaders[grid] = shader
        shaderVariants[grid] = "full"
        shaderErrors[grid] = {}
      else
        -- Do not silently turn VOXEL FULL into a flat map. Record and emit
        -- the complete driver response, then retry the same 3D/weather shader
        -- with only the optional Gen-1 aerial cloud/bird block omitted.
        warnShader(("Gen-1 Voxel3D full shader did not compile (grid=%s): %s")
          :format(tostring(grid), tostring(fullError)))
        local fallback, fallbackError = compileShader("mobile-safe", grid)
        shaderErrors[grid] = {
          full = tostring(fullError),
          mobileSafe = fallbackError and tostring(fallbackError) or nil,
        }
        if fallback then
          shaders[grid] = fallback
          shaderVariants[grid] = "mobile-safe"
          warnShader(("Gen-1 Voxel3D is using the mobile-safe 3D shader "
            .. "(grid=%s); weather, glass and cutaway remain enabled; "
            .. "only cloud/bird ground shadows are neutral")
            :format(tostring(grid)))
        else
          shaders[grid] = false
          shaderVariants[grid] = "unavailable"
          if grid then
            -- Grid is optional: beginScene immediately retries the plain
            -- shader, so its isolated failure is evidence but not a lost
            -- voxel renderer.
            mobileDiagnostic("checkpoint", "grid-shader-unavailable", {
              caller="Voxel3D.shader", variant="full+mobile-safe",
              grid=true, error=tostring(fallbackError or fullError),
            })
          else
            mobileDiagnostic("capability", "D07", "shader-compile-link", false,
              tostring(fallbackError or fullError), {
                caller="Voxel3D.shader", variant="full+mobile-safe",
                grid=false,
              })
          end
          warnShader(("Gen-1 Voxel3D mobile-safe shader also failed "
            .. "(grid=%s): %s -- 3D remains unavailable")
            :format(tostring(grid), tostring(fallbackError)))
        end
      end
    end
  end
  return shaders[grid] or nil
end

-- Private QA receipts. They expose no assets and do not affect runtime
-- selection; deterministic gates use them to prove which program compiled
-- and that the mobile source still contains every weather/cutaway contract.
function Voxel3D.shaderVariant(grid)
  return shaderVariants[grid and true or false]
end

function Voxel3D.shaderCompileErrors(grid)
  local found = shaderErrors[grid and true or false]
  if type(found) ~= "table" then return found end
  local copy = {}
  for key, value in pairs(found) do copy[key] = value end
  return copy
end

function Voxel3D._shaderSource(variant, grid)
  return shaderSource(variant or "full", grid and true or false)
end

-- Whether the 3D path can run at all. False on a headless test run (no
-- love.graphics), without shader support, or where a depth canvas cannot be
-- created -- every caller treats that as "stay on the 2D path".
function Voxel3D.available(callSite)
  callSite = type(callSite) == "string" and callSite or "Voxel3D.available"
  -- Only an unfinished M7 graphics START marker means the previous process
  -- stopped inside a risky call. The recovery boot must not touch even the
  -- first capability seam; completed D00/D90/FAILURE receipts never get here.
  if mobileDiagnostic("recoveryMode") == true then return false end
  mobileDiagnostic("checkpoint", "gen1-voxel3d-available-start", {
    caller=callSite, context="world",
    reason="entering-graphics-capability-path",
  })
  if not (love and love.graphics and love.graphics.newCanvas
          and love.graphics.setDepthMode) then
    mobileDiagnostic("capability", "D06", "graphics-api", false,
      "newCanvas-or-setDepthMode-unavailable", {
        caller=callSite,
      })
    return false
  end
  local available = Voxel3D.shader() ~= nil
  if available then
    mobileDiagnostic("capability", "D06", "graphics-api", true,
      "canvas-depth-api-and-shader-ready", {
        caller=callSite, shader=shaderVariants[false],
      })
  else
    -- A cached rejected shader performs no compile probe on later calls, so
    -- explicitly close the high-level availability START receipt as well.
    mobileDiagnostic("checkpoint", "gen1-voxel3d-available-unavailable", {
      caller=callSite, context="world",
      reason="scene-shader-unavailable",
    })
  end
  return available
end

-- Hardware instancing is an optional acceleration, never a requirement for
-- voxel mode. In particular, some iPhone/OpenGL ES 2 drivers expose the rest
-- of the 3D path but not per-instance vertex attributes. Cache the capability
-- answer so a rejected driver is not probed again for every cold map.
local instancing = nil

function Voxel3D.canInstance()
  if instancing ~= nil then return instancing end
  -- Driver capability flags do not prove that per-instance attributes and the
  -- first drawInstanced call are safe. Phones use the byte-identical expanded
  -- mesh fallback until the native backends have a physical-device gate.
  if MOBILE_RUNTIME then
    instancing = false
    return false
  end
  local g = love and love.graphics
  if not (g and type(g.getSupported) == "function"
          and type(g.drawInstanced) == "function") then
    instancing = false
    return false
  end
  local ok, supported = pcall(g.getSupported)
  instancing = ok and type(supported) == "table"
               and supported.instancing == true or false
  return instancing
end

-- attachAttribute can still reject `perinstance` on a driver which advertised
-- the broad capability. ChunkMesher calls this only after releasing that
-- incomplete build and immediately retries through its historical expanded
-- geometry path.
function Voxel3D.rejectInstancing()
  instancing = false
end

-- Build a mesh in the shared format. `verts` is the LOVE vertex list and
-- `map` the triangle index list. Returns nil when meshes are unavailable,
-- which the callers treat the same way they treat a missing model.
function Voxel3D.newMesh(verts, map)
  if #verts == 0 then return nil end
  mobileDiagnostic("checkpoint", "mesh-create-start", {
    caller="love.graphics.newMesh", vertexCount=#verts,
    indexMode=map and "lua-table" or "none",
  })
  local ok, mesh = pcall(love.graphics.newMesh, Voxel3D.FORMAT, verts,
                         "triangles", "static")
  if not ok or not mesh then
    mobileDiagnostic("capability", "D09", "mesh-create", false,
      mesh or "newMesh-returned-nil", { caller="Voxel3D.newMesh" })
    return nil
  end
  mobileDiagnostic("checkpoint", "mesh-create-ready", {
    caller="love.graphics.newMesh", vertexCount=#verts,
    indexMode=map and "lua-table" or "none",
  })
  if map and #map > 0 then
    mobileDiagnostic("checkpoint", "mesh-index-map-start", {
      caller="mesh.setVertexMap", indexMode="lua-table", indexCount=#map,
    })
    local mapped, mapErr = pcall(mesh.setVertexMap, mesh, map)
    if not mapped then
      mobileDiagnostic("capability", "D09", "mesh-index-map", false,
        mapErr, { caller="Voxel3D.newMesh", indexMode="lua-table" })
    else
      mobileDiagnostic("checkpoint", "mesh-index-map-ready", {
        caller="mesh.setVertexMap", indexMode="lua-table", indexCount=#map,
      })
    end
  end
  return mesh
end

-- The quad corner offsets and UV corners for one face direction, in the
-- order the vertex map below stitches into two triangles. Corners are unit
-- offsets from the voxel's (x, y, z) minimum corner.
Voxel3D.FACE_CORNERS = {
  [1] = { { 1, 0, 0 }, { 1, 0, 1 }, { 1, 1, 1 }, { 1, 1, 0 } },  -- +X
  [2] = { { 0, 0, 1 }, { 0, 0, 0 }, { 0, 1, 0 }, { 0, 1, 1 } },  -- -X
  [3] = { { 0, 1, 0 }, { 1, 1, 0 }, { 1, 1, 1 }, { 0, 1, 1 } },  -- +Y
  [4] = { { 0, 0, 1 }, { 1, 0, 1 }, { 1, 0, 0 }, { 0, 0, 0 } },  -- -Y
  [5] = { { 0, 0, 1 }, { 1, 0, 1 }, { 1, 1, 1 }, { 0, 1, 1 } },  -- +Z
  [6] = { { 1, 0, 0 }, { 0, 0, 0 }, { 0, 1, 0 }, { 1, 1, 0 } },  -- -Z
}

-- Append the six indices of quad `n` (0-based) to a triangle index list.
function Voxel3D.pushQuad(map, n)
  local b = n * 4
  map[#map + 1] = b + 1
  map[#map + 1] = b + 2
  map[#map + 1] = b + 3
  map[#map + 1] = b + 1
  map[#map + 1] = b + 3
  map[#map + 1] = b + 4
end

-- ---------------------------------------------------------------- camera --

-- An explicit camera, replacing the orbit below for as long as it is set:
-- { eye = {x,y,z}, focus = {x,y,z}, fov = radians, curve = k or nil,
--   up = {x,y,z} or nil }.
--
-- A caller with matrices of its own -- the VR eyes, whose view comes from
-- a tracked pose and whose projection is an off-centre frustum no
-- eye/focus/fov triple can express -- sets `view` and `proj` instead, and
-- the eye/focus fields stay for everything that reasons about the camera
-- rather than projecting with it (setLook, the sky, the water's lean).
--
-- The orbit is the free-roam camera and it is described entirely by ONE
-- number, the pitch, because that is all a camera following the player over
-- their own map ever needs. A staged shot -- the overworld battle's
-- over-the-shoulder rig (see BattleCam) -- is a placed camera: it has a yaw,
-- it does not sit above its focus, and its framing comes from the arena
-- rather than from the view size. Rather than widen the orbit into
-- something that could express both and be the wrong shape for each, a
-- caller with a camera of its own simply hands it over.
--
-- Everything downstream is unchanged by this: the shader uniforms, project()
-- and the overlay all read Voxel3D.vp / Voxel3D.eye, which are set the same
-- way either way.
Voxel3D.camera = nil

-- This frame's camera RAY FAN, set by viewProjection alongside vp: the
-- world direction a canvas point looks along (see Sky.paint's `ray`).
-- Present for every free-pitch camera -- the VR eyes bring theirs
-- (VRRig.eyeCamera), a placed eye/focus camera gets one built -- and nil
-- for the orbit, whose frame-hung sky is the classic look.
Voxel3D.skyRayLive = nil

-- Clouds, stars and rare sky events need a ray fan even in the classic orbit
-- so switching between ORBIT and 1ST/3RD does not teleport the atmosphere.
-- The orbit still leaves skyRayLive nil and therefore keeps its established
-- frame-shaped gradient; only the discrete atmosphere uses this second fan.
Voxel3D.atmosphereRayLive = nil

-- ------- which way, and how steeply, this camera looks
--
-- Two facts about the view direction, set alongside the eye and the focus
-- because they ARE the eye and the focus, and read by anything that has to
-- reason about the camera's ATTITUDE rather than about a point in front of
-- it:
--
--   lookFlat   the view direction flattened onto the ground plane and
--              normalized -- "the way the horizon lies from here", which is
--              what a reflection leans toward at the steeper rungs (Water).
--   descent    how far below horizontal the view runs, as a sine: 0 looking
--              level, 1 looking straight down. It is the number that says
--              whether there is a horizon in frame at all, and it answers
--              the same way for the orbit and for a placed battle camera --
--              which is why this is derived from the two vectors rather than
--              read off Voxel.angle, a rung the battle camera does not have.
--
-- A camera looking exactly straight down has no horizontal direction at all,
-- and lookFlat then keeps whatever it last held rather than becoming a zero
-- vector nothing downstream could normalize.
Voxel3D.lookFlat = { 0, 0, -1 }
Voxel3D.descent = 0

local function setLook(eye, focus)
  local dx = focus[1] - eye[1]
  local dy = focus[2] - eye[2]
  local dz = focus[3] - eye[3]
  local len = math.sqrt(dx * dx + dy * dy + dz * dz)
  if len < 1e-6 then return end
  Voxel3D.descent = math.max(0, math.min(1, -dy / len))
  local flat = math.sqrt(dx * dx + dz * dz)
  if flat < 1e-6 then return end
  Voxel3D.lookFlat = { dx / flat, 0, dz / flat }
end

local function cameraRay(eye, focus, upv, fov, aspect)
  if not (eye and focus and upv and fov and aspect) then return nil end
  local fx = focus[1] - eye[1]
  local fy = focus[2] - eye[2]
  local fz = focus[3] - eye[3]
  local fl = math.sqrt(fx * fx + fy * fy + fz * fz)
  if fl < 1e-6 then return nil end
  fx, fy, fz = fx / fl, fy / fl, fz / fl
  local crx = fy * upv[3] - fz * upv[2]
  local cry = fz * upv[1] - fx * upv[3]
  local crz = fx * upv[2] - fy * upv[1]
  local crl = math.sqrt(crx * crx + cry * cry + crz * crz)
  if crl < 1e-6 then return nil end
  crx, cry, crz = crx / crl, cry / crl, crz / crl
  local cux = cry * fz - crz * fy
  local cuy = crz * fx - crx * fz
  local cuz = crx * fy - cry * fx
  local tanY = math.tan(fov / 2)
  local tanX = tanY * aspect
  return {
    base = { fx - crx * tanX + cux * tanY,
             fy - cry * tanX + cuy * tanY,
             fz - crz * tanX + cuz * tanY },
    du = { crx * 2 * tanX, cry * 2 * tanX, crz * 2 * tanX },
    dv = { cux * -2 * tanY, cuy * -2 * tanY, cuz * -2 * tanY },
  }
end

-- View and projection for a `vw` x `vh` world-pixel view centred on
-- (cx, cy) in world pixels. Returns the combined matrix.
function Voxel3D.viewProjection(cx, cy, vw, vh)
  Voxel3D.atmosphereRayLive = nil
  local cam = Voxel3D.camera
  if cam then
    local eye, focus = cam.eye, cam.focus
    Voxel3D.eye = eye
    -- kept beside the eye for horizonY: where the sky's pale end goes is a
    -- question about which way this camera looks, and only these two answer it
    Voxel3D.focus = focus
    setLook(eye, focus)
    -- a camera that brought its own matrices (a VR eye) projects with
    -- them; only the clip-space Y flip is added, for the same canvas
    -- reason as every other branch here
    if cam.view and cam.proj then
      Voxel3D.fovY = cam.fov
      -- the VR eyes bring their fan with them (VRRig.eyeCamera)
      Voxel3D.skyRayLive = cam.skyRay
      Voxel3D.atmosphereRayLive = cam.skyRay
      return Mat4.mul(Mat4.mul(Mat4.scale(1, -1, 1), cam.proj), cam.view)
    end
    local dx = eye[1] - focus[1]
    local dy = eye[2] - focus[2]
    local dz = eye[3] - focus[3]
    local dist = math.max(1, math.sqrt(dx * dx + dy * dy + dz * dz))
    -- kept for the passes that measure an ANGLE against this camera rather
    -- than a position: the water's reflected sun is sized in radians, and
    -- radians per canvas pixel is exactly this over the frame height
    Voxel3D.fovY = cam.fov
    local proj = Mat4.perspective(cam.fov, vw / vh,
                                  math.max(1, dist * 0.05), dist * 4 + 4096)
    -- the same clip-space Y flip the orbit needs, for the same reason: we
    -- bypass LOVE's transform_projection and canvas coordinates run Y down
    proj = Mat4.mul(Mat4.scale(1, -1, 1), proj)
    local upv = cam.up or { 0, 1, 0 }
    -- A free-pitch camera uses the fan for both its gradient and discrete
    -- atmosphere. The helper is allocation-bounded (three tiny vectors once
    -- per frame); per-star projection in Sky is scalar and allocation-free.
    Voxel3D.skyRayLive = cameraRay(eye, focus, upv, cam.fov, vw / vh)
    Voxel3D.atmosphereRayLive = Voxel3D.skyRayLive
    -- world up by default, so the horizon stays level -- a placed camera
    -- that rolled with its own pitch would tip the whole arena. A caller
    -- may hand its own up: the first-person BLEND does, because its far
    -- end is the orbit, whose up leans with the pitch -- world up at the
    -- orbit's steep end degenerates against a straight-down view.
    return Mat4.mul(proj, Mat4.lookAt(eye, focus, cam.up or { 0, 1, 0 }))
  end

  -- the orbit: a fixed pitch per rung, and the classic frame-hung sky --
  -- no ray fan wanted
  Voxel3D.skyRayLive = nil

  local a = Voxel.angle
  local focal = Voxel.FOCAL
  local dist = focal * vh
  -- the FOV that makes a straight-down camera at `dist` frame exactly `vh`
  -- world pixels, which is the framing the flat view already has
  local fov = 2 * math.atan(1 / (2 * focal))
  Voxel3D.fovY = fov

  local focus = { cx, 0, cy }
  local eye = { cx, dist * math.cos(a), cy + dist * math.sin(a) }
  -- exposed for camera-facing billboards (VoxelScene yaws sprites at it)
  Voxel3D.eye = eye
  Voxel3D.focus = focus
  setLook(eye, focus)
  -- perpendicular to the view direction in the YZ plane: north is screen-up
  -- when looking straight down, +Y is screen-up when looking level. Never
  -- parallel to the view direction, so there is no degenerate a = 0 case.
  local up = { 0, math.sin(a), -math.cos(a) }
  -- Keep the classic orbit gradient frame-shaped, but project every cloud,
  -- star and event through the orbit's real north-facing camera. This makes
  -- the atmosphere continuous when entering or leaving 1ST/3RD.
  Voxel3D.atmosphereRayLive = cameraRay(eye, focus, up, fov, vw / vh)

  local proj = Mat4.perspective(fov, vw / vh,
                                math.max(1, dist * 0.05), dist * 4 + 4096)
  -- Flip clip-space Y. Mat4.perspective emits textbook GL clip space with
  -- +Y up, but we bypass LOVE's own transform_projection, and LOVE's canvas
  -- coordinates run Y DOWN -- so without this the entire scene composites
  -- vertically mirrored: north at the bottom and buildings extruding
  -- downward. Winding flips with it, which is free here because the pass
  -- draws with culling off.
  proj = Mat4.mul(Mat4.scale(1, -1, 1), proj)
  return Mat4.mul(proj, Mat4.lookAt(eye, focus, up))
end

-- ------- the horizon
--
-- Where the ground plane's vanishing line lands, in canvas pixels down from the
-- top edge, or nil when this camera has no horizon to find.
--
-- Not a fraction picked by eye. A direction ALONG the ground is a point at
-- infinity, and putting one through the same matrix the geometry is drawn with
-- gives the line every ground plane in the scene converges on -- so the sky's
-- pale end meets the horizon at any pitch, fov, window shape or zoom, and rides
-- the camera tween instead of having to be retuned against it.
--
-- The world CURVE is not in it, and cannot be: it bends distant ground down in
-- the vertex shader, so the ground's apparent edge sits BELOW this line by
-- however much the bend took. What shows in between is the haze the sky's fill
-- already is, which is what a curved-away horizon should look like.
--
-- nil in two cases, both meaning "no horizon in this frame": a camera looking
-- straight down, whose forward direction has no horizontal part to send to
-- infinity, and one whose vanishing line is behind it.
function Voxel3D.horizonY(h)
  local m, eye, focus = Voxel3D.vp, Voxel3D.eye, Voxel3D.focus
  if not (m and eye and focus and h and h > 0) then return nil end
  local dx = focus[1] - eye[1]
  local dz = focus[3] - eye[3]
  local len = math.sqrt(dx * dx + dz * dz)
  if len < 1e-6 then return nil end
  dx, dz = dx / len, dz / len
  -- a DIRECTION, so its w is zero and the matrix's translation column drops
  -- out; the clip-space Y flip is already baked into m, so this comes out in
  -- canvas coordinates rather than needing one
  local y = m[5] * dx + m[7] * dz
  local w = m[13] * dx + m[15] * dz
  if w <= 1e-6 then return nil end
  return (y / w * 0.5 + 0.5) * h
end

-- The horizon as a LINE rather than a row, for a camera that can ROLL --
-- a VR eye. A head tipped sideways tips the true horizon across the
-- canvas, and a sky painted in flat rows then visibly hinges with the
-- head. So: project the flat forward direction (a point ON the vanishing
-- line) and the same direction nudged a hair of world-up (a point just
-- above it); the difference is the canvas direction "down toward the
-- ground", perpendicular to the horizon however the head is tipped.
--
-- Returns (ax, ay, edge, top): a unit axis in canvas pixels pointing from
-- sky toward ground, the horizon's signed distance along it -- a pixel at
-- canvas (x, y) is above the horizon while x*ax + y*ay < edge -- and,
-- when `elev` (radians) is given, the distance the direction that far
-- ABOVE the horizon projects to. `top` is what pins the gradient's far
-- end to a real direction in the sky: extrapolating it linearly from a
-- pixels-per-radian estimate left the bands sliding as a pitch moved the
-- horizon through the frame, because a perspective's rows are tan-spaced,
-- not angle-spaced. nil `top` (the elevated direction is outside this
-- frustum's forward hemisphere) leaves the caller its estimate. nil
-- everything with no horizon in front of this camera.
function Voxel3D.horizonLine(w, h, elev)
  local m, eye, focus = Voxel3D.vp, Voxel3D.eye, Voxel3D.focus
  if not (m and eye and focus and w and h and h > 0) then return nil end
  local dx = focus[1] - eye[1]
  local dz = focus[3] - eye[3]
  local len = math.sqrt(dx * dx + dz * dz)
  if len < 1e-6 then return nil end
  dx, dz = dx / len, dz / len
  local function proj(vx, vy, vz)
    local x = m[1] * vx + m[2] * vy + m[3] * vz
    local y = m[5] * vx + m[6] * vy + m[7] * vz
    local ww = m[13] * vx + m[14] * vy + m[15] * vz
    if ww <= 1e-6 then return nil end
    return (x / ww * 0.5 + 0.5) * w, (y / ww * 0.5 + 0.5) * h
  end
  local qx, qy = proj(dx, 0, dz)
  if not qx then return nil end
  local rx, ry = proj(dx, 0.02, dz)
  if not rx then return nil end
  local ax, ay = qx - rx, qy - ry
  local al = math.sqrt(ax * ax + ay * ay)
  if al < 1e-6 then ax, ay = 0, 1 else ax, ay = ax / al, ay / al end
  local top = nil
  if elev then
    local ce, se = math.cos(elev), math.sin(elev)
    local tx, ty = proj(dx * ce, se, dz * ce)
    if tx then top = tx * ax + ty * ay end
  end
  return ax, ay, qx * ax + qy * ay, top
end

-- ------- the hour's light
--
-- What the scene shader multiplies every surface by (see dayTint in the
-- shader). Set per pass by whoever knows what map is being drawn --
-- VoxelScene for free-roam, BattleScene for the arena -- because "is this
-- outdoors" is the map's question, not this pass's. Neutral until somebody
-- answers it, so a caller that never does draws exactly what it always drew.
Voxel3D.tint = { 1, 1, 1 }

-- The window-glass pass, set the same way and for the same reason: the
-- MASK belongs to the map's tileset (GlassMask.texture) and how lit the
-- panes are belongs to the hour and to being outdoors at all
-- (DayNight.windowLight). nil / 0 -- the defaults -- draw no glass effect.
Voxel3D.glassMask = nil
Voxel3D.glassNight = 0

-- the glint, fed by the camera's TRAVEL rather than by a clock (see
-- VoxelScene.glintStep): the phase is radians already wrapped to 2pi, and
-- the strength is 0 whenever the view has been still for a beat
Voxel3D.glassPhase = 0
Voxel3D.glassGlint = 0

-- The sun or moon disc's place on this camera's canvas, or nil when the
-- body is set, on the southern half of the sky, or behind the camera.
--
-- The direction comes from DayNight (true bearing, squashed elevation) and
-- goes through the SAME matrix the geometry is drawn with, as a point at
-- infinity -- exactly how horizonY finds the vanishing line. So the disc's
-- azimuth is honest: it stands over the point on the horizon its shadows
-- point away from, at every pitch, fov, window shape and zoom.
--
-- Must run after beginScene has set Voxel3D.vp for this frame's camera.
function Voxel3D.skyBody(w, h)
  local m = Voxel3D.vp
  local b = m and DayNight.body()
  if not b then return nil end
  local x = m[1] * b.dx + m[2] * b.dy + m[3] * b.dz
  local y = m[5] * b.dx + m[6] * b.dy + m[7] * b.dz
  local ww = m[13] * b.dx + m[14] * b.dy + m[15] * b.dz
  if ww <= 1e-6 then return nil end
  local amt, color = DayNight.glow()
  return {
    x = (x / ww * 0.5 + 0.5) * w,
    y = (y / ww * 0.5 + 0.5) * h,
    -- the body's WORLD direction, for the skybox path: a ray-fan caller
    -- measures the twilight glow by the angle between a pixel's ray and
    -- this, so the glow is pinned to the sky like the bands are (see
    -- Sky.paint's glowDir)
    dx = b.dx, dy = b.dy, dz = b.dz,
    moon = b.moon,
    glowAmt = amt,
    glowColor = color,
  }
end

-- ------- the VR sky's world-anchored pieces
--
-- Both exist because a headset showed the shortcuts: a gradient painted
-- off the frame moved with the head that carried the frame, and a
-- screen-space disc re-snapped its cell grid with every head movement
-- and held its face square to the canvas instead of to the world. The
-- gradient's fix rides the camera record itself (skyRay -- see VRRig and
-- Sky's useRay path); the disc's is below.

-- The sun or moon as a QUAD IN THE WORLD: the baked cell art
-- (Sky.discImage) on a square spanned about the hour's direction, its
-- corners projected through this very eye -- so the disc is pinned to
-- the sky like the terrain is to the ground, stable under every head
-- motion, its face upright over the world. Runs inside beginScene's sky
-- window, before the depth mode is set, so the world draws over it.
local discMesh = nil

local function drawWorldDisc(w, h)
  local b = DayNight.body()
  if not (b and b.dy and b.dy > 0.005) then return end
  -- A direction outside the camera fan must not contribute one enormous
  -- perspective corner. That was the pale checkerboard arc seen at DUSK in
  -- fixed battle shots. Cull by the body's centre before building its quad.
  local ray = Voxel3D.skyRayLive
  if ray then
    local _, _, visible = Sky.projectDirection(ray, w, h, b)
    if not visible then return end
  end
  local amt = DayNight.glow()
  local img = Sky.discImage(b.moon, Sky.discLooming(amt, b.moon))
  if not img then return end
  local m = Voxel3D.vp
  if not m then return end
  local hl = math.sqrt(b.dx * b.dx + b.dz * b.dz)
  if hl < 1e-6 then return end
  -- right = horizontal, perpendicular to the direction; up completes it
  local rx, rz = b.dz / hl, -b.dx / hl
  local ux = -rz * b.dy
  local uy = rz * b.dx - rx * b.dz
  local uz = rx * b.dy
  local ul = math.sqrt(ux * ux + uy * uy + uz * uz)
  if ul < 1e-6 then return end
  ux, uy, uz = ux / ul, uy / ul, uz / ul
  if uy < 0 then ux, uy, uz = -ux, -uy, -uz end
  -- apparent size is an ANGLE, the same fraction of the view the flat
  -- screen's disc takes of its frame; the low sun looms exactly as there
  local ang = Sky.DISC_FRAC * (Voxel3D.fovY or 1)
  if Sky.discLooming(amt, b.moon) then ang = ang * 1.4 end
  local k = math.tan(ang)
  local verts = {}
  local corners = { { -1, -1, 0, 1 }, { 1, -1, 1, 1 },
                    { 1, 1, 1, 0 }, { -1, 1, 0, 0 } }
  for i, c in ipairs(corners) do
    local vx = b.dx + (rx * c[1] + ux * c[2]) * k
    local vy = b.dy + (uy * c[2]) * k
    local vz = b.dz + (rz * c[1] + uz * c[2]) * k
    local x = m[1] * vx + m[2] * vy + m[3] * vz
    local y = m[5] * vx + m[6] * vy + m[7] * vz
    local ww = m[13] * vx + m[14] * vy + m[15] * vz
    if ww <= 1e-6 then return end
    verts[i] = { (x / ww * 0.5 + 0.5) * w, (y / ww * 0.5 + 0.5) * h,
                 c[3], c[4] }
  end
  mobileDiagnostic("checkpoint", "sky-disc-render-start", {
    caller="Voxel3D.drawDisc", context="world",
  })
  local discOK = pcall(function()
    if not discMesh then
      mobileDiagnostic("checkpoint", "sky-disc-mesh-create-start", {
        caller="love.graphics.newMesh", context="world", vertices=4,
      })
      discMesh = love.graphics.newMesh(4, "fan", "stream")
    end
    mobileDiagnostic("checkpoint", "sky-disc-vertex-upload-start", {
      caller="Mesh.setVertices", context="world", vertices=4,
    })
    discMesh:setVertices(verts)
    discMesh:setTexture(img)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(discMesh)
  end)
  mobileDiagnostic("checkpoint",
    discOK and "sky-disc-render-ready" or "sky-disc-render-unavailable", {
      caller="Voxel3D.drawDisc", context="world", ok=discOK,
    })
end

-- ----------------------------------------------------------------- scene --

-- Begin the 3D pass into a `w` x `h` pixel canvas centred on world
-- (cx, cy), covering `vw` x `vh` world pixels. Returns false when the pass
-- could not start, in which case the caller must not call endScene.
-- `sky` is an optional {r, g, b, a} in 0..1 to clear the void to, for the
-- pitch where the horizon is in frame (VoxelScene.skyFor). nil leaves the
-- void transparent, which is what every rung below it wants.
-- `slot` names which cached canvas to render into (see `slots` above);
-- omitted is the free-roam world pass.
function Voxel3D.beginScene(w, h, cx, cy, vw, vh, sky, slot, skyContext)
  -- the wireframe variant when the player has it on AND it built; either
  -- answer falls through to the plain scene rather than to no scene
  local grid = VoxelGrid.enabled()
  local sh = grid and Voxel3D.shader(true) or nil
  if not sh then
    grid, sh = false, Voxel3D.shader()
  end
  if not sh then
    mobileDiagnostic("capability", "D07", "scene-shader", false,
      "no-scene-shader-object", { caller="Voxel3D.beginScene" })
    return false
  end
  local name = slot or "world"
  local slotHeld = slots[name]
  if not (slotHeld and slotHeld.w == w and slotHeld.h == h) then
    mobileDiagnostic("checkpoint", "color-canvas-create-start", {
      caller="PixelCanvas.new", slot=name, width=w, height=h,
    })
    local ok, c = PixelCanvas.new(w, h)
    if not ok or not c then
      mobileDiagnostic("capability", "D08", "color-canvas-create", false,
        c or "PixelCanvas-returned-nil", {
          caller="Voxel3D.beginScene", slot=name, width=w, height=h,
        })
      return false
    end
    mobileDiagnostic("checkpoint", "color-canvas-created", {
      caller="Voxel3D.beginScene", slot=name, width=w, height=h,
      format="default-dpiscale-1",
    })
    c:setFilter("nearest", "nearest")
    if slotHeld then releaseSlot(slotHeld) end
    -- the depth canvas is sized with its colour, so a window resize
    -- reallocates the pair together and they can never disagree
    slotHeld = { canvas = c, w = w, h = h, depth = newDepth(w, h) }
    slots[name] = slotHeld
  end
  held = slotHeld
  canvas, canvasW, canvasH = held.canvas, w, h
  -- a depth buffer is what makes occlusion real: walk behind a building and
  -- the building wins, with no y-sorting anywhere
  mobileDiagnostic("checkpoint", "framebuffer-depth-attach-start", {
    caller="love.graphics.setCanvas", slot=name,
    depth=held.depth and "readable" or "internal",
  })
  local ok = pcall(love.graphics.setCanvas, depthTarget())
  if not ok and held.depth then
    -- the readable canvas would not bind; fall back to the internal buffer
    -- for the rest of this session rather than losing the whole 3D pass
    pcall(held.depth.release, held.depth)
    held.depth = nil
    mobileDiagnostic("checkpoint", "readable-depth-attach-rejected", {
      caller="Voxel3D.beginScene", slot=name,
      result="retry-internal-depth",
    })
    mobileDiagnostic("checkpoint", "framebuffer-internal-retry-start", {
      caller="love.graphics.setCanvas", slot=name, depth="internal",
    })
    ok = pcall(love.graphics.setCanvas, depthTarget())
  end
  if not ok then
    pcall(love.graphics.setCanvas)
    mobileDiagnostic("capability", "D08", "framebuffer-depth-attach", false,
      "readable-and-internal-depth-target-bind-failed", {
        caller="Voxel3D.beginScene", slot=name, width=w, height=h,
      })
    return false
  end
  mobileDiagnostic("checkpoint", "framebuffer-depth-attached", {
    caller="Voxel3D.beginScene", slot=name,
    depth=held.depth and "readable" or "internal",
  })
  -- Ahead of the clear, because the sky's bands are placed off the ground
  -- plane's vanishing line and that is a property of this matrix.
  Voxel3D.vp = Voxel3D.viewProjection(cx, cy, vw, vh)
  -- This frame's pixels per WORLD pixel: the size a diorama pixel is on
  -- screen. The sky's dither grid is cut to it, and so is the water's --
  -- one number, so the two break up on the same checkerboard.
  Voxel3D.cell = w / math.max(1, vw or w)
  -- A FREE-PITCH camera's sky is ANCHORED IN SPACE, where the orbit's is
  -- glued to the frame. One discriminator: skyRayLive, set by
  -- viewProjection above for every camera whose pitch the player steers
  -- -- the VR eyes and the flat first-person rig alike. With a fan, the
  -- gradient is a SKYBOX (every pixel takes its band, and its GBC
  -- checker, from its ray's true elevation -- no motion of the camera
  -- moves a band, only the clock recolours them) and the sun or moon
  -- hangs in the WORLD (drawWorldDisc). Without one -- the orbit, whose
  -- pitch is the rung's -- the classic frame-hung painting stands.
  local skyRay = Voxel3D.skyRayLive
  local atmosphereRay = Voxel3D.atmosphereRayLive or skyRay
  local skyWeather = skyContext and skyContext.weather or nil
  local bodyObscured = skyWeather == "storm" or skyWeather == "fog"
                       or skyWeather == "rain" or skyWeather == "snow"
  local hy = Voxel3D.horizonY(h)
  -- where the sky's bottom edge lands, which is what the reflection
  -- reads its bands against (see Water). nil when nothing painted bands.
  Voxel3D.skyEdge = (sky and sky.bands) and Sky.region(h, hy) or nil
  if sky then
    love.graphics.clear(sky[1], sky[2], sky[3], sky[4] or 1, true, true)
    -- The sky goes down here, in the one window in this function where a
    -- rectangle is just a rectangle: the depth mode and the scene shader are
    -- both set below. Sky.paint puts them aside anyway -- beginScene is not the
    -- only thing that has ever left a shader bound.
    --
    -- w / vw is this frame's pixels per WORLD pixel, which is the size a diorama
    -- pixel is on screen: the sky's dither grid is cut to that, so its squares
    -- are the same size as the world's own and follow every resize and zoom.
    -- The banded sky also hangs the hour's sun or moon (skyBody projects it
    -- through this very camera); a flat sky has no bands and hangs nothing.
    -- Terrain and billboards already use the mobile clip-space convention.
    -- Sky.paint is the one contained 2-D pass inside that same Canvas, so on
    -- iOS it needs the established pre-flip used by weather/backdrop pixels.
    -- Without it only the sky artwork (most visibly the cloud silhouettes)
    -- is upside down while the 3-D world remains upright.
    love.graphics.push("all")
    CanvasPresentation.begin2D(love.graphics, h)
    if skyRay and sky.bands then
      Sky.paint(w, h, sky, nil, Voxel3D.cell,
                bodyObscured and nil or Voxel3D.skyBody(w, h),
                nil, nil, skyRay, {
                  ray = atmosphereRay,
                  weather = skyContext and skyContext.weather or nil,
                  arena = skyContext and skyContext.arena or nil,
                  mapId = skyContext and skyContext.mapId or nil,
                  shadowPolicy = skyContext and skyContext.shadowPolicy or nil,
                  battleView = skyContext and skyContext.battleView == true,
                })
      love.graphics.pop()
      if not bodyObscured and not (skyContext and skyContext.arena) then
        drawWorldDisc(w, h)
      end
    else
      Sky.paint(w, h, sky, hy, Voxel3D.cell,
                sky.bands and not bodyObscured and Voxel3D.skyBody(w, h) or nil,
                nil, nil, nil, {
                  ray = atmosphereRay,
                  weather = skyContext and skyContext.weather or nil,
                  arena = skyContext and skyContext.arena or nil,
                  mapId = skyContext and skyContext.mapId or nil,
                  shadowPolicy = skyContext and skyContext.shadowPolicy or nil,
                  battleView = skyContext and skyContext.battleView == true,
                })
      love.graphics.pop()
    end
  else
    love.graphics.clear(0, 0, 0, 0, true, true)
  end
  love.graphics.setDepthMode("lequal", true)
  -- models mirror on X for right-facing and alternate walk steps, which
  -- flips winding; hidden faces are already culled at build time, so there
  -- is nothing to gain from backface culling and a real bug to avoid
  love.graphics.setMeshCullMode("none")
  mobileDiagnostic("checkpoint", "scene-shader-bind-start", {
    caller="love.graphics.setShader", context="world", slot=name,
    variant=shaderVariants[grid],
  })
  local shaderBound, shaderBindError = pcall(love.graphics.setShader, sh)
  if not shaderBound then
    pcall(love.graphics.setCanvas)
    mobileDiagnostic("fail", "D07", "scene-shader-bind",
      tostring(shaderBindError), {
        caller="love.graphics.setShader", context="world", slot=name,
        variant=shaderVariants[grid],
      })
    return false
  end
  mobileDiagnostic("checkpoint", "scene-shader-bound", {
    caller="Voxel3D.beginScene", context="world", slot=name,
    variant=shaderVariants[grid],
  })
  love.graphics.setColor(1, 1, 1, 1)
  mobileDiagnostic("checkpoint", "scene-uniform-batch-start", {
    caller="Shader.send", context="world", slot=name,
    variant=shaderVariants[grid],
  })
  pcall(sh.send, sh, "vp", "row", Voxel3D.vp)
  pcall(sh.send, sh, "eye", Voxel3D.eye)
  if MOBILE_RUNTIME then
    -- The standalone phone program declares exactly these presentation
    -- uniforms. Do not probe absent desktop uniforms through pcall: some GLES
    -- drivers defer uniform realization to first use, which puts avoidable
    -- work back into the frame this path is meant to protect.
    pcall(sh.send, sh, "ghost", 0)
    pcall(sh.send, sh, "ghostColor", Voxel3D.GHOST_COLOR)
    pcall(sh.send, sh, "dayTint", Voxel3D.tint or { 1, 1, 1 })
  else
  -- the sun's frame, filled by ShadowMap just before this pass opened.
  -- Sent unconditionally: the sampler is declared either way, and leaving
  -- one unbound is a driver-dependent crash rather than a fallback.
  local map = not MOBILE_RUNTIME and Shadows.enabled() and ShadowMap.active()
  pcall(sh.send, sh, "sunVP", "row", map and ShadowMap.uvVP or IDENTITY)
  -- mobile-core has no sunMap sampler; do not create ShadowMap's otherwise
  -- mandatory 1x1 GPU placeholder merely to send it to an absent uniform.
  local tex = not MOBILE_RUNTIME and ShadowMap.texture() or nil
  if tex then pcall(sh.send, sh, "sunMap", tex) end
  pcall(sh.send, sh, "sunDark", map and Voxel3D.SHADOW_ALPHA or 0)
  -- Every scene begins with ordinary world receivers. Camera-facing battle
  -- cards suppress only this compare around their own draw; the terrain or
  -- backdrop contact pass still receives the shadow they cast.
  pcall(sh.send, sh, "sunReceive", 1)
  pcall(sh.send, sh, "sunBias", ShadowMap.bias)
  local texel = 1 / ShadowMap.res
  pcall(sh.send, sh, "sunTexel", { texel, texel })
  local shadowPolicy = skyContext and skyContext.shadowPolicy or nil
  pcall(sh.send, sh, "cloudShadow",
        shadowPolicy and shadowPolicy.cloudOpacity or 0)
  pcall(sh.send, sh, "cloudTime", Sky.clock or 0)
  pcall(sh.send, sh, "cloudProgress",
        shadowPolicy and shadowPolicy.cloudProgress or 0)
  pcall(sh.send, sh, "cloudSeed",
        shadowPolicy and shadowPolicy.cloudSeed or 0)
  pcall(sh.send, sh, "birdShadow",
        shadowPolicy and shadowPolicy.birdOpacity or 0)
  pcall(sh.send, sh, "birdProgress",
        shadowPolicy and shadowPolicy.birdProgress or 0)
  pcall(sh.send, sh, "birdSeed",
        shadowPolicy and shadowPolicy.birdSeed or 0)
  pcall(sh.send, sh, "birdCount",
        shadowPolicy and shadowPolicy.birdCount or 1)
  pcall(sh.send, sh, "birdScale",
        shadowPolicy and shadowPolicy.birdScale or 1)
  pcall(sh.send, sh, "birdDirection",
        shadowPolicy and shadowPolicy.birdDirection or 1)
  pcall(sh.send, sh, "birdLegendary",
        shadowPolicy and shadowPolicy.birdLegendary and 1 or 0)
  local focus = Voxel3D.focus or { 0, 0, 0 }
  pcall(sh.send, sh, "shadowAnchor", { focus[1] or 0, focus[3] or 0 })
  if grid then
    pcall(sh.send, sh, "gridDark", VoxelGrid.DARK)
    pcall(sh.send, sh, "gridWidth", VoxelGrid.width())
  end
  -- ordinary shading until the silhouette pass asks for otherwise. Sent
  -- every frame rather than once, because a scene that opened mid-ghost --
  -- a driver hiccup between beginGhost and endGhost -- would otherwise
  -- start out flattening everything it drew.
  pcall(sh.send, sh, "ghost", 0)
  pcall(sh.send, sh, "ghostColor", Voxel3D.GHOST_COLOR)
  -- the hour's light, as the caller last set it (see Voxel3D.tint)
  pcall(sh.send, sh, "dayTint", Voxel3D.tint or { 1, 1, 1 })
  local weather = skyContext and (skyContext.groundWeather
                                   or skyContext.weather) or nil
  Voxel3D.weatherKind = (weather == "heat" and 3)
                        or (weather == "snow" and 2)
                        or ((weather == "rain" or weather == "storm") and 1)
                        or 0
  Voxel3D.weatherAmount = math.max(0, math.min(1,
    tonumber(skyContext and skyContext.groundAmount) or 1))
  pcall(sh.send, sh, "weatherGround", 0)
  pcall(sh.send, sh, "weatherGrass", 0)
  pcall(sh.send, sh, "weatherAmount", Voxel3D.weatherAmount)
  pcall(sh.send, sh, "weatherTime", Sky.clock or 0)
  -- the window glass: the tileset's mask (or the blank -- the sampler is
  -- declared either way, and unbound is a driver-dependent crash), how lit
  -- the panes are, and the movement-fed glint as the caller last set it
  local mask = not MOBILE_RUNTIME
               and (Voxel3D.glassMask or GlassMask.blank()) or nil
  if mask then
    pcall(sh.send, sh, "glassMask", mask)
    local ok, mw, mh = pcall(mask.getDimensions, mask)
    pcall(sh.send, sh, "glassSize", { ok and mw or 1, ok and mh or 1 })
  end
  pcall(sh.send, sh, "glassNight", Voxel3D.glassNight or 0)
  pcall(sh.send, sh, "glassPhase", Voxel3D.glassPhase or 0)
  pcall(sh.send, sh, "glassGlint", Voxel3D.glassGlint or 0)
  -- on until a sprite pass says otherwise, reset per frame like `ghost`
  pcall(sh.send, sh, "glassOn", 1)
  end -- desktop-only sun/weather/glass uniform batch
  -- No cut unless VoxelScene explicitly opens a FULL indoor shell below.
  pcall(sh.send, sh, "cutaway", { 0, 0, 0, 0 })
  -- the curved world bends about the camera's focus, so the horizon keeps
  -- a fixed distance ahead of the player rather than sitting on the map.
  -- A placed camera may decline it outright (Voxel3D.camera.curve = 0).
  local placed = Voxel3D.camera
  Voxel3D.curveK = (placed and placed.curve) or WorldCurve.k(vh)
  Voxel3D.curveX, Voxel3D.curveZ = cx, cy
  pcall(sh.send, sh, "curve", { cx, cy, Voxel3D.curveK })
  -- clip w at the focus point, the reference depth project() reports scale
  -- against (so scale == 1 for anything standing at the view centre)
  local m = Voxel3D.vp
  Voxel3D.focusW = m[13] * cx + m[14] * 0 + m[15] * cy + m[16]
  mobileDiagnostic("checkpoint", "scene-uniform-batch-ready", {
    caller="Voxel3D.beginScene", context="world", slot=name,
    variant=shaderVariants[grid],
  })
  activeShader = sh
  active = true
  firstDrawPending = true
  mobileDiagnostic("capability", "D08", "scene-framebuffer-ready", true,
    "color-and-depth-target-active", {
      caller="Voxel3D.beginScene", slot=name,
      depth=held.depth and "readable" or "internal",
    })
  return true
end

-- Depth handling for the character pass. Gen 1 draws sprites over the
-- background unconditionally, so characters render with the depth test
-- forced to pass (still writing depth: the grass mesh drawn after them
-- tests against it to overdraw feet). "test" restores normal occlusion.
function Voxel3D.depth(mode)
  if not active then return end
  pcall(love.graphics.setDepthMode, mode == "always" and "always" or "lequal",
        true)
end

-- Paint a screen-filling image behind every depth-tested part of the active
-- scene.  The colour target stays paired with its existing depth buffer, but
-- the picture neither tests nor writes depth; terrain, platforms and cards
-- therefore remain real geometry in front of it.  This is deliberately a
-- narrow scene primitive rather than an overlay: overlays run after the 3D
-- pass and would cover the Pokemon as well as the empty backdrop.
function Voxel3D.backdrop(image, tint)
  if not (active and activeShader and image and canvasW > 0 and canvasH > 0)
  then
    return false
  end
  local okSize, iw, ih = pcall(image.getDimensions, image)
  if not (okSize and type(iw) == "number" and type(ih) == "number"
          and iw > 0 and ih > 0) then
    return false
  end
  local c = type(tint) == "table" and tint or { 1, 1, 1 }
  local ok = pcall(function()
    love.graphics.setShader()
    love.graphics.setDepthMode("always", false)
    love.graphics.setColor(c[1] or 1, c[2] or 1, c[3] or 1, 1)
    local dx, dy, dr, dsx, dsy = CanvasPresentation.imageDraw(
      canvasW, canvasH, iw, ih)
    love.graphics.draw(image, dx, dy, dr, dsx, dsy)
  end)
  -- Optional backdrop failure must not leak temporary graphics state into the
  -- established ARENA stage which continues drawing after this call.
  pcall(love.graphics.setColor, 1, 1, 1, 1)
  pcall(love.graphics.setDepthMode, "lequal", true)
  pcall(love.graphics.setShader, activeShader)
  return ok
end

-- Multiply the world clock into authored window glass without grading the
-- room around it.  Regions are authored in the backdrop's source pixels and
-- scaled to the active battle canvas.  Rectangles, porthole ellipses and
-- simple convex panes cover the reviewed interiors without a mask texture.
function Voxel3D.backdropWindows(scene, regions, sourceW, sourceH)
  local gfx = love.graphics
  local tint = type(scene) == "table" and (scene.tint or scene) or nil
  if not (active and activeShader and type(tint) == "table"
          and type(regions) == "table" and #regions > 0
          and type(sourceW) == "number" and sourceW > 0
          and type(sourceH) == "number" and sourceH > 0
          and canvasW > 0 and canvasH > 0
          and gfx and gfx.setBlendMode and gfx.setColor
          and gfx.rectangle and gfx.ellipse and gfx.polygon) then
    return false
  end
  local r, g, b = tint[1], tint[2], tint[3]
  if not (type(r) == "number" and type(g) == "number"
          and type(b) == "number") then return false end
  local sky = type(scene) == "table" and scene.sky or nil
  local skyAlpha = type(scene) == "table" and scene.alpha or 0
  local stars = type(scene) == "table" and scene.stars or 0
  local moon = type(scene) == "table" and scene.moon or 0
  if not (type(skyAlpha) == "number" and type(stars) == "number"
          and type(moon) == "number") then return false end

  -- Use the exact same aspect-preserving COVER transform as the authored
  -- backdrop.  Window tint/stars are source-space annotations; stretching
  -- or mapping them with a second ratio would make them drift off their panes
  -- after a phone rotates.
  local ox, oy, coverScale = CanvasPresentation.cover(
    canvasW, canvasH, sourceW, sourceH)
  local sx, sy = coverScale, coverScale
  local blend, alphaMode = "alpha", "alphamultiply"
  if gfx.getBlendMode then
    local ok, gotBlend, gotAlpha = pcall(gfx.getBlendMode)
    if ok then blend, alphaMode = gotBlend or blend, gotAlpha or alphaMode end
  end
  local cr, cg, cb, ca = 1, 1, 1, 1
  if gfx.getColor then
    local ok, a, d, c, e = pcall(gfx.getColor)
    if ok then cr, cg, cb, ca = a or 1, d or 1, c or 1, e or 1 end
  end

  local ok = pcall(function()
    gfx.setShader()
    gfx.setDepthMode("always", false)
    gfx.setBlendMode("multiply", "premultiplied")
    local function pointIn(region, x, y)
      if region.shape == "rect" then
        return x >= region.x and x <= region.x + region.w
               and y >= region.y and y <= region.y + region.h
      elseif region.shape == "ellipse" then
        local rx, ry = region.w * .5, region.h * .5
        local dx = (x - region.x - rx) / rx
        local dy = (y - region.y - ry) / ry
        return dx * dx + dy * dy <= 1
      end
      local inside, j = false, #region.points - 1
      for i = 1, #region.points, 2 do
        local xi, yi = region.points[i], region.points[i + 1]
        local xj, yj = region.points[j], region.points[j + 1]
        if ((yi > y) ~= (yj > y))
            and x < (xj - xi) * (y - yi) / (yj - yi) + xi then
          inside = not inside
        end
        j = i
      end
      return inside
    end
    local function regionShape(region)
      if region.shape == "rect" then
        local rh = region.h * sy
        gfx.rectangle("fill", ox + region.x * sx,
                      CanvasPresentation.rectY(oy + region.y * sy,
                                               rh, canvasH),
                      region.w * sx, rh)
      elseif region.shape == "ellipse" then
        gfx.ellipse("fill", ox + (region.x + region.w * .5) * sx,
                    CanvasPresentation.pointY(
                      oy + (region.y + region.h * .5) * sy, canvasH),
                    region.w * sx * .5, region.h * sy * .5, 48)
      else
        local points = {}
        for i=1,#region.points,2 do
          points[#points + 1] = ox + region.points[i] * sx
          points[#points + 1] = CanvasPresentation.pointY(
            oy + region.points[i + 1] * sy, canvasH)
        end
        gfx.polygon("fill", points)
      end
    end
    for _, region in ipairs(regions) do
      local scale = type(region.tintScale) == "number"
                    and region.tintScale or 1
      gfx.setColor(1 + (r - 1) * scale,
                   1 + (g - 1) * scale,
                   1 + (b - 1) * scale, 1)
      regionShape(region)
    end

    -- Cover the painted daytime view progressively; at DAY alpha is zero.
    if sky and skyAlpha > 0 then
      gfx.setBlendMode("alpha")
      for _, region in ipairs(regions) do
        local scale = type(region.alphaScale) == "number"
                      and region.alphaScale or 1
        gfx.setColor(sky[1], sky[2], sky[3], skyAlpha * scale)
        regionShape(region)
      end
    end

    -- Deterministic irregular stars and one small moon, clipped by testing
    -- their centres against each authored pane. No mask texture or RNG state.
    if stars > 0 and gfx.circle then
      gfx.setBlendMode("alpha")
      for ri, region in ipairs(regions) do
        local starScale = type(region.starsScale) == "number"
                          and region.starsScale or 1
        local bx = region.x or 0
        local by = region.y or 0
        local bw = region.w or sourceW
        local bh = region.h or sourceH
        for i = 1, 13 do
          local x = bx + ((i * 47 + ri * 19) % 91) / 100 * bw
          local y = by + ((i * 29 + ri * 31) % 83) / 100 * bh
          if pointIn(region, x, y) then
            local size = ((i + ri) % 5 == 0) and 1.7 or .8
            gfx.setColor(1, .97, .78,
                         stars * starScale * (.46 + (i % 4) * .12))
            gfx.circle("fill", ox + x * sx,
                       CanvasPresentation.pointY(oy + y * sy, canvasH),
                       math.max(1, size * math.min(sx, sy)))
          end
        end
        if ri == 1 and region.moon ~= false and moon > 0 then
          local mx, my = bx + bw * .72, by + bh * .28
          if pointIn(region, mx, my) then
            gfx.setColor(.94, .95, .82, moon * .95)
            gfx.circle("fill", ox + mx * sx,
                       CanvasPresentation.pointY(oy + my * sy, canvasH),
                       math.max(2, math.min(bw * sx, bh * sy) * .075))
          end
        end
      end
    end
  end)

  pcall(gfx.setBlendMode, blend or "alpha", alphaMode)
  pcall(gfx.setColor, cr, cg, cb, ca)
  pcall(gfx.setDepthMode, "lequal", true)
  pcall(gfx.setShader, activeShader)
  return ok
end

-- ------------------------------------------------ the player's own ghost --

-- The silhouette's colour, and how solid it is.
--
-- ONE flat grey rather than a dimmed copy of the sprite, so the shape reads
-- at a glance instead of competing with whatever is showing through it --
-- and translucent rather than opaque, so it stays a hint of where the
-- player is rather than a hole punched in the building. The wall it is
-- seen through still shows, which is what keeps it reading as "behind
-- that" instead of "in front of it".
Voxel3D.GHOST_COLOR = { 0.26, 0.26, 0.28 }
Voxel3D.GHOST_ALPHA = 0.5

-- Draw a character AGAIN wherever the ordinary draw LOST the depth test.
--
-- Honest occlusion is the point of this mode -- walk behind the Mart and the
-- Mart is genuinely in front of you -- but a player who cannot see their own
-- character has lost track of where they are standing, which the flat game
-- never allowed. So the figure is drawn a second time with the test
-- INVERTED: "greater" passes exactly where "lequal" failed, and LOVE hands
-- the compare straight to glDepthFunc, so the two are true complements.
-- Every texel of the sprite is therefore drawn once and once only -- solid
-- where it is visible, translucent where it is not -- with no seam where
-- they meet and no double-blending anywhere.
--
-- Nothing is drawn at all when nothing is in the way, and no code here ever
-- asks whether the player is occluded: the depth buffer already knows, and
-- the test is the question.
--
-- Depth WRITES are off. This pass is behind the scenery by definition, and
-- writing would file the hidden figure's depth in front of the building
-- hiding it -- the grass pass at the end of the frame reads that buffer.
--
-- The caller redraws through the ordinary character path, so the ghost keeps
-- the same mesh, matrix and camera-ward PULL as the real draw. The pull
-- matching is what keeps the leaning-over-a-near-wall case out of here: pull
-- already won that fight for the solid draw, so this pass finds nothing left
-- to paint and a character merely standing close to a wall does not shimmer
-- a ghost over it.
function Voxel3D.beginGhost()
  if not active then return end
  pcall(love.graphics.setDepthMode, "greater", false)
  love.graphics.setColor(1, 1, 1, Voxel3D.GHOST_ALPHA)
  if activeShader then
    pcall(activeShader.send, activeShader, "ghostColor", Voxel3D.GHOST_COLOR)
    pcall(activeShader.send, activeShader, "ghost", 1)
  end
end

-- Flatten whatever is drawn next to one solid colour, or nil to stop.
--
-- The same `ghost` path the silhouette uses, WITHOUT beginGhost's inverted
-- depth test and half alpha -- this is for something drawn normally that
-- simply wants to come out one colour, which is what a hit flash on a sprite
-- is. beginScene resets the uniform every frame, so a pass that forgets to
-- clear it cannot leak into the next one.
-- `amount` is how far toward that colour, 0..1; omitted is all the way.
-- Anything short of 1 leaves the sprite's own shading showing through, which
-- is the difference between a hit flash and a white cut-out.
function Voxel3D.flatten(color, amount)
  if not (active and activeShader) then return end
  local sh = activeShader
  if color then
    pcall(sh.send, sh, "ghostColor", color)
    pcall(sh.send, sh, "ghost", math.max(0, math.min(1, amount or 1)))
  else
    pcall(sh.send, sh, "ghost", 0)
  end
end

-- ------------------------------------------------------- the water pass --
--
-- A reflective surface has to READ the frame it is being drawn into: the
-- colour of what is standing around it and the depth that says where. Both
-- are attachments of the target this pass is bound to, and a texture cannot
-- be sampled while it is one -- so for the length of the water draw the
-- frame is taken apart:
--
--   the COLOUR is copied to a mirror canvas, which is a texture like any
--   other and is what the reflection samples.
--
--   the DEPTH is simply detached. The water shader does the test itself
--   against the texture (see Water), which is the same comparison the
--   hardware would have made -- what it gives up is depth WRITES, and water
--   is flat, never overlaps itself, and has nothing drawn under it later.
--
-- `paint`, when given, is called with the MIRROR bound and the scene shader
-- set, to add things that must be REFLECTED without being composited yet.
--
-- The characters are the whole reason it exists. Gen 1 draws people over
-- the world and water is world, so the cast has to composite AFTER the
-- water -- but a reflection can only contain what was drawn BEFORE it, and
-- a lake with everyone standing beside it and nobody in it reads as glass.
-- Painting them into the mirror alone settles both: they are in the picture
-- the water reflects and not yet in the picture the water is drawn into.
--
-- They go down depth-TESTED and depth-WRITE-FREE. Tested, so a figure behind
-- a building is behind it in the reflection too; write-free because the very
-- next thing to read that buffer is the water's own depth test, and a cast
-- that had written to it would punch itself out of the water it is standing
-- beside.
--
-- Returns the two textures, or nil when there is nothing to hand over: no
-- readable depth canvas on this driver, or no pass open. A caller that gets
-- nil draws its water like ordinary terrain, which is what this mode always
-- did.
--
-- MUST be paired with endWater, which puts the frame back together.
function Voxel3D.beginWater(paint)
  if not (active and canvas and held and held.depth) then return nil end
  if not held.mirror then
    -- The reflection copy is attached to the readable scene depth target, so
    -- it must use the same one-texel-per-pixel DPI rule as that whole family.
    mobileDiagnostic("checkpoint", "water-mirror-create-start", {
      caller="PixelCanvas.new", context="water",
      width=held.w, height=held.h,
    })
    local ok, c = PixelCanvas.new(held.w, held.h)
    if not (ok and c) then return nil end
    pcall(c.setFilter, c, "nearest", "nearest")
    pcall(c.setWrap, c, "clamp", "clamp")
    held.mirror = c
    mobileDiagnostic("checkpoint", "water-mirror-ready", {
      caller="PixelCanvas.new", context="water",
      width=held.w, height=held.h,
    })
  end
  love.graphics.setShader()
  -- the frame's own depth rides along, so the paint below can test against
  -- it; the copy underneath switches the test off rather than detaching it
  mobileDiagnostic("checkpoint", "water-mirror-bind-start", {
    caller="love.graphics.setCanvas", context="water",
  })
  local ok = pcall(love.graphics.setCanvas,
                   { held.mirror, depthstencil = held.depth })
  if not ok then
    mobileDiagnostic("checkpoint", "water-mirror-bind-unavailable", {
      caller="love.graphics.setCanvas", context="water",
    })
    pcall(love.graphics.setCanvas, depthTarget())
    return nil
  end
  mobileDiagnostic("checkpoint", "water-mirror-bound", {
    caller="love.graphics.setCanvas", context="water",
  })
  love.graphics.setDepthMode("always", false)
  -- COLOUR only. The last two arguments are what keep the depth buffer the
  -- frame's rather than this canvas's: cleared here, the water's own depth
  -- test a few lines later would find nothing in front of anything and every
  -- lake would draw straight through the buildings standing in it.
  love.graphics.clear(0, 0, 0, 0, false, false)
  -- premultiplied over a cleared target is a straight copy: every channel
  -- lands exactly as it stood, including the alpha, so the mirror is the
  -- frame rather than the frame composited against something
  love.graphics.setBlendMode("alpha", "premultiplied")
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(canvas)
  love.graphics.setBlendMode("alpha")
  if paint and activeShader then
    love.graphics.setDepthMode("lequal", false)
    love.graphics.setShader(activeShader)
    pcall(paint)
    love.graphics.setShader()
  end
  love.graphics.setDepthMode()
  -- and back to the scene canvas WITHOUT its depth: that texture is about
  -- to be read
  mobileDiagnostic("checkpoint", "water-color-target-bind-start", {
    caller="love.graphics.setCanvas", context="water",
  })
  if not pcall(love.graphics.setCanvas, canvas) then
    pcall(love.graphics.setCanvas, depthTarget())
    return nil
  end
  mobileDiagnostic("checkpoint", "water-pass-ready", {
    caller="Voxel3D.beginWater", context="water",
  })
  return held.mirror, held.depth
end

-- Put the frame back: depth reattached, depth test and the scene shader as
-- the pass had them. Safe to call after a beginWater that returned nil.
function Voxel3D.endWater()
  if not active then return end
  mobileDiagnostic("checkpoint", "water-depth-target-restore-start", {
    caller="love.graphics.setCanvas", context="water",
  })
  pcall(love.graphics.setCanvas, depthTarget())
  pcall(love.graphics.setDepthMode, "lequal", true)
  love.graphics.setColor(1, 1, 1, 1)
  if activeShader then love.graphics.setShader(activeShader) end
end

-- Whether a reflective water pass can run in this frame at all -- there is
-- a depth texture to read. Callers use it to choose between the water
-- shader and an ordinary terrain draw before they start moving canvases.
function Voxel3D.depthReadable()
  return (active and held and held.depth) and true or false
end

-- Whether what is drawn next carries the voxel wireframe. false for the
-- length of a draw, true to put it back.
--
-- The wireframe reads a mesh's OWN model space and darkens its integer
-- planes (see VoxelGrid), which is only a wireframe because every mesh in
-- this mode is built ONE UNIT PER VOXEL: terrain in world pixels, a
-- character card in the sprite's own pixels. A mesh whose model space does
-- not mean that gets no wireframe out of the same shader -- it gets
-- whichever of its integer planes happen to fall inside it, which is a
-- stray line rather than a seam.
--
-- So this is not a style switch. It is how a mesh that is not on the voxel
-- grid says so, and the alternative -- rescaling such a mesh until its
-- units happen to be voxels -- would change what it IS to satisfy a
-- shading pass.
--
-- Sent rather than branched because the plain scene shader has no such
-- uniform, and the send simply does not take there -- which is right: with
-- no wireframe compiled in there is nothing to suppress.
function Voxel3D.seams(on)
  if MOBILE_RUNTIME then return end
  if not (active and activeShader) then return end
  pcall(activeShader.send, activeShader, "gridDark",
        on and VoxelGrid.DARK or 0)
end

-- ADDITIVE for the length of a draw, or nil to put the pass back the way
-- it was found.
--
-- Exactly one thing asks for this: the flame and gas primitives on a
-- STADIUM battle model (Charmander's tail, Weezing's cloud -- see
-- StadiumRig). Those are light, not surface: they are drawn over a body
-- that is already in the depth buffer and they must ADD to it rather than
-- replace it, or the flame comes out as an opaque orange sticker.
--
-- Depth WRITES go off with the blend, and for the usual reason -- a
-- translucent thing that wrote depth would punch whatever comes after it
-- out of the frame. The test stays on, so a flame behind a tree is still
-- behind the tree.
function Voxel3D.blend(mode)
  if not active then return end
  if mode == "add" then
    pcall(love.graphics.setBlendMode, "add", "alphamultiply")
    pcall(love.graphics.setDepthMode, "lequal", false)
  else
    pcall(love.graphics.setBlendMode, "alpha", "alphamultiply")
    pcall(love.graphics.setDepthMode, "lequal", true)
  end
end

-- Whether what is drawn next may consult the glass mask. false for the
-- length of a sprite-sheet pass, true to put it back.
--
-- Same shape as seams(), for the same reason: the mask means "this ATLAS
-- texel is window glass", so it is only an answer for meshes textured from
-- the tileset atlas. A sprite sheet's coordinates land wherever they land
-- on it, and at night that painted lamplight stripes down whoever was
-- standing in the wrong part of their own sheet.
function Voxel3D.glass(on)
  if MOBILE_RUNTIME then return end
  if not (active and activeShader) then return end
  pcall(activeShader.send, activeShader, "glassOn", on and 1 or 0)
end

function Voxel3D.endGhost()
  if not active then return end
  pcall(love.graphics.setDepthMode, "lequal", true)
  love.graphics.setColor(1, 1, 1, 1)
  -- back to ordinary shading before anything else draws; leaving it set
  -- would flatten the grass pass that follows into one grey sheet
  if activeShader then
    pcall(activeShader.send, activeShader, "ghost", 0)
  end
end

-- -------------------------------------------------------------- shadows --

-- The sun. One direction, shared by everything that needs to know where
-- the light comes from: the shadow map, the flat fallback below, and the
-- baked contact shading in ChunkMesher. Both shears are negative, which
-- hangs it in the SOUTHEAST and throws every shadow northwest -- up and to
-- the left on screen.
Voxel3D.SHADOW_KX = ShadowMap.KX   -- west drift per pixel of height
Voxel3D.SHADOW_KZ = ShadowMap.KZ   -- north drift per pixel of height
Voxel3D.SHADOW_EPS = 0.25     -- float above the ground to dodge z-fighting
Voxel3D.SHADOW_ALPHA = 0.40   -- how far into black a shadowed surface goes

-- Whether real shadows are running this frame. False headless and on any
-- driver the sun pass could not start on, which is when VoxelScene falls
-- back to the flat decals below.
function Voxel3D.shadowsActive()
  return Shadows.enabled() and ShadowMap.active()
end

-- Camera-facing presentation cards are shadow CASTERS, not useful shadow
-- receivers. Sampling the card's own packed depth makes precision differences
-- dim the artwork itself instead of putting that darkness on the floor. This
-- narrow per-draw switch leaves baked face light, day tint, weather and every
-- world receiver intact; callers must restore it immediately after the card.
function Voxel3D.shadowReception(on)
  if MOBILE_RUNTIME then return false end
  if not (active and activeShader) then return false end
  return pcall(activeShader.send, activeShader, "sunReceive",
               on == false and 0 or 1)
end

-- The upright card a character presents to the sun: its 16x16 sprite quad
-- (corners (0,0,0)..(16,16,0), feet at y = 0) standing on the middle of
-- the cell whose top-left is world (px, py), feet at height `y`.
--
-- This is the caster the shadow pass draws -- deliberately NOT the leaning
-- slab the camera sees. The slab tips back by the camera's pitch to read
-- face-on, which is a trick played on the viewer; letting the sun see it
-- too would shrink every shadow to nothing as the camera flattened toward
-- top-down. The sun sees the figure standing up, at every tilt.
--
-- The z-flatten matters when this is used the other way round, as the
-- lookup transform a lit slab reads its own shadowing with (Voxel3D.draw's
-- `sunModel`): it collapses the slab's side relief onto the card plane, so
-- every vertex asks about the exact surface the sun recorded rather than
-- one a few pixels behind it, and a figure cannot fringe itself. On the
-- caster itself it is a no-op -- that quad is already flat.
function Voxel3D.casterMatrix(px, py, y, mirror)
  local m = Mat4.translate(px + 8, y, py + 8)
  if mirror then m = Mat4.mul(m, Mat4.scale(-1, 1, 1)) end
  return Mat4.mul(Mat4.mul(m, Mat4.translate(-8, 0, 0)),
                  Mat4.scale(1, 1, 0))
end

-- FALLBACK ONLY (no shadow map: headless, or a driver that cannot make the
-- canvas). Character drop shadows as decals -- the sprite frame squashed
-- flat onto its ground plane and drawn translucent black. It can only ever
-- paint the floor, which is the whole reason ShadowMap exists.
--
-- Flattening is measured from the ground plane, so a hop slides the whole
-- shadow along the sun line while it stays glued to the ground -- the
-- classic jump-shadow tell.
function Voxel3D.shadowMatrix(px, py, gh, lift, mirror)
  local card = Voxel3D.casterMatrix(px, py, gh + (lift or 0), mirror)
  -- flatten about the ground plane: y' = 0, x/z shear by height above it
  local squash = { 1, Voxel3D.SHADOW_KX, 0, 0,
                   0, 0,                 0, 0,
                   0, Voxel3D.SHADOW_KZ, 1, 0,
                   0, 0,                 0, 1 }
  local m = Mat4.mul(squash, Mat4.mul(Mat4.translate(0, -gh, 0), card))
  return Mat4.mul(Mat4.translate(0, gh + Voxel3D.SHADOW_EPS, 0), m)
end

-- The decal pass draws between terrain and characters: depth-tested so a
-- building still hides a shadow behind it, but NOT depth-writing -- the
-- grass tufts drawn at the end of the frame must keep beating the ground
-- plane, and one quad per entity has no self-overlap to guard against.
function Voxel3D.beginShadows()
  if not active then return end
  pcall(love.graphics.setDepthMode, "lequal", false)
  love.graphics.setColor(0, 0, 0, Voxel3D.SHADOW_ALPHA)
end

function Voxel3D.endShadows()
  if not active then return end
  pcall(love.graphics.setDepthMode, "lequal", true)
  love.graphics.setColor(1, 1, 1, 1)
end

-- Draw one mesh with `model` (a Mat4) applied. Texture may be nil to keep
-- whatever the mesh already carries. `pull` moves every vertex toward the
-- eye along its own ray (see the shader) -- the artifact-free depth bias
-- the character and grass passes ride in front of the terrain.
--
-- `sunModel` is where the SHADOW PASS put this same geometry, and defaults
-- to `model` because for everything but a character the two are one matrix.
-- A character is drawn leaning and cast upright, so it must hand over the
-- upright transform or it reads its own shadow as falling on itself.
function Voxel3D.draw(mesh, texture, model, pull, sunModel)
  if not (active and mesh) then return end
  -- the variant beginScene actually bound, not whichever one is default:
  -- sending a uniform to the other shader would go nowhere
  local sh = activeShader
  if not sh then return end
  local function performDraw()
    -- LOVE defaults matrix uniforms to column-major; Mat4 is row-major
    pcall(sh.send, sh, "model", "row", model or IDENTITY)
    if not MOBILE_RUNTIME then
      pcall(sh.send, sh, "sunModel", "row", sunModel or model or IDENTITY)
    end
    pcall(sh.send, sh, "pull", pull or 0)
    if mesh.__voxelMeshBundle then
      if mesh.base then
        if texture then mesh.base:setTexture(texture) end
        love.graphics.draw(mesh.base)
      end
      for _, group in ipairs(mesh.instances or {}) do
        if texture then group.mesh:setTexture(texture) end
        love.graphics.drawInstanced(group.mesh, group.count)
      end
    else
      if texture then mesh:setTexture(texture) end
      love.graphics.draw(mesh)
    end
  end

  if firstDrawPending then
    firstDrawPending = false
    mobileDiagnostic("checkpoint", "scene-first-mesh-draw-start", {
      caller="love.graphics.draw", context="world",
      variant=shaderVariants[false],
      bundle=mesh.__voxelMeshBundle and true or false,
    })
    local ok, err = pcall(performDraw)
    if not ok then
      mobileDiagnostic("fail", "D10", "scene-first-mesh-draw",
        tostring(err), {
          caller="love.graphics.draw", context="world",
          variant=shaderVariants[false],
        })
      return false
    end
    mobileDiagnostic("checkpoint", "scene-first-mesh-draw-ready", {
      caller="Voxel3D.draw", context="world",
      variant=shaderVariants[false],
    })
    return true
  end

  performDraw()
  return true
end

-- Gate native accumulation to terrain draws. Character cards, flowers,
-- horizon curtains and authored decals may also use upward-facing geometry;
-- leaving the uniform globally enabled would frost or flood those as well.
function Voxel3D.weatherGround(on)
  if MOBILE_RUNTIME then return false end
  if not (active and activeShader) then return false end
  local amount = on and (Voxel3D.weatherKind or 0) or 0
  local ok = pcall(activeShader.send, activeShader, "weatherGround", amount)
  return ok and amount > 0
end

function Voxel3D.weatherGrass(on)
  if MOBILE_RUNTIME then return false end
  if not (active and activeShader) then return false end
  local amount = on and ((Voxel3D.weatherKind == 2 and 1)
                         or (Voxel3D.weatherKind == 3 and 2) or 0) or 0
  local ok = pcall(activeShader.send, activeShader, "weatherGrass", amount)
  return ok and amount > 0
end

-- Enable/disable the synthetic-room half-space cut for subsequent draws.
-- Keeping this as draw state, rather than rebuilding a camera-specific mesh,
-- makes rotation immediate and preserves the one cached enclosure geometry.
function Voxel3D.setCutaway(nx, nz, offset)
  if not (active and activeShader) then return false end
  local valid = type(nx) == "number" and type(nz) == "number"
                and type(offset) == "number"
  local value = valid and { nx, nz, offset, 1 } or { 0, 0, 0, 0 }
  local ok = pcall(activeShader.send, activeShader, "cutaway", value)
  return ok and valid
end

-- Project a world point to canvas pixels: returns (x, y, scale), or nil
-- when the point is behind the camera. `scale` is how much bigger a thing
-- at that depth appears than one at the focus point, so a caller can size
-- with it -- or ignore it and draw unscaled, which is what tilt mode's
-- billboards do.
--
-- This is what lets the overworld's FX closures (the "!" bubble, the heal
-- machine, the Fly bird, the fishing rod) draw in voxel mode completely
-- unchanged: they stay ordinary 2D draws, anchored to wherever their ground
-- point lands under the same camera the 3D pass used.
function Voxel3D.project(wx, wy, wz)
  local m = Voxel3D.vp
  if not m then return nil end
  -- the same drop the vertex shader applies, or every FX anchored to a
  -- ground point floats off its own feet the moment that ground bends
  wy = wy - WorldCurve.drop(Voxel3D.curveK or 0, Voxel3D.curveX or 0,
                            Voxel3D.curveZ or 0, wx, wz)
  local cx = m[1] * wx + m[2] * wy + m[3] * wz + m[4]
  local cy = m[5] * wx + m[6] * wy + m[7] * wz + m[8]
  local cw = m[13] * wx + m[14] * wy + m[15] * wz + m[16]
  if cw <= 1e-6 then return nil end
  -- viewProjection already flipped clip-space Y into LOVE's Y-down canvas
  -- convention, so both axes map the same way here -- no second flip
  local x = (cx / cw * 0.5 + 0.5) * canvasW
  local y = (cy / cw * 0.5 + 0.5) * canvasH
  return x, y, (Voxel3D.focusW or cw) / cw
end

-- Re-bind the scene canvas for ordinary 2D drawing (no depth test), so
-- screen-space overlays can be composited into the same image the 3D pass
-- just filled. Pairs with endScene, which unbinds it.
function Voxel3D.beginOverlay()
  if not canvas then return false end
  love.graphics.setShader()
  love.graphics.setDepthMode()
  mobileDiagnostic("checkpoint", "gen1-overlay-canvas-bind-start", {
    caller="love.graphics.setCanvas", context="world-overlay",
  })
  local ok, err = pcall(love.graphics.setCanvas, canvas)
  if not ok then
    mobileDiagnostic("checkpoint", "gen1-overlay-canvas-bind-unavailable", {
      caller="love.graphics.setCanvas", context="world-overlay", error=err,
    })
    return false
  end
  mobileDiagnostic("checkpoint", "gen1-overlay-canvas-bound", {
    caller="love.graphics.setCanvas", context="world-overlay",
  })
  love.graphics.setColor(1, 1, 1, 1)
  return true
end

-- Close the overlay begun by beginOverlay.
function Voxel3D.endOverlay()
  mobileDiagnostic("checkpoint", "gen1-overlay-canvas-unbind-start", {
    caller="love.graphics.setCanvas", context="world-overlay",
  })
  love.graphics.setCanvas()
  mobileDiagnostic("checkpoint", "gen1-overlay-canvas-unbound", {
    caller="love.graphics.setCanvas", context="world-overlay",
  })
  active, activeShader, firstDrawPending = false, nil, false
end

-- End the pass and hand back the rendered canvas.
function Voxel3D.endScene()
  if not active then return nil end
  love.graphics.setShader()
  love.graphics.setDepthMode()
  love.graphics.setMeshCullMode("none")
  mobileDiagnostic("checkpoint", "gen1-scene-canvas-unbind-start", {
    caller="love.graphics.setCanvas", context="world",
  })
  love.graphics.setCanvas()
  mobileDiagnostic("checkpoint", "gen1-caller-target-restored", {
    caller="Voxel3D.endScene", target="physical-screen",
  })
  active, activeShader, firstDrawPending = false, nil, false
  return canvas
end

function Voxel3D.canvas()
  return canvas
end

-- The bound canvas's pixel size, for a pass that has to work in screen
-- coordinates (the water's reflection marches in them).
function Voxel3D.size()
  return canvasW, canvasH
end

-- Drop the GPU objects (window resize, hot reload).
function Voxel3D.invalidate()
  active, activeShader, firstDrawPending = false, nil, false
  for name, slotHeld in pairs(slots) do
    releaseSlot(slotHeld)
    slots[name] = nil
  end
  canvas, canvasW, canvasH = nil, 0, 0
  held = nil
  -- the VR sky's disc mesh belongs to this context like the canvases do
  if discMesh and discMesh.release then pcall(discMesh.release, discMesh) end
  discMesh = nil
  ShadowMap.invalidate()
  -- the sky is part of this pass and holds a shader of its own
  Sky.invalidate()
  -- and so does the water, for the same reason
  V.require("Water").invalidate()
  -- and the glass masks are textures of this context too
  GlassMask.invalidate()
end

return Voxel3D
