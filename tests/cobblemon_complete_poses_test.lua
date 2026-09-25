local V={};local cache={}
function V.require(n)if not cache[n]then cache[n]=assert(loadfile('lib/'..n..'.lua'))(V)end;return cache[n]end
local G=V.require('CobblemonGeometry');local Motion=V.require('CobblemonMotion')
local function equal(a,b)
 for i,row in ipairs(a)do for j,x in ipairs(row)do assert(math.abs(x-b[i][j])<1e-7,'pose discontinuity')end end
end
local function copy(p)local out={};for i,row in ipairs(p)do out[i]={unpack(row)}end;return out end
for _,case in ipairs({{'body',{}},{'legged',{'leg_left','leg_right'}},{'quadruped',{'leg_front_left','leg_front_right','leg_back_left','leg_back_right'}},{'winged',{'wing_left','wing_right'}},{'finned',{'fin_left','fin_right'}}})do
 local bones={{name='body',pivot={0,0,0},cubes={{origin={-2,0,-2},size={4,8,4},uv={0,0}}}}, {name='eye',parent='body',pivot={0,6,0}}, {name='tail',parent='body',pivot={0,2,1}}, {name='tail_tip',parent='tail',pivot={0,2,2}}}
 for _,name in ipairs(case[2])do bones[#bones+1]={name=name,parent='body',pivot={0,2,0}}end
 local m,names=G.build({['minecraft:geometry']={{description={texture_width=16,texture_height=16},bones=bones}}},1)
 local original=G.clip({animation_length=2,loop=true,bones={body={rotation={12,0,0}},eye={scale={0,0,0}}}},names)
 m.anims={original};m.actions={idle=1};m.actionSources={idle='cobblemon'}
 local before=copy(G.sample(m,1,0,false));Motion.complete(m,names,G)
 assert(m.motionProfile.kind==case[1]);assert(#m.motionProfile.tails==1,'nested tails double-transformed')
 assert(m.anims[1]==original and m.actionSources.idle=='cobblemon','original animation replaced')
 local slots={}
 for _,action in ipairs(Motion.REQUIRED)do
  local index=assert(m.actions[action]);assert(not slots[index],'different generated actions share generic slot');slots[index]=true
  local c=m.anims[index]
  if action~='idle' then
   assert(m.actionSources[action]=='vasc');equal(before,G.sample(m,index,0,false))
   if action~='faint' then equal(before,G.sample(m,index,c.seconds*30,false))end
   if action~='battle' and action~='walk' then assert(not c.loop,'one-shot accidentally loops')end
  end
  for _,time in ipairs({.07,.17,.35,.53,.79,1,1.4})do
   local out=G.sample(m,index,c.seconds*30*time,false)
   assert(out[names.eye][7]==0,'fallback exposed hidden facial geometry')
  end
 end
 local n=#m.anims;Motion.complete(m,names,G);assert(#m.anims==n,'completion duplicated clips')
end
print('PASS five rig profiles, all ten actions, distinct slots, preserved idle stance/hidden geometry, continuous one-shots and idempotence')
