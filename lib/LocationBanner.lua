-- Screen-space presentation for the location banner's existing owner.
-- The owner supplies translated text, lifetime and modal/option gating.
local V=...
local M={}
local notice,font
local function now()return love.timer.getTime()end
function M.present(name,expiresAt,duration)
 if V.require('VoxelState').level<=0 then notice=nil;return false end
 if type(name)~='string' or type(expiresAt)~='number' then return false end
 local t=now()
 if expiresAt<=t then notice=nil;return true end
 notice={name=name:gsub('[%c]',' '),expires=expiresAt,
  started=expiresAt-(tonumber(duration)or 2),seen=t}
 return true
end
function M.layout(x,y,w,h,textWidth)
 local width=math.min(math.max(124,textWidth+54),math.max(80,w-32),360)
 -- Center lane leaves the touch Start/Select and diagnostic corners free.
 return {x=x+(w-width)/2,y=y+math.min(56,math.max(12,h*.055)),w=width,h=38}
end
function M.draw()
 local n=notice;notice=nil;if not n then return end
 local t=now();local age=t-n.started;local remaining=n.expires-t
 -- The owner must offer the banner on this frame. Menus/dialogue never
 -- inherit a stale toast when the underlying overworld stops drawing UI.
 if remaining<=0 or t-n.seen>.1 then notice=nil;return end
 local a=math.min(1,math.max(0,age/.18),math.max(0,remaining/.4))
 local g=love.graphics
 font=font or g.newFont(15)
 local x,y,w,h=require('src.core.SafeArea').windowRect()
 local b=M.layout(x,y,w,h,font:getWidth(n.name))
 g.push('all');g.origin();g.setCanvas();g.setShader();g.setScissor();g.setDepthMode()
 g.setBlendMode('alpha');g.setFont(font)
 -- Cartridge-inspired route plaque: cream face, double border and a small
 -- Poke Ball rather than the former voxel cube. Stay within the safe lane.
 g.setColor(.035,.08,.10,.28*a);g.rectangle('fill',b.x+2,b.y+3,b.w,b.h,9,9)
 g.setColor(.95,.96,.88,.96*a);g.rectangle('fill',b.x,b.y,b.w,b.h,9,9)
 g.setLineWidth(2);g.setColor(.15,.32,.35,.94*a)
 g.rectangle('line',b.x+1,b.y+1,b.w-2,b.h-2,8,8)
 g.setLineWidth(1);g.setColor(.64,.75,.66,.9*a)
 g.rectangle('line',b.x+4,b.y+4,b.w-8,b.h-8,5,5)
 local cx,cy=b.x+21,b.y+b.h/2
 g.setColor(.98,.98,.94,a);g.circle('fill',cx,cy,10)
 g.setColor(.82,.20,.23,a);g.arc('fill','pie',cx,cy,10,math.pi,2*math.pi)
 g.setColor(.14,.25,.28,a);g.setLineWidth(2);g.circle('line',cx,cy,10)
 g.line(cx-10,cy,cx+10,cy);g.circle('fill',cx,cy,4)
 g.setColor(.98,.98,.94,a);g.circle('fill',cx,cy,2)
 local scale=math.min(1,(b.w-48)/math.max(1,font:getWidth(n.name)))
 g.setColor(.12,.24,.27,a)
 g.print(n.name,b.x+40,b.y+(b.h-font:getHeight()*scale)/2,0,scale,scale)
 g.pop()
end
function M.install()
 if M.installed then return end
 local Game=require('src.core.Game');local previous=Game.draw
 function Game:draw(...)local result=previous(self,...);M.draw();return result end
 M.installed=true
end
return M
