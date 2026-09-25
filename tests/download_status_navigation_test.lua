package.loaded['src.render.Font']={width=function(s)return #s end,draw=function()end}
love={graphics={newShader=function()error('headless')end}}
local state='downloading';local pressed;local popped,manual=0,0
local session={installer={progress=function()return{state=state,total=0,completed=0}end},catalog={packages={}},downloadIds={'one'},
 openManual=function()manual=manual+1 end}
local game={input={wasPressed=function(_,k)return k==pressed end},stack={pop=function()popped=popped+1 end}}
local menu=dofile('lib/SpriteDownloadStatus.lua').new(game,session,{})
menu.index=2 -- BACK while the download is running
state='error';pressed='a';menu:update()
assert(popped==1,'download status change replaced the selected BACK action')
for _,row in ipairs(menu.items)do assert(row.action~='manual','offered dead manual action without a package')end
print('PASS download status: stable action focus across transitions; no dead alternative-link action')
local lines={};package.loaded['src.render.Font'].draw=function(s)lines[#lines+1]=s end
setmetatable(love.graphics,{__index=function()return function()end end})
session.downloadFamilyLabels={};session.maintenance={state='ready',result='healthy',checked=1,job={ids={'one'}},pending=function()return nil end};session.activeOperation='maintenance'
menu:refresh();menu:draw();local text=table.concat(lines,'\n')
assert(text:find('SPRITES VERIFIED',1,true)and text:find('No repair or restart needed.',1,true))
assert(not text:find('RESTART THE GAME',1,true)and not text:find('Download starts automatically.',1,true),'healthy check requested unnecessary work')
print('PASS successful maintenance is verification, with no fake restart/download instruction')
