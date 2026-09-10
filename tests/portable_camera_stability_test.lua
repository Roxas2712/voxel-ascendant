-- Exercise the real frame-to-frame rig: the recovery helper alone cannot
-- catch the next narrow idle pose undoing a verified wide composition.
local setting={new=function(_,_,_,_,default)
 return {value=default,get=function(self)return self.value end}
end}
local cam=assert(loadfile('lib/BattleCam.lua'))({require=function(name)
 if name=='ModSetting' then return setting end
 error('unexpected dependency '..name)
end})
local arena={discs=true,mid={0,0},player={-16,16},enemy={16,-16}}
local battle={};local wide=false;local checks=0;local requiredFov=.8
local function evaluator(_,_,_,camera)
 checks=checks+1;return not wide or camera.fov>=requiredFov,'pose-bounds'
end
cam.setScreenSafetyEvaluator(evaluator);cam.update(0,arena,battle,0)
local ordinary=assert(cam.rig(arena,0))
wide=true;local recovered=assert(cam.rig(arena,0));wide=false
assert(recovered.fov>ordinary.fov,'fixture did not require recovery')
assert(cam.rig(arena,0).fov>=recovered.fov-1e-9,'narrow idle pose undid optical recovery')
for i=1,120 do
 wide=i%2==0;cam.update(1/60,arena,battle,0)
 assert(cam.rig(arena,0).fov>=recovered.fov-1e-9,'alternating poses caused camera pumping')
end
assert(checks>=123,'held lens bypassed current safety evaluation')
-- A later larger pose must search from the authored rig, not multiply the
-- previous recovery again and unnecessarily shrink both battlers.
requiredFov=.94;wide=true
local larger=assert(cam.rig(arena,0))
assert(larger.fov>=.94 and larger.fov<1.0,'repeated recovery compounded the lens')
recovered=larger;requiredFov=.8
assert(cam.distanceSetting:get()==3 and cam.zoomGoal==3,'recovery changed saved/manual zoom')
wide=false;cam.noteViewport(600,1300);cam.noteViewport(1300,600)
assert(cam.rig(arena,0).fov<recovered.fov,'resize retained portrait floor')
local function recover()
 wide=true;assert(cam.rig(arena,0));wide=false
end
recover();cam.setScreenSafetyEvaluator(evaluator)
assert(cam.rig(arena,0).fov<recovered.fov,'HUD owner change retained floor')
recover();cam.applyDistanceSetting(true)
assert(cam.rig(arena,0).fov<recovered.fov,'explicit distance change retained floor')
recover();cam.directorManualUntil=cam.directorClock+1
assert(cam.rig(arena,0).fov<recovered.fov,'manual camera retained floor')
cam.directorManualUntil=0
recover();cam.update(0,arena,{},0)
assert(cam.rig(arena,0).fov<recovered.fov,'new battle retained floor')
recover();cam.reset();cam.update(0,arena,battle,0)
assert(cam.rig(arena,0).fov<recovered.fov,'reset retained floor')
recover();local before=cam.rig(arena,0);cam.update(.5,arena,battle,0);local after=cam.rig(arena,0)
assert(before.eye[1]~=after.eye[1] or before.eye[3]~=after.eye[3],'holding lens froze camera drift')
cam.setScreenSafetyEvaluator(function()return false,'blocked'end)
assert(cam.rig(arena,0)==nil,'unsafe camera was published')
print('Portable camera pose stability and invalidation: ok')
