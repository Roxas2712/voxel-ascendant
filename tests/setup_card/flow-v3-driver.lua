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
 local before={};for k,s in pairs(screen.settings)do before[k]=s:get()end
 check(#screen.pages==9 and pages.device==2,'nine steps, device first')
 page('device');screen:next();check(screen.page==pages.device,'device selection required')
 pick('_device','mobile');check(screen.draft.sceneResolution=='economy' and screen.draft.localLights==false and screen.draft.aa==0,'safe mobile preset')
 pick('_device','integrated');check(screen.draft.sceneResolution=='balanced' and screen.draft.arenaCamera=='fixed3x','notebook preset and calm camera')
 page('people');for _,v in ipairs({'classic','hd','voxel'})do pick('_people',v);check(screen.draft.apo_human_acting_pilot==(v~='classic'),'dialogue follows '..v)end
 page('pokemon');check(#screen.contexts==4,'four separate world contexts')
 pick('_follower','stadium2');local r=find(nil,'rom');check(r.source=='stadium2','Stadium import immediately follows source')
 U.wait(3);U.shot(game,root..'new-import.png')
 pick('_follower','full_hd');local r=find(nil,'content');check(r.source=='full_hd','HD download action follows source')
 local savedSource=screen.draft._follower
 screen:openAcquisition(r);U.wait(4);check(game.stack:top()~=screen,'native package menu opened')
 while game.stack:top()~=screen do game.stack:pop()end;U.wait(3)
 check(screen.draft._follower==savedSource and screen.page==pages.pokemon,'returns to same draft and page')
 -- Optional batch affects only explicitly selected contexts.
 screen.subpage=screen.optional.base;screen.index=1;screen.draft._base='cobblemon'
 for _,c in ipairs(screen.contexts)do screen.draft['_include_'..c[1]]=c[1]=='town' end
 local follower=screen.draft._follower;find(nil,'base');screen:choose()
 check(screen.draft._town=='cobblemon' and screen.draft._follower==follower,'scoped preset preserves excluded context')
 page('dex');pick('modernDexSpriteSource','kasc_crystal');screen:refreshPreview();U.wait(4)
 check(screen.preview.source=='crystal' and screen.preview.image~=nil and not screen.preview.error,'real Crystal Dex preview')
 U.shot(game,root..'new-dex.png')
 pick('modernDexSpriteSource','active');U.wait(4);check(screen.preview.image~=nil and not screen.preview.error,'active Dex provider preview')
 page('battle');pick('_battleGraphics','hd');check(screen.draft.battleSpriteStyle=='hd' and screen.draft.battleHdSprites==true and screen.draft.pokemonModelSkin=='crystal','HD is one consistent battle type')
 pick('_battleGraphics','crystal');check(screen.draft.battleHdSprites==false and screen.draft.battleSpriteStyle=='crystal','Crystal disables HD override')
 pick(screen.stageKey,false);pick('_battleGraphics','cobblemon');check(screen.draft[screen.stageKey]=='arena','3D chooses supported arena')
 pick(screen.stageKey,false);check(screen.draft._battleGraphics=='crystal','classic scene selects compatible sprite')
 for _,r in ipairs(screen:rows())do check(r.key~='battleHdSprites' and r.key~='arenaCamera','no conflicting battle switches')end
 U.wait(3);U.shot(game,root..'new-battle.png')
 page('world');screen:startBenchmark(true);check(not screen.trial and screen.message:find('draußen'),'indoor world preview explicitly refused')
 game.stack:pop();game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB=true;game.save.flags.EVENT_GOT_STARTER=true;game.save.repelSteps=999999
 game.save.party={require('src.pokemon.Pokemon').new(game.data,'PIKACHU',20)}
 require('src.render.Pipelines').setLevel('voxel',3);U.teleport(game,'ROUTE_1',10,30,'right');U.wait(15);game.stack:push(screen)
 pick('_world','full');local count=0;local writer=game.writeOptions;game.writeOptions=function()count=count+1 end
 local trialBefore={};for k,s in pairs(screen.settings)do trialBefore[k]=s:get()end
 screen:startBenchmark(true);check(screen.trial and screen.isOpaque==false,'world preview exposes real outdoor scene');U.wait(120);U.shot(game,root..'new-world-live.png');screen:stopBenchmark(true)
 check(count==0,'world preview writes no options');for k,v in pairs(trialBefore)do check(screen.settings[k]:get()==v,'trial restores '..k)end
 page('pokemon');screen.subpage=screen.optional.finish;screen.detailsOpen=true;screen.index=1
 find(nil,'detailtest');screen:choose();check(screen.trial and screen.trial.details,'optional details use real A/B scene')
 U.wait(8);U.shot(game,root..'new-details-a.png')
 local frames=0;while screen.trial and screen.trial.phase==1 and frames<1200 do U.wait(1);frames=frames+1 end
 check(screen.trial and screen.trial.phase==2,'detail comparison reaches draft phase');U.shot(game,root..'new-details-b.png')
 while screen.trial and frames<2400 do U.wait(1);frames=frames+1 end
 check(not screen.trial and count==0,'detail comparison returns without writes')
 game.writeOptions=writer
 -- Trial restoration compares against the values before the trial (pipeline presets may have run before it).
 page('device');pick('_device','keep');page('people');pick('_people','hd')
 page('pokemon');for _,c in ipairs(screen.contexts)do screen:stageContext(c,'classic')end
 page('battle');pick('_battleGraphics','crystal')
 local writes=0;game.writeOptions=function()writes=writes+1 end
 page('summary');check(screen:apply(),'consistent draft applies');check(writes==1,'one final options write');game.writeOptions=writer
 check(game.save.options.modOptions.VOXEL_ASCENDANT.battleSpriteStyle=='crystal','battle style persisted')
 local reopened=e.setupCard.new(game);check(reopened.draft.battleSpriteStyle=='crystal','battle style reloads');reopened.preview:release()
 local BC=V.require('BattleSpriteControl');check(BC.choice({player={},enemy={}})=='crystal','new battle consumes persistent unified style')
 local setup=e.setupCard
 -- Menu integrations use actual native entry points.
 game:keypressed('f3');local found=false;local panel=game.stack:top();for _,r in ipairs(panel.rows or {})do if r.id=='dein-look'then found=true end end;check(found,'F3 entry available');game:keypressed('f3')
 while game.stack:top()~=game.overworld do game.stack:pop()end
 game.mods.exports.kanto_ascendant.ascendantMenu.open(game,{})
 found=false;for _,rootMenu in ipairs(game.stack.states)do for _,r in ipairs(rootMenu.items or {})do if r.label=='DEIN LOOK'then found=true end end end;check(found,'KASC menu entry available')
 while game.stack:top()~=game.overworld do game.stack:pop()end
 setup.open(game);check(game.stack:top().draft~=nil,'VASC registered screen opens');game.stack:pop()
 -- Automatic first use once, and a new playthrough gets a new receipt.
 e.setupCard.suspended=false;U.wait(3);check(game.stack:top()==game.overworld,'completed setup does not reappear')
 game:startNewGame{intro=false};U.wait(3);check(game.stack:top()~=game.overworld and game.stack:top().draft~=nil,'new playthrough opens setup')
 local auto=game.stack:top();auto.index=2;auto:choose();U.wait(3);check(game.stack:top()==game.overworld,'keep current completes once')
 print('NINE_STEP_FLOW_AND_LIFECYCLE_PASS');love.event.quit()
end

