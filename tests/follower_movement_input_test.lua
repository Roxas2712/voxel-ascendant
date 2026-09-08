local engine=assert(os.getenv('GEN1RECOMP_ROOT'))
package.path=engine..'/?.lua;'..engine..'/?/init.lua;'..package.path
require('src.core.GameVersion').set('yellow')
local F=require('src.world.PikachuFollower')
local original=F.update
local held={};local driving=true;local yaw=0
local camera={driving=function()return driving end}
function camera.moveVector()
 return (held.right and 1 or 0)-(held.left and 1 or 0),
   (held.up and 1 or 0)-(held.down and 1 or 0)
end
function camera.moveWorld(x,z)
 return -math.cos(yaw)*x+math.sin(yaw)*z,math.sin(yaw)*x+math.cos(yaw)*z
end
local B=assert(loadfile('lib/FollowerMovementInput.lua'))({require=function(name)
 assert(name=='FirstPerson');return camera end})
local input=setmetatable({}, {__index={isDown=function(_,key)return held[key]==true end}})
local function fixture(direction)
 local delta={left={-1,0},right={1,0},up={0,-1},down={0,1}}
 local d=delta[direction]
 local npc={pikachuFollower=true,cellX=10+d[1],cellY=10+d[2],moving=true}
 local ow={player={cellX=10,cellY=10,facing='down'},npcs={npc},
  pikachuTrail={x=10,y=10},pikachuTurnArmed=true,scriptMoves={}}
 local game={input=input,data={sprites={SPRITE_PIKACHU={}}},save={
  flags={EVENT_GOT_STARTER=true,EVENT_BATTLED_RIVAL_IN_OAKS_LAB=true},
  party={{species='PIKACHU',hp=1}}}}
 return game,ow,npc
end
-- Existing native counter cannot resolve a camera-relative reverse press.
held={right=true};yaw=0
local g,ow,n=fixture('left')
for _=1,12 do original(g,ow)end
assert(not n.passable and ow.pikachuCollisionCounter==8,'baseline must reproduce blocked follower')
B.install();local wrapper=F.update;B.install();assert(F.update==wrapper,'duplicate install')
for _,angle in ipairs({0,math.pi/2,math.pi,3*math.pi/2})do
 yaw=angle
 for _,key in ipairs({'up','down','left','right'})do
  held={[key]=true};local wx,wz=camera.moveWorld(camera.moveVector())
  local dir=math.abs(wx)>math.abs(wz) and (wx>0 and 'right' or 'left')
    or (wz>0 and 'down' or 'up')
  g,ow,n=fixture(dir)
  for _=1,12 do F.update(g,ow)end
  assert(n.passable and ow.pikachuCollisionCounter==0,'camera direction failed '..angle..' '..key)
  assert(ow.player.facing=='down' and rawget(input,'isDown')==nil,'input/facing leaked')
 end
end
-- Grid movement and scripted walking retain their native input behavior.
driving=false;held={right=true};yaw=0;g,ow,n=fixture('left')
for _=1,12 do F.update(g,ow)end
assert(not n.passable and ow.pikachuCollisionCounter==8)
driving=true;g,ow,n=fixture('left');ow.scriptMoves={{}}
for _=1,12 do F.update(g,ow)end
assert(not n.passable and ow.pikachuCollisionCounter==8)
-- B still passes through to the native follower owner.
g,ow,n=fixture('left');held={b=true};F.update(g,ow);assert(n.passable)
-- Story-owned follower scenes keep their collision protection.
g,ow,n=fixture('left');ow.pikachuBillsScene=true;held={right=true,b=true}
F.update(g,ow);assert(not n.passable,'story follower protection bypassed')
assert(rawget(input,'isDown')==nil and ow.player.facing=='down')
-- A companion can wrap the bridge after installation; reinstallation must
-- not rotate the input twice, and exceptions must restore shared state.
local prior=F.update
F.update=function(...)prior(...);error('owner failure')end
B.install();g,ow,n=fixture('left');held={right=true}
local ok,err=pcall(F.update,g,ow)
assert(not ok and tostring(err):find('owner failure',1,true))
assert(rawget(input,'isDown')==nil and ow.player.facing=='down')
assert(not F.__vascWorldInputBridge.active and input:isDown('right'))
print('follower world input: native counter baseline, 16 directions, grid/script guards, B, reload and error cleanup PASS')
