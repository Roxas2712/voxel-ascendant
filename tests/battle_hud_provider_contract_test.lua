-- VASC/KASC battle-HUD ownership and fail-open contract.
--
-- This harness executes the actual OrasBattleHudSettings module and the
-- actual provider compositor captured from OverworldBattle.update. It uses
-- headless canvas stubs only; no production function is copied here.

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected " .. tostring(expected)
      .. ", got " .. tostring(actual), 2)
  end
end

local function check(value, message)
  if not value then error(message or "check failed", 2) end
end

local function read(path)
  local handle = assert(io.open(path, "rb"))
  local value = assert(handle:read("*a"))
  handle:close()
  return value
end

-- -------------------------------------------------------------------------
-- VASC-owned settings: ORAS default, explicit STANDARD, delegation and the
-- one-time legacy HUD POS=FRAME migration.
-- -------------------------------------------------------------------------

local stored = {}
local kascHandle = nil
local SettingsV = {
  mod = {
    id = "VOXEL_ASCENDANT",
    options = { get=function(_, key) return stored[key] end },
    find = function(id)
      if kascHandle and id == "kanto_ascendant" then return kascHandle end
    end,
  },
}
local settingsCache = {}
function SettingsV.require(name)
  if settingsCache[name] then return settingsCache[name] end
  eq(name, "ModSetting", "unexpected settings dependency")
  settingsCache[name] = assert(loadfile("lib/ModSetting.lua"))(SettingsV)
  return settingsCache[name]
end

local Settings = assert(loadfile("lib/OrasBattleHudSettings.lua"))(SettingsV)
eq(Settings.uiSkinSetting:get(), "oras", "native menu skin default")
Settings.uiSkinSetting:sync("standard")
eq(Settings.uiSkinSetting:get(), "standard",
  "native menu skin did not switch independently")
Settings.uiSkinSetting.index = nil
eq(Settings.bagSkinSetting:get(), "external",
  "GAME/KASC was not the safe Bag presentation default")
eq(table.concat(Settings.bagSkinSetting.values, "/"),
  "external/oras_wide/frlg_wide",
  "Bag presentation stored-value ladder")
eq(table.concat(Settings.bagSkinSetting.labels, "/"),
  "GAME/KASC/D/P ORAS WIDE/FRLG ORAS WIDE",
  "Bag presentation labels")
Settings.bagSkinSetting:sync("oras")
eq(Settings.bagSkinSetting:get(), "oras_wide",
  "legacy D/P compact choice did not migrate to WIDE")
Settings.bagSkinSetting:sync("frlg")
eq(Settings.bagSkinSetting:get(), "frlg_wide",
  "legacy FRLG compact choice did not migrate to WIDE")
Settings.bagSkinSetting:sync("oras_wide")
eq(Settings.bagSkinSetting:get(), "oras_wide",
  "D/P ORAS WIDE Bag presentation was not selectable")
Settings.bagSkinSetting:sync("frlg_wide")
eq(Settings.bagSkinSetting:get(), "frlg_wide",
  "FRLG ORAS WIDE Bag presentation was not selectable")
Settings.bagSkinSetting.index = nil
eq(Settings.bagColorSetting:get(), "auto", "Bag accent default")
eq(table.concat(Settings.bagColorSetting.values, "/"),
  "auto/red/blue/green", "Bag accent stored-value ladder")
Settings.bagColorSetting:sync("blue")
eq(Settings.bagColorSetting:get(), "blue",
  "Bag accent did not switch independently")
Settings.bagColorSetting.index = nil
eq(Settings.bagBodySetting:get(), "auto", "Bag body default")
eq(table.concat(Settings.bagBodySetting.values, "/"),
  "auto/oras/red/blue/yellow/gold/silver/crystal",
  "Bag body/edition stored-value ladder")
Settings.bagBodySetting:sync("crystal")
eq(Settings.bagBodySetting:get(), "crystal",
  "Bag body did not switch independently")
Settings.bagBodySetting.index = nil
eq(Settings.bagFormSetting:get(), "auto", "Bag form default")
eq(table.concat(Settings.bagFormSetting.values, "/"),
  "auto/round/handle", "Bag form stored-value ladder")
Settings.bagFormSetting:sync("handle")
eq(Settings.bagFormSetting:get(), "handle",
  "Bag form did not switch independently")
Settings.bagFormSetting.index = nil

local bagWrites = 0
local bagSettingsGame = {
  save={ options={ modOptions={} } }, mods={ modOptions={} },
  writeOptions=function() bagWrites = bagWrites + 1 end,
}
Settings.bagSkinSetting:setValue("external", bagSettingsGame)
Settings.bagColorSetting:setValue("green", bagSettingsGame)
Settings.bagBodySetting:setValue("silver", bagSettingsGame)
Settings.bagFormSetting:setValue("handle", bagSettingsGame)
eq(bagSettingsGame.save.options.modOptions.VOXEL_ASCENDANT.qol_bag_skin,
  "external", "safe Bag owner choice was not saved")
eq(bagSettingsGame.mods.modOptions.VOXEL_ASCENDANT.qol_bag_skin,
  "external", "safe Bag owner choice did not update the live loader bucket")
eq(bagSettingsGame.save.options.modOptions.VOXEL_ASCENDANT.qol_bag_color,
  "green", "Bag accent was not saved")
eq(bagSettingsGame.save.options.modOptions.VOXEL_ASCENDANT.qol_bag_body,
  "silver", "Bag body/edition colour was not saved")
eq(bagSettingsGame.save.options.modOptions.VOXEL_ASCENDANT.qol_bag_form,
  "handle", "Bag form was not saved")
check(bagWrites >= 4, "Bag appearance settings were not persisted immediately")
Settings.bagSkinSetting.index = nil
Settings.bagColorSetting.index = nil
Settings.bagBodySetting.index = nil
Settings.bagFormSetting.index = nil
eq(Settings.style(), "oras", "VASC standalone HUD default")
eq(Settings.vascOwnsHud(SettingsV.mod), true,
  "VASC did not own its standalone HUD")
eq(Settings.orasSelected(SettingsV.mod), true,
  "standalone default did not select ORAS")
eq(Settings.standardSelected(SettingsV.mod), false,
  "standalone default selected STANDARD")
local standaloneReceipt = Settings.receipt(SettingsV.mod)
eq(standaloneReceipt.owner, "VOXEL_ASCENDANT", "standalone owner receipt")
eq(standaloneReceipt.style, "oras", "standalone style receipt")
eq(standaloneReceipt.mega, false,
  "VASC without KASC advertised Mega controls")

Settings.styleSetting:sync("standard")
eq(Settings.orasSelected(SettingsV.mod), false,
  "battleHudStyle=standard retained ORAS")
eq(Settings.standardSelected(SettingsV.mod), true,
  "battleHudStyle=standard did not select native/readable HUD")

kascHandle = { exports={} }
eq(Settings.vascOwnsHud(SettingsV.mod), true,
  "mere KASC installation displaced VASC HUD ownership")
eq(Settings.orasSelected(SettingsV.mod), false,
  "STANDARD unexpectedly switched back to ORAS beside KASC")
eq(Settings.standardSelected(SettingsV.mod), true,
  "VASC STANDARD disappeared beside a non-claiming KASC")
local installedReceipt = Settings.receipt(SettingsV.mod)
eq(installedReceipt.owner, "VOXEL_ASCENDANT", "installed-only owner receipt")
eq(installedReceipt.delegated, false, "installed-only delegated receipt flag")
eq(installedReceipt.style, "standard", "installed-only style receipt")
eq(installedReceipt.kascInstalled, true, "KASC installation receipt")
eq(installedReceipt.mega, false, "empty KASC export advertised Mega")

kascHandle = { exports={ megaEvolution={} } }
eq(Settings.vascOwnsHud(SettingsV.mod), true,
  "KASC Mega capability displaced VASC presentation ownership")
eq(Settings.receipt(SettingsV.mod).mega, true,
  "KASC Mega capability was not reported")

kascHandle = { exports={ ascendantBattleHud={
  apiVersion=1, claimsVascHud=true,
} } }
eq(Settings.vascOwnsHud(SettingsV.mod), false,
  "explicit KASC HUD claimant did not receive ownership")
local delegatedReceipt = Settings.receipt(SettingsV.mod)
eq(delegatedReceipt.owner, "kanto_ascendant", "delegated owner receipt")
eq(delegatedReceipt.delegated, true, "delegated receipt flag")
eq(delegatedReceipt.style, "kasc", "delegated style receipt")
eq(delegatedReceipt.claimSource, "export", "delegated claim source")

kascHandle = nil
Settings.styleSetting.index = nil
local writes = 0
local migrationGame = {
  save={ options={ modOptions={ VOXEL_ASCENDANT={
    battleHudPosition="frame",
  } } } },
  mods={ modOptions={ VOXEL_ASCENDANT={
    battleHudPosition="frame",
  } } },
  writeOptions=function() writes = writes + 1 end,
}
local positionSetting = {
  setValue=function(_, value, game)
    game.save.options.modOptions.VOXEL_ASCENDANT.battleHudPosition = value
    game.mods.modOptions.VOXEL_ASCENDANT.battleHudPosition = value
    return value
  end,
}
eq(Settings.migrateLegacyFrame(
  SettingsV.mod, migrationGame, positionSetting), true,
  "legacy FRAME was not migrated")
eq(migrationGame.save.options.modOptions.VOXEL_ASCENDANT.battleHudStyle,
  "standard", "save migration did not select STANDARD")
eq(migrationGame.mods.modOptions.VOXEL_ASCENDANT.battleHudStyle,
  "standard", "loader migration did not select STANDARD")
eq(migrationGame.save.options.modOptions.VOXEL_ASCENDANT.battleHudPosition,
  "auto", "save migration did not retire FRAME")
eq(migrationGame.mods.modOptions.VOXEL_ASCENDANT.battleHudPosition,
  "auto", "loader migration did not retire FRAME")
check(writes >= 1, "legacy migration was not persisted")
eq(Settings.migrateLegacyFrame(
  SettingsV.mod, migrationGame, positionSetting), false,
  "legacy migration was not idempotent")

local explicit = {
  save={ options={ modOptions={ VOXEL_ASCENDANT={
    battleHudStyle="oras", battleHudPosition="frame",
  } } } },
  mods={ modOptions={} },
}
eq(Settings.migrateLegacyFrame(SettingsV.mod, explicit, positionSetting), false,
  "explicit modern style was overwritten by legacy migration")

kascHandle = { exports={ battleHudOwnership={
  apiVersion=1, claimsVascHud=true,
} } }
local delegatedLegacy = {
  save={ options={ modOptions={ VOXEL_ASCENDANT={
    battleHudPosition="frame",
  } } } },
  mods={ modOptions={} },
}
eq(Settings.migrateLegacyFrame(
  SettingsV.mod, delegatedLegacy, positionSetting), false,
  "VASC migrated HUD ownership while KASC was active")
kascHandle = nil

-- VASC owns presentation and may consume KASC's exact public Mega capability.
-- Without that capability it remains autonomous and fails closed.
local orasSource = read("battle_hud_oras.lua")
check(orasSource:find(
  'local Diagnostics = { write=function() return false end }', 1, true),
  "ORAS HUD lost its optional no-op diagnostics fallback")
check(orasSource:find(
  'local ok, value = pcall(V.require, "Diagnostics")', 1, true),
  "ORAS HUD no longer resolves diagnostics fail-open through VASC")
check(orasSource:find(
  'local mega = kasc and kasc.megaEvolution', 1, true),
  "ORAS factory gained a non-KASC Mega source")
check(not orasSource:find(
  'if INTEGRATED_VASC then return nil end', 1, true),
  "integrated VASC still hard-disables an eligible KASC Mega")
check(orasSource:find(
  'if not mega then return nil end', 1, true),
  "Mega visibility no longer fails closed without KASC")
check(orasSource:find(
  'if type(mega.canActivate) == "function" then', 1, true),
  "Mega visibility no longer prefers KASC readiness authority")
check(orasSource:find(
  'and type(mega.available) == "function") then return nil end', 1, true),
  "legacy KASC fallback no longer requires profile and availability")
check(orasSource:find(
  'local mega = profile and FloatingHud.styleAsset("mega") or nil', 1, true),
  "move picker no longer hides Mega without a profile")
check(orasSource:find(
  'local registerProvider = INTEGRATED_VASC\n  and registerBundledProvider',
  1, true), "integrated VASC no longer uses its bounded default-provider slot")
check(orasSource:find(
  'type(registerBundledProvider) == "function"', 1, true),
  "integrated VASC no longer recognizes its bounded provider capability")
check(orasSource:find('or "voxel_ascendant.oras"', 1, true),
  "VASC ORAS provider id changed or disappeared")
check(orasSource:find(
  'local key = INTEGRATED_VASC and "battleHudStyle" or "battle_hud_style"',
  1, true), "integrated VASC no longer reads battleHudStyle")
check(orasSource:find(
  'return optionChoice(key, "oras"):lower() ~= "standard"', 1, true),
  "battleHudStyle=standard no longer makes the ORAS provider decline")
check(orasSource:find(
  'pcall(OverworldBattle.presentationPlan, battle)', 1, true),
  "ORAS provider no longer reads the exact battle presentation plan")

-- Execute the actual typewriter-page adapter. The engine clears `current` in
-- the same update that begins msgHold; the provider must then promote its
-- cached complete source page instead of freezing the last partial glyph.
;(function()
local messageStart = assert(orasSource:find(
  "local function splitBattleMessageText", 1, true))
local messageEnd = assert(orasSource:find(
  "\nlocal function visibleTextBoxMessageLines", messageStart, true)) - 1
local messageChunk, messageError = (loadstring or load)([=[
local Font = { split=function(text)
  local out = {}
  for i = 1, #text do out[i] = { to=i } end
  return out
end }
]=] .. orasSource:sub(messageStart, messageEnd) .. [=[
return visibleBattleMessageLines
]=], "@actual-vasc-full-message-hold")
assert(messageChunk, messageError)
local visibleLines = messageChunk()
local item = { text="BLIZZARD!", done=false }
local messageBattle = {
  current=item, shown={{1,2,3,4,5,6,7}}, lineIndex=1,
}
eq(visibleLines(messageBattle)[1], "BLIZZAR",
  "typewriter frame did not retain its genuine partial glyph count")
messageBattle.current = nil
messageBattle.msgHold = true
eq(visibleLines(messageBattle)[1], "BLIZZARD!",
  "message hold froze the last partial glyph instead of the full source page")
local nextItem = { text="THUNDER!", done=false }
messageBattle.current, messageBattle.msgHold = nextItem, false
messageBattle.shown = {{1,2,3}}
eq(visibleLines(messageBattle)[1], "THU",
  "new message item reused the previous page cache")
local promptItem = { text="Enemy PIDGEY fainted! PROMPT", done=true }
messageBattle.current, messageBattle.msgPrompt = promptItem, nil
messageBattle.shown = {{}}
eq(visibleLines(messageBattle)[1], "Enemy PIDGEY fainted!",
  "terminal prompt leaked before the engine entered its wait phase")
messageBattle.current, messageBattle.msgHold = nil, true
eq(visibleLines(messageBattle)[1], "Enemy PIDGEY fainted!",
  "terminal prompt survived in the cached animation hold")
messageBattle.msgHold = nil
messageBattle.current, messageBattle.msgPrompt = promptItem, true
messageBattle.shown = {{}}
eq(visibleLines(messageBattle)[1], "Enemy PIDGEY fainted!",
  "terminal Gen1 prompt opcode leaked into the visible sentence")
local proseItem = { text="Choose a PROMPT example", done=true }
messageBattle.current, messageBattle.msgPrompt = proseItem, false
eq(visibleLines(messageBattle)[1], "Choose a PROMPT example",
  "ordinary prose was mistaken for a terminal prompt opcode")
for _, marker in ipairs({" PROMPT", " <PROMPT>", " [PROMPT]", "{PROMPT}",
    "{PROMPT}\vNext page",
    " PROMPT\n", "<PROMPT>\vNext page", " [PROMPT]\n"}) do
  messageBattle.current = {text="Wild RATTATA appeared!" .. marker, done=false}
  messageBattle.msgPrompt, messageBattle.msgHold, messageBattle.msgWaiting =
    nil, nil, nil
  messageBattle.shown = {{1,2,3,4}}
  eq(visibleLines(messageBattle)[1], "Wild",
    "marker cleaning advanced genuine typewriter progress")
  messageBattle.shown = {{}}
  for n=1,60 do messageBattle.shown[1][n]=n end
  eq(visibleLines(messageBattle)[1], "Wild RATTATA appeared!",
    "terminal control marker leaked while typing before msgPrompt")
  messageBattle.current, messageBattle.msgHold = nil, true
  eq(visibleLines(messageBattle)[1], "Wild RATTATA appeared!",
    "terminal control marker survived the cached full page")
end
end)()

-- Execute the mobile START/SELECT avoidance geometry. The message plate uses
-- the engine's live orientation-specific touch layout and remains above both
-- central controls instead of making its text unreadable underneath them.
;(function()
local touchStart = assert(orasSource:find(
  "function FloatingHud.touchStartSelectTop", 1, true))
local touchEnd = assert(orasSource:find(
  "\nlocal function battleMessageActive", touchStart, true)) - 1
local messageRectStart = assert(orasSource:find(
  "function HudRuntime.messageRectFor", touchEnd, true))
local messageRectEnd = assert(orasSource:find(
  "\nfunction HudRuntime.mapPanelHits", messageRectStart, true)) - 1
local geometryChunk, geometryError = (loadstring or load)([=[
local FloatingHud = {
  MESSAGE={ scale=1 }, MARGIN=4,
  panelLogicalSize=function() return 288, 64 end,
  safeInsets=function() return 0, 0, 0, 0 end,
}
local TouchControls = {
  visible=function() return true end,
  layout=function() return {
    select={ cx=440, cy=390, w=54 },
    start={ cx=516, cy=390, w=54 },
  } end,
}
local PLATFORM_OS = "iOS"
local g = { getDimensions=function() return 956, 440 end }
local function hudStyle() return "oras" end
local function uiScale() return 2 end
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function distanceScale() return 1 end
local HudRuntime = {}
local function optionChoice(_, fallback) return fallback end
]=] .. orasSource:sub(assert(orasSource:find("function FloatingHud.positionTextbox(",1,true)), messageRectStart-1) .. "\n" .. orasSource:sub(touchStart, touchEnd) .. "\n"
  .. orasSource:sub(messageRectStart, messageRectEnd) .. [=[
return FloatingHud, HudRuntime, function() TouchControls.visible=function() return false end end
]=], "@actual-mobile-message-control-clearance")
assert(geometryChunk, geometryError)
local GeometryHud, GeometryRuntime, disableTouch = geometryChunk()
local shot = { pw=956, ph=440, scale=2, player={80,96}, enemy={80,56} }
local controlTop = assert(GeometryHud.touchStartSelectTop(shot))
local rect = assert(GeometryRuntime.messageRectFor(shot))
check(rect[2] + rect[4] < controlTop,
  "mobile message plate still overlaps START/SELECT")
-- The same reviewed arena foot marks are used on desktop. A low contact
-- must not make a trainer intro/faint message retire the entire renderer.
disableTouch()
shot.actorVisuals = { player={hull={300,250,180,100}},
                     enemy={hull={610,180,70,100}} }
local fitted, scale = GeometryRuntime.messageRectFor(shot)
check(fitted[2] > 350 + 8, "desktop message covers exact actor ink")
check(fitted[2] + fitted[4] == shot.ph, "desktop message lost bottom dock")
check(scale >= 1, "dialog text shrank below native scale")
shot.actorVisuals = nil
local ordinary = GeometryRuntime.messageRectFor(shot)
check(ordinary[4] > fitted[4], "ordinary dialog did not restore preferred size")
end)()

-- Execute the actual enable predicate: live option edits must not change the
-- owner of an already-started battle, while the following battle receives the
-- new option. This must stay coupled to the back-sprite plan, not merely be a
-- source-level claim in OverworldBattle.
local enabledStart = assert(orasSource:find(
  "local function battleHudEnabled", 1, true))
local enabledEnd = assert(orasSource:find(
  "\nlocal function companionHandle", enabledStart, true)) - 1
local enabledChunk, enabledCompileError = (loadstring or load)([=[
local INTEGRATED_VASC = true
local isAscendantHost = true
local liveStyle = "oras"
local activeBattle, activePlan = nil, nil
local OverworldBattle = {
  presentationPlan=function(expected)
    if expected ~= nil and expected ~= activeBattle then return nil end
    return activePlan
  end,
}
local function optionChoice() return liveStyle end
]=] .. orasSource:sub(enabledStart, enabledEnd) .. [=[
return battleHudEnabled, function(battle, plan, style)
  activeBattle, activePlan, liveStyle = battle, plan, style
end
]=], "@actual-vasc-battle-hud-plan")
assert(enabledChunk, enabledCompileError)
local plannedHudEnabled, setHudPlan = enabledChunk()
local plannedBattle, foreignBattle = {}, {}
setHudPlan(nil, nil, "oras")
eq(plannedHudEnabled(), true, "live ORAS option did not enable provider")
setHudPlan(plannedBattle, {standardHud=true}, "oras")
eq(plannedHudEnabled(plannedBattle), false,
  "latched STANDARD battle changed to live ORAS")
setHudPlan(plannedBattle, {standardHud=false}, "standard")
eq(plannedHudEnabled(plannedBattle), true,
  "latched ORAS battle changed to live STANDARD")
setHudPlan(plannedBattle, {standardHud=true}, "oras")
eq(plannedHudEnabled(foreignBattle), false,
  "foreign BattleState used the live ORAS option without an exact plan")
check(orasSource:find(
  'and FloatingHud.wildDVsEnabled()', 1, true),
  "wild DV toggle no longer reads the live option bucket")
check(orasSource:find(
  'return optionEnabled("wild_dvs", false)', 1, true),
  "wild DV toggle no longer normalizes string-backed toggle values")

-- Execute the production option normalizer. Loader toggles and the live save
-- bucket can expose booleans, numbers, or their string representations; all
-- supported true spellings must actually enable the row, not merely appear in
-- the menu while the renderer compares a string with boolean true.
local optionStart = assert(orasSource:find(
  "local function optionChoice", 1, true))
local optionEnd = assert(orasSource:find(
  "\nlocal function glassStrength", optionStart, true)) - 1
local optionChunk, optionCompileError = (loadstring or load)([=[
local FloatingHud = {}
local activeRuntimeGame = nil
local boot = {}
local mod = {
  id="VOXEL_ASCENDANT", world=nil,
  options={get=function(_, key) return boot[key] end},
}
]=] .. orasSource:sub(optionStart, optionEnd) .. [=[
return FloatingHud, boot, function(game) activeRuntimeGame = game end
]=], "@actual-vasc-option-toggle")
assert(optionChunk, optionCompileError)
local OptionHud, optionBoot, setOptionGame = optionChunk()
optionBoot.wild_dvs = true
eq(OptionHud.wildDVsEnabled(), true, "boolean boot toggle did not enable DVs")
optionBoot.wild_dvs = "false"
eq(OptionHud.wildDVsEnabled(), false, "false boot toggle enabled DVs")
setOptionGame({save={options={modOptions={VOXEL_ASCENDANT={
  wild_dvs="1",
}}}}})
eq(OptionHud.wildDVsEnabled(), true, "live string toggle did not enable DVs")
setOptionGame({save={options={modOptions={VOXEL_ASCENDANT={
  wild_dvs=false,
}}}}})
eq(OptionHud.wildDVsEnabled(), false, "live false toggle enabled DVs")
check(orasSource:find(
  'if not hudGenderEnabled() then return nil end', 1, true),
  "ORAS status cards ignore the live HUD GENDER setting")
check(orasSource:find(
  'drawEXPFill(layout, expRatio(battle, battler), hudExpChoice(battle))',
  1, true), "ORAS status cards ignore the live HUD EXP setting")
check(orasSource:find(
  'hudCaughtChoice(battle))', 1, true),
  "ORAS status cards ignore the live HUD CAUGHT setting")
check(orasSource:find(
  'elseif showWildDVs(battle, side, battler) then', 1, true),
  "compact ORAS wild status card no longer renders the enabled DV row")
check(orasSource:find(
  'drawShadowText(prefix .. text, 7, logicalH - 13, k, scale)', 1, true),
  "compact ORAS wild DV row lost its reserved lower-band placement")
check(not orasSource:find('vascDelegatesToKasc', 1, true),
  "mere KASC installation still disables the VASC HUD provider")
check(orasSource:find(
  'return FloatingHud.hasExactHudSnapReceipt(state)', 1, true),
  "KASC QoL overlay suppression is not gated by the exact VASC frame receipt")
check(orasSource:find(
  'type(battleService.setHudOwnerPredicate) == "function"', 1, true),
  "KASC QoL overlay ownership lost its public service boundary")
check(not orasSource:find('_ascendantBattleHudOverlayWrapper', 1, true),
  "VASC still replaces the KASC battle draw function")
check(not orasSource:find('modOptions.kanto_ascendant', 1, true),
  "VASC still mutates KASC options as an overlay fallback")

-- Execute the exact ownership bridge. A current KASC provider receives the
-- read-only predicate; an older provider without that public seam must remain
-- completely untouched rather than being wrapped or having options changed.
local suppressionStart = assert(orasSource:find(
  "function FloatingHud.installKascOverlaySuppression", 1, true))
local suppressionEnd = assert(orasSource:find(
  "\nend\n\nFloatingHud.installNativeHudSuppression", suppressionStart, true))
suppressionEnd = suppressionEnd + #"\nend" - 1
local suppressionChunk, suppressionError = (loadstring or load)([=[
local ACTIVE_KASC = nil
local OWNS, EXACT = false, false
local FloatingHud = {
  ownsHostStatus=function() return OWNS end,
  hasExactHudSnapReceipt=function() return EXACT end,
}
local function kascExports() return ACTIVE_KASC end
]=] .. orasSource:sub(suppressionStart, suppressionEnd) .. [=[

return FloatingHud,
  function(value) ACTIVE_KASC = value end,
  function(owns, exact) OWNS, EXACT = owns, exact end
]=], "@actual-kasc-overlay-ownership-bridge")
assert(suppressionChunk, suppressionError)
local SuppressionHud, setKasc, setOwnership = suppressionChunk()
local originalDraw = function() return "native" end
local originalOptions = { modOptions={ kanto_ascendant={
  qol_exp_bar="blue", qol_caught_indicator="red",
} } }
local legacyBattle = {
  draw=originalDraw,
  game={ save={ options=originalOptions } },
}
setKasc({ qualityOfLife={ battle={} } })
eq(SuppressionHud.installKascOverlaySuppression(legacyBattle), false,
  "legacy KASC without public ownership seam did not fail open")
eq(legacyBattle.draw, originalDraw,
  "legacy KASC battle draw was replaced by VASC")
eq(legacyBattle.game.save.options, originalOptions,
  "legacy KASC options container was replaced by VASC")
eq(originalOptions.modOptions.kanto_ascendant.qol_exp_bar, "blue",
  "legacy KASC EXP option was mutated by VASC")
eq(originalOptions.modOptions.kanto_ascendant.qol_caught_indicator, "red",
  "legacy KASC caught option was mutated by VASC")

local ownerPredicate
local ownerReceipt = {}
setKasc({ qualityOfLife={ battle={
  setHudOwnerPredicate=function(_, predicate)
    ownerPredicate = predicate
    return ownerReceipt
  end,
} } })
eq(SuppressionHud.installKascOverlaySuppression(legacyBattle), ownerReceipt,
  "public KASC HUD ownership receipt was not returned")
check(type(ownerPredicate) == "function",
  "public KASC HUD ownership predicate was not installed")
setOwnership(false, true)
eq(ownerPredicate({}), false, "non-owned VASC status suppressed KASC overlays")
setOwnership(true, false)
eq(ownerPredicate({}), false, "uncommitted VASC HUD suppressed KASC overlays")
setOwnership(true, true)
eq(ownerPredicate({}), true, "exact VASC HUD receipt did not yield KASC overlays")

check(orasSource:find('local bottom = 0\n', 1, true),
  "ORAS command dock no longer ends at the physical bottom edge")
check(not orasSource:find('local bottom = insetBottom + safe', 1, true),
  "ORAS command dock regained a synthetic gap above the bottom edge")
check(not orasSource:find('local bottom = insetBottom\n', 1, true),
  "mobile safe-area inset still lifts the ORAS command dock")
check(orasSource:find('local y = shot.ph - h', 1, true),
  "ORAS message panel no longer shares the command dock bottom edge")
check(orasSource:find(
  'function FloatingHud.projectOwnerStatusRect(shot, side)', 1, true),
  "ORAS status cards lost their initial owner-head projection")
check(orasSource:find(
  'function FloatingHud.proposeStatusLatch(', 1, true),
  "ORAS status cards lost their pure per-battle latch proposal")
check(orasSource:find(
  'local safariStatusRect = FloatingHud.safariBallCountBounds(battle, shot)',
  1, true),
  "ORAS renderer no longer reserves the exact Safari balls band")
check(orasSource:find(
  'statusReserved[#statusReserved + 1] = safariStatusRect', 1, true),
  "ORAS renderer does not feed the Safari band into its status proposal")
check(orasSource:find(
  'function FloatingHud.commitStatusLatch(', 1, true),
  "ORAS status cards lost their transactional latch commit")
check(orasSource:find('context.afterCommit(function()', 1, true),
  "ORAS status latch still commits before provider pixels")
check(orasSource:find('finishBattle = function(battle)', 1, true),
  "ORAS provider no longer clears its per-battle latch")
check(orasSource:find('voxel-ascendant/actor-render/v1', 1, true),
  "ORAS status cards no longer require exact actor render receipts")

-- Execute the real live-choice adapters. This catches the old boot-value bug:
-- changing a VASC/KASC menu value must affect the very next ORAS provider draw
-- without rebuilding the HUD factory or restarting the process.
do
local extraStart = assert(orasSource:find(
  "local function hudGenderEnabled", 1, true))
local extraEnd = assert(orasSource:find(
  "\nlocal function showWildDVs", extraStart, true))
local liveExtra = { gender=true, exp="blue", caught="red" }
local extraChunk, extraCompileError = (loadstring or load)([[
local LIVE = ...
local BattleHudExtras = {
  genderEnabled=function() return LIVE.gender end,
  expChoice=function() return LIVE.exp end,
  caughtChoice=function() return LIVE.caught end,
}
]] .. orasSource:sub(extraStart, extraEnd - 1)
   .. [[
return hudGenderEnabled, hudExpChoice, hudCaughtChoice
]], "@actual-vasc-live-hud-extra-choices")
assert(extraChunk, extraCompileError)
local liveGender, liveExp, liveCaught = extraChunk(liveExtra)
eq(liveGender(), true, "initial HUD GENDER choice")
eq(liveExp({ game={} }), "blue", "initial HUD EXP choice")
eq(liveCaught({ game={} }), "red", "initial HUD CAUGHT choice")
liveExtra.gender, liveExtra.exp, liveExtra.caught = false, "off", "grey"
eq(liveGender(), false, "HUD GENDER did not update live")
eq(liveExp({ game={} }), "off", "HUD EXP did not update live")
eq(liveCaught({ game={} }), "grey", "HUD CAUGHT did not update live")

local markerStart = assert(orasSource:find(
  "local function caughtSpecies", 1, true))
local markerEnd = assert(orasSource:find(
  "\nlocal function hpDV", markerStart, true))
local markerControl = {
  caught="red", shiny=true, shinyEffects=true, eventRosette=true,
}
local markerChunk, markerCompileError = (loadstring or load)([[
local CONTROL = ...
local FloatingHud = {}
local function wildBattle(battle)
  return battle and (battle.kind == "wild" or battle.kind == "safari")
end
local function hudCaughtChoice() return CONTROL.caught end
local function kascOptionEnabled(key)
  if key == "shiny_effects" then return CONTROL.shinyEffects end
  if key == "event_rosette" then return CONTROL.eventRosette end
  return true
end
local function kascExports()
  return { shinySystem={ isShiny=function() return CONTROL.shiny end } }
end
]] .. orasSource:sub(markerStart, markerEnd - 1)
   .. "\nreturn FloatingHud", "@actual-vasc-status-marker-kinds")
assert(markerChunk, markerCompileError)
local MarkerHud = markerChunk(markerControl)
local markerBattle = {
  kind="wild", game={ save={ pokedex={ owned={ PIKACHU=true } } } },
}
local markerBattler = { mon={ species="PIKACHU", eventDistribution="mew" } }
eq(table.concat(MarkerHud.statusMarkerKinds(
  markerBattle, "enemy", markerBattler), ","), "caught,shiny,event",
  "ORAS card lost KASC caught/shiny/event metadata")
markerControl.caught = "off"
eq(table.concat(MarkerHud.statusMarkerKinds(
  markerBattle, "enemy", markerBattler), ","), "shiny,event",
  "HUD CAUGHT OFF did not remove only the caught marker")
markerControl.shinyEffects = false
eq(table.concat(MarkerHud.statusMarkerKinds(
  markerBattle, "enemy", markerBattler), ","), "event",
  "KASC SHINY EFFECTS OFF did not remove the ORAS shiny marker")
markerControl.eventRosette = false
eq(#MarkerHud.statusMarkerKinds(markerBattle, "enemy", markerBattler), 0,
  "KASC EVENT ROSETTE OFF still painted an ORAS event marker")
end

-- The segmented BattleHudExtras service is the primary presentation source;
-- KASC and raw mon fields remain compatibility fallbacks only.
;(function()
local genderStart = assert(orasSource:find(
  "local function genderSymbol", 1, true))
local genderEnd = assert(orasSource:find(
  "\nlocal function megaProfileFor", genderStart, true)) - 1
local preferredSymbol = "♀"
local genderChunk, genderError = (loadstring or load)([=[
local preferredSymbol = ...
local kascCalls = 0
local BattleHudExtras = {
  presentationGenderSymbol=function() return preferredSymbol end,
}
local function hudGenderEnabled() return true end
local function kascExports()
  return { pokemonGender={ symbol=function()
    kascCalls = kascCalls + 1
    return "♂"
  end } }
end
]=] .. orasSource:sub(genderStart, genderEnd) .. [=[
return genderSymbol, BattleHudExtras, function() return kascCalls end
]=], "@actual-vasc-presentation-gender")
assert(genderChunk, genderError)
local gender, extras, getKascCalls = genderChunk(preferredSymbol)
eq(gender({}, {}), "♀",
  "BattleHudExtras presentation gender did not win inside the ORAS card")
eq(getKascCalls(), 0,
  "ORAS card consulted KASC despite an exact segmented gender result")
extras.presentationGenderSymbol = function() return nil end
eq(gender({}, {}), "♂",
  "ORAS card lost its KASC gender compatibility fallback")
eq(getKascCalls(), 1,
  "KASC gender fallback was not called exactly once")
end)()

-- A side has no live HUD owner while its send-out actor is still pending.
;(function()
local liveStart = assert(orasSource:find(
  "local function floatingHudLive", 1, true))
local liveEnd = assert(orasSource:find(
  "\n\n-- Safari's BALL", liveStart, true)) - 1
local liveChunk, liveError = (loadstring or load)(
  orasSource:sub(liveStart, liveEnd) .. "\nreturn floatingHudLive\n",
  "@actual-vasc-floating-hud-live")
assert(liveChunk, liveError)
local live = liveChunk()
local battle = {
  player={}, enemy={}, showPlayerBack=false, showEnemyTrainer=false,
  sendingOut=true, enemySendingOut=true,
}
local enemyLive, playerLive = live(battle, 0)
eq(enemyLive, false, "enemy send-out was treated as a live HUD owner")
eq(playerLive, false, "player send-out was treated as a live HUD owner")
battle.sendingOut, battle.enemySendingOut = false, false
enemyLive, playerLive = live(battle, 0)
eq(enemyLive, true, "deployed enemy did not become a live HUD owner")
eq(playerLive, true, "deployed player did not become a live HUD owner")
end)()

check(not orasSource:find('ownerOrderFor', 1, true),
  "ORAS status cards still sort owners by screen side")
check(not orasSource:find('resolveStatusPair', 1, true),
  "ORAS status cards still relocate as a free UI pair")
check(not orasSource:find('BattleHudMotion', 1, true),
  "retired screen-lock/redock layer remains in the ORAS HUD")
check(not orasSource:find('statusMotion', 1, true),
  "retired status motion state remains in the ORAS HUD")
check(orasSource:find(
  'FloatingHud.observeMegaFormTransitions(battle)', 1, true),
  "KASC-owned Mega form edges are not observed by the VASC compositor")

-- Execute the production propose/commit path. Pure camera queries may propose
-- rectangles but cannot allocate/publish state; only an exact real render
-- receipt followed by transactional commit may freeze them.
local attachStart = assert(orasSource:find(
  "FloatingHud.OWNER_ATTACHMENT", 1, true))
local attachEnd = assert(orasSource:find(
  "\n\n-- Shadow offset", attachStart, true)) - 1
local attachChunk, attachCompileError = (loadstring or load)([=[
local FloatingHud = {
  STATUS_SCALE=1.53, GAP=5, EXTRA_RISE=18, REFERENCE_SPAN=56,
  HEAD_LIFT={ player=1.05, enemy=1.05 },
  POTATO_PLAYER_Y_OFFSET=0, POTATO_ENEMY_Y_OFFSET=0,
}
local diagnosticWrites = 0
local Diagnostics = { write=function()
  diagnosticWrites = diagnosticWrites + 1
  return true
end }
function FloatingHud.safeInsets() return 0, 0, 0, 0 end
local function clamp(value, low, high)
  if value < low then return low end
  if value > high then return high end
  return value
end
local function plateSize(side)
  return side == "player" and 178 or 162,
         side == "player" and 58 or 45
end
local function uiScale(shot) return tonumber(shot and shot.testUiScale) or 2 end
local optionValues = {}
local function optionChoice(key, fallback)
  local value = optionValues[key]
  if value == nil then return fallback end
  return value
end
FloatingHud._testOptionValues = optionValues
local isAscendantHost = true
local OverworldBattle = {}
local flowRects = {}
local HudRuntime = {
  commandRectFor=function() return flowRects.command end,
  fightRectFor=function() return flowRects.fight end,
  messageRectFor=function() return flowRects.message end,
}
local function supportedFloatingLayout() return true end
local function floatingCommandsEnabled() return true end
local function floatingStatusHudEnabled() return true end
local function hudStyle() return "oras" end
local PLATFORM_OS = "iOS"
local function floatingHudLive(battle)
  return true, battle and not battle.safari
end
local function battleMessageActive() return false end
]=] .. orasSource:sub(attachStart, attachEnd) .. "\n" .. [=[
FloatingHud.statusAssetsReady = function() return true end
FloatingHud._testFlowRects = flowRects
FloatingHud._testDiagnosticWrites = function() return diagnosticWrites end
]=] .. "\n" .. orasSource:sub(
  assert(orasSource:find(
    "function FloatingHud.safariBallCountBounds(battle, shot)", attachEnd, true)),
  assert(orasSource:find(
    "\n\nlocal function drawSafariBallCount", attachEnd, true)) - 1)
  .. "\n" .. orasSource:sub(
  assert(orasSource:find(
    "function FloatingHud.cameraBounds(battle, shot)", attachEnd, true)),
  assert(orasSource:find(
    "\n\n-- Decide whether the provider produced", attachEnd, true)) - 1)
  .. "\nreturn FloatingHud\n",
  "@actual-vasc-owner-attachment")
assert(attachChunk, attachCompileError)
local AttachHud = attachChunk()
-- This ownership fixture supplies one opaque dock; production icon geometry
-- has its own localization/focus/MEGA bounds contract.
AttachHud.orasCommandBounds = function(_, rect) return {rect} end
local pikachu = { species="PIKACHU" }
local tentacool = { species="TENTACOOL" }
local battle = {
  player={ mon=pikachu, sprite={} },
  enemy={ mon=tentacool, sprite={} },
}
local playerCanvas, enemyCanvas = {}, {}
local function visual(side, battler, token, headX, headY, canvas, identity)
  return {
    schema="voxel-ascendant/actor-render/v1", side=side,
    renderToken=token, battler=battler, mon=battler.mon,
    modelKey=tostring(battler.mon.species) .. "|front",
    textureToken=identity, inkIdentity=identity, canvas=canvas, view="front",
    viewportW=1280, viewportH=720,
    head={ x=headX, y=headY },
    hull={ headX - 20, headY, 40, 80 },
  }
end
local frameA = {
  pw=1280, ph=720, scale=2, renderToken=1,
}
frameA.actorVisuals = {
  player=visual("player", battle.player, 1, 400, 300,
                playerCanvas, battle.player.sprite),
  enemy=visual("enemy", battle.enemy, 1, 800, 240,
               enemyCanvas, battle.enemy.sprite),
}
local frameB = {
  pw=1280, ph=720, scale=2, renderToken=2,
}
frameB.actorVisuals = {
  player=visual("player", battle.player, 2, 540, 330,
                playerCanvas, battle.player.sprite),
  enemy=visual("enemy", battle.enemy, 2, 690, 260,
               enemyCanvas, battle.enemy.sprite),
}

local queryShot = {}
for key, value in pairs(frameA) do queryShot[key] = value end
queryShot.cameraSafety = true
local query = AttachHud.proposeStatusLatch(
  battle, queryShot, true, true, {})
eq(query.state, nil, "pure camera query allocated latch state")
eq(battle._floatingBattleHudOwnerAttachment, nil,
  "pure camera query published a battle receipt")

do
  local nilOwnerShot = {
    pw=1280, ph=720, scale=2, renderToken=99,
    actorVisuals={
      player={
        schema="voxel-ascendant/actor-render/v1", side="player",
        renderToken=99, battler=nil, mon=nil,
        modelKey="GHOST|front", textureToken={}, inkIdentity={}, canvas={},
        view="front", viewportW=1280, viewportH=720,
        head={ x=400, y=300 }, hull={ 380, 300, 40, 80 },
      },
    },
  }
  local nilOwnerBattle = {}
  eq(AttachHud.exactActorVisual(nilOwnerBattle, nilOwnerShot, "player"), nil,
    "all-nil semantic owner was accepted as an exact actor visual")
  local nilOwnerProposal = AttachHud.proposeStatusLatch(
    nilOwnerBattle, nilOwnerShot, true, false, {})
  eq(nilOwnerProposal.complete, false,
    "all-nil semantic owner created a complete ghost latch")
  eq(AttachHud.commitStatusLatch(nilOwnerProposal), false,
    "all-nil semantic owner committed a ghost latch")
  eq(AttachHud.statusAttachmentStates[nilOwnerBattle], nil,
    "all-nil semantic owner allocated persistent latch state")
  local monlessBattler = {}
  local monlessBattle = { player=monlessBattler }
  nilOwnerShot.actorVisuals.player.battler = monlessBattler
  eq(AttachHud.exactActorVisual(monlessBattle, nilOwnerShot, "player"), nil,
    "battler without a mon was accepted as an exact actor visual")
end

local incompleteInitial = {
  pw=1280, ph=720, scale=2, renderToken=1,
  actorVisuals={ player=frameA.actorVisuals.player },
}
local incomplete = AttachHud.proposeStatusLatch(
  battle, incompleteInitial, true, true, {})
eq(incomplete.complete, false,
  "one-sided initial render committed a non-atomic owner pair")
eq(AttachHud.commitStatusLatch(incomplete), false,
  "incomplete initial owner pair mutated latch state")
eq(battle._floatingBattleHudOwnerAttachment, nil,
  "incomplete initial owner pair published a receipt")

-- Wild-contact and send-out lifecycles legitimately expose only one semantic
-- battler before the other side enters.  That first exact actor may acquire
-- its own card without waiting for a fictitious two-sided frame; the second
-- side must then join the same semantic transaction exactly once, while the
-- already-live card continues following its current projected owner head.
local partialBattle = {
  player={ mon={ species="PIKACHU" }, sprite={} },
  enemy={ mon={ species="TENTACOOL" }, sprite={} },
}
local partialShot = {
  pw=1280, ph=720, scale=2, renderToken=11,
}
local introEmpty = AttachHud.proposeStatusLatch(
  partialBattle, {
    pw=1280, ph=720, scale=2, renderToken=10, actorVisuals={},
  }, false, false, {})
eq(introEmpty.complete, true,
  "trainer/intro frame without live billboards blocked VASC camera ownership")
partialShot.actorVisuals = {
  enemy=visual("enemy", partialBattle.enemy, 11, 800, 240,
               {}, partialBattle.enemy.sprite),
}
local partialInitial = AttachHud.proposeStatusLatch(
  partialBattle, partialShot, false, true, {})
eq(partialInitial.complete, true,
  "one-live-side wild/send-out frame could not acquire its exact owner card")
eq(AttachHud.commitStatusLatch(partialInitial), true,
  "one-live-side wild/send-out card did not commit")
local partialReceipt = AttachHud.statusLatchReceipt(
  partialBattle, partialInitial)
eq(partialReceipt.generations.enemy, 1,
  "one-live-side enemy card did not acquire exactly once")
eq(partialReceipt.generations.player, nil,
  "absent player side acquired a phantom card")
local firstPartialEnemy = partialReceipt.rects.enemy

partialShot.renderToken = 12
partialShot.actorVisuals = {
  player=visual("player", partialBattle.player, 12, 400, 300,
                {}, partialBattle.player.sprite),
  enemy=visual("enemy", partialBattle.enemy, 12, 760, 260,
               partialShot.actorVisuals.enemy.canvas,
               partialBattle.enemy.sprite),
}
local partialComplete = AttachHud.proposeStatusLatch(
  partialBattle, partialShot, true, true, {})
eq(partialComplete.complete, true,
  "second send-out side could not join the existing exact owner card")
eq(AttachHud.commitStatusLatch(partialComplete), true,
  "completed send-out owner pair did not commit")
local completedPartialReceipt = AttachHud.statusLatchReceipt(
  partialBattle, partialComplete)
eq(completedPartialReceipt.generations.player, 1,
  "late player card did not acquire exactly once")
eq(completedPartialReceipt.generations.enemy, 1,
  "late player card unnecessarily reacquired the enemy card")
local currentPartialEnemy = assert(AttachHud.projectOwnerStatusRect(
  partialShot, "enemy"))
for index = 1, 4 do
  eq(completedPartialReceipt.rects.enemy[index], currentPartialEnemy[index],
    "late player send-out detached the enemy card from its current head")
end
check(completedPartialReceipt.rects.enemy[1] ~= firstPartialEnemy[1],
  "moving enemy head left its status card frozen in screen space")

-- Fainting removes the retained card and a resize may still reacquire the
-- surviving owner. A new deployment must acquire a fresh semantic slot.
partialBattle.enemy.fainted = true
local defeated = AttachHud.proposeStatusLatch(partialBattle, partialShot, true, false, {})
eq(defeated.complete, true, "faint frame rejected surviving card")
eq(AttachHud.commitStatusLatch(defeated), true, "faint frame did not commit")
eq(AttachHud.statusAttachmentStates[partialBattle].enemy, nil, "faint retained old enemy slot")
partialShot.ph = 800
partialShot.testUiScale = 1.5
partialShot.actorVisuals.player.viewportH = 800
local resizedFaint = AttachHud.proposeStatusLatch(partialBattle, partialShot, true, false, {})
eq(resizedFaint.complete, true, "resize after faint blocked surviving card: " .. tostring(resizedFaint.unsafeReason) .. " pending=" .. tostring(resizedFaint.pending.player))
eq(AttachHud.commitStatusLatch(resizedFaint), true, "resize after faint did not commit")
eq(partialBattle._floatingBattleHudOwnerAttachment.rects.enemy, nil, "resize resurrected defeated card")
partialBattle.enemy = { mon={ species="GEODUDE" }, sprite={} }
partialShot.actorVisuals.enemy = visual("enemy", partialBattle.enemy, 12, 800, 240, {}, partialBattle.enemy.sprite)
partialShot.actorVisuals.enemy.viewportH = 800
local replacement = AttachHud.proposeStatusLatch(partialBattle, partialShot, true, true, {})
eq(replacement.complete, true, "new enemy did not acquire card")
eq(AttachHud.commitStatusLatch(replacement), true, "new enemy card did not commit")
eq(AttachHud.statusAttachmentStates[partialBattle].enemy.mon, partialBattle.enemy.mon, "new enemy inherited old payload")

local initial = AttachHud.proposeStatusLatch(battle, frameA, true, true, {})
eq(initial.complete, true, "exact initial pair was not a complete proposal")
eq(AttachHud.commitStatusLatch(initial), true,
  "exact initial pair did not commit transactionally")
local receiptA = AttachHud.statusLatchReceipt(battle, initial)
local playerA = assert(receiptA.rects.player)
local enemyA = assert(receiptA.rects.enemy)
for _, rect in ipairs({ playerA, enemyA }) do
  for _, actorSide in ipairs({ "player", "enemy" }) do
    check(not AttachHud.rectanglesHit(
      rect, frameA.actorVisuals[actorSide].hull, 8),
      "production-size owner card overlaps the " .. actorSide .. " alpha hull")
  end
end
eq(receiptA.binding.player, "player", "initial player binding drifted")
eq(receiptA.binding.enemy, "enemy", "initial enemy binding drifted")
check(playerA[1] + playerA[3] < frameA.actorVisuals.player.head.x,
  "player card is not behind the rear/left side of the player head")
check(enemyA[1] > frameA.actorVisuals.enemy.head.x,
  "enemy card is not behind the rear/right side of the enemy head")
check(playerA[2] + playerA[4] < frameA.actorVisuals.player.head.y,
  "player card does not keep clearance above the player head")
check(enemyA[2] + enemyA[4] < frameA.actorVisuals.enemy.head.y,
  "enemy card does not keep clearance above the enemy head")

-- An authored grow/shrink/Dig/Fly animation may move or resize an alpha hull
-- while the semantic battler stays unchanged. The card must follow the exact
-- current head/hull at the reviewed clearance; visible owner overlap is never
-- excused. Current flow reservations, peer-card collisions and a real switch
-- remain authoritative.
;(function()
local transientShot = {
  pw=1280, ph=720, scale=2, renderToken=3,
}
transientShot.actorVisuals = {
  player=visual("player", battle.player, 3, 520, 320,
                playerCanvas, battle.player.sprite),
  enemy=visual("enemy", battle.enemy, 3, 800, 240,
               enemyCanvas, battle.enemy.sprite),
}
local transientProposal = AttachHud.proposeStatusLatch(
  battle, transientShot, true, true, {})
eq(transientProposal.ready, true,
  "same-owner transient frame lost its ready owner pair")
eq(transientProposal.safe, true,
  "same-owner head reprojection did not clear the current actor hull")
eq(transientProposal.complete, true,
  "same-owner head reprojection did not produce a complete proposal")
local presented = AttachHud.statusSlotsForPresentation(
  battle, transientProposal, true, true)
eq(presented, transientProposal.slots,
  "same-owner frame did not present its current head-projected slots")
local expectedTransientPlayer = assert(AttachHud.projectOwnerStatusRect(
  transientShot, "player"))
for index = 1, 4 do
  eq(presented.player.rect[index], expectedTransientPlayer[index],
    "same-owner player card detached from the current projected head")
end
check(presented.player.rect[1] ~= playerA[1]
      or presented.player.rect[2] ~= playerA[2],
  "same-owner player card remained frozen over the moving Pokemon")
check(not AttachHud.rectanglesHit(
  presented.player.rect, transientShot.actorVisuals.player.hull, 8),
  "same-owner player card still overlaps its current alpha hull")
eq(AttachHud._testDiagnosticWrites(), 0,
  "head reprojection emitted a stale-slot retention diagnostic")

local writesBeforeCameraQuery = AttachHud._testDiagnosticWrites()
local transientBounds, transientReason =
  AttachHud.cameraBounds(battle, transientShot)
eq(transientReason, nil,
  "camera rejected the renderer's current head-projected frame")
check(transientBounds ~= nil,
  "camera omitted the renderer's current head-projected bounds")
local currentPlayerBound, currentEnemyBound
for _, item in ipairs(transientBounds.reserved) do
  if item.id == "player-status" then currentPlayerBound = item end
  if item.id == "enemy-status" then currentEnemyBound = item end
end
check(currentPlayerBound and currentPlayerBound.allowOwnActorOverlap ~= true,
  "visible player card published an owner-overlap exception")
check(currentEnemyBound and currentEnemyBound.allowOwnActorOverlap ~= true,
  "visible enemy card published an owner-overlap exception")
for index = 1, 4 do
  local key = ({ "x", "y", "w", "h" })[index]
  eq(currentPlayerBound[key], presented.player.rect[index],
    "camera and renderer disagreed on the current player card seat")
  eq(currentEnemyBound[key], presented.enemy.rect[index],
    "camera and renderer disagreed on the current enemy card seat")
end
eq(AttachHud._testDiagnosticWrites(), writesBeforeCameraQuery,
  "pure camera query emitted a head-reprojection diagnostic")

-- The default rearward OUTSIDE contract stays strict in landscape, but on a
-- phone portrait it must use the head's diagonal-above seat. Requiring two
-- full cards beside the actors on a 440px axis forced SMART into a remote lens
-- and still produced owner-render-unsafe receipts.
local portraitShot = { pw=440, ph=956, scale=2, testUiScale=2, renderToken=33 }
local function portraitVisual(side, battler, headX, headY)
  return {
    schema="voxel-ascendant/actor-render/v1", side=side,
    renderToken=portraitShot.renderToken, battler=battler, mon=battler.mon,
    modelKey=tostring(battler.mon.species) .. "|front",
    textureToken=battler.sprite, inkIdentity=battler.sprite, canvas={},
    view="front", viewportW=portraitShot.pw, viewportH=portraitShot.ph,
    head={ x=headX, y=headY }, hull={ headX-10, headY, 20, 55 },
  }
end
portraitShot.actorVisuals = {
  player=portraitVisual("player", battle.player, 180, 450),
  enemy=portraitVisual("enemy", battle.enemy, 275, 350),
}
local portraitProposal = AttachHud.proposeStatusLatch(
  battle, portraitShot, true, true, {})
check(portraitProposal.complete,
  "mobile portrait default still requires a remote side-by-side camera")
for _, side in ipairs({ "player", "enemy" }) do
  local rect = assert(portraitProposal.slots[side].rect)
  check(rect[2] + rect[4] < portraitShot.actorVisuals[side].hull[2],
    "mobile portrait " .. side .. " card is not diagonally above its head")
end

-- Moving the mobile message plate above START/SELECT makes it a floating
-- reservation, not a physical-bottom dock. Advertising the old exception for
-- this shifted rectangle makes the provider-neutral validator reject the
-- entire camera receipt as malformed and permanently latch native 2-D.
battle.phase = "messages"
AttachHud._testFlowRects.message = { 330, 570, 620, 100 }
local shiftedBounds, shiftedReason =
  AttachHud.cameraBounds(battle, transientShot)
eq(shiftedReason, nil, "shifted mobile message bounds were rejected")
local shiftedMessage
for _, item in ipairs(assert(shiftedBounds).reserved) do
  if item.id == "message" then shiftedMessage = item end
end
check(shiftedMessage ~= nil, "shifted mobile message was not reserved")
eq(shiftedMessage.safeAreaPolicy, nil,
  "shifted mobile message retained the physical-bottom exception")

AttachHud._testFlowRects.message = { 330, 620, 620, 100 }
local bottomBounds = assert(AttachHud.cameraBounds(battle, transientShot))
local bottomMessage
for _, item in ipairs(bottomBounds.reserved) do
  if item.id == "message" then bottomMessage = item end
end
eq(assert(bottomMessage).safeAreaPolicy, "physical-bottom-dock",
  "real bottom-docked message lost its explicit safe-area exception")
AttachHud._testFlowRects.message = nil
battle.phase = nil

local hiddenEnemyShot = {
  pw=1280, ph=720, scale=2, renderToken=32,
  actorVisuals={
    player=visual("player", battle.player, 32, 400, 300,
                  playerCanvas, battle.player.sprite),
  },
}
local hiddenBounds, hiddenReason =
  AttachHud.cameraBounds(battle, hiddenEnemyShot)
eq(hiddenReason, nil,
  "same-owner animation visual gap lost camera bounds")
local hiddenEnemyBound
for _, item in ipairs(assert(hiddenBounds).reserved) do
  if item.id == "enemy-status" then hiddenEnemyBound = item end
end
check(hiddenEnemyBound
    and hiddenEnemyBound.allowOwnActorOverlap == true
    and hiddenEnemyBound.ownerSide == "enemy"
    and hiddenEnemyBound.ownerVisualGap == true,
  "hidden enemy owner did not publish its visual-gap receipt")

local foreignHullShot = {
  pw=1280, ph=720, scale=2, renderToken=31,
}
foreignHullShot.actorVisuals = {
  player=visual("player", battle.player, 31, 400, 300,
                playerCanvas, battle.player.sprite),
  enemy=visual("enemy", battle.enemy, 31, 800, 240,
               enemyCanvas, battle.enemy.sprite),
}
foreignHullShot.actorVisuals.enemy.hull = {
  playerA[1] + 2, playerA[2] + 2, 8, 8,
}
local foreignHullProposal = AttachHud.proposeStatusLatch(
  battle, foreignHullShot, true, true, {})
eq(foreignHullProposal.ready, true,
  "foreign-hull regression did not keep the owner pair ready")
eq(foreignHullProposal.safe, false,
  "foreign actor hull covering a current card was not unsafe")
eq(AttachHud.statusSlotsForPresentation(
  battle, foreignHullProposal, true, true), nil,
  "current player slot ignored the current enemy actor hull")
eq(foreignHullProposal.displayedFromCommittedSlots, nil,
  "foreign actor overlap published a retention receipt")

local reservedProposal = AttachHud.proposeStatusLatch(
  battle, frameB, true, true, {
    { 0, 0, frameB.pw, frameB.ph },
  })
eq(reservedProposal.ready, true,
  "reserved-band regression did not keep the owner pair ready")
eq(reservedProposal.safe, false,
  "reserved band covering a committed card was not unsafe")
eq(AttachHud.statusSlotsForPresentation(
  battle, reservedProposal, true, true), nil,
  "current HP slot was presented underneath a reserved band")
eq(reservedProposal.displayedFromCommittedSlots, nil,
  "rejected reserved-band proposal published a retention receipt")

local replacement = { mon={ species="RAICHU" }, sprite={} }
local originalPlayer = battle.player
battle.player = replacement
local switchedShot = {
  pw=1280, ph=720, scale=2, renderToken=4,
  actorVisuals={
    enemy=visual("enemy", battle.enemy, 4, 800, 240,
                 enemyCanvas, battle.enemy.sprite),
  },
}
local switchedProposal = AttachHud.proposeStatusLatch(
  battle, switchedShot, true, true, {})
eq(switchedProposal.ready, false,
  "switch without a fresh exact actor receipt was render-ready")
eq(AttachHud.statusSlotsForPresentation(
  battle, switchedProposal, true, true), nil,
  "real switch reused the previous Pokemon's committed HP slot")
battle.player = originalPlayer
local freshProposal = AttachHud.proposeStatusLatch(
  battle, frameB, true, true, {})
eq(freshProposal.complete, true,
  "fresh exact proposal did not recover after transient motion")
eq(AttachHud.statusSlotsForPresentation(
  battle, freshProposal, true, true), freshProposal.slots,
  "complete fresh proposal did not publish head-projected status slots")
eq(battle._ascendantHudRetainedStatusLogged, nil,
  "fresh complete proposal did not retire a legacy diagnostic latch")
end)()

-- Regression from the real 1024x768 Route-20 driver: its height-derived UI
-- scale used to cap each card at 48% of the screen, so no safe camera could
-- ever produce two non-overlapping initial latches.  The production compact
-- cap must leave two valid owner-head-derived cards without relocating them.
local compactBattle = {
  player={ mon={ species="PIKACHU" }, sprite={} },
  enemy={ mon={ species="TENTACOOL" }, sprite={} },
}
local compactShot = { pw=1024, ph=768, scale=3, testUiScale=4,
                      renderToken=3 }
local function compactVisual(side, battler, x, y, canvas)
  local got = visual(side, battler, 3, x, y, canvas, battler.sprite)
  got.viewportW, got.viewportH = 1024, 768
  return got
end
compactShot.actorVisuals = {
  player=compactVisual("player", compactBattle.player, 360, 260, {}),
  enemy=compactVisual("enemy", compactBattle.enemy, 650, 250, {}),
}
local compactProposal = AttachHud.proposeStatusLatch(
  compactBattle, compactShot, true, true, {})
check(compactProposal.complete,
  "compact Route-20 frame could not latch both semantic owner cards")
check(compactProposal.slots.player.rect[1]
        + compactProposal.slots.player.rect[3]
      < compactProposal.slots.enemy.rect[1],
  "compact owner cards still overlap after their initial latch")

local unchanged = AttachHud.proposeStatusLatch(battle, frameB, true, true, {})
eq(unchanged.complete, true, "camera-motion query lost committed cards")
eq(AttachHud.commitStatusLatch(unchanged), true,
  "camera-motion transaction did not preserve committed cards")
local receiptB = AttachHud.statusLatchReceipt(battle, unchanged)
local expectedPlayerB = assert(AttachHud.projectOwnerStatusRect(
  frameB, "player"))
local expectedEnemyB = assert(AttachHud.projectOwnerStatusRect(
  frameB, "enemy"))
for index = 1, 4 do
  eq(receiptB.rects.player[index], expectedPlayerB[index],
    "camera projection detached the player card from its current head")
  eq(receiptB.rects.enemy[index], expectedEnemyB[index],
    "camera projection detached the enemy card from its current head")
end
check(receiptB.rects.player[1] ~= playerA[1]
      or receiptB.rects.player[2] ~= playerA[2],
  "camera motion left the player card frozen in screen space")
check(receiptB.rects.enemy[1] ~= enemyA[1]
      or receiptB.rects.enemy[2] ~= enemyA[2],
  "camera motion left the enemy card frozen in screen space")
eq(frameB.actorVisuals.player.head.y
    - (receiptB.rects.player[2] + receiptB.rects.player[4]),
  frameA.actorVisuals.player.head.y - (playerA[2] + playerA[4]),
  "player card did not preserve its fixed above-head clearance")
eq(frameB.actorVisuals.enemy.head.y
    - (receiptB.rects.enemy[2] + receiptB.rects.enemy[4]),
  frameA.actorVisuals.enemy.head.y - (enemyA[2] + enemyA[4]),
  "enemy card did not preserve its fixed above-head clearance")
eq(receiptB.generations.player, 1,
  "ordinary camera motion reacquired the player card")
eq(receiptB.generations.enemy, 1,
  "ordinary camera motion reacquired the enemy card")

-- Mega/Gorochu animation frames and a same-owner form presentation may
-- replace every content receipt. They must update the payload atomically and
-- keep the reviewed fixed clearance from the exact current projected head.
;(function()
  local ownerBattle = {
    player={ mon={ species="PIKACHU" }, sprite={} },
    enemy={ mon={ species="TENTACOOL" }, sprite={} },
  }
  local playerOwnerCanvas, enemyOwnerCanvas = {}, {}
  local ownerFrame = { pw=1280, ph=720, scale=2, renderToken=20 }
  ownerFrame.actorVisuals = {
    player=visual("player", ownerBattle.player, 20, 400, 300,
                  playerOwnerCanvas, ownerBattle.player.sprite),
    enemy=visual("enemy", ownerBattle.enemy, 20, 800, 240,
                 enemyOwnerCanvas, ownerBattle.enemy.sprite),
  }
  local initialOwner = AttachHud.proposeStatusLatch(
    ownerBattle, ownerFrame, true, true, {})
  eq(initialOwner.complete, true,
    "same-owner fixture could not acquire its initial HUD pair")
  eq(AttachHud.commitStatusLatch(initialOwner), true,
    "same-owner fixture could not commit its initial HUD pair")
  local ownerReceipt = AttachHud.statusLatchReceipt(
    ownerBattle, initialOwner)
  local ownerRect = ownerReceipt.rects.player

  local changingCanvasA = {}
  local changingFrame = { pw=1280, ph=720, scale=2, renderToken=21 }
  changingFrame.actorVisuals = {
    player=visual("player", ownerBattle.player, 21, 540, 330,
                  changingCanvasA, ownerBattle.player.mon),
    enemy=visual("enemy", ownerBattle.enemy, 21, 690, 260,
                 enemyOwnerCanvas, ownerBattle.enemy.sprite),
  }
  changingFrame.actorVisuals.player.modelKey =
    "PIKACHU|MEGA|front|pokemon"
  changingFrame.actorVisuals.player.inkIdentity = "mega-frame-001"
  changingFrame.actorVisuals.player.view = "mega-front"
  local changing = AttachHud.proposeStatusLatch(
    ownerBattle, changingFrame, true, true, {})
  eq(changing.complete, true,
    "same-owner content refresh lost a complete safe HUD proposal")
  eq(changing.mismatch.player, "modelKey",
    "same-owner form refresh lost its exact mismatch receipt")
  eq(AttachHud.commitStatusLatch(changing), true,
    "same-owner form refresh did not commit")
  local changingReceipt = AttachHud.statusLatchReceipt(
    ownerBattle, changing)
  local expectedChangingRect = assert(AttachHud.projectOwnerStatusRect(
    changingFrame, "player"))
  for index = 1, 4 do
    eq(changingReceipt.rects.player[index], expectedChangingRect[index],
      "same-owner form refresh detached from the current player head")
  end
  check(changingReceipt.rects.player[1] ~= ownerRect[1]
        or changingReceipt.rects.player[2] ~= ownerRect[2],
    "same-owner form refresh left the player card frozen")
  local changingSlot = AttachHud.statusAttachmentStates[ownerBattle].player
  eq(changingSlot.anchor.x, changingFrame.actorVisuals.player.head.x,
    "same-owner form refresh lost the current player x anchor")
  eq(changingSlot.anchor.y, changingFrame.actorVisuals.player.head.y,
    "same-owner form refresh lost the current player y anchor")
  eq(changingSlot.modelKey, "PIKACHU|MEGA|front|pokemon",
    "same-owner refresh retained a stale model receipt")
  eq(changingSlot.textureToken, ownerBattle.player.mon,
    "same-owner refresh retained a stale texture receipt")
  eq(changingSlot.inkIdentity, "mega-frame-001",
    "same-owner refresh retained a stale alpha-content receipt")
  eq(changingSlot.canvas, changingCanvasA,
    "same-owner refresh retained a stale canvas receipt")
  eq(changingSlot.view, "mega-front",
    "same-owner refresh retained a stale view receipt")
  eq(changingSlot.visualHull, changingFrame.actorVisuals.player.hull,
    "camera safety retained the old actor hull after content refresh")

  local changingFrameB = { pw=1280, ph=720, scale=2, renderToken=22 }
  changingFrameB.actorVisuals = {
    player=visual("player", ownerBattle.player, 22, 560, 340,
                  changingCanvasA, ownerBattle.player.mon),
    enemy=visual("enemy", ownerBattle.enemy, 22, 690, 260,
                 enemyOwnerCanvas, ownerBattle.enemy.sprite),
  }
  changingFrameB.actorVisuals.player.modelKey =
    "PIKACHU|MEGA|front|pokemon"
  changingFrameB.actorVisuals.player.inkIdentity = "mega-frame-002"
  changingFrameB.actorVisuals.player.view = "mega-front"
  local stableGeneration = changingReceipt.generations.player
  local stableSerial = changingReceipt.serial
  local changingAgain = AttachHud.proposeStatusLatch(
    ownerBattle, changingFrameB, true, true, {})
  eq(changingAgain.complete, true,
    "second same-owner animation frame lost its safe HUD proposal")
  eq(changingAgain.mismatch.player, nil,
    "animated content-only frame became a deployment mismatch")
  eq(changingAgain.receiptRefresh.player, true,
    "animated content-only frame did not request a receipt refresh")
  eq(AttachHud.commitStatusLatch(changingAgain), true,
    "second same-owner animation frame did not commit")
  local changingAgainReceipt = AttachHud.statusLatchReceipt(
    ownerBattle, changingAgain)
  local expectedChangingAgainRect = assert(AttachHud.projectOwnerStatusRect(
    changingFrameB, "player"))
  for index = 1, 4 do
    eq(changingAgainReceipt.rects.player[index],
      expectedChangingAgainRect[index],
      "animated same-owner frame detached from the current player head")
  end
  changingSlot = AttachHud.statusAttachmentStates[ownerBattle].player
  eq(changingSlot.anchor.x, changingFrameB.actorVisuals.player.head.x,
    "animated content-only frame lost the current player x anchor")
  eq(changingSlot.anchor.y, changingFrameB.actorVisuals.player.head.y,
    "animated content-only frame lost the current player y anchor")
  eq(changingSlot.textureToken, ownerBattle.player.mon,
    "animated same-owner frame changed its stable deployment token")
  eq(changingSlot.inkIdentity, "mega-frame-002",
    "animated same-owner frame retained stale alpha content")
  eq(changingSlot.canvas, changingCanvasA,
    "animated same-owner frame changed its stable canvas")
  eq(changingSlot.view, "mega-front",
    "animated same-owner frame changed its stable view")
  eq(changingSlot.visualHull, changingFrameB.actorVisuals.player.hull,
    "camera safety did not receive the current animated actor hull")
  eq(changingAgainReceipt.generations.player, stableGeneration,
    "animated content-only frame churned the player latch generation")
  eq(changingAgainReceipt.serial, stableSerial,
    "animated content-only frame churned the attachment serial")
end)()

-- Damage/attack blink intentionally withholds one actor visual for a handful
-- of frames. The exact current battler/mon keeps its last exact head-relative
-- seat while hidden; this may never be mistaken for a real switch.
local blinkFrame = {
  pw=1280, ph=720, scale=2, renderToken=3,
  actorVisuals={ enemy=frameB.actorVisuals.enemy },
}
blinkFrame.actorVisuals.enemy.renderToken = blinkFrame.renderToken
local blink = AttachHud.proposeStatusLatch(
  battle, blinkFrame, true, true, {})
eq(blink.complete, true,
  "temporary attack blink dropped the exact last-known player card")
eq(AttachHud.commitStatusLatch(blink), true,
  "temporary attack blink could not preserve the status transaction")
local blinkReceipt = AttachHud.statusLatchReceipt(battle, blink)
eq(blinkReceipt.pending.player, false,
  "temporary attack blink published a false player-owner pending state")
eq(blinkReceipt.generations.player, 1,
  "temporary attack blink reacquired the player card")
eq(blinkReceipt.generations.enemy, 1,
  "temporary attack blink reacquired the enemy card")

local crossed = {
  pw=1280, ph=720, scale=2, renderToken=4,
}
crossed.actorVisuals = {
  player=visual("player", battle.player, 4, 850, 350,
                playerCanvas, battle.player.sprite),
  enemy=visual("enemy", battle.enemy, 4, 180, 160,
               enemyCanvas, battle.enemy.sprite),
}
local crossedProposal = AttachHud.proposeStatusLatch(
  battle, crossed, true, true, {})
local crossedTargets = crossedProposal.slots
local expectedCrossedPlayer = assert(AttachHud.projectOwnerStatusRect(
  crossed, "player"))
local expectedCrossedEnemy = assert(AttachHud.projectOwnerStatusRect(
  crossed, "enemy"))
for index = 1, 4 do
  eq(crossedTargets.player.rect[index], expectedCrossedPlayer[index],
    "actor crossing detached/swapped the player rectangle")
  eq(crossedTargets.enemy.rect[index], expectedCrossedEnemy[index],
    "actor crossing detached/swapped the enemy rectangle")
end

battle.player = { mon={ species="RAICHU" }, sprite={} }
local replacement = {
  pw=1280, ph=720, scale=2, renderToken=5,
}
replacement.actorVisuals = {
  player=visual("player", battle.player, 5, 500, 310, {}, battle.player.sprite),
  enemy=visual("enemy", battle.enemy, 5, 800, 240,
               enemyCanvas, battle.enemy.sprite),
}
local replaced = AttachHud.proposeStatusLatch(
  battle, replacement, true, true, {})
eq(replaced.complete, true, "exact replacement proposal was rejected")
eq(AttachHud.commitStatusLatch(replaced), true,
  "exact replacement did not commit")
local replacedReceipt = AttachHud.statusLatchReceipt(battle, replaced)
local expectedReplacementEnemy = assert(AttachHud.projectOwnerStatusRect(
  replacement, "enemy"))
check(replacedReceipt.rects.player[1] ~= playerA[1]
      or replacedReceipt.rects.player[2] ~= playerA[2],
  "genuine player/model replacement did not reacquire its new head")
for index = 1, 4 do
  eq(replacedReceipt.rects.enemy[index], expectedReplacementEnemy[index],
    "player replacement detached the unchanged enemy card from its head")
end
eq(replacedReceipt.generations.player, 2,
  "player replacement generation did not advance exactly once")
eq(replacedReceipt.generations.enemy, 1,
  "player replacement advanced the enemy generation")

-- A real viewport/UI-generation change invalidates both screen rectangles at
-- once. It must reacquire one complete semantic pair from exact visuals; a
-- half-updated frame may never expose one old and one resized card.
local resized = {
  pw=1440, ph=900, scale=2, testUiScale=2.25, renderToken=6,
}
resized.actorVisuals = {
  player=visual("player", battle.player, 6, 460, 390, {},
                battle.player.sprite),
  enemy=visual("enemy", battle.enemy, 6, 980, 310,
               enemyCanvas, battle.enemy.sprite),
}
for _, side in ipairs({ "player", "enemy" }) do
  resized.actorVisuals[side].viewportW = resized.pw
  resized.actorVisuals[side].viewportH = resized.ph
end
local resizedProposal = AttachHud.proposeStatusLatch(
  battle, resized, true, true, {})
eq(resizedProposal.atomic, true,
  "viewport generation did not request an atomic pair relatch")
eq(resizedProposal.complete, true,
  "complete resized owner pair was rejected")
eq(AttachHud.commitStatusLatch(resizedProposal), true,
  "resized owner pair did not commit atomically")
local resizedReceipt = AttachHud.statusLatchReceipt(battle, resizedProposal)
eq(resizedReceipt.generations.player, 3,
  "viewport relatch did not advance player exactly once")
eq(resizedReceipt.generations.enemy, 2,
  "viewport relatch did not advance enemy exactly once")
check(resizedReceipt.rects.player[1] ~= replacedReceipt.rects.player[1]
      and resizedReceipt.rects.enemy[1] ~= replacedReceipt.rects.enemy[1],
  "viewport relatch exposed stale mixed-generation rectangles")

-- A second switch with yesterday's Raichu visual must fail open. The old slot
-- cannot receive CHARIZARD content, and pure proposal must not mutate either
-- side while the replacement model is absent.
local charizardBattler = { mon={ species="CHARIZARD" }, sprite={} }
battle.player = charizardBattler
local stale = AttachHud.proposeStatusLatch(
  battle, resized, true, true, {})
eq(stale.ready, false, "stale Raichu shot attached Charizard content")
eq(stale.slots.player, nil, "old player slot survived a genuine switch")
local stalePayloads = AttachHud.bindStatusPayloads(battle, stale)
eq(stalePayloads.player, nil,
  "pending Charizard was bound to the old Raichu rectangle")
local afterStale = AttachHud.statusLatchReceipt(battle, stale)
eq(afterStale.generations.player, 3,
  "stale switch query advanced the player generation")
eq(afterStale.generations.enemy, 2,
  "stale switch query advanced the enemy generation")

local offscreen = assert(AttachHud.projectOwnerStatusRect({
  pw=1280, ph=720, scale=2, renderToken=6,
  actorVisuals={ player={ head={x=0,y=350} } },
}, "player"))
check(offscreen[1] >= 8 and offscreen[1]+offscreen[3] <= 1280-8,
  "outside card was not bounded to the physical safe frame")

-- The Samsung report rejects a ready owner frame repeatedly. A clamped
-- default card can cover its own tall actor while a clear seat exists below.
;(function()
  for _, size in ipairs({{2340,1080},{1080,2340}}) do
    local w,h=size[1],size[2]
    local b={player={mon={species='GENGAR'},sprite={}},enemy={mon={species='BLISSEY'},sprite={}}}
    local shot={pw=w,ph=h,scale=3,testUiScale=3,renderToken=91}
    shot.actorVisuals={}
    for _,side in ipairs({'player','enemy'}) do
      local battler=b[side];local x=side=='player' and 30 or w-330
      shot.actorVisuals[side]={schema='voxel-ascendant/actor-render/v1',side=side,
        renderToken=91,battler=battler,mon=battler.mon,modelKey=side,
        textureToken=battler.sprite,canvas={},view='front',viewportW=w,viewportH=h,
        head={x=x+150,y=25},hull={x,25,300,450}}
    end
    AttachHud._testOptionValues.status_anchor='outside'
    local reserved={{0,h-220,w,220}}
    local proposal=AttachHud.proposeStatusLatch(b,shot,true,true,reserved)
    check(proposal.complete,'Samsung '..w..'x'..h..' solvable status placement declined: '..tostring(proposal.unsafeReason))
    check(AttachHud.statusLatchFrameSafe(shot,proposal.slots,reserved),'reflow bypassed geometry check')
    local blocked=AttachHud.proposeStatusLatch(b,shot,true,true,{{0,0,w,h}})
    check(not blocked.complete,'fully blocked viewport accepted')
    AttachHud._testOptionValues.status_anchor=nil
  end
end)()

-- The three public anchor choices are real geometry contracts, not dead menu
-- values. Exercise them against an adversarial 1024x768 frame whose player
-- hull leaves too little room for the former unbounded OUTSIDE placement.
;(function()
  local anchorBattle = {
    player={ mon={ species="SNORLAX" }, sprite={} },
    enemy={ mon={ species="ONIX" }, sprite={} },
  }
  local anchorShot = { pw=1024, ph=768, scale=3, testUiScale=4,
                       renderToken=3 }
  anchorShot.actorVisuals = {
    player=compactVisual("player", anchorBattle.player, 125, 300, {}),
    enemy=compactVisual("enemy", anchorBattle.enemy, 875, 250, {}),
  }
  anchorShot.actorVisuals.player.hull = { 65, 300, 120, 210 }
  anchorShot.actorVisuals.enemy.hull = { 815, 250, 120, 220 }
  local viewportKeys = {}
  for _, mode in ipairs({ "outside", "above", "corners" }) do
    AttachHud._testOptionValues.status_anchor = mode
    viewportKeys[mode] = AttachHud.statusViewportKey(anchorShot)
    local proposal = AttachHud.proposeStatusLatch(
      anchorBattle, anchorShot, true, true, {})
    check(proposal.complete,
      "1024x768 " .. mode .. " anchor did not produce a safe complete pair")
    for _, side in ipairs({ "player", "enemy" }) do
      local rect = assert(proposal.slots[side] and proposal.slots[side].rect)
      if proposal.complete then
        check(rect[1] >= 0 and rect[2] >= 0
            and rect[1] + rect[3] <= anchorShot.pw
            and rect[2] + rect[4] <= anchorShot.ph,
          mode .. " anchor escaped the 1024x768 viewport")
        for _, actorSide in ipairs({ "player", "enemy" }) do
          check(not AttachHud.rectanglesHit(
            rect, anchorShot.actorVisuals[actorSide].hull, 8),
            mode .. " anchor overlaps the " .. actorSide .. " alpha hull")
        end
      end
    end
  end
  check(viewportKeys.outside ~= viewportKeys.above
      and viewportKeys.above ~= viewportKeys.corners,
    "status-anchor change did not invalidate the viewport latch")
  AttachHud._testOptionValues.status_anchor = nil
end)()

-- Camera and renderer must agree on relocated cards. This 4:3 fixture
-- previously fell onto the bottom flow and was rejected. Reflow now finds
-- free seats while retaining the full actor/HUD collision check.
;(function()
  local cameraBattle = {
    player={ mon={ species="SNORLAX" }, sprite={} },
    enemy={ mon={ species="ONIX" }, sprite={} },
  }
  local cameraShot = { pw=1024, ph=768, scale=3, testUiScale=1.8,
                       renderToken=31 }
  local function cameraVisual(side, battler, hull)
    return {
      schema="voxel-ascendant/actor-render/v1", side=side,
      renderToken=cameraShot.renderToken, battler=battler, mon=battler.mon,
      modelKey=tostring(battler.mon.species) .. "|front",
      textureToken=battler.sprite, canvas={}, view="front",
      viewportW=cameraShot.pw, viewportH=cameraShot.ph,
      head={ x=hull[1] + hull[3] * .5, y=hull[2] }, hull=hull,
    }
  end
  cameraShot.actorVisuals = {
    player=cameraVisual(
      "player", cameraBattle.player, { 100, 20, 120, 220 }),
    enemy=cameraVisual(
      "enemy", cameraBattle.enemy, { 804, 20, 120, 220 }),
  }
  AttachHud._testOptionValues.status_anchor = "outside"

  local flows = {
    { phase="menu", key="command", rect={ 18, 555, 988, 213 } },
    { phase="moveSelect", key="fight", rect={ 272, 546, 480, 222 } },
    { phase="messages", key="message", rect={ 253, 653, 518, 115 } },
  }
  for _, flow in ipairs(flows) do
    AttachHud._testFlowRects.command = nil
    AttachHud._testFlowRects.fight = nil
    AttachHud._testFlowRects.message = nil
    AttachHud._testFlowRects[flow.key] = flow.rect
    cameraBattle.phase = flow.phase

    local proposal = AttachHud.proposeStatusLatch(
      cameraBattle, cameraShot, true, true, { flow.rect })
    eq(proposal.ready, true,
      flow.phase .. " status proposal was not ready")
    eq(proposal.complete, true, flow.phase .. " clear alternate seats were rejected")
    check(AttachHud.statusLatchFrameSafe(cameraShot,proposal.slots,{flow.rect}),
      flow.phase .. " relocated cards still collide")
    local bounds, reason = AttachHud.cameraBounds(cameraBattle, cameraShot)
    check(bounds ~= nil, flow.phase .. " safe camera bounds rejected: "..tostring(reason))
    for _,rect in ipairs(bounds.reserved) do
      local side=rect.id=="player-status" and "player" or rect.id=="enemy-status" and "enemy"
      if side then
        local expected=proposal.slots[side].rect
        eq(rect.x,expected[1],"camera/render reflow x differs")
        eq(rect.y,expected[2],"camera/render reflow y differs")
      end
    end
  end
  AttachHud._testOptionValues.status_anchor = nil
end)()

-- Safari has only an enemy owner card, plus a compact top-centred remaining-
-- balls band. On the reported 412x915 portrait frame, CORNERS used to accept
-- the enemy card directly underneath that band because cameraBounds published
-- the band only after the proposal. The renderer and camera must now reject
-- that overlap from one shared reservation, while a genuinely clear anchor
-- remains complete and publishes byte-identical Safari bounds.
;(function()
  local safariBattle = {
    kind="safari", safari={ balls=30 },
    enemy={ mon={ species="TAUROS" }, sprite={} },
  }
  local safariShot = {
    pw=412, ph=915, scale=2, testUiScale=2, renderToken=77,
  }
  safariShot.actorVisuals = { enemy={
    schema="voxel-ascendant/actor-render/v1", side="enemy",
    battler=safariBattle.enemy, mon=safariBattle.enemy.mon,
    renderToken=safariShot.renderToken, modelKey="TAUROS|front",
    textureToken=safariBattle.enemy.sprite, canvas={}, view="front",
    viewportW=safariShot.pw, viewportH=safariShot.ph,
    head={ x=200, y=400 }, hull={ 180, 400, 40, 80 },
  } }
  local safariRect = assert(
    AttachHud.safariBallCountBounds(safariBattle, safariShot))
  eq(safariRect[1], 133.9, "portrait Safari band x drifted")
  eq(safariRect[2], 4, "portrait Safari band y drifted")
  eq(safariRect[3], 144.2, "portrait Safari band width drifted")
  eq(safariRect[4], 68.625, "portrait Safari band height drifted")

  AttachHud._testOptionValues.status_anchor = "corners"
  local unreserved = AttachHud.proposeStatusLatch(
    safariBattle, safariShot, false, true, {})
  eq(unreserved.complete, true,
    "Safari overlap fixture no longer reaches the historical false positive")
  local cornerRect = assert(unreserved.slots.enemy.rect)
  check(AttachHud.rectanglesHit(cornerRect, safariRect, 0),
    "Safari overlap fixture does not cover the reported portrait collision")

  local reserved = AttachHud.proposeStatusLatch(
    safariBattle, safariShot, false, true, { safariRect })
  eq(reserved.ready, true, "one-sided Safari owner was not render-ready")
  eq(reserved.safe, false,
    "CORNERS card overlapping Safari balls was marked safe")
  eq(reserved.complete, false,
    "CORNERS card overlapping Safari balls was marked complete")
  local rejected, rejectReason =
    AttachHud.cameraBounds(safariBattle, safariShot)
  eq(rejected, nil, "unsafe Safari CORNERS bounds were published")
  eq(rejectReason, "owner-render-unsafe",
    "unsafe Safari CORNERS reason drifted")

  AttachHud._testOptionValues.status_anchor = "outside"
  local clear = AttachHud.proposeStatusLatch(
    safariBattle, safariShot, false, true, { safariRect })
  eq(clear.complete, true,
    "genuinely clear one-sided Safari layout was rejected")
  check(not AttachHud.rectanglesHit(
    assert(clear.slots.enemy.rect), safariRect, 8),
    "complete Safari layout still overlaps the balls band")
  local published = assert(AttachHud.cameraBounds(safariBattle, safariShot))
  local publishedSafari, publishedEnemy
  for _, item in ipairs(published.reserved) do
    if item.id == "safari-balls" then publishedSafari = item end
    if item.id == "enemy-status" then publishedEnemy = item end
  end
  check(publishedSafari ~= nil, "safe Safari bounds omitted the balls band")
  for index, key in ipairs({ "x", "y", "w", "h" }) do
    eq(publishedSafari[key], safariRect[index],
      "published Safari band " .. key .. " diverged from latch reservation")
  end
  check(publishedEnemy ~= nil, "safe Safari bounds omitted the enemy card")
  check(not AttachHud.rectanglesHit({
    publishedEnemy.x, publishedEnemy.y,
    publishedEnemy.w, publishedEnemy.h,
  }, safariRect, 8), "published safe Safari card overlaps its balls band")
  AttachHud._testOptionValues.status_anchor = nil
end)()

-- Semantic content must stay attached to the battle side. Exercise the
-- production binder with concrete species: Tentacool may never inherit
-- Pikachu's player label during Stadium.
local bindStart = assert(orasSource:find(
  "function FloatingHud.bindStatusPayloads", 1, true))
local bindEnd = assert(orasSource:find(
  "\nend\n\n-- Shadow offset", bindStart, true))
bindEnd = bindEnd + #"\nend" - 1
local bindChunk, bindCompileError = (loadstring or load)([=[
local FloatingHud = {}
]=] .. orasSource:sub(bindStart, bindEnd) .. "\nreturn FloatingHud\n",
  "@actual-vasc-status-bindings")
assert(bindChunk, bindCompileError)
local BindHud = bindChunk()
local semanticBattle = {
  player={ mon={ species="PIKACHU" } },
  enemy={ mon={ species="TENTACOOL" } },
}
local crossedPose = {
  slots={
    player={ rect=playerA, battler=semanticBattle.player },
    enemy={ rect=enemyA, battler=semanticBattle.enemy },
  },
}
local payloads = BindHud.bindStatusPayloads(semanticBattle, crossedPose)
eq(payloads.player.side, "player", "crossed player rectangle lost its side")
eq(payloads.enemy.side, "enemy", "crossed enemy rectangle lost its side")
eq(payloads.player.battler.mon.species, "PIKACHU",
  "Tentacool inherited Pikachu's player status content")
eq(payloads.enemy.battler.mon.species, "TENTACOOL",
  "Pikachu inherited Tentacool's enemy status content")

-- KASC overlays may yield only after the replacement pixels for this exact
-- staged frame have committed. A stale shot, empty owner or optimistic boolean
-- must fail open so neither mod can erase the only readable HUD.
local receiptStart = assert(orasSource:find(
  "function FloatingHud.hasExactHudSnapReceipt", 1, true))
local receiptEnd = assert(orasSource:find(
  "\nend\n\nfunction FloatingHud.ownsHostStatus", receiptStart, true))
receiptEnd = receiptEnd + #"\nend" - 1
local receiptChunk, receiptCompileError = (loadstring or load)([=[
local FloatingHud = {}
local activeReceipt = nil
local OverworldBattle = {
  hudSnapReceipt=function() return activeReceipt end,
}
]=] .. orasSource:sub(receiptStart, receiptEnd) .. [=[

return FloatingHud, function(value) activeReceipt = value end
]=], "@actual-vasc-hud-snap-receipt")
assert(receiptChunk, receiptCompileError)
local ReceiptHud, setReceipt = receiptChunk()
local receiptShot, staleShot = {}, {}
local receiptBattle = { voxelAscendantShot=receiptShot }

local function receiptAccepted(value, message)
  setReceipt(value)
  return ReceiptHud.hasExactHudSnapReceipt(receiptBattle), message
end

eq(receiptAccepted(nil), false, "nil HUD receipt was accepted")
eq(receiptAccepted({
  schema="wrong", shot=receiptShot, snapped=true, owner="VOXEL_ASCENDANT",
}), false, "wrong HUD receipt schema was accepted")
eq(receiptAccepted({
  schema="voxel-ascendant/hud-snap/v1", shot=receiptShot,
  snapped=false, owner="VOXEL_ASCENDANT",
}), false, "uncommitted HUD receipt was accepted")
eq(receiptAccepted({
  schema="voxel-ascendant/hud-snap/v1", shot=receiptShot,
  snapped=true, owner="",
}), false, "empty HUD receipt owner was accepted")
eq(receiptAccepted({
  schema="voxel-ascendant/hud-snap/v1", shot=staleShot,
  snapped=true, owner="VOXEL_ASCENDANT",
}), false, "stale HUD receipt shot was accepted")
receiptBattle.voxelAscendantShot = nil
eq(receiptAccepted({
  schema="voxel-ascendant/hud-snap/v1", shot=nil,
  snapped=true, owner="VOXEL_ASCENDANT",
}), false, "nil current HUD shot was accepted")
receiptBattle.voxelAscendantShot = receiptShot
eq(receiptAccepted({
  schema="voxel-ascendant/hud-snap/v1", shot=receiptShot,
  snapped=true, owner="voxel_ascendant.oras",
}), true, "exact committed HUD receipt was rejected")

do
-- Execute the real bottom-dock geometry with a phone-shaped framebuffer and a
-- deliberately non-zero home-indicator safe inset. Side insets still protect
-- the controls, but the visual bottom edge is an invariant of the framebuffer.
local safeStart = assert(orasSource:find(
  "function FloatingHud.safeInsets", 1, true))
local safeEnd = assert(orasSource:find(
  "\nend\n\n-- Gen I's SE_WAVY_SCREEN", safeStart, true))
safeEnd = safeEnd + #"\nend" - 1
local dockStart = assert(orasSource:find(
  "function FloatingHud.screenDockRect", safeEnd, true))
local dockEnd = assert(orasSource:find(
  "\nend\n\nfunction FloatingHud.drawMenuPlane", dockStart, true))
dockEnd = dockEnd + #"\nend" - 1
local dockChunk, dockCompileError = (loadstring or load)([[
local love = {
  graphics={},
  window={},
}
local g = love.graphics
local FloatingHud = {
  CANVAS_PAD=5, DOCK_HEIGHT_SHARE=0.31, DOCK_MAX_LOGICAL_WIDTH=720,
  panelLogicalSize=function() return 320, 96 end,
}
local CURRENT_W, CURRENT_H = 390, 844
local CURRENT_SCALE = 1
local SAFE = { 12, 44, 366, 766 }
love.graphics.getDimensions = function() return CURRENT_W, CURRENT_H end
love.window.getSafeArea = function() return unpack(SAFE) end
local function uiScale() return CURRENT_SCALE end
local function optionChoice(_,fallback) return fallback end
]] .. orasSource:sub(safeStart, safeEnd)
   .. "\n" .. orasSource:sub(assert(orasSource:find("function FloatingHud.configureControls(",1,true)),dockStart-1)
   .. "\n" .. orasSource:sub(dockStart, dockEnd)
   .. "\n" .. [[return FloatingHud, function(w, h, scale, safe)
  CURRENT_W, CURRENT_H, CURRENT_SCALE = w, h, scale
  SAFE = safe or { 0, 0, w, h }
end
]], "@actual-vasc-bottom-dock")
assert(dockChunk, dockCompileError)
local DockHud, setDockViewport = dockChunk()
local phoneRect = assert(DockHud.screenDockRect({ pw=390, ph=844 }, "command"))
eq(phoneRect[2] + phoneRect[4], 844,
  "phone safe-area inset lifted the ORAS dock above the framebuffer bottom")
check(phoneRect[1] > 12,
  "phone side safe-area inset stopped protecting the ORAS dock")

local function verifyWideDock(w, h, scale, label)
  setDockViewport(w, h, scale)
  local rect, actualScale = DockHud.screenDockRect({ pw=w, ph=h }, "command")
  check(actualScale <= scale + 1e-9,
    label .. " enlarged the HUD beyond the requested UI scale")
  check(rect[3] <= DockHud.DOCK_MAX_LOGICAL_WIDTH * actualScale + 1e-9,
    label .. " command plane exceeded its logical width cap")
  check(math.abs((rect[1] + rect[3] * 0.5) - w * 0.5) < 1e-6,
    label .. " command plane was not centred")
  eq(rect[2] + rect[4], h,
    label .. " command plane stopped touching the framebuffer bottom")
end

verifyWideDock(3420, 2214, 2.7, "3420x2214")
verifyWideDock(1710, 1107, 1.8, "1710x1107")
verifyWideDock(1920, 1080, 1.8, "1920x1080")
verifyWideDock(1024, 768, 1, "1024x768 approved edge-dock design")
end

-- Execute the real localized-control sizing helper. Different cropped source
-- images must share one design box; German FIGHT may be shorter on disk, but it
-- must not become the giant command shown in the reported ultrawide capture.
local metricsStart = assert(orasSource:find(
  "function FloatingHud.commandAssetMetrics", 1, true))
local metricsEnd = assert(orasSource:find(
  "\nend\n\nlocal function renderCommandCanvas", metricsStart, true))
metricsEnd = metricsEnd + #"\nend" - 1
local metricsChunk, metricsCompileError = (loadstring or load)([[
local FloatingHud = {}
]] .. orasSource:sub(metricsStart, metricsEnd)
   .. "\nreturn FloatingHud", "@actual-vasc-command-asset-metrics")
assert(metricsChunk, metricsCompileError)
local MetricsHud = metricsChunk()
local function imageSize(w, h)
  return { getWidth=function() return w end, getHeight=function() return h end }
end
local deMetrics = MetricsHud.commandAssetMetrics(
  imageSize(67, 20), 720, 156, 0.30, 0.32, 1.50, 69, 32)
local enMetrics = MetricsHud.commandAssetMetrics(
  imageSize(69, 32), 720, 156, 0.30, 0.32, 1.50, 69, 32)
eq(deMetrics.layoutW, enMetrics.layoutW,
  "German and English FIGHT no longer share one design width")
eq(deMetrics.layoutH, enMetrics.layoutH,
  "German and English FIGHT no longer share one design height")
check(20 * deMetrics.baseScale < 156 * 0.25,
  "German FIGHT sprite is still vertically oversized")

-- Execute the factory's real visibility/arming functions in isolation. This
-- is stronger than checking labels: VASC alone and a not-ready KASC service
-- must be unable to manufacture even a latent armed state.
;(function()
local profileStart = assert(orasSource:find(
  "local function megaProfileFor", 1, true))
local profileEnd = assert(orasSource:find(
  "\ndo\nlocal MEGA_FX_DURATION", profileStart, true))
local armedStart = assert(orasSource:find(
  "function FloatingHud.clearMegaArmed", profileEnd, true))
local armedEndMarker = "\nend\n\nlocal function megaSfxVolume"
local armedEnd = assert(orasSource:find(armedEndMarker, armedStart, true))
armedEnd = armedEnd + #"\nend" - 1
local megaPrelude = [[
local FloatingHud = {}
local ACTIVE_KASC = nil
local INTEGRATED_VASC = true
local Diagnostics = { write=function() return false end }
local MENU_RECEIPT = nil
local ListMenu = { new=function(game, title, rows, opts)
  local menu = { game=game, title=title, rows=rows, opts=opts }
  function menu:close() self.closed = true end
  MENU_RECEIPT = menu
  return menu
end }
local function hudLanguage() return "en" end
local function hudStyle() return "oras" end
local function kascExports() return ACTIVE_KASC end
]]
local megaChunk, megaCompileError = (loadstring or load)(
  megaPrelude
  .. orasSource:sub(profileStart, profileEnd - 1)
  .. orasSource:sub(armedStart, armedEnd)
  .. "\n"
  .. [[return FloatingHud,
  function(value, integratedVasc)
    ACTIVE_KASC = value
    if integratedVasc ~= nil then INTEGRATED_VASC = integratedVasc end
  end,
  function(...) return megaProfileFor(...) end,
  function() return MENU_RECEIPT end
]], "@actual-vasc-mega-contract")
assert(megaChunk, megaCompileError)
local MegaHud, setMegaKasc, actualMegaProfile, megaMenuReceipt = megaChunk()
local megaBattle = {
  kind="trainer", game={}, moveSwapIndex=nil,
  player={ mon={ hp=20 } },
}

setMegaKasc(nil, true)
eq(actualMegaProfile(megaBattle, megaBattle.player, "player"), nil,
  "VASC alone exposed a Mega profile")
local armed, armedReason = MegaHud.toggleMegaArmed(megaBattle)
eq(armed, false, "VASC alone armed Mega")
eq(armedReason, "unavailable", "VASC-alone Mega refusal reason")
eq(MegaHud.megaArmed(megaBattle), false,
  "VASC alone retained a latent Mega armed state")

-- Presentation remains VASC-owned, but KASC is the sole gameplay authority.
-- An exact ready profile may therefore appear and arm in VASC's own HUD.
local integratedVascProfile = { form="VISIBLE_THROUGH_PUBLIC_KASC_API" }
setMegaKasc({ megaEvolution={
  canActivate=function()
    return true, nil, integratedVascProfile
  end,
} }, true)
eq(actualMegaProfile(megaBattle, megaBattle.player, "player"),
  integratedVascProfile,
  "VASC provider hid an exact ready KASC Mega capability")
armed, armedReason = MegaHud.toggleMegaArmed(megaBattle)
eq(armed, true, "VASC provider could not arm a KASC-authorized Mega")
eq(armedReason, "armed", "VASC provider Mega armed reason")
eq(MegaHud.megaArmed(megaBattle), true,
  "VASC provider lost its KASC-authorized Mega armed state")

local canActivateCalls = 0
setMegaKasc({ megaEvolution={
  canActivate=function(battleArg, battlerArg, sideArg)
    canActivateCalls = canActivateCalls + 1
    eq(battleArg, megaBattle, "KASC readiness battle")
    eq(battlerArg, megaBattle.player, "KASC readiness battler")
    eq(sideArg, "player", "KASC readiness side")
    return false, "not-ready"
  end,
} }, false)
eq(actualMegaProfile(megaBattle, megaBattle.player, "player"), nil,
  "canActivate=false exposed the Mega button")
armed, armedReason = MegaHud.toggleMegaArmed(megaBattle)
eq(armed, false, "canActivate=false armed Mega")
eq(armedReason, "unavailable", "not-ready KASC refusal reason")
eq(MegaHud.megaArmed(megaBattle), false,
  "not-ready KASC retained a latent armed state")
check(canActivateCalls >= 2, "KASC readiness authority was not consulted")

local readyProfile = { form="TEST_MEGA", requiresRing=false }
setMegaKasc({ megaEvolution={
  canActivate=function()
    return true, nil, readyProfile
  end,
} }, false)
eq(actualMegaProfile(megaBattle, megaBattle.player, "player"), readyProfile,
  "canActivate=true profile was not exposed")
armed, armedReason = MegaHud.toggleMegaArmed(megaBattle)
eq(armed, true, "ready KASC could not arm Mega")
eq(armedReason, "armed", "ready KASC armed reason")
eq(MegaHud.megaArmed(megaBattle), true,
  "ready KASC armed state was not retained")

-- Readiness can disappear between focus and move confirmation. The next
-- state read must fail closed and erase the stale armed bit.
setMegaKasc({ megaEvolution={ canActivate=function() return false end } })
eq(MegaHud.megaArmed(megaBattle), false,
  "stale armed state survived canActivate=false")
eq(megaBattle._ascendantBattleHudMegaArmed, nil,
  "stale Mega armed flag was not cleared")

-- Charizard/Mewtwo-style dual forms must use a real in-battle picker. Cancel
-- leaves gameplay untouched; choosing Y pins that exact profile through the
-- subsequent activation transaction instead of allowing provider defaulting.
;(function()
local megaX = { id="CHARIZARD_X", species="CHARIZARD", label="Mega X" }
local megaY = { id="CHARIZARD_Y", species="CHARIZARD", label="Mega Y" }
local preferredSpecies, preferredForm = nil, nil
setMegaKasc({ megaEvolution={
  canActivate=function() return true, nil, megaX end,
  formChoicesFor=function() return { megaX, megaY } end,
  setPreferredForm=function(species, form)
    preferredSpecies, preferredForm = species, form
  end,
} }, true)
local pushed = nil
megaBattle.player.mon.species = "CHARIZARD"
megaBattle.game.stack = { push=function(_, menu) pushed = menu end }
armed, armedReason = MegaHud.toggleMegaArmed(megaBattle)
eq(armed, true, "dual-form Mega did not open its picker")
eq(armedReason, "choosing", "dual-form Mega picker result")
local firstMenu = megaMenuReceipt()
eq(pushed, firstMenu, "dual-form Mega picker was not pushed on the battle stack")
eq(#firstMenu.rows, 2, "dual-form Mega picker row count")
eq(firstMenu.rows[1].right, "X", "Mega X picker badge")
eq(firstMenu.rows[2].right, "Y", "Mega Y picker badge")
firstMenu.opts.onCancel()
eq(megaBattle._ascendantBattleHudMegaChoice, nil,
  "Mega form picker cancel retained a stale choice owner")
eq(MegaHud.megaArmed(megaBattle), false,
  "Mega form picker cancel armed a form")

armed, armedReason = MegaHud.toggleMegaArmed(megaBattle)
eq(armedReason, "choosing", "dual-form Mega picker did not reopen")
local secondMenu = megaMenuReceipt()
secondMenu.opts.onChoose(secondMenu.rows[2], secondMenu)
eq(secondMenu.closed, true, "Mega form choice did not close its picker")
eq(preferredSpecies, "CHARIZARD", "Mega form choice lost species identity")
eq(preferredForm, "CHARIZARD_Y", "Mega form choice lost exact Y profile")
eq(megaBattle._ascendantBattleHudMegaArmedProfile, "CHARIZARD_Y",
  "chosen Mega profile was not pinned on the exact battle owner")
eq(MegaHud.megaArmed(megaBattle), true,
  "chosen Mega form did not arm after picker confirmation")
MegaHud.clearMegaArmed(megaBattle)

-- Multiple forms cannot silently degrade into an unowned menu. A malformed
-- stack object must fail closed without arming or calling a non-function push.
megaBattle.game.stack = {}
armed, armedReason = MegaHud.toggleMegaArmed(megaBattle)
eq(armed, false, "dual-form Mega armed without a callable stack.push")
eq(armedReason, "stack_unavailable",
  "malformed Mega picker stack returned the wrong refusal")
eq(megaBattle._ascendantBattleHudMegaArmed, nil,
  "malformed Mega picker stack retained latent armed state")
end)()
end)()

-- KASC also owns classic SELECT and automatic enemy activation paths. Those
-- do not pass through VASC's move-button commit, so the production observer
-- must start the same presentation from the actual same-owner form edge,
-- without replaying it for fixtures or an already-started VASC transaction.
local observeStart = assert(orasSource:find(
  "local function currentMegaOwnerForm", 1, true))
local observeEnd = assert(orasSource:find(
  "\nfunction FloatingHud.advanceMegaTransformation", observeStart, true)) - 1
local observeChunk, observeCompileError = (loadstring or load)([=[
local FloatingHud = {}
local MEGA_FX_DURATION = 5.04
local Diagnostics = { write=function() return false end }
local soundStarts = 0
local function playMegaTransformationSound()
  soundStarts = soundStarts + 1
  return true
end
]=] .. orasSource:sub(observeStart, observeEnd) .. [=[
return FloatingHud, function() return soundStarts end
]=], "@actual-vasc-mega-form-observer")
assert(observeChunk, observeCompileError)
local ObserveHud, megaSoundStarts = observeChunk()

local fixtureBattle = {
  player={ mon={ _ascMegaForm="FIXTURE_MEGA" },
           _ascMegaForm="FIXTURE_MEGA" },
}
eq(ObserveHud.observeMegaFormTransitions(fixtureBattle), false,
  "already-Mega battle fixture replayed the transformation animation")
eq(fixtureBattle._ascendantBattleHudMegaTransformation, nil,
  "already-Mega battle fixture allocated a transformation effect")

local observedBattle = {
  player={ mon={} }, enemy={ mon={} },
}
eq(ObserveHud.observeMegaFormTransitions(observedBattle), false,
  "initial ordinary forms started a transformation")
observedBattle.player._ascMegaForm = "PLAYER_MEGA"
observedBattle.player.mon._ascMegaForm = "PLAYER_MEGA"
eq(ObserveHud.observeMegaFormTransitions(observedBattle), true,
  "classic KASC SELECT form edge did not start the player presentation")
local playerFx = observedBattle._ascendantBattleHudMegaTransformation
eq(playerFx.side, "player", "classic KASC SELECT targeted the wrong side")
eq(ObserveHud.observeMegaFormTransitions(observedBattle), false,
  "unchanged player Mega form restarted the presentation")
eq(observedBattle._ascendantBattleHudMegaTransformation, playerFx,
  "unchanged player Mega form replaced the running effect")

observedBattle._ascendantBattleHudMegaTransformation = nil
observedBattle.enemy._ascMegaForm = "ENEMY_MEGA"
observedBattle.enemy.mon._ascMegaForm = "ENEMY_MEGA"
eq(ObserveHud.observeMegaFormTransitions(observedBattle), true,
  "automatic KASC enemy form edge did not start the enemy presentation")
eq(observedBattle._ascendantBattleHudMegaTransformation.side, "enemy",
  "automatic KASC enemy form edge targeted the wrong side")

local committedBattle = { player={ mon={} } }
ObserveHud.observeMegaFormTransitions(committedBattle)
committedBattle.player._ascMegaForm = "COMMITTED_MEGA"
committedBattle.player.mon._ascMegaForm = "COMMITTED_MEGA"
ObserveHud.startMegaTransformation(committedBattle, "player")
local committedFx = committedBattle._ascendantBattleHudMegaTransformation
eq(ObserveHud.observeMegaFormTransitions(committedBattle), false,
  "VASC commit form edge started the presentation twice")
eq(committedBattle._ascendantBattleHudMegaTransformation, committedFx,
  "VASC commit observer replaced the running presentation")
eq(megaSoundStarts(), 3,
  "Mega observer/commit paths did not start exactly one sound per real edge")

-- -------------------------------------------------------------------------
-- Actual OverworldBattle provider compositor: priority, exclusivity and
-- transactional draw/commit behavior.
-- -------------------------------------------------------------------------

local screenCanvas = { name="screen" }
local shotCanvas = {
  name="shot",
  getWidth=function() return 640 end,
  getHeight=function() return 360 end,
}
local currentCanvas = screenCanvas
local blendMode, blendAlpha = "add", "premultiplied"
local operations = {}
local nextLayer = 0
local failShotBlit = false
local currentScissor = nil

local function operation(kind, payload)
  operations[#operations + 1] = {
    kind=kind, target=currentCanvas, payload=payload,
  }
end

_G.love = {
  _os="OS X",
  graphics={
    newCanvas=function(width, height)
      nextLayer = nextLayer + 1
      local layer = { name="provider-layer-" .. nextLayer, w=width, h=height }
      function layer:getWidth() return self.w end
      function layer:getHeight() return self.h end
      function layer:setFilter() end
      return layer
    end,
    getCanvas=function() return currentCanvas end,
    setCanvas=function(value) currentCanvas = value end,
    getBlendMode=function() return blendMode, blendAlpha end,
    setBlendMode=function(mode, alpha)
      blendMode, blendAlpha = mode, alpha
    end,
    setColor=function() end,
    getScissor=function()
      if currentScissor then return unpack(currentScissor) end
    end,
    setScissor=function(x, y, w, h)
      currentScissor = x and { x, y, w, h } or nil
      operation("scissor", currentScissor)
    end,
    clear=function(...) operation("clear", { ... }) end,
    rectangle=function(...) operation("rectangle", { ... }) end,
    draw=function(source, ...)
      if failShotBlit and currentCanvas == shotCanvas then
        error("synthetic provider blit failure")
      end
      operation("draw", { source, ... })
    end,
    newQuad=function(...) return { ... } end,
    push=function() end,
    pop=function() end,
    origin=function() end,
    setShader=function() end,
  },
}

package.loaded["src.core.Platform"] = nil
package.preload["src.core.Platform"] = function()
  error("headless fixture uses love._os")
end

local function simpleSetting(values, defaultValue)
  local value = defaultValue
  if value == nil and type(values) == "table" then value = values[1] end
  return {
    get=function() return value end,
    setIndex=function(_, index) value = values[index] end,
  }
end

local modules = {
  ModSetting={ new=function(_, _, values, _, defaultValue)
    return simpleSetting(values, defaultValue)
  end },
  BattleArena={},
  BattleCam={ arenaDirectorSelected=function() return false end },
  BattleScene={ GB_W=160, GB_H=144 },
  BattleDOF={},
  BattleHud={},
  BattlePartyBalls={ PERSISTENT_RECT={ enemy={}, player={} } },
  BattlePics={},
  CanvasPresentation={
    preflips=function() return false end,
    begin2D=function() return false end,
  },
  Voxel3D={},
  ChunkMesher={},
}
local warnings = {}
local V = {
  require=function(name)
    local value = modules[name]
    check(value ~= nil, "missing provider fixture module " .. tostring(name))
    return value
  end,
  mod={ log={ warn=function(_, message, ...)
    warnings[#warnings + 1] = string.format(message, ...)
  end } },
}

local OverworldBattle = assert(loadfile("lib/OverworldBattle.lua"))(V)
local function upvalue(fn, wanted)
  for index = 1, 100 do
    local name, value = debug.getupvalue(fn, index)
    if not name then break end
    if name == wanted then return value end
  end
  error("missing upvalue " .. wanted)
end
-- update() publishes every complete frame through commitShot(); the provider
-- compositor is deliberately owned by that atomic transaction rather than by
-- update() directly.  Follow the real closure chain so this test keeps
-- exercising the runtime compositor instead of depending on accidental
-- upvalue flattening.
local drawProvider = upvalue(upvalue(
  upvalue(OverworldBattle.update, "updateBattleFrame"), "commitShot"),
  "drawBattleHudProvider")
eq(type(drawProvider), "function", "provider compositor test seam")
local markSnapped = upvalue(upvalue(
  upvalue(OverworldBattle.update, "updateBattleFrame"), "commitShot"),
  "markSnapped")
local acknowledgeHudSnapshot = upvalue(upvalue(
  upvalue(OverworldBattle.update, "updateBattleFrame"), "commitShot"),
  "acknowledgeHudSnapshot")
eq(type(markSnapped), "function", "provider snap receipt test seam")
eq(type(acknowledgeHudSnapshot), "function",
  "cooperative provider acknowledgement test seam")

local battle = { phase="menu" }
local shot = {
  canvas=shotCanvas, pw=640, ph=360, scale=2,
  player={ 80, 120 }, enemy={ 220, 50 }, lx=0, ly=0,
}
local defaultDraws, externalDraws = 0, 0
local deferredCommits, defaultFinishes = 0, 0
local deferredMode = "ok"
local function defaultProvider()
  return {
    apiVersion=1, id="voxel_ascendant.oras",
    claim=function() return true end,
    draw=function(_, _, context)
      defaultDraws = defaultDraws + 1
      love.graphics.rectangle("fill", 10, 10, 20, 10)
      check(context.afterCommit(function()
        deferredCommits = deferredCommits + 1
        if deferredMode == "false" then return false end
        if deferredMode == "error" then error("synthetic latch failure") end
        return true
      end), "provider compositor rejected deferred latch transaction")
      return true
    end,
    finishBattle=function()
      defaultFinishes = defaultFinishes + 1
      return true
    end,
  }
end

local function shotCommits(from)
  local count = 0
  for index = from or 1, #operations do
    local item = operations[index]
    if item.kind == "draw" and item.target == shotCanvas then count = count + 1 end
  end
  return count
end

local bundledProvider = defaultProvider()
eq(OverworldBattle.setDefaultBattleHudProvider(bundledProvider), true,
  "VASC default provider registration")
local receipt = OverworldBattle.battleHudProviderReceipt()
eq(receipt.id, "voxel_ascendant.oras", "default provider receipt")
eq(receipt.externalId, nil, "standalone receipt gained an external owner")
eq(receipt.defaultId, "voxel_ascendant.oras", "default receipt id")
eq(receipt.damageBoundsSchema, "voxel-ascendant/hud-damage-bounds/v1",
  "provider receipt lost the sparse transaction capability")

local before = #operations + 1
local drew, owner, native = drawProvider(battle, shot)
eq(drew, true, "standalone VASC default ORAS provider declined")
eq(owner, "voxel_ascendant.oras", "standalone provider owner")
eq(native, nil, "standalone ORAS unexpectedly requested native HUD")
eq(defaultDraws, 1, "standalone default draw count")
eq(shotCommits(before), 1, "successful default provider was not committed once")
eq(deferredCommits, 1,
  "status latch transaction did not run after successful provider blit")
eq(currentCanvas, screenCanvas, "default provider leaked its canvas")
eq(blendMode, "add", "default provider leaked blend mode")
eq(blendAlpha, "premultiplied", "default provider leaked blend alpha")

-- KASC 6.5.17 observes the documented snapHUDs seam and otherwise assumes it
-- still has to reconstruct VASC's legacy wide bands from BattleState:drawHUDs.
-- A provider-completed frame must therefore pass through an observational
-- wrapper exactly once while the renderer implementation itself remains a
-- draw-free acknowledgement.
local rendererSnap = OverworldBattle.snapHUDs
local observerCalls = 0
OverworldBattle.snapHUDs = function(liveBattle, liveShot, ...)
  observerCalls = observerCalls + 1
  return rendererSnap(liveBattle, liveShot, ...)
end
markSnapped(battle, shot, true, nil, "voxel_ascendant.oras")
before = #operations + 1
eq(acknowledgeHudSnapshot(battle, shot), true,
  "provider completion was not published through snapHUDs")
eq(observerCalls, 1, "cooperative snap observer call count")
eq(shotCommits(before), 0,
  "provider acknowledgement repainted the legacy wide HUD")
OverworldBattle.snapHUDs = rendererSnap

-- Safari used to reach this legacy compositor after the ORAS provider
-- declined. Its pixels were valid, but the receipt owner was nil, so KASC's
-- public observer correctly treated the frame as unowned and added QoL
-- fragments. Exercise the real compositor and require a complete owner.
local legacyShot = {
  canvas=shotCanvas, pw=640, ph=360, scale=2,
  player={ 80, 120 }, enemy={ 220, 50 }, lx=0, ly=0,
}
local legacyBattle = {
  phase="menu", safari={ balls=17 }, introSlide=0,
  growInScale=function() return nil end,
}
modules.BattleHud.position = function() return "auto" end
modules.BattleHud.panel = function() end
OverworldBattle.textPlacements = function() return {} end
OverworldBattle.snapRects = function()
  return {}, {
    enemy={ x=0, y=0, scale=1 },
    player={ x=0, y=0, scale=1 },
  }
end
OverworldBattle.hudLive = function() return false, false end
OverworldBattle.partyRects = function() return {} end
OverworldBattle.persistentPartyPlacements = function() return {} end
OverworldBattle.hudTexture = function() return { name="legacy-hud-layer" } end
eq(rendererSnap(legacyBattle, legacyShot), true,
  "successful Safari legacy compositor declined")
local legacyReceipt = assert(OverworldBattle.hudSnapReceipt(legacyBattle))
eq(legacyReceipt.schema, "voxel-ascendant/hud-snap/v1",
  "legacy compositor receipt schema")
eq(legacyReceipt.shot, legacyShot, "legacy compositor receipt shot")
eq(legacyReceipt.snapped, true, "legacy compositor snapped flag")
eq(legacyReceipt.owner, "voxel_ascendant.legacy",
  "legacy compositor did not publish a cooperative owner")

local external = {
  apiVersion=1, id="kanto_ascendant.oras", exclusive=true,
  claim=function() return true end,
  draw=function()
    externalDraws = externalDraws + 1
    love.graphics.rectangle("fill", 30, 20, 40, 20)
    return true
  end,
}
eq(OverworldBattle.setBattleHudProvider(external), true,
  "external KASC provider registration")
receipt = OverworldBattle.battleHudProviderReceipt()
eq(receipt.id, "kanto_ascendant.oras", "external provider receipt owner")
eq(receipt.externalId, "kanto_ascendant.oras", "external receipt id")
eq(receipt.defaultId, "voxel_ascendant.oras", "external displaced default receipt")

before = #operations + 1
drew, owner, native = drawProvider(battle, shot)
eq(drew, true, "external KASC ORAS provider declined")
eq(owner, "kanto_ascendant.oras", "external provider did not win")
eq(native, nil, "successful external provider requested native HUD")
eq(externalDraws, 1, "external provider draw count")
eq(defaultDraws, 1, "default provider also drew under external KASC")
eq(shotCommits(before), 1, "external provider was not committed exactly once")

-- KASC STANDARD is represented by its exclusive provider declining claim.
-- The exclusivity receipt must suppress both VASC ORAS and legacy snapHUDs.
external.claim = function() return false end
before = #operations + 1
drew, owner, native = drawProvider(battle, shot)
eq(drew, false, "KASC STANDARD unexpectedly drew ORAS")
eq(owner, "kanto_ascendant.oras", "KASC STANDARD lost owner receipt")
eq(native, true, "KASC STANDARD did not request native fallback")
eq(defaultDraws, 1, "VASC default drew under KASC STANDARD")
eq(shotCommits(before), 0, "KASC STANDARD committed replacement pixels")

-- A partially painting provider that throws must leave the authoritative shot
-- untouched. Exclusive KASC still chooses native rather than VASC fallback.
external.claim = function() return true end
external.draw = function()
  externalDraws = externalDraws + 1
  love.graphics.rectangle("fill", 1, 1, 100, 30)
  error("synthetic provider failure")
end
before = #operations + 1
drew, owner, native = drawProvider(battle, shot)
eq(drew, false, "failed KASC provider reported success")
eq(owner, "kanto_ascendant.oras", "failed KASC owner receipt")
eq(native, true, "failed exclusive KASC did not request native fallback")
eq(defaultDraws, 1, "VASC default drew after exclusive KASC failure")
eq(shotCommits(before), 0,
  "partial provider pixels leaked into the authoritative shot")
local partialWasPrivate = false
for index = before, #operations do
  local item = operations[index]
  if item.kind == "rectangle" and item.target ~= shotCanvas then
    partialWasPrivate = true
  end
end
eq(partialWasPrivate, true, "failed provider did not draw into private layer")
eq(currentCanvas, screenCanvas, "failed provider leaked its canvas")
eq(blendMode, "add", "failed provider leaked blend mode")
eq(blendAlpha, "premultiplied", "failed provider leaked blend alpha")
check(#warnings >= 1, "provider failure emitted no diagnostic")

eq(OverworldBattle.setBattleHudProvider(nil), true,
  "external provider could not be cleared")

-- A complete private provider layer whose authoritative blit fails may not
-- publish its deferred card latch/receipt. The same provider must recover on
-- the next healthy frame without process or battle restart.
failShotBlit = true
before = #operations + 1
drew, owner, native = drawProvider(battle, shot)
eq(drew, false, "failed authoritative blit reported provider success")
eq(shotCommits(before), 0, "failed provider blit reported a shot commit")
eq(defaultDraws, 2, "failed-blit provider draw count")
eq(deferredCommits, 1,
  "deferred status latch ran before/after a failed authoritative blit")
failShotBlit = false

-- Once a complete layer was blitted it owns the frame even if its private
-- bookkeeping callback declines or throws. Reporting false here would make
-- native/legacy fallback paint a second HUD over already-committed pixels.
for _, mode in ipairs({ "false", "error" }) do
  deferredMode = mode
  before = #operations + 1
  drew, owner, native = drawProvider(battle, shot)
  eq(drew, true, "post-blit " .. mode .. " callback lost pixel ownership")
  eq(owner, "voxel_ascendant.oras",
    "post-blit " .. mode .. " callback lost provider owner")
  eq(shotCommits(before), 1,
    "post-blit " .. mode .. " callback duplicated/missed provider pixels")
end
eq(defaultDraws, 4, "post-blit callback fixture draw count")
eq(deferredCommits, 3, "post-blit callback execution count")

deferredMode = "ok"
before = #operations + 1
drew, owner, native = drawProvider(battle, shot)
eq(drew, true, "VASC default did not recover after KASC removal")
eq(owner, "voxel_ascendant.oras", "recovered default owner")
eq(defaultDraws, 5, "recovered default draw count")
eq(shotCommits(before), 1, "recovered default did not commit")
eq(deferredCommits, 4,
  "recovered provider did not publish exactly one deferred latch")

-- A provider with exact damage bounds keeps the disposable transaction, but
-- must not clear or composite its empty 640x360 surroundings. This is the
-- failing-first analogue of the real 3420x2214 Oak's Lab regression.
local bounded = defaultProvider()
bounded.damageBoundsSchema = "voxel-ascendant/hud-damage-bounds/v1"
bounded.damageBounds = function()
  return {
    schema="voxel-ascendant/hud-damage-bounds/v1", width=640, height=360,
    rects={
      { x=8, y=6, w=96, h=52 },
      { x=490, y=290, w=140, h=62 },
    },
  }
end
eq(OverworldBattle.setDefaultBattleHudProvider(bounded), true,
  "bounded default provider registration")
before = #operations + 1
drew, owner = drawProvider(battle, shot)
eq(drew, true, "bounded provider declined")
eq(owner, "voxel_ascendant.oras", "bounded provider owner")
eq(shotCommits(before), 2,
  "bounded provider did not commit exactly its two occupied regions")
local fullClears, transparentRegionClears = 0, 0
for index = before, #operations do
  local item = operations[index]
  if item.kind == "clear" then fullClears = fullClears + 1 end
  if item.kind == "rectangle" and item.target ~= shotCanvas then
    transparentRegionClears = transparentRegionClears + 1
  end
end
eq(fullClears, 0, "bounded provider still cleared the full transaction canvas")
check(transparentRegionClears >= 2,
  "bounded provider did not clear its occupied regions")
eq(currentScissor, nil, "bounded provider leaked its damage scissor")

local function setUpvalue(fn, wanted, value)
  for index = 1, 100 do
    local name = debug.getupvalue(fn, index)
    if not name then break end
    if name == wanted then
      debug.setupvalue(fn, index, value)
      return true
    end
  end
  return false
end
check(setUpvalue(OverworldBattle.finish, "session", { battle=battle }),
  "provider finish test could not install a battle session")
OverworldBattle.finish()
eq(defaultFinishes, 1,
  "battle finish did not clear the bundled provider's latch state")
OverworldBattle.finish()
eq(defaultFinishes, 1,
  "idempotent finish cleared the same provider battle twice")

local invalid, invalidReason = OverworldBattle.setBattleHudProvider({})
eq(invalid, false, "invalid external provider was accepted")
eq(invalidReason, "invalid-provider", "invalid provider reason")

print("battle HUD provider ownership: ok")
