-- The engine appends true-colour redraw zones over palette zones. That is
-- correct for opaque sprites, but composites translucent UI twice. Exclude
-- only our glass rectangles from every underpass and present them once.
local M={}
local function subtract(rect,cut)
  local x,y,w,h=rect.x,rect.y,rect.w,rect.h
  local l,t=math.max(x,cut.x),math.max(y,cut.y)
  local r,b=math.min(x+w,cut.x+cut.w),math.min(y+h,cut.y+cut.h)
  if l>=r or t>=b then return {rect} end
  local out={}
  local function add(a,c,d,e)
    if d>0 and e>0 then out[#out+1]={x=a,y=c,w=d,h=e,colors=rect.colors} end
  end
  add(x,y,w,t-y);add(x,b,w,y+h-b);add(x,t,l-x,b-t);add(r,t,x+w-r,b-t)
  return out
end
function M.zones(zones)
  local glass={}
  for _,z in ipairs(zones or{})do
    if z.vascGlass then
      local parts={z}
      for _,existing in ipairs(glass)do
        local nextParts={}
        for _,p in ipairs(parts)do for _,q in ipairs(subtract(p,existing))do nextParts[#nextParts+1]=q end end
        parts=nextParts
      end
      for _,p in ipairs(parts)do glass[#glass+1]=p end
    end
  end
  if #glass==0 then return zones end
  local out={}
  for _,z in ipairs(zones)do
    if not z.vascGlass then
      local parts={z}
      for _,g in ipairs(glass)do
        local nextParts={}
        for _,p in ipairs(parts)do for _,q in ipairs(subtract(p,g))do nextParts[#nextParts+1]=q end end
        parts=nextParts
      end
      for _,p in ipairs(parts)do out[#out+1]=p end
    end
  end
  for _,g in ipairs(glass)do out[#out+1]={x=g.x,y=g.y,w=g.w,h=g.h,colors=false} end
  return out
end
function M.install()
  if M.installed then return end;M.installed=true
  local R=require('src.render.Renderer');local previous=R.blitCanvas
  function R:blitCanvas(canvas,sx,sy,zones,...)
    if canvas==self.canvas then zones=M.zones(zones) end
    return previous(self,canvas,sx,sy,zones,...)
  end
end
return M
