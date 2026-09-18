-- Exact native Route23 architecture; entrances stay at the original warps.
local V=...
local specs={
{name="victory_road_gate",x=0,y=56,w=36,h=8,tiles={
 {46,47,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,46,47},
 {46,47,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,46,47},
 {37,38,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,37,38},
 {40,41,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,40,41},
 {21,22,15,15,15,15,15,15,15,15,15,15,15,15,15,15,46,47,3,3,3,3,3,3,3,3,46,47,15,15,15,15,15,15,21,22},
 {5,6,15,15,15,15,15,15,15,15,15,15,15,15,15,15,46,47,3,3,3,3,3,3,3,3,46,47,15,15,15,15,15,15,5,6},
 {5,6,15,15,15,15,15,15,11,12,15,15,15,15,15,15,46,47,3,3,3,3,3,3,3,3,46,47,11,12,15,15,15,15,5,6},
 {21,22,14,14,14,14,14,14,27,28,14,14,14,14,14,14,46,47,3,3,3,3,3,3,3,3,46,47,27,28,14,14,14,14,21,22},
}},
{name="route23_south_gate",x=4,y=280,w=24,h=8,tiles={
 {64,62,62,62,62,62,62,62,62,62,62,62,62,62,62,62,62,62,62,62,62,62,62,65},
 {68,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,68},
 {68,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,68},
 {68,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,68},
 {68,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,68},
 {68,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,68},
 {68,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,68},
 {68,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,68},
}},
}
return function(M,F)
 for _,spec in ipairs(specs)do
  local p=spec
  F.patterns[#F.patterns+1]={kind='kanto_building',sets={PLATEAU=true},maps={ROUTE_23=true},
   x=p.x,y=p.y,tiles=p.tiles,voxelOnly=true,groundTile=35,
   enabled=function()return V.require('Gen1PalletVillage').buildings:get()end,
   guard=function(map)
    local d=map.def
    if d.generation==2 or d.width~=10 or d.height~=72 then return false end
    local required=p.name=='victory_road_gate'and {{4,31,'VICTORY_ROAD_1F'},{14,31,'VICTORY_ROAD_2F'}}
      or {{7,139,'ROUTE_22_GATE'},{8,139,'ROUTE_22_GATE'}}
    for _,want in ipairs(required)do
     local found=false;for _,warp in ipairs(d.warps or{})do
      if warp.x==want[1]and warp.y==want[2]and warp.destMap==want[3]then found=true end
     end
     if not found then return false end
    end
    return true
   end,
   variant=function(map)return M.create('kanto_building_'..p.name,map,p.x,p.y,p.w,p.h,p.name)end}
 end
end
