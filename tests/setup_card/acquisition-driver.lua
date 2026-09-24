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
 screen.page=4;screen.index=1;screen.draft._follower='stadium2';screen:refreshPreview()
 local module=V.require('SetupCard');local rom=assert(module.rom);local called=0;local choose=rom.choose
 rom.choose=function(g)assert(g==game);called=called+1;return false end
 screen:openAcquisition(screen:acquisition('stadium2'));assert(called==1 and game.stack:top()==screen);rom.choose=choose
 print('DIRECT_STADIUM_PICKER_DISPATCH_PASS')
 local C=V.require('CobblemonContent');local originalAvailable=C.available;local originalStart=C.start;local starts=0
 C.start=function()starts=starts+1;error('Cobblemon acquisition must not start')end
 for _,ready in ipairs({true,false})do
  C.available=function(dex,variant)assert(dex==25 and variant=='normal');return ready end
  local row=screen:acquisition('cobblemon');assert(row and not row.action and not row.choices,'Cobblemon is information only')
  screen:openAcquisition(row);assert(game.stack:top()==screen and starts==0,'no Cobblemon install or download')
  print('COBBLEMON_INFORMATION_ONLY',ready,row.label)
 end
 C.available=originalAvailable;C.start=originalStart
 screen.draft._follower='cobblemon';screen.index=1;screen.message=nil;screen:refreshPreview();U.wait(3);U.shot(game,root..'cobblemon-included.png')
 print('COBBLEMON_NO_INSTALL_PASS')
 for _,source in ipairs({'full_hd','crystal','pokemmo'})do
  screen:openAcquisition(screen:acquisition(source));U.wait(4)
  local top=game.stack:top();print('PACKAGE_TARGET',source,top.title,top.key)
  U.shot(game,root..'download-'..source..'.png')
  while game.stack:top()~=screen do game.stack:pop()end
 end
 for i,p in ipairs(screen.pages)do
  screen.page=i;screen.index=1;screen.message=nil;screen:refreshPreview();U.wait(3)
  U.shot(game,root..string.format('layout-%02d.png',i))
 end
 print('ACQUISITION_LAYOUT_PASS');love.event.quit()
end
