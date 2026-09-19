-- A readback may run during an already-transformed/shaded battle draw.
-- Neither cached geometry nor repaired artwork may inherit that draw state.
local root=assert(arg[1])
local Pics=assert(loadfile(root..'/lib/BattlePics.lua'))({})
local g=love.graphics
local pixels=love.image.newImageData(8,8)
for y=2,5 do for x=2,5 do
 if x==2 or x==5 or y==2 or y==5 then pixels:setPixel(x,y,1,.5,.25,1) end
end end
local img=g.newImage(pixels)
local target=g.newCanvas(32,32,{dpiscale=1})
local shader=g.newShader([[vec4 effect(vec4 color, Image image, vec2 uv, vec2 screen) {
 vec4 p=Texel(image,uv); return vec4(0.0,0.0,0.0,p.a);
}]])
local function read(image)
 g.push('all');g.origin();g.setShader();g.setScissor();g.setColorMask(true,true,true,true)
 g.setCanvas(target);g.clear(0,0,0,0);g.setBlendMode('replace','premultiplied');g.setColor(1,1,1,1)
 g.draw(image);g.setCanvas();local data=target:newImageData();g.pop();return data
end
for _,mode in ipairs({'shader','transform','scissor','color-mask'}) do
 Pics.invalidate();g.push('all');g.origin();g.setCanvas(target);g.clear(0,0,0,0)
 g.setColor(.2,.3,.4,.5);g.setBlendMode('add','alphamultiply')
 if mode=='shader' then g.setShader(shader)
 elseif mode=='transform' then g.translate(11,9);g.scale(2,3)
 elseif mode=='scissor' then g.setScissor(0,0,1,1)
 elseif mode=='color-mask' then g.setColorMask(false,true,false,true) end
 local x,y=g.transformPoint(3,4)
 local x0,y0,x1,y1=Pics.inkBounds(img)
 assert(x0==2 and y0==2 and x1==5 and y1==5,'readback geometry inherited '..mode)
 local fixed=Pics.filled(img)
 assert(fixed~=img,'enclosed pixels were not restored under '..mode)
 assert(g.getCanvas()==target,'canvas not restored')
 assert(g.getShader()==(mode=='shader' and shader or nil),'shader not restored')
 local xx,yy=g.transformPoint(3,4);assert(xx==x and yy==y,'transform not restored')
 local r,c,b,a=g.getColor();assert(math.abs(r-.2)<1e-6 and math.abs(c-.3)<1e-6 and math.abs(b-.4)<1e-6 and a==.5,'color not restored')
 local blend,alpha=g.getBlendMode();assert(blend=='add' and alpha=='alphamultiply','blend not restored')
 local sx,sy,sw,sh=g.getScissor()
 assert(mode=='scissor' and sx==0 and sy==0 and sw==1 and sh==1 or mode~='scissor' and sx==nil,'scissor not restored')
 local mr,mg,mb,ma=g.getColorMask();assert(mg and ma and mr==(mode~='color-mask') and mb==mr,'color mask not restored')
 g.pop()
 local actual=read(fixed)
 for py=0,7 do for px=0,7 do
  local rr,gg,bb,aa=actual:getPixel(px,py)
  if px>=2 and px<=5 and py>=2 and py<=5 then
   assert(rr>.99 and math.abs(gg-.5)<.005 and math.abs(bb-.25)<.005 and aa>.99,'artwork inherited '..mode)
  else assert(aa==0,'exterior changed under '..mode) end
 end end
 actual:release();fixed:release();print('PASS_BATTLE_PIC_READBACK_STATE',mode)
end
-- Failure must restore the caller's state too, and must not cache bad bounds.
Pics.invalidate();g.push('all');g.setCanvas(target);g.setShader(shader);g.translate(7,8)
local draw=g.draw;g.draw=function()error('simulated GPU readback failure')end
assert(Pics.filled(img)==img);assert(Pics.inkBounds(img)==nil)
g.draw=draw
assert(g.getCanvas()==target and g.getShader()==shader,'failure leaked render state')
g.pop()
Pics.invalidate();assert(Pics.inkBounds(img)==2,'failed readback poisoned subsequent geometry')
print('PASS_BATTLE_PIC_READBACK_FAILURE_RECOVERY')
img:release();pixels:release();target:release();shader:release()
