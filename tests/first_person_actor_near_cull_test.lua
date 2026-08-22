-- A first-person eye must not render the inside of a follower/NPC card in
-- the nearest cell, but ordinary actors remain visible at readable distance
-- and every non-1ST camera keeps the established cast unchanged.

local cache = {}
local cardDraws, meshCalls = 0, 0
local hidePlayer = true

local V = { mod = { id = "VOXEL_ASCENDANT" } }
function V.require(name)
  if cache[name] == nil then cache[name] = {} end
  return cache[name]
end

package.preload["src.render.PaletteFX"] = function()
  return {
    effectiveColors = function(c) return c end,
    usesGbcPack = function() return false end,
  }
end
package.preload["src.render.SpriteRenderer"] = function()
  return { STAND = { down = 0 }, WALK = { down = 0 } }
end
package.preload["src.world.Map"] = function() return {} end

cache.Mat4 = {
  translate = function() return {} end,
  mul = function() return {} end,
  rotateX = function() return {} end,
  rotateY = function() return {} end,
  scale = function() return {} end,
}

cache.VoxelState = {
  FP_LEVEL = 6,
  TP_LEVEL = 7,
  level = 6,
  angle = math.rad(75),
}
function cache.VoxelState.isFirstPerson(level)
  return (level or cache.VoxelState.level) == cache.VoxelState.FP_LEVEL
end

cache.Voxel3D = {
  eye = { 8, 13, 8 },
  focus = { 8, 13, 32 },
  glass = function() end,
  seams = function() end,
  casterMatrix = function() return {} end,
  draw = function(mesh)
    if mesh == "actor-card" then cardDraws = cardDraws + 1 end
  end,
}
cache.ShadowMap = { snug = function(model) return model end }
cache.Shadows = {}
cache.ChunkMesher = { figures = function() return {} end }
cache.SpriteBillboards = {
  mesh = function()
    meshCalls = meshCalls + 1
    return "actor-card"
  end,
}
cache.TileShape = {}
cache.TerrainAtlas = { forSprite = function() return nil end }
cache.Sky = {}
cache.Water = {}
cache.VoxelGrid = {}
cache.DayNight = {}
cache.FirstPerson = {
  hidePlayer = function() return hidePlayer end,
  cardBlend = function()
    return cache.VoxelState.isFirstPerson() and 1 or 0
  end,
  apparentFacing = function(facing) return facing end,
  playerFacing = function(facing) return facing end,
  cardYaw = function() return 0 end,
}
cache.HorizonWall = {}
cache.Weather = {}

local Scene = assert(loadfile("lib/VoxelScene.lua"))(V)
local engulf = assert(Scene._actorEngulfsEye,
                      "camera-space actor predicate is not exposed")
local drawCast = assert(Scene._drawCast, "focused cast seam is not exposed")

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected "
          .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function actor(px, py, gh, lift, isPlayer)
  return {
    sprite = {
      def = { image = "actor.png", frames = 1, trueColor = true },
      resolveImage = function() return "actor-texture" end,
    },
    px = px,
    py = py,
    gh = gh or 0,
    lift = lift,
    facing = "down",
    phase = 0,
    flip = false,
    isPlayer = isPlayer,
  }
end

local function look(yaw, pitch)
  local cp = math.cos(pitch)
  cache.Voxel3D.focus = {
    cache.Voxel3D.eye[1] + math.sin(yaw) * cp * 24,
    cache.Voxel3D.eye[2] - math.sin(pitch) * 24,
    cache.Voxel3D.eye[3] + math.cos(yaw) * cp * 24,
  }
end

look(0, math.rad(10))
local player = actor(0, 0, 0, nil, true)
local sameCellFollower = actor(0, 0)
local nearFollower = actor(0, 16)
local justReadableNPC = actor(0, 16.001)
local readableNPC = actor(0, 32)

-- The exact 16px threshold comes from one billboard/card span, not a tuned
-- radius. The fallback same-cell spawn is inside the card as well.
eq(engulf(sameCellFollower), true,
   "same-cell follower did not engulf the first-person eye")
eq(engulf(nearFollower), true,
   "one-card/one-cell follower was not classified as near")
eq(engulf(justReadableNPC), false,
   "actor beyond the exact 16px card span was hidden")
eq(engulf(readableNPC), false,
   "two-cell readable NPC was hidden")

-- Range alone is insufficient: the optical-centre ray has to pierce the
-- finite, eye-facing card rectangle.
eq(engulf(actor(0, -16)), false, "actor behind the eye was hidden")
eq(engulf(actor(16, 0)), false, "actor beside the eye was hidden")
eq(engulf(actor(16, 16)), false, "diagonal actor was hidden")
eq(engulf(actor(12, 8)), false,
   "off-axis near actor whose card misses the centre ray was hidden")
eq(engulf(actor(0, 16, 32)), false,
   "near actor above the optical-centre ray was hidden")
eq(engulf(actor(0, 0, 16)), false,
   "same-cell actor without vertical eye overlap was hidden")

look(0, math.rad(-50))
eq(engulf(nearFollower), false,
   "near card was hidden while the eye looked above it")
look(0, math.rad(70))
eq(engulf(nearFollower), false,
   "near card was hidden while the eye looked below it")
look(0, math.rad(10))

-- The pure camera test does not touch mesh/texture caches or allocate GPU
-- resources. Mesh work starts only when the established draw path is called.
eq(meshCalls, 0, "geometry predicate touched the billboard mesh cache")

local map = { id = "ACTOR_CULL_TEST" }
local state = { map = map, neighbors = {} }
local posed = { player, nearFollower, readableNPC }
local function drawsAt(level, hidesPlayer)
  cache.VoxelState.level = level
  hidePlayer = hidesPlayer
  cardDraws, meshCalls = 0, 0
  drawCast(state, posed, function() return nil end)
  return cardDraws, meshCalls
end

local draws, meshes = drawsAt(6, true)
eq(draws, 1, "1ST did not retain only the readable-distance NPC")
eq(meshes, 1, "1ST built a card for a culled near actor")

draws, meshes = drawsAt(7, false)
eq(draws, 3, "ordinary 3RD cast changed")
eq(meshes, 3, "ordinary 3RD mesh count changed")

draws, meshes = drawsAt(5, false)
eq(draws, 3, "orbit cast changed")
eq(meshes, 3, "orbit mesh count changed")

-- A wall-collapsed 3RD camera keeps its established player-card suppression,
-- but the new non-player cull remains 1ST-only.
draws, meshes = drawsAt(7, true)
eq(draws, 2, "collapsed 3RD hid the nearby follower")
eq(meshes, 2, "collapsed 3RD changed non-player mesh work")

print("first-person actor near cull: ok; threshold=16px; "
      .. "3RD/orbit draw+mesh counts unchanged; no new GPU resources")
