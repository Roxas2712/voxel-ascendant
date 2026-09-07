-- Generation-neutral public battle-overlay receipt builder.
--
-- A companion may need to know whether VASC already committed the status HUD
-- for one exact battle/deployment/frame. It must never receive the renderer's
-- mutable shot, Canvas, BattleState owner table or private control functions.
-- This factory keeps those values behind an injected snapshot callback and
-- publishes primitive identity tokens only.

local Public = {
  API_VERSION = 1,
  SCHEMA = "ascendant.battle-overlay/v1",
  RECEIPT_SCHEMA = "ascendant.battle-overlay-receipt/v1",
  SURFACE = "status_hud",
}

local function positiveInteger(value)
  return type(value) == "number" and value >= 1 and value % 1 == 0
end

local function nonNegativeInteger(value)
  return type(value) == "number" and value >= 0 and value % 1 == 0
end

local function primitiveReason(value, fallback)
  if type(value) == "string" and value ~= "" then return value end
  if type(value) == "number" or type(value) == "boolean" then
    return tostring(value)
  end
  return fallback
end

local function validLifecycle(value, generation)
  return type(value) == "table"
    and rawget(value, "schema") == "ascendant.battle-context/v1"
    and rawget(value, "apiVersion") == 1
    and rawget(value, "generation") == generation
    and positiveInteger(rawget(value, "battleToken"))
    and nonNegativeInteger(rawget(value, "deploymentToken"))
    and type(rawget(value, "provider")) == "string"
    and rawget(value, "provider") ~= ""
    -- created/replacing/native_latched are deliberately not presentation
    -- commits.  In particular, replacing may still expose the preceding HUD
    -- receipt until the new deployment publishes its first complete frame.
    and rawget(value, "state") == "active"
end

local function validFrame(value)
  -- OverworldBattle shots are private mutable tables.  A boolean or scalar
  -- can never identify a committed renderer frame.
  return type(value) == "table"
end

function Public.new(options)
  options = options or {}
  local generation = tonumber(options.generation)
  local ownerId = options.owner
  local lifecycle = options.lifecycle
  local snapshot = options.snapshot
  local currentFrame = options.currentFrame
  local snapshotSchema = options.snapshotSchema

  if not positiveInteger(generation) then
    return nil, "battle overlay generation must be a positive integer"
  end
  if type(ownerId) ~= "string" or ownerId == "" then
    return nil, "battle overlay owner must be a non-empty string"
  end
  if type(lifecycle) ~= "table"
      or type(lifecycle.current) ~= "function"
      or type(lifecycle.health) ~= "function" then
    return nil, "battle overlay lifecycle capability is unavailable"
  end
  if type(snapshot) ~= "function" then
    return nil, "battle overlay snapshot callback is unavailable"
  end
  if type(currentFrame) ~= "function" then
    return nil, "battle overlay current-frame callback is unavailable"
  end
  if type(snapshotSchema) ~= "string" or snapshotSchema == "" then
    return nil, "battle overlay snapshot schema is required"
  end
  -- Capture trusted callbacks once. A mutable capability table cannot swap an
  -- executable seam between validation and invocation.
  local lifecycleCurrent = lifecycle.current
  local lifecycleHealth = lifecycle.health

  local state = {
    retired=false,
    frameSerial=0,
    lastBattleToken=nil,
    lastDeploymentToken=nil,
    lastShot=nil,
    calls=0,
    commits=0,
    invalidSnapshots=0,
    lastError=nil,
    lease=1,
  }

  local function resetFrameIdentity()
    state.lastBattleToken = nil
    state.lastDeploymentToken = nil
    state.lastShot = nil
  end

  local function current(battle)
    state.calls = state.calls + 1
    if state.retired then
      state.lastError = "battle overlay capability is retired"
      return nil, state.lastError
    end
    if battle == nil then
      state.lastError = "battle overlay exact owner is required"
      return nil, state.lastError
    end
    local lease = state.lease
    local function live()
      return not state.retired and state.lease == lease
    end

    local okLifecycle, lifecycleReceipt = pcall(lifecycleCurrent, battle)
    if not live() then
      return nil, "battle overlay capability is retired"
    end
    if not okLifecycle or not validLifecycle(lifecycleReceipt, generation) then
      state.lastError = okLifecycle
        and "battle lifecycle has no exact committed owner"
        or "battle lifecycle current callback failed"
      return nil, state.lastError
    end

    local okFrame, frame = pcall(currentFrame, battle)
    if not live() then
      return nil, "battle overlay capability is retired"
    end
    if not okFrame then
      state.invalidSnapshots = state.invalidSnapshots + 1
      state.lastError = "battle overlay current-frame callback failed"
      return nil, state.lastError
    end
    local frameValid = frame == nil or validFrame(frame)
    if not frameValid then
      state.invalidSnapshots = state.invalidSnapshots + 1
      state.lastError = "battle overlay current frame is malformed"
    end

    local okSnapshot, raw = pcall(snapshot, battle)
    if not live() then
      return nil, "battle overlay capability is retired"
    end
    if not okSnapshot then
      state.invalidSnapshots = state.invalidSnapshots + 1
      state.lastError = "battle overlay snapshot callback failed"
      raw = nil
    end

    -- Snapshot receipts are mutable renderer internals. Read their primitive
    -- fields with rawget so a hostile/stale metatable cannot execute after the
    -- last retirement lease check and resurrect a committed claim.
    local rawSchema, rawSnapped, rawShot, rawOwner, rawReason
    if type(raw) == "table" then
      rawSchema = rawget(raw, "schema")
      rawSnapped = rawget(raw, "snapped")
      rawShot = rawget(raw, "shot")
      rawOwner = rawget(raw, "owner")
      rawReason = rawget(raw, "reason")
    end
    local snapshotValid = type(raw) == "table"
      and rawSchema == snapshotSchema
      and type(rawSnapped) == "boolean"
      and (rawShot == nil or validFrame(rawShot))
    if raw ~= nil and not snapshotValid then
      state.invalidSnapshots = state.invalidSnapshots + 1
      state.lastError = "battle overlay snapshot receipt is malformed"
    end

    local shot = snapshotValid and rawShot or nil
    local candidateOwner = snapshotValid
      and type(rawOwner) == "string" and rawOwner ~= ""
      and rawOwner or nil
    local committed = snapshotValid and rawSnapped == true
      and frameValid and validFrame(frame) and validFrame(shot)
      and rawequal(shot, frame) and candidateOwner ~= nil
    local presentationOwner = committed and candidateOwner or nil

    local battleToken = rawget(lifecycleReceipt, "battleToken")
    local deploymentToken = rawget(lifecycleReceipt, "deploymentToken")
    local provider = rawget(lifecycleReceipt, "provider")
    if state.lastBattleToken ~= battleToken
        or state.lastDeploymentToken ~= deploymentToken
        or not rawequal(state.lastShot, frame) then
      state.frameSerial = state.frameSerial + 1
      state.lastBattleToken = battleToken
      state.lastDeploymentToken = deploymentToken
      state.lastShot = frame
    end
    if committed then
      state.commits = state.commits + 1
      state.lastError = nil
    elseif snapshotValid then
      if rawSnapped == true and validFrame(shot) and validFrame(frame)
          and not rawequal(shot, frame) then
        state.lastError = "status HUD receipt does not match current frame"
      elseif not frameValid then
        state.lastError = "battle overlay current frame is malformed"
      else
        state.lastError = primitiveReason(rawReason, "status HUD is uncommitted")
      end
    elseif raw == nil and state.lastError == nil then
      state.lastError = "status HUD has no frame receipt"
    end

    return {
      schema=Public.RECEIPT_SCHEMA,
      apiVersion=Public.API_VERSION,
      generation=generation,
      owner=ownerId,
      battleToken=battleToken,
      deploymentToken=deploymentToken,
      frameToken=state.frameSerial,
      provider=provider,
      presentationOwner=presentationOwner,
      committed=committed,
      exclusive=committed,
      surfaces=committed and { Public.SURFACE } or {},
      reason=committed and nil or state.lastError,
    }
  end

  local service = {
    schema=Public.SCHEMA,
    apiVersion=Public.API_VERSION,
    owner=ownerId,
    generation=generation,
    receiptSchema=Public.RECEIPT_SCHEMA,
    surfaces={ Public.SURFACE },
    current=current,
    health=function()
      if state.retired then
        return {
          schema="ascendant.compat-status/v1",
          apiVersion=Public.API_VERSION,
          ok=false,
          state="retired",
          generation=generation,
          calls=state.calls,
          commits=state.commits,
          invalidSnapshots=state.invalidSnapshots,
          lastError=state.lastError,
          lifecycleOK=false,
        }
      end
      local okHealth, lifecycleHealthReceipt = pcall(lifecycleHealth)
      local lifecycleOK = okHealth and type(lifecycleHealthReceipt) == "table"
        and rawget(lifecycleHealthReceipt, "ok") == true
      return {
        schema="ascendant.compat-status/v1",
        apiVersion=Public.API_VERSION,
        ok=not state.retired and lifecycleOK,
        state=state.retired and "retired" or "active",
        generation=generation,
        calls=state.calls,
        commits=state.commits,
        invalidSnapshots=state.invalidSnapshots,
        lastError=state.lastError,
        lifecycleOK=lifecycleOK,
      }
    end,
  }

  local control = {
    retire=function()
      if state.retired then return true end
      state.retired = true
      state.lease = state.lease + 1
      state.lastError = "battle overlay capability is retired"
      resetFrameIdentity()
      return true
    end,
  }
  return service, control
end

return Public
