-- Edition-neutral performance policy for Voxel Ascendant's Gen-2 runtime.
--
-- AUTO intentionally favours a smooth frame cadence even on a desktop.  A
-- player who wants the expensive full-resolution path can still choose MAX;
-- AUTO must be a safe install default for Gold, Silver and Crystal instead of
-- silently turning every detected desktop into the most expensive preset.

local Policy = {}

function Policy.resolveAuto(engineTier)
  if engineTier == "low" then return "eco" end
  -- Balanced and high hosts share the smooth HANDHELD default. MAX remains
  -- an explicit opt-in instead of making detected desktops pay its cost.
  return "handheld"
end

local SLICES = {
  -- Keep enough of a 16.7-ms frame for Game2, input, audio and presentation.
  -- Covered work runs during the cartridge's existing map fade and may spend
  -- more, but it is still bounded so a transition never becomes one giant
  -- synchronous stall.
  -- Current outdoor BODY work receives enough contiguous time to become
  -- playable quickly instead of revealing one structure strip at a time for
  -- tens of seconds.  Distant neighbours stay on the smaller idle slice, and
  -- fades absorb the larger covered slice without affecting visible cadence.
  max      = { urgent = 0.0140, idle = 0.0030, covered = 0.0500 },
  handheld = { urgent = 0.0110, idle = 0.0025, covered = 0.0420 },
  eco      = { urgent = 0.0070, idle = 0.0015, covered = 0.0300 },
  custom   = { urgent = 0.0110, idle = 0.0025, covered = 0.0420 },
}

-- A FULL map includes a scenery apron measured in four-tile map blocks.
-- Eight blocks was inherited from the wide Gen-1 stadium camera, but makes a
-- cold Gen-2 route mesh an enormous rectangle before connected maps are even
-- considered. The bounded low-cost builder uses a smaller footprint for
-- VASC's normal Gen-2 profiles; the broadest panorama is explicit ULTRA.
local APRON_BLOCKS = {
  max = 6,
  handheld = 2,
  eco = 1,
  custom = 2,
}

function Policy.slices(profile)
  local row = SLICES[profile] or SLICES.handheld
  return row.urgent, row.idle, row.covered
end

function Policy.apronBlocks(profile)
  return APRON_BLOCKS[profile] or APRON_BLOCKS.handheld
end

return Policy
