-- Android whole-frame 180-degree compatibility flip.
--
-- The earlier screenFlip implementation lived inside render.compose.  Gold's
-- Game2 draws render.hud + TouchControls AFTER render.compose, so that could
-- never rotate the entire phone presentation.  This module wraps Game2:draw
-- itself: the complete finished frame is rendered to a window-sized canvas,
-- then that canvas is rotated 180 degrees onto the real target.  The matching
-- touch wrappers apply the inverse transform (which is the same 180-degree
-- transform), keeping Android's virtual pad and touch menus lined up with what
-- the player sees.
--
-- Android only.  Desktop behavior is deliberately untouched.

local V = ...
local mod = V and V.mod

local M = {
  installed = false,
  frames = 0,
  touches = 0,
  moves = 0,
  releases = 0,
  lastError = nil,
}

local androidCached = nil
local function isAndroid()
  if androidCached ~= nil then return androidCached end

  local okOS, name = pcall(function()
    local sys = love and love.system
    if sys and type(sys.getOS) == "function" then return sys.getOS() end
    return nil
  end)
  if okOS and (name == "Android" or name == "iOS") then
    androidCached = name == "Android"
    return androidCached
  end

  -- Prefer the engine-owned platform helper. Newer Gen1Recomp sandboxes do
  -- not expose raw love.system to mod chunks, while src.core.Platform is the
  -- engine-side capability detector.
  local okPlatform, Platform = pcall(require, "src.core.Platform")
  if okPlatform and type(Platform) == "table" and type(Platform.detect) == "function" then
    local okDetect, info = pcall(Platform.detect)
    if okDetect and type(info) == "table" and type(info.os) == "string" then
      androidCached = info.os == "Android"
      return androidCached
    end
  end

  -- Older builds do expose love.system. Keep this fallback fully inside a
  -- pcall so a sandboxed love proxy cannot turn platform detection into a
  -- boot-time crash.
  if okOS and type(name) == "string" then
    androidCached = name == "Android"
    return androidCached
  end

  local platform = rawget(_G, "PLATFORM")
  androidCached = type(platform) == "string"
    and string.lower(platform) == "android" or false
  return androidCached
end

local function enabled()
  if not isAndroid() then return false end
  local options = mod and mod.options
  if not (options and type(options.get) == "function") then return false end
  local ok, value = pcall(options.get, options, "screenFlip")
  return ok and value == true
end

local frameCanvas, frameW, frameH
local function ensureCanvas(w, h)
  if frameCanvas and frameW == w and frameH == h then return frameCanvas end
  local G = love and love.graphics
  if not (G and type(G.newCanvas) == "function") then return nil end
  local ok, canvas = pcall(G.newCanvas, w, h)
  if not ok or not canvas then return nil end
  if type(canvas.setFilter) == "function" then
    pcall(canvas.setFilter, canvas, "nearest", "nearest")
  end
  frameCanvas, frameW, frameH = canvas, w, h
  return canvas
end

local function dimensions()
  local G = love and love.graphics
  if not (G and type(G.getDimensions) == "function") then return nil, nil end
  local w, h = G.getDimensions()
  w, h = tonumber(w), tonumber(h)
  if not (w and h and w > 0 and h > 0) then return nil, nil end
  return math.max(1, math.floor(w + 0.5)), math.max(1, math.floor(h + 0.5))
end

local function remapPoint(x, y)
  if not enabled() then return x, y end
  local w, h = dimensions()
  if not (w and h) then return x, y end
  x, y = tonumber(x) or 0, tonumber(y) or 0
  return w - x, h - y
end

local function remapDelta(dx, dy)
  if not enabled() then return dx, dy end
  return -(tonumber(dx) or 0), -(tonumber(dy) or 0)
end

function M.install()
  if M.installed then return true end

  -- Never monkey-patch Game2:draw on desktop. v0.2.56 installed the wrapper
  -- on every platform even though the feature is Android-only; keeping this
  -- completely out of the desktop boot path restores the v0.2.45 behavior.
  local okAndroid, onAndroid = pcall(isAndroid)
  if not okAndroid or not onAndroid then
    M.installed = true
    M.platformActive = false
    if not okAndroid then M.lastError = tostring(onAndroid) end
    return true
  end
  M.platformActive = true

  local ok, Game2 = pcall(require, "src.core.Game2")
  if not (ok and type(Game2) == "table" and type(Game2.draw) == "function") then
    return false, "src.core.Game2.draw unavailable"
  end
  if Game2._stadium2WholeFrameFlipPatched then
    M.installed = true
    return true
  end

  local nativeDraw = Game2.draw
  Game2.draw = function(self, ...)
    if not enabled() then return nativeDraw(self, ...) end

    local G = love and love.graphics
    if not (G and type(G.setCanvas) == "function" and type(G.draw) == "function") then
      return nativeDraw(self, ...)
    end
    local w, h = dimensions()
    local canvas = w and ensureCanvas(w, h) or nil
    if not canvas then return nativeDraw(self, ...) end

    local previous = nil
    if type(G.getCanvas) == "function" then
      local okPrev, value = pcall(G.getCanvas)
      if okPrev then previous = value end
    end

    G.push("all")
    G.setCanvas(canvas)
    G.origin()
    G.clear(0, 0, 0, 1)

    local okDraw, err = pcall(nativeDraw, self, ...)

    -- Native Game2:draw restores the canvas it found on entry; make the target
    -- explicit anyway so an early-return path cannot leave us pointed at one
    -- of Game2's internal post-process canvases.
    G.setCanvas(previous)
    G.origin()
    G.setShader()
    G.setScissor()
    G.setBlendMode("alpha")
    G.setColor(1, 1, 1, 1)
    G.draw(canvas, w, h, math.pi)
    G.pop()

    if not okDraw then
      M.lastError = tostring(err)
      error(err, 0)
    end
    M.frames = M.frames + 1
    M.lastError = nil
  end

  local nativePressed = Game2.touchpressed
  if type(nativePressed) == "function" then
    Game2.touchpressed = function(self, id, x, y, dx, dy, pressure, ...)
      if enabled() then
        x, y = remapPoint(x, y)
        dx, dy = remapDelta(dx, dy)
        M.touches = M.touches + 1
      end
      return nativePressed(self, id, x, y, dx, dy, pressure, ...)
    end
  end

  local nativeMoved = Game2.touchmoved
  if type(nativeMoved) == "function" then
    Game2.touchmoved = function(self, id, x, y, dx, dy, pressure, ...)
      if enabled() then
        x, y = remapPoint(x, y)
        dx, dy = remapDelta(dx, dy)
        M.moves = M.moves + 1
      end
      return nativeMoved(self, id, x, y, dx, dy, pressure, ...)
    end
  end

  local nativeReleased = Game2.touchreleased
  if type(nativeReleased) == "function" then
    Game2.touchreleased = function(self, id, x, y, dx, dy, pressure, ...)
      if enabled() then
        x, y = remapPoint(x, y)
        dx, dy = remapDelta(dx, dy)
        M.releases = M.releases + 1
      end
      return nativeReleased(self, id, x, y, dx, dy, pressure, ...)
    end
  end

  Game2._stadium2WholeFrameFlipPatched = true
  M.installed = true
  return true
end

M.enabled = enabled
M.remapPoint = remapPoint
M.remapDelta = remapDelta

function M.status()
  return {
    installed = M.installed,
    enabled = enabled(),
    frames = M.frames,
    touches = M.touches,
    moves = M.moves,
    releases = M.releases,
    lastError = M.lastError,
    platformActive = M.platformActive == true,
    width = frameW,
    height = frameH,
  }
end

return M
