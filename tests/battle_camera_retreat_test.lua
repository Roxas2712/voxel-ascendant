local file=assert(io.open('lib/BattleCam.lua'));local source=file:read('*a');file:close()
local first=assert(source:find('local function retreatActorCamera',1,true))
local last=assert(source:find('-- A phone can expose',first,true))
local chunk=assert(loadstring(source:sub(first,last-1)..'return retreatActorCamera'))
local battle,arena={}, {map={},player={1,2},enemy={3,4}}
local camera={eye={20,40,80},focus={0,0,0},fov=math.rad(135)}
local physical,calls={},0
local env={sameScreenOwner=function(r,a,b)return r and r.arena==a and r.battle==b end,activeBattle=battle,BattleCam={directorShot='test'},V={require=function(name)
 assert(name=='BattleArena');return physical
end},copyCamera=function(c)return{eye={unpack(c.eye)},focus={unpack(c.focus)},fov=c.fov}end}
local visible,pathClear=true,true
env.visibilityScore=function(a,map,stage,eye,ground,subject)
 assert(a==physical and map==arena.map and stage==arena and subject=='both')
 return 4,visible
end
env.travelClear=function(a,map,from,to)
 assert(a==physical and map==arena.map and from==camera.eye and to~=from)
 return pathClear
end
local verdict=true
env.screenSafeCamera=function(owner,stage,ground,c,context)
 assert(owner==battle and stage==arena and ground==12 and context.actual)
 calls=calls+1
 assert(c.fov<=math.pi/3+1e-9,'lens still distorted')
 assert(c.focus[2]==camera.focus[2],'retreat moved aim or actors')
 if c.eye[3]<120 then return false end
 return verdict
end
setfenv(chunk,setmetatable(env,{__index=_G}));local retreat=chunk()
calls=0
local result,pitch=retreat(arena,12,camera,.4,{})
assert(result and pitch==.4 and calls==4)
assert(result.eye[3]==120 and camera.eye[3]==80 and camera.fov==math.rad(135))
assert(env.lastScreenSafe.battle==battle and env.BattleCam.mapRescueLens.retreat==1.5)
env.lastScreenSafe=nil;env.BattleCam.mapRescueLens=nil
env.BattleCam.viewportFovScale=1280/576
camera.fov=math.rad(60);calls=0
local portrait=assert(retreat(arena,12,camera,.4,{}))
local displayed=2*math.atan(math.tan(portrait.fov*.5)*env.BattleCam.viewportFovScale)
assert(math.abs(displayed-math.rad(60))<1e-9,'portrait expanded the corrected lens')
env.BattleCam.viewportFovScale=1
for _,blocked in ipairs({'terrain','travel','HUD','pending','manual','narrow','portable'})do
 visible=blocked~='terrain';pathClear=blocked~='travel'
 verdict=blocked~='HUD'
 if blocked=='pending' then verdict=nil end
 local stage=blocked=='portable' and {map=arena.map,discs=true} or arena
 camera.fov=blocked=='narrow' and math.rad(60) or math.rad(135)
 calls=0;env.lastScreenSafe=nil;env.BattleCam.mapRescueLens=nil
 assert(not retreat(stage,12,camera,.4,{manual=blocked=='manual'}),'accepted '..blocked)
 assert(not env.lastScreenSafe and not env.BattleCam.mapRescueLens,'cached rejected camera')
 assert(calls<=16,'unbounded search')
 if blocked~='HUD' and blocked~='pending' then assert(calls==0)end
end
-- A blocked route may be crossed only as one explicit recovery cut after
-- a definitive clipping verdict, to a clear destination with a safe HUD.
visible=true;camera.fov=math.rad(135);verdict=true
env.lastScreenSafe=nil;env.lastRetreatCut=nil;env.BattleCam.mapRescueLens=nil
local destinationClear=true
env.travelClear=function(_,_,from,to)return from==to and destinationClear end
calls=0
assert(retreat(arena,12,camera,.4,{recoveryCut=true}))
assert(env.lastRetreatCut.battle==battle)
env.lastScreenSafe=nil
assert(not retreat(arena,12,camera,.4,{recoveryCut=true}),'repeated recovery cut')
env.lastRetreatCut=nil;destinationClear=false
assert(not retreat(arena,12,camera,.4,{recoveryCut=true}),'cut into blocked destination')
destinationClear=true;verdict=false
assert(not retreat(arena,12,camera,.4,{recoveryCut=true}),'cut behind HUD')
assert(env.lastRetreatCut==nil,'rejected cut used recovery allowance')
print('PASS_BATTLE_CAMERA_RETREAT: moderate lens, clear travel, live HUD, bounded search and exclusions')
local setting={new=function(_,_,_,_,default)
 return {value=default,get=function(self)return self.value end}
end}
local Cam=assert(loadfile('lib/BattleCam.lua'))({require=function(name)
 assert(name=='ModSetting');return setting
end})
Cam.noteViewport(1000,600,576)
local priorSeat={camera={eye={20,50,80},focus={0,0,0},fov=math.rad(60)}}
for index=1,100 do
 local name=debug.getupvalue(Cam.noteViewport,index)
 if not name then break end
 if name=='lastScreenSafe' then debug.setupvalue(Cam.noteViewport,index,priorSeat);break end
end
local displayedBefore=2*math.atan(math.tan(priorSeat.camera.fov*.5)*600/576)
Cam.orbit=.2;Cam.zoom=2.8;Cam.zoomGoal=2.8;Cam.directorManualUntil=100
assert(not Cam.noteViewport(1000,600,576) and Cam.directorManualUntil==100)
assert(Cam.noteViewport(720,1280,576) and Cam.directorManualUntil==0)
assert(Cam.orbit==.2 and Cam.zoom==2.8 and Cam.zoomGoal==2.8,'resize changed accepted input')
assert(Cam.viewportFovScale==1280/576)
assert(math.abs(2*math.atan(math.tan(priorSeat.camera.fov*.5)*1280/576)-displayedBefore)<1e-9)
assert(priorSeat.camera.eye[1]==20 and priorSeat.camera.eye[2]==50,'resize moved fallback seat')
Cam.noteViewport(1000,600,576)
assert(math.abs(priorSeat.camera.fov-math.rad(60))<1e-9,'roundtrip accumulated lens scaling')
Cam.reset();assert(Cam.viewportFovScale==1)
print('PASS_BATTLE_CAMERA_VIEWPORT_LENS_AND_GESTURE_INVALIDATION')
-- A blocked retreat must hold the last proven physical seat. Falling back
-- to the uncorrected rig can pass HUD bounds but restore the distorted lens.
local guardStart=assert(source:find('local function guardRenderedCamera',1,true))
local guardEnd=assert(source:find('-- Decide once whether this physical arena',guardStart,true))
local guarded=assert(loadstring(source:sub(guardStart,guardEnd-1)..'return guardRenderedCamera'))
local held={eye={80,90,160},focus={0,0,0},fov=math.rad(60)}
local gate={activeArena=arena,activeBattle=battle,screenSafetyEvaluator=function()end,
 BattleCam={directorClock=0,directorManualUntil=0,directorShot='current',
  mapRescueLens={arena=arena,battle=battle,retreat=2,factor=.2}},
 lastScreenSafe={arena=arena,battle=battle,camera=held,pitch=.5},
 sameScreenOwner=env.sameScreenOwner,copyCamera=env.copyCamera,V=env.V,
 visibilityScore=function()return 6,true end,travelClear=function()return false end,
 authoredArena=function()return false end,
 screenSafeCamera=function()return true,'bounds-clear'end,
 retreatActorCamera=function()end,renderedPortableFrameRescue=function()end,
 renderedActorFrameRescue=function()end,exhaustPendingScreenFrames=function()end,
 rollbackManualInput=function()return false end,
 returnRevalidatedScreenCamera=function(_,c,p,reason)
  assert(c==held and reason=='rolled-back:camera-travel-blocked')
  return c,p
 end}
setfenv(guarded,setmetatable(gate,{__index=_G}))
local hold=guarded()
camera.fov=math.rad(135)
local kept=assert(hold(arena,12,camera,.5,false))
assert(kept==held and kept.fov==math.rad(60),'blocked move restored old wide rig')
gate.screenSafeCamera=function()return false,'actor-outside'end
assert(hold(arena,12,camera,.5,false)==nil,'held a newly unsafe old seat')
print('PASS_BATTLE_CAMERA_BLOCKED_RETREAT_PRESERVES_PROVEN_LENS')
-- A taller fight dock must be solved from the prior physical seat, rather
-- than repeatedly widening a new director rig which hugs the trainer.
gate.BattleCam.mapRescueLens=nil
gate.lastScreenSafe={arena=arena,battle=battle,camera=held,pitch=.5}
local recovered={eye={unpack(held.eye)},focus={0,-8,0},fov=held.fov}
local priorVerdict=false
local priorAttempts=0
gate.screenSafeCamera=function(_,_,_,c)
 if c==held then return priorVerdict,'playerHero-under-fight' end
 return false,'playerHero-outside-safe-frame'
end
gate.renderedActorFrameRescue=function(a,g,c,p,reason)
 if c~=held then return nil end
 priorAttempts=priorAttempts+1
 assert(a==arena and g==12 and p==.5 and reason=='playerHero-under-fight')
 return recovered,.55
end
assert(hold(arena,12,camera,.5,false)==recovered and priorAttempts==1)
priorVerdict=true
gate.returnRevalidatedScreenCamera=function(a,c,p,reason)
 assert(a==arena and c==held and p==.5 and reason=='prior-seat:playerHero-under-fight')
 return c,p
end
assert(hold(arena,12,camera,.5,false)==held and priorAttempts==1)
for _,excluded in ipairs({'pending','foreign-owner','manual','discs','arena'})do
 priorVerdict=false;if excluded=='pending'then priorVerdict=nil end
 gate.lastScreenSafe.battle=excluded=='foreign-owner' and {} or battle
 gate.BattleCam.directorManualUntil=excluded=='manual' and 10 or 0
 arena.discs=excluded=='discs' or nil;arena.arenaStyle=excluded=='arena' or nil
 local before=priorAttempts
 assert(hold(arena,12,camera,.5,false)==nil,'unverified seat admitted: '..excluded)
 assert(priorAttempts==before,'prior-seat recovery escaped scope: '..excluded)
end
print('PASS_BATTLE_PRIOR_SEAT_NEW_DOCK_AND_OWNER_GUARDS')
