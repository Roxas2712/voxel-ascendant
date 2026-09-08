local f=assert(io.open('lib/OverworldBattle.lua'));local s=f:read('*a');f:close()
local a=assert(s:find('local function rectHits',1,true));local b=assert(s:find('if type(BattleCam.setScreenSafetyEvaluator)',a,true))
local O={};local shot={pw=960,ph=600,actorVisuals={},actorHulls={player={-50,480,200,150},enemy={600,200,80,100}},actorFeet={player={0,610},enemy={640,300}}}
local owner={id='player-status',x=10,y=10,w=200,h=60,ownerSide='player',ownerVisualGap=true,allowOwnActorOverlap=true}
local bounds={safeInsets={0,0,0,0},reserved={owner,{id='command',x=200,y=500,w=500,h=90}}}
O.battleHudCameraBounds=function()return bounds end
local fn=assert(loadstring(s:sub(a,b-1)));local env={OverworldBattle=O,BattleScene={cameraSafetyShot=function()return shot end},sameBattle=function(a,b)return a==b end};setfenv(fn,setmetatable(env,{__index=_G}));fn()
local battle={player={mon={}},enemy={mon={}}}
assert(O.battleHudCameraSafe(battle,{},0,{}),'same-owner hidden body collided with command UI')
owner.ownerVisualGap=nil;owner.allowOwnActorOverlap=nil;owner.ownerSide=nil
assert(O.battleHudCameraSafe(battle,{},0,{})==false,'missing owner receipt authorized hidden pixels')
owner.ownerVisualGap=true;owner.allowOwnActorOverlap=true;owner.ownerSide='player'
shot.actorVisuals.player={hull={-50,480,200,150},foot={x=0,y=610}}
assert(O.battleHudCameraSafe(battle,{},0,{})==false,'visible actor bypassed screen safety')
print('Hidden actor camera ownership: ok')

shot.actorVisuals.player=nil;bounds.reserved={{id='command',x=200,y=500,w=500,h=90}}
O.playerBackPinned=function()return false end
battle.picFx={[battle.player]={hidden=true}};env.session={battle=battle,presentationCommitted=true}
assert(O.battleHudCameraSafe(battle,{},0,{}),'STANDARD hidden body still collides with its nominal prism')
env.session.pendingSwitch={};assert(O.battleHudCameraSafe(battle,{},0,{})==false,'deployment gap accepted as an animation hide')
env.session.pendingSwitch=nil;battle.picFx=nil;O.playerBackPinned=function()return true end
assert(O.battleHudCameraSafe(battle,{},0,{}),'native pinned rear was counted as world geometry')
print('STANDARD hidden actor camera ownership: ok')

-- A new deployment has no owner-gap HUD receipt yet. The engine's explicit
-- send-out/hide state can prove that its nominal body has no visible pixels.
env.session={battle=battle,presentationCommitted=true,pendingSwitch={side='enemy'}}
battle.picFx=nil; O.playerBackPinned=function()return false end
shot.actorHulls={player={20,230,50,60},enemy={200,130,50,60}}
shot.actorFeet={player={45,290},enemy={225,190}}
shot.actorVisuals={player={hull=shot.actorHulls.player,foot={x=45,y=290}}}
bounds.reserved={{id='player-status',x=180,y=120,w=180,h=60}}
local safe,reason=O.battleHudCameraSafe(battle,{},0,{})
assert(not safe and reason=='enemy-under-player-status')
battle.enemySendingOut=true
assert(O.battleHudCameraSafe(battle,{},0,{}),'absent send-out body blocked camera')
shot.actorVisuals.enemy={hull=shot.actorHulls.enemy,foot={x=225,y=190}}
assert(O.battleHudCameraSafe(battle,{},0,{})==false,'visible growing model bypassed safety')
shot.actorVisuals.enemy=nil; battle.showEnemyTrainer=true
assert(O.battleHudCameraSafe(battle,{},0,{})==false,'missing trainer art treated as empty slot')
battle.showEnemyTrainer=nil; battle.enemySendingOut=nil; battle.enemyHidden=true
assert(O.battleHudCameraSafe(battle,{},0,{}),'explicit hidden enemy blocked camera')
battle.enemyHidden=nil
assert(O.battleHudCameraSafe(battle,{},0,{})==false,'missing model without hide flag accepted')
battle.growInScale=function(_,battler)if battler==battle.enemy then return 0 end end
assert(O.battleHudCameraSafe(battle,{},0,{}),'zero-scale ball beat created phantom body')
shot.actorVisuals.enemy={hull=shot.actorHulls.enemy,foot={x=225,y=190}}
assert(O.battleHudCameraSafe(battle,{},0,{})==false,'visible Stadium growth bypassed safety')
shot.actorVisuals.enemy=nil
for _,scale in ipairs({.001,3/7,1}) do
  battle.growInScale=function()return scale end
  assert(O.battleHudCameraSafe(battle,{},0,{})==false,'nonzero growth incorrectly hidden')
end
battle.growInScale=function()error('provider failed')end
assert(O.battleHudCameraSafe(battle,{},0,{})==false,'failed grow query authorized hide')
battle.growInScale=nil
battle.enemySendingOut=true;env.session={battle={}}
assert(O.battleHudCameraSafe(battle,{},0,{})==false,'foreign battle authorized hide')
env.session={battle=battle,pendingSwitch={side='player'}}
battle.enemySendingOut=nil; battle.sendingOut=true
shot.actorVisuals={enemy={hull={500,230,50,60},foot={x=525,y=290}}}
shot.actorHulls.player={-50,230,50,60};shot.actorFeet.player={-25,290}
assert(O.battleHudCameraSafe(battle,{},0,{}),'absent player send-out body blocked camera')
battle.showPlayerBack=true
assert(O.battleHudCameraSafe(battle,{},0,{})==false,'missing back trainer authorized hide')
print('Send-out camera visibility and exact battle ownership: ok')
