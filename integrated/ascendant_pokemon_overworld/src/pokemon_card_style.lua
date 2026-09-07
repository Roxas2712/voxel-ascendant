-- Optional GO/HD atlas postprocess. This is not normal-based 3D relighting.
-- The caller owns draw-state save/restore and admits only its normal scene pass.
local M = {}
local identity = {1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1}

M.shaderSource = [[
varying float cardShade;
#ifdef VERTEX
uniform mat4 vp; uniform mat4 model; uniform vec3 eye;
uniform vec3 curve; uniform float pull;
attribute float VertexShade;
vec4 position(mat4 transform_projection, vec4 vertex_position) {
  cardShade = VertexShade;
  vec4 w = model * vertex_position;
  if (curve.z > 0.0) {
    vec2 cd = w.xz - curve.xy;
    w.y -= dot(cd, cd) * curve.z;
  }
  if (pull > 0.0) w.xyz += normalize(eye - w.xyz) * pull;
  return vp * w;
}
#endif
#ifdef PIXEL
uniform vec4 cardCell; // current atlas cell edges, not alpha crop edges
uniform vec2 cardTexel;
uniform float cardOutlineWidth;
uniform float cardToon;
uniform float cardAlphaPass;
float cellAlpha(Image tex, vec2 uv) {
  // Test before clamping: adjacent cells are never allowed to contribute.
  if (uv.x < cardCell.x || uv.y < cardCell.y ||
      uv.x >= cardCell.z || uv.y >= cardCell.w) return 0.0;
  vec2 lo = cardCell.xy + cardTexel * 0.5;
  vec2 hi = cardCell.zw - cardTexel * 0.5;
  return Texel(tex, clamp(uv, lo, hi)).a;
}
vec3 softToon(vec3 rgb) {
  // Quantize only a small fraction of VALUE, not hue/saturation. Uniform RGB
  // scaling preserves channel ratios, with <= .011 absolute channel change.
  float value = max(rgb.r, max(rgb.g, rgb.b));
  float band = floor(value * 7.0 + 0.5) / 7.0;
  float target = mix(value, band, 0.15 * cardToon);
  if (cardToon > 1.5) {
    // Optional comic ink: stronger value-only cel bands, never RGB channel
    // quantization or white mixing. Hue/saturation and source alpha survive.
    band = floor(value * 4.0 + 0.5) / 4.0;
    target = mix(value, band, 0.60);
  }
  return value > 0.00001 ? rgb * (target / value) : rgb;
}
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
  vec2 lo = cardCell.xy + cardTexel * 0.5;
  vec2 hi = cardCell.zw - cardTexel * 0.5;
  vec4 p = Texel(tex, clamp(tc, lo, hi));
  float inside = cellAlpha(tex, tc);
  if (cardAlphaPass > 1.5) {
    if (inside <= 0.001 || inside >= 0.999) discard;
    return vec4(softToon(p.rgb) * cardShade, inside) * color;
  }
  if (cardAlphaPass > 0.5 && inside > 0.001 && inside < 0.999) discard;
  if (inside >= 0.5) {
    return vec4(softToon(p.rgb) * cardShade, 1.0) * color;
  }
  vec2 d = cardTexel * cardOutlineWidth;
  float edge = 0.0;
  edge = max(edge, cellAlpha(tex, tc + vec2(d.x, 0.0)));
  edge = max(edge, cellAlpha(tex, tc - vec2(d.x, 0.0)));
  edge = max(edge, cellAlpha(tex, tc + vec2(0.0, d.y)));
  edge = max(edge, cellAlpha(tex, tc - vec2(0.0, d.y)));
  edge = max(edge, cellAlpha(tex, tc + d * 0.70710678));
  edge = max(edge, cellAlpha(tex, tc - d * 0.70710678));
  edge = max(edge, cellAlpha(tex, tc + vec2(d.x, -d.y) * 0.70710678));
  edge = max(edge, cellAlpha(tex, tc + vec2(-d.x, d.y) * 0.70710678));
  if (edge < 0.5) discard;
  vec3 ink = cardToon > 1.5 ? vec3(0.035, 0.040, 0.055) : vec3(0.055, 0.060, 0.070);
  float inkAlpha = cardToon > 1.5 ? 0.96 : 0.88;
  return vec4(ink, smoothstep(0.5, 0.85, edge) * inkAlpha) * color;
}
#endif
]]

function M.mode(value)
  return (value == "outline" or value == "anime" or value == "comic") and value or "off"
end

local function finite(value)
  return type(value) == "number" and value == value
    and value ~= math.huge and value ~= -math.huge
end

-- Identity is explicit: never infer GO from a filename, a dex or a 3D look.
function M.descriptor(spec)
  if type(spec) ~= "table" or M.mode(spec.mode) == "off"
      or spec.source ~= "go" or spec.pixelArt == true
      or spec.legacyCyndaquil == true
      or (spec.kind ~= "animation-cards" and spec.kind ~= "hd-cards") then
    return nil
  end
  local iw, ih, columns, rows = spec.imageWidth, spec.imageHeight,
    spec.columns, spec.rows or 4
  local column, row = spec.column, spec.row
  for _, value in ipairs({iw, ih, columns, rows, column, row}) do
    if not finite(value) or value % 1 ~= 0 then return nil end
  end
  if not (iw and ih and columns and rows and column and row)
      or iw < 1 or ih < 1 or columns < 1 or rows < 1
      or iw % columns ~= 0 or ih % rows ~= 0
      or column < 0 or column >= columns or row < 0 or row >= rows then
    return nil
  end
  local mode = M.mode(spec.mode)
  local width = mode == "comic" and 1.6 or mode == "anime" and 1.2 or 1.0
  return { mode=M.mode(spec.mode), width=width,
    toon=mode == "comic" and 2 or mode == "anime" and 1 or 0,
    cell={column/columns, row/rows, (column+1)/columns, (row+1)/rows},
    texel={1/iw, 1/ih}, imageWidth=iw, imageHeight=ih,
    cellPixels={column*iw/columns,row*ih/rows,
      (column+1)*iw/columns,(row+1)*ih/rows} }
end

-- Ensure the shader has geometry on which to draw the OUTSIDE silhouette.
-- Shared root/referenceHeight anchoring remains unchanged. Legacy cards gain
-- an equivalent anchor contract BEFORE padding, so feet/body do not shift.
function M.paddedBounds(bounds, descriptor)
  if not descriptor or type(bounds) ~= "table" then return bounds, 1 end
  local result = {}
  for key, value in pairs(bounds) do result[key] = value end
  local c, pad = descriptor.cellPixels, math.ceil(descriptor.width + 1)
  result.left = math.max(c[1], bounds.left-pad)
  result.top = math.max(c[2], bounds.top-pad)
  result.right = math.min(c[3], bounds.right+pad)
  result.bottom = math.min(c[4], bounds.bottom+pad)
  if not bounds.layout then
    result.cellX, result.cellY = bounds.cellX or c[1], bounds.cellY or c[2]
    result.layout = {referenceHeight=math.max(1,bounds.bottom-bounds.top),
      anchorX=(bounds.left+bounds.right)/2-result.cellX,
      anchorY=bounds.bottom-result.cellY}
  end
  return result, 1
end

function M.new()
  local self = {shader=nil,error=nil}
  function self:prepare(graphics, scene, model, pull, spec)
    local descriptor = M.descriptor(spec)
    if not descriptor then return nil end
    if type(graphics) ~= "table" or type(graphics.newShader) ~= "function"
        or type(scene) ~= "table" then return nil end
    if self.shader == nil then
      local ok, value = pcall(graphics.newShader, M.shaderSource)
      self.shader = ok and value or false
      if not ok then self.error = tostring(value) end
    end
    if not self.shader then return nil end
    local ok, err = pcall(function()
      self.shader:send("vp", "row", scene.vp)
      self.shader:send("model", "row", model or identity)
      self.shader:send("eye", scene.eye)
      self.shader:send("curve", {scene.curveX or 0, scene.curveZ or 0, scene.curveK or 0})
      self.shader:send("pull", pull or 0)
      self.shader:send("cardCell", descriptor.cell)
      self.shader:send("cardTexel", descriptor.texel)
      self.shader:send("cardOutlineWidth", descriptor.width)
      self.shader:send("cardToon", descriptor.toon)
      self.shader:send("cardAlphaPass", 0)
    end)
    if not ok then self.error = tostring(err) return nil end
    return self.shader, descriptor
  end
  return self
end

return M
