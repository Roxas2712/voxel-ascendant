-- Read-only core discovery surface for the internal Ascendant card runtime.
--
-- RC11 deliberately does not accept executable foreign Cards: the current
-- engine cannot bind an exported function call to the calling mod owner or
-- roll it back after a later entry failure.  Add-ons can safely observe the
-- advertised owner-scoped engine event.  Full external leases require the
-- loader seam planned for 3.1.

local Host = {
  API_VERSION = 1,
  SCHEMA = "ascendant.card-host/v1",
}

local function copy(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, item in pairs(value) do
    if type(item) ~= "function" then result[key] = copy(item) end
  end
  return result
end

function Host.new(options)
  options = options or {}
  local lifecycle = copy(options.lifecycle or {})
  local health = type(options.health) == "function"
    and options.health or function() return { ok=false, state="unavailable" } end
  local fields = {
    apiVersion=Host.API_VERSION,
    schema=Host.SCHEMA,
    cardSchema=options.cardSchema,
    externalRegistration=false,
  }

  return setmetatable({}, {
    __index=function(_, key)
      if key == "lifecycle" then return copy(lifecycle) end
      if key == "health" then return health end
      return fields[key]
    end,
    __newindex=function()
      error("VOXEL_ASCENDANT: the card host facade is read-only", 2)
    end,
    __metatable="VOXEL_ASCENDANT card host facade",
  })
end

return Host
