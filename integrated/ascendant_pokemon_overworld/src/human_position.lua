-- Fractional human presentation; native simulation coordinates stay untouched.
local M={}
local function finite(v)return type(v)=='number' and v==v and math.abs(v)<math.huge end
function M.fraction(clock)
 if type(clock)~='table' or not finite(clock.accum) or not finite(clock.STEP) or clock.STEP<=0 then return end
 return math.max(0,math.min(1,clock.accum/clock.STEP))
end
function M.project(actor,pose,alpha,generation)
 if type(actor)~='table' or type(pose)~='table' or not finite(alpha) or alpha<0 or alpha>1 then return end
 if not actor.moving or actor.frozen or actor.inputLocked or actor.scriptedMoving
  or actor.jumping or actor.hopping or actor.hopStep or actor.marching
  or actor.teleport or actor.treeShake or actor.rockSmash or actor.bouncing
  or actor.onBike or actor.surfing or (pose.lift or 0)~=0 then return end
 local def=pose.sprite and pose.sprite.def
 if not def or def.ascendantCharacterAction~=nil or def.ascendantPokemonDex or def.pokemonDex then return end
 for _,key in ipairs({'cellX','cellY','targetX','targetY','progress','px','py'})do if not finite(actor[key])then return end end
 if pose.px~=actor.px or pose.py~=actor.py then return end
 local dx,dy=actor.targetX-actor.cellX,actor.targetY-actor.cellY
 if math.abs(dx)+math.abs(dy)~=1 then return end
 local facing=dx==1 and 'right' or dx==-1 and 'left' or dy==1 and 'down' or 'up'
 if actor.facing~=facing then return end
 local frames
 if generation==1 then frames=(pose.isPlayer and actor.stepFramesCur) or actor.stepFrames or (pose.isPlayer and 16 or 32)
 elseif generation==2 then frames=actor.stepFrames or 16
 else return end
 if not finite(frames) or frames<16 or frames>64 or frames%1~=0
  or actor.progress<0 or actor.progress>=frames or actor.progress%1~=0 then return end
 local advance=math.floor(actor.progress*16/frames)
 if actor.px~=actor.cellX*16+dx*advance or actor.py~=actor.cellY*16+dy*advance then return end
 -- Gen1 updates a newly started player step before its first draw (progress
 -- 1); Gen2 and NPCs expose progress 0. Map the Gen1 player's remaining
 -- intervals onto the full cell so onset starts at alpha and the final
 -- interval still reaches the native landing, without a stop-time snap.
 local progress,duration=actor.progress+alpha,frames
 if generation==1 and pose.isPlayer then
  progress=math.max(0,progress-1);duration=frames-1
 end
 local t=math.min(1,progress/duration)
 return actor.cellX*16+dx*16*t,actor.cellY*16+dy*16*t
end
-- Captured poses may be queried more than once. Restore only coordinates
-- still owned by this layer before recomputing or switching it off.
function M.apply(poses,options)
 local count=0
 for _,pose in ipairs(poses or {})do
  local previous=pose.ascendantHumanPosition
  if type(previous)=="table" and pose.px==previous.x and pose.py==previous.y then
   pose.px,pose.py=previous.nativeX,previous.nativeY
  end
  pose.ascendantHumanPosition=nil
  if options.enabled==true and pose.mapId==options.mapId
    and options.ready(pose)==true then
   local x,y=M.project(pose.entity,pose,options.alpha,options.generation)
   if x then
    local nativeX,nativeY=pose.px,pose.py
    pose.ascendantHumanPosition={nativeX=nativeX,nativeY=nativeY,x=x,y=y,
     cameraX=pose.isPlayer and x-nativeX or 0,cameraY=pose.isPlayer and y-nativeY or 0}
    pose.px,pose.py=x,y;count=count+1
   end
  end
 end
 return count
end
return M
