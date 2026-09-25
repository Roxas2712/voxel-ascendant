-- Rig-aware VASC motions fill unsupported/missing Cobblemon actions at build
-- time. Existing original clips are never replaced. No per-frame discovery.
local M={}
M.REQUIRED={'idle','battle','walk','entrance','attack_default','attack_physical','attack_special','attack_status','flinch','faint'}
local function members(model,names,pattern)
 local candidates={}
 for name,index in pairs(names)do
  local n=name:lower()
  if not n:find('#',1,true) and not n:find('locator',1,true) and n:match(pattern)then candidates[index]=name end
 end
 local result={}
 for index,name in pairs(candidates)do
  local parent=model.parent[index];local nested=false
  while parent and parent>0 do
   if candidates[parent]then nested=true;break end
   parent=model.parent[parent]
  end
  if not nested then result[#result+1]=name end
 end
 table.sort(result);return result
end
local function keyframes(seconds,peak,finish)
 return {['0']={0,0,0},[tostring(seconds*.35)]=peak,[tostring(seconds)]=finish or {0,0,0}}
end
function M.complete(model,names,G)
 local root=names.__vasc_root and '__vasc_root' or model.boneNames[2]
 assert(root and names[root],'model has no motion root')
 local legs=members(model,names,'^leg');local wings=members(model,names,'^wing')
 local fins=members(model,names,'^fin');local tails=members(model,names,'^tail')
 local profile=#wings>0 and 'winged' or #legs>=4 and 'quadruped'
  or #legs>0 and 'legged' or #fins>0 and 'finned' or 'body'
 model.motionProfile={revision=1,kind=profile,root=root,legs=legs,wings=wings,fins=fins,tails=tails}
 -- Conservative displacement based on the mesh's local vertical span. Bound
 -- it so tiny and very large rigs cannot acquire an extreme generic lunge.
 local low,high=math.huge,-math.huge
 for _,p in ipairs(model.prims or {})do for _,y in ipairs(p.py or {})do low=math.min(low,y);high=math.max(high,y)end end
 local step=high>low and math.max(.12,math.min(.8,(high-low)*.025)) or .25
 local baseline
 local function add(action,seconds,bones,loop,keepPose)
  if model.actions[action]then return end
  local clip=G.clip({animation_length=seconds,loop=loop==true,bones=bones},names)
  assert(next(clip.channels),'empty generated motion: '..action)
  if keepPose and baseline then
   clip={seconds=seconds,frames=1,channels={},loop=loop==true,layers={baseline,clip}}
  end
  model.anims[#model.anims+1]=clip;model.actions[action]=#model.anims
  model.actionSources=model.actionSources or {};model.actionSources[action]='vasc'
  model.authoredActions=model.authoredActions or {};model.authoredActions[#model.authoredActions+1]=action
 end
 add('idle',2,{[root]={position={0,'math.sin(q.anim_time * 180) * '..tostring(step*.4),0}}},true)
 -- Keep each species' supported idle stance, including hidden facial meshes,
 -- when adding whole-body actions. Starting a fallback must not expose a
 -- bind-pose mouth/eyelid or unfold a rig into its modelling pose.
 local pose=G.sample(model,model.actions.idle,0,false);local bones={}
 for i,row in ipairs(pose)do
  local o=(i-1)*3;local pos,rot,scale={},{},{};local changed=false
  for a=1,3 do
   pos[a]=row[a]-model.restT[o+a]
   rot[a]=(row[a+3]-model.restR[o+a])*180/32768*(a==2 and 1 or -1)
   scale[a]=model.restS[o+a]~=0 and row[a+6]/model.restS[o+a] or 1
   changed=changed or math.abs(pos[a])>1e-9 or math.abs(rot[a])>1e-9 or math.abs(scale[a]-1)>1e-9
  end
  if changed then bones[model.boneNames[i]]={position=pos,rotation=rot,scale=scale}end
 end
 baseline=G.clip({animation_length=1,bones=bones},names)
 add('battle',2,{[root]={position={0,'math.sin(q.anim_time * 180) * '..tostring(step*.3),0}}},true,true)
 local walk={[root]={position={0,'math.abs(math.sin(q.anim_time * 360)) * '..tostring(step),0}}}
 local moving=#wings>0 and wings or #legs>0 and legs or #fins>0 and fins or tails
 for i,name in ipairs(moving)do
  local n=name:lower();local sign=n:find('right',1,true) and -1 or n:find('left',1,true) and 1 or (i%2==0 and -1 or 1)
  walk[name]={rotation={0,0,0}}
  walk[name].rotation[profile=='winged' and 3 or profile=='finned' and 2 or 1]='math.sin(q.anim_time * 360) * '..tostring(sign*(profile=='winged' and 8 or 10))
 end
 add('walk',1,walk,true,true)
 add('entrance',.8,{[root]={position=keyframes(.8,{0,step*2,0}),rotation=keyframes(.8,{-5,0,0})}},false,true)
 add('attack_default',.6,{[root]={rotation=keyframes(.6,{-9,0,0})}},false,true)
 add('attack_physical',.65,{[root]={position=keyframes(.65,{0,0,-step*2}),rotation=keyframes(.65,{profile=='winged' and -8 or -12,0,0})}},false,true)
 add('attack_special',.9,{[root]={position=keyframes(.9,{0,step,step*.5}),rotation=keyframes(.9,{7,0,0})}},false,true)
 add('attack_status',1,{[root]={position=keyframes(1,{0,step*.5,0}),rotation={['0']={0,0,0},['0.25']={0,-7,0},['0.65']={0,7,0},['1']={0,0,0}}}},false,true)
 add('flinch',.4,{[root]={position=keyframes(.4,{0,0,step}),rotation=keyframes(.4,{-6,0,-4})}},false,true)
 local fall=profile=='body' or profile=='finned'
 add('faint',1,{[root]={rotation=keyframes(1,{0,0,fall and 12 or 25},{0,0,fall and 35 or 65}),position=keyframes(1,{0,-step*.3,0},{0,-step,0})}},false,true)
 for _,action in ipairs(M.REQUIRED)do assert(model.actions[action],'missing action: '..action)end
 model._sample=nil
end
return M
