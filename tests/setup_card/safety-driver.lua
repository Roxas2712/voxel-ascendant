return function(game)
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
 game.stack:pop();V.mod.storage:delete(game,'dein-look/v1');e.setupCard.suspended=false;e.ascendantContent.onboardingShown=false;e.ascendantContent.offerRequested=false
 U.wait(2);local offer=game.stack:top();check(offer~=game.overworld and offer~=screen,'startup offer before setup')
 local skip;for i,r in ipairs(offer.items or {})do if r.action=='skip'then skip=i end end;check(skip~=nil,'native download offer owns startup')
 U.shot(game,root..'v3-download-first.png');offer.index=skip;U.tap(game,'a');U.wait(3)
 local setup=game.stack:top();check(setup.pages and setup.pages[2].id=='device','setup follows completed download offer');e.setupCard.suspended=true
 game.stack:pop();game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB=true;game.save.flags.EVENT_GOT_STARTER=true;game.save.repelSteps=999999
 game.save.party={require('src.pokemon.Pokemon').new(game.data,'PIKACHU',20)}
 require('src.render.Pipelines').setLevel('voxel',3);U.teleport(game,'ROUTE_1',10,30,'right');U.wait(10);game.stack:push(screen)
 page('device');pick('_device','integrated');page('lighting')
 local function clone(t)local o={};for k,v in pairs(t)do o[k]=type(v)=='table'and clone(v)or v end;return o end;local oldSave=game.save;local saveSnapshot=clone(game.save);local oldWorld=game.overworld;local oldMap=oldWorld.map;local oldX,oldY=oldWorld.player.px,oldWorld.player.py;local oldStack=game.stack.states;local oldOptions=game.writeOptions;local oldWrite=game.writeSave;local writes=0;game.writeOptions=function()writes=writes+1 end;game.writeSave=function()writes=writes+1 end
 local before={};for k,v in pairs(screen.settings)do before[k]=v:get()end
 local originalIdle=V.require('TerarriumHost').service.idleSample;local originalWeather=V.require('Weather').clock
 screen:startBenchmark();check(V.require('SetupEffects').tracking==true,'camera diagnostics active during check');check(game.save~=oldSave,'isolated benchmark save');game.save.player.name='BENCHMARK ONLY';U.wait(15);screen:stopBenchmark(true)
 check(V.require('SetupEffects').tracking==false,'camera diagnostics stop outside check')
 check(V.require('TerarriumHost').service.idleSample==originalIdle and V.require('Weather').clock==originalWeather,'cancel restores animation function and weather clock')
 check(game.save==oldSave and game.save.player.name~='BENCHMARK ONLY','cancel restores original save and progress')
 check(game.overworld==oldWorld and oldWorld.map==oldMap and oldWorld.player.px==oldX and oldWorld.player.py==oldY and game.stack.states==oldStack,'original world and menu stack restored')
 for k,v in pairs(before)do assert(screen.settings[k]:get()==v,'cancel restores '..k)end
 local diffs=0;local function diff(a,b,p)for k,v in pairs(a)do if type(v)=='table'and type(b[k])=='table'then diff(v,b[k],p..'.'..k)elseif v~=b[k]then diffs=diffs+1;print('SAVE_DIFF',p..'.'..k,tostring(v),tostring(b[k]))end end;for k,v in pairs(b)do if a[k]==nil then diffs=diffs+1;print('SAVE_ADDED',p..'.'..k,tostring(v))end end end;diff(saveSnapshot,game.save,'save');check(diffs==0,'entire original save unchanged after cancel');check(writes==0,'cancel writes no save/options');game.writeOptions=oldOptions;game.writeSave=oldWrite
 local E=V.require('SetupEffects');screen.effects=E.new(game,screen.draft);check(screen.effects.probe.ok,'actual shader/depth/readback preflight')
 E.refresh(screen.effects,screen.draft)
 for _,effect in ipairs(E.rules.effects)do screen.effects.results[effect.id]={method=2,verdict='pass',valid=true,exercised=true,off=.016,on=.017,visual='ok'}end
 screen.effects.combination=nil;screen:applyRecommendations();check(screen.draft.shadows and screen.draft.aa==2,'recommendations preselect passing effects')
 screen.effects.results.shadows.error='injected render failure';screen:applyRecommendations();check(screen.draft.shadows==false,'failure overrides high speed')
 screen.effects.results.aa.exercised=false;screen:applyRecommendations();check(screen.draft.aa==2,'unexercised result preserves selected AA')
 screen.effects.results.shadows={method=2,verdict='uncertain',valid=true,exercised=true,off=.034,on=.034,visual='ok'};screen.draft.shadows=true;screen:applyRecommendations();check(screen.draft.shadows==true,'uncertain measurement preserves selected shadows')
 screen.draft.water='full';screen.draft.battleLights=true;screen:openEffect('world_light');screen.index=2;screen:choose();check(screen.draft.localLights==false and screen.draft.water=='full'and screen.draft.battleLights==true and screen.draft.shadows==true,'one visual failure affects only world light');screen.subpage=nil
 screen.effects.results.shadows={valid=true};screen.draft.sceneResolution=screen.draft.sceneResolution=='native'and 'balanced'or 'native';E.refresh(screen.effects,screen.draft);check(next(screen.effects.results)==nil,'resolution change invalidates evidence')
 screen.performance=nil
 for i,pg in ipairs(screen.pages)do screen.page=i;screen.subpage=nil;screen.index=1;screen.message=nil;screen:refreshPreview();U.wait(2);U.shot(game,root..'v3-page-'..pg.id..'.png')end
 love.window.setMode(1024,768,{resizable=true,vsync=1});page('lighting');U.wait(3);U.shot(game,root..'v3-small-graphics.png')
 print('STARTUP_SAFETY_PASS');love.event.quit()
end
