-- Gen-2-owned copy of the optional 3D Pokemon-model source contract.
-- Gameplay ownership remains independent from Kanto; keep this implementation
-- in sync deliberately, never by loading the Gen-1 module at runtime.

local V = ...
local ModSetting = V.require("ModSetting")

local M = {
  API_VERSION = 1,
  CONTRACT = "vasc-pokemon-model-provider/v1",
  AUTO = "auto",
  CRYSTAL = "crystal",
  STADIUM1 = "stadium1",
  STADIUM2 = "stadium2",
}

M.setting = ModSetting.new(
  "pokemonModelSkin", "POKéMON MODEL",
  { M.AUTO, M.CRYSTAL, M.STADIUM1, M.STADIUM2 },
  { "AUTO", "CRYSTAL", "STADIUM 1", "STADIUM 2" }, M.AUTO)

local function generation()
  local host = V.mod and V.mod._vascHostGeneration
  return tonumber(host) or 2
end

local function stagedMode()
  local ok, battle = pcall(V.require, "OverworldBattle")
  if not ok or type(battle) ~= "table" then return nil end
  local mode
  if type(battle.mode) == "function" then
    local called, value = pcall(battle.mode)
    if called then mode = value end
  elseif battle.setting and type(battle.setting.get) == "function" then
    local called, value = pcall(battle.setting.get, battle.setting)
    if called then mode = value end
  end
  if mode == nil or mode == false or mode == 0 or mode == battle.DEFAULT then
    return nil
  end
  if mode == battle.MAP or mode == true then return "MAP" end
  if mode == battle.ARENA or mode == "arena" or mode == "stadium" then
    return "ARENA"
  end
  if mode == battle.DISCS or mode == "discs" or mode == "flatB"
      or mode == "stadiumB" then
    return "DISCS"
  end
  return nil
end

local function externalReceipt()
  local mod = V.mod
  if not (mod and type(mod.find) == "function") then return nil end
  local ok, provider = pcall(mod.find, mod, "STADIUM_OVERWORLD_MODELS")
  if not ok or type(provider) ~= "table" then
    ok, provider = pcall(mod.find, "STADIUM_OVERWORLD_MODELS")
  end
  local exports = ok and provider and provider.exports or nil
  if type(exports) ~= "table" then return nil end
  local receipt = exports.vascPokemonModelProvider
  if type(receipt) ~= "table" or receipt.contract ~= M.CONTRACT then return nil end
  return receipt
end

local function externalReady(source, mode)
  local receipt = externalReceipt()
  if not receipt then return false end
  if type(receipt.supports) == "function" then
    local ok, yes = pcall(receipt.supports, source, mode, generation())
    return ok and yes == true
  end
  local sources = receipt.sources
  return type(sources) == "table" and sources[source] == true
end

local function builtInStadium2Ready()
  local ok, install = pcall(V.require, "StadiumInstall")
  if not ok or type(install) ~= "table" or type(install.available) ~= "function" then
    return false
  end
  local called, ready = pcall(install.available)
  return called and ready == true
end

function M.requested() return M.setting:get() end
function M.mode() return stagedMode() end

function M.resolve(requested)
  local mode = stagedMode()
  if not mode then return M.CRYSTAL, "battle-mode-off" end
  requested = requested or M.setting:get()
  if requested == M.CRYSTAL then return M.CRYSTAL, "selected" end
  if requested == M.STADIUM1 then
    if externalReady(M.STADIUM1, mode) then return M.STADIUM1, "provider" end
    return M.CRYSTAL, "stadium1-unavailable"
  end
  if requested == M.STADIUM2 then
    if builtInStadium2Ready() then return M.STADIUM2, "built-in" end
    if externalReady(M.STADIUM2, mode) then return M.STADIUM2, "provider" end
    return M.CRYSTAL, "stadium2-unavailable"
  end
  if builtInStadium2Ready() then return M.STADIUM2, "auto-built-in" end
  if externalReady(M.STADIUM1, mode) then return M.STADIUM1, "auto-provider" end
  if externalReady(M.STADIUM2, mode) then return M.STADIUM2, "auto-provider" end
  return M.CRYSTAL, "auto-fallback"
end

function M.modelsEnabled()
  local source = M.resolve()
  return source ~= M.CRYSTAL
end

-- The embedded renderer may claim only packs built by this package. External
-- provider receipts retain ownership of their own pixels and lifecycle.
function M.builtInModelsEnabled()
  local source, reason = M.resolve()
  return source == M.STADIUM2
    and (reason == "built-in" or reason == "auto-built-in")
end

function M.status()
  local active, reason = M.resolve()
  local catalogLimit
  local okInstall, install = pcall(V.require, "StadiumInstall")
  if okInstall and type(install) == "table"
      and type(install.targetCount) == "function" then
    local okCount, count = pcall(install.targetCount)
    if okCount then catalogLimit = tonumber(count) end
  end
  return {
    apiVersion=M.API_VERSION, contract=M.CONTRACT,
    requested=M.setting:get(), active=active, reason=reason,
    battleMode=stagedMode() or "OFF", generation=generation(),
    catalogLimit=catalogLimit,
    stadium1Provider=externalReady(M.STADIUM1, stagedMode() or "OFF"),
    stadium2Provider=builtInStadium2Ready()
      or externalReady(M.STADIUM2, stagedMode() or "OFF"),
  }
end

function M.public()
  return {
    apiVersion=M.API_VERSION, contract=M.CONTRACT,
    choices={M.CRYSTAL, M.STADIUM1, M.STADIUM2},
    requested=M.requested, resolve=M.resolve,
    builtInModelsEnabled=M.builtInModelsEnabled, status=M.status,
    allows=function(source, mode)
      if mode ~= "MAP" and mode ~= "ARENA" and mode ~= "DISCS" then return false end
      if source == M.STADIUM1 then return externalReady(source, mode) end
      if source == M.STADIUM2 then
        return builtInStadium2Ready() or externalReady(source, mode)
      end
      return source == M.CRYSTAL
    end,
  }
end

return M
