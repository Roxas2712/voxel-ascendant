-- One small, engine-scoped profile per playthrough. Coalesce a pinch into one
-- verified storage write instead of doing disk IO for every touch movement.
local M={KEY='terrarium/zoom-v1'}
function M.new(storage,minimum,maximum,warn)
  local P={value=1}
  local game,owner,pending,age,reported
  local function clean(value)
    if type(value)~='number' or value~=value or math.abs(value)==math.huge then return 1 end
    return math.max(minimum,math.min(maximum,value))
  end
  function P.flush()
    if not pending then return true end
    if not game or game.save~=owner then return false end
    local ok,written,reason=false,false,'storage unavailable'
    if storage and type(storage.write)=='function' then
      ok,written,reason=pcall(storage.write,storage,game,M.KEY,{version=1,zoom=P.value})
    end
    if ok and written==true then pending,reported=nil,nil;return true end
    if not reported and warn then pcall(warn,tostring(ok and reason or written))end
    reported=true;age=-1 -- bounded retry after a transient write failure
    return false
  end
  function P.load(current)
    if not current or type(current.save)~='table' then return P.value end
    if owner==current.save then return P.value end
    P.flush()
    game,owner,pending,age,reported=current,current.save,nil,0,nil
    P.value=1
    if storage and type(storage.read)=='function' then
      local ok,data=pcall(storage.read,storage,current,M.KEY)
      if ok and type(data)=='table' and data.version==1 then P.value=clean(data.zoom)end
    end
    return P.value
  end
  function P.remember(value)
    value=clean(value)
    if value==P.value then return end
    P.value=value;pending=true;age=0
  end
  function P.update(dt)
    if pending then
      age=(age or 0)+math.max(0,tonumber(dt)or 0)
      if age>=.35 then P.flush()end
    end
  end
  return P
end
return M
