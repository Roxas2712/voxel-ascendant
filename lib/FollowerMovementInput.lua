local V = ...
local FirstPerson = V.require("FirstPerson")
local Bridge = {}
local directions = { up=true, down=true, left=true, right=true }
local function pack(...) return { n=select("#", ...), ... } end

function Bridge.install()
  local Follower = require("src.world.PikachuFollower")
  local state = Follower.__vascWorldInputBridge or {}
  Follower.__vascWorldInputBridge = state
  state.camera = FirstPerson
  if Follower.update == state.wrapper then return end
  local inner = Follower.update
  state.wrapper = function(game, ow, ...)
    local camera = state.camera
    local p = ow and ow.player
    local input = game and game.input
    if state.active or not (p and input and camera.driving())
        or p.moving or p.inputLocked or ow.pikaHop
        or #(ow.scriptMoves or {}) > 0
        or (ow.runner and ow.runner:isRunning()) then
      return inner(game, ow, ...)
    end
    local mx, mz = camera.moveVector()
    local wx, wz = camera.moveWorld(mx, mz)
    local dir
    if wx ~= 0 or wz ~= 0 then
      if math.abs(wx) > math.abs(wz) then
        dir = wx > 0 and "right" or "left"
      else
        dir = wz > 0 and "down" or "up"
      end
    end
    -- The native follower's yield counter compares pad direction, facing
    -- and adjacent cell in world coordinates. Free movement's pad is camera
    -- relative; supply that world view only during the follower update.
    local ownIsDown, isDown = rawget(input, "isDown"), input.isDown
    local facing = p.facing
    input.isDown = function(self, key)
      if directions[key] then return key == dir end
      return isDown(self, key)
    end
    if dir then p.facing = dir end
    state.active = true
    local result = pack(pcall(inner, game, ow, ...))
    state.active = false
    input.isDown, p.facing = ownIsDown, facing
    if not result[1] then error(result[2], 0) end
    return unpack(result, 2, result.n)
  end
  Follower.update = state.wrapper
end

return Bridge
