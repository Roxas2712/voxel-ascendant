-- Gen-1 Weather Music bridge. It owns one music.select wrapper and asks the
-- engine's existing Music owner to replay/refresh an already-owned map cue.
-- It never creates, plays, pauses or stops a LOVE Source itself. Newer hosts
-- may publish status/refreshMap; Gen1Recomp 0.1.90 publishes the narrower
-- current/mapSong/playMap contract. Both paths retain src.core.Music as the
-- only audio owner.

local Adapter = {}
Adapter.__index = Adapter

Adapter.API_VERSION = 1
Adapter.SCHEMA = "voxel-ascendant/weather-music-playback/v1"
-- Resolve after every lower-priority selector, including VASC LocalMusic at
-- 2,000,000.  The weather layer can therefore retain and later restore the
-- exact final normal map cue instead of the engine's pre-hook mapSong.
Adapter.HOOK_PRIORITY = 2100000

-- Music.status in the refresh-owner host exposes whether either of its two
-- owned BGM Sources is actually sounding.  A short empty receipt can be
-- legitimate while an app pause, fanfare or phase hand-off owns audio, so a
-- stopped label is only treated as a fault after several identical frames.
-- Recovery is capped per stable route and backed off between attempts; a
-- healthy Weather Source resets the budget after two seconds at 60 Hz.
Adapter.SILENT_CONFIRM_OBSERVATIONS = 8
Adapter.SILENT_MAX_RECOVERIES = 3
Adapter.SILENT_HEALTHY_RESET_OBSERVATIONS = 120
Adapter.SILENT_BACKOFF_OBSERVATIONS = { 30, 120, 300 }

local function text(value)
  return type(value) == "string" and value ~= "" and value or nil
end

local function call(fn, ...)
  if type(fn) ~= "function" then return false, "function is unavailable" end
  local ok, a, b = pcall(fn, ...)
  if not ok then return false, tostring(a) end
  if a == false then return false, tostring(b or "request declined") end
  return true, a, b
end

local function log(owner, event, fields)
  local diagnostics = owner and owner.diagnostics
  if type(diagnostics) == "table"
      and type(diagnostics.write) == "function" then
    pcall(diagnostics.write, event, fields)
  end
end

local function mapIdentity(game)
  local overworld = type(game) == "table" and game.overworld or nil
  local map = type(overworld) == "table" and overworld.map or nil
  local mapId = map and (map.id or (map.def and map.def.id)) or nil
  local ready = type(map) == "table" and type(map.def) == "table"
    and text(tostring(mapId or "")) ~= nil
    and not (overworld and overworld.transitioning == true)
  return map, ready and tostring(mapId) or nil, ready
end

local function stateKey(state)
  return table.concat({
    tostring(state.map), tostring(state.mapId), tostring(state.weatherCode),
    tostring(state.timeOfDay), state.optionEnabled and "1" or "0",
  }, "\0")
end

local function ownerReason(status)
  if type(status) ~= "table" then return nil end
  return status.reason or status.owner or status.currentReason or status.ownerReason
    or (type(status.context) == "table" and status.context.reason)
end

local function mapOwner(status, mapId)
  if type(status) ~= "table" then return false, "status-unavailable" end
  if status.mapOwned == false then return false, "priority-owner" end
  local reason = ownerReason(status)
  if reason ~= nil and reason ~= "map" then return false, "priority-owner" end
  local statusMap = status.mapId
    or (type(status.context) == "table" and status.context.mapId)
  if statusMap ~= nil and mapId ~= nil and tostring(statusMap) ~= mapId then
    return false, "map-changed"
  end
  -- Bicycle remains map-owned: Weather Music has an authored Bicycle family
  -- and must also reclaim it after battle. Surf still owns a separate native
  -- composition for which no weather variants are packaged.
  if status.surfing == true then return false, "surf-owner" end
  if status.current == nil and status.song == nil and status.songId == nil then
    return false, "no-current-cue"
  end
  return true
end

local function audioHeld(status)
  if type(status) ~= "table" then return false end
  return status.paused == true
    or status.fanfare == true or status.fanfareActive == true
    or status.jingle == true or status.jingleActive == true
end

local function explicitPlayingSources(status)
  local count = type(status) == "table" and status.playingSources or nil
  if type(count) ~= "number" or count < 0 then return nil end
  return math.floor(count)
end

local function hostContract(music)
  if type(music) ~= "table" then return nil end
  if type(music.status) == "function"
      and type(music.refreshMap) == "function" then
    return "refresh-owner-v1"
  end
  if type(music.current) == "function"
      and type(music.mapSong) == "function"
      and type(music.playMap) == "function" then
    return "gen1-music-v1"
  end
  return nil
end

function Adapter.new(options)
  options = options or {}
  local mod, music = options.mod, options.music
  local router, option = options.router, options.option
  if type(mod) ~= "table" or type(mod.hooks) ~= "table"
      or type(mod.hooks.wrap) ~= "function" then
    return nil, "music.select hook surface is unavailable"
  end
  local contract = hostContract(music)
  if not contract then
    return nil, "central Music owner map playback contract is unavailable"
  end
  if type(router) ~= "table" or type(router.select) ~= "function" then
    return nil, "weather music router capability is unavailable"
  end
  if type(option) ~= "table" or type(option.enabled) ~= "function" then
    return nil, "weather music option capability is unavailable"
  end
  return setmetatable({
    mod=mod, music=music, musicContract=contract,
    router=router, option=option,
    diagnostics=options.diagnostics,
    active=false, unsubscribe=nil,
    observed=nil, observedKey=nil, stableCount=0, stable=nil,
    requestToken=0, requestedKey=nil,
    lastNativeSongId=nil, lastRoute=nil, lastRouteSignature=nil,
    failedSongs={},
    lastMusicContext=nil,
    lastOwnershipReason=nil, lastError=nil,
    forceNativeRecovery=false,
    playbackHealth={
      key=nil, silent=0, audible=0, cooldown=0, attempts=0,
      phase=nil, detected=false, exhausted=false,
    },
  }, Adapter)
end

function Adapter:_route(normalSong, ctx)
  ctx = type(ctx) == "table" and ctx or {}
  if ctx.reason ~= "map" then
    if self.lastOwnershipReason ~= "priority-owner" then
      self.lastOwnershipReason = "priority-owner"
      log(self, "vasc.weather-music.ownership-released", {
        owner="central-music", reason="priority-owner",
        requestToken=self.requestToken,
      })
    end
    return normalSong
  end

  local stable = self.stable
  if not stable or stable.mapId ~= tostring(ctx.mapId or "") then
    return normalSong
  end
  self.lastNativeSongId = normalSong
  -- A dead Weather Source cannot be restarted by selecting the same label:
  -- the central owner correctly considers that request idempotent.  For one
  -- owner-controlled refresh only, let the post-selector native cue through.
  -- The following observation re-applies Weather through the ordinary route.
  if self.forceNativeRecovery == true then return normalSong end
  local routed = self.router.select({
    generation=1,
    reason="map",
    mapReady=stable.mapReady,
    stable=true,
    optionEnabled=stable.optionEnabled,
    onBike=ctx.onBike == true,
    surfing=ctx.surfing == true,
    higherPriority=false,
    mapId=stable.mapId,
    weatherCode=stable.weatherCode,
    timeOfDay=stable.timeOfDay,
    nativeSongId=normalSong,
    requestToken=self.requestToken,
  })
  if type(routed) ~= "table" then return normalSong end
  if routed.action == "weather" and text(routed.songId)
      and self.failedSongs[routed.songId] then
    routed = {
      schema=routed.schema, apiVersion=routed.apiVersion,
      action="native", reason="asset-failed",
      mapId=routed.mapId, weatherCode=routed.weatherCode,
      timeOfDay=routed.timeOfDay, songId=normalSong,
      failedSongId=routed.songId, requestToken=routed.requestToken,
    }
  end
  self.lastRoute = routed
  local signature = table.concat({ tostring(routed.action),
    tostring(routed.songId), tostring(routed.reason),
    tostring(routed.requestToken) }, "|")
  if signature ~= self.lastRouteSignature then
    self.lastRouteSignature = signature
    self.lastOwnershipReason = routed.reason
    log(self, "vasc.weather-music.route-selected", {
      mapId=routed.mapId, weatherCode=routed.weatherCode,
      timeOfDay=routed.timeOfDay, musicFamily=routed.family,
      musicVariant=routed.variant, musicId=routed.songId,
      action=routed.action, reason=routed.reason,
      requestToken=routed.requestToken,
      transition=routed.phaseMode,
    })
  end
  if routed.action == "weather" and text(routed.songId) then
    return routed.songId
  end
  return normalSong
end

function Adapter:activate()
  if self.active then return true end
  local ok, unsubscribe = pcall(self.mod.hooks.wrap, self.mod.hooks,
    "music.select", function(nextSong, current, ctx)
      local normal = nextSong(current, ctx)
      if type(ctx) == "table" then
        self.lastMusicContext = {
          reason=ctx.reason, mapId=ctx.mapId,
          onBike=ctx.onBike == true, surfing=ctx.surfing == true,
        }
      end
      return self:_route(normal, ctx)
    end, Adapter.HOOK_PRIORITY)
  if not ok or type(unsubscribe) ~= "function" then
    return false, "music.select registration failed: " .. tostring(unsubscribe)
  end
  self.unsubscribe = unsubscribe
  self.active = true
  log(self, "vasc.weather-music.adapter-active", {
    cardId="vasc.gen1.weather-music.playback-adapter",
    version="1.0.0", status="active",
  })
  return true
end

function Adapter:_musicStatus()
  if self.musicContract == "refresh-owner-v1" then
    local ok, status = pcall(self.music.status)
    if not ok or type(status) ~= "table" then
      return nil, ok and "invalid Music.status receipt" or tostring(status)
    end
    return status
  end
  local okCurrent, current = pcall(self.music.current)
  local okMap, mapSong = pcall(self.music.mapSong)
  if not okCurrent or not okMap then
    return nil, tostring(not okCurrent and current or mapSong)
  end
  local context = self.lastMusicContext or {}
  local mapId = context.mapId
    or (self.stable and self.stable.mapId) or nil
  return {
    current=current, mapSong=mapSong,
    reason=context.reason or "map", mapId=mapId,
    onBike=context.onBike == true, surfing=context.surfing == true,
  }
end

function Adapter:_refreshMap(game, request)
  if self.musicContract == "refresh-owner-v1" then
    return call(self.music.refreshMap, game and game.data, request)
  end
  local _, liveMapId, ready = mapIdentity(game)
  if not ready or tostring(liveMapId) ~= tostring(request.mapId) then
    return false, "map-changed"
  end
  local context = self.lastMusicContext or {}
  if context.reason ~= nil and context.reason ~= "map" then
    return false, "priority-owner"
  end
  -- playMap is the 0.1.90 central owner's public replay seam. It recomputes
  -- the normal map cue, then runs this adapter's music.select wrapper exactly
  -- once. No VASC Source exists and battle/jingle owners remain untouched.
  local ok, err = pcall(self.music.playMap, game and game.data,
    request.mapId, context.onBike == true, context.surfing == true,
    self.music.MAP_FADE or 10)
  if not ok then return false, tostring(err) end
  return true, "queued"
end

local function resetPlaybackHealth(owner, key)
  local health = owner.playbackHealth
  health.key, health.silent, health.audible = key, 0, 0
  health.cooldown, health.attempts = 0, 0
  health.phase, health.detected, health.exhausted = nil, false, false
end


function Adapter:_requestSilentRecovery(game, candidate, key, status)
  local health = self.playbackHealth
  local nativeSongId = text(self.lastNativeSongId)
    or text(status.mapSong) or text(status.nativeSongId)
  local currentSong = status.current or status.song or status.songId
  health.attempts = health.attempts + 1
  if not nativeSongId or nativeSongId == currentSong then
    health.cooldown = Adapter.SILENT_BACKOFF_OBSERVATIONS[
      math.min(health.attempts, #Adapter.SILENT_BACKOFF_OBSERVATIONS)]
    log(self, "vasc.weather-music.silence-recovery-unavailable", {
      mapId=candidate.mapId, weatherCode=candidate.weatherCode,
      timeOfDay=candidate.timeOfDay, musicId=currentSong,
      reason="native-cue-unavailable", attempt=health.attempts,
    })
    return false, "native-recovery-unavailable"
  end

  health.silent, health.audible, health.detected = 0, 0, false
  health.cooldown = Adapter.SILENT_BACKOFF_OBSERVATIONS[
    math.min(health.attempts, #Adapter.SILENT_BACKOFF_OBSERVATIONS)] or 300
  self.requestToken = self.requestToken + 1
  local request = {
    token=self.requestToken,
    mapId=candidate.mapId,
    nativeSongId=nativeSongId,
    -- Crossfade is intentional.  If a fanfare has paused the BGM without a
    -- public fanfare bit, the central owner queues this request until the
    -- jingle releases audio instead of starting underneath it.
    phaseMode="crossfade",
  }
  self.forceNativeRecovery = true
  local refreshed, result, detail = self:_refreshMap(game, request)
  self.forceNativeRecovery = false
  if not refreshed then
    health.phase = nil
    self.lastError = result
    log(self, "vasc.weather-music.silence-recovery-error", {
      mapId=candidate.mapId, weatherCode=candidate.weatherCode,
      timeOfDay=candidate.timeOfDay, musicId=currentSong,
      nativeMusicId=nativeSongId, requestToken=self.requestToken,
      attempt=health.attempts, error=result,
    })
    return false, result
  end

  -- Keep requestedKey armed while native playback/its owner-held queue settles;
  -- otherwise the next frame could immediately schedule Weather over it.
  self.requestedKey = key
  health.phase = "await-native"
  self.lastError = nil
  log(self, "vasc.weather-music.silence-recovery-requested", {
    mapId=candidate.mapId, weatherCode=candidate.weatherCode,
    timeOfDay=candidate.timeOfDay, musicId=currentSong,
    nativeMusicId=nativeSongId, requestToken=self.requestToken,
    attempt=health.attempts, transition="native-then-weather",
    status=tostring(detail or result),
  })
  return true, result or "silence-recovery-native-requested"
end


-- Returns true when playback health has fully handled this observation.  A
-- false first result means the ordinary routing code should continue below.
function Adapter:_observePlaybackHealth(game, candidate, key, status)
  if self.musicContract ~= "refresh-owner-v1"
      or self.requestedKey ~= key then
    return false
  end
  local health = self.playbackHealth
  if health.key ~= key then resetPlaybackHealth(self, key) end
  if health.cooldown > 0 then health.cooldown = health.cooldown - 1 end

  local route = self.lastRoute
  local expected = type(route) == "table" and route.action == "weather"
    and text(route.songId) or nil
  local current = status.current or status.song or status.songId
  local playing = explicitPlayingSources(status)
  if not expected or playing == nil then
    health.silent, health.audible = 0, 0
    health.phase = nil
    return true, false, "already-requested"
  end

  if audioHeld(status) then
    health.silent, health.audible = 0, 0
    return true, false, "audio-owner-held"
  end

  if health.phase == "await-native" then
    if current == expected and playing > 0 then
      -- The central owner recovered by itself before the native bridge landed.
      health.phase, health.silent = nil, 0
      log(self, "vasc.weather-music.silence-recovered", {
        mapId=candidate.mapId, weatherCode=candidate.weatherCode,
        musicId=expected, attempt=health.attempts,
        reason="owner-resumed-weather",
      })
      return true, false, "weather-source-resumed"
    end
    if current ~= expected and playing > 0
        and status.transitioning ~= true and status.pendingSong == nil then
      health.phase, health.silent = "await-weather", 0
      self.requestedKey = nil
      log(self, "vasc.weather-music.silence-native-ready", {
        mapId=candidate.mapId, weatherCode=candidate.weatherCode,
        musicId=expected, nativeMusicId=current,
        attempt=health.attempts, reason="reapply-weather",
      })
      return false
    end
    return true, false, "silence-recovery-awaiting-native"
  end

  if current == expected and playing > 0 then
    health.silent = 0
    health.audible = health.audible + 1
    if health.phase == "await-weather" then
      health.phase = nil
      log(self, "vasc.weather-music.silence-recovery-complete", {
        mapId=candidate.mapId, weatherCode=candidate.weatherCode,
        musicId=expected, attempt=health.attempts,
        reason="weather-audible",
      })
    end
    if health.audible >= Adapter.SILENT_HEALTHY_RESET_OBSERVATIONS then
      health.audible, health.attempts, health.cooldown = 0, 0, 0
      health.exhausted = false
    end
    return true, false, "already-requested"
  end

  health.audible = 0
  if current ~= expected then
    -- A stable audible native map cue means the requested Weather route was
    -- displaced without an intervening state change.  Re-arm it directly;
    -- no native bridge is necessary because a healthy owner already sounds.
    if playing > 0 and status.transitioning ~= true
        and status.pendingSong == nil and health.cooldown <= 0 then
      health.phase = "await-weather"
      self.requestedKey = nil
      log(self, "vasc.weather-music.route-rearmed", {
        mapId=candidate.mapId, weatherCode=candidate.weatherCode,
        musicId=expected, currentMusicId=current,
        reason="map-route-displaced",
      })
      return false
    end
    return true, false, "weather-route-settling"
  end

  -- A transition or pending owner request may legitimately report an empty
  -- frame.  Let the central owner settle it; this adapter never reaches into
  -- Sources or bypasses that queue.
  if status.transitioning == true or status.pendingSong ~= nil then
    health.silent = 0
    return true, false, "weather-owner-settling"
  end
  if playing > 0 then
    health.silent = 0
    return true, false, "already-requested"
  end

  health.silent = health.silent + 1
  if health.silent < Adapter.SILENT_CONFIRM_OBSERVATIONS then
    return true, false, "weather-source-silent-confirming"
  end
  if not health.detected then
    health.detected = true
    log(self, "vasc.weather-music.silence-detected", {
      mapId=candidate.mapId, weatherCode=candidate.weatherCode,
      timeOfDay=candidate.timeOfDay, musicId=expected,
      playingSources=playing, transition=status.transitioning == true,
      pendingSong=status.pendingSong, attempts=health.attempts,
    })
  end
  if health.cooldown > 0 then
    return true, false, "silence-recovery-backoff"
  end
  if health.attempts >= Adapter.SILENT_MAX_RECOVERIES then
    if not health.exhausted then
      health.exhausted = true
      log(self, "vasc.weather-music.silence-recovery-exhausted", {
        mapId=candidate.mapId, weatherCode=candidate.weatherCode,
        musicId=expected, attempts=health.attempts,
        reason="recovery-budget-exhausted",
      })
    end
    return true, false, "silence-recovery-exhausted"
  end
  local ok, result = self:_requestSilentRecovery(
    game, candidate, key, status)
  return true, ok, result
end

-- Called from the already always-running VASC pipeline update immediately
-- after Weather.update.  Two identical observations are required before a
-- refresh; map object identity prevents a reused textual id from crossing a
-- load transaction.
function Adapter:observe(game, weatherCode, timeOfDay)
  if not self.active then return false, "adapter-inactive" end
  local map, mapId, ready = mapIdentity(game)
  local optionOK, optionEnabled = pcall(self.option.enabled)
  optionEnabled = optionOK and optionEnabled == true
  local candidate = {
    map=map, mapId=mapId, mapReady=ready,
    weatherCode=text(weatherCode) or "clear",
    timeOfDay=text(timeOfDay) or "DAY",
    optionEnabled=optionEnabled,
  }
  local key = stateKey(candidate)
  if self.observedKey == key and self.observed and self.observed.map == map then
    self.stableCount = self.stableCount + 1
  else
    self.observed, self.observedKey = candidate, key
    self.stableCount = 1
  end
  if self.stableCount < 2 then return false, "state-not-stable" end
  self.stable = candidate
  if not ready then
    self.requestedKey = nil
    resetPlaybackHealth(self, nil)
    return false, "map-not-ready"
  end
  local status, statusError = self:_musicStatus()
  if not status then
    if self.lastError ~= statusError then
      self.lastError = statusError
      log(self, "vasc.weather-music.owner-error", {
        reason="status-unavailable", error=statusError,
      })
    end
    return false, statusError
  end
  local ownsMap, ownershipReason = mapOwner(status, mapId)
  if not ownsMap then
    -- A battle, jingle or surf cue temporarily owns the central player.
    -- The weather state itself often does not change across that interruption,
    -- so retaining requestedKey would make the first restored native map cue
    -- look already satisfied forever.  Arm the same stable weather request
    -- again, but only after the central owner reports map ownership below.
    self.requestedKey = nil
    resetPlaybackHealth(self, nil)
    self.lastOwnershipReason = ownershipReason
    return false, ownershipReason
  end
  local healthHandled, healthOK, healthReason =
    self:_observePlaybackHealth(game, candidate, key, status)
  if healthHandled then return healthOK, healthReason end
  if self.requestedKey == key then return false, "already-requested" end

  local currentSong = status.current or status.song or status.songId
  local currentIsWeather = self.lastRoute
    and self.lastRoute.action == "weather"
    and currentSong == self.lastRoute.songId
  if text(currentSong) and not currentIsWeather then
    -- Music.status reports the post-hook current cue.  This is the only safe
    -- normal fallback in a combined VASC/KASC run; mapSong is merely the
    -- engine's pre-selector request.
    self.lastNativeSongId = currentSong
  end
  local nativeSongId = self.lastNativeSongId or status.mapSong

  self.requestToken = self.requestToken + 1
  local planned = self.router.select({
    generation=1, reason="map", mapReady=true, stable=true,
    optionEnabled=candidate.optionEnabled,
    onBike=status.onBike == true, surfing=status.surfing == true,
    higherPriority=false, mapId=mapId,
    weatherCode=candidate.weatherCode, timeOfDay=candidate.timeOfDay,
    nativeSongId=nativeSongId,
    requestToken=self.requestToken,
  })
  local plannedFailed = type(planned) == "table"
    and planned.action == "weather" and text(planned.songId)
    and self.failedSongs[planned.songId] == true
  local phase = type(planned) == "table" and planned.action == "weather"
    and not plannedFailed
    and planned or self.lastRoute
  local hasTiming = type(phase) == "table"
    and text(phase.compositionId) ~= nil
    and tonumber(phase.bpm) ~= nil
  local targetIsWeather = type(planned) == "table"
    and planned.action == "weather" and not plannedFailed
  local canSynchronize = hasTiming and (
    (targetIsWeather and (currentIsWeather
      or planned.nativeSongMatched == true))
    or (not targetIsWeather and phase.nativeSongMatched == true))
  local requestedPhaseMode = canSynchronize and phase.phaseMode == "phrase"
    and "phrase-boundary"
    or (canSynchronize and "synchronous" or "crossfade")
  local request = {
    token=self.requestToken,
    mapId=mapId,
    nativeSongId=nativeSongId,
    phaseMode=requestedPhaseMode,
    compositionId=hasTiming and phase.compositionId or nil,
    transitionBars=hasTiming and phase.transitionBars or nil,
    timing=hasTiming and {
      bpm=phase.bpm,
      beatsPerBar=phase.beatsPerBar,
      introEndSeconds=phase.introEndSeconds,
      loopStartSeconds=phase.loopStartSeconds,
      loopEndSeconds=phase.loopEndSeconds,
      loopCrossfadeSeconds=0.09,
      downbeatOriginSeconds=phase.downbeatOriginSeconds,
      downbeatStepSeconds=phase.downbeatStepSeconds,
      phraseSeconds=phase.phraseSeconds,
    } or nil,
  }
  local refreshed, result, detail = self:_refreshMap(game, request)
  self.requestedKey = key
  if not refreshed then
    -- The final post-selector normal cue may change while Weather owns the
    -- output (for example a live LocalMusic profile change).  A synchronous
    -- receipt names the previously observed native reference and must then be
    -- rejected by the Engine.  Retry once as an ordinary crossfade so the new
    -- final cue is restored exactly, without lending it an unproven grid.
    if request.phaseMode == "synchronous"
        and (result == "native-song-mismatch"
          or result == "composition-mismatch") then
      self.requestToken = self.requestToken + 1
      local retryRequest = {
        token=self.requestToken,
        mapId=mapId,
        nativeSongId=nativeSongId,
        phaseMode="crossfade",
      }
      local retryOK, retryResult, retryDetail =
        self:_refreshMap(game, retryRequest)
      if retryOK then
        self.lastError = nil
        log(self, "vasc.weather-music.phase-downgraded", {
          mapId=mapId, weatherCode=candidate.weatherCode,
          timeOfDay=candidate.timeOfDay, requestToken=self.requestToken,
          transition="crossfade", reason=result,
          status=tostring(retryDetail or retryResult),
        })
        return true, retryResult or "crossfade-fallback"
      end
      result = retryResult
    end
    if type(planned) == "table" and planned.action == "weather"
        and text(planned.songId)
        and (result == "source-failed" or result == "missing-song") then
      self.failedSongs[planned.songId] = true
      self.requestToken = self.requestToken + 1
      local fallbackRequest = {
        token=self.requestToken,
        mapId=mapId,
        nativeSongId=nativeSongId,
        phaseMode="crossfade",
      }
      local fallbackOK, fallbackResult =
        self:_refreshMap(game, fallbackRequest)
      log(self, "vasc.weather-music.asset-failed", {
        mapId=mapId, weatherCode=candidate.weatherCode,
        timeOfDay=candidate.timeOfDay, musicId=planned.songId,
        requestToken=self.requestToken, error=result,
        reason=fallbackOK and "native-fallback" or "fallback-declined",
      })
      if fallbackOK then
        self.lastError = result
        return true, fallbackResult or "native-fallback"
      end
      self.lastError = fallbackResult
      return false, fallbackResult
    end
    self.lastError = result
    log(self, "vasc.weather-music.refresh-error", {
      mapId=mapId, weatherCode=candidate.weatherCode,
      timeOfDay=candidate.timeOfDay, requestToken=self.requestToken,
      error=result, reason="refresh-declined",
    })
    return false, result
  end
  self.lastError = nil
  log(self, "vasc.weather-music.refresh-requested", {
    mapId=mapId, weatherCode=candidate.weatherCode,
    timeOfDay=candidate.timeOfDay, requestToken=self.requestToken,
    transition=request.phaseMode, status=tostring(detail or result),
  })
  return true, result
end

function Adapter:deactivate(reason)
  if not self.active then return true end
  self.active = false
  local unsubscribe = self.unsubscribe
  self.unsubscribe = nil
  if unsubscribe then pcall(unsubscribe) end
  self.requestToken = self.requestToken + 1
  local status = self:_musicStatus()
  local ownsMap = status and mapOwner(status, status.mapId)
  if ownsMap and self.lastGame then
    if self.musicContract == "refresh-owner-v1" then
      pcall(self.music.refreshMap, self.lastGame.data, {
          token=self.requestToken, mapId=status.mapId,
          nativeSongId=self.lastNativeSongId or status.mapSong,
          phaseMode="crossfade",
        })
    else
      local context = self.lastMusicContext or {}
      pcall(self.music.playMap, self.lastGame.data, status.mapId,
        context.onBike == true, context.surfing == true,
        self.music.MAP_FADE or 10)
    end
  end
  log(self, "vasc.weather-music.adapter-inactive", {
    cardId="vasc.gen1.weather-music.playback-adapter",
    status="inactive", reason=reason or "card-deactivated",
    requestToken=self.requestToken,
  })
  return true
end

function Adapter:status()
  return {
    schema=Adapter.SCHEMA,
    apiVersion=Adapter.API_VERSION,
    ok=self.active,
    state=self.active and "active" or "inactive",
    stable=self.stableCount >= 2,
    mapId=self.stable and self.stable.mapId or nil,
    weatherCode=self.stable and self.stable.weatherCode or nil,
    timeOfDay=self.stable and self.stable.timeOfDay or nil,
    optionEnabled=self.stable and self.stable.optionEnabled or nil,
    requestToken=self.requestToken,
    route=self.lastRoute and self.lastRoute.action or nil,
    songId=self.lastRoute and self.lastRoute.songId or nil,
    reason=self.lastOwnershipReason,
    musicContract=self.musicContract,
    error=self.lastError,
    silenceRecoveryPhase=self.playbackHealth.phase,
    silenceRecoveryAttempts=self.playbackHealth.attempts,
    silentObservations=self.playbackHealth.silent,
  }
end

function Adapter:public()
  local owner = self
  return {
    schema=Adapter.SCHEMA, apiVersion=Adapter.API_VERSION,
    observe=function(game, weatherCode, timeOfDay)
      owner.lastGame = game
      return owner:observe(game, weatherCode, timeOfDay)
    end,
    status=function() return owner:status() end,
  }
end

return Adapter
