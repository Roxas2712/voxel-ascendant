-- FRLG-like DISCS are selected by VASC's existing location profile.  The
-- exact-map table only narrows profiles whose generic family is too broad;
-- no random disk family is ever borrowed from an unrelated location.

return {
  width = 128,
  height = 128,
  assets = {
    building = "assets/battle_disks/disk_building-frlg.compact.png",
    grass = "assets/battle_disks/disk_grass-frlg.compact.png",
    water = "assets/battle_disks/disk_water-frlg.compact.png",
    cave = "assets/battle_disks/disk_cave-frlg.compact.png",
    pond = "assets/battle_disks/disk_pond-frlg.compact.png",
    ice = "assets/battle_disks/disk_ice-frlg.compact.png",
    sand = "assets/battle_disks/disk_sand-frlg.compact.png",
    indoor = "assets/battle_disks/disk_indoor-frlg.compact.png",
    long_grass = "assets/battle_disks/disk_long-grass-frlg.compact.png",
    mountain = "assets/battle_disks/disk_mountain-frlg.compact.png",
  },
  -- A white procedural void, lightly material-tinted to match the selected
  -- disk.  These are renderer colours, not full-frame bitmap backdrops.
  backgrounds = {
    building={.91, .94, .89}, grass={.84, .94, .79},
    water={.78, .91, .98}, cave={.84, .79, .70},
    pond={.77, .93, .88}, ice={.87, .96, 1.00},
    sand={.98, .91, .72}, indoor={.91, .85, .97},
    long_grass={.79, .91, .76}, mountain={.86, .85, .82},
  },
  profiles = {
    grass="grass", city="building", forest="long_grass", coast="water",
    cave="cave", mansion="building", tower="indoor",
    industrial="building", rocket="indoor", safari="sand",
    ship="building", gym="indoor", interior="building",
    league_ice="ice", league_rock="mountain", league_ghost="indoor",
    league_dragon="indoor", league_champion="indoor",
    route2_gate="long_grass", moon_approach="mountain",
    moon_exit="mountain", rock_water="pond", vermilion_gate="building",
    indigo_gate="mountain", indigo_road="mountain",
    nugget_bridge="pond", cape="pond", cerulean_canal="pond",
  },
  maps = {
    SEAFOAM_ISLANDS_1F="ice", SEAFOAM_ISLANDS_B1F="ice",
    SEAFOAM_ISLANDS_B2F="ice", SEAFOAM_ISLANDS_B3F="ice",
    SEAFOAM_ISLANDS_B4F="ice",
    VICTORY_ROAD_1F="mountain", VICTORY_ROAD_2F="mountain",
    VICTORY_ROAD_3F="mountain",
    LORELEIS_ROOM="ice", BRUNOS_ROOM="mountain",
    ROUTE_19="water", ROUTE_20="water", ROUTE_21="water",
    CINNABAR_ISLAND="water",
    VIRIDIAN_FOREST="long_grass",
  },
}
