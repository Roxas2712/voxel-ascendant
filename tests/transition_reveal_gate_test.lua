local scene = { ready = false, map = nil }
function scene.readyForReveal(state)
  return scene.ready and state.map == scene.map
end

local V = { mod = { id = "VOXEL_ASCENDANT" } }
function V.require(name)
  if name == "VoxelScene" then return scene end
  error("unexpected module " .. tostring(name), 0)
end

local Gate = assert(loadfile("lib/TransitionReveal.lua"))(V)

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected "
          .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local map = { id = "MT_MOON_POKECENTER" }
local game = { overworld = { map = map } }

-- Gen1Recomp 0.1.90 path: no revealReady schema/API. The compatibility
-- wrapper must affect only voxel fade-in at the opaque midpoint.
local oldPipelines = { active = "voxel" }
function oldPipelines.worldPipeline() return oldPipelines.active end
local oldSchemas = {
  REGISTRIES = { render_pipelines = { fields = { drawWorld = {} } } },
}
local calls = 0
local function baseUpdate(self)
  calls = calls + 1
  self.t = self.t + 1
end
local transition = { update = baseUpdate }

local callback, mode = Gate.configure({
  Pipelines = oldPipelines, Game = game, Schemas = oldSchemas,
  Transition = transition,
})
eq(callback, nil, "0.1.90 cannot receive an unknown record field")
eq(mode, "compat", "0.1.90 did not select the compatibility path")
local installed = transition.update

scene.ready, scene.map = false, nil
local fade = { phase = "out", t = 0 }
transition.update(fade, 1 / 60)
eq(fade.t, 1, "cold destination readiness delayed fade-out")
eq(calls, 1, "fade-out did not delegate to the original transition")

fade.phase, fade.t = "in", 0
transition.update(fade, 1 / 60)
eq(fade.t, 0, "cold voxel destination escaped the black midpoint")
eq(calls, 1, "held midpoint still advanced the original transition")

scene.ready, scene.map = true, map
transition.update(fade, 1 / 60)
eq(fade.t, 1, "warm/current voxel destination did not reveal immediately")
eq(calls, 2, "ready fade-in did not delegate exactly once")

-- The shared Transition class must fail open for every path VASC does not
-- own, including another world renderer and a broken ownership query.
fade.t, oldPipelines.active = 0, "another_renderer"
transition.update(fade, 1 / 60)
eq(fade.t, 1, "compatibility wrapper delayed another renderer")
fade.t = 0
oldPipelines.worldPipeline = function() error("catalog unavailable", 0) end
transition.update(fade, 1 / 60)
eq(fade.t, 1, "broken pipeline lookup did not fail open")

-- Reconfiguration (hot reload) updates the predicate but never stacks a
-- second wrapper around the first.
oldPipelines.worldPipeline = function() return "voxel" end
Gate.configure({
  Pipelines = oldPipelines, Game = game, Schemas = oldSchemas,
  Transition = transition,
})
eq(transition.update, installed, "compatibility wrapper was installed twice")

-- A live development session may still carry the pre-opaque-hold V1 marker.
-- Upgrade by unwrapping its recorded engine method, never by stacking V2 on
-- top of the old wrapper.
do
  local originalCalls = 0
  local function original(self)
    originalCalls = originalCalls + 1
    self.t = self.t + 1
  end
  local function legacyWrapper() error("legacy wrapper was retained", 0) end
  local upgradeTransition = { update = legacyWrapper }
  upgradeTransition.__voxelAscendantRevealGateV1 = {
    owner = V.mod.id, original = original, wrapper = legacyWrapper,
  }
  Gate.configure({
    Pipelines = oldPipelines, Game = game, Schemas = oldSchemas,
    Transition = upgradeTransition,
  })
  if upgradeTransition.update == legacyWrapper then
    error("V1 compatibility wrapper was not upgraded", 0)
  end
  local upgraded = upgradeTransition.__voxelAscendantRevealGateV1
  eq(type(upgraded), "table", "V2 compatibility marker missing after upgrade")
  eq(upgraded.version, 3, "compatibility marker did not record V3")
  local probe = { phase = "out", t = 0 }
  upgradeTransition.update(probe, 1 / 60)
  eq(originalCalls, 1, "V2 upgrade did not unwrap to the engine update")
  eq(probe.t, 1, "V2 upgrade stacked or skipped the engine update")
end

-- Both player-attached modes use the same selected voxel world pipeline.
-- Pin the two public rung numbers explicitly so a later gate cannot quietly
-- cover 3RD while letting 1ST (or vice versa) fall back to bird's-eye.
for _, level in ipairs({ 6, 7 }) do
  oldPipelines.level = level
  oldPipelines.worldPipeline = function()
    return oldPipelines.level > 0 and "voxel" or nil
  end
  scene.ready, scene.map = false, nil
  local attached = { phase = "in", t = 0 }
  transition.update(attached, 1 / 60)
  eq(attached.t, 0,
     (level == 6 and "1ST" or "3RD") .. " released a cold destination")
  scene.ready, scene.map = true, map
  transition.update(attached, 1 / 60)
  eq(attached.t, 1,
     (level == 6 and "1ST" or "3RD") .. " held a complete destination")
end

-- Gen1Recomp 0.2.19 changed a zero-in warp's ordering: it pops the
-- Transition before onMidpoint, marks it offStack, and only then calls
-- finish(). Deferring finish without retaining that popped state strands
-- Overworld.transitioning forever because the object receives no more
-- updates. Exercise that exact ownership sequence independently of the
-- frozen 0.1.90 fixture below.
do
  local pops, pushes, done, midpoint = 0, 0, 0, 0
  local stack = { states = {} }
  function stack:top() return self.states[#self.states] end
  function stack:push(value)
    pushes = pushes + 1
    self.states[#self.states + 1] = value
  end
  function stack:pop()
    pops = pops + 1
    return table.remove(self.states)
  end

  local currentGame = { overworld = { map = { id = "CURRENT_SOURCE" } } }
  currentGame.stack = stack
  local CurrentTransition = {}
  CurrentTransition.__index = CurrentTransition
  function CurrentTransition.new(onMidpoint, onDone)
    return setmetatable({
      game = currentGame, onMidpoint = onMidpoint, onDone = onDone,
      phase = "out", t = 3, frames = 4, framesIn = 0,
    }, CurrentTransition)
  end
  function CurrentTransition:finish()
    if self.done then return end
    self.done = true
    if not self.offStack then self.game.stack:pop() end
    if self.onDone then self.onDone() end
  end
  function CurrentTransition:update()
    self.t = self.t + 1
    if self.t < self.frames then return end
    self.t = 0
    self.phase = "in"
    self.offStack = true
    self.game.stack:pop()
    if self.onMidpoint then self.onMidpoint() end
    self:finish()
  end

  local _, currentMode = Gate.configure({
    Pipelines = oldPipelines, Game = currentGame, Schemas = oldSchemas,
    Transition = CurrentTransition,
  })
  eq(currentMode, "compat", "0.2.19 fixture did not select compatibility")

  local source, target = currentGame.overworld.map, { id = "CURRENT_COLD" }
  scene.ready, scene.map = true, source
  local midpointTop
  local cold = CurrentTransition.new(function()
    midpoint = midpoint + 1
    midpointTop = stack:top()
    currentGame.overworld.map = target
  end, function() done = done + 1 end)
  stack:push(cold)
  cold:update()
  eq(midpoint, 1, "0.2.19 midpoint did not run exactly once")
  eq(midpointTop, nil, "compat gate changed 0.2.19 pre-midpoint pop ordering")
  eq(pops, 1, "0.2.19 engine pop was lost or duplicated")
  eq(pushes, 2, "cold popped transition was not retained exactly once")
  eq(stack:top(), cold, "cold popped transition is no longer active")
  eq(cold.offStack, false, "retained transition still believes it is popped")
  eq(cold.phase, "out", "retained transition lost its opaque phase")
  eq(cold.t, cold.frames, "retained transition lost terminal fade pose")
  eq(done, 0, "cold 0.2.19 transition completed before readiness")

  cold:update()
  eq(midpoint, 1, "held 0.2.19 transition reran its midpoint")
  eq(pops, 1, "held 0.2.19 transition escaped while cold")
  scene.ready, scene.map = true, target
  cold:update()
  eq(pops, 2, "ready retained transition did not pop exactly once")
  eq(stack:top(), nil, "ready retained transition remained on stack")
  eq(done, 1, "ready retained transition lost its completion callback")
  eq(cold.phase, "in", "ready retained transition finished in wrong phase")
  eq(cold.t, 0, "ready retained transition finished on wrong tick")

  -- A warm destination preserves the current engine's same-tick pre-pop and
  -- completion. It must not be pushed back for even one frame.
  source, target = { id = "CURRENT_WARM_SOURCE" }, { id = "CURRENT_WARM" }
  currentGame.overworld.map = source
  scene.ready, scene.map = true, source
  local warm = CurrentTransition.new(function()
    midpoint = midpoint + 1
    currentGame.overworld.map = target
    scene.ready, scene.map = true, target
  end, function() done = done + 1 end)
  stack:push(warm)
  warm:update()
  eq(pops, 3, "warm 0.2.19 transition lost its engine pop")
  eq(pushes, 3, "warm 0.2.19 transition was unnecessarily requeued")
  eq(stack:top(), nil, "warm 0.2.19 transition remained active")
  eq(done, 2, "warm 0.2.19 transition lost same-tick completion")
end

-- New engine path: include the schema field and leave Transition completely
-- untouched. The callback reflects only the current map's atomic 3D answer.
local newPipelines = {
  worldRevealReady = function() return true end,
  worldPipeline = function() return "voxel" end,
}
local newSchemas = {
  REGISTRIES = {
    render_pipelines = {
      fields = { drawWorld = {}, revealReady = {} },
    },
  },
}
local newTransition = { update = baseUpdate }
scene.ready, scene.map = false, nil
callback, mode = Gate.configure({
  Pipelines = newPipelines, Game = game, Schemas = newSchemas,
  Transition = newTransition,
})
eq(type(callback), "function", "new engine did not receive revealReady")
eq(mode, "engine", "new engine selected the compatibility wrapper")
eq(newTransition.update, baseUpdate, "new engine Transition was monkey-patched")
eq(callback(), false, "new engine callback released a cold destination")
scene.ready, scene.map = true, map
eq(callback(), true, "new engine callback held a complete destination")

-- Both capabilities are required: method-only or schema-only partial
-- backports must use the valid 0.1.90 record shape.
eq(Gate._supportsEngineHook(newPipelines, oldSchemas), false,
   "method-only backport would register an unknown field")
eq(Gate._supportsEngineHook(oldPipelines, newSchemas), false,
   "schema-only backport was mistaken for a live engine hook")

-- Readiness failures cannot strand the screen behind black.
scene.readyForReveal = function() error("scene probe failed", 0) end
eq(callback(), true, "broken scene readiness probe did not fail open")

-- When the contract runner supplies the frozen 0.1.90 tree, exercise its
-- actual schema and Transition class rather than relying only on the reduced
-- fixture above. Its real warps have framesIn=0: the original midpoint changes
-- the map and calls finish() in one update, so this also proves that finish is
-- deferred until the NEW map identity is ready rather than trusting the warm
-- source map or waiting for a phase=in tick that would otherwise never exist.
local baseline = arg and arg[1]
if baseline and baseline ~= "" then
  package.path = baseline .. "/?.lua;" .. baseline .. "/?/init.lua;"
                 .. package.path
  package.loaded["src.core.Timing"] = nil
  package.loaded["src.mods.Schemas"] = nil
  package.loaded["src.render.Transition"] = nil
  local baselineSchemas = require("src.mods.Schemas")
  local baselineTransition = require("src.render.Transition")
  eq(baselineSchemas.REGISTRIES.render_pipelines.fields.revealReady, nil,
     "frozen 0.1.90 unexpectedly accepts the new record field")

  function scene.readyForReveal(state)
    return scene.ready and state.map == scene.map
  end
  local before = baselineTransition.update
  local baselinePipelines = { active = "voxel" }
  function baselinePipelines.worldPipeline()
    return baselinePipelines.active
  end
  local pops, done = 0, 0
  local baselineGame = {
    data = {}, overworld = { map = { id = "SOURCE" } },
    stack = { pop = function() pops = pops + 1 end },
  }
  local _, baselineMode = Gate.configure({
    Pipelines = baselinePipelines, Game = baselineGame,
    Schemas = baselineSchemas, Transition = baselineTransition,
  })
  eq(baselineMode, "compat", "frozen 0.1.90 did not select compatibility")
  if baselineTransition.update == before then
    error("frozen 0.1.90 Transition did not receive the compatibility gate", 0)
  end

  local installedBaseline = baselineTransition.update
  Gate.configure({
    Pipelines = baselinePipelines, Game = baselineGame,
    Schemas = baselineSchemas, Transition = baselineTransition,
  })
  eq(baselineTransition.update, installedBaseline,
     "frozen 0.1.90 compatibility wrapper stacked on reconfigure")

  local source = baselineGame.overworld.map
  local target = { id = "COLD_TARGET" }
  scene.ready, scene.map = true, source
  local midpoint = 0
  local cold = baselineTransition.new(baselineGame, function()
    midpoint = midpoint + 1
    baselineGame.overworld.map = target
  end, function() done = done + 1 end, true)
  eq(cold.framesIn, 0, "frozen 0.1.90 warp fixture is not zero-in")
  cold.t = cold.frames - 1
  cold:update(1 / 60)
  eq(midpoint, 1, "zero-in compatibility gate skipped the real midpoint")
  eq(baselineGame.overworld.map, target,
     "zero-in compatibility gate did not install the destination map")
  eq(cold.phase, "out",
     "cold zero-in destination was not held at terminal fade-out")
  eq(cold.t, cold.frames,
     "cold zero-in destination lost its opaque fade-out pose")
  eq(cold:alpha(), 1,
     "cold zero-in destination exposed a transparent framesIn=0 pose")
  eq(pops, 0, "warm source identity released a cold zero-in destination")
  eq(done, 0, "cold zero-in destination ran its completion callback")

  -- Hot reload/reconfigure updates predicates without losing the deferred
  -- finish or wrapping the engine method again.
  Gate.configure({
    Pipelines = baselinePipelines, Game = baselineGame,
    Schemas = baselineSchemas, Transition = baselineTransition,
  })
  eq(baselineTransition.update, installedBaseline,
     "hot reload replaced a live zero-in compatibility wrapper")
  cold:update(1 / 60)
  eq(pops, 0, "cold zero-in destination escaped on a later update")
  eq(midpoint, 1, "held zero-in destination reran its midpoint")
  eq(cold.phase, "out", "held zero-in destination left opaque phase")
  eq(cold.t, cold.frames, "held zero-in destination advanced fade state")
  eq(cold:alpha(), 1, "later cold tick exposed the target map")
  scene.ready, scene.map = true, target
  cold:update(1 / 60)
  eq(pops, 1, "ready zero-in destination did not finish exactly once")
  eq(done, 1, "ready zero-in destination lost its completion callback")
  eq(midpoint, 1, "ready zero-in destination reran its midpoint")
  eq(cold.phase, "in", "ready zero-in destination finished from wrong phase")
  eq(cold.t, 0, "ready zero-in destination finished from wrong tick")

  -- A destination already complete at the midpoint keeps 0.1.90's original
  -- same-tick timing; the temporary finish deferral is not an added frame.
  source, target = { id = "WARM_SOURCE" }, { id = "WARM_TARGET" }
  baselineGame.overworld.map = source
  scene.ready, scene.map = true, source
  local warm = baselineTransition.new(baselineGame, function()
    baselineGame.overworld.map = target
    scene.ready, scene.map = true, target
  end, function() done = done + 1 end, true)
  warm.t = warm.frames - 1
  warm:update(1 / 60)
  eq(pops, 2, "warm zero-in destination gained a compatibility delay")
  eq(done, 2, "warm zero-in destination did not finish in its original tick")

  -- The shared Transition class must not defer a zero-in warp owned by any
  -- other world renderer, even when VoxelScene itself is cold.
  baselinePipelines.active = "another_renderer"
  baselineGame.overworld.map = { id = "OTHER_SOURCE" }
  scene.ready, scene.map = false, nil
  local other = baselineTransition.new(baselineGame, function()
    baselineGame.overworld.map = { id = "OTHER_TARGET" }
  end, function() done = done + 1 end, true)
  other.t = other.frames - 1
  other:update(1 / 60)
  eq(pops, 3, "zero-in compatibility gate delayed another renderer")
  eq(done, 3, "another renderer lost its zero-in completion callback")

  -- Script fades retain their real framesIn>0 phase and are never routed
  -- through the zero-in finish deferral.
  baselinePipelines.active = "voxel"
  baselineGame.overworld.map = { id = "SCRIPT_SOURCE" }
  local scriptTarget = { id = "SCRIPT_TARGET" }
  scene.ready, scene.map = true, baselineGame.overworld.map
  local scriptFade = baselineTransition.new(baselineGame, function()
    baselineGame.overworld.map = scriptTarget
  end, nil, false)
  if scriptFade.framesIn <= 0 then error("script fade lost framesIn>0", 0) end
  scriptFade.t = scriptFade.frames - 1
  scriptFade:update(1 / 60)
  eq(scriptFade.phase, "in", "framesIn>0 fade did not retain its in phase")
  eq(scriptFade.t, 0, "framesIn>0 fade gained a compatibility tick")
  eq(pops, 3, "framesIn>0 midpoint was mistaken for zero-in finish")

  -- Readiness errors remain fail-open, and an error in the original midpoint
  -- restores the inherited finish method before propagating.
  baselineGame.overworld.map = { id = "FAIL_OPEN_SOURCE" }
  scene.readyForReveal = function() error("scene probe failed", 0) end
  local failOpen = baselineTransition.new(baselineGame, function()
    baselineGame.overworld.map = { id = "FAIL_OPEN_TARGET" }
  end, function() done = done + 1 end, true)
  failOpen.t = failOpen.frames - 1
  failOpen:update(1 / 60)
  eq(pops, 4, "zero-in readiness error stranded the transition")
  eq(done, 4, "zero-in readiness error lost the completion callback")

  local broken = baselineTransition.new(baselineGame, function()
    error("midpoint exploded", 0)
  end, nil, true)
  broken.t = broken.frames - 1
  local ok, message = pcall(broken.update, broken, 1 / 60)
  eq(ok, false, "zero-in midpoint error was swallowed")
  eq(message, "midpoint exploded", "zero-in midpoint error changed")
  eq(rawget(broken, "finish"), nil,
     "zero-in midpoint error left a temporary finish override")
end

print("transition reveal gate: ok")
