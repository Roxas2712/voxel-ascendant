-- Gen-1 move-learning presentation owner.
--
-- The engine deliberately draws non-opaque states bottom-up. MoveLearnMenu
-- did not claim a complete surface, so a wide VASC battle, its Pokemon and
-- HUD remained visible behind the move list and its nested TextBoxes. This
-- Card changes presentation ownership only: the exact engine MoveLearnMenu
-- remains the input, move-rule, callback and stack owner.

local V = ...
local M = {
  apiVersion = 1,
  cardId = "VASC-66-GEN1-MOVE-LEARN-PRESENTATION",
  owner = "voxel-ascendant/gen1-move-learn-presentation/v1",
  schema = "voxel-ascendant/gen1-move-learn-presentation/v1",
}

local PRESENTATION_HANDOFF_KEY = "__vascMoveLearnPresentationHandoffV1"
local LEGACY_HANDOFF_KEY = "__floatingBattleMoveLearnHandoffV1"
local LEGACY_HANDOFF_SCHEMA =
  "voxel-ascendant/gen1-move-learn-owner-handoff/v1"
local LEGACY_OWNER = "voxel-ascendant/gen1-floating-move-learn/v1"

local unpackValues = table.unpack or unpack
local function packed(...)
  return { n=select("#", ...), ... }
end

local function traceback(errorValue)
  if debug and type(debug.traceback) == "function" then
    return debug.traceback(tostring(errorValue), 2)
  end
  return tostring(errorValue)
end

local Diagnostics, MobileMenuPresentation, OverlayPresentation
if type(V) == "table" and type(V.require) == "function" then
  pcall(function() OverlayPresentation = V.require("OrasPartyOverlayPresentation") end)
  pcall(function() Diagnostics = V.require("Diagnostics") end)
  pcall(function()
    MobileMenuPresentation = V.require("MobileMenuPresentation")
  end)
end

local WIDTH, HEIGHT = 512, 288
local C = {
  navy={ 12/255, 37/255, 84/255 },
  navy2={ 5/255, 24/255, 61/255 },
  blue={ 23/255, 75/255, 142/255 },
  orange={ 244/255, 91/255, 12/255 },
  gold={ 1, 194/255, 44/255 },
  cream={ 1, 247/255, 218/255 },
  paper={ 1, 252/255, 236/255 },
  gray={ 132/255, 151/255, 176/255 },
  white={ 1, 1, 1 },
}

local installed = false
local eventUnregister = {}
local decorated = setmetatable({}, { __mode="k" })
local decoratedCount = 0
local lastError
local stableCode
local handoffClass, previousHandoff, hadPreviousHandoff
local solidTextShader

-- This class-level receipt is deliberately narrower than a global flag.  The
-- bundled floating battle HUD can see whether this exact presentation Card is
-- active before it decorates a newly constructed MoveLearnMenu, and can ask
-- whether a concrete instance is really ours before yielding any pixels.
local presentationHandoff = {
  apiVersion=1,
  schema=LEGACY_HANDOFF_SCHEMA,
  owner=M.owner,
  active=function() return installed end,
  owns=function(state)
    return installed
      and type(state) == "table"
      and rawget(state, "__vascMoveLearnPresentationOwner") == M.owner
      and decorated[state] ~= nil
  end,
}

local function diagnostic(event, fields)
  if type(Diagnostics) == "table" and type(Diagnostics.write) == "function" then
    pcall(Diagnostics.write, event, fields)
  end
end

stableCode = function(value, fallback)
  if value == nil then return fallback end
  value = tostring(value):lower():gsub("[^%w%._%-]", "-")
  value = value:gsub("%-+", "-"):gsub("^%-", ""):gsub("%-$", "")
  if value == "" then return fallback end
  return value:sub(1, 80)
end

local function classFor(moduleName)
  local ok, value = pcall(require, moduleName)
  return ok and type(value) == "table" and value or nil
end

local function classInstance(state, class)
  if type(state) ~= "table" or type(class) ~= "table" then return false end
  local mt = getmetatable(state)
  local seen = {}
  while type(mt) == "table" and not seen[mt] do
    if mt == class or rawget(mt, "__index") == class then return true end
    seen[mt] = true
    mt = getmetatable(mt)
  end
  return false
end

function M.isMoveLearnMenu(state)
  return classInstance(state, classFor("src.ui.MoveLearnMenu"))
end

local function legacyHandoff()
  local class = classFor("src.ui.MoveLearnMenu")
  local bridge = class and rawget(class, LEGACY_HANDOFF_KEY) or nil
  if type(bridge) ~= "table"
      or bridge.apiVersion ~= 1
      or bridge.schema ~= LEGACY_HANDOFF_SCHEMA
      or bridge.owner ~= LEGACY_OWNER then
    return nil
  end
  return bridge
end

local function legacyOwns(state)
  local bridge = legacyHandoff()
  if not (bridge and type(bridge.owns) == "function") then return false end
  local ok, owns = pcall(bridge.owns, state)
  return ok and owns == true
end

local function releaseLegacy(state)
  local bridge = legacyHandoff()
  if not (bridge and type(bridge.release) == "function") then
    return not legacyOwns(state)
  end
  local ok, released = pcall(bridge.release, state,
    "vasc-full-surface-owner-enter")
  return ok and released ~= false
end

local function claimLegacy(state, reason)
  local bridge = legacyHandoff()
  if not (bridge and type(bridge.claim) == "function") then return false end
  local ok, claimed = pcall(bridge.claim, state,
    stableCode(reason, "vasc-owner-released"))
  return ok and claimed == true
end

local function stackSource(state)
  local explicit = rawget(state, "__vascMoveLearnSourceReason")
  if explicit ~= nil then return stableCode(explicit, "engine-move-learn") end

  local stack = state.game and state.game.stack
  local states = stack and stack.states
  if type(states) ~= "table" then return "engine-move-learn" end
  local current
  for index = #states, 1, -1 do
    if states[index] == state then current = index break end
  end
  if not current then return "engine-move-learn" end

  local BattleState = classFor("src.battle.BattleState")
  local EvolutionState = classFor("src.ui.EvolutionState")
  for index = current - 1, 1, -1 do
    local underlay = states[index]
    if classInstance(underlay, BattleState) then
      local active = underlay.player and underlay.player.mon
      if active ~= nil and active ~= state.mon then
        return "battle-exp-all-level-up"
      end
      return "battle-active-level-up"
    end
    if classInstance(underlay, EvolutionState) then
      return "post-evolution-level-up"
    end
  end
  -- TM/HM, Rare Candy and post-evolution callers all use the same native
  -- screen constructor and do not publish private inventory or save data.
  -- Keep the log truthful instead of guessing which item opened it.
  return "engine-nonbattle-move-learn"
end

local function diagnosticFields(state, reason, status)
  local mon = type(state) == "table" and state.mon or nil
  return {
    cardId=M.cardId,
    generation="gen1",
    owner=M.owner,
    speciesId=type(mon) == "table" and mon.species or "unknown",
    moveId=type(state) == "table" and state.newMoveId or "unknown",
    source=type(state) == "table"
      and (rawget(state, "__vascMoveLearnSourceCode") or stackSource(state))
      or "engine-move-learn",
    reason=reason,
    status=status,
  }
end

local function setColor(graphics, color, alpha)
  graphics.setColor(color[1], color[2], color[3], alpha or 1)
end

local function rounded(graphics, color, x, y, width, height, radius, alpha)
  setColor(graphics, color, alpha)
  graphics.rectangle("fill", x, y, width, height, radius or 0, radius or 0)
end

local function outline(graphics, color, x, y, width, height, radius, lineWidth)
  setColor(graphics, color)
  if type(graphics.setLineWidth) == "function" then
    graphics.setLineWidth(lineWidth or 1)
  end
  graphics.rectangle("line", x + .5, y + .5, width - 1, height - 1,
    radius or 0, radius or 0)
  if type(graphics.setLineWidth) == "function" then graphics.setLineWidth(1) end
end

local function textShader(graphics, color)
  if type(graphics.newShader) ~= "function"
      or type(graphics.setShader) ~= "function" then return nil end
  if solidTextShader == nil then
    local ok, shader = pcall(graphics.newShader, [[
      uniform vec4 tone;
      vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
        vec4 px = Texel(tex, tc);
        return vec4(tone.rgb, px.a * tone.a * color.a);
      }
    ]])
    solidTextShader = ok and shader and type(shader.send) == "function"
      and shader or false
  end
  if solidTextShader then
    local ok = pcall(solidTextShader.send, solidTextShader, "tone", {
      color[1], color[2], color[3], color[4] or 1,
    })
    if ok then return solidTextShader end
    -- A compiled-but-unusable shader is just as unsafe as a compile failure:
    -- never keep retrying a stale uniform while painting white source glyphs
    -- on the cream cards.
    solidTextShader = false
  end
  return nil
end

local function drawText(graphics, Font, value, x, y, scale, color, maxWidth)
  if type(Font.width) == "function" then
    local width = Font.width(tostring(value or ""))
    if width > 0 then scale = math.min(scale or 2, (maxWidth or (WIDTH - x - 20)) / width) end
  end
  color = color or C.navy2
  local previousShader
  if type(graphics.getShader) == "function" then
    local ok, shader = pcall(graphics.getShader)
    if ok then previousShader = shader end
  end
  local shader = textShader(graphics, color)
  if shader then
    graphics.setShader(shader)
    setColor(graphics, C.white, color[4])
  else
    setColor(graphics, color)
  end
  graphics.push()
  graphics.translate(math.floor(x), math.floor(y))
  graphics.scale(scale or 2, scale or 2)
  Font.draw(tostring(value or ""), 0, 0)
  graphics.pop()
  if shader then
    if previousShader ~= nil then graphics.setShader(previousShader)
    else graphics.setShader() end
  end
end

local function language()
  local mod = V and V.mod
  local function find(id)
    if not (mod and type(mod.find) == "function") then return nil end
    local ok, value = pcall(mod.find, id)
    if not ok then ok, value = pcall(mod.find, mod, id) end
    return ok and value or nil
  end
  local universal = find("translation-german-universal")
  local boot = universal and universal.exports and universal.exports.bootLanguage
  if boot == "de" or boot == "en" then return boot end
  local kasc = find("kanto_ascendant")
  local resolve = kasc and kasc.exports and kasc.exports.language
  if type(resolve) == "function" then
    local ok, value = pcall(resolve)
    if ok and (value == "de" or value == "en") then return value end
  end
  for _, id in ipairs({"universal_german", "deutsch", "deutsch-blau", "deutsch-gelb"}) do
    if find(id) then return "de" end
  end
  return "en"
end

local function drawWideMoveLearn(state)
  local graphics = love and love.graphics
  local Font = classFor("src.render.Font")
  if not (graphics and Font and type(Font.draw) == "function"
      and type(graphics.rectangle) == "function"
      and type(graphics.push) == "function"
      and type(graphics.pop) == "function"
      and type(graphics.translate) == "function"
      and type(graphics.scale) == "function") then
    return false, "wide-renderer-unavailable"
  end

  if type(graphics.setShader) == "function" then graphics.setShader() end
  if type(graphics.setScissor) == "function" then graphics.setScissor() end
  if type(graphics.setBlendMode) == "function" then
    graphics.setBlendMode("alpha", "alphamultiply")
  end

  local german = language() == "de"
  rounded(graphics, C.navy2, 0, 0, WIDTH, HEIGHT)
  state.__vascMoveLearnBackdropStyle = "oras-wide"
  rounded(graphics, C.blue, 14, 13, 484, 43, 8)
  rounded(graphics, C.paper, 18, 17, 476, 35, 6)
  outline(graphics, C.gold, 18, 17, 476, 35, 6, 2)
  drawText(graphics, Font, "ASCENDANT", 32, 27, 2, C.navy)
  drawText(graphics, Font, german and "ATTACKE LERNEN" or "LEARN A MOVE", 246, 27, 2, C.navy)

  rounded(graphics, C.navy, 18, 66, 476, 156, 9)
  rounded(graphics, C.paper, 23, 71, 466, 146, 7)
  local mon = type(state.mon) == "table" and state.mon or {}
  local monName = type(state.monName) == "function" and state:monName()
    or mon.nickname or mon.species or "POKéMON"
  local moveDef = state.game and state.game.data and state.game.data.moves
    and state.game.data.moves[state.newMoveId]
  local moveName = type(moveDef) == "table" and moveDef.name
    or tostring(state.newMoveId or (german and "ATTACKE" or "MOVE"))
  drawText(graphics, Font, monName, 39, 82, 2, C.navy, 232)
  drawText(graphics, Font, moveName, 289, 82, 2, C.orange)

  if state.selecting then
    local rows = {}
    for index, move in ipairs(mon.moves or {}) do
      local moveId = type(move) == "table" and move.id or move
      local def = state.game and state.game.data and state.game.data.moves
        and state.game.data.moves[moveId]
      rows[#rows + 1] = type(def) == "table" and def.name
        or tostring(moveId or "—")
    end
    for index, label in ipairs(rows) do
      local x = index <= 3 and 39 or 267
      local y = 111 + ((index - 1) % 3) * 31
      if state.index == index then
        rounded(graphics, C.orange, x - 7, y - 7, 207, 27, 5)
        outline(graphics, C.navy, x - 7, y - 7, 207, 27, 5, 1)
      end
      drawText(graphics, Font, label, x, y, 2,
        state.index == index and C.white or C.navy2, 193)
    end
  else
    drawText(graphics, Font, german and "WÄHLE EINE ATTACKE," or "CHOOSE A MOVE", 52, 126, 2, C.gray)
    drawText(graphics, Font, german and "DIE VERGESSEN WERDEN SOLL." or "TO FORGET.", 52, 158, 2, C.gray)
  end

  rounded(graphics, C.orange, 18, 232, 476, 42, 8)
  rounded(graphics, C.paper, 22, 236, 468, 34, 6)
  drawText(graphics, Font, state.selecting
    and (german and "WELCHE ATTACKE SOLL VERGESSEN WERDEN?" or "WHICH MOVE SHOULD BE FORGOTTEN?")
    or (german and "A BESTÄTIGEN   B ZURÜCK" or "A CONFIRM   B BACK"), 34, 246, 1, C.navy2)
  setColor(graphics, C.white)
  return true
end

local function drawWidePhysical(state, winW, winH)
  local graphics = love and love.graphics
  winW, winH = tonumber(winW), tonumber(winH)
  if not (graphics and winW and winH and winW > 0 and winH > 0
      and type(graphics.origin) == "function") then
    return drawWideMoveLearn(state)
  end
  local scale = math.min(winW / WIDTH, winH / HEIGHT)
  if scale >= 1 then scale = math.max(1, math.floor(scale)) end
  local x = math.floor((winW - WIDTH * scale) / 2)
  local y = math.floor((winH - HEIGHT * scale) / 2)
  graphics.push("all")
  graphics.origin()
  setColor(graphics, C.navy2)
  graphics.rectangle("fill", 0, 0, winW, winH)
  graphics.translate(x, y)
  graphics.scale(scale, scale)
  local ok, reason = drawWideMoveLearn(state)
  graphics.pop()
  return ok, reason
end

local function capturedCanvas(graphics)
  if type(graphics.getCanvas) ~= "function" then return false, nil end
  local result = packed(pcall(graphics.getCanvas))
  if not result[1] then return false, nil end
  return true, result[2]
end

local function restoreCanvas(graphics, captured, canvas)
  if captured and type(graphics.setCanvas) == "function" then
    if canvas == nil then pcall(graphics.setCanvas)
    else pcall(graphics.setCanvas, canvas) end
  end
end

local MODAL_FIELDS = {
  "draw", "drawWidescreen", "uiSize", "isWideBattleLayout", "sgbPalettes",
  "drawsWidescreen", "wantsFillScale", "letterboxWhite",
  "__vascOrasWideBattleOverlay", "__vascOrasWideTextBox", "__vascOrasWideChoiceBox",
}
local function reconcileModals(owner, record)
  if not OverlayPresentation then return end
  local states = owner.game and owner.game.stack and owner.game.stack.states or {}
  local found = false
  for _, state in ipairs(states) do
    if state == owner then found = true
    elseif found then
      if state.isOpaque then break end
      local method
      if classInstance(state, classFor("src.render.TextBox")) then
        method = "decorateTextBox"
      elseif classInstance(state, classFor("src.ui.ChoiceBox")) then
        method = "decorateChoiceBox"
      end
      if method and not record.modals[state] then
        local before, after = {}, {}
        for _, key in ipairs(MODAL_FIELDS) do before[key] = rawget(state, key) end
        OverlayPresentation[method](state, {wideBattle=true})
        for _, key in ipairs(MODAL_FIELDS) do after[key] = rawget(state, key) end
        record.modals[state] = {before=before, after=after}
      end
    end
  end
end

local restore

local function failOpen(state, record, reason)
  reason = stableCode(reason, "presentation-failure")
  lastError = reason
  state.__vascMoveLearnPresentationFailed = reason
  if not record.fallbackLogged then
    record.fallbackLogged = true
    diagnostic("move-learn-fallback",
      diagnosticFields(state, reason, "previous-presentation-restored"))
  end
  -- Stop claiming the surface immediately.  The guarded caller still invokes
  -- the captured native draw exactly once for this frame; subsequent frames
  -- belong to the legacy floating owner when it is installed, otherwise to the
  -- untouched native menu.  Keeping our marker after dropping isOpaque would
  -- make screen.render_visible yield to an owner that no longer owns pixels.
  if restore then restore(state, reason, true) end
end

local function guardedDraw(state, record, ...)
  local args = packed(...)
  local graphics = love and love.graphics
  if not (graphics and type(graphics.push) == "function"
      and type(graphics.pop) == "function") then
    failOpen(state, record, "graphics-guard-unavailable")
    return record.originalDraw(state, unpackValues(args, 1, args.n))
  end

  local canvasCaptured, previousCanvas = capturedCanvas(graphics)
  local pushed = pcall(graphics.push, "all")
  if not pushed then
    failOpen(state, record, "graphics-push-failed")
    return record.originalDraw(state, unpackValues(args, 1, args.n))
  end

  local backdropOK, painted, backdropReason = pcall(drawWideMoveLearn, state)
  if not backdropOK or not painted then
    pcall(graphics.pop)
    restoreCanvas(graphics, canvasCaptured, previousCanvas)
    failOpen(state, record,
      backdropOK and backdropReason
        or ("backdrop-draw-error-" .. tostring(painted)))
    return record.originalDraw(state, unpackValues(args, 1, args.n))
  end

  if not record.presentedLogged then
    record.presentedLogged = true
    diagnostic("move-learn-presented",
      diagnosticFields(state, state.__vascMoveLearnBackdropStyle,
        "full-surface-owner"))
  end

  local returned
  local ok, errorValue = xpcall(function()
    returned = packed(true)
  end, traceback)

  local popped, popError = pcall(graphics.pop)
  restoreCanvas(graphics, canvasCaptured, previousCanvas)
  if not ok or not popped then
    local reason = not ok and "native-draw-error" or "graphics-pop-failed"
    lastError = tostring(not ok and errorValue or popError)
    failOpen(state, record, reason)
    error(not ok and errorValue or popError, 0)
  end
  return unpackValues(returned, 1, returned.n)
end

restore = function(state, reason, handoffToLegacy)
  local record = decorated[state]
  if not record then return false, "not-decorated" end

  if rawget(state, "draw") == record.drawWrapper then
    if record.hadRawDraw then rawset(state, "draw", record.rawDraw)
    else rawset(state, "draw", nil) end
  else
    diagnostic("move-learn-owner-conflict",
      diagnosticFields(state, "draw-owner-changed-before-restore", "preserved"))
  end
  if record.finishWrapper and rawget(state, "finish") == record.finishWrapper then
    if record.hadRawFinish then rawset(state, "finish", record.rawFinish)
    else rawset(state, "finish", nil) end
  end
  if rawget(state, "__vascMoveLearnPresentationOwner") == M.owner then
    if record.hadRawOpacity then
      rawset(state, "isOpaque", record.originalOpacity)
    else
      rawset(state, "isOpaque", nil)
    end
    rawset(state, "__vascMoveLearnPresentation", nil)
    rawset(state, "__vascMoveLearnPresentationOwner", nil)
    rawset(state, "__vascMoveLearnPresentationSchema", nil)
    rawset(state, "__vascMoveLearnSourceCode", nil)
    rawset(state, "uiSize", record.rawUiSize)
    rawset(state, "isWideBattleLayout", record.rawIsWideBattleLayout)
    rawset(state, "drawWidescreen", record.rawDrawWidescreen)
    rawset(state, "drawsWidescreen", record.rawDrawsWidescreen)
    rawset(state, "wantsFillScale", record.rawWantsFillScale)
    rawset(state, "sgbPalettes", record.rawSgbPalettes)
    rawset(state, "letterboxWhite", record.rawLetterboxWhite)
  end

  for modal, saved in pairs(record.modals) do
    for _, key in ipairs(MODAL_FIELDS) do
      if rawget(modal, key) == saved.after[key] then rawset(modal, key, saved.before[key]) end
    end
  end
  decorated[state] = nil
  decoratedCount = math.max(0, decoratedCount - 1)
  local handedOff = handoffToLegacy == true
    and claimLegacy(state, reason) or false
  local exitFields = diagnosticFields(
    state,
    record.outcome or stableCode(reason, "screen-popped"),
    handedOff and "legacy-owner-restored" or "native-owner-restored")
  diagnostic("move-learn-exit-restore", exitFields)
  return true, handedOff and "legacy-owner-restored" or "native-owner-restored"
end

function M.decorate(state)
  if not M.isMoveLearnMenu(state) then
    return state, false, "not-move-learn-menu"
  end
  if decorated[state] or rawget(state, "__vascMoveLearnPresentation") then
    return state, false, "already-decorated"
  end
  -- Hot activation can encounter an instance that the old floating battle HUD
  -- already decorated.  Ask that exact owner to retire its wrappers first;
  -- never layer two draw/update owners onto the same native screen.
  if legacyOwns(state) and not releaseLegacy(state) then
    diagnostic("move-learn-owner-conflict",
      diagnosticFields(state, "legacy-owner-did-not-release", "not-claimed"))
    return state, false, "owner-conflict"
  end
  local foreignOwner = rawget(state, "__vascMoveLearnPresentationOwner")
  if foreignOwner ~= nil and foreignOwner ~= M.owner then
    diagnostic("move-learn-owner-conflict",
      diagnosticFields(state, "foreign-owner-marker", "not-claimed"))
    return state, false, "owner-conflict"
  end
  if rawget(state, "isOpaque") == true then
    diagnostic("move-learn-owner-conflict",
      diagnosticFields(state, "preexisting-opaque-owner", "not-claimed"))
    return state, false, "owner-conflict"
  end

  local originalDraw = state.draw
  if type(originalDraw) ~= "function" then
    return state, false, "not-drawable"
  end
  local record = {
    modals=setmetatable({}, {__mode="k"}),
    rawIsWideBattleLayout=rawget(state, "isWideBattleLayout"),
    originalDraw=originalDraw,
    hadRawDraw=rawget(state, "draw") ~= nil,
    rawDraw=rawget(state, "draw"),
    hadRawFinish=rawget(state, "finish") ~= nil,
    rawFinish=rawget(state, "finish"),
    originalFinish=state.finish,
    hadRawOpacity=rawget(state, "isOpaque") ~= nil,
    originalOpacity=rawget(state, "isOpaque"),
    rawUiSize=rawget(state, "uiSize"),
    rawDrawWidescreen=rawget(state, "drawWidescreen"),
    rawDrawsWidescreen=rawget(state, "drawsWidescreen"),
    rawWantsFillScale=rawget(state, "wantsFillScale"),
    rawSgbPalettes=rawget(state, "sgbPalettes"),
    rawLetterboxWhite=rawget(state, "letterboxWhite"),
  }
  record.drawWrapper = function(self, ...)
    return guardedDraw(self, record, ...)
  end
  state.draw = record.drawWrapper
  if type(record.originalFinish) == "function" then
    record.finishWrapper = function(self, learned, ...)
      record.outcome = learned == true and "move-replaced"
        or "move-declined-or-cancelled"
      return record.originalFinish(self, learned, ...)
    end
    state.finish = record.finishWrapper
  end
  state.isOpaque = true
  state.letterboxWhite = true
  state.uiSize = function() return WIDTH, HEIGHT end
  state.isWideBattleLayout = function() return true end
  state.drawsWidescreen = function() return true end
  state.wantsFillScale = function() return true end
  state.sgbPalettes = function()
    return { { colors=false, x=0, y=0, w=WIDTH, h=HEIGHT } }
  end
  state.drawWidescreen = function(self, winW, winH)
    return drawWidePhysical(self, winW, winH)
  end
  state.__vascMoveLearnPresentation = true
  state.__vascMoveLearnPresentationOwner = M.owner
  state.__vascMoveLearnPresentationSchema = M.schema
  state.__vascMoveLearnSourceCode = stackSource(state)
  decorated[state] = record
  decoratedCount = decoratedCount + 1
  reconcileModals(state, record)
  if type(MobileMenuPresentation) == "table"
      and type(MobileMenuPresentation.attach) == "function" then
    pcall(MobileMenuPresentation.attach, state, {
      owner="move_learn", logicalW=WIDTH, logicalH=HEIGHT,
      backdrop=C.navy2,
    })
  end
  diagnostic("move-learn-enter",
    diagnosticFields(state, state.__vascMoveLearnSourceCode,
      "full-surface-claimed"))
  return state, true
end

local function listen(mod, name, callback)
  local ok, token = pcall(mod.events.on, mod.events, name, callback)
  if not ok then return false, tostring(token) end
  eventUnregister[#eventUnregister + 1] = token
  return true
end

function M.install(mod)
  if installed then return true, "already-installed" end
  if not (type(mod) == "table" and mod.events
      and type(mod.events.on) == "function") then
    return false, "screen-events-unavailable"
  end

  if type(Diagnostics) == "table"
      and type(Diagnostics.registerSegment) == "function" then
    pcall(Diagnostics.registerSegment, {
      cardId=M.cardId,
      version="v1",
      schema=M.schema,
      owner=M.owner,
      active=true,
      dependencyStatus="ready",
      providerStatus="active",
      buildReceiptId="VASC_66_GEN1_MOVE_LEARN_PRESENTATION_RECEIPT",
      rollbackReceiptId="VASC_66_GEN1_MOVE_LEARN_PRESENTATION_ROLLBACK",
    })
  end

  local ok, reason = listen(mod, "screen.pushed", function(event)
    local state = type(event) == "table" and event.state or nil
    for owner, record in pairs(decorated) do reconcileModals(owner, record) end
    local decoratedOK, _, claimed, claimReason = pcall(M.decorate, state)
    if not decoratedOK then
      lastError = tostring(_)
      diagnostic("move-learn-fallback", {
        cardId=M.cardId, generation="gen1", owner=M.owner,
        reason="decorate-error", status="native-presentation-retained",
      })
      if M.isMoveLearnMenu(state) then
        claimLegacy(state, "decorate-error")
      end
    elseif M.isMoveLearnMenu(state) and claimed ~= true
        and claimReason ~= "already-decorated"
        and claimReason ~= "owner-conflict" then
      -- Constructor-time retirement happens before the pushed event.  If this
      -- Card cannot claim a legitimate native instance, hand it back instead of
      -- leaving neither presentation path responsible for it.
      claimLegacy(state, claimReason)
    end
  end)
  if not ok then eventUnregister = {} return false, reason end

  ok, reason = listen(mod, "screen.popped", function(event)
    local state = type(event) == "table" and event.state or nil
    if decorated[state] then restore(state, "screen-popped") end
  end)
  if not ok then
    local first = eventUnregister[1]
    if type(first) == "function" then pcall(first) end
    eventUnregister = {}
    return false, reason
  end

  local class = classFor("src.ui.MoveLearnMenu")
  if type(class) ~= "table" then
    for _, unregister in ipairs(eventUnregister) do
      if type(unregister) == "function" then pcall(unregister) end
    end
    eventUnregister = {}
    return false, "move-learn-class-unavailable"
  end
  local existing = rawget(class, PRESENTATION_HANDOFF_KEY)
  if existing ~= nil and existing ~= presentationHandoff then
    for _, unregister in ipairs(eventUnregister) do
      if type(unregister) == "function" then pcall(unregister) end
    end
    eventUnregister = {}
    return false, "presentation-handoff-owner-conflict"
  end
  handoffClass = class
  hadPreviousHandoff = existing ~= nil
  previousHandoff = existing
  installed = true
  rawset(class, PRESENTATION_HANDOFF_KEY, presentationHandoff)
  return true
end

function M.health()
  local removable = true
  for _, unregister in ipairs(eventUnregister) do
    if type(unregister) ~= "function" then removable = false break end
  end
  return {
    cardId=M.cardId,
    schema=M.schema,
    owner=M.owner,
    ok=installed and lastError == nil,
    state=installed and "active" or "inactive",
    eventRegistered=installed and #eventUnregister == 2,
    decorated=decoratedCount,
    handoffPublished=handoffClass ~= nil
      and rawget(handoffClass, PRESENTATION_HANDOFF_KEY) == presentationHandoff,
    removable=removable,
    lastError=lastError,
  }
end

function M.deactivate()
  if not installed then return true end
  for _, unregister in ipairs(eventUnregister) do
    if type(unregister) ~= "function" then
      return false, "screen-event-not-removable"
    end
  end
  for _, unregister in ipairs(eventUnregister) do
    local ok, reason = pcall(unregister)
    if not ok then return false, tostring(reason) end
  end
  eventUnregister = {}
  -- Mark inactive before returning live instances.  The legacy bridge may now
  -- claim them, whereas constructor-time checks must yield while this Card is
  -- active.
  installed = false
  local states = {}
  for state in pairs(decorated) do states[#states + 1] = state end
  for _, state in ipairs(states) do
    restore(state, "card-deactivated", true)
  end
  if handoffClass
      and rawget(handoffClass, PRESENTATION_HANDOFF_KEY) == presentationHandoff then
    if hadPreviousHandoff then
      rawset(handoffClass, PRESENTATION_HANDOFF_KEY, previousHandoff)
    else
      rawset(handoffClass, PRESENTATION_HANDOFF_KEY, nil)
    end
  end
  handoffClass, previousHandoff, hadPreviousHandoff = nil, nil, nil
  return true
end

M.restore = restore

return M
