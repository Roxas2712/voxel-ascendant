-- Upload authored interior panoramas on devices whose texture limit is below
-- the source width. Resampling happens once during scene preparation, on CPU;
-- no oversized source image ever reaches the GPU.
local M = {}
function M.load(g, imageAPI, path, spec, backgrounds)
  local limits = g.getSystemLimits and g.getSystemLimits() or {}
  local limit = tonumber(limits.texturesize) or math.huge
  local source, resized, image
  local width, height = spec.width, spec.height
  local function release(v) if v and v.release then pcall(v.release,v) end end
  local ok, err = pcall(function()
    local input = path
    if math.max(width,height) > limit then
      assert(imageAPI and imageAPI.newImageData,'Image decoding unavailable')
      source = backgrounds and backgrounds.imageData(path) or imageAPI.newImageData(path)
      local sw, sh = source:getDimensions()
      assert(sw==width and sh==height,'Interior source dimensions changed')
      local scale = math.min(1024,limit)/math.max(sw,sh)
      width, height = math.max(1,math.floor(sw*scale)), math.max(1,math.floor(sh*scale))
      resized = imageAPI.newImageData(width,height)
      resized:mapPixel(function(x,y)
        return source:getPixel(math.min(sw-1,math.floor((x+.5)*sw/width)),
          math.min(sh-1,math.floor((y+.5)*sh/height)))
      end)
      input = resized
    end
    if input==path and backgrounds and backgrounds.has(path) then
      source=backgrounds.imageData(path);input=source
    end
    local uploaded, value = pcall(g.newImage,input,{mipmaps=false,linear=false})
    if not uploaded then uploaded, value = pcall(g.newImage,input) end
    assert(uploaded and value,value or 'Interior upload failed')
    image=value
    local iw, ih=image:getDimensions()
    assert(iw==width and ih==height,'Interior upload dimensions changed')
  end)
  release(resized);release(source)
  if not ok then release(image);return nil,tostring(err) end
  return image
end
return M
