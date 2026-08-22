-- Real LÖVE/Gen1Recomp frame-gap probe for VASC's cold-map transition.
-- It starts on Pallet, enables 3RD with PRELOAD disabled, waits for that
-- neighbourhood, then performs either the original cold Viridian Forest
-- warp, a cold Route 4 warp, or a Route-1/Route-8 round trip. Those loops
-- compare a cold destination with its retained warm return. Every destination
-- gets a post-ready gap window, and CURRENT_READY records whether grass,
-- flowers and authored figures landed as one aux bundle. Route 8 additionally
-- records when its exact seven-map streamed union is FULL_WARM. A connected
-- map body is also forbidden from
-- entering the visible draw plan before that map's aux bundle is complete.
-- VASC_QA_SEQUENCE=center_entries separately drives both real Poké Center
-- doors cold/return/warm and emits one product draw-path certificate per
-- presented frame; VASC_QA_CENTER_STABLE_FRAMES defaults to 30.
-- VASC_QA_SEQUENCE=route8_seams accepts the fail-closed QA-only matrix knobs
-- VASC_QA_ROUTE8_START_CASE=A|B|C|D and VASC_QA_ROUTE8_PASSES=1|2. Defaults
-- retain the original ABCD/one-pass traversal.

-- Keep stack failures attributable without depending on private class-name
-- fields. Engine states use their module table as a metatable, so the source
-- of update/draw identifies TextBox, BattleState, Overworld, etc.
local function stackStateType(state)
  if state == nil then return "nil" end
  local method = type(state) == "table"
    and (state.update or state.draw or state.enter) or nil
  if type(method) == "function" and debug
     and type(debug.getinfo) == "function" then
    local info = debug.getinfo(method, "S")
    local source = tostring(info and (info.short_src or info.source) or "")
    local file = source:match("([^/\\]+%.lua)$")
    if file then return type(state) .. ":" .. file end
  end
  return type(state)
end

local function stackDepth(game)
  return game and game.stack and type(game.stack.states) == "table"
    and #game.stack.states or -1
end

local function stackIsTextBox(state)
  return type(state) == "table" and state.isTextBox == true or false
end

-- A POKEPORT_DRIVER is installed only after Game:load. Current engines can
-- therefore enter the selected QA save synchronously through their guarded
-- playtest auto-continue path before this coroutine receives Game. The exact
-- public 0.1.90 engine predates that capability and leaves the IntroMovie on
-- top instead. This small QA-only state machine drives the same fresh button
-- edges a player would use: skip the movie, wait for the interactive title,
-- select the real (possibly localized) CONTINUE row, confirm ContinueInfo,
-- and accept success only after TitleState.onContinue has restored Overworld.
-- It deliberately has no SaveData, restoreSave, setMap or stack mutation path.
local function qaBootStateKind(state)
  if type(state) ~= "table" then return "unknown" end
  local source = stackStateType(state)
  if source:match("IntroMovie%.lua$") then return "intro" end
  if source:match("YellowIntro%.lua$") then return "intro" end
  if source:match("QuarantineReport%.lua$") then
    if state.screenId == "QuarantineReport"
       and type(state.report) == "table" and type(state.lines) == "table"
       and type(state.offset) == "number"
       and type(state.maxOffset) == "function" then
      return "quarantine_report"
    end
    return "unknown"
  end
  if source:match("Menu%.lua$") and type(state.items) == "table"
     and type(state.index) == "number" then
    return "menu"
  end
  -- Kanto Ascendant 6.7 decorates TitleState.update in its Crystal-v1.5
  -- presentation layer.  Keep the legacy CONTINUE bootstrap compatible with
  -- that public wrapper without accepting an arbitrary lookalike: the exact
  -- wrapper source and the complete interactive TitleState shape are both
  -- required.  A title without an active CONTINUE callback remains closed.
  if source:match("crystal_v15_features%.lua$")
     and state.screenId == "TitleState"
     and state.isOpaque == true and type(state.game) == "table"
     and type(state.onContinue) == "function"
     and type(state.openMenu) == "function"
     and type(state.currentSprite) == "function"
     and type(state.phase) == "string"
     and type(state.cycleSpecies) == "table" then
    return "title"
  end
  if source:match("TitleState%.lua$") then
    if type(state.title) == "table" and type(state.save) == "table" then
      return "continue_info"
    end
    if type(state.openMenu) == "function" and type(state.phase) == "string" then
      return "title"
    end
  end
  return "unknown"
end

local QAContinueBootstrap = {}
QAContinueBootstrap.__index = QAContinueBootstrap

local function qaBootstrapError(code, detail)
  error("VASC_QA_BOOTSTRAP_" .. code .. " " .. tostring(detail or ""), 0)
end

local function qaBootstrapEnv(env, name)
  local value = env(name)
  if value == nil then return nil end
  return tostring(value)
end

local function newQAContinueBootstrap(game, env, options)
  env = env or os.getenv
  options = options or {}
  if type(env) ~= "function" then
    qaBootstrapError("BAD_ENV", "environment reader is not callable")
  end
  local driver = qaBootstrapEnv(env, "POKEPORT_DRIVER")
  if driver == nil or driver == "" then
    qaBootstrapError("DRIVER_REQUIRED", "POKEPORT_DRIVER is not set")
  end
  if type(game) ~= "table" or type(game.stack) ~= "table"
     or type(game.stack.top) ~= "function" or type(game.overworld) ~= "table" then
    qaBootstrapError("BAD_GAME", "Game/StateStack/Overworld is unavailable")
  end

  local current = type(game.playtestAutoContinueRequested) == "function"
  local playtest = qaBootstrapEnv(env, "POKEPORT_PLAYTEST")
  local autoContinue = qaBootstrapEnv(env, "POKEPORT_PLAYTEST_AUTO_CONTINUE")
  if current and (playtest ~= "1" or autoContinue ~= "1") then
    qaBootstrapError("CURRENT_FLAGS_REQUIRED",
      "current engine requires POKEPORT_PLAYTEST=1 and "
      .. "POKEPORT_PLAYTEST_AUTO_CONTINUE=1")
  end

  return setmetatable({
    game = game,
    mode = current and "current_auto_continue" or "legacy_continue",
    classify = options.classify or qaBootStateKind,
    continueLabel = options.continueLabel or "CONTINUE",
    emit = options.emit or print,
    maxFrames = tonumber(options.maxFrames) or 1800,
    frame = 0,
    enteredFrame = 0,
    stage = "boot",
    path = {},
    inputEdges = 0,
    done = false,
  }, QAContinueBootstrap)
end

function QAContinueBootstrap:enter(stage)
  if self.stage == stage then return end
  self.stage = stage
  self.enteredFrame = self.frame
  self.path[#self.path + 1] = stage
end

function QAContinueBootstrap:tap(button)
  local input = self.game.input
  if type(input) ~= "table" or type(input.sourcePress) ~= "function"
     or type(input.sourceRelease) ~= "function" then
    qaBootstrapError("INPUT_API_REQUIRED",
      "sourcePress/sourceRelease unavailable for " .. tostring(button))
  end
  local source = "vasc:manual-transition-bootstrap"
  input:sourcePress(button, source)
  input:sourceRelease(button, source)
  self.inputEdges = self.inputEdges + 1
end

function QAContinueBootstrap:failUnexpected(kind)
  qaBootstrapError("UNEXPECTED_STATE",
    ("mode=%s stage=%s kind=%s top=%s depth=%d frame=%d")
      :format(self.mode, self.stage, tostring(kind),
        stackStateType(self.game.stack:top()), stackDepth(self.game), self.frame))
end

function QAContinueBootstrap:finish()
  self.done = true
  self:enter("overworld")
  local line = ("VASC_QA_BOOTSTRAP mode=%s status=PASS frames=%d "
                .. "input_edges=%d path=%s")
    :format(self.mode, self.frame, self.inputEdges,
      table.concat(self.path, ">"))
  self.emit(line)
  return true, line
end

function QAContinueBootstrap:step()
  if self.done then return true end
  self.frame = self.frame + 1
  if self.frame > self.maxFrames then
    qaBootstrapError("TIMEOUT",
      ("mode=%s stage=%s frames=%d"):format(
        self.mode, self.stage, self.frame))
  end

  local top = self.game.stack:top()
  if top == self.game.overworld then
    if not self.game.overworld.map then
      qaBootstrapError("OVERWORLD_NOT_READY", "restored Overworld has no map")
    end
    if self.mode == "current_auto_continue" then
      if self.inputEdges ~= 0 then
        qaBootstrapError("CURRENT_INPUT", "current path received QA input")
      end
      return self:finish()
    end
    if self.stage ~= "continue_confirmed"
       and self.stage ~= "quarantine_acknowledged" then
      qaBootstrapError("LEGACY_CONTINUE_BYPASSED",
        "Overworld appeared before ContinueInfo confirmation")
    end
    return self:finish()
  end

  local kind = self.classify(top)
  if self.mode == "current_auto_continue" then
    qaBootstrapError("CURRENT_AUTO_CONTINUE_FAILED",
      ("expected restored Overworld, got %s (%s)")
        :format(tostring(kind), stackStateType(top)))
  end

  if kind == "intro" then
    if self.stage ~= "boot" and self.stage ~= "intro_requested" then
      return self:failUnexpected(kind)
    end
    if self.stage == "boot" then
      self:enter("intro_requested")
      self:tap("start")
    elseif self.frame - self.enteredFrame > 180 then
      qaBootstrapError("INTRO_STALLED", "skip did not reach TitleState")
    end
    return false
  end

  if kind == "title" then
    if self.stage == "boot" or self.stage == "intro_requested" then
      self:enter("title")
    elseif self.stage ~= "title" and self.stage ~= "title_requested" then
      return self:failUnexpected(kind)
    end
    if top.phase == "loop" and self.stage == "title" then
      self:enter("title_requested")
      self:tap("start")
    elseif self.stage == "title_requested"
       and self.frame - self.enteredFrame > 8 then
      qaBootstrapError("TITLE_STALLED", "START did not open the main menu")
    elseif self.stage == "title" and self.frame - self.enteredFrame > 900 then
      qaBootstrapError("TITLE_NOT_INTERACTIVE",
        "TitleState never reached phase=loop")
    end
    return false
  end

  if kind == "menu" then
    if self.stage == "title_requested" then
      self:enter("menu")
    elseif self.stage ~= "menu" and self.stage ~= "menu_confirmed" then
      return self:failUnexpected(kind)
    end
    if self.stage == "menu_confirmed" then
      if self.frame - self.enteredFrame > 8 then
        qaBootstrapError("MENU_STALLED", "CONTINUE did not open ContinueInfo")
      end
      return false
    end

    local continueIndex
    for index, item in ipairs(top.items) do
      if type(item) == "table" and item.label == self.continueLabel then
        if continueIndex then
          qaBootstrapError("AMBIGUOUS_CONTINUE", "duplicate CONTINUE rows")
        end
        continueIndex = index
      end
    end
    if not continueIndex then
      qaBootstrapError("CONTINUE_MISSING",
        "active save row not present in title menu")
    end
    if top.index == continueIndex then
      self:enter("menu_confirmed")
      self:tap("a")
    elseif top.index < continueIndex then
      self:tap("down")
    else
      self:tap("up")
    end
    return false
  end

  if kind == "continue_info" then
    if self.stage ~= "menu_confirmed" then
      return self:failUnexpected(kind)
    end
    self:enter("continue_confirmed")
    self:tap("a")
    return false
  end

  if kind == "quarantine_report" then
    if self.stage ~= "continue_confirmed" then
      return self:failUnexpected(kind)
    end
    local states = self.game.stack.states
    if type(states) ~= "table" or #states ~= 2
       or states[1] ~= self.game.overworld or states[2] ~= top
       or not self.game.overworld.map then
      qaBootstrapError("QUARANTINE_STACK",
        ("expected restored Overworld beneath report, depth=%d map=%s")
          :format(stackDepth(self.game),
            tostring(self.game.overworld.map and self.game.overworld.map.id)))
    end
    self:enter("quarantine_acknowledged")
    self:tap("a")
    return false
  end

  return self:failUnexpected(kind)
end

local function requireOverworldTop(game, ow, label, phase, cell, frame)
  local top = game.stack:top()
  if top == ow then return true end
  error(("VASC_QA_%s_STACK_LOST phase=%s cell=%s frame=%s "
         .. "top=%s is_textbox=%s depth=%d engaging=%s emote=%s")
    :format(label, tostring(phase), tostring(cell), tostring(frame),
      stackStateType(top), tostring(stackIsTextBox(top)), stackDepth(game),
      tostring(ow.engaging == true), tostring(ow.emote ~= nil)), 0)
end

local function requireSyntheticIdle(game, ow, label, phase, cell, frame)
  requireOverworldTop(game, ow, label, phase, cell, frame)
  local player = ow.player
  if not ow.engaging and not ow.emote
     and not (player and player.moving) then return true end
  error(("VASC_QA_%s_WORLD_BUSY phase=%s cell=%s frame=%s "
         .. "top=%s is_textbox=%s depth=%d engaging=%s emote=%s "
         .. "player_moving=%s")
    :format(label, tostring(phase), tostring(cell), tostring(frame),
      stackStateType(game.stack:top()),
      tostring(stackIsTextBox(game.stack:top())), stackDepth(game),
      tostring(ow.engaging == true), tostring(ow.emote ~= nil),
      tostring(player and player.moving == true or false)), 0)
end

local function syntheticTrainerSight() return false end
local function syntheticHandleInput() return nil end

local SYNTHETIC_WILDS_INACTIVE_MAP = {
  SAFFRON_CITY = true,
  LAVENDER_TOWN = true,
}

local function syntheticWildReceiptMode(logic, ow)
  local state = type(logic) == "table" and logic.state or nil
  local mapId = ow and ow.map and ow.map.id
  if not mapId or type(state) ~= "table"
     or type(logic.entities) ~= "table"
     or logic.activeMapId ~= mapId or state.mapId ~= mapId then
    return nil
  end
  if state.initialized == true then
    if mapId == "ROUTE_8" and state.mapSupported == true
       and state.pipelineVerified == true
       and state.fallbackToVanilla == false
       and state.unsupportedReason == nil and state.lastError == nil then
      return "ACTIVE"
    end
    return nil
  end
  if state.initialized == false
     and SYNTHETIC_WILDS_INACTIVE_MAP[mapId]
     and next(logic.entities) == nil and logic.pendingBattle == nil
     and state.mapSupported == false
     and state.encounterDataAvailable == false
     and state.pipelineVerified == false
     and state.vanillaSuppressed == false
     and state.fallbackToVanilla == true and state.phase == "idle"
     and state.encounterSource == "none"
     and state.unsupportedReason == "no supported encounter surface"
     and state.lastError == nil and state.assetError == nil then
    return "INACTIVE"
  end
  return nil
end

-- The Route-8 predictor probe assigns standing cells directly. Kanto
-- Ascendant's bundled Wilds sees those synthetic coordinates during its real
-- render-pipeline AI tick; an aggressive entity can otherwise mistake one
-- artificial frame for player movement and open an alert/chase sequence.
-- Resolve only the exact bundled export used by the RC identity. A missing
-- Kanto mod is a supported generic-driver case, but a present, malformed or
-- substituted Kanto Wilds surface fails closed before any frame is changed.
local function resolveSyntheticWildSightProvider(game, ow)
  local exports = game and game.mods and game.mods.exports
  local kanto = exports and exports.kanto_ascendant
  if kanto == nil then return nil end
  local internal = type(kanto) == "table" and kanto.internalWilds or nil
  local public = type(internal) == "table" and internal.exports or nil
  local logic = type(public) == "table" and public.logic or nil
  local behaviorTick = type(public) == "table" and public.behaviorTick or nil
  local state = type(logic) == "table" and logic.state or nil
  local mapId = ow and ow.map and ow.map.id
  if type(internal) ~= "table" or internal.bundled ~= true
     or internal.source ~= "bundled" or internal.version ~= "1.12.2"
     or type(public) ~= "table" or public.version ~= "1.12.2"
     or public.bundledBy ~= "kanto_ascendant"
     or type(logic) ~= "table" or type(logic.entities) ~= "table"
     or type(state) ~= "table"
     or type(behaviorTick) ~= "table" or behaviorTick.logic ~= logic
     or not mapId or logic.activeMapId ~= mapId
     or state.mapId ~= mapId then
    error("VASC_QA_SYNTHETIC_WILDS_CONTRACT expected bundled internalWilds "
          .. "1.12.2 live-map logic receipt", 0)
  end
  local receiptMode = syntheticWildReceiptMode(logic, ow)
  if not receiptMode then
    error("VASC_QA_SYNTHETIC_WILDS_CONTRACT invalid active/inactive "
          .. "live-map receipt", 0)
  end

  -- City maps without an encounter surface deliberately leave Wilds idle.
  -- Its behavior tick returns before LOS in this exact state, so installing a
  -- Behavior override would add work that the real frame never performs.
  if receiptMode == "INACTIVE" then
    return logic, nil, nil, receiptMode
  end

  local lib = public.lib
  local requireBehavior = type(lib) == "table" and lib.require or nil
  local ok, behavior = false, nil
  if type(requireBehavior) == "function" then
    ok, behavior = pcall(requireBehavior, "behavior")
  end
  if state.initialized ~= true or state.lastError ~= nil
     or not ok or type(behavior) ~= "table"
     or type(behavior.playerInSight) ~= "function"
     or behavior.AGGRESSIVE ~= "AGGRESSIVE" then
    error("VASC_QA_SYNTHETIC_WILDS_CONTRACT expected initialized logic "
          .. "and Behavior.playerInSight", 0)
  end
  return logic, behavior, behavior.playerInSight, receiptMode
end

local WILDS_BUSY_STATE = {
  PLAYER_DETECTED = true, PLAYER_NOTICED = true, ALERT = true,
  CHASE_START = true, CHASING = true, BATTLE_PENDING = true,
  IN_BATTLE = true, CLEANUP = true,
}

local WILDS_BUSY_ENTITY_STATE = {
  encounter_starting = true, in_battle = true,
  ENCOUNTER_STARTING = true, IN_BATTLE = true,
}

local function requireSyntheticWildIdle(logic, label, phase, cell, frame,
                                        ow, receiptMode)
  if not logic then return true end
  if receiptMode
     and syntheticWildReceiptMode(logic, ow) ~= receiptMode then
    error(("VASC_QA_%s_WILDS_STATE_DRIFT phase=%s cell=%s frame=%s "
           .. "expected=%s active_map=%s live_map=%s initialized=%s")
      :format(label, tostring(phase), tostring(cell), tostring(frame),
        tostring(receiptMode), tostring(logic.activeMapId),
        tostring(ow and ow.map and ow.map.id),
        tostring(logic.state and logic.state.initialized)), 0)
  end
  if logic.pendingBattle ~= nil then
    error(("VASC_QA_%s_WILDS_BUSY phase=%s cell=%s frame=%s "
           .. "pending_battle=true")
      :format(label, tostring(phase), tostring(cell), tostring(frame)), 0)
  end
  for id, entity in pairs(logic.entities) do
    local state = type(entity) == "table" and entity.behaviorState or nil
    local stateName = type(state) == "table" and state.state or nil
    local entityState = type(entity) == "table" and entity.state or nil
    if type(state) == "table"
       and (WILDS_BUSY_STATE[stateName] or state.playerDetected
         or state.alertEmoteSpawned or state.alertAt ~= nil
         or state.chaseReady or state.chasing
         or state.battlePending or state.battleStarted
         or (type(state.safariFlee) == "table"
           and state.safariFlee.noticedPlayer)) then
      error(("VASC_QA_%s_WILDS_BUSY phase=%s cell=%s frame=%s "
             .. "id=%s state=%s detected=%s alert=%s chase=%s battle=%s")
        :format(label, tostring(phase), tostring(cell), tostring(frame),
          tostring(id),
          tostring(stateName), tostring(state.playerDetected == true),
          tostring(state.alertEmoteSpawned == true or state.alertAt ~= nil),
          tostring(state.chaseReady == true or state.chasing == true),
          tostring(state.battlePending == true
            or state.battleStarted == true)), 0)
    end
    if WILDS_BUSY_ENTITY_STATE[entityState]
       or (type(entity) == "table"
         and (entity.battlePending or entity.battleStarted)) then
      error(("VASC_QA_%s_WILDS_BUSY phase=%s cell=%s frame=%s "
             .. "id=%s entity_state=%s entity_battle=%s")
        :format(label, tostring(phase), tostring(cell), tostring(frame),
          tostring(id), tostring(entityState),
          tostring(entity.battlePending == true
            or entity.battleStarted == true)), 0)
    end
  end
  return true
end

local function syntheticWildEntityId(logic, wanted)
  for id, entity in pairs(logic and logic.entities or {}) do
    if entity == wanted then return true, id end
  end
  return false, nil
end

local SyntheticFrameGuard = {}
SyntheticFrameGuard.__index = SyntheticFrameGuard

function SyntheticFrameGuard:install(cell, frame)
  if self.installed then
    error("VASC_QA_" .. self.label
          .. " synthetic frame guard installed twice", 0)
  end
  requireSyntheticIdle(self.game, self.ow, self.label,
                       "pre-yield", cell, frame)
  requireSyntheticWildIdle(
    self.wildsLogic, self.label, "pre-yield", cell, frame,
    self.ow, self.wildsReceiptMode)
  if self.wildsBehavior
     and self.wildsBehavior.playerInSight ~= self.wildSightOriginal then
    error("VASC_QA_" .. self.label
          .. "_WILDS_SIGHT_PROVIDER_DRIFT before synthetic frame", 0)
  end
  self.ow.checkTrainerSight = syntheticTrainerSight
  self.ow.handleInput = syntheticHandleInput
  if self.wildsBehavior then
    self.wildsBehavior.playerInSight = self.wildSightWrapper
  end
  self.installed = true
  return true
end

function SyntheticFrameGuard:restore()
  if not self.installed then return false end
  self.ow.checkTrainerSight = self.priorTrainerSight
  self.ow.handleInput = self.priorHandleInput
  local providerDrift = false
  if self.wildsBehavior then
    providerDrift = self.wildsBehavior.playerInSight
                    ~= self.wildSightWrapper
    if not providerDrift then
      self.wildsBehavior.playerInSight = self.wildSightOriginal
    end
  end
  self.installed = false
  if providerDrift then
    error("VASC_QA_" .. self.label
          .. "_WILDS_SIGHT_PROVIDER_DRIFT during synthetic frame", 0)
  end
  return true
end

-- Own one pair of constant no-op functions for the whole approach. Reusing
-- the guard avoids allocating closures in the frame-gap/GC measurement loop.
local function newSyntheticFrameGuard(game, ow, label)
  local wildsLogic, wildsBehavior, wildSightOriginal, wildsReceiptMode =
    resolveSyntheticWildSightProvider(game, ow)
  local guard = setmetatable({
    game = game,
    ow = ow,
    label = label,
    priorTrainerSight = rawget(ow, "checkTrainerSight"),
    priorHandleInput = rawget(ow, "handleInput"),
    wildsLogic = wildsLogic,
    wildsBehavior = wildsBehavior,
    wildSightOriginal = wildSightOriginal,
    wildsReceiptMode = wildsReceiptMode,
    wildSightSuppressed = 0,
    installed = false,
  }, SyntheticFrameGuard)
  if wildSightOriginal then
    -- Keep the real LOS work in the measured frame; discard only the result
    -- produced from the probe's synthetic player coordinate. One closure is
    -- cached for the entire approach and restored after every yielded frame.
    guard.wildSightWrapper = function(entity, player, map, entities,
                                      range, opts)
      local result = wildSightOriginal(
        entity, player, map, entities, range, opts)
      if result ~= true and result ~= false then
        error("VASC_QA_" .. label
              .. "_WILDS_SIGHT_NON_BOOLEAN result=" .. tostring(result), 0)
      end
      if not result then return false end
      if syntheticWildReceiptMode(wildsLogic, ow) ~= "ACTIVE" then
        error("VASC_QA_" .. label
              .. "_WILDS_STATE_DRIFT during LOS result", 0)
      end
      local owned, entityId = syntheticWildEntityId(wildsLogic, entity)
      local state = type(entity) == "table" and entity.behaviorState or nil
      local behaviorName = type(state) == "table" and state.behavior or nil
      if player ~= ow.player or map ~= ow.map
         or entities ~= ow.entities
         or not (map and wildsLogic.activeMapId == map.id
           and wildsLogic.state.initialized == true)
         or map.id ~= "ROUTE_8" or not owned
         or behaviorName ~= wildsBehavior.AGGRESSIVE
         or entity.behavior ~= wildsBehavior.AGGRESSIVE
         or entity.surface ~= "GRASS" then
        error(("VASC_QA_%s_WILDS_SIGHT_UNEXPECTED_TRUE id=%s owned=%s "
               .. "behavior=%s entity_behavior=%s surface=%s "
               .. "player_live=%s map_live=%s entities_live=%s active_map=%s")
          :format(label, tostring(entityId), tostring(owned),
            tostring(behaviorName), tostring(entity.behavior),
            tostring(entity.surface), tostring(player == ow.player),
            tostring(map == ow.map), tostring(entities == ow.entities),
            tostring(wildsLogic.activeMapId)), 0)
      end
      guard.wildSightSuppressed = guard.wildSightSuppressed + 1
      return false
    end
  end
  return guard
end

-- The two Poké Center entry loops are intentionally data, not loose calls in
-- the sequence branch. Headless contracts pin every real source/door/landing
-- cell, and the native driver consumes the same records. The first interior
-- warp is the landing named by each route's destWarp=1; the second half of
-- the two-cell exit mat exercises the reciprocal LAST_MAP path.
local CENTER_ENTRY_SPECS = {
  {
    key = "MTMOON_CENTER", sourceMap = "ROUTE_4", sourceX = 11, sourceY = 5,
    centerMap = "MT_MOON_POKECENTER", entryX = 3, entryY = 7,
    exitX = 4, exitY = 7,
  },
  {
    key = "ROCKTUNNEL_CENTER", sourceMap = "ROUTE_10",
    sourceX = 11, sourceY = 19,
    centerMap = "ROCK_TUNNEL_POKECENTER", entryX = 3, entryY = 7,
    exitX = 4, exitY = 7,
  },
}

local function centerEntrySpecs()
  local out = {}
  for index, spec in ipairs(CENTER_ENTRY_SPECS) do
    local copy = {}
    for key, value in pairs(spec) do copy[key] = value end
    out[index] = copy
  end
  return out
end

local function centerEntryLegs(spec)
  return {
    {
      label = spec.key .. "_COLD", temperature = "cold",
      fromMap = spec.sourceMap, x = spec.sourceX, y = spec.sourceY,
      facing = "up", warpDest = spec.centerMap, toMap = spec.centerMap,
      toX = spec.entryX, toY = spec.entryY,
    },
    {
      label = spec.key .. "_RETURN", temperature = "return",
      fromMap = spec.centerMap, x = spec.exitX, y = spec.exitY,
      facing = "down", warpDest = "LAST_MAP", toMap = spec.sourceMap,
      toX = spec.sourceX, toY = spec.sourceY,
    },
    {
      label = spec.key .. "_WARM", temperature = "warm",
      fromMap = spec.sourceMap, x = spec.sourceX, y = spec.sourceY,
      facing = "up", warpDest = spec.centerMap, toMap = spec.centerMap,
      toX = spec.entryX, toY = spec.entryY,
    },
  }
end

local function asBoolFlag(value)
  return value and 1 or 0
end

-- Route 8's four reciprocal seam legs are data for the same reason as the
-- Center matrix above: the headless contract pins every source, target, lane
-- and boot coordinate consumed by native QA.  A process may rotate which leg
-- is first without inventing a teleport-only crossing, then repeat the same
-- cycle once after all four destinations have become resident.
local ROUTE8_SEAM_SPECS = {
  A = {
    key = "A", approachLabel = "ROUTE8_SAFFRON",
    seamLabel = "ROUTE8_SAFFRON_SEAM",
    sourceMap = "ROUTE_8", targetMap = "SAFFRON_CITY", direction = "left",
    crossX = 0, crossY = 9,
    bootMap = "ROUTE_8", bootX = 59, bootY = 9,
    approachFirst = 59, approachLast = 0, approachFixed = 9,
  },
  B = {
    key = "B", approachLabel = "SAFFRON_ROUTE8",
    seamLabel = "SAFFRON_ROUTE8_SEAM",
    sourceMap = "SAFFRON_CITY", targetMap = "ROUTE_8", direction = "right",
    crossX = 39, crossY = 17,
    bootMap = "SAFFRON_CITY", bootX = 0, bootY = 17,
    approachFirst = 0, approachLast = 39, approachFixed = 17,
  },
  C = {
    key = "C", approachLabel = "ROUTE8_LAVENDER",
    seamLabel = "ROUTE8_LAVENDER_SEAM",
    sourceMap = "ROUTE_8", targetMap = "LAVENDER_TOWN", direction = "right",
    crossX = 59, crossY = 8,
    bootMap = "ROUTE_8", bootX = 0, bootY = 8,
    approachFirst = 0, approachLast = 59, approachFixed = 8,
  },
  D = {
    key = "D", approachLabel = "LAVENDER_ROUTE8",
    seamLabel = "LAVENDER_ROUTE8_SEAM",
    sourceMap = "LAVENDER_TOWN", targetMap = "ROUTE_8", direction = "left",
    crossX = 0, crossY = 8,
    bootMap = "LAVENDER_TOWN", bootX = 19, bootY = 8,
    approachFirst = 19, approachLast = 0, approachFixed = 8,
  },
}
local ROUTE8_SEAM_ORDER = { "A", "B", "C", "D" }

local function copyRecord(source)
  local out = {}
  for key, value in pairs(source) do out[key] = value end
  return out
end

local function route8SeamMatrix(startCase, passes)
  startCase = startCase == nil and "A" or startCase
  passes = passes == nil and "1" or passes
  if type(startCase) ~= "string" or not ROUTE8_SEAM_SPECS[startCase] then
    error("VASC_QA_ROUTE8_SEAMS invalid START_CASE expected=A|B|C|D actual="
          .. tostring(startCase), 0)
  end
  if passes ~= "1" and passes ~= "2" then
    error("VASC_QA_ROUTE8_SEAMS invalid PASSES expected=1|2 actual="
          .. tostring(passes), 0)
  end

  local first
  for index, key in ipairs(ROUTE8_SEAM_ORDER) do
    if key == startCase then first = index break end
  end
  local legs, order = {}, {}
  for offset = 0, #ROUTE8_SEAM_ORDER - 1 do
    local key = ROUTE8_SEAM_ORDER[(first + offset - 1)
                                 % #ROUTE8_SEAM_ORDER + 1]
    legs[#legs + 1] = copyRecord(ROUTE8_SEAM_SPECS[key])
    order[#order + 1] = key
  end
  return {
    startCase = startCase,
    passes = tonumber(passes),
    order = table.concat(order),
    legs = legs,
  }
end

-- Fixed-size millisecond statistics for the trace-only GC observer.  Values
-- above 999 ms saturate into the last bin, just like the frame-gap histogram;
-- the observer therefore cannot grow with run length or manufacture its own
-- long-run GC problem.  `elapsed` is total explicit collector time for one
-- measured frame and `callMax` is the longest explicit call in that frame.
local GC_METRIC_MAX_MS = 999

local function newGCMetric(heapKB)
  heapKB = tonumber(heapKB) or 0
  return {
    frames = 0, bins = {}, calls = 0, cycles = 0,
    total = 0, frameMax = 0, callMax = 0,
    heapStart = heapKB, heapEnd = heapKB, heapPeak = heapKB,
  }
end

local function recordGCMetric(metric, elapsed, callMax, calls, cycles, heapKB)
  elapsed = math.max(0, tonumber(elapsed) or 0)
  callMax = math.max(0, tonumber(callMax) or 0)
  heapKB = tonumber(heapKB) or metric.heapEnd
  local ms = math.floor(math.min(GC_METRIC_MAX_MS, elapsed * 1000) + 0.5)
  metric.frames = metric.frames + 1
  metric.bins[ms] = (metric.bins[ms] or 0) + 1
  metric.calls = metric.calls + math.max(0, tonumber(calls) or 0)
  metric.cycles = metric.cycles + math.max(0, tonumber(cycles) or 0)
  metric.total = metric.total + elapsed
  metric.frameMax = math.max(metric.frameMax, elapsed)
  metric.callMax = math.max(metric.callMax, callMax)
  metric.heapEnd = heapKB
  metric.heapPeak = math.max(metric.heapPeak, heapKB)
  return metric
end

local function gcMetricPercentile(metric, fraction)
  if not metric or metric.frames == 0 then return 0 end
  local target = math.max(1, math.ceil(metric.frames * fraction))
  local seen = 0
  for ms = 0, GC_METRIC_MAX_MS do
    seen = seen + (metric.bins[ms] or 0)
    if seen >= target then return ms / 1000 end
  end
  return GC_METRIC_MAX_MS / 1000
end

local function gcSummaryLine(label, phase, metric, mode)
  return ("VASC_QA_%s_%s_GC_SUMMARY frames=%d calls=%d cycles=%d "
          .. "total_ms=%.3f p95_ms=%.3f p99_ms=%.3f "
          .. "frame_max_ms=%.3f call_max_ms=%.3f mode=%s "
          .. "source=explicit_collectgarbage bins=%d")
    :format(label, phase, metric.frames, metric.calls, metric.cycles,
      metric.total * 1000, gcMetricPercentile(metric, 0.95) * 1000,
      gcMetricPercentile(metric, 0.99) * 1000,
      metric.frameMax * 1000, metric.callMax * 1000,
      tostring(mode), GC_METRIC_MAX_MS + 1)
end

local function heapEndLine(label, phase, metric)
  return ("VASC_QA_%s_%s_HEAP_END start_kb=%.0f end_kb=%.0f "
          .. "peak_kb=%.0f delta_kb=%+.0f")
    :format(label, phase, metric.heapStart, metric.heapEnd,
      metric.heapPeak, metric.heapEnd - metric.heapStart)
end

local function route8PassHeapLine(index, temperature, heapKB)
  return ("VASC_QA_ROUTE8_PASS_HEAP_END index=%d temperature=%s heap_kb=%.0f")
    :format(index, tostring(temperature), tonumber(heapKB) or -1)
end

-- A pass-end heap sample cannot distinguish live retention from garbage that
-- the incremental collector has not reached yet.  This opt-in is deliberately
-- narrower than the normal trace: only the two-pass Route-8 matrix may use it,
-- and it runs after every timed crossing/window has completed.
local function route8FinalFullGCEnabled(raw, sequence, traceEnabled, passes)
  if raw == nil or raw == "0" then return false end
  if raw ~= "1" then
    error("VASC_QA_ROUTE8_FINAL_FULL_GC invalid value expected=0|1 actual="
          .. tostring(raw), 0)
  end
  if sequence ~= "route8_seams" then
    error("VASC_QA_ROUTE8_FINAL_FULL_GC requires sequence=route8_seams actual="
          .. tostring(sequence), 0)
  end
  if traceEnabled ~= true then
    error("VASC_QA_ROUTE8_FINAL_FULL_GC requires VASC_QA_TRACE=1", 0)
  end
  if passes ~= 2 then
    error("VASC_QA_ROUTE8_FINAL_FULL_GC requires VASC_QA_ROUTE8_PASSES=2",
          0)
  end
  return true
end

local function collectRoute8FinalFullGC(rawGC, clock)
  if type(rawGC) ~= "function" or type(clock) ~= "function" then
    error("VASC_QA_ROUTE8_FINAL_FULL_GC collector unavailable", 0)
  end
  local before = rawGC("count")
  local started = clock()
  rawGC("collect")
  local firstElapsed = math.max(0, clock() - started)
  local afterFirst = rawGC("count")
  started = clock()
  rawGC("collect")
  local secondElapsed = math.max(0, clock() - started)
  local afterSecond = rawGC("count")
  return {
    before = before, afterFirst = afterFirst, afterSecond = afterSecond,
    firstElapsed = firstElapsed, secondElapsed = secondElapsed,
  }
end

local function route8FinalFullGCLine(metric, pass1KB, pending)
  return ("VASC_QA_ROUTE8_FINAL_FULL_GC pass1_kb=%.0f pre_kb=%.0f "
          .. "after1_kb=%.0f after2_kb=%.0f reclaimed_kb=%+.0f "
          .. "retained_vs_pass1_kb=%+.0f collect1_ms=%.3f "
          .. "collect2_ms=%.3f pending=%d source=explicit_collectgarbage")
    :format(tonumber(pass1KB) or -1, tonumber(metric.before) or -1,
      tonumber(metric.afterFirst) or -1, tonumber(metric.afterSecond) or -1,
      (tonumber(metric.before) or -1) - (tonumber(metric.afterSecond) or -1),
      (tonumber(metric.afterSecond) or -1) - (tonumber(pass1KB) or -1),
      (tonumber(metric.firstElapsed) or 0) * 1000,
      (tonumber(metric.secondElapsed) or 0) * 1000,
      tonumber(pending) or -1)
end

local function targetCacheLine(label, status)
  local hit = status.found and status.body and status.aux and status.atlas
              and status.planned and status.planReady
              and not status.planPending and status.planResumes == 0
  return ("VASC_QA_%s_TARGET_CACHE target=%s found=%d body=%d aux=%d "
          .. "atlas=%d plan=%d plan_ready=%d plan_pending=%d "
          .. "plan_resumes=%d plan_maps=%d hit=%d")
    :format(label, tostring(status.target), asBoolFlag(status.found),
      asBoolFlag(status.body), asBoolFlag(status.aux), asBoolFlag(status.atlas),
      asBoolFlag(status.planned), asBoolFlag(status.planReady),
      asBoolFlag(status.planPending), tonumber(status.planResumes) or -1,
      tonumber(status.planMaps) or -1, asBoolFlag(hit))
end

local function transitionStackType(value)
  -- Exact 0.1.90 has no revealReady pipeline hook, so VASC's supported compat
  -- path replaces Transition.update with the wrapper defined in
  -- lib/TransitionReveal.lua. stackStateType consequently reports that
  -- wrapper's source while the state, stack ownership and gameplay transition
  -- remain the engine's real Transition instance. Keep this an exact basename
  -- allowlist: similarly named QA covers or arbitrary transition states do not
  -- count toward the Center product-frame certificate.
  local source = tostring(value or "")
  return source == "table:Transition.lua"
      or source == "table:TransitionReveal.lua"
end

-- Classify only the product-visible part of a real warp frame. A single
-- alpha=1 interval is the engine's own Transition midpoint, not a QA cover
-- and not a black-screen defect. A cold product pipeline may hold that exact
-- midpoint for several frames; at every lesser alpha the world is visible, so
-- the selected voxel pipeline must have returned the exact current-map 3D
-- scene; otherwise the renderer is exposing its ordinary bird's-eye fallback.
-- `black` is a missing world-composite path while visible. Pixel aesthetics
-- remain screenshot QA; this certifies the actual product draw ownership.
local function classifyCenterEntryFrame(row)
  local fade = tonumber(row.fadeAlpha) or 0
  local productBlack = fade >= 0.999
  local visible = not productBlack
  local render3d = row.renderCalled == true and row.renderCanvas == true
    and row.renderMap == row.map and row.pipelineId == "voxel"
    and row.pipelineCanvas == true and row.worldOverride == true
  return {
    productBlack = productBlack,
    visible = visible,
    render3d = render3d,
    birdseye = visible and not render3d,
    black = visible and row.worldActive ~= true,
    qaCover = row.qaCover == true,
    wrongLevel = row.pipelineLevel ~= row.expectedLevel,
  }
end

local function summarizeCenterEntryFrames(rows, expected)
  local out = {
    frames = 0, transition = 0, productBlack = 0, visible3d = 0,
    birdseye = 0, black = 0, qaCover = 0, wrongLevel = 0,
    fromFrames = 0, toFrames = 0, targetUnderTransition = 0,
    targetLanding = 0, finalReady3d = 0,
  }
  for _, row in ipairs(rows or {}) do
    local class = classifyCenterEntryFrame(row)
    out.frames = out.frames + 1
    if transitionStackType(row.top) then out.transition = out.transition + 1 end
    if class.productBlack then out.productBlack = out.productBlack + 1 end
    if class.visible and class.render3d then out.visible3d = out.visible3d + 1 end
    if class.birdseye then out.birdseye = out.birdseye + 1 end
    if class.black then out.black = out.black + 1 end
    if class.qaCover then out.qaCover = out.qaCover + 1 end
    if class.wrongLevel then out.wrongLevel = out.wrongLevel + 1 end
    if row.map == expected.fromMap then out.fromFrames = out.fromFrames + 1 end
    if row.map == expected.toMap then
      out.toFrames = out.toFrames + 1
      if row.cellX == expected.toX and row.cellY == expected.toY then
        out.targetLanding = out.targetLanding + 1
      end
      if transitionStackType(row.top) then
        out.targetUnderTransition = out.targetUnderTransition + 1
      end
      if row.stackCurrent == true and row.ready == true
         and class.visible and class.render3d then
        out.finalReady3d = out.finalReady3d + 1
      end
    end
  end
  out.pass = out.frames > 0 and out.transition > 0
    and out.productBlack > 0 and out.fromFrames > 0 and out.toFrames > 0
    and out.targetUnderTransition > 0 and out.targetLanding > 0
    and out.finalReady3d > 0
    and out.birdseye == 0 and out.black == 0 and out.qaCover == 0
    and out.wrongLevel == 0
  return out
end

local function centerEntryFrameLine(label, row, class)
  class = class or classifyCenterEntryFrame(row)
  return ("VASC_QA_%s_FRAME frame=%d temperature=%s "
          .. "product_pipeline=%s pipeline_level=%s top=%s map=%s "
          .. "cell=%s,%s ready=%d render_called=%d render_map=%s render3d=%d "
          .. "world_active=%d world_override=%d fade=%.3f "
          .. "product_black=%d qa_cover=%d birdseye=%d black=%d")
    :format(label, tonumber(row.frame) or -1, tostring(row.temperature),
      tostring(row.pipelineId or "none"), tostring(row.pipelineLevel),
      tostring(row.top), tostring(row.map), tostring(row.cellX),
      tostring(row.cellY), asBoolFlag(row.ready),
      asBoolFlag(row.renderCalled), tostring(row.renderMap or "none"),
      asBoolFlag(class.render3d), asBoolFlag(row.worldActive),
      asBoolFlag(row.worldOverride), tonumber(row.fadeAlpha) or 0,
      asBoolFlag(class.productBlack), asBoolFlag(class.qaCover),
      asBoolFlag(class.birdseye), asBoolFlag(class.black))
end

local function run(game)
  local continueLabel = require("src.core.Strings")("CONTINUE")
  local bootstrap = newQAContinueBootstrap(game, os.getenv, {
    continueLabel = continueLabel,
  })
  while not bootstrap:step() do
    coroutine.yield()
  end

  local id = "VOXEL_ASCENDANT"
  local shadowQA = string.lower(os.getenv("VASC_QA_SHADOWS") or "off") == "on"
  local values = {
    preload = false,
    scenery = "full",
    shadows = shadowQA,
    weather = os.getenv("VASC_QA_WEATHER") or "fog",
    sky = "full",
    clouds = "on",
  }
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions[id] = values
  game.mods.modOptions = game.mods.modOptions or {}
  game.mods.modOptions[id] = values

  local Pipelines = require("src.render.Pipelines")
  local targetLevel = tonumber(os.getenv("VASC_QA_VOXEL_LEVEL"))
                      or 7
  Pipelines.setLevel("voxel", 0)
  Pipelines.setLevel("tiltshift", 0)
  Pipelines.syncOptions(game.save.options)

  -- Exercise the real option-row closures so already-read ModSetting caches
  -- see the QA values too.
  local Runtime = require("src.mods.Runtime")
  local rows = Runtime.call("ui.options.rows", function(_, base) return base end,
                            game, {})
  local wanted = {
    preload = "OFF", scenery = "FULL",
    shadows = shadowQA and "ON" or "OFF",
    weather = string.upper(values.weather), sky = "FULL", clouds = "ON",
  }
  for _, row in ipairs(rows or {}) do
    local key = row.id and row.id:match("^" .. id .. ":(.+)$")
    if key and wanted[key] then
      for _ = 1, 10 do
        if row.value(game) == wanted[key] then break end
        row.step(game, 1)
      end
    end
  end

  local ow = game.overworld
  ow:setMap("PALLET_TOWN", 10, 12, "up")
  for _ = 1, 3 do coroutine.yield() end
  Pipelines.setLevel("voxel", targetLevel) -- 7 = 3RD; 0 = baseline 2D
  Pipelines.syncOptions(game.save.options)

  local exports = game.mods and game.mods.exports
                  and game.mods.exports[id]
  local Voxel = exports and exports.lib and exports.lib.require
                and exports.lib.require("VoxelState")
  if not Voxel then error("VASC_QA_TRANSITION missing VoxelState export") end
  local Scene = exports.lib.require("VoxelScene")
  local Voxel3D = exports.lib.require("Voxel3D")
  local sequence = string.lower(os.getenv("VASC_QA_SEQUENCE") or "forest")

  -- These build modules are deliberately absent from VASC's hardened public
  -- facade. This driver is an in-process diagnostic, so inspect the
  -- already-loaded VoxelScene closure instead of weakening that production
  -- boundary. Fail hard if any private dependency cannot be observed:
  -- Voxel.ready marks the first complete CURRENT scene, while this probe also
  -- has to distinguish that from the complete streamed union becoming warm.
  local Mesher, Atlas, Horizon
  if debug and type(debug.getupvalue) == "function" then
    for index = 1, 64 do
      local name, value = debug.getupvalue(Scene.prefetch, index)
      if not name then break end
      if name == "ChunkMesher" then Mesher = value end
      if name == "TerrainAtlas" then Atlas = value end
      if name == "HorizonWall" then Horizon = value end
    end
  end
  if type(Mesher) ~= "table" or type(Mesher.ready) ~= "function"
     or type(Mesher.auxReady) ~= "function"
     or type(Mesher.pending) ~= "function"
     or type(Atlas) ~= "table" or type(Atlas.prepared) ~= "function"
     or type(Horizon) ~= "table"
     or type(Horizon.preferBody) ~= "function"
     or type(Horizon.buildStatus) ~= "function" then
    error("VASC_QA_TRANSITION cannot observe private union build state")
  end

  -- Optional phase sampler for long but frame-budget-clean cold builds. A
  -- p95 near 16 ms can still hide hundreds of cooperative resumes; sampling
  -- the suspended coroutine after each pump identifies which deterministic
  -- phase consumed those frames without enabling an instruction hook or
  -- perturbing production code. The table is bounded by source sites.
  local phaseProfileEnabled = os.getenv("VASC_QA_PHASE_PROFILE") == "1"
  local phaseProfileReset, phaseProfilePrint
  if phaseProfileEnabled and debug and type(debug.getupvalue) == "function"
     and type(debug.getinfo) == "function" then
    local rawPhasePump = Mesher.pump
    local phaseJobs
    for index = 1, 64 do
      local name, value = debug.getupvalue(rawPhasePump, index)
      if not name then break end
      if name == "jobs" then phaseJobs = value break end
    end
    if type(phaseJobs) ~= "table" then
      error("VASC_QA_PHASE_PROFILE cannot observe mesher jobs")
    end

    local rows = {}
    local function phaseSite(job)
      if not (job and job.co and coroutine.status(job.co) == "suspended") then
        return "complete"
      end
      for level = 1, 32 do
        local info = debug.getinfo(job.co, level, "Sl")
        if not info then break end
        local src = tostring(info.short_src or info.source or "")
        if src:find("ChunkMesher.lua", 1, true)
           or src:find("Structures.lua", 1, true)
           or src:find("Buildings.lua", 1, true)
           or src:find("LedgeElevation.lua", 1, true) then
          local file = src:match("([^/\\]+%.lua)$") or src
          return ("%s:%d"):format(file, tonumber(info.currentline) or -1)
        end
      end
      return "unknown"
    end

    local function selectedJob()
      local firstPriority, firstPriorityRank, firstLive
      for _, job in ipairs(phaseJobs) do
        if job.urgent then return job end
        local rank = type(job.priority) == "number" and job.priority
                     or (job.priority and 1 or 0)
        if job.live and rank > (firstPriorityRank or 0) then
          firstPriority, firstPriorityRank = job, rank
        end
        if job.live and not firstLive then firstLive = job end
      end
      return firstPriority or firstLive or phaseJobs[1]
    end

    Mesher.pump = function(...)
      local picked = selectedJob()
      local started = love.timer.getTime()
      local result = rawPhasePump(...)
      local elapsed = love.timer.getTime() - started
      local site = phaseSite(picked)
      local key = table.concat({ tostring(picked and picked.id or "none"),
        tostring(picked and picked.slot or "none"), site }, "|")
      local row = rows[key]
      if not row then
        row = { id = tostring(picked and picked.id or "none"),
                slot = tostring(picked and picked.slot or "none"),
                site = site, calls = 0, elapsed = 0 }
        rows[key] = row
      end
      row.calls, row.elapsed = row.calls + 1, row.elapsed + elapsed
      return result
    end

    phaseProfileReset = function() rows = {} end
    local profileBuildings
    if exports and exports.lib and exports.lib.require then
      local ok, value = pcall(exports.lib.require, "Buildings")
      if ok and type(value) == "table" and type(value.stats) == "function" then
        profileBuildings = value
      end
    end
    -- Hardened release facades intentionally reject Buildings. Follow the
    -- already-loaded private dependency chain instead of weakening exports:
    -- geometry -> runGeometry -> Structures.forMap -> Buildings.
    if not profileBuildings then
      local runGeometry
      for index = 1, 64 do
        local name, value = debug.getupvalue(Mesher.geometry, index)
        if not name then break end
        if name == "runGeometry" then runGeometry = value break end
      end
      local structures
      if type(runGeometry) == "function" then
        for index = 1, 64 do
          local name, value = debug.getupvalue(runGeometry, index)
          if not name then break end
          if name == "Structures" then structures = value break end
        end
      end
      if type(structures) == "table" and type(structures.forMap) == "function" then
        for index = 1, 64 do
          local name, value = debug.getupvalue(structures.forMap, index)
          if not name then break end
          if name == "Buildings" and type(value) == "table"
             and type(value.stats) == "function" then
            profileBuildings = value
            break
          end
        end
      end
    end
    if profileBuildings and type(profileBuildings.diagnostics) == "function" then
      profileBuildings.diagnostics(true)
    end
    phaseProfilePrint = function(label)
      local ordered = {}
      for _, row in pairs(rows) do ordered[#ordered + 1] = row end
      table.sort(ordered, function(a, b)
        if a.elapsed ~= b.elapsed then return a.elapsed > b.elapsed end
        return a.calls > b.calls
      end)
      local limit = math.min(16, #ordered)
      for index = 1, limit do
        local row = ordered[index]
        print(("VASC_QA_%s_PHASE rank=%d job=%s:%s site=%s "
               .. "calls=%d elapsed=%.3f")
          :format(label, index, row.id, row.slot, row.site,
                  row.calls, row.elapsed))
      end
      if profileBuildings then
        local totalModels, totalVoxels, totalShell, totalQuads = 0, 0, 0, 0
        local modelRows = {}
        for key, stat in pairs(profileBuildings.stats()) do
          local model = { key = key, voxels = tonumber(stat.voxels) or 0,
                          shell = tonumber(stat.shell) or 0,
                          quads = tonumber(stat.quads) or 0 }
          modelRows[#modelRows + 1] = model
          totalModels = totalModels + 1
          totalVoxels = totalVoxels + model.voxels
          totalShell = totalShell + model.shell
          totalQuads = totalQuads + model.quads
        end
        table.sort(modelRows, function(a, b)
          if a.quads ~= b.quads then return a.quads > b.quads end
          return a.key < b.key
        end)
        print(("VASC_QA_%s_BUILDING_TOTAL models=%d voxels=%d shell=%d quads=%d")
          :format(label, totalModels, totalVoxels, totalShell, totalQuads))
        for index = 1, math.min(16, #modelRows) do
          local model = modelRows[index]
          print(("VASC_QA_%s_BUILDING rank=%d key=%s voxels=%d shell=%d quads=%d")
            :format(label, index, model.key, model.voxels,
                    model.shell, model.quads))
        end
      end
    end
  end

  -- A neighbour is visible precisely when VoxelScene includes it in the
  -- private draw plan returned by prefetch(). Seeing its terrain one frame
  -- before grass/flowers/figures is the pop-in this driver exists to catch.
  -- Record violations during a destination window and fail the process after
  -- the complete requested sequence, so a Route-1 round trip still yields all
  -- three READY/STABLE samples even when its cold leg exposes a regression.
  local popinWindow, popinExpectedMap, popinSeen, popinViolations
  local latestPlan, latestPlanMap
  local runViolations = {}
  local centerFrameAudit, centerFrameStamp, centerFrameSerial = nil, {}, 0
  local centerAuditSummaries = {}

  -- Center-entry evidence is deliberately dormant for every existing
  -- transition sequence. When selected, wrap the same production calls the
  -- frame uses and take the stamp at Renderer:endFrame, after Overworld and
  -- Transition have both drawn but before Renderer clears its one-frame
  -- worldOverride/fade state. There is no screenshot mask or QA cover here.
  local centerSequence = sequence == "center_entries"
  if centerSequence then
    local scriptedSpeed = tonumber(os.getenv("POKEPORT_SPEED") or "1")
    if scriptedSpeed ~= 1 then
      error("VASC_QA_CENTER_ENTRIES requires POKEPORT_SPEED=1", 0)
    end

    local rawCenterRender = Scene.render
    Scene.render = function(state, ...)
      centerFrameStamp.renderCalled = true
      centerFrameStamp.renderMap = state and state.map and state.map.id or nil
      local out = rawCenterRender(state, ...)
      if out ~= nil then centerFrameStamp.renderCanvas = true end
      return out
    end

    local rawCenterDrawWorld = Pipelines.drawWorld
    Pipelines.drawWorld = function(pipelineId, ctx)
      centerFrameStamp.pipelineId = pipelineId
      centerFrameStamp.pipelineLevel = ctx and ctx.level
                                or Pipelines.level(pipelineId)
      local out = rawCenterDrawWorld(pipelineId, ctx)
      if out ~= nil then centerFrameStamp.pipelineCanvas = true end
      return out
    end

    local renderer = assert(game.renderer,
                            "VASC_QA_CENTER_ENTRIES missing renderer")
    local rawCenterEndFrame = renderer.endFrame
    renderer.endFrame = function(self, ...)
      local audit, row = centerFrameAudit, nil
      if audit then
        centerFrameSerial = centerFrameSerial + 1
        local top = game.stack:top()
        row = {
          frame = centerFrameSerial,
          temperature = audit.temperature,
          expectedLevel = audit.expectedLevel,
          pipelineId = centerFrameStamp.pipelineId,
          pipelineLevel = centerFrameStamp.pipelineLevel
                          or Pipelines.level("voxel"),
          top = stackStateType(top), stackCurrent = top == ow,
          map = ow.map and ow.map.id or nil, ready = Voxel.ready == true,
          cellX = ow.player and ow.player.cellX or nil,
          cellY = ow.player and ow.player.cellY or nil,
          renderCalled = centerFrameStamp.renderCalled == true,
          renderCanvas = centerFrameStamp.renderCanvas == true,
          renderMap = centerFrameStamp.renderMap,
          pipelineCanvas = centerFrameStamp.pipelineCanvas == true,
          worldActive = self.worldActive == true,
          worldOverride = self.worldOverride ~= nil,
          fadeAlpha = tonumber(self.worldFadeAlpha) or 0,
          qaCover = false,
        }
      end
      local out = rawCenterEndFrame(self, ...)
      -- Only a frame whose real product composite completed is evidence.
      if row then
        audit.rows[#audit.rows + 1] = row
        print(centerEntryFrameLine(audit.label, row))
      end
      centerFrameStamp = {}
      return out
    end
  end

  local function beginCenterFrameAudit(leg)
    if not centerSequence then return end
    if centerFrameAudit then
      error("VASC_QA_CENTER_ENTRIES nested frame audit", 0)
    end
    centerFrameSerial = 0
    centerFrameStamp = {}
    centerFrameAudit = {
      label = leg.label, temperature = leg.temperature,
      expectedLevel = targetLevel, fromMap = leg.fromMap, toMap = leg.toMap,
      toX = leg.toX, toY = leg.toY, rows = {},
    }
    print(("VASC_QA_%s_FRAME_BEGIN temperature=%s from=%s to=%s "
           .. "pipeline=voxel level=%d qa_cover=0")
      :format(leg.label, leg.temperature, leg.fromMap, leg.toMap, targetLevel))
  end

  local function finishCenterFrameAudit()
    if not centerFrameAudit then return nil end
    local audit = centerFrameAudit
    centerFrameAudit = nil
    local summary = summarizeCenterEntryFrames(audit.rows, audit)
    centerAuditSummaries[#centerAuditSummaries + 1] = summary
    print(("VASC_QA_%s_FRAME_CERT status=%s frames=%d transition=%d "
           .. "product_black=%d visible_3d=%d from_frames=%d to_frames=%d "
           .. "target_under_transition=%d target_landing=%d final_ready_3d=%d "
           .. "birdseye=%d black=%d qa_cover=%d wrong_level=%d")
      :format(audit.label, summary.pass and "PASS" or "FAIL",
        summary.frames, summary.transition, summary.productBlack,
        summary.visible3d, summary.fromFrames, summary.toFrames,
        summary.targetUnderTransition, summary.targetLanding,
        summary.finalReady3d,
        summary.birdseye, summary.black, summary.qaCover,
        summary.wrongLevel))
    if not summary.pass then
      runViolations[#runViolations + 1] = audit.label
        .. ":frame-certification"
    end
    return summary
  end

  local rawPrefetchForAux = Scene.prefetch
  local traceReady = os.getenv("VASC_QA_TRACE_READY") == "1"
  local wasReady, readyDropAt, readyDropCalls = false, nil, 0
  Scene.prefetch = function(state, ...)
    local terrain, neighbors, water, nbWater, plan =
      rawPrefetchForAux(state, ...)
    local nowReady = Voxel.ready == true
    if traceReady then
      if wasReady and not nowReady and not readyDropAt then
        readyDropAt, readyDropCalls = love.timer.getTime(), 0
        print(("VASC_QA_READY_FALLBACK_BEGIN map=%s terrain=%s")
          :format(tostring(state and state.map and state.map.id),
                  tostring(terrain ~= nil)))
      elseif readyDropAt and not nowReady then
        readyDropCalls = readyDropCalls + 1
      elseif readyDropAt and nowReady then
        print(("VASC_QA_READY_FALLBACK_END map=%s elapsed=%.3f calls=%d")
          :format(tostring(state and state.map and state.map.id),
                  love.timer.getTime() - readyDropAt, readyDropCalls))
        readyDropAt, readyDropCalls = nil, 0
      end
      wasReady = nowReady
    end
    if state and state.map then
      latestPlan, latestPlanMap = plan, state.map.id
    end
    if popinWindow and state and state.map
       and state.map.id == popinExpectedMap
       and plan and plan.state then
      for _, nb in ipairs(plan.state.neighbors or {}) do
        if not Mesher.auxReady(nb.map) then
          local mapId = tostring(nb.map and nb.map.id)
          if not popinSeen[mapId] then
            popinSeen[mapId] = true
            popinViolations[#popinViolations + 1] = mapId
            print(("VASC_QA_%s_POPIN map=%s current=%s reason=visible-before-aux")
              :format(popinWindow, mapId,
                      tostring(state and state.map and state.map.id)))
          end
        end
      end
    end
    return terrain, neighbors, water, nbWater, plan
  end

  -- Optional real-driver profiler. It stays entirely in this QA process:
  -- public module methods are wrapped after load and disappear with the app.
  -- POST_GAP is measured when the driver resumes, before Game:update. Its
  -- interval therefore belongs to the PREVIOUS frame and includes engine
  -- logic, pipeline/pump, GC, draw, present and OS scheduling. Aggregate all
  -- of those costs and consume them at the next resume; isolated render logs
  -- cannot attribute a frame gap on their own.
  local traceEnabled = os.getenv("VASC_QA_TRACE") == "1"
  local traceReset, traceSnapshot, traceGCRecord, traceHeapNow
  local gcSummaryBegin, gcSummaryEnd, traceFinalFullGC
  if traceEnabled and Scene and Voxel3D then
    local rawGC = collectgarbage
    local gcMode = string.lower(os.getenv("VASC_QA_GC_MODE") or "normal")
    local trace = {}
    local function add(key, elapsed, maxKey)
      trace[key] = (trace[key] or 0) + elapsed
      if maxKey and elapsed > (trace[maxKey] or 0) then
        trace[maxKey] = elapsed
      end
    end
    local function pendingNow()
      return Mesher and Mesher.pending and Mesher.pending() or -1
    end
    local function memoryNow()
      return rawGC and rawGC("count") or 0
    end
    traceHeapNow = memoryNow
    traceFinalFullGC = function()
      return collectRoute8FinalFullGC(rawGC, love.timer.getTime)
    end
    traceReset = function()
      for key in pairs(trace) do trace[key] = nil end
      trace.memStart = memoryNow()
    end

    -- Inspect the suspended build coroutine only after a pump overrun. The
    -- first non-Budget source line says whether the oversized atomic section
    -- was geometry, upload, structures analysis or auxiliary construction.
    local mesherJobs, budgetForTrace
    if debug and type(debug.getupvalue) == "function" then
      for index = 1, 64 do
        local name, value = debug.getupvalue(Mesher.pump, index)
        if not name then break end
        if name == "jobs" then mesherJobs = value end
        if name == "Budget" then budgetForTrace = value end
      end
    end
    local function suspendedBuildSite()
      if not (debug and type(debug.getinfo) == "function"
              and type(mesherJobs) == "table") then return "unknown" end
      for pass = 1, 2 do
        for _, job in ipairs(mesherJobs) do
          if job.co and coroutine.status(job.co) == "suspended"
             and ((pass == 1 and job.urgent) or (pass == 2 and not job.urgent)) then
            for level = 1, 24 do
              local info = debug.getinfo(job.co, level, "Sl")
              if not info then break end
              local src = tostring(info.short_src or info.source or "")
              if src:find("ChunkMesher.lua", 1, true)
                 or src:find("Structures.lua", 1, true)
                 or src:find("Buildings.lua", 1, true)
                 or src:find("LedgeElevation.lua", 1, true) then
                local file = src:match("([^/\\]+%.lua)$") or src
                return ("%s:%s:%s:%d"):format(tostring(job.id),
                  tostring(job.slot), file, tonumber(info.currentline) or -1)
              end
            end
          end
        end
      end
      return "none"
    end

    local inPump, budgetBoundary = false, 0
    if type(budgetForTrace) == "table"
       and type(budgetForTrace.check) == "function" then
      local rawBudgetCheck = budgetForTrace.check
      budgetForTrace.check = function(...)
        if inPump then
          local now = love.timer.getTime()
          local span = now - budgetBoundary
          budgetBoundary = now
          if span > (trace.budgetSpanMax or 0) then
            trace.budgetSpanMax = span
            local info = debug and debug.getinfo and debug.getinfo(2, "Sl")
            local source = info and (info.short_src or info.source) or "unknown"
            trace.budgetSpanSite = ("%s:%d"):format(tostring(source),
              tonumber(info and info.currentline) or -1)
          end
        end
        return rawBudgetCheck(...)
      end
    end

    local rawPump = Mesher.pump
    Mesher.pump = function(covered, background, loading)
      local beforePending, beforeMem = pendingNow(), memoryNow()
      local selected = type(mesherJobs) == "table" and mesherJobs[1] or nil
      for _, job in ipairs(type(mesherJobs) == "table" and mesherJobs or {}) do
        if job.urgent then selected = job break end
      end
      local started = love.timer.getTime()
      inPump, budgetBoundary = true, started
      rawPump(covered, background, loading)
      inPump = false
      local elapsed = love.timer.getTime() - started
      add("pump", elapsed, "pumpMax")
      trace.pumpPendingBefore = beforePending
      trace.pumpPendingAfter = pendingNow()
      trace.pumpJobId = selected and selected.id or "none"
      trace.pumpJobSlot = selected and selected.slot or "none"
      trace.pumpJobUrgent = selected and selected.urgent and true or false
      trace.pumpMemDelta = (trace.pumpMemDelta or 0)
                           + (memoryNow() - beforeMem)
      trace.pumpMode = background and "background"
                       or covered and "covered"
                       or loading and "loading" or "visible"
      if elapsed >= 0.020 then trace.pumpSite = suspendedBuildSite() end
    end

    -- The engine's explicit incremental step is observable; automatic GC
    -- inside allocations is not. A second diagnostic run can set
    -- VASC_QA_GC_MODE=stop to suppress both automatic and explicit steps and
    -- distinguish a collector pause from an oversized mesh driver call.
    if rawGC and gcMode == "stop" then rawGC("stop") end
    if rawGC then
      collectgarbage = function(option, amount)
        local before = memoryNow()
        local started = love.timer.getTime()
        local result
        if gcMode == "stop" and option == "step" then
          result = false
        elseif amount ~= nil then
          result = rawGC(option, amount)
        else
          result = rawGC(option)
        end
        add("gc", love.timer.getTime() - started, "gcMax")
        trace.gcCalls = (trace.gcCalls or 0) + 1
        if option == "step" and result == true then
          trace.gcCycles = (trace.gcCycles or 0) + 1
        end
        trace.gcMemDelta = (trace.gcMemDelta or 0) + (memoryNow() - before)
        return result
      end
    end

    -- Every measured frame contributes to this bounded summary, including the
    -- fast frames whose detailed ATTR row is deliberately suppressed.  This
    -- observes explicit collectgarbage calls only; automatic allocation-side
    -- work remains represented by the enclosing frame gap and heap endpoints.
    local activeGCMetric, activeGCLabel, activeGCPhase
    gcSummaryBegin = function(label, phase)
      if activeGCMetric then
        error(("VASC_QA_GC_SUMMARY overlap active=%s/%s next=%s/%s")
          :format(activeGCLabel, activeGCPhase, label, phase), 0)
      end
      activeGCLabel, activeGCPhase = label, phase
      activeGCMetric = newGCMetric(memoryNow())
    end
    traceGCRecord = function()
      if not activeGCMetric then return end
      recordGCMetric(activeGCMetric, trace.gc, trace.gcMax,
                     trace.gcCalls, trace.gcCycles, memoryNow())
    end
    gcSummaryEnd = function()
      if not activeGCMetric then return end
      local metric, label, phase = activeGCMetric,
        activeGCLabel, activeGCPhase
      local heap = memoryNow()
      metric.heapEnd = heap
      metric.heapPeak = math.max(metric.heapPeak, heap)
      activeGCMetric, activeGCLabel, activeGCPhase = nil, nil, nil
      print(gcSummaryLine(label, phase, metric, gcMode))
      print(heapEndLine(label, phase, metric))
    end

    local PipelinesForTrace = require("src.render.Pipelines")
    local rawPipelineUpdate = PipelinesForTrace.update
    PipelinesForTrace.update = function(...)
      local started = love.timer.getTime()
      local result = rawPipelineUpdate(...)
      add("pipeline", love.timer.getTime() - started)
      return result
    end

    local rawStackUpdate = game.stack.update
    game.stack.update = function(stack, ...)
      local started = love.timer.getTime()
      local result = rawStackUpdate(stack, ...)
      add("stack", love.timer.getTime() - started)
      return result
    end

    local rawGameUpdate = game.update
    game.update = function(self, ...)
      local started = love.timer.getTime()
      local result = rawGameUpdate(self, ...)
      add("gameUpdate", love.timer.getTime() - started)
      return result
    end

    local rawGameDraw = game.draw
    game.draw = function(self, ...)
      local started = love.timer.getTime()
      local result = rawGameDraw(self, ...)
      add("gameDraw", love.timer.getTime() - started)
      return result
    end

    local HostDisplayForTrace = require("src.core.HostDisplay")
    for _, key in ipairs({ "update", "beginFrame", "endFrame" }) do
      local raw = HostDisplayForTrace[key]
      if type(raw) == "function" then
        HostDisplayForTrace[key] = function(...)
          local started = love.timer.getTime()
          local result = raw(...)
          add("hostDisplay", love.timer.getTime() - started)
          return result
        end
      end
    end
    local DiagnosticsForTrace = require("src.debug.SwitchDiagnostics")
    if type(DiagnosticsForTrace.maybeFlush) == "function" then
      local rawMaybeFlush = DiagnosticsForTrace.maybeFlush
      DiagnosticsForTrace.maybeFlush = function(...)
        local started = love.timer.getTime()
        local result = rawMaybeFlush(...)
        add("diagnostics", love.timer.getTime() - started)
        return result
      end
    end

    if love.timer and type(love.timer.step) == "function" then
      local rawTimerStep = love.timer.step
      love.timer.step = function(...)
        local started = love.timer.getTime()
        local result = rawTimerStep(...)
        add("timerStep", love.timer.getTime() - started)
        return result
      end
    end
    if love.timer and type(love.timer.sleep) == "function" then
      local rawSleep = love.timer.sleep
      love.timer.sleep = function(...)
        local started = love.timer.getTime()
        local result = rawSleep(...)
        add("sleep", love.timer.getTime() - started)
        return result
      end
    end
    if love.event and type(love.event.pump) == "function" then
      local rawEventPump = love.event.pump
      love.event.pump = function(...)
        local started = love.timer.getTime()
        local result = rawEventPump(...)
        add("eventPump", love.timer.getTime() - started)
        return result
      end
    end

    if love.graphics and type(love.graphics.present) == "function" then
      local rawPresent = love.graphics.present
      love.graphics.present = function(...)
        local started = love.timer.getTime()
        local result = rawPresent(...)
        add("present", love.timer.getTime() - started)
        return result
      end
    end

    local rawSetMap = ow.setMap
    ow.setMap = function(self, ...)
      local started = love.timer.getTime()
      local result = rawSetMap(self, ...)
      add("setMap", love.timer.getTime() - started)
      return result
    end
    local rawRebuildNeighbors = ow.rebuildNeighbors
    ow.rebuildNeighbors = function(self, ...)
      local started = love.timer.getTime()
      local result = rawRebuildNeighbors(self, ...)
      add("neighbors", love.timer.getTime() - started)
      return result
    end

    local MapLoader = require("src.world.MapLoader")
    local rawMapLoad = MapLoader.load
    MapLoader.load = function(...)
      local started = love.timer.getTime()
      local result = rawMapLoad(...)
      add("mapLoad", love.timer.getTime() - started)
      return result
    end

    local RuntimeForTrace = require("src.mods.Runtime")
    local rawEmit = RuntimeForTrace.emit
    RuntimeForTrace.emit = function(name, ...)
      local started = love.timer.getTime()
      local result = rawEmit(name, ...)
      add("emit", love.timer.getTime() - started)
      if name == "map.entered" then trace.mapEntered = (trace.mapEntered or 0) + 1 end
      return result
    end
    -- Kanto Ascendant currently contributes dozens of synchronous map-enter
    -- listeners under one owner id. Time the already-registered callbacks
    -- individually so an expensive handler is not hidden inside `emit`.
    local enteredListeners = RuntimeForTrace.events
                             and RuntimeForTrace.events.listeners
                             and RuntimeForTrace.events.listeners["map.entered"]
    for _, entry in ipairs(type(enteredListeners) == "table"
                           and enteredListeners or {}) do
      local rawCallback = entry.callback
      local info = debug and debug.getinfo and debug.getinfo(rawCallback, "Sl")
      local source = info and (info.short_src or info.source) or "unknown"
      local line = info and info.linedefined or -1
      local site = ("%s:%d"):format(tostring(source), tonumber(line) or -1)
      entry.callback = function(...)
        local started = love.timer.getTime()
        local result = rawCallback(...)
        local elapsed = love.timer.getTime() - started
        add("mapHandler", elapsed, "mapHandlerMax")
        if elapsed >= (trace.mapHandlerMax or 0) then
          trace.mapHandlerSite = site
        end
        return result
      end
    end

    if love.graphics and type(love.graphics.newMesh) == "function" then
      local rawNewMesh = love.graphics.newMesh
      love.graphics.newMesh = function(...)
        local started = love.timer.getTime()
        local result = rawNewMesh(...)
        add("newMesh", love.timer.getTime() - started)
        return result
      end
    end
    if love.data and type(love.data.pack) == "function" then
      local rawPack = love.data.pack
      love.data.pack = function(...)
        local started = love.timer.getTime()
        local result = rawPack(...)
        add("pack", love.timer.getTime() - started)
        return result
      end
    end
    if love.data and type(love.data.newByteData) == "function" then
      local rawByteData = love.data.newByteData
      love.data.newByteData = function(...)
        local started = love.timer.getTime()
        local result = rawByteData(...)
        add("byteData", love.timer.getTime() - started)
        return result
      end
    end

    local rawPrefetch = Scene.prefetch
    Scene.prefetch = function(state, ...)
      local started = love.timer.getTime()
      local terrain, neighbors, water, nbWater, plan = rawPrefetch(state, ...)
      local elapsed = love.timer.getTime() - started
      add("prefetch", elapsed)
      return terrain, neighbors, water, nbWater, plan
    end

    local rawDraw = Voxel3D.draw
    Voxel3D.draw = function(mesh, ...)
      local started = love.timer.getTime()
      local out = rawDraw(mesh, ...)
      local elapsed = love.timer.getTime() - started
      add("voxelDraw", elapsed)
      return out
    end

    local rawRender = Scene.render
    Scene.render = function(state, ...)
      local started = love.timer.getTime()
      local out = rawRender(state, ...)
      local elapsed = love.timer.getTime() - started
      add("render", elapsed)
      return out
    end

    traceSnapshot = function(gap)
      local accounted = (trace.gameUpdate or 0) + (trace.gameDraw or 0)
                        + (trace.present or 0) + (trace.sleep or 0)
                        + (trace.timerStep or 0) + (trace.eventPump or 0)
                        + (trace.hostDisplay or 0)
                        + (trace.diagnostics or 0)
      local result = {
        pump = trace.pump or 0, pumpMax = trace.pumpMax or 0,
        pumpBefore = trace.pumpPendingBefore or -1,
        pumpAfter = trace.pumpPendingAfter or -1,
        pumpJobId = trace.pumpJobId or "none",
        pumpJobSlot = trace.pumpJobSlot or "none",
        pumpJobUrgent = trace.pumpJobUrgent and true or false,
        pumpMode = trace.pumpMode or "none",
        pumpSite = trace.pumpSite or "none",
        pumpMem = trace.pumpMemDelta or 0,
        budgetSpan = trace.budgetSpanMax or 0,
        budgetSite = trace.budgetSpanSite or "none",
        gc = trace.gc or 0, gcMax = trace.gcMax or 0,
        gcCalls = trace.gcCalls or 0, gcCycles = trace.gcCycles or 0,
        gcMem = trace.gcMemDelta or 0,
        gameUpdate = trace.gameUpdate or 0,
        stack = trace.stack or 0, pipeline = trace.pipeline or 0,
        prefetch = trace.prefetch or 0, render = trace.render or 0,
        voxelDraw = trace.voxelDraw or 0, gameDraw = trace.gameDraw or 0,
        present = trace.present or 0, setMap = trace.setMap or 0,
        sleep = trace.sleep or 0, timerStep = trace.timerStep or 0,
        eventPump = trace.eventPump or 0,
        hostDisplay = trace.hostDisplay or 0,
        diagnostics = trace.diagnostics or 0,
        neighbors = trace.neighbors or 0, mapLoad = trace.mapLoad or 0,
        emit = trace.emit or 0, mapEntered = trace.mapEntered or 0,
        mapHandler = trace.mapHandler or 0,
        mapHandlerMax = trace.mapHandlerMax or 0,
        mapHandlerSite = trace.mapHandlerSite or "none",
        newMesh = trace.newMesh or 0, pack = trace.pack or 0,
        byteData = trace.byteData or 0,
        memDelta = memoryNow() - (trace.memStart or memoryNow()),
        residual = math.max(0, gap - accounted), gcMode = gcMode,
      }
      return result
    end
    traceReset()
  end

  local function pending()
    return Mesher and Mesher.pending and Mesher.pending() or -1
  end

  local function auxReady()
    if targetLevel == 0 then return true end
    if Mesher and Mesher.auxReady then return Mesher.auxReady(ow.map) end
    return Voxel.ready == true
  end

  local function consumeFrameTrace(gap, capture)
    if traceGCRecord then traceGCRecord() end
    local snapshot = capture and traceSnapshot and traceSnapshot(gap) or nil
    if traceReset then traceReset() end
    return snapshot
  end

  local function beginFrameMetrics(label, phase)
    if gcSummaryBegin then gcSummaryBegin(label, phase) end
    if traceReset then traceReset() end
  end

  local function endFrameMetrics()
    if gcSummaryEnd then gcSummaryEnd() end
  end

  local function printTrace(label, kind, row)
    local t = row.trace
    if not t then return end
    print(("VASC_QA_%s_%s_ATTR frame=%d "
           .. "pump=%.1f/%.1fms(%s,%d>%d,job=%s:%s:%s,%s,mem=%+.0fKB,boundary=%.1fms@%s) "
           .. "gc=%.1f/%.1fms(calls=%d,cycles=%d,mem=%+.0fKB,mode=%s) "
           .. "update=%.1fms stack=%.1fms pipeline=%.1fms prefetch=%.1fms "
           .. "draw=%.1fms render=%.1fms voxel_draw=%.1fms present=%.1fms "
           .. "sleep=%.1fms timer=%.1fms events=%.1fms host=%.1fms diag=%.1fms "
           .. "setmap=%.1fms neighbors=%.1fms mapload=%.1fms "
           .. "emit=%.1fms entered=%d handlers=%.1f/%.1fms(%s) "
           .. "newmesh=%.1fms pack=%.1fms "
           .. "bytedata=%.1fms mem=%+.0fKB residual=%.1fms")
      :format(label, kind, row.frame,
        t.pump * 1000, t.pumpMax * 1000, t.pumpMode,
        t.pumpBefore, t.pumpAfter, t.pumpJobId, t.pumpJobSlot,
        tostring(t.pumpJobUrgent), t.pumpSite, t.pumpMem,
        t.budgetSpan * 1000, t.budgetSite,
        t.gc * 1000, t.gcMax * 1000, t.gcCalls, t.gcCycles,
        t.gcMem, t.gcMode,
        t.gameUpdate * 1000, t.stack * 1000, t.pipeline * 1000,
        t.prefetch * 1000,
        t.gameDraw * 1000, t.render * 1000, t.voxelDraw * 1000,
        t.present * 1000, t.sleep * 1000, t.timerStep * 1000,
        t.eventPump * 1000, t.hostDisplay * 1000, t.diagnostics * 1000,
        t.setMap * 1000, t.neighbors * 1000,
        t.mapLoad * 1000, t.emit * 1000, t.mapEntered,
        t.mapHandler * 1000, t.mapHandlerMax * 1000, t.mapHandlerSite,
        t.newMesh * 1000, t.pack * 1000, t.byteData * 1000,
        t.memDelta, t.residual * 1000))
  end

  local fullWarmLimit = math.floor(
    tonumber(os.getenv("VASC_QA_FULL_WARM_FRAMES")) or 5400)
  if fullWarmLimit < 1 then fullWarmLimit = 1 end

  -- Optional millisecond histogram for release-candidate frame pacing.  A
  -- histogram, rather than one Lua table entry per frame, keeps the observer
  -- bounded and avoids turning a long full-union warmup into its own source
  -- of GC pressure.  Existing log consumers keep their original markers;
  -- the percentile line is additive and opt-in.
  local percentileEnabled = os.getenv("VASC_QA_PERCENTILES") == "1"
  local function newGapStats()
    return percentileEnabled and { n = 0, bins = {} } or nil
  end

  local function recordGap(stats, gap)
    if not stats then return end
    local ms = math.floor(math.max(0, math.min(999, gap * 1000)) + 0.5)
    stats.n = stats.n + 1
    stats.bins[ms] = (stats.bins[ms] or 0) + 1
  end

  local function gapPercentile(stats, fraction)
    if not stats or stats.n == 0 then return 0 end
    local target = math.max(1, math.ceil(stats.n * fraction))
    local seen = 0
    for ms = 0, 999 do
      seen = seen + (stats.bins[ms] or 0)
      if seen >= target then return ms / 1000 end
    end
    return 0.999
  end

  local function printPercentiles(label, phase, stats)
    if not stats then return end
    print(("VASC_QA_%s_%s_PERCENTILES frames=%d p95=%.3f p99=%.3f")
      :format(label, phase, stats.n,
              gapPercentile(stats, 0.95), gapPercentile(stats, 0.99)))
  end

  local function asFlag(value)
    return value and 1 or 0
  end

  local function joinIds(ids)
    return type(ids) == "table" and table.concat(ids, ",") or ""
  end

  local function printPlanStatus(label, marker)
    local status = Scene.planStatus and Scene.planStatus() or {}
    local active, handoff = status.active or {}, status.handoff or {}
    print(("VASC_QA_%s_%s_PLAN_STATUS active_root=%s active_ids=%s "
           .. "handoff_root=%s handoff_ids=%s live_key=%s")
      :format(label, marker, tostring(active.rootId), joinIds(active.ids),
        tostring(handoff.rootId), joinIds(handoff.ids),
        tostring(status.liveKey)))
  end

  local function horizonCache(state)
    if not (Horizon.cacheStatus and state and state.map) then
      return { ready = false, pending = false, resumes = -1, maps = -1 }
    end
    return Horizon.cacheStatus(state)
  end

  local function printHorizonCacheStatus(label, marker)
    local map = ow.map
    local current = horizonCache({ map = map, neighbors = {},
                                   worldMaps = ow.worldMaps })
    local plan = latestPlanMap == (map and map.id) and latestPlan or nil
    local planned = horizonCache(plan and plan.state)
    local full = horizonCache(map and ow)
    print(("VASC_QA_%s_%s_HORIZON_CACHE "
           .. "current_ready=%d current_pending=%d current_resumes=%d "
           .. "current_maps=%d plan_ready=%d plan_pending=%d "
           .. "plan_resumes=%d plan_maps=%d full_ready=%d "
           .. "full_pending=%d full_resumes=%d full_maps=%d")
      :format(label, marker, asFlag(current.ready), asFlag(current.pending),
        current.resumes, current.maps, asFlag(planned.ready),
        asFlag(planned.pending), planned.resumes, planned.maps,
        asFlag(full.ready), asFlag(full.pending), full.resumes, full.maps))
  end

  -- A full union is stronger than `Mesher.pending() == 0`: the latter can
  -- include retained work from the previous neighbourhood, while a complete
  -- semantic draw plan proves that this exact union's horizon and every body
  -- it exposes are ready. Count body/aux/atlas independently so a long phase
  -- is attributable without calling Horizon.meshes() from the observer (that
  -- call would itself advance the asynchronous horizon and skew the sample).
  local function requiredUnion(expectedIds)
    local ids, count = {}, 0
    local source = expectedIds
    if not source then
      source = {}
      for _, nb in ipairs(ow.neighbors or {}) do
        source[#source + 1] = nb.map and nb.map.id
      end
    end
    for _, mapId in ipairs(source) do
      if mapId and not ids[mapId] then
        ids[mapId] = true
        count = count + 1
      end
    end
    return { ids = ids, count = count }
  end

  local function fullWarmStatus(expectedMap, required)
    local map = ow.map
    local neighbors = (map and ow.neighbors) or {}
    local planNeighbors = {}
    if latestPlanMap == expectedMap and latestPlan and latestPlan.state then
      planNeighbors = latestPlan.state.neighbors or {}
    end

    local topology, bodies, aux, atlases = 0, 0, 0, 0
    for _, nb in ipairs(neighbors) do
      local nbMap = nb.map
      if nbMap and required.ids[nbMap.id] then
        topology = topology + 1
        if Mesher.ready(nbMap, true) then bodies = bodies + 1 end
        if Mesher.auxReady(nbMap) then aux = aux + 1 end
        if Atlas.prepared(nbMap) then atlases = atlases + 1 end
      end
    end

    local planned = 0
    for _, nb in ipairs(planNeighbors) do
      if nb.map and required.ids[nb.map.id] then planned = planned + 1 end
    end

    local onTarget = map and map.id == expectedMap
    local currentBody = onTarget
      and Mesher.ready(map, Horizon.preferBody(map)) or false
    local currentAux = onTarget and Mesher.auxReady(map) or false
    local currentAtlas = onTarget and Atlas.prepared(map) or false
    local horizon = Horizon.buildStatus() or {}
    local exactTopology = #neighbors == required.count
                          and topology == required.count
    local exactPlan = latestPlanMap == expectedMap
                      and #planNeighbors == required.count
                      and planned == required.count
    local ready = onTarget and game.stack:top() == ow and Voxel.ready
                  and currentBody and currentAux and currentAtlas
                  and exactTopology and exactPlan
                  and bodies == required.count
                  and aux == required.count
                  and atlases == required.count
    return ready, {
      map = tostring(map and map.id), currentBody = not not currentBody,
      currentAux = not not currentAux, currentAtlas = not not currentAtlas,
      topology = topology, neighborCount = #neighbors,
      planned = planned, planCount = #planNeighbors,
      bodies = bodies, aux = aux, atlases = atlases,
      required = required.count, mesherPending = pending(),
      horizonPending = tonumber(horizon.pending) or -1,
    }
  end

  local function printFullStatus(label, marker, frames, phaseElapsed,
                                 totalElapsed, currentElapsed, maxGap, status)
    print(("VASC_QA_%s_%s frames=%d phase_elapsed=%.3f total_elapsed=%.3f "
           .. "current_elapsed=%.3f max_gap=%.3f map=%s "
           .. "current_body=%d current_aux=%d current_atlas=%d "
           .. "topology=%d/%d neighbors=%d plan=%d/%d plan_members=%d "
           .. "body=%d/%d aux=%d/%d atlas=%d/%d "
           .. "mesher_pending=%d horizon_pending=%d")
      :format(label, marker, frames, phaseElapsed, totalElapsed,
        currentElapsed, maxGap, status.map,
        asFlag(status.currentBody), asFlag(status.currentAux),
        asFlag(status.currentAtlas), status.topology, status.required,
        status.neighborCount, status.planned, status.required,
        status.planCount, status.bodies, status.required,
        status.aux, status.required, status.atlases, status.required,
        status.mesherPending, status.horizonPending))
  end

  local function waitFullWarm(label, expectedMap, limit, warpStarted,
                              currentElapsed, expectedIds)
    local required = requiredUnion(expectedIds)
    local started = love.timer.getTime()
    local previous = started
    local maxGap, frames = 0, 0
    local gaps = {}
    local gapStats = newGapStats()
    beginFrameMetrics(label, "FULL")

    local ready, status = fullWarmStatus(expectedMap, required)
    while not ready and frames < limit do
      coroutine.yield()
      frames = frames + 1
      local now = love.timer.getTime()
      local gap = now - previous
      previous = now
      recordGap(gapStats, gap)
      if gap > maxGap then maxGap = gap end
      ready, status = fullWarmStatus(expectedMap, required)
      if gap >= 0.030 then
        gaps[#gaps + 1] = {
          frame = frames, gap = gap, elapsed = now - started,
          status = status, trace = consumeFrameTrace(gap, true),
        }
      else
        consumeFrameTrace(gap, false)
      end
    end

    endFrameMetrics()
    for _, row in ipairs(gaps) do
      local s = row.status
      print(("VASC_QA_%s_FULL_GAP frame=%d gap=%.3f elapsed=%.3f "
             .. "map=%s topology=%d/%d plan=%d/%d body=%d/%d "
             .. "aux=%d/%d atlas=%d/%d mesher_pending=%d "
             .. "horizon_pending=%d")
        :format(label, row.frame, row.gap, row.elapsed, s.map,
          s.topology, s.required, s.planned, s.required,
          s.bodies, s.required, s.aux, s.required,
          s.atlases, s.required, s.mesherPending, s.horizonPending))
      printTrace(label, "FULL_GAP", row)
    end

    local finished = love.timer.getTime()
    printFullStatus(label, ready and "FULL_WARM" or "FULL_TIMEOUT",
                    frames, finished - started, finished - warpStarted,
                    currentElapsed, maxGap, status)
    printPercentiles(label, "FULL", gapStats)
    return ready, maxGap
  end

  local function waitReady(label, expectedMap, limit)
    local started = love.timer.getTime()
    local previous = started
    local maxGap, frames = 0, 0
    local gaps = {}
    local gapStats = newGapStats()
    if phaseProfileReset then phaseProfileReset() end
    beginFrameMetrics(label, "CURRENT")
    while frames < limit do
      coroutine.yield()
      frames = frames + 1
      local now = love.timer.getTime()
      local gap = now - previous
      previous = now
      recordGap(gapStats, gap)
      if gap > maxGap then maxGap = gap end
      if gap >= 0.030 then
        gaps[#gaps + 1] = {
          frame = frames, gap = gap, elapsed = now - started,
          ready = Voxel.ready, pending = pending(),
          map = tostring(ow.map and ow.map.id),
          trace = consumeFrameTrace(gap, true),
        }
      else
        consumeFrameTrace(gap, false)
      end
      local onTarget = ow.map and ow.map.id == expectedMap
      local drawable = targetLevel == 0 or Voxel.ready
      if onTarget and drawable and game.stack:top() == ow then
        local aux = auxReady()
        endFrameMetrics()
        for _, row in ipairs(gaps) do
          print(("VASC_QA_%s_CURRENT_GAP frame=%d gap=%.3f elapsed=%.3f ready=%s pending=%d map=%s")
            :format(label, row.frame, row.gap, row.elapsed,
                    tostring(row.ready), row.pending, row.map))
          printTrace(label, "CURRENT_GAP", row)
        end
        print(("VASC_QA_%s_CURRENT_READY frames=%d elapsed=%.3f max_gap=%.3f map=%s aux=%s pending=%d")
          :format(label, frames, now - started, maxGap,
                  tostring(ow.map and ow.map.id), tostring(aux),
                  pending()))
        -- Retain the original marker for existing log consumers.
        print(("VASC_QA_%s_READY frames=%d elapsed=%.3f max_gap=%.3f map=%s aux=%s pending=%d")
          :format(label, frames, now - started, maxGap,
                  tostring(ow.map and ow.map.id), tostring(aux),
                  pending()))
        printPercentiles(label, "CURRENT", gapStats)
        printPlanStatus(label, "CURRENT_READY")
        printHorizonCacheStatus(label, "CURRENT_READY")
        if phaseProfilePrint then phaseProfilePrint(label) end
        if targetLevel ~= 0 and not aux then
          error("VASC_QA_" .. label
                .. " terrain became visible before grass/flowers/figures")
        end
        return true, maxGap, frames, now - started
      end
    end
    endFrameMetrics()
    print(("VASC_QA_%s_TIMEOUT frames=%d elapsed=%.3f max_gap=%.3f map=%s")
      :format(label, frames, love.timer.getTime() - started, maxGap,
              tostring(ow.map and ow.map.id)))
    -- A timeout must explain which readiness gate stayed closed.  Do not call
    -- Horizon.meshes here: that would advance the job being diagnosed.  The
    -- latest production draw plan and passive buildStatus are sufficient to
    -- distinguish a missing current body/aux/atlas from a canonical re-root
    -- or horizon-cache miss.
    local timeoutMap = ow.map
    local timeoutBody = timeoutMap
      and Mesher.ready(timeoutMap, Horizon.preferBody(timeoutMap)) or false
    local timeoutAux = timeoutMap and Mesher.auxReady(timeoutMap) or false
    local timeoutAtlas = timeoutMap and Atlas.prepared(timeoutMap) or false
    local timeoutHorizon = Horizon.buildStatus and Horizon.buildStatus() or {}
    local timeoutPlan = latestPlanMap == (timeoutMap and timeoutMap.id)
                        and latestPlan or nil
    local timeoutPlanCount = timeoutPlan and timeoutPlan.state
      and #(timeoutPlan.state.neighbors or {}) or -1
    print(("VASC_QA_%s_TIMEOUT_DETAIL voxel=%d body=%d aux=%d atlas=%d "
           .. "plan_map=%s plan_neighbors=%d stack_current=%d "
           .. "stack_top=%s stack_is_textbox=%s stack_depth=%d "
           .. "mesher_pending=%d horizon_ready=%s horizon_pending=%s")
      :format(label, asFlag(Voxel.ready), asFlag(timeoutBody),
        asFlag(timeoutAux), asFlag(timeoutAtlas), tostring(latestPlanMap),
        timeoutPlanCount, asFlag(game.stack:top() == ow),
        stackStateType(game.stack:top()),
        tostring(stackIsTextBox(game.stack:top())), stackDepth(game), pending(),
        tostring(timeoutHorizon.ready), tostring(timeoutHorizon.pending)))
    printPlanStatus(label, "TIMEOUT")
    printHorizonCacheStatus(label, "TIMEOUT")
    for i, nb in ipairs((timeoutMap and ow.neighbors) or {}) do
      local planned = false
      if timeoutPlan and timeoutPlan.state then
        for _, member in ipairs(timeoutPlan.state.neighbors or {}) do
          if member.map and nb.map and member.map.id == nb.map.id then
            planned = true
            break
          end
        end
      end
      print(("VASC_QA_%s_TIMEOUT_NEIGHBOR index=%d id=%s body=%d aux=%d "
             .. "atlas=%d planned=%d")
        :format(label, i, tostring(nb.map and nb.map.id),
          asFlag(nb.map and Mesher.ready(nb.map, true)),
          asFlag(nb.map and Mesher.auxReady(nb.map)),
          asFlag(nb.map and Atlas.prepared(nb.map)), asFlag(planned)))
    end
    if phaseProfilePrint then phaseProfilePrint(label) end
    return false, maxGap, frames, love.timer.getTime() - started
  end

  local function stableWindow(label, frames)
    local started = love.timer.getTime()
    local previous = started
    local maxGap = 0
    local gaps = {}
    local gapStats = newGapStats()
    beginFrameMetrics(label, "STABLE")
    for frame = 1, frames do
      coroutine.yield()
      local now = love.timer.getTime()
      local gap = now - previous
      previous = now
      recordGap(gapStats, gap)
      if gap > maxGap then maxGap = gap end
      if gap >= 0.030 then
        gaps[#gaps + 1] = {
          frame = frame, gap = gap, elapsed = now - started,
          pending = pending(), map = tostring(ow.map and ow.map.id),
          trace = consumeFrameTrace(gap, true),
        }
      else
        consumeFrameTrace(gap, false)
      end
    end
    endFrameMetrics()
    for _, row in ipairs(gaps) do
      print(("VASC_QA_%s_POST_GAP frame=%d gap=%.3f elapsed=%.3f pending=%d map=%s")
        :format(label, row.frame, row.gap, row.elapsed,
                row.pending, row.map))
      printTrace(label, "POST_GAP", row)
    end
    print(("VASC_QA_%s_STABLE frames=%d elapsed=%.3f max_gap=%.3f aux=%s pending=%d map=%s")
      :format(label, frames, love.timer.getTime() - started, maxGap,
              tostring(auxReady()), pending(),
              tostring(ow.map and ow.map.id)))
    printPercentiles(label, "STABLE", gapStats)
    return maxGap
  end

  local function finishPopinWindow(label)
    if popinViolations and #popinViolations > 0 then
      local detail = table.concat(popinViolations, ",")
      runViolations[#runViolations + 1] = label .. ":" .. detail
      print(("VASC_QA_%s_ASSERT_FAIL visible-neighbour-before-aux=%s")
        :format(label, detail))
    end
    popinWindow, popinExpectedMap = nil, nil
  end

  local function warp(label, mapId, x, y, options)
    options = options or {}
    popinWindow, popinExpectedMap = label, mapId
    popinSeen, popinViolations = {}, {}
    local warpStarted = love.timer.getTime()
    print(("VASC_QA_WARP_BEGIN %s -> %s")
      :format(tostring(ow.map and ow.map.id), mapId))
    ow:startWarpTo(mapId, x, y, "up")
    local ready, _, _, currentElapsed = waitReady(label, mapId, 1800)
    if not ready then error("VASC_QA_" .. label .. " did not become ready") end
    local fullReady = true
    if options.fullWarm and targetLevel ~= 0 then
      fullReady = waitFullWarm(label, mapId, fullWarmLimit, warpStarted,
                               currentElapsed, options.expectedNeighbors)
    end
    local stableFrames = options.stableFrames
    if stableFrames == nil then stableFrames = 300 end
    if stableFrames > 0 then stableWindow(label, stableFrames) end
    finishPopinWindow(label)
    if not fullReady then
      error("VASC_QA_" .. label .. " union did not become fully warm")
    end
  end

  local centerStableFrames = math.floor(
    tonumber(os.getenv("VASC_QA_CENTER_STABLE_FRAMES")) or 30)
  if centerSequence and (centerStableFrames < 20 or centerStableFrames > 600) then
    error("VASC_QA_CENTER_ENTRIES invalid CENTER_STABLE_FRAMES", 0)
  end

  -- Exercise the map's real warp record instead of calling setMap or naming
  -- the destination directly. takeWarp resolves destWarp/LAST_MAP, emits the
  -- product event, arms door SFX/auto-step, and enters startWarpTo's real
  -- Transition state. The observer above stays active across that whole stack
  -- lifetime and a short uncovered tail after it pops.
  local function centerDoorWarp(leg)
    requireSyntheticIdle(game, ow, leg.label, "pre-door", "-", 0)
    if not ow.map or ow.map.id ~= leg.fromMap then
      error(("VASC_QA_%s wrong source map expected=%s actual=%s")
        :format(leg.label, leg.fromMap,
                tostring(ow.map and ow.map.id)), 0)
    end
    local entry = ow.map:warpAtCell(leg.x, leg.y)
    if not entry or not entry.def or entry.def.destMap ~= leg.warpDest
       or entry.def.destWarp ~= 1 then
      error(("VASC_QA_%s wrong real warp at=%d,%d expected=%s#1 actual=%s#%s")
        :format(leg.label, leg.x, leg.y, leg.warpDest,
          tostring(entry and entry.def and entry.def.destMap),
          tostring(entry and entry.def and entry.def.destWarp)), 0)
    end

    local player = assert(ow.player)
    player.cellX, player.cellY = leg.x, leg.y
    player.px, player.py = leg.x * 16, leg.y * 16
    player.facing = leg.facing
    if ow.refreshStandingOnWarp then ow:refreshStandingOnWarp() end

    popinWindow, popinExpectedMap = leg.label, leg.toMap
    popinSeen, popinViolations = {}, {}
    print(("VASC_QA_%s_DOOR_BEGIN temperature=%s from=%s@%d,%d "
           .. "warp_dest=%s#1 expected=%s@%d,%d")
      :format(leg.label, leg.temperature, leg.fromMap, leg.x, leg.y,
        leg.warpDest, leg.toMap, leg.toX, leg.toY))
    beginCenterFrameAudit(leg)
    ow:takeWarp(entry.def)
    local transitionTop = stackStateType(game.stack:top())
    if not ow.transitioning or not transitionStackType(transitionTop) then
      finishCenterFrameAudit()
      finishPopinWindow(leg.label)
      error(("VASC_QA_%s did not enter real Transition stack top=%s")
        :format(leg.label, transitionTop), 0)
    end

    local ready = waitReady(leg.label, leg.toMap, 1800)
    if ready then stableWindow(leg.label, centerStableFrames) end
    finishCenterFrameAudit()
    finishPopinWindow(leg.label)
    if not ready then
      error("VASC_QA_" .. leg.label .. " did not become ready", 0)
    end
    requireSyntheticIdle(game, ow, leg.label, "post-door", "-", 0)
  end

  local neighbourWarmStatus

  local function seam(label, direction, expectedMap)
    requireSyntheticIdle(game, ow, label, "pre-cross", "-", 0)
    popinWindow, popinExpectedMap = label, expectedMap
    popinSeen, popinViolations = {}, {}
    local connection = ow.map and ow.map:connection(({
      up = "north", down = "south", left = "west", right = "east",
    })[direction])
    if not connection or connection.map ~= expectedMap then
      error(("VASC_QA_%s missing %s connection to %s")
        :format(label, tostring(direction), tostring(expectedMap)))
    end
    print(("VASC_QA_SEAM_BEGIN %s -> %s dir=%s")
      :format(tostring(ow.map and ow.map.id), expectedMap, direction))
    -- Passive snapshots on the two sides of the synchronous re-root.  These
    -- probes neither request nor resume Horizon jobs; they let one native
    -- failure distinguish a cold pre-cross handoff from a cache/key that was
    -- ready before crossConnection and disappeared when the root changed.
    printPlanStatus(label, "PRE_CROSS")
    print(targetCacheLine(label, neighbourWarmStatus(expectedMap)))
    printHorizonCacheStatus(label, "PRE_CROSS")
    requireSyntheticIdle(game, ow, label, "cross", "-", 0)
    if not ow:crossConnection(direction, connection) then
      error("VASC_QA_" .. label .. " crossConnection rejected")
    end
    requireOverworldTop(game, ow, label, "post-cross", "-", 0)
    printPlanStatus(label, "POST_CROSS")
    printHorizonCacheStatus(label, "POST_CROSS")
    local ready = waitReady(label, expectedMap, 900)
    if not ready then error("VASC_QA_" .. label .. " did not become ready") end
    stableWindow(label, 120)
    finishPopinWindow(label)
  end

  neighbourWarmStatus = function(mapId)
    local target
    for _, nb in ipairs(ow.neighbors or {}) do
      if nb.map and nb.map.id == mapId then target = nb.map break end
    end
    local plan = latestPlanMap == (ow.map and ow.map.id) and latestPlan or nil
    local planned = false
    if plan and plan.state then
      for _, nb in ipairs(plan.state.neighbors or {}) do
        if nb.map and nb.map.id == mapId then planned = true break end
      end
    end
    local cache = horizonCache(plan and plan.state)
    return {
      target = mapId, found = target ~= nil,
      body = target and Mesher.ready(target, true) or false,
      aux = target and Mesher.auxReady(target) or false,
      atlas = target and Atlas.prepared(target) or false,
      planned = planned,
      planReady = cache.ready, planPending = cache.pending,
      planResumes = cache.resumes, planMaps = cache.maps,
    }
  end

  -- Walk a deterministic number of rendered frames through real map cells
  -- before invoking crossConnection.  Directly teleporting onto an edge and
  -- crossing in the same driver tick bypasses the predictive seam scheduler
  -- that ordinary movement exercises, and can mislabel a deliberately cold
  -- neighbour as a player-visible regression. Eight frames per cell is the
  -- fast Gen-1 traversal case; slower movement only gives prewarming longer.
  local function approachSeam(label, direction, mapId,
                              firstCell, lastCell, fixedCell,
                              framesPerCell)
    local p = assert(ow.player)
    requireSyntheticIdle(game, ow, label, "pre-approach", firstCell, 0)

    -- This probe assigns standing cells rather than issuing real movement.
    -- An unfinished save can therefore let an undefeated trainer consume one
    -- of those artificial idle frames, then the coroutine keeps scanning and
    -- crosses the seam underneath the trainer TextBox. Suppress only trainer
    -- sight and native input for the engine update between each yield. Restore
    -- the exact prior instance values immediately on resume; no trainer/save
    -- flag or production method is changed.
    local syntheticGuard = newSyntheticFrameGuard(game, ow, label)
    local step = firstCell <= lastCell and 1 or -1
    local started, previous = love.timer.getTime(), love.timer.getTime()
    local maxGap, frames = 0, 0
    local gapStats = newGapStats()
    local firstBody, firstAux, firstAtlas, firstPlan
    local cell = firstCell
    beginFrameMetrics(label, "APPROACH")
    print(("VASC_QA_%s_APPROACH_BEGIN map=%s target=%s dir=%s "
           .. "first=%d last=%d frames_per_cell=%d")
      :format(label, tostring(ow.map and ow.map.id), mapId, direction,
              firstCell, lastCell, framesPerCell))
    while true do
      if direction == "left" or direction == "right" then
        p.cellX, p.cellY = cell, fixedCell
      else
        p.cellX, p.cellY = fixedCell, cell
      end
      p.px, p.py, p.facing = p.cellX * 16, p.cellY * 16, direction
      for _ = 1, framesPerCell do
        syntheticGuard:install(cell, frames + 1)
        coroutine.yield()
        syntheticGuard:restore()
        frames = frames + 1
        requireSyntheticIdle(game, ow, label, "post-yield", cell, frames)
        requireSyntheticWildIdle(
          syntheticGuard.wildsLogic, label, "post-yield", cell, frames,
          ow, syntheticGuard.wildsReceiptMode)
        local now = love.timer.getTime()
        local gap = now - previous
        previous = now
        recordGap(gapStats, gap)
        if gap > maxGap then maxGap = gap end
        consumeFrameTrace(gap, false)
        local status = neighbourWarmStatus(mapId)
        local elapsed = now - started
        if status.body and not firstBody then firstBody = elapsed end
        if status.aux and not firstAux then firstAux = elapsed end
        if status.atlas and not firstAtlas then firstAtlas = elapsed end
        if status.planned and not firstPlan then firstPlan = elapsed end
      end
      if cell == lastCell then break end
      cell = cell + step
    end
    syntheticGuard:restore()
    requireSyntheticIdle(game, ow, label, "post-approach", lastCell, frames)
    local status = neighbourWarmStatus(mapId)
    endFrameMetrics()
    print(("VASC_QA_%s_APPROACH_END frames=%d elapsed=%.3f max_gap=%.3f "
           .. "body=%d aux=%d atlas=%d plan=%d "
           .. "body_at=%s aux_at=%s atlas_at=%s plan_at=%s "
           .. "wild_sight_suppressed=%d")
      :format(label, frames, love.timer.getTime() - started, maxGap,
        asFlag(status.body), asFlag(status.aux), asFlag(status.atlas),
        asFlag(status.planned), tostring(firstBody), tostring(firstAux),
        tostring(firstAtlas), tostring(firstPlan),
        syntheticGuard.wildSightSuppressed))
    printPlanStatus(label, "APPROACH_END")
    printHorizonCacheStatus(label, "APPROACH_END")
    printPercentiles(label, "APPROACH", gapStats)
  end

  -- The manual QA identity is reused between visual audits, so its save may
  -- legitimately be on the last inspected route.  Normalize the starting
  -- map instead of silently waiting forever for Pallet to appear.
  if not ow.map or ow.map.id ~= "PALLET_TOWN" then
    print(("VASC_QA_BOOTSTRAP %s -> PALLET_TOWN")
      :format(tostring(ow.map and ow.map.id)))
    ow:startWarpTo("PALLET_TOWN", 10, 12, "up")
  end
  waitReady("PALLET", "PALLET_TOWN", 900)
  for _ = 1, 30 do coroutine.yield() end

  local route8FinalFullGCRaw = os.getenv("VASC_QA_ROUTE8_FINAL_FULL_GC")
  if sequence ~= "route8_seams" then
    route8FinalFullGCEnabled(route8FinalFullGCRaw, sequence,
                             traceEnabled, nil)
  end
  if sequence == "route_loop" then
    warp("ROUTE1_COLD", "ROUTE_1", 5, 5)
    warp("PALLET_RETURN", "PALLET_TOWN", 10, 12)
    warp("ROUTE1_RETURN", "ROUTE_1", 5, 5)
  elseif sequence == "seam_loop" then
    -- Exercise the actual scrolling connection path rather than a faded
    -- warp.  This is the path a player uses while walking from Pallet into
    -- Route 1 and is where a one-frame 2D fallback would be visible.
    local p = assert(ow.player)
    p.cellX, p.cellY = 10, 0
    p.px, p.py = p.cellX * 16, p.cellY * 16
    p.facing = "up"
    seam("PALLET_ROUTE1_SEAM", "up", "ROUTE_1")
    p = assert(ow.player)
    p.cellX, p.cellY = 10, ow.map.heightCells - 1
    p.px, p.py = p.cellX * 16, p.cellY * 16
    p.facing = "down"
    seam("ROUTE1_PALLET_SEAM", "down", "PALLET_TOWN")
  elseif sequence == "forest" then
    warp("FOREST", "VIRIDIAN_FOREST", 16, 43)
  elseif sequence == "route4" then
    warp("ROUTE4", "ROUTE_4", 6, 16)
  elseif sequence == "center_entries" then
    -- One process is essential here: the first door visit is cold, the exit
    -- retains the just-rendered Center, and the second visit proves the warm
    -- return. Both directions use real map warp records; only the source boot
    -- is a setup warp and is deliberately outside the per-frame certificate.
    local visited = {}
    for _, spec in ipairs(centerEntrySpecs()) do
      warp(spec.key .. "_SOURCE_BOOT", spec.sourceMap,
           spec.sourceX, spec.sourceY, { stableFrames = 30 })
      for _, leg in ipairs(centerEntryLegs(spec)) do
        if leg.temperature == "cold" and visited[leg.toMap] then
          error("VASC_QA_" .. leg.label .. " target was already visited", 0)
        elseif leg.temperature == "warm" and not visited[leg.toMap] then
          error("VASC_QA_" .. leg.label .. " has no cold predecessor", 0)
        end
        centerDoorWarp(leg)
        if leg.temperature == "cold" then visited[leg.toMap] = true end
      end
    end

    local totalFrames, totalBirdseye, totalBlack, totalCover = 0, 0, 0, 0
    local passed = #centerAuditSummaries == #CENTER_ENTRY_SPECS * 3
    for _, summary in ipairs(centerAuditSummaries) do
      totalFrames = totalFrames + summary.frames
      totalBirdseye = totalBirdseye + summary.birdseye
      totalBlack = totalBlack + summary.black
      totalCover = totalCover + summary.qaCover
      passed = passed and summary.pass
    end
    print(("VASC_QA_CENTER_ENTRIES_CERT status=%s maps=%d legs=%d frames=%d "
           .. "birdseye=%d black=%d qa_cover=%d")
      :format(passed and "PASS" or "FAIL", #CENTER_ENTRY_SPECS,
        #centerAuditSummaries, totalFrames, totalBirdseye,
        totalBlack, totalCover))
    if not passed then
      runViolations[#runViolations + 1] = "center_entries:aggregate-certification"
    end
  elseif sequence == "route8" then
    -- Use the real west connection on both sides of the seam. The first leg
    -- starts from Pallet with a cold cache and requires Route 8's exact seven
    -- streamed neighbours. Saffron then becomes the bridge map before the
    -- same Route-8 union is requested again from the one-neighbour return
    -- cache. CURRENT_READY and FULL_WARM therefore measure the player-facing
    -- transition separately from cold and warm background convergence.
    local route8Union = {
      "LAVENDER_TOWN", "SAFFRON_CITY", "ROUTE_10", "ROUTE_12",
      "ROUTE_5", "ROUTE_6", "ROUTE_7",
    }
    warp("ROUTE8_COLD", "ROUTE_8", 0, 8,
         { fullWarm = true, expectedNeighbors = route8Union })
    warp("SAFFRON_BRIDGE", "SAFFRON_CITY", 39, 16)
    warp("ROUTE8_RETURN", "ROUTE_8", 0, 8,
         { fullWarm = true, expectedNeighbors = route8Union })
  elseif sequence == "saffron_profile" then
    -- Small native profiling target: isolates Saffron's cold current-map
    -- build without waiting for Route 8's seven-map full-union audit.
    warp("SAFFRON_PROFILE", "SAFFRON_CITY", 39, 17,
         { stableFrames = 0 })
  elseif sequence == "route8_seams" then
    -- Release-candidate path: exercise the same unfaded re-root operation a
    -- player triggers by walking across both Route-8 borders.  The exact
    -- median lanes are pinned from the reciprocal map connections, then each
    -- direction is tested so retained handoff geometry and canonical horizon
    -- reuse are covered as well as the cold first leg.
    -- Start at the opposite end and traverse the current source map at the
    -- fast eight-frame cell cadence. This gives every ordinary background job
    -- the same travel time a real player supplies, while the final cells
    -- exercise the explicit seam-priority window. The default A/one-pass
    -- matrix expands to the byte-for-byte historical ABCD operations below;
    -- explicit rotations let a ten-process campaign distribute first-seam
    -- cold starts without paying for forty separate app launches.
    local matrix = route8SeamMatrix(os.getenv("VASC_QA_ROUTE8_START_CASE"),
                                    os.getenv("VASC_QA_ROUTE8_PASSES"))
    local finalFullGCEnabled = route8FinalFullGCEnabled(
      route8FinalFullGCRaw, sequence, traceEnabled, matrix.passes)
    print(("VASC_QA_ROUTE8_MATRIX start_case=%s passes=%d order=%s")
      :format(matrix.startCase, matrix.passes, matrix.order))

    local first = matrix.legs[1]
    local passHeapKB = {}
    warp("ROUTE8_SEAM_BOOT", first.bootMap, first.bootX, first.bootY,
         { stableFrames = 0 })
    for passIndex = 1, matrix.passes do
      local temperature = passIndex == 1 and "cold_first_pass" or "warm"
      print(("VASC_QA_ROUTE8_PASS_BEGIN index=%d temperature=%s order=%s")
        :format(passIndex, temperature, matrix.order))
      for ordinal, leg in ipairs(matrix.legs) do
        if not ow.map or ow.map.id ~= leg.sourceMap then
          error(("VASC_QA_ROUTE8_PASS source mismatch pass=%d leg=%s "
                 .. "expected=%s actual=%s")
            :format(passIndex, leg.key, leg.sourceMap,
                    tostring(ow.map and ow.map.id)), 0)
        end
        local suffix = passIndex == 1 and "" or "_P" .. passIndex
        -- The first leg needs a predictive walk from its cold boot root. Route
        -- 8 source legs always traverse the full corridor; reciprocal city
        -- returns retain the historical immediate turnaround unless they own
        -- the rotated start position.
        if ordinal == 1 or leg.sourceMap == "ROUTE_8" then
          approachSeam(leg.approachLabel .. suffix, leg.direction,
                       leg.targetMap, leg.approachFirst, leg.approachLast,
                       leg.approachFixed, 8)
        end
        local p = assert(ow.player)
        p.cellX, p.cellY = leg.crossX, leg.crossY
        p.px, p.py = p.cellX * 16, p.cellY * 16
        p.facing = leg.direction
        seam(leg.seamLabel .. suffix, leg.direction, leg.targetMap)
      end
      if traceHeapNow then
        passHeapKB[passIndex] = traceHeapNow()
        print(route8PassHeapLine(passIndex, temperature, passHeapKB[passIndex]))
      end
      print(("VASC_QA_ROUTE8_PASS_END index=%d temperature=%s order=%s")
        :format(passIndex, temperature, matrix.order))
    end
    if finalFullGCEnabled then
      local pending = Mesher.pending()
      if pending ~= 0 then
        error("VASC_QA_ROUTE8_FINAL_FULL_GC requires pending=0 actual="
              .. tostring(pending), 0)
      end
      if not traceFinalFullGC or not passHeapKB[1] then
        error("VASC_QA_ROUTE8_FINAL_FULL_GC trace collector unavailable", 0)
      end
      print(route8FinalFullGCLine(traceFinalFullGC(), passHeapKB[1], pending))
    end
  else
    error("VASC_QA_SEQUENCE unknown sequence " .. tostring(sequence))
  end
  if #runViolations > 0 then
    if centerSequence then
      error("VASC_QA_CENTER_ENTRIES violations: "
            .. table.concat(runViolations, ";"))
    end
    error("VASC_QA_TRANSITION visible neighbour(s) before aux: "
          .. table.concat(runViolations, ";"))
  end
  print("VASC_QA_TRANSITION_DONE")
  -- POKEPORT_DRIVER coroutines deliberately remain alive after DONE.  When
  -- stdout is redirected to a release-evidence log, stdio can otherwise keep
  -- the final marker buffered forever because the process never exits on its
  -- own.  Flush only the QA stream after the terminal marker; gameplay and
  -- every measured frame are already complete at this point.
  if io and io.stdout and type(io.stdout.flush) == "function" then
    pcall(io.stdout.flush, io.stdout)
  end

  while true do coroutine.yield() end
end

-- Headless contracts exercise the synthetic-frame ownership boundary without
-- constructing a LÖVE game. A normal POKEPORT_DRIVER load receives only run.
if rawget(_G, "VASC_TRANSITION_QA_TEST") then
  return {
    stackStateType = stackStateType,
    stackDepth = stackDepth,
    qaBootStateKind = qaBootStateKind,
    newQAContinueBootstrap = newQAContinueBootstrap,
    requireOverworldTop = requireOverworldTop,
    requireSyntheticIdle = requireSyntheticIdle,
    requireSyntheticWildIdle = requireSyntheticWildIdle,
    newSyntheticFrameGuard = newSyntheticFrameGuard,
    centerEntrySpecs = centerEntrySpecs,
    centerEntryLegs = centerEntryLegs,
    route8SeamMatrix = route8SeamMatrix,
    newGCMetric = newGCMetric,
    recordGCMetric = recordGCMetric,
    gcMetricPercentile = gcMetricPercentile,
    gcSummaryLine = gcSummaryLine,
    heapEndLine = heapEndLine,
    route8PassHeapLine = route8PassHeapLine,
    route8FinalFullGCEnabled = route8FinalFullGCEnabled,
    collectRoute8FinalFullGC = collectRoute8FinalFullGC,
    route8FinalFullGCLine = route8FinalFullGCLine,
    targetCacheLine = targetCacheLine,
    transitionStackType = transitionStackType,
    classifyCenterEntryFrame = classifyCenterEntryFrame,
    summarizeCenterEntryFrames = summarizeCenterEntryFrames,
    centerEntryFrameLine = centerEntryFrameLine,
  }
end

return run
