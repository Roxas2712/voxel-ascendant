local function eq(a, b, message)
  if a ~= b then error((message or "mismatch") .. ": "
    .. tostring(a) .. " ~= " .. tostring(b), 2) end
end

local draws, pixels, colors = {}, {}, {}
local image = { getDimensions = function() return 32, 8 end }
_G.love = { graphics = {
  newImage = function(path)
    eq(path, "assets/generated/battle/balls.png", "wrong atlas")
    return image
  end,
  newQuad = function(x) return x / 8 end,
  draw = function(_, quad, x, y) draws[#draws + 1] = { quad, x, y } end,
  setColor = function(r, g, b, a) colors[#colors + 1] = { r, g, b, a } end,
  rectangle = function(mode, x, y, w, h)
    pixels[#pixels + 1] = { mode, x, y, w, h }
  end,
  push = function() end, pop = function() end,
} }

local fallback = 0
local BattleState = { drawBallRow = function() fallback = fallback + 1 end }
package.loaded["src.battle.BattleState"] = BattleState
local module = assert(loadfile("lib/BattlePartyBalls.lua"))({})
eq(module.install(), true, "install")
local wrapper = BattleState.drawBallRow
eq(module.install(), true, "idempotent install")
eq(BattleState.drawBallRow, wrapper, "wrapper stacked")

BattleState:drawBallRow({ { hp = 10 }, { hp = 0 }, nil,
  { hp = 1 }, { hp = -1 }, nil }, 10, 20, 8)
eq(#draws, 6, "party receipt count")
eq(draws[1][1], 0, "healthy ball tile")
eq(draws[2][1], 2, "fainted ball tile")
eq(draws[3][1], 3, "empty ball tile")
eq(#pixels, 12, "two fainted strike-throughs")
eq(colors[1][1], 1, "healthy red channel")
eq(colors[1][2], 0.28, "healthy ball is not red")

BattleState:drawBallRow({ { hp = "bad" } }, 0, 0, 8)
eq(fallback, 1, "malformed party did not fail open")

print("battle party balls: ok")
