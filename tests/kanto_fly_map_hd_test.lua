-- Real GPU sampling: sub-logical-pixel artwork must survive the final blit.
local root=assert(arg[1])
local g=love.graphics
local R={canvas=g.newCanvas(576,324,{dpiscale=1})}
local seen
function R:blitCanvas(...) seen={...};return 'native-blit' end
package.loaded['src.render.Renderer']=R
local release
package.loaded['src.render.Assets']={register=function(h)release=h.release end}
local HD=assert(loadfile(root..'/lib/KantoFlyMapHD.lua'))()
local data=love.image.newImageData(1152,648)
for y=0,647 do for x=0,1151 do
 local c=x%2;data:setPixel(x,y,c,c,c,1)
end end
local image=g.newImage(data);image:setFilter('nearest','nearest')
local Screen={};Screen.__index=Screen
function Screen:uiSize()return 576,324 end
function Screen:draw()
 if self.fail and self.__vascKantoHD then error('paint failure')end
 g.setColor(1,1,1,1);g.draw(image,0,0,0,.5,.5)
end
HD.bind(Screen)
local top
local owner=setmetatable({game={stack={top=function()return top end}}},Screen)
top={_active=owner,_stage='wide'}
local zones={};local function blit(sx,dx)
 return R:blitCanvas(R.canvas,sx,sx,zones,sx,sx,11,12,13,14,15,16,dx or 1,dx or 1)
end
g.push('all');g.setCanvas(R.canvas);g.origin();g.clear();owner:draw()
g.translate(17,19);g.setScissor(2,3,4,5);g.setColor(.2,.3,.4,.5)
assert(blit(2)=='native-blit')
assert(HD.receipt.width==1152 and HD.receipt.height==648)
assert(seen[1]~=R.canvas and seen[2]==1 and seen[4]==zones)
assert(seen[5]==2 and seen[7]==11 and seen[9]==13 and seen[14]==1)
assert(g.getCanvas()==R.canvas)
local x,y=g.transformPoint(0,0);assert(x==17 and y==19)
local a,b,c,d=g.getScissor();assert(a==2 and b==3 and c==4 and d==5)
local r,gg,bb,aa=g.getColor();assert(math.abs(r-.2)<.001 and math.abs(aa-.5)<.001)
g.setCanvas();g.setScissor();g.origin()
local pixels=seen[1]:newImageData()
for i=0,15 do local r,_,_,a=pixels:getPixel(i,10);assert(math.abs(r-i%2)<.01 and a>.99)end
pixels:release()
-- At 1x the native target is sufficient; other canvases never get substituted.
blit(1);assert(seen[1]==R.canvas)
local other=g.newCanvas(2,2);R:blitCanvas(other,2,2);assert(seen[1]==other)
-- Info stays on top in HD, while ordinary native overlays cannot be repainted.
top={__vascKantoMapOwner=owner,draw=function()g.setColor(1,0,0,1);g.rectangle('fill',0,0,4,4)end}
owner:draw();blit(2);assert(HD.receipt.info)
pixels=seen[1]:newImageData();r,gg,bb,aa=pixels:getPixel(1,1)
assert(r>.99 and gg<.01 and bb<.01 and aa>.99);pixels:release()
top={};blit(2);assert(seen[1]==R.canvas and HD.receipt==nil)
-- Failed HD paint preserves the already rendered native map and graphics state.
top=owner;owner.fail=true;owner:draw();blit(2)
assert(seen[1]==R.canvas and owner.__vascKantoHD==nil and HD.receipt==nil)
owner.fail=false;owner:draw();blit(2,2);assert(HD.receipt.scale==4)
owner:exit();assert(HD.receipt==nil)
owner:draw();blit(2);release();assert(HD.receipt==nil)
g.pop();other:release();image:release();data:release();R.canvas:release()
print('PASS_KANTO_HD_GPU detail, logical zones, graphics state, info, scope, fallback, DPI and release')
