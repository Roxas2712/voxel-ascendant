local cache = {}

local V = {}
function V.require(name)
  if cache[name] then return cache[name] end
  if name == "Voxel3D" then
    cache[name] = { available = function() return true end, camera = nil }
  elseif name == "WorldCurve" then
    cache[name] = { k = function() return 0 end }
  elseif name == "Mat4" then
    cache[name] = {}
  elseif name == "VoxelScene" then
    cache[name] = {
      groundAt = function(map, cx, cy)
        return map.groundAt and map:groundAt(cx, cy) or 0
      end,
    }
  elseif name == "TileShape" then
    cache[name] = {
      forMap = function(map) return map.shapes end,
    }
  else
    cache[name] = assert(loadfile("lib/" .. name .. ".lua"))(V)
  end
  return cache[name]
end

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected "
          .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local Voxel = V.require("VoxelState")
local ThirdPerson = V.require("ThirdPerson")
local FirstPerson = V.require("FirstPerson")

eq(Voxel.levelLabel(Voxel.FP_LEVEL), "1ST", "first-person rung is exposed")
eq(Voxel.levelLabel(Voxel.TP_LEVEL), "3RD", "third-person rung is exposed")
eq(Voxel.nextHotkeyLevel(5), Voxel.FP_LEVEL,
   "hotkey reaches first person after the 75-degree orbit")
eq(Voxel.nextHotkeyLevel(Voxel.FP_LEVEL), Voxel.TP_LEVEL,
   "hotkey walks from first to third person")
eq(Voxel.nextHotkeyLevel(Voxel.TP_LEVEL), 0,
   "hotkey can leave third person without opening options")

Voxel.setLevel(Voxel.FP_LEVEL)
eq(Voxel.isFirstPerson(), true, "first-person level is recognized")
eq(Voxel.isFreeCam(), true, "first-person level owns the player camera")
eq(FirstPerson.engaged(), true, "first-person camera engages when available")

Voxel.setLevel(Voxel.TP_LEVEL)
eq(Voxel.isThirdPerson(), true, "third-person level is recognized")
eq(ThirdPerson.selected(), true, "third-person boom selects independently")

ThirdPerson.zoomGoal = 1
eq(ThirdPerson.stepZoom(1), true, "third-person boom zooms independently")
if ThirdPerson.zoomGoal <= 1 then error("third-person zoom did not move out") end

-- Reproduce the real Route 4 -> Route 3 seam in Route-3-local coordinates:
-- landed pivot (1000,17,8), old Route 4 translated by (800,-288), and its
-- lip at local cell (12,17). The lip is unwalkable because the engine enters
-- it through checkLedgeHop, but it is only six pixels tall. Treating every
-- unwalkable cell as a 20px wall collapsed the boom to ~3px and parked the
-- eye behind the very brown face it was trying to avoid.
local function mapOf(id, width, height, class)
  local map = {
    id = id,
    widthCells = width,
    heightCells = height,
    shapes = {
      [1] = { class = class or "ground", h = class == "ledge" and 6 or 16 },
      [2] = { class = "ground", h = 0 },
    },
  }
  function map:inBounds(x, y)
    return x >= 0 and y >= 0 and x < self.widthCells
           and y < self.heightCells
  end
  function map:isLip(cx, cy)
    return self.id ~= "ROUTE_3" and cx == 12 and cy == 17
  end
  function map:groundAt(cx, cy) return self:isLip(cx, cy) and 6 or 0 end
  function map:isWalkableCell(cx, cy) return not self:isLip(cx, cy) end
  function map:cellTile(cx, cy) return self:isLip(cx, cy) and 1 or 2 end
  return map
end

local route3 = mapOf("ROUTE_3", 70, 18, "ground")
local ledgeRoute4 = mapOf("ROUTE_4", 82, 18, "ledge")
local wallRoute4 = mapOf("ROUTE_4_WALL_TWIN", 82, 18, "wall")
local function seamWith(oldMap)
  return { map = route3,
           neighbors = { { map = oldMap, ox = 800, oy = -288 } } }
end

local s, c = math.sin(math.rad(10)), math.cos(math.rad(10))
local pivot = { 1000, 17, 8 }
local ledgeRoom = ThirdPerson.reach(seamWith(ledgeRoute4), pivot,
                                    0, s, -c, 48)
eq(ledgeRoom, 48, "real Route 4 lip keeps the full third-person boom")
eq(ThirdPerson._collisionClass(ledgeRoute4, 12, 17), "ledge",
   "ledge exemption follows the collision-cell shape")

-- Same transform, height and unwalkability, but genuine wall semantics:
-- this must still pull the eye in rather than seeing through the structure.
local wallRoom = ThirdPerson.reach(seamWith(wallRoute4), pivot,
                                   0, s, -c, 48)
if wallRoom >= ThirdPerson.SHOW_AT then
  error("wall twin failed to shorten boom: room=" .. tostring(wallRoom))
end

-- A merely non-zero boom is not enough to reveal the player's card while a
-- gatehouse is still squeezing the camera. The requested threshold is strict
-- at 67% of the current zoomed reach: 0.66 remains hidden, 0.68 is visible.
ThirdPerson.out = 1
ThirdPerson.zoom = 1
ThirdPerson.len = ThirdPerson.reachFor() * 0.66
eq(ThirdPerson.showsPlayer(), false,
   "third-person player leaked into a 0.66-reach gatehouse camera")
ThirdPerson.len = ThirdPerson.reachFor() * 0.68
eq(ThirdPerson.showsPlayer(), true,
   "third-person player stayed hidden after 0.68 of the boom survived")
if ThirdPerson.signature() == "" then
  error("third-person player gate accidentally removed the shadow signature")
end

Voxel.setLevel(0)
eq(Voxel.isFreeCam(), false, "orbit/off levels release the player camera")

print("camera modes: ok")
