-- KASC-authored HD trainer standees for Gen-2 live-world battles.
--
-- This module is presentation-only. Gold/Silver/Crystal continue to own the
-- battle state, intro queue and the exact moment a trainer is replaced by a
-- Pokemon. We merely resolve a higher-resolution image while the engine's
-- showPlayerTrainer/showEnemyTrainer flag is true. Missing or unknown art is
-- deliberately nil so OverworldBattle can fall back to the imported cartridge
-- picture without changing battle timing.

local V = ...

local M = {}
local cache = {}
local reported = setmetatable({}, { __mode = "k" })

local okDiagnostics, Diagnostics = pcall(V.require, "Diagnostics")
if not okDiagnostics or type(Diagnostics) ~= "table" then Diagnostics = {} end
local okLocalContent, LocalContent = pcall(V.require, "LocalContent")
if not okLocalContent or type(LocalContent) ~= "table" then LocalContent = nil end

-- Player and opponent identities are deliberately separate even though the
-- packaged files share one directory.  Silver is the rival, not the Silver-
-- edition protagonist; Gold/Silver and male Crystal all play as Ethan/Gold.
local PLAYER = {
  gold = "assets/trainers/gen2/players/gold_front_hd.png",
  kris = "assets/trainers/gen2/players/kris_front_hd.png",
}

local UNIQUE_OPPONENT = {
  silver = "assets/trainers/gen2/players/silver_front_hd.png",
  red = "assets/trainers/gen2/players/red_front_hd.png",
}

-- Gen-2 classes which have an honest visual counterpart in KASC's approved
-- 128px trainer pack. Unique Johto leaders/classes are intentionally absent:
-- showing a random Kanto person would be worse than the native Crystal art.
local ENEMY_STEM = {
  AGATHA="elite_four_agatha", BEAUTY="beauty", BIKER="biker",
  BIRD_KEEPER="bird_keeper", BLACKBELT="black_belt", BLACK_BELT="black_belt",
  BLAINE="leader_blaine", BROCK="leader_brock", BUG_CATCHER="bug_catcher",
  BRUNO="elite_four_bruno", CHAMPION="elite_four_lance",
  BURGLAR="burglar", CAMPER="camper", CHANNELER="channeler",
  COOLTRAINER_F="cool_trainer_f", COOLTRAINER_M="cool_trainer_m",
  COOLTRAINERF="cool_trainer_f", COOLTRAINERM="cool_trainer_m",
  CUE_BALL="cue_ball", ENGINEER="engineer", ERIKA="leader_erika",
  FISHER="fisherman", FISHERMAN="fisherman", GAMBLER="gamer",
  GENTLEMAN="gentleman", GIOVANNI="leader_giovanni", GRUNTM="rocket_grunt_m",
  GUITARIST="rocker", HIKER="hiker",
  JR_TRAINER_F="picnicker", JR_TRAINER_M="camper", JUGGLER="juggler",
  KOGA="leader_koga", LANCE="elite_four_lance", LASS="lass",
  LORELEI="elite_four_lorelei", LT_SURGE="leader_lt_surge",
  MEDIUM="channeler", MISTY="leader_misty", PICNICKER="picnicker",
  POKEMANIAC="pokemaniac", PSYCHIC="psychic_m", PSYCHIC_M="psychic_m",
  PSYCHIC_T="psychic_m", ROCKER="rocker",
  ROCKET="rocket_grunt_m", ROCKET_GRUNT="rocket_grunt_m",
  SAILOR="sailor", SABRINA="leader_sabrina", SCIENTIST="scientist",
  SUPER_NERD="super_nerd", SWIMMER="swimmer_m", SWIMMER_M="swimmer_m",
  SWIMMERM="swimmer_m", TAMER="tamer", YOUNGSTER="youngster",
  -- These suffixes are the canonical pokecrystal trainer constants. Keep the
  -- older aliases above for save/import compatibility, but do not let a mere
  -- spelling difference force an otherwise exact approved standee to 2D.
  BLACKBELT_T="black_belt",
}

local ELITE_V3 = {
  elite_four_agatha=true, elite_four_bruno=true,
  elite_four_lance=true, elite_four_lorelei=true,
}

local function image(path)
  if cache[path] ~= nil then return cache[path] or nil end
  local assets = V and V.mod and V.mod.assets
  if not (assets and type(assets.image) == "function") then
    cache[path] = false
    return nil
  end
  -- LocalContent returns the engine-visible path for loose files.  When that
  -- path points back into this mod, convert it to the relative path expected
  -- by mod.assets:image; packaged defaults already arrive relative.
  local relative = path
  local root = V and V.mod and V.mod.path
  if type(root) == "string" and path:sub(1, #root + 1) == root .. "/" then
    relative = path:sub(#root + 2)
  end
  local ok, loaded = pcall(assets.image, assets, relative)
  if not ok or not loaded then
    cache[path] = false
    return nil
  end
  if type(loaded.setFilter) == "function" then
    pcall(loaded.setFilter, loaded, "nearest", "nearest")
  end
  cache[path] = loaded
  return loaded
end

local function injected(kind, current, context)
  if not (LocalContent and type(LocalContent.resolveSprite) == "function") then
    return current
  end
  local ok, chosen = pcall(LocalContent.resolveSprite, kind, current, context)
  return ok and type(chosen) == "string" and chosen ~= "" and chosen or current
end

local function classKey(value)
  local key = tostring(value or ""):upper():gsub("^OPP_", "")
  return key:gsub("[^A-Z0-9]+", "_"):gsub("^_+", ""):gsub("_+$", "")
end

local function carrier(screen, side, id, path)
  local loaded = image(path)
  if not loaded then return nil end
  local seen = reported[screen]
  if not seen then seen = {}; reported[screen] = seen end
  if not seen[side] then
    seen[side] = true
    if type(Diagnostics.write) == "function" then
      pcall(Diagnostics.write, "gen2-battle-trainer-art", {
        side=side, id=id, path=path, source="kasc-hd",
        class=screen and screen.enemyTrainerClass,
        version=screen and screen.save and screen.save.version,
      })
    end
  end
  return {
    canvas=loaded,
    -- All approved standees are 128x128 with feet on y=122. Their authored
    -- body is 116px high; 28 world pixels keeps a trainer visibly human-sized
    -- beside the enlarged 32px Pokemon without turning the person into scenery.
    captureW=128, captureH=128, ax=64, ay=122,
    pixelWorld=28 / 116,
    trainer=true, trainerArt=true,
    vascSpriteView="front",
    inkIdentity=path,
    source="kasc-hd-gen2-trainer",
  }
end

function M.player(screen)
  if type(screen) ~= "table" then return nil end
  -- Crystal's native lifecycle calls this showPlayerBack; older VASC builds
  -- exposed showPlayerTrainer. Never paint the player during the foe's intro.
  local visible = screen.showPlayerBack == true
    or screen.showPlayerTrainer == true
  -- Gold's real lifecycle deliberately keeps the player trainer visible while
  -- the opposing trainer slides away and its Pokemon is sent out. It clears
  -- showPlayerTrainer only on the later player `sendout` queue event (the Go!
  -- line). Follow that flag exactly; only the simultaneous enemy-trainer and
  -- enemy grow-in phases are excluded.
  if not visible or screen.showEnemyTrainer == true
      or screen.enemySendingOut == true then return nil end
  local save = screen.save or (screen.game and screen.game.save) or {}
  local version = tostring(save.version or "crystal"):lower()
  local female = type(save.player) == "table"
    and save.player.gender == "female"
  -- Kris exists only in Crystal's female branch. Silver's cartridge edition
  -- still stars Ethan/Gold; the Silver HD image below is reserved for the
  -- rival/opponent resolver and can never leak onto the player's side.
  local id = (version == "crystal" and female) and "kris" or "gold"
  local path = injected("player", PLAYER[id], {
    kind="battle", side="front", player=true, playerCharacter=id,
    edition=version, screen=screen,
  })
  return carrier(screen, "player", id, path)
end

function M.enemy(screen)
  if type(screen) ~= "table" or screen.showEnemyTrainer ~= true then return nil end
  local key = classKey(screen.enemyTrainerClass)
  -- Silver is the canonical Gen-2 rival across all three rival phases.
  if key == "RIVAL" or key == "RIVAL1" or key == "RIVAL2" or key == "RIVAL3" then
    local path = injected("trainer", UNIQUE_OPPONENT.silver, {
      kind="battle", side="front", trainerId=key, oppClass=key, screen=screen,
    })
    return carrier(screen, "enemy", "silver", path)
  end
  if key == "RED" then
    local path = injected("trainer", UNIQUE_OPPONENT.red, {
      kind="battle", side="front", trainerId=key, oppClass=key, screen=screen,
    })
    return carrier(screen, "enemy", "red", path)
  end
  local stem = ENEMY_STEM[key]
  if not stem then return nil end
  local version = ELITE_V3[stem] and "v3" or "v2"
  local path = ("assets/trainers/gen2/kasc/%s_voxel_front_hd_%s.png")
    :format(stem, version)
  path = injected("trainer", path, {
    kind="battle", side="front", trainerId=key, oppClass=key, screen=screen,
  })
  return carrier(screen, "enemy", key, path)
end

function M.resolve(screen, side)
  if side == "player" then return M.player(screen) end
  if side == "enemy" then return M.enemy(screen) end
  return nil
end

function M.hasHdClass(value)
  local key = classKey(value)
  if key == "RED" or key == "RIVAL" or key == "RIVAL1"
      or key == "RIVAL2" or key == "RIVAL3" then return true end
  return ENEMY_STEM[key] ~= nil
end

function M.coverage(classes)
  local hd, native = {}, {}
  for id, row in pairs(type(classes) == "table" and classes or {}) do
    local key = type(row) == "table" and (row.id or row.name) or id
    local out = M.hasHdClass(key) and hd or native
    out[#out + 1] = classKey(key)
  end
  table.sort(hd)
  table.sort(native)
  return { hd=hd, native=native, hdCount=#hd, nativeCount=#native }
end

return M
