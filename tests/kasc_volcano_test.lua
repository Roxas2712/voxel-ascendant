local root=assert(arg[1])
local on={get=function()return true end}
local V={require=function(n)return n=='VoxelItems'and{setting=on}or{stone=on}end}
local M=assert(loadfile(root..'/lib/KascVolcano.lua'))(V)
local P={models={},decorColors={oldBeam=1,looseRock4=2,stone=3}}
for _,id in ipairs({'KA_MOLTRES_VOLCANO_BASE','KA_MOLTRES_VOLCANO_ASCENT','KA_MOLTRES_VOLCANO'})do
 local d={tileset='KA_MOLTRES_VOLCANO_67',kaOwner='kasc.hoenn-moltres-volcano/v4',width=3,height=2,
  blocks={0,125,25,125,41,125},objects={{x=2,y=0}},signs={{x=4,y=3,name="KA_MOLTRES_SUMMIT_DOWN"}},storyPositions={{x=1,y=2}}}
 local map={id=id,def=d}
 function map:isWalkableCell(x,y)return x==3 end
 function map:isWaterCell(x,y)return x==5 and y==2 end
 function map:warpAtCell(x,y)return x==4 and y==1 and {}or nil end
 assert(M.profile(map));assert(M.openSky(map)==(id=='KA_MOLTRES_VOLCANO'))
 local snapshot=table.concat(d.blocks,',');local props=M.find(P,map);assert(#props>0)
 for _,p in ipairs(props)do
  local x,y=p.tx/2,p.ty/2
  if p.kind:find('basalt',1,true)then
   assert(not map:isWalkableCell(x,y)and not map:isWaterCell(x,y)and not map:warpAtCell(x,y))
   for _,list in ipairs({d.objects,d.signs,d.storyPositions})do for _,obj in ipairs(list)do assert(x~=obj.x or y~=obj.y)end end
  elseif p.kind=='kasc_volcano_exit_steps'then
   assert(x==4 and y==3);local model=P.models[p.kind]
   for _,box in ipairs(model.boxes)do assert(box[2]+box[5]<=0,'exit geometry rises across approach')end
   for z=0,15 do assert(model.support(8,z)<=0 and model.support(8,z)>=-6)end
  elseif p.kind:find('apron',1,true)then assert(not map:isWalkableCell(x,y))
  else assert(map:isWalkableCell(x,y))end
 end
 assert(snapshot==table.concat(d.blocks,','),'changed gameplay')
 d.kaOwner='unrelated';assert(not M.profile(map)and #M.find(P,map)==0)
end
for i=1,3 do
 local kind=M.boulder(P,i);local model=assert(P.models[kind]);assert(#model.boxes>0)
 for _,b in ipairs(model.boxes)do assert(b[1]>=0 and b[3]>=0 and b[1]+b[4]<=16 and b[3]+b[6]<=16,'boulder spills into adjacent cell')end
 assert(M.boulder(P,i)==kind,'unstable boulder model')
end
for _,dimensions in ipairs({{390,844},{844,390},{1920,1080}})do
 local count=0;local g={setColor=function(...)end,rectangle=function(mode,x,y,w,h)
  assert(mode=='fill'and w<=3 and h<=3 and x==x and y==y);count=count+1
 end}
 M.ash(g,dimensions[1],dimensions[2],120.5,8);assert(count==52)
end
print('PASS volcano guards, bounded ash in portrait/landscape, native passages/objects/collisions retained')

for _,dim in ipairs({{390,844},{844,390},{1920,1080}})do
 local count=0
 local g={setColor=function(r,g,b,a)assert(a>=0 and a<=1)end,rectangle=function(_,x,y,w,h)
  assert(x==x and y==y and w>0 and h>0);count=count+1
 end}
 M.skySmoke(g,dim[1],dim[2],dim[2]*.7,123,function(az,el)return az/(2*math.pi)*dim[1],dim[2]*(.7-el)end,1)
 assert(count>0 and count<=144,'unbounded volcanic sky work')
end
print('PASS procedural world-bearing smoke bounded to 144 rectangles, no bitmap or simulation storage')
