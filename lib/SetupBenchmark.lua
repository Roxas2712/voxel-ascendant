-- Two minute native-render check. No changes to the player's save/party.
local V=...
local L=V.require('SetupLocale').text
local Measure=V.require('SetupMeasurement')
local E=V.require('SetupEffects');local Images=V.require('SetupImageCheck');local M={DURATION=120}
local function copy(t,seen)
 if type(t)~='table'then return t end;seen=seen or {};if seen[t]then return seen[t]end
 local n={};seen[t]=n;for k,v in pairs(t)do n[copy(k,seen)]=copy(v,seen)end;return setmetatable(n,getmetatable(t))
end
local function p95(a)local b={};for i,v in ipairs(a)do b[i]=v end;table.sort(b);return b[math.max(1,math.ceil(#b*.95))]or 0 end
M.p95=p95
M.tiers={L("Weak",'Schwach'),L("Entry-level",'Einsteiger'),L("Solid",'Solide'),L("Powerful",'Leistungsstark'),L("Very powerful",'Sehr stark'),'High-End'}
function M.tier(seconds)
 local level=Measure.tier(seconds);return level,M.tiers[level]
end
local function set(s,k,v)if s.settings[k]and v~=nil then s.settings[k]:setValue(v,s.game,true)end end
local function below(s,fn)
 local states=s.game.stack.states;assert(states[#states]==s,L("The graphics check is no longer in the foreground.",'Der Grafikcheck ist nicht mehr im Vordergrund.'));table.remove(states)
 local ok,err=pcall(fn);states[#states+1]=s;if not ok then error(err,0)end
end
local function clearBattle(s)
 local t=s.trial;local g=s.game
 if t.fixture then pcall(V.require('adapters/gen1/Gen1BattleLifecycle').abort,t.fixture,'setup-benchmark-finished')end
 below(s,function()while #g.stack.states>t.baseCount do g.stack:pop()end end)
 t.fixture=nil;t.scene='world';g.overworld.battleOamKeep=nil;g.overworld.wipeSpritesFn=nil
end
local function scene(s,kind)
 local t=s.trial;if t.scene==kind then return end;clearBattle(s)
 if kind=='world'then return end
 set(s,s.stageKey,kind=='terrarium'and 'terarrium'or true)
 local Native=require('src.battle.BattleState')
 local gate=Native._kascGenerationBattleGate67;if gate then gate.equipmentCheckpoint(s.game)end
 local b=Native.newWild(s.game,'PIDGEY',4);t.fixture=b;t.scene=kind
 -- A render fixture starts at the command menu, without simulating a turn.
 -- Run the native lifecycle, then omit only its introductory message queue.
 local enter=b.enter
 b.enter=function(battle,...)
  enter(battle,...)
  battle.queue={};battle.current=nil;battle.afterQueue=nil;battle.nextInsert=nil
  battle.waitFrames=nil;battle.waitingSound=nil;battle.waitSoundLeft=nil
  battle.msgHold=nil;battle.msgWaiting=nil;battle.msgPrompt=nil;battle.shown=nil
  battle.introSlide=nil;battle.showPlayerBack=false;battle.showEnemyTrainer=false
  battle.sendingOut=false;battle.enemySendingOut=false;battle.introBalls=false
  battle.fx={};battle:slidePic('back');battle:slidePic('foe')
  battle:enterCommandMenu();battle:snapIdleBars()
 end

 below(s,function()s.game.overworld:pushBattle(b)end)
end
function M.plan(request)
 local plan={{scene='world',duration=8,label=L('Warming up the scene','Szene aufwärmen'),calibration=true}}
 for _,id in ipairs({'shadows','reflections','aa','world_light','battle_light','terrarium_light'})do
  if not request or request.ids[id]then
  local effect;for _,e in ipairs(E.rules.effects)do if e.id==id then effect=e end end
  for repeatIndex,on in ipairs({false,true,true,false})do plan[#plan+1]={effect=effect,on=on,repeatIndex=repeatIndex,scene=effect.scene,duration=4,label=effect.label..(on and L(' · ON',' · AN')or L(' · OFF / BASELINE',' · AUS / BASIS'))..' · '..repeatIndex..'/4'}end
  end
 end
 if not request or request.combo then
 for repeatIndex,on in ipairs({false,true,true,false})do
  plan[#plan+1]={scene='world',duration=4,repeatIndex=repeatIndex,label=(on and L('Combined effects','Effekte gemeinsam')or L('Shared baseline','Gemeinsame Basis'))..' · '..repeatIndex..'/4',combo=on}
 end
 end
 local duration=0;for _,p in ipairs(plan)do duration=duration+p.duration end
 return plan,duration
end
function M.start(s)
 local t=s.trial;local g=s.game;t.full=true;t.duration=120;t.elapsed=0;t.phase=0;t.baseCount=#g.stack.states-1;t.scene='world'
 t.weatherClock=V.require('Weather').clock
 t.originalStates=g.stack.states;t.world=g.overworld
 t.save=g.save;t.saveWriter=g.writeSave;t.menu={g.partyMenuSavedIndex,g.bagSavedMenuItem,g.bagListScrollOffset}
 g.writeSave=function()end;g.save=copy(g.save)
 g.save.meta=g.save.meta or {};g.save.meta.playthroughId='dein-look-benchmark-v3'
 g.save.party={require('src.pokemon.Pokemon').new(g.data,'PIKACHU',20)}
 g.save.repelSteps=999999
 g.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB=true;g.save.flags.EVENT_GOT_STARTER=true
 local proto={};for k,v in pairs(require('src.world.OverworldController'))do if type(v)=='function'then proto[k]=v end end
 local world=setmetatable({isOpaque=true},{__index=proto})
 g.stack.states={world,s};t.baseCount=1;t.testWorld=world
 world:enter('ROUTE_1',10,30,'right')
 set(s,'weather','clear');set(s,'daytime','day')
 t.priorEffects=s.effects;t.priorPerformance=s.performance
 s.effects=E.new(g,s.draft);s.effects.results=copy(t.priorEffects.results);s.effects.combination=copy(t.priorEffects.combination);s.effects.performance=copy(t.priorEffects.performance)
 E.refresh(s.effects,s.draft);E.install();E.tracking=true
 -- Exercise the native Terrarium camera's idle roll immediately, with the
 -- same repeatable phase in all four windows instead of its nine-second wait.
 t.terrariumService=V.require('TerarriumHost').service
 if t.terrariumService and type(t.terrariumService.idleSample)=='function'then
  t.idleSample=t.terrariumService.idleSample
  t.terrariumService.idleSample=function()
   if t.scene~='terrarium'then return t.idleSample()end
   local age=math.max(0,t.elapsed-t.phaseStart);local beat=math.floor(age/.56);local phase=age/.56-beat
   local envelope=math.sin(math.pi*phase)^2
   return (beat%2==0 and 1 or -1)*.075*envelope,envelope,age
  end
 end
 local camera=V.require('BattleCam');t.cameraState={};for k,v in pairs(camera)do if type(v)=='number'then t.cameraState[k]=v end end
 t.cap=require('src.core.FrameCap').current
 local _,_,flags=love.window.getMode();t.refreshRate=tonumber(flags and flags.refreshrate)or 60
 if t.refreshRate<=0 then t.refreshRate=60 end
 t.vsync=love.window.getVSync and love.window.getVSync()or 0
 t.pacingRate=t.cap>0 and t.cap or t.refreshRate
 if t.vsync~=0 then t.pacingRate=math.min(t.pacingRate,t.refreshRate)end
 t.budget=1/math.min(60,t.pacingRate)
 t.recommendedResolution=s.draft.sceneResolution
 t.plan,t.duration=M.plan(t.request);t.metrics={};t.total=0
 t.phaseStart=0;t.frameSamples={};t.last=love.timer.getTime();M.advance(s)
end
function M.advance(s)
 local t=s.trial;if t.phase>0 then M.finishPhase(s)end
 t.phase=t.phase+1;local p=t.plan[t.phase];if not p then return false end
 t.phaseStart=t.elapsed;t.frameSamples={};t.images=0;t.flickers=0;t.losses=0;t.exercised=false;t.firstImage=nil;t.previous=nil;t.previousDelta=nil;t.lastImage=0;t.readbackFailures=0;t.timingContaminated=false;t.lastTiming=false;t.error=nil;t.skipped=nil;t.maxLights=0;t.motion=false;t.cameraFirst=nil;t.rainObserved=false;t.waterSeen=false
 for _,e in ipairs(E.rules.effects)do set(s,e.key,e.off)end
 if p.scene=='battle'then set(s,'battleBack',false)end
 if p.scene=='battle'and s.game.overworld.map.id~='ROUTE_1'then s.game.overworld:setMap('ROUTE_1',10,30,'right',{via='boot'})end
 scene(s,p.scene)
 if p.scene=='world'then
  local wanted=p.effect and p.effect.id=='world_light'and 'PALLET_TOWN'or (p.combo~=nil or p.effect and p.effect.id=='reflections')and 'ROUTE_21'or 'ROUTE_1'
  if s.game.overworld.map.id~=wanted then s.game.overworld:setMap(wanted,wanted=='PALLET_TOWN'and 9 or 10,wanted=='ROUTE_1'and 30 or wanted=='PALLET_TOWN'and 9 or 10,'right',{via='boot'})end
 end
 local rain=p.combo~=nil or p.effect and p.effect.id=='reflections'
 set(s,'weather',rain and 'rain'or 'clear');set(s,'daytime',p.effect and p.effect.id=='world_light'and 'night'or 'day')
 set(s,'arenaCamera','stadium')
 local camera=V.require('BattleCam');camera.t=0;camera.directorAutoClock=18;camera.orbit=0;camera.orbitGoal=0
 t.scenario=p.effect and p.effect.id=='world_light'and 'night-windows'or rain and 'rain-water'or p.scene~='world'and 'moving-battle'or 'day-nature'
 if p.effect and p.on then
  local rule=s.effects.compatibility[p.effect.id]
  -- Test the appropriate fixture even when the current preferred battle
  -- style doesn't use it; recommendations still respect the chosen style.
  if rule.state=='blocked'then t.skipped=rule.reason else set(s,p.effect.key,p.effect.on)end
 elseif p.combo then
  local combined=0;t.candidates={}
  for _,e in ipairs(E.rules.effects)do local r=t.metrics[e.id]or t.request and s.effects.results[e.id];if e.scene=='world'and r and r.valid and r.exercised and not r.error and (not r.imageSuspect or r.visual=='ok')and r.visual~='bad'and r.verdict=='pass' then set(s,e.key,e.on);combined=combined+1;t.candidates[e.id]=true end end
  t.combinedCount=combined
 end
 E.waterObserved=false
 print('SETUP_BENCHMARK_PHASE',t.phase,p.label)
 return true
end
function M.finishPhase(s)
 local t=s.trial;local p=t.plan[t.phase]
 local r=Measure.summary(t.frameSamples)
 r.frame=r.p95 or 0;r.samples=r.n;r.images=t.images;r.exercised=t.exercised
 r.flickers=t.flickers;r.losses=t.losses;r.error=t.error or t.skipped
 r.coverage={scenario=t.scenario,lights=t.maxLights,rain=t.rainObserved,water=t.waterSeen,moving=t.motion};r.first=t.firstImage;r.last=t.previous;r.readbackFailures=t.readbackFailures
 t.phaseResults=t.phaseResults or {};t.phaseResults[t.phase]=r
 if p.calibration then t.calibration=r else
  if p.repeatIndex==1 then t.repeats={}end
  t.repeats[p.repeatIndex]=r
  if p.repeatIndex==4 then
   local result=Measure.compare(t.repeats,t.budget)
   local a,b,c,d=t.repeats[1],t.repeats[2],t.repeats[3],t.repeats[4]
   result.exercised=b.exercised and c.exercised
   result.visual='unknown';result.scene=p.scene;result.coverage={scenario=t.scenario,lights=math.min(b.coverage.lights,c.coverage.lights),rain=b.coverage.rain and c.coverage.rain,water=b.coverage.water and c.coverage.water,moving=b.coverage.moving and c.coverage.moving}
   if t.scenario=='night-windows'and result.coverage.lights<2 or t.scenario=='rain-water'and (not result.coverage.rain or (p.effect or t.candidates and t.candidates.reflections)and not result.coverage.water)or t.scenario=='moving-battle'and not result.coverage.moving then result.valid=false;result.verdict='uncertain';result.reason='scenario'end
   if p.combo~=nil and not next(t.candidates or {})then result.valid=false;result.verdict='uncertain';result.reason='no-candidates'end
   result.imageValid=a.images>=3 and b.images>=3 and c.images>=3 and d.images>=3
   result.valid=result.valid and result.imageValid
   if not result.valid then result.verdict='uncertain';result.reason=(result.reason=='scenario'or result.reason=='no-candidates')and result.reason or 'samples'end
   -- A missing single frame is inconclusive, never a permanent shader failure.
   result.error=a.error or b.error or c.error or d.error
   result.imageSuspect=(b.flickers>=2 or c.flickers>=2 or b.losses>=2 or c.losses>=2
    or (Images.compare(a.last,b.last)and Images.compare(d.last,c.last)))and true or false
   if p.effect then t.metrics[p.effect.id]=result else t.combination=result;result.candidates=t.candidates or {};t.reference=a;t.referenceRepeat=d end
   print('SETUP_PAIRED_RESULT',p.effect and p.effect.id or 'combined',result.verdict,result.reason,result.off,result.on,result.delta,result.valid,result.exercised,result.imageSuspect)
  end
 end
 print('SETUP_BENCHMARK_RESULT',t.phase,r.samples,r.images,r.frame,r.median or 0,r.exercised,r.flickers,r.losses,r.error or '')
end
function M.update(s)
 local t=s.trial;local now=love.timer.getTime();local delta=now-t.last;t.last=now
 if s.game.input:wasPressed('b')then s:stopBenchmark(true);return end
 local w,h=love.graphics.getPixelDimensions();if w~=s.effects.device.width or h~=s.effects.device.height then s:stopBenchmark(true);s.message=L("Window size changed. Please test again at your preferred size.",'Fenstergröße geändert. Bitte bei der gewünschten Größe erneut testen.');return end
 if not love.window.isVisible()or not love.window.hasFocus()then t.paused=true;t.lastTiming=false;return end
 if t.paused then t.paused=false;t.resumeWarmup=1.25;delta=0 end
 if t.resumeWarmup then t.resumeWarmup=t.resumeWarmup-delta;if t.resumeWarmup<=0 then t.resumeWarmup=nil end end
 if not t.resumeWarmup then t.elapsed=t.elapsed+delta end
 local age=t.elapsed-t.phaseStart
 V.require('Weather').setClock(60+age)
 if t.scene~='world'then local cam=V.require('BattleCam');cam.t=age;cam.directorAutoClock=18+age;if t.scene=='battle'then cam.dragOrbit(math.min(delta,.05)*.025)end end
 if t.scene~='world'then
  local input=s.game.input;local pressed,down=input.wasPressed,input.isDown
  local b=t.fixture
  input.wasPressed=function(_,key)return key=='a'and b and b.phase~='menu'end
  input.isDown=function(_,key)return key=='a'and b and b.phase~='menu'end
  local ok,err=pcall(function()below(s,function()
   local top=s.game.stack:top()
   if top and top~=s.game.overworld and top.update then for i=1,(b and b.phase~='menu'and 4 or 1)do top:update(math.min(delta,.05))end end
   E.resetFrame();local started=love.timer.getTime();V.require('OverworldBattle').update(math.min(delta,.05))
   if b and b.phase=='menu'then M.capture(s,started,true)end
  end)end)
  input.wasPressed=pressed;input.isDown=down
  if not ok then t.error=tostring(err);s:stopBenchmark(true);s.message=L("Graphics check cancelled; your settings were restored.",'Grafikcheck abgebrochen; deine Einstellungen wurden wiederhergestellt.');return end
 end
 if age>=t.plan[t.phase].duration then if not M.advance(s)then s:stopBenchmark(false)end end
end
-- Once per rendered frame, never per fixed simulation step. Includes actual
-- frame pacing, but no diagnostic readback or screenshot window.
function M.frame(s,now)
 local t=s.trial;local age=t.elapsed-t.phaseStart
 local timing=not t.paused and not t.resumeWarmup and Measure.window(age,t.plan[t.phase].duration)=='timing'
 if timing and t.lastTiming and t.framePhase==t.phase and t.frameLast and not t.timingContaminated then
  local delta=now-t.frameLast;if delta>0 then t.frameSamples[#t.frameSamples+1]=delta end
 end
 t.frameLast=now;t.framePhase=t.phase;t.lastTiming=timing;t.timingContaminated=false
end
function M.capture(s,started,battleUpdate)
 local t=s.trial;if not t or not t.full or t.paused then return end
 if t.scene~='world'and not battleUpdate then return end
 local age=t.elapsed-t.phaseStart
 local p=t.plan[t.phase]
 t.maxLights=math.max(t.maxLights,E.lightCount or 0);t.waterSeen=t.waterSeen or E.waterObserved==true
 t.rainObserved=t.rainObserved or E.sceneObserved and V.require('Weather').mode(s.game.overworld.map)=='rain'
 local signature=E.cameraSignature
 if signature then if t.cameraFirst and signature~=t.cameraFirst then t.motion=true end;t.cameraFirst=t.cameraFirst or signature end
 if p.effect and p.on and not t.skipped then t.exercised=t.exercised or E.active(p.effect.id)end
 if t.resumeWarmup or Measure.window(age,p.duration)~='images'or t.elapsed-t.lastImage<.11 then return end
 t.lastImage=t.elapsed;t.timingContaminated=true
 local stats,err=E.imageStats()
 if not stats then t.readbackFailures=t.readbackFailures+1;return end
 t.images=t.images+1
 Images.observe(t,stats)
 if not t.firstImage then t.firstImage=stats end
end
function M.restore(s)
 local t=s.trial;local g=s.game;E.tracking=false
 local ok,err=pcall(clearBattle,s)
 if t.testWorld then pcall(t.testWorld.exit,t.testWorld)end
 g.overworld=t.world;g.stack.states=t.originalStates
 g.save=t.save;g.writeSave=t.saveWriter;g.partyMenuSavedIndex=t.menu[1];g.bagSavedMenuItem=t.menu[2];g.bagListScrollOffset=t.menu[3]
 if t.terrariumService and t.idleSample then t.terrariumService.idleSample=t.idleSample end
 if t.weatherClock then V.require('Weather').setClock(t.weatherClock)end
 if t.cameraState then local camera=V.require('BattleCam');for k,v in pairs(t.cameraState)do camera[k]=v end end
 pcall(require('src.core.Music').restoreMap,g.data)
 return ok,err
end
function M.complete(s,t)
 E.refresh(s.effects,s.draft)
 if not t.request then s.effects.results={}end
 for id,r in pairs(t.metrics)do s.effects.results[id]=r end
 if t.combination then s.effects.combination=t.combination;s.effects.performance=nil end
 s.performance=s.effects.performance
 local combo=t.combination
 if combo and combo.valid and (combo.reason=='negligible'or combo.reason=='headroom'or combo.reason=='repeatable-cost') then
  local base={t.reference.median,t.referenceRepeat.median}
  local seconds=Measure.quantile(base,.5);local level,label=M.tier(seconds)
  s.performance={level=level,label=label,frameMs=seconds*1000,renderMs=seconds*1000,
   lowerBound=seconds<=1/t.pacingRate*1.08,width=s.effects.device.width,height=s.effects.device.height,
   resolution=s.draft.sceneResolution,method=Measure.REVISION}
 end
 s.effects.performance=s.performance;E.save(s.effects)
 local scope=t.request and copy(t.request.ids)
 if scope and not next(scope)and t.combination then for _,e in ipairs(E.rules.effects)do if e.scene=='world'then scope[e.id]=true end end end
 s:applyRecommendations(scope)
end

return M
