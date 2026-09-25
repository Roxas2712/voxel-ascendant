local storageFail,writeFail,callbackFail,pops,live=false,false,false,0,false
local receipt;local V={mod={storage={write=function(_,_,_,value)if storageFail then return false,'disk full'end;receipt=value;return true end}},require=function(name)if name=='SetupLocale'then return{text=function(en)return en end}end;error(name)end}
local M=assert(loadfile('lib/SetupCard.lua'))(V)
local value=false
local s={values={false,true},get=function()return value end,setValue=function(_,v) value=v;return v end,
 change=function(_,v)live=v;if callbackFail and v then error('callback failed')end end}
local game={writeOptions=function()if writeFail then return false,'write failed'end end,stack={pop=function()pops=pops+1 end}}
local original=game.writeOptions
local function screen()return setmetatable({game=game,settings={setting=s},draft={setting=true,_device='keep'},initial={setting=false},page=1},M.Screen)end
local a=screen();storageFail=true;local ok=pcall(a.pause,a)
assert(ok and pops==0 and a.message,'failed draft save crashed or closed the guide')
storageFail=false;callbackFail=true;a=screen();assert(not a:apply());assert(value==false and live==false,'failed callback left live effect enabled');assert(game.writeOptions==original and pops==0)
callbackFail=false;writeFail=true;a=screen();assert(not a:apply(),'failed options save reported success');assert(not value and not live and not a.applied and pops==0)
writeFail=false;storageFail=true;a=screen();assert(not a:apply(),'failed receipt save reported success');assert(not value and not live and pops==0)
storageFail=false;a=screen();assert(a:apply());assert(value and live and receipt.done and pops==1 and game.writeOptions==original)
print('PASS setup: failed draft/options/receipt saves stay open, callbacks roll back, retry succeeds')
