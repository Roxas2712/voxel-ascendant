-- Install the supplied VASC PBAnimation programs without changing the battle
-- rules. Gen-I moves always receive their VASC replacement. Programs for
-- later-generation move ids are visible only while Kanto Ascendant is an
-- active mod, so VASC by itself never leaks a foreign move set into Kanto.

local V = ...
local BattleAnimationCompat = {}
local lastReceipt = { installed=false, reason="not-installed" }

-- Native Gen-I effects/sounds used while a full-color VASC sheet is on top.
-- The table also covers every current KASC move whose supplied collection has
-- no exact program, preserving audio and coarse screen effects as fallback.
BattleAnimationCompat.ALIASES = {
  CRUNCH = "BITE",
  METAL_CLAW = "SLASH",
  IRON_TAIL = "SLAM",
  SHADOW_BALL = "PSYCHIC_M",
  FLAME_WHEEL = "FIRE_SPIN",
  GIGA_DRAIN = "MEGA_DRAIN",
  SLUDGE_BOMB = "SLUDGE",
  SPARK = "THUNDER_SHOCK",
  POWDER_SNOW = "BLIZZARD",
  SACRED_FIRE = "FIRE_BLAST",
  AEROBLAST = "SKY_ATTACK",
  FRENZY_PLANT = "PETAL_DANCE",
  BLAST_BURN = "FIRE_BLAST",
  HYDRO_CANNON = "HYDRO_PUMP",
}

-- The supplied collection has dedicated programs for eight KASC moves. The
-- remaining six deliberately use the closest complete VASC program rather
-- than falling back to a tiny native Gen-I tile effect.
BattleAnimationCompat.PROGRAM_ALIASES = {
  IRON_TAIL = "SLAM",
  SPARK = "THUNDERSHOCK",
  POWDER_SNOW = "ICYWIND",
  SACRED_FIRE = "FIREBLAST",
  AEROBLAST = "AERIALACE",
  HYDRO_CANNON = "HYDROPUMP",
}

-- Essentials omits separators; most engine ids resolve by compact form.
-- These two are historical Pokémon Red identifier spellings rather than
-- separator differences and therefore need an explicit bridge.
local NAME_OVERRIDES = {
  PSYCHIC = "PSYCHIC_M",
  HIGHJUMPKICK = "HI_JUMP_KICK",
}

-- Gen1's current animation start seam supplies only move id and attacking
-- side.  Preserve that public boundary and derive presentation ownership from
-- the immutable ROM move definition while building the registry.  Draining
-- attacks are intentionally absent: their authored target-to-user path must
-- retain both endpoints.
local SELF_EFFECTS = {
  HEAL_EFFECT=true,
  LIGHT_SCREEN_EFFECT=true,
  REFLECT_EFFECT=true,
  MIST_EFFECT=true,
  FOCUS_ENERGY_EFFECT=true,
  CONVERSION_EFFECT=true,
  SUBSTITUTE_EFFECT=true,
  SPLASH_EFFECT=true,
  METRONOME_EFFECT=true,
  MIRROR_MOVE_EFFECT=true,
  BIDE_EFFECT=true,
}

local function targetMode(moveId, def)
  if moveId == "FLY" then return "self-then-foe" end
  if moveId == "TELEPORT" then return "self" end
  if type(def) ~= "table" then return "foe" end
  local effect = tostring(def.effect or "")
  if SELF_EFFECTS[effect] then return "self" end
  if tonumber(def.power) == 0 and effect:match("_UP[12]_EFFECT$") then
    return "self"
  end
  return "foe"
end

local function compact(value)
  return tostring(value or ""):upper():gsub("[^A-Z0-9]", "")
end

local function kascActive(mod)
  if type(V) == "table" and type(V.require) == "function" then
    local ok, compat = pcall(V.require, "KantoAscendantCompat")
    if ok and compat and type(compat.active) == "function" then
      local active = compat.active(mod)
      return active == true
    end
  end
  if type(mod) ~= "table" or type(mod.find) ~= "function" then return false end
  for _, id in ipairs({ "kanto_ascendant", "trainer_rematch" }) do
    local ok, handle = pcall(mod.find, id)
    if ok and type(handle) == "table" then return true end
  end
  return false
end

local function isGenOne(def)
  if type(def) ~= "table" then return false end
  local index = tonumber(def.index)
  if index and index >= 1 and index <= 165 then return true end
  return tostring(def.source or ""):match("^ROM:") ~= nil
end

local function catalogFromV()
  if type(V) ~= "table" or type(V.data) ~= "function" then return nil end
  local ok, data = pcall(V.data, "vasc_battle_animations")
  return ok and data or nil
end

local function playerFromV()
  if type(V) ~= "table" or type(V.require) ~= "function" then return nil end
  local ok, player = pcall(V.require, "VascBattleAnimPlayer")
  return ok and player or nil
end

function BattleAnimationCompat.registry(game, catalog, activeKasc)
  local data = game and game.data or {}
  local moves = type(data.moves) == "table" and data.moves or {}
  local native = data.battle_anims and data.battle_anims.moveAnims or {}
  local byCompact = {}
  for moveId in pairs(moves) do
    local key = compact(moveId)
    if byCompact[key] == nil then byCompact[key] = moveId end
  end

  local registry = {
    programs={}, nativeSources={}, targetModes={},
    kasc=activeKasc and true or false,
    gen1Count=0, kascCount=0, aliasCount=0,
  }
  -- Native animation data is only a companion layer for sounds/coarse screen
  -- effects while VASC paints the full-colour program.  Keep one known-safe
  -- named fallback, but never manufacture a numeric/index-equivalent lookup
  -- for an optional move whose native alias is absent.
  for _, candidate in ipairs({ "TACKLE", "POUND", "SCRATCH" }) do
    if native[candidate] ~= nil then
      registry.defaultNativeSource = candidate
      break
    end
  end
  for programKey, program in pairs(catalog and catalog.programs or {}) do
    local explicit = NAME_OVERRIDES[programKey]
    local moveId = explicit and moves[explicit] and explicit
                   or byCompact[compact(programKey)]
    local def = moveId and moves[moveId]
    local gen1 = isGenOne(def)
    if moveId and (gen1 or activeKasc) then
      registry.programs[moveId] = program
      registry.targetModes[moveId] = targetMode(moveId, def)
      if gen1 then registry.gen1Count = registry.gen1Count + 1
      else registry.kascCount = registry.kascCount + 1 end
    end
  end

  if activeKasc then
    for moveId, programKey in pairs(BattleAnimationCompat.PROGRAM_ALIASES) do
      if moves[moveId] and not registry.programs[moveId] then
        local program = catalog and catalog.programs
                        and catalog.programs[programKey]
        if program then
          registry.programs[moveId] = program
          registry.targetModes[moveId] = targetMode(moveId, moves[moveId])
          registry.kascCount = registry.kascCount + 1
          registry.aliasCount = registry.aliasCount + 1
        end
      end
    end
  end

  for moveId in pairs(registry.programs) do
    local source = BattleAnimationCompat.ALIASES[moveId]
    if native[moveId] ~= nil then
      registry.nativeSources[moveId] = moveId
    elseif source and native[source] ~= nil then
      registry.nativeSources[moveId] = source
    end
  end
  return registry
end

local function installNativeAliases(game, activeKasc)
  local data = game and game.data or {}
  local moves = data.battle_anims and data.battle_anims.moveAnims
  local moveDefs = data.moves
  if type(moves) ~= "table" or type(moveDefs) ~= "table"
      or not activeKasc then return 0, 0 end
  local installed, missing = 0, 0
  for move, source in pairs(BattleAnimationCompat.ALIASES) do
    -- A KASC generation-gated id must exist in the merged move registry. This
    -- prevents aliases from manufacturing unavailable move ids in VASC-only
    -- games and also allows future KASC revisions to remove one cleanly.
    if moveDefs[move] and moves[move] == nil then
      if moves[source] ~= nil then
        moves[move] = moves[source]
        installed = installed + 1
      else
        missing = missing + 1
      end
    end
  end
  return installed, missing
end

function BattleAnimationCompat.install(game, mod, opts)
  opts = opts or {}
  local catalog = opts.catalog or catalogFromV()
  local player = opts.player or playerFromV()
  if type(catalog) ~= "table" or type(catalog.programs) ~= "table"
      or type(player) ~= "table" or type(player.install) ~= "function" then
    lastReceipt = { installed=false, reason="catalog-or-player-missing" }
    return 0, 0, lastReceipt
  end
  local activeKasc = opts.kasc
  if activeKasc == nil then activeKasc = kascActive(mod) end
  local installed, missing = installNativeAliases(game, activeKasc)
  local registry = BattleAnimationCompat.registry(game, catalog, activeKasc)
  local called, result = pcall(player.install, catalog, registry)
  local ok = called and result and true or false
  lastReceipt = {
    installed=ok,
    reason=ok and nil or (called and "animation-factory-conflict"
      or ("player-install-error:" .. tostring(result))),
    kasc=activeKasc and true or false,
    gen1=registry.gen1Count,
    postGen=registry.kascCount,
    programAliases=registry.aliasCount,
    missingNativeAliases=missing,
    sourceSha256=catalog.sourceSha256,
  }
  return installed, missing, lastReceipt
end

-- Read-only receipt for the in-game VASC hub and QA.  Returning a copy keeps
-- menu code from mutating the install state while still making it obvious
-- whether KASC's post-Gen-I programs were present at the last refresh.
function BattleAnimationCompat.status()
  local out = {}
  for key, value in pairs(lastReceipt) do out[key] = value end
  return out
end

BattleAnimationCompat.compact = compact
BattleAnimationCompat.isGenOne = isGenOne
BattleAnimationCompat.kascActive = kascActive
BattleAnimationCompat.targetMode = targetMode

return BattleAnimationCompat
