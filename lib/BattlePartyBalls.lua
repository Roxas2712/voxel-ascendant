-- Make the six party receipts immediately readable: usable Pokemon are red;
-- fainted Pokemon are grey and struck through. Empty slots stay neutral.

local V = ...
local BattlePartyBalls = {}
local unpackValues = table.unpack or unpack
local hudOwnerPredicate = nil

function BattlePartyBalls.setHudOwnerPredicate(predicate)
  hudOwnerPredicate = type(predicate) == "function" and predicate or nil
  return hudOwnerPredicate ~= nil
end

local function packValues(...)
  return { n = select("#", ...), ... }
end

local function kascOwnsHud()
  if hudOwnerPredicate then
    local ok, vascOwns = pcall(hudOwnerPredicate)
    if ok then return vascOwns ~= true end
  end
  local mod = V and V.mod
  if type(mod) ~= "table" or type(mod.find) ~= "function" then return false end
  for _, id in ipairs({ "kanto_ascendant", "trainer_rematch" }) do
    local ok, handle = pcall(mod.find, id)
    if ok and type(handle) == "table" then return true end
  end
  return false
end

local BALL_ASSETS = {
  healthy = "assets/hud/battleplate_ball.png",
  fainted = "assets/hud/battleplate_ball_defeated.png",
  empty = "assets/hud/battleplate_ball_empty.png",
}

local quads
local function atlas()
  if quads ~= nil then return quads or nil end
  local g = love and love.graphics
  if not (g and type(g.newImage) == "function") then
    quads = false
    return nil
  end
  local loaded = {}
  for _, key in ipairs({ "healthy", "fainted", "empty" }) do
    local ok, img = pcall(g.newImage, BALL_ASSETS[key])
    if not (ok and img and type(img.getDimensions) == "function") then
      quads = false
      return nil
    end
    local w, h = img:getDimensions()
    if not (w and h and w > 0 and h > 0) then
      quads = false
      return nil
    end
    if type(img.setFilter) == "function" then
      pcall(img.setFilter, img, "nearest", "nearest")
    end
    loaded[key] = { image=img, sx=8 / w, sy=8 / h }
  end
  quads = loaded
  return quads
end

local function validParty(party)
  if type(party) ~= "table" then return false end
  for i = 1, 6 do
    local mon = party[i]
    if mon ~= nil and (type(mon) ~= "table" or type(mon.hp) ~= "number") then
      return false
    end
  end
  return true
end

-- Compact persistent receipts occupy the unused half of each 48px HUD band.
-- They remain separate from Gen-I's larger intro/faint rows, which continue
-- to appear at their original moments and positions.
BattlePartyBalls.PERSISTENT_RECT = {
  -- Enemy row sits immediately below the upper-left status block. Player row
  -- sits immediately above the lower-right block. Both therefore travel with
  -- their own HUD band when it snaps to a phone/window edge instead of
  -- floating over the centre of the fight.
  enemy = { 8, 34, 48, 10 },
  player = { 104, 48, 48, 10 },
}

function BattlePartyBalls.persistentLive(battle, side)
  if not battle or battle.introBalls then return false end
  if side == "enemy" then
    return battle.enemyParty ~= nil and not battle.showEnemyBalls
  end
  return (battle.playerParty ~= nil
          or battle.game and battle.game.save and battle.game.save.party ~= nil)
         and not (battle.safari or battle.demo or battle.showPlayerBack)
end

local function drawColoredRow(party, x, y, dx)
  local q, g = atlas(), love and love.graphics
  if not (q and g and type(g.draw) == "function"
          and type(g.setColor) == "function"
          and type(g.rectangle) == "function"
          and validParty(party) and type(x) == "number"
          and type(y) == "number" and type(dx) == "number") then
    return false
  end
  local canPush = type(g.push) == "function" and type(g.pop) == "function"
  if canPush then g.push("all") end
  for i = 1, 6 do
    local mon, px = party[i], x + (i - 1) * dx
    local key = not mon and "empty" or mon.hp > 0 and "healthy" or "fainted"
    local icon = q[key]
    g.setColor(1, 1, 1, 1)
    g.draw(icon.image, px, y, 0, icon.sx, icon.sy)
    if not mon then
      -- The packaged empty icon already owns its neutral colour.
    elseif mon.hp <= 0 then
      g.setColor(0.18, 0.18, 0.18, 1)
      for d = 1, 6 do g.rectangle("fill", px + d, y + 7 - d, 1, 1) end
    end
  end
  if canPush then g.pop() else g.setColor(1, 1, 1, 1) end
  return true
end

-- Reuse VASC's packaged ORAS party-ball artwork at the native 8px footprint.
-- The shader-free outer layer stops KASC's zone palette turning the reviewed
-- red/grey art orange or purple; fainted slots retain the compact diagonal.
local function drawPersistentRow(party, x, y, dx)
  local g = love and love.graphics
  if not g then return false end
  local canPush = type(g.push) == "function" and type(g.pop) == "function"
  if canPush then g.push("all") end
  if type(g.setShader) == "function" then g.setShader() end
  local drawn = drawColoredRow(party, x, y, dx)
  if canPush then g.pop() end
  return drawn
end

function BattlePartyBalls.drawPersistentSide(battle, side)
  if not BattlePartyBalls.persistentLive(battle, side) then return false end
  local rect = BattlePartyBalls.PERSISTENT_RECT[side]
  if not rect then return false end
  local party = side == "enemy" and battle.enemyParty
                or battle.playerParty or battle.game.save.party
  return drawPersistentRow(party, rect[1], rect[2], 8)
end

function BattlePartyBalls.drawPersistent(battle)
  local enemy = BattlePartyBalls.drawPersistentSide(battle, "enemy")
  local player = BattlePartyBalls.drawPersistentSide(battle, "player")
  return enemy or player
end

local overlayInstalled = false
local function installOverlay()
  if overlayInstalled then return true end
  local mod = V and V.mod
  local hooks = mod and mod.hooks
  if not (type(hooks) == "table" and type(hooks.wrap) == "function") then
    return false
  end
  hooks:wrap("battle.overlay", function(nextOverlay, battle)
    local results = packValues(nextOverlay(battle))
    -- In edge mode this exact row was already painted into VASC's unfiltered
    -- window-resolution HUD texture.  FRAME mode and ordinary 2D battles need
    -- it here, after the SGB/KASC zone pass, so the status colours cannot
    -- recolour it and no second row appears at the old GB coordinates.
    if battle and not battle.blankForAskName
        and not battle.voxelAscendantHudSnapped and not kascOwnsHud() then
      BattlePartyBalls.drawPersistent(battle)
    end
    return unpackValues(results, 1, results.n)
  end, 100)
  overlayInstalled = true
  return true
end

function BattlePartyBalls.install()
  installOverlay()
  local BattleState = require("src.battle.BattleState")
  local current = BattleState and BattleState.drawBallRow
  if type(current) ~= "function" then return false end
  local held = rawget(BattleState, "voxelAscendantPartyBallHook")
  if held then return current == held.wrapper end

  local original = current
  local function wrapper(self, party, x, y, dx)
    if kascOwnsHud() then
      return original(self, party, x, y, dx)
    end
    if not drawColoredRow(party, x, y, dx) then
      return original(self, party, x, y, dx)
    end
  end
  BattleState.drawBallRow = wrapper
  BattleState.voxelAscendantPartyBallHook = {
    original = original, wrapper = wrapper,
  }
  return true
end

return BattlePartyBalls
