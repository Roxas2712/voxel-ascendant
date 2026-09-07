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
local okSnowGrade, SnowGrade = pcall(V.require, "PanoramaSnowGrade")
if not okSnowGrade or type(SnowGrade) ~= "table"
    or type(SnowGrade.color) ~= "function" then
  SnowGrade = nil
end

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

  -- Decode and validate once.  A cold mobile graphics context can reject the
  -- following upload for a handful of frames; retaining this CPU object lets
  -- the map-owned gate retry the actual failing GPU seam without decoding the
  -- same panorama on every update.
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
      -- Keep the successfully uploaded texture.  Only the failed mesh stage
      -- is retried on the next bounded lifecycle update.
      lastFailure, lastRetryable = "mesh-build", true
      return false, lastFailure, lastRetryable
    end
    mesh = built
  end
  lastFailure, lastRetryable = nil, false
  return true
end

-- Clear only the one-attempt guard after a retryable cold GPU answer.  Unlike
-- invalidate(), this deliberately preserves decoded data or a completed
-- texture so automatic mobile recovery stays cheap and deterministic.
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

local function safeColor(value)
  value = tonumber(value)
  if value == nil or value ~= value then return 1 end
  return math.max(0, math.min(1, value))
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
  -- Resolve all fallible pure inputs before changing graphics state.
  local grade = nil
  if SnowGrade then
    local okGrade, value = pcall(SnowGrade.color,
      type(context) == "table" and context.weather or nil,
      type(context) == "table" and context.amount or nil,
      type(context) == "table" and context.outdoor or nil,
      type(context) == "table" and context.surfaces or nil)
    if okGrade and type(value) == "table" then grade = value end
  end
  local okModel, model = pcall(Mat4.translate, x or 0, baseY or 0, z or 0)
  if not okModel or model == nil then return false end
  local setDepthMode = love and love.graphics
                       and love.graphics.setDepthMode
  if type(setDepthMode) ~= "function" then return false end
  local okDepth = pcall(setDepthMode, "lequal", false)
  if not okDepth then
    pcall(setDepthMode, "lequal", true)
    return false
  end
  local setColor = love and love.graphics and love.graphics.setColor
  local colorScoped = type(grade) == "table" and type(setColor) == "function"
  local glass = type(Voxel3D.glass) == "function" and Voxel3D.glass or nil
  if glass then pcall(glass, false) end
  if colorScoped then
    pcall(setColor,
      safeColor(grade[1]), safeColor(grade[2]), safeColor(grade[3]),
      safeColor(grade[4]))
  end
  local okDraw, drawn = pcall(Voxel3D.draw, mesh, texture, model)
  -- Restore every ordinary world state even if a driver rejected the draw.
  if colorScoped then pcall(setColor, 1, 1, 1, 1) end
  if glass then pcall(glass, true) end
  pcall(setDepthMode, "lequal", true)
  -- Voxel3D deliberately turns the first real GPU-draw failure of a scene
  -- into `false` so callers can abort transactionally.  Preserve that signal
  -- instead of treating pcall success as a successful panorama draw.
  return okDraw and drawn ~= false
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
