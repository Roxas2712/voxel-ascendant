-- Native Kanto rooms only. Additive backdrops never edit blocks, collisions,
-- warps or actors. Camera-facing walls are hidden as complete panels.
local M = { assets = {}, profiles = {} }
for _, theme in ipairs({'lab','mart','center','home','traditional_home','coastal_home',
  'daycare','hotel','diner','workshop','museum','elevator',
  'casino','corporate','rocket','power_plant','gate','ruined_mansion',
  'ice_hall','stone_hall','spirit_hall','dragon_hall','champion_hall','underground'}) do
  M.assets['kanto_'..theme] = {
    path='assets/interiors/'..theme..'.png', sourceW=2172, sourceH=724, fitDevice=true,
  }
end
M.assets.kanto_casino.sourceW=2164;M.assets.kanto_casino.sourceH=727
M.assets.kanto_corporate.sourceW=2171
M.assets.kanto_spirit_hall.sourceW=2164;M.assets.kanto_spirit_hall.sourceH=727
local function room(id, tileset, width, height, theme, wallHeight)
  M.profiles[id] = {
    tileset=tileset, width=width, height=height, theme=theme,
    enabled=true, shellHeight=(wallHeight or 64)*0.625, wallDistance=0,
    wallAsset='kanto_'..theme,
    nativeRoomPanels=true,
    wallEdges={north=true,south=true,west=true,east=true},
    ceiling={enabled=true,authored=true}, doors={},
  }
end
room('OAKS_LAB','DOJO',5,6,'lab',72)
for _, town in ipairs({'VIRIDIAN','PEWTER','CERULEAN','VERMILION','LAVENDER','CELADON','FUCHSIA','SAFFRON','CINNABAR','MT_MOON','ROCK_TUNNEL'}) do
  room(town..'_POKECENTER','POKECENTER',7,4,'center',72)
end
for _, town in ipairs({'VIRIDIAN','PEWTER','CERULEAN','VERMILION','LAVENDER','FUCHSIA','SAFFRON','CINNABAR'}) do
  room(town..'_MART','MART',4,4,'mart')
end
for floor=1,5 do room('CELADON_MART_'..floor..'F','LOBBY',10,4,'mart',80) end
for _, id in ipairs({'BLUES_HOUSE','CELADON_MANSION_ROOF_HOUSE','CERULEAN_TRADE_HOUSE',
  'PEWTER_NIDORAN_HOUSE','PEWTER_SPEECH_HOUSE','ROUTE_16_FLY_HOUSE',
  'ROUTE_2_TRADE_HOUSE','SAFFRON_PIDGEY_HOUSE','VIRIDIAN_NICKNAME_HOUSE',
  'VIRIDIAN_SCHOOL_HOUSE'}) do room(id,'HOUSE',4,4,'home') end
for _, id in ipairs({'FUCHSIA_BILLS_GRANDPAS_HOUSE','LAVENDER_CUBONE_HOUSE',
  'MR_FUJIS_HOUSE','MR_PSYCHICS_HOUSE','NAME_RATERS_HOUSE'}) do room(id,'HOUSE',4,4,'traditional_home') end
for _, id in ipairs({'ROUTE_12_SUPER_ROD_HOUSE','VERMILION_OLD_ROD_HOUSE',
  'VERMILION_PIDGEY_HOUSE','VERMILION_TRADE_HOUSE'}) do room(id,'HOUSE',4,4,'coastal_home') end
for _, prefix in ipairs({'REDS_HOUSE','COPYCATS_HOUSE'}) do
  room(prefix..'_1F','REDS_HOUSE_1',4,4,'home')
  room(prefix..'_2F','REDS_HOUSE_2',4,4,'home')
end
room('BILLS_HOUSE','INTERIOR',4,4,'lab')
room('CELADON_CHIEF_HOUSE','MANSION',4,4,'home')
room('CERULEAN_BADGE_HOUSE','SHIP',4,4,'coastal_home')
room('FUCHSIA_GOOD_ROD_HOUSE','SHIP',4,4,'coastal_home')
room('POKEMON_FAN_CLUB','INTERIOR',4,4,'coastal_home')
room('WARDENS_HOUSE','LAB',5,4,'traditional_home')
for _, bearing in ipairs({'CENTER','EAST','NORTH','WEST'}) do
  room('SAFARI_ZONE_'..bearing..'_REST_HOUSE','GATE',4,4,'traditional_home')
end
room('SAFARI_ZONE_SECRET_HOUSE','LAB',4,4,'traditional_home')
room('DAYCARE','HOUSE',4,4,'daycare')
room('CERULEAN_TRASHED_HOUSE','HOUSE',4,4,'home')
room('BIKE_SHOP','CLUB',4,4,'workshop')
room('CELADON_HOTEL','POKECENTER',7,4,'hotel',72)
room('CELADON_DINER','LOBBY',5,4,'diner')
for floor=1,3 do room('CELADON_MANSION_'..floor..'F','MANSION',4,6,'hotel') end
room('MUSEUM_1F','MUSEUM',10,4,'museum',80)
room('MUSEUM_2F','MUSEUM',7,4,'museum',80)
room('CINNABAR_LAB','LAB',9,4,'lab',72)
for _,kind in ipairs({'FOSSIL','METRONOME','TRADE'}) do
  room('CINNABAR_LAB_'..kind..'_ROOM','LAB',4,4,'lab')
end
-- Closed ship decks/cabins reuse the coastal wall material. Bow stays open.
for _,entry in ipairs({{'1F',20,9},{'2F',20,9},{'3F',10,3},{'B1F',15,4},
 {'1F_ROOMS',12,8},{'2F_ROOMS',12,8},{'B1F_ROOMS',12,8},
 {'CAPTAINS_ROOM',3,4},{'KITCHEN',7,8}})do
 local id='SS_ANNE_'..entry[1]
 room(id,'SHIP',entry[2],entry[3],'coastal_home')
 M.profiles[id].ceiling.style='ship'
end
-- Registered KASC building interiors only; cave habitats and open islands
-- remain with their existing scenery owners. Exact dimensions gate each map.
room('KA_NGPLUS_LEGACY_WORKSHOP','FACILITY',8,9,'workshop',80)
for _,id in ipairs({'KA_ROCKET_SILPH_COMMAND_1F','KA_ROCKET_SILPH_RELAY_1F'})do
 room(id,'FACILITY',15,9,'rocket',80)
end
room('KA_JOHTO_GOLD_FINALE','GYM',4,4,'champion_hall',80)
room('KA_JOHTO_SILVER_FINALE','GYM',5,6,'stone_hall',80)
room('KA_JOHTO_KRIS_FINALE','CEMETERY',5,6,'spirit_hall',80)
room('KA_ROCKET_TOWER_RELAY_1F','CEMETERY',10,9,'spirit_hall',80)
room('INDIGO_PLATEAU_LOBBY','MART',8,6,'center',80)
room('FUCHSIA_MEETING_ROOM','LAB',7,4,'traditional_home')
room('GAME_CORNER','LOBBY',10,9,'casino',80)
room('GAME_CORNER_PRIZE_ROOM','LOBBY',5,4,'casino')
for _,floor in ipairs({'1F','2F','B1F'}) do room('POKEMON_MANSION_'..floor,'FACILITY',15,14,'ruined_mansion',80) end
room('POKEMON_MANSION_3F','FACILITY',15,9,'ruined_mansion',80)
room('POWER_PLANT','FACILITY',20,18,'power_plant',80)
-- Large exploratory layouts need a stable floor plan in dollhouse views.
-- Eye-level views retain normal room visibility and complete walls.
for _,id in ipairs({'POKEMON_MANSION_1F','POKEMON_MANSION_2F',
 'POKEMON_MANSION_3F','POKEMON_MANSION_B1F','POWER_PLANT'})do
 M.profiles[id].cutawayPlan=true
end
for floor=1,4 do
 local id='ROCKET_HIDEOUT_B'..floor..'F'
 room(id,'FACILITY',15,floor==4 and 12 or 14,'rocket',80)
 -- As in the Mansion: authored partitions own occlusion. Flood-masking an
 -- adjoining room leaves black floor gaps and slices the dungeon from above.
 M.profiles[id].cutawayPlan=true
end
room('ROCKET_HIDEOUT_ELEVATOR','LOBBY',3,4,'elevator')
for floor=1,10 do
  local width=({[6]=13,[7]=13,[8]=13,[9]=13,[10]=8})[floor] or 15
  room('SILPH_CO_'..floor..'F','FACILITY',width,9,'corporate',80)
end
room('SILPH_CO_11F','INTERIOR',9,9,'corporate',80)
-- Silph's authored partitions already close each office. The chamber flood
-- mask otherwise erases neighbouring native floor cells and slices walls
-- to black, just as in the Mansion and Rocket Hideout. Keep the complete
-- native footprint; depth and the camera-side cutaway still own occlusion.
for floor=1,11 do M.profiles['SILPH_CO_'..floor..'F'].cutawayPlan=true end
room('SILPH_CO_ELEVATOR','LOBBY',2,2,'elevator')
room('CELADON_MART_ELEVATOR','LOBBY',2,2,'elevator')
for _,route in ipairs({11,12,15,16,18}) do
  room('ROUTE_'..route..'_GATE_1F','GATE',route==12 and 5 or 4,route==12 and 4 or (route==16 and 7 or 5),'gate')
  room('ROUTE_'..route..'_GATE_2F','GATE',4,4,'gate')
end
for _,route in ipairs({2,22}) do room('ROUTE_'..route..'_GATE','GATE',5,4,'gate') end
for _,route in ipairs({5,6}) do room('ROUTE_'..route..'_GATE','GATE',4,3,'gate') end
for _,route in ipairs({7,8}) do room('ROUTE_'..route..'_GATE','GATE',3,4,'gate') end
room('SAFARI_ZONE_GATE','GATE',4,3,'gate')
for _,route in ipairs({5,6,7,8}) do room('UNDERGROUND_PATH_ROUTE_'..route,'GATE',4,4,'gate') end
room('TRADE_CENTER','CLUB',5,4,'center')
room('COLOSSEUM','CLUB',5,4,'corporate')
room('LORELEIS_ROOM','GYM',5,6,'ice_hall',80)
room('BRUNOS_ROOM','GYM',5,6,'stone_hall',80)
room('AGATHAS_ROOM','CEMETERY',5,6,'spirit_hall',80)
room('LANCES_ROOM','DOJO',13,13,'dragon_hall',80)
room('CHAMPIONS_ROOM','GYM',4,4,'champion_hall',80)
room('HALL_OF_FAME','GYM',5,4,'champion_hall',80)
room('UNDERGROUND_PATH_NORTH_SOUTH','UNDERGROUND',4,24,'underground')
room('UNDERGROUND_PATH_WEST_EAST','UNDERGROUND',25,4,'underground')
for _,bearing in ipairs({'NORTH','SOUTH'}) do room('VIRIDIAN_FOREST_'..bearing..'_GATE','FOREST_GATE',5,4,'gate') end
-- Authored ceilings share the shell's existing orbit cutaway.
for _,id in ipairs({'OAKS_LAB','GAME_CORNER','CELADON_MART_1F','CELADON_MART_2F',
 'CELADON_MART_3F','CELADON_MART_4F','CELADON_MART_5F'})do
 M.profiles[id].ceiling={enabled=true,authored=true}
end
-- Native north-edge warps stay visible through the decorative backing,
-- including the story-critical breach in Cerulean's trashed house.
function M.profileFor(map)
  local d=map and map.def
  if not d then return nil end
  local p=M.profiles[tostring(map.id or d.id or '')]
  if p and d.tileset==p.tileset and d.width==p.width and d.height==p.height
      and next(d.connections or {})==nil then
    local doors,openCells={},{}
    for _,warp in ipairs(d.warps or {}) do
      if warp.y==0 and type(warp.x)=='number' and warp.x>=0 and warp.x<d.width*2 then
        openCells[warp.x]=true
      end
    end
    -- The panorama sits outside the map perimeter. Walkable cells against
    -- a closed outer boundary still need backing; only real exits cut it.
    -- This differs from Johto's backing quads placed inside blocked cells.
    for x=0,d.width*2-1 do
      if openCells[x] then
        doors[#doors+1]={edge='north',from=x/(d.width*2),upto=(x+1)/(d.width*2),
          height=map.id=='CERULEAN_TRASHED_HOUSE' and 28 or math.min(24,p.shellHeight-16),open=true}
      end
    end
    if #doors==0 then return p end
    local profile={};for key,value in pairs(p)do profile[key]=value end
    profile.doors=doors;return profile
  end
end
return M
