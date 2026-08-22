-- Export data/battle_arenas.lua as browser-safe JavaScript for the review UI.

local input = assert(arg[1], "battle arena data path required")
local output = assert(arg[2], "output JavaScript path required")
local mapsInput = arg[3]
local arenas = assert(dofile(input))

local maps = {}
for mapId in pairs(arenas) do maps[#maps + 1] = mapId end
table.sort(maps)

local function quoted(value)
  if value == nil then return "null" end
  return string.format("%q", tostring(value))
end

local rows = {}
for _, mapId in ipairs(maps) do
  local entry = assert(arenas[mapId])
  local spots = entry.spots or { entry }
  for index, spot in ipairs(spots) do
    rows[#rows + 1] = string.format(
      '{"id":%s,"map":%s,"index":%d,"x":%d,"y":%d,"shape":%s,"cam":%s,"stageMap":%s}',
      quoted(mapId .. "#" .. index), quoted(mapId), index,
      assert(spot.x), assert(spot.y), quoted(spot.shape),
      quoted(spot.cam or entry.cam), quoted(spot.map or entry.map or mapId)
    )
  end
end

assert(#maps == 95, "expected 95 maps")
assert(#rows == 111, "expected 111 anchors")

local file = assert(io.open(output, "wb"))
file:write("window.VASC_ARENA_ANCHORS = [\n  ")
file:write(table.concat(rows, ",\n  "))
file:write("\n];\n")

local coverageRows = {}
if mapsInput then
  local mapDefs = assert(dofile(mapsInput))
  local allMaps = {}
  for mapId in pairs(mapDefs) do allMaps[#allMaps + 1] = mapId end
  table.sort(allMaps)
  for _, mapId in ipairs(allMaps) do
    local def = assert(mapDefs[mapId])
    local trainerCount = 0
    for _, object in ipairs(def.objects or {}) do
      if object.trainerClass ~= nil then trainerCount = trainerCount + 1 end
    end
    local arena = arenas[mapId]
    local arenaCount = arena and #(arena.spots or { arena }) or 0
    coverageRows[#coverageRows + 1] = string.format(
      '{"map":%s,"tileset":%s,"trainers":%d,"warps":%d,"arenaCount":%d}',
      quoted(mapId), quoted(def.tileset), trainerCount,
      #(def.warps or {}), arenaCount
    )
  end
  file:write("window.VASC_MAP_COVERAGE = [\n  ")
  file:write(table.concat(coverageRows, ",\n  "))
  file:write("\n];\n")
end
assert(file:close())
print(string.format(
  "arena scenery catalog: %d anchored maps / %d anchors / %d total maps",
  #maps, #rows, #coverageRows
))
