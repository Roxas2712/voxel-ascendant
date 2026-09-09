-- Olivine's blocked side border becomes a low curb under the steel shell.
-- Late presentation-only adjustment: never change collision or map tiles.
local P={HEIGHT=6}
local signature={
 [10]='0112233301233333013333330233321102321122022122220212222201222222',
 [11]='3332111033333110333322101123322022211220222212202221212022221110',
 [26]='0112222201222233011332110132111101111111021111110111111100000000',
 [27]='2222211033221110112321101111221011111110111111201111111000000000',
}
local function key(x,y)return (y+64)*4096+x+64 end
function P.find(map)
 local d=map and map.def
 if not(d and map.id=='OLIVINE_GYM' and d.generation==2 and d.width==5 and d.height==8
  and d.tileset=='TILESET_CHAMPIONS_ROOM' and d.environment=='INDOOR'
  and not d.outdoor and next(d.connections or {})==nil)then return {}end
 local out={}
 for y=0,15 do for _,x in ipairs({0,9})do
  local good=map:cellCollision(x,y)==7 and not map:isWarpTileCell(x,y)
  for dy=0,1 do for dx=0,1 do
   local wanted=10+dx+((y==15 and dy==1) and 16 or 0)
   good=good and map:tileAt(x*2+dx,y*2+dy)==wanted
  end end
  if good then out[#out+1]={x=x,y=y}end
 end end
 return out
end
function P.artMatches(pixels)
 if not(pixels and pixels.getDimensions and pixels.getPixel)then return false end
 local w,h=pixels:getDimensions();if w~=128 or h~=128 then return false end
 for tile,expected in pairs(signature)do for y=0,7 do for x=0,7 do
  local wanted=tonumber(expected:sub(y*8+x+1,y*8+x+1))/3
  local r,g,b,a=pixels:getPixel(tile%16*8+x,math.floor(tile/16)*8+y)
  if math.abs(r-wanted)>.001 or math.abs(g-wanted)>.001 or math.abs(b-wanted)>.001
   or not a or a<.99 then return false end
 end end end
 return true
end
function P.build(state,map,pixels)
 local found=P.find(map)
 if #found==0 or not P.artMatches(pixels)then return 0 end
 local count=0
 for _,p in ipairs(found)do
  local keys={};local good=true
  for dy=0,1 do for dx=0,1 do
   local k=key(p.x*2+dx,p.y*2+dy);keys[#keys+1]=k
   local shape,run=state.shapeAt[k],state.runs[k]
   good=good and not state.skip[k] and shape and shape.class=='wall' and shape.h==16
    and run and run.h==16 and run.peak==16 and (run.rise or 0)==0 and not run.door
  end end
  if good then
   for _,k in ipairs(keys)do
    -- Never mutate shared profile or run tables used by another tile.
    local shape,run={},{}
    for f,v in pairs(state.shapeAt[k])do shape[f]=v end
    for f,v in pairs(state.runs[k])do run[f]=v end
    shape.h,run.h,run.peak=P.HEIGHT,P.HEIGHT,P.HEIGHT
    state.shapeAt[k],state.runs[k]=shape,run
   end
   count=count+1
  end
 end
 return count
end
return P
