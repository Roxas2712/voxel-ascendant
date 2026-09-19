local root=assert(arg[1])..'/integrated/ascendant_pokemon_overworld'
local Binder=assert(loadfile(root..'/src/walking_sprites.lua'))()
local Catalog=assert(loadfile(root..'/src/npc_catalog.lua'))()
local mod={path=root,id='apo',options={get=function()return true end}}
function mod:read(path)
 local f=io.open(root..'/'..path,'rb');if not f then return end
 local bytes=f:read('*a');f:close();return bytes
end
local catalog=Catalog.public(mod)
package.loaded['src.render.SpriteRenderer']={new=function(def,seed)return{def=def,seed=seed}end}
local total,riders,other=0,0,0
local byGeneration={0,0}
for generation=1,2 do
 local binder=Binder.new{mod=mod,generation=generation,npcCatalog=catalog,
  compat={characterSources=function()return{}end}}
 for _,row in ipairs(catalog.inventory(generation))do
  local native={def={id=row.sprite,image='native'}}
  local entity={def={sprite=row.sprite,x=row.x,y=row.y},sprite=native}
  local atlas,role,action=binder:_npcVisual(row.map,entity,false)
  if row.sprite=='SPRITE_BIKER'then
   local expected=row.visualAuthority=='OPP_CUE_BALL' and 'cue-ball' or 'biker'
   assert(role==expected and action=='bicycle','wrong rider identity: '..row.map)
   assert(atlas=='assets/characters/actions/'..expected..'/bicycle_4x3.png')
   assert(binder:_bind(entity,atlas,role,nil,action))
   assert(entity.sprite.def.ascendantCharacterAction=='bicycle')
   assert(entity.sprite.def.ascendantRole==expected)
   binder:restore();assert(entity.sprite==native,'native restore changed')
   local strip=binder.runtimeByAtlas[atlas];binder.runtimeByAtlas[atlas]=nil
   local fallback,_,fallbackAction=binder:_npcVisual(row.map,entity,false)
   assert(fallback~=atlas and fallbackAction==nil,'unregistered asset selected')
   binder.runtimeByAtlas[atlas]=strip
   riders=riders+1
   byGeneration[generation]=byGeneration[generation]+1
  else
   assert(action==nil,'riding pose applied to non-rider: '..row.map..'/'..row.sprite)
   other=other+1
  end
  total=total+1
 end
end
assert(byGeneration[1]==23 and byGeneration[2]==7)
-- Decode the actual delivery files and verify every directional cell and
-- native fallback frame is nonempty and has a transparent background.
for _,role in ipairs({'biker','cue-ball'})do
 for _,directory in ipairs({'actions','runtime/actions'})do
  local path='assets/characters/'..directory..'/'..role..'/bicycle_4x3.png'
  local data=love.image.newImageData(love.filesystem.newFileData(assert(mod:read(path)),path))
  local w,h=data:getDimensions();local cols,rows=3,4
  if directory=='runtime/actions'then assert(w==16 and h==96);cols,rows=1,6 end
  local cw,ch=math.floor(w/cols),math.floor(h/rows)
  for r=0,rows-1 do for c=0,cols-1 do
   local opaque,transparent=0,0
   for y=r*ch,(r+1)*ch-1 do for x=c*cw,(c+1)*cw-1 do
    local _,_,_,a=data:getPixel(x,y)
    if a>.5 then opaque=opaque+1 elseif a==0 then transparent=transparent+1 end
   end end
   assert(opaque>20 and transparent>20,'empty or opaque frame '..path)
  end end
  data:release()
 end
end
print('PASS_ALL_BIKERS',total,'catalogue entries',riders,'riders',other,'non-riders unchanged')
