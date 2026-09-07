-- Read-only runtime for immutable Content Selector generations.
-- The desktop app owns imports and atomic pointer writes. VASC verifies the
-- selected pointer, manifest and every referenced asset before exposing one
-- complete CUSTOM generation; a partial generation is never used.

local V = ...
local PresetRuntime = {}
local UserFiles = V.require("UserFiles")
local ContentJson = V.require("ContentJson")

PresetRuntime.API_VERSION = 2
PresetRuntime.ROOT = "user/content-selector/preset-runtime/v1"
PresetRuntime.POINTER_V1 = "vasc-active-preset/v1"
PresetRuntime.POINTER_V2 = "vasc-active-preset/v2"
PresetRuntime.MANIFEST = "vasc-content-preset/v1"

local MAX_POINTER = 256 * 1024
local MAX_MANIFEST = 16 * 1024 * 1024
local MAX_ASSET = 256 * 1024 * 1024
local MAX_TOTAL = 4 * 1024 * 1024 * 1024
local MAX_ITEMS = 10000
local MAX_PACKAGE_RECEIPT = 512 * 1024
local MAX_RUNTIME_FILES = 512
local MAX_RUNTIME_SOURCE = 2 * 1024 * 1024
local MAX_RUNTIME_TOTAL = 64 * 1024 * 1024
local RUNTIME_RECEIPT_PATH = "runtime-receipt.json"
local RUNTIME_RECEIPT_SCHEMA = "voxel-ascendant/runtime-receipt/v1"
local PROCESS_GUARD_KEY = "_vascPresetRuntimeProcessGuardV2"
local GAME_GENERATION = {
  red="gen1", blue="gen1", yellow="gen1",
  gold="gen2", silver="gen2", crystal="gen2",
}
local EXTENSION = { png=true, mp3=true, ogg=true, wav=true, flac=true }
local MUSIC_CATEGORY = {
  wild=true, trainer=true, rival=true, gym=true, elite4=true, champion=true,
  field=true, bike=true, surf=true, victory=true, evolution=true, title=true,
  halloffame=true, credits=true, jingle=true, scene=true,
}
local SPRITE_GROUP = {
  ["pokemon.front"]=true, ["pokemon.back"]=true,
  ["pokemon.retro"]=true, ["pokemon.mega"]=true,
  ["trainer.player"]=true, ["trainer.opponent"]=true,
}
local BATTLE_BACKGROUND_SCHEMA = "vasc-battle-backgrounds/v1"
local BATTLE_BACKGROUND_PLAN_SCHEMA = "vasc-battle-background-plan/v1"
local BATTLE_BACKGROUND_SURFACE = "arena.backdrop"
local BATTLE_BACKGROUND_SLOT = "ARENA_BACKDROP"
local MAX_BACKGROUND_RULES = 1024
local MAX_BACKGROUND_ASSETS = 64
local MAX_BACKGROUND_ASSET = 32 * 1024 * 1024
local BACKGROUND_DIMENSIONS = {
  ["640x400"]=true, ["1280x800"]=true, ["1920x1200"]=true,
  ["2560x1600"]=true, ["3840x2400"]=true,
}
local BATTLE_KINDS = {
  wild=true, trainer=true, rival=true, gym=true, elite4=true,
  champion=true, special=true,
}
local state = {
  valid=false, mode="VASC_DEFAULT", reason="not-scanned", scope="default",
  baseProfile="vasc-default", generation=nil, game=nil,
  restartRequired=false, restartReason=nil, packageReceiptVerified=false,
  sprites={}, exactMusic={}, categoryMusic={}, musicIds={},
}
local lastMusic, battleMusic, serial = {}, nil, 0
local installed, pointerSnapshot, packageReceiptVerified = false, nil, false
local packageRestartLatched = false
local processGuard = nil
local fallbackMusicRegistries = setmetatable({}, {__mode="k"})
local backgroundSelections = setmetatable({}, {__mode="k"})
local backgroundChoiceReceipts = setmetatable({}, {__mode="k"})
local NO_BACKGROUND = {}

local function safePath(value)
  if type(value) ~= "string" or value == "" or #value > 1024
     or value:find("[%z\1-\31\127]") or value:find("\\", 1, true)
     or value:sub(1, 1) == "/" or value:match("^%a:")
     or value:sub(1, 2) == "//" or value:find("//", 1, true)
     or value:sub(-1) == "/" then return false end
  local count = 0
  for component in value:gmatch("[^/]+") do
    count = count + 1
    if component == "." or component == ".." or component == ""
       or #component > 255 then return false end
  end
  return count > 0
end

local function sha(value)
  return type(value) == "string" and #value == 64
    and value:match("^[0-9a-f]+$") ~= nil
end

local function id(value, maximum)
  return type(value) == "string" and #value <= (maximum or 128)
    and value:match("^[A-Za-z0-9][A-Za-z0-9_.%-]*$") ~= nil
end

-- Preset IDs stay on their deliberately narrower portable-ID contract.
-- Versions additionally admit SemVer build metadata (for example
-- 1.2.3+hgss.4), matching the selector's v1 schema.
local function version(value)
  return type(value) == "string" and #value <= 64
    and value:match("^[A-Za-z0-9][A-Za-z0-9_.+%-]*$") ~= nil
end

local function exactFields(value, allowed)
  if type(value) ~= "table" then return false end
  for key in pairs(value) do
    if type(key) ~= "string" or not allowed[key] then return false end
  end
  return true
end

local function denseArray(value, maximum)
  if type(value) ~= "table" then return nil end
  local count = 0
  for key in pairs(value) do
    if type(key) ~= "number" or key < 1 or key ~= math.floor(key) then return nil end
    count = count + 1
  end
  if count ~= #value or count > (maximum or MAX_ITEMS) then return nil end
  return count
end

local function callGameVersion(name)
  local ok, GameVersion = pcall(require, "src.core.GameVersion")
  if not ok or type(GameVersion) ~= "table" then return nil end
  local fn = GameVersion[name]
  if type(fn) ~= "function" then return nil end
  local called, value = pcall(fn, GameVersion)
  if not called then called, value = pcall(fn) end
  return called and value or nil
end

local function identity()
  local game = callGameVersion("get")
  local info = callGameVersion("info")
  if type(game) ~= "string" and type(info) == "table" then game = info.id end
  game = type(game) == "string" and game:lower() or nil
  if not GAME_GENERATION[game] then game = nil end
  local generation = game and GAME_GENERATION[game] or nil
  if not generation then
    local numeric = V and V.mod and tonumber(V.mod._vascHostGeneration)
    if not numeric and type(info) == "table" then numeric = tonumber(info.generation) end
    if not numeric then numeric = tonumber(callGameVersion("generation")) end
    if numeric == 1 or numeric == 2 then generation = "gen" .. tostring(numeric) end
  end
  return generation or "gen1", game
end

local function cleanState(reason)
  local generation, game = identity()
  return {
    valid=false, mode="VASC_DEFAULT", reason=reason, scope="default",
    baseProfile="vasc-default", generation=generation, game=game,
    restartRequired=false, restartReason=nil,
    packageReceiptVerified=packageReceiptVerified,
    sprites={}, exactMusic={}, categoryMusic={}, musicIds={},
  }
end

local function packageVersion(mod)
  local version = mod and (mod._vascPackageVersion or mod.version)
    or V and V.mod and (V.mod._vascPackageVersion or V.mod.version)
  return tostring(version or "unknown")
end

local function packageReceipt(mod)
  local bytes = UserFiles.read(RUNTIME_RECEIPT_PATH, MAX_PACKAGE_RECEIPT)
  local receiptDigest = UserFiles.sha256(
    RUNTIME_RECEIPT_PATH, MAX_PACKAGE_RECEIPT)
  if not bytes or not sha(receiptDigest) then return nil, false end
  local receipt = ContentJson.decode(bytes)
  if type(receipt) ~= "table"
     or not exactFields(receipt, {
       schema=true, package_id=true, version=true, manifest_sha256=true,
       file_count=true, files=true,
     })
     or receipt.schema ~= RUNTIME_RECEIPT_SCHEMA
     or receipt.package_id ~= "VOXEL_ASCENDANT"
     or receipt.version ~= packageVersion(mod)
     or not sha(receipt.manifest_sha256) then
    return nil, false
  end
  local manifestInfo = UserFiles.info("manifest.json", "file")
  local manifestDigest = UserFiles.sha256("manifest.json", MAX_RUNTIME_SOURCE)
  if not manifestInfo or not sha(manifestDigest)
     or manifestDigest ~= receipt.manifest_sha256 then
    return nil, false
  end
  local count = denseArray(receipt.files, MAX_RUNTIME_FILES)
  if not count or count < 1 or receipt.file_count ~= count then
    return nil, false
  end
  local required = {
    ["main.lua"]=false, ["main_gen1.lua"]=false,
    ["battle_hud_oras.lua"]=false,
    ["lib/PresetRuntime.lua"]=false, ["lib/LocalContent.lua"]=false,
    ["lib/LocalMusic.lua"]=false, ["lib/LocalSprites.lua"]=false,
    ["lib/BattleScene.lua"]=false, ["lib/OverworldBattle.lua"]=false,
    ["gen2/main.lua"]=false, ["gen2/options.lua"]=false,
    ["gen2/lib/PresetRuntime.lua"]=false,
    ["gen2/lib/LocalContent.lua"]=false,
    ["gen2/lib/LocalMusic.lua"]=false,
    ["gen2/lib/LocalSprites.lua"]=false,
    ["gen2/lib/BattleScene.lua"]=false,
    ["gen2/lib/OverworldBattle.lua"]=false,
    ["gen2/lib/sprite_resolver.lua"]=false,
  }
  local seen, previous, total = {}, nil, 0
  for _, row in ipairs(receipt.files) do
    if type(row) ~= "table"
       or not exactFields(row, {path=true, sha256=true, size_bytes=true})
       or not safePath(row.path) or not row.path:match("%.lua$")
       or not sha(row.sha256)
       or type(row.size_bytes) ~= "number"
       or row.size_bytes ~= math.floor(row.size_bytes)
       or row.size_bytes < 1 or row.size_bytes > MAX_RUNTIME_SOURCE
       or seen[row.path] or (previous and row.path <= previous) then
      return nil, false
    end
    local info = UserFiles.info(row.path, "file")
    local digest = UserFiles.sha256(row.path, row.size_bytes)
    if not info or tonumber(info.size) ~= row.size_bytes
       or digest ~= row.sha256 then return nil, false end
    seen[row.path], previous = true, row.path
    if required[row.path] ~= nil then required[row.path] = true end
    total = total + row.size_bytes
    if total > MAX_RUNTIME_TOTAL then return nil, false end
  end
  for _, present in pairs(required) do
    if not present then return nil, false end
  end
  return receiptDigest .. "|manifest=" .. manifestDigest
    .. "|version=" .. packageVersion(mod), true
end

local function processOwner(mod)
  -- src.core.Game is a process singleton, but this private module field is
  -- outside Game.data and therefore never enters a save.  A fresh mod API or
  -- Lua loader created by F5 still sees the receipt accepted at process boot.
  local ok, Game = pcall(require, "src.core.Game")
  if ok and type(Game) == "table" then return Game end
  return mod or V and V.mod
end

local function packageSafe(mod)
  local owner = processOwner(mod)
  local previous = type(owner) == "table" and owner[PROCESS_GUARD_KEY] or nil
  if packageRestartLatched
     or type(previous) == "table" and previous.blocked == true then
    packageRestartLatched, packageReceiptVerified = true, false
    processGuard = previous
    return false
  end
  local receipt, verified = packageReceipt(mod)
  if not verified
     or type(previous) == "table" and previous.receipt ~= receipt then
    packageRestartLatched, packageReceiptVerified = true, false
    if type(owner) == "table" then
      owner[PROCESS_GUARD_KEY] = {
        receipt=previous and previous.receipt or receipt,
        verified=false, blocked=true,
        musicRegistries=previous and previous.musicRegistries or nil,
      }
      processGuard = owner[PROCESS_GUARD_KEY]
    end
    return false
  end
  packageReceiptVerified = true
  if type(owner) ~= "table" then return true end
  if type(previous) ~= "table" then
    previous = {musicRegistries=setmetatable({}, {__mode="k"})}
  elseif type(previous.musicRegistries) ~= "table" then
    previous.musicRegistries = setmetatable({}, {__mode="k"})
  end
  previous.receipt, previous.verified, previous.blocked = receipt, true, false
  owner[PROCESS_GUARD_KEY], processGuard = previous, previous
  return true
end

local function chooseSelection(pointer)
  local generation, game = identity()
  if pointer.schema == PresetRuntime.POINTER_V1 then
    if not exactFields(pointer, {
      schema=true, mode=true, base_profile=true, preset=true, ["$schema"]=true,
    }) then return nil, "pointer-fields", generation, game end
    -- v1 stores the selection and its envelope in one object.  Normalize the
    -- already field-checked envelope so the shared selection validator does
    -- not mistake `schema`/`$schema` for nested v2 selection fields.
    return {
      mode=pointer.mode, base_profile=pointer.base_profile,
      preset=pointer.preset,
    }, "default", generation, game
  end
  if pointer.schema ~= PresetRuntime.POINTER_V2
     or type(pointer.default) ~= "table"
     or type(pointer.generations) ~= "table"
     or type(pointer.games) ~= "table" then
    return nil, "pointer-schema", generation, game
  end
  if not exactFields(pointer, {
    schema=true, default=true, generations=true, games=true, ["$schema"]=true,
  }) or not exactFields(pointer.generations, {gen1=true, gen2=true})
     or not exactFields(pointer.games, {
       red=true, blue=true, yellow=true, gold=true, silver=true, crystal=true,
     }) then
    return nil, "pointer-fields", generation, game
  end
  if game and type(pointer.games[game]) == "table" then
    return pointer.games[game], game, generation, game
  end
  if type(pointer.generations[generation]) == "table" then
    return pointer.generations[generation], generation, generation, game
  end
  return pointer.default, "default", generation, game
end

local function pointerReference(selection)
  if type(selection) ~= "table" then return nil, "selection-missing" end
  if selection.mode == "VASC_DEFAULT" then
    if not exactFields(selection, {mode=true}) then
      return nil, "selection-fields"
    end
    return false
  end
  if selection.mode ~= "CUSTOM" then return nil, "selection-mode" end
  if not exactFields(selection, {mode=true, base_profile=true, preset=true}) then
    return nil, "selection-fields"
  end
  local base = selection.base_profile
  if base ~= "vasc-default" and base ~= "retro" then
    return nil, "selection-base-profile"
  end
  local ref = selection.preset
  if type(ref) ~= "table"
     or not exactFields(ref, {id=true, version=true, generation_path=true,
                             manifest_path=true, manifest_sha256=true})
     or not id(ref.id, 96) or not version(ref.version)
     or not sha(ref.manifest_sha256) then return nil, "selection-reference" end
  local digest = ref.manifest_sha256
  local generationPath = "generations/" .. digest
  local manifestPath = generationPath .. "/manifest.json"
  if ref.generation_path ~= generationPath or ref.manifest_path ~= manifestPath then
    return nil, "selection-reference-path"
  end
  return {
    id=ref.id, version=ref.version, digest=digest, baseProfile=base,
    generationPath=generationPath, manifestPath=manifestPath,
  }
end

local function u32(bytes, at)
  local a, b, c, d = bytes:byte(at, at + 3)
  if not d then return nil end
  return ((a * 256 + b) * 256 + c) * 256 + d
end

local function validMedia(format, bytes)
  if format == "png" then
    if bytes:sub(1, 8) ~= "\137PNG\13\10\26\10" or bytes:sub(13, 16) ~= "IHDR" then
      return false
    end
    local width, height = u32(bytes, 17), u32(bytes, 21)
    return width and height and width >= 1 and width <= 4096
      and height >= 1 and height <= 4096
  end
  if format == "ogg" then return bytes:sub(1, 4) == "OggS" end
  if format == "flac" then return bytes:sub(1, 4) == "fLaC" end
  if format == "wav" then
    return bytes:sub(1, 4) == "RIFF" and bytes:sub(9, 12) == "WAVE"
  end
  if format == "mp3" then
    local a, b = bytes:byte(1, 2)
    return bytes:sub(1, 3) == "ID3" or (a == 0xFF and b and b >= 0xE0)
  end
  return false
end

local function matchId(value)
  return type(value) == "string" and value ~= "" and #value <= 128
    and value:match("^[A-Za-z0-9][A-Za-z0-9_.:%-]*$") ~= nil
end

-- Python's selector hashes json.dumps(sort_keys=True, indent=2,
-- ensure_ascii=False) plus one trailing newline.  The plan contains only
-- bounded integers, strings, arrays and objects, so this deliberately small
-- encoder can reproduce those exact bytes without becoming another manifest
-- parser or accepting executable data.
local function jsonString(value)
  local escaped = value:gsub("[\\\"%z\1-\31]", function(char)
    local short = {
      ['"']='\\"', ['\\']='\\\\', ['\b']='\\b', ['\f']='\\f',
      ['\n']='\\n', ['\r']='\\r', ['\t']='\\t',
    }
    return short[char] or ("\\u%04x"):format(char:byte())
  end)
  return '"' .. escaped .. '"'
end

local canonicalJson
canonicalJson = function(value, depth)
  depth = depth or 0
  local kind = type(value)
  if kind == "string" then return jsonString(value) end
  if kind == "number" and value == math.floor(value) then return tostring(value) end
  if kind == "boolean" then return value and "true" or "false" end
  if kind ~= "table" then return nil end
  local arrayCount, stringKeys = 0, {}
  for key in pairs(value) do
    if type(key) == "number" and key >= 1 and key == math.floor(key) then
      arrayCount = arrayCount + 1
    elseif type(key) == "string" then
      stringKeys[#stringKeys + 1] = key
    else
      return nil
    end
  end
  local indent, childIndent = string.rep("  ", depth), string.rep("  ", depth + 1)
  if #stringKeys == 0 and arrayCount > 0 then
    if arrayCount ~= #value then return nil end
    local rows = {}
    for index = 1, #value do
      local encoded = canonicalJson(value[index], depth + 1)
      if not encoded then return nil end
      rows[#rows + 1] = childIndent .. encoded
    end
    return "[\n" .. table.concat(rows, ",\n") .. "\n" .. indent .. "]"
  end
  if arrayCount ~= 0 then return nil end
  table.sort(stringKeys)
  local rows = {}
  for _, key in ipairs(stringKeys) do
    local encoded = canonicalJson(value[key], depth + 1)
    if not encoded then return nil end
    rows[#rows + 1] = childIndent .. jsonString(key) .. ": " .. encoded
  end
  return "{\n" .. table.concat(rows, ",\n") .. "\n" .. indent .. "}"
end

local function sha256Bytes(value)
  local data = love and love.data
  if not (data and type(data.hash) == "function") then return nil end
  local ok, digest = pcall(data.hash, "sha256", value)
  if not ok then return nil end
  if type(digest) ~= "string" and digest
     and type(digest.getString) == "function" then
    local got, bytes = pcall(digest.getString, digest)
    digest = got and bytes or nil
  end
  return type(digest) == "string" and #digest == 32 and digest or nil
end

local function hexDigest(value)
  local digest = sha256Bytes(value)
  if not digest then return nil end
  return (digest:gsub(".", function(char) return ("%02x"):format(char:byte()) end))
end

local function backgroundMatch(raw, label)
  if type(raw) ~= "table" or not exactFields(raw, {
    generation=true, game=true, route_or_map=true, battle_kind=true,
    trainer_id=true, battle_id=true,
  }) then return nil, label .. "-fields" end
  local rawGeneration, rawGame = raw.generation, raw.game
  local generation = type(rawGeneration) == "string" and rawGeneration:lower()
  local game = type(rawGame) == "string" and rawGame:lower()
  if rawGeneration ~= generation or rawGame ~= game
     or (generation ~= "gen1" and generation ~= "gen2")
     or GAME_GENERATION[game] ~= generation
     or not matchId(raw.route_or_map) then
    return nil, label .. "-identity"
  end
  local rawKind = raw.battle_kind
  local kind = rawKind
  if rawKind ~= nil then
    kind = type(rawKind) == "string" and rawKind:lower() or nil
    if rawKind ~= kind or not BATTLE_KINDS[kind] then
      return nil, label .. "-kind"
    end
  end
  if raw.trainer_id ~= nil and not matchId(raw.trainer_id) then
    return nil, label .. "-trainer"
  end
  if raw.battle_id ~= nil and not matchId(raw.battle_id) then
    return nil, label .. "-battle"
  end
  if kind == "wild" and raw.trainer_id ~= nil then
    return nil, label .. "-wild-trainer"
  end
  local result = {
    generation=generation, game=game, route_or_map=raw.route_or_map,
  }
  if kind then result.battle_kind = kind end
  if raw.trainer_id then result.trainer_id = raw.trainer_id end
  if raw.battle_id then result.battle_id = raw.battle_id end
  return result
end

local function backgroundPlan(raw, assets)
  if type(raw) ~= "table" or not exactFields(raw, {
    schema=true, surface=true, plan_digest=true, rules=true,
  }) or raw.schema ~= BATTLE_BACKGROUND_SCHEMA
     or raw.surface ~= BATTLE_BACKGROUND_SURFACE or not sha(raw.plan_digest) then
    return nil, nil, "battle-background-contract"
  end
  if not denseArray(raw.rules, MAX_BACKGROUND_RULES) or #raw.rules < 1 then
    return nil, nil, "battle-background-rules"
  end
  local planRules, referenced, seenIds, seenMatches = {}, {}, {}, {}
  local previousRule
  for index, rawRule in ipairs(raw.rules) do
    local label = "battle-background-rule-" .. tostring(index)
    if type(rawRule) ~= "table" or not exactFields(rawRule, {
      id=true, action=true, slot=true, match=true, selection=true,
      asset_ids=true,
    }) or not id(rawRule.id, 96) or seenIds[rawRule.id:lower()]
       or (previousRule and rawRule.id < previousRule)
       or (rawRule.action ~= "add" and rawRule.action ~= "replace")
       or rawRule.slot ~= BATTLE_BACKGROUND_SLOT then
      return nil, nil, label
    end
    previousRule, seenIds[rawRule.id:lower()] = rawRule.id, true
    local match, matchWhy = backgroundMatch(rawRule.match, label .. "-match")
    if not match then return nil, nil, matchWhy end
    -- Runtime comparison is ASCII case-insensitive for every match scalar.
    -- Normalize the duplicate key the same way or ROUTE_1/route_1 could
    -- author two semantically identical rules with order-dependent results.
    local normalizedMatch = {}
    for key, value in pairs(match) do
      normalizedMatch[key] = type(value) == "string" and value:lower() or value
    end
    local matchKey = canonicalJson(normalizedMatch, 0)
    if not matchKey or seenMatches[matchKey] then
      return nil, nil, label .. "-duplicate-match"
    end
    seenMatches[matchKey] = true
    if not denseArray(rawRule.asset_ids, MAX_BACKGROUND_ASSETS)
       or #rawRule.asset_ids < 1 then
      return nil, nil, label .. "-assets"
    end
    local candidates, selected, previousAsset = {}, {}, nil
    for _, assetId in ipairs(rawRule.asset_ids) do
      local asset = type(assetId) == "string" and assets[assetId] or nil
      if not asset or asset.id ~= assetId or asset.lane ~= "sprites"
         or asset.format ~= "png" or not asset.assetPath
         or asset.size > MAX_BACKGROUND_ASSET
         or selected[assetId:lower()]
         or (previousAsset and assetId < previousAsset)
         or not BACKGROUND_DIMENSIONS[
           tostring(asset.width) .. "x" .. tostring(asset.height)] then
        return nil, nil, label .. "-asset"
      end
      selected[assetId:lower()], previousAsset, referenced[assetId] =
        true, assetId, true
      candidates[#candidates + 1] = {
        asset_id=asset.id, path=asset.manifestPath, sha256=asset.digest,
        size_bytes=asset.size,
      }
    end
    local selection = rawRule.selection
    if type(selection) ~= "table" then return nil, nil, label .. "-selection" end
    local normalizedSelection
    if selection.mode == "first" and #candidates == 1
       and exactFields(selection, {mode=true}) then
      normalizedSelection = {mode="first"}
    elseif selection.mode == "deterministic-shuffle" and #candidates >= 2
       and exactFields(selection, {mode=true, seed=true}) and sha(selection.seed) then
      normalizedSelection = {mode="deterministic-shuffle", seed=selection.seed}
    else
      return nil, nil, label .. "-selection"
    end
    planRules[#planRules + 1] = {
      action=rawRule.action, candidates=candidates, id=rawRule.id,
      match=match, selection=normalizedSelection, slot=rawRule.slot,
    }
  end
  local document = {
    rules=planRules, schema=BATTLE_BACKGROUND_PLAN_SCHEMA,
    surface=BATTLE_BACKGROUND_SURFACE,
  }
  local encoded = canonicalJson(document, 0)
  local digest = encoded and hexDigest(encoded .. "\n") or nil
  if digest ~= raw.plan_digest then
    return nil, nil, digest and "battle-background-plan-digest"
      or "battle-background-plan-sha256-unavailable"
  end
  -- Runtime-only paths and dimensions are deliberately attached only after
  -- the cross-language plan digest has been verified.  They therefore cannot
  -- alter the selector's canonical document, but the eventual image upload
  -- still remains pinned to the exact immutable asset receipt validated above.
  for _, rule in ipairs(planRules) do
    for _, candidate in ipairs(rule.candidates) do
      local asset = assets[candidate.asset_id]
      candidate._assetPath = asset.assetPath
      candidate._relativePath = asset.path
      candidate._width = asset.width
      candidate._height = asset.height
    end
  end
  return {surface=BATTLE_BACKGROUND_SURFACE, digest=digest, rules=planRules},
    referenced
end

local function assetReceipt(raw, reference, ordinal)
  if type(raw) ~= "table"
     or not exactFields(raw, {id=true, label=true, lane=true, format=true,
                              path=true, sha256=true, size_bytes=true})
     or not id(raw.id) or type(raw.label) ~= "string" or raw.label == ""
     or #raw.label > 4096 or not safePath(raw.path)
     or not sha(raw.sha256) or type(raw.size_bytes) ~= "number"
     or raw.size_bytes ~= math.floor(raw.size_bytes) or raw.size_bytes < 1
     or raw.size_bytes > MAX_ASSET or not EXTENSION[raw.format]
     or (raw.lane ~= "sprites" and raw.lane ~= "music") then
    return nil, "manifest-asset"
  end
  if (raw.format == "png") ~= (raw.lane == "sprites") then
    return nil, "manifest-asset-lane"
  end
  if not raw.path:match("^assets/") then return nil, "manifest-asset-path" end
  local relative = PresetRuntime.ROOT .. "/" .. reference.generationPath
    .. "/" .. raw.path
  local info = UserFiles.info(relative, "file")
  if not info or (info.size and tonumber(info.size) ~= raw.size_bytes) then
    return nil, "asset-size"
  end
  local digest = UserFiles.sha256(relative, raw.size_bytes)
  if digest ~= raw.sha256 then return nil, "asset-sha256" end
  local bytes = UserFiles.read(relative, raw.size_bytes)
  if not bytes or #bytes ~= raw.size_bytes or not validMedia(raw.format, bytes) then
    return nil, "asset-format"
  end
  local extension = raw.path:match("%.([A-Za-z0-9]+)$")
  if not extension or extension:lower() ~= raw.format then
    return nil, "asset-extension"
  end
  return {
    id=raw.id, lane=raw.lane, format=raw.format, path=relative,
    assetPath=UserFiles.path(relative), size=raw.size_bytes,
    digest=raw.sha256, ordinal=ordinal, manifestPath=raw.path,
    width=raw.format == "png" and u32(bytes, 17) or nil,
    height=raw.format == "png" and u32(bytes, 21) or nil,
  }
end

local function musicId(reference, asset)
  -- The old slug mapped e.g. battle-a and battle.a to the same registry key.
  -- Canonical manifest order plus the immutable asset digest is injective for
  -- every valid manifest, while remaining stable across machines and reloads.
  return ("VASC_PRESET_%s_%05d_%s"):format(
    reference.digest:upper(), asset.ordinal, asset.digest:upper())
end

local function buildRuntime(reference, manifest)
  if type(manifest) ~= "table" or manifest.schema ~= PresetRuntime.MANIFEST
     or not exactFields(manifest, {
       ["$schema"]=true, schema=true, id=true, name=true, version=true,
       author=true, description=true, target_api=true, base_profile=true,
       capability_hints=true, assets=true, assignments=true,
       battle_backgrounds=true,
     })
     or manifest.target_api ~= "vasc-local-content/v1"
     or manifest.id ~= reference.id or manifest.version ~= reference.version
     or manifest.base_profile ~= reference.baseProfile
     or type(manifest.name) ~= "string" or manifest.name == ""
     or type(manifest.author) ~= "string" or manifest.author == ""
     or type(manifest.description) ~= "string" or manifest.description == ""
     or not denseArray(manifest.assets) or #manifest.assets < 1
     or not denseArray(manifest.assignments)
     or (#manifest.assignments < 1 and manifest.battle_backgrounds == nil) then
    return nil, "manifest-contract"
  end
  if manifest.capability_hints ~= nil
     and not denseArray(manifest.capability_hints, 64) then
    return nil, "manifest-capability-hints"
  end
  local assets, total, assetPaths, previousAsset = {}, 0, {}, nil
  for ordinal, raw in ipairs(manifest.assets) do
    local receipt, why = assetReceipt(raw, reference, ordinal)
    local idKey = receipt and receipt.id:lower() or nil
    local pathKey = type(raw.path) == "string" and raw.path:lower() or nil
    if not receipt or assets[receipt.id] or (idKey and assets[idKey])
       or (pathKey and assetPaths[pathKey]) then
      return nil, why or "asset-duplicate"
    end
    if previousAsset and receipt.id < previousAsset then return nil, "asset-order" end
    previousAsset = receipt.id
    assets[receipt.id] = receipt
    assets[idKey] = receipt
    assetPaths[pathKey] = true
    total = total + receipt.size
    if total > MAX_TOTAL then return nil, "asset-total" end
  end
  local runtime = cleanState(nil)
  runtime.valid, runtime.mode, runtime.reason = true, "CUSTOM", nil
  runtime.baseProfile = reference.baseProfile
  runtime.preset = {id=reference.id, version=reference.version, digest=reference.digest}
  local assignmentIds, previousAssignment, referenced, targetKeys = {}, nil, {}, {}
  local pendingMusic = {}
  local pendingMusicIds = {}
  for _, assignment in ipairs(manifest.assignments) do
    if type(assignment) ~= "table" or not id(assignment.id)
       or assignmentIds[assignment.id:lower()] or type(assignment.group) ~= "string" then
      return nil, "manifest-assignment"
    end
    if previousAssignment and assignment.id < previousAssignment then
      return nil, "assignment-order"
    end
    previousAssignment = assignment.id
    assignmentIds[assignment.id:lower()] = true
    if assignment.group == "music.mapping" then
      if not exactFields(assignment, assignment.mode == "exact-replace"
          and {id=true, group=true, mode=true, target=true, asset_ids=true}
          or {id=true, group=true, mode=true, category=true, asset_ids=true}) then
        return nil, "music-assignment-fields"
      end
      local assetIds = assignment.asset_ids
      if not denseArray(assetIds, 256) or #assetIds < 1 then
        return nil, "music-assignment-assets"
      end
      local songs, selected, previous = {}, {}, nil
      for _, assetId in ipairs(assetIds) do
        local asset = assets[assetId]
        if not asset or asset.id ~= assetId or asset.lane ~= "music"
           or not asset.assetPath or selected[assetId:lower()]
           or (previous and assetId < previous) then
          return nil, "music-assignment-asset"
        end
        selected[assetId:lower()], previous, referenced[assetId] = true, assetId, true
        local song = musicId(reference, asset)
        if not pendingMusicIds[song] then
          pendingMusic[#pendingMusic + 1] = {id=song, file=asset.assetPath}
          pendingMusicIds[song] = true
        end
        runtime.musicIds[assetId], songs[#songs + 1] = song, song
      end
      if assignment.mode == "exact-replace" and #songs == 1
         and type(assignment.target) == "string" then
        local original, extension = assignment.target:match(
          "^replace/([A-Za-z0-9_.%-]+)%.([A-Za-z0-9]+)$")
        if not original or not id(original) or extension:lower() ~= assets[assetIds[1]].format
           or targetKeys[("music/" .. assignment.target):lower()] then
          return nil, "music-exact-target"
        end
        targetKeys[("music/" .. assignment.target):lower()] = true
        runtime.exactMusic[original] = songs[1]
      elseif assignment.mode == "category-shuffle"
         and MUSIC_CATEGORY[assignment.category] then
        for _, assetId in ipairs(assetIds) do
          local asset = assets[assetId]
          local filename = asset.path:match("([^/]+)$")
          local key = ("music/" .. assignment.category .. "/" .. filename):lower()
          if targetKeys[key] then return nil, "music-target-duplicate" end
          targetKeys[key] = true
        end
        runtime.categoryMusic[assignment.category] = songs
      else
        return nil, "music-assignment-mode"
      end
    else
      if not SPRITE_GROUP[assignment.group]
         or not exactFields(assignment, {
           id=true, group=true, slot=true, asset_id=true, target=true,
         }) then return nil, "sprite-assignment-group" end
      local asset = assets[assignment.asset_id]
      if not asset or asset.id ~= assignment.asset_id or asset.lane ~= "sprites"
         or not asset.assetPath or type(assignment.slot) ~= "string"
         or assignment.slot == "" or type(assignment.target) ~= "string"
         or not safePath(assignment.target)
         or not assignment.target:match("%.png$") then
        return nil, "sprite-assignment"
      end
      local slot, target = assignment.slot, assignment.target
      local stem = target:match("/([A-Z0-9][A-Z0-9_%-]*)%.png$")
      local validTarget = false
      if assignment.group == "pokemon.front" then
        validTarget = target:match("^pokemon/front/") ~= nil and stem == slot
      elseif assignment.group == "pokemon.back" then
        validTarget = target:match("^pokemon/back/") ~= nil and stem == slot
      elseif assignment.group == "pokemon.mega" then
        local view = target:match("^pokemon/([a-z]+)/")
        validTarget = (view == "front" or view == "back") and stem == slot
      elseif assignment.group == "pokemon.retro" then
        local species, side = slot:match("^([A-Z0-9][A-Z0-9_%-]*):([a-z]+)$")
        validTarget = species ~= nil and (side == "front" or side == "back")
          and target:match("^pokemon/" .. side .. "/") ~= nil
      elseif assignment.group == "trainer.player" then
        validTarget = slot == "front" or slot == "back"
          or slot == "battle_front" or slot == "battle_back"
        validTarget = validTarget and target == "player/" .. slot .. ".png"
      elseif assignment.group == "trainer.opponent" then
        validTarget = target:match("^trainers/") ~= nil and stem == slot
      end
      local targetKey = ("sprites/" .. target):lower()
      if not validTarget or targetKeys[targetKey] then
        return nil, "sprite-assignment-target"
      end
      targetKeys[targetKey], referenced[assignment.asset_id] = true, true
      local key = assignment.group .. "|" .. assignment.slot:upper()
      if runtime.sprites[key] then return nil, "sprite-assignment-duplicate" end
      runtime.sprites[key] = asset.assetPath
    end
  end
  if manifest.battle_backgrounds ~= nil then
    local plan, backgroundRefs, backgroundWhy = backgroundPlan(
      manifest.battle_backgrounds, assets)
    if not plan then return nil, backgroundWhy end
    runtime.battleBackgrounds = plan
    for assetId in pairs(backgroundRefs) do
      -- The v1 transport is a dedicated full-frame ARENA lane. Reusing one
      -- asset as a sprite/music assignment would give that same immutable ID
      -- two incompatible runtime meanings and diverge from the selector.
      if referenced[assetId] then return nil, "background-asset-dual-use" end
      referenced[assetId] = true
    end
  end
  for _, raw in ipairs(manifest.assets) do
    if not referenced[raw.id] then return nil, "asset-unassigned" end
  end
  return runtime, pendingMusic
end

local function v2Selections(pointer)
  local out = {{scope="default", selection=pointer.default}}
  for _, scope in ipairs({"gen1", "gen2"}) do
    local selection = pointer.generations[scope]
    if selection ~= nil then
      if type(selection) ~= "table" then return nil, "pointer-fields" end
      out[#out + 1] = {scope=scope, selection=selection}
    end
  end
  for _, scope in ipairs({"red", "blue", "yellow", "gold", "silver", "crystal"}) do
    local selection = pointer.games[scope]
    if selection ~= nil then
      if type(selection) ~= "table" then return nil, "pointer-fields" end
      out[#out + 1] = {scope=scope, selection=selection}
    end
  end
  return out
end

local function referenceKey(reference)
  return table.concat({reference.digest, reference.id, reference.version,
                       reference.baseProfile}, "\0")
end

local function loadReference(reference, manifestCache, runtimeCache)
  local key = referenceKey(reference)
  local cached = runtimeCache[key]
  if cached then return cached.runtime, cached.pending, cached.why end

  local manifestEntry = manifestCache[reference.digest]
  if not manifestEntry then
    local relative = PresetRuntime.ROOT .. "/" .. reference.manifestPath
    local bytes = UserFiles.read(relative, MAX_MANIFEST)
    if not bytes then
      manifestEntry = {why="manifest-missing"}
    elseif UserFiles.sha256(relative, MAX_MANIFEST) ~= reference.digest then
      manifestEntry = {why="manifest-sha256"}
    else
      local manifest, why = ContentJson.decode(bytes)
      manifestEntry = manifest and {manifest=manifest}
        or {why="manifest-json:" .. tostring(why)}
    end
    manifestCache[reference.digest] = manifestEntry
  end
  if manifestEntry.why then
    runtimeCache[key] = {why=manifestEntry.why}
    return nil, nil, manifestEntry.why
  end

  local runtime, pendingOrWhy = buildRuntime(reference, manifestEntry.manifest)
  cached = runtime and {runtime=runtime, pending=pendingOrWhy}
    or {why=tostring(pendingOrWhy)}
  runtimeCache[key] = cached
  return cached.runtime, cached.pending, cached.why
end

local function registryRegistrations(registry)
  local stores = fallbackMusicRegistries
  if type(processGuard) == "table" then
    if type(processGuard.musicRegistries) ~= "table" then
      processGuard.musicRegistries = setmetatable({}, {__mode="k"})
    end
    stores = processGuard.musicRegistries
  end
  local seen = stores[registry]
  if not seen then
    seen = {}
    stores[registry] = seen
  end
  return seen
end

local function commitMusic(pendingMusic, mod)
  if type(pendingMusic) ~= "table" or #pendingMusic == 0 then return true end
  local registry = mod and mod.content and mod.content.music
  if not (registry and type(registry.register) == "function") then
    return nil, "music-registry-missing"
  end
  if type(registry.remove) ~= "function" then
    return nil, "music-registry-rollback-missing"
  end
  local seen, additions = registryRegistrations(registry), {}
  for _, pending in ipairs(pendingMusic) do
    if not seen[pending.id] then
      if type(registry.get) == "function" then
        local ok, existing = pcall(registry.get, registry, pending.id)
        if not ok then return nil, "music-registry-probe" end
        if existing ~= nil then return nil, "music-register-collision" end
      end
      additions[#additions + 1] = pending
    end
  end

  local committed = {}
  for _, pending in ipairs(additions) do
    local ok = pcall(registry.register, registry, pending.id,
                     {file=pending.file})
    if not ok then
      -- The registry has no one-call transaction, so compensate every
      -- completed write through its required remove() operation.  All content
      -- validation and collision probes ran before this narrow commit window.
      local rollbackFailed = false
      for at = #committed, 1, -1 do
        local removed = pcall(registry.remove, registry, committed[at])
        if removed then
          seen[committed[at]] = nil
        else
          rollbackFailed = true
        end
      end
      if rollbackFailed then
        packageRestartLatched = true
        if type(processGuard) == "table" then
          processGuard.blocked, processGuard.verified = true, false
        end
        return nil, "music-register-rollback", true
      end
      return nil, "music-register"
    end
    seen[pending.id] = true
    committed[#committed + 1] = pending.id
  end
  return true
end

local function scan(mod, rescan)
  local nextState = cleanState("pointer-missing")
  local pointerBytes, pointerWhy = UserFiles.read(
    PresetRuntime.ROOT .. "/active.json", MAX_POINTER)
  local observedPointer = pointerBytes or false
  if rescan and installed and pointerSnapshot ~= nil
     and pointerSnapshot ~= observedPointer then
    state.restartRequired = true
    state.restartReason = "active-preset-changed"
    state.packageReceiptVerified = packageReceiptVerified
    return state
  end
  pointerSnapshot = observedPointer
  if not pointerBytes then
    local why = tostring(pointerWhy or "")
    nextState.reason = why:find("unavailable", 1, true)
      and "reader-unavailable" or "pointer-missing"
    state = nextState
    return state
  end
  local pointer, decodeWhy = ContentJson.decode(pointerBytes)
  if not pointer then nextState.reason = "pointer-json:" .. tostring(decodeWhy)
    state = nextState return state end
  local selection, scope, generation, game = chooseSelection(pointer)
  nextState.scope, nextState.generation, nextState.game = scope, generation, game
  if not selection then nextState.reason = tostring(scope)
    state = nextState return state end
  local function authenticatePackage()
    if packageSafe(mod) then
      nextState.packageReceiptVerified = packageReceiptVerified
      return true
    end
    local blocked = cleanState("package-restart-required")
    blocked.restartRequired = true
    blocked.restartReason = "lua-or-package-hash-changed"
    state = blocked
    return false
  end
  local manifestCache, runtimeCache = {}, {}
  local runtime, pendingMusic, reference
  if pointer.schema == PresetRuntime.POINTER_V2 then
    local selections, selectionsWhy = v2Selections(pointer)
    if not selections then nextState.reason = tostring(selectionsWhy)
      state = nextState return state end
    -- Validate every scope reference before trusting the selected CUSTOM
    -- base.  A structurally invalid pointer must fall straight to VASC
    -- DEFAULT; only a complete reference may carry its declared RETRO or
    -- VASC DEFAULT base into later manifest/asset failure handling.
    local validated = {}
    for _, item in ipairs(selections) do
      local itemReference, referenceWhy = pointerReference(item.selection)
      if itemReference == nil then nextState.reason = tostring(referenceWhy)
        state = nextState return state end
      validated[item.selection] = {reference=itemReference}
    end
    local selected = validated[selection]
    if not selected then nextState.reason = "selection-missing"
      state = nextState return state end
    if selected.reference == false then
      nextState.reason = "scope-default"
      state = nextState
      return state
    end
    if selected.reference then
      nextState.baseProfile = selected.reference.baseProfile
    end
    -- Authenticating all packaged Lua is intentionally deferred until a
    -- CUSTOM selection is about to consume it. VASC DEFAULT has no imported
    -- content to trust, so hashing hundreds of files on the UI thread only
    -- stalls mobile startup without protecting anything.
    if not authenticatePackage() then return state end
    for _, item in ipairs(selections) do
      local record = validated[item.selection]
      if record.reference then
        record.runtime, record.pending, record.why = loadReference(
          record.reference, manifestCache, runtimeCache)
        if not record.runtime then nextState.reason = tostring(record.why)
          state = nextState return state end
      end
    end
    reference, runtime, pendingMusic = selected.reference,
      selected.runtime, selected.pending
  else
    local referenceWhy
    reference, referenceWhy = pointerReference(selection)
    if reference == nil then nextState.reason = tostring(referenceWhy)
      state = nextState return state end
    if reference then
      nextState.baseProfile = reference.baseProfile
      if not authenticatePackage() then return state end
      runtime, pendingMusic, referenceWhy = loadReference(
        reference, manifestCache, runtimeCache)
      if not runtime then nextState.reason = tostring(referenceWhy)
        state = nextState return state end
    end
  end
  if reference == false then nextState.reason = "scope-default"
    state = nextState return state end
  nextState.baseProfile = reference.baseProfile
  local committed, commitWhy, commitRestart = commitMusic(pendingMusic, mod)
  if not committed then nextState.reason = tostring(commitWhy)
    if commitRestart then
      nextState.restartRequired = true
      nextState.restartReason = "music-registry-rollback-failed"
    end
    state = nextState return state end
  runtime.scope, runtime.generation, runtime.game = scope, generation, game
  state = runtime
  return state
end

local function sprite(runtime, group, slot)
  return runtime.sprites[group .. "|" .. tostring(slot or ""):upper()]
end

function PresetRuntime.resolveSprite(kind, current, ctx)
  if not state.valid or type(ctx) ~= "table" then return current end
  local result
  if kind == "pokemon" then
    local side = ctx.side == "back" and "back" or "front"
    if ctx.formId then result = sprite(state, "pokemon.mega", ctx.formId) end
    result = result or sprite(state, "pokemon." .. side, ctx.species)
      or sprite(state, "pokemon.retro", tostring(ctx.species) .. ":" .. side)
  elseif kind == "player" then
    local side = ctx.side == "back" and "back" or "front"
    local slot = ctx.kind == "battle" and "battle_" .. side or side
    result = sprite(state, "trainer.player", slot)
  elseif kind == "trainer" then
    result = sprite(state, "trainer.opponent", ctx.trainerId)
  end
  return result or current
end

local function arenaContext(ctx)
  if type(ctx) ~= "table" or ctx.presentationMode ~= "ARENA"
     or type(ctx.authoredBackdropExists) ~= "boolean" then
    return nil
  end
  local generation = type(ctx.generation) == "string"
    and ctx.generation:lower() or nil
  local game = type(ctx.game) == "string" and ctx.game:lower() or nil
  if (generation ~= "gen1" and generation ~= "gen2")
     or GAME_GENERATION[game] ~= generation
     or generation ~= state.generation or game ~= state.game
     or not matchId(ctx.route_or_map) then
    return nil
  end
  local result = {
    generation=generation, game=game, route_or_map=ctx.route_or_map,
  }
  if ctx.battle_kind ~= nil then
    local kind = type(ctx.battle_kind) == "string"
      and ctx.battle_kind:lower() or nil
    if not BATTLE_KINDS[kind] then return nil end
    result.battle_kind = kind
  end
  for _, key in ipairs({"trainer_id", "battle_id"}) do
    local value = ctx[key]
    if value ~= nil then
      if not matchId(value) then return nil end
      result[key] = value
    end
  end
  if result.battle_kind == "wild" and result.trainer_id ~= nil then return nil end
  local token = ctx.battleToken
  if type(token) == "number" then
    if token < 1 or token ~= math.floor(token) then return nil end
    token = tostring(token)
  elseif type(token) ~= "string" or token == "" or #token > 512
      or token:find("[%z\1-\31\127]") then
    return nil
  end
  return result, token
end

local function matchArenaRule(rule, ctx)
  for key, expected in pairs(rule.match) do
    local actual = ctx[key]
    if type(actual) ~= "string" or actual:lower() ~= expected:lower() then
      return false
    end
  end
  return true
end

local function specificity(rule)
  local match = rule.match
  local battle = match.battle_id and 1 or 0
  local trainer = match.trainer_id and 1 or 0
  local kind = match.battle_kind and 1 or 0
  return battle + trainer + kind, battle, trainer, kind
end

local function preferredArenaRule(candidate, current)
  if not current then return true end
  local a1, a2, a3, a4 = specificity(candidate)
  local b1, b2, b3, b4 = specificity(current)
  if a1 ~= b1 then return a1 > b1 end
  if a2 ~= b2 then return a2 > b2 end
  if a3 ~= b3 then return a3 > b3 end
  if a4 ~= b4 then return a4 > b4 end
  return candidate.id < current.id
end

local function shuffledArenaCandidate(rule, planDigest, identity)
  if rule.selection.mode == "first" then return rule.candidates[1] end
  local digest = sha256Bytes(table.concat({
    rule.selection.seed, planDigest, rule.id, identity,
  }, "\0"))
  if not digest then return nil end
  -- uint64_be modulo candidate_count without converting the 64-bit prefix to
  -- a Lua number (whose IEEE-754 mantissa would lose deterministic bits).
  local remainder = 0
  for at = 1, 8 do
    remainder = (remainder * 256 + digest:byte(at)) % #rule.candidates
  end
  return rule.candidates[remainder + 1]
end

-- Resolve exactly once for one battle owner. This function cannot change a
-- presentation provider: every non-ARENA context returns nil before consulting
-- or populating the owner cache.  Once ARENA asks, both a choice and nil are
-- first-call-wins until exact finish; a later forged token/context therefore
-- cannot reroll a live battle.
function PresetRuntime.resolveArenaBackdrop(owner, ctx)
  local ownerKind = type(owner)
  if ownerKind ~= "table" and ownerKind ~= "userdata" then return nil end
  if not state.valid or type(state.battleBackgrounds) ~= "table" then return nil end
  if type(ctx) ~= "table" or ctx.presentationMode ~= "ARENA" then return nil end
  local cached = backgroundSelections[owner]
  if type(cached) == "table" then
    return cached.choice ~= NO_BACKGROUND and cached.choice or nil
  end
  local context, identity = arenaContext(ctx)
  if not context then
    backgroundSelections[owner] = {choice=NO_BACKGROUND}
    return nil
  end

  local plan, selectedRule = state.battleBackgrounds, nil
  for _, rule in ipairs(plan.rules) do
    if matchArenaRule(rule, context) and preferredArenaRule(rule, selectedRule) then
      selectedRule = rule
    end
  end
  local choice = NO_BACKGROUND
  if selectedRule
     and ((selectedRule.action == "add" and not ctx.authoredBackdropExists)
       or (selectedRule.action == "replace" and ctx.authoredBackdropExists)) then
    local candidate = shuffledArenaCandidate(selectedRule, plan.digest, identity)
    if candidate and candidate._assetPath and candidate._relativePath
       and BACKGROUND_DIMENSIONS[
         tostring(candidate._width) .. "x" .. tostring(candidate._height)] then
      choice = {
        action=selectedRule.action,
        assetId=candidate.asset_id,
        digest=candidate.sha256,
        height=candidate._height,
        planDigest=plan.digest,
        ruleId=selectedRule.id,
        size=candidate.size_bytes,
        slot=BATTLE_BACKGROUND_SLOT,
        surface=BATTLE_BACKGROUND_SURFACE,
        width=candidate._width,
      }
      backgroundChoiceReceipts[choice] = {
        action=choice.action, assetId=choice.assetId, digest=choice.digest,
        height=choice.height, path=candidate._assetPath,
        planDigest=choice.planDigest, relativePath=candidate._relativePath,
        ruleId=choice.ruleId, size=choice.size, width=choice.width,
      }
    end
  end
  backgroundSelections[owner] = {choice=choice}
  return choice ~= NO_BACKGROUND and choice or nil
end

-- The stage asks for this receipt immediately before decoding/uploading the
-- selected PNG.  Rechecking the immutable file here makes a post-scan missing,
-- changed or truncated asset fail closed to VASC's authored ARENA result.
function PresetRuntime.arenaBackdropAsset(choice)
  local receipt = type(choice) == "table" and backgroundChoiceReceipts[choice]
  if not receipt
     or choice.surface ~= BATTLE_BACKGROUND_SURFACE
     or choice.slot ~= BATTLE_BACKGROUND_SLOT
     or choice.action ~= receipt.action or choice.assetId ~= receipt.assetId
     or choice.digest ~= receipt.digest or choice.size ~= receipt.size
     or choice.width ~= receipt.width or choice.height ~= receipt.height
     or choice.planDigest ~= receipt.planDigest or choice.ruleId ~= receipt.ruleId
     or not BACKGROUND_DIMENSIONS[
       tostring(receipt.width) .. "x" .. tostring(receipt.height)] then
    return nil
  end
  local info = UserFiles.info(receipt.relativePath, "file")
  if not info or tonumber(info.size) ~= receipt.size
     or UserFiles.sha256(receipt.relativePath, MAX_BACKGROUND_ASSET)
       ~= receipt.digest then
    return nil
  end
  local bytes = UserFiles.read(receipt.relativePath, MAX_BACKGROUND_ASSET)
  if not bytes or #bytes ~= receipt.size or not validMedia("png", bytes)
     or u32(bytes, 17) ~= receipt.width or u32(bytes, 21) ~= receipt.height then
    return nil
  end
  local path = UserFiles.path(receipt.relativePath)
  if type(path) ~= "string" or path == "" or path ~= receipt.path then return nil end
  return {
    digest=receipt.digest, height=receipt.height, path=path,
    size=receipt.size, width=receipt.width,
  }
end

function PresetRuntime.finishArenaBackdrop(owner)
  local ownerKind = type(owner)
  if ownerKind ~= "table" and ownerKind ~= "userdata" then return false end
  local cached = backgroundSelections[owner]
  if cached == nil then return false end
  local choice = type(cached) == "table" and cached.choice or nil
  backgroundSelections[owner] = nil
  if type(choice) == "table" and choice ~= NO_BACKGROUND then
    backgroundChoiceReceipts[choice] = nil
  end
  return true
end

local function hash(value)
  local out = 2166136261
  for at = 1, #value do out = (out * 16777619 + value:byte(at)) % 2147483647 end
  return out
end

function PresetRuntime.resolveMusic(current, ctx, category)
  if not state.valid or type(current) ~= "string" then return current end
  local exact = state.exactMusic[current]
  if exact then return exact end
  local list = category and state.categoryMusic[category] or nil
  if type(list) ~= "table" or #list == 0 then return current end
  if type(ctx) == "table" and ctx.reason == "battle" and battleMusic then
    return battleMusic
  end
  local token = tostring(category) .. "|" .. tostring(ctx and ctx.mapId or "")
    .. "|" .. tostring(ctx and ctx.trainerId or "") .. "|" .. tostring(serial)
  local at = hash(token) % #list + 1
  if #list > 1 and list[at] == lastMusic[category] then at = at % #list + 1 end
  local song = list[at]
  lastMusic[category] = song
  if type(ctx) == "table" and ctx.reason == "battle" then battleMusic = song end
  return song
end

function PresetRuntime.finish()
  battleMusic, serial = nil, serial + 1
end

function PresetRuntime.install(mod)
  installed = true
  return scan(mod, false)
end
function PresetRuntime.rescan(mod) return scan(mod, true) end
function PresetRuntime.status()
  local out = {
    apiVersion=PresetRuntime.API_VERSION, valid=state.valid, mode=state.mode,
    reason=state.reason, scope=state.scope, generation=state.generation,
    game=state.game, baseProfile=state.baseProfile,
    restartRequired=state.restartRequired == true,
    restartReason=state.restartReason,
    packageReceiptVerified=state.packageReceiptVerified == true,
  }
  if state.preset then
    out.preset = {id=state.preset.id, version=state.preset.version,
                  digest=state.preset.digest}
  end
  return out
end

return PresetRuntime
