-- Ascendant-authored conservative clips for rigs whose procedural Cobblemon
-- poser cannot be evaluated here. Original valid clips always take precedence.
local M={}
function M.complete(model,names,G)
 local root=model.boneNames[2];if not root then return end
 local limbs={};for name in pairs(names)do
  local n=name:lower()
  if n:find('leg') or n:find('foot') or n:find('wing') or n=='arm_left' or n=='arm_right'then limbs[#limbs+1]=name end
 end;table.sort(limbs)
 local function add(action,seconds,bones,loop)
  if model.actions[action]then return end
  local clip=G.clip({animation_length=seconds,loop=loop~=false,bones=bones},names)
  model.anims[#model.anims+1]=clip;model.actions[action]=#model.anims
  model.actionSources=model.actionSources or {};model.actionSources[action]='vasc'
  model.authoredActions=model.authoredActions or {};model.authoredActions[#model.authoredActions+1]=action
 end
 local idle={[root]={position={0,'math.sin(q.anim_time * 180) * 0.18',0}}}
 add('idle',2,idle);add('battle',2,idle)
 local walk={[root]={position={0,'math.abs(math.sin(q.anim_time * 360)) * 0.35',0}}}
 for i,name in ipairs(limbs)do walk[name]={rotation={'math.sin(q.anim_time * 360) * '..(i%2==0 and '12' or '-12'),0,0}}end
 add('walk',1,walk)
 add('attack_default',.6,{[root]={rotation={['0']={0,0,0},['0.2']={-9,0,0},['0.35']={12,0,0},['0.6']={0,0,0}}}},false)
 add('flinch',.4,{[root]={rotation={['0']={0,0,0},['0.12']={-6,0,0},['0.4']={0,0,0}}}},false)
 add('faint',.8,{[root]={rotation={['0']={0,0,0},['0.8']={0,0,75}}}},false)
end
return M
