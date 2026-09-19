-- Room materials belong only to the 3D ground surface. Native tiles and their
-- atlas remain authoritative for 2D, walls, stairs and gameplay. Audited
-- CLUB floor accents retain their positions in the optional 3D material.
local V=...
local M={}
M.setting=V.require('ModSetting').new('interiorFloors','INDOOR FLOORS',
  {true,false},{'ON','OFF'})
local rooms=V.require('Gen1InteriorPanoramas')
-- Native Gen-1 arena floors: violet stone, dojo boards and laboratory tile.
-- Reuse the established materials; puzzle graphics keep their original atlas.
local gymFloors={SAFFRON_GYM={8,'FACILITY',10,9},
  FUCHSIA_GYM={2,'GYM',5,9},CINNABAR_GYM={6,'FACILITY',10,9}}
local families={lab=1,home=2,traditional_home=2,coastal_home=3,daycare=2,
  hotel=2,diner=3,center=4,mart=5,workshop=6,museum=7,casino=8,
  corporate=6,rocket=6,elevator=6,power_plant=6,gate=7,ruined_mansion=9,
  ice_hall=10,stone_hall=7,spirit_hall=8,dragon_hall=9,
  champion_hall=7,underground=7}
-- Only the plain, known flooring graphics. In particular, FACILITY arrows,
-- switches and teleport pads and GYM puzzle markings are never admitted.
local tiles={DOJO={17},GYM={17,9,10,25,26},HOUSE={1},REDS_HOUSE_1={1},
  REDS_HOUSE_2={1},MANSION={1,5,17,80},LAB={1,38},MUSEUM={1,17},LOBBY={32},
  GATE={1,17},SHIP={13,29},FACILITY={1},POKECENTER={1,11,17,27},
  MART={1,11,17,27},INTERIOR={1,11,17,27},CLUB={15,30,31},
  CEMETERY={1},UNDERGROUND={1},FOREST_GATE={1,17}}
local allowed={}
for ts,list in pairs(tiles)do allowed[ts]={};for _,tile in ipairs(list)do allowed[ts][tile]=true end end
function M.profile(map)
  if map and (map.id=='CELADON_MART_ROOF'or map.id=='CELADON_MANSION_ROOF')
   and V.require('VoxelItems').setting:get() and V.require('Gen1RoofTerrace').matches(map)then return 6 end
  if not M.setting:get() then return nil end
  local d=map and map.def
  local gym=d and gymFloors[map.id]
  if gym and d.generation~=2
      and d.tileset==gym[2] and d.width==gym[3] and d.height==gym[4]
      and next(d.connections or {})==nil then
    return gym[1]
  end
  local p=rooms.profileFor(map)
  if not p then return nil end
  if map.id=='TRADE_CENTER' then return 11 end
  if map.id=='COLOSSEUM' then return 12 end
  return families[p.theme]
end
function M.material(map,profile,tile,synthetic)
  if not profile then return nil end
  if not synthetic and profile==1 and map.def.tileset=='LAB'
      and map.id and (map.id=='CINNABAR_LAB' or map.id:match('^CINNABAR_LAB_')) then
    if tile==39 or tile==55 then return -144 end -- quiet entry mat
    if map.id=='CINNABAR_LAB' and (tile==52 or tile==53 or tile==76 or tile==77) then
      return -129 -- the panorama supplies the upright doors at these warps
    end
    if map.id=='CINNABAR_LAB_FOSSIL_ROOM' and (tile==12 or tile==13) then
      return -134 -- walkable work-zone flooring, not a machine footprint
    end
  end
  -- Native FACILITY runners use separate center/selvedge tiles. Retain
  -- their footprints and exit triggers, replacing only the flashing weave.
  if not synthetic and map.def.tileset=='FACILITY' and (tile==66 or tile==82) then
    if profile==9 and map.id and map.id:match('^POKEMON_MANSION_') then
      return tile==66 and -143 or -142
    elseif map.id=='POWER_PLANT' and profile==6 then
      return tile==66 and -145 or -144
    end
  end
  if map.id and map.id:match('_ELEVATOR$') and map.def.tileset=='LOBBY'
      and (tile==55 or tile==69) then return -134 end
  if not synthetic and map.def.tileset=='CLUB' then
    if map.id=='BIKE_SHOP' and (tile==10 or tile==26) then return -141 end
    if (profile==11 or profile==12)
      and (tile==40 or tile==41 or tile==44 or tile==45 or tile==46 or tile==47) then
      return -128-profile
    end
  end
  if synthetic or (allowed[map.def.tileset] or {})[tile] then return -128-profile end
end
-- A single material id at every corner, evaluated in world coordinates by
-- Voxel3D: adjacent terrain quads and Blickfrei fills meet without seams.
function M.bind(invalidate)
  local setting=M.setting
  for _,name in ipairs({'setIndex','sync'})do
    local previous=setting[name]
    setting[name]=function(self,...)
      local before=self:get();local value=previous(self,...)
      if before~=self:get() then invalidate() end
      return value
    end
  end
end
return M
