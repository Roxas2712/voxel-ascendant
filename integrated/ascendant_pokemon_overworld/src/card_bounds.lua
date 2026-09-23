-- Exact precomputed card geometry, admitted by content digest. Known PNGs
-- can skip a second decode; changed/DLC graphics keep the RGBA8 scanner.
local M={}
function M.new(mod)
 local catalog,fileCatalog,decoded
 local function readCatalog(path)
  local ok,result=pcall(function()
   local text=assert(mod:read(path))
   return assert(loadstring(text,'@'..path))()
  end)
  return ok and type(result)=='table' and result or {}
 end
 local function load()
  if catalog~=nil then return end
  catalog=readCatalog('production/card-bounds.lua')
  fileCatalog=readCatalog('production/card-file-digests.lua');decoded={}
 end
 local function digest(data)
  if not (love and love.data and love.data.hash and love.data.encode) then return nil end
  local ok,key=pcall(function()return love.data.encode('string','hex',love.data.hash('sha256',data))end)
  return ok and key or nil
 end
 local function bounds(key,w,h)
  local entry=catalog[key];if not entry then return nil end
  if w and (entry[1]~=w or entry[2]~=h)then return nil end
  if decoded[key]then return decoded[key]end
  local valid,value=pcall(function()
   w,h=entry[1],entry[2]
   local out={};for row=0,3 do out[row]={};for col=0,2 do
    local f=assert(entry[3][row*3+col+1])
    out[row][col]={left=f[1],top=f[2],right=f[3],bottom=f[4],
     imageWidth=w,imageHeight=h,cellX=col*math.floor(w/3),cellY=row*math.floor(h/4),
     gridColumns=10,gridRows=14,occupied=f[5],
     cubeColumns=16,cubeRows=22,cubeOccupied=f[6]}
   end end;return out
  end)
  if valid then decoded[key]=value;return value end
  return nil
 end
 return {
  forImage=function(data)
   if not (data and data.getFormat and data:getFormat()=='rgba8')then return nil end
   load();local key=digest(data);if not key then return nil end
   local w,h=data:getDimensions();return bounds(key,w,h)
  end,
  -- Caller supplies Assets.resolve(path), so replacement assets are checked
  -- rather than trusting a filename, timestamp or a previous path lookup.
  -- Never retain PNG bytes or cache misses from user/DLC files.
  forPath=function(path)
   if type(path)~='string' or not (love and love.filesystem and love.filesystem.read)then return nil end
   load()
   local ok,bytes=pcall(love.filesystem.read,path)
   if not ok or type(bytes)~='string' then return nil end
   local key=digest(bytes);local imageKey=key and fileCatalog[key]
   return imageKey and bounds(imageKey) or nil
  end,
 }
end
return M
