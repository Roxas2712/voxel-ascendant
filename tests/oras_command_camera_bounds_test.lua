local function extract(path,first,last,env)
 local f=assert(io.open(path));local s=f:read('*a');f:close()
 local a=assert(s:find(first,1,true));local b=assert(s:find(last,a,true))
 local fn=assert(loadstring(s:sub(a,b-1)));setfenv(fn,setmetatable(env,{__index=_G}));fn()
end
local sizes={en={fight={69,32},bag={126,62},pokemon={126,62},run={102,39},mega={140,85}},de={fight={67,20},bag={127,63},pokemon={127,63},run={103,40},mega={139,84}}}
local language='en'
local FloatingHud={CONTROL_SCALE=1.5,ORAS_FIGHT_DESIGN_W=69,ORAS_FIGHT_DESIGN_H=32,megaArmed=function(b)return b.mega end}
FloatingHud.styleAsset=function(key)
 local d=sizes[language][key]
 return {getWidth=function()return d[1]end,getHeight=function()return d[2]end}
end
local env={FloatingHud=FloatingHud,megaProfileFor=function(b)return b.mega end,clamp=function(v,a,b)return math.max(a,math.min(b,v))end}
extract('battle_hud_oras.lua','function FloatingHud.commandAssetMetrics','local function renderCommandCanvas',env)
local function contains(a,b)return a[1]<=b[1] and a[2]<=b[2] and a[1]+a[3]>=b[1]+b[3] and a[2]+a[4]>=b[2]+b[4] end
for _,lang in ipairs({'en','de'})do language=lang
 for _,width in ipairs({280,720})do
  for _,mega in ipairs({false,true})do
   for selected=1,4 do
    local b={menuIndex=selected,frame=41,mega=mega}
    local _,_,entries=FloatingHud.orasCommandLayout(b,width,140)
    local rect={10,400,width,140}
    local bounds=FloatingHud.orasCommandBounds(b,rect,1,width,140)
    for _,e in ipairs(entries)do
     local pixels={rect[1]+e.x,rect[2]+e.y,e.width,e.height}
     local covered=false;for _,area in ipairs(bounds)do if contains(area,pixels)then covered=true end end
     assert(covered,'visible localized control escaped camera reservation')
    end
    local blanket=false
    for _,area in ipairs(bounds)do if area[3]>=width*.9 and area[4]>=120 then blanket=true end end
    assert(not blanket,'transparent dock became an opaque camera obstacle')
   end
  end
 end
end
print('ORAS command visible bounds, locales, widths, MEGA: ok')
