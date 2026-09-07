-- Fail-closed Card registry for the non-overlapping Gen-2 change surfaces.

local V = ...
local Registry = V.require("core/AscendantCardRegistry")
local CardSet = V.require("cards/gen2/Gen2SegmentCards")

local M = { installed=false, registry=nil, cards=nil, lastError=nil }

local function joinErrors(report)
  local errors = {}
  for _, row in ipairs(report and report.errors or {}) do
    errors[#errors + 1] = tostring(row.id) .. ": " .. tostring(row.error)
  end
  if #errors == 0 then return nil end
  return table.concat(errors, "; ")
end

function M.install(options)
  if M.installed then return M.lastError == nil, M.lastError end
  options = type(options) == "table" and options or {}
  local cards = CardSet.descriptors()
  local claimedFiles = {}
  for _, card in ipairs(cards) do
    for _, path in ipairs(card.impact.files or {}) do
      if claimedFiles[path] then
        M.lastError = ("file ownership overlap: %s (%s and %s)")
          :format(path, claimedFiles[path], card.id)
        M.installed = true
        return false, M.lastError
      end
      claimedFiles[path] = card.id
    end
  end

  local registry = Registry.new()
  for _, card in ipairs(cards) do
    local ok, err = registry:register(card)
    if ok ~= true then
      M.lastError = tostring(err)
      M.installed = true
      return false, M.lastError
    end
  end
  local runtime = { mod=options.mod or V.mod, generation=2 }
  local installReport = registry:installAll(runtime)
  local installError = joinErrors(installReport)
  if installError then
    M.lastError = installError
    M.installed = true
    return false, installError
  end
  local activeReport = registry:activateAll(runtime)
  local activeError = joinErrors(activeReport)
  if activeError then
    registry:deactivateAll(runtime, "Gen2-segment-activation-failed")
    M.lastError = activeError
    M.installed = true
    return false, activeError
  end
  M.registry, M.cards, M.installed = registry, cards, true
  return true
end

function M.public()
  local result = {
    schema="voxel-ascendant/gen2-segment-cards/v1",
    generation=2,
    ok=M.installed == true and M.lastError == nil,
    error=M.lastError,
    cards={},
  }
  for _, card in ipairs(M.cards or {}) do
    result.cards[#result.cards + 1] = {
      id=card.id,
      capability=card.provides[1],
      runtimeOwner=card.impact.runtimeOwners[1],
      files=card.impact.files,
    }
  end
  return result
end

return M
