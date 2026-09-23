-- Resolve only catalog-verified mounted data. Mod scripts stay on the original loader.
local M={}
function M.install(mod,store,cache,fs,graphics,imageApi,Assets,owner)
  owner=owner or 'vasc'
  assert(owner=='vasc' or owner=='kasc')
  local before={read=mod.read,info=mod.info,image=mod.image};local textures,placeholders={},{};local active=true;local restoreAssets
  local function known(path)
    return active and type(path)=='string' and store.files[owner..':'..path]~=nil
  end
  local function read(path)
    if type(store.readVerified)=='function' then return store:readVerified(owner,path) end
    local key,err=store:materialize(owner,path)
    if not key then return nil,err end
    return cache:read(key)
  end
  local function pixels(path)
    local raw,err=read(path)
    assert(raw,'verified sprite unavailable: '..owner..':'..tostring(path)..' ('..tostring(err)..')')
    local data=fs.newFileData(raw,'verified-sprite.png')
    local ok,result=pcall(imageApi.newImageData,data)
    if data.release then data:release()end
    assert(ok,result);return result
  end
  local function image(path)
    if not textures[path] then
      local data=pixels(path);local ok,result=pcall(graphics.newImage,data)
      if data.release then data:release()end
      assert(ok,result);textures[path]=result
    end
    return textures[path]
  end
  local function missing(path)
    local optional=mod.exports and mod.exports.optionalPokemonAssets
    if not active or known(path)or not optional or type(optional.metadata)~='function'then return nil end
    local meta=optional.metadata(path)
    if not meta or before.info and before.info(mod,path)then return nil end
    return meta
  end
  local Glitch=assert((loadstring or _G.load)(assert(mod:read('lib/GlitchDlcPixels.lua'))))()
  local function placeholderPixels(meta)
    return Glitch.new(imageApi,meta.width,meta.height)
  end
  local function placeholder(meta)
    local key=meta.width..'x'..meta.height
    if not placeholders[key]then
      local data=placeholderPixels(meta);local ok,result=pcall(graphics.newImage,data)
      if data.release then data:release()end
      assert(ok,result);placeholders[key]=result
    end
    return placeholders[key]
  end
  function mod:spriteAssetVersion(path)
    local f=active and store.files[owner..':'..tostring(path)]
    return f and f.sha256 or nil
  end
  function mod:read(path)if known(path)then return read(path)end;return before.read(self,path)end
  function mod:info(path)
    local f=active and store.files[owner..':'..tostring(path)]
    if f then return {type='file',size=f.bytes}end
    return before.info and before.info(self,path)
  end
  function mod:image(path,...)
    if known(path) then return image(path)end
    local meta=missing(path);if meta then return placeholder(meta)end
    return before.image(self,path,...)
  end
  if Assets then
    local priorImage,priorData,priorBytes=Assets.image,Assets.imageData,Assets.hdImageBytes
    local prefix=mod.path:gsub('/$','')..'/'
    local function relative(path)
      if type(path)=='string' and path:sub(1,#prefix)==prefix then return path:sub(#prefix+1)end
    end
    local wrappedImage=function(path,...)
      local rel=relative(path)
      if rel then if known(rel)then return image(rel)end;local meta=missing(rel);if meta then return placeholder(meta)end end
      return priorImage(path,...)
    end
    local wrappedData=function(path,...)
      local rel=relative(path)
      if rel then if known(rel)then return pixels(rel)end;local meta=missing(rel);if meta then return placeholderPixels(meta)end end
      return priorData(path,...)
    end
    local wrappedBytes=function(path)
      local rel=relative(path)
      if rel and known(rel)then return assert(read(rel),'verified sprite unavailable') end
      if priorBytes then return priorBytes(path) end
    end
    Assets.image,Assets.imageData=wrappedImage,wrappedData
    Assets.hdImageBytes=wrappedBytes
    restoreAssets=function()
      if Assets.image==wrappedImage then Assets.image=priorImage end
      if Assets.imageData==wrappedData then Assets.imageData=priorData end
      if Assets.hdImageBytes==wrappedBytes then Assets.hdImageBytes=priorBytes end
    end
  end
  local function close()
    if not active then return end;active=false
    for _,texture in pairs(textures)do if texture.release then pcall(texture.release,texture)end end
    for _,texture in pairs(placeholders)do if texture.release then pcall(texture.release,texture)end end
    textures={};placeholders={};if restoreAssets then restoreAssets()end
  end
  if Assets and Assets.register then Assets.register{invalidate=function()textures={}end,release=close}end
  return {read=read,installed=function(path)return known(path)end,close=close}
end
return M
