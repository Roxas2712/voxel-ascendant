-- A single rendered map is sampled many times: terrain, grass, flowers,
-- figures, water/reflection and (when stale) the shadow pass. Its effective
-- palette and atlas should resolve once per render and the sprite palette
-- should share that same effective-colour answer.

local cache = {}
local paletteCalls, effectiveCalls, atlasCalls = 0, 0, 0
local frame = {}

local V = { mod = { id = "VOXEL_ASCENDANT" } }
function V.require(name)
  if cache[name] == nil then cache[name] = {} end
  return cache[name]
end

package.preload["src.render.PaletteFX"] = function()
  return {
    effectiveColors = function(colors)
      effectiveCalls = effectiveCalls + 1
      return colors and { colors[1], colors[2], colors[3], colors[4] } or nil
    end,
    usesGbcPack = function() return false end,
  }
end
package.preload["src.world.Map"] = function() return {} end

cache.Mat4 = {
  translate = function() return {} end,
  mul = function() return {} end,
  rotateX = function() return {} end,
  rotateY = function() return {} end,
  scale = function() return {} end,
}
cache.VoxelState = { ready = false, angle = math.rad(35) }
cache.Voxel3D = {
  draw = function() end,
  glass = function() end,
  seams = function() end,
  beginScene = function() return true end,
  endScene = function() return frame end,
  shadowsActive = function() return false end,
  cell = 1,
}
cache.ShadowMap = { snug = function(model) return model end }
cache.Shadows = { enabled = function() return false end }
cache.SpriteBillboards = {}
cache.TileShape = {}
cache.TerrainAtlas = {
  setLive = function() end,
  -- Deliberately return nil: a separate ready bit must still suppress the
  -- repeated atlas calls in compatibility/failure paths.
  forMap = function()
    atlasCalls = atlasCalls + 1
    return nil
  end,
}
cache.ChunkMesher = {
  setLive = function() end,
  request = function() end,
  pair = function() return "terrain", nil end,
  figures = function() return {} end,
  grass = function() return nil end,
  flowers = function() return nil end,
}
cache.Sky = { enabled = function() return false end }
cache.Water = {}
cache.VoxelGrid = {}
cache.DayNight = {
  isCanopy = function() return false end,
  applyRig = function() end,
  tint = function() return { 1, 1, 1 } end,
  windowLight = function() return 0 end,
}
cache.FirstPerson = {
  frame = function() return nil end,
  shadowCenter = function(x, y) return x, y end,
  hidePlayer = function() return false end,
  cardBlend = function() return 0 end,
}
cache.HorizonWall = {
  preferBody = function() return true end,
  enabled = function() return true end,
  hasSky = function() return false end,
  meshes = function() return {}, true end,
}
cache.PanoramaBackdrop = {
  setEnabled = function() end,
  prepare = function() return false end,
}
cache.Weather = {
  mode = function() return "off" end,
  apply = function(rendered) return rendered end,
}
cache.GlassMask = { texture = function() return nil end }
cache.WallDecals = { drawState = function() end }

local Scene = assert(loadfile("lib/VoxelScene.lua"))(V)
local map = {
  id = "CACHE_TEST",
  tileset = {},
  def = { width = 1, height = 1 },
}
local state = {
  map = map,
  camera = { x = 0, y = 0 },
  neighbors = {}, ghosts = {}, entities = {},
}

local raw = { "light", "mid1", "mid2", "dark" }
local function paletteFor(askedMap)
  if askedMap ~= map then error("unexpected palette map", 2) end
  paletteCalls = paletteCalls + 1
  return raw
end

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected "
          .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

eq(Scene.render(state, 160, 144, 160, 144, paletteFor), frame,
   "minimal scene did not render")
eq(paletteCalls, 1,
   "one map re-ran its palette/world hooks within a render")
eq(effectiveCalls, 1,
   "sprite and terrain paths did not share effective colors")
eq(atlasCalls, 1,
   "nil atlas answer was not retained for the render")

-- The cache belongs to a frame, not to a map lifetime: a later render must
-- observe display-mode/time-of-day changes rather than carrying stale colors.
eq(Scene.render(state, 160, 144, 160, 144, paletteFor), frame,
   "second minimal scene did not render")
eq(paletteCalls, 2, "palette cache leaked across renders")
eq(effectiveCalls, 2, "effective-color cache leaked across renders")
eq(atlasCalls, 2, "atlas cache leaked across renders")

print("voxel scene per-render palette/atlas cache: ok")
