-- Central visual scale policy. Canonical centimetres remain metadata, while
-- the overworld uses five readable size tiers: two for humans and three for
-- Pokemon. A normal adult / large Pokemon is capped at 16 VASC world units.

local ScaleProfiles = {}

ScaleProfiles.reference = {
  centimetres = 185,
  worldHeight = 16,
  normalActorMaximumCm = 185,
  displayMultiplier = 1.35,
}

ScaleProfiles.classes = {
  human_child = 12.5,
  human_adult = 16,
  pokemon_small = 7,
  pokemon_medium = 11.5,
  pokemon_large = 16,
}

ScaleProfiles.characterCm = {
  green = 140,
  red = 145,
  blue = 145,
  gold = 145,
  kris = 145,
  silver = 145,
  oak = 185,
}

ScaleProfiles.characters = {
  green = "human_child",
  red = "human_child",
  blue = "human_child",
  gold = "human_child",
  kris = "human_child",
  silver = "human_child",
  oak = "human_adult",
}

ScaleProfiles.speciesCm = {
  [16] = 30, -- Pidgey / Taubsi
  [25] = 40,  -- Pikachu
  [133] = 30, -- Eevee / Evoli
  [206] = 150, -- Dunsparce / Dummisel (canonical body length, not height)
}

-- Canonical Gen-1/2 height tiers (decimetres): <= 7 small, <= 14 medium,
-- above 14 large. Medium is the default, so only non-medium species need an
-- entry. Dummisel is the deliberate exception because 1.5 m measures its
-- long, ground-hugging body rather than its standing height.
ScaleProfiles.species = {
  [1] = "pokemon_small",
  [3] = "pokemon_large",
  [4] = "pokemon_small",
  [6] = "pokemon_large",
  [7] = "pokemon_small",
  [9] = "pokemon_large",
  [10] = "pokemon_small",
  [11] = "pokemon_small",
  [13] = "pokemon_small",
  [14] = "pokemon_small",
  [16] = "pokemon_small",
  [18] = "pokemon_large",
  [19] = "pokemon_small",
  [20] = "pokemon_small",
  [21] = "pokemon_small",
  [23] = "pokemon_large",
  [24] = "pokemon_large",
  [25] = "pokemon_small",
  [27] = "pokemon_small",
  [29] = "pokemon_small",
  [32] = "pokemon_small",
  [35] = "pokemon_small",
  [37] = "pokemon_small",
  [39] = "pokemon_small",
  [42] = "pokemon_large",
  [43] = "pokemon_small",
  [46] = "pokemon_small",
  [49] = "pokemon_large",
  [50] = "pokemon_small",
  [51] = "pokemon_small",
  [52] = "pokemon_small",
  [55] = "pokemon_large",
  [56] = "pokemon_small",
  [58] = "pokemon_small",
  [59] = "pokemon_large",
  [60] = "pokemon_small",
  [65] = "pokemon_large",
  [67] = "pokemon_large",
  [68] = "pokemon_large",
  [69] = "pokemon_small",
  [71] = "pokemon_large",
  [73] = "pokemon_large",
  [74] = "pokemon_small",
  [78] = "pokemon_large",
  [80] = "pokemon_large",
  [81] = "pokemon_small",
  [85] = "pokemon_large",
  [87] = "pokemon_large",
  [90] = "pokemon_small",
  [91] = "pokemon_large",
  [93] = "pokemon_large",
  [94] = "pokemon_large",
  [95] = "pokemon_large",
  [97] = "pokemon_large",
  [98] = "pokemon_small",
  [100] = "pokemon_small",
  [102] = "pokemon_small",
  [103] = "pokemon_large",
  [104] = "pokemon_small",
  [106] = "pokemon_large",
  [109] = "pokemon_small",
  [112] = "pokemon_large",
  [115] = "pokemon_large",
  [116] = "pokemon_small",
  [118] = "pokemon_small",
  [123] = "pokemon_large",
  [127] = "pokemon_large",
  [130] = "pokemon_large",
  [131] = "pokemon_large",
  [132] = "pokemon_small",
  [133] = "pokemon_small",
  [138] = "pokemon_small",
  [140] = "pokemon_small",
  [142] = "pokemon_large",
  [143] = "pokemon_large",
  [144] = "pokemon_large",
  [145] = "pokemon_large",
  [146] = "pokemon_large",
  [147] = "pokemon_large",
  [148] = "pokemon_large",
  [149] = "pokemon_large",
  [150] = "pokemon_large",
  [151] = "pokemon_small",
  [154] = "pokemon_large",
  [155] = "pokemon_small",
  [157] = "pokemon_large",
  [158] = "pokemon_small",
  [160] = "pokemon_large",
  [162] = "pokemon_large",
  [163] = "pokemon_small",
  [164] = "pokemon_large",
  [167] = "pokemon_small",
  [169] = "pokemon_large",
  [170] = "pokemon_small",
  [172] = "pokemon_small",
  [173] = "pokemon_small",
  [174] = "pokemon_small",
  [175] = "pokemon_small",
  [176] = "pokemon_small",
  [177] = "pokemon_small",
  [178] = "pokemon_large",
  [179] = "pokemon_small",
  [182] = "pokemon_small",
  [183] = "pokemon_small",
  [187] = "pokemon_small",
  [188] = "pokemon_small",
  [191] = "pokemon_small",
  [194] = "pokemon_small",
  [198] = "pokemon_small",
  [199] = "pokemon_large",
  [200] = "pokemon_small",
  [201] = "pokemon_small",
  [203] = "pokemon_large",
  [204] = "pokemon_small",
  [206] = "pokemon_small",
  [208] = "pokemon_large",
  [209] = "pokemon_small",
  [211] = "pokemon_small",
  [212] = "pokemon_large",
  [213] = "pokemon_small",
  [214] = "pokemon_large",
  [216] = "pokemon_small",
  [217] = "pokemon_large",
  [218] = "pokemon_small",
  [220] = "pokemon_small",
  [222] = "pokemon_small",
  [223] = "pokemon_small",
  [226] = "pokemon_large",
  [227] = "pokemon_large",
  [228] = "pokemon_small",
  [230] = "pokemon_large",
  [231] = "pokemon_small",
  [233] = "pokemon_small",
  [236] = "pokemon_small",
  [238] = "pokemon_small",
  [239] = "pokemon_small",
  [240] = "pokemon_small",
  [242] = "pokemon_large",
  [243] = "pokemon_large",
  [244] = "pokemon_large",
  [245] = "pokemon_large",
  [246] = "pokemon_small",
  [248] = "pokemon_large",
  [249] = "pokemon_large",
  [250] = "pokemon_large",
  [251] = "pokemon_small",
}

function ScaleProfiles.heightCm(role, dex)
  if dex ~= nil then return ScaleProfiles.speciesCm[tonumber(dex)] end
  return ScaleProfiles.characterCm[tostring(role or ""):lower()]
end

function ScaleProfiles.class(role, dex)
  if dex ~= nil then
    return ScaleProfiles.species[tonumber(dex)] or "pokemon_medium"
  end
  return ScaleProfiles.characters[tostring(role or ""):lower()]
    or "human_adult"
end

function ScaleProfiles.worldHeight(role, dex)
  return ScaleProfiles.classes[ScaleProfiles.class(role, dex)]
    * ScaleProfiles.reference.displayMultiplier
end

function ScaleProfiles.worldHeightForClass(class)
  return (ScaleProfiles.classes[tostring(class or "")]
    or ScaleProfiles.classes.human_adult)
    * ScaleProfiles.reference.displayMultiplier
end

-- Live-calibrated body heights for reviewed animated cards only. The source
-- referenceHeight excludes wings/tails; multiplying it by the broad small
-- tier made Taubsi approach the protagonist's body size while hovering.
-- Keep legacy/pixel cards and the already accepted Charizard untouched.
function ScaleProfiles.worldHeightForRecord(record)
  if type(record) == "table" and record.animationCards then
    local dex = tonumber(record.dex)
    if dex == 16 then return 5.4 end
    -- Same-camera review: measure the body, not raised wings or a stretched
    -- snake's nominal length. These values apply identically to both palettes.
    if dex == 41 then return 9.45 end
    if dex == 42 then return 12.15 end -- Golbat: wing envelope is not body height.
    if dex == 92 then return 8.1 end -- Gastly: gas extends beyond the measured sphere.
    if dex == 147 then return 12.15 end
    if dex == 130 then return 32.4 end
  end
  return ScaleProfiles.worldHeightForClass(record and record.scaleClass)
end

-- Compatibility alias for the initial Card renderer API.
ScaleProfiles.cardSize = ScaleProfiles.worldHeight

function ScaleProfiles.public()
  return {
    schema = "ascendant.scale-profiles/v3",
    units = "visual-tiers-with-centimetre-metadata",
    reference = ScaleProfiles.reference,
    classes = ScaleProfiles.classes,
    characterCm = ScaleProfiles.characterCm,
    speciesCm = ScaleProfiles.speciesCm,
    characters = ScaleProfiles.characters,
    species = ScaleProfiles.species,
    heightCm = ScaleProfiles.heightCm,
    class = ScaleProfiles.class,
    worldHeight = ScaleProfiles.worldHeight,
    worldHeightForClass = ScaleProfiles.worldHeightForClass,
    worldHeightForRecord = ScaleProfiles.worldHeightForRecord,
    cardSize = ScaleProfiles.cardSize,
  }
end

return ScaleProfiles
