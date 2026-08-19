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

Voxel.setLevel(0)
eq(Voxel.isFreeCam(), false, "orbit/off levels release the player camera")

print("camera modes: ok")
