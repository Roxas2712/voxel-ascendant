local f=assert(io.open('lib/Gen2ModernDexHost.lua'));local source=f:read('*a');f:close()
local values={pokedexStyle='modern',qol_ui_skin='standard',modernDexSpriteSource='crystal'}
local env=setmetatable({mod={options={get=function(_,key)return values[key]end}},V={require=function()return{}end}},{__index=_G})
local function extract(first,last)
 local a=assert(source:find(first,1,true));local b=assert(source:find(last,a+1,true));return source:sub(a,b-1)
end
local use=assert(loadstring(extract('local function useModern()','local function copy(')..'return useModern'));setfenv(use,env);use=use()
assert(use(),'unrelated skin disables modern Dex');values.pokedexStyle='game';values.qol_ui_skin='oras';assert(not use(),'Dex game-default switch ignored')
local feature=assert(loadstring(extract('local function featureMod()','local function loadUi()')..'return featureMod'));setfenv(feature,env);feature=feature()
for input,expected in pairs({crystal='kasc_crystal',active='auto',game='game',cobblemon='cobblemon'})do
 values.modernDexSpriteSource=input;assert(feature().options:get('sprite_source')==expected,input..' ignored')
end
print('PASS Gen2 Dex: independent layout setting and all advertised source options reach renderer')
env.copy=function(t)local c={};for k,v in pairs(t or {})do c[k]=v end;return c end;env.proxies={}
local proxy=assert(loadstring(extract('local function gameProxy(game)','local function panoramaImage()')..'return gameProxy'));setfenv(proxy,env);proxy=proxy()
local entry={dex=25,height=104,weight=130,text='When anger-<NEXT>ed.',text2='Second<NEXT>page.'}
local game={data={pokemon={PIKACHU={dex=25}},gen2Pokedex={entries={PIKACHU=entry}}},save={pokedex={caught={PIKACHU=true}}}}
local p=proxy(game);local actual=p.data.pokemon.PIKACHU.dexEntry
assert(actual.heightFt==1 and actual.heightIn==4 and actual.weight==130)
assert(actual.inlineText=='When angered.\nSecond page.')
assert(not entry.inlineText and p.save.pokedex.owned.PIKACHU,'proxy changed original data or lost caught flags')
print('PASS Gen2 Dex metadata: both literal text pages, line hyphenation and cartridge height units')

local needs=dofile('lib/SpriteSettingContent.lua').required
assert(needs('modernDexSpriteSource','crystal')==nil)
assert(needs('modernDexSpriteSource','cobblemon')==nil)
assert(needs('modernDexSpriteSource','kasc_crystal')=='pokemon-crystal')
print('PASS Dex content ownership: packaged Crystal/Cobblemon need no unrelated sprite download')
