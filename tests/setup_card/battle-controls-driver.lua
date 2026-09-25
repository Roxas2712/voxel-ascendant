return function(game)
 io.stdout:setvbuf('no');local U=require('tests.drivers.util');game:startNewGame{intro=false}
 local e=assert(game.mods.exports.VOXEL_ASCENDANT);e.setupCard.suspended=true;e.ascendantContent.promptDisabled=true;e.ascendantContent.onboardingShown=true
 local root=assert(os.getenv('BUTTONS_QA'))
 local screen=e.setupCard.new(game);local before={};for k,s in pairs(screen.settings)do before[k]=s:get()end
 local idx;for i,p in ipairs(screen.pages)do if p.id=='battle_controls'then idx=i end end;assert(idx,'controls page absent');screen.page=idx;screen.index=1;game.stack:push(screen)
 local hud=assert(e.orasBattleHud);assert(hud.controlsPreview)
 for _,case in ipairs{{'edge','auto',0,1,0},{'auto-raised','auto',25,1,0},{'complete','round',0,1,0},{'raised-original','original',25,.75,20},{'glass','glass',15,1,0}}do
  screen.draft.battle_controls_shape=case[2];screen.draft.battle_controls_y=case[3];screen.draft.battle_controls_scale=case[4];screen.draft.battle_controls_x=case[5]
  for _,size in ipairs{{1100,760,'landscape'},{540,960,'portrait'}}do
   love.window.setMode(size[1],size[2],{resizable=true,vsync=1});screen:refreshPreview();U.wait(5)
   assert(not screen.message,tostring(screen.message));assert(hud.optionSnapshot==nil,'preview leaked draft snapshot');assert(hud.commandDetached==nil,'preview leaked dock state')
   assert(U.shot(game,root..'/'..case[1]..'-'..size[3]..'.png'))
   for k,v in pairs(before)do assert(screen.settings[k]:get()==v,'preview changed live setting '..k)end
  end
 end
 print('PASS actual preview: all shapes, both orientations, draft isolated')
 -- Save later, reopen, then reset explicitly and apply. No user save is used.
 screen:pause();screen=e.setupCard.new(game);assert(screen.draft.battle_controls_shape=='glass','draft not restored');game.stack:push(screen)
 screen.page=idx;screen.index=5;screen:choose()
 assert(screen.draft.battle_controls_shape=='auto' and screen.draft.battle_controls_y==0 and screen.draft.battle_controls_x==0 and screen.draft.battle_controls_scale==1,'edge reset incomplete')
 for k,v in pairs(before)do assert(screen.settings[k]:get()==v,'reset wrote live setting '..k)end
 screen.draft.battle_controls_shape='original';screen.draft.battle_controls_y=25;screen.draft._device='keep'
 assert(screen:apply(),tostring(screen.message));assert(screen.settings.battle_controls_shape:get()=='original','apply callback overrode ORIGINAL')
 local reopened=e.setupCard.new(game);assert(reopened.draft.battle_controls_shape=='original' and reopened.draft.battle_controls_y==25,'settings not retained on reopen')
 screen.settings.battle_controls_y:setValue(30,game);assert(screen.settings.battle_controls_shape:get()=='original','ordinary setting change overrode ORIGINAL')
 print('PASS draft resume, reset, apply, reopen and position callback')
 print('BUTTONS_SETUP_DONE');love.event.quit()
end
