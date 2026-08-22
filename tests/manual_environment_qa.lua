-- Manual visual driver for the VASC overworld environment controls.
-- Launch against a QA-only identity and select the sky/camera with:
--   VASC_QA_SKY=full|flat|off
--   VASC_QA_SKY_EVENTS=full|rainbow|flyers|off
--   VASC_QA_CAMERA=6|7             -- 1ST or 3RD
--   VASC_QA_DAYTIME=day|night|dusk|dawn|cycle
--   VASC_QA_WEATHER=clear|auto|rain|snow|fog|storm
--   VASC_QA_FORCE_EVENT=rainbow|pidgeot|hooh|articuno|zapdos|moltres
--   VASC_QA_FORCE_SPECIES=pidgey|pidgeotto|pidgeot|spearow|fearow|farfetchd|murkrow
--   VASC_QA_X / VASC_QA_Y / VASC_QA_DIRECTION=up|down|left|right
--   VASC_QA_PRELOAD_FRAMES=120      -- warm meshes before enabling voxel
--   VASC_QA_AUTO_CROSS_FRAMES=300   -- QA-only: invoke the real ledge/edge path
--   VASC_QA_NO_ENCOUNTERS=1         -- keep visual captures out of battles
--   VASC_QA_PIN_LOOK=1              -- pin free-camera yaw/pitch for A/B captures
return function(game)
  while not (game and game.overworld and game.overworld.map
             and game.stack and game.stack:top() == game.overworld) do
    coroutine.yield()
  end

  local id = "VOXEL_ASCENDANT"
  local sky = os.getenv("VASC_QA_SKY") or "full"
  local skyEvents = os.getenv("VASC_QA_SKY_EVENTS") or "full"
  local camera = tonumber(os.getenv("VASC_QA_CAMERA")) or 7
  local daytime = os.getenv("VASC_QA_DAYTIME") or "day"
  local weather = os.getenv("VASC_QA_WEATHER") or "clear"
  local forceEvent = string.lower(os.getenv("VASC_QA_FORCE_EVENT") or "")
  local forceSpecies = string.lower(os.getenv("VASC_QA_FORCE_SPECIES") or "")
  local scenery = os.getenv("VASC_QA_SCENERY") or "full"
  local clouds = os.getenv("VASC_QA_CLOUDS") or "on"
  local targetMap = os.getenv("VASC_QA_MAP")
  local targetX = tonumber(os.getenv("VASC_QA_X"))
  local targetY = tonumber(os.getenv("VASC_QA_Y"))
  local direction = os.getenv("VASC_QA_DIRECTION") or "up"
  local preloadFrames = tonumber(os.getenv("VASC_QA_PRELOAD_FRAMES")) or 0
  local autoCrossFrames = tonumber(os.getenv("VASC_QA_AUTO_CROSS_FRAMES"))
  local noEncounters = os.getenv("VASC_QA_NO_ENCOUNTERS") == "1"
  local pinLook = os.getenv("VASC_QA_PIN_LOOK") == "1"
  local values = {
    battles = true,
    trainerBack = false,
    battleBack = false,
    sky = sky,
    skyEvents = skyEvents,
    daytime = daytime,
    weather = weather,
    scenery = scenery,
    clouds = clouds,
    shadows = false,
  }
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions[id] = values
  game.mods.modOptions = game.mods.modOptions or {}
  game.mods.modOptions[id] = values

  -- Put the isolated QA save near Pallet's northern tree line and face it.
  -- Reloading through setMap also rebuilds connected-map state exactly as a
  -- real warp would, which exercises the horizon wall's seam exclusions.
  local ow = game.overworld
  if noEncounters then
    ow.rollEncounter = function() return nil end
  end
  if targetMap and targetMap ~= "" and targetMap ~= ow.map.id then
    ow:setMap(targetMap, 2, 2, "up")
  end
  local x = targetX or math.max(2, math.min(10, ow.map.def.width * 2 - 3))
  local y = targetY or math.max(2, math.min(4, ow.map.def.height * 2 - 3))
  x = math.max(1, math.min(x, ow.map.def.width * 2 - 2))
  y = math.max(1, math.min(y, ow.map.def.height * 2 - 2))
  ow:setMap(ow.map.id, x, y, direction)

  -- Leave the ordinary 2D pipeline active for a controlled number of update
  -- ticks. PRELOAD should consume those otherwise-idle ticks and have the
  -- current map ready before the camera mode is switched on.
  for _ = 1, preloadFrames do coroutine.yield() end

  local Pipelines = require("src.render.Pipelines")
  camera = Pipelines.setLevel("voxel", camera)
  Pipelines.syncOptions(game.save.options)
  local FirstPerson = pinLook and game.mods.exports[id].lib.require("FirstPerson")
                      or nil
  local pinnedYaw = ({ down = 0, right = math.pi / 2,
                       up = math.pi, left = -math.pi / 2 })[direction] or 0

  -- Exercise the same row closure the in-game OPTIONS screen uses. Merely
  -- changing loader.modOptions here would leave an already-read ModSetting
  -- cache untouched and would not test the player's real switching path.
  local Runtime = require("src.mods.Runtime")
  local rows = Runtime.call("ui.options.rows", function(_, base) return base end,
                            game, {})
  local wanted = {
    sky = string.upper(sky), daytime = string.upper(daytime),
    skyEvents = string.upper(skyEvents),
    weather = string.upper(weather), scenery = string.upper(scenery),
    clouds = string.upper(clouds),
  }
  for _, row in ipairs(rows or {}) do
    local key = row.id and row.id:match("^" .. id .. ":(.+)$")
    if key and wanted[key] then
      for _ = 1, 8 do
        if row.value(game) == wanted[key] then break end
        row.step(game, 1)
      end
    end
  end

  -- Rare-event production cadence stays untouched. This QA-only driver jumps
  -- the save-local clock into the middle of one requested window so a visual
  -- Metal run can inspect the art and world anchoring immediately.
  local forcedEvents, forcedClock
  local forcedKind
  if forceEvent ~= "" or forceSpecies ~= "" then
    local exports = game.mods and game.mods.exports
                    and game.mods.exports[id]
    local Events = exports and exports.lib and exports.lib.require
                   and exports.lib.require("SkyEvents")
    local timing = Events and Events.TIMING
                   and Events.TIMING[forceSpecies ~= "" and "pidgeot"
                                     or forceEvent]
    if forceSpecies ~= "" and forceEvent ~= "" then
      error("set only one of VASC_QA_FORCE_EVENT/VASC_QA_FORCE_SPECIES")
    elseif forceSpecies ~= "" and timing then
      forcedEvents = Events
      forcedKind = "pidgeot"
      forcedClock = Events.qaClockForSpecies
                    and Events.qaClockForSpecies(forceSpecies, 0.50)
      if not forcedClock then
        error("VASC_QA_FORCE_SPECIES unknown species "
              .. tostring(forceSpecies))
      end
      Events.clock = forcedClock
      -- This is an isolated visual process: complete its relevant prewarm now
      -- so the first screenshot cannot race the normal one-atlas-per-frame
      -- production staging path.
      if Events.prewarm then Events.prewarm() end
      local plan = Events.ordinaryPlan and Events.ordinaryPlan(forcedClock)
      print(("VASC_QA_FORCE_SPECIES %s clock=%.3f count=%s asset=%s")
        :format(forceSpecies, Events.clock,
                tostring(plan and plan.count), tostring(plan and plan.asset)))
    elseif timing then
      forcedEvents = Events
      forcedKind = forceEvent
      -- Use a genuine production occurrence where the requested legend wins
      -- the normal overlap policy. This remains world-anchored and changes no
      -- production timing or save data; only this QA coroutine pins the clock.
      forcedClock = Events.qaClock and Events.qaClock(forceEvent, 0.50)
                    or timing.period - timing.offset + timing.duration * 0.50
      Events.clock = forcedClock
      if Events.prewarm then Events.prewarm() end
      local status, reason = Events.assetStatus
                             and Events.assetStatus(forceEvent == "pidgeot"
                                                    and "flock" or forceEvent)
      local progress = Events.progress and Events.progress(forceEvent,
                                                            forcedClock)
      print(("VASC_QA_FORCE_EVENT %s clock=%.3f progress=%.3f asset=%s/%s")
        :format(forceEvent, Events.clock, progress or -1,
                tostring(status), tostring(reason)))
    else
      error("VASC_QA_FORCE_EVENT unknown event " .. tostring(forceEvent))
    end
  end
  if forcedEvents and forcedKind then
    local traced = false
    local basePaint = forcedEvents.paint
    forcedEvents.paint = function(ctx, layer)
      local drawn = basePaint(ctx, layer)
      local wantedLayer = forcedKind == "rainbow" and "back" or "front"
      if not traced and layer == wantedLayer then
        traced = true
        local azimuth = forcedEvents.anchor(forcedKind, forcedClock)
        local elevation = forcedKind == "rainbow" and 0.20
                          or (forcedKind == "pidgeot" and 0.22
                              or (forcedEvents.LEGEND_ART[forcedKind]
                                  and forcedEvents.LEGEND_ART[forcedKind].elevation))
        local px, py, visible = ctx.project(azimuth, elevation)
        print(("VASC_QA_SKY_PAINT kind=%s layer=%s drawn=%d "
               .. "canvas=%dx%d edge=%.1f cell=%.3f project=%.1f,%.1f,%s")
          :format(forcedKind, layer, drawn, ctx.w, ctx.h, ctx.edge, ctx.cell,
                  px or -999, py or -999, tostring(visible)))
      end
      return drawn
    end
  end
  -- Some compatibility mods update the player after setMap while their own
  -- map-enter hooks settle. Reassert the requested view direction after all
  -- option hooks so close-up edge screenshots are deterministic.
  if ow.player then ow.player.facing = direction end
  print(("VASC_QA_ENV map=%s x=%d y=%d sky=%s events=%s daytime=%s weather=%s "
         .. "scenery=%s clouds=%s event=%s camera=%s"):format(
    tostring(ow.map.id), x, y, sky, skyEvents, daytime, weather, scenery, clouds,
    forceSpecies ~= "" and ("species:" .. forceSpecies)
      or (forceEvent ~= "" and forceEvent or "scheduled"),
    Pipelines.levelLabel("voxel", camera)))

  local visibleFrames = 0
  local autoCrossDone = false
  while true do
    if ow.player then ow.player.facing = direction end
    if FirstPerson then
      FirstPerson.yaw = pinnedYaw
      FirstPerson.pitch = FirstPerson.PITCH_DEFAULT
    end
    -- Hold the selected pose long enough for screenshots and camera-rotation
    -- checks; only this QA process is pinned, production update cadence is not.
    if forcedEvents then forcedEvents.clock = forcedClock end
    visibleFrames = visibleFrames + 1
    if autoCrossFrames and not autoCrossDone
       and visibleFrames >= autoCrossFrames then
      autoCrossDone = true
      local from = ow.map and ow.map.id
      local started = ow.checkLedgeHop and ow:checkLedgeHop(direction)
      if not started and ow.checkEdgeExit then
        started = ow:checkEdgeExit(direction)
      end
      print(("VASC_QA_AUTO_CROSS from=%s direction=%s started=%s")
        :format(tostring(from), tostring(direction), tostring(started)))
    end
    coroutine.yield()
  end
end
