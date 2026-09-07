-- Screen-space artwork painted into a world canvas needs one platform receipt.
--
-- Gen1Recomp's iOS presenter samples that canvas with a negative Y scale. 3D
-- geometry already arrives in the orientation expected by that presenter, but
-- ordinary LOVE draws (a full-frame Arena Scenery image, window masks and the
-- weather pass) do not.  Pre-flip only those 2D draws so the final iOS sample
-- puts them upright. Desktop and Android remain byte-semantic no-ops.

local V = ...
local CanvasPresentation = {}

-- `love` is an empty proxy in the current mod sandbox. rawget() therefore
-- misses public runtime members and can silently classify an iPhone as the
-- desktop compatibility host. Ordinary indexing is the supported path; keep
-- it contained because intentionally blocked members may throw.
local function runtimeMember(runtime, key)
  if type(runtime) ~= "table" then return nil end
  local ok, value = pcall(function() return runtime[key] end)
  if ok then return value end
  return nil
end

local function detectedOS()
  -- The packaged mobile runtime is allowed to expose a desktop-compatible
  -- Platform receipt while LÖVE itself still knows that the renderer is
  -- running on iOS/Android.  Every expensive phone policy (bounded scene
  -- canvas, unindexed GLES meshes, deferred panorama) keys off this value,
  -- so prefer an explicit mobile answer from love.system before consulting
  -- the engine compatibility layer.  A desktop answer is only a fallback:
  -- it must not mask the native mobile renderer as happened on iPhone.
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

-- Battle furniture shares the same contained world canvas as the correctly
-- oriented Gen-1 scene. That renderer has one stable negative-Y presentation
-- contract in every physical phone orientation. Switching the embedded HUD to
-- X for `landscapeflipped` differs by 180 degrees and mirrors only its pixels.
-- Sample orientation every frame for diagnostics, but never let it change the
-- presentation axis. Callers pass the exact receipt through provider pixels,
-- frost sampling and ownership diagnostics.
CanvasPresentation.BATTLE_PRESENTATION_SCHEMA =
  "voxel-ascendant/battle-canvas-presentation/v1"

local function displayOrientation()
  local runtime = love
  local window = runtimeMember(runtime, "window")
  local getter = runtimeMember(window, "getDisplayOrientation")
  if type(getter) ~= "function" then return nil end
  local ok, value = pcall(getter)
  if not ok or type(value) ~= "string" or value == "" then return nil end
  return value:lower()
end

function CanvasPresentation.battlePresentation(os, orientation)
  local platform = os or CanvasPresentation.OS
  local receipt = {
    schema = CanvasPresentation.BATTLE_PRESENTATION_SCHEMA,
    platform = platform,
    orientation = nil,
    axis = nil,
    source = "not-ios",
  }
  if platform ~= "iOS" then return receipt end

  local sampled = orientation
  local source = "argument"
  if type(sampled) ~= "string" or sampled == "" then
    sampled = displayOrientation()
    source = sampled and "love.window" or "legacy-ios-y"
  else
    sampled = sampled:lower()
  end
  -- `unknown` is a real LÖVE sentinel.  Preserve it in the receipt while
  -- falling back to the historically proven iOS Y correction.
  receipt.orientation = sampled or "unavailable"
  -- render.hud/provider pixels are already painted in the final orientation.
  -- The physical iOS run proved that adding a second Y reflection turns only
  -- the HUD/text upside down while the battle scene remains upright.
  receipt.axis = nil
  receipt.contract = "ios-final-hud-no-extra-reflection"
  receipt.source = source
  return receipt
end

-- Apply the battle receipt exactly once around a contained 2D HUD pass.  This
-- intentionally does not replace begin2D(): arena art, weather and other
-- screen-space layers retain their established platform-only Y contract.
function CanvasPresentation.beginBattle2D(g, w, h, receipt)
  if type(receipt) ~= "table"
      or receipt.schema ~= CanvasPresentation.BATTLE_PRESENTATION_SCHEMA then
    receipt = CanvasPresentation.battlePresentation()
  end
  local axis = receipt.axis
  if axis == nil then return true end
  if not (g and type(g.translate) == "function"
          and type(g.scale) == "function") then
    return false
  end
  if axis == "x" then
    if not (type(w) == "number" and w > 0) then return false end
    g.translate(w, 0)
    g.scale(-1, 1)
    return true
  end
  if axis == "y" then
    if not (type(h) == "number" and h > 0) then return false end
    g.translate(0, h)
    g.scale(1, -1)
    return true
  end
  return false
end

-- A phone can rotate without the emulated Game Boy viewport changing in the
-- same frame.  Passing that stale 160x144 view into a portrait (or very wide)
-- world canvas makes the projection fill two differently-shaped rectangles:
-- geometry is stretched and the player appears giant/cropped.  Preserve the
-- least magnified world-units-per-pixel and reveal more world on only the
-- surplus axis.  Desktop keeps the exact historical viewport.
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

  local unitsPerPixel = math.max(vw / w, vh / h)
  local renderVw, renderVh = w * unitsPerPixel, h * unitsPerPixel
  local changed = math.abs(renderVw - vw) > 1e-9
                  or math.abs(renderVh - vh) > 1e-9
  return renderVw, renderVh, changed
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

-- Arguments for drawing a complete image into a w x h canvas.
function CanvasPresentation.imageDraw(w, h, iw, ih, os)
  local x, y, scale, _, dh = CanvasPresentation.cover(w, h, iw, ih)
  if CanvasPresentation.preflips(os) then
    return x, y + dh, 0, scale, -scale
  end
  return x, y, 0, scale, scale
end

function CanvasPresentation.pointY(y, h, os)
  if CanvasPresentation.preflips(os) then return h - y end
  return y
end

function CanvasPresentation.rectY(y, rh, h, os)
  if CanvasPresentation.preflips(os) then return h - y - rh end
  return y
end

-- Apply the same pre-flip to a contained screen-space paint pass. The caller
-- owns push/pop, so this never leaks a transform into the 3D scene.
function CanvasPresentation.begin2D(g, h, os)
  if not CanvasPresentation.preflips(os) then return true end
  if not (g and type(g.translate) == "function"
          and type(g.scale) == "function") then
    return false
  end
  g.translate(0, h)
  g.scale(1, -1)
  return true
end

return CanvasPresentation
