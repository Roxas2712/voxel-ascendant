-- Location-aware procedural battle-field styles. Twenty-two base families
-- cover the 95 authored maps/111 anchors; anchor and height seed a stable
-- room-local variant without shipping external artwork.

local V = ...
local Style = {}

Style.PROFILES = {
  grass =      { pattern="grass",   top={.48,.68,.30}, alt={.37,.55,.22}, edge={.20,.36,.15} },
  city =       { pattern="paving",  top={.67,.66,.55}, alt={.57,.57,.48}, edge={.30,.31,.29} },
  forest =     { pattern="leaves",  top={.25,.48,.22}, alt={.15,.36,.17}, edge={.09,.24,.12} },
  coast =      { pattern="waves",   top={.43,.66,.65}, alt={.32,.54,.58}, edge={.18,.35,.48} },
  cave =       { pattern="stone",   top={.48,.43,.36}, alt={.37,.33,.29}, edge={.21,.19,.18} },
  mansion =    { pattern="tiles",   top={.57,.38,.31}, alt={.44,.27,.25}, edge={.26,.16,.17} },
  tower =      { pattern="runes",   top={.39,.34,.45}, alt={.28,.25,.35}, edge={.16,.13,.23} },
  industrial = { pattern="panels",  top={.48,.55,.52}, alt={.36,.44,.43}, edge={.18,.25,.25} },
  rocket =     { pattern="panels",  top={.34,.35,.38}, alt={.22,.23,.27}, edge={.55,.16,.18} },
  safari =     { pattern="sand",    top={.69,.62,.36}, alt={.57,.50,.27}, edge={.30,.37,.18} },
  ship =       { pattern="deck",    top={.61,.47,.30}, alt={.49,.36,.24}, edge={.24,.30,.32} },
  gym =        { pattern="court",   top={.61,.58,.42}, alt={.49,.47,.35}, edge={.30,.21,.14} },
  interior =   { pattern="tiles",   top={.60,.56,.45}, alt={.49,.46,.39}, edge={.28,.27,.25} },
  league_ice = { pattern="crystal", top={.65,.82,.86}, alt={.46,.68,.76}, edge={.25,.43,.62} },
  league_rock ={ pattern="stone",   top={.55,.45,.35}, alt={.42,.32,.25}, edge={.24,.16,.12} },
  league_ghost={ pattern="runes",   top={.44,.31,.51}, alt={.30,.20,.39}, edge={.18,.11,.26} },
  league_dragon={pattern="scales",  top={.38,.52,.58}, alt={.27,.40,.48}, edge={.18,.25,.34} },
  league_champion={pattern="court", top={.72,.63,.33}, alt={.56,.47,.23}, edge={.33,.24,.12} },
  johto_silver={pattern="panels",   top={.62,.66,.70}, alt={.45,.51,.58}, edge={.24,.30,.38} },
  johto_crystal={pattern="crystal", top={.42,.77,.76}, alt={.30,.59,.65}, edge={.20,.35,.48} },
  johto_gold = { pattern="court",   top={.80,.67,.28}, alt={.64,.49,.18}, edge={.38,.27,.09} },
  red_basalt = { pattern="runes",   top={.39,.25,.22}, alt={.27,.16,.16}, edge={.64,.22,.12} },
  route2_gate = { pattern="gate", motif="route2_gate",
    top={.34,.55,.28}, alt={.24,.42,.21}, edge={.42,.39,.27} },
  moon_approach={pattern="stone", motif="moon",
    top={.56,.48,.38}, alt={.43,.36,.30}, edge={.27,.23,.22} },
  moon_exit =  { pattern="stone", motif="moon_exit",
    top={.61,.53,.41}, alt={.47,.40,.32}, edge={.31,.27,.24} },
  rock_water = { pattern="waves", motif="rock_water",
    top={.43,.60,.58}, alt={.34,.47,.49}, edge={.28,.30,.27} },
  vermilion_gate={pattern="deck", motif="vermilion_gate",
    top={.66,.52,.34}, alt={.52,.39,.28}, edge={.27,.34,.37} },
  indigo_gate ={ pattern="court", motif="indigo_gate",
    top={.58,.59,.61}, alt={.43,.46,.50}, edge={.32,.25,.45} },
  indigo_road ={ pattern="crystal", motif="indigo_road",
    top={.55,.63,.68}, alt={.40,.50,.59}, edge={.28,.22,.43} },
  nugget_bridge={pattern="bridge", motif="nugget_bridge",
    top={.68,.66,.52}, alt={.52,.54,.49}, edge={.82,.62,.17} },
  cape =        { pattern="waves", motif="cape",
    top={.50,.69,.63}, alt={.37,.57,.58}, edge={.24,.42,.54} },
  cerulean_canal={pattern="canal", motif="cerulean_canal",
    top={.57,.67,.61}, alt={.42,.57,.58}, edge={.25,.43,.60} },
}

local function hash(s)
  local h = 2166136261
  for i = 1, #s do h = (h * 16777619 + s:byte(i)) % 4294967291 end
  return h
end

local EXACT = {
  LORELEIS_ROOM="league_ice", BRUNOS_ROOM="league_rock",
  AGATHAS_ROOM="league_ghost", LANCES_ROOM="league_dragon",
  CHAMPIONS_ROOM="league_champion",
  ROUTE_2="route2_gate", ROUTE_3="moon_approach", ROUTE_4="moon_exit",
  ROUTE_10="rock_water", ROUTE_11="vermilion_gate",
  ROUTE_22="indigo_gate", ROUTE_23="indigo_road",
  ROUTE_24="nugget_bridge", ROUTE_25="cape",
  CERULEAN_CITY="cerulean_canal",
}

local function family(map)
  local id = tostring(map and map.id or "")
  if EXACT[id] then return EXACT[id] end
  if id:match("^KA_JOHTO_SILVER_") then return "johto_silver" end
  if id:match("^KA_JOHTO_KRIS_") then return "johto_crystal" end
  if id:match("^KA_JOHTO_GOLD_") then return "johto_gold" end
  if id:match("^KA_HEVO_RED_") then return "red_basalt" end
  if id:find("SS_ANNE", 1, true) then return "ship" end
  if id:find("SAFARI_ZONE", 1, true) then return "safari" end
  if id:find("ROCKET_HIDEOUT", 1, true) or id == "GAME_CORNER" then return "rocket" end
  if id:find("SILPH_CO", 1, true) or id == "POWER_PLANT" then return "industrial" end
  if id:find("POKEMON_TOWER", 1, true) then return "tower" end
  if id:find("POKEMON_MANSION", 1, true) then return "mansion" end
  if id:find("GYM", 1, true) or id == "FIGHTING_DOJO" then return "gym" end
  if id:find("FOREST", 1, true) then return "forest" end
  if id:find("CAVE", 1, true) or id:find("TUNNEL", 1, true)
     or id:find("MT_MOON", 1, true) or id:find("VICTORY_ROAD", 1, true)
     or id:find("SEAFOAM_ISLANDS", 1, true) then return "cave" end
  if id == "ROUTE_19" or id == "ROUTE_20" or id == "ROUTE_21"
     or id == "CINNABAR_ISLAND" then return "coast" end
  if id:find("CITY", 1, true) or id:find("TOWN", 1, true) then return "city" end
  local tileset = map and map.def and map.def.tileset
  if tileset and tileset ~= "OVERWORLD" then return "interior" end
  return "grass"
end

function Style.resolve(map, arena)
  local id = tostring(map and map.id or "UNKNOWN")
  local profile = family(map)
  local anchor = arena and arena.anchorIndex or 0
  local height = arena and arena.anchorHeight or 0
  local variant = id .. ":" .. tostring(anchor) .. ":" .. tostring(height)
  return { id=profile, profile=Style.PROFILES[profile], variant=variant,
           seed=hash(variant), mapId=id, anchorIndex=anchor,
           anchorHeight=height }
end

function Style.audit()
  local ok, authored = pcall(V.data, "battle_arenas")
  local maps, anchors = 0, 0
  if ok and type(authored) == "table" then
    for _, entry in pairs(authored) do
      maps = maps + 1
      anchors = anchors + ((type(entry.spots) == "table" and #entry.spots) or 1)
    end
  end
  local profiles = 0
  for _ in pairs(Style.PROFILES) do profiles = profiles + 1 end
  return { maps=maps, anchors=anchors, profiles=profiles }
end

return Style
