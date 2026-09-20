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
  misty = "human_child",
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
-- PRIVATE HOENN QA: UNAPPROVED body-size candidates. Source graphics unchanged.
local HOENN_QA_BODY_HEIGHTS = {
  [252] = 9.45, -- treecko
  [253] = 15.525, -- grovyle
  [254] = 21.6, -- sceptile
  [255] = 9.45, -- torchic
  [256] = 15.525, -- combusken
  [257] = 21.6, -- blaziken
  [258] = 9.45, -- mudkip
  [259] = 9.45, -- marshtomp
  [260] = 21.6, -- swampert
  [261] = 9.45, -- poochyena
  [262] = 15.525, -- mightyena
  [263] = 9.45, -- zigzagoon
  [264] = 9.45, -- linoone
  [265] = 9.45, -- wurmple
  [266] = 9.45, -- silcoon
  [267] = 15.525, -- beautifly
  [268] = 9.45, -- cascoon
  [269] = 15.525, -- dustox
  [270] = 9.45, -- lotad
  [271] = 15.525, -- lombre
  [272] = 21.6, -- ludicolo
  [273] = 9.45, -- seedot
  [274] = 15.525, -- nuzleaf
  [275] = 15.525, -- shiftry
  [276] = 5.4, -- taillow
  [277] = 9.45, -- swellow
  [278] = 5.4, -- wingull
  [279] = 12.15, -- pelipper
  [280] = 9.45, -- ralts
  [281] = 15.525, -- kirlia
  [282] = 21.6, -- gardevoir
  [283] = 9.45, -- surskit
  [284] = 15.525, -- masquerain
  [285] = 9.45, -- shroomish
  [286] = 15.525, -- breloom
  [287] = 15.525, -- slakoth
  [288] = 15.525, -- vigoroth
  [289] = 21.6, -- slaking
  [290] = 9.45, -- nincada
  [291] = 15.525, -- ninjask
  [292] = 15.525, -- shedinja
  [293] = 9.45, -- whismur
  [294] = 15.525, -- loudred
  [295] = 21.6, -- exploud
  [296] = 15.525, -- makuhita
  [297] = 21.6, -- hariyama
  [298] = 9.45, -- azurill
  [299] = 15.525, -- nosepass
  [300] = 9.45, -- skitty
  [301] = 15.525, -- delcatty
  [302] = 9.45, -- sableye
  [303] = 9.45, -- mawile
  [304] = 9.45, -- aron
  [305] = 15.525, -- lairon
  [306] = 21.6, -- aggron
  [307] = 9.45, -- meditite
  [308] = 15.525, -- medicham
  [309] = 9.45, -- electrike
  [310] = 21.6, -- manectric
  [311] = 9.45, -- plusle
  [312] = 9.45, -- minun
  [313] = 9.45, -- volbeat
  [314] = 9.45, -- illumise
  [315] = 9.45, -- roselia
  [316] = 9.45, -- gulpin
  [317] = 21.6, -- swalot
  [318] = 15.525, -- carvanha
  [319] = 21.6, -- sharpedo
  [320] = 21.6, -- wailmer
  [321] = 32.4, -- wailord
  [322] = 9.45, -- numel
  [323] = 21.6, -- camerupt
  [324] = 9.45, -- torkoal
  [325] = 9.45, -- spoink
  [326] = 15.525, -- grumpig
  [327] = 15.525, -- spinda
  [328] = 9.45, -- trapinch
  [329] = 15.525, -- vibrava
  [330] = 21.6, -- flygon
  [331] = 9.45, -- cacnea
  [332] = 15.525, -- cacturne
  [333] = 5.4, -- swablu
  [334] = 9.45, -- altaria
  [335] = 15.525, -- zangoose
  [336] = 16.2, -- seviper
  [337] = 15.525, -- lunatone
  [338] = 15.525, -- solrock
  [339] = 9.45, -- barboach
  [340] = 15.525, -- whiscash
  [341] = 9.45, -- corphish
  [342] = 15.525, -- crawdaunt
  [343] = 9.45, -- baltoy
  [344] = 21.6, -- claydol
  [345] = 15.525, -- lileep
  [346] = 21.6, -- cradily
  [347] = 9.45, -- anorith
  [348] = 21.6, -- armaldo
  [349] = 9.45, -- feebas
  [350] = 12.15, -- milotic
  [351] = 9.45, -- castform
  [352] = 15.525, -- kecleon
  [353] = 9.45, -- shuppet
  [354] = 15.525, -- banette
  [355] = 15.525, -- duskull
  [356] = 21.6, -- dusclops
  [357] = 21.6, -- tropius
  [358] = 9.45, -- chimecho
  [359] = 15.525, -- absol
  [360] = 9.45, -- wynaut
  [361] = 9.45, -- snorunt
  [362] = 21.6, -- glalie
  [363] = 15.525, -- spheal
  [364] = 15.525, -- sealeo
  [365] = 15.525, -- walrein
  [366] = 9.45, -- clamperl
  [367] = 10.8, -- huntail
  [368] = 10.8, -- gorebyss
  [369] = 15.525, -- relicanth
  [370] = 9.45, -- luvdisc
  [371] = 9.45, -- bagon
  [372] = 15.525, -- shelgon
  [373] = 21.6, -- salamence
  [374] = 9.45, -- beldum
  [375] = 15.525, -- metang
  [376] = 21.6, -- metagross
  [377] = 21.6, -- regirock
  [378] = 21.6, -- regice
  [379] = 21.6, -- registeel
  [380] = 15.525, -- latias
  [381] = 21.6, -- latios
  [382] = 24.3, -- kyogre
  [383] = 21.6, -- groudon
  [384] = 32.4, -- rayquaza
  [385] = 9.45, -- jirachi
  [386] = 21.6, -- deoxys
}
-- Kanto Dex heights in decimetres, from the native Dex entries (rounded from
-- their feet/inches display). HD sheets measure only a body core; use the full
-- admitted silhouette so leaves/fins/gas cannot multiply that nominal height.
local KANTO_DEX_DM = {
  7,10,20,6,11,17,5,10,16,3, -- 1-10
  7,11,3,6,10,3,11,15,3,7, -- 11-20
  3,12,20,35,4,8,6,10,4,8, -- 21-30
  13,5,9,14,6,13,6,11,5,10, -- 31-40
  8,16,5,8,12,3,10,10,15,2, -- 41-50
  7,4,10,8,17,5,10,7,19,6, -- 51-60
  10,13,9,13,15,8,15,16,7,10, -- 61-70
  17,9,16,4,10,14,10,17,12,16, -- 71-80
  3,10,8,14,18,11,17,9,12,3, -- 81-90
  15,13,16,15,88,10,16,4,13,5, -- 91-100
  12,4,20,4,10,15,14,12,6,12, -- 101-110
  10,19,11,10,22,4,12,6,13,8, -- 111-120
  11,13,15,14,11,13,15,14,9,65, -- 121-130
  25,3,3,10,8,9,8,4,10,5, -- 131-140
  13,18,21,17,16,20,18,40,22,20, -- 141-150
  4, -- 151-151
}
-- Nominal length is not standing height for coiled snakes or horizontal seals.
-- These are projected silhouette heights in world units, not per-axis squash.
local KANTO_POSE_HEIGHT = {[23]=10.8,[24]=22.275,[79]=13.5,[86]=12.15,
  [87]=20.25,[95]=32.4,[147]=12.15,[148]=27}
local KANTO_WING_ENVELOPE = {[12]=true,[15]=true,[16]=true,[17]=true,[18]=true,
  [21]=true,[22]=true,[41]=true,[42]=true,[49]=true,[123]=true,
  [142]=true,[144]=true,[145]=true,[146]=true,[149]=true}
local function kantoHdBodyHeight(record)
  local dex=tonumber(record.dex)
  local dm=KANTO_DEX_DM[dex]
  local layout=type(record.animationCards)=='table' and record.animationCards.layout
  if not dm or type(layout)~='table' then return nil end
  local top,bottom,reference=tonumber(layout.top),tonumber(layout.bottom),tonumber(layout.referenceHeight)
  if not top or not bottom or not reference or reference<=0 or bottom<=top then return nil end
  -- Keep the previously accepted large mount presentations exactly as reviewed.
  if dex==6 then return 21.6 end
  if dex==130 then return 32.4 end
  local target=KANTO_POSE_HEIGHT[dex] or math.max(5.4,dm*1.35)
  if KANTO_WING_ENVELOPE[dex] then target=target*1.5 end
  -- One uniform scale preserves the source pose, aspect ratio and foot anchor.
  return target*reference/(bottom-top)
end

local function recordBodyHeight(record)
  if type(record)=="table" then
    local height=kantoHdBodyHeight(record)
    if height then return height end
  end
  if type(record)=="table" and type(record.animationCards)=="table"
      and type(record.animationCards.id)=="string"
      and record.animationCards.id:match("^hoenn%-original%-trs%-v1:") then
    local candidate=HOENN_QA_BODY_HEIGHTS[tonumber(record.dex)]
    if candidate then return candidate end
  end
  if type(record) == "table" and record.animationCards then
    local dex = tonumber(record.dex)
    if dex == 16 then return 5.4 end
    if dex == 23 then return 9.45 end -- Ekans: coiled body height, not uncoiled length.
    -- Same-camera review: measure the body, not raised wings or a stretched
    -- snake's nominal length. These values apply identically to both palettes.
    if dex == 41 then return 9.45 end
    if dex == 42 then return 12.15 end -- Golbat: wing envelope is not body height.
    if dex == 92 then return 8.1 end -- Gastly: gas extends beyond the measured sphere.
    if dex == 147 then return 12.15 end
    if dex == 130 then return 32.4 end
    -- Size-review-v2 candidate: proportionate body scaling, not per-axis
    -- compression. Pending same-camera native review for all Johto species.
    if dex == 152 then return 10.8 end -- Smaller body than Bayleef; leaf remains outside body reference.
    if dex == 156 then return 7.2 end -- Long low body; default medium height over-enlarged it.
    if dex == 162 then return 10.8 end -- Long low Furret: whole silhouette, not height-tier stretching.
    if dex == 165 then return 12.15 end -- First-stage ladybird body below evolved Ledian.
    if dex == 171 then return 8.1 end -- Swimming fish thickness is not its nominal full size.
    if dex == 180 then return 12.15 end -- Intermediate sheep stays below Ampharos, above Mareep.
    if dex == 190 then return 12.15 end -- Small monkey body; long hand-tail is preserved.
    if dex == 192 then return 12.15 end -- Flower body should not equal a child trainer's height.
    if dex == 193 then return 8.1 end -- Dragonfly body thickness; wings and abdomen remain full length.
    if dex == 208 then return 32.4 end -- Large serpent must not have a tiny head/body; compare with130.
    if dex == 223 then return 4.725 end -- Small fish thickness, not its complete fin envelope.
    -- Johto animated-card body calibration; the wings/cotton/fin envelope
    -- remains outside referenceHeight. Do not scale legacy or pixel cards.
    if dex == 169 then return 13.66875 end -- Golbat 12.15 * nominal 1.8/1.6.
    if dex == 178 then return 15.525 end -- Upright Xatu near the trainer.
    if dex == 189 then return 8.1 end -- Sphere is not the full cotton envelope.
    if dex == 226 then return 8.1 end -- Thin ray body, broad animated fins.
  end
  return ScaleProfiles.worldHeightForClass(record and record.scaleClass)
end

-- Match the readable 16-unit Crystal presentation in the overworld. HD
-- source padding must not shrink the body; retain larger authored encounters.
local WORLD_CONTEXT = {follower=true,city=true,grass=true,wilds_town=true}
local WORLD_MINIMUM = {pokemon_small=16,pokemon_medium=18,pokemon_large=21.6}
function ScaleProfiles.worldHeightForRecord(record, context)
  local height = recordBodyHeight(record)
  local cards = type(record)=="table" and record.animationCards
  if not (WORLD_CONTEXT[context] and type(cards)=="table") then return height end
  local minimum = WORLD_MINIMUM[record.scaleClass] or 18
  local layout = cards.layout
  local reference = type(layout)=="table" and tonumber(layout.referenceHeight)
  local top = type(layout)=="table" and tonumber(layout.top)
  local bottom = type(layout)=="table" and tonumber(layout.bottom)
  -- The Kanto HD path normalizes to the authored body envelope above.
  if tonumber(record.dex) and tonumber(record.dex)<=151 and reference
      and reference>0 and reference<math.huge and top and bottom
      and bottom>top and bottom<math.huge then
    minimum = minimum * reference / (bottom-top)
  end
  return math.max(height, minimum)
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
