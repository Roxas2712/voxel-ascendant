-- VASC Gen-2 world-map bridge.
--
-- Gold/Silver/Crystal keep ownership of every destination, visited flag and
-- warp.  VASC only removes the original one-region-at-a-time presentation
-- limit after Kanto has legitimately been unlocked: the Fly screen may then
-- list all already visited Johto and Kanto destinations in one atlas.

local C = ... or {}
local mod = C.mod

local M = {
  installed = false,
  combinedCalls = 0,
  lastError = nil,
}

local function enabled()
  local options = mod and mod.options
  if not (options and type(options.get) == "function") then return true end
  local ok, value = pcall(options.get, options, "gen2WorldMap")
  if not ok or value == nil then return true end
  return value ~= false
end

local function landmarkEntry(landmarks, id)
  local rows = landmarks and landmarks.landmarks
  return rows and rows[id] or nil
end

local function hallOfFame(save)
  local flags = type(save) == "table" and save.flags or nil
  return type(flags) == "table" and flags.HALL_OF_FAME == true
end

local function combinedFlyPoints(FieldMoves, save, landmarks)
  -- Indigo is a Johto fly destination and can be visited before the player
  -- learns that Kanto is playable. Visiting it must not reveal Kanto. Match
  -- the visible atlas and unlock the combined list only after the Hall of Fame.
  if not hallOfFame(save) then return nil end

  local out = {}
  local split = tonumber(FieldMoves.KANTO_FLYPOINT) or 13
  for index, row in ipairs(FieldMoves.FLYPOINTS or {}) do
    if FieldMoves.hasVisitedSpawn(save, row.spawn) then
      local entry = landmarkEntry(landmarks, row.landmark)
      out[#out + 1] = {
        landmark = row.landmark,
        spawn = row.spawn,
        index = entry and entry.index or nil,
        name = entry and entry.name or row.landmark,
        region = index < split and "johto" or "kanto",
        vascWorldMap = true,
      }
    end
  end
  return out
end

function M.install()
  if M.installed then return true end
  local ok, FieldMoves = pcall(require, "src.world.gen2.FieldMoves")
  if not ok or type(FieldMoves) ~= "table"
      or type(FieldMoves.flyPoints) ~= "function" then
    M.lastError = "Gen-2 FieldMoves.flyPoints unavailable"
    return false, M.lastError
  end

  local held = rawget(FieldMoves, "voxelAscendantWorldMap")
  if held then
    held.enabled = enabled
    M.installed = true
    return true
  end

  held = { original = FieldMoves.flyPoints, enabled = enabled }
  held.wrapper = function(save, landmarks, region)
    local native = held.original(save, landmarks, region)
    if not held.enabled() then return native end
    local combined = combinedFlyPoints(FieldMoves, save, landmarks)
    if not combined or #combined == 0 then return native end
    M.combinedCalls = M.combinedCalls + 1
    return combined
  end
  FieldMoves.flyPoints = held.wrapper
  FieldMoves.voxelAscendantWorldMap = held
  M.installed = true
  return true
end

return M
