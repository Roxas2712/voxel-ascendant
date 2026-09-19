local root=assert(arg[1])
local ready=false
local install={status={state='idle',total=151},ready=function()return ready end,
 available=function()return ready end,targetCount=function()return 151 end,
 usesStadium2=function()return true end}
local writes=0
local V={require=function(name)
 if name=='StadiumInstall'then return install end
 if name=='EngineCompat'then return {fs=function()return nil end,osName=function()return 'Linux'end}end
 error('unavailable')
end}
local Menu=assert(loadfile(root..'/gen2/lib/StadiumRomMenu.lua'))(V)
install.begin=function()writes=writes+1;error('display must not import')end
for _,de in ipairs({false,true})do
 local value,help=Menu.guidance(de)
 assert(value=='OPTIONAL' and help:find('151',1,true) and help:find('.z64',1,true))
 assert(help:find(de and 'separat' or 'separate',1,true))
 install.status.state='building';install.status.done=43
 value,help=Menu.guidance(de);assert(value=='43/151')
 assert(help:find(de and 'nicht erneut' or 'no need',1,true))
 install.status.state='failed';install.status.error='/private/path/secret.rom'
 value,help=Menu.guidance(de);assert(value==(de and 'ERNEUT' or 'RETRY'))
 assert(not help:find('private',1,true))
 ready=true
 value,help=Menu.guidance(de);assert(value==(de and 'BEREIT' or 'READY'))
 assert(help:find('Stadium 2',1,true))
 ready=false;install.status.state='idle'
 for _,state in ipairs({'NO PICKER','NO MOBILE PICKER'})do
  Menu._status=state;value,help=Menu.guidance(de)
  assert(value==(de and 'KEIN DATEIDIALOG' or 'NO PICKER'))
 end
 Menu._status='PICK...';value,help=Menu.guidance(de)
 assert(value==(de and 'DATEI WÄHLEN' or 'CHOOSE FILE'))
 Menu._status='READY';value=Menu.guidance(de)
 assert(value=='OPTIONAL','stale picker status must not claim a ready model pack')
 Menu._status=nil
end
install.targetCount=function()return 251 end
local _,help=Menu.guidance(false);assert(help:find('251',1,true))
assert(writes==0)
print('PASS_STADIUM_SETUP_GUIDANCE live EN/DE states, counts, no import, no raw paths, no stale readiness')
