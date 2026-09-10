-- Optional KASC capability, never a Gen-1 battler adapter. Rules and form
-- lifetime stay in KASC; this module owns only the extra VASC command chip.
local V = ...
local M = {}
local painted = setmetatable({}, { __mode="k" })

local function bridge(screen)
  local exports = screen and screen.game and screen.game.mods
    and screen.game.mods.exports
  local kasc = exports and exports.kanto_ascendant
  local api = kasc and kasc.megaGen2BattleBridge
  if type(api) == "table" and type(api.isVisible) == "function"
      and type(api.canActivate) == "function"
      and type(api.activate) == "function" then return api end
end

function M.state(screen)
  local api = bridge(screen)
  if not api then return false, false end
  local ok, visible = pcall(api.isVisible, screen)
  if not ok or visible ~= true then return false, false end
  local ready, allowed = pcall(api.canActivate, screen)
  return true, ready and allowed == true
end

function M.activate(screen)
  local visible, allowed = M.state(screen)
  if not visible or not allowed then return false end
  local ok, success = pcall(bridge(screen).activate, screen)
  screen._vascGen2MegaFocus = nil
  painted[screen] = nil
  return ok and success == true
end

function M.clearPaint(screen) if screen then painted[screen] = nil end end
function M.publish(screen, rect, ww, wh)
  local w, h = love.graphics.getDimensions()
  painted[screen] = rect and { rect={rect[1]*w/ww, rect[2]*h/wh,
    rect[3]*w/ww, rect[4]*h/wh}, ww=w, wh=h } or nil
end

local function owns(screen)
  local controller = V and V.BattleControllerUI
  return controller and controller.owns(screen) == true
    and screen.phase == "menu" and not screen.message
end

local function presented(screen)
  local receipt = painted[screen]
  if not receipt or not owns(screen) then return nil end
  local w, h = love.graphics.getDimensions()
  -- A rotated/resized device needs a fresh paint before it can activate.
  if w ~= receipt.ww or h ~= receipt.wh then return nil end
  return receipt.rect
end

function M.hitRect(screen)
  local rect=presented(screen)
  return rect and {rect[1],rect[2],rect[3],rect[4]} or nil
end

function M.neighbour(index, direction)
  if direction=="up" and index~=1 then return 1 end
  if direction=="down" and index==1 then return 2 end
  if direction=="left" or direction=="right" then
    if index==1 then return direction=="left" and 0 or 2 end
    local row={3,0,2,4}
    for i,value in ipairs(row) do
      if value==index then
        return row[math.max(1,math.min(#row,i+(direction=="left" and -1 or 1)))]
      end
    end
  end
  return index
end

function M.press(screen, x, y)
  local controls = V and V.BattleControllerUI
  if controls and type(controls.pressControls) == "function"
      and controls.pressControls(screen, x, y) then return true end
  local rect = presented(screen)
  if not rect or x < rect[1] or y < rect[2]
      or x > rect[1]+rect[3] or y > rect[2]+rect[4] then return false end
  if not M.state(screen) then return false end
  M.activate(screen) -- a used/temporarily blocked chip consumes no native A
  return true
end

function M.install(options)
  local State = require("src.ui.gen2.BattleState")
  local Game = require("src.core.Game2")
  if State._vascGen2MegaBridge then return true end
  local bindInput
  local inner = State.update
  State.update = function(screen, ...)
    -- Camera controls wrap the live Game2 INSTANCE at game.ready. Capture
    -- the chip outside those wrappers too, before a finger becomes a pinch.
    bindInput(screen.game)
    local input = screen.game and screen.game.input
    local visible = M.state(screen)
    if not (input and presented(screen) and visible) then
      screen._vascGen2MegaFocus = nil
      return inner(screen, ...)
    end
    local function pressed(key) return input:wasPressed(key) end
    if screen._vascGen2MegaFocus then
      if pressed("a") then M.activate(screen); return end
      if pressed("b") then
        screen._vascGen2MegaFocus = nil
        screen.menuIndex = 1
        return
      end
    end
    for _, direction in ipairs({"up","down","left","right"}) do
      if pressed(direction) then
        local index=screen._vascGen2MegaFocus and 0 or screen.menuIndex
        local target=M.neighbour(index,direction)
        screen._vascGen2MegaFocus=target==0 or nil
        if target~=0 then screen.menuIndex=target end
        return
      end
    end
    -- SELECT remains KASC's native shortcut, including all rule checks.
    return inner(screen, ...)
  end

  local function top(game)
    return game.stack and game.stack:top()
  end
  local function point(x, y)
    local flip = options and options.flip
    if flip and flip.enabled() then return flip.remapPoint(x, y) end
    return x, y
  end
  local bound = setmetatable({}, {__mode="k"})
  bindInput = function(Game)
  if type(Game) ~= "table" or bound[Game] then return end
  bound[Game]=true
  local held = {}
  local touch = Game.touchpressed
  Game.touchpressed = function(game, id, x, y, ...)
    local px, py = point(x, y)
    if M.press(top(game), px, py) then held[id]=true; return end
    if touch then return touch(game, id, x, y, ...) end
  end
  for _, name in ipairs({"touchmoved", "touchreleased"}) do
    local previous, released = Game[name], name == "touchreleased"
    Game[name] = function(game, id, ...)
      if held[id] then
        if released then held[id]=nil end
        return
      end
      if previous then return previous(game, id, ...) end
    end
  end
  local mouse, mouseHeld = Game.mousepressed, false
  Game.mousepressed = function(game, x, y, button, istouch, ...)
    local px, py = point(x, y)
    if button == 1 and not istouch and M.press(top(game), px, py) then
      mouseHeld=true; return
    end
    if mouse then return mouse(game, x, y, button, istouch, ...) end
  end
  local release = Game.mousereleased
  Game.mousereleased = function(game, x, y, button, ...)
    if button == 1 and mouseHeld then mouseHeld=false; return end
    if release then return release(game, x, y, button, ...) end
  end
  end
  bindInput(Game)
  State._vascGen2MegaBridge = true
  return true
end

return M
