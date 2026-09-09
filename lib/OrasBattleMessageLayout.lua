-- Presentation-only word layout for VASC's wider ORAS battle message plate.
--
-- The engine owns message pagination, the typewriter glyph count, CONT waits
-- and callbacks. This module receives only the engine rows that are currently
-- visible and may arrange those already-revealed glyphs into additional visual
-- rows. It never mutates battle/TextBox state.

local Layout = {}

local function finite(value, fallback)
  value = tonumber(value)
  if not (value and value == value and value > -math.huge
      and value < math.huge) then return fallback end
  return value
end

local function fontWidth(font, text)
  local ok, width = pcall(font.width, tostring(text or ""))
  if ok and finite(width, nil) then return math.max(0, width) end
  local okSplit, spans = pcall(font.split, tostring(text or ""))
  return okSplit and type(spans) == "table" and #spans * 8 or 0
end

local function words(text)
  local out = {}
  for word in tostring(text or ""):gmatch("%S+") do
    out[#out + 1] = word
  end
  return out
end

-- Wrap only between complete whitespace-delimited words. An individual word
-- wider than the row stays whole; its row receives a local fit scale later.
local function wrapSourceRows(font, sourceRows, rawBudget)
  local out = {}
  for _, source in ipairs(type(sourceRows) == "table" and sourceRows or {}) do
    local rowWords = words(source)
    if #rowWords == 0 then
      out[#out + 1] = ""
    else
      local line = ""
      for _, word in ipairs(rowWords) do
        local candidate = line == "" and word or (line .. " " .. word)
        if line ~= "" and fontWidth(font, candidate) > rawBudget then
          out[#out + 1] = line
          line = word
        else
          line = candidate
        end
      end
      out[#out + 1] = line
    end
  end
  return out
end

local function verticalCapacity(height, top, bottom, glyphHeight, gap)
  local available = math.max(0, height - top - bottom)
  if glyphHeight <= 0 or available < glyphHeight then return 0 end
  return math.max(1, math.floor((available + gap) / (glyphHeight + gap)))
end

function Layout.layout(font, sourceRows, options)
  assert(type(font) == "table" and type(font.width) == "function",
    "ORAS message layout requires Font.width")
  options = type(options) == "table" and options or {}

  local logicalWidth = math.max(1, finite(options.logicalWidth, 288))
  local logicalHeight = math.max(1, finite(options.logicalHeight, 64))
  local textX = math.max(0, finite(options.textX, 13))
  local rightPadding = math.max(0, finite(options.rightPadding, 24))
  local top = math.max(0, finite(options.top, 7))
  local bottom = math.max(0, finite(options.bottom, 7))
  local lineGap = math.max(0, finite(options.lineGap, 2))
  local requestedScale = math.max(0.01, finite(options.textScale, 1.18))
  local minScale = math.min(requestedScale,
    math.max(0.01, finite(options.minScale, 0.72)))
  local glyphHeight = math.max(1, finite(options.glyphHeight, 8))
  local maxWidth = math.max(1, logicalWidth - textX - rightPadding)

  local scale, visual, capacity = requestedScale, nil, 0
  while scale + 0.0001 >= minScale do
    visual = wrapSourceRows(font, sourceRows, maxWidth / scale)
    capacity = verticalCapacity(logicalHeight, top, bottom,
      glyphHeight * scale, lineGap)
    if #visual <= capacity then break end
    scale = math.max(minScale, scale - 0.02)
    if scale == minScale then
      visual = wrapSourceRows(font, sourceRows, maxWidth / scale)
      capacity = verticalCapacity(logicalHeight, top, bottom,
        glyphHeight * scale, lineGap)
      break
    end
  end

  visual = visual or {}
  local complete = #visual <= capacity
  local result = {
    lines={}, complete=complete, maxLines=capacity,
    maxWidth=maxWidth, scale=scale,
    logicalHeight=logicalHeight, top=top, bottom=bottom,
  }
  if not complete then return result end

  local count = #visual
  local defaultStep = glyphHeight * scale + lineGap
  local firstY = top
  local step = defaultStep
  if count == 1 then
    firstY = finite(options.line1Y, top)
  elseif count == 2 and options.line1Y ~= nil and options.line2Y ~= nil then
    firstY = finite(options.line1Y, top)
    step = math.max(defaultStep,
      finite(options.line2Y, firstY + defaultStep) - firstY)
    if firstY + step + glyphHeight * scale > logicalHeight - bottom then
      firstY, step = top, defaultStep
    end
  elseif count > 2 then
    local lastStart = logicalHeight - bottom - glyphHeight * scale
    step = count > 1 and (lastStart - top) / (count - 1) or 0
    if step < defaultStep then step = defaultStep end
  end

  for index, text in ipairs(visual) do
    local width = fontWidth(font, text)
    -- A single exceptionally long name/compound stays an intact word. Scale
    -- that row just enough to fit instead of splitting through the name.
    local lineScale = scale
    if width > 0 and width * lineScale > maxWidth then
      lineScale = maxWidth / width
    end
    -- Never solve an impossible word by making the text unreadably tiny. The
    -- compositor will decline this whole ORAS surface and the engine's native
    -- message remains authoritative/readable for that frame.
    if lineScale + 0.0001 < minScale then
      result.complete = false
      result.lines = {}
      return result
    end
    result.lines[#result.lines + 1] = {
      text=text, width=width, scale=lineScale,
      x=textX, y=firstY + (index - 1) * step,
    }
  end
  return result
end

return Layout
