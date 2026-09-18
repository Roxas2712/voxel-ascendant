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
  if not Voxel.isFull(level) then
    local rung=tonumber(level) or tonumber(Voxel.level)
    if not (rung and rung>1 and rung<(Voxel.FP_LEVEL or 6)) then return false end
    -- Tower ceilings sit below the orbit camera. Keeping the complete shell
    -- in these views hides the lobby and its exit behind the roof texture.
    -- Use the same roof/near-wall cutaway as FULL; eye-level views stay closed.
    if type(HorizonWall.isOutdoorMap)=='function' and HorizonWall.isOutdoorMap(map) then return false end
    if InteriorCutaway.classFor(map)=='tower' then return true end
    local native=type(HorizonWall.interiorProfileFor)=='function'
      and HorizonWall.interiorProfileFor(map)
    return (native and native.nativeRoomPanels==true)
      or (type(HorizonWall.architecturalRoom)=='function'
          and HorizonWall.architecturalRoom(map)==true) or false
  end
  -- Never apply a room cutaway solely because an external profile happened to
  -- name an outdoor map like an interior. HorizonWall owns the authoritative
  -- `def.outdoor`/tileset check and deliberately has no class="room" shortcut.
  if type(HorizonWall.isOutdoorMap) == "function"
     and HorizonWall.isOutdoorMap(map) then return false end
  return CLOSED[InteriorCutaway.classFor(map)] == true
end

-- Ordinary interiors use the body-only slot under FULL, removing the repeated
-- border blocks that otherwise become a second near wall/roof. An optional
-- editor shell then supplies the cuttable enclosure; without one, the legacy
-- open dollhouse remains. Semantic cave/tower/room maps already use body-only
-- terrain and are cut at their separate rim draw.
function InteriorCutaway.bodyOnly(map, level)
  return InteriorCutaway.active(map, level)
         and InteriorCutaway.classFor(map) == "interior"
end

-- The enclosure's ground batch contains its synthetic ceiling and outer cap,
-- never the map's playable floor.  Suppressing it under FULL therefore opens
-- the roof without punching a hole in gameplay terrain.
function InteriorCutaway.rimVisible(rim, enabled, eye, focus)
  if rim and rim.kind=='cutaway_base' then
    if not enabled then return false end
    -- A hidden tall wall keeps its low, textured footprint. The complete
    -- face owns that same area whenever it is visible, avoiding duplicates.
    return not InteriorCutaway.rimVisible({kind='wall',
      interiorPanel=rim.interiorPanel,ox=rim.ox,oy=rim.oy},true,eye,focus)
  end
  if enabled and rim and rim.interiorPanel and eye and focus then
    local p=rim.interiorPanel
    local function faceVisible(face)
      local horizontal=face.edge=='north' or face.edge=='south'
      local axis=horizontal and 3 or 1
      local at=face.at+(horizontal and (rim.oy or 0) or (rim.ox or 0))
      local sign=(face.edge=='north' or face.edge=='west') and 1 or -1
      return ((eye[axis] or 0)-at)*sign>0 and ((focus[axis] or 0)-at)*sign>=0
    end
    if p.endcap and p.cutawayFaces then
      local parentVisible=false
      for _,face in ipairs(p.cutawayFaces)do
        if faceVisible(face)then parentVisible=true;break end
      end
      if not parentVisible then return false end
    end
    -- Only a whole wall facing the camera and its room is visible. Never
    -- cut through the middle of an image with the old global half-space.
    return faceVisible(p)
  end
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
