local root=assert(arg[1])
local noop=function()end
local shot,arena,smart={liveWorld=false},{},true
local axisX,axisY=0,0
local zoom,looks,forward=1,0,0
love={graphics={getDimensions=function()return 480,900 end,getWidth=function()return 480 end,getHeight=function()return 900 end},system={getOS=function()return 'iOS'end}}
package.loaded['src.core.TouchControls']={hitTest=function()return nil end}
local cinematic={ownsCamera=function()return smart end,manualLook=function()looks=looks+1 end,reset=function()zoom=1 end,stepZoom=function(n)zoom=zoom*1.12^n;return true end,scaleZoom=function(f)zoom=zoom*f;return true end}
local modules={VoxelState={active=function()return false end},Voxel3D={},FirstPerson={stickX=function()return axisX end,stickY=function()return axisY end},ThirdPerson={},DioramaZoom={},BattleCam={steerable=true},BattleCinematic=cinematic,OverworldBattle={shot=function()return shot end,arena=function()return arena end}}
local V={require=function(k)return assert(modules[k],k)end,mod={}}
modules.Gen2Terrarium=assert(loadfile(root..'/gen2/lib/Gen2Terrarium.lua'))(V)
local control=assert(loadfile(root..'/gen2/lib/CamControl.lua'))(V)
local game=setmetatable({},{__index=function()return function()forward=forward+1 end end})
control.install(game)
for _,live in ipairs({false,true})do
 shot.liveWorld=live
 assert(control.zoomTarget()=='cinematic')
 zoom=1;game:wheelmoved(0,1);assert(zoom<1)
 game:gamepadpressed(nil,'leftstick');assert(math.abs(zoom-1)<1e-8)
 local previous=looks;axisX=.5;control.tick(.02);axisX=0;assert(looks>previous)
 game:touchpressed('finger',300,300);game:touchmoved('finger',340,330);game:touchreleased('finger',340,330);assert(looks>previous+1)
end
local t=modules.Gen2Terrarium
arena.terarrium={};arena.terarriumService={camera=function()return {eye={0,157,205},focus={0,-12,0},up={0,1,0},fov=.7}end}
assert(control.zoomTarget()=='terrarium')
local first=t.camera(arena,0);game:wheelmoved(0,1);assert(t.camera(arena,0).fov<first.fov)
assert(control.pinchBy(1.3));assert(t.zoom<1)
control.recentre();assert(t.zoom==1 and t.yaw==0)
game:touchpressed('finger',300,300);game:touchmoved('finger',350,310);game:touchreleased('finger',350,310)
local rotated=t.camera(arena,0);assert(math.abs(rotated.eye[1]-first.eye[1])>1)
assert(t.scaleZoom(999) and t.zoom==3);assert(t.scaleZoom(.00001)and t.zoom==.45)
assert(not t.scaleZoom(0) and not t.scaleZoom(0/0))
local sum=0;for _,v in ipairs(rotated.up)do sum=sum+v*v end;assert(math.abs(sum-1)<1e-8)
shot=nil;local before=forward;game:wheelmoved(0,1);assert(forward==before+1,'non-battle input forwarded')
print('PASS Gen2 visible camera routing: MAP, portable, Terrarium; wheel, pad, touch, pinch, reset and passthrough')
