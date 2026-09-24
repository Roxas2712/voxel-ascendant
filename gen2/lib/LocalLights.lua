-- Gen2 owns native scene discovery; only bounded GPU lighting is shared.
local V=...
local source=assert(V.mod:read('lib/lighting/LocalLightsCore.lua'))
local M=assert((loadstring or load)(source,'@lighting/LocalLightsCore.lua'))(V)
local windows=V.require('NativeWindowLights')
local function option()
  local value=V.mod.options and V.mod.options:get('localLights')
  if type(value)=='boolean' then return value end
  return M.setting:get()
end
local lastOption
function M.enabled()
  local value=option()
  if lastOption~=nil and lastOption~=value then M.invalidate()end
  lastOption=value
  return M.available() and value
end
function M.prepare(state,outdoor,focus,dark,weather)
  local enabled=M.enabled()
  M.clear(true)
  local f=M.current()
  if not enabled or not(state and state.map) then return f end
  f.suppressed=false;f.map=state.map
  f.tint=V.require('Voxel3D').tint
  f.sky=M.sky(state.map,outdoor,weather)
  local glow=outdoor and V.require('DayNight').windowLight() or 0
  if glow<=0 then return f end
  local sources,buildings={},{}
  windows.append(state,sources,buildings,glow,focus)
  M.assign(sources,buildings,focus,false)
  -- Stable nearest relevant occluders, including each emitter's owner.
  for i,b in ipairs(buildings)do
    b.order=i;b.score=math.huge
    for _,l in ipairs(f.lights)do
      local d=0
      for a,p in ipairs({l.x,l.y,l.z})do
        local nearest=math.max(b.lo[a],math.min(b.hi[a],p));d=d+(p-nearest)^2
      end
      if d<l.radius*l.radius then b.score=math.min(b.score,d)end
    end
  end
  table.sort(buildings,function(a,b)if a.score==b.score then return a.order<b.order end;return a.score<b.score end)
  for i=1,math.min(M.MAX_BLOCKERS,#buildings)do
    local b=buildings[i];if b.score<math.huge then b.index=i;f.blockers[i]=b end
  end
  return f
end
local reset=M.invalidate
function M.invalidate()windows.invalidate();reset()end
M.setting:onChange(function()M.invalidate();lastOption=option()end)
if V.mod.events then V.mod.events:on('mod.options_changed',function(p)
  if p and p.key=='localLights' and (not p.mod or p.mod==V.mod.id)then
    M.setting.index=nil;M.invalidate()
  end
end)end
return M
