local baseline = assert(arg and arg[1], "frozen engine root is required")
package.path = baseline .. "/?.lua;" .. baseline .. "/?/init.lua;"
               .. package.path

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected "
          .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function near(actual, expected, message)
  if math.abs(actual - expected) > 1e-9 then
    error((message or "numbers differ") .. ": expected "
          .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function source(path)
  local file = assert(io.open(path, "rb"))
  local payload = assert(file:read("*a"))
  file:close()
  return payload
end

-- This is the real frozen Sandbox facade, not a hand-written approximation.
-- Any old-style callback assignment made by either module therefore aborts
-- with the exact native-stage error this regression test was added for.
local relative, windowFocused = false, true
local hostMoved = function() return "host-moved" end
local hostPressed = function() return "host-pressed" end
local hostReleased = function() return "host-released" end
_G.love = {
  mousemoved = hostMoved,
  mousepressed = hostPressed,
  mousereleased = hostReleased,
  mouse = {
    getRelativeMode = function() return relative end,
    setRelativeMode = function(value) relative = value == true end,
  },
  window = { hasFocus = function() return windowFocused end },
  graphics = {
    getWidth = function() return 1280 end,
    getHeight = function() return 720 end,
  },
}

local Sandbox = require("src.mods.Sandbox")
local Hooks = require("src.mods.Hooks")
local Runtime = require("src.mods.Runtime")
local env = Sandbox.envFor({ modId = "VOXEL_ASCENDANT" })
local assignOk, assignError = pcall(function()
  env.love.mousemoved = function() end
end)
eq(assignOk, false, "frozen love facade unexpectedly accepted assignment")
if not tostring(assignError):find("mods cannot assign love.mousemoved", 1, true) then
  error("frozen love assignment guard changed: " .. tostring(assignError), 0)
end

-- Load the exact frozen Game:pointerEvent implementation while keeping its
-- unrelated renderer/data dependencies inert. The public Hooks and Runtime
-- modules above remain the byte-exact baseline implementations.
local input = { pressed = {}, released = {} }
function input:overlayPressed(button)
  self.pressed[#self.pressed + 1] = button
end
function input:overlayReleased(button)
  self.released[#self.released + 1] = button
end
function input:isDown() return false end
function input:reset() end
function input:reconcile() end

local touchControls = {}
function touchControls:touchpressed() return false end
function touchControls:touchmoved() end
function touchControls:touchreleased() end
function touchControls:hitTest() return nil end
function touchControls:reset() end
function touchControls:layout()
  return { dpad = { cx = 100, cy = 100, w = 64 } }
end

local inert = {
  "src.core.Data", "src.core.FixedStep", "src.render.Renderer",
  "src.core.SaveData", "src.core.StateStack", "src.core.GamepadMap",
  "src.mods.Loader", "src.ui.Screens",
}
for _, name in ipairs(inert) do package.loaded[name] = {} end
package.loaded["src.core.Input"] = input
package.loaded["src.core.TouchControls"] = touchControls
package.loaded["src.core.Game"] = nil
local Game = require("src.core.Game")

local bus = Hooks.new()
Runtime.install({ emit = function() end, removeOwner = function() end },
                bus, {})

local mod = { id = "VOXEL_ASCENDANT", hooks = {} }
function mod.hooks:wrap(name, callback, priority)
  return bus:wrap(name, callback, priority, mod.id)
end

local voxel = {
  level = 6, ready = true, FP_LEVEL = 6, TP_LEVEL = 7,
  active = function() return true end,
  isFreeCam = function(level) return level == 6 or level == 7 end,
  isFirstPerson = function(level) return level == 6 end,
  isThirdPerson = function(level) return level == 7 end,
}
local voxel3d = { available = function() return true end }
local thirdPerson = {
  update = function() end,
  extended = function() return false end,
  showsPlayer = function() return false end,
  signature = function() return "" end,
  stepZoom = function() return true end,
  scaleZoom = function() return true end,
}
local battleShot = nil
local overworldBattle = { shot = function() return battleShot end }
local orbit, pitch = {}, {}
local battleCam = {
  steerable = true,
  ZOOM_STEP = 1.1,
  mouseOrbit = function(value) orbit[#orbit + 1] = value end,
  mousePitch = function(value) pitch[#pitch + 1] = value end,
  stepZoom = function() return true end,
  stickOrbit = function() end,
  stickPitch = function() end,
  dragOrbit = function() end,
  dragPitch = function() end,
}

local modules = {
  VoxelState = voxel,
  Voxel3D = voxel3d,
  WorldCurve = { k = function() return 0 end },
  ThirdPerson = thirdPerson,
  BattleCam = battleCam,
  OverworldBattle = overworldBattle,
}
local V = { mod = mod }
function V.require(name)
  local value = modules[name]
  if value == nil then error("unexpected V.require " .. tostring(name), 0) end
  return value
end

local function loadModule(name, namespace, environment)
  local chunk, compileError = Sandbox.compile(
    source("lib/" .. name .. ".lua"), "@lib/" .. name .. ".lua",
    environment
  )
  if not chunk then error(compileError, 0) end
  return chunk(namespace)
end

local FirstPerson = loadModule("FirstPerson", V, env)
modules.FirstPerson = FirstPerson
local CamControl = loadModule("CamControl", V, env)

Game.input = input
Game.overworld = { player = { facing = "down" } }
local top = Game.overworld
Game.stack = { top = function() return top end }

local passed = {}
bus:wrap("input.pointer", function(nextInput, game, pointer)
  passed[#passed + 1] = pointer.phase .. ":" .. pointer.source
  return nextInput(game, pointer)
end, -100, "probe")

FirstPerson.install()
CamControl.install()
eq(#bus.chains["input.pointer"], 3,
   "public pointer hooks were not registered exactly once")
eq(_G.love.mousemoved, hostMoved, "FirstPerson replaced host mousemoved")
eq(_G.love.mousepressed, hostPressed, "FirstPerson replaced host mousepressed")
eq(_G.love.mousereleased, hostReleased,
   "FirstPerson replaced host mousereleased")

-- Free-roam mouse look is still consumed before downstream pointer mods and
-- applies the exact relative counts on the next camera tick.
FirstPerson.update(1 / 60)
eq(relative, true, "free-roam rung did not capture the mouse")
local yaw, lookPitch = FirstPerson.yaw, FirstPerson.pitch
Game:mousemoved(100, 80, 5, -4, false)
eq(#passed, 0, "captured mouse motion leaked downstream")
FirstPerson.update(1 / 60)
near(FirstPerson.yaw, yaw - 5 * FirstPerson.MOUSE_SENS,
     "captured mouse yaw changed")
near(FirstPerson.pitch, lookPitch - 4 * FirstPerson.MOUSE_SENS,
     "captured mouse pitch changed")

-- Captured left/right clicks remain A/B, and a release is still owned after
-- the rung is left so it cannot strand an overlay button held.
Game:mousepressed(100, 80, 1, false)
eq(input.pressed[#input.pressed], "a", "captured left click was not A")
eq(#passed, 0, "captured left click leaked downstream")
voxel.level = 0
FirstPerson.update(1 / 60)
eq(relative, false, "leaving free-roam did not release relative mode")
Game:mousereleased(100, 80, 1, false)
eq(input.released[#input.released], "a", "captured A release was lost")
eq(#passed, 0, "owned A release leaked downstream")

-- Unowned motion, touch payloads and unbound buttons retain the frozen
-- engine's normal hook chain byte for byte.
Game:mousemoved(20, 30, 2, 3, false)
eq(passed[#passed], "moved:mouse", "uncaptured mouse did not pass through")
Game:pointerEvent("moved", "touch", 7, 10, 12, 1, 2, 1)
eq(passed[#passed], "moved:touch", "touch pointer was claimed as mouse")
voxel.level = 6
top = Game.overworld
FirstPerson.update(1 / 60)
Game:mousepressed(20, 30, 3, false)
eq(passed[#passed], "pressed:mouse", "middle button was claimed")
Game:mousereleased(20, 30, 3, false)
eq(passed[#passed], "released:mouse", "middle-button release was claimed")

-- Leaving the application releases relative mode immediately. Returning does
-- not steal the pointer back from a screenshot tool; the first deliberate
-- left click only re-captures and must not also press A or leak downstream.
windowFocused = false
Game:focus(false)
eq(relative, false, "focus loss did not release the system pointer")
FirstPerson.update(1 / 60)
eq(relative, false, "unfocused free camera re-captured the pointer")
windowFocused = true
Game:focus(true)
FirstPerson.update(1 / 60)
eq(relative, false, "focus regain captured without a deliberate click")
local beforeRearmA, beforeRearmPass = #input.pressed, #passed
Game:mousepressed(20, 30, 1, false)
eq(relative, true, "return click did not re-arm relative mouse mode")
eq(#input.pressed, beforeRearmA, "return click also pressed A")
eq(#passed, beforeRearmPass, "return click leaked downstream")

-- A focus/recovery cancellation is the release captured LOVE callbacks could
-- never deliver. It retires VASC's held button and remains consumed, so a
-- downstream mod never receives a cancellation for a press it did not see.
local beforeCancelPasses = #passed
Game:mousepressed(20, 30, 2, false)
eq(input.pressed[#input.pressed], "b", "captured right click was not B")
Game:cancelPointers()
eq(input.released[#input.released], "b", "cancelled B release was lost")
eq(#passed, beforeCancelPasses, "owned cancellation leaked downstream")

-- CamControl was historically the outer callback. Explicit priorities keep
-- that ordering: a staged battle reads/clamps motion before FirstPerson's
-- still-captured inner handler consumes it.
local battleState = {}
top, battleShot = battleState, {}
FirstPerson.update(1 / 60)
Game:mousemoved(40, 40, 100, -100, false)
eq(orbit[#orbit], 40, "battle mouse orbit lost its 40-count clamp")
eq(pitch[#pitch], 40, "battle mouse pitch lost its sign/clamp")
eq(#passed, beforeCancelPasses, "battle motion escaped captured inner hook")

FirstPerson.install()
CamControl.install()
eq(#bus.chains["input.pointer"], 3,
   "repeated installs stacked public pointer hooks")

-- Feature detection must also fail safely outside the supported hook ABI:
-- loading either module with no mod.hooks simply omits mouse extras and still
-- never attempts to mutate the protected LOVE facade.
local noHookGame = {}
for _, name in ipairs({
  "gamepadaxis", "joystickaxis", "touchpressed", "touchmoved",
  "touchreleased", "focus", "joystickremoved", "wheelmoved",
  "gamepadpressed",
}) do
  noHookGame[name] = function() end
end
package.loaded["src.core.Game"] = noHookGame
local noHookModules = {
  VoxelState = voxel, Voxel3D = voxel3d,
  WorldCurve = modules.WorldCurve, ThirdPerson = thirdPerson,
  BattleCam = battleCam, OverworldBattle = overworldBattle,
}
local noHookV = { mod = { id = "NO_HOOK" } }
function noHookV.require(name)
  local value = noHookModules[name]
  if value == nil then error("unexpected no-hook V.require " .. tostring(name), 0) end
  return value
end
local noHookEnv = Sandbox.envFor({ modId = "NO_HOOK" })
local noHookFirst = loadModule("FirstPerson", noHookV, noHookEnv)
noHookModules.FirstPerson = noHookFirst
local noHookCam = loadModule("CamControl", noHookV, noHookEnv)
noHookFirst.install()
noHookCam.install()
eq(_G.love.mousemoved, hostMoved, "no-hook fallback replaced mousemoved")
eq(_G.love.mousepressed, hostPressed, "no-hook fallback replaced mousepressed")
eq(_G.love.mousereleased, hostReleased,
   "no-hook fallback replaced mousereleased")

print("pointer input frozen compatibility: ok")
