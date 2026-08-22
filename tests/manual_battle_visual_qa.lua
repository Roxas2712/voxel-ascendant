-- QA-only native screenshot receipt for Voxel Ascendant staged battles.
--
-- This enters the selected QA save through the panorama audit's guarded
-- title bootstrap, starts an ordinary Pallet wild battle, then records the
-- real presented framebuffer at every legal camera composition. MAP/DISCS
-- cover 1X, 2X and 3X; authored ARENA covers its fixed 3X master and its
-- optional Stadium director without ever moving to a different distance rung.

local function fail(phase, reason, extra)
  error(("VASC_BATTLE_QA_FAIL phase=%s reason=%s%s"):format(
    tostring(phase), tostring(reason),
    extra and (" " .. tostring(extra)) or ""), 0)
end

local function envInt(env, name, fallback, minimum)
  local raw = env(name)
  if raw == nil or raw == "" then return fallback end
  local value = tonumber(raw)
  if not value or value ~= math.floor(value) or value < (minimum or 0) then
    fail("config", "invalid-number", "key=" .. name .. " value=" .. raw)
  end
  return value
end

local function relativePath(value)
  if type(value) ~= "string" or value == "" then return false end
  if value:sub(1, 1) == "/" or value:match("^%a:[/\\]") then return false end
  if value:find("\\", 1, true) or value:find("//", 1, true) then return false end
  for part in value:gmatch("[^/]+") do
    if part == "." or part == ".." or part == "" then return false end
  end
  return true
end

local function leafName(value)
  return type(value) == "string" and value:match("^[A-Za-z0-9._-]+$") ~= nil
end

local function dataId(value)
  return type(value) == "string" and value:match("^[A-Z0-9_]+$") ~= nil
end

local function oneOf(value, allowed)
  for _, candidate in ipairs(allowed) do
    if value == candidate then return true end
  end
  return false
end

local function configFromEnv(env)
  env = env or os.getenv
  local out = env("VASC_BATTLE_QA_OUT") or "qa/visual-reset"
  local runId = env("VASC_BATTLE_QA_RUN_ID") or "battle-map"
  local map = env("VASC_BATTLE_QA_MAP") or "PALLET_TOWN"
  local species = env("VASC_BATTLE_QA_SPECIES") or "RATTATA"
  local stage = env("VASC_BATTLE_QA_STAGE") or "MAP"
  local daytime = env("VASC_BATTLE_QA_DAYTIME") or "AUTO"
  if not relativePath(out) then fail("config", "unsafe-output", out) end
  if not leafName(runId) or runId == "." or runId == ".." then
    fail("config", "unsafe-run-id", runId)
  end
  if not dataId(map) then fail("config", "unsafe-map", map) end
  if not dataId(species) then fail("config", "unsafe-species", species) end
  if stage ~= "MAP" and stage ~= "ARENA" and stage ~= "DISCS" then
    fail("config", "unsafe-stage", stage)
  end
  if not oneOf(daytime, { "AUTO", "DAWN", "DAY", "DUSK", "NIGHT" }) then
    fail("config", "unsafe-daytime", daytime)
  end
  local hold = envInt(env, "VASC_BATTLE_QA_HOLD", 0, 0)
  if hold ~= 0 and hold ~= 1 then
    fail("config", "invalid-hold", tostring(hold))
  end
  return {
    root = out .. "/" .. runId,
    map = map,
    x = envInt(env, "VASC_BATTLE_QA_X", 10, 0),
    y = envInt(env, "VASC_BATTLE_QA_Y", 12, 0),
    species = species,
    stage = stage,
    daytime = daytime,
    hold = hold == 1,
    level = envInt(env, "VASC_BATTLE_QA_LEVEL", 3, 1),
    stable = envInt(env, "VASC_BATTLE_QA_STABLE_FRAMES", 30, 2),
    timeout = envInt(env, "VASC_BATTLE_QA_TIMEOUT_FRAMES", 1800, 1),
    captureTimeout = envInt(
      env, "VASC_BATTLE_QA_CAPTURE_TIMEOUT_FRAMES", 300, 1),
  }
end

local PNG_MAGIC = "\137PNG\r\n\26\n"
local PNG_END = "IEND\174B\096\130"
local function completePNG(bytes)
  return type(bytes) == "string" and #bytes > 20
    and bytes:sub(1, #PNG_MAGIC) == PNG_MAGIC
    and bytes:sub(-#PNG_END) == PNG_END
end

local function globalPendingDiagnostics(Mesher, Horizon)
  local out = { mesher = -1, horizon = -1 }
  if type(Mesher) == "table" and type(Mesher.pending) == "function" then
    local ok, value = pcall(Mesher.pending)
    if ok and type(value) == "number" and value >= 0
       and value == math.floor(value) then out.mesher = value end
  end
  if type(Horizon) == "table" and type(Horizon.buildStatus) == "function" then
    local ok, status = pcall(Horizon.buildStatus)
    local value = ok and type(status) == "table" and status.pending or nil
    if type(value) == "number" and value >= 0
       and value == math.floor(value) then out.horizon = value end
  end
  return out
end

local function presentedShotReady(top, arena, shot, expectedMap)
  if type(arena) ~= "table" or type(arena.map) ~= "table"
     or arena.map.id ~= expectedMap then
    return false, "arena-not-ready"
  end
  if type(shot) ~= "table" or shot.canvas == nil then
    return false, "shot-not-ready"
  end
  local presented = type(top) == "table" and top.voxelAscendantShot or nil
  if type(presented) ~= "table" or presented.canvas == nil then
    return false, "shot-not-presented"
  end
  if presented.canvas ~= shot.canvas then
    return false, "presented-canvas-mismatch"
  end
  return true
end

-- Reconstruct the exact immutable active plan advertised by VoxelScene's
-- passive QA receipt, then ask HorizonWall about that one canonical key.  A
-- global pending count cannot answer this question: deliberately retained
-- future-union jobs may remain suspended until their exact key is requested
-- again.  cacheStatus neither creates nor advances work.
local function exactPlanReceipt(Scene, Horizon, ow, expectedMap)
  if type(Scene) ~= "table" or type(Scene.planStatus) ~= "function" then
    return nil, "plan-status-api-unavailable"
  end
  if type(Horizon) ~= "table" or type(Horizon.cacheStatus) ~= "function" then
    return nil, "horizon-cache-api-unavailable"
  end
  if type(ow) ~= "table" or type(ow.map) ~= "table"
     or ow.map.id ~= expectedMap then
    return nil, "plan-map-unavailable"
  end
  local okPlan, status = pcall(Scene.planStatus)
  local active = okPlan and type(status) == "table" and status.active or nil
  if type(active) ~= "table" or active.rootId ~= expectedMap
     or type(active.ids) ~= "table" then
    return nil, "active-plan-malformed"
  end
  local wanted, count = {}, 0
  for index, id in ipairs(active.ids) do
    if type(id) ~= "string" or id == "" or wanted[id] then
      return nil, "active-plan-malformed"
    end
    wanted[id], count = true, count + 1
    if index ~= count then return nil, "active-plan-malformed" end
  end
  if count == 0 or not wanted[expectedMap] then
    return nil, "active-plan-missing-root"
  end
  local neighbors, seen = {}, { [expectedMap] = true }
  for _, nb in ipairs(ow.neighbors or {}) do
    local id = nb and nb.map and nb.map.id
    if wanted[id] then
      if seen[id] then return nil, "active-plan-duplicate-map" end
      seen[id] = true
      neighbors[#neighbors + 1] = nb
    end
  end
  for id in pairs(wanted) do
    if not seen[id] then return nil, "active-plan-member-unavailable" end
  end
  local planState = {
    map = ow.map, neighbors = neighbors, worldMaps = ow.worldMaps,
  }
  local okCache, cache = pcall(Horizon.cacheStatus, planState)
  if not okCache or type(cache) ~= "table" or cache.enabled ~= true
     or type(cache.key) ~= "string" or cache.key == ""
     or type(cache.maps) ~= "number" or cache.maps ~= count
     or type(cache.ready) ~= "boolean" or type(cache.pending) ~= "boolean"
     or type(cache.failed) ~= "boolean" then
    return nil, "active-horizon-cache-malformed"
  end
  if cache.failed then return nil, "active-horizon-failed" end
  if cache.pending or not cache.ready then return nil, "active-horizon-pending" end
  return { key = cache.key, maps = cache.maps, ids = active.ids }
end

local function sameReceiptIdentity(a, b)
  return type(a) == "table" and type(b) == "table"
    and a.planKey == b.planKey and a.canvas == b.canvas and a.arena == b.arena
end

local function privateUpvalue(fn, wanted, seen, depth)
  if not (debug and type(debug.getupvalue) == "function"
          and type(fn) == "function") then return nil end
  seen, depth = seen or {}, depth or 0
  if seen[fn] or depth > 5 then return nil end
  seen[fn] = true
  for index = 1, 96 do
    local name, value = debug.getupvalue(fn, index)
    if not name then break end
    if name == wanted then return value end
  end
  for index = 1, 96 do
    local name, value = debug.getupvalue(fn, index)
    if not name then break end
    if type(value) == "function" then
      local hit = privateUpvalue(value, wanted, seen, depth + 1)
      if hit ~= nil then return hit end
    end
  end
  return nil
end

local function siblingPath(name)
  local info = debug and debug.getinfo and debug.getinfo(1, "S") or nil
  local source = tostring(info and info.source or "")
  if source:sub(1, 1) == "@" then source = source:sub(2) end
  local dir = source:match("^(.*)[/\\][^/\\]+$")
  if not dir then fail("boot", "driver-directory-unavailable") end
  return dir .. "/" .. name
end

local function panoramaBootstrapHelpers()
  local previous = rawget(_G, "VASC_PANORAMA_AUDIT_TEST")
  _G.VASC_PANORAMA_AUDIT_TEST = true
  local chunk, loadError = loadfile(siblingPath("manual_panorama_audit.lua"))
  if not chunk then
    _G.VASC_PANORAMA_AUDIT_TEST = previous
    fail("boot", "panorama-bootstrap-load", loadError)
  end
  local ok, helpers = pcall(chunk)
  _G.VASC_PANORAMA_AUDIT_TEST = previous
  if not ok or type(helpers) ~= "table"
     or type(helpers.newQAContinueBootstrap) ~= "function" then
    fail("boot", "panorama-bootstrap-unavailable", ok and "shape" or helpers)
  end
  return helpers
end

local function run(game)
  if tonumber(os.getenv("POKEPORT_SPEED") or "1") ~= 1 then
    fail("config", "speed-must-be-one")
  end
  local config = configFromEnv(os.getenv)
  local helpers = panoramaBootstrapHelpers()
  local bootstrap = helpers.newQAContinueBootstrap(game, os.getenv, {
    continueLabel = require("src.core.Strings")("CONTINUE"),
  })
  while not bootstrap:step() do coroutine.yield() end

  local fs, graphics, event = love and love.filesystem,
    love and love.graphics, love and love.event
  if not (fs and type(fs.createDirectory) == "function"
          and type(fs.getInfo) == "function" and type(fs.read) == "function"
          and type(fs.remove) == "function") then
    fail("boot", "filesystem-unavailable")
  end
  if not (graphics and type(graphics.captureScreenshot) == "function") then
    fail("boot", "captureScreenshot-unavailable")
  end
  if not (event and type(event.quit) == "function") then
    fail("boot", "quit-unavailable")
  end
  if not fs.createDirectory(config.root) then fail("boot", "mkdir", config.root) end

  local id = "VOXEL_ASCENDANT"
  local values = {
    battles = true, battleCameraDistance = 1, trainerBack = false,
    battleBack = false, sky = "full", weather = "clear", shadows = false,
  }
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions[id] = values
  game.mods.modOptions = game.mods.modOptions or {}
  game.mods.modOptions[id] = values
  local Runtime = require("src.mods.Runtime")
  local function rows()
    return Runtime.call("ui.options.rows", function(_, base) return base end,
                        game, {})
  end
  local function selectValue(key, wanted)
    local matched
    for _, row in ipairs(rows() or {}) do
      if row.id == id .. ":" .. key then
        matched = row
        for _ = 1, 12 do
          if row.value(game) == wanted then break end
          row.step(game, 1)
        end
        if row.value(game) ~= wanted then
          fail("options", "value-unreachable", "key=" .. key
            .. " wanted=" .. wanted .. " got=" .. tostring(row.value(game)))
        end
      end
    end
    if not matched then fail("options", "row-missing", "key=" .. key) end
    return matched
  end

  selectValue("battles", config.stage)
  local distanceRow, arenaCameraRow
  if config.stage == "ARENA" then
    arenaCameraRow = selectValue("arenaCamera", "3X")
  else
    distanceRow = selectValue("battleCameraDistance", "1X")
  end
  selectValue("trainerBack", "OFF")
  selectValue("battleBack", "OFF")
  selectValue("weather", "CLEAR")
  selectValue("shadows", "OFF")
  selectValue("sky", "FULL")
  selectValue("daytime", config.daytime)

  local ow = game.overworld
  if not (ow and type(ow.setMap) == "function") then
    fail("boot", "overworld-unavailable")
  end
  if not (game.data and game.data.maps and game.data.maps[config.map]) then
    fail("config", "unknown-map", config.map)
  end
  local okMap = pcall(ow.setMap, ow, config.map, config.x, config.y, "up")
  if not okMap then
    fail("map", "set-map-failed",
         "map=" .. config.map .. " x=" .. config.x .. " y=" .. config.y)
  end
  for _ = 1, 10 do coroutine.yield() end
  if game.stack:top() ~= ow or not ow.map or ow.map.id ~= config.map then
    fail("map", "target-not-presented", config.map)
  end
  if not (ow.map.inBounds and ow.map:inBounds(config.x, config.y)) then
    fail("config", "cell-out-of-bounds",
         "map=" .. config.map .. " x=" .. config.x .. " y=" .. config.y)
  end

  local exports = game.mods and game.mods.exports and game.mods.exports[id]
  local lib = exports and exports.lib
  local Scene = lib and lib.require and lib.require("VoxelScene")
  local OverworldBattle = lib and lib.require and lib.require("OverworldBattle")
  if not (Scene and type(Scene.prefetch) == "function"
          and type(Scene.planStatus) == "function"
          and OverworldBattle and type(OverworldBattle.arena) == "function"
          and type(OverworldBattle.shot) == "function") then
    fail("boot", "battle-public-api-unavailable")
  end
  -- QA-only observation of the exact module tables already captured by the
  -- exported VoxelScene.  Production's public facade remains unchanged.
  local Mesher = privateUpvalue(Scene.prefetch, "ChunkMesher")
  local Horizon = privateUpvalue(Scene.prefetch, "HorizonWall")
  if not (Horizon and type(Horizon.cacheStatus) == "function") then
    fail("boot", "horizon-cache-api-unavailable")
  end

  local okBattle, battle = pcall(function()
    return require("src.battle.BattleState").newWild(
      game, config.species, config.level, { onFinish = function() end })
  end)
  if not okBattle or type(battle) ~= "table" then
    fail("config", "battle-construction-failed",
         "species=" .. config.species .. " level=" .. config.level)
  end
  ow:pushBattle(battle)
  print(("VASC_BATTLE_QA_STARTED map=%s stage=%s x=%d y=%d species=%s level=%d")
    :format(config.map, config.stage, config.x, config.y,
      config.species, config.level))

  local frame = 0
  local function tick() frame = frame + 1; coroutine.yield() end
  local function currentReceipt()
    local arena, shot = OverworldBattle.arena(), OverworldBattle.shot()
    local ok, reason = presentedShotReady(
      game.stack:top(), arena, shot, config.map)
    if not ok then return nil, reason end
    local plan, planReason = exactPlanReceipt(
      Scene, Horizon, ow, config.map)
    if not plan then return nil, planReason end
    return {
      arena = arena, canvas = shot.canvas,
      planKey = plan.key, planMaps = plan.maps,
    }
  end
  local function receipt(distance)
    local stable, lastReason = 0, "not-checked"
    local previous
    for _ = 1, config.timeout do
      tick()
      local cameraRow = config.stage == "ARENA"
                        and arenaCameraRow or distanceRow
      if tostring(cameraRow.value(game)) ~= distance then
        fail("ready", "camera-distance-drift", "wanted=" .. distance
          .. " got=" .. tostring(cameraRow.value(game)))
      end
      local current, reason = currentReceipt()
      local ok = current ~= nil
      if ok and sameReceiptIdentity(current, previous) then
        stable = stable + 1
      elseif ok then
        stable = 1
      else
        stable = 0
      end
      lastReason = ok and (stable == 1 and "plan-or-shot-identity-changing"
                           or "ready") or reason
      previous = ok and current or nil
      if stable >= config.stable then
        local pending = globalPendingDiagnostics(Mesher, Horizon)
        print(("VASC_BATTLE_QA_READY map=%s distance=%s stable=%d frame=%d "
               .. "arena=1 shot=1 presented=1 plan_maps=%d plan_key=%s "
               .. "global_mesher_pending=%d global_horizon_pending=%d")
          :format(config.map, distance, stable, frame, current.planMaps,
            current.planKey, pending.mesher, pending.horizon))
        return current
      end
    end
    fail("ready", "timeout", "distance=" .. distance
      .. " last=" .. tostring(lastReason) .. " frame=" .. frame)
  end

  local function capture(distance)
    local locked = receipt(distance)
    local path = config.root .. "/" .. config.map .. "-" .. config.stage .. "-"
      .. distance .. ".png"
    if fs.getInfo(path) and not fs.remove(path) then
      fail("capture", "stale-output-not-removable", path)
    end
    graphics.captureScreenshot(path)
    for _ = 1, config.captureTimeout do
      tick()
      local current, reason = currentReceipt()
      if not current then
        fs.remove(path); fail("capture", reason, "distance=" .. distance)
      end
      if not sameReceiptIdentity(current, locked) then
        fs.remove(path)
        fail("capture", "plan-or-shot-identity-changed",
             "distance=" .. distance)
      end
      local info = fs.getInfo(path, "file")
      if info and (info.size or 0) > 0 then
        local bytes = fs.read(path)
        if not completePNG(bytes) then
          fs.remove(path); fail("capture", "incomplete-png", "distance=" .. distance)
        end
        local pending = globalPendingDiagnostics(Mesher, Horizon)
        print(("VASC_BATTLE_QA_CAPTURE map=%s distance=%s plan_maps=%d "
               .. "plan_key=%s global_mesher_pending=%d "
               .. "global_horizon_pending=%d path=%s bytes=%d frame=%d")
          :format(config.map, distance, locked.planMaps, locked.planKey,
            pending.mesher, pending.horizon, path, #bytes, frame))
        return path
      end
    end
    fs.remove(path); fail("capture", "encoder-timeout", "distance=" .. distance)
  end

  if config.stage == "ARENA" then
    local fixed = capture("3X")
    arenaCameraRow = selectValue("arenaCamera", "STADIUM")
    local stadium = capture("STADIUM")
    print(("VASC_BATTLE_QA_DONE captures=2 fixed=%s stadium=%s frame=%d")
      :format(fixed, stadium, frame))
  else
    local first = capture("1X")
    distanceRow = selectValue("battleCameraDistance", "2X")
    local middle = capture("2X")
    distanceRow = selectValue("battleCameraDistance", "3X")
    local wide = capture("3X")
    print(("VASC_BATTLE_QA_DONE captures=3 first=%s middle=%s wide=%s frame=%d")
      :format(first, middle, wide, frame))
  end
  pcall(io.stdout.flush, io.stdout)
  if config.hold then
    print(("VASC_BATTLE_QA_DEMO_READY map=%s stage=%s daytime=%s frame=%d")
      :format(config.map, config.stage, config.daytime, frame))
    pcall(io.stdout.flush, io.stdout)
    while true do coroutine.yield() end
  end
  event.quit(0)
  while true do coroutine.yield() end
end

if rawget(_G, "VASC_BATTLE_VISUAL_QA_TEST") then
  return {
    configFromEnv = configFromEnv, relativePath = relativePath,
    completePNG = completePNG,
    globalPendingDiagnostics = globalPendingDiagnostics,
    exactPlanReceipt = exactPlanReceipt,
    sameReceiptIdentity = sameReceiptIdentity,
    presentedShotReady = presentedShotReady,
  }
end
return run
