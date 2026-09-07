-- Keep a cold voxel destination behind the engine's real warp midpoint until
-- its first complete 3D frame exists. Desktop keeps that atomic contract;
-- iOS/Android fail open to the engine's native 2D world after a bounded wait
-- so an unfinished mobile voxel frame can never strand the loading screen.
--
-- New engines expose render_pipelines.revealReady directly.  Gen1Recomp
-- 0.1.90 predates that optional field, so adding it unconditionally would make
-- the whole VASC pipeline record fail schema validation.  VASC already
-- declares engine_internals for its renderer integration; on that supported
-- baseline this module installs the same one-condition handshake as a narrow,
-- idempotent Transition.update wrapper instead.

local V = ...

local TransitionReveal = {}

local MARKER = "__voxelAscendantRevealGateV1"
local ENGINE_MARKER = "__voxelAscendantRevealEngineGateV1"
local COMPAT_VERSION = 4
local ENGINE_GATE_VERSION = 1
local MOBILE_TIMEOUT_SECONDS = 2.5
local MOBILE_TIMEOUT_FRAMES = 150

local function runtimeOS()
  local loveRuntime = rawget(_G, "love")
  if type(loveRuntime) ~= "table" then return nil end
  if type(loveRuntime._os) == "string" then return loveRuntime._os end
  local getOS = loveRuntime.system and loveRuntime.system.getOS
  if type(getOS) ~= "function" then return nil end
  local ok, value = pcall(getOS)
  if ok and type(value) == "string" then return value end
  return nil
end

local RUNTIME_OS = runtimeOS()
local MOBILE_RUNTIME = RUNTIME_OS == "iOS" or RUNTIME_OS == "Android"

local MobileDiagnostic = V and V.mod and V.mod._vascMobileDiagnostic or nil
local function mobileDiagnostic(name, ...)
  local fn = MobileDiagnostic and MobileDiagnostic[name]
  if type(fn) ~= "function" then return nil end
  local ok, a, b = pcall(fn, ...)
  if ok then return a, b end
  return nil
end

local function pack(...)
  return { n = select("#", ...), ... }
end

local function ownsWorld(Pipelines)
  if type(Pipelines) ~= "table" or type(Pipelines.worldPipeline) ~= "function" then
    return false
  end
  local ok, id = pcall(Pipelines.worldPipeline)
  return ok and id == "voxel"
end

local function clockNow()
  local loveRuntime = rawget(_G, "love")
  local getTime = type(loveRuntime) == "table" and loveRuntime.timer
                  and loveRuntime.timer.getTime
  if type(getTime) ~= "function" then return nil end
  local ok, value = pcall(getTime)
  if ok and type(value) == "number" and value == value then return value end
  return nil
end

local function newMobileGate()
  return {
    map = nil,
    startedAt = nil,
    probes = 0,
    released = false,
    marked = false,
  }
end

local directMobileGate = newMobileGate()

local function resetMobileGate(gate, map, now)
  gate.map = map
  gate.startedAt = now
  gate.probes = 0
  gate.released = false
  gate.marked = false
end

local function mapLabel(map)
  if type(map) == "table" then
    for _, key in ipairs({ "id", "name", "mapId" }) do
      local value = rawget(map, key)
      if value ~= nil then return tostring(value) end
    end
  end
  return tostring(map)
end

local function markMobileFailOpen(gate, map, elapsed, route, fallbackBy)
  if gate.marked then return end
  gate.marked = true
  local caller = "gen1-TransitionReveal." .. tostring(route or "unknown")
  local fields = {
    caller = caller,
    context = "world",
    reason = "mobile-transition-reveal-timeout",
    status = "FALLBACK",
    mapId = mapLabel(map),
    elapsedSeconds = elapsed,
    probeCount = gate.probes,
    timeoutSeconds = MOBILE_TIMEOUT_SECONDS,
    timeoutFrames = MOBILE_TIMEOUT_FRAMES,
    fallbackBy = fallbackBy,
    fallback = "native-2d",
  }
  -- fallback() preserves the ordinary mobile diagnostic classification;
  -- the following named boundary leaves an unambiguous last checkpoint for
  -- screenshots/snapshots from a phone with no filesystem access.
  mobileDiagnostic("fallback", caller, fields.reason, "native-2d", fields)
  mobileDiagnostic("checkpoint", "transition-reveal-mobile-fail-open", {
    code = "D11",
    caller = caller,
    context = fields.context,
    reason = fields.reason,
    status = fields.status,
    mapId = fields.mapId,
    elapsedSeconds = fields.elapsedSeconds,
    probeCount = fields.probeCount,
    timeoutSeconds = fields.timeoutSeconds,
    timeoutFrames = fields.timeoutFrames,
    fallbackBy = fields.fallbackBy,
    fallback = fields.fallback,
  })
end

local function mobileRevealReady(gate, map, sceneReady, route)
  gate = gate or directMobileGate
  local now = clockNow()
  if gate.map ~= map then resetMobileGate(gate, map, now) end

  -- A successful atomic scene handoff is final for this exact map. If a
  -- later hot reload invalidates its meshes while the same transition is
  -- completing, never put an already-approved destination back behind black.
  if sceneReady then
    gate.released = true
    return true
  end
  if gate.released then return true end

  gate.probes = gate.probes + 1
  if gate.startedAt == nil and now ~= nil then gate.startedAt = now end

  local elapsed
  if now ~= nil and gate.startedAt ~= nil then
    if now < gate.startedAt then
      -- A reset/replaced timer is a new trustworthy origin, not an instant
      -- timeout. The frame counter remains available if the clock disappears.
      gate.startedAt = now
    end
    elapsed = now - gate.startedAt
  end
  local timedOut = elapsed ~= nil and elapsed >= MOBILE_TIMEOUT_SECONDS
  local frameTimedOut = elapsed == nil
                        and gate.probes >= MOBILE_TIMEOUT_FRAMES
  if not timedOut and not frameTimedOut then return false end

  gate.released = true
  markMobileFailOpen(gate, map, elapsed, route,
    timedOut and "timer" or "frame-fallback")
  return true
end

local function readyNow(Pipelines, Game, requireOwner, gate, route)
  -- The compatibility wrapper lives on the shared Transition class, so it
  -- must explicitly leave every other renderer's fade untouched.  The native
  -- engine hook already dispatches only the selected pipeline's callback.
  if requireOwner and not ownsWorld(Pipelines) then return true end
  local ow = Game and Game.overworld
  if not (ow and ow.map) then
    if MOBILE_RUNTIME and gate then resetMobileGate(gate, nil, nil) end
    return true
  end
  local map = ow.map
  local okScene, Scene = pcall(V.require, "VoxelScene")
  local ready = true
  if okScene and type(Scene) == "table"
      and type(Scene.readyForReveal) == "function" then
    local okReady, value = pcall(Scene.readyForReveal, ow)
    if okReady then ready = value == true end
  end
  if not MOBILE_RUNTIME then return ready end
  return mobileRevealReady(gate, map, ready, route)
end

local function supportsEngineHook(Pipelines, Schemas)
  local registry = Schemas and Schemas.REGISTRIES
                   and Schemas.REGISTRIES.render_pipelines
  return type(Pipelines) == "table"
         and type(Pipelines.worldRevealReady) == "function"
         and registry ~= nil and type(registry.fields) == "table"
         and registry.fields.revealReady ~= nil
end

local function installCompat(Pipelines, Game, Transition)
  if type(Transition) ~= "table" or type(Transition.update) ~= "function" then
    error("VOXEL_ASCENDANT: Gen1Recomp Transition.update is unavailable", 0)
  end

  local inheritedPending, inheritedMobileGate
  local state = rawget(Transition, MARKER)
  if type(state) == "table" and state.owner == V.mod.id then
    -- Hot reload may create a new V/Scene closure. Update only the predicate;
    -- never wrap the already-wrapped method a second time.
    state.owns = function()
      return ownsWorld(Pipelines)
    end
    state.ready = function()
      return readyNow(Pipelines, Game, true, state.mobileGate, "compat")
    end
    if state.version == COMPAT_VERSION and type(state.pending) == "table"
        and type(state.mobileGate) == "table" then
      return state.wrapper
    end
    -- Upgrade an older compatibility wrapper without stacking it. Every
    -- version retains the untouched engine method for this idempotent unwind.
    if Transition.update ~= state.wrapper or type(state.original) ~= "function" then
      error("VOXEL_ASCENDANT: cannot safely upgrade Transition reveal gate", 0)
    end
    inheritedPending = type(state.pending) == "table" and state.pending or nil
    inheritedMobileGate = type(state.mobileGate) == "table"
                          and state.mobileGate or nil
    Transition.update = state.original
    Transition[MARKER] = nil
  end

  state = {
    owner = V.mod.id,
    original = Transition.update,
    version = COMPAT_VERSION,
    -- A zero-framesIn warp can call finish in the same update that installs
    -- the target map. Keep that one deferred finish per live Transition
    -- without retaining completed instances across GC. Gen1Recomp 0.2.19
    -- additionally pops that Transition before its midpoint; the cold path
    -- below requeues the same state until the destination is ready.
    pending = inheritedPending or setmetatable({}, { __mode = "k" }),
    mobileGate = inheritedMobileGate or newMobileGate(),
  }
  state.owns = function()
    return ownsWorld(Pipelines)
  end
  state.ready = function()
    return readyNow(Pipelines, Game, true, state.mobileGate, "compat")
  end
  state.wrapper = function(self, ...)
    local pending = state.pending[self]
    if pending then
      if not state.ready() then return end
      state.pending[self] = nil
      -- Match the state the engine's original same-tick finish would see.
      self.phase = "in"
      self.t = 0
      return pending.finish(self,
        unpack(pending.args, 1, pending.args.n))
    end

    if self.phase == "in" and self.t == 0 and not state.ready() then
      return
    end

    -- Zero-in warps change the map and call finish() in that same invocation.
    -- There is no later phase=in,t=0 tick for the ordinary guard above to
    -- hold. Let the real midpoint run, but temporarily defer only that finish.
    -- Once the destination map exists, its object identity participates in
    -- readyNow(); a warm target finishes in the original tick, while a cold
    -- one remains on the real opaque Transition until a later update.
    local zeroIn = type(self) == "table" and self.phase == "out"
                   and type(self.framesIn) == "number"
                   and self.framesIn <= 0
                   and type(self.t) == "number"
                   and type(self.frames) == "number"
                   and self.t + 1 >= self.frames and state.owns()
    local finish = zeroIn and self.finish or nil
    if type(finish) ~= "function" then
      return state.original(self, ...)
    end

    local previousFinish = rawget(self, "finish")
    local deferred
    rawset(self, "finish", function(target, ...)
      if target == self then
        deferred = pack(...)
        return
      end
      return finish(target, ...)
    end)
    local result = pack(pcall(state.original, self, ...))
    rawset(self, "finish", previousFinish)
    if not result[1] then error(result[2], 0) end
    if deferred then
      if state.ready() then
        finish(self, unpack(deferred, 1, deferred.n))
      else
        -- 0.2.19's zero-in warp intentionally pops itself *before* running
        -- onMidpoint, then marks offStack so finish() does not pop twice. A
        -- deferred finish on that already-popped object would never receive
        -- another update and would leave Overworld.transitioning true
        -- forever. Preserve the engine's midpoint ordering, then put the
        -- exact same opaque state back until VoxelScene is complete. Older
        -- engines have not popped here and therefore take no stack action.
        if rawget(self, "offStack") == true then
          local stack = self.game and self.game.stack
          local top = stack and stack.top
          local push = stack and stack.push
          local okTop, current = false, nil
          if type(top) == "function" then
            okTop, current = pcall(top, stack)
          end
          local retained = okTop and current == self
          if okTop and not retained and type(push) == "function" then
            local okPush = pcall(push, stack, self)
            retained = okPush
          end
          if not retained then
            -- An unknown Stack implementation is safer revealed than
            -- permanently input-locked. Preserve the real engine completion
            -- callback and fail open without manufacturing stack state.
            return finish(self, unpack(deferred, 1, deferred.n))
          end
          self.offStack = false
        end
        state.pending[self] = { finish = finish, args = deferred }
        -- Transition:alpha cannot represent an opaque phase=in pose when
        -- framesIn=0: fadeAlpha(0, 0) is 1, then the in-phase inversion makes
        -- it 0 (fully transparent). Keep the already-swapped target behind
        -- the engine's terminal fade-out pose instead. The pending branch
        -- above owns subsequent updates, so onMidpoint cannot run twice.
        self.phase = "out"
        self.t = self.frames
      end
    end
    return unpack(result, 2, result.n)
  end
  Transition[MARKER] = state
  Transition.update = state.wrapper
  return state.wrapper
end

local function engineMobileGate(Pipelines)
  local state = rawget(Pipelines, ENGINE_MARKER)
  if type(state) == "table" and state.owner == V.mod.id
      and state.version == ENGINE_GATE_VERSION
      and type(state.gate) == "table" then
    return state.gate
  end
  state = {
    owner = V.mod.id,
    version = ENGINE_GATE_VERSION,
    gate = newMobileGate(),
  }
  rawset(Pipelines, ENGINE_MARKER, state)
  return state.gate
end

-- Returns the callback to add to the voxel pipeline record on a new engine,
-- or nil after installing the 0.1.90 compatibility wrapper.  Optional
-- dependency injection exists solely for the headless contract test.
function TransitionReveal.configure(deps)
  deps = deps or {}
  local Pipelines = deps.Pipelines or require("src.render.Pipelines")
  local Game = deps.Game or require("src.core.Game")
  local Schemas = deps.Schemas or require("src.mods.Schemas")

  if supportsEngineHook(Pipelines, Schemas) then
    local gate = MOBILE_RUNTIME and engineMobileGate(Pipelines) or nil
    return function()
      return readyNow(Pipelines, Game, false, gate, "engine")
    end, "engine"
  end

  local Transition = deps.Transition or require("src.render.Transition")
  installCompat(Pipelines, Game, Transition)
  return nil, "compat"
end

TransitionReveal._supportsEngineHook = supportsEngineHook
TransitionReveal._readyNow = readyNow
TransitionReveal._MOBILE_TIMEOUT_SECONDS = MOBILE_TIMEOUT_SECONDS
TransitionReveal._MOBILE_TIMEOUT_FRAMES = MOBILE_TIMEOUT_FRAMES

return TransitionReveal
