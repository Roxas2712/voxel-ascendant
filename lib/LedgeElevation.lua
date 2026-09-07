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
-- Non-walkable scenery follows the selected interpretation. LOCAL keeps one
-- connected mass at its lowest adjacent ground datum. WORLD instead assigns
-- each blocked cell to its nearest walkable surface, so rocks/bollards beside
-- a terrace rise with that terrace while the same frame can return to the
-- lower datum beyond its stair opening. Equal-distance ties prefer the higher
-- surface, keeping the visible plateau rim closed without lifting unrelated
-- roads.
--
-- SLICE is the deliberately safer middle ground: it accepts only contours
-- that contain a real one- or two-cell walkable opening between authored ledge
-- pieces. Those openings are the map's visual evidence for stairs. The local
-- plateau and its retaining scenery are raised, but no datum crosses a map
-- connection and an isolated jump ledge cannot lift a town or pond.

local V = ...

local LedgeElevation = {}
local Budget = V.require("BuildBudget")
local ModSetting = V.require("ModSetting")

-- WORLD is the continuous-terrain reading: an
-- authored ledge establishes a bounded terrace, carries its course through a
-- seamless map connection and lets flanking rocks/bollards inherit the level
-- of the nearest ground. The terrace ends again beyond that physical frame,
-- so an unrelated road cannot acquire invisible stairs. LOCAL preserves the
-- historical conservative object treatment. FLAT is the safe default: it
-- removes both the derived terrace datum and the intrinsic ledge lift, so a
-- hedge break that happens to reuse Gen-I ledge collision art cannot cut a
-- six-pixel niche into otherwise level ground. Real stairs and structures
-- retain their own geometry.
--
-- Compact labels are deliberate. KASC's public guided-list renderer and the
-- native VASC copy both use the original eight-glyph value rail.
LedgeElevation.setting = ModSetting.new(
  "terrainHeights", "HEIGHTS",
  { "world", "local", "flat" },
  { "WORLD", "LOCAL", "FLAT" },
  "flat")
-- Older hosts and focused fixtures expose the public setting contract without
-- the optional migration helper. SLICE still resolves to LOCAL where the
-- helper exists, while legacy hosts keep loading instead of crashing here.
if type(LedgeElevation.setting.aliasLegacy) == "function" then
  LedgeElevation.setting:aliasLegacy("slice", "local")
end

local FALLBACK_STEP = 6
local MAX_ROAD_GAP = 2
-- A SLICE fallback may close one short, physically framed terrace band when
-- the walkable upper component continues through an unrelated rear road.
-- Keeping the search under half a Gen 1 screen prevents a ledge from turning
-- into a map-wide datum while still covering Route 1's five-cell garden.
local MAX_SLICE_DEPTH = 8
-- A rear gate in an otherwise blocked retaining row can carry the plateau
-- back to ordinary ground without placing a collision-blind wall through a
-- walkable road. Route 1's real gate is four cells wide; anything broader is
-- an open landscape, not a locally framed slice.
local MAX_SLICE_PASSAGE = 4

-- Audited outdoor bodies without an authored stair transition stay on one
-- local plane in WORLD. They may still receive a non-zero global map datum
-- from a connected route; only invented within-town terraces are suppressed.
-- Viridian is the guard case: its one-way ledge art is gameplay collision,
-- not evidence that the pond, houses and streets occupy separate storeys.
local WORLD_LEVEL_MAPS = {
  VIRIDIAN_CITY = true,
  -- Celadon has no traversable internal storey transition. Its decorative
  -- hedge/one-way ledge motifs were being integrated into a six-pixel basin;
  -- wandering trainers then inherited the low walkable cells and vanished
  -- behind the surrounding terrain. Keep the complete city body on its one
  -- authored course in LOCAL and WORLD, just like audited Viridian.
  CELADON_CITY = true,
}

-- LOCAL deliberately does not propagate a datum through arbitrary map
-- seams. A town whose entire body is the continuation of a visibly raised
-- route still needs one stable local course, though, otherwise its first
-- frame drops like an elevator at the border. Viridian is the audited Gen-1
-- case: raise the whole town by the one Route-1 course instead of inventing
-- internal terraces or changing collision.
local LOCAL_CITY_COURSES = {
  VIRIDIAN_CITY = 1,
}
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

-- WORLD placement is learned incrementally from the exact maps the engine
-- has loaded. The current map anchors its seamless component at zero; each
-- connected neighbour receives the offset that makes both edge terraces meet.
-- Re-rooting later may move the whole component relative to the camera, but
-- never changes the visible difference between the maps. Warps are omitted on
-- purpose: a forest, gate, cave or building is allowed to reset the datum.
local worldMaps = setmetatable({}, { __mode = "v" })
local worldLocal = setmetatable({}, { __mode = "v" })
local worldBase = {}

local testMode
local function mode()
  if testMode then return testMode end
  -- Unit/compatibility fixtures load this module without a live mod handle.
  -- Keep their long-standing bounded geometry unless they explicitly select a
  -- mode through _setModeForTests; production always supplies V.mod.
  if not (V and V.mod) then return "local" end
  local ok, value = pcall(LedgeElevation.setting.get,
                          LedgeElevation.setting)
  if value == "world" or value == "local" or value == "flat" then
    return value
  end
  -- Focused compatibility fixtures historically supply a boolean ModSetting
  -- stub. Keep those probes on the pre-RC LOCAL contract instead of silently
  -- changing their geometry.
  return "local"
end

function LedgeElevation.mode()
  return mode()
end

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
                                ledgeCount, rampTiles, terrainMode)
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
    terrainMode = terrainMode,
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
  -- A synthesized walkable opening between two pieces of one ledge contour is
  -- the authored stair/ramp into that plateau. Only its high 8px half slopes;
  -- the cell centre remains on the low datum used by gameplay and entities.
  -- Return scalars instead of the backing record so the snapshot stays truly
  -- immutable to callers.
  function public.rampAtTile(_, tx, ty)
    tx, ty = tonumber(tx), tonumber(ty)
    if not tx or not ty then return nil end
    tx, ty = math.floor(tx), math.floor(ty)
    if tx < 0 or ty < 0 or tx >= width * 2 or ty >= height * 2 then
      return nil
    end
    local ramp = rampTiles and rampTiles[ty * width * 2 + tx]
    if type(ramp) ~= "table" then return nil end
    return ramp[1], ramp[2], ramp[3]
  end
  return setmetatable({}, {
    __index = public,
    __newindex = function()
      error("ledge elevation snapshots are immutable", 2)
    end,
    __metatable = "ledge-elevation-snapshot",
  })
end

local function build(map, data, buildMode)
  Budget.check()
  local width, height = dimensions(map)
  local step = profileStep()
  if width == 0 or height == 0 or type(map.cellTile) ~= "function" then
    return readonlySnapshot(width, height, step, {}, nil, 0, nil, buildMode)
  end
  if buildMode == "flat" then
    return readonlySnapshot(width, height, step, {}, nil, 0, nil, buildMode)
  end
  if (buildMode == "world" or buildMode == "local")
     and WORLD_LEVEL_MAPS[map.id] then
    return readonlySnapshot(width, height, step, {}, nil, 0, nil, buildMode)
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

  -- Water is deliberately kept separate from other blocked scenery. A pond
  -- is one visual plane, not a retaining wall whose cells should inherit the
  -- nearest bank height. Mixing both kinds in WORLD caused Viridian's pond to
  -- fold into several terraces and added needless propagation work.
  local waterCache = {}
  local function water(x, y)
    if x < 0 or y < 0 or x >= width or y >= height then return false end
    local k = y * width + x
    local cached = waterCache[k]
    if cached ~= nil then return cached end
    if type(map.isWaterCell) == "function" then
      local ok, value = pcall(map.isWaterCell, map, x, y)
      if ok then
        waterCache[k] = value and true or false
        return waterCache[k]
      end
    end
    waterCache[k] = false
    return false
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
          if gap > 0 then run.hasRamp = true end
          run.last = tangent
        end
        run.actual[tangent] = occurrence
      end
    end
  end

  -- SLICE is not a filtered LOCAL/WORLD sweep. It proves one local upper
  -- walkable component behind a physical front and raises exactly that
  -- component. A fully enclosed component is the strongest proof. A repeated
  -- jump-ledge front may additionally prove one short framed terrace band;
  -- unlike a stair mouth, its ordinary walkable breaks remain vertical.
  -- Neither path accepts water, a map edge/connection, an unframed town road
  -- or a Cycling-Road-style rail.
  local sliceRegions
  if buildMode == "slice" then
    local acceptedContours, acceptedOccurrences = {}, {}
    local acceptedSeen, acceptedLipCells, acceptedLipGroups = {}, {}, {}
    sliceRegions = {}

    local function barrierFor(run)
      local barrier = {}
      for tangent = run.first, run.last do
        local _, _, lx, ly =
          contourPosition(run.direction, run.normal, tangent)
        barrier[ly * width + lx] = true
      end
      return barrier
    end

    local function frameOffsets(direction)
      if direction == "down" then
        return { 0, -1 }, { -1, 0 }, { 1, 0 }
      elseif direction == "up" then
        return { 0, 1 }, { 1, 0 }, { -1, 0 }
      elseif direction == "right" then
        return { -1, 0 }, { 0, -1 }, { 0, 1 }
      end
      return { 1, 0 }, { 0, 1 }, { 0, -1 }
    end

    local function gapProfile(run)
      local gaps, groups, inGap = {}, 0, false
      for tangent = run.first, run.last do
        if not run.actual[tangent] then
          gaps[#gaps + 1] = tangent
          if not inGap then groups, inGap = groups + 1, true end
        else
          inGap = false
        end
      end
      return gaps, groups
    end

    local function enclosedRegion(run)
      -- Collision is the authority for an actually traversable component.
      -- A reduced compatibility map without it cannot prove a slice safely.
      if type(map.isWalkableCell) ~= "function" then return nil end

      local gaps, groups = gapProfile(run)
      if groups ~= 1 or #gaps < 1 or #gaps > MAX_ROAD_GAP then return nil end
      local stairOpening = true

      local barrier = barrierFor(run)
      local region, regionSet, queue, lowSide = {}, {}, {}, {}
      for _, tangent in ipairs(gaps) do
        local sx, sy, _, _, tx, ty =
          contourPosition(run.direction, run.normal, tangent)
        if not walkable(sx, sy) or water(sx, sy)
           or not inBounds(map, tx, ty, width, height)
           or not walkable(tx, ty) or water(tx, ty) then
          return nil
        end
        lowSide[ty * width + tx] = true
      end
      for _, occurrence in pairs(run.actual) do
        if not walkable(occurrence.sx, occurrence.sy)
           or water(occurrence.sx, occurrence.sy) then return nil end
        if #queue == 0 then
          local key = occurrence.sy * width + occurrence.sx
          regionSet[key] = true
          queue[1] = { occurrence.sx, occurrence.sy }
        end
        if occurrence.landing then
          lowSide[occurrence.ty * width + occurrence.tx] = true
        end
      end
      if #queue == 0 then return nil end

      local head, touchesEdge, touchesWater = 1, false, false
      while head <= #queue do
        Budget.tick()
        local here = queue[head]
        head = head + 1
        local x, y = here[1], here[2]
        local key = y * width + x
        region[#region + 1] = key
        if x == 0 or y == 0 or x == width - 1 or y == height - 1 then
          touchesEdge = true
        end
        for _, offset in ipairs(NEIGHBOURS) do
          local nx, ny = x + offset[1], y + offset[2]
          if nx < 0 or ny < 0 or nx >= width or ny >= height then
            touchesEdge = true
          else
            local nk = ny * width + nx
            if water(nx, ny) then
              touchesWater = true
            elseif not barrier[nk] and walkable(nx, ny)
                   and not regionSet[nk] then
              regionSet[nk] = true
              queue[#queue + 1] = { nx, ny }
            end
          end
        end
      end
      if touchesEdge or touchesWater or #region == 0 then return nil end
      for key in pairs(lowSide) do
        if regionSet[key] then return nil end
      end

      -- Every authored standing cell must belong to the same upper component;
      -- otherwise the visual line is a decorative mix rather than one plateau.
      for _, occurrence in pairs(run.actual) do
        if not regionSet[occurrence.sy * width + occurrence.sx] then return nil end
      end

      -- The upper component must have a real retaining object behind it and
      -- on both flanks. Ledge cells and water cannot stand in for that frame.
      local back, flankA, flankB = frameOffsets(run.direction)
      local sides = { false, false, false }
      local offsets = { back, flankA, flankB }
      for _, key in ipairs(region) do
        local x, y = key % width, math.floor(key / width)
        for index, offset in ipairs(offsets) do
          local nx, ny = x + offset[1], y + offset[2]
          if nx >= 0 and ny >= 0 and nx < width and ny < height then
            local nk = ny * width + nx
            if not barrier[nk] and not lipCells[nk]
               and not water(nx, ny) and not walkable(nx, ny) then
              sides[index] = true
            end
          end
        end
      end
      if not (sides[1] and sides[2] and sides[3]) then return nil end
      local frame = {}
      for _, key in ipairs(region) do
        local x, y = key % width, math.floor(key / width)
        for _, offset in ipairs(NEIGHBOURS) do
          local nx, ny = x + offset[1], y + offset[2]
          if nx >= 0 and ny >= 0 and nx < width and ny < height then
            local nk = ny * width + nx
            if not barrier[nk] and not lipCells[nk] and not water(nx, ny)
               and not walkable(nx, ny) then
              frame[nk] = true
            end
          end
        end
      end
      return region, regionSet, frame, stairOpening
    end

    -- Route 1's repeated jump fronts are physically framed on both sides and
    -- have a nearby rear retaining row, but the upper road remains connected
    -- through that rear row. A raw flood therefore reaches the map seam even
    -- though the visible garden itself is one local slice. Prove that special
    -- geometry without map IDs: a dense authored front, uninterrupted blocked
    -- side rails, and a rear barrier shared by at least two thirds of the
    -- front. The nearest such barrier fixes one short common depth. One short,
    -- fully framed walkable gate in that rear row becomes a real broad grade
    -- transition; it must never become a wall the player can walk through.
    local function boundedBandRegion(run)
      if type(map.isWalkableCell) ~= "function" then return nil end
      local span = run.last - run.first + 1
      if span < 2 then return nil end
      local _, gapGroups = gapProfile(run)
      if gapGroups < 2 then return nil end
      local actualCount = 0
      for _ in pairs(run.actual) do actualCount = actualCount + 1 end
      if actualCount < 2 or actualCount * 2 < span then return nil end

      local highDX, highDY
      if run.direction == "down" then highDX, highDY = 0, -1
      elseif run.direction == "up" then highDX, highDY = 0, 1
      elseif run.direction == "right" then highDX, highDY = -1, 0
      else highDX, highDY = 1, 0 end

      local rearCounts = {}
      for tangent = run.first, run.last do
        Budget.tick()
        local sx, sy = contourPosition(run.direction, run.normal, tangent)
        for distance = 1, MAX_SLICE_DEPTH do
          local x, y = sx + highDX * distance, sy + highDY * distance
          if not inBounds(map, x, y, width, height) or water(x, y) then break end
          if not walkable(x, y) then
            rearCounts[distance] = (rearCounts[distance] or 0) + 1
            break
          end
        end
      end
      local required = math.max(2, math.ceil(span * 2 / 3))
      local depth
      for distance = 1, MAX_SLICE_DEPTH do
        if (rearCounts[distance] or 0) >= required then
          depth = distance
          break
        end
      end
      if not depth then return nil end

      local region, regionSet, frame, rearOpenings = {}, {}, {}, {}
      for tangent = run.first, run.last do
        Budget.tick()
        local sx, sy, lx, ly, tx, ty =
          contourPosition(run.direction, run.normal, tangent)
        if not inBounds(map, tx, ty, width, height)
           or not walkable(tx, ty) or water(tx, ty)
           or water(lx, ly) then return nil end
        for offset = 0, depth - 1 do
          local x, y = sx + highDX * offset, sy + highDY * offset
          if not inBounds(map, x, y, width, height)
             or not walkable(x, y) or water(x, y) then return nil end
          local key = y * width + x
          if not regionSet[key] then
            regionSet[key] = true
            region[#region + 1] = key
          end
        end
        local rearX, rearY = sx + highDX * depth, sy + highDY * depth
        if not inBounds(map, rearX, rearY, width, height)
           or water(rearX, rearY) then return nil end
        if not walkable(rearX, rearY) then
          frame[rearY * width + rearX] = true
        else
          rearOpenings[#rearOpenings + 1] = {
            x = rearX, y = rearY, tangent = tangent,
          }
        end
      end

      -- A walkable breach in the rear retaining row must be one short,
      -- contiguous gate with solid jambs and ordinary ground beyond it. This
      -- is distinct from the jump gaps in the authored front: only this proven
      -- rear passage receives a slope, so an open road or scattered holes
      -- reject the whole candidate rather than creating invisible walls.
      local transitions = {}
      if #rearOpenings > 0 then
        if #rearOpenings > MAX_SLICE_PASSAGE then return nil end
        for index = 2, #rearOpenings do
          if rearOpenings[index].tangent
             ~= rearOpenings[index - 1].tangent + 1 then return nil end
        end
        local firstTangent = rearOpenings[1].tangent
        local lastTangent = rearOpenings[#rearOpenings].tangent
        for _, tangent in ipairs({ firstTangent - 1, lastTangent + 1 }) do
          local sx, sy = contourPosition(run.direction, run.normal, tangent)
          local x, y = sx + highDX * depth, sy + highDY * depth
          if not inBounds(map, x, y, width, height) or water(x, y)
             or walkable(x, y) then return nil end
        end
        local transitionDirection = ({
          down = "up", up = "down", left = "right", right = "left",
        })[run.direction]
        for _, opening in ipairs(rearOpenings) do
          local lowX, lowY = opening.x + highDX, opening.y + highDY
          if not inBounds(map, lowX, lowY, width, height)
             or water(lowX, lowY) or not walkable(lowX, lowY) then return nil end
          transitions[#transitions + 1] = {
            x = opening.x, y = opening.y,
            direction = transitionDirection,
          }
        end
      end

      -- Both side rails must close every row of the selected band. This is
      -- what rejects an isolated jump lip and Route 5's open horizontal rail.
      for _, tangent in ipairs({ run.first - 1, run.last + 1 }) do
        local sx, sy = contourPosition(run.direction, run.normal, tangent)
        for offset = 0, depth - 1 do
          local x, y = sx + highDX * offset, sy + highDY * offset
          if not inBounds(map, x, y, width, height)
             or water(x, y) or walkable(x, y) then return nil end
          frame[y * width + x] = true
        end
      end
      return region, regionSet, frame, false, transitions
    end

    for _, run in ipairs(contours) do
      Budget.tick()
      -- At least one real interior break is required to distinguish a drawn
      -- contour from a decorative solid rail. Multiple breaks can prove a
      -- jump-ledge slice, but only one strictly enclosed break becomes stairs.
      if run.hasRamp then
        local region, regionSet, frame, stairOpening, transitions =
          enclosedRegion(run)
        if not region then
          region, regionSet, frame, stairOpening, transitions =
            boundedBandRegion(run)
        end
        if region then
          run.sliceRamp = stairOpening == true
          if not run.sliceRamp then
            -- Repeated jump-ledge breaks are not stair mouths. Carry those
            -- ordinary cells on the upper datum so the rendered retaining
            -- face stays on one straight, watertight front and the character
            -- does not fall into a half-cell trench inside a walkable gap.
            -- The low datum begins on the real landing row beyond the front.
            for tangent = run.first, run.last do
              if not run.actual[tangent] then
                local _, _, lx, ly =
                  contourPosition(run.direction, run.normal, tangent)
                frame[ly * width + lx] = true
              end
            end
          end
          acceptedContours[#acceptedContours + 1] = run
          sliceRegions[#sliceRegions + 1] = {
            cells = region,
            set = regionSet,
            frame = frame,
            transitions = transitions,
          }
          for _, occurrence in pairs(run.actual) do
            if not acceptedSeen[occurrence] then
              acceptedSeen[occurrence] = true
              acceptedOccurrences[#acceptedOccurrences + 1] = occurrence
              local lipKey = occurrence.ly * width + occurrence.lx
              acceptedLipCells[lipKey] = true
              acceptedLipGroups[lipKey] = acceptedLipGroups[lipKey] or {}
              acceptedLipGroups[lipKey][#acceptedLipGroups[lipKey] + 1] =
                occurrence
            end
          end
        end
      end
    end
    contours, occurrences = acceptedContours, acceptedOccurrences
    lipCells, lipGroups = acceptedLipCells, acceptedLipGroups
    ledgeCount = #acceptedOccurrences
    walkableCache = {}
  end

  -- Emit signed transitions.  DOWN/RIGHT cross from high to low while a
  -- north-to-south / west-to-east scan advances; UP/LEFT cross low to high.
  -- Events exist only inside a run's tangential span, including an accepted
  -- short road opening. A real rock/pillar frame closes the terrace below;
  -- extending the event to the whole row would invent stairs on unrelated
  -- roads elsewhere on the same map (Cerulean/Route 5 are the key cases).
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
      local sideProfile = sideRange
        and x >= sideRange[1] and x <= sideRange[2]
      values[k] = sideProfile and (horizontalValues[k] or 0)
                  or (verticalValues[k] or 0)
    end
  end

  -- LOCAL/WORLD derive a signed potential from every accepted contour.
  -- SLICE deliberately discards that potential: only the flood-proven upper
  -- component is high. This is what lets the terrain fall immediately behind
  -- the back/side retaining frame instead of extending a band to the map edge.
  if buildMode == "slice" then
    for y = 0, height - 1 do
      Budget.check()
      for x = 0, width - 1 do values[y * width + x] = 0 end
    end
    for _, region in ipairs(sliceRegions or {}) do
      Budget.check()
      for _, key in ipairs(region.cells) do
        Budget.tick()
        values[key] = step
      end
      for key in pairs(region.frame or {}) do values[key] = step end
    end
  end

  -- A connected mountain/building mass must never acquire a visible staircase
  -- just because two terrain profiles meet inside it. LOCAL therefore keeps
  -- the historical conservative rule: the whole object uses its lowest
  -- adjacent ground datum.
  --
  -- WORLD is intentionally different but still bounded. Every boundary rock
  -- or bollard inherits the nearest proven walkable surface. A one-cell frame
  -- touching both levels chooses the raised side; a thicker frame changes
  -- datum inside its own authored mass. Thus stones enclosing a raised terrace
  -- rise with that terrace, while the road after those stones can immediately
  -- return to zero. No event is extended across the map.
  local blockedVisited, queue = {}, {}
  for y = 0, height - 1 do
    Budget.check()
    for x = 0, width - 1 do
      local start = y * width + x
      if not walkable(x, y) and not lipCells[start]
         and not blockedVisited[start] then
        local region, regionSet, regionBase = {}, {}, nil
        local regionWater = water(x, y)
        local head = 1
        queue = { { x, y } }
        blockedVisited[start] = true
        while head <= #queue do
          Budget.tick()
          local here = queue[head]
          head = head + 1
          local hk = here[2] * width + here[1]
          region[#region + 1] = hk
          regionSet[hk] = true
          for _, offset in ipairs(NEIGHBOURS) do
            local nx, ny = here[1] + offset[1], here[2] + offset[2]
            if nx >= 0 and ny >= 0 and nx < width and ny < height then
              local nk = ny * width + nx
              if walkable(nx, ny) then
                local base = values[nk] or 0
                regionBase = regionBase == nil and base
                             or math.min(regionBase, base)
              elseif not lipCells[nk] and not blockedVisited[nk]
                     and not walkable(nx, ny)
                     and water(nx, ny) == regionWater then
                blockedVisited[nk] = true
                queue[#queue + 1] = { nx, ny }
              end
            end
          end
        end
        if buildMode == "slice" then
          -- The vertical-slice flood already selected the exact adjoining
          -- retaining cells. Never diffuse their height through a larger
          -- connected wall/rock mass (especially one reaching a map edge).
        elseif buildMode ~= "world" or regionWater then
          regionBase = regionBase or 0
          for _, k in ipairs(region) do values[k] = regionBase end
          if buildMode == "local" and not regionWater then
            -- Keep LOCAL conservative through the interior of a connected
            -- building/hedge mass, but seal its one-cell terrain-facing skin.
            -- Gen-I town hedges are often one connected collision object that
            -- touches both sides of a visual terrace. Giving the complete
            -- object its lowest datum cut square niches between the bushes.
            -- Only cells which directly touch proven walkable ground inherit
            -- that side's highest datum; no height can diffuse through the
            -- rest of the object or escape the current map.
            for _, k in ipairs(region) do
              Budget.tick()
              local rx, ry = k % width, math.floor(k / width)
              local boundary
              for _, offset in ipairs(NEIGHBOURS) do
                local nx, ny = rx + offset[1], ry + offset[2]
                if nx >= 0 and ny >= 0 and nx < width and ny < height
                   and walkable(nx, ny) then
                  local adjacent = values[ny * width + nx] or 0
                  boundary = boundary == nil and adjacent
                             or math.max(boundary, adjacent)
                end
              end
              if boundary ~= nil then values[k] = boundary end
            end
          end
        else
          -- First find all object cells that actually touch walkable ground.
          -- Their maximum adjacent datum makes a thin retaining wall part of
          -- the raised plateau instead of punching a six-pixel hole through it.
          local distance, inherited, wave, layers = {}, {}, {}, {}
          for _, k in ipairs(region) do
            Budget.tick()
            local rx, ry = k % width, math.floor(k / width)
            local seed
            for _, offset in ipairs(NEIGHBOURS) do
              local nx, ny = rx + offset[1], ry + offset[2]
              if nx >= 0 and ny >= 0 and nx < width and ny < height
                 and walkable(nx, ny) then
                local adjacent = values[ny * width + nx] or 0
                seed = seed == nil and adjacent or math.max(seed, adjacent)
              end
            end
            if seed ~= nil then
              distance[k], inherited[k] = 0, seed
              wave[#wave + 1] = k
            end
          end

          -- Multi-source distance through the object chooses the nearest
          -- terrain boundary. Resolve equal-distance ties toward the higher
          -- predecessor; that keeps a framed stair/terrace visually sealed.
          local waveHead, maxDistance = 1, 0
          while waveHead <= #wave do
            Budget.tick()
            local k = wave[waveHead]
            waveHead = waveHead + 1
            local rx, ry = k % width, math.floor(k / width)
            local nextDistance = distance[k] + 1
            for _, offset in ipairs(NEIGHBOURS) do
              local nx, ny = rx + offset[1], ry + offset[2]
              if nx >= 0 and ny >= 0 and nx < width and ny < height then
                local nk = ny * width + nx
                if regionSet[nk] and distance[nk] == nil then
                  distance[nk] = nextDistance
                  maxDistance = math.max(maxDistance, nextDistance)
                  layers[nextDistance] = layers[nextDistance] or {}
                  layers[nextDistance][#layers[nextDistance] + 1] = nk
                  wave[#wave + 1] = nk
                end
              end
            end
          end
          for d = 1, maxDistance do
            for _, k in ipairs(layers[d] or {}) do
              Budget.tick()
              local rx, ry = k % width, math.floor(k / width)
              local nearest
              for _, offset in ipairs(NEIGHBOURS) do
                local nx, ny = rx + offset[1], ry + offset[2]
                if nx >= 0 and ny >= 0 and nx < width and ny < height then
                  local nk = ny * width + nx
                  if distance[nk] == d - 1 then
                    local candidate = inherited[nk] or 0
                    nearest = nearest == nil and candidate
                              or math.max(nearest, candidate)
                  end
                end
              end
              inherited[k] = nearest or 0
            end
          end
          for _, k in ipairs(region) do values[k] = inherited[k] or 0 end
        end
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
  local tileValues, rampTiles = {}, {}
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
  -- cell datum. ChunkMesher tilts this tagged half into a short visual ramp.
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
                local tx, ty = lx * 2 + ox, ly * 2 + oy
                setTileBase(tx, ty, top)
                local rampKey = ty * tileWidth + tx
                local existing = rampTiles[rampKey]
                if buildMode ~= "slice" or run.sliceRamp then
                  if existing == nil then
                    rampTiles[rampKey] = { run.direction, top, low }
                  elseif type(existing) == "table"
                         and (existing[1] ~= run.direction
                              or existing[2] ~= top or existing[3] ~= low) then
                    -- A contradictory orthogonal custom contour has no unique
                    -- slope. Keep its proven flat closure instead of guessing.
                    rampTiles[rampKey] = false
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  -- A bounded SLICE band can have one real walkable gate in its rear frame.
  -- Grade that gate across its high 8px half instead of leaving a vertical
  -- render wall on collision-open ground. Front jump-ledge breaks never enter
  -- this list and therefore remain the straight retaining face above.
  local highNeighbour = {
    down = { 0, -1 }, up = { 0, 1 },
    left = { 1, 0 }, right = { -1, 0 },
  }
  for _, region in ipairs(sliceRegions or {}) do
    Budget.check()
    for _, transition in ipairs(region.transitions or {}) do
      Budget.tick()
      local offset = highNeighbour[transition.direction]
      local hx, hy = transition.x + offset[1], transition.y + offset[2]
      local top = values[hy * width + hx] or step
      local low = values[transition.y * width + transition.x] or 0
      if top > low then
        for oy = 0, 1 do
          for ox = 0, 1 do
            if isHighHalf(transition.direction, ox, oy) then
              local tx, ty = transition.x * 2 + ox,
                             transition.y * 2 + oy
              setTileBase(tx, ty, top)
              local rampKey = ty * tileWidth + tx
              local existing = rampTiles[rampKey]
              if existing == nil then
                rampTiles[rampKey] = {
                  transition.direction, top, low,
                }
              elseif type(existing) == "table"
                     and (existing[1] ~= transition.direction
                          or existing[2] ~= top or existing[3] ~= low) then
                rampTiles[rampKey] = false
              end
            end
          end
        end
      end
    end
  end

  return readonlySnapshot(width, height, step, values, tileValues, ledgeCount,
                          rampTiles, buildMode)
end

-- A raised LOCAL town is intentionally independent from the neighbouring
-- route's datum. At a direct, walkable map connection that reset still needs a
-- short render grade: otherwise the legal road ends in a vertical wall. Keep
-- the grade in the outer 8px atlas half, after the last gameplay/NPC stand
-- point, and never place it under water or decorative blocked border art.
local function localConnectionRamps(map, source, base)
  base = tonumber(base) or 0
  local width, height = source.width or 0, source.height or 0
  local tileWidth, tileHeight = source.tileWidth or width * 2,
                                source.tileHeight or height * 2
  local ramps = {}
  local function safeBool(method, x, y, fallback)
    if type(map and map[method]) ~= "function" then return fallback end
    local ok, value = pcall(map[method], map, x, y)
    return ok and value and true or false
  end
  local function eligible(x, y)
    -- No walkability authority means no invented stair. Runtime maps expose
    -- this method; tiny third-party fixtures that omit it fail safely flat.
    if not safeBool("isWalkableCell", x, y, false) then return false end
    return not safeBool("isWaterCell", x, y, false)
  end
  local function add(tx, ty, direction, high)
    if tx < 0 or ty < 0 or tx >= tileWidth or ty >= tileHeight then return end
    high = tonumber(high) or 0
    if high <= 0 then return end
    if type(source.rampAtTile) == "function"
       and source:rampAtTile(tx, ty) ~= nil then return end
    ramps[ty * tileWidth + tx] = { direction, high, 0 }
  end
  if connectionAt(map, "north") and height > 0 then
    for x = 0, width - 1 do
      if eligible(x, 0) then
        local high = source:at(x, 0) + base
        add(x * 2, 0, "up", high)
        add(x * 2 + 1, 0, "up", high)
      end
    end
  end
  if connectionAt(map, "south") and height > 0 then
    for x = 0, width - 1 do
      if eligible(x, height - 1) then
        local high = source:at(x, height - 1) + base
        add(x * 2, tileHeight - 1, "down", high)
        add(x * 2 + 1, tileHeight - 1, "down", high)
      end
    end
  end
  if connectionAt(map, "west") and width > 0 then
    for y = 0, height - 1 do
      if eligible(0, y) then
        local high = source:at(0, y) + base
        add(0, y * 2, "left", high)
        add(0, y * 2 + 1, "left", high)
      end
    end
  end
  if connectionAt(map, "east") and width > 0 then
    for y = 0, height - 1 do
      if eligible(width - 1, y) then
        local high = source:at(width - 1, y) + base
        add(tileWidth - 1, y * 2, "right", high)
        add(tileWidth - 1, y * 2 + 1, "right", high)
      end
    end
  end
  return next(ramps) and ramps or nil
end

-- Add one seamless-map datum without copying the potentially large cell/tile
-- arrays. WORLD clamps off-body terrain queries to the nearest edge sample, so
-- ChunkMesher's border ring continues the last terrace. LOCAL can instead
-- expose the lower reset datum plus boundary-ramp tags supplied above.
local function placedSnapshot(source, base, options)
  base = tonumber(base) or 0
  options = type(options) == "table" and options or {}
  local ramps = options.ramps
  local outsideBase = tonumber(options.outsideBase)
  local width, height = source.width or 0, source.height or 0
  local tileWidth, tileHeight = source.tileWidth or width * 2,
                                source.tileHeight or height * 2
  local function clamp(value, limit)
    if limit <= 0 then return 0 end
    return math.max(0, math.min(limit - 1, math.floor(value)))
  end
  local public = {
    width = width, height = height,
    tileWidth = tileWidth, tileHeight = tileHeight,
    step = source.step, ledgeCount = source.ledgeCount,
    terrainMode = source.terrainMode,
    worldBase = base,
  }
  function public.at(_, x, y)
    x, y = tonumber(x), tonumber(y)
    if not x or not y or width <= 0 or height <= 0 then return base end
    x, y = math.floor(x), math.floor(y)
    if outsideBase ~= nil
       and (x < 0 or y < 0 or x >= width or y >= height) then
      return outsideBase
    end
    return source:at(clamp(x, width), clamp(y, height)) + base
  end
  function public.atTile(_, tx, ty)
    tx, ty = tonumber(tx), tonumber(ty)
    if not tx or not ty or tileWidth <= 0 or tileHeight <= 0 then return base end
    tx, ty = math.floor(tx), math.floor(ty)
    if outsideBase ~= nil
       and (tx < 0 or ty < 0 or tx >= tileWidth or ty >= tileHeight) then
      return outsideBase
    end
    return source:atTile(clamp(tx, tileWidth), clamp(ty, tileHeight)) + base
  end
  function public.atWorld(self, wx, wz)
    wx, wz = tonumber(wx), tonumber(wz)
    if not wx or not wz then return base end
    return self:atTile(math.floor(wx / 8), math.floor(wz / 8))
  end
  function public.rampAtTile(_, tx, ty)
    tx, ty = tonumber(tx), tonumber(ty)
    if not tx or not ty or tx < 0 or ty < 0
       or tx >= tileWidth or ty >= tileHeight then return nil end
    tx, ty = math.floor(tx), math.floor(ty)
    local localRamp = ramps and ramps[ty * tileWidth + tx]
    if type(localRamp) == "table" then
      return localRamp[1], localRamp[2], localRamp[3]
    end
    if type(source.rampAtTile) ~= "function" then return nil end
    local direction, high, low = source:rampAtTile(tx, ty)
    if not direction then return nil end
    return direction, high + base, low + base
  end
  return setmetatable({}, {
    __index = public,
    __newindex = function()
      error("ledge elevation snapshots are immutable", 2)
    end,
    __metatable = "world-ledge-elevation-snapshot",
  })
end

local function seamDifference(a, aField, b, bField, direction, connection)
  if not (aField and bField) then return nil end
  local offset = math.floor((tonumber(connection and connection.offset) or 0)
                            * 2)
  local walkableCounts, allCounts = {}, {}
  local walkableSamples = 0
  local function vote(counts, difference)
    counts[difference] = (counts[difference] or 0) + 1
  end
  local function seamWalkable(map, x, y)
    if type(map) ~= "table" or type(map.isWalkableCell) ~= "function" then
      return nil
    end
    local ok, value = pcall(map.isWalkableCell, map, x, y)
    return ok and value and true or false
  end
  local function sample(ax, ay, bx, by)
    if ax < 0 or ay < 0 or bx < 0 or by < 0
       or ax >= aField.width or ay >= aField.height
       or bx >= bField.width or by >= bField.height then return end
    local difference = aField:at(ax, ay) - bField:at(bx, by)
    vote(allCounts, difference)
    -- A seamless map hop can occur only through the shared walkable opening.
    -- Perimeter trees, retaining rocks and bollards commonly occupy most of
    -- the raw edge; letting that decorative majority vote forced Route 1's
    -- raised road back to zero on entering Viridian.  Prefer exact traversable
    -- pairs and retain the all-edge histogram only for reduced/legacy maps
    -- without a readable walkability contract.
    if seamWalkable(a, ax, ay) and seamWalkable(b, bx, by) then
      walkableSamples = walkableSamples + 1
      vote(walkableCounts, difference)
    end
  end
  if direction == "north" or direction == "south" then
    local ay = direction == "north" and 0 or aField.height - 1
    local by = direction == "north" and bField.height - 1 or 0
    for ax = 0, aField.width - 1 do sample(ax, ay, ax - offset, by) end
  elseif direction == "west" or direction == "east" then
    local ax = direction == "west" and 0 or aField.width - 1
    local bx = direction == "west" and bField.width - 1 or 0
    for ay = 0, aField.height - 1 do sample(ax, ay, bx, ay - offset) end
  else
    return nil
  end
  local counts = walkableSamples > 0 and walkableCounts or allCounts
  local best, bestCount
  for difference, count in pairs(counts) do
    if not bestCount or count > bestCount
       or (count == bestCount and math.abs(difference) < math.abs(best))
       or (count == bestCount and math.abs(difference) == math.abs(best)
           and difference < best) then
      best, bestCount = difference, count
    end
  end
  return best
end

local DIRECTIONS = { "north", "south", "west", "east" }

-- These ROM map connections join pieces that are geographically separated by
-- an indoor/warp transition. They are useful for the 2D world layout, but must
-- not carry a terrain datum through Viridian Forest, Mt. Moon or Rock Tunnel.
-- Keeping this tiny explicit list avoids the costly whole-map component scan
-- that previously made every map load slower and misclassified ponds.
local WORLD_RESET_PAIRS = {
  ["PEWTER_CITY|ROUTE_2"] = true,
  ["ROUTE_3|ROUTE_4"] = true,
  ["LAVENDER_TOWN|ROUTE_10"] = true,
}

local function worldPair(aId, bId)
  local a, b = tostring(aId), tostring(bId)
  if b < a then a, b = b, a end
  return a .. "|" .. b
end

local function connectWorld(aId, bId, direction, connection)
  local a, b = worldMaps[aId], worldMaps[bId]
  local aField, bField = worldLocal[aId], worldLocal[bId]
  if not (a and b and aField and bField) then return false end
  if WORLD_RESET_PAIRS[worldPair(aId, bId)] then return false end
  local difference = seamDifference(a, aField, b, bField,
                                    direction, connection)
  if difference == nil then return false end
  if worldBase[aId] ~= nil and worldBase[bId] == nil then
    worldBase[bId] = worldBase[aId] + difference
    return true
  elseif worldBase[bId] ~= nil and worldBase[aId] == nil then
    worldBase[aId] = worldBase[bId] - difference
    return true
  end
  return false
end

local function placeWorld(map, localField)
  local id = map and map.id
  if id == nil then return 0 end
  worldMaps[id], worldLocal[id] = map, localField
  local connections = map.def and map.def.connections or {}
  for _, direction in ipairs(DIRECTIONS) do
    local connection = connections[direction]
    if connection and connection.map ~= nil then
      connectWorld(id, connection.map, direction, connection)
    end
  end
  if worldBase[id] == nil then
    for otherId, other in pairs(worldMaps) do
      if otherId ~= id and other and other.def then
        for _, direction in ipairs(DIRECTIONS) do
          local connection = other.def.connections
                             and other.def.connections[direction]
          if connection and connection.map == id then
            connectWorld(otherId, id, direction, connection)
          end
        end
      end
    end
  end
  if worldBase[id] == nil then worldBase[id] = 0 end
  return worldBase[id]
end

-- Immutable cached snapshot for a map. Passing a different data authority
-- rebuilds automatically; mutating the same map/data deliberately requires
-- invalidate(), so a half-edited map can never change underneath a mesh job.
function LedgeElevation.map(map, explicitData)
  if type(map) ~= "table" then
    return readonlySnapshot(0, 0, profileStep(), {}, nil, 0, nil, mode())
  end
  local data = gameData(explicitData)
  local buildMode = mode()
  local entry = cache[map]
  if entry and entry.data == data and entry.mode == buildMode then
    return entry.snapshot
  end
  local localField = build(map, data, buildMode)
  local snapshot = localField
  if buildMode == "world" then
    snapshot = placedSnapshot(localField, placeWorld(map, localField))
  elseif buildMode == "local" then
    local base = localField.step * (LOCAL_CITY_COURSES[map.id] or 0)
    local ramps = localConnectionRamps(map, localField, base)
    if base ~= 0 or ramps ~= nil then
      snapshot = placedSnapshot(localField, base, {
        outsideBase = 0,
        ramps = ramps,
      })
    end
  end
  cache[map] = { data = data, mode = buildMode,
                 localField = localField, snapshot = snapshot }
  return snapshot
end

function LedgeElevation.basisAtCell(map, cellX, cellY, explicitData)
  return LedgeElevation.map(map, explicitData):at(cellX, cellY)
end

function LedgeElevation.invalidate(map)
  if map ~= nil then
    local had = cache[map] ~= nil
    cache[map] = nil
    if type(map) == "table" and map.id ~= nil then
      worldMaps[map.id], worldLocal[map.id] = nil, nil
    end
    return had
  end
  cache = setmetatable({}, { __mode = "k" })
  worldMaps = setmetatable({}, { __mode = "v" })
  worldLocal = setmetatable({}, { __mode = "v" })
  worldBase = {}
  return true
end

-- Focused deterministic contract seam; production callers use the saved row.
function LedgeElevation._setModeForTests(value)
  if value ~= nil and value ~= "world" and value ~= "slice"
     and value ~= "local"
     and value ~= "flat" then error("invalid ledge elevation test mode", 2) end
  testMode = value
  LedgeElevation.invalidate()
end

LedgeElevation.FALLBACK_STEP = FALLBACK_STEP

return LedgeElevation
