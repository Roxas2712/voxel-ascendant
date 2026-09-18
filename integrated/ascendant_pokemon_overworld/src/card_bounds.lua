-- Exact precomputed card geometry metadata, admitted by decoded-image digest.
-- Replaced/DLC graphics and non-RGBA8 data keep the ordinary scanner.
local M={}
function M.new(mod)
 local catalog,decoded
 local function load()
  if catalog~=nil then return end
  local ok,result=pcall(function()
   local text=assert(mod:read('production/card-bounds.lua'))
   return assert(loadstring(text,'@card-bounds'))()
  end)
  catalog=ok and type(result)=='table' and result or {};decoded={}
 end
 return {forImage=function(data)
  if not (love and love.data and love.data.hash and love.data.encode
      and data and data.getFormat and data:getFormat()=='rgba8')then return nil end
  load()
  local ok,key=pcall(function()return love.data.encode('string','hex',love.data.hash('sha256',data))end)
  if not ok then return nil end
  local entry=catalog[key];if not entry then return nil end
  local w,h=data:getDimensions();if entry[1]~=w or entry[2]~=h then return nil end
  if decoded[key]then return decoded[key]end
  local valid,value=pcall(function()
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
 end}
end
return M
