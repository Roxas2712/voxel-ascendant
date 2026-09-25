local P={models={},decorColors={}}
local colors=0;setmetatable(P.decorColors,{__index=function(t,k)colors=colors+1;rawset(t,k,colors+50);return colors+50 end})
local modules={ModSetting={new=function()return {get=function()return true end}end},VoxelWinterDetails={roof=function()return 'winter'end}}
local V={require=function(n)return assert(modules[n],n)end,data=function()return {buildings={OVERWORLD={}}}end}
local Village=assert(loadfile('lib/Gen1PalletVillage.lua'))(V)
Village.register(P,{patterns={}})
local checked=0
for _,kind in ipairs{'pallet_red_house','pallet_blue_house','pallet_oak_lab'}do
 local glass=P.models[kind..'_glass'];local solid=P.models[kind]
 for _,g in ipairs(glass.boxes)do for _,b in ipairs(solid.boxes)do
  local overlap=true
  for axis=1,3 do
   if math.min(g[axis]+g[axis+3],b[axis]+b[axis+3])<=math.max(g[axis],b[axis])then overlap=false end
  end
  assert(not overlap,kind..': glass occupies an opaque facade/mullion voxel')
  checked=checked+1
 end end
 assert(#glass.boxes>0)
end
print('PASS: '..checked..' glass/opaque volume pairs do not intersect')
