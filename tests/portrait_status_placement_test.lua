local function extract(path,first,last,env)
 local f=assert(io.open(path));local s=f:read('*a');f:close()
 local a=assert(s:find(first,1,true));local b=assert(s:find(last,a,true))
 local fn=assert(loadstring(s:sub(a,b-1)));setfenv(fn,setmetatable(env,{__index=_G}));fn()
end
local FloatingHud={STATUS_SCALE=1.53,GAP=3,EXTRA_RISE=1,OWNER_ATTACHMENT={player={x=-3,y=-2},enemy={x=3,y=-2}},safeInsets=function()return 0,0,0,0 end,rectanglesHit=function(a,b,p)return a[1]<b[1]+b[3]+p and a[1]+a[3]>b[1]-p and a[2]<b[2]+b[4]+p and a[2]+a[4]>b[2]-p end}
local env={FloatingHud=FloatingHud,plateSize=function()return 180,50 end,uiScale=function()return 1.2 end,optionChoice=function(_,fallback)return fallback end,PLATFORM_OS='OS X',isAscendantHost=true,clamp=function(v,lo,hi)return math.max(lo,math.min(hi,v))end}
extract('battle_hud_oras.lua','function FloatingHud.ownerAnchorFor','FloatingHud.statusAttachmentStates =',env)
for _,size in ipairs({{600,955},{390,844}})do
 local w,h=unpack(size);local shot={pw=w,ph=h,actorVisuals={player={head={x=w*.25,y=h*.60},hull={w*.20,h*.60,40,50}},enemy={head={x=w*.75,y=h*.49},hull={w*.70,h*.49,30,40}}}}
 for _,side in ipairs({'player','enemy'})do
  local r=assert(FloatingHud.projectOwnerStatusRect(shot,side))
  assert(r[1]>=0 and r[1]+r[3]<=w and r[2]>=0 and r[2]+r[4]<=h,'portrait card outside viewport')
  for _,v in pairs(shot.actorVisuals)do assert(not FloatingHud.rectanglesHit(r,v.hull,8),'portrait card covered actor')end
 end
end
print('Portrait owner cards: ok')
