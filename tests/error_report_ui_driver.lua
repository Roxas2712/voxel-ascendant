return function(game)
 local U=require('tests.drivers.util');game:startNewGame{intro=false}
 local e=assert(game.mods.exports.VOXEL_ASCENDANT);e.setupCard.suspended=true;e.ascendantContent.promptDisabled=true;e.ascendantContent.onboardingShown=true
 local errors=assert(e.errors);U.teleport(game,'ROUTE_2',7,6,'down');U.wait(30)
 errors.poll(game);local inbox=errors.inbox;inbox.items={};inbox.unread=0
 local long="TEST FIXTURE: Cannot compile pixel shader code: Line 28: ERROR: 'patch': Syntax error. "..string.rep('Compiler detail for pagination test. ',25)
 inbox:observe('battle-scene-error',{reason=long,requested='TERRARIUM',actual='SCENE FAILED',phase='menu',shader='Dome',candidateCount=3})
 local r=inbox:observe('battle-native-latch',{reason='TEST FIXTURE: scene-render-timeout: camera-unavailable:playerHero-under-command',provider='DISCS',phase='scene-render-timeout'})
 assert(r.engine~='?' and #r.details>4 and #r.related==1)
 local copied=assert(errors.reportText(r));assert(copied:find('patch',1,true))
 for _,portrait in ipairs{true,false}do
  love.window.setMode(portrait and 540 or 1170,portrait and 960 or 540,{resizable=true,vsync=1})
  errors.open(game);local s=game.stack:top();s:choose('open');U.wait(2)
  local count=s.pageCount;assert(count>=2,'expected full report pagination')
  for page=1,count do
   s.page=page;U.wait(2);assert(s.contentBottom<s.buttonsTop,'report overlaps controls')
   assert(U.shot(game,os.getenv('BATTLE_QA')..'/errors-'..(portrait and 'portrait' or 'landscape')..'-'..page..'.png'))
  end
  s:choose('open');assert(s.copyNotice and s.copyNotice:find('unavailable',1,true),'sandbox must not claim copy success');assert(copied:find('renderer:',1,true))
  print('ERROR_UI_PASS',portrait and 'portrait' or 'landscape','pages',count,'engine',r.engine,'bytes',#copied)
  game.stack:pop()
 end
 print('ERROR_REPORT_UI_PASS');love.event.quit()
end
