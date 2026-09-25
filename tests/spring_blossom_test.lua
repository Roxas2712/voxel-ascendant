local selected='auto'
local W=assert(loadfile('lib/Weather.lua'))({require=function(n)
 if n=='ModSetting'then return {new=function()return {get=function()return selected end}end} end
 return {}
end})
assert(W.blossomAt(0)==0 and W.blossomAt(120)==1 and W.blossomAt(480)==1)
assert(W.blossomAt(800)>0 and W.blossomAt(900)==0)
for t=960,3839 do assert(W.blossomAt(t)==0,'bloom outside spring') end
for t=0,960 do local a=W.blossomAt(t);assert(a>=0 and a<=1);assert(math.abs(a-W.blossomAt(t+.01))<.001)end
assert(W.blossomAt(3840+240)==W.blossomAt(240))
assert(W.blossomAt(15360+240)==W.blossomAt(240))
print('PASS continuous spring bloom, green before summer, year/save-clock wrap')
local captured={};local G={eye={0,0,0},newMesh=function(v,i)
 captured.alloc=(captured.alloc or 0)+1;assert(#v==64 and #i==96)
 return {setVertices=function(_,rows)captured.rows=rows end,release=function()end}
end,seasonFoliage=function()end,weatherGround=function()end,weatherGrass=function()end,
 draw=function()captured.draws=(captured.draws or 0)+1 end}
local weather={clock=240,setting={get=function()return selected end},isOutdoor=function(map)return map.outdoor end,isLavender=function(map)return map.lavender end,blossomAt=W.blossomAt}
package.preload['src.render.Assets']=function()return {register=function()end}end
local depth,writes='lequal',true
love={image={newImageData=function()return {setPixel=function()end,release=function()end}end},graphics={
 newImage=function()return {setFilter=function()end,release=function()end}end,
 getDepthMode=function()return depth,writes end,setDepthMode=function(d,w)depth,writes=d,w end,
 getColor=function()return .5,.6,.7,1 end,setColor=function()end}}
local B=assert(loadfile('lib/SpringBlossom.lua'))({require=function(n)return n=='Weather' and weather or G end})
local function mat(x,z)return {1,0,0,x,0,1,0,0,0,0,1,z,0,0,0,1}end
local point={0,25,0}
B.begin({outdoor=true});B.add(mat(0,0),point);B.add(mat(0,0),point);assert(B.count==1,'duplicate petals')
B.add(mat(400,0),point);assert(B.count==1,'distant petals')
for x=10,200,10 do B.add(mat(x,0),point)end
assert(B.count==8,'unbounded sources');assert(B.draw());assert(captured.alloc==1 and depth=='lequal'and writes==true)
for i=1,100 do weather.clock=240+i*.01;assert(B.draw())end
assert(captured.alloc==1 and #captured.rows==64,'per-frame GPU allocation')
local x,y,z,fade=B.petal(10,25,20,240,1);local xx,yy,zz=B.petal(10,25,20,240,1)
assert(x==xx and y==yy and z==zz and fade>=0 and fade<=1)
B.begin({outdoor=false});B.add(mat(0,0),point);assert(B.count==0 and not B.draw())
B.begin({outdoor=true,lavender=true});assert(B.amount==0)
selected='clear';B.begin({outdoor=true});assert(B.amount==0)
selected='auto';weather.clock=1200;B.begin({outdoor=true});assert(B.amount==0)
B.clear();weather.clock=240;B.begin({outdoor=true});B.add(mat(0,0),point);assert(B.draw(),'asset reload failed')
print('PASS bounded nearby sources, deterministic petals, one reusable mesh, depth restoration and off/indoor/season gates')

local total=0;local rows={}
for z=0,49 do for x=0,49 do
 local yes=B.selected('ROUTE_1',x*2,z*2)
 assert(yes==B.selected('ROUTE_1',x*2,z*2),'selection rerolled')
 if yes then total=total+1 end
end end
assert(total>500 and total<750,'unexpected cherry density')
local last,gaps,types=nil,{},0
for x=0,100 do if B.selected('ROUTE_1',x*2,20)then
 if last then local gap=x-last;if not gaps[gap]then gaps[gap]=true;types=types+1 end end
 last=x
end end
assert(types>=5,'regular tree spacing')
local differences=0
for x=0,99 do if B.selected('ROUTE_1',x*2,20)~=B.selected('ROUTE_2',x*2,20)then differences=differences+1 end end
assert(differences>10,'map identity ignored')
print('PASS stable irregular tree selection: '..total..'/2500 crowns, '..types..' different gap lengths')

-- Different colours of the same template must remain separate instance
-- groups and retain separate GPU streams across frames.
local allocations,uploads=0,0
local function mesh()
 return {attachAttribute=function()end,release=function()end}
end
local batchG={canInstance=function()return true end,newMesh=function()allocations=allocations+1;return mesh()end}
love.graphics.newMesh=function()return {setVertices=function()uploads=uploads+1 end,release=function()end}end
local batch=assert(loadfile('lib/VoxelPropBatch.lua'))({require=function(n)assert(n=='Voxel3D');return batchG end})
local original={getVertexCount=function()return 4 end,getVertex=function()return 0,0,0,0,0,1 end,getVertexMap=function()return {1,2,3,1,3,4}end}
local green={seasonalFoliage=true};local pink={seasonalFoliage=true,blossomSource={8,25,8}}
local function each(_,draw)
 for i=1,6 do draw(original,'tree-texture',mat(i*16,0),1,i%2==0 and pink or green)end
end
for frame=1,2 do
 local calls=0
 batch.draw({map={}},each,function(bundle,_,_,_,extra)
  calls=calls+1;assert(bundle.__voxelMeshBundle and bundle.instances[1].count==3,'tree became individual draw')
  assert(extra==green or extra==pink)
 end)
 assert(calls==2,'colours merged or per-tree draw calls')
end
assert(allocations==2 and uploads==2,'stable trees reallocated/reuploaded every frame')
print('PASS mixed cherry/green trees share templates but retain two stable instance streams')
