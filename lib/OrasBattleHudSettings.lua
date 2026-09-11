-- VASC-owned settings for its standalone ORAS battle HUD.
--
-- VASC remains the autonomous owner when Kanto Ascendant is merely installed.
-- These rows disappear only when an optional KASC HUD explicitly claims the
-- public replacement-provider slot. The persisted VASC values are deliberately
-- retained so a declined/removed claimant restores the prior presentation.

local V = ...
local ModSetting = V.require("ModSetting")

local Settings = {}
local OverworldBattle = nil
do
  local ok, value = pcall(V.require, "OverworldBattle")
  if ok and type(value) == "table" then OverworldBattle = value end
end

-- Presentation of the engine's native dialogue, choice, title/START and
-- ordinary list surfaces. This is deliberately independent from the battle
-- HUD switch: custom KASC/VASC/PC screens retain their own renderer, while
-- GAME DEFAULT restores the untouched Gen1Recomp furniture live. Bag drawing
-- has its own explicit owner-safe choice immediately below.
Settings.uiSkinSetting = ModSetting.new(
  "qol_ui_skin", "OVERWORLD MENUS",
  { "oras", "standard" }, { "ORAS GLASS", "GAME DEFAULT" }, "oras")

-- Bag behaviour and the captured fallback renderer remain owned by the game,
-- Useful Bag or KASC. D/P ORAS WIDE is the default presentation; an explicit
-- GAME/KASC selection keeps the provider draw.
-- Only the two real 512x288 presentations are public choices. Historical
-- compact values still resolve safely, but migrate to their corresponding
-- WIDE presentation instead of remaining selectable menu rungs.
Settings.bagSkinSetting = ModSetting.new(
  "qol_bag_skin", "BAG MENU",
  { "external", "oras_wide", "frlg_wide" },
  { "GAME/KASC", "D/P ORAS WIDE", "FRLG ORAS WIDE" }, "oras_wide")
Settings.bagSkinSetting:aliasLegacy("oras", "oras_wide")
Settings.bagSkinSetting:aliasLegacy("frlg", "frlg_wide")

-- The pocket-insert accent remains tied to the explicitly selected VASC Bag.
-- AUTO follows KASC's public character identity; no provider identity means
-- the long-standing red fallback.
Settings.bagColorSetting = ModSetting.new(
  "qol_bag_color", "BAG ACCENT",
  { "auto", "red", "blue", "green" },
  { "AUTO", "RED", "BLUE", "GREEN" }, "auto")

-- Body/edition colour is a second, independent choice. It is consumed only
-- after a VASC Bag renderer owns draw, so GAME/KASC remains a strict no-touch
-- path. AUTO follows the active edition and ORAS preserves source pixels.
Settings.bagBodySetting = ModSetting.new(
  "qol_bag_body", "BAG BODY",
  { "auto", "oras", "red", "blue", "yellow", "gold", "silver", "crystal" },
  { "AUTO", "ORAS", "RED", "BLUE", "YELLOW", "GOLD", "SILVER", "CRYSTAL" },
  "auto")

Settings.bagFormSetting = ModSetting.new(
  "qol_bag_form", "BAG SHAPE",
  { "auto", "round", "handle" },
  { "AUTO", "NORMAL", "HANDLE" }, "auto")

Settings.styleSetting = ModSetting.new(
  "battleHudStyle", "BATTLE HUD",
  { "oras", "standard" }, { "ORAS", "STANDARD" }, "oras")

Settings.languageSetting = ModSetting.new(
  "hud_language", "HUD LANGUAGE",
  { "auto", "de", "en" }, { "AUTO", "DEUTSCH", "ENGLISH" }, "auto")

Settings.scaleSetting = ModSetting.new(
  "hud_scale", "ORAS HUD SIZE",
  { 0.75, 0.9, 1.0, 1.25, 1.5, 2.0 },
  { "75%", "90%", "100%", "125%", "150%", "200%" }, 0.9)

-- The authored ORAS furniture used to have one fixed glass strength. Keep the
-- two large occluding surfaces independent: compact status cards need a little
-- more backing for their HP numbers, while the much larger message panel can
-- reveal more of the arena. Only background glass reads these values; ink,
-- bars, icons, focus cues and edition borders remain at their authored alpha.
local glassValues, glassLabels = {}, {}
for percent = 0, 100, 5 do
  glassValues[#glassValues + 1] = percent / 100
  glassLabels[#glassLabels + 1] = tostring(percent) .. "%"
end

Settings.statusGlassSetting = ModSetting.new(
  "oras_status_glass", "STATUS GLASS",
  glassValues, glassLabels, 0.75)

Settings.textGlassSetting = ModSetting.new(
  "oras_text_glass", "TEXT GLASS",
  glassValues, glassLabels, 0.65)

Settings.anchorSetting = ModSetting.new(
  "status_anchor", "ORAS HUD ANCHOR",
  { "outside", "above", "corners" },
  { "OUTSIDE", "ABOVE", "CORNERS" }, "outside")

local offsetValues = { -80, -40, 0, 40, 80 }
local offsetLabels = { "-80", "-40", "0", "+40", "+80" }
Settings.playerXSetting = ModSetting.new(
  "player_hud_x", "PLAYER HUD X", offsetValues, offsetLabels, 0)
Settings.playerYSetting = ModSetting.new(
  "player_hud_y", "PLAYER HUD Y", offsetValues, offsetLabels, 0)
Settings.enemyXSetting = ModSetting.new(
  "enemy_hud_x", "ENEMY HUD X", offsetValues, offsetLabels, 0)
Settings.enemyYSetting = ModSetting.new(
  "enemy_hud_y", "ENEMY HUD Y", offsetValues, offsetLabels, 0)

Settings.wildDvsSetting = ModSetting.new(
  "wild_dvs", "WILD DVs", { false, true }, { "OFF", "ON" }, false)

Settings.battle_textbox_x = ModSetting.new("battle_textbox_x", "TEXTBOX X",
  {-60, -55, -50, -45, -40, -35, -30, -25, -20, -15, -10, -5, 0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60}, {"-60%", "-55%", "-50%", "-45%", "-40%", "-35%", "-30%", "-25%", "-20%", "-15%", "-10%", "-5%", "0%", "+5%", "+10%", "+15%", "+20%", "+25%", "+30%", "+35%", "+40%", "+45%", "+50%", "+55%", "+60%"}, 0)
Settings.battle_textbox_y = ModSetting.new("battle_textbox_y", "TEXTBOX Y",
  {-60, -55, -50, -45, -40, -35, -30, -25, -20, -15, -10, -5, 0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60}, {"-60%", "-55%", "-50%", "-45%", "-40%", "-35%", "-30%", "-25%", "-20%", "-15%", "-10%", "-5%", "0%", "+5%", "+10%", "+15%", "+20%", "+25%", "+30%", "+35%", "+40%", "+45%", "+50%", "+55%", "+60%"}, 0)

Settings.battle_controls_scale = ModSetting.new("battle_controls_scale", "BUTTON SIZE",
  {0.5, 0.75, 0.9, 1, 1.1, 1.25, 1.5}, {"50%", "75%", "90%", "100%", "110%", "125%", "150%"}, 1)
Settings.battle_controls_x = ModSetting.new("battle_controls_x", "BUTTON X",
  {-40, -35, -30, -25, -20, -15, -10, -5, 0, 5, 10, 15, 20, 25, 30, 35, 40}, {"-40%", "-35%", "-30%", "-25%", "-20%", "-15%", "-10%", "-5%", "0%", "+5%", "+10%", "+15%", "+20%", "+25%", "+30%", "+35%", "+40%"}, 0)
Settings.battle_controls_y = ModSetting.new("battle_controls_y", "BUTTON LIFT",
  {0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60}, {"0%", "5%", "10%", "15%", "20%", "25%", "30%", "35%", "40%", "45%", "50%", "55%", "60%"}, 0)
Settings.battle_controls_transparency = ModSetting.new("battle_controls_transparency", "BUTTON TRANSPARENCY",
  {0,10,20,30,40,50,60,70,80,90}, {"0%","10%","20%","30%","40%","50%","60%","70%","80%","90%"}, 0)
Settings.battle_controls_shape = ModSetting.new("battle_controls_shape", "BUTTON SHAPE",
  {"auto", "original", "round", "glass"}, {"AUTO", "ORIGINAL", "COMPLETE ORAS", "GLASS"}, "auto")

Settings.all = {
  Settings.battle_textbox_x, Settings.battle_textbox_y,
  Settings.battle_controls_scale,
  Settings.battle_controls_x,
  Settings.battle_controls_y,
  Settings.battle_controls_shape,
  Settings.battle_controls_transparency,

  Settings.uiSkinSetting,
  Settings.bagSkinSetting,
  Settings.bagColorSetting,
  Settings.bagBodySetting,
  Settings.bagFormSetting,
  Settings.styleSetting,
  Settings.languageSetting,
  Settings.scaleSetting,
  Settings.statusGlassSetting,
  Settings.textGlassSetting,
  Settings.anchorSetting,
  Settings.playerXSetting,
  Settings.playerYSetting,
  Settings.enemyXSetting,
  Settings.enemyYSetting,
  Settings.wildDvsSetting,
}

local KASC_IDS = { "kanto_ascendant", "trainer_rematch" }

function Settings.kascActive(mod)
  if type(mod) ~= "table" or type(mod.find) ~= "function" then return false end
  for _, id in ipairs(KASC_IDS) do
    local ok, handle = pcall(mod.find, id)
    if ok and type(handle) == "table" then return true, handle, id end
  end
  return false
end

-- Installation is not ownership. Current public KASC can provide trainer art,
-- Mega capability and QoL data without replacing VASC's HUD. A future/optional
-- KASC HUD becomes authoritative only through the renderer's public external
-- provider receipt or an explicit versioned ownership export.
function Settings.kascHudClaim(mod)
  local installed, handle, id = Settings.kascActive(mod)
  if not installed then return false end

  local exports = type(handle.exports) == "table" and handle.exports or nil
  local ownership = exports and exports.battleHudOwnership or nil
  if type(ownership) == "table" and ownership.apiVersion == 1
      and ownership.claimsVascHud == true then
    return true, handle, id, "export"
  end
  local hud = exports and exports.ascendantBattleHud or nil
  if type(hud) == "table" and hud.apiVersion == 1
      and hud.claimsVascHud == true then
    return true, handle, id, "export"
  end

  if OverworldBattle
      and type(OverworldBattle.battleHudProviderReceipt) == "function" then
    local ok, receipt = pcall(OverworldBattle.battleHudProviderReceipt)
    local externalId = ok and type(receipt) == "table"
      and receipt.externalId or nil
    if type(externalId) == "string"
        and (externalId == id or externalId:match("^" .. id .. "%.")) then
      return true, handle, id, "provider"
    end
  end
  return false, handle, id
end

function Settings.vascOwnsHud(mod)
  return not Settings.kascHudClaim(mod)
end

function Settings.style()
  return tostring(Settings.styleSetting:get() or "oras"):lower()
end

function Settings.orasSelected(mod)
  return Settings.vascOwnsHud(mod) and Settings.style() == "oras"
end

function Settings.standardSelected(mod)
  return Settings.vascOwnsHud(mod) and Settings.style() == "standard"
end

function Settings.receipt(mod)
  local installed, handle, id = Settings.kascActive(mod)
  local delegated, _, _, source = Settings.kascHudClaim(mod)
  local exports = installed and type(handle.exports) == "table"
    and handle.exports or nil
  local megaAvailable = exports and type(exports.megaEvolution) == "table"
  return {
    apiVersion = 1,
    owner = delegated and id or "VOXEL_ASCENDANT",
    delegated = delegated == true,
    style = delegated and "kasc" or Settings.style(),
    claimSource = source,
    kascInstalled = installed == true,
    mega = megaAvailable == true,
    megaPolicy = "exact-active-pokemon-capability",
  }
end

-- HUD POS=FRAME was the historical implicit "use the standard HUD" switch.
-- Translate it once into the explicit style key, then return position to AUTO
-- so it cannot remain a second invisible ownership switch. Raw option buckets
-- are inspected because mod.options:get() already substitutes the new default.
function Settings.migrateLegacyFrame(mod, game, positionSetting)
  if not Settings.vascOwnsHud(mod) or type(game) ~= "table" then return false end
  local id = type(mod.id) == "string" and mod.id or "VOXEL_ASCENDANT"
  local saveOptions = game.save and game.save.options
  local saveBuckets = saveOptions and saveOptions.modOptions
  local saveBucket = type(saveBuckets) == "table" and saveBuckets[id] or nil
  local loader = game.mods
  local loaderBuckets = loader and loader.modOptions
  local loaderBucket = type(loaderBuckets) == "table" and loaderBuckets[id] or nil
  local style = type(saveBucket) == "table" and saveBucket.battleHudStyle
             or type(loaderBucket) == "table" and loaderBucket.battleHudStyle
  local position = type(saveBucket) == "table" and saveBucket.battleHudPosition
                or type(loaderBucket) == "table" and loaderBucket.battleHudPosition
  if style ~= nil or position ~= "frame" then return false end

  Settings.styleSetting:setValue("standard", game, true)
  if positionSetting and type(positionSetting.setValue) == "function" then
    positionSetting:setValue("auto", game, true)
  else
    if type(saveBucket) == "table" then saveBucket.battleHudPosition = "auto" end
    if type(loaderBucket) == "table" then loaderBucket.battleHudPosition = "auto" end
  end
  if type(game.writeOptions) == "function" then pcall(game.writeOptions, game) end
  return true
end

return Settings
