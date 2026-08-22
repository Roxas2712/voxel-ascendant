local topState = {}
local hostKeys, hostAxes = 0, 0
local order = {}

local Game = {
  stack = { top = function() return topState end },
  overworld = {},
}
function Game:keypressed(key, marker)
  hostKeys = hostKeys + 1
  order[#order + 1] = "key:" .. tostring(key)
  return "host-key", key, marker
end
function Game:gamepadaxis(_, axis, value, marker)
  hostAxes = hostAxes + 1
  order[#order + 1] = "axis:" .. tostring(axis)
  return "host-axis", axis, value, marker
end

package.loaded["src.core.Game"] = Game

local V = { mod = { id = "VOXEL_ASCENDANT" } }
local Shortcut = assert(loadfile("lib/VoxelShortcut.lua"))(V)

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected "
          .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

eq(Shortcut.KEY, "v", "desktop shortcut changed")
eq(Shortcut.TRIGGER_AXIS, "triggerright", "ZR/R2/RT axis changed")
eq(Shortcut.TRIGGER_ON, 0.65, "trigger press threshold changed")
eq(Shortcut.TRIGGER_OFF, 0.35, "trigger release threshold changed")

local cycleCalls, cycleResult = 0, true
local function cycle(game)
  eq(game, Game, "shortcut did not pass the live Game")
  cycleCalls = cycleCalls + 1
  order[#order + 1] = "cycle"
  return cycleResult
end

local state = Shortcut.install(cycle)
eq(state.owner, V.mod.id, "shortcut marker lost owner")

-- V is consumed only when the authoritative cycle accepts it.
local a = Game:keypressed("v", "desktop")
eq(a, nil, "accepted V shortcut leaked to the host")
eq(cycleCalls, 1, "V did not cycle exactly once")
eq(hostKeys, 0, "accepted V reached the host key handler")

cycleResult = false
local k1, k2, k3 = Game:keypressed("v", "fallback")
eq(cycleCalls, 2, "rejected V did not ask the cycle gate")
eq(hostKeys, 1, "rejected V was not forwarded exactly once")
eq(k1, "host-key", "forwarded V lost host return #1")
eq(k2, "v", "forwarded V lost host return #2")
eq(k3, "fallback", "forwarded V lost host return #3")

cycleResult = true
Game:keypressed("q", "other")
eq(cycleCalls, 2, "unrelated desktop key cycled voxel view")
eq(hostKeys, 2, "unrelated desktop key was not forwarded")

topState = { onKeyPressed = function() end }
Game:keypressed("v", "typing")
eq(cycleCalls, 2, "screen-owned V changed the world camera")
eq(hostKeys, 3, "screen-owned V did not reach the active screen path")
topState = {}

-- ZR/R2/RT is an axis, not a Game Boy button. The engine always receives it
-- first (touch-overlay ownership), then one rising edge cycles. A held or
-- jittering trigger cannot skip multiple camera rungs.
local padA, padB = {}, {}
order = {}
local r1, r2, r3, r4 = Game:gamepadaxis(padA, "triggerright", 0.70, "zr")
eq(hostAxes, 1, "trigger axis was not forwarded")
eq(cycleCalls, 3, "trigger rising edge did not cycle")
eq(order[1], "axis:triggerright", "trigger cycled before host forwarding")
eq(order[2], "cycle", "trigger did not cycle after forwarding")
eq(r1, "host-axis", "trigger lost host return #1")
eq(r2, "triggerright", "trigger lost host return #2")
eq(r3, 0.70, "trigger lost host return #3")
eq(r4, "zr", "trigger lost host return #4")

Game:gamepadaxis(padA, "triggerright", 1.0)
Game:gamepadaxis(padA, "triggerright", 0.50)
eq(cycleCalls, 3, "held/jittering trigger skipped a camera rung")
Game:gamepadaxis(padA, "triggerright", 0.34)
Game:gamepadaxis(padA, "triggerright", 0.66)
eq(cycleCalls, 4, "released trigger did not create a fresh edge")

Game:gamepadaxis(padB, "rightx", 1.0)
eq(cycleCalls, 4, "right stick was mistaken for ZR")
Game:gamepadaxis(padB, "triggerright", 0 / 0)
eq(cycleCalls, 4, "NaN trigger input changed the camera")
Game:gamepadaxis(padB, "triggerright", 0.70)
eq(cycleCalls, 5, "second controller did not own an independent edge")

-- Pressing ZR on a menu is latched but never delayed until that menu closes.
Game:gamepadaxis(padA, "triggerright", 0.0)
topState = { onGamepadPressed = function() end }
Game:gamepadaxis(padA, "triggerright", 0.8)
eq(cycleCalls, 5, "menu-owned ZR changed the world camera")
topState = {}
Game:gamepadaxis(padA, "triggerright", 1.0)
eq(cycleCalls, 5, "held menu trigger caused a delayed camera change")
Game:gamepadaxis(padA, "triggerright", 0.0)
Game:gamepadaxis(padA, "triggerright", 0.8)
eq(cycleCalls, 6, "fresh post-menu ZR edge did not cycle")

-- Hot reload updates only the callback closure; public handlers are not
-- wrapped a second time and a single event still yields one cycle.
local keyWrapper, axisWrapper = Game.keypressed, Game.gamepadaxis
local hotCalls = 0
local again = Shortcut.install(function(game)
  eq(game, Game, "hot-reload cycle lost Game")
  hotCalls = hotCalls + 1
  return true
end)
eq(again, state, "hot reload replaced shortcut state")
eq(Game.keypressed, keyWrapper, "hot reload wrapped key input twice")
eq(Game.gamepadaxis, axisWrapper, "hot reload wrapped axis input twice")
Game:keypressed("v")
eq(hotCalls, 1, "hot-reload V did not use the new callback exactly once")
eq(cycleCalls, 6, "hot reload retained the stale callback")

print("voxel shortcuts: ok")
