-- ORAS battle text is a presentation-only reflow of the engine-owned page.
-- The engine remains authoritative for typewriter glyph counts, CONT waits,
-- callbacks and page changes; this contract only proves that every revealed
-- word fits the wider ORAS message plate without clipping.

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected " .. tostring(expected)
      .. ", got " .. tostring(actual), 2)
  end
end

local function check(value, message)
  if not value then error(message or "check failed", 2) end
end

local Layout = assert(loadfile("lib/OrasBattleMessageLayout.lua"))()
assert(loadfile("battle_hud_oras.lua"), "battle_hud_oras.lua does not compile")

-- Fixed-width stand-in for the real Gen1 font. split() preserves UTF-8 glyphs
-- and the POKeMON ligature-shaped token as indivisible units, matching the API
-- that production passes from src.render.Font.
local Font = {}
function Font.split(text)
  local spans, index = {}, 1
  while index <= #text do
    local lead = text:byte(index)
    local last = index
    if lead >= 0xC0 then
      last = index + 1
      while last + 1 <= #text do
        local byte = text:byte(last + 1)
        if byte < 0x80 or byte > 0xBF then break end
        last = last + 1
      end
    end
    spans[#spans + 1] = { from=index, to=last }
    index = last + 1
  end
  return spans
end
function Font.width(text)
  return #Font.split(text) * 8
end

local function flattened(layout)
  local out = {}
  for _, line in ipairs(layout.lines) do
    out[#out + 1] = line.text
  end
  return table.concat(out, " "):gsub("%s+", " ")
end

local function assertSafe(layout, expected, label)
  check(layout and type(layout.lines) == "table", label .. " has no lines")
  eq(flattened(layout), expected, label .. " lost or duplicated text")
  check(#layout.lines >= 1 and #layout.lines <= layout.maxLines,
    label .. " exceeded its vertical line budget")
  local previous = nil
  for _, line in ipairs(layout.lines) do
    check(line.width * line.scale <= layout.maxWidth + 0.001,
      label .. " overflows the ORAS plate")
    check(not line.text:match("^%s") and not line.text:match("%s$"),
      label .. " retained a broken wrap-space")
    check(line.y >= layout.top
      and line.y + 8 * line.scale
        <= layout.logicalHeight - layout.bottom + 0.001,
      label .. " escaped the vertical text-safe area")
    if previous then
      check(line.y >= previous.y + 8 * previous.scale - 0.001,
        label .. " overlaps adjacent visual rows")
    end
    previous = line
  end
end

local options = {
  logicalWidth=288, logicalHeight=64,
  textX=13, rightPadding=13, top=7, bottom=7,
  textScale=1.18, minScale=0.72, lineGap=2,
}

-- Normal battle: the long nickname must move as one word, never clip at the
-- right edge and never be split through the name.
local normal = "ULTRALANGERNICKNAME used THUNDERBOLT!"
local normalLayout = Layout.layout(Font, { normal }, options)
assertSafe(normalLayout, normal, "normal battle")
check(normalLayout.lines[1].text:find("ULTRALANGERNICKNAME", 1, true),
  "long nickname was cut at the measured edge")
check(not normalLayout.lines[1].text:find("ULTRALANGERNICKNAM ", 1, true),
  "long nickname was split inside the word")

-- Localized German messages are longer than their English source. The ORAS
-- plate may use three or more visual lines without changing the engine page.
local german = "ULTRALANGERNICKNAME wurde in BOX NUMMER ZWOELF uebertragen!"
local germanLayout = Layout.layout(Font, { german }, options)
assertSafe(germanLayout, german, "German transfer")
check(#germanLayout.lines >= 3,
  "larger ORAS plate did not use its extra visual rows")

-- The two engine-retained rows are flattened only visually. This covers the
-- Safari catch text and caught-Pokemon nickname question without altering the
-- native CONT/page boundary between those source rows.
local safariRows = {
  "WILD ULTRALANGERNICKNAME was caught!",
  "Give a nickname to ULTRALANGERNICKNAME?",
}
local safariExpected = table.concat(safariRows, " ")
local safariLayout = Layout.layout(Font, safariRows, options)
assertSafe(safariLayout, safariExpected, "Safari/nickname")

-- MoveLearn/TextBox uses the same visual contract. UTF-8 glyph spans stay
-- intact and a single overlong word scales down as a whole instead of being
-- split in its middle.
local moveLearn = "BISASAM möchte ÜBERHYPERMEGASTRAHL lernen!"
local moveLayout = Layout.layout(Font, { moveLearn }, options)
assertSafe(moveLayout, moveLearn, "MoveLearn")
for _, line in ipairs(moveLayout.lines) do
  check(not line.text:find("\195$"), "UTF-8 glyph was cut at a byte boundary")
end

local hugeName = "ABCDEFGHIJKLMNOPQRSTUVWXYZABCDE"
local hugeLayout = Layout.layout(Font, { hugeName }, options)
assertSafe(hugeLayout, hugeName, "single overlong name")
eq(#hugeLayout.lines, 1, "single name was broken into multiple rows")
check(hugeLayout.lines[1].scale < options.textScale,
  "single overlong name was not fitted atomically")

-- A partially revealed typewriter word is still allowed to grow, but reflow
-- itself must be pure and must not synthesize, consume or advance any glyph.
local partial = "ULTRALANGERNI"
local partialRows = { partial }
local partialLayout = Layout.layout(Font, partialRows, options)
assertSafe(partialLayout, partial, "partial typewriter")
eq(partialRows[1], partial, "visual reflow mutated engine-owned revealed text")

local impossible = Layout.layout(Font, {
  "ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKL",
}, options)
eq(impossible.complete, false,
  "unreadably small single word did not fail open as a whole surface")
eq(#impossible.lines, 0,
  "failed surface retained a clipped/microscopic display row")

-- Pixel width, not byte/glyph count, drives wrapping. Equal-length rows with
-- a variable-advance font therefore produce different visual layouts.
local VariableFont = { split=Font.split }
function VariableFont.width(text)
  local width = 0
  for _, span in ipairs(VariableFont.split(text)) do
    local glyph = text:sub(span.from, span.to)
    width = width + (glyph == "W" and 12 or glyph == "I" and 4 or 8)
  end
  return width
end
local wide = Layout.layout(VariableFont, { "WWWWWWWWWW WWWWWWWWWW" }, options)
local narrow = Layout.layout(VariableFont, { "IIIIIIIIII IIIIIIIIII" }, options)
check(#wide.lines > #narrow.lines,
  "layout used character count instead of rendered pixel width")

local source = assert(io.open("battle_hud_oras.lua", "rb")):read("*a")
local _, drawCount = source:gsub("drawMessageLayout%(visual, k%)", "")
eq(drawCount, 3,
  "normal battle and pushed TextBox do not share the exact visual reflow")
local renderStart = assert(source:find(
  "local function renderMessageCanvas", 1, true))
check(assert(source:find("local visual = FloatingHud.layoutMessageLines",
  renderStart, true)) < assert(source:find("\n    g.push()", renderStart, true)),
  "ordinary battle layout is not preflighted before the transform stack")
check(not source:find('error("ORAS battle message does not fit', 1, true),
  "incomplete layout still throws inside the graphics transform")

print("ORAS battle message visual reflow: ok")
