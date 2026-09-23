-- Small immutable roof attachments, sharing the house palette and transform.
-- No map edits, weather-dependent rebuilds, particles or additional textures.
local W={}
function W.roof(P,kind,w,d,height,sides,doors)
  local key=kind..'_winter_eaves'
  if P.models[key] then return key end
  local boxes={}
  local function icicle(x,z,n)
    local length=3+(n*7)%5
    boxes[#boxes+1]={x,height-length*.55,z,2,length*.55,2,4}
    boxes[#boxes+1]={x+.5,height-length,z+.5,1,length*.45,1,7}
  end
  local ordinal=0
  for _,side in ipairs(sides)do
    local span=(side=='north' or side=='south') and w or d
    local step=math.max(9,math.ceil((span-8)/12))
    for at=4,span-4,step do
      local clear=true
      for _,door in ipairs(doors or {})do
        if door.side==side and math.abs(at-door.at)<(door.width or 14)/2+5 then clear=false end
      end
      if clear then
        ordinal=ordinal+1
        if side=='north' then icicle(at,0,ordinal)
        elseif side=='south' then icicle(at,d-2,ordinal)
        elseif side=='west' then icicle(0,at,ordinal)
        else icicle(w-2,at,ordinal)end
      end
    end
  end
  P.models[key]={boxes=boxes,directBoxes=true,step=1,
    frameW=w,frameH=height+d,depth=d,offsetY=-height}
  return key
end
return W
