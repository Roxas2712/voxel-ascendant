-- Chamber-only high-detail cards. The actual NPC keeps its native walker,
-- collision, facing, interaction and save state (including classic 2D).
local Assets=require('src.render.Assets')
local M={}
local sizes={GROUDON=48,KYOGRE=56,RAYQUAZA=56}
local cards={}
function M.prepare(state,posed)
 local map=state and state.map
 if not(map and map.def and map.def.generation~=2)then return end
 local species=(map.id or ''):match('^KA_HEVO_(%u+)_CHAMBER$')
 local size=sizes[species];if not size then return end
 for _,p in ipairs(posed)do
  local e=p.entity;local d=e and e.def;local source=p.sprite and p.sprite.def
  if not p.isPlayer and d and d.name=='KA_HEVO_'..species and source
    and not source.ascendantAtlasImage and not source.ascendantPokemonAnimationCards
    and source.providerId~='ascendant_walksheets'
    and e.ascendantPokemonModelSource~='stadium2'
    and source.id=='SPRITE_KA_HEVO_LEGEND_'..species
    and type(source.voxelChamberImage)=='string'then
   local path=source.voxelChamberImage;local card=cards[path]
   if card==nil then
    local ok,img=pcall(Assets.image,path)
    if ok and img then
     local w,h=img:getDimensions()
     if w>=48 and h>=48 and w<=512 and h<=512 then
      img:setFilter('nearest','nearest')
      card={image=img,def={id=source.id..'_VOXEL_CARD',image=path,
       frames=1,walker=false,trueColor=true,frameWidth=w,frameHeight=h,
       voxelChamberCard=true,voxelWorldWidth=size*w/h,voxelWorldHeight=size}}
      function card:resolveImage()return self.image end
     end
    end
    cards[path]=card or false
   end
   if card then p.sprite=card end
  end
 end
end
function M.invalidate()cards={}end
Assets.register(M.invalidate)
return M
