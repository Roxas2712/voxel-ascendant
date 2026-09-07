-- Opt-in FRLG artwork in the VASC ORAS visual language.
--
-- This adapter replaces only `draw` on an already-built Bag ListMenu. Update,
-- input, callbacks, items and provider pocket state remain exactly native.

local V = ...
local Base = V.require("OrasBagSkin")

local M = {
  apiVersion = 1,
  owner = "voxel_ascendant.oras_frlg_bag",
  width = 160,
  height = 144,
  assetPath = "assets/ui/frlg-oras-bag-3865.png",
}
M.OWNER, M.WIDTH, M.HEIGHT, M.ASSET_PATH =
  M.owner, M.width, M.height, M.assetPath
M.WIDE_WIDTH, M.WIDE_HEIGHT = 512, 288
M.POCKET_ICON_ASSET_PATH = Base.POCKET_ICON_ASSET_PATH
M.POCKET_ICON_ATLAS = Base.POCKET_ICON_ATLAS
M.RECOLOR_SCOPE = "exact_accent_and_body_swatches_only"
M.ATLAS = { cell = 64, columns = 5, rows = 2, width = 320, height = 128 }

local unpackValues = table.unpack or unpack

local function packed(...)
  return { n = select("#", ...), ... }
end

local function traceback(message)
  if debug and type(debug.traceback) == "function" then
    return debug.traceback(tostring(message), 2)
  end
  return tostring(message)
end

local function safeRequire(name)
  local ok, value = pcall(require, name)
  return ok and type(value) == "table" and value or nil
end

local function clamp(value, low, high)
  return math.max(low, math.min(high, value))
end

local function pixel(value)
  if value < 0 then return math.ceil(value - 0.5) end
  return math.floor(value + 0.5)
end

local function integer(value, fallback)
  value = tonumber(value)
  return value and math.floor(value) or fallback
end

local function externalOwnerOf(list)
  if Base.isDecorated(list) then return Base.OWNER, "__vascOrasBagSkin" end
  return Base.externalOwnerOf(list, M.owner)
end

local function battleBelow(list)
  local game = type(list) == "table" and rawget(list, "game") or nil
  local stack = type(game) == "table" and game.stack or nil
  local states = type(stack) == "table" and stack.states or nil
  if type(states) ~= "table" then return false end
  local found = false
  for index = #states, 1, -1 do
    local state = states[index]
    if state == list then
      found = true
    elseif found and type(state) == "table" and state.isBattle == true then
      return true
    end
  end
  return false
end

function M.externalOwnerOf(list)
  return externalOwnerOf(list)
end

function M.isDecorated(list)
  return type(list) == "table"
    and rawget(list, "__vascOrasFrlgBagPresentation") == true
    and rawget(list, "__vascOrasFrlgBagOwner") == M.owner
end

function M.ownerOf(list)
  if M.isDecorated(list) then return M.owner, "__vascOrasFrlgBagPresentation" end
  return externalOwnerOf(list)
end

function M.yieldReason(list, opts)
  opts = type(opts) == "table" and opts or {}
  if opts.force == true then return nil end
  local owner, marker = externalOwnerOf(list)
  if owner then return "external_owner:" .. owner, marker end
  return nil
end

function M.canDecorate(list, opts)
  if type(list) ~= "table" then return false, "invalid_list" end
  if M.isDecorated(list) then return false, "already_decorated" end
  if type(rawget(list, "draw") or list.draw) ~= "function" then
    return false, "missing_draw"
  end
  if type(rawget(list, "items") or list.items) ~= "table" then
    return false, "missing_items"
  end
  local reason, marker = M.yieldReason(list, opts)
  if reason then return false, reason, marker end
  return true
end

M.canDecorateBag = M.canDecorate
M.shouldYield = function(list, opts)
  local reason, marker = M.yieldReason(list, opts)
  return reason ~= nil, reason, marker
end

local C = {
  navy = { 12 / 255, 37 / 255, 84 / 255, 1 },
  navy2 = { 5 / 255, 24 / 255, 61 / 255, 1 },
  blue = { 23 / 255, 75 / 255, 142 / 255, 1 },
  orange = { 244 / 255, 91 / 255, 12 / 255, 1 },
  orange2 = { 255 / 255, 145 / 255, 22 / 255, 1 },
  gold = { 255 / 255, 194 / 255, 44 / 255, 1 },
  cream = { 255 / 255, 247 / 255, 218 / 255, 1 },
  paper = { 255 / 255, 252 / 255, 236 / 255, 1 },
  glass = { 158 / 255, 215 / 255, 244 / 255, 1 },
  glass2 = { 202 / 255, 238 / 255, 251 / 255, 1 },
  sky = { 31 / 255, 158 / 255, 219 / 255, 1 },
  skyLight = { 100 / 255, 207 / 255, 240 / 255, 1 },
  sea = { 5 / 255, 113 / 255, 183 / 255, 1 },
  ink = { 5 / 255, 24 / 255, 61 / 255, 1 },
  white = { 1, 1, 1, 1 },
  shadow = { 5 / 255, 24 / 255, 61 / 255, 0.28 },
}

local ACCENTS = {
  red = {
    dark = { 0.36, 0.04, 0.08 }, mid = { 0.82, 0.14, 0.17 },
    light = { 1.00, 0.43, 0.32 },
  },
  blue = {
    dark = { 0.02, 0.12, 0.31 }, mid = { 0.09, 0.29, 0.56 },
    light = { 0.39, 0.81, 0.94 },
  },
  green = {
    dark = { 0.03, 0.23, 0.16 }, mid = { 0.10, 0.53, 0.32 },
    light = { 0.49, 0.84, 0.50 },
  },
}
M.ACCENT_PALETTES = ACCENTS

local BODY_PALETTES = {
  red = {
    dark = { 0.36, 0.04, 0.08 }, mid = { 0.82, 0.14, 0.17 },
    light = { 1.00, 0.43, 0.32 },
  },
  blue = {
    dark = { 0.02, 0.12, 0.31 }, mid = { 0.09, 0.29, 0.56 },
    light = { 0.39, 0.81, 0.94 },
  },
  yellow = {
    dark = { 0.42, 0.27, 0.02 }, mid = { 0.88, 0.62, 0.05 },
    light = { 1.00, 0.88, 0.27 },
  },
  gold = {
    dark = { 0.34, 0.22, 0.05 }, mid = { 0.70, 0.49, 0.10 },
    light = { 0.94, 0.75, 0.30 },
  },
  silver = {
    dark = { 0.24, 0.30, 0.39 }, mid = { 0.55, 0.63, 0.72 },
    light = { 0.87, 0.92, 0.96 },
  },
  crystal = {
    dark = { 0.03, 0.26, 0.31 }, mid = { 0.16, 0.62, 0.70 },
    light = { 0.55, 0.91, 0.94 },
  },
}
BODY_PALETTES.oras = BODY_PALETTES.gold
M.BODY_PALETTES = BODY_PALETTES

local function color(g, value)
  g.setColor(value[1], value[2], value[3], value[4])
end

local function panel(g, x, y, width, height, outside, inside, radius)
  radius = radius or 3
  color(g, C.shadow)
  g.rectangle("fill", x + 1, y + 1, width, height, radius, radius)
  color(g, outside)
  g.rectangle("fill", x, y, width, height, radius, radius)
  color(g, inside)
  g.rectangle("fill", x + 2, y + 2,
    math.max(0, width - 4), math.max(0, height - 4),
    math.max(0, radius - 1), math.max(0, radius - 1))
end

local function timeNow()
  local loveRef = rawget(_G, "love")
  local timer = loveRef and loveRef.timer
  if timer and type(timer.getTime) == "function" then
    local ok, value = pcall(timer.getTime)
    if ok and type(value) == "number" then return value end
  end
  return 0
end

local function fontWidth(Font, value)
  local ok, width = pcall(Font.width, tostring(value or ""))
  return ok and type(width) == "number" and width
    or #tostring(value or "") * 8
end

local function truncate(Font, value, budget)
  local text = tostring(value or "")
  if fontWidth(Font, text) <= budget then return text end
  if type(Font.split) == "function" and type(Font.spansFitting) == "function" then
    local spans = Font.split(text)
    local fit = Font.spansFitting(spans, math.max(0, budget - 8))
    if fit < 1 then return "." end
    return text:sub(1, spans[fit].to) .. "."
  end
  return text:sub(1, math.max(1, math.floor(budget / 8) - 1)) .. "."
end

local function languageOf(list, config)
  local value = config.language or rawget(list, "language")
    or rawget(list, "__language")
  if value == nil then
    local game = rawget(list, "game")
    local save = type(game) == "table" and game.save or nil
    local options = type(save) == "table" and save.options or nil
    value = type(options) == "table" and options.language
      or (type(game) == "table" and game.language)
  end
  return tostring(value or "en"):lower():match("^de") and "de" or "en"
end

local function tr(language, english, german)
  return language == "de" and german or english
end

local function localizedBagTitle(value, language)
  value = tostring(value or "")
  if language ~= "de" then return value end
  return ({
    ["BAG"]="TASCHE", ["ITEM"]="GEGENSTAND",
    ["ITEMS"]="GEGENSTÄNDE",
    ["MEDICINE"]="MEDIZIN", ["MEDS"]="MEDIZIN",
    ["BALLS"]="BÄLLE", ["POKé BALLS"]="POKéBÄLLE",
    ["BATTLE"]="KAMPF", ["BATTLE ITEMS"]="KAMPF-GEGENSTÄNDE",
    ["KEY ITEMS"]="BASIS-GEGENSTÄNDE",
    ["BASIS-ITEMS"]="BASIS-GEGENSTÄNDE",
  })[value] or value
end

local function scissorState(g)
  if type(g.getScissor) ~= "function" then return nil end
  local values = packed(pcall(g.getScissor))
  if not values[1] then return nil end
  return { known = true, active = values[2] ~= nil,
    values = { values[2], values[3], values[4], values[5] } }
end

local function restoreScissor(g, state)
  if type(g.setScissor) ~= "function" then return end
  if state and state.known and state.active then
    pcall(g.setScissor, unpackValues(state.values, 1, 4))
  else
    pcall(g.setScissor)
  end
end

local function withScissor(g, x, y, width, height, callback)
  if type(g.setScissor) ~= "function" then return callback() end
  local previous = scissorState(g)
  g.setScissor(x, y, width, height)
  local ok, result = xpcall(function() return packed(callback()) end, traceback)
  restoreScissor(g, previous)
  if not ok then error(result, 0) end
  return unpackValues(result, 1, result.n)
end

local function graphicsState(g)
  local state = { scissor = scissorState(g) }
  if type(g.getColor) == "function" then
    local values = packed(pcall(g.getColor))
    if values[1] then state.color = { values[2], values[3], values[4], values[5] } end
  end
  if type(g.getLineWidth) == "function" then
    local ok, value = pcall(g.getLineWidth)
    if ok then state.lineWidth = value end
  end
  if type(g.getShader) == "function" then
    local ok, value = pcall(g.getShader)
    if ok then state.shaderKnown, state.shader = true, value end
  end
  return state
end

local function restoreGraphics(g, state)
  restoreScissor(g, state.scissor)
  if state.shaderKnown and type(g.setShader) == "function" then
    if state.shader ~= nil then pcall(g.setShader, state.shader)
    else pcall(g.setShader) end
  end
  if state.lineWidth ~= nil and type(g.setLineWidth) == "function" then
    pcall(g.setLineWidth, state.lineWidth)
  end
  if state.color then pcall(g.setColor, unpackValues(state.color, 1, 4))
  else pcall(g.setColor, 1, 1, 1, 1) end
end

local function restoreCanvas(g, canvas)
  if canvas ~= nil then g.setCanvas(canvas) else g.setCanvas() end
end

local function resolveWideLayer(config, g)
  if type(g) ~= "table" or type(g.newCanvas) ~= "function"
      or type(g.setCanvas) ~= "function" or type(g.getCanvas) ~= "function"
      or type(g.push) ~= "function" or type(g.pop) ~= "function"
      or type(g.clear) ~= "function" or type(g.draw) ~= "function" then
    return nil, "FRLG ORAS WIDE Bag staging canvas is unavailable"
  end
  local okCanvas, canvasOrError = pcall(g.getCanvas)
  if not okCanvas then return nil, tostring(canvasOrError) end
  local layer = config.wideLayer
  if layer then
    if type(layer.getDimensions) ~= "function" then
      layer = nil
    else
      local ok, width, height = pcall(layer.getDimensions, layer)
      if not ok or width ~= M.WIDE_WIDTH or height ~= M.WIDE_HEIGHT then
        layer = nil
      end
    end
  end
  if not layer then
    local ok, created = pcall(g.newCanvas, M.WIDE_WIDTH, M.WIDE_HEIGHT,
      { dpiscale=1 })
    if not ok or not created then
      return nil, tostring(created or
        "FRLG ORAS WIDE Bag canvas allocation failed")
    end
    layer, config.wideLayer = created, created
    if type(layer.setFilter) == "function" then
      pcall(layer.setFilter, layer, "nearest", "nearest")
    end
  end
  return layer
end

-- Keep the complete 512x288 composition private until every draw succeeds.
-- A failed provider/font/graphics call can then yield to the native renderer
-- without leaving FRLG-wide furniture in the authoritative target.
local function drawWideAtomically(config, g, callback)
  local layer, layerError = resolveWideLayer(config, g)
  if not layer then return false, layerError end

  local okCanvas, previousCanvas = pcall(g.getCanvas)
  if not okCanvas then return false, previousCanvas end
  local pushed, returned = false, nil
  local ok, err = xpcall(function()
    g.push("all")
    pushed = true
    g.setCanvas(layer)
    if type(g.origin) == "function" then g.origin() end
    if type(g.setShader) == "function" then g.setShader() end
    if type(g.setScissor) == "function" then g.setScissor() end
    if type(g.setBlendMode) == "function" then g.setBlendMode("alpha") end
    g.clear(0, 0, 0, 0)
    returned = packed(callback())
    g.pop()
    pushed = false
    restoreCanvas(g, previousCanvas)

    g.push("all")
    pushed = true
    if type(g.origin) == "function" then g.origin() end
    if type(g.setShader) == "function" then g.setShader() end
    if type(g.setScissor) == "function" then g.setScissor() end
    if type(g.setBlendMode) == "function" then g.setBlendMode("alpha") end
    g.setColor(1, 1, 1, 1)
    g.draw(layer, 0, 0)
    g.pop()
    pushed = false
  end, traceback)
  if pushed then pcall(g.pop) end
  pcall(restoreCanvas, g, previousCanvas)
  if not ok then return false, err end
  return true, returned
end

local function drawNativeWideFallback(config, g, callback)
  if type(g) ~= "table" or type(g.translate) ~= "function"
      or type(g.scale) ~= "function" then
    return false, "FRLG ORAS WIDE Bag native fallback transform is unavailable"
  end
  local ok, returned = drawWideAtomically(config, g, function()
    g.translate(math.floor((M.WIDE_WIDTH - M.WIDTH * 2) / 2), 0)
    g.scale(2, 2)
    return callback()
  end)
  if ok then
    local PaletteFX = config.PaletteFX or safeRequire("src.render.PaletteFX")
    if PaletteFX and type(PaletteFX.markTrueColor) == "function" then
      pcall(PaletteFX.markTrueColor, 0, 0, M.WIDE_WIDTH, M.WIDE_HEIGHT)
    end
  end
  return ok, returned
end

local function drawPokeBall(g, cx, cy, radius, active, hollow)
  radius, cx, cy = math.max(2, math.floor(radius)), pixel(cx), pixel(cy)
  for dy = -radius, radius do
    local half = math.floor(math.sqrt(math.max(0, radius * radius - dy * dy)))
    if not hollow then
      color(g, dy < 0 and (active and C.orange2 or C.orange) or C.cream)
      g.rectangle("fill", cx - half, cy + dy, half * 2 + 1, 1)
    end
    color(g, C.navy)
    g.rectangle("fill", cx - half, cy + dy, 1, 1)
    if half > 0 then g.rectangle("fill", cx + half, cy + dy, 1, 1) end
  end
  color(g, C.navy)
  g.rectangle("fill", cx - radius, cy, radius * 2 + 1, 1)
  g.rectangle("fill", cx - 1, cy - 1, 3, 3)
  color(g, hollow and C.paper or C.white)
  g.rectangle("fill", cx, cy, 1, 1)
end

local function renderPokeBall(config, g, ...)
  if type(config.drawPokeBall) == "function" then
    local ok = pcall(config.drawPokeBall, g, ...)
    if ok then return end
  end
  drawPokeBall(g, ...)
end

local SHADER_SOURCE = [[
extern vec3 accentDark;
extern vec3 accentMid;
extern vec3 accentLight;
extern float recolorAmount;
extern vec3 bodyDark;
extern vec3 bodyMid;
extern vec3 bodyLight;
extern float bodyRecolorAmount;

float exactPaletteColour(vec3 pixel, vec3 paletteColour) {
  vec3 difference = abs(pixel - paletteColour);
  return 1.0 - step(0.006, max(max(difference.r, difference.g), difference.b));
}

float exactCell(float value, float expected) {
  return 1.0 - step(0.1, abs(value - expected));
}

float insideBox(vec2 point, vec4 bounds) {
  return step(bounds.x, point.x) * step(bounds.y, point.y)
    * step(point.x, bounds.z) * step(point.y, bounds.w);
}

vec4 effect(vec4 drawColor, Image texture, vec2 textureCoords, vec2 screenCoords) {
  vec4 pixel = Texel(texture, textureCoords);
  // Exact authored insert/interior swatches from asset 3865. Body cloth uses
  // its own disjoint mask below; navy outlines never enter either mask.
  float blueSurface = max(
    exactPaletteColour(pixel.rgb, vec3(82.0, 123.0, 198.0) / 255.0),
    exactPaletteColour(pixel.rgb, vec3(107.0, 165.0, 222.0) / 255.0));
  float redInsert = max(
    exactPaletteColour(pixel.rgb, vec3(222.0, 57.0, 0.0) / 255.0),
    exactPaletteColour(pixel.rgb, vec3(247.0, 115.0, 0.0) / 255.0));
  float pinkInsert = max(
    exactPaletteColour(pixel.rgb, vec3(231.0, 148.0, 99.0) / 255.0),
    exactPaletteColour(pixel.rgb, vec3(255.0, 173.0, 123.0) / 255.0));
  vec2 atlasPixel = floor(textureCoords * vec2(320.0, 128.0));
  vec2 cellPixel = mod(atlasPixel, 64.0);
  float column = floor(atlasPixel.x / 64.0);
  float row = floor(atlasPixel.y / 64.0);
  float navySource = exactPaletteColour(
    pixel.rgb, vec3(66.0, 74.0, 107.0) / 255.0);
  // The deep navy swatch is shared by outlines and pocket interiors. Only
  // these authored interior rectangles participate; every outline stays navy.
  float itemInterior = exactCell(column, 1.0) * max(
    exactCell(row, 0.0) * insideBox(cellPixel, vec4(10.0, 46.0, 17.0, 54.0)),
    exactCell(row, 1.0) * insideBox(cellPixel, vec4(8.0, 36.0, 16.0, 41.0)));
  float keyInterior = exactCell(column, 2.0) * max(
    exactCell(row, 0.0) * insideBox(cellPixel, vec4(19.0, 36.0, 44.0, 45.0)),
    exactCell(row, 1.0) * insideBox(cellPixel, vec4(18.0, 25.0, 45.0, 30.0)));
  float ballInterior = exactCell(column, 3.0) * max(
    exactCell(row, 0.0) * insideBox(cellPixel, vec4(46.0, 46.0, 53.0, 54.0)),
    exactCell(row, 1.0) * insideBox(cellPixel, vec4(47.0, 36.0, 55.0, 41.0)));
  float pocketInterior = navySource
    * max(itemInterior, max(keyInterior, ballInterior));
  float accentPixel = max(max(blueSurface, redInsert),
    max(pinkInsert, pocketInterior));
  float bodyPixel = max(max(max(
    exactPaletteColour(pixel.rgb, vec3(255.0, 231.0, 123.0) / 255.0),
    exactPaletteColour(pixel.rgb, vec3(239.0, 206.0, 99.0) / 255.0)),
    max(
      exactPaletteColour(pixel.rgb, vec3(165.0, 123.0, 66.0) / 255.0),
      exactPaletteColour(pixel.rgb, vec3(214.0, 173.0, 99.0) / 255.0))),
    exactPaletteColour(pixel.rgb, vec3(255.0, 247.0, 181.0) / 255.0));
  float luminance = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));
  vec3 lowShade = mix(accentDark, accentMid,
    smoothstep(0.12, 0.58, luminance));
  vec3 target = mix(lowShade, accentLight,
    smoothstep(0.58, 0.94, luminance));
  pixel.rgb = mix(pixel.rgb, target, accentPixel * recolorAmount);
  vec3 bodyLowShade = mix(bodyDark, bodyMid,
    smoothstep(0.12, 0.58, luminance));
  vec3 bodyTarget = mix(bodyLowShade, bodyLight,
    smoothstep(0.58, 0.94, luminance));
  pixel.rgb = mix(pixel.rgb, bodyTarget, bodyPixel * bodyRecolorAmount);
  return pixel * drawColor;
}
]]

local SOURCE_ACCENT_COLOURS = {
  { 82, 123, 198 }, { 107, 165, 222 },
  { 222, 57, 0 }, { 247, 115, 0 },
  { 231, 148, 99 }, { 255, 173, 123 },
}
M.SOURCE_ACCENT_COLOURS = SOURCE_ACCENT_COLOURS

local SOURCE_BODY_COLOURS = {
  { 255, 231, 123 }, { 239, 206, 99 }, { 165, 123, 66 },
  { 214, 173, 99 }, { 255, 247, 181 },
}
M.SOURCE_BODY_COLOURS = SOURCE_BODY_COLOURS

function M.isBodySourcePixel(red, green, blue)
  red, green, blue = pixel(tonumber(red) or -1),
    pixel(tonumber(green) or -1), pixel(tonumber(blue) or -1)
  for _, source in ipairs(SOURCE_BODY_COLOURS) do
    if red == source[1] and green == source[2] and blue == source[3] then
      return true
    end
  end
  return false
end

-- Mirrors the shader's exact 8-bit palette classification. This lets the
-- headless contract prove that representative cloth colours are untouched.
local function pocketInterior(column, row, x, y)
  if column == 1 then
    return row == 0 and x >= 10 and x <= 17 and y >= 46 and y <= 54
      or row == 1 and x >= 8 and x <= 16 and y >= 36 and y <= 41
  elseif column == 2 then
    return row == 0 and x >= 19 and x <= 44 and y >= 36 and y <= 45
      or row == 1 and x >= 18 and x <= 45 and y >= 25 and y <= 30
  elseif column == 3 then
    return row == 0 and x >= 46 and x <= 53 and y >= 46 and y <= 54
      or row == 1 and x >= 47 and x <= 55 and y >= 36 and y <= 41
  end
  return false
end

function M.isAccentSourcePixel(red, green, blue, column, row, x, y)
  red, green, blue = pixel(tonumber(red) or -1),
    pixel(tonumber(green) or -1), pixel(tonumber(blue) or -1)
  for _, source in ipairs(SOURCE_ACCENT_COLOURS) do
    if red == source[1] and green == source[2] and blue == source[3] then
      return true
    end
  end
  return red == 66 and green == 74 and blue == 107
    and pocketInterior(integer(column, -1), integer(row, -1),
      integer(x, -1), integer(y, -1))
end

local function imageOf(config)
  if config.imageResolved then return config.image or nil end
  config.imageResolved = true
  local image = config.image
  if not image and type(config.loadImage) == "function" then
    local ok, loaded = pcall(config.loadImage, M.ASSET_PATH)
    if ok then image = loaded else config.imageError = tostring(loaded) end
  end
  if not image then return nil end
  if type(image.setFilter) == "function" then
    pcall(image.setFilter, image, "nearest", "nearest")
  end
  local ok, width, height = pcall(function()
    return image:getWidth(), image:getHeight()
  end)
  if not ok or width < M.ATLAS.width or height < M.ATLAS.height then
    config.imageError = "invalid FRLG ORAS atlas dimensions"
    return nil
  end
  config.image, config.imageWidth, config.imageHeight = image, width, height
  return image
end

local function shaderOf(g, config, accent, body)
  if config.shaderFailed or type(g.newShader) ~= "function"
      or type(g.setShader) ~= "function" then return nil end
  if not config.shader then
    local ok, shader = pcall(g.newShader, SHADER_SOURCE)
    if not ok or not shader then
      config.shaderFailed, config.shaderError = true, tostring(shader)
      return nil
    end
    config.shader = shader
  end
  local palette = ACCENTS[accent] or ACCENTS.red
  local bodyPalette = BODY_PALETTES[body] or BODY_PALETTES.oras
  local ok, err = pcall(function()
    config.shader:send("accentDark", palette.dark)
    config.shader:send("accentMid", palette.mid)
    config.shader:send("accentLight", palette.light)
    config.shader:send("recolorAmount", 1)
    config.shader:send("bodyDark", bodyPalette.dark)
    config.shader:send("bodyMid", bodyPalette.mid)
    config.shader:send("bodyLight", bodyPalette.light)
    config.shader:send("bodyRecolorAmount", body == "oras" and 0 or 1)
  end)
  if not ok then
    config.shaderFailed, config.shaderError = true, tostring(err)
    return nil
  end
  return config.shader
end

local function quadOf(g, config, column, row)
  if type(g.newQuad) ~= "function" then return nil end
  config.quads = config.quads or {}
  local key = tostring(column) .. ":" .. tostring(row)
  if config.quads[key] then return config.quads[key] end
  local ok, quad = pcall(g.newQuad, column * 64, row * 64, 64, 64,
    config.imageWidth, config.imageHeight)
  if not ok or not quad then return nil end
  config.quads[key] = quad
  return quad
end

local function drawFrame(g, config, frame, x, y, scale)
  local image = imageOf(config)
  if not image or type(g.draw) ~= "function" then return false end
  local quad = quadOf(g, config, frame.column, frame.row)
  if not quad then return false end
  local shader = shaderOf(g, config, frame.accent, frame.body)
  local known, previous = false, nil
  if shader and type(g.getShader) == "function" then
    local ok, value = pcall(g.getShader)
    if ok then known, previous = true, value end
  end
  if shader then g.setShader(shader) end
  g.setColor(1, 1, 1, 1)
  scale = math.max(1, integer(scale, 1))
  local ok = pcall(g.draw, image, quad, pixel(x), pixel(y), 0, scale, scale)
  if shader then
    if known and previous ~= nil then g.setShader(previous) else g.setShader() end
  end
  return ok
end

local POCKET_COLUMN = {
  items = 1, medicine = 1, balls = 3, tms = 4,
  battle = 1, key = 2, berries = 4,
}
M.POCKET_COLUMN = POCKET_COLUMN

local function frameFor(pocketId, form, accent, body, closed)
  if closed then
    return { column = 0, row = form == "handle" and 0 or 1,
      accent = accent, body = body, pocketId = pocketId }
  end
  if pocketId == "tms" then
    return { column = 4, row = 1, accent = accent, body = body,
      pocketId = pocketId }
  end
  if pocketId == "berries" then
    return { column = 4, row = 0, accent = accent, body = body,
      pocketId = pocketId }
  end
  return { column = POCKET_COLUMN[pocketId] or 1,
    row = form == "handle" and 0 or 1,
    accent = accent, body = body, pocketId = pocketId }
end

local function optionValue(config, key, list, character)
  local value = config[key]
  if type(value) ~= "function" then return value end
  local ok, result = pcall(value, list, character)
  if ok then return result end
  config[key .. "Error"] = tostring(result)
  return nil
end

local function choices(list, config)
  local character = Base.normalizeCharacter(optionValue(
    config, "resolveCharacter", list, nil))
  local accent = Base.normalizeAccent(optionValue(
    config, "resolveAccent", list, character), character)
  local form = Base.normalizeForm(optionValue(
    config, "resolveForm", list, character), character)
  local body = Base.normalizeBody(optionValue(
    config, "resolveBody", list, character))
  return character, accent, form, body
end

local function withChromeAccent(config, list, callback)
  local value = optionValue(config, "resolveChromeAccent", list, nil)
  local primary, bright = Base.normalizeChromeAccent(value)
  if not primary then return callback() end
  local nativeOrange, nativeOrange2 = C.orange, C.orange2
  C.orange, C.orange2 = primary, bright
  local returned
  local ok, err = xpcall(function()
    returned = packed(callback())
  end, traceback)
  C.orange, C.orange2 = nativeOrange, nativeOrange2
  if not ok then error(err, 0) end
  return unpackValues(returned, 1, returned.n)
end

local function animation(config, token, now)
  if not config.openedAt then config.openedAt = now end
  if not config.currentToken then
    config.currentToken = token
  elseif config.currentToken ~= token then
    config.currentToken = token
    config.changedAt = now
  end
  local elapsed = math.max(0, now - config.openedAt)
  local opening = clamp(elapsed / 0.20, 0, 1)
  local closed = elapsed < 0.09
  local offsetX, offsetY = 0, 0
  if elapsed < 0.05 then offsetY = -3
  elseif elapsed < 0.10 then offsetY = -1
  elseif elapsed < 0.15 then offsetY = 1 end
  local pocket = 1
  if config.changedAt then
    local changed = math.max(0, now - config.changedAt)
    pocket = clamp(changed / 0.18, 0, 1)
    if changed < 0.05 then offsetX = 3
    elseif changed < 0.10 then offsetX = -1
    elseif changed < 0.15 then offsetY = -2 end
  end
  return opening, pocket, closed, offsetX, offsetY
end

local function drawCoast(g)
  color(g, C.sky)
  g.rectangle("fill", 0, 0, M.width, M.height)
  color(g, C.glass2)
  g.rectangle("fill", 0, 34, 69, 56)
  color(g, C.sea)
  for y = 43, 87, 11 do g.rectangle("fill", 4 + y % 13, y, 43, 1) end
  color(g, C.skyLight)
  for y = 48, 86, 11 do g.rectangle("fill", 2 + y % 17, y, 34, 1) end
end

local function splitParagraphs(value)
  local result = {}
  local text = tostring(value or ""):gsub("\f", "\n")
  for line in (text .. "\n"):gmatch("(.-)\n") do result[#result + 1] = line end
  return result
end

local function wrapText(Font, value, budget)
  local output = {}
  for _, paragraph in ipairs(splitParagraphs(value)) do
    local line = ""
    for word in paragraph:gmatch("%S+") do
      local candidate = line == "" and word or line .. " " .. word
      if fontWidth(Font, candidate) <= budget then line = candidate
      else
        if line ~= "" then output[#output + 1] = line end
        line = fontWidth(Font, word) <= budget and word
          or truncate(Font, word, budget)
      end
    end
    if line ~= "" then output[#output + 1] = line
    elseif paragraph == "" then output[#output + 1] = "" end
  end
  if #output == 0 then output[1] = "" end
  return output
end

local function pingPong(time, overflow, hold, speed)
  if overflow <= 0 then return 0 end
  local travel = overflow / speed
  local cycle = hold * 2 + travel * 2
  local phase = math.max(0, time) % cycle
  if phase < hold then return 0 end
  phase = phase - hold
  if phase < travel then
    local p = phase / travel
    p = p * p * (3 - 2 * p)
    return -overflow * p
  end
  phase = phase - travel
  if phase < hold then return -overflow end
  local p = clamp((phase - hold) / travel, 0, 1)
  p = p * p * (3 - 2 * p)
  return -overflow * (1 - p)
end

local function resultText(value)
  if type(value) == "string" and value ~= "" then return value end
  if type(value) ~= "table" then return nil end
  return type(value.text) == "string" and value.text
    or type(value.description) == "string" and value.description or nil
end

local function descriptionOf(list, item, config, language)
  local providers = { config.describeItem, rawget(list, "describeItem") }
  for _, provider in ipairs(providers) do
    if type(provider) == "function" then
      local ok, value = pcall(provider, item, list)
      value = ok and resultText(value) or nil
      if value then return value end
    end
  end
  if item then
    local value = resultText(item.description) or resultText(item.desc)
    if value then return value end
    local game = rawget(list, "game")
    local definitions = type(game) == "table" and type(game.data) == "table"
      and game.data.items or nil
    local definition = type(definitions) == "table" and definitions[item.value]
    value = type(definition) == "table"
      and (resultText(definition.description) or resultText(definition.desc))
    if value then return value end
  end
  return tr(language, "Choose an item.", "Wähle ein Item.")
end

local function listWindow(list, count)
  local rows = clamp(integer(rawget(list, "rows") or list.rows, 4), 1, 4)
  local selected = count > 0
    and clamp(integer(rawget(list, "index") or list.index, 1), 1, count) or 1
  local first = clamp(integer(rawget(list, "scroll") or list.scroll, 0) + 1,
    1, math.max(1, count - rows + 1))
  if selected < first then first = selected end
  if selected > first + rows - 1 then first = selected - rows + 1 end
  return clamp(first, 1, math.max(1, count - rows + 1)), rows, selected
end

local function moneyText(list)
  local value
  if type(rawget(list, "money")) == "function" then
    local ok, result = pcall(rawget(list, "money"))
    if ok then value = result end
  end
  if value == nil then
    local game = rawget(list, "game")
    value = type(game) == "table" and type(game.save) == "table"
      and game.save.money or nil
  end
  value = tonumber(value)
  return value and ("¥%d"):format(math.max(0, math.floor(value))) or nil
end

local function drawWideCoast(g)
  color(g, C.sky)
  g.rectangle("fill", 0, 0, M.WIDE_WIDTH, M.WIDE_HEIGHT)
  color(g, C.skyLight)
  g.rectangle("fill", 0, 184, M.WIDE_WIDTH, 104)
  color(g, C.sea)
  g.rectangle("fill", 0, 210, M.WIDE_WIDTH, 78)
  color(g, C.glass2)
  for _, cloud in ipairs({
      { 18, 30, 86, 16 }, { 91, 20, 132, 18 },
      { 348, 24, 108, 17 }, { 434, 39, 61, 13 },
    }) do
    g.rectangle("fill", cloud[1], cloud[2], cloud[3], cloud[4], 8, 8)
  end
  color(g, C.skyLight)
  for y = 222, 282, 15 do
    g.rectangle("fill", 10 + (y * 3) % 47, y, 116, 2)
    g.rectangle("fill", 292 + (y * 5) % 61, y + 5, 142, 2)
  end
end

local function wideListWindow(list, count, rows)
  rows = math.max(1, integer(rows, 9))
  local selected = count > 0
    and clamp(integer(rawget(list, "index") or list.index, 1), 1, count) or 1
  local first = clamp(selected - rows + 1,
    1, math.max(1, count - rows + 1))
  return first, rows, selected
end

local function drawWideMovingLabel(g, Font, value, x, y, budget,
    selected, elapsed)
  local text = tostring(value or "")
  local width = fontWidth(Font, text)
  if width <= budget or not selected or type(g.setScissor) ~= "function" then
    Font.draw(truncate(Font, text, budget), x, y)
    return
  end
  withScissor(g, x, y, budget, 8, function()
    Font.draw(text, x + pixel(pingPong(elapsed,
      width - budget, 1.5, 8)), y)
  end)
end

-- True 512x288 composition for the FRLG artwork family. Source sprites use a
-- crisp integer scale, but panels, list capacity and help geometry are all
-- authored independently from the compact 160x144 renderer.
local function drawWidePresentation(list, config)
  local loveRef = rawget(_G, "love")
  local g = loveRef and loveRef.graphics
  local Font = config.Font or safeRequire("src.render.Font")
  if type(g) ~= "table" or type(g.setColor) ~= "function"
      or type(g.rectangle) ~= "function" or type(Font) ~= "table"
      or type(Font.draw) ~= "function" or type(Font.width) ~= "function" then
    error("FRLG ORAS WIDE Bag graphics are unavailable", 0)
  end
  local items = rawget(list, "items") or list.items
  if type(items) ~= "table" then
    error("FRLG ORAS WIDE Bag items are unavailable", 0)
  end

  local language = languageOf(list, config)
  local pocketCount, pocketIndex, pocketLabel, pocketId =
    Base.pocketInfo(list, language)
  local character, accent, form, body = choices(list, config)
  local now = timeNow()
  local token = accent .. ":" .. body .. ":" .. form .. ":" .. pocketId
  local opening, pocketProgress, closed, offsetX, offsetY =
    animation(config, token, now)
  local frame = frameFor(pocketId, form, accent, body, closed)
  config.pocketIconDisplay = 24

  drawWideCoast(g)
  panel(g, 12, 10, 488, 34, C.navy, C.paper, 5)
  color(g, C.orange)
  g.rectangle("fill", 15, 13, 4, 28, 2, 2)
  color(g, C.ink)
  Font.draw("FRLG ORAS WIDE", 28, 23)
  local title = truncate(Font, localizedBagTitle(rawget(list, "title")
    or list.title or tr(language, "BAG", "BEUTEL"), language), 172)
  Font.draw(title, 184, 23)
  local money = moneyText(list)
  if money then Font.draw(truncate(Font, money, 112),
    488 - fontWidth(Font, truncate(Font, money, 112)), 23) end

  panel(g, 12, 52, 160, 142, C.navy, C.glass2, 6)
  if not drawFrame(g, config, frame,
      28 + offsetX * 2, 58 + offsetY * 2, 2) then
    error("FRLG ORAS WIDE Bag atlas frame is unavailable", 0)
  end
  panel(g, 12, 200, 160, 39, C.navy, C.cream, 5)
  local railStep = pocketCount > 1 and 132 / (pocketCount - 1) or 0
  for index = 1, pocketCount do
    local x = pixel(26 + (index - 1) * railStep)
    if index == pocketIndex then
      color(g, C.orange2)
      g.rectangle("fill", x - 14, 205, 28, 29, 5, 5)
    end
    Base.renderPocketIcon(config, g, Base.pocketIdAt(list, index), x, 219,
      index == pocketIndex)
  end
  panel(g, 12, 245, 160, 31, C.navy, C.paper, 4)
  color(g, C.orange)
  g.rectangle("fill", 16, 249, 3, 23, 1, 1)
  color(g, C.ink)
  Font.draw(tr(language, "L/R POCKET", "L/R FACH"), 25, 250)
  Font.draw(tr(language, "A OK  B BACK", "A OK  B ZUR."), 25, 262)

  panel(g, 184, 52, 316, 153, C.navy, C.paper, 6)
  color(g, C.orange)
  g.rectangle("fill", 188, 56, 308, 24, 4, 4)
  Base.renderPocketIcon(config, g, pocketId, 204, 68, true)
  color(g, C.ink)
  local countText = tostring(pocketIndex) .. "/" .. tostring(pocketCount)
  local countX = 488 - fontWidth(Font, countText)
  Font.draw(truncate(Font, pocketLabel, math.max(16, countX - 228)), 222, 64)
  Font.draw(countText, countX, 64)

  local count = #items
  local first, rows, selected = wideListWindow(list, count, 9)
  if count == 0 then
    renderPokeBall(config, g, 300, 139, 12, false, true)
    color(g, C.ink)
    Font.draw(tr(language, "THIS POCKET IS EMPTY", "DIESES FACH IST LEER"),
      325, 135)
  else
    for row = 1, rows do
      local index = first + row - 1
      local item = items[index]
      if not item then break end
      local y = 87 + (row - 1) * 12
      local active = index == selected
      if active then
        color(g, C.orange2)
        g.rectangle("fill", 190, y - 2, 303, 11, 3, 3)
      end
      local right = truncate(Font, tostring(item.right or ""), 64)
      local rightWidth = right ~= "" and fontWidth(Font, right) or 0
      local rightX = 487 - rightWidth
      local labelX = 204
      local budget = math.max(16, rightX - labelX
        - (right ~= "" and 8 or 0))
      local swapped = rawget(list, "swapIndex") == index
      if active or swapped then
        renderPokeBall(config, g, 197, y + 3, 3,
          active, swapped and not active)
      end
      local tickerKey = pocketId .. ":wide:" .. tostring(index) .. ":"
        .. tostring(item.label or item.value or "")
      if active and config.itemTickerKey ~= tickerKey then
        config.itemTickerKey, config.itemTickerAt = tickerKey, now
      end
      color(g, C.ink)
      drawWideMovingLabel(g, Font, item.label or item.value or "",
        labelX, y, budget, active, now - (config.itemTickerAt or now))
      if right ~= "" then
        if active then
          color(g, C.paper)
          g.rectangle("fill", rightX - 2, y - 1, rightWidth + 4, 9, 2, 2)
          color(g, C.ink)
        end
        Font.draw(right, rightX, y)
      end
    end
    if count > rows then
      color(g, C.sea)
      g.rectangle("fill", 494, 86, 2, 108)
      local thumb = math.max(10, math.floor(108 * rows / count))
      local progress = count > 1 and (selected - 1) / (count - 1) or 0
      color(g, C.orange)
      g.rectangle("fill", 493, 86 + math.floor((108 - thumb) * progress),
        4, thumb, 2, 2)
    end
  end

  panel(g, 184, 211, 316, 65, C.navy, C.cream, 6)
  color(g, C.orange)
  g.rectangle("fill", 189, 216, 4, 54, 2, 2)
  color(g, C.ink)
  Font.draw(tr(language, "ITEM HELP", "GEGENSTAND-HILFE"), 201, 217)
  local item = count > 0 and items[selected] or nil
  local description = item and descriptionOf(list, item, config, language)
    or tr(language, "This pocket is empty.", "Dieses Fach ist leer.")
  local lines = wrapText(Font, description, 286)
  local descriptionKey = pocketId .. ":wide:" .. tostring(selected) .. ":"
    .. tostring(item and item.value or "empty") .. ":" .. description
  if config.descriptionKey ~= descriptionKey then
    config.descriptionKey, config.descriptionAt = descriptionKey, now
  end
  local verticalOffset = pixel(pingPong(now - (config.descriptionAt or now),
    math.max(0, (#lines - 4) * 10), 1.5, 5))
  withScissor(g, 200, 229, 288, 40, function()
    for index, line in ipairs(lines) do
      Font.draw(truncate(Font, line, 286), 201,
        230 + (index - 1) * 10 + verticalOffset)
    end
  end)

  list.__vascOrasFrlgBagPocketCount = pocketCount
  list.__vascOrasFrlgBagPocketId = pocketId
  list.__vascOrasFrlgBagSpriteSlot = frame.column
  list.__vascOrasFrlgBagCharacter = character
  list.__vascOrasFrlgBagAccent = accent
  list.__vascOrasFrlgBagForm = form
  list.__vascOrasFrlgBagBody = body
  list.__vascOrasFrlgBagWidePresentation = true
  list.__vascOrasFrlgBagLayoutWidth = M.WIDE_WIDTH
  list.__vascOrasFrlgBagLayoutHeight = M.WIDE_HEIGHT
  list.__vascOrasFrlgBagAnimation = {
    opening=opening, pocket=pocketProgress, closed=closed,
    offsetX=offsetX, offsetY=offsetY, form=form, sourceRow=frame.row,
  }
  local PaletteFX = config.PaletteFX or safeRequire("src.render.PaletteFX")
  if PaletteFX and type(PaletteFX.markTrueColor) == "function" then
    pcall(PaletteFX.markTrueColor, 0, 0, M.WIDE_WIDTH, M.WIDE_HEIGHT)
  end
end

local function drawPresentation(list, config)
  local loveRef = rawget(_G, "love")
  local g = loveRef and loveRef.graphics
  local Font = config.Font or safeRequire("src.render.Font")
  if type(g) ~= "table" or type(g.setColor) ~= "function"
      or type(g.rectangle) ~= "function" or type(Font) ~= "table"
      or type(Font.draw) ~= "function" or type(Font.width) ~= "function" then
    error("FRLG ORAS Bag graphics are unavailable", 0)
  end
  local items = rawget(list, "items") or list.items
  if type(items) ~= "table" then error("FRLG ORAS Bag items are unavailable", 0) end
  local language = languageOf(list, config)
  local pocketCount, pocketIndex, pocketLabel, pocketId =
    Base.pocketInfo(list, language)
  local character, accent, form, body = choices(list, config)
  local now = timeNow()
  local token = accent .. ":" .. body .. ":" .. form .. ":" .. pocketId
  local opening, pocketProgress, closed, offsetX, offsetY =
    animation(config, token, now)
  local frame = frameFor(pocketId, form, accent, body, closed)

  drawCoast(g)
  panel(g, 1, 1, 67, 66, C.navy, C.glass2, 4)
  if not drawFrame(g, config, frame, 2 + offsetX, 2 + offsetY) then
    error("FRLG ORAS Bag atlas frame is unavailable", 0)
  end
  panel(g, 2, 69, 65, 21, C.navy, C.cream, 3)
  color(g, C.orange)
  g.rectangle("fill", 4, 71, 61, 2)
  local railStep = pocketCount > 1 and 55 / (pocketCount - 1) or 0
  for index = 1, pocketCount do
    local x = pixel(6 + (index - 1) * railStep)
    if index == pocketIndex then
      color(g, C.orange2)
      g.rectangle("fill", x - 4, 78, 9, 9, 2, 2)
    end
    Base.renderPocketIcon(config, g, Base.pocketIdAt(list, index), x, 82,
      index == pocketIndex)
  end

  panel(g, 70, 2, 88, 16, C.navy, C.paper, 2)
  color(g, C.orange)
  g.rectangle("fill", 72, 4, 2, 12)
  color(g, C.ink)
  Font.draw("FRLG ORAS", 77, 6)

  panel(g, 70, 20, 88, 13, C.blue, C.cream, 2)
  local countText = tostring(pocketIndex) .. "/" .. tostring(pocketCount)
  local countX = 154 - fontWidth(Font, countText)
  Base.renderPocketIcon(config, g, pocketId, 76, 26, true)
  color(g, C.ink)
  Font.draw(truncate(Font, pocketLabel, math.max(8, countX - 82)), 82, 23)
  Font.draw(countText, countX, 23)

  panel(g, 70, 35, 88, 55, C.navy, C.paper, 4)
  local count = #items
  local first, rows, selected = listWindow(list, count)
  if count == 0 then
    renderPokeBall(config, g, 88, 62, 7, false, true)
    color(g, C.ink)
    Font.draw(tr(language, "EMPTY", "LEER"), 104, 58)
  else
    for row = 1, rows do
      local index = first + row - 1
      local item = items[index]
      if not item then break end
      local y = 39 + (row - 1) * 12
      local active = index == selected
      if active then
        color(g, C.orange2)
        g.rectangle("fill", 73, y - 2, 82, 11, 3, 3)
      end
      local right = truncate(Font, tostring(item.right or ""), 32)
      local rightWidth = right ~= "" and fontWidth(Font, right) or 0
      local rightX = 153 - rightWidth
      local labelX = 82
      local budget = math.max(8, rightX - labelX - (right ~= "" and 2 or 0))
      if active or rawget(list, "swapIndex") == index then
        renderPokeBall(config, g, 78, y + 3, 3, active,
          rawget(list, "swapIndex") == index and not active)
      end
      local tickerKey = pocketId .. ":" .. tostring(index) .. ":"
        .. tostring(item.label or item.value or "")
      if active and config.itemTickerKey ~= tickerKey then
        config.itemTickerKey, config.itemTickerAt = tickerKey, now
      end
      color(g, C.ink)
      local text = tostring(item.label or item.value or "")
      if active and fontWidth(Font, text) > budget
          and type(g.setScissor) == "function" then
        withScissor(g, labelX, y, budget, 8, function()
          local elapsed = now - (config.itemTickerAt or now)
          Font.draw(text, labelX + pixel(pingPong(
            elapsed, fontWidth(Font, text) - budget, 1.5, 8)), y)
        end)
      else
        Font.draw(truncate(Font, text, budget), labelX, y)
      end
      if right ~= "" then
        if active then
          color(g, C.paper)
          g.rectangle("fill", rightX - 1, y - 1, rightWidth + 2, 9, 2, 2)
          color(g, C.ink)
        end
        Font.draw(right, rightX, y)
      end
    end
    if count > rows then
      color(g, C.sea)
      g.rectangle("fill", 156, 39, 1, 46)
      local thumb = math.max(5, math.floor(46 * rows / count))
      local progress = count > 1 and (selected - 1) / (count - 1) or 0
      color(g, C.orange)
      g.rectangle("fill", 155, 39 + math.floor((46 - thumb) * progress),
        3, thumb, 1, 1)
    end
  end

  panel(g, 2, 92, 156, 50, C.navy, C.cream, 4)
  local item = count > 0 and items[selected] or nil
  local description = item and descriptionOf(list, item, config, language)
    or tr(language, "This pocket is empty.", "Dieses Fach ist leer.")
  local lines = wrapText(Font, description, 140)
  local descriptionKey = pocketId .. ":" .. tostring(selected) .. ":"
    .. tostring(item and item.value or "empty") .. ":" .. description
  if config.descriptionKey ~= descriptionKey then
    config.descriptionKey, config.descriptionAt = descriptionKey, now
  end
  local offset = pixel(pingPong(now - (config.descriptionAt or now),
    math.max(0, (#lines - 3) * 10), 1.5, 5))
  color(g, C.orange)
  g.rectangle("fill", 5, 95, 3, 29, 1, 1)
  color(g, C.ink)
  withScissor(g, 10, 95, 142, 30, function()
    for index, line in ipairs(lines) do
      Font.draw(truncate(Font, line, 140), 11,
        96 + (index - 1) * 10 + offset)
    end
  end)

  panel(g, 4, 127, 152, 12, C.navy, C.paper, 2)
  color(g, C.orange)
  g.rectangle("fill", 6, 129, 2, 8)
  color(g, C.ink)
  local money = moneyText(list)
  if money then money = truncate(Font, money, 48) end
  local moneyX = money and 152 - fontWidth(Font, money) or 152
  Font.draw(truncate(Font, tr(language, "A OK  B BACK", "A OK  B ZUR."),
    math.max(8, moneyX - 13)), 10, 130)
  if money then Font.draw(money, moneyX, 130) end

  list.__vascOrasFrlgBagPocketCount = pocketCount
  list.__vascOrasFrlgBagPocketId = pocketId
  list.__vascOrasFrlgBagSpriteSlot = frame.column
  list.__vascOrasFrlgBagCharacter = character
  list.__vascOrasFrlgBagAccent = accent
  list.__vascOrasFrlgBagForm = form
  list.__vascOrasFrlgBagBody = body
  list.__vascOrasFrlgBagAnimation = {
    opening = opening, pocket = pocketProgress, closed = closed,
    offsetX = offsetX, offsetY = offsetY, form = form,
    sourceRow = frame.row,
  }

  local PaletteFX = config.PaletteFX or safeRequire("src.render.PaletteFX")
  if PaletteFX and type(PaletteFX.markTrueColor) == "function" then
    pcall(PaletteFX.markTrueColor, 0, 0, M.width, M.height)
  end
end

function M.decorate(list, opts)
  opts = type(opts) == "table" and opts or {}
  local allowed, reason, marker = M.canDecorate(list, opts)
  if not allowed then return list, false, reason, marker end
  local nativeDraw = rawget(list, "draw") or list.draw
  local characterResolver = opts.resolveCharacter or opts.kascCharacter
  local config = {
    describeItem = opts.describeItem,
    enabled = opts.enabled,
    language = opts.language,
    image = opts.image,
    loadImage = opts.loadImage,
    resolveCharacter = characterResolver,
    resolveAccent = opts.resolveAccent ~= nil and opts.resolveAccent
      or opts.bagColor or opts.accent,
    resolveForm = opts.resolveForm ~= nil and opts.resolveForm
      or opts.bagForm or opts.form,
    resolveBody = opts.resolveBody ~= nil and opts.resolveBody
      or opts.bagBody or opts.body,
    resolveChromeAccent = opts.resolveChromeAccent ~= nil
      and opts.resolveChromeAccent or opts.chromeAccent,
    drawPokeBall = opts.drawPokeBall,
    drawPocketIcon = opts.drawPocketIcon,
    pocketIconImage = opts.pocketIconImage,
    Font = opts.Font,
    PaletteFX = opts.PaletteFX,
    wide = opts.wide == true,
  }
  list.__vascOrasFrlgBagNativeDraw = nativeDraw
  list.__vascOrasFrlgBagConfig = config
  list.__vascOrasFrlgBagForced = opts.force == true
  list.__vascOrasFrlgBagOwner = M.owner
  list.__vascOrasFrlgBagPresentation = true
  list.__vascOrasFrlgBagSkin = true
  list.__vascOrasFrlgBagAssetPath = M.ASSET_PATH
  list.__vascOrasFrlgBagPocketIconAssetPath = M.POCKET_ICON_ASSET_PATH
  list.__vascOrasFrlgBagWidePresentation = config.wide
  list.__vascOrasFrlgBagLayoutWidth = config.wide
    and M.WIDE_WIDTH or M.WIDTH
  list.__vascOrasFrlgBagLayoutHeight = config.wide
    and M.WIDE_HEIGHT or M.HEIGHT
  list.__ascendantGlobalUiSkinSkip = true

  local nativeUiSize = rawget(list, "uiSize") or list.uiSize
  local nativeDrawsWidescreen = rawget(list, "drawsWidescreen")
    or list.drawsWidescreen
  local nativeWantsFillScale = rawget(list, "wantsFillScale")
    or list.wantsFillScale
  local nativeIsWideBattleLayout = rawget(list, "isWideBattleLayout")
    or list.isWideBattleLayout
  local nativeSgbPalettes = rawget(list, "sgbPalettes") or list.sgbPalettes

  local function enabledFor(self, live)
    if live.enabled == nil then return true end
    if type(live.enabled) ~= "function" then return live.enabled == true end
    local ok, value = pcall(live.enabled, self)
    if ok then return value == true end
    self.__vascOrasFrlgBagLastError = tostring(value)
    return false
  end

  local function wideEnabledFor(self, live)
    if not live.wide or live.wideFailed then return false end
    if not enabledFor(self, live) then return false end
    if not rawget(self, "__vascOrasFrlgBagForced")
        and externalOwnerOf(self) then return false end
    if not imageOf(live) then
      self.__vascOrasFrlgBagLastError = live.imageError
        or "FRLG ORAS Bag atlas is unavailable"
      live.wideFailed = true
      self.__vascOrasFrlgBagWidePresentation = false
      self.__vascOrasFrlgBagLayoutWidth = M.WIDTH
      self.__vascOrasFrlgBagLayoutHeight = M.HEIGHT
      return false
    end
    local loveRef = rawget(_G, "love")
    local graphics = loveRef and loveRef.graphics
    local _, layerError = resolveWideLayer(live, graphics)
    if layerError then
      self.__vascOrasFrlgBagLastError = layerError
      live.wideFailed = true
      self.__vascOrasFrlgBagWidePresentation = false
      self.__vascOrasFrlgBagLayoutWidth = M.WIDTH
      self.__vascOrasFrlgBagLayoutHeight = M.HEIGHT
      return false
    end
    return true
  end

  if config.wide then
    list.uiSize = function(self, ...)
      local live = rawget(self, "__vascOrasFrlgBagConfig") or config
      if wideEnabledFor(self, live) then
        return M.WIDE_WIDTH, M.WIDE_HEIGHT
      end
      if type(nativeUiSize) == "function" then return nativeUiSize(self, ...) end
      return M.WIDTH, M.HEIGHT
    end
    list.drawsWidescreen = function(self, ...)
      local live = rawget(self, "__vascOrasFrlgBagConfig") or config
      if wideEnabledFor(self, live) then return true end
      if type(nativeDrawsWidescreen) == "function" then
        local ok, value = pcall(nativeDrawsWidescreen, self, ...)
        return ok and value == true
      end
      return false
    end
    list.wantsFillScale = function(self, ...)
      local live = rawget(self, "__vascOrasFrlgBagConfig") or config
      if wideEnabledFor(self, live) then return true end
      if type(nativeWantsFillScale) == "function" then
        local ok, value = pcall(nativeWantsFillScale, self, ...)
        return ok and value == true
      end
      return false
    end
    list.isWideBattleLayout = function(self, ...)
      local live = rawget(self, "__vascOrasFrlgBagConfig") or config
      if wideEnabledFor(self, live) and battleBelow(self) then return true end
      if type(nativeIsWideBattleLayout) == "function" then
        local ok, value = pcall(nativeIsWideBattleLayout, self, ...)
        return ok and value == true
      end
      return false
    end
    list.sgbPalettes = function(self, ...)
      local live = rawget(self, "__vascOrasFrlgBagConfig") or config
      if wideEnabledFor(self, live) then
        return { { colors=false, x=0, y=0,
          w=M.WIDE_WIDTH, h=M.WIDE_HEIGHT } }
      end
      if type(nativeSgbPalettes) == "function" then
        return nativeSgbPalettes(self, ...)
      end
      return nil
    end
  end

  list.draw = function(self, ...)
    local args = packed(...)
    local live = rawget(self, "__vascOrasFrlgBagConfig") or config
    if live.wide then
      if not wideEnabledFor(self, live) then
        return nativeDraw(self, unpackValues(args, 1, args.n))
      end
      local loveRef = rawget(_G, "love")
      local graphics = loveRef and loveRef.graphics
      local state = type(graphics) == "table" and graphicsState(graphics) or nil
      local ok, returned = drawWideAtomically(live, graphics, function()
        return withChromeAccent(live, self, function()
          return drawWidePresentation(self, live)
        end)
      end)
      if state then restoreGraphics(graphics, state) end
      if ok then return unpackValues(returned, 1, returned.n) end
      self.__vascOrasFrlgBagLastError = tostring(returned)
      live.wideFailed = true
      self.__vascOrasFrlgBagWidePresentation = false
      self.__vascOrasFrlgBagLayoutWidth = M.WIDTH
      self.__vascOrasFrlgBagLayoutHeight = M.HEIGHT
      local fallbackOk, fallbackReturned = drawNativeWideFallback(
        live, graphics, function()
          return nativeDraw(self, unpackValues(args, 1, args.n))
        end)
      if fallbackOk then
        return unpackValues(fallbackReturned, 1, fallbackReturned.n)
      end
      self.__vascOrasFrlgBagLastError = tostring(returned) .. "\n"
        .. tostring(fallbackReturned)
      return nil
    end
    if not enabledFor(self, live) then
      return nativeDraw(self, unpackValues(args, 1, args.n))
    end
    if not rawget(self, "__vascOrasFrlgBagForced") then
      local external = externalOwnerOf(self)
      if external then return nativeDraw(self, unpackValues(args, 1, args.n)) end
    end
    if not imageOf(live) then
      self.__vascOrasFrlgBagLastError = live.imageError
        or "FRLG ORAS Bag atlas is unavailable"
      return nativeDraw(self, unpackValues(args, 1, args.n))
    end
    local loveRef = rawget(_G, "love")
    local graphics = loveRef and loveRef.graphics
    local state = type(graphics) == "table" and graphicsState(graphics) or nil
    local returned
    local ok, err = xpcall(function()
      returned = packed(withChromeAccent(live, self, function()
        return drawPresentation(self, live)
      end))
    end, traceback)
    if state then restoreGraphics(graphics, state) end
    if ok then return unpackValues(returned, 1, returned.n) end
    self.__vascOrasFrlgBagLastError = tostring(err)
    return nativeDraw(self, unpackValues(args, 1, args.n))
  end
  if config.wide then list.drawWidescreen = list.draw end
  return list, true, M.owner
end

return M
