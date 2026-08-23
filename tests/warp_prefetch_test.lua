local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected "
      .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local requests, loads = {}, {}
local active, preload, semantic = true, false, true
local mapById = {}
local readyById = {}

package.preload["src.world.MapLoader"] = function()
  return {
    load = function(data, id)
      loads[#loads + 1] = { data = data, id = id }
      local map = { id = id, def = { tileset = "OVERWORLD" } }
      mapById[id] = map
      return map
    end,
  }
end

local modules = {
  ChunkMesher = {
    preloadSetting = { get = function() return preload end },
    request = function(map, bodyOnly, masks, urgent)
      requests[#requests + 1] = {
        map = map, bodyOnly = bodyOnly, masks = masks, urgent = urgent,
      }
    end,
    ready = function(map) return readyById[map.id] == true end,
  },
  HorizonWall = { preferBody = function() return semantic end },
  VoxelState = { active = function() return active end },
}
local V = { require = function(name) return assert(modules[name], name) end }
local Prefetch = assert(loadfile("lib/WarpPrefetch.lua"))(V)

local originalCalls = {}
local ow = {}
function ow:startWarpTo(mapId, x, y, facing, onDone, opts)
  originalCalls[#originalCalls + 1] = {
    self = self, mapId = mapId, x = x, y = y, facing = facing,
    onDone = onDone, opts = opts,
  }
  return "warp", nil, 17
end
local original = ow.startWarpTo
local game = { overworld = ow, data = { marker = "game-data" } }

eq(Prefetch.install(game), true, "install")
local wrapper = ow.startWarpTo
eq(Prefetch.install(game), true, "idempotent install")
eq(ow.startWarpTo, wrapper, "wrapper stacked")

local done, opts = function() end, { via = "fly" }
local a, b, c = ow:startWarpTo("SAFFRON_CITY", 9, 12, "up", done, opts)
eq(a, "warp", "first return")
eq(b, nil, "nil return")
eq(c, 17, "last return")
eq(#originalCalls, 1, "original call count")
eq(originalCalls[1].self, ow, "self")
eq(originalCalls[1].mapId, "SAFFRON_CITY", "map id")
eq(originalCalls[1].onDone, done, "onDone")
eq(originalCalls[1].opts, opts, "options")
eq(#loads, 0, "startWarpTo did map-loading work")
eq(#requests, 0, "startWarpTo queued meshing directly")
eq(Prefetch.update(game, false), false, "uncovered update")
eq(#loads, 0, "uncovered destination load")
eq(Prefetch.update(game, true), true, "covered prefetch")
eq(#loads, 1, "destination load count")
eq(loads[1].data, game.data, "game data")
eq(loads[1].id, "SAFFRON_CITY", "loaded destination")
eq(#requests, 1, "request count")
eq(requests[1].map, mapById.SAFFRON_CITY, "requested map")
eq(requests[1].bodyOnly, true, "body-only")
eq(requests[1].masks, nil, "unexpected masks")
eq(requests[1].urgent, true, "not urgent")
eq(Prefetch.update(game, true), true, "warming hint vanished")
readyById.SAFFRON_CITY = true
eq(Prefetch.update(game, true), false, "ready warming hint retained")

-- Protected OFF means neither VASC mode nor PRELOAD may touch the target.
active, preload = false, false
ow:startWarpTo("ROUTE_8", 1, 2, "left")
eq(Prefetch.update(game, true), false, "disabled prefetch")
eq(#loads, 1, "disabled map load")
eq(#requests, 1, "disabled mesh request")

-- PRELOAD is an explicit opt-in even while the live camera is off.
preload = true
ow:startWarpTo("ROUTE_7", 3, 4, "right")
eq(Prefetch.update(game, true), true, "preload setting")
eq(#requests, 2, "preload request")

-- Interiors retain their normal full-map path after the midpoint.
active, preload, semantic = true, false, false
ow:startWarpTo("OAKS_LAB", 4, 5, "down")
eq(Prefetch.update(game, true), false, "interior prefetch")
eq(#loads, 3, "interior was not classified")
eq(#requests, 2, "interior mesh queued")

-- Never overwrite a marker whose wrapper no longer owns startWarpTo.
local foreign = { startWarpTo = original }
foreign[Prefetch.MARKER] = { owner = "ANOTHER_MOD", wrapper = original }
local foreignGame = { overworld = foreign, data = {} }
eq(Prefetch.install(foreignGame), false, "foreign marker accepted")
eq(foreign.startWarpTo, original, "foreign function overwritten")

print("warp destination prefetch: ok")
