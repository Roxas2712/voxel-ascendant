-- Disabled VR compatibility surface for the unified Gen1/Gen2 package.
-- VR backends and native OpenXR binaries are intentionally not shipped.
-- Keep this small API because camera, battle and Pokedex modules probe it.

local VR = {
  disabledReason = "VR is not part of Voxel Ascendant 3.0 RC",
  paletteFor = nil,
  cycleVoxel = nil,
}

function VR.supported() return false end
function VR.enabled() return false end
function VR.active() return false end
function VR.update() return false end
function VR.mirror() return nil end
function VR.invalidate() return true end
function VR.shutdown() return true end
function VR.leave() return false end
function VR.stepView() return false end
function VR.status()
  return { active = false, supported = false, reason = VR.disabledReason }
end

return VR
