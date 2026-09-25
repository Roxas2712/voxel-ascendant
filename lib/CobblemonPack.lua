local V=...;local Content=V.require('CobblemonContent');local Geometry=V.require('CobblemonGeometry')
local M={}
local function failure(dex,reason)
 local ok,d=pcall(V.require,'Diagnostics')
 if ok and d.write then pcall(d.write,'battle-sprite-unavailable',{requested='cobblemon',actual='sprite',
  reason=tostring(dex)..': '..tostring(reason),caller='CobblemonPack'})end
end
local models=setmetatable({},{__mode='v'})
-- An actor may ask again every frame while using its sprite fallback. Retry
-- a failed model only after content activation changes the available data.
local failed,failedEpoch={},nil
function M.variant(mon)
 if type(mon)~='table'then return 'normal'end
 if mon._ascMegaForm or mon.ascMegaForm then return nil end
 local identity=Content.catalog.runtime and Content.catalog.runtime[mon.species]
 if Content.catalog.runtime and mon.species and not identity then return nil end
 if mon.form and (not identity or identity.variantPrefix=='') then return nil end
 local female=mon.gender=='female' or mon.gender=='F' or mon.gender=='f'
 local shiny=mon.shiny==true or mon.isShiny==true or mon._shiny==true
 if V.require then local ok,helper=pcall(V.require,'Gen2CrystalFronts');if ok and helper.isShiny then local yes,value=pcall(helper.isShiny,mon);shiny=shiny or yes and value==true end end
 local variant=(female and 'female' or '')..(shiny and (female and '_shiny' or 'shiny')or (female and '' or 'normal'))
 return (identity and identity.variantPrefix or '')..variant
end
local function national(dex,mon)
 local identity=type(mon)=='table' and Content.catalog.runtime and Content.catalog.runtime[mon.species]
 return identity and identity.dex or dex
end
function M.dex(mon)return national(nil,mon)end
function M.available(dex,mon)local variant=M.variant(mon);return variant~=nil and Content.available(national(dex,mon),variant)end
function M.load(dex,mon)
 dex=national(dex,mon)
 local epoch=Content.epoch or 0
 if failedEpoch~=epoch then failed,failedEpoch={},epoch end
 local variant=M.variant(mon)
 local key=tostring(epoch)..':'..tostring(dex)..':'..tostring(variant)
 if failed[key]then return nil end
 if not variant or not Content.available(dex,variant)then failed[key]=true;failure(dex,'variant-unavailable/'..tostring(variant));return nil end
 local model=models[key];if model then return model end
 model=Content.record(dex,variant);if not model then failed[key]=true;failure(dex,'prepared-model-missing-or-invalid/'..variant);return nil end
 model.crystalDex=dex
 model.assetProvider=M;model.textures={{}};models[key]=model;return model
end
function M.sample(model,index,frame,wrap)return Geometry.sample(model,index,frame,wrap)end
function M.image(model,index)
 if index~=1 then return nil end
 local slot=model.textures[1];if slot.image~=nil then return slot.image or nil end
 local owned={}
 local function own(object)owned[object]=true;return object end
 local function release(object)
  if owned[object]then owned[object]=nil;if object.release then pcall(object.release,object)end end
 end
 local ok,img=pcall(function()
  local fs=V.require('EngineCompat').fs()
  local function data(path)
   local bytes=assert(Content.read(path),'Cobblemon texture missing')
   local fd=own((fs.newFileData or love.filesystem.newFileData)(bytes,'cobblemon.png'))
   local image=own(love.image.newImageData(fd));release(fd)
   assert(image:getWidth()<=4096 and image:getHeight()<=4096,'texture size');return image
  end
  local base=data(model.texture)
  for _,path in ipairs(model.layers or {})do
   local layer=data(path)
   if layer:getWidth()==base:getWidth() and layer:getHeight()==base:getHeight()then
    base:mapPixel(function(x,y,r,g,b,a)
     local R,G,B,A=layer:getPixel(x,y);local out=A+a*(1-A)
     if out==0 then return 0,0,0,0 end
     return (R*A+r*a*(1-A))/out,(G*A+g*a*(1-A))/out,(B*A+b*a*(1-A))/out,out
    end)
   end
   release(layer)
  end
  local image=own(love.graphics.newImage(base));release(base);image:setFilter('nearest','nearest');return image
 end)
 if ok then owned[img]=nil end -- The model owns only the completed GPU image.
 for object in pairs(owned)do release(object)end
 if not ok then failure(model.crystalDex,'texture-upload: '..tostring(img))end
 slot.image=ok and img or false;return slot.image or nil
end
return M
