-- A height rebuild retires all geometry at once. Keep one independent copy
-- of the last presented world while its replacement is built. Never borrow
-- released mesh/canvas resources, carry a picture across maps, or replay FX.
local H={}
local last,held
local function now()return love.timer.getTime()end
function H.clear()
 if held then held.canvas:release();held=nil end
 last=nil
end
function H.presented(canvas,state,w,h)
 if held then held.canvas:release();held=nil end
 last={canvas=canvas,map=state.map,w=w,h=h,at=now()}
end
function H.begin()
 if held then return end -- repeated option changes keep the same safe image
 if not last or now()-last.at>.25 then last=nil;return end
 local source=last;last=nil
 local g=love.graphics
 local canvas
 local ok=pcall(function()
  canvas=g.newCanvas(source.w,source.h)
  g.push('all')
  local copied,err=pcall(function()
   g.setCanvas(canvas);g.origin();g.setShader();g.setScissor();g.setDepthMode()
   g.setBlendMode('replace','premultiplied');g.setColor(1,1,1,1)
   g.clear(0,0,0,0);g.draw(source.canvas,0,0)
  end)
  g.pop()
  if not copied then error(err)end
 end)
 if ok then held={canvas=canvas,map=source.map,w=source.w,h=source.h,at=now()}
 elseif canvas then canvas:release()end
end
function H.pending(state,w,h)
 if not held then return end
 -- This is a short rebuild handoff, never a permanent frozen screen after
 -- an unrelated renderer error. A new map or viewport cannot use this image.
 if held.map~=state.map or held.w~=w or held.h~=h or now()-held.at>2.5 then
  H.clear();return
 end
 return held.canvas
end
return H
