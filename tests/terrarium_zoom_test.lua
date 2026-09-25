local settings={}
local V={require=function(name)
  assert(name=='ModSetting',name)
  return {new=function(key,label,values,labels,default)
    local s={value=default,get=function(self)return self.value end}
    settings[key]=s;return s
  end}
end}
local C=assert(loadfile('lib/BattleCam.lua'))(V)
local S=assert(loadfile('integrated/terarrium/Terarrium.lua'))()({})
local arena={terarrium={},terarriumService=S,mid={20,30},discs=true}
local battle={phase='menu'}
local function tick()C.update(.2,arena,battle,7)end
local function equalPose(a,b)
  for _,key in ipairs{'eye','focus','up'}do
    for i=1,3 do assert(a[key][i]==b[key][i],key..' moved')end
  end
  assert(a.curve==b.curve)
end
tick()
local baseline,pitch=C.rig(arena,7)
local original=select(1,S.camera(arena,7))
assert(baseline.fov==original.fov and C.frameH(arena)==204)
assert(C.stepZoom(-2,arena));tick()
local close,angle=C.rig(arena,7)
equalPose(baseline,close);assert(pitch==angle and close.fov<baseline.fov)
assert(math.abs(math.tan(close.fov/2)/math.tan(baseline.fov/2)
  -C.frameH(arena)/204)<1e-12,'lens and light framing disagree')
local held=close.fov;battle.phase='moves';tick();assert(C.rig(arena,7).fov==held)
settings.battleCameraDistance.value=3;tick()
assert(C.rig(arena,7).fov==held,'MAP distance overwrote Terrarium lens')
C.orbit,C.orbitGoal,C.pitch,C.pitchGoal=1,1,1,1;tick()
equalPose(baseline,C.rig(arena,7))
assert(C.rig(arena,7,true).fov==baseline.fov,'canonical probe zoomed')
C.still=true;assert(not C.stepZoom(-1,arena));tick()
assert(C.rig(arena,7).fov==baseline.fov and C.frameH(arena)==204)
C.still=false
assert(C.stepZoom(100,arena));tick();assert(C.terrariumZoom==C.ZOOM_MAX)
assert(not C.stepZoom(1,arena));equalPose(baseline,C.rig(arena,7))
assert(C.stepZoom(-100,arena));tick();assert(C.terrariumZoom==C.ZOOM_MIN)
assert(not C.stepZoom(-1,arena));equalPose(baseline,C.rig(arena,7))
local serviceCamera=S.camera
local shared=select(1,serviceCamera(arena,7));S.camera=function()return shared,pitch end
local result=C.rig(arena,7)
assert(result~=shared and shared.fov==baseline.fov,'mutated service camera')
S.camera=serviceCamera
-- Changing the layout of this battle retains zoom; a new battle resets it.
arena={terarrium={},terarriumService=S,mid={20,30},discs=true};tick()
assert(C.terrariumZoom==C.ZOOM_MIN)
battle={phase='menu'};tick();assert(C.terrariumZoom==1 and C.terrariumZoomGoal==1)
C.stepZoom(-1,arena);C.reset();assert(C.terrariumZoom==1 and C.terrariumZoomGoal==1)
-- Exercise the existing unified input routing with the actual camera module.
local live=true
local modules={BattleCam=C,OverworldBattle={shot=function()return live and {}end,arena=function()return arena end},
  VoxelState={active=function()return false end},Voxel3D={},FirstPerson={},ThirdPerson={}}
local controls=assert(loadfile('lib/CamControl.lua'))({require=function(n)return assert(modules[n],n)end})
tick();assert(controls.zoomBy(-1));tick();assert(C.terrariumZoom<1)
local before=C.terrariumZoomGoal
assert(controls.pinchBy(1.25));tick();assert(C.terrariumZoom<before)
equalPose(baseline,C.rig(arena,7))
assert(controls.pinchBy(.5));tick();assert(C.terrariumZoom>before)
live=false;assert(not controls.pinchBy(1.25) and not controls.zoomBy(-1))
print('PASS Terrarium optical zoom: fixed pose, pinch/steps, framing, limits, lifetime, canonical/VR, shared camera and MAP preference isolation')
