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
  local playerSpecies = env("VASC_BATTLE_QA_PLAYER_SPECIES") or ""
  local stage = env("VASC_BATTLE_QA_STAGE") or "MAP"
  local daytime = env("VASC_BATTLE_QA_DAYTIME") or "AUTO"
  local weather = env("VASC_BATTLE_QA_WEATHER") or "CLEAR"
  local megaForm = env("VASC_BATTLE_QA_MEGA_FORM") or ""
  if not relativePath(out) then fail("config", "unsafe-output", out) end
  if not leafName(runId) or runId == "." or runId == ".." then
    fail("config", "unsafe-run-id", runId)
  end
  if not dataId(map) then fail("config", "unsafe-map", map) end
  if not dataId(species) then fail("config", "unsafe-species", species) end
  if playerSpecies ~= "" and not dataId(playerSpecies) then
    fail("config", "unsafe-player-species", playerSpecies)
  end
  if stage ~= "MAP" and stage ~= "ARENA" and stage ~= "DISCS" then
    fail("config", "unsafe-stage", stage)
  end
  if not oneOf(daytime, { "AUTO", "DAWN", "DAY", "DUSK", "NIGHT" }) then
    fail("config", "unsafe-daytime", daytime)
  end
  if not oneOf(weather, { "CLEAR", "AUTO", "RAIN", "SNOW", "FOG", "STORM" }) then
    fail("config", "unsafe-weather", weather)
  end
  if megaForm ~= "" and not dataId(megaForm) then
    fail("config", "unsafe-mega-form", megaForm)
  end
  local hold = envInt(env, "VASC_BATTLE_QA_HOLD", 0, 0)
  if hold ~= 0 and hold ~= 1 then
    fail("config", "invalid-hold", tostring(hold))
  end
  local megaCatalog = envInt(env, "VASC_BATTLE_QA_MEGA_CATALOG", 0, 0)
  if megaCatalog ~= 0 and megaCatalog ~= 1 then
    fail("config", "invalid-mega-catalog", tostring(megaCatalog))
  end
  local monPhase = envInt(env, "VASC_BATTLE_QA_MON_PHASE", 0, 0)
  if monPhase ~= 0 and monPhase ~= 1 then
    fail("config", "invalid-mon-phase", tostring(monPhase))
  end
  if megaCatalog == 1 and monPhase ~= 1 then
    fail("config", "mega-catalog-requires-mon-phase")
  end
  return {
    root = out .. "/" .. runId,
    map = map,
    x = envInt(env, "VASC_BATTLE_QA_X", 10, 0),
    y = envInt(env, "VASC_BATTLE_QA_Y", 12, 0),
    species = species,
    playerSpecies = playerSpecies,
    stage = stage,
    daytime = daytime,
    weather = weather,
    megaForm = megaForm,
    megaCatalog = megaCatalog == 1,
    monPhase = monPhase == 1,
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

-- ARENA uses a reviewed full-frame backdrop rather than the overworld's
-- progressive map union.  Indoor maps intentionally have no active horizon
-- plan, so demanding one here makes every legitimate room time-of-day capture
-- time out after its already-presented shot is ready.  This receipt is passive:
-- the same canvas has already survived BattleScene's asserted drawBackdrop,
-- while this helper pins the exact authored style/map identity across the
-- stability and PNG-encoding windows.
local function authoredArenaReceipt(Stage, arena, expectedMap)
  if type(Stage) ~= "table"
      or type(Stage.hasAuthoredBackdrop) ~= "function" then
    return nil, "authored-backdrop-api-unavailable"
  end
  local style = type(arena) == "table" and arena.arenaStyle or nil
  if type(style) ~= "table" or style.mapId ~= expectedMap
      or type(style.id) ~= "string" or style.id == ""
      or type(style.variant) ~= "string" or style.variant == "" then
    return nil, "authored-style-malformed"
  end
  local ok, ready = pcall(Stage.hasAuthoredBackdrop, arena)
  if not ok or ready ~= true then return nil, "authored-backdrop-unavailable" end
  return {
    key = "authored:" .. expectedMap .. ":" .. style.id .. ":" .. style.variant,
    maps = 1, ids = { expectedMap },
  }
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
  selectValue("weather", config.weather)
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
  -- exported modules. Production's public facade remains unchanged: these
  -- two private owners are recovered only from functions in that closed
  -- facade, and the run fails closed if their exact receipts disappear.
  local BattleScene = privateUpvalue(OverworldBattle.update, "BattleScene")
  local BattlePics = privateUpvalue(OverworldBattle.invalidate, "BattlePics")
  local Mesher = privateUpvalue(Scene.prefetch, "ChunkMesher")
  local Horizon = privateUpvalue(Scene.prefetch, "HorizonWall")
  -- VoxelBattleStage is deliberately not part of the public compatibility
  -- facade. Recover it through BattleScene's already-captured private owner,
  -- exactly like the other QA-only receipts above, without expanding runtime
  -- exports merely to satisfy a test driver.
  local ownerV = BattleScene and privateUpvalue(BattleScene.render, "V")
  local okStage, Stage = pcall(function()
    return ownerV and ownerV.require and ownerV.require("VoxelBattleStage")
  end)
  if not (BattleScene and type(BattleScene.textureBaseline) == "function"
          and type(BattleScene.presentationMetrics) == "function"
          and BattlePics and type(BattlePics.inkBounds) == "function") then
    fail("boot", "battle-private-receipt-unavailable")
  end
  if not (okStage and Stage
          and type(Stage.hasAuthoredBackdrop) == "function") then
    fail("boot", "authored-backdrop-private-receipt-unavailable")
  end
  if not (Horizon and type(Horizon.cacheStatus) == "function") then
    fail("boot", "horizon-cache-api-unavailable")
  end

  local kanto = game.mods and game.mods.exports
    and game.mods.exports.kanto_ascendant
  local mega = kanto and kanto.megaEvolution
  local selectedMega
  if config.megaForm ~= "" or config.megaCatalog then
    if not (type(mega) == "table" and type(mega.forms) == "table"
            and type(mega.rearOverlayAllowed) == "function"
            and OverworldBattle.kantoAscendantMegaAnchorHook == true
            and type(OverworldBattle.sideTexture) == "function") then
      fail("mega", "compatibility-api-unavailable")
    end
    for _, profile in ipairs(mega.forms) do
      if type(profile) == "table" and profile.id == config.megaForm then
        selectedMega = profile
      end
    end
    if config.megaForm ~= "" and not selectedMega then
      fail("mega", "unknown-form", config.megaForm)
    end
  end

  local originalParty = game.save.party
  local okBattle, battle = pcall(function()
    if selectedMega or config.playerSpecies ~= "" then
      local mon = require("src.pokemon.Pokemon").new(
        game.data, selectedMega and selectedMega.species
          or config.playerSpecies, config.level)
      if selectedMega then mon._ascMegaForm = selectedMega.id end
      game.save.party = { mon }
    end
    return require("src.battle.BattleState").newWild(
      game, config.species, config.level, { onFinish = function() end })
  end)
  game.save.party = originalParty
  if not okBattle or type(battle) ~= "table" then
    fail("config", "battle-construction-failed",
         "species=" .. config.species .. " level=" .. config.level)
  end
  ow:pushBattle(battle)
  -- Optional QA-only stable presentation state. `pushBattle` first schedules
  -- a transition, so the battle's `enter` routine has not run here yet; the
  -- state must be applied only once that real screen owns the stack.
  local monPhaseApplied = false
  local function applyMonPhase()
    if not config.monPhase or monPhaseApplied
        or game.stack:top() ~= battle then return end
    battle.queue = {}
    battle.afterQueue = nil
    battle.phase = "menu"
    battle.introBalls = nil
    battle.introSlide = 0
    battle.showPlayerBack = false
    battle.showEnemyTrainer = false
    battle.sendingOut = false
    battle.enemySendingOut = false
    battle.enemyHidden = false
    monPhaseApplied = true
  end
  print(("VASC_BATTLE_QA_STARTED map=%s stage=%s x=%d y=%d species=%s "
         .. "player_species=%s level=%d")
    :format(config.map, config.stage, config.x, config.y,
      config.species, config.playerSpecies ~= "" and config.playerSpecies
        or (selectedMega and selectedMega.species or "SAVE_PARTY"),
      config.level))

  local frame = 0
  local megaCatalogChecked = false
  local presentationLogged = false
  local function tick()
    frame = frame + 1
    coroutine.yield()
    applyMonPhase()
  end
  local function currentReceipt()
    local arena, shot = OverworldBattle.arena(), OverworldBattle.shot()
    local ok, reason = presentedShotReady(
      game.stack:top(), arena, shot, config.map)
    if not ok then return nil, reason end
    local plan, planReason
    if config.stage == "ARENA" then
      plan, planReason = authoredArenaReceipt(Stage, arena, config.map)
    else
      plan, planReason = exactPlanReceipt(Scene, Horizon, ow, config.map)
    end
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
    if not presentationLogged then
      for _, side in ipairs({ "player", "enemy" }) do
        local battler = battle[side]
        local species = battler and battler.mon and battler.mon.species
        local registry = battle.data and battle.data.pokemon
          and battle.data.pokemon[species]
        local dex = registry and registry.dexEntry
        local texture = OverworldBattle.finalizeSideTexture(
          battle, side, OverworldBattle.sideTexture(battle, side))
        local directHeight = OverworldBattle.battlerHeightIn(battle, side)
        local identity = texture and (texture.kantoAscendantMegaSource
          or texture.inkIdentity)
        local x0, y0, x1, y1
        if texture then
          x0, y0, x1, y1 = BattlePics.inkBounds(texture.canvas, identity)
        end
        local cw, ch = 0, 0
        if texture and texture.canvas and texture.canvas.getDimensions then
          cw, ch = texture.canvas:getDimensions()
        end
        local metrics = texture and BattleScene.presentationMetrics(texture, 1)
        print(("VASC_BATTLE_QA_PRESENTATION side=%s canvas=%dx%d "
               .. "ink=%s,%s,%s,%s height_in=%s species_scale=%s "
               .. "baseline=%s reported=%s world_ink_h=%s "
               .. "combined=%s density=%s mega=%d source=%s species=%s "
               .. "registry=%d dex=%s/%s direct_height=%s trainer=%s")
          :format(side, cw, ch, tostring(x0), tostring(y0), tostring(x1),
            tostring(y1), tostring(texture and texture.heightIn),
            tostring(texture and BattleScene.speciesScale(texture)),
            tostring(texture and BattleScene.textureBaseline(texture)),
            tostring(texture and texture.ay),
            tostring(metrics and metrics.worldInkHeight),
            tostring(metrics and metrics.combinedScale),
            tostring(metrics and metrics.densityScale),
            texture and texture.kantoAscendantMegaSupersampled == true
              and 1 or 0,
            tostring(texture and texture.kantoAscendantMegaSource),
            tostring(species), registry and 1 or 0,
            tostring(dex and dex.heightFt), tostring(dex and dex.heightIn),
            tostring(directHeight), tostring(texture and texture.trainer)))
      end
      presentationLogged = true
    end
    if config.megaCatalog and not megaCatalogChecked then
      if battle.dramaticShapeShot ~= battle.voxelAscendantShot
          or battle.dramaticShapeShot == nil then
        fail("mega", "staged-shot-marker-missing")
      end
      local okOverlay, overlayAllowed = pcall(mega.rearOverlayAllowed, battle)
      if not okOverlay or overlayAllowed ~= false then
        fail("mega", "classic-rear-overlay-not-suppressed")
      end
      local originalPlayer = battle.player
      local sheetCols, sheetCellW, sheetCellH = 6, 200, 150
      local sheetRows = math.ceil(#mega.forms / sheetCols)
      local okSheet, megaSheet = pcall(graphics.newCanvas,
        sheetCols * sheetCellW, sheetRows * sheetCellH,
        { dpiscale = 1 })
      if not okSheet or not megaSheet then
        fail("mega", "contact-sheet-canvas")
      end
      megaSheet:setFilter("nearest", "nearest")
      do
        local oldCanvas = graphics.getCanvas()
        local oldBlend, oldAlpha = graphics.getBlendMode()
        local r, g, b, a = graphics.getColor()
        graphics.setCanvas(megaSheet)
        graphics.setBlendMode("alpha")
        graphics.clear(0.035, 0.05, 0.065, 1)
        graphics.setColor(1, 1, 1, 1)
        if oldCanvas then graphics.setCanvas(oldCanvas)
        else graphics.setCanvas() end
        graphics.setBlendMode(oldBlend or "alpha", oldAlpha)
        graphics.setColor(r or 1, g or 1, b or 1, a or 1)
      end
      local checked, catalogError = pcall(function()
        local Pokemon = require("src.pokemon.Pokemon")
        local BattleState = require("src.battle.BattleState")
        local seen, count, grounded, sized, cards = {}, 0, 0, 0, 0
        local normalCompared, largePreserved = 0, 0
        local minWorldHeight, maxWorldHeight = math.huge, 0
        local minHeightRatio, minFootprintRatio = math.huge, math.huge
        local minHeightForm, minFootprintForm = "", ""
        local protectedMinHeightRatio = math.huge
        local protectedMinHeightForm = ""
        local protectedEntries = {}
        local maxCorrection = 0
        for _, profile in ipairs(mega.forms) do
          if type(profile) ~= "table" or not dataId(profile.id)
              or not dataId(profile.species)
              or type(profile.asset) ~= "string" or profile.asset == ""
              or seen[profile.id] then
            error("malformed-profile", 0)
          end
          seen[profile.id], count = true, count + 1
          local mon = Pokemon.new(game.data, profile.species, config.level)
          mon._ascMegaForm = profile.id
          battle.player = BattleState.makeBattler(
            game.data, mon, true, game.save)
          local texture = OverworldBattle.finalizeSideTexture(
            battle, "player", OverworldBattle.sideTexture(battle, "player"))
          local source = texture and texture.kantoAscendantMegaSource
          if not (texture and texture.kantoAscendantMegaSupersampled == true
                  and type(source) == "string"
                  and source:find(profile.asset, 1, true)
                  and source:find("front", 1, true)) then
            error("front-card-missing form=" .. profile.id
              .. " source=" .. tostring(source), 0)
          end
          local _, _, _, visibleBottom = BattlePics.inkBounds(
            texture.canvas, source)
          local metrics = BattleScene.presentationMetrics(texture, 1)
          local baseline = metrics.baseline
          local reported = tonumber(texture.ay)
          local expected = reported and type(visibleBottom) == "number"
            and math.min(reported, visibleBottom + 1) or nil
          if not (reported and expected and baseline == expected) then
            error("ground-anchor-mismatch form=" .. profile.id
              .. " reported=" .. tostring(reported)
              .. " visible=" .. tostring(visibleBottom)
              .. " baseline=" .. tostring(baseline), 0)
          end
          grounded = grounded + 1
          maxCorrection = math.max(maxCorrection, reported - baseline)
          if not (metrics.canvasWidth == 160
                  and metrics.canvasHeight == 144) then
            error("battle-card-mismatch form=" .. profile.id
              .. " canvas=" .. tostring(metrics.canvasWidth) .. "x"
              .. tostring(metrics.canvasHeight), 0)
          end
          cards = cards + 1
          local heightIn = tonumber(texture.heightIn)
          local worldHeight = tonumber(metrics.worldInkHeight)
          if not (heightIn and heightIn > 0
                  and metrics.inkWidth and metrics.inkWidth > 0
                  and metrics.inkHeight and metrics.inkHeight > 0
                  and metrics.worldInkWidth and metrics.worldInkWidth > 0
                  and worldHeight and worldHeight >= 6
                  and worldHeight <= 34
                  and metrics.worldInkWidth <= 36
                  and metrics.combinedScale
                    == BattleScene.speciesScale(texture)) then
            error("presentation-size-mismatch form=" .. profile.id
              .. " height_in=" .. tostring(heightIn)
              .. " ink=" .. tostring(metrics.inkWidth) .. "x"
              .. tostring(metrics.inkHeight)
              .. " world=" .. tostring(worldHeight)
              .. " scale=" .. tostring(metrics.combinedScale), 0)
          end
          sized = sized + 1
          minWorldHeight = math.min(minWorldHeight, worldHeight)
          maxWorldHeight = math.max(maxWorldHeight, worldHeight)

          -- One compact visual receipt for the complete catalog. Draw the
          -- exact live card with the same player-side mirror, physical scale
          -- and alpha-derived foot baseline as production. This catches the
          -- failures that numeric inventory checks cannot: reversed art,
          -- floating ink and one-off visual scale outliers, without writing
          -- 33 full-size battle screenshots.
          do
            local index = count - 1
            local col, row = index % sheetCols,
                             math.floor(index / sheetCols)
            local cellX, cellY = col * sheetCellW, row * sheetCellH
            local oldCanvas = graphics.getCanvas()
            local oldBlend, oldAlpha = graphics.getBlendMode()
            local r, g, b, a = graphics.getColor()
            graphics.setCanvas(megaSheet)
            graphics.setBlendMode("alpha")
            graphics.setColor(0.08, 0.11, 0.14, 1)
            graphics.rectangle("fill", cellX + 2, cellY + 2,
                               sheetCellW - 4, sheetCellH - 4)
            local ground = cellY + 126
            graphics.setColor(0.30, 0.78, 0.45, 1)
            graphics.rectangle("fill", cellX + 8, ground,
                               sheetCellW - 16, 2)
            local drawScale = metrics.scale * 4
            local anchorX = tonumber(texture.ax)
              or metrics.canvasWidth / 2
            graphics.setColor(1, 1, 1, 1)
            graphics.draw(texture.canvas,
              cellX + sheetCellW / 2, ground, 0,
              -drawScale, drawScale, anchorX, metrics.baseline)
            graphics.setColor(0.93, 0.96, 1, 1)
            graphics.print(profile.id, cellX + 8, cellY + 7)
            graphics.setColor(0.58, 0.68, 0.76, 1)
            graphics.print(("%s in / %.1f world / %s"):format(
              tostring(heightIn), worldHeight,
              tostring(metrics.densityPolicy)), cellX + 8, cellY + 23)
            if oldCanvas then graphics.setCanvas(oldCanvas)
            else graphics.setCanvas() end
            graphics.setBlendMode(oldBlend or "alpha", oldAlpha)
            graphics.setColor(r or 1, g or 1, b or 1, a or 1)
          end

          -- Compare every live Mega card with the exact ordinary species card
          -- produced by the same engine/KASC stack. This catches the original
          -- regression directly: a nominal 96px Mega master could be crisp,
          -- grounded and still visibly smaller than its normal form. Broad
          -- already-large silhouettes (notably Mega Steelix) retain their
          -- reviewed footprint; every other Mega must stand at least slightly
          -- taller, while all forms remain inside the shared safe envelope.
          local normalMon = Pokemon.new(
            game.data, profile.species, config.level)
          battle.player = BattleState.makeBattler(
            game.data, normalMon, true, game.save)
          local normalTexture = OverworldBattle.finalizeSideTexture(
            battle, "player", OverworldBattle.sideTexture(battle, "player"))
          local normalMetrics = normalTexture
            and BattleScene.presentationMetrics(normalTexture, 1)
          local normalHeight = normalMetrics
            and tonumber(normalMetrics.worldInkHeight)
          local normalWidth = normalMetrics
            and tonumber(normalMetrics.worldInkWidth)
          if not (normalHeight and normalHeight > 0
                  and normalWidth and normalWidth > 0) then
            error("normal-presentation-missing form=" .. profile.id, 0)
          end
          normalCompared = normalCompared + 1
          local heightRatio = worldHeight / normalHeight
          local footprintRatio = math.sqrt(
            (metrics.worldInkWidth * worldHeight)
            / (normalWidth * normalHeight))
          if heightRatio < minHeightRatio then
            minHeightRatio, minHeightForm = heightRatio, profile.id
          end
          if footprintRatio < minFootprintRatio then
            minFootprintRatio, minFootprintForm = footprintRatio, profile.id
          end
          if metrics.densityPolicy == "large-preserved" then
            largePreserved = largePreserved + 1
            protectedEntries[#protectedEntries + 1] = {
              id = profile.id,
              megaWidth = metrics.worldInkWidth,
              megaHeight = worldHeight,
              normalWidth = normalWidth,
              normalHeight = normalHeight,
              heightRatio = heightRatio,
              footprintRatio = footprintRatio,
            }
            if heightRatio < protectedMinHeightRatio then
              protectedMinHeightRatio = heightRatio
              protectedMinHeightForm = profile.id
            end
            if footprintRatio < 0.90 then
              error(("large-mega-footprint-too-small form=%s ratio=%.3f")
                :format(profile.id, footprintRatio), 0)
            end
          elseif heightRatio < 1.03 then
            error(("mega-not-larger-than-normal form=%s height_ratio=%.3f "
                   .. "mega=%.3f normal=%.3f policy=%s")
              :format(profile.id, heightRatio, worldHeight, normalHeight,
                      tostring(metrics.densityPolicy)), 0)
          end
        end
        if count < 1 then error("empty-catalog", 0) end
        return { count = count, grounded = grounded, sized = sized,
                 cards = cards, minWorldHeight = minWorldHeight,
                 maxWorldHeight = maxWorldHeight,
                 normalCompared = normalCompared,
                 largePreserved = largePreserved,
                 minHeightRatio = minHeightRatio,
                 minFootprintRatio = minFootprintRatio,
                 minHeightForm = minHeightForm,
                 minFootprintForm = minFootprintForm,
                 protectedMinHeightRatio = protectedMinHeightRatio,
                 protectedMinHeightForm = protectedMinHeightForm,
                 protectedEntries = protectedEntries,
                 maxCorrection = maxCorrection }
      end)
      battle.player = originalPlayer
      if not checked then fail("mega", "catalog", catalogError) end
      megaCatalogChecked = true
      for _, entry in ipairs(catalogError.protectedEntries) do
        print(("VASC_BATTLE_QA_MEGA_PROTECTED form=%s "
               .. "mega=%.3fx%.3f normal=%.3fx%.3f "
               .. "height_ratio=%.3f footprint_ratio=%.3f")
          :format(entry.id, entry.megaWidth, entry.megaHeight,
                  entry.normalWidth, entry.normalHeight,
                  entry.heightRatio, entry.footprintRatio))
      end
      local sheetPath = config.root .. "/MEGA-CATALOG-" .. config.stage
        .. ".png"
      local okData, sheetData = pcall(megaSheet.newImageData, megaSheet)
      local okEncode = okData and sheetData
        and pcall(sheetData.encode, sheetData, "png", sheetPath)
      if sheetData and sheetData.release then pcall(sheetData.release, sheetData) end
      if megaSheet.release then pcall(megaSheet.release, megaSheet) end
      local sheetInfo = fs.getInfo(sheetPath, "file")
      if not okEncode or not sheetInfo or (sheetInfo.size or 0) < 1024 then
        fail("mega", "contact-sheet-write", sheetPath)
      end
      print(("VASC_BATTLE_QA_MEGA_CATALOG forms=%d grounded=%d sized=%d "
             .. "cards=%d normal_compared=%d large_preserved=%d "
             .. "world_height_min=%.3f world_height_max=%.3f "
             .. "min_height_ratio=%.3f:%s min_footprint_ratio=%.3f:%s "
             .. "protected_min_height_ratio=%.3f:%s "
             .. "max_correction=%d overlay=0 marker=1 front=1 sheet=%s")
        :format(catalogError.count, catalogError.grounded,
                catalogError.sized, catalogError.cards,
                catalogError.normalCompared, catalogError.largePreserved,
                catalogError.minWorldHeight, catalogError.maxWorldHeight,
                catalogError.minHeightRatio, catalogError.minHeightForm,
                catalogError.minFootprintRatio,
                catalogError.minFootprintForm,
                catalogError.protectedMinHeightRatio,
                catalogError.protectedMinHeightForm,
                catalogError.maxCorrection, sheetPath))
    end
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
    authoredArenaReceipt = authoredArenaReceipt,
    sameReceiptIdentity = sameReceiptIdentity,
    presentedShotReady = presentedShotReady,
  }
end
return run
