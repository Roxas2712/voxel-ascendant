local root=arg[1]or'.'
for _,path in ipairs({'lib/FirstPerson.lua','gen2/lib/FirstPerson.lua'})do
 local held,axis={}, {x=0,y=0}
 local TC={held={},touches={}}
 function TC:layout()return{dpad={cx=80,cy=300,w=100}}end
 function TC:hitTest(x)return x<160 and'dpad'or nil end
 function TC:reset()self.held={};self.touches={};self.dpadTouch=nil;held={}end
 local world={player={facing='down'}}
 local Game={input={stickAxis=axis,isDown=function(_,k)return held[k]end},overworld=world,
  stack={top=function()return world end},touchControls=TC}
 local function noop()end
 for _,k in ipairs({'gamepadaxis','joystickaxis','focus','joystickremoved','cancelPointers'})do Game[k]=noop end
 function Game:touchpressed(id,x,y)if TC:hitTest(x,y)then TC.dpadTouch=id;TC.touches[id]={control='dpad'};TC.held.up=1;held.up=true end end
 Game.touchmoved=noop
 function Game:touchreleased()TC:reset()end
 package.loaded['src.core.Game']=Game;package.loaded['src.core.TouchControls']=TC
 package.loaded['src.core.Input']=Game.input
 love={mouse={getRelativeMode=function()return false end,setRelativeMode=noop},system={getOS=function()return'iOS'end}}
 local voxel={level=7,isFreeCam=function(l)return l==6 or l==7 end,isThirdPerson=function(l)return l==7 end,isFirstPerson=function(l)return l==6 end}
 local V={mod={hooks={wrap=noop}},require=function(n)
  if n=='VoxelState'then return voxel end
  if n=='Voxel3D'then return{available=function()return true end}end
  return{}
 end}
 local F=assert(loadfile(root..'/'..path))(V)
 -- Gen2 host adapter may use a different Game singleton; the public movement
 -- functions must still read its live touch owner through the shared core.
 F.install()
 local function near(a,b)assert(math.abs(a-b)<1e-8,tostring(a)..' ~= '..tostring(b))end
 for _,mode in ipairs({6,7})do
  voxel.level=mode
  for _,yaw in ipairs({0,math.pi/2,math.pi,3*math.pi/2})do
   F.yaw=yaw
   Game:touchpressed('thumb',80,235)
   -- Touch must beat a previous controller-axis value.
   axis.x=1;axis.y=0
   local x,z=F.moveVector();near(x,0);near(z,1)
   local wx,wz=F.moveWorld(x,z);near(wx,math.sin(yaw));near(wz,math.cos(yaw))
   axis.x=0
   TC:reset() -- menu/focus/skin change without a release callback
   x,z=F.moveVector();near(x,0);near(z,0)
   -- Custom mobile skins have directional holds but no dpadTouch.
   TC.held={right=1};axis.x=-1
   x,z=F.moveVector();near(x,1);near(z,0)
   wx,wz=F.moveWorld(x,z);near(wx,-math.cos(yaw));near(wz,math.sin(yaw))
   TC:reset();axis.x=0
  end
 end
 -- Returning the analog thumb to its centre must stop, even with a stale
 -- digital edge from the engine's just-processed event queue.
 Game:touchpressed('thumb',80,235);Game:touchmoved('thumb',80,300)
 local x,z=F.moveVector();near(x,0);near(z,0)
 Game:touchreleased('thumb',80,300);x,z=F.moveVector();near(x,0);near(z,0)
 print('PASS '..path..': first/third person, four camera bearings, analog touch, skin pad, touch priority, reset, neutral and release')
end
