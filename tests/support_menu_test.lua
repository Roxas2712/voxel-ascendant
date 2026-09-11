local M=assert(loadfile('lib/SupportMenu.lua'))()
for _,de in ipairs({false,true})do
 local changed={}
 local original={};local sent=0
 local menu={game={input={wasPressed=function()return false end}},items={},onChoose=function(row)
   if row.digit then row.right=tostring(((tonumber(row.right) or -1)+1)%10);changed[row.digit]=true
   elseif row.action=='send' then sent=sent+1 end
 end}
 menu.items={{label='SEND',action='send'},{label='STATUS',right='READY'},{label='CANCEL',action='cancel'}}
 for i=1,8 do local row={digit=i,right='?'};original[i]=row;menu.items[#menu.items+1]=row end
 local decorated=false
 M.decorate(menu,{decorateFocusHelp=function(m,help)decorated=true;assert(type(help)=='function');return m end},de)
 assert(decorated and #menu.items==5 and #menu.items[1].right==8)
 for i=1,8 do menu.onChoose(menu.items[1]);menu.onChoose(menu.items[2])end
 assert(menu.items[1].right=='00000000')
 for i=1,8 do assert(changed[i] and original[i].right=='0')end
 menu.onChoose(menu.items[3]);assert(sent==1,'original send confirmation handler lost')
 assert(menu.items[4].right=='READY','polling status row lost')
end
print('Skinned support menu: all 8 digits visible/editable; original sender callbacks preserved: OK')
