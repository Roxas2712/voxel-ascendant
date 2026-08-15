-- Owner-isolated companion API facade.
--
-- The caller supplies an explicit module allowlist. This module copies it
-- into a private table once; lookups never delegate to the caller, the mod
-- loader, storage, content APIs or a package/global resolver.

local PublicFacade = {}

function PublicFacade.new(modules)
  local allowed = {}
  for name, value in pairs(modules or {}) do
    if type(name) == "string" then allowed[name] = value end
  end

  local function resolve(name)
    if type(name) ~= "string" then return nil end
    return allowed[name]
  end

  return setmetatable({}, {
    __index = function(_, key)
      if key == "require" then return resolve end
      return nil
    end,
    __newindex = function()
      error("VOXEL_ASCENDANT: the public compatibility facade is read-only", 2)
    end,
    __metatable = "VOXEL_ASCENDANT public compatibility facade",
  })
end

return PublicFacade
