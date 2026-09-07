-- Spatial cursor adapter for VASC's Gen-2 ORAS battle command surface.
--
-- Crystal's native command data order is FIGHT, POKEMON, PACK, RUN and its
-- stock painter presents those slots as a 2x2 rectangle.  VASC deliberately
-- uses the reviewed Gen-1 ORAS shape instead: FIGHT above a lower row of
-- BAG / POKEMON / RUN.  Native callbacks, A-confirm and every battle rule stay
-- untouched; this adapter changes only the directional neighbour selected
-- while that exact ORAS presentation owns an ordinary battle screen.

local V = ...
local Navigation = {
  installed = false,
  moves = 0,
  lastError = nil,
}

local unpackValues = (table and table.unpack) or unpack

local function packValues(...)
  return { n=select("#", ...), ... }
end

local NEIGHBOUR = {
  [1] = { left=3, right=4, up=1, down=2 }, -- FIGHT
  [2] = { left=3, right=4, up=1, down=2 }, -- POKEMON
  [3] = { left=3, right=2, up=1, down=3 }, -- BAG
  [4] = { left=2, right=4, up=1, down=4 }, -- RUN
}

local DIRECTION_ORDER = { "left", "right", "up", "down" }

local function controllerOwns(screen)
  local controller = type(V) == "table" and V.BattleControllerUI or nil
  if type(controller) ~= "table" and type(V) == "table"
      and type(V.require) == "function" then
    local ok, value = pcall(V.require, "BattleControllerUI")
    if ok then controller = value end
  end
  if type(controller) ~= "table" or type(controller.owns) ~= "function" then
    return false
  end
  local ok, owns = pcall(controller.owns, screen)
  return ok and owns == true
end

local function requestedDirection(input)
  if type(input) ~= "table" or type(input.wasPressed) ~= "function" then
    return nil
  end
  for _, direction in ipairs(DIRECTION_ORDER) do
    local ok, pressed = pcall(input.wasPressed, input, direction)
    if ok and pressed then return direction end
  end
  return nil
end

local function updateWithDirectionsMasked(inner, screen, input, ...)
  local wasPressed = input.wasPressed
  input.wasPressed = function(self, button, ...)
    if button == "left" or button == "right"
        or button == "up" or button == "down" then
      return false
    end
    return wasPressed(self, button, ...)
  end
  local out = packValues(pcall(inner, screen, ...))
  input.wasPressed = wasPressed
  if not out[1] then error(out[2], 0) end
  return unpackValues(out, 2, out.n)
end

function Navigation.install()
  local okState, BattleState = pcall(require, "src.ui.gen2.BattleState")
  if not (okState and type(BattleState) == "table"
      and type(BattleState.update) == "function") then
    Navigation.lastError = "src.ui.gen2.BattleState.update unavailable"
    return false, Navigation.lastError
  end
  if BattleState._vascOrasCommandNavigation then
    Navigation.installed = true
    return true
  end

  local innerUpdate = BattleState.update
  BattleState.update = function(self, ...)
    local input = type(self) == "table" and type(self.game) == "table"
      and self.game.input or nil
    if tostring(self and self.phase or "") ~= "menu"
        or not controllerOwns(self) then
      return innerUpdate(self, ...)
    end
    local direction = requestedDirection(input)
    if not direction then return innerUpdate(self, ...) end

    local index = tonumber(self.menuIndex) or 1
    local target = NEIGHBOUR[index] and NEIGHBOUR[index][direction] or index
    self.menuIndex = target
    Navigation.moves = Navigation.moves + 1
    Navigation.lastMove = {
      from=index, to=target, direction=direction,
    }
    Navigation.lastError = nil
    -- Prevent Crystal's stock 2x2 cursor block from applying the same physical
    -- edge a second time. Non-directional reads (notably A) pass through.
    return updateWithDirectionsMasked(innerUpdate, self, input, ...)
  end

  BattleState._vascOrasCommandNavigation = true
  Navigation.installed = true
  Navigation.lastError = nil
  return true
end

function Navigation.status()
  local last = Navigation.lastMove
  return {
    installed=Navigation.installed,
    moves=Navigation.moves,
    lastError=Navigation.lastError,
    lastMove=last and {
      from=last.from, to=last.to, direction=last.direction,
    } or nil,
    owner="native-command-callbacks/spatial-ORAS-cursor",
  }
end

Navigation.neighbourForQa = function(index, direction)
  local row = NEIGHBOUR[tonumber(index) or 1]
  return row and row[direction] or nil
end

return Navigation
