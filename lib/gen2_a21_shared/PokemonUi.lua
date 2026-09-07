-- Public, owner-neutral presentation contract for Pokemon collection screens.
--
-- VASC owns presentation providers, while a separately registered host owns
-- the immutable view model and every authoritative action.  A provider is
-- visible only where an active host and provider have a complete v1
-- intersection.  Accepted controllers exclusively own input and draw into a
-- disposable host layer; the host commits that layer only after draw returns
-- true.  Any contract violation revokes the session and fails open on the
-- following frame without exposing backend objects to the provider.

local V = ...
local PokemonUi = {}

PokemonUi.API_VERSION = 1
PokemonUi.PROVIDER_SCHEMA = "voxel-ascendant/pokemon-ui-provider/v1"
PokemonUi.HOST_SCHEMA = "voxel-ascendant/pokemon-ui-host/v1"
PokemonUi.SESSION_SCHEMA = "voxel-ascendant/pokemon-ui-session/v1"
PokemonUi.FALLBACK_SCHEMA = "voxel-ascendant/pokemon-ui-fallback/v1"
PokemonUi.MODEL_SCHEMA = "voxel-ascendant/pokemon-ui-model/v1"
PokemonUi.ACTION_SCHEMA = "voxel-ascendant/pokemon-ui-action/v1"
PokemonUi.ACTION_RESULT_SCHEMA =
  "voxel-ascendant/pokemon-ui-action-result/v1"
PokemonUi.EVENT_SCHEMA = "voxel-ascendant/pokemon-ui-event/v1"
PokemonUi.CONTROLLER_GENERATION = 1
PokemonUi.HOST_GENERATION = 1
PokemonUi.TRANSACTIONAL_DRAW = "disposable_layer_commit_after_true"
PokemonUi.CAPABILITY_DIGEST_SCHEMA = "pokemon-ui-capabilities/v1"
PokemonUi.MAX_VIEWPORT_DIMENSION = 2048
PokemonUi.MAX_VIEWPORT_PIXELS = 2097152
PokemonUi.INPUT_KEYS = {
  "up", "down", "left", "right", "a", "b", "start", "select",
  "page_prev", "page_next",
}

PokemonUi.GLOBAL_KEY = "pokemonUiSkin"
PokemonUi.SURFACE_KEYS = {
  pc_box = "pokemonUiPcBox",
  legacy_bank = "pokemonUiLegacyBank",
  battle_party = "pokemonUiBattleParty",
}

PokemonUi.DEFAULT_PROVIDER = "asc_box"
PokemonUi.GAME_DEFAULT = "game_default"
PokemonUi.FOLLOW_GLOBAL = "follow_global"

-- These are presentation/controller capabilities, never storage or battle
-- implementations.  Hosts keep every mutation authoritative even when a
-- particular action is disabled in the current model snapshot.
PokemonUi.REQUIREMENTS = {
  pc_box = {
    selection = "single",
    modes = {
      "browse_box", "browse_party", "action_menu", "confirmation", "message",
    },
    actions = {
      "navigate", "inspect", "dex_entry", "move", "withdraw", "deposit", "release",
      "change_box", "print_box", "cancel",
    },
    events = {
      "opened", "model_changed", "focus_changed", "box_changed",
      "action_result", "transfer_result", "warning", "closed",
    },
  },
  legacy_bank = {
    selection = "multi_cross_box",
    modes = {
      "browse_legacy", "browse_party", "action_menu", "message",
    },
    actions = {
      "navigate", "inspect", "dex_entry", "withdraw", "deposit", "move",
      "multi_select", "cross_box_select", "transfer_selected_to_pc",
      "transfer_all_to_pc", "cancel",
    },
    events = {
      "opened", "model_changed", "focus_changed", "selection_changed",
      "box_changed", "action_result", "transfer_result",
      "capacity_warning", "warning", "closed",
    },
  },
  battle_party = {
    selection = "single",
    modes = { "browse_party", "summary", "message" },
    actions = { "navigate", "inspect", "select", "cancel" },
    events = {
      "opened", "model_changed", "focus_changed", "action_result",
      "selection_rejected", "forced_switch", "warning", "closed",
    },
  },
}

local KNOWN_SCHEMAS = {
  model = PokemonUi.MODEL_SCHEMA,
  action = PokemonUi.ACTION_SCHEMA,
  actionResult = PokemonUi.ACTION_RESULT_SCHEMA,
  event = PokemonUi.EVENT_SCHEMA,
}

local WELL_KNOWN_LABELS = {
  asc_box = "ASC BOX",
  oras_glass = "ORAS GLASS",
  game_default = "GAME DEFAULT",
  kasc_frlg = "KASC FRLG",
  follow_global = "FOLLOW GLOBAL",
}
local WELL_KNOWN_ORDER = {
  asc_box = 10, oras_glass = 20, game_default = 30, kasc_frlg = 40,
}

local providers, hosts, hostHandles = {}, {}, {}
local listeners, activeSessions, activeSessionKeys = {}, {}, {}

local function validId(value)
  return type(value) == "string" and value ~= ""
    and value:match("^[a-z][a-z0-9_%.%-]*$") ~= nil
end

local function nonempty(value)
  return type(value) == "string" and value ~= ""
end

local function integer(value, minimum)
  return type(value) == "number" and value == math.floor(value)
    and value >= (minimum or 0)
end

local function copyArray(value)
  local out = {}
  for i, item in ipairs(type(value) == "table" and value or {}) do
    out[i] = item
  end
  return out
end

local function isExactArray(value)
  if type(value) ~= "table" then return false end
  local count = 0
  for key in pairs(value) do
    if not integer(key, 1) then return false end
    count = count + 1
  end
  return count == #value
end

local function normalizeViewport(value)
  if type(value) ~= "table" or getmetatable(value) ~= nil then
    return nil, "viewport-required"
  end
  for key in pairs(value) do
    if key ~= "width" and key ~= "height" then
      return nil, "unexpected-viewport-field:" .. tostring(key)
    end
  end
  local width, height = value.width, value.height
  if not integer(width, 1) or not integer(height, 1)
      or width > PokemonUi.MAX_VIEWPORT_DIMENSION
      or height > PokemonUi.MAX_VIEWPORT_DIMENSION
      or width * height > PokemonUi.MAX_VIEWPORT_PIXELS then
    return nil, "viewport-dimensions-invalid"
  end
  return { width=width, height=height }
end

local function copyViewport(value)
  return { width=value.width, height=value.height }
end

local function viewportKey(value)
  return tostring(value.width) .. "x" .. tostring(value.height)
end

local function sameViewport(a, b)
  return type(a) == "table" and type(b) == "table"
    and a.width == b.width and a.height == b.height
end

local function normalizeViewports(value)
  if not isExactArray(value) or #value < 1 or #value > 16 then
    return nil, "viewports-required"
  end
  local out, seen = {}, {}
  for _, raw in ipairs(value) do
    local viewport, why = normalizeViewport(raw)
    if not viewport then return nil, why end
    local key = viewportKey(viewport)
    if seen[key] then return nil, "duplicate-viewport:" .. key end
    seen[key], out[#out + 1] = true, viewport
  end
  table.sort(out, function(a, b)
    if a.width ~= b.width then return a.width < b.width end
    return a.height < b.height
  end)
  return out
end

local function supportsViewport(viewports, viewport)
  for _, candidate in ipairs(viewports or {}) do
    if sameViewport(candidate, viewport) then return true end
  end
  return false
end

local function copyViewports(value)
  local out = {}
  for index, viewport in ipairs(value or {}) do
    out[index] = copyViewport(viewport)
  end
  return out
end

local function sortedUnique(value)
  if not isExactArray(value) then return nil, "list-required" end
  local out, seen = {}, {}
  for _, item in ipairs(value) do
    if not validId(item) or seen[item] then return nil, "invalid-list-item" end
    seen[item] = true
    out[#out + 1] = item
  end
  table.sort(out)
  return out
end

local function arraySet(value)
  local out = {}
  for _, item in ipairs(value or {}) do out[item] = true end
  return out
end

local function sameArray(a, b)
  if type(a) ~= "table" or type(b) ~= "table" or #a ~= #b then return false end
  for i = 1, #a do if a[i] ~= b[i] then return false end end
  return true
end

local function containsAll(have, required)
  local set = arraySet(have)
  for _, item in ipairs(required or {}) do
    if not set[item] then return false, item end
  end
  return true
end

local function exactCapabilities(value, expected, missingPrefix,
                                 unexpectedPrefix)
  local items, why = sortedUnique(value)
  if not items then return nil, why end
  local expectedItems = copyArray(expected)
  table.sort(expectedItems)
  local have = arraySet(items)
  for _, id in ipairs(expectedItems) do
    if not have[id] then return nil, missingPrefix .. id end
  end
  local wanted = arraySet(expectedItems)
  for _, id in ipairs(items) do
    if not wanted[id] then return nil, unexpectedPrefix .. id end
  end
  return items
end

local function normalizeSchemas(value)
  if type(value) ~= "table" then return nil, "schemas-required" end
  local out = {}
  for key in pairs(value) do
    if KNOWN_SCHEMAS[key] == nil then return nil, "unexpected-schema:" .. tostring(key) end
  end
  for key in pairs(KNOWN_SCHEMAS) do
    if not nonempty(value[key]) then return nil, "missing-schema:" .. key end
    out[key] = value[key]
  end
  return out
end

local function schemasEqual(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  for key in pairs(KNOWN_SCHEMAS) do
    if a[key] ~= b[key] then return false end
  end
  return true
end

local function schemasKnown(value)
  local normalized = normalizeSchemas(value)
  return normalized ~= nil and schemasEqual(normalized, KNOWN_SCHEMAS)
end

local function negotiatedCapabilityDigest(provider, host, surface, def)
  local providerDef = provider.surfaces[surface]
  local hostViewports = {}
  for _, viewport in ipairs(def.viewports) do
    hostViewports[#hostViewports + 1] = viewportKey(viewport)
  end
  local canonical = table.concat({
    PokemonUi.CAPABILITY_DIGEST_SCHEMA,
    provider.id, provider.owner, host.id, host.owner,
    tostring(host.hostGeneration), tostring(def.controllerGeneration), surface,
    def.schemas.model, def.schemas.action,
    def.schemas.actionResult, def.schemas.event,
    def.claims.selection,
    table.concat(def.modes, ","),
    table.concat(def.actions, ","),
    table.concat(def.events, ","),
    viewportKey(providerDef.viewport),
    table.concat(hostViewports, ","),
  }, "|")
  -- A deterministic, dependency-free fingerprint.  This is an equality
  -- guard against stale negotiated receipts, not a cryptographic signature.
  local hash = 5381
  for index = 1, #canonical do
    hash = (hash * 33 + canonical:byte(index)) % 4294967296
  end
  return PokemonUi.CAPABILITY_DIGEST_SCHEMA .. ":"
    .. string.format("%08x", hash)
end

local function plainCopy(value, seen, depth, count)
  local kind = type(value)
  if kind == "nil" or kind == "string" or kind == "boolean" then return value end
  if kind == "number" then
    if value ~= value or value == math.huge or value == -math.huge then
      return nil, "non-finite-number"
    end
    return value
  end
  if kind ~= "table" then return nil, "non-data-value" end
  if getmetatable(value) ~= nil then return nil, "metatable-not-allowed" end
  if seen[value] then return nil, "cyclic-table" end
  if depth > 24 then return nil, "model-too-deep" end
  count.value = count.value + 1
  if count.value > 4096 then return nil, "model-too-large" end
  seen[value] = true
  local out = {}
  for key, item in pairs(value) do
    local keyType = type(key)
    if keyType ~= "string" and keyType ~= "number" and keyType ~= "boolean" then
      seen[value] = nil
      return nil, "non-data-key"
    end
    local copied, why = plainCopy(item, seen, depth + 1, count)
    if why then seen[value] = nil; return nil, why end
    out[key] = copied
  end
  seen[value] = nil
  return out
end

local function cloneData(value)
  return plainCopy(value, {}, 0, { value=0 })
end

local function publicRequirement(surface)
  local src = PokemonUi.REQUIREMENTS[surface]
  if not src then return nil end
  return {
    selection = src.selection,
    modes = copyArray(src.modes),
    actions = copyArray(src.actions),
    events = copyArray(src.events),
  }
end

local function notify()
  for _, listener in ipairs(listeners) do pcall(listener) end
end

function PokemonUi.onRegistryChanged(listener)
  if type(listener) ~= "function" then return false end
  listeners[#listeners + 1] = listener
  return true
end

local function completeProviderSurface(surface, def)
  local required = PokemonUi.REQUIREMENTS[surface]
  if not required or type(def) ~= "table"
     or def.controllerGeneration ~= PokemonUi.CONTROLLER_GENERATION
     or type(def.create) ~= "function" or type(def.claims) ~= "table"
     or def.claims.draw ~= "complete" or def.claims.input ~= "complete"
     or def.claims.commit ~= "atomic"
     or def.claims.selection ~= required.selection then
    return nil, "incomplete-surface-claim"
  end
  local schemas, schemaErr = normalizeSchemas(def.schemas)
  if not schemas then return nil, schemaErr end
  local viewport, viewportErr = normalizeViewport(def.viewport)
  if not viewport then return nil, viewportErr end
  local modes, modeErr = sortedUnique(def.modes)
  local actions, actionErr = sortedUnique(def.actions)
  local events, eventErr = sortedUnique(def.events)
  if not modes or not actions or not events then
    return nil, modeErr or actionErr or eventErr
  end
  local ok, missing = containsAll(modes, required.modes)
  if not ok then return nil, "missing-mode:" .. missing end
  ok, missing = containsAll(actions, required.actions)
  if not ok then return nil, "missing-action:" .. missing end
  ok, missing = containsAll(events, required.events)
  if not ok then return nil, "missing-event:" .. missing end
  return {
    controllerGeneration=def.controllerGeneration,
    schemas=schemas, modes=modes,
    viewport=viewport,
    claims={
      draw="complete", input="complete", commit="atomic",
      selection=def.claims.selection,
    },
    actions=actions, events=events, create=def.create,
  }
end

local function completeHostSurface(surface, def)
  local required = PokemonUi.REQUIREMENTS[surface]
  local claims = type(def) == "table" and def.claims or nil
  if not required or type(def) ~= "table"
     or def.controllerGeneration ~= PokemonUi.CONTROLLER_GENERATION
     or type(claims) ~= "table"
     or claims.model ~= "immutable_snapshot"
     or claims.actions ~= "authoritative"
     or claims.input ~= "exclusive"
     or claims.commit ~= "atomic"
     or claims.fallback ~= "whole_surface_next_frame"
     or claims.selection ~= required.selection then
    return nil, "incomplete-host-surface-claim"
  end
  local schemas, schemaErr = normalizeSchemas(def.schemas)
  if not schemas then return nil, schemaErr end
  local viewports, viewportErr = normalizeViewports(def.viewports)
  if not viewports then return nil, viewportErr end
  local modes, modeErr = sortedUnique(def.modes)
  local actions, actionErr = sortedUnique(def.actions)
  local events, eventErr = sortedUnique(def.events)
  if not modes or not actions or not events then
    return nil, modeErr or actionErr or eventErr
  end
  local ok, missing = containsAll(modes, required.modes)
  if not ok then return nil, "missing-mode:" .. missing end
  ok, missing = containsAll(actions, required.actions)
  if not ok then return nil, "missing-action:" .. missing end
  ok, missing = containsAll(events, required.events)
  if not ok then return nil, "missing-event:" .. missing end
  return {
    controllerGeneration=def.controllerGeneration,
    schemas=schemas, modes=modes, viewports=viewports,
    claims={
      model="immutable_snapshot", actions="authoritative",
      input="exclusive", commit="atomic",
      fallback="whole_surface_next_frame", selection=claims.selection,
    },
    actions=actions, events=events,
  }
end

local function collectSessions(predicate)
  local out = {}
  for session, entry in pairs(activeSessions) do
    if predicate(entry) then out[#out + 1] = session end
  end
  return out
end

function PokemonUi.register(receipt)
  if type(receipt) ~= "table"
     or receipt.schema ~= PokemonUi.PROVIDER_SCHEMA
     or receipt.apiVersion ~= PokemonUi.API_VERSION
     or not validId(receipt.id)
     or receipt.id == PokemonUi.GAME_DEFAULT
     or receipt.id == PokemonUi.FOLLOW_GLOBAL
     or providers[receipt.id]
     or not nonempty(receipt.owner) or not nonempty(receipt.label)
     or type(receipt.surfaces) ~= "table" then
    return nil, "invalid-or-duplicate-provider-receipt"
  end
  local surfaces, count = {}, 0
  for surface, def in pairs(receipt.surfaces) do
    local complete, why = completeProviderSurface(surface, def)
    if not complete then return nil, tostring(surface) .. ":" .. tostring(why) end
    surfaces[surface], count = complete, count + 1
  end
  if count == 0 then return nil, "provider-has-no-complete-surface" end
  local stored = {
    schema=PokemonUi.PROVIDER_SCHEMA, apiVersion=PokemonUi.API_VERSION,
    id=receipt.id, owner=receipt.owner, label=receipt.label,
    surfaces=surfaces,
  }
  providers[stored.id] = stored
  notify()
  return function()
    if providers[stored.id] ~= stored then return false end
    providers[stored.id] = nil
    for _, session in ipairs(collectSessions(function(entry)
      return entry.provider == stored
    end)) do session:_retire("provider-unregistered", true) end
    notify()
    return true
  end
end

local function hostSummary(host, surface)
  local out = {
    schema=host.schema, apiVersion=host.apiVersion,
    id=host.id, owner=host.owner, hostGeneration=host.hostGeneration,
    surfaces={},
  }
  for id, def in pairs(host.surfaces) do
    if surface == nil or surface == id then
      out.surfaces[id] = {
        controllerGeneration=def.controllerGeneration,
        schemas={
          model=def.schemas.model, action=def.schemas.action,
          actionResult=def.schemas.actionResult, event=def.schemas.event,
        },
        modes=copyArray(def.modes), actions=copyArray(def.actions),
        events=copyArray(def.events), viewports=copyViewports(def.viewports),
        claims={
          model=def.claims.model, actions=def.claims.actions,
          input=def.claims.input, commit=def.claims.commit,
          fallback=def.claims.fallback, selection=def.claims.selection,
        },
      }
    end
  end
  return out
end

local function validHostHandle(handle)
  local host = type(handle) == "table" and hostHandles[handle] or nil
  if host and hosts[host.id] == host then return host end
  return nil
end

function PokemonUi.unregisterHost(handle)
  local host = validHostHandle(handle)
  if not host then return false end
  hosts[host.id], hostHandles[handle] = nil, nil
  for _, session in ipairs(collectSessions(function(entry)
    return entry.host == host
  end)) do session:_retire("host-unregistered", true) end
  notify()
  return true
end

function PokemonUi.registerHost(receipt)
  if type(receipt) ~= "table"
     or receipt.schema ~= PokemonUi.HOST_SCHEMA
     or receipt.apiVersion ~= PokemonUi.API_VERSION
     or receipt.hostGeneration ~= PokemonUi.HOST_GENERATION
     or not validId(receipt.id) or hosts[receipt.id]
     or not nonempty(receipt.owner)
     or type(receipt.surfaces) ~= "table" then
    return nil, "invalid-or-duplicate-host-receipt"
  end
  local surfaces, count = {}, 0
  for surface, def in pairs(receipt.surfaces) do
    local complete, why = completeHostSurface(surface, def)
    if not complete then return nil, tostring(surface) .. ":" .. tostring(why) end
    surfaces[surface], count = complete, count + 1
  end
  if count == 0 then return nil, "host-has-no-complete-surface" end
  local stored = {
    schema=PokemonUi.HOST_SCHEMA, apiVersion=PokemonUi.API_VERSION,
    id=receipt.id, owner=receipt.owner,
    hostGeneration=PokemonUi.HOST_GENERATION, surfaces=surfaces,
  }
  local handle = {}
  function handle:begin(request) return PokemonUi.begin(self, request) end
  function handle:resolve(surface) return PokemonUi.resolve(surface, self) end
  function handle:list(surface) return PokemonUi.list(surface, self) end
  function handle:unregister() return PokemonUi.unregisterHost(self) end
  setmetatable(handle, { __metatable="pokemon-ui-host-handle/v1" })
  hosts[stored.id], hostHandles[handle] = stored, stored
  notify()
  return handle
end

function PokemonUi.listHosts(surface)
  if surface ~= nil and not PokemonUi.REQUIREMENTS[surface] then return {} end
  local ids = {}
  for id, host in pairs(hosts) do
    if surface == nil or host.surfaces[surface] then ids[#ids + 1] = id end
  end
  table.sort(ids)
  local out = {}
  for _, id in ipairs(ids) do out[#out + 1] = hostSummary(hosts[id], surface) end
  return out
end

local function compatible(provider, host, surface)
  local p = provider and provider.surfaces and provider.surfaces[surface]
  local h = host and host.surfaces and host.surfaces[surface]
  if not p or not h then return false, "surface-missing" end
  if p.controllerGeneration ~= h.controllerGeneration then
    return false, "controller-generation-mismatch"
  end
  if p.claims.selection ~= h.claims.selection then
    return false, "selection-mismatch"
  end
  if not supportsViewport(h.viewports, p.viewport) then
    return false, "viewport-mismatch"
  end
  if not schemasKnown(p.schemas) or not schemasKnown(h.schemas)
     or not schemasEqual(p.schemas, h.schemas) then
    return false, "schema-mismatch"
  end
  local ok, missing = containsAll(p.modes, h.modes)
  if not ok then return false, "provider-missing-mode:" .. tostring(missing) end
  ok, missing = containsAll(p.actions, h.actions)
  if not ok then return false, "provider-missing-action:" .. tostring(missing) end
  ok, missing = containsAll(p.events, h.events)
  if not ok then return false, "provider-missing-event:" .. tostring(missing) end
  return true
end

local function matchingHosts(provider, surface, exactHost)
  local out = {}
  if exactHost then
    if compatible(provider, exactHost, surface) then out[1] = exactHost end
  else
    for _, host in pairs(hosts) do
      if compatible(provider, host, surface) then out[#out + 1] = host end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
  end
  return out
end

local function providerIntersects(provider, surface, exactHost)
  if surface then return #matchingHosts(provider, surface, exactHost) > 0 end
  for id in pairs(provider.surfaces or {}) do
    if #matchingHosts(provider, id, exactHost) > 0 then return true end
  end
  return false
end

local function sortedProviderIds(surface, exactHost)
  local ids = {}
  for id, provider in pairs(providers) do
    if providerIntersects(provider, surface, exactHost) then ids[#ids + 1] = id end
  end
  table.sort(ids, function(a, b)
    local pa, pb = WELL_KNOWN_ORDER[a] or 1000, WELL_KNOWN_ORDER[b] or 1000
    if pa ~= pb then return pa < pb end
    return a < b
  end)
  return ids
end

local function providerSummary(provider, surface, exactHost)
  local out = {
    id=provider.id, label=provider.label, owner=provider.owner,
    schema=provider.schema, apiVersion=provider.apiVersion,
    surfaces={}, hosts={},
  }
  for id, def in pairs(provider.surfaces) do
    if (surface == nil or id == surface)
       and #matchingHosts(provider, id, exactHost) > 0 then
      out.surfaces[id] = {
        controllerGeneration=def.controllerGeneration,
        schemas={
          model=def.schemas.model, action=def.schemas.action,
          actionResult=def.schemas.actionResult, event=def.schemas.event,
        },
        modes=copyArray(def.modes), actions=copyArray(def.actions),
        events=copyArray(def.events), viewport=copyViewport(def.viewport),
        claims={
          draw=def.claims.draw, input=def.claims.input,
          commit=def.claims.commit, selection=def.claims.selection,
        },
      }
      for _, host in ipairs(matchingHosts(provider, id, exactHost)) do
        out.hosts[host.id] = { id=host.id, owner=host.owner,
          hostGeneration=host.hostGeneration }
      end
    end
  end
  return out
end

function PokemonUi.list(surface, handle)
  if surface ~= nil and not PokemonUi.REQUIREMENTS[surface] then return {} end
  local exactHost
  if handle ~= nil then
    exactHost = validHostHandle(handle)
    if not exactHost then
      return {{ id=PokemonUi.GAME_DEFAULT,
        label=WELL_KNOWN_LABELS.game_default, owner="game", builtin=true }}
    end
  end
  local out = {{
    id=PokemonUi.GAME_DEFAULT, label=WELL_KNOWN_LABELS.game_default,
    owner="game", builtin=true,
  }}
  for _, id in ipairs(sortedProviderIds(surface, exactHost)) do
    out[#out + 1] = providerSummary(providers[id], surface, exactHost)
  end
  return out
end

local function modId()
  return V.mod and V.mod.id or "VOXEL_ASCENDANT"
end

local function optionValue(key)
  local mod = V.mod
  if mod and mod.options and type(mod.options.get) == "function" then
    local ok, value = pcall(mod.options.get, mod.options, key)
    if ok then return value end
  end
  return nil
end

local function persist(game, key, value)
  local id = modId()
  local opts = game and game.save and game.save.options
  if opts then
    opts.modOptions = opts.modOptions or {}
    opts.modOptions[id] = opts.modOptions[id] or {}
    opts.modOptions[id][key] = value
  end
  local loader = game and game.mods
  if loader then
    loader.modOptions = loader.modOptions or {}
    loader.modOptions[id] = loader.modOptions[id] or {}
    loader.modOptions[id][key] = value
  end
  if game and type(game.writeOptions) == "function" then
    pcall(game.writeOptions, game)
  end
end

local Setting = {}
Setting.__index = Setting

local function validSettingValue(setting, value)
  if value == PokemonUi.GAME_DEFAULT then return true end
  if value == PokemonUi.FOLLOW_GLOBAL then
    return setting.surface ~= nil and setting.showFollowGlobal ~= false
  end
  local valid = validId(value)
    and value ~= PokemonUi.FOLLOW_GLOBAL
    and value ~= PokemonUi.GAME_DEFAULT
  if not valid then return false end
  return not setting.allowedProviders
    or setting.allowedProviders[value] == true
end

function Setting.new(key, label, surface, options)
  options = type(options) == "table" and options or {}
  local showFollowGlobal = surface ~= nil
    and options.showFollowGlobal ~= false
  return setmetatable({
    key=key, label=label, surface=surface,
    showFollowGlobal=showFollowGlobal,
    allowedProviders=options.allowedProviders,
    defaultValue=surface and (showFollowGlobal
      and PokemonUi.FOLLOW_GLOBAL or PokemonUi.DEFAULT_PROVIDER)
      or PokemonUi.DEFAULT_PROVIDER,
    cached=nil,
  }, Setting)
end

function Setting:read()
  if self.cached ~= nil then return self.cached end
  local value = optionValue(self.key)
  self.cached = validSettingValue(self, value) and value or self.defaultValue
  return self.cached
end

function Setting:get() return self:read() end

function Setting:sync(value)
  self.cached = validSettingValue(self, value) and value or self.defaultValue
end

local function choiceIds(setting)
  local out = {}
  if setting.surface and setting.showFollowGlobal then
    out[#out + 1] = PokemonUi.FOLLOW_GLOBAL
  end
  for _, id in ipairs(sortedProviderIds(setting.surface)) do
    if not setting.allowedProviders or setting.allowedProviders[id] then
      out[#out + 1] = id
    end
  end
  out[#out + 1] = PokemonUi.GAME_DEFAULT
  return out
end

local function labelFor(id)
  local provider = providers[id]
  return provider and provider.label or WELL_KNOWN_LABELS[id]
    or string.upper(tostring(id):gsub("_", " "))
end

function Setting:rungs() return #choiceIds(self) end

function Setting:setValue(value, game)
  local allowed = false
  for _, id in ipairs(choiceIds(self)) do
    if id == value then allowed = true break end
  end
  if not allowed then return false end
  self.cached = value
  persist(game, self.key, value)
  return true
end

function Setting:cycle(game, dir)
  local ids = choiceIds(self)
  local current, at = self:read(), 0
  for i, id in ipairs(ids) do if id == current then at = i break end end
  if at == 0 then at = 1 - (dir or 1) end
  at = ((at + (dir or 1) - 1) % #ids) + 1
  return self:setValue(ids[at], game)
end

function Setting:row()
  local setting = self
  return {
    id=modId() .. ":" .. self.key,
    label=self.label,
    value=function()
      if setting.surface and setting:read() == PokemonUi.FOLLOW_GLOBAL then
        return WELL_KNOWN_LABELS.follow_global
      end
      if not setting.surface then
        local requested = setting:read()
        local live = false
        for _, id in ipairs(sortedProviderIds(nil)) do
          if id == requested then live = true break end
        end
        return labelFor(live and requested or PokemonUi.GAME_DEFAULT)
      end
      return labelFor(PokemonUi.resolve(setting.surface).effective)
    end,
    step=function(game, dir)
      setting:cycle(game, dir)
      return true
    end,
  }
end

function Setting:schema(help)
  local choices = {}
  for _, id in ipairs(choiceIds(self)) do
    choices[#choices + 1] = { labelFor(id), id }
  end
  return {
    key=self.key, type="choice", label=self.label, choices=choices,
    default=self.defaultValue, help=help,
  }
end

PokemonUi.globalSetting = Setting.new(PokemonUi.GLOBAL_KEY, "POKéMON UI", nil)
PokemonUi.surfaceSettings = {
  pc_box=Setting.new(PokemonUi.SURFACE_KEYS.pc_box, "PC BOX UI", "pc_box"),
  legacy_bank=Setting.new(PokemonUi.SURFACE_KEYS.legacy_bank,
    "LEGACY BANK UI", "legacy_bank"),
  battle_party=Setting.new(PokemonUi.SURFACE_KEYS.battle_party,
    "BATTLE TEAM UI", "battle_party", {
      showFollowGlobal=false,
      allowedProviders={ asc_box=true, oras_glass=true },
    }),
}

function PokemonUi.settings()
  return {
    PokemonUi.globalSetting,
    PokemonUi.surfaceSettings.pc_box,
    PokemonUi.surfaceSettings.legacy_bank,
    PokemonUi.surfaceSettings.battle_party,
  }
end

function PokemonUi.resolve(surface, handle)
  if not PokemonUi.REQUIREMENTS[surface] then
    return { requested=nil, effective=PokemonUi.GAME_DEFAULT,
      reason="unknown-surface", surface=surface }
  end
  local override = PokemonUi.surfaceSettings[surface]:read()
  local requested = override == PokemonUi.FOLLOW_GLOBAL
    and PokemonUi.globalSetting:read() or override
  if requested == PokemonUi.GAME_DEFAULT then
    return { surface=surface, override=override, requested=requested,
      effective=PokemonUi.GAME_DEFAULT, reason="explicit-game-default" }
  end
  local provider = providers[requested]
  if not provider then
    return { surface=surface, override=override, requested=requested,
      effective=PokemonUi.GAME_DEFAULT, reason="provider-missing" }
  end
  if not provider.surfaces[surface] then
    return { surface=surface, override=override, requested=requested,
      effective=PokemonUi.GAME_DEFAULT,
      reason="provider-does-not-support-surface" }
  end
  local exactHost
  if handle ~= nil then
    exactHost = validHostHandle(handle)
    if not exactHost then
      return { surface=surface, override=override, requested=requested,
        effective=PokemonUi.GAME_DEFAULT,
        reason="invalid-or-stale-host-handle" }
    end
    if not exactHost.surfaces[surface] then
      return { surface=surface, override=override, requested=requested,
        effective=PokemonUi.GAME_DEFAULT,
        reason="host-does-not-support-surface" }
    end
  else
    local anyHost = false
    for _, host in pairs(hosts) do
      if host.surfaces[surface] then anyHost = true break end
    end
    if not anyHost then
      return { surface=surface, override=override, requested=requested,
        effective=PokemonUi.GAME_DEFAULT, reason="host-missing" }
    end
  end
  local matches = matchingHosts(provider, surface, exactHost)
  if #matches == 0 then
    return { surface=surface, override=override, requested=requested,
      effective=PokemonUi.GAME_DEFAULT,
      reason="provider-host-incompatible" }
  end
  return {
    surface=surface, override=override, requested=requested,
    effective=requested, provider=providerSummary(provider, surface, exactHost),
    host=exactHost and hostSummary(exactHost, surface) or nil,
    viewport=copyViewport(provider.surfaces[surface].viewport),
  }
end

local function fallback(surface, session, requested, reason, host)
  return {
    schema=PokemonUi.FALLBACK_SCHEMA, apiVersion=PokemonUi.API_VERSION,
    owner="game", provider=PokemonUi.GAME_DEFAULT,
    requested=requested, effective=PokemonUi.GAME_DEFAULT,
    host=host and host.id or nil, hostOwner=host and host.owner or nil,
    hostGeneration=host and host.hostGeneration or nil,
    surface=surface, session=session,
    controllerGeneration=PokemonUi.CONTROLLER_GENERATION,
    complete=false, failOpen=true, reason=reason,
  }
end

local function validateCallbacks(hostDef, actions)
  if type(actions) ~= "table" then return nil, "action-callbacks-required" end
  local expected = arraySet(hostDef.actions)
  for _, id in ipairs(hostDef.actions) do
    if type(actions[id]) ~= "function" then
      return nil, "missing-host-action:" .. id
    end
  end
  local out = {}
  for id, callback in pairs(actions) do
    if not validId(id) or type(callback) ~= "function" then
      return nil, "invalid-host-action"
    end
    if not expected[id] then return nil, "unexpected-host-action:" .. id end
    out[id] = callback
  end
  return out
end

local function validateEvents(hostDef, events)
  return exactCapabilities(events, hostDef.events,
    "missing-host-event:", "unexpected-host-event:")
end

local function validateLocation(value, requireId)
  if type(value) ~= "table" or not nonempty(value.zone)
     or not integer(value.slot, 1) then return false end
  if requireId and not nonempty(value.id) then return false end
  if value.box ~= nil and not integer(value.box, 1) then return false end
  return true
end

local function onlyKeys(value, allowed)
  if type(value) ~= "table" then return false end
  for key in pairs(value) do if not allowed[key] then return false, key end end
  return true
end

local INPUT_ENVELOPE_KEYS = arraySet({ "pressed" })
local INPUT_KEYS = arraySet(PokemonUi.INPUT_KEYS)

local function validateInputEnvelope(raw)
  local input, why = cloneData(raw)
  if not input then return nil, "unsafe-input:" .. tostring(why) end
  if not onlyKeys(input, INPUT_ENVELOPE_KEYS)
      or type(input.pressed) ~= "table"
      or not onlyKeys(input.pressed, INPUT_KEYS) then
    return nil, "input-shape-invalid"
  end
  for _, value in pairs(input.pressed) do
    if type(value) ~= "boolean" then return nil, "input-value-invalid" end
  end
  return input
end

local MODEL_KEYS = arraySet({
  "schema", "apiVersion", "host", "hostGeneration", "surface", "session",
  "revision", "locale", "edition", "mode", "title", "help", "message",
  "focus", "selection", "zones", "availability", "surfaceData",
})
local FOCUS_KEYS = arraySet({ "zone", "slot", "id", "box" })
local SELECTION_KEYS = arraySet({ "kind", "ids", "revision" })
local ZONE_KEYS = arraySet({ "label", "index", "count", "capacity", "entries" })
local ENTRY_KEYS = arraySet({
  "id", "zone", "slot", "box", "pokemon", "selected", "enabled",
  "reason", "tags", "capabilities", "metadata",
})
local POKEMON_KEYS = arraySet({
  "species", "form", "gender", "shiny", "egg", "nickname", "level",
  "hp", "maxHp", "attack", "defense", "speed", "special", "status",
  "ability", "item", "palette", "types", "markings", "art",
})
local ART_KEYS = arraySet({
  "kind", "species", "form", "gender", "shiny", "egg", "variant", "palette",
})
local AVAILABILITY_KEYS = arraySet({
  "enabled", "code", "reason", "confirmationRequired",
})
local SURFACE_DATA_KEYS = {
  pc_box = arraySet({
    "title", "currentBox", "boxCount", "boxCapacity", "partyCapacity",
    "canPrint",
  }),
  legacy_bank = arraySet({
    "title", "currentBox", "boxCount", "boxCapacity", "partyCapacity",
    "selectedCount", "moveSource",
  }),
  battle_party = arraySet({
    "title", "forcedSwitch", "canCancel", "reason",
  }),
}

local function scalarId(value)
  return nonempty(value) or integer(value, 0)
end

local function optionalString(value)
  return value == nil or type(value) == "string"
end

local function optionalBoolean(value)
  return value == nil or type(value) == "boolean"
end

local function optionalInteger(value, minimum)
  return value == nil or integer(value, minimum)
end

local function stringArray(value)
  if value == nil then return true end
  if not isExactArray(value) then return false end
  for _, item in ipairs(value) do if not nonempty(item) then return false end end
  return true
end

local function validateArtDescriptor(value)
  if value == nil then return true end
  if not onlyKeys(value, ART_KEYS) or value.kind ~= "pokemon"
     or not scalarId(value.species)
     or (value.form ~= nil and not scalarId(value.form))
     or not optionalString(value.gender)
     or not optionalBoolean(value.shiny) or not optionalBoolean(value.egg)
     or not optionalString(value.variant)
     or (value.palette ~= nil and not scalarId(value.palette)) then
    return false
  end
  return true
end

local function validatePokemonDescriptor(value)
  if type(value) ~= "table" or not onlyKeys(value, POKEMON_KEYS)
     or not scalarId(value.species)
     or (value.form ~= nil and not scalarId(value.form))
     or not optionalString(value.gender)
     or not optionalBoolean(value.shiny) or not optionalBoolean(value.egg)
     or not optionalString(value.nickname)
     or not optionalInteger(value.level, 0)
     or not optionalInteger(value.hp, 0)
     or not optionalInteger(value.maxHp, 0)
     or not optionalInteger(value.attack, 0)
     or not optionalInteger(value.defense, 0)
     or not optionalInteger(value.speed, 0)
     or not optionalInteger(value.special, 0)
     or not optionalString(value.status)
     or (value.ability ~= nil and not scalarId(value.ability))
     or (value.item ~= nil and not scalarId(value.item))
     or (value.palette ~= nil and not scalarId(value.palette))
     or not stringArray(value.types) or not stringArray(value.markings)
     or not validateArtDescriptor(value.art) then
    return false
  end
  return true
end

local function validSurfaceData(surface, value)
  local allowed = SURFACE_DATA_KEYS[surface]
  if not allowed or not onlyKeys(value, allowed) then return false end
  for key, item in pairs(value) do
    if key == "title" or key == "reason" or key == "moveSource" then
      if type(item) ~= "string" then return false end
    elseif key == "canPrint" or key == "forcedSwitch" or key == "canCancel" then
      if type(item) ~= "boolean" then return false end
    elseif not integer(item, 0) then
      return false
    end
  end
  return true
end

local function validateModel(raw, host, surface, session, hostDef)
  local model, copyErr = cloneData(raw)
  if not model then return nil, "unsafe-model:" .. tostring(copyErr) end
  local bounded, unexpected = onlyKeys(model, MODEL_KEYS)
  if not bounded then return nil, "model-unexpected-field:" .. tostring(unexpected) end
  if model.schema ~= hostDef.schemas.model
     or model.schema ~= PokemonUi.MODEL_SCHEMA then
    return nil, "model-schema-mismatch"
  end
  if model.apiVersion ~= PokemonUi.API_VERSION then
    return nil, "model-api-version-mismatch"
  end
  if model.host ~= host.id then return nil, "model-host-mismatch" end
  if model.hostGeneration ~= host.hostGeneration then
    return nil, "model-host-generation-mismatch"
  end
  if model.surface ~= surface then return nil, "model-surface-mismatch" end
  if model.session ~= session then return nil, "model-session-mismatch" end
  if not integer(model.revision, 0) then return nil, "model-revision-invalid" end
  if not nonempty(model.locale) or not nonempty(model.edition) then
    return nil, "model-presentation-context-invalid"
  end
  if not arraySet(hostDef.modes)[model.mode] then return nil, "model-mode-invalid" end
  if type(model.focus) ~= "table" or not onlyKeys(model.focus, FOCUS_KEYS)
     or not nonempty(model.focus.zone)
     or (model.focus.slot ~= nil and not integer(model.focus.slot, 1))
     or (model.focus.id ~= nil and not nonempty(model.focus.id))
     or (model.focus.box ~= nil and not integer(model.focus.box, 1)) then
    return nil, "model-focus-invalid"
  end
  if type(model.selection) ~= "table"
     or not onlyKeys(model.selection, SELECTION_KEYS)
     or model.selection.kind ~= hostDef.claims.selection
     or not isExactArray(model.selection.ids)
     or (model.selection.revision ~= nil
       and not integer(model.selection.revision, 0)) then
    return nil, "model-selection-invalid"
  end
  local seen = {}
  for _, id in ipairs(model.selection.ids) do
    if not nonempty(id) or seen[id] then return nil, "model-selection-invalid" end
    seen[id] = true
  end
  if hostDef.claims.selection == "single" and #model.selection.ids > 1 then
    return nil, "model-selection-invalid"
  end
  if type(model.zones) ~= "table" or type(model.zones[model.focus.zone]) ~= "table" then
    return nil, "model-zones-invalid"
  end
  for zone, value in pairs(model.zones) do
    if not nonempty(zone) or type(value) ~= "table"
       or not onlyKeys(value, ZONE_KEYS)
       or not isExactArray(value.entries)
       or not optionalString(value.label)
       or not optionalInteger(value.index, 1)
       or not optionalInteger(value.count, 0)
       or not optionalInteger(value.capacity, 0) then
      return nil, "model-zone-invalid"
    end
    for _, entry in ipairs(value.entries) do
      if type(entry) ~= "table" or not onlyKeys(entry, ENTRY_KEYS)
         or not nonempty(entry.id)
         or entry.zone ~= zone or not integer(entry.slot, 1)
         or (entry.box ~= nil and not integer(entry.box, 1))
         or (entry.pokemon ~= nil and not validatePokemonDescriptor(entry.pokemon))
         or not optionalBoolean(entry.selected)
         or not optionalBoolean(entry.enabled)
         or not optionalString(entry.reason)
         or not stringArray(entry.tags)
         or (entry.capabilities ~= nil and type(entry.capabilities) ~= "table")
         or (entry.metadata ~= nil and type(entry.metadata) ~= "table") then
        return nil, "model-entry-invalid"
      end
    end
  end
  if type(model.availability) ~= "table" then
    return nil, "model-availability-invalid"
  end
  local expectedActions = arraySet(hostDef.actions)
  for _, id in ipairs(hostDef.actions) do
    local availability = model.availability[id]
    if type(availability) ~= "table"
       or not onlyKeys(availability, AVAILABILITY_KEYS)
       or type(availability.enabled) ~= "boolean"
       or not optionalString(availability.code)
       or not optionalString(availability.reason)
       or not optionalBoolean(availability.confirmationRequired) then
      return nil, "model-availability-missing:" .. id
    end
  end
  for id in pairs(model.availability) do
    if not expectedActions[id] then
      return nil, "model-availability-unexpected:" .. tostring(id)
    end
  end
  if type(model.surfaceData) ~= "table"
     or not validSurfaceData(surface, model.surfaceData) then
    return nil, "model-surface-data-invalid"
  end
  if not optionalString(model.title) or not optionalString(model.help)
     or (model.message ~= nil and type(model.message) ~= "table") then
    return nil, "model-copy-invalid"
  end
  return model
end

local RESERVED_ACTION_FIELDS = {
  schema=true, apiVersion=true, host=true, hostGeneration=true,
  surface=true, session=true, action=true,
}
local ACTION_PAYLOAD_KEYS = {
  navigate=arraySet({ "modelRevision", "direction" }),
  inspect=arraySet({ "modelRevision", "target" }),
  dex_entry=arraySet({ "modelRevision", "target" }),
  withdraw=arraySet({ "modelRevision", "target" }),
  deposit=arraySet({ "modelRevision", "target" }),
  release=arraySet({ "modelRevision", "target", "confirmationToken" }),
  select=arraySet({ "modelRevision", "target" }),
  change_box=arraySet({ "modelRevision", "boxIndex" }),
  cross_box_select=arraySet({ "modelRevision", "boxIndex" }),
  print_box=arraySet({ "modelRevision", "boxIndex" }),
  move=arraySet({ "modelRevision", "target", "destination" }),
  multi_select=arraySet({ "modelRevision", "target", "selected" }),
  clear_selection=arraySet({ "modelRevision", "selectionRevision" }),
  transfer_selected_to_pc=arraySet({
    "modelRevision", "selectionRevision",
  }),
  transfer_all_to_pc=arraySet({ "modelRevision", "scope" }),
  cancel=arraySet({ "modelRevision", "scope" }),
}

local function validateActionPayload(action, raw, currentRevision)
  local payload, why = cloneData(raw)
  if not payload then return nil, "unsafe-action-payload:" .. tostring(why) end
  -- The provider must echo the revision of the immutable snapshot it actually
  -- rendered. The manager verifies that view before adding reserved host/session
  -- bindings; silently substituting the newest revision would let stale pixels
  -- trigger an action against a different authoritative box state.
  if type(payload) ~= "table" or payload.modelRevision ~= currentRevision then
    return nil, "action-model-revision-mismatch"
  end
  local allowedPayload = ACTION_PAYLOAD_KEYS[action]
  if not allowedPayload then return nil, "action-payload-contract-missing" end
  local bounded, unexpected = onlyKeys(payload, allowedPayload)
  if not bounded then
    return nil, "unexpected-action-field:" .. tostring(unexpected)
  end
  for key in pairs(RESERVED_ACTION_FIELDS) do
    if payload[key] ~= nil then return nil, "reserved-action-field:" .. key end
  end
  if action == "navigate" then
    local directions = { up=true, down=true, left=true, right=true,
      page_prev=true, page_next=true }
    if not directions[payload.direction] then return nil, "action-direction-invalid" end
  elseif action == "inspect" or action == "dex_entry"
      or action == "withdraw" or action == "deposit"
      or action == "release" or action == "select" then
    if not validateLocation(payload.target, true) then
      return nil, "action-target-invalid"
    end
    if action == "release" and payload.confirmationToken ~= nil
       and not nonempty(payload.confirmationToken) then
      return nil, "action-confirmation-token-invalid"
    end
  elseif action == "change_box" or action == "cross_box_select"
      or action == "print_box" then
    if not integer(payload.boxIndex, 1) then return nil, "action-box-invalid" end
  elseif action == "move" then
    if not validateLocation(payload.target, true)
       or not validateLocation(payload.destination, false) then
      return nil, "action-move-invalid"
    end
  elseif action == "multi_select" then
    if not validateLocation(payload.target, true)
       or type(payload.selected) ~= "boolean" then
      return nil, "action-multi-select-invalid"
    end
  elseif action == "clear_selection"
      or action == "transfer_selected_to_pc" then
    if payload.selectionRevision ~= currentRevision then
      return nil, "action-selection-revision-mismatch"
    end
  elseif action == "transfer_all_to_pc" then
    if payload.scope ~= "withdrawable" then return nil, "action-scope-invalid" end
  elseif action == "cancel" then
    if payload.scope ~= nil and payload.scope ~= "prompt"
       and payload.scope ~= "surface" then return nil, "action-scope-invalid" end
  end
  payload.schema = PokemonUi.ACTION_SCHEMA
  payload.apiVersion = PokemonUi.API_VERSION
  return payload
end

local function validMessage(value)
  if value == nil then return true end
  return type(value) == "table" and nonempty(value.text)
    and (value.severity == "info" or value.severity == "warning"
      or value.severity == "error")
end

local ACTION_RESULT_KEYS = arraySet({
  "schema", "apiVersion", "host", "hostGeneration", "surface", "session",
  "action", "requestRevision", "status", "code", "model", "message",
  "confirmation", "details",
})

local function validateActionResult(raw, envelope, host, hostDef, currentRevision)
  local result, why = cloneData(raw)
  if not result then return nil, "unsafe-action-result:" .. tostring(why) end
  if type(result) ~= "table" or not onlyKeys(result, ACTION_RESULT_KEYS)
     or result.schema ~= hostDef.schemas.actionResult
     or result.schema ~= PokemonUi.ACTION_RESULT_SCHEMA then
    return nil, "action-result-schema-mismatch"
  end
  if result.apiVersion ~= PokemonUi.API_VERSION
     or result.host ~= host.id
     or result.hostGeneration ~= host.hostGeneration
     or result.surface ~= envelope.surface
     or result.session ~= envelope.session
     or result.action ~= envelope.action
     or result.requestRevision ~= currentRevision
     or not nonempty(result.code) then
    return nil, "action-result-binding-mismatch"
  end
  local status = result.status
  if status ~= "applied" and status ~= "rejected"
     and status ~= "confirmation_required" and status ~= "closed" then
    return nil, "action-result-status-invalid"
  end
  if not validMessage(result.message) then return nil, "action-result-message-invalid" end
  if status == "closed" then
    if result.model ~= nil or result.confirmation ~= nil then
      return nil, "closed-result-payload-forbidden"
    end
    return result, nil, true
  end
  local nextModel, modelErr = validateModel(
    result.model, host, envelope.surface, envelope.session, hostDef)
  if not nextModel then return nil, "action-result-model:" .. modelErr end
  if status == "applied" and nextModel.revision <= currentRevision then
    return nil, "applied-result-revision-not-advanced"
  end
  if status ~= "applied" and nextModel.revision < currentRevision then
    return nil, "action-result-revision-regressed"
  end
  if status == "confirmation_required" then
    local confirmation = result.confirmation
    if type(confirmation) ~= "table" or not nonempty(confirmation.token)
       or not nonempty(confirmation.prompt)
       or (confirmation.default ~= "yes" and confirmation.default ~= "no") then
      return nil, "action-result-confirmation-invalid"
    end
  elseif result.confirmation ~= nil then
    return nil, "action-result-confirmation-unexpected"
  end
  result.model = nextModel
  return result, nil, false
end

local function validateEvent(raw, event, host, surface, session, hostDef,
                            currentRevision)
  local envelope, why = cloneData(raw)
  if not envelope then return nil, "unsafe-event:" .. tostring(why) end
  local eventKeys = arraySet({
    "schema", "apiVersion", "host", "hostGeneration", "surface", "session",
    "type", "revision", "model", "message", "details",
  })
  if type(envelope) ~= "table" or not onlyKeys(envelope, eventKeys)
     or envelope.schema ~= hostDef.schemas.event
     or envelope.schema ~= PokemonUi.EVENT_SCHEMA then
    return nil, "event-schema-mismatch"
  end
  if envelope.apiVersion ~= PokemonUi.API_VERSION
     or envelope.host ~= host.id
     or envelope.hostGeneration ~= host.hostGeneration
     or envelope.surface ~= surface or envelope.session ~= session
     or envelope.type ~= event or not integer(envelope.revision, 0) then
    return nil, "event-binding-mismatch"
  end
  if event == "closed" then
    if envelope.model ~= nil or envelope.revision ~= currentRevision then
      return nil, "closed-event-revision-mismatch"
    end
    return envelope
  end
  if not validMessage(envelope.message) then return nil, "event-message-invalid" end
  local model, modelErr = validateModel(
    envelope.model, host, surface, session, hostDef)
  if not model then return nil, "event-model:" .. modelErr end
  if envelope.revision ~= model.revision
     or envelope.revision < currentRevision then
    return nil, "event-revision-mismatch"
  end
  envelope.model = model
  return envelope
end

local function validSessionReceipt(receipt, provider, host, surface, session,
                                  providerDef, hostDef)
  local claims = type(receipt) == "table" and receipt.claims or nil
  local schemas = type(receipt) == "table" and receipt.schemas or nil
  local modes = claims and sortedUnique(claims.modes)
  local actions = claims and sortedUnique(claims.actions)
  local events = claims and sortedUnique(claims.events)
  return type(receipt) == "table"
    and receipt.schema == PokemonUi.SESSION_SCHEMA
    and receipt.apiVersion == PokemonUi.API_VERSION
    and receipt.owner == provider.owner and receipt.provider == provider.id
    and receipt.host == host.id and receipt.hostOwner == host.owner
    and receipt.hostGeneration == host.hostGeneration
    and receipt.capabilityDigest == negotiatedCapabilityDigest(
      provider, host, surface, hostDef)
    and receipt.surface == surface and receipt.session == session
    and sameViewport(receipt.viewport, providerDef.viewport)
    and receipt.controllerGeneration == PokemonUi.CONTROLLER_GENERATION
    and receipt.complete == true and type(claims) == "table"
    and type(schemas) == "table" and schemasKnown(schemas)
    and schemasEqual(schemas, providerDef.schemas)
    and schemasEqual(schemas, hostDef.schemas)
    and claims.draw == "complete" and claims.input == "complete"
    and claims.commit == "atomic"
    and claims.selection == hostDef.claims.selection
    and modes ~= nil and actions ~= nil and events ~= nil
    and sameArray(modes, hostDef.modes)
    and sameArray(actions, hostDef.actions)
    and sameArray(events, hostDef.events)
end

local function removeActive(session)
  local entry = activeSessions[session]
  if not entry then return end
  activeSessions[session] = nil
  if activeSessionKeys[entry.key] == session then activeSessionKeys[entry.key] = nil end
end

local function wrapController(controller, receipt, life, provider, host,
                             surface, session, hostDef)
  local wrapped = { receipt=receipt, inputExclusive=true }
  life.wrapper, life.controller = wrapped, controller
  local negotiatedEvents = arraySet(hostDef.events)

  local function cleanup(reason)
    if life.cleaned then
      if life.cleanupOk == false then return false, life.failure end
      return true
    end
    life.cleaned = true
    local ok, result = pcall(controller.close, controller, reason)
    if not ok then
      life.failure = life.failure or "close:" .. tostring(result)
      life.cleanupOk = false
      return false, life.failure
    end
    if result == false then
      life.failure = life.failure or "close:incomplete"
      life.cleanupOk = false
      return false, life.failure
    end
    life.cleanupOk = true
    return true
  end

  function wrapped:_retire(reason, closeNow)
    if life.active then
      life.active = false
      life.failure = life.failure or reason
      removeActive(wrapped)
    end
    if closeNow and (life.inProviderCall or 0) == 0 then
      cleanup(reason)
    elseif not life.cleaned then
      life.cleanupPending = true
    end
    return true
  end

  local function afterProviderCall()
    life.inProviderCall = math.max(0, (life.inProviderCall or 1) - 1)
    if life.cleanupPending and not life.active and life.inProviderCall == 0 then
      life.cleanupPending = false
      cleanup(life.failure or "closed")
    end
  end

  local function fail(where, value)
    wrapped:_retire(where .. ":" .. tostring(value), true)
    return false, life.failure
  end

  function wrapped:isActive() return life.active end
  function wrapped:failure() return life.failure end

  function wrapped:draw(...)
    if not life.active then return false, life.failure or "session-not-active" end
    life.inProviderCall = (life.inProviderCall or 0) + 1
    local ok, result = pcall(controller.draw, controller, ...)
    afterProviderCall()
    if not ok then return fail("draw", result) end
    if result ~= true then return fail("draw", "incomplete") end
    return true
  end

  function wrapped:handleInput(input)
    if not life.active then return false, life.failure or "session-not-active" end
    local checked, inputErr = validateInputEnvelope(input)
    if not checked then return fail("handleInput", inputErr) end
    life.inProviderCall = (life.inProviderCall or 0) + 1
    local ok, a, b, c = pcall(controller.handleInput, controller, checked)
    afterProviderCall()
    if not ok then return fail("handleInput", a) end
    if type(a) ~= "boolean" then return fail("handleInput", "incomplete") end
    if not life.active then
      cleanup(life.failure or "closed")
      if life.failure then return false, life.failure end
    end
    -- false means the exclusive UI made no state change; it never hands the
    -- same input back to the native controller.
    return a, b, c
  end

  function wrapped:onEvent(event, envelope)
    if not life.active then return false, life.failure or "session-not-active" end
    if not negotiatedEvents[event] then return fail("onEvent", "not-negotiated") end
    local checked, why = validateEvent(envelope, event, host, surface, session,
      hostDef, life.revision)
    if not checked then return fail("onEvent", why) end
    if event == "closed" then
      -- Revoke backend dispatch before notifying provider code.
      wrapped:_retire(nil, false)
      life.inProviderCall = (life.inProviderCall or 0) + 1
      local ok, result = pcall(controller.onEvent, controller, event, checked)
      afterProviderCall()
      local cleanupOk, cleanupWhy = cleanup("closed")
      if not ok or result ~= true then
        life.failure = life.failure or "onEvent:" .. tostring(ok and "incomplete" or result)
        return false, life.failure
      end
      if not cleanupOk then return false, cleanupWhy end
      return true
    end
    life.revision = checked.model.revision
    life.inProviderCall = (life.inProviderCall or 0) + 1
    local ok, result = pcall(controller.onEvent, controller, event, checked)
    afterProviderCall()
    if not ok then return fail("onEvent", result) end
    if result ~= true then return fail("onEvent", "incomplete") end
    return true
  end

  function wrapped:update(...)
    if not life.active then return false, life.failure or "session-not-active" end
    if type(controller.update) ~= "function" then return true end
    life.inProviderCall = (life.inProviderCall or 0) + 1
    local ok, result = pcall(controller.update, controller, ...)
    afterProviderCall()
    if not ok then return fail("update", result) end
    if result ~= nil and type(result) ~= "boolean" then
      return fail("update", "incomplete")
    end
    return result == nil and true or result
  end

  function wrapped:close(reason)
    if life.active then wrapped:_retire(nil, false) end
    local ok, why = cleanup(reason)
    if not ok then return false, why end
    return true
  end
  return wrapped
end

function PokemonUi.begin(handle, request)
  local host = validHostHandle(handle)
  local surface = type(request) == "table" and request.surface or nil
  local session = type(request) == "table" and request.session or nil
  if not host then
    return nil, fallback(surface, session, nil,
      "invalid-or-stale-host-handle")
  end
  if not PokemonUi.REQUIREMENTS[surface] or not nonempty(session) then
    return nil, fallback(surface, session, nil, "invalid-session-request", host)
  end
  local hostDef = host.surfaces[surface]
  if not hostDef then
    return nil, fallback(surface, session, nil,
      "host-does-not-support-surface", host)
  end
  if request.controllerGeneration ~= PokemonUi.CONTROLLER_GENERATION then
    return nil, fallback(surface, session, nil,
      "controller-generation-mismatch", host)
  end
  if request.atomicLayer ~= true then
    return nil, fallback(surface, session, nil,
      "host-atomic-layer-required", host)
  end
  local resolved = PokemonUi.resolve(surface, handle)
  if resolved.effective == PokemonUi.GAME_DEFAULT then
    return nil, fallback(surface, session, resolved.requested,
      resolved.reason, host)
  end
  local provider = providers[resolved.effective]
  local providerDef = provider and provider.surfaces[surface]
  if not providerDef or not compatible(provider, host, surface) then
    return nil, fallback(surface, session, resolved.requested,
      "provider-host-incompatible", host)
  end
  local actions, actionErr = validateCallbacks(hostDef, request.actions)
  if not actions then
    return nil, fallback(surface, session, resolved.requested, actionErr, host)
  end
  local events, eventErr = validateEvents(hostDef, request.events)
  if not events then
    return nil, fallback(surface, session, resolved.requested, eventErr, host)
  end
  local initialModel, modelErr = validateModel(
    request.model, host, surface, session, hostDef)
  if not initialModel then
    return nil, fallback(surface, session, resolved.requested,
      "invalid-model:" .. tostring(modelErr), host)
  end
  local sessionKey = host.id .. "\0" .. surface .. "\0" .. session
  if activeSessionKeys[sessionKey] then
    return nil, fallback(surface, session, resolved.requested,
      "duplicate-active-session", host)
  end

  local life = {
    active=false, cleaned=false, cleanupPending=false,
    inProviderCall=0, revision=initialModel.revision,
  }
  local providerModel = assert(cloneData(initialModel))
  local allowed = arraySet(hostDef.actions)
  local context = {
    schema=PokemonUi.SESSION_SCHEMA, apiVersion=PokemonUi.API_VERSION,
    surface=surface, session=session,
    controllerGeneration=PokemonUi.CONTROLLER_GENERATION,
    owner=provider.owner, provider=provider.id,
    host=host.id, hostOwner=host.owner, hostGeneration=host.hostGeneration,
    schemas={
      model=hostDef.schemas.model, action=hostDef.schemas.action,
      actionResult=hostDef.schemas.actionResult, event=hostDef.schemas.event,
    },
    capabilityDigest=negotiatedCapabilityDigest(
      provider, host, surface, hostDef),
    viewport=copyViewport(providerDef.viewport),
    atomicLayer=true, inputExclusive=true,
    selection=hostDef.claims.selection,
    modes=copyArray(hostDef.modes),
    actions=copyArray(hostDef.actions), events=copyArray(events),
    model=providerModel,
  }
  context.dispatch = function(action, payload)
    if not life.active then return false, "session-not-active" end
    if not allowed[action] then return false, "action-not-negotiated" end
    local checked, payloadErr = validateActionPayload(
      action, payload, life.revision)
    if not checked then
      if life.wrapper then life.wrapper:_retire(
        "dispatch:" .. payloadErr, life.inProviderCall == 0) end
      return nil, "dispatch:" .. payloadErr
    end
    checked.host, checked.hostGeneration = host.id, host.hostGeneration
    checked.surface, checked.session, checked.action = surface, session, action
    local callbackEnvelope = assert(cloneData(checked))
    local ok, result = pcall(actions[action], callbackEnvelope)
    if not ok then
      if life.wrapper then
        life.wrapper:_retire("dispatch:backend-error:" .. tostring(result),
          life.inProviderCall == 0)
      end
      return nil, "dispatch:backend-error:" .. tostring(result)
    end
    local accepted, resultErr, closes = validateActionResult(
      result, checked, host, hostDef, life.revision)
    if not accepted then
      if life.wrapper then
        life.wrapper:_retire("dispatch:" .. resultErr,
          life.inProviderCall == 0)
      end
      return nil, "dispatch:" .. resultErr
    end
    if closes then
      if life.wrapper then life.wrapper:_retire(nil,
        life.inProviderCall == 0) end
    else
      life.revision = accepted.model.revision
    end
    return accepted
  end

  local ok, controller = pcall(providerDef.create, context)
  if not ok or type(controller) ~= "table" then
    return nil, fallback(surface, session, resolved.requested,
      "provider-create-error:" .. tostring(controller), host)
  end
  if type(controller.draw) ~= "function"
     or type(controller.handleInput) ~= "function"
     or type(controller.onEvent) ~= "function"
     or type(controller.close) ~= "function"
     or not validSessionReceipt(controller.receipt, provider, host, surface,
       session, providerDef, hostDef) then
    if type(controller.close) == "function" then
      pcall(controller.close, controller, "invalid-session-controller-receipt")
    end
    return nil, fallback(surface, session, resolved.requested,
      "invalid-session-controller-receipt", host)
  end
  life.active = true
  local publicReceipt = assert(cloneData(controller.receipt))
  local wrapped = wrapController(controller, publicReceipt, life,
    provider, host, surface, session, hostDef)
  activeSessions[wrapped] = {
    provider=provider, host=host, key=sessionKey,
  }
  activeSessionKeys[sessionKey] = wrapped
  return wrapped, publicReceipt
end

function PokemonUi.public()
  local requirements = {}
  for surface in pairs(PokemonUi.REQUIREMENTS) do
    requirements[surface] = publicRequirement(surface)
  end
  return {
    schema=PokemonUi.PROVIDER_SCHEMA,
    providerSchema=PokemonUi.PROVIDER_SCHEMA,
    hostSchema=PokemonUi.HOST_SCHEMA,
    sessionSchema=PokemonUi.SESSION_SCHEMA,
    modelSchema=PokemonUi.MODEL_SCHEMA,
    actionSchema=PokemonUi.ACTION_SCHEMA,
    actionResultSchema=PokemonUi.ACTION_RESULT_SCHEMA,
    eventSchema=PokemonUi.EVENT_SCHEMA,
    apiVersion=PokemonUi.API_VERSION,
    controllerGeneration=PokemonUi.CONTROLLER_GENERATION,
    hostGeneration=PokemonUi.HOST_GENERATION,
    capabilityDigestSchema=PokemonUi.CAPABILITY_DIGEST_SCHEMA,
    optionKeys={
      global=PokemonUi.GLOBAL_KEY,
      pcBox=PokemonUi.SURFACE_KEYS.pc_box,
      legacyBank=PokemonUi.SURFACE_KEYS.legacy_bank,
      battleParty=PokemonUi.SURFACE_KEYS.battle_party,
    },
    ids={
      ascBox="asc_box", orasGlass="oras_glass",
      gameDefault=PokemonUi.GAME_DEFAULT, kascFrlg="kasc_frlg",
      followGlobal=PokemonUi.FOLLOW_GLOBAL,
    },
    requirements=requirements,
    transactionalDraw=PokemonUi.TRANSACTIONAL_DRAW,
    inputOwnership="exclusive_after_accept",
    inputKeys=copyArray(PokemonUi.INPUT_KEYS),
    viewportBounds={ maxDimension=PokemonUi.MAX_VIEWPORT_DIMENSION,
      maxPixels=PokemonUi.MAX_VIEWPORT_PIXELS },
    register=PokemonUi.register,
    registerHost=PokemonUi.registerHost,
    listHosts=PokemonUi.listHosts,
    list=PokemonUi.list,
    resolve=PokemonUi.resolve,
    begin=PokemonUi.begin,
  }
end

return PokemonUi
