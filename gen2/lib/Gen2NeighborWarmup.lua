-- Progressive adapter gate for Gen-2 connected maps.
--
-- Map.new + the edition-colour atlas are complete-map operations. Doing that
-- for every connected/open-world map before the current BODY is presented
-- turns an otherwise asynchronous mesher into a multi-second synchronous
-- first frame. This helper admits only complete adapter records and advances a
-- bounded number per presented frame.

local Warmup = {}

local function signatureFor(specs)
  local out = {}
  for index, spec in ipairs(specs or {}) do
    out[index] = table.concat({
      tostring(spec and spec.id or ""),
      tostring(spec and spec.dir or ""),
      tostring(tonumber(spec and spec.depth) or 1),
      tostring(tonumber(spec and spec.ox) or 0),
      tostring(tonumber(spec and spec.oy) or 0),
      tostring(spec and spec.parentId or ""),
    }, "\31")
  end
  return table.concat(out, "\30")
end

local function reset(state, rootId, maps, openWorld, specs, signature)
  state.rootId = rootId
  state.maps = maps
  state.openWorld = openWorld == true
  state.specs = specs or {}
  state.signature = signature or signatureFor(state.specs)
  state.out = {}
  state.byId = {}
  state.direct = {}
  state.failures = {}
  state.failureById = {}
  state.pendingDirect = {}
  state.pendingFar = {}
  for index, spec in ipairs(state.specs) do
    local queue = (tonumber(spec.depth) or 1) <= 1
      and state.pendingDirect or state.pendingFar
    queue[#queue + 1] = index
  end
  state.next = 1
end

local function directComplete(state)
  return #(state.pendingDirect or {}) == 0
end

local function rememberFailure(state, spec, message)
  local id = tostring(spec and spec.id or "?")
  message = tostring(message or "neighbour adapter declined")
  if state.failureById[id] == message then return end
  state.failureById[id] = message
  state.failures[#state.failures + 1] = { id = spec and spec.id, error = message }
end

local function attemptOne(state, build)
  -- Real immediate connections are a hard residency promise. A temporarily
  -- unavailable Map/tileset adapter is rotated behind its siblings and tried
  -- again on a later frame; consuming it once would incorrectly report the
  -- direct ring complete and permanently leave a seam cold. Far OPEN WORLD
  -- entries retain the historical best-effort behaviour after that ring.
  local direct = #(state.pendingDirect or {}) > 0
  local queue = direct and state.pendingDirect or state.pendingFar
  if #queue == 0 then return false end
  local specIndex = table.remove(queue, 1)
  local spec = state.specs[specIndex]
  local ok, rec, err = pcall(build, spec)
  if ok and type(rec) == "table" and rec.id and rec.map then
    state.out[#state.out + 1] = rec
    state.byId[rec.id] = rec
    state.failureById[tostring(rec.id)] = nil
    if (tonumber(rec.depth) or tonumber(spec and spec.depth) or 1) <= 1 then
      state.direct[#state.direct + 1] = rec
    end
  else
    rememberFailure(state, spec, ok and err or rec)
    if direct then queue[#queue + 1] = specIndex end
  end
  state.next = (tonumber(state.next) or 1) + 1
  return true
end

function Warmup.advance(state, rootId, maps, openWorld, specs, build, limit)
  if type(state) ~= "table" or type(build) ~= "function" then
    return {}, {}, {}, false, "invalid Gen-2 neighbour warmup input"
  end
  local signature = signatureFor(specs)
  if state.rootId ~= rootId or state.maps ~= maps
      or state.openWorld ~= (openWorld == true)
      or state.signature ~= signature then
    reset(state, rootId, maps, openWorld, specs, signature)
  end

  -- This is an adapter-attempt budget, not a throughput hint. Map.new plus
  -- atlas binding is whole-map synchronous work, so even an overeager caller
  -- can never raise the per-frame cap above one.
  limit = math.min(1, math.max(0, math.floor(tonumber(limit) or 1)))
  local built = 0
  while built < limit and attemptOne(state, build) do
    built = built + 1
  end

  return state.out, state.byId, state.direct, directComplete(state), nil,
    #(state.pendingDirect or {}) == 0 and #(state.pendingFar or {}) == 0
end

function Warmup.reset(state)
  if type(state) ~= "table" then return false end
  reset(state, nil, nil, false, {}, "")
  return true
end

return Warmup
