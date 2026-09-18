-- Source-audited live actors whose exact spawn cell contains authored seating.
-- Decorative people baked into furniture art (for example Gen 1 Pokemon
-- Centers) are intentionally absent: the scenery renderer already owns them.
local M={}
local rows={
 { 1,"BLUES_HOUSE",1,2,3,3,"daisy-oak-kasc-hd-4x3-walk-sheet-v2.png","home" },
 { 1,"CELADON_DINER",3,1,4,0,"middle-aged-man-kasc-hd-4x3-walk-sheet-v1.png","arcade-cafe" },
 { 1,"CELADON_DINER",4,5,3,3,"fisher-kasc-hd-4x3-walk-sheet-v1.png","arcade-cafe" },
 { 1,"CELADON_DINER",5,0,1,0,"gym-guide-kasc-hd-4x3-walk-sheet-v1.png","arcade-cafe" },
 { 1,"CELADON_MANSION_3F",1,0,4,2,"bike-shop-clerk-kasc-hd-4x3-walk-sheet-v1.png","home" },
 { 1,"CELADON_MANSION_3F",2,3,4,2,"clerk-kasc-hd-4x3-walk-sheet-v1.png","home" },
 { 1,"CELADON_MANSION_3F",3,0,7,2,"super-nerd-kasc-hd-4x3-walk-sheet-v1.png","home" },
 { 1,"CELADON_MART_ROOF",1,10,4,1,"super-nerd-kasc-hd-4x3-walk-sheet-v1.png","arcade-cafe" },
 { 1,"CERULEAN_BADGE_HOUSE",1,5,3,3,"middle-aged-man-kasc-hd-4x3-walk-sheet-v1.png","ship" },
 { 1,"CERULEAN_TRADE_HOUSE",1,5,4,1,"granny-kasc-hd-4x3-walk-sheet-v1.png","home" },
 { 1,"CINNABAR_LAB_TRADE_ROOM",1,3,2,0,"super-nerd-kasc-hd-4x3-walk-sheet-v1.png","lab" },
 { 1,"CINNABAR_LAB_TRADE_ROOM",3,5,5,2,"beauty-kasc-hd-4x3-walk-sheet-v1.png","lab" },
 { 1,"COPYCATS_HOUSE_1F",2,5,4,1,"middle-aged-man-kasc-hd-4x3-walk-sheet-v1.png","home" },
 { 1,"DAYCARE",1,2,3,3,"gentleman-kasc-hd-4x3-walk-sheet-v1.png","home" },
 { 1,"FUCHSIA_BILLS_GRANDPAS_HOUSE",1,2,3,3,"middle-aged-woman-kasc-hd-4x3-walk-sheet-v1.png","home" },
 { 1,"FUCHSIA_GOOD_ROD_HOUSE",1,5,3,3,"fishing-guru-kasc-hd-4x3-walk-sheet-v1.png","ship" },
 { 1,"FUCHSIA_MEETING_ROOM",3,10,1,0,"safari-zone-worker-kasc-hd-4x3-walk-sheet-v1.png","lab" },
 { 1,"GAME_CORNER",3,2,10,1,"middle-aged-man-kasc-hd-4x3-walk-sheet-v1.png","arcade-cafe" },
 { 1,"GAME_CORNER",4,2,13,1,"beauty-kasc-hd-4x3-walk-sheet-v1.png","arcade-cafe" },
 { 1,"GAME_CORNER",5,5,11,3,"fishing-guru-kasc-hd-4x3-walk-sheet-v1.png","arcade-cafe" },
 { 1,"GAME_CORNER",6,8,11,1,"middle-aged-woman-kasc-hd-4x3-walk-sheet-v1.png","arcade-cafe" },
 { 1,"GAME_CORNER",7,8,14,1,"gym-guide-kasc-hd-4x3-walk-sheet-v1.png","arcade-cafe" },
 { 1,"GAME_CORNER",8,11,15,3,"gambler-kasc-hd-4x3-walk-sheet-v1.png","arcade-cafe" },
 { 1,"GAME_CORNER",9,14,11,1,"clerk-kasc-hd-4x3-walk-sheet-v1.png","arcade-cafe" },
 { 1,"GAME_CORNER",10,17,13,3,"gentleman-kasc-hd-4x3-walk-sheet-v1.png","arcade-cafe" },
 { 1,"LAVENDER_CUBONE_HOUSE",2,2,4,3,"brunette-girl-kasc-hd-4x3-walk-sheet-v1.png","home" },
 { 1,"MR_PSYCHICS_HOUSE",1,5,3,1,"fishing-guru-kasc-hd-4x3-walk-sheet-v1.png","home" },
 { 1,"NAME_RATERS_HOUSE",1,5,3,1,"silph-president-kasc-hd-4x3-walk-sheet-v1.png","home" },
 { 1,"PEWTER_SPEECH_HOUSE",1,2,3,3,"gambler-kasc-hd-4x3-walk-sheet-v1.png","home" },
 { 1,"POKEMON_FAN_CLUB",1,6,3,1,"fisher-kasc-hd-4x3-walk-sheet-v1.png","fan-club" },
 { 1,"POKEMON_FAN_CLUB",2,1,3,3,"girl-kasc-hd-4x3-walk-sheet-v1.png","fan-club" },
 { 1,"REDS_HOUSE_1F",1,5,4,1,"reds-mother-kasc-hd-4x3-walk-sheet-v2.png","home" },
 { 1,"ROUTE_12_SUPER_ROD_HOUSE",1,2,4,3,"fishing-guru-kasc-hd-4x3-walk-sheet-v1.png","home" },
 { 1,"ROUTE_16_FLY_HOUSE",1,2,3,3,"brunette-girl-kasc-hd-4x3-walk-sheet-v1.png","home" },
 { 1,"ROUTE_2_TRADE_HOUSE",1,2,4,3,"scientist-kasc-hd-4x3-walk-sheet-v1.png","home" },
 { 1,"SAFFRON_PIDGEY_HOUSE",1,2,3,3,"brunette-girl-kasc-hd-4x3-walk-sheet-v1.png","home" },
 { 1,"SAFARI_ZONE_CENTER_REST_HOUSE",1,3,2,0,"girl-kasc-hd-4x3-walk-sheet-v1.png","home" },
 { 1,"SAFARI_ZONE_NORTH_REST_HOUSE",2,3,4,0,"safari-zone-worker-kasc-hd-4x3-walk-sheet-v1.png","home" },
 { 1,"SAFARI_ZONE_WEST_REST_HOUSE",2,0,2,3,"cooltrainer-male-kasc-hd-4x3-walk-sheet-v1.png","home" },
 { 1,"SS_ANNE_B1F_ROOMS",1,0,13,0,"sailor-kasc-hd-4x3-walk-sheet-v1.png","ship" },
 { 1,"SS_ANNE_B1F_ROOMS",7,10,13,3,"super-nerd-kasc-hd-4x3-walk-sheet-v1.png","ship" },
 { 1,"VERMILION_OLD_ROD_HOUSE",1,2,4,3,"fishing-guru-kasc-hd-4x3-walk-sheet-v1.png","home" },
 { 1,"VERMILION_PIDGEY_HOUSE",1,5,3,1,"youngster-gen1-bald-hd-4x3-walk-sheet-v1.png","home" },
 { 1,"VIRIDIAN_NICKNAME_HOUSE",1,5,3,0,"balding-guy-kasc-hd-4x3-walk-sheet-v1.png","home" },
 { 1,"VIRIDIAN_SCHOOL_HOUSE",1,3,5,2,"brunette-girl-kasc-hd-4x3-walk-sheet-v1.png","home" },
 { 2,"CELADON_CAFE",2,4,6,1,"fisher-kasc-hd-4x3-walk-sheet-v1.png","arcade-cafe" },
 { 2,"CELADON_CAFE",3,1,7,3,"fisher-kasc-hd-4x3-walk-sheet-v1.png","arcade-cafe" },
 { 2,"CELADON_CAFE",4,1,2,3,"fisher-kasc-hd-4x3-walk-sheet-v1.png","arcade-cafe" },
 { 2,"CELADON_CAFE",5,4,3,1,"teacher-gen2-kasc-hd-4x3-walk-sheet-v1.png","arcade-cafe" },
 { 2,"CELADON_GAME_CORNER",3,14,10,1,"pokefan-male-gen2-kasc-hd-4x3-walk-sheet-v1.png","arcade-cafe" },
 { 2,"CELADON_GAME_CORNER",4,17,7,3,"teacher-gen2-kasc-hd-4x3-walk-sheet-v1.png","arcade-cafe" },
 { 2,"CELADON_GAME_CORNER",5,11,7,3,"fishing-guru-kasc-hd-4x3-walk-sheet-v1.png","arcade-cafe" },
 { 2,"CELADON_GAME_CORNER",6,8,10,1,"fisher-kasc-hd-4x3-walk-sheet-v1.png","arcade-cafe" },
 { 2,"CELADON_GAME_CORNER",7,8,10,1,"fisher-kasc-hd-4x3-walk-sheet-v1.png","arcade-cafe" },
 { 2,"CELADON_GAME_CORNER",9,2,8,1,"gramps-kasc-hd-4x3-walk-sheet-v1.png","arcade-cafe" },
 { 2,"COPYCATS_HOUSE_1F",1,2,3,0,"pokefan-male-gen2-kasc-hd-4x3-walk-sheet-v1.png","home" },
 { 2,"COPYCATS_HOUSE_1F",2,5,4,1,"pokefan-female-gen2-kasc-hd-4x3-walk-sheet-v1.png","home" },
 { 2,"ELMS_HOUSE",2,5,4,2,"bug-catcher-kasc-hd-4x3-walk-sheet-v1.png","home" },
 { 2,"GOLDENROD_GAME_CORNER",4,8,7,1,"pharmacist-gen2-kasc-hd-4x3-walk-sheet-v1.png","arcade-cafe" },
 { 2,"GOLDENROD_GAME_CORNER",5,8,7,1,"pharmacist-gen2-kasc-hd-4x3-walk-sheet-v1.png","arcade-cafe" },
 { 2,"GOLDENROD_GAME_CORNER",6,11,10,3,"pokefan-male-gen2-kasc-hd-4x3-walk-sheet-v1.png","arcade-cafe" },
 { 2,"GOLDENROD_GAME_CORNER",7,14,8,1,"cooltrainer-male-kasc-hd-4x3-walk-sheet-v1.png","arcade-cafe" },
 { 2,"GOLDENROD_GAME_CORNER",8,17,6,3,"pokefan-female-gen2-kasc-hd-4x3-walk-sheet-v1.png","arcade-cafe" },
 { 2,"GOLDENROD_GAME_CORNER",10,5,10,3,"gentleman-kasc-hd-4x3-walk-sheet-v1.png","arcade-cafe" },
 { 2,"GOLDENROD_GAME_CORNER",12,17,10,3,"pokefan-male-gen2-kasc-hd-4x3-walk-sheet-v1.png","arcade-cafe" },
 { 2,"GOLDENROD_POKECENTER_1F",5,7,5,0,"pokefan-female-gen2-kasc-hd-4x3-walk-sheet-v1.png","pokecenter" },
 { 2,"LAV_RADIO_TOWER_1F",1,6,6,2,"receptionist-gen2-kasc-hd-4x3-walk-sheet-v1.png","radio" },
 { 2,"OLIVINE_CAFE",1,4,3,1,"sailor-kasc-hd-4x3-walk-sheet-v1.png","arcade-cafe" },
 { 2,"OLIVINE_CAFE",3,6,6,2,"sailor-kasc-hd-4x3-walk-sheet-v1.png","arcade-cafe" },
 { 2,"PLAYERS_HOUSE_1F",1,7,4,1,"johto-mother-kasc-hd-4x3-walk-sheet-v1.png","home" },
 { 2,"PLAYERS_HOUSE_1F",3,7,4,1,"johto-mother-kasc-hd-4x3-walk-sheet-v1.png","home" },
 { 2,"PLAYERS_HOUSE_1F",5,4,4,3,"pokefan-female-gen2-kasc-hd-4x3-walk-sheet-v1.png","home" },
 { 2,"RADIO_TOWER_1F",5,8,6,2,"gentleman-kasc-hd-4x3-walk-sheet-v1.png","radio" },
 { 2,"RADIO_TOWER_1F",6,12,6,2,"cooltrainer-female-kasc-hd-4x3-walk-sheet-v1.png","radio" },
 { 2,"RADIO_TOWER_2F",1,6,6,1,"super-nerd-kasc-hd-4x3-walk-sheet-v1.png","radio" },
 { 2,"RADIO_TOWER_3F",1,7,4,2,"super-nerd-kasc-hd-4x3-walk-sheet-v1.png","radio" },
 { 2,"RADIO_TOWER_3F",2,3,4,0,"gym-guide-kasc-hd-4x3-walk-sheet-v1.png","radio" },
 { 2,"REDS_HOUSE_1F",1,5,3,1,"reds-mother-kasc-hd-4x3-walk-sheet-v2.png","home" },
}
local offsets={home=-5,["arcade-cafe"]=-7,radio=-6,pokecenter=-6,ship=-7,lab=-7,museum=-6,["fan-club"]=-5}
local function roleFrom(filename)
 local stem=tostring(filename or ""):gsub("%.png$","")
 stem=stem:gsub("%-variant%-.+$",""):gsub("%-kasc%-hd%-4x3%-walk%-sheet%-v%d+.*$","")
 if stem:match("^youngster%-gen1%-bald")then return "youngster" end
 return stem
end
local tuned={
 ["1:SAFARI_ZONE_WEST_REST_HOUSE:2"]={legDepth=.72},
 ["1:BLUES_HOUSE:1"]={alwaysSeated=true,bodyMin=66,bodyMax=137,headCenter=84,headFade={91,116},headCut={102,121},frontOffset=-3,offsetY=-7,directDialogue=true},
 ["2:PLAYERS_HOUSE_1F:1"]={bodyMin=36,bodyMax=132,headCenter=78,headFade={88,112},headCut={98,114},frontOffset=4,offsetY=-3.2},
 ["2:PLAYERS_HOUSE_1F:3"]={bodyMin=36,bodyMax=132,headCenter=78,headFade={88,112},headCut={98,114},frontOffset=4,offsetY=-3.2},
 ["2:PLAYERS_HOUSE_1F:5"]={bodyMin=68,bodyMax=142,headCenter=86,headFade={92,118},headCut={104,122},frontOffset=-4,offsetY=-3.2},
}
local entries,byGeneration={}, {[1]={},[2]={}}
for _,row in ipairs(rows)do
 local generation,mapId,index,cellX,cellY,facingRow,filename,category=unpack(row)
 -- Gen1 seating describes the native chair occupant, not an optional acting
 -- clip. Keep the exact seat pose in Classic too; dialogue head turns still
 -- depend on the acting option in human_johto_seat. HD/grid OFF stays native.
 local profile={generation=generation,alwaysSeated=generation==1,mapId=mapId,index=index,cellX=cellX,cellY=cellY,
  px=cellX*16,py=cellY*16,row=facingRow,category=category,
  path="assets/characters/npcs/"..filename,role=roleFrom(filename),
  sign=facingRow==1 and -1 or 1,bendSign=facingRow==1 and -1 or facingRow==3 and 1 or 0,
  headFade={90,116},headCut={101,121},frontOffset=0,offsetY=offsets[category]or -6}
 -- Back-facing occupants bend toward their desk, away from the viewing
 -- side of the card. The former shared front-facing depth left their
 -- straight shins on top of the chair. Side poses and Gen2 stay authored.
 if generation==1 and facingRow==2 then profile.legDepth=-3 end
 local custom=tuned[table.concat({generation,mapId,index},":")]
 for key,value in pairs(custom or {})do profile[key]=value end
 entries[#entries+1]=profile
 local maps=byGeneration[generation];maps[mapId]=maps[mapId]or{};maps[mapId][#maps[mapId]+1]=profile
end
M.entries,M.byGeneration=entries,byGeneration
return M
