return function(game)
 io.stdout:setvbuf('no');assert((os.getenv('POKEPORT_IDENTITY')or''):match('^vasc%-.*%-qa$'))
 love.window.hasFocus=function()return true end;love.window.isVisible=function()return true end
 local U=require('tests.drivers.util');local Screens=require('src.ui.Screens');local gen2=os.getenv('POKEPORT_VERSION')=='crystal'
 if gen2 then
  local save=require('src.core.gen2.Save').newGame{version='crystal',playerName='MENUQA'}
  game.save=save;game:adoptSave(save);game.world.save=save;require('src.mods.Runtime').emit('save.created',{game=game,save=save});game:continueGame(save)
 else game:startNewGame{intro=false}end
 local e=assert(game.mods.exports.VOXEL_ASCENDANT);if e.setupCard then e.setupCard.suspended=true end
 local content=assert(e.ascendantContent);content.promptDisabled=true;content.onboardingShown=true
 local out=assert(os.getenv('MENU_QA'));U.wait(10)
 local floor=#game.stack.states;local function clear()while #game.stack.states>floor do game.stack:pop()end end


 love.window.setMode(1100,760,{resizable=true,vsync=1})
 local errors,values,blocked,actions=0,0,0,0
 local function findOwner(fn)
  for i=1,30 do local name,value=debug.getupvalue(fn,i);if not name then break end;if name=='self_'and type(value)=='table'and value.values then return value end end
 end
 local hub=Screens.push(game,'VascMenu');hub.showFirstGuide=function()return false end
 local sections={};for _,r in ipairs(hub.items)do if r.section then sections[#sections+1]=r.section end end;clear()
 for _,id in ipairs(sections)do
  local menu=Screens.push(game,'VascSettings',{section=id});menu.showFirstGuide=function()return false end;U.wait(1)
  local rows={};for _,r in ipairs(menu.items)do rows[#rows+1]=r end
  for index,row in ipairs(rows)do
   if row.descriptor and type(row.descriptor.step)=='function'then
    local owner=findOwner(row.descriptor.step)
    if owner then
     local original=owner:get();local change=owner.change
     if change then owner.change=function(...)
      local ok,why=pcall(change,...);if not ok then errors=errors+1;print('CALLBACK_ERROR',row.settingKey,why);error(why)end
     end end
     for i,value in ipairs(owner.values)do
      local previous=(i-2)%#owner.values+1
      owner:setValue(owner.values[previous],game,true)
      local expected=i
      for _=1,#owner.values do if owner:allows(expected)then break end;expected=expected%#owner.values+1 end
      local yes,result=pcall(row.descriptor.step,game,1)
      local redirected=game.stack:top()~=menu
      while game.stack:top()~=menu and #game.stack.states>floor do game.stack:pop()end
      local actual=owner:get();local verdict='PASS'
      if not yes then errors=errors+1;verdict='ERROR:'..tostring(result)
      elseif redirected then blocked=blocked+1;verdict='CONTENT_GATE'
      elseif actual~=owner.values[expected]then errors=errors+1;verdict='MISMATCH expected '..tostring(owner.values[expected])end
      values=values+1
      print('SETTING_VALUE',id,row.settingKey,tostring(value),tostring(actual),verdict)
      -- Exercise a real rendered frame with each reachable option value.
      U.wait(1)
     end
     owner.change=change
     owner:setValue(original,game,true);if owner.change then local ok,why=pcall(owner.change,game,original,owner.index);if not ok then errors=errors+1;print('RESTORE_ERROR',row.settingKey,why)end end
    else
     local before=row.descriptor.value and row.descriptor.value();local ok,why=pcall(row.descriptor.step,game,1)
     while game.stack:top()~=menu and #game.stack.states>floor do game.stack:pop()end
     if not ok then errors=errors+1;print('DESCRIPTOR_ERROR',row.settingKey,why)end
     pcall(row.descriptor.step,game,-1);print('CUSTOM_DESCRIPTOR',id,row.settingKey or row.label,tostring(before))
    end
   elseif row.screen or row.action then
    if row.action=='stadiumRom'then print('ACTION_MOCK_COVERAGE',id,'stadiumRom')
    else
     menu.index=index;local ok,why=pcall(function()U.tap(game,'a');U.wait(1);if row.screen then assert(game.stack:top()~=menu,'screen action did not open '..row.screen)end end)
     if not ok then errors=errors+1;print('ACTION_ERROR',id,row.action or row.screen,why)else actions=actions+1;print('ACTION_OPEN',id,row.action or row.screen)end
     while game.stack:top()~=menu and #game.stack.states>floor do game.stack:pop()end
    end
   end
  end
  -- Reopen after callbacks so conditional rows and displayed values are fresh.
  clear();menu=Screens.push(game,'VascSettings',{section=id});menu.showFirstGuide=function()return false end;U.wait(2);assert(U.shot(game,out..'/section-'..id..'.png'));clear()
 end
 print('MATRIX_TOTAL',values,blocked,actions,errors)
 assert(errors==0,'functional matrix errors: '..errors)
 print('PASS_FUNCTIONAL_MATRIX',gen2 and'gen2'or'gen1');love.event.quit(0)
end
