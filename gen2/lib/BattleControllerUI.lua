-- Draw-only ORAS battle HUD for Gold/Silver/Crystal live 3D battles.
--
-- Gold still owns battle rules, timing, HP, move legality, inventory, party,
-- switching, input and outcomes. This module owns only the NORMAL live-3D
-- battle screen's presentation. The historical input implementation remains
-- below for source compatibility but Voxel Ascendant never installs it.
--
--     Triangle / Up      FIGHT
--     Square   / Left    PACK
--     Circle   / Right   RUN
--     Cross    / Down    PKMN
--
-- Left stick/WASD are reserved for direct Pokemon movement. The right stick is
-- consumed by BattleCinematic. The real controller D-pad remains available to
-- Gold's move/item/party submenus.
local V = ...
local okCanvasPresentation, CanvasPresentation = false, nil
if V and type(V.require) == "function" then
  okCanvasPresentation, CanvasPresentation =
    pcall(V.require, "CanvasPresentation")
end
if not okCanvasPresentation then CanvasPresentation = nil end
local okPerformanceDiagnostics, PerformanceDiagnostics = false, nil
if V and type(V.require) == "function" then
  okPerformanceDiagnostics, PerformanceDiagnostics =
    pcall(V.require, "PerformanceDiagnostics")
end
if not okPerformanceDiagnostics then PerformanceDiagnostics = nil end
local okEngineFont, EngineFont = pcall(require, "src.render.Font")
if not okEngineFont or type(EngineFont) ~= "table" then EngineFont = nil end
local okTouchControls, TouchControls = pcall(require, "src.core.TouchControls")
if not okTouchControls or type(TouchControls) ~= "table" then
  TouchControls = nil
end
local M = {
  installed = false,
  shortcuts = 0,
  draws = 0,
  fullDraws = 0,
  sceneDraws = 0,
  sceneDrawn = false,
  sceneReceipt = nil,
}

local installedGame = nil
local installedInput = nil
local fonts = {}
local images = {}
local blockedPadRelease = setmetatable({}, { __mode = "k" })
local blockedRawRelease = setmetatable({}, { __mode = "k" })
local blockedKeyRelease = {}
local polledPadHeld = setmetatable({}, { __mode = "k" })
-- v0.2.74: direct battle shortcuts are armed only after the command panel has
-- actually been drawn at least once for the current menu opening.  Gold can
-- switch phase to "menu" during a fixed step before the next render.  Without
-- this latch, a face-button edge in that tiny window selects an invisible
-- command and the panel appears only after the action has already fired.
local commandPresented = setmetatable({}, { __mode = "k" })
-- Status cards acquire their seat from the exact rendered head receipt while
-- the battle is idle.  During a native action the posed Stadium head can move
-- or disappear for a frame; keep the last reviewed seat until that action has
-- completely drained so HP furniture never follows an attack animation.
local statusAttachments = setmetatable({}, { __mode = "k" })
-- The caught marker means "owned before this encounter", never "the ball
-- currently on screen has already succeeded". Snapshot per BattleState and
-- species before the capture path mutates save.pokedex.caught.
local encounterCaught = setmetatable({}, { __mode = "k" })
-- Automatic intro-page advancement is per BattleState so a new encounter never
-- inherits the previous one's prompt signature/counter.
local introAuto = setmetatable({}, { __mode = "k" })
local AUTO_INTRO_HOLD_FRAMES = 6
local NIL_PAD = {}
local function padKey(joystick) return joystick or NIL_PAD end
local unpackValues = (table and table.unpack) or unpack

local function packValues(...)
  return { n=select("#", ...), ... }
end

-- Asset-backed HUD painters contain their own transform frames (notably the
-- hand cursor). Treat the complete painter as untrusted: drain every push it
-- successfully opened, reject a pop through our boundary, and put both the
-- graphics function table and caller Canvas back exactly before failing open.
local function withGraphicsBoundary(label, fn, ...)
  local G = love and love.graphics
  local originalPush = G and G.push
  local originalPop = G and G.pop
  if type(originalPush) ~= "function" or type(originalPop) ~= "function" then
    return pcall(fn, ...)
  end

  local previousCanvas, restoreCanvas
  if type(G.getCanvas) == "function" then
    local ok, value = pcall(G.getCanvas)
    if ok then previousCanvas, restoreCanvas = value, true end
  end
  local originalFields = {}
  for key, value in pairs(G) do originalFields[key] = { value=value } end
  originalFields.push = { value=originalPush }
  originalFields.pop = { value=originalPop }

  local pushed, pushErr = pcall(originalPush, "all")
  if not pushed then
    return false, tostring(label) .. " graphics guard push failed: "
      .. tostring(pushErr)
  end
  local depth = 1
  local function trackedPush(...)
    local values = packValues(originalPush(...))
    depth = depth + 1
    return unpackValues(values, 1, values.n)
  end
  local function trackedPop(...)
    if depth <= 1 then
      error(tostring(label) .. " crossed its graphics guard", 0)
    end
    local values = packValues(originalPop(...))
    depth = depth - 1
    return unpackValues(values, 1, values.n)
  end
  local installed, installErr = pcall(function()
    G.push, G.pop = trackedPush, trackedPop
  end)
  if not installed then
    pcall(function() G.push, G.pop = originalPush, originalPop end)
    pcall(originalPop)
    return false, tostring(label) .. " graphics guard install failed: "
      .. tostring(installErr)
  end

  local results = packValues(pcall(fn, ...))
  local restored, restoreErr = pcall(function()
    local repairs = {}
    for key, value in pairs(G) do
      local original = originalFields[key]
      if type(value) == "function"
          and (not original or original.value ~= value) then
        repairs[#repairs + 1] = {
          key=key, value=original and original.value or nil,
        }
      end
    end
    for key, original in pairs(originalFields) do
      if type(original.value) == "function" and G[key] ~= original.value then
        repairs[#repairs + 1] = { key=key, value=original.value }
      end
    end
    for _, repair in ipairs(repairs) do G[repair.key] = repair.value end
  end)

  local cleanupErr
  for _ = 1, depth do
    local ok, reason = pcall(originalPop)
    if not ok then cleanupErr = reason break end
  end
  local canvasErr
  if restoreCanvas and type(G.setCanvas) == "function" then
    local ok, reason
    if previousCanvas ~= nil then
      ok, reason = pcall(G.setCanvas, previousCanvas)
    else
      ok, reason = pcall(G.setCanvas)
    end
    if not ok then canvasErr = reason end
  end
  if not restored or cleanupErr ~= nil or canvasErr ~= nil then
    local primary = results[1] and nil or results[2]
    local detail = tostring(restoreErr or cleanupErr or canvasErr)
    if primary ~= nil then detail = tostring(primary) .. "; " .. detail end
    return false, tostring(label) .. " graphics cleanup failed: " .. detail
  end
  return unpackValues(results, 1, results.n)
end

-- Retained only as a fail-open compatibility reader for older in-flight
-- instances. New PACK/PKMN commands always enter Gold's own screen dispatcher;
-- the concrete Gen2PartyMenu is decorated by the shared ORAS provider instead
-- of duplicating party/item validation in this HUD.
local overlay = nil
local itemEffectsCache = nil
local partyPreviewCache = nil
local okHudTheme, HudTheme = pcall(V.require, "AscendantHudTheme")
if not okHudTheme then HudTheme = nil end

local function hudPalette()
  if HudTheme and type(HudTheme.resolve) == "function" then
    local ok, palette = pcall(HudTheme.resolve, installedGame)
    if ok and type(palette) == "table" then return palette end
  end
  return {
    panel={0.018,0.026,0.045}, frame={1,1,1},
    selection={1,1,1}, selectionFrame={1,1,1}, accent={1,0.86,0.56},
  }
end

local function themedColor(G, role, alpha)
  local value = hudPalette()[role] or { 1, 1, 1 }
  G.setColor(value[1], value[2], value[3], alpha == nil and 1 or alpha)
end

local function themedRow(G, selected, normalAlpha)
  themedColor(G, selected and "selection" or "frame",
              selected and 0.68 or (normalAlpha or 0.07))
end

local function customUIEnabled()
  -- Kept for call-site clarity.  The retired `customUI` option is forced false
  -- during migration solely to neutralize old hot-reloaded wrappers.  The
  -- current battle HUD is owned by `battleHudStyle` instead.
  return true
end

local function battleCommandsEnabled(screen)
  -- The battle's UI owner is selected once beside the live-world session.
  -- Reading the launcher/save option every frame allowed STANDARD/ORAS to
  -- change halfway through one BattleState, producing a transparent native
  -- panel with the wrong pics or an ORAS command layer over native framing.
  if type(screen) ~= "table"
      or rawget(screen, "_vascGen2BattlePresentation") == "native" then
    return false
  end
  local okOwner, owner = pcall(V.require, "OverworldBattle")
  if okOwner and type(owner) == "table"
      and type(owner.presentationPlan) == "function" then
    local okPlan, plan = pcall(owner.presentationPlan, screen)
    if okPlan and type(plan) == "table" and plan.standardHud ~= nil then
      return plan.standardHud ~= true
    end
  end
  -- No exact session plan means VASC did not acquire the live-world scene
  -- (missing compositor/Voxel/stage, or a foreign/recycled BattleState). Gold's
  -- complete native canvas and input must remain authoritative regardless of
  -- the currently selected option. A later option read is not a draw receipt.
  return false
end

-- Presentation-only option reader.  The in-game VASC menu writes the active
-- save immediately, while mod.options can still expose the value captured at
-- boot.  Prefer the live save bucket, then use the public options API.  This
-- helper never creates a bucket or writes a value: Gold/Silver/Crystal remain
-- the sole owners of every Pokemon and battle record read below.
local function optionValue(screen, key, fallback)
  local game = type(screen) == "table" and screen.game or installedGame
  local save = type(screen) == "table" and screen.save
    or (type(game) == "table" and game.save) or nil
  local mod = V and V.mod
  local modId = type(mod) == "table" and mod.id or nil
  local okSaved, saved = pcall(function()
    local all = save and save.options and save.options.modOptions
    local own = type(all) == "table" and type(modId) == "string"
      and all[modId] or nil
    -- Do not use `own[key] or nil`: false is a meaningful live toggle value.
    if type(own) == "table" then return own[key] end
    return nil
  end)
  if okSaved and saved ~= nil then return saved end

  local options = type(mod) == "table" and mod.options or nil
  if options and type(options.get) == "function" then
    local ok, value = pcall(options.get, options, key)
    if ok and value ~= nil then return value end
  end
  return fallback
end

local function optionChoice(screen, key, allowed, fallback)
  local value = optionValue(screen, key, fallback)
  value = tostring(value or ""):lower():gsub("[%s_-]+", "")
  return allowed[value] and value or fallback
end

local function optionToggle(screen, key, fallback)
  local value = optionValue(screen, key, fallback == true)
  if type(value) == "boolean" then return value end
  if type(value) == "number" then return value ~= 0 end
  value = tostring(value or ""):lower()
  if value == "true" or value == "1" or value == "on" or value == "yes" then
    return true
  end
  if value == "false" or value == "0" or value == "off" or value == "no" then
    return false
  end
  return fallback == true
end

local EXP_CHOICES = { off=true, black=true, blue=true }
local CAUGHT_CHOICES = { off=true, grey=true, red=true }
local STATUS_VALUE_CHOICES = { off=true, dv=true, full=true }

local function expBarChoice(screen)
  return optionChoice(screen, "qolExpBar", EXP_CHOICES, "blue")
end

local function caughtIndicatorChoice(screen)
  return optionChoice(screen, "qolCaughtIndicator", CAUGHT_CHOICES, "red")
end

local function wildDvChoice(screen)
  -- `wildDVs` is accepted as the dedicated/legacy gate.  The current shared
  -- Gen-2 menu calls the same read-only feature `statusValues` so summaries and
  -- wild-battle cards can share OFF/DV/FULL without duplicating saved state.
  local value = optionValue(screen, "wildDVs", nil)
  if value == nil then value = optionValue(screen, "statusValues", "off") end
  if type(value) == "boolean" then value = value and "dv" or "off" end
  value = tostring(value or "off"):lower():gsub("[%s_-]+", "")
  return STATUS_VALUE_CHOICES[value] and value or "off"
end

function M.qolSettings(screen)
  return {
    expBar = expBarChoice(screen),
    caughtIndicator = caughtIndicatorChoice(screen),
    gender = optionToggle(screen, "battleGender", true),
    statusValues = wildDvChoice(screen),
    readOnly = true,
  }
end

local function battleShortcutMode()
  local mod = V and V.mod
  local options = mod and mod.options
  if not (options and type(options.get) == "function") then return "face" end
  local ok, value = pcall(options.get, options, "battleShortcutMode")
  value = ok and tostring(value or "face"):lower() or "face"
  if value == "native" or value == "off" then return "native" end
  if value == "dpad" or value == "arrows" then return "dpad" end
  return "face"
end

-- Forward declaration: the same visual-ready test used by the HUD is also the
-- safety gate for direct shortcuts.  BattleState can keep phase == "menu"
-- while a message/text step is still on screen, so phase alone is NOT enough.
local commandReady
local function commandVisualReady(screen)
  return screen ~= nil and tostring(screen.phase or "") == "menu"
    and commandReady ~= nil and commandReady(screen) == true
end

local function commandInputReady(screen)
  return commandVisualReady(screen) and commandPresented[screen] == true
end

local function commandWarming(screen)
  return commandVisualReady(screen) and commandPresented[screen] ~= true
end

local function partyPreview()
  if partyPreviewCache == false then return nil end
  if partyPreviewCache then return partyPreviewCache end
  local ok, got = pcall(V.require, "PartyModelPreview")
  partyPreviewCache = (ok and type(got) == "table") and got or false
  if not partyPreviewCache then M.lastPartyPreviewError = tostring(got) end
  return partyPreviewCache or nil
end

local function releasePartyPreview(screen)
  local preview = partyPreviewCache
  if preview and type(preview.release) == "function" and screen then
    pcall(preview.release, screen)
  end
end

local function itemEffects()
  if itemEffectsCache ~= nil then return itemEffectsCache or nil end
  local ok, got = pcall(require, "src.core.gen2.ItemEffects")
  itemEffectsCache = ok and got or false
  return itemEffectsCache or nil
end

local function overlayFor(screen)
  if overlay and overlay.screen == screen then return overlay end
  return nil
end

local function closeOverlay(screen)
  if not screen or (overlay and overlay.screen == screen) then
    if overlay and overlay.screen then releasePartyPreview(overlay.screen) end
    overlay = nil
  end
end

local function partyOf(screen)
  local battle = screen and screen.battle
  local party = battle and battle.party
  if type(party) ~= "table" then
    party = screen and screen.save and screen.save.party
  end
  return type(party) == "table" and party or {}
end

local POCKET_ORDER = { ITEM = 1, BALL = 2, KEY_ITEM = 3, TM_HM = 4 }

local function packRows(screen)
  local save = screen and (screen.save or (screen.game and screen.game.save))
  local data = screen and screen.game and screen.game.data or {}
  local defs = data.items or {}
  local rows = {}
  for id, raw in pairs((save and save.inventory) or {}) do
    local count = tonumber(raw) or (raw and 1) or 0
    if count > 0 then
      local def = defs[id]
      rows[#rows + 1] = {
        id = id,
        count = count,
        name = (def and def.name) or tostring(id):gsub("_", " "),
        pocket = (def and def.pocket) or "ITEM",
        index = (def and tonumber(def.index)) or math.huge,
        disabled = def and def.battleMenu == "ITEMMENU_NOUSE" or false,
      }
    end
  end
  table.sort(rows, function(a, b)
    local ap = POCKET_ORDER[a.pocket] or 99
    local bp = POCKET_ORDER[b.pocket] or 99
    if ap ~= bp then return ap < bp end
    if a.index ~= b.index then return a.index < b.index end
    return tostring(a.id) < tostring(b.id)
  end)
  return rows
end

local function clampOverlayCursor(o)
  if not o then return end
  local count = 0
  if o.mode == "pack" then
    count = #(o.rows or {})
  elseif o.mode == "party" or o.mode == "itemparty" then
    count = #partyOf(o.screen)
  elseif o.mode == "itemmove" then
    count = #((o.targetMon and o.targetMon.moves) or {})
  end
  count = math.max(1, count)
  o.index = math.max(1, math.min(tonumber(o.index) or 1, count))
  local visible = 4
  o.scroll = math.max(0, tonumber(o.scroll) or 0)
  if o.index <= o.scroll then o.scroll = o.index - 1 end
  if o.index > o.scroll + visible then o.scroll = o.index - visible end
  o.scroll = math.max(0, math.min(o.scroll, math.max(0, count - visible)))
end

local function openPartyOverlay(screen)
  overlay = { screen = screen, mode = "party", index = 1, scroll = 0 }
  local party = partyOf(screen)
  local active = screen and screen.battle and screen.battle.player
  for i, mon in ipairs(party) do
    if mon == active then overlay.index = i break end
  end
  clampOverlayCursor(overlay)
  return true
end

local function openPackOverlay(screen)
  overlay = { screen = screen, mode = "pack", index = 1, scroll = 0,
              rows = packRows(screen) }
  clampOverlayCursor(overlay)
  return true
end

local function localMonName(screen, mon)
  if not mon then return "POKéMON" end
  if screen and type(screen.name) == "function" then
    local ok, name = pcall(screen.name, screen, mon)
    if ok and name and tostring(name) ~= "" then return tostring(name) end
  end
  return tostring(mon.nickname or mon.name or mon.species or "POKéMON")
end

local function overlayMessage(o, text)
  if o then o.message = tostring(text or "") end
end

local function confirmPartySwitch(screen, o)
  local party = partyOf(screen)
  local mon = party[o.index]
  if not mon then return false end
  local battle = screen and screen.battle
  if battle and mon == battle.player then
    overlayMessage(o, localMonName(screen, mon) .. " is already out.")
    return true
  end
  if battle and type(battle.switchLocked) == "function" then
    local ok, locked = pcall(battle.switchLocked, battle)
    if ok and locked then
      overlayMessage(o, localMonName(screen, battle.player) .. " can't be recalled!")
      return true
    end
  end
  if mon.isEgg then
    overlayMessage(o, "An EGG can't battle!")
    return true
  end
  if (tonumber(mon.hp) or 0) <= 0 then
    overlayMessage(o, "There's no will to battle!")
    return true
  end
  closeOverlay(screen)
  if type(screen.submit) == "function" then
    screen:submit({ kind = "switch", index = o.index })
    return true
  end
  return false
end

local function enterItemParty(screen, o, row, action)
  o.packIndex, o.packScroll = o.index, o.scroll
  o.mode = "itemparty"
  o.itemId, o.itemName, o.action = row.id, row.name, action
  o.index, o.scroll = 1, 0
  o.message = nil
  clampOverlayCursor(o)
  return true
end

local function confirmPack(screen, o)
  o.rows = packRows(screen)
  clampOverlayCursor(o)
  local row = o.rows[o.index]
  if not row then
    overlayMessage(o, "Your PACK is empty.")
    return true
  end
  if row.disabled then
    overlayMessage(o, "That won't help in battle.")
    return true
  end

  local I = itemEffects()
  local action = I and type(I.partyAction) == "function" and I.partyAction(row.id) or nil
  if action and type(screen.applyPartyItem) == "function" then
    return enterItemParty(screen, o, row, action)
  end

  closeOverlay(screen)
  if type(screen.useItem) == "function" then
    screen:useItem(row.id)
    return true
  end
  return false
end

local function confirmItemParty(screen, o)
  local party = partyOf(screen)
  local mon = party[o.index]
  if not mon then return false end
  local I = itemEffects()
  local restore = I and I.RESTORE_PP and I.RESTORE_PP[o.itemId]
  if o.action == "pp" and restore and not restore.each and not mon.isEgg then
    o.partyIndex, o.partyScroll = o.index, o.scroll
    o.mode = "itemmove"
    o.targetMon = mon
    o.index, o.scroll = 1, 0
    o.message = nil
    clampOverlayCursor(o)
    return true
  end
  local itemId, action = o.itemId, o.action
  closeOverlay(screen)
  screen:applyPartyItem(itemId, action, mon)
  return true
end

local function confirmItemMove(screen, o)
  local moves = (o.targetMon and o.targetMon.moves) or {}
  if not moves[o.index] then return false end
  local itemId, mon, slot = o.itemId, o.targetMon, o.index
  closeOverlay(screen)
  screen:applyPartyItem(itemId, "pp", mon, slot)
  return true
end

local function cancelOverlay(screen, o)
  if o.mode == "itemmove" then
    o.mode = "itemparty"
    o.targetMon = nil
    o.index = o.partyIndex or 1
    o.scroll = o.partyScroll or 0
    o.message = nil
    clampOverlayCursor(o)
    return true
  end
  if o.mode == "itemparty" then
    o.mode = "pack"
    o.rows = packRows(screen)
    o.index = o.packIndex or 1
    o.scroll = o.packScroll or 0
    o.message = nil
    clampOverlayCursor(o)
    return true
  end
  closeOverlay(screen)
  return true
end

local function overlayControl(screen, control)
  local o = overlayFor(screen)
  if not o then return false end
  if o.message and o.message ~= "" then
    if control == "confirm" or control == "cancel" then
      o.message = nil
      return true
    end
    return true
  end

  if control == "up" or control == "down" or control == "left" or control == "right" then
    local count
    if o.mode == "pack" then count = #(o.rows or {}) end
    if o.mode == "party" or o.mode == "itemparty" then count = #partyOf(screen) end
    if o.mode == "itemmove" then count = #((o.targetMon and o.targetMon.moves) or {}) end
    count = tonumber(count) or 0
    if count <= 0 then return true end
    local delta = (control == "up" and -1) or (control == "down" and 1)
      or (control == "left" and -4) or 4
    local nextIndex = (tonumber(o.index) or 1) + delta
    if math.abs(delta) == 1 then
      if nextIndex < 1 then nextIndex = count end
      if nextIndex > count then nextIndex = 1 end
    else
      nextIndex = math.max(1, math.min(count, nextIndex))
    end
    o.index = nextIndex
    clampOverlayCursor(o)
    return true
  end

  if control == "cancel" then return cancelOverlay(screen, o) end
  if control == "confirm" then
    if o.mode == "party" then return confirmPartySwitch(screen, o) end
    if o.mode == "pack" then return confirmPack(screen, o) end
    if o.mode == "itemparty" then return confirmItemParty(screen, o) end
    if o.mode == "itemmove" then return confirmItemMove(screen, o) end
  end
  return false
end

local INDEX = {
  fight = 1,
  pkmn = 2,
  pack = 3,
  run = 4,
}

local function stackTop(game)
  local stack = game and game.stack
  if not (stack and type(stack.top) == "function") then return nil end
  local ok, top = pcall(stack.top, stack)
  if not ok or type(top) ~= "table" then return nil end
  return top
end

-- v0.2.33: the live Gold battle renderer already learned this lesson in
-- v0.2.32: Game2.stack:top() is not a reliable authority for the BattleState
-- while the overworld/voxel battle bridge is composing the fight. Resolve the
-- exact BattleState held by OverworldBattle first whenever the stack top is not
-- itself a battle screen. This keeps the physical face-button shortcuts wired
-- to the same screen that VoxelScene is visibly rendering.
local function sessionBattleScreen()
  local okO, OverworldBattle = pcall(V.require, "OverworldBattle")
  if not (okO and type(OverworldBattle) == "table") then return nil end

  if type(OverworldBattle.battle) == "function" then
    local ok, screen = pcall(OverworldBattle.battle)
    if ok and type(screen) == "table" and type(screen.battle) == "table" then
      return screen
    end
  end

  -- Compatibility with slightly older embedded OverworldBattle revisions that
  -- exposed only cameraContext().screen.
  if type(OverworldBattle.cameraContext) == "function" then
    local ok, ctx = pcall(OverworldBattle.cameraContext)
    local screen = ok and type(ctx) == "table" and ctx.screen or nil
    if type(screen) == "table" and type(screen.battle) == "table" then
      return screen
    end
  end
  return nil
end

local function screenOf(game)
  local top = stackTop(game)
  if type(top) == "table" and type(top.battle) == "table" then return top end
  return sessionBattleScreen()
end

local function isSpecialBattle(screen)
  if type(screen) ~= "table" then return true end
  local battle = type(screen.battle) == "table" and screen.battle or {}
  return screen.tutorial == true or screen.contest == true
    or screen.safari == true or screen.link == true
    or battle.tutorial == true or battle.contest == true
    or battle.safari == true or battle.link == true
end

local function battleInputOwned(game)
  -- v0.2.44: BATTLE COMMANDS is now a complete UI-mode switch.  OFF means
  -- Gold owns the battle screen and its controls again, rather than merely
  -- hiding our command diamond while the replacement HUD still owns the frame.
  local screen = screenOf(game)
  if not screen then return nil end
  if not battleCommandsEnabled(screen) then return nil end
  -- Tutorial and contest flows have special cart-authored menus and automatic
  -- input; do not replace those here.
  if isSpecialBattle(screen) then return nil end
  if screen.phase == "done" or screen.phase == "evolving" then return nil end
  -- openParty/openPack change the battle state to submenu before pushing the
  -- native screen. Once that happens, immediately yield ALL input back to Gold
  -- so the party/item menu gets its normal D-pad, stick and A/B handling.
  if screen.phase == "submenu" then return nil end
  return screen
end

function M.owns(screen)
  -- GAME DEFAULT restores Gold's original HUD/text/input ownership. Returning
  -- false prevents the custom HUD from being baked into VoxelScene; the
  -- compositor overlays Gold's transparent native UI on the selected staged
  -- world, while BATTLE WORLD = GAME DEFAULT retains its complete native scene.
  if not battleCommandsEnabled(screen) then return false end
  if type(screen) ~= "table" or type(screen.battle) ~= "table" then return false end
  if isSpecialBattle(screen) then return false end
  local phase = tostring(screen.phase or "")
  -- Ownership is latched across the complete ordinary live-world battle.
  -- Falling back merely because Gold is presenting a line of text, an intro,
  -- an HP drain or a move animation causes its opaque cartridge canvas to
  -- flash over the Voxel arena between every ORAS frame. Those fields are
  -- engine *state*, not a different screen owner, and are rendered below.
  -- Only genuinely pushed/complex native workflows leave this surface.
  -- `stats-box` is not such a workflow: Gold keeps it on the same BattleState
  -- while presenting level/stat and "learned MOVE" messages. Yielding there
  -- made the compositor show one opaque white cartridge frame and permanently
  -- latch an otherwise healthy voxel encounter to `native`. Keep the staged
  -- world/HUD owner and let drawFull paint the live engine message instead.
  if phase == "submenu" or phase == "evolving"
      or phase == "ask-forget" then return false end
  if screen.evolution or screen.yesNo
      or screen.confirm then return false end
  return true
end

local function clearNativeStick(input)
  if type(input) ~= "table" then return end
  local dir = input.stickDir
  if dir then
    if type(input.sourceRelease) == "function" then
      pcall(input.sourceRelease, input, dir, "stick")
    else
      local sources = input.sources and input.sources[dir]
      if type(sources) == "table" then sources.stick = nil end
      if input.state then input.state[dir] = false end
    end
  end
  input.stickDir = nil
  input.stickAxis = input.stickAxis or { x = 0, y = 0 }
  input.stickAxis.x, input.stickAxis.y = 0, 0
end

local function playerMoves(screen)
  if type(screen.playerMoves) == "function" then
    local ok, moves = pcall(screen.playerMoves, screen)
    if ok and type(moves) == "table" then return moves end
  end
  local mon = screen.battle and screen.battle.player
  return (mon and mon.moves) or {}
end

local shortcutTapSerial = 0

-- Feed a command through Gold's OWN battle-menu dispatcher instead of
-- duplicating BattleState's FIGHT/RUN/PACK/PKMN branches here.  The live
-- controller button selects the native 2x2 cursor slot, then we enqueue one
-- synthetic GB A edge.  On the next fixed step BattleState:update sees exactly
-- the same input it would have seen if the player moved the native cursor and
-- pressed A, so PACK/PKMN go through Screens.push with Gold's current stack,
-- callbacks and menu classes.
local function queueNativeConfirm(screen)
  local input = installedInput or (screen and screen.game and screen.game.input)
  if type(input) ~= "table" then return false, "no live input object" end

  shortcutTapSerial = shortcutTapSerial + 1
  local source = "stadium2:battle-command:" .. tostring(shortcutTapSerial)

  if type(input.sourcePress) == "function"
      and type(input.sourceRelease) == "function" then
    input:sourcePress("a", source)
    input:sourceRelease("a", source)
    return true
  end

  -- Compatibility fallback for older dev builds: the current matching repo
  -- exposes sourcePress/sourceRelease, but a direct queued A edge has the same
  -- fixed-step semantics if those helpers are absent.
  if type(input.pressQueue) == "table" then
    input.pressQueue[#input.pressQueue + 1] = "a"
    return true
  end

  return false, "input cannot enqueue native A"
end

-- v0.2.74: the custom live battle UI should arrive at its command panel on its
-- own.  Current Gold intentionally holds intro text at PromptButton until A/B;
-- that made the first physical controller press both dismiss the unseen final
-- intro prompt and, after phase flipped to menu, become a direct PACK/FIGHT/etc.
-- shortcut.  Auto-page ONLY the battle intro while the custom battle UI owns
-- the screen.  Every later battle prompt remains player-controlled.
local function autoAdvanceIntro(screen)
  if not (screen and battleCommandsEnabled(screen)) then return false end
  if screen.tutorial or screen.contest then return false end
  if tostring(screen.phase or "") ~= "intro" then
    introAuto[screen] = nil
    return false
  end
  if (tonumber(screen.messageTimer) or 0) <= 0 or not screen.message then
    return false
  end
  -- Match BattleState:update's gates: do not queue a prompt edge while an SFX,
  -- send-out animation, HP/slide animation, or stats panel still owns the loop.
  if screen.waitSfx or screen.anim or screen.hpAnim or screen.faintSlide
      or screen.trainerSlide or screen.statsBoxMon then
    return false
  end

  local queueCount = type(screen.queue) == "table" and #screen.queue or -1
  local sig = table.concat({
    tostring(screen.message), tostring(screen.messagePage or 0),
    tostring(queueCount), tostring(screen.showPlayerTrainer),
    tostring(screen.showEnemyTrainer),
  }, "\31")
  local state = introAuto[screen]
  if not state then
    state = { sig = nil, frames = 0, queued = false }
    introAuto[screen] = state
  end
  if state.sig ~= sig then
    state.sig, state.frames, state.queued = sig, 0, false
  end
  if state.queued then return true end

  state.frames = state.frames + 1
  if state.frames < AUTO_INTRO_HOLD_FRAMES then return true end
  local queued, err = queueNativeConfirm(screen)
  if queued then
    state.queued = true
    M.autoIntroPrompts = (M.autoIntroPrompts or 0) + 1
    M.lastAutoIntroError = nil
  else
    M.lastAutoIntroError = tostring(err or "failed to auto-advance battle intro")
  end
  return queued
end

local function activateImpl(screen, index)
  if not (screen and screen.battle and commandInputReady(screen)) then return false end
  index = tonumber(index)
  if not (index and index >= 1 and index <= 4) then return false end

  -- MENU order in Gold: 1 FIGHT, 2 PKMN, 3 PACK, 4 RUN.
  --
  -- Every slot uses Gold's exact native A-confirm dispatcher. In particular,
  -- PKMN/PACK must let BattleState push Gen2PartyMenu/Gen2PackMenu so forced
  -- switches, eggs, fainted mons, item targets and callbacks keep one owner.
  screen.menuIndex = index
  closeOverlay(screen)
  local queued, err = queueNativeConfirm(screen)
  if not queued then error(err or "failed to queue native battle confirm", 0) end
  return true
end

function M.activate(screen, index)
  local ok, used = pcall(activateImpl, screen, index)
  if ok and used then
    M.lastShortcutError = nil
    M.shortcuts = M.shortcuts + 1
    return true
  end
  if not ok then
    M.lastShortcutError = tostring(used)
    local log = V and V.mod and V.mod.log
    if log and type(log.warn) == "function" then
      pcall(log.warn, log, "battle controller shortcut failed: %s", M.lastShortcutError)
    end
  end
  return false
end

local KEY_CHOICE = {
  left = INDEX.pack,
  right = INDEX.run,
  up = INDEX.fight,
  down = INDEX.pkmn,
}

-- SDL/LÖVE mapped names: west=x (PS Square / Xbox X), east=b (Circle/B),
-- south=a (Cross/A), north=y (Triangle/Y).
local PAD_CHOICE = {
  x = INDEX.pack,
  b = INDEX.run,
  a = INDEX.pkmn,
  y = INDEX.fight,
}

local PAD_DPAD_CHOICE = {
  dpleft = INDEX.pack,
  dpright = INDEX.run,
  dpdown = INDEX.pkmn,
  dpup = INDEX.fight,
}

-- Generic desktop raw joystick convention (1=A,2=B,3=X,4=Y). The engine only
-- maps raw A/B itself; adding X/Y here keeps the four-command diamond usable on
-- Linux handhelds/controllers that SDL does not recognize as a gamepad.
local RAW_CHOICE = {
  [3] = INDEX.pack,
  [2] = INDEX.run,
  [1] = INDEX.pkmn,
  [4] = INDEX.fight,
}

function M.install(game)
  if M.installed then return game == installedGame end
  if type(game) ~= "table" then return false, "no live Game2 host" end
  local input = game.input
  if type(input) ~= "table" then return false, "live Game2 host has no input object" end
  installedGame, installedInput = game, input

  -- Reserve mapped left stick before Input converts it to GB D-pad directions.
  do
    local inner = input.gamepadaxis
    input.gamepadaxis = function(self, joystick, axis, value, ...)
      local screen = battleInputOwned(game)
      if screen and (axis == "leftx" or axis == "lefty") then
        clearNativeStick(self)
        return
      end
      if inner then return inner(self, joystick, axis, value, ...) end
    end
  end

  -- Same reservation for unrecognized/raw pads. Input maps raw axes 1/2 back
  -- into gamepadaxis(leftx/lefty), but intercepting here avoids even one queued
  -- menu direction on hosts where that conversion is wrapped elsewhere.
  do
    local inner = input.joystickaxis
    input.joystickaxis = function(self, joystick, axis, value, ...)
      local screen = battleInputOwned(game)
      if screen and (axis == 1 or axis == 2) then
        clearNativeStick(self)
        return
      end
      if inner then return inner(self, joystick, axis, value, ...) end
    end
  end

  -- WASD is Pokemon locomotion. Arrow keys are the four direct command slots
  -- while the command diamond is up. Outside that phase the arrow keys return
  -- to Gold normally, so move/item lists keep ordinary keyboard navigation.
  do
    local innerPress, innerRelease = input.keypressed, input.keyreleased
    input.keypressed = function(self, key, ...)
      local screen = battleInputOwned(game)
      if screen then
        local o = overlayFor(screen)
        if o then
          local controls = {
            up = "up", down = "down", left = "left", right = "right",
            z = "confirm", ["return"] = "confirm", space = "confirm",
            x = "cancel", backspace = "cancel",
          }
          local control = controls[key]
          if control and overlayControl(screen, control) then
            blockedKeyRelease[key] = true
            return
          end
          -- The custom list owns battle input completely; WASD remains
          -- locomotion-reserved and command hotkeys cannot fire behind it.
          if key == "w" or key == "a" or key == "s" or key == "d" then
            blockedKeyRelease[key] = true
            return
          end
        else
          if key == "w" or key == "a" or key == "s" or key == "d" then
            blockedKeyRelease[key] = true
            return
          end
          local shortcutMode = battleShortcutMode()
          -- A menu can become logically ready before its first render. Swallow
          -- command hotkeys during that one-frame warmup so the hidden native
          -- cursor cannot move/select behind the custom panel.
          if shortcutMode ~= "native" and commandWarming(screen)
              and KEY_CHOICE[key] then
            blockedKeyRelease[key] = true
            return
          end
          local choice = shortcutMode ~= "native" and commandInputReady(screen)
            and KEY_CHOICE[key] or nil
          if choice and M.activate(screen, choice) then
            blockedKeyRelease[key] = true
            return
          end
        end
      end
      if innerPress then return innerPress(self, key, ...) end
    end
    input.keyreleased = function(self, key, ...)
      if blockedKeyRelease[key] then
        blockedKeyRelease[key] = nil
        return
      end
      if innerRelease then return innerRelease(self, key, ...) end
    end
  end

  -- Mapped face buttons directly activate the four command slots before the
  -- engine translates A/B into Game Boy confirm/cancel actions.
  do
    local innerPress, innerRelease = input.gamepadpressed, input.gamepadreleased
    input.gamepadpressed = function(self, joystick, button, ...)
      local screen = battleInputOwned(game)
      local handled = false
      if screen and overlayFor(screen) then
        local controls = {
          dpup = "up", dpdown = "down", dpleft = "left", dpright = "right",
          a = "confirm", b = "cancel",
        }
        local control = controls[button]
        if control then handled = overlayControl(screen, control) end
        -- Square/Triangle are command buttons only on the command diamond.
        -- Swallow them while a selector is open so they never leak to Gold.
        if button == "x" or button == "y" then handled = true end
      else
        local shortcutMode = battleShortcutMode()
        local choice = nil
        if screen and commandInputReady(screen) then
          if shortcutMode == "face" then
            choice = PAD_CHOICE[button]
          elseif shortcutMode == "dpad" then
            choice = PAD_DPAD_CHOICE[button]
          end
        end
        if choice then
          handled = M.activate(screen, choice)
        elseif screen and shortcutMode ~= "native" and commandWarming(screen) then
          -- The command panel is logically ready but has not reached the screen
          -- yet. Consume its shortcut buttons for this edge; never let the
          -- native hidden menu accept an input the player could not see.
          local warmChoice = shortcutMode == "face" and PAD_CHOICE[button]
            or (shortcutMode == "dpad" and PAD_DPAD_CHOICE[button] or nil)
          if warmChoice then handled = true end
        elseif screen and shortcutMode == "face" and PAD_CHOICE[button]
            and not commandInputReady(screen) then
          -- If this physical face button is being used to page an intro line,
          -- remember that it is already held before forwarding it to Gold.
          -- The polling fallback must not reinterpret the SAME held edge as a
          -- command after BattleState flips to menu later in the frame.
          local key = padKey(joystick)
          local poll = polledPadHeld[key]
          if not poll then poll = {}; polledPadHeld[key] = poll end
          poll[button] = true
        end
      end
      if handled then
        local key = padKey(joystick)
        local held = blockedPadRelease[key]
        if not held then held = {}; blockedPadRelease[key] = held end
        held[button] = true
        local poll = polledPadHeld[key]
        if not poll then poll = {}; polledPadHeld[key] = poll end
        poll[button] = true
        return
      end
      if innerPress then return innerPress(self, joystick, button, ...) end
    end
    input.gamepadreleased = function(self, joystick, button, ...)
      local key = padKey(joystick)
      local held = blockedPadRelease[key]
      if held and held[button] then
        held[button] = nil
        local poll = polledPadHeld[key]
        if poll then poll[button] = nil end
        return
      end
      local poll = polledPadHeld[key]
      if poll then poll[button] = nil end
      if innerRelease then return innerRelease(self, joystick, button, ...) end
    end
  end

  -- Raw/unmapped face buttons. Recognized gamepads are ignored by the engine's
  -- raw path, so this block is only for generic joysticks/handheld controls.
  do
    local innerPress, innerRelease = input.joystickpressed, input.joystickreleased
    input.joystickpressed = function(self, joystick, button, ...)
      local screen = battleInputOwned(game)
      local handled = false
      if screen and overlayFor(screen) then
        if button == 1 then handled = overlayControl(screen, "confirm")
        elseif button == 2 then handled = overlayControl(screen, "cancel")
        elseif button == 3 or button == 4 then handled = true end
      else
        local shortcutMode = battleShortcutMode()
        local choice = screen and shortcutMode == "face"
          and commandInputReady(screen) and RAW_CHOICE[button] or nil
        if choice then
          handled = M.activate(screen, choice)
        elseif screen and shortcutMode == "face" and commandWarming(screen)
            and RAW_CHOICE[button] then
          handled = true
        end
      end
      if handled then
        local key = padKey(joystick)
        local held = blockedRawRelease[key]
        if not held then held = {}; blockedRawRelease[key] = held end
        held[button] = true
        return
      end
      if innerPress then return innerPress(self, joystick, button, ...) end
    end
    input.joystickreleased = function(self, joystick, button, ...)
      local key = padKey(joystick)
      local held = blockedRawRelease[key]
      if held and held[button] then
        held[button] = nil
        return
      end
      if innerRelease then return innerRelease(self, joystick, button, ...) end
    end
  end

  -- Raw joystick D-pads usually arrive as hats. Keep those on the custom
  -- selector instead of letting Input turn them into Gold menu directions
  -- behind the Stadium overlay.
  do
    local inner = input.joystickhat
    input.joystickhat = function(self, joystick, hat, direction, ...)
      local screen = battleInputOwned(game)
      if screen and overlayFor(screen) then
        local controls = {
          u = "up", d = "down", l = "left", r = "right",
          lu = "up", ru = "up", ld = "down", rd = "down",
        }
        local control = controls[direction]
        if control then
          overlayControl(screen, control)
          return
        elseif direction == "c" then
          return
        end
      elseif screen and battleShortcutMode() == "dpad"
          and commandInputReady(screen) then
        -- Match the visible Kanto diamond and the keyboard/gamepad mappings:
        -- FIGHT is above, PKMN below, PACK left and RUN right.  The previous
        -- raw-hat table had both vertical choices swapped, so pressing down
        -- from FIGHT selected PACK instead of POKEMON on generic controllers.
        local hats = { l = INDEX.pack, r = INDEX.run,
                       d = INDEX.pkmn, u = INDEX.fight }
        local choice = hats[direction]
        if choice and M.activate(screen, choice) then return end
      elseif screen and battleShortcutMode() == "dpad" and commandWarming(screen) then
        local hats = { l = true, r = true, d = true, u = true,
                       lu = true, ru = true, ld = true, rd = true }
        if hats[direction] then return end
      end
      if inner then return inner(self, joystick, hat, direction, ...) end
    end
  end

  M.installed = true
  return true
end

-- Poll mapped face buttons as a fallback for controller stacks where another
-- wrapper swallows or delays gamepadpressed. Also continually erase any stale
-- analog-stick D-pad source created before battle ownership began.
function M.update(game)
  game = game or installedGame
  if not M.installed or game ~= installedGame then return false end
  local screen = battleInputOwned(game)
  if not screen then
    if overlay and overlay.screen then releasePartyPreview(overlay.screen) end
    overlay = nil
    return false
  end
  if overlay and (overlay.screen ~= screen or screen.phase ~= "menu"
      or (screen.battle and screen.battle.over)) then
    if overlay.screen then releasePartyPreview(overlay.screen) end
    overlay = nil
  end
  if not commandVisualReady(screen) then commandPresented[screen] = nil end
  -- No physical A/B is required to reach the first command panel in an
  -- ordinary custom-UI battle. The intro pages itself through Gold's own input
  -- queue; subsequent messages/prompts remain untouched.
  autoAdvanceIntro(screen)
  clearNativeStick(installedInput)

  local J = love and love.joystick
  if not (J and type(J.getJoysticks) == "function") then return true end
  local okList, list = pcall(J.getJoysticks)
  if not okList or type(list) ~= "table" then return true end
  for _, js in ipairs(list) do
    local okPad, mapped = pcall(function()
      return js and type(js.isGamepad) == "function" and js:isGamepad()
    end)
    if okPad and mapped and type(js.isGamepadDown) == "function" then
      local held = polledPadHeld[js]
      if not held then held = {}; polledPadHeld[js] = held end
      local o = overlayFor(screen)
      if o then
        local controls = {
          a = "confirm", b = "cancel",
          dpup = "up", dpdown = "down", dpleft = "left", dpright = "right",
        }
        for button, control in pairs(controls) do
          local okDown, down = pcall(js.isGamepadDown, js, button)
          down = okDown and down and true or false
          if down and not held[button] then
            held[button] = true
            overlayControl(screen, control)
          elseif not down then
            held[button] = nil
          end
        end
      else
        local shortcutMode = battleShortcutMode()
        local shortcutMap = shortcutMode == "dpad" and PAD_DPAD_CHOICE or PAD_CHOICE
        for button, choice in pairs(shortcutMap) do
          local okDown, down = pcall(js.isGamepadDown, js, button)
          down = okDown and down and true or false
          if down and not held[button] then
            held[button] = true
            if shortcutMode ~= "native" and commandInputReady(screen) then
              M.activate(screen, choice)
            end
          elseif not down then
            held[button] = nil
          end
        end
      end
    end
  end
  return true
end

local function font(size)
  size = math.max(10, math.floor(size + 0.5))
  if fonts[size] ~= nil then return fonts[size] or nil end
  local G = love and love.graphics
  if not (G and type(G.newFont) == "function") then
    fonts[size] = false
    return nil
  end
  local ok, f = pcall(G.newFont, size)
  fonts[size] = ok and f or false
  return fonts[size] or nil
end

local function assetImage(path)
  if images[path] ~= nil then return images[path] or nil end
  local assets = V and V.mod and V.mod.assets
  if not (assets and type(assets.image) == "function") then
    images[path] = false
    return nil
  end
  local ok, image = pcall(assets.image, assets, path)
  if ok and image then
    if type(image.setFilter) == "function" then
      pcall(image.setFilter, image, "nearest", "nearest")
    end
    images[path] = image
    return image
  end
  images[path] = false
  return nil
end

local function drawOrasText(text, x, y, scale, alpha)
  text = tostring(text or ""):gsub("[\v\f\r\n]", " ")
                              :gsub("%s+", " ")
  scale = tonumber(scale) or 1
  local G = love.graphics
  local f = font(math.max(10, 8 * scale))
  if f then G.setFont(f) end
  G.setColor(0.005, 0.015, 0.025, alpha or 0.92)
  G.print(text, x + 1, y + 1)
  G.setColor(0.94, 0.99, 1.00, alpha or 1)
  G.print(text, x, y)
  return G.getFont():getWidth(text)
end

local function drawCenteredOrasText(text, cx, y, scale, alpha)
  local G = love.graphics
  local f = font(math.max(10, 8 * (tonumber(scale) or 1)))
  if f then G.setFont(f) end
  local width = G.getFont():getWidth(tostring(text or ""))
  return drawOrasText(text, cx - width * 0.5, y, scale, alpha)
end

-- The shared Gen-1 ORAS cards use the cartridge's extracted 8px font rather
-- than a desktop TTF.  Keep that exact glyph source for Crystal's status and
-- move cards as well.  The font sheet is black-on-transparent, so a tiny mask
-- shader supplies the white/black ORAS ink without modifying engine font data.
local HUD_TEXT_MASK_SHADER = [[
  uniform vec4 ink;
  vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec4 src = Texel(tex, tc);
    return vec4(ink.rgb, ink.a * src.a * color.a);
  }
]]
local hudTextMask = nil

local function hudTextShader()
  if hudTextMask == false then return nil end
  if hudTextMask then return hudTextMask end
  local G = love and love.graphics
  if not (G and type(G.newShader) == "function") then
    hudTextMask = false
    return nil
  end
  local ok, shader = pcall(G.newShader, HUD_TEXT_MASK_SHADER)
  hudTextMask = ok and shader or false
  return hudTextMask or nil
end

local function hudTextWidth(text)
  text = tostring(text or "")
  if EngineFont and type(EngineFont.width) == "function" then
    local ok, width = pcall(EngineFont.width, text)
    if ok and tonumber(width) then return tonumber(width) end
  end
  return #text * 8
end

local function fitHudText(text, maxWidth)
  text = tostring(text or "")
  if hudTextWidth(text) <= maxWidth then return text end
  local suffix = "."
  while #text > 0 and hudTextWidth(text .. suffix) > maxWidth do
    text = text:sub(1, -2)
  end
  return text .. suffix
end

local function drawMaskedHudText(text, x, y, r, g, b, a)
  local G = love.graphics
  local shader = hudTextShader()
  if not (shader and EngineFont and type(EngineFont.draw) == "function") then
    G.setColor(r, g, b, a or 1)
    G.print(tostring(text or ""), x, y)
    return
  end
  local previous = G.getShader()
  G.setShader(shader)
  pcall(shader.send, shader, "ink", { r, g, b, a or 1 })
  G.setColor(1, 1, 1, 1)
  EngineFont.draw(tostring(text or ""), x, y)
  G.setShader(previous)
end

local function drawHudText(text, x, y, scale, alpha)
  local G = love.graphics
  scale = tonumber(scale) or 1
  G.push()
  G.translate(x, y)
  G.scale(scale, scale)
  drawMaskedHudText(text, 1 / math.max(scale, .001),
    1 / math.max(scale, .001), 0.005, 0.015, 0.025, alpha or .96)
  drawMaskedHudText(text, 0, 0, .94, .99, 1.00, alpha or 1)
  G.pop()
  return hudTextWidth(text) * scale
end

local function drawCenteredHudText(text, cx, y, scale, alpha)
  scale = tonumber(scale) or 1
  return drawHudText(text, cx - hudTextWidth(text) * scale * .5,
    y, scale, alpha)
end

local function roundRect(mode, x, y, w, h, r)
  love.graphics.rectangle(mode, x, y, w, h, r, r)
end

local function panel(x, y, w, h, r, alpha)
  local G = love.graphics
  themedColor(G, "panel", alpha or 0.88)
  roundRect("fill", x, y, w, h, r)
  themedColor(G, "frame", 0.72)
  G.setLineWidth(2)
  roundRect("line", x, y, w, h, r)
end

local function cleanText(text)
  text = tostring(text or "")
  text = text:gsub("[\v\f\r]", " ")
  text = text:gsub("\n", "  ")
  text = text:gsub("%s+", " ")
  return text
end

local function monName(screen, mon)
  if not mon then return "" end
  if type(screen.name) == "function" then
    local ok, name = pcall(screen.name, screen, mon)
    if ok and name and tostring(name) ~= "" then return cleanText(name) end
  end
  if mon.nickname then return cleanText(mon.nickname) end
  if mon.name then return cleanText(mon.name) end
  local data = screen.game and screen.game.data
  local def = data and data.pokemon and data.pokemon[mon.species]
  if def and def.name then return cleanText(def.name) end
  return "#" .. tostring(mon.species or "?")
end

local function shownHp(screen, side, mon)
  if not mon then return 0, 1 end
  local hp = tonumber(mon.hp) or 0
  local shown = screen.shownHp
  if type(shown) == "table" and tonumber(shown[side]) then hp = tonumber(shown[side]) end
  local maxHp = tonumber(mon.maxHp)
    or (type(mon.stats) == "table" and tonumber(mon.stats.hp)) or math.max(1, hp)
  return math.max(0, hp), math.max(1, maxHp)
end

-- BattleState keeps the outgoing Pokemon in shownMon while queued faint/send
-- messages play.  Read the same native presentation receipt when available so
-- gender, caught state and DVs cannot jump to the replacement one message
-- before its sprite appears.
local function presentedMon(screen, side)
  if type(screen) == "table" and type(screen.activeMon) == "function" then
    local ok, mon = pcall(screen.activeMon, screen, side)
    if ok and type(mon) == "table" then return mon end
  end
  local shown = type(screen) == "table" and screen.shownMon or nil
  if type(shown) == "table" and type(shown[side]) == "table" then
    return shown[side]
  end
  local battle = type(screen) == "table" and screen.battle or nil
  return type(battle) == "table" and battle[side] or nil
end

local function nativeGenderSymbol(screen, mon)
  if not (mon and optionToggle(screen, "battleGender", true)) then return nil end
  if type(screen) == "table" and type(screen.genderSymbol) == "function" then
    local ok, symbol = pcall(screen.genderSymbol, screen, mon)
    if ok and (symbol == "\226\153\130" or symbol == "\226\153\128") then
      return symbol
    end
  end
  if mon.gender == "male" then return "\226\153\130" end
  if mon.gender == "female" then return "\226\153\128" end
  return nil
end

local function wildBattle(screen)
  local battle = type(screen) == "table" and screen.battle or nil
  return type(battle) == "table" and battle.wild == true
end

local function speciesCaught(screen, mon)
  if not (wildBattle(screen) and type(mon) == "table") then return false end
  local species = mon.species
  local state = encounterCaught[screen]
  if not state then state = {}; encounterCaught[screen] = state end
  if state[species] ~= nil then return state[species] == true end
  -- Prefer the cartridge screen's CheckCaughtMon-equivalent.  The direct table
  -- read is only a compatibility fallback for test/older engine screens.
  if type(screen.dexCaught) == "function" then
    local ok, caught = pcall(screen.dexCaught, screen, mon)
    if ok then
      state[species] = caught == true
      return state[species]
    end
  end
  local battle = screen.battle
  local save = screen.save or (screen.game and screen.game.save)
    or (type(battle) == "table" and battle.save) or nil
  local dex = save and save.pokedex
  local caught = dex and (dex.caught or dex.owned)
  state[species] = type(caught) == "table" and caught[species] == true
  return state[species]
end

local function hpDv(dvs)
  if type(dvs) ~= "table" then return nil end
  if tonumber(dvs.hp) then return math.floor(tonumber(dvs.hp)) end
  local atk, def = tonumber(dvs.attack), tonumber(dvs.defense)
  local spd, spc = tonumber(dvs.speed), tonumber(dvs.special)
  if not (atk and def and spd and spc) then return nil end
  return (atk % 2) * 8 + (def % 2) * 4 + (spd % 2) * 2 + (spc % 2)
end

local function statusValueLines(mon, mode)
  local dvs = type(mon) == "table" and mon.dvs or nil
  local hp = hpDv(dvs)
  local atk = type(dvs) == "table" and tonumber(dvs.attack) or nil
  local def = type(dvs) == "table" and tonumber(dvs.defense) or nil
  local spd = type(dvs) == "table" and tonumber(dvs.speed) or nil
  local spc = type(dvs) == "table" and tonumber(dvs.special) or nil
  if not (hp and atk and def and spd and spc) then return nil end
  local lines = { string.format("DV %02d/%02d/%02d/%02d/%02d",
    hp, atk, def, spd, spc) }
  if mode == "full" and type(mon.statExp) == "table" then
    local values = mon.statExp
    local special = tonumber(values.special)
      or tonumber(values.specialAttack) or tonumber(values.specialDefense) or 0
    lines[#lines + 1] = string.format("SE %d/%d/%d/%d/%d",
      math.floor(tonumber(values.hp) or 0),
      math.floor(tonumber(values.attack) or 0),
      math.floor(tonumber(values.defense) or 0),
      math.floor(tonumber(values.speed) or 0), math.floor(special))
  end
  return lines
end

local function hpColor(ratio)
  if ratio <= 0.20 then return 0.95, 0.23, 0.18 end
  if ratio <= 0.50 then return 0.96, 0.72, 0.15 end
  return 0.24, 0.90, 0.46
end

local function drawGenderSymbol(symbol, x, y, scale)
  if not symbol then return 0 end
  local G = love.graphics
  -- The bundled Gen-2 font has no male/female glyphs. Drawing the Unicode
  -- characters therefore produced a thin coloured replacement rectangle on
  -- several systems. Use tiny filled pixel masks so the symbols are identical
  -- on every LÖVE/font configuration.
  local cell = math.max(1, math.floor((tonumber(scale) or 1) * 1.45 + 0.5))
  local male = symbol ~= "\226\153\128"
  local pixels
  if male then
    pixels = {
      {1,1},{2,0},{3,0},{4,0},{4,1},{4,2},
      {0,2},{1,1},{2,1},{3,2},{3,3},{2,4},{1,4},{0,3},
    }
  else
    pixels = {
      {1,0},{2,0},{0,1},{3,1},{0,2},{3,2},{1,3},{2,3},
      {1,4},{2,4},{0,5},{1,5},{2,5},{3,5},{1,6},{2,6},
    }
  end
  local function paint(px, py)
    for _, point in ipairs(pixels) do
      G.rectangle("fill", px + point[1] * cell, py + point[2] * cell,
                  cell, cell)
    end
  end
  G.setColor(0.005, 0.015, 0.025, 0.94)
  paint(x + 1, y + 1)
  if male then
    G.setColor(0.26, 0.70, 1.00, 1)
  else
    G.setColor(1.00, 0.36, 0.67, 1)
  end
  paint(x, y)
  return 6 * cell
end

local function drawCaughtIndicator(choice, cx, cy, radius)
  if choice == "off" then return end
  local G = love.graphics
  radius = math.max(4, tonumber(radius) or 5)
  if choice == "red" then
    G.setColor(0.93, 0.20, 0.18, 0.98)
  else
    G.setColor(0.56, 0.62, 0.66, 0.98)
  end
  G.circle("fill", cx, cy, radius)
  G.setColor(0.02, 0.035, 0.05, 0.98)
  G.setLineWidth(math.max(1, radius * 0.22))
  G.circle("line", cx, cy, radius)
  G.line(cx - radius, cy, cx + radius, cy)
  G.setColor(0.92, 0.98, 1.00, 1)
  G.circle("fill", cx, cy, radius * 0.34)
  G.setColor(0.02, 0.035, 0.05, 0.98)
  G.circle("line", cx, cy, radius * 0.34)
  G.setLineWidth(1)
end

local GEN1_STATUS = {
  enemy={ logicalW=162, logicalH=45, attachX=3, attachY=-2 },
  player={ logicalW=178, logicalH=58, attachX=-3, attachY=-2 },
}

local GEN1_PARTY_BALL_ASSETS = {
  alive="assets/hud/battleplate_ball.png",
  active="assets/hud/battleplate_ball_active.png",
  defeated="assets/hud/battleplate_ball_defeated.png",
  empty="assets/hud/battleplate_ball_empty.png",
}

local GEN1_STATUS_FALLBACK = {
  SLP="SLP", PSN="PSN", BRN="BRN", PAR="PAR", FRZ="FRZ",
  sleep="SLP", poison="PSN", burn="BRN", paralysis="PAR",
  frozen="FRZ",
}

local function runtimeMember(runtime, key)
  if type(runtime) ~= "table" then return nil end
  local ok, value = pcall(function() return runtime[key] end)
  if ok then return value end
  return nil
end

-- Match FloatingHud.safeInsets() from the Gen-1 provider. The scene canvas can
-- use physical pixels while LÖVE reports the safe rectangle in window pixels,
-- so convert each edge independently. Missing or sandbox-blocked APIs are a
-- valid zero-inset receipt, never a reason to retain stale dimensions.
local function viewportSafeInsets(ww, wh)
  local runtime = love
  local window = runtimeMember(runtime, "window")
  local getter = runtimeMember(window, "getSafeArea")
  local graphics = runtimeMember(runtime, "graphics")
  local getDimensions = runtimeMember(graphics, "getDimensions")
  if type(getter) ~= "function" or type(getDimensions) ~= "function" then
    return 0, 0, 0, 0
  end
  local okWindow, windowW, windowH = pcall(getDimensions)
  local okSafe, x, y, width, height = pcall(getter)
  if not (okWindow and okSafe and tonumber(windowW) and tonumber(windowH)
      and windowW > 0 and windowH > 0 and tonumber(x) and tonumber(y)
      and tonumber(width) and tonumber(height) and width > 0 and height > 0) then
    return 0, 0, 0, 0
  end
  local sx, sy = ww / windowW, wh / windowH
  return math.max(0, x * sx), math.max(0, y * sy),
    math.max(0, (windowW - x - width) * sx),
    math.max(0, (windowH - y - height) * sy)
end

local function gen1BaseUiScale(ww, wh)
  local fit = math.max(1, math.floor(math.min(ww / 160, wh / 144)))
  return math.max(1, math.min(3, math.floor(fit * .5 + .5))) * .9
end

-- Reproduce the actual Gen-1 status-card scale contract.  Gen 1 first derives
-- the integer Game-Boy fit scale, applies the default 0.9 HUD option and the
-- reviewed 1.22 status gain, then caps each complete card to 24.5% of a
-- landscape viewport (40% in portrait) and 24% of its height.  The former
-- Crystal prototype copied only the final 1024px measurements and made the
-- player card 272px wide, so it could never match Kanto at other sizes.
local function gen1StatusScale(ww, wh, logicalW, logicalH)
  local base = gen1BaseUiScale(ww, wh)
  local scale = base * 1.22
  local widthShare = ww < wh and .40 or .245
  scale = math.min(scale, (ww * widthShare) / logicalW,
    (wh * .24) / logicalH)
  return math.max(.42, scale), base
end

-- Keep Crystal's shared ORAS furniture at the same physical viewport shares
-- as the Gen1 provider. Fixed desktop-pixel caps made the cards and command
-- surface progressively smaller at 1440p/4K even though the voxel scene grew.
local function layoutMetrics(ww, wh)
  ww, wh = tonumber(ww) or 0, tonumber(wh) or 0
  local margin = math.max(12, math.min(ww, wh) * 0.018)
  -- Port the reviewed Kanto ORAS proportions instead of scaling the old
  -- full-width Gen-2 prototype. 162x45 and 178x58 are the production logical
  -- status-card sizes; the 720-wide bottom dock is shared with Kanto too.
  -- Kanto reaches its reviewed physical card size at the common 1024x720
  -- battle viewport. Crystal previously waited until 1280px width, leaving
  -- both cards permanently at the 80% floor in 1024x768 windows. Keep the
  -- same height response and mobile floor, but use Kanto's desktop width seat.
  local ui = math.max(0.80, math.min(2.20, math.min(ww / 1024, wh / 720)))
  local enemyScale, statusBase = gen1StatusScale(ww, wh,
    GEN1_STATUS.enemy.logicalW, GEN1_STATUS.enemy.logicalH)
  local playerScale = gen1StatusScale(ww, wh,
    GEN1_STATUS.player.logicalW, GEN1_STATUS.player.logicalH)
  return {
    margin = margin,
    statusBaseScale = statusBase,
    enemyStatus = {
      w=GEN1_STATUS.enemy.logicalW * enemyScale,
      h=GEN1_STATUS.enemy.logicalH * enemyScale,
      scale=enemyScale, logicalW=GEN1_STATUS.enemy.logicalW,
      logicalH=GEN1_STATUS.enemy.logicalH,
    },
    playerStatus = {
      w=GEN1_STATUS.player.logicalW * playerScale,
      h=GEN1_STATUS.player.logicalH * playerScale,
      scale=playerScale, logicalW=GEN1_STATUS.player.logicalW,
      logicalH=GEN1_STATUS.player.logicalH,
    },
    command = {
      w = math.min(ww - margin * 2, 720 * ui),
      h = math.min(wh * 0.31, 220 * ui),
    },
    moves = {
      w = math.min(ww - margin * 2, 720 * ui),
      h = math.min(wh * 0.31, 220 * ui),
    },
  }
end

M.layoutMetrics = layoutMetrics

-- Reproduce Kanto's reviewed screen-dock contract exactly. The Gen-1 HUD is
-- authored in logical pixels, fitted by one whole-surface scale, and visually
-- touches the framebuffer bottom; it does not reserve a second physical inset.
-- Drawing Gen-2's individual PNGs directly in framebuffer pixels made the
-- cluster sit about 23 px too high at 1024x768 even when every source asset was
-- correct. Return the logical plane and its scale so paint and SMART share the
-- same geometry.
local function gen1ScreenDockRect(ww, wh, logicalH)
  local safe = math.max(7, math.floor(math.min(ww, wh) * .024))
  local canvasPad = 5
  local insetLeft, _, insetRight, insetBottom = viewportSafeInsets(ww, wh)
  local totalAvailable = math.max(1,
    ww - insetLeft - insetRight - safe * 2)
  local safeHeight = math.max(1, wh - insetBottom - safe * 2)
  local uiScale = gen1BaseUiScale(ww, wh)
  local heightCap = math.max(.25,
    (safeHeight * .31) / (logicalH + canvasPad * 2))
  local scale = math.min(uiScale, heightCap)
  local padPixels = canvasPad * scale
  local contentAvailable = math.max(1, totalAvailable - padPixels * 2)
  local available = math.min(contentAvailable, 720 * scale)
  local left = insetLeft + safe + (totalAvailable - available) * .5
  local logicalW = available / scale
  local height = logicalH * scale
  return {
    left, wh - height, available, height, bottomInset=0,
  }, scale, logicalW, logicalH
end

local function commandDockRect(ww, wh, layout)
  return gen1ScreenDockRect(ww, wh, 156)
end

M.commandDockRect = commandDockRect

-- Read-only final drawable receipt for diagnostics/native pointer QA.
function M.megaCommandRect(screen)
  local mega=V.Gen2MegaBridge
  return mega and mega.hitRect(screen) or nil
end

-- The move grid is the same centred, bottom-owned surface as Kanto's move
-- canvas.  Keep this geometry pure and shared: drawMoves paints exactly this
-- rectangle and SMART reserves exactly this rectangle, so a future responsive
-- size change cannot leave the camera protecting a stale right-docked area.
local function moveDockRect(ww, wh, layout)
  return gen1ScreenDockRect(ww, wh, 222)
end

M.moveDockRect = moveDockRect

-- Gen-1's screen-style message plate is a 288x64 logical surface. Crystal's
-- old 58%-wide/12%-high shortcut happened to look plausible at one desktop
-- size but stayed half-height on phones and after rotation. Port the complete
-- Kanto rule: one UI scale, real left/right safe area, a 23% vertical cap and
-- a physical-bottom anchor. This pure rectangle is shared by paint and SMART.
local function touchStartSelectTop(ww, wh)
  if not (TouchControls and type(TouchControls.layout) == "function"
      and type(TouchControls.visible) == "function") then return nil end
  local okVisible, visible = pcall(TouchControls.visible, TouchControls)
  if not okVisible or visible ~= true then return nil end
  local okLayout, layout = pcall(TouchControls.layout, TouchControls)
  if not (okLayout and type(layout) == "table") then return nil end
  local windowW, windowH = ww, wh
  local G = love and love.graphics
  if G and type(G.getDimensions) == "function" then
    local okDimensions, w, h = pcall(G.getDimensions)
    if okDimensions and tonumber(w) and tonumber(h) and w > 0 and h > 0 then
      windowW, windowH = w, h
    end
  end
  local sy = wh / math.max(1, windowH)
  local top = nil
  for _, name in ipairs({ "select", "start" }) do
    local zone = layout[name]
    if type(zone) == "table" and tonumber(zone.cy) and tonumber(zone.w) then
      local candidate = (zone.cy - zone.w * .58) * sy
      top = top and math.min(top, candidate) or candidate
    end
  end
  return top
end

M.touchStartSelectTop = touchStartSelectTop

local function messageDockRect(ww, wh)
  local logicalW, logicalH = 288, 64
  local insetLeft, _, insetRight, insetBottom = viewportSafeInsets(ww, wh)
  local safe = math.max(7, math.floor(math.min(ww, wh) * .024))
  local left = insetLeft + safe
  local right = insetRight + safe
  local availableW = math.max(1, ww - left - right)
  local availableH = math.max(1, wh - insetBottom - safe)
  local drawScale = math.max(.35, math.min(
    gen1BaseUiScale(ww, wh),
    availableW / logicalW,
    (availableH * .23) / logicalH))
  local w, h = logicalW * drawScale, logicalH * drawScale
  local y = wh - h
  local controlTop = touchStartSelectTop(ww, wh)
  if controlTop then
    local gutter = math.max(6, math.floor(math.min(ww, wh) * .015))
    y = math.max(safe, math.min(y, controlTop - gutter - h))
  end
  return { left + (availableW - w) * .5, y, w, h,
    bottomInset=0 }, drawScale, logicalW, logicalH
end

M.messageDockRect = messageDockRect

-- SMART must avoid the pixels the command cluster actually paints, not the
-- unused top half of Gen 2's logical layout dock. Kanto obtains this exact
-- distinction from its padded off-screen command canvas. The source art is
-- bounded by two 32%-high rows plus their gap; include the hand cursor's lead
-- above FIGHT and keep the full dock width as a conservative horizontal bound.
local function commandCameraRect(ww, wh, layout)
  layout = layout or layoutMetrics(ww, wh)
  local dock, scale, logicalW, logicalH = commandDockRect(ww, wh, layout)
  local actionGap = math.max(2, math.min(5, logicalW * .012)) * scale
  local cursorLead = 20 * .82 * scale
  local artHeight = math.min(dock[4],
    logicalH * .64 * scale + actionGap + cursorLead)
  return { dock[1], dock[2] + dock[4] - artHeight,
           dock[3], artHeight, bottomInset=dock.bottomInset }
end

M.commandCameraRect = commandCameraRect

local function rectanglesHit(a, b, padding)
  padding = tonumber(padding) or 0
  return a[1] < b[1] + b[3] + padding
     and a[1] + a[3] + padding > b[1]
     and a[2] < b[2] + b[4] + padding
     and a[2] + a[4] + padding > b[2]
end

-- BattleScene's `hull` is deliberately a conservative 3-D safety prism. It
-- is wider/taller than the pixels of the standing battler so a moving camera
-- cannot clip a model, but it must not be mistaken for the visible sprite
-- when seating a head-owned HUD card.  Use the rendered head-to-foot band for
-- UI collision while retaining the conservative hull's horizontal coverage.
local function statusActorRect(actor)
  local hull = type(actor) == "table" and actor.hull or nil
  local head = type(actor) == "table" and actor.head or nil
  local foot = type(actor) == "table" and actor.foot or nil
  if not (type(hull) == "table" and tonumber(hull[1])
      and tonumber(hull[2]) and tonumber(hull[3]) and tonumber(hull[4])) then
    return nil
  end
  local top = type(head) == "table" and tonumber(head.y) or nil
  local bottom = type(foot) == "table" and tonumber(foot.y) or nil
  if not (top and bottom) then return hull end
  if bottom < top then top, bottom = bottom, top end
  return { hull[1], top, hull[3], math.max(1, bottom - top) }
end

-- `head` is semantic, while a reflected mobile scene can temporarily publish
-- its numeric Y below `foot` until the final canvas presentation.  The actual
-- visible top is therefore the uppermost exact endpoint/hull edge, not blindly
-- `head.y`. This leaves ordinary projections unchanged and fixes the enemy
-- card that otherwise sat across the middle of the presented Pokemon.
local function statusVisualTop(actor)
  if type(actor) ~= "table" then return nil end
  local values = {}
  local head, foot, hull = actor.head, actor.foot, actor.hull
  if type(head) == "table" and tonumber(head.y) then
    values[#values + 1] = tonumber(head.y)
  end
  if type(foot) == "table" and tonumber(foot.y) then
    values[#values + 1] = tonumber(foot.y)
  end
  if type(hull) == "table" and tonumber(hull[2]) then
    values[#values + 1] = tonumber(hull[2])
  end
  if #values == 0 then return nil end
  local top = values[1]
  for index = 2, #values do top = math.min(top, values[index]) end
  return top
end

local function statusHeadX(side, headX, w, sideGap, attachX)
  -- Mobile opponents belong diagonally above/right of the visible head.
  -- The desktop's centred attachment remains unchanged; both painting and
  -- camera safety call this same helper before their viewport clamps.
  local os = CanvasPresentation and CanvasPresentation.OS
  if side == "enemy" and (os == "iOS" or os == "Android") then
    return headX + sideGap + attachX
  end
  return headX - w * .5 + attachX
end

local function statusViewportKey(ww, wh)
  return table.concat({ tostring(ww), tostring(wh) }, "|")
end

local function statusAttachmentState(screen, ww, wh)
  local viewportKey = statusViewportKey(ww, wh)
  local state = statusAttachments[screen]
  if not state or state.viewportKey ~= viewportKey then
    state = { viewportKey=viewportKey }
    statusAttachments[screen] = state
  end
  return state
end

local function statusActionActive(screen)
  if type(screen) ~= "table" then return false end
  if screen.anim ~= nil or screen.pendingAfterAnim ~= nil
      or screen.afterSendOut ~= nil then return true end
  local phase = tostring(screen.phase or "")
  return phase == "intro" or phase == "resolving" or phase == "locked-in"
    -- These engine-owned questions keep the same battlers on stage.  Their
    -- camera/idle motion must not make an already reviewed status attachment
    -- chase the projected head while the player is reading the prompt.
    or phase == "ask-next-mon" or phase == "ask-shift"
end

local function heldStatusRect(screen, mon, side, ww, wh, w, h)
  -- Freeze a reviewed attachment only while the actor is moving. The first
  -- send-out frames can project a tiny/growing model; retaining that seat
  -- after the animation ends leaves the HP card stranded near a screen corner.
  -- On an idle command frame reacquire the current, full-size model head.
  if not statusActionActive(screen) then return nil end
  local state = statusAttachments[screen]
  if not state or state.viewportKey ~= statusViewportKey(ww, wh) then
    return nil
  end
  local previous = state[side]
  local rect = previous and previous.rect
  if previous and previous.mon == mon
      and previous.battle == (screen and screen.battle)
      and type(rect) == "table"
      and tonumber(rect[1]) and tonumber(rect[2])
      and tonumber(rect[3]) == tonumber(w)
      and tonumber(rect[4]) == tonumber(h) then
    return rect
  end
  return nil
end

local function projectedStatusRect(screen, mon, side, projection, ww, wh, w, h)
  local state = statusAttachmentState(screen, ww, wh)
  local held = heldStatusRect(screen, mon, side, ww, wh, w, h)
  if held then return held end

  local visual = type(projection) == "table"
    and type(projection.actorVisuals) == "table"
    and projection.actorVisuals[side] or nil
  local head = type(visual) == "table" and visual.head or nil
  local hull = type(visual) == "table" and visual.hull or nil
  if not (type(head) == "table" and tonumber(head.x) and tonumber(head.y)
      and type(hull) == "table" and tonumber(hull[1]) and tonumber(hull[2])
      and tonumber(hull[3]) and tonumber(hull[4])) then return nil end
  local layout = layoutMetrics(ww, wh)
  local status = side == "enemy" and layout.enemyStatus or layout.playerStatus
  local definition = GEN1_STATUS[side] or GEN1_STATUS.player
  local baseScale = tonumber(layout.statusBaseScale) or 1
  local attachX = (tonumber(definition.attachX) or 0) * baseScale
  local attachY = (tonumber(definition.attachY) or 0) * baseScale
  local margin = layout.margin
  local minX, minY = margin, margin
  local maxX, maxY = math.max(minX, ww-margin-w), math.max(minY, wh-margin-h)
  local gap = math.max(8, math.min(ww, wh) * .012)
  -- This is Kanto's reviewed clearance contract.  The old Crystal prototype
  -- used an arbitrary double collision gap, which visibly detached the card
  -- from small heads and still let large actors push it into a corner.
  local clearance = math.max(8,
    5 * (tonumber(status.scale) or 1) + 18 * baseScale * .30)
  local sideGap = math.max(8, 5 * baseScale)
  -- Primary contract: anchor at the actually rendered head, with the mobile
  -- opponent's explicit upper-right offset (desktop remains centred).
  -- Player and opponent cards own separate screen halves. Without this guard,
  -- a camera orbit could put both perfectly valid head projections on the
  -- same side and SMART would reject the whole composition.
  -- Gen 1 uses the collision padding itself as the semantic-half divider.
  -- A second 1.5 multiplier made the Crystal cards drift horizontally even
  -- though their owner/head receipt and dimensions were already correct.
  local halfGap = gap
  local function semanticX(px)
    if side == "player" then
      local upper = math.max(minX, math.min(maxX, ww * 0.5 - halfGap - w))
      return math.max(minX, math.min(upper, px))
    end
    local lower = math.min(maxX, math.max(minX, ww * 0.5 + halfGap))
    return math.max(lower, math.min(maxX, px))
  end
  local function clampY(py)
    return math.max(minY, math.min(maxY, py))
  end

  local visualTop = statusVisualTop(visual) or head.y

  local x = semanticX(statusHeadX(side, head.x, w, sideGap, attachX))
  local y = clampY(visualTop - h - clearance + attachY)

  local function hitsActor(px, py)
    for _, actorSide in ipairs({ "player", "enemy" }) do
      local actor = projection.actorVisuals[actorSide]
      local actorRect = statusActorRect(actor)
      if actorRect and rectanglesHit({px,py,w,h}, actorRect, gap) then
        return true
      end
    end
    return false
  end
  if hitsActor(x, y) then
    local semanticCorner = semanticX(side == "player" and minX or maxX)
    local outsideX = side == "player" and (hull[1] - sideGap - w)
                                          or (hull[1] + hull[3] + sideGap)
    local outwardX = side == "player" and (head.x - w * 0.78)
                                         or (head.x - w * 0.22)
    local middleY = clampY(head.y - h * 0.52 + attachY)
    local candidates = {
      { semanticX(statusHeadX(side, head.x, w, sideGap, attachX)),
        clampY(visualTop-h-clearance + attachY) },
      { semanticX(outwardX + attachX),
        clampY(visualTop-h-clearance + attachY) },
      { semanticX(outsideX + attachX), middleY },
      { semanticX((side == "player" and minX or maxX) + attachX), middleY },
      { semanticCorner, clampY(minY + attachY) },
    }
    local found = false
    for _, candidate in ipairs(candidates) do
      if not hitsActor(candidate[1], candidate[2]) then
        x, y = candidate[1], candidate[2]
        found = true
        break
      end
    end
    -- Never dock a battler card along the bottom edge: that was the apparent
    -- 2D fallback and also collided with the command surface. A top semantic
    -- corner is the deterministic fail-open seat if every head seat is busy.
    if not found then x, y = semanticCorner, minY end
  end
  -- Match the production Gen-1 owner contract: acquire from the exact rendered
  -- head while idle, with no interpolation. statusActionActive above freezes
  -- this reviewed seat across attack poses, HP chase and transient missing
  -- projections; a real Pokemon or viewport change starts a fresh owner.
  local rect = { x, y, w, h }
  state[side] = {
    mon=mon, anchorOwner=mon, battle=screen and screen.battle,
    canvas=visual.canvas, rect=rect, visible=false,
  }
  return rect
end

local function drawGen1CompactHpBar(x, y, width, height, ratio)
  local G = love.graphics
  ratio = math.max(0, math.min(1, tonumber(ratio) or 0))
  G.setColor(.02, .04, .05, .88)
  G.rectangle("fill", x, y, width, height, 2, 2)
  G.setColor(.82, .90, .92, .92)
  G.rectangle("line", x, y, width, height, 2, 2)
  local r, g, b = hpColor(ratio)
  G.setColor(r, g, b, 1)
  local fill = math.max(0, (width - 2) * ratio)
  if fill > 0 then
    G.rectangle("fill", x + 1, y + 1, fill, height - 2, 1, 1)
  end
end

local function statusPartyForSide(screen, side)
  local battle = type(screen) == "table" and screen.battle or nil
  if type(battle) ~= "table" then return nil end
  if side == "enemy" then
    -- A wild encounter owns one opponent, not a fake six-slot receipt.
    if battle.wild == true then return nil end
    return type(battle.enemyParty) == "table" and battle.enemyParty or nil
  end
  if type(battle.party) == "table" then return battle.party end
  local save = screen.save or (screen.game and screen.game.save)
  return type(save) == "table" and type(save.party) == "table"
    and save.party or nil
end

local function statusPartyBallState(screen, side, slot, activeMon)
  local party = statusPartyForSide(screen, side)
  local mon = type(party) == "table" and party[slot] or nil
  if not mon then return "empty" end
  local hp = tonumber(mon.hp) or 0
  if mon == activeMon and hp > 0 then return "active" end
  return hp > 0 and "alive" or "defeated"
end

local function drawGen1PartyReceipt(screen, side, activeMon, logicalW)
  if type(statusPartyForSide(screen, side)) ~= "table" then return false end
  local source = assetImage(GEN1_PARTY_BALL_ASSETS.alive)
  if not source then return false end
  local G = love.graphics
  local iw, ih = source:getDimensions()
  local iconScale = (1 / 8) * .72
  local iconW, iconH = iw * iconScale, ih * iconScale
  local gap = 2
  local rowW = iconW * 6 + gap * 5
  local x = math.floor((logicalW - rowW) * .5 + .5)
  local y = side == "player" and 35 or 29
  for slot = 1, 6 do
    local state = statusPartyBallState(screen, side, slot, activeMon)
    local ball = assetImage(GEN1_PARTY_BALL_ASSETS[state])
    if ball then
      local bx = x + (slot - 1) * (iconW + gap)
      if state == "active" then
        local accent = hudPalette().accent or { .28, .88, 1 }
        G.setColor(accent[1], accent[2], accent[3], .40)
        G.circle("fill", bx + iconW * .5, y + iconH * .5, iconW * .59)
      end
      G.setColor(1, 1, 1, 1)
      G.draw(ball, bx, y, 0, iconScale, iconScale)
    end
  end
  return true
end

local function drawGen1CompactStatusCard(screen, mon, side, logicalW, logicalH)
  local G = love.graphics
  local palette = hudPalette()
  local accent = palette.accent or palette.frame or { .28, .88, 1 }
  local hp, maxHp = shownHp(screen, side, mon)
  local ratio = hp / math.max(1, maxHp)
  local gender = nativeGenderSymbol(screen, mon)
  local nameScale = side == "player" and .82 or .78
  local levelScale = .72
  local genderScale = nameScale * .82
  local levelText = "Lv." .. tostring(math.floor(tonumber(mon.level) or 1))
  local levelW = hudTextWidth(levelText) * levelScale
  local levelX = logicalW - 7 - levelW
  local genderRoom = gender and (8 * genderScale + 2) or 0
  local nameX, nameY = 7, 4
  local nameMax = math.max(16, (levelX-nameX-genderRoom-3)/nameScale)
  local name = fitHudText(monName(screen, mon), nameMax)

  -- Literal Kanto ORAS compact ribbon, authored in the same 162x45 / 178x58
  -- logical coordinate system.  Scaling the entire surface keeps every inner
  -- row and border at the exact same proportion in both generations.
  G.setColor(0, 0, 0, .48)
  G.polygon("fill", 4,4, logicalW-2,4,
    logicalW-9,logicalH, 0,logicalH)
  G.setColor(.012, .038, .055, .91)
  G.polygon("fill", 1,1, logicalW-6,1,
    logicalW-12,logicalH-3, 0,logicalH-3)
  G.setColor(accent[1], accent[2], accent[3], .78)
  G.setLineWidth(1)
  G.line(7, logicalH-3, logicalW-13, logicalH-3)

  drawHudText(name, nameX, nameY, nameScale, 1)
  local genderX = nameX + hudTextWidth(name) * nameScale + 2
  if gender and genderX + 8 * genderScale < levelX then
    drawGenderSymbol(gender, genderX, nameY + .5, genderScale)
  end
  drawHudText(levelText, levelX, nameY + .5, levelScale, 1)

  drawHudText("HP", 7, 17, .62, 1)
  drawGen1CompactHpBar(27, 17.5, logicalW-39, 7, ratio)

  if side == "player" then
    local status = mon.status and
      (GEN1_STATUS_FALLBACK[mon.status] or cleanText(mon.status)) or nil
    local infoY = 28
    if status then drawHudText(status, 7, infoY, .58, 1) end
    local numbers = tostring(math.floor(hp)) .. "/" .. tostring(math.floor(maxHp))
    drawHudText(numbers, logicalW-8-hudTextWidth(numbers)*.68,
      infoY, .68, 1)
    local expMode = expBarChoice(screen)
    if expMode ~= "off" then
      local exp = math.max(0, math.min(1,
        (tonumber(screen.shownExp) or 0) / 64))
      local expX, expY, expW = 22, logicalH-7, logicalW-34
      drawHudText("EXP", 7, expY-1.5, .40, .90)
      G.setColor(.01, .025, .04, .96)
      G.rectangle("fill", expX, expY, expW, 3, 1, 1)
      if expMode == "black" then
        G.setColor(.01, .02, .03, 1)
      else
        G.setColor(.11, .67, 1, 1)
      end
      G.rectangle("fill", expX, expY, expW*exp, 3, 1, 1)
      if expMode == "blue" then
        G.setColor(.70, .93, 1, .72)
        G.rectangle("fill", expX, expY, expW*exp, 1)
      end
    end
  elseif wildBattle(screen) then
    local mode = wildDvChoice(screen)
    if mode ~= "off" then
      local lines = statusValueLines(mon, mode)
      if lines then
        local firstY = logicalH - (#lines > 1 and 18 or 13)
        for index, line in ipairs(lines) do
          drawHudText(fitHudText(line, (logicalW-16)/.43), 7,
            firstY + (index-1)*5, .43, .90)
        end
      end
    end
  end

  drawGen1PartyReceipt(screen, side, mon, logicalW)
  if side == "enemy" and speciesCaught(screen, mon) then
    drawCaughtIndicator(caughtIndicatorChoice(screen), 9, 14, 4)
  end
  -- One thin edition-coloured outline, identical to Kanto's status border.
  themedColor(G, "frame", 1)
  G.setLineWidth(1)
  G.polygon("line", 1,1, logicalW-6,1,
    logicalW-12,logicalH-3, 0,logicalH-3)
  G.setLineWidth(1)
end

local function drawBattlerHud(screen, mon, side, ww, wh, projection)
  if not mon then return nil end
  local G = love.graphics
  local layout = layoutMetrics(ww, wh)
  local status = side == "enemy" and layout.enemyStatus or layout.playerStatus
  local w, h = status.w, status.h
  local margin = layout.margin
  local exact = projectedStatusRect(screen, mon, side, projection, ww, wh, w, h)
  local centerX = side == "enemy" and ww * .75 or ww * .25
  local x = exact and exact[1]
    or math.max(margin, math.min(ww-margin-w, centerX-w*.5))
  local y = exact and exact[2] or margin
  local state = statusAttachmentState(screen, ww, wh)
  local entry = state[side] or {}
  if entry.mon ~= mon or entry.battle ~= (screen and screen.battle) then
    entry = {}
  end
  local hp, maxHp = shownHp(screen, side, mon)
  entry.mon = mon
  entry.anchorOwner = entry.anchorOwner or mon
  entry.battle = screen and screen.battle
  entry.canvas = type(projection) == "table"
    and type(projection.actorVisuals) == "table"
    and type(projection.actorVisuals[side]) == "table"
    and projection.actorVisuals[side].canvas or entry.canvas
  -- The deterministic corner is paint-only while the 3D actor has not yet
  -- produced a valid head projection.  Never persist it as the attachment:
  -- the next frame must still be allowed to acquire the real head seat.
  entry.rect = exact and { x, y, w, h } or nil
  entry.visible = true
  entry.hp, entry.maxHp = hp, maxHp
  state[side] = entry
  G.push()
  G.translate(x, y)
  G.scale(status.scale, status.scale)
  drawGen1CompactStatusCard(screen, mon, side,
    status.logicalW, status.logicalH)
  G.pop()
  return { x, y, w, h }
end

-- Gold presents the completed battle Canvas by scaling it to the current
-- drawable.  Retina/iOS commonly makes that Canvas twice the size of the
-- LÖVE-unit target. Actor heads are projected in Canvas pixels, while this
-- HUD compatibility path paints on the final target; consuming the raw
-- coordinates therefore clamps both cards to a remote screen edge. MAP paints
-- this HUD into the still-unpresented scene Canvas: its pixels are pre-flipped
-- by beginBattle2D, so its requested coordinates are already FINAL/upright
-- coordinates. Convert the source actor receipt through the same presentation
-- receipt before choosing a card seat. Direct final-target fallbacks pass no
-- receipt only when their input is already in final-target coordinates.
local function targetStatusProjection(projection, ww, wh, receipt, inScene)
  if type(projection) ~= "table" or type(projection.actorVisuals) ~= "table"
      or not (tonumber(ww) and tonumber(wh) and ww > 0 and wh > 0) then
    return projection
  end
  local sourceW = tonumber(projection.viewportW) or tonumber(projection.pw)
  local sourceH = tonumber(projection.viewportH) or tonumber(projection.ph)
  if not (sourceW and sourceH and sourceW > 0 and sourceH > 0) then
    for _, visual in pairs(projection.actorVisuals) do
      if type(visual) == "table" then
        sourceW = sourceW or tonumber(visual.viewportW)
        sourceH = sourceH or tonumber(visual.viewportH)
      end
      if sourceW and sourceH then break end
    end
  end
  if not (sourceW and sourceH and sourceW > 0 and sourceH > 0) then
    return projection
  end
  local sx, sy = ww / sourceW, wh / sourceH
  receipt = projection.presentationReceipt or receipt
  local orient = projection.coordinateSpace ~= "final-target"
    and (inScene == true or projection.coordinateSpace == "scene-canvas")
    and type(receipt) == "table"
    and CanvasPresentation ~= nil
  if math.abs(sx - 1) < 1e-9 and math.abs(sy - 1) < 1e-9
      and not orient then
    return projection
  end
  local function pointX(x)
    x = x * sx
    if orient and type(CanvasPresentation.battlePointX) == "function" then
      local ok, value = pcall(CanvasPresentation.battlePointX,
        x, ww, receipt)
      if ok and tonumber(value) then x = value end
    end
    return x
  end
  local function pointY(y)
    y = y * sy
    if orient and type(CanvasPresentation.battlePointY) == "function" then
      local ok, value = pcall(CanvasPresentation.battlePointY,
        y, wh, receipt)
      if ok and tonumber(value) then y = value end
    end
    return y
  end
  local function rectX(x, w)
    x, w = x * sx, w * sx
    if orient and type(CanvasPresentation.battleRectX) == "function" then
      local ok, value = pcall(CanvasPresentation.battleRectX,
        x, w, ww, receipt)
      if ok and tonumber(value) then x = value end
    end
    return x, w
  end
  local function rectY(y, h)
    y, h = y * sy, h * sy
    if orient and type(CanvasPresentation.battleRectY) == "function" then
      local ok, value = pcall(CanvasPresentation.battleRectY,
        y, h, wh, receipt)
      if ok and tonumber(value) then y = value end
    end
    return y, h
  end
  local converted = {}
  for key, value in pairs(projection) do converted[key] = value end
  converted.viewportW, converted.viewportH = ww, wh
  converted.coordinateSpace = "final-target"
  converted.presentationReceipt = nil
  if converted.pw ~= nil then converted.pw = ww end
  if converted.ph ~= nil then converted.ph = wh end
  converted.actorVisuals = {}
  for side, visual in pairs(projection.actorVisuals) do
    if type(visual) ~= "table" then
      converted.actorVisuals[side] = visual
    else
      local copy = {}
      for key, value in pairs(visual) do copy[key] = value end
      for _, key in ipairs({ "head", "foot" }) do
        local point = visual[key]
        if type(point) == "table" and tonumber(point.x) and tonumber(point.y) then
          local nextPoint = {}
          for field, value in pairs(point) do nextPoint[field] = value end
          nextPoint.x, nextPoint.y = pointX(point.x), pointY(point.y)
          copy[key] = nextPoint
        end
      end
      local hull = visual.hull
      if type(hull) == "table" and tonumber(hull[1]) and tonumber(hull[2])
          and tonumber(hull[3]) and tonumber(hull[4]) then
        local hx, hw = rectX(hull[1], hull[3])
        local hy, hh = rectY(hull[2], hull[4])
        copy.hull = { hx, hy, hw, hh }
      end
      converted.actorVisuals[side] = copy
    end
  end
  return converted
end

-- Read-only QA receipt from the actual paint path. Tests and diagnostics must
-- not recalculate a head seat independently, because that used to let a moving
-- attack pose pass while the visibly painted card jumped.
function M.statusAttachmentReceipt(screen, side)
  side = side == "player" and "player" or "enemy"
  local state = type(screen) == "table" and statusAttachments[screen] or nil
  local entry = state and state[side] or nil
  local rect = entry and entry.rect or nil
  if not (entry and type(rect) == "table") then return nil end
  return {
    schema = "voxel-ascendant/gen2-status-paint/v1",
    visible = entry.visible == true,
    screen = screen,
    battle = screen.battle,
    side = side,
    mon = entry.mon,
    owner = entry.mon,
    anchorOwner = entry.anchorOwner,
    canvas = entry.canvas,
    viewportKey = state.viewportKey,
    rect = { rect[1], rect[2], rect[3], rect[4] },
    hp = entry.hp,
    maxHp = entry.maxHp,
  }
end

local function buttonIcon(kind, x, y, r, selected)
  local G = love.graphics
  local line = math.max(2, r * 0.10)
  G.setLineWidth(line)
  if selected then
    G.setColor(1, 1, 1, 0.20)
    G.circle("fill", x, y, r * 1.26)
  end
  G.setColor(1, 1, 1, 0.98)
  G.circle("line", x, y, r)
  local q = r * 0.52
  if kind == "square" then
    G.rectangle("line", x - q, y - q, q * 2, q * 2, q * 0.12, q * 0.12)
  elseif kind == "circle" then
    G.circle("line", x, y, q)
  elseif kind == "cross" then
    G.line(x - q, y - q, x + q, y + q)
    G.line(x + q, y - q, x - q, y + q)
  elseif kind == "triangle" then
    G.polygon("line", x, y - q * 1.1, x - q, y + q * 0.8, x + q, y + q * 0.8)
  end
end

local CHOICES = {
  { index = 1, kind = "triangle", label = "FIGHT", key = "UP",    dx =  0, dy = -1 },
  { index = 4, kind = "circle",   label = "RUN",   key = "RIGHT", dx =  1, dy = 0 },
  { index = 3, kind = "square",   label = "PACK",  key = "LEFT",  dx = -1, dy = 0 },
  { index = 2, kind = "cross",    label = "PKMN",  key = "DOWN",  dx =  0, dy = 1 },
}

commandReady = function(screen)
  if type(screen) ~= "table" or type(screen.battle) ~= "table" then return false end
  local phase = tostring(screen.phase or "")
  if phase == "moves" or phase == "submenu" or phase == "done" or phase == "evolving"
      or phase == "locked-in" then
    return false
  end
  -- IMPORTANT: Gold can already have phase == menu while a message/text box
  -- still owns A/B for advancing dialogue. Never show/arm direct commands until
  -- every text/animation gate is clear, or Cross/Circle can become PACK/RUN on
  -- the same press that was meant to dismiss text.
  if screen.message or screen.anim or screen.hpAnim or screen.faintSlide
      or screen.trainerSlide or screen.statsBoxMon then
    return false
  end
  if (tonumber(screen.messageTimer) or 0) > 0 then return false end
  local battle = screen.battle
  if battle.over then return false end
  local queue = screen.queue
  if type(queue) == "table" and #queue > 0 then return false end
  if phase == "menu" then return true end
  -- Gold can spend one fixed-step in intro/resolving immediately before it
  -- writes phase=menu. Keeping the controller panel up through that seam
  -- prevents the replacement HUD from blinking out even though the battle is
  -- already waiting for the next player command visually. Inputs still only
  -- ACTIVATE while phase==menu, so this is presentation-only fail-open logic.
  return phase == "intro" or phase == "resolving" or phase == ""
end

local function drawCommandDiamond(screen, ww, wh)
  local G = love.graphics
  -- Keep this deliberately conspicuous. v0.2.30's compact dock could be easy
  -- to miss (or disappear for the one-frame resolving->menu seam), defeating
  -- the point of replacing Gold's command box with a controller-native UI.
  local w = math.min(ww * 0.46, 620)
  -- v0.2.75: reserve real vertical lanes for header, command diamond and
  -- footer.  The old 43%-high panel put PACK/DOWN at ~88-96% of the panel
  -- while the stick hint already lived at ~94%, so the two text blocks could
  -- only overlap on shorter/wider windows.  A slightly taller panel plus a
  -- body-relative icon size keeps every label inside its own lane.
  local h = math.min(wh * 0.52, 430)
  local margin = math.max(18, wh * 0.025)
  local x = ww - w - margin
  local y = wh - h - margin
  local r = math.max(16, math.min(32, wh * 0.030))
  panel(x, y, w, h, r, 0.84)

  local titleFont = font(math.max(19, math.min(wh * 0.027, w * 0.066)))
  local labelFont = font(math.max(13, math.min(wh * 0.019, h * 0.075)))
  local hintFont = font(math.max(9, math.min(wh * 0.013, h * 0.050)))
  if titleFont then G.setFont(titleFont) end
  G.setColor(1, 1, 1, 0.98)
  G.print("BATTLE COMMANDS", x + w * 0.065, y + h * 0.065)
  local shortcutMode = battleShortcutMode()
  if hintFont then G.setFont(hintFont) end
  G.setColor(1, 1, 1, 0.62)
  local subtitle = shortcutMode == "native" and "NATIVE MENU INPUT"
    or (shortcutMode == "dpad" and "D-PAD / ARROWS" or "FACE BUTTONS")
  G.print(subtitle, x + w * 0.068, y + h * 0.155)

  local cx = x + w * 0.53
  -- The icon CENTRES occupy only the middle 38% vertically.  Labels and their
  -- direction hints then finish well above the dedicated footer lane.
  local cy = y + h * 0.47
  local spreadX = w * 0.285
  local spreadY = h * 0.16
  local iconR = math.max(15, math.min(32, wh * 0.030, h * 0.072))
  local selected = tostring(screen.phase or "") == "menu"
    and (tonumber(screen.menuIndex) or 1) or -1

  for _, item in ipairs(CHOICES) do
    local bx = cx + item.dx * spreadX
    local by = cy + item.dy * spreadY
    local on = selected == item.index
    if shortcutMode == "face" then
      buttonIcon(item.kind, bx, by, iconR, on)
    else
      -- D-pad/native modes deliberately avoid showing face-button glyphs that
      -- no longer own these commands. The compact direction plate still uses
      -- the same diamond positions and selection highlight.
      G.setColor(1, 1, 1, on and 0.20 or 0.08)
      roundRect("fill", bx - iconR, by - iconR * 0.72, iconR * 2, iconR * 1.44, iconR * 0.30)
      G.setColor(1, 1, 1, on and 0.85 or 0.30)
      roundRect("line", bx - iconR, by - iconR * 0.72, iconR * 2, iconR * 1.44, iconR * 0.30)
    end
    if labelFont then G.setFont(labelFont) end
    G.setColor(1, 1, 1, on and 1.0 or 0.88)
    local tw = G.getFont():getWidth(item.label)
    local labelY = by + iconR * 1.14
    G.print(item.label, bx - tw * 0.5, labelY)
    if hintFont then G.setFont(hintFont) end
    G.setColor(1, 1, 1, 0.54)
    local kw = G.getFont():getWidth(item.key)
    G.print(item.key, bx - kw * 0.5,
            labelY + (labelFont and labelFont:getHeight() or 20) * 0.92)
  end

  if hintFont then G.setFont(hintFont) end
  G.setColor(1, 1, 1, 0.68)
  local hint = shortcutMode == "native"
    and "D-PAD SELECT    /    A CONFIRM    /    B BACK"
    or "LEFT STICK MOVE    /    RIGHT STICK CAMERA"
  local hw = G.getFont():getWidth(hint)
  local footerY = y + h - G.getFont():getHeight() * 1.55 - math.max(5, h * 0.018)
  G.print(hint, x + (w - hw) * 0.5, footerY)
end

-- Presentation-only mirror of Gold's native 2x2 battle menu. Unlike the
-- historical command diamond this does not advertise or consume face-button
-- shortcuts; screen.menuIndex remains entirely engine-owned.
local function drawFallbackCommandGrid(screen, ww, wh)
  local G = love.graphics
  local layout = layoutMetrics(ww, wh)
  local dock = commandDockRect(ww, wh, layout)
  local x, y, w, h = dock[1], dock[2], dock[3], dock[4]
  local r = math.max(14, wh * 0.022)
  panel(x, y, w, h, r, 0.82)

  local titleFont = font(math.max(17, wh * 0.022))
  local rowFont = font(math.max(15, wh * 0.019))
  local hintFont = font(math.max(10, wh * 0.013))
  if titleFont then G.setFont(titleFont) end
  G.setColor(1, 1, 1, 0.98)
  G.print("BATTLE", x + w * 0.07, y + h * 0.08)

  local selected = tonumber(screen.menuIndex) or 1
  local rows = {
    { 1, "FIGHT", 0, 0 }, { 2, "PKMN", 1, 0 },
    { 3, "PACK", 0, 1 }, { 4, "RUN", 1, 1 },
  }
  local gap = math.max(8, h * 0.035)
  local cellW = (w - w * 0.14 - gap) * 0.5
  local cellH = math.max(46, h * 0.22)
  local baseX, baseY = x + w * 0.07, y + h * 0.28
  for _, row in ipairs(rows) do
    local index, label, col, line = row[1], row[2], row[3], row[4]
    local cx = baseX + col * (cellW + gap)
    local cy = baseY + line * (cellH + gap)
    local on = selected == index
    themedRow(G, on, 0.07)
    roundRect("fill", cx, cy, cellW, cellH, r * 0.45)
    if on then
      themedColor(G, "selectionFrame", 0.86)
      G.setLineWidth(2)
      roundRect("line", cx, cy, cellW, cellH, r * 0.45)
    end
    if rowFont then G.setFont(rowFont) end
    G.setColor(1, 1, 1, on and 1 or 0.82)
    G.printf(label, cx, cy + cellH * 0.28, cellW, "center")
  end
  if hintFont then G.setFont(hintFont) end
  G.setColor(1, 1, 1, 0.62)
  G.print("D-PAD SELECT    A CONFIRM", x + w * 0.07, y + h * 0.88)
end

local function drawHandCursor(x, y, scale)
  local G = love.graphics
  scale = tonumber(scale) or 1
  G.push()
  G.translate(x - 8 * scale, y - 20 * scale)
  G.scale(scale, scale)
  G.setColor(0.005, 0.015, 0.025, 0.98)
  G.polygon("fill", 5,0, 10,0, 10,7, 12,4, 15,5, 15,10,
            12,15, 10,15, 10,19, 6,19, 6,15, 3,13, 1,9, 2,6, 5,8)
  G.setColor(0.98, 0.99, 1.00, 1)
  G.polygon("fill", 6,1, 9,1, 9,10, 11,6, 13,6, 14,9,
            11,14, 9,14, 9,16, 7,16, 7,14, 4,12, 2,9, 3,7, 6,10)
  themedColor(G, "frame", 1)
  G.rectangle("fill", 6, 16, 4, 3)
  G.pop()
end

local ORAS_ACTION_ASSETS = {
  fight="assets/hud/oras/en_fight.png",
  bag="assets/hud/oras/en_bag.png",
  pokemon="assets/hud/oras/en_pokemon.png",
  run="assets/hud/oras/en_run.png",
  move="assets/hud/oras/en_move.png",
  mega="assets/hud/oras/en_mega.png",
}

-- Same authored ORAS action furniture as the Gen-1 provider. Gold's
-- menuIndex remains the sole selection/input authority; this function only
-- lays the shared FIGHT / BAG / POKEMON / RUN art over the voxel scene.
local function drawNativeCommandGrid(screen, ww, wh)
  local entries = {
    { index=1, key="fight" }, { index=3, key="bag" },
    { index=2, key="pokemon" }, { index=4, key="run" },
  }
  local mega = V.Gen2MegaBridge
  local visible, allowed
  if mega and type(mega.state) == "function" then
    visible, allowed = mega.state(screen)
  end
  if visible then table.insert(entries, 3, { index=0, key="mega" }) end
  local megaFocused = visible and screen._vascGen2MegaFocus == true
  for _, entry in ipairs(entries) do
    entry.image = assetImage(ORAS_ACTION_ASSETS[entry.key])
    if not entry.image then return drawFallbackCommandGrid(screen, ww, wh) end
  end

  local G = love.graphics
  local layout = layoutMetrics(ww, wh)
  local dock, dockScale, logicalW, logicalH = commandDockRect(ww, wh, layout)
  local x, y, w, h = 0, 0, logicalW, logicalH
  -- Paint in the same logical plane as Kanto, then scale the completed surface
  -- once. This preserves the authored proportions and exact bottom seat.
  G.push()
  G.translate(dock[1], dock[2])
  G.scale(dockScale, dockScale)
  local selected = tonumber(screen.menuIndex) or 1
  local lower = {}
  for i=2,#entries do lower[#lower+1]=entries[i] end
  -- Exact Kanto ORAS internal proportions: fixed responsive gaps, one shared
  -- shrink factor and a 150% requested control presentation.
  local controlScale = 1.50
  local gap = math.max(5, math.min(9, w * 0.025))
  local lowerW = 0
  for _, entry in ipairs(lower) do
    local iw, ih = entry.image:getDimensions()
    local maxW = (entry.key == "run" or entry.key == "mega") and 0.16 or 0.18
    local maxH = entry.key == "mega" and 0.36
      or (entry.key == "run" and 0.30 or 0.32)
    entry.baseScale = math.min(w * maxW * controlScale / iw, h * maxH / ih)
    entry.layoutW, entry.layoutH = iw * entry.baseScale, ih * entry.baseScale
    lowerW = lowerW + entry.layoutW
  end
  local gapCount = #lower-1
  lowerW = lowerW + gap * gapCount
  local contentW = math.max(1, lowerW-gap*gapCount)
  local rowFit = math.min(1, math.max(.35, (w-8-gap*gapCount)/contentW))
  lowerW = gap*gapCount
  local rowTop = y + h
  for _, entry in ipairs(lower) do
    entry.baseScale = entry.baseScale * rowFit
    local iw, ih = entry.image:getDimensions()
    entry.layoutW, entry.layoutH = iw*entry.baseScale, ih*entry.baseScale
    lowerW = lowerW + entry.layoutW
    rowTop = math.min(rowTop, y + h - entry.layoutH)
  end
  local cursorX = x + w * 0.5
  local cursorY = y + h * 0.5
  local lx = x + (w - lowerW) * 0.5
  local frame = tonumber(screen.frame) or 0
  for _, entry in ipairs(lower) do
    entry.focused = (entry.key == "mega" and megaFocused)
      or (entry.index == selected and not megaFocused)
    local pulse = entry.focused and (0.96 + 0.04*math.sin(frame*0.12)) or 1
    entry.scale = entry.baseScale * pulse
    local iw, ih = entry.image:getDimensions()
    entry.w, entry.h = iw*entry.scale, ih*entry.scale
    entry.layoutX = lx
    entry.x = lx + (entry.layoutW-entry.w)*0.5
    entry.y = y + h - entry.h
    lx = lx + entry.layoutW + gap
  end
  local fight = entries[1]
  local fiw, fih = fight.image:getDimensions()
  -- Exact Kanto contract.  Localised FIGHT crops still occupy the authored
  -- 69x32 design box, so shorter translated art never becomes oversized.
  fight.baseScale = math.min(w * .30 * controlScale / 69,
                             h * .32 / 32)
  fight.layoutW, fight.layoutH = fiw*fight.baseScale, fih*fight.baseScale
  fight.focused = selected == 1 and not megaFocused
  local fightPulse = fight.focused and (0.96 + 0.04*math.sin(frame*0.12)) or 1
  fight.scale = fight.baseScale * fightPulse
  fight.w, fight.h = fiw * fight.scale, fih * fight.scale
  fight.layoutX = x + (w - fight.layoutW) * 0.5
  local actionGap = math.max(2, math.min(5, w * 0.012))
  fight.layoutY = math.max(y, rowTop - fight.layoutH - actionGap)
  fight.x = fight.layoutX + (fight.layoutW-fight.w)*0.5
  fight.y = fight.layoutY + (fight.layoutH-fight.h)*0.5

  -- Same Gen-1 row: BAG / MEGA / POKEMON / RUN. The optional icon joins the
  -- common fit/bottom seat, never an extra panel beside FIGHT. With no Mega
  -- capability the original three-icon geometry remains byte-for-byte equal.
  local megaRect
  for _, entry in ipairs(lower) do
    if entry.key == "mega" then
      local hitTop = rowTop - actionGap*.5
      megaRect = {dock[1]+entry.layoutX*dockScale, dock[2]+hitTop*dockScale,
        entry.layoutW*dockScale, (logicalH-hitTop)*dockScale}
    end
  end

  for _, entry in ipairs(entries) do
    local focused = entry.focused == true
    if focused then
      themedColor(G, "selection", 0.26)
      G.ellipse("fill", entry.x + entry.w * 0.5,
                entry.y + entry.h * 0.60,
                entry.w * 0.58, entry.h * 0.62)
      cursorX, cursorY = entry.x + entry.w * 0.5, entry.y
    end
    G.setColor(1, 1, 1, entry.key == "mega" and not allowed and .35
      or (focused and 1 or 0.90))
    G.draw(entry.image, entry.x, entry.y, 0, entry.scale, entry.scale)
  end
  drawHandCursor(cursorX, cursorY, .82)
  G.pop()
  return megaRect
end

local function moveDef(screen, move)
  local battle = screen and screen.battle
  if battle and type(battle.moveDef) == "function" then
    local id = type(move) == "table" and (move.id or move.moveId) or move
    local ok, def = pcall(battle.moveDef, battle, id)
    if ok and type(def) == "table" then return def end
  end
  return nil
end

local function moveLabel(screen, move)
  local def = moveDef(screen, move)
  if def and def.name then return cleanText(def.name), def end
  if type(move) == "table" then
    if move.name then return cleanText(move.name), def end
    if move.id then return cleanText(move.id), def end
  end
  return cleanText(move), def
end

local function movePP(move, def)
  if type(move) ~= "table" then return nil, nil end
  local pp = tonumber(move.pp)
  local maxPp = tonumber(move.maxPp) or tonumber(move.maxPP)
  if not maxPp and def then maxPp = tonumber(def.pp) end
  return pp, maxPp
end

local TYPE_COLORS = {
  NORMAL={0.64,0.64,0.56}, FIRE={0.95,0.31,0.16}, WATER={0.20,0.52,0.96},
  ELECTRIC={0.98,0.79,0.12}, GRASS={0.28,0.75,0.25}, ICE={0.35,0.82,0.85},
  FIGHTING={0.82,0.16,0.20}, POISON={0.65,0.24,0.66}, GROUND={0.75,0.56,0.24},
  FLYING={0.48,0.57,0.88}, PSYCHIC={0.94,0.25,0.52}, BUG={0.58,0.70,0.18},
  ROCK={0.68,0.57,0.30}, GHOST={0.40,0.33,0.64}, DRAGON={0.43,0.29,0.90},
  DARK={0.36,0.29,0.25}, STEEL={0.58,0.63,0.70}, FAIRY={0.91,0.48,0.72},
}

local function moveColor(def)
  local key = tostring(def and def.type or "NORMAL"):upper()
  return TYPE_COLORS[key] or TYPE_COLORS.NORMAL
end

local function moveCardPresentation(screen, move)
  local name, def = moveLabel(screen, move)
  local pp, maxPp = movePP(move, def)
  local kind = tostring(def and def.type or "NORMAL"):upper()
  if not TYPE_COLORS[kind] then kind = "NORMAL" end
  local color = moveColor(def)
  return {
    id=type(move) == "table" and (move.id or move.moveId) or move,
    name=name, type=kind, pp=pp, maxPp=maxPp,
    color={ color[1], color[2], color[3] },
  }
end

M.moveCardPresentation = moveCardPresentation

local function drawMoves(screen, ww, wh)
  local G = love.graphics
  local moves = playerMoves(screen)
  local layout = layoutMetrics(ww, wh)
  local dock, dockScale, logicalW, logicalH = moveDockRect(ww, wh, layout)
  local x, y, w, h = 0, 0, logicalW, logicalH
  G.push()
  G.translate(dock[1], dock[2])
  G.scale(dockScale, dockScale)
  local count = math.min(4, #moves)
  local selected = math.max(1, math.min(math.max(1, count),
    math.floor(tonumber(screen.moveIndex) or 1)))
  local controlScale = 1.50
  local gap = math.max(6*controlScale,
    math.min(10*controlScale, w*.022))
  local cardW = math.min(148*controlScale, (w-gap)*.5)
  local gridW = cardW*2 + gap
  local gridX = x + (w-gridW)*.5
  local cardH = 29*controlScale
  local rowOneY = y + 24*controlScale
  local rowTwoY = rowOneY + cardH + 5*controlScale
  local positions = {
    { x=gridX, y=rowOneY }, { x=gridX+cardW+gap, y=rowOneY },
    { x=gridX, y=rowTwoY }, { x=gridX+cardW+gap, y=rowTwoY },
  }
  local frame = tonumber(screen.frame) or 0
  local chosen = positions[selected]
  for i = 1, count do
    local move = moves[i]
    local pos = positions[i]
    local card = moveCardPresentation(screen, move)
    local color = card.color or TYPE_COLORS.NORMAL
    local focused = i == selected
    local pulse = .5 + .5*math.sin(frame*.12)
    G.setColor(.012, .038, .055, .94)
    G.rectangle("fill", pos.x, pos.y, cardW, cardH,
      7*controlScale, 7*controlScale)
    G.setColor(color[1]*.68, color[2]*.68, color[3]*.68,
      focused and (.54+pulse*.14) or .42)
    G.rectangle("fill", pos.x+2*controlScale, pos.y+2*controlScale,
      cardW-4*controlScale, cardH-4*controlScale,
      6*controlScale, 6*controlScale)
    G.setColor(color[1], color[2], color[3], 1)
    G.rectangle("fill", pos.x+7*controlScale, pos.y+2*controlScale,
      cardW-14*controlScale, 2*controlScale)
    G.setLineWidth(focused and (2+pulse) or 1)
    G.rectangle("line", pos.x, pos.y, cardW, cardH,
      7*controlScale, 7*controlScale)
    if focused then
      G.setColor(1, 1, 1, .76+pulse*.22)
      G.rectangle("line", pos.x+2*controlScale, pos.y+2*controlScale,
        cardW-4*controlScale, cardH-4*controlScale,
        6*controlScale, 6*controlScale)
    end
    G.setLineWidth(1)
    local textCenter = pos.x + cardW*.5
    local textRoom = math.max(16, cardW-14*controlScale)
    local nameScale = .72*controlScale
    local name = fitHudText(card.name, textRoom/nameScale)
    drawCenteredHudText(name, textCenter, pos.y+6*controlScale,
      nameScale, 1)
    local pp = card.pp and tostring(math.floor(card.pp)) or "--"
    if card.maxPp then pp = pp .. "/" .. tostring(math.floor(card.maxPp)) end
    drawCenteredHudText(pp, textCenter, pos.y+17*controlScale,
      .58*controlScale, 1)
  end
  local moveTab = assetImage(ORAS_ACTION_ASSETS.move)
  if moveTab then
    local iw, ih = moveTab:getDimensions()
    local scale = .58*controlScale
    local backW, backH = iw*scale, ih*scale
    local backX = x + (w-backW)*.5
    local backY = y + h-backH-7*controlScale
    local label = "BACK"
    local labelScale = .62*controlScale
    local badgeW = hudTextWidth(label)*labelScale+8*controlScale
    local badgeH = 10*controlScale
    local badgeX = x+(w-badgeW)*.5
    local badgeY = backY-12*controlScale
    G.setColor(1, 1, 1, 1)
    G.draw(moveTab, backX, backY, 0, scale, scale)
    G.setColor(.008, .030, .046, .94)
    G.rectangle("fill", badgeX, badgeY, badgeW, badgeH,
      4*controlScale, 4*controlScale)
    themedColor(G, "frame", .78)
    G.rectangle("line", badgeX, badgeY, badgeW, badgeH,
      4*controlScale, 4*controlScale)
    drawCenteredHudText(label, x+w*.5, badgeY+controlScale,
      labelScale, 1)
  else
    drawCenteredHudText("BACK", x+w*.5, y+h-22, .93, .88)
  end
  if count > 0 and chosen then
    drawHandCursor(chosen.x+cardW*.5, chosen.y, .90)
  end
  G.pop()
end


local function selectorGeometry(ww, wh)
  local w = math.min(ww * 0.42, 560)
  local rowH = math.max(54, math.min(76, wh * 0.076))
  local gap = math.max(7, wh * 0.008)
  local headerH = math.max(48, wh * 0.060)
  local footerH = math.max(42, wh * 0.052)
  local h = headerH + rowH * 4 + gap * 5 + footerH
  local x = ww - w - math.max(18, wh * 0.025)
  local y = wh - h - math.max(18, wh * 0.025)
  local r = math.max(14, wh * 0.022)
  return x, y, w, h, rowH, gap, headerH, footerH, r
end

local function selectorHeader(G, title, subtitle, x, y, w, headerH, wh)
  local titleFont = font(math.max(18, wh * 0.023))
  local metaFont = font(math.max(11, wh * 0.013))
  if titleFont then G.setFont(titleFont) end
  G.setColor(1, 1, 1, 0.98)
  G.print(title, x + w * 0.055, y + headerH * 0.22)
  if subtitle and subtitle ~= "" then
    if metaFont then G.setFont(metaFont) end
    G.setColor(1, 1, 1, 0.58)
    G.print(subtitle, x + w * 0.055, y + headerH * 0.68)
  end
end

local function selectorFooter(G, o, x, y, w, h, gap, wh)
  local metaFont = font(math.max(11, wh * 0.013))
  if metaFont then G.setFont(metaFont) end
  local text = o and o.message
  if text and text ~= "" then
    G.setColor(1, 0.86, 0.56, 0.96)
    G.printf(cleanText(text), x + gap * 1.6, y + h - math.max(37, wh * 0.046),
             w - gap * 3.2, "left")
  else
    G.setColor(1, 1, 1, 0.58)
    G.print("D-PAD / ARROWS SELECT    CROSS/A CONFIRM    CIRCLE/B BACK",
            x + gap * 1.5, y + h - math.max(28, wh * 0.035))
  end
end

local function drawPartyModelPreview(screen, ww, wh, o, listX, listY, listH, gap, r)
  local party = partyOf(screen)
  local mon = party[tonumber(o and o.index) or 1]
  local margin = math.max(18, wh * 0.025)
  local x = margin
  local y = listY
  local w = listX - margin * 2
  local h = listH
  if not mon or w < math.max(190, ww * 0.18) then return false end

  local G = love.graphics
  panel(x, y, w, h, r, 0.82)
  local titleFont = font(math.max(18, wh * 0.023))
  local metaFont = font(math.max(11, wh * 0.013))
  local name = cleanText(monName(screen, mon))
  local species = cleanText(mon.species or "POKéMON")
  local def = screen and screen.game and screen.game.data and screen.game.data.pokemon
    and screen.game.data.pokemon[mon.species]
  if def and def.name then species = cleanText(def.name) end
  local dex = def and tonumber(def.dex or def.index) or nil
  if titleFont then G.setFont(titleFont) end
  G.setColor(1, 1, 1, 0.98)
  G.print(name, x + w * 0.055, y + h * 0.035)
  if metaFont then G.setFont(metaFont) end
  G.setColor(1, 1, 1, 0.58)
  local subtitle = species .. (dex and ("    #" .. string.format("%03d", dex)) or "")
  G.print(subtitle, x + w * 0.055, y + h * 0.085)

  local infoH = math.max(92, math.min(132, h * 0.20))
  local modelX = x + gap * 1.3
  local modelY = y + h * 0.14
  local modelW = w - gap * 2.6
  local modelH = h - infoH - h * 0.18
  G.setColor(1, 1, 1, 0.035)
  roundRect("fill", modelX, modelY, modelW, modelH, r * 0.58)
  G.setColor(1, 1, 1, 0.075)
  G.ellipse("fill", modelX + modelW * 0.50, modelY + modelH * 0.83,
    modelW * 0.28, math.max(5, modelH * 0.045))

  local preview = partyPreview()
  local canvas, details
  if mon.isEgg then
    details = { error = "egg" }
  elseif preview and type(preview.render) == "function" then
    local ok, rendered, info = pcall(preview.render, screen, mon,
      math.min(modelW, 480), math.min(modelH, 480))
    if ok then canvas, details = rendered, info else M.lastPartyPreviewError = tostring(rendered) end
  end
  if canvas and type(canvas.getDimensions) == "function" then
    local cw, ch = canvas:getDimensions()
    if cw and ch and cw > 0 and ch > 0 then
      local k = math.min(modelW / cw, modelH / ch)
      G.setColor(1, 1, 1, 1)
      G.draw(canvas, modelX + (modelW - cw * k) * 0.5,
        modelY + (modelH - ch * k) * 0.5, 0, k, k)
    end
  else
    -- Stadium packs are optional in Gold.  A failed/missing 3D preview must
    -- never turn the selected party member into an error placard: Crystal's
    -- own authored front picture is the exact sharp generation-correct
    -- fallback and is already available through this BattleState.
    local native, trueColor
    if not mon.isEgg and type(screen.pic) == "function" then
      local okPic, image, ownColor = pcall(screen.pic, screen, mon, false)
      if okPic and image and type(image.getDimensions) == "function" then
        native, trueColor = image, ownColor
      end
    end
    if native then
      local iw, ih = native:getDimensions()
      if iw and ih and iw > 0 and ih > 0 then
        local k = math.max(1, math.floor(math.min(modelW / iw, modelH / ih)))
        local dx = modelX + math.floor((modelW - iw * k) * 0.5)
        local dy = modelY + math.floor((modelH - ih * k) * 0.5)
        local function paint()
          G.setColor(1, 1, 1, 1)
          G.draw(native, dx, dy, 0, k, k)
        end
        local okPal, Palettes = pcall(V.require, "src.world.gen2.Palettes")
        local okGbc, GbcPalette = pcall(V.require, "src.render.GbcPalette")
        local colors = okPal and screen.palettes and type(Palettes.monColors) == "function"
          and Palettes.monColors(screen.palettes, mon.species, mon.shiny) or nil
        if colors and not trueColor and okGbc and type(GbcPalette.available) == "function"
            and GbcPalette.available() and type(GbcPalette.with) == "function" then
          GbcPalette.with(colors, paint)
        else
          paint()
        end
      end
    else
      local f = font(math.max(13, wh * 0.017))
      if f then G.setFont(f) end
      G.setColor(1, 1, 1, 0.68)
      local msg = mon.isEgg and "EGG" or "3D MODEL UNAVAILABLE"
      if details and details.error and details.error ~= "egg" then msg = "3D PREVIEW ERROR" end
      G.printf(msg, modelX, modelY + modelH * 0.45, modelW, "center")
    end
  end

  local hp = math.max(0, tonumber(mon.hp) or 0)
  local maxHp = tonumber(mon.maxHp)
    or (type(mon.stats) == "table" and tonumber(mon.stats.hp)) or math.max(1, hp)
  maxHp = math.max(1, maxHp)
  local ratio = math.max(0, math.min(1, hp / maxHp))
  local iy = y + h - infoH - gap
  G.setColor(1, 1, 1, 0.055)
  roundRect("fill", x + gap, iy, w - gap * 2, infoH, r * 0.50)
  if metaFont then G.setFont(metaFont) end
  G.setColor(1, 1, 1, 0.66)
  local status = mon.isEgg and "EGG" or hp <= 0 and "FNT" or cleanText(mon.status or "OK")
  if status == "" then status = "OK" end
  G.print(("LV %d    %s"):format(tonumber(mon.level) or 1, status),
    x + gap * 2, iy + infoH * 0.22)
  G.print(("HP %d / %d"):format(hp, maxHp), x + gap * 2, iy + infoH * 0.52)
  local bx, by = x + gap * 2, iy + infoH * 0.76
  local bw, bh = w - gap * 4, math.max(7, infoH * 0.08)
  G.setColor(0, 0, 0, 0.48)
  roundRect("fill", bx, by, bw, bh, bh * 0.5)
  local cr, cg, cb = hpColor(ratio)
  G.setColor(cr, cg, cb, 0.96)
  if ratio > 0 then roundRect("fill", bx, by, math.max(2, bw * ratio), bh, bh * 0.5) end
  return true
end

local function drawPartySelector(screen, ww, wh, o)
  local G = love.graphics
  local party = partyOf(screen)
  local x, y, w, h, rowH, gap, headerH, _, r = selectorGeometry(ww, wh)
  panel(x, y, w, h, r, 0.82)
  local title = o.mode == "itemparty" and "CHOOSE POKéMON" or "POKéMON"
  local subtitle = o.mode == "itemparty"
    and ("USE " .. cleanText(o.itemName or o.itemId or "ITEM"))
    or "SELECT A POKéMON TO SWITCH"
  selectorHeader(G, title, subtitle, x, y, w, headerH, wh)

  local nameFont = font(math.max(15, wh * 0.019))
  local metaFont = font(math.max(11, wh * 0.013))
  local active = screen.battle and screen.battle.player
  local start = (o.scroll or 0) + 1
  for slot = 1, 4 do
    local i = start + slot - 1
    local mon = party[i]
    local ry = y + headerH + gap + (slot - 1) * (rowH + gap)
    local on = mon and o.index == i
    themedRow(G, on, 0.07)
    roundRect("fill", x + gap, ry, w - gap * 2, rowH, r * 0.55)
    if on then
      themedColor(G, "selectionFrame", 0.96)
      G.setLineWidth(2)
      roundRect("line", x + gap, ry, w - gap * 2, rowH, r * 0.55)
    end
    if mon then
      if nameFont then G.setFont(nameFont) end
      G.setColor(1, 1, 1, 0.98)
      G.print(monName(screen, mon), x + gap * 2.2, ry + rowH * 0.15)

      local hp = math.max(0, tonumber(mon.hp) or 0)
      local maxHp = tonumber(mon.maxHp)
        or (type(mon.stats) == "table" and tonumber(mon.stats.hp)) or math.max(1, hp)
      maxHp = math.max(1, maxHp)
      local ratio = math.max(0, math.min(1, hp / maxHp))
      local bx = x + gap * 2.2
      local by = ry + rowH * 0.53
      local bw = w * 0.46
      local bh = math.max(7, rowH * 0.10)
      G.setColor(0, 0, 0, 0.46)
      roundRect("fill", bx, by, bw, bh, bh * 0.5)
      local cr, cg, cb = hpColor(ratio)
      G.setColor(cr, cg, cb, 0.96)
      if ratio > 0 then roundRect("fill", bx, by, math.max(2, bw * ratio), bh, bh * 0.5) end

      if metaFont then G.setFont(metaFont) end
      G.setColor(1, 1, 1, 0.64)
      local status = mon.isEgg and "EGG"
        or hp <= 0 and "FNT"
        or cleanText(mon.status or "")
      local meta = ("LV %d    HP %d/%d"):format(tonumber(mon.level) or 1, hp, maxHp)
      if status ~= "" then meta = meta .. "    " .. status end
      G.print(meta, bx, by + bh + rowH * 0.08)

      if mon == active then
        local tag = "ACTIVE"
        local tw = G.getFont():getWidth(tag)
        G.setColor(1, 1, 1, 0.58)
        G.print(tag, x + w - tw - gap * 2.2, ry + rowH * 0.18)
      end
    else
      if nameFont then G.setFont(nameFont) end
      G.setColor(1, 1, 1, 0.22)
      G.print("—", x + gap * 2.2, ry + rowH * 0.28)
    end
  end
  drawPartyModelPreview(screen, ww, wh, o, x, y, h, gap, r)
  selectorFooter(G, o, x, y, w, h, gap, wh)
end

local function pocketLabel(id)
  if id == "BALL" then return "BALL" end
  if id == "KEY_ITEM" then return "KEY" end
  if id == "TM_HM" then return "TM/HM" end
  return "ITEM"
end

local function drawPackSelector(screen, ww, wh, o)
  local G = love.graphics
  o.rows = packRows(screen)
  clampOverlayCursor(o)
  local rows = o.rows
  local x, y, w, h, rowH, gap, headerH, _, r = selectorGeometry(ww, wh)
  panel(x, y, w, h, r, 0.82)
  selectorHeader(G, "PACK", "BATTLE ITEMS", x, y, w, headerH, wh)

  local nameFont = font(math.max(15, wh * 0.019))
  local metaFont = font(math.max(11, wh * 0.013))
  local start = (o.scroll or 0) + 1
  for slot = 1, 4 do
    local i = start + slot - 1
    local row = rows[i]
    local ry = y + headerH + gap + (slot - 1) * (rowH + gap)
    local on = row and o.index == i
    themedRow(G, on, 0.07)
    roundRect("fill", x + gap, ry, w - gap * 2, rowH, r * 0.55)
    if on then
      themedColor(G, "selectionFrame", 0.96)
      G.setLineWidth(2)
      roundRect("line", x + gap, ry, w - gap * 2, rowH, r * 0.55)
    end
    if row then
      if nameFont then G.setFont(nameFont) end
      G.setColor(1, 1, 1, row.disabled and 0.38 or 0.98)
      G.print(cleanText(row.name), x + gap * 2.2, ry + rowH * 0.18)
      if metaFont then G.setFont(metaFont) end
      G.setColor(1, 1, 1, row.disabled and 0.28 or 0.62)
      local meta = pocketLabel(row.pocket) .. "    ×" .. tostring(math.floor(row.count or 0))
      if row.disabled then meta = meta .. "    CAN'T USE" end
      G.print(meta, x + gap * 2.2, ry + rowH * 0.61)
    else
      if nameFont then G.setFont(nameFont) end
      G.setColor(1, 1, 1, 0.22)
      G.print("—", x + gap * 2.2, ry + rowH * 0.28)
    end
  end
  selectorFooter(G, o, x, y, w, h, gap, wh)
end

local function drawItemMoveSelector(screen, ww, wh, o)
  local G = love.graphics
  local moves = (o.targetMon and o.targetMon.moves) or {}
  local x, y, w, h, rowH, gap, headerH, _, r = selectorGeometry(ww, wh)
  panel(x, y, w, h, r, 0.82)
  selectorHeader(G, "CHOOSE MOVE",
    "RESTORE PP / " .. monName(screen, o.targetMon), x, y, w, headerH, wh)

  local nameFont = font(math.max(15, wh * 0.019))
  local metaFont = font(math.max(11, wh * 0.013))
  for i = 1, 4 do
    local move = moves[i]
    local ry = y + headerH + gap + (i - 1) * (rowH + gap)
    local on = move and o.index == i
    themedRow(G, on, 0.07)
    roundRect("fill", x + gap, ry, w - gap * 2, rowH, r * 0.55)
    if on then
      themedColor(G, "selectionFrame", 0.96)
      G.setLineWidth(2)
      roundRect("line", x + gap, ry, w - gap * 2, rowH, r * 0.55)
    end
    if move then
      local name, def = moveLabel(screen, move)
      if nameFont then G.setFont(nameFont) end
      G.setColor(1, 1, 1, 0.98)
      G.print(name, x + gap * 2.2, ry + rowH * 0.18)
      local pp, maxPp = movePP(move, def)
      if metaFont then G.setFont(metaFont) end
      G.setColor(1, 1, 1, 0.62)
      local meta = "PP " .. tostring(math.floor(pp or 0))
      if maxPp then meta = meta .. "/" .. tostring(math.floor(maxPp)) end
      if def and def.type then meta = cleanText(def.type) .. "    " .. meta end
      G.print(meta, x + gap * 2.2, ry + rowH * 0.61)
    else
      if nameFont then G.setFont(nameFont) end
      G.setColor(1, 1, 1, 0.22)
      G.print("—", x + gap * 2.2, ry + rowH * 0.28)
    end
  end
  selectorFooter(G, o, x, y, w, h, gap, wh)
end

local function drawCustomOverlay(screen, ww, wh)
  local o = overlayFor(screen)
  if not o then return false end
  if o.mode == "pack" then drawPackSelector(screen, ww, wh, o)
  elseif o.mode == "party" or o.mode == "itemparty" then drawPartySelector(screen, ww, wh, o)
  elseif o.mode == "itemmove" then drawItemMoveSelector(screen, ww, wh, o)
  else return false end
  return true
end

local function drawMessage(screen, ww, wh)
  local text = cleanText(screen and screen.message)
  if text == "" then return end
  local G = love.graphics
  local rect, drawScale = messageDockRect(ww, wh)
  local x, y, w, h = rect[1], rect[2], rect[3], rect[4]
  local r = math.max(10, wh * 0.016)
  -- No second full-size dark plate underneath: overlapping .48 and .82
  -- fills made the nominally translucent message over 90% opaque.
  themedColor(G, "panel", 0.82)
  roundRect("fill", x, y, w, h, r)
  themedColor(G, "frame", 0.96)
  G.setLineWidth(2)
  roundRect("line", x, y, w, h, r)
  G.setLineWidth(1)
  G.setColor(1, 1, 1, 0.18)
  G.line(x + 14, y + 5, x + w - 14, y + 5)
  -- Use the same 8px authored glyph and 1.18 text gain as Kanto's ORAS
  -- message owner. Text and plate now grow together instead of the old state
  -- where a capped font floated inside a separately capped rectangle.
  local f = font(math.max(10, 8 * drawScale * 1.18))
  if f then G.setFont(f) end
  local leftPad = 13 * drawScale
  local rightPad = 24 * drawScale
  local activeFont = G.getFont()
  local wrapW = math.max(1, w - leftPad - rightPad)
  local lineCount = 1
  if activeFont and type(activeFont.getWrap) == "function" then
    local okWrap, _, lines = pcall(activeFont.getWrap, activeFont, text, wrapW)
    if okWrap and type(lines) == "table" then
      lineCount = math.max(1, #lines)
    end
  end
  local glyphH = activeFont:getHeight()
  local lineStep = glyphH * (type(activeFont.getLineHeight) == "function"
    and activeFont:getLineHeight() or 1)
  local textBlockH = glyphH + math.max(0, lineCount - 1) * lineStep
  local lineY = y + (h - textBlockH) * 0.5
  -- The engine owns paging; this surface only centres the currently revealed
  -- page inside Kanto's message dock.
  G.setColor(0.005, 0.015, 0.025, 0.92)
  G.printf(text, x + leftPad + 1, lineY + 1, wrapW, "center")
  G.setColor(0.94, 0.99, 1.00, 1)
  G.printf(text, x + leftPad, lineY, wrapW, "center")
end

local function yesNoPromptRect(ww, wh)
  local message = messageDockRect(ww, wh)
  local messageX, messageY, messageW = message[1], message[2], message[3]
  local insetLeft, _, insetRight = viewportSafeInsets(ww, wh)
  local gap = math.max(10, math.min(ww, wh) * 0.014)
  local w = math.max(132, math.min(190, ww * 0.17))
  local h = math.max(82, math.min(108, wh * 0.13))
  local x = messageX + messageW + gap
  local right = ww - insetRight - gap
  if x + w > right then x = right - w end
  x = math.max(insetLeft + gap, x)
  local y = messageY - gap - h
  return { x, math.max(gap, y), w, h }
end

local function promptSelection(screen)
  local phase = tostring(screen and screen.phase or "")
  if phase == "ask-next-mon" then return tonumber(screen.nextMonIndex) or 1 end
  if phase == "ask-shift" then return tonumber(screen.shiftIndex) or 1 end
  return nil
end

-- Gold still owns update/confirmation for these questions.  The custom Voxel
-- surface only mirrors the native YES/NO cursor that would otherwise be drawn
-- on the suppressed 160x144 cartridge canvas.
local function drawYesNoPrompt(screen, ww, wh)
  if (tonumber(screen and screen.messageTimer) or 0) > 0 then return false end
  local selected = promptSelection(screen)
  if not selected then return false end
  local G = love.graphics
  local rect = yesNoPromptRect(ww, wh)
  local x, y, w, h = rect[1], rect[2], rect[3], rect[4]
  local r = math.max(9, h * 0.12)
  G.setColor(0, 0, 0, 0.48)
  roundRect("fill", x + 5, y + 5, w, h, r)
  themedColor(G, "panel", 0.92)
  roundRect("fill", x, y, w, h, r)
  themedColor(G, "frame", 0.98)
  G.setLineWidth(2)
  roundRect("line", x, y, w, h, r)
  G.setLineWidth(1)
  local rowGap = math.max(5, h * 0.06)
  local pad = math.max(8, w * 0.07)
  local rowH = (h - pad * 2 - rowGap) * 0.5
  local f = font(math.max(13, math.min(21, rowH * 0.46)))
  if f then G.setFont(f) end
  -- Match Gold/Crystal's native YesNoBox labels. Translation mods may replace
  -- the surrounding source string, but the engine-owned box itself is YES/NO.
  for index, label in ipairs({ "YES", "NO" }) do
    local ry = y + pad + (index - 1) * (rowH + rowGap)
    themedRow(G, selected == index, 0.14)
    roundRect("fill", x + pad, ry, w - pad * 2, rowH, r * 0.55)
    if selected == index then
      themedColor(G, "selectionFrame", 1)
      G.setLineWidth(2)
      roundRect("line", x + pad, ry, w - pad * 2, rowH, r * 0.55)
      G.setLineWidth(1)
    end
    G.setColor(0.94, 0.99, 1.00, selected == index and 1 or 0.72)
    G.printf(label, x + pad, ry + (rowH - G.getFont():getHeight()) * 0.5,
      w - pad * 2, "center")
  end
  return true
end

local function drawPhaseHint(screen, ww, wh)
  if not screen or overlayFor(screen) then return end
  local phase = tostring(screen.phase or "")
  if phase == "menu" or phase == "moves" or screen.message then return end
  local G = love.graphics
  local f = font(math.max(11, wh * 0.013))
  if f then G.setFont(f) end
  local text = "LEFT STICK MOVE   /   RIGHT STICK CAMERA"
  local tw = G.getFont():getWidth(text)
  local x = (ww - tw) * 0.5
  G.setColor(0, 0, 0, 0.44)
  roundRect("fill", x - 13, wh - 44, tw + 26, 30, 12)
  G.setColor(1, 1, 1, 0.70)
  G.print(text, x, wh - 38)
end

local CAMERA_BOUNDS_SCHEMA = "voxel-ascendant/gen2-hud-camera-bounds/v1"

local function safetyStatusRect(side, projection, ww, wh, w, h)
  local visual = type(projection) == "table"
    and type(projection.actorVisuals) == "table"
    and projection.actorVisuals[side] or nil
  local head, hull = visual and visual.head, visual and visual.hull
  if not (type(head) == "table" and tonumber(head.x) and tonumber(head.y)
      and type(hull) == "table" and tonumber(hull[1]) and tonumber(hull[2])
      and tonumber(hull[3]) and tonumber(hull[4])) then return nil end
  local layout = layoutMetrics(ww, wh)
  local status = side == "enemy" and layout.enemyStatus or layout.playerStatus
  local definition = GEN1_STATUS[side] or GEN1_STATUS.player
  local baseScale = tonumber(layout.statusBaseScale) or 1
  local attachX = (tonumber(definition.attachX) or 0) * baseScale
  local attachY = (tonumber(definition.attachY) or 0) * baseScale
  local margin, gap = layout.margin,
    math.max(8, math.min(ww, wh) * .012)
  local clearance = math.max(8,
    5 * (tonumber(status.scale) or 1) + 18 * baseScale * .30)
  local sideGap = math.max(8, 5 * baseScale)
  local minX, minY = margin, margin
  local maxX, maxY = math.max(minX, ww-margin-w),
                       math.max(minY, wh-margin-h)
  -- cameraBounds must describe the exact deterministic target seats used by
  -- projectedStatusRect above.  In particular, player and enemy own separate
  -- screen halves and neither path may invent a lower-corner fallback.
  local halfGap = gap
  local function semanticX(px)
    if side == "player" then
      local upper = math.max(minX, math.min(maxX, ww * 0.5 - halfGap - w))
      return math.max(minX, math.min(upper, px))
    end
    local lower = math.min(maxX, math.max(minX, ww * 0.5 + halfGap))
    return math.max(lower, math.min(maxX, px))
  end
  local function clampY(py)
    return math.max(minY, math.min(maxY, py))
  end
  local function hitsActor(x, y)
    for _, actorSide in ipairs({ "player", "enemy" }) do
      local actor = projection.actorVisuals[actorSide]
      local actorRect = statusActorRect(actor)
      if actorRect and rectanglesHit({ x, y, w, h }, actorRect, gap) then
        return true
      end
    end
    return false
  end
  local visualTop = statusVisualTop(visual) or head.y
  local x = semanticX(statusHeadX(side, head.x, w, sideGap, attachX))
  local y = clampY(visualTop - h - clearance + attachY)
  if not hitsActor(x, y) then return { x, y, w, h } end
  local outsideX = side == "player" and (hull[1] - sideGap - w)
                                      or (hull[1] + hull[3] + sideGap)
  local semanticCorner = semanticX(side == "player" and minX or maxX)
  local outwardX = side == "player" and (head.x - w * 0.78)
                                       or (head.x - w * 0.22)
  local middleY = clampY(head.y - h * 0.52 + attachY)
  for _, candidate in ipairs({
    { semanticX(statusHeadX(side, head.x, w, sideGap, attachX)),
      clampY(visualTop-h-clearance + attachY) },
    { semanticX(outwardX + attachX),
      clampY(visualTop-h-clearance + attachY) },
    { semanticX(outsideX + attachX), middleY },
    { semanticX((side == "player" and minX or maxX) + attachX), middleY },
    { semanticCorner, clampY(minY + attachY) },
  }) do
    local cx, cy = candidate[1], candidate[2]
    if not hitsActor(cx, cy) then return { cx, cy, w, h } end
  end
  return { semanticCorner, clampY(minY + attachY), w, h }
end

-- Exact public description of the furniture this renderer will paint for the
-- current Gold phase.  SMART consumes it before choosing a moving lens; no
-- battle rule or native cursor is consulted beyond the same read-only phase
-- receipts drawFull already uses.
function M.cameraBounds(screen, shot)
  if not (M.owns(screen) and type(shot) == "table") then
    return nil, "oras-hud-not-owner"
  end
  local ww, wh = tonumber(shot.pw), tonumber(shot.ph)
  if not (ww and wh and ww > 0 and wh > 0) then
    return nil, "viewport-unavailable"
  end
  local layout = layoutMetrics(ww, wh)
  local reserved = {}
  local function add(id, rect)
    if type(rect) == "table" and tonumber(rect[1]) and tonumber(rect[2])
        and tonumber(rect[3]) and tonumber(rect[4])
        and rect[3] > 0 and rect[4] > 0 then
      reserved[#reserved + 1] = {
        id=id, x=rect[1], y=rect[2], w=rect[3], h=rect[4],
      }
    end
  end

  local trainerIntro = screen.showEnemyTrainer == true
    or screen.showPlayerTrainer == true or screen.showPlayerBack == true
  if not trainerIntro then
    local enemy = presentedMon(screen, "enemy")
    local player = presentedMon(screen, "player")
    if enemy then
      add("enemy-status",
        heldStatusRect(screen, enemy, "enemy", ww, wh,
          layout.enemyStatus.w, layout.enemyStatus.h)
        or safetyStatusRect("enemy", shot, ww, wh,
          layout.enemyStatus.w, layout.enemyStatus.h))
    end
    if player then
      add("player-status",
        heldStatusRect(screen, player, "player", ww, wh,
          layout.playerStatus.w, layout.playerStatus.h)
        or safetyStatusRect("player", shot, ww, wh,
          layout.playerStatus.w, layout.playerStatus.h))
    end
  end

  local o = overlayFor(screen)
  if o then
    local x, y, w, h = selectorGeometry(ww, wh)
    add("selector", { x, y, w, h })
    if o.mode == "party" or o.mode == "itemparty" then
      local margin = math.max(18, wh * .025)
      local previewW = x - margin * 2
      if previewW >= math.max(190, ww * .18) then
        add("party-preview", { margin, y, previewW, h })
      end
    end
  elseif tostring(screen.phase or "") == "moves" and not screen.message then
    add("moves", moveDockRect(ww, wh, layout))
  elseif commandReady(screen) then
    add("commands", commandCameraRect(ww, wh, layout))
  elseif screen.message then
    add("message", messageDockRect(ww, wh))
    if promptSelection(screen)
        and (tonumber(screen.messageTimer) or 0) <= 0 then
      add("yes-no", yesNoPromptRect(ww, wh))
    end
  else
    -- drawPhaseHint's compact live-control strip.
    add("phase-hint", { ww*.5-math.min(ww*.24, 270), wh-48,
                         math.min(ww*.48, 540), 40 })
  end
  local safeInsets = { layout.margin*.55, layout.margin*.55,
                       layout.margin*.55, layout.margin*.55 }
  -- Imported BattleLayout profiles may reserve additional normalized edges.
  -- They can only make SMART more conservative; the actual ORAS HUD remains
  -- the lower bound and cannot be displaced by an incomplete profile.
  local safe = type(shot.profileSafeArea) == "table"
    and shot.profileSafeArea or nil
  if safe then
    safeInsets[1] = math.max(safeInsets[1],
      (tonumber(safe.leading) or 0) * ww)
    safeInsets[2] = math.max(safeInsets[2],
      (tonumber(safe.top) or 0) * wh)
    safeInsets[3] = math.max(safeInsets[3],
      (tonumber(safe.trailing) or 0) * ww)
    safeInsets[4] = math.max(safeInsets[4],
      (tonumber(safe.bottom) or 0) * wh)
  end
  return {
    schema=CAMERA_BOUNDS_SCHEMA, width=ww, height=wh,
    safeInsets=safeInsets,
    reserved=reserved,
  }
end

local function hullHitsRect(hull, rect, padding)
  padding = tonumber(padding) or 0
  return hull[1] < rect.x + rect.w + padding
     and hull[1] + hull[3] > rect.x - padding
     and hull[2] < rect.y + rect.h + padding
     and hull[2] + hull[4] > rect.y - padding
end

-- Provider-local SMART verdict.  Complete conservative actor prisms and both
-- ground marks stay on-screen, out of every currently drawn HUD dock, and far
-- enough apart to read as a battle rather than one intersecting sprite.
function M.cameraSafe(screen, shot)
  local bounds, reason = M.cameraBounds(screen, shot)
  if not bounds then return nil, reason end
  local insets = bounds.safeInsets
  local margin = math.max(10, math.min(shot.pw, shot.ph) * .018)
  local left = (tonumber(insets[1]) or 0) + margin
  local top = (tonumber(insets[2]) or 0) + margin
  local right = shot.pw - (tonumber(insets[3]) or 0) - margin
  local bottom = shot.ph - (tonumber(insets[4]) or 0) - margin
  local padding = math.max(7, math.min(shot.pw, shot.ph) * .010)
  local hulls, feet = shot.actorHulls or {}, shot.actorFeet or {}
  local visuals = type(shot.actorVisuals) == "table"
    and shot.actorVisuals or {}
  for _, side in ipairs({ "player", "enemy" }) do
    local hull, foot = hulls[side], feet[side]
    if not (type(hull) == "table" and type(foot) == "table"
        and tonumber(hull[1]) and tonumber(hull[2])
        and tonumber(hull[3]) and tonumber(hull[4])
        and tonumber(foot[1]) and tonumber(foot[2])) then
      return nil, side .. "-projection-unavailable"
    end
    if hull[1] < left or hull[2] < top
        or hull[1]+hull[3] > right or hull[2]+hull[4] > bottom
        or foot[1] < left or foot[1] > right
        or foot[2] < top or foot[2] > bottom then
      return false, side .. "-outside-safe-frame"
    end
    -- Keep the deliberately conservative 16x40 world prism for viewport and
    -- terrain safety, but judge HUD occlusion against the pixels that are
    -- actually drawn. A head-owned status card necessarily overlaps the
    -- empty upper part of the safety prism for small Crystal sprites; treating
    -- that empty volume as visible made every otherwise valid SMART seat fail.
    local visualHull = type(visuals[side]) == "table"
      and type(visuals[side].hull) == "table"
      and visuals[side].hull or hull
    for _, rect in ipairs(bounds.reserved) do
      if hullHitsRect(visualHull, rect, padding) then
        return false, side .. "-under-" .. tostring(rect.id or "hud")
      end
    end
  end
  if rectanglesHit(hulls.player, hulls.enemy, padding) then
    return false, "actor-hulls-overlap"
  end
  local dx = feet.player[1] - feet.enemy[1]
  local dy = feet.player[2] - feet.enemy[2]
  local minDistance = math.max(56, math.min(shot.pw, shot.ph) * .10)
  if dx*dx + dy*dy < minDistance*minDistance then
    return false, "actor-screen-distance"
  end
  local status = {}
  for _, rect in ipairs(bounds.reserved) do
    if tostring(rect.id or ""):find("-status", 1, true) then
      status[#status+1] = rect
    end
  end
  if #status > 1 and status[1].x < status[2].x+status[2].w+padding
      and status[1].x+status[1].w+padding > status[2].x
      and status[1].y < status[2].y+status[2].h+padding
      and status[1].y+status[1].h+padding > status[2].y then
    return false, "status-card-overlap"
  end
  return true, "actor-hulls-and-hud-clear"
end

-- Full live battle replacement: the 3D scene is already on screen, so draw
-- only lightweight HUD furniture around its edges. No 160x144 white panel,
-- native command box or native battle pic/HUD canvas is composited underneath.
-- Crystal's sharp side pictures are captured independently by OverworldBattle
-- and placed as correctly sized world billboards by VoxelScene.
function M.drawFull(screen, ctx)
  local mega = V.Gen2MegaBridge
  if mega then mega.clearPaint(screen) end
  if not (M.owns(screen) and love and love.graphics) then return false end
  -- Direct command activation is valid only after THIS screen's current menu
  -- has actually reached a complete visible ORAS frame. Retire the old receipt
  -- before drawing; publish it below only after every render/cleanup step won.
  commandPresented[screen] = nil
  local G = love.graphics
  local ww, wh = tonumber(ctx and ctx.ww), tonumber(ctx and ctx.wh)
  if not (ww and wh and ww > 0 and wh > 0) then ww, wh = G.getDimensions() end
  if not (ww and wh and ww > 0 and wh > 0) then return false end

  -- Visibility belongs to this paint, never to a stale previous frame.
  local paintState = statusAttachments[screen]
  if paintState then
    if paintState.enemy then paintState.enemy.visible = false end
    if paintState.player then paintState.player.visible = false end
  end

  local presentationReceipt
  local inScene = ctx and ctx.inScene == true
  local presentationTarget = inScene and "scene-canvas" or "final-target"
  local presentationApplied = false
  local presentationOk = true
  local presentationContract = inScene
    and "scene-canvas-receipt" or "final-target-no-transform"
  local statusProjection
  local paintedRects = {}
  local megaRect
  local results = packValues(withGraphicsBoundary("Gen-2 ORAS HUD", function()
    G.origin()
    if CanvasPresentation
        and type(CanvasPresentation.battlePresentation) == "function" then
      presentationReceipt = CanvasPresentation.battlePresentation()
      if type(presentationReceipt) == "table" and inScene then
        presentationContract = presentationReceipt.contract
          or presentationContract
      end
    end
    -- MAP paints into the reflected iOS scene Canvas and therefore consumes
    -- its fixed-Y receipt here. ARENA/DISCS compatibility paints straight on
    -- the final target after GoldComposeBridge has presented the scene; a
    -- second transform there mirrors otherwise-upright HUD pixels.
    if inScene and CanvasPresentation
        and type(CanvasPresentation.beginBattle2D) == "function" then
      presentationApplied = CanvasPresentation.beginBattle2D(
        G, ww, wh, presentationReceipt) ~= false
      presentationOk = presentationApplied
    elseif inScene and type(presentationReceipt) == "table"
        and presentationReceipt.axis ~= nil then
      presentationOk = false
    end
    -- Voxel3D.project publishes coordinates in its current scene Canvas.
    -- The HUD's pre-flipped drawing coordinates describe the final/upright
    -- view, so convert the source actor receipts through the exact same sampled
    -- receipt before placing a head-owned card.
    statusProjection = targetStatusProjection(ctx and ctx.projection, ww, wh,
      inScene and presentationReceipt or nil, inScene)
    G.setBlendMode("alpha")

    local trainerIntro = screen.showEnemyTrainer == true
      or screen.showPlayerTrainer == true or screen.showPlayerBack == true
    -- Kanto does not paint live Pokemon status while either trainer owns the
    -- stage. The cards arrive with the Pokemon after the send-out.
    if not trainerIntro then
      paintedRects.enemy = drawBattlerHud(screen,
        presentedMon(screen, "enemy"), "enemy", ww, wh,
        statusProjection)
      paintedRects.player = drawBattlerHud(screen,
        presentedMon(screen, "player"), "player", ww, wh,
        statusProjection)
    end

    if drawCustomOverlay(screen, ww, wh) then
      -- Complete VASC-owned selector; native rules and callbacks remain live.
    elseif screen.phase == "moves" and not screen.message then
      drawMoves(screen, ww, wh)
    elseif commandReady(screen) then
      megaRect = drawNativeCommandGrid(screen, ww, wh)
    end

    -- A message is animation/dialogue furniture, never a second layer behind
    -- an interactive command or move dock.
    if screen.message and screen.phase ~= "menu" and screen.phase ~= "moves" then
      drawMessage(screen, ww, wh)
      drawYesNoPrompt(screen, ww, wh)
    end
    drawPhaseHint(screen, ww, wh)
  end))
  if not results[1] then error(results[2], 0) end

  if commandVisualReady(screen) then commandPresented[screen] = true end
  if mega and commandPresented[screen] then
    mega.publish(screen, megaRect, ww, wh)
  end

  if PerformanceDiagnostics
      and type(PerformanceDiagnostics.reportHud) == "function" then
    local player = paintedRects.player
    local enemy = paintedRects.enemy
    local function inside(rect)
      return type(rect) ~= "table" or (tonumber(rect.x) or 0) >= 0
        and (tonumber(rect.y) or 0) >= 0
        and (tonumber(rect.x) or 0) + (tonumber(rect.w) or 0) <= ww
        and (tonumber(rect.y) or 0) + (tonumber(rect.h) or 0) <= wh
    end
    local inBounds = inside(player) and inside(enemy)
    local enemyVisual = statusProjection and statusProjection.actorVisuals
      and statusProjection.actorVisuals.enemy
    pcall(PerformanceDiagnostics.reportHud, {
      hud="GEN2-ORAS", viewportWidth=ww, viewportHeight=wh,
      orientation=presentationReceipt and presentationReceipt.orientation,
      axis=presentationReceipt and presentationReceipt.axis,
      source=presentationReceipt and presentationReceipt.source or "desktop",
      target=presentationTarget, contract=presentationContract,
      presentationApplied=presentationApplied,
      inBounds=inBounds, orientationOk=presentationOk,
      reason=not presentationOk and "scene-canvas-presentation-failed"
        or inBounds and "anchors-in-bounds" or "status-anchor-out-of-bounds",
      playerX=player and player.x, playerY=player and player.y,
      playerWidth=player and player.w, playerHeight=player and player.h,
      enemyX=enemy and enemy.x, enemyY=enemy and enemy.y,
      enemyWidth=enemy and enemy.w, enemyHeight=enemy and enemy.h,
      projectionSpace=ctx and ctx.projection and ctx.projection.coordinateSpace,
      enemyHeadX=enemyVisual and enemyVisual.head and enemyVisual.head.x,
      enemyHeadY=statusVisualTop(enemyVisual),
    })
  end

  M.draws = M.draws + 1
  M.fullDraws = M.fullDraws + 1
  return true
end

-- v0.2.32: draw directly into the live VoxelScene canvas before endScene().
-- This is the guaranteed path for Gold live battles: if the Pokemon/world are
-- visible, this canvas is visible too. The later compositor only needs to know
-- whether this succeeded so it can avoid double-drawing or fail open to Gold.
function M.drawIntoScene(screen, w, h, canvas, projection)
  M.sceneDrawn = false
  M.sceneReceipt = nil
  M.lastSceneHudError = nil
  if not (M.owns(screen) and love and love.graphics) then return false end
  local ok, yes = pcall(M.drawFull, screen, {
    ww = w, wh = h, inScene = true, projection = projection,
  })
  M.sceneDrawn = ok and yes and true or false
  if M.sceneDrawn then
    M.sceneDraws = M.sceneDraws + 1
    M.sceneReceipt = {
      schema = "voxel-ascendant/gen2-scene-hud/v1",
      screen = screen,
      battle = screen.battle,
      canvas = canvas,
      projection = projection,
    }
  elseif not ok then
    M.lastSceneHudError = tostring(yes)
  end
  return M.sceneDrawn
end

function M.sceneHasHud(screen, canvas)
  local receipt = M.sceneReceipt
  return type(screen) == "table"
    and M.sceneDrawn == true and type(receipt) == "table"
    and receipt.schema == "voxel-ascendant/gen2-scene-hud/v1"
    and receipt.screen == screen
    and receipt.battle == screen.battle
    and receipt.canvas == canvas
end

function M.clearSceneHudFlag()
  M.sceneDrawn = false
  M.sceneReceipt = nil
end

-- Compatibility alias for callers from 0.2.28/0.2.29.
function M.draw(screen, ctx)
  return M.drawFull(screen, ctx)
end

function M.screen(game)
  return screenOf(game or installedGame)
end

function M.status()
  local activeScreen = screenOf(installedGame)
  return {
    installed = M.installed,
    shortcuts = M.shortcuts,
    draws = M.draws,
    fullDraws = M.fullDraws,
    sceneDraws = M.sceneDraws,
    sceneDrawn = M.sceneDrawn,
    sceneReceipt = M.sceneReceipt and M.sceneReceipt.schema or nil,
    customUI = customUIEnabled(),
    battleCommands = battleCommandsEnabled(),
    nativeBattleUI = not battleCommandsEnabled(),
    presentationOnly = true,
    qol = M.qolSettings(activeScreen),
    visualLanguage = "shared-oras-glass-v1",
    sharedOrasActionAssets = true,
    inputOwner = "engine-native",
    commandVisible = battleCommandsEnabled()
      and commandReady(screenOf(installedGame)) and overlay == nil,
    commandInputArmed = commandInputReady(screenOf(installedGame)),
    autoIntroPrompts = M.autoIntroPrompts or 0,
    lastAutoIntroError = M.lastAutoIntroError,
    customMenu = overlay and overlay.mode or nil,
    partyPreview = partyPreviewCache and partyPreviewCache ~= false,
    lastPartyPreviewError = M.lastPartyPreviewError,
    lastSceneHudError = M.lastSceneHudError,
    lastShortcutError = M.lastShortcutError,
    controls = battleCommandsEnabled()
      and "left stick/WASD Pokemon; Triangle Fight Square Pack Cross PKMN Circle Run; arrows mirror the visible Kanto layout; right stick camera"
      or "Gold original battle UI/input",
  }
end

-- Narrow, read-only regression seams. They expose the two presentation
-- decisions that physical capture/HUD tests need without granting tests a way
-- to mutate battle rules or the private latches themselves.
M._qa = {
  speciesCaught = speciesCaught,
  projectedStatusRect = projectedStatusRect,
  targetStatusProjection = targetStatusProjection,
}

return M
