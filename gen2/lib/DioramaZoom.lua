-- Continuous camera-distance zoom for the voxel diorama camera.
local V = ...
local DioramaZoom = {}

DioramaZoom.MIN = 0.24
DioramaZoom.DEFAULT_MAX = 2.20
DioramaZoom.STEP = 1.14
DioramaZoom.value = 1.0

local LIMITS = {
  standard = 2.20,
  far = 4.00,
  world = 8.00,
  extreme = 12.00,
}

local function optionMax()
  local mod = V and V.mod
  local options = mod and mod.options
  if options and type(options.get) == "function" then
    local ok, value = pcall(options.get, options, "worldZoomRange")
    value = ok and tostring(value or "world"):lower() or "world"
    if LIMITS[value] then return LIMITS[value], value end
  end
  -- v0.2.76 makes WORLD the new available range without changing the startup
  -- distance: value still begins at 1.0 and only moves when the player zooms.
  return LIMITS.world, "world"
end

function DioramaZoom.max()
  local value = optionMax()
  return value
end

function DioramaZoom.mode()
  local _, mode = optionMax()
  return mode
end

local function clamp(v)
  local maxValue = DioramaZoom.max()
  return math.max(DioramaZoom.MIN, math.min(maxValue, tonumber(v) or 1))
end

function DioramaZoom.get()
  DioramaZoom.value = clamp(DioramaZoom.value)
  return DioramaZoom.value
end

function DioramaZoom.set(v)
  DioramaZoom.value = clamp(v)
  return DioramaZoom.value
end

-- Positive notches pull the camera out; negative notches push in.
function DioramaZoom.step(notches)
  notches = tonumber(notches) or 0
  if notches == 0 then return false end
  DioramaZoom.set(DioramaZoom.get() * (DioramaZoom.STEP ^ notches))
  return true
end

-- Multiplicative distance change. Values below 1 zoom in.
function DioramaZoom.scaleBy(factor)
  factor = tonumber(factor)
  if not factor or factor <= 0 then return false end
  DioramaZoom.set(DioramaZoom.get() * factor)
  return true
end

function DioramaZoom.reset()
  DioramaZoom.value = 1.0
end

DioramaZoom.LIMITS = LIMITS
DioramaZoom.MAX = LIMITS.world -- compatibility field; max() is authoritative

return DioramaZoom
