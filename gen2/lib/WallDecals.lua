-- Depth-tested wall decals for the open Voxel3D scene.
--
-- The engine's flat wall-decal pass is replaced together with the flat world
-- whenever a drawWorld pipeline is active. This module consumes the same
-- map.def.wallDecals records and lets companion mods contribute additional
-- records through a small public registry. All caches are process-local RAM;
-- no filesystem, loader or save namespace is touched.

local V = ...

local Assets = require("src.render.Assets")
local Mat4 = V.require("Mat4")
local Voxel3D = V.require("Voxel3D")

local WallDecals = {
  API_VERSION = 1,
  providers = {},
}

local meshes = {}
local images = {}
local EPSILON = 0.04

local function release(value)
  if value and value.release then pcall(value.release, value) end
end

function WallDecals.invalidate()
  for _, mesh in pairs(meshes) do release(mesh) end
  meshes, images = {}, {}
end

if type(Assets.register) == "function" then
  Assets.register(WallDecals.invalidate)
end

local function faceShade(face)
  local shade = Voxel3D.FACE_SHADE or {}
  if face == "east" then return shade[1] or 1 end
  if face == "west" then return shade[2] or 1 end
  if face == "south" then return shade[5] or 1 end
  if face == "north" then return shade[6] or 1 end
  return 1
end

local function corners(face)
  local e = EPSILON
  if face == "north" then
    return { { 16, 0, -e }, { 0, 0, -e },
             { 0, 16, -e }, { 16, 16, -e } }
  elseif face == "east" then
    return { { 16 + e, 0, 16 }, { 16 + e, 0, 0 },
             { 16 + e, 16, 0 }, { 16 + e, 16, 16 } }
  elseif face == "west" then
    return { { -e, 0, 0 }, { -e, 0, 16 },
             { -e, 16, 16 }, { -e, 16, 0 } }
  end
  return { { 0, 0, 16 + e }, { 16, 0, 16 + e },
           { 16, 16, 16 + e }, { 0, 16, 16 + e } }
end

local function build(path, face)
  local okImage, image = pcall(Assets.image, path)
  if not (okImage and image) then return nil, nil end
  local c = corners(face)
  local s = faceShade(face)
  local okSize, iw, ih = pcall(image.getDimensions, image)
  iw, ih = tonumber(iw), tonumber(ih)
  local insetU = okSize and iw and iw > 0 and 0.02 / iw or 0
  local insetV = okSize and ih and ih > 0 and 0.02 / ih or 0
  local u0, u1 = insetU, 1 - insetU
  local v0, v1 = insetV, 1 - insetV
  local vertices = {
    { c[1][1], c[1][2], c[1][3], u0, v1, s },
    { c[2][1], c[2][2], c[2][3], u1, v1, s },
    { c[3][1], c[3][2], c[3][3], u1, v0, s },
    { c[4][1], c[4][2], c[4][3], u0, v0, s },
  }
  local indices = {}
  Voxel3D.pushQuad(indices, 0)
  return Voxel3D.newMesh(vertices, indices), image
end

local function drawable(path, face)
  local key = tostring(path) .. "#" .. tostring(face)
  if meshes[key] == nil then
    local ok, mesh, image = pcall(build, path, face)
    meshes[key] = (ok and mesh) or false
    images[key] = (ok and image) or false
  end
  return meshes[key] or nil, images[key] or nil
end

-- Register a companion provider under a stable, unique id. A provider is a
-- function `(map) -> array|nil`, or a table exposing `records(map)`. Records
-- use the engine wallDecals fields: image, cellX, cellY, face, offsetX,
-- elevation and faceOffsetY. Re-registering the same id replaces it.
function WallDecals.register(id, provider)
  if type(id) ~= "string" or id == "" then
    return false, "provider id must be a non-empty string"
  end
  local kind = type(provider)
  if kind ~= "function"
     and not (kind == "table" and type(provider.records) == "function") then
    return false, "provider must be a function or expose records(map)"
  end
  WallDecals.providers[id] = provider
  return true
end

function WallDecals.unregister(id)
  local existed = WallDecals.providers[id] ~= nil
  WallDecals.providers[id] = nil
  return existed
end

local function append(out, records)
  if type(records) ~= "table" then return end
  for _, record in ipairs(records) do
    if type(record) == "table" then out[#out + 1] = record end
  end
end

local function recordsFor(map)
  local out = {}
  local def = map and (map.def or map)
  append(out, def and def.wallDecals)

  local ids = {}
  for id in pairs(WallDecals.providers) do ids[#ids + 1] = id end
  table.sort(ids)
  for _, id in ipairs(ids) do
    local provider = WallDecals.providers[id]
    local ok, records
    if type(provider) == "function" then
      ok, records = pcall(provider, map)
    else
      ok, records = pcall(provider.records, provider, map)
    end
    if ok then append(out, records) end
  end
  return out
end

function WallDecals.draw(map, offsetX, offsetZ)
  if not (map and type(Voxel3D.draw) == "function"
          and type(Voxel3D.newMesh) == "function"
          and type(Voxel3D.glass) == "function"
          and type(Voxel3D.seams) == "function") then
    return 0
  end
  local ok, count = pcall(function()
    local drawn = 0
    Voxel3D.glass(false)
    Voxel3D.seams(false)
    for _, decal in ipairs(recordsFor(map)) do
      local cellX, cellY = tonumber(decal.cellX), tonumber(decal.cellY)
      if decal.image and cellX and cellY then
        local face = decal.face
        if face ~= "north" and face ~= "east" and face ~= "west" then
          face = "south"
        end
        local mesh, image = drawable(decal.image, face)
        if mesh and image then
          local along = tonumber(decal.offsetX) or 0
          local x = (tonumber(offsetX) or 0) + cellX * 16
          local z = (tonumber(offsetZ) or 0) + cellY * 16
          if face == "east" or face == "west" then
            z = z + along
          else
            x = x + along
          end
          local y = (tonumber(decal.elevation) or 0)
                    - (tonumber(decal.faceOffsetY) or 0)
          Voxel3D.draw(mesh, image, Mat4.translate(x, y, z))
          drawn = drawn + 1
        end
      end
    end
    return drawn
  end)

  -- Scene-global renderer switches must be restored even when a malformed
  -- companion provider, image, mesh or draw call fails.
  pcall(Voxel3D.seams, true)
  pcall(Voxel3D.glass, true)
  if not ok then return 0 end
  return count or 0
end

function WallDecals.drawState(state)
  if not (state and state.map) then return 0 end
  local count = WallDecals.draw(state.map, 0, 0)
  for _, neighbor in ipairs(state.neighbors or {}) do
    count = count + WallDecals.draw(neighbor.map, neighbor.ox or 0,
                                    neighbor.oy or 0)
  end
  return count
end

return WallDecals
