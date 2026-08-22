local cache = {}
local V = {}

function V.require(name)
  if cache[name] then return cache[name] end
  if name == "WorldPlacement" then
    cache[name] = assert(loadfile("lib/WorldPlacement.lua"))(V)
  elseif name == "ModSetting" then
    cache[name] = {
      new = function()
        return { get = function() return "full" end }
      end,
    }
  elseif name == "Voxel3D" then
    cache[name] = { FACE_SHADE = {} }
  else
    cache[name] = {}
  end
  return cache[name]
end

package.preload["src.render.TileRenderer"] = function()
  return { voidFill = "trees" }
end

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected "
          .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function truthy(value, message)
  if not value then error(message or "expected truthy value", 2) end
end

local function def(id, width, height, connections)
  return { id = id, width = width, height = height, tileset = "OVERWORLD",
           outdoor = true, connections = connections or {} }
end

local route3 = def("ROUTE_3", 35, 9, {
  north = { map = "ROUTE_4", offset = 25 },
})
local route4 = def("ROUTE_4", 45, 9, {
  south = { map = "ROUTE_3", offset = -25 },
  east = { map = "CERULEAN_CITY", offset = -4 },
})
local cerulean = def("CERULEAN_CITY", 20, 18, {
  west = { map = "ROUTE_4", offset = 4 },
})
local world = {
  ROUTE_3 = route3, ROUTE_4 = route4, CERULEAN_CITY = cerulean,
}

local function map(record)
  return { id = record.id, def = record, tileset = {} }
end

local r3, r4 = map(route3), map(route4)
local Horizon = assert(loadfile("lib/HorizonWall.lua"))(V)

local route4Root = {
  map = r4, worldMaps = world,
  neighbors = { { map = r3, ox = -800, oy = 288 } },
}
local route3Root = {
  map = r3, worldMaps = world,
  neighbors = { { map = r4, ox = 800, oy = -288 } },
}

local key4, bx4, by4, canonical4, stable4 =
  Horizon._canonicalAddress(route4Root)
local key3, bx3, by3, canonical3, stable3 =
  Horizon._canonicalAddress(route3Root)
eq(key4, key3, "Route 4/3 re-root rebuilt an identical horizon union")
eq(stable4, true, "Route 4 did not use component-stable coordinates")
eq(stable3, true, "Route 3 did not use component-stable coordinates")

-- CERULEAN_CITY is the lexicographic component anchor even though it is not
-- in this visible pair. This proves the origin came from the full connection
-- component, not from the minimum id of whichever maps happened to be drawn.
eq(cache.WorldPlacement.position("CERULEAN_CITY", world).x, 0,
   "full component anchor was not stable")

local function offset(entries, id)
  for _, entry in ipairs(entries) do
    if entry.map.id == id then return entry.ox, entry.oy end
  end
end
local r4x, r4y = offset(canonical4, "ROUTE_4")
local r3x, r3y = offset(canonical4, "ROUTE_3")
eq(r4x + bx4, 0, "Route 4 canonical mesh did not rebase to its root")
eq(r4y + by4, 0, "Route 4 canonical Y did not rebase to its root")
eq(r3x + bx4, -800, "Route 3 moved in the Route 4 frame")
eq(r3y + by4, 288, "Route 3 Y moved in the Route 4 frame")
eq(r3x + bx3, 0, "Route 3 canonical mesh did not rebase to its root")
eq(r3y + by3, 0, "Route 3 canonical Y did not rebase to its root")
eq(r4x + bx3, 800, "Route 4 moved in the Route 3 frame")
eq(r4y + by3, -288, "Route 4 Y moved in the Route 3 frame")

-- The other user-visible return loop uses the same address contract.
local pallet = def("PALLET_TOWN", 10, 9, {
  north = { map = "ROUTE_1", offset = 0 },
})
local route1 = def("ROUTE_1", 10, 18, {
  south = { map = "PALLET_TOWN", offset = 0 },
})
local southWorld = { PALLET_TOWN = pallet, ROUTE_1 = route1 }
cache.WorldPlacement.invalidate()
local p, r1 = map(pallet), map(route1)
local palletState = {
  map = p, worldMaps = southWorld,
  neighbors = { { map = r1, ox = 0, oy = -576 } },
}
local route1State = {
  map = r1, worldMaps = southWorld,
  neighbors = { { map = p, ox = 0, oy = 576 } },
}
local palletKey = Horizon._canonicalAddress(palletState)
local route1Key = Horizon._canonicalAddress(route1State)
eq(palletKey, route1Key, "Pallet/Route 1 return missed the horizon cache")

-- Route 8's retained handoff is three maps wide: Saffron west, Lavender
-- east, and Route 8 between them.  The live transition audit crosses this
-- exact set in both directions, so root normalization must preserve the same
-- complete horizon instead of briefly rebuilding a current-only curtain.
local route8 = def("ROUTE_8", 30, 9, {
  west = { map = "SAFFRON_CITY", offset = -4 },
  east = { map = "LAVENDER_TOWN", offset = 0 },
})
local saffron = def("SAFFRON_CITY", 20, 18, {
  east = { map = "ROUTE_8", offset = 4 },
})
local lavender = def("LAVENDER_TOWN", 10, 9, {
  west = { map = "ROUTE_8", offset = 0 },
})
local eastWorld = {
  ROUTE_8 = route8, SAFFRON_CITY = saffron, LAVENDER_TOWN = lavender,
}
cache.WorldPlacement.invalidate()
local r8, saff, lav = map(route8), map(saffron), map(lavender)
local route8Handoff = {
  map = r8, worldMaps = eastWorld,
  neighbors = {
    { map = saff, ox = -640, oy = -128 },
    { map = lav, ox = 960, oy = 0 },
  },
}
local lavenderHandoff = {
  map = lav, worldMaps = eastWorld,
  neighbors = {
    { map = r8, ox = -960, oy = 0 },
    { map = saff, ox = -1600, oy = -128 },
  },
}
local route8HandoffKey = Horizon._canonicalAddress(route8Handoff)
local lavenderHandoffKey = Horizon._canonicalAddress(lavenderHandoff)
eq(route8HandoffKey, lavenderHandoffKey,
   "Route 8/Lavender three-map handoff missed the horizon cache")

-- A contradictory mod cycle must never alias a valid world-space cache.
local brokenA = def("A", 1, 1, {
  east = { map = "B", offset = 0 },
  south = { map = "C", offset = 0 },
})
local brokenB = def("B", 1, 1, {
  west = { map = "A", offset = 0 },
  south = { map = "C", offset = 1 },
})
local brokenC = def("C", 1, 1)
local broken = { A = brokenA, B = brokenB, C = brokenC }
cache.WorldPlacement.invalidate()
eq(cache.WorldPlacement.position("A", broken), nil,
   "inconsistent connection cycle was treated as canonical")

truthy(key4:find("world", 1, true), "canonical cache key lacks world marker")
print("horizon connection re-root: ok")
