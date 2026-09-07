-- Location-aware battle paintings for Pokemon Gold, Silver and Crystal.
--
-- `maps` contains the reviewed one-to-one assignments. `rules` cover every
-- remaining floor/room of a named complex (for example every Radio Tower or
-- Whirl Island floor), while `fallbacks` guarantee that ROM revisions and
-- fan-made maps still receive a valid arena instead of a white screen.

local function johto(slug, outdoor, voxelSky)
  return {
    path = "assets/battle/arena_johto-" .. slug .. ".compact.png",
    outdoor = outdoor and true or nil,
    voxelSky = (voxelSky or outdoor) and true or nil,
  }
end

local assets = {
  route1 = { path="assets/battle/arena_grass-route1.compact.png", outdoor=true },
  grass = { path="assets/battle/arena_grass-kanto-open.compact.png", outdoor=true },
  forest = { path="assets/battle/arena_forest-viridian.compact.png", outdoor=true },
  moonApproach = { path="assets/battle/arena_moon-approach-route3.compact.png", outdoor=true },
  moonExit = { path="assets/battle/arena_moon-exit-route4.compact.png", outdoor=true },
  rockWater = { path="assets/battle/arena_rock-water-route10.compact.png", outdoor=true },
  coast = { path="assets/battle/arena_coast-surf.compact.png", outdoor=true },
  coastTown = { path="assets/battle/arena_coast-cinnabar.compact.png", outdoor=true },
  cape = { path="assets/battle/arena_cape-route25.compact.png", outdoor=true },
  bridge = { path="assets/battle/nugget_bridge_a.compact.png", outdoor=true },
  routeGate = { path="assets/battle/arena_route2-forest-gate.compact.png", outdoor=true },
  vermilionGate = { path="assets/battle/arena_vermilion-gate-route11.compact.png", outdoor=true },
  indigoGate = { path="assets/battle/arena_indigo-gate-route22.compact.png", outdoor=true },
  indigoRoad = { path="assets/battle/arena_indigo-road-route23.compact.png", outdoor=true },
  safari = { path="assets/battle/arena_safari-kanto.compact.png", outdoor=true },
  cave = { path="assets/battle/arena_cave-rock-tunnel.compact.png" },
  moonCave = { path="assets/battle/arena_cave-mt-moon.compact.png" },
  wetCave = { path="assets/battle/arena_cave-seafoam.compact.png" },
  victoryCave = { path="assets/battle/arena_cave-victory-road.compact.png" },
  tower = { path="assets/battle/arena_tower-lavender.compact.png" },
  rocket = { path="assets/battle/arena_rocket-hideout.compact.png" },
  gameCorner = { path="assets/battle/arena_rocket-game-corner.compact.png" },
  industrial = { path="assets/battle/arena_industrial-silph.compact.png" },
  powerPlant = { path="assets/battle/arena_industrial-power-plant.compact.png" },
  lab = { path="assets/battle/arena_interior-oaks-lab.compact.png" },
  mansion = { path="assets/battle/arena_mansion-cinnabar.compact.png" },
  shipCabin = { path="assets/battle/arena_ship-cabins.compact.png" },
  shipCorridor = { path="assets/battle/arena_ship-corridor.compact.png" },
  shipBow = { path="assets/battle/arena_ship-bow.compact.png", outdoor=true },

  -- Johto receives unique authored scenery. Only routes 26-28 (already in
  -- Kanto) and the shared Indigo Plateau may reuse the established set.
  johtoRoute29 = johto("route29", true),
  johtoRoute30 = johto("route30", true),
  johtoRoute31 = johto("route31", true),
  johtoRoute32 = johto("route32", true),
  johtoRoute33 = johto("route33", true),
  johtoRoute34 = johto("route34", true),
  johtoRoute35 = johto("route35", true),
  johtoRoute36 = johto("route36", true),
  johtoRoute37 = johto("route37", true),
  johtoRoute38 = johto("route38", true),
  johtoRoute39 = johto("route39", true),
  johtoRoute40 = johto("route40", true),
  johtoRoute41 = johto("route41", true),
  johtoRoute42 = johto("route42", true),
  johtoRoute43 = johto("route43", true),
  johtoRoute44 = johto("route44", true),
  johtoRoute45 = johto("route45", true),
  johtoRoute46 = johto("route46", true),

  johtoNewBark = johto("new-bark-town", true),
  johtoCherrygrove = johto("cherrygrove-city", true),
  johtoViolet = johto("violet-city", true),
  johtoAzalea = johto("azalea-town", true),
  johtoGoldenrod = johto("goldenrod-city", true),
  johtoEcruteak = johto("ecruteak-city", true),
  johtoOlivine = johto("olivine-city", true),
  johtoCianwood = johto("cianwood-city", true),
  johtoMahogany = johto("mahogany-town", true),
  johtoLakeOfRage = johto("lake-of-rage", true),
  johtoBlackthorn = johto("blackthorn-city", true),
  johtoNationalPark = johto("national-park", true),
  johtoIlexForest = johto("ilex-forest", true),
  johtoRuinsOutside = johto("ruins-alph-outside", true),
  johtoSilverOutside = johto("silver-cave-outside", true),
  johtoBattleTowerOutside = johto("battle-tower-outside", true),

  violetGym = johto("gym-violet-flying", false, true),
  azaleaGym = johto("gym-azalea-bug", false, true),
  goldenrodGym = johto("gym-goldenrod-normal", false, true),
  ecruteakGym = { path="assets/battle/arena_johto-gym-ecruteak-ghost.compact.png" },
  cianwoodGym = johto("gym-cianwood-fighting", false, true),
  olivineGym = johto("gym-olivine-steel", false, true),
  mahoganyGym = johto("gym-mahogany-ice", false, true),
  blackthornGym = { path="assets/battle/arena_johto-gym-blackthorn-dragon.compact.png" },
  will = { path="assets/battle/arena_johto-league-will-psychic.compact.png" },
  koga = { path="assets/battle/arena_johto-league-koga-poison.compact.png" },
  bruno = { path="assets/battle/arena_league-bruno.compact.png" },
  karen = { path="assets/battle/arena_johto-league-karen-dark.compact.png" },
  lance = { path="assets/battle/arena_league-lance.compact.png" },
  champion = { path="assets/battle/arena_league-champion.compact.png" },
  battleTower = johto("battle-tower", false, true),

  johtoSproutTower = johto("sprout-tower"),
  johtoRuinsInterior = johto("ruins-alph-interior"),
  johtoUnionCave = johto("union-cave"),
  johtoSlowpokeWell = johto("slowpoke-well", false, true),
  johtoGoldenrodUnderground = johto("goldenrod-underground"),
  johtoRadioTower = johto("radio-tower"),
  johtoDanceTheater = johto("dance-theater"),
  johtoBurnedTower = johto("burned-tower", false, true),
  johtoTinTower = johto("tin-tower"),
  johtoTinTowerRoof = johto("tin-tower-roof", true),
  johtoOlivineLighthouse = johto("olivine-lighthouse", false, true),
  johtoMountMortar = johto("mount-mortar"),
  johtoRocketBase = johto("team-rocket-base"),
  johtoIcePath = johto("ice-path"),
  johtoDragonsDen = johto("dragons-den"),
  johtoDragonShrine = johto("dragon-shrine"),
  johtoDarkCave = johto("dark-cave"),
  johtoWhirlIslands = johto("whirl-islands", false, true),
  johtoLugiaChamber = johto("lugia-chamber"),
  johtoTohjoFalls = johto("tohjo-falls"),
  johtoVictoryRoad = johto("victory-road"),
  johtoSilverInterior = johto("silver-cave-interior"),
  johtoFastShip = johto("fast-ship", false, true),

  pewterGym = { path="assets/battle/arena_gym-pewter.compact.png" },
  ceruleanGym = { path="assets/battle/arena_gym-cerulean.compact.png" },
  vermilionGym = { path="assets/battle/arena_gym-vermilion.compact.png" },
  celadonGym = { path="assets/battle/arena_gym-celadon.compact.png" },
  fuchsiaGym = { path="assets/battle/arena_gym-fuchsia.compact.png" },
  saffronGym = { path="assets/battle/arena_gym-saffron.compact.png" },
  cinnabarGym = { path="assets/battle/arena_gym-cinnabar.compact.png" },
  viridianGym = { path="assets/battle/arena_gym-viridian.compact.png" },
  dojo = { path="assets/battle/arena_gym-fighting-dojo.compact.png" },
}

for _, spec in pairs(assets) do
  spec.width, spec.height = 1280, 800
  if spec.outdoor then spec.voxelSky = true end
end

-- These fourteen paintings deliberately expose narrow roof gaps, windows or
-- skylights.  Their largest safe opening is real but fragmented enough that
-- the generic 64x40 detector rejects it after its conservative one-cell
-- inset.  The rectangles below are reviewed directly against the bundled
-- 1280x800 PNG alpha channel (alpha <= 0.12 at every sampled point) and inset
-- another two source pixels on every edge.  Keeping this metadata beside the
-- authoritative asset records makes sun, moon, cloud and rainbow projection
-- deterministic without weakening the generic Injector-image acceptance
-- threshold.
local reviewedSkyApertures = {
  johtoAzalea = {
    x=0.2750000, y=0.0025000, width=0.5695313, height=0.1137500,
  }, -- source px 352,2 729x91
  battleTower = {
    x=0.4476562, y=0.0025000, width=0.1062500, height=0.0475000,
  }, -- source px 573,2 136x38
  johtoBurnedTower = {
    x=0.3195312, y=0.0025000, width=0.1007813, height=0.1475000,
  }, -- source px 409,2 129x118
  azaleaGym = {
    x=0.4265625, y=0.3562500, width=0.0664062, height=0.1212500,
  }, -- source px 546,285 85x97
  goldenrodGym = {
    x=0.4390625, y=0.0662500, width=0.1226562, height=0.1025000,
  }, -- source px 562,53 157x82
  mahoganyGym = {
    x=0.4679687, y=0.1462500, width=0.0648438, height=0.0275000,
  }, -- source px 599,117 83x22
  violetGym = {
    x=0.6765625, y=0.1925000, width=0.1265625, height=0.0812500,
  }, -- source px 866,154 162x65
  johtoOlivineLighthouse = {
    x=0.4039063, y=0.2625000, width=0.1414063, height=0.1825000,
  }, -- source px 517,210 181x146
  johtoRoute35 = {
    x=0.4437500, y=0.0025000, width=0.1468750, height=0.1075000,
  }, -- source px 568,2 188x86
  johtoRoute37 = {
    x=0.2054688, y=0.0025000, width=0.6421875, height=0.0912500,
  }, -- source px 263,2 822x73
  johtoRoute43 = {
    x=0.5125000, y=0.0025000, width=0.3632812, height=0.1162500,
  }, -- source px 656,2 465x93
  johtoRoute45 = {
    x=0.3156250, y=0.0025000, width=0.5656250, height=0.0987500,
  }, -- source px 404,2 724x79
  johtoSlowpokeWell = {
    x=0.4062500, y=0.0025000, width=0.1734375, height=0.0775000,
  }, -- source px 520,2 222x62
  johtoWhirlIslands = {
    x=0.4593750, y=0.0812500, width=0.1062500, height=0.1900000,
  }, -- source px 588,65 136x152
}
for key, aperture in pairs(reviewedSkyApertures) do
  assert(assets[key] and assets[key].voxelSky == true,
    "reviewed sky aperture without voxel-sky asset: " .. tostring(key))
  assets[key].skyAperture = aperture
end

local maps = {}
local function add(ids, key)
  assert(assets[key], "unknown arena asset key: " .. tostring(key))
  for _, id in ipairs(ids) do maps[id] = key end
end

-- Every numbered route in the combined GSC world is assigned explicitly.
local routes = {
  [1]="route1", [2]="routeGate", [3]="moonApproach", [4]="moonExit",
  [5]="grass", [6]="grass", [7]="grass", [8]="grass", [9]="grass",
  [10]="rockWater", [11]="vermilionGate", [12]="grass", [13]="grass",
  [14]="grass", [15]="grass", [16]="grass", [17]="grass", [18]="grass",
  [19]="coast", [20]="coast", [21]="coast", [22]="indigoGate",
  [23]="indigoRoad", [24]="bridge", [25]="cape",
  [26]="indigoRoad", [27]="rockWater", [28]="indigoRoad",
  [29]="johtoRoute29", [30]="johtoRoute30", [31]="johtoRoute31",
  [32]="johtoRoute32", [33]="johtoRoute33", [34]="johtoRoute34",
  [35]="johtoRoute35", [36]="johtoRoute36", [37]="johtoRoute37",
  [38]="johtoRoute38", [39]="johtoRoute39", [40]="johtoRoute40",
  [41]="johtoRoute41", [42]="johtoRoute42", [43]="johtoRoute43",
  [44]="johtoRoute44", [45]="johtoRoute45", [46]="johtoRoute46",
}
for number, key in pairs(routes) do maps["ROUTE_" .. number] = key end
maps.ROUTE_10_NORTH, maps.ROUTE_10_SOUTH = "rockWater", "rockWater"

-- Johto cities and open landmark surfaces.
add({"NEW_BARK_TOWN"}, "johtoNewBark")
add({"CHERRYGROVE_CITY"}, "johtoCherrygrove")
add({"VIOLET_CITY"}, "johtoViolet")
add({"AZALEA_TOWN"}, "johtoAzalea")
add({"GOLDENROD_CITY"}, "johtoGoldenrod")
add({"ECRUTEAK_CITY"}, "johtoEcruteak")
add({"OLIVINE_CITY", "OLIVINE_PORT"}, "johtoOlivine")
add({"CIANWOOD_CITY"}, "johtoCianwood")
add({"MAHOGANY_TOWN"}, "johtoMahogany")
add({"LAKE_OF_RAGE"}, "johtoLakeOfRage")
add({"BLACKTHORN_CITY"}, "johtoBlackthorn")
add({"NATIONAL_PARK", "NATIONAL_PARK_BUG_CONTEST"}, "johtoNationalPark")
add({"ILEX_FOREST"}, "johtoIlexForest")
add({"RUINS_OF_ALPH_OUTSIDE"}, "johtoRuinsOutside")
add({"SILVER_CAVE_OUTSIDE"}, "johtoSilverOutside")
add({"BATTLE_TOWER_OUTSIDE"}, "johtoBattleTowerOutside")
add({"VERMILION_PORT"}, "shipBow")

-- Johto Gyms, Elite Four and Crystal's Battle Tower.
add({"VIOLET_GYM"}, "violetGym")
add({"AZALEA_GYM"}, "azaleaGym")
add({"GOLDENROD_GYM"}, "goldenrodGym")
add({"ECRUTEAK_GYM"}, "ecruteakGym")
add({"CIANWOOD_GYM"}, "cianwoodGym")
add({"OLIVINE_GYM"}, "olivineGym")
add({"MAHOGANY_GYM"}, "mahoganyGym")
add({"BLACKTHORN_GYM_1F", "BLACKTHORN_GYM_2F"}, "blackthornGym")
add({"DRAGONS_DEN_1F", "DRAGONS_DEN_B1F"}, "johtoDragonsDen")
add({"DRAGON_SHRINE"}, "johtoDragonShrine")
add({"DANCE_THEATER"}, "johtoDanceTheater")
add({"WILLS_ROOM"}, "will")
add({"KOGAS_ROOM"}, "koga")
add({"BRUNOS_ROOM"}, "bruno")
add({"KARENS_ROOM"}, "karen")
add({"LANCES_ROOM"}, "lance")
add({"HALL_OF_FAME"}, "champion")
add({"BATTLE_TOWER_1F", "BATTLE_TOWER_BATTLE_ROOM",
     "BATTLE_TOWER_ELEVATOR", "BATTLE_TOWER_HALLWAY"}, "battleTower")

-- Johto's complete battle-capable complexes. Prefix rules below catch every
-- floor too, but the principal floors are kept explicit and auditable here.
add({"BURNED_TOWER_1F", "BURNED_TOWER_B1F"}, "johtoBurnedTower")
add({"SPROUT_TOWER_1F", "SPROUT_TOWER_2F", "SPROUT_TOWER_3F"},
    "johtoSproutTower")
add({"TIN_TOWER_1F", "TIN_TOWER_2F", "TIN_TOWER_3F", "TIN_TOWER_4F",
     "TIN_TOWER_5F", "TIN_TOWER_6F", "TIN_TOWER_7F", "TIN_TOWER_8F",
     "TIN_TOWER_9F", "WISE_TRIOS_ROOM"}, "johtoTinTower")
add({"TIN_TOWER_ROOF"}, "johtoTinTowerRoof")
add({"DARK_CAVE_BLACKTHORN_ENTRANCE", "DARK_CAVE_VIOLET_ENTRANCE"},
    "johtoDarkCave")
add({"MOUNT_MORTAR_1F_INSIDE", "MOUNT_MORTAR_1F_OUTSIDE",
     "MOUNT_MORTAR_2F_INSIDE", "MOUNT_MORTAR_B1F"}, "johtoMountMortar")
add({"ICE_PATH_1F", "ICE_PATH_B1F", "ICE_PATH_B2F_BLACKTHORN_SIDE",
     "ICE_PATH_B2F_MAHOGANY_SIDE", "ICE_PATH_B3F"}, "johtoIcePath")
add({"SLOWPOKE_WELL_B1F", "SLOWPOKE_WELL_B2F"}, "johtoSlowpokeWell")
add({"UNION_CAVE_1F", "UNION_CAVE_B1F", "UNION_CAVE_B2F"},
    "johtoUnionCave")
add({"TOHJO_FALLS"}, "johtoTohjoFalls")
add({"WHIRL_ISLAND_NE", "WHIRL_ISLAND_NW", "WHIRL_ISLAND_SE",
     "WHIRL_ISLAND_SW", "WHIRL_ISLAND_CAVE", "WHIRL_ISLAND_B1F",
     "WHIRL_ISLAND_B2F"}, "johtoWhirlIslands")
add({"WHIRL_ISLAND_LUGIA_CHAMBER"}, "johtoLugiaChamber")
add({"SILVER_CAVE_ROOM_1", "SILVER_CAVE_ROOM_2", "SILVER_CAVE_ROOM_3",
     "SILVER_CAVE_ITEM_ROOMS"}, "johtoSilverInterior")
add({"VICTORY_ROAD"}, "johtoVictoryRoad")
add({"RUINS_OF_ALPH_INNER_CHAMBER", "RUINS_OF_ALPH_AERODACTYL_CHAMBER",
     "RUINS_OF_ALPH_AERODACTYL_ITEM_ROOM", "RUINS_OF_ALPH_AERODACTYL_WORD_ROOM",
     "RUINS_OF_ALPH_HO_OH_CHAMBER", "RUINS_OF_ALPH_HO_OH_ITEM_ROOM",
     "RUINS_OF_ALPH_HO_OH_WORD_ROOM", "RUINS_OF_ALPH_KABUTO_CHAMBER",
     "RUINS_OF_ALPH_KABUTO_ITEM_ROOM", "RUINS_OF_ALPH_KABUTO_WORD_ROOM",
     "RUINS_OF_ALPH_OMANYTE_CHAMBER", "RUINS_OF_ALPH_OMANYTE_ITEM_ROOM",
     "RUINS_OF_ALPH_OMANYTE_WORD_ROOM"}, "johtoRuinsInterior")
add({"TEAM_ROCKET_BASE_B1F", "TEAM_ROCKET_BASE_B2F", "TEAM_ROCKET_BASE_B3F",
     "UNDERGROUND_PATH"}, "johtoRocketBase")
add({"GOLDENROD_UNDERGROUND", "GOLDENROD_UNDERGROUND_SWITCH_ROOM_ENTRANCES",
     "GOLDENROD_UNDERGROUND_WAREHOUSE"}, "johtoGoldenrodUnderground")
add({"RADIO_TOWER_1F", "RADIO_TOWER_2F", "RADIO_TOWER_3F",
     "RADIO_TOWER_4F", "RADIO_TOWER_5F"}, "johtoRadioTower")
add({"LAV_RADIO_TOWER_1F"}, "industrial")
add({"OLIVINE_LIGHTHOUSE_1F", "OLIVINE_LIGHTHOUSE_2F",
     "OLIVINE_LIGHTHOUSE_3F", "OLIVINE_LIGHTHOUSE_4F",
     "OLIVINE_LIGHTHOUSE_5F", "OLIVINE_LIGHTHOUSE_6F"},
    "johtoOlivineLighthouse")
add({"FAST_SHIP_1F", "FAST_SHIP_B1F"}, "johtoFastShip")
add({"FAST_SHIP_CABINS_NNW_NNE_NE", "FAST_SHIP_CABINS_SE_SSE_CAPTAINS_CABIN",
     "FAST_SHIP_CABINS_SW_SSW_NW"}, "johtoFastShip")

-- Kanto assignments are reused from the established Arena Scenery set.
add({"PALLET_TOWN", "VIRIDIAN_CITY"}, "route1")
add({"PEWTER_CITY"}, "moonApproach")
add({"CERULEAN_CITY"}, "bridge")
add({"VERMILION_CITY"}, "vermilionGate")
add({"LAVENDER_TOWN"}, "rockWater")
add({"CELADON_CITY", "SAFFRON_CITY"}, "grass")
add({"FUCHSIA_CITY", "SAFARI_ZONE_BETA"}, "safari")
add({"CINNABAR_ISLAND"}, "coastTown")
add({"PEWTER_GYM"}, "pewterGym")
add({"CERULEAN_GYM"}, "ceruleanGym")
add({"VERMILION_GYM"}, "vermilionGym")
add({"CELADON_GYM"}, "celadonGym")
add({"FUCHSIA_GYM"}, "fuchsiaGym")
add({"SAFFRON_GYM"}, "saffronGym")
add({"SEAFOAM_GYM"}, "cinnabarGym")
add({"VIRIDIAN_GYM"}, "viridianGym")
add({"FIGHTING_DOJO"}, "dojo")
add({"DIGLETTS_CAVE", "ROCK_TUNNEL_1F", "ROCK_TUNNEL_B1F", "MOUNT_MOON"}, "cave")
add({"POWER_PLANT"}, "powerPlant")
add({"CELADON_GAME_CORNER", "GOLDENROD_GAME_CORNER"}, "gameCorner")
add({"OAKS_LAB", "ELMS_LAB"}, "lab")
add({"TRAINER_HOUSE_B1F"}, "battleTower")

-- Longest/specific prefixes first. These cover every room in each complex,
-- including Crystal-only floors and harmless future aliases.
local rules = {
  { prefix="BATTLE_TOWER_", key="battleTower" },
  { prefix="WHIRL_ISLAND_", key="johtoWhirlIslands" },
  { prefix="SILVER_CAVE_", key="johtoSilverInterior" },
  { prefix="RUINS_OF_ALPH_", key="johtoRuinsInterior" },
  { prefix="ICE_PATH_", key="johtoIcePath" },
  { prefix="RADIO_TOWER_", key="johtoRadioTower" },
  { prefix="LAV_RADIO_TOWER_", key="industrial" },
  { prefix="OLIVINE_LIGHTHOUSE_", key="johtoOlivineLighthouse" },
  { prefix="TIN_TOWER_", key="johtoTinTower" },
  { prefix="SPROUT_TOWER_", key="johtoSproutTower" },
  { prefix="BURNED_TOWER_", key="johtoBurnedTower" },
  { prefix="TEAM_ROCKET_BASE_", key="johtoRocketBase" },
  { prefix="GOLDENROD_UNDERGROUND", key="johtoGoldenrodUnderground" },
  { prefix="FAST_SHIP_CABINS_", key="johtoFastShip" },
  { prefix="FAST_SHIP_", key="johtoFastShip" },
  { prefix="MOUNT_MORTAR_", key="johtoMountMortar" },
  { prefix="DARK_CAVE_", key="johtoDarkCave" },
  { prefix="UNION_CAVE_", key="johtoUnionCave" },
  { prefix="SLOWPOKE_WELL_", key="johtoSlowpokeWell" },
  { prefix="DRAGONS_DEN_", key="johtoDragonsDen" },
  { prefix="ROUTE_", contains="_GATE", key="routeGate" },
  { prefix="ROUTE_", key="grass" },
  { contains="GYM", key="battleTower" },
  { contains="TOWER", key="tower" },
  { contains="CAVE", key="cave" },
  { contains="FOREST", key="forest" },
  { contains="PARK", key="forest" },
  { contains="SHIP", key="shipCorridor" },
  { contains="PORT", key="shipBow" },
  { contains="UNDERGROUND", key="rocket" },
  { contains="ROCKET", key="rocket" },
  { contains="GAME_CORNER", key="gameCorner" },
  { contains="LAB", key="lab" },
  { contains="MANSION", key="mansion" },
  { contains="DEPT_STORE", key="industrial" },
  { contains="STATION", key="industrial" },
  { contains="CITY", key="grass" },
  { contains="TOWN", key="grass" },
}

return {
  assets = assets,
  maps = maps,
  rules = rules,
  fallbacks = {
    ROUTE="grass", TOWN="grass", CAVE="cave", DUNGEON="cave",
    GATE="routeGate", INDOOR="lab", OUTDOOR="grass", default="lab",
  },
}
