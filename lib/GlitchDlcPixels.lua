-- Original procedural missing-art marker. No game artwork or animation assets.
local M={}
function M.new(imageApi,w,h)
 local data=imageApi.newImageData(w,h)
 local size=math.min(w,h)>=32 and 32 or 16
 local scale=math.max(1,math.floor(math.min(w,h)/size))
 local ox,oy=math.floor((w-size*scale)/2),math.floor((h-size*scale)/2)
 local colors={{.06,.09,.16,1},{.20,.90,1,1},{.95,.22,.66,1},{.85,.92,1,1},{.30,.37,.58,1}}
 local function pixel(x,y,c)
  for sy=0,scale-1 do for sx=0,scale-1 do
   local px,py=ox+x*scale+sx,oy+y*scale+sy
   if px>=0 and py>=0 and px<w and py<h then data:setPixel(px,py,unpack(c))end
  end end
 end
 local function body(x,y)
  if size==16 then return x>=2 and x<=13 and y>=1 and y<=14 end
  return (x>=5 and x<=23 and y>=2 and y<=28)or(x>=23 and x<=29 and y>=19 and y<=28)
 end
 for y=0,size-1 do for x=0,size-1 do
  if body(x,y)then
   local edge=not(body(x-1,y)and body(x+1,y)and body(x,y-1)and body(x,y+1))
   local n=(x*17+y*31+x*y*7)%29
   pixel(x,y,edge and colors[1]or colors[n<5 and 2 or n<10 and 3 or n<14 and 4 or n<22 and 5 or 1])
  end
 end end
 if size==32 then
  for x=2,8 do pixel(x,8,colors[2])end
  for x=22,28 do pixel(x,14,colors[3])end
 end
 -- An opaque label band keeps DLC readable even against noisy backgrounds.
 local glyphs={'110','101','101','101','110','100','100','100','100','111','111','100','100','100','111'}
 local gs=size==32 and 2 or 1
 local tx=math.floor((size-11*gs)/2);local ty=size==32 and 17 or 6
 for y=ty-1,ty+5*gs do for x=tx-1,tx+11*gs do pixel(x,y,colors[1])end end
 for letter=0,2 do for y=0,4 do for x=0,2 do
  if glyphs[letter*5+y+1]:sub(x+1,x+1)=='1'then
   for dy=0,gs-1 do for dx=0,gs-1 do pixel(tx+(letter*4+x)*gs+dx,ty+y*gs+dy,colors[4])end end
  end
 end end end
 return data
end
return M
