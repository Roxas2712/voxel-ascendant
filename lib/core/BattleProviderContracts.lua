-- Pure contract validation for one battle presentation provider.
--
-- Providers are internal executable services.  Their metadata is copied at
-- registration time, while callbacks remain callable only through the owning
-- router.  This module deliberately knows nothing about either engine.

local Contracts = {
  SCHEMA = "ascendant.battle-provider/v1",
  API_VERSION = 1,
}

local REQUIRED_CALLBACKS = {
  "canHandle", "start", "switch", "attack", "finish", "abort", "health",
}

local function fail(message)
  return nil, Contracts.SCHEMA .. ": " .. tostring(message)
end

local function identifier(value, field)
  if type(value) ~= "string" or value == "" then
    return nil, field .. " must be a non-empty string"
  end
  if not value:match("^[A-Z][A-Z0-9_%-]*$") then
    return nil, field .. " must use an uppercase provider identifier"
  end
  return value
end

local function dotIdentifiers(value, numericLeadingZeroForbidden)
  if type(value) ~= "string" or value == "" then return false end
  local count = 0
  for identifierValue in (value .. "."):gmatch("([^%.]*)%.") do
    count = count + 1
    if identifierValue == ""
        or not identifierValue:match("^[0-9A-Za-z%-]+$") then
      return false
    end
    if numericLeadingZeroForbidden
        and identifierValue:match("^%d+$")
        and #identifierValue > 1
        and identifierValue:sub(1, 1) == "0" then
      return false
    end
  end
  return count > 0
end

local function version(value)
  if type(value) ~= "string" then
    return nil, "version must use SemVer MAJOR.MINOR.PATCH form"
  end
  local major, minor, patch, suffix =
    value:match("^(%d+)%.(%d+)%.(%d+)(.*)$")
  if not major then
    return nil, "version must use SemVer MAJOR.MINOR.PATCH form"
  end
  for _, component in ipairs({ major, minor, patch }) do
    if #component > 1 and component:sub(1, 1) == "0" then
      return nil, "version must use SemVer MAJOR.MINOR.PATCH form"
    end
  end
  if suffix ~= "" then
    local prerelease, build
    if suffix:sub(1, 1) == "-" then
      local body = suffix:sub(2)
      local plus = body:find("+", 1, true)
      if plus then
        prerelease = body:sub(1, plus - 1)
        build = body:sub(plus + 1)
        if build:find("+", 1, true) then build = nil end
      else
        prerelease = body
      end
      if not dotIdentifiers(prerelease, true)
          or (plus and not dotIdentifiers(build, false)) then
        return nil, "version must use SemVer MAJOR.MINOR.PATCH form"
      end
    elseif suffix:sub(1, 1) == "+" then
      build = suffix:sub(2)
      if not dotIdentifiers(build, false) then
        return nil, "version must use SemVer MAJOR.MINOR.PATCH form"
      end
    else
      return nil, "version must use SemVer MAJOR.MINOR.PATCH form"
    end
  end
  return value
end

function Contracts.validate(raw)
  if type(raw) ~= "table" then return fail("service must be a table") end
  if raw.schema ~= Contracts.SCHEMA then
    return fail("schema must equal " .. Contracts.SCHEMA)
  end
  if raw.apiVersion ~= Contracts.API_VERSION then
    return fail("apiVersion must equal " .. tostring(Contracts.API_VERSION))
  end
  local id, reason = identifier(raw.id, "id")
  if not id then return fail(reason) end
  local serviceVersion
  serviceVersion, reason = version(raw.version)
  if not serviceVersion then return fail(reason) end
  local generation = tonumber(raw.generation)
  if generation == nil or generation < 1 or generation % 1 ~= 0 then
    return fail("generation must be a positive integer")
  end
  if type(raw.native) ~= "boolean" then
    return fail("native must be a boolean")
  end
  local priority = tonumber(raw.priority)
  if priority == nil or priority % 1 ~= 0 then
    return fail("priority must be an integer")
  end
  for _, name in ipairs(REQUIRED_CALLBACKS) do
    if type(raw[name]) ~= "function" then
      return fail(name .. " must be a function")
    end
  end
  return {
    schema=Contracts.SCHEMA,
    apiVersion=Contracts.API_VERSION,
    id=id,
    version=serviceVersion,
    generation=generation,
    native=raw.native,
    priority=priority,
    canHandle=raw.canHandle,
    start=raw.start,
    switch=raw.switch,
    attack=raw.attack,
    finish=raw.finish,
    abort=raw.abort,
    health=raw.health,
  }
end

function Contracts.metadata(provider)
  return {
    schema=provider.schema,
    apiVersion=provider.apiVersion,
    id=provider.id,
    version=provider.version,
    generation=provider.generation,
    native=provider.native,
    priority=provider.priority,
  }
end

return Contracts
