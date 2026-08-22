-- Keep a cold voxel destination behind the engine's real warp midpoint until
-- its first complete 3D frame exists.
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
local COMPAT_VERSION = 3

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

local function readyNow(Pipelines, Game, requireOwner)
  -- The compatibility wrapper lives on the shared Transition class, so it
  -- must explicitly leave every other renderer's fade untouched.  The native
  -- engine hook already dispatches only the selected pipeline's callback.
  if requireOwner and not ownsWorld(Pipelines) then return true end
  local ow = Game and Game.overworld
  if not (ow and ow.map) then return true end
  local okScene, Scene = pcall(V.require, "VoxelScene")
  if not okScene then return true end
  if type(Scene.readyForReveal) ~= "function" then return true end
  local okReady, ready = pcall(Scene.readyForReveal, ow)
  if not okReady then return true end
  return ready == true
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

  local state = rawget(Transition, MARKER)
  if type(state) == "table" and state.owner == V.mod.id then
    -- Hot reload may create a new V/Scene closure. Update only the predicate;
    -- never wrap the already-wrapped method a second time.
    state.owns = function()
      return ownsWorld(Pipelines)
    end
    state.ready = function()
      return readyNow(Pipelines, Game, true)
    end
    if state.version == COMPAT_VERSION and type(state.pending) == "table" then
      return state.wrapper
    end
    -- Upgrade an older compatibility wrapper without stacking it. Every
    -- version retains the untouched engine method for this idempotent unwind.
    if Transition.update ~= state.wrapper or type(state.original) ~= "function" then
      error("VOXEL_ASCENDANT: cannot safely upgrade Transition reveal gate", 0)
    end
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
    pending = setmetatable({}, { __mode = "k" }),
  }
  state.owns = function()
    return ownsWorld(Pipelines)
  end
  state.ready = function()
    return readyNow(Pipelines, Game, true)
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

-- Returns the callback to add to the voxel pipeline record on a new engine,
-- or nil after installing the 0.1.90 compatibility wrapper.  Optional
-- dependency injection exists solely for the headless contract test.
function TransitionReveal.configure(deps)
  deps = deps or {}
  local Pipelines = deps.Pipelines or require("src.render.Pipelines")
  local Game = deps.Game or require("src.core.Game")
  local Schemas = deps.Schemas or require("src.mods.Schemas")

  if supportsEngineHook(Pipelines, Schemas) then
    return function()
      return readyNow(Pipelines, Game, false)
    end, "engine"
  end

  local Transition = deps.Transition or require("src.render.Transition")
  installCompat(Pipelines, Game, Transition)
  return nil, "compat"
end

TransitionReveal._supportsEngineHook = supportsEngineHook
TransitionReveal._readyNow = readyNow

return TransitionReveal
