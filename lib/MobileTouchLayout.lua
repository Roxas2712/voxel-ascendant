-- VASC's corner positions are defaults, not a post-layout displacement.
-- The native layout/editor then applies saved positions and owns dragging,
-- hit testing, reset, scaling and the separate orientation buckets.
local M = {}
function M.install(controls)
  if type(controls)~='table' or type(controls.defaultLayout)~='function'
      or controls._vascCornerDefaults then return end
  local base=controls.defaultLayout
  controls._vascCornerDefaults=true
  function controls.defaultLayout(w,h,x,y,...)
    local out=base(w,h,x,y,...)
    if type(out)~='table' then return out end
    x,y=x or 0,y or 0
    for _,name in ipairs({'select','start'}) do
      local z=out[name]
      if z and tonumber(z.w) then
        local margin=math.max(8,z.w*.24)
        local half=z.w*.72
        z.cx=name=='select' and x+margin+half or x+w-margin-half
        z.cy=y+margin+half
      end
    end
    -- Leave room for START's label and touch padding above the dots menu.
    if out.start and out.hotbar then
      local z=out.hotbar
      z.cy=math.max(z.cy,out.start.cy+out.start.w*1.04+z.w*.72+8)
    end
    return out
  end
  -- A layout may already have been cached before mods loaded.
  controls.layoutW,controls.layoutH=nil,nil
end
return M
