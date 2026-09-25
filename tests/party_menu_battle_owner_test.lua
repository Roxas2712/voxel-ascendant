local listener,calls
calls=0
for _,name in ipairs({'src.render.TextBox','src.ui.ChoiceBox','src.ui.Menu','src.ui.QuantityBox'})do package.loaded[name]={}end
package.loaded['src.core.Strings']=function(s)return s end
local bridge=assert(loadfile('lib/PartyMenuSkins.lua'))({
 mod={events={on=function(_,name,fn)assert(name=='screen.pushed');listener=fn end},
 hooks={wrap=function()end}},
 require=function(name)
  if name=='ModSetting' then return {new=function()return {get=function()return 'asc_box' end}end}end
  if name=='OrasPartyPresentation' then return {decoratePartyMenu=function(s)calls=calls+1;s.draw=function()end;return s end}end
  return {}
 end})
assert(bridge.install())
local draw=function()end
local update=function()end
local callback=function()end
for _,state in ipairs({
 {screenId='PartyMenu',battle={},onSwitch=callback,draw=draw,update=update},
 {screenId='PartyMenu',__pokemonUiHostV1={surface='battle_party'},draw=draw,update=update},
})do
 listener({state=state});listener({state=state})
 assert(state.draw==draw and state.update==update,'Start skin replaced battle renderer/controller')
 assert(not state.__vascPartyMenuStyle,'Start selection replaced battle selection')
end
assert(calls==0)
local itemPicker={screenId='PartyMenu',pickOnly=true,itemUse=true,onSwitch=callback,draw=draw,update=update}
listener({state=itemPicker});listener({state=itemPicker})
assert(calls==1 and itemPicker.__vascPartyMenuStyle=='asc_box','ordinary item picker lost selected Start skin')
assert(itemPicker.onSwitch==callback,'item callback replaced')
local scriptPicker={screenId='PartyMenu',pickOnly=true,onSwitch=callback,draw=draw}
listener({state=scriptPicker})
assert(calls==2 and scriptPicker.__vascPartyMenuStyle=='asc_box','script target mistaken for battle')
print('party menu battle ownership: ok')
