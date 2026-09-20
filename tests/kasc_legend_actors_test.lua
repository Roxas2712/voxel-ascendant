local root=assert(arg[1]);local loads=0;local img={getDimensions=function()return 64,64 end,setFilter=function()end}
package.loaded['src.render.Assets']={image=function()loads=loads+1;return img end,register=function()end}
local M=assert(loadfile(root..'/lib/KascLegendActors.lua'))()
for _,species in ipairs({'GROUDON','KYOGRE','RAYQUAZA'})do
 local s={def={id='SPRITE_KA_HEVO_LEGEND_'..species,voxelChamberImage=species..'.png'},image={}}
 local e={sprite=s,def={name='KA_HEVO_'..species},cellX=8,cellY=4,px=128,py=64}
 local state={map={id='KA_HEVO_'..species..'_CHAMBER',def={}}};local p={sprite=s,entity=e}
 M.prepare(state,{p});assert(p.sprite~=s and p.sprite.def.voxelWorldHeight>=48)
 assert(p.sprite:resolveImage()==img and e.sprite==s and e.cellX==8 and e.px==128,'native entity changed')
 local before=loads;M.prepare(state,{{sprite=s,entity=e}});assert(loads==before,'texture loaded per frame')
 s.def.ascendantAtlasImage='selected-hd.png';local hd={sprite=s,entity=e};M.prepare(state,{hd});assert(hd.sprite==s,'HD source overwritten');s.def.ascendantAtlasImage=nil
 local other={sprite=s,entity=e};state.map.id='PALLET_TOWN';M.prepare(state,{other});assert(other.sprite==s)
 state.map.id='KA_HEVO_'..species..'_CHAMBER';state.map.def.generation=2;M.prepare(state,{other});assert(other.sprite==s)
end
local G={pushQuad=function()end,newMesh=function(v)return{vertices=v}end}
local B=assert(loadfile(root..'/lib/SpriteBillboards.lua'))({require=function(n)assert(n=='Voxel3D');return G end})
local base={image='test.png',frames=1,frameWidth=64,frameHeight=64}
local mesh=B.mesh(base,0,img);assert(mesh.vertices[1][1]==0 and mesh.vertices[3][2]==16)
base.voxelChamberCard=true;base.voxelWorldWidth=56;base.voxelWorldHeight=48
local large=B.mesh(base,0,img);assert(large~=mesh and large.vertices[1][1]==-20 and large.vertices[3][2]==48)
assert(B.shadowQuad(base,0,img)==large,'shadow and visible geometry diverge')
base.voxelWorldWidth=math.huge;local invalid=B.mesh(base,0,img);assert(invalid.vertices[3][2]==16)
print('PASS chamber-only large detailed cards, native entity unchanged, bounded cached geometry and matching shadows')
