-- Regression: an eight-unit grass canopy hid seven-unit imported bodies,
-- and received camera-depth pull while those bodies received none.
local root=assert((...) or arg[1], 'package root required')..'/'
local calls={draw=0,upload=0,release=0}
local failSpecies,failUpload=false,false
local provider={}
local modules={
 StadiumPack={KEEP=4,keep=function()end,load=function()return {}end},
 CobblemonPack=provider,
 StadiumActorBounds={world=function()return {0,0,0,16,12,16}end},
 Voxel3D={seams=function()end,glass=function()end,blend=function()end},
}
modules.StadiumMon={new=function(_,pack)
 return {provider=pack,model={},time=0,
  rig={draw=function(_,matrix,pull)calls.draw=calls.draw+1;calls.pull=pull end,
       caster=function(_,shadow,matrix)calls.shadowMatrix=matrix end},
  setSpecies=function()return not failSpecies end,
  worldHeight=function()return 4.5 end,
  update=function()end,
  matrix=function(self,x,y,z)return {x,y,z,scale=self.scale}end,
  pose=function()return true end,
  upload=function()calls.upload=calls.upload+1;return not failUpload end,
  release=function()calls.release=calls.release+1 end}
end}
local function requireModule(n)return assert(modules[n],n)end
local M=assert(loadfile(root..'lib/Gen1OverworldStadium.lua')){require=requireModule}
local p={entity={ascendantPokemonModelSource='cobblemon',ascendantPokemonModelDex=16},px=16,py=32,gh=3,facing='down'}
M.prepare{p}
assert(p.stadiumMon and p.stadiumMon.provider==provider)
assert(p.stadiumMon.scale*4.5>=12,'small Cobblemon must clear the eight-unit grass canopy')
assert(p.stadiumMatrix[2]==3,'grass readability must not float the actor above its ground')
assert(M.draw(p,function()return true end,9.25) and calls.pull==9.25,'imported actors must share grass camera-depth pull')
assert(M.cast(p,{}) and calls.shadowMatrix==p.stadiumMatrix,'shadows use the physical matrix')
local drawn=calls.draw
assert(M.draw(p,function()return false end,9.25) and calls.draw==drawn,'offscreen model keeps ownership without a draw')
p.entity.ascendantPokemonModelSource='sprite';M.prepare{p}
assert(not p.stadiumMon and not M.draw(p),'switching back restores the sprite path')
p.entity.ascendantPokemonModelSource='cobblemon';failSpecies=true;M.prepare{p}
assert(not p.stadiumMon and not M.draw(p),'missing model preserves sprite fallback')
failSpecies=false;failUpload=true;M.prepare{p}
assert(not M.draw(p,nil,9.25),'GPU upload failure preserves sprite fallback')
M.releaseAll();assert(M.status().active==0)
local f=assert(io.open(root..'lib/VoxelScene.lua'));local scene=f:read('*a');f:close()
assert(scene:find('OverworldStadium.draw(p,actorVisible,billboardPull())',1,true),'scene must pass the same correction as grass/cards')
print('PASS Cobblemon grass minimum, ground anchoring, shared depth correction, physical shadows, culling, source switches and failure fallback')
