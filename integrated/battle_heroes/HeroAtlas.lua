-- Atlas geometry belongs to the exact bytes used to create the GPU image.
-- Bundled sheets have precomputed bounds for every camera direction, avoiding
-- PNG decoding and alpha scans when a trainer turns during a live battle.
local load=...
local catalog=load('data/atlas_bounds.lua')
local A={}
function A.new(mod,chars)
 local sheets={}
 return function(role,row,column)
  local spec=chars.get(role)
  local path=mod.resolveAsset and mod.resolveAsset(spec.path)
    or (spec.path:match('^assets/') and mod.path..'/'..spec.path or spec.path)
  local sheet=sheets[path]
  if not sheet then
   local bytes=love.filesystem.newFileData(path)
   local key=love.data.encode('string','hex',love.data.hash('sha256',bytes))
   sheet={image=love.graphics.newImage(bytes),bytes=bytes,entry=catalog[key],bounds={}}
   sheets[path]=sheet
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
    local pixels=love.image.newImageData(sheet.bytes)
    local ok,result=pcall(chars.cellBounds,spec,pixels,row,column)
    pixels:release()
    if not ok then error(result,0)end
    b=result
   end
   cache[index]=b
  end
  return sheet.image,b
 end
end
return A
