-- Private owner bridge between the built-in Router Card and its Lifecycle
-- Card. The generic capability contains no durable transaction authority;
-- only code which owns this internal Card seam may resolve the raw router.

local OwnerControl = {}

-- copyCapability() preserves function identities while copying the public
-- service table. Keying by the start closure therefore survives Registry's
-- data boundary without placing a secret/token on the public capability.
local owners = setmetatable({}, { __mode="k" })

local function identity(service)
  return type(service) == "table" and service.start or nil
end

function OwnerControl.bind(service, router)
  local key = identity(service)
  if type(key) ~= "function" or type(router) ~= "table"
      or type(router.acquire) ~= "function" then
    return false, "battle router owner bridge is invalid"
  end
  if owners[key] ~= nil and not rawequal(owners[key], router) then
    return false, "battle router owner bridge is already bound"
  end
  owners[key] = router
  return true
end

function OwnerControl.acquire(service, operation)
  local router = owners[identity(service)]
  if router == nil then
    return nil, "battle router owner control is unavailable"
  end
  return router:acquire(operation)
end

function OwnerControl.unbind(service, router)
  local key = identity(service)
  if key == nil or not rawequal(owners[key], router) then return false end
  owners[key] = nil
  return true
end

return OwnerControl
