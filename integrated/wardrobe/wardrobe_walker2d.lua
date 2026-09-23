-- Local 2D consumer of KASC's saved outfit layers. Original sprites and native
-- battle backs remain untouched; optional VASC continues owning its HD path.
return function(mod,opts)
 local W=assert(opts.wardrobe)
 local M={schema='kasc.wardrobe.walker2d/v1',version=1,native=true}
 local ROOT='wardrobe/standard-walk-v1/'
 local logical='mod_cache/'..mod.id..'/'
 local size,height=16,16
 local function load(name)return assert(love.filesystem.load(mod.path..'/'..name..'.lua'))()end
 local art=load('wardrobe_pixel_art')(load('wardrobe_pixel_parts'))
 local indexFile=ROOT..'index.txt'
 local order={}
 if mod and mod.cache then
  local text=mod.cache:read(indexFile)
  for key in (text or''):gmatch('[0-9a-f]+')do if #key==64 then order[#order+1]=key end end
 end
 local function sha(s)return love.data.encode('string','hex',love.data.hash('sha256',s))end
 local artKey=sha(assert(love.filesystem.read(mod.path..'/wardrobe_pixel_parts.lua'))..assert(love.filesystem.read(mod.path..'/wardrobe_pixel_art.lua')))
 function M.build(id,selection)
  selection=selection or W.get(id)
  local original=mod.path..'/assets/characters/crystal_chars/'..id:lower()..'_walk.png'
  if selection.style=='native'or W.plain(selection)then return original,{frameWidth=16,frameHeight=16,frames=6,anchorX=8,anchorY=16}end
  local parts=W.assets.parts(id,selection)
  local tokens={id,artKey,'mono-v1'}
  for _,slot in ipairs({'upper','lower','footwear','head','eyewear','accessory'})do tokens[#tokens+1]=slot..'='..tostring(parts[slot])end
  for _,slot in ipairs({'hair','streak'})do tokens[#tokens+1]=slot..'='..tostring(selection[slot])end
  local source=love.image.newImageData(original)
  local sourceHash=sha(source:getString())
  assert(sourceHash==art.sources[id],'standard sprite differs from authored 2D template')
  tokens[#tokens+1]=sourceHash
  local key=sha(table.concat(tokens,'\0'));local file=ROOT..key..'.png'
  if not mod.cache:exists(file)or not mod.cache:exists(ROOT..key..'-dmg.png')then
   local out=art.build(source,id,parts,selection,love.image.newImageData)
   local mono=art.monochrome(out,love.image.newImageData);local monoPng=mono:encode('png');mono:release()
   assert(mod.cache:write(ROOT..key..'-dmg.png',monoPng:getString()));monoPng:release()
   local png=out:encode('png');out:release()
   local ok,err=mod.cache:write(file,png:getString());png:release();assert(ok,err)
  end
  source:release()
  for i=#order,1,-1 do if order[i]==key then table.remove(order,i)end end
  order[#order+1]=key
  while #order>96 do
   local old=table.remove(order,1);assert(mod.cache:delete(ROOT..old..'.png'))
   mod.cache:delete(ROOT..old..'-dmg.png')
  end
  assert(mod.cache:write(indexFile,table.concat(order,'\n')))
  return logical..file,{frameWidth=size,frameHeight=height,frames=6,anchorX=size/2,anchorY=height},logical..ROOT..key..'-dmg.png'
 end
 function M.bind(game,player,id,original)
  if W.presentation.hd()then return false end
  if not W.isActive()or W.native(id)or W.plain(W.get(id))then return false end
  local ok,path,geometry,monoPath=pcall(M.build,id)
  if not ok then W.errors.walker2d=tostring(path);return false end
  local def={id=original.def.id,image=path,walker=true,trueColor=true,kaWardrobe2d=true}
  for key,value in pairs(geometry)do def[key]=value end
  local S=require('src.render.SpriteRenderer');local sprite=S.new(def,'player')
  local monoDef={};for k,v in pairs(def)do monoDef[k]=v end
  monoDef.image=monoPath;monoDef.trueColor=false
  local mono=S.new(monoDef,'player');local palette=require('src.render.PaletteFX')
  function sprite:draw(...)
   return S.draw(palette.honorsTrueColor()and self or mono,...)
  end
  function sprite:resolveImage()
   return S.resolveImage(palette.honorsTrueColor()and self or mono)
  end
  player.sprite=sprite;player.kaWardrobe2dOriginal=original
  if player.pose~=player.kaWardrobe2dPose then
   local pose=player.pose
   player.kaWardrobe2dPose=function(p,...)
    local spr,x,y,facing,phase,flip,hopping=pose(p,...)
    -- The requested 2D surface is walking; native rod choreography and battle
    -- backs retain their original complete sprite, not a cropped outfit body.
    if p.fishing and spr and spr.def.kaWardrobe2d then spr=p.kaWardrobe2dOriginal end
    return spr,x,y,facing,phase,flip,hopping
   end
   player.pose=player.kaWardrobe2dPose
  end
  return true
 end
 return M
end
