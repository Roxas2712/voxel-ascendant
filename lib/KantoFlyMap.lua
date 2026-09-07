-- Internal owner bridge for the formerly standalone Kanto Fly Map.
--
-- The reviewed feature is receipt-pinned below integrated/kanto_fly_map so its
-- presentation and native fail-open rules can be tested independently. This
-- bridge gives it VASC's public services while
-- keeping its legacy exports in a child receipt: the embedded feature must not
-- replace VASC's package version, capabilities or renderer receipt.

local V = ...
local KantoFlyMap = {}
local ModSetting = V.require("ModSetting")

KantoFlyMap.setting = ModSetting.new(
  "kantoMapStyle", "KANTO MAP",
  { "cartridge", "widescreen" },
  { "CARTRIDGE MAP", "VASC WIDESCREEN" },
  "widescreen")
KantoFlyMap.setting:aliasLegacy("game", "cartridge")
KantoFlyMap.setting:aliasLegacy("default", "cartridge")
KantoFlyMap.setting:aliasLegacy("custom", "widescreen")
KantoFlyMap.setting:aliasLegacy("classic", "widescreen")
KantoFlyMap.setting:aliasLegacy("wide", "widescreen")

function KantoFlyMap.mode()
  return KantoFlyMap.setting:get() == "widescreen"
    and "widescreen" or "cartridge"
end

local function compileFeature(rel)
  local source, readErr = V.mod:read(rel)
  if not source then
    return nil, ("missing %s: %s"):format(rel, tostring(readErr or "unavailable"))
  end
  local chunk, compileErr = (loadstring or load)(source,
    "@" .. tostring(V.mod.path or "VOXEL_ASCENDANT") .. "/" .. rel)
  if not chunk then return nil, tostring(compileErr) end
  local ok, installer = pcall(chunk)
  if not ok then return nil, tostring(installer) end
  if type(installer) ~= "function" then
    return nil, rel .. " did not return an installer"
  end
  return installer
end

local function findThrough(root, id)
  if id == "VOXEL_ASCENDANT" then return root end
  local finder = root and root.find
  if type(finder) ~= "function" then return nil end
  local ok, found = pcall(finder, id)
  if ok and found ~= nil then return found end
  ok, found = pcall(finder, root, id)
  if ok then return found end
  return nil
end

local function featureFor(root, receipt)
  local feature = setmetatable({
    id = "VOXEL_ASCENDANT",
    path = root.path,
    exports = receipt,
  }, { __index = root })
  feature.find = function(first, second)
    local id = first == feature and second or first
    return findThrough(root, id)
  end
  return feature
end

function KantoFlyMap.install()
  local root = V.mod
  root.exports = root.exports or {}
  if type(root.exports.kantoFlyMap) == "table"
      and root.exports.kantoFlyMap.active == true then
    return true, root.exports.kantoFlyMap
  end

  local fallbackInstaller, fallbackLoadErr = compileFeature(
    "integrated/kanto_fly_map/main.lua")
  if not fallbackInstaller then return false, fallbackLoadErr end
  local fallbackReceipt = {}
  local fallbackFeature = featureFor(root, fallbackReceipt)
  fallbackFeature.kantoFlyMapFallbackOnly = true
  local fallbackOk, fallbackInstallErr = pcall(
    fallbackInstaller, fallbackFeature)
  if not fallbackOk or fallbackReceipt.active ~= true
      or fallbackReceipt.apiVersion ~= 1
      or type(fallbackReceipt.newFallback) ~= "function" then
    return false, tostring(fallbackInstallErr
      or "embedded compact Kanto map fallback is incomplete")
  end

  local installer, loadErr = compileFeature(
    "integrated/kanto_fly_map/widescreen.lua")
  if not installer then return false, loadErr end

  local receipt = {}
  local feature = featureFor(root, receipt)
  feature.kantoFlyMapMode = KantoFlyMap.mode
  feature.kantoFlyMapFallbackFactory = fallbackReceipt.newFallback

  local ok, installErr = pcall(installer, feature)
  if not ok then return false, tostring(installErr) end
  if receipt.active ~= true or receipt.apiVersion ~= 1 then
    return false, "embedded Kanto Fly Map did not publish its active v1 receipt"
  end

  receipt.owner = "VOXEL_ASCENDANT"
  receipt.bundled = true
  receipt.sourceVersion = "1.0.0"
  receipt.sourceArchiveSha256 =
    "e08b41897b68fa59588059f2caab6ab0c55a91fe3f98bfae43d1a1bd513a2744"
  receipt.fallbackSourceVersion = "1.6.3"
  receipt.fallbackInternalOnly = true
  receipt.mode = KantoFlyMap.mode
  root.exports.kantoFlyMap = receipt
  return true, receipt
end

return KantoFlyMap
