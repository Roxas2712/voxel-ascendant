-- Source-backed, map-instance NPC artwork catalog for Gen 1 and Gen 2.

local NpcCatalog = {}

NpcCatalog.SCHEMA = "ascendant.npc-catalog/v1"

local function split(line, separator)
  local result = {}
  for value in (line .. separator):gmatch("(.-)" .. separator) do
    result[#result + 1] = value
  end
  return result
end

local function loadRows(mod, generation)
  local relative = ("production/gen%d-map-npc-inventory.tsv"):format(generation)
  local body, err = mod:read(relative)
  if type(body) ~= "string" then return {}, {}, err end
  local rows, byLocation = {}, {}
  local first = true
  for line in body:gmatch("[^\r\n]+") do
    if first then
      first = false
    else
      local field = split(line, "\t")
      local assets = split(field[10] or "", "|")
      local row = {
        schema=NpcCatalog.SCHEMA,
        generation=tonumber((field[1] or ""):match("%d+")) or generation,
        map=field[2], line=tonumber(field[3]),
        x=tonumber(field[4]), y=tonumber(field[5]),
        sprite=field[6], role=field[7],
        visualAuthority=field[8], scriptOrText=field[9],
        assets=assets, status=field[11],
      }
      rows[#rows + 1] = row
      byLocation[(row.map or "") .. ":" .. tostring(row.line or "")] = row
    end
  end
  return rows, byLocation
end

function NpcCatalog.public(mod)
  local rows, indexes = {}, {}
  for _, generation in ipairs({ 1, 2 }) do
    rows[generation], indexes[generation] = loadRows(mod, generation)
  end

  local function inventory(generation)
    generation = tonumber(generation)
    if generation == 1 or generation == 2 then return rows[generation] end
    local combined = {}
    for _, current in ipairs({ 1, 2 }) do
      for _, row in ipairs(rows[current]) do combined[#combined + 1] = row end
    end
    return combined
  end

  local function lookup(generation, map, line)
    generation = tonumber(generation)
    local index = indexes[generation]
    if not index or type(map) ~= "string" then return nil end
    return index[map .. ":" .. tostring(tonumber(line) or line)]
  end

  local function assetPaths(generation, map, line)
    local row = lookup(generation, map, line)
    if not row then return nil end
    local absolute = {}
    for index, relative in ipairs(row.assets) do
      absolute[index] = mod.path .. "/" .. relative
    end
    return absolute, row.assets, row
  end

  return {
    schema=NpcCatalog.SCHEMA,
    generations={ 1, 2 },
    counts={ [1]=#rows[1], [2]=#rows[2] },
    inventory=inventory,
    lookup=lookup,
    assets=assetPaths,
  }
end

return NpcCatalog
