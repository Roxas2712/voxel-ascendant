local f=assert(io.open('lib/OverworldBattle.lua'));local s=f:read('*a');f:close()
local a=assert(s:find('local function rectHits',1,true));local b=assert(s:find('if type(BattleCam.setScreenSafetyEvaluator)',a,true))
local O={};local shot={pw=960,ph=600,actorVisuals={},actorHulls={player={-50,480,200,150},enemy={600,200,80,100}},actorFeet={player={0,610},enemy={640,300}}}
local owner={id='player-status',x=10,y=10,w=200,h=60,ownerSide='player',ownerVisualGap=true,allowOwnActorOverlap=true}
local bounds={safeInsets={0,0,0,0},reserved={owner,{id='command',x=200,y=500,w=500,h=90}}}
O.battleHudCameraBounds=function()return bounds end
local fn=assert(loadstring(s:sub(a,b-1)));setfenv(fn,setmetatable({OverworldBattle=O,BattleScene={cameraSafetyShot=function()return shot end}},{__index=_G}));fn()
local battle={player={mon={}},enemy={mon={}}}
assert(O.battleHudCameraSafe(battle,{},0,{}),'same-owner hidden body collided with command UI')
owner.ownerVisualGap=nil;owner.allowOwnActorOverlap=nil;owner.ownerSide=nil
assert(O.battleHudCameraSafe(battle,{},0,{})==false,'missing owner receipt authorized hidden pixels')
owner.ownerVisualGap=true;owner.allowOwnActorOverlap=true;owner.ownerSide='player'
shot.actorVisuals.player={hull={-50,480,200,150},foot={x=0,y=610}}
assert(O.battleHudCameraSafe(battle,{},0,{})==false,'visible actor bypassed screen safety')
print('Hidden actor camera ownership: ok')
