-- RED++ owns a private animated atlas per map. Terrain meshes retain one
-- previous neighbourhood for cheap door round-trips; the atlas cache must do
-- exactly the same or the retained mesh still pays a first-frame texture
-- rebuild when the player walks back outside.

local originalLove = love
local images = {}

local function imageData(w, h)
  local data = { w = w or 8, h = h or 8 }
  function data:getDimensions() return self.w, self.h end
  function data:getPixel() return 1, 1, 1, 1 end
  function data:setPixel() end
  function data:paste() end
  return data
end

local raw = imageData(8, 8)
love = {
  image = { newImageData = imageData },
  graphics = {},
  timer = { getTime = function() return 0 end },
}

function love.graphics.newImage(data)
  local image = { data = data, releases = 0, replacements = 0 }
  function image:setFilter() end
  function image:replacePixels()
    self.replacements = self.replacements + 1
  end
  function image:release()
    self.releases = self.releases + 1
  end
  images[#images + 1] = image
  return image
end

package.preload["src.render.Assets"] = function()
  return {
    imageData = function() return raw end,
    register = function() end,
  }
end

package.preload["src.render.TileRenderer"] = function()
  return {
    atlasImageData = function() return raw end,
    animFrame = function() return 0 end,
    defaultAnimatedTiles = function() return {} end,
  }
end

package.preload["src.render.PaletteFX"] = function()
  return {}
end

local V = { require = function() return {} end }
local TerrainAtlas = assert(loadfile("lib/TerrainAtlas.lua"))(V)

local tileset = {
  id = "OVERWORLD", image = "tiles.png", tilesPerRow = 1,
  animatedTiles = {
    { tile = 0, kind = "hshift", offsets = { 0 }, period = 20 },
  },
}

local function baseImage()
  return { replacePixels = function() end }
end

local function map(id)
  return {
    id = id,
    tileset = tileset,
    renderer = { image = baseImage(), gbcAtlas = true },
  }
end

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected "
          .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local a, b, c = map("A"), map("B"), map("C")

-- Runtime order: the live set changes during update, then the first render
-- asks for that map's animated texture.
TerrainAtlas.setLive({ A = true })
local atlasA = TerrainAtlas.forMap(a, nil)
eq(atlasA, images[1], "map A creates one private animated atlas")

TerrainAtlas.setLive({ B = true })
eq(atlasA.releases, 0,
   "the immediately previous neighbourhood survives a door warp")
eq(TerrainAtlas.forMap(a, nil), atlasA,
   "walking back can reuse the exact retained atlas object")

local atlasB = TerrainAtlas.forMap(b, nil)
TerrainAtlas.setLive({ C = true })
eq(atlasA.releases, 1,
   "a map older than one neighbourhood is evicted exactly once")
eq(atlasB.releases, 0,
   "the new immediately previous neighbourhood remains retained")

-- invalidate() must also clear prevLive. VoxelScene deliberately suppresses
-- redundant setLive calls while the map id is unchanged, so a texture may be
-- rebuilt after invalidation before another live-set change. A stale C id
-- must not exempt that new generation when D becomes live.
TerrainAtlas.invalidate()
eq(atlasB.releases, 1, "invalidation releases the retained B atlas")
local atlasC = TerrainAtlas.forMap(c, nil)
TerrainAtlas.setLive({ D = true })
eq(atlasC.releases, 1,
   "invalidation clears stale previous-live ids before the next eviction")

eq(atlasA.releases, 1, "an already-evicted atlas is never released twice")
love = originalLove
print("terrain atlas previous-live retention: ok")
