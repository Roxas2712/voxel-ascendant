-- Run in LOVE: compare actual source pixels with the GPU source correction.
local root=assert(arg[1])
local path=root..'/integrated/ascendant_pokemon_overworld/'
local Rim=assert(loadfile(path..'src/human_rim.lua'))()
assert(not Rim.prepare({},'unreviewed.png'))
assert(not Rim.prepare({getDimensions=function()return 16,96 end},
 'youngster-gen1-bald-hd-4x3-walk-sheet-v1.png'))
for _,suffix in ipairs({'','-bald-green','-bald-red'})do
 local name='youngster-gen1-bald-hd-4x3-walk-sheet-v1'..suffix..'.png'
 local f=assert(io.open(path..'assets/characters/npcs/'..name,'rb'))
 local bytes=f:read('*a');f:close()
 local source=love.image.newImageData(love.filesystem.newFileData(bytes,name))
 local texture=love.graphics.newImage(source)
 local canvas=assert(Rim.prepare(texture,name));local result=canvas:newImageData()
 local removed,frames=0,{}
 for y=0,899 do for x=0,494 do
  local r,g,b,a=source:getPixel(x,y)
  local rr,gg,bb,aa=result:getPixel(x,y)
  if math.abs(a-aa)>.01 then
   assert(aa<.01 and a>.1 and y%225<165,'changed protected art/alpha')
   assert(math.min(r,g,b)>.78 and math.max(r,g,b)-math.min(r,g,b)<.12,'removed colored artwork')
   removed=removed+1;frames[math.floor(y/225)*3+math.floor(x/165)]=true
  elseif a>.02 then
   assert(math.abs(r-rr)<.005 and math.abs(g-gg)<.005 and math.abs(b-bb)<.005,'recolored retained artwork')
  end
 end end
 local count=0;for _ in pairs(frames)do count=count+1 end
 assert(removed>50 and count==12,'not all reviewed frames corrected')
 print('PASS_REVIEWED_YOUNGSTER_RIM',name,removed,count)
 canvas:release();texture:release();source:release();result:release()
end
