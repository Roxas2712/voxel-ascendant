-- Dedicated, discoverable camera-ladder shortcuts.
--
-- The engine pipeline still owns `3`, and the historical controller bridge
-- still owns SELECT. This module adds aliases that do not compete with a
-- Game Boy input: V on keyboards and the mapped right trigger (ZR/R2/RT) on
-- controllers. Both delegate to main.lua's one authoritative cycleVoxel()
-- function, so persistence, availability gates and TILT/GBC-FX exclusion
-- remain byte-semantic with the existing controls.

local V = ...

local Shortcut = {}

Shortcut.KEY = "v"
Shortcut.TRIGGER_AXIS = "triggerright"
Shortcut.TRIGGER_ON = 0.65
Shortcut.TRIGGER_OFF = 0.35

local MARKER = "voxelAscendantViewShortcutV1"
local unpackValues = table.unpack or unpack

local function packValues(...)
  return { n = select("#", ...), ... }
end

local function screenOwnsInput(game)
  local top = game and game.stack and game.stack:top()
  return top and (top.onKeyPressed or top.onGamepadPressed) or false
end

local function validAxis(value)
  return type(value) == "number" and value == value
         and value >= -1.001 and value <= 1.001
end

function Shortcut.install(cycle)
  if type(cycle) ~= "function" then
    error("VOXEL_ASCENDANT: voxel shortcut requires a cycle callback", 0)
  end

  local Game = require("src.core.Game")
  local state = rawget(Game, MARKER)
  if type(state) == "table" and state.owner == V.mod.id then
    -- Hot reload updates the policy closure without wrapping public input a
    -- second time or losing a trigger that is currently held.
    state.cycle = cycle
    return state
  elseif state ~= nil then
    error("VOXEL_ASCENDANT: voxel shortcut marker is owned elsewhere", 0)
  end
  if type(Game.keypressed) ~= "function"
     or type(Game.gamepadaxis) ~= "function" then
    error("VOXEL_ASCENDANT: keyboard/gamepad input API is unavailable", 0)
  end

  state = {
    owner = V.mod.id,
    cycle = cycle,
    triggerHeld = setmetatable({}, { __mode = "k" }),
    nilJoystick = {},
  }
  local innerKeypressed = Game.keypressed
  local innerGamepadaxis = Game.gamepadaxis

  function Game:keypressed(key, ...)
    if key == Shortcut.KEY and not screenOwnsInput(self)
       and state.cycle(self) then
      return
    end
    return innerKeypressed(self, key, ...)
  end

  function Game:gamepadaxis(joystick, axis, value, ...)
    -- Always forward first: the engine uses a live gamepad axis to hide the
    -- touch overlay, while its Game Boy Input intentionally ignores triggers.
    local results = packValues(innerGamepadaxis(self, joystick, axis, value, ...))
    if axis == Shortcut.TRIGGER_AXIS and validAxis(value) then
      local key = joystick or state.nilJoystick
      local held = state.triggerHeld[key] == true
      if held then
        if value <= Shortcut.TRIGGER_OFF then
          state.triggerHeld[key] = nil
        end
      elseif value >= Shortcut.TRIGGER_ON then
        -- Latch even when a menu or transition rejects the cycle. Holding ZR
        -- while that screen closes must not cause a delayed surprise toggle;
        -- the player releases and presses again for a fresh edge.
        state.triggerHeld[key] = true
        if not screenOwnsInput(self) then state.cycle(self) end
      end
    end
    return unpackValues(results, 1, results.n)
  end

  rawset(Game, MARKER, state)
  return state
end

return Shortcut
