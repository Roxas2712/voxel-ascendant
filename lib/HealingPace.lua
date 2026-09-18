-- Hold each loaded party slot long enough to see its ball and portrait.
local V=...
local H={BALL_FRAMES=60,NATIVE_BALL_FRAMES=30}
function H.wrap(step,enabled)
 local held=setmetatable({}, {__mode='k'})
 return function(ha,...)
  local active=enabled() and ha and (ha.phase==nil or ha.phase=='balls')
    and (tonumber(ha.lit)or 0)>0
  if active then
   local record=held[ha]
   if not record or record.lit~=ha.lit then record={lit=ha.lit,frames=0};held[ha]=record end
   if record.frames<H.BALL_FRAMES-H.NATIVE_BALL_FRAMES then
    record.frames=record.frames+1
    return -- engine timer and ball event stay untouched during this hold
   end
  elseif ha then held[ha]=nil end
  return step(ha,...)
 end
end
function H.install()
 local OW=require('src.world.OverworldController')
 if OW._vascHealingPace or type(OW.stepHealAnim)~='function' then return false end
 OW.stepHealAnim=H.wrap(OW.stepHealAnim,function()
  return (require('src.render.Pipelines').level('voxel') or 0)>0
    and V.require('VoxelItems').setting:get()==true
 end)
 OW._vascHealingPace=true
 return true
end
return H
