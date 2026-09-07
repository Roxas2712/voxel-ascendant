-- FULL's indoor dollhouse cutaway.
--
-- Ordinary Gen-I rooms are closed by ChunkMesher's repeated border ring;
-- caves, towers and the reviewed room shells are closed by HorizonWall.
-- Those are two different geometry owners, but the presentation rule is one:
-- FULL removes the camera-side enclosure and the roof so the playable floor
-- remains visible.  This module owns only that decision and its pure camera
-- plane.  It never changes map blocks, collision, warps or entity positions.

local V = ...

local Voxel = V.require("VoxelState")
local HorizonWall = V.require("HorizonWall")

local InteriorCutaway = {}

local CLOSED = {
  interior = true,
  cave = true,
  tower = true,
  room = true,
}

function InteriorCutaway.classFor(map)
  local ok, class = pcall(HorizonWall.classFor, map)
  return ok and class or nil
end

function InteriorCutaway.active(map, level)
  return Voxel.isFull(level) and CLOSED[InteriorCutaway.classFor(map)] == true
end

-- Ordinary interiors have no semantic HorizonWall shell.  FULL therefore
-- asks ChunkMesher for the body-only slot, which removes the repeated border
-- blocks that otherwise become the near wall/roof.  Semantic cave/tower/room
-- maps already use body-only terrain and are cut at their separate rim draw.
function InteriorCutaway.bodyOnly(map, level)
  return InteriorCutaway.active(map, level)
         and InteriorCutaway.classFor(map) == "interior"
end

-- The enclosure's ground batch contains its synthetic ceiling and outer cap,
-- never the map's playable floor.  Suppressing it under FULL therefore opens
-- the roof without punching a hole in gameplay terrain.
function InteriorCutaway.rimVisible(rim, enabled)
  return not (enabled and rim and rim.kind == "ground")
end

-- A normalized ground-plane half-space pointing from focus toward the eye.
-- Horizon wall fragments on that side are the camera-facing wall (plus the
-- near halves of its two corners), producing a proper three-sided dollhouse
-- from any supported camera bearing rather than hardcoding map south.
function InteriorCutaway.wallPlane(eye, focus)
  if type(eye) ~= "table" or type(focus) ~= "table" then return nil end
  local dx = (eye[1] or 0) - (focus[1] or 0)
  local dz = (eye[3] or 0) - (focus[3] or 0)
  local length = math.sqrt(dx * dx + dz * dz)
  if length < 1e-6 then return nil end
  local nx, nz = dx / length, dz / length
  return nx, nz, nx * (focus[1] or 0) + nz * (focus[3] or 0)
end

return InteriorCutaway
