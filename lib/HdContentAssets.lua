-- Narrow bridge for verified external animation PNGs only. No physical cache
-- paths, executable files, characters or engine-generated assets are exposed.
local M={}
function M.install(store,prefix,Assets,graphics,imageApi,filesystem)
  local imageBefore,dataBefore=Assets.image,Assets.imageData
  local textures={}
  local function relative(path)
    if type(path)=="string" and path:sub(1,#prefix)==prefix then
      local rel=path:sub(#prefix+1)
      if rel:sub(1,31)=="assets/pokemon-animation-cards/"then return rel end
    end
  end
  local function data(path)
    local rel=relative(path)
    if not rel then return dataBefore(path)end
    local bytes=assert(store:read(rel),"HD package is missing or damaged")
    local file=filesystem.newFileData(bytes,"verified-pokemon.png")
    local ok,result=pcall(imageApi.newImageData,file)
    if file.release then file:release()end
    assert(ok,result);return result
  end
  local function texture(path)
    local rel=relative(path)
    if not rel then return imageBefore(path)end
    -- Engine sprite rendering needs only the tiny 16x96 fallback strip.
    -- Full atlases are owned and budgeted by the APO scene renderer.
    local info=assert(store:info(rel),"HD package not installed")
    assert(info.width==16 and info.height==96,"HD atlases must use the bounded scene cache")
    if not textures[path]then
      local pixels=data(path)
      local ok,result=pcall(graphics.newImage,pixels)
      if pixels.release then pixels:release()end
      assert(ok,result);textures[path]=result
    end
    return textures[path]
  end
  Assets.image,Assets.imageData=texture,data
  return function()
    if Assets.image==texture then Assets.image=imageBefore end
    if Assets.imageData==data then Assets.imageData=dataBefore end
    for _,value in pairs(textures)do if value.release then pcall(value.release,value)end end
    textures={}
  end
end
return M
