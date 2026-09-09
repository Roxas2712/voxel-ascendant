-- One bounded draw-state adapter for near and far authored scenery. No asset
-- copies, palette mutation, weather clock or texture residency of its own.
local SceneryWeather = {}
local KINDS = {rain=1,storm=1,snow=2,heat=3}
local SWIM_COLUMNS={0,1,2,1}
local PRISM_WEATHER={rain=.25,storm=.12,fog=.3,snow=.45}

function SceneryWeather.values(context)
  if type(context) ~= 'table' or context.outdoor ~= true
      or context.surfaces == false then return 0, 0 end
  local kind = KINDS[context.weather] or 0
  local amount = tonumber(context.amount)
  if kind == 0 or not amount or amount ~= amount
      or amount == math.huge or amount == -math.huge then return 0, 0 end
  return math.max(0, math.min(1, amount)), kind
end

-- Six render-only aquarium cards. Reuse 24 CPU vertices and the same GPU mesh;
-- only upload at 8 Hz. No entities, per-frame images, or retained history.
function SceneryWeather.aquariumVertices(base,frame,out)
  out=out or {}
  local t=frame/8
  for mon=0,5 do
    local species=mon%3
    local phase=t*math.pi*2/(14+species*3)+mon*1.1
    local dz=math.sin(phase)*(14+species*2)
    local dy=math.sin(phase*1.7)*2
    local row=math.cos(phase)>=0 and 1 or 0
    local column=SWIM_COLUMNS[math.floor(t*4)%4+1]
    for corner=1,4 do
      local i=mon*4+corner
      local b=base[i]
      local v=out[i] or {};out[i]=v
      v[1],v[2],v[3],v[6]=b[1],b[2]+dy,b[3]+dz,b[6]
      v[4]=(species*96+column*32+((corner==2 or corner==3) and 32 or 0))/384
      v[5]=(row*32+(corner<=2 and 32 or 0))/64
    end
  end
  return out
end

function SceneryWeather.updateAquarium(rim,now)
  if not (rim.aquariumBase and #rim.aquariumBase==24 and rim.mesh
      and rim.mesh.setVertices and not rim.aquariumUpdateFailed) then return false end
  now=tonumber(now) or 0
  if now~=now or now==math.huge or now==-math.huge then now=0 end
  local frame=math.floor(math.max(0,now)*8)
  if rim.aquariumFrame==frame then return true end
  rim.aquariumWorking=SceneryWeather.aquariumVertices(rim.aquariumBase,frame,rim.aquariumWorking)
  local ok=pcall(rim.mesh.setVertices,rim.mesh,rim.aquariumWorking)
  if not ok then rim.aquariumUpdateFailed=true;return false end
  rim.aquariumFrame=frame
  return true
end

-- Bounded artistic projection, not physical ray tracing. The two light pools
-- shear with the sun and shorten at high elevation. Eight vertices and their
-- GPU mesh are reused; pinned time settings require no repeated uploads.
function SceneryWeather.prismVertices(base,bearing,elevation,out)
  out=out or {}
  local width=(base[1][1]+base[2][1]+base[5][1]+base[6][1])/2
  local drift=-math.cos(math.rad(bearing))*math.min(18,width*.06)
  local length=1-.25*math.sin(math.rad(math.max(0,math.min(90,elevation))))
  for i,b in ipairs(base)do
    local v=out[i] or {};out[i]=v
    local corner=(i-1)%4+1
    local near=base[i-corner+1][3]
    local far=corner>=3
    v[1]=math.max(1,math.min(width-1,b[1]+drift*(far and 1 or .25)))
    v[2],v[3]=b[2],near+(b[3]-near)*length
    v[4],v[5],v[6]=b[4],b[5],b[6]
  end
  return out
end

function SceneryWeather.updatePrism(rim,clock)
  if not (rim.prismBase and #rim.prismBase==8 and rim.mesh and rim.mesh.setVertices
      and not rim.prismUpdateFailed and clock and clock.time and clock.bodyAt) then return false end
  local t=clock.time()
  if type(t)~='number' or t~=t or math.abs(t)==math.huge then return false end
  local frame=math.floor(t*4)
  if rim.prismFrame==frame then return true end
  local bearing,elevation,moon=clock.bodyAt(frame/4)
  if moon then return true end
  if type(bearing)~='number' or type(elevation)~='number' or bearing~=bearing
      or elevation~=elevation or math.abs(bearing)==math.huge or math.abs(elevation)==math.huge then return false end
  rim.prismWorking=SceneryWeather.prismVertices(rim.prismBase,bearing,elevation,rim.prismWorking)
  if not pcall(rim.mesh.setVertices,rim.mesh,rim.prismWorking) then
    rim.prismUpdateFailed=true;return false
  end
  rim.prismFrame=frame
  return true
end

function SceneryWeather.draw(renderer, rim, texture, model, context)
  if rim.class=='garden_prism' then
    local g=love and love.graphics
    if not (g and g.getColor and g.setColor and g.getBlendMode and g.setBlendMode
        and g.getDepthMode and g.setDepthMode) then
      return renderer.draw(rim.mesh,texture,model)
    end
    local color={g.getColor()};local blend,alpha=g.getBlendMode()
    local depth,writes=g.getDepthMode()
    local light=tonumber(context and context.prismLight) or 0
    if light~=light then light=0 end
    light=.3+.7*math.max(0,math.min(1,light))
    local ok,result=pcall(function()
      g.setBlendMode('alpha','alphamultiply');g.setDepthMode('lequal',false)
      g.setColor(color[1]*light,color[2]*light,color[3]*light,color[4]*.82)
      return renderer.draw(rim.mesh,texture,model)
    end)
    pcall(g.setColor,unpack(color));pcall(g.setBlendMode,blend,alpha)
    pcall(g.setDepthMode,depth,writes)
    if not ok then error(result,0)end
    return result
  end
  if rim.class=='water_fish' then
    local timer=love and love.timer
    local ok,now=false,0
    if timer and timer.getTime then ok,now=pcall(timer.getTime)end
    SceneryWeather.updateAquarium(rim,ok and now or 0)
  elseif rim.class=='water_glass' then
    local g=love and love.graphics
    if not (g and g.getColor and g.setColor and renderer.blend) then return false end
    local old={g.getColor()}
    local restore=g.getBlendMode and g.setBlendMode and g.getDepthMode and g.setDepthMode
    local blend,alpha,depth,writes
    if restore then blend,alpha=g.getBlendMode();depth,writes=g.getDepthMode()end
    local ok,result=pcall(function()
      renderer.blend('add')
      g.setColor(old[1]*.22,old[2]*.22,old[3]*.22,old[4])
      return renderer.draw(rim.mesh,texture,model)
    end)
    pcall(g.setColor,unpack(old))
    if restore then
      pcall(g.setBlendMode,blend,alpha);pcall(g.setDepthMode,depth,writes)
    else pcall(renderer.blend,nil)end
    if not ok then error(result,0)end
    return result
  end
  if rim.class == 'garden_light' then
    -- Stained glass removes some colour as well as adding a light pool.
    -- Multiplicative transmission keeps the pattern visible on white floors.
    local g=love and love.graphics
    if not (type(renderer.blend)=='function' and g and g.getColor and g.setColor) then
      return false
    end
    local strength=context and context.prismLight or 0
    if not (type(strength)=='number' and strength>0) then return true end
    strength=math.min(1,strength)
    SceneryWeather.updatePrism(rim,context and context.prismClock)
    local old={g.getColor()}
    local transmission=renderer.prismTransmission
    local filter=type(transmission)=='function' and g.getBlendMode and g.setBlendMode
      and g.getDepthMode and g.setDepthMode
    local blend,alpha,depth,writes
    if filter then
      blend,alpha=g.getBlendMode()
      depth,writes=g.getDepthMode()
    end
    local ok,result=pcall(function()
      if filter and transmission(strength*.44)==true then
        -- LOVE 11 requires premultiplied alpha for multiply. The scoped
        -- shader emits an opaque 1→pigment filter, independent of face shade.
        g.setBlendMode('multiply','premultiplied')
        g.setDepthMode('lequal',false)
        renderer.draw(rim.mesh,texture,model)
      end
      if type(transmission)=='function' then transmission(0) end
      renderer.blend('add')
      local glow=strength*.28
      g.setColor(old[1]*glow,old[2]*glow,old[3]*glow,old[4])
      return renderer.draw(rim.mesh,texture,model)
    end)
    if type(transmission)=='function' then pcall(transmission,0) end
    pcall(g.setColor,unpack(old))
    if filter then
      pcall(g.setBlendMode,blend,alpha)
      pcall(g.setDepthMode,depth,writes)
    else
      pcall(renderer.blend,nil)
    end
    if not ok then error(result,0) end
    return result
  end
  local amount, kind = SceneryWeather.values(context)
  -- Water, actors and imported decorations retain their dedicated owners.
  local eligible = rim.kind == 'wall' or rim.kind == 'ground'
    or rim.kind == 'foreground' or rim.kind == 'route8-seam-path'
    or rim.kind == 'forest-gate-path'
  local setter = renderer.weatherPanorama
  local scoped = eligible and amount > 0 and type(setter) == 'function'
  if scoped then
    local ok, applied = pcall(setter, amount, kind)
    if not ok or applied ~= true then pcall(setter, 0) end
  end
  local ok, result = pcall(renderer.draw, rim.mesh, texture, model)
  -- Even a partially failed uniform update or draw cannot coat the next actor.
  if scoped then pcall(setter, 0) end
  if not ok then error(result, 0) end
  return result
end

function SceneryWeather.prismLight(clock,weather)
  if not (clock and type(clock.time)=='function' and type(clock.bodyAt)=='function'
      and type(clock.strengthAt)=='function') then return 0 end
  local t=clock.time()
  local _,_,moon=clock.bodyAt(t)
  if moon then return 0 end
  return math.max(0,math.min(1,clock.strengthAt(t)))*(PRISM_WEATHER[weather] or 1)
end

return SceneryWeather
