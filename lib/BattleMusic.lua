-- Optional battle-music packs. Voxel Ascendant ships no music and performs
-- no network download: a separately installed mod owns and registers its
-- audio files in the engine music registry, then contributes only those song
-- IDs here. Missing, malformed or unloaded packs are an exact pass-through to
-- the game's original music.

local V = ...
local ModSetting = V.require("ModSetting")

local BattleMusic = {}

BattleMusic.API_VERSION = 1
BattleMusic.KEY = "battleMusicMode"
BattleMusic.setting = ModSetting.new(
  BattleMusic.KEY, "BTL MUSIC",
  { "original", "shuffle", "gen2", "gen3", "gen4", "gen5", "gen6" },
  { "ORIGINAL", "SHUFFLE", "GEN 2", "GEN 3", "GEN 4", "GEN 5", "GEN 6" },
  "original")

local packs, order = {}, {}
local activeChoice, lastChoice = nil, nil
local battleSerial = 0

local SCOPES = { wild=true, trainer=true, gym=true, league=true }
local LEAGUE_TRAINERS = {
  OPP_LORELEI=true, OPP_BRUNO=true, OPP_AGATHA=true, OPP_LANCE=true,
  OPP_RIVAL3=true,
  KA_JOHTO_SILVER=true, KA_JOHTO_KRIS=true, KA_JOHTO_GOLD=true,
}

local function validId(value)
  return type(value) == "string" and value ~= ""
         and value:match("^[A-Za-z0-9_.%-]+$") ~= nil
end

local function https(value)
  return type(value) == "string" and value:match("^https://[^%s]+$") ~= nil
end

local function validHash(value)
  return type(value) == "string" and #value == 64
         and value:match("^[0-9a-fA-F]+$") ~= nil
end

local function songAvailable(id)
  local registry = V.mod and V.mod.content and V.mod.content.music
  if not registry or type(registry.get) ~= "function" then return false end
  local ok, def = pcall(registry.get, registry, id)
  return ok and type(def) == "table"
         and (def.file ~= nil or def.chip ~= nil
              or (def.address ~= nil and def.bank ~= nil))
end

local function validScopes(scopes)
  if type(scopes) ~= "table" then return false end
  local found = false
  for name, enabled in pairs(scopes) do
    if not SCOPES[name] or type(enabled) ~= "boolean" then return false end
    found = found or enabled
  end
  return found
end

local function copyTrack(track, owner)
  if type(track) ~= "table" or not validId(track.id)
     or type(track.generation) ~= "number"
     or track.generation ~= math.floor(track.generation)
     or track.generation < 2 or track.generation > 6
     or not validScopes(track.scopes)
     or not songAvailable(track.id) then
    return nil
  end
  return {
    id=track.id, generation=track.generation, owner=owner,
    label=type(track.label) == "string" and track.label or track.id,
    scopes={
      wild=track.scopes.wild and true or false,
      trainer=track.scopes.trainer and true or false,
      gym=track.scopes.gym and true or false,
      league=track.scopes.league and true or false,
    },
  }
end

local function inventory()
  local out = {}
  for _, packId in ipairs(order) do
    local pack = packs[packId]
    if pack then
      for _, track in ipairs(pack.tracks) do
        if songAvailable(track.id) then out[#out + 1] = track end
      end
    end
  end
  table.sort(out, function(a, b)
    if a.generation ~= b.generation then return a.generation < b.generation end
    if a.owner ~= b.owner then return a.owner < b.owner end
    return a.id < b.id
  end)
  return out
end

local function modeGeneration(mode)
  local n = type(mode) == "string" and mode:match("^gen([2-6])$")
  return n and tonumber(n) or nil
end

local function modeAvailable(mode)
  if mode == "original" then return true end
  local generation = modeGeneration(mode)
  for _, track in ipairs(inventory()) do
    if mode == "shuffle" or track.generation == generation then return true end
  end
  return false
end

BattleMusic.setting:setGate(modeAvailable)

function BattleMusic.register(pack)
  if type(pack) ~= "table" or not validId(pack.id) or packs[pack.id]
     or type(pack.label) ~= "string" or pack.label == ""
     or type(pack.version) ~= "string" or pack.version == ""
     or not https(pack.sourceUrl) or not validHash(pack.sha256)
     or pack.userConfirmed ~= true or pack.separateInstall ~= true
     or type(pack.tracks) ~= "table" or #pack.tracks < 1 then
    return nil, "invalid or duplicate battle-music pack receipt"
  end
  local tracks, seen = {}, {}
  for _, candidate in ipairs(pack.tracks) do
    local track = copyTrack(candidate, pack.id)
    if not track or seen[track.id] then
      return nil, "invalid, duplicate or unregistered battle-music track"
    end
    seen[track.id] = true
    tracks[#tracks + 1] = track
  end
  local receipt = {
    id=pack.id, label=pack.label, version=pack.version,
    sourceUrl=pack.sourceUrl, sha256=string.lower(pack.sha256), tracks=tracks,
  }
  packs[pack.id] = receipt
  order[#order + 1] = pack.id
  table.sort(order)
  return function()
    if packs[pack.id] ~= receipt then return false end
    packs[pack.id] = nil
    for i = #order, 1, -1 do
      if order[i] == pack.id then table.remove(order, i) break end
    end
    if activeChoice and activeChoice.owner == pack.id then activeChoice = nil end
    return true
  end
end

local function scopeFor(ctx)
  local kind = ctx and (ctx.battleKind or ctx.kind)
  local trainerId = ctx and ctx.trainerId
  if kind == "final" or LEAGUE_TRAINERS[trainerId] then return "league" end
  if kind == "gym" then return "gym" end
  if kind == "trainer" then return "trainer" end
  if kind == "wild" or kind == "safari" or kind == "ghost"
     or kind == "oldman" then return "wild" end
  return nil
end

local function hashContext(ctx, scope)
  local value = tostring(scope) .. "|" .. tostring(ctx and ctx.trainerId or "")
                .. "|" .. tostring(battleSerial)
  local hash = 2166136261
  for i = 1, #value do
    hash = (hash * 16777619 + value:byte(i)) % 2147483647
  end
  return hash
end

local function candidates(mode, scope)
  local out, generation = {}, modeGeneration(mode)
  for _, track in ipairs(inventory()) do
    if track.scopes[scope]
       and (mode == "shuffle" or track.generation == generation) then
      out[#out + 1] = track
    end
  end
  return out
end

function BattleMusic.resolve(chosen, ctx)
  if type(ctx) ~= "table" or ctx.reason ~= "battle" then return chosen end
  local mode = BattleMusic.setting:get()
  if mode == "original" then return chosen end
  local scope = scopeFor(ctx)
  if not scope then return chosen end

  -- Music.playBattle is intentionally called before the wipe and once more
  -- on BattleState:enter. The first result owns the whole fight.
  if activeChoice then
    return songAvailable(activeChoice.id) and activeChoice.id or chosen
  end

  local available = candidates(mode, scope)
  if #available == 0 then return chosen end
  local at = (hashContext(ctx, scope) % #available) + 1
  if #available > 1 and available[at].id == lastChoice then
    at = (at % #available) + 1
  end
  activeChoice = available[at]
  return activeChoice.id
end

function BattleMusic.finish()
  if activeChoice then lastChoice = activeChoice.id end
  activeChoice = nil
  battleSerial = battleSerial + 1
end

function BattleMusic.install(mod)
  if type(mod) ~= "table" or type(mod.hooks) ~= "table"
     or type(mod.hooks.wrap) ~= "function" then return false end
  mod.hooks:wrap("music.select", function(next, chosen, ctx)
    return next(BattleMusic.resolve(chosen, ctx), ctx)
  end)
  return true
end

function BattleMusic.list()
  local out = {}
  for _, packId in ipairs(order) do
    local pack = packs[packId]
    if pack then
      local generations = {}
      for _, track in ipairs(pack.tracks) do generations[track.generation] = true end
      out[#out + 1] = {
        id=pack.id, label=pack.label, version=pack.version,
        sourceUrl=pack.sourceUrl, sha256=pack.sha256,
        tracks=#pack.tracks, generations=generations,
      }
    end
  end
  return out
end

function BattleMusic.public()
  return {
    apiVersion=BattleMusic.API_VERSION,
    register=BattleMusic.register,
    list=BattleMusic.list,
    requirements={
      separateMod=true, explicitUserInstall=true, userConfirmed=true,
      registeredEngineSongs=true, bundledAudio=false, networkDownloads=false,
      liveActivation=true,
    },
  }
end

return BattleMusic
