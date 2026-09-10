local root=assert(arg[1]);local D=assert(loadfile(root..'/lib/GateDoors.lua'))()
local function map(warps)return{def={tileset='OVERWORLD',warps=warps}}end
local function warp(x,y,d)return{x=x,y=y,destMap=d,destWarp=1}end
local cases={
 {'ROUTE_7_GATE',24,16,12,8,11,18,9},
 {'ROUTE_8_GATE',4,16,12,8,1,8,9},
 {'ROUTE_11_GATE_1F',100,12,16,8,49,58,8},
 {'ROUTE_15_GATE_1F',16,12,12,8,7,14,8},
 {'ROUTE_16_GATE_1F',36,4,12,8,17,24,4},
 {'ROUTE_16_GATE_1F',36,12,12,12,17,24,10},
 {'ROUTE_18_GATE_1F',68,8,12,12,33,40,8}}
for _,c in ipairs(cases)do
 local w={warp(c[6],c[8],c[1]),warp(c[6],c[8]+1,c[1]),warp(c[7],c[8],c[1]),warp(c[7],c[8]+1,c[1])}
 local d=D.forBuilding(map(w),c[2],c[3],c[4],c[5]);assert(#d==2,c[1])
 assert(d[1].side=='west' and d[2].side=='east' and d[1].width==32)
 assert(d[1].z>=0 and d[1].z+32<=c[5]*8)
 assert(d[1].x<0 and d[2].x>c[4]*8)
 w[4].destMap='HOUSE';assert(#D.forBuilding(map(w),c[2],c[3],c[4],c[5])==0)
end
local d=D.forBuilding(map{warp(16,35,'ROUTE_2_GATE')},28,72,12,8)
assert(d.north and d.north.x==32 and d.north.width==16,'offset north warp must not mirror south position')
d=D.forBuilding(map{warp(9,29,'ROUTE_5_GATE'),warp(10,29,'ROUTE_5_GATE')},12,60,16,8)
assert(d.north and d.north.width==32 and d.north.x==48)
assert(#D.forBuilding(map{warp(11,9,'HOUSE'),warp(18,9,'HOUSE')},24,16,12,8)==0)
assert(#D.forBuilding({def={tileset='GATE',warps={}}},24,16,12,8)==0)
print('PASS all seven east/west gate structures, both faces, native warp offsets, paired entrance widths and unrelated-building exclusions')

for _,c in ipairs{
 {'ROUTE_2_GATE',28,72,12,8,15,39},
 {'ROUTE_5_GATE',12,60,16,8,10,33},
 {'ROUTE_6_GATE',16,4,12,12,10,7},
 {'ROUTE_12_GATE_1F',16,32,12,12,10,21},
 {'ROUTE_22_GATE',4,0,24,12,8,5},
 {'VIRIDIAN_FOREST_SOUTH_GATE',4,80,8,8,3,43},
 {'SAFARI_ZONE_GATE',32,0,12,8,18,3}}do
 local ds=D.forBuilding(map{warp(c[6],c[7],c[1])},c[2],c[3],c[4],c[5])
 assert(#ds==1 and ds[1].side=='south',c[1]..' missing south facade')
 assert(ds[1].x==(c[6]*16-c[2]*8) and ds[1].z>c[5]*8)
end
print('PASS all seven south entrances are explicitly visible at the real warp columns')
