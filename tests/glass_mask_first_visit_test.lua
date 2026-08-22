-- Window discovery is first-use work. Its shape matcher may inspect one
-- texel through several overlapping candidates, but the native ImageData
-- reader must be crossed at most once for that texel and preparation must be
-- retained for the tileset.

local assetReads = 0
local calls = {}
local w, h = 16, 10

local function isBlackPixel(x, y)
  if (y == 1 or y == 6) and x >= 3 and x <= 8 then return true end
  if y >= 2 and y <= 5 and (x == 2 or x == 9) then return true end
  return false
end

local data = {}
function data:getDimensions() return w, h end
function data:getPixel(x, y)
  local key = y * w + x
  calls[key] = (calls[key] or 0) + 1
  if isBlackPixel(x, y) then return 0, 0, 0, 1 end
  return 1, 1, 1, 1
end

package.preload["src.render.Assets"] = function()
  return {
    imageData = function()
      assetReads = assetReads + 1
      return data
    end,
  }
end

local previousLove = love
love = {
  image = {
    newImageData = function()
      return { setPixel = function() end }
    end,
  },
  graphics = {
    newImage = function()
      return { setFilter = function() end }
    end,
  },
}

local GlassMask = assert(loadfile("lib/GlassMask.lua"))({})

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected "
          .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local rects = GlassMask.scan(function(x, y) return data:getPixel(x, y) end,
                             w, h)
eq(#rects, 1, "pane detector changed its result")
eq(rects[1].x, 3, "pane x")
eq(rects[1].y, 2, "pane y")
eq(rects[1].w, 6, "pane width")
eq(rects[1].h, 4, "pane height")
for key, count in pairs(calls) do
  eq(count, 1, "native pixel " .. tostring(key) .. " was read repeatedly")
end

calls = {}
local tileset = { image = "fixture/windows.png" }
eq(GlassMask.prepared(tileset), false, "cold tileset started prepared")
eq(GlassMask.prepare(tileset), true, "tileset preparation failed")
eq(GlassMask.prepared(tileset), true, "prepared tileset was not retained")
GlassMask.texture(tileset)
GlassMask.rects(tileset)
eq(assetReads, 1, "prepared glass art was reopened by visible draw calls")
for key, count in pairs(calls) do
  eq(count, 1, "prepared scan reread native pixel " .. tostring(key))
end

love = previousLove
print("glass mask first-visit scan/preparation: ok")
