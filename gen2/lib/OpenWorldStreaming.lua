-- Camera-aware residency radius for Gen-2's optional OPEN WORLD renderer.
--
-- The old path eventually admitted every cardinally connected outdoor map,
-- even while a first-/third-person camera could only see the current route.
-- This policy keeps the same seamless direct ring and expands only when the
-- player actually pulls the diorama camera back.  It is intentionally pure
-- apart from reading the current DioramaZoom value, which makes the thresholds
-- deterministic and easy to regression-test.

local V = ...
local Streaming = {}

Streaming.MAX_DEPTH = 4
Streaming.THRESHOLDS = {
  { zoom = 1.60, depth = 1 },
  { zoom = 3.00, depth = 2 },
  { zoom = 6.00, depth = 3 },
}

local function normalizeMode(value)
  value = tostring(value or "full"):lower()
  if value == "diorama" then return "full" end
  if value == "first_person" or value == "1st" then return "first" end
  if value == "third_person" or value == "3rd" then return "third" end
  return value
end

local function currentZoom()
  if not (V and type(V.require) == "function") then return 1 end
  local ok, zoom = pcall(V.require, "DioramaZoom")
  if not (ok and type(zoom) == "table" and type(zoom.get) == "function") then
    return 1
  end
  local called, value = pcall(zoom.get)
  value = called and tonumber(value) or nil
  return value and math.max(0.01, value) or 1
end

function Streaming.depth(openWorld, cameraMode, zoom)
  if openWorld ~= true then return 1, "stream" end

  local mode = normalizeMode(cameraMode)
  -- Placed cameras see only the current map and its seam handoff ring. Orbit
  -- angle presets likewise have no independent long-distance zoom control.
  if mode ~= "full" then return 1, mode end

  zoom = tonumber(zoom) or currentZoom()
  for _, threshold in ipairs(Streaming.THRESHOLDS) do
    if zoom <= threshold.zoom then
      return threshold.depth, "diorama"
    end
  end
  return Streaming.MAX_DEPTH, "diorama"
end

function Streaming.status(openWorld, cameraMode, zoom)
  local depth, owner = Streaming.depth(openWorld, cameraMode, zoom)
  return {
    openWorld = openWorld == true,
    camera = normalizeMode(cameraMode),
    zoom = tonumber(zoom) or currentZoom(),
    depth = depth,
    owner = owner,
    maxDepth = Streaming.MAX_DEPTH,
  }
end

return Streaming
