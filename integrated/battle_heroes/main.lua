return function(mod)
 local active=true
 local cache={}
 local function load(path)
  if cache[path] then return cache[path] end
  local source=assert(mod:read(path))
  local chunk=assert(loadstring(source,'@'..mod.path..'/'..path))
  local value=chunk(load)
  cache[path]=value
  return value
 end
 local Motion=load('Motion.lua')
 local CharSprite=load('CharSprite.lua')
 local Trainers=CharSprite.trainers
 local Catch=load('JohtoCatch.lua')
 local data=load('data/johto.lua')
 local Art=load('Art.lua')(mod,data)
 local Battle=require('src.battle.BattleState')
 local Sound=require('src.core.Sound')
 local states=setmetatable({},{__mode='k'})
 local function enabled(key)
  if key=='enabled' and not active then return false end
  return mod.options:get(key)~=false
 end
 mod.options:define({
  {key='qolModernBallSkins',label='MODERN BALL SKINS',type='toggle',default=true},
  {key='enabled',label='JOHTO BALLWURF',type='toggle',default=true},
  {key='trainer_stays',label='TRAINER IM KAMPF',type='toggle',default=true},
  {key='gestures',label='TRAINER-GESTEN',type='toggle',default=true},
 })
 local function identities(b)
  local player,enemy=Motion.identity(b),CharSprite.enemyDefault(b)
  local handle=mod:find('kanto_ascendant')
  local api=handle and handle.exports and handle.exports.extendedCharacters
  local function selected(fn)
   if type(fn)~='function' then return nil end
   local ok,id=pcall(fn)
   id=ok and tostring(id):lower() or nil
   return id and CharSprite.characters[id] and id or nil
  end
  local identityEnabled=true
  if api and type(api.getState)=='function' then
   local ok,settings=pcall(api.getState)
   identityEnabled=ok and type(settings)=='table' and settings.enabled~=false
  end
  if api and identityEnabled then
   player=selected(api.getPlayerCharacter) or player
   if b.oppClass=='OPP_RIVAL1' or b.oppClass=='OPP_RIVAL2' or b.oppClass=='OPP_RIVAL3' then
    enemy=selected(api.getRivalCharacter) or enemy
   end
  end
  local guest=tostring(b.ascendantLifeRivalCharacter or ''):lower()
  if CharSprite.characters[guest] then enemy=guest end
  return CharSprite.resolve(b,'player',player),CharSprite.resolve(b,'enemy',enemy)
 end
 local function state(b)
  if not states[b] then states[b]={frame=0,role=Motion.identity(b),enemyRole=CharSprite.enemyDefault(b)} end
  return states[b]
 end
 local function valid(b)
  return enabled('enabled') and not b.demo and not b.oakDemo and not b.link
 end
 local function sound(b,name)
  -- Preserve the edition's sound synthesis and native success fanfare.
  local names={SFX_THROW_BALL='Ball_Toss',SFX_BALL_POOF='Ball_Poof',
    SFX_BALL_BOUNCE='Ball_Toss',SFX_BALL_WOBBLE='Ball_Toss'}
  local id=names[name]
  if id then pcall(Sound.play,b.data,id) end
 end
 local function begin(b,caught,shakes,ball,deploy,side)
  local s=state(b)
  s.catch=Catch.new(data,caught,shakes,ball,function(name)sound(b,name)end,enabled('qolModernBallSkins'))
  s.catch.deploy=deploy
  s.catch.side=side or 'player'
  if side=='enemy' then s.enemyAction,s.enemyActionAt='throw',s.frame
  else s.action,s.actionAt='throw',s.frame end
  s.resting=nil
 end
 local function staged(b)
  if mod.renderer then
   local ok,yes=pcall(mod.renderer.enabled,b)
   return ok and yes==true,mod.renderer
  end
  local handle=mod:find('VOXEL_ASCENDANT')
  local exports=handle and handle.exports
  if not exports or not exports.battleHeroesBridge then return false end
  local lib=exports.lib
  local ok,renderer=pcall(function()return lib.require('OverworldBattle')end)
  if not ok or not renderer then return false end
  local yes,value=pcall(renderer.enabled,b)
  return yes and value==true,renderer
 end
 -- VASC can show the two standing trainers independently of the optional
 -- Johto throw animation. The standalone card retains its original switch.
 local function standing(b)
  return active and mod.standingTrainers and mod.standingTrainers()
   and not b.demo and not b.oakDemo and not b.link and staged(b)
 end
 local oldChain=Battle.ballChain
 Battle.ballChain=function(b,toss,caught,shakes,ball)
  if not valid(b) then return oldChain(b,toss,caught,shakes,ball) end
  -- Gen1 already rolled the result. No RNG, item or storage writes occur here.
  b:actNext(function()begin(b,caught,shakes,ball,false)end)
 end
 local oldQueue=Battle.updateQueue
 Battle.updateQueue=function(b,...)
  local s=states[b]
  local c=s and s.catch
  if c then
   local ok,err=pcall(Catch.step,c)
   if not ok then
    s.catch=nil
    if c.finish then pcall(c.finish) end
    if not c.deploy then b.enemyHidden=c.caught==true end
    if mod.log then mod.log:warn('Johto animation failed: %s',tostring(err)) end
    return true
   end
   if not c.deploy then b.enemyHidden=c.runner.bg.hidden.enemy==true end
   if c.done or c.deploy and c.runner.frames>=36 then
    s.catch=nil
    if c.finish then c.finish();c.finish=nil end
    c.runner.hooks={} -- retained success art must not keep the battle alive
    if not c.deploy then
     b.enemyHidden=c.caught==true
     s.resting=c.caught and c or nil
    end
   end
   return true
  end
  return oldQueue(b,...)
 end
 local oldTick=Battle.tickFx
 Battle.tickFx=function(b,...)
  local result=oldTick(b,...)
  if not valid(b) and not standing(b) and not (states[b] and states[b].catch) then return result end
  local s=state(b);s.frame=s.frame+1
  s.role,s.enemyRole=identities(b)
  if s.previousPhase=='menu' and b.phase~='menu' and enabled('gestures') then
   s.action,s.actionAt='command',s.frame
   if b.kind=='trainer' then s.enemyAction,s.enemyActionAt='command',s.frame+12 end
  end
  s.previousPhase=b.phase
  return result
 end
 local oldSend=Battle.queueSendOutAnim
 Battle.queueSendOutAnim=function(b,append,...)
  if valid(b) and not b:starterPikachuSendOut() then
   local fn=function()begin(b,false,0,'POKE_BALL',true)end
   if append then b:act(fn) else b:actNext(fn) end
  end
  return oldSend(b,append,...)
 end
 local oldGrow=Battle.startGrowIn
 Battle.startGrowIn=function(b,battler,...)
  if valid(b) and b.kind=='trainer' and battler==b.enemy then
   begin(b,false,0,'POKE_BALL',true,'enemy')
   b.enemySendingOut=true
   local args={n=select('#',...),...}
   state(b).catch.finish=function()
    b.enemySendingOut=false
    oldGrow(b,battler,unpack(args,1,args.n))
   end
   return
  end
  return oldGrow(b,battler,...)
 end
 local oldPic=Battle.drawBattlerPic
 Battle.drawBattlerPic=function(b,mon,x,y,scale,...)
  local s=states[b];local c=s and s.catch
  if c and not c.deploy and mon==b.enemy then
   local size=c.runner.bg.picSize.enemy
   local ratio=({[3]=1,[4]=5/7,[5]=3/7})[size]
   if ratio and ratio~=1 then
    local img=b:picImage(mon.sprite)
    local w,h=img:getDimensions()
    x=x+w*scale*(1-ratio)/2;y=y+h*scale*(1-ratio)
    scale=scale*ratio
   end
  end
  return oldPic(b,mon,x,y,scale,...)
 end
 local function pose(b)
  if not (valid(b) or standing(b)) or not staged(b) then return nil end
  local s=state(b)
  local action=s.action
  local age=s.frame-(s.actionAt or 0)
  if age>54 then action=nil end
  if not enabled('trainer_stays') and not s.catch and not b.showPlayerBack then return nil end
  return s,action,age
 end
 -- Extra trainers belong to a staged battle only. The native 2D picture
 -- layer keeps its original intro cards; the selected Card option stays on
 -- for the next MAP/ARENA/DISCS battle. Ball outcomes are unaffected.
 local oldAnim=Battle.drawAnimLayer
 Battle.drawAnimLayer=function(b,...)
  local s=states[b];local c=s and (s.catch or s.resting)
  if not c or b.fieldCleared then return oldAnim(b,...) end
  local isStage,renderer=staged(b)
  c.runner.presentationScale=isStage and .75 or 1
  local shot=b.voxelAscendantShot
  local actor=c.side=='enemy' and s.enemyPresentation or s.presentation
  local hand=actor and actor.handNdc
  if isStage and shot and hand and shot.scale and renderer.ANCHOR then
   local a=renderer.ANCHOR
   local px,py=shot.player[1],shot.player[2]
   if renderer.playerBackPinned(b) then px,py=a.player[1],a.player[2] end
   local cx,cy=(shot.enemy[1]+px)/2,(shot.enemy[2]+py)/2
   local ax,ay=(a.enemy[1]+a.player[1])/2,(a.enemy[2]+a.player[2])/2
   local k=renderer.animScale(shot,px,py)
   local hx=((hand[1]*.5+.5)*shot.pw-shot.lx)/shot.scale
   local hy=((hand[2]*.5+.5)*shot.ph-shot.ly)/shot.scale
   c.launchX=ax+(hx-cx)/k
   c.launchY=ay+(hy-cy)/k
   local target=c.deploy and c.side=='player' and 'player' or 'enemy'
   local visual=shot.actorVisuals and shot.actorVisuals[target]
   local foot=visual and visual.foot
   local nominal=shot.actorFeet and shot.actorFeet[target]
   local fx=foot and foot.x or nominal and nominal[1]
   local fy=foot and foot.y or nominal and nominal[2]
   if fx and fy then
    c.targetX=ax+((fx-shot.lx)/shot.scale-cx)/k
    c.targetY=ay+((fy-shot.ly)/shot.scale-cy)/k
   end
  else
   local side=c.side or 'player'
   local role=side=='enemy' and s.enemyRole or s.role
   local h=Art.releaseHand and Art.releaseHand(role,side) or {.6,.5}
   local x,y,height=11,94,42
   if side=='enemy' then x,y,height=149,52,34 end
   c.launchX=x+(h[1]*192-96)*height/220
   c.launchY=y+(h[2]*256-246)*height/220
   c.targetX,c.targetY=124,56
   if c.deploy and c.side=='player' then c.targetX,c.targetY=26,96 end
  end
  love.graphics.push('all')
  local player,playing=b.animPlayer,b.animPlaying
  b.animPlaying=true
  b.animPlayer={draw=function()
   local ok,err=pcall(Art.drawCatch,c)
   if not ok then
    s.renderError=tostring(err)
    if not s.renderWarned and mod.log then
     s.renderWarned=true;mod.log:warn('Ball rendering failed: %s',s.renderError)
    end
   end
  end}
  local ok,err=pcall(oldAnim,b,...)
  b.animPlayer,b.animPlaying=player,playing
  love.graphics.pop()
  if not ok then error(err) end
 end
 -- Retirement disables new work; queue wrappers drain existing native outcomes.
 mod.exports.setActive=function(value) active=value==true end
 mod.exports.isActive=function() return active and enabled('enabled') end
 mod.exports.schema='ascendant.battle-heroes/v1'
 mod.exports.presentation=function(b)
  local s,action,age=pose(b)
  if not s then return nil end
  local facing=s.presentation and s.presentation.facing or 'player'
  local view=s.presentation and s.presentation.view
  if s.canvasFrame~=s.frame or s.canvasView~=view or s.canvasFacing~=facing then
   s.canvas=Art.heroCanvas(s.role,s.frame,action,age,s.canvas,facing,s.catch and s.catch.side=='player' and s.catch.modern and s.catch.ball,view)
   s.canvasFrame,s.canvasView,s.canvasFacing=s.frame,view,facing
  end
  s.presentation=s.presentation or {}
  local p=s.presentation
  p.setView=p.setView or function(view,facing)
   if s.canvasFrame==s.frame and s.canvasView==view and s.canvasFacing==facing then return p end
   p.view,p.facing=view,facing
   return mod.exports.presentation(b)
  end
  p.canvas,p.role,p.width,p.height=s.canvas,s.role,CharSprite.get(s.role).width or 12,CharSprite.get(s.role).height
  p.intro,p.action=b.showPlayerBack==true,action
  p.releaseHand=Art.releaseHand and Art.releaseHand(s.role,facing,view) or {.6,.5}
  return p
 end
 mod.exports.enemyPresentation=function(b)
  local s=pose(b)
  if not s or b.kind~='trainer' then return nil end
  local age=math.max(0,s.frame-(s.enemyActionAt or 0))
  local action=age<=54 and s.enemyAction or nil
  local facing=s.enemyPresentation and s.enemyPresentation.facing or 'enemy'
  local view=s.enemyPresentation and s.enemyPresentation.view
  if s.enemyCanvasFrame~=s.frame or s.enemyCanvasView~=view or s.enemyCanvasFacing~=facing then
   s.enemyCanvas=Art.heroCanvas(s.enemyRole,s.frame,action,age,s.enemyCanvas,facing,s.catch and s.catch.side=='enemy' and s.catch.modern and s.catch.ball,view)
   s.enemyCanvasFrame,s.enemyCanvasView,s.enemyCanvasFacing=s.frame,view,facing
  end
  s.enemyPresentation=s.enemyPresentation or {}
  local p=s.enemyPresentation
  p.setView=p.setView or function(view,facing)
   if s.enemyCanvasFrame==s.frame and s.enemyCanvasView==view and s.enemyCanvasFacing==facing then return p end
   p.view,p.facing=view,facing
   return mod.exports.enemyPresentation(b)
  end
  p.canvas,p.role,p.width,p.height=s.enemyCanvas,s.enemyRole,CharSprite.get(s.enemyRole).width or 12,CharSprite.get(s.enemyRole).height
  p.intro,p.action=b.showEnemyTrainer==true,action
  p.releaseHand=Art.releaseHand and Art.releaseHand(s.enemyRole,facing,view) or {.4,.5}
  return p
 end
 mod.exports.trainerClasses=Trainers
 mod.exports.charsprite=CharSprite
 CharSprite.assetPath=function(id)
  local path=CharSprite.get(id).path
  return path:match('^assets/') and mod.path..'/'..path or path
 end
 mod.exports.status=function(b)
  local s=states[b]
  return s and {role=s.role,frame=s.frame,action=s.action,
    renderError=s.renderError,enemyRole=s.enemyRole,catchSide=s.catch and s.catch.side,catchAge=s.catch and s.catch.age,catching=s.catch~=nil,catchFrame=s.catch and s.catch.runner.frames,
    enabled=enabled('enabled'),trainerStays=enabled('trainer_stays')} or nil
 end
 mod.exports.ballStatus=Art.ballStatus
 mod.exports.roles=Motion.roles
end
