local cache = {}
local meshReleases, meshCreates = 0, 0
local runnerLove = love
local settingValue = "full"

local function trackedMesh()
  meshCreates = meshCreates + 1
  local mesh = { released = false }
  function mesh:release()
    if self.released then error("horizon mesh released twice") end
    self.released = true
    meshReleases = meshReleases + 1
  end
  return mesh
end

local V = { path = "." }
function V.require(name)
  if cache[name] then return cache[name] end
  if name == "WorldPlacement" then
    cache[name] = assert(loadfile("lib/WorldPlacement.lua"))(V)
  elseif name == "ModSetting" then
    cache[name] = {
      new = function()
        return { get = function() return settingValue end }
      end,
    }
  elseif name == "Voxel3D" then
    cache[name] = {
      FACE_SHADE = { 1, 1, 1, 1, 1, 1 },
      newMesh = trackedMesh,
    }
  else
    cache[name] = {}
  end
  return cache[name]
end

package.preload["src.render.TileRenderer"] = function()
  return { voidFill = "trees" }
end

local function noop() end
love = { graphics = {} }
local g = love.graphics
for _, name in ipairs({ "clear", "draw", "origin", "pop", "push",
                        "rectangle", "setBlendMode", "setCanvas",
                        "setColor" }) do
  g[name] = noop
end
local dimensions = {
  ["forest_edge_a.compact.png"] = { 128, 96 },
  ["forest_edge_b.compact.png"] = { 128, 96 },
  ["forest_edge_c.compact.png"] = { 128, 96 },
  ["viridian_town.compact.png"] = { 512, 96 },
  ["metropolis.compact.png"] = { 512, 96 },
  ["route8_horizon.compact.png"] = { 960, 96 },
  ["route8_midground.compact.png"] = { 256, 64 },
  ["rural_edge.compact.png"] = { 512, 128 },
  ["harbor_edge.compact.png"] = { 512, 128 },
  ["mini_trees.compact.png"] = { 128, 64 },
}
function g.newImage(path)
  local d = dimensions[path:match("([^/]+)$")]
  if not d then error("unexpected horizon source: " .. path) end
  local image = {}
  function image:getDimensions() return d[1], d[2] end
  image.setFilter, image.setMipmapFilter, image.release = noop, noop, noop
  return image
end
function g.newCanvas()
  local canvas = {}
  canvas.setFilter, canvas.setMipmapFilter, canvas.setWrap = noop, noop, noop
  canvas.release = noop
  return canvas
end

local Horizon = assert(loadfile("lib/HorizonWall.lua"))(V)
local blockAffectsGeometry = Horizon.blockAffectsGeometry
if type(blockAffectsGeometry) ~= "function" then
  error("horizon block-affect predicate is unavailable")
end
local blockMap = { def = { width = 8, height = 6 } }
if blockAffectsGeometry(blockMap, 3, 2) then
  error("an interior Cut block invalidated the horizon union")
end
for _, p in ipairs({ { 0, 2 }, { 7, 2 }, { 3, 0 }, { 3, 5 } }) do
  if not blockAffectsGeometry(blockMap, p[1], p[2]) then
    error("an outer block edit did not invalidate horizon geometry")
  end
end
if not blockAffectsGeometry(nil, 3, 2) then
  error("unknown map metadata did not fail closed")
end

local world, states = {}, {}
for i = 1, 40 do
  local id = "PENDING_" .. i
  local def = { id = id, width = 1, height = 1, tileset = "OVERWORLD",
                outdoor = true, connections = {} }
  world[id] = def
  states[i] = {
    map = { id = id, def = def, tileset = {} },
    neighbors = {}, worldMaps = world,
  }
end

local initial = Horizon.buildStatus()
local coldProbe = Horizon.cacheStatus(states[1])
if coldProbe.ready or coldProbe.pending or coldProbe.resumes ~= 0
   or coldProbe.maps ~= 1 then
  error("passive horizon probe misreported a cold state")
end
local afterProbe = Horizon.buildStatus()
if afterProbe.ready ~= initial.ready or afterProbe.pending ~= initial.pending then
  error("passive horizon probe created or advanced a cache job")
end

-- Leave every tiny union suspended immediately after its first allocated mesh
-- part. The exact number of geometry yields is deliberately not hard-coded:
-- adding a budgeted corner or ceiling must not weaken this lifecycle test.
-- Moving on then models a player turning toward another seam before the old
-- future union completed.
for _, state in ipairs(states) do
  local before = meshCreates
  for _ = 1, 64 do
    local _, ready = Horizon.meshes(state)
    if ready then error("pending fixture completed too early") end
    if meshCreates > before then break end
  end
  if meshCreates == before then
    error("pending fixture never allocated its first mesh part")
  end
end

local status = Horizon.buildStatus()
if status.pending > Horizon.PENDING_CACHE_CAP then
  error("pending horizon jobs exceeded their hard cap")
end
if meshReleases < #states - Horizon.PENDING_CACHE_CAP then
  error("evicted pending horizon jobs leaked allocated mesh parts")
end

-- The cap must never sacrifice the key being actively requested: resume the
-- newest state until its complete two-part horizon lands.
local ready = false
for _ = 1, 20 do
  local _, done = Horizon.meshes(states[#states])
  if done then ready = true break end
end
if not ready then error("current pending horizon job was evicted or starved") end
local warmProbe = Horizon.cacheStatus(states[#states])
if not warmProbe.ready or warmProbe.pending or warmProbe.maps ~= 1 then
  error("passive horizon probe missed the completed current key")
end
if Horizon.buildStatus().pending > Horizon.PENDING_CACHE_CAP then
  error("pending cap was lost after a job completed")
end

-- A completed horizon is never a generic visual fallback for a different
-- address. The old global lastReady path flashed the previous city's bitmap
-- while this unrelated key was still building.
local foreignDef = { id = "FOREIGN_COLD", width = 1, height = 1,
                     tileset = "OVERWORLD", outdoor = true,
                     connections = {} }
world.FOREIGN_COLD = foreignDef
local foreignState = {
  map = { id = "FOREIGN_COLD", def = foreignDef, tileset = {} },
  neighbors = {}, worldMaps = world,
}
local foreignMeshes, foreignReady = Horizon.meshes(foreignState)
if foreignReady or #foreignMeshes ~= 0 then
  error("cold map borrowed an unrelated ready horizon/bitmap")
end

Horizon.invalidate()

-- Exercise the READY LRU through the actual Kanto connection component. A
-- long Route-8 approach creates progressively larger active/future unions,
-- but semanticPlan touches the three-map direct handoff every frame. That
-- exact horizon must therefore survive the churn and alias Lavender's
-- re-rooted view without allocating a single replacement mesh.
local realWorld = assert(loadfile("../gen1recomp/data/generated/maps.lua"))()
local realIds = {
  "ROUTE_8", "SAFFRON_CITY", "LAVENDER_TOWN",
  "ROUTE_5", "ROUTE_6", "ROUTE_7",
}
local realMaps = {}
for _, id in ipairs(realIds) do
  local def = assert(realWorld[id], "missing generated map " .. id)
  realMaps[id] = {
    id = id, def = def,
    tileset = { id = def.tileset, tilesPerRow = 16,
                imageWidth = 128, imageHeight = 48 },
  }
end

local function realState(rootId, ids)
  local root = assert(cache.WorldPlacement.position(rootId, realWorld))
  local neighbors = {}
  for _, id in ipairs(ids) do
    local placed = assert(cache.WorldPlacement.position(id, realWorld))
    neighbors[#neighbors + 1] = {
      map = realMaps[id], ox = placed.x - root.x, oy = placed.y - root.y,
    }
  end
  return { map = realMaps[rootId], neighbors = neighbors,
           worldMaps = realWorld }
end

local function complete(state, label)
  for _ = 1, 2048 do
    local meshes, ready = Horizon.meshes(state)
    if ready then return meshes end
  end
  error(label .. " horizon did not converge")
end

local route8Handoff = realState("ROUTE_8",
  { "SAFFRON_CITY", "LAVENDER_TOWN" })
local lavenderHandoff = realState("LAVENDER_TOWN",
  { "ROUTE_8", "SAFFRON_CITY" })
complete(route8Handoff, "Route 8 handoff")

local growing = {
  { "SAFFRON_CITY", "LAVENDER_TOWN", "ROUTE_5" },
  { "SAFFRON_CITY", "LAVENDER_TOWN", "ROUTE_5", "ROUTE_6" },
  { "SAFFRON_CITY", "LAVENDER_TOWN", "ROUTE_5", "ROUTE_6", "ROUTE_7" },
}
for i, ids in ipairs(growing) do
  complete(realState("ROUTE_8", ids), "Route 8 expansion " .. i)
  local _, retained = Horizon.meshes(route8Handoff)
  if not retained then error("active expansion evicted the direct handoff") end
end

local beforeRerootCreates = meshCreates
local beforeRerootPending = Horizon.buildStatus().pending
local probe = Horizon.cacheStatus(lavenderHandoff)
if not probe.ready or probe.pending or probe.maps ~= 3 then
  error("Lavender passive probe missed the retained Route-8 handoff")
end
local _, rerootReady = Horizon.meshes(lavenderHandoff)
if not rerootReady then error("Lavender re-root rebuilt a ready handoff") end
if meshCreates ~= beforeRerootCreates then
  error("Lavender re-root allocated replacement horizon meshes")
end
if Horizon.buildStatus().pending ~= beforeRerootPending then
  error("Lavender re-root scheduled a duplicate horizon job")
end

-- A block edit/reload invalidates only unions containing that map.  Keep an
-- unrelated warm horizon beside the real Route-8 handoff, drop Route 8 and
-- prove the unrelated mesh survives without one replacement allocation.
complete(states[#states], "unrelated selective-invalidation fixture")
complete(route8Handoff, "Route 8 selective-invalidation fixture")
local unrelatedProbe = Horizon.cacheStatus(states[#states])
local route8Probe = Horizon.cacheStatus(route8Handoff)
if not unrelatedProbe.ready or not route8Probe.ready then
  error("selective-invalidation fixtures were not simultaneously warm")
end
local beforeSelectiveCreates, beforeSelectiveReleases =
  meshCreates, meshReleases
if not Horizon.invalidateMap("ROUTE_8") then
  error("map-scoped invalidation missed a ready Route-8 union")
end
if Horizon.cacheStatus(route8Handoff).ready then
  error("map-scoped invalidation retained stale Route-8 geometry")
end
if not Horizon.cacheStatus(states[#states]).ready then
  error("map-scoped invalidation discarded an unrelated ready horizon")
end
local _, unrelatedReady = Horizon.meshes(states[#states])
if not unrelatedReady or meshCreates ~= beforeSelectiveCreates then
  error("unrelated horizon rebuilt after a selective map invalidation")
end
if meshReleases <= beforeSelectiveReleases then
  error("selective map invalidation leaked its affected ready meshes")
end

Horizon.invalidate()

-- A deterministic error after one successful allocation used to remove the
-- pending job and recreate it on every later meshes() call. Pin that exact
-- stateKey as a negative result: the partial mesh is released once, thousands
-- of probes allocate nothing, and only invalidate() permits one new attempt.
local faultCalls = 0
local function faultMesh()
  faultCalls = faultCalls + 1
  if faultCalls % 2 == 0 then return nil end
  return trackedMesh()
end
cache.Voxel3D.newMesh = faultMesh

local function driveInjectedFailure(label)
  for _ = 1, 256 do
    local meshes, ready, failed = Horizon.meshes(states[1])
    if ready then error(label .. " unexpectedly completed") end
    if failed then
      if #meshes ~= 0 then error(label .. " exposed a partial horizon") end
      return
    end
  end
  error(label .. " did not reach its terminal failure state")
end

local beforeFaultCreates, beforeFaultReleases = meshCreates, meshReleases
driveInjectedFailure("first injected build")
if faultCalls ~= 2 or meshCreates ~= beforeFaultCreates + 1 then
  error("first injected build did not stop after its single partial mesh")
end
if meshReleases ~= beforeFaultReleases + 1 then
  error("failed horizon did not release its partial mesh exactly once")
end
local failedStatus = Horizon.buildStatus()
if failedStatus.failed ~= 1 or failedStatus.pending ~= 0 then
  error("failed horizon remained pending or missed its negative cache")
end
local failedProbe = Horizon.cacheStatus(states[1])
if not failedProbe.failed or failedProbe.ready or failedProbe.pending then
  error("passive probe misreported the terminal horizon failure")
end

local settledCalls = faultCalls
local settledCreates, settledReleases = meshCreates, meshReleases
for _ = 1, 5000 do
  local meshes, ready, failed = Horizon.meshes(states[1])
  if ready or not failed or #meshes ~= 0 then
    error("negative horizon cache returned a non-terminal answer")
  end
end
if faultCalls ~= settledCalls or meshCreates ~= settledCreates
   or meshReleases ~= settledReleases then
  error("negative horizon cache rebuilt or re-released per frame")
end
if Horizon.buildStatus().pending ~= 0 then
  error("negative horizon cache recreated a pending job")
end
if Horizon.invalidateMap(states[2].map.id) then
  error("an unrelated map invalidation cleared another key's failure")
end
if not Horizon.cacheStatus(states[1]).failed then
  error("unrelated map invalidation lost the exact terminal failure")
end

-- The terminal marker is exact-key local, not a global graphics-disable
-- latch. Another state can still complete while the failed key remains
-- allocation-free and terminal.
cache.Voxel3D.newMesh = trackedMesh
local otherReady = false
for _ = 1, 64 do
  local _, ready = Horizon.meshes(states[2])
  if ready then otherReady = true break end
end
if not otherReady then error("one failed key blocked an unrelated horizon") end
local _, firstReady, firstFailed = Horizon.meshes(states[1])
if firstReady or not firstFailed then
  error("building another key cleared the exact terminal failure")
end
cache.Voxel3D.newMesh = faultMesh

-- A map-scoped edit is also a retry boundary for a failed key containing
-- that map, while the unrelated ready state above remains warm.
local beforeMapRetryCalls = faultCalls
local beforeMapRetryCreates, beforeMapRetryReleases =
  meshCreates, meshReleases
if not Horizon.invalidateMap(states[1].map.id) then
  error("map-scoped invalidation missed its terminal failed key")
end
if Horizon.buildStatus().failed ~= 0 or Horizon.cacheStatus(states[1]).failed then
  error("map-scoped invalidation did not clear its exact failed key")
end
if not Horizon.cacheStatus(states[2]).ready then
  error("failed-key invalidation discarded an unrelated ready key")
end
driveInjectedFailure("post-map-invalidate build")
if faultCalls ~= beforeMapRetryCalls + 2
   or meshCreates ~= beforeMapRetryCreates + 1
   or meshReleases ~= beforeMapRetryReleases + 1 then
  error("map-scoped retry did not make exactly one fresh failed attempt")
end

Horizon.invalidate()
if Horizon.buildStatus().failed ~= 0 or Horizon.cacheStatus(states[1]).failed then
  error("Horizon.invalidate did not clear terminal state failures")
end
local postInvalidateCreates, postInvalidateReleases = meshCreates, meshReleases
local postInvalidateCalls = faultCalls
driveInjectedFailure("post-invalidate build")
if faultCalls ~= postInvalidateCalls + 2
   or meshCreates ~= postInvalidateCreates + 1 then
  error("invalidate did not permit exactly one fresh build attempt")
end
if meshReleases ~= postInvalidateReleases + 1 then
  error("post-invalidate failure leaked or double-released its partial mesh")
end

-- FULL/OFF/FULL is an explicit failure epoch even when no pipeline
-- invalidate callback runs (the mod manager writes the setting directly).
-- OFF must clear the terminal key without allocating; returning to FULL is a
-- cold key and allows exactly one new attempt.
settingValue = "off"
local offMeshes, offReady, offFailed = Horizon.meshes(states[1])
if not offReady or offFailed or #offMeshes ~= 0
   or Horizon.buildStatus().failed ~= 0 then
  error("SCENERY OFF did not end the previous terminal failure epoch")
end
settingValue = "full"
local fullProbe = Horizon.cacheStatus(states[1])
if fullProbe.ready or fullProbe.pending or fullProbe.failed then
  error("SCENERY FULL reused state from the prior setting epoch")
end
local beforeSettingCalls = faultCalls
local beforeSettingCreates, beforeSettingReleases = meshCreates, meshReleases
driveInjectedFailure("post-setting-epoch build")
if faultCalls ~= beforeSettingCalls + 2
   or meshCreates ~= beforeSettingCreates + 1
   or meshReleases ~= beforeSettingReleases + 1 then
  error("setting epoch did not permit exactly one fresh failed attempt")
end

local mainFile = assert(io.open("main.lua", "rb"))
local mainSource = mainFile:read("*a")
mainFile:close()
local _, mapInvalidationHooks =
  mainSource:gsub("HorizonWall%.invalidateMap%([^%)]+%)", "")
if mapInvalidationHooks < 3 then
  error("block replacement/setBlock/map reload are not all horizon-aware")
end

Horizon.invalidate()
cache.Voxel3D.newMesh = trackedMesh
love = runnerLove
print(("horizon pending cache: %d releases, cap %d")
  :format(meshReleases, Horizon.PENDING_CACHE_CAP))
