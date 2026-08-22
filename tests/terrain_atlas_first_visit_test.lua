-- RED++ has already baked the exact coloured atlas into renderer.image. The
-- voxel animation copy should read that tiny texture once, before draw, rather
-- than repeat the whole per-pixel CPU palette bake for every connected map.

local previousLove = love
local activeCanvas = { name = "world" }
local activeShader = { name = "scene shader" }
local blend, alpha = "alpha", "alphamultiply"
local color = { 0.25, 0.5, 0.75, 0.8 }
local canvasBuilds, cpuBakes, copyDraws = 0, 0, 0

local function pixels(w, h)
  local data = { w = w or 128, h = h or 48 }
  function data:getDimensions() return self.w, self.h end
  function data:getPixel() return 0.5, 0.5, 0.5, 1 end
  function data:setPixel() end
  function data:paste() end
  return data
end

local raw = pixels()
local Assets = {
  imageData = function() return raw end,
  register = function() end,
}
package.preload["src.render.Assets"] = function() return Assets end
package.preload["src.render.TileRenderer"] = function()
  return {
    defaultAnimatedTiles = function() return {} end,
    recolorSample = function(r, g, b, a) return r, g, b, a end,
    animFrame = function() return 0 end,
  }
end
package.preload["src.render.PaletteFX"] = function()
  return {
    worldGroupColors = function()
      cpuBakes = cpuBakes + 1
      return nil
    end,
  }
end

love = { graphics = {}, image = {}, timer = { getTime = function() return 0 end } }
function love.image.newImageData(w, h) return pixels(w, h) end
function love.graphics.getCanvas() return activeCanvas end
function love.graphics.setCanvas(value) activeCanvas = value end
function love.graphics.getShader() return activeShader end
function love.graphics.setShader(value) activeShader = value end
function love.graphics.getBlendMode() return blend, alpha end
function love.graphics.setBlendMode(a, b) blend, alpha = a, b end
function love.graphics.getColor() return color[1], color[2], color[3], color[4] end
function love.graphics.setColor(r, g, b, a) color = { r, g, b, a } end
function love.graphics.clear() end
function love.graphics.draw()
  if activeShader ~= nil then error("readback kept the 3D scene shader") end
  copyDraws = copyDraws + 1
end
function love.graphics.newCanvas(w, h)
  canvasBuilds = canvasBuilds + 1
  local canvas = {}
  function canvas:newImageData() return pixels(w, h) end
  function canvas:release() self.released = true end
  return canvas
end
function love.graphics.newImage()
  return {
    setFilter = function() end,
    replacePixels = function() end,
    release = function() end,
  }
end

local V = { require = function() return {} end }
local TerrainAtlas = assert(loadfile("lib/TerrainAtlas.lua"))(V)
local base = {
  getDimensions = function() return 128, 48 end,
  replacePixels = function() end,
}
local map = {
  id = "ROUTE_1",
  renderer = { image = base, gbcAtlas = true, data = {} },
  tileset = {
    id = "OVERWORLD", image = "assets/generated/tilesets/overworld.png",
    tilesPerRow = 16,
    animatedTiles = {
      { tile = 0x14, kind = "hshift", offsets = { 0, 1 }, period = 20 },
    },
  },
}

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected "
          .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

eq(TerrainAtlas.prepared(map), false, "cold RED++ atlas started prepared")
eq(TerrainAtlas.prepare(map), true, "RED++ atlas preparation failed")
eq(TerrainAtlas.prepared(map), true, "prepared RED++ atlas was not retained")
eq(canvasBuilds, 1, "preparation did not use exactly one tiny readback")
eq(copyDraws, 1, "engine atlas was not copied exactly once")
eq(cpuBakes, 0, "successful readback still repeated the CPU palette bake")
eq(activeCanvas.name, "world", "readback did not restore the world target")
eq(activeShader.name, "scene shader", "readback did not restore the shader")
eq(blend, "alpha", "readback did not restore blend mode")
eq(alpha, "alphamultiply", "readback did not restore alpha mode")
eq(color[1], 0.25, "readback did not restore draw color")

TerrainAtlas.prepare(map)
TerrainAtlas.forMap(map, nil)
eq(canvasBuilds, 1, "prepared atlas performed another readback")
eq(cpuBakes, 0, "prepared atlas later entered CPU fallback")

love = previousLove
print("terrain atlas first-visit RED++ readback/preparation: ok")
