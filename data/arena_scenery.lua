-- Reviewed full-frame Arena Scenery, selected in the 111-anchor gallery.
--
-- Every entry owns an exact 1280x800 bitmap and the same authored 3X screen
-- footing: player lower-left, opponent upper-right.  The positions remain
-- explicit on every returned spec so a missing or malformed record fails
-- closed instead of silently borrowing a generic arena.

local specs = {}

local function add(ids, file, outdoor, actorScale, actorSpread, windowRegions)
  local playerX, enemyX
  if type(actorSpread) == "table" then
    playerX = actorSpread.playerX or 0
    enemyX = actorSpread.enemyX or 0
  else
    playerX = -(actorSpread or 0)
    enemyX = actorSpread or 0
  end
  local spec = {
    path = "assets/battle/" .. file,
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
      player = { x = playerX, y = -8, z = 0 },
      enemy = { x = enemyX, y = -16, z = 0 },
    },
  }
  for _, id in ipairs(ids) do specs[id] = spec end
end

-- Window masks deliberately stop inside the physical frames.  Multiplying
-- these shapes is enough to turn the painted outdoor view through morning,
-- day, evening and night without blue-washing the room, its lamps or actors.
local OAK_LAB_WINDOWS = {
  { shape="rect", x=759, y=51, w=69, h=127 },
  { shape="rect", x=838, y=51, w=70, h=127 },
  { shape="poly", points={ 969,20, 1155,18, 1152,269, 964,269 } },
}
local MANSION_WINDOWS = {
  { shape="rect", x=54, y=91, w=106, h=190 },
  { shape="rect", x=536, y=116, w=62, h=148 },
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
add({ "CERULEAN_CAVE_1F", "CERULEAN_CAVE_2F", "CERULEAN_CAVE_B1F" },
    "arena_cave-cerulean.compact.png", false)
add({ "DIGLETTS_CAVE" }, "arena_cave-diglett.compact.png", false)
add({ "MT_MOON_1F", "MT_MOON_B1F", "MT_MOON_B2F" },
    "arena_cave-mt-moon.compact.png", false)
add({ "ROCK_TUNNEL_1F", "ROCK_TUNNEL_B1F" },
    "arena_cave-rock-tunnel.compact.png", false)
add({ "SEAFOAM_ISLANDS_1F", "SEAFOAM_ISLANDS_B1F",
      "SEAFOAM_ISLANDS_B2F", "SEAFOAM_ISLANDS_B3F",
      "SEAFOAM_ISLANDS_B4F" }, "arena_cave-seafoam.compact.png", false)
add({ "VICTORY_ROAD_1F", "VICTORY_ROAD_2F", "VICTORY_ROAD_3F" },
    "arena_cave-victory-road.compact.png", false)
add({ "CERULEAN_CITY" }, "arena_cerulean-canal.compact.png", true)
add({ "CINNABAR_ISLAND" }, "arena_coast-cinnabar.compact.png", true)
add({ "ROUTE_19", "ROUTE_20", "ROUTE_21" },
    "arena_coast-surf.compact.png", true)
add({ "VIRIDIAN_FOREST" }, "arena_forest-viridian.compact.png", true)
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
add({ "POWER_PLANT" }, "arena_industrial-power-plant.compact.png", false)
add({ "SILPH_CO_2F", "SILPH_CO_3F", "SILPH_CO_4F", "SILPH_CO_5F",
      "SILPH_CO_6F", "SILPH_CO_7F", "SILPH_CO_8F", "SILPH_CO_9F",
      "SILPH_CO_10F", "SILPH_CO_11F" },
    "arena_industrial-silph.compact.png", false, 1.70,
    { playerX=-8, enemyX=5 })
add({ "OAKS_LAB" }, "arena_interior-oaks-lab.compact.png",
    false, 2.10, 7, OAK_LAB_WINDOWS)
add({ "LORELEIS_ROOM" }, "arena_league-lorelei.compact.png", false)
add({ "BRUNOS_ROOM" }, "arena_league-bruno.compact.png", false)
add({ "AGATHAS_ROOM" }, "arena_league-agatha.compact.png", false)
add({ "LANCES_ROOM" }, "arena_league-lance.compact.png", false)
add({ "CHAMPIONS_ROOM" }, "arena_league-champion.compact.png", false)
add({ "POKEMON_MANSION_1F", "POKEMON_MANSION_2F",
      "POKEMON_MANSION_3F", "POKEMON_MANSION_B1F" },
    "arena_mansion-cinnabar.compact.png", false, 1.55,
    { playerX=-9, enemyX=5 }, MANSION_WINDOWS)
add({ "ROUTE_3" }, "arena_moon-approach-route3.compact.png", true)
add({ "ROUTE_4" }, "arena_moon-exit-route4.compact.png", true)
add({ "ROUTE_24" }, "nugget_bridge_a.compact.png", true)
add({ "ROUTE_10" }, "arena_rock-water-route10.compact.png", true)
add({ "GAME_CORNER" }, "arena_rocket-game-corner.compact.png", false, 1.65,
    { playerX=4, enemyX=12 })
add({ "ROCKET_HIDEOUT_B1F", "ROCKET_HIDEOUT_B2F",
      "ROCKET_HIDEOUT_B3F", "ROCKET_HIDEOUT_B4F" },
    "arena_rocket-hideout.compact.png", false, 1.70,
    { playerX=-8, enemyX=5 })
add({ "ROUTE_2" }, "arena_route2-forest-gate.compact.png", true)
add({ "SAFARI_ZONE_CENTER", "SAFARI_ZONE_EAST", "SAFARI_ZONE_NORTH",
      "SAFARI_ZONE_WEST" }, "arena_safari-kanto.compact.png", true)
add({ "SS_ANNE_1F_ROOMS", "SS_ANNE_2F_ROOMS", "SS_ANNE_B1F_ROOMS" },
    "arena_ship-cabins.compact.png", false, 1.80,
    { playerX=-10, enemyX=6 }, SHIP_CABIN_WINDOWS)
add({ "SS_ANNE_2F" }, "arena_ship-corridor.compact.png",
    false, 1.65, { playerX=-9, enemyX=5 }, SHIP_CORRIDOR_WINDOWS)
add({ "SS_ANNE_BOW" }, "arena_ship-bow.compact.png", true)
add({ "POKEMON_TOWER_2F", "POKEMON_TOWER_3F", "POKEMON_TOWER_4F",
      "POKEMON_TOWER_5F", "POKEMON_TOWER_6F", "POKEMON_TOWER_7F" },
    "arena_tower-lavender.compact.png", false, 1.50,
    { playerX=-9, enemyX=5 })
add({ "ROUTE_11" }, "arena_vermilion-gate-route11.compact.png", true)

return specs
