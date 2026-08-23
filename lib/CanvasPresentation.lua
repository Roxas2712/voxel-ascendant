-- Screen-space artwork painted into a world canvas needs one platform receipt.
--
-- Gen1Recomp's iOS presenter samples that canvas with a negative Y scale. 3D
-- geometry already arrives in the orientation expected by that presenter, but
-- ordinary LOVE draws (a full-frame Arena Scenery image, window masks and the
-- weather pass) do not.  Pre-flip only those 2D draws so the final iOS sample
-- puts them upright. Desktop and Android remain byte-semantic no-ops.

local V = ...
local CanvasPresentation = {}

local function detectedOS()
  local ok, Platform = pcall(require, "src.core.Platform")
  if ok and type(Platform) == "table"
      and type(Platform.detect) == "function" then
    local detected, info = pcall(Platform.detect)
    if detected and type(info) == "table" and type(info.os) == "string" then
      return info.os
    end
  end
  return nil
end

CanvasPresentation.OS = detectedOS()

function CanvasPresentation.preflips(os)
  return (os or CanvasPresentation.OS) == "iOS"
end

-- Arguments for drawing a complete image into a w x h canvas.
function CanvasPresentation.imageDraw(w, h, iw, ih, os)
  if CanvasPresentation.preflips(os) then
    return 0, h, 0, w / iw, -h / ih
  end
  return 0, 0, 0, w / iw, h / ih
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
