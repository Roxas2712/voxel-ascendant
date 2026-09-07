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

-- Native moves whose supplied collection uses a different program name.
-- These aliases are generation-independent: PSYBEAM is a legal Gen-I move
-- and must not fall back to the cartridge effect merely because the authored
-- collection calls the reusable full-colour program PSYCHIC.
BattleAnimationCompat.NATIVE_PROGRAM_ALIASES = {
  VICEGRIP = "CRUSHCLAW",
  GUILLOTINE = "XSCISSOR",
  RAZOR_WIND = "AERIALACE",
  HORN_DRILL = "HORNATTACK",
  TAKE_DOWN = "BODYSLAM",
  THRASH = "OUTRAGE",
  SONICBOOM = "SIGNALBEAM",
  SURF = "WATERPULSE",
  ICE_BEAM = "AURORABEAM",
  BLIZZARD = "ICYWIND",
  PSYBEAM = "PSYCHIC",
  HYPER_BEAM = "SIGNALBEAM",
  PECK = "FURYATTACK",
  DRILL_PECK = "AERIALACE",
  SUBMISSION = "LOWKICK",
  SEISMIC_TOSS = "BODYSLAM",
  STRENGTH = "MEGAPUNCH",
  GROWTH = "TAILGLOW",
  SOLARBEAM = "ENERGYBALL",
  EARTHQUAKE = "SANDSTORM",
  FISSURE = "SANDSTORM",
  DIG = "SANDATTACK",
  CONFUSION = "PSYCHIC",
  HYPNOSIS = "SLEEPPOWDER",
  MEDITATE = "BULKUP",
  RAGE = "OUTRAGE",
  NIGHT_SHADE = "SHADOWBALL",
  MIMIC = "SKETCH",
  DOUBLE_TEAM = "AGILITY",
  RECOVER = "MORNINGSUN",
  MINIMIZE = "ACUPRESSURE",
  WITHDRAW = "DEFENSECURL",
  HAZE = "CLEARSMOG",
  BIDE = "FOCUSENERGY",
  MIRROR_MOVE = "MAGICCOAT",
  EGG_BOMB = "EXPLOSION",
  BONE_CLUB = "ROCKTHROW",
  WATERFALL = "HYDROPUMP",
  CLAMP = "BIND",
  SKULL_BASH = "HEADBUTT",
  CONSTRICT = "WRAP",
  SOFTBOILED = "MORNINGSUN",
  DREAM_EATER = "MEGADRAIN",
  BARRAGE = "SPIKECANNON",
  SKY_ATTACK = "AERIALACE",
  TRANSFORM = "ALLYSWITCH",
  PSYWAVE = "PSYCHIC",
  CRABHAMMER = "CRUSHCLAW",
  BONEMERANG = "ROCKTHROW",
  ROCK_SLIDE = "ROCKTHROW",
  SHARPEN = "SWORDSDANCE",
  CONVERSION = "TRICKROOM",
  TRI_ATTACK = "SWIFT",
  SUPER_FANG = "BITE",
  SUBSTITUTE = "FOLLOWME",
  -- Gen-II cartridge ids without an identically named authored sheet.  These
  -- are deliberate semantic fallbacks, not native/vanilla escapes: both the
  -- Kanto and Johto packages keep a complete 1-251 VASC route table.
  TRIPLE_KICK = "ROLLINGKICK",
  THIEF = "BITE",
  MIND_READER = "LOCKON",
  SNORE = "ROAR",
  CONVERSION2 = "TRICKROOM",
  REVERSAL = "COUNTER",
  SPITE = "GRUDGE",
  PROTECT = "DETECT",
  FAINT_ATTACK = "BITE",
  BELLY_DRUM = "BULKUP",
  MUD_SLAP = "SANDATTACK",
  OCTAZOOKA = "WATERPULSE",
  DESTINY_BOND = "GRUDGE",
  PERISH_SONG = "SING",
  BONE_RUSH = "FURYATTACK",
  ENDURE = "HARDEN",
  ROLLOUT = "ICEBALL",
  FALSE_SWIPE = "SLASH",
  MILK_DRINK = "MORNINGSUN",
  STEEL_WING = "METALCLAW",
  ATTRACT = "SWEETKISS",
  SLEEP_TALK = "METRONOME",
  HEAL_BELL = "AROMATHERAPY",
  RETURN = "BODYSLAM",
  PRESENT = "PAYDAY",
  FRUSTRATION = "OUTRAGE",
  SAFEGUARD = "LIGHTSCREEN",
  PAIN_SPLIT = "MEGADRAIN",
  MAGNITUDE = "SANDSTORM",
  BATON_PASS = "ALLYSWITCH",
  PURSUIT = "QUICKATTACK",
  RAPID_SPIN = "FURYCUTTER",
  SWEET_SCENT = "COTTONSPORE",
  VITAL_THROW = "DYNAMICPUNCH",
  SYNTHESIS = "MORNINGSUN",
  HIDDEN_POWER = "ANCIENTPOWER",
  CROSS_CHOP = "BRICKBREAK",
  MIRROR_COAT = "MAGICCOAT",
  PSYCH_UP = "BULKUP",
  EXTREMESPEED = "QUICKATTACK",
  WHIRLPOOL = "WATERPULSE",
}

-- Essentials omits separators; most engine ids resolve by compact form.
-- These two are historical Pokémon Red identifier spellings rather than
-- separator differences and therefore need an explicit bridge.
local NAME_OVERRIDES = {
  PSYCHIC = "PSYCHIC_M",
  HIGHJUMPKICK = "HI_JUMP_KICK",
}

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

-- Structural audit used by both Kanto and Johto.  Rendering still fails open
-- per frame in VascBattleAnimPlayer, but the menu/logger can now distinguish a
-- complete catalog from a provider that merely registered a constructor.
function BattleAnimationCompat.audit(catalog)
  local receipt = {
    sheets=0, programs=0, variants=0, frames=0,
    invalidSheets=0, invalidPrograms=0, invalidFrames=0,
  }
  local sheets = type(catalog) == "table" and catalog.sheets or nil
  local programs = type(catalog) == "table" and catalog.programs or nil
  if type(sheets) ~= "table" or type(programs) ~= "table" then
    receipt.valid = false
    receipt.reason = "catalog-structure-missing"
    return receipt
  end
  for _, sheet in pairs(sheets) do
    receipt.sheets = receipt.sheets + 1
    if type(sheet) ~= "table" or type(sheet.path) ~= "string"
        or sheet.path == "" or (tonumber(sheet.w) or 0) <= 0
        or (tonumber(sheet.h) or 0) <= 0
        or (tonumber(sheet.cols) or 0) <= 0
        or (tonumber(sheet.rows) or 0) <= 0 then
      receipt.invalidSheets = receipt.invalidSheets + 1
    end
  end
  for programId, entry in pairs(programs) do
    receipt.programs = receipt.programs + 1
    local programValid = false
    if type(entry) == "table" then
      for _, variant in ipairs({ "move", "opp" }) do
        local program = entry[variant]
        if type(program) == "table" then
          receipt.variants = receipt.variants + 1
          local sheet = sheets[program.sheet]
          local capacity = type(sheet) == "table"
            and (tonumber(sheet.cols) or 0) * (tonumber(sheet.rows) or 0) or 0
          local frames = program.frames
          if type(frames) == "table" and #frames > 0 and capacity > 0 then
            programValid = true
            for frameIndex, frame in ipairs(frames) do
              receipt.frames = receipt.frames + 1
              if type(frame) ~= "table" then
                receipt.invalidFrames = receipt.invalidFrames + 1
              else
                for _, cel in ipairs(frame) do
                  local pattern = type(cel) == "table" and tonumber(cel.p) or -1
                  if pattern and pattern >= capacity then
                    receipt.invalidFrames = receipt.invalidFrames + 1
                    receipt.firstInvalidFrame = receipt.firstInvalidFrame or {
                      program=programId, variant=variant, frame=frameIndex,
                      pattern=pattern, capacity=capacity, sheet=program.sheet,
                    }
                    break
                  end
                end
              end
            end
          end
        end
      end
    end
    if not programValid then
      receipt.invalidPrograms = receipt.invalidPrograms + 1
    end
  end
  -- A bad cell index is quarantined by VascBattleAnimPlayer and the rest of
  -- that authored frame (or its native safety layer) remains usable.  Keep a
  -- strict `perfect` receipt while treating a catalog with only quarantined
  -- cell references as structurally valid.
  receipt.valid = receipt.invalidSheets == 0 and receipt.invalidPrograms == 0
  receipt.perfect = receipt.valid and receipt.invalidFrames == 0
  return receipt
end

function BattleAnimationCompat.registry(game, catalog, activeKasc, nativeMoveMax)
  local data = game and game.data or {}
  local moves = type(data.moves) == "table" and data.moves or {}
  local native = data.battle_anims and data.battle_anims.moveAnims or {}
  local byCompact = {}
  for moveId in pairs(moves) do
    local key = compact(moveId)
    if byCompact[key] == nil then byCompact[key] = moveId end
  end

  local registry = {
    programs={}, nativeSources={},
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
    local index = type(def) == "table" and tonumber(def.index) or nil
    local nativeOwned = index and index >= 1
      and index <= (tonumber(nativeMoveMax) or 165)
    if not index and tonumber(nativeMoveMax or 165) == 165 then
      nativeOwned = isGenOne(def)
    end
    if moveId and (nativeOwned or activeKasc) then
      registry.programs[moveId] = program
      if nativeOwned then registry.gen1Count = registry.gen1Count + 1
      else registry.kascCount = registry.kascCount + 1 end
    end
  end


  for moveId, programKey in pairs(
      BattleAnimationCompat.NATIVE_PROGRAM_ALIASES) do
    if moves[moveId] and not registry.programs[moveId] then
      local program = catalog and catalog.programs
                      and catalog.programs[programKey]
      if program then
        registry.programs[moveId] = program
        registry.gen1Count = registry.gen1Count + 1
        registry.aliasCount = registry.aliasCount + 1
      end
    end
  end

  if activeKasc then
    for moveId, programKey in pairs(BattleAnimationCompat.PROGRAM_ALIASES) do
      if moves[moveId] and not registry.programs[moveId] then
        local program = catalog and catalog.programs
                        and catalog.programs[programKey]
        if program then
          registry.programs[moveId] = program
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
  -- Keep an exhaustive, machine-readable receipt instead of inferring
  -- completeness from the number of authored sheets.  Kanto's release gate
  -- requires all 165 cartridge moves to resolve; Johto reports the same
  -- metric for its native range while its procedural 3D fallback remains
  -- available for moves without a hand-authored sheet.
  local maxNative = tonumber(nativeMoveMax) or 165
  local missingPrograms = {}
  local nativeMoves, coveredPrograms = 0, 0
  for moveId, def in pairs(moves) do
    local index = type(def) == "table" and tonumber(def.index) or nil
    local nativeOwned = index and index >= 1 and index <= maxNative
    if not index and maxNative == 165 then nativeOwned = isGenOne(def) end
    if nativeOwned then
      nativeMoves = nativeMoves + 1
      if registry.programs[moveId] then
        coveredPrograms = coveredPrograms + 1
      else
        missingPrograms[#missingPrograms + 1] = moveId
      end
    end
  end
  table.sort(missingPrograms)
  registry.nativeMoveCount = nativeMoves
  registry.coveredNativePrograms = coveredPrograms
  registry.missingNativePrograms = missingPrograms
  registry.missingNativeProgramCount = #missingPrograms
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
  -- Johto owns moves 1-251 natively, so its caller explicitly enables the
  -- post-Gen-I catalog without pretending KASC is installed.  Kanto keeps the
  -- original KASC gate.
  local enablePostGen = opts.enablePostGen == true or activeKasc == true
  local installed, missing = installNativeAliases(game, enablePostGen)
  local nativeMoveMax = opts.nativeMoveMax
  if nativeMoveMax == nil then
    nativeMoveMax = activeKasc and 251 or 165
  end
  local registry = BattleAnimationCompat.registry(
    game, catalog, enablePostGen, nativeMoveMax)
  local audit = BattleAnimationCompat.audit(catalog)
  local called, result = pcall(player.install, catalog, registry)
  local ok = called and result and true or false
  lastReceipt = {
    installed=ok,
    reason=ok and nil or (called and "animation-factory-conflict"
      or ("player-install-error:" .. tostring(result))),
    kasc=activeKasc and true or false,
    postGenEnabled=enablePostGen,
    gen1=registry.gen1Count,
    native=registry.gen1Count,
    postGen=registry.kascCount,
    programAliases=registry.aliasCount,
    nativeMoveCount=registry.nativeMoveCount,
    coveredNativePrograms=registry.coveredNativePrograms,
    missingNativeProgramCount=registry.missingNativeProgramCount,
    missingNativePrograms=registry.missingNativePrograms,
    missingNativeAliases=missing,
    sourceSha256=catalog.sourceSha256,
    audit=audit,
    catalogValid=audit.valid == true,
    catalogPerfect=audit.perfect == true,
    sheets=audit.sheets,
    programs=audit.programs,
    frames=audit.frames,
    invalidSheets=audit.invalidSheets,
    invalidPrograms=audit.invalidPrograms,
    invalidFrames=audit.invalidFrames,
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

return BattleAnimationCompat
