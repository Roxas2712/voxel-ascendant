-- Execute the actual Gen-2 path facade: shared data loaders must not resolve
-- their own forwarding stubs, while gameplay stays generation-owned.
local f=assert(io.open('main.lua'));local s=f:read('*a');f:close()
local a=assert(s:find('local GEN2_A21_SHARED_UI',1,true))
local b=assert(s:find('local gen2 = setmetatable',a,true))
local resolve=assert(loadstring(s:sub(a,b-1)..'return privatePath'))()
for _,name in ipairs({'StadiumContentState','CobblemonContent','CobblemonExpression','CobblemonGeometry',
 'CobblemonImport','CobblemonJson','CobblemonMotion','CobblemonPack','CobblemonSize',
 'ContentJson','HdBinaryFetch','HdBinaryFetchWorker'})do
 local path='lib/'..name..'.lua';assert(resolve(path)==path,'model loader recurses: '..name)
 assert(loadfile(path),'shared data module missing: '..name)
end
for _,path in ipairs({'lib/OverworldBattle.lua','lib/PokemonModelProvider.lua',
 'lib/BattleArena.lua','data/battle_arenas.lua','options.lua'})do
 assert(resolve(path)=='gen2/'..path,'Gen-2 gameplay escaped private root')
end
print('PASS Gen-2 data-only model paths and gameplay isolation')
