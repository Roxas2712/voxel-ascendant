local root=assert(arg[1], 'package root required')..'/'
local calls={release=0,draw=0,cast=0,build=0}
local pack={KEEP=4,load=function(d)return d~=151 and {} or nil end,keep=function()end}
local failBuild,failDraw=false,false
local Mon={new=function()
 return {time=0,rig={draw=function()if failDraw then error('gpu')end;calls.draw=calls.draw+1 end,
 caster=function()calls.cast=calls.cast+1 end},
 setSpecies=function(_,d)return d~=151 end,worldHeight=function()return 10 end,
 update=function(self,dt)self.time=self.time+dt end,matrix=function(_,x,y,z,fx,fz)return {x,y,z,fx,fz}end,
 build=function()calls.build=calls.build+1;return not failBuild end,
 release=function()calls.release=calls.release+1 end}
end}
local renderer={seams=function()end,glass=function()end,blend=function()end}
local modules={StadiumPack=pack,StadiumMon=Mon,Voxel3D=renderer}
local M=assert(loadfile(root..'lib/Gen1OverworldStadium.lua')){require=function(n)return assert(modules[n],n)end}
assert(M.available(25) and not M.available(0) and not M.available(252) and not M.available(1.5) and not M.available(151))
local function pose(d,source)
 return {entity={ascendantPokemonModelSource=source or 'stadium2',ascendantPokemonModelDex=d},px=16,py=32,gh=4,lift=2,facing='up'}
end
local p=pose(25);local human=pose(25);human.isPlayer=true
M.prepare{p,human};assert(p.stadiumMon and not human.stadiumMon)
assert(p.stadiumMatrix[1]==24 and p.stadiumMatrix[2]==6 and p.stadiumMatrix[3]==40 and p.stadiumMatrix[5]==-1)
assert(M.draw(p) and M.cast(p,{}));local count=calls.build
assert(M.draw(p) and calls.build==count,'reflections must reuse prepared mesh')
p.entity.ascendantPokemonModelSource='sprite';M.prepare{p};assert(not p.stadiumMon and not M.draw(p) and calls.release==1)
p.entity.ascendantPokemonModelSource='stadium2';M.prepare{p};assert(p.stadiumMon)
failBuild=true;M.prepare{p};assert(not p.stadiumMon and not M.draw(p))
failBuild=false;M.prepare{p};failDraw=true;assert(not M.draw(p));failDraw=false
local optout=pose(25);optout.entity.pokemonModel=false
local absent=pose(151);M.prepare{optout,absent};assert(not optout.stadiumMon and not absent.stadiumMon)
local many={};for i=1,10 do many[i]=pose(i)end
M.prepare(many);assert(pack.KEEP>=14 and M.status().active==10)
M.prepare{};assert(M.status().active==0);M.releaseAll()
print('PASS Gen1 model import readiness, selection, positioning, player exclusion, reflections, shadows, live switches, failures, lifecycle and cache capacity')
local Policy=assert(loadfile(root..'integrated/ascendant_pokemon_overworld/src/presentation_policy.lua'))()
local pol=Policy.new{mod={_vascIntegrated=true,_vascStadiumAvailable=M.available,options={get=function()return 'auto'end}},compat={}}
local e={};assert(pol:decorate(e,25,{spriteSource='stadium2'}).id=='stadium2' and e.ascendantPokemonModelDex==25)
assert(pol:decorate(e,25,{spriteSource='pokemmo'}).id=='sprite' and e.ascendantPokemonModelDex==nil)
assert(pol:decorate(e,151,{spriteSource='stadium2'}).id=='sprite' and e.ascendantPokemonModelDex==nil)
print('PASS actual APO policy dex ownership, explicit MMO override and missing-pack fallback')
