-- Owner-isolated compatibility module facade.
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
      error("Voxel Ascendant Gen 2: the public compatibility facade is read-only", 2)
    end,
    __metatable = "Voxel Ascendant Gen 2 public compatibility facade",
  })
end

return PublicFacade
