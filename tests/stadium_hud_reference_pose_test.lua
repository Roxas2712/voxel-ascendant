local root=assert(arg[1])
local f=assert(io.open(root..'/gen2/lib/StadiumRig.lua'));local s=f:read('*a');f:close()
local a=assert(s:find('local function finite(',1,true))
local b=assert(s:find('-- Project the lower contact band',a,true))
local Rig={};local fn=assert(loadstring(s:sub(a,b-1)))
setfenv(fn,setmetatable({StadiumRig=Rig},{__index=_G}));fn()
local I={1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}
local rows={{-.4,-.3,0},{.4,-.3,0},{0,.4,0}}
local actor=setmetatable({parts={{rows=rows}},projectionPose=1},{__index=Rig})
assert(actor:projectedHudBounds(I,1000,600)==nil)
actor:captureHudPose()
local reference={actor:projectedHudBounds(I,1000,600)}
for frame=1,60 do
  rows[3][2]=.4+math.sin(frame)*.2;rows[3][1]=math.cos(frame)*.2
  actor.projectionPose=frame+1;actor.projectionPointsValid=false;actor.projectionCache=nil
  actor:captureHudPose()
  local fixed={actor:projectedHudBounds(I,1000,600)}
  for k=1,4 do assert(fixed[k]==reference[k],'HUD inherited wing motion')end
end
local live={actor:projectedBounds(I,1000,600)}
assert(live[4]~=reference[4],'live collision hull was frozen')
I[4]=.2;local moved={actor:projectedHudBounds(I,1000,600)}
assert(math.abs(moved[1]-reference[1]-100)<1e-6,'camera translation ignored')
local resized={actor:projectedHudBounds(I,500,300)}
for k=1,4 do assert(math.abs(resized[k]*2-moved[k])<1e-6,'viewport ignored')end
local replacement=setmetatable({parts={{rows={{-.2,-.2,0},{.2,.8,0}}}}},{__index=Rig})
replacement:captureHudPose()
assert(select(2,replacement:projectedHudBounds(I,1000,600))~=reference[2],'replacement kept previous species')
print('PASS_STADIUM_HUD_REFERENCE_POSE: wing motion, live hull, camera, viewport, replacement')
