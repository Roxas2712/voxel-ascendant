-- Screen-space artwork painted into a world canvas needs one platform receipt.
--
-- Gen1Recomp's proven iOS world path uses one stable negative-Y canvas
-- correction in every device orientation.  Keep Crystal's 3D projection and
-- its world-space 2D companions (panorama, masks and weather) on that same
-- contract.  Crystal's MAP battle HUD is painted into that very canvas, so it
-- must use the same stable axis; only its direct final-target fallback skips
-- the contained-canvas transform.
-- Desktop and Android retain their established presentation paths.

local V = ...
local CanvasPresentation = {}

-- `love` is an empty proxy in the current mod sandbox.  rawget() therefore
-- sees none of its public modules and silently disables live orientation
-- sampling.  Ordinary indexing is the supported path; keep it contained in a
-- pcall because intentionally blocked modules (notably love.system) throw.
local function runtimeMember(runtime, key)
  if type(runtime) ~= "table" then return nil end
  local ok, value = pcall(function() return runtime[key] end)
  if ok then return value end
  return nil
end

local function detectedOS()
  -- A compatibility host may deliberately advertise macOS through Platform
  -- while the renderer underneath is the iOS/Android LÖVE backend.  Mobile
  -- safety policy must follow the renderer: otherwise a phone receives the
  -- desktop-sized scene/depth canvases and the desktop presentation transform.
  local runtime = love
  local system = runtimeMember(runtime, "system")
  local getOS = runtimeMember(system, "getOS")
  local nativeOS = nil
  if type(getOS) == "function" then
    local okNative, value = pcall(getOS)
    if okNative and type(value) == "string" and value ~= "" then
      nativeOS = value
      if value == "iOS" or value == "Android" then return value end
    end
  end
  local ok, Platform = pcall(require, "src.core.Platform")
  if ok and type(Platform) == "table"
      and type(Platform.detect) == "function" then
    local detected, info = pcall(Platform.detect)
    if detected and type(info) == "table" and type(info.os) == "string" then
      return info.os
    end
  end
  -- Gen1Recomp 0.1.90 has no Platform module. LÖVE publishes this immutable
  -- bootstrap value before love.conf, and reading it does not cross the mod
  -- sandbox into the denied system API.
  local osName = runtimeMember(runtime, "_os")
  if type(osName) == "string" and osName ~= "" then return osName end
  return nativeOS
end

CanvasPresentation.OS = detectedOS()

function CanvasPresentation.preflips(os)
  return (os or CanvasPresentation.OS) == "iOS"
end

CanvasPresentation.BATTLE_PRESENTATION_SCHEMA =
  "voxel-ascendant/battle-canvas-presentation/v1"
CanvasPresentation.WORLD_PRESENTATION_SCHEMA =
  "voxel-ascendant/world-canvas-presentation/v1"

local function displayOrientation()
  local runtime = love
  local window = runtimeMember(runtime, "window")
  local getter = runtimeMember(window, "getDisplayOrientation")
  if type(getter) ~= "function" then return nil end
  local ok, value = pcall(getter)
  if not ok or type(value) ~= "string" or value == "" then return nil end
  return value:lower()
end

-- Resolve the physical orientation for diagnostics.  Neither the world nor
-- the HUD baked into that same Crystal canvas may depend on this value:
-- Gen 1's working mobile renderer proves that its GL projection remains
-- clip-Y across portrait/landscape changes.  Moving the Gen-2 projection to X
-- for `landscapeflipped` differs from Y by 180 degrees and caused both the
-- Crystal world and its ORAS HUD to reverse while native text/touch stayed
-- upright.
local function presentation(schema, os, orientation, contract)
  local platform = os or CanvasPresentation.OS
  local receipt = {
    schema=schema,
    platform=platform, orientation=nil, axis=nil, source="not-ios",
  }
  if platform ~= "iOS" then return receipt end
  local sampled, source = orientation, "argument"
  if type(sampled) ~= "string" or sampled == "" then
    sampled = displayOrientation()
    source = sampled and "love.window" or "legacy-ios-y"
  else
    sampled = sampled:lower()
  end
  receipt.orientation = sampled or "unavailable"
  receipt.axis = "y"
  receipt.contract = contract
  receipt.source = source
  return receipt
end

function CanvasPresentation.battlePresentation(os, orientation)
  return presentation(
    CanvasPresentation.BATTLE_PRESENTATION_SCHEMA, os, orientation,
    "ios-scene-canvas-stable-y")
end

local function currentBattlePresentation(receipt, os, orientation)
  if type(receipt) == "table"
      and (receipt.schema == CanvasPresentation.BATTLE_PRESENTATION_SCHEMA
        or receipt.schema == CanvasPresentation.WORLD_PRESENTATION_SCHEMA) then
    return receipt
  end
  return CanvasPresentation.battlePresentation(os, orientation)
end

function CanvasPresentation.worldPresentation(os, orientation)
  return presentation(
    CanvasPresentation.WORLD_PRESENTATION_SCHEMA, os, orientation,
    "gen1-mobile-stable-y")
end

local activeWorldPresentation = nil

local function validWorldPresentation(receipt)
  return type(receipt) == "table"
    and receipt.schema == CanvasPresentation.WORLD_PRESENTATION_SCHEMA
end

local function normalizeWorldPresentation(receipt)
  if not validWorldPresentation(receipt) then return nil end
  if receipt.platform == "iOS" then
    receipt.axis = "y"
    receipt.contract = "gen1-mobile-stable-y"
  else
    receipt.axis = nil
    receipt.contract = "historical-world-clip-y"
  end
  return receipt
end

-- VoxelScene samples once at frame entry.  Weather and the shared weather
-- tweak paint later into that same canvas, so retaining this primitive receipt
-- lets all three passes use one orientation even if the OS rotates between
-- callbacks.  A nil receipt explicitly drops a stale frame.
function CanvasPresentation.setWorldPresentation(receipt)
  if receipt == nil then
    activeWorldPresentation = nil
    return true
  end
  receipt = normalizeWorldPresentation(receipt)
  if not receipt then return false end
  activeWorldPresentation = receipt
  return true
end

function CanvasPresentation.currentWorldPresentation(receipt, os, orientation)
  if validWorldPresentation(receipt) then
    return normalizeWorldPresentation(receipt)
  end
  if os == nil and orientation == nil
      and validWorldPresentation(activeWorldPresentation) then
    return normalizeWorldPresentation(activeWorldPresentation)
  end
  return CanvasPresentation.worldPresentation(os, orientation)
end

-- Mat4.perspective is GL-style while a LÖVE Canvas is Y-down.  Gen 1, desktop,
-- Android and Crystal all use the historical clip-Y correction.  Physical
-- device rotation is presentation metadata; it must never rotate the world
-- projection to the perpendicular axis.
function CanvasPresentation.worldClipScale(receipt, os, orientation)
  -- Resolve/validate the receipt so callers still sample one frame-local
  -- orientation for logging, even though the projection contract is stable.
  local current = CanvasPresentation.currentWorldPresentation(
    receipt, os, orientation)
  -- Gold's iOS world canvas is presented with the engine's Y reflection.
  -- Applying the desktop GL-to-canvas reflection as well inverted the entire
  -- Crystal scene while native text/touch stayed upright.  Desktop/Android
  -- retain their historical explicit clip-Y conversion.
  if current and current.platform == "iOS" then return 1, 1 end
  return 1, -1
end

function CanvasPresentation.beginBattle2D(g, w, h, receipt)
  receipt = currentBattlePresentation(receipt)
  if receipt.axis == nil then return true end
  if not (g and type(g.translate) == "function"
          and type(g.scale) == "function") then return false end
  if receipt.axis == "x" then
    if not (type(w) == "number" and w > 0) then return false end
    g.translate(w, 0)
    g.scale(-1, 1)
    return true
  end
  if receipt.axis == "y" then
    if not (type(h) == "number" and h > 0) then return false end
    g.translate(0, h)
    g.scale(1, -1)
    return true
  end
  return false
end

-- Scene actor projections describe their position in the unpresented battle
-- Canvas. HUD furniture is pre-flipped and later presented upright, so its
-- head anchors must first be converted into that final/upright space.
function CanvasPresentation.battlePointX(x, w, receipt, os, orientation)
  local current = currentBattlePresentation(receipt, os, orientation)
  if current.axis == "x" then return w - x end
  return x
end

function CanvasPresentation.battleRectX(x, rw, w, receipt, os, orientation)
  local current = currentBattlePresentation(receipt, os, orientation)
  if current.axis == "x" then return w - x - rw end
  return x
end

function CanvasPresentation.battlePointY(y, h, receipt, os, orientation)
  local current = currentBattlePresentation(receipt, os, orientation)
  if current.axis == "y" then return h - y end
  return y
end

function CanvasPresentation.battleRectY(y, rh, h, receipt, os, orientation)
  local current = currentBattlePresentation(receipt, os, orientation)
  if current.axis == "y" then return h - y - rh end
  return y
end

function CanvasPresentation.mobileWorldView(w, h, vw, vh, os)
  local platform = os or CanvasPresentation.OS
  if platform ~= "iOS" and platform ~= "Android" then
    return vw, vh, false
  end
  if not (type(w) == "number" and type(h) == "number"
          and type(vw) == "number" and type(vh) == "number"
          and w > 0 and h > 0 and vw > 0 and vh > 0) then
    return vw, vh, false
  end
  -- Preserve world-units per pixel and reveal more world on only the surplus
  -- phone axis.  Stretching the fixed 160x144 view over a very wide display
  -- made the player gigantic/cropped and left panorama coverage inconsistent.
  local unitsPerPixel = math.max(vw / w, vh / h)
  local renderVw, renderVh = w * unitsPerPixel, h * unitsPerPixel
  return renderVw, renderVh,
    math.abs(renderVw - vw) > 1e-9 or math.abs(renderVh - vh) > 1e-9
end

-- Aspect-preserving COVER placement for a complete image.  Rotating a phone
-- changes the canvas aspect immediately; stretching width and height
-- independently made every authored arena look squeezed until the next
-- launch.  COVER keeps one scale and crops the excess symmetrically.
function CanvasPresentation.cover(w, h, iw, ih)
  if not (w and h and iw and ih and w > 0 and h > 0 and iw > 0 and ih > 0)
  then
    return 0, 0, 1, w or 0, h or 0
  end
  local scale = math.max(w / iw, h / ih)
  local dw, dh = iw * scale, ih * scale
  return (w - dw) * .5, (h - dh) * .5, scale, dw, dh
end

-- Arguments for drawing a complete image into a w x h world canvas.  The
-- optional receipt is the one VoxelScene sampled for this frame.
function CanvasPresentation.imageDraw(w, h, iw, ih, os, receipt)
  local x, y, scale, dw, dh = CanvasPresentation.cover(w, h, iw, ih)
  local current = CanvasPresentation.currentWorldPresentation(receipt, os)
  if current.axis == "x" then
    return x + dw, y, 0, -scale, scale
  elseif current.axis == "y" then
    return x, y + dh, 0, scale, -scale
  end
  return x, y, 0, scale, scale
end

function CanvasPresentation.pointX(x, w, os, receipt)
  local current = CanvasPresentation.currentWorldPresentation(receipt, os)
  if current.axis == "x" then return w - x end
  return x
end

function CanvasPresentation.rectX(x, rw, w, os, receipt)
  local current = CanvasPresentation.currentWorldPresentation(receipt, os)
  if current.axis == "x" then return w - x - rw end
  return x
end

function CanvasPresentation.pointY(y, h, os, receipt)
  local current = CanvasPresentation.currentWorldPresentation(receipt, os)
  if current.axis == "y" then return h - y end
  return y
end

function CanvasPresentation.rectY(y, rh, h, os, receipt)
  local current = CanvasPresentation.currentWorldPresentation(receipt, os)
  if current.axis == "y" then return h - y - rh end
  return y
end

-- Apply the receipt to a contained screen-space world paint pass. The caller
-- owns push/pop, so this never leaks a transform into the 3D scene or the
-- engine's touch/menu overlay.
function CanvasPresentation.beginWorld2D(g, w, h, receipt, os)
  local current = CanvasPresentation.currentWorldPresentation(receipt, os)
  if current.axis == nil then return true end
  if not (g and type(g.translate) == "function"
          and type(g.scale) == "function") then
    return false
  end
  if current.axis == "x" then
    if not (type(w) == "number" and w > 0) then return false end
    g.translate(w, 0)
    g.scale(-1, 1)
    return true
  end
  if current.axis == "y" then
    if not (type(h) == "number" and h > 0) then return false end
    g.translate(0, h)
    g.scale(1, -1)
    return true
  end
  return false
end

local function activeCanvasWidth(g)
  if not g then return nil end
  if type(g.getCanvas) == "function" then
    local okCanvas, target = pcall(g.getCanvas)
    if okCanvas and target and type(target.getDimensions) == "function" then
      local okSize, w = pcall(target.getDimensions, target)
      if okSize and type(w) == "number" and w > 0 then return w end
    end
  end
  if type(g.getDimensions) == "function" then
    local okSize, w = pcall(g.getDimensions)
    if okSize and type(w) == "number" and w > 0 then return w end
  end
  return nil
end

-- Backwards-compatible entry used by the shared WeatherTweak module.  Its old
-- signature has no width.  Width discovery remains available for a foreign
-- legacy receipt, while VASC's stable-Y contract never needs it.
function CanvasPresentation.begin2D(g, h, os, receipt, w)
  local current = CanvasPresentation.currentWorldPresentation(receipt, os)
  if current.axis == "x" and not (type(w) == "number" and w > 0) then
    w = activeCanvasWidth(g)
  end
  return CanvasPresentation.beginWorld2D(g, w, h, current, os)
end

return CanvasPresentation
