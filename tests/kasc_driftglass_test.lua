local root=assert(arg[1]);local M=assert(loadfile(root..'/lib/KascDriftglass.lua'))({require=function()return {setting={get=function()return true end}}end})
local d={id='KANTO_ASCENDANT_DRIFTGLASS',index=1900,tileset='OVERWORLD',width=12,height=10,objects={{name='DRIFTGLASS_PRISM_SEAM',x=12,y=9},{name='DRIFTGLASS_RETURN_BOAT',x=8,y=15}}}
local map={id=d.id,def=d};function map:isWalkableCell(x,y)return not(y==13 and(x==10 or x==11))end
local P={models={},decorColors=setmetatable({},{__index=function()return 2 end})}
local props=M.find(P,map);assert(#props==1)
local p=props[1];local model=P.models[p.kind]
for _,b in ipairs(model.boxes)do
 assert(b[7] and b[4]>0 and b[5]>0 and b[6]>0)
 -- Ground-level solid furniture must stay in the two original counter cells.
 if b[2]<24 then
  for y=11,13 do for x=8,11 do
   local wx,wz=p.tx*8+b[1],p.ty*8+b[3]
   local overlap=x*16<wx+b[4]and(x+1)*16>wx and y*16<wz+b[6]and(y+1)*16>wz
   assert(not(overlap and map:isWalkableCell(x,y)),'counter blocks original approach')
  end end
 end
end
local prism=P.models[M.prism(P)]
for _,b in ipairs(prism.boxes)do assert(b[1]>=0 and b[3]>=0 and b[1]+b[4]<=16 and b[3]+b[6]<=16)end
assert(d.objects[1].x==12 and d.objects[2].y==15)
d.objects[1].x=11;assert(not M.matches(map));d.objects[1].x=12
d.generation=2;assert(not M.matches(map));d.generation=nil
map.isWalkableCell=function()return true end;assert(#M.find(P,map)==0,'changed collision must reject fixed counter')
print('PASS Driftglass scoped guards, original approaches, native actor footprint and edited-map rejection')
