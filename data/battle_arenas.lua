-- Fixed Gen1 battle compositions, in native map cells.
-- Four-actor courts reserve walkable floor and camera sightlines for both
-- Pokemon AND trainers. Select the nearest safe spot at the current height.
-- The regional catalogue passed native terrain/prop clearance; representative
-- views are reviewed separately. No camera or gameplay coordinates are saved
-- into the overworld. Manual orbit, pitch and zoom remain available.
-- Empty fixed entries deliberately choose the caller's room-specific 3D
-- alternative where no complete court/camera can fit safely (small cabins,
-- planted/pool gyms). They never reopen the arbitrary runtime search.
-- Entries are revalidated at runtime so other map mods cannot bypass safety.
-- Tiny ponds without room for the full court explicitly map water encounters
-- to Terrarium. Height-qualified courts cover LOCAL/WORLD as well as FLAT.
-- Shared by wild and trainer fights. Surface-tagged sea courts are reserved
-- for surfing; fixed courts decline to the caller's 3D fallback if obstructed.
return {
  -- KASC encounter maps: same terrain/surface validation as native Kanto.
  -- Cramped HEVO corridors use a safe chamber of the same dungeon.
  ["KANTO_ASCENDANT_DRIFTGLASS"] = { adaptive=false, fixed=true, spots={
    { x=13, y=6, shape="court_north", cam="court_aisle", surface="land" },
    { x=9, y=10, shape="court_west", cam="court_aisle", surface="land" },
    { x=6, y=14, shape="court_east", cam="compact", surface="land" },
    { x=14, y=0, shape="court_small_west", cam="compact", surface="water" },
    { x=0, y=10, shape="court_small_south", cam="compact", surface="water" },
    { x=8, y=18, shape="court_small_east", cam="compact", surface="water" },
  } },
  ["KANTO_ASCENDANT_PRISM_GROTTO"] = { adaptive=false, fixed=true, spots={
    { x=5, y=3, shape="court_east", cam="court_aisle", surface="land" },
    { x=2, y=8, shape="court_east", cam="court_aisle", surface="land" },
    { x=9, y=12, shape="court_tight_east", cam="compact", surface="land" },
  } },
  ["KA_BALD_CREW_MT_MOON_1F"] = { adaptive=false, fixed=true, spots={
    { x=5, y=6, shape="court_north", cam="court_aisle", surface="land" },
    { x=10, y=17, shape="court_east", cam="court_aisle", surface="land" },
    { x=8, y=28, shape="court_east", cam="compact", surface="land" },
  } },
  ["KA_HABITAT_CHESPIN_PROTOTYPE"] = { adaptive=false, fixed=true, spots={
    { x=16, y=3, shape="court_north", cam="compact", surface="land" },
    { x=18, y=11, shape="court_small_north", cam="compact", surface="land" },
    { x=6, y=16, shape="court_east", cam="compact", surface="land" },
  } },
  ["KA_HABITAT_CHIMCHAR_PROTOTYPE"] = { adaptive=false, fixed=true, spots={
    { x=6, y=4, shape="court_east", cam="court_aisle", surface="land" },
    { x=11, y=9, shape="court_east", cam="court_aisle", surface="land" },
    { x=20, y=10, shape="court_small_south", cam="wide", surface="land" },
  } },
  ["KA_HABITAT_FENNEKIN_PROTOTYPE"] = { adaptive=false, fixed=true, spots={
    { x=15, y=2, shape="court_tight_east", cam="compact", surface="land" },
    { x=13, y=8, shape="court_small_east", cam="compact", surface="land" },
    { x=18, y=10, shape="court_small_south", cam="compact", surface="land" },
  } },
  ["KA_HABITAT_FROAKIE_PROTOTYPE"] = { adaptive=false, fixed=true, spots={
    { x=14, y=3, shape="court_north", cam="court_aisle", surface="land" },
    { x=8, y=8, shape="court_east", cam="court_aisle", surface="land" },
    { x=10, y=14, shape="court_small_east", cam="compact", surface="land" },
    { x=19, y=10, shape="court_small_north", cam="compact", surface="water" },
    { x=2, y=11, shape="court_small_north", cam="court_aisle", surface="water" },
    { x=16, y=15, shape="court_tight_east", cam="compact", surface="water" },
  } },
  ["KA_HABITAT_LITTEN_PROTOTYPE"] = { adaptive=false, fixed=true, spots={
    { x=17, y=2, shape="court_tight_east", cam="compact", surface="land" },
    { x=13, y=8, shape="court_small_north", cam="court_aisle", surface="land" },
    { x=17, y=16, shape="court_tight_east", cam="compact", surface="land" },
  } },
  ["KA_HABITAT_OSHAWOTT_PROTOTYPE"] = { adaptive=false, fixed=true, spots={
    { x=8, y=4, shape="court_east", cam="court_aisle", surface="land" },
    { x=11, y=8, shape="court_small_east", cam="court_aisle", surface="land" },
    { x=16, y=6, shape="court_small_north", cam="court_aisle", surface="land" },
    { x=23, y=2, shape="court_small_north", cam="compact", surface="water" },
    { x=3, y=12, shape="court_east", cam="court_aisle", surface="water" },
    { x=1, y=17, shape="court_east", cam="compact", surface="water" },
  } },
  ["KA_HABITAT_PIPLUP_PROTOTYPE"] = { adaptive=false, fixed=true, spots={
    { x=20, y=4, shape="court_north", cam="compact", surface="land" },
    { x=2, y=9, shape="court_east", cam="court_aisle", surface="land" },
    { x=14, y=13, shape="court_small_north", cam="court_aisle", surface="land" },
    { x=3, y=12, shape="court_small_north", cam="court_aisle", surface="water" },
    { x=17, y=13, shape="court_small_east", cam="wide", surface="water" },
    { x=17, y=17, shape="court_small_east", cam="compact", surface="water" },
  } },
  ["KA_HABITAT_POPPLIO_PROTOTYPE"] = { adaptive=false, fixed=true, spots={
    { x=17, y=3, shape="court_north", cam="court_aisle", surface="land" },
    { x=7, y=9, shape="court_east", cam="court_aisle", surface="land" },
    { x=15, y=14, shape="court_tight_east", cam="compact", surface="land" },
    { x=22, y=2, shape="court_north", cam="compact", surface="water" },
    { x=23, y=12, shape="court_small_north", cam="court_aisle", surface="water" },
    { x=3, y=17, shape="court_tight_east", cam="compact", surface="water" },
  } },
  ["KA_HABITAT_ROWLET_PROTOTYPE"] = { adaptive=false, fixed=true, spots={
    { x=17, y=3, shape="court_tight_east", cam="wide", surface="land" },
    { x=6, y=9, shape="court_east", cam="court_aisle", surface="land" },
    { x=14, y=14, shape="court_east", cam="compact", surface="land" },
  } },
  ["KA_HABITAT_SNIVY_PROTOTYPE"] = { adaptive=false, fixed=true, spots={
    { x=19, y=3, shape="court_north", cam="court_aisle", surface="land" },
    { x=8, y=9, shape="court_east", cam="court_aisle", surface="land" },
    { x=14, y=14, shape="court_east", cam="compact", surface="land" },
  } },
  ["KA_HABITAT_TEPIG_PROTOTYPE"] = { adaptive=false, fixed=true, spots={
    { x=8, y=4, shape="court_east", cam="court_aisle", surface="land" },
    { x=16, y=9, shape="court_north", cam="compact", surface="land" },
    { x=16, y=14, shape="court_east", cam="compact", surface="land" },
  } },
  ["KA_HABITAT_TURTWIG_PROTOTYPE"] = { adaptive=false, fixed=true, spots={
    { x=20, y=3, shape="court_small_north", cam="compact", surface="land" },
    { x=20, y=11, shape="court_small_north", cam="compact", surface="land" },
    { x=6, y=16, shape="court_east", cam="compact", surface="land" },
  } },
  ["KA_HEVO_BLUE_FROST_HALL"] = { adaptive=false, fixed=true, spots={
    { x=26, y=16, shape="court_tight_west", cam="compact", surface="land" },
    { x=13, y=24, shape="court_tight_east", cam="compact", surface="land" },
    { x=5, y=29, shape="court_small_east", cam="court_aisle", surface="land" },
  } },
  ["KA_HEVO_BLUE_FROST_THRESHOLD"] = { adaptive=false, fixed=true, spots={
    { x=21, y=6, shape="court_tight_east", cam="compact", surface="land" },
    { x=16, y=13, shape="court_north", cam="compact", surface="land" },
    { x=3, y=26, shape="court_small_east", cam="court_aisle", surface="land" },
  } },
  ["KA_HEVO_BLUE_GLACIER_MAZE"] = { adaptive=false, fixed=true, spots={
    { x=19, y=8, shape="court_east", cam="court_aisle", surface="land" },
    { x=4, y=18, shape="court_east", cam="court_aisle", surface="land" },
    { x=14, y=27, shape="court_east", cam="court_aisle", surface="land" },
  } },
  ["KA_HEVO_BLUE_KYOGRE_SHRINE"] = { adaptive=false, fixed=true, spots={
    { x=16, y=6, shape="court_east", cam="compact", surface="land" },
    { x=20, y=6, shape="court_small_east", cam="compact", surface="land" },
    { x=3, y=26, shape="court_east", cam="court_aisle", surface="land" },
  } },
  ["KA_HEVO_BLUE_TIDAL_DEPTHS"] = { adaptive=false, fixed=true, spots={
    { x=36, y=10, shape="court_north", cam="court_aisle", surface="land" },
    { x=41, y=18, shape="court_small_north", cam="court_aisle", surface="land" },
    { x=3, y=28, shape="court_east", cam="court_aisle", surface="land" },
    { x=33, y=4, shape="court_small_east", cam="wide", surface="water" },
    { x=48, y=16, shape="court_north", cam="court_aisle", surface="water" },
    { x=32, y=29, shape="court_east", cam="court_aisle", surface="water" },
  } },
  ["KA_HEVO_GREEN_GROVE"] = { adaptive=false, fixed=true, fallbacks={water="terarrium"}, spots={
    { map="KA_HEVO_RAYQUAZA_CHAMBER", x=8, y=7, shape="court_small_south", cam="court_aisle", surface="land" },
    { map="KA_HEVO_RAYQUAZA_CHAMBER", x=5, y=11, shape="court_tight_west", cam="wide", surface="land" },
  } },
  ["KA_HEVO_GREEN_MIST"] = { adaptive=false, fixed=true, spots={
    { map="KA_HEVO_RAYQUAZA_CHAMBER", x=8, y=7, shape="court_small_south", cam="court_aisle", surface="land" },
    { map="KA_HEVO_RAYQUAZA_CHAMBER", x=5, y=11, shape="court_tight_west", cam="wide", surface="land" },
  } },
  ["KA_HEVO_GREEN_RAYQUAZA_SHRINE"] = { adaptive=false, fixed=true, fallbacks={water="terarrium"}, spots={
    { map="KA_HEVO_RAYQUAZA_CHAMBER", x=8, y=7, shape="court_small_south", cam="court_aisle", surface="land" },
    { map="KA_HEVO_RAYQUAZA_CHAMBER", x=5, y=11, shape="court_tight_west", cam="wide", surface="land" },
  } },
  ["KA_HEVO_GREEN_THRESHOLD"] = { adaptive=false, fixed=true, spots={
    { map="KA_HEVO_RAYQUAZA_CHAMBER", x=8, y=7, shape="court_small_south", cam="court_aisle", surface="land" },
    { map="KA_HEVO_RAYQUAZA_CHAMBER", x=5, y=11, shape="court_tight_west", cam="wide", surface="land" },
  } },
  ["KA_HEVO_GROUDON_CHAMBER"] = { adaptive=false, fixed=true, spots={
    { x=5, y=6, shape="court_north", cam="court_aisle", surface="land" },
    { x=12, y=8, shape="court_small_south", cam="wide", surface="land" },
    { x=15, y=16, shape="court_tight_east", cam="compact", surface="land" },
  } },
  ["KA_HEVO_KYOGRE_CHAMBER"] = { adaptive=false, fixed=true, spots={
    { x=6, y=5, shape="court_small_north", cam="court_aisle", surface="land" },
    { x=7, y=10, shape="court_small_north", cam="court_aisle", surface="land" },
    { x=9, y=16, shape="court_east", cam="compact", surface="land" },
    { x=10, y=6, shape="court_small_north", cam="court_aisle", surface="water" },
    { x=10, y=14, shape="court_small_east", cam="court_aisle", surface="water" },
  } },
  ["KA_HEVO_RAYQUAZA_CHAMBER"] = { adaptive=false, fixed=true, spots={
    { x=8, y=7, shape="court_small_south", cam="court_aisle", surface="land" },
    { x=5, y=11, shape="court_tight_west", cam="wide", surface="land" },
    { x=12, y=16, shape="court_east", cam="compact", surface="land" },
  } },
  ["KA_HEVO_RED_ABYSS"] = { adaptive=false, fixed=true, spots={
    { map="KA_HEVO_GROUDON_CHAMBER", x=5, y=6, shape="court_north", cam="court_aisle", surface="land" },
    { map="KA_HEVO_GROUDON_CHAMBER", x=12, y=8, shape="court_small_south", cam="wide", surface="land" },
  } },
  ["KA_HEVO_RED_LOWER"] = { adaptive=false, fixed=true, spots={
    { x=18, y=17, shape="court_small_north", cam="court_aisle", surface="water" },
    { x=21, y=20, shape="court_east", cam="court_aisle", surface="water" },
    { x=33, y=22, shape="court_small_east", cam="compact", surface="water" },
    { map="KA_HEVO_GROUDON_CHAMBER", x=5, y=6, shape="court_north", cam="court_aisle", surface="land" },
    { map="KA_HEVO_GROUDON_CHAMBER", x=12, y=8, shape="court_small_south", cam="wide", surface="land" },
  } },
  ["KA_HEVO_RED_RECOVERY"] = { adaptive=false, fixed=true, spots={
    { map="KA_HEVO_GROUDON_CHAMBER", x=5, y=6, shape="court_north", cam="court_aisle", surface="land" },
    { map="KA_HEVO_GROUDON_CHAMBER", x=12, y=8, shape="court_small_south", cam="wide", surface="land" },
  } },
  ["KA_HEVO_RED_SHRINE"] = { adaptive=false, fixed=true, spots={
    { map="KA_HEVO_GROUDON_CHAMBER", x=5, y=6, shape="court_north", cam="court_aisle", surface="land" },
    { map="KA_HEVO_GROUDON_CHAMBER", x=12, y=8, shape="court_small_south", cam="wide", surface="land" },
  } },
  ["KA_HEVO_RED_UPPER"] = { adaptive=false, fixed=true, spots={
    { map="KA_HEVO_GROUDON_CHAMBER", x=5, y=6, shape="court_north", cam="court_aisle", surface="land" },
    { map="KA_HEVO_GROUDON_CHAMBER", x=12, y=8, shape="court_small_south", cam="wide", surface="land" },
  } },
  ["KA_HEVO_SHARED_SEALED_ANTECHAMBER"] = { adaptive=false, fixed=true, spots={
    { x=15, y=10, shape="court_small_east", cam="compact", surface="land" },
    { x=12, y=14, shape="court_east", cam="compact", surface="land" },
    { x=3, y=18, shape="court_tight_east", cam="wide", surface="land" },
  } },
  ["KA_HEVO_TUNNEL_ALL"] = { adaptive=false, fixed=true, spots={
    { x=26, y=6, shape="court_north", cam="compact", surface="land" },
    { x=6, y=9, shape="court_north", cam="compact", surface="land" },
    { x=26, y=16, shape="court_small_south", cam="compact", surface="land" },
  } },
  ["KA_HOENN_ANCIENT_TOMB"] = { adaptive=false, fixed=true, spots={
    { x=10, y=6, shape="court_north", cam="compact", surface="land" },
    { x=16, y=10, shape="court_small_south", cam="court_aisle", surface="land" },
    { x=13, y=14, shape="court_tight_east", cam="compact", surface="land" },
  } },
  ["KA_HOENN_BIRTH_ISLAND"] = { adaptive=false, fixed=true, spots={
    { x=2, y=4, shape="court_north", cam="court_aisle", surface="land", terrain="flat" },
    { x=2, y=8, shape="court_east", cam="court_aisle", surface="land" },
    { x=2, y=12, shape="court_east", cam="compact", surface="land" },
    { x=2, y=4, shape="court_east", cam="court_aisle", surface="land", terrain="local" },
    { x=2, y=4, shape="court_east", cam="court_aisle", surface="land", terrain="world" },
  } },
  ["KA_HOENN_DESERT_RUINS"] = { adaptive=false, fixed=true, spots={
    { x=9, y=5, shape="court_north", cam="compact", surface="land" },
    { x=18, y=12, shape="court_small_south", cam="compact", surface="land" },
    { x=15, y=16, shape="court_tight_west", cam="court_aisle", surface="land" },
  } },
  ["KA_HOENN_ISLAND_CAVE"] = { adaptive=false, fixed=true, spots={
    { x=6, y=6, shape="court_north", cam="court_aisle", surface="land" },
    { x=18, y=10, shape="court_north", cam="compact", surface="land" },
    { x=15, y=16, shape="court_tight_east", cam="compact", surface="land" },
    { x=12, y=10, shape="court_small_north", cam="court_aisle", surface="water" },
  } },
  ["KA_HOENN_WISH_CHAMBER"] = { adaptive=false, fixed=true, spots={
    { x=9, y=5, shape="court_north", cam="compact", surface="land" },
    { x=4, y=9, shape="court_east", cam="court_aisle", surface="land" },
    { x=7, y=12, shape="court_tight_east", cam="compact", surface="land" },
  } },
  ["KA_JOHTO_GATE_HALL"] = { adaptive=false, fixed=true, spots={
    { x=10, y=13, shape="court_north", cam="court_aisle", surface="land" },
    { x=4, y=17, shape="court_east", cam="court_aisle", surface="land" },
    { x=8, y=19, shape="court_small_east", cam="compact", surface="land" },
  } },
  ["KA_JOHTO_GOLD_FINALE"] = { adaptive=false, fixed=true, fallbacks={water="terarrium"}, spots={
    { x=3, y=0, shape="court_small_north", cam="wide", surface="land" },
    { x=2, y=4, shape="court_tight_west", cam="court_aisle", surface="land" },
  } },
  ["KA_JOHTO_GOLD_PASSAGE"] = { adaptive=false, fixed=true, spots={
    { x=18, y=8, shape="court_north", cam="compact", surface="land" },
    { x=18, y=26, shape="court_north", cam="compact", surface="land" },
    { x=18, y=44, shape="court_north", cam="compact", surface="land" },
  } },
  ["KA_JOHTO_KRIS_FINALE"] = { adaptive=false, fixed=true, spots={
    { x=4, y=1, shape="court_north", cam="compact", surface="land" },
    { x=4, y=5, shape="court_small_south", cam="compact", surface="land" },
  } },
  ["KA_JOHTO_KRIS_PASSAGE"] = { adaptive=false, fixed=true, spots={
    { x=4, y=42, shape="court_east", cam="court_aisle", surface="land" },
    { x=5, y=46, shape="court_east", cam="court_aisle", surface="land" },
    { x=5, y=50, shape="court_east", cam="compact", surface="land" },
  } },
  ["KA_JOHTO_SILVER_FINALE"] = { adaptive=false, fixed=true, fallbacks={water="terarrium"}, spots={
    { x=5, y=1, shape="court_small_south", cam="wide", surface="land" },
    { x=4, y=5, shape="court_small_south", cam="compact", surface="land" },
  } },
  ["KA_JOHTO_SILVER_PASSAGE"] = { adaptive=false, fixed=true, spots={
    { x=4, y=42, shape="court_east", cam="court_aisle", surface="land" },
    { x=5, y=46, shape="court_east", cam="court_aisle", surface="land" },
    { x=5, y=50, shape="court_east", cam="compact", surface="land" },
  } },
  ["KA_MOLTRES_VOLCANO"] = { adaptive=false, fixed=true, spots={
    { x=7, y=6, shape="court_small_north", cam="court_aisle", surface="land" },
    { x=13, y=11, shape="court_tight_east", cam="wide", surface="land" },
    { x=6, y=15, shape="court_tight_west", cam="court_aisle", surface="land" },
  } },
  ["KA_MOLTRES_VOLCANO_ASCENT"] = { adaptive=false, fixed=true, spots={
    { x=5, y=6, shape="court_east", cam="court_aisle", surface="land" },
    { x=9, y=13, shape="court_small_east", cam="court_aisle", surface="land" },
    { x=13, y=16, shape="court_tight_east", cam="compact", surface="land" },
  } },
  ["KA_MOLTRES_VOLCANO_BASE"] = { adaptive=false, fixed=true, spots={
    { x=6, y=7, shape="court_east", cam="court_aisle", surface="land" },
    { x=14, y=12, shape="court_north", cam="compact", surface="land" },
    { x=9, y=18, shape="court_small_east", cam="court_aisle", surface="land" },
  } },
  ["KA_NGPLUS_LEGACY_WORKSHOP"] = { adaptive=false, fixed=true, spots={
    { x=1, y=3, shape="court_small_east", cam="wide", surface="land" },
    { x=10, y=7, shape="court_small_north", cam="compact", surface="land" },
    { x=8, y=15, shape="court_small_west", cam="compact", surface="land" },
  } },
  ["KA_ROCKET_CERULEAN_RELAY_1F"] = { adaptive=false, fixed=true, spots={
    { x=8, y=1, shape="court_east", cam="compact", surface="land" },
    { x=13, y=8, shape="court_tight_east", cam="compact", surface="land" },
    { x=21, y=14, shape="court_tight_west", cam="court_tight", surface="land" },
    { x=28, y=4, shape="court_north", cam="compact", surface="water" },
    { x=10, y=6, shape="court_small_east", cam="court_aisle", surface="water" },
    { x=24, y=4, shape="court_small_east", cam="compact", surface="water" },
  } },
  ["KA_ROCKET_SILPH_COMMAND_1F"] = { adaptive=false, fixed=true, spots={
    { x=9, y=1, shape="court_east", cam="compact", surface="land" },
    { x=1, y=8, shape="court_east", cam="court_aisle", surface="land" },
    { x=13, y=14, shape="court_east", cam="compact", surface="land" },
    { x=17, y=6, shape="court_tight_east", cam="compact", surface="water" },
    { x=10, y=6, shape="court_east", cam="compact", surface="water" },
  } },
  ["KA_ROCKET_SILPH_RELAY_1F"] = { adaptive=false, fixed=true, spots={
    { x=9, y=1, shape="court_east", cam="compact", surface="land" },
    { x=1, y=8, shape="court_east", cam="court_aisle", surface="land" },
    { x=13, y=14, shape="court_east", cam="compact", surface="land" },
    { x=17, y=6, shape="court_tight_east", cam="compact", surface="water" },
    { x=10, y=6, shape="court_east", cam="compact", surface="water" },
  } },
  ["KA_ROCKET_TOWER_RELAY_1F"] = { adaptive=false, fixed=true, spots={
    { x=15, y=4, shape="court_north", cam="wide", surface="land" },
    { x=3, y=9, shape="court_east", cam="court_aisle", surface="land" },
    { x=10, y=12, shape="court_small_south", cam="wide", surface="land" },
  } },
  ["VIRIDIAN_CITY"] = { adaptive=false, fixed=true, spots={
    -- Additional water / raised-terrain courts; native footprint and sightline checked.
    { x=25, y=10, shape="court_east", cam="compact", surface="land" },
    { x=28, y=21, shape="court_east", cam="court_aisle", surface="land" },
    { x=14, y=34, shape="court_tight_west", cam="wide", surface="land" },
    { x=9, y=24, shape="court_tight_east", cam="wide", surface="water" },
  } },
  ["SAFFRON_CITY"] = { adaptive=false, fixed=true, spots={
    -- Additional water / raised-terrain courts; native footprint and sightline checked.
    { x=32, y=6, shape="court_small_east", cam="court_aisle", surface="land" },
    { x=4, y=15, shape="court_small_south", cam="court_aisle", surface="land" },
    { x=37, y=26, shape="court_small_south", cam="compact", surface="land" },
  } },
  ["PEWTER_CITY"] = { adaptive=false, fixed=true, spots={
    -- Additional water / raised-terrain courts; native footprint and sightline checked.
    { x=20, y=8, shape="court_east", cam="court_aisle", surface="land", terrain="flat" },
    { x=12, y=19, shape="court_small_east", cam="compact", surface="land" },
    { x=16, y=30, shape="court_east", cam="compact", surface="land" },
    { x=20, y=8, shape="court_north", cam="court_aisle", surface="land", terrain="local" },
    { x=20, y=8, shape="court_north", cam="court_aisle", surface="land", terrain="world" },
  } },
  ["PALLET_TOWN"] = { adaptive=false, fixed=true, fallbacks={water="terarrium"}, spots={
    -- Additional water / raised-terrain courts; native footprint and sightline checked.
    { x=8, y=3, shape="court_north", cam="compact", surface="land" },
    { x=17, y=8, shape="court_north", cam="compact", surface="land" },
    { x=14, y=14, shape="court_tight_east", cam="compact", surface="land" },
  } },
  ["LAVENDER_TOWN"] = { adaptive=false, fixed=true, spots={
    -- Additional water / raised-terrain courts; native footprint and sightline checked.
    { x=7, y=6, shape="court_east", cam="compact", surface="land" },
    { x=12, y=10, shape="court_small_south", cam="wide", surface="land" },
    { x=11, y=14, shape="court_small_east", cam="compact", surface="land" },
  } },
  ["FUCHSIA_CITY"] = { adaptive=false, fixed=true, spots={
    -- Additional water / raised-terrain courts; native footprint and sightline checked.
    { x=2, y=8, shape="court_east", cam="compact", surface="land", terrain="flat" },
    { x=26, y=17, shape="court_east", cam="compact", surface="land" },
    { x=10, y=29, shape="court_east", cam="compact", surface="land" },
    { x=6, y=16, shape="court_small_east", cam="compact", surface="water" },
    { x=28, y=20, shape="court_small_east", cam="wide", surface="water" },
    { x=3, y=8, shape="court_small_east", cam="compact", surface="land", terrain="local" },
    { x=3, y=8, shape="court_small_east", cam="compact", surface="land", terrain="world" },
  } },
  ["CELADON_CITY"] = { adaptive=false, fixed=true, fallbacks={water="terarrium"}, spots={
    -- Additional water / raised-terrain courts; native footprint and sightline checked.
    { x=30, y=4, shape="court_east", cam="compact", surface="land" },
    { x=36, y=18, shape="court_small_south", cam="compact", surface="land" },
    { x=31, y=30, shape="court_east", cam="compact", surface="land" },
  } },
  ["AGATHAS_ROOM"] = { adaptive=false, fixed=true, spots={
    { x=2, y=1, shape="court_tight_east", cam="court_tight", surface="land" },
  } },
  ["BRUNOS_ROOM"] = { adaptive=false, fixed=true, spots={
    { x=4, y=2, shape="court_small_south", cam="wide", surface="land" },
  } },
  -- Their plant/pool/invisible-wall aisles cannot reserve all four bodies
  -- and a clear physical camera. Use the room's authored 3D alternative.
  ["CELADON_GYM"] = { fixed=true, spots={} },
  ["CERULEAN_CAVE_1F"] = { adaptive=false, fixed=true, spots={
    { x=12, y=8, shape="court_small_west", cam="court_aisle", surface="land" },
    { x=1, y=8, shape="court_small_east", cam="court_aisle_reverse", surface="land" },
    -- Additional water / raised-terrain courts; native footprint and sightline checked.
    { x=22, y=4, shape="court_small_east", cam="wide", surface="water" },
    { x=10, y=6, shape="court_small_east", cam="court_aisle", surface="water" },
  } },
  ["CERULEAN_CAVE_2F"] = { adaptive=false, fixed=true, spots={
    { map="CERULEAN_CAVE_B1F", x=11, y=6, shape="court_small_west", cam="court_aisle", surface="land" },
    { map="CERULEAN_CAVE_B1F", x=1, y=1, shape="court_small_north", cam="court_aisle", surface="land" },
  } },
  ["CERULEAN_CAVE_B1F"] = { adaptive=false, fixed=true, spots={
    { x=11, y=6, shape="court_small_west", cam="court_aisle", surface="land" },
    { x=1, y=1, shape="court_small_north", cam="court_aisle", surface="land" },
    -- Additional water / raised-terrain courts; native footprint and sightline checked.
    { x=23, y=10, shape="court_tight_east", cam="court_aisle", surface="water" },
    { x=15, y=16, shape="court_tight_east", cam="compact", surface="water" },
    { x=22, y=16, shape="court_east", cam="compact", surface="water" },
  } },
  ["CERULEAN_CITY"] = { adaptive=false, fixed=true, spots={
    { x=17, y=18, shape="court_tight_east", cam="court_close", surface="land" },
    { x=33, y=31, shape="court_tight_west", cam="court_aisle", surface="land" },
    -- Additional water / raised-terrain courts; native footprint and sightline checked.
    { x=29, y=1, shape="court_east", cam="court_aisle", surface="water" },
    { x=13, y=4, shape="court_small_west", cam="wide", surface="water" },
    { x=1, y=14, shape="court_small_west", cam="court_aisle", surface="water" },
  } },
  ["CERULEAN_GYM"] = { fixed=true, spots={} },
  ["CHAMPIONS_ROOM"] = { adaptive=false, fixed=true, spots={
    { x=1, y=3, shape="court_small_east", cam="wide", surface="land" },
  } },
  ["CINNABAR_GYM"] = { adaptive=false, fixed=true, spots={
    { x=12, y=6, shape="court_small_south", cam="court_close", surface="land" },
  } },
  ["CINNABAR_ISLAND"] = { adaptive=false, fixed=true, spots={
    { x=10, y=6, shape="court_tight_west", cam="court_close", surface="land" },
    { x=6, y=12, shape="court_tight_west", cam="court_aisle", surface="land" },
    -- Additional water / raised-terrain courts; native footprint and sightline checked.
    { x=1, y=5, shape="court_north", cam="wide", surface="water" },
    { x=7, y=14, shape="court_small_west", cam="court_aisle", surface="water" },
    { x=2, y=15, shape="court_west", cam="wide", surface="water" },
  } },
  ["DIGLETTS_CAVE"] = { adaptive=false, fixed=true, spots={
    { x=16, y=17, shape="court_east", cam="court_aisle", surface="land" },
    { x=1, y=29, shape="court_small_north", cam="court_aisle", surface="land" },
    { x=37, y=1, shape="court_small_south", cam="court_aisle", surface="land" },
  } },
  ["FIGHTING_DOJO"] = { adaptive=false, fixed=true, spots={
    { x=1, y=5, shape="court_east", cam="wide", surface="land" },
  } },
  ["FUCHSIA_GYM"] = { fixed=true, spots={} },
  ["GAME_CORNER"] = { adaptive=false, fixed=true, spots={
    { x=9, y=6, shape="court_small_south", cam="wide", surface="land" },
  } },
  ["LANCES_ROOM"] = { adaptive=false, fixed=true, spots={
    { x=7, y=14, shape="court_south", cam="court_close", surface="land" },
  } },
  ["LORELEIS_ROOM"] = { adaptive=false, fixed=true, spots={
    { x=4, y=2, shape="court_north", cam="court_close", surface="land" },
    -- Additional water / raised-terrain courts; native footprint and sightline checked.
    { x=8, y=2, shape="court_south", cam="court_aisle", surface="water" },
    { x=8, y=6, shape="court_small_south", cam="wide", surface="water" },
    { x=0, y=5, shape="court_small_north", cam="court_aisle", surface="water" },
  } },
  ["MT_MOON_1F"] = { adaptive=false, fixed=true, spots={
    { x=16, y=12, shape="court_south", cam="wide", surface="land" },
    { x=30, y=33, shape="court_west", cam="court_close", surface="land" },
    { x=36, y=2, shape="court_south", cam="court_close", surface="land" },
    { x=2, y=26, shape="court_north", cam="court_close", surface="land" },
  } },
  ["MT_MOON_B1F"] = { adaptive=false, fixed=true, spots={
    { x=14, y=8, shape="court_east", cam="wide", surface="land" },
    { x=4, y=10, shape="court_north", cam="wide", surface="land" },
  } },
  ["MT_MOON_B2F"] = { adaptive=false, fixed=true, spots={
    { x=14, y=22, shape="court_east", cam="court_close", surface="land" },
    { x=31, y=12, shape="court_east", cam="wide", surface="land" },
    { x=1, y=27, shape="court_north", cam="court_close", surface="land" },
    { x=2, y=12, shape="court_north", cam="wide", surface="land" },
  } },
  ["MT_MOON_POKECENTER"] = { adaptive=false, fixed=true, spots={
    { x=3, y=3, shape="court_east", cam="wide", surface="land" },
  } },
  ["OAKS_LAB"] = { x = 1, y = 8, shape = "court_east", cam = "court", adaptive = false, fixed=true, surface="land",
    cameraApron={edge="south",depth=96,width=10,height=12} },
  ["PEWTER_GYM"] = { x = 1, y = 11, shape = "court_east", cam = "wide", adaptive = false, fixed=true, surface="land",
    cameraApron={edge="south",depth=16,width=10,height=14} },
  ["POKEMON_MANSION_1F"] = { adaptive=false, fixed=true, spots={
    { x=10, y=5, shape="court_west", cam="wide", surface="land" },
    { x=4, y=19, shape="court_north", cam="wide", surface="land" },
  } },
  ["POKEMON_MANSION_2F"] = { adaptive=false, fixed=true, spots={
    { x=15, y=17, shape="court_east", cam="court_close", surface="land" },
    { x=10, y=1, shape="court_north", cam="court_close", surface="land" },
  } },
  ["POKEMON_MANSION_3F"] = { adaptive=false, fixed=true, spots={
    { x=4, y=2, shape="court_east", cam="wide", surface="land" },
  } },
  ["POKEMON_MANSION_B1F"] = { adaptive=false, fixed=true, spots={
    { x=11, y=13, shape="court_east", cam="wide", surface="land" },
    { x=1, y=19, shape="court_north", cam="court_close", surface="land" },
  } },
  ["POKEMON_TOWER_1F"] = { adaptive=false, fixed=true, spots={
    { x=6, y=8, shape="court_east", cam="court_close", surface="land" },
  } },
  ["POKEMON_TOWER_2F"] = { adaptive=false, fixed=true, spots={
    { x=8, y=4, shape="court_small_west", cam="wide", surface="land" },
  } },
  ["POKEMON_TOWER_3F"] = { adaptive=false, fixed=true, spots={
    { x=8, y=14, shape="court_small_west", cam="court_aisle", surface="land" },
  } },
  ["POKEMON_TOWER_4F"] = { adaptive=false, fixed=true, spots={
    { map="POKEMON_TOWER_3F", x=8, y=14, shape="court_small_west", cam="court_aisle", surface="land" },
  } },
  ["POKEMON_TOWER_5F"] = { adaptive=false, fixed=true, spots={
    { x=8, y=8, shape="court_small_east", cam="wide", surface="land" },
  } },
  ["POKEMON_TOWER_6F"] = { adaptive=false, fixed=true, spots={
    { x=6, y=6, shape="court_small_west", cam="wide", surface="land" },
  } },
  ["POKEMON_TOWER_7F"] = { adaptive=false, fixed=true, spots={
    { x=9, y=5, shape="court_north", cam="wide", surface="land" },
  } },
  ["POWER_PLANT"] = { adaptive=false, fixed=true, spots={
    { x=16, y=10, shape="court_small_west", cam="court_aisle", surface="land" },
    { x=1, y=7, shape="court_small_east", cam="court_aisle", surface="land" },
    { x=6, y=16, shape="court_small_south", cam="court_aisle_reverse", surface="land" },
  } },
  ["ROCKET_HIDEOUT_B1F"] = { adaptive=false, fixed=true, spots={
    { x=17, y=10, shape="court_small_north", cam="court_aisle", surface="land" },
    { x=17, y=25, shape="court_small_west", cam="wide", surface="land" },
  } },
  ["ROCKET_HIDEOUT_B2F"] = { adaptive=false, fixed=true, spots={
    { x=19, y=10, shape="court_small_north", cam="court_aisle", surface="land" },
    { x=19, y=21, shape="court_small_north", cam="court_aisle", surface="land" },
  } },
  ["ROCKET_HIDEOUT_B3F"] = { adaptive=false, fixed=true, spots={
    { x=22, y=12, shape="court_small_north", cam="wide", surface="land" },
    { x=15, y=25, shape="court_small_west", cam="court_aisle_reverse", surface="land" },
  } },
  ["ROCKET_HIDEOUT_B4F"] = { adaptive=false, fixed=true, spots={
    { x=17, y=7, shape="court_north", cam="court_aisle", surface="land" },
    { x=21, y=17, shape="court_small_south", cam="court_aisle_reverse", surface="land" },
  } },
  ["ROCK_TUNNEL_1F"] = { adaptive=false, fixed=true, spots={
    { x=14, y=17, shape="court_east", cam="court_close", surface="land" },
    { x=31, y=33, shape="court_west", cam="court_close", surface="land" },
    { x=1, y=33, shape="court_west", cam="court_close", surface="land" },
    { x=36, y=5, shape="court_south", cam="wide", surface="land" },
  } },
  ["ROCK_TUNNEL_B1F"] = { adaptive=false, fixed=true, spots={
    { x=20, y=16, shape="court_north", cam="court_close", surface="land" },
    { x=30, y=2, shape="court_east", cam="court_close", surface="land" },
    { x=2, y=4, shape="court_north", cam="wide", surface="land" },
    { x=36, y=26, shape="court_south", cam="court_close", surface="land" },
  } },
  ["ROCK_TUNNEL_POKECENTER"] = { adaptive=false, fixed=true, spots={
    { x=3, y=3, shape="court_east", cam="wide", surface="land" },
  } },
  ["ROUTE_1"] = { adaptive=false, fixed=true, spots={
    { x=6, y=14, shape="court_east", cam="court_close", surface="land" },
    { x=12, y=10, shape="court_small_west", cam="wide", surface="land" },
    { x=4, y=21, shape="court_small_west", cam="wide", surface="land" },
    -- Additional water / raised-terrain courts; native footprint and sightline checked.
    { x=6, y=11, shape="court_small_west", cam="wide", surface="land", terrain="local" },
    { x=6, y=11, shape="court_small_west", cam="wide", surface="land", terrain="world" },
    { x=10, y=10, shape="court_small_east", cam="court_aisle", surface="land", terrain="local" },
    { x=10, y=10, shape="court_small_east", cam="court_aisle", surface="land", terrain="world" },
    { x=10, y=17, shape="court_small_west", cam="court_aisle", surface="land", terrain="local" },
    { x=10, y=17, shape="court_small_west", cam="court_aisle", surface="land", terrain="world" },
  } },
  ["ROUTE_10"] = { adaptive=false, fixed=true, spots={
    { x=14, y=32, shape="court_north", cam="wide", surface="land" },
    { x=10, y=63, shape="court_east", cam="wide", surface="land" },
    { x=2, y=18, shape="court_north", cam="wide", surface="land" },
    -- Additional water / raised-terrain courts; native footprint and sightline checked.
    { x=3, y=2, shape="court_small_east", cam="wide", surface="water" },
    { x=16, y=29, shape="court_small_south", cam="court_aisle", surface="water", terrain="flat" },
    { x=8, y=46, shape="court_small_west", cam="court_aisle", surface="water" },
    { x=12, y=46, shape="court_small_west", cam="court_aisle", surface="water", terrain="local" },
    { x=12, y=46, shape="court_small_west", cam="court_aisle", surface="water", terrain="world" },
  } },
  ["ROUTE_11"] = { adaptive=false, fixed=true, spots={
    { x=24, y=10, shape="court_east", cam="wide", surface="land" },
    { x=48, y=1, shape="court_east", cam="court_close", surface="land" },
    { x=1, y=6, shape="court_east", cam="court_close", surface="land" },
    -- Additional water / raised-terrain courts; native footprint and sightline checked.
    { x=0, y=9, shape="court_east", cam="court_aisle", surface="water" },
    { x=4, y=8, shape="court_small_north", cam="court_aisle", surface="water" },
  } },
  ["ROUTE_12"] = { adaptive=false, fixed=true, spots={
    { x=8, y=52, shape="court_east", cam="court_close", surface="land" },
    { x=12, y=98, shape="court_north", cam="court_close", surface="land" },
    { x=8, y=2, shape="court_north", cam="wide", surface="land" },
    { x=8, y=26, shape="court_east", cam="court_close", surface="land" },
    { x=4, y=82, shape="court_east", cam="wide", surface="land" },
    { x=13, y=58, shape="court_north", cam="court_close", surface="water" },
    { x=14, y=15, shape="court_small_north", cam="court_close", surface="water" },
    { x=12, y=92, shape="court_small_east", cam="court_close", surface="water" },
    { x=9, y=38, shape="court_small_west", cam="court_close", surface="water" },
    { x=4, y=4, shape="court_small_north", cam="court_close", surface="water" },
    { x=4, y=73, shape="court_small_west", cam="court_close", surface="water" },
  } },
  ["ROUTE_13"] = { adaptive=false, fixed=true, spots={
    { x=34, y=10, shape="court_east", cam="court_close", surface="land" },
    { x=50, y=1, shape="court_north", cam="court_close", surface="land" },
    { x=42, y=10, shape="court_east", cam="court_close", surface="land" },
    { x=44, y=12, shape="court_east", cam="court_close", surface="water" },
    { x=36, y=13, shape="court_small_west", cam="court_close", surface="water" },
    { x=53, y=1, shape="court_small_east", cam="court_close", surface="water" },
  } },
  ["ROUTE_14"] = { adaptive=false, fixed=true, spots={
    { x=11, y=23, shape="court_north", cam="wide", surface="land" },
    { x=1, y=48, shape="court_west", cam="court_close", surface="land" },
    { x=4, y=12, shape="court_east", cam="court_close", surface="land" },
    -- Additional water / raised-terrain courts; native footprint and sightline checked.
    { x=18, y=23, shape="court_small_south", cam="wide", surface="water" },
  } },
  ["ROUTE_15"] = { adaptive=false, fixed=true, spots={
    { x=26, y=10, shape="court_east", cam="wide", surface="land" },
    { x=2, y=1, shape="court_east", cam="court_close", surface="land" },
    { x=51, y=12, shape="court_west", cam="court_close", surface="land" },
  } },
  ["ROUTE_16"] = { adaptive=false, fixed=true, spots={
    { x=10, y=7, shape="court_west", cam="court_close", surface="land" },
    { x=27, y=7, shape="court_west", cam="wide", surface="land" },
    { x=1, y=15, shape="court_west", cam="court_close", surface="land" },
    -- Additional water / raised-terrain courts; native footprint and sightline checked.
    { x=17, y=16, shape="court_small_east", cam="compact", surface="water" },
  } },
  ["ROUTE_17"] = { adaptive=false, fixed=true, spots={
    { x=8, y=67, shape="court_north", cam="court_close", surface="land" },
    { x=1, y=1, shape="court_east", cam="court_close", surface="land" },
    { x=6, y=139, shape="court_west", cam="court_close", surface="land" },
    { x=15, y=32, shape="court_south", cam="court_close", surface="land" },
    { x=1, y=101, shape="court_north", cam="court_close", surface="land" },
    { x=17, y=115, shape="court_south", cam="court_close", surface="land" },
    { x=9, y=12, shape="court_south", cam="court_close", surface="land" },
    -- Additional water / raised-terrain courts; native footprint and sightline checked.
    { x=10, y=47, shape="court_north", cam="court_aisle", surface="water", terrain="flat" },
    { x=10, y=47, shape="court_north", cam="court_aisle", surface="water", terrain="local" },
    { x=10, y=84, shape="court_north", cam="court_aisle", surface="water", terrain="flat" },
    { x=10, y=84, shape="court_north", cam="court_aisle", surface="water", terrain="local" },
    { x=3, y=129, shape="court_north", cam="court_aisle", surface="water", terrain="flat" },
    { x=3, y=129, shape="court_north", cam="court_aisle", surface="water", terrain="local" },
    { x=14, y=0, shape="court_small_east", cam="wide", surface="water", terrain="world" },
  } },
  ["ROUTE_18"] = { adaptive=false, fixed=true, spots={
    { x=21, y=8, shape="court_east", cam="court_close", surface="land" },
    { x=41, y=1, shape="court_east", cam="court_close", surface="land" },
    { x=6, y=1, shape="court_north", cam="court_close", surface="land" },
    -- Additional water / raised-terrain courts; native footprint and sightline checked.
    { x=2, y=4, shape="court_north", cam="court_aisle", surface="water" },
    { x=31, y=11, shape="court_small_south", cam="wide", surface="water" },
    { x=11, y=15, shape="court_east", cam="compact", surface="water" },
  } },
  ["ROUTE_19"] = { adaptive=false, fixed=true, spots={
    { x=6, y=7, shape="court_east", cam="wide", surface="land" },
    { x=5, y=38, shape="court_east", cam="court_close", surface="water" },
    { x=6, y=15, shape="court_east", cam="court_close", surface="water" },
    { x=2, y=51, shape="court_west", cam="court_close", surface="water" },
  } },
  ["ROUTE_2"] = { adaptive=false, fixed=true, spots={
    { x=2, y=50, shape="court_north", cam="wide", surface="land" },
    { x=11, y=2, shape="court_east", cam="wide", surface="land" },
    { x=17, y=53, shape="court_south", cam="court_close", surface="land" },
    { x=1, y=8, shape="court_small_west", cam="wide", surface="land" },
  } },
  ["ROUTE_20"] = { adaptive=false, fixed=true, spots={
    { x=46, y=8, shape="court_east", cam="court_close", surface="land" },
    { x=54, y=2, shape="court_east", cam="wide", surface="land" },
    { x=13, y=4, shape="court_north", cam="court_close", surface="water" },
    { x=77, y=4, shape="court_north", cam="court_close", surface="water" },
    { x=40, y=4, shape="court_south", cam="court_close", surface="water" },
    { x=95, y=4, shape="court_north", cam="wide", surface="water" },
    { x=62, y=4, shape="court_small_north", cam="court_close", surface="water" },
    { x=1, y=4, shape="court_north", cam="court_close", surface="water" },
  } },
  ["ROUTE_21"] = { adaptive=false, fixed=true, spots={
    { x=15, y=2, shape="court_north", cam="wide", surface="land" },
    { x=6, y=38, shape="court_east", cam="court_close", surface="water" },
    { x=6, y=70, shape="court_east", cam="court_close", surface="water" },
    { x=8, y=10, shape="court_north", cam="court_close", surface="water" },
    { x=6, y=86, shape="court_west", cam="court_close", surface="water" },
    { x=9, y=50, shape="court_north", cam="court_close", surface="water" },
  } },
  ["ROUTE_22"] = { adaptive=false, fixed=true, fallbacks={water="terarrium"}, spots={
    { x=21, y=4, shape="court_east", cam="wide", surface="land" },
    -- Additional water / raised-terrain courts; native footprint and sightline checked.
    { x=35, y=7, shape="court_small_north", cam="court_aisle", surface="land", terrain="local" },
    { x=35, y=7, shape="court_small_north", cam="court_aisle", surface="land", terrain="world" },
  } },
  ["ROUTE_23"] = { adaptive=false, fixed=true, spots={
    { x=6, y=48, shape="court_east", cam="wide", surface="land" },
    { x=1, y=132, shape="court_east", cam="wide", surface="land" },
    { x=1, y=20, shape="court_east", cam="wide", surface="land" },
    { x=14, y=104, shape="court_south", cam="court_close", surface="land" },
    { x=1, y=32, shape="court_north", cam="wide", surface="land" },
    { x=11, y=124, shape="court_east", cam="wide", surface="land" },
    { x=4, y=88, shape="court_east", cam="court_close", surface="water" },
    { x=8, y=72, shape="court_small_east", cam="court_close", surface="water" },
    { x=9, y=101, shape="court_east", cam="court_close", surface="water" },
  } },
  ["ROUTE_24"] = { adaptive=false, fixed=true, spots={
    { x=4, y=14, shape="court_west", cam="wide", surface="land" },
    { x=5, y=4, shape="court_east", cam="wide", surface="land" },
    -- Additional water / raised-terrain courts; native footprint and sightline checked.
    { x=7, y=22, shape="court_small_south", cam="court_aisle", surface="water" },
    { x=7, y=28, shape="court_small_south", cam="court_aisle", surface="water" },
    { x=18, y=30, shape="court_small_south", cam="wide", surface="water" },
  } },
  ["ROUTE_25"] = { adaptive=false, fixed=true, spots={
    { x=30, y=8, shape="court_west", cam="wide", surface="land" },
    { x=47, y=4, shape="court_east", cam="court_close", surface="land" },
    { x=38, y=5, shape="court_east", cam="wide", surface="land" },
    -- Additional water / raised-terrain courts; native footprint and sightline checked.
    { x=48, y=8, shape="court_small_east", cam="court_aisle", surface="water" },
    { x=36, y=16, shape="court_small_west", cam="court_aisle", surface="water" },
    { x=52, y=16, shape="court_west", cam="wide", surface="water" },
  } },
  ["ROUTE_3"] = { adaptive=false, fixed=true, spots={
    { x=30, y=8, shape="court_east", cam="wide", surface="land" },
    { x=10, y=4, shape="court_east", cam="wide", surface="land" },
    { x=50, y=12, shape="court_west", cam="wide", surface="land" },
  } },
  ["ROUTE_4"] = { adaptive=false, fixed=true, spots={
    { x=46, y=5, shape="court_north", cam="wide", surface="land" },
    { x=5, y=9, shape="court_west", cam="wide", surface="land" },
    { x=52, y=10, shape="court_east", cam="wide", surface="land" },
    { x=34, y=6, shape="court_east", cam="wide", surface="land" },
    -- Additional water / raised-terrain courts; native footprint and sightline checked.
    { x=85, y=6, shape="court_tight_east", cam="compact", surface="water" },
    { x=81, y=7, shape="court_east", cam="compact", surface="water" },
  } },
  ["ROUTE_5"] = { adaptive=false, fixed=true, spots={
    { x=15, y=14, shape="court_north", cam="wide", surface="land" },
    { x=1, y=1, shape="court_north", cam="wide", surface="land" },
    { x=1, y=24, shape="court_north", cam="court_close", surface="land" },
  } },
  ["ROUTE_6"] = { adaptive=false, fixed=true, spots={
    { x=6, y=20, shape="court_east", cam="wide", surface="land" },
    { x=6, y=8, shape="court_east", cam="wide", surface="land" },
    { x=4, y=29, shape="court_west", cam="court_close", surface="land" },
    -- Additional water / raised-terrain courts; native footprint and sightline checked.
    { x=0, y=25, shape="court_east", cam="court_aisle", surface="water" },
    { x=4, y=26, shape="court_east", cam="court_aisle", surface="water" },
    { x=0, y=34, shape="court_small_west", cam="wide", surface="water" },
  } },
  ["ROUTE_7"] = { adaptive=false, fixed=true, spots={
    { x=8, y=12, shape="court_east", cam="wide", surface="land" },
  } },
  ["ROUTE_8"] = { adaptive=false, fixed=true, spots={
    { x=27, y=5, shape="court_south", cam="court_close", surface="land" },
    { x=54, y=8, shape="court_south", cam="wide", surface="land" },
    { x=5, y=14, shape="court_west", cam="wide", surface="land" },
  } },
  ["ROUTE_9"] = { adaptive=false, fixed=true, spots={
    { x=38, y=2, shape="court_east", cam="wide", surface="land" },
    -- Additional water / raised-terrain courts; native footprint and sightline checked.
    { x=32, y=6, shape="court_small_east", cam="compact", surface="land", terrain="local" },
    { x=32, y=6, shape="court_small_east", cam="compact", surface="land", terrain="world" },
  } },
  ["SAFARI_ZONE_CENTER"] = { adaptive=false, fixed=true, spots={
    -- Keep the item pedestal's small island out of the battle lane.
    { x=11, y=16, shape="court_east", cam="wide", surface="land" },
    { x=23, y=1, shape="court_tight_east", cam="court_aisle", surface="land" },
    { x=1, y=7, shape="court_small_north", cam="court_close", surface="land" },
    { x=1, y=22, shape="court_tight_west", cam="court_close", surface="land" },
    -- Additional water / raised-terrain courts; native footprint and sightline checked.
    { x=20, y=8, shape="court_small_south", cam="court_aisle", surface="water" },
    { x=8, y=12, shape="court_west", cam="court_aisle", surface="water" },
    { x=12, y=12, shape="court_west", cam="court_aisle", surface="water" },
  } },
  ["SAFARI_ZONE_EAST"] = { adaptive=false, fixed=true, spots={
    { x=16, y=8, shape="court_tight_east", cam="court_aisle", surface="land" },
    { x=7, y=17, shape="court_small_north", cam="wide", surface="land" },
    { x=24, y=18, shape="court_tight_west", cam="court_tight", surface="land" },
    { x=22, y=11, shape="court_tight_west", cam="court_aisle", surface="land" },
    -- Additional water / raised-terrain courts; native footprint and sightline checked.
    { x=11, y=10, shape="court_east", cam="wide", surface="water" },
    { x=14, y=16, shape="court_small_east", cam="court_aisle", surface="water" },
    { x=16, y=11, shape="court_small_south", cam="wide", surface="water" },
  } },
  ["SAFARI_ZONE_NORTH"] = { adaptive=false, fixed=true, spots={
    { x=18, y=17, shape="court_tight_east", cam="court_close", surface="land" },
    { x=1, y=28, shape="court_small_north", cam="court_aisle", surface="land" },
    { x=33, y=32, shape="court_tight_west", cam="court_close", surface="land" },
    { x=37, y=4, shape="court_small_south", cam="court_close", surface="land" },
    -- Additional water / raised-terrain courts; native footprint and sightline checked.
    { x=8, y=8, shape="court_small_north", cam="court_aisle", surface="water" },
    { x=4, y=14, shape="court_small_north", cam="court_aisle", surface="water" },
    { x=8, y=24, shape="court_small_north", cam="court_aisle", surface="water" },
  } },
  ["SAFARI_ZONE_WEST"] = { adaptive=false, fixed=true, spots={
    { x=9, y=14, shape="court_tight_east", cam="court_close", surface="land" },
    { x=27, y=4, shape="court_small_south", cam="court_aisle", surface="land" },
    { x=22, y=20, shape="court_small_west", cam="court_close", surface="land" },
    { x=12, y=2, shape="court_tight_east", cam="court_close", surface="land" },
    -- Additional water / raised-terrain courts; native footprint and sightline checked.
    { x=4, y=10, shape="court_small_east", cam="court_aisle", surface="water" },
  } },
  ["SAFFRON_GYM"] = { adaptive=false, fixed=true, spots={
    { x=7, y=8, shape="court_small_east", cam="wide", surface="land" },
  } },
  ["SEAFOAM_ISLANDS_1F"] = { adaptive=false, fixed=true, spots={
    { x=12, y=8, shape="court_small_east", cam="court_close", surface="land" },
    { x=26, y=2, shape="court_small_south", cam="court_aisle_reverse", surface="land" },
    { x=2, y=14, shape="court_tight_west", cam="court_aisle_reverse", surface="land" },
  } },
  ["SEAFOAM_ISLANDS_B1F"] = { adaptive=false, fixed=true, spots={
    { x=16, y=4, shape="court_small_north", cam="court_aisle", surface="land" },
    { x=2, y=10, shape="court_small_north", cam="court_close", surface="land" },
    { x=26, y=10, shape="court_small_south", cam="court_aisle_reverse", surface="land" },
  } },
  ["SEAFOAM_ISLANDS_B2F"] = { adaptive=false, fixed=true, spots={
    { x=11, y=8, shape="court_east", cam="court_aisle", surface="land" },
    { x=2, y=2, shape="court_small_north", cam="court_close", surface="land" },
    { x=4, y=14, shape="court_tight_west", cam="court_aisle_reverse", surface="land" },
  } },
  ["SEAFOAM_ISLANDS_B3F"] = { adaptive=false, fixed=true, spots={
    { x=12, y=5, shape="court_tight_west", cam="court_close", surface="land" },
    { x=27, y=9, shape="court_small_south", cam="court_aisle_reverse", surface="land" },
    { x=1, y=7, shape="court_small_north", cam="court_close", surface="land" },
    -- Additional water / raised-terrain courts; native footprint and sightline checked.
    { x=13, y=2, shape="court_small_east", cam="wide", surface="water" },
    { x=16, y=10, shape="court_small_west", cam="court_aisle", surface="water" },
  } },
  ["SEAFOAM_ISLANDS_B4F"] = { adaptive=false, fixed=true, spots={
    { x=13, y=6, shape="court_small_south", cam="court_close", surface="land" },
    { x=18, y=1, shape="court_tight_east", cam="court_aisle", surface="land" },
    { x=10, y=15, shape="court_tight_west", cam="court_tight", surface="land" },
    -- Additional water / raised-terrain courts; native footprint and sightline checked.
    { x=7, y=4, shape="court_small_east", cam="court_aisle", surface="water" },
    { x=17, y=10, shape="court_east", cam="court_aisle", surface="water" },
    { x=22, y=13, shape="court_small_west", cam="court_aisle", surface="water" },
  } },
  ["SILPH_CO_10F"] = { adaptive=false, fixed=true, spots={
    { x=2, y=2, shape="court_east", cam="wide", surface="land" },
  } },
  ["SILPH_CO_11F"] = { adaptive=false, fixed=true, spots={
    { x=5, y=9, shape="court_east", cam="wide", surface="land" },
    { x=1, y=9, shape="court_north", cam="wide", surface="land" },
  } },
  ["SILPH_CO_1F"] = { adaptive=false, fixed=true, spots={
    { x=11, y=11, shape="court_east", cam="court_close", surface="land" },
    { x=19, y=1, shape="court_east", cam="court_close", surface="land" },
    { x=3, y=4, shape="court_north", cam="court_close", surface="land" },
  } },
  ["SILPH_CO_2F"] = { adaptive=false, fixed=true, spots={
    { x=9, y=6, shape="court_east", cam="wide", surface="land" },
    { x=1, y=8, shape="court_west", cam="court_close", surface="land" },
  } },
  ["SILPH_CO_3F"] = { adaptive=false, fixed=true, spots={
    { x=18, y=3, shape="court_north", cam="wide", surface="land" },
    { x=19, y=1, shape="court_east", cam="wide", surface="land" },
    { x=18, y=9, shape="court_north", cam="wide", surface="land" },
  } },
  ["SILPH_CO_4F"] = { adaptive=false, fixed=true, spots={
    { x=11, y=13, shape="court_east", cam="wide", surface="land" },
    { x=1, y=13, shape="court_east", cam="wide", surface="land" },
  } },
  ["SILPH_CO_5F"] = { adaptive=false, fixed=true, spots={
    { x=16, y=5, shape="court_north", cam="court_close", surface="land" },
    { x=1, y=4, shape="court_east", cam="wide", surface="land" },
    { x=21, y=1, shape="court_east", cam="wide", surface="land" },
  } },
  ["SILPH_CO_6F"] = { adaptive=false, fixed=true, spots={
    { x=6, y=1, shape="court_east", cam="wide", surface="land" },
    { x=17, y=1, shape="court_east", cam="wide", surface="land" },
  } },
  ["SILPH_CO_7F"] = { adaptive=false, fixed=true, spots={
    { x=19, y=6, shape="court_small_north", cam="wide", surface="land" },
    { x=1, y=1, shape="court_small_north", cam="wide", surface="land" },
    { x=16, y=1, shape="court_small_east", cam="wide", surface="land" },
  } },
  ["SILPH_CO_8F"] = { adaptive=false, fixed=true, spots={
    { x=14, y=1, shape="court_east", cam="wide", surface="land" },
  } },
  ["SILPH_CO_9F"] = { adaptive=false, fixed=true, spots={
    { x=12, y=1, shape="court_east", cam="wide", surface="land" },
    { x=1, y=1, shape="court_east", cam="wide", surface="land" },
  } },
  ["SS_ANNE_1F_ROOMS"] = { fixed=true, spots={} },
  ["SS_ANNE_2F"] = { adaptive=false, fixed=true, spots={
    { x=32, y=12, shape="court_tight_west", cam="court_aisle_reverse", surface="land" },
  } },
  ["SS_ANNE_2F_ROOMS"] = { fixed=true, spots={} },
  ["SS_ANNE_3F"] = { fixed=true, spots={} },
  ["SS_ANNE_B1F"] = { fixed=true, spots={} },
  ["SS_ANNE_B1F_ROOMS"] = { fixed=true, spots={} },
  ["SS_ANNE_BOW"] = { adaptive=false, fixed=true, spots={
    { x=10, y=3, shape="court_south", cam="court_close", surface="land" },
    { x=1, y=6, shape="court_tight_east", cam="court_tight", surface="land" },
  } },
  ["SS_ANNE_CAPTAINS_ROOM"] = { fixed=true, spots={} },
  ["VERMILION_CITY"] = { adaptive=false, fixed=true, spots={
    { x=17, y=16, shape="court_tight_west", cam="court_close", surface="land" },
    { x=37, y=1, shape="court_small_south", cam="court_aisle", surface="land" },
    -- Additional water / raised-terrain courts; native footprint and sightline checked.
    { x=4, y=14, shape="court_small_north", cam="court_aisle", surface="water" },
    { x=15, y=24, shape="court_east", cam="court_aisle", surface="water" },
    { x=5, y=34, shape="court_small_west", cam="court_aisle", surface="water" },
  } },
  ["VERMILION_GYM"] = { adaptive=false, fixed=true, spots={
    { x=4, y=15, shape="court_tight_west", cam="wide", surface="land" },
  } },
  ["VICTORY_ROAD_1F"] = { adaptive=false, fixed=true, spots={
    { x=6, y=4, shape="court_east", cam="wide", surface="land" },
  } },
  ["VICTORY_ROAD_2F"] = { adaptive=false, fixed=true, spots={
    { x=16, y=4, shape="court_north", cam="court_close", surface="land" },
    { x=16, y=1, shape="court_east", cam="wide", surface="land" },
  } },
  ["VICTORY_ROAD_3F"] = { adaptive=false, fixed=true, spots={
    { x=12, y=6, shape="court_east", cam="wide", surface="land" },
    { x=1, y=15, shape="court_west", cam="wide", surface="land" },
    { x=21, y=1, shape="court_east", cam="wide", surface="land" },
    { x=16, y=13, shape="court_east", cam="wide", surface="land" },
  } },
  ["VIRIDIAN_FOREST"] = { adaptive=false, fixed=true, spots={
    { x=13, y=18, shape="court_small_west", cam="wide", surface="land" },
    { x=22, y=42, shape="court_small_west", cam="wide", surface="land" },
    { x=6, y=42, shape="court_small_west", cam="wide", surface="land" },
    { x=6, y=1, shape="court_east", cam="wide", surface="land" },
  } },
  ["VIRIDIAN_GYM"] = { adaptive=false, fixed=true, spots={
    { x=8, y=8, shape="court_small_east", cam="wide", surface="land" },
  } },
}
