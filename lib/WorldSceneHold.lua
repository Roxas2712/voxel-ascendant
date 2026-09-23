-- A height rebuild retires all geometry at once. Keep one independent copy
-- of the last presented world while its replacement is built. Never borrow
-- released mesh/canvas resources, carry a picture across maps, or replay FX.
local H={}
local last,held
local cover,arrival
local preparing={ ["terrain-pending"]=true,["horizon-pending"]=true,
 ["atlas-pending"]=true,["glass-pending"]=true,["people-pending"]=true,
 ["startup-seam-pending"]=true }
local function now()return love.timer.getTime()end
function H.clear()
 if held then held.canvas:release();held=nil end
 last=nil
 if cover then cover.canvas:release();cover=nil end
 arrival=nil
end
function H.presented(canvas,state,w,h)
 if cover then cover.canvas:release();cover=nil end
 arrival={map=state.map,ready=true}
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
local function rebuildPending(state,w,h)
 if not held then return end
 -- This is a short rebuild handoff, never a permanent frozen screen after
 -- an unrelated renderer error. A new map or viewport cannot use this image.
 if held.map~=state.map or held.w~=w or held.h~=h or now()-held.at>2.5 then
  H.clear();return
 end
 return held.canvas
end
-- Cold map streaming has no complete world canvas yet. Use an opaque
-- handoff (also under the native warp fade), not the native tile renderer or
-- a stale picture from the previous map. One small, non-MSAA canvas per
-- arrival; preparation continues normally and the timeout cannot restart.
function H.pending(state,w,h,reason)
 local rebuilt=rebuildPending(state,w,h)
 if rebuilt then return rebuilt,"rebuild-hold" end
 if not state or not state.map then return end
 if not arrival or arrival.map~=state.map then
  arrival={map=state.map,at=now()}
 end
 if arrival.ready or not preparing[reason] or now()-arrival.at>=3 then
  if cover then cover.canvas:release();cover=nil end
  return
 end
 if cover and (cover.w~=w or cover.h~=h) then cover.canvas:release();cover=nil end
 if not cover then
  local g=love.graphics
  local canvas
  local ok=pcall(function()
   canvas=g.newCanvas(w,h,{msaa=0})
   g.push('all')
   local drawn,err=pcall(function()
    g.setCanvas(canvas);g.setScissor();g.setColorMask(true,true,true,true)
    g.clear(0,0,0,1)
   end)
   g.pop()
   if not drawn then error(err)end
  end)
  if not ok then if canvas then canvas:release()end;return end
  cover={canvas=canvas,w=w,h=h}
 end
 return cover.canvas,"map-loading-cover"
end
return H
