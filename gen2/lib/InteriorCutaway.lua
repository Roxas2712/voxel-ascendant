-- FULL's indoor dollhouse cutaway and Gen2 cave orbit visibility.
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
  local class=InteriorCutaway.classFor(map)
  if Voxel.isFull(level) then return CLOSED[class] == true end
  -- An orbit can put its eye outside/above a small cave. Without the same
  -- cutaway used by FULL, the enclosure is then a foreground wall/ceiling
  -- hiding the player (Slowpoke Well and Whirl Island NE at 50 degrees).
  -- Keep the closed shell for the two in-world walking cameras, and don't
  -- change ordinary rooms, towers or outdoor panoramas on angle-only rungs.
  local rung=tonumber(level) or tonumber(Voxel.level) or 0
  local authored = class=='room' and type(HorizonWall.architecturalRoom)=='function'
    and HorizonWall.architecturalRoom(map)
  return (class=='cave' or authored) and rung>Voxel.FULL_LEVEL and rung<Voxel.FP_LEVEL
end

-- Ordinary interiors have no semantic HorizonWall shell.  FULL therefore
-- asks ChunkMesher for the body-only slot, which removes the repeated border
-- blocks that otherwise become the near wall/roof.  Semantic cave/tower/room
-- maps already use body-only terrain and are cut at their separate rim draw.
function InteriorCutaway.bodyOnly(map, level)
  return InteriorCutaway.active(map, level)
         and InteriorCutaway.classFor(map) == "interior"
end

-- A semantic enclosure already supplies the outside walls/apron. FULL terrain
-- would add Structures.indoorShell in front of it (Olivine's dark duplicate
-- wall). Keep all native tiles, but let exactly one owner build the surround.
-- This is independent of orbit cutaway and of pending connected-map seams.
function InteriorCutaway.terrainBodyOnly(map)
  if type(HorizonWall.enabled) ~= 'function' or not HorizonWall.enabled() then return false end
  local class = InteriorCutaway.classFor(map)
  -- Rock/ice caves use their existing natural border policy, not the
  -- decorative room-shell inference being replaced here.
  return class == 'room' or class == 'tower'
end

-- Roof/caps are separate from the low apron. Rooms/towers keep the apron
-- in every cutaway so removing the roof never opens a dark floor gap.
-- Preserve the existing cave FULL policy independently of room changes.
function InteriorCutaway.rimVisible(rim, enabled, level)
  if not enabled or not rim then return true end
  if rim.kind=='ceiling' then return false end
  if rim.kind=='ground' then
    if rim.class=='room' or rim.class=='tower' then return true end
    -- A cave orbit keeps the low exterior apron; removing it with the roof
    -- exposes black strips between the playable body and its remaining walls.
    return rim.class=='cave' and not Voxel.isFull(level)
  end
  return true
end

-- A normalized ground-plane half-space pointing from focus toward the eye.
-- Horizon wall fragments on that side are the camera-facing wall (plus the
-- near halves of its two corners), producing a proper three-sided dollhouse
-- from any supported camera bearing rather than hardcoding map south.
function InteriorCutaway.wallPlane(eye, focus, map, level)
  if type(eye) ~= "table" or type(focus) ~= "table" then return nil end
  local dx = (eye[1] or 0) - (focus[1] or 0)
  local dz = (eye[3] or 0) - (focus[3] or 0)
  local length = math.sqrt(dx * dx + dz * dz)
  if length < 1e-6 then return nil end
  local nx, nz = dx / length, dz / length
  if map and InteriorCutaway.classFor(map)=='cave' and not Voxel.isFull(level)
    and tonumber(map.widthCells) and tonumber(map.heightCells) then
    -- Default orbit cameras look along an axis. Open their near boundary,
    -- not half of both side walls through the player's position. Keep the
    -- existing bearing-aware plane for arbitrary cinematic/free-pitch rigs.
    local belt=(tonumber(HorizonWall.BELT) or 32)*.5
    if math.abs(nx)<1e-6 then
      return 0,nz,nz>0 and map.heightCells*16+belt or belt
    elseif math.abs(nz)<1e-6 then
      return nx,0,nx>0 and map.widthCells*16+belt or belt
    end
  end
  return nx, nz, nx * (focus[1] or 0) + nz * (focus[3] or 0)
end

return InteriorCutaway
