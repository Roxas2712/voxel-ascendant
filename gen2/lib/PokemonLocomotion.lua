-- Overworld locomotion classification and tuning for Gen 1 + Gen 2.
--
-- Pokemon Stadium's battle model set does not contain a universal named
-- "walk" clip. The overworld bridge therefore reuses each species' second
-- standby loop when one exists and drives it from actual distance travelled,
-- then adds a small step/bob so the model visibly walks even when its Stadium
-- pack only has an idle loop.
--
-- v0.1.17 broadens walking beyond the earlier grounded-biped-only set.
-- The user specifically wanted basically every NON-FLYING-TYPE Pokemon to walk,
-- even if some of them are really just doing a simple waddle. We therefore make
-- every Gen 1/2 species eligible except the canonical Flying-type Pokemon, while
-- still allowing per-species overrides from the config file.
local L = {}

-- Gen 1/2 Flying-type Pokemon. These stay on the old animation behavior by
-- default because winged / aerial movement usually looks worse when forced into
-- the generic ground-step overlay.
local FLYING_TYPE = {
  [6]=true,   -- Charizard
  [12]=true,  -- Butterfree
  [16]=true, [17]=true, [18]=true, -- Pidgey line
  [21]=true, [22]=true,            -- Spearow line
  [41]=true, [42]=true,            -- Zubat line
  [83]=true,                       -- Farfetch'd
  [84]=true, [85]=true,            -- Doduo / Dodrio
  [123]=true,                      -- Scyther
  [130]=true,                      -- Gyarados
  [142]=true,                      -- Aerodactyl
  [144]=true, [145]=true, [146]=true, -- Legendary birds
  [149]=true,                      -- Dragonite
  -- Generation 2
  [163]=true, [164]=true,          -- Hoothoot / Noctowl
  [165]=true, [166]=true,          -- Ledyba / Ledian
  [169]=true,                      -- Crobat
  [176]=true,                      -- Togetic
  [177]=true, [178]=true,          -- Natu / Xatu
  [187]=true, [188]=true, [189]=true, -- Hoppip line
  [193]=true,                      -- Yanma
  [198]=true,                      -- Murkrow
  [207]=true,                      -- Gligar
  [225]=true,                      -- Delibird
  [226]=true,                      -- Mantine
  [227]=true,                      -- Skarmory
  [249]=true, [250]=true,          -- Lugia / Ho-Oh
}

-- Species-specific feel adjustments. Values multiply the generic cadence and
-- body motion; omitted species use 1.0. Long-legged runners get a little more
-- stride, very small/round walkers a little less body pitch. Extra entries are
-- included for some common quadrupeds / waddlers now that the locomotion set is
-- broader than just bipeds.
local TUNE = {
  [1]   = { cadence = 0.92, bob = 0.85, pitch = 0.55 }, -- Bulbasaur
  [2]   = { cadence = 0.88, bob = 0.88, pitch = 0.55 },
  [3]   = { cadence = 0.74, bob = 0.75, pitch = 0.45 },
  [4]   = { cadence = 1.05, bob = 0.95, pitch = 0.80 },
  [5]   = { cadence = 0.98, bob = 0.95, pitch = 0.80 },
  [6]   = { cadence = 0.82, bob = 0.72, pitch = 0.58 }, -- Charizard grounded walk
  [7]   = { cadence = 0.92, bob = 0.82, pitch = 0.60 },
  [8]   = { cadence = 0.88, bob = 0.82, pitch = 0.60 },
  [9]   = { cadence = 0.76, bob = 0.75, pitch = 0.55 },
  [19]  = { cadence = 1.16, bob = 0.82, pitch = 0.72 }, -- Rattata
  [20]  = { cadence = 1.12, bob = 0.80, pitch = 0.70 },
  [23]  = { cadence = 0.98, bob = 0.78, pitch = 0.35 }, -- Ekans slither-waddle
  [24]  = { cadence = 0.92, bob = 0.76, pitch = 0.35 },
  [25]  = { cadence = 1.16, bob = 0.88, pitch = 0.78, clipRate = 0.78 }, -- Pikachu: dedicated brisk walk clip in OverworldStadium
  [26]  = { cadence = 1.05, bob = 0.90, pitch = 0.80 },
  [27]  = { cadence = 0.96, bob = 0.86, pitch = 0.70 },
  [28]  = { cadence = 0.90, bob = 0.82, pitch = 0.72 },
  [29]  = { cadence = 0.96, bob = 0.86, pitch = 0.68 },
  [30]  = { cadence = 0.92, bob = 0.84, pitch = 0.68 },
  [31]  = { cadence = 0.82, bob = 0.80, pitch = 0.70 },
  [32]  = { cadence = 1.00, bob = 0.86, pitch = 0.70 },
  [33]  = { cadence = 0.94, bob = 0.84, pitch = 0.72 },
  [34]  = { cadence = 0.84, bob = 0.80, pitch = 0.75 },
  [35]  = { cadence = 1.02, bob = 0.92, pitch = 0.70 },
  [36]  = { cadence = 0.94, bob = 0.88, pitch = 0.68 },
  [37]  = { cadence = 1.02, bob = 0.82, pitch = 0.62 }, -- Vulpix
  [38]  = { cadence = 0.96, bob = 0.80, pitch = 0.60 },
  [39]  = { cadence = 0.98, bob = 0.95, pitch = 0.60 },
  [40]  = { cadence = 0.90, bob = 0.90, pitch = 0.58 },
  [43]  = { cadence = 1.18, bob = 1.15, pitch = 0.45 }, -- Oddish
  [44]  = { cadence = 1.10, bob = 1.10, pitch = 0.50 },
  [45]  = { cadence = 0.95, bob = 1.00, pitch = 0.45 },
  [46]  = { cadence = 0.92, bob = 0.90, pitch = 0.48 }, -- Paras
  [47]  = { cadence = 0.88, bob = 0.88, pitch = 0.48 },
  [48]  = { cadence = 1.10, bob = 1.05, pitch = 0.55 },
  [49]  = { cadence = 0.96, bob = 0.86, pitch = 0.52 }, -- Venomoth (non-Flying)
  [50]  = { cadence = 0.98, bob = 0.92, pitch = 0.40 }, -- Diglett
  [51]  = { cadence = 0.92, bob = 0.90, pitch = 0.40 }, -- Dugtrio
  [52]  = { cadence = 1.08, bob = 0.90, pitch = 0.90 },
  [53]  = { cadence = 1.00, bob = 0.84, pitch = 0.82 },
  [54]  = { cadence = 0.96, bob = 0.90, pitch = 0.72 },
  [55]  = { cadence = 0.90, bob = 0.86, pitch = 0.70 },
  [56]  = { cadence = 1.10, bob = 0.80, pitch = 0.72, clipRate = 0.70 }, -- Mankey: brisk ground gait; dedicated clip in OverworldStadium
  [57]  = { cadence = 0.98, bob = 0.85, pitch = 0.88 },
  [58]  = { cadence = 0.98, bob = 0.80, pitch = 0.72 }, -- Growlithe
  [59]  = { cadence = 0.92, bob = 0.76, pitch = 0.70 },
  [60]  = { cadence = 1.12, bob = 1.10, pitch = 0.55 },
  [61]  = { cadence = 1.02, bob = 1.02, pitch = 0.58 },
  [62]  = { cadence = 0.92, bob = 0.94, pitch = 0.65 },
  [63]  = { cadence = 0.96, bob = 0.86, pitch = 0.48 },
  [64]  = { cadence = 0.94, bob = 0.84, pitch = 0.60 },
  [65]  = { cadence = 0.90, bob = 0.82, pitch = 0.65 },
  [66]  = { cadence = 1.00, bob = 0.90, pitch = 0.90 },
  [67]  = { cadence = 0.96, bob = 0.88, pitch = 0.92 },
  [68]  = { cadence = 0.90, bob = 0.84, pitch = 0.92 },
  [69]  = { cadence = 0.98, bob = 0.98, pitch = 0.35 },
  [70]  = { cadence = 0.94, bob = 0.96, pitch = 0.35 },
  [71]  = { cadence = 0.86, bob = 0.90, pitch = 0.32 },
  [72]  = { cadence = 0.84, bob = 0.88, pitch = 0.28 }, -- Tentacool shimmy
  [73]  = { cadence = 0.78, bob = 0.84, pitch = 0.28 },
  [74]  = { cadence = 0.88, bob = 0.84, pitch = 0.40 },
  [75]  = { cadence = 0.82, bob = 0.80, pitch = 0.48 },
  [76]  = { cadence = 0.76, bob = 0.78, pitch = 0.48 },
  [77]  = { cadence = 1.00, bob = 0.78, pitch = 0.78 },
  [78]  = { cadence = 1.06, bob = 0.74, pitch = 0.82 },
  [79]  = { cadence = 0.74, bob = 0.78, pitch = 0.38 },
  [80]  = { cadence = 0.72, bob = 0.76, pitch = 0.42 },
  [81]  = { cadence = 0.86, bob = 0.76, pitch = 0.25 }, -- Magnemite hover-waddle
  [82]  = { cadence = 0.82, bob = 0.74, pitch = 0.25 },
  [86]  = { cadence = 0.84, bob = 0.86, pitch = 0.40 }, -- Seel
  [87]  = { cadence = 0.78, bob = 0.82, pitch = 0.40 },
  [88]  = { cadence = 0.82, bob = 0.90, pitch = 0.25 }, -- Grimer ooze-waddle
  [89]  = { cadence = 0.74, bob = 0.86, pitch = 0.25 },
  [90]  = { cadence = 0.84, bob = 0.84, pitch = 0.20 }, -- Shellder
  [91]  = { cadence = 0.78, bob = 0.80, pitch = 0.20 },
  [92]  = { cadence = 0.88, bob = 0.86, pitch = 0.20 }, -- Gastly float-waddle
  [93]  = { cadence = 0.84, bob = 0.82, pitch = 0.20 },
  [94]  = { cadence = 0.90, bob = 0.82, pitch = 0.48 },
  [95]  = { cadence = 0.62, bob = 0.68, pitch = 0.22 }, -- Onix slow undulation
  [96]  = { cadence = 0.92, bob = 0.84, pitch = 0.62 },
  [97]  = { cadence = 0.86, bob = 0.80, pitch = 0.64 },
  [98]  = { cadence = 1.02, bob = 0.80, pitch = 0.62 }, -- Krabby
  [99]  = { cadence = 0.96, bob = 0.78, pitch = 0.62 },
  [100] = { cadence = 0.96, bob = 0.78, pitch = 0.22 }, -- Voltorb roll-hop
  [101] = { cadence = 0.90, bob = 0.76, pitch = 0.22 },
  [102] = { cadence = 0.92, bob = 0.86, pitch = 0.28 }, -- Exeggcute
  [103] = { cadence = 0.78, bob = 0.80, pitch = 0.35 },
  [104] = { cadence = 0.98, bob = 0.84, pitch = 0.82 },
  [105] = { cadence = 0.92, bob = 0.82, pitch = 0.82 },
  [106] = { cadence = 1.22, bob = 0.75, pitch = 1.10 },
  [107] = { cadence = 1.08, bob = 0.85, pitch = 0.95 },
  [108] = { cadence = 0.86, bob = 0.84, pitch = 0.52 },
  [109] = { cadence = 0.86, bob = 0.80, pitch = 0.20 }, -- Koffing hover-waddle
  [110] = { cadence = 0.80, bob = 0.76, pitch = 0.20 },
  [111] = { cadence = 0.84, bob = 0.76, pitch = 0.58 },
  [112] = { cadence = 0.80, bob = 0.74, pitch = 0.60 },
  [113] = { cadence = 0.82, bob = 0.80, pitch = 0.42 }, -- Chansey
  [114] = { cadence = 1.10, bob = 1.00, pitch = 0.40 },
  [115] = { cadence = 0.86, bob = 0.82, pitch = 0.72 },
  [116] = { cadence = 0.90, bob = 0.84, pitch = 0.36 }, -- Horsea
  [117] = { cadence = 0.84, bob = 0.82, pitch = 0.36 },
  [118] = { cadence = 0.92, bob = 0.82, pitch = 0.36 }, -- Goldeen
  [119] = { cadence = 0.86, bob = 0.80, pitch = 0.36 },
  [120] = { cadence = 0.84, bob = 0.84, pitch = 0.22 }, -- Staryu
  [121] = { cadence = 0.80, bob = 0.82, pitch = 0.22 },
  [122] = { cadence = 1.00, bob = 0.80, pitch = 0.90 },
  [124] = { cadence = 0.96, bob = 0.84, pitch = 0.82 },
  [125] = { cadence = 0.98, bob = 0.84, pitch = 0.88 },
  [126] = { cadence = 0.94, bob = 0.84, pitch = 0.88 },
  [127] = { cadence = 0.92, bob = 0.82, pitch = 0.72 },
  [128] = { cadence = 0.86, bob = 0.76, pitch = 0.58 }, -- Tauros
  [129] = { cadence = 0.88, bob = 0.78, pitch = 0.18 }, -- Magikarp flop
  [131] = { cadence = 0.74, bob = 0.74, pitch = 0.28 }, -- Lapras
  [132] = { cadence = 0.82, bob = 0.82, pitch = 0.12 }, -- Ditto
  [133] = { cadence = 1.04, bob = 0.82, pitch = 0.66 }, -- Eevee
  [134] = { cadence = 0.96, bob = 0.78, pitch = 0.40 }, -- Vaporeon
  [135] = { cadence = 1.08, bob = 0.80, pitch = 0.72 }, -- Jolteon
  [136] = { cadence = 0.98, bob = 0.80, pitch = 0.70 }, -- Flareon
  [137] = { cadence = 0.86, bob = 0.76, pitch = 0.18 }, -- Porygon
  [138] = { cadence = 0.78, bob = 0.76, pitch = 0.26 }, -- Omanyte
  [139] = { cadence = 0.74, bob = 0.74, pitch = 0.30 }, -- Omastar
  [140] = { cadence = 0.92, bob = 0.80, pitch = 0.58 }, -- Kabuto
  [141] = { cadence = 1.08, bob = 0.70, pitch = 0.95 },
  [143] = { cadence = 0.72, bob = 0.75, pitch = 0.55 },
  [147] = { cadence = 0.84, bob = 0.82, pitch = 0.25 }, -- Dratini
  [148] = { cadence = 0.78, bob = 0.80, pitch = 0.25 }, -- Dragonair
  [150] = { cadence = 0.92, bob = 0.70, pitch = 0.85 },
  [151] = { cadence = 0.96, bob = 0.72, pitch = 0.28 }, -- Mew hover-waddle
}

function L.isGroundedBiped(dex, overrides)
  if type(overrides) == "table" and overrides[dex] ~= nil then
    return overrides[dex] and true or false
  end
  return type(dex) == "number" and dex >= 1 and dex <= 251 and not FLYING_TYPE[dex]
end

function L.tuning(dex)
  return TUNE[dex] or { cadence = 1, bob = 1, pitch = 1 }
end

-- Distance (world pixels) for one complete left/right gait cycle. Scale it
-- with model height so a Snorlax does not shuffle at Pikachu's cadence.
function L.cycleDistance(targetHeight, dex, globalMultiplier)
  local h = tonumber(targetHeight) or 14
  local tune = L.tuning(dex)
  local d = 10 + h * 0.62
  if d < 11 then d = 11 end
  if d > 34 then d = 34 end
  local cadence = tonumber(tune.cadence) or 1
  local global = tonumber(globalMultiplier) or 1
  if cadence <= 0 then cadence = 1 end
  if global <= 0 then global = 1 end
  -- Larger cadence means faster feet, therefore less distance per cycle.
  return d / (cadence * global)
end


-- Advance the Stadium skeletal loop from DISTANCE, but keep it close to the
-- speed it was authored for.  Older builds mapped one complete 48-84 frame
-- standby loop onto a roughly 15-30 px gait cycle; at normal overworld speed
-- that could play a 2-3 second animation in a few tenths of a second and look
-- like fast-forward.
--
-- This returns seconds of Stadium animation to advance for a world-space
-- distance. Higher cadence species still animate a little faster, but never
-- by compressing the entire standby clip into each procedural footfall.
function L.clipSecondsForDistance(distance, dex, globalMultiplier, worldSpeed)
  local dist = tonumber(distance) or 0
  if dist <= 0 then return 0 end
  local tune = L.tuning(dex)
  local cadence = tonumber(tune.cadence) or 1
  local global = tonumber(globalMultiplier) or 1
  local speed = tonumber(worldSpeed) or 54
  if cadence <= 0 then cadence = 1 end
  if global <= 0 then global = 1 end
  if speed <= 0 then speed = 54 end
  return (dist / speed) * cadence * global
end

-- World-space lift of the whole body at a footfall. This is intentionally
-- subtle; the Stadium skeleton supplies the character motion, this just makes
-- ground contact readable for species whose alternate standby has little leg
-- travel.

-- Optional skeletal playback multiplier for species whose most useful Stadium
-- locomotion source was authored as a more energetic battle motion.  This is
-- separate from footfall cadence: it lets us calm the skeleton down without
-- making the overworld body slide between steps.
function L.clipRate(dex)
  local tune = L.tuning(dex)
  local r = tonumber(tune.clipRate) or 1
  if r <= 0 then r = 1 end
  return r
end

function L.bobAmount(targetHeight, dex, globalMultiplier)
  local h = tonumber(targetHeight) or 14
  local tune = L.tuning(dex)
  local a = h * 0.020
  if a < 0.12 then a = 0.12 end
  if a > 0.75 then a = 0.75 end
  return a * (tonumber(tune.bob) or 1) * (tonumber(globalMultiplier) or 1)
end

function L.pitchAmount(dex, globalMultiplier)
  local tune = L.tuning(dex)
  -- about 1.7 degrees at the default setting
  return 0.030 * (tonumber(tune.pitch) or 1)
         * (tonumber(globalMultiplier) or 1)
end

return L
