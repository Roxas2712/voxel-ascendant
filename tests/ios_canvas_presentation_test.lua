local Canvas = assert(loadfile("lib/CanvasPresentation.lua"))({})

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected "
          .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

eq(Canvas.preflips("iOS"), true, "iOS owns the world-canvas pre-flip")
eq(Canvas.preflips("Android"), false, "Android is not double-flipped")
eq(Canvas.preflips("OS X"), false, "macOS is not double-flipped")

local x, y, r, sx, sy = Canvas.imageDraw(1280, 800, 1280, 800, "iOS")
eq(x, 0, "iOS backdrop x")
eq(y, 800, "iOS backdrop starts at the lower canvas edge")
eq(r, 0, "iOS backdrop rotation")
eq(sx, 1, "iOS backdrop keeps horizontal handedness")
eq(sy, -1, "iOS backdrop is pre-flipped vertically")

x, y, r, sx, sy = Canvas.imageDraw(640, 400, 1280, 800, "Android")
eq(y, 0, "ordinary backdrop starts at the upper canvas edge")
eq(sx, .5, "ordinary backdrop x scale")
eq(sy, .5, "ordinary backdrop y scale")

eq(Canvas.pointY(120, 800, "iOS"), 680, "iOS point Y")
eq(Canvas.rectY(120, 80, 800, "iOS"), 600, "iOS rectangle Y")
eq(Canvas.pointY(120, 800, "OS X"), 120, "desktop point Y")
eq(Canvas.rectY(120, 80, 800, "OS X"), 120, "desktop rectangle Y")

local trace = {}
local graphics = {
  translate = function(x0, y0) trace[#trace + 1] = { "translate", x0, y0 } end,
  scale = function(x0, y0) trace[#trace + 1] = { "scale", x0, y0 } end,
}
eq(Canvas.begin2D(graphics, 800, "iOS"), true,
   "iOS weather transform installs")
eq(trace[1][1], "translate", "iOS transform translates first")
eq(trace[1][3], 800, "iOS transform translates by canvas height")
eq(trace[2][1], "scale", "iOS transform scales second")
eq(trace[2][2], 1, "iOS transform preserves X")
eq(trace[2][3], -1, "iOS transform flips Y")

trace = {}
eq(Canvas.begin2D(graphics, 800, "Android"), true,
   "ordinary weather transform is a successful no-op")
eq(#trace, 0, "ordinary weather transform emits no operations")
eq(Canvas.begin2D({}, 800, "iOS"), false,
   "missing graphics transform fails closed")

print("iOS Arena Scenery and weather canvas orientation: ok")
