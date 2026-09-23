-- Atlas geometry belongs to the exact bytes used to create the GPU image.
-- Bundled sheets have precomputed bounds for every camera direction, avoiding
-- PNG decoding and alpha scans when a trainer turns during a live battle.
local load=...
local catalog=load('data/atlas_bounds.lua')
local A={}
local Assets=require('src.render.Assets')
function A.new(mod,chars)
 local sheets,order={},{}
 return function(role,row,column)
  local spec=chars.get(role)
  local path=mod.resolveAsset and mod.resolveAsset(spec.path)
    or (spec.path:match('^assets/') and mod.path..'/'..spec.path or spec.path)
  if role=='red'or role=='blue'or role=='green'then
   local game=require('src.core.Game')
   local exports=game.mods and game.mods.exports
   local wardrobe=exports and ((exports.kanto_ascendant and exports.kanto_ascendant.wardrobe)
    or(exports.VOXEL_ASCENDANT and exports.VOXEL_ASCENDANT.wardrobe))
   local walking=exports and exports.VOXEL_ASCENDANT and exports.VOXEL_ASCENDANT.overworldPokemon
   walking=walking and walking.walkingSprites
   if walking and walking.resolveAppearance then path=walking.resolveAppearance(path,role)
   elseif wardrobe then path=wardrobe.resolve(path,role)end
  end
  local sheet=sheets[path]
  if not sheet then
   -- Read owned assets through the host API. Engine 0.2.7x no longer
   -- guarantees filesystem.newFileData(path) in a mod's sandbox, especially
   -- for companion trainer cards. Foreign paths use the normal image loader.
   local bytes=mod.readAsset and mod.readAsset(path)
   local key=bytes and love.data.encode('string','hex',love.data.hash('sha256',bytes))
   local file=bytes and love.filesystem.newFileData(bytes,'battle-hero.png')
   local pixels=not file and Assets.imageData(path) or nil
   local ok,img=pcall(love.graphics.newImage,file or pixels)
   if pixels then pixels:release()end
   if not ok then if file then file:release()end;error(img,0)end
   sheet={image=img,bytes=file,path=path,entry=key and catalog[key],bounds={}}
   sheets[path]=sheet
  end
  for i=#order,1,-1 do if order[i]==path then table.remove(order,i)end end
  order[#order+1]=path
  while #order>12 do
   local old=table.remove(order,1);local retired=sheets[old];sheets[old]=nil
   retired.image:release();if retired.bytes then retired.bytes:release()end
  end
  local iw,ih=sheet.image:getDimensions()
  local e=sheet.entry
  local cache=sheet.bounds[spec]
  if not cache then cache={};sheet.bounds[spec]=cache end
  local index=spec.clips and 'clips' or row*spec.columns+column+1
  local b=cache[index]
  if not b then
   if e and e[1]==iw and e[2]==ih and e[3]==spec.columns and e[4]==spec.rows then
    if spec.clips then
     -- The scanner uses one union in cell coordinates for authored clips.
     local l,t,r,bot=iw,ih,-1,-1
     for _,cell in ipairs(e[5])do
      if cell then
       l,t,r,bot=math.min(l,cell[1]),math.min(t,cell[2]),math.max(r,cell[3]),math.max(bot,cell[4])
      end
     end
     if r>=l then b={l,t,r,bot,iw/spec.columns,ih/spec.rows}end
    else
     local cell=e[5][index]
     if cell then b={cell[1],cell[2],cell[3],cell[4],iw/spec.columns,ih/spec.rows}end
    end
   end
   if not b then
    -- Replaced/DLC sheets and foreign grid layouts retain the exact scanner.
    -- Decode the same bytes as the image, even if the file changed meanwhile.
    local pixels=sheet.bytes and love.image.newImageData(sheet.bytes) or Assets.imageData(sheet.path)
    local ok,result=pcall(chars.cellBounds,spec,pixels,row,column)
    pixels:release()
    if not ok then error(result,0)end
    b=result
   end
   cache[index]=b
  end
  return sheet.image,b,path:find("/voxel-demo/",1,true)~=nil
 end
end
return A
