local Size=assert(loadfile('lib/CobblemonSize.lua'))()
local data={pokemon={RATTATA={dexEntry={heightFt=1,heightIn=0}},VENUSAUR={dexEntry={heightFt=6,heightIn=7}},GOROCHU={dexEntry={heightM=1.4}}}}
local calls=0
local function fitted(species,bindH,bindR,poseH,poseW)
 local model={height=bindH,radius=bindR,rootScale=1,actions={battle=1},anims={{seconds=2}}}
 local rig={pose=function()calls=calls+1 end,posedBounds=function()return 0,0,0,poseW,poseH,poseW*.8 end}
 Size.prepare(model,rig)
 local count=calls;Size.prepare(model,rig);assert(calls==count,'repeated calibration')
 local metres=Size.meters(nil,{species=species},data)
 local matrixScale=Size.worldHeight(nil,model,metres)/model.height
 return poseH*matrixScale,model,metres
end
local rat=fitted('RATTATA',12,16,20,19)
local venusaur=fitted('VENUSAUR',37,40,39,61)
local gorochu=fitted('GOROCHU',24,10,24,20)
assert(venusaur>rat*2 and venusaur>gorochu,'large species compressed into sprite-size bucket')
assert(gorochu/rat<2.5,'compact authored model dominates equally calibrated models')
local a=fitted('VENUSAUR',37,40,39,61)
local b=fitted('VENUSAUR',370,400,390,610)
assert(math.abs(a-b)<1e-8,'authored model units change displayed height')
assert(Size.meters(nil,{species='ABRA'},{gen2Pokedex={entries={ABRA={height=211}}}})==35*.0254)
assert(Size.meters(nil,{species='UNKNOWN'},data)==nil)
assert(Size.targetHeight(0/0)==14 and Size.targetHeight(-1)==14)
assert(Size.targetHeight(.01)>=6 and Size.targetHeight(100)<=32)
print('PASS: species ordering, posed calibration, unit independence, caching and metadata')
