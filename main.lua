-- Voxel Ascendant 3.0 runtime dispatcher.
--
-- Gen 1 executes the reviewed VASC 3.0 runtime. Gen 2 receives a facade whose
-- private Lua/data reads are rooted below gen2/. Shared assets and user data
-- intentionally remain at package root.

local mod = ...

-- Both generations share the same bounded in-memory support evidence.
do
  local ok, recorder = pcall(function()
    local source = assert(mod:read("lib/RuntimePerformanceDiagnostics.lua"))
    return assert((loadstring or load)(source, "@RuntimePerformanceDiagnostics"))(mod)
  end)
  if ok then mod._vascRuntimeDiagnostics = recorder end
end

-- RC12 mobile trace bootstrap for the converged M10/M11 segment. It stores
-- renderer checkpoints in RAM until Diagnostics has booted and does not itself
-- install a render hook, query graphics state or write files directly.
local MobileDiagnostic = nil
do
  local okRead, source = pcall(function()
    return mod:read("lib/MobileVoxelDiagnostic.lua")
  end)
  if okRead and type(source) == "string" then
    local chunk = (loadstring or load)(source,
      "@" .. tostring(mod.path or "VOXEL_ASCENDANT")
        .. "/lib/MobileVoxelDiagnostic.lua")
    if chunk then
      local okLoad, value = pcall(chunk, mod)
      if okLoad and type(value) == "table" then
        MobileDiagnostic = value
        mod._vascMobileDiagnostic = value
        pcall(value.checkpoint, "mod-entry-loaded", {
          build="VASC-RC12-M10-M11-CONVERGED-20260903",
          physicalStatus="RC12_REQUIRES_PHYSICAL_SMARTPHONE_PASS",
          sourceZipSha256=
            "66021fb9a6512d3192692b14d3f8af965f8c52d8ed4b20163b1da8228be07618",
        })
      end
    end
  end
end
-- The loader obtains this value from manifest.json. Keep it authoritative for
-- every runtime/renderer export so a release cannot advertise one version to
-- the launcher and a different version to compatibility consumers such as
-- KASC. The fallback exists only for isolated legacy harnesses that construct
-- a minimal mod handle without loader metadata; the release contract asserts
-- that it matches manifest.json.
local PACKAGE_VERSION = type(mod.version) == "string" and mod.version
  or "3.0.2"
mod._vascPackageVersion = PACKAGE_VERSION

local function callFlag(GameVersion, name)
  local fn = GameVersion and GameVersion[name]
  if type(fn) ~= "function" then return nil end
  local ok, value = pcall(fn, GameVersion)
  if not ok then ok, value = pcall(fn) end
  if ok then return value == true end
  return nil
end

local function gameGeneration()
  local ok, GameVersion = pcall(require, "src.core.GameVersion")
  if not ok or type(GameVersion) ~= "table" then return nil end
  if tonumber(GameVersion.generation) then return tonumber(GameVersion.generation) end
  if type(GameVersion.generation) == "function" then
    local okGeneration, generation = pcall(GameVersion.generation, GameVersion)
    if not okGeneration then okGeneration, generation = pcall(GameVersion.generation) end
    generation = okGeneration and tonumber(generation) or nil
    if generation then return generation end
  end
  if callFlag(GameVersion, "isGen2") then return 2 end
  if callFlag(GameVersion, "isGen1") then return 1 end

  -- Gen1Recomp releases predating the shared Gen-2 launcher intentionally
  -- expose only get()/info() plus Red/Blue/Yellow predicates.  VASC 3 still
  -- supports those engines, so identify their public cartridge id instead of
  -- treating a missing generation() helper as an unsupported game.  This is
  -- deliberately a closed list: an unknown future cartridge remains inactive
  -- until its runtime has been reviewed.
  local function call(name)
    local fn = GameVersion[name]
    if type(fn) ~= "function" then return nil end
    local called, value = pcall(fn, GameVersion)
    if not called then called, value = pcall(fn) end
    return called and value or nil
  end
  local info = call("info")
  local generation = type(info) == "table" and tonumber(info.generation) or nil
  if generation then return generation end
  local id = call("get")
  if type(id) ~= "string" and type(info) == "table" then id = info.id end
  id = type(id) == "string" and id:lower() or nil
  if id == "red" or id == "blue" or id == "yellow" then return 1 end
  if id == "gold" or id == "silver" or id == "crystal" then return 2 end
  return nil
end

local function readOrError(owner, rel)
  local source, readErr = owner:read(rel)
  if not source then
    error(("VOXEL_ASCENDANT: missing %s: %s")
      :format(rel, tostring(readErr or "unavailable")), 0)
  end
  return source
end

local function runEntry(owner, rel)
  local source = readOrError(owner, rel)
  local chunk, compileErr = (loadstring or load)(source,
    "@" .. tostring(mod.path or "VOXEL_ASCENDANT") .. "/" .. rel)
  if not chunk then
    error(("VOXEL_ASCENDANT: %s did not compile: %s")
      :format(rel, tostring(compileErr)), 0)
  end
  return chunk(owner)
end

local generation = gameGeneration()
-- Both generation runtimes consume the same support-session owner. Bind the
-- resolved value on the root handle before either entry boots Diagnostics so
-- filenames and the first game-start receipt never fall back to Gx.
mod._vascHostGeneration = generation
-- The crash-loop marker uses generation as one of its closed decision fields.
-- Older RC12 bootstraps left it at "unknown"; supply the already resolved
-- dispatcher value before either generation attaches the recovery owner.
if MobileDiagnostic and type(MobileDiagnostic.setGeneration) == "function" then
  pcall(MobileDiagnostic.setGeneration, generation, {
    caller="main.lua", context="dispatcher", reason="generation-resolved",
  })
end
mod.exports = mod.exports or {}
mod.exports.packageVersion = PACKAGE_VERSION
mod.exports.generation = generation
mod.exports.dispatcher = true

if generation ~= 1 and generation ~= 2 then
  mod.exports.active = false
  mod.exports.runtime = "inactive"
  mod.exports.rendererInstalled = false
  mod.exports.rendererError = "Unable to identify a supported Pokemon generation"
  if mod.log and type(mod.log.warn) == "function" then
    mod.log:warn("Voxel Ascendant stays inactive: active game generation is unknown or unsupported")
  end
  return
end

-- One frozen, internal Overworld Card shared by both generation dispatches.
-- Prepare metadata before option schemas; boot after the generation exports
-- and declared provider dependencies, but before content registration closes.
-- The external host stays closed.
local OverworldCard = runEntry(mod, "lib/OverworldPokemonCard.lua")
local overworldCard = OverworldCard.new(mod)
mod._vascOverworldCard = overworldCard
mod.exports.overworldPokemonCard = {
  health=function() return overworldCard:health() end,
}
local function startOverworldCard()
  local ok, err = overworldCard:start()
  if not ok and mod.log then mod.log:warn("Overworld Card: %s", tostring(err)) end
end

if generation == 1 then
  mod.exports.runtime = "gen1"
  local result = runEntry(mod, "main_gen1.lua")
  -- Reassert the package version after the Gen-1 runtime populated exports.
  -- This prevents an optional compatibility provider from mistaking the 3.0
  -- package for a historical 2.x renderer.
  mod.exports.packageVersion = PACKAGE_VERSION
  mod.exports.version = PACKAGE_VERSION
  mod.exports.generation = 1
  mod.exports.runtime = "gen1"
  if type(mod.exports.renderer) == "table" then
    mod.exports.renderer.version = PACKAGE_VERSION
  end
  startOverworldCard()
  return result
end

local rawRead = assert(type(mod.read) == "function" and mod.read,
  "VOXEL_ASCENDANT: mod:read is unavailable")
local rawInfo = type(mod.info) == "function" and mod.info or nil
local rawFind = type(mod.find) == "function" and mod.find or nil

local function invokePath(method, rel)
  local okMethod, a, b, c = pcall(method, mod, rel)
  if okMethod and a ~= nil then return a, b, c end
  local okDot, x, y, z = pcall(method, rel)
  if okDot and x ~= nil then return x, y, z end
  if okMethod then return a, b, c end
  if okDot then return x, y, z end
  error(tostring(a) .. "; " .. tostring(x), 0)
end

-- These menu/presentation modules are deliberately generation-neutral public
-- VASC UI contracts. Gen 2 consumes the exact same reviewed sources as Gen 1 so a
-- menu hotfix cannot drift into a separate Gold/Silver/Crystal skin again.
-- Every gameplay, world and battle module remains rooted below gen2/.
-- A21's Gen-2 runtime was authored against these exact shared modules from
-- the supplied A21 package.  Keep them in a Gen-2-only namespace: loading the
-- newer Gen-1 copies here changes API contracts, while replacing the root
-- copies would regress Red/Blue/Yellow.  The facade preserves A21's original
-- public relative names but resolves their bytes from this closed segment.
local GEN2_A21_SHARED_UI = {
  ["lib/EditionAccent.lua"] = "lib/gen2_a21_shared/EditionAccent.lua",
  ["lib/ShortcutToast.lua"] = "lib/gen2_a21_shared/ShortcutToast.lua",
  ["lib/VascMenu.lua"] = "lib/gen2_a21_shared/VascMenu.lua",
  ["lib/VascMenuStyle.lua"] = "lib/gen2_a21_shared/VascMenuStyle.lua",
  -- One shared engine-scoped logger owns both generations.  The historical
  -- A21 copy writes through love.filesystem, which current Gen1Recomp removes
  -- from mod sandboxes and therefore lost real Crystal sessions.
  ["lib/Diagnostics.lua"] = "lib/Diagnostics.lua",
  ["lib/PerformanceDiagnostics.lua"] = "lib/PerformanceDiagnostics.lua",
  ["lib/TitleHubPresentation.lua"] = "lib/TitleHubPresentation.lua",
  ["lib/OrasUiSkin.lua"] = "lib/gen2_a21_shared/OrasUiSkin.lua",
  ["lib/OrasPartyPresentation.lua"] =
    "lib/gen2_a21_shared/OrasPartyPresentation.lua",
  ["lib/OrasPartySummaryPresentation.lua"] =
    "lib/gen2_a21_shared/OrasPartySummaryPresentation.lua",
  ["lib/OrasBagSkin.lua"] = "lib/gen2_a21_shared/OrasBagSkin.lua",
  ["lib/OrasFrlgBagSkin.lua"] = "lib/gen2_a21_shared/OrasFrlgBagSkin.lua",
  -- The sort action is generation-neutral; its Gen-2 adapter supplies the
  -- four-pocket ordering callback while the shared renderer owns the button.
  ["lib/ManualBagSort.lua"] = "lib/ManualBagSort.lua",
  ["lib/PokemonUi.lua"] = "lib/gen2_a21_shared/PokemonUi.lua",
  ["lib/AscBoxProvider.lua"] = "lib/gen2_a21_shared/AscBoxProvider.lua",
  ["lib/BattleLayout.lua"] = "lib/gen2_a21_shared/BattleLayout.lua",
  ["lib/BattleLayoutProfile.lua"] =
    "lib/gen2_a21_shared/BattleLayoutProfile.lua",
  ["lib/BattleArenaStyle.lua"] =
    "lib/gen2_a21_shared/BattleArenaStyle.lua",
  ["lib/VoxelBattleStage.lua"] =
    "lib/gen2_a21_shared/VoxelBattleStage.lua",
  ["data/battle_disks.lua"] =
    "lib/gen2_a21_shared/data/battle_disks.lua",
}

-- RC11 shares only the generation-neutral Card kernel and exact-owner battle
-- Router.  This is an explicit file allowlist rather than a directory escape:
-- Gen-2 gameplay, adapters and renderer modules remain rooted below gen2/.
local GEN2_SHARED_CARD_CORE = {
  ["lib/FieldKitPresentation.lua"] = true,
  ["lib/HdContentMenu.lua"] = true,
  ["lib/core/AscendantContracts.lua"] = true,
  ["lib/core/AscendantHooks.lua"] = true,
  ["lib/core/AscendantCardRegistry.lua"] = true,
  ["lib/core/AscendantCardHost.lua"] = true,
  ["lib/core/BattleProviderContracts.lua"] = true,
  ["lib/core/BattleProviderRouter.lua"] = true,
  ["lib/cards/battle_router/BattleRouterOwnerControl.lua"] = true,
}

local function privatePath(rel)
  local a21Shared = GEN2_A21_SHARED_UI[rel]
  if a21Shared then return a21Shared end
  if GEN2_SHARED_CARD_CORE[rel] then return rel end
  if rel == "options.lua" or rel:match("^lib/") or rel:match("^data/") then
    return "gen2/" .. rel
  end
  return rel
end

local gen2 = setmetatable({
  id = mod.id,
  path = mod.path,
  exports = mod.exports,
  _vascHostGeneration = 2,
  _vascPackageVersion = PACKAGE_VERSION,
}, { __index = mod })

function gen2:read(rel)
  assert(type(rel) == "string", "VOXEL_ASCENDANT: read path must be a string")
  return invokePath(rawRead, privatePath(rel))
end

if rawInfo then
  function gen2:info(rel)
    assert(type(rel) == "string", "VOXEL_ASCENDANT: info path must be a string")
    return invokePath(rawInfo, privatePath(rel))
  end
end

if rawFind then
  gen2.find = function(first, second)
    local id = first == gen2 and second or first
    local ok, found = pcall(rawFind, id)
    if ok and found ~= nil then return found end
    local dotError = found
    ok, found = pcall(rawFind, mod, id)
    if ok then return found end
    error(tostring(dotError) .. "; " .. tostring(found), 0)
  end
end

local optionsSource = readOrError(gen2, "options.lua")
local optionsChunk, optionsErr = (loadstring or load)(optionsSource,
  "@" .. tostring(mod.path or "VOXEL_ASCENDANT") .. "/gen2/options.lua")
if not optionsChunk then
  error("VOXEL_ASCENDANT: Gen2 options did not compile: " .. tostring(optionsErr), 0)
end
local okSchema, schema = pcall(optionsChunk)
if not okSchema or type(schema) ~= "table" then
  error("VOXEL_ASCENDANT: Gen2 options did not return a schema: " .. tostring(schema), 0)
end
for _, spec in ipairs(overworldCard.options.managerSchema(mod)) do schema[#schema+1]=spec end
if not (mod.options and type(mod.options.define) == "function") then
  error("VOXEL_ASCENDANT: Gen2 option registration is unavailable", 0)
end
mod.options:define(schema)
gen2._vascGen2Schema = schema
mod.exports.runtime = "gen2"
mod.exports.targetGeneration = 2

-- Preserve the supplied A21 bootstrap order exactly through completion.  In
-- particular, GoldVoxelBridge is allowed to install and begin the current-map,
-- panorama and sky startup path before the ownership registry does any work.
local runtimeResult = runEntry(gen2, "gen2/main.lua")

-- The Cards are declarative ownership boundaries around the already-running
-- A21 runtime.  They do not wrap or replace its implementation files.
local segmentModules = {}
local SegmentV = { mod=mod }
function SegmentV.require(name)
  if segmentModules[name] ~= nil then return segmentModules[name] end
  local rel = "lib/" .. tostring(name) .. ".lua"
  local source = readOrError(mod, rel)
  local chunk, loadErr = (loadstring or load)(source,
    "@" .. tostring(mod.path or "VOXEL_ASCENDANT") .. "/" .. rel)
  if not chunk then
    error(("VOXEL_ASCENDANT: Gen2 segment module %s did not compile: %s")
      :format(rel, tostring(loadErr)), 0)
  end
  local value = chunk(SegmentV)
  if value == nil then value = true end
  segmentModules[name] = value
  return value
end

local Gen2SegmentCardHost = SegmentV.require("Gen2SegmentCardHost")
local segmentsInstalled, segmentsErr = Gen2SegmentCardHost.install({ mod=mod })
if segmentsInstalled ~= true then
  error("VOXEL_ASCENDANT: Gen2 Card segmentation failed: "
    .. tostring(segmentsErr), 0)
end
gen2._vascGen2SegmentCardHost = Gen2SegmentCardHost
mod.exports.gen2SegmentCards = Gen2SegmentCardHost.public()
startOverworldCard()
return runtimeResult
