local M=assert(loadfile('lib/Gen1FossilPool.lua'))({})
assert(M.species({EVENT_GOT_DOME_FOSSIL=true})=='OMANYTE')
assert(M.species({EVENT_GOT_HELIX_FOSSIL=true})=='KABUTO')
assert(M.species({})==nil)
local function pose(map,name,sprite)
 return {mapId=map,entity={def={name=name,sprite=sprite}}}
end
assert(M.matches(pose('FUCHSIA_CITY','FUCHSIACITY_FOSSIL','SPRITE_FOSSIL')))
assert(not M.matches(pose('MT_MOON_B2F','MTMOONB2F_HELIX_FOSSIL','SPRITE_FOSSIL')))
assert(not M.matches(pose('FUCHSIA_CITY','FUCHSIACITY_LAPRAS','SPRITE_SEEL')))
local maps={
 {isWaterCell=function(_,x,y)return x>=4 and x<=7 and y>=4 and y<=5 end},
 {isWaterCell=function(_,x,y)return x>=4 and x<=7 and y>=4 and y<=7 and not(x>5 and y>5)end},
 {isWaterCell=function(_,x,y)return x==6 and y==5 end},
}
for _,map in ipairs(maps)do
 for step=0,1000 do
  local px,py,f=M.position(map,6,5,step*.1)
  assert(px and py and f)
  -- The whole 16px body remains inside water, including concave shores.
  for _,dx in ipairs({.01,15.99})do for _,dy in ipairs({.01,15.99})do
   assert(map:isWaterCell(math.floor((px+dx)/16),math.floor((py+dy)/16)),'crossed pool bank')
  end end
 end
 assert(M.position(map,1,1,0)==nil)
end
local x,y=M.position(maps[1],6,5,0)
local a,b=M.position(maps[1],6,5,2)
assert(math.abs(x-a)+math.abs(y-b)>1)
print('PASS fossil selection, exhibit identity, swimming movement and 3003 shoreline samples')
local image={getDimensions=function()return 56,56 end}
package.loaded['src.pokemon.Sprites']={path=function()return 'test.png',true end}
package.loaded['src.render.Assets']={image=function()return image end}
love={timer={getTime=function()return 2 end}}
local original={def={name='FUCHSIACITY_FOSSIL',sprite='SPRITE_FOSSIL'},px=96,py=80}
local sprite={def={id='SPRITE_FOSSIL'}}
local p={mapId='FUCHSIA_CITY',entity=original,sprite=sprite,px=96,py=80}
local state={map={id='FUCHSIA_CITY',isWaterCell=maps[1].isWaterCell}}
local game={save={flags={EVENT_GOT_DOME_FOSSIL=true}},data={}}
M.prepare(state,{p},game)
assert(p.entity~=original and p.sprite~=sprite and p.fossilPoolSpecies=='OMANYTE')
assert(original.px==96 and original.py==80 and original.def.sprite=='SPRITE_FOSSIL')
assert(sprite.def.id=='SPRITE_FOSSIL' and not original.ascendantPokemonModelDex)
local before=p.entity
local p2={mapId='FUCHSIA_CITY',entity=original,sprite=sprite,px=96,py=80}
M.prepare(state,{p2},game);assert(p2.entity==before,'proxy rebuilt per frame')
game.save.flags.EVENT_GOT_DOME_FOSSIL=false;game.save.flags.EVENT_GOT_HELIX_FOSSIL=true
local p3={mapId='FUCHSIA_CITY',entity=original,sprite=sprite,px=96,py=80}
M.prepare(state,{p3},game);assert(p3.fossilPoolSpecies=='KABUTO' and p3.entity~=before)
local W=assert(loadfile('lib/WaterActors.lua'))({require=function(name)
 if name=='ModSetting' then return {new=function()return {get=function()return false end}end} end
 if name=='TileShape' then return {forMap=function()return {classes={water={h=-2}}}end}end
 if name=='ChunkMesher' then return {elevation=function()return {at=function()return 0 end}end}end
 error(name)
end})
p3.gh=0
W.prepare(state,{p3});assert(p3.swimming=='pokemon' and p3.waterline==-2)
local ordinary={entity={px=96,py=80,ascendantPokemonModelDex=140},sprite={def={}},mapId='FUCHSIA_CITY',gh=0}
W.prepare(state,{ordinary});assert(not ordinary.swimming,'ordinary swimming setting ignored')
print('PASS native objects unchanged, stable visual proxies, live fossil choice and waterline with swimming disabled')
