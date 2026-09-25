local V={require=function(name)
 if name=='SetupLocale'then return{text=function(en)return en end}end
 if name=='OverworldBattle'then return{arenaArtSetting={key='arenaArt'},diskArtSetting={key='diskArt'}}end
 error(name)
end}
local M=assert(loadfile('lib/SetupCard.lua'))(V)
local screen=setmetatable({draft={},stageKey='battles'},M.Screen)
for _,id in ipairs({'battle_art','battle_detail'})do
 for _,mode in ipairs({true,'arena','flatB','terarrium',false})do
  screen.draft.battles=mode
  for _,key in ipairs({'terarriumDome','terarriumBackground','terarriumBehindRed'})do assert(screen:rowVisible({key=key},{id=id})==(mode=='terarrium'))end
  assert(screen:rowVisible({key='arenaArt'},{id=id})==(mode=='arena'))
  assert(screen:rowVisible({key='diskArt'},{id=id})==(mode=='flatB'))
  assert(screen:rowVisible({key='arenaCamera'},{id=id})==(mode==true or mode=='arena'))
 end
end
screen.draft.pokedexStyle='game';assert(not screen:rowVisible({key='modernDexSpriteSource'},{id='dex'}))
screen.draft.pokedexStyle='modern';assert(screen:rowVisible({key='modernDexSpriteSource'},{id='dex'}))
print('PASS setup: context-specific battle details and independent native/modern Dex options')
