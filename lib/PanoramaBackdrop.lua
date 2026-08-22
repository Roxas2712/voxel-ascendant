-- A distant, player-centred Kanto horizon behind the real streamed maps.
--
-- This is deliberately only the FAR layer. HorizonWall keeps ownership of
-- the first edge cells, water, foliage and authored transition geometry; the
-- panorama replaces only its opaque outer curtain. That preserves the real
-- map and the intentional coastal gaps while avoiding an empty void at the
-- wide first-person and 3X battle cameras.

local V = ...

local Mat4 = V.require("Mat4")
local Voxel3D = V.require("Voxel3D")
local Assets = require("src.render.Assets")

local PanoramaBackdrop = {}

PanoramaBackdrop.RADIUS = 900
PanoramaBackdrop.SEGMENTS = 64
PanoramaBackdrop.BOTTOM = -120
PanoramaBackdrop.TOP = 300
PanoramaBackdrop.WIDTH = 1024
PanoramaBackdrop.HEIGHT = 192
PanoramaBackdrop.ASSET = "assets/scenery/kanto_panorama.compact.png"

local texture, mesh
local attempted = false
local enabled = true

local function release(value)
  if value and type(value.release) == "function" then pcall(value.release, value) end
end

local function buildMesh()
  local verts, indices = {}, {}
  for i = 0, PanoramaBackdrop.SEGMENTS - 1 do
    local u0 = i / PanoramaBackdrop.SEGMENTS
    local u1 = (i + 1) / PanoramaBackdrop.SEGMENTS
    local a0, a1 = u0 * math.pi * 2, u1 * math.pi * 2
    local x0 = math.cos(a0) * PanoramaBackdrop.RADIUS
    local z0 = math.sin(a0) * PanoramaBackdrop.RADIUS
    local x1 = math.cos(a1) * PanoramaBackdrop.RADIUS
    local z1 = math.sin(a1) * PanoramaBackdrop.RADIUS
    local q = #verts / 4
    -- Clockwise from inside the cylinder. Culling is currently disabled, but
    -- the winding remains correct if the renderer enables it later.
    verts[#verts + 1] = { x1, PanoramaBackdrop.TOP,    z1, u1, 0, 1 }
    verts[#verts + 1] = { x0, PanoramaBackdrop.TOP,    z0, u0, 0, 1 }
    verts[#verts + 1] = { x0, PanoramaBackdrop.BOTTOM, z0, u0, 1, 1 }
    verts[#verts + 1] = { x1, PanoramaBackdrop.BOTTOM, z1, u1, 1, 1 }
    Voxel3D.pushQuad(indices, q)
  end
  return Voxel3D.newMesh(verts, indices)
end

function PanoramaBackdrop.prepare()
  if not enabled then return false end
  if texture and mesh then return true end
  if attempted then return false end
  attempted = true
  local path = V.path .. "/" .. PanoramaBackdrop.ASSET
  local okData, data = pcall(Assets.imageData, path)
  if not okData or not data or type(data.getDimensions) ~= "function" then
    return false
  end
  local okSize, w, h = pcall(data.getDimensions, data)
  if not okSize or w ~= PanoramaBackdrop.WIDTH
      or h ~= PanoramaBackdrop.HEIGHT then
    release(data)
    return false
  end
  local okImage, image = pcall(love.graphics.newImage, data)
  release(data)
  if not okImage or not image then return false end
  pcall(image.setFilter, image, "nearest", "nearest")
  pcall(image.setWrap, image, "clamp", "clamp")
  local built = buildMesh()
  if not built then
    release(image)
    return false
  end
  texture, mesh = image, built
  return true
end

function PanoramaBackdrop.ready()
  return texture ~= nil and mesh ~= nil
end

-- SCENERY=OFF is a real resource switch, not merely a draw skip. Release the
-- retained GPU objects once on the transition; turning it back on remains
-- lazy and does not decode anything until an outdoor frame asks prepare().
function PanoramaBackdrop.setEnabled(value)
  value = value ~= false
  if enabled and not value then
    release(mesh)
    release(texture)
    mesh, texture = nil, nil
    attempted = false
  end
  enabled = value
  return enabled
end

function PanoramaBackdrop.drawAt(x, baseY, z)
  if not PanoramaBackdrop.ready() then return false end
  -- A panorama is background paint, not an occluder.  The streamed union can
  -- legitimately extend beyond this player-centred 900px cylinder (Route 1
  -- plus Pallet/Viridian is the clearest case).  Writing the cylinder into
  -- the depth buffer then made its bright mountain/cloud pixels reject those
  -- real distant houses.  Keep the normal depth test, but never write this
  -- decorative layer; all subsequently drawn map and horizon geometry can
  -- therefore win regardless of which side of radius 900 it occupies.
  local setDepthMode = love and love.graphics
                       and love.graphics.setDepthMode
  if type(setDepthMode) ~= "function" then return false end
  local okDepth = pcall(setDepthMode, "lequal", false)
  if not okDepth then return false end
  local okDraw = pcall(Voxel3D.draw, mesh, texture,
                       Mat4.translate(x or 0, baseY or 0, z or 0))
  -- Restore the ordinary world contract even if a driver rejected the draw.
  pcall(setDepthMode, "lequal", true)
  return okDraw
end

function PanoramaBackdrop.invalidate()
  release(mesh)
  release(texture)
  mesh, texture = nil, nil
  attempted = false
end

return PanoramaBackdrop
