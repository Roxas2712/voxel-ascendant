local root=assert(arg[1]).."/lib/"
for _,name in ipairs({'SetupCard','SetupBenchmark','SetupEffects','SetupEffectRules','SetupImageCheck','SetupPreview','BattleSpriteControl'})do assert(loadfile(root..name..'.lua'))end
local Measure=assert(loadfile(root..'SetupMeasurement.lua'))()
local Locale={text=function(en,de)return en end}
local R=assert(loadfile(root..'SetupEffectRules.lua'))({require=function()return Locale end})
local I=assert(loadfile(root..'SetupImageCheck.lua'))()
local E={rules=R}
local B=assert(loadfile(root..'SetupBenchmark.lua'))({require=function(name)return name=='SetupLocale'and Locale or name=='SetupMeasurement'and Measure or name=='SetupImageCheck'and I or E end})
local count=0;local function test(x,name)assert(x,name);count=count+1;print('PASS',name)end
local c={gpu=true,lights=true,battle='arena',terrarium=true,mobile=false,width=1920,height=1080,maxTexture=8192,profile='desktop'}
local function reset()c.gpu=true;c.lights=true;c.battle='arena';c.mobile=false;c.width=1920;c.maxTexture=8192;c.profile='desktop'end
local r=R.evaluate(c);test(r.world_light.state=='needs-test','GPU name is not a safety certificate')
c.gpu=false;r=R.evaluate(c);test(r.aa.state=='blocked'and r.world_light.state=='blocked','GPU failure blocks every effect');reset()
c.mobile=true;r=R.evaluate(c);test(r.aa.state=='blocked','mobile supersampling policy');reset()
c.width=8000;c.maxTexture=8192;r=R.evaluate(c);test(r.aa.state=='blocked','texture limit blocks AA');reset()
c.battle=false;r=R.evaluate(c);test(r.battle_light.state=='not-applicable','classic has no battle light');reset()
c.battle='terarrium';r=R.evaluate(c);test(r.terrarium_light.state=='needs-test'and r.battle_light.state=='not-applicable','terrarium owns its light');reset()
c.lights=false;r=R.evaluate(c);test(r.world_light.state=='blocked','renderer failure dominates device profile');reset()
for i,x in ipairs({.06,.04,.025,.018,.010,.006})do test(B.tier(x)==i,'performance tier '..i)end
test(B.p95({.1,.2,.3,.4})==.4,'p95 tail uses observed samples')
local function sample(mean,black,opaque)return {mean=mean,groundBlack=black or 0,groundOpaque=opaque or 1}end
local stable={flickers=0,losses=0};for i=1,80 do I.observe(stable,sample(.5+math.sin(i)*.005))end
test(stable.flickers==0 and stable.losses==0,'small animation is not gross flicker')
local flicker={flickers=0,losses=0};for i=1,8 do I.observe(flicker,sample(i%2==0 and .8 or .3))end
test(flicker.flickers>=3,'repeated alternating luminance flagged')
test(I.compare(sample(.5),sample(.3,.5)),'large new black ground region flagged')
test(I.compare(sample(.5),sample(.3,0,.5)),'ground opacity loss flagged')
test(not I.compare(sample(.5),sample(.4)),'ordinary brightness difference alone not missing floor')
print('UNIT_PASS',count)
local Effects=assert(loadfile(root..'SetupEffects.lua'))({require=function(name)return name=='SetupLocale'and Locale or name=='SetupMeasurement'and Measure or R end})
Effects.refresh=function()end
local a={compatibility=R.evaluate(c),results={}}
local function record(id,change)
 local r={method=2,verdict='pass',on=.017,off=.016,valid=true,exercised=true,visual='ok'};for k,v in pairs(change or {})do r[k]=v end;a.results[id]=r;return Effects.status(a,id,{})
end
test(record('shadows')=='recommended','passing effect recommended')
test(record('shadows',{exercised=false})=='untested','toggle without actual pass rejected')
test(record('shadows',{on=.08,verdict='costly'})=='off','repeatedly costly effect rejected')
test(record('shadows',{visual='bad'})=='off','visual errors dominate FPS')
test(record('world_light',{visual='unknown'})=='review','lighting waits for visual confirmation')
a.combination={verdict='costly'};test(record('shadows')=='uncertain','combined overload does not blame every effect');test(record('battle_light')=='recommended','battle remains independent of world combination')
a.results.shadows={valid=true,exercised=true};test(Effects.status(a,'shadows',{})=='untested','malformed stored metrics cannot pass')
print('ALL_UNIT_PASS',count)

local handle={exports={bootLanguage='de'}};local present=true
local LocaleLive=assert(loadfile(root..'SetupLocale.lua'))({mod={find=function(id)assert(id=='translation-german-universal');return present and handle or nil end}})
test(LocaleLive.text('English','Deutsch')=='Deutsch','Universal German boot selects German')
handle.exports.bootLanguage='en';handle.exports.pendingLanguage='de';test(LocaleLive.text('English','Deutsch')=='English','English boot ignores pending German')
present=false;test(LocaleLive.text('English','Deutsch')=='English','without Universal defaults English')
present=true;handle.exports.bootLanguage=nil;test(LocaleLive.text('English','Deutsch')=='English','installed Universal without German receipt remains English')
local owner={};owner.find=function(self,id)assert(self==owner and id=='translation-german-universal');return {exports={bootLanguage='de'}}end
local MethodLocale=assert(loadfile(root..'SetupLocale.lua'))({mod=owner});test(MethodLocale.text('English','Deutsch')=='Deutsch','method-style public lookup supported')
test(LocaleLive.choice('NATUERLICH')=='NATURAL','owner German labels normalize to English')
handle.exports.bootLanguage='de';test(LocaleLive.choice('OFF')=='AUS','owner English labels normalize to German')
print('ALL_UNIT_AND_LANGUAGE_PASS',count)

local function stat(ms,tail,n)return {median=ms/1000,p95=(tail or ms+.2)/1000,mad=.0001,n=n or 90}end
local function pair(a,b,c,d,budget)return Measure.compare({stat(a),stat(b),stat(c),stat(d)},budget or 1/60)end
local equal=pair(33.4,33.4,33.4,33.4);test(equal.verdict=='pass','33.33 ms is not an off cliff')
test(pair(34.1,33.4,33.5,34).verdict=='pass','reported M2 battle light is not blamed for baseline load')
test(pair(60,60.4,60.5,60).verdict=='pass','slow baseline with negligible cost keeps effect')
test(pair(18.2,33.7,33.6,18.3).verdict=='costly','repeated large world light cost is actionable')
test(pair(4,7,7.1,4.1).verdict=='pass','large percentage with ample headroom is allowed')
test(pair(20,30,30,40).verdict=='uncertain','baseline drift invalidates attribution')
test(pair(20,30,40,20).verdict=='uncertain','on repeat drift invalidates attribution')
test(pair(100,30,30,20).verdict=='uncertain','warmup does not fake an effect speedup')
test(pair(30,20,20,30).verdict=='uncertain','large unexplained speedup requires a retest')
test(pair(32.2,33.8,33.7,32.3).verdict=='pass','small terrarium difference does not disable light')
test(pair(16,20,20,16).verdict=='uncertain','borderline performance preserves choice')
test(Measure.compare({stat(16,50),stat(17),stat(17),stat(16)}).verdict=='uncertain','frame stalls prevent rating')
test(Measure.compare({stat(16,nil,2),stat(17),stat(17),stat(16)}).valid==false,'short segment cannot recommend')
test(Measure.compare({stat(0/0),stat(17),stat(17),stat(16)}).valid==false,'nonfinite measurement cannot recommend')
test(Measure.window(.9,4)=='warmup'and Measure.window(2,4)=='timing'and Measure.window(3.5,4)=='images','image readback has a separate measurement window')
a.combination=nil
test(record('world_light',{verdict='uncertain'})=='uncertain','uncertain performance is neither off nor recommended')
test(record('world_light',{method=1})=='untested','old measurement method is rejected')
test(record('world_light',{imageSuspect=true,visual='unknown'})=='review','image suspicion requests review')
test(record('world_light',{imageSuspect=true,visual='ok'})=='recommended','manual review resolves image suspicion')
print('ALL_MEASUREMENT_UNIT_PASS',count)

local frameScreen={trial={elapsed=2,phaseStart=0,phase=1,plan={{duration=4},{duration=4}},frameSamples={}}}
B.frame(frameScreen,10);B.frame(frameScreen,10+1/60)
test(#frameScreen.trial.frameSamples==1,'one sample per rendered interval')
frameScreen.trial.elapsed=3.5;B.frame(frameScreen,10.08)
test(#frameScreen.trial.frameSamples==1,'readback window excluded from timing')
frameScreen.trial.phase=2;frameScreen.trial.elapsed=2;B.frame(frameScreen,10.1)
test(#frameScreen.trial.frameSamples==1,'phase transition excluded from timing')
frameScreen.trial.paused=true;B.frame(frameScreen,20)
frameScreen.trial.paused=false;frameScreen.trial.resumeWarmup=1;B.frame(frameScreen,20.016)
test(#frameScreen.trial.frameSamples==1,'focus pause and resume warmup excluded')
local tails=Measure.compare({stat(16),stat(16,24),stat(16,24),stat(16)})
test(tails.verdict=='uncertain','tail regression is not hidden by neutral median')
print('ALL_PAIRED_MEASUREMENT_TESTS_PASS',count)

a.combination={verdict='pass',imageSuspect=true};a.results.world_light={method=2,valid=true,exercised=true,verdict='pass',off=.016,on=.016,visual='ok'}
test(Effects.status(a,'world_light',{_visual='unknown'})=='uncertain','combined image suspicion waits for review')
a.combination.visual='ok';test(Effects.status(a,'world_light',{})=='recommended','manual review resolves combined image suspicion')
print('ALL_FINAL_MEASUREMENT_TESTS_PASS',count)

Effects.save=function()end
local function good()return {method=2,valid=true,exercised=true,verdict='pass',visual='ok',off=.016,on=.016}end
for _,e in ipairs(R.effects)do a.results[e.id]=good()end
a.combination=good();a.combination.candidates={world_light=true,aa=true,shadows=true,reflections=true}
Effects.visual(a,'world_light','bad')
test(a.results.world_light.visual=='bad'and a.results.shadows.visual=='ok'and a.results.battle_light.visual=='ok','visual fault is scoped to one effect')
Effects.visual(a,'combined','bad')
test(a.results.shadows.visual=='ok'and Effects.status(a,'shadows',{})=='uncertain','combined fault does not blame each effect')
test(Effects.status(a,'battle_light',{})=='recommended','combined visual fault leaves battle independent')
local d=Effects.details(a,'shadows',{})
test(d.performance=='Passed comparison'and d.combined=='Visual fault in combination','performance and combined image status are separate')
a.combination.visual='ok';a.results.world_light.visual='unknown'
local req=Effects.retest(a,{})
test(req.duration==0,'pending visual review does not repeat timing')
a.combination.verdict='uncertain';req=Effects.retest(a,{})
test(req.duration==24 and req.combo and next(req.ids)==nil,'only unclear combined result repeats 24 seconds')
a.combination=good();a.results.battle_light.verdict='uncertain';req=Effects.retest(a,{})
test(req.duration==24 and req.ids.battle_light and not req.combo,'single unclear battle repeats only itself')
a.results.battle_light=good();a.results.shadows.verdict='uncertain';req=Effects.retest(a,{})
test(req.duration==40 and req.ids.shadows and req.combo,'world retest includes dependent combination')
a.results.shadows=good();a.results.terrarium_light.verdict='uncertain';req=Effects.retest(a,{})
test(req.duration==0,'inactive terrarium does not extend automatic retest')
local plan,seconds=B.plan();test(#plan==29 and seconds==120,'full test stays at 120 seconds')
plan,seconds=B.plan({ids={battle_light=true}})
test(#plan==5 and seconds==24 and plan[2].effect.id=='battle_light'and not plan[2].on and plan[3].on and plan[4].on and not plan[5].on,'targeted battle preserves ABBA and warmup')
plan,seconds=B.plan({ids={shadows=true},combo=true})
test(#plan==9 and seconds==40 and plan[6].combo==false and plan[7].combo==true,'world targeted planner includes four combined phases')
print('SCOPED_CHECKS_UNIT_PASS',count)
local keep={results={world_light=good(),shadows=good(),battle_light=good()},performance={level=4}}
keep.results.shadows.visual='bad';local perf=keep.performance
E.refresh=function()end;E.save=function()end
local screen={effects=keep,draft={},applyRecommendations=function(self,scope)self.appliedScope=scope end}
B.complete(screen,{request={ids={battle_light=true}},metrics={battle_light=good()}})
test(screen.effects.results.shadows.visual=='bad'and screen.performance==perf,'target completion retains unrelated visual evidence and device rating')
test(screen.appliedScope.battle_light and not screen.appliedScope.shadows,'battle completion applies only battle recommendation')
B.complete(screen,{request={ids={world_light=true},combo=true},metrics={world_light=good()},combination={valid=false,verdict='uncertain'}})
test(screen.performance==nil and screen.effects.results.shadows.visual=='bad','new unclear world combination clears only stale device rating')
a.combination=good();a.combination.candidates={shadows=true,reflections=true,aa=true};a.results.world_light=good()
test(Effects.retest(a,{}).combo,'newly eligible effect requires combined retest')
local detail=Effects.details(a,'world_light',{})
test(detail.combined=='Not included','combined coverage does not certify omitted effect')
print('SCOPED_CHECKS_ALL_UNIT_PASS',count)
