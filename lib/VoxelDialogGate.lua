-- Change only the renderer while a native, manually advanced text box
-- suspends the same overworld. Never resume scripts or alter the stack.
local M = {}
function M.allowed(top, overworld, game, TextBox, defaultGate)
  if defaultGate(top, overworld) then return true end
  if not (game and overworld and top and TextBox)
      or getmetatable(top) ~= TextBox or top.game ~= game
      or top.auto or top.stay or top.onKeyPressed or top.onGamepadPressed
      or overworld.transitioning or overworld.teleportOut then return false end
  local states = game.stack and game.stack.states
  if not states or states[#states] ~= top
      or states[#states-1] ~= overworld then return false end
  local player = overworld.player
  if not player or player.moving or player.spinning
      or next(overworld.scriptMoves or {}) ~= nil then return false end
  local runner = overworld.runner
  if runner and (runner.waitingFrames or runner.waitingCheck) then return false end
  return true
end
return M
