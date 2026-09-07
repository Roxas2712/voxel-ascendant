-- Optional Gen-II/QoL details that belong to VASC's one battle HUD.
--
-- VASC owns the status-band geometry in staged battles.  Gender, EXP and the
-- caught marker therefore have to be painted into that same source texture;
-- a late screen-space overlay would stay behind in the centred 160x144 frame
-- when the HUD is snapped to a desktop or phone edge.
--
-- Kanto Ascendant remains an optional peer.  Its released renderer already
-- consumes VASC's exact snapped geometry, so when a matching public feature
-- is present it remains the single painter and these rows proxy its saved
-- value.  Without KASC, the compact implementations below provide the same
-- useful HUD information from VASC alone.

local V = ...
local ModSetting = V.require("ModSetting")

local Extras = {}
local hudOwnerPredicate = nil

Extras.genderSetting = ModSetting.new(
  "battleHudGender", "HUD GENDER",
  { false, true }, { "OFF", "ON" }, true)

Extras.expSetting = ModSetting.new(
  "battleHudExp", "HUD EXP",
  { "off", "black", "blue" },
  { "OFF", "BLACK", "BLUE" }, "blue")

Extras.caughtSetting = ModSetting.new(
  "battleHudCaught", "HUD CAUGHT",
  { "off", "grey", "red" },
  { "OFF", "GREY", "RED" }, "red")

local KASC_IDS = { "kanto_ascendant", "trainer_rematch" }
local GENDER_GUARD_KEY = "__voxelAscendantGenderSettingGuard"

local function kascHandle()
  local mod = V and V.mod
  if type(mod) ~= "table" or type(mod.find) ~= "function" then return nil end
  for _, id in ipairs(KASC_IDS) do
    local ok, handle = pcall(mod.find, id)
    if ok and type(handle) == "table" then return handle, id end
  end
  return nil
end

function Extras.setHudOwnerPredicate(predicate)
  hudOwnerPredicate = type(predicate) == "function" and predicate or nil
  return hudOwnerPredicate ~= nil
end

local function vascOwnsHud()
  if hudOwnerPredicate then
    local ok, owns = pcall(hudOwnerPredicate)
    if ok then return owns == true end
  end
  return kascHandle() == nil
end

local function optionBucket(container, id, create)
  if type(container) ~= "table" then return nil end
  if create then container.modOptions = container.modOptions or {} end
  local all = container.modOptions
  if type(all) ~= "table" then return nil end
  if create then all[id] = all[id] or {} end
  return type(all[id]) == "table" and all[id] or nil
end

local function optionGet(handle, key)
  local options = type(handle) == "table" and handle.options or nil
  if type(options) ~= "table" or type(options.get) ~= "function" then
    return nil
  end
  local ok, value = pcall(options.get, options, key)
  return ok and value or nil
end

-- Return value, claimed.  `claimed` means a released KASC QoL renderer owns
-- this feature and will draw it from VASC's validated HUD geometry.
local function companionChoice(game, key, allowed)
  local handle, id = kascHandle()
  if not handle then return nil, false end
  local exports = type(handle.exports) == "table" and handle.exports or nil
  -- expPixels is the public data receipt exported by released KASC QoL builds.
  -- HUD geometry is no longer exported by KASC: VASC owns the exact provider
  -- canvas, while KASC's read-only battle service reports external ownership
  -- and suppresses its native-coordinate painters for that frame.
  local quality = type(exports) == "table" and exports.qualityOfLife or nil
  local battleService = type(quality) == "table" and quality.battle or nil
  if type(exports) ~= "table" or type(exports.expPixels) ~= "function"
      or type(battleService) ~= "table"
      or type(battleService.externalHudOwned) ~= "function" then
    return nil, false
  end
  local saveOptions = game and game.save and game.save.options
  local loaderOptions = game and game.mods
  local bucket = optionBucket(saveOptions, id, false)
    or optionBucket(loaderOptions, id, false)
  local master = bucket and bucket.ascendant_qol
  if master == nil then master = optionGet(handle, "ascendant_qol") end
  if master == false then return "off", true end
  local value = bucket and bucket[key]
  if value == nil then value = optionGet(handle, key) end
  return allowed[value] and value or nil, allowed[value] == true
end

local function writeCompanionChoice(game, key, value, persist)
  local handle, id = kascHandle()
  if not handle or type(game) ~= "table" then return false end
  local saveOptions = game.save and game.save.options
  local loaderOptions = game.mods
  local wrote = false
  local function write(container)
    local bucket = optionBucket(container, id, true)
    if bucket then
      bucket[key] = value
      -- Selecting a concrete VASC QoL value is an explicit opt-in.  Wake the
      -- companion master only here; merely opening or drawing the menu never
      -- changes another package's options.
      if value ~= "off" and bucket.ascendant_qol == false then
        bucket.ascendant_qol = true
      end
      wrote = true
    end
  end
  -- Do not use ipairs({ saveOptions, loaderOptions }) here: a new game can
  -- briefly have no save-options table yet, and ipairs would then stop before
  -- visiting the live loader copy.
  write(saveOptions)
  if loaderOptions ~= saveOptions then write(loaderOptions) end
  if wrote and persist ~= false and type(game.writeOptions) == "function" then
    pcall(game.writeOptions, game)
  end
  return wrote
end

local EXP_ALLOWED = { off=true, black=true, blue=true }
local CAUGHT_ALLOWED = { off=true, grey=true, red=true }

local function resolvedChoice(setting, game, key, allowed)
  local companion, claimed = companionChoice(game, key, allowed)
  if claimed then return companion, true end
  return setting:get(), false
end

local function labelFor(setting, value)
  for index, candidate in ipairs(setting.values) do
    if candidate == value then return setting.labels[index] end
  end
  return setting.labels[setting.defaultIndex or 1]
end

local function proxyRow(setting, companionKey, allowed)
  local row = setting:row()
  row.value = function()
    local ok, Game = pcall(require, "src.core.Game")
    local game = ok and Game or nil
    local value = resolvedChoice(setting, game, companionKey, allowed)
    return labelFor(setting, value)
  end
  row.step = function(game, direction)
    local value, claimed = resolvedChoice(
      setting, game, companionKey, allowed)
    local index = setting.defaultIndex or 1
    for i, candidate in ipairs(setting.values) do
      if candidate == value then index = i break end
    end
    local n = #setting.values
    index = ((index - 1 + (direction or 1)) % n) + 1
    local nextValue = setting.values[index]
    -- Stage the optional peer value first. ModSetting then writes VASC's own
    -- value and persists both tables in one options write.
    if claimed then
      writeCompanionChoice(game, companionKey, nextValue, false)
    end
    setting:setValue(nextValue, game)
    return true
  end
  return row
end

function Extras.expRow()
  return proxyRow(Extras.expSetting, "qol_exp_bar", EXP_ALLOWED)
end

function Extras.caughtRow()
  return proxyRow(
    Extras.caughtSetting, "qol_caught_indicator", CAUGHT_ALLOWED)
end

function Extras.genderEnabled()
  return Extras.genderSetting:get() == true
end

function Extras.expChoice(game)
  local value = resolvedChoice(
    Extras.expSetting, game, "qol_exp_bar", EXP_ALLOWED)
  return EXP_ALLOWED[value] and value or "off"
end

function Extras.caughtChoice(game)
  local value = resolvedChoice(
    Extras.caughtSetting, game, "qol_caught_indicator", CAUGHT_ALLOWED)
  return CAUGHT_ALLOWED[value] and value or "off"
end

-- Gen-II female-rate classes for the original 151.  Everything not listed is
-- the ordinary 50:50 class.  Gender is derived from the existing Attack DV,
-- so VASC never invents or persists another personality field.
local RATIO = {}
local function ratio(value, ...)
  for i = 1, select("#", ...) do RATIO[select(i, ...)] = value end
end
ratio(-1, 81,82,100,101,120,121,132,137,144,145,146,150,151)
ratio(8, 29,30,31,113,115,124)
ratio(0, 32,33,34,106,107,128)
ratio(1, 1,2,3,4,5,6,7,8,9,133,134,135,136,138,139,140,141,142,143)
ratio(2, 58,59,63,64,65,66,67,68)
ratio(6, 35,36,37,38,39,40)
-- Gorochu evolves from Raichu without replacing the Pokemon record. It keeps
-- the same ordinary 50:50 Gen-II ratio instead of becoming genderless merely
-- because the companion's 251-entry breeding table has no custom #1026 row.
ratio(4, 1026)

local function dexOf(mon, gameOrData)
  local data = type(gameOrData) == "table"
    and (gameOrData.data or gameOrData) or nil
  local def = data and data.pokemon and mon and data.pokemon[mon.species]
  return def and tonumber(def.dex) or nil
end

function Extras.gender(mon, gameOrData)
  if type(mon) ~= "table" then return nil end
  local explicit = mon.gender or mon.sex
  if explicit == "MALE" or explicit == "male" or explicit == "M" then
    return "MALE"
  elseif explicit == "FEMALE" or explicit == "female" or explicit == "F" then
    return "FEMALE"
  elseif (explicit == "GENDERLESS" or explicit == "genderless")
      and mon.species ~= "GOROCHU" then
    return nil
  end
  local dex = dexOf(mon, gameOrData)
  if not dex then return nil end
  local femaleRate = RATIO[dex]
  if femaleRate == nil then femaleRate = 4 end
  if femaleRate < 0 then return nil end
  if femaleRate == 0 then return "MALE" end
  if femaleRate >= 8 then return "FEMALE" end
  local attack = mon.dvs and tonumber(mon.dvs.attack) or 0
  attack = math.max(0, math.min(15, math.floor(attack)))
  return attack < femaleRate * 2 and "FEMALE" or "MALE"
end

function Extras.genderSymbol(mon, gameOrData)
  local value = Extras.gender(mon, gameOrData)
  return value == "MALE" and "♂" or value == "FEMALE" and "♀" or nil
end

local function normalizedGender(value)
  value = tostring(value or ""):upper()
  if value == "MALE" or value == "M" or value == "♂" then return "MALE" end
  if value == "FEMALE" or value == "F" or value == "♀" then return "FEMALE" end
  if value == "GENDERLESS" or value == "NONE" or value == "-" then
    return "GENDERLESS"
  end
  return nil
end

-- Storage and party providers need the same gender authority as the battle
-- HUD. Prefer KASC's public 251-species service when it exists; VASC's local
-- Gen-I DV resolver remains the standalone fallback. Unknown/genderless data
-- is represented explicitly so a presentation can render a stable dash
-- without inventing or persisting a gender on the live Pokemon record.
function Extras.presentationGender(mon, gameOrData)
  if type(mon) ~= "table" then return "GENDERLESS" end
  local explicit = normalizedGender(mon.gender or mon.sex)
  if explicit and not (mon.species == "GOROCHU"
      and explicit == "GENDERLESS") then return explicit end

  local handle = kascHandle()
  local exports = handle and type(handle.exports) == "table"
    and handle.exports or nil
  local provider = exports and exports.pokemonGender or nil
  if type(provider) == "table" then
    for _, key in ipairs({ "getMonGender", "get" }) do
      if type(provider[key]) == "function" then
        local ok, value = pcall(provider[key], mon, gameOrData)
        local resolved = ok and normalizedGender(value) or nil
        if resolved and not (mon.species == "GOROCHU"
            and resolved == "GENDERLESS") then return resolved end
      end
    end
    if type(provider.symbol) == "function" then
      local ok, value = pcall(provider.symbol, mon, gameOrData)
      local resolved = ok and normalizedGender(value) or nil
      if resolved and not (mon.species == "GOROCHU"
          and resolved == "GENDERLESS") then return resolved end
    end
  end

  return Extras.gender(mon, gameOrData) or "GENDERLESS"
end

function Extras.presentationGenderSymbol(mon, gameOrData)
  local value = Extras.presentationGender(mon, gameOrData)
  return value == "MALE" and "♂" or value == "FEMALE" and "♀" or nil
end

local function enemyHudVisible(battle, slide)
  local enemy = battle and battle.enemy
  return enemy and not battle.showEnemyTrainer and not battle.enemySendingOut
    and not (battle.growInScale and battle:growInScale(enemy))
    and slide == 0 and not battle.introBalls and not enemy.fainted
end

local function playerHudVisible(battle, slide)
  return battle and battle.player and not (battle.safari or battle.demo)
    and not battle.showPlayerBack and slide == 0
end

local function resolvedGenderSymbol(battle, mon)
  -- The battle object owns the species catalog (`battle.data`) while storage
  -- passes a Game (`game.data`). Both shapes are accepted by the shared
  -- resolver, and companion services likewise receive a complete data owner.
  return Extras.presentationGenderSymbol(mon, battle)
end

local function drawGender(battle, slide)
  if not Extras.genderEnabled() then return end
  local ok, Font = pcall(require, "src.render.Font")
  if not ok or type(Font.draw) ~= "function" then return end
  if enemyHudVisible(battle, slide) then
    local symbol = resolvedGenderSymbol(
      battle, battle.enemy and battle.enemy.mon)
    if symbol then Font.draw(symbol, 72, 8) end
  end
  if playerHudVisible(battle, slide) then
    local symbol = resolvedGenderSymbol(
      battle, battle.player and battle.player.mon)
    if symbol then Font.draw(symbol, 104, 64) end
  end
end

local function expPixels(battle)
  local mon = battle and battle.player and battle.player.mon
  local data = battle and battle.data
  local def = data and data.pokemon and mon and data.pokemon[mon.species]
  if not (mon and def) then return 0 end
  local ok, Growth = pcall(require, "src.pokemon.Growth")
  if not ok or type(Growth.expForLevel) ~= "function" then return 0 end
  local cap = data.constants and tonumber(data.constants.levelCap) or 100
  if (tonumber(mon.level) or 0) >= cap then return 67 end
  local level = tonumber(mon.level) or 1
  local current = tonumber(Growth.expForLevel(
    def.growthRate, level, data.growth_rates)) or 0
  local following = tonumber(Growth.expForLevel(
    def.growthRate, level + 1, data.growth_rates)) or current
  local needed = following - current
  if needed <= 0 then return 0 end
  local progress = math.max(0, math.min(
    needed, (tonumber(mon.exp) or tonumber(current) or 0) - current))
  return math.floor(progress * 67 / needed)
end

Extras.expPixels = expPixels

local function drawExp(battle, slide, mode)
  if not playerHudVisible(battle, slide) or mode == "off" then return end
  local px = expPixels(battle)
  if px <= 0 then return end
  local g = love and love.graphics
  if not (g and type(g.rectangle) == "function") then return end
  if mode == "blue" then
    g.setColor(56 / 255, 144 / 255, 240 / 255, 1)
  else
    g.setColor(0, 0, 0, 1)
  end
  g.rectangle("fill", 80 + 67 - px, 89, px, 2)
end

local ballImage, ballScaleX, ballScaleY
local function caughtBall()
  if ballImage == false then return nil end
  if not ballImage then
    local g = love and love.graphics
    if not (g and type(g.newImage) == "function") then
      ballImage = false
      return nil
    end
    local ok, image = pcall(g.newImage, "assets/hud/battleplate_ball.png")
    if not (ok and image and type(image.getDimensions) == "function") then
      ballImage = false
      return nil
    end
    local w, h = image:getDimensions()
    if not (w and h and w > 0 and h > 0) then
      ballImage = false
      return nil
    end
    if type(image.setFilter) == "function" then
      pcall(image.setFilter, image, "nearest", "nearest")
    end
    ballImage = image
    ballScaleX, ballScaleY = 8 / w, 8 / h
  end
  return ballImage, ballScaleX, ballScaleY
end

local function enemyNameX(battle)
  local name = tostring(battle and battle.enemy and battle.enemy.name or "")
  local ok, Font = pcall(require, "src.render.Font")
  local glyphs = ok and type(Font.split) == "function" and #Font.split(name)
                 or #name
  return 8 + (glyphs <= 2 and 16 or glyphs <= 4 and 8 or 0)
end

local function drawCaught(battle, slide, mode)
  if mode == "off" or battle.kind ~= "wild" or battle.demo or battle.ghost
      or not enemyHudVisible(battle, slide) then return end
  local species = battle.enemy and battle.enemy.mon
                  and battle.enemy.mon.species
  local dex = battle.game and battle.game.save and battle.game.save.pokedex
  if not (species and dex and dex.owned and dex.owned[species]) then return end
  local image, sx, sy = caughtBall()
  if not image then return end
  local shake = battle.fx and tonumber(battle.fx.hudShakeX) or 0
  love.graphics.setColor(mode == "red" and 1 or 0.52,
                         mode == "red" and 1 or 0.52,
                         mode == "red" and 1 or 0.52, 1)
  love.graphics.draw(image, enemyNameX(battle) - 1 + shake, 7, 0, sx, sy)
end

-- Called while OverworldBattle's transparent 160x144 status texture is the
-- active canvas.  The complete texture is subsequently cut into VASC's two
-- bands, so every detail inherits mobile position, scale and alpha exactly.
function Extras.draw(battle, slide)
  if type(battle) ~= "table" then return false end
  -- Installation and presentation ownership are separate. A KASC service may
  -- supply gender/EXP/caught data while VASC keeps the actual HUD; only an
  -- explicit public HUD claimant disables this drawer.
  if not vascOwnsHud() then return false end
  local game = battle.game
  local expMode = Extras.expChoice(game)
  local caughtMode = Extras.caughtChoice(game)

  local g = love and love.graphics
  if not (g and type(g.setColor) == "function") then return false end
  local canPush = type(g.push) == "function" and type(g.pop) == "function"
  if canPush then g.push("all") end
  if type(g.setShader) == "function" then g.setShader() end
  g.setColor(0, 0, 0, 1)
  drawGender(battle, slide)
  drawExp(battle, slide, expMode)
  drawCaught(battle, slide, caughtMode)
  if canPush then g.pop() else g.setColor(1, 1, 1, 1) end
  return true
end

function Extras.guardCompanionGender()
  local handle = kascHandle()
  local gender = handle and type(handle.exports) == "table"
    and handle.exports.pokemonGender or nil
  if type(gender) ~= "table" or type(gender.symbol) ~= "function" then
    return false
  end
  local receipt = rawget(gender, GENDER_GUARD_KEY)
  -- Older VASC hot-loads wrapped this KASC export with VASC's private gender
  -- setting. Return exact ownership to KASC and never install that proxy in
  -- the merged architecture.
  if type(receipt) == "table" and receipt.wrapper == gender.symbol then
    gender.symbol = receipt.original
    gender[GENDER_GUARD_KEY] = nil
    return true
  end
  return false
end

-- KASC 6.5.20 exports its live breeding table, but that table ends at #251.
-- Gorochu's runtime dex is #1026, so the companion's otherwise authoritative
-- gender/daycare service reads no row and reports GENDERLESS. Extend only the
-- missing exact guest entry with Raichu's canonical 50:50 class and family;
-- a future KASC row always wins and no Pokemon/save object is mutated.
function Extras.ensureGorochuGenderData()
  local handle = kascHandle()
  local exports = handle and type(handle.exports) == "table"
    and handle.exports or nil
  local breeding = exports and exports.breedingData or nil
  if type(breeding) ~= "table" then return false end
  if breeding[1026] ~= nil then return false end
  breeding[1026] = {
    gender = 4,
    hatch = 10,
    groups = { "ground", "fairy" },
    vascGorochuCompat = true,
  }
  return true
end

function Extras.install(mod, overworldBattle)
  if type(overworldBattle) ~= "table"
      or type(overworldBattle.setHudExtrasDrawer) ~= "function" then
    return false
  end
  overworldBattle.setHudExtrasDrawer(Extras.draw)
  Extras.guardCompanionGender()
  Extras.ensureGorochuGenderData()
  if type(mod) == "table" and type(mod.events) == "table" then
    if type(mod.events.once) == "function" then
      mod.events:once("mods.loaded", function()
        Extras.guardCompanionGender()
        Extras.ensureGorochuGenderData()
      end)
    end
    if type(mod.events.on) == "function" then
      mod.events:on("game.ready", Extras.guardCompanionGender)
    end
  end
  return true
end

function Extras.invalidate()
  ballImage, ballQuad = nil, nil
end

return Extras
