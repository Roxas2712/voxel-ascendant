local V = ...

local PixelCanvas = {}

-- Every canvas attached to, copied from, or sampled beside the scene canvas
-- must obey the same physical-pixel rule. Preserve format/readability options
-- while preventing a high-density display from scaling only one attachment.
function PixelCanvas.new(w, h, options)
  local opts = {}
  for key, value in pairs(options or {}) do opts[key] = value end
  opts.dpiscale = 1
  return pcall(love.graphics.newCanvas, w, h, opts)
end

return PixelCanvas
