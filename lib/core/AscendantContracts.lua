-- Generation-neutral RC11 card contract core.
--
-- This module only validates and normalizes data.  It deliberately knows
-- nothing about the engine, VASC rendering, KASC saves or the mod loader.
-- Keeping this boundary pure makes descriptors usable by Gen 1, Gen 2, the
-- content selector and headless tooling without giving any of them ownership
-- over another component's runtime state.

local Contracts = {}

Contracts.CARD_SCHEMA = "ascendant.card/v1"

local function fail(message)
  return nil, "ascendant.card/v1: " .. message
end

local function isArray(value)
  if type(value) ~= "table" then return false end
  local count, highest = 0, 0
  for key in pairs(value) do
    if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then return false end
    count = count + 1
    if key > highest then highest = key end
  end
  if count ~= highest then return false end
  for index = 1, highest do
    if rawget(value, index) == nil then return false end
  end
  return true
end

local function copy(value, seen)
  local kind = type(value)
  if kind == "number" then
    if value ~= value or value == math.huge or value == -math.huge then
      error("contract data contains a non-finite number", 0)
    end
    return value
  end
  if kind ~= "table" then
    if kind == "nil" or kind == "boolean" or kind == "string" then
      return value
    end
    error("contract data contains unsupported " .. kind .. " value", 0)
  end
  seen = seen or {}
  if seen[value] then error("cyclic tables are not valid contract data", 0) end
  seen[value] = true
  local result = {}
  for key, item in pairs(value) do
    result[copy(key, seen)] = copy(item, seen)
  end
  seen[value] = nil
  return result
end

local function identifier(value, field)
  if type(value) ~= "string" or value == "" then
    return nil, field .. " must be a non-empty string"
  end
  if not value:match("^[%a%d][%a%d%._%-]*$") then
    return nil, field .. " contains unsupported characters"
  end
  return value
end

local function nonemptyString(value, field)
  if type(value) ~= "string" or value == "" then
    return nil, field .. " must be a non-empty string"
  end
  return value
end

-- Public hook names cross the Card boundary and are later used as exact
-- authorization keys.  Keep the grammar deliberately small so whitespace,
-- wildcards and control characters cannot turn a declaration into a broader
-- subscription than it appears to be.  Both versioned Card events
-- ("ascendant.example/v1") and the namespaced engine bridge events
-- ("mod.OWNER.example_v1") fit this grammar.
local function publicHook(value, field)
  if type(value) ~= "string" or value == "" then
    return nil, field .. " must be a non-empty string"
  end
  if not value:match("^[%a%d][%a%d%._:/%-]*$")
      or value:match("[%.:/%-]$") then
    return nil, field .. " contains unsupported public-hook characters"
  end
  return value
end

local function capability(value, field)
  if type(value) ~= "string" or value == "" then
    return nil, field .. " must be a non-empty string"
  end
  if not value:match("^[%l%d][%l%d%._%-]*/v[1-9]%d*$") then
    return nil, field .. " must be a versioned capability such as ascendant.example/v1"
  end
  return value
end

local function version(value)
  if type(value) ~= "string" or value == "" then
    return nil, "version must be a non-empty string"
  end

  local function validNumericIdentifier(identifier)
    return identifier:match("^[0-9]+$") ~= nil
      and (identifier == "0" or identifier:sub(1, 1) ~= "0")
  end

  local function validIdentifierList(list, rejectNumericLeadingZero)
    if list == "" or list:sub(1, 1) == "." or list:sub(-1) == "."
        or list:find("..", 1, true) then
      return false
    end
    for identifier in list:gmatch("[^.]+") do
      if identifier:find("[^0-9A-Za-z%-]") then return false end
      if rejectNumericLeadingZero
          and identifier:match("^[0-9]+$")
          and not validNumericIdentifier(identifier) then
        return false
      end
    end
    return true
  end

  local withoutBuild, build = value, nil
  local buildAt = value:find("+", 1, true)
  if buildAt then
    withoutBuild = value:sub(1, buildAt - 1)
    build = value:sub(buildAt + 1)
    if not validIdentifierList(build, false) then
      return nil, "version must use valid SemVer 2.0.0 MAJOR.MINOR.PATCH form"
    end
  end

  local core, prerelease = withoutBuild, nil
  local prereleaseAt = withoutBuild:find("-", 1, true)
  if prereleaseAt then
    core = withoutBuild:sub(1, prereleaseAt - 1)
    prerelease = withoutBuild:sub(prereleaseAt + 1)
    if not validIdentifierList(prerelease, true) then
      return nil, "version must use valid SemVer 2.0.0 MAJOR.MINOR.PATCH form"
    end
  end

  local major, minor, patch = core:match("^([0-9]+)%.([0-9]+)%.([0-9]+)$")
  if not major or not validNumericIdentifier(major)
      or not validNumericIdentifier(minor)
      or not validNumericIdentifier(patch) then
    return nil, "version must use valid SemVer 2.0.0 MAJOR.MINOR.PATCH form"
  end
  return value
end

local function normalizeList(raw, field, validator)
  if not isArray(raw) then return nil, field .. " must be an array" end
  local result, seen = {}, {}
  for index, value in ipairs(raw) do
    local normalized, err = validator(value, field .. "[" .. index .. "]")
    if not normalized then return nil, err end
    if seen[normalized] then return nil, field .. " contains duplicate " .. normalized end
    seen[normalized] = true
    result[#result + 1] = normalized
  end
  return result
end

local function listSet(values)
  local result = {}
  for _, value in ipairs(values) do result[value] = true end
  return result
end

local function normalizeImpact(raw)
  if type(raw) ~= "table" then return nil, "impact must be a table" end
  local ok, result = pcall(copy, raw)
  if not ok then return nil, "impact " .. tostring(result) end
  local knownLists = {
    { name="runtimeOwners", validator=identifier },
    { name="saveWrites", validator=identifier },
    { name="publicHooks", validator=publicHook },
    { name="files", validator=nonemptyString },
  }
  for _, declaration in ipairs(knownLists) do
    local field = declaration.name
    if result[field] == nil then
      result[field] = {}
    else
      local normalized, err = normalizeList(
        result[field], "impact." .. field, declaration.validator
      )
      if not normalized then return nil, err end
      result[field] = normalized
    end
  end
  return result
end

local function normalizeLifecycle(raw)
  if type(raw) ~= "table" then return nil, "lifecycle must be a table" end
  local result = {}
  for _, name in ipairs({ "install", "activate", "deactivate", "abort", "health" }) do
    if type(raw[name]) ~= "function" then
      return nil, "lifecycle." .. name .. " must be a function"
    end
    result[name] = raw[name]
  end
  return result
end

-- Validate a complete card descriptor and return an owner-isolated copy.
-- `requires` / `optionalRequires` name card ids; `consumes` / `provides`
-- name versioned public capabilities.  A stateless card explicitly uses
-- saveNamespace=false instead of silently omitting the field.
function Contracts.validateCard(raw)
  if type(raw) ~= "table" then return fail("descriptor must be a table") end
  if raw.schema ~= Contracts.CARD_SCHEMA then
    return fail("schema must equal " .. Contracts.CARD_SCHEMA)
  end

  local id, err = identifier(raw.id, "id")
  if not id then return fail(err) end
  local owner
  owner, err = identifier(raw.owner, "owner")
  if not owner then return fail(err) end
  local cardVersion
  cardVersion, err = version(raw.version)
  if not cardVersion then return fail(err) end

  local requires
  requires, err = normalizeList(raw.requires, "requires", identifier)
  if not requires then return fail(err) end
  local optionalRequires
  optionalRequires, err = normalizeList(raw.optionalRequires, "optionalRequires", identifier)
  if not optionalRequires then return fail(err) end
  local consumes
  consumes, err = normalizeList(raw.consumes, "consumes", capability)
  if not consumes then return fail(err) end
  local provides
  provides, err = normalizeList(raw.provides, "provides", capability)
  if not provides then return fail(err) end
  local tests
  tests, err = normalizeList(raw.tests, "tests", nonemptyString)
  if not tests then return fail(err) end
  if #tests == 0 then return fail("tests must contain at least one path") end
  local docs
  docs, err = normalizeList(raw.docs, "docs", nonemptyString)
  if not docs then return fail(err) end
  if #docs == 0 then return fail("docs must contain at least one path") end

  local saveNamespace = false
  if raw.saveNamespace ~= false then
    saveNamespace, err = identifier(raw.saveNamespace, "saveNamespace")
    if not saveNamespace then
      return fail(err .. " (use false for a stateless card)")
    end
  end

  local requiredSet = listSet(requires)
  for _, dependency in ipairs(optionalRequires) do
    if requiredSet[dependency] then
      return fail("optionalRequires duplicates required card " .. dependency)
    end
  end
  if requiredSet[id] then return fail("a card cannot require itself") end
  for _, dependency in ipairs(optionalRequires) do
    if dependency == id then return fail("a card cannot optionally require itself") end
  end
  local consumedSet = listSet(consumes)
  for _, name in ipairs(provides) do
    if consumedSet[name] then
      return fail("a card cannot consume and provide the same capability " .. name)
    end
  end

  local lifecycle
  lifecycle, err = normalizeLifecycle(raw.lifecycle)
  if not lifecycle then return fail(err) end
  local impact
  impact, err = normalizeImpact(raw.impact)
  if not impact then return fail(err) end

  -- A stateless Card cannot quietly announce save writes.  A stateful Card
  -- must in turn declare every write inside the one namespace it owns.  The
  -- exact namespace and dotted descendants are valid; lookalike prefixes
  -- such as "vasc.example.v10" are intentionally rejected.
  if saveNamespace == false then
    if #impact.saveWrites ~= 0 then
      return fail("impact.saveWrites must be empty when saveNamespace=false")
    end
  else
    if #impact.saveWrites == 0 then
      return fail("impact.saveWrites must declare at least one write inside saveNamespace "
        .. saveNamespace)
    end
    local descendantPrefix = saveNamespace .. "."
    for index, write in ipairs(impact.saveWrites) do
      if write ~= saveNamespace
          and write:sub(1, #descendantPrefix) ~= descendantPrefix then
        return fail(("impact.saveWrites[%d] must stay inside saveNamespace %s")
          :format(index, saveNamespace))
      end
    end
  end

  return {
    schema=Contracts.CARD_SCHEMA,
    id=id,
    version=cardVersion,
    owner=owner,
    requires=requires,
    optionalRequires=optionalRequires,
    consumes=consumes,
    provides=provides,
    tests=tests,
    docs=docs,
    saveNamespace=saveNamespace,
    lifecycle=lifecycle,
    impact=impact,
  }
end

function Contracts.assertCard(raw)
  local card, err = Contracts.validateCard(raw)
  if not card then error(err, 2) end
  return card
end

-- Metadata returned to callers never includes executable lifecycle callbacks.
function Contracts.cardMetadata(card)
  return {
    schema=card.schema,
    id=card.id,
    version=card.version,
    owner=card.owner,
    requires=copy(card.requires),
    optionalRequires=copy(card.optionalRequires),
    consumes=copy(card.consumes),
    provides=copy(card.provides),
    tests=copy(card.tests),
    docs=copy(card.docs),
    saveNamespace=card.saveNamespace,
    impact=copy(card.impact),
  }
end

return Contracts
