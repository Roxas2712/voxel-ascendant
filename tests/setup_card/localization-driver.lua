return function(game)
 io.stdout:setvbuf('no');local U=require('tests.drivers.util');game:startNewGame{intro=false}
 local e=game.mods.exports.VOXEL_ASCENDANT;e.setupCard.suspended=true;e.ascendantContent.onboardingShown=true;e.ascendantContent.promptDisabled=true
 local function find(fn,name,seen)
 if type(fn)~='function'then return end;seen=seen or {};if seen[fn]then return end;seen[fn]=true
 for i=1,200 do local k,v=debug.getupvalue(fn,i);if not k then break end;if k==name then return v end end
 for i=1,200 do local k,v=debug.getupvalue(fn,i);if not k then break end;local x=find(v,name,seen);if x then return x end end end
 local V=assert(find(e.lib.require('VoxelScene').render,'V'))
 local universal=assert(V.mod.find('translation-german-universal'));local originalBoot=universal.exports.bootLanguage
 local first=e.setupCard.new(game);local settings={};for _,s in pairs(first.settings)do settings[#settings+1]={s}end
 local root=os.getenv('VASC_SETUP_DEMO_ROOT');local modules={'SetupLocale','SetupMeasurement','SetupEffectRules','SetupEffects','SetupBenchmark','SetupPreview','SetupCard'};local localized={};for _,n in ipairs(modules)do localized[n]=true end
 local originalDraw=game.draw;local screen
 game.draw=function(self,...)originalDraw(self,...);if screen then screen:drawPhysical()end end
 local function build(language)
  universal.exports.bootLanguage=language
  local cache={};local proxy=setmetatable({},{__index=V})
  proxy.require=function(name)
   if not localized[name]then return V.require(name)end
   if not cache[name]then cache[name]=assert(loadfile(root..'/host/mods/VOXEL_ASCENDANT/lib/'..name..'.lua'))(proxy)end
   return cache[name]
  end
  screen=proxy.require('SetupCard').new(game,settings);screen.page=1;return proxy
 end
 local function check(v,t)assert(v,t);print('PASS',t)end
 love.window.setMode(1280,800,{resizable=true,vsync=1})
 for _,mode in ipairs({'en','de'})do
  local proxy=build(mode);game.stack:push(screen)
  check(screen.pages[1].title==(mode=='en'and 'Your adventure. Your look.'or 'Dein Abenteuer. Dein Look.'),'native '..mode..' welcome')
  check(e.setupCard.title()==(mode=='en'and 'YOUR LOOK'or 'DEIN LOOK'),'public menu title '..mode)
  check(proxy.require('SetupBenchmark').tiers[1]==(mode=='en'and 'Weak'or 'Schwach'),'six tiers '..mode)
  check(proxy.require('SetupEffectRules').effects[1].label==(mode=='en'and 'World lighting'or 'Weltlicht'),'compatibility labels '..mode)
  for i,p in ipairs(screen.pages)do
   screen.page=i;screen.subpage=nil;screen.index=1;screen.message=nil;screen:refreshPreview();U.wait(2)
   U.shot(game,root..'/evidence/v3-'..mode..'-'..p.id..'.png')
   print('PAGE',mode,p.id,p.title)
   for _,r in ipairs(screen:rows())do print('ROW',mode,p.id,r.label,r.help or '',r.key and screen:label(r)or '')end
  end
  for key,p in pairs(screen.optional)do
   screen.subpage=p;screen.detailsOpen=true;screen.index=1;screen:refreshPreview();U.wait(1)
   for _,r in ipairs(screen:rows())do print('OPTION',mode,key,r.label,r.help or '',r.key and screen:label(r)or '');for _,c in ipairs(r.choices or {})do print('CHOICE',mode,key,c[1]);if mode=='en'then assert(not c[1]:find('NATUERLICH')and not c[1]:find('FLACHE SCHICHTEN'),'untranslated choice')end end end
  end
  local effects=proxy.require('SetupEffects');effects.refresh(screen.effects,screen.draft)
  screen.effects.results.world_light={method=2,valid=true,exercised=true,verdict='pass',visual='bad',off=.016,on=.017,coverage={scenario='night-windows',lights=8}}
  screen.effects.combination={method=2,valid=true,verdict='uncertain',off=.017,on=.018}
  screen:openEffect('world_light');U.wait(1);U.shot(game,root..'/evidence/scoped-'..mode..'-detail-layout.png')
  local detail=effects.details(screen.effects,'world_light',screen.draft)
  check(detail.performance==(mode=='en'and 'Passed comparison'or 'Vergleich bestanden'),'independent performance label '..mode)
  check(screen:rows()[2].label==(mode=='en'and 'Flickering / missing surfaces here'or 'Hier Flackern / fehlende Flächen'),'scoped image report label '..mode)
  screen.subpage=nil;screen.page=8;screen.index=1;screen.performance={level=4,lowerBound=true,label=mode=='en'and 'Schwach'or 'Weak',resolution='native',renderMs=16.7}
  screen.effects.performance=screen.performance;U.wait(2);U.shot(game,root..'/evidence/v3-'..mode..'-result-layout.png')
  love.window.setMode(1024,768,{resizable=true,vsync=1});screen.performance=nil;screen.effects.performance=nil;U.wait(2);U.shot(game,root..'/evidence/v3-'..mode..'-small.png')
  effects.refresh(screen.effects,screen.draft);screen.effects.results.world_light={method=2,valid=true,exercised=true,verdict='uncertain',reason='stalls',visual='unknown',off=.016,on=.017,coverage={scenario='night-windows',lights=8}};screen.effects.combination={method=2,valid=true,verdict='uncertain',off=.017,on=.018};screen:openEffect('world_light');U.wait(1);U.shot(game,root..'/evidence/scoped-'..mode..'-small-detail.png');love.window.setMode(1280,800,{resizable=true,vsync=1});game.stack:pop();screen=nil
 end
 -- No published language receipt, even with the package installed, must be English.
 local proxy=build(nil);check(screen.pages[1].title=='Your adventure. Your look.','native missing receipt defaults English');screen=nil
 universal.exports.bootLanguage=originalBoot;game.draw=originalDraw
 print('LOCALIZATION_V3_PASS');love.event.quit()
end
