local nativeLove=love
local input=assert(io.open('gen2/lib/GoldSubmenuBattleStyle.lua'));local source=input:read('*a');input:close()
source=source:gsub('\nreturn M%s*$', '\nreturn {naming=namingRenderer, trainer=trainerRenderer, bag=drawPackBag}')
local boot, texts, lastConfig='en',{},nil
local function capture(value)texts[#texts+1]=tostring(value)end
local f={getWidth=function(_,s)return #s*6 end,getHeight=function()return 12 end,setFilter=function()end,getWrap=function(_,s)return #s*6,{s}end}
local g=setmetatable({print=capture,printf=capture,newFont=function()return f end,getFont=function()return f end,getDimensions=function()return 1100,720 end,newCanvas=function()return {setFilter=function()end}end,getCanvas=function()return nil end}, {__index=function()return function()end end})
love={graphics=g}
local provider={decorate=function(adapter,config)
 lastConfig=config
 adapter.draw=function(self)
  capture(self.title);capture(config.language)
  for _,row in ipairs(self.items)do capture(row.label);capture(config.describeItem(row))end
  self.__vascOrasBagWidePresentation=true
 end
 return adapter,true
end}
local api=assert(loadstring(source))({mod={options={get=function(_,key)if key=='qol_bag_skin'then return 'oras_wide'end end}},
 require=function()return nil end,OrasPartyPresentation={activeLanguage=function()return boot end},OrasBagSkin=provider})
local game={save={version='crystal',player={name='GOLD',badges={}},flags={HALL_OF_FAME=true},playTime={}}}
local naming={game=game,text='GOLD',prompt='YOUR NAME?',rows=function()return {}end}
local card={game=game,save=game.save,page=1}
local bag={game=game,rows={{id='POTION',name='POTION'}},items={POTION={description='Restores HP.'}},index=1}
local function output(fn,screen)
 texts={};assert(fn(screen,1100,720));return table.concat(texts,'|')
end
for _,lang in ipairs({'en','de','en'})do
 boot=lang
 local n=output(api.naming,naming)
 local c=output(api.trainer,card)
 card.page=2;local j=output(api.trainer,card);card.page=3;local k=output(api.trainer,card);card.page=1
 local b=output(api.bag,bag)
 assert(lastConfig.language==lang,'bag retained cached language')
 assert(b:find('Restores HP.',1,true),'native item description changed')
 if lang=='en'then
  assert(n:find('NAME ENTRY',1,true) and n:find('DELETE',1,true),n)
  assert(c:find('TRAINER CARD',1,true) and c:find('PLAY TIME',1,true),c)
  assert(j:find('FALKNER',1,true) and k:find('LT. SURGE',1,true),j..k)
  assert(b:find('Return to the START menu.',1,true),b)
  for _,word in ipairs({'NAMENSEINGABE','LÖSCHEN','TRAINERKARTE','SPIELZEIT','ZURÜCK','MAJOR BOB'})do assert(not (n..c..j..k..b):find(word,1,true),word)end
 else
  assert(n:find('NAMENSEINGABE',1,true) and c:find('TRAINERKARTE',1,true))
  assert(j:find('JOHTO-ORDEN',1,true) and k:find('MAJOR BOB',1,true))
  assert(b:find('Zurück zum START-Menü.',1,true))
 end
end
print('Gen2 trainer card, regional leaders, naming and cached bag language EN/DE/EN: PASS')

love=nativeLove
