local root=assert(arg[1])
local stored={}
local modules={}
local V={mod={id='VOXEL_ASCENDANT',options={get=function(_,k)return stored[k]end}}}
V.require=function(name)return assert(modules[name],name)end
modules.ModSetting=assert(loadfile(root..'/lib/ModSetting.lua'))(V)
local Settings=assert(loadfile(root..'/lib/OrasBattleHudSettings.lua'))(V)
assert(Settings.anchorSetting:get()=='outside')
Settings.anchorSetting:sync('outside');assert(Settings.anchorSetting:get()=='outside')
Settings.anchorSetting:sync('above');assert(Settings.anchorSetting:get()=='above')

-- Exercise the actual owner projection code, with deterministic viewport
-- and plate dimensions. Camera/head changes must not move clear corner seats.
local f=assert(io.open(root..'/battle_hud_oras.lua','r'));local source=f:read('*a');f:close()
local start=assert(source:find('FloatingHud.OWNER_ATTACHMENT =',1,true))
local finish=assert(source:find('FloatingHud.statusAttachmentStates =',start,true))
local hs=assert(source:find('function FloatingHud.rectanglesHit(',1,true))
local he=assert(source:find('\nend',hs,true))+4
local selected='corners'
local H={STATUS_SCALE=1,GAP=5,safeInsets=function()return 0,0,0,0 end}
local env=setmetatable({FloatingHud=H,isAscendantHost=true,OverworldBattle={},
 plateSize=function()return 220,60 end,uiScale=function()return 1 end,
 clamp=function(v,a,b)return math.max(a,math.min(b,v))end,
 optionChoice=function(k,default)return k=='status_anchor' and (selected or default)or default end,
},{__index=_G})
local chunk=assert(loadstring(source:sub(hs,he)..'\n'..source:sub(start,finish-1)))
setfenv(chunk,env);chunk()
for _,size in ipairs({{1000,600},{720,1280},{640,480}})do
 local shot={pw=size[1],ph=size[2],actorVisuals={}}
 local initial={}
 for frame=0,20 do
  for i,side in ipairs({'player','enemy'})do
   local x=shot.pw*(.3+i*.1)+frame*2
   shot.actorVisuals[side]={head={x=x,y=shot.ph*.5},hull={x-12,shot.ph*.5,24,50}}
  end
  for _,side in ipairs({'player','enemy'})do
   local rect=assert(H.projectOwnerStatusRect(shot,side))
   if initial[side]then for j=1,4 do assert(rect[j]==initial[side][j],'corner drift during camera motion')end end
   initial[side]=rect
  end
 end
 -- Keep the optional actor-relative presentation responsive.
 selected='outside'
 local before=H.projectOwnerStatusRect(shot,'player')
 shot.actorVisuals.player.head.x=shot.actorVisuals.player.head.x+15
 local after=H.projectOwnerStatusRect(shot,'player')
 assert(before[1]~=after[1],'explicit actor-following mode lost')
 selected='corners'
end
-- Corner preference still yields when a Pokemon would be covered.
local shot={pw=1000,ph=600,actorVisuals={player={head={x=100,y=30},hull={10,10,220,80}}}}
local rect=assert(H.projectOwnerStatusRect(shot,'player'))
assert(not H.rectanglesHit(rect,shot.actorVisuals.player.hull,8),'corner HUD covers actor')
-- Stable reference pose is independent of every live wing/head movement.
for _,mode in ipairs({'outside','above'})do
 selected=mode
 for _,size in ipairs({{1000,600},{720,1280},{640,480}})do
  local shot={pw=size[1],ph=size[2],actorVisuals={}}
  local first
  for frame=0,30 do
   local x,y=size[1]*.55,size[2]*.6
   shot.actorVisuals.player={head={x=x+math.sin(frame)*3,y=y-math.sin(frame)*3},hull={x-8,y-math.sin(frame)*3,16,30+math.sin(frame)*3},
    hudHead={x=x,y=y},hudHull={x-8,y,16,30}}
   local rect=H.projectOwnerStatusRect(shot,'player')
   if first then for i=1,4 do assert(rect[i]==first[i],'HUD inherited pose '..mode)end end
   first=rect
  end
  shot.actorVisuals.player.hudHead.x=shot.actorVisuals.player.hudHead.x+10
  shot.actorVisuals.player.hudHull[1]=shot.actorVisuals.player.hudHull[1]+10
  local moved=H.projectOwnerStatusRect(shot,'player')
  assert(moved[1]~=first[1],'reference did not follow camera')
 end
end
-- A seat moved by collision avoidance must not return towards the wing on
-- the next frame. It keeps its resolved offset until camera/owner changes.
local rs=assert(source:find('function FloatingHud.statusSlotFromVisual(',1,true))
local re=assert(source:find('function FloatingHud.rectanglesHit(',rs,true))
local refresh=assert(loadstring(source:sub(rs,re-1)));setfenv(refresh,env);refresh()
selected='outside'
local visual={battler={},mon={},hudHead={x=500,y=300},hudHull={480,300,40,60},head={x=510,y=290},hull={480,290,40,70}}
local shot={pw=1000,ph=600,actorVisuals={player=visual}}
local old=H.statusSlotFromVisual(shot,'player',visual)
old.rect[1]=old.rect[1]-45;old.rect[2]=old.rect[2]-20
local still=H.refreshStatusSlot(old,visual,shot,'player')
assert(still.rect[1]==old.rect[1] and still.rect[2]==old.rect[2],'resolved seat snapped back')
visual.hudHead.x=visual.hudHead.x+12
local moved=H.refreshStatusSlot(still,visual,shot,'player')
assert(moved.rect[1]==still.rect[1]+12,'resolved seat ignored camera')
visual.mon={};assert(H.refreshStatusSlot(old,visual,shot,'player')==nil,'switch inherited old seat')
print('PASS_STABLE_POSE_HUD_DEFAULT_OUTSIDE_CORNERS_OPTIONAL_CAMERA_AND_COLLISION')
