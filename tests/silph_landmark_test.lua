local root=assert(arg[1])
local engine=assert(os.getenv('GEN1RECOMP_DIR'))
local maps=assert(loadfile(engine..'/yellow/data/generated/maps.lua'))()
local modules={}
local V={require=function(name)return assert(modules[name],name)end}
modules.ModSetting={new=function()return{get=function()return true end}end}
modules.Voxel3D={};modules.HorizonBuildings={}
modules.Gen1VoxelSigns=assert(loadfile(root..'/lib/Gen1VoxelSigns.lua'))(V)
modules.WorldPlacement=assert(loadfile(root..'/lib/WorldPlacement.lua'))()
local T=assert(loadfile(root..'/lib/Gen1SilphCo.lua'))(V);modules.Gen1SilphCo=T
assert(T.matches(maps.SAFFRON_CITY))
assert(not T.matches{width=20,height=18,tileset='OVERWORLD',generation=2,warps=maps.SAFFRON_CITY.warps})
assert(not T.matches{width=21,height=18,tileset='OVERWORLD',warps=maps.SAFFRON_CITY.warps})
local P={models={},decorColors={navy=38,silver=39,stone=18,silphGlass=40}}
T.create(P,'silph',{{side='south',at=40,width=14}},function()return 0 end)
local m=P.models.silph
assert(m.storeys==11 and m.landmarkHeight==304 and m.landmarkHeight>272)
local count,top,rows=0,0,{}
for _,model in ipairs({m,P.models[m.glassKind]})do
 for _,b in ipairs(model.boxes)do
  count=count+1;top=math.max(top,b[2]+b[5])
  assert(b[1]>=0 and b[3]>=0 and b[1]+b[4]<=128 and b[3]+b[6]<=192)
  assert(b[4]>0 and b[5]>0 and b[6]>0 and type(b[7])=='number')
  if b[7]==40 and b[5]==16 then rows[b[2]]=true end
  if model==m and b[3]<186 and b[3]+b[6]>184 then
   assert(not(b[1]<48 and b[1]+b[4]>32 and b[2]<24 and b[2]+b[5]>4),'wall blocks native entrance')
  end
 end
end
local floors=0;for _ in pairs(rows)do floors=floors+1 end
assert(floors==11 and top==304 and count<1000,'storeys, silhouette or geometry budget')
local H=assert(loadfile(root..'/lib/OutdoorHorizon.lua'))(V)
local sp=modules.WorldPlacement.position('SAFFRON_CITY',maps)
for _,id in ipairs({'ROUTE_7','ROUTE_8','CELADON_CITY','LAVENDER_TOWN'})do
 local rp=assert(modules.WorldPlacement.position(id,maps))
 local list={}
 H.silphLandmark({{map={id=id},ox=24,oy=-16}},maps,function(...)list[#list+1]={...}end)
 assert(#list==count+1,'missing/duplicate distant Silph '..id)
 local i=1
 T.geometry(function(x,y,z,w,h,d,c,lit)
  i=i+1;local b=list[i]
  assert(b[1]==x+sp.x-rp.x+T.tx*8+24 and b[2]==y and b[3]==z+sp.y-rp.y+T.ty*8-16)
  assert(b[4]==w and b[5]==h and b[6]==d and b[8]==lit,'near/far shape differs')
 end)
end
local called=false
H.silphLandmark({{map={id='ROUTE_7'}},{map={id='SAFFRON_CITY'}}},maps,function()called=true end)
assert(not called,'distant duplicate when Saffron is resident')
print('PASS_SILPH_11_FLOORS_NATIVE_PLOT_DOOR_HEIGHT_AND_IDENTICAL_DISTANT_LANDMARK',count)

local map={id='SAFFRON_CITY',def=maps.SAFFRON_CITY}
assert(T.occludes(map,1,{320,180,460},{320,8,128}),'north-side orbit must open')
assert(not T.occludes(map,1,{320,180,650},{320,8,400}),'south-side view unnecessarily cut')
assert(not T.occludes(map,1,{200,180,460},{200,8,128}),'nonintersecting view cut')
assert(not T.occludes(map,1,{320,2000,460},{320,800,128}),'clear view above building cut')
for _,level in ipairs({6,7})do assert(not T.occludes(map,level,{320,180,460},{320,8,128}))end
assert(not T.occludes({id='ROUTE_7',def=maps.ROUTE_7},1,{320,180,460},{320,8,128}))
local low=P.models[assert(m.cutawayKind)]
assert(low~=m and low.landmarkHeight==34)
for _,model in ipairs({low,P.models[low.glassKind]})do
 for _,b in ipairs(model.boxes)do assert(b[2]+b[5]<=34)end
end
assert(m.landmarkHeight==304,'view alternative mutated full/shadow model')
print('PASS_SILPH_OCCLUSION_ONLY_ORBIT_CUTAWAY_FULL_SHADOW_AND_EYE_LEVEL_MODELS_RETAINED')
