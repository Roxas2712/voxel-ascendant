-- Visual base elevation implied by Gen 1's one-way ledges.
--
-- Gameplay already owns ledges.  `data.field.ledges` says that, for one
-- tileset, a player standing on S may press/facing `dir` when the next cell
-- L carries `ledgeTile`; the engine then hops over L and lands on T.  That
-- direction is also the missing visual fact: S is the high side, T the low
-- side, and the lip's authored six-pixel height is the difference.  L itself
-- keeps the LOW datum: TileShape already makes that artwork six pixels tall,
-- so its top meets S instead of being raised twice.
--
-- This module never changes collision, map data or a shared TileShape.  It
-- derives an immutable, cacheable CELL-height snapshot for gameplay-sized
-- consumers plus an 8px TILE-height snapshot for the renderer.  That second
-- view matters at the lip itself: a Gen 1 ledge collision cell is 16px deep,
-- but its authored six-pixel face occupies only one 8px half.  The other half
-- is plateau art and must keep the high datum, otherwise the mesh cuts an
-- eight-pixel trench immediately behind every otherwise-correct ledge.
--
-- A lip is a LOCAL contour, not permission to raise its whole map row or
-- column.  Same-direction occurrences on the same line are joined into one
-- run; a one- or two-cell walkable road opening may join neighbouring pieces
-- of that run because the upper and lower terrace continue across the road.
-- Nothing outside the run's tangential span is affected.  Perpendicular
-- signed sweeps then integrate those bounded contours: successive real runs
-- add courses, opposed runs bound a ridge/trench, and a short ledge cannot
-- manufacture a terrace elsewhere on the map.
--
-- A connected non-walkable scenery mass uses the lowest adjacent ground
-- datum.  That keeps one mountain/building internally level even when a
-- contour ends beside it, instead of turning its collision footprint into an
-- unauthored staircase.

local V = ...

local LedgeElevation = {}
local Budget = V.require("BuildBudget")

local FALLBACK_STEP = 6
local MAX_ROAD_GAP = 2
local DIR = {
  down = { 0, 1, "vertical" },
  up = { 0, -1, "vertical" },
  right = { 1, 0, "horizontal" },
  left = { -1, 0, "horizontal" },
}
local COMPASS = { up = "north", down = "south",
                  left = "west", right = "east" }

-- Map instances are the authority.  A weak key lets an unloaded map and its
-- immutable snapshot leave together; explicit invalidation handles hot map
-- edits and profile/mod reloads.
local cache = setmetatable({}, { __mode = "k" })

local function profileStep()
  if V and type(V.data) == "function" then
    local ok, profile = pcall(V.data, "voxel_heights")
    local h = ok and type(profile) == "table" and profile.heights
      and tonumber(profile.heights.ledge) or nil
    if h and h > 0 then return h end
  end
  return FALLBACK_STEP
end

local function gameData(explicit)
  if type(explicit) == "table" then return explicit end
  local ok, Game = pcall(require, "src.core.Game")
  return ok and type(Game) == "table" and Game.data or nil
end

local function dimensions(map)
  local w = tonumber(map and map.widthCells)
  local h = tonumber(map and map.heightCells)
  local def = map and map.def
  w = w or (def and tonumber(def.width) and tonumber(def.width) * 2)
  h = h or (def and tonumber(def.height) and tonumber(def.height) * 2)
  return math.max(0, math.floor(w or 0)),
         math.max(0, math.floor(h or 0))
end

local function inBounds(map, x, y, w, h)
  if map and type(map.inBounds) == "function" then
    return map:inBounds(x, y)
  end
  return x >= 0 and y >= 0 and x < w and y < h
end

local function tilesetId(map)
  return map and map.def and map.def.tileset
    or map and map.tileset and map.tileset.id
end

local function connectionAt(map, dir)
  local def = map and map.def
  return def and type(def.connections) == "table"
    and def.connections[COMPASS[dir] or dir] ~= nil
end

local NEIGHBOURS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

local function readonlySnapshot(width, height, step, values, tileValues,
                                ledgeCount)
  local function at(_, x, y)
    x, y = tonumber(x), tonumber(y)
    if not x or not y then return 0 end
    x, y = math.floor(x), math.floor(y)
    if x < 0 or y < 0 or x >= width or y >= height then return 0 end
    return values[y * width + x] or 0
  end
  local public = {
    width = width,
    height = height,
    tileWidth = width * 2,
    tileHeight = height * 2,
    step = step,
    ledgeCount = ledgeCount,
    at = at,
  }
  function public.atTile(_, tx, ty)
    tx, ty = tonumber(tx), tonumber(ty)
    if not tx or not ty then return 0 end
    tx, ty = math.floor(tx), math.floor(ty)
    if tx < 0 or ty < 0 or tx >= width * 2 or ty >= height * 2 then
      return 0
    end
    if tileValues then
      local hit = tileValues[ty * width * 2 + tx]
      if hit ~= nil then return hit end
    end
    return values[math.floor(ty / 2) * width + math.floor(tx / 2)] or 0
  end
  function public.atWorld(self, wx, wz)
    wx, wz = tonumber(wx), tonumber(wz)
    if not wx or not wz then return 0 end
    return self:atTile(math.floor(wx / 8), math.floor(wz / 8))
  end
  return setmetatable({}, {
    __index = public,
    __newindex = function()
      error("ledge elevation snapshots are immutable", 2)
    end,
    __metatable = "ledge-elevation-snapshot",
  })
end

local function build(map, data)
  Budget.check()
  local width, height = dimensions(map)
  local step = profileStep()
  if width == 0 or height == 0 or type(map.cellTile) ~= "function" then
    return readonlySnapshot(width, height, step, {}, nil, 0)
  end

  local rules = data and data.field and data.field.ledges or {}
  local mapTileset = tilesetId(map)
  local ledgeCount = 0
  local occurrences, occurrenceSeen = {}, {}
  local lipCells, lipGroups = {}, {}

  for y = 0, height - 1 do
    Budget.check()
    for x = 0, width - 1 do
      local standing = map:cellTile(x, y)
      for _, rule in ipairs(rules) do
        local name = type(rule) == "table" and rule.input or nil
        local d = DIR[name]
        -- Exactly the engine predicate: both facing and input must be the
        -- attempted direction.  A row without a tileset means OVERWORLD.
        if d and rule.facing == name
           and (rule.tileset or "OVERWORLD") == mapTileset
           and rule.standingTile == standing then
          local lx, ly = x + d[1], y + d[2]
          if inBounds(map, lx, ly, width, height)
             and map:cellTile(lx, ly) == rule.ledgeTile then
            local tx, ty = lx + d[1], ly + d[2]
            local landing = inBounds(map, tx, ty, width, height)
            if landing or connectionAt(map, name) then
              -- Geometry, not row index, is the event identity. A dataset
              -- accidentally repeating an identical rule must not add two
              -- floors to the same physical lip.
              local identity = table.concat({ x, y, lx, ly, name }, ":")
              if not occurrenceSeen[identity] then
                occurrenceSeen[identity] = true
                ledgeCount = ledgeCount + 1
                local occurrence = {
                  sx = x, sy = y, lx = lx, ly = ly, direction = name,
                  tx = tx, ty = ty, landing = landing,
                  ledgeTile = rule.ledgeTile,
                }
                occurrences[#occurrences + 1] = occurrence
                local lipKey = ly * width + lx
                lipCells[lipKey] = true
                lipGroups[lipKey] = lipGroups[lipKey] or {}
                lipGroups[lipKey][#lipGroups[lipKey] + 1] = occurrence
              end
            end
          end
        end
      end
    end
  end

  -- Authored lip cells are the cut itself, even in a custom map whose broad
  -- walkability predicate happens to include their collision tile.
  local walkableCache = {}
  local function walkable(x, y)
    if x < 0 or y < 0 or x >= width or y >= height then return false end
    local k = y * width + x
    local cached = walkableCache[k]
    if cached ~= nil then return cached end
    if lipCells[k] then
      walkableCache[k] = false
      return false
    end
    if type(map.isWalkableCell) == "function" then
      local ok, value = pcall(map.isWalkableCell, map, x, y)
      if ok then
        walkableCache[k] = value and true or false
        return walkableCache[k]
      end
    end
    -- Tiny fixtures and older compatible engines may not expose collision
    -- walkability. Treat every in-body non-lip cell as ordinary ground.
    walkableCache[k] = true
    return true
  end

  -- Return the standing/lip/landing triplet for any point along a contour.
  -- The point need not carry ledge art: a short walkable road gap synthesized
  -- between two authored pieces uses the same boundary coordinate.
  local function contourPosition(direction, normal, tangent)
    if direction == "down" then
      return tangent, normal - 1, tangent, normal, tangent, normal + 1
    elseif direction == "up" then
      return tangent, normal + 1, tangent, normal, tangent, normal - 1
    elseif direction == "right" then
      return normal - 1, tangent, normal, tangent, normal + 1, tangent
    elseif direction == "left" then
      return normal + 1, tangent, normal, tangent, normal - 1, tangent
    end
  end

  -- Bucket physical occurrences by direction and contour line.  A run owns
  -- only [first,last]; no later sweep may leak past those authored endpoints.
  local buckets = {}
  for _, occurrence in ipairs(occurrences) do
    Budget.tick()
    local vertical = occurrence.direction == "down"
                     or occurrence.direction == "up"
    occurrence.normal = vertical and occurrence.ly or occurrence.lx
    occurrence.tangent = vertical and occurrence.lx or occurrence.ly
    occurrence.axis = vertical and "vertical" or "horizontal"
    local key = occurrence.direction .. ":" .. tostring(occurrence.normal)
    local bucket = buckets[key]
    if not bucket then
      bucket = { direction = occurrence.direction,
                 normal = occurrence.normal, axis = occurrence.axis,
                 points = {} }
      buckets[key] = bucket
    end
    bucket.points[#bucket.points + 1] = occurrence
  end

  local function roadGapOpen(direction, normal, first, last)
    for tangent = first, last do
      local sx, sy, lx, ly, tx, ty =
        contourPosition(direction, normal, tangent)
      if not walkable(sx, sy) or not walkable(lx, ly) then return false end
      if inBounds(map, tx, ty, width, height) then
        if not walkable(tx, ty) then return false end
      elseif not connectionAt(map, direction) then
        return false
      end
    end
    return true
  end

  local contours = {}
  for _, bucket in pairs(buckets) do
    Budget.check()
    table.sort(bucket.points, function(a, b) return a.tangent < b.tangent end)
    local run
    for _, occurrence in ipairs(bucket.points) do
      local tangent = occurrence.tangent
      if run and tangent == run.last then
        run.actual[tangent] = run.actual[tangent] or occurrence
      else
        local gap = run and (tangent - run.last - 1) or math.huge
        local joins = run and gap >= 0 and gap <= MAX_ROAD_GAP
                       and roadGapOpen(bucket.direction, bucket.normal,
                                           run.last + 1, tangent - 1)
        if not joins then
          run = { direction = bucket.direction, normal = bucket.normal,
                  axis = bucket.axis, first = tangent, last = tangent,
                  actual = {} }
          contours[#contours + 1] = run
        else
          run.last = tangent
        end
        run.actual[tangent] = occurrence
      end
    end
  end

  -- Emit signed transitions.  DOWN/RIGHT cross from high to low while a
  -- north-to-south / west-to-east scan advances; UP/LEFT cross low to high.
  -- Events exist only inside a run's tangential span, including an accepted
  -- short road opening, so an unrelated column/row remains exactly flat.
  local verticalEvents, horizontalEvents, horizontalRanges = {}, {}, {}
  local function addEvent(store, scanline, position, delta)
    local line = store[scanline]
    if not line then line = {}; store[scanline] = line end
    line[position] = (line[position] or 0) + delta
  end
  for _, run in ipairs(contours) do
    Budget.check()
    for tangent = run.first, run.last do
      if run.axis == "vertical" then
        local position = run.direction == "down"
                         and run.normal or run.normal + 1
        addEvent(verticalEvents, tangent, position,
                 run.direction == "down" and -step or step)
      else
        local position = run.direction == "right"
                         and run.normal or run.normal + 1
        addEvent(horizontalEvents, tangent, position,
                 run.direction == "right" and -step or step)
        local range = horizontalRanges[tangent]
        if not range then
          range = { run.normal - 1, run.normal + 1 }
          horizontalRanges[tangent] = range
        else
          range[1] = math.min(range[1], run.normal - 1)
          range[2] = math.max(range[2], run.normal + 1)
        end
      end
    end
  end

  local verticalValues, horizontalValues = {}, {}
  for x = 0, width - 1 do
    Budget.check()
    local raw, minimum, scan = 0, 0, {}
    local events = verticalEvents[x] or {}
    for y = 0, height - 1 do
      raw = raw + (events[y] or 0)
      scan[y], minimum = raw, math.min(minimum, raw)
    end
    for y = 0, height - 1 do
      verticalValues[y * width + x] = scan[y] - minimum
    end
  end
  for y = 0, height - 1 do
    Budget.check()
    local raw, minimum, scan = 0, 0, {}
    local events = horizontalEvents[y] or {}
    for x = 0, width - 1 do
      raw = raw + (events[x] or 0)
      scan[x], minimum = raw, math.min(minimum, raw)
    end
    for x = 0, width - 1 do
      horizontalValues[y * width + x] = scan[x] - minimum
    end
  end

  -- Do not stop a side-authored profile one cell before the perpendicular
  -- profile catches up: that would merely move the unauthored wall from the
  -- lip to the corridor boundary (Route 4 x61 -> x62 exposed this). Extend
  -- only through the immediately adjacent disagreement and stop at the first
  -- reconvergence, so the correction remains local.
  for y, range in pairs(horizontalRanges) do
    Budget.check()
    local x = range[1] - 1
    while x >= 0 do
      local k = y * width + x
      if horizontalValues[k] == verticalValues[k] then break end
      range[1], x = x, x - 1
    end
    x = range[2] + 1
    while x < width do
      local k = y * width + x
      if horizontalValues[k] == verticalValues[k] then break end
      range[2], x = x, x + 1
    end
  end

  -- Side-facing runs are the authored closures of the north/south terrace
  -- bands on rows where they occur (Route 4's nested plaza is the canonical
  -- example). Their west/east profile is authoritative only inside the local
  -- corridor above: max composition would let a perpendicular run mask both
  -- sides of a true side drop and create a one-cell dip when the hard lip was
  -- restored. Cells outside that corridor use the north/south profile. This
  -- also counts an orthogonal corner once instead of adding a 12px tower.
  local values = {}
  for y = 0, height - 1 do
    Budget.check()
    local sideRange = horizontalRanges[y]
    for x = 0, width - 1 do
      local k = y * width + x
      local sideProfile = sideRange and x >= sideRange[1] and x <= sideRange[2]
      values[k] = sideProfile and (horizontalValues[k] or 0)
                  or (verticalValues[k] or 0)
    end
  end

  -- A connected mountain/building mass must never acquire a staircase merely
  -- because two nearest-ground waves meet inside it. Give the entire blocked
  -- region one conservative datum: the lowest adjacent proven component.
  -- An object wholly on one plateau still rides it; a wall between different
  -- levels stays on the lower side and supplies the vertical separation with
  -- its authored geometry.
  local blockedVisited, queue = {}, {}
  for y = 0, height - 1 do
    Budget.check()
    for x = 0, width - 1 do
      local start = y * width + x
      if not walkable(x, y) and not lipCells[start]
         and not blockedVisited[start] then
        local region, regionBase = {}, nil
        local head = 1
        queue = { { x, y } }
        blockedVisited[start] = true
        while head <= #queue do
          Budget.tick()
          local here = queue[head]
          head = head + 1
          local hk = here[2] * width + here[1]
          region[#region + 1] = hk
          for _, offset in ipairs(NEIGHBOURS) do
            local nx, ny = here[1] + offset[1], here[2] + offset[2]
            if nx >= 0 and ny >= 0 and nx < width and ny < height then
              local nk = ny * width + nx
              if walkable(nx, ny) then
                local base = values[nk] or 0
                regionBase = regionBase == nil and base
                             or math.min(regionBase, base)
              elseif not lipCells[nk] and not blockedVisited[nk]
                     and not walkable(nx, ny) then
                blockedVisited[nk] = true
                queue[#queue + 1] = { nx, ny }
              end
            end
          end
        end
        regionBase = regionBase or 0
        for _, k in ipairs(region) do values[k] = regionBase end
      end
    end
  end

  -- The local axis merge can still meet a lip at a mixed-axis endpoint. A
  -- physical lip is always exactly one course below its own standing side;
  -- its high 8px half is restored separately below.
  -- Resolve in map order and repeat to a fixed point. A landing can itself be
  -- the standing cell of the next stacked ledge; computing every target from
  -- the pre-correction snapshot would recognize only the first drop. Direct
  -- fixed-point propagation makes the second and third courses see the datum
  -- established immediately above them.
  for _ = 1, #occurrences + 1 do
    Budget.check()
    local changed = false
    for _, occurrence in ipairs(occurrences) do
      Budget.tick()
      local top = values[occurrence.sy * width + occurrence.sx] or step
      local target = math.max(0, top - step)
      local lipKey = occurrence.ly * width + occurrence.lx
      if values[lipKey] ~= target then
        values[lipKey], changed = target, true
      end
      -- Gen 1's maps occasionally use a side ledge inside a region whose
      -- perpendicular contour count would otherwise mask the drop. The
      -- actual landing is the strongest local evidence, but a deliberately
      -- two-way custom ridge is contradictory: each high side is also the
      -- other's nominal landing, so only its shared lip may be lowered.
      if occurrence.landing and #(lipGroups[lipKey] or {}) == 1 then
        local landingKey = occurrence.ty * width + occurrence.tx
        if values[landingKey] ~= target then
          values[landingKey], changed = target, true
        end
      end
    end
    if not changed then break end
  end

  -- The bounded contour potential above intentionally remains cell-sized: it is the datum
  -- entities, battles and collision-facing callers understand.  Terrain is
  -- built from 8px atlas tiles, though, and a lip collision cell contains
  -- both the lip and (on its high side) half a cell of ordinary plateau.
  -- Give only those atlas tiles their exact basis.  Intrinsic ledge artwork
  -- remains one course below the desired top so its own six-pixel TileShape
  -- reaches the plateau; ordinary high-side art gets the plateau basis
  -- directly.  No tile can therefore become the old 12px double-lip.
  local tileValues = {}
  local ledgeTiles = {}
  for _, rule in ipairs(rules) do
    Budget.tick()
    if type(rule) == "table" and rule.ledgeTile ~= nil then
      ledgeTiles[rule.ledgeTile] = true
    end
  end
  if V and type(V.data) == "function" then
    local ok, profile = pcall(V.data, "voxel_heights")
    local pins = ok and type(profile) == "table" and profile.tilesets
      and profile.tilesets[mapTileset]
    for _, tile in ipairs(pins and pins.ledge or {}) do ledgeTiles[tile] = true end
  end

  local tileWidth = width * 2
  local function setTileBase(tx, ty, base)
    if tx < 0 or ty < 0 or tx >= tileWidth or ty >= height * 2 then return end
    local k = ty * tileWidth + tx
    tileValues[k] = math.max(tileValues[k] or -math.huge, base)
  end
  local function tileAt(tx, ty)
    if type(map.tileAt) ~= "function" then return nil end
    local ok, tile = pcall(map.tileAt, map, tx, ty)
    return ok and tile or nil
  end
  local function isHighHalf(direction, ox, oy)
    if direction == "down" then return oy == 0 end
    if direction == "up" then return oy == 1 end
    if direction == "left" then return ox == 1 end
    if direction == "right" then return ox == 0 end
    return false
  end
  local function isFallbackLipHalf(direction, ox, oy)
    -- All current engine ledges store their collision tile in the atlas
    -- half indicated below.  This fallback keeps isolated unit fixtures and
    -- custom maps without tileAt deterministic; real maps use their profile
    -- pins above, including decorative continuation tiles.
    if direction == "down" then return oy == 1 end
    if direction == "up" then return oy == 0 end
    return ox == 0 -- both left/right ledges use the cell's west atlas half
  end

  for _, lip in ipairs(occurrences) do
    Budget.tick()
    local low = values[lip.ly * width + lip.lx] or 0
    local standing = values[lip.sy * width + lip.sx]
    -- S is the authored top the player jumps FROM, so it is the exact visual
    -- target. At an orthogonal corner max-composition can raise L's cell datum
    -- to S's level; using `low + step` there would put the intrinsic lip one
    -- course ABOVE S (the 12px corner spike). A tile override is allowed to be
    -- lower than its cell datum precisely so that the lip remains S-step while
    -- the other half of that same cell follows the crossing terrace.
    local top = standing ~= nil and standing or (low + step)
    for oy = 0, 1 do
      for ox = 0, 1 do
        local tx, ty = lip.lx * 2 + ox, lip.ly * 2 + oy
        local tile = tileAt(tx, ty)
        local intrinsic = tile ~= nil and ledgeTiles[tile]
                          or (tile == nil
                              and isFallbackLipHalf(lip.direction, ox, oy))
        if intrinsic then
          setTileBase(tx, ty, top - step)
        elseif isHighHalf(lip.direction, ox, oy) then
          setTileBase(tx, ty, top)
        end
      end
    end
  end

  -- A short road opening accepted into a contour has no intrinsic ledge tile,
  -- but it still needs the same half-cell closure: otherwise its collision
  -- cell would cut a conspicuous 8px groove through two level terrace bands.
  -- Only the high half is overridden; the ordinary low half keeps the swept
  -- cell datum and ChunkMesher supplies the exposed six-pixel side.
  for _, run in ipairs(contours) do
    Budget.check()
    for tangent = run.first, run.last do
      if not run.actual[tangent] then
        local sx, sy, lx, ly =
          contourPosition(run.direction, run.normal, tangent)
        local top = values[sy * width + sx] or 0
        local low = values[ly * width + lx] or 0
        if top > low then
          for oy = 0, 1 do
            for ox = 0, 1 do
              if isHighHalf(run.direction, ox, oy) then
                setTileBase(lx * 2 + ox, ly * 2 + oy, top)
              end
            end
          end
        end
      end
    end
  end

  return readonlySnapshot(width, height, step, values, tileValues, ledgeCount)
end

-- Immutable cached snapshot for a map. Passing a different data authority
-- rebuilds automatically; mutating the same map/data deliberately requires
-- invalidate(), so a half-edited map can never change underneath a mesh job.
function LedgeElevation.map(map, explicitData)
  if type(map) ~= "table" then
    return readonlySnapshot(0, 0, profileStep(), {}, nil, 0)
  end
  local data = gameData(explicitData)
  local entry = cache[map]
  if entry and entry.data == data then return entry.snapshot end
  local snapshot = build(map, data)
  cache[map] = { data = data, snapshot = snapshot }
  return snapshot
end

function LedgeElevation.basisAtCell(map, cellX, cellY, explicitData)
  return LedgeElevation.map(map, explicitData):at(cellX, cellY)
end

function LedgeElevation.invalidate(map)
  if map ~= nil then
    local had = cache[map] ~= nil
    cache[map] = nil
    return had
  end
  cache = setmetatable({}, { __mode = "k" })
  return true
end

LedgeElevation.FALLBACK_STEP = FALLBACK_STEP

return LedgeElevation
