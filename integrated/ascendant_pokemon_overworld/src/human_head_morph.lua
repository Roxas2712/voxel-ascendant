-- Artifact-free head turns between the reviewed mother views. Exactly one
-- authored head is visible at a time; a small anchored dip and horizontal
-- compression carry the motion across the two view changes. This avoids the
-- doubled hair, eye and ear contours produced by optical-flow crossfading.
local M={}
function M.new(layers,read,own)
 local api={mode='single-source-yaw'}
 local function wholeProgress(a,b,t)
  if a==1 and (b==2 or b==5)then return t*.5 end
  if (a==2 and b==3)or(a==5 and b==6)then return .5+t*.5 end
  return t
 end
 function api:draw(a,b,t,x,y,scale,headOnly)
  assert(type(t)=='number' and t==t and t>=0 and t<=1,'invalid progress')
  local head=t<.5 and a or b
  local p=wholeProgress(a,b,t)
  local turn=math.sin(math.pi*p)
  local scaleX=scale*(1-.065*turn)
  local scaleY=scale*(1-.012*turn)
  local dip=3.5*scale*turn
  love.graphics.push('all')
  love.graphics.setColor(1,1,1)
  love.graphics.setBlendMode('alpha','alphamultiply')
  if not headOnly and layers.body then
   love.graphics.draw(layers.body,x-256*scale,y-480*scale,0,scale,scale)
  end
  -- Keep the registration point (256,480) fixed while the source compresses.
  love.graphics.draw(assert(layers.heads[head]),x-256*scaleX,y+dip-480*scaleY,0,scaleX,scaleY)
  love.graphics.pop()
 end
 return api
end
return M
