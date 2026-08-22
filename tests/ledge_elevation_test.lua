local cache = {}

local profile = { heights = { ledge = 6 } }
local V = {
  data = function(name)
    if name == "voxel_heights" then return profile end
  end,
}
function V.require(name)
  if cache[name] then return cache[name] end
  cache[name] = assert(loadfile("lib/" .. name .. ".lua"))(V)
  return cache[name]
end

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected "
          .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function truth(value, message)
  if not value then error(message or "expected truthy value", 2) end
end

local function mapOf(id, rows, connections)
  local height = #rows
  local width = height > 0 and #rows[1] or 0
  local map = {
    id = id,
    widthCells = width,
    heightCells = height,
    def = {
      id = id,
      width = width / 2,
      height = height / 2,
      tileset = "OVERWORLD",
      connections = connections or {},
    },
    rows = rows,
  }
  function map:inBounds(x, y)
    return x >= 0 and y >= 0 and x < self.widthCells
      and y < self.heightCells
  end
  function map:cellTile(x, y)
    return self.rows[y + 1] and self.rows[y + 1][x + 1]
  end
  -- Deliberately present for the bypass fixture below. The helper must not
  -- use connectivity: a legal route around a lip does not make it flat.
  function map:isWalkableCell(x, y)
    return self:inBounds(x, y) and self:cellTile(x, y) ~= 90
  end
  return map
end

local DOWN_STAND, DOWN_LEDGE = 57, 54 -- real Gen 1 $39 -> $36 row
local UP_STAND, UP_LEDGE = 44, 55
local data = {
  field = {
    ledges = {
      { tileset = "OVERWORLD", facing = "down", input = "down",
        standingTile = DOWN_STAND, ledgeTile = DOWN_LEDGE },
      { tileset = "OVERWORLD", facing = "up", input = "up",
        standingTile = UP_STAND, ledgeTile = UP_LEDGE },
    },
  },
}

local LedgeElevation = V.require("LedgeElevation")

-- One finite three-cell ledge run with fully walkable bypasses at both ends.
-- The authored lateral footprint is a real one-course terrace, but neither
-- endpoint may leak that height into the unrelated columns beside it.
local loop = mapOf("LOOP_PLATEAU", {
  { 1, 57, 90, 57, 1 },
  { 1, 57, 57, 57, 1 },
  { 1, 54, 54, 54, 1 },
  { 1, 1,  1,  1,  1 },
  { 1, 1,  1,  1,  1 },
})
local loopField = LedgeElevation.map(loop, data)
eq(loopField.ledgeCount, 3, "the complete drawn run is detected")
eq(loopField:at(2, 0), 6, "blocked art inside the finite footprint rides it")
eq(loopField:at(2, 1), 6, "finite standing side is one course high")
eq(loopField:at(2, 2), 0,
   "finite lip cell keeps the low datum")
eq(loopField:at(2, 3), 0, "finite landing side stays on the map datum")
eq(loopField:at(0, 1), 0, "ground beyond the west endpoint stays flat")
eq(loopField:at(4, 1), 0, "ground beyond the east endpoint stays flat")
eq(loopField:atTile(4, 4), 6,
   "ordinary high half closes the finite plateau")
eq(loopField:atTile(4, 5), 0,
   "intrinsic lip basis remains on the lower terrace")
eq(loopField:atTile(4, 5) + loopField.step, 6,
   "intrinsic lip reaches the standing terrace exactly once")

-- Two pieces of one aligned contour separated by a one-cell walkable road.
-- This is common in Kanto: the path is an opening in the art, not a separate
-- level. Both terrace bands and the road column must stay uniform. The gap's
-- high 8px half is synthesized so it cannot become a groove in the mesh.
local roadGap = mapOf("ROAD_GAP", {
  { 57, 57, 1,  57, 57 },
  { 54, 54, 1,  54, 54 },
  { 1,  1,  1,  1,  1  },
  { 1,  1,  1,  1,  1  },
})
local roadField = LedgeElevation.map(roadGap, data)
eq(roadField.ledgeCount, 4, "road fixture counts only authored lips")
for x = 0, 4 do
  eq(roadField:at(x, 0), 6, "road-gap upper terrace is uniform at x=" .. x)
  eq(roadField:at(x, 2), 0, "road-gap lower terrace is uniform at x=" .. x)
end
eq(roadField:at(2, 1), 0, "road contour cell keeps the low datum")
eq(roadField:atTile(4, 2), 6,
   "road contour's ordinary high half closes the terrace")
eq(roadField:atTile(4, 3), 0,
   "road contour's low half stays on the lower terrace")

-- Closing the exact same run against both map sides produces the same local
-- six-pixel plateau, and blocked/object art inside its footprint inherits one
-- uniform datum rather than punching a hole in the top.
local closed = mapOf("CLOSED_PLATEAU", {
  { 57, 90, 57 },
  { 57, 57, 57 },
  { 54, 54, 54 },
  { 1,  1,  1 },
  { 1,  1,  1 },
})
local closedField = LedgeElevation.map(closed, data)
eq(closedField.ledgeCount, 3, "the closed run detects all authored lips")
eq(closedField:at(1, 0), 6, "blocked art rides a proven plateau")
eq(closedField:at(1, 1), 6, "closed standing side is one course high")
eq(closedField:at(1, 2), 0, "closed lip keeps the low cell datum")
eq(closedField:at(1, 3), 0, "closed landing side stays low")
eq(closedField:atTile(2, 4), 6,
   "ordinary high half closes the proven plateau")
eq(closedField:atTile(2, 5), 0,
   "intrinsic closed lip rises exactly once from the low basis")
eq(closedField:atWorld(20, 36), 6,
   "world-space scenery samples the proven high half")
eq(closedField:atWorld(20, 44), 0,
   "world-space scenery samples the intrinsic low-basis half")

-- Canonical Red ROUTE_4, collision column x=6, copied from the generated
-- map/OVERWORLD blockset. It contains three real $39,$36,* hop-down rows at
-- y=6/7/8, 10/11/12 and 14/15/16. The signed sweep must retain all three
-- terraces rather than treating the map's many ways around them as a cycle.
local route4Column = mapOf("ROUTE_4", {
  { 0x11 }, { 0x11 }, { 0x11 }, { 0x37 },
  { 0x39 }, { 0x23 }, { 0x39 }, { 0x36 },
  { 0x39 }, { 0x23 }, { 0x39 }, { 0x36 },
  { 0x39 }, { 0x23 }, { 0x39 }, { 0x36 },
  { 0x39 }, { 0x23 },
})
local route4 = LedgeElevation.map(route4Column, data)
eq(route4.ledgeCount, 3, "Route 4 fixture contains three authored drops")
eq(route4:at(0, 4), 18, "Route 4 upper terrace is three courses high")
eq(route4:at(0, 7), 12,
   "Route 4 first lip uses the next terrace datum, avoiding a 12px lip")
eq(route4:atTile(0, 14), 18,
   "Route 4 lip cell reaches the upper terrace for its full 16px depth")
eq(route4:atTile(0, 15), 12,
   "Route 4 authored face keeps the lower basis and rises intrinsically")
eq(route4:at(0, 8), 12, "Route 4 second terrace drops exactly one course")
eq(route4:at(0, 11), 6,
   "Route 4 second lip uses the next terrace datum")
eq(route4:at(0, 12), 6, "Route 4 third terrace drops exactly one course")
eq(route4:at(0, 15), 0,
   "Route 4 third lip uses the foot datum")
eq(route4:at(0, 16), 0, "Route 4 foot is the normalized datum")
eq(route4:at(-1, 4), 0, "off-map/ring queries retain the zero datum")

-- Two-dimensional Route 4 golden. These spans mirror the authored local
-- contours that exposed both regressions in-game: x=6 crosses three short,
-- differently-wide runs, while x=70 crosses three eastern runs containing a
-- one- and a two-cell road opening. A distant contour must never leak into a
-- neighbouring column merely because it shares the same map row.
local routeRows = {}
for y = 1, 18 do
  routeRows[y] = {}
  for x = 1, 82 do routeRows[y][x] = 1 end
end
local function downRun(standingY, pieces)
  for _, piece in ipairs(pieces) do
    for x = piece[1], piece[2] do
      routeRows[standingY + 1][x + 1] = DOWN_STAND
      routeRows[standingY + 2][x + 1] = DOWN_LEDGE
    end
  end
end
downRun(6,  { { 4, 7 } })
downRun(10, { { 4, 11 } })
downRun(14, { { 6, 9 } })
downRun(4,  { { 61, 79 } })
downRun(6,  { { 55, 56 }, { 58, 79 } }) -- one-cell road
downRun(8,  { { 64, 73 }, { 76, 79 } }) -- two-cell road
local routeLocal = LedgeElevation.map(mapOf("ROUTE_4_LOCAL", routeRows), data)

eq(routeLocal:at(6, 4), 18, "x6 upper terrace has all three local courses")
eq(routeLocal:at(6, 7), 12, "x6 first lip uses the next lower basis")
eq(routeLocal:atTile(12, 14), 18, "x6 first lip high half closes at 18")
eq(routeLocal:atTile(12, 15), 12, "x6 first intrinsic half stays at 12")
eq(routeLocal:at(6, 8), 12, "x6 second terrace")
eq(routeLocal:at(6, 11), 6, "x6 second lip")
eq(routeLocal:at(6, 12), 6, "x6 third terrace")
eq(routeLocal:at(6, 15), 0, "x6 third lip")
eq(routeLocal:at(6, 16), 0, "x6 foot")

eq(routeLocal:at(70, 4), 18, "x70 eastern upper terrace")
eq(routeLocal:at(70, 5), 12, "x70 first lip")
eq(routeLocal:at(70, 6), 12, "x70 second terrace")
eq(routeLocal:at(70, 7), 6, "x70 second lip")
eq(routeLocal:at(70, 8), 6, "x70 third terrace")
eq(routeLocal:at(70, 9), 0, "x70 third lip")
eq(routeLocal:at(70, 10), 0, "x70 foot")
eq(routeLocal:at(57, 6), 6, "one-cell road shares its upper level")
eq(routeLocal:at(57, 8), 0, "one-cell road shares its lower level")
eq(routeLocal:at(74, 8), 6, "two-cell road shares its upper level")
eq(routeLocal:at(75, 10), 0, "two-cell road shares its lower level")

eq(routeLocal:at(8, 6), routeLocal:at(8, 8),
   "x8 does not inherit the first x4-to-x7 contour")
eq(routeLocal:at(10, 14), routeLocal:at(10, 16),
   "x10 stays flat outside the x6-to-x9 third contour")

-- Facing each other: a down lip and an up lip bound one low trench. Signed
-- events return to the original potential, so the two outer plateaus are
-- both 6 rather than one drifting to 12.
local opposite = mapOf("OPPOSITE", {
  { 57 },
  { 57 },
  { 54 },
  { 1 },
  { 55 },
  { 44 },
  { 44 },
})
local opposed = LedgeElevation.map(opposite, data)
eq(opposed:at(0, 1), 6, "north outer plateau")
eq(opposed:at(0, 2), 0, "down lip itself keeps the low trench datum")
eq(opposed:at(0, 3), 0, "opposed ledges bound one low trench")
eq(opposed:at(0, 4), 0, "up lip itself keeps the low trench datum")
eq(opposed:at(0, 5), 6, "south outer plateau matches north")

-- Two-way rules over the same lip are unusual mod data, but must remain
-- bounded and deterministic: both standing sides use the high datum while
-- the intrinsically raised lip keeps the low one, never an iterative cycle.
local contradictoryData = {
  field = { ledges = {
    { tileset = "OVERWORLD", facing = "down", input = "down",
      standingTile = 57, ledgeTile = 54 },
    { tileset = "OVERWORLD", facing = "up", input = "up",
      standingTile = 57, ledgeTile = 54 },
  } },
}
local ridgeMap = mapOf("RIDGE", { { 57 }, { 54 }, { 57 } })
local ridge = LedgeElevation.map(ridgeMap, contradictoryData)
eq(ridge:at(0, 0), 6, "two-way north standing side is one course high")
eq(ridge:at(0, 1), 0, "two-way lip keeps the low datum")
eq(ridge:at(0, 2), 6, "two-way south standing side is one course high")
for _ = 1, 100 do
  eq(LedgeElevation.basisAtCell(ridgeMap, 0, 0, contradictoryData), 6,
     "repeated reads cannot accumulate cycle drift")
end

-- Two finite orthogonal runs close one local plateau corner. Their proofs are
-- combined with max, not addition: the overlap is still one six-pixel level,
-- while cells beyond either run's tangential endpoints remain unaffected.
local RIGHT_STAND, RIGHT_LEDGE = 70, 71
local bothData = {
  field = { ledges = {
    data.field.ledges[1],
    { tileset = "OVERWORLD", facing = "right", input = "right",
      standingTile = RIGHT_STAND, ledgeTile = RIGHT_LEDGE },
  } },
}
local corner = mapOf("CORNER", {
  { 57, 57, 70, 71, 1 },
  { 57, 57, 70, 71, 1 },
  { 54, 54, 70, 71, 1 },
  { 1,  1,  70, 71, 1 },
  { 1,  1,  1,  1,  1 },
})
local cornerField = LedgeElevation.map(corner, bothData)
eq(cornerField:at(1, 1), 6,
   "orthogonal overlap remains one course instead of adding to twelve")
eq(cornerField:at(2, 1), 6,
   "side contour continues the same local plateau")
eq(cornerField:at(4, 4), 0,
   "ground beyond both finite contour endpoints stays flat")
eq(cornerField:atTile(2, 4), 6,
   "down-lip high half closes the local plateau")
eq(cornerField:atTile(6, 2), 0,
   "side lip keeps the low basis and rises intrinsically once")

-- Side-facing lips use the same 8px closure rule with a different half-cell:
-- LEFT has ordinary plateau art east of its intrinsic west-half face; RIGHT
-- places that west-half face immediately beside the standing cell. Neither
-- orientation may leave a slit or lift its authored face twice.
local leftData = {
  field = { ledges = {
    { tileset = "OVERWORLD", facing = "left", input = "left",
      standingTile = 70, ledgeTile = 71 },
  } },
}
local leftLip = mapOf("LEFT_HALF", { { 1, 71, 70, 1 } })
local leftField = LedgeElevation.map(leftLip, leftData)
eq(leftField:atTile(2, 0), 0,
   "left-facing intrinsic west half keeps the low basis")
eq(leftField:atTile(3, 0), 6,
   "left-facing ordinary east half reaches its standing plateau")

-- Three nested side closures exercise the Route 4 x=61 neighbourhood shape:
-- every interval between authored lips is uniform. Restoring a hard landing
-- after axis composition must not leave a one-cell 6px dip beside that
-- landing, and each successive closure must retain the next course.
local nestedLeft = mapOf("NESTED_LEFT", {
  { 1, 1, 71, 70, 1, 71, 70, 1, 71, 70, 1 },
})
local nestedField = LedgeElevation.map(nestedLeft, leftData)
eq(nestedField:at(3, 0), 6, "first side band standing level")
eq(nestedField:at(4, 0), 6, "first side band landing neighbour is uniform")
eq(nestedField:at(5, 0), 6, "second lip uses that same lower basis")
eq(nestedField:at(6, 0), 12, "second side band standing level")
eq(nestedField:at(7, 0), 12, "second side band landing neighbour is uniform")
eq(nestedField:at(8, 0), 12, "third lip uses that same lower basis")
eq(nestedField:at(9, 0), 18, "third side closure retains all three courses")

local rightData = {
  field = { ledges = {
    { tileset = "OVERWORLD", facing = "right", input = "right",
      standingTile = 70, ledgeTile = 71 },
  } },
}
local rightLip = mapOf("RIGHT_HALF", { { 1, 70, 71, 1 } })
local rightField = LedgeElevation.map(rightLip, rightData)
eq(rightField:atTile(4, 0), 0,
   "right-facing intrinsic west half stays one course below its top")
eq(rightField:atTile(5, 0), 0,
   "right-facing landing half stays on the lower terrace")

-- A connected-map hop whose landing lies one cell past the body still gives
-- the departing map a high datum. Without the virtual end sample it would
-- normalize the body's only level back to zero.
local seam = mapOf("SEAM", { { 57 }, { 54 } }, { south = { map = "NEXT" } })
eq(LedgeElevation.basisAtCell(seam, 0, 0, data), 6,
   "connection-edge ledge raises the departing map")
local seamNeighbour = mapOf("NEXT", { { 1 }, { 1 } },
                            { north = { map = "SEAM" } })
eq(LedgeElevation.basisAtCell(seamNeighbour, 0, 0, data), 0,
   "a connected body derives its own snapshot instead of inheriting a seam")

-- Cache and invalidation contract. A mesh job gets a stable immutable
-- snapshot even if a development tool edits the live map underneath it.
local editRows = { { 57 }, { 54 }, { 1 } }
local edited = mapOf("EDITED", editRows)
local before = LedgeElevation.map(edited, data)
eq(before:at(0, 0), 6, "initial edited-map plateau")
eq(LedgeElevation.map(edited, data), before, "map snapshot is cached")
editRows[2][1] = 1
eq(LedgeElevation.basisAtCell(edited, 0, 0, data), 6,
   "cached snapshot ignores an uncommitted map edit")
eq(LedgeElevation.invalidate(edited), true, "one-map invalidation reports hit")
local after = LedgeElevation.map(edited, data)
truth(after ~= before, "invalidation creates a new snapshot")
eq(after:at(0, 0), 0, "committed map edit is visible after invalidation")
eq(before:at(0, 0), 6, "old immutable snapshot remains stable")
local ok = pcall(function() before.width = 99 end)
eq(ok, false, "snapshot public fields cannot be mutated")
eq(LedgeElevation.invalidate(), true, "global invalidation succeeds")

-- The cold Route-4-sized analysis runs inside ChunkMesher's coroutine. It
-- must hand control back when that coroutine's frame slice expires, while a
-- synchronous caller and the resumed build still receive the exact same
-- immutable cell/tile snapshot.
local budgetMap = mapOf("BUDGET_ROUTE_4", routeRows)
local directBudgetField = LedgeElevation.map(budgetMap, data)
LedgeElevation.invalidate(budgetMap)

local runnerLove = rawget(_G, "love")
local runnerTimer = runnerLove and runnerLove.timer or nil
local virtualNow = 0
love = runnerLove or {}
love.timer = {
  getTime = function()
    virtualNow = virtualNow + 0.00001
    return virtualNow
  end,
}

local Budget = V.require("BuildBudget")
local resumedBudgetField
local co = coroutine.create(function()
  resumedBudgetField = LedgeElevation.map(budgetMap, data)
end)
local yields, guard = 0, 0
while coroutine.status(co) ~= "dead" do
  guard = guard + 1
  if guard > 2000 then error("budgeted ledge analysis did not finish") end
  Budget.begin(co, 0.000005)
  local resumed, reason = coroutine.resume(co)
  Budget.finish()
  truth(resumed, reason)
  if coroutine.status(co) ~= "dead" then
    eq(reason, "budget", "ledge analysis yielded outside BuildBudget")
    yields = yields + 1
  end
end

if runnerLove then
  runnerLove.timer = runnerTimer
  love = runnerLove
else
  love = nil
end

truth(yields > 20, "Route-4-sized ledge analysis ignored the frame budget")
eq(resumedBudgetField.width, directBudgetField.width,
   "budgeted snapshot width")
eq(resumedBudgetField.height, directBudgetField.height,
   "budgeted snapshot height")
eq(resumedBudgetField.step, directBudgetField.step,
   "budgeted snapshot step")
eq(resumedBudgetField.ledgeCount, directBudgetField.ledgeCount,
   "budgeted snapshot ledge count")
for y = 0, directBudgetField.height - 1 do
  for x = 0, directBudgetField.width - 1 do
    eq(resumedBudgetField:at(x, y), directBudgetField:at(x, y),
       ("budgeted cell changed at %d,%d"):format(x, y))
  end
end
for ty = 0, directBudgetField.tileHeight - 1 do
  for tx = 0, directBudgetField.tileWidth - 1 do
    eq(resumedBudgetField:atTile(tx, ty), directBudgetField:atTile(tx, ty),
       ("budgeted tile changed at %d,%d"):format(tx, ty))
  end
end

print(("ledge elevation: ok (%d cooperative yields)"):format(yields))
