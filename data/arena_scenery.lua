-- Reviewed full-frame Arena Scenery, selected in the 111-anchor gallery.
--
-- Every entry owns an exact 1280x800 bitmap and the same authored 3X screen
-- footing: player lower-left, opponent upper-right.  The positions remain
-- explicit on every returned spec so a missing or malformed record fails
-- closed instead of silently borrowing a generic arena.

local specs = {}

local function add(ids, file, outdoor, actorScale, actorSpread, windowRegions,
                   frlgFile, frlgWindowRegions)
  local playerX, enemyX, playerY, enemyY, playerZ, enemyZ
  local trainerPlayerX, trainerEnemyX
  if type(actorSpread) == "table" then
    playerX = actorSpread.playerX or 0
    enemyX = actorSpread.enemyX or 0
    playerY = actorSpread.playerY or -8
    enemyY = actorSpread.enemyY or -10
    playerZ = actorSpread.playerZ or -20
    enemyZ = actorSpread.enemyZ or 20
    trainerPlayerX = actorSpread.trainerPlayerX or playerX
    trainerEnemyX = actorSpread.trainerEnemyX or enemyX
  else
    -- Once both cards share the central depth plane they need explicit
    -- left/right marks; the old zero spread relied on perspective alone and
    -- collapsed the pair onto the same spot. A profile can still provide a
    -- numeric reviewed spread or exact asymmetric values. The generic
    -- composition is deliberately asymmetric: the player stays on the left
    -- court mark while the opponent reaches the far-right court mark instead
    -- of collecting near screen centre.
    if type(actorSpread) == "number" then
      playerX = -actorSpread
      enemyX = actorSpread
      trainerPlayerX, trainerEnemyX = playerX, enemyX
    else
      playerX = -26
      -- The native fallback player-status card occupies the lower-right
      -- quarter at integer GB scale.  Keep world-staged opponents on the
      -- inner court mark in front of that card instead of drawing their body
      -- through it; human introductions still use the far-right mark below.
      enemyX = -4
      trainerPlayerX, trainerEnemyX = -18, 26
    end
    playerY, enemyY = -8, -10
    playerZ, enemyZ = -20, 20
  end
  local spec = {
    path = "assets/battle/" .. file,
    -- Only profiles with a geographically reviewed FR/LG-like counterpart
    -- carry this second path. Runtime selection can therefore never borrow a
    -- new painting for an unrelated map.
    frlgPath = frlgFile and ("assets/battle/" .. frlgFile) or nil,
    frlgWindows = frlgWindowRegions,
    width = 1280,
    height = 800,
    camera = "3X",
    outdoor = outdoor and true or false,
    -- Screen-space paintings do not all imply the same physical room size.
    -- Keep the authored feet fixed and scale only the battle cards about
    -- those feet.  Outdoor routes and stadium-sized rooms stay at 1.0;
    -- intimate interiors may opt into a reviewed larger human/monster datum.
    actorScale = actorScale or 1,
    -- Rooms keep their authored artificial light.  Only these exact panes
    -- look outside and therefore follow the continuous overworld clock.
    -- Coordinates live in the reviewed 1280x800 painting, not screen space.
    clockTint = type(windowRegions) == "table" and #windowRegions > 0,
    windows = windowRegions,
    anchors = {
      -- The arena cells already run from the near player's side toward the
      -- far opponent.  The painted composition repeats that diagonal: player
      -- lower-left, opponent upper-right.  These vertical offsets must not be
      -- reversed, or a tall front card (most visibly a Mega) appears over the
      -- distant scenery while the small foe drops into the foreground.
      -- The near/player cell already projects lower than the far opponent.
      -- Native 1710x1069 calibration puts the reviewed player foot below the
      -- opponent but wholly above the text window at -8. The former -25 datum
      -- hid normal and Mega cards; +1 over-corrected them into the far plane.
      -- The synthetic wide stage puts the two cells 48 world pixels apart in
      -- depth.  On a screen-space painting that exaggerated perspective made
      -- the near trainer roughly 40% larger than an equally tall opponent
      -- (Red versus Oak was the clearest report) and left the player on the
      -- foreground/UI lip.  Pull the near mark 20 pixels into the court and
      -- bring the far mark 20 pixels forward.  A small eight-pixel diagonal
      -- remains, but both now inhabit the painted centre plane and retain
      -- comparable physical proportions.
      player = { x = playerX, y = playerY, z = playerZ },
      enemy = { x = enemyX, y = enemyY, z = enemyZ },
    },
    -- Human introductions use the wider court marks. Pokémon return to the
    -- inner right mark so their body remains clear of the edge-docked status
    -- card; explicit room profiles retain their own reviewed coordinates.
    trainerAnchors = {
      player = { x = trainerPlayerX, y = playerY, z = playerZ },
      enemy = { x = trainerEnemyX, y = enemyY, z = enemyZ },
    },
  }
  for _, id in ipairs(ids) do specs[id] = spec end
end

local function addF(ids, file, outdoor, actorScale, actorSpread, windowRegions,
                    frlgWindowRegions)
  return add(ids, file .. ".compact.png", outdoor, actorScale, actorSpread,
             windowRegions, file .. "-frlg.compact.png", frlgWindowRegions)
end

-- Window masks deliberately stop inside the physical frames.  Multiplying
-- these shapes is enough to turn the painted outdoor view through morning,
-- day, evening and night without blue-washing the room, its lamps or actors.
local OAK_LAB_WINDOWS = {
  { shape="rect", x=759, y=51, w=69, h=127 },
  { shape="rect", x=838, y=51, w=70, h=127 },
  -- The conservatory contains interior frames, hanging plants and glass.  It
  -- receives the clock, but not the nearly-opaque night-sky sheet used by the
  -- two unobstructed panes; otherwise the whole structure becomes one blue
  -- polygon.  Moon/stars remain visible through the actual windows above.
  { shape="poly", points={ 969,20, 1155,18, 1152,269, 964,269 },
    tintScale=.72, alphaScale=0, starsScale=0, moon=false },
}
local MANSION_WINDOWS = {
  { shape="rect", x=54, y=91, w=106, h=190 },
  { shape="rect", x=536, y=116, w=62, h=148 },
}
-- The FRLG-like master has two tall arched windows on the left instead of
-- the original VASC room's separated panes. These polygons stay inside the
-- glass and deliberately exclude the pale wall and lower wood panelling.
local MANSION_FRLG_WINDOWS = {
  { shape="poly", points={ 94,37, 148,37, 163,69, 163,214, 78,214, 78,73 } },
  { shape="poly", points={ 308,66, 341,66, 361,95, 361,231, 283,231, 283,98 } },
}
local SHIP_CABIN_WINDOWS = {
  { shape="ellipse", x=744, y=158, w=76, h=91 },
  { shape="ellipse", x=934, y=158, w=76, h=91 },
}
local SHIP_CORRIDOR_WINDOWS = {
  { shape="ellipse", x=82,  y=104, w=91, h=112 },
  { shape="ellipse", x=357, y=123, w=76, h=96 },
  { shape="ellipse", x=579, y=134, w=72, h=90 },
  { shape="ellipse", x=704, y=143, w=50, h=66 },
}

add({ "ROUTE_25" }, "arena_cape-route25.compact.png", true)
addF({ "CERULEAN_CAVE_1F", "CERULEAN_CAVE_2F", "CERULEAN_CAVE_B1F" },
     "arena_cave-cerulean", false)
addF({ "DIGLETTS_CAVE" }, "arena_cave-diglett", false)
addF({ "MT_MOON_1F", "MT_MOON_B1F", "MT_MOON_B2F" },
     "arena_cave-mt-moon", false)
addF({ "ROCK_TUNNEL_1F", "ROCK_TUNNEL_B1F" },
     "arena_cave-rock-tunnel", false)
addF({ "SEAFOAM_ISLANDS_1F", "SEAFOAM_ISLANDS_B1F",
      "SEAFOAM_ISLANDS_B2F", "SEAFOAM_ISLANDS_B3F",
      "SEAFOAM_ISLANDS_B4F" }, "arena_cave-seafoam", false)
addF({ "VICTORY_ROAD_1F", "VICTORY_ROAD_2F", "VICTORY_ROAD_3F" },
     "arena_cave-victory-road", false)
add({ "CERULEAN_CITY" }, "arena_cerulean-canal.compact.png", true)
add({ "CINNABAR_ISLAND" }, "arena_coast-cinnabar.compact.png", true)
add({ "ROUTE_19", "ROUTE_20", "ROUTE_21" },
    "arena_coast-surf.compact.png", true)
addF({ "VIRIDIAN_FOREST" }, "arena_forest-viridian", true)
add({ "ROUTE_1" }, "arena_grass-route1.compact.png", true)
-- Kanto Ascendant's wanderer/rematch system can start trainer fights on all
-- canonical outdoor towns, including nine surfaces that the base Gen 1
-- battle-anchor catalog never needed.  ARENA carries its own fixed footing,
-- so bind each of those surfaces to the closest already-reviewed geographic
-- master instead of silently dropping only trainer fights back to flat 2D.
-- This is scenery-only: no overworld cell, trainer position, collision or
-- MAP-mode search is changed.
add({ "PALLET_TOWN", "VIRIDIAN_CITY" },
    "arena_grass-route1.compact.png", true)
add({ "PEWTER_CITY" }, "arena_moon-approach-route3.compact.png", true)
add({ "LAVENDER_TOWN" }, "arena_rock-water-route10.compact.png", true)
add({ "VERMILION_CITY" }, "arena_vermilion-gate-route11.compact.png", true)
add({ "CELADON_CITY", "SAFFRON_CITY" },
    "arena_grass-kanto-open.compact.png", true)
-- The established VASC profile is a suitable green Fuchsia surround, but the
-- FRLG-like counterpart is explicitly the open Safari reserve. Do not leak
-- that savanna painting into the urban city map.
add({ "FUCHSIA_CITY" }, "arena_safari-kanto.compact.png", true)
add({ "INDIGO_PLATEAU" }, "arena_indigo-road-route23.compact.png", true)
add({ "ROUTE_5", "ROUTE_6", "ROUTE_7", "ROUTE_8", "ROUTE_9",
      "ROUTE_12", "ROUTE_13", "ROUTE_14", "ROUTE_15", "ROUTE_16",
      "ROUTE_17", "ROUTE_18" }, "arena_grass-kanto-open.compact.png", true)
add({ "CELADON_GYM" }, "arena_gym-celadon.compact.png", false)
add({ "CERULEAN_GYM" }, "arena_gym-cerulean.compact.png", false)
add({ "CINNABAR_GYM" }, "arena_gym-cinnabar.compact.png", false)
add({ "FIGHTING_DOJO" }, "arena_gym-fighting-dojo.compact.png", false)
add({ "FUCHSIA_GYM" }, "arena_gym-fuchsia.compact.png", false)
add({ "PEWTER_GYM" }, "arena_gym-pewter.compact.png", false)
add({ "SAFFRON_GYM" }, "arena_gym-saffron.compact.png", false)
add({ "VERMILION_GYM" }, "arena_gym-vermilion.compact.png", false)
add({ "VIRIDIAN_GYM" }, "arena_gym-viridian.compact.png", false)
add({ "ROUTE_22" }, "arena_indigo-gate-route22.compact.png", true)
add({ "ROUTE_23" }, "arena_indigo-road-route23.compact.png", true)
addF({ "POWER_PLANT" }, "arena_industrial-power-plant", false)
addF({ "SILPH_CO_2F", "SILPH_CO_3F", "SILPH_CO_4F", "SILPH_CO_5F",
      "SILPH_CO_6F", "SILPH_CO_7F", "SILPH_CO_8F", "SILPH_CO_9F",
      "SILPH_CO_10F", "SILPH_CO_11F" },
    "arena_industrial-silph", false, 1.70,
    { playerX=-8, enemyX=5 })
add({ "OAKS_LAB" }, "arena_interior-oaks-lab.compact.png",
    false, 2.10,
    { playerX=-7, enemyX=18, playerY=-8, enemyY=-8,
      playerZ=-8, enemyZ=44 }, OAK_LAB_WINDOWS)
add({ "LORELEIS_ROOM" }, "arena_league-lorelei.compact.png", false)
add({ "BRUNOS_ROOM" }, "arena_league-bruno.compact.png", false)
add({ "AGATHAS_ROOM" }, "arena_league-agatha.compact.png", false)
add({ "LANCES_ROOM" }, "arena_league-lance.compact.png", false)
add({ "CHAMPIONS_ROOM" }, "arena_league-champion.compact.png", false)
addF({ "POKEMON_MANSION_1F", "POKEMON_MANSION_2F",
      "POKEMON_MANSION_3F", "POKEMON_MANSION_B1F" },
    "arena_mansion-cinnabar", false, 1.55,
    { playerX=-9, enemyX=5 }, MANSION_WINDOWS, MANSION_FRLG_WINDOWS)
add({ "ROUTE_3" }, "arena_moon-approach-route3.compact.png", true)
add({ "ROUTE_4" }, "arena_moon-exit-route4.compact.png", true)
add({ "ROUTE_24" }, "nugget_bridge_a.compact.png", true)
add({ "ROUTE_10" }, "arena_rock-water-route10.compact.png", true)
add({ "GAME_CORNER" }, "arena_rocket-game-corner.compact.png", false, 1.65,
    { playerX=4, enemyX=12 })
addF({ "ROCKET_HIDEOUT_B1F", "ROCKET_HIDEOUT_B2F",
      "ROCKET_HIDEOUT_B3F", "ROCKET_HIDEOUT_B4F" },
    "arena_rocket-hideout", false, 1.70,
    { playerX=-8, enemyX=5 })
add({ "ROUTE_2" }, "arena_route2-forest-gate.compact.png", true)
addF({ "SAFARI_ZONE_CENTER", "SAFARI_ZONE_EAST", "SAFARI_ZONE_NORTH",
       "SAFARI_ZONE_WEST" }, "arena_safari-kanto", true)
add({ "SS_ANNE_1F_ROOMS", "SS_ANNE_2F_ROOMS", "SS_ANNE_B1F_ROOMS" },
    "arena_ship-cabins.compact.png", false, 1.80,
    { playerX=-10, enemyX=6 }, SHIP_CABIN_WINDOWS)
add({ "SS_ANNE_2F" }, "arena_ship-corridor.compact.png",
    false, 1.65, { playerX=-9, enemyX=5 }, SHIP_CORRIDOR_WINDOWS)
add({ "SS_ANNE_BOW" }, "arena_ship-bow.compact.png", true)
addF({ "POKEMON_TOWER_2F", "POKEMON_TOWER_3F", "POKEMON_TOWER_4F",
      "POKEMON_TOWER_5F", "POKEMON_TOWER_6F", "POKEMON_TOWER_7F" },
    "arena_tower-lavender", false, 1.50,
    { playerX=-9, enemyX=5 })
add({ "ROUTE_11" }, "arena_vermilion-gate-route11.compact.png", true)

return specs
