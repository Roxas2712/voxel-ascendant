-- Move the default mobile START/SELECT row out of the battle HUD's bottom
-- band. Return derived geometry so drawing and hit testing share positions,
-- while the engine's saved layout and editor retain their original values.
local M = {}
local function copy(t)
  local out = {};for k,v in pairs(t) do out[k]=v end;return out
end
function M.install(controls)
  if type(controls)~='table' or type(controls.layout)~='function'
      or controls._vascCornerButtons then return end
  local base=controls.layout
  controls._vascCornerButtons=true
  function controls:layout(...)
    local original=base(self,...)
    if self.preview or self.skinId or type(original)~='table'
        or type(self.visible)~='function' or not self:visible() then return original end
    local x,y,w,h=self.layoutOx,self.layoutOy,self.layoutW,self.layoutH
    if not (tonumber(x) and tonumber(y) and tonumber(w) and tonumber(h) and w>0 and h>0) then return original end
    local out=copy(original)
    local positions=self.positions or {}
    for _,name in ipairs({'select','start'}) do
      local z=original[name]
      -- Explicit editor positions remain authoritative; only replace defaults.
      if z and tonumber(z.w) and not positions[name] then
        z=copy(z);out[name]=z
        local margin=math.max(8,z.w*.24)
        local half=z.w*.72
        z.cx=name=='select' and x+margin+half or x+w-margin-half
        z.cy=y+margin+half
      end
    end
    -- The engine's dots menu also defaults to the top right. Seat it below
    -- START, including the START label and both controls' touch padding.
    if out.start~=original.start and original.hotbar and not positions.hotbar then
      local z=copy(original.hotbar);out.hotbar=z
      z.cy=math.max(z.cy,out.start.cy+out.start.w*1.04+z.w*.72+8)
    end
    return out
  end
end
return M
