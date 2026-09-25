return function(game)
 io.stdout:setvbuf('no');love.window.hasFocus=function()return true end;love.window.isVisible=function()return true end
 local U=require('tests.drivers.util');game:startNewGame{intro=false}
 local V=assert(game.mods.exports.VOXEL_ASCENDANT);V.setupCard.suspended=true;V.ascendantContent.promptDisabled=true;V.ascendantContent.onboardingShown=true
 game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB=true;game.save.flags.EVENT_GOT_STARTER=true
 local Pokemon=require('src.pokemon.Pokemon');game.save.party={}
 for i,id in ipairs({'BULBASAUR','CHARMANDER','SQUIRTLE','PIKACHU','PIDGEY'})do game.save.party[i]=Pokemon.new(game.data,id,12+i)end
 love.window.setMode(1100,600,{resizable=true,vsync=1});U.teleport(game,'PALLET_TOWN',8,8,'down');U.wait(20)
 local Screens=require('src.ui.Screens');local dir=assert(os.getenv('SHOT_DIR'))
 local options=Screens.push(game,'OptionsMenu');local found={}
 for _,row in ipairs(options.rows)do if row.id and row.id:find('speed')then print('SPEED_ROW',row.id,row.label);found[row.id]=row end end
 assert(not found.speedBattle,'0.3.17 removed the battle speed option');print('UPSTREAM_BATTLE_SPEED_REMOVED_CONFIRMED')
 local group;for _,row in ipairs(options.view or {})do if row.id=='group.speed'then group=row end end
 assert(group);group.activate(game);local speed=game.stack:top()
 for _,row in ipairs(speed.view or speed.rows)do print('SPEED_SUB',row.id,row.label)end
 U.wait(20);assert(U.shot(game,dir..'/speed.png'));game.stack:pop();game.stack:pop()
 local function find(fn,name,seen)
  if type(fn)~='function'then return end;seen=seen or {};if seen[fn]then return end;seen[fn]=true
  for i=1,100 do local k,v=debug.getupvalue(fn,i);if not k then break end;if k==name then return v end end
  for i=1,100 do local k,v=debug.getupvalue(fn,i);if not k then break end;local found=find(v,name,seen);if found then return found end end
 end
 local context=assert(find(V.lib.require('VoxelScene').render,'V'))
 local Skins=context.require('PartyMenuSkins')
 local UI=context.require('PokemonUi');local P=context.require('OrasPartyPresentation')
 local setup=V.setupCard.new(game)
 local layoutPage
 for i,pg in ipairs(setup.pages)do if pg.id=='menus'then layoutPage=i end end
 assert(layoutPage,'layout setup page missing');setup.page=layoutPage
 for _,key in ipairs({'pokemonUiPartyMenu','pokemonUiBattleParty','pokemonUiPcBox','pokemonUiSkin'})do
  assert(setup.settings[key] and #setup.settings[key].values>=3,key..' choices missing')
  setup.draft[key]='game_default'
 end
 local live=UI.surfaceSettings.pc_box:get()
 assert(live~='game_default','fixture must begin without PC glass')
 game.stack:push(setup);U.wait(8);assert(U.shot(game,dir..'/setup-layouts.png'))
 assert(UI.surfaceSettings.pc_box:get()==live,'draft changed live setting')
 assert(setup:pause(),tostring(setup.message));local saved=context.require('SetupCard').receipt(game);print('SAVED_LAYOUT',saved.version,saved.done,saved.draft and saved.draft.pokemonUiPcBox);setup=V.setupCard.new(game);print('REOPEN_LAYOUT',setup.draft.pokemonUiPcBox)
 assert(setup.draft.pokemonUiPcBox=='game_default','layout draft lost on resume')
 game.stack:push(setup);setup.draft._device='keep';assert(setup:apply(),tostring(setup.message))
 assert(UI.surfaceSettings.pc_box:get()=='game_default','apply did not reach PC owner')
 local reopened=V.setupCard.new(game)
 assert(reopened.draft.pokemonUiPcBox=='game_default' and reopened.draft.pokemonUiBattleParty=='game_default','applied layouts lost on reopen')
 for _,key in ipairs({'pokemonUiPartyMenu','pokemonUiBattleParty','pokemonUiPcBox','pokemonUiSkin'})do reopened.draft[key]='asc_box' end
 reopened.draft._device='keep';game.stack:push(reopened);assert(reopened:apply(),tostring(reopened.message))
 while game.stack:top()~=game.overworld do game.stack:pop()end
 print('PASS_SETUP_LAYOUT_DRAFT_APPLY_REOPEN')
 local K=game.mods.exports.kanto_ascendant;local E=K.pokemonEquipment67
 local rules=K.generationRules;local state=rules.state(game,true,false);state.unlockedEpoch=7
 local yes,why=rules.switchMode(game,'gen3');assert(yes,tostring(why))
 game.save.boxes=game.save.boxes or {};game.save.boxes[1]={Pokemon.new(game.data,'PIKACHU',20)};game.save.currentBox=1
 assert(E.initialize(game))
 local first=game.save.party[1];local boxed=game.save.boxes[1][1]
 local Bag=require('src.inventory.Bag');assert(Bag.add(game.save,'LEFTOVERS',2,game.data))
 for i,mon in ipairs({first,boxed})do
  local v=assert(E.snapshotForMon(game,mon));assert(v.ability.id,'ability fixture absent')
  local result,reason=E.command(game,{requestId='layout-qa-'..i,handle=v.handle,expectedRevision=v.revision,action='give',itemId='LEFTOVERS'})
  assert(result,tostring(reason))
  local snap=assert(E.snapshotForMon(game,mon));local expected=snap.ability.names.en
  assert(P.abilityName(game,mon)==expected,'team ability not authoritative')
  assert(P.itemName(game,mon)==snap.item.names.en,'team item not authoritative')
  print('EQUIPMENT',mon.species,P.abilityName(game,mon),P.itemName(game,mon))
 end
 local box=Screens.push(game,'BoxMenu');U.wait(15)
 assert(U.shot(game,dir..'/box-equipment.png'))
 assert(box.__vascOrasStorage,'PC owner not attached')
 local before=game.save.boxes[1][1]
 U.tap(game,'a');U.wait(5);assert(U.shot(game,dir..'/box-carry-equipment.png'));U.tap(game,'b');U.wait(5)
 assert(game.save.boxes[1][1]==before,'carry cancel moved Pokemon')
 love.window.setMode(600,1100,{resizable=true,vsync=1});U.wait(8);assert(U.shot(game,dir..'/box-equipment-portrait.png'))
 love.window.setMode(1100,600,{resizable=true,vsync=1})
 while game.stack:top()~=game.overworld do game.stack:pop()end
 local current=assert(E.snapshotForMon(game,first))
 assert(E.command(game,{requestId='layout-qa-take',handle=current.handle,expectedRevision=current.revision,action='take'}))
 assert(P.itemName(game,first)=='---','removed held item stayed visible')
 current=assert(E.snapshotForMon(game,first))
 assert(E.command(game,{requestId='layout-qa-regive',handle=current.handle,expectedRevision=current.revision,action='give',itemId='LEFTOVERS'}))
 assert(P.itemName(game,first)=='Leftovers','new held item not refreshed')
 print('PASS_TEAM_BOX_EQUIPMENT')

 for _,style in ipairs({'game_default','oras_glass','asc_box'})do
  Skins.setting:setValue(style,game);game.partyMenuSavedIndex=1
  local party=Screens.push(game,'PartyMenu');U.wait(20)
  print('PARTY',style,party.__vascPartyMenuStyle,party.__ascendantGlobalUiSkinDecorated)
  assert(U.shot(game,dir..'/party-'..style..'.png'));U.tap(game,'down');U.tap(game,'a');U.wait(10);U.tap(game,'b');U.tap(game,'b');U.wait(10)
  while game.stack:top()~=game.overworld do game.stack:pop()end
 end
 Skins.setting:setValue('oras_glass',game)
 love.window.setMode(600,1100,{resizable=true,vsync=1})
 local picked,picker
 game.partyMenuSavedIndex=1
 local target=Screens.push(game,'PartyMenu',{pickOnly=true,itemUse=true,onSwitch=function(mon,menu)picked,picker=mon,menu end})
 local update,party=target.update,game.save.party
 U.wait(20);assert(U.shot(game,dir..'/party-glass-portrait.png'))
 U.tap(game,'down');U.tap(game,'a');U.wait(15)
 assert(picked==party[2] and picker==target,'native item selection callback changed')
 assert(game.save.party==party and target.update==update,'party/controller was replaced')
 while game.stack:top()~=game.overworld do game.stack:pop()end
 print('PASS_GLASS_PORTRAIT_NATIVE_ITEM_CALLBACK')
 print('MOBILE_MENU_CAPTURE_PASS');love.event.quit(0)
end
