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


 assert(not gen2)
 local setup=e.setupCard.new(game);game.stack:push(setup)
 local original,live={},{};for k,v in pairs(setup.draft)do original[k]=v end;for k,v in pairs(setup.settings)do live[k]=v:get()end
 local function reset()setup.draft={};for k,v in pairs(original)do setup.draft[k]=v end;setup.draft.pokedexStyle='modern';setup.detailsOpen=true;setup.message=nil end
 local pages={};for i,page in ipairs(setup.pages)do pages[#pages+1]={page=page,index=i}end
 for key,page in pairs(setup.optional)do if type(page)=='table'and page.rows then if page.id=='battle_detail'then for _,mode in ipairs({true,'arena','flatB','terarrium',false})do pages[#pages+1]={page=page,optional=key,stage=mode}end else pages[#pages+1]={page=page,optional=key}end end end
 local n,skips=0,0
 for _,entry in ipairs(pages)do
  reset();setup.subpage=entry.optional and entry.page or nil;setup.page=entry.index or 1
  if entry.stage~=nil then setup.draft[setup.stageKey]=entry.stage end
  local choices={};for _,r in ipairs(setup:rows())do if r.choices then choices[#choices+1]=r end end
  for _,row in ipairs(choices)do
   for j,choice in ipairs(row.choices)do
    reset();if entry.stage~=nil then setup.draft[setup.stageKey]=entry.stage end;setup.draft[row.key]=row.choices[(j-2)%#row.choices+1][2]
    local found;for i,r in ipairs(setup:rows())do if r.key==row.key then setup.index=i;found=true;break end end
    if found then
     setup:step(1);U.wait(1);n=n+1
     local setting=setup.settings[row.key];local available=true
     if setting and row.key~='modernDexSpriteSource'then for i,v in ipairs(setting.values)do if v==choice[2]then available=setting:allows(i)end end end
     assert(not available or setup.draft[row.key]==choice[2],row.key..' ignored '..tostring(choice[2]))
     for k,v in pairs(live)do assert(setup.settings[k]:get()==v,'draft leaked to live '..k)end
     print('SETUP_CHOICE',entry.page.id,row.key,tostring(choice[2]),available and'PASS'or'GATED')
    else skips=skips+1;print('SETUP_CONDITIONAL',entry.page.id,row.key)end
   end
  end
  reset();if entry.stage~=nil then setup.draft[setup.stageKey]=entry.stage end;setup.index=1;setup:refreshPreview()
  for _,size in ipairs({{1100,760,'landscape'},{540,960,'portrait'}})do
   love.window.setMode(size[1],size[2],{resizable=true,vsync=1});U.wait(2);assert(U.shot(game,out..'/setup-deep-'..entry.page.id..(entry.stage~=nil and '-'..tostring(entry.stage)or'')..'-'..size[3]..'.png'))
  end
 end
 assert(setup:pause());print('PASS_SETUP_MATRIX',#pages,n,skips);love.event.quit(0)
end
