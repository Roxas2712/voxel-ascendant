local root=assert(arg[1]);local supported=true
local mods={ModSetting={new=function()return {get=function()return true end}end},
 VoxelItems={setting={get=function()return true end}},LocalLights={supported=true},
 TowerAtmosphere={candleLight=function()return .7 end},Sky={clock=0}}
local V={require=function(n)return assert(mods[n],n)end}
mods.Gen1CavePanoramas=assert(loadfile(root..'/lib/Gen1CavePanoramas.lua'))()
mods.KascLegendAtmosphere=assert(loadfile(root..'/lib/KascLegendAtmosphere.lua'))()
local C=assert(loadfile(root..'/lib/CaveTorches.lua'))(V)
local P={models={}};C.register(P)
for dir=1,4 do
 local crystal=assert(P.models['cave_crystal_'..dir]);local light=crystal.lightSource
 assert(light.kind=='crystal' and light.color[3]>light.color[1] and light.color[2]>light.color[1])
 assert(crystal.glowColor[3]>crystal.glowColor[1] and P.models[crystal.glassKind])
 assert(light.radius<=48 and crystal.windowLight()>0)
 local radius=light.radius;mods.Sky.clock=2;assert(crystal.windowLight()~=.7 and light.radius==radius)
end
-- Long unoccupied stone wall, with floor along both sides and one warp.
local map={id='MT_MOON_1F',def={generation=1,tileset='CAVERN',width=30,height=12,
 warps={{x=5,y=5}},objects={}}}
function map:isWalkableCell(x,y)return y~=6 end
function map:tileAt(x,y)return math.floor(y/2)==6 and 2 or 5 end
local function counts(list)
 local crystals,torches=0,0
 for _,p in ipairs(list)do
  assert(p.keepTerrain and p.voxelOnly and not map:isWalkableCell(p.tx/2,p.ty/2))
  assert(map:isWalkableCell(p.approachX,p.approachY))
  if p.crystal then crystals=crystals+1 else torches=torches+1 end
 end
 return crystals,torches
end
local list=C.find(map);local count,torches=counts(list);assert(count>0 and count<=2 and torches>0 and torches<=4)
for i,a in ipairs(list)do if a.crystal then
 for j,b in ipairs(list)do if i~=j then assert((a.tx-b.tx)^2+(a.ty-b.ty)^2>=100,'crystal crowds another fixture')end end
end end
mods.LocalLights.supported=false
local _,mobileTorches=counts(C.find(map));local mobileCrystals=counts(C.find(map))
assert(mobileCrystals==0 and mobileTorches==torches,'mobile torches changed')
mods.LocalLights.supported=true
assert(#C.find(map,function()return true end)==0,'crystal ignores occupied art')
map.def.generation=2;assert(#C.find(map)==0,'Gen2 received crystals')
map.def.generation=1;map.id='KA_HEVO_GROUDON_CHAMBER';map.def.warps={}
map.def.signs={{x=5,y=5}};map.def.objects={{x=28,y=5}}
local extension=C.find(map);local nc,nt=counts(extension)
assert(nt>0 and nt<=16 and nc<=2,'scripted cave without native warps has no bounded lights')
for _,p in ipairs(extension)do
 for _,point in ipairs({map.def.signs[1],map.def.objects[1]})do
  assert(math.abs(p.approachX-point.x)+math.abs(p.approachY-point.y)>=3,'fixture crowds scripted landmark')
 end
end
map.id='KA_HEVO_KYOGRE_CHAMBER'
local blue=C.find(map);local crystals,torches=counts(blue);assert(crystals>0 and torches==0,'underwater route still uses fire torches')
assert(#blue<=18,'themed fixtures exceeded existing budget')
map.def.tileset='PRIVATE_CAVERN';assert(not C.eligible(map),'native atlas assumptions applied to custom art')
map.def.tileset='CAVERN';map.id='UNKNOWN_CAVE';assert(not C.eligible(map))
print('PASS_CAVE_CRYSTALS: cool emission, bounded pulse/range, rare separated wall placements, intact torches, collision-safe and mobile/Gen2 exclusions')
