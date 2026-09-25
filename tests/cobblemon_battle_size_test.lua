local Size=assert(loadfile('lib/CobblemonSize.lua'))()
local calls=0
local function fitted(dex,bindH,poseH,poseW,root,meters)
 local model={height=bindH,radius=poseW/2,rootScale=root or 1,actions={battle=1},anims={{seconds=2}}}
 local rig={pose=function()calls=calls+1 end,posedBounds=function()return 0,0,0,poseW,poseH,poseW*.8 end}
 Size.prepare(model,rig)
 local count=calls;Size.prepare(model,rig);assert(calls==count,'repeated calibration')
 local scale=(root or 1)*Size.worldHeight(dex,model,meters)/model.height
 return poseH*scale,poseW*scale
end
-- Both reported species fit their Crystal silhouette, on both world axes.
local species={252,1026,9999}
for dex=1,251 do species[#species+1]=dex end
for _,dex in ipairs(species) do
 local width,height=Size.reference(dex)
 for _,pose in ipairs({{20,10},{10,40},{40,40}})do
  local h,w=fitted(dex,30,pose[1],pose[2],1,.4)
  assert(h<=height+1e-8 and w<=width+1e-8,'Crystal envelope exceeded: '..dex)
  assert(math.abs(h/pose[1]-w/pose[2])<1e-8,'model stretched')
  local H,W=fitted(dex,300,pose[1]*10,pose[2]*10,.25,10)
  assert(math.abs(H-h)<1e-8 and math.abs(W-w)<1e-8,'authored units/root/metadata change size')
 end
end
local eggs=fitted(102,20,10,40)
local bellsprout=fitted(69,30,40,20)
assert(eggs<5 and bellsprout<12,'reported small models remain trainer-sized')
local fallback=Size.worldHeight(69,nil)
assert(fallback>0 and fallback<12)
print('PASS: Crystal bounds, Bellsprout/Exeggcute, uniform fit, unit independence and caching')
