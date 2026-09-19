-- Execute the actual Gen-1 and Gen-2 drawSprite functions with the engine's
-- real palette shaders. White inside a sprite is artwork, not background.
local root=assert(arg[1])
local engine=assert(os.getenv('GEN1RECOMP_ROOT'))
package.loaded['src.core.GameVersion']=assert(loadfile(engine..'/src/core/GameVersion.lua'))()
local P=assert(loadfile(engine..'/src/render/PaletteFX.lua'))()
local palette={{255,255,255},{170,220,120},{60,100,50},{0,0,0}}
P.monPal=function()return palette end
local data=love.image.newImageData(4,4)
data:setPixel(1,1,1,1,1,1)
data:setPixel(2,1,.66,.66,.66,1)
data:setPixel(1,2,0,0,0,1)
data:setPixel(2,2,.33,.33,.33,1)
local img=love.graphics.newImage(data);img:setFilter('nearest','nearest')
local resolved={image=img,trueColor=false}
for _,path in ipairs({'lib/ModernDex.lua','lib/gen2_dex/AscendantDex.lua'})do
 local file=assert(io.open(root..'/'..path));local source=file:read('*a');file:close()
 local first=assert(source:find('local function drawSprite(',1,true))
 local last=assert(source:find('local function drawCaughtBall(',first,true))
 local chunk=assert(loadstring(source:sub(first,last-1)..'return drawSprite'))
 setfenv(chunk,setmetatable({PaletteFX=P,spriteImage=function()return resolved end,
  fill=function()end,line=function()end,text=function()error('unexpected missing sprite')end,
  color=function()love.graphics.setColor(1,1,1,1)end,C={}}, {__index=_G}))
 local draw=chunk()
 for _,trueColor in ipairs({false,true})do
  resolved.trueColor=trueColor
  local canvas=love.graphics.newCanvas(20,20,{dpiscale=1})
  love.graphics.push('all');love.graphics.origin();love.graphics.setScissor();love.graphics.setShader()
  love.graphics.setCanvas(canvas);love.graphics.clear(0,0,0,0)
  draw({},'BULBASAUR',0,0,20,20,true)
  love.graphics.setCanvas();love.graphics.pop()
  local pixels=canvas:newImageData()
  local r,g,b,a=pixels:getPixel(8,8)
  assert(r>.99 and g>.99 and b>.99 and a>.99,'opaque white was keyed out: '..path)
  local _,_,_,clear=pixels:getPixel(6,6);assert(clear==0,'background alpha lost')
  local br,bg,bb,ba=pixels:getPixel(8,10)
  assert(br<.01 and bg<.01 and bb<.01 and ba>.99,'black outline changed')
  pixels:release();canvas:release()
 end
 print('PASS_DEX_ALPHA',path,'indexed and truecolor')
end
img:release();data:release()
