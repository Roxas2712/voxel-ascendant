-- Read-only hardware hints shared by both generation facades. Never infer a
-- handheld from resolution, CPU thread count, Linux, or a generic AMD GPU.
local M = {}
function M.classify(osName, device)
  local name = tostring(device or ""):lower()
  local desktop = osName == "Linux" or osName == "Windows"
  local deck = desktop and (name:find("vangogh", 1, true)
    or name:find("van gogh", 1, true)
    or name:match("amd custom gpu 0405%f[%W]")
    or name:match("amd custom gpu 0932%f[%W]")) ~= nil
  return {steamDeck=deck, os=osName, renderer=device,
    kind=deck and "steam-deck" or "default"}
end
function M.detect(api)
  local osName, device = "unknown", "unknown"
  if api and api.system and type(api.system.getOS)=="function" then
    local ok, value = pcall(api.system.getOS)
    if ok then osName=value end
  end
  if api and api.graphics and type(api.graphics.getRendererInfo)=="function" then
    local ok, _, _, _, value = pcall(api.graphics.getRendererInfo)
    if ok then device=value end
  end
  return M.classify(osName, device)
end
-- Correct only AUTO discovery in the shared host. Explicit HIGH/BALANCED/LOW
-- values still resolve through the host unchanged; no saved option is written.
function M.installAutoProfile(performance, hardware)
  if not (hardware and hardware.steamDeck and type(performance)=="table"
    and type(performance.detect)=="function") then return false end
  performance.detect = function() return "balanced" end
  return true
end
return M
