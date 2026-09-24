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
 local screen=e.setupCard.new(game);game.stack:push(screen);U.wait(5)
 local root=os.getenv('VASC_SETUP_DEMO_ROOT')..'/evidence/'

 local function check(value,name)assert(value,name);print('PASS',name)end
 local C=V.require('CobblemonContent');check(C.complete()and C.available(25,'normal')and C.included()and not C.requiresDownload(),'bundled models ready at boot without installation')
 local cacheReads,cacheWrites,network=0,0,0
 local modProxy=setmetatable({cache={read=function()cacheReads=cacheReads+1;return nil end,write=function()cacheWrites=cacheWrites+1;error('cache must remain read-only')end}}, {__index=V.mod})
 function modProxy:read(path)return V.mod:read(path)end
 local proxy=setmetatable({mod=modProxy},{__index=V})
 local clean=assert(loadfile(os.getenv('VASC_SETUP_DEMO_ROOT')..'/host/mods/VOXEL_ASCENDANT/lib/CobblemonContent.lua'))(proxy)
 check(clean.complete()and clean.available(),'empty read-only cache needs no setup receipt')
 for _,dex in ipairs({1,25,133,152,252})do
  for _,variant in ipairs({'normal','shiny'})do local model=clean.record(dex,variant);check(model and model.texture,'prepared record '..dex..' / '..variant)end
 end
 local ok=clean.start();check(ok and not clean.busy()and cacheWrites==0,'legacy start is harmless for included content')
 local Pack=V.require('CobblemonPack')
 for _,mon in ipairs({{species='PIKACHU',dex=25},{species='TREECKO',dex=252}})do
  local model=Pack.load(mon.dex,mon);check(model~=nil and Pack.image(model,1)~=nil,'real model and texture without setup '..mon.species)
 end
 screen.page=4;screen.index=1;screen.draft._follower='cobblemon';screen:refreshPreview();U.wait(3);check(not screen.preview.error,'native Cobblemon preview uses bundled model');U.shot(game,root..'cobblemon-bundled-preview.png')
 -- Open the actual download menu to initialize its native guided-menu factory.
 screen:openAcquisition(screen:acquisition('full_hd'));while game.stack:top()~=screen do game.stack:pop()end
 local session=e.ascendantContent;local original=e.cobblemonContent;local oldPlan=session.planFor;local installed=session.catalog.installed
 local function forbidden()network=network+1;error('Cobblemon download must never start')end
 for _,de in ipairs({false,true})do
  session.de=de;local page=session:openCobblemon();U.wait(2)
  for _,r in ipairs(page.items)do check(r.action~='download'and r.action~='cancel','native Cobblemon page has no installer action')end
  U.shot(game,root..'cobblemon-native-'..(de and 'de'or 'en')..'.png');game.stack:pop()
 end
 local damaged={version=C.version,available=function()return false end,complete=function()return false end,requiresDownload=function()return false end,busy=function()return false end,status=function()return {phase='idle',message=''}end,update=function()end,start=forbidden,size=function()return 45059925 end}
 e.cobblemonContent=damaged
 check(not session:needsCobblemonDownload(),'missing bundled models are not classified as a download')
 session.catalog.installed=function()return true end;check(not session:hasAvailableDownloads(),'Cobblemon alone cannot trigger startup download prompt')
 session.planFor=function()return {ready=true,canDownload=false,downloadBytes=0,missing={}}end
 local notices={};local oldNotice=session.notice;session.notice=function(_,message)notices[#notices+1]=message end
 local depth=#game.stack.states;session:confirmDownload({},true);check(#game.stack.states==depth and notices[#notices]=='already_installed','completed base pack does not redirect to Cobblemon installer')
 local menu=session:menu(game,session.guided,true);game.stack:push(menu);menu:downloadAll();check(game.stack:top()==menu and network==0,'download-all never adds bundled Cobblemon');game.stack:pop()
 local missing=session:openCobblemon();U.wait(1);U.shot(game,root..'cobblemon-native-missing.png')
 local found=false;for _,r in ipairs(missing.items)do if r.label=='STATUS'then found=r.right=='DATEIEN PRUEFEN'end;check(r.action~='download','missing models do not show install')end;check(found,'missing models show honest file diagnosis');game.stack:pop()
 session.cobblemonQueued=true;session.cobblemonBatch=true;session:update(game,0);check(not session.cobblemonQueued and not session.cobblemonBatch and network==0,'legacy queued Cobblemon job is discarded without download')
 session.notice=oldNotice;session.planFor=oldPlan;session.catalog.installed=installed;e.cobblemonContent=original
 check(cacheWrites==0 and network==0,'zero cache writes and zero Cobblemon downloads')
 print('COBBLEMON_BUNDLED_NATIVE_PASS');love.event.quit()
end
