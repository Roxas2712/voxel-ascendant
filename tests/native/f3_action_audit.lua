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


 local function open(group)
  clear();game:keypressed('f3');U.wait(1);local panel=assert(game.stack:top());assert(panel._vascControls,'F3 unavailable')
  if group then local found;for i,row in ipairs(panel.rows)do if row.submenu==group then panel.selected=i;found=true;break end end;assert(found,group);panel:onKeyPressed('return')end
  return panel
 end
 local first=open();local groups={false};for _,row in ipairs(first.rows)do if row.submenu then groups[#groups+1]=row.submenu end end
 local count=0
 for _,group in ipairs(groups)do
  local p=open(group);local actions={};for _,row in ipairs(p.rows)do if not row.submenu then actions[#actions+1]={id=row.id,key=row.key,title=row.title}end end
  for _,wanted in ipairs(actions)do
   p=open(group);local found;for i,row in ipairs(p.rows)do if row.id==wanted.id and row.key==wanted.key and row.title==wanted.title then p.selected=i;found=true;break end end
   assert(found,wanted.title);p:onKeyPressed('return');U.wait(1);count=count+1;print('F3_ACTION',group or 'root',wanted.id or wanted.key,wanted.title)
  end
 end
 clear();print('PASS_F3_ACTIONS',count);love.event.quit(0)
end
