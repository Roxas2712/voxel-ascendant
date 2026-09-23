-- Keep the frozen 3D world behind native dialogue. This grants drawing only;
-- it never advances the overworld, scripts, movement or callbacks.
local M = {}
function M.allowed(top, overworld, game, TextBox, defaultGate)
  if defaultGate(top, overworld) then return true end
  TextBox = TextBox and (TextBox._kascNativeTextBox or TextBox)
  if not (game and overworld and top and TextBox)
      or getmetatable(top) ~= TextBox or top.game ~= game
      or top.onKeyPressed or top.onGamepadPressed
      or overworld.transitioning or overworld.teleportOut then return false end
  local states = game.stack and game.stack.states
  return states and states[#states] == top and states[#states-1] == overworld or false
end
return M
