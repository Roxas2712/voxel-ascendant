local root=assert(arg[1])
local Size=assert(loadfile(root..'/lib/BattleSpriteSize.lua'))()
local Metrics=assert(loadfile(root..'/gen2/lib/Gen2BattleSpriteMetrics.lua'))({require=function(n)assert(n=='BattleSpriteSize');return Size end})
local Gen1=assert(loadfile(root..'/lib/BattleBillboard.lua'))({require=function()return{}end})
local units=Gen1.FULL_W/Gen1.FULL_PIC
local function close(a,b)assert(math.abs(a-b)<1e-8,tostring(a)..' ~= '..tostring(b))end
local mon={}
local function tex()return{vascRenderMon=mon,vascRenderModelKey='TOTODILE'}end
local a=Metrics.apply(tex(),{dexEntry={heightM=1}},50,'native')
close(a.pixelWorld,units)
-- The same species/artwork must occupy the same world units as Gen1 before
-- each scene's authored stage scaling. Do not reapply the old 2x Gen2 boost.
close(a.pixelWorld*50,50*units*Size.speciesScale(1/.0254))
-- A send-out/faint pose must not recalibrate a source already in use.
local b=Metrics.apply(tex(),{dexEntry={heightM=1}},10,'native')
close(a.pixelWorld,b.pixelWorld)
-- A genuinely different HD source uses its own reference; rendered body
-- extent stays the same even when its texture resolution is four times larger.
local hd=Metrics.apply(tex(),{dexEntry={heightM=1}},200,'hd')
close(hd.pixelWorld*200,a.pixelWorld*50)
local native=Metrics.apply(tex(),nil,50,'dex', {height=211})
close(native.heightIn,35)
close(Metrics.apply(tex(),nil,nil,nil).pixelWorld,units)
local trainer={trainer=true,pixelWorld=.5};assert(Metrics.apply(trainer,nil,50,'x')==trainer and trainer.pixelWorld==.5)
local small=Metrics.apply(tex(),{dexEntry={heightM=.1}},50,'small')
local huge=Metrics.apply(tex(),{dexEntry={heightM=100}},50,'huge')
assert(small.pixelWorld>=units*.72 and huge.pixelWorld<=units*1.56 and small.pixelWorld<huge.pixelWorld)
for _,inches in ipairs({12,24,39,83,204,346})do
 local base=Metrics.apply({vascRenderMon={},vascRenderModelKey='species'},
   {dexEntry={heightIn=inches}},50,'native')
 close(base.pixelWorld*50,units*50*Size.speciesScale(inches))
 for _,stageScale in ipairs({.78,.78*1.8,1})do
  local extent=base.pixelWorld*50*stageScale
  assert(extent<=units*50*1.56*stageScale,'body exceeds shared species bound')
 end
end
print('PASS Gen2 sprite extent, pose stability, native height and trainer preservation')
