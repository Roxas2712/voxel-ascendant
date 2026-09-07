-- Owner-scoped, generation-neutral event bus for RC11 card modules.
--
-- Listeners are ordered deterministically (higher priority first, then their
-- subscription order).  One broken listener cannot prevent later listeners
-- from running.  Every subscription has both an explicit token and an
-- idempotent unsubscribe function, while deactivateOwner removes all hooks
-- belonging to a card during rollback or deactivation.

local Hooks = {}
Hooks.__index = Hooks

local function validName(value)
  return type(value) == "string" and value ~= ""
    and value:match("^[%a%d][%a%d%._:/%-]*$") ~= nil
end

local function validPriority(value)
  return type(value) == "number" and value == value
    and value ~= math.huge and value ~= -math.huge
end

local function listenerBefore(a, b)
  if a.priority ~= b.priority then return a.priority > b.priority end
  return a.sequence < b.sequence
end

-- Public hook payloads are data receipts, never shared owner tables.  Clone
-- once at the emission boundary and once per listener so neither the emitter
-- nor an earlier listener can mutate what a later Card observes.
local function copyPayload(value, seen)
  local kind = type(value)
  if kind == "number" then
    if value ~= value or value == math.huge or value == -math.huge then
      error("hook payload contains a non-finite number", 0)
    end
    return value
  end
  if kind == "nil" or kind == "boolean" or kind == "string" then
    return value
  end
  if kind ~= "table" then
    error("hook payload contains unsupported " .. kind .. " value", 0)
  end
  seen = seen or {}
  if seen[value] then error("hook payload contains a cyclic table", 0) end
  seen[value] = true
  local result = {}
  for key, item in pairs(value) do
    local keyKind = type(key)
    if keyKind ~= "string" and keyKind ~= "number"
        and keyKind ~= "boolean" then
      error("hook payload contains unsupported " .. keyKind .. " key", 0)
    end
    result[key] = copyPayload(item, seen)
  end
  seen[value] = nil
  return result
end

function Hooks.new(options)
  options = options or {}
  return setmetatable({
    nextToken=0,
    nextSequence=0,
    listeners={},
    owners={},
    failureCount=0,
    invalidPayloadCount=0,
    onError=type(options.onError) == "function" and options.onError or nil,
  }, Hooks)
end

function Hooks:subscribe(event, owner, callback, priority)
  if not validName(event) then return nil, "event must be a non-empty hook name" end
  if not validName(owner) then return nil, "owner must be a non-empty hook owner" end
  if type(callback) ~= "function" then return nil, "callback must be a function" end
  priority = priority == nil and 0 or priority
  if not validPriority(priority) then return nil, "priority must be a finite number" end

  self.nextToken = self.nextToken + 1
  self.nextSequence = self.nextSequence + 1
  local token = self.nextToken
  local listener = {
    token=token,
    event=event,
    owner=owner,
    callback=callback,
    priority=priority,
    sequence=self.nextSequence,
    active=true,
  }
  self.listeners[token] = listener
  self.owners[owner] = self.owners[owner] or {}
  self.owners[owner][token] = true

  local function unsubscribe()
    return self:unsubscribe(token)
  end
  return token, unsubscribe
end

function Hooks:unsubscribe(token)
  local listener = self.listeners[token]
  if not listener then return false end
  listener.active = false
  self.listeners[token] = nil
  local owned = self.owners[listener.owner]
  if owned then
    owned[token] = nil
    if next(owned) == nil then self.owners[listener.owner] = nil end
  end
  return true
end

function Hooks:deactivateOwner(owner)
  local owned = self.owners[owner]
  if not owned then return 0 end
  local tokens = {}
  for token in pairs(owned) do tokens[#tokens + 1] = token end
  local removed = 0
  for _, token in ipairs(tokens) do
    if self:unsubscribe(token) then removed = removed + 1 end
  end
  return removed
end

function Hooks:emit(event, payload)
  if not validName(event) then
    return { event=event, delivered=0, errors={ "invalid event name" } }
  end
  local payloadOK, boundaryPayload = pcall(copyPayload, payload)
  if not payloadOK then
    self.invalidPayloadCount = self.invalidPayloadCount + 1
    return {
      event=event,
      delivered=0,
      errors={{ owner="emitter", error=tostring(boundaryPayload) }},
    }
  end
  local snapshot = {}
  for _, listener in pairs(self.listeners) do
    if listener.event == event and listener.active then
      snapshot[#snapshot + 1] = listener
    end
  end
  table.sort(snapshot, listenerBefore)

  local report = { event=event, delivered=0, errors={} }
  for _, listener in ipairs(snapshot) do
    -- A listener removed by an earlier callback in the same dispatch does not
    -- receive the event. Newly registered listeners wait for the next emit.
    if listener.active and self.listeners[listener.token] == listener then
      local ok, result = pcall(listener.callback, copyPayload(boundaryPayload), {
        event=event,
        owner=listener.owner,
        token=listener.token,
      })
      if ok then
        report.delivered = report.delivered + 1
      else
        self.failureCount = self.failureCount + 1
        local failure = {
          owner=listener.owner,
          token=listener.token,
          error=tostring(result),
        }
        report.errors[#report.errors + 1] = failure
        if self.onError then
          -- Diagnostics are isolated too; reporting must never break dispatch.
          local copied, diagnostic = pcall(copyPayload, failure)
          if copied then pcall(self.onError, event, diagnostic) end
        end
      end
    end
  end
  return report
end

function Hooks:health()
  local listeners, owners = 0, 0
  for _ in pairs(self.listeners) do listeners = listeners + 1 end
  for _ in pairs(self.owners) do owners = owners + 1 end
  return {
    listeners=listeners,
    owners=owners,
    listenerFailures=self.failureCount,
    invalidPayloads=self.invalidPayloadCount,
  }
end

return Hooks
