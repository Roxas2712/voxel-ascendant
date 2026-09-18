-- Screen-space diagnostics. CPU is process CPU time per presented frame;
-- GPU-Tex is LÖVE texture/canvas memory, never GPU utilisation or total VRAM.
local V = ...
local Setting = V.require('ModSetting')
local M = {}
local function toggle(key, label, defaultValue)
  return Setting.new(key, label, {false, true}, {'OFF', 'ON'}, defaultValue ~= false)
end
M.enabled = toggle('liveDisplay', 'LIVE DISPLAY', false)
M.clock = toggle('liveClock', 'CLOCK')
M.fps = toggle('liveFps', 'FPS + FRAME TIME')
M.cpu = toggle('liveCpu', 'CPU FRAME TIME')
M.gpu = toggle('liveGpu', 'GPU TEXTURE MEMORY')
function M.entries()
  return {
    {M.enabled, 'Small top-right display in world, battles and menus. OFF stops all sampling; individual choices are retained.', full=true},
    {M.clock, 'Local device time (24-hour clock), independent of the game day/night cycle.', full=true},
    {M.fps, 'Actual frames per second and average frame time over the last half second. Green: 55+ FPS; amber: 30-54; red: below 30.', full=true},
    {M.cpu, 'Process CPU milliseconds per frame, averaged over half a second. Includes process threads; not CPU utilisation or GPU waiting time.', full=true},
    {M.gpu, 'Memory used by LÖVE textures and render canvases in MiB. This is not total GPU memory, GPU load or a GPU frame-time measurement.', full=true},
  }
end

local lastWall, lastCpu, elapsed, cpuTime, frames, cpuValid
local sample = {}
local rows, widths, font, fontSize, signature, formattedAt = {}, {}, nil, nil, nil, nil
local function reset()
  lastWall, lastCpu, elapsed, cpuTime, frames, cpuValid = nil, nil, 0, 0, 0, true
  sample = {}
  signature, formattedAt = nil, nil
end
reset()
local function finite(x) return type(x)=='number' and x==x and x>=0 and x<math.huge end
local function cpuNow()
  if not (os and os.clock) then return nil end
  local ok, t = pcall(os.clock)
  return ok and finite(t) and t or nil
end
local function measure(t, cpu, gpu)
  local c = cpu and cpuNow() or nil
  if lastWall then
    local dt = t-lastWall
    if dt < 0 then reset() else
      elapsed, frames = elapsed+dt, frames+1
      if cpu then
        if c and lastCpu and c>=lastCpu then cpuTime=cpuTime+c-lastCpu
        else cpuValid=false end
      end
      if elapsed >= .5 then
        sample.fps, sample.ms = frames/elapsed, elapsed*1000/frames
        sample.cpu = cpu and cpuValid and cpuTime*1000/frames or nil
        sample.memory = nil
        if gpu and love.graphics.getStats then
          local ok, stats = pcall(love.graphics.getStats)
          if ok and type(stats)=='table' and finite(stats.texturememory) then
            sample.memory = stats.texturememory/1048576
          end
        end
        elapsed, cpuTime, frames, cpuValid = 0, 0, 0, true
      end
    end
  end
  lastWall, lastCpu = t, c
end
local function textTime()
  if os and os.date then
    local ok, s=pcall(os.date, '%H:%M')
    if ok and type(s)=='string' then return s end
  end
  return '--:--'
end
local function formatRows(t, clock, fps, cpu, gpu)
  if formattedAt and t-formattedAt < .25 then return end
  formattedAt=t
  rows, widths = {}, {}
  local a, b = {}, {}
  if clock then a[#a+1]=textTime() end
  if fps then
    a[#a+1]=sample.fps and string.format('%.0f FPS  /  %.1f ms',sample.fps,sample.ms) or '-- FPS  /  -- ms'
  end
  if cpu then b[#b+1]=sample.cpu and string.format('CPU %.1f ms',sample.cpu) or 'CPU -- ms' end
  if gpu then b[#b+1]=sample.memory and string.format('GPU-Tex %.0f MiB',sample.memory) or 'GPU-Tex -- MiB' end
  if #a>0 then rows[#rows+1]=table.concat(a,'  |  ') end
  if #b>0 then rows[#rows+1]=table.concat(b,'  |  ') end
  for i,s in ipairs(rows) do widths[i]=font:getWidth(s) end
end

function M.draw()
  if not M.enabled:get() then
    if lastWall or signature then reset() end
    return false
  end
  local clock, fps, cpu, gpu=M.clock:get(),M.fps:get(),M.cpu:get(),M.gpu:get()
  if not (clock or fps or cpu or gpu) then
    if lastWall or signature then reset() end
    return false
  end
  local g=love and love.graphics
  if not (g and love.timer and love.timer.getTime) then return false end
  local sig=(clock and 1 or 0)+(fps and 2 or 0)+(cpu and 4 or 0)+(gpu and 8 or 0)
  if signature~=sig then reset(); signature=sig end
  local t=love.timer.getTime()
  -- The clock alone does not poll CPU or GPU counters.
  if fps or cpu or gpu then measure(t,cpu,gpu) end
  local w,h=g.getDimensions()
  local size=math.max(10,math.min(18,math.floor(h/60)))
  if size~=fontSize then
    local previous=font
    font=g.newFont(size); fontSize=size; formattedAt=nil
    if previous then previous:release() end
  end
  formatRows(t,clock,fps,cpu,gpu)
  local width=0
  for _,v in ipairs(widths) do width=math.max(width,v) end
  local line=font:getHeight()+2
  local scale=math.min(1,(w-16)/(width+24))
  local x,y=w-(width+24)*scale-8,8
  g.push('all')
  local ok, err=pcall(function()
    g.setCanvas(); g.origin(); g.setShader(); g.setScissor()
    g.setDepthMode(); g.setStencilTest(); g.setBlendMode('alpha')
    g.translate(x,y); g.scale(scale); g.setFont(font)
    g.setColor(.025,.055,.09,.87)
    g.rectangle('fill',0,0,width+24,#rows*line+8,5,5)
    g.setLineWidth(1); g.setColor(.2,.65,.78,.85)
    g.rectangle('line',.5,.5,width+23,#rows*line+7,5,5)
    local r,green,b=.45,.7,.8
    if fps and sample.fps then
      if sample.fps>=55 then r,green,b=.3,.9,.6
      elseif sample.fps>=30 then r,green,b=1,.73,.25
      else r,green,b=1,.32,.3 end
    end
    g.setColor(r,green,b,1); g.rectangle('fill',1,5,3,#rows*line-2)
    for i,s in ipairs(rows) do
      g.setColor(.89,.95,.98,1); g.print(s,12,4+(i-1)*line)
    end
  end)
  g.pop()
  if not ok then error(err) end
  return true
end

-- Same final presentation seam used by ShortcutToast. No input/update hooks,
-- no per-frame result table, and exact return values from the inner renderer.
function M.install(game)
  if game.__vascPerformanceOverlay then return end
  local inner=assert(game.draw)
  local function after(...)
    local ok=pcall(M.draw)
    if not ok then reset() end -- diagnostics must never break gameplay
    return ...
  end
  game.draw=function(...) return after(inner(...)) end
  game.__vascPerformanceOverlay=true
end
return M
