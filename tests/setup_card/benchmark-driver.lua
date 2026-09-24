return function(game)
 -- Automated QA continues while Codex is foreground; production still pauses.
 love.window.hasFocus=function()return true end
 io.stdout:setvbuf('no');local U=require('tests.drivers.util');game:startNewGame{intro=false}
 local e=game.mods.exports.VOXEL_ASCENDANT;e.setupCard.suspended=true;e.ascendantContent.onboardingShown=true;e.ascendantContent.promptDisabled=true
 local function find(fn,name,seen)
 if type(fn)~='function'then return end;seen=seen or {};if seen[fn]then return end;seen[fn]=true
 for i=1,200 do local k,v=debug.getupvalue(fn,i);if not k then break end;if k==name then return v end end
 for i=1,200 do local k,v=debug.getupvalue(fn,i);if not k then break end;local x=find(v,name,seen);if x then return x end end end
 local V=assert(find(e.lib.require('VoxelScene').render,'V'))
 local raw=game.update;game.update=function(self,dt)return require('src.mods.Runtime').call('core.update',raw,self,dt)end
 love.window.setMode(1280,800,{resizable=true,vsync=1})
 local screen=e.setupCard.new(game);game.stack:push(screen)
 local root=os.getenv('VASC_SETUP_DEMO_ROOT')..'/evidence/'
 local pages={};for i,p in ipairs(screen.pages)do pages[p.id]=i end
 local function check(v,t)assert(v,t);print('PASS',t)end
 local function page(id)screen.subpage=nil;screen.page=assert(pages[id],id);screen.index=1;screen.message=nil;screen:refreshPreview()end
 local function find(key,action)
  for i,r in ipairs(screen:rows())do if key and r.key==key or action and r.action==action then screen.index=i;return r end end
  error('missing row '..tostring(key)..' / '..tostring(action))
 end
 local function pick(key,value)
  find(key);for i=1,20 do if screen.draft[key]==value then screen:refreshPreview();return end;screen:step(1);find(key)end
  error('cannot select '..key..' = '..tostring(value))
 end
 local function pickkey(key,value) for _,pg in ipairs(screen.pages)do for _,r in ipairs(pg.rows)do if r.key==key then screen.subpage=nil;for i,p in ipairs(screen.pages)do if p==pg then screen.page=i end end;pick(key,value);return end end end end
 game.stack:pop();game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB=true;game.save.flags.EVENT_GOT_STARTER=true;game.save.repelSteps=999999
 game.save.party={require('src.pokemon.Pokemon').new(game.data,'PIKACHU',20)}
 require('src.render.Pipelines').setLevel('voxel',3);U.teleport(game,'ROUTE_1',10,30,'right');U.wait(20);game.stack:push(screen)
 page('device');pick('_device','integrated');page('world');pick('_world','full');page('battle');pick(screen.stageKey,'arena');page('lighting')
 local before={};for k,s in pairs(screen.settings)do before[k]=s:get()end
 local function clone(t)local o={};for k,v in pairs(t)do o[k]=type(v)=='table'and clone(v)or v end;return o end
 local snapshot=clone(game.save);local originalWorld=game.overworld;local originalStack=game.stack.states
 local Storage=require('src.mods.Storage');local storageWrite=Storage.write;local foreignWrites=0;local id=game.save.meta.playthroughId
 Storage.write=function(self,g,key,...)if g and g.save and g.save.meta and g.save.meta.playthroughId==id and not key:find('dein%-look/')then foreignWrites=foreignWrites+1;print('FOREIGN_WRITE',key)end;return storageWrite(self,g,key,...)end
 local save=game.save;local writeOptions,writeSave=game.writeOptions,game.writeSave;local writes=0
 game.writeOptions=function()writes=writes+1 end;game.writeSave=function()writes=writes+1 end
 screen:startBenchmark();check(screen.trial and screen.trial.full,'two minute benchmark starts');local started=love.timer.getTime();local phase=0;local shots={}
 while screen.trial do
  if screen.trial.phase~=phase then phase=screen.trial.phase;print('NATIVE_PHASE',phase)end
  local t=screen.trial;local p=t.plan[t.phase];if p and p.on and t.elapsed-t.phaseStart>3.35 and not shots[p.effect.id]then shots[p.effect.id]=true;U.shot(game,root..'scenario-'..p.effect.id..'.png')end
  U.wait(1);assert(love.timer.getTime()-started<170,'benchmark timeout')
 end
 check(love.timer.getTime()-started>=120,'full 120 second run');check(game.save==save,'original save identity restored');local function same(a,b)for k,v in pairs(a)do if type(v)=='table'then if type(b[k])~='table'or not same(v,b[k])then return false end elseif v~=b[k]then print('SAVE_DIFF',k);return false end end;for k in pairs(b)do if a[k]==nil then print('SAVE_ADDED',k);return false end end;return true end;local resumedTime=(game.save.playTime or 0)-(snapshot.playTime or 0);check(resumedTime>=0 and resumedTime<1,'only normal return-frame play time; no benchmark time charged');snapshot.playTime=game.save.playTime;check(same(snapshot,game.save),'complete save unchanged apart from return-frame clock');check(game.overworld==originalWorld and game.stack.states==originalStack,'complete world and stack restored');Storage.write=storageWrite;check(foreignWrites==0,'no gameplay storage writes in original playthrough');check(writes==0,'zero save/options writes')
 for k,v in pairs(before)do assert(screen.settings[k]:get()==v,'restore '..k)end
 game.writeOptions=writeOptions;game.writeSave=writeSave
 check(screen.effects.combination~=nil,'four combined repeats recorded');if screen.performance then print('PERFORMANCE',screen.performance.level,screen.performance.label,screen.performance.frameMs,screen.performance.lowerBound)else print('PERFORMANCE_UNCERTAIN_NO_RATING')end
 for _,e in ipairs(V.require('SetupEffects').rules.effects)do local r=screen.effects.results[e.id];check(r~=nil,'result '..e.id);check(r.method==2,'paired method '..e.id);print('EFFECT',e.id,r.valid,r.exercised,r.off,r.on,r.verdict,r.reason,r.error);local c=r.coverage;print('SCENARIO',e.id,c.scenario,c.lights,c.rain,c.water,c.moving);if e.id=='world_light'then check(c.lights>=2,'multiple real night lights')elseif e.id=='reflections'then check(c.rain and c.water,'actual rainy water pass')elseif e.scene~='world'then check(c.moving,'actual camera movement '..e.id)end end
 U.shot(game,root..'benchmark-result.png');screen:openEffect('world_light');U.shot(game,root..'benchmark-world-detail.png')
 print('BENCHMARK_PAIRED_120_PASS')
 local E=V.require('SetupEffects');local json={};function json.encode(t)if type(t)~='table'then return tostring(t)end;local keys={};for k in pairs(t)do keys[#keys+1]=k end;table.sort(keys,function(a,b)return tostring(a)<tostring(b)end);local out={};for _,k in ipairs(keys)do out[#out+1]=tostring(k)..'='..json.encode(t[k])end;return '{'..table.concat(out,',')..'}'end
 local function runTarget(id,seconds)
  screen.subpage=nil;page('lighting');local request=E.retest(screen.effects,screen.draft,id)
  check(request.duration==seconds,'target duration '..id)
  local retained={};for key,r in pairs(screen.effects.results)do if not request.ids[key]then retained[key]=json.encode(r)end end
  screen:startBenchmark(false,request);check(screen.trial.duration==seconds,'native targeted duration '..id)
  local begun=love.timer.getTime();while screen.trial do U.wait(1);assert(love.timer.getTime()-begun<seconds+25,'target timeout')end
  for key,value in pairs(retained)do check(json.encode(screen.effects.results[key])==value,'unrelated evidence preserved '..id..' / '..key)end
  check(game.save==save and game.overworld==originalWorld and game.stack.states==originalStack,'target restores world '..id)
  for key,value in pairs(before)do assert(screen.settings[key]:get()==value,'target restores setting '..key)end
 end
 E.visual(screen.effects,'shadows','bad');local oldAA=screen.draft.aa
 runTarget('battle_light',24);check(screen.effects.results.shadows.visual=='bad'and screen.draft.aa==oldAA,'battle retest preserves unrelated report and override')
 runTarget('world_light',40)
 local previousEffects=screen.effects;local previousPerformance=screen.performance
 screen:startBenchmark(false,E.retest(screen.effects,screen.draft,'battle_light'));U.wait(10);screen:stopBenchmark(true)
 check(screen.effects==previousEffects and screen.performance==previousPerformance,'cancelled retest keeps previous evidence')
 print('TARGETED_CHECKS_NATIVE_PASS');love.event.quit()
end
