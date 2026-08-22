-- QA-only panorama and point-of-interest screenshot audit for VASC.
--
-- This file is a POKEPORT_DRIVER, never a production mod module. It writes
-- through love.graphics.captureScreenshot into the selected LÖVE identity:
--
--   VASC_PANORAMA_MAPS=ROUTE_1,ROUTE_2       explicit map ids, or
--   VASC_PANORAMA_PRESET=routes              routes|towns|caves|forests|
--                                             outdoor|semantic|all
--   VASC_PANORAMA_MODES=panorama,connections,warps,buildings
--   VASC_PANORAMA_DIRECTIONS=N,E,S,W
--   VASC_PANORAMA_RUN=20260820-a              one safe path segment
--   VASC_PANORAMA_OUT=qa/panorama-audit       relative to LÖVE save dir
--   VASC_PANORAMA_TIMEOUT_FRAMES=1800         per readiness/pose wait
--   VASC_PANORAMA_SETTLE_FRAMES=45            stable 3D frames per shot
--   VASC_PANORAMA_CAPTURE_TIMEOUT_FRAMES=300  screenshot encoder wait
--   VASC_PANORAMA_FULL_UNION=1                include every streamed map
--   VASC_PANORAMA_CONTINUE_ON_FAILURE=1        finish later maps, then fail run
--   VASC_PANORAMA_PITCH_DEG=10
--   VASC_PANORAMA_ZOOM=1
--   VASC_PANORAMA_CAMERA=1..7       orbit rungs or 1ST/3RD (default 7)
--   VASC_PANORAMA_CAMERA_PRESET=orbit35-fit|orbit75-maxout|1st|3rd
--   VASC_PANORAMA_ORBIT_ZOOM=fit|maxout
--   VASC_PANORAMA_ALLOW_COLLAPSED_BOOM=1  explicit 3RD stress evidence
--   VASC_PANORAMA_ROUTE4_PORTAL_VIEWS=1   exact Route 4 warp #2/#3
--                                             front/three-quarter QA only
--   VASC_PANORAMA_ROUTE8_SAFFRON_FOCUS=1  exact reciprocal seam/context
--                                             QA only (3 PNGs per camera)
-- Current engines additionally require POKEPORT_PLAYTEST=1 and
-- POKEPORT_PLAYTEST_AUTO_CONTINUE=1. Exact public 0.1.90 builds predate that
-- capability, so this driver follows their real Intro -> CONTINUE input path.
-- Normal-orbit presets default to panorama/N only; their fixed north yaw cannot
-- truthfully produce free-camera connection/warp/building elevations.
--
-- Output layout:
--   <out>/<run>/<MAP>/panorama/anchor01/N.png
--   <out>/<run>/<MAP>/panorama/surf01/N.png
--   <out>/<run>/<MAP>/connections/<dir>-<target>-<index>.png
--   <out>/<run>/<TOWN>/connections/<dir>-<route>-<index>-entry-context.png
--   <out>/<run>/<MAP>/warps/<index>-<target>-x-y.png
--   <out>/<run>/<MAP>/buildings/<index>-txN-tyN-front.png
-- plus manifest.tsv and manifest.json at the run root. CAPTURE/FAIL/MAP_FAIL/
-- DONE/PARTIAL records printed to stdout are intentionally machine-readable.

local function trim(value)
  return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function csv(value, upper)
  local out, seen = {}, {}
  for item in tostring(value or ""):gmatch("[^,]+") do
    item = trim(item)
    if upper then item = string.upper(item) end
    if item ~= "" and not seen[item] then
      seen[item] = true
      out[#out + 1] = item
    end
  end
  return out
end

-- A POKEPORT_DRIVER is created only after Game:load. Current engines have a
-- guarded playtest auto-continue capability and can therefore hand the
-- coroutine an already restored Overworld. Exact public 0.1.90 instead leaves
-- IntroMovie on top. Drive only that capability-old path through the same
-- public input edges a player uses: Intro, interactive Title, the real
-- localized CONTINUE row, ContinueInfo, then TitleState.onContinue. There is
-- deliberately no save loader, restoreSave, direct setMap or stack-write path.
local function qaBootStateType(state)
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

local function qaBootStackDepth(game)
  return game and game.stack and type(game.stack.states) == "table"
    and #game.stack.states or -1
end

local function qaBootStateKind(state)
  if type(state) ~= "table" then return "unknown" end
  local source = qaBootStateType(state)
  if source:match("IntroMovie%.lua$") then return "intro" end
  if source:match("YellowIntro%.lua$") then return "intro" end
  if source:match("Menu%.lua$") and type(state.items) == "table"
     and type(state.index) == "number" then
    return "menu"
  end
  if source:match("QuarantineReport%.lua$") then
    if state.screenId == "QuarantineReport" and state.isOpaque == true
       and type(state.report) == "table" and type(state.lines) == "table"
       and type(state.offset) == "number"
       and type(state.maxOffset) == "function"
       and type(state.game) == "table" then
      return "quarantine_report"
    end
    return "unknown"
  end
  if source:match("TitleState%.lua$") then
    if type(state.title) == "table" and type(state.save) == "table" then
      return "continue_info"
    end
    if type(state.openMenu) == "function" and type(state.phase) == "string" then
      return "title"
    end
  end
  -- Kanto Ascendant 6.7 replaces TitleState.update with its final paired-title
  -- controller.  The state remains the engine's real interactive TitleState;
  -- only debug provenance moves to this exact wrapper file.  Accept that one
  -- public shape so the QA driver can still take the authentic
  -- START -> CONTINUE -> ContinueInfo route.  Similar filenames or partial
  -- tables remain unknown and receive no synthetic input.
  if source == "table:crystal_v15_features.lua"
     and state.screenId == "TitleState"
     and type(state.openMenu) == "function"
     and type(state.currentSprite) == "function"
     and type(state.phase) == "string"
     and type(state.cycleSpecies) == "table"
     and type(state.cycleIndex) == "number" then
    return "title"
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
  local source = "vasc:manual-panorama-bootstrap"
  input:sourcePress(button, source)
  input:sourceRelease(button, source)
  self.inputEdges = self.inputEdges + 1
end

function QAContinueBootstrap:failUnexpected(kind)
  qaBootstrapError("UNEXPECTED_STATE",
    ("mode=%s stage=%s kind=%s top=%s depth=%d frame=%d")
      :format(self.mode, self.stage, tostring(kind),
        qaBootStateType(self.game.stack:top()),
        qaBootStackDepth(self.game), self.frame))
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
        :format(tostring(kind), qaBootStateType(top)))
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
       or top.game ~= self.game or not self.game.overworld.map then
      qaBootstrapError("QUARANTINE_STACK",
        "load report is not the sole screen above restored Overworld")
    end
    self:enter("quarantine_acknowledged")
    self:tap("a")
    return false
  end

  return self:failUnexpected(kind)
end

local function safeRelativePath(value, label)
  value = trim(value)
  label = label or "path"
  if value == "" then error("VASC_PANORAMA_FAIL phase=config reason=empty-" .. label, 0) end
  if value:sub(1, 1) == "/" or value:sub(1, 1) == "\\"
     or value:match("^%a:[/\\]") then
    error("VASC_PANORAMA_FAIL phase=config reason=absolute-" .. label, 0)
  end
  if value:find("\\", 1, true) or value:find("%z") then
    error("VASC_PANORAMA_FAIL phase=config reason=invalid-" .. label, 0)
  end
  for part in value:gmatch("[^/]+") do
    if part == ".." or part == "." or not part:match("^[%w_.-]+$") then
      error("VASC_PANORAMA_FAIL phase=config reason=unsafe-" .. label, 0)
    end
  end
  return value:gsub("/+$", "")
end

local function safeSegment(value, label)
  value = safeRelativePath(value, label)
  if value:find("/", 1, true) then
    error("VASC_PANORAMA_FAIL phase=config reason=nested-" .. (label or "segment"), 0)
  end
  return value
end

-- KASC's optional area banner is useful in play, but it is UI occlusion in a
-- scenery audit.  Disable it only in the disposable QA process and without
-- calling the option writer: the installed mod and the user's save remain
-- untouched.  The legacy id keeps the driver useful with older KASC builds.
local function disableLocationBanners(game)
  local mods = game and game.mods
  local exports = mods and mods.exports
  local saveOptions = game and game.save and game.save.options
  local changed = 0
  for _, id in ipairs({ "kanto_ascendant", "trainer_rematch" }) do
    local liveBucket = mods and mods.modOptions and mods.modOptions[id]
    local saveBucket = saveOptions and saveOptions.modOptions
      and saveOptions.modOptions[id]
    if (exports and exports[id] ~= nil) or liveBucket or saveBucket then
      if saveOptions then
        saveOptions.modOptions = saveOptions.modOptions or {}
        saveOptions.modOptions[id] = saveOptions.modOptions[id] or {}
        saveOptions.modOptions[id].qol_location_banners = false
      end
      if mods then
        mods.modOptions = mods.modOptions or {}
        mods.modOptions[id] = mods.modOptions[id] or {}
        mods.modOptions[id].qol_location_banners = false
      end
      changed = changed + 1
    end
  end
  return changed
end

local function naturalLess(a, b)
  local ap, an = a:match("^(.-)(%d+)$")
  local bp, bn = b:match("^(.-)(%d+)$")
  if ap and bp and ap == bp and tonumber(an) ~= tonumber(bn) then
    return tonumber(an) < tonumber(bn)
  end
  return a < b
end

local function mapCategory(id, def)
  if id:match("^ROUTE_%d+$") then return "route" end
  if def.tileset == "CAVERN" then return "cave" end
  if id:find("FOREST", 1, true) then return "forest" end
  if id:match("_CITY$") or id:match("_TOWN$")
     or id == "INDIGO_PLATEAU" then return "town" end
  if def.outdoor == true or def.tileset == "OVERWORLD" then return "outdoor" end
  return "interior"
end

local function mapsForPreset(data, preset)
  preset = string.lower(trim(preset))
  local known = {
    routes = true, towns = true, caves = true, forests = true,
    outdoor = true, semantic = true, all = true,
  }
  if not known[preset] then
    error("VASC_PANORAMA_FAIL phase=config reason=unknown-preset preset="
          .. tostring(preset), 0)
  end
  local out = {}
  for id, def in pairs((data and data.maps) or {}) do
    local category = mapCategory(id, def)
    local take = preset == "all"
      or (preset == "routes" and category == "route")
      or (preset == "towns" and category == "town")
      or (preset == "caves" and category == "cave")
      or (preset == "forests" and category == "forest")
      or (preset == "outdoor" and (def.outdoor == true
                                    or def.tileset == "OVERWORLD"))
      or (preset == "semantic" and (def.outdoor == true
                                     or def.tileset == "OVERWORLD"
                                     or category == "cave"
                                     or category == "forest"))
    if take then out[#out + 1] = id end
  end
  table.sort(out, naturalLess)
  if #out == 0 then
    error("VASC_PANORAMA_FAIL phase=config reason=empty-preset preset="
          .. tostring(preset), 0)
  end
  return out
end

local function walkable(map, x, y, occupied)
  if not (map and map.inBounds and map:inBounds(x, y)
          and map.isWalkableCell and map:isWalkableCell(x, y)) then
    return false
  end
  if map.isWaterCell and map:isWaterCell(x, y) then return false end
  if map.isWarpTileCell and map:isWarpTileCell(x, y) then return false end
  if map.warpAtCell and map:warpAtCell(x, y) then return false end
  return not (occupied and occupied[y * map.widthCells + x])
end

local CARDINAL = {
  N = { name = "N", facing = "up", dx = 0, dy = -1, yaw = math.pi },
  E = { name = "E", facing = "right", dx = 1, dy = 0, yaw = math.pi / 2 },
  S = { name = "S", facing = "down", dx = 0, dy = 1, yaw = 0 },
  W = { name = "W", facing = "left", dx = -1, dy = 0, yaw = -math.pi / 2 },
}

local function occupiedCells(map)
  local out = {}
  for _, object in ipairs((map.def and map.def.objects) or {}) do
    if object.x ~= nil and object.y ~= nil then
      out[object.y * map.widthCells + object.x] = true
    end
  end
  return out
end

local function openRadius(map, x, y, occupied, limit)
  local answer = limit
  for _, bearing in pairs(CARDINAL) do
    local run = 0
    for step = 1, limit do
      if not walkable(map, x + bearing.dx * step,
                       y + bearing.dy * step, occupied) then break end
      run = step
    end
    if run < answer then answer = run end
  end
  return answer
end

-- Pick the safest walkable cell close to the visual centre. The large
-- penalties mean a clear three-cell boom wins where one exists, after which
-- distance to centre is the tie-breaker. Routes with no such clearing still
-- get their best valid cell instead of an arbitrary hard-coded coordinate.
local function representativeCell(map)
  local occupied = occupiedCells(map)
  local cx, cy = (map.widthCells - 1) / 2, (map.heightCells - 1) / 2
  local best, bestScore
  for y = 0, map.heightCells - 1 do
    for x = 0, map.widthCells - 1 do
      if walkable(map, x, y, occupied) then
        local edge = math.min(x, y, map.widthCells - 1 - x,
                              map.heightCells - 1 - y)
        local clear = openRadius(map, x, y, occupied, 3)
        local score = math.max(0, 3 - clear) * 10000
                    + math.max(0, 3 - edge) * 1000
                    + math.abs(x - cx) + math.abs(y - cy)
        if not bestScore or score < bestScore then
          best, bestScore = { x = x, y = y, clear = clear }, score
        end
      end
    end
  end
  return best
end

local LONG_ROUTE_CELLS = 54

local function anchoredRepresentative(map, targetLong, axis, occupied, used)
  local longLength = axis == "x" and map.widthCells or map.heightCells
  local crossLength = axis == "x" and map.heightCells or map.widthCells
  local targetCross = (crossLength - 1) / 2
  local localRadius = math.max(4, math.floor(longLength * 0.12 + 0.5))

  -- Prefer a genuinely local clearing. Only fall back to the whole map when
  -- water or authored collision leaves no legal observer inside that slice.
  for pass = 1, 2 do
    local best, bestScore
    for y = 0, map.heightCells - 1 do
      for x = 0, map.widthCells - 1 do
        if walkable(map, x, y, occupied) then
          local long = axis == "x" and x or y
          local cross = axis == "x" and y or x
          local along = math.abs(long - targetLong)
          if pass == 2 or along <= localRadius then
            local edge = math.min(x, y, map.widthCells - 1 - x,
                                  map.heightCells - 1 - y)
            local clear = openRadius(map, x, y, occupied, 3)
            local key = tostring(x) .. ":" .. tostring(y)
            local score = (used and used[key] and 1000000 or 0)
                        + math.max(0, 3 - clear) * 10000
                        + math.max(0, 3 - edge) * 1000
                        + along * 20 + math.abs(cross - targetCross)
            if not bestScore or score < bestScore then
              best = { x = x, y = y, clear = clear, target = targetLong,
                       axis = axis }
              bestScore = score
            end
          end
        end
      end
    end
    if best then return best end
  end
  return nil
end

-- A release transition audit must not judge a city or forest only from its
-- centre.  These four stations deliberately sit at different longitudinal
-- fractions and look out through different real edges, so they are neither a
-- centre-only sample nor four points on one line.  The observer remains a
-- normal walkable, unoccupied cell with symmetric camera clearance; no free
-- camera or map mutation is introduced for the sake of the screenshot.
local EDGE_AUDIT_SPECS = {
  { name = "edge-north", edge = "north", direction = "N", fraction = 0.24 },
  { name = "edge-east",  edge = "east",  direction = "E", fraction = 0.37 },
  { name = "edge-south", edge = "south", direction = "S", fraction = 0.76 },
  { name = "edge-west",  edge = "west",  direction = "W", fraction = 0.63 },
}

local function edgeAuditRepresentative(map, spec, occupied, used)
  local horizontal = spec.edge == "north" or spec.edge == "south"
  local alongLength = horizontal and map.widthCells or map.heightCells
  local normalLength = horizontal and map.heightCells or map.widthCells
  local targetAlong = (alongLength - 1) * spec.fraction
  local inset = math.max(1, math.min(4, math.floor((normalLength - 1) / 3)))
  local targetNormal = (spec.edge == "north" or spec.edge == "west")
                       and inset or normalLength - 1 - inset
  local best, bestScore
  for y = 0, map.heightCells - 1 do
    for x = 0, map.widthCells - 1 do
      if walkable(map, x, y, occupied) then
        local along = horizontal and x or y
        local normal = horizontal and y or x
        local clear = openRadius(map, x, y, occupied, 3)
        local key = tostring(x) .. ":" .. tostring(y)
        local score = (used[key] and 1000000 or 0)
                    + math.max(0, 3 - clear) * 10000
                    + math.abs(normal - targetNormal) * 100
                    + math.abs(along - targetAlong)
        if not bestScore or score < bestScore then
          best = { x = x, y = y, clear = clear, name = spec.name,
                   edge = spec.edge, direction = spec.direction,
                   fraction = spec.fraction }
          bestScore = score
        end
      end
    end
  end
  return best
end

local function edgeAuditAnchors(map)
  local occupied, used, out = occupiedCells(map), {}, {}
  for _, spec in ipairs(EDGE_AUDIT_SPECS) do
    local cell = edgeAuditRepresentative(map, spec, occupied, used)
    if not cell then return {} end
    used[tostring(cell.x) .. ":" .. tostring(cell.y)] = true
    out[#out + 1] = cell
  end
  return out
end

-- Routes at least 27 ROM blocks long receive three evenly distributed audit
-- stations. This is intentionally based on absolute span rather than aspect
-- ratio: short connector routes remain one coherent scene even when narrow.
local function panoramaAnchors(map, edgeAudit)
  if edgeAudit then return edgeAuditAnchors(map) end
  local horizontal = map.widthCells > map.heightCells
  local longLength = horizontal and map.widthCells or map.heightCells
  local elongated = tostring(map.id or ""):match("^ROUTE_%d+$")
    and longLength >= LONG_ROUTE_CELLS
  if not elongated then
    local cell = representativeCell(map)
    if not cell then return {} end
    cell.name, cell.fraction = "anchor01", 0.5
    cell.axis = horizontal and "x" or "y"
    return { cell }
  end

  local occupied, used, out = occupiedCells(map), {}, {}
  local axis = horizontal and "x" or "y"
  for index, fraction in ipairs({ 0.2, 0.5, 0.8 }) do
    local cell = anchoredRepresentative(map, (longLength - 1) * fraction,
                                        axis, occupied, used)
    if not cell then return {} end
    cell.name = ("anchor%02d"):format(index)
    cell.fraction = fraction
    used[tostring(cell.x) .. ":" .. tostring(cell.y)] = true
    out[#out + 1] = cell
  end
  return out
end

local function waterCell(map, x, y, occupied)
  if not (map and map.inBounds and map:inBounds(x, y)
          and map.isWaterCell and map:isWaterCell(x, y)) then
    return false
  end
  if map.isWarpTileCell and map:isWarpTileCell(x, y) then return false end
  if map.warpAtCell and map:warpAtCell(x, y) then return false end
  return not (occupied and occupied[y * map.widthCells + x])
end

local function openWaterRadius(map, x, y, occupied, limit)
  local answer = limit
  for _, bearing in pairs(CARDINAL) do
    local run = 0
    for step = 1, limit do
      if not waterCell(map, x + bearing.dx * step,
                       y + bearing.dy * step, occupied) then break end
      run = step
    end
    if run < answer then answer = run end
  end
  return answer
end

local function representativeSurfCell(map)
  local occupied = occupiedCells(map)
  local cx, cy = (map.widthCells - 1) / 2, (map.heightCells - 1) / 2
  local best, bestScore
  for y = 0, map.heightCells - 1 do
    for x = 0, map.widthCells - 1 do
      if waterCell(map, x, y, occupied) then
        local edge = math.min(x, y, map.widthCells - 1 - x,
                              map.heightCells - 1 - y)
        local clear = openWaterRadius(map, x, y, occupied, 3)
        local score = math.max(0, 3 - clear) * 10000
                    + math.max(0, 3 - edge) * 1000
                    + math.abs(x - cx) + math.abs(y - cy)
        if not bestScore or score < bestScore then
          best, bestScore = { x = x, y = y, clear = clear }, score
        end
      end
    end
  end
  return best
end

-- A walking 3RD shot needs enough boom to show the player's card: otherwise
-- an accidentally obstructed audit anchor silently turns into a first-person
-- composition. Surfing is the deliberate exception. Water is non-walkable to
-- the engine's ordinary collision query, so the production boom can retract
-- below SHOW_AT even in a large, valid patch of open water. The exact rendered
-- map/yaw/pitch/cell/surf state is still proved separately by renderReady and
-- screenshot(); waiting for player-card visibility here can therefore never
-- become true and only converts a useful record of the real surf camera into a
-- readiness timeout.
local function thirdPersonPoseReady(extension, boom, showAt, surfing,
                                    allowCollapsed)
  return (extension or 0) >= 0.999
    and (allowCollapsed == true or surfing == true
         or (boom or 0) >= (showAt or 0))
end

-- 1ST and 3RD are the same player-attached world rig with different boom
-- targets.  Keeping this gate explicit lets identical audit poses prove that
-- scenery is genuine VoxelScene geometry rather than a 3RD-only composition.
local function freeCameraPoseReady(level, extension, boom, showAt, surfing,
                                   allowCollapsed)
  if level == 6 then return (extension or 0) <= 0.001 end
  return level == 7
    and thirdPersonPoseReady(extension, boom, showAt, surfing,
                             allowCollapsed)
end

local CAMERA_ANGLES_DEG = { 35, 35, 15, 35, 50, 75, 75, 75 }
local CAMERA_PRESETS = {
  ["orbit35-fit"] = { level = 3, orbitZoom = "fit" },
  ["orbit75-maxout"] = { level = 5, orbitZoom = "maxout" },
  ["1st"] = { level = 6 },
  ["3rd"] = { level = 7 },
  ["3rd-collapsed-stress"] = { level = 7, allowCollapsed = true },
}

local function cameraModeForLevel(level)
  if level and level >= 1 and level <= 5 then return "orbit" end
  if level == 6 then return "1st" end
  if level == 7 then return "3rd" end
  return nil
end

local function strictFlag(value, key)
  value = trim(value)
  if value == "" or value == "0" then return false end
  if value == "1" then return true end
  error("VASC_PANORAMA_FAIL phase=config reason=invalid-flag key="
        .. tostring(key) .. " value=" .. tostring(value), 0)
end

-- Resolve camera selection without touching runtime state. The named presets
-- are deliberately small: they pin the two normal-orbit release views while
-- the numeric level remains available for every real voxel rung. Level zero
-- is never accepted because it is the 2D fallback this audit must not certify.
local function panoramaCameraConfig(options)
  options = options or {}
  local rawLevel = trim(options.camera)
  local rawPreset = string.lower(trim(options.preset))
  if rawLevel ~= "" and rawPreset ~= "" then
    error("VASC_PANORAMA_FAIL phase=config reason=camera-and-camera-preset", 0)
  end

  local preset = rawPreset ~= "" and CAMERA_PRESETS[rawPreset] or nil
  if rawPreset ~= "" and not preset then
    error("VASC_PANORAMA_FAIL phase=config reason=unknown-camera-preset preset="
          .. tostring(rawPreset), 0)
  end

  local level
  if preset then
    level = preset.level
  elseif rawLevel == "" then
    level = 7
  else
    level = tonumber(rawLevel)
    if not level or level ~= math.floor(level) then
      error("VASC_PANORAMA_FAIL phase=config reason=invalid-camera", 0)
    end
  end
  local mode = cameraModeForLevel(level)
  if not mode then
    error("VASC_PANORAMA_FAIL phase=config reason=invalid-camera", 0)
  end

  local pitchDeg = tonumber(trim(options.pitch) ~= ""
                            and trim(options.pitch) or "10")
  local boomZoom = tonumber(trim(options.zoom) ~= ""
                          and trim(options.zoom) or "1")
  if not pitchDeg or pitchDeg < -50 or pitchDeg > 70 then
    error("VASC_PANORAMA_FAIL phase=config reason=invalid-pitch", 0)
  end
  if not boomZoom or boomZoom < 0.45 or boomZoom > 2.4 then
    error("VASC_PANORAMA_FAIL phase=config reason=invalid-zoom", 0)
  end

  local allowCollapsed = strictFlag(options.allowCollapsed,
                                    "VASC_PANORAMA_ALLOW_COLLAPSED_BOOM")
  if preset and preset.allowCollapsed then allowCollapsed = true end
  if allowCollapsed and mode ~= "3rd" then
    error("VASC_PANORAMA_FAIL phase=config reason=collapsed-boom-needs-3rd", 0)
  end

  local requestedOrbitZoom = string.lower(trim(options.orbitZoom))
  local orbitZoom = preset and preset.orbitZoom or nil
  if requestedOrbitZoom ~= "" then
    if mode ~= "orbit" then
      error("VASC_PANORAMA_FAIL phase=config reason=orbit-zoom-needs-orbit", 0)
    end
    if orbitZoom and requestedOrbitZoom ~= orbitZoom then
      error("VASC_PANORAMA_FAIL phase=config reason=camera-preset-zoom-conflict", 0)
    end
    orbitZoom = requestedOrbitZoom
  end
  if mode == "orbit" then
    orbitZoom = orbitZoom or "fit"
    if orbitZoom ~= "fit" and orbitZoom ~= "maxout" then
      error("VASC_PANORAMA_FAIL phase=config reason=invalid-orbit-zoom", 0)
    end
  elseif requestedOrbitZoom ~= "" then
    error("VASC_PANORAMA_FAIL phase=config reason=orbit-zoom-needs-orbit", 0)
  end

  local angleDeg = CAMERA_ANGLES_DEG[level + 1]
  local name
  if rawPreset ~= "" then
    name = rawPreset
  elseif mode == "orbit" then
    local full = level == 1 and "full-" or ""
    name = ("orbit%d-%s%s"):format(angleDeg, full, orbitZoom)
  else
    name = mode
  end
  local outputTag
  if mode == "orbit" then outputTag = name
  elseif allowCollapsed then outputTag = "3rd-collapsed-stress" end

  return {
    level = level, mode = mode, name = name, outputTag = outputTag,
    angleDeg = angleDeg, pitchDeg = mode == "orbit" and angleDeg or pitchDeg,
    pitch = math.rad(mode == "orbit" and angleDeg or pitchDeg),
    boomZoom = boomZoom, orbitZoom = orbitZoom,
    allowCollapsed = allowCollapsed,
    boomPolicy = allowCollapsed and "collapsed-stress" or "strict",
  }
end

local function cameraOutputPath(path, config)
  local tag = config and config.outputTag
  if not tag or tag == "" then return path end
  local base, extension = tostring(path):match("^(.*)(%.[^./]+)$")
  if not base then return tostring(path) .. "-" .. tag end
  return base .. "-" .. tag .. extension
end

local function cameraDirectionAllowed(config, direction)
  return not (config and config.mode == "orbit") or direction == "N"
end

local function wrapPi(value)
  return (value + math.pi) % (2 * math.pi) - math.pi
end

local function near(a, b, tolerance)
  return type(a) == "number" and type(b) == "number"
    and math.abs(a - b) <= (tolerance or 0.003)
end

-- The selected pipeline, its completed transition, and its zoom are separate
-- facts. Prove all of them. In particular an orbit must have released the
-- player-attached camera entirely; accepting blend>0 would certify a transient
-- dive frame rather than the normal voxel orbit named in the manifest.
local function auditCameraPoseReady(config, live)
  if not (config and live and live.ready == true
          and live.level == config.level
          and near(live.angle, math.rad(config.angleDeg), 0.002)
          and near(live.goal, math.rad(config.angleDeg), 0.002)) then
    return false
  end
  if config.mode == "orbit" then
    return (live.blend or 0) <= 0.001
      and live.cameraKind == "orbit"
      and live.zoomOffset == config.surveyOffset
      and near(live.zoomScale, config.surveyScale, 1e-6)
  end
  return (live.blend or 0) >= 0.999
    and live.cameraKind == "placed"
    and near(live.boomZoom, config.boomZoom, 1e-4)
    and freeCameraPoseReady(config.level, live.extension, live.boom,
                            live.showAt, live.surfing,
                            config.allowCollapsed)
end

-- Proof attached to the exact Scene.render frame. Orbit yaw is fixed north by
-- Voxel3D's real orbit camera (pi in FirstPerson's yaw convention); asking the
-- N/E/S/W free-camera planner to relabel that frame would be false evidence.
local function renderedCameraPoseReady(config, rendered, expected)
  if not (config and rendered and expected
          and rendered.map == expected.map
          and (rendered.frame or -1) >= (expected.frame or 0)
          and rendered.x == expected.x and rendered.y == expected.y
          and rendered.surfing == (expected.surfing == true)
          and rendered.level == config.level
          and near(rendered.angle, math.rad(config.angleDeg), 0.002)
          and rendered.cameraKind == (config.mode == "orbit"
                                      and "orbit" or "placed")) then
    return false
  end
  local wantedYaw = config.mode == "orbit" and math.pi or expected.yaw
  if not near(wrapPi((rendered.yaw or 0) - wantedYaw), 0, 0.003)
     or not near(rendered.pitch, config.pitch, 0.003) then
    return false
  end
  if config.mode == "orbit" then
    return (rendered.blend or 0) <= 0.001
      and rendered.zoomOffset == config.surveyOffset
      and near(rendered.zoomScale, config.surveyScale, 1e-6)
      and rendered.viewW == expected.viewW
      and rendered.viewH == expected.viewH
  end
  return (rendered.blend or 0) >= 0.999
    and near(rendered.boomZoom, config.boomZoom, 1e-4)
    and freeCameraPoseReady(config.level, rendered.extension, rendered.boom,
                            rendered.showAt, rendered.surfing,
                            config.allowCollapsed)
end

local function rounded(value)
  if type(value) ~= "number" then return nil end
  if value >= 0 then return math.floor(value * 1000 + 0.5) / 1000 end
  return math.ceil(value * 1000 - 0.5) / 1000
end

local function cameraManifestFields(config, status)
  status = status or {}
  local rendered = status.rendered or {}
  local boom = rendered.boom
  local showAt = rendered.showAt
  local boomRelevant = config.mode == "3rd"
  local zoom = config.mode == "orbit" and rendered.zoomScale
               or rendered.boomZoom
  return {
    camera_mode = config.mode,
    camera_level = config.level,
    camera_preset = config.name,
    camera_pitch_deg = rounded(rendered.pitch and math.deg(rendered.pitch)
                               or config.pitchDeg),
    camera_yaw_deg = rounded(rendered.yaw and math.deg(rendered.yaw) or nil),
    camera_zoom_kind = config.mode == "orbit" and config.orbitZoom
                       or (config.mode == "3rd" and "boom" or "fixed-eye"),
    camera_zoom = rounded(zoom),
    camera_zoom_offset = rendered.zoomOffset,
    camera_view = rendered.viewW and rendered.viewH
      and (tostring(rendered.viewW) .. "x" .. tostring(rendered.viewH)) or nil,
    render_frame = rendered.frame,
    boom_policy = boomRelevant and config.boomPolicy or nil,
    boom_length = boomRelevant and rounded(boom) or nil,
    boom_collapsed = boomRelevant and type(boom) == "number"
      and type(showAt) == "number" and (boom < showAt and 1 or 0) or nil,
    camera_stress = config.allowCollapsed and "collapsed-boom" or nil,
  }
end

local function preferredSidePenalty(side, x, y, tx, ty)
  if side == "south" then return y > ty and 0 or 800 end
  if side == "north" then return y < ty and 0 or 800 end
  if side == "east" then return x > tx and 0 or 800 end
  if side == "west" then return x < tx and 0 or 800 end
  return 0
end

local function alignmentPenalty(side, dx, dy)
  if side == "south" or side == "north" then return math.abs(dx) * 2 end
  if side == "east" or side == "west" then return math.abs(dy) * 2 end
  return 0
end

local function onPreferredSide(side, x, y, tx, ty)
  if side == "south" then return y > ty end
  if side == "north" then return y < ty end
  if side == "east" then return x > tx end
  if side == "west" then return x < tx end
  return true
end

local function viewCell(map, tx, ty, preferred, desired, strictPreferred)
  local occupied = occupiedCells(map)
  desired = desired or 4
  local best, bestScore
  for y = 0, map.heightCells - 1 do
    for x = 0, map.widthCells - 1 do
      if walkable(map, x, y, occupied)
         and (not strictPreferred
              or onPreferredSide(preferred, x, y, tx, ty)) then
        local dx, dy = tx - x, ty - y
        local distance = math.sqrt(dx * dx + dy * dy)
        if distance >= 1.5 and distance <= math.max(12, desired + 5) then
          local yaw = math.atan2(dx, dy)
          local backX = -math.sin(yaw)
          local backY = -math.cos(yaw)
          local boom = 0
          for step = 1, 3 do
            local bx = math.floor(x + backX * step + 0.5)
            local by = math.floor(y + backY * step + 0.5)
            if not walkable(map, bx, by, occupied) then break end
            boom = step
          end
          local score = preferredSidePenalty(preferred, x, y, tx, ty)
                      + math.max(0, 3 - boom) * 250
                      + math.abs(distance - desired) * 8
                      + alignmentPenalty(preferred, dx, dy)
          if not bestScore or score < bestScore then
            best, bestScore = { x = x, y = y, yaw = yaw, boom = boom,
                                distance = distance }, score
          end
        end
      end
    end
  end
  return best
end

-- The ordinary warp audit deliberately finds one generic safe view. Route 4's
-- two outdoor Mt. Moon portals need a narrower release regression: a direct
-- front elevation and the opposite three-quarter elevations which expose the
-- authored depth on both mouths. Keep that exceptional evidence opt-in and
-- data-pinned; nearby lawn cells must not silently replace a changed portal.
local ROUTE4_PORTAL_VIEWS = {
  [2] = {
    x = 18, y = 5, target = "MT_MOON_1F", destWarp = 1,
    views = {
      { name = "front", x = 18, y = 6, yaw = math.pi,
        facing = "up", direction = "N", captureKind = "portal-front" },
      { name = "three-quarter", x = 14, y = 6,
        yaw = math.atan2(4, -1), facing = "right", direction = "E",
        captureKind = "portal-three-quarter" },
    },
  },
  [3] = {
    x = 24, y = 5, target = "MT_MOON_B1F", destWarp = 8,
    views = {
      { name = "front", x = 24, y = 6, yaw = math.pi,
        facing = "up", direction = "N", captureKind = "portal-front" },
      { name = "three-quarter", x = 28, y = 6,
        yaw = math.atan2(-4, -1), facing = "left", direction = "W",
        captureKind = "portal-three-quarter" },
    },
  },
}

local function route4PortalModeConfig(value, mapIds, modes, cameraConfig)
  local enabled = strictFlag(value, "VASC_PANORAMA_ROUTE4_PORTAL_VIEWS")
  if not enabled then return false end
  local onlyWarps = modes and modes.warps == true
  for mode, selected in pairs(modes or {}) do
    if selected and mode ~= "warps" then onlyWarps = false end
  end
  if not (mapIds and #mapIds == 1 and mapIds[1] == "ROUTE_4"
          and onlyWarps and cameraConfig
          and (cameraConfig.mode == "1st" or cameraConfig.mode == "3rd")
          and cameraConfig.allowCollapsed ~= true) then
    error("VASC_PANORAMA_FAIL phase=config reason="
          .. "route4-portal-views-scope", 0)
  end
  return true
end

local function route4PortalViewPlans(map, warpIndex, mapRoot)
  local spec = ROUTE4_PORTAL_VIEWS[warpIndex]
  local def = map and map.def
  if not (spec and map.id == "ROUTE_4" and def and def.id == "ROUTE_4"
          and def.tileset == "OVERWORLD" and def.width == 45
          and def.height == 9 and map.widthCells == 90
          and map.heightCells == 18) then
    return nil, "route4-map-contract"
  end
  local warp = def.warps and def.warps[warpIndex]
  if not (warp and warp.x == spec.x and warp.y == spec.y
          and warp.destMap == spec.target and warp.destWarp == spec.destWarp) then
    return nil, "route4-warp-contract"
  end
  local placed = map.warpAtCell and map:warpAtCell(spec.x, spec.y)
  if not (placed and placed.index == warpIndex
          and placed.def == warp) then
    return nil, "route4-live-warp-contract"
  end

  local occupied = occupiedCells(map)
  for _, sign in ipairs(def.signs or {}) do
    if sign.x ~= nil and sign.y ~= nil then
      occupied[sign.y * map.widthCells + sign.x] = true
    end
  end
  local root = mapRoot or "ROUTE_4"
  local plans = {}
  for _, fixed in ipairs(spec.views) do
    if not walkable(map, fixed.x, fixed.y, occupied) then
      return nil, "route4-" .. fixed.name .. "-view-contract"
    end
    local expectedYaw = math.atan2(spec.x - fixed.x, spec.y - fixed.y)
    if math.abs(wrapPi(expectedYaw - fixed.yaw)) > 1e-9 then
      return nil, "route4-" .. fixed.name .. "-yaw-contract"
    end
    plans[#plans + 1] = {
      name = fixed.name,
      poi = ("warp-%d-%s"):format(warpIndex, fixed.name),
      target = spec.target,
      targetX = spec.x, targetY = spec.y,
      captureKind = fixed.captureKind,
      expectedDirection = fixed.direction,
      path = ("%s/warps/%03d-%s-%d-%d-%s.png")
        :format(root, warpIndex, spec.target, spec.x, spec.y, fixed.name),
      view = {
        x = fixed.x, y = fixed.y, yaw = fixed.yaw,
        facing = fixed.facing, surfing = false,
      },
    }
  end
  return plans
end

local ROUTE8_SAFFRON_FOCUS_EDGES = {
  ROUTE_8 = {
    direction = "west", target = "SAFFRON_CITY", entryContext = false,
  },
  SAFFRON_CITY = {
    direction = "east", target = "ROUTE_8", entryContext = true,
  },
}

local function route8SaffronFocusConfig(value, mapIds, modes, cameraConfig)
  local enabled = strictFlag(value, "VASC_PANORAMA_ROUTE8_SAFFRON_FOCUS")
  if not enabled then return false end
  local onlyConnections = modes and modes.connections == true
  for mode, selected in pairs(modes or {}) do
    if selected and mode ~= "connections" then onlyConnections = false end
  end
  if not (mapIds and #mapIds == 2 and mapIds[1] == "ROUTE_8"
          and mapIds[2] == "SAFFRON_CITY" and onlyConnections
          and cameraConfig
          and (cameraConfig.mode == "1st" or cameraConfig.mode == "3rd")
          and cameraConfig.allowCollapsed ~= true) then
    error("VASC_PANORAMA_FAIL phase=config reason="
          .. "route8-saffron-focus-scope", 0)
  end
  return true
end

local function route8SaffronFocusEdge(mapId, direction, spec)
  local expected = ROUTE8_SAFFRON_FOCUS_EDGES[mapId]
  if not (expected and direction == expected.direction and spec
          and spec.map == expected.target) then
    return nil
  end
  return {
    map = mapId, direction = direction, target = expected.target,
    entryContext = expected.entryContext,
  }
end

-- Building elevation names are relative to the facade, so their camera
-- bearings must be cardinal and their observer cells must stay on the named
-- side. Merely giving the wrong side a score penalty is not evidence: on a
-- cramped route it used to label a west-looking oblique shot as "front".
local BUILDING_SIDE = {
  north = { dx = 0, dy = -1, bearing = CARDINAL.S },
  east = { dx = 1, dy = 0, bearing = CARDINAL.W },
  south = { dx = 0, dy = 1, bearing = CARDINAL.N },
  west = { dx = -1, dy = 0, bearing = CARDINAL.E },
}

local BUILDING_REAR = {
  north = "south", east = "west", south = "north", west = "east",
}

-- "Left" is the left edge seen while standing in front of the facade and
-- looking inward. This makes the labels remain meaningful for a portal on a
-- non-south edge instead of silently reverting to world west/east.
local BUILDING_LEFT = {
  north = "east", east = "south", south = "west", west = "north",
}

local BUILDING_RIGHT = {
  north = "west", east = "north", south = "east", west = "south",
}

local function buildingBounds(stamp)
  local tx, ty = tonumber(stamp and stamp.tx), tonumber(stamp and stamp.ty)
  local bw, bh = tonumber(stamp and stamp.bw), tonumber(stamp and stamp.bh)
  if not (tx and ty and bw and bh and bw > 0 and bh > 0) then return nil end
  local left, right = tx / 2, (tx + bw - 1) / 2
  local top, bottom = ty / 2, (ty + bh - 1) / 2
  return {
    tx = tx, ty = ty, bw = bw, bh = bh,
    left = left, right = right, top = top, bottom = bottom,
    centreX = (left + right) / 2,
    centreY = (top + bottom) / 2,
  }
end

local function sideTarget(bounds, side)
  if side == "north" then return bounds.centreX, bounds.top end
  if side == "south" then return bounds.centreX, bounds.bottom end
  if side == "west" then return bounds.left, bounds.centreY end
  if side == "east" then return bounds.right, bounds.centreY end
  return nil
end

local function outsideBuildingSide(bounds, side, x, y)
  if side == "north" then return y < bounds.top end
  if side == "south" then return y > bounds.bottom end
  if side == "west" then return x < bounds.left end
  if side == "east" then return x > bounds.right end
  return false
end

local function sideDistance(bounds, side, x, y)
  if side == "north" then return bounds.top - y end
  if side == "south" then return y - bounds.bottom end
  if side == "west" then return bounds.left - x end
  if side == "east" then return x - bounds.right end
  return math.huge
end

local function sideAlignment(side, x, y, targetX, targetY)
  if side == "north" or side == "south" then
    return math.abs(x - targetX)
  end
  return math.abs(y - targetY)
end

-- Door-ground samples sit half a cell inside some Gen-I building claims. A
-- unique nearest edge within that half-cell is still an authored portal
-- normal; a corner tie or a deeper sample is not safe to guess from.
local function buildingPortal(stamp, bounds)
  local side, sx, sy, count
  sx, sy, count = 0, 0, 0
  for at = 1, #(stamp.doorGroundSamples or {}) - 1, 2 do
    local dx = tonumber(stamp.doorGroundSamples[at])
    local dy = tonumber(stamp.doorGroundSamples[at + 1])
    if not (dx and dy) then return nil end
    local x, y = dx / 2, (dy - 1) / 2
    local distances = {
      north = math.abs(y - bounds.top),
      east = math.abs(x - bounds.right),
      south = math.abs(y - bounds.bottom),
      west = math.abs(x - bounds.left),
    }
    local nearest, nearestDistance, ties
    for name, distance in pairs(distances) do
      if nearestDistance == nil or distance < nearestDistance - 1e-6 then
        nearest, nearestDistance, ties = name, distance, 1
      elseif math.abs(distance - nearestDistance) <= 1e-6 then
        ties = ties + 1
      end
    end
    if ties ~= 1 or nearestDistance > 0.500001 then return nil end
    if side and side ~= nearest then return nil end
    side, sx, sy, count = nearest, sx + x, sy + y, count + 1
  end
  if not side or count == 0 then return nil end
  return side, sx / count, sy / count, count
end

-- A valid 3RD screenshot needs at least one complete walkable cell behind
-- the observer. From the cell centre that leaves roughly 24px before the
-- first possible boundary; ThirdPerson's 5px pad still leaves 19px, safely
-- above SHOW_AT=14. An observer in the edge cell has only about 8px and was
-- the cause of the Route 8/11 voxel=0 minute-long readiness timeouts.
local function strictBuildingViewCell(map, targetX, targetY, side, desired,
                                      bounds, poseValidator)
  local descriptor = BUILDING_SIDE[side]
  if not (descriptor and bounds) then return nil end
  local occupied = occupiedCells(map)
  desired = desired or 4
  local best, bestScore
  for y = 0, map.heightCells - 1 do
    for x = 0, map.widthCells - 1 do
      if walkable(map, x, y, occupied)
         and outsideBuildingSide(bounds, side, x, y) then
        local alignment = sideAlignment(side, x, y, targetX, targetY)
        local distance = sideDistance(bounds, side, x, y)
        if alignment <= 0.500001 and distance >= 1.5
           and distance <= math.max(12, desired + 5) then
          local clearSight = true
          for step = 1, math.ceil(distance) do
            local sx = x - descriptor.dx * step
            local sy = y - descriptor.dy * step
            if not outsideBuildingSide(bounds, side, sx, sy) then break end
            if not walkable(map, sx, sy, occupied) then
              clearSight = false
              break
            end
          end
          if clearSight then
            local candidate = {
              x = x, y = y, yaw = descriptor.bearing.yaw,
              facing = descriptor.bearing.facing,
              boom = 1, distance = distance, side = side,
            }
            -- In the live driver, poseValidator invokes ThirdPerson.reach
            -- with the exact pitch, ground height and streamed-neighbour
            -- union. Pure helper tests use the conservative same-map proof:
            -- one clear cell behind the observer guarantees SHOW_AT.
            local poseReady
            if poseValidator then
              local ok, valid = pcall(poseValidator, candidate)
              poseReady = ok and valid == true
            else
              poseReady = walkable(map, x + descriptor.dx,
                                   y + descriptor.dy, nil)
            end
            local score = math.abs(distance - desired) * 8 + alignment * 2
            if poseReady and (not bestScore or score < bestScore) then
              best = candidate
              bestScore = score
            end
          end
        end
      end
    end
  end
  return best
end

local function buildingViewPlans(map, stamp, index, mapRoot, poseValidator)
  local bounds = buildingBounds(stamp)
  if not bounds then return {} end

  local portalSide, portalX, portalY = buildingPortal(stamp, bounds)
  -- Doorless stamps retain the authored Gen-I south facade for elevation
  -- coverage, but it is not a "true front" and can never satisfy warp XREF.
  local frontSide = portalSide or "south"
  local fallbackX, fallbackY = sideTarget(bounds, frontSide)
  local frontX, frontY = portalX or fallbackX, portalY or fallbackY

  local desired = math.max(4, math.max(bounds.bw, bounds.bh) / 4 + 2)
  local specs = {
    { name = "front", side = frontSide, x = frontX, y = frontY,
      trueFront = portalSide ~= nil },
    { name = "rear", side = BUILDING_REAR[frontSide] },
    { name = "left", side = BUILDING_LEFT[frontSide] },
    { name = "right", side = BUILDING_RIGHT[frontSide] },
  }
  local out = {}
  for _, spec in ipairs(specs) do
    if spec.x == nil then spec.x, spec.y = sideTarget(bounds, spec.side) end
    local bearing = BUILDING_SIDE[spec.side].bearing
    local path = ("%s/buildings/%03d-tx%d-ty%d-%s.png")
      :format(mapRoot, index, bounds.tx, bounds.ty, spec.name)
    out[#out + 1] = {
      name = spec.name, poi = "building-" .. index .. "-" .. spec.name,
      side = spec.side, targetX = spec.x, targetY = spec.y,
      expectedDirection = bearing.name, trueFront = spec.trueFront == true,
      path = path,
      view = strictBuildingViewCell(map, spec.x, spec.y, spec.side, desired,
                                    bounds, poseValidator),
    }
  end
  return out
end

local function reusableBuildingFront(building)
  local front = building and building.results and building.results.front
  if front and front.status == "captured" and front._trueFront == true then
    return front
  end
  return nil
end

local function connectionTarget(map, direction, spec, data)
  local targetDef = data.maps[spec.map]
  if not targetDef then return nil end
  local horizontal = direction == "north" or direction == "south"
  local sourceSpan = horizontal and map.widthCells or map.heightCells
  local targetSpan = horizontal and targetDef.width * 2 or targetDef.height * 2
  local shift = (spec.offset or 0) * 2
  local lo = math.max(0, shift)
  local hi = math.min(sourceSpan - 1, shift + targetSpan - 1)
  if lo > hi then return nil end
  local along = math.floor((lo + hi) / 2)
  if direction == "north" then return along, 0, "south", CARDINAL.N end
  if direction == "south" then
    return along, map.heightCells - 1, "north", CARDINAL.S
  end
  if direction == "west" then return 0, along, "east", CARDINAL.W end
  return map.widthCells - 1, along, "west", CARDINAL.E
end

local OPPOSITE_CONNECTION = {
  north = "south", east = "west", south = "north", west = "east",
}

local CONNECTION_BEARING = {
  north = { side = "south", bearing = CARDINAL.N },
  east = { side = "west", bearing = CARDINAL.E },
  south = { side = "north", bearing = CARDINAL.S },
  west = { side = "east", bearing = CARDINAL.W },
}

local function mapId(map)
  return map and (map.id or (map.def and map.def.id))
end

local function connectionOverlap(map, targetMap, direction, spec)
  local horizontal = direction == "north" or direction == "south"
  local sourceSpan = horizontal and map.widthCells or map.heightCells
  local targetSpan = horizontal and targetMap.widthCells or targetMap.heightCells
  if not (sourceSpan and targetSpan) then return nil end
  local shift = (tonumber(spec and spec.offset) or 0) * 2
  local lo = math.max(0, shift)
  local hi = math.min(sourceSpan - 1, shift + targetSpan - 1)
  if lo > hi then return nil end
  return lo, hi, shift
end

-- Convert one cell along the source overlap into the exact pair of edge cells
-- used by OverworldController.connectionLanding. Connection offsets are ROM
-- blocks, hence the two-cell shift.
local function connectionCellPair(map, targetMap, direction, spec, along)
  local lo, hi, shift = connectionOverlap(map, targetMap, direction, spec)
  if not lo or along < lo or along > hi then return nil end
  local targetAlong = along - shift
  if direction == "north" then
    return along, 0, targetAlong, targetMap.heightCells - 1
  elseif direction == "south" then
    return along, map.heightCells - 1, targetAlong, 0
  elseif direction == "west" then
    return 0, along, targetMap.widthCells - 1, targetAlong
  elseif direction == "east" then
    return map.widthCells - 1, along, 0, targetAlong
  end
  return nil
end

-- A land connection image is evidence only when it is taken on a lane that a
-- player can traverse in both directions. This proves both authored edge
-- cells, the reciprocal connection, and both offset transforms. An inward
-- cell may deliberately be a gate warp (Route 8 x=1 at y=9/10), so treating
-- warp semantics as solid camera geometry would incorrectly discard real
-- lanes. Candidates are ordered along the overlap; the lower median is
-- deterministic for an even number of valid lanes.
local function landConnectionSeam(map, targetMap, direction, spec)
  local descriptor = CONNECTION_BEARING[direction]
  local reverseDirection = OPPOSITE_CONNECTION[direction]
  if not (map and targetMap and descriptor and reverseDirection and spec) then
    return nil, "invalid-connection"
  end
  if spec.map ~= mapId(targetMap) then return nil, "target-map-mismatch" end
  local reverse = targetMap.def and targetMap.def.connections
    and targetMap.def.connections[reverseDirection]
  if not reverse or reverse.map ~= mapId(map) then
    return nil, "no-reciprocal-connection"
  end

  local lo, hi = connectionOverlap(map, targetMap, direction, spec)
  if not lo then return nil, "invalid-connection-overlap" end
  local sourceOccupied, targetOccupied = occupiedCells(map), occupiedCells(targetMap)
  local candidates = {}
  for along = lo, hi do
    local sx, sy, tx, ty = connectionCellPair(
      map, targetMap, direction, spec, along)
    local targetAlong = (direction == "north" or direction == "south")
      and tx or ty
    local backAlong = targetAlong - (tonumber(reverse.offset) or 0) * 2
    if backAlong == along
       and walkable(map, sx, sy, sourceOccupied)
       and walkable(targetMap, tx, ty, targetOccupied)
       then
      candidates[#candidates + 1] = {
        x = sx, y = sy, targetX = tx, targetY = ty,
        yaw = descriptor.bearing.yaw, facing = descriptor.bearing.facing,
        boom = 0, distance = 0, side = descriptor.side, surfing = false,
        seamExact = true, along = along,
      }
    end
  end
  if #candidates == 0 then return nil, "no-bidirectional-land-lane" end
  local view = candidates[math.floor((#candidates + 1) / 2)]
  view.laneCount = #candidates
  return view
end

local function seamExactManifestFields(view)
  if not (view and view.seamExact and view.x ~= nil and view.y ~= nil
          and view.targetX ~= nil and view.targetY ~= nil) then return nil end
  local coords = tostring(view.x) .. "," .. tostring(view.y)
  return {
    coords = coords, view = coords,
    target_coords = tostring(view.targetX) .. "," .. tostring(view.targetY),
    capture_kind = "seam-exact",
  }
end

-- Seam evidence and a useful entry composition answer different questions.
-- Keep the latter on the town side, looking inward along a REAL reciprocal
-- Route -> Town connection.  The four-cell inset is the first useful camera
-- station after a three-cell third-person boom; requiring three clear cells
-- forward also prevents a technically safe pose from staring into the back of
-- a gatehouse.  Search bounds are explicit so malformed data cannot turn a QA
-- run into an unbounded map walk.
local ENTRY_CONTEXT_INSET = 4
local ENTRY_CONTEXT_CLEAR = 3
local ENTRY_CONTEXT_MAX_DEPTH = 12
local ENTRY_CONTEXT_MAX_NODES = 384

local function routeTownConnectionLanes(routeMap, townMap, direction, spec)
  local descriptor = CONNECTION_BEARING[direction]
  local reverseDirection = OPPOSITE_CONNECTION[direction]
  local routeId, townId = mapId(routeMap), mapId(townMap)
  if not (routeMap and townMap and descriptor and reverseDirection and spec)
     then
    return nil, "invalid-connection"
  end
  if not (tostring(routeId or ""):match("^ROUTE_%d+$")
          and townId ~= nil
          and mapCategory(townId, townMap.def or {}) == "town") then
    return nil, "not-route-to-town"
  end
  if spec.map ~= townId then return nil, "target-map-mismatch" end
  local reverse = townMap.def and townMap.def.connections
    and townMap.def.connections[reverseDirection]
  if not reverse or reverse.map ~= routeId then
    return nil, "no-reciprocal-connection"
  end

  local lo, hi = connectionOverlap(routeMap, townMap, direction, spec)
  if not lo then return nil, "invalid-connection-overlap" end
  local routeOccupied, townOccupied = occupiedCells(routeMap), occupiedCells(townMap)
  local lanes, reciprocalPairs = {}, 0
  for along = lo, hi do
    local sx, sy, tx, ty = connectionCellPair(
      routeMap, townMap, direction, spec, along)
    local targetAlong = (direction == "north" or direction == "south")
      and tx or ty
    local rsx, rsy, rtx, rty = connectionCellPair(
      townMap, routeMap, reverseDirection, reverse, targetAlong)
    local reciprocal = rsx == tx and rsy == ty and rtx == sx and rty == sy
    if reciprocal then
      reciprocalPairs = reciprocalPairs + 1
      if walkable(routeMap, sx, sy, routeOccupied)
         and walkable(townMap, tx, ty, townOccupied) then
        lanes[#lanes + 1] = {
          routeX = sx, routeY = sy, entryX = tx, entryY = ty,
          along = along,
        }
      end
    end
  end
  if reciprocalPairs == 0 then return nil, "reciprocal-offset-mismatch" end
  if #lanes == 0 then return nil, "no-bidirectional-land-lane" end
  return lanes, nil, descriptor.bearing, townOccupied
end

local function clearCardinalRun(map, x, y, dx, dy, occupied, count)
  for step = 1, count do
    if not walkable(map, x + dx * step, y + dy * step, occupied) then
      return false
    end
  end
  return true
end

-- Route 8 enters Saffron beside a real solid scenery body, then the authored
-- lane turns north.  A cardinal west context therefore stares into the body
-- even though the connection itself is valid.  The focus audit uses this one
-- canonical QA-only composition instead: stand on the bend and look along the
-- real northbound lane.  It is deliberately fail-closed against both the
-- generated map and the already-rendered $39/top-UV plan; this helper never
-- edits either one.
local ROUTE8_SAFFRON_TURN_CONTEXT = {
  routeWidth = 30, routeHeight = 9,
  townWidth = 20, townHeight = 18,
  observerX = 37, observerY = 17,
  entryX = 39, entryY = 17,
  routeX = 0, routeY = 9,
  clear = 3, material = 0x39, source = 0x23,
  cells = {
    { 35, 15, 0x5b, 0x5b, 0x5b, 0x5b },
    { 36, 15, 0x10, 0x23, 0x10, 0x23 },
    { 37, 15, 0x23, 0x10, 0x23, 0x10 },
    { 38, 15, 0x2c, 0x2c, 0x2c, 0x2c },
    { 36, 16, 0x10, 0x23, 0x10, 0x23 },
    { 37, 16, 0x23, 0x10, 0x23, 0x10 },
    { 38, 16, 0x23, 0x23, 0x39, 0x23 },
    { 39, 16, 0x23, 0x23, 0x23, 0x23 },
    { 36, 17, 0x10, 0x23, 0x10, 0x23 },
    { 37, 17, 0x23, 0x10, 0x23, 0x10 },
    { 38, 17, 0x23, 0x23, 0x23, 0x23 },
    { 39, 17, 0x23, 0x23, 0x39, 0x23 },
    { 36, 18, 0x10, 0x23, 0x10, 0x23 },
    { 37, 18, 0x23, 0x21, 0x23, 0x23 },
    { 38, 18, 0x39, 0x39, 0x39, 0x39 },
    { 39, 18, 0x39, 0x39, 0x39, 0x39 },
  },
  blockers = {
    { 35, 16, 0x12, 0x53, 0x4d, 0x12, 0x5a },
    { 35, 17, 0x17, 0x12, 0x5a, 0x17, 0x5d },
    { 35, 18, 0x4b, 0x0a, 0x1f, 0x4b, 0x1f },
  },
}

local function structureTileKey(tx, ty)
  return (ty + 64) * 4096 + (tx + 64)
end

local function safeMapValue(map, method, ...)
  if type(map and map[method]) ~= "function" then return false, nil end
  return pcall(map[method], map, ...)
end

local function exactConnection(def, side, target, offset)
  local connection = def and def.connections and def.connections[side]
  return connection and connection.map == target and connection.offset == offset
end

local function exactTurnSafeCell(map, x, y, occupied)
  local okBounds, inBounds = safeMapValue(map, "inBounds", x, y)
  local okWalk, isWalkable = safeMapValue(map, "isWalkableCell", x, y)
  local okWater, isWater = safeMapValue(map, "isWaterCell", x, y)
  local okDoor, isDoor = safeMapValue(map, "isDoorTileCell", x, y)
  local okWarpTile, isWarpTile = safeMapValue(map, "isWarpTileCell", x, y)
  local okWarp, warp = safeMapValue(map, "warpAtCell", x, y)
  return okBounds and inBounds == true
    and okWalk and isWalkable == true
    and okWater and isWater == false
    and okDoor and isDoor == false
    and okWarpTile and isWarpTile == false
    and okWarp and warp == nil
    and not occupied[y * map.widthCells + x]
end

local function exactSaffronTurnStructure(map, structure)
  local spec = ROUTE8_SAFFRON_TURN_CONTEXT
  if not (type(structure) == "table"
          and type(structure.tileAt) == "table"
          and type(structure.topTileAt) == "table"
          and type(structure.topUVAt) == "table") then
    return false
  end

  local expectedTop, expectedUV, topCount = {}, {}, 0
  for _, cell in ipairs(spec.cells) do
    local cx, cy, at = cell[1], cell[2], 3
    for dy = 0, 1 do
      for dx = 0, 1 do
        local tx, ty = cx * 2 + dx, cy * 2 + dy
        local okTile, tile = safeMapValue(map, "tileAt", tx, ty)
        if not okTile or tile ~= cell[at] then return false end
        if tile == spec.source then
          local key = structureTileKey(tx, ty)
          expectedTop[key] = spec.material
          topCount = topCount + 1
        end
        at = at + 1
      end
    end
  end
  if topCount ~= 31 then return false end

  -- Two full native 8px columns plus the authored southeast corner pixel are
  -- the existing north-turn phase contract.  Grey joins grey and white joins
  -- white only with this alternating row transform.
  for ty = 30, 37 do
    local transform = ty % 2 == 0 and "cw" or "ccw"
    expectedUV[structureTileKey(73, ty)] = transform
    expectedUV[structureTileKey(74, ty)] = transform
  end
  expectedUV[structureTileKey(75, 37)] = "ccw"

  local actualTopCount = 0
  for key, tile in pairs(structure.topTileAt) do
    actualTopCount = actualTopCount + 1
    if expectedTop[key] ~= tile then return false end
  end
  if actualTopCount ~= 31 then return false end
  for key, tile in pairs(expectedTop) do
    if structure.topTileAt[key] ~= tile
       or structure.tileAt[key] ~= spec.source then return false end
  end

  local actualUVCount = 0
  for key, transform in pairs(structure.topUVAt) do
    actualUVCount = actualUVCount + 1
    if expectedUV[key] ~= transform
       or structure.topTileAt[key] ~= spec.material then return false end
  end
  if actualUVCount ~= 17 then return false end
  for key, transform in pairs(expectedUV) do
    if structure.topUVAt[key] ~= transform then return false end
  end

  for _, cell in ipairs(spec.blockers) do
    local cx, cy, at = cell[1], cell[2], 4
    local okWalk, isWalkable = safeMapValue(map, "isWalkableCell", cx, cy)
    local okCollision, collision = safeMapValue(map, "cellTile", cx, cy)
    if not (okWalk and isWalkable == false
            and okCollision and collision == cell[3]) then return false end
    for dy = 0, 1 do
      for dx = 0, 1 do
        local tx, ty = cx * 2 + dx, cy * 2 + dy
        local okTile, tile = safeMapValue(map, "tileAt", tx, ty)
        local key = structureTileKey(tx, ty)
        if not okTile or tile ~= cell[at]
           or structure.topTileAt[key] ~= nil
           or structure.topUVAt[key] ~= nil then return false end
        at = at + 1
      end
    end
  end
  return true
end

local function route8SaffronTurnContext(routeMap, townMap, direction, spec,
                                         structure)
  local turn = ROUTE8_SAFFRON_TURN_CONTEXT
  local routeDef, townDef = routeMap and routeMap.def, townMap and townMap.def
  if not (mapId(routeMap) == "ROUTE_8" and mapId(townMap) == "SAFFRON_CITY"
          and direction == "west" and spec
          and routeDef and routeDef.id == "ROUTE_8"
          and routeDef.tileset == "OVERWORLD"
          and routeDef.width == turn.routeWidth
          and routeDef.height == turn.routeHeight
          and routeMap.widthCells == turn.routeWidth * 2
          and routeMap.heightCells == turn.routeHeight * 2
          and townDef and townDef.id == "SAFFRON_CITY"
          and townDef.tileset == "OVERWORLD"
          and townDef.width == turn.townWidth
          and townDef.height == turn.townHeight
          and townMap.widthCells == turn.townWidth * 2
          and townMap.heightCells == turn.townHeight * 2
          and exactConnection(routeDef, "west", "SAFFRON_CITY", -4)
          and exactConnection(routeDef, "east", "LAVENDER_TOWN", 0)
          and exactConnection(townDef, "north", "ROUTE_5", 5)
          and exactConnection(townDef, "south", "ROUTE_6", 5)
          and exactConnection(townDef, "west", "ROUTE_7", 4)
          and exactConnection(townDef, "east", "ROUTE_8", 4)) then
    return nil, "route8-saffron-turn-map-drift"
  end

  local lanes, reason, _, occupied = routeTownConnectionLanes(
    routeMap, townMap, direction, spec)
  if not lanes then return nil, reason end
  local lane = lanes[math.floor((#lanes + 1) / 2)]
  if not (lane and #lanes == 3
          and lane.routeX == turn.routeX and lane.routeY == turn.routeY
          and lane.entryX == turn.entryX and lane.entryY == turn.entryY) then
    return nil, "route8-saffron-turn-seam-drift"
  end
  if not exactSaffronTurnStructure(townMap, structure) then
    return nil, "route8-saffron-turn-structure-drift"
  end

  local north = CARDINAL.N
  for offset = -turn.clear, turn.clear do
    local x, y = turn.observerX, turn.observerY + offset
    if not exactTurnSafeCell(townMap, x, y, occupied) then
      return nil, "route8-saffron-turn-unsafe-cell"
    end
  end
  return {
    x = turn.observerX, y = turn.observerY,
    yaw = north.yaw, facing = north.facing, direction = north.name,
    boom = turn.clear, boomClear = turn.clear,
    forwardClear = turn.clear, distance = 2, searchDepth = 2, inward = 2,
    surfing = false, seamExact = false, turnContext = true,
    captureKind = "entry-context",
    routeX = lane.routeX, routeY = lane.routeY,
    entryX = lane.entryX, entryY = lane.entryY,
    laneCount = #lanes,
  }
end

local function landConnectionEntryContext(routeMap, townMap, direction, spec)
  local lanes, reason, bearing, occupied = routeTownConnectionLanes(
    routeMap, townMap, direction, spec)
  if not lanes then return nil, reason end

  -- Match landConnectionSeam's deterministic lower median.  Keeping one
  -- proven lane as the BFS root makes coords/target_coords meaningful instead
  -- of letting a multi-source search silently relabel which crossing it used.
  local lane = lanes[math.floor((#lanes + 1) / 2)]
  local queue = { {
    x = lane.entryX, y = lane.entryY, depth = 0,
  } }
  local head, nodes = 1, 1
  local visited = { [lane.entryY * townMap.widthCells + lane.entryX] = true }
  local steps = {
    { dx = bearing.dx, dy = bearing.dy },
    { dx = -bearing.dy, dy = bearing.dx },
    { dx = bearing.dy, dy = -bearing.dx },
    { dx = -bearing.dx, dy = -bearing.dy },
  }

  while head <= #queue do
    local current = queue[head]
    head = head + 1
    local inward = (current.x - lane.entryX) * bearing.dx
                 + (current.y - lane.entryY) * bearing.dy
    if inward >= ENTRY_CONTEXT_INSET
       and clearCardinalRun(townMap, current.x, current.y,
                            -bearing.dx, -bearing.dy, occupied,
                            ENTRY_CONTEXT_CLEAR)
       and clearCardinalRun(townMap, current.x, current.y,
                            bearing.dx, bearing.dy, occupied,
                            ENTRY_CONTEXT_CLEAR) then
      return {
        x = current.x, y = current.y,
        yaw = bearing.yaw, facing = bearing.facing,
        boom = ENTRY_CONTEXT_CLEAR, boomClear = ENTRY_CONTEXT_CLEAR,
        forwardClear = ENTRY_CONTEXT_CLEAR, distance = current.depth,
        searchDepth = current.depth, inward = inward,
        surfing = false, seamExact = false,
        captureKind = "entry-context",
        routeX = lane.routeX, routeY = lane.routeY,
        entryX = lane.entryX, entryY = lane.entryY,
        laneCount = #lanes,
      }
    end

    if current.depth < ENTRY_CONTEXT_MAX_DEPTH then
      for _, step in ipairs(steps) do
        local x, y = current.x + step.dx, current.y + step.dy
        local key = y * townMap.widthCells + x
        if not visited[key] and walkable(townMap, x, y, occupied) then
          visited[key] = true
          nodes = nodes + 1
          if nodes > ENTRY_CONTEXT_MAX_NODES then
            return nil, "entry-context-search-budget"
          end
          queue[#queue + 1] = { x = x, y = y, depth = current.depth + 1 }
        end
      end
    end
  end
  return nil, "no-safe-entry-context"
end

local function entryContextManifestFields(view)
  if not (view and view.captureKind == "entry-context"
          and view.seamExact ~= true
          and view.x ~= nil and view.y ~= nil
          and view.entryX ~= nil and view.entryY ~= nil
          and view.routeX ~= nil and view.routeY ~= nil
          and (view.x ~= view.entryX or view.y ~= view.entryY)) then
    return nil
  end
  return {
    coords = tostring(view.entryX) .. "," .. tostring(view.entryY),
    view = tostring(view.x) .. "," .. tostring(view.y),
    target_coords = tostring(view.routeX) .. "," .. tostring(view.routeY),
    capture_kind = "entry-context",
  }
end

-- Surf seams retain their dedicated, axis-aligned context shot. Land must use
-- landConnectionSeam above: an oblique POI with a cardinal yaw overwrite is
-- not seam evidence and previously caused misleading images and timeouts.
local function connectionView(map, tx, ty, side, bearing, desired)
  if not (map and bearing and tx ~= nil and ty ~= nil) then return nil end
  local occupied = occupiedCells(map)
  local surfing = waterCell(map, tx, ty, occupied)
  desired = desired or 4
  if not surfing then return nil end

  -- Surfing deliberately tolerates the production boom retracting over
  -- water, but the observer itself and its line to the seam must remain water.
  local best, bestScore
  for distance = 2, math.max(12, desired + 5) do
    local x = tx - bearing.dx * distance
    local y = ty - bearing.dy * distance
    if not onPreferredSide(side, x, y, tx, ty) then break end

    local clear = true
    for step = 0, distance do
      local sx = tx - bearing.dx * step
      local sy = ty - bearing.dy * step
      if not waterCell(map, sx, sy, occupied) then
        clear = false
        break
      end
    end
    if clear then
      local score = math.abs(distance - desired)
      if not bestScore or score < bestScore then
        best = {
          x = x, y = y, yaw = bearing.yaw, facing = bearing.facing,
          boom = 0, distance = distance, side = side, surfing = true,
        }
        bestScore = score
      end
    end
  end
  return best
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

local function jsonEscape(value)
  return tostring(value):gsub("\\", "\\\\"):gsub('"', '\\"')
    :gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
end

local MANIFEST_FIELDS = {
  "map", "map_category", "category", "poi", "target", "coords",
  "view", "target_coords", "capture_kind", "direction", "surfing",
  "path", "status", "phase", "reason",
  "xref", "ready_frames",
  "camera_mode", "camera_level", "camera_preset", "camera_pitch_deg",
  "camera_yaw_deg", "camera_zoom_kind", "camera_zoom",
  "camera_zoom_offset", "camera_view", "render_frame",
  "boom_policy", "boom_length", "boom_collapsed", "camera_stress",
  "settle_frames", "elapsed_ms", "terrain", "aux", "atlas", "horizon",
  "sky", "union", "voxel", "render3d", "mesher_pending", "horizon_pending",
}

local function continueOnFailureEnabled(value)
  -- This mode is intentionally opt-in. A typo must retain the historical
  -- fail-fast behaviour instead of silently weakening a QA run.
  return trim(value) == "1"
end

local function failureDetails(value)
  local text = tostring(value or "unknown-error")
    :gsub("[\t\r\n]+", " "):gsub("%s+", " ")
  text = trim(text)
  if #text > 1000 then text = text:sub(1, 997) .. "..." end
  return text:match("phase=([^%s]+)") or "map", text
end

local function runMapBatch(mapIds, continueOnFailure, processMap, onFailure)
  local completed, failed = 0, {}
  for mapNumber, mapId in ipairs(mapIds) do
    if not continueOnFailure then
      -- Keep the original contract: no protected call, no recovery callback,
      -- and no attempt to visit a later map.
      processMap(mapNumber, mapId)
      completed = completed + 1
    else
      local okMap, mapError = pcall(processMap, mapNumber, mapId)
      if okMap then
        completed = completed + 1
      else
        local phase, reason = failureDetails(mapError)
        local failure = { map = mapId, phase = phase, reason = reason }
        failed[#failed + 1] = failure
        if onFailure then
          onFailure(failure, mapNumber, #mapIds)
        end
      end
    end
  end
  return completed, failed
end

-- A panorama teleport is intentionally direct: unlike a player's warp it has
-- no Transition above it, and PRELOAD is OFF so the audit measures the exact
-- cold scene it is about to capture.  The asynchronous builder must still get
-- ordinary update + draw frames, but presenting its nil/flat fallback makes a
-- human watching the run see the world blink into bird's-eye view between
-- maps.  This QA-owned, NON-OPAQUE state draws the real overworld underneath
-- and asks Renderer:endFrame for the same full-window black cover a warp uses.
-- It never enters the production mod/runtime.
local REVEAL_FIELDS = {
  "terrain", "aux", "atlas", "horizon", "sky", "union", "voxel", "render3d",
}

local function readyForReveal(status)
  if type(status) ~= "table" then return false end
  for _, field in ipairs(REVEAL_FIELDS) do
    if status[field] ~= true then return false end
  end
  return true
end

local function newReadyCover(game, overworld, graphics)
  local cover = {
    -- StateStack draws from the highest opaque state.  Remaining transparent
    -- is the contract that lets the exact 3D frame render and be observed
    -- before this cover is removed.
    isOpaque = false,
    panoramaReadyCover = true,
    active = false,
  }

  local function stack()
    return game and game.stack
  end

  function cover:topAllowed()
    local states = stack()
    local top = states and states:top()
    return top == overworld or (self.active and top == self)
  end

  function cover:show()
    local states = stack()
    if not states then return nil, "missing-stack" end
    if self.active and states:top() == self then return true end
    if states:top() ~= overworld then return nil, "overworld-covered" end
    states:push(self)
    if states:top() ~= self then return nil, "cover-not-pushed" end
    self.active = true
    return true
  end

  -- Synchronize after the audit's recovery loop has popped every state above
  -- the overworld.  Do not search or mutate an unrelated stack here.
  function cover:syncAfterUncover()
    local states = stack()
    if states and states:top() == overworld then self.active = false end
    return not self.active
  end

  function cover:hide(status)
    if not readyForReveal(status) then return nil, "scene-not-exact-3d" end
    local states = stack()
    if not (states and self.active and states:top() == self) then
      return nil, "cover-not-top"
    end
    if states:pop() ~= self or states:top() ~= overworld then
      return nil, "overworld-not-restored"
    end
    self.active = false
    return true
  end

  function cover:allowsCapture()
    local states = stack()
    return not self.active and states and states:top() == overworld
  end

  function cover:draw()
    local renderer = game and game.renderer
    if renderer then
      -- Renderer:endFrame applies this after either the pipeline override or
      -- the engine's flat fallback, at window rather than 160x144 UI size.
      renderer.worldFadeAlpha = 1
      if renderer.worldActive then return end
    end

    -- Defensive non-world fallback.  In the real audit the non-opaque cover
    -- always has the overworld below it and therefore takes worldFadeAlpha.
    local g = graphics or (love and love.graphics)
    if not (g and g.setColor and g.rectangle) then return end
    g.setColor(0, 0, 0, 1)
    g.rectangle("fill", 0, 0, 160, 144)
    g.setColor(1, 1, 1, 1)
  end

  return cover
end

local function captureScreenshotWhenUncovered(cover, capture, path)
  if not (cover and cover:allowsCapture()) then
    return nil, "qa-cover-active"
  end
  local ok, err = pcall(capture, path)
  if not ok then return nil, "capture:" .. tostring(err) end
  return true
end

local function encodeJSON(rows)
  local out = { "[" }
  for i, row in ipairs(rows) do
    out[#out + 1] = i == 1 and "  {" or "  ,{"
    local fields = {}
    for _, key in ipairs(MANIFEST_FIELDS) do
      local value = row[key]
      if value ~= nil then
        local encoded
        if type(value) == "number" then encoded = tostring(value)
        elseif type(value) == "boolean" then encoded = value and "true" or "false"
        else encoded = '"' .. jsonEscape(value) .. '"' end
        fields[#fields + 1] = '"' .. key .. '":' .. encoded
      end
    end
    out[#out + 1] = table.concat(fields, ",") .. "}"
  end
  out[#out + 1] = "]\n"
  return table.concat(out, "\n")
end

local function tsvValue(value)
  return tostring(value == nil and "" or value):gsub("[\t\r\n]", " ")
end

local function encodeTSV(rows)
  local out = { table.concat(MANIFEST_FIELDS, "\t") }
  for _, row in ipairs(rows) do
    local values = {}
    for _, key in ipairs(MANIFEST_FIELDS) do
      values[#values + 1] = tsvValue(row[key])
    end
    out[#out + 1] = table.concat(values, "\t")
  end
  return table.concat(out, "\n") .. "\n"
end

local function run(game)
  local continueLabel = require("src.core.Strings")("CONTINUE")
  local bootstrap = newQAContinueBootstrap(game, os.getenv, {
    continueLabel = continueLabel,
  })
  while not bootstrap:step() do
    coroutine.yield()
  end

  local function envInt(name, fallback, minimum)
    local raw = os.getenv(name)
    if raw == nil or raw == "" then return fallback end
    local value = tonumber(raw)
    if not value or value ~= math.floor(value) or value < (minimum or 0) then
      error("VASC_PANORAMA_FAIL phase=config reason=invalid-number key="
            .. name .. " value=" .. tostring(raw), 0)
    end
    return value
  end

  local explicit = trim(os.getenv("VASC_PANORAMA_MAPS"))
  local preset = trim(os.getenv("VASC_PANORAMA_PRESET"))
  if explicit ~= "" and preset ~= "" then
    error("VASC_PANORAMA_FAIL phase=config reason=maps-and-preset", 0)
  end
  local mapIds = explicit ~= "" and csv(explicit, true)
                 or mapsForPreset(game.data, preset ~= "" and preset or "routes")
  if #mapIds == 0 then
    error("VASC_PANORAMA_FAIL phase=config reason=no-maps", 0)
  end
  for _, mapId in ipairs(mapIds) do
    if not (game.data.maps and game.data.maps[mapId]) then
      error("VASC_PANORAMA_FAIL phase=validate map=" .. tostring(mapId)
            .. " reason=unknown-map", 0)
    end
  end

  local cameraConfig = panoramaCameraConfig({
    camera = os.getenv("VASC_PANORAMA_CAMERA"),
    preset = os.getenv("VASC_PANORAMA_CAMERA_PRESET"),
    pitch = os.getenv("VASC_PANORAMA_PITCH_DEG"),
    zoom = os.getenv("VASC_PANORAMA_ZOOM"),
    orbitZoom = os.getenv("VASC_PANORAMA_ORBIT_ZOOM"),
    allowCollapsed = os.getenv("VASC_PANORAMA_ALLOW_COLLAPSED_BOOM"),
  })
  local defaultModes = cameraConfig.mode == "orbit" and "panorama"
                       or "panorama,connections,warps,buildings"
  local modeList = csv(os.getenv("VASC_PANORAMA_MODES") or defaultModes, false)
  local modes = {}
  for _, mode in ipairs(modeList) do
    mode = string.lower(mode)
    if mode ~= "panorama" and mode ~= "connections" and mode ~= "warps"
       and mode ~= "buildings" then
      error("VASC_PANORAMA_FAIL phase=config reason=unknown-mode mode="
            .. tostring(mode), 0)
    end
    modes[mode] = true
  end
  if next(modes) == nil then
    error("VASC_PANORAMA_FAIL phase=config reason=no-modes", 0)
  end
  if cameraConfig.mode == "orbit"
     and (modes.connections or modes.warps or modes.buildings) then
    error("VASC_PANORAMA_FAIL phase=config reason=orbit-panorama-only", 0)
  end
  local route4PortalViews = route4PortalModeConfig(
    os.getenv("VASC_PANORAMA_ROUTE4_PORTAL_VIEWS"),
    mapIds, modes, cameraConfig)
  local route8SaffronFocus = route8SaffronFocusConfig(
    os.getenv("VASC_PANORAMA_ROUTE8_SAFFRON_FOCUS"),
    mapIds, modes, cameraConfig)
  local edgeAudit = strictFlag(os.getenv("VASC_PANORAMA_EDGE_AUDIT"),
                               "VASC_PANORAMA_EDGE_AUDIT")
  if edgeAudit and not modes.panorama then
    error("VASC_PANORAMA_FAIL phase=config reason=edge-audit-needs-panorama", 0)
  end

  -- Voxel3D's normal orbit is intentionally north-facing: its only degree of
  -- freedom is the selected pitch rung. Default to its one truthful bearing,
  -- and reject an explicitly relabelled E/S/W request instead of producing
  -- four identical pictures with false direction names.
  local defaultDirections = cameraConfig.mode == "orbit" and "N" or "N,E,S,W"
  local directionList = csv(os.getenv("VASC_PANORAMA_DIRECTIONS")
                            or defaultDirections, true)
  local directions = {}
  for _, direction in ipairs(directionList) do
    local alias = ({ UP = "N", RIGHT = "E", DOWN = "S", LEFT = "W" })[direction]
    direction = alias or direction
    if not CARDINAL[direction] then
      error("VASC_PANORAMA_FAIL phase=config reason=unknown-direction direction="
            .. tostring(direction), 0)
    end
    directions[#directions + 1] = CARDINAL[direction]
  end
  if modes.panorama and #directions == 0 then
    error("VASC_PANORAMA_FAIL phase=config reason=no-directions", 0)
  end
  if cameraConfig.mode == "orbit" then
    for _, direction in ipairs(directions) do
      if not cameraDirectionAllowed(cameraConfig, direction.name) then
        error("VASC_PANORAMA_FAIL phase=config reason=orbit-fixed-yaw", 0)
      end
    end
  end
  local outPrefix = safeRelativePath(os.getenv("VASC_PANORAMA_OUT")
                                     or "qa/panorama-audit", "out")
  local runId = safeSegment(os.getenv("VASC_PANORAMA_RUN")
                            or os.date("!%Y%m%dT%H%M%SZ"), "run")
  local runRoot = outPrefix .. "/" .. runId
  local timeoutFrames = envInt("VASC_PANORAMA_TIMEOUT_FRAMES", 1800, 1)
  local settleFrames = envInt("VASC_PANORAMA_SETTLE_FRAMES", 45, 0)
  local captureTimeout = envInt("VASC_PANORAMA_CAPTURE_TIMEOUT_FRAMES", 300, 1)
  local fullUnion = os.getenv("VASC_PANORAMA_FULL_UNION") ~= "0"
  local continueOnFailure = continueOnFailureEnabled(
    os.getenv("VASC_PANORAMA_CONTINUE_ON_FAILURE"))
  local pitch = cameraConfig.pitch
  local zoom, cameraLevel = cameraConfig.boomZoom, cameraConfig.level
  local scriptedSpeed = tonumber(os.getenv("POKEPORT_SPEED") or "1")
  -- main.lua may resume a scripted coroutine several times before the next
  -- love.draw when fast-forward is enabled. Screenshot evidence is defined in
  -- presented frames, so accepting that mode would let settle/capture loops
  -- outrun the framebuffer they are meant to prove.
  if not scriptedSpeed or scriptedSpeed <= 0 or scriptedSpeed > 1 then
    error("VASC_PANORAMA_FAIL phase=config reason=fast-forward-not-supported", 0)
  end
  local fs = assert(love and love.filesystem,
                    "VASC_PANORAMA_FAIL phase=boot reason=no-filesystem")
  local graphics = assert(love and love.graphics,
                          "VASC_PANORAMA_FAIL phase=boot reason=no-graphics")
  if type(graphics.captureScreenshot) ~= "function" then
    error("VASC_PANORAMA_FAIL phase=boot reason=no-captureScreenshot", 0)
  end
  assert(fs.createDirectory(runRoot))

  local id = "VOXEL_ASCENDANT"
  local exports = game.mods and game.mods.exports and game.mods.exports[id]
  local lib = exports and exports.lib
  local Scene = lib and lib.require and lib.require("VoxelScene")
  local Voxel = lib and lib.require and lib.require("VoxelState")
  local Voxel3D = lib and lib.require and lib.require("Voxel3D")
  if not (Scene and Voxel and Voxel3D) then
    error("VASC_PANORAMA_FAIL phase=boot reason=missing-vasc-public-api", 0)
  end

  -- QA-only introspection: readiness and profiled stamps are deliberately not
  -- part of VASC's hardened public compatibility facade. Observe the exact
  -- tables already captured by VoxelScene instead of widening production API.
  local Mesher = privateUpvalue(Scene.prefetch, "ChunkMesher")
  local Atlas = privateUpvalue(Scene.prefetch, "TerrainAtlas")
  local Horizon = privateUpvalue(Scene.prefetch, "HorizonWall")
  local FirstPerson = privateUpvalue(Scene.render, "FirstPerson")
  local ThirdPerson = FirstPerson and privateUpvalue(FirstPerson.update,
                                                      "ThirdPerson")
  local Structures = Mesher and privateUpvalue(Mesher.build, "Structures")
  local Sky = privateUpvalue(Scene.render, "Sky")
  if not (Mesher and Mesher.ready and Mesher.auxReady and Mesher.pending
          and Atlas and Atlas.prepared
          and Horizon and Horizon.meshes and Horizon.buildStatus
          and Scene.groundAt
          and FirstPerson and FirstPerson.update and FirstPerson.EYE_HEIGHT
          and ThirdPerson and ThirdPerson.extension
          and ThirdPerson.reach and ThirdPerson.reachFor
          and ThirdPerson.PIVOT_LIFT and ThirdPerson.SHOW_AT
          and Structures and Structures.forMap
          and Sky and Sky.cloudAssetStatus) then
    error("VASC_PANORAMA_FAIL phase=boot reason=private-readiness-unobservable", 0)
  end
  if not Voxel3D.available() then
    error("VASC_PANORAMA_FAIL phase=boot reason=voxel3d-unavailable", 0)
  end

  local values = {
    preload = false, scenery = "full", shadows = false, weather = "clear",
    sky = "full", skyEvents = "off", daytime = "day", clouds = "on",
  }
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions[id] = values
  game.mods.modOptions = game.mods.modOptions or {}
  game.mods.modOptions[id] = values

  -- Must happen before the first QA setMap: KASC creates the banner from the
  -- synchronous map.entered event.  Its draw hook also observes this value and
  -- clears any banner inherited from the identity's initial map on next draw.
  disableLocationBanners(game)

  local Runtime = require("src.mods.Runtime")
  local wanted = {
    preload = "OFF", scenery = "FULL", shadows = "OFF", weather = "CLEAR",
    sky = "FULL", skyEvents = "OFF", daytime = "DAY", clouds = "ON",
  }
  local rows = Runtime.call("ui.options.rows", function(_, base) return base end,
                            game, {})
  local applied = {}
  for _, row in ipairs(rows or {}) do
    local key = row.id and row.id:match("^" .. id .. ":(.+)$")
    if key and wanted[key] then
      for _ = 1, 12 do
        if row.value(game) == wanted[key] then break end
        row.step(game, 1)
      end
      if row.value(game) ~= wanted[key] then
        error("VASC_PANORAMA_FAIL phase=options key=" .. tostring(key), 0)
      end
      applied[key] = true
    end
  end
  for key in pairs(wanted) do
    if not applied[key] then
      error("VASC_PANORAMA_FAIL phase=options reason=missing-row key="
            .. tostring(key), 0)
    end
  end

  local Pipelines = require("src.render.Pipelines")
  local Zoom = require("src.render.Zoom")
  if cameraConfig.mode == "orbit" then
    local fitScale = game.renderer:fitScale()
    local minOffset = select(1, Zoom.offsetRange(fitScale))
    local wantedOffset = cameraConfig.orbitZoom == "maxout" and minOffset or 0
    wantedOffset = Zoom.clampOffset(wantedOffset, fitScale)
    -- QA memory only. Game:zoomStep would call writeOptions(), so the audit
    -- sets the same live Zoom field directly and mirrors it into the already
    -- disposable process's option table. No save writer or production hook is
    -- touched.
    Zoom.offset = wantedOffset
    game.save.options.zoom = wantedOffset
    cameraConfig.surveyOffset = wantedOffset
    cameraConfig.surveyScale = Zoom.scale(fitScale)
    cameraConfig.fitScale = fitScale
    cameraConfig.viewW, cameraConfig.viewH = game.renderer:worldViewSize()
  end
  Pipelines.setLevel("tiltshift", 0)
  local selected = Pipelines.setLevel("voxel", cameraLevel)
  Pipelines.syncOptions(game.save.options)
  if selected ~= cameraLevel then
    error("VASC_PANORAMA_FAIL phase=camera reason=camera-level-rejected", 0)
  end

  ThirdPerson.zoom, ThirdPerson.zoomGoal = zoom, zoom
  local pinYaw, pinFacing, pinX, pinY, pinSurfing = math.pi, "up", nil, nil, false
  local rawFirstPersonUpdate = FirstPerson.update
  FirstPerson.update = function(...)
    local result = rawFirstPersonUpdate(...)
    FirstPerson.yaw, FirstPerson.pitch = pinYaw, pitch
    return result
  end

  local frame = 0
  local last3D = { map = nil, frame = -1 }
  local rawRender = Scene.render
  Scene.render = function(state, ...)
    local renderArgs = { ... }
    local output = rawRender(state, ...)
    if output then
      local look = Voxel3D.lookFlat or { 0, 0, -1 }
      local actualYaw = math.atan2(look[1] or 0, look[3] or -1)
      local fitScale = game.renderer:fitScale()
      last3D = { map = state and state.map and state.map.id, frame = frame,
                 yaw = actualYaw,
                 pitch = cameraConfig.mode == "orbit"
                   and Voxel.angle or FirstPerson.pitch,
                 x = state and state.player and state.player.cellX,
                 y = state and state.player and state.player.cellY,
                 surfing = state and state.player
                   and state.player.surfing == true or false,
                 level = Voxel.level, angle = Voxel.angle,
                 cameraKind = Voxel3D.camera and "placed" or "orbit",
                 blend = FirstPerson.blend,
                 zoomOffset = Zoom.offset,
                 zoomScale = Zoom.scale(fitScale),
                 viewW = renderArgs[3], viewH = renderArgs[4],
                 boomZoom = ThirdPerson.zoom,
                 extension = ThirdPerson.extension(), boom = ThirdPerson.len,
                 showAt = ThirdPerson.SHOW_AT or 14 }
    end
    return output
  end

  local ow = game.overworld
  local readyCover = newReadyCover(game, ow, graphics)
  ow.rollEncounter = function() return nil end
  -- A screenshot tour is a static observer, not a second playthrough.  In
  -- particular, an undefeated trainer can acquire the teleported player
  -- without either of them moving, and Cycling Road applies its downhill
  -- input when no direction is held.  Both would cover the world or move the
  -- camera while a long batch is encoding.  These instance-only replacements
  -- disappear with the QA process and do not touch the engine or the save.
  ow.checkTrainerSight = function() return false end
  ow.handleInput = function() return nil end
  ow.checkForcedMovement = function() return false end
  ow.checkSeafoamCurrent = function() return false end

  -- setMap runs map-enter hooks synchronously before it returns.  Preserve
  -- every state change those hooks make (door blocks, object toggles, guards,
  -- etc.), but park deferred cutscenes and ambient script movement: the QA
  -- teleport is not a real entrance and must not walk the observer away from
  -- its selected view.  Keeping the queues/runners intact, instead of erasing
  -- them, also makes this an observational pause rather than a second version
  -- of map initialization.
  ow.drainPendingScripts = function() return nil end
  ow.updateParallel = function() return nil end
  ow.updateScriptMoves = function() return nil end

  local function quiesceWorld()
    ow.engaging, ow.emote, ow.transitioning = nil, nil, false
  end

  local function uncoverOverworld()
    local removed = 0
    while game.stack:top() and game.stack:top() ~= ow and removed < 32 do
      game.stack:pop()
      removed = removed + 1
    end
    readyCover:syncAfterUncover()
    return game.stack:top() == ow, removed
  end

  local function freeze()
    quiesceWorld()
    if game.input and game.input.reset then game.input:reset() end
    if cameraConfig.mode == "orbit" then
      Zoom.offset = cameraConfig.surveyOffset
      game.save.options.zoom = cameraConfig.surveyOffset
    end
    local p = ow.player
    if p then
      p.cellX, p.cellY = pinX or p.cellX, pinY or p.cellY
      p.moving, p.targetX, p.targetY = false, nil, nil
      p.px, p.py = p.cellX * 16, p.cellY * 16
      p.inputLocked = false
      p.facing = pinFacing or p.facing
      p.surfing = pinSurfing
    end
    for _, npc in ipairs(ow.npcs or {}) do npc.frozen = true end
    for _, ghost in ipairs(ow.ghosts or {}) do
      if ghost.npc then ghost.npc.frozen = true end
    end
    FirstPerson.yaw, FirstPerson.pitch = pinYaw, pitch
    -- Every presented QA frame gets the same cloud world-address. Sky.update
    -- advances it once after this reset, leaving a stable 1/60-second pose
    -- rather than making the fourth bearing minutes newer than the first.
    if Sky then Sky.clock = 0 end
  end

  local function tick()
    freeze()
    frame = frame + 1
    coroutine.yield()
  end

  local manifest = {}
  local function writeManifest()
    local okTSV, errTSV = fs.write(runRoot .. "/manifest.tsv", encodeTSV(manifest))
    local okJSON, errJSON = fs.write(runRoot .. "/manifest.json", encodeJSON(manifest))
    if not okTSV or not okJSON then
      error("VASC_PANORAMA_FAIL phase=manifest reason="
            .. tostring(errTSV or errJSON), 0)
    end
  end

  local function addManifest(row)
    manifest[#manifest + 1] = row
    writeManifest()
  end

  local currentMapStart, currentPoseStart = 0, 0
  local lastReady
  local function sampleReadiness()
    local ok, terrain, _, _, _, plan = pcall(Scene.prefetch, ow)
    if not ok then
      return nil, "prefetch:" .. tostring(terrain)
    end
    local map = ow.map
    local preferBody = Horizon.preferBody and Horizon.preferBody(map) or false
    local terrainReady = terrain ~= nil
      and (Mesher.ready(map, preferBody) and true or false)
    local auxReady = Mesher.auxReady(map) == true
    local atlasReady = Atlas.prepared(map) == true
    local cloudState = Sky.cloudAssetStatus()
    local skyReady = cloudState == "ready"
    local unionReady = true
    if fullUnion then
      local planCount = plan and plan.state and #(plan.state.neighbors or {}) or -1
      unionReady = planCount == #(ow.neighbors or {})
      for _, nb in ipairs(ow.neighbors or {}) do
        if not (Mesher.ready(nb.map, true) and Mesher.auxReady(nb.map)
                and Atlas.prepared(nb.map)) then
          unionReady = false
          break
        end
      end
    end
    local horizonState = fullUnion and ow or (plan and plan.state)
    local _, horizonReady = Horizon.meshes(horizonState or { map = map,
                                                              neighbors = {} })
    local hstatus = Horizon.buildStatus()
    local cameraReady = auditCameraPoseReady(cameraConfig, {
      ready = Voxel.ready, level = Voxel.level,
      angle = Voxel.angle, goal = Voxel.goal,
      blend = FirstPerson.blend,
      cameraKind = Voxel3D.camera and "placed" or "orbit",
      extension = ThirdPerson.extension(), boom = ThirdPerson.len,
      showAt = ThirdPerson.SHOW_AT or 14, surfing = pinSurfing,
      boomZoom = ThirdPerson.zoom,
      zoomOffset = Zoom.offset,
      zoomScale = Zoom.scale(game.renderer:fitScale()),
    })
      and ow.player and ow.player.cellX == pinX and ow.player.cellY == pinY
      and (ow.player.surfing == true) == pinSurfing
    local renderReady = renderedCameraPoseReady(cameraConfig, last3D, {
      map = map.id, frame = math.max(currentMapStart, currentPoseStart),
      yaw = pinYaw, x = pinX, y = pinY, surfing = pinSurfing,
      viewW = cameraConfig.viewW, viewH = cameraConfig.viewH,
    })
    local status = {
      terrain = terrainReady, aux = auxReady, atlas = atlasReady,
      horizon = horizonReady == true, sky = skyReady, union = unionReady,
      voxel = cameraReady, render3d = renderReady,
      mesher_pending = Mesher.pending(),
      horizon_pending = hstatus and hstatus.pending or -1,
      rendered = last3D,
    }
    status.ready = readyForReveal(status) and readyCover:topAllowed()
      and ow.map.id == map.id
    return status
  end

  local function statusFields(row, status)
    status = status or {}
    for key, value in pairs(cameraManifestFields(cameraConfig, status)) do
      row[key] = value
    end
    row.terrain = status.terrain and 1 or 0
    row.aux = status.aux and 1 or 0
    row.atlas = status.atlas and 1 or 0
    row.horizon = status.horizon and 1 or 0
    row.sky = status.sky and 1 or 0
    row.union = status.union and 1 or 0
    row.voxel = status.voxel and 1 or 0
    row.render3d = status.render3d and 1 or 0
    row.mesher_pending = status.mesher_pending or -1
    row.horizon_pending = status.horizon_pending or -1
    return row
  end

  local function skipRecord(row)
    addManifest(statusFields(row, lastReady))
    print(("VASC_PANORAMA SKIP map=%s category=%s poi=%s target=%s "
           .. "coords=%s direction=%s status=%s")
      :format(tostring(row.map), tostring(row.category), tostring(row.poi),
              tostring(row.target or ""), tostring(row.coords or ""),
              tostring(row.direction or ""), tostring(row.status)))
  end

  local function waitForPose(mapId)
    local started = love.timer.getTime()
    local stable, waited = 0, 0
    while stable < math.max(1, settleFrames) do
      if not readyCover:topAllowed() then
        return nil, "overworld-covered", waited,
               math.floor((love.timer.getTime() - started) * 1000 + 0.5)
      end
      if not ow.map or ow.map.id ~= mapId then
        return nil, "map-changed", waited,
               math.floor((love.timer.getTime() - started) * 1000 + 0.5)
      end
      local status, reason = sampleReadiness()
      lastReady = status or lastReady
      if not status then
        return nil, reason, waited,
               math.floor((love.timer.getTime() - started) * 1000 + 0.5)
      end
      if status.ready then stable = stable + 1 else stable = 0 end
      waited = waited + 1
      if waited > timeoutFrames then
        return nil, "readiness-timeout", waited,
               math.floor((love.timer.getTime() - started) * 1000 + 0.5)
      end
      tick()
    end
    return lastReady, nil, waited,
           math.floor((love.timer.getTime() - started) * 1000 + 0.5)
  end

  local function place(x, y, yaw, facing, surfing)
    local p = assert(ow.player)
    pinX, pinY, pinSurfing = x, y, surfing == true
    p.cellX, p.cellY = x, y
    p.px, p.py = x * 16, y * 16
    p.targetX, p.targetY, p.moving = nil, nil, false
    pinYaw, pinFacing = yaw, facing
    p.facing = facing
    p.surfing = pinSurfing
    FirstPerson.yaw, FirstPerson.pitch = yaw, pitch
    ThirdPerson.len = math.min(ThirdPerson.len or 0,
                               ThirdPerson.reachFor())
    if ow.camera and ow.camera.follow then
      ow.camera:follow(p.px, p.py, game.renderer:worldViewSize())
    end
    -- The pose is changed from love.update, after the previous love.draw.
    -- Demand at least the next presented frame before calling it ready.
    currentPoseStart = frame + 1
  end

  local function facingForYaw(yaw)
    local s, c = math.sin(yaw), math.cos(yaw)
    if math.abs(s) > math.abs(c) then return s > 0 and "right" or "left" end
    return c > 0 and "down" or "up"
  end

  local function bearingForYaw(yaw)
    local facing = facingForYaw(yaw)
    return ({ up = "N", right = "E", down = "S", left = "W" })[facing]
  end

  local function screenshot(relativePath, expectedMap, expectedYaw)
    local parent = relativePath:match("^(.*)/[^/]+$")
    if parent and not fs.createDirectory(parent) then
      return nil, "mkdir"
    end
    if fs.getInfo(relativePath) and not fs.remove(relativePath) then
      return nil, "stale-output-not-removable"
    end
    local ok, err = captureScreenshotWhenUncovered(
      readyCover, graphics.captureScreenshot, relativePath)
    if not ok then
      fs.remove(relativePath)
      return nil, err
    end
    local captureFrame = frame + 1
    local pngMagic = "\137PNG\r\n\26\n"
    local pngEnd = "IEND\174B\096\130"
    for _ = 1, captureTimeout do
      tick()
      if game.stack:top() ~= ow or not ow.map or ow.map.id ~= expectedMap then
        fs.remove(relativePath)
        return nil, "map-changed-during-capture"
      end
      local info = fs.getInfo(relativePath, "file")
      if info and (info.size or 0) > 0 then
        local bytes = fs.read(relativePath)
        local completePNG = type(bytes) == "string" and #bytes > 20
          and bytes:sub(1, #pngMagic) == pngMagic
          and bytes:sub(-#pngEnd) == pngEnd
        local exact3D = renderedCameraPoseReady(cameraConfig, last3D, {
          map = expectedMap, frame = captureFrame, yaw = expectedYaw,
          x = pinX, y = pinY, surfing = pinSurfing,
          viewW = cameraConfig.viewW, viewH = cameraConfig.viewH,
        })
        if completePNG and not exact3D then
          fs.remove(relativePath)
          return nil, "captured-frame-not-exact-3d-pose"
        end
        if completePNG then return true end
      end
    end
    fs.remove(relativePath)
    return nil, "capture-timeout"
  end

  local function captureRecord(base, view, relativePath)
    local mapId = ow.map.id
    relativePath = cameraOutputPath(relativePath, cameraConfig)
    -- A repeated run id must never leave an older image looking like evidence
    -- for a pose that failed before captureScreenshot was reached.
    if fs.getInfo(relativePath) and not fs.remove(relativePath) then
      base.path, base.status = relativePath, "stale-output-not-removable"
      addManifest(statusFields(base, lastReady))
      error("VASC_PANORAMA_FAIL phase=capture map=" .. mapId
            .. " path=" .. relativePath
            .. " reason=stale-output-not-removable", 0)
    end
    place(view.x, view.y, view.yaw, view.facing or facingForYaw(view.yaw),
          view.surfing)
    local ready, reason, waited, elapsed = waitForPose(mapId)
    base.view = tostring(view.x) .. "," .. tostring(view.y)
    base.direction = base.direction or bearingForYaw(view.yaw)
    base.surfing = view.surfing and 1 or 0
    base.path = relativePath
    base.ready_frames, base.settle_frames = waited, settleFrames
    base.elapsed_ms = elapsed
    statusFields(base, ready or lastReady)
    if not ready then
      base.status = reason or "not-ready"
      addManifest(base)
      print(("VASC_PANORAMA FAIL map=%s category=%s poi=%s path=%s status=%s")
        :format(mapId, tostring(base.category), tostring(base.poi), relativePath,
                tostring(base.status)))
      error("VASC_PANORAMA_FAIL phase=pose map=" .. mapId
            .. " category=" .. tostring(base.category)
            .. " reason=" .. tostring(base.status), 0)
    end
    local ok, captureReason = screenshot(relativePath, mapId, view.yaw)
    base.status = ok and "captured" or captureReason
    addManifest(base)
    print(("VASC_PANORAMA CAPTURE map=%s category=%s poi=%s direction=%s "
           .. "surfing=%d path=%s status=%s terrain=%d aux=%d atlas=%d horizon=%d "
           .. "sky=%d union=%d voxel=%d render3d=%d ready_frames=%d elapsed_ms=%d")
      :format(mapId, tostring(base.category), tostring(base.poi),
              tostring(base.direction), base.surfing, relativePath,
              tostring(base.status),
              base.terrain, base.aux, base.atlas, base.horizon, base.sky, base.union,
              base.voxel, base.render3d, waited, elapsed))
    if not ok then
      error("VASC_PANORAMA_FAIL phase=capture map=" .. mapId
            .. " path=" .. relativePath .. " reason="
            .. tostring(captureReason), 0)
    end
    return base
  end

  local MapLoader = require("src.world.MapLoader")
  local directionOrder = { north = 1, east = 2, south = 3, west = 4 }
  local connectionNames = { "north", "east", "south", "west" }

  local route8SaffronCaptured = 0
  local function processMap(mapNumber, mapId)
    local okLoad, probe = pcall(MapLoader.load, game.data, mapId)
    if not (okLoad and probe and probe.id == mapId) then
      error("VASC_PANORAMA_FAIL phase=load map=" .. mapId
            .. " reason=" .. tostring(probe), 0)
    end
    local representative = representativeCell(probe)
    if not representative then
      error("VASC_PANORAMA_FAIL phase=position map=" .. mapId
            .. " reason=no-safe-walkable-cell", 0)
    end
    local okSet, setError = pcall(ow.setMap, ow, mapId,
                                  representative.x, representative.y, "up",
                                  { via = "qa-panorama" })
    if not okSet or not ow.map or ow.map.id ~= mapId then
      error("VASC_PANORAMA_FAIL phase=setMap map=" .. mapId
            .. " reason=" .. tostring(setError), 0)
    end
    quiesceWorld()
    local uncovered, removed = uncoverOverworld()
    if not uncovered then
      error("VASC_PANORAMA_FAIL phase=setMap map=" .. mapId
            .. " reason=overworld-not-restorable", 0)
    end
    if removed > 0 then
      print(("VASC_PANORAMA QUIESCE map=%s discarded_screens=%d")
        :format(mapId, removed))
    end
    ow.rollEncounter = function() return nil end
    currentMapStart = frame
    pinYaw, pinFacing = math.pi, "up"
    place(representative.x, representative.y, pinYaw, pinFacing, false)
    local covered, coverReason = readyCover:show()
    if not covered then
      error("VASC_PANORAMA_FAIL phase=ready map=" .. mapId
            .. " reason=" .. tostring(coverReason), 0)
    end
    local initial, initialReason, initialFrames, initialElapsed = waitForPose(mapId)
    if not initial then
      -- Fail-fast runs do not enter the batch recovery callback. Restore the
      -- real overworld here too, so no QA-owned state survives either path.
      uncoverOverworld()
      error("VASC_PANORAMA_FAIL phase=ready map=" .. mapId
            .. " reason=" .. tostring(initialReason), 0)
    end
    local revealed, revealReason = readyCover:hide(initial)
    if not revealed then
      uncoverOverworld()
      error("VASC_PANORAMA_FAIL phase=ready map=" .. mapId
            .. " reason=" .. tostring(revealReason), 0)
    end
    -- Do not let the capture planner change cell/yaw in this same update. The
    -- first actually exposed frame must be the exact 3D pose that authorized
    -- the reveal, not merely a later screenshot that eventually settles.
    tick()
    local exposed, exposedReason = sampleReadiness()
    lastReady = exposed or lastReady
    if not (exposed and exposed.ready) then
      uncoverOverworld()
      error("VASC_PANORAMA_FAIL phase=ready map=" .. mapId
            .. " reason=first-uncovered-frame-not-exact-3d"
            .. (exposedReason and (":" .. tostring(exposedReason)) or ""), 0)
    end

    local map = ow.map
    local category = mapCategory(mapId, map.def)
    local mapRoot = runRoot .. "/" .. safeSegment(mapId, "map")
    local anchors = panoramaAnchors(map, edgeAudit)
    if #anchors == 0 then
      error("VASC_PANORAMA_FAIL phase=position map=" .. mapId
            .. " reason=no-panorama-anchor", 0)
    end
    local wantsSurf = modes.panorama and (mapId == "ROUTE_19"
      or mapId == "ROUTE_20" or mapId == "ROUTE_21"
      or mapId == "CINNABAR_ISLAND")
    local surfAnchor, surfReason
    if wantsSurf then
      surfAnchor = representativeSurfCell(map)
      surfReason = "no-safe-surf-anchor"
    end
    if wantsSurf and not surfAnchor then
      error("VASC_PANORAMA_FAIL phase=position map=" .. mapId
            .. " reason=" .. tostring(surfReason), 0)
    end
    addManifest(statusFields({
      map = mapId, map_category = category, category = "map-summary",
      poi = "initial-readiness",
      coords = representative.x .. "," .. representative.y,
      view = representative.x .. "," .. representative.y,
      direction = "N", surfing = 0, path = "", status = "ready",
      ready_frames = initialFrames, settle_frames = settleFrames,
      elapsed_ms = initialElapsed,
    }, initial))
    print(("VASC_PANORAMA MAP map=%s index=%d total=%d category=%s x=%d y=%d "
           .. "clear=%d neighbors=%d anchors=%d surf=%d ready_frames=%d "
           .. "elapsed_ms=%d")
      :format(mapId, mapNumber, #mapIds, category, representative.x,
              representative.y, representative.clear, #(ow.neighbors or {}),
              #anchors, surfAnchor and 1 or 0, initialFrames, initialElapsed))

    local okStructures, structureData = pcall(Structures.forMap, map)
    if not okStructures then
      error("VASC_PANORAMA_FAIL phase=structures map=" .. mapId
            .. " reason=" .. tostring(structureData), 0)
    end
    local function exactThirdPersonPose(view)
      if not (view and ow.map == map) then return false end
      local okGround, ground = pcall(Scene.groundAt, map, view.x, view.y)
      if not okGround or type(ground) ~= "number" then return false end
      local cp = math.cos(pitch)
      local lx = math.sin(view.yaw) * cp
      local ly = -math.sin(pitch)
      local lz = math.cos(view.yaw) * cp
      local pivot = {
        view.x * 16 + 8,
        ground + FirstPerson.EYE_HEIGHT + ThirdPerson.PIVOT_LIFT,
        view.y * 16 + 8,
      }
      local okReach, room = pcall(ThirdPerson.reach, ow, pivot,
                                  -lx, -ly, -lz, ThirdPerson.reachFor())
      return okReach and type(room) == "number"
        and (cameraConfig.allowCollapsed or room >= ThirdPerson.SHOW_AT)
    end
    local buildings = {}
    for index, stamp in ipairs(structureData.buildingStamps or {}) do
      buildings[#buildings + 1] = {
        index = index, stamp = stamp,
        plans = buildingViewPlans(map, stamp, index, mapRoot,
                                  exactThirdPersonPose),
      }
      if #buildings[#buildings].plans ~= 4 then
        error("VASC_PANORAMA_FAIL phase=structures map=" .. mapId
              .. " reason=invalid-building-stamp index=" .. index, 0)
      end
    end

    local warps, warpAt = {}, {}
    for index, warp in ipairs(map.def.warps or {}) do
      local record = { index = index, warp = warp, x = warp.x, y = warp.y,
                       target = warp.destMap or "UNKNOWN", kind = "warp" }
      warps[#warps + 1] = record
      warpAt[tostring(warp.x) .. ":" .. tostring(warp.y)] = true
    end
    local doorIndex = 0
    for y = 0, map.heightCells - 1 do
      for x = 0, map.widthCells - 1 do
        if map:isDoorTileCell(x, y)
           and not warpAt[tostring(x) .. ":" .. tostring(y)] then
          doorIndex = doorIndex + 1
          warps[#warps + 1] = {
            index = #warps + 1, doorIndex = doorIndex, x = x, y = y,
            target = "DOOR", kind = "door",
          }
        end
      end
    end

    for _, warp in ipairs(warps) do
      local wtx, wty = warp.x * 2, warp.y * 2 + 1
      for _, building in ipairs(buildings) do
        local stamp, exact = building.stamp, false
        for at = 1, #(stamp.doorGroundSamples or {}) - 1, 2 do
          if stamp.doorGroundSamples[at] == wtx
             and stamp.doorGroundSamples[at + 1] == wty then
            exact = true
            break
          end
        end
        local inside = wtx >= stamp.tx and wtx < stamp.tx + stamp.bw
          and wty >= stamp.ty and wty < stamp.ty + stamp.bh
        if exact or (inside and map:isDoorTileCell(warp.x, warp.y)) then
          warp.building = building
          break
        end
      end
    end

    if modes.panorama then
      for _, anchor in ipairs(anchors) do
        for _, direction in ipairs(directions) do
          if not anchor.direction or anchor.direction == direction.name then
            local relative = mapRoot .. "/panorama/" .. anchor.name .. "/"
                             .. direction.name .. ".png"
            captureRecord({
              map = mapId, map_category = category, category = "panorama",
              poi = anchor.name, coords = anchor.x .. "," .. anchor.y,
              direction = direction.name,
            }, { x = anchor.x, y = anchor.y, yaw = direction.yaw,
                 facing = direction.facing, surfing = false }, relative)
          end
        end
      end
      if surfAnchor then
        for _, direction in ipairs(directions) do
          local relative = mapRoot .. "/panorama/surf01/"
                           .. direction.name .. ".png"
          captureRecord({
            map = mapId, map_category = category, category = "panorama",
            poi = "surf01", target = "surf",
            coords = surfAnchor.x .. "," .. surfAnchor.y,
            direction = direction.name,
          }, { x = surfAnchor.x, y = surfAnchor.y, yaw = direction.yaw,
               facing = direction.facing, surfing = true }, relative)
        end
      end
    end

    if modes.connections then
      local connectionIndex = {}
      local focusEdges, focusCaptures = 0, 0
      for _, name in ipairs(connectionNames) do
        local spec = map.def.connections and map.def.connections[name]
        local focusEdge = route8SaffronFocus
          and route8SaffronFocusEdge(mapId, name, spec) or nil
        if spec and (not route8SaffronFocus or focusEdge) then
          if focusEdge then focusEdges = focusEdges + 1 end
          connectionIndex[name] = (connectionIndex[name] or 0) + 1
          local tx, ty, side, bearing = connectionTarget(map, name, spec, game.data)
          local poiName = name .. "-" .. tostring(spec.map) .. "-"
                          .. tostring(connectionIndex[name])
          if not tx then
            if route8SaffronFocus then
              error("VASC_PANORAMA_FAIL phase=route8-saffron-focus map="
                    .. mapId .. " reason=invalid-connection-overlap", 0)
            end
            local row = {
              map = mapId, map_category = category, category = "connections",
              poi = poiName, target = spec.map, coords = "", direction = name,
              path = "", status = "invalid-connection-overlap",
            }
            skipRecord(row)
          else
            local view, noViewReason, landTargetMap
            local seamFields
            local sourceOccupied = occupiedCells(map)
            if waterCell(map, tx, ty, sourceOccupied) then
              -- Water remains a contextual surf view on the source side; its
              -- differing coords/view fields intentionally distinguish it
              -- from a land seam-exact record.
              view = connectionView(map, tx, ty, side, bearing, 4)
              noViewReason = "no-safe-surf-anchor"
            else
              local okTarget, targetMap = pcall(MapLoader.load, game.data,
                                                spec.map)
              if okTarget and targetMap and targetMap.id == spec.map then
                landTargetMap = targetMap
                view, noViewReason = landConnectionSeam(
                  map, targetMap, name, spec)
                seamFields = seamExactManifestFields(view)
              else
                noViewReason = "target-map-unavailable"
              end
            end
            if route8SaffronFocus and not seamFields then
              error("VASC_PANORAMA_FAIL phase=route8-saffron-focus map="
                    .. mapId .. " reason="
                    .. tostring(noViewReason or "not-seam-exact"), 0)
            end
            if not view then
              if route8SaffronFocus then
                error("VASC_PANORAMA_FAIL phase=route8-saffron-focus map="
                      .. mapId .. " reason="
                      .. tostring(noViewReason or "no-safe-view"), 0)
              end
              local row = {
                map = mapId, map_category = category, category = "connections",
                poi = poiName, target = spec.map, coords = tx .. "," .. ty,
                direction = bearing.name, path = "", status = "no-safe-view",
                reason = noViewReason,
              }
              skipRecord(row)
            else
              view.yaw, view.facing = bearing.yaw, bearing.facing
              local exactSuffix = seamFields and "-seam-exact" or ""
              local relative = ("%s/connections/%s-%s-%d%s.png")
                :format(mapRoot, name, safeSegment(spec.map, "connection-target"),
                        connectionIndex[name], exactSuffix)
              local capturePoi = poiName .. exactSuffix
              captureRecord({
                map = mapId, map_category = category, category = "connections",
                poi = capturePoi, target = spec.map,
                coords = seamFields and seamFields.coords or tx .. "," .. ty,
                view = seamFields and seamFields.view or nil,
                target_coords = seamFields and seamFields.target_coords or nil,
                capture_kind = seamFields and seamFields.capture_kind or nil,
                direction = bearing.name,
              }, view, relative)
              if route8SaffronFocus then
                focusCaptures = focusCaptures + 1
                route8SaffronCaptured = route8SaffronCaptured + 1
              end
            end

            -- Capture one separate inward-looking context on the town side
            -- of a proven Route -> Town connection.  It is intentionally
            -- planned while that town is the current map: no hidden map swap
            -- can pollute the seam-exact record or its rendered-map proof.
            if landTargetMap and category == "town"
               and tostring(spec.map or ""):match("^ROUTE_%d+$") then
              local routeDirection = OPPOSITE_CONNECTION[name]
              local routeSpec = routeDirection and landTargetMap.def
                and landTargetMap.def.connections
                and landTargetMap.def.connections[routeDirection]
              -- The focused Route 8 proof replaces only Saffron's generic
              -- west-looking context.  Its turn helper keeps the exact seam
              -- record untouched, then looks north along the real bend while
              -- validating the live structure plan used for this map.
              local contextView, contextReason
              if route8SaffronFocus then
                contextView, contextReason = route8SaffronTurnContext(
                  landTargetMap, map, routeDirection, routeSpec,
                  structureData)
              else
                contextView, contextReason = landConnectionEntryContext(
                  landTargetMap, map, routeDirection, routeSpec)
              end
              local contextFields = entryContextManifestFields(contextView)
              local contextBearing = contextView and contextView.direction
                and CARDINAL[contextView.direction]
                or (routeDirection and CONNECTION_BEARING[routeDirection]
                    and CONNECTION_BEARING[routeDirection].bearing)
              local contextPoi = poiName .. "-entry-context"
              local contextRelative =
                ("%s/connections/%s-%s-%d-entry-context.png")
                  :format(mapRoot, name,
                          safeSegment(spec.map, "connection-target"),
                          connectionIndex[name])
              if not contextView or not contextFields or not contextBearing then
                if route8SaffronFocus then
                  error("VASC_PANORAMA_FAIL phase=route8-saffron-focus map="
                        .. mapId .. " reason="
                        .. tostring(contextReason
                                    or "invalid-entry-context"), 0)
                end
                skipRecord({
                  map = mapId, map_category = category,
                  category = "connections", poi = contextPoi,
                  target = spec.map, coords = tx .. "," .. ty,
                  capture_kind = "entry-context",
                  direction = contextBearing and contextBearing.name or name,
                  path = "", status = "no-safe-view",
                  reason = contextReason or "invalid-entry-context",
                })
              else
                captureRecord({
                  map = mapId, map_category = category,
                  category = "connections", poi = contextPoi,
                  target = spec.map, coords = contextFields.coords,
                  view = contextFields.view,
                  target_coords = contextFields.target_coords,
                  capture_kind = contextFields.capture_kind,
                  direction = contextBearing.name,
                }, contextView, contextRelative)
                if route8SaffronFocus then
                  focusCaptures = focusCaptures + 1
                  route8SaffronCaptured = route8SaffronCaptured + 1
                end
              end
            end
          end
        end
      end
      if route8SaffronFocus then
        local expectedCaptures = mapId == "SAFFRON_CITY" and 2 or 1
        if focusEdges ~= 1 or focusCaptures ~= expectedCaptures then
          error("VASC_PANORAMA_FAIL phase=route8-saffron-focus map="
                .. mapId .. " reason=unexpected-focus-count edges="
                .. tostring(focusEdges) .. " captures="
                .. tostring(focusCaptures), 0)
        end
      end
    end

    if modes.buildings then
      for _, building in ipairs(buildings) do
        building.results = {}
        for _, plan in ipairs(building.plans) do
          local result
          if not plan.view then
            result = {
              map = mapId, map_category = category, category = "buildings",
              poi = plan.poi,
              coords = ("%.2f,%.2f"):format(plan.targetX, plan.targetY),
              direction = plan.expectedDirection, surfing = 0,
              path = plan.path, status = "no-safe-view",
            }
            skipRecord(result)
          else
            result = captureRecord({
              map = mapId, map_category = category, category = "buildings",
              poi = plan.poi,
              coords = ("%.2f,%.2f"):format(plan.targetX, plan.targetY),
              direction = plan.expectedDirection,
            }, plan.view, plan.path)
          end
          -- Internal QA provenance only (not part of the manifest schema).
          -- A captured default facade on a doorless/ambiguous stamp must not
          -- be reused as evidence for a gameplay portal.
          result._trueFront = plan.trueFront == true
          building.results[plan.name] = result
        end
      end
    end

    if modes.warps then
      if route4PortalViews then
        for _, warpIndex in ipairs({ 2, 3 }) do
          local plans, reason = route4PortalViewPlans(map, warpIndex, mapRoot)
          if not plans or #plans ~= 2 then
            error("VASC_PANORAMA_FAIL phase=portal-views map=" .. mapId
                  .. " warp=" .. tostring(warpIndex)
                  .. " reason=" .. tostring(reason or "invalid-plan-count"), 0)
          end
          for _, plan in ipairs(plans) do
            if cameraConfig.mode == "3rd"
               and not exactThirdPersonPose(plan.view) then
              error("VASC_PANORAMA_FAIL phase=portal-views map=" .. mapId
                    .. " warp=" .. tostring(warpIndex)
                    .. " view=" .. tostring(plan.name)
                    .. " reason=no-strict-third-person-boom", 0)
            end
            captureRecord({
              map = mapId, map_category = category, category = "warps",
              poi = plan.poi, target = plan.target,
              coords = plan.targetX .. "," .. plan.targetY,
              target_coords = plan.targetX .. "," .. plan.targetY,
              capture_kind = plan.captureKind,
              direction = plan.expectedDirection,
            }, plan.view, plan.path)
          end
        end
      else
        for _, warp in ipairs(warps) do
          local poiName = warp.kind .. "-" .. tostring(warp.index)
          local buildingFront = reusableBuildingFront(warp.building)
          if buildingFront then
            local row = {
              map = mapId, map_category = category, category = "warps",
              poi = poiName, target = warp.target,
              coords = warp.x .. "," .. warp.y,
              direction = buildingFront.direction, surfing = 0,
              path = buildingFront.path, status = "xref",
              xref = "building:" .. warp.building.index .. ":front",
            }
            addManifest(statusFields(row, lastReady))
            print(("VASC_PANORAMA XREF map=%s category=warps poi=%s "
                   .. "xref=building:%d:front path=%s")
              :format(mapId, poiName, warp.building.index, row.path))
          else
            local view = viewCell(map, warp.x, warp.y, "south", 4)
            local targetName = safeSegment(
              tostring(warp.target):gsub("[^%w_.-]", "_"), "warp-target")
            local relative = ("%s/warps/%03d-%s-%d-%d.png")
              :format(mapRoot, warp.index, targetName, warp.x, warp.y)
            if not view then
              local row = {
                map = mapId, map_category = category, category = "warps",
                poi = poiName, target = warp.target,
                coords = warp.x .. "," .. warp.y,
                path = relative, status = "no-safe-view",
              }
              skipRecord(row)
            else
              captureRecord({
                map = mapId, map_category = category, category = "warps",
                poi = poiName, target = warp.target,
                coords = warp.x .. "," .. warp.y,
              }, view, relative)
            end
          end
        end
      end
    end
  end

  local completedMaps, failedMaps = runMapBatch(
    mapIds, continueOnFailure, processMap,
    function(failure, mapNumber, mapTotal)
      local mapId, phase, reason = failure.map, failure.phase, failure.reason
      local def = game.data.maps and game.data.maps[mapId] or {}

      -- Restore only QA-owned observer state. setMap on the next iteration
      -- remains responsible for constructing the next real map and running
      -- its synchronous enter hooks.
      quiesceWorld()
      local recoveredOverworld = uncoverOverworld()
      if game.input and game.input.reset then game.input:reset() end
      pinX, pinY, pinSurfing = nil, nil, false
      pinYaw, pinFacing = math.pi, "up"
      lastReady = nil
      last3D = { map = nil, frame = -1 }
      currentMapStart, currentPoseStart = frame + 1, frame + 1

      addManifest(statusFields({
        map = mapId, map_category = mapCategory(mapId, def),
        category = "map-summary", poi = "map-failure", path = "",
        status = "failed", phase = phase, reason = reason,
      }, nil))
      print(("VASC_PANORAMA MAP_FAIL map=%s index=%d total=%d phase=%s "
             .. "reason=%s continue=1")
        :format(mapId, mapNumber, mapTotal, phase,
                reason:gsub(" ", "%%20")))
      if not recoveredOverworld then
        -- Continuing with an unknown screen stack would make every later
        -- screenshot ambiguous. Preserve the failure row, then stop even in
        -- opt-in mode rather than manufacturing questionable evidence.
        error("VASC_PANORAMA_FAIL phase=recovery map=" .. mapId
              .. " reason=overworld-not-restorable-after-map-failure", 0)
      end
    end)

  writeManifest()
  local captured, xrefs, summaries, skipped, failedRecords = 0, 0, 0, 0, 0
  for _, row in ipairs(manifest) do
    if row.status == "captured" then captured = captured + 1
    elseif row.status == "xref" then xrefs = xrefs + 1
    elseif row.category == "map-summary" and row.status == "ready" then
      summaries = summaries + 1
    elseif row.status == "failed" then failedRecords = failedRecords + 1
    else skipped = skipped + 1 end
  end
  local saveDir = fs.getSaveDirectory and fs.getSaveDirectory() or "unknown"
  if #failedMaps > 0 then
    local names = {}
    for _, failure in ipairs(failedMaps) do names[#names + 1] = failure.map end
    print(("VASC_PANORAMA PARTIAL maps=%d completed=%d failed=%d records=%d "
           .. "captured=%d xrefs=%d summaries=%d skipped=%d failed_records=%d "
           .. "failed_maps=%s run=%s save_dir=%s")
      :format(#mapIds, completedMaps, #failedMaps, #manifest, captured, xrefs,
              summaries, skipped, failedRecords, table.concat(names, ","),
              runRoot, tostring(saveDir):gsub(" ", "%%20")))
    error("VASC_PANORAMA_FAIL phase=partial failed_maps="
          .. table.concat(names, ","), 0)
  end
  if route8SaffronFocus
     and (route8SaffronCaptured ~= 3 or captured ~= 3) then
    error("VASC_PANORAMA_FAIL phase=route8-saffron-focus "
          .. "reason=unexpected-run-capture-count captures="
          .. tostring(route8SaffronCaptured) .. " manifest="
          .. tostring(captured), 0)
  end
  print(("VASC_PANORAMA DONE maps=%d records=%d captured=%d xrefs=%d "
         .. "summaries=%d skipped=%d run=%s save_dir=%s")
    :format(#mapIds, #manifest, captured, xrefs, summaries, skipped, runRoot,
            tostring(saveDir):gsub(" ", "%%20")))
end

-- Headless contract tests opt into the pure helpers without constructing a
-- game or LÖVE context. A normal POKEPORT_DRIVER load receives only `run`.
if rawget(_G, "VASC_PANORAMA_AUDIT_TEST") then
  return {
    csv = csv,
    qaBootStateKind = qaBootStateKind,
    newQAContinueBootstrap = newQAContinueBootstrap,
    safeRelativePath = safeRelativePath,
    safeSegment = safeSegment,
    disableLocationBanners = disableLocationBanners,
    mapsForPreset = mapsForPreset,
    mapCategory = mapCategory,
    representativeCell = representativeCell,
    panoramaAnchors = panoramaAnchors,
    edgeAuditAnchors = edgeAuditAnchors,
    representativeSurfCell = representativeSurfCell,
    thirdPersonPoseReady = thirdPersonPoseReady,
    freeCameraPoseReady = freeCameraPoseReady,
    cameraModeForLevel = cameraModeForLevel,
    panoramaCameraConfig = panoramaCameraConfig,
    cameraOutputPath = cameraOutputPath,
    cameraDirectionAllowed = cameraDirectionAllowed,
    auditCameraPoseReady = auditCameraPoseReady,
    renderedCameraPoseReady = renderedCameraPoseReady,
    cameraManifestFields = cameraManifestFields,
    viewCell = viewCell,
    route4PortalModeConfig = route4PortalModeConfig,
    route4PortalViewPlans = route4PortalViewPlans,
    route8SaffronFocusConfig = route8SaffronFocusConfig,
    route8SaffronFocusEdge = route8SaffronFocusEdge,
    strictBuildingViewCell = strictBuildingViewCell,
    buildingBounds = buildingBounds,
    buildingPortal = buildingPortal,
    buildingViewPlans = buildingViewPlans,
    reusableBuildingFront = reusableBuildingFront,
    alignmentPenalty = alignmentPenalty,
    connectionTarget = connectionTarget,
    connectionCellPair = connectionCellPair,
    landConnectionSeam = landConnectionSeam,
    seamExactManifestFields = seamExactManifestFields,
    routeTownConnectionLanes = routeTownConnectionLanes,
    route8SaffronTurnContext = route8SaffronTurnContext,
    landConnectionEntryContext = landConnectionEntryContext,
    entryContextManifestFields = entryContextManifestFields,
    connectionView = connectionView,
    encodeJSON = encodeJSON,
    encodeTSV = encodeTSV,
    continueOnFailureEnabled = continueOnFailureEnabled,
    failureDetails = failureDetails,
    runMapBatch = runMapBatch,
    readyForReveal = readyForReveal,
    newReadyCover = newReadyCover,
    captureScreenshotWhenUncovered = captureScreenshotWhenUncovered,
  }
end

return run
