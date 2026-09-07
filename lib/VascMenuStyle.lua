-- Standalone Voxel Ascendant settings presentations.
--
-- FIRE RED COMPACT is the same visual grammar used by the current public Kanto
-- Ascendant 6.5.15 menu: cream paper,
-- navy/light-blue title rail, orange Kanto stripe, six visible rows, gold
-- selection and a full-screen paged help card.  It only decorates the
-- engine-owned ListMenu; input, scrolling and callbacks remain native.  The
-- implementation lives in VASC so the renderer keeps this presentation when
-- Kanto Ascendant is not installed.
--
-- ORAS FULLSCREEN is the default presentation of this very same controller.
-- It owns a responsive 16:9-ish logical surface, keeps the
-- focused row's complete help visible in a dedicated right-hand glass panel,
-- and never hooks Bag, PC or another ordinary game screen.  The skin resolver
-- is read for every frame, so changing VASC MENU from inside this screen takes
-- effect immediately without reconstructing the menu.

local V = ...
local Style = {}

local EditionAccent
if type(V) == "table" and type(V.require) == "function" then
  local ok, value = pcall(V.require, "EditionAccent")
  if ok and type(value) == "table" then EditionAccent = value end
end

local SHARED_ACCENT = { 0.04, 0.80, 0.97, 1 }

local SKIN_FIRE_RED = "firered"
local SKIN_ORAS_FULLSCREEN = "oras_fullscreen"
local ORAS_BASE_WIDTH = 512
local ORAS_BASE_HEIGHT = 288
local ORAS_MIN_WIDTH = 360
local ORAS_MAX_WIDTH = 640
local unpackValues = table.unpack or unpack

local function packed(...)
  return { n=select("#", ...), ... }
end

-- QA may exercise the real menu controller against a cloned save inside the
-- already running game process.  Navigation is intentionally process-local,
-- so give that harness a private copy without ever mutating the player's live
-- cache.  Table keys (notably the concrete Game/owner objects) keep identity;
-- only navigation values are recursively cloned.
local function cloneNavigationGraph(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local copy = setmetatable({}, getmetatable(value))
  seen[value] = copy
  for key, item in pairs(value) do
    copy[key] = cloneNavigationGraph(item, seen)
  end
  return copy
end

local function resolveEditionAccent(explicit)
  if EditionAccent and type(EditionAccent.color) == "function" then
    local ok, colorValue, id = pcall(EditionAccent.color, explicit)
    if ok and type(colorValue) == "table" then
      return colorValue, id or "shared"
    end
  end
  return SHARED_ACCENT, "shared"
end

local COLORS = {
  ink = { 0.08, 0.12, 0.19, 1 },
  paper = { 0.96, 0.93, 0.76, 1 },
  paper2 = { 0.88, 0.83, 0.60, 1 },
  cream = { 1.00, 0.98, 0.86, 1 },
  blue = { 0.12, 0.35, 0.65, 1 },
  blue2 = { 0.24, 0.55, 0.82, 1 },
  blue3 = { 0.07, 0.20, 0.40, 1 },
  orange = { 0.90, 0.45, 0.12, 1 },
  gold = { 1.00, 0.76, 0.18, 1 },
  red = { 0.78, 0.20, 0.22, 1 },
  white = { 1, 1, 1, 1 },
  glassBack = { 0.025, 0.045, 0.085, 1 },
  glassBack2 = { 0.045, 0.085, 0.145, 1 },
  glass = { 0.06, 0.12, 0.21, 0.92 },
  glassSoft = { 0.10, 0.19, 0.30, 0.82 },
  glassLine = { 0.40, 0.80, 1.00, 0.86 },
  -- Gen-I font pages contain black glyph pixels.  These values are applied
  -- by the ORAS-only alpha-mask shader below; ordinary setColor tinting cannot
  -- turn a black source image white.
  glassText = { 1.00, 1.00, 1.00, 1 },
  glassMuted = { 0.88, 0.94, 1.00, 1 },
  glassGold = { 1.00, 0.72, 0.24, 1 },
  glassBad = { 1.00, 0.30, 0.32, 1 },
  glassGood = { 0.35, 1.00, 0.63, 1 },
}

local function statusInk(item, fallback, compact)
  local tone = type(item) == "table" and item.statusTone or nil
  if tone == "bad" then return compact and COLORS.red or COLORS.glassBad end
  if tone == "warn" then return compact and COLORS.orange or COLORS.glassGold end
  if tone == "good" then return compact and COLORS.blue or COLORS.glassGood end
  return fallback
end

local runtimeCache
local function runtime()
  if runtimeCache then return runtimeCache end
  local function fallbackFont()
    local font = {}
    function font.width(value) return #tostring(value or "") * 8 end
    function font.split(value)
      local spans = {}
      value = tostring(value or "")
      for index = 1, #value do
        spans[index] = { from=index, to=index }
      end
      return spans
    end
    function font.spansFitting(spans, budget)
      return math.min(#spans, math.max(0, math.floor((budget or 0) / 8)))
    end
    function font.advanceOf() return 8 end
    function font.draw() end
    function font.drawCode() end
    return font
  end
  local okFont, Font = pcall(require, "src.render.Font")
  local okStrings, Strings = pcall(require, "src.core.Strings")
  local okTheme, Theme = pcall(require, "src.ui.Theme")
  local okPalette, PaletteFX = pcall(require, "src.render.PaletteFX")
  runtimeCache = {
    Font = okFont and Font or fallbackFont(),
    Strings = okStrings and Strings or function(value) return tostring(value or "") end,
    Theme = okTheme and Theme or { cursor=0, cursorHollow=0, moreArrow=0 },
    PaletteFX = okPalette and PaletteFX or {
      trueColorZone=function(x, y, w, h) return { x=x, y=y, w=w, h=h } end,
    },
  }
  return runtimeCache
end

local function color(value)
  love.graphics.setColor(value[1], value[2], value[3], value[4])
end

local function normalizedSkin(value)
  value = tostring(value or ""):lower():gsub("[%s%-]+", "_")
  if value == "oras" or value == "oras_full" or value == "oras_glass"
      or value == "oras_fullscreen" or value == "fullscreen_oras_glass" then
    return SKIN_ORAS_FULLSCREEN
  end
  return SKIN_FIRE_RED
end

-- Reset every piece of LÖVE drawing state that has historically leaked from
-- cartridge/SGB providers into mod-owned canvases.  push("all") preserves the
-- caller exactly on current LÖVE; the guarded resets keep headless and older
-- implementations deterministic as well.
local function resetGraphicsState()
  local graphics = love and love.graphics
  if not graphics then return end
  if type(graphics.origin) == "function" then graphics.origin() end
  if type(graphics.setShader) == "function" then graphics.setShader() end
  if type(graphics.setScissor) == "function" then graphics.setScissor() end
  if type(graphics.setBlendMode) == "function" then
    pcall(graphics.setBlendMode, "alpha", "alphamultiply")
  end
  if type(graphics.setColor) == "function" then
    graphics.setColor(1, 1, 1, 1)
  end
end

local function isolatedDraw(drawer, owner)
  local graphics = love and love.graphics
  local pushed = false
  if graphics and type(graphics.push) == "function" then
    local ok = pcall(graphics.push, "all")
    if not ok then ok = pcall(graphics.push) end
    pushed = ok
  end
  resetGraphicsState()
  local ok, result = xpcall(function() return drawer(owner) end,
    function(err)
      return debug and debug.traceback and debug.traceback(err, 2)
        or tostring(err)
    end)
  if pushed and type(graphics.pop) == "function" then
    pcall(graphics.pop)
  else
    resetGraphicsState()
  end
  if not ok then error(result, 0) end
  return result
end

local function orasUiSizeFor(width, height)
  width, height = tonumber(width), tonumber(height)
  if not width or not height or width <= 0 or height <= 0 then
    return ORAS_BASE_WIDTH, ORAS_BASE_HEIGHT
  end
  -- Match the physical aspect as closely as an eight-pixel text grid permits.
  -- Renderer:setUISize bounds this same range; the clamp prevents a malformed
  -- display report from requesting an unbounded canvas.
  local logical = math.floor((ORAS_BASE_HEIGHT * width / height) / 8 + .5) * 8
  logical = math.max(ORAS_MIN_WIDTH, math.min(ORAS_MAX_WIDTH, logical))
  return logical, ORAS_BASE_HEIGHT
end

local function orasUiSize()
  local graphics = love and love.graphics
  local width, height
  if graphics and type(graphics.getPixelDimensions) == "function" then
    local ok, w, h = pcall(graphics.getPixelDimensions)
    if ok then width, height = tonumber(w), tonumber(h) end
  end
  if (not width or not height or height <= 0)
      and graphics and type(graphics.getDimensions) == "function" then
    local ok, w, h = pcall(graphics.getDimensions)
    if ok then width, height = tonumber(w), tonumber(h) end
  end
  if not width or not height or width <= 0 or height <= 0 then
    return ORAS_BASE_WIDTH, ORAS_BASE_HEIGHT
  end
  return orasUiSizeFor(width, height)
end

local function activeOrasUiSize(owner)
  if type(owner) == "table"
      and tonumber(owner.__vascWideLogicalWidth)
      and tonumber(owner.__vascWideLogicalHeight) then
    return owner.__vascWideLogicalWidth, owner.__vascWideLogicalHeight
  end
  return orasUiSize()
end

local function text(value)
  if type(value) == "string" then return value end
  if value == nil then return "" end
  local Strings = runtime().Strings
  local ok, resolved = pcall(Strings, value)
  return ok and resolved or tostring(value)
end

-- The original Gen-I charmap intentionally has no ASCII plus or percent
-- glyph.  Those characters are nevertheless part of VASC's public menu
-- vocabulary (VIEW + WORLD, 75%, ...).  Keep the native 8 px advance and
-- draw the missing tiny glyphs as pixel primitives instead of asking Font.draw
-- to turn them into invisible spaces.  This is local to VASC's view layer;
-- no engine font page and no KASC module is patched.
local SPECIAL_ADVANCE = { ["+"]=8, ["%"]=8, ["&"]=8 }

local function spanAdvance(Font, value, span)
  local glyph = value:sub(span.from, span.to)
  if SPECIAL_ADVANCE[glyph] then return SPECIAL_ADVANCE[glyph] end
  if type(Font.advanceOf) == "function" then
    return Font.advanceOf(span.code or 0x7F)
  end
  return 8
end

local function displayWidth(value)
  local Font = runtime().Font
  value = text(value)
  local width = 0
  for _, span in ipairs(Font.split(value)) do
    width = width + spanAdvance(Font, value, span)
  end
  return width
end

local function drawSpecial(glyph, x, y)
  if glyph == "+" then
    love.graphics.rectangle("fill", x + 1, y + 3, 6, 1)
    love.graphics.rectangle("fill", x + 3, y + 1, 1, 6)
  elseif glyph == "%" then
    love.graphics.rectangle("fill", x + 1, y + 1, 2, 2)
    love.graphics.rectangle("fill", x + 5, y + 5, 2, 2)
    love.graphics.rectangle("fill", x + 5, y + 1, 1, 1)
    love.graphics.rectangle("fill", x + 4, y + 2, 1, 1)
    love.graphics.rectangle("fill", x + 3, y + 3, 1, 1)
    love.graphics.rectangle("fill", x + 2, y + 4, 1, 1)
    love.graphics.rectangle("fill", x + 1, y + 5, 1, 1)
  elseif glyph == "&" then
    -- The Gen-I page has no ampersand.  Keep the established section name
    -- instead of silently substituting the font's unknown-glyph question
    -- mark ("SKINS ? OVERLAYS").  This compact 5x7 mask follows the same
    -- one-logical-pixel grammar as the local plus/percent glyphs above.
    local pixels = {
      {2, 0}, {3, 0},
      {1, 1}, {4, 1},
      {1, 2}, {3, 2},
      {2, 3},
      {1, 4}, {3, 4}, {5, 4},
      {1, 5}, {4, 5},
      {2, 6}, {3, 6}, {5, 6},
    }
    for _, pixel in ipairs(pixels) do
      love.graphics.rectangle("fill", x + pixel[1], y + pixel[2], 1, 1)
    end
  end
end

local GLASS_GLYPH_SHADER = [[
extern vec4 vascGlassInk;

vec4 effect(vec4 vertexColor, Image texture, vec2 textureCoordinates,
    vec2 screenCoordinates) {
  vec4 glyph = Texel(texture, textureCoordinates);
  return vec4(vascGlassInk.rgb,
    vascGlassInk.a * vertexColor.a * glyph.a);
}
]]

local glassGlyphShader
local glassGlyphShaderAttempted = false

local function resolveGlassGlyphShader()
  if glassGlyphShaderAttempted then return glassGlyphShader end
  local graphics = love and love.graphics
  if not graphics or type(graphics.newShader) ~= "function" then return nil end
  -- A menu may be constructed before the host has installed its complete
  -- graphics API. Do not consume the one shader attempt on that pre-init
  -- frame; retry once a real shader factory exists.
  glassGlyphShaderAttempted = true
  local ok, shader = pcall(graphics.newShader, GLASS_GLYPH_SHADER)
  if ok and shader then glassGlyphShader = shader end
  return glassGlyphShader
end

local function beginGlassInk(ink)
  local graphics = love and love.graphics
  local shader = resolveGlassGlyphShader()
  if not graphics or not shader or type(graphics.setShader) ~= "function"
      or type(shader.send) ~= "function" then
    color(ink)
    return nil
  end
  local previous
  if type(graphics.getShader) == "function" then
    local ok, value = pcall(graphics.getShader)
    if ok then previous = value end
  end
  local sent = pcall(shader.send, shader, "vascGlassInk", ink)
  if not sent then
    color(ink)
    return nil
  end
  color(COLORS.white)
  local applied = pcall(graphics.setShader, shader)
  if not applied then
    color(ink)
    return nil
  end
  return { shader=shader, previous=previous, ink=ink }
end

local function suspendGlassInk(state)
  if not state then return end
  love.graphics.setShader(state.previous)
  color(state.ink)
end

local function resumeGlassInk(state)
  if not state then return end
  color(COLORS.white)
  love.graphics.setShader(state.shader)
end

local function endGlassInk(state)
  if not state then return end
  love.graphics.setShader(state.previous)
  color(state.ink)
end

local function drawCode(code, x, y, ink)
  local state = ink and beginGlassInk(ink) or nil
  runtime().Font.drawCode(code, x, y)
  endGlassInk(state)
end

local function drawText(value, x, y, ink)
  local Font = runtime().Font
  value = text(value)
  local pen = x
  local unknown
  local state = ink and beginGlassInk(ink) or nil
  for _, span in ipairs(Font.split(value)) do
    local glyph = value:sub(span.from, span.to)
    if SPECIAL_ADVANCE[glyph] then
      suspendGlassInk(state)
      drawSpecial(glyph, pen, y)
      resumeGlassInk(state)
    elseif span.code and type(Font.drawCode) == "function" then
      Font.drawCode(span.code, pen, y)
    else
      if unknown == nil then
        local question = Font.split("?")
        unknown = question[1] and question[1].code or 0x7F
      end
      Font.drawCode(unknown, pen, y)
    end
    pen = pen + spanAdvance(Font, value, span)
  end
  endGlassInk(state)
  return pen - x
end

local function truncate(value, budget)
  local Font = runtime().Font
  value = text(value):gsub("\n.*$", "")
  if displayWidth(value) <= budget then return value end
  local spans = Font.split(value)
  local used, fit = 0, 0
  for index, span in ipairs(spans) do
    used = used + spanAdvance(Font, value, span)
    if used > math.max(0, budget - 8) then break end
    fit = index
  end
  if fit < 1 then return "." end
  return value:sub(1, spans[fit].to) .. "."
end

local function panel(x, y, w, h, fill, border)
  color(fill)
  love.graphics.rectangle("fill", x, y, w, h)
  color(border or COLORS.blue3)
  love.graphics.rectangle("line", x + .5, y + .5, w - 1, h - 1)
end

local function menuAccent(menu)
  if type(menu) == "table" and type(menu.__vascEditionAccent) == "table" then
    return menu.__vascEditionAccent
  end
  return SHARED_ACCENT
end

local function editionFrame(menu, x, y, w, h, radius)
  color(menuAccent(menu))
  love.graphics.rectangle("line", x + .5, y + .5, w - 1, h - 1,
    radius or 0, radius or 0)
end

local function orasEditionFrame(menu, width, height)
  local graphics = love.graphics
  if type(graphics.setLineWidth) == "function" then graphics.setLineWidth(2) end
  color(COLORS.white)
  graphics.rectangle("line", 1.5, 1.5, width - 3, height - 3, 6, 6)
  if type(graphics.setLineWidth) == "function" then graphics.setLineWidth(1) end
  color(menuAccent(menu))
  graphics.rectangle("line", 4.5, 4.5, width - 9, height - 9, 4, 4)
end

local function wrapLines(value, budget)
  local Font = runtime().Font
  local lines = {}
  value = text(value)
  for paragraph in (value .. "\n"):gmatch("(.-)\n") do
    if paragraph == "" then
      lines[#lines + 1] = ""
    else
      local remaining = paragraph
      while remaining ~= "" do
        local spans = Font.split(remaining)
        local fit = Font.spansFitting(spans, budget)
        if fit >= #spans then
          lines[#lines + 1] = remaining
          break
        end
        fit = math.max(1, fit)
        local cut = spans[fit].to
        for index = fit, 1, -1 do
          local glyph = remaining:sub(spans[index].from, spans[index].to)
          if glyph == " " or glyph == "-" or glyph == "/" then
            cut = spans[index].to
            break
          end
        end
        lines[#lines + 1] = remaining:sub(1, cut):gsub("%s+$", "")
        remaining = remaining:sub(cut + 1):gsub("^%s+", "")
      end
    end
  end
  if lines[#lines] == "" then lines[#lines] = nil end
  return lines
end

local function controls(menu, budget)
  budget = tonumber(budget) or 146
  if menu.footer then return truncate(menu.footer, budget) end
  if menu.pageJump then return "A:OK L/R:PG B:BK" end
  return "A:SELECT  B:BACK"
end

local function pingPongOffset(time, overflow)
  if not (overflow and overflow > 0) then return 0 end
  local hold, speed = 1.2, 6
  local travel = overflow / speed
  local cycle = 2 * hold + 2 * travel
  local phase = (tonumber(time) or 0) % cycle
  if phase < hold then return 0 end
  phase = phase - hold
  if phase < travel then return -phase * speed end
  phase = phase - travel
  if phase < hold then return -overflow end
  return -overflow + (phase - hold) * speed
end

local function focusedHelp(menu)
  local item = menu.items and menu.items[menu.index]
  local provider = menu.ascendantFocusHelp
  if type(provider) == "function" then
    local ok, value = pcall(provider, item, menu)
    if ok and value ~= nil then return text(value):gsub("[\r\n]+", " ") end
  end
  if item and item.help then return text(item.help):gsub("[\r\n]+", " ") end
  return menu.__vascLanguage == "de"
    and "Eintrag wählen. SELECT öffnet die ganze Hilfe."
    or "Choose an entry. SELECT opens full help."
end

local function drawMarquee(value, x, y, budget, time)
  value = tostring(value or "")
  local width = displayWidth(value)
  if width <= budget or not love.graphics.setScissor then
    drawText(truncate(value, budget), x, y)
    return
  end
  local offset = pingPongOffset(time, width - budget)
  -- During the initial reading hold, show an explicit fitted continuation
  -- marker.  Drawing the unshortened line under a scissor at offset zero
  -- chops the final glyph in half and looks like a broken layout.  The full
  -- text still becomes available when the marquee starts, and immediately in
  -- the SELECT/START help popup.
  if offset == 0 then
    drawText(truncate(value, budget), x, y)
    return
  end
  love.graphics.setScissor(x, y - 1, budget, 10)
  drawText(value, x + offset, y)
  love.graphics.setScissor()
end

-- VASC mirrors KASC 6.5.18's permanent, cursor-sensitive help strip while
-- keeping the implementation and text entirely renderer-owned. Five rows
-- remain visible; START/SELECT still opens the full paged explanation.
local function drawFocusHelp(menu)
  local Font, Theme = runtime().Font, runtime().Theme
  local C = COLORS
  color(C.paper)
  love.graphics.rectangle("fill", 0, 0, 160, 144)

  color(C.blue3)
  love.graphics.rectangle("fill", 0, 0, 160, 18)
  color(C.blue2)
  love.graphics.rectangle("fill", 0, 16, 160, 3)
  color(C.orange)
  love.graphics.rectangle("fill", 0, 0, 8, 18)
  color(C.red)
  love.graphics.rectangle("fill", 0, 15, 8, 4)
  panel(9, 2, 148, 14, C.cream, menuAccent(menu))
  color(C.ink)
  drawText(truncate(menu.title, 144), 12, 5)

  panel(3, 21, 154, 83, C.cream, C.blue3)
  if #(menu.items or {}) == 0 then
    color(C.ink)
    drawText(menu.__vascLanguage == "de" and "Nichts vorhanden."
      or "Nothing here.", 16, 58)
  end

  local rows = math.min(menu.rows or 5, 5)
  for row = 1, rows do
    local index = (menu.scroll or 0) + row
    local item = menu.items[index]
    if not item then break end
    local y = 25 + (row - 1) * 16
    if index == menu.index then
      color(C.gold)
      love.graphics.rectangle("fill", 6, y - 2, 148, 14)
      color(C.orange)
      love.graphics.rectangle("fill", 6, y + 10, 148, 2)
    elseif row % 2 == 0 then
      color(C.paper)
      love.graphics.rectangle("fill", 6, y - 2, 148, 14)
    end

    color(C.ink)
    local right = truncate(item.right, 64)
    local rightX = item.right and (151 - displayWidth(right)) or 151
    local rootRow = menu.__voxelAscendantRoot == true and not item.right
    local labelX = rootRow and 14 or 17
    local labelBudget = item.right
      and math.max(24, rightX - labelX - 4)
      or (151 - labelX)
    drawText(truncate(item.label, labelBudget), labelX, y, item.muted and {.45,.45,.45,1} or nil)
    if item.right then drawText(right, rightX, y,
      statusInk(item, C.ink, true)) end
    if index == menu.index then
      Font.drawCode((menu.swapIndex == index or menu.hollowIndex == index)
        and Theme.cursorHollow or Theme.cursor, rootRow and 6 or 8, y)
    elseif menu.swapIndex == index then
      Font.drawCode(Theme.cursorHollow, rootRow and 6 or 8, y)
    end
  end

  if (menu.scroll or 0) > 0 then
    color(C.red)
    Font.drawCode(Theme.moreArrow, 145, 4)
  end
  if (menu.scroll or 0) + rows < #(menu.items or {}) then
    color(C.red)
    Font.drawCode(Theme.moreArrow, 145, 96)
  end

  panel(3, 106, 154, 18, C.paper2, menuAccent(menu))
  color(C.blue)
  love.graphics.rectangle("fill", 4, 107, 152, 3)
  color(C.ink)
  local help = focusedHelp(menu)
  menu.ascendantFocusedHelp = help
  drawMarquee(help, 7, 112, 146, menu.ascendantFocusTime)

  color(C.blue)
  love.graphics.rectangle("fill", 3, 127, 154, 14)
  color(C.blue3)
  love.graphics.rectangle("fill", 3, 127, 154, 2)
  panel(5, 129, 150, 12, C.cream, menuAccent(menu))
  color(C.ink)
  drawText(truncate(controls(menu), 146), 7, 131)
  editionFrame(menu, 0, 0, 160, 144)
end

local function glassPanel(x, y, w, h, fill, border, radius)
  color(fill or COLORS.glass)
  love.graphics.rectangle("fill", x, y, w, h, radius or 5, radius or 5)
  color(border or COLORS.glassLine)
  love.graphics.rectangle("line", x + .5, y + .5, w - 1, h - 1,
    radius or 5, radius or 5)
end

-- Fullscreen ORAS glass is intentionally a settings-screen composition, not
-- a global ListMenu theme.  Its geometry is derived solely from uiSize(), so
-- it remains deterministic under headless tests and all window/DPI layouts.
local function drawOrasFocusHelp(menu)
  local Font, Theme = runtime().Font, runtime().Theme
  local C = COLORS
  local width, height = activeOrasUiSize(menu)
  local margin, gap = 16, 12
  local headerY, headerH = 12, 36
  local footerH = 26
  local footerY = height - margin - footerH
  local contentY = headerY + headerH + 10
  local contentH = footerY - contentY - 10
  local listW = math.max(188, math.min(292, math.floor(width * .54)))
  local helpX = margin + listW + gap
  local helpW = width - helpX - margin
  local rows = math.max(1, math.min(menu.rows or 9,
    math.floor((contentH - 16) / 20)))

  menu.__vascOrasGeometry = {
    width=width, height=height, rows=rows,
    list={ x=margin, y=contentY, w=listW, h=contentH },
    help={ x=helpX, y=contentY, w=helpW, h=contentH },
    footer={ x=margin, y=footerY, w=width - margin * 2, h=footerH },
  }

  color(C.glassBack)
  love.graphics.rectangle("fill", 0, 0, width, height)
  color(C.glassBack2)
  love.graphics.rectangle("fill", 0, 0, width, math.floor(height * .54))
  color(menuAccent(menu))
  love.graphics.rectangle("fill", 0, 0, 6, height)
  love.graphics.rectangle("fill", width - 3, 0, 3, height)

  glassPanel(margin, headerY, width - margin * 2, headerH, C.glassSoft,
    menuAccent(menu), 7)
  local skinLabel = menu.__vascHeaderLabel or (menu.__vascLanguage == "de"
    and "VASC / KASC OPTIONEN" or "VASC / KASC SETTINGS")
  -- Even the minimum 4:3 logical surface has room for every current section
  -- title and the complete settings label.  Budget from the actual glyph
  -- widths rather than a percentage which shortened SETTINGS to SETTI.
  local wantedTitle = displayWidth(menu.title)
  local titleReserve = math.min(wantedTitle, 144)
  local maxSkinBudget = math.max(88,
    width - margin * 2 - 26 - titleReserve)
  local skinBudget = math.min(math.max(88, displayWidth(skinLabel)),
    maxSkinBudget)
  local skinX = width - margin - skinBudget
  drawText(truncate(menu.title, math.max(80, skinX - margin - 26)), margin + 14,
    headerY + 8, C.glassText)
  drawText(truncate(skinLabel, skinBudget), skinX, headerY + 8, C.glassMuted)
  color(menuAccent(menu))
  love.graphics.rectangle("fill", margin + 10, headerY + 25,
    width - margin * 2 - 20, 2)

  glassPanel(margin, contentY, listW, contentH, C.glass, C.glassLine, 7)
  if #(menu.items or {}) == 0 then
    drawText(menu.__vascLanguage == "de" and "Nichts vorhanden."
      or "Nothing here.", margin + 18, contentY + 24, C.glassText)
  end

  local rowX, rowW = margin + 8, listW - 16
  for row = 1, rows do
    local index = (menu.scroll or 0) + row
    local item = menu.items[index]
    if not item then break end
    local y = contentY + 10 + (row - 1) * 20
    if index == menu.index then
      color(C.glassSoft)
      love.graphics.rectangle("fill", rowX, y - 3, rowW, 17, 4, 4)
      color(menuAccent(menu))
      love.graphics.rectangle("fill", rowX, y - 3, 4, 17, 2, 2)
      color(C.glassGold)
      love.graphics.rectangle("line", rowX + .5, y - 2.5,
        rowW - 1, 16, 4, 4)
    elseif row % 2 == 0 then
      color({ C.glassSoft[1], C.glassSoft[2], C.glassSoft[3], .35 })
      love.graphics.rectangle("fill", rowX, y - 3, rowW, 17, 4, 4)
    end

    local cursorX = rowX + 4
    local labelX = cursorX + 12
    local right = item.right and truncate(item.right, math.min(112, rowW * .42))
    local rightX = right and (rowX + rowW - 7 - displayWidth(right))
      or (rowX + rowW - 7)
    local labelBudget = right
      and math.max(40, rightX - labelX - 8)
      or math.max(40, rowX + rowW - labelX - 7)
    local labelInk = item.muted and {.5,.53,.56,1}
      or index == menu.index and C.glassText or C.glassMuted
    drawText(truncate(item.label, labelBudget), labelX, y, labelInk)
    if right then
      local rightInk = statusInk(item,
        index == menu.index and C.glassGold or C.glassText, false)
      drawText(right, rightX, y, rightInk)
    end
    if index == menu.index then
      drawCode((menu.swapIndex == index or menu.hollowIndex == index)
        and Theme.cursorHollow or Theme.cursor, cursorX, y, C.glassGold)
    elseif menu.swapIndex == index then
      drawCode(Theme.cursorHollow, cursorX, y, C.glassMuted)
    end
  end

  if (menu.scroll or 0) > 0 then
    drawCode(Theme.moreArrow, margin + listW - 20, contentY + 4,
      C.glassGold)
  end
  if (menu.scroll or 0) + rows < #(menu.items or {}) then
    drawCode(Theme.moreArrow, margin + listW - 20,
      contentY + contentH - 13, C.glassGold)
  end

  glassPanel(helpX, contentY, helpW, contentH, C.glassSoft,
    menuAccent(menu), 7)
  drawText(menu.__vascLanguage == "de" and "HILFE" or "HELP",
    helpX + 12, contentY + 10, C.glassGold)
  color(menuAccent(menu))
  love.graphics.rectangle("fill", helpX + 12, contentY + 24,
    math.max(8, helpW - 24), 2)
  local help = focusedHelp(menu)
  menu.ascendantFocusedHelp = help
  local helpLines = wrapLines(help, math.max(32, helpW - 24))
  local maxHelpLines = math.max(1, math.floor((contentH - 45) / 12))
  for index = 1, math.min(#helpLines, maxHelpLines) do
    drawText(helpLines[index], helpX + 12, contentY + 34 + (index - 1) * 12,
      C.glassText)
  end
  local count = #(menu.items or {})
  local position = count > 0 and math.max(1, math.min(menu.index or 1, count)) or 0
  local counter = ("%02d / %02d"):format(position, count)
  drawText(counter, helpX + helpW - 12 - displayWidth(counter),
    contentY + contentH - 15, C.glassMuted)

  glassPanel(margin, footerY, width - margin * 2, footerH, C.glass,
    C.glassLine, 7)
  drawText(controls(menu, width - margin * 2 - 24),
    margin + 12, footerY + 8, C.glassText)
  orasEditionFrame(menu, width, height)
  color(C.white)
end

local function draw(menu)
  local Font, Theme = runtime().Font, runtime().Theme
  local C = COLORS
  color(C.paper)
  love.graphics.rectangle("fill", 0, 0, 160, 144)

  color(C.blue3)
  love.graphics.rectangle("fill", 0, 0, 160, 18)
  color(C.blue2)
  love.graphics.rectangle("fill", 0, 16, 160, 3)
  color(C.orange)
  love.graphics.rectangle("fill", 0, 0, 8, 18)
  color(C.red)
  love.graphics.rectangle("fill", 0, 15, 8, 4)
  panel(9, 2, 148, 14, C.cream, menuAccent(menu))
  color(C.ink)
  drawText(truncate(menu.title, 144), 12, 5)

  panel(3, 21, 154, 103, C.cream, C.blue3)
  if #(menu.items or {}) == 0 then
    color(C.ink)
    drawText("Nothing here.", 16, 64)
  end

  local rows = math.min(menu.rows or 6, 6)
  for row = 1, rows do
    local index = (menu.scroll or 0) + row
    local item = menu.items[index]
    if not item then break end
    local y = 25 + (row - 1) * 16
    if index == menu.index then
      color(C.gold)
      love.graphics.rectangle("fill", 6, y - 2, 148, 14)
      color(C.orange)
      love.graphics.rectangle("fill", 6, y + 10, 148, 2)
    elseif row % 2 == 0 then
      color(C.paper)
      love.graphics.rectangle("fill", 6, y - 2, 148, 14)
    end

    color(C.ink)
    local right = truncate(item.right, 64)
    local rightX = item.right and (151 - displayWidth(right)) or 151
    local rootRow = menu.__voxelAscendantRoot == true and not item.right
    local labelX = rootRow and 14 or 17
    local labelBudget = item.right
      and math.max(24, rightX - labelX - 4)
      or (151 - labelX)
    drawText(truncate(item.label, labelBudget), labelX, y, item.muted and {.45,.45,.45,1} or nil)
    if item.right then drawText(right, rightX, y,
      statusInk(item, C.ink, true)) end
    if index == menu.index then
      Font.drawCode((menu.swapIndex == index or menu.hollowIndex == index)
        and Theme.cursorHollow or Theme.cursor, rootRow and 6 or 8, y)
    elseif menu.swapIndex == index then
      Font.drawCode(Theme.cursorHollow, rootRow and 6 or 8, y)
    end
  end

  if (menu.scroll or 0) > 0 then
    color(C.red)
    Font.drawCode(Theme.moreArrow, 145, 4)
  end
  if (menu.scroll or 0) + rows < #(menu.items or {}) then
    color(C.red)
    Font.drawCode(Theme.moreArrow, 145, 113)
  end

  color(C.blue)
  love.graphics.rectangle("fill", 3, 127, 154, 14)
  color(C.blue3)
  love.graphics.rectangle("fill", 3, 127, 154, 2)
  panel(5, 129, 150, 12, C.cream, menuAccent(menu))
  color(C.ink)
  drawText(truncate(controls(menu), 146), 7, 131)
  editionFrame(menu, 0, 0, 160, 144)
  color(C.ink)
end

local HelpPopup = {}
HelpPopup.__index = HelpPopup
HelpPopup.isOpaque = false
local HELP_LINES_PER_PAGE = 7

local function helpPages(body, width, linesPerPage)
  local lines = wrapLines(body, width)
  local pages = {}
  for index, line in ipairs(lines) do
    local page = math.floor((index - 1) / linesPerPage) + 1
    pages[page] = pages[page] or {}
    pages[page][#pages[page] + 1] = line
  end
  return #pages > 0 and pages or { { "" } }
end

function HelpPopup.new(game, title, body, language, skinResolver)
  local fireRedPages = helpPages(body, 144, HELP_LINES_PER_PAGE)
  local orasPages = helpPages(body, 432, 11)
  return setmetatable({
    game=game, title=title, pages=fireRedPages, fireRedPages=fireRedPages,
    orasPages=orasPages, orasPageWidth=432, body=body,
    page=1, skinResolver=skinResolver,
    language=language == "de" and "de" or "en",
  }, HelpPopup)
end

function HelpPopup:skin()
  if type(self.skinResolver) == "function" then
    local ok, value = pcall(self.skinResolver)
    if ok then return normalizedSkin(value) end
  end
  return SKIN_FIRE_RED
end

function HelpPopup:activePages()
  local pages
  if self:skin() == SKIN_ORAS_FULLSCREEN then
    local width = select(1, orasUiSize())
    local budget = math.max(144, width - 88)
    if budget ~= self.orasPageWidth then
      self.orasPages = helpPages(self.body, budget, 11)
      self.orasPageWidth = budget
    end
    pages = self.orasPages
  else
    pages = self.fireRedPages
  end
  self.pages = pages
  self.page = math.max(1, math.min(self.page or 1, #pages))
  return pages
end

function HelpPopup:uiSize()
  if self:skin() == SKIN_ORAS_FULLSCREEN then return activeOrasUiSize(self) end
  return 160, 144
end

function HelpPopup:drawsWidescreen()
  return self:skin() == SKIN_ORAS_FULLSCREEN
end

-- Gen 1 has no physical drawWidescreen compositor.  Its public fullscreen
-- contract is Renderer.uiFill, selected through wantsFillScale().  Without
-- this marker an otherwise correctly sized 384x288/512x288 ORAS surface is
-- still presented at the fixed engine scale and leaves black margins around
-- the complete menu.  FireRed remains on the exact historic fixed scale.
function HelpPopup:wantsFillScale()
  return self:skin() == SKIN_ORAS_FULLSCREEN
end

function HelpPopup:sgbPalettes()
  if self:skin() == SKIN_ORAS_FULLSCREEN then
    local width, height = self:uiSize()
    return { { colors=false, x=0, y=0, w=width, h=height } }
  end
  return { runtime().PaletteFX.trueColorZone(0, 0, 19, 17) }
end

function HelpPopup:update()
  local input = self.game and self.game.input
  if not input or type(input.wasPressed) ~= "function" then return end
  local pages = self:activePages()
  if input:wasPressed("left") or input:wasPressed("up") then
    self.page = math.max(1, self.page - 1)
  elseif input:wasPressed("right") or input:wasPressed("down") then
    self.page = math.min(#pages, self.page + 1)
  elseif input:wasPressed("a") or input:wasPressed("b")
      or input:wasPressed("select") or input:wasPressed("start") then
    if self.game.stack and self.game.stack.pop then self.game.stack:pop() end
  end
end

local function drawFireRedHelpPopup(self)
  local Font = runtime().Font
  local C = COLORS
  local pages = self:activePages()
  love.graphics.setColor(0, 0, 0, .48)
  love.graphics.rectangle("fill", 0, 0, 160, 144)
  panel(2, 3, 156, 138, C.cream, menuAccent(self))
  color(C.blue3)
  love.graphics.rectangle("fill", 3, 4, 154, 18)
  panel(7, 6, 146, 14, C.cream, menuAccent(self))
  color(C.ink)
  drawText(truncate(self.title, 138), 10, 9)
  color(C.ink)
  for index, line in ipairs(pages[self.page]) do
    drawText(line, 8, 27 + (index - 1) * 12)
  end
  color(C.blue)
  love.graphics.rectangle("fill", 3, 122, 154, 18)
  panel(6, 124, 148, 14, C.cream, menuAccent(self))
  color(C.ink)
  local footer
  if #pages > 1 then
    footer = self.language == "de"
      and ("L/R %d/%d A/B ZU"):format(self.page, #pages)
      or ("L/R %d/%d A/B CLOSE"):format(self.page, #pages)
  else
    footer = self.language == "de" and "A/B: ZU" or "A/B: CLOSE"
  end
  drawText(truncate(footer, 140), 9, 127)
  editionFrame(self, 2, 3, 156, 138)
  color(C.white)
end

local function drawOrasHelpPopup(self)
  local C = COLORS
  local pages = self:activePages()
  local width, height = self:uiSize()
  local margin = 22
  color(C.glassBack)
  love.graphics.rectangle("fill", 0, 0, width, height)
  color(C.glassBack2)
  love.graphics.rectangle("fill", 0, 0, width, math.floor(height * .46))
  glassPanel(margin, 18, width - margin * 2, height - 36,
    C.glass, menuAccent(self), 9)
  glassPanel(margin + 12, 30, width - margin * 2 - 24, 34,
    C.glassSoft, C.glassLine, 6)
  drawText(truncate(self.title, width - margin * 2 - 48), margin + 24, 42,
    C.glassText)
  color(menuAccent(self))
  love.graphics.rectangle("fill", margin + 18, 75,
    width - margin * 2 - 36, 2)
  for index, line in ipairs(pages[self.page]) do
    drawText(line, margin + 22, 88 + (index - 1) * 12, C.glassText)
  end
  glassPanel(margin + 12, height - 61, width - margin * 2 - 24, 27,
    C.glassSoft, C.glassLine, 6)
  local footer
  if #pages > 1 then
    footer = self.language == "de"
      and ("L/R  %d/%d     A/B  ZU"):format(self.page, #pages)
      or ("L/R  %d/%d     A/B  CLOSE"):format(self.page, #pages)
  else
    footer = self.language == "de" and "A/B: ZU" or "A/B: CLOSE"
  end
  drawText(truncate(footer, width - margin * 2 - 52),
    margin + 26, height - 52, C.glassGold)
  orasEditionFrame(self, width, height)
  color(C.white)
end

-- Game2's compositor accepts a screen as the physical fullscreen owner only
-- when it publishes BOTH drawsWidescreen() and drawWidescreen(winW, winH).
-- The logical ORAS renderer deliberately remains resolution-independent; this
-- presenter supplies the missing physical layer, centres one integer-scaled
-- logical canvas and paints the small remainder with the same glass backdrop.
-- No input, stack or option ownership crosses this seam.
local function drawOrasWidescreen(owner, winW, winH, drawer)
  local G = love and love.graphics
  if not (G and type(G.rectangle) == "function"
      and type(G.push) == "function" and type(G.pop) == "function"
      and type(G.translate) == "function" and type(G.scale) == "function") then
    return isolatedDraw(drawer, owner)
  end

  winW, winH = tonumber(winW), tonumber(winH)
  if not (winW and winH and winW > 0 and winH > 0) then
    if type(G.getPixelDimensions) == "function" then
      local ok, width, height = pcall(G.getPixelDimensions)
      if ok then winW, winH = tonumber(width), tonumber(height) end
    end
  end
  if not (winW and winH and winW > 0 and winH > 0) then
    return isolatedDraw(drawer, owner)
  end

  local logicalW, logicalH = orasUiSizeFor(winW, winH)
  local scale = math.min(winW / logicalW, winH / logicalH)
  local x = math.floor((winW - logicalW * scale) / 2)
  local y = math.floor((winH - logicalH * scale) / 2)

  return isolatedDraw(function(target)
    color(COLORS.glassBack)
    G.rectangle("fill", 0, 0, winW, winH)
    G.push("all")
    local oldW, oldH = target.__vascWideLogicalWidth,
      target.__vascWideLogicalHeight
    target.__vascWideLogicalWidth = logicalW
    target.__vascWideLogicalHeight = logicalH
    local ok, err = pcall(function()
      G.translate(x, y)
      G.scale(scale, scale)
      drawer(target)
    end)
    target.__vascWideLogicalWidth = oldW
    target.__vascWideLogicalHeight = oldH
    local okPop, popErr = pcall(G.pop)
    if not ok then error(err, 0) end
    if not okPop then error(popErr, 0) end
  end, owner)
end

function HelpPopup:draw()
  local drawer = self:skin() == SKIN_ORAS_FULLSCREEN
    and drawOrasHelpPopup or drawFireRedHelpPopup
  return isolatedDraw(drawer, self)
end

function HelpPopup:drawWidescreen(winW, winH)
  if self:skin() ~= SKIN_ORAS_FULLSCREEN then return self:draw() end
  return drawOrasWidescreen(self, winW, winH, drawOrasHelpPopup)
end

function Style.new(mod, opts)
  opts = opts or {}
  local accent, accentId = resolveEditionAccent(opts.edition)
  local U = {
    colors=COLORS, HelpPopup=HelpPopup,
    displayWidth=displayWidth, rootLabelBudget=137,
    editionAccent=accent, editionAccentId=accentId,
  }
  local guidedHelpSeen = setmetatable({}, { __mode="k" })
  -- KASC owns its controller and does not persist cursor state itself.  Keep
  -- this presentation bridge's tiny navigation receipt process-local and
  -- scoped to the concrete Game/Style owner.  Weak Game keys prevent a
  -- closed session from becoming a lifetime cache, and page+skin slots keep
  -- KASC categories plus FIRE RED/ORAS focus independent without touching
  -- mod.save, options or KASC's global UI facade.
  local kascNavigationByGame = setmetatable({}, { __mode="k" })
  local kascNavigationFallback = { pages={} }
  local skinResolver = opts.skin
  local languageResolver = opts.language

  local function language()
    local configured = languageResolver
    if type(configured) == "function" then
      local ok, value = pcall(configured, mod)
      if ok and (value == "de" or value == "en") then return value end
    elseif configured == "de" or configured == "en" then
      return configured
    end
    return "en"
  end

  local function skin()
    local configured = skinResolver
    if type(configured) == "function" then
      local ok, value = pcall(configured, mod)
      if ok and value ~= nil then return normalizedSkin(value) end
    elseif configured ~= nil then
      return normalizedSkin(configured)
    end
    -- Gen 2 constructs this renderer before VascMenu receives its complete
    -- adapter config.  Reading the public option is the generation-neutral
    -- fallback and remains live after Manager/ModSetting changes.
    local options = mod and mod.options
    if options and type(options.get) == "function" then
      local ok, value = pcall(options.get, options, "vascMenuSkin")
      if ok and value ~= nil then return normalizedSkin(value) end
    end
    return SKIN_ORAS_FULLSCREEN
  end

  function U.setSkinResolver(resolver)
    skinResolver = resolver
    return U
  end

  function U.setLanguageResolver(resolver)
    languageResolver = resolver
    return U
  end

  function U.currentSkin()
    return skin()
  end

  -- Narrow, test-only isolation seam used by RC interaction QA.  It returns a
  -- one-shot cleanup instead of exposing a general cache mutation API.
  function U._qaBeginNavigationIsolation(game)
    if type(game) ~= "table" then
      return nil, "game-owner-unavailable"
    end
    local original = kascNavigationByGame[game]
    local isolated = cloneNavigationGraph(original or { pages={} })
    isolated.pages = type(isolated.pages) == "table" and isolated.pages or {}
    kascNavigationByGame[game] = isolated
    local active = true
    return function()
      if not active then return true end
      active = false
      kascNavigationByGame[game] = original
      return kascNavigationByGame[game] == original
    end, {
      schema="voxel-ascendant/qa-navigation-isolation/v1",
      owner="kasc-menu-style", original_present=original ~= nil,
    }
  end

  local function clampMenu(menu)
    local count = #(menu.items or {})
    menu.index = count > 0
      and math.max(1, math.min(math.floor(tonumber(menu.index) or 1), count))
      or 1
    local rows = math.max(1, math.floor(tonumber(menu.rows) or 1))
    local maxScroll = math.max(0, count - rows)
    menu.scroll = math.max(0,
      math.min(math.floor(tonumber(menu.scroll) or 0), maxScroll))
    if count > 0 and menu.index <= menu.scroll then
      menu.scroll = menu.index - 1
    elseif count > 0 and menu.index > menu.scroll + rows then
      menu.scroll = menu.index - rows
    end
  end

  local function applyMenuSkin(menu)
    local selected = menu.__vascEmergencyCompactFallback
      and SKIN_FIRE_RED or skin()
    menu.__vascMenuSkin = selected
    if selected == SKIN_ORAS_FULLSCREEN then
      menu.__kantoAscendantStyle = "oras-fullscreen-glass"
      menu.rows = menu.__vascOrasRows or 9
    else
      menu.__kantoAscendantStyle = menu.__vascFireRedStyle
        or (menu.__vascHasFocusHelp and "firered-focus-help" or "firered")
      menu.rows = menu.__vascFireRedRows
        or (menu.__vascHasFocusHelp and 5 or 6)
    end
    clampMenu(menu)
    return selected
  end

  local function installDynamicPresentation(menu, focusHelp, style, requestedRows)
    menu.__kantoAscendantLayout = true
    menu.__voxelAscendantStandaloneStyle = true
    menu.__vascHasFocusHelp = focusHelp and true or false
    menu.__voxelAscendantFocusHelp = focusHelp and true or nil
    menu.__vascFireRedStyle = style
      or (focusHelp and "firered-focus-help" or "firered")
    menu.__vascFireRedRows = math.min(tonumber(requestedRows)
      or (focusHelp and 5 or 6), focusHelp and 5 or 6)
    menu.__vascOrasRows = math.min(tonumber(requestedRows) or 9, 9)
    menu.__vascEditionAccent = accent
    menu.__vascEditionAccentId = accentId
    menu.isOpaque = true
    menu.ascendantFocusHelp = focusHelp
    menu.ascendantFocusTime = menu.ascendantFocusTime or 0
    menu.__vascLanguage = language()

    local baseUiSize = menu.uiSize
    function menu:uiSize()
      if applyMenuSkin(self) == SKIN_ORAS_FULLSCREEN then
        return orasUiSize()
      end
      if type(baseUiSize) == "function" then return baseUiSize(self) end
      return 160, 144
    end
    local baseDrawsWidescreen = menu.drawsWidescreen
    function menu:drawsWidescreen()
      if applyMenuSkin(self) == SKIN_ORAS_FULLSCREEN then return true end
      if type(baseDrawsWidescreen) == "function" then
        local ok, value = pcall(baseDrawsWidescreen, self)
        return ok and value == true
      end
      return false
    end
    local baseWantsFillScale = menu.wantsFillScale
    function menu:wantsFillScale()
      if applyMenuSkin(self) == SKIN_ORAS_FULLSCREEN then return true end
      if type(baseWantsFillScale) == "function" then
        local ok, value = pcall(baseWantsFillScale, self)
        return ok and value == true
      end
      return false
    end
    menu.sgbPalettes = function(self)
      if applyMenuSkin(self) == SKIN_ORAS_FULLSCREEN then
        local width, height = orasUiSize()
        return { { colors=false, x=0, y=0, w=width, h=height } }
      end
      return { runtime().PaletteFX.trueColorZone(0, 0, 19, 17) }
    end

    local baseUpdate = menu.update
    menu.update = function(self, dt, ...)
      applyMenuSkin(self)
      local before = self.index
      local result
      if type(baseUpdate) == "function" then
        result = baseUpdate(self, dt, ...)
      end
      applyMenuSkin(self)
      if self.index ~= before then
        self.ascendantFocusTime = 0
      else
        self.ascendantFocusTime = (self.ascendantFocusTime or 0)
          + math.max(0, tonumber(dt) or 0)
      end
      return result
    end
    menu.draw = function(self)
      local selected = applyMenuSkin(self)
      local drawer = selected == SKIN_ORAS_FULLSCREEN
        and drawOrasFocusHelp
        or (self.__vascHasFocusHelp and drawFocusHelp or draw)
      if selected ~= SKIN_ORAS_FULLSCREEN then
        return isolatedDraw(drawer, self)
      end
      local ok, result = pcall(isolatedDraw, drawer, self)
      if ok then return result end
      -- The compact implementation is intentionally no longer selectable.
      -- It remains a per-screen emergency renderer so a shader/API failure in
      -- the wide composition cannot strand the user outside the settings.
      self.__vascEmergencyCompactFallback = tostring(result)
      applyMenuSkin(self)
      return isolatedDraw(self.__vascHasFocusHelp and drawFocusHelp or draw,
        self)
    end
    menu.drawWidescreen = function(self, winW, winH)
      if applyMenuSkin(self) ~= SKIN_ORAS_FULLSCREEN then
        return self:draw()
      end
      local ok, result = pcall(drawOrasWidescreen, self, winW, winH,
        drawOrasFocusHelp)
      if ok then return result end
      -- Keep the same per-instance recovery contract as draw(): one failed
      -- physical ORAS frame switches future frames back to the internal
      -- compact presenter instead of trapping the settings stack.
      self.__vascEmergencyCompactFallback = tostring(result)
      applyMenuSkin(self)
      return self:draw()
    end
    applyMenuSkin(menu)
    return menu
  end

  function U.decorate(menu, style)
    if type(menu) ~= "table" or menu.__kantoAscendantLayout then return menu end
    -- Compatibility receipt retained for the shared Gen-2 audit: the
    -- historical default assignment was
    --   __kantoAscendantStyle = style or "firered"
    -- and applyMenuSkin still resolves to that exact value unless the player
    -- explicitly selected ORAS FULLSCREEN.
    return installDynamicPresentation(menu, nil, style or "firered", nil)
  end

  function U.decorateFocusHelp(menu, provider, requestedRows)
    if type(menu) ~= "table" then return menu end
    return installDynamicPresentation(menu, provider,
      "firered-focus-help", requestedRows)
  end

  local function kascItemKey(item, index)
    if type(item) ~= "table" then return "index:" .. tostring(index or 1) end
    local function scalar(prefix, value)
      local kind = type(value)
      if kind == "string" or kind == "number" or kind == "boolean" then
        return prefix .. tostring(value)
      end
    end
    local stable = scalar("ascendant:", item.ascendantKey)
      or scalar("setting:", item.settingKey)
      or scalar("value:", item.value)
      or scalar("section:", item.section)
      or scalar("action:", item.action)
    if stable then return stable end
    return "label:" .. tostring(item.label or index or "row")
  end

  local function kascNavigationPage(menu)
    local game = rawget(menu, "game")
    local state
    if type(game) == "table" then
      state = kascNavigationByGame[game]
      if type(state) ~= "table" then
        state = { pages={} }
        kascNavigationByGame[game] = state
      end
    else
      state = kascNavigationFallback
    end
    state.pages = type(state.pages) == "table" and state.pages or {}
    local key = tostring(rawget(menu, "__vascKascNavigationKey")
      or rawget(menu, "title") or "KANTO ASCENDANT")
    local page = state.pages[key]
    if type(page) ~= "table" then
      page = { fire={}, oras={} }
      state.pages[key] = page
    end
    page.fire = type(page.fire) == "table" and page.fire or {}
    page.oras = type(page.oras) == "table" and page.oras or {}
    return page, key
  end

  local function kascItemContext(items, index, key)
    local occurrence = 0
    for candidate = 1, math.min(index, #(items or {})) do
      if kascItemKey(items[candidate], candidate) == key then
        occurrence = occurrence + 1
      end
    end
    return occurrence,
      index > 1 and kascItemKey(items[index - 1], index - 1) or nil,
      index < #(items or {}) and kascItemKey(items[index + 1], index + 1) or nil
  end

  -- KASC owns its ASCENDANT controller and its original FireRed renderer.
  -- This narrow adapter multiplexes only a documented focus-help list: FireRed
  -- continues to call KASC's exact methods, while the explicitly selected ORAS
  -- skin calls VASC's fullscreen presentation.  The skin is resolved for every
  -- method invocation so a menu already below VASC's settings page changes in
  -- place when the player returns, without rebuilding its items or losing the
  -- controller-owned cursor/scroll state.
  function U.bridgeFocusHelp(menu, provider, requestedRows)
    if type(menu) ~= "table" then return menu end
    local existing = rawget(menu, "__vascKascMenuSkinBridge")
    if type(existing) == "table"
        and existing.schema == "voxel-ascendant/kasc-menu-skin/v1" then
      return menu
    end

    local fire = {
      update=menu.update, draw=menu.draw, uiSize=menu.uiSize,
      drawsWidescreen=menu.drawsWidescreen, sgbPalettes=menu.sgbPalettes,
      close=menu.close, rows=menu.rows, style=menu.__kantoAscendantStyle,
      vascSkin=menu.__vascMenuSkin, scroll=menu.scroll,
    }
    installDynamicPresentation(menu, provider,
      fire.style or "firered-focus-help", requestedRows or fire.rows)
    local oras = {
      update=menu.update, draw=menu.draw, uiSize=menu.uiSize,
      drawsWidescreen=menu.drawsWidescreen, sgbPalettes=menu.sgbPalettes,
    }
    local navigation, navigationKey = kascNavigationPage(menu)
    local receipt = {
      schema="voxel-ascendant/kasc-menu-skin/v1",
      fire=fire, oras=oras, scroll={ fire=fire.scroll, oras=menu.scroll },
      navigation={ schema="voxel-ascendant/kasc-navigation/v1",
        page=navigationKey, slots=navigation },
    }
    menu.__vascKascMenuSkinBridge = receipt

    local function useOras()
      return skin() == SKIN_ORAS_FULLSCREEN
    end

    local function remember(self, target)
      target = target or receipt.active or (useOras() and "oras" or "fire")
      clampMenu(self)
      local slot = navigation[target]
      local index = math.floor(tonumber(self.index) or 1)
      local items = self.items or {}
      local itemKey = kascItemKey(items[index], index)
      local occurrence, previousKey, nextKey =
        kascItemContext(items, index, itemKey)
      slot.index = index
      slot.scroll = math.floor(tonumber(self.scroll) or 0)
      slot.itemKey = itemKey
      slot.itemOccurrence = occurrence
      slot.previousKey, slot.nextKey = previousKey, nextKey
      receipt.scroll[target] = slot.scroll
      return true
    end

    local function restore(self, target)
      local slot = navigation[target]
      if slot.index == nil and slot.itemKey == nil then
        return remember(self, target)
      end
      local found, foundScore, foundDistance
      if type(slot.itemKey) == "string" then
        local occurrence = 0
        for index, item in ipairs(self.items or {}) do
          if kascItemKey(item, index) == slot.itemKey then
            occurrence = occurrence + 1
            local _, previousKey, nextKey =
              kascItemContext(self.items, index, slot.itemKey)
            local score = 0
            if slot.previousKey ~= nil and previousKey == slot.previousKey then
              score = score + 4
            end
            if slot.nextKey ~= nil and nextKey == slot.nextKey then
              score = score + 4
            end
            if slot.itemOccurrence ~= nil
                and occurrence == slot.itemOccurrence then score = score + 2 end
            local distance = math.abs(index - (tonumber(slot.index) or index))
            if found == nil or score > foundScore
                or (score == foundScore and distance < foundDistance) then
              found, foundScore, foundDistance = index, score, distance
            end
          end
        end
      end
      self.index = found or math.floor(tonumber(slot.index) or self.index or 1)
      self.scroll = math.floor(tonumber(slot.scroll) or self.scroll or 0)
      clampMenu(self)
      remember(self, target)
      return found ~= nil
    end

    local function selectPresentation(self)
      local target = useOras() and "oras" or "fire"
      if receipt.active ~= target then
        if receipt.active then remember(self, receipt.active) end
        receipt.active = target
      end
      if target == "oras" then
        applyMenuSkin(self)
      else
        self.__vascMenuSkin = fire.vascSkin
        self.__kantoAscendantStyle = fire.style or "firered-focus-help"
        self.rows = fire.rows or 5
        clampMenu(self)
      end
      if receipt.restored ~= target then
        restore(self, target)
        receipt.restored = target
      end
    end

    menu.update = function(self, ...)
      selectPresentation(self)
      local fn = useOras() and oras.update or fire.update
      if type(fn) ~= "function" then return end
      local results = packed(fn(self, ...))
      selectPresentation(self)
      remember(self, receipt.active)
      return unpackValues(results, 1, results.n)
    end
    menu.draw = function(self, ...)
      selectPresentation(self)
      local fn = useOras() and oras.draw or fire.draw
      if type(fn) == "function" then return fn(self, ...) end
    end
    menu.uiSize = function(self, ...)
      selectPresentation(self)
      local fn = useOras() and oras.uiSize or fire.uiSize
      if type(fn) == "function" then return fn(self, ...) end
      return 160, 144
    end
    menu.drawsWidescreen = function(self, ...)
      selectPresentation(self)
      local fn = useOras() and oras.drawsWidescreen or fire.drawsWidescreen
      if type(fn) == "function" then return fn(self, ...) == true end
      return false
    end
    menu.sgbPalettes = function(self, ...)
      selectPresentation(self)
      local fn = useOras() and oras.sgbPalettes or fire.sgbPalettes
      if type(fn) == "function" then return fn(self, ...) end
      return nil
    end
    menu.close = function(self, ...)
      selectPresentation(self)
      remember(self, receipt.active)
      if type(fire.close) == "function" then return fire.close(self, ...) end
    end
    menu.__vascRememberNavigation = function(self)
      selectPresentation(self)
      return remember(self, receipt.active)
    end
    menu.__vascKascNavigationKey = navigationKey
    selectPresentation(menu)
    return menu
  end

  U.ListMenu = {
    new=function(game, title, items, opts)
      opts = opts or {}
      local requestedRows = opts.rows
      if opts.ascendantFocusHelp then
        opts.rows = skin() == SKIN_ORAS_FULLSCREEN
          and math.min(tonumber(opts.rows) or 9, 9)
          or math.min(tonumber(opts.rows) or 5, 5)
      end
      local menu = mod.ui.ListMenu.new(game, title, items, opts)
      if opts.ascendantLayout == false or opts.dialogue
          or (opts.messageBox and opts.ascendantLayout ~= true) then
        return menu
      end
      if opts.ascendantFocusHelp then
        return U.decorateFocusHelp(menu, opts.ascendantFocusHelp, requestedRows)
      end
      return U.decorate(menu, opts.ascendantStyle)
    end,
  }

  function U.showHelp(game, title, body)
    if not (game and game.stack and type(game.stack.push) == "function"
        and body and body ~= "") then return false end
    local popup = HelpPopup.new(game, title, body, language(), skin)
    popup.__vascEditionAccent = accent
    popup.__vascEditionAccentId = accentId
    game.stack:push(popup)
    return true
  end

  function U.guidedList(game, spec)
    spec = spec or {}
    local key = assert(spec.key, "guided VASC menu requires a stable key")
    local title = assert(spec.title, "guided VASC menu requires a title")
    local body = assert(spec.help, "guided VASC menu requires help")
    assert(game and game.stack and type(game.stack.push) == "function",
      "guided VASC menu requires a game stack")

    local rows = {}
    for index, item in ipairs(spec.rows or {}) do rows[index] = item end
    local helpValue = "__kasc_help:" .. tostring(key)
    rows[#rows + 1] = {
      label=language()=="de" and "HILFE" or "HELP",
      value=helpValue, help=body, __kascFeatureHelp=true,
    }

    local listOpts = {}
    for option, value in pairs(spec.options or {}) do listOpts[option] = value end
    listOpts.ascendantLayout = true
    listOpts.ascendantStyle = spec.style or listOpts.ascendantStyle or "firered"
    listOpts.ascendantFocusHelp = function(item)
      return item and item.help or body
    end
    listOpts.footer = spec.footer or (language()=="de"
      and "A:WAHL  SEL:HILFE" or "A:SELECT  SEL:HELP")
    local originalChoose = spec.onChoose or listOpts.onChoose
    local originalSelect = spec.onSelectKey or listOpts.onSelectKey
    listOpts.onChoose = function(item, menu)
      if item and item.value == helpValue then
        return U.showHelp(game, spec.helpTitle or title, body)
      end
      if originalChoose then return originalChoose(item, menu) end
    end
    listOpts.onSelectKey = function(item, menu)
      local itemHelp = item and item.help
      if itemHelp and itemHelp ~= "" then
        return U.showHelp(game, item.label or spec.helpTitle or title, itemHelp)
      end
      if originalSelect then return originalSelect(item, menu) end
      return U.showHelp(game, spec.helpTitle or title, body)
    end

    local menu = U.ListMenu.new(game, title, rows, listOpts)
    menu.__kascGuidedHelpRow = rows[#rows]
    local baseUpdate = menu.update
    function menu:showFirstGuide()
      local stack = game.stack
      if type(stack.top) == "function" and stack:top() ~= self then return false end
      local seen = guidedHelpSeen[game]
      if not seen then
        seen = {}
        guidedHelpSeen[game] = seen
      end
      if seen[key] then return false end
      seen[key] = true
      return U.showHelp(game, spec.helpTitle or title, body)
    end
    if type(baseUpdate) == "function" then
      menu.update = function(self, ...)
        if self:showFirstGuide() then return end
        return baseUpdate(self, ...)
      end
    end
    return menu
  end

  U.truncate = truncate
  U.skinIds = {
    fireRed=SKIN_FIRE_RED,
    orasFullscreen=SKIN_ORAS_FULLSCREEN,
  }
  U.orasUiSize = orasUiSize
  return U
end

Style.colors = COLORS
Style.HelpPopup = HelpPopup
Style.SKIN_FIRE_RED = SKIN_FIRE_RED
Style.SKIN_ORAS_FULLSCREEN = SKIN_ORAS_FULLSCREEN

return Style
