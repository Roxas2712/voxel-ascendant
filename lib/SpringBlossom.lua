-- Render-only petals near visible cherry crowns. Eight sources, two petals
-- each, one reused mesh and texture. No particles, RNG, timers or save data.
local V=...
local B={MAX_SOURCES=8,PETALS_PER_TREE=2,count=0,amount=0}
local sources,vertices,indices={},{},{}
local mesh,texture,failed,registered
local G,W
-- Integer-only positional hash: no regular every-nth-tree spacing and no
-- global RNG/save state. About one quarter of broadleaf crowns are cherries.
function B.selected(mapId,x,z)
 local h=17
 for i=1,#mapId do h=(h*131+mapId:byte(i))%65521 end
 h=(h+math.floor(x)*109+math.floor(z)*181)%65521
 h=(h*h*17+h*31+7)%65521
 h=(h*h*23+h*13+11)%65521
 return h<16380
end
function B.clear()
 if mesh then mesh:release() end
 if texture then texture:release() end
 mesh,texture,failed=nil,nil,nil
 sources,vertices,indices={},{},{}
 B.count,B.amount=0,0
end
function B.begin(map)
 G=G or V.require('Voxel3D');W=W or V.require('Weather')
 B.count=0
 B.amount=W.setting:get()=='auto' and W.isOutdoor(map) and not W.isLavender(map)
   and W.blossomAt(W.clock) or 0
end
function B.add(mat,point)
 if B.amount<=.01 or not mat then return end
 local x=mat[1]*point[1]+mat[2]*point[2]+mat[3]*point[3]+mat[4]
 local y=mat[5]*point[1]+mat[6]*point[2]+mat[7]*point[3]+mat[8]
 local z=mat[9]*point[1]+mat[10]*point[2]+mat[11]*point[3]+mat[12]
 local eye=G.eye or {0,0,0}
 local distance=(x-eye[1])^2+(y-eye[2])^2+(z-eye[3])^2
 -- Only nearby, camera-visible crowns supply petals. Far horizon trees
 -- remain static. Deduplication also handles repeated furniture callbacks.
 if distance>320^2 then return end
 for i=1,B.count do local s=sources[i];if s[1]==x and s[3]==z then return end end
 local slot=B.count+1
 if slot>B.MAX_SOURCES then
  slot=1;for i=2,B.count do if sources[i][4]>sources[slot][4] then slot=i end end
  if distance>=sources[slot][4] then return end
 else B.count=slot end
 local s=sources[slot] or {};sources[slot]=s
 s[1],s[2],s[3],s[4]=x,y,z,distance
end
-- Source coordinates seed the fall, so culling/reordering never restarts it.
function B.petal(x,y,z,clock,index)
 local seed=x*.071+z*.113+index*.47
 local t=(clock/7+seed)%1
 local angle=clock*2.1+seed
 return x+math.sin(angle)*2.5+t*5-2.5,
   y-2-t*14,z+math.cos(angle*.7)*2+t*3,
   math.sin(math.pi*t),angle
end
local function ensure()
 if mesh and texture then return true end
 if failed then return false end
 if not registered then require('src.render.Assets').register(B.clear);registered=true end
 local ok=pcall(function()
  for i=1,B.MAX_SOURCES*B.PETALS_PER_TREE do
   local n=(i-1)*4
   for j=1,4 do vertices[n+j]={0,0,0,.5,.5,1} end
   for _,j in ipairs{1,2,3,1,3,4} do indices[#indices+1]=n+j end
  end
  mesh=assert(G.newMesh(vertices,indices),'petal mesh unavailable')
  local data=love.image.newImageData(1,1)
  data:setPixel(0,0,1,.74,.83,1)
  local made,result=pcall(love.graphics.newImage,data)
  data:release();assert(made,result);texture=result
  texture:setFilter('nearest','nearest')
 end)
 if not ok then B.clear();failed=true end
 return ok
end
function B.draw()
 if B.amount<=.01 or B.count==0 or not ensure() then return false end
 local n=0
 for i=1,B.count do local s=sources[i]
  for p=1,B.PETALS_PER_TREE do
   local x,y,z,fade,angle=B.petal(s[1],s[2],s[3],W.clock,p)
   local size=.7*fade*B.amount
   local dx,dz=math.cos(angle)*size,math.sin(angle)*size
   for corner=1,4 do
    n=n+1;local v=vertices[n]
    if corner==1 then v[1],v[2],v[3]=x-dx,y,z-dz
    elseif corner==2 then v[1],v[2],v[3]=x,y+size*.65,z
    elseif corner==3 then v[1],v[2],v[3]=x+dx,y,z+dz
    else v[1],v[2],v[3]=x,y-size*.65,z end
   end
  end
 end
 -- Unused quads collapse; never resize or reallocate the GPU mesh in play.
 for i=n+1,#vertices do local v=vertices[i];v[1],v[2],v[3]=0,0,0 end
 local g=love.graphics;local depth,writes=g.getDepthMode();local r,green,b,a=g.getColor()
 local ok=pcall(function()
  mesh:setVertices(vertices)
  G.seasonFoliage(false);G.weatherGround(false);G.weatherGrass(false)
  g.setColor(1,1,1,1);g.setDepthMode('lequal',false)
  G.draw(mesh,texture,nil,0)
 end)
 g.setDepthMode(depth,writes);g.setColor(r,green,b,a)
 if not ok then B.clear();failed=true end
 return ok
end
return B
