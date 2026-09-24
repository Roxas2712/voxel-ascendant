return function(game)
 io.stdout:setvbuf('no');local U=require('tests.drivers.util');game:startNewGame{intro=false}
 local e=assert(game.mods.exports.VOXEL_ASCENDANT);e.setupCard.suspended=true;e.ascendantContent.onboardingShown=true;e.ascendantContent.promptDisabled=true
 assert(not game.mods.exports.kanto_ascendant,'standalone fixture must not load KASC')
 local function find(fn,name,seen)
 if type(fn)~='function'then return end;seen=seen or {};if seen[fn]then return end;seen[fn]=true
 for i=1,200 do local k,v=debug.getupvalue(fn,i);if not k then break end;if k==name then return v end end
 for i=1,200 do local k,v=debug.getupvalue(fn,i);if not k then break end;local x=find(v,name,seen);if x then return x end end end
 local V=assert(find(e.lib.require('VoxelScene').render,'V'))
 local screen=e.setupCard.new(game);assert(not screen.kasc and #screen.contexts==3,'standalone contexts')
 local before={};for k,s in pairs(screen.settings)do before[k]=s:get()end
 screen.page=1;screen.subpage=nil;screen.index=1;game.stack:push(screen);love.window.setMode(540,960,{resizable=true,vsync=1});U.wait(4)
 local root=os.getenv('VASC_SETUP_DEMO_ROOT')..'/evidence/'
 U.shot(game,root..'standalone-portrait.png')
 local p=screen.physical
 local function touch(x,y)
  game:touchpressed('qa-finger',p.x+x*p.scale,p.y+y*p.scale,0,0,1)
 end
 local controls=require('src.core.TouchControls');local normal=controls.touchpressed;controls.touchpressed=function()error('hidden pad intercepted setup touch')end
 touch(150,260);controls.touchpressed=normal;U.wait(2)
 assert(game.stack:top()~=screen,'touch keep closes setup')
 for k,v in pairs(before)do assert(screen.settings[k]:get()==v,'keep altered '..k)end
 assert(V.require('SetupCard').receipt(game).done,'keep persisted completion')
 print('PASS standalone touch keep preserves all settings')
 e.setupCard.open(game);screen=game.stack:top();assert(screen.pages,'standalone reopen')
 for i,page in ipairs(screen.pages)do screen.page=i;screen.index=1;screen.subpage=nil;screen:refreshPreview();U.wait(2);U.shot(game,root..'portrait-'..page.id..'.png')end
 screen.page=2;screen.index=1;screen:refreshPreview();U.wait(2)
 love.window.setMode(960,540,{resizable=true,vsync=1});U.wait(3);U.shot(game,root..'standalone-landscape.png')
 assert(e.setupCard.title()=='DEIN LOOK','universal language retained')
 game.stack:pop()
 local control=V.require('VascControls');local setup=e.setupCard;local found=false
 for _,row in ipairs(control.visibleRows(game))do if row.id=='dein-look'then found=true end end
 assert(found,'integrated F3 entry');e.setupCard=nil
 for _,row in ipairs(control.visibleRows(game))do assert(row.id~='dein-look','unavailable setup must not be advertised')end
 e.setupCard=setup;print('PASS setup entry requires installed screen')
 print('STANDALONE_TOUCH_PASS');love.event.quit()
end
