-- Small drawable facade for terrain streams that are too large for one
-- comfortable LOVE Mesh allocation.  The renderer understands the marker
-- and draws every part with the same shader/model; callers that only manage
-- lifetime or texture state can keep treating the bundle like one mesh.
local M = {}

-- Keep each GPU allocation near six MiB (six float32 values per vertex).
-- The value is divisible by six, so no quad/triangle can straddle parts.
M.MAX_VERTICES = 258048

local function releaseOne(mesh)
  if mesh and type(mesh.release) == "function" then
    pcall(mesh.release, mesh)
  end
end

function M.wrap(parts)
  parts = type(parts) == "table" and parts or {}
  if #parts == 0 then return nil end
  if #parts == 1 then return parts[1] end

  local bundle = {
    __voxelMeshParts = true,
    parts = parts,
    released = false,
  }

  function bundle:setTexture(texture)
    if self.released then return end
    for _, mesh in ipairs(self.parts or {}) do
      if mesh and type(mesh.setTexture) == "function" then
        mesh:setTexture(texture)
      end
    end
  end

  function bundle:release()
    if self.released then return end
    self.released = true
    for _, mesh in ipairs(self.parts or {}) do releaseOne(mesh) end
    self.parts = {}
  end

  return bundle
end

function M.release(parts)
  for _, mesh in ipairs(type(parts) == "table" and parts or {}) do
    releaseOne(mesh)
  end
end

return M
