local root=assert(arg[1]);local M=assert(loadfile(root..'/lib/KascBirthIsland.lua'))({require=function()return {setting={get=function()return true end}}end})
local d={id='KA_HOENN_BIRTH_ISLAND',index=1987,tileset='CAVERN',width=8,height=8,objects={{name='KA_HOENN_BIRTH_TRIANGLE',x=8,y=8},{name='KA_HOENN_BIRTH_RETURN',x=8,y=13}},blocks={}}
for y=0,7 do for x=0,7 do d.blocks[#d.blocks+1]=(x==0 or y==0 or x==7 or y==7)and 125 or 25 end end
local map={id=d.id,def=d};function map:isWalkableCell(x,y)return x>=2 and y>=2 and x<=13 and y<=13 end
local before=table.concat(d.blocks,',');local P={models={},decorColors={looseRock6=1,looseRock5=2,oldBoard=3,oldBeam=4,walnut=5,oak=6}}
local props=M.find(P,map);assert(#props==1);local model=assert(P.models[props[1].kind]);assert(model.support==0 and model.actorSurface)
for y=0,15 do for x=0,15 do
 assert(model.groundAt(x*16,y*16)==(map:isWalkableCell(x,y)and 5 or 20))
end end
-- The actual six puzzle positions and every surrounding native land cell
-- remain supported, without any new above-ground geometry across them.
for _,p in ipairs({{8,8},{5,6},{11,6},{6,3},{10,3},{8,4}})do
 assert(map:isWalkableCell(p[1],p[2]))
 for _,b in ipairs(model.boxes)do
  if b[2]+b[5]>.2 then assert(not(p[1]*16<b[1]+b[4]and(p[1]+1)*16>b[1]and p[2]*16<b[3]+b[6]and(p[2]+1)*16>b[3]),'scenery covers puzzle cell')end
 end
end
local triangle=assert(P.models[M.triangle(P)]);assert(#triangle.boxes>5)
for _,b in ipairs(triangle.boxes)do assert(b[1]>=0 and b[3]>=0 and b[1]+b[4]<=16 and b[3]+b[6]<=16)end
assert(before==table.concat(d.blocks,','));assert(d.objects[1].x==8 and d.objects[2].y==13)
for _,field in ipairs({'id','tileset','index'})do local old=d[field];d[field]='OTHER';if field=='id'then map.id='OTHER'end;assert(not M.matches(map));d[field]=old;map.id=d.id end
d.objects[2].x=7;assert(not M.matches(map),'moved landing still receives fixed boat');d.objects[2].x=8
d.generation=2;assert(not M.matches(map));d.generation=nil;d.objects={};assert(not M.matches(map))
print('PASS Birth Island native footprint, six puzzle positions, actor geometry, unchanged gameplay and strict guards')
