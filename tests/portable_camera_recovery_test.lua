local f=assert(io.open('lib/BattleCam.lua'));local source=f:read('*a');f:close()
local a=assert(source:find('local function renderedPortableFrameRescue',1,true))
local b=assert(source:find('-- Definitive provider-neutral safety gate',a,true))
local fn=assert(loadstring(source:sub(a,b-1)..'return renderedPortableFrameRescue'))
local calls=0;local battle={};local arena={discs=true,player={1,2},enemy={3,4}}
local camera={eye={0,20,100},focus={0,0,0},fov=.8}
local env={activeBattle=battle,sameScreenOwner=function()return false end,copyCamera=function(c)return{eye={unpack(c.eye)},focus={unpack(c.focus)},fov=c.fov}end,
 screenSafeCamera=function(owner,stage,y,c,context)
  assert(owner==battle and stage==arena and context.actual)
  calls=calls+1;return math.abs(c.eye[1])>20 and c.fov>.9
 end}
setfenv(fn,setmetatable(env,{__index=_G}));local recover=fn()
assert(not recover({},0,camera,.5,{}))
assert(not recover(arena,0,camera,.5,{manual=true}));assert(calls==0)
local result=assert(recover(arena,0,camera,.5,{}));assert(calls>1)
assert(camera.eye[1]==0 and camera.fov==.8 and arena.player[1]==1 and arena.enemy[1]==3,'camera search moved live actors/platforms')
assert(env.lastScreenSafe.battle==battle and env.lastScreenSafe.arena==arena)
env.screenSafeCamera=function()return false end
assert(not recover(arena,0,camera,.5,{}),'unsafe camera accepted')
print('Portable camera recovery: ok')

local painted={arenaStyle={}};local seen=false
env.screenSafeCamera=function(_,stage,_,c)assert(stage==painted);assert(c.eye[1]==0,'bitmap recovery rotated the view');seen=true;return c.fov>.9 end
assert(recover(painted,0,camera,.5,{}));assert(seen)

-- Narrow portrait displays may need more than the former 1.75x lens while
-- keeping both platform anchors fixed. A painted composition retains its cap.
env.screenSafeCamera=function(_,stage,_,c)
  local factor=math.tan(c.fov*.5)/math.tan(camera.fov*.5)
  return factor>1.9
end
assert(recover(arena,0,camera,.5,{}),'portrait platform lens stayed capped at 1.75x')
assert(not recover(painted,0,camera,.5,{}),'authored bitmap optical limit changed')
print('Portrait platform optical recovery: ok')
