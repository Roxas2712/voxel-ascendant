-- Make the six party receipts immediately readable: usable Pokemon are red;
-- fainted Pokemon are grey and struck through. Empty slots stay neutral.

local V = ...
local BattlePartyBalls = {}

local quads
local function atlas()
  if quads ~= nil then return quads or nil end
  local g = love and love.graphics
  if not (g and type(g.newImage) == "function"
          and type(g.newQuad) == "function") then
    quads = false
    return nil
  end
  local ok, img = pcall(g.newImage, "assets/generated/battle/balls.png")
  if not (ok and img and type(img.getDimensions) == "function") then
    quads = false
    return nil
  end
  local w, h = img:getDimensions()
  if w < 32 or h < 8 then quads = false return nil end
  quads = { img = img }
  for i = 0, 3 do quads[i] = g.newQuad(i * 8, 0, 8, 8, w, h) end
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

function BattlePartyBalls.install()
  local BattleState = require("src.battle.BattleState")
  local current = BattleState and BattleState.drawBallRow
  if type(current) ~= "function" then return false end
  local held = rawget(BattleState, "voxelAscendantPartyBallHook")
  if held then return current == held.wrapper end

  local original = current
  local function wrapper(self, party, x, y, dx)
    local q, g = atlas(), love and love.graphics
    if not (q and g and type(g.draw) == "function"
            and type(g.setColor) == "function"
            and type(g.rectangle) == "function"
            and validParty(party) and type(x) == "number"
            and type(y) == "number" and type(dx) == "number") then
      return original(self, party, x, y, dx)
    end
    local canPush = type(g.push) == "function" and type(g.pop) == "function"
    if canPush then g.push("all") end
    for i = 1, 6 do
      local mon, px = party[i], x + (i - 1) * dx
      if not mon then
        g.setColor(1, 1, 1, 1)
        g.draw(q.img, q[3], px, y)
      elseif mon.hp > 0 then
        g.setColor(1, 0.28, 0.28, 1)
        g.draw(q.img, q[0], px, y)
      else
        g.setColor(0.52, 0.52, 0.52, 1)
        g.draw(q.img, q[2], px, y)
        g.setColor(0.18, 0.18, 0.18, 1)
        for d = 1, 6 do g.rectangle("fill", px + d, y + 7 - d, 1, 1) end
      end
    end
    if canPush then g.pop() else g.setColor(1, 1, 1, 1) end
  end
  BattleState.drawBallRow = wrapper
  BattleState.voxelAscendantPartyBallHook = {
    original = original, wrapper = wrapper,
  }
  return true
end

return BattlePartyBalls
