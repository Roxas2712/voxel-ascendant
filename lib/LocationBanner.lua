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
 g.setColor(.025,.055,.065,.77*a)
 -- Small stepped corners and an inset top edge echo the voxel buildings.
 g.rectangle('fill',b.x+3,b.y,b.w-6,b.h)
 g.rectangle('fill',b.x,b.y+3,b.w,b.h-6)
 g.setColor(.48,.76,.72,.5*a);g.rectangle('fill',b.x+5,b.y,b.w-10,1)
 local cx,cy=b.x+15,b.y+13
 g.setColor(.67,.86,.78,.95*a);g.polygon('fill',cx,cy,cx+7,cy-4,cx+14,cy,cx+7,cy+4)
 g.setColor(.32,.57,.51,.95*a);g.polygon('fill',cx,cy,cx+7,cy+4,cx+7,cy+12,cx,cy+8)
 g.setColor(.46,.70,.62,.95*a);g.polygon('fill',cx+7,cy+4,cx+14,cy,cx+14,cy+8,cx+7,cy+12)
 local scale=math.min(1,(b.w-48)/math.max(1,font:getWidth(n.name)))
 g.setColor(.94,.96,.92,.96*a)
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
