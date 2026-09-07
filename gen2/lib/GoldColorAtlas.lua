-- Gold/Silver GBC-color atlas adapter for the voxel renderer.
--
-- Gen2Recomp stores Gold's generated tileset art as the original four GB
-- shades. The native 2D world supplies color later, per 8x8 tile, from that
-- tileset's PalMap (`tilePalettes`) and the current map/time-of-day palette
-- set. Voxel terrain cannot use the native per-quad shader after the map has
-- become 3D geometry, so this module performs the same shade substitution once
-- into a private atlas and gives that colored atlas to TerrainAtlas.
--
-- Deliberately Gen-2 only. It does not touch GbcPalette.mode and therefore
-- respects the player's COLOR option: GBC stays color, DMG stays grayscale,
-- and CLASSIC keeps the DMG staging texture which the engine's final classic
-- presentation pass turns green.

local Assets = require("src.render.Assets")
local GbcPalette = require("src.render.GbcPalette")
local Palettes = require("src.world.gen2.Palettes")

local GoldColorAtlas = {}

local cache = {}
local dataCache = {}
local mapByKey = {}
local lastError = nil

local function release(value)
  if value and value ~= false and type(value.release) == "function" then
    pcall(value.release, value)
  end
end

local function hourFor(world)
  if world and type(world.hour) == "function" then
    local ok, value = pcall(world.hour, world)
    value = ok and tonumber(value) or nil
    if value then return math.floor(value) % 24 end
  end
  local value = tonumber(world and world.clockHour)
  if value then return math.floor(value) % 24 end
  return nil -- Palettes.daytimeFor falls back to the host RTC.
end

local function flashUsedFor(world)
  if type(world) ~= "table" then return false end
  for _, key in ipairs({ "flashUsed", "usedFlash", "flashActive" }) do
    local value = world[key]
    if type(value) == "boolean" then return value end
  end
  -- Keep this conservative. A missing flash flag means a PALETTE_DARK map
  -- remains dark rather than being incorrectly lit.
  return false
end

local function paletteSetFor(world, map)
  local game = world and world.game
  local data = game and game.data and game.data.gen2Palettes
  if not data then
    return nil, nil, "Gold palette data is unavailable"
  end
  local daytime = Palettes.daytimeFor(map and map.def, hourFor(world), flashUsedFor(world))
  local set = Palettes.bgSet(data, map and map.def, daytime)
  if not set then
    return nil, daytime, "Gold map palette set could not be resolved"
  end
  return set, daytime
end

local function modeName()
  return tostring(GbcPalette.mode or "gbc")
end

local function shadeIndex(r)
  -- Exact companion of src/render/GbcPalette.lua's shader math. Generated 2bpp
  -- source pixels are 1, 2/3, 1/3, 0, so this lands on 1..4 with headroom.
  local shade = math.floor((1 - (tonumber(r) or 0)) * 3 + 0.5)
  if shade < 0 then shade = 0 elseif shade > 3 then shade = 3 end
  return shade + 1
end

local function tilePaletteIndex(tilePalettes, tile)
  local slot = tilePalettes and tilePalettes[tile + 1]
  slot = tonumber(slot)
  if not slot then return 1 end
  -- Gold's generated PalMap is 1-based in Lua. Be tolerant of a modded table
  -- that carried the original 0..7 bytes instead.
  if slot >= 1 and slot <= 8 then return math.floor(slot) end
  if slot >= 0 and slot <= 7 then return math.floor(slot) + 1 end
  return 1
end

local function resolvedPalette(set, slot)
  local colors = set and (set[slot] or set[1])
  if not colors then return nil end
  if type(GbcPalette.resolve) == "function" then
    local ok, resolved = pcall(GbcPalette.resolve, colors)
    if ok and resolved then return resolved end
  end
  return colors
end

-- Exported for the headless regression probe.
function GoldColorAtlas.recolorImageData(src, tilePalettes, paletteSet, newImageData)
  if not (src and src.getDimensions and src.getPixel and paletteSet) then
    return nil, "invalid recolor inputs"
  end
  newImageData = newImageData or (love and love.image and love.image.newImageData)
  if type(newImageData) ~= "function" then return nil, "ImageData creation unavailable" end

  local w, h = src:getDimensions()
  local out = newImageData(w, h)
  local perRow = math.max(1, math.floor(w / 8))
  local palettes = {}

  for y = 0, h - 1 do
    local tileY = math.floor(y / 8)
    for x = 0, w - 1 do
      local tile = tileY * perRow + math.floor(x / 8)
      local slot = tilePaletteIndex(tilePalettes, tile)
      local colors = palettes[slot]
      if colors == nil then
        colors = resolvedPalette(paletteSet, slot) or false
        palettes[slot] = colors
      end

      local r, g, b, a = src:getPixel(x, y)
      if colors and (a == nil or a > 0) then
        local c = colors[shadeIndex(r)]
        if c then
          r, g, b = (c[1] or 0) / 255, (c[2] or 0) / 255, (c[3] or 0) / 255
        end
      end
      out:setPixel(x, y, r, g, b, a)
    end
  end
  return out
end

local function atlasPath(tileset)
  return tileset and (tileset.image or tileset.path)
end

local function cacheKey(map, tileset, daytime, flashUsed)
  return table.concat({
    tostring(atlasPath(tileset) or tileset and tileset.id or "?"),
    tostring(map and map.id or "?"),
    tostring(daytime or "DAY"),
    modeName(),
    flashUsed and "flash" or "dark",
  }, "#")
end

function GoldColorAtlas.forMap(world, map, rawAtlas)
  lastError = nil
  if not (world and map and map.tileset) then
    lastError = "Gold world/map/tileset is not ready"
    return rawAtlas, nil, false, lastError
  end
  if map.tileset.trueColor then return rawAtlas, nil, false end
  if not (love and love.image and love.image.newImageData
      and love.graphics and love.graphics.newImage) then
    lastError = "LOVE pixel/image APIs are unavailable"
    return rawAtlas, nil, false, lastError
  end

  local set, daytime, palErr = paletteSetFor(world, map)
  if not set then
    lastError = palErr
    return rawAtlas, nil, false, lastError
  end

  local key = cacheKey(map, map.tileset, daytime, flashUsedFor(world))
  mapByKey[key] = tostring(map.id or map.def and map.def.id or "?")
  if cache[key] ~= nil then
    if cache[key] then return cache[key], dataCache[key], true, nil, key end
    return rawAtlas, nil, false, lastError, key
  end

  local path = atlasPath(map.tileset)
  if not path then
    lastError = "Gold tileset has no source image path"
    cache[key] = false
    return rawAtlas, nil, false, lastError, key
  end

  local ok, image, pixels = pcall(function()
    local src = Assets.imageData(path)
    local out, err = GoldColorAtlas.recolorImageData(
      src, map.tileset.tilePalettes, set, love.image.newImageData)
    if not out then error(err or "Gold atlas recolor failed") end
    local img = love.graphics.newImage(out)
    if img and type(img.setFilter) == "function" then img:setFilter("nearest", "nearest") end
    return img, out
  end)

  if not ok or not image then
    lastError = tostring(ok and "Gold atlas image creation failed" or image)
    cache[key] = false
    dataCache[key] = false
    return rawAtlas, nil, false, lastError, key
  end

  cache[key] = image
  dataCache[key] = pixels
  return image, pixels, true, nil, key
end

function GoldColorAtlas.lastError()
  return lastError
end

-- Per-map GBC atlases are large GPU images plus ImageData. Keep only maps in
-- the renderer's current residency radius; a later visit rebuilds the exact
-- palette/time key and reattaches the fresh image to that Map renderer.
function GoldColorAtlas.setLive(live)
  live = type(live) == "table" and live or {}
  for key, mapId in pairs(mapByKey) do
    if not live[mapId] then
      release(cache[key])
      release(dataCache[key])
      cache[key] = nil
      dataCache[key] = nil
      mapByKey[key] = nil
    end
  end
end

function GoldColorAtlas.invalidate()
  for _, image in pairs(cache) do release(image) end
  for _, data in pairs(dataCache) do release(data) end
  cache = {}
  dataCache = {}
  mapByKey = {}
  lastError = nil
end

if type(Assets.register) == "function" then Assets.register(GoldColorAtlas.invalidate) end

return GoldColorAtlas
