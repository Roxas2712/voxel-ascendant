local root=assert(arg[1])
local invalidations=0
local V={}
V.mod={options={get=function()return nil end}}
local Setting=assert(loadfile(root..'/lib/ModSetting.lua'))(V)
V.require=function(name)assert(name=='ModSetting');return Setting end
local T=assert(loadfile(root..'/lib/Gen1LavenderTower.lua'))(V)
assert(T.setting:get()=='stone','new installations must use stone')
T.bind(function()invalidations=invalidations+1 end)
local colors={}
for i,name in ipairs({'oldTimber','oldBeam','oldBoard','oldShingle','paperWindow','stone','oak','walnut',
 'hauntedStone','hauntedMortar','hauntedWeathered','hauntedSlate','hauntedGlass'})do colors[name]=i end
local P={models={},decorColors=colors}
local bounds={}
for _,style in ipairs({'stone','wood'})do
 T.setting:setValue(style)
 local top=0
 for _,part in ipairs({'pokemon_tower','pokemon_tower_top'})do
  local name=style..part
  T.create(P,name,part,function()return 0 end)
  local m=P.models[name]
  assert(m.towerStyle==style and m.landmarkHeight==272 and m.frameW==96)
  local depth=part=='pokemon_tower_top'and 96 or 64
  local total=0
  for _,model in ipairs({m,P.models[m.glassKind]})do
   for _,b in ipairs(model.boxes)do
    assert(b[1]>=0 and b[1]+b[4]<=96 and b[3]>=0 and b[3]+b[6]<=depth,'tower crossed native footprint/seam')
    assert(b[4]>0 and b[5]>0 and b[6]>0 and type(b[7])=='number')
    top=math.max(top,b[2]+b[5]);total=total+1
   end
  end
  assert(total>100,'tower detail missing')
 end
 bounds[style]=top
end
assert(bounds.stone==272 and bounds.wood==272,'variant changes landmark height')
assert(invalidations==1,'unchanged value rebuilt scenery')
T.setting:sync('stone');assert(invalidations==2,'mod-manager switch did not invalidate')
T.setting:sync('stone');assert(invalidations==2)
print('PASS stone default, equal tower height/footprint, seam clipping and live menu/manager invalidation')
