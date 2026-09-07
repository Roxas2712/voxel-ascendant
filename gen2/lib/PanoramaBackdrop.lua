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
-- Same outdoor bitmap palette as the Gen2 A21 arena backdrop renderer.
-- DayNight's existing shader uniform supplies the clock exactly once.
local WEATHER_GRADE = {
  snow={1.16,1.20,1.28,1}, rain={.72,.78,.88,1},
  storm={.72,.78,.88,1}, fog={.90,.94,.94,1},
}

local PanoramaBackdrop = {}

PanoramaBackdrop.RADIUS = 900
PanoramaBackdrop.SEGMENTS = 64
PanoramaBackdrop.BOTTOM = -120
PanoramaBackdrop.TOP = 300
PanoramaBackdrop.WIDTH = 1024
PanoramaBackdrop.HEIGHT = 192
PanoramaBackdrop.ASSET = "assets/scenery/kanto_panorama.compact.png"

local texture, mesh, pendingData
local attempted = false
local enabled = true
local lastFailure, lastRetryable = nil, false

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
  if not enabled then return false, "disabled", false end
  if texture and mesh then return true end
  if attempted then
    return false, lastFailure or "prepare-already-attempted",
           lastRetryable == true
  end
  attempted = true
  lastFailure, lastRetryable = nil, false

  -- Decode once, then retain the CPU data while a cold mobile graphics
  -- context retries only the failing upload.  This avoids both the old
  -- manual-trigger dependency and repeated PNG decoding.
  if not texture and not pendingData then
    local path = V.path .. "/" .. PanoramaBackdrop.ASSET
    local okData, data = pcall(Assets.imageData, path)
    if not okData or not data or type(data.getDimensions) ~= "function" then
      if okData then release(data) end
      lastFailure, lastRetryable = "asset-image-data", false
      return false, lastFailure, lastRetryable
    end
    local okSize, w, h = pcall(data.getDimensions, data)
    if not okSize or w ~= PanoramaBackdrop.WIDTH
        or h ~= PanoramaBackdrop.HEIGHT then
      release(data)
      lastFailure, lastRetryable = "asset-dimensions", false
      return false, lastFailure, lastRetryable
    end
    pendingData = data
  end

  if not texture then
    local okImage, image = pcall(love.graphics.newImage, pendingData)
    if not okImage or not image then
      lastFailure, lastRetryable = "image-upload", true
      return false, lastFailure, lastRetryable
    end
    texture = image
    release(pendingData)
    pendingData = nil
    pcall(texture.setFilter, texture, "nearest", "nearest")
    pcall(texture.setWrap, texture, "clamp", "clamp")
  end

  if not mesh then
    local okMesh, built = pcall(buildMesh)
    if not okMesh or not built then
      lastFailure, lastRetryable = "mesh-build", true
      return false, lastFailure, lastRetryable
    end
    mesh = built
  end
  lastFailure, lastRetryable = nil, false
  return true
end

-- Retry only the failed GPU stage.  Successfully decoded data or an uploaded
-- texture remains owned by this resource; a map retry never starts from zero.
function PanoramaBackdrop.rearm()
  if texture and mesh then return true end
  if lastRetryable ~= true then return false end
  attempted = false
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
    release(pendingData)
    mesh, texture, pendingData = nil, nil, nil
    attempted = false
    lastFailure, lastRetryable = nil, false
  end
  enabled = value
  return enabled
end

function PanoramaBackdrop.drawAt(x, baseY, z, context)
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
  -- A distant bitmap is not the terrain atlas: sampling the terrain's lamp
  -- mask here relit arbitrary panorama pixels at night, bypassing dayTint.
  local glass = type(Voxel3D.glass) == "function" and Voxel3D.glass or nil
  if glass then pcall(glass, false) end
  local grade = type(context) == "table" and context.outdoor == true
    and context.surfaces ~= false and WEATHER_GRADE[context.weather] or nil
  local setColor = love.graphics.setColor
  if grade and type(setColor) == "function" then
    setColor(grade[1], grade[2], grade[3], grade[4])
  end
  local okDraw = pcall(Voxel3D.draw, mesh, texture,
                       Mat4.translate(x or 0, baseY or 0, z or 0))
  -- Restore the ordinary world contract even if a driver rejected the draw.
  if grade and type(setColor) == "function" then pcall(setColor, 1, 1, 1, 1) end
  if glass then pcall(glass, true) end
  pcall(setDepthMode, "lequal", true)
  return okDraw
end

function PanoramaBackdrop.invalidate()
  release(mesh)
  release(texture)
  release(pendingData)
  mesh, texture, pendingData = nil, nil, nil
  attempted = false
  lastFailure, lastRetryable = nil, false
end

return PanoramaBackdrop
